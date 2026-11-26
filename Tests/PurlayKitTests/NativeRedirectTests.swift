import Foundation
import PurlayContract
import Testing

@testable import PurlayKit

/// The app's URL scheme is the server's: the scheme of the address it sends a native app back to (`NATIVE_REDIRECT`).
@Suite("the native redirect")
struct NativeRedirectTests {
    @Test("the scheme and host are the contract's redirect, read rather than spelt")
    func fromTheContract() {
        #expect(NativeRedirect.scheme + "://" + NativeRedirect.host == ContractConstants.nativeRedirect)
        #expect(!NativeRedirect.scheme.isEmpty && !NativeRedirect.host.isEmpty)
    }

    @Test("an app link is opened under the contract's scheme")
    func appLinksUseIt() throws {
        let web = try #require(URL(string: "https://chat.example.test/w/team/c/\(channel(1))"))
        #expect(ConversationLink.appURL(for: web)?.scheme == NativeRedirect.scheme)
    }

    @Test("a callback is recognised as one by the contract's scheme and host, and nothing else is")
    func recognisesCallbacks() throws {
        let callback = try #require(URL(string: ContractConstants.nativeRedirect + "?code=c&state=s"))
        #expect(NativeRedirect.isCallback(callback))
        let web = try #require(URL(string: "https://chat.example.test/w/team/c/\(channel(1))"))
        #expect(!NativeRedirect.isCallback(web))
        #expect(!NativeRedirect.isCallback(try #require(ConversationLink.appURL(for: web))))
    }
}
