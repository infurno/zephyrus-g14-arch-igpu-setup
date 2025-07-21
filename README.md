# ASUS ROG Zephyrus G14 Arch Linux Setup

Comprehensive setup repository for ASUS ROG Zephyrus G14 laptops with hybrid GPU configuration (AMD iGPU + NVIDIA dGPU) on Arch Linux. This project optimizes your laptop for maximum battery life using the AMD integrated GPU while maintaining seamless access to the NVIDIA discrete GPU for gaming and CUDA workloads.

## Table of Contents

- [Features](#features)
- [Hardware Compatibility](#hardware-compatibility)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)
- [Contributing](#contributing)
- [License](#license)

## Features

### Core Functionality
- **Hybrid GPU Configuration**: AMD iGPU as primary display driver with NVIDIA dGPU for offload rendering
- **Power Management**: Optimized for maximum battery life with automatic GPU power gating
- **ASUS Hardware Integration**: Full support for ASUS-specific hardware controls and features
- **Seamless GPU Switching**: Easy switching between integrated and discrete graphics
- **Display Management**: Proper handling of internal and external displays

### Power Optimization
- **AMD P-State EPP**: Advanced CPU frequency scaling for AMD processors
- **TLP Configuration**: Laptop-optimized power management settings
- **Auto CPU Frequency**: Dynamic CPU frequency adjustment based on workload
- **NVIDIA Power Control**: Automatic NVIDIA GPU power management via bbswitch
- **Battery Life Focus**: Aggressive power saving when running on battery

### ASUS-Specific Features
- **asusctl Integration**: Hardware control for keyboard backlight, fan curves, and power profiles
- **supergfxctl Support**: Advanced GPU management and switching
- **ROG Control Center**: GUI application for hardware settings
- **Power Profiles**: Multiple performance modes (power-saver, balanced, performance)

## Hardware Compatibility

### Primary Target
- **ASUS ROG Zephyrus G14 (GA403WR)** with AMD Ryzen 9 8945HS and NVIDIA RTX 5070 Ti Laptop GPU

### Supported Configurations
- AMD Ryzen 7000/8000 series processors
- AMD Radeon 700M/800M series integrated graphics
- NVIDIA RTX 4000/5000 series laptop GPUs
- Hybrid GPU configurations with AMD iGPU + NVIDIA dGPU

### Compatibility Notes
- Script is optimized for the specific hardware combination but may work with similar configurations
- Some features may not be available on different hardware variants
- Check hardware compatibility before installation

## Prerequisites

### System Requirements
- **Operating System**: Fresh Arch Linux installation
- **Internet Connection**: Required for package downloads
- **User Privileges**: Regular user account with sudo access
- **Hardware**: ASUS ROG Zephyrus G14 or compatible laptop

### Pre-Installation Checklist
1. Complete a fresh Arch Linux installation
2. Ensure system is up to date: `sudo pacman -Syu`
3. Verify internet connectivity
4. Confirm sudo privileges: `sudo -v`
5. Backup any existing configurations

## Installation

### Quick Installation

```bash
# Clone the repository
git clone https://github.com/infurno/zephyrus-g14-arch-igpu-setup.git
cd zephyrus-g14-arch-igpu-setup

# Make the setup script executable
chmod +x setup.sh

# Run the interactive setup
./setup.sh
```

### Installation Options

```bash
# Interactive setup with prompts
./setup.sh

# Verbose output for debugging
./setup.sh --verbose

# Preview changes without applying them
./setup.sh --dry-run

# Automated setup (skip confirmations)
./setup.sh --force

# Skip automatic backup creation
./setup.sh --no-backup

# Custom log directory
./setup.sh --log-dir /path/to/logs

# Show help and all options
./setup.sh --help
```

### Configuration Backup System

The setup script automatically creates a backup of your current system configuration before making any changes. This provides a safety net in case something goes wrong during setup.

**Backup Features:**
- Automatic pre-setup backup creation
- Configuration versioning and migration support
- User data protection (never backs up personal files)
- Integrity validation with checksums
- Easy restore functionality

**Managing Backups:**
```bash
# List available backups
./scripts/config-backup.sh list

# Create manual backup
./scripts/config-backup.sh backup "Description of backup"

# Restore from backup
./scripts/config-backup.sh restore

# Validate backup integrity
./scripts/config-backup.sh validate backup_name

# Delete old backups
./scripts/config-backup.sh delete backup_name
```

**Recovery from Failed Setup:**
If the setup fails, you can restore your system to its previous state:
```bash
# List backups to find the pre-setup backup
./scripts/config-backup.sh list

# Restore the pre-setup backup
./scripts/config-backup.sh restore backup_name

# Reboot to apply changes
sudo reboot
```

### Post-Installation

After the main setup completes, run the post-installation script:

```bash
# Run post-installation configuration
sudo ./scripts/post-install.sh

# Or run specific post-installation tasks
sudo ./scripts/post-install.sh validate    # System validation only
sudo ./scripts/post-install.sh setup-user  # User environment setup only
```

## Usage

### Basic GPU Operations

```bash
# Check GPU status
gpu-state-manager status

# Run application with NVIDIA GPU
prime-run <application>

# Control NVIDIA GPU power
bbswitch-control on   # Power on NVIDIA GPU
bbswitch-control off  # Power off NVIDIA GPU

# Check current power source and GPU state
gpu-info
```

### Power Management

```bash
# Check power management status
tlp-stat

# Monitor CPU frequency scaling
watch -n 1 'cat /proc/cpuinfo | grep MHz'

# Check current power profile
powerprofilesctl get

# Set power profile
powerprofilesctl set power-saver    # Battery optimization
powerprofilesctl set balanced       # Balanced performance
powerprofilesctl set performance    # Maximum performance
```

### ASUS Hardware Control

```bash
# Check ASUS hardware status
asusctl --version

# Control keyboard backlight
asusctl -k 0    # Off
asusctl -k 1    # Low
asusctl -k 2    # Medium  
asusctl -k 3    # High

# Check fan profiles
asusctl profile -l

# Set fan profile
asusctl profile -P quiet      # Quiet mode
asusctl profile -P balanced   # Balanced mode
asusctl profile -P performance # Performance mode
```

### System Monitoring

```bash
# Run comprehensive system test
./scripts/system-test.sh

# Run troubleshooting diagnostics
./scripts/troubleshoot.sh

# Generate system report
./scripts/troubleshoot.sh --report

# Interactive troubleshooting menu
./scripts/troubleshoot.sh --interactive
```

## Configuration

### Repository Structure

```
zephyrus-g14-arch-igpu-setup/
├── setup.sh                           # Main installation script
├── setup.bat                          # Windows wrapper (informational)
├── configs/                           # Configuration files
│   ├── xorg/
│   │   └── 10-hybrid.conf            # Xorg hybrid GPU configuration
│   ├── udev/
│   │   └── 81-nvidia-switching.rules # NVIDIA power management rules
│   ├── modules/
│   │   └── bbswitch.conf             # Kernel module configuration
│   ├── systemd/
│   │   └── nvidia-suspend.service    # NVIDIA suspend/resume service
│   ├── tlp/
│   │   └── tlp.conf                  # TLP power management configuration
│   └── auto-cpufreq/
│       └── auto-cpufreq.conf         # CPU frequency scaling configuration
├── scripts/                          # Helper scripts and utilities
│   ├── prime-run                     # NVIDIA GPU offload script
│   ├── gpu-state-manager             # GPU state management utility
│   ├── bbswitch-control              # NVIDIA power control script
│   ├── post-install.sh               # Post-installation configuration
│   ├── troubleshoot.sh               # Diagnostic and troubleshooting script
│   ├── system-test.sh                # System validation tests
│   └── setup-*.sh                    # Component-specific setup scripts
├── docs/                             # Documentation and guides
│   ├── TROUBLESHOOTING.md            # Troubleshooting guide
│   ├── CUSTOMIZATION.md              # Customization guide
│   └── ASUS_HARDWARE_INTEGRATION.md  # ASUS hardware documentation
└── tests/                            # System validation and testing scripts
```

### Key Configuration Files

- **Xorg Configuration**: `/etc/X11/xorg.conf.d/10-hybrid.conf` - Hybrid GPU display configuration
- **TLP Configuration**: `/etc/tlp.conf` - Power management settings
- **Auto CPU Frequency**: `/etc/auto-cpufreq.conf` - CPU frequency scaling
- **NVIDIA Suspend Service**: `/etc/systemd/system/nvidia-suspend.service` - GPU suspend/resume handling
- **udev Rules**: `/etc/udev/rules.d/81-nvidia-switching.rules` - Automatic GPU power management

## Troubleshooting

### Quick Diagnostics

```bash
# Run automatic troubleshooting
./scripts/troubleshoot.sh

# Interactive troubleshooting menu
./scripts/troubleshoot.sh --interactive

# Generate detailed system report
./scripts/troubleshoot.sh --report
```

### Common Issues

For detailed troubleshooting information, see [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

**Quick fixes for common problems:**

1. **Black screen after boot**: Check Xorg configuration and restart display manager
2. **NVIDIA GPU not working**: Verify drivers are loaded and run `prime-run glxinfo`
3. **Poor battery life**: Check power management services and GPU power state
4. **External displays not working**: Verify display configuration and GPU switching

### Log Files

- **Setup logs**: `./logs/setup_YYYYMMDD_HHMMSS.log`
- **System logs**: `journalctl -u asusd -u supergfxd -u tlp`
- **Troubleshooting logs**: `/tmp/troubleshoot-YYYYMMDD-HHMMSS.log`

## Advanced Usage

### Custom Configuration

For advanced configuration options, see [CUSTOMIZATION.md](docs/CUSTOMIZATION.md).

### Manual GPU Switching

```bash
# Switch to integrated graphics only
supergfxctl -m integrated

# Switch to hybrid mode (default)
supergfxctl -m hybrid

# Switch to discrete graphics only (not recommended for battery life)
supergfxctl -m discrete
```

### Performance Tuning

```bash
# Monitor GPU usage
watch -n 1 nvidia-smi

# Check CPU performance
cpupower frequency-info

# Monitor power consumption
powertop
```

## Contributing

Contributions are welcome! Please read the contributing guidelines and submit pull requests for any improvements.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/username/zephyrus-g14-arch-igpu-setup.git
cd zephyrus-g14-arch-igpu-setup

# Test changes in dry-run mode
./setup.sh --dry-run --verbose
```

## License

This project is provided as-is for educational and personal use. See the LICENSE file for details.

## Acknowledgments

- ASUS Linux community for hardware support tools
- Arch Linux community for comprehensive documentation
- Contributors to TLP, auto-cpufreq, and other power management tools