import PurlayKit
import PurlayTokens
import SwiftUI

/// The quiet bar that says Deep Work is on, until when, with End (`UX.md` §8: a mode you can forget you are in is a mode that loses you
/// messages). The mention badges are not drawn while it lasts; the counts are kept, so they are all there when it ends.
struct DeepWorkBar: View {
    let model: AppModel

    var body: some View {
        if let end = model.deepWorkEnds {
            // The minutes are asked when drawn, and drawn again each half minute and at the end itself. The model compares the end
            // to the clock but nothing it observes changes when that moment passes, so the timeline is what takes the bar away.
            TimelineView(DeepWorkBarSchedule(end: end)) { context in
                if context.date < end, model.deepWorkEnds != nil {
                    HStack(spacing: Spacing.space2) {
                        Image(systemName: "moon.fill").foregroundStyle(.indigo)
                        Text("Deep Work until \(end, style: .time)")
                        Text("·").foregroundStyle(.secondary)
                        Text("\(model.deepWorkMinutesLeft) min left").foregroundStyle(.secondary)
                        Spacer()
                        Button("End") { Task { await model.endDeepWork() } }.controlSize(.small)
                    }
                    .font(.callout)
                    .padding(.horizontal, Spacing.space4)
                    .padding(.vertical, Spacing.space1 + Stroke.strokeFocus)
                    .background(.bar)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// Every half minute from now, and then the end itself, so the bar goes at the instant Deep Work does.
struct DeepWorkBarSchedule: TimelineSchedule {
    static let step: TimeInterval = 30
    let end: Date

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> UnfoldFirstSequence<Date> {
        sequence(first: startDate) { last in last >= end ? nil : min(last.addingTimeInterval(Self.step), end) }
    }
}

/// What the person can do about Deep Work, as menu items: off, each while to start it for; on, the end and what is left. The same items
/// serve the account menu and the menu bar.
public struct DeepWorkItems: View {
    let model: AppModel

    public init(model: AppModel) { self.model = model }

    public var body: some View {
        if model.deepWorkEnds != nil {
            Button("End Deep Work (\(model.deepWorkMinutesLeft) min left)") { Task { await model.endDeepWork() } }
        } else {
            Button("Deep Work for 30 Minutes") { Task { await model.startDeepWork(.halfHour) } }
            Button("Deep Work for an Hour") { Task { await model.startDeepWork(.hour) } }
            Button("Deep Work for 2 Hours") { Task { await model.startDeepWork(.twoHours) } }
            Button("Deep Work Until Tomorrow") { Task { await model.startDeepWork(.untilTomorrow) } }
        }
    }
}
