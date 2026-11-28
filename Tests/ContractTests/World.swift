import Foundation
import PurlayContract
import PurlayKit
import Testing

/// The server the contract tests run against, and the people and channels its demo made. Read from the manifest the demo wrote.
struct World: Sendable {
    struct Persona: Sendable {
        let userID: String
        let username: String
        /// The raw session value, as the app keeps it.
        let session: String
    }

    let server: ServerAddress
    let workspaceID: String
    let workspaceSlug: String
    let personas: [String: Persona]
    /// The people in no workspace (erin, frank, gwen): for a test that ends a person, such as erasing their account, which
    /// done as one of the workspace's people would pull the ground from under every other test. Each has two sessions; this
    /// is the first.
    let outsiders: [String: Persona]
    let channels: [String: String]

    static var isAvailable: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["PURLAY_TEST_MANIFEST"] != nil && environment["PURLAY_TEST_SERVER"] != nil
    }

    static func load() throws -> World {
        let environment = ProcessInfo.processInfo.environment
        guard let manifest = environment["PURLAY_TEST_MANIFEST"], let server = environment["PURLAY_TEST_SERVER"] else {
            throw WorldError.notConfigured
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: manifest))
        guard case .object(let root) = try JSONDecoder().decode(JSONValue.self, from: data),
            case .object(let workspace)? = root["workspace"], case .string(let id)? = workspace["id"],
            case .string(let slug)? = workspace["slug"], case .object(let people)? = root["personas"],
            case .object(let rooms)? = root["channels"]
        else { throw WorldError.shape("the manifest is not the demo's") }

        var personas: [String: Persona] = [:]
        for (name, value) in people {
            guard case .object(let fields) = value, case .string(let userID)? = fields["userId"],
                case .string(let username)? = fields["username"], case .string(let cookie)? = fields["cookie"],
                let equals = cookie.firstIndex(of: "=")
            else { throw WorldError.shape("a persona has no session: \(name)") }
            personas[name] = Persona(
                userID: userID, username: username, session: String(cookie[cookie.index(after: equals)...]))
        }
        var outsiders: [String: Persona] = [:]
        if case .object(let others)? = root["outsiders"] {
            for (name, value) in others {
                guard case .object(let fields) = value, case .string(let userID)? = fields["userId"],
                    case .string(let username)? = fields["username"], case .array(let tokens)? = fields["tokens"],
                    case .string(let token)? = tokens.first
                else { throw WorldError.shape("an outsider has no session: \(name)") }
                outsiders[name] = Persona(userID: userID, username: username, session: token)
            }
        }
        var channels: [String: String] = [:]
        for (name, value) in rooms {
            if case .string(let channelID) = value { channels[name] = channelID }
        }
        return World(
            server: try ServerAddress.parse(server, allowsLocalHTTP: true), workspaceID: id, workspaceSlug: slug,
            personas: personas, outsiders: outsiders, channels: channels)
    }

    enum WorldError: Error {
        case notConfigured
        case shape(String)
    }

    var appVersion: SemanticVersion { SemanticVersion("0.1.0")! }
    /// The client these tests speak as: a Mac app, under a Keychain service and log of their own.
    var identity: AppIdentity { AppIdentity(bundleIdentifier: "dev.purlay.contract-tests", platform: .macOS) }
    var log: Log { Log(subsystem: identity.logSubsystem) }

    /// The API's own address: the demo's front is one port below it, a proxy that is not the server's own upgrade.
    var apiOrigin: URL {
        var components = URLComponents(url: server.origin, resolvingAgainstBaseURL: false)!
        components.port = (components.port ?? 80) + 1
        return components.url!
    }

    func persona(_ name: String) throws -> Persona {
        try #require(personas[name], "the demo has no \(name)")
    }

    func outsider(_ name: String) throws -> Persona {
        try #require(outsiders[name], "the demo has no outsider \(name)")
    }

    /// The iOS app's minimum `scripts/contract-test` started the server with (`MIN_CLIENT_IOS_VERSION`), when it did.
    static var iOSMinimum: String? { ProcessInfo.processInfo.environment["PURLAY_TEST_IOS_MINIMUM"] }

    /// A client that is signed in as `persona`, with the transport the app uses, speaking as the app on `platform`.
    func client(
        as persona: Persona, platform: ClientPlatform? = nil, onRejected: @escaping @Sendable () async -> Void = {}
    ) -> APIClient {
        APIClient(
            configuration: APIConfiguration(
                baseURL: server.origin,
                clientHeader: ClientHeader.value(appVersion: appVersion, platform: platform ?? identity.platform),
                sessionCookie: { persona.session }, onSessionRejected: { _ in await onRejected() }),
            transport: URLSessionTransport())
    }
}

extension Trait where Self == ConditionTrait {
    /// The tests that need a server: skipped, loudly, without one.
    static var needsServer: Self {
        .enabled(if: World.isAvailable, "no server: run scripts/contract-test")
    }
}
