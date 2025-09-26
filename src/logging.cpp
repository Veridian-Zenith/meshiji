#include "include/logging.hpp"
#include <iostream>
#include <fstream>
#include <ctime>
#include <iomanip>
#include <sstream>
#include <algorithm>

// Enhanced structured logging with JSON format
void log_message(int level, const std::string &message, const std::string &log_file, bool success) {
    if (log_file.empty()) {
        return; // Do not log if no file is specified
    }

    std::ofstream out(log_file, std::ios_base::app);
    if (out.is_open()) {
        auto t = std::time(nullptr);
        auto tm = *std::localtime(&t);

        // Parse message for structured data (format: "KEY=VALUE KEY2=VALUE2 message")
        std::string timestamp = std::to_string(t);
        std::string level_str;
        switch (level) {
            case LOG_ERR:     level_str = "ERROR";   break;
            case LOG_WARNING: level_str = "WARNING"; break;
            case LOG_INFO:    level_str = "INFO";    break;
            default:          level_str = "LOG";     break;
        }

        // Extract structured data from message
        std::string structured_data = message;
        std::string main_message = message;

        // Look for key=value pairs at the beginning
        size_t space_pos = message.find(' ');
        if (space_pos != std::string::npos) {
            std::string prefix = message.substr(0, space_pos);
            std::string rest = message.substr(space_pos + 1);

            // Check if prefix contains key=value pairs
            if (prefix.find('=') != std::string::npos) {
                structured_data = prefix;
                main_message = rest;
            }
        }

        // Create JSON structured log entry
        out << "{"
            << "\"timestamp\":\"" << std::put_time(&tm, "%Y-%m-%dT%H:%M:%S%z") << "\","
            << "\"epoch\":" << timestamp << ","
            << "\"level\":\"" << level_str << "\","
            << "\"success\":" << (success ? "true" : "false") << ",";

        // Add structured data if present
        if (!structured_data.empty() && structured_data != main_message) {
            out << "\"data\":\"" << structured_data << "\",";
        }

        out << "\"message\":\"" << main_message << "\""
            << "}" << std::endl;
    }
}

// This function is called after a command is executed.
// It logs the user, command, and success status.
void log_action(const std::string& user, const std::string& cmd, bool success, const std::string& log_file) {
    if (log_file.empty()) {
        return; // Do not log if no file is specified
    }

    std::ofstream out(log_file, std::ios_base::app);
    if (out.is_open()) {
        auto t = std::time(nullptr);
        auto tm = *std::localtime(&t);
        out << std::put_time(&tm, "%Y-%m-%d %H:%M:%S") << " ";
        out << user << ": " << cmd << " " << (success ? "OK" : "FAIL") << std::endl;
    }
}

bool is_auth_valid(const std::string& user) {
    std::ifstream ts_file("/run/voix/" + user + ".timestamp");
    if (ts_file.good()) {
        time_t now = time(nullptr);
        time_t last_auth;
        ts_file >> last_auth;
        return (now - last_auth) < 900; // 15-min timeout
    }
    return false;
}

void update_auth_timestamp(const std::string& user) {
    std::ofstream ts_file("/run/voix/" + user + ".timestamp");
    ts_file << time(nullptr);
}
