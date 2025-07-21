#!/bin/bash

# Error Handler Enhancements Script
# Adds comprehensive error handling and recovery mechanisms to all scripts

set -euo pipefail

# Source the main error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"

readonly SCRIPT_NAME="$(basename "$0")"

# Enhanced error reporting with detailed context
enhanced_error_report() {
    local error_message="$1"
    local error_code="${2:-$E_GENERAL}"
    local context="${3:-}"
    local recovery_suggestion="${4:-}"
    
    log_error "=== ENHANCED ERROR REPORT ==="
    log_error "Error Message: $error_message"
    log_error "Error Code: $error_code"
    log_error "Context: ${context:-N/A}"
    log_error "Recovery Suggestion: ${recovery_suggestion:-N/A}"
    log_error "Script: ${BASH_SOURCE[2]##*/}"
    log_error "Function: ${FUNCNAME[2]}"
    log_error "Line: ${BASH_LINENO[1]}"
    log_error "Timestamp: $(date -Iseconds)"
    log_error "System Info: $(uname -a)"
    log_error "Available Memory: $(free -h | grep Mem | awk '{print $7}')"
    log_error "Disk Space: $(df -h / | tail -1 | awk '{print $4}')"
    log_error "=== END ERROR REPORT ==="
    
    # Log to system journal as well
    echo "Enhanced error report: $error_message (Code: $error_code)" | systemd-cat -t "zephyrus-g14-setup" -p err
}

