# Windows Build Verification Script
# SPDX-License-Identifier: MIT
# Comprehensive MSVC validation, Windows API compatibility, and deployment verification

param(
    [string]$BuildType = "Release",
    [string]$Architecture = "x64",
    [string]$QtVersion = "6.6.2",
    [switch]$SkipTests = $false,
    [switch]$Verbose = $false,
    [switch]$PackageOnly = $false
)

# Script configuration
$ErrorActionPreference = "Stop"
$InformationPreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

# Constants
$PROJECT_ROOT = Split-Path $PSScriptRoot -Parent
$BUILD_DIR = Join-Path $PROJECT_ROOT "build-windows-verify"
$PACKAGE_DIR = Join-Path $PROJECT_ROOT "package-windows"
$TOOLS_DIR = Join-Path $PROJECT_ROOT "tools\windows"

# Colors for output
$ColorSuccess = "Green"
$ColorError = "Red"
$ColorWarning = "Yellow"
$ColorInfo = "Cyan"

function Write-Section($Message) {
    Write-Host "`n=== $Message ===" -ForegroundColor $ColorInfo
}

function Write-Success($Message) {
    Write-Host "✓ $Message" -ForegroundColor $ColorSuccess
}

function Write-Warning($Message) {
    Write-Host "⚠ $Message" -ForegroundColor $ColorWarning
}

function Write-Error($Message) {
    Write-Host "✗ $Message" -ForegroundColor $ColorError
}

function Test-Command($CommandName) {
    return Get-Command $CommandName -ErrorAction SilentlyContinue
}

function Invoke-ExternalCommand($Command, $Arguments = @(), $WorkingDirectory = $null) {
    $process = @{
        FilePath = $Command
        ArgumentList = $Arguments
        NoNewWindow = $true
        Wait = $true
        PassThru = $true
    }

    if ($WorkingDirectory) {
        $process.WorkingDirectory = $WorkingDirectory
    }

    if ($Verbose) {
        Write-Host "Executing: $Command $($Arguments -join ' ')" -ForegroundColor DarkGray
    }

    $result = Start-Process @process

    if ($result.ExitCode -ne 0) {
        throw "Command failed with exit code $($result.ExitCode): $Command"
    }

    return $result
}

# =============================================================================
# Environment Verification
# =============================================================================
function Test-BuildEnvironment {
    Write-Section "Environment Verification"

    # Check Windows version
    $winVersion = [System.Environment]::OSVersion.Version
    Write-Information "Windows Version: $($winVersion.Major).$($winVersion.Minor).$($winVersion.Build)"

    if ($winVersion.Major -lt 10) {
        throw "Windows 10 or later required for modern MSVC features"
    }
    Write-Success "Windows version compatible"

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        throw "PowerShell 5.0 or later required"
    }
    Write-Success "PowerShell $($psVersion.Major).$($psVersion.Minor) detected"

    # Verify Visual Studio Build Tools
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vsWhere)) {
        throw "Visual Studio Installer not found. Install Visual Studio 2019/2022 or Build Tools"
    }

    $vsInstalls = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json | ConvertFrom-Json
    if (-not $vsInstalls -or $vsInstalls.Count -eq 0) {
        throw "No Visual Studio installation with C++ tools found"
    }

    $vsPath = $vsInstalls[0].installationPath
    Write-Success "Visual Studio found at: $vsPath"

    # Check MSVC version
    $vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
    if (-not (Test-Path $vcvars)) {
        throw "MSVC x64 tools not found"
    }
    Write-Success "MSVC x64 tools verified"

    # Verify Qt installation
    if (-not $env:QT_ROOT -and -not $env:Qt6_DIR) {
        $qtGuess = "C:\Qt\$QtVersion\msvc2019_64"
        if (Test-Path $qtGuess) {
            $env:QT_ROOT = $qtGuess
            Write-Warning "Qt path guessed: $qtGuess"
        } else {
            throw "Qt not found. Set QT_ROOT or Qt6_DIR environment variable"
        }
    }

    $qtDir = $env:QT_ROOT ?? $env:Qt6_DIR
    if (-not (Test-Path (Join-Path $qtDir "bin\qmake.exe"))) {
        throw "Qt installation invalid: qmake not found in $qtDir"
    }
    Write-Success "Qt installation verified at: $qtDir"

    # Check CMake
    if (-not (Test-Command "cmake")) {
        throw "CMake not found in PATH. Install CMake 3.16 or later"
    }

    $cmakeVersion = & cmake --version | Select-String "cmake version (\d+\.\d+\.\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }
    if ([version]$cmakeVersion -lt [version]"3.16") {
        throw "CMake 3.16 or later required, found: $cmakeVersion"
    }
    Write-Success "CMake $cmakeVersion verified"

    # Check Windows SDK
    $sdkPath = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots" -Name KitsRoot10 -ErrorAction SilentlyContinue
    if (-not $sdkPath) {
        throw "Windows SDK not found. Install Windows 10/11 SDK"
    }
    Write-Success "Windows SDK found"

    return @{
        VSPath = $vsPath
        QtPath = $qtDir
        CMakeVersion = $cmakeVersion
    }
}

