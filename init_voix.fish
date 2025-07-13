#!/usr/bin/env fish

# Create project structure
mkdir -p src gui pam lua include

# Create voix core CLI binary
printf '%s\n' '
#include <iostream>
int main(int argc, char* argv[]) {
    std::cout << "voix (CLI) called" << std::endl;
    return 0;
}
' > src/main.cpp

# Create voix-gui binary
printf '%s\n' '
#include <iostream>
int main(int argc, char* argv[]) {
    std::cout << "voix-gui (graphical pkexec replacement) called" << std::endl;
    return 0;
}
' > gui/main.cpp

# Create voix-pam helper
printf '%s\n' '
#include <iostream>
int main(int argc, char* argv[]) {
    std::cout << "voix-pam helper called" << std::endl;
    return 0;
}
' > pam/voix-pam-helper.cpp

# Core source placeholders
for f in auth config utils
    printf "// TODO: $f logic\n" > src/$f.cpp
    printf "#pragma once\n// TODO: $f headers\n" > src/$f.hpp
end

# Lua config
printf '%s\n' '
return {
  users = {
    "root",
    "alice",
    "bob",
  },
  groups = {
    "wheel",
    "admin",
  },
  log_file = "/var/log/voix.log",
  max_auth_attempts = 3,
}
' > lua/config.lua

# CMakeLists.txt
printf '%s\n' '
cmake_minimum_required(VERSION 3.16)
project(voix LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(voix
  src/main.cpp
  src/auth.cpp
  src/config.cpp
  src/utils.cpp
)

add_executable(voix-gui
  gui/main.cpp
)

add_executable(voix-pam
  pam/voix-pam-helper.cpp
)

target_include_directories(voix PRIVATE src include)
target_include_directories(voix-gui PRIVATE gui include)
target_include_directories(voix-pam PRIVATE pam include)
' > CMakeLists.txt

# README.md
printf '%s\n' '# Voix

Voix is a modular privilege escalation suite, replacing `sudo` and `pkexec`.

## Components

- `voix` — CLI sudo replacement
- `voix-gui` — GUI prompt binary (pkexec-style)
- `voix-pam` — PAM helper (optional internal tool)

## Config

Lua config is in `/etc/voix/config.lua` or `lua/config.lua` for local dev.

## Build

```bash
mkdir build && cd build
cmake ..
make' > README.md

echo "✅ Voix project initialized successfully!"
