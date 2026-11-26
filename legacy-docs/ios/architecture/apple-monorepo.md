# Design: one Apple repository (`purlay-apple`)

> 2026-11-26 · Owner: the Purlay owner · Decision: [ADR 0007](../decisions/0007-one-apple-repository.md) · Approved by the owner (D1–D6), 2026-11-26

## Intent

The owner wants to build iPhone, iPad, Mac and later Apple Watch apps in parallel, fast and without friction, at Apple's
own quality, and to keep doing so for years. Today a change to the engine is a pull request in `purlay-swift`, then a release
tag, then a version bump in `purlay-ios` and another in `purlay-macos`. The design system lives only in the iOS app, and the
Mac has its own. Every coming slice (account erasure, the wipe on sign-out, chat) touches the engine and the screens
together, so that loop would be paid again and again.

## Goals

- One change to the engine, a screen and its tests is one pull request, checked once, on every platform it affects.
- One design system for every Apple platform, with the OS-version decisions in one module.
- Each platform keeps its own version, tag, changelog and distribution channel: the Mac on Developer ID and Sparkle, iOS on
  TestFlight and the App Store (after Q-001), and watchOS inside the iOS app.
- A pull request is checked in about 3 minutes, and only the platforms a change touches are built.
- Rules that hold the architecture (layering, the availability seam, no feature importing a feature) are checked by a tool,
  not by memory.

## Non-goals

- Moving the server or the contract. `purlay` stays separate, and the contract still crosses as a versioned bundle (ADR 0004).
- Building the watch app now. The structure makes room for it, and it gets its own design.
- Changing behaviour during the move. The move changes where code lives, never what it does.

## Anti-goals

- Breaking the update path of Mac apps already installed (v0.1.0–v0.3.0 check `releases/latest/download/appcast.xml` in
  `purlay-macos`).
- Losing history: `git log` and `blame` must keep working on moved files.
- Tooling that needs a paid service, a regenerate step, or that blocks Xcode Cloud.

## Facts this design rests on

1. **The Mac app has shipped.** Build number 10 is v0.3.0. Sparkle compares build numbers, so new builds must be numbered
   above 10.
2. **Xcode 27.2 saves projects as JSON** (`.xcproj`), which Apple says makes merge conflicts less likely, and reverting is a
   single setting. Xcode Cloud refuses a project that a tool generates or edits.
3. **watchOS restricts low-level networking** (TN3135), the WebSocket included, on a real device. The engine already takes
   its socket from outside (`AppEnvironment.openSocket`).

## Approaches considered

| Question | Chosen | Rejected, and why |
|---|---|---|
| Repo | A new `purlay/purlay-apple`, made by a script that imports all three repos with history (`git filter-repo --to-subdirectory-filter`, tags renamed to `ios/`, `macos/`, `swift/`) | *Renaming `purlay-ios`:* nothing to keep there, and the files must move anyway. *Renaming `purlay-macos`:* keeps the update feed only through a GitHub redirect, which breaks if anyone takes the old name. *`git subtree`:* path history is lost |
| Project | One checked-in `Apps/Purlay.xcodeproj` in Xcode's JSON format, with synchronized folders, holding only app targets. Every setting goes in `.xcconfig` | *XcodeGen:* a pinned tool, a regenerate step, and it blocks Xcode Cloud; its benefit is now the JSON format's. *Tuist 4:* a manifest language and a paid cache for a team this size |
| Modules | One `Package.swift` at the root, with every module a target: floors, Swift 6 and warnings-as-errors stated once | *Several local packages:* the settings drift that `check-shared-files` exists to catch |
| Releases | Each platform has its own version, tag (`ios/v*`, `macos/v*`) and changelog; the build number is the commit count | *One train:* the Mac ships on Sparkle while iOS is blocked by Q-001 |
| CI | GitHub Actions: path-based jobs, one required `verify` check, the content-addressed compilation cache | *Xcode Cloud now:* it cannot publish the Sparkle feed or a GitHub release; the checked-in project keeps it possible later |

## The design

### Layout

```
purlay-apple/
├── Package.swift                 every module; floors and strict Swift stated once
├── Sources/
│   ├── PurlayContract/  PurlayTokens/        generated from the server's bundle (never hand-edited)
│   ├── PurlayKit/                            the engine: no UI framework
│   ├── PurlayTestSupport/
│   ├── PurlayDesign/                         the one design system; the only #available
│   ├── PurlayModuleAPI/
│   ├── PurlayMacUI/                          temporary: today's Mac screens, moved into features one by one
│   └── Feature<Module>/{Model,Shared,iOS,macOS}/
├── Tests/<Module>Tests/
├── Apps/
│   ├── Purlay.xcodeproj                      app targets only: iOS (iPhone and iPad), macOS, later watchOS
│   ├── iOS/   macOS/   (watchOS/ later)      thin composition roots, Info.plist, entitlements, assets
│   └── <platform>/CHANGELOG.md
├── Config/{Shared,iOS,macOS,Debug,Release}.xcconfig
├── TestPlans/{PR,Simulator,macOS}.xctestplan
├── Contract/contract.lock   Tools/PurlayGen/   ContractTests/
├── Design/purlay.svg        scripts/          docs/
```

### The layers (checked by `scripts/enforcement layers`, from `swift package dump-package`)

| Module | May depend on |
|---|---|
| `PurlayContract`, `PurlayTokens` | nothing |
| `PurlayKit` | Contract |
| `PurlayTestSupport` | Kit, Contract |
| `PurlayDesign` | Tokens |
| `PurlayModuleAPI` | nothing |
| `Feature<Module>` | Kit, Contract, Tokens, Design, ModuleAPI, never another feature |
| `PurlayMacUI` | as today, until it is emptied |
| App targets | everything above |

`#available` is allowed only in `Sources/PurlayDesign`. `#if os(…)` is allowed only as a whole-file wrapper under a
platform folder. `--demo` plants each violation and requires the rule to refuse it.

### Platforms

- The iPhone and iPad are one target (`TARGETED_DEVICE_FAMILY = 1,2`): the screens adapt, and iPad-specific layouts live in
  the feature's `iOS/` folder behind size classes. Vision Pro runs the iPad app ("Designed for iPad") until a native target
  is worth it.
- The Mac is its own target: bundle id `dev.purlay.mac`, Sparkle, Developer ID, its own entitlements.
- watchOS (later) is a watch app inside the iOS app. It links Contract, Kit and Design, gives the engine a socket that says
  "unavailable", and needs an engine mode without realtime. That mode and how the watch gets a session are its own design.

### CI and releases

- **Pull request:**
  - Linux jobs: `rules`, `security` (gitleaks), and `changes`, which maps paths to the jobs that need to run.
  - macOS jobs: `generated` (only when `Contract/` or `Tools/` change), `packages`, `ios` and `macos`.
  - The simulator runs on main, weekly, and when `Apps/iOS/**` changes.
  - One `verify` job is the required check.
- Weekly contract-drift job: opens an issue when the server's bundle moves ahead of `Contract/contract.lock`.
- **Mac update feed:** moves to a stable address the project owns (for example `updates.purlay.app/macos/appcast.xml`). A
  bridge release v0.3.1 from `purlay-macos` changes only `SUFeedURL`, so installed copies follow. The Sparkle key, the
  bundle id and the signing identity do not change.
- **Notarization and uploads:** both move to an App Store Connect API key. The same key will later upload iOS builds to
  TestFlight (after Q-001).

## Migration, in phases (each gated: every lane green and the test counts unchanged)

| Phase | What | Gate | Who |
|---|---|---|---|
| 0 | Finish the entry slice. Freeze merges in the three repos | — | — |
| 1 | Local import into `ios/`, `macos/` and `swift/`. The apps use the engine by path. Each folder keeps its XcodeGen | each folder's `scripts/verify` green; test counts match | me |
| 2 | Create `purlay/purlay-apple`, push, set protection and secrets; old repos get a banner | CI green on main | owner approves, then me |
| 3 | Root `Package.swift`, `git mv` into `Sources/` and `Tests/`, ADR 0007, the layer rule. Delete the shared-file machinery | same test counts; `enforcement --demo` passes; Mac Release passes its ATS and entitlement checks | me |
| 4 | The checked-in JSON project replaces both `project.yml`; XcodeGen removed | build settings, Info.plist and entitlements identical before and after | me |
| 5 | Stable feed, the v0.3.1 bridge release, a rehearsal of `release-macos.yml` | a Mac on 0.3.0 updates to 0.3.1, then to a monorepo test build | owner approves, then me |
| 6 | Archive the three repos after a green week (reversible) | — | owner approves |
| 7 | Merge the design systems (Mac `PurlayUI` into `PurlayDesign`), then move Mac screens into features | each move keeps its tests | me |

The entry slice's slice 2 (shell and account) starts after phase 4. It is the first work done in the new structure.

## Owner decisions

| # | Decision | My recommendation |
|---|---|---|
| D1 | A new repo `purlay/purlay-apple` | Yes (above) |
| D2 | The update-feed domain and host | `updates.purlay.app` on GitHub Pages from the new repo |
| D3 | The v0.3.1 bridge release to installed Macs (cannot be undone) | Yes, before archiving |
| D4 | When to archive the old repos | After a green week on the new one |
| D5 | Moving secrets and switching notarization to an API key | Yes |
| D6 | The Mac keeps Developer ID distribution while Q-001 is open | Yes |

## Left to verify in phase 3 (unconfirmed facts)

- Whether a project in `Apps/` can use the root package by path without a workspace. The fallback is `Purlay.xcworkspace`.
- Whether `swift package dump-package` runs on the Linux runner. If not, the layer rule runs in `packages`.
- Whether Xcode 27 refuses an import of an undeclared module by default.
