#if os(macOS)
import PurlayContract
import PurlayKit
import PurlayTokens
import PurlayWords
import SwiftUI

/// Forward (server D-217): a message sent on to another channel or conversation, as a message of the person's own whose last line
/// is the original's link, with a note if they want one. Nothing new is stored, and nobody sees more than they could: the link
/// opens the original only for those who may read it. It goes the way any message goes, through the outbox.
struct ForwardSheet: View {
    let model: AppModel
    let message: Message
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var note = ""
    @State private var target: Uuid?
    @State private var failed = false
    @FocusState private var searching: Bool

    /// The conversations the person can post in (an announcement channel only for its owners and admins), in the sidebar's
    /// order, found by name without case or accents.
    private var destinations: [Channel] {
        let all = model.sidebar.flatMap(\.channels).filter { model.canPost(to: $0.id, parent: nil) }
        let wanted = query.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return all }
        return all.filter { Words.channelLabel($0).localizedStandardContains(wanted) }
    }

    private var link: URL? { model.webURL(.message(message.id, in: message.channelId)) }

    /// The note, then the original's link on a line of its own: what the web client sends.
    nonisolated static func content(note: String, link: URL) -> String {
        let words = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? link.absoluteString : words + "\n\n" + link.absoluteString
    }

    private var tooLong: Bool {
        guard let link else { return false }
        return Self.content(note: note, link: link).count > ContractConstants.messageContentMax
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space3) {
            Text("Forward Message").font(.title2.bold())
            TextField("Search conversations", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searching)
                .accessibilityLabel("Search conversations")
            let found = destinations
            if found.isEmpty {
                ContentUnavailableView.search(text: query).frame(maxHeight: .infinity)
            } else {
                List(found, id: \.id, selection: $target) { channel in
                    Label(Words.channelLabel(channel), systemImage: Self.symbol(for: channel))
                        .lineLimit(1)
                        .tag(channel.id)
                }
                .listStyle(.bordered)
                .alternatingRowBackgrounds(.disabled)
                .frame(minHeight: 180)
            }
            TextField("Add a note (optional)", text: $note, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
            if tooLong {
                Text("The note is too long to send with the link.")
                    .font(.callout)
                    .foregroundStyle(Colors.dangerText.style)
            } else if failed {
                Text(SharedWords.messageNotSent)
                    .font(.callout)
                    .foregroundStyle(Colors.dangerText.style)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Forward", action: forward)
                    .keyboardShortcut(.defaultAction)
                    .disabled(target == nil || link == nil || tooLong)
            }
        }
        .padding(Spacing.space5)
        .frame(width: 440, height: 520)
        .onAppear { searching = true }
        // A conversation the search hides is no longer the one chosen, so Forward never sends where the person cannot see.
        .onChange(of: query) {
            if let target, !destinations.contains(where: { $0.id == target }) { self.target = nil }
        }
        .onChange(of: target) { failed = false }
    }

    private static func symbol(for channel: Channel) -> String {
        switch channel.type {
        case .directMessage: channel.peers.count > 1 ? "person.2" : "person"
        case .private: "lock"
        case .public, .unknown: "number"
        }
    }

    private func forward() {
        guard let target, let link else { return }
        if model.post(Self.content(note: note, link: link), to: target) { dismiss() } else { failed = true }
    }
}
#endif
