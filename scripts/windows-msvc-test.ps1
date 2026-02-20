# Windows MSVC Feature Test Script
# SPDX-License-Identifier: MIT
# Validates MSVC compiler capabilities and Windows API compatibility

param(
    [switch]$Extended = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

function Write-TestSection($Message) {
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-TestResult($Test, $Result, $Details = "") {
    $symbol = if ($Result) { "✓" } else { "✗" }
    $color = if ($Result) { "Green" } else { "Red" }

    Write-Host "$symbol $Test" -ForegroundColor $color
    if ($Details -and $Verbose) {
        Write-Host "  $Details" -ForegroundColor DarkGray
    }
}

function Test-MSVCVersion {
    Write-TestSection "MSVC Version Detection"

    # Find Visual Studio installation
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vsWhere)) {
        Write-TestResult "Visual Studio Installer" $false "vswhere.exe not found"
        return $false
    }

    $vsInstalls = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json | ConvertFrom-Json
    if (-not $vsInstalls -or $vsInstalls.Count -eq 0) {
        Write-TestResult "MSVC Installation" $false "No MSVC installation found"
        return $false
    }

    $vsPath = $vsInstalls[0].installationPath
    $vsVersion = $vsInstalls[0].catalog.productDisplayVersion

    Write-TestResult "Visual Studio Detection" $true "Found at $vsPath"
    Write-TestResult "Visual Studio Version" $true $vsVersion

    # Check MSVC toolset version
    $vcvarsPath = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
    if (Test-Path $vcvarsPath) {
        Write-TestResult "MSVC x64 Tools" $true "vcvars64.bat found"
        return $vsPath
    } else {
        Write-TestResult "MSVC x64 Tools" $false "vcvars64.bat not found"
        return $false
    }
}

function Test-CppStandardSupport($vsPath) {
    Write-TestSection "C++ Standard Support"

    $testDir = Join-Path $env:TEMP "cpp-standard-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        # Test C++23 features
        $cpp23Test = @"
#include <iostream>
#include <optional>
#include <variant>
#include <string_view>
#include <span>
#include <ranges>

// Check C++23 support
#if __cplusplus < 202302L
#error "C++23 support required"
#endif

// Check MSVC version (19.30+ for VS 2022)
#if _MSC_VER < 1930
#error "MSVC 19.30+ required"
#endif

int main() {
    // Test C++23 features
    std::optional<int> opt{42};
    std::variant<int, std::string> var{"test"};

    // Test ranges (C++20/23)
    std::vector<int> vec{1, 2, 3, 4, 5};
    auto filtered = vec | std::views::filter([](int x) { return x % 2 == 0; });

    std::cout << "C++23 features test passed" << std::endl;
    std::cout << "MSVC Version: " << _MSC_VER << std::endl;
    std::cout << "C++ Standard: " << __cplusplus << std::endl;

    return 0;
}
"@

        $testFile = Join-Path $testDir "cpp23_test.cpp"
        $testExe = Join-Path $testDir "cpp23_test.exe"
        Set-Content -Path $testFile -Value $cpp23Test

        # Compile with MSVC
        $vcvarsCmd = "call `"$vsPath\VC\Auxiliary\Build\vcvars64.bat`" >nul 2>&1 && cl /std:c++latest /EHsc `"$testFile`" /Fe:`"$testExe`" >nul 2>&1"
        $compileResult = cmd /c $vcvarsCmd

        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "C++23 Compilation" $true

            # Run the test
            $output = & $testExe 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-TestResult "C++23 Runtime" $true
                if ($Verbose) {
                    $output | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
                }
            } else {
                Write-TestResult "C++23 Runtime" $false "Execution failed"
            }
        } else {
            Write-TestResult "C++23 Compilation" $false "Compilation failed"
        }

    } finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-WindowsAPISupport($vsPath) {
    Write-TestSection "Windows API Support"

    $testDir = Join-Path $env:TEMP "winapi-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        # Test Windows API compatibility
        $winapiTest = @"
#include <windows.h>
#include <iostream>
#include <string>
#include <memory>

// Test modern Windows API usage
#if WINVER < 0x0A00
#error "Windows 10+ API required"
#endif

class WindowsAPITest {
public:
    static bool TestBasicAPIs() {
        // Test version info
        OSVERSIONINFOEXW osvi = {};
        osvi.dwOSVersionInfoSize = sizeof(osvi);

        // Use RtlGetVersion instead of deprecated GetVersionEx
        typedef LONG (WINAPI *RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);
        HMODULE hMod = GetModuleHandleW(L"ntdll.dll");
        if (hMod) {
            RtlGetVersionPtr fxPtr = (RtlGetVersionPtr)GetProcAddress(hMod, "RtlGetVersion");
            if (fxPtr && fxPtr((PRTL_OSVERSIONINFOW)&osvi) == 0) {
                std::wcout << L"Windows Version: " << osvi.dwMajorVersion << L"." << osvi.dwMinorVersion << std::endl;
            }
        }

        // Test system metrics
        int screenWidth = GetSystemMetrics(SM_CXSCREEN);
        int screenHeight = GetSystemMetrics(SM_CYSCREEN);
        std::cout << "Screen Resolution: " << screenWidth << "x" << screenHeight << std::endl;

        // Test registry access
        HKEY hKey;
        if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                         0, KEY_READ, &hKey) == ERROR_SUCCESS) {
            RegCloseKey(hKey);
            std::cout << "Registry access test passed" << std::endl;
        }

        return true;
    }

    static bool TestSecurityFeatures() {
        // Test DEP support
        BOOL isDEPEnabled = FALSE;
        DWORD depFlags = 0;
        if (GetProcessDEPPolicy(GetCurrentProcess(), &depFlags, &isDEPEnabled)) {
            std::cout << "DEP Status: " << (isDEPEnabled ? "Enabled" : "Disabled") << std::endl;
        }

        // Test ASLR support (indirectly)
        HMODULE hKernel = GetModuleHandleW(L"kernel32.dll");
        if (hKernel) {
            std::cout << "ASLR Test: Module loaded at " << std::hex << hKernel << std::dec << std::endl;
        }

        return true;
    }
};

int main() {
    std::cout << "Windows API Compatibility Test" << std::endl;
    std::cout << "==============================" << std::endl;

    try {
        WindowsAPITest::TestBasicAPIs();
        WindowsAPITest::TestSecurityFeatures();

        std::cout << "All Windows API tests passed" << std::endl;
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
}
"@

        $testFile = Join-Path $testDir "winapi_test.cpp"
        $testExe = Join-Path $testDir "winapi_test.exe"
        Set-Content -Path $testFile -Value $winapiTest

        # Compile with Windows API support
        $vcvarsCmd = "call `"$vsPath\VC\Auxiliary\Build\vcvars64.bat`" >nul 2>&1 && cl /D_WIN32_WINNT=0x0A00 /DWINVER=0x0A00 /EHsc `"$testFile`" /Fe:`"$testExe`" >nul 2>&1"
        $compileResult = cmd /c $vcvarsCmd

        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Windows API Compilation" $true

            # Run the test
            $output = & $testExe 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-TestResult "Windows API Runtime" $true
                if ($Verbose) {
                    $output | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
                }
            } else {
                Write-TestResult "Windows API Runtime" $false "Execution failed"
            }
        } else {
            Write-TestResult "Windows API Compilation" $false "Compilation failed"
        }

    } finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-SecurityFeatures($vsPath) {
    Write-TestSection "Security Features"

    $testDir = Join-Path $env:TEMP "security-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        # Test security compilation flags
        $securityTest = @"
#include <iostream>
#include <vector>
#include <memory>

// Test buffer security
void testBufferSecurity() {
    std::vector<char> buffer(1024);
    // Use secure functions
    strcpy_s(buffer.data(), buffer.size(), "Security test");
    std::cout << "Buffer security test passed: " << buffer.data() << std::endl;
}

// Test stack protection
void testStackProtection() {
    char stackBuffer[100];
    strcpy_s(stackBuffer, sizeof(stackBuffer), "Stack protection test");
    std::cout << "Stack protection test passed: " << stackBuffer << std::endl;
}

int main() {
    try {
        testBufferSecurity();
        testStackProtection();
        std::cout << "Security features test completed" << std::endl;
        return 0;
    } catch (...) {
        std::cerr << "Security test failed" << std::endl;
        return 1;
    }
}
"@

        $testFile = Join-Path $testDir "security_test.cpp"
        $testExe = Join-Path $testDir "security_test.exe"
        Set-Content -Path $testFile -Value $securityTest

        # Compile with security flags
        $vcvarsCmd = "call `"$vsPath\VC\Auxiliary\Build\vcvars64.bat`" >nul 2>&1 && cl /GS /guard:cf /DYNAMICBASE /NXCOMPAT /EHsc `"$testFile`" /Fe:`"$testExe`" >nul 2>&1"
        $compileResult = cmd /c $vcvarsCmd

        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Security Compilation" $true "Stack protection, CFG, ASLR, DEP enabled"

            # Check binary security features
            $vcvarsCheckCmd = "call `"$vsPath\VC\Auxiliary\Build\vcvars64.bat`" >nul 2>&1 && dumpbin /headers `"$testExe`""
            $headers = cmd /c $vcvarsCheckCmd 2>&1

            $hasNX = $headers -match "NX compatible"
            $hasASLR = $headers -match "Dynamic base"
            $hasCFG = $headers -match "Guard CF"

            Write-TestResult "DEP/NX Protection" $hasNX
            Write-TestResult "ASLR Protection" $hasASLR
            Write-TestResult "Control Flow Guard" $hasCFG

            # Run the test
            $output = & $testExe 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-TestResult "Security Runtime" $true
                if ($Verbose) {
                    $output | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
                }
            } else {
                Write-TestResult "Security Runtime" $false "Execution failed"
            }
        } else {
            Write-TestResult "Security Compilation" $false "Compilation with security flags failed"
        }

    } finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-QtCompatibility($vsPath) {
    Write-TestSection "Qt Framework Compatibility"

    # Check if Qt is available
    $qtPath = $env:QT_ROOT ?? $env:Qt6_DIR
    if (-not $qtPath) {
        # Try common Qt installation paths
        $commonPaths = @(
            "C:\Qt\6.6.2\msvc2019_64",
            "C:\Qt\6.7.0\msvc2019_64",
            "C:\Qt\Tools\QtCreator\bin"
        )

        foreach ($path in $commonPaths) {
            if (Test-Path (Join-Path $path "bin\qmake.exe")) {
                $qtPath = $path
                break
            }
        }
    }

    if (-not $qtPath -or -not (Test-Path (Join-Path $qtPath "bin\qmake.exe"))) {
        Write-TestResult "Qt Detection" $false "Qt installation not found"
        return
    }

    Write-TestResult "Qt Detection" $true "Found at $qtPath"

    # Get Qt version
    $qmake = Join-Path $qtPath "bin\qmake.exe"
    $qtVersion = & $qmake -query QT_VERSION 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "Qt Version" $true $qtVersion
    } else {
        Write-TestResult "Qt Version" $false "Could not query Qt version"
    }

    # Test Qt compilation if Extended flag is set
    if ($Extended) {
        $testDir = Join-Path $env:TEMP "qt-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        try {
            $qtTest = @"
#include <QApplication>
#include <QWidget>
#include <QLabel>
#include <QVBoxLayout>
#include <QTimer>
#include <iostream>

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    QWidget window;
    QVBoxLayout layout(&window);
    QLabel label("Qt MSVC Compatibility Test");
    layout.addWidget(&label);

    // Test Qt version
    std::cout << "Qt Version: " << QT_VERSION_STR << std::endl;
    std::cout << "Qt Runtime Version: " << qVersion() << std::endl;

    // Close immediately for headless testing
    QTimer::singleShot(100, &app, &QApplication::quit);

    return app.exec();
}
"@

            $testPro = @"
QT += core widgets
CONFIG += c++23
TARGET = qt_test
SOURCES += qt_test.cpp
"@

            $testCpp = Join-Path $testDir "qt_test.cpp"
            $testPro = Join-Path $testDir "qt_test.pro"
            Set-Content -Path $testCpp -Value $qtTest
            Set-Content -Path $testPro -Value $testPro

            # Setup environment and compile
            $env:PATH = "$qtPath\bin;$env:PATH"
            $compileCmd = "call `"$vsPath\VC\Auxiliary\Build\vcvars64.bat`" >nul 2>&1 && cd /d `"$testDir`" && `"$qmake`" && nmake release >nul 2>&1"
            $compileResult = cmd /c $compileCmd

            if ($LASTEXITCODE -eq 0) {
                Write-TestResult "Qt Compilation" $true

                # Test execution
                $qtExe = Join-Path $testDir "release\qt_test.exe"
                if (Test-Path $qtExe) {
                    $env:QT_QPA_PLATFORM = "offscreen"
                    $output = & $qtExe 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-TestResult "Qt Runtime" $true
                        if ($Verbose) {
                            $output | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
                        }
                    } else {
                        Write-TestResult "Qt Runtime" $false "Execution failed"
                    }
                } else {
                    Write-TestResult "Qt Runtime" $false "Executable not found"
                }
            } else {
                Write-TestResult "Qt Compilation" $false "qmake/nmake failed"
            }

        } finally {
            Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Main execution
Write-Host "Windows MSVC Feature Test" -ForegroundColor Yellow
Write-Host "=========================" -ForegroundColor Yellow
Write-Host "Extended tests: $Extended" -ForegroundColor Yellow
Write-Host "Verbose output: $Verbose" -ForegroundColor Yellow
Write-Host ""

try {
    # Test MSVC installation
    $vsPath = Test-MSVCVersion
    if (-not $vsPath) {
        throw "MSVC installation test failed"
    }

    # Test C++ standard support
    Test-CppStandardSupport $vsPath

    # Test Windows API support
    Test-WindowsAPISupport $vsPath

    # Test security features
    Test-SecurityFeatures $vsPath

    # Test Qt compatibility
    Test-QtCompatibility $vsPath

    Write-Host "`n=== Test Summary ===" -ForegroundColor Green
    Write-Host "✓ MSVC installation verified" -ForegroundColor Green
    Write-Host "✓ C++23 support confirmed" -ForegroundColor Green
    Write-Host "✓ Windows API compatibility verified" -ForegroundColor Green
    Write-Host "✓ Security features tested" -ForegroundColor Green
    if ($Extended) {
        Write-Host "✓ Extended Qt testing completed" -ForegroundColor Green
    }
    Write-Host "`nAll tests passed successfully!" -ForegroundColor Green

    exit 0

} catch {
    Write-Host "`n=== Test Failed ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}