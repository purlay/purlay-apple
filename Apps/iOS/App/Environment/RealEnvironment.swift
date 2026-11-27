import Foundation
import OSLog
import PurlayKit
import UIKit

/// The app's real environment: the Keychain, the defaults, the network, the browser and the files, as iOS gives them.
@MainActor
enum RealEnvironment {
    /// This app, as its bundle names it (`PRODUCT_BUNDLE_IDENTIFIER` in Config/iOS.xcconfig).
    static let identity = AppIdentity.main(platform: .iOS)

    /// `variables`: the process's environment, handed in so a test can say what it holds.
    static func make(variables: [String: String] = ProcessInfo.processInfo.environment) -> AppEnvironment {
        let info = Bundle.main.infoDictionary
        let version =
            SemanticVersion(info?["CFBundleShortVersionString"] as? String ?? "") ?? SemanticVersion(0, 0, 0)
        let support =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = support.appendingPathComponent(
            identity.bundleIdentifier, isDirectory: true)
        // Copies the app can make again (Quick Look's), where the system may reclaim the space; the person's go at sign-out.
        let caches =
            (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory).appendingPathComponent(
                identity.bundleIdentifier, isDirectory: true)
        // The development server is read in a debug build only: in a release build the name is not looked at.
        #if DEBUG
        let choice = ServerChoice.resolve(isDebugBuild: true, override: variables["PURLAY_DEV_SERVER"])
        #else
        let choice = ServerChoice.resolve(isDebugBuild: false, override: nil)
        #endif
        let clientHeader = ClientHeader.value(appVersion: version, platform: identity.platform)
        return AppEnvironment(
            transport: URLSessionTransport(), sessions: KeychainSessionStore(service: identity.keychainService),
            preferences: UserDefaultsPreferences(), authenticator: WebAuthSession(), appVersion: version,
            identity: identity, deviceName: UIDevice.current.name, allowsLocalHTTP: choice.allowsLocalHTTP,
            serverAddress: choice.address, dataDirectory: directory, cacheDirectory: caches,
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
            owner: DefaultsOwner(),
            // None of the app's own yet: the engine removes the drafts and the outbox it keeps under this environment (P-6 in
            // docs/design/entry-shell-account.md); the cold-start cache (A-003) adds its wiper when it is built. The badge is
            // cleared by the model.
            wipers: [])
    }
}

#if DEBUG
extension RealEnvironment {
    /// The development shortcuts (`DevelopmentSession`), for this app's sessions and in its log.
    static func seedDevelopmentSession(
        _ environment: AppEnvironment, variables: [String: String] = ProcessInfo.processInfo.environment
    ) {
        DevelopmentSession.seed(
            environment.sessions, variables: variables,
            log: Logger(subsystem: identity.logSubsystem, category: "development"))
    }
}
#endif
