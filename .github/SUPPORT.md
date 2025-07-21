# Support

Thank you for using the ASUS ROG Zephyrus G14 Arch Linux Setup! This document provides information on how to get help and support.

## Getting Help

### 1. Documentation First

Before asking for help, please check our comprehensive documentation:

- **[README.md](../README.md)** - Complete setup and usage guide
- **[Troubleshooting Guide](../docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Customization Guide](../docs/CUSTOMIZATION.md)** - Advanced configuration options
- **[ASUS Hardware Integration](../docs/ASUS_HARDWARE_INTEGRATION.md)** - Hardware-specific information

### 2. Self-Diagnosis Tools

Try our built-in diagnostic tools:

```bash
# Run comprehensive system diagnostics
./scripts/troubleshoot.sh

# Generate detailed system report
./scripts/troubleshoot.sh --report

# Interactive troubleshooting menu
./scripts/troubleshoot.sh --interactive

# Validate system configuration
./scripts/system-test.sh
```

### 3. Search Existing Issues

Search through [existing issues](https://github.com/username/zephyrus-g14-arch-igpu-setup/issues) to see if your problem has already been reported or solved.

## How to Get Support

### GitHub Issues

For bugs, feature requests, and hardware support:

1. **Bug Reports**: Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml)
2. **Feature Requests**: Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.yml)
3. **Hardware Support**: Use the [hardware support template](.github/ISSUE_TEMPLATE/hardware_support.yml)
4. **Questions**: Use the [question template](.github/ISSUE_TEMPLATE/question.yml)

### GitHub Discussions

For general questions, tips, and community interaction:

- [GitHub Discussions](https://github.com/username/zephyrus-g14-arch-igpu-setup/discussions)

## What Information to Include

When asking for help, please include:

### System Information
```bash
# Hardware information
cat /sys/class/dmi/id/product_name
cat /sys/class/dmi/id/product_version
lscpu | grep "Model name"
lspci | grep -E "(VGA|3D|Display)"

# System information
uname -a
cat /etc/os-release
```

### Setup Information
- Setup script version (check `VERSION` file)
- Installation method used
- Any customizations made
- Error messages or logs

### Logs
Include relevant logs:
- Setup logs: `./logs/setup_*.log`
- System logs: `journalctl -u asusd -u supergfxd -u tlp`
- Troubleshooting output: `./scripts/troubleshoot.sh --report`

## Response Times

This is a community-driven project maintained by volunteers. Response times may vary:

- **Critical Issues**: We aim to respond within 24-48 hours
- **Bug Reports**: Usually responded to within 2-7 days
- **Feature Requests**: May take longer to evaluate and implement
- **Questions**: Community members often respond quickly

## Community Guidelines

Please follow these guidelines when seeking support:

### Be Respectful
- Be patient and respectful with maintainers and community members
- Remember that everyone is volunteering their time
- Use inclusive and welcoming language

### Be Specific
- Provide clear, detailed descriptions of your issue
- Include all requested information in templates
- Use proper formatting for code and logs

### Be Helpful
- Help others when you can
- Share solutions you've found
- Contribute back to the community

## Self-Help Resources

### Common Issues Quick Reference

| Issue | Quick Fix | Documentation |
|-------|-----------|---------------|
| Black screen after boot | Check Xorg config | [Troubleshooting Guide](../docs/TROUBLESHOOTING.md#display-issues) |
| Poor battery life | Check power management | [Troubleshooting Guide](../docs/TROUBLESHOOTING.md#power-issues) |
| NVIDIA GPU not working | Verify drivers | [Troubleshooting Guide](../docs/TROUBLESHOOTING.md#gpu-issues) |
| External displays not working | Check display config | [Troubleshooting Guide](../docs/TROUBLESHOOTING.md#display-issues) |

### Useful Commands

```bash
# Check GPU status
gpu-state-manager status
prime-run glxinfo | grep "OpenGL renderer"

# Check power management
tlp-stat
powerprofilesctl get

# Check ASUS tools
asusctl --version
supergfxctl -g

# System validation
./scripts/system-test.sh
```

## Contributing Support

You can help improve support for everyone:

### Documentation
- Improve existing documentation
- Add missing information
- Fix errors or outdated content

### Issue Triage
- Help reproduce reported issues
- Provide additional information
- Test proposed solutions

### Community Support
- Answer questions from other users
- Share your experiences and solutions
- Help with troubleshooting

## Professional Support

This project is provided as-is under the MIT license. There is no official professional support, but you may:

- Hire community contributors for custom work
- Contribute funding to support development
- Sponsor specific features or improvements

## Hardware Support

### Currently Supported
- ASUS ROG Zephyrus G14 (GA403WR) - Primary target
- Similar ASUS ROG models with AMD/NVIDIA hybrid graphics

### Requesting New Hardware Support
Use the [hardware support template](.github/ISSUE_TEMPLATE/hardware_support.yml) and be prepared to:
- Provide detailed hardware specifications
- Test changes on your hardware
- Share logs and debugging information

## Emergency Issues

For critical issues that make your system unusable:

1. **Boot Issues**: Use a live USB to access your system
2. **Recovery**: Use the backup system to restore previous configuration
3. **Rollback**: Follow the rollback procedures in the troubleshooting guide

```bash
# Emergency rollback
./scripts/config-backup.sh restore
sudo reboot
```

## Feedback

We value your feedback! Let us know:
- What's working well
- What could be improved
- Ideas for new features
- Documentation gaps

Thank you for being part of our community!