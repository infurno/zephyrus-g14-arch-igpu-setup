#!/bin/bash

# ASUS ROG Zephyrus G14 Arch Linux Setup Script
# Optimized for hybrid GPU configuration (AMD iGPU + NVIDIA dGPU)

set -euo pipefail

# Source error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/error-handler.sh"

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"

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
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
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
            if [[ "$VERBOSE" == true ]]; then
                echo -e "[DEBUG] $message"
            fi
            ;;
    esac
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_success() {
    log "SUCCESS" "$@"
}

log_debug() {
    log "DEBUG" "$@"
}

# Enhanced error handling with rollback support
enhanced_error_exit() {
    local error_message="$1"
    local exit_code="${2:-$E_GENERAL}"
    local recovery_function="${3:-}"
    local context="${4:-}"
    
    error_exit "$error_message" "$exit_code" "$recovery_function" "$context"
}

# Create rollback point before major operations
create_setup_rollback() {
    local operation_name="$1"
    local description="${2:-Setup operation rollback point}"
    
    log_info "Creating rollback point for: $operation_name"
    
    if ! create_rollback_point "$operation_name" "$description"; then
        log_warn "Failed to create rollback point, continuing without rollback capability"
        return 1
    fi
    
    return 0
}

# Enhanced package installation with error handling
install_package_with_recovery() {
    local package="$1"
    local max_retries="${2:-3}"
    local retry_count=0
    
    log_debug "Installing package with recovery: $package"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install package: $package"
        return 0
    fi
    
    # Check if package is already installed
    if pacman -Qi "$package" &>/dev/null; then
        log_debug "Package $package is already installed"
        return 0
    fi
    
    while [[ $retry_count -lt $max_retries ]]; do
        local error_output
        if error_output=$(sudo pacman -S --noconfirm "$package" 2>&1); then
            log_success "Successfully installed: $package"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warn "Failed to install $package (attempt $retry_count/$max_retries)"
            
            # Handle specific package errors
            handle_package_error "$package" "$error_output"
            
            if [[ $retry_count -lt $max_retries ]]; then
                log_info "Retrying in 5 seconds..."
                sleep 5
                # Update package database before retry
                sudo pacman -Sy || log_warn "Failed to update package database"
            fi
        fi
    done
    
    log_error "Failed to install $package after $max_retries attempts"
    return 1
}

# Enhanced service management with error handling
manage_service_with_recovery() {
    local service="$1"
    local operation="$2" # enable, start, restart, etc.
    local max_retries="${3:-2}"
    local retry_count=0
    
    log_debug "Managing service with recovery: $service ($operation)"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would $operation service: $service"
        return 0
    fi
    
    while [[ $retry_count -lt $max_retries ]]; do
        local error_output
        if error_output=$(sudo systemctl "$operation" "$service" 2>&1); then
            log_success "Successfully ${operation}ed service: $service"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warn "Failed to $operation $service (attempt $retry_count/$max_retries)"
            
            # Handle specific service errors
            handle_service_error "$service" "$operation" "$error_output"
            
            if [[ $retry_count -lt $max_retries ]]; then
                log_info "Attempting service recovery..."
                recover_service_failure "$service" || log_warn "Service recovery failed"
                sleep 2
            fi
        fi
    done
    
    log_error "Failed to $operation service $service after $max_retries attempts"
    return 1
}

# Enhanced configuration file installation with backup and recovery
install_config_with_backup() {
    local source_file="$1"
    local target_file="$2"
    local description="${3:-Configuration file}"
    
    log_info "Installing $description: $target_file"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install $description from $source_file to $target_file"
        return 0
    fi
    
    # Validate source file
    if [[ ! -f "$source_file" ]]; then
        log_error "$description source file not found: $source_file"
        return 1
    fi
    
    # Create backup of existing file
    if [[ -f "$target_file" ]]; then
        local backup_file="${target_file}.backup-$(date +%Y%m%d_%H%M%S)"
        if sudo cp "$target_file" "$backup_file"; then
            log_info "Backed up existing $description to: $backup_file"
        else
            log_warn "Failed to backup existing $description"
        fi
    fi
    
    # Create target directory if needed
    local target_dir=$(dirname "$target_file")
    sudo mkdir -p "$target_dir" || {
        log_error "Failed to create directory: $target_dir"
        return 1
    }
    
    # Install configuration file
    if sudo cp "$source_file" "$target_file"; then
        sudo chmod 644 "$target_file"
        sudo chown root:root "$target_file"
        log_success "$description installed successfully"
        return 0
    else
        log_error "Failed to install $description"
        
        # Attempt to restore backup if installation failed
        if [[ -f "${backup_file:-}" ]]; then
            log_info "Attempting to restore backup..."
            sudo cp "$backup_file" "$target_file" || log_error "Failed to restore backup"
        fi
        
        return 1
    fi
}

# User interaction functions
prompt_user() {
    local message="$1"
    local default="${2:-}"
    local response
    
    if [[ -n "$default" ]]; then
        read -p "$message [$default]: " response
        response="${response:-$default}"
    else
        read -p "$message: " response
    fi
    
    echo "$response"
}

confirm_action() {
    local message="$1"
    local default="${2:-n}"
    local response
    
    while true; do
        response=$(prompt_user "$message (y/n)" "$default")
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

# System validation functions
check_arch_linux() {
    if [[ ! -f /etc/arch-release ]]; then
        error_exit "This script is designed for Arch Linux only."
    fi
    log_success "Arch Linux detected"
}

check_root_privileges() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should not be run as root. Please run as a regular user with sudo privileges."
    fi
    
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo privileges. You may be prompted for your password."
        if ! sudo true; then
            error_exit "Failed to obtain sudo privileges"
        fi
    fi
    log_success "Sudo privileges confirmed"
}

check_internet_connection() {
    if ! ping -c 1 archlinux.org &> /dev/null; then
        error_exit "Internet connection required but not available"
    fi
    log_success "Internet connection verified"
}

check_hardware_compatibility() {
    local cpu_info=$(lscpu | grep "Model name" | head -1)
    local gpu_info=$(lspci | grep -E "(VGA|3D)")
    
    log_info "Detected CPU: $cpu_info"
    log_info "Detected GPU(s):"
    echo "$gpu_info" | while read -r line; do
        log_info "  $line"
    done
    
    # Check for AMD CPU
    if ! echo "$cpu_info" | grep -qi "amd"; then
        log_warn "This script is optimized for AMD CPUs. Proceed with caution."
    fi
    
    # Check for hybrid GPU setup
    local amd_gpu=$(echo "$gpu_info" | grep -i "amd\|radeon" | wc -l)
    local nvidia_gpu=$(echo "$gpu_info" | grep -i "nvidia" | wc -l)
    
    if [[ $amd_gpu -eq 0 ]] || [[ $nvidia_gpu -eq 0 ]]; then
        log_warn "Hybrid AMD/NVIDIA GPU setup not detected. This script is optimized for dual GPU systems."
        if ! confirm_action "Continue anyway?"; then
            exit 0
        fi
    else
        log_success "Hybrid GPU setup detected (AMD + NVIDIA)"
    fi
}

# Initialization functions
initialize_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    log_info "=== ASUS ROG Zephyrus G14 Setup Started ==="
    log_info "Script version: 1.0"
    log_info "Log file: $LOG_FILE"
    log_info "Script directory: $SCRIPT_DIR"
}

show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    ASUS ROG Zephyrus G14 Setup Script                       ║
║                     Arch Linux Hybrid GPU Configuration                     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  This script will configure your system for optimal battery life using      ║
║  the AMD iGPU while maintaining NVIDIA dGPU access for gaming and CUDA.     ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF
}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -d, --dry-run   Show what would be done without making changes
    -f, --force     Skip confirmation prompts
    --log-dir DIR   Specify custom log directory (default: ./logs)
    --no-backup     Skip creating pre-setup configuration backup

Examples:
    $SCRIPT_NAME                    # Interactive setup with backup
    $SCRIPT_NAME --verbose          # Verbose output
    $SCRIPT_NAME --dry-run          # Preview changes
    $SCRIPT_NAME --force --verbose  # Automated setup with verbose output
    $SCRIPT_NAME --no-backup        # Skip backup creation

BACKUP SYSTEM:
    By default, this script creates a backup of your current system configuration
    before making any changes. This allows you to restore your system if something
    goes wrong. Use --no-backup to skip this step.
    
    Backup management commands:
        ./scripts/config-backup.sh list      # List available backups
        ./scripts/config-backup.sh restore   # Restore from backup
        ./scripts/config-backup.sh validate  # Validate backup integrity

EOF
}

# Package arrays for different component categories
declare -ra CORE_PACKAGES=(
    "linux-headers"
    "mesa"
    "vulkan-radeon"
    "xf86-video-amdgpu"
    "mesa-utils"
    "vulkan-tools"
    "base-devel"
    "git"
    "wget"
    "curl"
)

declare -ra NVIDIA_PACKAGES=(
    "nvidia"
    "nvidia-utils"
    "lib32-nvidia-utils"
    "nvidia-prime"
    "nvidia-settings"
    "opencl-nvidia"
    "lib32-opencl-nvidia"
)

