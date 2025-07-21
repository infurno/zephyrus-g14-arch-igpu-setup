#!/bin/bash

# Comprehensive Test Runner for Laptop Configuration
# Orchestrates all test suites and generates comprehensive reports

set -euo pipefail

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_LOG="/tmp/comprehensive-tests-$(date +%Y%m%d-%H%M%S).log"
REPORT_DIR="/tmp/test-reports-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Test suite configuration
UNIT_TESTS_ENABLED=true
INTEGRATION_TESTS_ENABLED=true
HARDWARE_TESTS_ENABLED=true
PERFORMANCE_TESTS_ENABLED=true
QUICK_MODE=false
VERBOSE_MODE=false

# Test results tracking
declare -A TEST_SUITE_RESULTS
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Utility functions
log_test() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TEST_LOG"
}

print_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    Comprehensive Test Suite Runner                          ║
║                   ASUS ROG Zephyrus G14 Configuration                       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  This test runner validates the entire laptop configuration system          ║
║  including hardware compatibility, performance, and functionality.          ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -q, --quick             Run quick tests only (reduced duration)
    --unit-only             Run unit tests only
    --integration-only      Run integration tests only
    --hardware-only         Run hardware compatibility tests only
    --performance-only      Run performance benchmarks only
    --skip-unit             Skip unit tests
    --skip-integration      Skip integration tests
    --skip-hardware         Skip hardware compatibility tests
    --skip-performance      Skip performance benchmarks
    --report-dir DIR        Specify custom report directory

Test Suites:
    Unit Tests              Test individual script functions and components
    Integration Tests       Test complete setup workflow end-to-end
    Hardware Tests          Validate hardware compatibility and detection
    Performance Tests       Benchmark system performance and battery life

Examples:
    $(basename "$0")                    # Run all test suites
    $(basename "$0") --quick            # Run quick tests
    $(basename "$0") --unit-only        # Run only unit tests
    $(basename "$0") --skip-performance # Skip performance benchmarks
    $(basename "$0") --verbose          # Verbose output

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -q|--quick)
                QUICK_MODE=true
                shift
                ;;
            --unit-only)
                INTEGRATION_TESTS_ENABLED=false
                HARDWARE_TESTS_ENABLED=false
                PERFORMANCE_TESTS_ENABLED=false
                shift
                ;;
            --integration-only)
                UNIT_TESTS_ENABLED=false
                HARDWARE_TESTS_ENABLED=false
                PERFORMANCE_TESTS_ENABLED=false
                shift
                ;;
            --hardware-only)
                UNIT_TESTS_ENABLED=false
                INTEGRATION_TESTS_ENABLED=false
                PERFORMANCE_TESTS_ENABLED=false
                shift
                ;;
            --performance-only)
                UNIT_TESTS_ENABLED=false
                INTEGRATION_TESTS_ENABLED=false
                HARDWARE_TESTS_ENABLED=false
                shift
                ;;
            --skip-unit)
                UNIT_TESTS_ENABLED=false
                shift
                ;;
            --skip-integration)
                INTEGRATION_TESTS_ENABLED=false
                shift
                ;;
            --skip-hardware)
                HARDWARE_TESTS_ENABLED=false
                shift
                ;;
            --skip-performance)
                PERFORMANCE_TESTS_ENABLED=false
                shift
                ;;
            --report-dir)
                REPORT_DIR="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Test suite execution functions
run_test_suite() {
    local suite_name="$1"
    local test_script="$2"
    local description="$3"
    
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║$(printf "%-78s" "  Running $suite_name")║${NC}"
    echo -e "${CYAN}║$(printf "%-78s" "  $description")║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    log_test "Starting test suite: $suite_name"
    
    local start_time=$(date +%s)
    local suite_log="$REPORT_DIR/${suite_name,,}_results.log"
    
    if [[ -f "$test_script" ]]; then
        if [[ "$VERBOSE_MODE" == true ]]; then
            bash "$test_script" 2>&1 | tee "$suite_log"
            local exit_code=${PIPESTATUS[0]}
        else
            bash "$test_script" > "$suite_log" 2>&1
            local exit_code=$?
        fi
    else
        echo -e "${RED}✗ SKIP${NC}: Test script not found: $test_script"
        log_test "SKIP: $suite_name - Test script not found"
        TEST_SUITE_RESULTS["$suite_name"]="SKIP"
        return 2
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    ((TOTAL_SUITES++))
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "\n${GREEN}✓ PASS${NC}: $suite_name completed successfully (${duration}s)"
        log_test "PASS: $suite_name completed in ${duration}s"
        TEST_SUITE_RESULTS["$suite_name"]="PASS"
        ((PASSED_SUITES++))
        return 0
    else
        echo -e "\n${RED}✗ FAIL${NC}: $suite_name failed (${duration}s)"
        log_test "FAIL: $suite_name failed in ${duration}s (exit code: $exit_code)"
        TEST_SUITE_RESULTS["$suite_name"]="FAIL"
        ((FAILED_SUITES++))
        return 1
    fi
}

