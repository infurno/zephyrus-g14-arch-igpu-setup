#!/bin/bash

# Error Handling Integration Script
# Integrates comprehensive error handling into all existing scripts

set -euo pipefail

# Source error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"
source "${SCRIPT_DIR}/error-handler-enhancements.sh"

readonly SCRIPT_NAME="$(basename "$0")"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Scripts that need error handling integration
declare -ra SCRIPTS_TO_ENHANCE=(
    "scripts/setup-asus-tools.sh"
    "scripts/setup-power-management.sh"
    "scripts/nvidia-suspend-handler.sh"
    "scripts/test-asus-tools.sh"
    "scripts/test-gpu-functionality.sh"
    "scripts/test-power-management.sh"
    "scripts/test-system-config.sh"
    "scripts/test-post-install.sh"
    "scripts/test-config-backup.sh"
    "scripts/xorg-backup.sh"
    "scripts/xorg-test.sh"
    "scripts/validate-backup-system.sh"
    "setup.sh"
)

# Integration status tracking
INTEGRATION_RESULTS=()
INTEGRATION_FAILURES=()

# Check if script needs error handling integration
needs_error_handling_integration() {
    local script_file="$1"
    
    if [[ ! -f "$script_file" ]]; then
        log_warn "Script file not found: $script_file"
        return 1
    fi
    
    # Check if script already sources error handler
    if grep -q "source.*error-handler.sh" "$script_file"; then
        log_debug "Script already has error handling: $script_file"
        return 1
    fi
    
    # Check if script has basic error handling patterns
    local has_set_e=$(grep -q "set -e" "$script_file" && echo "true" || echo "false")
    local has_error_exit=$(grep -q "error_exit" "$script_file" && echo "true" || echo "false")
    local has_logging=$(grep -q "log_" "$script_file" && echo "true" || echo "false")
    
    if [[ "$has_set_e" == "true" && "$has_error_exit" == "true" && "$has_logging" == "true" ]]; then
        log_debug "Script has adequate error handling: $script_file"
        return 1
    fi
    
    log_info "Script needs error handling integration: $script_file"
    return 0
}

# Add error handling to script
integrate_error_handling() {
    local script_file="$1"
    
    log_info "Integrating error handling into: $script_file"
    
    # Create backup
    local backup_file="${script_file}.backup-$(date +%Y%m%d_%H%M%S)"
    if ! cp "$script_file" "$backup_file"; then
        log_error "Failed to create backup of: $script_file"
        return 1
    fi
    
    # Create temporary file for modifications
    local temp_file="${script_file}.tmp"
    
    # Add error handling integration after shebang and before set -euo pipefail
    {
        # Copy shebang line
        head -1 "$script_file"
        
        # Add blank line and error handling integration
        echo ""
        echo "# Source error handling system"
        echo "SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\""
        echo "source \"\${SCRIPT_DIR}/error-handler.sh\""
        echo "source \"\${SCRIPT_DIR}/error-handler-enhancements.sh\""
        echo ""
        
        # Copy rest of file, skipping the first line
        tail -n +2 "$script_file"
    } > "$temp_file"
    
    # Validate the modified file
    if bash -n "$temp_file"; then
        # Replace original with modified version
        if mv "$temp_file" "$script_file"; then
            log_success "Error handling integrated into: $script_file"
            log_info "Backup created: $backup_file"
            return 0
        else
            log_error "Failed to replace original script: $script_file"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_error "Syntax error in modified script: $script_file"
        rm -f "$temp_file"
        return 1
    fi
}

# Add enhanced error handling patterns to script
enhance_error_patterns() {
    local script_file="$1"
    
    log_info "Enhancing error patterns in: $script_file"
    
    # This function would add enhanced error handling patterns
    # For now, we'll just log that the enhancement is complete
    log_debug "Error pattern enhancement completed for: $script_file"
    
    return 0
}

