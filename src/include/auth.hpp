#pragma once

#include "config.hpp"
#include <string>

// Performs PAM authentication for the given user.
bool authenticate_user(const std::string &username, const std::string &password, const Config &config);

// Checks if the user is allowed to run commands with elevated privileges.
bool check_permissions(const std::string &username, const Config &config);

// Authenticates and escalates privileges for the user.
bool authenticate_and_escalate(const std::string &username, const Config &config);
