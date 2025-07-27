# Fedora 42 Migration Guide

This document outlines the migration from Arch Linux to Fedora 42 support for the ASUS ROG Zephyrus G14 setup script.

## Completed Changes

### Core Setup Script (`setup.sh`)
- ✅ Updated package manager from `pacman` to `dnf`
- ✅ Updated package names for Fedora equivalents
- ✅ Replaced AUR/yay with COPR support
- ✅ Updated system detection from Arch to Fedora
- ✅ Changed initramfs tool from `mkinitcpio` to `dracut`
- ✅ Updated GRUB commands from `grub-mkconfig` to `grub2-mkconfig`
- ✅ Updated GRUB paths for Fedora's `/boot/grub2/` structure
- ✅ Added auto-cpufreq pip installation fallback
- ✅ Updated internet connectivity check to use fedoraproject.org

### Supporting Scripts (ALL COMPLETED ✅)
- ✅ **`scripts/error-handler.sh`** - Package manager commands updated
- ✅ **`scripts/error-recovery-mechanisms.sh`** - Recovery mechanisms migrated
- ✅ **`scripts/troubleshoot.sh`** - Diagnostic commands updated
- ✅ **`scripts/system-test.sh`** - Package validation updated
- ✅ **`scripts/test-power-management.sh`** - Package checks updated
- ✅ **`scripts/rollback-system.sh`** - Backup system migrated
- ✅ **`scripts/error-reporter.sh`** - Error solutions updated
- ✅ **`scripts/config-backup.sh`** - Configuration paths updated
- ✅ **`scripts/error-handler-enhancements.sh`** - Enhanced error handling migrated
- ✅ **`scripts/validate-backup-system.sh`** - Validation updated
- ✅ **`scripts/validate-error-handling.sh`** - Validation patterns updated
- ✅ **`scripts/integrate-error-handling.sh`** - Integration patterns updated
- ✅ **`scripts/error-handling-summary.md`** - Documentation updated

### Package Mappings Applied
| Arch Package | Fedora Package |
|--------------|----------------|
| `linux-headers` | `kernel-headers` + `kernel-devel` |
| `mesa` | `mesa-dri-drivers` |
| `vulkan-radeon` | `mesa-vulkan-drivers` |
| `nvidia` | `akmod-nvidia` |
| `nvidia-utils` | `xorg-x11-drv-nvidia-cuda` |
| `base-devel` | `@development-tools` |
| `bbswitch` | *Removed (not available/needed)* |
| `cpupower` | `kernel-tools` |

### Repository Changes
- ✅ Replaced ASUS Linux Arch repository with COPR
- ✅ Added RPM Fusion repository setup for additional drivers
- ✅ Updated repository configuration methods

## Remaining Files to Update

### ✅ ALL SCRIPT FILES COMPLETED!

All 12 script files that contained pacman references have been successfully updated:

1. ✅ **`scripts/error-handler.sh`** - Core error handling system
2. ✅ **`scripts/error-recovery-mechanisms.sh`** - Package recovery functions  
3. ✅ **`scripts/troubleshoot.sh`** - System diagnostic tools
4. ✅ **`scripts/system-test.sh`** - Package validation tests
5. ✅ **`scripts/test-power-management.sh`** - Power management tests
6. ✅ **`scripts/rollback-system.sh`** - System backup and rollback
7. ✅ **`scripts/error-reporter.sh`** - Error reporting and solutions
8. ✅ **`scripts/config-backup.sh`** - Configuration backup system
9. ✅ **`scripts/error-handler-enhancements.sh`** - Enhanced error handling
10. ✅ **`scripts/validate-backup-system.sh`** - Backup validation
11. ✅ **`scripts/validate-error-handling.sh`** - Error handling validation
12. ✅ **`scripts/integrate-error-handling.sh`** - Error handling integration

### Remaining Tasks (Non-Critical)
1. **Test Configuration Files** - Verify configs in `configs/` directory work with Fedora
2. **Documentation Updates** - Update `docs/` directory for Fedora-specific instructions  
3. **System Testing** - Comprehensive testing in Fedora 42 environment

## Quick Reference for Common Replacements

### Package Manager Commands
```bash
# Package Installation
pacman -S package_name          → dnf install package_name
pacman -S --noconfirm package   → dnf install -y package

# Package Queries
pacman -Qi package              → dnf list installed package
pacman -Q                       → dnf list installed

# System Updates
pacman -Syu                     → dnf upgrade
pacman -Sy                      → dnf makecache

# Cache Management
pacman -Scc                     → dnf clean all

# Database Checks
pacman -Dk                      → dnf check
```

### System Commands
```bash
# Initramfs
mkinitcpio -P                   → dracut --regenerate-all --force
mkinitcpio -k kernel -g image   → dracut --force image kernel

# GRUB
grub-mkconfig -o /boot/grub/grub.cfg  → grub2-mkconfig -o /boot/grub2/grub.cfg
```

### Configuration Paths
```bash
# Package manager config
/etc/pacman.conf               → /etc/dnf/dnf.conf

# GRUB
/boot/grub/                    → /boot/grub2/

# Package cache
/var/cache/pacman/pkg/         → /var/cache/dnf/
```

## Testing Recommendations

1. **Virtual Machine Testing**: Test the migrated script in a Fedora 42 VM first
2. **Dry Run Mode**: Use `--dry-run` flag extensively during testing
3. **Backup System**: Ensure backup functionality works before testing
4. **Component Testing**: Test individual components (GPU, power management, ASUS tools) separately

## Known Issues & Considerations

1. **Auto-cpufreq**: May need to be installed via pip if not in Fedora repos
2. **ASUS Tools**: COPR repository availability may vary
3. **bbswitch**: May not be needed/available in newer kernel versions
4. **NVIDIA Drivers**: akmod-nvidia behaves differently than Arch nvidia package
5. **Service Names**: Some systemd service names may differ between distributions

## Validation Checklist

- [ ] Script runs without syntax errors
- [ ] Package installation completes successfully
- [ ] GPU switching functionality works
- [ ] Power management tools are properly configured
- [ ] ASUS hardware tools function correctly
- [ ] System services start correctly
- [ ] Configuration files are properly installed
- [ ] Backup and rollback functionality works

## Contributing

When updating remaining files, please:
1. Test changes in a VM environment first
2. Update this document with completed changes
3. Add new package mappings to the table above
4. Report any Fedora-specific issues discovered
