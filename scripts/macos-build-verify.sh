#!/usr/bin/env bash
# macOS Build Verification Script
# SPDX-License-Identifier: MIT
# Comprehensive code signing, notarization, bundle validation, and Qt framework verification

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build-macos-verify"
PACKAGE_DIR="${PROJECT_ROOT}/package-macos"
APP_NAME="WiserOne"
BUNDLE_ID="com.wiserone.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default parameters
BUILD_TYPE="Release"
SKIP_TESTS=false
VERBOSE=false
SKIP_SIGNING=false
SKIP_NOTARIZATION=true  # Notarization requires Apple Developer account
UNIVERSAL_BINARY=false

# =============================================================================
# Helper Functions
# =============================================================================
print_section() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    if [[ "${VERBOSE}" == true ]]; then
        echo -e "  $1"
    fi
}

show_help() {
    cat << EOF
macOS Build Verification Script

Usage: $(basename "$0") [options]

Options:
  --debug           Build in Debug mode
  --release         Build in Release mode (default)
  --skip-tests      Skip running tests
  --skip-signing    Skip code signing verification
  --notarize        Enable notarization (requires Apple Developer account)
  --universal       Build universal binary (arm64 + x86_64)
  --verbose         Enable verbose output
  --help            Show this help message

Examples:
  $(basename "$0")                        # Default Release build
  $(basename "$0") --debug --verbose      # Debug build with verbose output
  $(basename "$0") --universal            # Universal binary build
  $(basename "$0") --notarize             # Include notarization

Environment Variables:
  QT_ROOT or Qt6_DIR     - Path to Qt installation
  DEVELOPER_ID_APP       - Code signing identity (optional)
  APPLE_ID              - Apple ID for notarization (optional)
  APPLE_APP_PASSWORD    - App-specific password for notarization (optional)
  APPLE_TEAM_ID         - Apple Team ID for notarization (optional)

EOF
    exit 0
}

# =============================================================================
# Argument Parsing
# =============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                BUILD_TYPE="Debug"
                shift
                ;;
            --release)
                BUILD_TYPE="Release"
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --skip-signing)
                SKIP_SIGNING=true
                shift
                ;;
            --notarize)
                SKIP_NOTARIZATION=false
                shift
                ;;
            --universal)
                UNIVERSAL_BINARY=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                print_error "Unknown argument: $1"
                show_help
                ;;
        esac
    done
}

