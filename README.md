<!-- markdownlint-disable MD033 MD041 -->

<img
src="https://kura.pro/wiserone/images/logos/wiserone.webp"
alt="The Wiser One logo"
height="199"
width="199"
align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# The Wiser One

[![CI](https://github.com/sebastienrousseau/WiserOneApp/actions/workflows/ci.yml/badge.svg)](https://github.com/sebastienrousseau/WiserOneApp/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![C++23](https://img.shields.io/badge/C++-23-blue.svg)](https://en.cppreference.com/w/cpp/23)
[![Qt6](https://img.shields.io/badge/Qt-6.2+-green.svg)](https://www.qt.io/)

Daily nuggets of wisdom in a clean, minimalist design, inspiring deeper thought and personal growth with every visit.

![divider][divider]

## Overview

The Wiser One is a cross-platform system tray application that offers daily insights and wisdom in a sleek, minimalist interface. It runs natively on **Windows**, **macOS**, and **Linux** (including Wayland and X11).

## Features

- **System Tray Integration** — Lives in your system tray/menu bar for quick access
- **Random Daily Quotes** — Presents a different inspirational quote each time
- **Monthly Quote Collections** — Loads quotes specific to the current month
- **Click-to-Website** — Click the logo to visit wiserone.com
- **Cross-Platform** — Native look and feel on Windows, macOS, and Linux
- **Dark/Light Mode** — Automatically adapts to your system theme
- **15 Languages** — Full internationalization support

### Supported Languages

English, Français, Español, Deutsch, Português, 简体中文, 日本語, 한국어, Русский, Italiano, العربية, עברית, हिंदी, Nederlands, Bahasa Indonesia

## Installation

### Download

Download the latest release for your platform from the [Releases](https://github.com/sebastienrousseau/WiserOneApp/releases) page:

| Platform | Download |
|----------|----------|
| Linux | `wiserone-linux-x64.tar.gz` |
| macOS | `wiserone-macos-x64.dmg` |
| Windows | `wiserone-windows-x64.zip` |

### Linux Installation

```bash
# Extract
tar -xzf wiserone-linux-x64.tar.gz

# Install (optional)
sudo cp usr/bin/wiserone /usr/local/bin/
sudo cp usr/share/applications/com.wiserone.WiserOne.desktop /usr/share/applications/
sudo cp usr/share/icons/hicolor/256x256/apps/com.wiserone.WiserOne.png /usr/share/icons/hicolor/256x256/apps/

# Run
wiserone
```

### macOS Installation

1. Open the `.dmg` file
2. Drag "The Wiser One" to Applications
3. Launch from Applications or Spotlight

### Windows Installation

1. Extract the `.zip` file
2. Run `WiserOne.exe`
3. (Optional) Create a shortcut in your Start menu

## Building from Source

### Prerequisites

- **Qt6** 6.2+ with Widgets, Svg, SvgWidgets, LinguistTools modules
- **CMake** 3.16+
- **C++23** compatible compiler (GCC 13+, Clang 17+, MSVC 19.36+)

### Installing Dependencies

<details>
<summary><strong>Ubuntu/Debian</strong></summary>

```bash
sudo apt install qt6-base-dev qt6-svg-dev qt6-l10n-tools cmake build-essential libgl1-mesa-dev
```

</details>

<details>
<summary><strong>Fedora</strong></summary>

```bash
sudo dnf install qt6-qtbase-devel qt6-qtsvg-devel qt6-linguist cmake gcc-c++
```

</details>

<details>
<summary><strong>Arch Linux</strong></summary>

```bash
sudo pacman -S qt6-base qt6-svg qt6-tools cmake
```

</details>

<details>
<summary><strong>macOS (Homebrew)</strong></summary>

```bash
brew install qt6 cmake
```

</details>

<details>
<summary><strong>Windows</strong></summary>

1. Install Qt6 via the [Qt Online Installer](https://www.qt.io/download-qt-installer) (select Desktop components)
2. Install [CMake](https://cmake.org/download/)
3. Install Visual Studio 2022 or MinGW

</details>

### Build Instructions

```bash
# Clone the repository
git clone https://github.com/sebastienrousseau/WiserOneApp.git
cd WiserOneApp

# Create build directory
mkdir build && cd build

# Configure
cmake .. -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build . --parallel $(nproc)

# Run tests
ctest --output-on-failure

# Run the application
./wiserone
```

## Usage

1. After launching, The Wiser One appears in your system tray
2. Click the tray icon to see the context menu with a quote
3. Click **Refresh** to see a new random quote
4. Click **Visit Website** to open wiserone.com
5. Click **Quit** to exit the application

## Project Structure

```
WiserOneApp/
├── CMakeLists.txt              # Build configuration
├── src/
│   ├── main.cpp                # Application entry point
│   ├── Application.h/cpp       # App lifecycle management
│   ├── TrayIcon.h/cpp          # System tray integration
│   ├── QuoteWidget.h/cpp       # Quote popup window
│   ├── QuoteManager.h/cpp      # Quote loading and selection
│   └── ErrorLogger.h/cpp       # Thread-safe error logging
├── resources/
│   ├── resources.qrc           # Qt resource file
│   ├── logo.svg                # Application logo
│   ├── 01-quotes.json          # January quotes
│   ├── 02-quotes.json          # February quotes
│   ├── icons/                  # Application icons
│   └── linux/                  # Linux desktop integration
├── translations/               # i18n files (15 languages)
└── tests/                      # Unit tests
```

## Documentation

Comprehensive documentation is available in the [`docs/`](docs/) directory:

- **[User Guide](docs/USER_GUIDE.md)** - Complete usage instructions
- **[Getting Started](docs/GETTING_STARTED.md)** - Development setup
- **[API Reference](docs/API.md)** - Technical API documentation

## Contributing

We welcome contributions! Please see the [Contributing Guide](CONTRIBUTING.md) for:

- Coding standards (C++23, Qt style)
- Commit message format (Conventional Commits)
- Pull request process

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgements

- [Qt Project](https://www.qt.io/) for the cross-platform framework
- [The Noun Project](https://thenounproject.com/) for icon inspiration
- All [contributors](https://github.com/sebastienrousseau/WiserOneApp/graphs/contributors)

---

<p align="center">
  Made with ❤️ by <a href="https://wiserone.com">WiserOne</a><br>
  Designed by Sebastien Rousseau — Engineered with Euxis
</p>

[divider]: https://kura.pro/common/images/elements/divider.svg "divider"
