# A maintainer loses access

What only one person holds is what is lost with them. Prepare, then recover.

## Prepare (once, and after any change)

- **GitHub:** two-factor on with recovery codes stored offline; a second owner of the `purlay` organisation, so the repository's
  settings, secrets and rulesets can be managed if one account is lost.
- **Apple:** the Developer Program's Account Holder has a second Admin on the team; App Store Connect API keys can be revoked by
  an Admin.
- **Offline backup** (an encrypted vault the second owner can open): the Developer ID certificate and key (`.p12` and its
  password), the App Store Connect `.p8` with its ids, the Sparkle private key (without it no update reaches installed Macs again),
  and access to the DNS of purlay.app.

## Recover

1. **GitHub account:** recover it with the recovery codes (github.com/login → *Two-factor authentication* → recovery code). If it
   cannot be recovered, the second owner removes it from the organisation and adds the new account; update
   `.github/CODEOWNERS` and the `release` environment's required reviewers.
2. **A lost device:** sign out its sessions (GitHub → Settings → Sessions; Apple ID → Devices), revoke its tokens and SSH keys.
3. **Secrets the person could reach:** if their device or account may be in someone else's hands, rotate as in
   [leaked-secret.md](leaked-secret.md).
4. **Apple Account Holder lost:** an Admin requests the transfer through Apple Developer Support; meanwhile a Developer ID
   certificate cannot be created, so do not let the current one expire unplanned.
