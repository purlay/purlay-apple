# Releasing

Each platform releases on its own: its own version, changelog, tag and workflow
([ADR 0007](../decisions/0007-releases-per-platform.md)). A release never runs the tests again; it builds the commit that main's
CI already passed.

| | Mac | iPhone and iPad |
|---|---|---|
| Version | `MARKETING_VERSION` in `Config/macOS.xcconfig` | `MARKETING_VERSION` in `Config/iOS.xcconfig` |
| Changelog | `Apps/macOS/CHANGELOG.md` (it is also the release notes, rendered by `scripts/release-notes`) | `Apps/iOS/CHANGELOG.md` |
| Tag | `macos/vX.Y.Z` | `ios/vX.Y.Z` |
| Workflow | `release-macos.yml`: signed, notarized, stapled, a signed Sparkle appcast, a GitHub release, the stable feed | `release-ios.yml`: an unsigned Release archive (until Q-001) |
| Runbook | [release-macos.md](../runbooks/release-macos.md) | below |
| Expected time | 4–6 minutes from the tag, after the environment is approved | 3–5 minutes |

## Versions, changelogs and build numbers

- A version is raised in the pull request that starts it: `MARKETING_VERSION` and a `## [X.Y.Z] — Unreleased` section in the
  changelog together. `scripts/ci/changelog-versions` (in CI's `changes` job) refuses a version with no section.
- At release, the section's "Unreleased" becomes the date (`## [X.Y.Z] — YYYY-MM-DD`). The Mac's notes accept only paragraphs,
  level-three headings, bullets and bold text; check them with `scripts/release-notes X.Y.Z "$(mktemp -d)"`.
- The build number is the commit count at the tagged commit (`scripts/build-number`), the same for both apps, and always above
  10, the Mac's 0.3.0 (Sparkle offers only a higher build).

## What every release workflow does first: the gate

`scripts/ci/release-gate` refuses to go on unless the tag is `<platform>/v` plus the configured version, the changelog has that
version's section, and **the tagged commit has a successful `ci.yml` run on main** (read from the GitHub API). A run by hand that
is not on a tag is a rehearsal: the tag and CI conditions become warnings, and nothing is published.

## The iPhone and iPad app, until Q-001

Distribution waits for the licensing decision (Q-001, TD-005). Meanwhile an `ios/vX.Y.Z` tag on a commit that passed CI makes an
unsigned Release archive for `generic/platform=iOS`, kept as the run's artefact for 14 days with its digest; *Actions → Release
iOS → Run workflow* rehearses the same from any branch. The archive is a proof that the release path works, not something to
install.

```sh
git switch main && git pull
git tag ios/vX.Y.Z && git push origin ios/vX.Y.Z
```

## The `release` environment

The Mac's signing material exists only as secrets of the `release` environment, which requires the owner's approval for each
run and accepts only `main` and `macos/v*` tags ([.github/settings.md](../../.github/settings.md)):

| Secret | What |
|---|---|
| `MACOS_CERTIFICATE_P12` | the Developer ID Application certificate and key, PKCS#12, base64 |
| `MACOS_CERTIFICATE_PASSWORD` | its password |
| `APP_STORE_CONNECT_API_KEY_P8` | an App Store Connect API key for notarization (the `.p8` file, base64), Developer role |
| `APP_STORE_CONNECT_KEY_ID` | that key's id |
| `APP_STORE_CONNECT_ISSUER_ID` | the issuer id of the team's keys |
| `SPARKLE_PRIVATE_KEY` | Sparkle's EdDSA private key; its public half is `SUPublicEDKey` in `Apps/macOS/Info.plist` |

The job that uses them builds and signs, and cannot write to the repository; the job that publishes holds no secret. The keychain
it makes, the certificate and the API key are deleted at the end of the job whatever happened. Rotating any of them:
[signing-credentials.md](../runbooks/signing-credentials.md), [rotate-sparkle-key.md](../runbooks/rotate-sparkle-key.md).
