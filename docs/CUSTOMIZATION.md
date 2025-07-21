# Customization Guide

This guide covers advanced configuration options and customization possibilities for the ASUS ROG Zephyrus G14 Arch Linux setup.

## Table of Contents

- [Configuration Overview](#configuration-overview)
- [Power Management Customization](#power-management-customization)
- [GPU Configuration](#gpu-configuration)
- [Display Settings](#display-settings)
- [ASUS Hardware Customization](#asus-hardware-customization)
- [Performance Tuning](#performance-tuning)
- [Custom Scripts and Automation](#custom-scripts-and-automation)
- [Advanced Xorg Configuration](#advanced-xorg-configuration)
- [Kernel Parameters](#kernel-parameters)
- [Service Configuration](#service-configuration)

## Configuration Overview

The setup creates a modular configuration system that can be customized for different use cases and preferences. All configuration files are located in the `configs/` directory and can be modified before or after installation.

### Configuration Structure

```
configs/
├── xorg/
│   └── 10-hybrid.conf              # Display server configuration
├── udev/
│   └── 81-nvidia-switching.rules   # Hardware event rules
├── modules/
│   └── bbswitch.conf               # Kernel module options
├── systemd/
│   └── nvidia-suspend.service      # System service definitions
├── tlp/
│   └── tlp.conf                    # Power management settings
└── auto-cpufreq/
    └── auto-cpufreq.conf           # CPU frequency scaling
```

### Customization Workflow

1. **Before Installation**: Modify configuration files in `configs/` directory
2. **After Installation**: Edit system configuration files directly
3. **Testing**: Use dry-run mode to preview changes
4. **Backup**: Always backup existing configurations before changes

## Power Management Customization

### TLP Configuration

Edit `configs/tlp/tlp.conf` or `/etc/tlp.conf` for custom power management:

#### Battery Optimization

```bash
# Aggressive battery saving
TLP_DEFAULT_MODE=BAT
TLP_PERSISTENT_DEFAULT=1

# CPU frequency scaling
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# CPU energy performance preference
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# Turbo boost
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# HWP (Hardware P-States)
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=0
```

#### Performance Optimization

```bash
# Performance-focused settings
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=ondemand

# Less aggressive power saving
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_performance

# Keep turbo boost enabled
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=1
```

#### Custom Power Profiles

Create custom power profiles for different scenarios:

```bash
# Gaming profile
cat > /etc/tlp.d/01-gaming.conf << EOF
# Gaming-optimized TLP configuration
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=performance
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=performance
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=1
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=default
EOF

# Development profile
cat > /etc/tlp.d/02-development.conf << EOF
# Development-optimized TLP configuration
CPU_SCALING_GOVERNOR_ON_AC=ondemand
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power
EOF
```

### Auto CPU Frequency Customization

Edit `configs/auto-cpufreq/auto-cpufreq.conf`:

```ini
# Custom auto-cpufreq configuration

[charger]
# Settings when plugged in
governor = performance
scaling_min_freq = 1400000
scaling_max_freq = 5100000
turbo = auto

[battery]
# Settings when on battery
governor = powersave
scaling_min_freq = 400000
scaling_max_freq = 2800000
turbo = never
enable_thresholds = true
start_threshold = 20
stop_threshold = 80
```

### Custom Power Scripts

Create custom power management scripts:

```bash
# Battery optimization script
cat > ~/.local/bin/battery-mode << 'EOF'
#!/bin/bash
# Switch to battery optimization mode

# Set CPU governor
echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Power off NVIDIA GPU
echo OFF | sudo tee /proc/acpi/bbswitch

# Set power profile
powerprofilesctl set power-saver

# Reduce screen brightness
brightnessctl set 30%

echo "Battery optimization mode activated"
EOF

chmod +x ~/.local/bin/battery-mode
```

## GPU Configuration

### Custom GPU Switching Scripts

Create advanced GPU switching functionality:

```bash
# Intelligent GPU switcher
cat > ~/.local/bin/smart-gpu << 'EOF'
#!/bin/bash
# Smart GPU switching based on power source and application

check_power_source() {
    if [ -f /sys/class/power_supply/ADP1/online ]; then
        cat /sys/class/power_supply/ADP1/online
    else
        echo "0"
    fi
}

is_gaming_app() {
    local app="$1"
    local gaming_apps=("steam" "lutris" "wine" "blender" "obs")
    
    for game_app in "${gaming_apps[@]}"; do
        if [[ "$app" == *"$game_app"* ]]; then
            return 0
        fi
    done
    return 1
}

main() {
    local app="$1"
    local power_source=$(check_power_source)
    
    if [[ $power_source == "1" ]] || is_gaming_app "$app"; then
        # Use NVIDIA GPU when plugged in or for gaming apps
        echo "Using NVIDIA GPU for: $app"
        prime-run "$@"
    else
        # Use integrated GPU for battery saving
        echo "Using integrated GPU for: $app"
        "$@"
    fi
}

main "$@"
EOF

chmod +x ~/.local/bin/smart-gpu
```

### NVIDIA GPU Power Management

Customize NVIDIA GPU power behavior:

```bash
# Custom bbswitch control script
cat > ~/.local/bin/nvidia-power-manager << 'EOF'
#!/bin/bash
# Advanced NVIDIA power management

BBSWITCH_PATH="/proc/acpi/bbswitch"
LOG_FILE="/var/log/nvidia-power.log"

log() {
    echo "[$(date)] $1" | tee -a "$LOG_FILE"
}

get_nvidia_state() {
    if [ -f "$BBSWITCH_PATH" ]; then
        awk '{print $2}' "$BBSWITCH_PATH"
    else
        echo "UNKNOWN"
    fi
}

power_on_nvidia() {
    local current_state=$(get_nvidia_state)
    if [ "$current_state" = "OFF" ]; then
        echo ON | sudo tee "$BBSWITCH_PATH" > /dev/null
        log "NVIDIA GPU powered ON"
    fi
}

power_off_nvidia() {
    local current_state=$(get_nvidia_state)
    if [ "$current_state" = "ON" ]; then
        # Kill any processes using NVIDIA GPU
        sudo pkill -f nvidia-smi
        echo OFF | sudo tee "$BBSWITCH_PATH" > /dev/null
        log "NVIDIA GPU powered OFF"
    fi
}

auto_manage() {
    local power_source=$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo "0")
    local nvidia_processes=$(pgrep -f "prime-run\|nvidia-smi" | wc -l)
    
    if [ "$power_source" = "0" ] && [ "$nvidia_processes" = "0" ]; then
        power_off_nvidia
    elif [ "$nvidia_processes" -gt "0" ]; then
        power_on_nvidia
    fi
}

case "$1" in
    on) power_on_nvidia ;;
    off) power_off_nvidia ;;
    auto) auto_manage ;;
    status) echo "NVIDIA GPU: $(get_nvidia_state)" ;;
    *) echo "Usage: $0 {on|off|auto|status}" ;;
esac
EOF

chmod +x ~/.local/bin/nvidia-power-manager
```

## Display Settings

### Custom Xorg Configuration

Modify `configs/xorg/10-hybrid.conf` for specific display needs:

#### High Refresh Rate Configuration

```xorg
# High refresh rate internal display
Section "Monitor"
    Identifier "eDP-1"
    Option "PreferredMode" "2560x1600_165"
    Option "DPMS" "true"
EndSection

Section "Screen"
    Identifier "AMD"
    Device "AMD"
    Monitor "eDP-1"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "2560x1600_165" "2560x1600_120" "1920x1200_165"
    EndSubSection
EndSection
```

#### Multi-Monitor Setup

```xorg
# External monitor configuration
Section "Monitor"
    Identifier "HDMI-1"
    Option "PreferredMode" "3840x2160_60"
    Option "Position" "2560 0"
    Option "DPMS" "true"
EndSection

Section "Screen"
    Identifier "NVIDIA"
    Device "NVIDIA"
    Monitor "HDMI-1"
    DefaultDepth 24
EndSection
```

### Display Automation Scripts

```bash
# Automatic display configuration
cat > ~/.local/bin/display-manager << 'EOF'
#!/bin/bash
# Automatic display configuration based on connected monitors

detect_monitors() {
    xrandr --query | grep " connected" | cut -d" " -f1
}

configure_single_monitor() {
    xrandr --output eDP-1 --primary --mode 2560x1600 --rate 165
}

configure_dual_monitor() {
    local external_monitor="$1"
    xrandr --output eDP-1 --primary --mode 2560x1600 --rate 165 \
           --output "$external_monitor" --mode 3840x2160 --rate 60 --right-of eDP-1
}

main() {
    local monitors=($(detect_monitors))
    local monitor_count=${#monitors[@]}
    
    case $monitor_count in
        1)
            configure_single_monitor
            ;;
        2)
            local external="${monitors[1]}"
            configure_dual_monitor "$external"
            ;;
        *)
            echo "Unsupported monitor configuration"
            ;;
    esac
}

main "$@"
EOF

chmod +x ~/.local/bin/display-manager
```

## ASUS Hardware Customization

### Custom Fan Curves

Create custom fan curves for different scenarios:

```bash
# Gaming fan curve
asusctl fan-curve -m performance -f cpu -D 30c:10%,40c:20%,50c:35%,60c:55%,70c:65%,80c:75%,90c:85%,100c:95%
asusctl fan-curve -m performance -f gpu -D 30c:10%,40c:20%,50c:35%,60c:55%,70c:65%,80c:75%,90c:85%,100c:95%

# Silent fan curve
asusctl fan-curve -m quiet -f cpu -D 30c:0%,40c:5%,50c:10%,60c:20%,70c:35%,80c:55%,90c:75%,100c:85%
asusctl fan-curve -m quiet -f gpu -D 30c:0%,40c:5%,50c:10%,60c:20%,70c:35%,80c:55%,90c:75%,100c:85%
```

### Keyboard Backlight Automation

```bash
# Automatic keyboard backlight based on ambient light
cat > ~/.local/bin/kbd-backlight-auto << 'EOF'
#!/bin/bash
# Automatic keyboard backlight control

get_ambient_light() {
    # This would need an ambient light sensor
    # For now, use time-based logic
    local hour=$(date +%H)
    if [ "$hour" -ge 18 ] || [ "$hour" -le 6 ]; then
        echo "dark"
    else
        echo "bright"
    fi
}

set_keyboard_backlight() {
    local ambient=$(get_ambient_light)
    local power_source=$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo "0")
    
    if [ "$ambient" = "dark" ]; then
        if [ "$power_source" = "1" ]; then
            asusctl -k 3  # Bright when plugged in
        else
            asusctl -k 1  # Dim on battery
        fi
    else
        asusctl -k 0  # Off during day
    fi
}

set_keyboard_backlight
EOF

chmod +x ~/.local/bin/kbd-backlight-auto

# Add to crontab for automatic execution
(crontab -l 2>/dev/null; echo "*/30 * * * * ~/.local/bin/kbd-backlight-auto") | crontab -
```

### Custom Power Profiles

```bash
# Create custom ASUS power profiles
cat > ~/.local/bin/asus-profile-manager << 'EOF'
#!/bin/bash
# Custom ASUS power profile manager

set_gaming_profile() {
    asusctl profile -P performance
    asusctl -k 3  # Full keyboard backlight
    # Custom fan curves would be applied here
    echo "Gaming profile activated"
}

set_work_profile() {
    asusctl profile -P balanced
    asusctl -k 1  # Low keyboard backlight
    echo "Work profile activated"
}

set_battery_profile() {
    asusctl profile -P quiet
    asusctl -k 0  # Keyboard backlight off
    echo "Battery profile activated"
}

case "$1" in
    gaming) set_gaming_profile ;;
    work) set_work_profile ;;
    battery) set_battery_profile ;;
    *) echo "Usage: $0 {gaming|work|battery}" ;;
esac
EOF

chmod +x ~/.local/bin/asus-profile-manager
```

## Performance Tuning

### CPU Optimization

```bash
# Custom CPU performance tuning
cat > /etc/systemd/system/cpu-performance.service << 'EOF'
[Unit]
Description=CPU Performance Optimization
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
ExecStart=/bin/bash -c 'echo 0 | tee /sys/devices/system/cpu/cpufreq/boost'

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
sudo systemctl enable cpu-performance.service
```

### Memory Optimization

```bash
# Custom memory management
cat > /etc/sysctl.d/99-memory-optimization.conf << 'EOF'
# Memory optimization for gaming laptop
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=15
vm.dirty_background_ratio=5
EOF
```

### I/O Optimization

```bash
# I/O scheduler optimization
cat > /etc/udev/rules.d/60-ioschedulers.rules << 'EOF'
# Set I/O scheduler for different device types
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF
```

## Custom Scripts and Automation

### System State Monitor

```bash
# Comprehensive system monitoring script
cat > ~/.local/bin/system-monitor << 'EOF'
#!/bin/bash
# System state monitoring and automatic adjustments

LOG_FILE="$HOME/.local/share/system-monitor.log"

log() {
    echo "[$(date)] $1" | tee -a "$LOG_FILE"
}

check_thermal_state() {
    local cpu_temp=$(sensors | grep 'Tctl:' | awk '{print $2}' | sed 's/+//;s/°C//')
    if [ "${cpu_temp%.*}" -gt 80 ]; then
        log "High CPU temperature detected: ${cpu_temp}°C"
        asusctl profile -P quiet
        return 1
    fi
    return 0
}

check_power_state() {
    local power_source=$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo "0")
    local battery_level=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "100")
    
    if [ "$power_source" = "0" ] && [ "$battery_level" -lt 20 ]; then
        log "Low battery detected: ${battery_level}%"
        nvidia-power-manager off
        asusctl profile -P quiet
        asusctl -k 0
    fi
}

check_gpu_usage() {
    local nvidia_processes=$(pgrep -f prime-run | wc -l)
    local power_source=$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo "0")
    
    if [ "$nvidia_processes" = "0" ] && [ "$power_source" = "0" ]; then
        nvidia-power-manager off
    fi
}

main() {
    check_thermal_state
    check_power_state
    check_gpu_usage
}

main "$@"
EOF

chmod +x ~/.local/bin/system-monitor

# Add to systemd user service
cat > ~/.config/systemd/user/system-monitor.service << 'EOF'
[Unit]
Description=System State Monitor
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/system-monitor

[Install]
WantedBy=default.target
EOF

cat > ~/.config/systemd/user/system-monitor.timer << 'EOF'
[Unit]
Description=Run System Monitor every 5 minutes
Requires=system-monitor.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user enable --now system-monitor.timer
```

### Application Launcher with GPU Detection

```bash
# Smart application launcher
cat > ~/.local/bin/smart-launch << 'EOF'
#!/bin/bash
# Intelligent application launcher with GPU detection

GAMING_APPS=("steam" "lutris" "wine" "blender" "obs" "davinci-resolve")
DEVELOPMENT_APPS=("code" "pycharm" "android-studio" "unity")

is_gaming_app() {
    local app="$1"
    for gaming_app in "${GAMING_APPS[@]}"; do
        if [[ "$app" == *"$gaming_app"* ]]; then
            return 0
        fi
    done
    return 1
}

is_development_app() {
    local app="$1"
    for dev_app in "${DEVELOPMENT_APPS[@]}"; do
        if [[ "$app" == *"$dev_app"* ]]; then
            return 0
        fi
    done
    return 1
}

launch_app() {
    local app="$1"
    shift
    local args="$@"
    
    if is_gaming_app "$app"; then
        echo "Launching gaming application with NVIDIA GPU: $app"
        asusctl profile -P performance
        prime-run "$app" $args
    elif is_development_app "$app"; then
        echo "Launching development application: $app"
        asusctl profile -P balanced
        "$app" $args
    else
        echo "Launching standard application: $app"
        "$app" $args
    fi
}

launch_app "$@"
EOF

chmod +x ~/.local/bin/smart-launch
```

## Advanced Xorg Configuration

### Custom Device Sections

```xorg
# Advanced AMD GPU configuration
Section "Device"
    Identifier "AMD"
    Driver "amdgpu"
    BusID "PCI:6:0:0"
    Option "TearFree" "true"
    Option "DRI" "3"
    Option "VariableRefresh" "true"
    Option "AsyncFlipSecondaries" "true"
EndSection

# Advanced NVIDIA GPU configuration
Section "Device"
    Identifier "NVIDIA"
    Driver "nvidia"
    BusID "PCI:1:0:0"
    Option "AllowEmptyInitialConfiguration" "true"
    Option "PrimaryGPU" "false"
    Option "ProbeAllGpus" "false"
EndSection
```

### Custom Screen Sections

```xorg
# High-performance screen configuration
Section "Screen"
    Identifier "AMD"
    Device "AMD"
    Monitor "eDP-1"
    DefaultDepth 24
    Option "metamodes" "2560x1600_165 +0+0"
    Option "AllowIndirectGLXProtocol" "off"
    Option "TripleBuffer" "on"
    SubSection "Display"
        Depth 24
        Modes "2560x1600_165" "2560x1600_120" "1920x1200_165"
    EndSubSection
EndSection
```

## Kernel Parameters

### Custom Kernel Parameters

Add to `/etc/default/grub`:

```bash
# Performance-oriented kernel parameters
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_pstate=active amd_iommu=on iommu=pt nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"

# Power-saving oriented kernel parameters
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_pstate=active pcie_aspm=force nvidia.NVreg_DynamicPowerManagement=0x02"

# Gaming-oriented kernel parameters
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_pstate=active preempt=full nvidia-drm.modeset=1 nvidia.NVreg_EnableGpuFirmware=0"
```

### Custom Kernel Modules

```bash
# Custom module loading configuration
cat > /etc/modules-load.d/custom.conf << 'EOF'
# Custom kernel modules
nvidia
nvidia_modeset
nvidia_drm
amdgpu
bbswitch
EOF

# Custom module options
cat > /etc/modprobe.d/custom.conf << 'EOF'
# Custom module options
options nvidia NVreg_DynamicPowerManagement=0x02
options nvidia_drm modeset=1
options amdgpu si_support=1 cik_support=1
options bbswitch load_state=0 unload_state=1
EOF
```

## Service Configuration

### Custom systemd Services

```bash
# GPU state management service
cat > /etc/systemd/system/gpu-state-manager.service << 'EOF'
[Unit]
Description=GPU State Management Service
After=multi-user.target

[Service]
Type=forking
ExecStart=/usr/local/bin/gpu-state-manager daemon
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
EOF

# Power optimization service
cat > /etc/systemd/system/power-optimizer.service << 'EOF'
[Unit]
Description=Power Optimization Service
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/power-optimizer start
ExecStop=/usr/local/bin/power-optimizer stop

[Install]
WantedBy=multi-user.target
EOF
```

### Custom udev Rules

```bash
# Advanced GPU switching rules
cat > /etc/udev/rules.d/90-gpu-switching.rules << 'EOF'
# Automatic GPU power management
SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", ATTR{power/control}="auto"
SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", ATTR{power/control}="auto"

# USB power management
SUBSYSTEM=="usb", ATTR{power/control}="auto"
SUBSYSTEM=="usb", TEST=="power/autosuspend" ATTR{power/autosuspend}="2"

# PCI power management
SUBSYSTEM=="pci", ATTR{power/control}="auto"
EOF
```

This customization guide provides extensive options for tailoring the system to specific needs and preferences. Users can mix and match these configurations based on their use cases, whether focused on battery life, performance, or specific workflows.