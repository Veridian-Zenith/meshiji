#pragma once
#include <string>
#include <vector>

struct Config {
  std::vector<std::string> users;
  std::vector<std::string> groups;
  int max_auth_attempts = 3;
};

void load_config(const std::string &path, Config &config);