# Pre-test system checks
run_pre_test_checks() {
    echo -e "\n${BLUE}Running pre-test system checks...${NC}"
    
    # Check required tools
    local missing_tools=()
    local recommended_tools=("bc" "stress" "sysbench" "fio" "glxgears")
    
    for tool in "${recommended_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Warning: Missing recommended tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}Some tests may not run properly or may be skipped.${NC}"
        log_test "Missing tools: ${missing_tools[*]}"
    else
        echo -e "${GREEN}✓${NC} All recommended tools are available"
    fi
    
    # Check system resources
    local available_space=$(df -h /tmp | tail -1 | awk '{print $4}')
    echo -e "${BLUE}ℹ${NC} Available space in /tmp: $available_space"
    
    local total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_memory_gb=$((total_memory / 1024 / 1024))
    echo -e "${BLUE}ℹ${NC} Total system memory: ${total_memory_gb}GB"
    
    # Check if running on battery
    if [[ -d /sys/class/power_supply/BAT* ]]; then
        local battery_status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)
        echo -e "${BLUE}ℹ${NC} Battery status: $battery_status"
        
        if [[ "$battery_status" == "Discharging" ]] && [[ "$PERFORMANCE_TESTS_ENABLED" == true ]]; then
            echo -e "${YELLOW}⚠ Warning: Running on battery power${NC}"
            echo -e "${YELLOW}Performance tests may be affected by power management.${NC}"
        fi
    fi
    
    log_test "Pre-test checks completed"
}

