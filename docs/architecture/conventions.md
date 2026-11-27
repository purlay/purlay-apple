# Code conventions

Only what is specific to this repository and checkable. A rule held by a tool names the tool; the rest is held by review. The
module rules are in [modules-and-layers.md](modules-and-layers.md).

## Tools

| Purpose | Tool | Where |
|---|---|---|
| Format | `xcrun swift-format lint --strict` (Xcode's toolchain): 120 columns, 4 spaces | `.swift-format`; the `packages` lane, and the pre-commit hook on staged files |
| Compiler | Swift 6 language mode, complete strict concurrency, every warning an error | `Package.swift` (`strict`), `Config/Shared.xcconfig` |
| Architecture rules | `scripts/enforcement`, and `--demo`, which plants each violation and requires the refusal, and writes valid code a rule must leave alone and requires it accepted | the `rules` lane |
| Strings | `scripts/enforcement`: one checker for the three catalogues; `scripts/localize` adds the Mac's and the engine's new sentences | the `rules` lane |
| Generated code | `scripts/generate --check` | the `generated` lane |
| Tests | Swift Testing (`@Test`, `@Suite`, `#expect`); XCUITest for the iOS sign-in only | `Tests/` (`Tests/ContractTests` among them), `Apps/iOS/Tests/`, `Tools/PurlayGen/Tests/` |
| Secrets | gitleaks, pinned, over the whole history; the pre-commit hook on staged changes | `scripts/verify security`, [ADR 0005](../decisions/0005-make-verify-and-a-secret-scan.md) |
| Commit messages | conventional commits (`type(scope): what changed`) | `.githooks/commit-msg`; the squash title is the message that lands |
| Verify | `make verify` before pushing; `make verify-all` as a release does | `Makefile` over `scripts/verify` |

## Layout and naming

- An app target is a thin composition root: scenes, the real environment, system adapters, one screen per phase (iOS). What the
  app does lives in a module.
- A file is named for the main type it holds. A test file is named for the behaviour it holds (`ConnectionReplayTests.swift`); a
  test's name states the behaviour in a sentence.
- `Sources/*/Generated` is written by `scripts/generate` and never edited by hand. A change to what is generated is a change to
  `Tools/PurlayGen`, with its tests, or a new contract pin ([contract.md](../development/contract.md)).
- `Apps/Purlay.xcodeproj` is changed in Xcode, never by hand or by a generator, and holds no build setting: a setting goes in
  `Config/*.xcconfig` (`Shared` for both apps, `iOS`, `iOSTests`, `iOSUITests`, `macOS`, and `Debug` or `Release`). New files in
  `Apps/iOS/App`, `Apps/iOS/Tests/*` and `Apps/macOS/App` need no registration: those folders are synchronized.
- Bundle ids: `dev.purlay.ios` (tests `dev.purlay.ios.tests`, `dev.purlay.ios.uitests`) and `dev.purlay.mac`, which never
  changes (the Keychain and Sparkle depend on it).
- Icons are generated: `scripts/icon` writes both apps' icon sets and the iOS launch mark from `Design/purlay.svg`. Change the
  SVG and run the script; never edit a PNG.
- Each app's version is `MARKETING_VERSION` in `Config/iOS.xcconfig` or `Config/macOS.xcconfig`; the build number is the commit
  count, written by `scripts/build-number` into the ignored `Config/BuildNumber.xcconfig`.

## Layers and state

- Views read an `@Observable` model and call it; they never reach the network, the Keychain or the clock. The model is
  `AppModel` from `PurlayKit`; a feature adds its own models beside its views.
- Everything the platform provides (network, Keychain, defaults, browser, files, timers, attention) reaches the model through
  `AppEnvironment`, built in each app's composition root. Platform-specific acts arrive as protocols the app implements
  (`AttentionPresenter`, `WebAuthenticator`, `PreferenceStore`).
- A screen is decided from a pure value (`RootScreen` on iOS) so each state is tested without drawing. A tap that must happen
  once goes through a guard that reads the phase (`RootActions`), never a flag in the view. What leaves the phase as it is while
  the server answers (signing out, erasing the account, signing in again, reading the account again) runs once in the model,
  for both apps: a call meanwhile waits for the one under way. Signing out and erasing share one slot, so they never overlap.
- Colour, spacing, type and motion come from `PurlayTokens`: through `PurlayDesign` on iOS, through `TokenBinding.swift` and
  `NativePalette.swift` on the Mac. A view names a token, never a colour of its own; a colour literal is allowed only in the
  tokens, the logo and `NativePalette.swift` (enforced, comments aside). The only colour set in an asset catalogue is each
  app's `AccentColor`, held to the accent token (enforced).
- Liquid Glass belongs on the navigation layer, never on content, and is the system's own (`purlaySurface`, the glass button
  styles), never drawn by hand.

## Errors

- A failure is a typed value (`APIError`, `TransportError`, `HandshakeError`, `SignInError`, `ServerProblem`, `UploadFailure`,
  `SendFailure`, `EraseAccountResult`, `ReauthenticationResult`) that the model turns into what the person is told. A server problem is a phase, never an alert that can be
  dismissed into a broken state.
- Wire error codes are matched from the generated union; an unknown id or code is ignored or shown generically, never a crash.
- A failure shown to a person is a sentence written for them. The server's `message` is English and written for a log, so it is
  never shown, and neither is `String(describing:)` of an error. Each `ServerProblem`, `SignInError`, notice, upload failure
  `EraseAccountResult` and `ReauthenticationResult` has its sentence in `PurlayWords`' `EngineWords`, matched exhaustively, so a new case fails to compile until it has words.
- No empty `catch`, no `_ = error`, no silent fallback. A `try?` is acceptable only for work whose failure changes nothing
  (cancelling a sleep). A failure is shown, retried by a stated rule, or logged with its cause.

## Concurrency

- `@MainActor` for everything that touches a view or a model a view reads; `Sendable` across boundaries (the compiler checks).
- Shared mutable state lives in an actor, a `Mutex`, or behind the model. A bridge from a callback API to async code answers
  exactly once (`Answer` in `Apps/iOS/App/Environment/WebAuthSession.swift`).
- `DispatchQueue.main.async` only for one run-loop turn AppKit needs, and `Task.detached` only for file and image work off the
  main actor; each use says why on or above the line. View-bound work uses `.task`, which cancels with the view.
- A test never sleeps a guessed time and then asserts: it waits for the condition (`eventually`).

## Tests

- New behaviour comes with a test; a bug fix starts with a failing regression test. Test the behaviour a document states, not
  the implementation.
- Logic is tested in the module that owns it, on macOS, without a simulator. The iOS app's own tests cover wiring and screen
  decisions; they use `Apps/iOS/Tests/PurlayTests/Fakes.swift`, not `PurlayTestSupport`
  ([ADR 0006](../decisions/0006-app-tests-use-their-own-fakes.md)).
- Replace only the system's edges (network, Keychain, browser, clock, timers), as protocol implementations; never the code under
  test.
- A screen that shows data has loading, empty and error states, accessibility labels, and a guard against a double submit. A new
  or changed Mac screen adds its states to `SnapshotTests`.
- What a test cannot reach is listed in [testing.md](../development/testing.md) and checked by hand.

## Privacy and logging

- The session lives only in the Keychain; never in `Info.plist`, defaults or source. Session material never goes to a log.
- `Log` is the engine's logger; a message carries an id or a code, not a message body, an address or a token. The iOS app logs
  with `os.Logger` at the default privacy, and only its development shortcuts log today; the Mac app writes no log of its own.
- Debug-only shortcuts (`PURLAY_DEV_SERVER`, `PURLAY_DEV_SESSION`, `PURLAY_DEV_RESET`) are compiled out of Release.
- `Apps/iOS/App/Resources/PrivacyInfo.xcprivacy` declares every required-reason API the code uses; `scripts/enforcement` refuses
  code that uses one it does not declare.
- A notice the system shows never carries what was said.
- What the app keeps of a person on the device is removed through a `UserDataWiper`. The engine makes its own from each
  model's environment (the drafts in its preferences, the outbox in its data directory, the Quick Look copies in its cache
  directory), so a new kind of per-person data is kept under one of those, or comes with a wiper in `AppEnvironment.wipers`.
  `SessionManager` runs each once when the person signs out or their account is erased, and when another person signs in
  where they were; a wiper that throws does not stop the others, and is logged by its type and error code, never the error's
  description, which can name a file.

## Strings and screens

- Every sentence a person reads is in one catalogue (`Localizable.xcstrings`), English as the source and Turkish complete. What
  both apps say about the engine is `PurlayWords`' (`EngineWords`, its own catalogue); what only one app says is that app's: on
  iOS a `LocalizedStringResource` in `Words.swift`, on the Mac English in the code (`Strings.swift`, `Text("…")`). For the Mac
  and the engine, `scripts/localize` adds new sentences to their catalogues. A view never writes a literal sentence on iOS.
  A sentence lives in one catalogue only, and every sentence in a catalogue is a string literal in the code that reads that
  catalogue: the iOS app's, the Mac app's with `PurlayMacUI`, `PurlayWords`' (enforced). A sentence the code stopped saying
  is removed; the catalogues keep no extraction state, so `stale` alone would never show it. The literal counts where it is
  said as a sentence, never in a comment: an argument of a call the SDK declares as taking one (`scripts/lib/sentence_calls.py`,
  written by `scripts/dev/sentence-calls` from the interfaces of SwiftUI, Foundation, App Intents, WidgetKit, Charts, AppKit
  and UIKit, and checked against the SDK by the packages lane), an argument of a function or initialiser of the repository's
  own code (any module, so a design-system component counts) whose parameter or property is typed `LocalizedStringKey`,
  `LocalizedStringResource`, `String.LocalizationValue` or `IntentDialog` (or an array of them), the value of a declaration so
  typed (a ternary of literals too) or a literal its computed body gives, or an assignment to a property so typed, through
  `self` or a value whose type the code states. The same literal given to an API that takes a `String` does not count. The
  rules that read Swift and data are in `scripts/lib/rules.py`.
