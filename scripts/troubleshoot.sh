#!/bin/bash

# Troubleshooting Script for ASUS ROG Zephyrus G14 Hybrid GPU Setup
# Common issue detection and automated fixes

set -euo pipefail

# Source error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="/tmp/troubleshoot-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Troubleshooting & Diagnostics ${NC}"
    echo -e "${BLUE}================================${NC}"
    log "Starting troubleshooting session"
}

print_section() {
    echo -e "\n${CYAN}--- $1 ---${NC}"
    log "SECTION: $1"
}

print_issue() {
    echo -e "${RED}Issue: $1${NC}"
    log "ISSUE: $1"
}

print_solution() {
    echo -e "${GREEN}Solution: $1${NC}"
    log "SOLUTION: $1"
}

print_info() {
    echo -e "${YELLOW}Info: $1${NC}"
    log "INFO: $1"
}

# Check for common black screen issues
check_black_screen() {
    print_section "Black Screen Issues"
    
    local issues_found=false
    
    # Check if Xorg is running
    if ! pgrep -x "Xorg" > /dev/null; then
        print_issue "Xorg is not running"
        print_solution "Try: sudo systemctl restart display-manager"
        issues_found=true
    fi
    
    # Check for conflicting drivers
    if lsmod | grep -q "nouveau"; then
        print_issue "Nouveau driver is loaded (conflicts with NVIDIA)"
        print_solution "Add 'nouveau.modeset=0' to kernel parameters and blacklist nouveau"
        issues_found=true
    fi
    
    # Check Xorg configuration
    if [ ! -f "/etc/X11/xorg.conf.d/10-hybrid.conf" ]; then
        print_issue "Hybrid GPU Xorg configuration missing"
        print_solution "Run the main setup script to create proper Xorg configuration"
        issues_found=true
    fi
    
    # Check for NVIDIA driver issues
    if ! nvidia-smi &>/dev/null; then
        print_issue "NVIDIA driver not responding"
        print_solution "Try: sudo modprobe nvidia && sudo nvidia-smi"
        issues_found=true
    fi
    
    if ! $issues_found; then
        print_info "No black screen issues detected"
    fi
}

# Check GPU switching problems
check_gpu_switching() {
    print_section "GPU Switching Issues"
    
    local issues_found=false
    
    # Check if prime-run exists
    if ! command -v prime-run &>/dev/null; then
        print_issue "prime-run command not found"
        print_solution "Install nvidia-prime package or create prime-run script"
        issues_found=true
    fi
    
    # Check bbswitch functionality
    if [ ! -f "/proc/acpi/bbswitch" ]; then
        print_issue "bbswitch module not loaded"
        print_solution "Load bbswitch module: sudo modprobe bbswitch"
        issues_found=true
    else
        local nvidia_state=$(cat /proc/acpi/bbswitch | awk '{print $2}')
        print_info "NVIDIA GPU state: $nvidia_state"
    fi
    
    # Check supergfxctl status
    if command -v supergfxctl &>/dev/null; then
        local gfx_mode=$(supergfxctl -g 2>/dev/null || echo "unknown")
        print_info "Current graphics mode: $gfx_mode"
        
        if [ "$gfx_mode" = "unknown" ]; then
            print_issue "supergfxctl not responding properly"
            print_solution "Try: sudo systemctl restart supergfxd"
            issues_found=true
        fi
    else
        print_issue "supergfxctl not installed"
        print_solution "Install supergfxctl from AUR"
        issues_found=true
    fi
    
    if ! $issues_found; then
        print_info "No GPU switching issues detected"
    fi
}

