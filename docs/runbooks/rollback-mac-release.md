# A broken Mac release, or a bad appcast

Sparkle never offers a lower build, so a release is never "rolled back" on Macs that installed it: it is **superseded** by a new
release, with a higher build, made from the last good code. What can be rolled back at once is the feed, so no more Macs take the
broken one.

## A broken release

1. **Stop the spread.**
   - Stable feed (`scripts/ci/feed-url` prints a `pages_path`): re-deploy the last good release's appcast. Find its run
     (`gh run list --workflow release-macos.yml`), its `feed` job's id
     (`gh run view <run-id> --json jobs --jq '.jobs[] | {name, databaseId}'`), then `gh run rerun <run-id> --job <id>`. The rerun
     deploys that run's appcast again (its artefacts are kept 30 days). Check: `curl -s https://updates.purlay.app/macos/appcast.xml | grep shortVersionString`.
   - GitHub releases feed: make the last good release the latest: `gh release edit macos/vGOOD --latest`.
2. **Fix forward.** On main, revert the change that broke it (`git revert`, in a pull request), raise the patch version, date its
   changelog section saying what was fixed, and release it ([release-macos.md](release-macos.md)). Its build number is higher by
   construction (the commit count), so every Mac is offered it.
3. Say in the broken release's notes on GitHub that it is superseded (`gh release edit macos/vBAD --notes-file …`); its signed
   assets stay as they are.

## A bad appcast

The release checks the appcast before publishing (the archive's and notes' addresses, the version, every signature) and the feed
after deploying it, so a bad one is usually stopped before anyone reads it. If one is published anyway:

- **Sparkle refuses it** when a signature does not match: Macs keep what they have and report nothing new. Re-deploy the last
  good appcast as in step 1 above, then release a new patch.
- **A wrong address or version:** same: step 1, then a new patch release. Never edit `appcast.xml` by hand: it is signed.
- **The feed does not answer** (DNS or Pages): check `dig +short CNAME updates.purlay.app` and repository Settings → Pages; the
  steps are in [mac-update-feed.md](mac-update-feed.md#1-the-address-the-owner).
