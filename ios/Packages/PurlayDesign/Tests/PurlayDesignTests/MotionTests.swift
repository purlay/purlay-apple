import SwiftUI
import Testing

@testable import PurlayDesign

@Suite("motion")
struct MotionTests {
    @Test("Reduce Motion turns every movement into a short fade")
    func reduceMotion() {
        for motion in [Motion.smooth, .snappy] {
            #expect(motion.animation(reduceMotion: true) == .easeInOut(duration: 0.15))
            #expect(motion.animation(reduceMotion: false) != .easeInOut(duration: 0.15))
        }
    }
}
