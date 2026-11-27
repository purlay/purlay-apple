# Move installed Macs to the stable update feed

Installed Macs read their updates from the address in `Config/macOS.xcconfig` (`PURLAY_UPDATE_FEED_URL`). Today that is a GitHub
releases address in another repository (purlay-macos, whose 0.3.1 still reads it), so releases published here do not reach them (TD-019). The owner approved the stable
feed **`https://updates.purlay.app/macos/appcast.xml`**, served by this repository's GitHub Pages (decision D2). The release
workflow already deploys the appcast there once `Config/macOS.xcconfig` names it, and fails a release whose built app reads any
other feed.

Do the steps in this order: each makes the next safe, and no Mac is ever pointed at an address that does not answer.

## 1. The address (the owner)

1. **Verify the domain for the organisation** so nobody else can claim it on Pages: organisation Settings → Pages → *Add a
   domain* → `updates.purlay.app`; add the TXT record GitHub shows at the DNS host of purlay.app; *Verify*.
2. **The DNS record:** a `CNAME` from `updates.purlay.app` to `purlay.github.io.` at the DNS host.
   Check: `dig +short CNAME updates.purlay.app` prints `purlay.github.io.`
3. **Pages for this repository:** repository Settings → Pages → *Source: GitHub Actions*; *Custom domain:* `updates.purlay.app`;
   wait for the certificate, then tick *Enforce HTTPS*.
4. The `github-pages` environment that Pages creates accepts deployments from `macos/v*` tags: Settings → Environments →
   github-pages → *Deployment branches and tags* → add the tag pattern `macos/v*`.

## 2. The first release that serves the feed (here)

1. A pull request `build(macos): read updates from the stable feed` changes one line in `Config/macOS.xcconfig`:
   `PURLAY_UPDATE_FEED_URL = https:/$()/updates.purlay.app/macos/appcast.xml`, raises `MARKETING_VERSION` to the next patch, and
   adds its changelog section. `scripts/ci/feed-url` then prints `pages_path=macos/appcast.xml`.
2. Release it ([release-macos.md](release-macos.md)). The `feed` job deploys the appcast and fails unless
   `https://updates.purlay.app/macos/appcast.xml` offers that version. Check by hand:
   `curl -s https://updates.purlay.app/macos/appcast.xml | grep shortVersionString`.

## 3. The bridge (in the repository installed Macs read today)

purlay-macos released 0.3.1 (build 11) on 2026-11-27 without moving the feed: its app and its appcast still name
`https://github.com/purlay/purlay-macos/releases/latest/download/appcast.xml`. Installed Macs (0.3.1 and earlier) read that
address, so the bridge is still owed, and it can no longer be numbered 0.3.1. This repository's next Mac version is 0.3.2
(`Config/macOS.xcconfig`). The owner chooses one of two bridges:

- **A bridge release from purlay-macos, 0.3.2.** In that repository, change only the feed its app reads (`SUFeedURL`) to
  `https://updates.purlay.app/macos/appcast.xml`, set the version to 0.3.2 and add the changelog entry, and release it with that
  repository's own workflow. Its build (that repository numbers builds by run, in the tens) stays below the release of step 2
  (this one numbers builds by commit count, in the hundreds). The pull request of step 2 then raises this repository's `MARKETING_VERSION` to 0.3.3 and renames the
  changelog's 0.3.2 section, so no version is used twice.
- **A bridge appcast, no new build there.** Release this repository's 0.3.2 (step 2) first. Then publish one more release in
  purlay-macos, marked latest, whose only asset is an `appcast.xml` that offers that 0.3.2 archive (signed with the same
  Sparkle key: `scripts/sign-release` signs it). Installed Macs update straight to 0.3.2, which reads the stable feed. purlay-macos
  is frozen, so this needs the owner's approval for a release there.

Either way:

1. Check on a Mac with 0.3.1: Check for Updates… offers the bridge (or 0.3.2); after it, Check for Updates… reads
   `https://updates.purlay.app/macos/appcast.xml`.
2. Archive purlay-macos after a week with no problem reports. Its releases stay, so a Mac that skipped the bridge still finds it.

## Afterwards

- Delete TD-019 and the warning in [release-macos.md](release-macos.md).
- The feed is now part of every release: a broken one is fixed as in [rollback-mac-release.md](rollback-mac-release.md#a-bad-appcast).
