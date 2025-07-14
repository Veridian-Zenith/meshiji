#include <grp.h>
// voix: CLI privilege escalation tool
// This file contains the main application logic.

#include "include/config.hpp"
#include "include/utils.hpp"
#include "include/auth.hpp"
#include <cerrno>
#include <cstring>
#include <fstream>
#include <iostream>
#include <pwd.h>
#include <string>
#include <sys/stat.h>
#include <sys/types.h>
#include <termios.h>
#include <unistd.h>
#include <vector>
#include <syslog.h>

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

// Create default config if missing
static void create_default_config(const std::string &path) {
  ensure_config_dir_exists("/etc/voix");
  std::ofstream out(path);
  out << "-- Voix Configuration File\n"
         "-- This file defines who can run commands with elevated privileges.\n\n"
         "return {\n"
         "  -- List of users who can run commands with elevated privileges\n"
         "  users = {\n"
         "    \"root\",\n"
         "    \"your_username\"\n"
         "  },\n\n"
         "  -- List of groups whose members can run commands with elevated privileges\n"
         "  groups = {\n"
         "    \"wheel\",\n"
         "    \"admin\"\n"
         "  },\n\n"
         "  -- Maximum number of authentication attempts\n"
         "  max_auth_attempts = 3\n"
         "}\n";
  out.close();
  chmod(path.c_str(), 0644);
}

int main(int argc, char *argv[]) {
  openlog("voix", LOG_PID | LOG_CONS, LOG_AUTH);

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

  // Build command string for logging and execution
  std::string cmd_str;
  for (int i = 1; i < argc; ++i) {
    cmd_str += std::string(argv[i]) + (i < argc - 1 ? " " : "");
  }

  // Missing command check
  if (argc < 2) {
    syslog(LOG_ERR, "FAIL user=%s reason=missing_command", current_user.c_str());
    std::cerr << "Usage: voix <command> [args...]" << std::endl;
    closelog();
    return 2;
  }

  // Check permissions and authenticate in one step
  if (!check_permissions(current_user, cfg)) {
    syslog(LOG_WARNING, "DENY user=%s cmd='%s'", current_user.c_str(), cmd_str.c_str());
    std::cout << current_user << " not allowed. Add to /etc/voix/config.lua if this was intentional." << std::endl;
    closelog();
    return 1;
  }

  // Execute command as current user
  syslog(LOG_INFO, "SUCCESS user=%s cmd='%s'", current_user.c_str(), cmd_str.c_str());
  execl(user_shell.c_str(), user_shell.c_str(), "-c", cmd_str.c_str(), NULL);

  // If execl fails
  syslog(LOG_ERR, "EXECFAIL user=%s cmd='%s' error=%s", current_user.c_str(),
         cmd_str.c_str(), strerror(errno));
  std::cerr << "Failed to execute command: " << strerror(errno) << std::endl;
  closelog();
  return 4;
}
