#!/bin/bash

# Rollback System for ASUS ROG Zephyrus G14 Setup
# Provides comprehensive rollback functionality for failed installations

set -euo pipefail

# Source error handler
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"

# Rollback system configuration
readonly ROLLBACK_VERSION="1.0.0"
readonly ROLLBACK_STORAGE="${BACKUP_DIR}/rollbacks"
readonly ROLLBACK_INDEX="${ROLLBACK_STORAGE}/index.json"
readonly MAX_ROLLBACKS=10

# Initialize rollback system
init_rollback_system() {
    log_info "Initializing rollback system (v${ROLLBACK_VERSION})"
    
    sudo mkdir -p "$ROLLBACK_STORAGE"
    sudo chmod 755 "$ROLLBACK_STORAGE"
    
    # Create index file if it doesn't exist
    if [[ ! -f "$ROLLBACK_INDEX" ]]; then
        echo "[]" | sudo tee "$ROLLBACK_INDEX" >/dev/null
        sudo chmod 644 "$ROLLBACK_INDEX"
    fi
    
    log_success "Rollback system initialized"
}

# Create comprehensive rollback point
create_comprehensive_rollback() {
    local rollback_name="$1"
    local description="${2:-Comprehensive system rollback point}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local rollback_id="${rollback_name}_${timestamp}"
    local rollback_path="${ROLLBACK_STORAGE}/${rollback_id}"
    
    log_info "Creating comprehensive rollback point: $rollback_name"
    
    # Create rollback directory structure
    sudo mkdir -p "$rollback_path"/{configs,packages,services,logs}
    
    # Backup system configurations
    backup_configurations "$rollback_path/configs"
    
    # Backup package information
    backup_packages "$rollback_path/packages"
    
    # Backup service states
    backup_services "$rollback_path/services"
    
    # Backup relevant logs
    backup_logs "$rollback_path/logs"
    
    # Create rollback metadata
    create_rollback_metadata "$rollback_path" "$rollback_name" "$description" "$timestamp"
    
    # Update rollback index
    update_rollback_index "$rollback_id" "$rollback_name" "$description" "$timestamp"
    
    # Cleanup old rollbacks
    cleanup_old_rollbacks
    
    log_success "Comprehensive rollback point created: $rollback_id"
    return 0
}

