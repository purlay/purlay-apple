import Foundation

/// Who the retained data belongs to, kept in the app's defaults beside it.
public struct DefaultsOwner: OwnerMemory {
    private let key = "retained-data-owner"
    private let suite: String?

    /// `suite`: a defaults domain a test makes for itself; the app's own (the standard one) when `nil`.
    public init(suite: String? = nil) {
        self.suite = suite
    }

    private var defaults: UserDefaults { suite.flatMap { UserDefaults(suiteName: $0) } ?? .standard }

    public func load() -> String? { defaults.string(forKey: key) }

    public func save(_ owner: String?) {
        if let owner {
            defaults.set(owner, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
