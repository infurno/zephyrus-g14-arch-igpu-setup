#!/bin/bash
# ASUS Hardware Tools Test Script
# Tests the functionality of ASUS-specific hardware integration

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# Test functions
test_asusctl() {
    log_info "Testing asusctl functionality..."
    
    if ! command -v asusctl &>/dev/null; then
        log_error "asusctl not found"
        return 1
    fi
    
    # Test service status
    if systemctl is-active asusd.service &>/dev/null; then
        log_success "asusd service is running"
    else
        log_warn "asusd service is not running"
    fi
    
    # Test basic functionality
    if asusctl --help &>/dev/null; then
        log_success "asusctl command works"
    else
        log_error "asusctl command failed"
        return 1
    fi
    
    # Test profile listing
    if asusctl profile -l &>/dev/null; then
        log_success "Fan profiles available"
        log_info "Available profiles:"
        asusctl profile -l 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
    else
        log_warn "Fan profiles not available"
    fi
    
    return 0
}

test_supergfxctl() {
    log_info "Testing supergfxctl functionality..."
    
    if ! command -v supergfxctl &>/dev/null; then
        log_error "supergfxctl not found"
        return 1
    fi
    
    # Test service status
    if systemctl is-active supergfxd.service &>/dev/null; then
        log_success "supergfxd service is running"
    else
        log_warn "supergfxd service is not running"
    fi
    
    # Test GPU mode query
    local gpu_mode=$(supergfxctl -g 2>/dev/null || echo "unknown")
    if [[ "$gpu_mode" != "unknown" ]]; then
        log_success "Current GPU mode: $gpu_mode"
    else
        log_warn "Could not determine GPU mode"
    fi
    
    # Test available modes
    if supergfxctl --help &>/dev/null; then
        log_success "supergfxctl command works"
    else
        log_error "supergfxctl command failed"
        return 1
    fi
    
    return 0
}

test_rog_control_center() {
    log_info "Testing rog-control-center..."
    
    if ! command -v rog-control-center &>/dev/null; then
        log_error "rog-control-center not found"
        return 1
    fi
    
    # Check desktop entry
    local desktop_file="/usr/share/applications/rog-control-center.desktop"
    if [[ -f "$desktop_file" ]]; then
        log_success "Desktop entry exists"
    else
        log_warn "Desktop entry not found"
    fi
    
    # Check user groups
    local current_user=$(whoami)
    if groups "$current_user" | grep -q "input"; then
        log_success "User is in input group"
    else
        log_warn "User is not in input group"
    fi
    
    return 0
}

test_switcheroo_control() {
    log_info "Testing switcheroo-control functionality..."
    
    if ! command -v switcherooctl &>/dev/null; then
        log_error "switcheroo-control not found"
        return 1
    fi
    
    # Test service status
    if systemctl is-active switcheroo-control.service &>/dev/null; then
        log_success "switcheroo-control service is running"
    else
        log_warn "switcheroo-control service is not running"
    fi
    
    # Test GPU listing
    if switcherooctl list &>/dev/null; then
        log_success "GPU switching available"
        log_info "Available GPUs:"
        switcherooctl list 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
    else
        log_warn "GPU switching not available"
    fi
    
    # Check udev rule
    local udev_rule="/etc/udev/rules.d/82-gpu-power-switch.rules"
    if [[ -f "$udev_rule" ]]; then
        log_success "GPU power switching udev rule exists"
    else
        log_warn "GPU power switching udev rule not found"
    fi
    
    return 0
}

test_power_profiles() {
    log_info "Testing power-profiles-daemon..."
    
    if ! command -v powerprofilesctl &>/dev/null; then
        log_warn "powerprofilesctl not found"
        return 0
    fi
    
    # Test service status
    if systemctl is-active power-profiles-daemon.service &>/dev/null; then
        log_success "power-profiles-daemon service is running"
    else
        log_warn "power-profiles-daemon service is not running"
    fi
    
    # Test current profile
    local profile=$(powerprofilesctl get 2>/dev/null || echo "unknown")
    if [[ "$profile" != "unknown" ]]; then
        log_success "Current power profile: $profile"
    else
        log_warn "Could not determine power profile"
    fi
    
    # List available profiles
    if powerprofilesctl list &>/dev/null; then
        log_info "Available power profiles:"
        powerprofilesctl list 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
    fi
    
    return 0
}

test_gpu_switching_script() {
    log_info "Testing GPU switching helper script..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local switch_script="${script_dir}/gpu-switch"
    
    if [[ -f "$switch_script" ]] && [[ -x "$switch_script" ]]; then
        log_success "GPU switching script exists and is executable"
        
        # Test script help
        if "$switch_script" help &>/dev/null; then
            log_success "GPU switching script help works"
        else
            log_warn "GPU switching script help failed"
        fi
        
        # Test status command
        if "$switch_script" status &>/dev/null; then
            log_success "GPU switching script status works"
        else
            log_warn "GPU switching script status failed"
        fi
    else
        log_warn "GPU switching script not found or not executable"
    fi
    
    return 0
}

# Main test function
main() {
    log_info "=== ASUS Hardware Tools Test ==="
    echo
    
    local failed_tests=0
    
    # Run all tests
    test_asusctl || ((failed_tests++))
    echo
    
    test_supergfxctl || ((failed_tests++))
    echo
    
    test_rog_control_center || ((failed_tests++))
    echo
    
    test_switcheroo_control || ((failed_tests++))
    echo
    
    test_power_profiles || ((failed_tests++))
    echo
    
    test_gpu_switching_script || ((failed_tests++))
    echo
    
    # Summary
    log_info "=== Test Summary ==="
    if [[ $failed_tests -eq 0 ]]; then
        log_success "All tests passed!"
    else
        log_warn "$failed_tests test(s) failed or had warnings"
    fi
    
    # Show overall system status
    echo
    log_info "=== System Status ==="
    
    # Show service statuses
    log_info "ASUS Services:"
    for service in asusd supergfxd switcheroo-control power-profiles-daemon; do
        if systemctl is-active "${service}.service" &>/dev/null; then
            log_success "  $service: active"
        else
            log_warn "  $service: inactive"
        fi
    done
    
    # Show GPU information
    echo
    log_info "GPU Information:"
    if command -v lspci &>/dev/null; then
        lspci | grep -E "(VGA|3D)" | while read -r line; do
            log_info "  $line"
        done
    fi
    
    echo
    log_info "Test completed."
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi