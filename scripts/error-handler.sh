#!/bin/bash

# Centralized Error Handling and Recovery System
# Provides comprehensive error handling, logging, and recovery mechanisms

# Error handling configuration
readonly ERROR_HANDLER_VERSION="1.0.0"
readonly ERROR_LOG_DIR="/var/log/zephyrus-g14-setup"
readonly ERROR_LOG_FILE="${ERROR_LOG_DIR}/error.log"
readonly RECOVERY_LOG_FILE="${ERROR_LOG_DIR}/recovery.log"
readonly BACKUP_DIR="/var/backups/zephyrus-g14-setup"

# Error codes
readonly E_SUCCESS=0
readonly E_GENERAL=1
readonly E_PACKAGE_INSTALL=2
readonly E_CONFIG_ERROR=3
readonly E_SERVICE_ERROR=4
readonly E_HARDWARE_ERROR=5
readonly E_PERMISSION_ERROR=6
readonly E_NETWORK_ERROR=7
readonly E_ROLLBACK_ERROR=8

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global error tracking
declare -g ERROR_COUNT=0
declare -g LAST_ERROR_CODE=0
declare -g LAST_ERROR_MESSAGE=""
declare -g RECOVERY_ATTEMPTED=false
declare -g ROLLBACK_AVAILABLE=false

# Initialize error handling system
init_error_handler() {
    # Create log directories
    sudo mkdir -p "$ERROR_LOG_DIR" "$BACKUP_DIR"
    sudo chmod 755 "$ERROR_LOG_DIR" "$BACKUP_DIR"
    
    # Initialize log files
    sudo touch "$ERROR_LOG_FILE" "$RECOVERY_LOG_FILE"
    sudo chmod 644 "$ERROR_LOG_FILE" "$RECOVERY_LOG_FILE"
    
    # Set up trap for cleanup
    trap 'cleanup_on_exit $?' EXIT
    trap 'handle_interrupt' INT TERM
    
    log_info "Error handling system initialized (v${ERROR_HANDLER_VERSION})"
}

# Logging functions with error context
log_with_context() {
    local level="$1"
    local message="$2"
    local context="${3:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"
    
    local log_entry="[$timestamp] [$level] [$caller] $message"
    if [[ -n "$context" ]]; then
        log_entry="$log_entry | Context: $context"
    fi
    
    echo "$log_entry" | sudo tee -a "$ERROR_LOG_FILE" >/dev/null
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "DEBUG")
            if [[ "${VERBOSE:-false}" == "true" ]]; then
                echo -e "${CYAN}[DEBUG]${NC} $message"
            fi
            ;;
    esac
}

log_error() {
    log_with_context "ERROR" "$1" "${2:-}"
    ERROR_COUNT=$((ERROR_COUNT + 1))
    LAST_ERROR_MESSAGE="$1"
}

log_warn() {
    log_with_context "WARN" "$1" "${2:-}"
}

log_info() {
    log_with_context "INFO" "$1" "${2:-}"
}

log_success() {
    log_with_context "SUCCESS" "$1" "${2:-}"
}

log_debug() {
    log_with_context "DEBUG" "$1" "${2:-}"
}

# Enhanced error exit with recovery options
error_exit() {
    local error_message="$1"
    local exit_code="${2:-$E_GENERAL}"
    local recovery_function="${3:-}"
    local context="${4:-}"
    
    LAST_ERROR_CODE="$exit_code"
    log_error "$error_message" "$context"
    
    # Attempt recovery if function provided
    if [[ -n "$recovery_function" ]] && [[ "$RECOVERY_ATTEMPTED" == false ]]; then
        RECOVERY_ATTEMPTED=true
        log_info "Attempting automatic recovery..."
        
        if "$recovery_function"; then
            log_success "Recovery successful, continuing..."
            return 0
        else
            log_error "Recovery failed"
        fi
    fi
    
    # Offer rollback if available
    if [[ "$ROLLBACK_AVAILABLE" == true ]]; then
        offer_rollback
    fi
    
    log_error "Setup failed with exit code: $exit_code"
    log_error "Check error log: $ERROR_LOG_FILE"
    
    exit "$exit_code"
}

