# 0007. One repository for every Apple platform

Status: accepted, 2026-11-26 (supersedes [0002](0002-shared-swift-packages.md))

**Context.** The iPhone, iPad and Mac apps, and later Apple Watch, share the engine, the contract and the tokens, and must
share one design system. With `purlay-swift`, `purlay-ios` and `purlay-macos` apart, every change to the engine became a
pull request, a release tag and two version bumps. The coming slices all change the engine and the screens together. Nothing
outside these three repositories consumes the Swift package; Android shares only the server's contract bundle (ADR 0004).

**Decision.** One repository, `purlay/purlay-apple`, built by importing the three repositories with their history:
- **Package:** one `Package.swift` at the root holds every module, with platform floors and strict Swift 6 stated once.
- **Project:** one checked-in `Apps/Purlay.xcodeproj` in Xcode's JSON format, holding only the app targets: iOS (iPhone and
  iPad), macOS, and later watchOS inside the iOS app. Every build setting is in `.xcconfig`.
- **Releases:** each platform keeps its own version, tag (`ios/v*`, `macos/v*`), changelog and distribution channel. The
  build number is the commit count.
- **Checks:** layering, the availability seam and feature isolation are checked by `scripts/enforcement`.
- **Migration:** the phases are in [architecture/apple-monorepo.md](../architecture/apple-monorepo.md).

**Rejected.**
- *Moving the Swift code into the server repository:* SwiftPM fetches a package only from a repository's root; it would tie
  Swift releases to the server's tags and make every app clone the server's toolchain.
- *Keeping three repositories:* the release-and-bump loop on every engine change, and two design systems.
- *XcodeGen or Tuist:* a generator step and a pinned tool, and Xcode Cloud refuses generated projects. The JSON format already
  gives most of what a generator was used for.
- *One version for all platforms:* the Mac ships through Sparkle while iOS waits for Q-001.

**Consequences.**
- An engine change and its screens are one pull request.
- `check-shared-files` and the single-pin rule go away.
- Installed Macs move to a stable update feed through a bridge release from `purlay-macos` before it is archived.
- The old repositories are archived, not deleted.
