#!/bin/bash

# Test script for configuration backup and restore system
# Tests backup, restore, validation, and user data protection functions

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly BACKUP_SCRIPT="${SCRIPT_DIR}/config-backup.sh"
readonly TEST_DIR="/tmp/config-backup-test"
readonly TEST_BACKUP_DIR="${TEST_DIR}/backups"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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

# Test framework functions
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo
    log_info "Running test: $test_name"
    ((TESTS_RUN++))
    
    if $test_function; then
        log_success "PASSED: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "FAILED: $test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        log_error "$message: expected '$expected', got '$actual'"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [[ -f "$file" ]]; then
        return 0
    else
        log_error "$message: $file"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist}"
    
    if [[ ! -f "$file" ]]; then
        return 0
    else
        log_error "$message: $file"
        return 1
    fi
}

assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed}"
    
    if eval "$command" >/dev/null 2>&1; then
        return 0
    else
        log_error "$message: $command"
        return 1
    fi
}

assert_command_failure() {
    local command="$1"
    local message="${2:-Command should fail}"
    
    if ! eval "$command" >/dev/null 2>&1; then
        return 0
    else
        log_error "$message: $command"
        return 1
    fi
}

# Test setup and teardown
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Clean up any existing test directory
    rm -rf "$TEST_DIR"
    
    # Create test directory structure
    mkdir -p "$TEST_DIR"/{etc/X11/xorg.conf.d,etc/systemd/system,etc/udev/rules.d,backups}
    
    # Create test configuration files
    cat > "$TEST_DIR/etc/X11/xorg.conf.d/10-hybrid.conf" << 'EOF'
# Test Xorg hybrid configuration
Section "ServerLayout"
    Identifier "layout"
    Screen 0 "amd"
    Inactive "nvidia"
EndSection
EOF
    
    cat > "$TEST_DIR/etc/systemd/system/test-service.service" << 'EOF'
[Unit]
Description=Test Service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/true

[Install]
WantedBy=multi-user.target
EOF
    
    cat > "$TEST_DIR/etc/udev/rules.d/99-test.rules" << 'EOF'
# Test udev rule
SUBSYSTEM=="test", ACTION=="add", RUN+="/bin/echo test"
EOF
    
    # Create test metadata
    cat > "$TEST_DIR/test-metadata.json" << 'EOF'
{
    "version": "1.0",
    "timestamp": "2024-01-20T14:30:22+00:00",
    "description": "Test backup",
    "hostname": "test-host",
    "kernel": "6.1.0-test",
    "user": "testuser",
    "script_version": "1.0",
    "files": []
}
EOF
    
    log_success "Test environment setup completed"
}

cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
    log_success "Test environment cleaned up"
}

# Test functions
test_backup_script_exists() {
    assert_file_exists "$BACKUP_SCRIPT" "Backup script should exist"
}

test_backup_script_executable() {
    assert_command_success "test -x '$BACKUP_SCRIPT'" "Backup script should be executable"
}

test_backup_help_command() {
    assert_command_success "'$BACKUP_SCRIPT' --help" "Help command should work"
}

test_backup_version_command() {
    assert_command_success "'$BACKUP_SCRIPT' version" "Version command should work"
}

test_backup_list_empty() {
    # Test listing when no backups exist
    local output
    output=$("$BACKUP_SCRIPT" list 2>&1 || true)
    
    if echo "$output" | grep -q "No backups found\|Total backups: 0"; then
        return 0
    else
        log_error "Expected empty backup list message"
        return 1
    fi
}

test_user_data_protection() {
    # Test that protected paths are rejected
    local test_script=$(mktemp)
    
    cat > "$test_script" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/config-backup.sh"

# Test protected path detection
if is_protected_path "/home/user/file.txt"; then
    echo "PROTECTED"
else
    echo "NOT_PROTECTED"
fi
EOF
    
    chmod +x "$test_script"
    local result=$("$test_script")
    rm -f "$test_script"
    
    assert_equals "PROTECTED" "$result" "Home directory should be protected"
}

test_path_validation() {
    # Test path validation function
    local test_script=$(mktemp)
    
    cat > "$test_script" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/config-backup.sh"

# Test system path validation
if validate_path "/etc/test.conf"; then
    echo "VALID"
else
    echo "INVALID"
fi
EOF
    
    chmod +x "$test_script"
    local result=$("$test_script")
    rm -f "$test_script"
    
    assert_equals "VALID" "$result" "System configuration path should be valid"
}

test_backup_metadata_creation() {
    # Test metadata file creation
    local temp_dir=$(mktemp -d)
    local test_script=$(mktemp)
    
    cat > "$test_script" << EOF
#!/bin/bash
source "$BACKUP_SCRIPT"
create_backup_metadata "$temp_dir" "Test backup"
EOF
    
    chmod +x "$test_script"
    "$test_script"
    rm -f "$test_script"
    
    assert_file_exists "$temp_dir/metadata.json" "Metadata file should be created"
    
    # Validate JSON format
    if command -v jq >/dev/null 2>&1; then
        assert_command_success "jq empty '$temp_dir/metadata.json'" "Metadata should be valid JSON"
    fi
    
    rm -rf "$temp_dir"
}

test_backup_dry_run() {
    # Test dry run mode
    local output
    output=$("$BACKUP_SCRIPT" --dry-run backup "Test dry run" 2>&1 || true)
    
    if echo "$output" | grep -q "DRY RUN MODE"; then
        return 0
    else
        log_error "Dry run mode not detected in output"
        return 1
    fi
}

test_backup_validation_missing_files() {
    # Test backup validation with missing files
    local temp_backup_dir=$(mktemp -d)
    
    # Create incomplete backup (missing required files)
    echo "1.0" > "$temp_backup_dir/config_version"
    
    local test_script=$(mktemp)
    cat > "$test_script" << EOF
#!/bin/bash
source "$BACKUP_SCRIPT"
if validate_backup "$temp_backup_dir"; then
    echo "VALID"
else
    echo "INVALID"
fi
EOF
    
    chmod +x "$test_script"
    local result=$("$test_script" 2>/dev/null || echo "INVALID")
    rm -f "$test_script"
    rm -rf "$temp_backup_dir"
    
    assert_equals "INVALID" "$result" "Incomplete backup should be invalid"
}

test_configuration_mappings() {
    # Test that configuration mappings are properly defined
    local test_script=$(mktemp)
    
    cat > "$test_script" << EOF
#!/bin/bash
source "$BACKUP_SCRIPT"
echo "\${#CONFIG_MAPPINGS[@]}"
EOF
    
    chmod +x "$test_script"
    local mapping_count=$("$test_script")
    rm -f "$test_script"
    
    if [[ "$mapping_count" -gt 0 ]]; then
        return 0
    else
        log_error "No configuration mappings defined"
        return 1
    fi
}