# Check power management problems
check_power_management() {
    print_section "Power Management Issues"
    
    local issues_found=false
    
    # Check TLP status
    if ! systemctl is-active tlp &>/dev/null; then
        print_issue "TLP service not running"
        print_solution "Enable and start TLP: sudo systemctl enable --now tlp"
        issues_found=true
    fi
    
    # Check auto-cpufreq status
    if ! systemctl is-active auto-cpufreq &>/dev/null; then
        print_issue "auto-cpufreq service not running"
        print_solution "Enable and start auto-cpufreq: sudo systemctl enable --now auto-cpufreq"
        issues_found=true
    fi
    
    # Check CPU governor
    local cpu_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    if [ "$cpu_governor" = "performance" ] && [ "$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo 0)" = "0" ]; then
        print_issue "CPU in performance mode while on battery"
        print_solution "Switch to powersave governor or check power management configuration"
        issues_found=true
    fi
    
    # Check for conflicting power management services
    if systemctl is-active power-profiles-daemon &>/dev/null && systemctl is-active tlp &>/dev/null; then
        print_issue "Both power-profiles-daemon and TLP are running (conflict)"
        print_solution "Disable one service: sudo systemctl disable power-profiles-daemon OR sudo systemctl disable tlp"
        issues_found=true
    fi
    
    if ! $issues_found; then
        print_info "No power management issues detected"
    fi
}# C
heck ASUS hardware integration issues
check_asus_hardware() {
    print_section "ASUS Hardware Integration Issues"
    
    local issues_found=false
    
    # Check asusctl service
    if ! systemctl is-active asusd &>/dev/null; then
        print_issue "asusd service not running"
        print_solution "Enable and start asusd: sudo systemctl enable --now asusd"
        issues_found=true
    fi
    
    # Check asusctl functionality
    if ! asusctl --version &>/dev/null; then
        print_issue "asusctl not working properly"
        print_solution "Reinstall asusctl or check service status"
        issues_found=true
    fi
    
    # Check for missing firmware
    if dmesg | grep -i "firmware.*failed" | grep -i "asus" &>/dev/null; then
        print_issue "ASUS firmware loading failures detected"
        print_solution "Install linux-firmware package and reboot"
        issues_found=true
    fi
    
    # Check keyboard backlight
    if [ ! -d "/sys/class/leds/asus::kbd_backlight" ]; then
        print_issue "Keyboard backlight control not available"
        print_solution "Check if asusd is running and asusctl is properly installed"
        issues_found=true
    fi
    
    if ! $issues_found; then
        print_info "No ASUS hardware integration issues detected"
    fi
}

# Check display configuration issues
check_display_config() {
    print_section "Display Configuration Issues"
    
    local issues_found=false
    
    # Check if running in X11 or Wayland
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        print_info "Running under Wayland"
        print_info "Some GPU switching features may be limited under Wayland"
    elif [ -n "${DISPLAY:-}" ]; then
        print_info "Running under X11"
        
        # Check xrandr functionality
        if ! xrandr &>/dev/null; then
            print_issue "xrandr not working"
            print_solution "Check X11 configuration and restart display manager"
            issues_found=true
        else
            local monitors=$(xrandr --listmonitors | grep -c "Monitor")
            print_info "Detected $monitors monitor(s)"
        fi
    else
        print_issue "No display server detected"
        print_solution "Start X11 or Wayland session"
        issues_found=true
    fi
    
    # Check for external display issues
    if xrandr 2>/dev/null | grep -q "disconnected"; then
        local disconnected=$(xrandr 2>/dev/null | grep "disconnected" | wc -l)
        print_info "$disconnected disconnected display port(s) detected"
    fi
    
    if ! $issues_found; then
        print_info "No display configuration issues detected"
    fi
}

# Check system performance issues
check_performance() {
    print_section "Performance Issues"
    
    local issues_found=false
    
    # Check CPU frequency scaling
    local max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo "0")
    local cur_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "0")
    
    if [ "$max_freq" != "0" ] && [ "$cur_freq" != "0" ]; then
        local freq_percent=$((cur_freq * 100 / max_freq))
        print_info "CPU running at ${freq_percent}% of maximum frequency"
        
        if [ $freq_percent -lt 50 ] && [ "$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo 0)" = "1" ]; then
            print_issue "CPU frequency very low while plugged in"
            print_solution "Check power management settings or switch to performance mode"
            issues_found=true
        fi
    fi
    
    # Check thermal throttling
    if dmesg | grep -i "thermal" | grep -i "throttl" &>/dev/null; then
        print_issue "Thermal throttling detected in system logs"
        print_solution "Check system temperatures and clean laptop vents"
        issues_found=true
    fi
    
    # Check memory usage
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [ "$mem_usage" -gt 90 ]; then
        print_issue "High memory usage: ${mem_usage}%"
        print_solution "Close unnecessary applications or add more RAM"
        issues_found=true
    fi
    
    if ! $issues_found; then
        print_info "No performance issues detected"
    fi
}

