# ASUS Hardware Integration Guide

This document describes the ASUS-specific hardware integration implemented for the ROG Zephyrus G14 laptop configuration.

## Overview

The ASUS hardware integration provides comprehensive support for:
- **asusctl**: Hardware control for fans, LEDs, keyboard backlight, and battery management
- **supergfxctl**: Advanced GPU management and switching
- **rog-control-center**: GUI application for hardware settings
- **switcheroo-control**: Seamless GPU switching with power management

## Components

### 1. asusctl Configuration

**Purpose**: Controls ASUS-specific hardware features
**Service**: `asusd.service`

**Features**:
- Fan profile management (silent, balanced, performance)
- Keyboard backlight control
- LED configuration
- Battery charge threshold control
- Hardware monitoring

**Configuration File**: `/etc/asus/asusctl.conf`

### 2. supergfxctl Configuration

**Purpose**: Advanced GPU management and power control
**Service**: `supergfxd.service`

**Features**:
- GPU mode switching (integrated, hybrid, discrete, compute)
- dGPU power management
- Thermal management
- Performance optimization

**Configuration File**: `/etc/asus/supergfxctl.conf`

### 3. rog-control-center Configuration

**Purpose**: GUI application for hardware control
**Type**: Desktop application

**Features**:
- Graphical interface for all ASUS hardware settings
- Real-time monitoring
- Profile management
- System information display

**Desktop Entry**: `/usr/share/applications/rog-control-center.desktop`

### 4. switcheroo-control Configuration

**Purpose**: Seamless GPU switching with power awareness
**Service**: `switcheroo-control.service`

**Features**:
- Automatic GPU switching based on power state
- Manual GPU selection
- Power-aware GPU management
- Integration with power profiles

**Helper Script**: `/usr/local/bin/gpu-switch`

## Installation

The ASUS hardware integration is automatically configured when running the main setup script:

```bash
./setup.sh
```

Or you can run the ASUS-specific setup independently:

```bash
sudo /usr/local/bin/setup-asus-tools.sh
```

## Configuration Files

### ASUS Configuration Directory: `/etc/asus/`

- `asusctl.conf` - asusctl hardware control settings
- `supergfxctl.conf` - GPU management configuration

### Systemd Services

- `asusd.service` - ASUS hardware daemon
- `supergfxd.service` - GPU management daemon
- `switcheroo-control.service` - GPU switching service
- `power-profiles-daemon.service` - Power profile management

### Udev Rules

- `/etc/udev/rules.d/82-gpu-power-switch.rules` - Automatic GPU switching
- `/etc/udev/rules.d/83-asus-hardware.rules` - ASUS hardware detection

## Usage

### GPU Switching

Use the helper script for manual GPU switching:

```bash
# Switch to integrated GPU (power saving)
gpu-switch integrated

# Switch to discrete GPU (performance)
gpu-switch discrete

# Enable automatic switching
gpu-switch auto

# Check current status
gpu-switch status
```

### Fan Profile Management

```bash
# List available profiles
asusctl profile -l

# Set fan profile
asusctl profile -P balanced    # or silent, performance
```

### GPU Mode Management

```bash
# Check current GPU mode
supergfxctl -g

# Set GPU mode
supergfxctl -m hybrid    # or integrated, discrete, compute
```

### Power Profile Management

```bash
# Check current power profile
powerprofilesctl get

# Set power profile
powerprofilesctl set balanced    # or power-saver, performance

# List available profiles
powerprofilesctl list
```

## Automatic Features

### Power-Based GPU Switching

The system automatically switches GPUs based on power state:
- **On Battery**: Prefers integrated GPU for power saving
- **On AC Power**: Allows automatic switching based on workload

### Service Management

All ASUS services are automatically:
- Enabled at boot
- Started after installation
- Monitored for proper operation

## Troubleshooting

### Testing ASUS Tools

Run the comprehensive test script:

```bash
sudo /usr/local/bin/test-asus-tools.sh
```

### Service Status

Check service status:

```bash
systemctl status asusd.service
systemctl status supergfxd.service
systemctl status switcheroo-control.service
systemctl status power-profiles-daemon.service
```

### Common Issues

1. **Services not starting**: May require reboot after installation
2. **GPU switching not working**: Check if hardware supports MUX switching
3. **Permission errors**: Ensure user is in `input` group
4. **Hardware not detected**: Verify ASUS hardware compatibility

### Log Files

Check logs for troubleshooting:

```bash
journalctl -u asusd.service
journalctl -u supergfxd.service
journalctl -u switcheroo-control.service
```

## Hardware Requirements

- ASUS ROG laptop with supported hardware
- Hybrid GPU configuration (AMD + NVIDIA recommended)
- UEFI firmware with GPU switching support
- Linux kernel with ASUS platform drivers

## Integration with Power Management

The ASUS hardware integration works seamlessly with:
- TLP power management
- auto-cpufreq CPU scaling
- bbswitch NVIDIA power control
- power-profiles-daemon

## Security Considerations

- Services run with appropriate privileges
- User permissions configured for hardware access
- Configuration files have proper ownership and permissions
- No sensitive information stored in configuration files

## Performance Impact

- Minimal CPU overhead from monitoring services
- GPU switching may cause brief display interruption
- Power savings significant when using integrated GPU
- No impact on system stability or reliability