# Backup system configurations
backup_configurations() {
    local backup_dir="$1"
    
    log_debug "Backing up system configurations"
    
    # System configuration directories
    local config_dirs=(
        "/etc/X11"
        "/etc/systemd/system"
        "/etc/udev/rules.d"
        "/etc/modules-load.d"
        "/etc/modprobe.d"
        "/etc/default"
        "/boot/loader"
    )
    
    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local target_dir="${backup_dir}$(dirname "$dir")"
            sudo mkdir -p "$target_dir"
            sudo cp -r "$dir" "$target_dir/" 2>/dev/null || {
                log_warn "Failed to backup directory: $dir"
            }
        fi
    done
    
    # Individual configuration files
    local config_files=(
        "/etc/pacman.conf"
        "/etc/mkinitcpio.conf"
        "/etc/tlp.conf"
        "/etc/auto-cpufreq.conf"
        "/etc/fstab"
        "/etc/hosts"
        "/etc/hostname"
        "/etc/locale.conf"
        "/etc/vconsole.conf"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            local target_dir="${backup_dir}$(dirname "$file")"
            sudo mkdir -p "$target_dir"
            sudo cp "$file" "$target_dir/" 2>/dev/null || {
                log_warn "Failed to backup file: $file"
            }
        fi
    done
    
    # Backup GRUB configuration
    if [[ -d "/boot/grub" ]]; then
        sudo mkdir -p "${backup_dir}/boot"
        sudo cp -r "/boot/grub" "${backup_dir}/boot/" 2>/dev/null || {
            log_warn "Failed to backup GRUB configuration"
        }
    fi
    
    log_debug "Configuration backup completed"
}

# Backup package information
backup_packages() {
    local backup_dir="$1"
    
    log_debug "Backing up package information"
    
    # Installed packages list
    pacman -Q > "${backup_dir}/installed_packages.txt" 2>/dev/null || {
        log_warn "Failed to backup installed packages list"
    }
    
    # Explicitly installed packages
    pacman -Qe > "${backup_dir}/explicit_packages.txt" 2>/dev/null || {
        log_warn "Failed to backup explicit packages list"
    }
    
    # Foreign packages (AUR)
    pacman -Qm > "${backup_dir}/foreign_packages.txt" 2>/dev/null || {
        log_warn "Failed to backup foreign packages list"
    }
    
    # Package database
    if [[ -d "/var/lib/pacman/local" ]]; then
        sudo mkdir -p "${backup_dir}/pacman"
        sudo cp -r "/var/lib/pacman/local" "${backup_dir}/pacman/" 2>/dev/null || {
            log_warn "Failed to backup package database"
        }
    fi
    
    # Pacman cache info
    ls -la /var/cache/pacman/pkg/ > "${backup_dir}/package_cache.txt" 2>/dev/null || true
    
    log_debug "Package information backup completed"
}

# Backup service states
backup_services() {
    local backup_dir="$1"
    
    log_debug "Backing up service states"
    
    # Enabled services
    systemctl list-unit-files --state=enabled > "${backup_dir}/enabled_services.txt" 2>/dev/null || {
        log_warn "Failed to backup enabled services"
    }
    
    # Active services
    systemctl list-units --state=active > "${backup_dir}/active_services.txt" 2>/dev/null || {
        log_warn "Failed to backup active services"
    }
    
    # Failed services
    systemctl list-units --state=failed > "${backup_dir}/failed_services.txt" 2>/dev/null || true
    
    # Service overrides
    if [[ -d "/etc/systemd/system" ]]; then
        find /etc/systemd/system -name "*.service" -o -name "*.timer" -o -name "*.socket" | \
        while read -r service_file; do
            local service_name=$(basename "$service_file")
            local target_dir="${backup_dir}/overrides"
            sudo mkdir -p "$target_dir"
            sudo cp "$service_file" "$target_dir/" 2>/dev/null || true
        done
    fi
    
    # Systemd journal state
    journalctl --disk-usage > "${backup_dir}/journal_usage.txt" 2>/dev/null || true
    
    log_debug "Service states backup completed"
}

# Backup relevant logs
backup_logs() {
    local backup_dir="$1"
    
    log_debug "Backing up relevant logs"
    
    # System logs
    local log_files=(
        "/var/log/pacman.log"
        "/var/log/Xorg.0.log"
        "/var/log/boot.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            sudo cp "$log_file" "$backup_dir/" 2>/dev/null || {
                log_warn "Failed to backup log: $log_file"
            }
        fi
    done
    
    # Recent journal entries
    journalctl --since "24 hours ago" > "${backup_dir}/recent_journal.log" 2>/dev/null || {
        log_warn "Failed to backup recent journal entries"
    }
    
    # GPU-related logs
    journalctl --since "24 hours ago" | grep -E "(nvidia|amdgpu|gpu)" > "${backup_dir}/gpu_logs.log" 2>/dev/null || true
    
    # Power management logs
    journalctl --since "24 hours ago" | grep -E "(tlp|auto-cpufreq|power)" > "${backup_dir}/power_logs.log" 2>/dev/null || true
    
    log_debug "Log backup completed"
}

# Create rollback metadata
create_rollback_metadata() {
    local rollback_path="$1"
    local name="$2"
    local description="$3"
    local timestamp="$4"
    
    local metadata_file="${rollback_path}/metadata.json"
    
    # Gather system information
    local kernel_version=$(uname -r)
    local hostname=$(hostname)
    local user=$(whoami)
    local package_count=$(pacman -Q | wc -l)
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}')
    
    # Create metadata JSON
    cat << EOF | sudo tee "$metadata_file" >/dev/null
{
    "rollback_info": {
        "name": "$name",
        "description": "$description",
        "timestamp": "$timestamp",
        "created_by": "$user",
        "rollback_version": "$ROLLBACK_VERSION"
    },
    "system_info": {
        "kernel": "$kernel_version",
        "hostname": "$hostname",
        "package_count": $package_count,
        "disk_usage": "$disk_usage",
        "architecture": "$(uname -m)",
        "uptime": "$(uptime -p)"
    },
    "hardware_info": {
        "cpu": "$(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)",
        "gpu": $(lspci | grep -E "(VGA|3D)" | jq -R . | jq -s .),
        "memory": "$(free -h | grep Mem | awk '{print $2}')"
    },
    "backup_contents": {
        "configurations": true,
        "packages": true,
        "services": true,
        "logs": true
    }
}
EOF
    
    sudo chmod 644 "$metadata_file"
}