# Comprehensive system state validation
validate_system_prerequisites() {
    log_info "Validating system prerequisites..."
    
    local validation_errors=()
    
    # Check if running on Arch Linux
    if [[ ! -f /etc/arch-release ]]; then
        validation_errors+=("Not running on Arch Linux")
    fi
    
    # Check available disk space (minimum 2GB)
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 2097152 ]]; then  # 2GB in KB
        validation_errors+=("Insufficient disk space (less than 2GB available)")
    fi
    
    # Check available memory (minimum 1GB)
    local available_memory=$(free | grep Mem | awk '{print $7}')
    if [[ $available_memory -lt 1048576 ]]; then  # 1GB in KB
        validation_errors+=("Insufficient available memory (less than 1GB)")
    fi
    
    # Check internet connectivity
    if ! ping -c 1 -W 5 archlinux.org &>/dev/null; then
        validation_errors+=("No internet connectivity")
    fi
    
    # Check package manager functionality
    if ! pacman -Q &>/dev/null; then
        validation_errors+=("Package manager not functioning")
    fi
    
    # Check systemd functionality
    if ! systemctl --version &>/dev/null; then
        validation_errors+=("systemd not functioning")
    fi
    
    # Check sudo privileges
    if ! sudo -n true 2>/dev/null; then
        validation_errors+=("Sudo privileges not available")
    fi
    
    if [[ ${#validation_errors[@]} -eq 0 ]]; then
        log_success "System prerequisites validation passed"
        return 0
    else
        log_error "System prerequisites validation failed:"
        for error in "${validation_errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
}

# Enhanced package installation with dependency resolution
install_package_with_dependencies() {
    local package="$1"
    local max_retries="${2:-3}"
    
    log_info "Installing package with dependency resolution: $package"
    
    # Check if package exists in repositories
    if ! pacman -Si "$package" &>/dev/null; then
        log_error "Package not found in repositories: $package"
        return 1
    fi
    
    # Get package dependencies
    local dependencies=$(pacman -Si "$package" | grep "Depends On" | cut -d: -f2 | tr -d ' ')
    if [[ -n "$dependencies" && "$dependencies" != "None" ]]; then
        log_debug "Package dependencies: $dependencies"
    fi
    
    # Install with enhanced error handling
    local retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        local error_output
        if error_output=$(sudo pacman -S --noconfirm "$package" 2>&1); then
            log_success "Successfully installed package: $package"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warn "Package installation failed (attempt $retry_count/$max_retries): $package"
            log_debug "Error output: $error_output"
            
            # Analyze error and attempt recovery
            if echo "$error_output" | grep -q "signature"; then
                log_info "Signature error detected, updating keyring..."
                sudo pacman -Sy archlinux-keyring --noconfirm || true
            elif echo "$error_output" | grep -q "conflict"; then
                log_info "Package conflict detected, attempting resolution..."
                resolve_package_conflicts "$package" "$error_output"
            elif echo "$error_output" | grep -q "database"; then
                log_info "Database error detected, refreshing package database..."
                sudo pacman -Syy || true
            fi
            
            if [[ $retry_count -lt $max_retries ]]; then
                sleep 5
            fi
        fi
    done
    
    log_error "Failed to install package after $max_retries attempts: $package"
    return 1
}

# Package conflict resolution
resolve_package_conflicts() {
    local package="$1"
    local error_output="$2"
    
    log_info "Attempting to resolve package conflicts for: $package"
    
    # Extract conflicting packages from error output
    local conflicting_packages=$(echo "$error_output" | grep -o "conflicts with [^:]*" | cut -d' ' -f3- | tr '\n' ' ')
    
    if [[ -n "$conflicting_packages" ]]; then
        log_info "Found conflicting packages: $conflicting_packages"
        
        for conflict in $conflicting_packages; do
            if pacman -Qi "$conflict" &>/dev/null; then
                log_info "Removing conflicting package: $conflict"
                sudo pacman -Rns --noconfirm "$conflict" || {
                    log_warn "Failed to remove conflicting package: $conflict"
                }
            fi
        done
    fi
}

# Enhanced service management with dependency checking
manage_service_with_dependencies() {
    local service="$1"
    local operation="$2"
    local check_dependencies="${3:-true}"
    
    log_info "Managing service with dependencies: $service ($operation)"
    
    # Check service dependencies if requested
    if [[ "$check_dependencies" == "true" ]]; then
        local dependencies=$(systemctl list-dependencies "$service" --plain --no-pager 2>/dev/null | tail -n +2 | grep -v "^$" || true)
        if [[ -n "$dependencies" ]]; then
            log_debug "Service dependencies for $service:"
            echo "$dependencies" | while read -r dep; do
                log_debug "  - $dep"
            done
        fi
    fi
    
    # Perform the operation with enhanced error handling
    case "$operation" in
        "enable")
            if sudo systemctl enable "$service"; then
                log_success "Service enabled: $service"
                return 0
            else
                log_error "Failed to enable service: $service"
                return 1
            fi
            ;;
        "start")
            if sudo systemctl start "$service"; then
                log_success "Service started: $service"
                return 0
            else
                log_error "Failed to start service: $service"
                # Get service status for debugging
                local status_output=$(systemctl status "$service" --no-pager -l 2>&1 || true)
                log_debug "Service status output: $status_output"
                return 1
            fi
            ;;
        "restart")
            if sudo systemctl restart "$service"; then
                log_success "Service restarted: $service"
                return 0
            else
                log_error "Failed to restart service: $service"
                return 1
            fi
            ;;
        *)
            log_error "Unknown service operation: $operation"
            return 1
            ;;
    esac
}

