#!/bin/bash

# System Test Script for ASUS ROG Zephyrus G14 Hybrid GPU Setup
# Automated system validation and testing

set -euo pipefail

# Source error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging
LOG_FILE="/tmp/system-test-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  System Validation Test Suite  ${NC}"
    echo -e "${BLUE}================================${NC}"
    log "Starting system validation tests"
}

print_test() {
    echo -e "${YELLOW}Testing: $1${NC}"
    log "TEST: $1"
}

test_pass() {
    echo -e "${GREEN}✓ PASS: $1${NC}"
    log "PASS: $1"
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
}

test_fail() {
    echo -e "${RED}✗ FAIL: $1${NC}"
    log "FAIL: $1"
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
}

# Test 1: Check if required packages are installed
test_packages() {
    print_test "Required packages installation"
    
    local required_packages=(
        "mesa"
        "vulkan-radeon" 
        "xf86-video-amdgpu"
        "nvidia"
        "nvidia-utils"
        "tlp"
        "auto-cpufreq"
        "asusctl"
        "supergfxctl"
    )
    
    local missing_packages=()
    
    for package in "${required_packages[@]}"; do
        if ! dnf list installed "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -eq 0 ]; then
        test_pass "All required packages are installed"
    else
        test_fail "Missing packages: ${missing_packages[*]}"
    fi
}

# Test 2: Check GPU detection
test_gpu_detection() {
    print_test "GPU detection"
    
    local amd_gpu_found=false
    local nvidia_gpu_found=false
    
    # Check for AMD GPU
    if lspci | grep -i "vga.*amd\|vga.*radeon" &>/dev/null; then
        amd_gpu_found=true
    fi
    
    # Check for NVIDIA GPU  
    if lspci | grep -i "vga.*nvidia\|3d.*nvidia" &>/dev/null; then
        nvidia_gpu_found=true
    fi
    
    if $amd_gpu_found && $nvidia_gpu_found; then
        test_pass "Both AMD and NVIDIA GPUs detected"
    elif $amd_gpu_found; then
        test_fail "Only AMD GPU detected, NVIDIA GPU missing"
    elif $nvidia_gpu_found; then
        test_fail "Only NVIDIA GPU detected, AMD GPU missing"
    else
        test_fail "No GPUs detected"
    fi
}

