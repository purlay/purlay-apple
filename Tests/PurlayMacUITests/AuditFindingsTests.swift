import Foundation
import PurlayContract
import PurlayKit
import PurlayTokens
import Testing

@testable import PurlayMacUI

/// What the macOS audit changed in the feature views (from purlay-macos `feat/macos-27-audit-and-parity`, unfinished).
@MainActor
@Suite("the macOS audit's findings")
struct AuditFindingsTests {
    @Test("a scheduling or reminder failure is said in the app's words, and an error of another kind as unconfirmed")
    func schedulingAndReminderWords() {
        let scheduling: [SchedulingFailure] = [
            .unavailable, .files, .content, .time, .limit, .sent, .access, .failed, .sessionChanged,
        ]
        for failure in scheduling { #expect(!Words.scheduling(failure).isEmpty, "\(failure)") }
        #expect(Words.scheduling(CancellationError()) == Words.scheduling(SchedulingFailure.failed))
        #expect(Words.scheduling(SchedulingFailure.time) != Words.scheduling(SchedulingFailure.failed))

        let reminders: [ReminderFailure] = [.unavailable, .time, .validation, .access, .failed, .sessionChanged]
        for failure in reminders { #expect(!Words.reminder(failure).isEmpty, "\(failure)") }
        #expect(Words.reminder(CancellationError()) == Words.reminder(ReminderFailure.failed))
        #expect(Words.reminder(ReminderFailure.validation).contains("\(ContractConstants.messageRemindersMax)"))
    }

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
