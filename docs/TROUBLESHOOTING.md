# Troubleshooting Guide

This guide covers common issues and solutions for the ASUS ROG Zephyrus G14 Arch Linux setup with hybrid GPU configuration.

## Table of Contents

- [Configuration Backup and Restore](#configuration-backup-and-restore)
- [Quick Diagnostics](#quick-diagnostics)
- [Black Screen Issues](#black-screen-issues)
- [GPU Switching Problems](#gpu-switching-problems)
- [Power Management Issues](#power-management-issues)
- [ASUS Hardware Integration Issues](#asus-hardware-integration-issues)
- [Display Configuration Issues](#display-configuration-issues)
- [Performance Issues](#performance-issues)
- [Installation Problems](#installation-problems)
- [System Recovery](#system-recovery)
- [Getting Help](#getting-help)

## Configuration Backup and Restore

The setup script automatically creates backups of your system configuration before making changes. This section covers how to manage and use these backups.

### Backup Management

List available backups:
```bash
./scripts/config-backup.sh list
```

Create a manual backup:
```bash
./scripts/config-backup.sh backup "Manual backup before changes"
```

Restore from backup:
```bash
./scripts/config-backup.sh restore
```

Validate backup integrity:
```bash
./scripts/config-backup.sh validate backup_name
```

Delete old backups:
```bash
./scripts/config-backup.sh delete backup_name
```

### Recovery from Failed Setup

If the setup script fails and your system is not working properly:

1. **Check for automatic backup**: The setup script creates a backup before making changes
   ```bash
   ./scripts/config-backup.sh list
   ```

2. **Restore the pre-setup backup**: Look for a backup with "Pre-setup backup" in the description
   ```bash
   ./scripts/config-backup.sh restore backup_name
   ```

3. **Reboot after restore**: Some changes require a reboot to take effect
   ```bash
   sudo reboot
   ```

### Backup Locations and Structure

- **Backup directory**: `./backups/`
- **Backup format**: Each backup is stored in a timestamped directory
- **Metadata**: Each backup includes metadata.json with file checksums and version info
- **Protected paths**: User data and sensitive files are never backed up

### Manual Configuration Recovery

If backups are not available, you can manually restore configurations:

1. **Remove hybrid GPU configuration**:
   ```bash
   sudo rm -f /etc/X11/xorg.conf.d/10-hybrid.conf
   sudo systemctl restart display-manager
   ```

2. **Disable custom services**:
   ```bash
   sudo systemctl disable nvidia-suspend.service nvidia-resume.service
   sudo systemctl disable power-management.service
   ```

3. **Reset power management**:
   ```bash
   sudo rm -f /etc/tlp.conf /etc/auto-cpufreq.conf
   sudo systemctl disable tlp auto-cpufreq
   ```

## Quick Diagnostics

### Automated Troubleshooting

Run the automated troubleshooting script to identify and fix common issues:

```bash
# Run all diagnostic checks
./scripts/troubleshoot.sh

# Interactive troubleshooting menu
./scripts/troubleshoot.sh --interactive

# Generate detailed system report
./scripts/troubleshoot.sh --report

# Run automated fixes
./scripts/troubleshoot.sh --auto-fix
```

### Manual System Check

```bash
# Check GPU status
gpu-state-manager status

# Check system services
systemctl status asusd supergfxd tlp auto-cpufreq

# Check GPU drivers
lsmod | grep -E "(nvidia|amdgpu|bbswitch)"

# Check power management
tlp-stat -s
```

## Black Screen Issues

### Symptoms
- Black screen after boot
- Display manager fails to start
- No display output on internal screen
- System boots but no graphics

### Common Causes and Solutions

#### 1. Conflicting GPU Drivers

**Problem**: Nouveau driver conflicts with NVIDIA proprietary driver

**Solution**:
```bash
# Check if nouveau is loaded
lsmod | grep nouveau

# If nouveau is loaded, blacklist it
echo "blacklist nouveau" | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf
echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf

# Regenerate initramfs
sudo mkinitcpio -P

# Reboot
sudo reboot
```

#### 2. Incorrect Xorg Configuration

**Problem**: Xorg configuration is missing or incorrect

**Solution**:
```bash
# Check if hybrid configuration exists
ls -la /etc/X11/xorg.conf.d/10-hybrid.conf

# If missing, reinstall configuration
sudo cp configs/xorg/10-hybrid.conf /etc/X11/xorg.conf.d/

# Restart display manager
sudo systemctl restart display-manager
```

#### 3. NVIDIA Driver Not Loaded

**Problem**: NVIDIA driver modules are not loaded

**Solution**:
```bash
# Check NVIDIA modules
lsmod | grep nvidia

# Load NVIDIA modules manually
sudo modprobe nvidia
sudo modprobe nvidia_modeset
sudo modprobe nvidia_drm

# Make permanent by adding to modules-load
echo "nvidia" | sudo tee -a /etc/modules-load.d/nvidia.conf
echo "nvidia_modeset" | sudo tee -a /etc/modules-load.d/nvidia.conf
echo "nvidia_drm" | sudo tee -a /etc/modules-load.d/nvidia.conf
```

#### 4. Wrong GPU Bus IDs

**Problem**: Xorg configuration has incorrect PCI bus IDs

**Solution**:
```bash
# Detect current GPU bus IDs
lspci | grep -E "(VGA|3D)"

# Update Xorg configuration with correct bus IDs
# Edit /etc/X11/xorg.conf.d/10-hybrid.conf and update BusID lines

# Example:
# BusID "PCI:6:0:0"  # AMD GPU
# BusID "PCI:1:0:0"  # NVIDIA GPU
```

### Emergency Recovery

If you have a black screen and can't access the desktop:

1. **Boot to TTY**: Press `Ctrl+Alt+F2` to access a text console
2. **Login**: Use your username and password
3. **Run recovery**:
   ```bash
   # Restore Xorg backup
   sudo cp /etc/X11/xorg.conf.d.backup/xorg.conf.d_* /etc/X11/xorg.conf.d/
   
   # Or remove problematic configuration
   sudo rm /etc/X11/xorg.conf.d/10-hybrid.conf
   
   # Restart display manager
   sudo systemctl restart display-manager
   ```

## GPU Switching Problems

### Symptoms
- `prime-run` command not working
- Applications not using NVIDIA GPU
- GPU switching commands fail
- Poor gaming performance

### Common Causes and Solutions

#### 1. Missing PRIME Render Offload

**Problem**: PRIME render offload not configured properly

**Solution**:
```bash
# Check if prime-run script exists
which prime-run

# If missing, create it
sudo cp scripts/prime-run /usr/local/bin/
sudo chmod +x /usr/local/bin/prime-run

# Test PRIME render offload
prime-run glxinfo | grep "OpenGL renderer"
```

#### 2. bbswitch Module Issues

**Problem**: bbswitch module not loaded or not working

**Solution**:
```bash
# Check bbswitch status
cat /proc/acpi/bbswitch

# If file doesn't exist, load bbswitch
sudo modprobe bbswitch

# Make permanent
echo "bbswitch" | sudo tee -a /etc/modules-load.d/bbswitch.conf

# Test bbswitch control
echo OFF | sudo tee /proc/acpi/bbswitch
echo ON | sudo tee /proc/acpi/bbswitch
```

#### 3. supergfxctl Not Working

**Problem**: supergfxctl service not running or responding

**Solution**:
```bash
# Check supergfxd service
systemctl status supergfxd

# Restart service
sudo systemctl restart supergfxd

# Check supergfxctl functionality
supergfxctl -g  # Get current mode
supergfxctl -m hybrid  # Set hybrid mode
```

#### 4. NVIDIA GPU Not Detected

**Problem**: NVIDIA GPU not visible to applications

**Solution**:
```bash
# Check if NVIDIA GPU is detected
nvidia-smi

# If command fails, check driver installation
pacman -Qs nvidia

# Reinstall NVIDIA drivers if necessary
sudo pacman -S nvidia nvidia-utils
```

## Power Management Issues

### Symptoms
- Poor battery life
- High power consumption
- CPU running at high frequencies on battery
- NVIDIA GPU always powered on

### Common Causes and Solutions

#### 1. TLP Not Running

**Problem**: TLP service is not active

**Solution**:
```bash
# Check TLP status
systemctl status tlp

# Enable and start TLP
sudo systemctl enable --now tlp

# Check TLP configuration
tlp-stat -s
```

#### 2. Conflicting Power Management Services

**Problem**: Multiple power management services running simultaneously

**Solution**:
```bash
# Check for conflicts
systemctl status power-profiles-daemon tlp auto-cpufreq

# Disable conflicting services (keep only one)
sudo systemctl disable power-profiles-daemon
# OR
sudo systemctl disable tlp

# Recommended: Use TLP + auto-cpufreq
sudo systemctl enable --now tlp
sudo systemctl enable --now auto-cpufreq
```

#### 3. NVIDIA GPU Not Powering Down

**Problem**: NVIDIA GPU remains powered on, draining battery

**Solution**:
```bash
# Check NVIDIA power state
cat /proc/acpi/bbswitch

# Manually power off NVIDIA GPU
echo OFF | sudo tee /proc/acpi/bbswitch

# Check udev rules for automatic power management
ls -la /etc/udev/rules.d/*nvidia*

# Install udev rules if missing
sudo cp configs/udev/81-nvidia-switching.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

#### 4. AMD P-State Not Active

**Problem**: AMD P-State EPP not being used for CPU frequency scaling

**Solution**:
```bash
# Check current CPU scaling driver
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver

# If not amd-pstate-epp, add kernel parameter
sudo nano /etc/default/grub
# Add: amd_pstate=active

# Update GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Reboot to apply changes
sudo reboot
```

## ASUS Hardware Integration Issues

### Symptoms
- Keyboard backlight not working
- Fan control not available
- ASUS-specific features not functioning
- ROG Control Center not working

### Common Causes and Solutions

#### 1. asusd Service Not Running

**Problem**: ASUS daemon service is not active

**Solution**:
```bash
# Check asusd status
systemctl status asusd

# Enable and start asusd
sudo systemctl enable --now asusd

# Check asusctl functionality
asusctl --version
asusctl -k 2  # Test keyboard backlight
```

#### 2. Missing ASUS Packages

**Problem**: ASUS-specific packages not installed

**Solution**:
```bash
# Check installed ASUS packages
pacman -Qs asus

# Install missing packages
yay -S asusctl supergfxctl rog-control-center

# Restart services
sudo systemctl restart asusd supergfxd
```

#### 3. Keyboard Backlight Issues

**Problem**: Keyboard backlight control not working

**Solution**:
```bash
# Check keyboard backlight device
ls -la /sys/class/leds/asus::kbd_backlight/

# Test manual control
echo 2 | sudo tee /sys/class/leds/asus::kbd_backlight/brightness

# Use asusctl
asusctl -k 0  # Off
asusctl -k 3  # Maximum
```

#### 4. Fan Control Problems

**Problem**: Fan profiles not working or not available

**Solution**:
```bash
# Check available fan profiles
asusctl profile -l

# Set fan profile
asusctl profile -P quiet
asusctl profile -P balanced
asusctl profile -P performance

# Check fan curve configuration
asusctl fan-curve -l
```

## Display Configuration Issues

### Symptoms
- External displays not working
- Wrong resolution or refresh rate
- Display flickering or artifacts
- Multi-monitor setup problems

### Common Causes and Solutions

#### 1. External Display Not Detected

**Problem**: External monitor not showing up in display settings

**Solution**:
```bash
# Check connected displays
xrandr --listmonitors

# Force display detection
xrandr --auto

# Check if running on NVIDIA GPU for external display
prime-run xrandr --listmonitors

# Configure external display manually
xrandr --output HDMI-1 --mode 1920x1080 --rate 60
```

#### 2. Wrong GPU for External Display

**Problem**: External display connected to wrong GPU

**Solution**:
```bash
# Check which GPU handles external displays
xrandr --listproviders

# Use NVIDIA GPU for external display
prime-run your-application

# Or switch to hybrid mode
supergfxctl -m hybrid
```

#### 3. Display Resolution Issues

**Problem**: Incorrect resolution or refresh rate

**Solution**:
```bash
# List available modes
xrandr

# Set specific resolution and refresh rate
xrandr --output eDP-1 --mode 2560x1600 --rate 165

# Create custom mode if needed
cvt 2560 1600 165
xrandr --newmode "2560x1600_165.00" [output from cvt]
xrandr --addmode eDP-1 "2560x1600_165.00"
```

## Performance Issues

### Symptoms
- Low gaming performance
- High CPU temperatures
- System lag or stuttering
- Applications running slowly

### Common Causes and Solutions

#### 1. Applications Not Using NVIDIA GPU

**Problem**: Games or GPU-intensive applications using integrated graphics

**Solution**:
```bash
# Always use prime-run for GPU-intensive applications
prime-run steam
prime-run blender
prime-run your-game

# Check which GPU is being used
prime-run glxinfo | grep "OpenGL renderer"
```

#### 2. CPU Thermal Throttling

**Problem**: CPU overheating and reducing performance

**Solution**:
```bash
# Check CPU temperatures
sensors

# Monitor thermal throttling
journalctl | grep -i thermal

# Adjust fan curves
asusctl profile -P performance

# Clean laptop vents and fans
# Consider undervolting (advanced users only)
```

#### 3. Wrong Power Profile

**Problem**: System running in power-saving mode while plugged in

**Solution**:
```bash
# Check current power profile
powerprofilesctl get

# Set performance profile when plugged in
powerprofilesctl set performance

# Check CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Set performance governor if needed
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

## Installation Problems

### Symptoms
- Setup script fails
- Package installation errors
- Permission denied errors
- Network connectivity issues

### Common Causes and Solutions

#### 1. Package Installation Failures

**Problem**: Packages fail to install during setup

**Solution**:
```bash
# Update package database
sudo pacman -Sy

# Update keyring
sudo pacman -S archlinux-keyring

# Clear package cache if corrupted
sudo pacman -Scc

# Run setup with verbose output
./setup.sh --verbose
```

#### 2. AUR Package Issues

**Problem**: AUR packages fail to build or install

**Solution**:
```bash
# Install base-devel if missing
sudo pacman -S base-devel

# Install yay AUR helper manually
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

# Clear AUR cache
yay -Scc
```

#### 3. Permission Issues

**Problem**: Permission denied errors during setup

**Solution**:
```bash
# Ensure user has sudo privileges
sudo -v

# Check if user is in wheel group
groups $USER

# Add user to wheel group if needed
sudo usermod -aG wheel $USER

# Logout and login again
```

#### 4. Network Issues

**Problem**: Cannot download packages or access repositories

**Solution**:
```bash
# Test internet connectivity
ping -c 3 archlinux.org

# Check DNS resolution
nslookup archlinux.org

# Update mirrorlist
sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Refresh package database
sudo pacman -Sy
```

## System Recovery

### Boot Issues

If your system won't boot after configuration:

1. **Boot from Arch Linux USB**
2. **Mount your system**:
   ```bash
   mount /dev/sdXY /mnt  # Replace with your root partition
   arch-chroot /mnt
   ```
3. **Remove problematic configurations**:
   ```bash
   rm /etc/X11/xorg.conf.d/10-hybrid.conf
   systemctl disable nvidia-suspend.service
   ```
4. **Regenerate initramfs**:
   ```bash
   mkinitcpio -P
   ```
5. **Reboot**

### Configuration Rollback

To restore previous configurations:

```bash
# Restore Xorg configuration
sudo cp /etc/X11/xorg.conf.d.backup/xorg.conf.d_* /etc/X11/xorg.conf.d/

# Restore TLP configuration
sudo cp /etc/tlp.conf.backup /etc/tlp.conf

# Disable custom services
sudo systemctl disable nvidia-suspend.service
sudo systemctl disable auto-cpufreq.service

# Reboot
sudo reboot
```

## Getting Help

### Log Files to Check

1. **Setup logs**: `./logs/setup_YYYYMMDD_HHMMSS.log`
2. **System logs**: `journalctl -xe`
3. **GPU logs**: `journalctl | grep -E "(nvidia|amdgpu)"`
4. **Service logs**: `journalctl -u asusd -u supergfxd -u tlp`

### Information to Gather

When seeking help, provide:

1. **Hardware information**:
   ```bash
   lscpu
   lspci | grep -E "(VGA|3D)"
   ```

2. **System information**:
   ```bash
   uname -a
   pacman -Q | grep -E "(nvidia|mesa|xorg)"
   ```

3. **Current configuration**:
   ```bash
   cat /etc/X11/xorg.conf.d/10-hybrid.conf
   systemctl status asusd supergfxd tlp
   ```

4. **Error messages**: Copy exact error messages from logs

### Community Resources

- **Arch Linux Forums**: https://bbs.archlinux.org/
- **ASUS Linux Community**: https://asus-linux.org/
- **Reddit**: r/archlinux, r/ASUS
- **GitHub Issues**: Create an issue in this repository

### Professional Support

For complex issues or hardware problems, consider:
- ASUS technical support for hardware issues
- Professional Linux support services
- Local Linux user groups or meetups

Remember to always backup your system before making significant changes, and test configurations in a safe environment when possible.