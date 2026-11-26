# Contributing to Purlay for Apple platforms

The rules every Purlay repository shares (the agreement, conduct) are in the organisation's
[CONTRIBUTING.md](https://github.com/purlay/.github/blob/main/CONTRIBUTING.md). This file is what is specific to this one: the
iPhone and iPad app, the Mac app and the Swift they share. Start with [`docs/README.md`](docs/README.md).

## The flow

1. **Set up once:** `make setup` (the pinned contract bundle, the secret scanner, and the git hooks).
2. **Branch** from main, named `feat/…`, `fix/…`, `chore/…`, `refactor/…` or `docs/…` (`scripts/check-branch` refuses
   anything else).
3. **Commit** in conventional commits, as the history is: `type(scope): what changed`, for example `fix(app): the mark stays put
   under Reduce Motion`. Types: `feat`, `fix`, `docs`, `refactor`, `build`, `ci`, `chore`, `test`, `perf`, `style`, `revert`.
   The commit-msg hook checks the form; the pre-commit hook checks the staged Swift's format and that no secret is staged.
4. **Every change updates its documents in the same pull request**: a path, a command, a number or a rule a document states that
   the change makes untrue; the requirement's status; a decision record when a decision was made
   ([`docs/decisions/`](docs/decisions/README.md)); the app's changelog when a person would notice.
5. **`make verify` before pushing.** It runs what CI's required check runs: the rules, format and every package test, both apps
   built. `make verify-security` scans the history for secrets; `make verify-all` runs every lane, the simulator included.
6. **Open a pull request** with the template filled in. Its title becomes the squash commit's message, so it is a conventional
   commit too. CI labels it by its paths; add a `type:` label and, if it is urgent, a `priority:` one.
7. **Merge** when `verify` is green and every review conversation is resolved. Main takes **squash merges only**, and the branch
   is deleted on merge. A branch does not need to be up to date with main to merge: `verify` runs on the merge with main, and
   requiring it would restart every open pull request's check after each merge.

A pull request's check takes about 2 to 2½ minutes for a code change and under 30 seconds for documents only
([`docs/development/ci.md`](docs/development/ci.md)). Keep it that way: a change that makes it slower says why in its description,
with the run's times.

## Where code goes

- `Package.swift` and `Sources/`: every module, in one package that states the floors (iOS 18, macOS 26), Swift 6 and
  warnings-as-errors once. `PurlayContract` and `PurlayTokens` are generated (`scripts/generate`); `PurlayKit` is the engine and
  draws nothing; `PurlayDesign` is the design system and the only place an OS version is asked about; `PurlayMacUI` holds the
  Mac's screens. Tests are in `Tests/<Module>Tests`.
- `Apps/Purlay.xcodeproj`: the app targets only (`Purlay iOS`, its test bundles, `Purlay macOS`), checked in, in Xcode's JSON
  format, with synchronized folders. Change it in Xcode. It holds no build setting: every one is in `Config/*.xcconfig`.
- `Apps/iOS` and `Apps/macOS`: each app's composition root, Info.plist, entitlements, assets, string catalogue and changelog.

The module rules, and how to add a module: [`docs/architecture/modules-and-layers.md`](docs/architecture/modules-and-layers.md).
The code conventions: [`docs/architecture/conventions.md`](docs/architecture/conventions.md).

## What the rules protect

`scripts/enforcement` holds the decisions, so they do not depend on review, and `--demo` proves each rule refuses its violation:
the layers; one floor per platform; OS-version checks only in `PurlayDesign`; no UI framework in the engine; no package
dependency and none in the project beyond Sparkle; no unchecked concurrency escape and nothing that can trap; the apps' icons,
the iOS launch mark, translations, the privacy manifest, App Transport Security and the Mac's entitlements.

If a rule is in the way, change the decision first (its record, in the same pull request), then the rule.

## Strings, accessibility, versions

Strings are in each app's string catalogue (`Localizable.xcstrings`), English and Turkish. Every control has an accessibility
label, text uses Dynamic Type, and nothing is said by colour alone. Use the newest API behind `PurlayDesign`'s modifiers, with the
older path beside it. Each app keeps its own version (`MARKETING_VERSION` in `Config/iOS.xcconfig` and `Config/macOS.xcconfig`),
with a section in its changelog, its own tag and its own release ([`docs/development/releasing.md`](docs/development/releasing.md)).

## Dependencies and security

No new dependency without a decision record ([ADR 0010](docs/decisions/0010-no-third-party-code-beyond-sparkle.md)). Dependabot
proposes updates weekly, grouped; a patch update merges by itself when `verify` passes. Report a vulnerability privately, never
in an issue: [`SECURITY.md`](SECURITY.md).
