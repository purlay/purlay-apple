import OSLog

/// The development shortcut both apps' debug builds offer, for the server `PURLAY_DEV_SERVER` names: `PURLAY_DEV_RESET=1`
/// forgets its stored session first (a Keychain item outlives the app's launches), and `PURLAY_DEV_SESSION=<the cookie's
/// value>` stores one already made, so the screens after sign-in can be looked at and tested without the browser.
///
/// It exists in a debug build only, so a release binary carries none of it (scripts/verify reads the built apps for the names).
/// What cannot be done is logged, not swallowed: a developer who asked for a session and did not get one is told why.
#if DEBUG
public enum DevelopmentSession {
    public static func seed(_ sessions: any SessionStore, variables: [String: String], log: Logger) {
        guard let server = variables["PURLAY_DEV_SERVER"] else { return }
        let address: ServerAddress
        do {
            address = try ServerAddress.parse(server, allowsLocalHTTP: true)
        } catch {
            log.error("PURLAY_DEV_SERVER is not a usable address: \(String(describing: error))")
            return
        }
        if variables["PURLAY_DEV_RESET"] == "1" {
            do {
                try sessions.delete(for: address)
            } catch {
                log.error("The stored session could not be forgotten: \(String(describing: error))")
            }
        }
        guard let session = variables["PURLAY_DEV_SESSION"] else { return }
        do {
            try sessions.save(StoredSession(cookie: session, expiresAt: nil, origin: address.description), for: address)
        } catch {
            log.error("The development session could not be stored: \(String(describing: error))")
        }
    }
}
#endif
