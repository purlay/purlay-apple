# 0005. `make verify` over the lanes of `scripts/verify`, and a secret scan of the history

Status: accepted, 2026-11-26

**Context.** The checks must be one thing a person runs and a pipeline runs, in pieces that can run side by side. Swift Package
Manager has no standard vulnerability database, and a secret committed and then removed is still in the history.

**Decision.**
- `scripts/verify` holds the lanes (`rules`, `generated`, `packages`, `ios`, `macos`, `simulator`, `security`); `scripts/verify
  <lane>` runs one. The `Makefile` holds no logic: `make setup` installs the pinned tools and the git hooks, `make verify` runs
  what a pull request needs (`rules`, `packages`, `ios`, `macos`), `make verify-security` the secret scan, `make verify-all`
  every lane as a release runs them.
- The `security` lane scans the whole history with gitleaks, at the version and digests pinned in `scripts/install-gitleaks`. CI
  runs it on every run, a documents-only pull request included, and the required check does not accept it skipped. The
  pre-commit hook scans staged changes before they are committed.
- Dependency risk is held by having almost none ([0010](0010-no-third-party-code-beyond-sparkle.md)), by pinning tools by digest,
  and by Dependabot for the actions and packages.

**Rejected.** *The lanes written in the Makefile:* a second home for the same commands. *Scanning only the working tree:* misses
what was removed. *gitleaks from Homebrew:* unpinned and slow on a hosted runner. *A third-party SwiftPM audit tool:* none is
established, and it would be a dependency of its own.

**Consequences.** One name for "done", and a leaked secret fails the pull request that carries it. The scan sees only what
gitleaks's rules recognise. A false positive needs an allowlist (`.gitleaks.toml`, which does not exist because none has
occurred).
