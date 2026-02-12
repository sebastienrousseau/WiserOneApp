@echo off
REM Windows Build Verification Batch Wrapper
REM SPDX-License-Identifier: MIT
REM Provides batch file interface to PowerShell verification script

setlocal EnableDelayedExpansion

REM Default parameters
set "BUILD_TYPE=Release"
set "ARCHITECTURE=x64"
set "QT_VERSION=6.6.2"
set "SKIP_TESTS="
set "VERBOSE="
set "PACKAGE_ONLY="

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :execute
if /i "%~1"=="--debug" (
    set "BUILD_TYPE=Debug"
    shift
    goto :parse_args
)
if /i "%~1"=="--release" (
    set "BUILD_TYPE=Release"
    shift
    goto :parse_args
)
if /i "%~1"=="--x86" (
    set "ARCHITECTURE=x86"
    shift
    goto :parse_args
)
if /i "%~1"=="--x64" (
    set "ARCHITECTURE=x64"
    shift
    goto :parse_args
)
if /i "%~1"=="--skip-tests" (
    set "SKIP_TESTS=-SkipTests"
    shift
    goto :parse_args
)
if /i "%~1"=="--verbose" (
    set "VERBOSE=-Verbose"
    shift
    goto :parse_args
)
if /i "%~1"=="--package-only" (
    set "PACKAGE_ONLY=-PackageOnly"
    shift
    goto :parse_args
)
if /i "%~1"=="--qt-version" (
    shift
    set "QT_VERSION=%~1"
    shift
    goto :parse_args
)
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="/?" goto :show_help

echo Unknown argument: %~1
goto :show_help

:execute
echo Windows Build Verification
echo ==========================
echo Build Type: %BUILD_TYPE%
echo Architecture: %ARCHITECTURE%
echo Qt Version: %QT_VERSION%
echo.

REM Check PowerShell availability
powershell -Command "exit 0" >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo ERROR: PowerShell is required but not available
    echo Please install PowerShell 5.0 or later
    exit /b 1
)

REM Get script directory
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%windows-build-verify.ps1"

REM Check if PowerShell script exists
if not exist "%PS_SCRIPT%" (
    echo ERROR: PowerShell script not found: %PS_SCRIPT%
    exit /b 1
)

REM Execute PowerShell script with parameters
powershell -ExecutionPolicy Bypass -File "%PS_SCRIPT%" ^
    -BuildType "%BUILD_TYPE%" ^
    -Architecture "%ARCHITECTURE%" ^
    -QtVersion "%QT_VERSION%" ^
    %SKIP_TESTS% %VERBOSE% %PACKAGE_ONLY%

exit /b %ERRORLEVEL%

:show_help
echo Windows Build Verification Script
echo.
echo Usage: %~n0 [options]
echo.
echo Options:
echo   --debug           Build in Debug mode
echo   --release         Build in Release mode (default)
echo   --x86             Target x86 architecture
echo   --x64             Target x64 architecture (default)
echo   --qt-version VER  Specify Qt version (default: 6.6.2)
echo   --skip-tests      Skip running tests
echo   --verbose         Enable verbose output
echo   --package-only    Only package existing build
echo   --help            Show this help message
echo.
echo Examples:
echo   %~n0                           # Default Release x64 build
echo   %~n0 --debug --verbose         # Debug build with verbose output
echo   %~n0 --skip-tests              # Skip testing phase
echo   %~n0 --package-only            # Package existing build only
echo.
echo Environment Variables:
echo   QT_ROOT or Qt6_DIR  - Path to Qt installation
echo   CMAKE_PREFIX_PATH   - Additional CMake search paths
echo.
exit /b 0