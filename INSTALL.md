# Installation Guide

## For Arch Linux Users (AUR)

The easiest way to install Voix on Arch Linux is via the AUR:

```bash
# Install from AUR (using your preferred AUR helper)
yay -S voix
# or
paru -S voix
# or manually:
git clone https://aur.archlinux.org/voix.git
cd voix
makepkg -si
```

## Dependencies

Voix requires the following dependencies for compilation:

### Arch Linux
```bash
sudo pacman -S cmake clang pkgconf pam lua lua51
```

### Debian/Ubuntu
```bash
sudo apt-get install cmake clang pkg-config libpam0g-dev lua5.3-dev
```

### Fedora
```bash
sudo dnf install cmake clang pkgconf pam-devel lua-devel
```

## Building from Source

1. Clone the repository:
```bash
git clone https://github.com/Veridian-Zenith/Voix.git
cd Voix/src
```

2. Build the project (Voix uses Clang with ThinLTO for optimal performance):
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

## Post-Installation Setup

### 1. Create PAM Configuration
For Voix to authenticate users, create a PAM configuration file:

```bash
sudo bash -c 'cat > /etc/pam.d/voix << EOF
auth     required   pam_unix.so
account  required   pam_unix.so
EOF'
```

### 2. Set Up Initial Configuration
Create a basic configuration file:

```bash
sudo bash -c 'cat > /etc/voix.conf << EOF
# Allow your user to use Voix with authentication caching
permit persist $USER as root

# Allow wheel group to run system commands
permit group:wheel as root

# Allow package management
permit $USER cmd /usr/bin/pacman
permit $USER cmd /usr/bin/yay
EOF'

# Set proper permissions
sudo chmod 600 /etc/voix.conf
```

### 3. Create Required Directories
```bash
sudo mkdir -p /var/lib/voix
sudo chown root:root /var/lib/voix
sudo chmod 700 /var/lib/voix

sudo mkdir -p /var/log
sudo touch /var/log/voix.log
sudo chown root:root /var/log/voix.log
sudo chmod 640 /var/log/voix.log
```

## Testing the Installation

After installation, test Voix:

```bash
# Check version
voix --version

# Validate configuration
voix check /etc/voix.conf

# Test with a simple command (first time will require password)
voix id
```

## Optional: Polkit Support

For enhanced GUI integration in desktop environments, install Polkit:

### Arch Linux
```bash
sudo pacman -S polkit
```

### Debian/Ubuntu
```bash
sudo apt-get install libpolkit-agent-1-dev libpolkit-gobject-1-dev libgio-2.0-dev
```

### Fedora
```bash
sudo dnf install polkit-devel
```

## Building Release Version

For production builds, use release mode with optimizations:

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
```

## Troubleshooting

### Permission Denied Errors
If you get "Permission denied" errors, ensure the binary has the correct permissions:

```bash
sudo chown root:root /usr/local/bin/voix
sudo chmod u+s /usr/local/bin/voix
```

### PAM Authentication Issues
If authentication fails, check the PAM configuration:

```bash
# Test PAM configuration
sudo pam_tally2 --user=$USER --reset

# Verify PAM config
sudo cat /etc/pam.d/voix
```

### Missing Dependencies
If you get missing dependency errors during build:

```bash
# On Ubuntu/Debian
sudo apt-get install libpam0g-dev lua5.3-dev

# On Arch Linux
sudo pacman -S lua pam

# On Fedora
sudo dnf install pam-devel lua-devel
```

### Configuration Issues
If Voix complains about configuration:

```bash
# Validate and debug configuration
voix check /etc/voix.conf

# Check logs for more details
sudo tail -f /var/log/voix.log
```

### Build Issues
If compilation fails:

```bash
# Clean build directory
rm -rf build
cmake -B build
cmake --build build

# Check for specific errors
cmake --build build --verbose
