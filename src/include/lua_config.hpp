#pragma once
#include <string>
#include <vector>
#include "config.hpp"
#include <lua.hpp>

// Lua configuration support
void load_config(const std::string &path, Config &config);

// Helper function to read a string field from a Lua table
void get_string_field(lua_State *L, const char *key, std::string &value);

// Helper function to read an integer field from a Lua table
void get_int_field(lua_State *L, const char *key, int &value);

// Helper function to read a table of strings from a Lua table
void get_string_table(lua_State *L, const char *key, std::vector<std::string> &vec);
