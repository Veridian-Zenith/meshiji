cmake_minimum_required(VERSION 3.16)
project(voix LANGUAGES CXX)

# Use clang++ as the compiler
set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_C_COMPILER clang)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Check for required dependencies
find_package(PkgConfig REQUIRED)

# Find Lua
find_package(PkgConfig REQUIRED)
pkg_check_modules(LUA lua5.3)

if (LUA_FOUND)
    set(LUA_INCLUDE_DIRS ${LUA_INCLUDE_DIRS})
    set(LUA_LIBRARIES ${LUA_LIBRARIES})
else()
    # Fallback to manual search
    find_path(LUA_INCLUDE_DIR lua.h
        /usr/include/lua5.3
        /usr/include
        /usr/local/include/lua5.3
        /usr/local/include
    )

    find_library(LUA_LIBRARY lua5.3
        /usr/lib/x86_64-linux-gnu
        /usr/lib
        /usr/local/lib
    )

    if (LUA_INCLUDE_DIR AND LUA_LIBRARY)
        set(LUA_FOUND TRUE)
        set(LUA_INCLUDE_DIRS ${LUA_INCLUDE_DIR})
        set(LUA_LIBRARIES ${LUA_LIBRARY})
    else ()
        message(FATAL_ERROR "Lua not found. Please install liblua5.3-dev or lua5.3 development package.")
    endif()
endif()

# Optional Polkit support for GUI environments
pkg_check_modules(POLKIT polkit-agent-1 polkit-gobject-1 gio-2.0)
if (POLKIT_FOUND)
    set(HAVE_POLKIT TRUE)
    add_compile_definitions(HAVE_POLKIT)
    message(STATUS "Polkit support enabled")
else()
    message(STATUS "Polkit not found - GUI authentication will fall back to PAM")
endif()

add_compile_definitions(_GNU_SOURCE)

# Main Voix executable (single binary with all functionality)
add_executable(voix
    main.cpp
    config.cpp
    utils.cpp
    auth.cpp
    polkit.cpp
    logging.cpp
    password.cpp
    lua_config.cpp
    env.cpp
)

# Include directories
target_include_directories(voix PRIVATE include ${LUA_INCLUDE_DIRS})

# Link libraries
target_link_libraries(voix pam ${LUA_LIBRARIES})
if (POLKIT_FOUND)
    target_link_libraries(voix ${POLKIT_LIBRARIES})
    target_include_directories(voix PRIVATE ${POLKIT_INCLUDE_DIRS})
endif()

# Install targets
install(TARGETS voix
    RUNTIME DESTINATION bin
)

# Set proper permissions for installed binaries
install(CODE "execute_process(COMMAND chown root:root \${CMAKE_INSTALL_PREFIX}/bin/voix)")
install(CODE "execute_process(COMMAND chmod u+s \${CMAKE_INSTALL_PREFIX}/bin/voix)")

# Install polkit policy and rules if polkit is available
if (POLKIT_FOUND)
    install(FILES org.veridian.voix.policy
        DESTINATION /usr/share/polkit-1/actions/
        RENAME org.veridian.voix.policy
    )
    install(FILES 10-voix.rules
        DESTINATION /etc/polkit-1/rules.d/
        RENAME 10-voix.rules
    )
endif()
