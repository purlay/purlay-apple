# Entry Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every phase before the workspace a designed, Liquid Glass screen (launch, connecting, Welcome, problems, two-step
verification required, no workspace, notice banners), on design seams in `PurlayDesign`.

**Architecture:** `PurlayDesign` gains the brand (the mark, token colours), motion, and three role-named seams (prominent button,
bottom bar, notice transition), the only place an OS version is checked. The app's `RootScreen` becomes a pure decision over the
phase and the account, and `RootView` hands each case to a screen in `App/Entry/`. The engine (`purlay-swift` 0.2.0) is not changed.

**Tech Stack:** Swift 6 (strict concurrency, warnings are errors), SwiftUI, iOS 18 floor and iOS 27 SDK, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-26-entry-shell-account-design.md` (slice 1).

## Global Constraints

- Before coding, the implementer loads the skills `liquid-glass:liquid-glass`, `liquid-glass:liquid-glass-motion` and
  `swiftui-app-design:swiftui-screens`, and reads `docs/architecture/conventions.md`.
- `#available` only in `Packages/PurlayDesign`, always as `#available(iOS 26, macOS 26, *)` (the packages build for macOS too).
  Toolbar-only APIs are wrapped in `#if os(iOS)`.
- No literal sentence in a view. Every sentence is a `LocalizedStringResource` in `App/Root/Words.swift`, is listed in
  `Words.fixed` when it is fixed, and has a Turkish translation in `App/Resources/Localizable.xcstrings`. Buttons take
  `Text(Words.x)` labels, never `Button(Words.x)`.
- Glass only on the navigation layer (bars, the prominent button, the notice banner). Text on glass is `.primary`, never `.secondary`.
- Every animation the app writes goes through `Motion` (Reduce Motion aware). No `try!`, `!`-unwraps, `fatalError`, `@unchecked Sendable`.
- No new dependency. Do not edit `Purlay.xcodeproj`. Change `project.yml` and run `xcodegen generate`.
- The mark is drawn at **120 pt** wherever it sits in the launch screen's place: the launch screen, connecting, and the start
  of Welcome.
- Commits: conventional style like the history (`feat(app): …`, `feat(design): …`), identity already set in the repo
  config, no AI or co-author lines.

## Review Focus

1. **The largest Dynamic Type size (AX5) on the smallest iPhone (SE, 375 pt).** Welcome, Problem, Two-Step and No Workspace
   scroll, and the bottom bar's button wraps instead of clipping. Check in previews at `.accessibility5`, Task 4 and Task 5.
2. **A fast tap during a phase change.** Sign In, Try Again, Refresh and Sign Out each act once, guarded by phase in
   `RootActions`. Tests in Task 2.
3. **The two-step screen on return from the browser.** Becoming active refreshes the account once, not on every redraw.
   Covered by the `onChange(of: scenePhase)` step in Task 5, and checked by eye.
4. **A notice that arrives while another is shown.** Both stay, in order, each dismissed on its own, and VoiceOver announces
   each once. Task 5, by eye with VoiceOver.
5. **Reduce Motion, Reduce Transparency and Low Power Mode.** The backdrop is static, the mark fades in place, and the iOS 18
   materials do not become see-through. A `Motion` test (Task 1) and previews (Task 4).

---

### Task 1: Design foundation in PurlayDesign

**Files:**
- Create: `Packages/PurlayDesign/Sources/PurlayDesign/Brand.swift`, `PurlayMark.swift`, `Motion.swift`, `Controls.swift`
- Modify: `App/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`, set to the token accent `#2563EB` (0.145, 0.388, 0.922)
- Test: `Packages/PurlayDesign/Tests/PurlayDesignTests/BrandTests.swift`, `MotionTests.swift`, `ControlsTests.swift`

