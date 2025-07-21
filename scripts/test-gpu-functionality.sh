#!/bin/bash

# GPU Functionality Testing and Validation Script
# Tests GPU switching, offload rendering, and performance

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
GPU_TESTS_PASSED=0
GPU_TESTS_FAILED=0
GPU_TESTS_TOTAL=0

# Logging
LOG_FILE="/tmp/gpu-test-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}    GPU Functionality Tests     ${NC}"
    echo -e "${BLUE}================================${NC}"
    log "Starting GPU functionality tests"
}

print_test() {
    echo -e "${YELLOW}Testing: $1${NC}"
    log "GPU_TEST: $1"
}

gpu_test_pass() {
    echo -e "${GREEN}✓ PASS: $1${NC}"
    log "GPU_PASS: $1"
    ((GPU_TESTS_PASSED++))
    ((GPU_TESTS_TOTAL++))
}

gpu_test_fail() {
    echo -e "${RED}✗ FAIL: $1${NC}"
    log "GPU_FAIL: $1"
    ((GPU_TESTS_FAILED++))
    ((GPU_TESTS_TOTAL++))
}

print_info() {
    echo -e "${CYAN}Info: $1${NC}"
    log "GPU_INFO: $1"
}

# Test AMD GPU functionality
test_amd_gpu() {
    print_test "AMD GPU functionality"
    
    # Check if AMD GPU is detected
    if ! lspci | grep -i "vga.*amd\|vga.*radeon" &>/dev/null; then
        gpu_test_fail "AMD GPU not detected in lspci"
        return
    fi
    
    # Check if amdgpu driver is loaded
    if ! lsmod | grep -q "amdgpu"; then
        gpu_test_fail "amdgpu driver not loaded"
        return
    fi
    
    # Test OpenGL with AMD GPU
    if command -v glxinfo &>/dev/null; then
        local amd_renderer=$(DRI_PRIME=0 glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1)
        if echo "$amd_renderer" | grep -qi "amd\|radeon"; then
            gpu_test_pass "AMD GPU OpenGL rendering working"
            print_info "AMD Renderer: $amd_renderer"
        else
            gpu_test_fail "AMD GPU OpenGL rendering not working"
        fi
    else
        gpu_test_fail "glxinfo not available for testing"
    fi
    
    # Test Vulkan with AMD GPU
    if command -v vulkaninfo &>/dev/null; then
        if vulkaninfo 2>/dev/null | grep -qi "amd\|radeon"; then
            gpu_test_pass "AMD GPU Vulkan support working"
        else
            gpu_test_fail "AMD GPU Vulkan support not working"
        fi
    else
        print_info "vulkaninfo not available for Vulkan testing"
    fi
}

# Test NVIDIA GPU functionality
test_nvidia_gpu() {
    print_test "NVIDIA GPU functionality"
    
    # Check if NVIDIA GPU is detected
    if ! lspci | grep -i "vga.*nvidia\|3d.*nvidia" &>/dev/null; then
        gpu_test_fail "NVIDIA GPU not detected in lspci"
        return
    fi
    
    # Check if nvidia driver is loaded
    if ! lsmod | grep -q "nvidia"; then
        gpu_test_fail "NVIDIA driver not loaded"
        return
    fi
    
    # Test nvidia-smi
    if command -v nvidia-smi &>/dev/null; then
        if nvidia-smi &>/dev/null; then
            gpu_test_pass "nvidia-smi working"
            local gpu_info=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader,nounits)
            print_info "NVIDIA GPU: $gpu_info"
        else
            gpu_test_fail "nvidia-smi not responding"
        fi
    else
        gpu_test_fail "nvidia-smi not available"
    fi
    
    # Test NVIDIA OpenGL
    if command -v glxinfo &>/dev/null; then
        local nvidia_renderer=$(DRI_PRIME=1 glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1)
        if echo "$nvidia_renderer" | grep -qi "nvidia"; then
            gpu_test_pass "NVIDIA GPU OpenGL rendering working"
            print_info "NVIDIA Renderer: $nvidia_renderer"
        else
            gpu_test_fail "NVIDIA GPU OpenGL rendering not working"
        fi
    fi
    
    # Test CUDA if available
    if command -v nvcc &>/dev/null; then
        if nvcc --version &>/dev/null; then
            gpu_test_pass "CUDA compiler available"
            local cuda_version=$(nvcc --version | grep "release" | awk '{print $6}')
            print_info "CUDA Version: $cuda_version"
        else
            gpu_test_fail "CUDA compiler not working"
        fi
    else
        print_info "CUDA compiler not installed"
    fi
}

# Test GPU switching functionality
test_gpu_switching() {
    print_test "GPU switching functionality"
    
    # Test prime-run availability
    if ! command -v prime-run &>/dev/null; then
        gpu_test_fail "prime-run command not available"
        return
    fi
    
    # Test prime-run with a simple OpenGL command
    if command -v glxinfo &>/dev/null; then
        # Test default GPU (should be AMD)
        local default_gpu=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1)
        
        # Test NVIDIA GPU via prime-run
        local nvidia_gpu=$(prime-run glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1)
        
        if [ "$default_gpu" != "$nvidia_gpu" ]; then
            gpu_test_pass "GPU switching working (prime-run changes renderer)"
            print_info "Default: $default_gpu"
            print_info "Prime-run: $nvidia_gpu"
        else
            gpu_test_fail "GPU switching not working (same renderer for both)"
        fi
    else
        gpu_test_fail "Cannot test GPU switching without glxinfo"
    fi
    
    # Test supergfxctl if available
    if command -v supergfxctl &>/dev/null; then
        local current_mode=$(supergfxctl -g 2>/dev/null || echo "unknown")
        if [ "$current_mode" != "unknown" ]; then
            gpu_test_pass "supergfxctl working (mode: $current_mode)"
        else
            gpu_test_fail "supergfxctl not responding"
        fi
    else
        print_info "supergfxctl not available"
    fi
}

# Test GPU power management
test_gpu_power_management() {
    print_test "GPU power management"
    
    # Test bbswitch functionality
    if [ -f "/proc/acpi/bbswitch" ]; then
        local nvidia_state=$(cat /proc/acpi/bbswitch | awk '{print $2}')
        gpu_test_pass "bbswitch working (NVIDIA state: $nvidia_state)"
        
        # Test power state switching (if running as root)
        if [ $EUID -eq 0 ]; then
            print_info "Testing NVIDIA power state switching..."
            
            # Turn OFF
            echo OFF > /proc/acpi/bbswitch
            sleep 1
            local off_state=$(cat /proc/acpi/bbswitch | awk '{print $2}')
            
            # Turn ON
            echo ON > /proc/acpi/bbswitch
            sleep 1
            local on_state=$(cat /proc/acpi/bbswitch | awk '{print $2}')
            
            if [ "$off_state" = "OFF" ] && [ "$on_state" = "ON" ]; then
                gpu_test_pass "NVIDIA power switching working"
            else
                gpu_test_fail "NVIDIA power switching not working"
            fi
        else
            print_info "Run as root to test power state switching"
        fi
    else
        gpu_test_fail "bbswitch not available"
    fi
    
    # Check NVIDIA power consumption
    if command -v nvidia-smi &>/dev/null; then
        local power_draw=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [ -n "$power_draw" ] && [ "$power_draw" != "N/A" ]; then
            print_info "NVIDIA power draw: ${power_draw}W"
            
            # Check if power draw is reasonable
            if (( $(echo "$power_draw < 5" | bc -l) )); then
                gpu_test_pass "NVIDIA GPU in low power state"
            elif (( $(echo "$power_draw > 50" | bc -l) )); then
                print_info "NVIDIA GPU in high power state (may be under load)"
            fi
        fi
    fi
}

# Test display output functionality
test_display_output() {
    print_test "Display output functionality"
    
    if [ -z "$DISPLAY" ]; then
        gpu_test_fail "No X11 display available"
        return
    fi
    
    # Test xrandr functionality
    if ! command -v xrandr &>/dev/null; then
        gpu_test_fail "xrandr not available"
        return
    fi
    
    # Get display information
    local displays=$(xrandr --listmonitors 2>/dev/null | grep -c "Monitor" || echo "0")
    if [ "$displays" -gt 0 ]; then
        gpu_test_pass "Display detection working ($displays monitor(s))"
        
        # List all displays
        xrandr --listmonitors 2>/dev/null | grep "Monitor" | while read -r line; do
            print_info "Display: $line"
        done
    else
        gpu_test_fail "No displays detected"
    fi
    
    # Test display providers (for GPU offloading)
    local providers=$(xrandr --listproviders 2>/dev/null | grep -c "Provider" || echo "0")
    if [ "$providers" -gt 1 ]; then
        gpu_test_pass "Multiple display providers detected (good for GPU offloading)"
        xrandr --listproviders 2>/dev/null | grep "Provider" | while read -r line; do
            print_info "Provider: $line"
        done
    else
        print_info "Single display provider detected"
    fi
}

# Performance benchmark tests
test_gpu_performance() {
    print_test "GPU performance benchmarks"
    
    # Simple OpenGL performance test
    if command -v glxgears &>/dev/null; then
        print_info "Running glxgears performance test..."
        
        # Test AMD GPU performance
        timeout 5s glxgears 2>/dev/null | tail -1 | while read -r line; do
            if echo "$line" | grep -q "frames"; then
                print_info "AMD GPU (glxgears): $line"
            fi
        done
        
        # Test NVIDIA GPU performance
        if command -v prime-run &>/dev/null; then
            timeout 5s prime-run glxgears 2>/dev/null | tail -1 | while read -r line; do
                if echo "$line" | grep -q "frames"; then
                    print_info "NVIDIA GPU (glxgears): $line"
                fi
            done
        fi
        
        gpu_test_pass "Performance benchmarks completed"
    else
        print_info "glxgears not available for performance testing"
    fi
    
    # Memory bandwidth test if available
    if command -v nvidia-smi &>/dev/null; then
        local mem_info=$(nvidia-smi --query-gpu=memory.total,memory.used --format=csv,noheader,nounits)
        if [ -n "$mem_info" ]; then
            print_info "NVIDIA GPU Memory: $mem_info"
        fi
    fi
}

# Run comprehensive GPU validation
run_gpu_validation() {
    print_header
    
    test_amd_gpu
    test_nvidia_gpu
    test_gpu_switching
    test_gpu_power_management
    test_display_output
    test_gpu_performance
    
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}     GPU Test Results Summary   ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Total GPU tests: $GPU_TESTS_TOTAL"
    echo -e "${GREEN}Passed: $GPU_TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $GPU_TESTS_FAILED${NC}"
    echo -e "Log file: $LOG_FILE"
    echo
    
    if [ $GPU_TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All GPU tests passed! GPU functionality is working properly.${NC}"
        log "All GPU tests passed successfully"
        exit 0
    else
        echo -e "${RED}Some GPU tests failed. Check the log for details.${NC}"
        log "GPU tests completed with $GPU_TESTS_FAILED failures"
        exit 1
    fi
}

# Script execution
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --amd          Test AMD GPU only"
        echo "  --nvidia       Test NVIDIA GPU only"
        echo "  --switching    Test GPU switching only"
        echo "  --power        Test power management only"
        echo "  --display      Test display output only"
        echo "  --performance  Test GPU performance only"
        echo "  --all          Run all GPU tests (default)"
        exit 0
        ;;
    --amd)
        print_header
        test_amd_gpu
        ;;
    --nvidia)
        print_header
        test_nvidia_gpu
        ;;
    --switching)
        print_header
        test_gpu_switching
        ;;
    --power)
        print_header
        test_gpu_power_management
        ;;
    --display)
        print_header
        test_display_output
        ;;
    --performance)
        print_header
        test_gpu_performance
        ;;
    --all|*)
        run_gpu_validation
        ;;
esac