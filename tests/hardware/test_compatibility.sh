#!/bin/bash

# Hardware Compatibility Detection and Validation Tests
# Tests hardware detection and compatibility validation

set -euo pipefail

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_LOG="/tmp/hardware-compatibility-tests-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Hardware compatibility database
declare -A SUPPORTED_CPUS=(
    ["AMD Ryzen 9 7940HS"]="full"
    ["AMD Ryzen 7 7735HS"]="full"
    ["AMD Ryzen 9 6900HS"]="full"
    ["AMD Ryzen 7 6800HS"]="full"
    ["AMD Ryzen 5 6600HS"]="partial"
    ["Intel Core i7"]="limited"
    ["Intel Core i5"]="limited"
)

declare -A SUPPORTED_GPUS=(
    ["NVIDIA GeForce RTX 4070"]="full"
    ["NVIDIA GeForce RTX 4060"]="full"
    ["NVIDIA GeForce RTX 3070"]="full"
    ["NVIDIA GeForce RTX 3060"]="full"
    ["AMD Radeon RX 6800M"]="amd_only"
    ["AMD Radeon RX 6700M"]="amd_only"
    ["Intel Iris Xe"]="limited"
)

declare -A SUPPORTED_LAPTOPS=(
    ["ASUS ROG Zephyrus G14"]="full"
    ["ASUS ROG Zephyrus G15"]="full"
    ["ASUS TUF Gaming A15"]="partial"
    ["ASUS TUF Gaming F15"]="partial"
    ["Lenovo Legion 5"]="limited"
    ["HP Omen 15"]="limited"
)

# Test utilities
log_test() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$TEST_LOG"
}

print_test_header() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
    log_test "TEST SECTION: $1"
}

assert_compatibility() {
    local component="$1"
    local expected_level="$2"
    local actual_level="$3"
    local test_name="$4"
    
    ((TESTS_TOTAL++))
    
    case "$expected_level" in
        "full")
            if [[ "$actual_level" == "full" ]]; then
                echo -e "${GREEN}✓ PASS${NC}: $test_name (Full compatibility)"
                log_test "PASS: $test_name - Full compatibility"
                ((TESTS_PASSED++))
                return 0
            fi
            ;;
        "partial")
            if [[ "$actual_level" == "full" ]] || [[ "$actual_level" == "partial" ]]; then
                echo -e "${YELLOW}✓ PARTIAL${NC}: $test_name (Partial compatibility)"
                log_test "PARTIAL: $test_name - Partial compatibility"
                ((TESTS_PASSED++))
                return 0
            fi
            ;;
        "limited")
            if [[ "$actual_level" != "unsupported" ]]; then
                echo -e "${YELLOW}✓ LIMITED${NC}: $test_name (Limited compatibility)"
                log_test "LIMITED: $test_name - Limited compatibility"
                ((TESTS_PASSED++))
                return 0
            fi
            ;;
    esac
    
    echo -e "${RED}✗ FAIL${NC}: $test_name (Incompatible: $actual_level)"
    log_test "FAIL: $test_name - Incompatible: $actual_level"
    ((TESTS_FAILED++))
    return 1
}

# Hardware detection functions
detect_cpu_model() {
    local cpu_info=$(lscpu 2>/dev/null | grep "Model name" | head -1 | sed 's/.*: *//')
    if [[ -z "$cpu_info" ]]; then
        # Fallback to /proc/cpuinfo
        cpu_info=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ *//')
    fi
    echo "$cpu_info"
}

detect_gpu_models() {
    lspci 2>/dev/null | grep -E "(VGA|3D)" | sed 's/.*: //'
}

detect_laptop_model() {
    local model=""
    if [[ -f /sys/devices/virtual/dmi/id/product_name ]]; then
        model=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)
    elif command -v dmidecode &> /dev/null; then
        model=$(sudo dmidecode -s system-product-name 2>/dev/null)
    fi
    echo "$model"
}

detect_memory_info() {
    local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_gb=$((total_mem / 1024 / 1024))
    echo "${total_gb}GB"
}

detect_storage_info() {
    lsblk -d -o NAME,SIZE,TYPE 2>/dev/null | grep disk | head -5
}