# Update rollback index
update_rollback_index() {
    local rollback_id="$1"
    local name="$2"
    local description="$3"
    local timestamp="$4"
    
    # Create new entry
    local new_entry=$(cat << EOF
{
    "id": "$rollback_id",
    "name": "$name",
    "description": "$description",
    "timestamp": "$timestamp",
    "path": "${ROLLBACK_STORAGE}/${rollback_id}",
    "created": "$(date -Iseconds)"
}
EOF
)
    
    # Update index file
    local temp_index="/tmp/rollback_index_temp.json"
    
    if jq ". += [$new_entry]" "$ROLLBACK_INDEX" > "$temp_index" 2>/dev/null; then
        sudo mv "$temp_index" "$ROLLBACK_INDEX"
        sudo chmod 644 "$ROLLBACK_INDEX"
    else
        log_warn "Failed to update rollback index, using fallback method"
        # Fallback: recreate index
        echo "[$new_entry]" | sudo tee "$ROLLBACK_INDEX" >/dev/null
    fi
}

# List available rollbacks
list_rollbacks() {
    log_info "Available rollback points:"
    
    if [[ ! -f "$ROLLBACK_INDEX" ]]; then
        log_warn "No rollback index found"
        return 1
    fi
    
    local rollback_count=$(jq length "$ROLLBACK_INDEX" 2>/dev/null || echo "0")
    
    if [[ "$rollback_count" -eq 0 ]]; then
        log_info "No rollback points available"
        return 0
    fi
    
    echo -e "\n${CYAN}Available Rollback Points:${NC}"
    echo "=========================="
    
    jq -r '.[] | "\(.name) (\(.timestamp))\n  Description: \(.description)\n  Path: \(.path)\n"' "$ROLLBACK_INDEX" 2>/dev/null || {
        log_error "Failed to parse rollback index"
        return 1
    }
    
    return 0
}

# Perform rollback
perform_comprehensive_rollback() {
    local rollback_id="$1"
    local rollback_path="${ROLLBACK_STORAGE}/${rollback_id}"
    
    if [[ ! -d "$rollback_path" ]]; then
        log_error "Rollback point not found: $rollback_id"
        return 1
    fi
    
    log_info "Starting comprehensive rollback: $rollback_id"
    
    # Verify rollback integrity
    if ! verify_rollback_integrity "$rollback_path"; then
        log_error "Rollback integrity check failed"
        return 1
    fi
    
    # Create emergency backup before rollback
    create_emergency_backup
    
    # Perform rollback steps
    log_info "Restoring system configurations..."
    restore_configurations "$rollback_path/configs" || {
        log_error "Failed to restore configurations"
        return 1
    }
    
    log_info "Restoring service states..."
    restore_services "$rollback_path/services" || {
        log_warn "Some services may not have been restored properly"
    }
    
    log_info "Updating system state..."
    update_system_after_rollback || {
        log_warn "System update after rollback had issues"
    }
    
    # Log rollback completion
    echo "$(date -Iseconds): Rollback completed - $rollback_id" | sudo tee -a "$RECOVERY_LOG_FILE" >/dev/null
    
    log_success "Comprehensive rollback completed successfully"
    log_info "System may require a reboot for all changes to take effect"
    
    return 0
}

