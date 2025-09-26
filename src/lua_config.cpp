#include "include/lua_config.hpp"
#include <iostream>
#include <lua.hpp>

// Helper function to read a string field from a Lua table
void get_string_field(lua_State *L, const char *key, std::string &value) {
    lua_getfield(L, -1, key);
    if (lua_isstring(L, -1)) {
        value = lua_tostring(L, -1);
    }
    lua_pop(L, 1);
}

// Helper function to read an integer field from a Lua table
void get_int_field(lua_State *L, const char *key, int &value) {
    lua_getfield(L, -1, key);
    if (lua_isinteger(L, -1)) {
        value = lua_tointeger(L, -1);
    }
    lua_pop(L, 1);
}

// Helper function to read a table of strings from a Lua table
void get_string_table(lua_State *L, const char *key, std::vector<std::string> &vec) {
    lua_getfield(L, -1, key);
    if (lua_istable(L, -1)) {
        lua_pushnil(L);
        while (lua_next(L, -2) != 0) {
            if (lua_isstring(L, -1)) {
                vec.push_back(lua_tostring(L, -1));
            }
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
}

void load_config(const std::string &path, Config &config) {
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);

    if (luaL_dofile(L, path.c_str()) != LUA_OK) {
        std::cerr << "Error loading config file: " << lua_tostring(L, -1) << std::endl;
        lua_close(L);
        return;
    }

    if (!lua_istable(L, -1)) {
        std::cerr << "Config file must return a table" << std::endl;
        lua_close(L);
        return;
    }

    // Get global settings
    get_int_field(L, "max_auth_attempts", config.max_auth_attempts);
    get_string_field(L, "log_file", config.log_file);

    // Get users and groups
    get_string_table(L, "users", config.users);
    get_string_table(L, "groups", config.groups);

    lua_close(L);
}
