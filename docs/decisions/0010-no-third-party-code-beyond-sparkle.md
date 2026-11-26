# 0010. No third-party code beyond Sparkle

Status: accepted, 2026-11-26

**Context.** Every dependency is code the apps ship and trust, and Swift packages have no standard vulnerability database.

**Decision.** The root package has no dependency (`scripts/enforcement` refuses any `.package(`). The project's only remote package
is Sparkle, at an exact version (2.10.1), linked by the Mac app alone and imported only in `Apps/macOS/App/Updates`. A new
dependency needs a decision record first, then a change to the allowlist in `scripts/enforcement`.

**Rejected.** *Convenience packages (networking, Keychain wrappers):* the standard library and Foundation do it. *Writing an
updater:* Sparkle is the established, audited way to update a Developer ID app, with signed feeds.

**Consequences.** Little to scan and little to update. Sparkle's security releases are watched by hand at each release (TD-013).
