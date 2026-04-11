# Architecture

## Modules

- `WiserOne`: macOS AppKit runtime.
- `WiserOneCore`: portable resource resolution logic.
- `WiserOneCoreTests`: coverage-gated tests for core logic.
- `WiserOneUITests`: macOS UI smoke coverage.

```mermaid
flowchart LR
    A[WiserOne App\nmacOS] --> B[WiserOneCore]
    T1[WiserOneCoreTests] --> B
    T2[WiserOneUITests] --> A
    R[JSON resources] --> A
```

## Runtime Flow

```mermaid
sequenceDiagram
    participant User as User
    participant Menu as Status Item
    participant VC as QuoteViewController
    participant Core as WiserOneCore

    User->>Menu: Click menu bar icon
    Menu->>VC: Show popover
    VC->>Core: Resolve resource candidates
    VC->>VC: Load JSON quote payload
    VC-->>User: Render quote and signature
```