# Rollback system
create_rollback_point() {
    local rollback_name="$1"
    local description="${2:-Automatic rollback point}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local rollback_dir="${BACKUP_DIR}/rollback_${rollback_name}_${timestamp}"
    
    log_info "Creating rollback point: $rollback_name"
    
    sudo mkdir -p "$rollback_dir"
    
    # Backup critical system files
    backup_system_configs "$rollback_dir"
    
    # Create rollback metadata
    cat << EOF | sudo tee "$rollback_dir/metadata.json" >/dev/null
{
    "name": "$rollback_name",
    "description": "$description",
    "timestamp": "$timestamp",
    "created_by": "${USER:-unknown}",
    "system_info": {
        "kernel": "$(uname -r)",
        "hostname": "$(hostname)",
        "packages": "$(dnf list installed | wc -l)"
    }
}
EOF
    
    # Mark rollback as available
    ROLLBACK_AVAILABLE=true
    echo "$rollback_dir" > "${BACKUP_DIR}/.last_rollback"
    
    log_success "Rollback point created: $rollback_dir"
}

backup_system_configs() {
    local backup_dir="$1"
    
    log_debug "Backing up system configurations to $backup_dir"
    
    # Backup directories and files
    local backup_items=(
        "/etc/X11/xorg.conf.d"
        "/etc/tlp.conf"
        "/etc/auto-cpufreq.conf"
        "/etc/dnf/dnf.conf"
        "/etc/dracut.conf.d"
        "/etc/default/grub"
        "/etc/systemd/system"
        "/etc/udev/rules.d"
        "/etc/modules-load.d"
        "/etc/modprobe.d"
    )
    
    for item in "${backup_items[@]}"; do
        if [[ -e "$item" ]]; then
            local item_name=$(basename "$item")
            local parent_dir=$(dirname "$item")
            sudo mkdir -p "${backup_dir}${parent_dir}"
            sudo cp -r "$item" "${backup_dir}${parent_dir}/" 2>/dev/null || true
            log_debug "Backed up: $item"
        fi
    done
    
    # Backup package list
    dnf list installed > "${backup_dir}/package_list.txt" 2>/dev/null || true
    
    # Backup service states
    systemctl list-unit-files --state=enabled > "${backup_dir}/enabled_services.txt" 2>/dev/null || true
}

offer_rollback() {
    if [[ ! -f "${BACKUP_DIR}/.last_rollback" ]]; then
        log_warn "No rollback point available"
        return 1
    fi
    
    local last_rollback=$(cat "${BACKUP_DIR}/.last_rollback")
    
    if [[ ! -d "$last_rollback" ]]; then
        log_warn "Rollback directory not found: $last_rollback"
        return 1
    fi
    
    echo -e "${YELLOW}A rollback point is available. Would you like to restore your system?${NC}"
    echo "Rollback point: $(basename "$last_rollback")"
    
    if [[ -f "$last_rollback/metadata.json" ]]; then
        local description=$(grep '"description"' "$last_rollback/metadata.json" | cut -d'"' -f4)
        local timestamp=$(grep '"timestamp"' "$last_rollback/metadata.json" | cut -d'"' -f4)
        echo "Description: $description"
        echo "Created: $timestamp"
    fi
    
    read -p "Restore from rollback? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        perform_rollback "$last_rollback"
    fi
}

perform_rollback() {
    local rollback_dir="$1"
    
    log_info "Starting system rollback from: $rollback_dir"
    echo "$rollback_dir" | sudo tee -a "$RECOVERY_LOG_FILE" >/dev/null
    
    # Restore system configurations
    if restore_system_configs "$rollback_dir"; then
        log_success "System configurations restored"
    else
        log_error "Failed to restore system configurations"
        return 1
    fi
    
    # Restore services
    if restore_services "$rollback_dir"; then
        log_success "Services restored"
    else
        log_warn "Some services may not have been restored properly"
    fi
    
    log_success "Rollback completed successfully"
    log_info "You may need to reboot for all changes to take effect"
    
    return 0
}

