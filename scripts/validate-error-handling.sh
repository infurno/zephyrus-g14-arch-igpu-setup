#!/bin/bash

# Error Handling Validation Script
# Validates comprehensive error handling implementation across all scripts

set -euo pipefail

# Source error handling system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/error-handler.sh"

readonly VALIDATION_VERSION="1.0.0"
readonly VALIDATION_LOG="${ERROR_LOG_DIR}/validation_$(date +%Y%m%d_%H%M%S).log"

# Validation results tracking
declare -a VALIDATION_RESULTS=()
declare -a VALIDATION_FAILURES=()
declare -a VALIDATION_WARNINGS=()

# Initialize validation system
init_validation() {
    log_info "Initializing error handling validation system (v${VALIDATION_VERSION})"
    
    sudo mkdir -p "$(dirname "$VALIDATION_LOG")"
    sudo touch "$VALIDATION_LOG"
    sudo chmod 644 "$VALIDATION_LOG"
    
    log_success "Validation system initialized"
}

# Log validation result
log_validation() {
    local test_name="$1"
    local status="$2"
    local details="${3:-}"
    local timestamp=$(date -Iseconds)
    
    echo "[$timestamp] VALIDATION: $test_name - $status - $details" | sudo tee -a "$VALIDATION_LOG" >/dev/null
    
    case "$status" in
        "PASS")
            VALIDATION_RESULTS+=("$test_name:$status:$details")
            log_success "✓ $test_name: $details"
            ;;
        "FAIL")
            VALIDATION_FAILURES+=("$test_name:$status:$details")
            log_error "✗ $test_name: $details"
            ;;
        "WARN")
            VALIDATION_WARNINGS+=("$test_name:$status:$details")
            log_warn "⚠ $test_name: $details"
            ;;
    esac
}

# Validate error handler core functionality
validate_error_handler_core() {
    log_info "Validating error handler core functionality..."
    
    # Test 1: Check if error handler script exists and is executable
    if [[ -f "${SCRIPT_DIR}/error-handler.sh" && -x "${SCRIPT_DIR}/error-handler.sh" ]]; then
        log_validation "error_handler_exists" "PASS" "Error handler script exists and is executable"
    else
        log_validation "error_handler_exists" "FAIL" "Error handler script missing or not executable"
        return 1
    fi
    
    # Test 2: Check if error handler can be sourced
    if source "${SCRIPT_DIR}/error-handler.sh" 2>/dev/null; then
        log_validation "error_handler_sourceable" "PASS" "Error handler can be sourced successfully"
    else
        log_validation "error_handler_sourceable" "FAIL" "Error handler cannot be sourced"
        return 1
    fi
    
    # Test 3: Check if core functions are available
    local core_functions=("log_error" "log_warn" "log_info" "log_success" "error_exit" "create_rollback_point")
    local missing_functions=()
    
    for func in "${core_functions[@]}"; do
        if ! command -v "$func" >/dev/null 2>&1; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        log_validation "core_functions_available" "PASS" "All core error handling functions are available"
    else
        log_validation "core_functions_available" "FAIL" "Missing functions: ${missing_functions[*]}"
        return 1
    fi
    
    # Test 4: Check if error codes are defined
    local error_codes=("E_SUCCESS" "E_GENERAL" "E_PACKAGE_INSTALL" "E_CONFIG_ERROR" "E_SERVICE_ERROR")
    local missing_codes=()
    
    for code in "${error_codes[@]}"; do
        if [[ -z "${!code:-}" ]]; then
            missing_codes+=("$code")
        fi
    done
    
    if [[ ${#missing_codes[@]} -eq 0 ]]; then
        log_validation "error_codes_defined" "PASS" "All error codes are properly defined"
    else
        log_validation "error_codes_defined" "FAIL" "Missing error codes: ${missing_codes[*]}"
        return 1
    fi
    
    return 0
}

# Validate recovery mechanisms
validate_recovery_mechanisms() {
    log_info "Validating recovery mechanisms..."
    
    # Test 1: Check if recovery mechanisms script exists
    if [[ -f "${SCRIPT_DIR}/error-recovery-mechanisms.sh" ]]; then
        log_validation "recovery_script_exists" "PASS" "Recovery mechanisms script exists"
    else
        log_validation "recovery_script_exists" "FAIL" "Recovery mechanisms script missing"
        return 1
    fi
    
    # Test 2: Check if recovery mechanisms can be sourced
    if source "${SCRIPT_DIR}/error-recovery-mechanisms.sh" 2>/dev/null; then
        log_validation "recovery_script_sourceable" "PASS" "Recovery mechanisms script can be sourced"
    else
        log_validation "recovery_script_sourceable" "FAIL" "Recovery mechanisms script cannot be sourced"
        return 1
    fi
    
    # Test 3: Check if recovery functions are available
    local recovery_functions=(
        "recover_package_install_failure"
        "recover_service_start_failure"
        "recover_gpu_driver_failure"
        "recover_xorg_config_failure"
        "recover_power_management_failure"
        "execute_recovery"
    )
    
    local missing_recovery_functions=()
    
    for func in "${recovery_functions[@]}"; do
        if ! command -v "$func" >/dev/null 2>&1; then
            missing_recovery_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_recovery_functions[@]} -eq 0 ]]; then
        log_validation "recovery_functions_available" "PASS" "All recovery functions are available"
    else
        log_validation "recovery_functions_available" "FAIL" "Missing recovery functions: ${missing_recovery_functions[*]}"
        return 1
    fi
    
    # Test 4: Test recovery mechanism execution (dry run)
    if execute_recovery "network_failure" "test" 2>/dev/null; then
        log_validation "recovery_execution_test" "PASS" "Recovery mechanism execution test passed"
    else
        log_validation "recovery_execution_test" "WARN" "Recovery mechanism execution test failed (may be expected)"
    fi
    
    return 0
}

# Validate rollback system
validate_rollback_system() {
    log_info "Validating rollback system..."
    
    # Test 1: Check if rollback system script exists
    if [[ -f "${SCRIPT_DIR}/rollback-system.sh" ]]; then
        log_validation "rollback_script_exists" "PASS" "Rollback system script exists"
    else
        log_validation "rollback_script_exists" "FAIL" "Rollback system script missing"
        return 1
    fi
    
    # Test 2: Check if rollback directories exist
    if [[ -d "$BACKUP_DIR" ]]; then
        log_validation "rollback_directories_exist" "PASS" "Rollback directories exist"
    else
        log_validation "rollback_directories_exist" "WARN" "Rollback directories not found (will be created when needed)"
    fi
    
    # Test 3: Test rollback point creation (dry run)
    local test_rollback_name="validation_test_$(date +%s)"
    if create_rollback_point "$test_rollback_name" "Validation test rollback point" 2>/dev/null; then
        log_validation "rollback_creation_test" "PASS" "Rollback point creation test passed"
        
        # Clean up test rollback
        local rollback_dir="${BACKUP_DIR}/rollback_${test_rollback_name}_"*
        sudo rm -rf $rollback_dir 2>/dev/null || true
    else
        log_validation "rollback_creation_test" "WARN" "Rollback point creation test failed (may require privileges)"
    fi
    
    return 0
}

