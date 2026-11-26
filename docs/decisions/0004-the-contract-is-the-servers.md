# 0004. The contract is the server's; the apps generate from its pinned bundle

Status: accepted, 2026-11-26

**Context.** The server defines the wire contract (`packages/types` in `purlay/purlay`) and publishes it with each release as a
versioned bundle with a manifest of digests. An Android client is planned, and a separate "API repository" has been suggested.

**Decision.**
- The server repository is the only definition. This repository pins one bundle in `Contract/contract.lock` (server version,
  contract version, bundle format, the manifest's digest); the bundle itself is fetched and ignored.
- `Tools/PurlayGen` generates `Sources/PurlayContract/Generated`, `Sources/PurlayKit/Generated` and
  `Sources/PurlayTokens/Generated` from it. Generated code is never edited; `scripts/generate --check` fails on any difference.
- The pin moves deliberately, never by accident: `scripts/prepare-contract` fails if fetching would change the lock. A weekly
  workflow reports when the server has released past the pin.
- Each platform generates its own types; Android keeps its own Kotlin core and shares only the bundle.

**Rejected.** *A separate contract repository:* a route and its type could no longer change in one commit, and it would own nothing
the bundle does not already carry. *Hand-written wire types:* they drift from the server silently. *A shared runtime (Kotlin
Multiplatform):* trades the platform-native feel for a shared runtime.

**Consequences.** A contract change starts in the server; here it is a new pin, a regeneration and the fixes the compiler and the
tests show ([contract.md](../development/contract.md)). Revisit if third parties need published SDKs.
