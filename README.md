# Voix - A Secure Privilege Management Tool

## Overview

Voix is a secure privilege management tool designed to provide controlled command execution with elevated privileges. Unlike traditional sudo implementations, Voix focuses on security and simplicity.

## Features

- **Controlled Privilege Escalation**: Execute commands with elevated privileges only when explicitly configured
- **Simple Configuration**: Easy-to-understand configuration format
- **PAM Authentication**: Secure authentication using Pluggable Authentication Modules
- **Shell Integration**: Properly executes commands within the user's shell environment

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
git clone https://github.com/Veridian-Zenith/Voix.git
cd Voix/src
```

2. Build the project:
```bash
cmake -B build
cmake --build build
```

3. Update permissions for the `voix` binary:
```bash
sudo chown root:root ./build/voix
sudo chmod u+s ./build/voix
```

4. Install the binary:
```bash
sudo install -o root -m 4755 build/voix /usr/local/bin/voix
```

**Note on running from the build directory:**

For security reasons, the `setuid` feature only works on executables owned by `root`. If you want to run `voix` directly from the `build` directory for testing, you must ensure the binary is owned by `root` and has the `setuid` bit set, as shown in step 3. The `install` command in step 4 handles this for the final installed binary in `/usr/local/bin`.

### PAM Configuration

For Voix to authenticate users, you must create a PAM configuration file at `/etc/pam.d/voix`. This file tells the system how to handle authentication for the `voix` service.

Create the file with the following content:
```bash
# /etc/pam.d/voix
auth     required   pam_unix.so
account  required   pam_unix.so
```

You can create this file using the following command:
```bash
sudo bash -c 'echo -e "auth     required   pam_unix.so\naccount  required   pam_unix.so" > /etc/pam.d/voix'
```

## Configuration

The configuration file is located at `/etc/voix/config.lua`. Here's an example configuration:

```lua
return {
  -- List of users who can run commands with elevated privileges
  users = {
    "root",
    "your_username"
  },

  -- List of groups whose members can run commands with elevated privileges
  groups = {
    "wheel",
    "admin"
  },

  -- Maximum number of authentication attempts
  max_auth_attempts = 3,

  -- (Optional) Path to the log file. If not set, no logs will be written.
  log_file = "/var/log/voix.log"
}
```

### Note for AUR Users

If you have installed Voix from the AUR, you will need to edit the configuration file at `/etc/voix/config.lua` to grant permissions to your user. Since you cannot use `voix` to edit its own configuration, you will need to use an alternative method to gain root privileges, such as:

*   Using `pkexec` to run your editor: `pkexec <your_editor> /etc/voix/config.lua`
*   Using `su` to run your editor: `su -c "<your_editor> /etc/voix/config.lua"`
*   Logging in as the `root` user in a TTY.

## Usage

To run a command with elevated privileges:
```bash
voix <command> [args...]
```

## Security Notes

- Voix runs commands with the current user's privileges by default
- Privilege escalation must be explicitly configured
- The binary must be owned by root with the setuid bit set for proper operation

## License

Voix is licensed under the AGPLv3 license. See the LICENSE file for more details.
