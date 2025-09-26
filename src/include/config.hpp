#pragma once
#include <string>
#include <vector>

struct Rule {
    bool permit;
    bool persist;
    bool nopasswd;
    bool keepenv;
    std::string user_or_group;
    std::string target_user;
    std::string cmd;
};

std::vector<Rule> parse_config(const std::string& path);

struct Config {
  std::vector<std::string> users;
  std::vector<std::string> groups;
  std::string log_file;
  int max_auth_attempts = 3;
};

void load_config(const std::string &path, Config &config);
