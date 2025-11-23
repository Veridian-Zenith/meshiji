#include "include/config.hpp"
#include <iostream>
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cctype>
#include <string>

// Validate configuration path for security
static bool is_valid_config_path(const std::string& path) {
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

// Trim whitespace from both ends of a string
static std::string trim(const std::string& str) {
    size_t start = 0;
    while (start < str.length() && std::isspace(static_cast<unsigned char>(str[start]))) {
        start++;
    }

    size_t end = str.length();
    while (end > start && std::isspace(static_cast<unsigned char>(str[end - 1]))) {
        end--;
    }

    return str.substr(start, end - start);
}

// Simplified config parser - much easier syntax
std::vector<Rule> parse_config(const std::string& path) {
    std::vector<Rule> rules;

    // Security validation
    if (!is_valid_config_path(path)) {
        std::cerr << "Error: Invalid config file path: " << path << std::endl;
        return rules;
    }

    std::ifstream file(path);
    if (!file.is_open()) {
        std::cerr << "Error: Cannot open config file: " << path << std::endl;
        return rules;
    }

    std::string line;
    int line_number = 0;

    while (std::getline(file, line)) {
        line_number++;

        // Skip empty lines and comments
        if (line.empty() || line[0] == '#') {
            continue;
        }

        // Remove trailing comments
        size_t comment_pos = line.find('#');
        if (comment_pos != std::string::npos) {
            line = line.substr(0, comment_pos);
        }

        // Trim whitespace
        line = trim(line);
        if (line.empty()) {
            continue;
        }

        // Simple parsing - just split by spaces
        std::istringstream iss(line);
        std::string word;

        if (!(iss >> word)) {
            continue;
        }

        bool permit;
        if (word == "permit") {
            permit = true;
        } else if (word == "deny") {
            permit = false;
        } else {
            // Skip invalid lines
            continue;
        }

        Rule r;
        r.permit = permit;
        r.persist = false;
        r.nopasswd = false;
        r.keepenv = false;
        r.user_or_group = "";
        r.target_user = "root";
        r.cmd = "";

        // Get user/group
        if (iss >> r.user_or_group) {
            // Check for modifiers
            while (iss >> word) {
                if (word == "persist") {
                    r.persist = true;
                } else if (word == "nopasswd") {
                    r.nopasswd = true;
                } else if (word == "keepenv") {
                    r.keepenv = true;
                } else if (word == "as" && iss >> r.target_user) {
                    // Handle "as user" syntax
                    // target_user already set from iss
                } else if (word == "cmd") {
                    // Rest of the line is the command
                    std::string cmd;
                    std::getline(iss, cmd);
                    r.cmd = trim(cmd);
                } else {
                    // Unknown word - could be part of command or another modifier
                    // For simplicity, treat everything after user as command
                    r.cmd = word;
                    std::string rest;
                    std::getline(iss, rest);
                    if (!trim(rest).empty()) {
                        r.cmd += " " + trim(rest);
                    }
                    break;
                }
            }
        }

        // Default target user is root if not specified
        if (r.target_user.empty()) {
            r.target_user = "root";
        }

        // Validate basic requirements
        if (r.user_or_group.empty()) {
            continue; // Skip invalid rule
        }

        // Validate rule consistency
        if (r.nopasswd && !r.permit) {
            std::cerr << "Warning: nopasswd on deny rule is ineffective (line " << line_number << ")" << std::endl;
        }

        rules.push_back(r);
    }

    return rules;
}
