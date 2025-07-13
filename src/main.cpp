// voix: CLI privilege escalation tool
// Cleaned, sorted, and commented for clarity

#include "../include/config.hpp"
#include "../include/utils.hpp"
#include <algorithm>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <grp.h>
#include <iostream>
#include <pwd.h>
#include <string>
#include <sys/stat.h>
#include <sys/types.h>
#include <termios.h>
#include <unistd.h>
#include <vector>
#include <security/pam_appl.h>
#include <security/pam_misc.h>
#include <syslog.h>

// Global variables for PAM conversation function
static std::string pam_username_global;
static std::string pam_password_global;

// PAM conversation function
int pam_conv_func(int num_msg, const struct pam_message **msg,
                  struct pam_response **resp, void *appdata_ptr) {
    if (num_msg <= 0) {
        syslog(LOG_ERR, "PAM conversation error: invalid message count");
        return PAM_CONV_ERR;
    }

    *resp = (struct pam_response *)calloc(num_msg, sizeof(struct pam_response));
    if (!*resp) {
        syslog(LOG_ERR, "PAM conversation error: memory allocation failed");
        return PAM_CONV_ERR;
    }

    for (int i = 0; i < num_msg; ++i) {
        if (msg[i]->msg_style == PAM_PROMPT_ECHO_OFF) {
            (*resp)[i].resp = strdup(pam_password_global.c_str());
        } else if (msg[i]->msg_style == PAM_PROMPT_ECHO_ON) {
            (*resp)[i].resp = strdup(pam_username_global.c_str());
        } else {
            (*resp)[i].resp = nullptr;
        }
    }
    return PAM_SUCCESS;
}

// Function to perform PAM authentication
bool authenticate_pam(const std::string &username, const std::string &password) {
    openlog("voix", LOG_PID | LOG_CONS, LOG_AUTH);

    pam_username_global = username;
    pam_password_global = password;

    struct pam_conv conv = {pam_conv_func, nullptr};
    pam_handle_t *pamh = nullptr;
    int ret = pam_start("voix", username.c_str(), &conv, &pamh);

    if (ret != PAM_SUCCESS) {
        syslog(LOG_ERR, "PAM initialization failed: %s", pam_strerror(pamh, ret));
        return false;
    }

    ret = pam_authenticate(pamh, 0);
    if (ret != PAM_SUCCESS) {
        syslog(LOG_ERR, "PAM authentication failed: %s", pam_strerror(pamh, ret));
        pam_end(pamh, ret);
        return false;
    }

    ret = pam_acct_mgmt(pamh, 0);
    if (ret != PAM_SUCCESS) {
        syslog(LOG_ERR, "PAM account management failed: %s", pam_strerror(pamh, ret));
        pam_end(pamh, ret);
        return false;
    }

    pam_end(pamh, ret);
    syslog(LOG_INFO, "PAM authentication successful for user: %s", username.c_str());
    return true;
}

// Check if a user belongs to a group
bool is_user_in_system_group(const std::string &user,
                             const std::string &group) {
  struct passwd *pw = getpwnam(user.c_str());
  if (!pw)
    return false;
  int ngroups = 0;
  getgrouplist(user.c_str(), pw->pw_gid, nullptr, &ngroups);
  std::vector<gid_t> groups(ngroups);
  getgrouplist(user.c_str(), pw->pw_gid, groups.data(), &ngroups);
  for (gid_t gid : groups) {
    struct group *gr = getgrgid(gid);
    if (gr && group == gr->gr_name)
      return true;
  }
  return false;
}

// Ensure /etc/voix exists
void ensure_config_dir_exists(const std::string &dir) {
  struct stat st = {0};
  if (stat(dir.c_str(), &st) == -1) {
    if (mkdir(dir.c_str(), 0755) != 0) {
      std::cerr << "Failed to create directory " << dir << ": "
                << strerror(errno) << std::endl;
    }
  }
}

// Create default config if missing
void create_default_config(const std::string &path) {
  ensure_config_dir_exists("/etc/voix");
  std::ofstream out(path);
  out << "-- voix config file\n"
         "-- This file controls who can use voix for privilege escalation\n\n"
         "return {\n"
         "  users = {\n"
         "    \"root\",\n"
         "  },\n"
         "  groups = {\n"
         "    \"wheel\",\n"
         "    \"admin\",\n"
         "  },\n"
         "  max_auth_attempts = 3,\n"
         "  log_file = \"/var/log/voix.log\",\n"
         "}\n";
  out.close();
  chmod(path.c_str(), 0644);
}

int main(int argc, char *argv[]) {
  // Config path logic
  std::string config_path = "/etc/voix/config.lua";
  struct stat buffer;
  if (stat(config_path.c_str(), &buffer) != 0)
    create_default_config(config_path);
  std::ifstream test(config_path);
  if (!test.good())
    config_path = "lua/config.lua";
  Config cfg;
  load_config(config_path, cfg);

  // Get current username securely
  std::string current_user = "unknown";
  struct passwd *pw = getpwuid(getuid());
  if (pw && pw->pw_name)
    current_user = pw->pw_name;

  // Check permissions
  bool allowed = std::find(cfg.users.begin(), cfg.users.end(), current_user) !=
                 cfg.users.end();
  if (!allowed) {
    for (const auto &g : cfg.groups) {
      if (is_user_in_system_group(current_user, g)) {
        allowed = true;
        break;
      }
    }
  }
  if (!allowed && is_user_in_system_group(current_user, "voix"))
    allowed = true;

  // Build command string for logging
  std::string log_cmd;
  for (int i = 1; i < argc; ++i) {
    log_cmd += std::string(argv[i]) + " ";
  }

  // Permission denied
  if (!allowed) {
    log_event("DENY user=" + current_user + " cmd='" + log_cmd + "'", cfg);
    std::cout << "User not allowed: " << current_user << "\n";
    std::cout
        << "Add them to /etc/voix/config.lua under 'users' or 'groups'.\n";
    return 1;
  }
  // Missing command
  if (argc < 2) {
    log_event("FAIL user=" + current_user + " reason=missing_command", cfg);
    std::cerr << "Usage: voix <command> [args...]" << std::endl;
    return 2;
  }

  // Secure password prompt
  std::string password;
  struct termios oldt, newt;
  std::cout << "Password: ";
  tcgetattr(STDIN_FILENO, &oldt);
  newt = oldt;
  newt.c_lflag &= ~ECHO;
  tcsetattr(STDIN_FILENO, TCSANOW, &newt);
  std::getline(std::cin, password);
  tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
  std::cout << std::endl;

  // Authenticate using PAM
  bool pam_auth_ok = authenticate_pam(current_user, password);

  if (!pam_auth_ok) {
    log_event("AUTHFAIL user=" + current_user + " cmd='" + log_cmd + "'", cfg);
    std::cerr << "Authentication failed." << std::endl;
    return 3;
  }
  // Privilege escalation
  if (setuid(0) != 0) {
    log_event("ESCALATEFAIL user=" + current_user + " cmd='" + log_cmd + "'",
              cfg);
    std::cerr << "Failed to escalate privileges: " << strerror(errno)
              << std::endl;
    return 3;
  }
  // Success
  log_event("SUCCESS user=" + current_user + " cmd='" + log_cmd + "'", cfg);
  execvp(argv[1], &argv[1]);
  // If exec fails
  log_event("EXECFAIL user=" + current_user + " cmd='" + log_cmd + "'", cfg);
  std::cerr << "Failed to execute command: " << strerror(errno) << std::endl;
  return 4;
}
