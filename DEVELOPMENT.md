# Development Guide

## Project Structure

```
Voix/
├── src/                    # Source code
│   ├── main.cpp           # Main application logic
│   ├── config.cpp         # Text configuration parsing
│   ├── auth.cpp           # PAM authentication
│   ├── polkit.cpp         # GUI environment integration
│   ├── logging.cpp        # Structured JSON logging
│   ├── password.cpp       # Secure password input
│   ├── lua_config.cpp     # Lua configuration support
│   ├── env.cpp           # Environment scrubbing
│   ├── utils.cpp         # Minimal utilities
│   └── include/          # Header files
│       ├── config.hpp     # Configuration structures
│       ├── auth.hpp      # Authentication interfaces
│       ├── polkit.hpp    # Polkit integration
│       ├── logging.hpp   # Logging interfaces
│       ├── password.hpp  # Password input interfaces
│       ├── lua_config.hpp # Lua configuration interfaces
│       ├── env.hpp      # Environment interfaces
│       └── utils.hpp    # Utility interfaces
├── docs/                  # Documentation
│   ├── INSTALL.md        # Installation guide
│   ├── CONFIG.md         # Configuration guide
│   ├── USAGE.md          # Usage examples
│   └── SECURITY.md       # Security considerations
├── tests/                 # Test files
│   └── test_voix.sh      # Integration test suite
├── CMakeLists.txt        # Build configuration
├── version.lua           # Version information
└── README.md             # Main project overview
```

## Building from Source

### Prerequisites
```bash
# Required dependencies
sudo apt-get install cmake clang pkg-config lua5.3-dev libpam0g-dev

# Optional for GUI support
sudo apt-get install libpolkit-agent-1-dev libpolkit-gobject-1-dev libgio-2.0-dev
```

### Build Process
```bash
# Clone repository
git clone https://github.com/Veridian-Zenith/Voix.git
cd Voix/src

# Configure build
mkdir build && cd build
cmake ..

# Build
make

# Install (requires root)
sudo make install
```

### Development Build
```bash
# Enable debug symbols and disable optimizations
cmake -DCMAKE_BUILD_TYPE=Debug ..

# Enable verbose output
make VERBOSE=1

# Run tests
../test_voix.sh
```

## Code Organization

### Modular Design
Each major functionality is separated into its own module:

- **config.cpp**: Configuration file parsing and validation
- **auth.cpp**: PAM authentication and user management
- **polkit.cpp**: GUI environment detection and Polkit integration
- **logging.cpp**: Structured logging with JSON output
- **password.cpp**: Secure password input handling
- **lua_config.cpp**: Legacy Lua configuration support
- **env.cpp**: Environment variable management

### Header Organization
- Each module has a corresponding header file
- Headers use include guards to prevent multiple inclusion
- Forward declarations minimize compilation dependencies

## Adding New Features

### 1. Create Module Files
```bash
# Create header file
touch src/include/new_feature.hpp
touch src/new_feature.cpp
```

### 2. Implement Interface
```cpp
// src/include/new_feature.hpp
#pragma once
#include <string>

// New feature interface
void new_feature_function(const std::string& param);

```

### 3. Update CMakeLists.txt
```cmake
# Add to executable sources
add_executable(voix
    # ... existing files ...
    new_feature.cpp
)
```

### 4. Update Main Application
```cpp
// Include new header
#include "include/new_feature.hpp"

// Use new feature
new_feature_function("example");
```

## Testing

### Running Tests
```bash
# Run full test suite
./test_voix.sh

# Run specific test
./test_voix.sh --specific-test

# Debug test failures
bash -x ./test_voix.sh
```

### Adding Tests
```bash
# Add test function to test_voix.sh
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing: $test_name... "

    if eval "$test_command" > /dev/null 2>&1; then
        # Test logic here
    fi
}

# Add new test
run_test "new feature test" "voix new-feature-command" 0
```

## Debugging

### Common Issues

#### Compilation Errors
```bash
# Check for missing dependencies
pkg-config --exists polkit-agent-1

# Check include paths
find /usr/include -name "polkit*.h" 2>/dev/null

# Check library locations
find /usr/lib -name "*polkit*" 2>/dev/null
```

#### Runtime Errors
```bash
# Enable debug logging
export VOIX_LOG_LEVEL=DEBUG

# Check PAM configuration
cat /etc/pam.d/voix

# Test PAM modules
pam_tally2 --user=$USER
```