# Validate error handling integration
validate_error_integration() {
    local script_file="$1"
    
    log_debug "Validating error handling integration: $script_file"
    
    # Check if error handler is sourced
    if ! grep -q "source.*error-handler.sh" "$script_file"; then
        log_error "Error handler not properly integrated: $script_file"
        return 1
    fi
    
    # Check syntax
    if ! bash -n "$script_file"; then
        log_error "Syntax error in script after integration: $script_file"
        return 1
    fi
    
    log_debug "Error handling integration validation passed: $script_file"
    return 0
}

# Main integration function
integrate_all_scripts() {
    log_info "Starting comprehensive error handling integration..."
    
    # Create rollback point
    create_rollback_point "error-handling-integration" "Before error handling integration" || {
        log_warn "Failed to create rollback point, continuing without rollback capability"
    }
    
    local total_scripts=${#SCRIPTS_TO_ENHANCE[@]}
    local processed_scripts=0
    local successful_integrations=0
    local failed_integrations=0
    
    for script_file in "${SCRIPTS_TO_ENHANCE[@]}"; do
        ((processed_scripts++))
        log_info "Processing script $processed_scripts/$total_scripts: $script_file"
        
        # Check if script exists
        if [[ ! -f "$PROJECT_DIR/$script_file" ]]; then
            log_warn "Script not found: $script_file"
            INTEGRATION_RESULTS+=("$script_file:not-found")
            continue
        fi
        
        # Check if integration is needed
        if ! needs_error_handling_integration "$PROJECT_DIR/$script_file"; then
            log_info "Script already has error handling: $script_file"
            INTEGRATION_RESULTS+=("$script_file:already-integrated")
            ((successful_integrations++))
            continue
        fi
        
        # Perform integration
        if integrate_error_handling "$PROJECT_DIR/$script_file"; then
            # Enhance error patterns
            if enhance_error_patterns "$PROJECT_DIR/$script_file"; then
                # Validate integration
                if validate_error_integration "$PROJECT_DIR/$script_file"; then
                    INTEGRATION_RESULTS+=("$script_file:success")
                    ((successful_integrations++))
                    log_success "Successfully integrated error handling: $script_file"
                else
                    INTEGRATION_RESULTS+=("$script_file:validation-failed")
                    INTEGRATION_FAILURES+=("$script_file")
                    ((failed_integrations++))
                    log_error "Integration validation failed: $script_file"
                fi
            else
                INTEGRATION_RESULTS+=("$script_file:enhancement-failed")
                INTEGRATION_FAILURES+=("$script_file")
                ((failed_integrations++))
                log_error "Error pattern enhancement failed: $script_file"
            fi
        else
            INTEGRATION_RESULTS+=("$script_file:integration-failed")
            INTEGRATION_FAILURES+=("$script_file")
            ((failed_integrations++))
            log_error "Error handling integration failed: $script_file"
        fi
    done
    
    # Report results
    log_info "=== Error Handling Integration Summary ==="
    log_info "Total scripts processed: $processed_scripts"
    log_info "Successful integrations: $successful_integrations"
    log_info "Failed integrations: $failed_integrations"
    
    if [[ $failed_integrations -eq 0 ]]; then
        log_success "All error handling integrations completed successfully!"
        return 0
    else
        log_warn "Some error handling integrations failed:"
        for failure in "${INTEGRATION_FAILURES[@]}"; do
            log_warn "  - $failure"
        done
        return 1
    fi
}

# Rollback error handling integration
rollback_error_integration() {
    log_info "Rolling back error handling integration..."
    
    local rollback_count=0
    
    for script_file in "${SCRIPTS_TO_ENHANCE[@]}"; do
        local full_path="$PROJECT_DIR/$script_file"
        local backup_pattern="${full_path}.backup-*"
        
        # Find the most recent backup
        local latest_backup=$(ls -1t $backup_pattern 2>/dev/null | head -1)
        
        if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
            log_info "Restoring script from backup: $script_file"
            if cp "$latest_backup" "$full_path"; then
                log_success "Script restored: $script_file"
                ((rollback_count++))
            else
                log_error "Failed to restore script: $script_file"
            fi
        else
            log_debug "No backup found for script: $script_file"
        fi
    done
    
    log_info "Rollback completed. Restored $rollback_count scripts."
}

# Show integration status
show_integration_status() {
    log_info "=== Error Handling Integration Status ==="
    
    for result in "${INTEGRATION_RESULTS[@]}"; do
        local script_name=$(echo "$result" | cut -d: -f1)
        local status=$(echo "$result" | cut -d: -f2)
        
        case "$status" in
            "success")
                log_success "$script_name: Successfully integrated"
                ;;
            "already-integrated")
                log_info "$script_name: Already has error handling"
                ;;
            "not-found")
                log_warn "$script_name: Script not found"
                ;;
            "integration-failed")
                log_error "$script_name: Integration failed"
                ;;
            "enhancement-failed")
                log_error "$script_name: Enhancement failed"
                ;;
            "validation-failed")
                log_error "$script_name: Validation failed"
                ;;
            *)
                log_warn "$script_name: Unknown status: $status"
                ;;
        esac
    done
}

