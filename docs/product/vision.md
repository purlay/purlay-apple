# Product vision: Purlay for Apple platforms

> Last updated: 2026-11-26 · Owner: the Purlay owner (`@doancan`) · The server's product document: `docs/PRD.md` in
> [`purlay/purlay`](https://github.com/purlay/purlay) · Requirements: [requirements.md](requirements.md)

## Problem

People who run their work in Purlay (team chat today; issues and more modules after it) live in conversations, threads and
notifications. A web client in a browser tab or an installable web app does that badly: it cannot use the system's own
navigation, windows, keyboard and materials, it is easy to lose, and on a phone it cannot be told about a message while it is
closed.

## Target users

- **iPhone (primary on the go):** a member of a Purlay workspace reading and answering messages away from a desk.
- **Mac (primary at a desk):** a member of a team on the hosted service (purlay.app), on an Apple silicon Mac, signed in for
  days at a time and working in other windows.
- **Secondary:** the same person on an iPad, with a larger layout; workspace owners and administrators, who reach the
  administration pages through the app (they open in the browser); a person on a self-hosted server, who needs to point the
  app at it (FR-025 on iOS; Q-007 on the Mac).

## Jobs to be done

- When a conversation in my workspace needs me and I am away from my desk, I want to read it and answer it from my phone, so
  that my team is not waiting on me.
- When my team's conversation is moving and I am working in other windows, I want the Mac to tell me what needs me and let me
  answer without leaving my flow, so that I neither miss what matters nor am pulled out of what I am doing.

## Value over the alternative

- **Native.** SwiftUI, the system's navigation, toolbars, sheets, windows and Liquid Glass; not a web page in a frame.
- **No password in the app.** Sign-in goes through the system browser to the server's own page and returns with a one-time
  code bound to a secret the app keeps (PKCE). The session lives in the Keychain.
- **As modular as the server.** A module the workspace does not run is not shown, and one the app does not know is ignored.
- **Calm by design (Mac).** Deep Work, a focused Inbox, notices that never show what was said, and an idle cost that a test
  holds near zero.
- **Keyboard first (Mac).** A palette, search, a menu item for every action, and shortcuts the app lists.
- **Safe by construction.** The sandbox (Mac), signed and notarized builds, Ed25519-signed updates, strict App Transport
  Security in release builds.
- **Open.** AGPL-3.0, like the server.

## Platforms

| Platform | Floor | Built with | Distribution |
|---|---|---|---|
| iPhone and iPad (one app) | iOS 18 | the iOS 27 SDK; Liquid Glass from iOS 26, a system material before | Not yet: blocked by Q-001 |
| Mac | macOS 26, Apple silicon only | the macOS 27 SDK | Developer ID, notarized, updated by Sparkle |

Apple Watch (inside the iOS app) and Vision Pro (running the iPad app) are later; the structure makes room for both
([ADR 0001](../decisions/0001-one-repository-one-package-one-project.md)).

## Success metrics

| Metric | Target | Measured by | When |
|---|---|---|---|
| Cold load to an interactive channel, warm cache (iOS) | < 1.5 s | the server's performance budget, on a device, once chat ships | first TestFlight with chat |
| Keystroke to own message painted (iOS) | < 16 ms, never awaiting the network | the same budget | first TestFlight with chat |
| An idle signed-in app (both) | two timers, no HTTP request in ten minutes | `IdleBudgetTests` | every pull request |
| Accessibility audit of every shipped iOS screen | zero failures | `performAccessibilityAudit` in the UI tests | each screen, as it ships |
| A pull request's check | mergeable within 3 minutes | the timing summary of every CI run ([ci.md](../development/ci.md)) | every run |
| A release | shipped within 10 minutes of the tag | the release workflow's summary | every release |

Adoption and retention targets are not set: Q-002.

## Where it is

- **Mac:** released; 0.3.0 (2026-11-24) is the latest, with fixes waiting under *Unreleased* in
  [`Apps/macOS/CHANGELOG.md`](../../Apps/macOS/CHANGELOG.md). Functional scope FR-101 to FR-124.
- **iPhone and iPad:** the walking skeleton is done (launch, handshake, sign-in, resuming a session) and the entry screens are
  being designed into the app ([design](../design/entry-shell-account.md), slice 1). Nothing is distributed.

## Non-goals

- A password form, or a web view of the app's own for sign-in.
- Client-side encryption of messages (it would make server-side search impossible; the server's privacy answer is self-hosting).
- Dynamic or downloaded modules: a module is compiled into the app, as the server's modules are.
- Hosting or administering a server: administration opens in the browser.
- A second hand-built design for systems without Liquid Glass; Intel Macs; macOS before 26; Mac Catalyst.
- A shared runtime with the Android client (Kotlin Multiplatform): Android shares the server's contract bundle only.

## Constraints

- **iOS distribution is undecided.** The App Store's terms and the AGPL do not sit together, and iOS has no other channel for
  an ordinary person. Until the owner settles the licensing basis (Q-001, server decision D-338), the iOS app is built,
  tested and archived unsigned, not published.
- **Personal data:** the apps hold a session cookie (Keychain), preferences, drafts and the outbox. No analytics or tracking
  SDK, and no third-party code beyond Sparkle in the Mac app.
- **The contract** is the server's; the apps generate from its published bundle and never write a wire type by hand
  ([ADR 0004](../decisions/0004-the-contract-is-the-servers.md)).
- Swift 6 with complete strict concurrency; AGPL-3.0 with a contributor agreement ([`CLA.md`](../../CLA.md)).