# Automated fixes for common issues with enhanced error handling
auto_fix_common_issues() {
    print_section "Automated Fixes"
    
    echo -e "${YELLOW}Attempting automated fixes for common issues...${NC}"
    
    # Create rollback point before fixes
    log_info "Creating rollback point before automated fixes..."
    create_rollback_point "auto-fix" "Before automated troubleshooting fixes" || {
        log_warn "Failed to create rollback point, continuing without rollback capability"
    }
    
    local fixes_applied=0
    local fixes_failed=0
    
    # Fix 1: Reload kernel modules with error handling
    print_info "Reloading kernel modules..."
    if recover_gpu_driver; then
        print_solution "GPU drivers reloaded successfully"
        ((fixes_applied++))
    else
        print_issue "Failed to reload GPU drivers"
        ((fixes_failed++))
    fi
    
    # Fix 2: Restart critical services with recovery
    print_info "Restarting critical services..."
    local services=("asusd" "supergfxd" "tlp" "auto-cpufreq")
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            if recover_service_failure "$service"; then
                print_solution "$service restarted successfully"
                ((fixes_applied++))
            else
                print_issue "Failed to restart $service"
                ((fixes_failed++))
            fi
        fi
    done
    
    # Fix 3: Clear GPU state with validation
    if [ -f "/proc/acpi/bbswitch" ]; then
        print_info "Cycling NVIDIA GPU power state..."
        local current_state=$(cat /proc/acpi/bbswitch | awk '{print $2}')
        
        if echo OFF | sudo tee /proc/acpi/bbswitch > /dev/null 2>&1; then
            sleep 2
            if echo ON | sudo tee /proc/acpi/bbswitch > /dev/null 2>&1; then
                local new_state=$(cat /proc/acpi/bbswitch | awk '{print $2}')
                print_solution "NVIDIA GPU power cycled ($current_state -> $new_state)"
                ((fixes_applied++))
            else
                print_issue "Failed to power on NVIDIA GPU"
                ((fixes_failed++))
            fi
        else
            print_issue "Failed to power off NVIDIA GPU"
            ((fixes_failed++))
        fi
    fi
    
    # Fix 4: Update initramfs with validation
    if [ -f "/etc/mkinitcpio.conf" ]; then
        print_info "Updating initramfs..."
        local error_output
        if error_output=$(sudo mkinitcpio -P 2>&1); then
            print_solution "initramfs updated successfully"
            ((fixes_applied++))
        else
            print_issue "Failed to update initramfs: $error_output"
            ((fixes_failed++))
        fi
    fi
    
    # Fix 5: Restore Xorg configuration if corrupted
    if [ ! -f "/etc/X11/xorg.conf.d/10-hybrid.conf" ] || ! grep -q "amdgpu\|nvidia" "/etc/X11/xorg.conf.d/10-hybrid.conf" 2>/dev/null; then
        print_info "Attempting to restore Xorg configuration..."
        if recover_xorg_config; then
            print_solution "Xorg configuration restored"
            ((fixes_applied++))
        else
            print_issue "Failed to restore Xorg configuration"
            ((fixes_failed++))
        fi
    fi
    
    # Fix 6: Clear package cache if corrupted
    print_info "Checking package cache integrity..."
    if ! pacman -Q >/dev/null 2>&1; then
        print_info "Package database appears corrupted, attempting recovery..."
        if recover_package_installation; then
            print_solution "Package system recovered"
            ((fixes_applied++))
        else
            print_issue "Failed to recover package system"
            ((fixes_failed++))
        fi
    fi
    
    # Summary
    echo -e "\n${CYAN}Automated Fixes Summary:${NC}"
    echo "Fixes applied successfully: $fixes_applied"
    echo "Fixes failed: $fixes_failed"
    
    if [ $fixes_failed -gt 0 ]; then
        echo -e "${YELLOW}Some fixes failed. Consider manual intervention or system rollback.${NC}"
        return 1
    else
        echo -e "${GREEN}All automated fixes completed successfully.${NC}"
        return 0
    fi
}

