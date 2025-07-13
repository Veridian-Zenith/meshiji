cmake_minimum_required(VERSION 3.16)
project(voix LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Check for required dependencies
find_package(PkgConfig REQUIRED)

# Main Voix executable
add_executable(voix
    main.cpp
    config.cpp
    utils.cpp
)


# Include directories
target_include_directories(voix PRIVATE include)

# Link libraries
target_link_libraries(voix pam)

# Install targets
install(TARGETS voix
    RUNTIME DESTINATION bin
)

# Set proper permissions for installed binaries
install(CODE "execute_process(COMMAND chown root:root \${CMAKE_INSTALL_PREFIX}/bin/voix)")
install(CODE "execute_process(COMMAND chmod u+s \${CMAKE_INSTALL_PREFIX}/bin/voix)")
