import Foundation

/// Every draft kept in a store of preferences (`purlay.draft.<userId>.…`), whoever's: what is left in one environment is its
/// owner's, or a previous owner's whose removal failed (`SessionManager.identify`), and neither is kept for the next person.
struct DraftsWiper: UserDataWiper {
    let preferences: any PreferenceStore

    func wipe() async throws {
        preferences.removeValues(withPrefix: Drafts.keyPrefix)
    }
}

/// A folder of the person's files and everything in it: the outbox (`outbox/`, set-aside files included), the Quick Look
/// copies (`Previews/`). One that is not there is already removed.
public struct FolderWiper: UserDataWiper {
    let folder: URL
    /// Runs first, so that what writes into the folder has stopped and nothing is written back once it is gone.
    let stopWriting: @Sendable () async -> Void

    public init(_ folder: URL, stopWriting: @escaping @Sendable () async -> Void = {}) {
        self.folder = folder
        self.stopWriting = stopWriting
    }

    public func wipe() async throws {
        await stopWriting()
        do {
            try FileManager.default.removeItem(at: folder)
        } catch CocoaError.fileNoSuchFile {
            return
        }
    }
}
