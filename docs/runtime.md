# Runtime Guide

## Purpose

Run WiserOne as a macOS menu bar app.

## Supported Platforms

| Platform | Build | Test | Run App |
| :--- | :--- | :--- | :--- |
| macOS | `swift build` | `swift test` | `swift run WiserOne` |
| Linux | `swift build` | `swift test` | Not supported |
| WSL2 | `swift build` | `swift test` | Not supported |

## Day 1 Run Path

```sh
make init
swift build
swift run WiserOne
```

## Quote Resources

The app auto-discovers and loads all JSON quote files in `sources/resources/`.
File names can be arbitrary as long as each file contains valid quote payload JSON.
