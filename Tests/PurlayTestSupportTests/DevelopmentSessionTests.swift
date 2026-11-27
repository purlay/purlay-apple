import OSLog
import PurlayKit
import PurlayTestSupport
import Testing

/// The development shortcuts both apps' debug builds offer: `PURLAY_DEV_SERVER`, `PURLAY_DEV_RESET` and `PURLAY_DEV_SESSION`.
@Suite("the development session a debug build may be handed")
struct DevelopmentSessionTests {
    private let address = "http://localhost:4390"
    private let log = Logger(subsystem: "dev.purlay.tests", category: "development")

    private func stored(_ sessions: InMemorySessionStore) throws -> StoredSession? {
        try sessions.load(for: try ServerAddress.parse(address, allowsLocalHTTP: true))
    }

    @Test("stores the session it is handed for the server it names, so the screens after sign-in can be looked at")
    func seeds() throws {
        let sessions = InMemorySessionStore()
        DevelopmentSession.seed(
            sessions, variables: ["PURLAY_DEV_SERVER": address, "PURLAY_DEV_SESSION": "cookie-value"], log: log)
        #expect(try stored(sessions)?.cookie == "cookie-value")
    }

    @Test("stores nothing without a server to store it for, or without a session to store")
    func nothingToSeed() {
        let sessions = InMemorySessionStore()
        DevelopmentSession.seed(sessions, variables: ["PURLAY_DEV_SESSION": "cookie-value"], log: log)
        DevelopmentSession.seed(sessions, variables: ["PURLAY_DEV_SERVER": address], log: log)
        #expect(sessions.saves == 0)
    }

    @Test("an address it cannot use stores nothing, rather than a session for some other place")
    func unusableAddress() {
        let sessions = InMemorySessionStore()
        DevelopmentSession.seed(
            sessions, variables: ["PURLAY_DEV_SERVER": "ftp://x.test", "PURLAY_DEV_SESSION": "cookie-value"], log: log)
        #expect(sessions.saves == 0)
    }

    @Test("a keychain that refuses to forget the old session does not stop the new one being stored")
    func resetRefused() throws {
        let sessions = InMemorySessionStore()
        sessions.failDeletes()
        DevelopmentSession.seed(
            sessions,
            variables: ["PURLAY_DEV_SERVER": address, "PURLAY_DEV_RESET": "1", "PURLAY_DEV_SESSION": "fresh"],
            log: log)
        #expect(try stored(sessions)?.cookie == "fresh")
    }

    @Test("a reset forgets the stored session first")
    func reset() throws {
        let sessions = InMemorySessionStore()
        let server = try ServerAddress.parse(address, allowsLocalHTTP: true)
        try sessions.save(StoredSession(cookie: "old", expiresAt: nil, origin: server.description), for: server)
        DevelopmentSession.seed(sessions, variables: ["PURLAY_DEV_SERVER": address, "PURLAY_DEV_RESET": "1"], log: log)
        #expect(try stored(sessions) == nil)
    }
}
