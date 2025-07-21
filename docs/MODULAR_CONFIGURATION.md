# Modular Configuration System

The Zephyrus G14 setup includes a comprehensive modular configuration system that automatically detects your hardware, applies appropriate configurations, and allows for extensive customization.

## Overview

The modular configuration system provides:

- **Hardware Detection**: Automatic detection of your specific laptop model and components
- **Template Processing**: Dynamic configuration generation based on your hardware and preferences
- **Hardware Variants**: Optimized configurations for different G14 models and GPU combinations
- **User Preferences**: Customizable settings for power management, graphics, and other features
- **Configuration Validation**: Comprehensive validation of all configuration files
- **Consistency Checking**: Ensures all configurations work together properly

## Directory Structure

```
configs/
├── templates/           # Configuration templates with variable substitution
│   ├── xorg/
│   │   └── 10-hybrid.conf.template
│   └── tlp/
│       └── tlp.conf.template
├── variants/           # Hardware-specific configurations
│   ├── ga403wr-2025/   # RTX 5070 Ti variant (2025)
│   ├── ga403uv/        # RTX 4060 variant (2024)
│   └── generic/        # Fallback configuration
└── [component dirs]/   # Standard configuration directories
    ├── xorg/
    ├── tlp/
    ├── udev/
    └── systemd/
```

## Hardware Detection

The system automatically detects:

- **Laptop Model**: Specific G14 variant (GA403WR, GA403UV, etc.)
- **CPU**: AMD Ryzen processor model and capabilities
- **GPUs**: AMD iGPU and NVIDIA dGPU models and bus IDs
- **Display**: Internal display specifications and capabilities
- **Battery**: Battery capacity and charging features
- **Connectivity**: WiFi, Bluetooth, and port configurations

### Running Hardware Detection

```bash
# Detect and cache hardware information
./scripts/config-manager.sh detect-hardware

# View detected hardware
./scripts/config-manager.sh show-hardware
```

## User Preferences

User preferences allow you to customize the setup behavior without modifying configuration files directly.

### Initializing Preferences

```bash
# Create default preferences file
./scripts/config-manager.sh init-preferences

# View current preferences
./scripts/config-manager.sh show-preferences
```

### Preference Categories

#### Power Management
- `default_power_profile`: power-saver, balanced, performance
- `battery_power_saving`: Enable aggressive power saving on battery
- `cpu_governor_preference`: CPU governor preference

#### Graphics
- `primary_gpu_mode`: integrated, hybrid, discrete
- `nvidia_power_management`: Enable NVIDIA GPU power management
- `prime_offload_default`: Enable PRIME render offload by default

#### Display
- `external_display_support`: Enable external display support
- `display_scaling`: Preferred display scaling factor
- `night_light`: Enable blue light filter

#### ASUS Hardware
- `enable_asusctl`: Enable ASUS hardware controls
- `enable_rog_control`: Enable ROG Control Center
- `fan_profile`: silent, balanced, performance

#### Advanced
- `experimental_features`: Enable experimental features
- `custom_kernel_params`: Additional kernel parameters
- `additional_packages`: Extra packages to install

### Editing Preferences

Edit the preferences file directly:

```bash
# Edit preferences file
nano ~/.config/zephyrus-g14/preferences.conf
```

Example preferences file:
```ini
[power]
default_power_profile=balanced
battery_power_saving=true
cpu_governor_preference=schedutil

[graphics]
primary_gpu_mode=hybrid
nvidia_power_management=true
prime_offload_default=true

[display]
external_display_support=true
display_scaling=1.0
night_light=false

[asus]
enable_asusctl=true
enable_rog_control=true
fan_profile=balanced
```

## Hardware Variants

The system supports multiple hardware variants with optimized configurations:

### Supported Variants

#### GA403WR-2025 (RTX 5070 Ti)
- **CPU**: AMD Ryzen 9 8945HS
- **iGPU**: AMD Radeon 890M
- **dGPU**: NVIDIA GeForce RTX 5070 Ti Laptop GPU
- **Display**: 14" 2560x1600 OLED 120Hz
- **Battery**: 90Wh
- **Optimizations**: High-performance settings, aggressive GPU power management

#### GA403UV (RTX 4060)
- **CPU**: AMD Ryzen 9 8945HS
- **iGPU**: AMD Radeon 890M
- **dGPU**: NVIDIA GeForce RTX 4060 Laptop GPU
- **Display**: 14" 2560x1600 OLED 120Hz
- **Battery**: 76Wh
- **Optimizations**: Balanced performance and efficiency

#### Generic Fallback
- **Purpose**: Safe configuration for unrecognized models
- **Features**: Conservative settings, broad compatibility
- **Usage**: Automatic fallback when specific variant not detected

### Variant-Specific Files

Each variant can include:
- `variant.conf`: Hardware specifications and capabilities
- `xorg/`: Display server configurations
- `tlp/`: Power management settings
- `systemd/`: System service configurations
- `udev/`: Hardware rules and power management

## Configuration Templates

Templates allow dynamic configuration generation based on detected hardware and user preferences.

### Template Variables

Templates support variable substitution using environment variables:

#### Hardware Variables
- `${laptop_model}`: Detected laptop model
- `${cpu_model}`: CPU model string
- `${amd_gpu}`: AMD GPU description
- `${nvidia_gpu}`: NVIDIA GPU description
- `${amd_gpu_busid}`: AMD GPU PCI bus ID
- `${nvidia_gpu_busid}`: NVIDIA GPU PCI bus ID

#### Preference Variables
- `${default_power_profile}`: User's preferred power profile
- `${primary_gpu_mode}`: Primary GPU mode setting
- `${cpu_governor_preference}`: Preferred CPU governor
- `${battery_power_saving}`: Battery power saving preference

### Creating Templates

1. Create a `.template` file in the appropriate `configs/templates/` subdirectory
2. Use `${VARIABLE_NAME}` syntax for variable substitution
3. Include conditional logic using bash parameter expansion:
   - `${variable:-default}`: Use default if variable is empty
   - `${variable:+value}`: Use value if variable is set

Example template:
```bash
# GPU Configuration for ${laptop_model}
# Primary GPU Mode: ${primary_gpu_mode}

Section "Device"
    Identifier "amd"
    Driver "amdgpu"
    BusID "${amd_gpu_busid:-PCI:5:0:0}"
    Option "TearFree" "${tearfree_enabled:-true}"
EndSection
```

## Configuration Generation

Generate configurations based on your hardware and preferences:

```bash
# Generate all configurations
./scripts/config-manager.sh generate

# Force regeneration of existing files
./scripts/config-manager.sh generate --force
```

The generation process:
1. Detects hardware if not already cached
2. Initializes user preferences if needed
3. Determines hardware variant
4. Applies variant-specific configurations
5. Processes templates with variable substitution
6. Validates generated configurations

## Configuration Validation

The system includes comprehensive validation to ensure configurations are correct and consistent.

### Running Validation

```bash
# Validate all configurations
./scripts/validate-config.sh
```

### Validation Checks

#### Hardware Compatibility
- Verifies required hardware is present
- Checks for supported kernel modules
- Validates ASUS hardware detection

#### Configuration Syntax
- **Xorg**: Validates X11 configuration syntax
- **TLP**: Checks power management settings
- **Systemd**: Validates service file syntax
- **Udev**: Checks rule file format

#### Consistency Checks
- Ensures no conflicting GPU configurations
- Validates power management tool compatibility
- Checks for missing required configurations

#### User Preferences
- Validates preference values are within acceptable ranges
- Checks for invalid configuration combinations

### Validation Output

The validation system provides:
- **Detailed Log**: Complete validation log with timestamps
- **Summary Report**: Overview of errors and warnings
- **Exit Codes**: 0 for success, 1 for errors

## Usage Examples

### Complete Setup Workflow

```bash
# 1. Detect hardware
./scripts/config-manager.sh detect-hardware

# 2. Initialize and customize preferences
./scripts/config-manager.sh init-preferences
nano ~/.config/zephyrus-g14/preferences.conf

# 3. Generate configurations
./scripts/config-manager.sh generate

# 4. Validate configurations
./scripts/validate-config.sh

# 5. Apply configurations (run main setup)
./setup.sh
```

### Customization Workflow

```bash
# View current hardware detection
./scripts/config-manager.sh show-hardware

# View current preferences
./scripts/config-manager.sh show-preferences

# Edit preferences
nano ~/.config/zephyrus-g14/preferences.conf

# Regenerate configurations with new preferences
./scripts/config-manager.sh generate --force

# Validate changes
./scripts/validate-config.sh
```

### Troubleshooting

```bash
# Check validation logs
cat ~/.config/zephyrus-g14/validation.log

# View configuration manager logs
cat ~/.config/zephyrus-g14/config-manager.log

# Test specific configuration
./scripts/validate-config.sh
```

## Advanced Usage

### Custom Hardware Variants

To add support for a new hardware variant:

1. Create variant directory: `configs/variants/your-variant/`
2. Add `variant.conf` with hardware specifications
3. Include variant-specific configuration files
4. Update hardware detection logic in `config-manager.sh`

### Custom Templates

To create custom templates:

1. Add `.template` files to `configs/templates/`
2. Use variable substitution syntax
3. Test with `config-manager.sh generate`
4. Validate with `validate-config.sh`

### Integration with Setup Scripts

The modular configuration system integrates with the main setup process:

```bash
# In setup.sh
source scripts/config-manager.sh
generate_configurations
validate_all_configurations
```

## Troubleshooting

### Common Issues

#### Hardware Not Detected
- Ensure you're running on supported ASUS hardware
- Check DMI information: `cat /sys/class/dmi/id/product_name`
- Run hardware detection manually: `./scripts/config-manager.sh detect-hardware`

#### Configuration Validation Failures
- Check validation log: `~/.config/zephyrus-g14/validation.log`
- Verify hardware compatibility
- Ensure all required packages are installed

#### Template Processing Errors
- Verify template syntax
- Check variable names and values
- Ensure preferences file is valid

#### Variant Not Found
- Check if your hardware model is supported
- Verify hardware detection results
- Use generic variant as fallback

### Getting Help

1. Check validation logs and reports
2. Review hardware detection output
3. Verify user preferences are valid
4. Test with generic variant configuration
5. Check main setup script logs

## Contributing

To contribute to the modular configuration system:

1. Add support for new hardware variants
2. Improve hardware detection logic
3. Create additional configuration templates
4. Enhance validation checks
5. Update documentation

The modular configuration system is designed to be extensible and maintainable, making it easy to add support for new hardware and customize the setup process.