**Interfaces:**
- Produces:
  - `extension Color { init(_ token: TokenColor) }`: a dynamic colour, `light` in light mode and `dark` in dark mode, built
    with `UIColor(dynamicProvider:)` on iOS and `NSColor(name:dynamicProvider:)` on macOS.
  - `public enum Brand { static let accent: Color; static let onAccent: Color; static let ink: Color; static let inkMuted: Color }`,
    each from the `PurlayTokens.Colors` token of the same name.
  - `public struct PurlayMark: View { public init() }`: the three paths of `Design/purlay.svg` with their three linear
    gradients, drawn in the SVG's full 1024×1024 canvas scaled to the view's frame, keeping its aspect ratio. Transcribe the
    `d` attributes into `Path` (`move`, `addLine`, `addCurve`; the SVG's `H` and `V` are absolute). Use `.accessibilityHidden(true)`:
    the word "Purlay" beside it is what is read. Add `public static let launchSize: CGFloat = 120`.
  - `public enum Motion { case smooth, snappy }` and
    `public func animation(reduceMotion: Bool) -> Animation`: `.smooth` gives `.smooth`, and `.snappy` gives `.snappy`. With
    Reduce Motion, both give `.easeInOut(duration: 0.15)`.
  - `extension View { func purlayAnimation<V: Equatable>(_ motion: Motion, value: V) -> some View }`: reads
    `accessibilityReduceMotion` from the environment and applies `.animation(motion.animation(reduceMotion:), value:)`.
  - `public enum ButtonRank { case primary }` and `extension View { func purlayButton(_ rank: ButtonRank) -> some View }`:
    from iOS 26, `.buttonStyle(.glassProminent)`; before, `.buttonStyle(.borderedProminent)`. Both apply `.controlSize(.large)`
    and `.tint(Brand.accent)`.
  - `extension View { func purlayBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View }`: from iOS 26,
    `safeAreaBar(edge: .bottom) { bar }`; before, `safeAreaInset(edge: .bottom) { bar.background(.bar) }`.
  - `extension View { func purlayNoticeTransition() -> some View }`: from iOS 26, `.glassEffectTransition(.materialize)`;
    before, `.transition(.move(edge: .top).combined(with: .opacity))`.
  - `public struct PurlayNoticeStack<Content: View>: View { public init(@ViewBuilder content: () -> Content) }`: from iOS 26,
    a `GlassEffectContainer` around a `VStack(spacing: 8)`; before, the `VStack` alone.

- [ ] **Step 1: Write the failing tests**

```swift
// BrandTests
@Test("white on the accent is readable at body size")
func accentContrast() {
    for appearance in Appearance.allCases {
        let ratio = RGBA.contrast(Colors.onAccent.value(in: appearance), Colors.accent.value(in: appearance))
        #expect(ratio >= 4.5)
    }
}
@Test("the mark can be drawn") @MainActor func mark() { _ = PurlayMark().frame(width: PurlayMark.launchSize) }

// MotionTests
@Test("Reduce Motion turns every movement into a short fade")
func reduceMotion() {
    for motion in [Motion.smooth, .snappy] {
        #expect(motion.animation(reduceMotion: true) == .easeInOut(duration: 0.15))
        #expect(motion.animation(reduceMotion: false) != .easeInOut(duration: 0.15))
    }
}

// ControlsTests (@MainActor): each seam builds
_ = Button(action: {}) { Text("x") }.purlayButton(.primary)
_ = Text("x").purlayBottomBar { Text("y") }
_ = PurlayNoticeStack { Text("x").purlayNoticeTransition() }
```

- [ ] **Step 2: Run `scripts/verify packages`. Expected: FAIL (the types do not exist)**
- [ ] **Step 3: Implement the interfaces above, and set the AccentColor asset**
- [ ] **Step 4: Run `scripts/verify packages` and `scripts/verify rules`. Expected: both pass**
- [ ] **Step 5: Commit** `feat(design): the brand, the mark, motion and the button, bar and notice seams`

### Task 2: The screen decision and its guarded actions

**Files:**
- Modify: `App/Root/RootScreen.swift`
- Test: `Tests/PurlayTests/RootScreenTests.swift`

**Interfaces:**
- Produces:
  - `RootScreen` gains `case twoFactorRequired` and `case noWorkspace`.
  - `init(phase: AppModel.Phase, mustEnrolTwoFactor: Bool, hasWorkspace: Bool)`: `.ready` with two-step required gives
    `.twoFactorRequired`; `.ready` with no workspace gives `.noWorkspace`; `.ready` with a workspace gives `.ready`; every other
    phase maps as today. Two-step comes before no workspace, because a held-back account is given none.
  - `@MainActor init(_ model: AppModel)`: calls the above with `model.phase`, `model.mustEnrolTwoFactor` and
    `model.workspace != nil`. The existing `init(_ phase:)` is removed, and its callers and tests move to the new initializers.
  - `RootActions` gains three actions, each with the guard `model.phase == .ready`:
    - `static func signOut(_ model: AppModel, everywhere: Bool) async`, which calls
      `model.signOut(everywhere ? .everywhere : .thisDevice)`;
    - `static func refreshAccount(_ model: AppModel) async`, which calls `model.refreshAccount()`;
    - `static func reload(_ model: AppModel) async`, which calls `model.connect()`. This is the No Workspace refresh:
      `refreshAccount` loads a workspace only for an account that was held back, so after an invitation is accepted only a
      new connection finds it.

- [ ] **Step 1: Write the failing tests**

```swift
@Test("a ready account is shown what it can do: two-step first, then no workspace, then the workspace")
func readyScreens() {
    #expect(RootScreen(phase: .ready, mustEnrolTwoFactor: true, hasWorkspace: false) == .twoFactorRequired)
    #expect(RootScreen(phase: .ready, mustEnrolTwoFactor: true, hasWorkspace: true) == .twoFactorRequired)
    #expect(RootScreen(phase: .ready, mustEnrolTwoFactor: false, hasWorkspace: false) == .noWorkspace)
    #expect(RootScreen(phase: .ready, mustEnrolTwoFactor: false, hasWorkspace: true) == .ready)
    #expect(RootScreen(phase: .signedOut, mustEnrolTwoFactor: true, hasWorkspace: false) == .signIn)
}
@Test("signing out, refreshing and reloading do nothing unless the account is ready")
func guardedWhenNotReady() async {
    let harness = Harness([Harness.clientInfo()])
    await harness.model.connect()                       // signed out
    let before = await harness.transport.requests.count   // ScriptedTransport is an actor
    await RootActions.signOut(harness.model, everywhere: true)
    await RootActions.refreshAccount(harness.model)
    await RootActions.reload(harness.model)
    #expect(harness.model.phase == .signedOut)
    #expect(await harness.transport.requests.count == before)
}
```

Also update `everyPhase` to the new initializer, with `hasWorkspace: true` for `.ready`.

- [ ] **Step 2: Run `scripts/verify simulator`. Expected: FAIL (the cases and initializers do not exist)**
- [ ] **Step 3: Implement. `RootView` switches on the two new cases with the existing placeholder for now, so it compiles. Task 5 replaces it**
- [ ] **Step 4: Run `scripts/verify simulator`. Expected: PASS**
- [ ] **Step 5: Commit** `feat(app): decide the two-step and no-workspace screens, and guard sign-out and refresh`

### Task 3: A launch screen that matches the first frame

**Files:**
- Modify: `scripts/icon` (also writes the launch mark), `scripts/enforcement` (checks it), `App/Resources/Info.plist`
- Create (generated): `App/Resources/Assets.xcassets/LaunchMark.imageset/{Contents.json,purlay-mark.svg}`

**Interfaces:**
- Produces: an image asset named `LaunchMark`. It is `Design/purlay.svg` with the root `width` and `height` set to `120`
  (the viewBox is unchanged, so the padding is the same as `PurlayMark`'s), with `"preserves-vector-representation": true`.

- [ ] **Step 1: Add a rule to `scripts/enforcement`, with a `--demo` case like the icon's:**
  `LaunchMark.imageset/purlay-mark.svg` exists, and apart from its first `<svg …>` line it is byte-for-byte the same as
  `Design/purlay.svg`. This means a change to the logo cannot leave the launch screen behind.
- [ ] **Step 2: Run `scripts/enforcement` and `scripts/enforcement --demo`. Expected: the check fails on the missing asset, and the demo refuses its planted violation**
- [ ] **Step 3: Extend `scripts/icon` to write the imageset. Run it, and set `UILaunchScreen` to `{ UIImageName: LaunchMark }` (the background stays the system's)**
- [ ] **Step 4: Run `scripts/verify rules` and `scripts/verify build`. Expected: both pass**
- [ ] **Step 5: Commit** `feat(app): a launch screen of the mark, generated from the logo`

### Task 4: Connecting and Welcome, with the mark carried across

**Files:**
- Create: `App/Entry/EntryBackdrop.swift`, `App/Entry/ConnectingView.swift`, `App/Entry/WelcomeView.swift`
- Modify: `App/Root/RootView.swift` (uses them; removes the old `BusyView` and `SignInView`), `App/Root/Words.swift`,
  `App/Resources/Localizable.xcstrings`
- Test: `Tests/PurlayTests/WordsTests.swift` (the new fixed sentences are in `Words.fixed`, so the existing test checks them)

**Interfaces:**
- Consumes: `PurlayMark`, `Motion`/`purlayAnimation`, `purlayButton(.primary)`, `purlayBottomBar` (Task 1); `RootScreen` (Task 2).
- Produces:
  - `RootView` owns `@Namespace private var brand` and passes it to both screens. Each draws the mark with
    `.matchedGeometryEffect(id: "mark", in: brand)`. The `switch` sits inside a `ZStack`, with
    `.purlayAnimation(.smooth, value: screen)` on the `ZStack`, so leaving a screen animates too. `RootScreen` is `Equatable`.
  - `ConnectingView(busy: RootScreen.Busy, brand: Namespace.ID)`: the mark at `PurlayMark.launchSize`, centred on the whole
    screen (`.ignoresSafeArea()`), so it sits where the launch screen put it. The words and a `ProgressView` sit below it, and
    appear only after 500 ms (`.task { try? await Task.sleep(for: .milliseconds(500)); … }`; a `try?` on a sleep is allowed).
  - `WelcomeView(server: String?, brand: Namespace.ID, signIn: () async -> Void)`. Scrolling content: the mark at 120 pt,
    "Purlay" in `.largeTitle.bold()` (a header), and the tagline `Words.tagline` ("Your team's conversations, in your pocket.").
    In `purlayBottomBar`: the `Words.signInButton` button with `.purlayButton(.primary)` and full width, and under it
    `Words.continuesInBrowser(host)` ("You'll continue in your browser on \(host)."), `.footnote`, `.primary` on glass, with
    the host from `model.server?.origin.host()`, falling back to `Words.continuesInBrowserNoHost`. A footer line
    `Words.newAccount` ("New to Purlay? You can create an account on the sign-in page.").
  - `EntryBackdrop()`: a 3×3 `MeshGradient` in the brand blues of the logo (#0759EB, #0EA5EE, #78BDF2, #A8D4F7), at low
    opacity over `Color(.systemBackground)`: 0.18 in light mode, 0.28 in dark. The four centre-edge points move between two
    sets with `.easeInOut(duration: 20).repeatForever(autoreverses: true)`, so SwiftUI interpolates them with no per-frame work
    of ours. It is static when `accessibilityReduceMotion` is on or `ProcessInfo.processInfo.isLowPowerModeEnabled` is true
    (re-read on `.NSProcessInfoPowerStateDidChange`). It sits behind Welcome only and is `.accessibilityHidden(true)`.
  - `Words.signInButton` changes to "Sign In". `signInPrompt` is removed, and `continuesInBrowser` takes its place (Turkish:
    "Giriş Yap"; "Tarayıcında \(host) üzerinde devam edeceksin.").

- [ ] **Step 1: Add the new sentences to `Words` and `Words.fixed` and the catalogue (English keys, Turkish values). Run `scripts/verify simulator`. Expected: `WordsTests` PASS with the new sentences in both languages**
- [ ] **Step 2: Build the three views and wire them into `RootView`. Each view gets `#Preview`s: light, dark, Turkish (`.environment(\.locale, .init(identifier: "tr"))`), `.dynamicTypeSize(.accessibility5)`**
- [ ] **Step 3: Run `scripts/verify build` and `scripts/verify simulator`. Expected: PASS**
- [ ] **Step 4: Render the previews with the Xcode MCP tool `RenderPreview` (ToolSearch `select:mcp__plugin_xcode-integration_xcode__RenderPreview`), and look at each for: no clipping at AX5 on a 375 pt width, the mark centred, the text on glass readable. Fix anything wrong before committing**
- [ ] **Step 5: Commit** `feat(app): connecting and Welcome, with the mark carried from the launch screen`

### Task 5: Problem, Two-Step, No Workspace, and the notice banners

**Files:**
- Create: `App/Entry/ProblemView.swift`, `App/Entry/TwoFactorView.swift`, `App/Entry/NoWorkspaceView.swift`, `App/Entry/NoticeBanner.swift`
- Modify: `App/Root/RootView.swift`, `App/Root/Words.swift`, `App/Resources/Localizable.xcstrings`
- Test: `Tests/PurlayTests/WordsTests.swift`, `Tests/PurlayTests/RootScreenTests.swift`

**Interfaces:**
- Consumes: Task 1's seams; Task 2's `RootScreen` cases and `RootActions.signOut/refreshAccount/reload/retry`.
- Produces:
  - `ProblemView(problem: ServerProblem, retry: () async -> Void)`. `ContentUnavailableView` with `Words.problem(_:)` and a
    symbol per problem, decided by `static func symbol(for: ServerProblem) -> String`:
    - unreachable: `wifi.exclamationmark`
    - not a Purlay server: `questionmark.circle`
    - rate limited: `hourglass`
    - app too old: `arrow.down.app`
    - server too old: `clock.arrow.circlepath`
    - unusable origin: `exclamationmark.triangle`

    The action goes in `purlayBottomBar`. For `.appTooOld` with a `downloadUrl` that parses as an https URL, the button is
    `Words.update` ("Update Purlay") and opens it with `openURL`; otherwise it is Try Again. For `.rateLimited(retryAfter: n)`
    with `n`, the detail is `Words.rateLimited(after:)`: "Try again in \(Duration.seconds(n).formatted(.units(width: .wide)))."
  - `TwoFactorView(setupURL: URL?, refresh: () async -> Void, signOut: (_ everywhere: Bool) async -> Void)`:
    - Title `Words.twoFactorTitle` ("Turn On Two-Step Verification"), detail `Words.twoFactorDetail` ("Your account needs it
      before you can continue. Set it up in your browser, then come back."), symbol `lock.shield`.
    - Bottom bar: `Words.setUpInBrowser` (primary, hidden when `setupURL` is nil), and `Words.refresh` as a plain button that
      shows a `ProgressView` while it runs.
    - `.onChange(of: scenePhase) { old, new in if old != .active && new == .active { Task { await refresh() } } }`.
    - It sits in a `NavigationStack` with a top-trailing `Words.signOut` button that opens the sign-out dialog.
  - `NoWorkspaceView(webURL: URL?, reload: () async -> Void, signOut: (_ everywhere: Bool) async -> Void)`:
    - `Words.noWorkspaceTitle` ("You're Not in a Workspace Yet"), `Words.noWorkspaceDetail` ("Ask a teammate for an
      invitation, or create a workspace on the web."), symbol `person.3`.
    - `Words.openOnWeb` ("Open Purlay on the Web"), primary, hidden when `webURL` is nil.
    - `Words.refresh`, plus the same toolbar Sign Out.
  - The sign-out dialog. This is a `SignOutDialog` view modifier in `App/Entry/SignOutDialog.swift`, shared by both screens
    now and by the Account sheet later:
    - `confirmationDialog(Text(Words.signOutQuestion), isPresented:, titleVisibility: .visible)`, attached to the toolbar
      button itself, so iOS 26 anchors it there.
    - Buttons: `Words.signOut` (destructive, this device), `Words.signOutEverywhere` ("Sign Out of All Devices", destructive),
      and Cancel.
    - Message: `Words.signOutDetail` ("You can sign in again at any time.").
  - `NoticeBanner(text: LocalizedStringResource, dismiss: () -> Void)`:
    - The current row, on `purlaySurface(.panel, in: Capsule())` (it was a rounded rectangle), with `.purlayNoticeTransition()`.
    - On appear, `AccessibilityNotification.Announcement(String(localized: text)).post()`.
    - `RootView`'s top inset holds `PurlayNoticeStack { ForEach(...) { NoticeBanner } }` with `.purlayAnimation(.snappy, value: model.notices)`.
  - `Words.notice` gains sentences for the three sign-out outcomes, now reachable:
    - `.serverNotTold`: "Signed out on this iPhone. The server couldn't be told, so that session ends when it expires."
    - `.signOutEverywhereFailed`: "You couldn't be signed out of all devices. Check your connection and try again."
    - `.signOutFailed`: "You couldn't be signed out. Try again."

    Use "this device" rather than "this iPhone", so the sentence is right on iPad too.

- [ ] **Step 1: Write the failing tests**

```swift
@Test("every server problem has its own symbol")
func symbols() {
    let problems: [ServerProblem] = [.unreachable, .notAPurlayServer, .rateLimited(retryAfter: 30),
        .appTooOld(ClientMinimum(appVersion: "9.0.0", contractVersion: 1, downloadUrl: nil)),
        .serverTooOld(contract: 0), .unusableOrigin("x")]
    #expect(Set(problems.map(ProblemView.symbol(for:))).count == problems.count)
}
@Test("a wait the server names is said in both languages")
func rateLimitedWait() {
    for language in ["en", "tr"] { #expect(text(Words.rateLimited(after: 30), in: language).contains("30")) }
}
@Test("the sign-out outcomes are said, not left generic", arguments: [Notice.Kind.serverNotTold, .signOutEverywhereFailed, .signOutFailed])
func signOutNotices(kind: Notice.Kind) {
    #expect(Words.notice(kind) != nil)
    #expect(text(Words.notice(kind)!, in: "tr") != text(Words.generic, in: "tr"))   // use `guard let` instead of the force unwrap in the real test
}
```

- [ ] **Step 2: Run `scripts/verify simulator`. Expected: FAIL**
- [ ] **Step 3: Implement the views, the dialog, the banner and the sentences, and wire them into `RootView`. Each view gets the same four previews as Task 4**
- [ ] **Step 4: Run `make verify` and `scripts/verify simulator`. Expected: PASS**
- [ ] **Step 5: Render the previews (as in Task 4) and fix what they show**
- [ ] **Step 6: Commit** `feat(app): problem, two-step, no-workspace and notice screens in the system's glass`

### Task 6: Seen running, audited, and documented

**Files:**
- Modify: `Tests/PurlayUITests/SignInFlowTests.swift` (an accessibility audit of Welcome), `docs/README.md` (status),
  `docs/product/requirements.md` (FR-008 and a new FR-009 row), `docs/architecture/overview.md` §4 (the new seams),
  `CHANGELOG.md`

- [ ] **Step 1: Add `testWelcomePassesTheAccessibilityAudit`. It launches the app as the existing tests do, waits for the
  Sign In button, and calls `try app.performAccessibilityAudit()`. It skips itself without a server, as its neighbours do**
- [ ] **Step 2: Run the app in the simulator** (the `run` skill, or `xcodebuild` then `xcrun simctl`), with
  `PURLAY_DEV_SERVER` pointing at an address that does not answer (`http://127.0.0.1:9`). Take screenshots of:
  - launch to Problem, in English and light mode;
  - in Turkish and dark mode;
  - at AX5.

  With a server that answers only the handshake (as in the 2026-11-26 status in `docs/README.md`), take screenshots of
  Welcome in the same three settings. Look at each screenshot. The mark must not jump between the launch screen and the
  first frame.
- [ ] **Step 3: Update the documents.**
  - `docs/README.md`: status, "seen in the simulator", and what was not verified (VoiceOver by ear, iPad, Two-Step and No
    Workspace on a real account).
  - `requirements.md`: FR-009, "Two-step verification required and no workspace each have a screen with a way forward",
    Done, with the tests named.
  - `overview.md` §4: the seams.
  - `CHANGELOG.md`.
- [ ] **Step 4: Run `make verify` and `make verify-all`. Expected: PASS (the UI tests skip without a server)**
- [ ] **Step 5: Commit** `docs: the entry screens, as built and as seen`
