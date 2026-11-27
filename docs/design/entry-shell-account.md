# Design: entry, shell, and account

> 2026-11-26 · Owner: the Purlay owner · Platform: iPhone and iPad · Requirements: FR-001–FR-004, FR-008, FR-009, FR-020,
> FR-023, FR-025 in [requirements](../product/requirements.md)
>
> **Status:** slice 1 in progress. Built: `PurlayDesign`'s mark, brand, motion and the button, bar and notice seams; the launch
> screen, connecting and Welcome; the notice banners in glass; the decisions for two-step verification and no workspace
> (`RootScreen`). Still to build in slice 1: the Problem screen's design, and the two-step and no-workspace screens.

## Intent

The owner wants the iOS app's screens built from the moment it opens, at the quality of Apple's own apps: Liquid Glass, the
current SDK's APIs, motion that feels physical, and smooth on every supported device. The code under them must be
maintainable at an enterprise level. The owner asked that the gaps they did not name be found and proposed, not left out.

The person who opens the app is usually a team member who was invited and wants to reach their team's conversation. Every
screen before the conversation is in the way. "Premium" here means that the way is short, calm, unmistakably Purlay, and
never stuck.

## Goals

- From launch to signed in in the fewest steps. No marketing carousel.
- Every state the engine can be in has a designed screen: connecting, each server problem, signed out, signing in, loading,
  ready, two-step verification required, and no workspace.
- A shell that grows with the server's modules. A tab bar on iPhone and a sidebar on iPad, from one piece of code.
- An Account sheet with what a person expects there: their profile and status, the workspace, this device's preferences,
  security, about, and sign out.
- Liquid Glass from iOS 26. iOS 18–25 get the same shapes in system materials, behind `PurlayDesign`.
- Smoothness: 120 Hz animations with no dropped frames on launch, in transitions and in the sheet, and none of the app's own
  work on the main thread during an animation.

## Non-goals (this design)

- The chat screens (FR-021, FR-022). They come after the shell and get a design of their own.
- Push notifications, an app lock, several accounts at once, and invite links that open the app.
- A web view of the app's own. Pages that belong to the server open in Safari.

## Anti-goals

- Glass on content, or glass drawn by hand.
- A screen with no way forward. Every problem screen has an action, and every signed-in screen can reach Sign Out.
- Animations that ignore Reduce Motion. Text on glass in `.secondary`.
- An `#available` outside `PurlayDesign`. A literal sentence in a view.

## Constraints (from the repository, unchanged)

- iOS 18 floor and iOS 27 SDK. Version checks only in `PurlayDesign`, as modifiers named by role ([ADR 0002](../decisions/0002-platform-floors-and-one-availability-seam.md)).
- `AppModel` from `PurlayKit` is the one model. Views read it and call it. Slice 1 needs no change to the engine.
- Every sentence is in the app's `Words` and its catalogue, or, for what the engine reports, in `PurlayWords`' `EngineWords`
  and its catalogue, in English and Turkish.
- Each screen is decided from a pure value (`RootScreen`). A tap that must happen once goes through a guard that reads the
  phase (`RootActions`); signing out and reading the account again run once in `AppModel`, which the Mac shares.

## Approaches considered

1. **Polish the existing screens in place** (only `RootView` changes). It is cheap, but the entry, the shell and the account
   end up in one file. Two-step verification and "no workspace" stay hidden behind "ready". Rejected.
2. **Screens in `Apps/iOS/App/`, grouped by flow, with the design seams in `PurlayDesign` (chosen).** `Apps/iOS/App/Entry/` holds the screens
   before the workspace, `Apps/iOS/App/Shell/` the tabs and the workspace switcher, and `Apps/iOS/App/Account/` the sheet. The engine's
   account and settings live in the core, not in a server module, so they are not a `Feature*` package ([ADR 0003](../decisions/0003-layers-and-feature-modules.md) reserves
   those for modules). The brand mark, motion and the button, bar and banner seams go in `PurlayDesign`, because both the
   app and future feature packages draw with them.
3. **A new `PurlayAccount` package.** Logic that can be tested would run on macOS without a simulator. But the account
   screens have little logic of their own (the engine owns it), and a package boundary now would be speculative. Rejected
   for now. The pure parts are tested in the app's tests, as `RootScreen` already is.

## The design

### Flow

```
launch screen (mark on the system background)
   │ the mark stays where it is
connecting ──problem──▶ Problem (a symbol for each problem; Try Again; Update for an app that is too old)
   │
signed out ──▶ Welcome ──Sign In──▶ system browser (PKCE) ──▶ loading ──▶ ready
                  ▲                          │ cancelled: nothing is said
                  └── a notice banner says what went wrong
ready ─┬─ two-step verification required ──▶ "Turn On Two-Step Verification" (browser; Refresh; refreshes itself on return)
       ├─ no workspace ──▶ "You're Not in a Workspace Yet" (open the web; Refresh; Sign Out)
       └─ workspace ──▶ Shell
```

Moving between phases is a cross-fade, because the phases are not steps that can be gone back through. The brand mark is a
single `matchedGeometryEffect` across launch, connecting and Welcome. It moves with `.smooth` and, under Reduce Motion, fades
in place.

### Entry screens

- **Launch screen (`UILaunchScreen`).** The mark as an image on the system background. It matches the first SwiftUI frame
  point for point, so the launch does not "blink".
- **Connecting.** The mark in the launch screen's place. A `ProgressView` appears under it only after 0.5 s, so a fast
  connection shows nothing but the mark. The words name what is under way, as they do today.
- **Welcome (signed out).** The mark (vector, drawn from the logo in `Design/purlay.svg` as a SwiftUI `Shape`, sharp at
  every size), "Purlay", and one line: "Your team's conversations, in your pocket." A bottom bar holds "Sign In" as the one
  prominent glass button and, under it, a secondary line: "You'll continue in your browser on <server host>." The footer
  says that a new account is made on the sign-in page. Every line wraps, at any size, and never ends in "…". Content
  scrolled under the bar takes the mark with it, and the mark is cut at the bar's top edge, as it is at the status bar, so it
  never covers Sign In. The background is a quiet `MeshGradient` in the brand blues. It is
  static under Reduce Motion and when the device runs in Low Power Mode, and otherwise drifts slowly (no faster than one
  cycle in 20 s).
- **Problem.** `ContentUnavailableView` with a symbol for each problem. The action goes in the bottom bar: Try Again, or
  for an app that is too old, Update (only when the server gives a download address; otherwise Try Again). A rate-limited
  server says how long to wait when it says so.
- **Two-step verification required** (`me.mustEnrolTwoFactor`). Set Up in Browser opens `twoFactorSetupURL`. Refresh calls
  `refreshAccount()`, and so does the app coming back to the foreground. Sign Out is in the toolbar.
- **No workspace** (ready, no workspace). Open Purlay on the Web (`webFrontDoor`), Refresh, and Sign Out.
- **Notice banners.** A glass capsule at the top (`purlaySurface(.panel)`), in one `PurlayNoticeStack`; a banner taller than one
  line keeps the capsule's corners. It materializes on iOS 26 and slides with a fade before. VoiceOver announces it, and
  reads the whole sentence. It stays until dismissed, with a dismiss button that is a 44 pt target. It never covers the
  screen: three lines show (one on a landscape iPhone), and Read More opens the whole sentence in a sheet that scrolls.

`RootScreen` gains `.twoFactorRequired` and `.noWorkspace`, decided from the phase and the account, so each is tested
without drawing.

### Shell (FR-020)

- `TabView` with `Tab`s and `.sidebarAdaptable`: a tab bar on iPhone and a sidebar on iPad. The `ModuleRegistry` is built
  in the composition root with the features the app has. With no feature built yet, the shell shows one designed empty
  state ("Chat is coming to this app"), not an empty tab bar.
- **Workspace switcher.** `toolbarTitleMenu` on the workspace name at each tab's root. The sidebar's header on iPad. Each
  membership is listed with its role and a check on the current one, and switching opens the app on that workspace. One
  membership shows the name and no menu.
- **Account.** An avatar button at the top trailing corner, as in the App Store and Music. It opens the Account sheet, with
  a zoom transition on iOS 26 and later.
- Changing workspace resets the tab selection before the tabs change (an iOS 27 pitfall).

### Account sheet (FR-023, part of FR-032)

A `NavigationStack` with a grouped `Form`, `.large` detent, the close button (`Button(role: .close)` on iOS 26).

| Section | Rows | Where |
|---|---|---|
| Header | Avatar, name, title; Set a Status (emoji, text, clear after) | native |
| Profile | Edit Profile: name (read-only, "Managed by GitHub", when it follows GitHub), title, time zone | native, `saveProfile` |
| Workspace | Current workspace and role; Switch; by role: Workspace, Members, Invitations, Integrations, Audit Log, Data | the switch native, the rest web |
| This Device | Appearance (System, Light, Dark), Language (the app's page in Settings) | native |
| Security | Two-Step Verification and Sessions (the account page), Delete Account | web |
| Server | Server Administration, for a server admin only | web |
| About | Server, version and build, Source Code (AGPL), Privacy Policy, Help | mixed |
| — | Sign Out (red, last): a dialog with "Sign Out" and "Sign Out of All Devices" | native, `signOut` |

Web rows open in Safari. Because the sign-in used the shared browser session, Safari is usually signed in already. If it is
not, the server asks the person to sign in, which is acceptable.

Every section that loads data has loading, error with Retry, and empty states. Save shows progress, and a failed save keeps
what was typed.

### Design system (`PurlayDesign`)

Only what these screens use (YAGNI):

- `PurlayMark`: the logo as a `Shape`, with its three gradients.
- `Brand`: colours bound from `PurlayTokens` (accent, onAccent, danger and so on), light and dark. The `AccentColor` asset
  is set to the token accent. Prominent buttons are checked for contrast against white, at 4.5:1 at least.
- `Motion`: `.smooth` and `.snappy` springs, with a Reduce Motion variant chosen in one place (`purlayAnimation`).
- `purlayButton(.primary)`: `.glassProminent` from iOS 26, `.borderedProminent` before.
- `purlayBottomBar { }`: `safeAreaBar(edge: .bottom)` from iOS 26 (with the scroll edge effect), `safeAreaInset` with
  `.bar` before.
- `purlayNoticeTransition()`: the glass materialize transition in a `GlassEffectContainer` from iOS 26, a move with a fade
  before.
- `PurlayCloseButton` and the avatar toolbar item (`sharedBackgroundVisibility(.hidden)` on 26,
  `contentMarginsRemoved()` on 27), added with the shell.

### Quality bar (every screen)

- Dynamic Type up to AX5: the screen scrolls and nothing is clipped. VoiceOver labels and order are right. Targets are at
  least 44 pt. Reduce Motion, Reduce Transparency and Increase Contrast are honoured. Light and dark mode, English and Turkish.
- Previews for each state. Unit tests for every new `RootScreen` and action decision. A `performAccessibilityAudit` UI test
  of the entry screens.
- `make verify` green. Checked in the simulator by eye in both languages and both appearances, at the largest text size.
- Reviewed by the HIG, accessibility and SwiftUI-performance specialist skills before merging.

### Delivery, in slices (one pull request each)

1. **Design foundation and entry:** `PurlayDesign` (the mark, brand, motion, the button, bar and banner seams), the launch
   screen, connecting, Welcome, Problem, two-step, no workspace, the notice banners.
2. **Shell and Account:** the registry, `TabView`, the workspace switcher, the avatar, the Account sheet, Sign Out (FR-023).
3. **Use another server (FR-025):** the address sheet, remembering the server, rebuilding the model for it.
4. **Chat (FR-021, FR-022):** a design of its own.

## Calls made after the builder check

- **Switching workspace (slice 2).** `AppModel` has no public way to switch in place, and `preferredWorkspaceID` is set only by
  `AppModel(environment, workspaceID:)`. The engine's `DesktopSessions` already holds one model per workspace, shares the
  server's session between them and switches with `selectWorkspace(_:from:)`. It is not tied to the Mac. Slice 2 uses it as
  the composition root's owner, so no engine change is needed. Its first step confirms on the simulator that switching does
  not repeat the handshake. If it does, a `PurlayKit` change comes first, in the same pull request.
- **The accessibility audit (slice 1).** The binary gets no fake environment. The decisions are unit-tested. The audit
  (`performAccessibilityAudit`) runs on Welcome and Problem in the existing UI tests (against a server, as today, skipped
  without one). Two-step and No Workspace are checked with Xcode's previews and the Accessibility Inspector, and the PR says so.
- **The shell with no feature (slice 2).** Always one `TabView`. With no feature it has a single tab that shows the empty
  state, with the same toolbar (title menu and avatar). When Chat comes, it becomes a tab beside it and nothing is
  rebuilt. The iPad sidebar header holds the switcher in both cases.

## Left to the builder

The exact sizes and spacing (from the `PurlayTokens` scale), the per-problem symbols, the mesh-gradient points, and the copy's
final wording within the tone above (short, plain, Apple-style title case for titles and buttons).

## Proposals and open questions for the owner (do not block slice 1)

| # | Item | Level | Proposal |
|---|---|---|---|
| P-1 | Account deletion reachable in the app (App Store Guideline 5.1.1(v)) | Must before release | **Native, not web.** The server has `POST /api/me/erase` (body `EraseAccountRequest`: the username typed as confirmation; `403 REAUTHENTICATION_REQUIRED` when the last sign-in is older than `ERASURE_SIGN_IN_MINUTES`; `409 LAST_OWNER`; `204` clears the cookie). It needs no workspace, but the web page for it does. The contract has the type, but `PurlayKit` has no call. Add `AppModel.eraseAccount` to `PurlayKit` (with P-6), and build the Delete Account screen in slice 2: type the username, then on 403 sign in again through the browser and retry |
| P-2 | Report, block and filter user content, plus contact details (Guideline 1.2) | Must before release | Designed with the chat slice |
| P-3 | Sign in with Apple, or a sign-in that shares only name and email (Guideline 4.8), because GitHub sign-in exists | Must check | Check whether the server's email sign-in qualifies |
| P-4 | Privacy policy, terms and support addresses | Must before release | The owner gives the addresses. Until then the rows are hidden |
| P-5 | Source code offer (AGPL §13) | Must | The Source Code row links the repository. The final wording waits on Q-001 |
| P-6 | Sign-out wipes this device's data (drafts, cache, badge) | Must | `SessionManager` has wipers, but `AppModel` passes `wipers: []` and `AppEnvironment` has no field for them. This needs a `PurlayKit` change (`AppEnvironment` gains the wipers): the owner decides whether it goes with slice 2 or later |
| P-7 | A demo account for App Review | Must before submission | On the hosted server |
| P-8 | Ask for notification permission after the first entry, with a short explanation screen first | Should | With push (FR-030) |
| P-10 | An `ios` minimum-client gate: `ClientInfo.minClient` has only `macos`, and the engine reads the macOS minimum for iOS (Q-003) | Must before release | A server PR: contract `minClient.ios`, `MIN_CLIENT_IOS_*` and `IOS_DOWNLOAD_URL`, then `PurlayKit` reads it |
| P-11 | Privacy, terms and support addresses per server: `ClientInfo` carries none, so a self-hosted server cannot show its own | Must before release | A server PR: optional `legal: { privacyUrl, termsUrl, supportUrl }` in `ClientInfo` from configuration. The app shows those rows only when they are present |
| P-9 | Face ID app lock, several accounts at once, invite links | Later | — |