# Compatibility testing functions
test_cpu_compatibility() {
    print_test_header "Testing CPU Compatibility"
    
    local cpu_model=$(detect_cpu_model)
    log_test "Detected CPU: $cpu_model"
    
    local compatibility="unsupported"
    for supported_cpu in "${!SUPPORTED_CPUS[@]}"; do
        if [[ "$cpu_model" == *"$supported_cpu"* ]]; then
            compatibility="${SUPPORTED_CPUS[$supported_cpu]}"
            break
        fi
    done
    
    # Special handling for AMD CPUs
    if [[ "$cpu_model" == *"AMD"* ]] && [[ "$compatibility" == "unsupported" ]]; then
        if [[ "$cpu_model" == *"Ryzen"* ]]; then
            compatibility="partial"
        fi
    fi
    
    assert_compatibility "CPU" "partial" "$compatibility" "CPU compatibility check"
    
    # Test CPU features
    local cpu_features=$(lscpu | grep "Flags" | head -1)
    if [[ "$cpu_features" == *"avx2"* ]]; then
        echo -e "${GREEN}✓${NC} AVX2 support detected"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} AVX2 support not detected"
    fi
    ((TESTS_TOTAL++))
    
    # Test CPU frequency scaling
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        local scaling_driver=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo "unknown")
        echo -e "${BLUE}ℹ${NC} CPU scaling driver: $scaling_driver"
        
        if [[ "$scaling_driver" == "amd-pstate-epp" ]] || [[ "$scaling_driver" == "amd-pstate" ]]; then
            echo -e "${GREEN}✓${NC} AMD P-State driver detected (optimal)"
            ((TESTS_PASSED++))
        elif [[ "$scaling_driver" == "acpi-cpufreq" ]]; then
            echo -e "${YELLOW}⚠${NC} ACPI CPU frequency driver (suboptimal)"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗${NC} Unknown or missing CPU frequency driver"
            ((TESTS_FAILED++))
        fi
        ((TESTS_TOTAL++))
    fi
}

test_gpu_compatibility() {
    print_test_header "Testing GPU Compatibility"
    
    local gpu_models=$(detect_gpu_models)
    log_test "Detected GPUs: $gpu_models"
    
    local amd_gpu_found=false
    local nvidia_gpu_found=false
    local intel_gpu_found=false
    
    while IFS= read -r gpu; do
        if [[ -z "$gpu" ]]; then continue; fi
        
        local compatibility="unsupported"
        for supported_gpu in "${!SUPPORTED_GPUS[@]}"; do
            if [[ "$gpu" == *"$supported_gpu"* ]]; then
                compatibility="${SUPPORTED_GPUS[$supported_gpu]}"
                break
            fi
        done
        
        # Detect GPU types
        if [[ "$gpu" == *"AMD"* ]] || [[ "$gpu" == *"Radeon"* ]]; then
            amd_gpu_found=true
            if [[ "$compatibility" == "unsupported" ]]; then
                compatibility="partial"
            fi
        elif [[ "$gpu" == *"NVIDIA"* ]] || [[ "$gpu" == *"GeForce"* ]]; then
            nvidia_gpu_found=true
            if [[ "$compatibility" == "unsupported" ]]; then
                compatibility="partial"
            fi
        elif [[ "$gpu" == *"Intel"* ]]; then
            intel_gpu_found=true
            compatibility="limited"
        fi
        
        assert_compatibility "GPU" "partial" "$compatibility" "GPU compatibility: $gpu"
    done <<< "$gpu_models"
    
    # Test hybrid GPU setup
    if [[ "$amd_gpu_found" == true ]] && [[ "$nvidia_gpu_found" == true ]]; then
        echo -e "${GREEN}✓${NC} Hybrid AMD/NVIDIA GPU setup detected (optimal)"
        ((TESTS_PASSED++))
    elif [[ "$amd_gpu_found" == true ]]; then
        echo -e "${YELLOW}⚠${NC} AMD GPU only (limited functionality)"
        ((TESTS_PASSED++))
    elif [[ "$nvidia_gpu_found" == true ]]; then
        echo -e "${YELLOW}⚠${NC} NVIDIA GPU only (limited functionality)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} No compatible GPU detected"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
}

