#!/bin/bash

# Error Recovery Mechanisms for ASUS ROG Zephyrus G14 Setup
# Provides automated recovery procedures for common failures

set -euo pipefail

# Source error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"

readonly RECOVERY_VERSION="1.0.0"
readonly RECOVERY_LOG_FILE="${ERROR_LOG_DIR}/recovery.log"

# Recovery mechanism registry
declare -A RECOVERY_MECHANISMS=(
    ["package_install_failure"]="recover_package_install_failure"
    ["service_start_failure"]="recover_service_start_failure"
    ["gpu_driver_failure"]="recover_gpu_driver_failure"
    ["xorg_config_failure"]="recover_xorg_config_failure"
    ["power_management_failure"]="recover_power_management_failure"
    ["asus_tools_failure"]="recover_asus_tools_failure"
    ["network_failure"]="recover_network_failure"
    ["disk_space_failure"]="recover_disk_space_failure"
    ["permission_failure"]="recover_permission_failure"
    ["config_corruption"]="recover_config_corruption"
)

# Initialize recovery system
init_recovery_system() {
    log_info "Initializing error recovery system (v${RECOVERY_VERSION})"
    
    # Ensure recovery log exists
    sudo mkdir -p "$(dirname "$RECOVERY_LOG_FILE")"
    sudo touch "$RECOVERY_LOG_FILE"
    sudo chmod 644 "$RECOVERY_LOG_FILE"
    
    log_success "Error recovery system initialized"
}

# Log recovery attempt
log_recovery() {
    local recovery_type="$1"
    local status="$2"
    local details="${3:-}"
    local timestamp=$(date -Iseconds)
    
    echo "[$timestamp] RECOVERY: $recovery_type - $status - $details" | sudo tee -a "$RECOVERY_LOG_FILE" >/dev/null
}

# Package installation failure recovery
recover_package_install_failure() {
    local package="${1:-unknown}"
    local error_details="${2:-}"
    
    log_info "Attempting package installation recovery for: $package"
    log_recovery "package_install" "started" "$package"
    
    local recovery_steps=0
    local successful_steps=0
    
    # Step 1: Update package database
    ((recovery_steps++))
    log_info "Step 1: Updating package database..."
    if sudo pacman -Sy; then
        log_success "Package database updated"
        ((successful_steps++))
    else
        log_warn "Failed to update package database"
    fi
    
    # Step 2: Clear package cache
    ((recovery_steps++))
    log_info "Step 2: Clearing package cache..."
    if sudo pacman -Scc --noconfirm; then
        log_success "Package cache cleared"
        ((successful_steps++))
    else
        log_warn "Failed to clear package cache"
    fi
    
    # Step 3: Update keyring
    ((recovery_steps++))
    log_info "Step 3: Updating keyring..."
    if sudo pacman -S --noconfirm archlinux-keyring; then
        log_success "Keyring updated"
        ((successful_steps++))
    else
        log_warn "Failed to update keyring"
    fi
    
    # Step 4: Fix broken packages
    ((recovery_steps++))
    log_info "Step 4: Checking for broken packages..."
    if sudo pacman -Dk; then
        log_success "No broken packages found"
        ((successful_steps++))
    else
        log_warn "Broken packages detected, attempting repair..."
        if sudo pacman -S --noconfirm $(pacman -Qkq 2>/dev/null | head -10); then
            log_success "Package repair attempted"
            ((successful_steps++))
        else
            log_warn "Package repair failed"
        fi
    fi
    
    # Step 5: Retry package installation
    if [[ -n "$package" && "$package" != "unknown" ]]; then
        ((recovery_steps++))
        log_info "Step 5: Retrying package installation: $package"
        if sudo pacman -S --noconfirm "$package"; then
            log_success "Package installation successful after recovery"
            ((successful_steps++))
        else
            log_error "Package installation still failing after recovery"
        fi
    fi
    
    local success_rate=$((successful_steps * 100 / recovery_steps))
    log_info "Package recovery completed: $successful_steps/$recovery_steps steps successful ($success_rate%)"
    
    if [[ $success_rate -ge 80 ]]; then
        log_recovery "package_install" "success" "$package - $success_rate% success rate"
        return 0
    else
        log_recovery "package_install" "partial" "$package - $success_rate% success rate"
        return 1
    fi
}

