#if os(macOS)
import PurlayDesign
import PurlayKit
import PurlayTokens
import SwiftUI

struct SidebarOrganizer: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var editing: UUID?
    @State private var invalid = false
    @State private var saving = false
    @State private var removing: GroupToRemove?

    private struct GroupToRemove {
        let id: UUID
        let name: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space4) {
            SheetHeading(
                title: "Organize Sidebar", subtitle: "Keep related conversations together, on every device you use.",
                image: "sidebar.left")
            HStack {
                TextField(editing == nil ? "New group name" : "Group name", text: $name)
                    .purlayTextField()
                    .onSubmit(save)
                    .onChange(of: name) { _, _ in invalid = false }
                Button(editing == nil ? "Add Group" : "Save", action: save)
                    .disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if editing != nil {
                    Button("Cancel Rename") {
                        editing = nil
                        name = ""
                        invalid = false
                    }
                }
            }
            if invalid {
                Text("Use a unique group name of 1–64 characters.")
                    .font(.callout).foregroundStyle(Colors.dangerText.style)
            }
            List {
                ForEach(Array(model.sidebar.enumerated()), id: \.element.id) { index, section in
                    HStack(spacing: Spacing.space2) {
                        VStack(alignment: .leading) {
                            Text(Words.header(section.kind)).fontWeight(.medium)
                            Text("\(section.channels.count) conversations").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if case .custom(let id, let name) = section.kind {
                            Button("Rename \(name)", systemImage: "pencil") {
                                editing = id
                                self.name = name
                                invalid = false
                            }
                            .labelStyle(.iconOnly)
                            Button("Remove Group \(name)", systemImage: "trash", role: .destructive) {
                                removing = GroupToRemove(id: id, name: name)
                            }
                            .labelStyle(.iconOnly)
                            .help("Remove the group and return its conversations to their default sections")
                        }
                        Button("Move \(Words.header(section.kind)) Up", systemImage: "arrow.up") {
                            model.moveSidebarSection(section.id, by: -1)
                        }
                        .labelStyle(.iconOnly).disabled(index == 0)
                        Button("Move \(Words.header(section.kind)) Down", systemImage: "arrow.down") {
                            model.moveSidebarSection(section.id, by: 1)
                        }
                        .labelStyle(.iconOnly).disabled(index == model.sidebar.count - 1)
                    }
                    .padding(.vertical, Spacing.space2)
                    .buttonStyle(.borderless)
                }
            }
            Text(
                "Drag conversations within a section to reorder them. Use a conversation’s menu to move it into a group."
            )
            .font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.space5)
        .frame(width: 580, height: 500)
        .confirmationDialog(
            "Remove this group?",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible,
            presenting: removing
        ) { group in
            Button("Remove Group", role: .destructive) { remove(group) }
            Button("Cancel", role: .cancel) {}
        } message: { group in
            Text("“\(group.name)” is removed and its conversations return to their default sections.")
        }
    }

    private func remove(_ group: GroupToRemove) {
        Task { await model.removeSidebarGroup(group.id) }
        if editing == group.id {
            editing = nil
            name = ""
        }
    }

    private func save() {
        // Return in the field and the button can both ask while the first save is still on its way.
        guard !saving else { return }
        saving = true
        Task {
            defer { saving = false }
            if await model.saveSidebarGroup(editing, name: name) {
                name = ""
                editing = nil
                invalid = false
            } else {
                invalid = true
            }
        }
    }
}
#endif
