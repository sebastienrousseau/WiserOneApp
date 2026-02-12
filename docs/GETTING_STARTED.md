# Getting Started with The Wiser One

This guide will help you set up, build, and run The Wiser One application from source.

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Software

- **Qt6** 6.2+ with the following modules:
  - Core, Widgets, Svg, SvgWidgets
  - LinguistTools (optional, for translations)
- **CMake** 3.16 or later
- **C++23** compatible compiler:
  - GCC 13+ (Linux)
  - Clang 17+ (macOS/Linux)
  - MSVC 19.36+ (Windows, Visual Studio 2022)

### Platform-Specific Dependencies

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install qt6-base-dev qt6-svg-dev qt6-l10n-tools cmake build-essential libgl1-mesa-dev
```

#### Fedora
```bash
sudo dnf install qt6-qtbase-devel qt6-qtsvg-devel qt6-linguist cmake gcc-c++
```

#### Arch Linux
```bash
sudo pacman -S qt6-base qt6-svg qt6-tools cmake
```

#### macOS (Homebrew)
```bash
brew install qt6 cmake
```

#### Windows
1. Install [Qt6](https://www.qt.io/download-qt-installer) (select Desktop components)
2. Install [CMake](https://cmake.org/download/)
3. Install Visual Studio 2022 with C++ development tools

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/sebastienrousseau/WiserOneApp.git
cd WiserOneApp
```

### 2. Build the Application

```bash
# Create and enter build directory
mkdir build && cd build

# Configure the build
cmake .. -DCMAKE_BUILD_TYPE=Release

# Build the application
cmake --build . --parallel $(nproc)
```

### 3. Run Tests

```bash
# From the build directory
ctest --output-on-failure
```

### 4. Launch the Application

```bash
# From the build directory
./wiserone
```

The application will appear in your system tray. Click the tray icon to see a quote!

## Build Configuration Options

### Debug Build

For development work:

```bash
cmake .. -DCMAKE_BUILD_TYPE=Debug
cmake --build .
```

### Custom Install Prefix

To install to a custom location:

```bash
cmake .. -DCMAKE_INSTALL_PREFIX=/your/custom/path
cmake --build .
cmake --install .
```

### Advanced Options

```bash
# Enable verbose build output
cmake --build . --verbose

# Build specific target
cmake --build . --target wiserone

# Clean build
cmake --build . --target clean
```

## Troubleshooting

### Common Issues

#### Qt6 Not Found

**Error**: `Could NOT find Qt6 (missing: Qt6_DIR)`

**Solution**: Set Qt6 path manually:
```bash
# Linux/macOS
cmake .. -DQt6_DIR=/path/to/qt6/lib/cmake/Qt6

# Example paths:
# Ubuntu: -DQt6_DIR=/usr/lib/x86_64-linux-gnu/cmake/Qt6
# Homebrew: -DQt6_DIR=/opt/homebrew/lib/cmake/Qt6
# Windows: -DQt6_DIR=C:/Qt/6.5.0/msvc2022_64/lib/cmake/Qt6
```

#### C++23 Not Supported

**Error**: Compiler doesn't support C++23

**Solutions**:
- Update your compiler (GCC 13+, Clang 17+)
- Use a newer toolchain
- On older systems, consider using a container/Docker

#### LinguistTools Missing

**Warning**: `Could NOT find Qt6LinguistTools`

**Solutions**:
```bash
# Ubuntu/Debian
sudo apt install qt6-l10n-tools

# Fedora
sudo dnf install qt6-linguist

# This is optional - app works without translations
```

#### System Tray Unavailable

**Issue**: Application starts but no tray icon appears

**Common causes**:
- No system tray support (some Linux environments)
- Desktop environment doesn't support tray icons
- Wayland compositor without tray support

**Solutions**:
```bash
# Check if tray is available
echo $XDG_CURRENT_DESKTOP
# For GNOME, install extensions like TopIcons Plus

# Force X11 on Wayland (temporary)
GDK_BACKEND=x11 ./wiserone
```

### Build on Specific Platforms

#### Ubuntu 20.04/22.04

```bash
# Install dependencies
sudo apt install qt6-base-dev qt6-svg-dev cmake build-essential

# Build with system Qt6
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

#### macOS with Xcode

```bash
# Install dependencies
brew install qt6 cmake

# Generate Xcode project
mkdir build && cd build
cmake .. -G Xcode
open WiserOneApp.xcodeproj
```

#### Windows with Visual Studio

```cmd
REM Open Developer Command Prompt for VS 2022
mkdir build
cd build
cmake .. -G "Visual Studio 17 2022" -A x64
cmake --build . --config Release
```

## Development Workflow

### Code Style

The project follows Qt coding conventions:

```cpp
// Use camelCase for functions and variables
void updateQuoteDisplay();
QString m_currentQuote;

// Use PascalCase for classes
class QuoteManager {
    // Use m_ prefix for member variables
    QString m_databasePath;
};
```

### Testing

Run the test suite before submitting changes:

```bash
# Build and run all tests
cd build
cmake --build . --target all
ctest --verbose

# Run specific test
./tests/tst_quotemanager
```

### Debugging

Build in debug mode for development:

```bash
cmake .. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
make

# Run with debugger
gdb ./wiserone
(gdb) run
```

### Performance Profiling

```bash
# Build with debug info
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo

# Profile with valgrind
valgrind --tool=callgrind ./wiserone

# Or use perf on Linux
perf record ./wiserone
perf report
```

## IDE Setup

### VS Code

Recommended extensions:
- C/C++ Extension Pack
- CMake Tools
- Qt tools

Create `.vscode/settings.json`:
```json
{
    "cmake.configureOnOpen": true,
    "C_Cpp.default.configurationProvider": "ms-vscode.cmake-tools"
}
```

### CLion

1. Open project root directory
2. CLion will auto-detect CMakeLists.txt
3. Configure Qt6 toolchain in Settings → Build → Toolchains

### Qt Creator

1. Open CMakeLists.txt as project
2. Configure kit with Qt6
3. Select build directory

## Next Steps

Once you have the application running:

1. **Explore the UI**: Right-click the tray icon to see the context menu
2. **Check the logs**: Error logs are written to `~/Documents/appLog.txt`
3. **Read the code**: Start with `src/main.cpp` and `src/Application.cpp`
4. **Run tests**: Understand the codebase through unit tests in `tests/`
5. **Try building**: Make a small change and rebuild

## Contributing

Ready to contribute? See our [Contributing Guide](../CONTRIBUTING.md) for:
- Code style guidelines
- Pull request process
- Testing requirements

## Support

Need help? Check these resources:

- **Issues**: [GitHub Issues](https://github.com/sebastienrousseau/WiserOneApp/issues)
- **Discussions**: [GitHub Discussions](https://github.com/sebastienrousseau/WiserOneApp/discussions)
- **Wiki**: [Project Wiki](https://github.com/sebastienrousseau/WiserOneApp/wiki)

---

Designed by Sebastien Rousseau — Engineered with Euxis