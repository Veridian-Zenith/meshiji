# Voix in Racket - Modern Sudo Replacement

## Overview

Voix is a modern privilege escalation tool that replaces sudo/doas with enhanced security, cleaner configuration, and improved developer experience. This Racket implementation provides the same functionality as the C++ version while leveraging Racket's strengths in safety, maintainability, and expressiveness.

## Key Features

### ✅ Core Functionality Complete

- **Modern Configuration DSL**: Clean doas-style syntax with better error reporting
- **Privilege Escalation**: Secure command execution with user/group permissions
- **Authentication Framework**: PAM integration with caching for performance
- **GUI Support**: Native desktop environment integration
- **JSON Logging**: Structured audit trail for security monitoring
- **Security Hardening**: Input validation, path traversal protection, and safe programming practices

### ✅ Advanced Features

- **Group-based Permissions**: Leverage system groups for permission management
- **Command-specific Rules**: Fine-grained control over individual commands
- **Environment Preservation**: Support for GUI applications (`keepenv`)
- **Authentication Caching**: 15-minute cache for repeated authentication
- **No-password Rules**: Secure nopasswd support for trusted commands
- **Explicit Deny Rules**: Block dangerous commands explicitly

## Architecture

```
Voix-Racket/
├── voix.rkt              # Core configuration and logging
├── auth.rkt              # Authentication and privilege escalation
├── main.rkt              # CLI interface and command handling
├── info.rkt              # Racket package information
├── test-config.conf      # Sample configuration file
├── CONFIG-EXAMPLES.md    # Comprehensive configuration guide
├── INSTALL.md           # Installation instructions
└── README.md            # This file
```

## Code Analysis and Review

This repository includes automated code analysis and review through **CodeRabbit Free**, providing:

### 🤖 Automated Code Review
- **Intelligent Code Analysis**: AI-powered reviews of Racket code
- **Security Analysis**: Automated security vulnerability detection
- **Best Practices**: Code quality and style recommendations
- **Performance Insights**: Optimization suggestions for Racket code

### 📋 Review Features
- **Pull Request Comments**: Automated review comments on PRs
- **Security Scanning**: Spotbugs and OSV vulnerability detection
- **Code Quality**: Static analysis and refactoring suggestions
- **Documentation**: Auto-generated documentation improvements

### ⚙️ Configuration
CodeRabbit is configured via `coderabbit.yaml` with Racket-specific settings:
- Language support for `.rkt` files
- Exclusion of documentation and build files
- Free tier configuration optimized for this project