#### Permission Issues
```bash
# Check binary permissions
ls -la /usr/local/bin/voix

# Verify setuid bit
stat /usr/local/bin/voix

# Check running user
id
```

## Code Style

### Formatting
```bash
# Use consistent indentation (4 spaces)
if (condition) {
    // 4 spaces, no tabs
    statement;
}

# Brace placement
function() {
    // Function body
}

if (condition) {
    // If body
} else {
    // Else body
}
```

### Naming Conventions
```cpp
// Classes and structs: PascalCase
class MyClass { };

// Functions: camelCase
void myFunction() { }

// Variables: snake_case
int my_variable = 0;

// Constants: SCREAMING_SNAKE_CASE
const int MAX_SIZE = 100;
```

### Comments
```cpp
// Single line comments for simple explanations
int result = calculate(); // Calculate result

/*
 * Multi-line comments for complex explanations
 * or function documentation
 */
void complexFunction() {
    // Implementation
}
```

## Performance Considerations

### Memory Management
- Use RAII (Resource Acquisition Is Initialization)
- Avoid memory leaks with smart pointers when possible
- Clean up GObject references properly

### Efficiency
- Minimize system calls in loops
- Cache expensive operations (file stats, user lookups)
- Use appropriate data structures

### Security
- Validate all inputs
- Avoid buffer overflows
- Sanitize environment variables

## Contributing

### Code Review Checklist
- [ ] Code compiles without warnings
- [ ] Tests pass
- [ ] Documentation updated
- [ ] Security considerations addressed
- [ ] Performance impact assessed
- [ ] Backward compatibility maintained

### Pull Request Process
1. Fork the repository
2. Create feature branch
3. Implement changes
4. Add tests
5. Update documentation
6. Submit pull request

## Release Process

### Version Management
```bash
# Update version in version.lua
echo "1.2.3" > version.lua

# Update changelog
vim CHANGELOG.md

# Tag release
git tag -a v1.2.3 -m "Release version 1.2.3"
git push origin v1.2.3
```

### Pre-release Testing
```bash
# Full test suite
./test_voix.sh

# Security audit
sudo grep -r "TODO\|FIXME\|XXX" src/

# Performance testing
time ./build/voix --version
```

### Distribution
```bash
# Create release archives
tar -czf voix-1.2.3.tar.gz src/ docs/ README.md
zip -r voix-1.2.3.zip src/ docs/ README.md

# Upload to GitHub releases
gh release create v1.2.3 \
  --title "Voix v1.2.3" \
  --notes "Release notes here" \
  voix-1.2.3.tar.gz \
  voix-1.2.3.zip
```

## Troubleshooting Development

### CMake Issues
```bash
# Clear build cache
rm -rf build/
mkdir build && cd build
cmake ..

# Force reconfiguration
cmake -DCMAKE_BUILD_TYPE=Debug -DHAVE_POLKIT=ON ..
```

### Dependency Problems
```bash
# Check system dependencies
ldconfig -p | grep lua
ldconfig -p | grep pam

# Install missing packages
sudo apt-get install lua5.3-dev libpam0g-dev
```

### IDE Setup
```bash
# Generate compile_commands.json for IDE support
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..

# For VS Code
ln -s build/compile_commands.json .
```

## Resources

### Documentation
- [CMake Documentation](https://cmake.org/documentation/)
- [Polkit Documentation](https://www.freedesktop.org/software/polkit/docs/)
- [PAM Documentation](https://linux.die.net/man/8/pam)

### Development Tools
- [Valgrind](https://valgrind.org/) - Memory debugging
- [GDB](https://www.gnu.org/software/gdb/) - Debugging
- [Cppcheck](http://cppcheck.sourceforge.net/) - Static analysis
- [Clang Static Analyzer](https://clang-analyzer.llvm.org/) - Code analysis

### Testing
- [Google Test](https://github.com/google/googletest) - Unit testing
- [LCOV](https://github.com/linux-test-project/lcov) - Coverage analysis
- [Valgrind](https://valgrind.org/) - Memory testing

## Getting Help

### Community
- GitHub Issues: https://github.com/Veridian-Zenith/Voix/issues
- Discussions: https://github.com/Veridian-Zenith/Voix/discussions
- IRC: #voix on libera.chat

### Development Support
- Development mailing list: dev@example.com
- Security issues: security@example.com
- Code contributions: https://github.com/Veridian-Zenith/Voix/pulls

## License

This project is licensed under the AGPLv3 license. See the LICENSE file for details.

When contributing code, ensure your contributions are compatible with this license.
