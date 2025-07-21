#!/bin/bash

# Configuration Backup and Restore System for ASUS ROG Zephyrus G14
# Handles backup, restore, versioning, and migration of system configurations

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly BACKUP_DIR="${PROJECT_DIR}/backups"
readonly CONFIG_VERSION_FILE="${PROJECT_DIR}/.config-version"
readonly CURRENT_CONFIG_VERSION="1.0"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
VERBOSE=false
DRY_RUN=false
FORCE=false

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

log_debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "[DEBUG] $*"
    fi
}

# Error handling
error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# Configuration file mappings
# Format: "source_path:target_path:description"
declare -ra CONFIG_MAPPINGS=(
    # Xorg configuration
    "/etc/X11/xorg.conf.d/10-hybrid.conf:${PROJECT_DIR}/configs/xorg/10-hybrid.conf:Xorg hybrid GPU configuration"
    "/etc/X11/xorg.conf:/etc/X11/xorg.conf:Xorg main configuration"
    
    # Power management
    "/etc/tlp.conf:${PROJECT_DIR}/configs/tlp/tlp.conf:TLP power management configuration"
    "/etc/auto-cpufreq.conf:${PROJECT_DIR}/configs/auto-cpufreq/auto-cpufreq.conf:auto-cpufreq configuration"
    
    # Kernel modules
    "/etc/modules-load.d/bbswitch.conf:${PROJECT_DIR}/configs/modules/bbswitch.conf:bbswitch module configuration"
    "/etc/modules-load.d/nvidia.conf:${PROJECT_DIR}/configs/modules/nvidia.conf:NVIDIA module configuration"
    "/etc/modules-load.d/amdgpu.conf:${PROJECT_DIR}/configs/modules/amdgpu.conf:AMD GPU module configuration"
    "/etc/modules-load.d/acpi_call.conf:${PROJECT_DIR}/configs/modules/acpi_call.conf:ACPI call module configuration"
    
    # Systemd services
    "/etc/systemd/system/nvidia-suspend.service:${PROJECT_DIR}/configs/systemd/nvidia-suspend.service:NVIDIA suspend service"
    "/etc/systemd/system/nvidia-resume.service:${PROJECT_DIR}/configs/systemd/nvidia-resume.service:NVIDIA resume service"
    "/etc/systemd/system/power-management.service:${PROJECT_DIR}/configs/systemd/power-management.service:Power management service"
    "/etc/systemd/system/asus-hardware.service:${PROJECT_DIR}/configs/systemd/asus-hardware.service:ASUS hardware service"
    
    # Udev rules
    "/etc/udev/rules.d/80-nvidia-pm.rules:${PROJECT_DIR}/configs/udev/80-nvidia-pm.rules:NVIDIA power management udev rules"
    "/etc/udev/rules.d/81-nvidia-switching.rules:${PROJECT_DIR}/configs/udev/81-nvidia-switching.rules:NVIDIA switching udev rules"
    "/etc/udev/rules.d/83-asus-hardware.rules:${PROJECT_DIR}/configs/udev/83-asus-hardware.rules:ASUS hardware udev rules"
    
    # ASUS tools configuration
    "/etc/asusd/asusd.conf:${PROJECT_DIR}/configs/asus/asusctl.conf:ASUS daemon configuration"
    "/etc/supergfxd.conf:${PROJECT_DIR}/configs/asus/supergfxctl.conf:SuperGFX daemon configuration"
    
    # GRUB configuration (for kernel parameters)
    "/etc/default/grub:/etc/default/grub:GRUB bootloader configuration"
    
    # Pacman configuration (for ASUS repository)
    "/etc/pacman.conf:/etc/pacman.conf:Pacman package manager configuration"
)

# User data protection patterns
declare -ra PROTECTED_PATTERNS=(
    "*/home/*"
    "*/root/*"
    "*/.ssh/*"
    "*/.gnupg/*"
    "*/passwd"
    "*/shadow"
    "*/group"
    "*/gshadow"
)

