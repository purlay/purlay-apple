import AppKit
import OSLog
import PurlayContract
import PurlayKit
import PurlayMacUI
import UserNotifications

/// Tells the person what needs them where they are not looking: the Dock badge, and a notice of the system for what is new while the
/// window is not in front. What decides is the model's (`Attention`); this shows, and nothing here knows what a message said.
///
/// The system is asked for permission the first time there is something to tell, not on launch: a question with no reason is a question
/// people say no to. No sound: the system sounds a notice by the person's own settings, and a second sound would double it (D-148 §6).
@MainActor
final class SystemAttention: NSObject, AttentionPresenter, UNUserNotificationCenterDelegate {
    /// Opens a conversation, from a click on its notice.
    var open: ((Uuid, String?) -> Void)?
    /// Sends what was typed into a conversation's notice, to that conversation, without bringing the app forward.
    var reply: ((Uuid, String?, String) async -> Void)?
    var openLink: ((URL) -> Void)?
    private var reminderChanges: [String: UUID] = [:]
    private var reminderTasks: [String: Task<Void, Never>] = [:]
    var bringForward: (() -> Void)?

    private let center = UNUserNotificationCenter.current()
    private let log: Logger
    /// A conversation's notice can be answered where it is, as Messages' can: what is typed is sent, and nothing of what was said
    /// is in the notice itself.
    private nonisolated static let conversation = "conversation"
    private nonisolated static let replyAction = "reply"

    /// `log`: the app's `attention` log, where what the system refused is kept.
    init(log: Logger) {
        self.log = log
        super.init()
        center.delegate = self
        let reply = UNTextInputNotificationAction(
            identifier: Self.replyAction, title: String(localized: "Reply"), options: [],
            textInputButtonTitle: String(localized: "Send"), textInputPlaceholder: String(localized: "Message"))
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.conversation, actions: [reply], intentIdentifiers: [])
        ])
    }

    func setBadge(_ count: Int?) {
        NSApp?.dockTile.badgeLabel = count.map { $0 > 99 ? "99+" : String($0) }
        guard count != nil else { return }
        // Permission given before the badge was asked for stays without it; asking again with it is how it is added.
        Task { [center] in
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized, settings.badgeSetting == .notSupported else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .badge])
        }
    }

    func show(_ notice: AttentionNotice) {
        Task { [center, log] in
            guard await Self.mayTell(center) else { return }
            let content = UNMutableNotificationContent()
            content.title = AttentionWords.title(notice)
            content.body = AttentionWords.body(notice)
            if case .place(let channel, _, _) = notice.content {
                content.userInfo = ["channel": channel.value]
                content.categoryIdentifier = Self.conversation
                if let source = notice.sourceID { content.userInfo["source"] = source }
                // Notification Center stacks a conversation's notices together.
                content.threadIdentifier = notice.id
            }
            // One per conversation: the next replaces the last, which the identifier does.
            do {
                try await center.add(UNNotificationRequest(identifier: notice.id, content: content, trigger: nil))
            } catch {
                // Nothing to say in the app (the person sees the badge and the sidebar); kept for "notices never come".
                log.error("the system refused a notice: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func retract(_ ids: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: ids)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func replaceReminders(_ notices: [ReminderNotice], scope: String) {
        let change = UUID()
        reminderChanges[scope] = change
        let prefix = "purlay-reminder:\(scope):"
        let previous = reminderTasks[scope]
        reminderTasks[scope] = Task { [center, log] in
            await previous?.value
            guard reminderChanges[scope] == change else { return }
            let pending = await center.pendingNotificationRequests()
            guard reminderChanges[scope] == change else { return }
            let wanted = Set(notices.map { prefix + $0.id })
            // A server delivery may precede Notification Center by a few milliseconds. Leave a due
            // local request to fire; explicit cancellation/sign-out uses the methods below.
            let obsolete = pending.filter {
                $0.identifier.hasPrefix(prefix) && !wanted.contains($0.identifier)
                    && (($0.content.userInfo["reminderAt"] as? Double).map(Date.init(timeIntervalSince1970:))
                        ?? .distantPast) > .now.addingTimeInterval(2)
            }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: obsolete)
            guard !notices.isEmpty, await Self.mayTell(center), reminderChanges[scope] == change else { return }
            for notice in notices where notice.date > .now {
                guard reminderChanges[scope] == change else { return }
                let content = UNMutableNotificationContent()
                content.title = String(localized: "Message Reminder")
                content.body = String(localized: "Return to your message in \(notice.label).")
                content.userInfo = [
                    "reminderLink": notice.link.absoluteString, "reminderAt": notice.date.timeIntervalSince1970,
                ]
                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, notice.date.timeIntervalSinceNow), repeats: false)
                let name = prefix + notice.id
                do {
                    try await center.add(UNNotificationRequest(identifier: name, content: content, trigger: trigger))
                    if reminderChanges[scope] != change {
                        center.removePendingNotificationRequests(withIdentifiers: [name])
                    }
                } catch {
                    log.error(
                        "the system refused a reminder: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    func cancelReminders(_ ids: [String], scope: String) {
        reminderChanges[scope] = UUID()
        let names = ids.map { "purlay-reminder:\(scope):\($0)" }
        retract(names)
        let previous = reminderTasks[scope]
        reminderTasks[scope] = Task {
            await previous?.value
            retract(names)
        }
    }

    func clearReminders(scope: String) {
        let change = UUID()
        reminderChanges[scope] = change
        let prefix = "purlay-reminder:\(scope):"
        let previous = reminderTasks[scope]
        reminderTasks[scope] = Task { [center] in
            await previous?.value
            guard reminderChanges[scope] == change else { return }
            let pending = await center.pendingNotificationRequests()
            let delivered = await center.deliveredNotifications()
            guard reminderChanges[scope] == change else { return }
            retract(
                pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
                    + delivered.map(\.request.identifier).filter { $0.hasPrefix(prefix) })
        }
    }

    /// Whether a notice may be shown, asking the system once if it has never been asked.
    private static func mayTell(_ center: UNUserNotificationCenter) async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined: return (try? await center.requestAuthorization(options: [.alert, .badge])) ?? false
        default: return false
        }
    }

    // MARK: Delegate

    /// A notice is only added while the window is not in front, but if it is in front by the time the system delivers it, it says nothing.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.content.userInfo["reminderLink"] is String ? [.banner, .list] : []
    }

    /// Hands a reply to the app, and returns once it is sent or kept: the system may have started the app only to deliver it.
    private func answer(_ channel: Uuid, source: String?, text: String) async {
        await reply?(channel, source, text)
    }

    /// A click brings the window forward on the conversation; a reply typed into the notice is sent and leaves the window where it is.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let channel = (response.notification.request.content.userInfo["channel"] as? String).flatMap(Uuid.init)
        let source = response.notification.request.content.userInfo["source"] as? String
        if response.actionIdentifier == Self.replyAction, let channel,
            let text = (response as? UNTextInputNotificationResponse)?.userText
        {
            await answer(channel, source: source, text: text)
            return
        }
        let reminderLink = (response.notification.request.content.userInfo["reminderLink"] as? String).flatMap(
            URL.init(string:))
        await MainActor.run {
            bringForward?()
            NSApp.activate()
            NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
            if let reminderLink { openLink?(reminderLink) } else if let channel { open?(channel, source) }
        }
    }
}