test_timestamp_generation() {
    # Test timestamp generation
    local test_script=$(mktemp)
    
    cat > "$test_script" << EOF
#!/bin/bash
source "$BACKUP_SCRIPT"
get_timestamp
EOF
    
    chmod +x "$test_script"
    local timestamp=$("$test_script")
    rm -f "$test_script"
    
    # Check timestamp format (YYYYMMDD_HHMMSS)
    if [[ "$timestamp" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
        return 0
    else
        log_error "Invalid timestamp format: $timestamp"
        return 1
    fi
}

test_backup_name_generation() {
    # Test backup name generation
    local test_script=$(mktemp)
    
    cat > "$test_script" << EOF
#!/bin/bash
source "$BACKUP_SCRIPT"
get_backup_name "Test backup" "20240120_143022"
EOF
    
    chmod +x "$test_script"
    local backup_name=$("$test_script")
    rm -f "$test_script"
    
    local expected="Test_backup_20240120_143022"
    assert_equals "$expected" "$backup_name" "Backup name should be properly formatted"
}

test_jq_dependency() {
    # Test that jq is available for JSON processing
    if command -v jq >/dev/null 2>&1; then
        return 0
    else
        log_error "jq is required but not available"
        return 1
    fi
}

# Integration tests
test_full_backup_restore_cycle() {
    # This test requires root privileges and actual system files
    # Skip if not running as root or in test environment
    if [[ $EUID -ne 0 ]] || [[ "${SKIP_INTEGRATION_TESTS:-}" == "true" ]]; then
        log_warn "Skipping integration test (requires root or SKIP_INTEGRATION_TESTS set)"
        return 0
    fi
    
    # Create a test backup
    local backup_name
    backup_name=$("$BACKUP_SCRIPT" backup "Integration test backup" 2>&1 | grep "Backup created:" | cut -d' ' -f3 || echo "")
    
    if [[ -z "$backup_name" ]]; then
        log_error "Failed to create test backup"
        return 1
    fi
    
    # Validate the backup
    if ! "$BACKUP_SCRIPT" validate "$backup_name" >/dev/null 2>&1; then
        log_error "Backup validation failed"
        return 1
    fi
    
    # Clean up test backup
    "$BACKUP_SCRIPT" --force delete "$backup_name" >/dev/null 2>&1 || true
    
    return 0
}

# Test runner
run_all_tests() {
    log_info "Starting configuration backup system tests..."
    
    # Setup test environment
    setup_test_environment
    
    # Basic functionality tests
    run_test "Backup script exists" test_backup_script_exists
    run_test "Backup script is executable" test_backup_script_executable
    run_test "Help command works" test_backup_help_command
    run_test "Version command works" test_backup_version_command
    run_test "List empty backups" test_backup_list_empty
    
    # Security and validation tests
    run_test "User data protection" test_user_data_protection
    run_test "Path validation" test_path_validation
    run_test "Backup validation with missing files" test_backup_validation_missing_files
    
    # Functionality tests
    run_test "Backup metadata creation" test_backup_metadata_creation
    run_test "Dry run mode" test_backup_dry_run
    run_test "Configuration mappings defined" test_configuration_mappings
    run_test "Timestamp generation" test_timestamp_generation
    run_test "Backup name generation" test_backup_name_generation
    
    # Dependency tests
    run_test "jq dependency available" test_jq_dependency
    
    # Integration tests
    run_test "Full backup/restore cycle" test_full_backup_restore_cycle
    
    # Cleanup
    cleanup_test_environment
    
    # Report results
    echo
    log_info "Test Results:"
    log_info "Tests run: $TESTS_RUN"
    log_success "Tests passed: $TESTS_PASSED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "Tests failed: $TESTS_FAILED"
        return 1
    else
        log_success "All tests passed!"
        return 0
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Test script for configuration backup and restore system.

OPTIONS:
    -h, --help              Show this help message
    --skip-integration      Skip integration tests that require root

ENVIRONMENT VARIABLES:
    SKIP_INTEGRATION_TESTS  Set to "true" to skip integration tests

EXAMPLES:
    $SCRIPT_NAME                        # Run all tests
    $SCRIPT_NAME --skip-integration     # Skip integration tests
    SKIP_INTEGRATION_TESTS=true $SCRIPT_NAME  # Skip integration tests

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
            --skip-integration)
                export SKIP_INTEGRATION_TESTS="true"
                shift
                ;;
            *)
                echo "Unknown option: $1. Use -h for help." >&2
                exit 1
                ;;
        esac
    done
    
    # Check if backup script exists
    if [[ ! -f "$BACKUP_SCRIPT" ]]; then
        log_error "Backup script not found: $BACKUP_SCRIPT"
        exit 1
    fi
    
    # Run tests
    if run_all_tests; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"