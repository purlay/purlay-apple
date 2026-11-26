import Foundation
import PurlayKit
import Testing

@testable import Purlay

@MainActor
@Suite("the app's environment")
struct EnvironmentTests {
    @Test("identifies itself to the server as an iOS client")
    func platform() {
        #expect(RealEnvironment.make().identity.platform == .iOS)
    }

    @Test("reports the version the bundle says, not a placeholder")
    func version() throws {
        let shown = try #require(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        #expect(RealEnvironment.make().appVersion == SemanticVersion(shown))
        #expect(RealEnvironment.make().appVersion != SemanticVersion(0, 0, 0))
    }

    @Test("names itself from its bundle, and keeps its session under the app's own Keychain service")
    func identity() {
        let identity = RealEnvironment.make().identity
        #expect(identity.bundleIdentifier == Bundle.main.bundleIdentifier)
        #expect(identity.keychainService == "dev.purlay.ios.session")
    }

    @Test("keeps its files under the app's own name in Application Support")
    func dataDirectory() {
        let directory = RealEnvironment.make().dataDirectory
        #expect(directory.lastPathComponent == (Bundle.main.bundleIdentifier ?? "dev.purlay.ios"))
        #expect(directory.pathComponents.contains("Application Support"))
    }

    @Test("a timer fires once and a cancelled one never does")
    func schedule() async throws {
        let environment = RealEnvironment.make()
        var fired = 0
        _ = environment.schedule(10) { fired += 1 }
        let cancel = environment.schedule(10) { fired += 100 }
        cancel()
        for _ in 0..<200 where fired == 0 { try await Task.sleep(for: .milliseconds(10)) }
        try await Task.sleep(for: .milliseconds(50))
        #expect(fired == 1)
    }
}

@Suite("which server a build talks to (FR-006)")
struct ServerChoiceTests {
    @Test("a debug build talks to the development server it is told of, and may use plain HTTP to this machine")
    func debugBuild() {
        let choice = ServerChoice.resolve(isDebugBuild: true, override: "http://localhost:4390")
        #expect(choice == ServerChoice(address: "http://localhost:4390", allowsLocalHTTP: true))
    }

    @Test("a debug build told of nothing talks to the hosted server")
    func debugBuildWithoutOverride() {
        #expect(
            ServerChoice.resolve(isDebugBuild: true, override: nil)
                == ServerChoice(address: ServerAddress.hosted, allowsLocalHTTP: true))
    }

    @Test("a release build talks only to the hosted server over HTTPS, whatever it is handed")
    func releaseBuild() {
        for override in [nil, "http://localhost:4390", "https://elsewhere.example"] {
            let choice = ServerChoice.resolve(isDebugBuild: false, override: override)
            #expect(choice == ServerChoice(address: ServerAddress.hosted, allowsLocalHTTP: false))
        }
        #expect(ServerAddress.hosted.hasPrefix("https://"))
    }

    @MainActor
    @Test("the real environment follows the choice of the build it is in")
    func realEnvironment() {
        #if DEBUG
        let environment = RealEnvironment.make(variables: ["PURLAY_DEV_SERVER": "http://localhost:4390"])
        #expect(environment.serverAddress == "http://localhost:4390")
        #expect(environment.allowsLocalHTTP)
        #expect(RealEnvironment.make(variables: [:]).serverAddress == ServerAddress.hosted)
        #else
        let environment = RealEnvironment.make(variables: ["PURLAY_DEV_SERVER": "http://localhost:4390"])
        #expect(environment.serverAddress == ServerAddress.hosted)
        #expect(!environment.allowsLocalHTTP)
        #endif
    }
}

#if DEBUG
/// The shortcuts themselves are `DevelopmentSession`'s, tested in its package; this is the app's wiring of them.
@MainActor
@Suite("the development shortcuts of a debug build")
struct DevelopmentSessionTests {
    @Test("stores the session it is handed in the app's own sessions, for the server it names")
    func seeds() throws {
        let address = "http://localhost:4390"
        let sessions = InMemorySessionStore()
        RealEnvironment.seedDevelopmentSession(
            Harness.environment(sessions: sessions),
            variables: ["PURLAY_DEV_SERVER": address, "PURLAY_DEV_SESSION": "cookie-value"])
        #expect(
            try sessions.load(for: try ServerAddress.parse(address, allowsLocalHTTP: true))?.cookie == "cookie-value")
    }
}
#endif
