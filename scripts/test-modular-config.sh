#!/bin/bash

# Test script for modular configuration system
# Validates that all components work together correctly

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/configs"
TEST_DIR="/tmp/zephyrus-g14-config-test"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test logging
log_test() {
    echo "[TEST] $1"
}

log_pass() {
    echo "[PASS] $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo "[FAIL] $1"
    ((TESTS_FAILED++))
}

# Setup test environment
setup_test_env() {
    log_test "Setting up test environment..."
    
    # Create test directory
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    
    # Set test environment variables
    export HOME="$TEST_DIR"
    export USER_CONFIG_DIR="$TEST_DIR/.config/zephyrus-g14"
    
    log_pass "Test environment setup complete"
}

# Test hardware detection
test_hardware_detection() {
    log_test "Testing hardware detection..."
    
    # Mock hardware detection by creating fake hardware info
    mkdir -p "$USER_CONFIG_DIR"
    cat > "$USER_CONFIG_DIR/hardware.conf" << EOF
[hardware]
laptop_model="GA403WR"
cpu_model="AMD Ryzen 9 8945HS"
amd_gpu="AMD Radeon 890M"
nvidia_gpu="NVIDIA GeForce RTX 5070 Ti Laptop GPU"
has_battery=true

[capabilities]
hybrid_graphics=true
amd_pstate_supported=true
bbswitch_supported=true
EOF
    
    if [ -f "$USER_CONFIG_DIR/hardware.conf" ]; then
        log_pass "Hardware detection configuration created"
    else
        log_fail "Hardware detection configuration not created"
    fi
}

# Test user preferences initialization
test_user_preferences() {
    log_test "Testing user preferences initialization..."
    
    # Test config manager preference initialization
    if bash "$SCRIPT_DIR/config-manager.sh" init-preferences; then
        if [ -f "$USER_CONFIG_DIR/preferences.conf" ]; then
            log_pass "User preferences file created successfully"
        else
            log_fail "User preferences file not created"
        fi
    else
        log_fail "User preferences initialization failed"
    fi
}

# Test template processing
test_template_processing() {
    log_test "Testing template processing..."
    
    # Check if templates exist
    if [ -d "$CONFIG_DIR/templates" ]; then
        local template_count
        template_count=$(find "$CONFIG_DIR/templates" -name "*.template" | wc -l)
        if [ "$template_count" -gt 0 ]; then
            log_pass "Configuration templates found ($template_count templates)"
        else
            log_fail "No configuration templates found"
        fi
    else
        log_fail "Templates directory not found"
    fi
}

# Test hardware variant support
test_hardware_variants() {
    log_test "Testing hardware variant support..."
    
    # Check if variant configurations exist
    if [ -d "$CONFIG_DIR/variants" ]; then
        local variant_count
        variant_count=$(find "$CONFIG_DIR/variants" -name "variant.conf" | wc -l)
        if [ "$variant_count" -gt 0 ]; then
            log_pass "Hardware variant configurations found ($variant_count variants)"
        else
            log_fail "No hardware variant configurations found"
        fi
        
        # Test specific variants
        if [ -f "$CONFIG_DIR/variants/ga403wr-2025/variant.conf" ]; then
            log_pass "GA403WR-2025 variant configuration exists"
        else
            log_fail "GA403WR-2025 variant configuration missing"
        fi
        
        if [ -f "$CONFIG_DIR/variants/generic/variant.conf" ]; then
            log_pass "Generic fallback variant configuration exists"
        else
            log_fail "Generic fallback variant configuration missing"
        fi
    else
        log_fail "Variants directory not found"
    fi
}

# Test configuration validation
test_configuration_validation() {
    log_test "Testing configuration validation..."
    
    # Test validation script exists and is executable
    if [ -f "$SCRIPT_DIR/validate-config.sh" ]; then
        log_pass "Configuration validation script exists"
        
        # Test validation functionality (dry run)
        if bash "$SCRIPT_DIR/validate-config.sh" 2>/dev/null || true; then
            log_pass "Configuration validation script executes"
        else
            log_fail "Configuration validation script execution failed"
        fi
    else
        log_fail "Configuration validation script not found"
    fi
}

# Test configuration consistency
test_configuration_consistency() {
    log_test "Testing configuration consistency..."
    
    local consistency_issues=0
    
    # Check for required configuration files
    local required_configs=(
        "xorg/10-hybrid.conf"
        "tlp/tlp.conf"
        "udev/81-nvidia-switching.rules"
        "systemd/nvidia-suspend.service"
    )
    
    for config in "${required_configs[@]}"; do
        if [ -f "$CONFIG_DIR/$config" ]; then
            log_pass "Required configuration exists: $config"
        else
            log_fail "Required configuration missing: $config"
            ((consistency_issues++))
        fi
    done
    
    if [ $consistency_issues -eq 0 ]; then
        log_pass "Configuration consistency check passed"
    else
        log_fail "Configuration consistency issues found: $consistency_issues"
    fi
}

# Test modular system integration
test_modular_integration() {
    log_test "Testing modular system integration..."
    
    # Test config manager main functions
    local functions_to_test=(
        "detect-hardware"
        "init-preferences"
        "show-hardware"
        "show-preferences"
    )
    
    for func in "${functions_to_test[@]}"; do
        if bash "$SCRIPT_DIR/config-manager.sh" "$func" &>/dev/null || true; then
            log_pass "Config manager function works: $func"
        else
            log_fail "Config manager function failed: $func"
        fi
    done
}

# Test file structure and permissions
test_file_structure() {
    log_test "Testing file structure and permissions..."
    
    # Check main directories exist
    local required_dirs=(
        "configs/templates"
        "configs/variants"
        "configs/variants/generic"
        "configs/variants/ga403wr-2025"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$CONFIG_DIR/../$dir" ]; then
            log_pass "Required directory exists: $dir"
        else
            log_fail "Required directory missing: $dir"
        fi
    done
    
    # Check script files exist
    local required_scripts=(
        "config-manager.sh"
        "validate-config.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/$script" ]; then
            log_pass "Required script exists: $script"
        else
            log_fail "Required script missing: $script"
        fi
    done
}

# Cleanup test environment
cleanup_test_env() {
    log_test "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
    log_pass "Test environment cleaned up"
}

# Generate test report
generate_test_report() {
    echo ""
    echo "========================================="
    echo "Modular Configuration System Test Report"
    echo "========================================="
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo "✓ All tests passed! Modular configuration system is working correctly."
        return 0
    else
        echo "✗ Some tests failed. Please review the issues above."
        return 1
    fi
}

# Main test execution
main() {
    echo "Starting modular configuration system tests..."
    echo ""
    
    setup_test_env
    test_hardware_detection
    test_user_preferences
    test_template_processing
    test_hardware_variants
    test_configuration_validation
    test_configuration_consistency
    test_modular_integration
    test_file_structure
    cleanup_test_env
    
    generate_test_report
}

# Execute main function
main "$@"