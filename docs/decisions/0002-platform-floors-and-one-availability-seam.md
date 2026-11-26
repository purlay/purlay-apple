# 0002. iOS 18 and macOS 26 floors, the OS 27 SDKs, and one availability seam

Status: accepted, 2026-11-26

**Context.** The apps must run on iOS 18 through 27 and macOS 26 through 27, and use Liquid Glass fully where the system has it.
Every OS-version branch is a place where the two paths can drift.

**Decision.**
- **Floors:** iOS 18.0 and macOS 26.0, each one number, stated alike in `Package.swift` and `Config/iOS.xcconfig` /
  `Config/macOS.xcconfig` (`scripts/enforcement` refuses a second number).
- **SDKs:** built with Xcode 27 and the OS 27 SDKs; the newest APIs are adopted behind the seam as screens need them. CI states its
  Xcode once, in `.github/toolchain.env`.
- **The Mac ships for Apple silicon only** (`ARCHS = arm64`).
- **One seam:** `#available`, `#unavailable` and `@available` exist only in `Sources/PurlayDesign`, as modifiers named by role
  (`purlaySurface(.floatingControl)`, `purlayButton(.primary)`, `purlayBottomBar`). From iOS 26 the system's glass; before, a
  system `Material` in the same shape. Glass is for the navigation layer only, and always the system's own.

**Rejected.** *An iOS 26 floor:* leaves iOS 18–25 devices out. *Two hand-built designs:* doubles the work and the test matrix.
*Drawing glass by hand:* fights the system and its accessibility settings. *`#available` where it is needed:* the checks scatter
and no one can audit them when a version is dropped. *Intel Macs:* a second architecture to sign, notarize and test for few people
(the weighing is Q-005).

**Consequences.** One place to audit for version drift, and one to change when a floor moves. Intel Macs, macOS 15 and earlier,
and iOS 17 and earlier cannot run the apps.
