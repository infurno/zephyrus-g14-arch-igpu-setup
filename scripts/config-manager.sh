#!/bin/bash

# Configuration Manager for Zephyrus G14 Setup
# Handles templating, customization, validation, and hardware variant support

set -euo pipefail

# Configuration directories
CONFIG_DIR="$(dirname "$(dirname "$(realpath "$0")")")/configs"
TEMPLATE_DIR="${CONFIG_DIR}/templates"
USER_CONFIG_DIR="${HOME}/.config/zephyrus-g14"
SYSTEM_CONFIG_DIR="/etc/zephyrus-g14"

# Hardware detection cache
HARDWARE_CACHE="${USER_CONFIG_DIR}/hardware.conf"
USER_PREFS="${USER_CONFIG_DIR}/preferences.conf"

# Logging
LOG_FILE="${USER_CONFIG_DIR}/config-manager.log"

# Initialize logging
init_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuration Manager started"
}

# Hardware detection functions
detect_hardware() {
    echo "Detecting hardware configuration..."
    
    local hw_config="${HARDWARE_CACHE}"
    mkdir -p "$(dirname "$hw_config")"
    
    # GPU detection
    local amd_gpu=""
    local nvidia_gpu=""
    
    if lspci | grep -i "amd.*vga\|amd.*display" > /dev/null; then
        amd_gpu=$(lspci | grep -i "amd.*vga\|amd.*display" | head -1 | cut -d: -f3- | xargs)
    fi
    
    if lspci | grep -i "nvidia.*vga\|nvidia.*3d" > /dev/null; then
        nvidia_gpu=$(lspci | grep -i "nvidia.*vga\|nvidia.*3d" | head -1 | cut -d: -f3- | xargs)
    fi
    
    # CPU detection
    local cpu_model=""
    if [ -f /proc/cpuinfo ]; then
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    fi
    
    # ASUS model detection
    local laptop_model=""
    if [ -f /sys/class/dmi/id/product_name ]; then
        laptop_model=$(cat /sys/class/dmi/id/product_name)
    fi
    
    # Power supply detection
    local has_battery="false"
    if [ -d /sys/class/power_supply/BAT* ] 2>/dev/null; then
        has_battery="true"
    fi
    
    # Write hardware configuration
    cat > "$hw_config" << EOF
# Hardware Configuration - Auto-detected
# Generated on $(date)

[hardware]
laptop_model="$laptop_model"
cpu_model="$cpu_model"
amd_gpu="$amd_gpu"
nvidia_gpu="$nvidia_gpu"
has_battery=$has_battery

[capabilities]
hybrid_graphics=$([ -n "$amd_gpu" ] && [ -n "$nvidia_gpu" ] && echo "true" || echo "false")
amd_pstate_supported=$([ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver ] && grep -q "amd_pstate" /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver && echo "true" || echo "false")
bbswitch_supported=$(lsmod | grep -q bbswitch && echo "true" || echo "false")
EOF
    
    echo "Hardware detection complete. Results saved to $hw_config"
}

# User preference detection and initialization
init_user_preferences() {
    echo "Initializing user preferences..."
    
    mkdir -p "$(dirname "$USER_PREFS")"
    
    if [ ! -f "$USER_PREFS" ]; then
        cat > "$USER_PREFS" << EOF
# User Preferences for Zephyrus G14 Configuration
# Edit this file to customize your setup

[power]
# Power profile: power-saver, balanced, performance
default_power_profile=balanced
# Enable aggressive power saving on battery
battery_power_saving=true
# CPU governor preference: powersave, ondemand, performance, schedutil
cpu_governor_preference=schedutil

[graphics]
# Primary GPU: integrated, hybrid, discrete
primary_gpu_mode=hybrid
# Enable NVIDIA GPU power management
nvidia_power_management=true
# PRIME render offload by default
prime_offload_default=true

[display]
# Enable external display support
external_display_support=true
# Preferred display scaling
display_scaling=1.0
# Enable night light/blue light filter
night_light=false

[asus]
# Enable ASUS hardware controls
enable_asusctl=true
# Enable ROG Control Center
enable_rog_control=true
# Fan curve profile: silent, balanced, performance
fan_profile=balanced

[advanced]
# Enable experimental features
experimental_features=false
# Custom kernel parameters (space-separated)
custom_kernel_params=""
# Additional packages to install (space-separated)
additional_packages=""
EOF
        echo "Default preferences created at $USER_PREFS"
        echo "Edit this file to customize your configuration before running setup."
    else
        echo "User preferences already exist at $USER_PREFS"
    fi
}

# Configuration template processing
process_template() {
    local template_file="$1"
    local output_file="$2"
    local context_file="$3"
    
    if [ ! -f "$template_file" ]; then
        echo "Error: Template file $template_file not found"
        return 1
    fi
    
    echo "Processing template: $template_file -> $output_file"
    
    # Source configuration context
    if [ -f "$context_file" ]; then
        # shellcheck source=/dev/null
        source "$context_file"
    fi
    
    # Source hardware configuration
    if [ -f "$HARDWARE_CACHE" ]; then
        # shellcheck source=/dev/null
        source "$HARDWARE_CACHE"
    fi
    
    # Source user preferences
    if [ -f "$USER_PREFS" ]; then
        # shellcheck source=/dev/null
        source "$USER_PREFS"
    fi
    
    # Process template with variable substitution
    mkdir -p "$(dirname "$output_file")"
    envsubst < "$template_file" > "$output_file"
    
    echo "Template processed successfully"
}

# Configuration validation
validate_configuration() {
    local config_file="$1"
    local config_type="$2"
    
    echo "Validating $config_type configuration: $config_file"
    
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file $config_file not found"
        return 1
    fi
    
    case "$config_type" in
        "xorg")
            validate_xorg_config "$config_file"
            ;;
        "tlp")
            validate_tlp_config "$config_file"
            ;;
        "systemd")
            validate_systemd_config "$config_file"
            ;;
        "udev")
            validate_udev_config "$config_file"
            ;;
        *)
            echo "Warning: No specific validation for config type: $config_type"
            ;;
    esac
}

validate_xorg_config() {
    local config_file="$1"
    
    # Check for required sections
    if ! grep -q "Section.*Device" "$config_file"; then
        echo "Error: Xorg config missing Device section"
        return 1
    fi
    
    # Check for AMD GPU configuration
    if ! grep -q "Driver.*amdgpu" "$config_file"; then
        echo "Warning: AMD GPU driver not found in Xorg config"
    fi
    
    echo "Xorg configuration validation passed"
}

validate_tlp_config() {
    local config_file="$1"
    
    # Check for critical TLP settings
    if ! grep -q "TLP_ENABLE" "$config_file"; then
        echo "Error: TLP_ENABLE not found in configuration"
        return 1
    fi
    
    # Validate CPU governor settings
    if grep -q "CPU_SCALING_GOVERNOR_ON_AC" "$config_file"; then
        local governor=$(grep "CPU_SCALING_GOVERNOR_ON_AC" "$config_file" | cut -d= -f2 | tr -d '"')
        if [[ ! "$governor" =~ ^(powersave|ondemand|performance|schedutil)$ ]]; then
            echo "Warning: Invalid CPU governor: $governor"
        fi
    fi
    
    echo "TLP configuration validation passed"
}

validate_systemd_config() {
    local config_file="$1"
    
    # Check systemd service file syntax
    if ! grep -q "\[Unit\]" "$config_file"; then
        echo "Error: Systemd service missing [Unit] section"
        return 1
    fi
    
    if ! grep -q "\[Service\]" "$config_file"; then
        echo "Error: Systemd service missing [Service] section"
        return 1
    fi
    
    echo "Systemd configuration validation passed"
}

validate_udev_config() {
    local config_file="$1"
    
    # Check udev rule syntax
    if ! grep -qE "^(ACTION|KERNEL|SUBSYSTEM|ATTR)" "$config_file"; then
        echo "Warning: Udev rule may be malformed"
    fi
    
    echo "Udev configuration validation passed"
}

# Hardware variant support
get_hardware_variant() {
    if [ ! -f "$HARDWARE_CACHE" ]; then
        detect_hardware
    fi
    
    # shellcheck source=/dev/null
    source "$HARDWARE_CACHE"
    
    local variant="unknown"
    
    # Determine hardware variant based on detected components
    if [[ "$laptop_model" == *"GA403"* ]]; then
        if [[ "$nvidia_gpu" == *"RTX 4060"* ]]; then
            variant="ga403uv"  # RTX 4060 variant
        elif [[ "$nvidia_gpu" == *"RTX 4070"* ]]; then
            variant="ga403wr"  # RTX 4070 variant
        elif [[ "$nvidia_gpu" == *"RTX 5070"* ]]; then
            variant="ga403wr-2025"  # RTX 5070 variant
        else
            variant="ga403-generic"
        fi
    elif [[ "$laptop_model" == *"GA402"* ]]; then
        variant="ga402-series"
    else
        variant="generic-asus"
    fi
    
    echo "$variant"
}

# Apply hardware-specific configurations
apply_hardware_variant_config() {
    local variant="$1"
    local variant_dir="${CONFIG_DIR}/variants/${variant}"
    
    echo "Applying configuration for hardware variant: $variant"
    
    if [ ! -d "$variant_dir" ]; then
        echo "Warning: No specific configuration for variant $variant, using generic"
        variant_dir="${CONFIG_DIR}/variants/generic"
    fi
    
    if [ -d "$variant_dir" ]; then
        echo "Copying variant-specific configurations..."
        find "$variant_dir" -type f -name "*.conf" -o -name "*.rules" -o -name "*.service" | while read -r file; do
            local rel_path="${file#$variant_dir/}"
            local dest_dir="${CONFIG_DIR}/$(dirname "$rel_path")"
            mkdir -p "$dest_dir"
            cp "$file" "${CONFIG_DIR}/${rel_path}"
            echo "Applied: $rel_path"
        done
    fi
}

# Main configuration management functions
generate_configurations() {
    echo "Generating configurations based on hardware and preferences..."
    
    # Ensure hardware is detected
    if [ ! -f "$HARDWARE_CACHE" ]; then
        detect_hardware
    fi
    
    # Initialize user preferences if needed
    init_user_preferences
    
    # Get hardware variant
    local variant
    variant=$(get_hardware_variant)
    echo "Detected hardware variant: $variant"
    
    # Apply variant-specific configurations
    apply_hardware_variant_config "$variant"
    
    # Process templates if they exist
    if [ -d "$TEMPLATE_DIR" ]; then
        find "$TEMPLATE_DIR" -name "*.template" | while read -r template; do
            local rel_path="${template#$TEMPLATE_DIR/}"
            local output_file="${CONFIG_DIR}/${rel_path%.template}"
            process_template "$template" "$output_file" "$USER_PREFS"
        done
    fi
    
    echo "Configuration generation complete"
}

validate_all_configurations() {
    echo "Validating all configurations..."
    
    local validation_failed=false
    
    # Validate Xorg configurations
    find "$CONFIG_DIR/xorg" -name "*.conf" 2>/dev/null | while read -r config; do
        if ! validate_configuration "$config" "xorg"; then
            validation_failed=true
        fi
    done
    
    # Validate TLP configurations
    find "$CONFIG_DIR/tlp" -name "*.conf" 2>/dev/null | while read -r config; do
        if ! validate_configuration "$config" "tlp"; then
            validation_failed=true
        fi
    done
    
    # Validate systemd configurations
    find "$CONFIG_DIR/systemd" -name "*.service" 2>/dev/null | while read -r config; do
        if ! validate_configuration "$config" "systemd"; then
            validation_failed=true
        fi
    done
    
    # Validate udev configurations
    find "$CONFIG_DIR/udev" -name "*.rules" 2>/dev/null | while read -r config; do
        if ! validate_configuration "$config" "udev"; then
            validation_failed=true
        fi
    done
    
    if [ "$validation_failed" = true ]; then
        echo "Configuration validation completed with warnings/errors"
        return 1
    else
        echo "All configurations validated successfully"
        return 0
    fi
}

# Command-line interface
show_usage() {
    cat << EOF
Configuration Manager for Zephyrus G14 Setup

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    detect-hardware     Detect and cache hardware configuration
    init-preferences    Initialize user preference file
    generate           Generate configurations based on hardware and preferences
    validate           Validate all configuration files
    show-hardware      Display detected hardware information
    show-preferences   Display current user preferences
    help               Show this help message

Options:
    --force            Force regeneration of existing files
    --verbose          Enable verbose output
    --dry-run          Show what would be done without making changes

Examples:
    $0 detect-hardware
    $0 generate --force
    $0 validate
EOF
}

show_hardware_info() {
    if [ ! -f "$HARDWARE_CACHE" ]; then
        echo "Hardware not detected yet. Run: $0 detect-hardware"
        return 1
    fi
    
    echo "Detected Hardware Configuration:"
    echo "================================"
    cat "$HARDWARE_CACHE"
}

show_preferences() {
    if [ ! -f "$USER_PREFS" ]; then
        echo "User preferences not initialized. Run: $0 init-preferences"
        return 1
    fi
    
    echo "Current User Preferences:"
    echo "========================"
    cat "$USER_PREFS"
}

# Main execution
main() {
    init_logging
    
    case "${1:-help}" in
        "detect-hardware")
            detect_hardware
            ;;
        "init-preferences")
            init_user_preferences
            ;;
        "generate")
            generate_configurations
            ;;
        "validate")
            validate_all_configurations
            ;;
        "show-hardware")
            show_hardware_info
            ;;
        "show-preferences")
            show_preferences
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            echo "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"