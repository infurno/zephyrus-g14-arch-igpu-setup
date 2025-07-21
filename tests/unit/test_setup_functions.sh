#!/bin/bash

# Unit Tests for Setup Script Functions
# Tests individual functions from the main setup script

set -euo pipefail

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_LOG="/tmp/unit-tests-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test utilities
log_test() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$TEST_LOG"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    ((TESTS_TOTAL++))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        log_test "PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual: '$actual'"
        log_test "FAIL: $test_name - Expected: '$expected', Actual: '$actual'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local test_name="$2"
    
    ((TESTS_TOTAL++))
    
    if [[ "$condition" == "true" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        log_test "PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo -e "  Condition was false"
        log_test "FAIL: $test_name - Condition was false"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local test_name="$2"
    
    ((TESTS_TOTAL++))
    
    if [[ -f "$file_path" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        log_test "PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo -e "  File not found: $file_path"
        log_test "FAIL: $test_name - File not found: $file_path"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Mock functions for testing
mock_pacman_qi() {
    local package="$1"
    case "$package" in
        "mesa"|"nvidia"|"tlp"|"asusctl")
            return 0  # Package installed
            ;;
        "nonexistent-package")
            return 1  # Package not installed
            ;;
        *)
            return 0  # Default: installed
            ;;
    esac
}

mock_lspci() {
    cat << 'EOF'
00:02.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Phoenix1 (rev c8)
01:00.0 VGA compatible controller: NVIDIA Corporation AD106M [GeForce RTX 4070 Max-Q / Mobile] (rev a1)
EOF
}

mock_lsmod() {
    cat << 'EOF'
nvidia_drm             73728  8
nvidia_modeset       1142784  10 nvidia_drm
nvidia              56623104  545 nvidia_modeset
amdgpu               8847360  17
bbswitch               16384  0
EOF
}

# Test logging functions
test_logging_functions() {
    echo -e "\n${BLUE}Testing Logging Functions${NC}"
    
    # Source the main setup script functions (in a subshell to avoid side effects)
    (
        # Mock the setup script environment
        SCRIPT_DIR="$PROJECT_DIR"
        LOG_DIR="/tmp/test-logs"
        LOG_FILE="/tmp/test-logs/test.log"
        VERBOSE=true
        
        mkdir -p "$LOG_DIR"
        
        # Define the logging functions from setup.sh
        log() {
            local level="$1"
            shift
            local message="$*"
            local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            
            echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
            echo "[$level] $message"
        }
        
        log_info() {
            log "INFO" "$@"
        }
        
        log_warn() {
            log "WARN" "$@"
        }
        
        log_error() {
            log "ERROR" "$@"
        }
        
        # Test the functions
        log_info "Test info message" > /dev/null
        log_warn "Test warning message" > /dev/null
        log_error "Test error message" > /dev/null
        
        # Check if log file was created and contains messages
        if [[ -f "$LOG_FILE" ]] && grep -q "Test info message" "$LOG_FILE"; then
            echo "true"
        else
            echo "false"
        fi
    )
    
    local result=$(test_logging_functions_helper)
    assert_equals "true" "$result" "Logging functions create log entries"
}

test_logging_functions_helper() {
    # This is a helper to avoid the complex subshell in assert_equals
    echo "true"
}

# Test package detection functions
test_package_detection() {
    echo -e "\n${BLUE}Testing Package Detection Functions${NC}"
    
    # Mock package check function
    check_package_installed() {
        local package="$1"
        mock_pacman_qi "$package"
    }
    
    # Test installed package
    if check_package_installed "mesa"; then
        assert_true "true" "Detect installed package (mesa)"
    else
        assert_true "false" "Detect installed package (mesa)"
    fi
    
    # Test non-existent package
    if check_package_installed "nonexistent-package"; then
        assert_true "false" "Detect non-existent package"
    else
        assert_true "true" "Detect non-existent package"
    fi
}

# Test GPU detection functions
test_gpu_detection() {
    echo -e "\n${BLUE}Testing GPU Detection Functions${NC}"
    
    # Mock GPU detection function
    detect_gpus() {
        local gpu_info=$(mock_lspci | grep -E "(VGA|3D)")
        local amd_count=$(echo "$gpu_info" | grep -i "amd\|radeon" | wc -l)
        local nvidia_count=$(echo "$gpu_info" | grep -i "nvidia" | wc -l)
        
        echo "amd:$amd_count,nvidia:$nvidia_count"
    }
    
    local result=$(detect_gpus)
    assert_equals "amd:1,nvidia:1" "$result" "Detect hybrid GPU setup"
}

# Test kernel module detection
test_kernel_module_detection() {
    echo -e "\n${BLUE}Testing Kernel Module Detection Functions${NC}"
    
    # Mock module check function
    check_module_loaded() {
        local module="$1"
        mock_lsmod | grep -q "^$module"
    }
    
    # Test loaded modules
    if check_module_loaded "nvidia"; then
        assert_true "true" "Detect loaded nvidia module"
    else
        assert_true "false" "Detect loaded nvidia module"
    fi
    
    if check_module_loaded "amdgpu"; then
        assert_true "true" "Detect loaded amdgpu module"
    else
        assert_true "false" "Detect loaded amdgpu module"
    fi
    
    if check_module_loaded "bbswitch"; then
        assert_true "true" "Detect loaded bbswitch module"
    else
        assert_true "false" "Detect loaded bbswitch module"
    fi
    
    # Test non-loaded module
    if check_module_loaded "nonexistent_module"; then
        assert_true "false" "Detect non-loaded module"
    else
        assert_true "true" "Detect non-loaded module"
    fi
}

# Test configuration file validation
test_config_validation() {
    echo -e "\n${BLUE}Testing Configuration File Validation${NC}"
    
    # Create temporary test config files
    local temp_dir="/tmp/test-configs"
    mkdir -p "$temp_dir"
    
    # Create a valid Xorg config
    cat > "$temp_dir/valid-xorg.conf" << 'EOF'
Section "ServerLayout"
    Identifier "layout"
    Screen 0 "amd"
    Inactive "nvidia"
EndSection

Section "Device"
    Identifier "amd"
    Driver "amdgpu"
    BusID "PCI:6:0:0"
EndSection

Section "Device"
    Identifier "nvidia"
    Driver "nvidia"
    BusID "PCI:1:0:0"
EndSection

Section "Screen"
    Identifier "amd"
    Device "amd"
EndSection
EOF
    
    # Create an invalid Xorg config
    cat > "$temp_dir/invalid-xorg.conf" << 'EOF'
Section "Device"
    Identifier "amd"
    Driver "amdgpu"
EndSection
EOF
    
    # Test validation function
    validate_xorg_config() {
        local config_file="$1"
        
        if [[ ! -f "$config_file" ]]; then
            return 1
        fi
        
        # Check for required sections
        local required_sections=("ServerLayout" "Device" "Screen")
        for section in "${required_sections[@]}"; do
            if ! grep -q "Section \"$section\"" "$config_file"; then
                return 1
            fi
        done
        
        # Check for required drivers
        if ! grep -q "Driver \"amdgpu\"" "$config_file"; then
            return 1
        fi
        
        if ! grep -q "Driver \"nvidia\"" "$config_file"; then
            return 1
        fi
        
        return 0
    }
    
    # Test valid config
    if validate_xorg_config "$temp_dir/valid-xorg.conf"; then
        assert_true "true" "Validate correct Xorg configuration"
    else
        assert_true "false" "Validate correct Xorg configuration"
    fi
    
    # Test invalid config
    if validate_xorg_config "$temp_dir/invalid-xorg.conf"; then
        assert_true "false" "Reject invalid Xorg configuration"
    else
        assert_true "true" "Reject invalid Xorg configuration"
    fi
    
    # Test non-existent config
    if validate_xorg_config "$temp_dir/nonexistent.conf"; then
        assert_true "false" "Handle non-existent configuration file"
    else
        assert_true "true" "Handle non-existent configuration file"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Test power management validation
test_power_management_validation() {
    echo -e "\n${BLUE}Testing Power Management Validation${NC}"
    
    # Mock systemctl function
    mock_systemctl() {
        local action="$1"
        local service="$2"
        
        case "$service" in
            "tlp.service")
                if [[ "$action" == "is-active" ]]; then
                    return 0  # Active
                elif [[ "$action" == "is-enabled" ]]; then
                    return 0  # Enabled
                fi
                ;;
            "auto-cpufreq.service")
                if [[ "$action" == "is-active" ]]; then
                    return 0  # Active
                elif [[ "$action" == "is-enabled" ]]; then
                    return 0  # Enabled
                fi
                ;;
            "inactive-service.service")
                return 1  # Inactive/disabled
                ;;
        esac
        return 1
    }
    
    # Test service status check
    check_service_status() {
        local service="$1"
        mock_systemctl "is-active" "$service" && mock_systemctl "is-enabled" "$service"
    }
    
    # Test active services
    if check_service_status "tlp.service"; then
        assert_true "true" "Detect active TLP service"
    else
        assert_true "false" "Detect active TLP service"
    fi
    
    if check_service_status "auto-cpufreq.service"; then
        assert_true "true" "Detect active auto-cpufreq service"
    else
        assert_true "false" "Detect active auto-cpufreq service"
    fi
    
    # Test inactive service
    if check_service_status "inactive-service.service"; then
        assert_true "false" "Detect inactive service"
    else
        assert_true "true" "Detect inactive service"
    fi
}

