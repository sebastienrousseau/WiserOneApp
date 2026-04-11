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
make test
swift run WiserOne
```

## Quote Resources

The app auto-discovers and loads all JSON quote files in `sources/resources/`.
File names can be arbitrary as long as each file contains valid quote payload JSON.

## Stable Local Health Check

```sh
make ci-local
```

## CI Troubleshooting

1. Run `make ci-local` locally before opening a PR.
2. On Linux and WSL2, install `shellcheck` so shell lint runs during `make hygiene`.
3. Keep file path casing normalized (`sources/`, `tests/`) to avoid Linux-only failures.
4. Refresh governance artifacts only when required by release or compliance updates.