# Test 3: Check kernel modules
test_kernel_modules() {
    print_test "Kernel modules"
    
    local required_modules=(
        "amdgpu"
        "nvidia"
        "bbswitch"
    )
    
    local missing_modules=()
    
    for module in "${required_modules[@]}"; do
        if ! lsmod | grep -q "^$module"; then
            missing_modules+=("$module")
        fi
    done
    
    if [ ${#missing_modules[@]} -eq 0 ]; then
        test_pass "All required kernel modules are loaded"
    else
        test_fail "Missing kernel modules: ${missing_modules[*]}"
    fi
}# Te
st 4: Check Xorg configuration
test_xorg_config() {
    print_test "Xorg configuration"
    
    local xorg_config="/etc/X11/xorg.conf.d/10-hybrid.conf"
    
    if [ -f "$xorg_config" ]; then
        if grep -q "amdgpu" "$xorg_config" && grep -q "nvidia" "$xorg_config"; then
            test_pass "Xorg hybrid GPU configuration found"
        else
            test_fail "Xorg configuration exists but missing GPU drivers"
        fi
    else
        test_fail "Xorg hybrid GPU configuration not found"
    fi
}

# Test 5: Check power management services
test_power_services() {
    print_test "Power management services"
    
    local services=(
        "tlp"
        "auto-cpufreq"
        "power-profiles-daemon"
    )
    
    local failed_services=()
    
    for service in "${services[@]}"; do
        if ! systemctl is-enabled "$service" &>/dev/null; then
            failed_services+=("$service (not enabled)")
        elif ! systemctl is-active "$service" &>/dev/null; then
            failed_services+=("$service (not active)")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        test_pass "All power management services are running"
    else
        test_fail "Service issues: ${failed_services[*]}"
    fi
}

# Test 6: Check NVIDIA GPU power state
test_nvidia_power() {
    print_test "NVIDIA GPU power management"
    
    if [ -f "/proc/acpi/bbswitch" ]; then
        local nvidia_state=$(cat /proc/acpi/bbswitch | awk '{print $2}')
        if [ "$nvidia_state" = "OFF" ] || [ "$nvidia_state" = "ON" ]; then
            test_pass "NVIDIA GPU power management working (state: $nvidia_state)"
        else
            test_fail "NVIDIA GPU power state unknown: $nvidia_state"
        fi
    else
        test_fail "bbswitch not available for NVIDIA power management"
    fi
}

# Test 7: Check ASUS tools
test_asus_tools() {
    print_test "ASUS hardware tools"
    
    local tools_working=true
    
    # Test asusctl
    if ! command -v asusctl &>/dev/null; then
        test_fail "asusctl command not found"
        tools_working=false
    elif ! asusctl --version &>/dev/null; then
        test_fail "asusctl not working properly"
        tools_working=false
    fi
    
    # Test supergfxctl
    if ! command -v supergfxctl &>/dev/null; then
        test_fail "supergfxctl command not found"
        tools_working=false
    elif ! supergfxctl --version &>/dev/null; then
        test_fail "supergfxctl not working properly"
        tools_working=false
    fi
    
    if $tools_working; then
        test_pass "ASUS hardware tools are working"
    fi
}

# Test 8: Check display functionality
test_display() {
    print_test "Display functionality"
    
    if [ -n "$DISPLAY" ]; then
        # Check if X server is running
        if xrandr &>/dev/null; then
            local displays=$(xrandr --listmonitors | grep -c "Monitor")
            test_pass "Display system working ($displays monitor(s) detected)"
        else
            test_fail "X server not responding to xrandr"
        fi
    else
        test_fail "No DISPLAY environment variable set"
    fi
}

# Test 9: Check GPU offload capability
test_gpu_offload() {
    print_test "GPU offload capability"
    
    if [ -f "/usr/bin/prime-run" ] || [ -f "/usr/local/bin/prime-run" ] || command -v prime-run &>/dev/null; then
        # Test if prime-run can execute a simple command
        if prime-run glxinfo -B &>/dev/null; then
            test_pass "GPU offload (prime-run) working"
        else
            test_fail "prime-run exists but not working properly"
        fi
    else
        test_fail "prime-run script not found"
    fi
}

# Test 10: Check system performance
test_system_performance() {
    print_test "System performance indicators"
    
    local cpu_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    local cpu_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "0")
    
    if [ "$cpu_governor" != "unknown" ] && [ "$cpu_freq" != "0" ]; then
        test_pass "CPU frequency scaling working (governor: $cpu_governor)"
    else
        test_fail "CPU frequency scaling not working properly"
    fi
}

# Main test execution
run_all_tests() {
    print_header
    
    test_packages
    test_gpu_detection
    test_kernel_modules
    test_xorg_config
    test_power_services
    test_nvidia_power
    test_asus_tools
    test_display
    test_gpu_offload
    test_system_performance
    
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}        Test Results Summary     ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Total tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "Log file: $LOG_FILE"
    echo
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed! System is properly configured.${NC}"
        log "All tests passed successfully"
        exit 0
    else
        echo -e "${RED}Some tests failed. Check the log for details.${NC}"
        log "Tests completed with $TESTS_FAILED failures"
        exit 1
    fi
}

# Script execution
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo "  --quiet, -q   Run tests quietly (minimal output)"
    echo "  --verbose, -v Run tests with verbose output"
    exit 0
fi

# Handle quiet mode
if [ "${1:-}" = "--quiet" ] || [ "${1:-}" = "-q" ]; then
    exec > /dev/null 2>&1
fi

# Handle verbose mode
if [ "${1:-}" = "--verbose" ] || [ "${1:-}" = "-v" ]; then
    set -x
fi

# Make sure we're running as root for some tests
if [ $EUID -ne 0 ] && [ "${1:-}" != "--user" ]; then
    echo -e "${YELLOW}Warning: Some tests require root privileges. Run with sudo for complete testing.${NC}"
fi

run_all_tests