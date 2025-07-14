# Voix - A Modern Privilege Escalation Tool

## Overview

Voix is a modern privilege escalation tool designed to replace traditional tools like `sudo` and `doas`. It provides a secure way to execute commands with elevated privileges while maintaining a clean and user-friendly interface. Voix uses PAM for authentication, creating and using /etc/pam.d/voix for PAM authentication, making it a robust alternative to existing privilege escalation tools. (Upload to AUR planned)

## Features

-   **Advanced Rule-Based Permissions**: Configure exactly who can run what commands, similar to `sudoers`.
-   **Run As Arbitrary User**: Execute commands as any user on the system, not just root, via the `run_as_user` option.
-   **Passwordless Execution**: Allow specific commands to be run without a password prompt via a `nopasswd` flag.
-   **Robust Configuration**: Uses the Lua C API for parsing a flexible and powerful configuration file.
-   **Secure PAM Authentication**: Integrates with the system's Pluggable Authentication Modules (PAM) for authentication.
-   **Shell Integration**: Correctly executes commands within the user's shell, allowing aliases and functions to work.
-   **Syslog Logging**: Logs all actions to `syslog` for easy integration with system monitoring tools.
-   **Safe & Modular Codebase**: Refactored for improved modularity, robustness, and memory safety.

## Installation

### Dependencies

#### Arch Linux
```bash
sudo pacman -S cmake make gcc pkgconf
```

#### Debian/Ubuntu
```bash
sudo apt-get install cmake make gcc pkg-config
```

#### Fedora
```bash
sudo dnf install cmake make gcc pkgconf
```

### Building

1. Clone the repository:
```bash
git clone https://github.com/yourusername/voix.git
cd voix
```

2. Build the project:
```bash
cd src
cmake -B build
cmake --build build
```

## Usage

### CLI Tool
```bash
voix <command> [args...]
```


## Configuration

Configuration is handled in `/etc/voix/config.lua`, which uses a Lua table to define a set of rules. Voix processes rules in order and stops at the first one that matches the user and command.

### Rule Properties

-   `users` (table): A list of usernames this rule applies to.
-   `groups` (table): A list of group names this rule applies to.
-   `commands` (table): A list of full command strings the user can run. A value of `"ALL"` allows any command.
-   `run_as_user` (string, optional): The username to run the command as. Defaults to `"root"`.
-   `nopasswd` (boolean, optional): If `true`, no password will be required for this rule. Defaults to `false`.

### Example Configuration

```lua
-- /etc/voix/config.lua
return {
  -- Global settings
  max_auth_attempts = 3,

  -- Permission rules
  rules = {
    -- Rule 1: Members of the 'wheel' group can run any command as root.
    {
      groups = { "wheel" },
      commands = { "ALL" }
      -- run_as_user defaults to "root"
    },

    -- Rule 2: User 'jane' can update packages without a password.
    {
      users = { "jane" },
      commands = { "/usr/bin/apt-get update", "/usr/bin/apt-get upgrade" },
      nopasswd = true
    },

    -- Rule 3: Members of 'developers' can restart a service as the 'webapp' user.
    {
      groups = { "developers" },
      commands = { "/usr/bin/systemctl restart myapp.service" },
      run_as_user = "webapp"
    }
  }
}
```

## Project Structure

```
.
├── .gitignore
├── PKGBUILD
├── README.md
├── src/
│   ├── .gitignore
│   ├── build.fish
│   ├── CMakeLists.txt
│   ├── config.cpp
│   ├── LICENSE
│   ├── LICENSE-AGPLv3
│   ├── LICENSE-VCL1.0
│   ├── main.cpp
│   ├── utils.cpp
│   ├── include/
│   │   ├── config.hpp
│   │   └── utils.hpp
│   └── lua/
│       └── config.lua
```

## Missing Parts and Future Work

1. **Enhanced Security Features**:
   - Time-based access controls
   - Command-specific permissions
   - Audit logging

2. **Additional Backend Support**:
   - Additional authentication methods

3. **Documentation**:
   - More detailed usage examples
   - Troubleshooting guide

4. **Testing**:
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

Voix is dual-licensed under the AGPLv3 and VCL 1.0 licenses. See the src/LICENSE file for more details.
(IMPORTANT - The VCL 1.0 license is for commercial use, while the AGPLv3 license is for all other uses. Please use the appropriate license for your use case.)
