# 0001. One repository, one package and one project for every Apple platform

Status: accepted, 2026-11-26

**Context.** The iPhone and iPad app, the Mac app, and later an Apple Watch app share the engine, the contract and the tokens,
and must share one design system. Most changes reach the engine and the screens together. Nothing outside these apps consumes the
Swift code; Android shares only the server's contract bundle ([0004](0004-the-contract-is-the-servers.md)).

**Decision.**
- **Repository:** `purlay/purlay-apple` holds every Apple platform: the modules, both apps, their tests, the contract pin and the
  generator.
- **Package:** one `Package.swift` at the root holds every module as a target. The floors, Swift 6 and warnings-as-errors are
  stated once (the `module` and `tests` helpers).
- **Project:** one checked-in `Apps/Purlay.xcodeproj` in Xcode's JSON format (Xcode 27.2 or later), with synchronized folders,
  holding only the app targets: `Purlay iOS` (iPhone and iPad, `TARGETED_DEVICE_FAMILY = 1,2`) with its test bundles, and
  `Purlay macOS`. It uses the root package by path. It holds no build setting; every one is in `Config/*.xcconfig`.
- **Platforms:** Vision Pro runs the iPad app until a native target is worth it; watchOS will be a watch app inside the iOS app,
  with a design of its own (the engine already takes its socket from outside).

**Rejected.**
- *A repository per platform, with the engine released as a versioned package:* every engine change becomes a pull request, a
  release and a version bump in each app, and two design systems drift.
- *The Swift code in the server repository:* SwiftPM fetches a package only from a repository's root, so every app would clone
  the server's toolchain, and Swift releases would follow the server's tags.
- *A project generator (XcodeGen, Tuist):* a pinned tool and a regenerate step, and Xcode Cloud refuses a generated project; the
  JSON format gives the readable, mergeable diff a generator was wanted for.
- *Several local packages:* their settings drift apart; one manifest states them once.
- *One version for every platform:* the Mac ships through Sparkle while iOS waits for Q-001 ([0007](0007-releases-per-platform.md)).

**Consequences.**
- An engine change and its screens are one pull request, checked once on every platform it reaches.
- The project is edited in Xcode only; `scripts/enforcement` refuses a build setting in it.
- CI builds only what a change reaches, so one repository does not mean every check every time ([0008](0008-ci-lanes-and-one-required-check.md)).
