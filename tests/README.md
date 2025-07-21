# Automated Testing and Validation Suite

This directory contains a comprehensive testing framework for the ASUS ROG Zephyrus G14 laptop configuration system. The test suite validates hardware compatibility, system performance, and ensures the setup scripts work correctly.

## Test Suite Overview

### 🧪 Unit Tests (`unit/test_setup_functions.sh`)
Tests individual functions and components from the main setup script:
- Logging functions
- Package detection and installation retry logic
- GPU and kernel module detection
- Configuration file validation
- Power management validation
- Backup and restore functionality
- Error handling mechanisms
- System validation functions

### 🔗 Integration Tests (`integration/test_complete_setup.sh`)
Tests the complete setup workflow end-to-end:
- Package installation workflow
- Xorg configuration setup
- Power management configuration
- GPU switching system setup
- ASUS hardware integration
- System services configuration
- Post-installation validation
- Error handling and recovery

### 🖥️ Hardware Compatibility Tests (`hardware/test_compatibility.sh`)
Validates hardware compatibility and detection:
- CPU compatibility and feature detection
- GPU compatibility (AMD/NVIDIA hybrid setup)
- Laptop model compatibility
- Memory and storage validation
- Power management hardware
- Connectivity hardware (WiFi, Bluetooth, USB)
- Generates detailed compatibility reports

### ⚡ Performance Benchmarks (`performance/test_benchmarks.sh`)
Benchmarks system performance and power efficiency:
- CPU performance testing
- GPU performance validation
- Memory bandwidth testing
- Storage I/O performance
- Power management testing
- Battery life estimation
- Idle vs. load power consumption analysis

## Quick Start

### Run All Tests
```bash
# Run comprehensive test suite
./tests/run_all_tests.sh

# Run with verbose output
./tests/run_all_tests.sh --verbose

# Run quick tests (reduced duration)
./tests/run_all_tests.sh --quick
```

### Run Individual Test Suites
```bash
# Unit tests only
./tests/run_all_tests.sh --unit-only

# Hardware compatibility only
./tests/run_all_tests.sh --hardware-only

# Performance benchmarks only
./tests/run_all_tests.sh --performance-only

# Integration tests only
./tests/run_all_tests.sh --integration-only
```

### Run Individual Test Files
```bash
# Run unit tests directly
bash tests/unit/test_setup_functions.sh

# Run hardware compatibility tests
bash tests/hardware/test_compatibility.sh

# Run performance benchmarks
bash tests/performance/test_benchmarks.sh

# Run integration tests
bash tests/integration/test_complete_setup.sh
```

## Test Framework Validation

Before running the main test suites, you can validate the testing framework itself:

```bash
bash tests/validate_test_framework.sh
```

This ensures all test files are properly structured and the framework is working correctly.

## Test Results and Reports

### Output Locations
- **Logs**: `/tmp/` directory with timestamped filenames
- **Reports**: Generated in `/tmp/test-reports-[timestamp]/` directory
- **HTML Report**: Comprehensive HTML report with all results

### Report Types
1. **Comprehensive Test Report**: HTML format with all test results
2. **Hardware Compatibility Report**: Detailed hardware analysis
3. **Performance Benchmark Report**: System performance metrics
4. **Individual Test Logs**: Detailed logs for each test suite

## Requirements and Dependencies

### Required Tools
- `bash` (version 4.0+)
- `bc` (for calculations)
- Standard Linux utilities (`lscpu`, `lspci`, `free`, `df`, etc.)

### Recommended Tools (for enhanced testing)
- `sysbench` (CPU and memory benchmarks)
- `stress` (system stress testing)
- `fio` (storage I/O testing)
- `glxgears` (GPU testing)
- `tlp-stat` (power management validation)

### Installation of Optional Tools
```bash
# Arch Linux
sudo pacman -S sysbench stress fio mesa-demos tlp

# Ubuntu/Debian
sudo apt install sysbench stress fio mesa-utils tlp
```

## Test Configuration

### Environment Variables
- `BENCHMARK_DURATION`: Duration for performance tests (default: 30 seconds)
- `BATTERY_TEST_DURATION`: Duration for battery tests (default: 300 seconds)
- `VERBOSE`: Enable verbose output (true/false)

### Quick Mode
Use `--quick` flag to run tests with reduced durations:
- Benchmark duration: 10 seconds
- Battery test duration: 60 seconds

## Understanding Test Results

### Test Status Indicators
- ✅ **PASS**: Test completed successfully
- ❌ **FAIL**: Test failed, issue detected
- ⚠️ **SKIP**: Test skipped (missing dependencies or not applicable)
- ℹ️ **INFO**: Informational message

### Exit Codes
- `0`: All tests passed
- `1`: Some tests failed (minor issues)
- `2`: Multiple tests failed (significant issues)

### Compatibility Levels
- **Full**: Complete compatibility, all features supported
- **Partial**: Most features work, minor limitations
- **Limited**: Basic functionality only
- **Incompatible**: Significant issues, not recommended

## Troubleshooting

### Common Issues

#### Missing Dependencies
```bash
# Install missing tools
sudo pacman -S bc sysbench stress fio mesa-demos

# Or run without optional tools (some tests will be skipped)
./tests/run_all_tests.sh
```

#### Permission Issues
```bash
# Ensure scripts are executable
chmod +x tests/*.sh tests/*/*.sh

# Some tests may require sudo for hardware access
```

#### Display Issues (for GPU tests)
```bash
# Ensure X11 is running for GPU tests
echo $DISPLAY

# Or run in headless mode (GPU tests will be skipped)
```

### Test Failures

1. **Review detailed logs** in the generated report directory
2. **Check hardware compatibility** report for specific issues
3. **Verify system requirements** are met
4. **Run individual test suites** to isolate problems

## Contributing

### Adding New Tests

1. **Unit Tests**: Add test functions to `test_setup_functions.sh`
2. **Integration Tests**: Add workflow tests to `test_complete_setup.sh`
3. **Hardware Tests**: Add compatibility checks to `test_compatibility.sh`
4. **Performance Tests**: Add benchmarks to `test_benchmarks.sh`

### Test Function Template
```bash
test_new_functionality() {
    print_test_header "Testing New Functionality"
    
    # Test implementation
    local result=$(some_test_command)
    
    # Assertion
    assert_equals "expected" "$result" "Test description"
}
```

### Mock Function Template
```bash
mock_system_command() {
    local input="$1"
    case "$input" in
        "expected_input") echo "expected_output"; return 0 ;;
        *) return 1 ;;
    esac
}
```

## Integration with CI/CD

The test suite is designed to work in automated environments:

```bash
# Non-interactive mode
./tests/run_all_tests.sh --quick --verbose > test_results.log 2>&1

# Check exit code
if [ $? -eq 0 ]; then
    echo "All tests passed"
else
    echo "Tests failed, check test_results.log"
fi
```

## Performance Considerations

### Test Duration
- **Full test suite**: 10-15 minutes
- **Quick mode**: 3-5 minutes
- **Individual suites**: 1-3 minutes each

### Resource Usage
- **CPU**: High during performance tests
- **Memory**: Moderate (< 1GB)
- **Storage**: Temporary files in `/tmp` (< 100MB)
- **Network**: Minimal (only for connectivity tests)

### Battery Impact
- Performance tests may drain battery faster
- Consider running on AC power for consistent results
- Battery tests measure actual power consumption

## Support

For issues with the testing framework:

1. Check the test logs for detailed error messages
2. Validate the test framework with `validate_test_framework.sh`
3. Ensure all dependencies are installed
4. Review the hardware compatibility report

The testing suite is designed to be robust and provide clear feedback about system readiness for the laptop configuration setup.