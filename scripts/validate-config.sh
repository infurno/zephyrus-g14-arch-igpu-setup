#!/bin/bash

# Configuration Validation Script for Zephyrus G14 Setup
# Validates configuration files for syntax, consistency, and hardware compatibility

set -euo pipefail

# Configuration directories
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/configs"
USER_CONFIG_DIR="${HOME}/.config/zephyrus-g14"

# Validation results
VALIDATION_LOG="${USER_CONFIG_DIR}/validation.log"
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

# Initialize logging
init_validation_logging() {
    mkdir -p "$(dirname "$VALIDATION_LOG")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuration validation started" > "$VALIDATION_LOG"
}

# Logging functions
log_error() {
    echo "ERROR: $1" | tee -a "$VALIDATION_LOG"
    ((VALIDATION_ERRORS++))
}

log_warning() {
    echo "WARNING: $1" | tee -a "$VALIDATION_LOG"
    ((VALIDATION_WARNINGS++))
}

log_info() {
    echo "INFO: $1" | tee -a "$VALIDATION_LOG"
}

# Hardware compatibility validation
validate_hardware_compatibility() {
    log_info "Validating hardware compatibility..."
    
    # Check for hybrid GPU setup
    local amd_gpu_present=false
    local nvidia_gpu_present=false
    
    if lspci | grep -qi "amd.*vga\|amd.*display"; then
        amd_gpu_present=true
        log_info "AMD GPU detected"
    else
        log_error "AMD GPU not detected - hybrid setup requires AMD iGPU"
    fi
    
    if lspci | grep -qi "nvidia.*vga\|nvidia.*3d"; then
        nvidia_gpu_present=true
        log_info "NVIDIA GPU detected"
    else
        log_warning "NVIDIA GPU not detected - some features may not work"
    fi
    
    # Check for ASUS hardware
    if [ -f /sys/class/dmi/id/sys_vendor ]; then
        local vendor=$(cat /sys/class/dmi/id/sys_vendor)
        if [[ "$vendor" != *"ASUSTeK"* ]]; then
            log_warning "Non-ASUS hardware detected: $vendor"
        else
            log_info "ASUS hardware confirmed: $vendor"
        fi
    fi
    
    # Check for required kernel modules
    local required_modules=("amdgpu" "nvidia" "bbswitch")
    for module in "${required_modules[@]}"; do
        if ! modinfo "$module" &>/dev/null; then
            log_error "Required kernel module not available: $module"
        else
            log_info "Kernel module available: $module"
        fi
    done
}

# Xorg configuration validation
validate_xorg_configs() {
    log_info "Validating Xorg configurations..."
    
    find "$CONFIG_DIR" -name "*.conf" -path "*/xorg/*" | while read -r config_file; do
        log_info "Validating Xorg config: $config_file"
        
        # Check for required sections
        if ! grep -q "Section.*Device" "$config_file"; then
            log_error "Missing Device section in $config_file"
        fi
        
        if ! grep -q "Section.*Screen" "$config_file"; then
            log_error "Missing Screen section in $config_file"
        fi
        
        # Check for AMD GPU driver
        if ! grep -q "Driver.*amdgpu" "$config_file"; then
            log_error "AMD GPU driver not configured in $config_file"
        fi
        
        # Check for NVIDIA configuration
        if grep -q "nvidia" "$config_file"; then
            if ! grep -q "AllowEmptyInitialConfiguration" "$config_file"; then
                log_warning "NVIDIA GPU missing AllowEmptyInitialConfiguration in $config_file"
            fi
        fi
        
        # Validate BusID format
        if grep -q "BusID" "$config_file"; then
            local busids
            busids=$(grep "BusID" "$config_file" | cut -d'"' -f2)
            while IFS= read -r busid; do
                if [[ ! "$busid" =~ ^PCI:[0-9]+:[0-9]+:[0-9]+$ ]]; then
                    log_warning "Invalid BusID format: $busid in $config_file"
                fi
            done <<< "$busids"
        fi
        
        # Check syntax with Xorg
        if command -v Xorg &>/dev/null; then
            if ! Xorg -config "$config_file" -configtest 2>/dev/null; then
                log_error "Xorg syntax validation failed for $config_file"
            else
                log_info "Xorg syntax validation passed for $config_file"
            fi
        else
            log_warning "Xorg not available for syntax validation"
        fi
    done
}

# TLP configuration validation
validate_tlp_configs() {
    log_info "Validating TLP configurations..."
    
    find "$CONFIG_DIR" -name "*.conf" -path "*/tlp/*" | while read -r config_file; do
        log_info "Validating TLP config: $config_file"
        
        # Check for TLP_ENABLE
        if ! grep -q "^TLP_ENABLE=" "$config_file"; then
            log_error "TLP_ENABLE not set in $config_file"
        fi
        
        # Validate CPU governors
        local governors=("powersave" "ondemand" "performance" "schedutil" "conservative")
        if grep -q "CPU_SCALING_GOVERNOR_ON_AC" "$config_file"; then
            local governor_ac
            governor_ac=$(grep "CPU_SCALING_GOVERNOR_ON_AC" "$config_file" | cut -d= -f2)
            if [[ ! " ${governors[*]} " =~ " ${governor_ac} " ]]; then
                log_error "Invalid CPU governor on AC: $governor_ac in $config_file"
            fi
        fi
        
        if grep -q "CPU_SCALING_GOVERNOR_ON_BAT" "$config_file"; then
            local governor_bat
            governor_bat=$(grep "CPU_SCALING_GOVERNOR_ON_BAT" "$config_file" | cut -d= -f2)
            if [[ ! " ${governors[*]} " =~ " ${governor_bat} " ]]; then
                log_error "Invalid CPU governor on battery: $governor_bat in $config_file"
            fi
        fi
        
        # Validate battery thresholds
        if grep -q "START_CHARGE_THRESH_BAT0" "$config_file"; then
            local start_thresh
            start_thresh=$(grep "START_CHARGE_THRESH_BAT0" "$config_file" | cut -d= -f2)
            if [[ ! "$start_thresh" =~ ^[0-9]+$ ]] || [ "$start_thresh" -lt 0 ] || [ "$start_thresh" -gt 100 ]; then
                log_error "Invalid start charge threshold: $start_thresh in $config_file"
            fi
        fi
        
        if grep -q "STOP_CHARGE_THRESH_BAT0" "$config_file"; then
            local stop_thresh
            stop_thresh=$(grep "STOP_CHARGE_THRESH_BAT0" "$config_file" | cut -d= -f2)
            if [[ ! "$stop_thresh" =~ ^[0-9]+$ ]] || [ "$stop_thresh" -lt 0 ] || [ "$stop_thresh" -gt 100 ]; then
                log_error "Invalid stop charge threshold: $stop_thresh in $config_file"
            fi
        fi
        
        # Check TLP syntax if available
        if command -v tlp &>/dev/null; then
            # Create temporary config for testing
            local temp_config="/tmp/tlp_test_$$.conf"
            cp "$config_file" "$temp_config"
            
            # Test TLP configuration
            if ! TLP_CONF="$temp_config" tlp start --no-init 2>/dev/null; then
                log_warning "TLP configuration test failed for $config_file"
            else
                log_info "TLP configuration test passed for $config_file"
            fi
            
            rm -f "$temp_config"
        else
            log_warning "TLP not available for configuration validation"
        fi
    done
}

# Systemd service validation
validate_systemd_configs() {
    log_info "Validating systemd configurations..."
    
    find "$CONFIG_DIR" -name "*.service" -path "*/systemd/*" | while read -r service_file; do
        log_info "Validating systemd service: $service_file"
        
        # Check for required sections
        if ! grep -q "^\[Unit\]" "$service_file"; then
            log_error "Missing [Unit] section in $service_file"
        fi
        
        if ! grep -q "^\[Service\]" "$service_file"; then
            log_error "Missing [Service] section in $service_file"
        fi
        
        # Check for Description
        if ! grep -q "^Description=" "$service_file"; then
            log_warning "Missing Description in $service_file"
        fi
        
        # Check for ExecStart
        if ! grep -q "^ExecStart=" "$service_file"; then
            log_error "Missing ExecStart in $service_file"
        fi
        
        # Validate ExecStart path
        if grep -q "^ExecStart=" "$service_file"; then
            local exec_start
            exec_start=$(grep "^ExecStart=" "$service_file" | cut -d= -f2- | awk '{print $1}')
            if [[ "$exec_start" =~ ^/ ]] && [ ! -x "$exec_start" ]; then
                log_warning "ExecStart binary not found or not executable: $exec_start"
            fi
        fi
        
        # Check systemd syntax if available
        if command -v systemd-analyze &>/dev/null; then
            if ! systemd-analyze verify "$service_file" 2>/dev/null; then
                log_error "Systemd service validation failed for $service_file"
            else
                log_info "Systemd service validation passed for $service_file"
            fi
        else
            log_warning "systemd-analyze not available for service validation"
        fi
    done
}

# Udev rules validation
validate_udev_configs() {
    log_info "Validating udev configurations..."
    
    find "$CONFIG_DIR" -name "*.rules" -path "*/udev/*" | while read -r rules_file; do
        log_info "Validating udev rules: $rules_file"
        
        # Check for basic udev rule structure
        if ! grep -qE "^(ACTION|KERNEL|SUBSYSTEM|ATTR)" "$rules_file"; then
            log_warning "No standard udev rule patterns found in $rules_file"
        fi
        
        # Check for proper rule syntax
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue
            
            # Check for proper rule format
            if [[ "$line" =~ ^[A-Z] ]] && [[ ! "$line" =~ , ]]; then
                log_warning "Potentially malformed udev rule: $line in $rules_file"
            fi
        done < "$rules_file"
        
        # Test udev rules syntax if available
        if command -v udevadm &>/dev/null; then
            if ! udevadm test-builtin path_id /sys/class/block/sda 2>/dev/null; then
                log_warning "udev test environment not available"
            else
                log_info "udev rules syntax appears valid for $rules_file"
            fi
        fi
    done
}

# Configuration consistency validation
validate_configuration_consistency() {
    log_info "Validating configuration consistency..."
    
    # Check for conflicting GPU configurations
    local xorg_configs
    xorg_configs=$(find "$CONFIG_DIR" -name "*.conf" -path "*/xorg/*")
    
    if [ -n "$xorg_configs" ]; then
        local amd_driver_count=0
        local nvidia_driver_count=0
        
        while IFS= read -r config; do
            if grep -q "Driver.*amdgpu" "$config"; then
                ((amd_driver_count++))
            fi
            if grep -q "Driver.*nvidia" "$config"; then
                ((nvidia_driver_count++))
            fi
        done <<< "$xorg_configs"
        
        if [ "$amd_driver_count" -eq 0 ]; then
            log_error "No AMD GPU driver configuration found"
        elif [ "$amd_driver_count" -gt 1 ]; then
            log_warning "Multiple AMD GPU driver configurations found"
        fi
        
        if [ "$nvidia_driver_count" -gt 1 ]; then
            log_warning "Multiple NVIDIA GPU driver configurations found"
        fi
    fi
    
    # Check for TLP and auto-cpufreq conflicts
    local tlp_enabled=false
    local auto_cpufreq_enabled=false
    
    if find "$CONFIG_DIR" -name "*.conf" -path "*/tlp/*" -exec grep -q "TLP_ENABLE=1" {} \; 2>/dev/null; then
        tlp_enabled=true
    fi
    
    if systemctl is-enabled auto-cpufreq &>/dev/null; then
        auto_cpufreq_enabled=true
    fi
    
    if [ "$tlp_enabled" = true ] && [ "$auto_cpufreq_enabled" = true ]; then
        log_warning "Both TLP and auto-cpufreq are enabled - this may cause conflicts"
    fi
}

# User preference validation
validate_user_preferences() {
    log_info "Validating user preferences..."
    
    local prefs_file="${USER_CONFIG_DIR}/preferences.conf"
    
    if [ ! -f "$prefs_file" ]; then
        log_warning "User preferences file not found: $prefs_file"
        return
    fi
    
    # Source and validate preferences
    # shellcheck source=/dev/null
    source "$prefs_file" 2>/dev/null || {
        log_error "Failed to source user preferences file"
        return
    }
    
    # Validate power profile
    if [ -n "${default_power_profile:-}" ]; then
        local valid_profiles=("power-saver" "balanced" "performance")
        if [[ ! " ${valid_profiles[*]} " =~ " ${default_power_profile} " ]]; then
            log_error "Invalid default power profile: $default_power_profile"
        fi
    fi
    
    # Validate GPU mode
    if [ -n "${primary_gpu_mode:-}" ]; then
        local valid_modes=("integrated" "hybrid" "discrete")
        if [[ ! " ${valid_modes[*]} " =~ " ${primary_gpu_mode} " ]]; then
            log_error "Invalid primary GPU mode: $primary_gpu_mode"
        fi
    fi
    
    # Validate CPU governor preference
    if [ -n "${cpu_governor_preference:-}" ]; then
        local valid_governors=("powersave" "ondemand" "performance" "schedutil" "conservative")
        if [[ ! " ${valid_governors[*]} " =~ " ${cpu_governor_preference} " ]]; then
            log_error "Invalid CPU governor preference: $cpu_governor_preference"
        fi
    fi
}

# Generate validation report
generate_validation_report() {
    log_info "Generating validation report..."
    
    local report_file="${USER_CONFIG_DIR}/validation-report.txt"
    
    cat > "$report_file" << EOF
Configuration Validation Report
Generated: $(date)

Summary:
- Errors: $VALIDATION_ERRORS
- Warnings: $VALIDATION_WARNINGS

$([ $VALIDATION_ERRORS -eq 0 ] && echo "✓ No critical errors found" || echo "✗ Critical errors found - review required")
$([ $VALIDATION_WARNINGS -eq 0 ] && echo "✓ No warnings" || echo "⚠ Warnings present - review recommended")

Detailed log: $VALIDATION_LOG

EOF
    
    echo "Validation report generated: $report_file"
    cat "$report_file"
}

# Main validation function
main() {
    init_validation_logging
    
    log_info "Starting comprehensive configuration validation..."
    
    validate_hardware_compatibility
    validate_xorg_configs
    validate_tlp_configs
    validate_systemd_configs
    validate_udev_configs
    validate_configuration_consistency
    validate_user_preferences
    
    generate_validation_report
    
    log_info "Configuration validation completed"
    
    # Exit with error code if critical errors found
    if [ $VALIDATION_ERRORS -gt 0 ]; then
        echo "Validation failed with $VALIDATION_ERRORS errors"
        exit 1
    else
        echo "Validation completed successfully with $VALIDATION_WARNINGS warnings"
        exit 0
    fi
}

# Execute main function
main "$@"