# Modules and layers

Every module is a target of the root `Package.swift`; the apps are targets of `Apps/Purlay.xcodeproj` that link the modules they
need. Which module may depend on which is a table in `scripts/enforcement`, read against the manifest through
`swift package dump-package`, and a module the table does not name is refused, so a new one is placed on purpose
([ADR 0003](../decisions/0003-layers-and-feature-modules.md)).

## The layers

| Module | Owns | May depend on |
|---|---|---|
| `PurlayContract` | the wire types, endpoints and constants, generated from the pinned bundle (`Generated/`); `Primitives.swift` (`Uuid`, `Timestamp`, `JSONValue`) by hand | nothing |
| `PurlayTokens` | the design values, generated from the bundle's `tokens.json`; `PurlayTokens.swift`, the shapes they are written in | nothing |
| `PurlayKit` | the engine: `AppModel` (one type in many files, `AppModel+<Feature>.swift`), its `AppEnvironment`, sign-in, transport, realtime with replay, the outbox, uploads, markdown; the typed API client (`Generated/PurlayAPI.swift`) | `PurlayContract` |
| `PurlayWords` | what both apps say about what the engine reports (`EngineWords`: its phases, server problems, sign-in failures, notices, upload failures and account erasures), and what both apps' screens say otherwise (`SharedWords`: Cancel, the workspace's places, a message's state), translated once in its own catalogue, `Resources/Localizable.xcstrings`; no UI framework | `PurlayKit`, `PurlayContract` |
| `PurlayTestSupport` | fakes of the network, the Keychain and the browser, `ScriptedTransport`, for package tests | `PurlayKit`, `PurlayContract` |
| `PurlayDesign` | the design system and the only place an OS version is asked about: `purlaySurface`, `purlayButton`, `purlayBottomBar`, `purlayNoticeTransition`, `purlayAnimation`, `PurlayMark`, `Brand`, `Motion` | `PurlayTokens` |
| `PurlayModuleAPI` | `FeatureModule`, `ModuleID` (a string, so an unknown id survives decoding), `ModuleRegistry` | nothing |
| `Feature<Module>` (`FeatureChat` today) | one server module's screens and models, in `Model/`, `Shared/`, `iOS/` and `macOS/` folders | `PurlayKit`, `PurlayContract`, `PurlayTokens`, `PurlayDesign`, `PurlayModuleAPI`, `PurlayWords`; never another feature |
| `PurlayMacUI` | the Mac's screens and controls, until they move onto `PurlayDesign` and into features; whole files are wrapped for macOS so the package builds for iOS | `PurlayKit`, `PurlayContract`, `PurlayTokens`, `PurlayDesign`, `PurlayWords` (it uses all but `PurlayDesign` today) |
| App targets | the composition roots: scenes, the real environment, system adapters | everything above |

`PurlayKit` is grouped by concern: `App`, `Attention`, `Auth`, `Code`, `Composer`, `DeepWork`, `Diagnostics`, `Handshake`,
`Markdown`, `Networking`, `Outbox`, `Palette`, `Realtime`, `State`, `Uploads`.

What the apps link (`Apps/Purlay.xcodeproj`): the iOS app takes Contract, Design, FeatureChat, Kit, ModuleAPI, Tokens and Words; its unit tests take
Contract and Kit, and not TestSupport ([ADR 0006](../decisions/0006-app-tests-use-their-own-fakes.md)); the Mac app takes
Contract, Kit, MacUI (which brings Words), Tokens and Sparkle.

## The rules a compiler does not state

`scripts/enforcement` checks the tree, and `scripts/enforcement --demo` plants each violation in a copy and requires the check
to refuse it, so a rule that stopped looking is seen at once. The rules that read only files (`scripts/enforcement tree`) run in
`scripts/verify rules`, on Linux; the layer rule reads the manifest through SwiftPM (`scripts/enforcement layers`) and runs in
`scripts/verify packages`, on macOS.

| Rule | Why |
|---|---|
| The layer table above; a feature never imports another feature (in the manifest and in the code) | features stay independent; what two need goes into `PurlayModuleAPI` first |
| The engine, its words, the contract, the tokens and the test support import no UI framework | each app draws its own interface; the engine runs anywhere, the watch included |
| `#available`, `#unavailable` and `@available` only under `Sources/PurlayDesign` | one place to audit when an OS version is added or dropped ([ADR 0002](../decisions/0002-platform-floors-and-one-availability-seam.md)) |
| One floor per platform, stated alike in every `Package.swift` and in `Config/` | a floor cannot drift between the package and the apps |
| The project holds no build setting (`"build-settings"` in `project.xcproj`) | every setting is in `Config/*.xcconfig`, where a review sees it |
| Every test target is in a test plan a lane runs | a test no lane runs is not a test |
| No `.package(` in `Package.swift`; the project's only remote packages are Sparkle (and swift-markdown, which is allowed and unused, TD-015) | [ADR 0010](../decisions/0010-no-third-party-code-beyond-sparkle.md) |
| Only `Apps/macOS/App/Updates/` imports Sparkle; `PurlayMacUI` opens no connection | the updater and the network each have one door |
| No `@unchecked Sendable` or `nonisolated(unsafe)` (unless the line says `enforcement-allow` and why) | the compiler's concurrency checking is the guarantee |
| No `try!`, `as!`, `fatalError(`, `unsafelyUnwrapped`, force unwrap or implicitly unwrapped optional in production code | a trap cannot be caught; generated code, `PurlayTestSupport` and tests are not looked at |
| The iOS icon is 1024 × 1024 with no alpha; the Mac icon set has every size; the iOS launch mark is the logo at 120 pt | the App Store refuses an icon with transparency; the launch must not blink |
| The three catalogues (each app's and `PurlayWords`') hold a final value in every language the apps declare (`CFBundleLocalizations`), no stale entry and no sentence the code that reads the catalogue does not say, the same format specifiers, plural forms with `other`, English plural forms (`one` and `other`) for every sentence with a count, and each sentence in one catalogue only; no `Button(Words.…)` | a sentence has one home, so two copies cannot drift; a button built from a resource showed English on a Turkish device |
| A colour literal (a hex value, or components given as numbers) only in the tokens, the logo (`Logo.swift`, written from `Design/purlay.svg` by `scripts/icon`) and `NativePalette.swift`; both apps' accent is the token's | a colour is a token, so the brand is one blue ([ADR 0004](../decisions/0004-the-contract-is-the-servers.md)) |
| The engine names no app: no bundle identifier and no platform in `Sources/`; each app hands in its `AppIdentity` | a default would make a new caller silently the Mac |
| The sign-in's URL scheme is the contract's `nativeRedirect`, never spelt by hand | the server changes it in one place |
| One test package: the contract tests are a test target of `Package.swift` | a second package is built by no lane |
| Every required-reason API the iOS app or the modules it links use is declared in `PrivacyInfo.xcprivacy` | the App Store refuses a build otherwise |
| The Mac's `Info.plist` has `SUPublicEDKey` and `SUFeedURL` | Sparkle checks every update's signature against the key |
| No transport-security exception outside the Debug configuration; no `NSAllowsArbitraryLoads` | Release stays strict |
| The Mac's entitlements are the allowlist; only the Debug file adds library validation off | the sandbox is exactly what is declared |

Other rules are held by other scripts: the generated code by `scripts/generate --check`, the format by `swift-format lint --strict`, the signed Mac app by `scripts/verify macos`, secrets by
`scripts/verify security`.

## Adding a module

1. Add the target (and its test target) to `Package.swift` with the `module(…)` and `tests(…)` helpers, so it takes the strict
   settings.
2. Place it in the layer table in `scripts/enforcement`, with a `--demo` case if the rule changes.
3. Add its test target to the test plan of the lane that runs it (`TestPlans/macOS.xctestplan`; `TestPlans/iOS.xctestplan` too
   only if it has code of its own for iOS, as `PurlayDesign` has: [testing](../development/testing.md)).
4. Write the decision if it is one ([decisions](../decisions/README.md)), and update this page.

A feature for a server module is `Sources/Feature<Module>` (named for the module's id), conforms to `FeatureModule`, and is one
line where the composition root builds the `ModuleRegistry`.