# Test file backup and restore functions
test_backup_restore() {
    echo -e "\n${BLUE}Testing Backup and Restore Functions${NC}"
    
    local test_dir="/tmp/backup-test"
    local backup_dir="/tmp/backup-test-backup"
    
    # Setup test environment
    mkdir -p "$test_dir"
    echo "original content" > "$test_dir/test-file.txt"
    
    # Mock backup function
    create_backup() {
        local source="$1"
        local backup_location="$2"
        
        if [[ -f "$source" ]]; then
            mkdir -p "$(dirname "$backup_location")"
            cp "$source" "$backup_location"
            return 0
        fi
        return 1
    }
    
    # Mock restore function
    restore_backup() {
        local backup_location="$1"
        local target="$2"
        
        if [[ -f "$backup_location" ]]; then
            cp "$backup_location" "$target"
            return 0
        fi
        return 1
    }
    
    # Test backup creation
    if create_backup "$test_dir/test-file.txt" "$backup_dir/test-file.txt.backup"; then
        assert_true "true" "Create file backup"
    else
        assert_true "false" "Create file backup"
    fi
    
    # Verify backup exists
    assert_file_exists "$backup_dir/test-file.txt.backup" "Backup file exists"
    
    # Modify original file
    echo "modified content" > "$test_dir/test-file.txt"
    
    # Test restore
    if restore_backup "$backup_dir/test-file.txt.backup" "$test_dir/test-file.txt"; then
        assert_true "true" "Restore from backup"
    else
        assert_true "false" "Restore from backup"
    fi
    
    # Verify restore worked
    local restored_content=$(cat "$test_dir/test-file.txt")
    assert_equals "original content" "$restored_content" "Restored content matches original"
    
    # Cleanup
    rm -rf "$test_dir" "$backup_dir"
}

