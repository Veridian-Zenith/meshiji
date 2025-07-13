#include "../include/utils.hpp"
#include <ctime>
#include <fstream>

// TODO: utils logic

void log_event(const std::string &event, const Config &cfg) {
  if (cfg.log_file.empty())
    return;
  std::ofstream log(cfg.log_file, std::ios::app);
  if (!log.is_open())
    return;
  std::time_t now = std::time(nullptr);
  char buf[32];
  std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", std::localtime(&now));
  log << "[" << buf << "] " << event << std::endl;
}