declare -ra POWER_PACKAGES=(
    "tlp"
    "tlp-rdw"
    "auto-cpufreq"
    "powertop"
    "acpi_call"
    "bbswitch"
    "thermald"
    "cpupower"
)

declare -ra ASUS_PACKAGES=(
    "asusctl"
    "supergfxctl"
    "rog-control-center"
    "power-profiles-daemon"
    "switcheroo-control"
)

# Package installation functions with enhanced error handling and retry logic
install_package() {
    local package="$1"
    local max_retries="${2:-3}"
    
    # Use the enhanced installation function
    install_package_with_recovery "$package" "$max_retries"
}

install_aur_package() {
    local package="$1"
    local max_retries="${2:-3}"
    local retry_count=0
    
    log_debug "Installing AUR package: $package"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install AUR package: $package"
        return 0
    fi
    
    # Check if yay is installed, install if not
    if ! command -v yay &>/dev/null; then
        log_info "Installing yay AUR helper..."
        install_yay_helper || return 1
    fi
    
    # Check if package is already installed
    if pacman -Qi "$package" &>/dev/null; then
        log_debug "AUR package $package is already installed"
        return 0
    fi
    
    while [[ $retry_count -lt $max_retries ]]; do
        if yay -S --noconfirm "$package"; then
            log_success "Successfully installed AUR package: $package"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warn "Failed to install AUR package $package (attempt $retry_count/$max_retries)"
            
            if [[ $retry_count -lt $max_retries ]]; then
                log_info "Retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    log_error "Failed to install AUR package $package after $max_retries attempts"
    return 1
}

install_yay_helper() {
    log_info "Installing yay AUR helper..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install yay AUR helper"
        return 0
    fi
    
    local temp_dir="/tmp/yay-install"
    
    # Clean up any existing installation
    rm -rf "$temp_dir"
    
    # Clone and build yay
    git clone https://aur.archlinux.org/yay.git "$temp_dir" || return 1
    cd "$temp_dir" || return 1
    makepkg -si --noconfirm || return 1
    cd - || return 1
    
    # Clean up
    rm -rf "$temp_dir"
    
    log_success "yay AUR helper installed successfully"
    return 0
}

install_package_group() {
    local group_name="$1"
    local -n package_array=$2
    local failed_packages=()
    
    log_info "Installing $group_name packages..."
    
    for package in "${package_array[@]}"; do
        if ! install_package "$package"; then
            failed_packages+=("$package")
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warn "Failed to install some $group_name packages: ${failed_packages[*]}"
        return 1
    else
        log_success "All $group_name packages installed successfully"
        return 0
    fi
}

install_aur_package_group() {
    local group_name="$1"
    local -n package_array=$2
    local failed_packages=()
    
    log_info "Installing $group_name AUR packages..."
    
    for package in "${package_array[@]}"; do
        if ! install_aur_package "$package"; then
            failed_packages+=("$package")
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warn "Failed to install some $group_name AUR packages: ${failed_packages[*]}"
        return 1
    else
        log_success "All $group_name AUR packages installed successfully"
        return 0
    fi
}

# Package conflict detection and resolution
detect_package_conflicts() {
    log_info "Checking for package conflicts..."
    
    local conflicts_found=false
    
    # Check for conflicting GPU drivers
    if pacman -Qi xf86-video-nouveau &>/dev/null; then
        log_warn "Conflicting package detected: xf86-video-nouveau (conflicts with NVIDIA proprietary driver)"
        if confirm_action "Remove xf86-video-nouveau?"; then
            sudo pacman -Rns --noconfirm xf86-video-nouveau || log_error "Failed to remove xf86-video-nouveau"
        else
            conflicts_found=true
        fi
    fi
    
    # Check for conflicting power management tools
    if pacman -Qi laptop-mode-tools &>/dev/null; then
        log_warn "Conflicting package detected: laptop-mode-tools (conflicts with TLP)"
        if confirm_action "Remove laptop-mode-tools?"; then
            sudo pacman -Rns --noconfirm laptop-mode-tools || log_error "Failed to remove laptop-mode-tools"
        else
            conflicts_found=true
        fi
    fi
    
    # Check for conflicting CPU frequency scaling tools
    if pacman -Qi cpufrequtils &>/dev/null; then
        log_warn "Conflicting package detected: cpufrequtils (may conflict with auto-cpufreq)"
        if confirm_action "Remove cpufrequtils?"; then
            sudo pacman -Rns --noconfirm cpufrequtils || log_error "Failed to remove cpufrequtils"
        else
            conflicts_found=true
        fi
    fi
    
    if [[ "$conflicts_found" == true ]]; then
        log_warn "Some package conflicts were not resolved. This may cause issues."
        if ! confirm_action "Continue anyway?"; then
            error_exit "Setup cancelled due to unresolved package conflicts"
        fi
    else
        log_success "No package conflicts detected"
    fi
}

# ASUS repository setup and GPG key management
setup_asus_repository() {
    log_info "Setting up ASUS Linux repository..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would set up ASUS Linux repository"
        return 0
    fi
    
    local asus_repo_url="https://gitlab.com/asus-linux/asus-linux-drivers/-/raw/main/pkg"
    local keyring_url="https://gitlab.com/asus-linux/asus-linux-drivers/-/raw/main/pkg/asus-linux-keyring-1-1-any.pkg.tar.xz"
    local temp_keyring="/tmp/asus-linux-keyring.pkg.tar.xz"
    
    # Check if repository is already configured
    if grep -q "asus-linux" /etc/pacman.conf; then
        log_debug "ASUS Linux repository already configured"
        return 0
    fi
    
    # Download and install keyring
    log_info "Installing ASUS Linux keyring..."
    if ! wget -O "$temp_keyring" "$keyring_url"; then
        log_error "Failed to download ASUS Linux keyring"
        return 1
    fi
    
    if ! sudo pacman -U --noconfirm "$temp_keyring"; then
        log_error "Failed to install ASUS Linux keyring"
        rm -f "$temp_keyring"
        return 1
    fi
    
    rm -f "$temp_keyring"
    
    # Add repository to pacman.conf
    log_info "Adding ASUS Linux repository to pacman.conf..."
    
    # Create backup of pacman.conf
    sudo cp /etc/pacman.conf /etc/pacman.conf.backup
    
    # Add ASUS repository
    cat << EOF | sudo tee -a /etc/pacman.conf

# ASUS Linux Repository
[asus-linux]
SigLevel = Required DatabaseOptional
Server = https://gitlab.com/asus-linux/asus-linux-drivers/-/raw/main/pkg
EOF
    
    # Update package database
    log_info "Updating package database..."
    if ! sudo pacman -Sy; then
        log_error "Failed to update package database"
        return 1
    fi
    
    log_success "ASUS Linux repository configured successfully"
    return 0
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would update system packages"
        return 0
    fi
    
    # Update keyring first to avoid signature issues
    if ! sudo pacman -Sy archlinux-keyring; then
        log_warn "Failed to update archlinux-keyring, continuing anyway..."
    fi
    
    # Full system update
    if ! sudo pacman -Syu --noconfirm; then
        log_error "Failed to update system packages"
        return 1
    fi
    
    log_success "System packages updated successfully"
    return 0
}

# Enhanced package setup function with comprehensive error handling
setup_packages() {
    log_info "=== Starting Package Installation ==="
    
    # Create rollback point before package installation
    create_setup_rollback "pre-package-install" "Before package installation" || {
        log_warn "Continuing without rollback capability"
    }
    
    # Update system first with error handling
    if ! update_system; then
        enhanced_error_exit "Failed to update system packages" "$E_PACKAGE_INSTALL" "recover_package_installation" "System update failed"
    fi
    
    # Detect and resolve package conflicts with recovery
    if ! detect_package_conflicts; then
        log_warn "Package conflicts detected but not fully resolved"
        if ! confirm_action "Continue with potential conflicts?"; then
            enhanced_error_exit "Setup cancelled due to unresolved package conflicts" "$E_PACKAGE_INSTALL"
        fi
    fi
    
    # Set up ASUS repository with error handling
    if ! setup_asus_repository; then
        log_warn "Failed to set up ASUS repository, some packages may not be available"
        log_warn "This may cause ASUS-specific package installations to fail"
    fi
    
    # Install package groups with enhanced error handling
    local failed_groups=()
    local critical_failures=()
    
    # Install core packages (critical)
    log_info "Installing core packages..."
    if ! install_package_group_with_recovery "core" CORE_PACKAGES; then
        failed_groups+=("core")
        critical_failures+=("core")
    fi
    
    # Install NVIDIA packages (critical for GPU functionality)
    log_info "Installing NVIDIA packages..."
    if ! install_package_group_with_recovery "NVIDIA" NVIDIA_PACKAGES; then
        failed_groups+=("NVIDIA")
        critical_failures+=("NVIDIA")
    fi
    
    # Install power management packages (important but not critical)
    log_info "Installing power management packages..."
    if ! install_package_group_with_recovery "power management" POWER_PACKAGES; then
        failed_groups+=("power management")
    fi
    
    # Install ASUS packages (optional)
    log_info "Installing ASUS packages..."
    if ! install_aur_package_group_with_recovery "ASUS" ASUS_PACKAGES; then
        failed_groups+=("ASUS")
    fi
    
    # Evaluate installation results
    if [[ ${#critical_failures[@]} -gt 0 ]]; then
        log_error "Critical package groups failed to install: ${critical_failures[*]}"
        log_error "System may not function properly without these packages"
        
        # Offer recovery options
        echo -e "\n${YELLOW}Recovery Options:${NC}"
        echo "1. Retry failed package installations"
        echo "2. Continue with partial installation"
        echo "3. Rollback and exit"
        
        read -p "Select option (1-3): " recovery_choice
        
        case "$recovery_choice" in
            1)
                log_info "Retrying failed package installations..."
                retry_failed_package_groups "${critical_failures[@]}"
                ;;
            2)
                log_warn "Continuing with partial installation"
                ;;
            3)
                if [[ "$ROLLBACK_AVAILABLE" == true ]]; then
                    offer_rollback
                fi
                enhanced_error_exit "Setup cancelled due to critical package failures" "$E_PACKAGE_INSTALL"
                ;;
            *)
                log_warn "Invalid choice, continuing with partial installation"
                ;;
        esac
    elif [[ ${#failed_groups[@]} -gt 0 ]]; then
        log_warn "Some non-critical package groups failed to install: ${failed_groups[*]}"
        log_warn "System should still function, but some features may be unavailable"
        
        if ! confirm_action "Continue with setup despite non-critical package failures?"; then
            enhanced_error_exit "Setup cancelled due to package installation failures" "$E_PACKAGE_INSTALL"
        fi
    else
        log_success "All packages installed successfully"
    fi
    
    # Validate package installation
    if ! validate_package_installation; then
        log_warn "Package installation validation found issues"
    fi
    
    log_success "=== Package Installation Completed ==="
}

# Enhanced package group installation with recovery
install_package_group_with_recovery() {
    local group_name="$1"
    local -n package_array=$2
    local failed_packages=()
    local max_group_retries=2
    local retry_count=0
    
    log_info "Installing $group_name packages with recovery..."
    
    while [[ $retry_count -lt $max_group_retries ]]; do
        failed_packages=()
        
        for package in "${package_array[@]}"; do
            if ! install_package_with_recovery "$package"; then
                failed_packages+=("$package")
            fi
        done
        
        if [[ ${#failed_packages[@]} -eq 0 ]]; then
            log_success "All $group_name packages installed successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warn "Failed to install some $group_name packages: ${failed_packages[*]} (attempt $retry_count/$max_group_retries)"
            
            if [[ $retry_count -lt $max_group_retries ]]; then
                log_info "Attempting package group recovery..."
                recover_package_installation || log_warn "Package recovery failed"
                sleep 5
            fi
        fi
    done
    
    log_error "Failed to install $group_name packages after $max_group_retries attempts: ${failed_packages[*]}"
    return 1
}

# Enhanced AUR package group installation with recovery
install_aur_package_group_with_recovery() {
    local group_name="$1"
    local -n package_array=$2
    local failed_packages=()
    local max_group_retries=2
    local retry_count=0
    
    log_info "Installing $group_name AUR packages with recovery..."
    
    # Ensure yay is available
    if ! command -v yay &>/dev/null; then
        log_info "Installing yay AUR helper..."
        if ! install_yay_helper; then
            log_error "Failed to install yay AUR helper"
            return 1
        fi
    fi
    
    while [[ $retry_count -lt $max_group_retries ]]; do
        failed_packages=()
        
        for package in "${package_array[@]}"; do
            if ! install_aur_package "$package"; then
                failed_packages+=("$package")
            fi
        done
        
        if [[ ${#failed_packages[@]} -eq 0 ]]; then
            log_success "All $group_name AUR packages installed successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warn "Failed to install some $group_name AUR packages: ${failed_packages[*]} (attempt $retry_count/$max_group_retries)"
            
            if [[ $retry_count -lt $max_group_retries ]]; then
                log_info "Attempting AUR package recovery..."
                # Clear yay cache and retry
                yay -Scc --noconfirm || true
                sleep 5
            fi
        fi
    done
    
    log_error "Failed to install $group_name AUR packages after $max_group_retries attempts: ${failed_packages[*]}"
    return 1
}

# Retry failed package groups
retry_failed_package_groups() {
    local failed_groups=("$@")
    
    log_info "Retrying failed package groups: ${failed_groups[*]}"
    
    for group in "${failed_groups[@]}"; do
        case "$group" in
            "core")
                install_package_group_with_recovery "core" CORE_PACKAGES
                ;;
            "NVIDIA")
                install_package_group_with_recovery "NVIDIA" NVIDIA_PACKAGES
                ;;
            "power management")
                install_package_group_with_recovery "power management" POWER_PACKAGES
                ;;
            "ASUS")
                install_aur_package_group_with_recovery "ASUS" ASUS_PACKAGES
                ;;
        esac
    done
}

# Validate package installation
validate_package_installation() {
    log_info "Validating package installation..."
    
    local validation_errors=()
    
    # Check critical packages
    local critical_packages=("mesa" "nvidia" "nvidia-utils" "tlp")
    
    for package in "${critical_packages[@]}"; do
        if ! pacman -Qi "$package" &>/dev/null; then
            validation_errors+=("Critical package not installed: $package")
        fi
    done
    
    # Check package database integrity
    if ! pacman -Dk &>/dev/null; then
        validation_errors+=("Package database integrity check failed")
    fi
    
    # Check for broken dependencies
    local broken_deps=$(pacman -Qk 2>&1 | grep -c "warning" || echo "0")
    if [[ $broken_deps -gt 0 ]]; then
        validation_errors+=("Found $broken_deps package warnings")
    fi
    
    if [[ ${#validation_errors[@]} -eq 0 ]]; then
        log_success "Package installation validation passed"
        return 0
    else
        log_warn "Package installation validation found issues:"
        for error in "${validation_errors[@]}"; do
            log_warn "  - $error"
        done
        return 1
    fi
}

# Xorg configuration functions
backup_xorg_config() {
    local backup_dir="/etc/X11/xorg.conf.d.backup"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    log_info "Creating backup of existing Xorg configuration..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would backup Xorg configuration to $backup_dir"
        return 0
    fi
    
    # Create backup directory if it doesn't exist
    if [[ ! -d "$backup_dir" ]]; then
        sudo mkdir -p "$backup_dir"
    fi
    
    # Backup existing configuration files
    if [[ -d "/etc/X11/xorg.conf.d" ]]; then
        sudo cp -r "/etc/X11/xorg.conf.d" "${backup_dir}/xorg.conf.d_${timestamp}"
        log_success "Xorg configuration backed up to ${backup_dir}/xorg.conf.d_${timestamp}"
    fi
    
    # Backup xorg.conf if it exists
    if [[ -f "/etc/X11/xorg.conf" ]]; then
        sudo cp "/etc/X11/xorg.conf" "${backup_dir}/xorg.conf_${timestamp}"
        log_success "xorg.conf backed up to ${backup_dir}/xorg.conf_${timestamp}"
    fi
    
    return 0
}

restore_xorg_config() {
    local backup_dir="/etc/X11/xorg.conf.d.backup"
    
    log_info "Available Xorg configuration backups:"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_warn "No backup directory found at $backup_dir"
        return 1
    fi
    
    local backups=($(ls -1 "$backup_dir" | grep "xorg.conf.d_" | sort -r))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        log_warn "No Xorg configuration backups found"
        return 1
    fi
    
    echo "Available backups:"
    for i in "${!backups[@]}"; do
        echo "  $((i+1)). ${backups[i]}"
    done
    
    local choice
    read -p "Select backup to restore (1-${#backups[@]}): " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#backups[@]} ]]; then
        log_error "Invalid selection"
        return 1
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    
    if confirm_action "Restore backup $selected_backup?"; then
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would restore backup $selected_backup"
            return 0
        fi
        
        # Remove current configuration
        sudo rm -rf "/etc/X11/xorg.conf.d"
        
        # Restore backup
        sudo cp -r "${backup_dir}/${selected_backup}" "/etc/X11/xorg.conf.d"
        
        log_success "Xorg configuration restored from backup: $selected_backup"
        return 0
    fi
    
    return 1
}

detect_gpu_bus_ids() {
    log_info "Detecting GPU PCI bus IDs..."
    
    local amd_bus_id=""
    local nvidia_bus_id=""
    
    # Get PCI information for GPUs
    local gpu_info=$(lspci -nn | grep -E "(VGA|3D)")
    
    log_debug "GPU information:"
    echo "$gpu_info" | while read -r line; do
        log_debug "  $line"
    done
    
    # Extract AMD GPU bus ID
    local amd_line=$(echo "$gpu_info" | grep -i "amd\|radeon" | head -1)
    if [[ -n "$amd_line" ]]; then
        amd_bus_id=$(echo "$amd_line" | cut -d' ' -f1 | sed 's/\([0-9a-f]\{2\}\):\([0-9a-f]\{2\}\)\.\([0-9a-f]\)/PCI:\1:\2:\3/')
        log_info "AMD GPU detected at bus ID: $amd_bus_id"
    fi
    
    # Extract NVIDIA GPU bus ID
    local nvidia_line=$(echo "$gpu_info" | grep -i "nvidia" | head -1)
    if [[ -n "$nvidia_line" ]]; then
        nvidia_bus_id=$(echo "$nvidia_line" | cut -d' ' -f1 | sed 's/\([0-9a-f]\{2\}\):\([0-9a-f]\{2\}\)\.\([0-9a-f]\)/PCI:\1:\2:\3/')
        log_info "NVIDIA GPU detected at bus ID: $nvidia_bus_id"
    fi
    
    # Export for use in other functions
    export DETECTED_AMD_BUS_ID="$amd_bus_id"
    export DETECTED_NVIDIA_BUS_ID="$nvidia_bus_id"
    
    if [[ -z "$amd_bus_id" ]] || [[ -z "$nvidia_bus_id" ]]; then
        log_warn "Could not detect both AMD and NVIDIA GPUs"
        log_warn "AMD Bus ID: ${amd_bus_id:-'Not detected'}"
        log_warn "NVIDIA Bus ID: ${nvidia_bus_id:-'Not detected'}"
        return 1
    fi
    
    return 0
}

install_xorg_config() {
    local config_file="${SCRIPT_DIR}/configs/xorg/10-hybrid.conf"
    local target_dir="/etc/X11/xorg.conf.d"
    local target_file="${target_dir}/10-hybrid.conf"
    
    log_info "Installing Xorg hybrid GPU configuration..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install Xorg configuration from $config_file to $target_file"
        return 0
    fi
    
    # Check if source config file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "Xorg configuration file not found: $config_file"
        return 1
    fi
    
    # Create target directory if it doesn't exist
    sudo mkdir -p "$target_dir"
    
    # Detect GPU bus IDs and update configuration
    if detect_gpu_bus_ids; then
        # Create temporary file with updated bus IDs
        local temp_config="/tmp/10-hybrid.conf"
        cp "$config_file" "$temp_config"
        
        # Update bus IDs in the configuration
        if [[ -n "$DETECTED_AMD_BUS_ID" ]]; then
            sed -i "s|BusID \"PCI:6:0:0\"|BusID \"$DETECTED_AMD_BUS_ID\"|g" "$temp_config"
            log_info "Updated AMD GPU bus ID to: $DETECTED_AMD_BUS_ID"
        fi
        
        if [[ -n "$DETECTED_NVIDIA_BUS_ID" ]]; then
            sed -i "s|BusID \"PCI:1:0:0\"|BusID \"$DETECTED_NVIDIA_BUS_ID\"|g" "$temp_config"
            log_info "Updated NVIDIA GPU bus ID to: $DETECTED_NVIDIA_BUS_ID"
        fi
        
        # Install the updated configuration
        sudo cp "$temp_config" "$target_file"
        rm -f "$temp_config"
    else
        log_warn "Using default bus IDs in Xorg configuration"
        sudo cp "$config_file" "$target_file"
    fi
    
    # Set proper permissions
    sudo chmod 644 "$target_file"
    sudo chown root:root "$target_file"
    
    log_success "Xorg configuration installed to: $target_file"
    return 0
}

validate_xorg_config() {
    log_info "Validating Xorg configuration..."
    
    local config_file="/etc/X11/xorg.conf.d/10-hybrid.conf"
    
    # Check if configuration file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "Xorg configuration file not found: $config_file"
        return 1
    fi
    
    # Validate configuration syntax
    log_info "Checking Xorg configuration syntax..."
    if ! sudo Xorg -config "$config_file" -configtest 2>/dev/null; then
        log_warn "Xorg configuration syntax validation failed"
        log_warn "This may be normal if the system is not in a graphical environment"
    else
        log_success "Xorg configuration syntax is valid"
    fi
    
    # Check for required sections
    local required_sections=("ServerLayout" "Device" "Screen")
    local missing_sections=()
    
    for section in "${required_sections[@]}"; do
        if ! grep -q "Section \"$section\"" "$config_file"; then
            missing_sections+=("$section")
        fi
    done
    
    if [[ ${#missing_sections[@]} -gt 0 ]]; then
        log_error "Missing required sections in Xorg configuration: ${missing_sections[*]}"
        return 1
    fi
    
    # Check for AMD and NVIDIA device sections
    if ! grep -q "Driver \"amdgpu\"" "$config_file"; then
        log_error "AMD GPU driver configuration not found in Xorg config"
        return 1
    fi
    
    if ! grep -q "Driver \"nvidia\"" "$config_file"; then
        log_error "NVIDIA GPU driver configuration not found in Xorg config"
        return 1
    fi
    
    # Validate bus IDs format
    local bus_ids=$(grep "BusID" "$config_file" | grep -o "PCI:[0-9a-f]*:[0-9a-f]*:[0-9a-f]*")
    if [[ $(echo "$bus_ids" | wc -l) -lt 2 ]]; then
        log_warn "Expected at least 2 PCI bus IDs in configuration"
    fi
    
    log_success "Xorg configuration validation completed"
    return 0
}

verify_display_configuration() {
    log_info "Verifying display configuration..."
    
    # Check if we're in a graphical environment
    if [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        log_warn "Not in a graphical environment, skipping display verification"
        return 0
    fi
    
    # Check available displays
    if command -v xrandr &>/dev/null; then
        log_info "Available displays:"
        xrandr --listmonitors 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
        
        # Check for internal display
        if xrandr | grep -q "eDP-1\|eDP1\|LVDS-1\|LVDS1"; then
            log_success "Internal display detected"
        else
            log_warn "Internal display not detected"
        fi
    else
        log_warn "xrandr not available, cannot verify display configuration"
    fi
    
    # Check GPU information
    if command -v glxinfo &>/dev/null; then
        local renderer=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1)
        if [[ -n "$renderer" ]]; then
            log_info "Current OpenGL renderer: $renderer"
        fi
    else
        log_warn "glxinfo not available, install mesa-utils to check GPU rendering"
    fi
    
    return 0
}

setup_xorg() {
    log_info "=== Setting up Xorg configuration for hybrid GPU ==="
    
    # Create backup of existing configuration
    backup_xorg_config || log_warn "Failed to backup existing Xorg configuration"
    
    # Install new Xorg configuration
    if ! install_xorg_config; then
        log_error "Failed to install Xorg configuration"
        return 1
    fi
    
    # Validate the configuration
    if ! validate_xorg_config; then
        log_error "Xorg configuration validation failed"
        
        if confirm_action "Restore previous configuration?"; then
            restore_xorg_config
        fi
        return 1
    fi
    
    # Verify display configuration (if in graphical environment)
    verify_display_configuration
    
    log_success "=== Xorg configuration setup completed ==="
    log_info "Note: You may need to restart your display manager or reboot for changes to take effect"
    
    return 0
}

setup_power_management() {
    log_info "=== Setting up Power Management ==="
    
    local config_dir="${SCRIPT_DIR}/configs"
    local scripts_dir="${SCRIPT_DIR}/scripts"
    
    # Install TLP configuration
    install_tlp_config || log_warn "Failed to install TLP configuration"
    
    # Install auto-cpufreq configuration
    install_auto_cpufreq_config || log_warn "Failed to install auto-cpufreq configuration"
    
    # Setup power management script
    install_power_management_script || log_warn "Failed to install power management script"
    
    # Install udev rules for NVIDIA power management
    install_nvidia_power_udev_rules || log_warn "Failed to install NVIDIA power management udev rules"
    
    # Install kernel modules configuration
    install_kernel_modules_config || log_warn "Failed to install kernel modules configuration"
    
    # Configure AMD P-state EPP and power management services
    configure_power_management_services || log_warn "Failed to configure power management services"
    
    log_success "=== Power Management Setup Completed ==="
    log_info "Note: Some changes may require a reboot to take effect"
    
    return 0
}

install_tlp_config() {
    local config_file="${SCRIPT_DIR}/configs/tlp/tlp.conf"
    local target_file="/etc/tlp.conf"
    
    log_info "Installing TLP configuration..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install TLP configuration from $config_file to $target_file"
        return 0
    fi
    
    # Check if source config file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "TLP configuration file not found: $config_file"
        return 1
    fi
    
    # Backup existing TLP configuration
    if [[ -f "$target_file" ]]; then
        local backup_file="${target_file}.backup-$(date +%Y%m%d_%H%M%S)"
        sudo cp "$target_file" "$backup_file"
        log_info "Backed up existing TLP config to: $backup_file"
    fi
    
    # Install new configuration
    sudo cp "$config_file" "$target_file"
    sudo chmod 644 "$target_file"
    sudo chown root:root "$target_file"
    
    log_success "TLP configuration installed to: $target_file"
    return 0
}

install_auto_cpufreq_config() {
    local config_file="${SCRIPT_DIR}/configs/auto-cpufreq/auto-cpufreq.conf"
    local target_file="/etc/auto-cpufreq.conf"
    
    log_info "Installing auto-cpufreq configuration..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install auto-cpufreq configuration from $config_file to $target_file"
        return 0
    fi
    
    # Check if source config file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "auto-cpufreq configuration file not found: $config_file"
        return 1
    fi
    
    # Backup existing auto-cpufreq configuration
    if [[ -f "$target_file" ]]; then
        local backup_file="${target_file}.backup-$(date +%Y%m%d_%H%M%S)"
        sudo cp "$target_file" "$backup_file"
        log_info "Backed up existing auto-cpufreq config to: $backup_file"
    fi
    
    # Install new configuration
    sudo cp "$config_file" "$target_file"
    sudo chmod 644 "$target_file"
    sudo chown root:root "$target_file"
    
    log_success "auto-cpufreq configuration installed to: $target_file"
    return 0
}

install_nvidia_power_udev_rules() {
    local config_file="${SCRIPT_DIR}/configs/udev/80-nvidia-pm.rules"
    local target_dir="/etc/udev/rules.d"
    local target_file="${target_dir}/80-nvidia-pm.rules"
    
    log_info "Installing NVIDIA power management udev rules..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install udev rules from $config_file to $target_file"
        return 0
    fi
    
    # Check if source config file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "NVIDIA power management udev rules file not found: $config_file"
        return 1
    fi
    
    # Create target directory if it doesn't exist
    sudo mkdir -p "$target_dir"
    
    # Backup existing udev rules if they exist
    if [[ -f "$target_file" ]]; then
        local backup_file="${target_file}.backup-$(date +%Y%m%d_%H%M%S)"
        sudo cp "$target_file" "$backup_file"
        log_info "Backed up existing udev rules to: $backup_file"
    fi
    
    # Install new udev rules
    sudo cp "$config_file" "$target_file"
    sudo chmod 644 "$target_file"
    sudo chown root:root "$target_file"
    
    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    log_success "NVIDIA power management udev rules installed to: $target_file"
    return 0
}

install_kernel_modules_config() {
    local config_file="${SCRIPT_DIR}/configs/modules/bbswitch.conf"
    local target_dir="/etc/modprobe.d"
    local target_file="${target_dir}/bbswitch.conf"
    
    log_info "Installing kernel modules configuration..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install kernel modules config from $config_file to $target_file"
        return 0
    fi
    
    # Check if source config file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "Kernel modules configuration file not found: $config_file"
        return 1
    fi
    
    # Create target directory if it doesn't exist
    sudo mkdir -p "$target_dir"
    
    # Backup existing modules configuration if it exists
    if [[ -f "$target_file" ]]; then
        local backup_file="${target_file}.backup-$(date +%Y%m%d_%H%M%S)"
        sudo cp "$target_file" "$backup_file"
        log_info "Backed up existing modules config to: $backup_file"
    fi
    
    # Install new modules configuration
    sudo cp "$config_file" "$target_file"
    sudo chmod 644 "$target_file"
    sudo chown root:root "$target_file"
    
    log_success "Kernel modules configuration installed to: $target_file"
    return 0
}

install_power_management_script() {
    local script_file="${SCRIPT_DIR}/scripts/setup-power-management.sh"
    local target_file="/usr/local/bin/setup-power-management.sh"
    
    log_info "Installing power management setup script..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install power management script from $script_file to $target_file"
        return 0
    fi
    
    # Check if source script file exists
    if [[ ! -f "$script_file" ]]; then
        log_error "Power management script not found: $script_file"
        return 1
    fi
    
    # Create target directory if it doesn't exist
    sudo mkdir -p "$(dirname "$target_file")"
    
    # Install script
    sudo cp "$script_file" "$target_file"
    sudo chmod 755 "$target_file"
    sudo chown root:root "$target_file"
    
    log_success "Power management script installed to: $target_file"
    return 0
}

configure_power_management_services() {
    log_info "Configuring power management services..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would configure power management services"
        return 0
    fi
    
    # Check AMD P-state EPP support
    check_and_configure_amd_pstate || log_warn "AMD P-state configuration may have issues"
    
    # Configure power management based on available tools
    configure_power_management_priority || log_warn "Power management service configuration may have issues"
    
    return 0
}

check_and_configure_amd_pstate() {
    log_info "Checking AMD P-state EPP support..."
    
    # Check if this is an AMD CPU
    if ! grep -q "AMD" /proc/cpuinfo; then
        log_warn "Non-AMD CPU detected, skipping AMD P-state configuration"
        return 0
    fi
    
    # Check if amd-pstate driver is available
    if ! modinfo amd_pstate &>/dev/null; then
        log_warn "AMD P-state driver module not available"
        return 1
    fi
    
    # Check current kernel parameters
    local current_params=$(cat /proc/cmdline)
    log_info "Current kernel parameters: $current_params"
    
    if echo "$current_params" | grep -q "amd_pstate=active"; then
        log_success "AMD P-state already active in kernel parameters"
        return 0
    else
        log_info "AMD P-state not active, will be configured by power management script"
        log_warn "A reboot will be required after running the power management script"
        return 0
    fi
}

configure_power_management_priority() {
    log_info "Configuring power management service priority..."
    
    # Determine which power management solution to prioritize
    # Priority: auto-cpufreq > TLP > power-profiles-daemon
    
    local power_mgmt_tool=""
    
    if pacman -Qi auto-cpufreq &>/dev/null; then
        power_mgmt_tool="auto-cpufreq"
        log_info "auto-cpufreq detected, will be used as primary power management tool"
    elif pacman -Qi tlp &>/dev/null; then
        power_mgmt_tool="tlp"
        log_info "TLP detected, will be used as primary power management tool"
    elif pacman -Qi power-profiles-daemon &>/dev/null; then
        power_mgmt_tool="power-profiles-daemon"
        log_info "power-profiles-daemon detected, will be used as primary power management tool"
    else
        log_warn "No supported power management tools detected"
        return 1
    fi
    
    # The actual service configuration will be handled by the power management script
    log_info "Power management tool priority set to: $power_mgmt_tool"
    log_info "Run 'sudo /usr/local/bin/setup-power-management.sh' to configure services"
    
    return 0
}

setup_gpu_switching() {
    log_info "GPU switching setup will be implemented in task 5"
    # Placeholder for task 5 implementation
}

# ASUS-specific hardware integration functions
install_asus_files() {
    log_info "Installing ASUS configuration files and scripts..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install ASUS files"
        return 0
    fi
    
    local config_dir="${SCRIPT_DIR}/configs"
    local scripts_dir="${SCRIPT_DIR}/scripts"
    
    # Install ASUS configuration files
    if [[ -d "$config_dir/asus" ]]; then
        log_info "Installing ASUS configuration files..."
        sudo mkdir -p "/etc/asus"
        
        # Copy ASUS config files
        for config_file in "$config_dir/asus"/*.conf; do
            if [[ -f "$config_file" ]]; then
                local filename=$(basename "$config_file")
                sudo cp "$config_file" "/etc/asus/$filename"
                sudo chmod 644 "/etc/asus/$filename"
                log_success "Installed ASUS config: $filename"
            fi
        done
    fi
    
    # Install ASUS setup script
    local asus_setup_script="$scripts_dir/setup-asus-tools.sh"
    if [[ -f "$asus_setup_script" ]]; then
        log_info "Installing ASUS setup script..."
        sudo cp "$asus_setup_script" "/usr/local/bin/setup-asus-tools.sh"
        sudo chmod +x "/usr/local/bin/setup-asus-tools.sh"
        log_success "ASUS setup script installed to /usr/local/bin/"
    fi
    
    # Install ASUS test script
    local asus_test_script="$scripts_dir/test-asus-tools.sh"
    if [[ -f "$asus_test_script" ]]; then
        log_info "Installing ASUS test script..."
        sudo cp "$asus_test_script" "/usr/local/bin/test-asus-tools.sh"
        sudo chmod +x "/usr/local/bin/test-asus-tools.sh"
        log_success "ASUS test script installed to /usr/local/bin/"
    fi
    
    # Install ASUS udev rules
    local asus_udev_rule="$config_dir/udev/83-asus-hardware.rules"
    if [[ -f "$asus_udev_rule" ]]; then
        log_info "Installing ASUS hardware detection udev rule..."
        sudo cp "$asus_udev_rule" "/etc/udev/rules.d/"
        sudo chmod 644 "/etc/udev/rules.d/83-asus-hardware.rules"
        
        # Reload udev rules
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        
        log_success "ASUS udev rule installed and activated"
    fi
    
    # Install ASUS systemd service
    local asus_service="$config_dir/systemd/asus-hardware.service"
    if [[ -f "$asus_service" ]]; then
        log_info "Installing ASUS hardware service..."
        sudo cp "$asus_service" "/etc/systemd/system/"
        sudo chmod 644 "/etc/systemd/system/asus-hardware.service"
        sudo systemctl daemon-reload
        log_success "ASUS hardware service installed"
    fi
    
    log_success "ASUS files installation completed"
    return 0
}

configure_asusctl() {
    log_info "Configuring asusctl for hardware control..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would configure asusctl"
        return 0
    fi
    
    # Check if asusctl is installed
    if ! command -v asusctl &>/dev/null; then
        log_error "asusctl is not installed. Please install it first."
        return 1
    fi
    
    # Enable and start asusd service
    log_info "Enabling asusd service..."
    if ! sudo systemctl enable asusd.service; then
        log_error "Failed to enable asusd service"
        return 1
    fi
    
    if ! sudo systemctl start asusd.service; then
        log_warn "Failed to start asusd service (may require reboot)"
    fi
    
    # Configure LED settings (if supported)
    log_info "Configuring LED settings..."
    if asusctl led-mode static &>/dev/null; then
        log_success "LED mode set to static"
    else
        log_debug "LED configuration not supported or failed"
    fi
    
    # Configure fan profiles
    log_info "Setting up fan profiles..."
    if asusctl profile -l &>/dev/null; then
        # Set balanced profile as default
        if asusctl profile -P balanced &>/dev/null; then
            log_success "Fan profile set to balanced"
        else
            log_debug "Failed to set fan profile"
        fi
    else
        log_debug "Fan profile configuration not supported"
    fi
    
    # Configure keyboard backlight
    log_info "Configuring keyboard backlight..."
    if asusctl -k med &>/dev/null; then
        log_success "Keyboard backlight set to medium"
    else
        log_debug "Keyboard backlight configuration not supported"
    fi
    
    log_success "asusctl configuration completed"
    return 0
}

configure_supergfxctl() {
    log_info "Configuring supergfxctl for advanced GPU management..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would configure supergfxctl"
        return 0
    fi
    
    # Check if supergfxctl is installed
    if ! command -v supergfxctl &>/dev/null; then
        log_error "supergfxctl is not installed. Please install it first."
        return 1
    fi
    
    # Enable and start supergfxd service
    log_info "Enabling supergfxd service..."
    if ! sudo systemctl enable supergfxd.service; then
        log_error "Failed to enable supergfxd service"
        return 1
    fi
    
    if ! sudo systemctl start supergfxd.service; then
        log_warn "Failed to start supergfxd service (may require reboot)"
    fi
    
    # Set GPU mode to hybrid for optimal battery life with dGPU availability
    log_info "Setting GPU mode to hybrid..."
    if supergfxctl -m hybrid &>/dev/null; then
        log_success "GPU mode set to hybrid"
    else
        log_warn "Failed to set GPU mode to hybrid, may require reboot"
    fi
    
    # Check current GPU status
    log_info "Checking GPU status..."
    local gpu_status=$(supergfxctl -g 2>/dev/null || echo "unknown")
    log_info "Current GPU mode: $gpu_status"
    
    # Configure power management for dGPU
    log_info "Configuring dGPU power management..."
    if supergfxctl -P &>/dev/null; then
        log_success "dGPU power management configured"
    else
        log_debug "dGPU power management configuration not available"
    fi
    
    log_success "supergfxctl configuration completed"
    return 0
}

configure_rog_control_center() {
    log_info "Configuring rog-control-center GUI application..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would configure rog-control-center"
        return 0
    fi
    
    # Check if rog-control-center is installed
    if ! command -v rog-control-center &>/dev/null; then
        log_error "rog-control-center is not installed. Please install it first."
        return 1
    fi
    
    # Create desktop entry if it doesn't exist
    local desktop_file="/usr/share/applications/rog-control-center.desktop"
    if [[ ! -f "$desktop_file" ]]; then
        log_info "Creating desktop entry for rog-control-center..."
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
        log_success "Desktop entry created for rog-control-center"
    fi
    
    # Configure autostart (optional)
    local autostart_dir="$HOME/.config/autostart"
    local autostart_file="$autostart_dir/rog-control-center.desktop"
    
    if confirm_action "Enable rog-control-center autostart?" "n"; then
        mkdir -p "$autostart_dir"
        cp "$desktop_file" "$autostart_file"
        log_success "rog-control-center autostart enabled"
    fi
    
    # Set up user permissions for hardware access
    log_info "Configuring user permissions for hardware access..."
    local current_user=$(whoami)
    
    # Add user to input group for keyboard control
    if ! groups "$current_user" | grep -q "input"; then
        sudo usermod -a -G input "$current_user"
        log_success "User added to input group"
    fi
    
    log_success "rog-control-center configuration completed"
    log_info "Note: You may need to log out and back in for group changes to take effect"
    return 0
}

configure_switcheroo_control() {
    log_info "Configuring switcheroo-control for seamless GPU switching..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would configure switcheroo-control"
        return 0
    fi
    
    # Check if switcheroo-control is installed
    if ! command -v switcherooctl &>/dev/null; then
        log_error "switcheroo-control is not installed. Please install it first."
        return 1
    fi
    
    # Enable and start switcheroo-control service
    log_info "Enabling switcheroo-control service..."
    if ! sudo systemctl enable switcheroo-control.service; then
        log_error "Failed to enable switcheroo-control service"
        return 1
    fi
    
    if ! sudo systemctl start switcheroo-control.service; then
        log_warn "Failed to start switcheroo-control service (may require reboot)"
    fi
    
    # Check available GPUs
    log_info "Checking available GPUs for switching..."
    if switcherooctl list &>/dev/null; then
        local gpu_list=$(switcherooctl list 2>/dev/null || echo "No GPUs detected")
        log_info "Available GPUs:"
        echo "$gpu_list" | while read -r line; do
            log_info "  $line"
        done
    else
        log_warn "Could not list available GPUs"
    fi
    
    # Create GPU switching helper script
    local switch_script="${SCRIPT_DIR}/scripts/gpu-switch"
    log_info "Creating GPU switching helper script..."
    
    cat > "$switch_script" << 'EOF'
#!/bin/bash
# GPU switching helper script using switcheroo-control

set -euo pipefail

show_usage() {
    echo "Usage: $0 [integrated|discrete|auto]"
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
    log_success "GPU switching helper script created at: $switch_script"
    
    # Create udev rule for automatic GPU switching based on power state
    local udev_rule="/etc/udev/rules.d/82-gpu-power-switch.rules"
    log_info "Creating udev rule for automatic GPU switching..."
    
    sudo tee "$udev_rule" > /dev/null << 'EOF'
# Automatic GPU switching based on power state
# Switch to integrated GPU when on battery, allow discrete when on AC

# On battery power - prefer integrated GPU
SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="/usr/bin/switcherooctl switch integrated"

# On AC power - allow auto switching
SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="/usr/bin/switcherooctl switch auto"
EOF
    
    sudo chmod 644 "$udev_rule"
    log_success "Udev rule created for automatic GPU switching"
    
    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    log_success "switcheroo-control configuration completed"
    return 0
}

enable_asus_services() {
    log_info "Enabling ASUS-related system services..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would enable ASUS services"
        return 0
    fi
    
    local services=(
        "asusd.service"
        "supergfxd.service"
        "switcheroo-control.service"
        "power-profiles-daemon.service"
    )
    
    local failed_services=()
    
    for service in "${services[@]}"; do
        log_info "Enabling $service..."
        
        # Check if service exists
        if ! systemctl list-unit-files | grep -q "^$service"; then
            log_warn "Service $service not found, skipping..."
            continue
        fi
        
        # Enable service
        if sudo systemctl enable "$service" &>/dev/null; then
            log_success "Enabled $service"
            
            # Try to start service (may fail if hardware not supported)
            if sudo systemctl start "$service" &>/dev/null; then
                log_success "Started $service"
            else
                log_warn "Failed to start $service (may require reboot or hardware support)"
            fi
        else
            log_error "Failed to enable $service"
            failed_services+=("$service")
        fi
    done
    
    # Configure power-profiles-daemon default profile
    if systemctl is-active power-profiles-daemon.service &>/dev/null; then
        log_info "Setting default power profile to balanced..."
        if command -v powerprofilesctl &>/dev/null; then
            if powerprofilesctl set balanced &>/dev/null; then
                log_success "Power profile set to balanced"
            else
                log_debug "Failed to set power profile"
            fi
        fi
    fi
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_warn "Some services failed to enable: ${failed_services[*]}"
        return 1
    else
        log_success "All ASUS services enabled successfully"
        return 0
    fi
}

setup_asus_tools() {
    log_info "=== Setting up ASUS-specific hardware integration ==="
    
    # Install ASUS configuration files and scripts
    install_asus_files || log_warn "Failed to install ASUS files"
    
    # Configure asusctl for hardware control
    configure_asusctl || log_warn "Failed to configure asusctl"
    
    # Set up supergfxctl for advanced GPU management
    configure_supergfxctl || log_warn "Failed to configure supergfxctl"
    
    # Configure rog-control-center GUI application
    configure_rog_control_center || log_warn "Failed to configure rog-control-center"
    
    # Implement switcheroo-control for seamless GPU switching
    configure_switcheroo_control || log_warn "Failed to configure switcheroo-control"
    
    # Enable and start ASUS-related services
    enable_asus_services || log_warn "Failed to enable ASUS services"
    
    log_success "=== ASUS hardware integration setup completed ==="
    log_info "Note: Some ASUS tools may require a reboot to function properly"
    
    return 0
}

setup_system_services() {
    log_info "=== Setting up System Configuration and Services ==="
    
    # Install kernel module configurations
    install_kernel_module_configs || log_warn "Failed to install kernel module configurations"
    
    # Install systemd service configurations
    install_systemd_services || log_warn "Failed to install systemd services"
    
    # Update initramfs with new configurations
    update_initramfs || log_warn "Failed to update initramfs"
    
    # Update GRUB configuration
    update_grub_config || log_warn "Failed to update GRUB configuration"
    
    # Enable and configure system services
    enable_system_services || log_warn "Failed to enable system services"
    
    log_success "=== System configuration and services setup completed ==="
    log_info "Note: A reboot is recommended to apply all kernel and service changes"
    
    return 0
}

# Configuration backup functions
create_pre_setup_backup() {
    log_info "Creating pre-setup configuration backup..."
    
    local backup_script="${SCRIPT_DIR}/scripts/config-backup.sh"
    
    if [[ ! -f "$backup_script" ]]; then
        log_warn "Backup script not found, skipping backup creation"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create pre-setup backup"
        return 0
    fi
    
    # Create backup with descriptive name
    local backup_description="Pre-setup backup - $(date '+%Y-%m-%d %H:%M:%S')"
    
    if "$backup_script" backup "$backup_description" >/dev/null 2>&1; then
        log_success "Pre-setup backup created successfully"
        export BACKUP_CREATED=true
    else
        log_warn "Failed to create pre-setup backup, continuing anyway"
        export BACKUP_CREATED=false
    fi
}

offer_backup_restore() {
    log_info "Setup encountered an error. Checking for available backups..."
    
    local backup_script="${SCRIPT_DIR}/scripts/config-backup.sh"
    
    if [[ ! -f "$backup_script" ]]; then
        log_warn "Backup script not found, cannot offer restore"
        return 0
    fi
    
    # Check if we created a backup during this session
    if [[ "${BACKUP_CREATED:-false}" == true ]]; then
        echo
        log_warn "A backup was created before setup began."
        
        if confirm_action "Would you like to restore the pre-setup backup?"; then
            log_info "Restoring pre-setup backup..."
            
            # Get the most recent backup
            local latest_backup
            latest_backup=$("$backup_script" list 2>/dev/null | grep "Backup:" | head -1 | cut -d' ' -f2 || echo "")
            
            if [[ -n "$latest_backup" ]]; then
                if "$backup_script" --force restore "$latest_backup"; then
                    log_success "Configuration restored from backup"
                    log_info "System has been restored to pre-setup state"
                else
                    log_error "Failed to restore backup"
                fi
            else
                log_error "Could not identify backup to restore"
            fi
        fi
    else
        log_info "No backup was created during this session"
    fi
}

# Enhanced error handling with backup restore option
enhanced_error_exit() {
    local error_message="$1"
    local exit_code="${2:-1}"
    
    log_error "$error_message"
    log_error "Setup failed. Check the log file: $LOG_FILE"
    
    # Offer backup restore if available
    offer_backup_restore
    
    exit "$exit_code"
}

# Main execution function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            --log-dir)
                if [[ -n "${2:-}" ]]; then
                    LOG_DIR="$2"
                    LOG_FILE="${LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"
                    shift 2
                else
                    error_exit "Error: --log-dir requires a directory path"
                fi
                ;;
            --no-backup)
                SKIP_BACKUP=true
                shift
                ;;
            *)
                error_exit "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
    
    # Initialize
    initialize_logging
    show_banner
    
    log_info "Starting system validation..."
    
    # System checks
    check_arch_linux
    check_root_privileges
    check_internet_connection
    check_hardware_compatibility
    
    log_success "System validation completed"
    
    # Create pre-setup backup unless disabled
    if [[ "${SKIP_BACKUP:-false}" != true ]]; then
        create_pre_setup_backup
    else
        log_info "Backup creation skipped (--no-backup flag used)"
        export BACKUP_CREATED=false
    fi
    
    # Show configuration summary
    log_info "Configuration Summary:"
    log_info "  Verbose mode: $VERBOSE"
    log_info "  Dry run mode: $DRY_RUN"
    log_info "  Force mode: $FORCE"
    log_info "  Log directory: $LOG_DIR"
    
    # Confirm before proceeding
    if [[ "$FORCE" != true ]] && [[ "$DRY_RUN" != true ]]; then
        echo
        log_info "This script will modify your system configuration for optimal hybrid GPU operation."
        log_info "The following changes will be made:"
        log_info "  - Install GPU drivers and power management tools"
        log_info "  - Configure Xorg for hybrid GPU setup"
        log_info "  - Set up power management profiles"
        log_info "  - Install and configure ASUS-specific tools"
        log_info "  - Configure system services and kernel modules"
        echo
        
        if ! confirm_action "Do you want to continue with the setup?"; then
            log_info "Setup cancelled by user"
            exit 0
        fi
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "=== DRY RUN MODE - No changes will be made ==="
    fi
    
    # Main setup sequence (placeholders for future implementation)
    log_info "Starting setup process..."
    
    setup_packages
    setup_xorg
    setup_power_management
    setup_gpu_switching
    setup_asus_tools
    setup_system_services
    
    # Completion
    log_success "=== Setup completed successfully ==="
    log_info "Log file saved to: $LOG_FILE"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Reboot your system to apply all changes"
    log_info "  2. Test GPU switching with: prime-run glxinfo | grep 'OpenGL renderer'"
    log_info "  3. Check power management with: sudo powertop"
    log_info "  4. Review the documentation in the docs/ directory"
    log_info ""
    log_info "For troubleshooting, run: ./scripts/troubleshoot.sh"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
# Sy
stem configuration functions for task 7

install_kernel_module_configs() {
    log_info "Installing kernel module configurations..."
    
    local modules_dir="${SCRIPT_DIR}/configs/modules"
    local target_dir="/etc/modprobe.d"
    local installed_configs=()
    local failed_configs=()
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install kernel module configurations"
        return 0
    fi
    
    # Create target directory if it doesn't exist
    sudo mkdir -p "$target_dir"
    
    # Install each module configuration file
    for config_file in "$modules_dir"/*.conf; do
        if [[ -f "$config_file" ]]; then
            local filename=$(basename "$config_file")
            local target_file="$target_dir/$filename"
            
            log_info "Installing module config: $filename"
            
            # Backup existing configuration if it exists
            if [[ -f "$target_file" ]]; then
                local backup_file="${target_file}.backup-$(date +%Y%m%d_%H%M%S)"
                sudo cp "$target_file" "$backup_file"
                log_debug "Backed up existing config to: $backup_file"
            fi
            
            # Install new configuration
            if sudo cp "$config_file" "$target_file"; then
                sudo chmod 644 "$target_file"
                sudo chown root:root "$target_file"
                installed_configs+=("$filename")
                log_success "Installed: $filename"
            else
                failed_configs+=("$filename")
                log_error "Failed to install: $filename"
            fi
        fi
    done
    
    # Report results
    if [[ ${#installed_configs[@]} -gt 0 ]]; then
        log_success "Installed kernel module configurations: ${installed_configs[*]}"
    fi
    
    if [[ ${#failed_configs[@]} -gt 0 ]]; then
        log_warn "Failed to install some configurations: ${failed_configs[*]}"
        return 1
    fi
    
    return 0
}

install_systemd_services() {
    log_info "Installing systemd service configurations..."
    
    local systemd_dir="${SCRIPT_DIR}/configs/systemd"
    local target_dir="/etc/systemd/system"
    local installed_services=()
    local failed_services=()
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install systemd service configurations"
        return 0
    fi
    
    # Install NVIDIA suspend handler script first
    install_nvidia_suspend_handler || log_warn "Failed to install NVIDIA suspend handler script"
    
    # Create target directory if it doesn't exist
    sudo mkdir -p "$target_dir"
    
    # Install each service file
    for service_file in "$systemd_dir"/*.service; do
        if [[ -f "$service_file" ]]; then
            local filename=$(basename "$service_file")
            local target_file="$target_dir/$filename"
            
            log_info "Installing systemd service: $filename"
            
            # Backup existing service if it exists
            if [[ -f "$target_file" ]]; then
                local backup_file="${target_file}.backup-$(date +%Y%m%d_%H%M%S)"
                sudo cp "$target_file" "$backup_file"
                log_debug "Backed up existing service to: $backup_file"
            fi
            
            # Install new service
            if sudo cp "$service_file" "$target_file"; then
                sudo chmod 644 "$target_file"
                sudo chown root:root "$target_file"
                installed_services+=("$filename")
                log_success "Installed: $filename"
            else
                failed_services+=("$filename")
                log_error "Failed to install: $filename"
            fi
        fi
    done
    
    # Reload systemd daemon to recognize new services
    if [[ ${#installed_services[@]} -gt 0 ]]; then
        log_info "Reloading systemd daemon..."
        if sudo systemctl daemon-reload; then
            log_success "Systemd daemon reloaded successfully"
        else
            log_warn "Failed to reload systemd daemon"
        fi
    fi
    
    # Report results
    if [[ ${#installed_services[@]} -gt 0 ]]; then
        log_success "Installed systemd services: ${installed_services[*]}"
    fi
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_warn "Failed to install some services: ${failed_services[*]}"
        return 1
    fi
    
    return 0
}

update_initramfs() {
    log_info "Updating initramfs with new kernel module configurations..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would update initramfs"
        return 0
    fi
    
    # Check if mkinitcpio is available
    if ! command -v mkinitcpio &>/dev/null; then
        log_error "mkinitcpio not found. Cannot update initramfs."
        return 1
    fi
    
    # Update initramfs for all installed kernels
    log_info "Regenerating initramfs for all kernels..."
    
    # Get list of installed kernels
    local kernels=($(ls /lib/modules/ 2>/dev/null | grep -E '^[0-9]+\.[0-9]+'))
    
    if [[ ${#kernels[@]} -eq 0 ]]; then
        log_warn "No kernels found in /lib/modules/"
        # Try the generic approach
        if sudo mkinitcpio -P; then
            log_success "Initramfs updated successfully (generic)"
            return 0
        else
            log_error "Failed to update initramfs"
            return 1
        fi
    fi
    
    local failed_kernels=()
    local success_kernels=()
    
    # Update initramfs for each kernel
    for kernel in "${kernels[@]}"; do
        log_info "Updating initramfs for kernel: $kernel"
        
        if sudo mkinitcpio -k "$kernel" -g "/boot/initramfs-${kernel}.img"; then
            success_kernels+=("$kernel")
            log_success "Updated initramfs for kernel: $kernel"
        else
            failed_kernels+=("$kernel")
            log_warn "Failed to update initramfs for kernel: $kernel"
        fi
    done
    
    # Try the preset approach as fallback
    if [[ ${#failed_kernels[@]} -gt 0 ]]; then
        log_info "Trying preset-based initramfs update as fallback..."
        if sudo mkinitcpio -P; then
            log_success "Initramfs updated successfully using presets"
            return 0
        fi
    fi
    
    # Report results
    if [[ ${#success_kernels[@]} -gt 0 ]]; then
        log_success "Successfully updated initramfs for kernels: ${success_kernels[*]}"
    fi
    
    if [[ ${#failed_kernels[@]} -gt 0 ]]; then
        log_warn "Failed to update initramfs for kernels: ${failed_kernels[*]}"
        return 1
    fi
    
    return 0
}

update_grub_config() {
    log_info "Updating GRUB configuration..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would update GRUB configuration"
        return 0
    fi
    
    # Check if GRUB is installed and configured
    if [[ ! -f "/etc/default/grub" ]]; then
        log_warn "GRUB configuration file not found at /etc/default/grub"
        log_warn "Skipping GRUB configuration update"
        return 0
    fi
    
    if ! command -v grub-mkconfig &>/dev/null; then
        log_warn "grub-mkconfig not found. Cannot update GRUB configuration."
        return 0
    fi
    
    # Backup current GRUB configuration
    local grub_config="/etc/default/grub"
    local backup_file="${grub_config}.backup-$(date +%Y%m%d_%H%M%S)"
    
    if sudo cp "$grub_config" "$backup_file"; then
        log_info "Backed up GRUB config to: $backup_file"
    else
        log_warn "Failed to backup GRUB configuration"
    fi
    
    # Check and update GRUB parameters for better hybrid GPU support
    local grub_updated=false
    local temp_grub="/tmp/grub_temp"
    
    # Copy current config to temp file
    cp "$grub_config" "$temp_grub"
    
    # Add or update kernel parameters for better power management and GPU support
    local kernel_params="amd_pstate=active amdgpu.ppfeaturemask=0xffffffff nvidia-drm.modeset=1"
    
    # Check if GRUB_CMDLINE_LINUX_DEFAULT exists and update it
    if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$temp_grub"; then
        # Get current parameters
        local current_params=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$temp_grub" | sed 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/\1/')
        
        # Add new parameters if they don't exist
        local updated_params="$current_params"
        
        for param in $kernel_params; do
            local param_name=$(echo "$param" | cut -d'=' -f1)
            if ! echo "$current_params" | grep -q "$param_name"; then
                updated_params="$updated_params $param"
                grub_updated=true
                log_info "Adding kernel parameter: $param"
            fi
        done
        
        # Update the line if parameters were added
        if [[ "$grub_updated" == true ]]; then
            sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$updated_params\"|" "$temp_grub"
        fi
    else
        # Add the line if it doesn't exist
        echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$kernel_params\"" >> "$temp_grub"
        grub_updated=true
        log_info "Added GRUB_CMDLINE_LINUX_DEFAULT with parameters: $kernel_params"
    fi
    
    # Install updated configuration if changes were made
    if [[ "$grub_updated" == true ]]; then
        if sudo cp "$temp_grub" "$grub_config"; then
            log_success "Updated GRUB configuration with new kernel parameters"
        else
            log_error "Failed to update GRUB configuration"
            rm -f "$temp_grub"
            return 1
        fi
    else
        log_info "GRUB configuration already contains required parameters"
    fi
    
    # Clean up temp file
    rm -f "$temp_grub"
    
    # Regenerate GRUB configuration
    log_info "Regenerating GRUB configuration..."
    
    # Determine the correct GRUB config path
    local grub_cfg_path=""
    if [[ -d "/boot/grub" ]]; then
        grub_cfg_path="/boot/grub/grub.cfg"
    elif [[ -d "/boot/grub2" ]]; then
        grub_cfg_path="/boot/grub2/grub.cfg"
    else
        log_warn "Could not determine GRUB configuration directory"
        return 1
    fi
    
    # Generate new GRUB configuration
    if sudo grub-mkconfig -o "$grub_cfg_path"; then
        log_success "GRUB configuration regenerated successfully"
        return 0
    else
        log_error "Failed to regenerate GRUB configuration"
        return 1
    fi
}

enable_system_services() {
    log_info "Enabling and configuring system services..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would enable and configure system services"
        return 0
    fi
    
    # Define services to enable
    local services_to_enable=(
        "nvidia-suspend.service"
        "nvidia-resume.service"
        "asus-hardware.service"
        "power-management.service"
        "tlp.service"
        "auto-cpufreq.service"
        "power-profiles-daemon.service"
    )
    
    local enabled_services=()
    local failed_services=()
    
    # Enable each service
    for service in "${services_to_enable[@]}"; do
        log_info "Enabling service: $service"
        
        # Check if service file exists
        if [[ -f "/etc/systemd/system/$service" ]] || systemctl list-unit-files | grep -q "^$service"; then
            if sudo systemctl enable "$service" 2>/dev/null; then
                enabled_services+=("$service")
                log_success "Enabled: $service"
            else
                failed_services+=("$service")
                log_warn "Failed to enable: $service (may not be installed)"
            fi
        else
            log_debug "Service not found, skipping: $service"
        fi
    done
    
    # Start services that should be running immediately
    local services_to_start=(
        "tlp.service"
        "auto-cpufreq.service"
        "power-profiles-daemon.service"
    )
    
    local started_services=()
    local failed_starts=()
    
    for service in "${services_to_start[@]}"; do
        if [[ " ${enabled_services[*]} " =~ " ${service} " ]]; then
            log_info "Starting service: $service"
            
            if sudo systemctl start "$service" 2>/dev/null; then
                started_services+=("$service")
                log_success "Started: $service"
            else
                failed_starts+=("$service")
                log_warn "Failed to start: $service"
            fi
        fi
    done
    
    # Configure service dependencies and conflicts
    configure_service_dependencies
    
    # Report results
    if [[ ${#enabled_services[@]} -gt 0 ]]; then
        log_success "Enabled services: ${enabled_services[*]}"
    fi
    
    if [[ ${#started_services[@]} -gt 0 ]]; then
        log_success "Started services: ${started_services[*]}"
    fi
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_warn "Failed to enable services: ${failed_services[*]}"
    fi
    
    if [[ ${#failed_starts[@]} -gt 0 ]]; then
        log_warn "Failed to start services: ${failed_starts[*]}"
    fi
    
    # Return success if at least some services were enabled
    if [[ ${#enabled_services[@]} -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

configure_service_dependencies() {
    log_info "Configuring service dependencies and conflicts..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would configure service dependencies"
        return 0
    fi
    
    # Disable conflicting services
    local conflicting_services=(
        "laptop-mode.service"
        "cpufrequtils.service"
        "thermald.service"  # May conflict with auto-cpufreq
    )
    
    for service in "${conflicting_services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            log_info "Disabling conflicting service: $service"
            if sudo systemctl disable "$service" 2>/dev/null; then
                log_success "Disabled conflicting service: $service"
            else
                log_warn "Failed to disable service: $service"
            fi
        fi
    done
    
    # Mask services that should never run
    local services_to_mask=(
        "nouveau.service"
    )
    
    for service in "${services_to_mask[@]}"; do
        if systemctl list-unit-files | grep -q "^$service"; then
            log_info "Masking service: $service"
            if sudo systemctl mask "$service" 2>/dev/null; then
                log_success "Masked service: $service"
            else
                log_warn "Failed to mask service: $service"
            fi
        fi
    done
    
    return 0
}# Install
 NVIDIA suspend handler script
install_nvidia_suspend_handler() {
    log_info "Installing NVIDIA suspend handler script..."
    
    local source_script="${SCRIPT_DIR}/scripts/nvidia-suspend-handler.sh"
    local target_script="/usr/local/bin/nvidia-suspend-handler.sh"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install NVIDIA suspend handler to $target_script"
        return 0
    fi
    
    # Check if source script exists
    if [[ ! -f "$source_script" ]]; then
        log_error "NVIDIA suspend handler script not found: $source_script"
        return 1
    fi
    
    # Create target directory if it doesn't exist
    sudo mkdir -p "$(dirname "$target_script")"
    
    # Install the script
    if sudo cp "$source_script" "$target_script"; then
        # Make it executable
        sudo chmod +x "$target_script"
        sudo chown root:root "$target_script"
        log_success "Installed NVIDIA suspend handler to: $target_script"
        return 0
    else
        log_error "Failed to install NVIDIA suspend handler script"
        return 1
    fi
}