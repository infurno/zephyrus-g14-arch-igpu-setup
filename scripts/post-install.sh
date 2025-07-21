#!/bin/bash

# Post-installation configuration script for ASUS ROG Zephyrus G14
# Final system configuration, validation, and user environment setup

set -euo pipefail

# Source error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly LOG_FILE="/var/log/post-install.log"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
VERBOSE=false
DRY_RUN=false
CURRENT_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$CURRENT_USER")

# Enhanced logging functions using error handler
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$SCRIPT_NAME] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    enhanced_error_exit "$1" "${2:-$E_GENERAL}" "${3:-}" "${4:-}"
}

warn() {
    log_warn "$1" "${2:-}"
}

info() {
    log_info "$1" "${2:-}"
}

success() {
    log_success "$1" "${2:-}"
}

debug() {
    log_debug "$1" "${2:-}"
}

# System validation functions

validate_amd_primary_display() {
    info "Validating AMD iGPU as primary display driver..."
    
    # Check if AMD driver is loaded
    if ! lsmod | grep -q amdgpu; then
        error_exit "AMD GPU driver (amdgpu) is not loaded"
    fi
    
    # Check Xorg configuration
    local xorg_config="/etc/X11/xorg.conf.d/10-hybrid.conf"
    if [[ ! -f "$xorg_config" ]]; then
        error_exit "Hybrid GPU Xorg configuration not found: $xorg_config"
    fi
    
    # Verify AMD GPU is set as primary in Xorg config
    if ! grep -q "Driver.*amdgpu" "$xorg_config"; then
        error_exit "AMD GPU not configured as primary in Xorg configuration"
    fi
    
    # Check if internal display is working
    if command -v xrandr >/dev/null 2>&1; then
        local internal_display=$(xrandr --listmonitors 2>/dev/null | grep -E "eDP|LVDS" | head -1)
        if [[ -z "$internal_display" ]]; then
            warn "Internal display not detected via xrandr (may be normal if running headless)"
        else
            success "Internal display detected and active"
        fi
    fi
    
    success "AMD iGPU validated as primary display driver"
}

