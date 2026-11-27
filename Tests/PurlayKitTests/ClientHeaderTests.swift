import Testing

@testable import PurlayKit

@Suite("the client header")
struct ClientHeaderTests {
    private let version = SemanticVersion(1, 2, 3)

    @Test("names the Mac as the server spells it, now that the Mac says so rather than being the default")
    func namesMacOS() {
        #expect(
            ClientHeader.value(appVersion: version, platform: .macOS, contractVersion: 1) == "macos/1.2.3 contract/1")
    }

    @Test("names the platform it runs on")
    func namesPlatform() {
        #expect(ClientHeader.value(appVersion: version, platform: .iOS, contractVersion: 1) == "ios/1.2.3 contract/1")
    }
}
