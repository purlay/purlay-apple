import Foundation
import Testing

@testable import PurlayMacUI

/// What the macOS audit changed in the feature views (from purlay-macos `feat/macos-27-audit-and-parity`).
@MainActor
@Suite("the macOS audit's findings")
struct AuditFindingsTests {
    @Test("the Deep Work bar is drawn again every half minute and at the end itself, and not after it")
    func deepWorkBarSchedule() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = start.addingTimeInterval(75)
        let entries = Array(DeepWorkBarSchedule(end: end).entries(from: start, mode: .normal))
        #expect(entries == [start, start.addingTimeInterval(30), start.addingTimeInterval(60), end])

        let past = Array(DeepWorkBarSchedule(end: start).entries(from: end, mode: .normal))
        #expect(past == [end])
    }
}
