import Foundation
import PurlayContract
import PurlayKit

@testable import Purlay

/// What the world outside the app does in a test: only the network, the Keychain, the browser and the clock are replaced; the
/// model, the handshake client and the sign-in flow are the real ones.
@MainActor
struct Harness {
    let transport: ScriptedTransport
    let authenticator: ScriptedAuthenticator
    let sessions = InMemorySessionStore()
    let model: AppModel

    init(
        _ steps: [ScriptedTransport.Step], browser: [WebAuthenticatorError] = [],
        serverAddress: String = "https://purlay.test"
    ) {
        let transport = ScriptedTransport(steps)
        let authenticator = ScriptedAuthenticator(browser)
        self.transport = transport
        self.authenticator = authenticator
        model = AppModel(
            Self.environment(
                transport: transport, sessions: sessions, authenticator: authenticator, serverAddress: serverAddress))
    }

    /// An environment of the app's own shape with its outside replaced: nothing reaches a network, a Keychain or a browser.
    static func environment(
        transport: any HTTPTransport = ScriptedTransport(), sessions: any SessionStore,
        authenticator: any WebAuthenticator = ScriptedAuthenticator([]), serverAddress: String = "https://purlay.test"
    ) -> AppEnvironment {
        AppEnvironment(
            transport: transport, sessions: sessions, preferences: MemoryPreferences(), authenticator: authenticator,
            appVersion: SemanticVersion(0, 1, 0),
            identity: AppIdentity(bundleIdentifier: "dev.purlay.ios.tests", platform: .iOS), deviceName: "Test iPhone",
            allowsLocalHTTP: false,
            serverAddress: serverAddress,
            dataDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(
                "purlay-tests-" + UUID().uuidString, isDirectory: true),
            openSocket: { _, _ in { _, _ in throw NoSocket() } },
            schedule: { _, _ in {} }, owner: InMemoryOwnerMemory(), sleep: { _ in })
    }

    struct NoSocket: Error {}

    /// A session kept from an earlier launch, so the next connection resumes it instead of asking to sign in.
    func rememberSession(serverAddress: String = "https://purlay.test") throws {
        try sessions.save(
            StoredSession(
                cookie: "session-value", expiresAt: Date(timeIntervalSince1970: 4_000_000_000), origin: serverAddress),
            for: try ServerAddress.parse(serverAddress, allowsLocalHTTP: false))
    }

    /// The server's answer to `/api/me` for an account that belongs to no workspace.
    nonisolated static func meWithoutWorkspace(mustEnrolTwoFactor: Bool = false) -> ScriptedTransport.Step {
        ScriptedTransport.json(
            200,
            """
            {"user":{"id":"0199155c-6200-7b7f-8c11-0000000000e1","username":"ada","displayName":"Ada","avatarUrl":null,"email":"ada@example.test"},\
            "profile":{"title":null,"timeZone":null,"status":null},"memberships":[],"mayCreateWorkspace":false,\
            "isServerAdmin":false,"nameFromGitHub":false,"mustEnrolTwoFactor":\(mustEnrolTwoFactor),\
            "scheduledDeletions":[],"modules":["chat","issues"],"awayChosen":false}
            """)
    }

    /// A server's answer to the handshake, as a Purlay server of the current release gives it.
    nonisolated static func clientInfo(
        minApp: String = "0.1.0", contract: Int = ContractConstants.contractVersion,
        appURL: String = "https://purlay.test"
    ) -> ScriptedTransport.Step {
        ScriptedTransport.json(
            200,
            """
            {"server":{"version":"0.8.0"},"contractVersion":\(contract),"appUrl":"\(appURL)",\
            "minClient":{"macos":{"appVersion":"\(minApp)","contractVersion":1,"downloadUrl":null}},\
            "auth":{"email":true,"github":true,"google":false,"oidc":null,"password":true,"signUp":"invite-only"}}
            """)
    }
}

/// A sentence in one language, whatever the language of the device the test runs on.
func text(_ resource: LocalizedStringResource, in language: String) -> String {
    var resource = resource
    resource.locale = Locale(identifier: language)
    return String(localized: resource)
}
