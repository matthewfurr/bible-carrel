#if os(iOS)
import SwiftUI

/// The chapter's notes and highlights over the page, in the Mac column's rows and order
/// (`markup.columnItems`: the chapter notes, then each highlight with its note or as a compact
/// row). Tapping a row closes the sheet and hands the row to `onChoose`; the reader then scrolls
/// to it and opens its note.
public struct PhoneChapterNotesSheet: View {
    private let markup: MarkupModel
    private let onChoose: (NotesColumnItem) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(markup: MarkupModel, onChoose: @escaping (NotesColumnItem) -> Void) {
        self.markup = markup
        self.onChoose = onChoose
    }

    public var body: some View {
        NavigationStack {
            Group {
                if markup.columnItems.isEmpty {
                    ContentUnavailableView(
                        "No notes yet",
                        systemImage: "note.text",
                        description: Text("Press and hold text in the chapter to highlight it or add a note."))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.xxs) {
                            ForEach(markup.columnItems) { item in
                                row(item)
                            }
                        }
                        .padding(AppSpacing.xs)
                    }
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func row(_ item: NotesColumnItem) -> some View {
        switch item {
        case .note(let card):
            NoteRowView(
                card: card,
                isLit: card.highlightID.map { markup.selectedHighlightIDs.contains($0) } ?? false,
                isEditing: false,
                colorChips: markup.colorChips,
                onSelect: { choose(item) },
                onBeginEdit: { choose(item) },
                onBodyChange: { _ in },
                onEndEdit: {},
                onDelete: {
                    if card.isDraft, let highlightID = card.highlightID {
                        markup.deleteHighlight(id: highlightID)
                    } else {
                        markup.deleteNote(noteID: card.id)
                    }
                },
                onRecolor: { colorID in
                    if let highlightID = card.highlightID { markup.setColor(colorID, highlightID: highlightID) }
                })
        case .compactHighlight(let compact):
            CompactHighlightRow(
                row: compact,
                isLit: markup.selectedHighlightIDs.contains(compact.id),
                colorChips: markup.colorChips,
                onSelect: { choose(item) },
                onAddNote: { choose(item) },
                onDelete: { markup.deleteHighlight(id: compact.id) },
                onRecolor: { markup.setColor($0, highlightID: compact.id) })
        }
    }

    /// One tap opens: a row's select and edit both land here (a lit row's tap calls both, for
    /// the same row, so the second changes nothing).
    private func choose(_ item: NotesColumnItem) {
        onChoose(item)
        dismiss()
    }
}
#endif
