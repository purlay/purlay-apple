# A Keychain or signing failure in tests

CI and `scripts/verify` build with `CODE_SIGNING_ALLOWED=NO`, on purpose: no signing material on a pull request's runner.

| What you see | Why | What to do |
|---|---|---|
| The iOS app on a simulator starts signed out and says "Unsent messages can't be saved on this device right now" | an unsigned app cannot read the Keychain on a simulator, and the engine reports a failed restore with the outbox's notice (TD-009) | build it ad hoc to look at it ([getting-started.md](../development/getting-started.md#running-the-apps)); the fix of the wrong notice is TD-009 |
| A package test that touches the Keychain fails only on a runner (`errSecInteractionNotAllowed`, -25308) | the runner's login keychain is locked | not seen yet; if it happens, the test should use `PurlayTestSupport`'s in-memory store unless it is `KeychainSessionStoreTests`, which tests the Keychain itself: report it with the log |
| The Mac app asks for the Keychain after every rebuild | ad hoc signatures change with each build | `scripts/dev-signing` once, on that Mac |
| A Mac Debug build will not load Sparkle | library validation under ad hoc signing | the Debug entitlements turn it off; check `Config/macOS.xcconfig` takes `Purlay.Debug.entitlements` for Debug |

A test that fails only for one of these reasons is not flaky: fix the build setting or the test, not the retry.
