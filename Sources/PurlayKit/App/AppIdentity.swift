import Foundation

/// Which app the engine is serving, handed in by that app: the engine serves every app and names none. What the engine
/// keeps and logs under is derived from it, so each app's Keychain items and log are its own.
public struct AppIdentity: Sendable, Equatable {
    /// The app's bundle identifier, as its build states it (`PRODUCT_BUNDLE_IDENTIFIER` in `Config/`).
    public let bundleIdentifier: String
    /// The operating system the app runs on, as the server is told it.
    public let platform: ClientPlatform

    public init(bundleIdentifier: String, platform: ClientPlatform) {
        self.bundleIdentifier = bundleIdentifier
        self.platform = platform
    }

    /// The running app's identity: its main bundle's identifier. An app's bundle always has one (Xcode writes
    /// `CFBundleIdentifier` into every app's Info.plist), so its absence is a broken build, not a state to carry on in.
    public static func main(platform: ClientPlatform) -> AppIdentity {
        guard let identifier = Bundle.main.bundleIdentifier else {
            preconditionFailure("the app's bundle states no CFBundleIdentifier")
        }
        return AppIdentity(bundleIdentifier: identifier, platform: platform)
    }

    /// The unified log's subsystem: `log show --predicate 'subsystem == "<bundle identifier>"'`.
    public var logSubsystem: String { bundleIdentifier }

    /// The Keychain service the session is kept under. Installed Macs hold theirs under `dev.purlay.mac.session`, which
    /// is this for the Mac's bundle identifier: changing the rule, or the identifier, signs every one of them out.
    public var keychainService: String { bundleIdentifier + ".session" }
}
