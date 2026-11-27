import ScriptureData
import SwiftUI

/// The notes column, shown as the window's inspector: this chapter's notes as rows and its
/// noteless highlights as compact rows, linked both ways to the text through `MarkupModel`.
///
/// Keyboard: Tab reaches the rows; ↑ and ↓ move between them and select each one's highlight;
/// Return edits (or starts a note on a highlight); Delete deletes, and ⌘Z brings it back.
public struct NotesColumnView: View {
    @Bindable var model: MarkupModel
    @FocusState private var focusedRow: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: MarkupModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Color.inkRule.frame(height: 1)
            if model.columnItems.isEmpty {
                // The header stays pinned at the top; only the empty state centres beneath it.
                ContentUnavailableView(
                    "No notes yet",
                    systemImage: "note.text",
                    description: Text("Select text in the chapter and right-click to highlight it or add a note."))
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                rows
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.paperPanel)
        // Hidden, or the assistant took the inspector: an edit in it ends (a row's own
        // disappearance is no sign, since rows leave the screen as the column scrolls).
        .onDisappear { model.notesColumnDidHide() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Notes")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if !model.columnItems.isEmpty {
                Text(model.columnItems.count, format: .number)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityLabel("\(model.columnItems.count) items")
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: AppSpacing.xxs) {
                    ForEach(model.columnItems) { item in
                        itemView(item)
                            .focusable(!isEditing(item))
                            .focused($focusedRow, equals: item.id)
                            .onKeyPress(.upArrow) { move(from: item.id, by: -1) }
                            .onKeyPress(.downArrow) { move(from: item.id, by: 1) }
                            .onKeyPress(.return) {
                                guard !isEditing(item) else { return .ignored }
                                edit(item)
                                return .handled
                            }
                            #if os(macOS)
                            .onDeleteCommand { if !isEditing(item) { delete(item) } }
                            #endif
                            .id(item.id)
                    }
                }
                .padding(AppSpacing.xs)
            }
            .onChange(of: model.selectedHighlightIDs) { _, ids in
                guard let first = ids.first, let item = model.columnItems.first(where: { highlightID(of: $0) == first }) else { return }
                scroll(proxy, to: item.id)
            }
            .onChange(of: model.editingNoteID) { _, noteID in
                guard let noteID, let item = model.columnItems.first(where: { if case .note(let card) = $0 { return card.id == noteID } else { return false } }) else { return }
                scroll(proxy, to: item.id)
            }
        }
    }

    @ViewBuilder
    private func itemView(_ item: NotesColumnItem) -> some View {
        switch item {
        case .note(let card):
            NoteRowView(
                card: card,
                book: model.book.flatMap(BookCatalog.book(code:)),
                isLit: card.highlightID.map { model.selectedHighlightIDs.contains($0) } ?? false,
                isEditing: model.editingNoteID == card.id,
                focusRequest: model.editorFocusRequest,
                draftReload: model.editorReloadRequest,
                colorChips: model.colorChips,
                onSelect: { select(item) },
                onBeginEdit: { edit(item) },
                onBodyChange: { model.updateNoteBody(noteID: card.id, body: $0) },
                onEndEdit: { model.endEditing(noteID: card.id) },
                onFinish: { model.noteFinished() },
                onDelete: { delete(item) },
                onRecolor: { colorID in
                    if let highlightID = card.highlightID { model.setColor(colorID, highlightID: highlightID) }
                })
        case .compactHighlight(let row):
            CompactHighlightRow(
                row: row,
                isLit: model.selectedHighlightIDs.contains(row.id),
                colorChips: model.colorChips,
                onSelect: { select(item) },
                onAddNote: { edit(item) },
                onDelete: { delete(item) },
                onRecolor: { model.setColor($0, highlightID: row.id) })
        }
    }

    // MARK: - Actions

    private func select(_ item: NotesColumnItem) {
        if let highlightID = highlightID(of: item) { model.focus(highlightID: highlightID) }
    }

    /// Opens the note's editor; on a noteless highlight, creates the note and opens it (an empty
    /// note is removed again when editing ends).
    private func edit(_ item: NotesColumnItem) {
        switch item {
        case .note(let card):
            if card.isDraft, let highlightID = card.highlightID {
                model.beginEditingDraft(highlightID: highlightID)
            } else {
                model.beginEditing(noteID: card.id)
            }
        case .compactHighlight(let row):
            model.focus(highlightID: row.id)
            model.beginEditingDraft(highlightID: row.id)
        }
    }

    private func delete(_ item: NotesColumnItem) {
        switch item {
        case .note(let card):
            if card.isDraft, let highlightID = card.highlightID {
                model.deleteHighlight(id: highlightID)
            } else {
                model.deleteNote(noteID: card.id)
            }
        case .compactHighlight(let row):
            model.deleteHighlight(id: row.id)
        }
    }

    private func move(from id: UUID, by delta: Int) -> KeyPress.Result {
        let items = model.columnItems
        guard let index = items.firstIndex(where: { $0.id == id }), items.indices.contains(index + delta) else { return .ignored }
        let target = items[index + delta]
        focusedRow = target.id
        select(target)
        return .handled
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: UUID) {
        if reduceMotion {
            proxy.scrollTo(id, anchor: .center)
        } else {
            withAnimation(.smooth) { proxy.scrollTo(id, anchor: .center) }
        }
    }

    // MARK: - Lookups

    private func isEditing(_ item: NotesColumnItem) -> Bool {
        if case .note(let card) = item { return model.editingNoteID == card.id || card.isDraft }
        return false
    }

    private func highlightID(of item: NotesColumnItem) -> UUID? {
        switch item {
        case .note(let card): card.highlightID
        case .compactHighlight(let row): row.id
        }
    }
}
