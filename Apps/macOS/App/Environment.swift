import AppKit
import Foundation
import PurlayKit

/// Who the retained data belongs to, kept in the app's defaults beside it.
struct DefaultsOwner: OwnerMemory {
    private let key = "retained-data-owner"
    func load() -> String? { UserDefaults.standard.string(forKey: key) }
    func save(_ owner: String?) {
        if let owner {
            UserDefaults.standard.set(owner, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

/// The app's real environment: the Keychain, the defaults, the network, the browser and the files, as the sandbox gives them.
@MainActor
enum RealEnvironment {
    /// This app, as its bundle names it (`PRODUCT_BUNDLE_IDENTIFIER` in Config/macOS.xcconfig): its Keychain service is
    /// `dev.purlay.mac.session`, where every installed Mac keeps its session.
    static let identity = AppIdentity.main(platform: .macOS)
    static let log = Log(subsystem: identity.logSubsystem)

    static func make(attention: any AttentionPresenter = SilentAttention()) -> AppEnvironment {
        let info = Bundle.main.infoDictionary
        let version =
            SemanticVersion(info?["CFBundleShortVersionString"] as? String ?? "") ?? SemanticVersion(0, 0, 0)
        let support =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = support.appendingPathComponent(
            identity.bundleIdentifier, isDirectory: true)
        #if DEBUG
        let allowsLocalHTTP = true
        let serverAddress = ProcessInfo.processInfo.environment["PURLAY_DEV_SERVER"] ?? ServerAddress.hosted
        #else
        let allowsLocalHTTP = false
        let serverAddress = ServerAddress.hosted
        #endif
        let clientHeader = ClientHeader.value(appVersion: version, platform: identity.platform)
        return AppEnvironment(
            transport: URLSessionTransport(), sessions: KeychainSessionStore(service: identity.keychainService),
            preferences: UserDefaultsPreferences(), authenticator: SystemBrowserAuthenticator(), appVersion: version,
            identity: identity,
            deviceName: Host.current().localizedName ?? DeviceName.fallback,
            allowsLocalHTTP: allowsLocalHTTP, serverAddress: serverAddress, dataDirectory: directory,
            openSocket: { origin, session in
                URLSessionSocketTransport(origin: origin.description, clientHeader: clientHeader, cookie: { session })
                    .openSocket(session: session)
            },
            schedule: { milliseconds, work in
                let task = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(milliseconds))
                    if !Task.isCancelled { work() }
                }
                return { task.cancel() }
            },
            owner: DefaultsOwner(), attention: attention, loginItem: SystemLoginItem())
    }

    #if DEBUG
    /// A development shortcut, in debug builds only: a session that is already made for the local server `PURLAY_DEV_SERVER` names, so the
    /// screens can be looked at without the browser. `PURLAY_DEV_SERVER=http://localhost:4390 PURLAY_DEV_SESSION=<value>`.
    static func seedDevelopmentSession(_ environment: AppEnvironment) {
        let variables = ProcessInfo.processInfo.environment
        guard let server = variables["PURLAY_DEV_SERVER"], let session = variables["PURLAY_DEV_SESSION"],
            let address = try? ServerAddress.parse(server, allowsLocalHTTP: true)
        else { return }
        try? environment.sessions.save(
            StoredSession(cookie: session, expiresAt: nil, origin: address.description), for: address)
    }
    #endif
}
