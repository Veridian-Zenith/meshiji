#!/usr/bin/env fish

# Voix build script for pacman-based systems
# Compatible with fish, bash, and zsh

function usage
    echo "Usage: build.fish [options]"
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -i, --install  Install dependencies only"
    echo "  -b, --build    Build the project only"
    echo "  -c, --clean    Clean the build directory"
    echo "  -r, --run      Run the application after building"
    exit 0
end

function check_sudo
    # Check if we have sudo or doas available
    if command -v sudo >/dev/null
        return 0
    else if command -v doas >/dev/null
        return 0
    else
        echo "Error: Neither sudo nor doas found. Please install one of them."
        exit 1
    end
end

function is_package_installed
    set pkg $argv[1]
    pacman -Q $pkg >/dev/null 2>&1
    return $status
end

function install_dependencies
    echo "Checking and installing dependencies using pacman..."

    # Check for sudo/doas
    check_sudo

    # List of required packages
    set -l packages cmake make gcc pkgconf

    # Check and install each package
    for pkg in $packages
        if not is_package_installed $pkg
            echo "Installing $pkg..."
            if command -v sudo >/dev/null
                sudo pacman -S --needed --noconfirm $pkg
            else
                doas pacman -S --needed --noconfirm $pkg
            end
        else
            echo "$pkg is already installed"
        end
    end

    echo "Dependencies checked and installed successfully"
end

function build_project
    echo "Building Voix..."

    # Clean the build directory before building
    if test -d build
        rm -rf build
    end
    mkdir build
    cd build

    # Run cmake and make
    cmake ..
    make

    cd ..
    echo "Build completed"
end

function setup_application
    echo "Setting up Voix application..."

    # Check for sudo/doas
    check_sudo

    # Set ownership and permissions for the binary
    if test -f build/voix
        echo "Setting up voix binary..."
        if command -v sudo >/dev/null
            sudo chown root:root build/voix
            sudo chmod u+s build/voix
        else
            doas chown root:root build/voix
            doas chmod u+s build/voix
        end
    else
        echo "Error: voix binary not found in build directory"
        exit 1
    end

    # Create PAM configuration
    echo "Setting up PAM configuration..."
    if command -v sudo >/dev/null
        echo "auth     required   pam_unix.so" | sudo tee /etc/pam.d/voix > /dev/null
        echo "account  required   pam_unix.so" | sudo tee -a /etc/pam.d/voix > /dev/null
    else
        echo "auth     required   pam_unix.so" | doas tee /etc/pam.d/voix > /dev/null
        echo "account  required   pam_unix.so" | doas tee -a /etc/pam.d/voix > /dev/null
    end

    echo "Application setup completed"
end

function clean_project
    echo "Cleaning build directory..."
    if test -d build
        rm -rf build
    end
    echo "Clean completed"
end

# Main script execution
set -l install_only false
set -l build_only false
set -l clean_only false

# Parse command line arguments
for arg in $argv
    switch $arg
        case "-h" "--help"
            usage
        case "-i" "--install"
            set install_only true
        case "-b" "--build"
            set build_only true
        case "-c" "--clean"
            set clean_only true
        case "*"
            # This is not an option, but a command to run
            break
    end
end

# Execute based on options
if not $install_only and not $build_only and not $clean_only
    install_dependencies
    build_project
    setup_application
else if $install_only
    install_dependencies
else if $build_only
    build_project
else if $clean_only
    clean_project
end
