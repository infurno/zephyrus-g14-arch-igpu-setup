#!/bin/bash

# Xorg Configuration Test and Troubleshooting Script
# For ASUS ROG Zephyrus G14 hybrid GPU setup

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(dirname "$SCRIPT_DIR")"

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

show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                        Xorg Configuration Tester                            ║
║                     ASUS ROG Zephyrus G14 Hybrid GPU                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF
}

# Hardware detection functions
detect_hardware() {
    log_info "=== Hardware Detection ==="
    
    # CPU information
    local cpu_info=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    log_info "CPU: $cpu_info"
    
    # GPU information
    log_info "GPU Information:"
    lspci | grep -E "(VGA|3D)" | while read -r line; do
        log_info "  $line"
    done
    
    # Memory information
    local mem_info=$(free -h | grep "Mem:" | awk '{print $2}')
    log_info "Memory: $mem_info"
    
    echo
}

detect_gpu_details() {
    log_info "=== GPU Details ==="
    
    # AMD GPU details
    if lspci | grep -qi "amd\|radeon"; then
        log_success "AMD GPU detected"
        local amd_info=$(lspci -v | grep -A 10 -i "amd\|radeon" | grep -E "(Subsystem|Kernel driver)")
        if [[ -n "$amd_info" ]]; then
            echo "$amd_info" | while read -r line; do
                log_info "  AMD: $line"
            done
        fi
    else
        log_warn "AMD GPU not detected"
    fi
    
    # NVIDIA GPU details
    if lspci | grep -qi "nvidia"; then
        log_success "NVIDIA GPU detected"
        local nvidia_info=$(lspci -v | grep -A 10 -i "nvidia" | grep -E "(Subsystem|Kernel driver)")
        if [[ -n "$nvidia_info" ]]; then
            echo "$nvidia_info" | while read -r line; do
                log_info "  NVIDIA: $line"
            done
        fi
    else
        log_warn "NVIDIA GPU not detected"
    fi
    
    echo
}

check_drivers() {
    log_info "=== Driver Status ==="
    
    # Check loaded kernel modules
    log_info "Loaded GPU kernel modules:"
    lsmod | grep -E "(amdgpu|radeon|nvidia|nouveau)" | while read -r line; do
        log_info "  $line"
    done
    
    # Check for conflicting drivers
    if lsmod | grep -q "nouveau"; then
        log_warn "Nouveau driver is loaded (conflicts with NVIDIA proprietary driver)"
    fi
    
    # Check NVIDIA driver version
    if command -v nvidia-smi &>/dev/null; then
        local nvidia_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [[ -n "$nvidia_version" ]]; then
            log_success "NVIDIA driver version: $nvidia_version"
        fi
    else
        log_warn "nvidia-smi not available"
    fi
    
    echo
}

check_xorg_config() {
    log_info "=== Xorg Configuration Status ==="
    
    local config_file="/etc/X11/xorg.conf.d/10-hybrid.conf"
    
    # Check if configuration file exists
    if [[ -f "$config_file" ]]; then
        log_success "Hybrid GPU configuration found: $config_file"
        
        # Show configuration summary
        log_info "Configuration summary:"
        grep -E "(Identifier|Driver|BusID)" "$config_file" | while read -r line; do
            log_info "  $line"
        done
        
        # Validate bus IDs
        local bus_ids=$(grep "BusID" "$config_file" | grep -o "PCI:[0-9a-f]*:[0-9a-f]*:[0-9a-f]*")
        if [[ -n "$bus_ids" ]]; then
            log_info "Configured PCI bus IDs:"
            echo "$bus_ids" | while read -r bus_id; do
                log_info "  $bus_id"
            done
        fi
    else
        log_warn "Hybrid GPU configuration not found: $config_file"
    fi
    
    # Check for other Xorg configurations
    if [[ -d "/etc/X11/xorg.conf.d" ]]; then
        local other_configs=$(find /etc/X11/xorg.conf.d -name "*.conf" -not -name "10-hybrid.conf" 2>/dev/null)
        if [[ -n "$other_configs" ]]; then
            log_info "Other Xorg configurations found:"
            echo "$other_configs" | while read -r config; do
                log_info "  $(basename "$config")"
            done
        fi
    fi
    
    echo
}

test_display_detection() {
    log_info "=== Display Detection Test ==="
    
    # Check if we're in a graphical environment
    if [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        log_warn "Not in a graphical environment"
        log_info "Run this script from within X11 or Wayland for display testing"
        return 0
    fi
    
    # Test xrandr availability and output
    if command -v xrandr &>/dev/null; then
        log_success "xrandr is available"
        
        log_info "Connected displays:"
        xrandr --listmonitors 2>/dev/null | tail -n +2 | while read -r line; do
            log_info "  $line"
        done
        
        log_info "Available outputs:"
        xrandr | grep " connected" | while read -r line; do
            log_info "  $line"
        done
        
        # Check for internal display
        if xrandr | grep -q "eDP-1\|eDP1\|LVDS-1\|LVDS1"; then
            log_success "Internal display detected"
        else
            log_warn "Internal display not detected"
        fi
    else
        log_warn "xrandr not available"
    fi
    
    echo
}

test_gpu_rendering() {
    log_info "=== GPU Rendering Test ==="
    
    # Test OpenGL with AMD GPU (default)
    if command -v glxinfo &>/dev/null; then
        log_info "Testing AMD GPU rendering:"
        local amd_renderer=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1)
        if [[ -n "$amd_renderer" ]]; then
            log_success "  $amd_renderer"
        else
            log_warn "  Could not get AMD GPU renderer information"
        fi
        
        # Test NVIDIA GPU rendering with prime-run
        if command -v prime-run &>/dev/null; then
            log_info "Testing NVIDIA GPU rendering with prime-run:"
            local nvidia_renderer=$(prime-run glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1)
            if [[ -n "$nvidia_renderer" ]]; then
                log_success "  $nvidia_renderer"
            else
                log_warn "  Could not get NVIDIA GPU renderer information"
            fi
        else
            log_warn "prime-run not available"
        fi
    else
        log_warn "glxinfo not available (install mesa-utils)"
    fi
    
    # Test Vulkan
    if command -v vulkaninfo &>/dev/null; then
        log_info "Vulkan devices:"
        vulkaninfo --summary 2>/dev/null | grep -A 5 "Vulkan Instance" | while read -r line; do
            log_info "  $line"
        done
    else
        log_warn "vulkaninfo not available (install vulkan-tools)"
    fi
    
    echo
}

test_power_management() {
    log_info "=== Power Management Test ==="
    
    # Check NVIDIA GPU power state
    if [[ -f "/proc/driver/nvidia/gpus/0000:01:00.0/power" ]]; then
        local nvidia_power=$(cat /proc/driver/nvidia/gpus/0000:01:00.0/power 2>/dev/null || echo "unknown")
        log_info "NVIDIA GPU power state: $nvidia_power"
    else
        log_warn "NVIDIA GPU power state file not found"
    fi
    
    # Check bbswitch status
    if [[ -f "/proc/acpi/bbswitch" ]]; then
        local bbswitch_status=$(cat /proc/acpi/bbswitch 2>/dev/null || echo "unknown")
        log_info "bbswitch status: $bbswitch_status"
    else
        log_warn "bbswitch not available"
    fi
    
    # Check switcheroo control
    if [[ -d "/sys/kernel/debug/vgaswitcheroo" ]]; then
        if [[ -f "/sys/kernel/debug/vgaswitcheroo/switch" ]]; then
            log_info "VGA switcheroo status:"
            sudo cat /sys/kernel/debug/vgaswitcheroo/switch 2>/dev/null | while read -r line; do
                log_info "  $line"
            done
        fi
    else
        log_warn "VGA switcheroo not available"
    fi
    
    echo
}

# Display configuration repair utilities
repair_xorg_config() {
    log_info "=== Display Configuration Repair ==="
    
    local config_file="/etc/X11/xorg.conf.d/10-hybrid.conf"
    local backup_file="/etc/X11/xorg.conf.d/10-hybrid.conf.backup"
    
    # Create backup if config exists
    if [[ -f "$config_file" ]]; then
        log_info "Creating backup of existing configuration..."
        sudo cp "$config_file" "$backup_file"
        log_success "Backup created: $backup_file"
    fi
    
    # Get GPU bus IDs
    local amd_bus_id=$(lspci | grep -i "vga.*amd\|vga.*radeon" | cut -d' ' -f1 | head -1)
    local nvidia_bus_id=$(lspci | grep -i "vga.*nvidia\|3d.*nvidia" | cut -d' ' -f1 | head -1)
    
    if [[ -z "$amd_bus_id" ]] || [[ -z "$nvidia_bus_id" ]]; then
        log_error "Could not detect both GPU bus IDs"
        log_info "AMD GPU bus ID: ${amd_bus_id:-not found}"
        log_info "NVIDIA GPU bus ID: ${nvidia_bus_id:-not found}"
        return 1
    fi
    
    # Convert bus IDs to Xorg format
    local amd_xorg_bus="PCI:$(echo "$amd_bus_id" | sed 's/:/@/g' | sed 's/\./@/g' | sed 's/@/:/1' | sed 's/@/:/1')"
    local nvidia_xorg_bus="PCI:$(echo "$nvidia_bus_id" | sed 's/:/@/g' | sed 's/\./@/g' | sed 's/@/:/1' | sed 's/@/:/1')"
    
    log_info "Generating new Xorg configuration..."
    log_info "AMD GPU bus ID: $amd_xorg_bus"
    log_info "NVIDIA GPU bus ID: $nvidia_xorg_bus"
    
    # Generate new configuration
    sudo tee "$config_file" > /dev/null << EOF
# Hybrid GPU configuration for ASUS ROG Zephyrus G14
# AMD Radeon 890M (iGPU) + NVIDIA RTX 5070 Ti (dGPU)
# Generated by xorg-test.sh repair function

Section "ServerLayout"
    Identifier "layout"
    Screen 0 "amd"
    Inactive "nvidia"
EndSection

Section "Device"
    Identifier "amd"
    Driver "amdgpu"
    BusID "$amd_xorg_bus"
EndSection

Section "Screen"
    Identifier "amd"
    Device "amd"
EndSection

Section "Device"
    Identifier "nvidia"
    Driver "nvidia"
    BusID "$nvidia_xorg_bus"
EndSection

Section "Screen"
    Identifier "nvidia"
    Device "nvidia"
EndSection
EOF
    
    log_success "New Xorg configuration created: $config_file"
    log_info "Restart your display manager or reboot to apply changes"
    
    echo
}

repair_display_issues() {
    log_info "=== Display Issue Repair ==="
    
    # Check for common display issues and attempt repairs
    local issues_found=false
    
    # Issue 1: No displays detected
    if [[ -n "${DISPLAY:-}" ]] && command -v xrandr &>/dev/null; then
        local connected_displays=$(xrandr | grep " connected" | wc -l)
        if [[ "$connected_displays" -eq 0 ]]; then
            log_warn "No connected displays detected"
            log_info "Attempting to force display detection..."
            xrandr --auto
            sleep 2
            connected_displays=$(xrandr | grep " connected" | wc -l)
            if [[ "$connected_displays" -gt 0 ]]; then
                log_success "Display detection successful after xrandr --auto"
            else
                log_error "Display detection failed"
                issues_found=true
            fi
        fi
    fi
    
    # Issue 2: Internal display not working
    if command -v xrandr &>/dev/null; then
        if ! xrandr | grep -E "eDP-1|eDP1|LVDS-1|LVDS1" | grep " connected" &>/dev/null; then
            log_warn "Internal display not detected as connected"
            log_info "Attempting to enable internal display..."
            
            # Try different internal display names
            for display_name in eDP-1 eDP1 LVDS-1 LVDS1; do
                if xrandr | grep -q "$display_name"; then
                    xrandr --output "$display_name" --auto 2>/dev/null && {
                        log_success "Internal display enabled: $display_name"
                        break
                    }
                fi
            done
        fi
    fi
    
    # Issue 3: Resolution problems
    if command -v xrandr &>/dev/null; then
        local current_res=$(xrandr | grep "primary" | grep -o "[0-9]*x[0-9]*" | head -1)
        if [[ -n "$current_res" ]]; then
            log_info "Current primary display resolution: $current_res"
            
            # Check if resolution is very low (might indicate a problem)
            local width=$(echo "$current_res" | cut -d'x' -f1)
            if [[ "$width" -lt 1024 ]]; then
                log_warn "Very low resolution detected, attempting to fix..."
                xrandr --auto
                log_info "Applied automatic resolution settings"
            fi
        fi
    fi
    
    # Issue 4: Multiple display configuration
    if command -v xrandr &>/dev/null; then
        local external_displays=$(xrandr | grep " connected" | grep -v "primary" | wc -l)
        if [[ "$external_displays" -gt 0 ]]; then
            log_info "External displays detected: $external_displays"
            log_info "Configuring optimal display layout..."
            
            # Enable all connected displays
            xrandr | grep " connected" | grep -v "primary" | while read -r line; do
                local display_name=$(echo "$line" | awk '{print $1}')
                xrandr --output "$display_name" --auto --right-of eDP-1 2>/dev/null || \
                xrandr --output "$display_name" --auto --right-of eDP1 2>/dev/null || \
                xrandr --output "$display_name" --auto 2>/dev/null
                log_info "Configured external display: $display_name"
            done
        fi
    fi
    
    if ! $issues_found; then
        log_success "No display issues found or all issues resolved"
    fi
    
    echo
}

test_and_repair_gpu_offload() {
    log_info "=== GPU Offload Test and Repair ==="
    
    # Test if GPU offload is working
    if command -v glxinfo &>/dev/null; then
        local default_gpu=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1)
        
        if command -v prime-run &>/dev/null; then
            local offload_gpu=$(prime-run glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1)
            
            if [[ "$default_gpu" != "$offload_gpu" ]]; then
                log_success "GPU offload working correctly"
                log_info "Default: $default_gpu"
                log_info "Offload: $offload_gpu"
            else
                log_warn "GPU offload not working (same renderer for both)"
                log_info "Attempting to repair GPU offload..."
                
                # Check if prime-run script exists and is executable
                if [[ ! -x "$(command -v prime-run)" ]]; then
                    log_error "prime-run not executable or not found"
                    return 1
                fi
                
                # Check environment variables
                log_info "Checking GPU offload environment variables..."
                prime-run env | grep -E "(DRI_PRIME|__NV_PRIME_RENDER_OFFLOAD|__GLX_VENDOR_LIBRARY_NAME)" | while read -r line; do
                    log_info "  $line"
                done
                
                # Test NVIDIA GPU directly
                if __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo 2>/dev/null | grep -q "NVIDIA"; then
                    log_success "NVIDIA GPU accessible via environment variables"
                else
                    log_error "NVIDIA GPU not accessible via environment variables"
                fi
            fi
        else
            log_error "prime-run not available"
            log_info "Install nvidia-prime package or create prime-run script"
        fi
    else
        log_warn "glxinfo not available for testing"
    fi
    
    echo
}

run_diagnostics() {
    log_info "=== Running Comprehensive Diagnostics ==="
    
    detect_hardware
    detect_gpu_details
    check_drivers
    check_xorg_config
    test_display_detection
    test_gpu_rendering
    test_power_management
    
    log_success "Diagnostics completed"
}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
    -h, --help          Show this help message
    -d, --diagnostics   Run comprehensive diagnostics
    -x, --xorg          Test Xorg configuration only
    -g, --gpu           Test GPU rendering only
    -p, --power         Test power management only
    --hardware          Show hardware information only
    --repair-xorg       Repair Xorg configuration
    --repair-display    Repair display issues
    --repair-offload    Test and repair GPU offload

Examples:
    $SCRIPT_NAME -d                 # Run all diagnostics
    $SCRIPT_NAME --xorg             # Test Xorg configuration
    $SCRIPT_NAME --gpu              # Test GPU rendering
    $SCRIPT_NAME --hardware         # Show hardware info
    $SCRIPT_NAME --repair-xorg      # Repair Xorg configuration
    $SCRIPT_NAME --repair-display   # Fix display issues

EOF
}

# Main execution
main() {
    local run_diagnostics=false
    local test_xorg=false
    local test_gpu=false
    local test_power=false
    local show_hardware=false
    local repair_xorg=false
    local repair_display=false
    local repair_offload=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--diagnostics)
                run_diagnostics=true
                shift
                ;;
            -x|--xorg)
                test_xorg=true
                shift
                ;;
            -g|--gpu)
                test_gpu=true
                shift
                ;;
            -p|--power)
                test_power=true
                shift
                ;;
            --hardware)
                show_hardware=true
                shift
                ;;
            --repair-xorg)
                repair_xorg=true
                shift
                ;;
            --repair-display)
                repair_display=true
                shift
                ;;
            --repair-offload)
                repair_offload=true
                shift
                ;;
            *)
                log_error "Unknown option: $1. Use --help for usage information."
                exit 1
                ;;
        esac
    done
    
    # Show banner
    show_banner
    
    # Execute based on options
    if [[ "$run_diagnostics" == true ]]; then
        run_diagnostics
    elif [[ "$test_xorg" == true ]]; then
        check_xorg_config
        test_display_detection
    elif [[ "$test_gpu" == true ]]; then
        test_gpu_rendering
    elif [[ "$test_power" == true ]]; then
        test_power_management
    elif [[ "$show_hardware" == true ]]; then
        detect_hardware
        detect_gpu_details
    elif [[ "$repair_xorg" == true ]]; then
        repair_xorg_config
    elif [[ "$repair_display" == true ]]; then
        repair_display_issues
    elif [[ "$repair_offload" == true ]]; then
        test_and_repair_gpu_offload
    else
        # Default: run basic diagnostics
        log_info "Running basic diagnostics (use -d for comprehensive diagnostics)"
        echo
        detect_hardware
        check_xorg_config
        test_display_detection
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi