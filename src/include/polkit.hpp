#pragma once
#include <string>

// Polkit authentication function for GUI environments
bool check_polkit_auth(const std::string& action_id, const std::string& cmd);

// Check if we're in a GUI environment
bool is_gui_environment();