# Utility functions
get_timestamp() {
    date '+%Y%m%d_%H%M%S'
}

get_backup_name() {
    local description="$1"
    local timestamp="$2"
    echo "${description// /_}_${timestamp}"
}

is_protected_path() {
    local path="$1"
    
    for pattern in "${PROTECTED_PATTERNS[@]}"; do
        if [[ "$path" == $pattern ]]; then
            return 0
        fi
    done
    
    return 1
}

validate_path() {
    local path="$1"
    
    # Check if path contains user data
    if is_protected_path "$path"; then
        log_error "Path contains protected user data: $path"
        return 1
    fi
    
    # Check if path is within system configuration directories
    case "$path" in
        /etc/*|/usr/lib/systemd/*|/usr/share/*)
            return 0
            ;;
        *)
            log_warn "Path is outside typical system configuration directories: $path"
            return 0
            ;;
    esac
}

# Backup functions
create_backup_metadata() {
    local backup_path="$1"
    local description="$2"
    local metadata_file="${backup_path}/metadata.json"
    
    log_debug "Creating backup metadata: $metadata_file"
    
    cat > "$metadata_file" << EOF
{
    "version": "$CURRENT_CONFIG_VERSION",
    "timestamp": "$(date -Iseconds)",
    "description": "$description",
    "hostname": "$(hostname)",
    "kernel": "$(uname -r)",
    "user": "${SUDO_USER:-$USER}",
    "script_version": "1.0",
    "files": []
}
EOF
}

update_backup_metadata() {
    local metadata_file="$1"
    local source_file="$2"
    local backup_file="$3"
    local checksum="$4"
    
    # Create temporary file with updated metadata
    local temp_file=$(mktemp)
    
    # Add file entry to metadata
    jq --arg source "$source_file" \
       --arg backup "$backup_file" \
       --arg checksum "$checksum" \
       --arg size "$(stat -c%s "$source_file" 2>/dev/null || echo "0")" \
       '.files += [{
           "source": $source,
           "backup": $backup,
           "checksum": $checksum,
           "size": ($size | tonumber),
           "timestamp": now | strftime("%Y-%m-%dT%H:%M:%S%z")
       }]' "$metadata_file" > "$temp_file"
    
    mv "$temp_file" "$metadata_file"
}

backup_single_file() {
    local source_path="$1"
    local backup_dir="$2"
    local description="$3"
    
    log_debug "Backing up: $source_path"
    
    # Validate source path
    if ! validate_path "$source_path"; then
        log_error "Invalid or protected source path: $source_path"
        return 1
    fi
    
    # Check if source file exists
    if [[ ! -f "$source_path" ]]; then
        log_debug "Source file does not exist, skipping: $source_path"
        return 0
    fi
    
    # Create backup directory structure
    local backup_file_dir="${backup_dir}$(dirname "$source_path")"
    mkdir -p "$backup_file_dir"
    
    # Copy file to backup location
    local backup_file="${backup_dir}${source_path}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would backup: $source_path -> $backup_file"
        return 0
    fi
    
    if ! cp "$source_path" "$backup_file"; then
        log_error "Failed to backup file: $source_path"
        return 1
    fi
    
    # Calculate checksum
    local checksum=$(sha256sum "$source_path" | cut -d' ' -f1)
    
    # Update metadata
    local metadata_file="${backup_dir}/metadata.json"
    if [[ -f "$metadata_file" ]]; then
        update_backup_metadata "$metadata_file" "$source_path" "$backup_file" "$checksum"
    fi
    
    log_debug "Successfully backed up: $source_path"
    return 0
}

create_full_backup() {
    local description="${1:-Full system configuration backup}"
    local timestamp=$(get_timestamp)
    local backup_name=$(get_backup_name "$description" "$timestamp")
    local backup_path="${BACKUP_DIR}/$backup_name"
    
    log_info "Creating full configuration backup: $backup_name"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Create metadata file
    create_backup_metadata "$backup_path" "$description"
    
    local backup_count=0
    local failed_count=0
    
    # Backup each configuration file
    for mapping in "${CONFIG_MAPPINGS[@]}"; do
        IFS=':' read -r source_path target_path desc <<< "$mapping"
        
        if backup_single_file "$source_path" "$backup_path" "$desc"; then
            ((backup_count++))
        else
            ((failed_count++))
        fi
    done
    
    # Save current configuration version
    echo "$CURRENT_CONFIG_VERSION" > "${backup_path}/config_version"
    
    # Create backup summary
    cat > "${backup_path}/summary.txt" << EOF
Backup Summary
==============
Backup Name: $backup_name
Description: $description
Timestamp: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
User: ${SUDO_USER:-$USER}

Files backed up: $backup_count
Failed backups: $failed_count
Total configurations: ${#CONFIG_MAPPINGS[@]}

Backup location: $backup_path
EOF
    
    if [[ $failed_count -eq 0 ]]; then
        log_success "Full backup completed successfully: $backup_name"
        log_info "Backup location: $backup_path"
    else
        log_warn "Backup completed with $failed_count failures: $backup_name"
        log_info "Check backup summary for details: ${backup_path}/summary.txt"
    fi
    
    echo "$backup_name"
}

# Restore functions
validate_backup() {
    local backup_path="$1"
    
    log_info "Validating backup: $(basename "$backup_path")"
    
    # Check if backup directory exists
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup directory does not exist: $backup_path"
        return 1
    fi
    
    # Check for required files
    local required_files=(
        "metadata.json"
        "config_version"
        "summary.txt"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "${backup_path}/$file" ]]; then
            log_error "Required backup file missing: $file"
            return 1
        fi
    done
    
    # Validate metadata format
    if ! jq empty "${backup_path}/metadata.json" 2>/dev/null; then
        log_error "Invalid metadata format in backup"
        return 1
    fi
    
    # Check configuration version compatibility
    local backup_version=$(cat "${backup_path}/config_version")
    if [[ "$backup_version" != "$CURRENT_CONFIG_VERSION" ]]; then
        log_warn "Backup version ($backup_version) differs from current version ($CURRENT_CONFIG_VERSION)"
        log_warn "Migration may be required"
    fi
    
    # Validate file checksums
    local validation_errors=0
    
    if command -v jq >/dev/null 2>&1; then
        while IFS= read -r file_info; do
            local source_file=$(echo "$file_info" | jq -r '.source')
            local backup_file=$(echo "$file_info" | jq -r '.backup')
            local expected_checksum=$(echo "$file_info" | jq -r '.checksum')
            
            if [[ -f "$backup_file" ]]; then
                local actual_checksum=$(sha256sum "$backup_file" | cut -d' ' -f1)
                if [[ "$actual_checksum" != "$expected_checksum" ]]; then
                    log_error "Checksum mismatch for: $backup_file"
                    ((validation_errors++))
                fi
            else
                log_error "Backup file missing: $backup_file"
                ((validation_errors++))
            fi
        done < <(jq -c '.files[]' "${backup_path}/metadata.json")
    fi
    
    if [[ $validation_errors -eq 0 ]]; then
        log_success "Backup validation passed"
        return 0
    else
        log_error "Backup validation failed with $validation_errors errors"
        return 1
    fi
}

restore_single_file() {
    local backup_file="$1"
    local target_path="$2"
    local description="$3"
    
    log_debug "Restoring: $backup_file -> $target_path"
    
    # Validate target path
    if ! validate_path "$target_path"; then
        log_error "Invalid or protected target path: $target_path"
        return 1
    fi
    
    # Check if backup file exists
    if [[ ! -f "$backup_file" ]]; then
        log_warn "Backup file does not exist, skipping: $backup_file"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would restore: $backup_file -> $target_path"
        return 0
    fi
    
    # Create target directory if needed
    local target_dir=$(dirname "$target_path")
    if [[ ! -d "$target_dir" ]]; then
        sudo mkdir -p "$target_dir"
    fi
    
    # Backup existing file if it exists
    if [[ -f "$target_path" ]]; then
        local existing_backup="${target_path}.pre-restore-$(get_timestamp)"
        sudo cp "$target_path" "$existing_backup"
        log_debug "Backed up existing file to: $existing_backup"
    fi
    
    # Restore file
    if ! sudo cp "$backup_file" "$target_path"; then
        log_error "Failed to restore file: $backup_file -> $target_path"
        return 1
    fi
    
    # Set appropriate permissions
    case "$target_path" in
        /etc/systemd/system/*)
            sudo chmod 644 "$target_path"
            sudo chown root:root "$target_path"
            ;;
        /etc/udev/rules.d/*)
            sudo chmod 644 "$target_path"
            sudo chown root:root "$target_path"
            ;;
        /etc/X11/*)
            sudo chmod 644 "$target_path"
            sudo chown root:root "$target_path"
            ;;
        *)
            sudo chmod 644 "$target_path"
            sudo chown root:root "$target_path"
            ;;
    esac
    
    log_debug "Successfully restored: $target_path"
    return 0
}

restore_from_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/$backup_name"
    
    log_info "Restoring configuration from backup: $backup_name"
    
    # Validate backup
    if ! validate_backup "$backup_path"; then
        error_exit "Backup validation failed, cannot restore"
    fi
    
    # Check for version compatibility and migrate if needed
    local backup_version=$(cat "${backup_path}/config_version")
    if [[ "$backup_version" != "$CURRENT_CONFIG_VERSION" ]]; then
        log_info "Migrating backup from version $backup_version to $CURRENT_CONFIG_VERSION"
        if ! migrate_backup_version "$backup_path" "$backup_version" "$CURRENT_CONFIG_VERSION"; then
            error_exit "Backup migration failed"
        fi
    fi
    
    local restore_count=0
    local failed_count=0
    
    # Restore files using metadata
    if command -v jq >/dev/null 2>&1; then
        while IFS= read -r file_info; do
            local source_file=$(echo "$file_info" | jq -r '.source')
            local backup_file=$(echo "$file_info" | jq -r '.backup')
            
            if restore_single_file "$backup_file" "$source_file" "Restored from backup"; then
                ((restore_count++))
            else
                ((failed_count++))
            fi
        done < <(jq -c '.files[]' "${backup_path}/metadata.json")
    else
        log_error "jq is required for restore operations"
        return 1
    fi
    
    # Reload systemd and restart services if needed
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Reloading systemd configuration..."
        sudo systemctl daemon-reload
        
        log_info "Reloading udev rules..."
        sudo udevadm control --reload-rules
        sudo udevadm trigger
    fi
    
    if [[ $failed_count -eq 0 ]]; then
        log_success "Configuration restored successfully from backup: $backup_name"
        log_info "Files restored: $restore_count"
        log_info "You may need to reboot for all changes to take effect"
    else
        log_warn "Restore completed with $failed_count failures"
        log_info "Files restored: $restore_count"
        log_info "Failed restores: $failed_count"
    fi
}

# Version migration functions
migrate_backup_version() {
    local backup_path="$1"
    local from_version="$2"
    local to_version="$3"
    
    log_info "Migrating backup from version $from_version to $to_version"
    
    case "$from_version" in
        "1.0")
            # Current version, no migration needed
            return 0
            ;;
        *)
            log_error "Unknown backup version: $from_version"
            return 1
            ;;
    esac
}

# Listing and management functions
list_backups() {
    log_info "Available configuration backups:"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_info "No backups found (backup directory does not exist)"
        return 0
    fi
    
    local backup_count=0
    
    for backup_path in "$BACKUP_DIR"/*; do
        if [[ -d "$backup_path" ]]; then
            local backup_name=$(basename "$backup_path")
            local summary_file="${backup_path}/summary.txt"
            
            echo
            echo "Backup: $backup_name"
            
            if [[ -f "$summary_file" ]]; then
                # Extract key information from summary
                local description=$(grep "Description:" "$summary_file" | cut -d' ' -f2-)
                local timestamp=$(grep "Timestamp:" "$summary_file" | cut -d' ' -f2-)
                local files_backed_up=$(grep "Files backed up:" "$summary_file" | cut -d' ' -f3)
                
                echo "  Description: $description"
                echo "  Created: $timestamp"
                echo "  Files: $files_backed_up"
            else
                echo "  Status: Summary file missing"
            fi
            
            # Check backup validity
            if validate_backup "$backup_path" >/dev/null 2>&1; then
                echo "  Status: Valid"
            else
                echo "  Status: Invalid or corrupted"
            fi
            
            ((backup_count++))
        fi
    done
    
    echo
    log_info "Total backups: $backup_count"
}

delete_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/$backup_name"
    
    if [[ ! -d "$backup_path" ]]; then
        error_exit "Backup not found: $backup_name"
    fi
    
    log_info "Backup details:"
    if [[ -f "${backup_path}/summary.txt" ]]; then
        cat "${backup_path}/summary.txt"
    fi
    
    echo
    if [[ "$FORCE" != true ]]; then
        read -p "Are you sure you want to delete this backup? (y/N): " -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Backup deletion cancelled"
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would delete backup: $backup_path"
        return 0
    fi
    
    if rm -rf "$backup_path"; then
        log_success "Backup deleted: $backup_name"
    else
        error_exit "Failed to delete backup: $backup_name"
    fi
}

# Configuration versioning functions
get_current_config_version() {
    if [[ -f "$CONFIG_VERSION_FILE" ]]; then
        cat "$CONFIG_VERSION_FILE"
    else
        echo "unknown"
    fi
}

set_config_version() {
    local version="$1"
    echo "$version" > "$CONFIG_VERSION_FILE"
    log_info "Configuration version set to: $version"
}

# User data protection functions
validate_user_data_protection() {
    log_info "Validating user data protection..."
    
    local violations=()
    
    # Check if any configuration mappings point to user data
    for mapping in "${CONFIG_MAPPINGS[@]}"; do
        IFS=':' read -r source_path target_path desc <<< "$mapping"
        
        if is_protected_path "$source_path"; then
            violations+=("Source path contains user data: $source_path")
        fi
        
        if is_protected_path "$target_path"; then
            violations+=("Target path contains user data: $target_path")
        fi
    done
    
    if [[ ${#violations[@]} -eq 0 ]]; then
        log_success "User data protection validation passed"
        return 0
    else
        log_error "User data protection violations found:"
        for violation in "${violations[@]}"; do
            log_error "  $violation"
        done
        return 1
    fi
}

# Main command functions
cmd_backup() {
    local description="${1:-Automated configuration backup}"
    
    # Validate user data protection
    if ! validate_user_data_protection; then
        error_exit "User data protection validation failed"
    fi
    
    # Create backup
    local backup_name=$(create_full_backup "$description")
    
    # Update current configuration version
    set_config_version "$CURRENT_CONFIG_VERSION"
    
    log_success "Backup created: $backup_name"
}

cmd_restore() {
    local backup_name="$1"
    
    if [[ -z "$backup_name" ]]; then
        log_info "Available backups:"
        list_backups
        echo
        read -p "Enter backup name to restore: " backup_name
    fi
    
    if [[ -z "$backup_name" ]]; then
        error_exit "No backup name provided"
    fi
    
    # Validate user data protection
    if ! validate_user_data_protection; then
        error_exit "User data protection validation failed"
    fi
    
    # Confirm restore operation
    if [[ "$FORCE" != true ]]; then
        echo
        log_warn "This will overwrite current system configuration files!"
        read -p "Are you sure you want to restore from backup '$backup_name'? (y/N): " -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Restore operation cancelled"
            return 0
        fi
    fi
    
    # Perform restore
    restore_from_backup "$backup_name"
}

cmd_list() {
    list_backups
}

cmd_delete() {
    local backup_name="$1"
    
    if [[ -z "$backup_name" ]]; then
        log_info "Available backups:"
        list_backups
        echo
        read -p "Enter backup name to delete: " backup_name
    fi
    
    if [[ -z "$backup_name" ]]; then
        error_exit "No backup name provided"
    fi
    
    delete_backup "$backup_name"
}

cmd_validate() {
    local backup_name="$1"
    
    if [[ -z "$backup_name" ]]; then
        log_info "Available backups:"
        list_backups
        echo
        read -p "Enter backup name to validate: " backup_name
    fi
    
    if [[ -z "$backup_name" ]]; then
        error_exit "No backup name provided"
    fi
    
    local backup_path="${BACKUP_DIR}/$backup_name"
    
    if validate_backup "$backup_path"; then
        log_success "Backup validation passed: $backup_name"
    else
        error_exit "Backup validation failed: $backup_name"
    fi
}

cmd_version() {
    local current_version=$(get_current_config_version)
    
    echo "Configuration Backup System"
    echo "Current configuration version: $current_version"
    echo "Script version: 1.0"
    echo "Backup directory: $BACKUP_DIR"
    echo "Configuration mappings: ${#CONFIG_MAPPINGS[@]}"
}

# Usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] COMMAND [ARGS...]

Configuration backup and restore system for ASUS ROG Zephyrus G14.

COMMANDS:
    backup [DESCRIPTION]     Create a full configuration backup
    restore [BACKUP_NAME]    Restore configuration from backup
    list                     List available backups
    delete [BACKUP_NAME]     Delete a backup
    validate [BACKUP_NAME]   Validate backup integrity
    version                  Show version information

OPTIONS:
    -v, --verbose           Enable verbose output
    -n, --dry-run          Show what would be done without making changes
    -f, --force            Skip confirmation prompts
    -h, --help             Show this help message

EXAMPLES:
    $SCRIPT_NAME backup "Pre-update backup"
    $SCRIPT_NAME restore
    $SCRIPT_NAME list
    $SCRIPT_NAME validate backup_20240120_143022
    $SCRIPT_NAME delete old_backup_20240115_120000

BACKUP LOCATIONS:
    Backups are stored in: $BACKUP_DIR
    Each backup includes metadata, checksums, and version information.

PROTECTED PATHS:
    The following paths are protected from backup/restore operations:
    - User home directories (/home/*, /root/*)
    - SSH keys (*.ssh/*)
    - GPG keys (*.gnupg/*)
    - System authentication files (passwd, shadow, etc.)

EOF
}

# Main execution function
main() {
    local command=""
    
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
            -f|--force)
                FORCE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            backup|restore|list|delete|validate|version)
                command="$1"
                shift
                break
                ;;
            *)
                error_exit "Unknown option: $1. Use -h for help."
                ;;
        esac
    done
    
    # Check if command was provided
    if [[ -z "$command" ]]; then
        usage
        error_exit "No command specified"
    fi
    
    # Check for required tools
    if ! command -v jq >/dev/null 2>&1; then
        error_exit "jq is required but not installed. Please install jq package."
    fi
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No changes will be made"
    fi
    
    # Execute command
    case "$command" in
        "backup")
            cmd_backup "$@"
            ;;
        "restore")
            cmd_restore "$@"
            ;;
        "list")
            cmd_list "$@"
            ;;
        "delete")
            cmd_delete "$@"
            ;;
        "validate")
            cmd_validate "$@"
            ;;
        "version")
            cmd_version "$@"
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Execute main function with all arguments
main "$@"