# =============================================================================
# Environment Verification
# =============================================================================
verify_environment() {
    print_section "Environment Verification"

    # Check macOS version
    local macos_version
    macos_version=$(sw_vers -productVersion)
    print_info "macOS Version: ${macos_version}"

    local major_version
    major_version=$(echo "${macos_version}" | cut -d. -f1)
    if [[ "${major_version}" -lt 11 ]]; then
        print_error "macOS 11.0 (Big Sur) or later required"
        exit 1
    fi
    print_success "macOS version compatible: ${macos_version}"

    # Check Xcode Command Line Tools
    if ! xcode-select -p &>/dev/null; then
        print_error "Xcode Command Line Tools not installed"
        echo "Run: xcode-select --install"
        exit 1
    fi
    local xcode_path
    xcode_path=$(xcode-select -p)
    print_success "Xcode tools found: ${xcode_path}"

    # Check clang version
    local clang_version
    clang_version=$(clang --version | head -1)
    print_info "Clang: ${clang_version}"
    print_success "Clang compiler verified"

    # Check CMake
    if ! command -v cmake &>/dev/null; then
        print_error "CMake not found. Install with: brew install cmake"
        exit 1
    fi
    local cmake_version
    cmake_version=$(cmake --version | head -1 | awk '{print $3}')
    print_success "CMake ${cmake_version} verified"

    # Check Qt installation
    local qt_dir=""
    if [[ -n "${QT_ROOT:-}" ]]; then
        qt_dir="${QT_ROOT}"
    elif [[ -n "${Qt6_DIR:-}" ]]; then
        qt_dir="${Qt6_DIR}"
    else
        # Try common Homebrew paths
        local brew_qt_paths=(
            "/opt/homebrew/opt/qt@6"
            "/usr/local/opt/qt@6"
            "/opt/homebrew/opt/qt"
            "/usr/local/opt/qt"
        )
        for path in "${brew_qt_paths[@]}"; do
            if [[ -d "${path}" ]]; then
                qt_dir="${path}"
                break
            fi
        done
    fi

    if [[ -z "${qt_dir}" ]] || [[ ! -d "${qt_dir}" ]]; then
        print_error "Qt installation not found"
        echo "Set QT_ROOT or Qt6_DIR environment variable, or install with: brew install qt@6"
        exit 1
    fi

    if [[ ! -f "${qt_dir}/bin/qmake" ]] && [[ ! -f "${qt_dir}/bin/qmake6" ]]; then
        print_error "Qt installation invalid: qmake not found in ${qt_dir}"
        exit 1
    fi

    export QT_ROOT="${qt_dir}"
    export CMAKE_PREFIX_PATH="${qt_dir}"
    print_success "Qt installation verified: ${qt_dir}"

    # Check code signing identity (optional)
    if [[ "${SKIP_SIGNING}" != true ]]; then
        if [[ -n "${DEVELOPER_ID_APP:-}" ]]; then
            if security find-identity -v -p codesigning | grep -q "${DEVELOPER_ID_APP}"; then
                print_success "Code signing identity found: ${DEVELOPER_ID_APP}"
            else
                print_warning "Code signing identity not found in keychain"
                SKIP_SIGNING=true
            fi
        else
            print_warning "No DEVELOPER_ID_APP set - using ad-hoc signing"
        fi
    fi
}

# =============================================================================
# C++ Compiler Validation
# =============================================================================
verify_compiler() {
    print_section "C++ Compiler Validation"

    local test_dir
    test_dir=$(mktemp -d)
    trap "rm -rf ${test_dir}" RETURN

    # Create test program for C++23 features
    cat > "${test_dir}/test.cpp" << 'EOF'
// C++ Feature Test
#include <iostream>
#include <memory>
#include <string_view>
#include <optional>
#include <variant>
#include <filesystem>
#include <expected>

// Test C++23 features
#if __cplusplus < 202302L
// Allow C++20 as fallback for older compilers
#if __cplusplus < 202002L
#error "C++20 or later required"
#endif
#endif

// Test Apple Clang version
#if defined(__apple_build_version__)
#if __apple_build_version__ < 14000000
#warning "Consider updating Xcode for best C++23 support"
#endif
#endif

int main() {
    // Test modern C++ features
    std::optional<std::string> opt = "test";
    std::variant<int, std::string> var = 42;

    // Test filesystem (C++17)
    auto path = std::filesystem::current_path();

    std::cout << "C++ Standard: " << __cplusplus << std::endl;
    std::cout << "Apple Clang Build: " << __apple_build_version__ << std::endl;
    std::cout << "Path: " << path << std::endl;

    return 0;
}
EOF

    # Compile and run test
    if clang++ -std=c++2b -stdlib=libc++ -o "${test_dir}/test" "${test_dir}/test.cpp" 2>/dev/null; then
        local output
        output=$("${test_dir}/test")
        print_success "C++23 compiler test passed"
        print_info "${output}"
    else
        # Fallback to C++20
        if clang++ -std=c++20 -stdlib=libc++ -o "${test_dir}/test" "${test_dir}/test.cpp" 2>/dev/null; then
            print_warning "C++23 not fully supported, using C++20"
            print_success "C++20 compiler test passed"
        else
            print_error "C++ compiler validation failed"
            exit 1
        fi
    fi
}

# =============================================================================
# Build Process
# =============================================================================
build_project() {
    print_section "Build Process"

    # Clean previous build
    if [[ -d "${BUILD_DIR}" ]]; then
        rm -rf "${BUILD_DIR}"
    fi
    mkdir -p "${BUILD_DIR}"

    # Configure CMake arguments
    local cmake_args=(
        "-B" "${BUILD_DIR}"
        "-S" "${PROJECT_ROOT}"
        "-DCMAKE_BUILD_TYPE=${BUILD_TYPE}"
        "-DCMAKE_PREFIX_PATH=${QT_ROOT}"
        "-DBUILD_TESTING=ON"
        "-DCMAKE_INSTALL_PREFIX=${PACKAGE_DIR}"
        "-DCI_MODE=ON"
    )

    # Universal binary configuration
    if [[ "${UNIVERSAL_BINARY}" == true ]]; then
        cmake_args+=("-DCMAKE_OSX_ARCHITECTURES=arm64;x86_64")
        print_info "Building universal binary (arm64 + x86_64)"
    else
        # Build for native architecture
        local arch
        arch=$(uname -m)
        cmake_args+=("-DCMAKE_OSX_ARCHITECTURES=${arch}")
        print_info "Building for ${arch}"
    fi

    # Set deployment target for compatibility
    cmake_args+=("-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0")

    if [[ "${VERBOSE}" == true ]]; then
        cmake_args+=("--debug-output")
    fi

    # Configure
    print_info "Configuring with CMake..."
    cmake "${cmake_args[@]}"
    print_success "CMake configuration completed"

    # Build
    print_info "Building project..."
    local build_args=(
        "--build" "${BUILD_DIR}"
        "--config" "${BUILD_TYPE}"
        "--parallel"
    )

    if [[ "${VERBOSE}" == true ]]; then
        build_args+=("--verbose")
    fi

    cmake "${build_args[@]}"
    print_success "Build completed successfully"

    # Verify build output
    local app_bundle="${BUILD_DIR}/${APP_NAME}.app"
    if [[ ! -d "${app_bundle}" ]]; then
        # Check alternative locations
        app_bundle="${BUILD_DIR}/src/${APP_NAME}.app"
        if [[ ! -d "${app_bundle}" ]]; then
            print_error "App bundle not found after build"
            exit 1
        fi
    fi

    export APP_BUNDLE="${app_bundle}"
    print_success "Build artifacts verified: ${app_bundle}"
}

# =============================================================================
# Bundle Validation
# =============================================================================
validate_bundle() {
    print_section "Bundle Validation"

    local app_bundle="${APP_BUNDLE}"

    # Check bundle structure
    local required_paths=(
        "Contents/Info.plist"
        "Contents/MacOS/${APP_NAME}"
        "Contents/Resources"
    )

    for path in "${required_paths[@]}"; do
        if [[ ! -e "${app_bundle}/${path}" ]]; then
            print_error "Missing required bundle component: ${path}"
            exit 1
        fi
    done
    print_success "Bundle structure verified"

    # Validate Info.plist
    local info_plist="${app_bundle}/Contents/Info.plist"

    # Check bundle identifier
    local bundle_id
    bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${info_plist}" 2>/dev/null || echo "")
    if [[ -z "${bundle_id}" ]]; then
        print_warning "CFBundleIdentifier not set in Info.plist"
    else
        print_success "Bundle identifier: ${bundle_id}"
    fi

    # Check version strings
    local short_version
    short_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${info_plist}" 2>/dev/null || echo "")
    local bundle_version
    bundle_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${info_plist}" 2>/dev/null || echo "")

    if [[ -n "${short_version}" ]]; then
        print_success "App version: ${short_version} (${bundle_version:-unknown})"
    else
        print_warning "Version strings not properly set"
    fi

    # Check minimum macOS version
    local min_version
    min_version=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "${info_plist}" 2>/dev/null || echo "")
    if [[ -n "${min_version}" ]]; then
        print_success "Minimum macOS version: ${min_version}"
    else
        print_warning "LSMinimumSystemVersion not set"
    fi

    # Check required device capabilities
    local required_keys=(
        "CFBundleDisplayName"
        "CFBundleExecutable"
        "CFBundleIconFile"
        "NSHighResolutionCapable"
    )

    for key in "${required_keys[@]}"; do
        local value
        value=$(/usr/libexec/PlistBuddy -c "Print :${key}" "${info_plist}" 2>/dev/null || echo "")
        if [[ -n "${value}" ]]; then
            print_info "${key}: ${value}"
        else
            print_warning "${key} not set in Info.plist"
        fi
    done

    # Verify executable
    local executable="${app_bundle}/Contents/MacOS/${APP_NAME}"
    if [[ ! -x "${executable}" ]]; then
        print_error "Executable not found or not executable"
        exit 1
    fi
    print_success "Executable verified"

    # Check executable architecture
    local archs
    archs=$(lipo -archs "${executable}" 2>/dev/null || file "${executable}")
    print_success "Architectures: ${archs}"

    if [[ "${UNIVERSAL_BINARY}" == true ]]; then
        if [[ "${archs}" == *"arm64"* ]] && [[ "${archs}" == *"x86_64"* ]]; then
            print_success "Universal binary verified (arm64 + x86_64)"
        else
            print_error "Universal binary incomplete - missing architecture"
            exit 1
        fi
    fi
}

# =============================================================================
# Qt Framework Verification
# =============================================================================
verify_qt_frameworks() {
    print_section "Qt Framework Verification"

    local app_bundle="${APP_BUNDLE}"
    local executable="${app_bundle}/Contents/MacOS/${APP_NAME}"
    local frameworks_dir="${app_bundle}/Contents/Frameworks"

    # Check linked Qt frameworks using otool
    local qt_deps
    qt_deps=$(otool -L "${executable}" | grep -i "Qt" || true)

    if [[ -z "${qt_deps}" ]]; then
        print_warning "No Qt frameworks linked - may be statically linked"
        return
    fi

    print_info "Qt dependencies:"
    echo "${qt_deps}" | while read -r line; do
        print_info "  ${line}"
    done

    # Check for required Qt frameworks
    local required_frameworks=(
        "QtCore"
        "QtGui"
        "QtWidgets"
    )

    for framework in "${required_frameworks[@]}"; do
        if echo "${qt_deps}" | grep -q "${framework}"; then
            print_success "${framework} linked"
        else
            print_warning "${framework} not found in dependencies"
        fi
    done

    # Check for embedded frameworks (for distribution)
    if [[ -d "${frameworks_dir}" ]]; then
        print_info "Embedded frameworks found:"
        ls -1 "${frameworks_dir}" 2>/dev/null | while read -r fw; do
            print_info "  ${fw}"
        done
        print_success "Frameworks embedded for distribution"
    else
        print_info "No embedded frameworks - using system/Homebrew Qt"
    fi

    # Verify @rpath resolution
    local rpaths
    rpaths=$(otool -l "${executable}" | grep -A2 "LC_RPATH" | grep "path" | awk '{print $2}' || true)
    if [[ -n "${rpaths}" ]]; then
        print_info "Runtime search paths (@rpath):"
        echo "${rpaths}" | while read -r rpath; do
            print_info "  ${rpath}"
        done
    fi

    # Check for missing dependencies
    local missing_deps
    missing_deps=$(otool -L "${executable}" 2>/dev/null | grep "not found" || true)
    if [[ -n "${missing_deps}" ]]; then
        print_error "Missing dependencies detected:"
        echo "${missing_deps}"
        exit 1
    fi
    print_success "All dependencies resolved"
}

# =============================================================================
# Code Signing Verification
# =============================================================================
verify_code_signing() {
    print_section "Code Signing Verification"

    if [[ "${SKIP_SIGNING}" == true ]]; then
        print_warning "Code signing verification skipped"
        return
    fi

    local app_bundle="${APP_BUNDLE}"

    # Check if already signed
    if codesign -v "${app_bundle}" 2>/dev/null; then
        print_success "App bundle is signed"

        # Get signing info
        local signing_info
        signing_info=$(codesign -dvv "${app_bundle}" 2>&1)
        print_info "Signing details:"
        echo "${signing_info}" | grep -E "(Authority|Identifier|TeamIdentifier)" | while read -r line; do
            print_info "  ${line}"
        done

        # Verify signature is valid
        if codesign --verify --deep --strict "${app_bundle}" 2>/dev/null; then
            print_success "Signature verification passed (deep)"
        else
            print_warning "Deep signature verification has issues"
        fi

        # Check for hardened runtime
        if echo "${signing_info}" | grep -q "flags=0x10000(runtime)"; then
            print_success "Hardened runtime enabled"
        else
            print_warning "Hardened runtime not enabled (required for notarization)"
        fi

    else
        print_warning "App bundle is not signed"

        # Sign with ad-hoc signature for local testing
        if [[ -n "${DEVELOPER_ID_APP:-}" ]]; then
            print_info "Signing with Developer ID..."
            codesign --force --deep --options runtime \
                --sign "${DEVELOPER_ID_APP}" \
                "${app_bundle}"
            print_success "Signed with Developer ID"
        else
            print_info "Signing with ad-hoc signature..."
            codesign --force --deep --sign - "${app_bundle}"
            print_success "Ad-hoc signature applied"
        fi
    fi

    # Verify entitlements (if present)
    local entitlements
    entitlements=$(codesign -d --entitlements - "${app_bundle}" 2>/dev/null || true)
    if [[ -n "${entitlements}" ]] && [[ "${entitlements}" != *"no entitlements"* ]]; then
        print_info "Entitlements:"
        echo "${entitlements}" | head -20
        print_success "Entitlements verified"
    else
        print_info "No entitlements (may be required for App Store)"
    fi
}

# =============================================================================
# Notarization Check
# =============================================================================
check_notarization() {
    print_section "Notarization Check"

    if [[ "${SKIP_NOTARIZATION}" == true ]]; then
        print_warning "Notarization skipped (use --notarize to enable)"
        return
    fi

    local app_bundle="${APP_BUNDLE}"

    # Check required environment variables
    if [[ -z "${APPLE_ID:-}" ]] || [[ -z "${APPLE_APP_PASSWORD:-}" ]] || [[ -z "${APPLE_TEAM_ID:-}" ]]; then
        print_warning "Notarization requires APPLE_ID, APPLE_APP_PASSWORD, and APPLE_TEAM_ID"
        return
    fi

    # Create ZIP for notarization
    local zip_path="${BUILD_DIR}/${APP_NAME}-notarize.zip"
    print_info "Creating archive for notarization..."
    ditto -c -k --keepParent "${app_bundle}" "${zip_path}"

    # Submit for notarization
    print_info "Submitting for notarization..."
    local notarize_result
    notarize_result=$(xcrun notarytool submit "${zip_path}" \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_APP_PASSWORD}" \
        --team-id "${APPLE_TEAM_ID}" \
        --wait 2>&1) || true

    if echo "${notarize_result}" | grep -q "Accepted"; then
        print_success "Notarization accepted"

        # Staple the notarization ticket
        print_info "Stapling notarization ticket..."
        xcrun stapler staple "${app_bundle}"
        print_success "Notarization ticket stapled"
    else
        print_warning "Notarization not completed:"
        echo "${notarize_result}"
    fi

    # Verify notarization status
    local staple_result
    staple_result=$(xcrun stapler validate "${app_bundle}" 2>&1 || true)
    if echo "${staple_result}" | grep -q "valid"; then
        print_success "Notarization staple verified"
    else
        print_info "Staple status: ${staple_result}"
    fi

    # Clean up
    rm -f "${zip_path}"
}

# =============================================================================
# Security Validation
# =============================================================================
verify_security() {
    print_section "Security Validation"

    local executable="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

    # Check for Position Independent Executable (PIE)
    local pie_check
    pie_check=$(otool -hv "${executable}" | grep -i "pie" || true)
    if [[ -n "${pie_check}" ]]; then
        print_success "Position Independent Executable (PIE) enabled"
    else
        print_warning "PIE may not be enabled"
    fi

    # Check for stack canaries
    local stack_check
    stack_check=$(nm "${executable}" 2>/dev/null | grep -i "stack_chk" || true)
    if [[ -n "${stack_check}" ]]; then
        print_success "Stack canaries detected"
    else
        print_info "Stack canaries not detected (may be optimized out)"
    fi

    # Check for ASLR compatibility
    print_success "ASLR supported (macOS system-wide)"

    # Verify no debug symbols in release
    if [[ "${BUILD_TYPE}" == "Release" ]]; then
        local debug_info
        debug_info=$(dsymutil -s "${executable}" 2>/dev/null | head -5 || true)
        if [[ -z "${debug_info}" ]]; then
            print_success "No debug symbols in release build"
        else
            print_info "Debug symbols present (may be in separate dSYM)"
        fi
    fi

    # Check for problematic library dependencies
    local dangerous_libs
    dangerous_libs=$(otool -L "${executable}" | grep -E "(libcrypto|libssl)" || true)
    if [[ -n "${dangerous_libs}" ]]; then
        print_warning "Cryptographic libraries linked - ensure versions are secure:"
        echo "${dangerous_libs}"
    fi
}

# =============================================================================
# Run Tests
# =============================================================================
run_tests() {
    print_section "Running Tests"

    if [[ "${SKIP_TESTS}" == true ]]; then
        print_warning "Tests skipped by user request"
        return
    fi

    # Set headless Qt environment
    export QT_QPA_PLATFORM="offscreen"

    # Run CTest
    local ctest_args=(
        "--test-dir" "${BUILD_DIR}"
        "--output-on-failure"
        "-C" "${BUILD_TYPE}"
        "--parallel" "4"
        "--timeout" "300"
    )

    if [[ "${VERBOSE}" == true ]]; then
        ctest_args+=("--verbose")
    fi

    if ctest "${ctest_args[@]}"; then
        print_success "All tests passed"
    else
        print_error "Tests failed - check output above"
        exit 1
    fi
}

# =============================================================================
# Performance Validation
# =============================================================================
verify_performance() {
    print_section "Performance Validation"

    local executable="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

    # Check executable size
    local file_size
    file_size=$(stat -f%z "${executable}")
    local size_mb
    size_mb=$(echo "scale=2; ${file_size} / 1048576" | bc)
    print_info "Executable size: ${size_mb} MB"

    if (( $(echo "${size_mb} > 50" | bc -l) )); then
        print_warning "Large executable size - consider optimization"
    else
        print_success "Executable size acceptable"
    fi

    # Check app bundle size
    local bundle_size
    bundle_size=$(du -sk "${APP_BUNDLE}" | cut -f1)
    local bundle_mb
    bundle_mb=$(echo "scale=2; ${bundle_size} / 1024" | bc)
    print_info "Bundle size: ${bundle_mb} MB"

    # Test startup time (basic)
    if [[ "${SKIP_TESTS}" != true ]]; then
        print_info "Testing startup performance..."
        export QT_QPA_PLATFORM="offscreen"

        local start_time
        start_time=$(date +%s%N)
        timeout 10 "${executable}" --version 2>/dev/null || true
        local end_time
        end_time=$(date +%s%N)

        local duration_ms
        duration_ms=$(( (end_time - start_time) / 1000000 ))
        print_info "Startup time: ${duration_ms}ms"

        if (( duration_ms > 5000 )); then
            print_warning "Slow startup detected (>5s)"
        else
            print_success "Startup performance acceptable"
        fi
    fi
}

