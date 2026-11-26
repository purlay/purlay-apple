# Move installed Macs to the stable update feed

Installed Macs read their updates from the address in `Config/macOS.xcconfig` (`PURLAY_UPDATE_FEED_URL`). Today that is a GitHub
releases address in another repository, so releases published here do not reach them (TD-019). The owner approved the stable
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

## 3. The bridge release (in the repository installed Macs read today)

Installed Macs (0.3.0 and earlier) still read the old address. One last release there moves them:

1. In that repository, change only the feed its app reads (`SUFeedURL`) to `https://updates.purlay.app/macos/appcast.xml`, set
   the version to 0.3.1, and add the changelog entry. Its build number must stay below the release of step 2 (it is: that
   repository numbers builds by run, in the tens; this one by commit count, in the hundreds).
2. Release it with that repository's own workflow. Installed Macs update to 0.3.1, which reads the stable feed and is offered the
   release of step 2.
3. Check on a Mac with 0.3.0: Check for Updates… offers 0.3.1; after it, Check for Updates… offers the release of step 2.
4. Archive that repository after a week with no problem reports. Its releases stay, so a Mac that skipped 0.3.1 still finds it.

## Afterwards

- Delete TD-019 and the warning in [release-macos.md](release-macos.md).
- The feed is now part of every release: a broken one is fixed as in [rollback-mac-release.md](rollback-mac-release.md#a-bad-appcast).
