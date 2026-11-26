# A compromised GitHub Action

Every action is pinned by full commit, so a moved tag does not reach this repository. A commit that was malicious when it was
pinned, or a Dependabot update to one, can.

1. **Stop it running:** `gh workflow disable "<workflow name>" --repo purlay/purlay-apple` for each workflow that uses it
   (`grep -rn '<owner>/<action>' .github/workflows`).
2. **Which runs used it,** and what they could reach: `gh run list --workflow <file> --limit 50`. Only the `build` job of
   `release-macos.yml` sees signing secrets, and only after the owner approved the `release` environment; other jobs hold a
   token limited to their `permissions:` and expiring with the job.
3. **Rotate what it could reach.** If it ran in an approved release: every secret of the `release` environment
   ([signing-credentials.md](signing-credentials.md), [rotate-sparkle-key.md](rotate-sparkle-key.md)). Check the audit log for
   pushes, releases and settings changes made by `github-actions[bot]` during those runs.
4. **Releases made with it:** check each archive against its attestation
   (`gh attestation verify Purlay-X.Y.Z-macOS-arm64.zip --repo purlay/purlay-apple`) and its notarization
   (`spctl --assess --type execute --verbose=2 Purlay.app`). If one cannot be trusted, supersede it
   ([rollback-mac-release.md](rollback-mac-release.md)).
5. **Replace it:** pin a known-good commit, or remove the action, in a pull request; re-enable the workflows.
