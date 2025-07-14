#ifndef UTILS_HPP
#define UTILS_HPP

#include <string>

// Function to read password securely from the terminal
std::string get_password();

// Function to display the version of the program
void display_version();

// Function to display the help message
void display_help();

// Function to log a message to syslog or a file
void log_message(int level, const std::string &message, const std::string &log_file);

#endif // UTILS_HPP
