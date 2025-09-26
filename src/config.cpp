#include "include/config.hpp"
#include <iostream>
#include <lua.hpp>
#include <fstream>
#include <regex>
#include <sstream>
#include <algorithm>

// Enhanced config parser with better error handling and validation
std::vector<Rule> parse_config(const std::string& path) {
    std::vector<Rule> rules;
    std::ifstream file(path);

    if (!file.is_open()) {
        std::cerr << "Error: Cannot open config file: " << path << std::endl;
        return rules;
    }

    std::string line;
    int line_number = 0;

    // Enhanced regex that handles quoted commands and better validation
    std::regex rule_regex("^\\s*(permit|deny)\\s+((?:persist\\s+|nopasswd\\s+|keepenv\\s+)*)(?:(\\w+|group:\\w+)|\"([^\"]+)\")\\s+(as\\s+\\w+\\s+)?(cmd\\s+(.+))?$");

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
        line.erase(line.begin(), std::find_if(line.begin(), line.end(), [](unsigned char ch) -> bool {
            return !std::isspace(ch);
        }));
        line.erase(std::find_if(line.rbegin(), line.rend(), [](unsigned char ch) -> bool {
            return !std::isspace(ch);
        }).base(), line.end());

        if (line.empty()) {
            continue;
        }

        std::smatch match;
        if (std::regex_match(line, match, rule_regex)) {
            try {
                Rule r;
                r.permit = (match[1] == "permit");

                // Parse modifiers
                std::string modifiers = match[2];
                r.persist = (modifiers.find("persist") != std::string::npos);
                r.nopasswd = (modifiers.find("nopasswd") != std::string::npos);
                r.keepenv = (modifiers.find("keepenv") != std::string::npos);

                // Handle quoted user/group names
                if (match[4].matched) {
                    r.user_or_group = match[4]; // Quoted user/group
                } else {
                    r.user_or_group = match[3]; // Unquoted
                }

                // Validate user/group format
                if (r.user_or_group.find("group:") == 0) {
                    std::string group_name = r.user_or_group.substr(6);
                    if (group_name.empty()) {
                        std::cerr << "Warning: Empty group name on line " << line_number << std::endl;
                        continue;
                    }
                } else if (r.user_or_group.empty()) {
                    std::cerr << "Warning: Empty user/group on line " << line_number << std::endl;
                    continue;
                }

                // Parse target user
                std::string target_part = match[5];
                if (!target_part.empty()) {
                    std::istringstream iss(target_part);
                    std::string as_keyword, target_user;
                    iss >> as_keyword >> target_user;
                    r.target_user = target_user.empty() ? "root" : target_user;
                } else {
                    r.target_user = "root";
                }

                // Parse command (handle quoted commands)
                std::string cmd_part = match[6];
                if (!cmd_part.empty()) {
                    // Remove leading/trailing whitespace
                    cmd_part.erase(cmd_part.begin(), std::find_if(cmd_part.begin(), cmd_part.end(), [](unsigned char ch) {
                        return !std::isspace(ch);
                    }));
                    r.cmd = cmd_part;
                } else {
                    r.cmd = "";
                }

                // Validate rule consistency
                if (r.nopasswd && !r.permit) {
                    std::cerr << "Warning: nopasswd modifier on deny rule is ineffective (line " << line_number << ")" << std::endl;
                }

                if (r.persist && r.nopasswd) {
                    std::cerr << "Warning: persist with nopasswd may not work as expected (line " << line_number << ")" << std::endl;
                }

                rules.push_back(r);

            } catch (const std::exception& e) {
                std::cerr << "Error parsing line " << line_number << ": " << e.what() << std::endl;
                continue;
            }
        } else {
            std::cerr << "Warning: Invalid syntax on line " << line_number << ": " << line << std::endl;
            std::cerr << "Expected format: permit|deny [persist|nopasswd|keepenv] <user|group:name> [as <target>] [cmd <command>]" << std::endl;
        }
    }

    if (rules.empty()) {
        std::cerr << "Warning: No valid rules found in config file: " << path << std::endl;
    }

    return rules;
}
