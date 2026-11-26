# Release the Mac app

A release is a `macos/vX.Y.Z` tag on a commit that passed CI on main; `release-macos.yml` does the rest in about 4–6 minutes once
the owner approves the `release` environment. Nothing is signed on a person's Mac. Background: [releasing.md](../development/releasing.md).

## Before tagging

1. **The feed.** `scripts/ci/feed-url` prints where installed Macs read their updates. Until it prints a `pages_path`, a release
   here does not reach installed Macs: do [mac-update-feed.md](mac-update-feed.md) first (TD-019).
2. **Sparkle.** `gh release view --repo sparkle-project/Sparkle --json tagName,publishedAt`. If it is newer than the version
   `Apps/Purlay.xcodeproj` pins (2.10.1), move the pin in Xcode in its own pull request, check `licenses/Sparkle.txt`, and do not
   leave a security fix for later (TD-013).
3. **The version and its notes,** in one pull request `chore(macos): release X.Y.Z`: `MARKETING_VERSION = X.Y.Z` in
   `Config/macOS.xcconfig`, and the `## [X.Y.Z] — Unreleased` section of `Apps/macOS/CHANGELOG.md` dated
   (`## [X.Y.Z] — YYYY-MM-DD`). Check the notes render: `scripts/release-notes X.Y.Z "$(mktemp -d)"`.
4. **Merge it, and wait for main's CI run to be green.** The release builds Release from the cache that run keeps warm.
5. **Rehearse** (once per release; it signs and notarizes, and publishes nothing):
   `gh workflow run release-macos.yml --ref main -f publish=false`, then approve the `release` environment on the run.

## Tag

```sh
git switch main && git pull
git tag macos/vX.Y.Z && git push origin macos/vX.Y.Z
```

Approve the `release` environment on the run. The workflow: the gate (version, changelog, main's CI), the Release build from the
warm cache with its ATS and entitlement checks, the check that the app reads the stated feed, Developer ID signing (Sparkle's
helpers first), notarization with the API key, stapling and Gatekeeper's assessment, the ZIP and `SHA256SUMS`, the notes, the
signed appcast with every signature verified, the build-provenance attestation, the GitHub release, and the stable feed on Pages.
The keychain and keys are removed at the end whatever happened.

## After

1. The release has `Purlay-X.Y.Z-macOS-arm64.zip`, `SHA256SUMS`, `appcast.xml` and the notes' HTML. Check a download:
   `shasum -a 256 -c SHA256SUMS` and `gh attestation verify Purlay-X.Y.Z-macOS-arm64.zip --repo purlay/purlay-apple`.
2. The run's summary shows it within 10 minutes; if not, note why in the release's pull request.
3. **By hand**, on a Mac with the previous version: Purlay → Check for Updates… offers X.Y.Z, and it installs and opens. First
   launch: notifications, the Dock badge and the login item behave as before (TD-014).
4. In the next pull request that touches the Mac, open `## [X.Y.Z+1] — Unreleased` when the version moves.

## When it goes wrong

- **The gate refuses the commit** (main's CI not finished or failed): a tag cannot be moved or deleted. If CI was still running,
  wait for it and re-run the release (`gh run rerun <run-id>`). If it failed, fix main, raise the patch version, and tag again.
- **Signing or notarization fails:** [signing-credentials.md](signing-credentials.md). Then re-run the failed jobs
  (`gh run rerun <run-id> --failed`); nothing was published.
- **A published release is broken, or its appcast is:** [rollback-mac-release.md](rollback-mac-release.md). Never edit or replace a
  published asset: the feed, the notes and the archive are signed together.
