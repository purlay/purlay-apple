# The runner image or Xcode changed

`.github/toolchain.env` states the Xcode (27.2) and the simulator (iPhone 17, iOS 27.2) CI uses. Every macOS job asserts them, so an
image change fails at once at "Xcode, as .github/toolchain.env names it" or "The simulator .github/toolchain.env names", with
what the image has.

## Xcode is missing or different

1. Read what the `xcode-27` image has now: `actions/runner-images`, `images/macos/xcode-27-arm64-Readme.md`, section Xcode.
2. Choose the Xcode to use: the newest 27.x the image has, never older than 27.2 (the JSON project format needs it).
3. One pull request, `ci: build with Xcode 27.N`: `XCODE_VERSION` in `.github/toolchain.env`, and the version named in
   `docs/development/ci.md` and `docs/development/getting-started.md`. The compilation caches are keyed by the Xcode build, so the
   first runs are cold.
4. In the same pull request, run `scripts/dev/sentence-calls`: it writes `scripts/lib/sentence_calls.py`, the calls of the new
   SDK that take a sentence, which the catalogue rule reads. The packages lane refuses a file this Xcode would write otherwise
   (`scripts/enforcement layers`).
5. After it merges, run main's CI by hand (*Actions → CI → Run workflow*) to warm the caches.

A new Xcode that breaks the build (a new warning is an error here) is fixed in the same pull request; nothing is silenced.

## The simulator is missing

1. The failing step lists the available iPhones per runtime. Choose a device the image has on the newest iOS runtime.
2. Change `SIMULATOR_DEVICE` and `SIMULATOR_OS` in `.github/toolchain.env`, and the device named in `docs/development/ci.md`.
3. Locally: `xcrun simctl list runtimes`; a missing runtime installs with `xcodebuild -downloadPlatform iOS`.
