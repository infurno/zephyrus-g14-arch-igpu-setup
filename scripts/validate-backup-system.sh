#!/bin/bash

# Simple validation script for the configuration backup system
# Performs basic checks to ensure the backup system is properly integrated

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly BACKUP_SCRIPT="${SCRIPT_DIR}/config-backup.sh"

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

# Validation functions
validate_backup_script_exists() {
    log_info "Checking if backup script exists..."
    
    if [[ -f "$BACKUP_SCRIPT" ]]; then
        log_success "Backup script found: $BACKUP_SCRIPT"
        return 0
    else
        log_error "Backup script not found: $BACKUP_SCRIPT"
        return 1
    fi
}

validate_backup_script_executable() {
    log_info "Checking if backup script is executable..."
    
    if [[ -x "$BACKUP_SCRIPT" ]]; then
        log_success "Backup script is executable"
        return 0
    else
        log_error "Backup script is not executable"
        log_info "Fix with: chmod +x $BACKUP_SCRIPT"
        return 1
    fi
}

validate_backup_help() {
    log_info "Testing backup script help command..."
    
    if "$BACKUP_SCRIPT" --help >/dev/null 2>&1; then
        log_success "Backup script help command works"
        return 0
    else
        log_error "Backup script help command failed"
        return 1
    fi
}

validate_backup_version() {
    log_info "Testing backup script version command..."
    
    if "$BACKUP_SCRIPT" version >/dev/null 2>&1; then
        log_success "Backup script version command works"
        return 0
    else
        log_error "Backup script version command failed"
        return 1
    fi
}

validate_setup_script_integration() {
    log_info "Checking setup script integration..."
    
    local setup_script="${PROJECT_DIR}/setup.sh"
    
    if [[ ! -f "$setup_script" ]]; then
        log_error "Setup script not found: $setup_script"
        return 1
    fi
    
    # Check for backup integration in setup script
    if grep -q "create_pre_setup_backup" "$setup_script"; then
        log_success "Backup integration found in setup script"
    else
        log_error "Backup integration not found in setup script"
        return 1
    fi
    
    # Check for --no-backup option
    if grep -q "\-\-no-backup" "$setup_script"; then
        log_success "No-backup option found in setup script"
    else
        log_error "No-backup option not found in setup script"
        return 1
    fi
    
    return 0
}

validate_test_script_exists() {
    log_info "Checking if test script exists..."
    
    local test_script="${SCRIPT_DIR}/test-config-backup.sh"
    
    if [[ -f "$test_script" ]]; then
        log_success "Test script found: $test_script"
        return 0
    else
        log_error "Test script not found: $test_script"
        return 1
    fi
}

validate_documentation() {
    log_info "Checking documentation updates..."
    
    local readme="${PROJECT_DIR}/README.md"
    local troubleshooting="${PROJECT_DIR}/docs/TROUBLESHOOTING.md"
    
    # Check README.md
    if [[ -f "$readme" ]]; then
        if grep -q "Configuration Backup System" "$readme"; then
            log_success "Backup system documented in README.md"
        else
            log_error "Backup system not documented in README.md"
            return 1
        fi
    else
        log_error "README.md not found"
        return 1
    fi
    
    # Check TROUBLESHOOTING.md
    if [[ -f "$troubleshooting" ]]; then
        if grep -q "Configuration Backup and Restore" "$troubleshooting"; then
            log_success "Backup system documented in TROUBLESHOOTING.md"
        else
            log_error "Backup system not documented in TROUBLESHOOTING.md"
            return 1
        fi
    else
        log_error "TROUBLESHOOTING.md not found"
        return 1
    fi
    
    return 0
}

validate_dependencies() {
    log_info "Checking required dependencies..."
    
    local missing_deps=()
    
    # Check for jq (required for JSON processing)
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        log_success "All required dependencies are available"
        return 0
    else
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: sudo pacman -S ${missing_deps[*]}"
        return 1
    fi
}

validate_configuration_mappings() {
    log_info "Validating configuration mappings..."
    
    # Source the backup script to access CONFIG_MAPPINGS
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/config-backup.sh"
echo "${#CONFIG_MAPPINGS[@]}"
EOF
    
    chmod +x "$temp_script"
    local mapping_count=$("$temp_script" 2>/dev/null || echo "0")
    rm -f "$temp_script"
    
    if [[ "$mapping_count" -gt 0 ]]; then
        log_success "Configuration mappings defined: $mapping_count mappings"
        return 0
    else
        log_error "No configuration mappings found"
        return 1
    fi
}

# Main validation function
run_validation() {
    log_info "Starting backup system validation..."
    echo
    
    local validation_errors=0
    
    # Run all validation checks
    validate_backup_script_exists || ((validation_errors++))
    validate_backup_script_executable || ((validation_errors++))
    validate_backup_help || ((validation_errors++))
    validate_backup_version || ((validation_errors++))
    validate_setup_script_integration || ((validation_errors++))
    validate_test_script_exists || ((validation_errors++))
    validate_documentation || ((validation_errors++))
    validate_dependencies || ((validation_errors++))
    validate_configuration_mappings || ((validation_errors++))
    
    echo
    if [[ $validation_errors -eq 0 ]]; then
        log_success "All validation checks passed!"
        log_info "The backup system is properly implemented and integrated."
        return 0
    else
        log_error "Validation failed with $validation_errors errors"
        log_info "Please fix the issues above before using the backup system."
        return 1
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Validation script for the configuration backup and restore system.

OPTIONS:
    -h, --help      Show this help message

DESCRIPTION:
    This script validates that the backup system is properly implemented
    and integrated into the main setup script. It checks for:
    
    - Backup script existence and executability
    - Basic functionality (help, version commands)
    - Integration with main setup script
    - Test script availability
    - Documentation updates
    - Required dependencies
    - Configuration mappings

EXAMPLES:
    $SCRIPT_NAME                # Run validation checks

EOF
}

# Main execution function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1. Use -h for help." >&2
                exit 1
                ;;
        esac
    done
    
    # Run validation
    if run_validation; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"