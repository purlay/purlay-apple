import Testing

@testable import Purlay

@MainActor
@Suite("what the connecting screen says after a moment")
struct ConnectingViewTests {
    /// Whether the status was revealed; a class, so the waiting task and the test see one value.
    private final class Revealed {
        var shown = false
    }

    @Test("a screen that left before the moment passed shows and announces nothing")
    func leftEarly() async {
        let revealed = Revealed()
        let wait = Task { await ConnectingView.revealStatus(after: .seconds(60)) { revealed.shown = true } }
        wait.cancel()
        await wait.value
        #expect(!revealed.shown)
    }

    @Test("a screen still there when the moment has passed says what is under way")
    func stayed() async {
        let revealed = Revealed()
        await ConnectingView.revealStatus(after: .milliseconds(1)) { revealed.shown = true }
        #expect(revealed.shown)
    }
}
