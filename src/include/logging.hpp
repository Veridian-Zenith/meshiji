#pragma once
#include <string>

// Define syslog level constants locally to avoid including syslog.h
#define LOG_ERR     3
#define LOG_WARNING 4
#define LOG_INFO    6

// Enhanced structured logging with JSON format
void log_message(int level, const std::string &message, const std::string &log_file, bool success);

// This function is called after a command is executed.
// It logs the user, command, and success status.
void log_action(const std::string& user, const std::string& cmd, bool success, const std::string& log_file);

// Auth caching functions
bool is_auth_valid(const std::string& user);
void update_auth_timestamp(const std::string& user);
