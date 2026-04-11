# Contributing

Thanks for helping improve WiserOne.

## Setup

```sh
make init
swift build
make ci-local
```

On macOS, launch the app with:

```sh
swift run WiserOne
```

On Linux and WSL2, run core build and test only.

## Signed Commits

Configure Git signing:

```sh
git config commit.gpgsign true
git config tag.gpgSign true
git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519.pub
```

Create signed commits:

```sh
git commit -S -m "type: summary"
```

CI validates commit signatures on every pull request.

## Branch and PR Hygiene

Use focused branches:
- `feat/<name>`
- `fix/<name>`
- `docs/<name>`

Open pull requests with:
- clear title
- short problem statement
- short change summary
- test evidence (`make ci-local` output)

Keep pull requests small and reviewable.

## Code Guidelines

- Keep cross-platform logic in `sources/core`.
- Keep macOS UI logic in app files under `sources/`.
- Keep quote data loading logic in `QuoteRepository` and `QuoteService`.
- Add core tests in `tests/core-tests`.
- Add UI smoke tests in `tests/ui-tests`.
- Prefer simple names and short functions.
- Write comments that explain intent, not syntax.

## Governance Artifacts

Do not regenerate governance files in routine commits.

Use this only when the change requires updated governance records:

```sh
make governance-refresh
```

## Report Issues

Open an issue: https://github.com/sebastienrousseau/WiserOneApp/issues/new
