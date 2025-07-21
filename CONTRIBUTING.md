# Contributing to ASUS ROG Zephyrus G14 Arch Linux Setup

Thank you for your interest in contributing to this project! This guide will help you get started with contributing to the ASUS ROG Zephyrus G14 Arch Linux Setup repository.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Guidelines](#development-guidelines)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Community](#community)

## Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow. Please be respectful and constructive in all interactions.

### Our Standards

- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Gracefully accept constructive criticism
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

- ASUS ROG Zephyrus G14 laptop (or similar hardware for testing)
- Arch Linux installation
- Basic knowledge of shell scripting and Linux system administration
- Git for version control

### Development Setup

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/your-username/zephyrus-g14-arch-igpu-setup.git
   cd zephyrus-g14-arch-igpu-setup
   ```
3. Create a new branch for your feature or fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. Test your changes in a safe environment (VM or test system)

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

- **Bug Reports**: Help us identify and fix issues
- **Feature Requests**: Suggest new functionality or improvements
- **Code Contributions**: Submit bug fixes, new features, or improvements
- **Documentation**: Improve or add to our documentation
- **Testing**: Help test the setup on different hardware configurations

### Reporting Bugs

When reporting bugs, please include:

1. **Hardware Information**: Laptop model, CPU, GPU, RAM, etc.
2. **System Information**: Arch Linux version, kernel version, desktop environment
3. **Steps to Reproduce**: Clear steps to reproduce the issue
4. **Expected Behavior**: What you expected to happen
5. **Actual Behavior**: What actually happened
6. **Logs**: Relevant log files or error messages
7. **Screenshots**: If applicable

Use the bug report template when creating issues.

### Suggesting Features

When suggesting new features:

1. Check if the feature already exists or has been requested
2. Explain the use case and benefits
3. Provide implementation ideas if possible
4. Consider backward compatibility and impact on existing users

## Development Guidelines

### Shell Scripting Standards

- Use `#!/bin/bash` shebang for all shell scripts
- Follow POSIX compliance where possible
- Use proper error handling with `set -euo pipefail`
- Include comprehensive logging and user feedback
- Use meaningful variable names and add comments
- Validate user input and provide helpful error messages

### Code Style

```bash
# Good: Clear variable names and error handling
install_nvidia_drivers() {
    local log_file="$1"
    
    if ! pacman -S --noconfirm nvidia nvidia-utils; then
        log_error "Failed to install NVIDIA drivers" "$log_file"
        return 1
    fi
    
    log_info "NVIDIA drivers installed successfully" "$log_file"
}

# Bad: Poor error handling and unclear names
install_nv() {
    pacman -S nvidia
}
```

### Configuration Files

- Use clear, well-commented configuration files
- Provide sensible defaults
- Include documentation for all options
- Test configurations on target hardware

### Documentation

- Keep documentation up to date with code changes
- Use clear, concise language
- Include examples and use cases
- Test all documented procedures

## Testing

### Testing Requirements

All contributions should be tested before submission:

1. **Dry Run Testing**: Use `./setup.sh --dry-run` to test without making changes
2. **Virtual Machine Testing**: Test basic functionality in a VM when possible
3. **Hardware Testing**: Test on actual hardware when available
4. **Regression Testing**: Ensure existing functionality still works

### Test Scripts

Run the provided test scripts:

```bash
# Run all tests
./tests/run_all_tests.sh

# Run specific test categories
./tests/unit/test_setup_functions.sh
./tests/integration/test_complete_setup.sh
./tests/hardware/test_compatibility.sh
```

### Manual Testing Checklist

- [ ] Setup script completes without errors
- [ ] GPU switching works correctly
- [ ] Power management is functional
- [ ] ASUS tools are properly configured
- [ ] System boots correctly after setup
- [ ] Battery life is optimized
- [ ] External displays work properly

## Submitting Changes

### Pull Request Process

1. **Create a Branch**: Create a feature branch from `main`
2. **Make Changes**: Implement your changes with proper testing
3. **Update Documentation**: Update relevant documentation
4. **Test Thoroughly**: Run all applicable tests
5. **Commit Changes**: Use clear, descriptive commit messages
6. **Push Branch**: Push your branch to your fork
7. **Create Pull Request**: Submit a pull request with detailed description

### Commit Message Guidelines

Use clear, descriptive commit messages:

```
feat: add support for RTX 4060 GPU configuration

- Add RTX 4060 to supported GPU list
- Update power management settings for new GPU
- Add specific configuration for mobile variant
- Update documentation with compatibility info

Fixes #123
```

### Pull Request Template

When creating a pull request, include:

- **Description**: Clear description of changes
- **Type of Change**: Bug fix, new feature, documentation, etc.
- **Testing**: How the changes were tested
- **Hardware Tested**: What hardware configurations were tested
- **Breaking Changes**: Any breaking changes and migration notes
- **Related Issues**: Link to related issues

### Review Process

1. **Automated Checks**: CI/CD pipeline runs automated tests
2. **Code Review**: Maintainers review code for quality and compatibility
3. **Testing**: Changes are tested on available hardware
4. **Documentation Review**: Documentation changes are reviewed
5. **Approval**: Changes are approved and merged

## Community

### Getting Help

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Documentation**: Check existing documentation first

### Communication Guidelines

- Be respectful and constructive
- Search existing issues before creating new ones
- Provide detailed information when asking for help
- Help others when you can

### Recognition

Contributors are recognized in:
- README.md acknowledgments section
- Release notes for significant contributions
- GitHub contributor statistics

## Development Workflow

### Branch Strategy

- `main`: Stable, production-ready code
- `develop`: Integration branch for new features
- `feature/*`: Feature development branches
- `hotfix/*`: Critical bug fixes
- `release/*`: Release preparation branches

### Release Process

1. **Feature Freeze**: Stop adding new features
2. **Testing**: Comprehensive testing on multiple hardware configurations
3. **Documentation**: Update all documentation
4. **Version Bump**: Update version numbers
5. **Release Notes**: Create detailed release notes
6. **Tag Release**: Create Git tag and GitHub release

## Hardware Testing

### Supported Hardware

Current testing is primarily done on:
- ASUS ROG Zephyrus G14 (GA403WR)
- AMD Ryzen 9 8945HS
- NVIDIA RTX 5070 Ti Laptop GPU

### Testing on New Hardware

If you have different hardware:
1. Test the setup carefully
2. Document any required changes
3. Submit hardware compatibility reports
4. Help expand hardware support

## Questions?

If you have questions about contributing, please:
1. Check the existing documentation
2. Search through GitHub issues
3. Create a new discussion or issue
4. Be patient and respectful when asking for help

Thank you for contributing to make this project better for everyone!