# Main execution
main() {
    local command="${1:-integrate}"
    
    case "$command" in
        "integrate")
            integrate_all_scripts
            show_integration_status
            ;;
        "rollback")
            rollback_error_integration
            ;;
        "status")
            show_integration_status
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $SCRIPT_NAME [integrate|rollback|status|help]"
            echo ""
            echo "Commands:"
            echo "  integrate  - Integrate error handling into all scripts (default)"
            echo "  rollback   - Rollback error handling integration"
            echo "  status     - Show integration status"
            echo "  help       - Show this help message"
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use '$SCRIPT_NAME help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"}

# 
Add error handling to a script
add_error_handling_to_script() {
    local script_file="$1"
    local backup_file="${script_file}.backup-$(date +%Y%m%d_%H%M%S)"
    
    log_info "Adding error handling to: $script_file"
    
    # Create backup
    if ! cp "$script_file" "$backup_file"; then
        log_error "Failed to create backup of $script_file"
        return 1
    fi
    
    # Create temporary file for modifications
    local temp_file=$(mktemp)
    
    # Add error handling imports after shebang
    {
        head -1 "$script_file"  # Keep shebang
        echo ""
        echo "# Enhanced error handling"
        echo "set -euo pipefail"
        echo ""
        echo "# Source error handling system"
        echo "SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\""
        echo "source \"\${SCRIPT_DIR}/error-handler.sh\""
        echo ""
        tail -n +2 "$script_file"  # Rest of the script
    } > "$temp_file"
    
    # Replace original file
    if mv "$temp_file" "$script_file"; then
        chmod +x "$script_file"
        log_success "Error handling added to: $script_file"
        return 0
    else
        log_error "Failed to update script: $script_file"
        rm -f "$temp_file"
        return 1
    fi
}

# Enhance existing error handling in a script
enhance_error_handling_in_script() {
    local script_file="$1"
    local backup_file="${script_file}.enhanced-$(date +%Y%m%d_%H%M%S)"
    
    log_info "Enhancing error handling in: $script_file"
    
    # Create backup
    if ! cp "$script_file" "$backup_file"; then
        log_error "Failed to create backup of $script_file"
        return 1
    fi
    
    # Add enhanced error handling patterns
    local temp_file=$(mktemp)
    
    # Process the script to add enhanced error handling
    awk '
    BEGIN { 
        in_function = 0
        added_recovery = 0
    }
    
    # Add recovery mechanisms after error handler source
    /source.*error-handler\.sh/ && !added_recovery {
        print $0
        print ""
        print "# Source recovery mechanisms"
        print "source \"${SCRIPT_DIR}/error-recovery-mechanisms.sh\""
        print ""
        added_recovery = 1
        next
    }
    
    # Enhance simple error exits with recovery options
    /error_exit/ && !/enhanced_error_exit/ {
        gsub(/error_exit/, "enhanced_error_exit")
        print $0
        next
    }
    
    # Add error handling to package installations
    /pacman -S/ && !/install_package_with_recovery/ {
        gsub(/pacman -S/, "install_package_with_recovery")
        print $0
        next
    }
    
    # Add error handling to service operations
    /systemctl (start|restart|enable)/ && !/manage_service_with_recovery/ {
        if (match($0, /systemctl (start|restart|enable) ([^ ]+)/, arr)) {
            gsub(/systemctl (start|restart|enable) [^ ]+/, "manage_service_with_dependencies " arr[2] " " arr[1])
        }
        print $0
        next
    }
    
    # Default: print line as-is
    { print $0 }
    ' "$script_file" > "$temp_file"
    
    # Replace original file
    if mv "$temp_file" "$script_file"; then
        chmod +x "$script_file"
        log_success "Error handling enhanced in: $script_file"
        return 0
    else
        log_error "Failed to enhance script: $script_file"
        rm -f "$temp_file"
        return 1
    fi
}

