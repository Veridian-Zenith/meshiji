# Usage Guide

## Basic Usage

To run a command with elevated privileges:
```bash
voix <command> [args...]
```

## Command Examples

### System Information
```bash
# Run a single command as root
voix id

# Check who you are (will show root if configured)
voix whoami
```

### System Management
```bash
# Run systemctl commands
voix systemctl status sshd
voix systemctl restart nginx
voix systemctl start docker

# View system logs
voix journalctl -f
voix dmesg
```

### Package Management
```bash
# Update system packages
voix pacman -Syu          # Arch Linux
voix apt update && apt upgrade  # Debian/Ubuntu
voix dnf update           # Fedora
```

### GUI Applications
```bash
# Run GUI applications with environment preservation
voix firefox
voix chromium
voix code
voix gedit
```

### Development Tools
```bash
# Run development tools
voix make
voix cmake --build build
voix gcc -o myprogram myprogram.c
```

### Network Tools
```bash
# Run network diagnostic tools
voix ping google.com
voix traceroute github.com
voix nmap -sn 192.168.1.0/24
```

## Advanced Usage

### Configuration Management
```bash
# Check configuration syntax
voix check /etc/voix.conf

# Validate and display configuration
voix validate /etc/voix.conf

# Display version information
voix --version
voix -v

# Display help
voix --help
voix -h
```

### Environment Variables

Voix respects several environment variables for configuration:

- `VOIX_CONFIG`: Path to configuration file (default: `/etc/voix.conf`)
- `VOIX_LOG_FILE`: Path to log file (default: `/var/log/voix.log`)
- `XDG_SESSION_TYPE`: Session type detection for GUI support
- `DISPLAY`: X11 display for GUI detection
- `WAYLAND_DISPLAY`: Wayland display for GUI detection

## GUI Integration

Voix automatically detects GUI environments and uses Polkit for authentication when available:

### X11 Environment
- Uses Polkit authentication dialogs
- Preserves DISPLAY and other X11 variables
- Supports GUI applications seamlessly

### Wayland Environment
- Uses Polkit authentication dialogs
- Preserves WAYLAND_DISPLAY and other Wayland variables
- Supports modern GUI applications

### TTY Environment
- Falls back to traditional PAM authentication
- Text-based password prompts
- Full terminal functionality

## Authentication Caching

Voix supports authentication caching to improve user experience:

### Persistent Authentication
- Commands with `persist` modifier cache authentication for 15 minutes
- Reduces need for repeated password entry
- Automatically expires after timeout

### Example
```bash
# First command requires authentication
voix systemctl status sshd

# Subsequent commands within 15 minutes don't require re-auth
voix systemctl restart sshd
voix journalctl -u sshd
```

## Security Features

### Command Whitelisting
- Only explicitly allowed commands can be executed
- Fine-grained control over permitted operations
- Prevents execution of unauthorized commands

### Environment Scrubbing
- By default, scrubs environment variables for security
- `keepenv` modifier preserves essential variables for GUI applications
- Protects against environment-based attacks

### Structured Logging
- All actions are logged with structured JSON format
- Easy to parse and analyze for security monitoring
- Includes timestamps, user information, and success/failure status

## Best Practices

### For Users
1. **Use specific commands**: Avoid blanket permissions when possible
2. **Leverage groups**: Use system groups for easier permission management
3. **Monitor logs**: Check `/var/log/voix.log` for security events
4. **Test configurations**: Use `voix check` to validate setup

### For Administrators
1. **Principle of least privilege**: Grant minimum necessary permissions
2. **Regular audits**: Review configuration and logs periodically
3. **Secure configuration**: Set proper file permissions on `/etc/voix.conf`
4. **Monitor usage**: Watch for unusual patterns in logs

## Troubleshooting

### Common Issues

#### "Command not permitted"
- Check your configuration in `/etc/voix.conf`
- Ensure your user or group is listed
- Verify the command path matches exactly

#### "Permission denied"
- Ensure the Voix binary has correct permissions:
  ```bash
  sudo chown root:root /usr/local/bin/voix
  sudo chmod u+s /usr/local/bin/voix
  ```

#### Authentication failures
- Check PAM configuration in `/etc/pam.d/voix`
- Verify your user account is not locked
- Check system logs for PAM errors

#### GUI applications not working
- Ensure `keepenv` modifier is used for GUI commands
- Check that DISPLAY or WAYLAND_DISPLAY is set
- Verify Polkit is installed and running

### Getting Help

```bash
# Display help
voix --help

# Check configuration
voix check /etc/voix.conf

# View logs
sudo tail -f /var/log/voix.log
```

## Integration with Scripts

Voix can be safely used in scripts:

```bash
#!/bin/bash
# Safe script using Voix

# Update system packages
voix apt update
voix apt upgrade -y

# Restart service
voix systemctl restart myapp

# Check service status
if voix systemctl is-active myapp; then
    echo "Service is running"
else
    echo "Service is not running"
fi
```

Note: Scripts should handle authentication failures gracefully and provide appropriate error messages to users.
