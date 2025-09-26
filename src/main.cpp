#include <grp.h>
// voix: CLI privilege escalation tool
// This file contains the main application logic.

#include "include/config.hpp"
#include "include/auth.hpp"
#include "include/polkit.hpp"
#include "include/logging.hpp"
#include "include/password.hpp"
#include "include/env.hpp"
#include <cerrno>
#include <cstring>
#include <iostream>
#include <pwd.h>
#include <string>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <vector>

// Ensure /etc/voix exists
static void ensure_config_dir_exists(const std::string &dir) {
  struct stat st = {0};
  if (stat(dir.c_str(), &st) == -1) {
    if (mkdir(dir.c_str(), 0755) != 0) {
      std::cerr << "Failed to create directory " << dir << ": "
                << strerror(errno) << std::endl;
    }
  }
}



// Helper function to check group membership
static bool is_user_in_system_group(const std::string &user,
                                    const std::string &group) {
  struct passwd *pw = getpwnam(user.c_str());
  if (!pw)
    return false;

  int ngroups = 0;
  getgrouplist(user.c_str(), pw->pw_gid, nullptr, &ngroups);
  if (ngroups <= 0)
    return false;

  std::vector<gid_t> groups(ngroups);
  getgrouplist(user.c_str(), pw->pw_gid, groups.data(), &ngroups);

  for (int i = 0; i < ngroups; ++i) {
    struct group *gr = getgrgid(groups[i]);
    if (gr && group == gr->gr_name) {
      return true;
    }
  }
  return false;
}