# Verify rollback integrity
verify_rollback_integrity() {
    local rollback_path="$1"
    
    log_debug "Verifying rollback integrity"
    
    # Check required directories
    local required_dirs=("configs" "packages" "services" "logs")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${rollback_path}/${dir}" ]]; then
            log_error "Missing rollback directory: $dir"
            return 1
        fi
    done
    
    # Check metadata file
    if [[ ! -f "${rollback_path}/metadata.json" ]]; then
        log_error "Missing rollback metadata"
        return 1
    fi
    
    # Validate metadata JSON
    if ! jq . "${rollback_path}/metadata.json" >/dev/null 2>&1; then
        log_error "Invalid rollback metadata format"
        return 1
    fi
    
    log_debug "Rollback integrity verified"
    return 0
}

# Create emergency backup before rollback
create_emergency_backup() {
    local emergency_backup="${ROLLBACK_STORAGE}/emergency_$(date +%Y%m%d_%H%M%S)"
    
    log_info "Creating emergency backup before rollback..."
    
    sudo mkdir -p "$emergency_backup"
    
    # Backup critical current state
    backup_configurations "$emergency_backup/configs" 2>/dev/null || true
    backup_services "$emergency_backup/services" 2>/dev/null || true
    
    # Create simple metadata
    cat << EOF | sudo tee "$emergency_backup/metadata.json" >/dev/null
{
    "type": "emergency_backup",
    "created": "$(date -Iseconds)",
    "reason": "Pre-rollback emergency backup"
}
EOF
    
    log_success "Emergency backup created: $emergency_backup"
}

# Restore configurations from rollback
restore_configurations() {
    local configs_backup="$1"
    
    if [[ ! -d "$configs_backup" ]]; then
        log_error "Configuration backup directory not found"
        return 1
    fi
    
    # Restore system directories
    local restore_dirs=(
        "/etc/X11"
        "/etc/systemd/system"
        "/etc/udev/rules.d"
        "/etc/modules-load.d"
        "/etc/modprobe.d"
        "/etc/default"
    )
    
    for dir in "${restore_dirs[@]}"; do
        local backup_dir="${configs_backup}${dir}"
        if [[ -d "$backup_dir" ]]; then
            sudo rm -rf "$dir" 2>/dev/null || true
            sudo mkdir -p "$(dirname "$dir")"
            sudo cp -r "$backup_dir" "$dir" || {
                log_error "Failed to restore directory: $dir"
                return 1
            }
            log_debug "Restored directory: $dir"
        fi
    done
    
    # Restore individual files
    local restore_files=(
        "/etc/pacman.conf"
        "/etc/mkinitcpio.conf"
        "/etc/tlp.conf"
        "/etc/auto-cpufreq.conf"
        "/etc/fstab"
    )
    
    for file in "${restore_files[@]}"; do
        local backup_file="${configs_backup}${file}"
        if [[ -f "$backup_file" ]]; then
            sudo cp "$backup_file" "$file" || {
                log_error "Failed to restore file: $file"
                return 1
            }
            log_debug "Restored file: $file"
        fi
    done
    
    return 0
}

# Update system after rollback
update_system_after_rollback() {
    log_info "Updating system state after rollback..."
    
    # Reload systemd
    sudo systemctl daemon-reload || {
        log_warn "Failed to reload systemd"
    }
    
    # Update initramfs
    if [[ -f "/etc/mkinitcpio.conf" ]]; then
        sudo mkinitcpio -P || {
            log_warn "Failed to update initramfs"
        }
    fi
    
    # Update GRUB if configuration changed
    if [[ -f "/etc/default/grub" ]]; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg || {
            log_warn "Failed to update GRUB configuration"
        }
    fi
    
    # Reload udev rules
    sudo udevadm control --reload-rules || {
        log_warn "Failed to reload udev rules"
    }
    
    return 0
}

