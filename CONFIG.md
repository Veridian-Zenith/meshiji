# Configuration Guide

Voix uses a simple, doas-style configuration file located at `/etc/voix.conf`. The configuration syntax is intuitive and human-readable:

## Configuration Syntax

```
permit|deny [persist|nopasswd|keepenv] <user|group:name> [as <target>] [cmd <command>]
```

## Configuration Examples

### Basic User Permissions
```bash
# Allow user veridian to run any command as root with auth caching
permit persist veridian as root

# Allow all users in wheel group to run any command as root
permit group:wheel as root
```

### GUI Applications
```bash
# Allow user to run firefox with environment preservation
permit keepenv veridian cmd /usr/bin/firefox

# Allow user to run code editor with environment preservation
permit keepenv veridian cmd /usr/bin/code
```

### System Management
```bash
# Allow systemctl commands without password for active sessions
permit nopasswd veridian cmd /usr/bin/systemctl

# Allow journalctl for log viewing
permit veridian cmd /usr/bin/journalctl

# Allow dmesg for system diagnostics
permit veridian cmd /usr/bin/dmesg
```

### Package Management
```bash
# Allow package management with auth
permit veridian cmd /usr/bin/pacman
permit veridian cmd /usr/bin/apt
permit veridian cmd /usr/bin/yum
permit veridian cmd /usr/bin/dnf
```

### Development Tools
```bash
# Allow development tools
permit veridian cmd /usr/bin/gcc
permit veridian cmd /usr/bin/g++
permit veridian cmd /usr/bin/cmake
permit veridian cmd /usr/bin/make
```

### Security Rules
```bash
# Explicitly deny dangerous commands
deny veridian cmd /bin/rm -rf /
deny veridian cmd /usr/bin/dd
deny veridian cmd /usr/bin/mkfs
deny veridian cmd /usr/bin/fdisk
```

### Service Management
```bash
# Service management (restrictive)
permit veridian cmd /usr/bin/systemctl start *
permit veridian cmd /usr/bin/systemctl stop *
permit veridian cmd /usr/bin/systemctl restart *
permit veridian cmd /usr/bin/systemctl status *
```

### User Management
```bash
# User management (if needed)
permit veridian cmd /usr/bin/useradd
permit veridian cmd /usr/bin/usermod
permit veridian cmd /usr/bin/userdel
```

## Configuration Modifiers

### `persist`
- Enables authentication caching for 15 minutes
- Reduces need for repeated password entry
- Example: `permit persist veridian as root`

### `nopasswd`
- Allows command execution without password authentication
- Use with caution for security-sensitive commands
- Example: `permit nopasswd veridian cmd /usr/bin/systemctl status`

### `keepenv`
- Preserves environment variables for GUI applications
- Essential for X11 and Wayland applications
- Example: `permit keepenv veridian cmd /usr/bin/firefox`

## Legacy Lua Configuration

For backward compatibility, Voix also supports the legacy Lua configuration format at `/etc/voix/config.lua`:

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

## Configuration Validation

You can validate your configuration file using the built-in checker:

```bash
voix check /etc/voix.conf
```

This will display all rules and validate the syntax.

You can also use the validate command for more detailed output:

```bash
voix validate /etc/voix.conf
```

## Environment Variables

Voix respects several environment variables for configuration:

- `VOIX_CONFIG`: Path to configuration file (default: `/etc/voix.conf`)
- `VOIX_LOG_FILE`: Path to log file (default: `/var/log/voix.log`)
- `XDG_SESSION_TYPE`: Session type detection for GUI support
- `DISPLAY`: X11 display for GUI detection
- `WAYLAND_DISPLAY`: Wayland display for GUI detection

## Configuration Tips

1. **Start restrictive**: Begin with specific command permissions rather than blanket access
2. **Use groups**: Leverage system groups for easier permission management
3. **Test thoroughly**: Use `voix check` to validate your configuration
4. **Monitor logs**: Check `/var/log/voix.log` for security events
5. **Regular review**: Periodically audit your configuration for unnecessary permissions

## Security Considerations

- Avoid `nopasswd` for commands that can cause system damage
- Use specific command paths rather than wildcards when possible
- Regularly review logs for suspicious activity
- Keep the configuration file readable only by root: `chmod 600 /etc/voix.conf`
- Use `deny` rules to explicitly block dangerous commands