# Service start failure recovery
recover_service_start_failure() {
    local service="${1:-unknown}"
    local error_details="${2:-}"
    
    log_info "Attempting service recovery for: $service"
    log_recovery "service_start" "started" "$service"
    
    local recovery_steps=0
    local successful_steps=0
    
    # Step 1: Stop service
    ((recovery_steps++))
    log_info "Step 1: Stopping service: $service"
    if sudo systemctl stop "$service" 2>/dev/null; then
        log_success "Service stopped"
        ((successful_steps++))
    else
        log_debug "Service was not running"
        ((successful_steps++))
    fi
    
    # Step 2: Reset failed state
    ((recovery_steps++))
    log_info "Step 2: Resetting failed state: $service"
    if sudo systemctl reset-failed "$service" 2>/dev/null; then
        log_success "Failed state reset"
        ((successful_steps++))
    else
        log_debug "No failed state to reset"
        ((successful_steps++))
    fi
    
    # Step 3: Reload systemd
    ((recovery_steps++))
    log_info "Step 3: Reloading systemd daemon"
    if sudo systemctl daemon-reload; then
        log_success "Systemd daemon reloaded"
        ((successful_steps++))
    else
        log_warn "Failed to reload systemd daemon"
    fi
    
    # Step 4: Check service dependencies
    ((recovery_steps++))
    log_info "Step 4: Checking service dependencies"
    local deps_ok=true
    local dependencies=$(systemctl list-dependencies "$service" --plain --no-pager 2>/dev/null | tail -n +2 | head -5)
    
    if [[ -n "$dependencies" ]]; then
        while IFS= read -r dep; do
            if [[ -n "$dep" ]]; then
                local dep_clean=$(echo "$dep" | sed 's/[^a-zA-Z0-9.-]//g')
                if ! systemctl is-active "$dep_clean" >/dev/null 2>&1; then
                    log_warn "Dependency not active: $dep_clean"
                    deps_ok=false
                fi
            fi
        done <<< "$dependencies"
    fi
    
    if [[ "$deps_ok" == true ]]; then
        log_success "Service dependencies are satisfied"
        ((successful_steps++))
    else
        log_warn "Some service dependencies are not satisfied"
    fi
    
    # Step 5: Start service
    ((recovery_steps++))
    log_info "Step 5: Starting service: $service"
    if sudo systemctl start "$service"; then
        log_success "Service started successfully"
        ((successful_steps++))
    else
        log_error "Service start still failing"
    fi
    
    # Step 6: Verify service status
    ((recovery_steps++))
    log_info "Step 6: Verifying service status"
    if systemctl is-active "$service" >/dev/null 2>&1; then
        log_success "Service is active and running"
        ((successful_steps++))
    else
        log_error "Service is not active after recovery attempt"
    fi
    
    local success_rate=$((successful_steps * 100 / recovery_steps))
    log_info "Service recovery completed: $successful_steps/$recovery_steps steps successful ($success_rate%)"
    
    if [[ $success_rate -ge 80 ]]; then
        log_recovery "service_start" "success" "$service - $success_rate% success rate"
        return 0
    else
        log_recovery "service_start" "partial" "$service - $success_rate% success rate"
        return 1
    fi
}