# Cleanup old rollbacks
cleanup_old_rollbacks() {
    local rollback_count=$(jq length "$ROLLBACK_INDEX" 2>/dev/null || echo "0")
    
    if [[ "$rollback_count" -le "$MAX_ROLLBACKS" ]]; then
        return 0
    fi
    
    log_info "Cleaning up old rollback points (keeping $MAX_ROLLBACKS most recent)"
    
    # Get oldest rollbacks to remove
    local rollbacks_to_remove=$(jq -r "sort_by(.created) | .[0:$(($rollback_count - $MAX_ROLLBACKS))] | .[].id" "$ROLLBACK_INDEX" 2>/dev/null)
    
    while IFS= read -r rollback_id; do
        if [[ -n "$rollback_id" ]]; then
            local rollback_path="${ROLLBACK_STORAGE}/${rollback_id}"
            if [[ -d "$rollback_path" ]]; then
                sudo rm -rf "$rollback_path"
                log_debug "Removed old rollback: $rollback_id"
            fi
        fi
    done <<< "$rollbacks_to_remove"
    
    # Update index to remove deleted rollbacks
    local temp_index="/tmp/rollback_index_cleanup.json"
    jq "sort_by(.created) | .[-${MAX_ROLLBACKS}:]" "$ROLLBACK_INDEX" > "$temp_index" 2>/dev/null && {
        sudo mv "$temp_index" "$ROLLBACK_INDEX"
        sudo chmod 644 "$ROLLBACK_INDEX"
    }
}

# Interactive rollback selection
interactive_rollback() {
    if ! list_rollbacks; then
        return 1
    fi
    
    local rollback_count=$(jq length "$ROLLBACK_INDEX" 2>/dev/null || echo "0")
    
    if [[ "$rollback_count" -eq 0 ]]; then
        return 0
    fi
    
    echo -e "\n${YELLOW}Select a rollback point:${NC}"
    
    # Display numbered list
    jq -r 'to_entries | .[] | "\(.key + 1). \(.value.name) (\(.value.timestamp))"' "$ROLLBACK_INDEX" 2>/dev/null
    
    read -p "Enter rollback number (1-$rollback_count) or 'q' to quit: " choice
    
    if [[ "$choice" == "q" ]]; then
        return 0
    fi
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$rollback_count" ]]; then
        log_error "Invalid selection"
        return 1
    fi
    
    local selected_rollback=$(jq -r ".[$((choice - 1))].id" "$ROLLBACK_INDEX" 2>/dev/null)
    
    if [[ -z "$selected_rollback" ]]; then
        log_error "Failed to get rollback information"
        return 1
    fi
    
    echo -e "\n${YELLOW}Selected rollback: $selected_rollback${NC}"
    read -p "Are you sure you want to perform this rollback? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        perform_comprehensive_rollback "$selected_rollback"
    else
        log_info "Rollback cancelled"
    fi
}

# Main function
main() {
    case "${1:-}" in
        "init")
            init_rollback_system
            ;;
        "create")
            local name="${2:-auto}"
            local description="${3:-Automatic rollback point}"
            create_comprehensive_rollback "$name" "$description"
            ;;
        "list")
            list_rollbacks
            ;;
        "rollback")
            if [[ -n "${2:-}" ]]; then
                perform_comprehensive_rollback "$2"
            else
                interactive_rollback
            fi
            ;;
        "cleanup")
            cleanup_old_rollbacks
            ;;
        "help"|"--help"|"-h")
            cat << EOF
Usage: $0 <command> [options]

Commands:
    init                    Initialize rollback system
    create <name> [desc]    Create new rollback point
    list                    List available rollback points
    rollback [id]           Perform rollback (interactive if no ID)
    cleanup                 Clean up old rollback points
    help                    Show this help message

Examples:
    $0 init
    $0 create "pre-gpu-setup" "Before GPU driver installation"
    $0 list
    $0 rollback
    $0 rollback pre-gpu-setup_20240120_143022

EOF
            ;;
        *)
            log_error "Unknown command: ${1:-}. Use 'help' for usage information."
            exit 1
            ;;
    esac
}

# Initialize rollback system if not already done
if [[ ! -d "$ROLLBACK_STORAGE" ]]; then
    init_rollback_system
fi

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi