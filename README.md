# Voix - A Modern, Secure Sudo Replacement

## Overview

Voix is a modern privilege escalation tool that combines the simplicity of `doas` with the power of `sudo`. It provides controlled command execution with elevated privileges while maintaining security and auditability. Voix is designed to be lean, auditable, and secure without the complexity of traditional sudo implementations.

## Quick Start

### Installation
See [INSTALL.md](INSTALL.md) for detailed installation instructions.

```bash
# Quick install on Ubuntu/Debian
sudo apt-get install cmake make gcc pkg-config lua5.3-dev libpam0g-dev
git clone https://github.com/Veridian-Zenith/Voix.git
cd Voix/src
cmake -B build && cmake --build build
sudo chown root:root build/voix && sudo chmod u+s build/voix
```

### Basic Usage
```bash
# Run commands with elevated privileges
voix id                    # Check effective user ID
voix systemctl status sshd # Manage system services
voix apt update            # Package management
voix firefox               # GUI applications
```

### Configuration
See [CONFIG.md](CONFIG.md) for comprehensive configuration options.

```bash
# Basic configuration
echo "permit persist $USER as root" | sudo tee /etc/voix.conf

# Validate configuration
voix check /etc/voix.conf
```

## Key Features

- **🔒 Security-First**: Principle of least privilege with fine-grained access control
- **🎯 Simple Configuration**: Doas-style syntax that's easy to read and maintain
- **🖥️ GUI Integration**: Native Polkit support for desktop environments
- **📊 Structured Logging**: JSON-formatted logs for security monitoring
- **⚡ Performance**: Fast authentication with intelligent caching
- **🔧 Modular Design**: Clean, maintainable codebase architecture

## Documentation

- **[📦 Installation](INSTALL.md)**: Build and install Voix
- **[⚙️ Configuration](CONFIG.md)**: Configure permissions and policies
- **[📖 Usage](USAGE.md)**: Command examples and advanced features
- **[🔐 Security](SECURITY.md)**: Security considerations and best practices
- **[🛠️ Development](DEVELOPMENT.md)**: Contributing and development guide

## Examples

### System Administration
```bash
# Service management
voix systemctl restart nginx
voix journalctl -u sshd -f

# Package management
voix pacman -Syu          # Arch Linux
voix apt update && apt upgrade  # Debian/Ubuntu
```

### Development
```bash
# Build tools
voix make
voix cmake --build build
voix gcc -o myapp myapp.c
```

### GUI Applications
```bash
# Desktop applications
voix firefox
voix code
voix gedit
```

## Support

- **Issues**: [GitHub Issues](https://github.com/Veridian-Zenith/Voix/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Veridian-Zenith/Voix/discussions)
- **Documentation**: See the detailed guides above

## License

Voix is licensed under the AGPLv3 license. See the LICENSE file for more details.

---

*Voix - Because security and simplicity should coexist.*
