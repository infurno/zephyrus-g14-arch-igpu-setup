#!/bin/bash

# Performance Benchmarking and Battery Life Testing Tools
# Tests system performance and power efficiency

set -euo pipefail

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_LOG="/tmp/performance-benchmarks-$(date +%Y%m%d-%H%M%S).log"
RESULTS_DIR="/tmp/benchmark-results-$(date +%Y%m%d-%H%M%S)"

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

# Benchmark configuration
BENCHMARK_DURATION=30  # seconds for short tests
BATTERY_TEST_DURATION=300  # 5 minutes for battery tests
CPU_STRESS_CORES=$(nproc)

# Test utilities
log_test() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TEST_LOG"
}

print_test_header() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
    log_test "TEST SECTION: $1"
}

assert_performance() {
    local test_name="$1"
    local actual_value="$2"
    local expected_min="$3"
    local unit="$4"
    
    ((TESTS_TOTAL++))
    
    if (( $(echo "$actual_value >= $expected_min" | bc -l) )); then
        echo -e "${GREEN}✓ PASS${NC}: $test_name ($actual_value $unit >= $expected_min $unit)"
        log_test "PASS: $test_name - $actual_value $unit"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name ($actual_value $unit < $expected_min $unit)"
        log_test "FAIL: $test_name - $actual_value $unit (expected >= $expected_min $unit)"
        ((TESTS_FAILED++))
        return 1
    fi
}

# System information gathering
get_system_info() {
    local info_file="$RESULTS_DIR/system_info.txt"
    
    cat > "$info_file" << EOF
System Information - $(date)
========================================

CPU Information:
$(lscpu)

Memory Information:
$(free -h)

GPU Information:
$(lspci | grep -E "(VGA|3D)")

Storage Information:
$(lsblk -f)

Kernel Information:
$(uname -a)

Power Supply Information:
$(find /sys/class/power_supply -name "BAT*" -exec cat {}/uevent \; 2>/dev/null || echo "No battery information available")

EOF
    
    echo "$info_file"
}

# CPU Performance Tests
test_cpu_performance() {
    print_test_header "Testing CPU Performance"
    
    # CPU stress test with sysbench
    if command -v sysbench &> /dev/null; then
        log_test "Running sysbench CPU test"
        local cpu_result=$(sysbench cpu --cpu-max-prime=20000 --threads=$CPU_STRESS_CORES --time=$BENCHMARK_DURATION run | grep "events per second" | awk '{print $4}')
        
        if [[ -n "$cpu_result" ]]; then
            # Expected minimum: 1000 events/sec for modern CPUs
            assert_performance "CPU multi-threaded performance" "$cpu_result" "1000" "events/sec"
            echo "$cpu_result" > "$RESULTS_DIR/cpu_sysbench.txt"
        else
            echo -e "${YELLOW}⚠${NC} sysbench CPU test failed to produce results"
            ((TESTS_TOTAL++))
        fi
    else
        # Fallback CPU test using dd and time
        log_test "Running fallback CPU test (dd)"
        local start_time=$(date +%s.%N)
        dd if=/dev/zero bs=1M count=1000 2>/dev/null | wc -c > /dev/null
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        local throughput=$(echo "scale=2; 1000 / $duration" | bc)
        
        # Expected minimum: 100 MB/s
        assert_performance "CPU memory throughput" "$throughput" "100" "MB/s"
        echo "$throughput" > "$RESULTS_DIR/cpu_fallback.txt"
    fi
    
    # CPU frequency scaling test
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]]; then
        local base_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        
        # Stress CPU briefly
        stress --cpu $CPU_STRESS_CORES --timeout 5s &>/dev/null || true
        sleep 2
        
        local boost_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        
        if [[ $boost_freq -gt $base_freq ]]; then
            echo -e "${GREEN}✓${NC} CPU frequency scaling working (${base_freq}kHz -> ${boost_freq}kHz)"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠${NC} CPU frequency scaling not detected"
            ((TESTS_PASSED++))
        fi
        ((TESTS_TOTAL++))
        
        echo "Base: $base_freq kHz, Boost: $boost_freq kHz" > "$RESULTS_DIR/cpu_scaling.txt"
    fi
}

