#!/bin/bash

# Release management script for ASUS ROG Zephyrus G14 Arch Linux Setup
# This script handles version bumping, changelog updates, and release preparation

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$PROJECT_ROOT/VERSION"
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    version                 Show current version
    bump [major|minor|patch] Bump version number
    prepare [VERSION]       Prepare release (update changelog, create tag)
    package                 Create release package
    validate               Validate release readiness
    help                   Show this help message

Options:
    --dry-run              Show what would be done without making changes
    --force                Skip confirmation prompts
    --verbose              Enable verbose output

Examples:
    $0 version                    # Show current version
    $0 bump patch                 # Bump patch version (1.0.0 -> 1.0.1)
    $0 bump minor                 # Bump minor version (1.0.0 -> 1.1.0)
    $0 bump major                 # Bump major version (1.0.0 -> 2.0.0)
    $0 prepare 1.1.0              # Prepare release for version 1.1.0
    $0 package                    # Create release package
    $0 validate                   # Validate release readiness
EOF
}

# Get current version from VERSION file
get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "0.0.0"
    fi
}

# Validate version format (semantic versioning)
validate_version() {
    local version="$1"
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format: $version (expected: X.Y.Z)"
        return 1
    fi
}

# Bump version number
bump_version() {
    local bump_type="$1"
    local current_version
    current_version=$(get_current_version)
    
    # Parse current version
    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"
    
    # Bump version based on type
    case "$bump_type" in
        major)
            ((major++))
            minor=0
            patch=0
            ;;
        minor)
            ((minor++))
            patch=0
            ;;
        patch)
            ((patch++))
            ;;
        *)
            log_error "Invalid bump type: $bump_type (expected: major, minor, or patch)"
            return 1
            ;;
    esac
    
    local new_version="$major.$minor.$patch"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Would bump version from $current_version to $new_version"
        return 0
    fi
    
    # Confirm version bump
    if [[ "${FORCE:-false}" != "true" ]]; then
        echo -n "Bump version from $current_version to $new_version? [y/N] "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Version bump cancelled"
            return 0
        fi
    fi
    
    # Update VERSION file
    echo "$new_version" > "$VERSION_FILE"
    log_success "Version bumped from $current_version to $new_version"
    
    # Update setup.sh with new version
    if [[ -f "$PROJECT_ROOT/setup.sh" ]]; then
        sed -i "s/VERSION=\".*\"/VERSION=\"$new_version\"/" "$PROJECT_ROOT/setup.sh"
        log_info "Updated version in setup.sh"
    fi
}

# Prepare release (update changelog, create git tag)
prepare_release() {
    local version="$1"
    validate_version "$version"
    
    local current_version
    current_version=$(get_current_version)
    
    if [[ "$version" == "$current_version" ]]; then
        log_info "Version $version is already current"
    else
        log_info "Updating version from $current_version to $version"
        echo "$version" > "$VERSION_FILE"
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Would prepare release for version $version"
        return 0
    fi
    
    # Update changelog
    local date
    date=$(date +%Y-%m-%d)
    
    # Replace [Unreleased] with version and date
    if grep -q "\[Unreleased\]" "$CHANGELOG_FILE"; then
        sed -i "s/## \[Unreleased\]/## [Unreleased]\n\n## [$version] - $date/" "$CHANGELOG_FILE"
        log_info "Updated changelog for version $version"
    fi
    
    # Commit changes
    if command -v git >/dev/null 2>&1 && [[ -d "$PROJECT_ROOT/.git" ]]; then
        git add "$VERSION_FILE" "$CHANGELOG_FILE"
        if [[ -f "$PROJECT_ROOT/setup.sh" ]]; then
            git add "$PROJECT_ROOT/setup.sh"
        fi
        git commit -m "chore: prepare release $version"
        git tag -a "v$version" -m "Release version $version"
        log_success "Created git commit and tag for version $version"
    else
        log_warning "Git not available or not in git repository - skipping commit and tag"
    fi
}

# Create release package
create_package() {
    local version
    version=$(get_current_version)
    local package_name="zephyrus-g14-arch-setup-v$version"
    local package_dir="$PROJECT_ROOT/dist"
    local package_path="$package_dir/$package_name.tar.gz"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Would create package: $package_path"
        return 0
    fi
    
    # Create dist directory
    mkdir -p "$package_dir"
    
    # Create temporary directory for package contents
    local temp_dir
    temp_dir=$(mktemp -d)
    local package_temp="$temp_dir/$package_name"
    
    # Copy project files (excluding development files)
    mkdir -p "$package_temp"
    
    # Copy main files
    cp -r "$PROJECT_ROOT"/{setup.sh,setup.bat,configs,scripts,docs,tests} "$package_temp/"
    cp "$PROJECT_ROOT"/{README.md,LICENSE,CHANGELOG.md,VERSION,CONTRIBUTING.md} "$package_temp/"
    
    # Remove development and testing files
    find "$package_temp" -name "*.log" -delete
    find "$package_temp" -name ".git*" -delete
    find "$package_temp" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$package_temp" -name "*.pyc" -delete
    
    # Create tarball
    cd "$temp_dir"
    tar -czf "$package_path" "$package_name"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Generate checksums
    cd "$package_dir"
    sha256sum "$package_name.tar.gz" > "$package_name.tar.gz.sha256"
    
    log_success "Created release package: $package_path"
    log_info "Package size: $(du -h "$package_path" | cut -f1)"
    log_info "SHA256 checksum: $(cat "$package_name.tar.gz.sha256")"
}

# Validate release readiness
validate_release() {
    local errors=0
    
    log_info "Validating release readiness..."
    
    # Check required files exist
    local required_files=(
        "README.md"
        "LICENSE"
        "CHANGELOG.md"
        "VERSION"
        "CONTRIBUTING.md"
        "setup.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            log_error "Missing required file: $file"
            ((errors++))
        fi
    done
    
    # Check VERSION file format
    local version
    version=$(get_current_version)
    if ! validate_version "$version"; then
        ((errors++))
    fi
    
    # Check if changelog has unreleased section
    if ! grep -q "\[Unreleased\]" "$CHANGELOG_FILE"; then
        log_warning "Changelog missing [Unreleased] section"
    fi
    
    # Check if setup.sh is executable
    if [[ ! -x "$PROJECT_ROOT/setup.sh" ]]; then
        log_error "setup.sh is not executable"
        ((errors++))
    fi
    
    # Check for TODO or FIXME comments
    local todo_count
    todo_count=$(find "$PROJECT_ROOT" -name "*.sh" -o -name "*.md" | xargs grep -i "TODO\|FIXME" | wc -l)
    if [[ $todo_count -gt 0 ]]; then
        log_warning "Found $todo_count TODO/FIXME comments in codebase"
    fi
    
    # Run basic syntax check on shell scripts
    local script_errors=0
    while IFS= read -r -d '' script; do
        if ! bash -n "$script" 2>/dev/null; then
            log_error "Syntax error in script: $script"
            ((script_errors++))
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -print0)
    
    errors=$((errors + script_errors))
    
    if [[ $errors -eq 0 ]]; then
        log_success "Release validation passed"
        return 0
    else
        log_error "Release validation failed with $errors errors"
        return 1
    fi
}

# Main function
main() {
    local command="${1:-help}"
    
    # Parse global options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                set -x
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Execute command
    case "$command" in
        version)
            echo "Current version: $(get_current_version)"
            ;;
        bump)
            if [[ $# -lt 2 ]]; then
                log_error "Bump type required (major, minor, or patch)"
                show_usage
                exit 1
            fi
            bump_version "$2"
            ;;
        prepare)
            if [[ $# -lt 2 ]]; then
                log_error "Version required for prepare command"
                show_usage
                exit 1
            fi
            prepare_release "$2"
            ;;
        package)
            create_package
            ;;
        validate)
            validate_release
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"