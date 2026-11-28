import Foundation
import PurlayContract
import Testing

@testable import PurlayMacUI

/// Settings → Account & Sessions draws each session as the kind of device it is on: the contract says browser or app, and the
/// name the device gave itself.
@Suite("the devices list's symbols")
struct DeviceSessionSymbolTests {
    private func session(kind: String, name: String?) throws -> DeviceSession {
        let named = name.map { "\"\($0)\"" } ?? "null"
        let json = """
            {"id":"0199155c-6200-7b7f-8c11-000000000bb1","kind":"\(kind)","name":\(named),\
            "createdAt":"2026-10-12T12:00:00.000Z","lastUsedAt":"2026-10-12T12:00:00.000Z",\
            "expiresAt":"2026-11-12T12:00:00.000Z","current":false}
            """
        return try JSONDecoder().decode(DeviceSession.self, from: Data(json.utf8))
    }

    @Test("a browser, an iPhone and an iPad by their names, and any other app session as a Mac")
    func symbols() throws {
        #expect(DeviceSessionsSection.symbol(for: try session(kind: "browser", name: nil)) == "safari")
        #expect(DeviceSessionsSection.symbol(for: try session(kind: "native", name: "Ada's iPhone")) == "iphone")
        #expect(DeviceSessionsSection.symbol(for: try session(kind: "native", name: "Ada’nın iPad’i")) == "ipad")
        #expect(DeviceSessionsSection.symbol(for: try session(kind: "native", name: "Studio")) == "desktopcomputer")
        #expect(DeviceSessionsSection.symbol(for: try session(kind: "native", name: nil)) == "desktopcomputer")
    }
}