# =============================================================================
# MSVC Compiler Validation
# =============================================================================
function Test-MSVCCompiler {
    Write-Section "MSVC Compiler Validation"

    # Create test program
    $testDir = Join-Path $env:TEMP "msvc-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $testCpp = @"
// MSVC Feature Test
#include <iostream>
#include <memory>
#include <string_view>
#include <optional>
#include <variant>
#include <filesystem>

// Test C++23 features
#if __cplusplus < 202302L
#error "C++23 support required"
#endif

// Test MSVC version
#if _MSC_VER < 1930
#error "Visual Studio 2022 (MSVC 19.30) or later required"
#endif

// Test Windows API compatibility
#include <windows.h>

int main() {
    // Test modern C++ features
    std::optional<std::string> opt = "test";
    std::variant<int, std::string> var = 42;

    // Test filesystem (C++17)
    auto path = std::filesystem::current_path();

    // Test Windows API
    DWORD version = GetVersion();

    std::cout << "MSVC Version: " << _MSC_VER << std::endl;
    std::cout << "C++ Standard: " << __cplusplus << std::endl;
    std::cout << "Windows Version: " << LOBYTE(LOWORD(version)) << "." << HIBYTE(LOWORD(version)) << std::endl;

    return 0;
}
"@

        $testFile = Join-Path $testDir "test.cpp"
        $testExe = Join-Path $testDir "test.exe"
        Set-Content -Path $testFile -Value $testCpp

        # Setup MSVC environment and compile
        $vcvarsCmd = "call `"$($(Test-BuildEnvironment).VSPath)\VC\Auxiliary\Build\vcvars64.bat`" && cl /std:c++latest /EHsc `"$testFile`" /Fe:`"$testExe`""
        $result = cmd /c $vcvarsCmd 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "MSVC compilation failed:"
            Write-Host $result
            throw "MSVC compiler validation failed"
        }

        # Run test executable
        $output = & $testExe
        Write-Success "MSVC compiler test passed"
        Write-Information $output

        # Check for specific warnings/errors
        if ($result -match "warning C4") {
            Write-Warning "MSVC warnings detected - review compiler output"
        }

    } finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# Windows API Compatibility Check
# =============================================================================
function Test-WindowsAPICompatibility {
    Write-Section "Windows API Compatibility Check"

    # Read source files and check for Windows API usage
    $sourceFiles = Get-ChildItem -Path (Join-Path $PROJECT_ROOT "src") -Filter "*.cpp" -Recurse
    $headerFiles = Get-ChildItem -Path (Join-Path $PROJECT_ROOT "src") -Filter "*.h" -Recurse

    $apiUsage = @{}
    $deprecatedAPIs = @(
        "GetVersionEx", "GetVersion", "VerifyVersionInfo",  # Version detection
        "CreateFont", "CreateFontIndirect",                 # GDI fonts
        "SetWindowLong", "GetWindowLong"                    # Should use 64-bit versions
    )

    $secureAPIs = @{
        "strcpy" = "strcpy_s"
        "strcat" = "strcat_s"
        "sprintf" = "sprintf_s"
        "gets" = "gets_s"
    }

    foreach ($file in $sourceFiles + $headerFiles) {
        $content = Get-Content $file.FullName -Raw

        # Check for Windows headers
        if ($content -match "#include\s*<windows\.h>") {
            $apiUsage[$file.Name] = @{ WindowsAPI = $true }
        }

        # Check for deprecated APIs
        foreach ($api in $deprecatedAPIs) {
            if ($content -match "\b$api\b") {
                if (-not $apiUsage[$file.Name]) { $apiUsage[$file.Name] = @{} }
                if (-not $apiUsage[$file.Name].Deprecated) { $apiUsage[$file.Name].Deprecated = @() }
                $apiUsage[$file.Name].Deprecated += $api
            }
        }

        # Check for insecure APIs
        foreach ($api in $secureAPIs.Keys) {
            if ($content -match "\b$api\b") {
                if (-not $apiUsage[$file.Name]) { $apiUsage[$file.Name] = @{} }
                if (-not $apiUsage[$file.Name].Insecure) { $apiUsage[$file.Name].Insecure = @() }
                $apiUsage[$file.Name].Insecure += @{ Old = $api; New = $secureAPIs[$api] }
            }
        }
    }

    # Report findings
    $hasIssues = $false
    foreach ($file in $apiUsage.Keys) {
        $issues = $apiUsage[$file]

        if ($issues.WindowsAPI) {
            Write-Information "Windows API usage detected in: $file"
        }

        if ($issues.Deprecated) {
            Write-Warning "Deprecated API usage in $file`: $($issues.Deprecated -join ', ')"
            $hasIssues = $true
        }

        if ($issues.Insecure) {
            foreach ($insecure in $issues.Insecure) {
                Write-Warning "Insecure API in $file`: use $($insecure.New) instead of $($insecure.Old)"
            }
            $hasIssues = $true
        }
    }

    if (-not $hasIssues) {
        Write-Success "No Windows API compatibility issues detected"
    }

    # Check Windows version targeting
    $cmakeContent = Get-Content (Join-Path $PROJECT_ROOT "CMakeLists.txt") -Raw
    if ($cmakeContent -match "WIN32_WINNT") {
        Write-Information "Windows version targeting detected in CMakeLists.txt"
    } else {
        Write-Warning "Consider setting WIN32_WINNT for explicit Windows version targeting"
    }
}

# =============================================================================
# Build Process
# =============================================================================
function Invoke-Build {
    Write-Section "Build Process"

    # Clean previous build
    if (Test-Path $BUILD_DIR) {
        Remove-Item -Path $BUILD_DIR -Recurse -Force
    }
    New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null

    $env = Test-BuildEnvironment

    # Setup environment variables
    $qtPath = $env.QtPath
    $env:CMAKE_PREFIX_PATH = $qtPath
    $env:PATH = "$qtPath\bin;$env:PATH"

    # Configure with CMake
    Write-Information "Configuring build..."
    $cmakeArgs = @(
        "-B", $BUILD_DIR
        "-S", $PROJECT_ROOT
        "-G", "Visual Studio 17 2022"
        "-A", $Architecture
        "-DCMAKE_BUILD_TYPE=$BuildType"
        "-DBUILD_TESTING=ON"
        "-DCMAKE_INSTALL_PREFIX=$PACKAGE_DIR"
        "-DCI_MODE=ON"  # Enable warnings as errors
    )

    if ($Verbose) {
        $cmakeArgs += "--debug-output"
    }

    Invoke-ExternalCommand "cmake" $cmakeArgs
    Write-Success "CMake configuration completed"

    # Build project
    Write-Information "Building project..."
    $buildArgs = @(
        "--build", $BUILD_DIR
        "--config", $BuildType
        "--parallel"
    )

    if ($Verbose) {
        $buildArgs += "--verbose"
    }

    Invoke-ExternalCommand "cmake" $buildArgs
    Write-Success "Build completed successfully"

    # Check build outputs
    $expectedExe = Join-Path $BUILD_DIR "$BuildType\WiserOne.exe"
    if (-not (Test-Path $expectedExe)) {
        throw "Expected executable not found: $expectedExe"
    }
    Write-Success "Build artifacts verified"

    return @{
        BuildDir = $BUILD_DIR
        ExecutablePath = $expectedExe
    }
}

# =============================================================================
# Testing
# =============================================================================
function Invoke-Tests {
    param([hashtable]$BuildInfo)

    if ($SkipTests) {
        Write-Warning "Tests skipped by user request"
        return
    }

    Write-Section "Running Tests"

    # Set test environment
    $env:QT_QPA_PLATFORM = "offscreen"  # Headless testing

    # Run CTest
    $ctestArgs = @(
        "--test-dir", $BuildInfo.BuildDir
        "--output-on-failure"
        "-C", $BuildType
        "--parallel", "4"
        "--timeout", "300"
    )

    if ($Verbose) {
        $ctestArgs += "--verbose"
    }

    try {
        Invoke-ExternalCommand "ctest" $ctestArgs
        Write-Success "All tests passed"
    } catch {
        Write-Error "Tests failed - check output above"
        throw
    }
}

# =============================================================================
# Dependency Analysis
# =============================================================================
function Test-Dependencies {
    param([hashtable]$BuildInfo)

    Write-Section "Dependency Analysis"

    $exe = $BuildInfo.ExecutablePath

    # Use dumpbin to analyze dependencies
    $vcvarsCmd = "call `"$($(Test-BuildEnvironment).VSPath)\VC\Auxiliary\Build\vcvars64.bat`" && dumpbin /dependents `"$exe`""
    $dumpOutput = cmd /c $vcvarsCmd 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not analyze dependencies with dumpbin"
        return
    }

    # Parse dependencies
    $dependencies = $dumpOutput | Where-Object { $_ -match "\.dll" } | ForEach-Object { $_.Trim() }

    Write-Information "Dependencies found:"
    foreach ($dep in $dependencies) {
        Write-Information "  - $dep"

        # Flag potentially problematic dependencies
        if ($dep -match "(msvcp|msvcr|vcruntime)\d+\.dll") {
            Write-Information "    Visual C++ Runtime: $dep"
        } elseif ($dep -match "Qt\d") {
            Write-Information "    Qt Framework: $dep"
        } elseif ($dep -match "(api-ms-win|kernelbase|ntdll)") {
            Write-Information "    System: $dep"
        } else {
            Write-Warning "    Unknown/Third-party: $dep"
        }
    }

    # Check for missing Qt deployment
    $qtDeps = $dependencies | Where-Object { $_ -match "Qt\d" }
    if ($qtDeps.Count -gt 0) {
        Write-Information "Qt dependencies detected - deployment required"
        return $qtDeps
    }

    Write-Success "Dependency analysis completed"
}

# =============================================================================
# Windows Deployment
# =============================================================================
function Invoke-Deployment {
    param([hashtable]$BuildInfo, [array]$QtDependencies)

    Write-Section "Windows Deployment"

    # Clean package directory
    if (Test-Path $PACKAGE_DIR) {
        Remove-Item -Path $PACKAGE_DIR -Recurse -Force
    }
    New-Item -ItemType Directory -Path $PACKAGE_DIR -Force | Out-Null

    $exe = $BuildInfo.ExecutablePath
    $packageExe = Join-Path $PACKAGE_DIR "WiserOne.exe"

    # Copy main executable
    Copy-Item -Path $exe -Destination $packageExe
    Write-Success "Executable copied to package"

    # Use windeployqt for Qt deployment
    $qtPath = $(Test-BuildEnvironment).QtPath
    $windeployqt = Join-Path $qtPath "bin\windeployqt.exe"

    if (Test-Path $windeployqt) {
        $deployArgs = @(
            $packageExe
            "--$($BuildType.ToLower())"
            "--no-translations"  # We handle translations separately
            "--no-system-d3d-compiler"
            "--no-opengl-sw"
        )

        if ($Verbose) {
            $deployArgs += "--verbose", "2"
        }

        Invoke-ExternalCommand $windeployqt $deployArgs $PACKAGE_DIR
        Write-Success "Qt deployment completed"
    } else {
        Write-Warning "windeployqt not found - manual Qt deployment required"
    }

    # Copy Visual C++ Redistributables (if needed)
    $vcredistPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC"
    if (Test-Path $vcredistPath) {
        # Find latest redistributable version
        $latestVcredist = Get-ChildItem $vcredistPath | Sort-Object Name -Descending | Select-Object -First 1
        $redistDlls = Join-Path $latestVcredist.FullName "x64\Microsoft.VC143.CRT"

        if (Test-Path $redistDlls) {
            $redistFiles = Get-ChildItem $redistDlls -Filter "*.dll"
            foreach ($dll in $redistFiles) {
                Copy-Item $dll.FullName $PACKAGE_DIR
            }
            Write-Success "Visual C++ Redistributables copied"
        }
    }

    # Copy translations if they exist
    $translationsDir = Join-Path $PROJECT_ROOT "translations"
    if (Test-Path $translationsDir) {
        $packageTranslations = Join-Path $PACKAGE_DIR "translations"
        New-Item -ItemType Directory -Path $packageTranslations -Force | Out-Null

        $qmFiles = Get-ChildItem $translationsDir -Filter "*.qm"
        foreach ($qm in $qmFiles) {
            Copy-Item $qm.FullName $packageTranslations
        }
        Write-Success "Translations copied"
    }

    # Copy resources
    $resourcesDir = Join-Path $PROJECT_ROOT "resources"
    if (Test-Path $resourcesDir) {
        $packageResources = Join-Path $PACKAGE_DIR "resources"
        Copy-Item $resourcesDir $packageResources -Recurse
        Write-Success "Resources copied"
    }

    # Create installer manifest
    $manifest = @{
        Name = "WiserOne"
        Version = (Get-Content (Join-Path $PROJECT_ROOT "VERSION")).Trim()
        Architecture = $Architecture
        BuildType = $BuildType
        BuildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Dependencies = $QtDependencies
    } | ConvertTo-Json -Depth 3

    Set-Content (Join-Path $PACKAGE_DIR "manifest.json") $manifest
    Write-Success "Deployment manifest created"

    # Verify package
    $packageSize = (Get-ChildItem $PACKAGE_DIR -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Information "Package size: $([math]::Round($packageSize, 2)) MB"

    $packageFiles = (Get-ChildItem $PACKAGE_DIR -Recurse -File).Count
    Write-Information "Package files: $packageFiles"

    Write-Success "Windows deployment completed: $PACKAGE_DIR"

    return @{
        PackageDir = $PACKAGE_DIR
        PackageSize = $packageSize
        FileCount = $packageFiles
    }
}

# =============================================================================
# Security Validation
# =============================================================================
function Test-Security {
    param([hashtable]$BuildInfo)

    Write-Section "Security Validation"

    $exe = $BuildInfo.ExecutablePath

    # Check DEP (Data Execution Prevention)
    $vcvarsCmd = "call `"$($(Test-BuildEnvironment).VSPath)\VC\Auxiliary\Build\vcvars64.bat`" && dumpbin /headers `"$exe`""
    $headers = cmd /c $vcvarsCmd 2>&1

    if ($headers -match "NX compatible") {
        Write-Success "DEP (NX) protection enabled"
    } else {
        Write-Warning "DEP (NX) protection not detected"
    }

    # Check ASLR (Address Space Layout Randomization)
    if ($headers -match "Dynamic base") {
        Write-Success "ASLR protection enabled"
    } else {
        Write-Warning "ASLR protection not detected"
    }

    # Check Control Flow Guard
    if ($headers -match "Guard CF") {
        Write-Success "Control Flow Guard enabled"
    } else {
        Write-Information "Control Flow Guard not enabled (consider adding /guard:cf)"
    }

    # Check for debug information in release build
    if ($BuildType -eq "Release" -and ($headers -match "Debug Directories")) {
        Write-Warning "Debug information present in release build"
    } else {
        Write-Success "Release build properly stripped of debug info"
    }
}

# =============================================================================
# Performance Validation
# =============================================================================
function Test-Performance {
    param([hashtable]$BuildInfo)

    Write-Section "Performance Validation"

    $exe = $BuildInfo.ExecutablePath

    # Get file size
    $fileSize = (Get-Item $exe).Length / 1KB
    Write-Information "Executable size: $([math]::Round($fileSize, 2)) KB"

    if ($fileSize -gt 50000) {  # > 50MB
        Write-Warning "Large executable size detected - consider optimization"
    } else {
        Write-Success "Executable size within acceptable range"
    }

    # Check startup time (basic test)
    if (-not $SkipTests) {
        Write-Information "Testing startup performance..."
        $env:QT_QPA_PLATFORM = "offscreen"

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $process = Start-Process -FilePath $exe -ArgumentList "--version" -NoNewWindow -PassThru -Wait
            $stopwatch.Stop()

            if ($process.ExitCode -eq 0) {
                $startupTime = $stopwatch.ElapsedMilliseconds
                Write-Information "Startup time: ${startupTime}ms"

                if ($startupTime -gt 5000) {
                    Write-Warning "Slow startup detected (>5s)"
                } else {
                    Write-Success "Startup performance acceptable"
                }
            }
        } catch {
            Write-Warning "Could not measure startup time: $_"
        }
    }
}

