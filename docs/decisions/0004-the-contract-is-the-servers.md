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
- A colour is the bundle's token. A colour literal (a hex value, or components given as numbers) is allowed only where its value
  is stated: the generated tokens, the logo (`Sources/PurlayDesign/Logo.swift`, which `scripts/icon` writes from
  `Design/purlay.svg`), and `Sources/PurlayMacUI/NativePalette.swift`, the Mac's neutral greys and status colours that no token
  states yet. Both apps' accent is the token's. `scripts/enforcement` refuses a literal anywhere else.

**Rejected.** *A separate contract repository:* a route and its type could no longer change in one commit, and it would own nothing
the bundle does not already carry. *Hand-written wire types:* they drift from the server silently. *Colours of the apps' own:* the Mac's composer drew a blue
(0x015bf7) that was not the brand's. *A shared runtime (Kotlin
Multiplatform):* trades the platform-native feel for a shared runtime.

**Consequences.** A contract change starts in the server; here it is a new pin, a regeneration and the fixes the compiler and the
tests show ([contract.md](../development/contract.md)). Revisit if third parties need published SDKs.
