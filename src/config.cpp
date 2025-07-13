#include "../include/config.hpp"
#include <fstream>
#include <string>
#include <vector>

void load_config(const std::string &path, Config &config) {
  std::ifstream file(path);
  std::string line;

  while (std::getline(file, line)) {
    if (line.find("users") != std::string::npos) {
      while (std::getline(file, line) && line.find("}") == std::string::npos) {
        if (line.find('"') != std::string::npos) {
          size_t start = line.find('"') + 1;
          size_t end = line.find('"', start);
          if (end > start)
            config.users.push_back(line.substr(start, end - start));
        }
      }
    }
    if (line.find("groups") != std::string::npos) {
      while (std::getline(file, line) && line.find("}") == std::string::npos) {
        if (line.find('"') != std::string::npos) {
          size_t start = line.find('"') + 1;
          size_t end = line.find('"', start);
          if (end > start)
            config.groups.push_back(line.substr(start, end - start));
        }
      }
    }
    if (line.find("max_auth_attempts") != std::string::npos) {
      size_t eq = line.find('=');
      if (eq != std::string::npos)
        config.max_auth_attempts = std::stoi(line.substr(eq + 1));
    }
    if (line.find("log_file") != std::string::npos) {
      size_t quote = line.find('"');
      if (quote != std::string::npos) {
        size_t end = line.find('"', quote + 1);
        if (end > quote)
          config.log_file = line.substr(quote + 1, end - quote - 1);
      }
    }
  }
}