# =============================================================================
# Main Execution
# =============================================================================
function Main {
    Write-Host "Windows Build Verification Script" -ForegroundColor $ColorInfo
    Write-Host "=================================" -ForegroundColor $ColorInfo
    Write-Host "Build Type: $BuildType" -ForegroundColor $ColorInfo
    Write-Host "Architecture: $Architecture" -ForegroundColor $ColorInfo
    Write-Host "Qt Version: $QtVersion" -ForegroundColor $ColorInfo
    Write-Host ""

    try {
        # Skip build if package-only mode
        if ($PackageOnly) {
            $buildInfo = @{
                BuildDir = $BUILD_DIR
                ExecutablePath = Join-Path $BUILD_DIR "$BuildType\WiserOne.exe"
            }

            if (-not (Test-Path $buildInfo.ExecutablePath)) {
                throw "Package-only mode requires existing build. Run without -PackageOnly first."
            }
        } else {
            # Full verification process
            Test-BuildEnvironment | Out-Null
            Test-MSVCCompiler
            Test-WindowsAPICompatibility
            $buildInfo = Invoke-Build
            Invoke-Tests $buildInfo
            Test-Security $buildInfo
            Test-Performance $buildInfo
        }

        # Dependency analysis and deployment
        $qtDeps = Test-Dependencies $buildInfo
        $packageInfo = Invoke-Deployment $buildInfo $qtDeps

        Write-Section "Verification Complete"
        Write-Success "All checks passed successfully"
        Write-Success "Package ready: $($packageInfo.PackageDir)"
        Write-Information "Package size: $([math]::Round($packageInfo.PackageSize, 2)) MB"
        Write-Information "File count: $($packageInfo.FileCount)"

        return 0

    } catch {
        Write-Section "Verification Failed"
        Write-Error $_.Exception.Message
        if ($Verbose) {
            Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
        }
        return 1
    }
}

# Execute main function
exit (Main)