test_laptop_compatibility() {
    print_test_header "Testing Laptop Model Compatibility"
    
    local laptop_model=$(detect_laptop_model)
    log_test "Detected laptop: $laptop_model"
    
    if [[ -z "$laptop_model" ]]; then
        echo -e "${YELLOW}⚠${NC} Could not detect laptop model"
        ((TESTS_PASSED++))
        ((TESTS_TOTAL++))
        return
    fi
    
    local compatibility="unsupported"
    for supported_laptop in "${!SUPPORTED_LAPTOPS[@]}"; do
        if [[ "$laptop_model" == *"$supported_laptop"* ]]; then
            compatibility="${SUPPORTED_LAPTOPS[$supported_laptop]}"
            break
        fi
    done
    
    # Special handling for ASUS laptops
    if [[ "$laptop_model" == *"ASUS"* ]] && [[ "$compatibility" == "unsupported" ]]; then
        compatibility="partial"
    fi
    
    assert_compatibility "Laptop" "partial" "$compatibility" "Laptop model compatibility"
}

test_memory_compatibility() {
    print_test_header "Testing Memory Configuration"
    
    local memory_info=$(detect_memory_info)
    log_test "Detected memory: $memory_info"
    
    local memory_gb=$(echo "$memory_info" | sed 's/GB//')
    
    if [[ $memory_gb -ge 16 ]]; then
        echo -e "${GREEN}✓${NC} Memory: $memory_info (optimal)"
        ((TESTS_PASSED++))
    elif [[ $memory_gb -ge 8 ]]; then
        echo -e "${YELLOW}⚠${NC} Memory: $memory_info (minimum)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Memory: $memory_info (insufficient)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    # Test memory speed if available
    if command -v dmidecode &> /dev/null; then
        local memory_speed=$(sudo dmidecode -t memory 2>/dev/null | grep "Speed:" | head -1 | awk '{print $2}')
        if [[ -n "$memory_speed" ]] && [[ "$memory_speed" != "Unknown" ]]; then
            echo -e "${BLUE}ℹ${NC} Memory speed: $memory_speed MHz"
            if [[ ${memory_speed%% *} -ge 3200 ]]; then
                echo -e "${GREEN}✓${NC} High-speed memory detected"
            fi
        fi
    fi
}

test_storage_compatibility() {
    print_test_header "Testing Storage Configuration"
    
    local storage_info=$(detect_storage_info)
    log_test "Detected storage: $storage_info"
    
    local nvme_count=$(echo "$storage_info" | grep -i nvme | wc -l)
    local ssd_count=$(lsblk -d -o NAME,ROTA 2>/dev/null | grep "0$" | wc -l)
    
    if [[ $nvme_count -gt 0 ]]; then
        echo -e "${GREEN}✓${NC} NVMe storage detected (optimal)"
        ((TESTS_PASSED++))
    elif [[ $ssd_count -gt 0 ]]; then
        echo -e "${YELLOW}⚠${NC} SSD storage detected (good)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} No SSD storage detected (suboptimal)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    # Check available space
    local root_space=$(df -h / | tail -1 | awk '{print $4}')
    echo -e "${BLUE}ℹ${NC} Available space: $root_space"
}

test_power_management_hardware() {
    print_test_header "Testing Power Management Hardware"
    
    # Test battery presence
    if [[ -d /sys/class/power_supply/BAT* ]]; then
        echo -e "${GREEN}✓${NC} Battery detected"
        ((TESTS_PASSED++))
        
        # Test battery capacity
        local battery_path=$(ls /sys/class/power_supply/BAT* | head -1)
        if [[ -f "$battery_path/capacity" ]]; then
            local battery_level=$(cat "$battery_path/capacity")
            echo -e "${BLUE}ℹ${NC} Battery level: $battery_level%"
        fi
        
        if [[ -f "$battery_path/energy_full_design" ]] && [[ -f "$battery_path/energy_full" ]]; then
            local design_capacity=$(cat "$battery_path/energy_full_design")
            local current_capacity=$(cat "$battery_path/energy_full")
            local health=$((current_capacity * 100 / design_capacity))
            echo -e "${BLUE}ℹ${NC} Battery health: $health%"
        fi
    else
        echo -e "${YELLOW}⚠${NC} No battery detected (desktop system?)"
        ((TESTS_PASSED++))
    fi
    ((TESTS_TOTAL++))
    
    # Test AC adapter
    if [[ -d /sys/class/power_supply/A* ]]; then
        echo -e "${GREEN}✓${NC} AC adapter detected"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} AC adapter not detected"
        ((TESTS_PASSED++))
    fi
    ((TESTS_TOTAL++))
    
    # Test thermal zones
    local thermal_zones=$(ls /sys/class/thermal/thermal_zone* 2>/dev/null | wc -l)
    if [[ $thermal_zones -gt 0 ]]; then
        echo -e "${GREEN}✓${NC} Thermal management zones detected ($thermal_zones zones)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} No thermal management zones detected"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
}