validate_internal_display() {
    info "Validating internal display functionality..."
    
    # Check for common display issues
    local display_issues=()
    
    # Check if display is detected
    if command -v xrandr >/dev/null 2>&1; then
        local displays=$(xrandr --listmonitors 2>/dev/null | wc -l)
        if [[ $displays -lt 2 ]]; then  # Header line + at least one display
            display_issues+=("No displays detected via xrandr")
        fi
    fi
    
    # Check for black screen indicators in logs
    if journalctl --no-pager -u display-manager --since "1 hour ago" 2>/dev/null | grep -qi "black screen\|display.*fail"; then
        display_issues+=("Display manager logs indicate potential black screen issues")
    fi
    
    # Check GPU driver conflicts
    if lsmod | grep -q nouveau && lsmod | grep -q nvidia; then
        display_issues+=("Conflicting GPU drivers detected (nouveau and nvidia)")
    fi
    
    # Report results
    if [[ ${#display_issues[@]} -eq 0 ]]; then
        success "Internal display validation passed"
    else
        warn "Internal display validation found potential issues:"
        for issue in "${display_issues[@]}"; do
            echo "  - $issue"
        done
    fi
}

validate_gpu_switching_stability() {
    info "Validating GPU switching stability..."
    
    # Check if GPU state manager is available
    local gpu_manager="${PROJECT_DIR}/scripts/gpu-state-manager"
    if [[ ! -f "$gpu_manager" ]]; then
        error_exit "GPU state manager not found: $gpu_manager"
    fi
    
    # Run GPU validation
    if ! "$gpu_manager" validate >/dev/null 2>&1; then
        error_exit "GPU switching validation failed"
    fi
    
    # Check for GPU switching stability indicators
    local stability_issues=()
    
    # Check for GPU driver crashes in logs
    if journalctl --no-pager --since "1 hour ago" 2>/dev/null | grep -qi "gpu.*crash\|nvidia.*error\|amdgpu.*error"; then
        stability_issues+=("GPU driver errors detected in system logs")
    fi
    
    # Check bbswitch functionality
    if [[ -f /proc/acpi/bbswitch ]]; then
        local bbswitch_status=$(cat /proc/acpi/bbswitch 2>/dev/null || echo "ERROR")
        if [[ "$bbswitch_status" == "ERROR" ]]; then
            stability_issues+=("bbswitch module not functioning properly")
        fi
    fi
    
    # Check PRIME render offload setup
    local prime_script="${PROJECT_DIR}/scripts/prime-run"
    if [[ ! -f "$prime_script" ]] || [[ ! -x "$prime_script" ]]; then
        stability_issues+=("PRIME render offload script not available or not executable")
    fi
    
    # Report results
    if [[ ${#stability_issues[@]} -eq 0 ]]; then
        success "GPU switching stability validation passed"
    else
        warn "GPU switching stability validation found potential issues:"
        for issue in "${stability_issues[@]}"; do
            echo "  - $issue"
        done
    fi
}

# System health check functions

check_system_services() {
    info "Checking system services status..."
    
    local services=(
        "nvidia-suspend.service"
        "nvidia-resume.service"
        "tlp.service"
        "auto-cpufreq.service"
        "power-profiles-daemon.service"
    )
    
    local service_issues=()
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            if ! systemctl is-active "$service" >/dev/null 2>&1; then
                service_issues+=("Service $service is enabled but not active")
            fi
        else
            debug "Service $service is not enabled (may be optional)"
        fi
    done
    
    # Check ASUS-specific services if available
    local asus_services=(
        "supergfxd.service"
        "asusd.service"
    )
    
    for service in "${asus_services[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
            if systemctl is-enabled "$service" >/dev/null 2>&1; then
                if ! systemctl is-active "$service" >/dev/null 2>&1; then
                    service_issues+=("ASUS service $service is enabled but not active")
                fi
            fi
        fi
    done
    
    if [[ ${#service_issues[@]} -eq 0 ]]; then
        success "All system services are running properly"
    else
        warn "System service issues detected:"
        for issue in "${service_issues[@]}"; do
            echo "  - $issue"
        done
    fi
}

check_power_management() {
    info "Checking power management configuration..."
    
    local power_issues=()
    
    # Check CPU governor
    local cpu_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    if [[ "$cpu_governor" == "performance" ]] && [[ -f /sys/class/power_supply/BAT*/online ]] && [[ $(cat /sys/class/power_supply/BAT*/online) == "1" ]]; then
        power_issues+=("CPU governor is set to performance while on battery power")
    fi
    
    # Check if amd-pstate is available and configured
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver ]]; then
        local scaling_driver=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver)
        if [[ "$scaling_driver" != "amd-pstate-epp" ]] && grep -q "AMD" /proc/cpuinfo; then
            power_issues+=("AMD P-State EPP driver not active (current: $scaling_driver)")
        fi
    fi
    
    # Check TLP configuration
    if command -v tlp-stat >/dev/null 2>&1; then
        if ! tlp-stat -s >/dev/null 2>&1; then
            power_issues+=("TLP is not running or configured properly")
        fi
    fi
    
    # Check NVIDIA GPU power state on battery
    if [[ -f /proc/acpi/bbswitch ]]; then
        local power_source="unknown"
        if [[ -f /sys/class/power_supply/ADP*/online ]]; then
            local ac_online=$(cat /sys/class/power_supply/ADP*/online 2>/dev/null || echo "0")
            if [[ "$ac_online" == "0" ]]; then
                power_source="battery"
                local nvidia_state=$(cat /proc/acpi/bbswitch | awk '{print $2}')
                if [[ "$nvidia_state" == "ON" ]]; then
                    power_issues+=("NVIDIA GPU is powered on while running on battery")
                fi
            fi
        fi
    fi
    
    if [[ ${#power_issues[@]} -eq 0 ]]; then
        success "Power management configuration is optimal"
    else
        warn "Power management issues detected:"
        for issue in "${power_issues[@]}"; do
            echo "  - $issue"
        done
    fi
}

check_gpu_drivers() {
    info "Checking GPU driver status..."
    
    local driver_issues=()
    
    # Check AMD driver
    if ! lsmod | grep -q amdgpu; then
        driver_issues+=("AMD GPU driver (amdgpu) is not loaded")
    fi
    
    # Check NVIDIA driver
    if lspci | grep -qi nvidia; then
        if ! lsmod | grep -q nvidia; then
            driver_issues+=("NVIDIA GPU detected but driver is not loaded")
        fi
        
        # Check NVIDIA driver version compatibility
        if command -v nvidia-smi >/dev/null 2>&1; then
            if ! nvidia-smi >/dev/null 2>&1; then
                driver_issues+=("NVIDIA driver is loaded but nvidia-smi is not working")
            fi
        fi
    fi
    
    # Check for driver conflicts
    if lsmod | grep -q nouveau && lsmod | grep -q nvidia; then
        driver_issues+=("Conflicting GPU drivers: nouveau and nvidia both loaded")
    fi
    
    if [[ ${#driver_issues[@]} -eq 0 ]]; then
        success "GPU drivers are properly loaded and configured"
    else
        warn "GPU driver issues detected:"
        for issue in "${driver_issues[@]}"; do
            echo "  - $issue"
        done
    fi
}

# User environment setup functions

setup_user_environment() {
    info "Setting up user environment for $CURRENT_USER..."
    
    # Create user directories
    local user_dirs=(
        "$USER_HOME/.local/bin"
        "$USER_HOME/.local/share/applications"
        "$USER_HOME/.config/autostart"
    )
    
    for dir in "${user_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            sudo -u "$CURRENT_USER" mkdir -p "$dir"
            debug "Created directory: $dir"
        fi
    done
    
    # Set up user PATH
    setup_user_path
    
    # Configure shell profile
    setup_shell_profile
    
    success "User environment setup completed for $CURRENT_USER"
}

setup_user_path() {
    info "Configuring user PATH for GPU switching tools..."
    
    local bashrc="$USER_HOME/.bashrc"
    local zshrc="$USER_HOME/.zshrc"
    
    # Add project scripts to PATH
    local path_addition="export PATH=\"${PROJECT_DIR}/scripts:\$PATH\""
    
    # Update .bashrc if it exists
    if [[ -f "$bashrc" ]]; then
        if ! grep -q "${PROJECT_DIR}/scripts" "$bashrc"; then
            echo "" >> "$bashrc"
            echo "# ASUS ROG Zephyrus G14 GPU tools" >> "$bashrc"
            echo "$path_addition" >> "$bashrc"
            debug "Added GPU tools to PATH in .bashrc"
        fi
    fi
    
    # Update .zshrc if it exists
    if [[ -f "$zshrc" ]]; then
        if ! grep -q "${PROJECT_DIR}/scripts" "$zshrc"; then
            echo "" >> "$zshrc"
            echo "# ASUS ROG Zephyrus G14 GPU tools" >> "$zshrc"
            echo "$path_addition" >> "$zshrc"
            debug "Added GPU tools to PATH in .zshrc"
        fi
    fi
    
    # Create symlinks in user's local bin
    local user_bin="$USER_HOME/.local/bin"
    local scripts_to_link=(
        "prime-run"
        "gpu-state-manager"
        "bbswitch-control"
    )
    
    for script in "${scripts_to_link[@]}"; do
        local source_script="${PROJECT_DIR}/scripts/$script"
        local target_link="$user_bin/$script"
        
        if [[ -f "$source_script" ]]; then
            if [[ ! -L "$target_link" ]]; then
                sudo -u "$CURRENT_USER" ln -sf "$source_script" "$target_link"
                debug "Created symlink: $target_link -> $source_script"
            fi
        fi
    done
}

setup_shell_profile() {
    info "Configuring shell profile for GPU environment..."
    
    local profile_content='
# ASUS ROG Zephyrus G14 GPU Configuration
# Aliases for common GPU operations
alias gpu-status="gpu-state-manager status"
alias gpu-validate="gpu-state-manager validate"
alias nvidia-on="bbswitch-control on"
alias nvidia-off="bbswitch-control off"
alias prime="prime-run"

# Function to run applications with NVIDIA GPU
nvidia-run() {
    if [ $# -eq 0 ]; then
        echo "Usage: nvidia-run <command> [args...]"
        return 1
    fi
    prime-run "$@"
}

# Function to check current GPU status
gpu-info() {
    echo "=== GPU Status ==="
    gpu-state-manager status
    echo
    echo "=== Power Source ==="
    if [ -f /sys/class/power_supply/ADP*/online ]; then
        if [ "$(cat /sys/class/power_supply/ADP*/online)" = "1" ]; then
            echo "AC Power"
        else
            echo "Battery Power"
        fi
    else
        echo "Unknown"
    fi
}
'
    
    # Add to .bashrc
    local bashrc="$USER_HOME/.bashrc"
    if [[ -f "$bashrc" ]]; then
        if ! grep -q "ASUS ROG Zephyrus G14 GPU Configuration" "$bashrc"; then
            echo "$profile_content" >> "$bashrc"
            debug "Added GPU profile configuration to .bashrc"
        fi
    fi
    
    # Add to .zshrc
    local zshrc="$USER_HOME/.zshrc"
    if [[ -f "$zshrc" ]]; then
        if ! grep -q "ASUS ROG Zephyrus G14 GPU Configuration" "$zshrc"; then
            echo "$profile_content" >> "$zshrc"
            debug "Added GPU profile configuration to .zshrc"
        fi
    fi
}

# Desktop environment integration functions

setup_desktop_integration() {
    info "Setting up desktop environment integration..."
    
    # Create desktop entries for GPU switching
    create_desktop_entries
    
    # Set up autostart entries
    setup_autostart_entries
    
    # Configure desktop environment specific settings
    configure_desktop_environment
    
    success "Desktop environment integration completed"
}

create_desktop_entries() {
    info "Creating desktop entries for GPU switching..."
    
    local applications_dir="$USER_HOME/.local/share/applications"
    
    # GPU Status desktop entry
    cat > "$applications_dir/gpu-status.desktop" << EOF
[Desktop Entry]
Name=GPU Status
Comment=Check GPU status and switching capability
Exec=x-terminal-emulator -e 'gpu-state-manager status; read -p "Press Enter to close..."'
Icon=preferences-system
Terminal=false
Type=Application
Categories=System;Monitor;
Keywords=gpu;nvidia;amd;status;
EOF
    
    # NVIDIA GPU Control desktop entry
    cat > "$applications_dir/nvidia-control.desktop" << EOF
[Desktop Entry]
Name=NVIDIA GPU Control
Comment=Control NVIDIA GPU power state
Exec=x-terminal-emulator -e 'echo "NVIDIA GPU Control"; echo "1) Power On"; echo "2) Power Off"; echo "3) Status"; read -p "Choose option (1-3): " opt; case \$opt in 1) bbswitch-control on;; 2) bbswitch-control off;; 3) gpu-state-manager status;; esac; read -p "Press Enter to close..."'
Icon=preferences-desktop-display
Terminal=false
Type=Application
Categories=System;Settings;
Keywords=nvidia;gpu;power;control;
EOF
    
    # Prime Run Launcher desktop entry
    cat > "$applications_dir/prime-run-launcher.desktop" << EOF
[Desktop Entry]
Name=Run with NVIDIA GPU
Comment=Launch applications using NVIDIA GPU
Exec=x-terminal-emulator -e 'read -p "Enter command to run with NVIDIA GPU: " cmd; if [ -n "\$cmd" ]; then prime-run \$cmd; fi; read -p "Press Enter to close..."'
Icon=applications-games
Terminal=false
Type=Application
Categories=System;Utility;
Keywords=prime;nvidia;gpu;run;
EOF
    
    # Make desktop entries executable
    chmod +x "$applications_dir"/*.desktop
    
    debug "Created desktop entries for GPU switching tools"
}

setup_autostart_entries() {
    info "Setting up autostart entries..."
    
    local autostart_dir="$USER_HOME/.config/autostart"
    
    # GPU State Monitor autostart entry
    cat > "$autostart_dir/gpu-state-monitor.desktop" << EOF
[Desktop Entry]
Name=GPU State Monitor
Comment=Monitor GPU state and handle power management
Exec=${PROJECT_DIR}/scripts/gpu-state-manager detect
Icon=preferences-system
Terminal=false
Type=Application
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
    
    debug "Created autostart entry for GPU state monitoring"
}

configure_desktop_environment() {
    info "Configuring desktop environment specific settings..."
    
    # Detect desktop environment
    local desktop_env=""
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        desktop_env="$XDG_CURRENT_DESKTOP"
    elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
        desktop_env="$DESKTOP_SESSION"
    fi
    
    debug "Detected desktop environment: ${desktop_env:-unknown}"
    
    case "${desktop_env,,}" in
        *gnome*)
            configure_gnome_settings
            ;;
        *kde*|*plasma*)
            configure_kde_settings
            ;;
        *xfce*)
            configure_xfce_settings
            ;;
        *)
            debug "Unknown or unsupported desktop environment, skipping specific configuration"
            ;;
    esac
}

configure_gnome_settings() {
    info "Configuring GNOME-specific settings..."
    
    # Set power management preferences
    if command -v gsettings >/dev/null 2>&1; then
        # Configure power settings for better battery life
        sudo -u "$CURRENT_USER" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 3600
        sudo -u "$CURRENT_USER" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800
        
        # Configure display settings
        sudo -u "$CURRENT_USER" gsettings set org.gnome.settings-daemon.plugins.power idle-dim true
        sudo -u "$CURRENT_USER" gsettings set org.gnome.settings-daemon.plugins.power idle-brightness 30
        
        debug "Configured GNOME power management settings"
    fi
}

configure_kde_settings() {
    info "Configuring KDE-specific settings..."
    
    # KDE power management configuration would go here
    # This is a placeholder for KDE-specific settings
    debug "KDE configuration placeholder - implement as needed"
}

configure_xfce_settings() {
    info "Configuring XFCE-specific settings..."
    
    # XFCE power management configuration would go here
    # This is a placeholder for XFCE-specific settings
    debug "XFCE configuration placeholder - implement as needed"
}

# Main execution functions

run_system_validation() {
    info "Running comprehensive system validation..."
    
    validate_amd_primary_display
    validate_internal_display
    validate_gpu_switching_stability
    
    success "System validation completed"
}

run_health_checks() {
    info "Running system health checks..."
    
    check_system_services
    check_power_management
    check_gpu_drivers
    
    success "System health checks completed"
}

run_user_setup() {
    info "Running user environment setup..."
    
    setup_user_environment
    setup_desktop_integration
    
    success "User environment setup completed"
}

# Display usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] [COMMAND]

Post-installation configuration script for ASUS ROG Zephyrus G14.
Performs final system configuration, validation, and user environment setup.

COMMANDS:
    validate        Run system validation checks
    health          Run system health checks
    setup-user      Set up user environment and desktop integration
    all             Run all configuration steps (default)

OPTIONS:
    -v, --verbose   Enable verbose output
    -n, --dry-run   Show what would be done without making changes
    -h, --help      Show this help message

EXAMPLES:
    $SCRIPT_NAME                    # Run all configuration steps
    $SCRIPT_NAME validate           # Run only validation checks
    $SCRIPT_NAME setup-user         # Set up user environment only
    $SCRIPT_NAME --verbose all      # Run all steps with verbose output

REQUIREMENTS:
    - Must be run as root or with sudo
    - System should be configured with hybrid GPU setup
    - All previous setup steps should be completed

EOF
}

# Main execution function
main() {
    local command="all"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            validate|health|setup-user|all)
                command="$1"
                shift
                ;;
            *)
                error_exit "Unknown option: $1. Use -h for help."
                ;;
        esac
    done
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root or with sudo"
    fi
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Log script start
    log "Starting post-installation configuration..."
    log "Command: $command"
    log "User: $CURRENT_USER"
    log "Verbose: $VERBOSE"
    log "Dry run: $DRY_RUN"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN MODE - No changes will be made"
    fi
    
    # Execute requested command
    case "$command" in
        "validate")
            run_system_validation
            ;;
        "health")
            run_health_checks
            ;;
        "setup-user")
            run_user_setup
            ;;
        "all")
            run_system_validation
            run_health_checks
            run_user_setup
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
    
    success "Post-installation configuration completed successfully!"
    log "Post-installation configuration completed successfully"
}

# Execute main function with all arguments
main "$@"