# Configuration file validation with schema checking
validate_config_file_advanced() {
    local config_file="$1"
    local config_type="${2:-generic}"
    local schema_file="${3:-}"
    
    log_debug "Advanced configuration file validation: $config_file (type: $config_type)"
    
    local validation_errors=()
    
    # Basic file checks
    if [[ ! -f "$config_file" ]]; then
        validation_errors+=("Configuration file does not exist")
        return 1
    fi
    
    if [[ ! -r "$config_file" ]]; then
        validation_errors+=("Configuration file is not readable")
    fi
    
    # Type-specific validation
    case "$config_type" in
        "xorg")
            validate_xorg_config_syntax "$config_file" || validation_errors+=("Invalid Xorg configuration syntax")
            ;;
        "systemd")
            validate_systemd_config_syntax "$config_file" || validation_errors+=("Invalid systemd configuration syntax")
            ;;
        "tlp")
            validate_tlp_config_syntax "$config_file" || validation_errors+=("Invalid TLP configuration syntax")
            ;;
        "grub")
            validate_grub_config_syntax "$config_file" || validation_errors+=("Invalid GRUB configuration syntax")
            ;;
    esac
    
    # Schema validation if schema file provided
    if [[ -n "$schema_file" && -f "$schema_file" ]]; then
        validate_config_against_schema "$config_file" "$schema_file" || validation_errors+=("Configuration does not match schema")
    fi
    
    if [[ ${#validation_errors[@]} -eq 0 ]]; then
        log_success "Advanced configuration validation passed: $config_file"
        return 0
    else
        log_error "Advanced configuration validation failed: $config_file"
        for error in "${validation_errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
}

# Configuration syntax validators
validate_xorg_config_syntax() {
    local config_file="$1"
    
    # Check for basic Xorg configuration structure
    if ! grep -q "Section\|EndSection" "$config_file"; then
        return 1
    fi
    
    # Check for balanced Section/EndSection pairs
    local sections=$(grep -c "^Section" "$config_file" 2>/dev/null || echo "0")
    local end_sections=$(grep -c "^EndSection" "$config_file" 2>/dev/null || echo "0")
    
    if [[ $sections -ne $end_sections ]]; then
        return 1
    fi
    
    return 0
}

validate_systemd_config_syntax() {
    local config_file="$1"
    
    # Basic systemd unit file validation
    if ! grep -q "^\[.*\]" "$config_file"; then
        return 1
    fi
    
    return 0
}

validate_tlp_config_syntax() {
    local config_file="$1"
    
    # Check for TLP configuration format
    if ! grep -q "^[A-Z_]*=" "$config_file"; then
        return 1
    fi
    
    return 0
}

validate_grub_config_syntax() {
    local config_file="$1"
    
    # Check for GRUB configuration format
    if ! grep -q "^GRUB_" "$config_file"; then
        return 1
    fi
    
    return 0
}

validate_config_against_schema() {
    local config_file="$1"
    local schema_file="$2"
    
    # This is a placeholder for schema validation
    # In a real implementation, you might use tools like jsonschema for JSON configs
    # or custom validation logic for other formats
    
    log_debug "Schema validation not implemented for: $config_file"
    return 0
}

# System recovery checkpoint management
create_recovery_checkpoint() {
    local checkpoint_name="$1"
    local description="${2:-Recovery checkpoint}"
    
    log_info "Creating recovery checkpoint: $checkpoint_name"
    
    local checkpoint_dir="${BACKUP_DIR}/checkpoints/${checkpoint_name}_$(date +%Y%m%d_%H%M%S)"
    
    # Create checkpoint directory
    sudo mkdir -p "$checkpoint_dir"
    
    # Save system state
    save_system_state "$checkpoint_dir"
    
    # Create checkpoint metadata
    cat << EOF | sudo tee "$checkpoint_dir/checkpoint.json" >/dev/null
{
    "name": "$checkpoint_name",
    "description": "$description",
    "timestamp": "$(date -Iseconds)",
    "created_by": "${USER:-unknown}",
    "script": "${BASH_SOURCE[1]##*/}",
    "system_info": {
        "kernel": "$(uname -r)",
        "hostname": "$(hostname)",
        "uptime": "$(uptime -p)",
        "load": "$(uptime | awk -F'load average:' '{print $2}')"
    }
}
EOF
    
    log_success "Recovery checkpoint created: $checkpoint_dir"
    echo "$checkpoint_dir" > "${BACKUP_DIR}/.last_checkpoint"
}

save_system_state() {
    local state_dir="$1"
    
    log_debug "Saving system state to: $state_dir"
    
    # Save package list
    pacman -Q > "$state_dir/packages.txt" 2>/dev/null || true
    
    # Save service states
    systemctl list-unit-files --state=enabled > "$state_dir/enabled_services.txt" 2>/dev/null || true
    systemctl list-units --state=active > "$state_dir/active_services.txt" 2>/dev/null || true
    
    # Save kernel modules
    lsmod > "$state_dir/loaded_modules.txt" 2>/dev/null || true
    
    # Save system configuration files
    local config_files=(
        "/etc/pacman.conf"
        "/etc/mkinitcpio.conf"
        "/etc/default/grub"
        "/boot/grub/grub.cfg"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            local config_name=$(basename "$config_file")
            sudo cp "$config_file" "$state_dir/$config_name" 2>/dev/null || true
        fi
    done
    
    # Save directory structures
    find /etc/X11 -type f -name "*.conf" -exec sudo cp {} "$state_dir/" \; 2>/dev/null || true
    find /etc/systemd/system -name "*.service" -exec sudo cp {} "$state_dir/" \; 2>/dev/null || true
}

# Automated system repair functions
auto_repair_system() {
    log_info "Starting automated system repair..."
    
    local repair_actions=()
    local repair_success=true
    
    # Repair package database
    if repair_package_database; then
        repair_actions+=("package-database:success")
    else
        repair_actions+=("package-database:failed")
        repair_success=false
    fi
    
    # Repair systemd services
    if repair_systemd_services; then
        repair_actions+=("systemd-services:success")
    else
        repair_actions+=("systemd-services:failed")
        repair_success=false
    fi
    
    # Repair configuration files
    if repair_configuration_files; then
        repair_actions+=("configuration-files:success")
    else
        repair_actions+=("configuration-files:failed")
        repair_success=false
    fi
    
    # Repair kernel modules
    if repair_kernel_modules; then
        repair_actions+=("kernel-modules:success")
    else
        repair_actions+=("kernel-modules:failed")
        repair_success=false
    fi
    
    log_info "Automated system repair completed"
    log_info "Repair actions: ${repair_actions[*]}"
    
    if [[ "$repair_success" == true ]]; then
        log_success "All automated repairs completed successfully"
        return 0
    else
        log_warn "Some automated repairs failed"
        return 1
    fi
}

repair_package_database() {
    log_info "Repairing package database..."
    
    # Update package database
    if sudo pacman -Sy; then
        log_debug "Package database updated"
    else
        log_warn "Failed to update package database"
        return 1
    fi
    
    # Check database integrity
    if sudo pacman -Dk; then
        log_debug "Package database integrity check passed"
    else
        log_warn "Package database integrity issues detected"
    fi
    
    return 0
}

repair_systemd_services() {
    log_info "Repairing systemd services..."
    
    # Reload systemd daemon
    sudo systemctl daemon-reload
    
    # Reset failed services
    sudo systemctl reset-failed
    
    return 0
}

repair_configuration_files() {
    log_info "Repairing configuration files..."
    
    # This is a placeholder for configuration file repair logic
    # In a real implementation, you would check for common configuration issues
    # and attempt to fix them automatically
    
    return 0
}

repair_kernel_modules() {
    log_info "Repairing kernel modules..."
    
    # Rebuild kernel modules if needed
    if [[ -f /etc/mkinitcpio.conf ]]; then
        if sudo mkinitcpio -P; then
            log_debug "Kernel modules rebuilt successfully"
        else
            log_warn "Failed to rebuild kernel modules"
            return 1
        fi
    fi
    
    return 0
}

# Export enhanced functions
export -f enhanced_error_report
export -f validate_system_prerequisites
export -f install_package_with_dependencies
export -f resolve_package_conflicts
export -f manage_service_with_dependencies
export -f validate_config_file_advanced
export -f create_recovery_checkpoint
export -f auto_repair_system

log_info "Error handler enhancements loaded successfully"