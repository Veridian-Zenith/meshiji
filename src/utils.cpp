#include "include/utils.hpp"
#include <iostream>
#include <termios.h>
#include <unistd.h>
#include <fstream>
#include <lua.hpp>
#include <ctime>
#include <iomanip>

std::string get_password() {
  std::cout << "Password: ";
  termios oldt;
  tcgetattr(STDIN_FILENO, &oldt);
  termios newt = oldt;
  newt.c_lflag &= ~ECHO;
  tcsetattr(STDIN_FILENO, TCSANOW, &newt);
  std::string password;
  std::getline(std::cin, password);
  tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
  std::cout << std::endl;
  return password;
}

void display_version() {
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    std::string version = "unknown";
    if (luaL_dofile(L, "version.lua") == LUA_OK) {
        if (lua_isstring(L, -1)) {
            version = lua_tostring(L, -1);
        }
    }
    lua_close(L);
    std::cout << "voix version " << version << std::endl;
}

void display_help() {
    std::cout << "voix: a modern, secure, and simple sudo replacement." << std::endl;
    std::cout << std::endl;
    std::cout << "Usage:" << std::endl;
    std::cout << "  voix [options] <command> [args...]" << std::endl;
    std::cout << std::endl;
    std::cout << "Options:" << std::endl;
    std::cout << "  -h, --help     Show this help message and exit." << std::endl;
    std::cout << "  -v, --version  Show the version of voix and exit." << std::endl;
    std::cout << std::endl;
    std::cout << "For more information, see the README.md file." << std::endl;
}

// Define syslog level constants locally to avoid including syslog.h
#define LOG_ERR     3
#define LOG_WARNING 4
#define LOG_INFO    6

void log_message(int level, const std::string &message, const std::string &log_file) {
    if (log_file.empty()) {
        return; // Do not log if no file is specified
    }

    std::ofstream out(log_file, std::ios_base::app);
    if (out.is_open()) {
        auto t = std::time(nullptr);
        auto tm = *std::localtime(&t);
        out << std::put_time(&tm, "%Y-%m-%d %H:%M:%S") << " ";
        switch (level) {
            case LOG_ERR:     out << "[ERROR] ";   break;
            case LOG_WARNING: out << "[WARNING] "; break;
            case LOG_INFO:    out << "[INFO] ";    break;
            default:          out << "[LOG] ";     break;
        }
        out << message << std::endl;
    }
}
