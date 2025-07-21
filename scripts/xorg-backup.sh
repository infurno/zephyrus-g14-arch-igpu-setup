#!/bin/bash

# Xorg Configuration Backup and Restore Utility
# For ASUS ROG Zephyrus G14 hybrid GPU setup

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly BACKUP_DIR="/etc/X11/xorg.conf.d.backup"
readonly XORG_DIR="/etc/X11/xorg.conf.d"
readonly XORG_CONF="/etc/X11/xorg.conf"

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

# Utility functions
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    local response
    
    while true; do
        read -p "$message (y/n) [$default]: " response
        response="${response:-$default}"
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                log_warn "Please answer yes or no."
                ;;
        esac
    done
}

# Backup functions
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="xorg_backup_${timestamp}"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log_info "Creating Xorg configuration backup..."
    
    # Create backup directory if it doesn't exist
    if [[ ! -d "$BACKUP_DIR" ]]; then
        sudo mkdir -p "$BACKUP_DIR"
        log_info "Created backup directory: $BACKUP_DIR"
    fi
    
    # Create backup subdirectory
    sudo mkdir -p "$backup_path"
    
    # Backup xorg.conf.d directory
    if [[ -d "$XORG_DIR" ]]; then
        sudo cp -r "$XORG_DIR" "${backup_path}/xorg.conf.d"
        log_success "Backed up xorg.conf.d directory"
    else
        log_warn "xorg.conf.d directory not found"
    fi
    
    # Backup xorg.conf file
    if [[ -f "$XORG_CONF" ]]; then
        sudo cp "$XORG_CONF" "${backup_path}/xorg.conf"
        log_success "Backed up xorg.conf file"
    else
        log_info "xorg.conf file not found (this is normal)"
    fi
    
    # Create backup metadata
    cat << EOF | sudo tee "${backup_path}/backup_info.txt" > /dev/null
Backup created: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
GPU info:
$(lspci | grep -E "(VGA|3D)" | sed 's/^/  /')
EOF
    
    log_success "Backup created: $backup_name"
    log_info "Backup location: $backup_path"
    
    return 0
}