# Generate system information report
generate_system_report() {
    print_section "System Information Report"
    
    local report_file="/tmp/system-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "System Report Generated: $(date)"
        echo "========================================"
        echo
        
        echo "Hardware Information:"
        echo "--------------------"
        lscpu | head -10
        echo
        lspci | grep -E "(VGA|3D)"
        echo
        
        echo "Kernel and Modules:"
        echo "------------------"
        uname -a
        echo
        lsmod | grep -E "(nvidia|amdgpu|bbswitch)"
        echo
        
        echo "Graphics Information:"
        echo "--------------------"
        if command -v nvidia-smi &>/dev/null; then
            nvidia-smi 2>/dev/null || echo "nvidia-smi failed"
        fi
        echo
        
        echo "Power Management:"
        echo "----------------"
        systemctl status tlp auto-cpufreq power-profiles-daemon 2>/dev/null | grep -E "(Active|Loaded)"
        echo
        
        echo "ASUS Services:"
        echo "-------------"
        systemctl status asusd supergfxd 2>/dev/null | grep -E "(Active|Loaded)"
        echo
        
        echo "Display Information:"
        echo "-------------------"
        if [ -n "$DISPLAY" ]; then
            xrandr 2>/dev/null || echo "xrandr failed"
        else
            echo "No X11 display available"
        fi
        echo
        
        echo "Recent System Logs:"
        echo "------------------"
        journalctl --since "1 hour ago" | grep -E "(nvidia|amdgpu|asus|gpu)" | tail -20
        
    } > "$report_file"
    
    print_solution "System report generated: $report_file"
}

# Interactive troubleshooting menu
interactive_menu() {
    while true; do
        echo -e "\n${CYAN}Troubleshooting Menu:${NC}"
        echo "1. Check black screen issues"
        echo "2. Check GPU switching issues"
        echo "3. Check power management issues"
        echo "4. Check ASUS hardware integration"
        echo "5. Check display configuration"
        echo "6. Check performance issues"
        echo "7. Run automated fixes"
        echo "8. Generate system report"
        echo "9. Run all checks"
        echo "0. Exit"
        
        read -p "Select option (0-9): " choice
        
        case $choice in
            1) check_black_screen ;;
            2) check_gpu_switching ;;
            3) check_power_management ;;
            4) check_asus_hardware ;;
            5) check_display_config ;;
            6) check_performance ;;
            7) auto_fix_common_issues ;;
            8) generate_system_report ;;
            9) run_all_checks ;;
            0) echo "Exiting..."; exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

# Run all diagnostic checks
run_all_checks() {
    print_header
    check_black_screen
    check_gpu_switching
    check_power_management
    check_asus_hardware
    check_display_config
    check_performance
    
    echo -e "\n${BLUE}Troubleshooting completed. Check log: $LOG_FILE${NC}"
}

# Main script execution
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --help, -h        Show this help message"
        echo "  --interactive, -i Run interactive troubleshooting menu"
        echo "  --auto-fix, -f    Run automated fixes"
        echo "  --report, -r      Generate system report only"
        echo "  --all, -a         Run all diagnostic checks"
        exit 0
        ;;
    --interactive|-i)
        interactive_menu
        ;;
    --auto-fix|-f)
        print_header
        auto_fix_common_issues
        ;;
    --report|-r)
        generate_system_report
        ;;
    --all|-a)
        run_all_checks
        ;;
    *)
        run_all_checks
        ;;
esac