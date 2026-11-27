import SwiftUI
import Testing
import simd

@testable import Purlay

@MainActor
@Suite("the drift of Welcome's field")
struct EntryBackdropTests {
    private let resting = EntryBackdrop.points(after: 0)

    @Test("it starts at rest, reaches the drifted points after one way, and is back at rest after the return")
    func cycle() {
        let oneWay = EntryBackdrop.driftDuration
        #expect(EntryBackdrop.points(after: oneWay) == EntryBackdrop.drifted)
        #expect(EntryBackdrop.points(after: 2 * oneWay) == resting)
        #expect(EntryBackdrop.points(after: 5 * oneWay) == EntryBackdrop.drifted)
    }

    @Test("it eases: halfway in time is halfway in place, and the first second moves less than the middle one")
    func eases() throws {
        let oneWay = EntryBackdrop.driftDuration
        let middle = EntryBackdrop.points(after: oneWay / 2)
        for (index, point) in middle.enumerated() {
            let halfway = (resting[index] + EntryBackdrop.drifted[index]) / 2
            #expect(abs(point.x - halfway.x) < 0.0001 && abs(point.y - halfway.y) < 0.0001)
        }
        func moved(_ from: TimeInterval, _ to: TimeInterval) -> Float {
            zip(EntryBackdrop.points(after: from), EntryBackdrop.points(after: to))
                .map { simd_distance($0, $1) }.reduce(0, +)
        }
        #expect(moved(0, 1) < moved(oneWay / 2 - 0.5, oneWay / 2 + 0.5))
    }

    @Test("it is drawn at most 15 times a second: slow enough to cost little, often enough to look continuous")
    func rate() {
        #expect(EntryBackdrop.frameInterval >= 1.0 / 15)
        // The farthest any point moves between two drawn frames, at the fastest part of the drift, in thousandths of the field.
        let step =
            zip(
                EntryBackdrop.points(after: EntryBackdrop.driftDuration / 2),
                EntryBackdrop.points(after: EntryBackdrop.driftDuration / 2 + EntryBackdrop.frameInterval)
            ).map { simd_distance($0, $1) }.max() ?? 0
        #expect(step < 0.003)
    }
}
