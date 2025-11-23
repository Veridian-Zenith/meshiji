#include "include/logging.hpp"
#include <iostream>
#include <fstream>
#include <ctime>
#include <iomanip>
#include <sstream>
#include <algorithm>
#include <sys/stat.h>
#include <cerrno>
#include <cstring>
#include <string>

// Validate log file path for security
static bool is_valid_log_path(const std::string& path) {
    if (path.empty() || path.length() > 512) {
        return false;
    }

    // Prevent path traversal attacks
    if (path.find("..") != std::string::npos ||
        path.find("//") != std::string::npos ||
        path.find("~") != std::string::npos) {
        return false;
    }

    // Must be absolute path for security
    if (path[0] != '/') {
        return false;
    }

    return true;
}

// Ensure log directory exists with proper permissions
static void ensure_log_dir_exists(const std::string& log_file) {
    size_t last_slash = log_file.find_last_of('/');
    if (last_slash == std::string::npos) {
        return; // No directory to create
    }

    std::string dir = log_file.substr(0, last_slash);
    struct stat st = {0};

    if (stat(dir.c_str(), &st) == -1) {
        if (mkdir(dir.c_str(), 0755) != 0) {
            // Log to stderr if we can't create log directory
            std::cerr << "Failed to create log directory " << dir << ": "
                      << strerror(errno) << std::endl;
        }
    }
}

// Escape JSON strings to prevent injection attacks
static std::string escape_json_string(const std::string& input) {
    std::string result;
    result.reserve(input.length());

    for (char c : input) {
        switch (c) {
            case '"':  result += "\\\""; break;
            case '\\': result += "\\\\"; break;
            case '\b': result += "\\b";  break;
            case '\f': result += "\\f";  break;
            case '\n': result += "\\n";  break;
            case '\r': result += "\\r";  break;
            case '\t': result += "\\t";  break;
            default:
                if (c >= 0 && c < 32) {
                    result += "\\u";
                    result += std::to_string(static_cast<int>(c));
                } else {
                    result += c;
                }
                break;
        }
    }

    return result;
}

// Enhanced structured logging with JSON format and security validation
void log_message(int level, const std::string &message, const std::string &log_file, bool success) {
    // Security validation
    if (!is_valid_log_path(log_file)) {
        std::cerr << "Invalid log file path: " << log_file << std::endl;
        return;
    }

    if (message.empty() || message.length() > 2048) {
        return; // Invalid message
    }

    // Ensure log directory exists
    ensure_log_dir_exists(log_file);

    std::ofstream out(log_file, std::ios_base::app);
    if (!out.is_open()) {
        std::cerr << "Failed to open log file: " << log_file << std::endl;
        return;
    }

    try {
        auto t = std::time(nullptr);
        auto tm = *std::localtime(&t);

        std::string level_str;
        switch (level) {
            case 3: level_str = "ERROR"; break;
            case 4: level_str = "WARNING"; break;
            case 5: level_str = "NOTICE"; break;
            case 6: level_str = "INFO"; break;
            default: level_str = "DEBUG"; break;
        }

        // Extract structured data from message (format: "KEY=VALUE message")
        std::string main_message = message;
        std::string structured_data;

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
            << "\"epoch\":" << std::to_string(t) << ","
            << "\"level\":\"" << level_str << "\","
            << "\"success\":" << (success ? "true" : "false") << ",";

        // Add structured data if present and valid
        if (!structured_data.empty() && structured_data != main_message) {
            out << "\"data\":\"" << escape_json_string(structured_data) << "\",";
        }

        out << "\"message\":\"" << escape_json_string(main_message) << "\""
            << "}" << std::endl;

    } catch (const std::exception& e) {
        std::cerr << "Logging error: " << e.what() << std::endl;
    }
}

// This function is called after a command is executed.
// It logs the user, command, and success status.
void log_action(const std::string& user, const std::string& cmd, bool success, const std::string& log_file) {
    // Input validation
    if (user.empty() || cmd.empty() || !is_valid_log_path(log_file)) {
        return;
    }

    if (user.length() > 256 || cmd.length() > 1024) {
        return; // Prevent buffer overflow
    }

    std::ofstream out(log_file, std::ios_base::app);
    if (!out.is_open()) {
        std::cerr << "Failed to open log file: " << log_file << std::endl;
        return;
    }

    try {
        auto t = std::time(nullptr);
        auto tm = *std::localtime(&t);
        out << std::put_time(&tm, "%Y-%m-%d %H:%M:%S") << " ";
        out << escape_json_string(user) << ": " << escape_json_string(cmd) << " "
            << (success ? "OK" : "FAIL") << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "Action logging error: " << e.what() << std::endl;
    }
}


// Authentication caching functions for security
bool is_auth_valid(const std::string& user) {
    // Input validation
    if (user.empty() || user.length() > 256) {
        return false;
    }

    // Use secure authentication cache path
    std::string cache_file = "/var/lib/voix/.auth_cache";
    
    std::ifstream ts_file(cache_file);
    if (!ts_file.is_open()) {
        return false;
    }

    try {
        time_t now = time(nullptr);
        std::string line;
        
        while (std::getline(ts_file, line)) {
            std::istringstream iss(line);
            std::string cached_user;
            long long timestamp;
            
            if (iss >> cached_user >> timestamp) {
                if (cached_user == user) {
                    time_t auth_time = static_cast<time_t>(timestamp);
                    time_t now_time = time(nullptr);
                    long diff = now_time - auth_time;
                    
                    // Authentication valid for 5 minutes (300 seconds)
                    ts_file.close();
                    return diff <= 300;
                }
            }
        }
        ts_file.close();
    } catch (const std::exception& e) {
        std::cerr << "Auth validation error: " << e.what() << std::endl;
    }
    
    return false;
}

void update_auth_timestamp(const std::string& user) {
    // Input validation
    if (user.empty() || user.length() > 256) {
        return;
    }

    // Ensure the directory exists
    std::string dir = "/var/lib/voix";
    struct stat st = {0};
    if (stat(dir.c_str(), &st) == -1) {
        if (mkdir(dir.c_str(), 0700) != 0) {
            std::cerr << "Failed to create auth cache directory: " << strerror(errno) << std::endl;
            return;
        }
    }

    // Use secure authentication cache path
    std::string cache_file = "/var/lib/voix/.auth_cache";
    
    std::ofstream ts_file(cache_file, std::ios::app);
    if (!ts_file.is_open()) {
        std::cerr << "Failed to open auth cache file: " << cache_file << std::endl;
        return;
    }

    try {
        time_t now = time(nullptr);
        ts_file << user << " " << now << std::endl;
        ts_file.close();
    } catch (const std::exception& e) {
        std::cerr << "Auth timestamp update error: " << e.what() << std::endl;
    }
}