list_backups() {
    log_info "Available Xorg configuration backups:"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_warn "No backup directory found"
        return 1
    fi
    
    local backups=($(ls -1 "$BACKUP_DIR" | grep "xorg_backup_" | sort -r))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        log_warn "No backups found"
        return 1
    fi
    
    echo
    for i in "${!backups[@]}"; do
        local backup_path="${BACKUP_DIR}/${backups[i]}"
        local backup_date=""
        
        if [[ -f "${backup_path}/backup_info.txt" ]]; then
            backup_date=$(grep "Backup created:" "${backup_path}/backup_info.txt" | cut -d: -f2- | xargs)
        fi
        
        echo "  $((i+1)). ${backups[i]}"
        if [[ -n "$backup_date" ]]; then
            echo "     Created: $backup_date"
        fi
        
        # Show what's included in the backup
        local contents=()
        if [[ -d "${backup_path}/xorg.conf.d" ]]; then
            contents+=("xorg.conf.d")
        fi
        if [[ -f "${backup_path}/xorg.conf" ]]; then
            contents+=("xorg.conf")
        fi
        
        if [[ ${#contents[@]} -gt 0 ]]; then
            echo "     Contains: ${contents[*]}"
        fi
        echo
    done
    
    return 0
}

restore_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup not found: $backup_name"
        return 1
    fi
    
    log_info "Restoring backup: $backup_name"
    
    # Show backup information
    if [[ -f "${backup_path}/backup_info.txt" ]]; then
        log_info "Backup information:"
        cat "${backup_path}/backup_info.txt" | while read -r line; do
            log_info "  $line"
        done
        echo
    fi
    
    if ! confirm_action "Proceed with restore?"; then
        log_info "Restore cancelled"
        return 0
    fi
    
    # Create a backup of current configuration before restoring
    log_info "Creating backup of current configuration before restore..."
    create_backup
    
    # Remove current configuration
    if [[ -d "$XORG_DIR" ]]; then
        sudo rm -rf "$XORG_DIR"
        log_info "Removed current xorg.conf.d directory"
    fi
    
    if [[ -f "$XORG_CONF" ]]; then
        sudo rm -f "$XORG_CONF"
        log_info "Removed current xorg.conf file"
    fi
    
    # Restore from backup
    if [[ -d "${backup_path}/xorg.conf.d" ]]; then
        sudo cp -r "${backup_path}/xorg.conf.d" "$XORG_DIR"
        log_success "Restored xorg.conf.d directory"
    fi
    
    if [[ -f "${backup_path}/xorg.conf" ]]; then
        sudo cp "${backup_path}/xorg.conf" "$XORG_CONF"
        log_success "Restored xorg.conf file"
    fi
    
    log_success "Backup restored successfully"
    log_info "You may need to restart your display manager or reboot for changes to take effect"
    
    return 0
}

interactive_restore() {
    if ! list_backups; then
        return 1
    fi
    
    local backups=($(ls -1 "$BACKUP_DIR" | grep "xorg_backup_" | sort -r))
    
    echo "Select a backup to restore:"
    local choice
    read -p "Enter backup number (1-${#backups[@]}): " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#backups[@]} ]]; then
        log_error "Invalid selection"
        return 1
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    restore_backup "$selected_backup"
}

delete_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup not found: $backup_name"
        return 1
    fi
    
    log_warn "This will permanently delete the backup: $backup_name"
    
    if confirm_action "Are you sure you want to delete this backup?"; then
        sudo rm -rf "$backup_path"
        log_success "Backup deleted: $backup_name"
    else
        log_info "Deletion cancelled"
    fi
}

interactive_delete() {
    if ! list_backups; then
        return 1
    fi
    
    local backups=($(ls -1 "$BACKUP_DIR" | grep "xorg_backup_" | sort -r))
    
    echo "Select a backup to delete:"
    local choice
    read -p "Enter backup number (1-${#backups[@]}): " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#backups[@]} ]]; then
        log_error "Invalid selection"
        return 1
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    delete_backup "$selected_backup"
}

cleanup_old_backups() {
    local keep_count="${1:-5}"
    
    log_info "Cleaning up old backups (keeping $keep_count most recent)..."
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_info "No backup directory found"
        return 0
    fi
    
    local backups=($(ls -1 "$BACKUP_DIR" | grep "xorg_backup_" | sort -r))
    
    if [[ ${#backups[@]} -le $keep_count ]]; then
        log_info "No cleanup needed (${#backups[@]} backups, keeping $keep_count)"
        return 0
    fi
    
    local to_delete=("${backups[@]:$keep_count}")
    
    log_info "Will delete ${#to_delete[@]} old backups:"
    for backup in "${to_delete[@]}"; do
        log_info "  $backup"
    done
    
    if confirm_action "Proceed with cleanup?"; then
        for backup in "${to_delete[@]}"; do
            sudo rm -rf "${BACKUP_DIR}/${backup}"
            log_info "Deleted: $backup"
        done
        log_success "Cleanup completed"
    else
        log_info "Cleanup cancelled"
    fi
}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [COMMAND] [OPTIONS]

Commands:
    backup              Create a new backup of current Xorg configuration
    list                List all available backups
    restore [NAME]      Restore a specific backup (interactive if NAME not provided)
    delete [NAME]       Delete a specific backup (interactive if NAME not provided)
    cleanup [COUNT]     Delete old backups, keeping COUNT most recent (default: 5)

Options:
    -h, --help          Show this help message

Examples:
    $SCRIPT_NAME backup                     # Create backup
    $SCRIPT_NAME list                       # List backups
    $SCRIPT_NAME restore                    # Interactive restore
    $SCRIPT_NAME restore xorg_backup_20240120_143022  # Restore specific backup
    $SCRIPT_NAME cleanup 3                  # Keep only 3 most recent backups

EOF
}

# Main execution
main() {
    local command="${1:-}"
    
    case "$command" in
        backup)
            create_backup
            ;;
        list)
            list_backups
            ;;
        restore)
            if [[ -n "${2:-}" ]]; then
                restore_backup "$2"
            else
                interactive_restore
            fi
            ;;
        delete)
            if [[ -n "${2:-}" ]]; then
                delete_backup "$2"
            else
                interactive_delete
            fi
            ;;
        cleanup)
            cleanup_old_backups "${2:-5}"
            ;;
        -h|--help|help)
            show_help
            ;;
        "")
            log_info "Xorg Configuration Backup and Restore Utility"
            echo
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi