#!/bin/bash

# NVIDIA GPU Suspend/Resume Handler Script
# Handles proper NVIDIA GPU power management during system suspend/resume

set -euo pipefail

# Source error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/var/log/nvidia-suspend.log"
readonly BBSWITCH_PATH="/proc/acpi/bbswitch"
readonly NVIDIA_MODULES=("nvidia_uvm" "nvidia_drm" "nvidia_modeset" "nvidia")
readonly STATE_FILE="/tmp/nvidia-pre-suspend-state"
readonly LOCK_FILE="/tmp/nvidia-suspend.lock"

# Global variables for error tracking
NVIDIA_SUSPEND_FAILED=()
CRITICAL_SUSPEND_FAILURES=false

# Recovery functions
recover_nvidia_module_unload() {
    local module="$1"
    
    log_info "Attempting to recover NVIDIA module unload: $module"
    
    # Find processes using the module
    local processes=$(lsof "/dev/nvidia*" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u || true)
    
    if [[ -n "$processes" ]]; then
        log_warn "Found processes using NVIDIA devices: $processes"
        
        # Try to terminate processes gracefully
        for pid in $processes; do
            if kill -TERM "$pid" 2>/dev/null; then
                log_info "Sent TERM signal to process $pid"
            fi
        done
        
        # Wait a moment for processes to terminate
        sleep 2
        
        # Check if processes are still running and force kill if necessary
        for pid in $processes; do
            if kill -0 "$pid" 2>/dev/null; then
                log_warn "Process $pid still running, sending KILL signal"
                kill -KILL "$pid" 2>/dev/null || true
            fi
        done
        
        sleep 1
        return 0
    fi
    
    return 1
}

acquire_suspend_lock() {
    local timeout="${1:-30}"
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            log_debug "Acquired suspend lock"
            return 0
        fi
        
        # Check if lock is stale
        if [[ -f "$LOCK_FILE" ]]; then
            local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
                log_warn "Removing stale suspend lock (PID: $lock_pid)"
                rm -f "$LOCK_FILE"
                continue
            fi
        fi
        
        log_debug "Waiting for suspend lock... ($count/$timeout)"
        sleep 1
        ((count++))
    done
    
    log_error "Failed to acquire suspend lock after $timeout seconds"
    return 1
}

release_suspend_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ "$lock_pid" == "$$" ]]; then
            rm -f "$LOCK_FILE"
            log_debug "Released suspend lock"
        else
            log_warn "Lock file exists but PID doesn't match (expected: $$, found: $lock_pid)"
        fi
    fi
}

validate_nvidia_suspend_state() {
    log_debug "Validating NVIDIA suspend state..."
    
    local validation_errors=()
    
    # Check if bbswitch is available
    if ! check_bbswitch; then
        validation_errors+=("bbswitch not available")
    fi
    
    # Check if NVIDIA modules are available
    for module in "${NVIDIA_MODULES[@]}"; do
        if ! modinfo "$module" &>/dev/null; then
            validation_errors+=("NVIDIA module not available: $module")
        fi
    done
    
    # Check if state file directory is writable
    local state_dir=$(dirname "$STATE_FILE")
    if [[ ! -w "$state_dir" ]]; then
        validation_errors+=("Cannot write to state directory: $state_dir")
    fi
    
    if [[ ${#validation_errors[@]} -eq 0 ]]; then
        log_debug "NVIDIA suspend state validation passed"
        return 0
    else
        log_error "NVIDIA suspend state validation failed:"
        for error in "${validation_errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
}

# Check if bbswitch is available with enhanced validation
check_bbswitch() {
    if [[ -f "$BBSWITCH_PATH" ]]; then
        # Verify bbswitch is readable and writable
        if [[ -r "$BBSWITCH_PATH" && -w "$BBSWITCH_PATH" ]]; then
            return 0
        else
            log_error "bbswitch exists but is not accessible (permissions issue)" "bbswitch-permissions"
            return 1
        fi
    else
        log_warn "bbswitch not available at $BBSWITCH_PATH" "bbswitch-missing"
        return 1
    fi
}

# Get current NVIDIA GPU power state
get_nvidia_power_state() {
    if check_bbswitch; then
        cat "$BBSWITCH_PATH" 2>/dev/null | grep -o "ON\|OFF" || echo "UNKNOWN"
    else
        echo "UNKNOWN"
    fi
}

# Set NVIDIA GPU power state with enhanced error handling and retry logic
set_nvidia_power_state() {
    local state="$1"
    local max_retries="${2:-3}"
    local retry_count=0
    
    if ! check_bbswitch; then
        NVIDIA_SUSPEND_FAILED+=("bbswitch-unavailable")
        log_warn "Cannot set NVIDIA power state: bbswitch not available"
        return 1
    fi
    
    if [[ "$state" != "ON" && "$state" != "OFF" ]]; then
        NVIDIA_SUSPEND_FAILED+=("invalid-power-state")
        log_error "Invalid power state: $state (must be ON or OFF)" "power-state-validation"
        return 1
    fi
    
    local current_state=$(get_nvidia_power_state)
    if [[ "$current_state" == "$state" ]]; then
        log_info "NVIDIA GPU already in $state state"
        return 0
    fi
    
    log_info "Setting NVIDIA GPU power state to $state"
    
    while [[ $retry_count -lt $max_retries ]]; do
        local error_output
        if error_output=$(echo "$state" 2>&1 | sudo tee "$BBSWITCH_PATH" >/dev/null); then
            # Verify the state was actually set
            sleep 1
            local new_state=$(get_nvidia_power_state)
            if [[ "$new_state" == "$state" ]]; then
                log_success "Successfully set NVIDIA GPU to $state"
                return 0
            else
                log_warn "Power state command succeeded but verification failed (expected: $state, actual: $new_state)"
            fi
        else
            retry_count=$((retry_count + 1))
            log_warn "Failed to set NVIDIA GPU power state to $state (attempt $retry_count/$max_retries): $error_output"
            
            if [[ $retry_count -lt $max_retries ]]; then
                log_info "Retrying in 2 seconds..."
                sleep 2
            fi
        fi
    done
    
    NVIDIA_SUSPEND_FAILED+=("power-state-set-failed")
    log_error "Failed to set NVIDIA GPU power state to $state after $max_retries attempts"
    return 1
}

# Unload NVIDIA kernel modules with enhanced error handling
unload_nvidia_modules() {
    log_info "Unloading NVIDIA kernel modules..."
    
    local failed_modules=()
    local max_retries=3
    
    for module in "${NVIDIA_MODULES[@]}"; do
        if lsmod | grep -q "^$module "; then
            log_info "Unloading module: $module"
            
            local retry_count=0
            local unload_success=false
            
            while [[ $retry_count -lt $max_retries ]]; do
                local error_output
                if error_output=$(sudo modprobe -r "$module" 2>&1); then
                    log_success "Successfully unloaded: $module"
                    unload_success=true
                    break
                else
                    retry_count=$((retry_count + 1))
                    log_warn "Failed to unload module $module (attempt $retry_count/$max_retries): $error_output"
                    
                    if [[ $retry_count -lt $max_retries ]]; then
                        # Try to force kill processes using the module
                        if recover_nvidia_module_unload "$module"; then
                            log_info "Attempted module recovery, retrying..."
                            sleep 1
                        else
                            sleep 2
                        fi
                    fi
                fi
            done
            
            if [[ "$unload_success" == false ]]; then
                failed_modules+=("$module")
                NVIDIA_SUSPEND_FAILED+=("module-unload-$module")
            fi
        else
            log_debug "Module $module not loaded"
        fi
    done
    
    if [[ ${#failed_modules[@]} -gt 0 ]]; then
        log_warn "Failed to unload NVIDIA modules: ${failed_modules[*]}"
        log_warn "This may prevent proper GPU power management during suspend"
        return 1
    fi
    
    return 0
}

# Load NVIDIA kernel modules
load_nvidia_modules() {
    log "INFO" "Loading NVIDIA kernel modules..."
    
    # Load modules in reverse order
    local reversed_modules=()
    for ((i=${#NVIDIA_MODULES[@]}-1; i>=0; i--)); do
        reversed_modules+=("${NVIDIA_MODULES[i]}")
    done
    
    for module in "${reversed_modules[@]}"; do
        if ! lsmod | grep -q "^$module "; then
            log "INFO" "Loading module: $module"
            if modprobe "$module" 2>/dev/null; then
                log "INFO" "Successfully loaded: $module"
            else
                log "WARN" "Failed to load module: $module"
            fi
        else
            log "INFO" "Module $module already loaded"
        fi
    done
}

# Handle suspend operation
handle_suspend() {
    log "INFO" "=== NVIDIA Suspend Handler Started ==="
    
    local current_state=$(get_nvidia_power_state)
    log "INFO" "Current NVIDIA GPU state: $current_state"
    
    # Save current state for resume
    echo "$current_state" > "/tmp/nvidia-pre-suspend-state"
    
    # If GPU is ON, turn it OFF and unload modules
    if [[ "$current_state" == "ON" ]]; then
        log "INFO" "Preparing NVIDIA GPU for suspend..."
        
        # Unload NVIDIA modules first
        unload_nvidia_modules
        
        # Wait a moment for modules to fully unload
        sleep 2
        
        # Turn off GPU
        set_nvidia_power_state "OFF"
        
        log "INFO" "NVIDIA GPU prepared for suspend"
    else
        log "INFO" "NVIDIA GPU already OFF, no action needed"
    fi
    
    log "INFO" "=== NVIDIA Suspend Handler Completed ==="
}

# Handle resume operation
handle_resume() {
    log "INFO" "=== NVIDIA Resume Handler Started ==="
    
    # Read pre-suspend state
    local pre_suspend_state="OFF"
    if [[ -f "/tmp/nvidia-pre-suspend-state" ]]; then
        pre_suspend_state=$(cat "/tmp/nvidia-pre-suspend-state")
        rm -f "/tmp/nvidia-pre-suspend-state"
    fi
    
    log "INFO" "Pre-suspend NVIDIA GPU state was: $pre_suspend_state"
    
    local current_state=$(get_nvidia_power_state)
    log "INFO" "Current NVIDIA GPU state: $current_state"
    
    # If GPU was ON before suspend, restore it
    if [[ "$pre_suspend_state" == "ON" ]]; then
        log "INFO" "Restoring NVIDIA GPU to ON state..."
        
        # Turn on GPU
        set_nvidia_power_state "ON"
        
        # Wait a moment for GPU to power up
        sleep 2
        
        # Load NVIDIA modules
        load_nvidia_modules
        
        log "INFO" "NVIDIA GPU restored to ON state"
    else
        log "INFO" "NVIDIA GPU was OFF before suspend, keeping it OFF"
    fi
    
    log "INFO" "=== NVIDIA Resume Handler Completed ==="
}

# Main function
main() {
    local action="${1:-}"
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    case "$action" in
        "suspend")
            handle_suspend
            ;;
        "resume")
            handle_resume
            ;;
        *)
            log "ERROR" "Usage: $SCRIPT_NAME {suspend|resume}"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"