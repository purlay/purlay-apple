import Testing

@testable import Purlay

/// VoiceOver does not read a banner that appears on its own, so each new notice is announced: once, when it arrives.
@Suite("which notices VoiceOver is told of")
struct NoticeAnnouncementTests {
    private struct Said: Identifiable, Equatable {
        let id: Int
    }

    private let first = Said(id: 1)
    private let second = Said(id: 2)

    @Test("a notice that arrives is announced")
    func arrival() {
        #expect(NoticeList.arrivals(from: [], to: [first]) == [first])
    }

    @Test("a notice already shown is not announced again when another arrives")
    func onlyTheNewOne() {
        #expect(NoticeList.arrivals(from: [first], to: [first, second]) == [second])
    }

    @Test("dismissing a notice, or nothing changing, announces nothing")
    func nothingNew() {
        #expect(NoticeList.arrivals(from: [first, second], to: [second]).isEmpty)
        #expect(NoticeList.arrivals(from: [first], to: [first]).isEmpty)
    }

    @Test("notices that arrive together are each announced, in order")
    func together() {
        #expect(NoticeList.arrivals(from: [], to: [first, second]) == [first, second])
    }
}