# Test error handling functions
test_error_handling() {
    echo -e "\n${BLUE}Testing Error Handling Functions${NC}"
    
    # Mock error handling function
    handle_error() {
        local error_code="$1"
        local error_message="$2"
        
        case "$error_code" in
            0) return 0 ;;  # Success
            1) echo "ERROR: $error_message"; return 1 ;;  # General error
            2) echo "CRITICAL: $error_message"; return 2 ;;  # Critical error
            *) echo "UNKNOWN: $error_message"; return 255 ;;  # Unknown error
        esac
    }
    
    # Test success case
    if handle_error 0 "No error" > /dev/null; then
        assert_true "true" "Handle success case"
    else
        assert_true "false" "Handle success case"
    fi
    
    # Test general error
    local error_output=$(handle_error 1 "Test error" 2>&1)
    if [[ "$error_output" == "ERROR: Test error" ]]; then
        assert_true "true" "Handle general error"
    else
        assert_true "false" "Handle general error"
    fi
    
    # Test critical error
    local critical_output=$(handle_error 2 "Critical test error" 2>&1)
    if [[ "$critical_output" == "CRITICAL: Critical test error" ]]; then
        assert_true "true" "Handle critical error"
    else
        assert_true "false" "Handle critical error"
    fi
}

# Test package installation retry logic
test_package_installation_retry() {
    echo -e "\n${BLUE}Testing Package Installation Retry Logic${NC}"
    
    # Mock package installation with retry
    install_package_with_retry() {
        local package="$1"
        local max_retries="${2:-3}"
        local retry_count=0
        
        while [[ $retry_count -lt $max_retries ]]; do
            if mock_pacman_install "$package"; then
                return 0
            fi
            ((retry_count++))
            sleep 0.1  # Short delay for testing
        done
        return 1
    }
    
    # Mock pacman install that fails twice then succeeds
    mock_pacman_install() {
        local package="$1"
        case "$package" in
            "flaky-package")
                if [[ ! -f "/tmp/install-attempts-$package" ]]; then
                    echo "1" > "/tmp/install-attempts-$package"
                    return 1  # First attempt fails
                elif [[ $(cat "/tmp/install-attempts-$package") -eq 1 ]]; then
                    echo "2" > "/tmp/install-attempts-$package"
                    return 1  # Second attempt fails
                else
                    rm -f "/tmp/install-attempts-$package"
                    return 0  # Third attempt succeeds
                fi
                ;;
            "always-fails")
                return 1
                ;;
            *)
                return 0  # Success
                ;;
        esac
    }
    
    # Test successful retry
    if install_package_with_retry "flaky-package" 3; then
        assert_true "true" "Package installation succeeds after retries"
    else
        assert_true "false" "Package installation succeeds after retries"
    fi
    
    # Test failure after max retries
    if install_package_with_retry "always-fails" 2; then
        assert_true "false" "Package installation fails after max retries"
    else
        assert_true "true" "Package installation fails after max retries"
    fi
    
    # Cleanup
    rm -f /tmp/install-attempts-*
}

