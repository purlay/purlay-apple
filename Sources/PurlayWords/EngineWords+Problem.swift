import Foundation
import PurlayKit

extension EngineWords {
    /// What stands between the app and the server: the title, and what the person can do about it.
    public static func problem(_ problem: ServerProblem) -> (
        title: LocalizedStringResource, detail: LocalizedStringResource
    ) {
        switch problem {
        case .unreachable:
            return (
                LocalizedStringResource("Server Unavailable", bundle: .module),
                LocalizedStringResource("Check your connection, then try again.", bundle: .module)
            )
        case .notAPurlayServer:
            return (
                LocalizedStringResource("That doesn't look like a Purlay server", bundle: .module),
                LocalizedStringResource("The address answered, but not as Purlay does.", bundle: .module)
            )
        case .rateLimited:
            return (
                LocalizedStringResource("Too many requests", bundle: .module),
                LocalizedStringResource("The server asks you to wait a moment.", bundle: .module)
            )
        case .appTooOld(let minimum):
            let detail =
                minimum.appVersion.map { LocalizedStringResource("It needs version \($0) or newer.", bundle: .module) }
                ?? LocalizedStringResource("Update Purlay, then try again.", bundle: .module)
            return (LocalizedStringResource("This server needs a newer Purlay", bundle: .module), detail)
        case .serverTooOld:
            return (
                LocalizedStringResource("This server is older than this app supports", bundle: .module),
                LocalizedStringResource("Ask whoever runs it to update the server.", bundle: .module)
            )
        case .unusableOrigin:
            // The address the server gave is the server's text, not ours to show.
            return (
                LocalizedStringResource("The server gave an address this app can't use", bundle: .module),
                LocalizedStringResource("Ask whoever runs the server to check its address settings.", bundle: .module)
            )
        }
    }
}