restore_system_configs() {
    local rollback_dir="$1"
    local restore_failed=false
    
    log_debug "Restoring system configurations from $rollback_dir"
    
    # Restore configuration files
    local config_dirs=(
        "/etc/X11/xorg.conf.d"
        "/etc/systemd/system"
        "/etc/udev/rules.d"
        "/etc/modules-load.d"
        "/etc/modprobe.d"
    )
    
    for config_dir in "${config_dirs[@]}"; do
        local backup_path="${rollback_dir}${config_dir}"
        if [[ -d "$backup_path" ]]; then
            sudo rm -rf "$config_dir" 2>/dev/null || true
            sudo cp -r "$backup_path" "$config_dir" || {
                log_error "Failed to restore: $config_dir"
                restore_failed=true
            }
        fi
    done
    
    # Restore individual config files
    local config_files=(
        "/etc/tlp.conf"
        "/etc/auto-cpufreq.conf"
        "/etc/dnf/dnf.conf"
        "/etc/dracut.conf.d"
        "/etc/default/grub"
    )
    
    for config_file in "${config_files[@]}"; do
        local backup_file="${rollback_dir}${config_file}"
        if [[ -f "$backup_file" ]]; then
            sudo cp "$backup_file" "$config_file" || {
                log_error "Failed to restore: $config_file"
                restore_failed=true
            }
        fi
    done
    
    if [[ "$restore_failed" == true ]]; then
        return 1
    fi
    
    return 0
}

restore_services() {
    local rollback_dir="$1"
    local services_file="${rollback_dir}/enabled_services.txt"
    
    if [[ ! -f "$services_file" ]]; then
        log_warn "No services backup found"
        return 0
    fi
    
    log_debug "Restoring service states"
    
    # Disable all services that might have been enabled
    local current_services=(
        "tlp.service"
        "auto-cpufreq.service"
        "power-profiles-daemon.service"
        "nvidia-suspend.service"
        "nvidia-resume.service"
        "asusd.service"
        "supergfxd.service"
    )
    
    for service in "${current_services[@]}"; do
        sudo systemctl disable "$service" 2>/dev/null || true
    done
    
    # Re-enable services from backup
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)\.service[[:space:]]+enabled ]]; then
            local service="${BASH_REMATCH[1]}.service"
            sudo systemctl enable "$service" 2>/dev/null || {
                log_warn "Failed to enable service: $service"
            }
        fi
    done < "$services_file"
    
    return 0
}

# Recovery functions for common failures
recover_package_installation() {
    log_info "Attempting package installation recovery..."
    
    # Update package database
    if sudo dnf makecache; then
        log_success "Package database updated"
    else
        log_error "Failed to update package database"
        return 1
    fi
    
    # Clear package cache if corrupted
    if sudo dnf clean all; then
        log_success "Package cache cleared"
    fi
    
    # Try to fix broken packages
    if sudo dnf install -y fedora-gpg-keys; then
        log_success "GPG keys updated"
    fi
    
    return 0
}

recover_service_failure() {
    local service_name="$1"
    
    log_info "Attempting service recovery for: $service_name"
    
    # Stop the service
    sudo systemctl stop "$service_name" 2>/dev/null || true
    
    # Reset failed state
    sudo systemctl reset-failed "$service_name" 2>/dev/null || true
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Try to start the service again
    if sudo systemctl start "$service_name"; then
        log_success "Service $service_name recovered"
        return 0
    else
        log_error "Failed to recover service: $service_name"
        return 1
    fi
}

recover_gpu_driver() {
    log_info "Attempting GPU driver recovery..."
    
    # Unload and reload kernel modules
    local modules=("nvidia_drm" "nvidia_modeset" "nvidia" "amdgpu")
    
    for module in "${modules[@]}"; do
        sudo modprobe -r "$module" 2>/dev/null || true
    done
    
    sleep 2
    
    for module in "${modules[@]}"; do
        if sudo modprobe "$module"; then
            log_debug "Reloaded module: $module"
        else
            log_warn "Failed to reload module: $module"
        fi
    done
    
    # Restart display manager if running
    if systemctl is-active display-manager >/dev/null 2>&1; then
        log_info "Restarting display manager..."
        sudo systemctl restart display-manager || {
            log_warn "Failed to restart display manager"
        }
    fi
    
    return 0
}

