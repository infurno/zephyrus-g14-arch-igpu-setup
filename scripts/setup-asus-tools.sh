#!/bin/bash
# ASUS Hardware Tools Setup Script
# Configures asusctl, supergfxctl, rog-control-center, and switcheroo-control

set -euo pipefail

# Source error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly CONFIG_DIR="${SCRIPT_DIR}/../configs/asus"

# Global variables for error tracking
ASUS_TOOLS_FAILED=()
CRITICAL_FAILURES=false

# Validation functions
validate_asus_config_permissions() {
    local config_dir="$1"
    
    log_debug "Validating ASUS configuration directory permissions: $config_dir"
    
    # Check directory exists and has correct permissions
    if [[ ! -d "$config_dir" ]]; then
        log_error "ASUS configuration directory does not exist: $config_dir"
        return 1
    fi
    
    # Check directory permissions (should be 755)
    local dir_perms=$(stat -c "%a" "$config_dir")
    if [[ "$dir_perms" != "755" ]]; then
        log_warn "ASUS configuration directory has incorrect permissions: $dir_perms (expected 755)"
        sudo chmod 755 "$config_dir" || return 1
    fi
    
    # Check config file permissions
    for config_file in "$config_dir"/*.conf; do
        if [[ -f "$config_file" ]]; then
            local file_perms=$(stat -c "%a" "$config_file")
            if [[ "$file_perms" != "644" ]]; then
                log_warn "Configuration file has incorrect permissions: $config_file ($file_perms, expected 644)"
                sudo chmod 644 "$config_file" || return 1
            fi
        fi
    done
    
    return 0
}

validate_asusctl_functionality() {
    log_debug "Validating asusctl functionality..."
    
    # Check if asusctl responds to version command
    if ! asusctl --version &>/dev/null; then
        log_error "asusctl does not respond to version command"
        return 1
    fi
    
    # Check if asusd service is running
    if ! systemctl is-active asusd.service &>/dev/null; then
        log_warn "asusd service is not active"
        return 1
    fi
    
    # Test basic functionality
    if ! asusctl profile -l &>/dev/null; then
        log_warn "asusctl profile listing failed"
        return 1
    fi
    
    log_debug "asusctl functionality validation passed"
    return 0
}

validate_supergfxctl_functionality() {
    log_debug "Validating supergfxctl functionality..."
    
    # Check if supergfxctl responds to version command
    if ! supergfxctl --version &>/dev/null; then
        log_error "supergfxctl does not respond to version command"
        return 1
    fi
    
    # Check if supergfxd service is running
    if ! systemctl is-active supergfxd.service &>/dev/null; then
        log_warn "supergfxd service is not active"
        return 1
    fi
    
    # Test basic functionality
    if ! supergfxctl -g &>/dev/null; then
        log_warn "supergfxctl GPU mode query failed"
        return 1
    fi
    
    log_debug "supergfxctl functionality validation passed"
    return 0
}

# Recovery functions
recover_asus_config_install() {
    log_info "Attempting to recover ASUS configuration installation..."
    
    local asus_config_dir="/etc/asus"
    
    # Remove potentially corrupted configuration directory
    if [[ -d "$asus_config_dir" ]]; then
        log_info "Removing potentially corrupted ASUS configuration directory..."
        sudo rm -rf "$asus_config_dir" || {
            log_error "Failed to remove corrupted configuration directory"
            return 1
        }
    fi
    
    # Recreate directory with correct permissions
    if sudo mkdir -p "$asus_config_dir"; then
        sudo chmod 755 "$asus_config_dir"
        log_success "ASUS configuration directory recreated"
        return 0
    else
        log_error "Failed to recreate ASUS configuration directory"
        return 1
    fi
}

recover_asus_service() {
    local service_name="$1"
    
    log_info "Attempting to recover ASUS service: $service_name"
    
    # Stop the service
    sudo systemctl stop "$service_name" 2>/dev/null || true
    
    # Reset failed state
    sudo systemctl reset-failed "$service_name" 2>/dev/null || true
    
    # Reload systemd daemon
    sudo systemctl daemon-reload
    
    # Try to start the service
    if sudo systemctl start "$service_name"; then
        log_success "ASUS service $service_name recovered"
        return 0
    else
        log_error "Failed to recover ASUS service: $service_name"
        return 1
    fi
}

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should not be run as root. Please run as a regular user with sudo privileges."
    fi
}

# Check sudo privileges
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo privileges. You may be prompted for your password."
        if ! sudo true; then
            error_exit "Failed to obtain sudo privileges"
        fi
    fi
}

# Install ASUS configuration files with error handling and backup
install_asus_configs() {
    log_info "Installing ASUS configuration files..."
    
    # Create rollback point
    create_rollback_point "asus-config-install" "Before ASUS configuration installation" || {
        log_warn "Failed to create rollback point, continuing without rollback capability"
    }
    
    # Create ASUS config directory with error handling
    local asus_config_dir="/etc/asus"
    if ! sudo mkdir -p "$asus_config_dir"; then
        error_exit "Failed to create ASUS configuration directory: $asus_config_dir" "$E_CONFIG_ERROR" "recover_asus_config_install"
    fi
    
    # Install asusctl configuration with backup and validation
    if [[ -f "$CONFIG_DIR/asusctl.conf" ]]; then
        if install_config_with_backup "$CONFIG_DIR/asusctl.conf" "$asus_config_dir/asusctl.conf" "asusctl configuration"; then
            log_success "asusctl configuration installed"
        else
            ASUS_TOOLS_FAILED+=("asusctl-config")
            log_error "Failed to install asusctl configuration"
        fi
    else
        log_warn "asusctl configuration file not found: $CONFIG_DIR/asusctl.conf"
    fi
    
    # Install supergfxctl configuration with backup and validation
    if [[ -f "$CONFIG_DIR/supergfxctl.conf" ]]; then
        if install_config_with_backup "$CONFIG_DIR/supergfxctl.conf" "$asus_config_dir/supergfxctl.conf" "supergfxctl configuration"; then
            log_success "supergfxctl configuration installed"
        else
            ASUS_TOOLS_FAILED+=("supergfxctl-config")
            log_error "Failed to install supergfxctl configuration"
        fi
    else
        log_warn "supergfxctl configuration file not found: $CONFIG_DIR/supergfxctl.conf"
    fi
    
    # Validate configuration directory permissions
    if ! validate_asus_config_permissions "$asus_config_dir"; then
        log_warn "ASUS configuration directory permissions may be incorrect"
    fi
}

# Configure asusctl with comprehensive error handling
configure_asusctl() {
    log_info "Configuring asusctl..."
    
    if ! command -v asusctl &>/dev/null; then
        ASUS_TOOLS_FAILED+=("asusctl-missing")
        log_error "asusctl is not installed"
        return 1
    fi
    
    # Enable and start asusd service with recovery
    if ! manage_service_with_recovery "asusd" "enable"; then
        ASUS_TOOLS_FAILED+=("asusd-enable")
        log_error "Failed to enable asusd service"
        return 1
    fi
    
    if ! manage_service_with_recovery "asusd" "start"; then
        log_warn "asusd service may require reboot to start"
        # Don't fail here as service might start after reboot
    fi
    
    # Wait for service to be ready
    local retry_count=0
    local max_retries=5
    while [[ $retry_count -lt $max_retries ]]; do
        if asusctl --version &>/dev/null; then
            break
        fi
        log_debug "Waiting for asusctl to be ready... (attempt $((retry_count + 1))/$max_retries)"
        sleep 2
        ((retry_count++))
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        log_warn "asusctl may not be fully ready, continuing with configuration"
    fi
    
    # Apply configuration settings with error handling
    log_info "Applying asusctl settings..."
    local settings_failed=()
    
    # Set fan profile to balanced
    if ! asusctl profile -P balanced &>/dev/null; then
        settings_failed+=("fan-profile")
        log_warn "Could not set fan profile to balanced"
    else
        log_debug "Fan profile set to balanced"
    fi
    
    # Set keyboard backlight to medium
    if ! asusctl -k med &>/dev/null; then
        settings_failed+=("keyboard-backlight")
        log_warn "Could not set keyboard backlight"
    else
        log_debug "Keyboard backlight set to medium"
    fi
    
    # Set LED mode to static
    if ! asusctl led-mode static &>/dev/null; then
        settings_failed+=("led-mode")
        log_warn "Could not set LED mode to static"
    else
        log_debug "LED mode set to static"
    fi
    
    # Configure battery charge thresholds (if supported)
    if ! asusctl -c 80 &>/dev/null; then
        settings_failed+=("battery-threshold")
        log_warn "Could not set battery charge threshold (may not be supported)"
    else
        log_debug "Battery charge threshold set to 80%"
    fi
    
    # Report configuration results
    if [[ ${#settings_failed[@]} -gt 0 ]]; then
        log_warn "Some asusctl settings failed: ${settings_failed[*]}"
        ASUS_TOOLS_FAILED+=("asusctl-settings")
    fi
    
    # Validate asusctl functionality
    if validate_asusctl_functionality; then
        log_success "asusctl configured and validated successfully"
        return 0
    else
        ASUS_TOOLS_FAILED+=("asusctl-validation")
        log_error "asusctl configuration validation failed"
        return 1
    fi
}

# Configure supergfxctl
configure_supergfxctl() {
    log_info "Configuring supergfxctl..."
    
    if ! command -v supergfxctl &>/dev/null; then
        log_error "supergfxctl is not installed"
        return 1
    fi
    
    # Enable and start supergfxd service
    sudo systemctl enable supergfxd.service
    sudo systemctl start supergfxd.service || log_warn "supergfxd service may require reboot to start"
    
    # Set GPU mode to hybrid
    log_info "Setting GPU mode to hybrid..."
    supergfxctl -m hybrid &>/dev/null || log_warn "Could not set GPU mode to hybrid"
    
    # Check current status
    local gpu_mode=$(supergfxctl -g 2>/dev/null || echo "unknown")
    log_info "Current GPU mode: $gpu_mode"
    
    log_success "supergfxctl configured successfully"
}

# Configure rog-control-center
configure_rog_control_center() {
    log_info "Configuring rog-control-center..."
    
    if ! command -v rog-control-center &>/dev/null; then
        log_error "rog-control-center is not installed"
        return 1
    fi
    
    # Create desktop entry
    local desktop_file="/usr/share/applications/rog-control-center.desktop"
    if [[ ! -f "$desktop_file" ]]; then
        sudo tee "$desktop_file" > /dev/null << 'EOF'
[Desktop Entry]
Name=ROG Control Center
Comment=ASUS ROG laptop control center
Exec=rog-control-center
Icon=rog-control-center
Terminal=false
Type=Application
Categories=System;Settings;
Keywords=asus;rog;control;hardware;
EOF
        sudo chmod 644 "$desktop_file"
        log_success "Desktop entry created"
    fi
    
    # Add user to input group for hardware access
    local current_user=$(whoami)
    if ! groups "$current_user" | grep -q "input"; then
        sudo usermod -a -G input "$current_user"
        log_success "User added to input group"
        log_info "Please log out and back in for group changes to take effect"
    fi
    
    log_success "rog-control-center configured successfully"
}

# Configure switcheroo-control
configure_switcheroo_control() {
    log_info "Configuring switcheroo-control..."
    
    if ! command -v switcherooctl &>/dev/null; then
        log_error "switcheroo-control is not installed"
        return 1
    fi
    
    # Enable and start service
    sudo systemctl enable switcheroo-control.service
    sudo systemctl start switcheroo-control.service || log_warn "switcheroo-control service may require reboot to start"
    
    # Create GPU switching helper script
    local switch_script="${SCRIPT_DIR}/gpu-switch"
    cat > "$switch_script" << 'EOF'
#!/bin/bash
# GPU switching helper script

set -euo pipefail

show_usage() {
    echo "Usage: $0 [integrated|discrete|auto|status]"
    echo "  integrated - Switch to integrated GPU (power saving)"
    echo "  discrete   - Switch to discrete GPU (performance)"
    echo "  auto       - Let system decide based on workload"
    echo "  status     - Show current GPU status"
}

case "${1:-status}" in
    "integrated"|"igpu")
        echo "Switching to integrated GPU..."
        switcherooctl switch integrated
        ;;
    "discrete"|"dgpu"|"nvidia")
        echo "Switching to discrete GPU..."
        switcherooctl switch discrete
        ;;
    "auto")
        echo "Setting GPU switching to auto mode..."
        switcherooctl switch auto
        ;;
    "status")
        echo "Current GPU status:"
        switcherooctl list
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        echo "Error: Unknown option '$1'"
        show_usage
        exit 1
        ;;
esac
EOF
    
    chmod +x "$switch_script"
    log_success "GPU switching helper script created"
    
    # Create udev rule for automatic GPU switching
    local udev_rule="/etc/udev/rules.d/82-gpu-power-switch.rules"
    sudo tee "$udev_rule" > /dev/null << 'EOF'
# Automatic GPU switching based on power state
SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="/usr/bin/switcherooctl switch integrated"
SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="/usr/bin/switcherooctl switch auto"
EOF
    
    sudo chmod 644 "$udev_rule"
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    log_success "switcheroo-control configured successfully"
}

# Configure power-profiles-daemon
configure_power_profiles() {
    log_info "Configuring power-profiles-daemon..."
    
    if ! command -v powerprofilesctl &>/dev/null; then
        log_warn "powerprofilesctl not available"
        return 0
    fi
    
    # Enable and start service
    sudo systemctl enable power-profiles-daemon.service
    sudo systemctl start power-profiles-daemon.service || log_warn "power-profiles-daemon may require reboot to start"
    
    # Set default profile to balanced
    powerprofilesctl set balanced &>/dev/null || log_warn "Could not set power profile"
    
    log_success "power-profiles-daemon configured successfully"
}

# Show system status
show_status() {
    echo
    log_info "=== ASUS Hardware Status ==="
    
    # Check services
    echo
    log_info "Service Status:"
    for service in asusd supergfxd switcheroo-control power-profiles-daemon; do
        if systemctl is-active "${service}.service" &>/dev/null; then
            log_success "$service: active"
        else
            log_warn "$service: inactive"
        fi
    done
    
    # Check GPU status
    echo
    log_info "GPU Status:"
    if command -v supergfxctl &>/dev/null; then
        local gpu_mode=$(supergfxctl -g 2>/dev/null || echo "unknown")
        log_info "Current GPU mode: $gpu_mode"
    fi
    
    if command -v switcherooctl &>/dev/null; then
        log_info "Available GPUs:"
        switcherooctl list 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
    fi
    
    # Check power profile
    echo
    log_info "Power Profile:"
    if command -v powerprofilesctl &>/dev/null; then
        local profile=$(powerprofilesctl get 2>/dev/null || echo "unknown")
        log_info "Current profile: $profile"
    fi
    
    echo
}

# Main function
main() {
    log_info "=== ASUS Hardware Tools Setup ==="
    
    check_not_root
    check_sudo
    
    # Install configuration files
    install_asus_configs
    
    # Configure each tool
    configure_asusctl || log_warn "asusctl configuration failed"
    configure_supergfxctl || log_warn "supergfxctl configuration failed"
    configure_rog_control_center || log_warn "rog-control-center configuration failed"
    configure_switcheroo_control || log_warn "switcheroo-control configuration failed"
    configure_power_profiles || log_warn "power-profiles-daemon configuration failed"
    
    # Show final status
    show_status
    
    log_success "=== ASUS Hardware Tools Setup Complete ==="
    log_info "Note: Some changes may require a reboot to take effect"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi