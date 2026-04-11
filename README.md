# WiserOne

Daily quotes in a macOS menu bar app.

## What Ships

- `WiserOne`: macOS AppKit executable.
- `WiserOneCore`: platform-neutral module for resource resolution logic.

## Platform Support

| Platform | Build | Test | Run Desktop App |
| :--- | :--- | :--- | :--- |
| macOS | `swift build` | `swift test` | `swift run WiserOne` |
| Linux | `swift build` | `swift test` | Not supported |
| WSL2 (Ubuntu/Debian) | `swift build` | `swift test` | Not supported |

## Day 1 Setup

```sh
git clone https://github.com/sebastienrousseau/WiserOneApp.git
cd WiserOneApp
swift build
swift test
```

Run the app on macOS:

```sh
swift run WiserOne
```

Onboarding target: 15 minutes on a fresh machine.

## Quality Gates

Run core quality gates:

```sh
make security
make test
make hygiene
```

`make hygiene` runs:

- `./scripts/quality/verify-portability.sh`
- `./scripts/quality/verify-docs-completeness.sh`
- `./scripts/quality/verify-content-integrity.sh`

## UI Test Target

This repository includes a dedicated macOS UI-focused XCTest target:

- `WiserOneUITests`

Run only UI-focused tests:

```sh
make test-ui
```

Run all tests (core coverage gate + UI tests):

```sh
make test-all
```

## Signed Commits

Enable commit signing locally:

```sh
git config commit.gpgsign true
git config tag.gpgSign true
git config gpg.format openpgp
```

Create a signed commit:

```sh
git commit -S -m "type: summary"
```

## Troubleshooting

Run the explicit product name:

```sh
swift run WiserOne
```

## Architecture

```mermaid
flowchart LR
    A[WiserOne App\nmacOS only] --> B[WiserOneCore]
    T[WiserOneCoreTests] --> B
```

## Repository Map

```text
.build/                (generated local build cache; not tracked)
sources/
  core/
  AppDelegate.swift
  QuoteViewController.swift
  main.swift
tests/
  core-tests/
  ui-tests/
docs/
scripts/
governance/
  security/
  sbom/
  checksums/
  compliance/
config/
```

Detailed docs are available in:

- [docs/repository-layout.md](docs/repository-layout.md)
- [docs/runtime.md](docs/runtime.md)
- [tests/README.md](tests/README.md)
- [scripts/README.md](scripts/README.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Licensed under MIT OR Apache-2.0.
