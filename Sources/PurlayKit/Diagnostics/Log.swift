import OSLog

/// The app's log, by area, in the unified log under the app's own subsystem (`AppIdentity.logSubsystem`). What goes here
/// is what happened and its code, never what a person wrote, who they are, or an address: those are `.private` when they
/// must appear.
public struct Log: Sendable {
    public let subsystem: String
    /// Notices the system was asked to show, and what it refused.
    public let attention: Logger
    /// The session: sign-in, restore, sign-out, the keychain.
    public let session: Logger
    /// Socket events and connection state.
    let realtime: Logger
    /// Files on disk: the outbox, drafts, attachments saved and read.
    public let storage: Logger

    public init(subsystem: String) {
        self.subsystem = subsystem
        attention = Logger(subsystem: subsystem, category: "attention")
        session = Logger(subsystem: subsystem, category: "session")
        realtime = Logger(subsystem: subsystem, category: "realtime")
        storage = Logger(subsystem: subsystem, category: "storage")
    }
}