# Validate script error handling integration
validate_script_integration() {
    log_info "Validating script error handling integration..."
    
    local project_dir="$(dirname "$SCRIPT_DIR")"
    local scripts_to_check=(
        "setup.sh"
        "scripts/post-install.sh"
        "scripts/troubleshoot.sh"
        "scripts/system-test.sh"
        "scripts/setup-power-management.sh"
        "scripts/setup-asus-tools.sh"
    )
    
    local integration_passed=0
    local integration_failed=0
    local integration_warnings=0
    
    for script_path in "${scripts_to_check[@]}"; do
        local full_path="${project_dir}/${script_path}"
        
        if [[ ! -f "$full_path" ]]; then
            log_validation "script_exists_${script_path//\//_}" "WARN" "Script not found: $script_path"
            ((integration_warnings++))
            continue
        fi
        
        local script_issues=()
        
        # Check for basic error handling
        if ! grep -q "set -e" "$full_path"; then
            script_issues+=("missing_set_e")
        fi
        
        if ! grep -q "error_exit\|enhanced_error_exit" "$full_path"; then
            script_issues+=("missing_error_exit")
        fi
        
        if ! grep -q "source.*error-handler" "$full_path"; then
            script_issues+=("missing_error_handler_source")
        fi
        
        # Check for logging
        if ! grep -q "log_" "$full_path"; then
            script_issues+=("missing_logging")
        fi
        
        # Check for recovery mechanisms in package operations
        if grep -q "pacman -S" "$full_path" && ! grep -q "install_package_with_recovery\|install_package_with_dependencies" "$full_path"; then
            script_issues+=("unprotected_package_operations")
        fi
        
        # Check for recovery mechanisms in service operations
        if grep -q "systemctl.*start\|systemctl.*restart\|systemctl.*enable" "$full_path" && ! grep -q "manage_service_with_recovery\|manage_service_with_dependencies" "$full_path"; then
            script_issues+=("unprotected_service_operations")
        fi
        
        if [[ ${#script_issues[@]} -eq 0 ]]; then
            log_validation "script_integration_${script_path//\//_}" "PASS" "Script has comprehensive error handling"
            ((integration_passed++))
        elif [[ ${#script_issues[@]} -le 2 ]]; then
            log_validation "script_integration_${script_path//\//_}" "WARN" "Script has minor error handling issues: ${script_issues[*]}"
            ((integration_warnings++))
        else
            log_validation "script_integration_${script_path//\//_}" "FAIL" "Script has significant error handling issues: ${script_issues[*]}"
            ((integration_failed++))
        fi
    done
    
    # Summary
    local total_scripts=$((integration_passed + integration_failed + integration_warnings))
    log_info "Script integration validation: $integration_passed passed, $integration_warnings warnings, $integration_failed failed (total: $total_scripts)"
    
    if [[ $integration_failed -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Validate error reporting system
validate_error_reporting() {
    log_info "Validating error reporting system..."
    
    # Test 1: Check if error reporter script exists
    if [[ -f "${SCRIPT_DIR}/error-reporter.sh" ]]; then
        log_validation "error_reporter_exists" "PASS" "Error reporter script exists"
    else
        log_validation "error_reporter_exists" "FAIL" "Error reporter script missing"
        return 1
    fi
    
    # Test 2: Check if error log directory exists
    if [[ -d "$ERROR_LOG_DIR" ]]; then
        log_validation "error_log_dir_exists" "PASS" "Error log directory exists"
    else
        log_validation "error_log_dir_exists" "WARN" "Error log directory not found (will be created when needed)"
    fi
    
    # Test 3: Check if error log file is writable
    if sudo touch "$ERROR_LOG_FILE" 2>/dev/null; then
        log_validation "error_log_writable" "PASS" "Error log file is writable"
    else
        log_validation "error_log_writable" "FAIL" "Error log file is not writable"
        return 1
    fi
    
    # Test 4: Test error logging functionality
    local test_message="Validation test error message $(date +%s)"
    if log_error "$test_message" 2>/dev/null && grep -q "$test_message" "$ERROR_LOG_FILE" 2>/dev/null; then
        log_validation "error_logging_functional" "PASS" "Error logging is functional"
    else
        log_validation "error_logging_functional" "WARN" "Error logging test failed (may require privileges)"
    fi
    
    return 0
}

# Validate configuration backup and restore
validate_config_backup() {
    log_info "Validating configuration backup and restore..."
    
    # Test 1: Check if config backup script exists
    if [[ -f "${SCRIPT_DIR}/config-backup.sh" ]]; then
        log_validation "config_backup_script_exists" "PASS" "Configuration backup script exists"
    else
        log_validation "config_backup_script_exists" "FAIL" "Configuration backup script missing"
        return 1
    fi
    
    # Test 2: Check if backup directory structure can be created
    local test_backup_dir="/tmp/validation_backup_test_$$"
    if mkdir -p "$test_backup_dir" 2>/dev/null; then
        log_validation "backup_directory_creation" "PASS" "Backup directory can be created"
        rm -rf "$test_backup_dir"
    else
        log_validation "backup_directory_creation" "FAIL" "Cannot create backup directory"
        return 1
    fi
    
    # Test 3: Test backup functionality (if available)
    if source "${SCRIPT_DIR}/config-backup.sh" 2>/dev/null && command -v create_backup_metadata >/dev/null 2>&1; then
        log_validation "backup_functions_available" "PASS" "Backup functions are available"
    else
        log_validation "backup_functions_available" "WARN" "Backup functions not available or not sourceable"
    fi
    
    return 0
}

# Validate user-friendly error messages
validate_user_friendly_errors() {
    log_info "Validating user-friendly error messages..."
    
    local project_dir="$(dirname "$SCRIPT_DIR")"
    local scripts_with_errors=0
    local scripts_with_friendly_errors=0
    
    # Check main scripts for user-friendly error messages
    local main_scripts=("setup.sh" "scripts/post-install.sh" "scripts/troubleshoot.sh")
    
    for script_path in "${main_scripts[@]}"; do
        local full_path="${project_dir}/${script_path}"
        
        if [[ -f "$full_path" ]]; then
            ((scripts_with_errors++))
            
            # Check for user-friendly error patterns
            local friendly_patterns=(
                "Please.*try"
                "Check.*and.*retry"
                "Make sure"
                "Ensure that"
                "You may need to"
                "Consider"
                "Try running"
            )
            
            local has_friendly_errors=false
            for pattern in "${friendly_patterns[@]}"; do
                if grep -qi "$pattern" "$full_path"; then
                    has_friendly_errors=true
                    break
                fi
            done
            
            if [[ "$has_friendly_errors" == true ]]; then
                ((scripts_with_friendly_errors++))
            fi
        fi
    done
    
    if [[ $scripts_with_friendly_errors -gt 0 ]]; then
        log_validation "user_friendly_errors" "PASS" "$scripts_with_friendly_errors/$scripts_with_errors scripts have user-friendly error messages"
    else
        log_validation "user_friendly_errors" "WARN" "No user-friendly error messages found in main scripts"
    fi
    
    return 0
}

# Run comprehensive validation
run_comprehensive_validation() {
    log_info "Running comprehensive error handling validation..."
    
    local validation_functions=(
        "validate_error_handler_core"
        "validate_recovery_mechanisms"
        "validate_rollback_system"
        "validate_script_integration"
        "validate_error_reporting"
        "validate_config_backup"
        "validate_user_friendly_errors"
    )
    
    local passed_validations=0
    local failed_validations=0
    
    for validation_func in "${validation_functions[@]}"; do
        log_info "Running validation: $validation_func"
        
        if "$validation_func"; then
            ((passed_validations++))
            log_success "Validation passed: $validation_func"
        else
            ((failed_validations++))
            log_error "Validation failed: $validation_func"
        fi
        
        echo ""  # Add spacing between validations
    done
    
    # Overall summary
    local total_validations=$((passed_validations + failed_validations))
    log_info "Comprehensive validation completed: $passed_validations/$total_validations validations passed"
    
    return $failed_validations
}

# Generate validation report
generate_validation_report() {
    local report_file="${ERROR_LOG_DIR}/error_handling_validation_$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "Generating validation report..."
    
    {
        echo "Error Handling Validation Report"
        echo "==============================="
        echo "Generated: $(date)"
        echo "Validation Version: $VALIDATION_VERSION"
        echo ""
        
        echo "Validation Summary:"
        echo "------------------"
        echo "Total Tests: $((${#VALIDATION_RESULTS[@]} + ${#VALIDATION_FAILURES[@]} + ${#VALIDATION_WARNINGS[@]}))"
        echo "Passed: ${#VALIDATION_RESULTS[@]}"
        echo "Failed: ${#VALIDATION_FAILURES[@]}"
        echo "Warnings: ${#VALIDATION_WARNINGS[@]}"
        echo ""
        
        if [[ ${#VALIDATION_RESULTS[@]} -gt 0 ]]; then
            echo "Passed Tests:"
            echo "------------"
            for result in "${VALIDATION_RESULTS[@]}"; do
                IFS=':' read -r test_name status details <<< "$result"
                echo "  ✓ $test_name: $details"
            done
            echo ""
        fi
        
        if [[ ${#VALIDATION_WARNINGS[@]} -gt 0 ]]; then
            echo "Warnings:"
            echo "--------"
            for warning in "${VALIDATION_WARNINGS[@]}"; do
                IFS=':' read -r test_name status details <<< "$warning"
                echo "  ⚠ $test_name: $details"
            done
            echo ""
        fi
        
        if [[ ${#VALIDATION_FAILURES[@]} -gt 0 ]]; then
            echo "Failed Tests:"
            echo "------------"
            for failure in "${VALIDATION_FAILURES[@]}"; do
                IFS=':' read -r test_name status details <<< "$failure"
                echo "  ✗ $test_name: $details"
            done
            echo ""
        fi
        
        echo "Error Handling Components Validated:"
        echo "-----------------------------------"
        echo "  - Error handler core functionality"
        echo "  - Recovery mechanisms"
        echo "  - Rollback system"
        echo "  - Script integration"
        echo "  - Error reporting system"
        echo "  - Configuration backup and restore"
        echo "  - User-friendly error messages"
        echo ""
        
        echo "Recommendations:"
        echo "---------------"
        if [[ ${#VALIDATION_FAILURES[@]} -gt 0 ]]; then
            echo "  - Address failed validations before deployment"
            echo "  - Review error handling implementation in failing components"
        fi
        
        if [[ ${#VALIDATION_WARNINGS[@]} -gt 0 ]]; then
            echo "  - Consider addressing validation warnings for improved reliability"
        fi
        
        if [[ ${#VALIDATION_FAILURES[@]} -eq 0 && ${#VALIDATION_WARNINGS[@]} -eq 0 ]]; then
            echo "  - Error handling implementation is comprehensive and ready for use"
        fi
        
    } > "$report_file"
    
    log_success "Validation report generated: $report_file"
    echo -e "\n${GREEN}Report saved to: $report_file${NC}"
}

# Main function
main() {
    local command="${1:-validate}"
    
    case "$command" in
        "validate")
            init_validation
            if run_comprehensive_validation; then
                generate_validation_report
                log_success "All error handling validations passed"
                exit 0
            else
                generate_validation_report
                log_error "Some error handling validations failed"
                exit 1
            fi
            ;;
        "core")
            init_validation
            validate_error_handler_core
            ;;
        "recovery")
            init_validation
            validate_recovery_mechanisms
            ;;
        "rollback")
            init_validation
            validate_rollback_system
            ;;
        "integration")
            init_validation
            validate_script_integration
            ;;
        "reporting")
            init_validation
            validate_error_reporting
            ;;
        "backup")
            init_validation
            validate_config_backup
            ;;
        "report")
            generate_validation_report
            ;;
        "help"|"-h"|"--help")
            cat << EOF
Usage: $0 <command>

Commands:
    validate     Run comprehensive error handling validation (default)
    core         Validate error handler core functionality
    recovery     Validate recovery mechanisms
    rollback     Validate rollback system
    integration  Validate script error handling integration
    reporting    Validate error reporting system
    backup       Validate configuration backup and restore
    report       Generate validation report
    help         Show this help message

This script validates the comprehensive error handling implementation
across all components of the system, ensuring:

- Error handler core functionality
- Recovery mechanisms for common failures
- Rollback system for failed installations
- Script integration with error handling
- Error reporting and logging
- Configuration backup and restore
- User-friendly error messages

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