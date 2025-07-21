#!/bin/bash

# Test script for system configuration and service management (Task 7)
# Tests the implementation of systemd services, kernel modules, and system configuration

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Test framework functions
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    log_info "Running test: $test_name"
    
    if $test_function; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "PASSED: $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "FAILED: $test_name"
        return 1
    fi
}

# Test functions

test_systemd_service_files() {
    local services=(
        "nvidia-suspend.service"
        "nvidia-resume.service"
        "asus-hardware.service"
        "power-management.service"
    )
    
    local missing_services=()
    
    for service in "${services[@]}"; do
        local service_file="${PROJECT_DIR}/configs/systemd/$service"
        if [[ ! -f "$service_file" ]]; then
            missing_services+=("$service")
        fi
    done
    
    if [[ ${#missing_services[@]} -eq 0 ]]; then
        log_info "All systemd service files found"
        return 0
    else
        log_error "Missing systemd service files: ${missing_services[*]}"
        return 1
    fi
}

test_nvidia_suspend_handler() {
    local handler_script="${PROJECT_DIR}/scripts/nvidia-suspend-handler.sh"
    
    if [[ ! -f "$handler_script" ]]; then
        log_error "NVIDIA suspend handler script not found: $handler_script"
        return 1
    fi
    
    # Check if script is executable (in a Unix environment)
    if [[ -x "$handler_script" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        log_info "NVIDIA suspend handler script found and executable"
    else
        log_warn "NVIDIA suspend handler script found but not executable"
    fi
    
    # Check script syntax
    if bash -n "$handler_script" 2>/dev/null; then
        log_info "NVIDIA suspend handler script syntax is valid"
        return 0
    else
        log_error "NVIDIA suspend handler script has syntax errors"
        return 1
    fi
}

test_kernel_module_configs() {
    local module_configs=(
        "bbswitch.conf"
        "nvidia.conf"
        "amdgpu.conf"
        "acpi_call.conf"
    )
    
    local missing_configs=()
    
    for config in "${module_configs[@]}"; do
        local config_file="${PROJECT_DIR}/configs/modules/$config"
        if [[ ! -f "$config_file" ]]; then
            missing_configs+=("$config")
        fi
    done
    
    if [[ ${#missing_configs[@]} -eq 0 ]]; then
        log_info "All kernel module configuration files found"
        return 0
    else
        log_error "Missing kernel module configurations: ${missing_configs[*]}"
        return 1
    fi
}

test_setup_script_functions() {
    local setup_script="${PROJECT_DIR}/setup.sh"
    
    if [[ ! -f "$setup_script" ]]; then
        log_error "Setup script not found: $setup_script"
        return 1
    fi
    
    # Check for required functions
    local required_functions=(
        "install_kernel_module_configs"
        "install_systemd_services"
        "update_initramfs"
        "update_grub_config"
        "enable_system_services"
        "setup_system_services"
    )
    
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$setup_script"; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        log_info "All required functions found in setup script"
        return 0
    else
        log_error "Missing functions in setup script: ${missing_functions[*]}"
        return 1
    fi
}

test_systemd_service_syntax() {
    local systemd_dir="${PROJECT_DIR}/configs/systemd"
    local invalid_services=()
    
    for service_file in "$systemd_dir"/*.service; do
        if [[ -f "$service_file" ]]; then
            local service_name=$(basename "$service_file")
            
            # Basic syntax checks
            if ! grep -q "^\[Unit\]" "$service_file"; then
                invalid_services+=("$service_name: missing [Unit] section")
                continue
            fi
            
            if ! grep -q "^\[Service\]" "$service_file"; then
                invalid_services+=("$service_name: missing [Service] section")
                continue
            fi
            
            if ! grep -q "^\[Install\]" "$service_file"; then
                invalid_services+=("$service_name: missing [Install] section")
                continue
            fi
            
            # Check for required fields
            if ! grep -q "^Description=" "$service_file"; then
                invalid_services+=("$service_name: missing Description")
            fi
            
            if ! grep -q "^ExecStart=" "$service_file" && ! grep -q "^Type=oneshot" "$service_file"; then
                invalid_services+=("$service_name: missing ExecStart or not oneshot type")
            fi
        fi
    done
    
    if [[ ${#invalid_services[@]} -eq 0 ]]; then
        log_info "All systemd service files have valid syntax"
        return 0
    else
        log_error "Invalid systemd service files:"
        for issue in "${invalid_services[@]}"; do
            log_error "  $issue"
        done
        return 1
    fi
}

test_module_config_syntax() {
    local modules_dir="${PROJECT_DIR}/configs/modules"
    local invalid_configs=()
    
    for config_file in "$modules_dir"/*.conf; do
        if [[ -f "$config_file" ]]; then
            local config_name=$(basename "$config_file")
            
            # Check for common syntax issues
            if grep -q "^[[:space:]]*$" "$config_file" && [[ $(wc -l < "$config_file") -eq 1 ]]; then
                invalid_configs+=("$config_name: empty or whitespace-only file")
                continue
            fi
            
            # Check for proper comment format
            if grep -q "^[^#[:space:]]" "$config_file"; then
                # File has non-comment content, which is good
                log_info "Module config $config_name has valid content"
            fi
        fi
    done
    
    if [[ ${#invalid_configs[@]} -eq 0 ]]; then
        log_info "All kernel module configuration files have valid syntax"
        return 0
    else
        log_error "Invalid kernel module configurations:"
        for issue in "${invalid_configs[@]}"; do
            log_error "  $issue"
        done
        return 1
    fi
}

# Main test execution
main() {
    log_info "=== System Configuration and Service Management Tests ==="
    log_info "Testing Task 7 implementation..."
    echo
    
    # Run all tests
    run_test "Systemd service files exist" test_systemd_service_files
    run_test "NVIDIA suspend handler script" test_nvidia_suspend_handler
    run_test "Kernel module configurations exist" test_kernel_module_configs
    run_test "Setup script functions exist" test_setup_script_functions
    run_test "Systemd service syntax validation" test_systemd_service_syntax
    run_test "Module configuration syntax validation" test_module_config_syntax
    
    # Report results
    echo
    log_info "=== Test Results ==="
    log_info "Total tests: $TESTS_TOTAL"
    log_success "Passed: $TESTS_PASSED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "Failed: $TESTS_FAILED"
        echo
        log_error "Some tests failed. Please review the implementation."
        exit 1
    else
        echo
        log_success "All tests passed! Task 7 implementation is complete."
        exit 0
    fi
}

# Run main function
main "$@"