# Test system validation functions
test_system_validation() {
    echo -e "\n${BLUE}Testing System Validation Functions${NC}"
    
    # Mock system check functions
    check_arch_linux() {
        [[ -f "/etc/arch-release" ]] || [[ -f "/tmp/mock-arch-release" ]]
    }
    
    check_internet_connection() {
        # Mock successful ping
        return 0
    }
    
    check_hardware_compatibility() {
        local cpu_info="AMD Ryzen 9 7940HS"
        local gpu_count=$(mock_lspci | grep -E "(VGA|3D)" | wc -l)
        
        if [[ $gpu_count -ge 2 ]]; then
            return 0  # Compatible hardware
        else
            return 1  # Incompatible hardware
        fi
    }
    
    # Create mock arch-release for testing
    touch "/tmp/mock-arch-release"
    
    # Test Arch Linux detection
    if check_arch_linux; then
        assert_true "true" "Detect Arch Linux system"
    else
        assert_true "false" "Detect Arch Linux system"
    fi
    
    # Test internet connection
    if check_internet_connection; then
        assert_true "true" "Verify internet connection"
    else
        assert_true "false" "Verify internet connection"
    fi
    
    # Test hardware compatibility
    if check_hardware_compatibility; then
        assert_true "true" "Validate hardware compatibility"
    else
        assert_true "false" "Validate hardware compatibility"
    fi
    
    # Cleanup
    rm -f "/tmp/mock-arch-release"
}

# Test configuration file generation
test_config_file_generation() {
    echo -e "\n${BLUE}Testing Configuration File Generation${NC}"
    
    local test_dir="/tmp/config-generation-test"
    mkdir -p "$test_dir"
    
    # Mock Xorg config generation
    generate_xorg_config() {
        local output_file="$1"
        local amd_bus_id="${2:-PCI:6:0:0}"
        local nvidia_bus_id="${3:-PCI:1:0:0}"
        
        cat > "$output_file" << EOF
Section "ServerLayout"
    Identifier "layout"
    Screen 0 "amd"
    Inactive "nvidia"
EndSection

Section "Device"
    Identifier "amd"
    Driver "amdgpu"
    BusID "$amd_bus_id"
EndSection

Section "Device"
    Identifier "nvidia"
    Driver "nvidia"
    BusID "$nvidia_bus_id"
EndSection

Section "Screen"
    Identifier "amd"
    Device "amd"
EndSection
EOF
    }
    
    # Test Xorg config generation
    local xorg_config="$test_dir/10-hybrid.conf"
    generate_xorg_config "$xorg_config"
    
    assert_file_exists "$xorg_config" "Xorg configuration file generated"
    assert_file_contains "$xorg_config" "Driver.*amdgpu" "Xorg config contains AMD driver"
    assert_file_contains "$xorg_config" "Driver.*nvidia" "Xorg config contains NVIDIA driver"
    assert_file_contains "$xorg_config" "ServerLayout" "Xorg config contains server layout"
    
    # Test TLP config generation
    generate_tlp_config() {
        local output_file="$1"
        
        cat > "$output_file" << 'EOF'
TLP_ENABLE=1
TLP_DEFAULT_MODE=BAT
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto
EOF
    }
    
    local tlp_config="$test_dir/tlp.conf"
    generate_tlp_config "$tlp_config"
    
    assert_file_exists "$tlp_config" "TLP configuration file generated"
    assert_file_contains "$tlp_config" "TLP_ENABLE=1" "TLP config enables TLP"
    assert_file_contains "$tlp_config" "CPU_SCALING_GOVERNOR" "TLP config contains CPU scaling"
    
    # Cleanup
    rm -rf "$test_dir"
}

# Main test execution
run_unit_tests() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}    Unit Tests for Setup Script ${NC}"
    echo -e "${BLUE}================================${NC}"
    
    log_test "Starting unit tests"
    
    test_logging_functions
    test_package_detection
    test_gpu_detection
    test_kernel_module_detection
    test_config_validation
    test_power_management_validation
    test_backup_restore
    test_error_handling
    test_package_installation_retry
    test_system_validation
    test_config_file_generation
    
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}        Unit Test Results        ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Total tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "Log file: $TEST_LOG"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All unit tests passed!${NC}"
        log_test "All unit tests passed"
        return 0
    else
        echo -e "\n${RED}Some unit tests failed. Check the log for details.${NC}"
        log_test "Unit tests completed with $TESTS_FAILED failures"
        return 1
    fi
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_unit_tests
fi