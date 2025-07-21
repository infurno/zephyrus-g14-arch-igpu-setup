#!/bin/bash

# Error Reporting and Analysis System
# Provides comprehensive error analysis, reporting, and troubleshooting guidance

set -euo pipefail

# Source error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"

# Error reporting configuration
readonly ERROR_REPORTER_VERSION="1.0.0"
readonly ERROR_REPORT_DIR="${ERROR_LOG_DIR}/reports"
readonly ERROR_PATTERNS_FILE="${SCRIPT_DIR}/../configs/error-patterns.json"

# Initialize error reporting system
init_error_reporting() {
    log_info "Initializing error reporting system (v${ERROR_REPORTER_VERSION})"
    
    sudo mkdir -p "$ERROR_REPORT_DIR"
    sudo chmod 755 "$ERROR_REPORT_DIR"
    
    # Create error patterns file if it doesn't exist
    if [[ ! -f "$ERROR_PATTERNS_FILE" ]]; then
        create_error_patterns_file
    fi
    
    log_success "Error reporting system initialized"
}

# Create error patterns configuration
create_error_patterns_file() {
    local patterns_dir=$(dirname "$ERROR_PATTERNS_FILE")
    mkdir -p "$patterns_dir"
    
    cat << 'EOF' > "$ERROR_PATTERNS_FILE"
{
    "package_errors": {
        "signature_error": {
            "pattern": "signature.*invalid|key.*unknown|gpg.*error",
            "description": "Package signature validation failed",
            "solution": "Update keyring: sudo pacman -S archlinux-keyring",
            "recovery_function": "recover_package_installation"
        },
        "dependency_conflict": {
            "pattern": "conflicting dependencies|conflicts with",
            "description": "Package dependency conflict detected",
            "solution": "Resolve conflicts manually or use --overwrite flag",
            "recovery_function": "resolve_package_conflicts"
        },
        "network_error": {
            "pattern": "failed retrieving file|download.*failed|connection.*timeout",
            "description": "Network error during package download",
            "solution": "Check internet connection and try again",
            "recovery_function": "retry_with_different_mirror"
        }
    },
    "service_errors": {
        "service_failed": {
            "pattern": "failed to start|service.*failed|unit.*failed",
            "description": "System service failed to start",
            "solution": "Check service logs: journalctl -u <service>",
            "recovery_function": "recover_service_failure"
        },
        "dependency_failed": {
            "pattern": "dependency failed|required by.*failed",
            "description": "Service dependency failure",
            "solution": "Check and restart dependent services",
            "recovery_function": "restart_service_dependencies"
        }
    },
    "gpu_errors": {
        "nvidia_driver_error": {
            "pattern": "nvidia.*error|nvidia.*failed|nvidia-smi.*failed",
            "description": "NVIDIA driver error",
            "solution": "Reload NVIDIA modules or reinstall driver",
            "recovery_function": "recover_gpu_driver"
        },
        "xorg_error": {
            "pattern": "xorg.*error|x server.*failed|display.*failed",
            "description": "X server or display error",
            "solution": "Check Xorg configuration and restart display manager",
            "recovery_function": "recover_xorg_config"
        },
        "bbswitch_error": {
            "pattern": "bbswitch.*error|bbswitch.*failed",
            "description": "bbswitch module error",
            "solution": "Reload bbswitch module: sudo modprobe -r bbswitch && sudo modprobe bbswitch",
            "recovery_function": "reload_bbswitch_module"
        }
    },
    "power_errors": {
        "tlp_error": {
            "pattern": "tlp.*error|tlp.*failed",
            "description": "TLP power management error",
            "solution": "Check TLP configuration and restart service",
            "recovery_function": "recover_tlp_config"
        },
        "cpufreq_error": {
            "pattern": "cpufreq.*error|scaling.*failed",
            "description": "CPU frequency scaling error",
            "solution": "Check CPU governor settings and power management",
            "recovery_function": "recover_cpufreq_config"
        }
    },
    "hardware_errors": {
        "asus_hardware_error": {
            "pattern": "asus.*error|asusd.*failed|asusctl.*error",
            "description": "ASUS hardware control error",
            "solution": "Restart ASUS services: sudo systemctl restart asusd",
            "recovery_function": "recover_asus_services"
        },
        "thermal_error": {
            "pattern": "thermal.*throttling|overheating|temperature.*critical",
            "description": "Thermal management issue",
            "solution": "Check system cooling and reduce load",
            "recovery_function": "handle_thermal_issue"
        }
    }
}
EOF
    
    log_success "Error patterns file created: $ERROR_PATTERNS_FILE"
}

# Analyze error logs for patterns
analyze_error_logs() {
    local log_file="${1:-$ERROR_LOG_FILE}"
    local analysis_report="${ERROR_REPORT_DIR}/analysis_$(date +%Y%m%d_%H%M%S).json"
    
    log_info "Analyzing error logs: $log_file"
    
    if [[ ! -f "$log_file" ]]; then
        log_error "Log file not found: $log_file"
        return 1
    fi
    
    local error_matches=()
    local error_count=0
    
    # Read error patterns
    if [[ ! -f "$ERROR_PATTERNS_FILE" ]]; then
        log_warn "Error patterns file not found, creating default patterns"
        create_error_patterns_file
    fi
    
    # Analyze each error category
    local categories=($(jq -r 'keys[]' "$ERROR_PATTERNS_FILE" 2>/dev/null || echo ""))
    
    for category in $categories; do
        log_debug "Analyzing $category errors..."
        
        local patterns=$(jq -r ".$category | keys[]" "$ERROR_PATTERNS_FILE" 2>/dev/null || echo "")
        
        for pattern_name in $patterns; do
            local pattern=$(jq -r ".$category.$pattern_name.pattern" "$ERROR_PATTERNS_FILE" 2>/dev/null || echo "")
            local description=$(jq -r ".$category.$pattern_name.description" "$ERROR_PATTERNS_FILE" 2>/dev/null || echo "")
            local solution=$(jq -r ".$category.$pattern_name.solution" "$ERROR_PATTERNS_FILE" 2>/dev/null || echo "")
            local recovery_function=$(jq -r ".$category.$pattern_name.recovery_function" "$ERROR_PATTERNS_FILE" 2>/dev/null || echo "")
            
            if [[ -n "$pattern" ]]; then
                local matches=$(grep -iE "$pattern" "$log_file" | wc -l)
                if [[ $matches -gt 0 ]]; then
                    error_matches+=("{\"category\":\"$category\",\"pattern\":\"$pattern_name\",\"description\":\"$description\",\"solution\":\"$solution\",\"recovery_function\":\"$recovery_function\",\"matches\":$matches}")
                    error_count=$((error_count + matches))
                fi
            fi
        done
    done
    
    # Create analysis report
    local report_content="{"
    report_content+="\"timestamp\":\"$(date -Iseconds)\","
    report_content+="\"log_file\":\"$log_file\","
    report_content+="\"total_errors\":$error_count,"
    report_content+="\"error_patterns\":["
    
    if [[ ${#error_matches[@]} -gt 0 ]]; then
        report_content+=$(IFS=','; echo "${error_matches[*]}")
    fi
    
    report_content+="]}"
    
    echo "$report_content" | jq . > "$analysis_report" 2>/dev/null || {
        echo "$report_content" > "$analysis_report"
    }
    
    log_success "Error analysis completed: $analysis_report"
    
    # Display summary
    display_error_analysis "$analysis_report"
    
    return 0
}

# Display error analysis results
display_error_analysis() {
    local analysis_file="$1"
    
    if [[ ! -f "$analysis_file" ]]; then
        log_error "Analysis file not found: $analysis_file"
        return 1
    fi
    
    local total_errors=$(jq -r '.total_errors' "$analysis_file" 2>/dev/null || echo "0")
    local pattern_count=$(jq -r '.error_patterns | length' "$analysis_file" 2>/dev/null || echo "0")
    
    echo -e "\n${CYAN}Error Analysis Summary${NC}"
    echo "======================"
    echo "Total errors found: $total_errors"
    echo "Error patterns matched: $pattern_count"
    
    if [[ $pattern_count -gt 0 ]]; then
        echo -e "\n${YELLOW}Detected Error Patterns:${NC}"
        
        jq -r '.error_patterns[] | "Category: \(.category)\nPattern: \(.pattern)\nDescription: \(.description)\nMatches: \(.matches)\nSolution: \(.solution)\n---"' "$analysis_file" 2>/dev/null || {
            log_warn "Failed to parse analysis file with jq, showing raw content"
            cat "$analysis_file"
        }
    fi
}

# Generate comprehensive error report
generate_error_report() {
    local report_name="${1:-comprehensive}"
    local report_file="${ERROR_REPORT_DIR}/error_report_${report_name}_$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "Generating comprehensive error report: $report_name"
    
    {
        echo "ASUS ROG Zephyrus G14 Setup - Error Report"
        echo "=========================================="
        echo "Generated: $(date)"
        echo "Report Type: $report_name"
        echo "System: $(uname -a)"
        echo ""
        
        echo "System Information:"
        echo "------------------"
        echo "Hostname: $(hostname)"
        echo "Uptime: $(uptime -p)"
        echo "CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
        echo "Memory: $(free -h | grep Mem | awk '{print $2 " total, " $3 " used, " $7 " available"}')"
        echo "Disk Usage: $(df -h / | tail -1 | awk '{print $5 " used (" $3 "/" $2 ")"}')"
        echo ""
        
        echo "GPU Information:"
        echo "---------------"
        lspci | grep -E "(VGA|3D)"
        echo ""
        
        if command -v nvidia-smi >/dev/null 2>&1; then
            echo "NVIDIA GPU Status:"
            nvidia-smi 2>/dev/null || echo "nvidia-smi failed"
            echo ""
        fi
        
        echo "Loaded Kernel Modules:"
        echo "---------------------"
        lsmod | grep -E "(nvidia|amdgpu|bbswitch)" || echo "No GPU modules loaded"
        echo ""
        
        echo "Service Status:"
        echo "--------------"
        local services=("tlp" "auto-cpufreq" "asusd" "supergfxd" "nvidia-suspend" "nvidia-resume")
        for service in "${services[@]}"; do
            local status=$(systemctl is-active "$service" 2>/dev/null || echo "not-found")
            local enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "not-found")
            echo "$service: $status ($enabled)"
        done
        echo ""
        
        echo "Recent Error Log Entries:"
        echo "------------------------"
        if [[ -f "$ERROR_LOG_FILE" ]]; then
            tail -50 "$ERROR_LOG_FILE" | grep -E "(ERROR|FAIL)" || echo "No recent errors found"
        else
            echo "Error log file not found"
        fi
        echo ""
        
        echo "System Journal Errors (Last 24 hours):"
        echo "--------------------------------------"
        journalctl --since "24 hours ago" --priority=err --no-pager | tail -20 || echo "No journal errors found"
        echo ""
        
        echo "GPU-Related Journal Entries:"
        echo "---------------------------"
        journalctl --since "24 hours ago" --no-pager | grep -iE "(nvidia|amdgpu|gpu|bbswitch)" | tail -20 || echo "No GPU-related entries found"
        echo ""
        
        echo "Power Management Status:"
        echo "-----------------------"
        if command -v tlp-stat >/dev/null 2>&1; then
            tlp-stat -s 2>/dev/null || echo "TLP status unavailable"
        fi
        
        local cpu_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
        echo "CPU Governor: $cpu_governor"
        
        if [[ -f /proc/acpi/bbswitch ]]; then
            echo "NVIDIA GPU State: $(cat /proc/acpi/bbswitch)"
        fi
        echo ""
        
        echo "Configuration Files Status:"
        echo "---------------------------"
        local config_files=(
            "/etc/X11/xorg.conf.d/10-hybrid.conf"
            "/etc/tlp.conf"
            "/etc/auto-cpufreq.conf"
            "/etc/pacman.conf"
        )
        
        for config in "${config_files[@]}"; do
            if [[ -f "$config" ]]; then
                echo "$config: exists ($(stat -c %Y "$config" | xargs -I {} date -d @{}))"
            else
                echo "$config: missing"
            fi
        done
        echo ""
        
        echo "Package Information:"
        echo "-------------------"
        local packages=("nvidia" "nvidia-utils" "mesa" "tlp" "auto-cpufreq" "asusctl" "supergfxctl")
        for package in "${packages[@]}"; do
            local version=$(pacman -Q "$package" 2>/dev/null || echo "not installed")
            echo "$package: $version"
        done
        echo ""
        
        echo "Error Analysis:"
        echo "--------------"
        if [[ -f "$ERROR_LOG_FILE" ]]; then
            local temp_analysis="/tmp/error_analysis_$$.json"
            if analyze_error_logs "$ERROR_LOG_FILE" >/dev/null 2>&1; then
                local latest_analysis=$(ls -t "${ERROR_REPORT_DIR}"/analysis_*.json 2>/dev/null | head -1)
                if [[ -n "$latest_analysis" ]]; then
                    display_error_analysis "$latest_analysis"
                fi
            fi
        fi
        
    } > "$report_file"
    
    log_success "Error report generated: $report_file"
    echo -e "\n${GREEN}Error report saved to: $report_file${NC}"
    
    return 0
}

# Automated error resolution
resolve_detected_errors() {
    local analysis_file="${1:-}"
    
    if [[ -z "$analysis_file" ]]; then
        # Generate new analysis
        local temp_analysis="/tmp/error_analysis_$$.json"
        if ! analyze_error_logs "$ERROR_LOG_FILE" >/dev/null 2>&1; then
            log_error "Failed to analyze error logs"
            return 1
        fi
        analysis_file=$(ls -t "${ERROR_REPORT_DIR}"/analysis_*.json 2>/dev/null | head -1)
    fi
    
    if [[ ! -f "$analysis_file" ]]; then
        log_error "Analysis file not found: $analysis_file"
        return 1
    fi
    
    log_info "Attempting automated error resolution..."
    
    # Create rollback point before attempting fixes
    create_rollback_point "error-resolution" "Before automated error resolution" || {
        log_warn "Failed to create rollback point"
    }
    
    local resolution_count=0
    local resolution_failures=0
    
    # Get recovery functions from analysis
    local recovery_functions=($(jq -r '.error_patterns[].recovery_function' "$analysis_file" 2>/dev/null | sort -u))
    
    for recovery_function in "${recovery_functions[@]}"; do
        if [[ "$recovery_function" != "null" ]] && [[ -n "$recovery_function" ]]; then
            log_info "Executing recovery function: $recovery_function"
            
            if command -v "$recovery_function" >/dev/null 2>&1; then
                if "$recovery_function"; then
                    log_success "Recovery function succeeded: $recovery_function"
                    ((resolution_count++))
                else
                    log_error "Recovery function failed: $recovery_function"
                    ((resolution_failures++))
                fi
            else
                log_warn "Recovery function not found: $recovery_function"
                ((resolution_failures++))
            fi
        fi
    done
    
    log_info "Automated error resolution completed"
    log_info "Successful resolutions: $resolution_count"
    log_info "Failed resolutions: $resolution_failures"
    
    if [[ $resolution_failures -eq 0 ]]; then
        log_success "All detected errors resolved successfully"
        return 0
    else
        log_warn "Some errors could not be resolved automatically"
        return 1
    fi
}

# Interactive error resolution
interactive_error_resolution() {
    log_info "Starting interactive error resolution..."
    
    # Generate fresh analysis
    if ! analyze_error_logs "$ERROR_LOG_FILE"; then
        log_error "Failed to analyze error logs"
        return 1
    fi
    
    local latest_analysis=$(ls -t "${ERROR_REPORT_DIR}"/analysis_*.json 2>/dev/null | head -1)
    
    if [[ ! -f "$latest_analysis" ]]; then
        log_error "No error analysis available"
        return 1
    fi
    
    local error_count=$(jq -r '.error_patterns | length' "$latest_analysis" 2>/dev/null || echo "0")
    
    if [[ $error_count -eq 0 ]]; then
        log_success "No errors detected in logs"
        return 0
    fi
    
    echo -e "\n${YELLOW}Interactive Error Resolution${NC}"
    echo "============================"
    echo "Found $error_count error pattern(s) in logs"
    echo ""
    
    # Display error patterns with options
    local pattern_index=0
    while [[ $pattern_index -lt $error_count ]]; do
        local category=$(jq -r ".error_patterns[$pattern_index].category" "$latest_analysis" 2>/dev/null)
        local pattern=$(jq -r ".error_patterns[$pattern_index].pattern" "$latest_analysis" 2>/dev/null)
        local description=$(jq -r ".error_patterns[$pattern_index].description" "$latest_analysis" 2>/dev/null)
        local solution=$(jq -r ".error_patterns[$pattern_index].solution" "$latest_analysis" 2>/dev/null)
        local recovery_function=$(jq -r ".error_patterns[$pattern_index].recovery_function" "$latest_analysis" 2>/dev/null)
        local matches=$(jq -r ".error_patterns[$pattern_index].matches" "$latest_analysis" 2>/dev/null)
        
        echo -e "${CYAN}Error $((pattern_index + 1))/$error_count:${NC}"
        echo "Category: $category"
        echo "Description: $description"
        echo "Occurrences: $matches"
        echo "Suggested solution: $solution"
        echo ""
        
        if [[ "$recovery_function" != "null" ]] && [[ -n "$recovery_function" ]]; then
            echo "Available actions:"
            echo "1. Apply automated fix ($recovery_function)"
            echo "2. Skip this error"
            echo "3. Show manual solution"
            echo "4. Exit resolution"
            
            read -p "Select action (1-4): " action
            
            case "$action" in
                1)
                    log_info "Applying automated fix: $recovery_function"
                    if command -v "$recovery_function" >/dev/null 2>&1; then
                        if "$recovery_function"; then
                            log_success "Automated fix applied successfully"
                        else
                            log_error "Automated fix failed"
                        fi
                    else
                        log_error "Recovery function not available: $recovery_function"
                    fi
                    ;;
                2)
                    log_info "Skipping error resolution"
                    ;;
                3)
                    echo -e "\n${YELLOW}Manual Solution:${NC}"
                    echo "$solution"
                    echo ""
                    read -p "Press Enter to continue..."
                    ;;
                4)
                    log_info "Exiting error resolution"
                    return 0
                    ;;
                *)
                    log_warn "Invalid selection, skipping..."
                    ;;
            esac
        else
            echo "No automated fix available. Manual solution:"
            echo "$solution"
            echo ""
            read -p "Press Enter to continue to next error..."
        fi
        
        echo ""
        ((pattern_index++))
    done
    
    log_success "Interactive error resolution completed"
}

# Main function
main() {
    case "${1:-}" in
        "init")
            init_error_reporting
            ;;
        "analyze")
            local log_file="${2:-$ERROR_LOG_FILE}"
            analyze_error_logs "$log_file"
            ;;
        "report")
            local report_name="${2:-comprehensive}"
            generate_error_report "$report_name"
            ;;
        "resolve")
            local analysis_file="${2:-}"
            resolve_detected_errors "$analysis_file"
            ;;
        "interactive")
            interactive_error_resolution
            ;;
        "help"|"--help"|"-h")
            cat << EOF
Usage: $0 <command> [options]

Commands:
    init                    Initialize error reporting system
    analyze [log_file]      Analyze error logs for patterns
    report [name]           Generate comprehensive error report
    resolve [analysis]      Attempt automated error resolution
    interactive             Interactive error resolution
    help                    Show this help message

Examples:
    $0 analyze
    $0 analyze /var/log/custom.log
    $0 report gpu-issues
    $0 resolve
    $0 interactive

EOF
            ;;
        *)
            log_error "Unknown command: ${1:-}. Use 'help' for usage information."
            exit 1
            ;;
    esac
}

# Initialize error reporting system if not already done
if [[ ! -d "$ERROR_REPORT_DIR" ]]; then
    init_error_reporting
fi

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi