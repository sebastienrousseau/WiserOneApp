# Dependency Checksum Lock

`dependency-checksums.lock` enforces SOUP controls for external SwiftPM dependencies.

Format:

```text
source_url|sha256|signature_reference
```

Rules:

- One row per external dependency declared via `.package(...)` in `Package.swift`.
- `sha256` must be the immutable source artifact checksum.
- `signature_reference` must point to vendor signature verification evidence.

Security posture details:

- `security-and-compliance.md`
