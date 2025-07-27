#!/bin/bash

# Test script for power management configuration
# Validates that all power management components are properly configured

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Test function wrapper
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TESTS_TOTAL++))
    log_info "Running test: $test_name"
    
    if $test_function; then
        log_success "$test_name"
    else
        log_error "$test_name"
    fi
    echo
}

# Test if TLP configuration exists and is valid
test_tlp_config() {
    local config_file="/etc/tlp.conf"
    
    if [[ ! -f "$config_file" ]]; then
        echo "TLP configuration file not found: $config_file"
        return 1
    fi
    
    # Check for key configuration options
    local required_options=(
        "TLP_ENABLE=1"
        "CPU_SCALING_GOVERNOR_ON_AC"
        "CPU_SCALING_GOVERNOR_ON_BAT"
        "CPU_BOOST_ON_AC"
        "CPU_BOOST_ON_BAT"
    )
    
    for option in "${required_options[@]}"; do
        if ! grep -q "^${option%=*}=" "$config_file"; then
            echo "Missing required TLP option: ${option%=*}"
            return 1
        fi
    done
    
    echo "TLP configuration file exists and contains required options"
    return 0
}

# Test if auto-cpufreq configuration exists and is valid
test_auto_cpufreq_config() {
    local config_file="/etc/auto-cpufreq.conf"
    
    if [[ ! -f "$config_file" ]]; then
        echo "auto-cpufreq configuration file not found: $config_file"
        return 1
    fi
    
    # Check for required sections
    if ! grep -q "^\[charger\]" "$config_file"; then
        echo "Missing [charger] section in auto-cpufreq config"
        return 1
    fi
    
    if ! grep -q "^\[battery\]" "$config_file"; then
        echo "Missing [battery] section in auto-cpufreq config"
        return 1
    fi
    
    echo "auto-cpufreq configuration file exists and contains required sections"
    return 0
}

# Test if power management script is installed
test_power_management_script() {
    local script_file="/usr/local/bin/setup-power-management.sh"
    
    if [[ ! -f "$script_file" ]]; then
        echo "Power management script not found: $script_file"
        return 1
    fi
    
    if [[ ! -x "$script_file" ]]; then
        echo "Power management script is not executable: $script_file"
        return 1
    fi
    
    echo "Power management script exists and is executable"
    return 0
}

# Test if NVIDIA power management udev rules are installed
test_nvidia_udev_rules() {
    local rules_file="/etc/udev/rules.d/80-nvidia-pm.rules"
    
    if [[ ! -f "$rules_file" ]]; then
        echo "NVIDIA power management udev rules not found: $rules_file"
        return 1
    fi
    
    # Check for key rules
    if ! grep -q "ATTR{vendor}==\"0x10de\"" "$rules_file"; then
        echo "NVIDIA vendor ID rule not found in udev rules"
        return 1
    fi
    
    echo "NVIDIA power management udev rules exist and contain required rules"
    return 0
}

# Test if kernel modules configuration is installed
test_kernel_modules_config() {
    local config_file="/etc/modprobe.d/bbswitch.conf"
    
    if [[ ! -f "$config_file" ]]; then
        echo "bbswitch kernel module configuration not found: $config_file"
        return 1
    fi
    
    if ! grep -q "options bbswitch" "$config_file"; then
        echo "bbswitch options not found in kernel modules config"
        return 1
    fi
    
    echo "Kernel modules configuration exists and contains bbswitch options"
    return 0
}

# Test if required packages are installed
test_power_packages_installed() {
    local required_packages=(
        "tlp"
        "auto-cpufreq"
        "bbswitch"
        "power-profiles-daemon"
    )
    
    local missing_packages=()
    
    for package in "${required_packages[@]}"; do
        if ! dnf list installed "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        echo "Missing required power management packages: ${missing_packages[*]}"
        return 1
    fi
    
    echo "All required power management packages are installed"
    return 0
}

# Test AMD P-state support detection
test_amd_pstate_support() {
    # Check if this is an AMD CPU
    if ! grep -q "AMD" /proc/cpuinfo; then
        echo "Non-AMD CPU detected, AMD P-state test skipped"
        return 0
    fi
    
    # Check if amd-pstate driver module is available
    if ! modinfo amd_pstate &>/dev/null; then
        echo "AMD P-state driver module not available"
        return 1
    fi
    
    echo "AMD P-state driver module is available"
    return 0
}

# Test current CPU frequency scaling
test_cpu_frequency_scaling() {
    local scaling_driver_file="/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver"
    
    if [[ ! -f "$scaling_driver_file" ]]; then
        echo "CPU frequency scaling not available"
        return 1
    fi
    
    local current_driver=$(cat "$scaling_driver_file")
    echo "Current CPU frequency scaling driver: $current_driver"
    
    # Check available governors
    local governors_file="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors"
    if [[ -f "$governors_file" ]]; then
        local available_governors=$(cat "$governors_file")
        echo "Available CPU governors: $available_governors"
    fi
    
    return 0
}

# Test power supply detection
test_power_supply_detection() {
    local power_supplies=(/sys/class/power_supply/*)
    
    if [[ ${#power_supplies[@]} -eq 0 ]]; then
        echo "No power supplies detected"
        return 1
    fi
    
    echo "Detected power supplies:"
    for supply in "${power_supplies[@]}"; do
        if [[ -f "$supply/type" ]]; then
            local supply_name=$(basename "$supply")
            local supply_type=$(cat "$supply/type")
            echo "  $supply_name: $supply_type"
        fi
    done
    
    return 0
}

# Main test execution
main() {
    echo "========================================"
    echo "Power Management Configuration Test"
    echo "========================================"
    echo
    
    # Run all tests
    run_test "TLP Configuration" test_tlp_config
    run_test "auto-cpufreq Configuration" test_auto_cpufreq_config
    run_test "Power Management Script" test_power_management_script
    run_test "NVIDIA udev Rules" test_nvidia_udev_rules
    run_test "Kernel Modules Configuration" test_kernel_modules_config
    run_test "Power Packages Installation" test_power_packages_installed
    run_test "AMD P-state Support" test_amd_pstate_support
    run_test "CPU Frequency Scaling" test_cpu_frequency_scaling
    run_test "Power Supply Detection" test_power_supply_detection
    
    # Print summary
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo "Total tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All power management tests passed!"
        return 0
    else
        log_error "$TESTS_FAILED test(s) failed. Please review the configuration."
        return 1
    fi
}

# Run main function
main "$@"