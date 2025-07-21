#!/bin/bash

# Test script for post-installation configuration (Task 8)
# Tests the implementation of post-install.sh script functionality

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

test_post_install_script_exists() {
    local post_install_script="${PROJECT_DIR}/scripts/post-install.sh"
    
    if [[ ! -f "$post_install_script" ]]; then
        log_error "Post-install script not found: $post_install_script"
        return 1
    fi
    
    log_info "Post-install script found"
    return 0
}

test_script_syntax() {
    local post_install_script="${PROJECT_DIR}/scripts/post-install.sh"
    
    if [[ ! -f "$post_install_script" ]]; then
        log_error "Post-install script not found: $post_install_script"
        return 1
    fi
    
    # Check script syntax
    if bash -n "$post_install_script" 2>/dev/null; then
        log_info "Post-install script syntax is valid"
        return 0
    else
        log_error "Post-install script has syntax errors"
        return 1
    fi
}

test_system_validation_functions() {
    local post_install_script="${PROJECT_DIR}/scripts/post-install.sh"
    
    if [[ ! -f "$post_install_script" ]]; then
        log_error "Post-install script not found: $post_install_script"
        return 1
    fi
    
    # Check for required validation functions
    local required_functions=(
        "validate_amd_primary_display"
        "validate_internal_display"
        "validate_gpu_switching_stability"
        "run_system_validation"
    )
    
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$post_install_script"; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        log_info "All required system validation functions found"
        return 0
    else
        log_error "Missing system validation functions: ${missing_functions[*]}"
        return 1
    fi
}

test_health_check_functions() {
    local post_install_script="${PROJECT_DIR}/scripts/post-install.sh"
    
    if [[ ! -f "$post_install_script" ]]; then
        log_error "Post-install script not found: $post_install_script"
        return 1
    fi
    
    # Check for required health check functions
    local required_functions=(
        "check_system_services"
        "check_power_management"
        "check_gpu_drivers"
        "run_health_checks"
    )
    
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$post_install_script"; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        log_info "All required health check functions found"
        return 0
    else
        log_error "Missing health check functions: ${missing_functions[*]}"
        return 1
    fi
}

test_user_environment_functions() {
    local post_install_script="${PROJECT_DIR}/scripts/post-install.sh"
    
    if [[ ! -f "$post_install_script" ]]; then
        log_error "Post-install script not found: $post_install_script"
        return 1
    fi
    
    # Check for required user environment functions
    local required_functions=(
        "setup_user_environment"
        "setup_user_path"
        "setup_shell_profile"
        "run_user_setup"
    )
    
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$post_install_script"; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        log_info "All required user environment functions found"
        return 0
    else
        log_error "Missing user environment functions: ${missing_functions[*]}"
        return 1
    fi
}

test_desktop_integration_functions() {
    local post_install_script="${PROJECT_DIR}/scripts/post-install.sh"
    
    if [[ ! -f "$post_install_script" ]]; then
        log_error "Post-install script not found: $post_install_script"
        return 1
    fi
    
    # Check for required desktop integration functions
    local required_functions=(
        "setup_desktop_integration"
        "create_desktop_entries"
        "setup_autostart_entries"
        "configure_desktop_environment"
    )
    
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$post_install_script"; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        log_info "All required desktop integration functions found"
        return 0
    else
        log_error "Missing desktop integration functions: ${missing_functions[*]}"
        return 1
    fi
}

test_command_line_interface() {
    local post_install_script="${PROJECT_DIR}/scripts/post-install.sh"
    
    if [[ ! -f "$post_install_script" ]]; then
        log_error "Post-install script not found: $post_install_script"
        return 1
    fi
    
    # Check for required CLI features
    local required_features=(
        "usage()"
        "main()"
        "--help"
        "--verbose"
        "--dry-run"
        "validate"
        "health"
        "setup-user"
        "all"
    )
    
    local missing_features=()
    
    for feature in "${required_features[@]}"; do
        if ! grep -q "$feature" "$post_install_script"; then
            missing_features+=("$feature")
        fi
    done
    
    if [[ ${#missing_features[@]} -eq 0 ]]; then
        log_info "All required CLI features found"
        return 0
    else
        log_error "Missing CLI features: ${missing_features[*]}"
        return 1
    fi
}

test_requirements_compliance() {
    local post_install_script="${PROJECT_DIR}/scripts/post-install.sh"
    
    if [[ ! -f "$post_install_script" ]]; then
        log_error "Post-install script not found: $post_install_script"
        return 1
    fi
    
    local compliance_issues=()
    
    # Check for Requirement 1.2: AMD iGPU as primary display driver
    if ! grep -q "validate_amd_primary_display" "$post_install_script"; then
        compliance_issues+=("Missing validation for AMD iGPU as primary display (Requirement 1.2)")
    fi
    
    # Check for Requirement 1.4: Internal display functionality
    if ! grep -q "validate_internal_display" "$post_install_script"; then
        compliance_issues+=("Missing validation for internal display functionality (Requirement 1.4)")
    fi
    
    # Check for Requirement 3.4: GPU switching stability
    if ! grep -q "validate_gpu_switching_stability" "$post_install_script"; then
        compliance_issues+=("Missing validation for GPU switching stability (Requirement 3.4)")
    fi
    
    # Check for user environment setup
    if ! grep -q "setup_user_environment" "$post_install_script"; then
        compliance_issues+=("Missing user environment setup functionality")
    fi
    
    # Check for desktop integration
    if ! grep -q "setup_desktop_integration" "$post_install_script"; then
        compliance_issues+=("Missing desktop environment integration")
    fi
    
    if [[ ${#compliance_issues[@]} -eq 0 ]]; then
        log_info "All requirements compliance checks passed"
        return 0
    else
        log_error "Requirements compliance issues:"
        for issue in "${compliance_issues[@]}"; do
            log_error "  - $issue"
        done
        return 1
    fi
}

test_error_handling() {
    local post_install_script="${PROJECT_DIR}/scripts/post-install.sh"
    
    if [[ ! -f "$post_install_script" ]]; then
        log_error "Post-install script not found: $post_install_script"
        return 1
    fi
    
    # Check for proper error handling patterns
    local error_handling_features=(
        "error_exit"
        "set -euo pipefail"
        "log("
        "warn("
    )
    
    local missing_features=()
    
    for feature in "${error_handling_features[@]}"; do
        if ! grep -q "$feature" "$post_install_script"; then
            missing_features+=("$feature")
        fi
    done
    
    if [[ ${#missing_features[@]} -eq 0 ]]; then
        log_info "All error handling features found"
        return 0
    else
        log_error "Missing error handling features: ${missing_features[*]}"
        return 1
    fi
}

# Main test execution
main() {
    log_info "=== Post-Installation Configuration Tests ==="
    log_info "Testing Task 8 implementation..."
    echo
    
    # Run all tests
    run_test "Post-install script exists" test_post_install_script_exists
    run_test "Script syntax validation" test_script_syntax
    run_test "System validation functions" test_system_validation_functions
    run_test "Health check functions" test_health_check_functions
    run_test "User environment functions" test_user_environment_functions
    run_test "Desktop integration functions" test_desktop_integration_functions
    run_test "Command line interface" test_command_line_interface
    run_test "Requirements compliance" test_requirements_compliance
    run_test "Error handling" test_error_handling
    
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
        log_success "All tests passed! Task 8 implementation is complete."
        exit 0
    fi
}

# Run main function
main "$@"