- A sentence with a count (`%lld`, `%d`, `%i`…) has English plural forms whose `one` is not its `other` (enforced), unless the
  count changes no English word ("Filters (%lld)"): those are listed in `scripts/lib/rules.py`, and a new one is a review
  point. A sentence with two counts has them as Xcode writes them, substitutions (`%#@messages@ in %#@channels@`), each with
  its own forms. That the `one` form is the right singular is a review point too. Turkish says a count with one form, so its
  value may be a single one.
- A button is built from a `Text` label: `Button(Words.x)` showed English on a Turkish simulator (enforced).
- Turkish addresses the person as "sen", as the web client does; its wording follows `apps/web/src/i18n/catalogue/tr.ts` of the
  server repository.
- Titles and buttons in Apple-style title case. Every control has an accessibility label; text uses Dynamic Type and scrolls
  instead of clipping; Reduce Motion, Reduce Transparency and Increase Contrast are honoured; nothing is said by colour alone.

## The Mac specifically

- The sandbox's entitlements are an allowlist. A new entitlement needs a reason, a decision, and a change to the allowlists in
  `scripts/enforcement` and `scripts/verify`.
- Permissions (notifications, the Dock badge, the login item) are asked for the first time there is something to tell, never at
  launch. They cannot be tested here; they are checked by hand on a signed build.
- Development builds can be signed with this Mac's own identity (`scripts/dev-signing`), so the Keychain's "Always Allow"
  survives a rebuild; releases are signed with Developer ID in CI, never with it.

## Forbidden patterns

| Forbidden | Instead | Why |
|---|---|---|
| `try!`, `as!`, `x!`, `T!`, `fatalError(` in production code | a typed error, `guard`, optional handling | enforced; a trap cannot be caught |
| `@unchecked Sendable`, `nonisolated(unsafe)` without `enforcement-allow` and a reason | an actor, a `Mutex`, a value type | enforced |
| `#available` outside `PurlayDesign` | a `PurlayDesign` modifier named by role | enforced, ADR 0002 |
| A feature importing a feature | `PurlayModuleAPI` | enforced, ADR 0003 |
| A package dependency, or a project dependency beyond Sparkle | the standard library, or a decision first | enforced, ADR 0010 |
| `URLSession` and friends in `PurlayMacUI`; `import Sparkle` outside `Apps/macOS/App/Updates` | `PurlayKit`'s protocols; `UpdateController` | enforced |
| Editing a file under `Generated/` | the bundle pin or `Tools/PurlayGen` | `scripts/generate --check` |
| A build setting in the project file | `Config/*.xcconfig` | enforced |
| A string with no final Turkish value | the Turkish value in the catalogue | enforced |
| A catalogue sentence no code that reads the catalogue says | remove it from the catalogue | enforced |
| `Button(Words.x)`, a literal sentence in an iOS view, `String(describing:)` of an error shown to a person | a `Text(Words.x)` label; a sentence in `Words` | the catalogue; a person is not shown a developer's text |
| Linking `PurlayTestSupport` into the iOS app's tests | `Apps/iOS/Tests/PurlayTests/Fakes.swift` | ADR 0006 |
| Lowering strict concurrency, silencing a warning, `// swift-format-ignore` without a reason | fix the cause | the compiler is the first reviewer |
| Drawing glass by hand | `purlaySurface` and the system's glass styles | ADR 0002 |
| Editing a published release asset | a new patch release | the feed, the notes and the archive are signed together |

## Old patterns, not for new code

- **Citations of plan sections** in the Mac code's comments (`§12.3`, `M-8`, `M6-1`) point at a plan that is not in the
  repository (TD-011, Q-006). Cite a document, a decision or the server's `D-xxx` decision instead.
- **`NativePalette.swift`** holds the Mac's neutral greys and status colours as literals, because no token states them yet. Its
  blue is the accent token. Do not add a colour there that a token states.