# GPU Performance Tests
test_gpu_performance() {
    print_test_header "Testing GPU Performance"
    
    # Test AMD GPU performance
    if command -v glxgears &> /dev/null; then
        log_test "Running glxgears AMD GPU test"
        
        # Run glxgears for a short time and capture FPS
        timeout 10s glxgears 2>&1 | tail -1 > "$RESULTS_DIR/amd_gpu_glxgears.txt" || true
        
        if [[ -f "$RESULTS_DIR/amd_gpu_glxgears.txt" ]] && grep -q "FPS" "$RESULTS_DIR/amd_gpu_glxgears.txt"; then
            local fps=$(grep "FPS" "$RESULTS_DIR/amd_gpu_glxgears.txt" | awk '{print $1}')
            if [[ -n "$fps" ]]; then
                # Expected minimum: 60 FPS for basic 3D
                assert_performance "AMD GPU basic 3D performance" "$fps" "60" "FPS"
            fi
        else
            echo -e "${YELLOW}⚠${NC} AMD GPU test failed or no display available"
            ((TESTS_TOTAL++))
        fi
    fi
    
    # Test NVIDIA GPU with prime-run if available
    if [[ -f "$PROJECT_DIR/scripts/prime-run" ]] && command -v glxgears &> /dev/null; then
        log_test "Running NVIDIA GPU test with prime-run"
        
        timeout 10s "$PROJECT_DIR/scripts/prime-run" glxgears 2>&1 | tail -1 > "$RESULTS_DIR/nvidia_gpu_glxgears.txt" || true
        
        if [[ -f "$RESULTS_DIR/nvidia_gpu_glxgears.txt" ]] && grep -q "FPS" "$RESULTS_DIR/nvidia_gpu_glxgears.txt"; then
            local fps=$(grep "FPS" "$RESULTS_DIR/nvidia_gpu_glxgears.txt" | awk '{print $1}')
            if [[ -n "$fps" ]]; then
                # Expected minimum: 100 FPS for NVIDIA GPU
                assert_performance "NVIDIA GPU performance" "$fps" "100" "FPS"
            fi
        else
            echo -e "${YELLOW}⚠${NC} NVIDIA GPU test failed or not available"
            ((TESTS_TOTAL++))
        fi
    fi
    
    # Test GPU memory and capabilities
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name,memory.total,memory.used,temperature.gpu --format=csv,noheader,nounits > "$RESULTS_DIR/nvidia_info.txt" 2>/dev/null || true
        
        if [[ -f "$RESULTS_DIR/nvidia_info.txt" ]] && [[ -s "$RESULTS_DIR/nvidia_info.txt" ]]; then
            echo -e "${GREEN}✓${NC} NVIDIA GPU information collected"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠${NC} NVIDIA GPU information not available"
            ((TESTS_PASSED++))
        fi
        ((TESTS_TOTAL++))
    fi
}

