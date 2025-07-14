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

  // Verify that the program is running with the correct permissions
  if (geteuid() != 0) {
    std::cerr << "Error: Voix is not running with root privileges." << std::endl;
    std::cerr << "This program must be owned by the root user and have the setuid bit set." << std::endl;
    std::cerr << "Please run the following commands:" << std::endl;
    std::cerr << "  sudo chown root:root " << argv[0] << std::endl;
    std::cerr << "  sudo chmod u+s " << argv[0] << std::endl;
    closelog();
    return 1;
  }

  // Config path logic
  std::string config_path = "/etc/voix/config.lua";
  struct stat buffer;
  if (stat(config_path.c_str(), &buffer) != 0) {
    create_default_config(config_path);
  }
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
    display_help();
    closelog();
    return 2;
  }

  std::string command = argv[1];
  if (command == "help" || command == "--help" || command == "-h") {
    display_help();
    closelog();
    return 0;
  }

  if (command == "version" || command == "--version" || command == "-v") {
    display_version();
    closelog();
    return 0;
  }

  // Authenticate and escalate privileges
  if (!authenticate_and_escalate(current_user, cfg)) {
    closelog();
    return 1;
  }

  // Execute command as root
  log_message(LOG_INFO, "SUCCESS user=" + current_user + " cmd='" + cmd_str + "'", cfg.log_file);
  execl(user_shell.c_str(), user_shell.c_str(), "-c", cmd_str.c_str(), NULL);

  // If execl fails
  log_message(LOG_ERR, "EXECFAIL user=" + current_user + " cmd='" + cmd_str + "' error=" + strerror(errno), cfg.log_file);
  std::cerr << "Failed to execute command: " << strerror(errno) << std::endl;
  closelog();
  return 4;
}
