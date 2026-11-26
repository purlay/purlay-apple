# Runbooks

Short, executable steps for when something needs doing. Which scenario each answers, and what prevents it, is in
[hardening.md](../development/hardening.md).

| Runbook | When |
|---|---|
| [release-macos.md](release-macos.md) | releasing the Mac app |
| [mac-update-feed.md](mac-update-feed.md) | moving installed Macs to the stable feed: the DNS, Pages, the bridge release |
| [rollback-mac-release.md](rollback-mac-release.md) | a broken Mac release, or a bad appcast |
| [signing-credentials.md](signing-credentials.md) | the Developer ID certificate or the notarization key expired, was revoked, or is wrong |
| [rotate-sparkle-key.md](rotate-sparkle-key.md) | changing Sparkle's EdDSA key |
| [leaked-secret.md](leaked-secret.md) | a secret was pushed, pasted or logged |
| [compromised-action.md](compromised-action.md) | a GitHub Action the workflows use may be malicious |
| [dependency-cve.md](dependency-cve.md) | a vulnerability in Sparkle, an action or a pinned tool |
| [contract-drift.md](contract-drift.md) | the server has released past the pinned contract |
| [ci-outage.md](ci-outage.md) | CI is down or out of macOS runners |
| [xcode-update.md](xcode-update.md) | the runner image's Xcode or simulator changed |
| [flaky-test.md](flaky-test.md) | a test fails and passes on the same code |
| [keychain-in-tests.md](keychain-in-tests.md) | a Keychain or signing failure in a test or an unsigned build |
| [disk-full.md](disk-full.md) | no space left, locally or on a runner |
| [lost-maintainer-access.md](lost-maintainer-access.md) | a maintainer loses an account, a device or the Apple team |
