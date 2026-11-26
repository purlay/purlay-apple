# 0007. Each platform releases on its own, from a tag, trusting main's check

Status: accepted, 2026-11-26

**Context.** The Mac ships through Developer ID and Sparkle; iOS cannot ship until the licensing question is settled (Q-001).
Sparkle offers an update only to a higher build number, and the Mac's 0.3.0 is build 10. Re-running every test on the release's machine takes 6 to 16 minutes on a hosted runner (measured: in the slowest run 505 s went
to the tests and 357 s to a cold signed build, and notarization took 35 s).

**Decision.**
- Each platform has its own `MARKETING_VERSION` (`Config/iOS.xcconfig`, `Config/macOS.xcconfig`), its own changelog
  (`Apps/iOS/CHANGELOG.md`, `Apps/macOS/CHANGELOG.md`) with a section for that version, its own tag (`ios/vX.Y.Z`,
  `macos/vX.Y.Z`) and its own workflow.
- The build number is the commit count (`scripts/build-number`), so it only grows and is the same for both apps at one commit.
- A release does not run the tests again. It refuses a commit whose CI run on main did not succeed, builds Release from the
  compilation cache main keeps warm, and does only what a release adds: sign, notarize, staple, sign the appcast, publish, and
  attest the archive's provenance.
- Signing material lives only in the `release` environment, which needs the owner's approval for each run; the job that
  publishes holds no secret; the job that signs cannot write to the repository. Notarization uses an App Store Connect API key.
- The Mac's update feed is one address, stated once in `Config/macOS.xcconfig` (`PURLAY_UPDATE_FEED_URL`); a release fails
  unless the built app reads it. The stable feed is `https://updates.purlay.app/macos/appcast.xml`, served by this repository's
  GitHub Pages.
- Release tags cannot be moved or deleted: a wrong release is superseded by the next patch version.
- iOS, until Q-001: the tag makes an unsigned Release archive, kept as a workflow artefact, so the path stays working.

**Rejected.** *One version and tag for both platforms:* they ship on different channels and schedules. *Re-running every lane at
release:* minutes of repeated work for a commit that already passed. *The run number as the build number:* it restarts with a new
workflow or repository; the commit count does not. *Xcode Cloud now:* it cannot publish the Sparkle feed or a GitHub release; the
checked-in project keeps it possible later. *The feed at a GitHub releases address:* "latest" follows whichever release is newest,
which could be the other platform's.

**Consequences.** A Mac release takes about four to six minutes ([ci.md](../development/ci.md)). A release depends on main's
cache being warm; a cold one is slower, not wrong. A failed release before publication is re-run, not re-tagged.
