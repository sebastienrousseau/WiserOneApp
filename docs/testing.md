# Testing

## Commands

```sh
make test
make test-ui
make test-all
make ci-local
```

## Coverage Scope

- Coverage gate targets `sources/core`.
- Coverage gate runs the `WiserOneCoreTests` path for deterministic CI behavior.
- UI smoke checks run in `WiserOneUITests`.

## Regression Boundary

```mermaid
sequenceDiagram
    participant Dev as Developer or CI
    participant Gate as make test
    participant SwiftTest as swift test
    participant Coverage as check_coverage.swift

    Dev->>Gate: Start core reliability gate
    Gate->>SwiftTest: Run tests with coverage
    SwiftTest->>Coverage: Emit coverage report
    Coverage-->>Gate: pass or fail
```