recover_xorg_config() {
    log_info "Attempting Xorg configuration recovery..."
    
    local xorg_config_dir="/etc/X11/xorg.conf.d"
    local backup_config_dir="/etc/X11/xorg.conf.d.backup"
    
    # Check if backup exists
    if [[ -d "$backup_config_dir" ]]; then
        local latest_backup=$(ls -1t "$backup_config_dir" | head -1)
        if [[ -n "$latest_backup" ]]; then
            log_info "Restoring Xorg configuration from backup: $latest_backup"
            sudo rm -rf "$xorg_config_dir"
            sudo cp -r "${backup_config_dir}/${latest_backup}" "$xorg_config_dir"
            log_success "Xorg configuration restored"
            return 0
        fi
    fi
    
    # Generate minimal working configuration
    log_info "Creating minimal Xorg configuration..."
    sudo mkdir -p "$xorg_config_dir"
    
    cat << 'EOF' | sudo tee "$xorg_config_dir/10-minimal.conf" >/dev/null
Section "Device"
    Identifier "AMD"
    Driver "amdgpu"
EndSection

Section "Screen"
    Identifier "AMD"
    Device "AMD"
EndSection
EOF
    
    log_success "Minimal Xorg configuration created"
    return 0
}

# Interrupt handler
handle_interrupt() {
    log_warn "Received interrupt signal"
    
    if [[ "$ROLLBACK_AVAILABLE" == true ]]; then
        echo -e "\n${YELLOW}Setup interrupted. Rollback is available.${NC}"
        offer_rollback
    fi
    
    cleanup_on_exit 130
    exit 130
}

# Cleanup function
cleanup_on_exit() {
    local exit_code="$1"
    
    if [[ "$exit_code" -ne 0 ]] && [[ "$ERROR_COUNT" -gt 0 ]]; then
        log_error "Script exited with errors (exit code: $exit_code)"
        log_error "Total errors encountered: $ERROR_COUNT"
        log_error "Last error: $LAST_ERROR_MESSAGE"
        
        echo -e "\n${RED}Setup completed with errors!${NC}"
        echo -e "Error log: $ERROR_LOG_FILE"
        echo -e "Recovery log: $RECOVERY_LOG_FILE"
        
        if [[ "$ROLLBACK_AVAILABLE" == true ]]; then
            echo -e "Rollback available - run with --rollback option to restore"
        fi
    fi
}

# Validation functions
validate_system_state() {
    log_info "Validating system state..."
    
    local validation_errors=()
    
    # Check critical services
    local critical_services=("systemd-logind" "dbus" "NetworkManager")
    for service in "${critical_services[@]}"; do
        if ! systemctl is-active "$service" >/dev/null 2>&1; then
            validation_errors+=("Critical service not running: $service")
        fi
    done
    
    # Check filesystem integrity
    if ! df -h / >/dev/null 2>&1; then
        validation_errors+=("Root filesystem check failed")
    fi
    
    # Check package manager
    if ! dnf list >/dev/null 2>&1; then
        validation_errors+=("Package manager not responding")
    fi
    
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "System validation failed:"
        for error in "${validation_errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
    
    log_success "System state validation passed"
    return 0
}

# Enhanced error handling for specific operations
handle_package_error() {
    local package="$1"
    local error_output="$2"
    
    log_error "Package installation failed: $package" "$error_output"
    
    # Analyze error and suggest recovery
    if echo "$error_output" | grep -q "signature"; then
        log_info "Signature error detected, attempting keyring update..."
        recover_package_installation
    elif echo "$error_output" | grep -q "conflict"; then
        log_info "Package conflict detected"
        # Could implement conflict resolution here
    elif echo "$error_output" | grep -q "network\|download"; then
        log_info "Network error detected, retrying..."
        sleep 5
    fi
}

handle_service_error() {
    local service="$1"
    local operation="$2"
    local error_output="$3"
    
    log_error "Service $operation failed: $service" "$error_output"
    
    # Attempt automatic recovery
    if recover_service_failure "$service"; then
        return 0
    fi
    
    return 1
}

handle_config_error() {
    local config_file="$1"
    local error_output="$2"
    
    log_error "Configuration error: $config_file" "$error_output"
    
    # Attempt to restore from backup
    local backup_file="${config_file}.backup-$(date +%Y%m%d)"
    if [[ -f "$backup_file" ]]; then
        log_info "Restoring configuration from backup: $backup_file"
        sudo cp "$backup_file" "$config_file"
        return 0
    fi
    
    return 1
}

# Export functions for use in other scripts
export -f init_error_handler
export -f log_error log_warn log_info log_success log_debug
export -f error_exit
export -f create_rollback_point perform_rollback
export -f recover_package_installation recover_service_failure
export -f recover_gpu_driver recover_xorg_config
export -f handle_package_error handle_service_error handle_config_error
export -f validate_system_state

# Initialize if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_error_handler
fi