# Generate comprehensive test report
generate_comprehensive_report() {
    local report_file="$REPORT_DIR/comprehensive_test_report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Laptop Configuration Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #333; padding-bottom: 20px; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .summary-card { background-color: #f8f9fa; padding: 15px; border-radius: 5px; text-align: center; }
        .pass { color: #28a745; }
        .fail { color: #dc3545; }
        .skip { color: #ffc107; }
        .suite-results { margin-bottom: 30px; }
        .suite-header { background-color: #e9ecef; padding: 10px; border-radius: 5px; margin-bottom: 10px; }
        .test-details { margin-left: 20px; }
        pre { background-color: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
        .timestamp { color: #6c757d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>ASUS ROG Zephyrus G14 Configuration Test Report</h1>
            <p class="timestamp">Generated: $(date)</p>
        </div>
        
        <div class="summary">
            <div class="summary-card">
                <h3>Total Test Suites</h3>
                <h2>$TOTAL_SUITES</h2>
            </div>
            <div class="summary-card">
                <h3>Passed</h3>
                <h2 class="pass">$PASSED_SUITES</h2>
            </div>
            <div class="summary-card">
                <h3>Failed</h3>
                <h2 class="fail">$FAILED_SUITES</h2>
            </div>
            <div class="summary-card">
                <h3>Success Rate</h3>
                <h2>$(( PASSED_SUITES * 100 / TOTAL_SUITES ))%</h2>
            </div>
        </div>
        
        <div class="suite-results">
            <h2>Test Suite Results</h2>
EOF
    
    # Add results for each test suite
    for suite in "${!TEST_SUITE_RESULTS[@]}"; do
        local result="${TEST_SUITE_RESULTS[$suite]}"
        local result_class=""
        case "$result" in
            "PASS") result_class="pass" ;;
            "FAIL") result_class="fail" ;;
            "SKIP") result_class="skip" ;;
        esac
        
        cat >> "$report_file" << EOF
            <div class="suite-header">
                <h3>$suite <span class="$result_class">[$result]</span></h3>
            </div>
            <div class="test-details">
EOF
        
        # Include detailed results if log file exists
        local suite_log="$REPORT_DIR/${suite,,}_results.log"
        if [[ -f "$suite_log" ]]; then
            echo "                <pre>$(tail -50 "$suite_log" | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')</pre>" >> "$report_file"
        fi
        
        echo "            </div>" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
        </div>
        
        <div class="system-info">
            <h2>System Information</h2>
            <pre>
CPU: $(lscpu | grep "Model name" | head -1 | sed 's/.*: *//')
Memory: $(free -h | grep "Mem:" | awk '{print $2}')
GPU: $(lspci | grep -E "(VGA|3D)" | sed 's/.*: //' | head -2)
Kernel: $(uname -r)
            </pre>
        </div>
        
        <div class="recommendations">
            <h2>Recommendations</h2>
            <ul>
EOF
    
    # Add recommendations based on results
    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo "                <li class=\"pass\">✓ All test suites passed successfully. Your system is ready for the laptop configuration.</li>" >> "$report_file"
    elif [[ $FAILED_SUITES -le 1 ]]; then
        echo "                <li class=\"skip\">⚠ Most test suites passed with minor issues. Review failed tests before proceeding.</li>" >> "$report_file"
    else
        echo "                <li class=\"fail\">✗ Multiple test suites failed. Address issues before running the configuration script.</li>" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF
                <li>Review detailed logs in: $REPORT_DIR</li>
                <li>Check hardware compatibility report for specific recommendations</li>
                <li>Ensure all required packages are installed before running setup</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF
    
    echo "$report_file"
}

# Main test execution
main() {
    parse_arguments "$@"
    
    print_banner
    
    # Create report directory
    mkdir -p "$REPORT_DIR"
    
    log_test "Starting comprehensive test suite"
    log_test "Report directory: $REPORT_DIR"
    log_test "Configuration: Quick=$QUICK_MODE, Verbose=$VERBOSE_MODE"
    
    # Run pre-test checks
    run_pre_test_checks
    
    # Set environment variables for quick mode
    if [[ "$QUICK_MODE" == true ]]; then
        export BENCHMARK_DURATION=10
        export BATTERY_TEST_DURATION=60
        log_test "Quick mode enabled - reduced test durations"
    fi
    
    # Run enabled test suites
    if [[ "$UNIT_TESTS_ENABLED" == true ]]; then
        run_test_suite "Unit Tests" "$SCRIPT_DIR/unit/test_setup_functions.sh" "Testing individual script functions and components"
    fi
    
    if [[ "$INTEGRATION_TESTS_ENABLED" == true ]]; then
        run_test_suite "Integration Tests" "$SCRIPT_DIR/integration/test_complete_setup.sh" "Testing complete setup workflow end-to-end"
    fi
    
    if [[ "$HARDWARE_TESTS_ENABLED" == true ]]; then
        run_test_suite "Hardware Compatibility" "$SCRIPT_DIR/hardware/test_compatibility.sh" "Validating hardware compatibility and detection"
    fi
    
    if [[ "$PERFORMANCE_TESTS_ENABLED" == true ]]; then
        run_test_suite "Performance Benchmarks" "$SCRIPT_DIR/performance/test_benchmarks.sh" "Benchmarking system performance and battery life"
    fi
    
    # Generate comprehensive report
    local html_report=$(generate_comprehensive_report)
    
    # Display final results
    echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║$(printf "%-78s" "  COMPREHENSIVE TEST RESULTS")║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\nTest Suite Summary:"
    for suite in "${!TEST_SUITE_RESULTS[@]}"; do
        local result="${TEST_SUITE_RESULTS[$suite]}"
        case "$result" in
            "PASS") echo -e "  ${GREEN}✓${NC} $suite" ;;
            "FAIL") echo -e "  ${RED}✗${NC} $suite" ;;
            "SKIP") echo -e "  ${YELLOW}⚠${NC} $suite" ;;
        esac
    done
    
    echo -e "\nOverall Results:"
    echo -e "  Total test suites: $TOTAL_SUITES"
    echo -e "  ${GREEN}Passed: $PASSED_SUITES${NC}"
    echo -e "  ${RED}Failed: $FAILED_SUITES${NC}"
    echo -e "  Success rate: $(( PASSED_SUITES * 100 / TOTAL_SUITES ))%"
    
    echo -e "\nReports Generated:"
    echo -e "  HTML Report: $html_report"
    echo -e "  Detailed logs: $REPORT_DIR"
    echo -e "  Main log: $TEST_LOG"
    
    # Final assessment
    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 ALL TESTS PASSED!${NC}"
        echo -e "${GREEN}Your system is ready for the laptop configuration setup.${NC}"
        log_test "Comprehensive test suite: ALL PASSED"
        return 0
    elif [[ $FAILED_SUITES -le 1 ]]; then
        echo -e "\n${YELLOW}⚠ MOSTLY SUCCESSFUL${NC}"
        echo -e "${YELLOW}Most tests passed with minor issues. Review failed tests.${NC}"
        log_test "Comprehensive test suite: MOSTLY SUCCESSFUL"
        return 1
    else
        echo -e "\n${RED}❌ MULTIPLE FAILURES${NC}"
        echo -e "${RED}Several test suites failed. Address issues before proceeding.${NC}"
        log_test "Comprehensive test suite: MULTIPLE FAILURES"
        return 2
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi