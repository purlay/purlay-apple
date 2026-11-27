# A flaky test

A test that fails and then passes on the same code is a bug, in the test or in the code, until it is shown which. Never re-run a
lane until it is green, and never add a retry for a test: `scripts/ci/retry-infra` retries only a machine's failure.

1. **Is it the machine?** A retry warning on the run ("Retried once for the machine") with a simulator or network message is not a
   flaky test. A Keychain error on an unsigned build is [keychain-in-tests.md](keychain-in-tests.md).
2. **Reproduce it** by running it many times, here with a package test:

   ```sh
   xcodebuild -project Apps/Purlay.xcodeproj -scheme Purlay-macOS -testPlan macOS -destination 'platform=macOS' \
     CODE_SIGNING_ALLOWED=NO -only-testing:PurlayKitTests/ReconnectingTests -test-iterations 50 -run-tests-until-failure test
   ```

   (For an iOS app test: `-scheme Purlay-iOS -testPlan iOS -destination 'id=<simulator>'`.)
3. **The usual causes:** a sleep of a guessed time before an assertion (wait for the condition with `eventually`); shared state
   between tests (each test builds its own model and fakes); a real clock or network (inject them); ordering of async work that
   the test assumes.
4. **Fix it** with a test that proves the fix (the repeated run passes), in one pull request.
5. **If main is blocked and the fix will take longer:** disable that one test with its reason and an issue
   (`@Test(.disabled("flaky: #123"))`), labelled `bug` and `p1`, in its own pull request. Remove the trait in the
   fix.