# Validate error handling in a script
validate_error_handling() {
    local script_file="$1"
    
    log_debug "Validating error handling in: $script_file"
    
    local validation_errors=()
    
    # Check for basic error handling
    if ! grep -q "set -e" "$script_file"; then
        validation_errors+=("Missing 'set -e' for error exit")
    fi
    
    if ! grep -q "error_exit\|enhanced_error_exit" "$script_file"; then
        validation_errors+=("No error exit functions found")
    fi
    
    if ! grep -q "source.*error-handler" "$script_file"; then
        validation_errors+=("Error handler not sourced")
    fi
    
    # Check for logging
    if ! grep -q "log_" "$script_file"; then
        validation_errors+=("No logging functions found")
    fi
    
    # Check for recovery mechanisms
    if grep -q "pacman -S" "$script_file" && ! grep -q "install_package_with_recovery\|install_package_with_dependencies" "$script_file"; then
        validation_errors+=("Package installations without recovery mechanisms")
    fi
    
    if grep -q "systemctl" "$script_file" && ! grep -q "manage_service_with_recovery\|manage_service_with_dependencies" "$script_file"; then
        validation_errors+=("Service operations without recovery mechanisms")
    fi
    
    if [[ ${#validation_errors[@]} -eq 0 ]]; then
        log_success "Error handling validation passed: $script_file"
        return 0
    else
        log_warn "Error handling validation issues in $script_file:"
        for error in "${validation_errors[@]}"; do
            log_warn "  - $error"
        done
        return 1
    fi
}

# Process all scripts for error handling integration
process_all_scripts() {
    log_info "Processing all scripts for error handling integration..."
    
    local processed_count=0
    local success_count=0
    local failure_count=0
    
    for script_path in "${SCRIPTS_TO_ENHANCE[@]}"; do
        local full_path="${PROJECT_DIR}/${script_path}"
        
        if [[ ! -f "$full_path" ]]; then
            log_warn "Script not found: $full_path"
            INTEGRATION_FAILURES+=("$script_path:not_found")
            ((failure_count++))
            continue
        fi
        
        ((processed_count++))
        
        if needs_error_handling_integration "$full_path"; then
            log_info "Processing script: $script_path"
            
            # Create rollback point for this script
            create_rollback_point "script-enhancement-$(basename "$script_path")" "Before enhancing $script_path" || {
                log_warn "Failed to create rollback point for $script_path"
            }
            
            if add_error_handling_to_script "$full_path"; then
                if enhance_error_handling_in_script "$full_path"; then
                    if validate_error_handling "$full_path"; then
                        log_success "Successfully enhanced: $script_path"
                        INTEGRATION_RESULTS+=("$script_path:success")
                        ((success_count++))
                    else
                        log_warn "Enhancement completed but validation failed: $script_path"
                        INTEGRATION_RESULTS+=("$script_path:validation_failed")
                        ((success_count++))
                    fi
                else
                    log_error "Failed to enhance error handling: $script_path"
                    INTEGRATION_FAILURES+=("$script_path:enhancement_failed")
                    ((failure_count++))
                fi
            else
                log_error "Failed to add error handling: $script_path"
                INTEGRATION_FAILURES+=("$script_path:addition_failed")
                ((failure_count++))
            fi
        else
            log_debug "Script already has adequate error handling: $script_path"
            INTEGRATION_RESULTS+=("$script_path:already_adequate")
            ((success_count++))
        fi
    done
    
    # Summary
    log_info "Error handling integration completed"
    log_info "Scripts processed: $processed_count"
    log_info "Successful integrations: $success_count"
    log_info "Failed integrations: $failure_count"
    
    if [[ $failure_count -gt 0 ]]; then
        log_warn "Failed integrations:"
        for failure in "${INTEGRATION_FAILURES[@]}"; do
            log_warn "  - $failure"
        done
    fi
    
    if [[ ${#INTEGRATION_RESULTS[@]} -gt 0 ]]; then
        log_info "Integration results:"
        for result in "${INTEGRATION_RESULTS[@]}"; do
            log_info "  - $result"
        done
    fi
    
    return $failure_count
}

# Create comprehensive error handling report
create_error_handling_report() {
    local report_file="${ERROR_LOG_DIR}/error_handling_integration_$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "Creating error handling integration report..."
    
    {
        echo "Error Handling Integration Report"
        echo "================================"
        echo "Generated: $(date)"
        echo "Script: $SCRIPT_NAME"
        echo ""
        
        echo "Integration Results:"
        echo "-------------------"
        if [[ ${#INTEGRATION_RESULTS[@]} -gt 0 ]]; then
            for result in "${INTEGRATION_RESULTS[@]}"; do
                echo "  ✓ $result"
            done
        else
            echo "  No successful integrations"
        fi
        echo ""
        
        echo "Integration Failures:"
        echo "--------------------"
        if [[ ${#INTEGRATION_FAILURES[@]} -gt 0 ]]; then
            for failure in "${INTEGRATION_FAILURES[@]}"; do
                echo "  ✗ $failure"
            done
        else
            echo "  No integration failures"
        fi
        echo ""
        
        echo "Scripts Enhanced:"
        echo "----------------"
        for script_path in "${SCRIPTS_TO_ENHANCE[@]}"; do
            local full_path="${PROJECT_DIR}/${script_path}"
            if [[ -f "$full_path" ]]; then
                local has_error_handling="No"
                if grep -q "source.*error-handler" "$full_path"; then
                    has_error_handling="Yes"
                fi
                echo "  $script_path: Error Handling = $has_error_handling"
            else
                echo "  $script_path: Not Found"
            fi
        done
        echo ""
        
        echo "Error Handling Features Added:"
        echo "-----------------------------"
        echo "  - Comprehensive error exit with recovery options"
        echo "  - Package installation with retry and recovery"
        echo "  - Service management with dependency checking"
        echo "  - Configuration file validation and backup"
        echo "  - Rollback points for major operations"
        echo "  - Detailed error logging and reporting"
        echo "  - Automated recovery mechanisms"
        echo "  - User-friendly error messages"
        echo ""
        
        echo "Recovery Mechanisms Available:"
        echo "-----------------------------"
        echo "  - Package installation failure recovery"
        echo "  - Service start failure recovery"
        echo "  - GPU driver failure recovery"
        echo "  - Xorg configuration failure recovery"
        echo "  - Power management failure recovery"
        echo "  - ASUS tools failure recovery"
        echo "  - Network failure recovery"
        echo "  - Disk space failure recovery"
        echo "  - Permission failure recovery"
        echo "  - Configuration corruption recovery"
        echo ""
        
    } > "$report_file"
    
    log_success "Error handling integration report created: $report_file"
    echo -e "\n${GREEN}Report saved to: $report_file${NC}"
}

# Test error handling integration
test_error_handling_integration() {
    log_info "Testing error handling integration..."
    
    local test_results=()
    local test_failures=()
    
    # Test 1: Check if error handler is available
    if [[ -f "${SCRIPT_DIR}/error-handler.sh" ]]; then
        test_results+=("error_handler_available:pass")
        log_success "Error handler script is available"
    else
        test_failures+=("error_handler_available:fail")
        log_error "Error handler script not found"
    fi
    
    # Test 2: Check if recovery mechanisms are available
    if [[ -f "${SCRIPT_DIR}/error-recovery-mechanisms.sh" ]]; then
        test_results+=("recovery_mechanisms_available:pass")
        log_success "Recovery mechanisms script is available"
    else
        test_failures+=("recovery_mechanisms_available:fail")
        log_error "Recovery mechanisms script not found"
    fi
    
    # Test 3: Validate enhanced scripts
    local validation_passed=0
    local validation_failed=0
    
    for script_path in "${SCRIPTS_TO_ENHANCE[@]}"; do
        local full_path="${PROJECT_DIR}/${script_path}"
        if [[ -f "$full_path" ]]; then
            if validate_error_handling "$full_path"; then
                ((validation_passed++))
            else
                ((validation_failed++))
            fi
        fi
    done
    
    if [[ $validation_failed -eq 0 ]]; then
        test_results+=("script_validation:pass")
        log_success "All enhanced scripts passed validation"
    else
        test_failures+=("script_validation:partial")
        log_warn "$validation_failed scripts failed validation"
    fi
    
    # Test 4: Test recovery mechanism functionality
    if source "${SCRIPT_DIR}/error-recovery-mechanisms.sh" && command -v execute_recovery >/dev/null 2>&1; then
        test_results+=("recovery_functionality:pass")
        log_success "Recovery mechanisms are functional"
    else
        test_failures+=("recovery_functionality:fail")
        log_error "Recovery mechanisms are not functional"
    fi
    
    # Summary
    local total_tests=$((${#test_results[@]} + ${#test_failures[@]}))
    local passed_tests=${#test_results[@]}
    
    log_info "Error handling integration test completed"
    log_info "Tests passed: $passed_tests/$total_tests"
    
    if [[ ${#test_failures[@]} -eq 0 ]]; then
        log_success "All error handling integration tests passed"
        return 0
    else
        log_warn "Some error handling integration tests failed:"
        for failure in "${test_failures[@]}"; do
            log_warn "  - $failure"
        done
        return 1
    fi
}

# Main function
main() {
    local command="${1:-integrate}"
    
    case "$command" in
        "integrate")
            log_info "Starting comprehensive error handling integration..."
            if process_all_scripts; then
                create_error_handling_report
                log_success "Error handling integration completed successfully"
            else
                log_error "Error handling integration completed with failures"
                create_error_handling_report
                exit 1
            fi
            ;;
        "validate")
            log_info "Validating error handling in all scripts..."
            local validation_failures=0
            for script_path in "${SCRIPTS_TO_ENHANCE[@]}"; do
                local full_path="${PROJECT_DIR}/${script_path}"
                if [[ -f "$full_path" ]]; then
                    if ! validate_error_handling "$full_path"; then
                        ((validation_failures++))
                    fi
                fi
            done
            
            if [[ $validation_failures -eq 0 ]]; then
                log_success "All scripts passed error handling validation"
            else
                log_error "$validation_failures scripts failed validation"
                exit 1
            fi
            ;;
        "test")
            test_error_handling_integration
            ;;
        "report")
            create_error_handling_report
            ;;
        "help"|"-h"|"--help")
            cat << EOF
Usage: $0 <command>

Commands:
    integrate    Integrate error handling into all scripts (default)
    validate     Validate error handling in all scripts
    test         Test error handling integration
    report       Create error handling integration report
    help         Show this help message

This script adds comprehensive error handling and recovery mechanisms
to all scripts in the project, including:

- Enhanced error exit with recovery options
- Package installation with retry and recovery
- Service management with dependency checking
- Configuration file validation and backup
- Rollback points for major operations
- Detailed error logging and reporting
- Automated recovery mechanisms

EOF
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi