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

### High Priority (Core Functionality)
1. **`scripts/error-handler.sh`** - ⚠️ Partially updated
   - Still contains several `pacman` references
   - Need to update package checking and recovery functions

2. **`scripts/error-recovery-mechanisms.sh`** - ⚠️ Partially updated
   - Package database recovery commands need updating
   - Cache management commands updated

3. **`scripts/troubleshoot.sh`**
   - Package manager checks need updating
   - System diagnostic commands may need adjustment

### Medium Priority (Testing & Validation)
4. **`tests/` directory**
   - All test scripts contain Arch-specific assumptions
   - Package installation tests need updating
   - Mock system functions need Fedora equivalents

5. **`scripts/system-test.sh`**
   - Package validation checks use `pacman`
   - Service checks may need updating

6. **`scripts/test-*.sh` files**
   - Multiple test scripts with Arch assumptions

### Low Priority (Documentation & Helpers)
7. **`scripts/error-reporter.sh`**
   - Error solutions reference Arch commands
   - Package information gathering uses `pacman`

8. **`scripts/validate-*.sh` files**
   - Validation scripts with Arch-specific checks

9. **`docs/TROUBLESHOOTING.md`**
   - Documentation contains Arch-specific commands
   - Need to update package manager references

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
