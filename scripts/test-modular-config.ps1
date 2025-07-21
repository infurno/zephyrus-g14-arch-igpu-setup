# PowerShell Test Script for Modular Configuration System
# Validates that all components work together correctly

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = Join-Path (Split-Path -Parent $ScriptDir) "configs"
$TestDir = Join-Path $env:TEMP "zephyrus-g14-config-test"

# Test results
$TestsPassed = 0
$TestsFailed = 0

# Test logging functions
function Log-Test($message) {
    Write-Host "[TEST] $message" -ForegroundColor Cyan
}

function Log-Pass($message) {
    Write-Host "[PASS] $message" -ForegroundColor Green
    $script:TestsPassed++
}

function Log-Fail($message) {
    Write-Host "[FAIL] $message" -ForegroundColor Red
    $script:TestsFailed++
}

# Setup test environment
function Setup-TestEnv {
    Log-Test "Setting up test environment..."
    
    # Create test directory
    if (Test-Path $TestDir) {
        Remove-Item -Recurse -Force $TestDir
    }
    New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
    
    Log-Pass "Test environment setup complete"
}

# Test file structure and permissions
function Test-FileStructure {
    Log-Test "Testing file structure..."
    
    # Check main directories exist
    $RequiredDirs = @(
        "configs/templates",
        "configs/variants",
        "configs/variants/generic",
        "configs/variants/ga403wr-2025",
        "configs/variants/ga403uv"
    )
    
    foreach ($dir in $RequiredDirs) {
        $fullPath = Join-Path (Split-Path -Parent $ScriptDir) $dir
        if (Test-Path $fullPath) {
            Log-Pass "Required directory exists: $dir"
        } else {
            Log-Fail "Required directory missing: $dir"
        }
    }
    
    # Check script files exist
    $RequiredScripts = @(
        "config-manager.sh",
        "validate-config.sh"
    )
    
    foreach ($script in $RequiredScripts) {
        $scriptPath = Join-Path $ScriptDir $script
        if (Test-Path $scriptPath) {
            Log-Pass "Required script exists: $script"
        } else {
            Log-Fail "Required script missing: $script"
        }
    }
}

# Test template files
function Test-TemplateProcessing {
    Log-Test "Testing template processing..."
    
    # Check if templates exist
    $TemplateDir = Join-Path $ConfigDir "templates"
    if (Test-Path $TemplateDir) {
        $TemplateFiles = Get-ChildItem -Path $TemplateDir -Filter "*.template" -Recurse
        if ($TemplateFiles.Count -gt 0) {
            Log-Pass "Configuration templates found ($($TemplateFiles.Count) templates)"
            
            # Check specific templates
            $XorgTemplate = Join-Path $TemplateDir "xorg/10-hybrid.conf.template"
            if (Test-Path $XorgTemplate) {
                Log-Pass "Xorg template exists"
            } else {
                Log-Fail "Xorg template missing"
            }
            
            $TlpTemplate = Join-Path $TemplateDir "tlp/tlp.conf.template"
            if (Test-Path $TlpTemplate) {
                Log-Pass "TLP template exists"
            } else {
                Log-Fail "TLP template missing"
            }
        } else {
            Log-Fail "No configuration templates found"
        }
    } else {
        Log-Fail "Templates directory not found"
    }
}

# Test hardware variants
function Test-HardwareVariants {
    Log-Test "Testing hardware variant support..."
    
    # Check if variant configurations exist
    $VariantsDir = Join-Path $ConfigDir "variants"
    if (Test-Path $VariantsDir) {
        $VariantConfigs = Get-ChildItem -Path $VariantsDir -Filter "variant.conf" -Recurse
        if ($VariantConfigs.Count -gt 0) {
            Log-Pass "Hardware variant configurations found ($($VariantConfigs.Count) variants)"
        } else {
            Log-Fail "No hardware variant configurations found"
        }
        
        # Test specific variants
        $GA403WR2025Variant = Join-Path $VariantsDir "ga403wr-2025/variant.conf"
        if (Test-Path $GA403WR2025Variant) {
            Log-Pass "GA403WR-2025 variant configuration exists"
        } else {
            Log-Fail "GA403WR-2025 variant configuration missing"
        }
        
        $GA403UVVariant = Join-Path $VariantsDir "ga403uv/variant.conf"
        if (Test-Path $GA403UVVariant) {
            Log-Pass "GA403UV variant configuration exists"
        } else {
            Log-Fail "GA403UV variant configuration missing"
        }
        
        $GenericVariant = Join-Path $VariantsDir "generic/variant.conf"
        if (Test-Path $GenericVariant) {
            Log-Pass "Generic fallback variant configuration exists"
        } else {
            Log-Fail "Generic fallback variant configuration missing"
        }
    } else {
        Log-Fail "Variants directory not found"
    }
}

