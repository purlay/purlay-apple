import Testing

@testable import PurlayKit

/// The engine names no app: what it keeps and logs under is derived from the identity the app hands in.
@Suite("AppIdentity")
struct AppIdentityTests {
    @Test("the Mac keeps the Keychain service every installed Mac already holds its session under")
    func macKeychainServiceIsTheShippedOne() {
        // v0.3.0 and every Mac before it stored the session under exactly this service. A different one would sign
        // every installed Mac out on update.
        let mac = AppIdentity(bundleIdentifier: "dev.purlay.mac", platform: .macOS)
        #expect(mac.keychainService == "dev.purlay.mac.session")
    }

    @Test("the iPhone keeps the Keychain service it has used since its first build")
    func iOSKeychainServiceIsTheShippedOne() {
        let iOS = AppIdentity(bundleIdentifier: "dev.purlay.ios", platform: .iOS)
        #expect(iOS.keychainService == "dev.purlay.ios.session")
    }

    @Test("the log's subsystem is the app's bundle identifier, so each app's log is its own")
    func logSubsystemIsTheBundleIdentifier() {
        let identity = AppIdentity(bundleIdentifier: "dev.example.app", platform: .iOS)
        #expect(identity.logSubsystem == "dev.example.app")
        #expect(Log(subsystem: identity.logSubsystem).subsystem == "dev.example.app")
    }

    @Test("the environment carries the identity it was handed, platform included")
    @MainActor
    func environmentCarriesTheIdentity() {
        let identity = AppIdentity(bundleIdentifier: "dev.example.app", platform: .iOS)
        let environment = ModelHarness(identity: identity).model.environment
        #expect(environment.identity == identity)
        #expect(environment.log.subsystem == "dev.example.app")
    }

    @Test("the log is always the identity's: an identity set after the environment is made moves the log with it")
    @MainActor
    func logFollowsTheIdentity() {
        var environment = ModelHarness().model.environment
        environment.identity = AppIdentity(bundleIdentifier: "dev.example.other", platform: .iOS)
        // Two public properties, one derived from the other, can disagree; the log must not name another app.
        #expect(environment.log.subsystem == environment.identity.logSubsystem)
    }
}
