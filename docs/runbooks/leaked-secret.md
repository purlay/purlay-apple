# A secret is leaked

A secret is leaked the moment it is pushed, pasted or logged anywhere another person can read: assume it is used. **Revoke first;
clean up after.** Removing it from the history does not un-leak it, and rewriting main is refused by the ruleset.

1. **Revoke or rotate it at its issuer, now.**

   | Secret | Where |
   |---|---|
   | Developer ID certificate (`MACOS_CERTIFICATE_P12`, its password) | revoke and replace: [signing-credentials.md](signing-credentials.md) |
   | App Store Connect API key | revoke in App Store Connect, make a new one: [signing-credentials.md](signing-credentials.md#notarization-key-app-store-connect-api-key) |
   | Sparkle private key | [rotate-sparkle-key.md](rotate-sparkle-key.md) |
   | A GitHub token | github.com → Settings → Developer settings → revoke; organisation tokens in the organisation's settings |
   | A session cookie, a server credential | sign the session out on the server; rotate the server credential in the server repository's runbook |

2. **Replace the secret where CI reads it:** `gh secret set NAME --env release --repo purlay/purlay-apple`.
3. **Look for use** since the leak: the issuer's logs (Apple's notarization history, `xcrun notarytool history`), the
   repository's audit log (organisation Settings → Audit log), the Actions runs that could read it.
4. **The history.** Once the secret is revoked, the commit that holds it is harmless: leave the history as it is. So that the scan
   stays green, add the finding's fingerprint (from the `security` job's output, `gitleaks git --redact -v`) to `.gitleaksignore`
   in a pull request that names the revocation. Never add a fingerprint for a secret that is still valid.
5. **Say what happened** in a short note on the pull request that adds the ignore line: what leaked, when it was revoked, what
   use was found.

Prevention is already in place: the pre-commit hook scans staged changes, GitHub's push protection refuses known secret formats
(`.github/settings.md`), and `security` scans the whole history on every CI run.