// Get command first to allow non-root commands
int main(int argc, char *argv[]) {
  // Missing command check
  if (argc < 2) {
    display_help();
    return 2;
  }

  std::string command = argv[1];
  if (command == "help" || command == "--help" || command == "-h") {
    display_help();
    return 0;
  }

  if (command == "version" || command == "--version" || command == "-v") {
    display_version();
    return 0;
  }

  if (command == "check") {
      std::string config_path = "/etc/voix.conf";
      if (argc > 2) {
          config_path = argv[2];
      }
      std::vector<Rule> rules = parse_config(config_path);
      if (rules.empty()) {
          std::cerr << "No rules found or failed to parse config file." << std::endl;
          return 1;
      }
      for (const auto& r : rules) {
          std::cout << (r.permit ? "Permit" : "Deny") << " rule for " << r.user_or_group
                    << (r.cmd.empty() ? "" : " cmd " + r.cmd) << std::endl;
      }
      std::cout << "Configuration file '" << config_path << "' is valid." << std::endl;
      return 0;
  }

  if (command == "validate") {
      std::string config_path = "/etc/voix.conf";
      if (argc > 2) {
          config_path = argv[2];
      }
      std::vector<Rule> rules = parse_config(config_path);
      if (rules.empty()) {
          std::cerr << "No rules found or failed to parse config file." << std::endl;
          return 1;
      }
      std::cout << "Configuration validation successful." << std::endl;
      std::cout << "Found " << rules.size() << " rule(s):" << std::endl;
      for (const auto& r : rules) {
          std::cout << "  - " << (r.permit ? "Permit" : "Deny") << " rule for " << r.user_or_group
                    << (r.cmd.empty() ? "" : " cmd " + r.cmd) << std::endl;
      }
      return 0;
  }

  // Now check root for privileged operations
  if (geteuid() != 0) {
    std::cerr << "Error: Voix is not running with root privileges." << std::endl;
    std::cerr << "This program must be owned by the root user and have the setuid bit set." << std::endl;
    std::cerr << "Please run the following commands:" << std::endl;
    std::cerr << "  sudo chown root:root " << argv[0] << std::endl;
    std::cerr << "  sudo chmod u+s " << argv[0] << std::endl;
    return 1;
  }

  Config cfg; // Declare cfg here to be accessible by all branches
  bool authenticated = false;
  bool keep_env = false;

  // Build command string for logging and execution
  std::string cmd_str;
  for (int i = 1; i < argc; ++i) {
    cmd_str += std::string(argv[i]) + (i < argc - 1 ? " " : "");
  }

  // Config path
  std::string config_path = "/etc/voix.conf";
  struct stat buffer;
  if (stat(config_path.c_str(), &buffer) != 0) {
      std::cerr << "Configuration file " << config_path << " not found." << std::endl;
      return 1;
  }

  // Get current username and shell securely
  std::string current_user = "unknown";
  std::string user_shell = "/bin/sh";
  struct passwd *pw = getpwuid(getuid());
  if (pw && pw->pw_name) {
    current_user = pw->pw_name;
    if (pw->pw_shell && *pw->pw_shell) {
        user_shell = pw->pw_shell;
    }
  }

  // Parse config
  std::vector<Rule> rules = parse_config(config_path);
  cfg.log_file = "/var/log/voix.log";
  cfg.max_auth_attempts = 3;
  bool permitted = false;
  bool can_persist = false;
  bool should_keepenv = false;
  bool nopasswd_rule = false;
  bool denied = false;
  for (const auto& rule : rules) {
      bool user_matches = false;
      if (rule.user_or_group.rfind("group:", 0) == 0) { // start with group:
          std::string gname = rule.user_or_group.substr(6);
          user_matches = is_user_in_system_group(current_user, gname);
      } else {
          user_matches = (rule.user_or_group == current_user);
      }
      bool cmd_matches = rule.cmd.empty() ||
          (cmd_str.find(rule.cmd + " ") == 0) || (cmd_str == rule.cmd);
      if (user_matches && cmd_matches) {
          if (rule.permit) {
              permitted = true;
              can_persist = rule.persist;
              should_keepenv = rule.keepenv;
              nopasswd_rule = rule.nopasswd;
              break;
          } else {
              denied = true;
              break;
          }
      }
  }
  if (denied || !permitted) {
      log_message(4, "DENY user=" + current_user + " cmd='" + cmd_str + "'", cfg.log_file, false);
      std::cerr << "voix: command not permitted" << std::endl;
      return 1;
  }
  authenticated = nopasswd_rule || (can_persist && is_auth_valid(current_user));
  keep_env = should_keepenv;
  cfg.users.push_back(current_user); // For authenticate_and_escalate

  if (!authenticated) {
      // Try polkit authentication first in GUI environments
      bool polkit_success = false;
#ifdef HAVE_POLKIT
      if (is_gui_environment()) {
          std::string action_id = "org.veridian.voix.execute";
          // Use specific action for systemctl commands
          if (cmd_str.find("systemctl") == 0) {
              action_id = "org.veridian.voix.systemctl";
          }
          // Use specific action for package management
          else if (cmd_str.find("pacman") == 0 || cmd_str.find("apt") == 0 ||
                   cmd_str.find("yum") == 0 || cmd_str.find("dnf") == 0) {
              action_id = "org.veridian.voix.package-management";
          }

          polkit_success = check_polkit_auth(action_id, cmd_str);
          if (polkit_success) {
              log_message(6, "POLKIT_AUTH_SUCCESS user=" + current_user + " cmd='" + cmd_str + "'", cfg.log_file, true);
          }
      }
#endif

      // Fall back to PAM if polkit is not available or failed
      if (!polkit_success) {
          Config auth_cfg; // Dummy config for PAM auth
          if (!authenticate_and_escalate(current_user, auth_cfg)) {
              return 1;
          }
          update_auth_timestamp(current_user);
      }
  }

  if (!keep_env) {
      scrub_env();
  }

  // Execute command as root
  log_message(6, "SUCCESS user=" + current_user + " cmd='" + cmd_str + "'", cfg.log_file, true);
  execl(user_shell.c_str(), user_shell.c_str(), "-c", cmd_str.c_str(), NULL);

  // If execl fails
  log_message(3, "EXECFAIL user=" + current_user + " cmd='" + cmd_str + "' error=" + strerror(errno), cfg.log_file, false);
  std::cerr << "Failed to execute command: " << strerror(errno) << std::endl;
  return 4;
}
