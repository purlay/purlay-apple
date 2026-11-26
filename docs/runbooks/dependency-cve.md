# A vulnerability in a dependency

The apps ship one third-party library, Sparkle (Mac only); CI uses GitHub Actions pinned by commit and gitleaks pinned by digest.

1. **Read the alert** (Security → Dependabot, a GitHub advisory, Sparkle's release notes): which version is affected, and is the
   vulnerable code reached by the apps or by CI?
2. **Sparkle:**
   - Check the version pinned in `Apps/Purlay.xcodeproj` (Xcode → the project → Package Dependencies; today 2.10.1).
   - Move the pin in Xcode to the fixed version in its own pull request, `fix(macos): Sparkle X.Y.Z`; check
     `licenses/Sparkle.txt`.
   - `make verify-all`, then release a Mac patch ([release-macos.md](release-macos.md)) so installed Macs get the fix.
3. **An action:** merge Dependabot's pull request, or move the pinned commit by hand to the fixed release (`gh api
   repos/<owner>/<action>/commits/<tag> --jq .sha`), keeping the version in the comment. If the action may have been abused,
   [compromised-action.md](compromised-action.md).
4. **gitleaks:** change `VERSION` and the three digests in `scripts/install-gitleaks` to those GitHub shows for the fixed
   release's assets; `make setup && make verify-security`.
5. **Xcode or the toolchain:** [xcode-update.md](xcode-update.md).
