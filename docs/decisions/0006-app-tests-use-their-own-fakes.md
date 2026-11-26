# 0006. The iOS app's tests use fakes of their own, not `PurlayTestSupport`

Status: accepted, 2026-11-26

**Context.** `PurlayTestSupport` holds fakes of the network, the Keychain and the browser for the package tests. The iOS app's
unit tests (`PurlayTests`) are hosted by the app, which links `PurlayKit` and `PurlayContract`. Linking `PurlayTestSupport` into
the test bundle as well put a second, static copy of `PurlayKit`'s types into it: the runtime reported every class as
implemented twice, and two copies of a Swift class are two types, so a test could pass or fail on a type the app does not use.

**Decision.** `Apps/iOS/Tests/PurlayTests/Fakes.swift` holds the few fakes the app's tests need (a scripted transport with an
offline switch, a scripted browser, an in-memory session store, owner memory and preferences). The test bundle links `PurlayKit`
and `PurlayContract`, the same frameworks the app uses, and not `PurlayTestSupport`.

**Rejected.** *Link it and ignore the warnings:* the duplicate types are what a test must not have. *Test the screens in a
package:* the composition root and the screen decisions live in the app. *Make `PurlayTestSupport` a dynamic product:* worth doing
if the duplication grows; today it would change every package test's linking for about 100 lines.

**Consequences.** About 100 lines of fakes exist twice. They implement public protocols, so a change to a protocol fails to
compile here at once. Revisit when `PurlayTestSupport` can be linked without a second copy of the engine.
