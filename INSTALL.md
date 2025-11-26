# Voix in Racket - Installation Guide

## Overview

This guide explains how to install and set up Voix in Racket, a modern privilege escalation tool that replaces sudo/doas with improved security and configurability.

## Prerequisites

- Racket 8.0 or later
- Linux system (Ubuntu, Debian, Arch, etc.)
- Root access for installation

## Installation Methods

### Method 1: Install from Racket Package Manager

```bash
# Install via raco (Racket's package manager)
raco pkg install voix-racket

# Create symlink for system-wide access
sudo ln -s $(raco pkg show voix-racket | grep "path:" | cut -d: -f2)/main.rkt /usr/local/bin/voix
```

### Method 2: Manual Installation

```bash
# Clone or download the Voix-racket files
cd /usr/local/lib
sudo mkdir voix-racket
sudo cp -r /path/to/voix-racket/* voix-racket/

# Create symlink for system access
sudo ln -s /usr/local/lib/voix-racket/main.rkt /usr/local/bin/voix

# Make executable
sudo chmod +x /usr/local/bin/voix
```

### Method 3: From Source

```bash
# Install dependencies
raco pkg install json racket-doc

# Run from source directory
cd /path/to/voix-racket
raco exec main.rkt --help
```

## Post-Installation Setup

### 1. Set Permissions

```bash
# Make owned by root with setuid bit
sudo chown root:root /usr/local/bin/voix
sudo chmod u+s /usr/local/bin/voix

# Secure permissions
sudo chmod 755 /usr/local/bin/voix
```

### 2. Create Directories

```bash
# Create configuration directory
sudo mkdir -p /etc/voix
sudo chmod 700 /etc/voix

# Create log directory
sudo mkdir -p /var/log
sudo chmod 755 /var/log

# Create auth cache directory
sudo mkdir -p /var/lib/voix/auth
sudo chmod 700 /var/lib/voix/auth
```

### 3. Create Configuration

```bash
# Copy sample configuration
sudo cp test-config.conf /etc/voix.conf

# Edit for your system
sudo $EDITOR /etc/voix.conf
```

### 4. Test Installation

```bash
# Test version display
raco exec main.rkt --version

# Test help
raco exec main.rkt --help

# Test configuration validation
raco exec main.rkt check test-config.conf

# Test detailed validation
raco exec main.rkt validate test-config.conf
```

## Configuration

See `CONFIG-EXAMPLES.md` for comprehensive configuration examples.

## Usage Examples

### Basic Usage

```bash
# Run single command with elevated privileges (needs proper setup)
raco exec main.rkt systemctl status sshd
raco exec main.rkt apt update

# Run GUI applications (needs keepenv configuration)
raco exec main.rkt firefox
```

### Configuration Management

```bash
# Validate configuration
raco exec main.rkt check test-config.conf

# Detailed validation
raco exec main.rkt validate test-config.conf
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Requires setuid root for full functionality
2. **Configuration Errors**: Use `voix check` to validate syntax
3. **Racket Issues**: Verify installation with `racket --version`

## Security Audit

The Racket implementation provides enhanced security:

- **Memory Safety**: Racket's garbage collection eliminates buffer overflow vulnerabilities
- **Type Safety**: Strong typing prevents common programming errors
- **Input Validation**: Comprehensive path traversal and injection protection
- **Audit Trail**: JSON-formatted logging for security analysis