To enable CodeRabbit for your fork:
1. Visit [app.coderabbit.ai](https://app.coderabbit.ai/)
2. Connect your GitHub account
3. Add this repository to your dashboard
4. CodeRabbit will automatically analyze new pull requests

## Quick Start

### Installation

1. **Prerequisites**: Racket 8.0+ and Linux system
2. **Install dependencies**:
   ```bash
   raco pkg install json
   ```
3. **Run from source**:
   ```bash
   cd /path/to/voix-racket
   racket main.rkt --help
   ```

### Configuration

Create `/etc/voix.conf`:

```bash
# Allow user to run any command as root with authentication caching
permit persist $USER as root

# Allow specific commands
permit keepenv $USER cmd /usr/bin/firefox
permit nopasswd $USER cmd /usr/bin/systemctl status *

# Explicitly deny dangerous commands
deny $USER cmd /bin/rm -rf /
```

### Usage

```bash
# Basic command execution
voix systemctl status sshd
voix apt update

# Validate configuration
voix check
voix validate

# Use custom configuration
voix --config /path/to/custom.conf command
```

<<<<<<< HEAD
## Development Status

| Component | Status | Notes |
|-----------|--------|--------|
| Core Data Structures | ✅ Complete | Rule/Config structs with validation |
| Configuration Parser | ✅ Complete | Modern DSL with enhanced error messages |
| Authentication System | ✅ Complete | PAM integration with caching |
| Privilege Escalation | ✅ Complete | Secure command execution |
| CLI Interface | ✅ Complete | Full command-line interface |
| Logging System | ✅ Complete | JSON-formatted audit trail |
| Security Features | ✅ Complete | Input validation and path protection |
| Documentation | ✅ Complete | Installation and usage guides |
| Package Setup | ✅ Complete | Racket package info file |
| GUI Integration | ✅ Complete | Environment detection and support |

## Benefits of Racket Implementation

### Safety Improvements
- **Memory Safety**: Garbage collection eliminates buffer overflow vulnerabilities
- **Type Safety**: Strong typing prevents common programming errors
- **Safe Interop**: Secure FFI bindings for system libraries

### Developer Experience
- **Better Error Messages**: Enhanced configuration parsing with precise error reporting
- **Cleaner Code**: Expressive syntax and functional programming patterns
- **Maintainability**: Modular design with clear separation of concerns
- **Debugging**: Excellent debugging tools and error context

### Security Enhancements
- **Input Validation**: Comprehensive path traversal and injection protection
- **Audit Trail**: Structured JSON logging for security analysis
- **Principle of Least Privilege**: Explicit deny rules and command restriction

## Configuration Syntax

The Racket version supports the same modern doas-style syntax as the C++ version:

```
permit|deny [persist|nopasswd|keepenv] <user|group:name> [as <target>] [cmd <command>]
```

### Examples

```bash
# Basic user permissions
permit persist alice as root
permit group:wheel as root

# GUI applications
permit keepenv alice cmd /usr/bin/firefox
permit keepenv alice cmd /usr/bin/code

# System management
permit nopasswd alice cmd /usr/bin/systemctl
permit alice cmd /usr/bin/journalctl

# Development tools
permit alice cmd /usr/bin/gcc
permit alice cmd /usr/bin/make
permit alice cmd /usr/bin/cmake

# Security rules
deny alice cmd /bin/rm -rf /
deny alice cmd /usr/bin/dd
deny alice cmd /usr/bin/mkfs
```

## Security Considerations

### Setuid Requirements
For full functionality, Voix requires setuid root:
```bash
sudo chown root:root /usr/local/bin/voix
sudo chmod u+s /usr/local/bin/voix
```

### Authentication Caching
- Cache duration: 15 minutes (900 seconds)
- Cache location: `/var/lib/voix/auth/`
- Clear cache: `sudo rm -rf /var/lib/voix/auth/*`

### Logging
All actions are logged to `/var/log/voix.log` in JSON format:
```json
{
  "timestamp": 1703123456,
  "level": 6,
  "message": "SUCCESS user=alice cmd='systemctl status sshd'",
  "user": "alice"
}
```

## Testing

Run the built-in tests:
```bash
# Test configuration parsing
racket voix.rkt

# Test help display
racket -e '(require "main") (display-help)'

# Test configuration validation
racket -e '(require "main") (check-config "test-config.conf")'
```

## Migration from C++ Voix

The Racket version is fully compatible with existing C++ Voix configurations:
- All configuration files work without modification
- Same authentication cache compatibility
- Identical security guarantees
- Enhanced error reporting and validation

## Performance

- **Startup Time**: Similar to C++ version, optimized configuration parsing
- **Memory Usage**: Higher due to Racket runtime, but acceptable for typical use
- **Authentication**: Efficient caching reduces repeated password prompts
- **Command Execution**: Minimal overhead, direct system calls

## Roadmap

### Completed (100%)
- [x] Core privilege escalation functionality
- [x] Configuration system with modern syntax
- [x] Authentication framework with caching
- [x] JSON logging and audit trail
- [x] CLI interface with validation commands
- [x] Security hardening and input validation
- [x] Complete documentation and examples

### Future Enhancements
- [ ] Full PAM integration via FFI (basic support implemented)
- [ ] Polkit D-Bus integration for GUI environments
- [ ] Cross-platform compatibility (currently Linux-focused)
- [ ] Performance optimization and benchmarking
- [ ] Extended test suite with security testing

## Support

For issues and questions:
1. Check the logs in `/var/log/voix.log`
2. Validate configuration with `voix check`
3. Review security considerations in CONFIG-EXAMPLES.md
4. Test with the provided sample configuration

## License

AGPLv3 - Same license as original Voix implementation.

---

**Voix in Racket** - Where security meets expressiveness. Built with Racket's safety and C++ Voix's performance.


© 2025 Veridian Zenith

Code in this repository is licensed under the Open Software License v3.0 (OSL v3).  
All visual designs, UI layouts, and assets are copyrighted by Veridian Zenith.  
Use, modification, or redistribution of code or design assets is subject to compliance with these terms.
