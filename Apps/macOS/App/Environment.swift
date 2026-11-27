import AppKit
import Foundation
import OSLog
import PurlayKit

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
        // Copies the app can make again (Quick Look's), where the system may reclaim the space; the person's go at sign-out.
        let cachesRoot =
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let caches = cachesRoot.appendingPathComponent(identity.bundleIdentifier, isDirectory: true)
        #if DEBUG
        let allowsLocalHTTP = true
        let serverAddress = ProcessInfo.processInfo.environment["PURLAY_DEV_SERVER"] ?? ServerAddress.hosted
        #else
        let allowsLocalHTTP = false
        let serverAddress = ServerAddress.hosted
        #endif
        let clientHeader = ClientHeader.value(appVersion: version, platform: identity.platform)
        // One Keychain service per workspace session for a sign-in not yet known to be whose (ADR 0011).
        let pendingService = identity.keychainService + ".pending."
        return AppEnvironment(
            transport: URLSessionTransport(), sessions: KeychainSessionStore(service: identity.keychainService),
            preferences: UserDefaultsPreferences(), authenticator: SystemBrowserAuthenticator(), appVersion: version,
            identity: identity,
            deviceName: Host.current().localizedName ?? DeviceName.fallback,
            allowsLocalHTTP: allowsLocalHTTP, serverAddress: serverAddress, dataDirectory: directory,
            cacheDirectory: caches,
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
            owner: DefaultsOwner(), attention: attention, loginItem: SystemLoginItem(),
            // The engine removes the drafts, the outbox and the Quick Look copies it keeps under this environment (per
            // workspace session, P-6 in docs/design/entry-shell-account.md). The app's own: the copies an earlier version kept
            // directly under Caches/Previews, for every session alike. The badge is cleared by the model.
            wipers: [FolderWiper(cachesRoot.appendingPathComponent("Previews", isDirectory: true))],
            // A browser sign-in not yet known to be whose, apart from the session in use (ADR 0011).
            pendingSessions: PendingSessionStores { slot in
                KeychainSessionStore(service: pendingService + slot)
            })
    }

    #if DEBUG
    /// The development shortcuts (`DevelopmentSession`), in debug builds only, for this app's sessions and in its log:
    /// `PURLAY_DEV_SERVER=http://localhost:4390 PURLAY_DEV_SESSION=<value>`, and `PURLAY_DEV_RESET=1`.
    static func seedDevelopmentSession(_ environment: AppEnvironment) {
        DevelopmentSession.seed(
            environment.sessions, variables: ProcessInfo.processInfo.environment,
            log: Logger(subsystem: identity.logSubsystem, category: "development"))
    }
    #endif
}
