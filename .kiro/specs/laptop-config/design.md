# Design Document

## Overview

The laptop configuration repository will be structured as a comprehensive setup system for ASUS ROG Zephyrus G14 laptops with hybrid AMD/NVIDIA GPU configurations. The design focuses on creating a modular, maintainable, and user-friendly solution that optimizes for battery life while maintaining high-performance capabilities when needed.

The system will use a combination of automated setup scripts, configuration files, and documentation to transform a fresh Arch Linux installation into an optimized laptop environment.

## Architecture

### Repository Structure
```
zephyrus-g14-arch-igpu-setup/
├── setup.sh                    # Main installation script
├── configs/
│   ├── xorg/
│   │   └── 10-hybrid.conf      # Xorg hybrid GPU configuration
│   ├── udev/
│   │   └── 80-nvidia-off.rules # NVIDIA power management rule
│   ├── modules/
│   │   └── bbswitch.conf       # Kernel module configuration
│   └── systemd/
│       └── nvidia-suspend.service # NVIDIA suspend service
├── scripts/
│   ├── prime-run               # GPU offload helper script
│   ├── post-install.sh         # Post-installation configuration
│   └── troubleshoot.sh         # Diagnostic and troubleshooting script
├── docs/
│   ├── README.md               # Main documentation
│   ├── TROUBLESHOOTING.md      # Common issues and solutions
│   └── CUSTOMIZATION.md        # Customization guide
└── tests/
    └── system-test.sh          # System validation tests
```

### Component Architecture

The system follows a layered architecture:

1. **Hardware Layer**: AMD Radeon 890M (iGPU) + NVIDIA RTX 5070 Ti (dGPU)
2. **Kernel Layer**: Linux kernel with amd-pstate, NVIDIA drivers, bbswitch
3. **Display Server Layer**: Xorg with hybrid GPU configuration
4. **Power Management Layer**: TLP, auto-cpufreq, power-profiles-daemon
5. **ASUS Integration Layer**: asusctl, supergfxctl, rog-control-center
6. **User Interface Layer**: Command-line tools and GUI applications

## Components and Interfaces

### Main Setup Script (setup.sh)
- **Purpose**: Orchestrates the entire installation and configuration process
- **Interface**: Command-line execution with optional parameters
- **Dependencies**: Arch Linux base system, internet connection
- **Outputs**: Fully configured hybrid GPU system

### Configuration Management
- **Xorg Configuration**: Manages display server setup for hybrid GPUs
- **Power Management**: Configures TLP, auto-cpufreq, and power profiles
- **GPU Management**: Sets up NVIDIA offloading and AMD primary display
- **ASUS Tools**: Integrates manufacturer-specific hardware controls

### GPU Switching System
- **Primary Display**: AMD iGPU handles internal display and basic graphics
- **Offload Rendering**: NVIDIA dGPU available via PRIME render offload
- **Power Control**: bbswitch module for NVIDIA GPU power management
- **User Interface**: prime-run script and supergfxctl for GPU selection

### Power Optimization
- **CPU Scaling**: amd-pstate-epp for efficient frequency management
- **Automatic Tuning**: auto-cpufreq for dynamic performance adjustment
- **Hardware Control**: TLP for comprehensive power management
- **Profile Management**: power-profiles-daemon for user-selectable modes

## Data Models

### System Configuration State
```bash
# GPU State
current_gpu="integrated"  # integrated, hybrid, discrete
nvidia_power_state="off"  # on, off, suspended

# Power Profile
power_profile="power-saver"  # power-saver, balanced, performance
cpu_governor="powersave"     # powersave, ondemand, performance

# Display Configuration
primary_display="eDP-1"      # Internal display identifier
external_displays=()         # Array of connected external displays
```

### Package Dependencies
```bash
# Core packages
CORE_PACKAGES=(
    "linux-headers"
    "mesa"
    "vulkan-radeon"
    "xf86-video-amdgpu"
)

# NVIDIA packages
NVIDIA_PACKAGES=(
    "nvidia"
    "nvidia-utils"
    "lib32-nvidia-utils"
    "nvidia-prime"
)

# Power management packages
POWER_PACKAGES=(
    "tlp"
    "auto-cpufreq"
    "powertop"
    "acpi_call"
    "bbswitch"
)

# ASUS-specific packages
ASUS_PACKAGES=(
    "asusctl"
    "supergfxctl"
    "rog-control-center"
    "power-profiles-daemon"
    "switcheroo-control"
)
```

## Error Handling

### Installation Error Recovery
- **Package Installation Failures**: Retry mechanism with fallback to alternative packages
- **Repository Access Issues**: Multiple mirror support and offline package caching
- **Permission Errors**: Clear error messages with suggested solutions
- **Dependency Conflicts**: Automatic conflict resolution with user confirmation

### Runtime Error Management
- **GPU Switching Failures**: Fallback to safe iGPU mode with error logging
- **Display Issues**: Automatic Xorg configuration regeneration
- **Power Management Errors**: Service restart mechanisms and safe defaults
- **Hardware Detection Failures**: Graceful degradation with manual override options

### Logging and Diagnostics
- **Setup Logging**: Comprehensive installation log with timestamps
- **System State Monitoring**: Regular health checks and status reporting
- **Error Reporting**: Structured error messages with troubleshooting hints
- **Debug Mode**: Verbose output option for advanced troubleshooting

## Testing Strategy

### Automated Testing
- **Pre-installation Checks**: Hardware compatibility verification
- **Post-installation Validation**: System functionality tests
- **GPU Switching Tests**: Automated verification of GPU offload functionality
- **Power Management Tests**: Battery life and performance benchmarks

### Manual Testing Procedures
- **Display Functionality**: Internal and external display testing
- **Gaming Performance**: GPU-intensive application testing
- **CUDA Functionality**: Machine learning workload testing
- **Battery Life**: Extended usage testing on battery power

### Continuous Integration
- **Virtual Machine Testing**: Basic functionality testing in VMs
- **Hardware-in-the-Loop**: Testing on actual Zephyrus G14 hardware
- **Regression Testing**: Automated testing of common use cases
- **Documentation Testing**: Verification of setup instructions

### User Acceptance Testing
- **Installation Experience**: User-friendly setup process validation
- **Performance Benchmarks**: Real-world usage scenario testing
- **Troubleshooting Effectiveness**: Common issue resolution testing
- **Documentation Clarity**: User feedback on documentation quality

## Security Considerations

### Privilege Management
- **Sudo Usage**: Minimal privilege escalation with clear justification
- **File Permissions**: Proper ownership and permissions for configuration files
- **Service Security**: Secure configuration of system services
- **User Data Protection**: No modification of user personal data

### Package Integrity
- **GPG Verification**: Package signature verification for ASUS repository
- **Checksum Validation**: File integrity verification during installation
- **Source Verification**: Only trusted package sources and repositories
- **Update Security**: Secure update mechanisms for ongoing maintenance

## Performance Optimization

### Battery Life Optimization
- **CPU Frequency Scaling**: Aggressive power saving on battery
- **GPU Power Gating**: Automatic NVIDIA GPU shutdown when unused
- **Display Brightness**: Automatic brightness adjustment based on power state
- **Background Process Management**: Minimal resource usage during idle

### Performance Mode Optimization
- **CPU Boost**: Maximum performance when plugged in
- **GPU Availability**: Seamless access to high-performance NVIDIA GPU
- **Thermal Management**: Optimal fan curves and thermal throttling
- **Memory Management**: Efficient memory allocation and caching

## Maintenance and Updates

### Automated Maintenance
- **Kernel Updates**: Automatic driver rebuilding after kernel updates
- **Package Updates**: Regular system updates with compatibility checking
- **Configuration Sync**: Automatic configuration file updates
- **Log Rotation**: Automatic cleanup of old log files

### Manual Maintenance
- **Configuration Customization**: User-friendly customization options
- **Performance Tuning**: Advanced tuning options for power users
- **Troubleshooting Tools**: Built-in diagnostic and repair utilities
- **Backup and Restore**: Configuration backup and restore functionality