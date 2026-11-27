import Foundation

/// Small preferences the app keeps between runs: where it was last pointed. Not a credential.
public protocol PreferenceStore: Sendable {
    func string(for key: String) -> String?
    func set(_ value: String?, for key: String)
    /// Removes every value whose key begins with `prefix`: what is kept per person under one name (their drafts) goes at once.
    func removeValues(withPrefix prefix: String)
}

public struct UserDefaultsPreferences: PreferenceStore {
    private let suite: String?

    /// `suite`: a defaults domain of the app's own, or the standard one.
    public init(suite: String? = nil) {
        self.suite = suite
    }

    private var defaults: UserDefaults { suite.flatMap { UserDefaults(suiteName: $0) } ?? .standard }

    public func string(for key: String) -> String? { defaults.string(forKey: key) }

    public func set(_ value: String?, for key: String) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    public func removeValues(withPrefix prefix: String) {
        let defaults = defaults
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Where what needs the person is told: the Dock badge and the notices of the system. The model decides; this shows.
@MainActor
public protocol AttentionPresenter {
    func setBadge(_ count: Int?)
    func show(_ notice: AttentionNotice)
    func retract(_ ids: [String])
    func replaceReminders(_ notices: [ReminderNotice], scope: String)
    func cancelReminders(_ ids: [String], scope: String)
    func clearReminders(scope: String)
}

extension AttentionPresenter {
    public func replaceReminders(_ notices: [ReminderNotice], scope: String) {}
    public func cancelReminders(_ ids: [String], scope: String) {}
    public func clearReminders(scope: String) {}
}

/// For where nothing can be told: a test that does not look, and a build with no notifications.
@MainActor
public struct SilentAttention: AttentionPresenter {
    public init() {}
    public func setBadge(_ count: Int?) {}
    public func show(_ notice: AttentionNotice) {}
    public func retract(_ ids: [String]) {}
}

/// Where the system stands on opening the app at login.
public enum LoginItemStatus: Sendable, Equatable {
    case off, on
    /// Registered, and the person has still to approve it in System Settings.
    case requiresApproval
    /// A build the system does not list as a login item.
    case unavailable
}

/// Opening at login, as the system keeps it: the app asks and shows the answer.
@MainActor
public protocol LoginItemControl {
    var status: LoginItemStatus { get }
    func set(_ on: Bool) throws
    /// The place in System Settings where a login item is approved.
    func openSystemSettings()
}

/// For where there is no login item: a test that does not look, and a build the system does not list.
@MainActor
public struct NoLoginItem: LoginItemControl {
    public init() {}
    public var status: LoginItemStatus { .unavailable }
    public func set(_ on: Bool) throws {}
    public func openSystemSettings() {}
}

/// Everything the app's model reaches the outside world through, so a test replaces each: the network, the keychain, the browser, the
/// files, the socket, the clock and the timers.
@MainActor
public struct AppEnvironment {
    public var transport: any HTTPTransport
    public var sessions: any SessionStore
    /// Where the Mac keeps a browser sign-in's session until `/api/me` says whose it is (ADR 0011), apart from the session in
    /// use and one entry per workspace session, so a quit does not lose it or leave it alive on the server with nothing
    /// holding it. None on iOS, which keeps a sign-in at once.
    public var pendingSessions: PendingSessionStores?
    public var preferences: any PreferenceStore
    public var authenticator: any WebAuthenticator
    public var appVersion: SemanticVersion
    /// Which app this is: the platform the server is told, and what the Keychain and the log are named after.
    public var identity: AppIdentity {
        didSet { log = Log(subsystem: identity.logSubsystem) }
    }
    /// The log, under the app's own subsystem: made from `identity`, and made again when it changes, so it names no other app.
    public private(set) var log: Log
    public var deviceName: String
    public var allowsLocalHTTP: Bool
    /// The one server this app signs in to: Purlay's own. Only a development build points it elsewhere.
    public var serverAddress: String
    /// Preferences every session of the app shares, where the Mac scopes `preferences` per workspace: for what belongs to a
    /// server's one credential and person rather than to a workspace (an unconfirmed erasure). `preferences` unless given.
    public var sharedPreferences: any PreferenceStore
    /// Where per-person files are kept (`outbox/<userId>.json`).
    public var dataDirectory: URL
    /// Where copies the app can make again are kept (the Mac's Quick Look copies, `Previews/`): the system may empty it.
    public var cacheDirectory: URL
    /// An `OpenSocket` for this server's canonical address and this session.
    public var openSocket: (_ origin: ServerAddress, _ session: String) -> OpenSocket
    public var schedule: Schedule
    public var random: () -> Double
    public var clock: @Sendable () -> Date
    /// Called with the kept owner of the retained data (a person's id), so what one person left is not sent as another's.
    public var owner: any OwnerMemory
    public var sleep: @Sendable (Duration) async throws -> Void
    public var attention: any AttentionPresenter
    public var loginItem: any LoginItemControl
    /// What the app keeps of the person on this device beside what the engine keeps: each runs once when the person signs out
    /// (here or everywhere) or erases their account, and when another person signs in where they were. A wiper of data kept per
    /// session must be made for the environment it is given, since the Mac scopes each of its sessions' preferences and files.
    public var wipers: [any UserDataWiper]

    public init(
        transport: any HTTPTransport, sessions: any SessionStore, preferences: any PreferenceStore,
        authenticator: any WebAuthenticator,
        appVersion: SemanticVersion, identity: AppIdentity, deviceName: String, allowsLocalHTTP: Bool,
        serverAddress: String = ServerAddress.hosted, dataDirectory: URL, cacheDirectory: URL? = nil,
        openSocket: @escaping (ServerAddress, String) -> OpenSocket, schedule: @escaping Schedule,
        random: @escaping () -> Double = { Double.random(in: 0...1) },
        clock: @escaping @Sendable () -> Date = Date.init,
        owner: any OwnerMemory,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        attention: any AttentionPresenter = SilentAttention(),
        loginItem: any LoginItemControl = NoLoginItem(),
        wipers: [any UserDataWiper] = [],
        pendingSessions: PendingSessionStores? = nil
    ) {
        self.loginItem = loginItem
        self.wipers = wipers
        self.pendingSessions = pendingSessions
        self.transport = transport
        self.sessions = sessions
        self.preferences = preferences
        self.sharedPreferences = preferences
        self.authenticator = authenticator
        self.appVersion = appVersion
        self.identity = identity
        self.log = Log(subsystem: identity.logSubsystem)
        self.deviceName = deviceName
        self.allowsLocalHTTP = allowsLocalHTTP
        self.serverAddress = serverAddress
        self.dataDirectory = dataDirectory
        // A test, or a build with no caches of its own, keeps them beside its data.
        self.cacheDirectory = cacheDirectory ?? dataDirectory.appendingPathComponent("Caches", isDirectory: true)
        self.attention = attention
        self.openSocket = openSocket
        self.schedule = schedule
        self.random = random
        self.clock = clock
        self.owner = owner
        self.sleep = sleep
    }
}

/// The Mac's pending sign-ins (`AppEnvironment.pendingSessions`): one store per workspace session (`slot`), so one
/// workspace's pending sign-in never replaces another's.
public struct PendingSessionStores: Sendable {
    /// The workspace session this one is for: "main" for the first, the descriptor's id for each other.
    public let slot: String
    private let make: @Sendable (_ slot: String) -> any SessionStore

    public init(slot: String = "main", make: @escaping @Sendable (_ slot: String) -> any SessionStore) {
        self.slot = slot
        self.make = make
    }

    /// This workspace session's store.
    public var store: any SessionStore { make(slot) }

    /// The same stores, for another workspace session.
    public func scoped(to slot: String) -> PendingSessionStores {
        PendingSessionStores(slot: slot, make: make)
    }
}