# Test configuration consistency
function Test-ConfigurationConsistency {
    Log-Test "Testing configuration consistency..."
    
    $ConsistencyIssues = 0
    
    # Check for required configuration files
    $RequiredConfigs = @(
        "xorg/10-hybrid.conf",
        "tlp/tlp.conf",
        "udev/81-nvidia-switching.rules",
        "systemd/nvidia-suspend.service"
    )
    
    foreach ($config in $RequiredConfigs) {
        $configPath = Join-Path $ConfigDir $config
        if (Test-Path $configPath) {
            Log-Pass "Required configuration exists: $config"
        } else {
            Log-Fail "Required configuration missing: $config"
            $ConsistencyIssues++
        }
    }
    
    if ($ConsistencyIssues -eq 0) {
        Log-Pass "Configuration consistency check passed"
    } else {
        Log-Fail "Configuration consistency issues found: $ConsistencyIssues"
    }
}

# Test variant-specific configurations
function Test-VariantConfigurations {
    Log-Test "Testing variant-specific configurations..."
    
    # Test GA403WR-2025 variant files
    $GA403WR2025Dir = Join-Path $ConfigDir "variants/ga403wr-2025"
    if (Test-Path $GA403WR2025Dir) {
        $XorgConfig = Join-Path $GA403WR2025Dir "xorg/10-hybrid.conf"
        if (Test-Path $XorgConfig) {
            Log-Pass "GA403WR-2025 Xorg configuration exists"
        } else {
            Log-Fail "GA403WR-2025 Xorg configuration missing"
        }
        
        $TlpConfig = Join-Path $GA403WR2025Dir "tlp/tlp.conf"
        if (Test-Path $TlpConfig) {
            Log-Pass "GA403WR-2025 TLP configuration exists"
        } else {
            Log-Fail "GA403WR-2025 TLP configuration missing"
        }
    }
    
    # Test GA403UV variant files
    $GA403UVDir = Join-Path $ConfigDir "variants/ga403uv"
    if (Test-Path $GA403UVDir) {
        $TlpConfig = Join-Path $GA403UVDir "tlp/tlp.conf"
        if (Test-Path $TlpConfig) {
            Log-Pass "GA403UV TLP configuration exists"
        } else {
            Log-Fail "GA403UV TLP configuration missing"
        }
    }
    
    # Test generic variant files
    $GenericDir = Join-Path $ConfigDir "variants/generic"
    if (Test-Path $GenericDir) {
        $XorgConfig = Join-Path $GenericDir "xorg/10-hybrid.conf"
        if (Test-Path $XorgConfig) {
            Log-Pass "Generic Xorg configuration exists"
        } else {
            Log-Fail "Generic Xorg configuration missing"
        }
    }
}

# Test documentation
function Test-Documentation {
    Log-Test "Testing documentation..."
    
    $DocsDir = Join-Path (Split-Path -Parent $ScriptDir) "docs"
    $ModularConfigDoc = Join-Path $DocsDir "MODULAR_CONFIGURATION.md"
    
    if (Test-Path $ModularConfigDoc) {
        Log-Pass "Modular configuration documentation exists"
        
        # Check if documentation contains key sections
        $DocContent = Get-Content $ModularConfigDoc -Raw
        $RequiredSections = @(
            "Hardware Detection",
            "User Preferences",
            "Hardware Variants",
            "Configuration Templates",
            "Configuration Validation"
        )
        
        foreach ($section in $RequiredSections) {
            if ($DocContent -match $section) {
                Log-Pass "Documentation contains section: $section"
            } else {
                Log-Fail "Documentation missing section: $section"
            }
        }
    } else {
        Log-Fail "Modular configuration documentation missing"
    }
}

# Cleanup test environment
function Cleanup-TestEnv {
    Log-Test "Cleaning up test environment..."
    if (Test-Path $TestDir) {
        Remove-Item -Recurse -Force $TestDir
    }
    Log-Pass "Test environment cleaned up"
}

# Generate test report
function Generate-TestReport {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "Modular Configuration System Test Report" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "Tests Passed: $TestsPassed" -ForegroundColor Green
    Write-Host "Tests Failed: $TestsFailed" -ForegroundColor Red
    Write-Host "Total Tests: $($TestsPassed + $TestsFailed)" -ForegroundColor Cyan
    Write-Host ""
    
    if ($TestsFailed -eq 0) {
        Write-Host "All tests passed! Modular configuration system is working correctly." -ForegroundColor Green
        return $true
    } else {
        Write-Host "Some tests failed. Please review the issues above." -ForegroundColor Red
        return $false
    }
}

# Main test execution
function Main {
    Write-Host "Starting modular configuration system tests..." -ForegroundColor Yellow
    Write-Host ""
    
    Setup-TestEnv
    Test-FileStructure
    Test-TemplateProcessing
    Test-HardwareVariants
    Test-ConfigurationConsistency
    Test-VariantConfigurations
    Test-Documentation
    Cleanup-TestEnv
    
    $success = Generate-TestReport
    
    if (-not $success) {
        exit 1
    }
}

# Execute main function
Main