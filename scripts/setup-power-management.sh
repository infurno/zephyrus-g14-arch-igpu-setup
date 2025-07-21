#!/bin/bash

# Power Management Setup Script for ASUS ROG Zephyrus G14
# Handles AMD P-state detection, kernel parameters, and service configuration

set -euo pipefail

# Source error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"

# Global variables for error tracking
POWER_MGMT_FAILED=()
CRITICAL_POWER_FAILURES=false

# Recovery functions
recover_grub_config() {
    log_info "Attempting to recover GRUB configuration..."
    
    local grub_config="/etc/default/grub"
    local backup_pattern="${grub_config}.backup-*"
    
    # Find the most recent backup
    local latest_backup=$(ls -1t $backup_pattern 2>/dev/null | head -1)
    
    if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
        log_info "Restoring GRUB configuration from backup: $latest_backup"
        if sudo cp "$latest_backup" "$grub_config"; then
            log_success "GRUB configuration restored from backup"
            
            # Regenerate GRUB configuration
            if command -v grub-mkconfig &>/dev/null; then
                if sudo grub-mkconfig -o /boot/grub/grub.cfg; then
                    log_success "GRUB configuration regenerated after recovery"
                    return 0
                else
                    log_error "Failed to regenerate GRUB configuration after recovery"
                fi
            fi
        else
            log_error "Failed to restore GRUB configuration from backup"
        fi
    else
        log_error "No GRUB configuration backup found for recovery"
    fi
    
    return 1
}

recover_power_management_service() {
    local service_name="$1"
    
    log_info "Attempting to recover power management service: $service_name"
    
    # Stop the service
    sudo systemctl stop "$service_name" 2>/dev/null || true
    
    # Reset failed state
    sudo systemctl reset-failed "$service_name" 2>/dev/null || true
    
    # Reload systemd daemon
    sudo systemctl daemon-reload
    
    # Try to start the service
    if sudo systemctl start "$service_name"; then
        log_success "Power management service $service_name recovered"
        return 0
    else
        log_error "Failed to recover power management service: $service_name"
        return 1
    fi
}

validate_power_management_setup() {
    log_info "Validating power management setup..."
    
    local validation_errors=()
    
    # Check if any power management service is running
    local power_services=("tlp" "auto-cpufreq" "power-profiles-daemon")
    local active_services=0
    
    for service in "${power_services[@]}"; do
        if systemctl is-active "${service}.service" &>/dev/null; then
            ((active_services++))
            log_debug "Power management service active: $service"
        fi
    done
    
    if [[ $active_services -eq 0 ]]; then
        validation_errors+=("No power management services are active")
    elif [[ $active_services -gt 1 ]]; then
        validation_errors+=("Multiple conflicting power management services are active")
    fi
    
    # Check CPU frequency scaling
    if [[ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]]; then
        local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        log_debug "Current CPU governor: $governor"
    else
        validation_errors+=("CPU frequency scaling not available")
    fi
    
    # Check AMD P-state if applicable
    if grep -q "AMD" /proc/cpuinfo; then
        if [[ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver" ]]; then
            local driver=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver)
            log_debug "Current CPU frequency driver: $driver"
            
            if [[ "$driver" == "amd-pstate-epp" ]]; then
                log_debug "AMD P-state EPP is active"
            fi
        fi
    fi
    
    if [[ ${#validation_errors[@]} -eq 0 ]]; then
        log_success "Power management setup validation passed"
        return 0
    else
        log_error "Power management setup validation failed:"
        for error in "${validation_errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
}

# Check if AMD P-state EPP is supported
check_amd_pstate_epp_support() {
    log_info "Checking AMD P-state EPP support..."
    
    # Check if the CPU supports AMD P-state
    if ! grep -q "AMD" /proc/cpuinfo; then
        log_warn "Non-AMD CPU detected, AMD P-state not applicable"
        return 1
    fi
    
    # Check if amd-pstate driver is available
    if [[ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]]; then
        local current_driver=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo "unknown")
        log_info "Current CPU frequency driver: $current_driver"
        
        # Check if amd-pstate-epp is supported
        if modinfo amd_pstate &>/dev/null; then
            log_info "AMD P-state driver module is available"
            
            # Check if EPP is supported
            if [[ -f "/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference" ]]; then
                log_info "AMD P-state EPP is supported and active"
                return 0
            else
                log_info "AMD P-state EPP support detected but not active"
                return 2
            fi
        else
            log_warn "AMD P-state driver module not found"
            return 1
        fi
    else
        log_error "CPU frequency scaling not available"
        return 1
    fi
}

# Configure kernel parameters for AMD P-state EPP with comprehensive error handling
configure_amd_pstate_kernel_params() {
    log_info "Configuring kernel parameters for AMD P-state EPP..."
    
    local grub_config="/etc/default/grub"
    local backup_config="${grub_config}.backup-$(date +%Y%m%d_%H%M%S)"
    
    # Create rollback point before modifying GRUB
    create_rollback_point "grub-config" "Before GRUB configuration changes" || {
        log_warn "Failed to create rollback point, continuing without rollback capability"
    }
    
    # Validate GRUB configuration file exists and is readable
    if [[ ! -f "$grub_config" ]]; then
        POWER_MGMT_FAILED+=("grub-config-missing")
        error_exit "GRUB configuration file not found: $grub_config" "$E_CONFIG_ERROR" "recover_grub_config"
    fi
    
    if [[ ! -r "$grub_config" ]]; then
        POWER_MGMT_FAILED+=("grub-config-permissions")
        error_exit "Cannot read GRUB configuration file: $grub_config" "$E_PERMISSION_ERROR"
    fi
    
    # Create backup with error handling
    if ! cp "$grub_config" "$backup_config"; then
        POWER_MGMT_FAILED+=("grub-backup-failed")
        error_exit "Failed to create backup of GRUB config" "$E_CONFIG_ERROR"
    fi
    log_info "Created backup of GRUB config: $backup_config"
    
    # Check current kernel parameters with validation
    local current_params
    if ! current_params=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_config" | cut -d'"' -f2); then
        POWER_MGMT_FAILED+=("grub-params-read-failed")
        log_error "Failed to read current kernel parameters from GRUB config"
        return 1
    fi
    log_info "Current kernel parameters: $current_params"
    
    # Check if amd_pstate=active is already present
    if echo "$current_params" | grep -q "amd_pstate=active"; then
        log_info "AMD P-state already configured in kernel parameters"
        return 0
    fi
    
    log_info "Adding AMD P-state kernel parameter..."
    
    # Add amd_pstate=active to kernel parameters
    local new_params="$current_params amd_pstate=active"
    
    # Update GRUB configuration with error handling and validation
    local temp_config="${grub_config}.tmp"
    if ! sed "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$new_params\"/" "$grub_config" > "$temp_config"; then
        POWER_MGMT_FAILED+=("grub-update-failed")
        rm -f "$temp_config"
        error_exit "Failed to update GRUB configuration" "$E_CONFIG_ERROR" "recover_grub_config"
    fi
    
    # Validate the updated configuration
    if ! grep -q "amd_pstate=active" "$temp_config"; then
        POWER_MGMT_FAILED+=("grub-validation-failed")
        rm -f "$temp_config"
        error_exit "GRUB configuration validation failed" "$E_CONFIG_ERROR" "recover_grub_config"
    fi
    
    # Replace original with updated configuration
    if ! sudo mv "$temp_config" "$grub_config"; then
        POWER_MGMT_FAILED+=("grub-replace-failed")
        rm -f "$temp_config"
        error_exit "Failed to replace GRUB configuration" "$E_CONFIG_ERROR" "recover_grub_config"
    fi
    
    log_info "Updated kernel parameters: $new_params"
    log_info "GRUB configuration updated, regenerating GRUB config..."
    
    # Regenerate GRUB configuration with error handling
    if command -v grub-mkconfig &>/dev/null; then
        local error_output
        if error_output=$(sudo grub-mkconfig -o /boot/grub/grub.cfg 2>&1); then
            log_info "GRUB configuration regenerated successfully"
        else
            POWER_MGMT_FAILED+=("grub-regen-failed")
            log_error "Failed to regenerate GRUB configuration: $error_output"
            
            # Attempt to restore backup
            if [[ -f "$backup_config" ]]; then
                log_info "Attempting to restore GRUB configuration from backup..."
                if sudo cp "$backup_config" "$grub_config"; then
                    log_success "GRUB configuration restored from backup"
                else
                    log_error "Failed to restore GRUB configuration from backup"
                fi
            fi
            
            return 1
        fi
    else
        POWER_MGMT_FAILED+=("grub-mkconfig-missing")
        log_error "grub-mkconfig not found, please regenerate GRUB config manually"
        log_error "Run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
        return 1
    fi
    
    log_warn "Reboot required for AMD P-state changes to take effect"
    return 0
}

# Setup power profiles daemon
setup_power_profiles_daemon() {
    log_info "Setting up power-profiles-daemon..."
    
    # Check if power-profiles-daemon is installed
    if ! command -v powerprofilesctl &>/dev/null; then
        log_error "power-profiles-daemon not installed"
        return 1
    fi
    
    # Enable and start the service
    systemctl enable power-profiles-daemon.service
    systemctl start power-profiles-daemon.service
    
    # Check available profiles
    log_info "Available power profiles:"
    powerprofilesctl list | while read -r line; do
        log_info "  $line"
    done
    
    # Set default profile based on power source
    if [[ -f "/sys/class/power_supply/ADP1/online" ]]; then
        local ac_online=$(cat /sys/class/power_supply/ADP1/online)
        if [[ "$ac_online" == "1" ]]; then
            log_info "AC power detected, setting balanced profile"
            powerprofilesctl set balanced || log_warn "Failed to set balanced profile"
        else
            log_info "Battery power detected, setting power-saver profile"
            powerprofilesctl set power-saver || log_warn "Failed to set power-saver profile"
        fi
    else
        log_warn "Could not detect power source, using default profile"
    fi
    
    log_info "power-profiles-daemon setup completed"
    return 0
}

# Setup TLP
setup_tlp() {
    log_info "Setting up TLP power management..."
    
    # Check if TLP is installed
    if ! command -v tlp &>/dev/null; then
        log_error "TLP not installed"
        return 1
    fi
    
    # Stop conflicting services
    log_info "Stopping conflicting power management services..."
    systemctl stop power-profiles-daemon.service 2>/dev/null || true
    systemctl disable power-profiles-daemon.service 2>/dev/null || true
    
    # Enable and start TLP
    systemctl enable tlp.service
    systemctl start tlp.service
    
    # Enable TLP sleep service
    systemctl enable tlp-sleep.service
    
    # Check TLP status
    log_info "TLP status:"
    tlp-stat -s | head -20 | while read -r line; do
        log_info "  $line"
    done
    
    log_info "TLP setup completed"
    return 0
}

# Setup auto-cpufreq
setup_auto_cpufreq() {
    log_info "Setting up auto-cpufreq..."
    
    # Check if auto-cpufreq is installed
    if ! command -v auto-cpufreq &>/dev/null; then
        log_error "auto-cpufreq not installed"
        return 1
    fi
    
    # Stop conflicting services
    log_info "Stopping conflicting CPU frequency services..."
    systemctl stop tlp.service 2>/dev/null || true
    systemctl disable tlp.service 2>/dev/null || true
    systemctl stop power-profiles-daemon.service 2>/dev/null || true
    systemctl disable power-profiles-daemon.service 2>/dev/null || true
    
    # Install auto-cpufreq as a daemon
    auto-cpufreq --install
    
    # Check auto-cpufreq status
    log_info "auto-cpufreq status:"
    auto-cpufreq --stats | head -20 | while read -r line; do
        log_info "  $line"
    done
    
    log_info "auto-cpufreq setup completed"
    return 0
}

# Main power management setup
main() {
    log_info "Starting power management setup..."
    
    # Detect AMD P-state EPP support
    local pstate_status=0
    check_amd_pstate_epp_support || pstate_status=$?
    
    case $pstate_status in
        0)
            log_info "AMD P-state EPP is supported and active"
            ;;
        1)
            log_warn "AMD P-state EPP not supported on this system"
            ;;
        2)
            log_info "AMD P-state EPP supported but not active, configuring kernel parameters..."
            configure_amd_pstate_kernel_params || log_error "Failed to configure AMD P-state kernel parameters"
            ;;
    esac
    
    # Determine which power management solution to use
    # Priority: auto-cpufreq > TLP > power-profiles-daemon
    
    if command -v auto-cpufreq &>/dev/null; then
        log_info "Using auto-cpufreq for power management"
        setup_auto_cpufreq || log_error "Failed to setup auto-cpufreq"
    elif command -v tlp &>/dev/null; then
        log_info "Using TLP for power management"
        setup_tlp || log_error "Failed to setup TLP"
    elif command -v powerprofilesctl &>/dev/null; then
        log_info "Using power-profiles-daemon for power management"
        setup_power_profiles_daemon || log_error "Failed to setup power-profiles-daemon"
    else
        log_error "No supported power management tools found"
        return 1
    fi
    
    log_info "Power management setup completed successfully"
    return 0
}

# Run main function
main "$@"