test_connectivity_hardware() {
    print_test_header "Testing Connectivity Hardware"
    
    # Test WiFi
    local wifi_devices=$(lspci | grep -i "network\|wireless\|wifi" | wc -l)
    if [[ $wifi_devices -gt 0 ]]; then
        echo -e "${GREEN}✓${NC} WiFi hardware detected"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} No WiFi hardware detected"
        ((TESTS_PASSED++))
    fi
    ((TESTS_TOTAL++))
    
    # Test Bluetooth
    if command -v bluetoothctl &> /dev/null; then
        if bluetoothctl show 2>/dev/null | grep -q "Controller"; then
            echo -e "${GREEN}✓${NC} Bluetooth hardware detected"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠${NC} Bluetooth hardware not detected"
            ((TESTS_PASSED++))
        fi
    else
        echo -e "${BLUE}ℹ${NC} Bluetooth tools not installed"
        ((TESTS_PASSED++))
    fi
    ((TESTS_TOTAL++))
    
    # Test USB ports
    local usb_controllers=$(lspci | grep -i "usb" | wc -l)
    if [[ $usb_controllers -gt 0 ]]; then
        echo -e "${GREEN}✓${NC} USB controllers detected ($usb_controllers controllers)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} No USB controllers detected"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
}

# Generate compatibility report
generate_compatibility_report() {
    local report_file="/tmp/hardware-compatibility-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
Hardware Compatibility Report
Generated: $(date)
========================================

System Information:
- CPU: $(detect_cpu_model)
- Memory: $(detect_memory_info)
- Laptop Model: $(detect_laptop_model)

GPU Information:
$(detect_gpu_models | sed 's/^/- /')

Storage Information:
$(detect_storage_info | sed 's/^/- /')

Test Results:
- Total Tests: $TESTS_TOTAL
- Passed: $TESTS_PASSED
- Failed: $TESTS_FAILED
- Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%

Compatibility Assessment:
$(if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ COMPATIBLE: This hardware is compatible with the setup script."
elif [[ $TESTS_FAILED -le 2 ]]; then
    echo "⚠ PARTIALLY COMPATIBLE: This hardware has minor compatibility issues."
else
    echo "✗ INCOMPATIBLE: This hardware has significant compatibility issues."
fi)

Recommendations:
$(if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "- Review failed tests in the detailed log: $TEST_LOG"
    echo "- Consider hardware upgrades for optimal performance"
    echo "- Some features may not work as expected"
else
    echo "- Hardware is fully compatible"
    echo "- All features should work optimally"
fi)

EOF
    
    echo "$report_file"
}

# Main compatibility test execution
run_compatibility_tests() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Hardware Compatibility Tests  ${NC}"
    echo -e "${BLUE}================================${NC}"
    
    log_test "Starting hardware compatibility tests"
    
    # Run all compatibility tests
    test_cpu_compatibility
    test_gpu_compatibility
    test_laptop_compatibility
    test_memory_compatibility
    test_storage_compatibility
    test_power_management_hardware
    test_connectivity_hardware
    
    # Generate report
    local report_file=$(generate_compatibility_report)
    
    # Display results
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}   Compatibility Test Results   ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Total tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "Success rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo -e "Detailed log: $TEST_LOG"
    echo -e "Compatibility report: $report_file"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ HARDWARE COMPATIBLE${NC}"
        echo -e "${GREEN}Your hardware is fully compatible with this setup script.${NC}"
        log_test "Hardware compatibility: COMPATIBLE"
        return 0
    elif [[ $TESTS_FAILED -le 2 ]]; then
        echo -e "\n${YELLOW}⚠ PARTIALLY COMPATIBLE${NC}"
        echo -e "${YELLOW}Your hardware has minor compatibility issues.${NC}"
        echo -e "${YELLOW}The setup may work with reduced functionality.${NC}"
        log_test "Hardware compatibility: PARTIALLY COMPATIBLE"
        return 1
    else
        echo -e "\n${RED}✗ HARDWARE INCOMPATIBLE${NC}"
        echo -e "${RED}Your hardware has significant compatibility issues.${NC}"
        echo -e "${RED}The setup script may not work properly.${NC}"
        log_test "Hardware compatibility: INCOMPATIBLE"
        return 2
    fi
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_compatibility_tests
fi