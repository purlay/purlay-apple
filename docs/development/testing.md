# Testing

Tests are written to the behaviour a document states and to the contract's own fixtures, not to the implementation. Faults are
injected at the system's edges (`HTTPTransport`, `OpenSocket`, the Keychain, the browser, the clock and the timers), never by
replacing the code under test. The conventions are in [conventions.md](../architecture/conventions.md#tests).

## Where each kind of test lives, and which lane runs it

| What | Where | Test plan | Lane |
|---|---|---|---|
| The engine: state, transport, sign-in, realtime, outbox, markdown | `Tests/PurlayKitTests` | `TestPlans/macOS.xctestplan` | `packages` |
| The contract, the tokens, the test support | `Tests/PurlayContractTests`, `Tests/PurlayTokensTests`, `Tests/PurlayTestSupportTests` | `macOS` | `packages` |
| The module registry | `Tests/PurlayModuleAPITests` | `macOS` | `packages` |
| The chat feature's decisions (what a message row may show) | `Tests/FeatureChatTests` | `macOS` | `packages` |
| The design system, whose colours take a UIKit path on iOS and an AppKit path on macOS | `Tests/PurlayDesignTests` | `macOS`, `iOS` | `packages`, `simulator` |
| The Mac's screens and controls, and the Mac screens drawn from state, light and dark | `Tests/PurlayMacUITests` (`SnapshotTests` among them) | `macOS` | `packages` |
| The iOS app's wiring and screen decisions (`RootScreenTests`, `WordsTests`, `EnvironmentTests`, `PrivacyManifestTests`, `WorkspaceShellTests`, `NoticeWordsTests`) | `Apps/iOS/Tests/PurlayTests` | `iOS` | `simulator` |
| The iOS sign-in against a real server, and the shell, Chat, the composer and sign-out against fixtures (each skips without its server, TD-028) | `Apps/iOS/Tests/PurlayUITests` | `iOS` | `simulator` |
| The generator | `Tools/PurlayGen/Tests` | its own package | `generated` |
| What both apps say, in each language (`EngineWordsTests`, `SharedWordsTests`) | `Tests/PurlayWordsTests` | `macOS` | `packages` |
| The real client against a real server of the pinned version | `Tests/ContractTests` | `macOS` (compiled, and skipped without a server) | `packages`; against a server by hand: `scripts/contract-test` (TD-017) |
| The rules, each with its violation planted (refused) and, where a rule could refuse good code, valid code written (accepted); each on its own copy, in parallel | `scripts/enforcement`, `--demo` | — | `rules` |
| The strings: the four catalogues (the Mac's App Shortcut phrases among them), one checker | `scripts/enforcement` | — | `rules` |
| The built apps: build number, App Transport Security, the Mac's entitlements declared and signed | `scripts/verify ios`, `scripts/verify macos` | — | `ios`, `macos` |
| Secrets | `scripts/verify security` | — | `security` |

`scripts/enforcement` refuses a test target that no lane's test plan names, so a new test target is never silently skipped.

Logic is tested once, in its package, on macOS. The simulator runs only what needs iOS: the app's own tests and the UI tests
(`TestPlans/iOS`) and `PurlayDesignTests`, because `PurlayDesign` is the one package with code of its own for UIKit
(`Brand.swift`). A package test added to `TestPlans/iOS` needs such a reason, said in the plan's row above.

The Mac snapshots run where `PURLAY_SNAPSHOT_DIR` names a folder; `scripts/verify packages` sets it (as
`TEST_RUNNER_PURLAY_SNAPSHOT_DIR`) to a temporary folder and fails if no screen was drawn. To keep the pictures:

```sh
TEST_RUNNER_PURLAY_SNAPSHOT_DIR=/tmp/screens xcodebuild -project Apps/Purlay.xcodeproj -scheme Purlay-macOS -testPlan macOS \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

## What is held to the server's own fixtures

The pinned bundle (`Contract/bundle/fixtures`, fetched by `make setup`) carries what a second implementation is held to. Message
ids (what is made, what is refused, the plausibility window) are checked in `RealtimePrimitivesTests`; the markdown conformance
corpus in `MarkdownCorpusTests`, with its known divergences listed in `MarkdownDivergences`.

## Ports of the web client's tests

The web client's realtime tests (`apps/web/src/realtime/` in the server repository) are the engine's test plan, ported case by
case, by name. All are in `Tests/PurlayKitTests` unless said otherwise.

| Web | Here | State |
|---|---|---|
| `backoff.test.ts`, `cursors.test.ts`, `server-clock.test.ts` | `RealtimePrimitivesTests` | ported |
| `connection.test.ts` | `ConnectionTests`, `ConnectionNetworkTests`, `ConnectionReplayTests` | ported, every case |
| `socket.test.ts` | `Tests/ContractTests/LiveSocketTests.swift` | against the real server (the transport is `URLSession`'s; a fake would test the fake) |
| `pending-store.ts`, the send cases of `engine.test.ts` | `OutboxStoreTests`, `SendCoordinatorTests` | ported |
| `engine.test.ts` (frames, replay, refused subscriptions, routing) | `ChatStateTests`, `ChannelWindowTests`, `EngineTests` | ported by behaviour |

## What no automated test reaches

Checked by hand on a signed build, and said so in the pull request:

- The Mac's notification, Dock-badge and login-item permissions, and Sparkle's update of an installed app (TD-014).
- Approving the sign-in in the system browser's page (TD-007).
- VoiceOver by ear, scrolling by touch, and iPad layouts.
- The Mac's App Intents run through Shortcuts, Spotlight and Siri (in English and Turkish), a reply typed into a notice's
  Reply field, and Handoff picked up on another device. What they decide is tested in `OutsideRequestsTests` and
  `WebPageTests`; the system's side is not reachable from a test.
- The rows a feed draws inside its scroll view: the Mac snapshots leave a scroll view's contents out (TD-032).

## Tests that need the Keychain

`scripts/verify` and CI build unsigned (`CODE_SIGNING_ALLOWED=NO`). On macOS the package tests use `PurlayTestSupport`'s in-memory
session store, and `KeychainSessionStoreTests` uses the real Keychain of the test process. On a simulator, an unsigned app cannot
read the Keychain, so it starts signed out and says it could not read the saved sign-in. A test that fails only for that reason is not a flaky
test: [runbook](../runbooks/keychain-in-tests.md).

## Flaky tests

A test that fails without a change is a bug in the test or the code, never noise. CI retries a lane only when the machine failed
(a simulator that would not boot, a download that did not arrive), never when a test did, and says so on the run
([runbook](../runbooks/flaky-test.md)). A test never sleeps a guessed time and then asserts: it waits for the condition
(`eventually`).
