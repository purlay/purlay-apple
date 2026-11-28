# Getting started

## What you need

- An Apple silicon Mac on macOS 26 or later, with **Xcode 27.2** or later: `Apps/Purlay.xcodeproj` is in the JSON project format,
  which Xcode 27.2 is the first to read. CI uses exactly the Xcode `.github/toolchain.env` names. With several Xcodes installed,
  choose one for the command line with `DEVELOPER_DIR=/Applications/Xcode_27.2.app/Contents/Developer` or `xcode-select`.
- `gh`, signed in (`gh auth login`): `make setup` downloads the contract bundle from the server's release with it.
- Python 3 (the system's is enough) and the network for the first `make setup`.

## Set up

```sh
git clone https://github.com/purlay/purlay-apple.git && cd purlay-apple
make setup        # the pinned contract bundle (Contract/bundle), gitleaks, and the git hooks (.githooks)
make verify       # what a pull request needs: the rules, format and every package test, both apps built
```

Open `Apps/Purlay.xcodeproj` in Xcode. The schemes are `Purlay-iOS` (iPhone and iPad) and `Purlay-macOS`. The modules are the
root package, which the project uses by path; their tests run in the `Purlay-macOS` scheme's `macOS` test plan.

The hooks run in under a second: a staged Swift file must pass `swift-format lint --strict`, the staged changes must hold no
secret, and the message must be a conventional commit. `git commit --no-verify` skips them, and CI checks the same things anyway.
`scripts/dev/install-hooks --remove` turns them off for your clone.

## Checking a change

```sh
make verify             # rules, packages, ios, macos: what a pull request needs
make verify-security    # the history scanned for secrets
make verify-all         # every lane: the generated code, the Mac's Release build and the simulator too (what a release relies on)
scripts/verify <lane>   # one lane: rules | generated | packages | ios | macos [CONFIGURATIONS] | simulator | security
```

Measured on a developer's Apple silicon Mac with a warm cache (2026-11-26): `rules` 50–85 s, `generated` 12 s, `packages` 90 s,
`ios` 91 s, `macos Release` 120 s, `simulator` 62 s. Compiled code is cached by content in
`~/Library/Caches/dev.purlay/compilation-cache` (or `PURLAY_CACHE_DIR`), shared by every checkout on the Mac, so a second run and
a fresh worktree are fast. `make clean` frees that cache and this checkout's build folders when the disk is full
([runbook](../runbooks/disk-full.md)).

Every build is numbered with the commit count (`scripts/build-number`), so a shallow clone cannot build: fetch the whole history.

## Running the apps

**Against a local server.** In a checkout of `purlay/purlay`: `bun run db:up && bun run db:migrate && bun run dev`. Launch a Debug
build with `PURLAY_DEV_SERVER=http://localhost:<port>` in the scheme's environment. Plain HTTP is allowed in Debug builds only.
`PURLAY_DEV_SESSION` seeds a stored session's cookie value, and `PURLAY_DEV_RESET=1` (iOS) forgets the stored session first.
Release builds talk to purlay.app only.

**The iOS app on a simulator, signed ad hoc.** `scripts/verify` builds with `CODE_SIGNING_ALLOWED=NO`, and an unsigned app cannot
use the Keychain on a simulator: it starts signed out and says it could not read the saved sign-in. To look at the app:

```sh
xcodebuild -project Apps/Purlay.xcodeproj -scheme Purlay-iOS -destination 'id=<simulator>' CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES build
SIMCTL_CHILD_PURLAY_DEV_SERVER=http://localhost:4590 xcrun simctl launch <simulator> dev.purlay.ios -AppleLanguages '(tr)'
xcrun simctl ui <simulator> content_size accessibility-extra-extra-extra-large   # and: xcrun simctl ui <simulator> appearance dark
```

A server that answers `GET /api/client` is enough to reach the sign-in screen; an address nobody answers shows the problem screen
after the client's retries (about twenty seconds).

**The Mac app.** Build and run the `Purlay-macOS` scheme. `scripts/dev-signing` makes a self-signed identity for this Mac's
development builds and names it in `Config/Local.xcconfig` (ignored by git), so the Keychain's "Always Allow" survives a rebuild;
without it builds are signed ad hoc. To see the app in Turkish: `-AppleLanguages "(tr)"` in the scheme's arguments.

## The iOS sign-in against a server

`Apps/iOS/Tests/PurlayUITests` signs in through the system browser. It needs a server and skips itself without one:

```sh
# in a purlay checkout at the server release Contract/contract.lock names
bun run demo -- --no-build --port 4590 --tls-cert cert.pem --tls-key key.pem
xcrun simctl keychain booted add-root-cert cert.pem        # a certificate the simulator trusts
TEST_RUNNER_PURLAY_UITEST_SERVER=https://localhost:4590 \
TEST_RUNNER_PURLAY_UITEST_SESSION="<the __Host-purlay_session value from https://localhost:4590/__demo/login?as=alice>" \
  xcodebuild -project Apps/Purlay.xcodeproj -scheme Purlay-iOS -testPlan iOS -only-testing:PurlayUITests \
    -destination 'id=<simulator>' test
```

Approving inside the system browser's page is not driven (TD-007); the server's half of that step runs in the live contract tests.

## The iOS shell, Chat and sign-out against a fixture

Four more UI tests skip without their own server, each a local fixture that answers in a scripted order (TD-028). Run them like
the sign-in test above, on iPhone and on iPad, each run with a fresh fixture:

- `WorkspaceShellUITests`: `TEST_RUNNER_PURLAY_SHELL_UITEST_SERVER`, `…_SESSION`, `…_CHAT_WORKSPACE` and `…_CORE_WORKSPACE`. A
  member whose first workspace allows Chat and whose second omits it; the test checks the tab or the sidebar, switches to the
  workspace without Chat and back, and keeps a screenshot of each.
- `NativeChatUITests`: `TEST_RUNNER_PURLAY_CHAT_UITEST_SERVER` and `…_SESSION`. An unread joined channel with two recent messages
  and an earlier page; the fixture refuses the first earlier-page read and the first read of an empty second channel, so both
  Try Again controls are driven.
- `NativeComposerUITests`: `TEST_RUNNER_PURLAY_COMPOSER_UITEST_SERVER` and `…_SESSION`. A writable channel, an announcement channel
  only owners and admins may post in, and a workspace without Chat; the fixture holds the first message's echo until
  `POST /composer-echo`, refuses the first attempt of the second, and records each send at `/composer-proof`.
- `NativeSignOutUITests`: `TEST_RUNNER_PURLAY_SIGN_OUT_UITEST_SERVER`, `…_CONTROL` and `…_SESSION`. A loopback fixture with two
  device sessions and two memberships with Chat, whose control listener records logout paths and socket counts, holds or
  refuses requests, and stops and restarts the app's listener; the tests relaunch the Debug app without a seeded session to see
  that it forgot the credential.

## Strings

- **What both apps say about the engine** (a phase, a server problem, a sign-in failure, a notice, an upload failure): a
  `LocalizedStringResource` with `bundle: .module` in `Sources/PurlayWords`, and an entry in its catalogue,
  `Sources/PurlayWords/Resources/Localizable.xcstrings`.
- **What both apps' screens say otherwise** (Cancel, a place in the workspace, a message's state): `SharedWords` in
  `Sources/PurlayWords`, in the same catalogue.
- **iOS's own:** a `LocalizedStringResource` in `Apps/iOS/App/Root/Words.swift` and an entry in
  `Apps/iOS/App/Resources/Localizable.xcstrings`. A feature's screens take their sentences from the app (`FeatureChat`'s
  `ChatStrings`), so a sentence keeps one home.
- **The Mac's own:** write the sentence in English in the code.
- **The Mac's App Intents:** titles, descriptions and parameters are sentences in the code like any other. A parameter summary
  (`Summary("Send \(\.$text) to \(\.$conversation)")`) is looked up by its parameters' names, `Send ${text} to ${conversation}`,
  which the build does not extract: add that key to the Mac's catalogue by hand. An App Shortcut's phrases (what a person says
  to Siri) are in `Apps/macOS/App/Resources/AppShortcuts.xcstrings`, a set of phrases per shortcut.
- `scripts/localize` builds the Mac app with string extraction and adds the new sentences of the Mac and of `PurlayWords`, and
  the Mac's App Shortcut phrases, to their catalogues. Give each its Turkish value with the state `translated`, then run
  `scripts/enforcement tree`: its one checker holds the four catalogues to every language the apps declare
  (`CFBundleLocalizations`).

## Where to read next

[Conventions](../architecture/conventions.md) before any code change; [testing](testing.md); [CI](ci.md); the
[contract pipeline](contract.md); [releasing](releasing.md).