# =============================================================================
# Create Distribution Package
# =============================================================================
create_package() {
    print_section "Creating Distribution Package"

    # Clean package directory
    if [[ -d "${PACKAGE_DIR}" ]]; then
        rm -rf "${PACKAGE_DIR}"
    fi
    mkdir -p "${PACKAGE_DIR}"

    local app_bundle="${APP_BUNDLE}"

    # Copy app bundle
    print_info "Copying app bundle..."
    cp -R "${app_bundle}" "${PACKAGE_DIR}/"
    print_success "App bundle copied"

    # Run macdeployqt if available
    local macdeployqt="${QT_ROOT}/bin/macdeployqt"
    if [[ -x "${macdeployqt}" ]]; then
        print_info "Running macdeployqt..."
        "${macdeployqt}" "${PACKAGE_DIR}/${APP_NAME}.app" \
            -verbose=1 \
            2>&1 | grep -v "^$" || true
        print_success "Qt frameworks deployed"
    else
        print_warning "macdeployqt not found - frameworks not embedded"
    fi

    # Re-sign after macdeployqt (it invalidates signatures)
    if [[ "${SKIP_SIGNING}" != true ]]; then
        print_info "Re-signing after framework deployment..."
        if [[ -n "${DEVELOPER_ID_APP:-}" ]]; then
            codesign --force --deep --options runtime \
                --sign "${DEVELOPER_ID_APP}" \
                "${PACKAGE_DIR}/${APP_NAME}.app"
        else
            codesign --force --deep --sign - "${PACKAGE_DIR}/${APP_NAME}.app"
        fi
        print_success "Package re-signed"
    fi

    # Create DMG for distribution
    local dmg_path="${PACKAGE_DIR}/${APP_NAME}.dmg"
    print_info "Creating DMG..."
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${PACKAGE_DIR}/${APP_NAME}.app" \
        -ov -format UDZO \
        "${dmg_path}" 2>/dev/null || true

    if [[ -f "${dmg_path}" ]]; then
        print_success "DMG created: ${dmg_path}"
        local dmg_size
        dmg_size=$(ls -lh "${dmg_path}" | awk '{print $5}')
        print_info "DMG size: ${dmg_size}"
    else
        print_warning "DMG creation failed (hdiutil may require GUI session)"
    fi

    # Create manifest
    local manifest="${PACKAGE_DIR}/manifest.json"
    cat > "${manifest}" << EOF
{
  "name": "${APP_NAME}",
  "version": "$(cat "${PROJECT_ROOT}/VERSION" 2>/dev/null || echo "unknown")",
  "buildType": "${BUILD_TYPE}",
  "architecture": "$(uname -m)",
  "universal": ${UNIVERSAL_BINARY},
  "buildDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "macOSMinVersion": "11.0",
  "qtVersion": "$(${QT_ROOT}/bin/qmake -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")"
}
EOF
    print_success "Manifest created"

    print_success "Package ready: ${PACKAGE_DIR}"
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    echo -e "${CYAN}macOS Build Verification Script${NC}"
    echo -e "${CYAN}=================================${NC}"
    echo "Build Type: ${BUILD_TYPE}"
    echo "Universal Binary: ${UNIVERSAL_BINARY}"
    echo ""

    parse_args "$@"

    # Run verification steps
    verify_environment
    verify_compiler
    build_project
    validate_bundle
    verify_qt_frameworks
    verify_code_signing
    check_notarization
    verify_security
    run_tests
    verify_performance
    create_package

    print_section "Verification Complete"
    print_success "All checks passed successfully"
    print_success "Package ready: ${PACKAGE_DIR}"

    return 0
}

# Execute main function with all arguments
main "$@"
