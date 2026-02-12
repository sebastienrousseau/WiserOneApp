# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Updated copyright year to 2024-2026

### Removed

- Legacy Swift/Xcode source files and assets
- Swift configuration files (.swiftlint.yml, Package.swift)
- SwiftLint CI workflow

## [0.0.2] - 2026-02-11

### Added

- Cross-platform Qt6 implementation (Windows, macOS, Linux)
- System tray integration with theme-adaptive icon
- Internationalization support for 15 languages:
  - English, French, Spanish, German, Portuguese
  - Chinese (Simplified), Japanese, Korean, Russian, Italian
  - Arabic, Hebrew, Hindi, Dutch, Indonesian
- Dark/light mode automatic detection and adaptation
- Desktop launcher integration for Linux (freedesktop)
- AppStream metadata for Linux software centers
- Comprehensive unit tests with Qt Test framework
- CI/CD pipeline with GitHub Actions
- SPDX license headers on all source files

### Changed

- Migrated from Swift/Cocoa to C++23/Qt6
- Menu item "New Quote" renamed to "Refresh"
- Tray icon changed to magic rune symbol
- Build system changed from Swift Package Manager to CMake

### Technical

- C++23 standard with `std::expected` error handling
- Qt6.2+ with Widgets, Svg, SvgWidgets modules
- Modern C++ patterns: smart pointers, RAII, constexpr
- Static analysis with clang-tidy
- Code formatting with clang-format

## [0.0.1] - 2024-01-01

### Added

- Initial macOS Swift implementation
- Basic quote display functionality
- System tray integration for macOS

---

[Unreleased]: https://github.com/sebastienrousseau/WiserOneApp/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/sebastienrousseau/WiserOneApp/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/sebastienrousseau/WiserOneApp/releases/tag/v0.0.1