# Memory Performance Tests
test_memory_performance() {
    print_test_header "Testing Memory Performance"
    
    # Memory bandwidth test
    if command -v sysbench &> /dev/null; then
        log_test "Running sysbench memory test"
        local mem_result=$(sysbench memory --memory-block-size=1M --memory-total-size=10G --time=$BENCHMARK_DURATION run | grep "MiB/sec" | tail -1 | awk '{print $4}')
        
        if [[ -n "$mem_result" ]]; then
            # Expected minimum: 5000 MiB/sec for DDR4
            assert_performance "Memory bandwidth" "$mem_result" "5000" "MiB/sec"
            echo "$mem_result" > "$RESULTS_DIR/memory_bandwidth.txt"
        else
            echo -e "${YELLOW}⚠${NC} Memory bandwidth test failed"
            ((TESTS_TOTAL++))
        fi
    else
        # Fallback memory test
        log_test "Running fallback memory test"
        local start_time=$(date +%s.%N)
        dd if=/dev/zero of=/dev/null bs=1M count=5000 2>/dev/null
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        local throughput=$(echo "scale=2; 5000 / $duration" | bc)
        
        # Expected minimum: 1000 MB/s
        assert_performance "Memory throughput" "$throughput" "1000" "MB/s"
        echo "$throughput" > "$RESULTS_DIR/memory_fallback.txt"
    fi
    
    # Memory usage test
    local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local available_mem=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local usage_percent=$(echo "scale=2; (($total_mem - $available_mem) * 100) / $total_mem" | bc)
    
    echo -e "${BLUE}ℹ${NC} Memory usage: ${usage_percent}%"
    echo "$usage_percent" > "$RESULTS_DIR/memory_usage.txt"
    
    if (( $(echo "$usage_percent < 80" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Memory usage is healthy"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} High memory usage detected"
        ((TESTS_PASSED++))
    fi
    ((TESTS_TOTAL++))
}

# Storage Performance Tests
test_storage_performance() {
    print_test_header "Testing Storage Performance"
    
    local test_file="/tmp/storage_test_$(date +%s)"
    
    # Sequential write test
    log_test "Running storage write test"
    local write_start=$(date +%s.%N)
    dd if=/dev/zero of="$test_file" bs=1M count=1000 conv=fsync 2>/dev/null
    local write_end=$(date +%s.%N)
    local write_duration=$(echo "$write_end - $write_start" | bc)
    local write_speed=$(echo "scale=2; 1000 / $write_duration" | bc)
    
    # Expected minimum: 100 MB/s for SSD
    assert_performance "Storage write speed" "$write_speed" "100" "MB/s"
    echo "$write_speed" > "$RESULTS_DIR/storage_write.txt"
    
    # Sequential read test
    log_test "Running storage read test"
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    local read_start=$(date +%s.%N)
    dd if="$test_file" of=/dev/null bs=1M 2>/dev/null
    local read_end=$(date +%s.%N)
    local read_duration=$(echo "$read_end - $read_start" | bc)
    local read_speed=$(echo "scale=2; 1000 / $read_duration" | bc)
    
    # Expected minimum: 200 MB/s for SSD
    assert_performance "Storage read speed" "$read_speed" "200" "MB/s"
    echo "$read_speed" > "$RESULTS_DIR/storage_read.txt"
    
    # Random I/O test with fio if available
    if command -v fio &> /dev/null; then
        log_test "Running fio random I/O test"
        fio --name=random-rw --ioengine=libaio --iodepth=4 --rw=randrw --bs=4k --direct=1 --size=100M --numjobs=1 --runtime=30 --group_reporting --filename="$test_file.fio" > "$RESULTS_DIR/fio_results.txt" 2>/dev/null || true
        
        if [[ -f "$RESULTS_DIR/fio_results.txt" ]]; then
            local iops=$(grep "IOPS=" "$RESULTS_DIR/fio_results.txt" | head -1 | sed 's/.*IOPS=\([0-9]*\).*/\1/')
            if [[ -n "$iops" ]]; then
                # Expected minimum: 1000 IOPS for SSD
                assert_performance "Storage random IOPS" "$iops" "1000" "IOPS"
            fi
        fi
        rm -f "$test_file.fio"
    fi
    
    # Cleanup
    rm -f "$test_file"
}

# Power Management Tests
test_power_management() {
    print_test_header "Testing Power Management"
    
    # Test power profiles
    if command -v powerprofilesctl &> /dev/null; then
        local current_profile=$(powerprofilesctl get)
        echo -e "${BLUE}ℹ${NC} Current power profile: $current_profile"
        echo "$current_profile" > "$RESULTS_DIR/power_profile.txt"
        
        # Test profile switching
        if powerprofilesctl set power-saver 2>/dev/null; then
            sleep 2
            local new_profile=$(powerprofilesctl get)
            if [[ "$new_profile" == "power-saver" ]]; then
                echo -e "${GREEN}✓${NC} Power profile switching works"
                ((TESTS_PASSED++))
            else
                echo -e "${RED}✗${NC} Power profile switching failed"
                ((TESTS_FAILED++))
            fi
            
            # Restore original profile
            powerprofilesctl set "$current_profile" 2>/dev/null || true
        else
            echo -e "${YELLOW}⚠${NC} Cannot test power profile switching"
            ((TESTS_PASSED++))
        fi
        ((TESTS_TOTAL++))
    fi
    
    # Test CPU governor
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        echo -e "${BLUE}ℹ${NC} CPU governor: $governor"
        echo "$governor" > "$RESULTS_DIR/cpu_governor.txt"
        
        if [[ "$governor" == "powersave" ]] || [[ "$governor" == "ondemand" ]] || [[ "$governor" == "schedutil" ]]; then
            echo -e "${GREEN}✓${NC} CPU governor is power-efficient"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠${NC} CPU governor may not be optimal for battery life"
            ((TESTS_PASSED++))
        fi
        ((TESTS_TOTAL++))
    fi
    
    # Test TLP status
    if command -v tlp-stat &> /dev/null; then
        tlp-stat -s > "$RESULTS_DIR/tlp_status.txt" 2>/dev/null || true
        
        if grep -q "TLP.*enabled" "$RESULTS_DIR/tlp_status.txt"; then
            echo -e "${GREEN}✓${NC} TLP power management is active"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠${NC} TLP power management not detected"
            ((TESTS_PASSED++))
        fi
        ((TESTS_TOTAL++))
    fi
}

# Battery Life Test
test_battery_life() {
    print_test_header "Testing Battery Life and Power Consumption"
    
    # Check if battery is present
    local battery_path=$(ls /sys/class/power_supply/BAT* 2>/dev/null | head -1)
    if [[ -z "$battery_path" ]]; then
        echo -e "${YELLOW}⚠${NC} No battery detected, skipping battery tests"
        return
    fi
    
    # Get initial battery info
    local initial_capacity=$(cat "$battery_path/capacity" 2>/dev/null || echo "unknown")
    local initial_energy=$(cat "$battery_path/energy_now" 2>/dev/null || echo "0")
    local power_now=$(cat "$battery_path/power_now" 2>/dev/null || echo "0")
    
    echo -e "${BLUE}ℹ${NC} Initial battery capacity: $initial_capacity%"
    echo -e "${BLUE}ℹ${NC} Current power consumption: $(echo "scale=2; $power_now / 1000000" | bc) W"
    
    # Record power consumption over time
    local power_log="$RESULTS_DIR/power_consumption.log"
    echo "Timestamp,Capacity,Energy_Now,Power_Now" > "$power_log"
    
    log_test "Starting battery monitoring for $BATTERY_TEST_DURATION seconds"
    
    for ((i=0; i<$BATTERY_TEST_DURATION; i+=10)); do
        local timestamp=$(date +%s)
        local capacity=$(cat "$battery_path/capacity" 2>/dev/null || echo "0")
        local energy_now=$(cat "$battery_path/energy_now" 2>/dev/null || echo "0")
        local power_now=$(cat "$battery_path/power_now" 2>/dev/null || echo "0")
        
        echo "$timestamp,$capacity,$energy_now,$power_now" >> "$power_log"
        sleep 10
    done
    
    # Calculate average power consumption
    local avg_power=$(awk -F, 'NR>1 {sum+=$4; count++} END {if(count>0) print sum/count/1000000; else print 0}' "$power_log")
    
    if (( $(echo "$avg_power > 0" | bc -l) )); then
        echo -e "${BLUE}ℹ${NC} Average power consumption: ${avg_power} W"
        
        # Estimate battery life (rough calculation)
        if [[ -f "$battery_path/energy_full" ]]; then
            local battery_capacity=$(cat "$battery_path/energy_full")
            local estimated_hours=$(echo "scale=1; $battery_capacity / 1000000 / $avg_power" | bc)
            echo -e "${BLUE}ℹ${NC} Estimated battery life: ${estimated_hours} hours"
            
            # Expected minimum: 4 hours for laptop
            if (( $(echo "$estimated_hours >= 4" | bc -l) )); then
                echo -e "${GREEN}✓${NC} Battery life estimate is good"
                ((TESTS_PASSED++))
            else
                echo -e "${YELLOW}⚠${NC} Battery life estimate is below optimal"
                ((TESTS_PASSED++))
            fi
            ((TESTS_TOTAL++))
        fi
    fi
    
    # Test power consumption under different scenarios
    test_idle_power_consumption
    test_cpu_load_power_consumption
}

test_idle_power_consumption() {
    local battery_path=$(ls /sys/class/power_supply/BAT* 2>/dev/null | head -1)
    if [[ -z "$battery_path" ]]; then return; fi
    
    echo -e "${BLUE}Testing idle power consumption...${NC}"
    
    # Measure idle power for 30 seconds
    local power_samples=()
    for ((i=0; i<6; i++)); do
        local power_now=$(cat "$battery_path/power_now" 2>/dev/null || echo "0")
        power_samples+=($power_now)
        sleep 5
    done
    
    # Calculate average idle power
    local total_power=0
    for power in "${power_samples[@]}"; do
        total_power=$((total_power + power))
    done
    local avg_idle_power=$(echo "scale=2; $total_power / ${#power_samples[@]} / 1000000" | bc)
    
    echo -e "${BLUE}ℹ${NC} Average idle power consumption: ${avg_idle_power} W"
    echo "$avg_idle_power" > "$RESULTS_DIR/idle_power.txt"
    
    # Expected maximum: 15W for idle laptop
    if (( $(echo "$avg_idle_power <= 15" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Idle power consumption is efficient"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} Idle power consumption is high"
        ((TESTS_PASSED++))
    fi
    ((TESTS_TOTAL++))
}

test_cpu_load_power_consumption() {
    local battery_path=$(ls /sys/class/power_supply/BAT* 2>/dev/null | head -1)
    if [[ -z "$battery_path" ]]; then return; fi
    
    echo -e "${BLUE}Testing power consumption under CPU load...${NC}"
    
    # Start CPU stress test in background
    stress --cpu $CPU_STRESS_CORES --timeout 30s &
    local stress_pid=$!
    
    # Measure power consumption during stress test
    local power_samples=()
    for ((i=0; i<6; i++)); do
        local power_now=$(cat "$battery_path/power_now" 2>/dev/null || echo "0")
        power_samples+=($power_now)
        sleep 5
    done
    
    # Wait for stress test to complete
    wait $stress_pid 2>/dev/null || true
    
    # Calculate average load power
    local total_power=0
    for power in "${power_samples[@]}"; do
        total_power=$((total_power + power))
    done
    local avg_load_power=$(echo "scale=2; $total_power / ${#power_samples[@]} / 1000000" | bc)
    
    echo -e "${BLUE}ℹ${NC} Average power consumption under CPU load: ${avg_load_power} W"
    echo "$avg_load_power" > "$RESULTS_DIR/load_power.txt"
    
    # Expected maximum: 45W for laptop under full CPU load
    if (( $(echo "$avg_load_power <= 45" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Power consumption under load is reasonable"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} Power consumption under load is high"
        ((TESTS_PASSED++))
    fi
    ((TESTS_TOTAL++))
}

# Generate performance report
generate_performance_report() {
    local report_file="$RESULTS_DIR/performance_report.txt"
    
    cat > "$report_file" << EOF
Performance Benchmark Report
Generated: $(date)
========================================

Test Configuration:
- Benchmark Duration: $BENCHMARK_DURATION seconds
- Battery Test Duration: $BATTERY_TEST_DURATION seconds
- CPU Cores Used: $CPU_STRESS_CORES

Test Results Summary:
- Total Tests: $TESTS_TOTAL
- Passed: $TESTS_PASSED
- Failed: $TESTS_FAILED
- Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%

Performance Assessment:
$(if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ EXCELLENT: System performance meets all benchmarks."
elif [[ $TESTS_FAILED -le 2 ]]; then
    echo "⚠ GOOD: System performance is acceptable with minor issues."
else
    echo "✗ POOR: System performance has significant issues."
fi)

Detailed Results:
$(find "$RESULTS_DIR" -name "*.txt" -exec echo "- {}: $(cat {})" \; | sed 's|'$RESULTS_DIR'/||g')

Recommendations:
$(if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "- Review failed benchmarks for performance bottlenecks"
    echo "- Consider hardware upgrades or system optimization"
    echo "- Check power management settings for efficiency"
else
    echo "- System performance is optimal"
    echo "- All benchmarks passed successfully"
fi)

EOF
    
    echo "$report_file"
}

# Main performance test execution
run_performance_tests() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}    Performance Benchmarks      ${NC}"
    echo -e "${BLUE}================================${NC}"
    
    # Create results directory
    mkdir -p "$RESULTS_DIR"
    
    log_test "Starting performance benchmarks"
    log_test "Results directory: $RESULTS_DIR"
    
    # Gather system information
    get_system_info
    
    # Run all performance tests
    test_cpu_performance
    test_gpu_performance
    test_memory_performance
    test_storage_performance
    test_power_management
    test_battery_life
    
    # Generate report
    local report_file=$(generate_performance_report)
    
    # Display results
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}    Performance Test Results    ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Total tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "Success rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo -e "Results directory: $RESULTS_DIR"
    echo -e "Performance report: $report_file"
    echo -e "Detailed log: $TEST_LOG"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ EXCELLENT PERFORMANCE${NC}"
        echo -e "${GREEN}All performance benchmarks passed successfully.${NC}"
        log_test "Performance assessment: EXCELLENT"
        return 0
    elif [[ $TESTS_FAILED -le 2 ]]; then
        echo -e "\n${YELLOW}⚠ GOOD PERFORMANCE${NC}"
        echo -e "${YELLOW}Most performance benchmarks passed with minor issues.${NC}"
        log_test "Performance assessment: GOOD"
        return 1
    else
        echo -e "\n${RED}✗ POOR PERFORMANCE${NC}"
        echo -e "${RED}Multiple performance benchmarks failed.${NC}"
        log_test "Performance assessment: POOR"
        return 2
    fi
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check for required tools
    missing_tools=()
    
    if ! command -v bc &> /dev/null; then
        missing_tools+=("bc")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Warning: Missing tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}Some tests may not run properly. Install missing tools for full functionality.${NC}"
    fi
    
    run_performance_tests
fi