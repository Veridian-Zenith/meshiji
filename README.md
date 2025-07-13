# Voix - A Modern Privilege Escalation Tool

## Overview

Voix is a modern privilege escalation tool designed to replace traditional tools like `sudo` and `doas`. It provides a secure way to execute commands with elevated privileges while maintaining a clean and user-friendly interface.

## Features

### Current Implementation

1. **CLI Tool**:
   - Secure password prompt with hidden input
   - Configurable user and group permissions
   - Logging of authentication attempts
   - PAM integration for authentication

2. **GUI Interface**:
   - Support for GTK 4/5 and Qt 5/6 backends
   - Black and gold Hyprland-style theme
   - Cross-platform compatibility

3. **PAM Helper**:
   - Authentication backend
   - Integration with system authentication

4. **Build System**:
   - CMake-based build configuration
   - Multi-shell compatible build script (fish, bash, zsh)
   - Dependency management

### Work in Progress

1. **GUI Improvements**:
   - Enhanced theme support
   - Better error handling and user feedback
   - Additional customization options

2. **Security Enhancements**:
   - More granular permission controls
   - Enhanced logging capabilities
   - Additional authentication methods

3. **Documentation**:
   - Complete API documentation
   - Usage examples and tutorials
   - Configuration guide

## Installation

### Dependencies

#### Arch Linux
```bash
sudo pacman -S gtk4 qt5-base qt6-base cmake make gcc pkgconf
```

#### Debian/Ubuntu
```bash
sudo apt-get install libgtk-4-dev qtbase5-dev qt6-base-dev cmake make gcc pkg-config
```

#### Fedora
```bash
sudo dnf install gtk4-devel qt5-devel qt6-devel cmake make gcc pkgconf
```

### Building

1. Clone the repository:
```bash
git clone https://github.com/yourusername/voix.git
cd voix
```

2. Make the build script executable:
```bash
chmod +x build.fish
```

3. Build the project:
```bash
./build.fish
```

## Usage

### CLI Tool
```bash
voix <command> [args...]
```

### GUI Tool
```bash
voix-gui
```

## Configuration

The main configuration file is located at `/etc/voix/config.lua`. You can also use a local configuration file at `lua/config.lua`.

Example configuration:
```lua
return {
  users = {
    "root",
    "yourusername"
  },
  groups = {
    "wheel",
    "admin"
  },
  max_auth_attempts = 3,
  log_file = "/var/log/voix.log"
}
```

## Project Structure

```
.
├── build.fish          # Build script (fish, bash, zsh compatible)
├── CMakeLists.txt      # CMake build configuration
├── include/            # Header files
│   ├── auth.hpp
│   ├── config.hpp
│   └── utils.hpp
├── lua/
│   └── config.lua      # Default configuration
├── pam/
│   └── voix-pam-helper.cpp # PAM helper implementation
├── src/
│   ├── auth.cpp        # Authentication implementation
│   ├── config.cpp      # Configuration handling
│   ├── main.cpp        # Main CLI implementation
│   └── utils.cpp       # Utility functions
├── themes/
│   └── black_gold_hyprland/ # Default theme
│       ├── gtk.css     # GTK theme
│       └── qt.qss       # Qt theme
└── gui/
    └── main.cpp         # GUI implementation
```

## Missing Parts and Future Work

1. **Additional Theme Support**:
   - More theme options
   - Theme customization tools

2. **Enhanced Security Features**:
   - Time-based access controls
   - Command-specific permissions
   - Audit logging

3. **Additional Backend Support**:
   - Wayland compatibility improvements
   - Additional authentication methods

4. **Documentation**:
   - Complete API documentation
   - More detailed usage examples
   - Troubleshooting guide

5. **Testing**:
   - Comprehensive test suite
   - CI/CD pipeline integration

## Contributing

We welcome contributions to Voix! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to your branch
5. Open a pull request

## License

Voix is licensed under the AGPLv3 license. See the LICENSE file for more details.