# GPU driver failure recovery
recover_gpu_driver_failure() {
    local gpu_type="${1:-both}"
    local error_details="${2:-}"
    
    log_info "Attempting GPU driver recovery for: $gpu_type"
    log_recovery "gpu_driver" "started" "$gpu_type"
    
    local recovery_steps=0
    local successful_steps=0
    
    # Step 1: Unload GPU modules
    ((recovery_steps++))
    log_info "Step 1: Unloading GPU kernel modules"
    local modules_to_unload=("nvidia_drm" "nvidia_modeset" "nvidia" "amdgpu" "radeon")
    local unload_success=true
    
    for module in "${modules_to_unload[@]}"; do
        if lsmod | grep -q "^$module"; then
            if sudo modprobe -r "$module" 2>/dev/null; then
                log_debug "Unloaded module: $module"
            else
                log_warn "Failed to unload module: $module"
                unload_success=false
            fi
        fi
    done
    
    if [[ "$unload_success" == true ]]; then
        ((successful_steps++))
    fi
    
    # Step 2: Wait for modules to unload
    ((recovery_steps++))
    log_info "Step 2: Waiting for modules to unload completely"
    sleep 3
    ((successful_steps++))
    
    # Step 3: Reload GPU modules
    ((recovery_steps++))
    log_info "Step 3: Reloading GPU kernel modules"
    local modules_to_load=("amdgpu" "nvidia" "nvidia_modeset" "nvidia_drm")
    local load_success=true
    
    for module in "${modules_to_load[@]}"; do
        if sudo modprobe "$module" 2>/dev/null; then
            log_debug "Loaded module: $module"
        else
            log_warn "Failed to load module: $module"
            load_success=false
        fi
    done
    
    if [[ "$load_success" == true ]]; then
        ((successful_steps++))
    fi
    
    # Step 4: Test NVIDIA functionality
    if [[ "$gpu_type" == "nvidia" || "$gpu_type" == "both" ]]; then
        ((recovery_steps++))
        log_info "Step 4: Testing NVIDIA functionality"
        if nvidia-smi >/dev/null 2>&1; then
            log_success "NVIDIA driver is responding"
            ((successful_steps++))
        else
            log_warn "NVIDIA driver is not responding properly"
        fi
    else
        ((recovery_steps++))
        ((successful_steps++))
    fi
    
    # Step 5: Test AMD functionality
    if [[ "$gpu_type" == "amd" || "$gpu_type" == "both" ]]; then
        ((recovery_steps++))
        log_info "Step 5: Testing AMD functionality"
        if lsmod | grep -q amdgpu && [[ -d /sys/class/drm/card0 ]]; then
            log_success "AMD driver is loaded and functional"
            ((successful_steps++))
        else
            log_warn "AMD driver may not be functioning properly"
        fi
    else
        ((recovery_steps++))
        ((successful_steps++))
    fi
    
    # Step 6: Restart display manager if needed
    ((recovery_steps++))
    log_info "Step 6: Checking display manager status"
    if systemctl is-active display-manager >/dev/null 2>&1; then
        log_info "Restarting display manager for GPU changes to take effect"
        if sudo systemctl restart display-manager; then
            log_success "Display manager restarted"
            ((successful_steps++))
        else
            log_warn "Failed to restart display manager"
        fi
    else
        log_debug "Display manager not running, skipping restart"
        ((successful_steps++))
    fi
    
    local success_rate=$((successful_steps * 100 / recovery_steps))
    log_info "GPU driver recovery completed: $successful_steps/$recovery_steps steps successful ($success_rate%)"
    
    if [[ $success_rate -ge 70 ]]; then
        log_recovery "gpu_driver" "success" "$gpu_type - $success_rate% success rate"
        return 0
    else
        log_recovery "gpu_driver" "partial" "$gpu_type - $success_rate% success rate"
        return 1
    fi
}

# Xorg configuration failure recovery
recover_xorg_config_failure() {
    local config_file="${1:-/etc/X11/xorg.conf.d/10-hybrid.conf}"
    local error_details="${2:-}"
    
    log_info "Attempting Xorg configuration recovery"
    log_recovery "xorg_config" "started" "$config_file"
    
    local recovery_steps=0
    local successful_steps=0
    
    # Step 1: Backup current config
    ((recovery_steps++))
    log_info "Step 1: Backing up current Xorg configuration"
    local backup_dir="/etc/X11/xorg.conf.d.recovery"
    if sudo mkdir -p "$backup_dir" && sudo cp -r /etc/X11/xorg.conf.d/* "$backup_dir/" 2>/dev/null; then
        log_success "Xorg configuration backed up"
        ((successful_steps++))
    else
        log_warn "Failed to backup Xorg configuration"
    fi
    
    # Step 2: Remove problematic config
    ((recovery_steps++))
    log_info "Step 2: Removing problematic configuration"
    if [[ -f "$config_file" ]]; then
        if sudo rm "$config_file"; then
            log_success "Problematic configuration removed"
            ((successful_steps++))
        else
            log_warn "Failed to remove problematic configuration"
        fi
    else
        log_debug "Configuration file doesn't exist"
        ((successful_steps++))
    fi
    
    # Step 3: Generate minimal working config
    ((recovery_steps++))
    log_info "Step 3: Generating minimal working configuration"
    local minimal_config="/etc/X11/xorg.conf.d/10-minimal-recovery.conf"
    
    if sudo tee "$minimal_config" >/dev/null << 'EOF'
Section "Device"
    Identifier "AMD"
    Driver "amdgpu"
    BusID "PCI:6:0:0"
    Option "TearFree" "true"
EndSection

Section "Screen"
    Identifier "AMD"
    Device "AMD"
EndSection
EOF
    then
        log_success "Minimal Xorg configuration created"
        ((successful_steps++))
    else
        log_warn "Failed to create minimal configuration"
    fi
    
    # Step 4: Test configuration syntax
    ((recovery_steps++))
    log_info "Step 4: Testing Xorg configuration syntax"
    if sudo Xorg -config "$minimal_config" -configtest 2>/dev/null; then
        log_success "Xorg configuration syntax is valid"
        ((successful_steps++))
    else
        log_warn "Xorg configuration syntax test failed"
    fi
    
    # Step 5: Restart display manager
    ((recovery_steps++))
    log_info "Step 5: Restarting display manager"
    if systemctl is-active display-manager >/dev/null 2>&1; then
        if sudo systemctl restart display-manager; then
            log_success "Display manager restarted"
            ((successful_steps++))
        else
            log_warn "Failed to restart display manager"
        fi
    else
        log_debug "Display manager not running"
        ((successful_steps++))
    fi
    
    local success_rate=$((successful_steps * 100 / recovery_steps))
    log_info "Xorg recovery completed: $successful_steps/$recovery_steps steps successful ($success_rate%)"
    
    if [[ $success_rate -ge 80 ]]; then
        log_recovery "xorg_config" "success" "$config_file - $success_rate% success rate"
        return 0
    else
        log_recovery "xorg_config" "partial" "$config_file - $success_rate% success rate"
        return 1
    fi
}

# Power management failure recovery
recover_power_management_failure() {
    local component="${1:-all}"
    local error_details="${2:-}"
    
    log_info "Attempting power management recovery for: $component"
    log_recovery "power_management" "started" "$component"
    
    local recovery_steps=0
    local successful_steps=0
    
    # Step 1: Stop conflicting services
    ((recovery_steps++))
    log_info "Step 1: Stopping conflicting power management services"
    local conflicting_services=("power-profiles-daemon" "laptop-mode-tools")
    local stop_success=true
    
    for service in "${conflicting_services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            if sudo systemctl stop "$service"; then
                log_debug "Stopped conflicting service: $service"
            else
                log_warn "Failed to stop service: $service"
                stop_success=false
            fi
        fi
    done
    
    if [[ "$stop_success" == true ]]; then
        ((successful_steps++))
    fi
    
    # Step 2: Restart TLP
    ((recovery_steps++))
    log_info "Step 2: Restarting TLP service"
    if sudo systemctl restart tlp; then
        log_success "TLP service restarted"
        ((successful_steps++))
    else
        log_warn "Failed to restart TLP service"
    fi
    
    # Step 3: Restart auto-cpufreq
    ((recovery_steps++))
    log_info "Step 3: Restarting auto-cpufreq service"
    if sudo systemctl restart auto-cpufreq; then
        log_success "auto-cpufreq service restarted"
        ((successful_steps++))
    else
        log_warn "Failed to restart auto-cpufreq service"
    fi
    
    # Step 4: Check CPU governor
    ((recovery_steps++))
    log_info "Step 4: Checking CPU governor settings"
    local current_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    if [[ "$current_governor" != "unknown" ]]; then
        log_success "CPU governor is active: $current_governor"
        ((successful_steps++))
    else
        log_warn "CPU governor not accessible"
    fi
    
    # Step 5: Test power management functionality
    ((recovery_steps++))
    log_info "Step 5: Testing power management functionality"
    if command -v tlp-stat >/dev/null 2>&1 && tlp-stat -s >/dev/null 2>&1; then
        log_success "TLP is functioning properly"
        ((successful_steps++))
    else
        log_warn "TLP functionality test failed"
    fi
    
    local success_rate=$((successful_steps * 100 / recovery_steps))
    log_info "Power management recovery completed: $successful_steps/$recovery_steps steps successful ($success_rate%)"
    
    if [[ $success_rate -ge 80 ]]; then
        log_recovery "power_management" "success" "$component - $success_rate% success rate"
        return 0
    else
        log_recovery "power_management" "partial" "$component - $success_rate% success rate"
        return 1
    fi
}

# ASUS tools failure recovery
recover_asus_tools_failure() {
    local tool="${1:-all}"
    local error_details="${2:-}"
    
    log_info "Attempting ASUS tools recovery for: $tool"
    log_recovery "asus_tools" "started" "$tool"
    
    local recovery_steps=0
    local successful_steps=0
    
    # Step 1: Restart ASUS services
    ((recovery_steps++))
    log_info "Step 1: Restarting ASUS services"
    local asus_services=("asusd" "supergfxd")
    local restart_success=true
    
    for service in "${asus_services[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
            if sudo systemctl restart "$service"; then
                log_debug "Restarted ASUS service: $service"
            else
                log_warn "Failed to restart service: $service"
                restart_success=false
            fi
        fi
    done
    
    if [[ "$restart_success" == true ]]; then
        ((successful_steps++))
    fi
    
    # Step 2: Test asusctl functionality
    ((recovery_steps++))
    log_info "Step 2: Testing asusctl functionality"
    if command -v asusctl >/dev/null 2>&1 && asusctl --version >/dev/null 2>&1; then
        log_success "asusctl is functioning"
        ((successful_steps++))
    else
        log_warn "asusctl functionality test failed"
    fi
    
    # Step 3: Test supergfxctl functionality
    ((recovery_steps++))
    log_info "Step 3: Testing supergfxctl functionality"
    if command -v supergfxctl >/dev/null 2>&1 && supergfxctl --version >/dev/null 2>&1; then
        log_success "supergfxctl is functioning"
        ((successful_steps++))
    else
        log_warn "supergfxctl functionality test failed"
    fi
    
    # Step 4: Check hardware access
    ((recovery_steps++))
    log_info "Step 4: Checking ASUS hardware access"
    if [[ -d /sys/class/leds/asus::kbd_backlight ]] || [[ -d /sys/devices/platform/asus-nb-wmi ]]; then
        log_success "ASUS hardware interfaces are accessible"
        ((successful_steps++))
    else
        log_warn "ASUS hardware interfaces may not be accessible"
    fi
    
    local success_rate=$((successful_steps * 100 / recovery_steps))
    log_info "ASUS tools recovery completed: $successful_steps/$recovery_steps steps successful ($success_rate%)"
    
    if [[ $success_rate -ge 75 ]]; then
        log_recovery "asus_tools" "success" "$tool - $success_rate% success rate"
        return 0
    else
        log_recovery "asus_tools" "partial" "$tool - $success_rate% success rate"
        return 1
    fi
}

# Network failure recovery
recover_network_failure() {
    local interface="${1:-auto}"
    local error_details="${2:-}"
    
    log_info "Attempting network recovery"
    log_recovery "network" "started" "$interface"
    
    local recovery_steps=0
    local successful_steps=0
    
    # Step 1: Restart NetworkManager
    ((recovery_steps++))
    log_info "Step 1: Restarting NetworkManager"
    if sudo systemctl restart NetworkManager; then
        log_success "NetworkManager restarted"
        ((successful_steps++))
    else
        log_warn "Failed to restart NetworkManager"
    fi
    
    # Step 2: Test connectivity
    ((recovery_steps++))
    log_info "Step 2: Testing network connectivity"
    sleep 5  # Wait for network to come up
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_success "Network connectivity restored"
        ((successful_steps++))
    else
        log_warn "Network connectivity test failed"
    fi
    
    # Step 3: Test DNS resolution
    ((recovery_steps++))
    log_info "Step 3: Testing DNS resolution"
    if ping -c 1 -W 5 archlinux.org >/dev/null 2>&1; then
        log_success "DNS resolution is working"
        ((successful_steps++))
    else
        log_warn "DNS resolution test failed"
    fi
    
    local success_rate=$((successful_steps * 100 / recovery_steps))
    log_info "Network recovery completed: $successful_steps/$recovery_steps steps successful ($success_rate%)"
    
    if [[ $success_rate -ge 66 ]]; then
        log_recovery "network" "success" "$interface - $success_rate% success rate"
        return 0
    else
        log_recovery "network" "partial" "$interface - $success_rate% success rate"
        return 1
    fi
}

# Disk space failure recovery
recover_disk_space_failure() {
    local threshold="${1:-90}"
    local error_details="${2:-}"
    
    log_info "Attempting disk space recovery (threshold: ${threshold}%)"
    log_recovery "disk_space" "started" "threshold:${threshold}%"
    
    local recovery_steps=0
    local successful_steps=0
    
    # Step 1: Clean package cache
    ((recovery_steps++))
    log_info "Step 1: Cleaning package cache"
    local cache_before=$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1 || echo "unknown")
    if sudo pacman -Scc --noconfirm; then
        local cache_after=$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1 || echo "unknown")
        log_success "Package cache cleaned (was: $cache_before, now: $cache_after)"
        ((successful_steps++))
    else
        log_warn "Failed to clean package cache"
    fi
    
    # Step 2: Clean journal logs
    ((recovery_steps++))
    log_info "Step 2: Cleaning old journal logs"
    if sudo journalctl --vacuum-time=7d; then
        log_success "Old journal logs cleaned"
        ((successful_steps++))
    else
        log_warn "Failed to clean journal logs"
    fi
    
    # Step 3: Remove orphaned packages
    ((recovery_steps++))
    log_info "Step 3: Removing orphaned packages"
    local orphans=$(pacman -Qtdq 2>/dev/null || echo "")
    if [[ -n "$orphans" ]]; then
        if sudo pacman -Rns --noconfirm $orphans; then
            log_success "Orphaned packages removed"
            ((successful_steps++))
        else
            log_warn "Failed to remove some orphaned packages"
        fi
    else
        log_debug "No orphaned packages found"
        ((successful_steps++))
    fi
    
    # Step 4: Check disk usage after cleanup
    ((recovery_steps++))
    log_info "Step 4: Checking disk usage after cleanup"
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -lt $threshold ]]; then
        log_success "Disk usage is now acceptable: ${disk_usage}%"
        ((successful_steps++))
    else
        log_warn "Disk usage is still high: ${disk_usage}%"
    fi
    
    local success_rate=$((successful_steps * 100 / recovery_steps))
    log_info "Disk space recovery completed: $successful_steps/$recovery_steps steps successful ($success_rate%)"
    
    if [[ $success_rate -ge 75 ]]; then
        log_recovery "disk_space" "success" "threshold:${threshold}% - $success_rate% success rate"
        return 0
    else
        log_recovery "disk_space" "partial" "threshold:${threshold}% - $success_rate% success rate"
        return 1
    fi
}

# Permission failure recovery
recover_permission_failure() {
    local path="${1:-/}"
    local error_details="${2:-}"
    
    log_info "Attempting permission recovery for: $path"
    log_recovery "permission" "started" "$path"
    
    local recovery_steps=0
    local successful_steps=0
    
    # Step 1: Check if path exists
    ((recovery_steps++))
    log_info "Step 1: Checking if path exists: $path"
    if [[ -e "$path" ]]; then
        log_success "Path exists: $path"
        ((successful_steps++))
    else
        log_warn "Path does not exist: $path"
    fi
    
    # Step 2: Check current permissions
    ((recovery_steps++))
    log_info "Step 2: Checking current permissions"
    local current_perms=$(ls -ld "$path" 2>/dev/null | awk '{print $1}' || echo "unknown")
    log_info "Current permissions: $current_perms"
    ((successful_steps++))
    
    # Step 3: Fix common permission issues
    ((recovery_steps++))
    log_info "Step 3: Attempting to fix permissions"
    if [[ -d "$path" ]]; then
        if sudo chmod 755 "$path" 2>/dev/null; then
            log_success "Directory permissions fixed"
            ((successful_steps++))
        else
            log_warn "Failed to fix directory permissions"
        fi
    elif [[ -f "$path" ]]; then
        if sudo chmod 644 "$path" 2>/dev/null; then
            log_success "File permissions fixed"
            ((successful_steps++))
        else
            log_warn "Failed to fix file permissions"
        fi
    else
        log_debug "Path type unknown, skipping permission fix"
        ((successful_steps++))
    fi
    
    local success_rate=$((successful_steps * 100 / recovery_steps))
    log_info "Permission recovery completed: $successful_steps/$recovery_steps steps successful ($success_rate%)"
    
    if [[ $success_rate -ge 66 ]]; then
        log_recovery "permission" "success" "$path - $success_rate% success rate"
        return 0
    else
        log_recovery "permission" "partial" "$path - $success_rate% success rate"
        return 1
    fi
}

# Configuration corruption recovery
recover_config_corruption() {
    local config_file="${1:-}"
    local error_details="${2:-}"
    
    log_info "Attempting configuration corruption recovery for: $config_file"
    log_recovery "config_corruption" "started" "$config_file"
    
    local recovery_steps=0
    local successful_steps=0
    
    # Step 1: Backup corrupted config
    ((recovery_steps++))
    log_info "Step 1: Backing up corrupted configuration"
    if [[ -f "$config_file" ]]; then
        local backup_file="${config_file}.corrupted-$(date +%Y%m%d_%H%M%S)"
        if sudo cp "$config_file" "$backup_file"; then
            log_success "Corrupted config backed up to: $backup_file"
            ((successful_steps++))
        else
            log_warn "Failed to backup corrupted config"
        fi
    else
        log_debug "Config file doesn't exist"
        ((successful_steps++))
    fi
    
    # Step 2: Look for backup
    ((recovery_steps++))
    log_info "Step 2: Looking for configuration backup"
    local backup_pattern="${config_file}.backup*"
    local latest_backup=$(ls -1t $backup_pattern 2>/dev/null | head -1)
    
    if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
        log_success "Found configuration backup: $latest_backup"
        ((successful_steps++))
    else
        log_warn "No configuration backup found"
    fi
    
    # Step 3: Restore from backup or create default
    ((recovery_steps++))
    log_info "Step 3: Restoring configuration"
    if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
        if sudo cp "$latest_backup" "$config_file"; then
            log_success "Configuration restored from backup"
            ((successful_steps++))
        else
            log_warn "Failed to restore from backup"
        fi
    else
        # Create minimal default config based on file type
        local config_created=false
        case "$config_file" in
            *.conf)
                echo "# Default configuration restored $(date)" | sudo tee "$config_file" >/dev/null
                config_created=true
                ;;
            */xorg.conf.d/*)
                echo "# Minimal Xorg configuration" | sudo tee "$config_file" >/dev/null
                config_created=true
                ;;
        esac
        
        if [[ "$config_created" == true ]]; then
            log_success "Default configuration created"
            ((successful_steps++))
        else
            log_warn "Could not create default configuration"
        fi
    fi
    
    local success_rate=$((successful_steps * 100 / recovery_steps))
    log_info "Configuration corruption recovery completed: $successful_steps/$recovery_steps steps successful ($success_rate%)"
    
    if [[ $success_rate -ge 66 ]]; then
        log_recovery "config_corruption" "success" "$config_file - $success_rate% success rate"
        return 0
    else
        log_recovery "config_corruption" "partial" "$config_file - $success_rate% success rate"
        return 1
    fi
}

# Execute recovery mechanism by name
execute_recovery() {
    local recovery_type="$1"
    shift
    local recovery_args=("$@")
    
    if [[ -n "${RECOVERY_MECHANISMS[$recovery_type]:-}" ]]; then
        local recovery_function="${RECOVERY_MECHANISMS[$recovery_type]}"
        log_info "Executing recovery mechanism: $recovery_type"
        
        if "$recovery_function" "${recovery_args[@]}"; then
            log_success "Recovery mechanism completed successfully: $recovery_type"
            return 0
        else
            log_error "Recovery mechanism failed: $recovery_type"
            return 1
        fi
    else
        log_error "Unknown recovery mechanism: $recovery_type"
        return 1
    fi
}

# List available recovery mechanisms
list_recovery_mechanisms() {
    log_info "Available recovery mechanisms:"
    for mechanism in "${!RECOVERY_MECHANISMS[@]}"; do
        echo "  - $mechanism: ${RECOVERY_MECHANISMS[$mechanism]}"
    done
}

# Show recovery history
show_recovery_history() {
    if [[ -f "$RECOVERY_LOG_FILE" ]]; then
        log_info "Recent recovery attempts:"
        tail -20 "$RECOVERY_LOG_FILE" | while IFS= read -r line; do
            echo "  $line"
        done
    else
        log_info "No recovery history available"
    fi
}

# Main function
main() {
    local command="${1:-help}"
    
    case "$command" in
        "init")
            init_recovery_system
            ;;
        "recover")
            if [[ $# -lt 2 ]]; then
                log_error "Recovery type required"
                echo "Usage: $0 recover <type> [args...]"
                exit 1
            fi
            execute_recovery "${@:2}"
            ;;
        "list")
            list_recovery_mechanisms
            ;;
        "history")
            show_recovery_history
            ;;
        "help"|"-h"|"--help")
            cat << EOF
Usage: $0 <command> [options]

Commands:
    init                    Initialize recovery system
    recover <type> [args]   Execute recovery mechanism
    list                    List available recovery mechanisms
    history                 Show recovery history
    help                    Show this help message

Recovery Types:
    package_install_failure [package]
    service_start_failure <service>
    gpu_driver_failure [gpu_type]
    xorg_config_failure [config_file]
    power_management_failure [component]
    asus_tools_failure [tool]
    network_failure [interface]
    disk_space_failure [threshold]
    permission_failure <path>
    config_corruption <config_file>

Examples:
    $0 recover package_install_failure nvidia
    $0 recover service_start_failure tlp
    $0 recover gpu_driver_failure both
    $0 recover disk_space_failure 85

EOF
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Initialize recovery system if not already done
if [[ ! -f "$RECOVERY_LOG_FILE" ]]; then
    init_recovery_system
fi

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi