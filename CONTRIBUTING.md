# Contributing to Purlay for Apple platforms

The rules every Purlay repository shares (branches, commits, pull requests, the agreement) are in the organisation's
[CONTRIBUTING.md](https://github.com/purlay/.github/blob/main/CONTRIBUTING.md). This file is what is specific to this one: the
iPhone and iPad app, the Mac app and the Swift they share.

## Where code goes

- `Package.swift` and `Sources/`: every module, in one package that states the floors (iOS 18, macOS 26), Swift 6 and
  warnings-as-errors once. `PurlayContract` and `PurlayTokens` are generated (`scripts/generate`); `PurlayKit` is the engine and
  draws nothing; `PurlayDesign` is the design system and the only place an OS version is asked about; `PurlayMacUI` holds today's
  Mac screens. Tests are in `Tests/<Module>Tests`.
- `Apps/Purlay.xcodeproj`: the app targets only (`Purlay iOS`, its test bundles, `Purlay macOS`), checked in, in Xcode's JSON
  format, with synchronized folders. Change it in Xcode. It holds no build setting: every one is in `Config/*.xcconfig`.
- `Apps/iOS` and `Apps/macOS`: each app's composition root, Info.plist, entitlements, assets and changelog.

## Before you push

```sh
make setup             # once: the pinned contract bundle and the secret scanner
make verify            # rules, format and every package test, both apps built
make verify-security   # the history scanned for secrets
make verify-all        # every lane: the generated code, the Mac's Release build and the simulator included
```

`scripts/verify` holds the lanes and `make` is the entry point: `rules` (branch name, the architecture rules and a demonstration
that each refuses its violation, the Mac's strings), `generated` (the pinned contract and the code generated from it),
`packages` (format, and every package test on macOS), `ios` and `macos` (each app built, the Mac's App Transport Security and
entitlements checked), `simulator` (the iOS tests on a simulator) and `security` (gitleaks). Every build is numbered with the
commit count (`scripts/build-number`). Compiled code is cached by content, so the second run is much faster than the first; keep a
pull request's check short, and say why in its description if a change makes it slower.

## What the rules protect

`scripts/enforcement` holds the decisions, so they do not depend on review:

- the layers: `Kit` depends only on `Contract`, `Design` only on `Tokens`, a feature on the shared core and never on another
  feature, and a new module is placed in the table on purpose;
- one floor per platform, stated alike in every `Package.swift` and in `Config/`;
- OS-version checks only in `PurlayDesign`; the engine imports no UI framework;
- no package dependency, and none in the project beyond Sparkle;
- no unchecked concurrency escape and nothing that can trap on a value it was handed;
- the apps' icons, the iOS launch mark, translations, the privacy manifest, App Transport Security and the Mac's entitlements.

If a rule is in the way, change the decision first (a new record that supersedes the old), then the rule.

## Strings, accessibility, versions

Strings are in each app's string catalogue (`Localizable.xcstrings`) in English and Turkish. Every control has an accessibility
label, text uses Dynamic Type, and nothing is conveyed by colour alone. Use the newest API behind `PurlayDesign`'s modifiers, with
the older path beside it. Each app keeps its own version (`MARKETING_VERSION` in `Config/iOS.xcconfig` and
`Config/macOS.xcconfig`), tag and changelog.
