# Installation Guide

## Dependencies

### Arch Linux
```bash
sudo pacman -S cmake clang pkgconf
```

### Debian/Ubuntu
```bash
sudo apt-get install cmake clang pkg-config
```

### Fedora
```bash
sudo dnf install cmake clang pkgconf
```

## Building

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

## PAM Configuration

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

## Optional: Polkit Support

For GUI environment support, install Polkit development packages:

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

## Testing the Installation

After installation, you can test Voix:

```bash
# Check if the binary works
voix --version

# Test configuration validation (will fail until config is set up)
voix check /etc/voix.conf
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
```

### Missing Dependencies

If you get missing dependency errors during build:

```bash
# On Ubuntu/Debian
sudo apt-get install lua5.3-dev libpam0g-dev

# On Arch Linux
sudo pacman -S lua pam

# On Fedora
sudo dnf install lua-devel pam-devel
