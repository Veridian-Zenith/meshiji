# Security Guide

## Overview

Voix is designed with security as a primary concern. This guide covers security features, best practices, and considerations for secure deployment.

## Security Features

### Principle of Least Privilege
- Commands must be explicitly permitted in configuration
- No default permissions - everything must be configured
- Fine-grained control over allowed operations

### Authentication
- PAM-based authentication with configurable modules
- Polkit integration for GUI environments
- Authentication caching with configurable timeouts
- Failed authentication attempt logging

### Environment Security
- Environment scrubbing by default to prevent attacks
- Selective environment preservation for GUI applications
- Protection against environment-based vulnerabilities

### Audit Logging
- Structured JSON logging for easy analysis
- Comprehensive audit trail of all actions
- Timestamps, user information, and success/failure status
- Configurable log levels and locations

## Configuration Security

### File Permissions
```bash
# Configuration file should be readable only by root
sudo chmod 600 /etc/voix.conf

# PAM configuration should be readable only by root
sudo chmod 600 /etc/pam.d/voix

# Log file should be readable only by root
sudo chmod 600 /var/log/voix.log
sudo chown root:root /var/log/voix.log
```

### Secure Configuration Practices

#### 1. Use Specific Commands
```bash
# Good - specific command
permit user cmd /usr/bin/systemctl

# Avoid - overly broad permissions
permit user as root  # Too permissive
```

#### 2. Leverage Groups
```bash
# Good - use system groups
permit group:wheel as root
permit group:developers cmd /usr/bin/make

# Avoid - individual user management
permit alice as root
permit bob as root
permit charlie as root
```

#### 3. Explicit Deny Rules
```bash
# Good - explicitly deny dangerous commands
permit user as root
deny user cmd /bin/rm -rf /
deny user cmd /usr/bin/dd
```

#### 4. Use nopasswd Judiciously
```bash
# Good - limited nopasswd for safe commands
permit nopasswd user cmd /usr/bin/systemctl status
permit nopasswd user cmd /usr/bin/journalctl

# Avoid - nopasswd for dangerous commands
permit nopasswd user cmd /usr/bin/rm  # Dangerous!
```

## Deployment Security

### Binary Permissions
```bash
# Ensure correct ownership and permissions
sudo chown root:root /usr/local/bin/voix
sudo chmod u+s /usr/local/bin/voix

# Verify permissions
ls -la /usr/local/bin/voix
# Should show: -rwsr-xr-x 1 root root ...
```

### PAM Configuration
```bash
# Secure PAM configuration
sudo chmod 600 /etc/pam.d/voix

# Test PAM configuration
sudo pam_tally2 --user=$USER --reset
```

### Log Rotation
```bash
# Configure log rotation for Voix logs
sudo bash -c 'cat > /etc/logrotate.d/voix << EOF
/var/log/voix.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 600 root root
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOF'
```

## Monitoring and Alerting

### Log Analysis
```bash
# Monitor Voix logs for suspicious activity
sudo tail -f /var/log/voix.log

# Search for failed authentication attempts
sudo grep "FAIL" /var/log/voix.log

# Search for successful privilege escalations
sudo grep "SUCCESS" /var/log/voix.log

# Monitor for unusual commands
sudo grep "rm\|dd\|mkfs" /var/log/voix.log
```

### Automated Monitoring
```bash
#!/bin/bash
# Security monitoring script

LOG_FILE="/var/log/voix.log"
ALERT_EMAIL="admin@example.com"

# Check for failed authentication attempts
FAIL_COUNT=$(grep "FAIL" "$LOG_FILE" | wc -l)
if [ "$FAIL_COUNT" -gt 10 ]; then
    echo "High number of failed authentication attempts: $FAIL_COUNT" | \
    mail -s "Voix Security Alert" "$ALERT_EMAIL"
fi

# Check for unusual commands
UNUSUAL_CMDS=$(grep -E "(rm|dd|mkfs|fdisk)" "$LOG_FILE" | wc -l)
if [ "$UNUSUAL_CMDS" -gt 0 ]; then
    echo "Unusual commands detected: $UNUSUAL_CMDS" | \
    mail -s "Voix Security Alert" "$ALERT_EMAIL"
fi
```

## Incident Response

### Suspicious Activity Detection
1. **Monitor logs regularly** for unauthorized access attempts
2. **Check for unusual commands** that shouldn't be executed
3. **Review configuration changes** for unauthorized modifications
4. **Audit user permissions** periodically

### Response Procedures

#### 1. Lock User Accounts
```bash
# Lock user account temporarily
sudo usermod -L suspicious_user

# Reset failed login attempts
sudo pam_tally2 --user=suspicious_user --reset
```

#### 2. Review and Update Configuration
```bash
# Validate current configuration
voix check /etc/voix.conf

# Review for overly permissive rules
voix validate /etc/voix.conf

# Tighten permissions if necessary
sudo vim /etc/voix.conf
```

#### 3. Analyze Logs
```bash
# Detailed log analysis
sudo grep "suspicious_user" /var/log/voix.log

# Check time patterns
sudo awk '{print $1, $2}' /var/log/voix.log | sort | uniq -c

# Check command patterns
sudo awk '{print $3}' /var/log/voix.log | sort | uniq -c
```

## Security Hardening

### Restrict Configuration Access
```bash
# Ensure only root can modify configuration
sudo chown root:root /etc/voix.conf
sudo chmod 600 /etc/voix.conf

# Set immutable flag (if supported)
sudo chattr +i /etc/voix.conf
```

### Network Security
```bash
# If Voix is accessible over network, restrict access
sudo ufw deny from 192.168.1.0/24 to any port 22
sudo ufw allow from 192.168.1.100 to any port 22  # Admin workstation only
```

### System Hardening
```bash
# Disable root SSH login
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Enable SSH key authentication
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Restart SSH service
sudo systemctl restart sshd
```

## Compliance Considerations

### Audit Requirements
- Maintain detailed logs of all privilege escalations
- Implement log retention policies
- Regular security audits and reviews

### Separation of Duties
- Different users for system administration vs. security monitoring
- Separate configuration management from execution
- Dual approval for critical changes

### Documentation
- Document all configuration changes
- Maintain change logs for security reviews
- Document incident response procedures

## Best Practices Summary

1. **Minimal Permissions**: Grant only necessary privileges
2. **Regular Audits**: Review configuration and logs regularly
3. **Secure Configuration**: Protect configuration files and logs
4. **Monitor Activity**: Watch for suspicious patterns
5. **Incident Response**: Have procedures for security incidents
6. **Documentation**: Keep security documentation current
7. **Testing**: Test configurations before deployment
8. **Updates**: Keep Voix and dependencies updated

## Emergency Procedures

### System Compromise Response
1. **Isolate the system** if compromise is suspected
2. **Disable Voix temporarily** if necessary:
   ```bash
   sudo chmod 755 /usr/local/bin/voix  # Remove setuid
   ```
3. **Analyze logs** for attack patterns
4. **Change all passwords** after incident resolution
5. **Review and update** security configuration

### Recovery
1. **Restore from backups** if data corruption occurred
2. **Reinstall Voix** if binary compromise suspected
3. **Update all credentials** after incident
4. **Review security policies** and update as needed

## Contact Information

For security-related issues:
- Security team: security@example.com
- Emergency contact: +1-555-0123
- Security reporting: https://example.com/security

Report security vulnerabilities responsibly to allow for coordinated disclosure.
