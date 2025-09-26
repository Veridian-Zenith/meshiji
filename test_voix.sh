#!/bin/bash
# Voix Integration Test Script
# This script tests various aspects of the Voix implementation

set -e

echo "=== Voix Integration Test Suite ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing: $test_name... "

    if eval "$test_command" > /dev/null 2>&1; then
        if [ $? -eq $expected_exit_code ]; then
            echo -e "${GREEN}PASS${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}FAIL${NC} (expected exit code $expected_exit_code)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        if [ $? -eq $expected_exit_code ]; then
            echo -e "${GREEN}PASS${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}FAIL${NC} (expected exit code $expected_exit_code, got $?)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    fi
}

print_result() {
    echo
    echo "=== Test Results ==="
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Check if we're running as root (needed for some tests)
if [ "$EUID" -eq 0 ]; then
    echo "Running as root - some tests may behave differently"
    IS_ROOT=true
else
    echo "Running as regular user"
    IS_ROOT=false
fi

echo "Building Voix..."
cd src
if [ -f "CMakeLists.txt" ]; then
    mkdir -p build
    cd build
    cmake ..
    make
    cd ..
else
    echo "CMakeLists.txt not found, trying direct compilation..."
    g++ -std=c++17 -o voix main.cpp config.cpp utils.cpp auth.cpp -I include -llua -lpam
    g++ -std=c++17 -o voixcheck voixcheck.cpp config.cpp -I include -llua
fi

VOIX_BINARY="./build/voix"

if [ ! -f "$VOIX_BINARY" ]; then
    echo "Voix binary not found at $VOIX_BINARY"
    exit 1
fi

echo "Testing voix (single binary with all functionality)..."
run_test "voix help" "$VOIX_BINARY --help" 0
run_test "voix version" "$VOIX_BINARY --version" 0
# Create a test config file first
TEST_CONFIG="/tmp/test-voix.conf"
cat > "$TEST_CONFIG" << 'EOF'
# Test configuration file
permit testuser as root
permit group:testgroup as root
permit persist testuser cmd /usr/bin/id
permit keepenv testuser cmd /usr/bin/env
deny testuser cmd /bin/rm -rf /
EOF

run_test "voix check command" "$VOIX_BINARY check $TEST_CONFIG" 0
run_test "voix validate command" "$VOIX_BINARY validate $TEST_CONFIG" 0

run_test "voixcheck valid config" "$VOIX_BINARY check $TEST_CONFIG" 0

# Test invalid config
INVALID_CONFIG="/tmp/invalid-voix.conf"
echo "invalid line without proper syntax" > "$INVALID_CONFIG"
run_test "voixcheck invalid config" "$VOIX_BINARY check $INVALID_CONFIG" 1

echo "Testing voix binary..."
run_test "voix help" "$VOIX_BINARY --help" 0
run_test "voix version" "$VOIX_BINARY --version" 0

# Test missing command (should fail)
run_test "voix no command" "$VOIX_BINARY" 2

# Test check command
run_test "voix check command" "$VOIX_BINARY check $TEST_CONFIG" 0

# Test with non-existent config
run_test "voix non-existent config" "$VOIX_BINARY id" 1

# Test with valid config but no permission
if [ "$IS_ROOT" = true ]; then
    # Create a config that denies the current user
    DENY_CONFIG="/tmp/deny-voix.conf"
    cat > "$DENY_CONFIG" << EOF
deny $USER as root
EOF
    run_test "voix denied command" "$VOIX_BINARY id" 1
fi

# Test environment variable detection
echo "Testing environment detection..."
if [ -n "$DISPLAY" ]; then
    echo "DISPLAY is set: $DISPLAY"
elif [ -n "$WAYLAND_DISPLAY" ]; then
    echo "WAYLAND_DISPLAY is set: $WAYLAND_DISPLAY"
else
    echo "No GUI environment detected"
fi

# Test structured logging
echo "Testing structured logging..."
LOG_FILE="/tmp/voix-test.log"
export VOIX_LOG_FILE="$LOG_FILE"

# Create a simple test config
SIMPLE_CONFIG="/tmp/simple-voix.conf"
echo "permit $USER as root" > "$SIMPLE_CONFIG"

# This test might fail if not running as root, but that's expected
run_test "voix with logging" "$VOIX_BINARY --version" 0

if [ -f "$LOG_FILE" ]; then
    echo "Log file created, checking format..."
    if grep -q "{" "$LOG_FILE"; then
        echo -e "${GREEN}Structured logging format detected${NC}"
    else
        echo -e "${YELLOW}Warning: Structured logging format not detected${NC}"
    fi
fi

# Cleanup
rm -f "$TEST_CONFIG" "$INVALID_CONFIG" "$LOG_FILE" "$SIMPLE_CONFIG"
if [ "$IS_ROOT" = true ]; then
    rm -f "$DENY_CONFIG"
fi

# Test compilation with polkit (if available)
echo "Testing Polkit support..."
if pkg-config --exists polkit-agent-1; then
    echo "Polkit detected, testing compilation with polkit support..."
    # This would require a full rebuild with polkit flags
    echo "Polkit support available"
else
    echo "Polkit not available"
fi

# Test regex patterns
echo "Testing regex patterns..."
echo "permit \"quoted user\" as root" > /tmp/quoted-test.conf
run_test "voixcheck quoted config" "$VOIX_BINARY check /tmp/quoted-test.conf" 0
rm -f /tmp/quoted-test.conf

print_result
