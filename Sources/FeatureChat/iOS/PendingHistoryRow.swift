import PurlayKit
import PurlayTokens
import SwiftUI

struct PendingHistoryRow: View {
    let message: PendingMessage
    let words: ChatStrings
    let retry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            Text(verbatim: message.content)
                .textSelection(.enabled)
            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if message.delivery == .failed, let retry {
                Button(action: retry) {
                    Text(words.retryMessage)
                        .frame(minHeight: Size.sizeTouch, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("chat.outbox.retry")
            }
        }
        .padding(.vertical, Spacing.space2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.pending.\(message.id.value)")
    }

    private var status: LocalizedStringResource {
        switch message.delivery {
        case .sending: words.sendingMessage
        case .sent: words.sentMessage
        case .failed: words.messageSendFailed
        }
    }
}
