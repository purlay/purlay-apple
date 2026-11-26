import PurlayContract
import PurlayKit
import SwiftUI
import Testing

@testable import PurlayMacUI

@MainActor
@Suite("the Mac's words")
struct MacWordsTests {
    @Test("an incident is named by its level and state, and the worst levels are red")
    func incidentWords() {
        let urgent = ChannelIncident(severity: .v1, status: .investigating)
        #expect(urgent.severityName == "SEV1" && urgent.tint == .red)
        #expect(ChannelIncident(severity: .v3, status: .mitigating).tint == .orange)
        #expect(ChannelIncident(severity: .unknown(7), status: .unknown("x")).severityName == "SEV7")
    }
}
