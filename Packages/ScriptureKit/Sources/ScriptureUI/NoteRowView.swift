import ScriptureData
import SwiftUI

/// One note in the column, as a row rather than a card: marker, reference and date on one line,
/// the quoted phrase in the page's serif, then the note as rendered markdown, or the editor with
/// its markdown toolbar while editing. No border and no fill at rest; the accent wash when its
/// highlight is selected.
///
/// The click contract (Things-like): the first click selects the row (its highlight is selected,
/// outlined and scrolled to in the reader); a click on a row already selected, Return, or the
/// Edit Note action opens the editor. A chapter note has nothing to select in the text, so a
/// click opens its editor at once. Delete is undoable, so it needs no confirmation.
public struct NoteRowView: View {
    @Environment(\.pageFace) private var pageFace
    let card: NoteCard
    /// The note's book, for a bare "5:3" in it.
    let book: Book?
    let isLit: Bool
    let isEditing: Bool
    /// Bumped by the model when editing starts; the editor then takes focus.
    let focusRequest: Int
    /// Bumped by the model when a choice or an append changed the note under the open editor
    /// (`MarkupModel.editorReloadRequest`); the draft is then reloaded from the card.
    let draftReload: Int
    let colorChips: [ColorChip]
    let onSelect: () -> Void
    let onBeginEdit: () -> Void
    let onBodyChange: (String) -> Void
    let onEndEdit: () -> Void
    /// The editor's own finish (⌘Return, Return or Esc), after `onEndEdit`; never a blur.
    let onFinish: () -> Void
    let onDelete: () -> Void
    let onRecolor: (UUID?) -> Void

    @AppStorage(NoteEditingKeys.settingKey) private var finishWithReturn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.undoManager) private var undoManager
    @ScaledMetric(relativeTo: .callout) private var inset: CGFloat = AppSpacing.sm
    @State private var draft = ""
    @State private var editorSelection = NSRange(location: 0, length: 0)
    @State private var endEditTask: Task<Void, Never>?
    @State private var editSession = 0
    @State private var versionsShown = false

    public init(
        card: NoteCard,
        book: Book? = nil,
        isLit: Bool,
        isEditing: Bool,
        focusRequest: Int = 0,
        draftReload: Int = 0,
        colorChips: [ColorChip] = [],
        onSelect: @escaping () -> Void,
        onBeginEdit: @escaping () -> Void,
        onBodyChange: @escaping (String) -> Void,
        onEndEdit: @escaping () -> Void,
        onFinish: @escaping () -> Void = {},
        onDelete: @escaping () -> Void,
        onRecolor: @escaping (UUID?) -> Void = { _ in }
    ) {
        self.card = card
        self.book = book
        self.isLit = isLit
        self.isEditing = isEditing
        self.focusRequest = focusRequest
        self.draftReload = draftReload
        self.colorChips = colorChips
        self.onSelect = onSelect
        self.onBeginEdit = onBeginEdit
        self.onBodyChange = onBodyChange
        self.onEndEdit = onEndEdit
        self.onFinish = onFinish
        self.onDelete = onDelete
        self.onRecolor = onRecolor
    }

    private var showsEditor: Bool { isEditing || card.isDraft }
    /// A click edits rather than selects when there is nothing left to select.
    private var clickEdits: Bool { isLit || card.highlightID == nil }
    /// The "2 versions" mark shows under the body while the editor does not; a count of 1 has none.
    private var showsVersionsMark: Bool { card.versionCount > 1 && !showsEditor }
    private var versionsText: String { VersionText.mark(count: card.versionCount) }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            header
            if !card.quotedText.isEmpty {
                Text(card.quotedText)
                    .font(pageFace.quoteFont())
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(2)
            }
            if showsEditor {
                markdownToolbar
                editor
            } else if !card.body.isEmpty {
                // Rendered, its references links that show their verses (spec 3.1).
                NoteBodyText(card.body, book: book, font: .callout)
            }
            if showsVersionsMark { versionsMark }
        }
        .padding(inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .columnRowSurface(isLit: isLit, reduceMotion: reduceMotion)
        .contentShape(Rectangle())
        // The editor is an AppKit view and keeps its own clicks.
        .onTapGesture { if !showsEditor { activate() } }
        .contextMenu {
            Button("Edit Note") { beginEdit() }
            Divider()
            Button(card.isDraft ? "Delete Highlight" : "Delete Note", role: .destructive) { delete() }
        }
        .accessibilityElement(children: showsEditor ? .contain : .combine)
        .accessibilityLabel(Self.spokenTitle(for: card, colorName: colorName))
        .accessibilityAddTraits(isLit ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { activate() }
        .accessibilityAction(named: "Edit Note") { beginEdit() }
        #if os(macOS)
        .accessibilityActions {
            if showsVersionsMark {
                Button(versionsText) { versionsShown = true }
            }
        }
        #endif
        .accessibilityAction(named: card.isDraft ? "Delete Highlight" : "Delete Note") { delete() }
        .colorActions(chips: card.isChapterNote ? [] : colorChips, current: card.colorID, onRecolor: onRecolor)
        .onChange(of: isEditing) { _, editing in
            if editing { editSession += 1; draft = card.body }
        }
        .onChange(of: card.isDraft) { _, _ in
            draft = card.body
        }
        .onChange(of: draftReload) { _, _ in
            if isEditing { draft = card.body }
        }
        // The mark went (settled elsewhere, an undo, a sync, or the editor opened) before the
        // popover closed itself: forget it, so it cannot reopen when a mark comes back.
        .onChange(of: showsVersionsMark) { _, shows in
            if !shows { versionsShown = false }
        }
    }

    private var colorName: String? {
        card.colorID.flatMap { id in colorChips.first { $0.id == id }?.name }
    }

    /// What VoiceOver reads for the row: "Note, John 15:5, Yellow" or "Chapter note, John 15", then
    /// ", 2 versions" when it has kept versions.
    nonisolated static func spokenTitle(for card: NoteCard, colorName: String?) -> String {
        let title = card.isChapterNote ? "Chapter note, \(card.referenceString)" : "Note, \(card.referenceString), \(colorName ?? "No color")"
        return card.versionCount > 1 ? "\(title), \(VersionText.mark(count: card.versionCount))" : title
    }

    /// On the Mac a button showing the versions in a popover on itself, closed once they are
    /// settled, its choices undone through the row's window; on the phone the mark alone.
    @ViewBuilder
    private var versionsMark: some View {
        #if os(macOS)
        VersionsMarkButton(text: versionsText, subject: .note(card.id), isShown: $versionsShown, undoManager: undoManager)
        #else
        VersionsMark(text: versionsText)
        #endif
    }

    private var header: some View {
        HStack(spacing: AppSpacing.xxs) {
            if card.isChapterNote {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityHidden(true)
            } else {
                ColorDotButton(color: card.color, colorID: card.colorID, chips: colorChips, onRecolor: onRecolor)
            }
            Text(card.referenceString)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: AppSpacing.xs)
            if !card.isDraft {
                Text(card.modifiedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.inkTertiary)
            }
            if isEditing {
                RowSymbolButton(title: "Done", symbol: "checkmark") {
                    endEditTask?.cancel()
                    onEndEdit()
                }
            }
            if isLit || showsEditor {
                RowSymbolButton(title: card.isDraft ? "Delete Highlight" : "Delete Note", symbol: "trash", role: .destructive) {
                    delete()
                }
            }
        }
    }

    private var markdownToolbar: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(MarkdownStyle.allCases, id: \.self) { style in
                RowSymbolButton(title: style.title, symbol: style.symbolName) { apply(style) }
            }
            Spacer()
        }
    }

    /// The only bordered element in a row: overlay paper, a hairline rule, the medium radius.
    private var editor: some View {
        editorField
            .padding(AppSpacing.xxs)
            .editorSurface()
            .onAppear { draft = card.body }
            .onChange(of: draft) { _, body in
                if body != card.body { onBodyChange(body) }
            }
    }

    @ViewBuilder
    private var editorField: some View {
        #if os(macOS)
        NoteTextEditor(
            text: $draft,
            selection: $editorSelection,
            focusRequest: card.isDraft ? -1 : focusRequest,
            finishWithReturn: finishWithReturn,
            onFocusChange: { focused in
                if focused {
                    endEditTask?.cancel()
                    if card.isDraft { onBeginEdit() }
                } else if isEditing {
                    // Deferred so a click on this row's own buttons runs before the edit ends,
                    // and bound to this editing session so it cannot end a later one.
                    let session = editSession
                    endEditTask = Task {
                        try? await Task.sleep(for: .milliseconds(200))
                        guard !Task.isCancelled, session == editSession else { return }
                        onEndEdit()
                    }
                }
            },
            onFinish: {
                endEditTask?.cancel()
                onEndEdit()
                onFinish()
            })
        #else
        TextEditor(text: $draft)
            .font(.callout)
            .frame(minHeight: 80)
        #endif
    }

    private func activate() {
        clickEdits ? beginEdit() : onSelect()
    }

    private func beginEdit() {
        guard !isEditing else { return }
        if card.highlightID != nil { onSelect() }
        onBeginEdit()
    }

    private func delete() {
        endEditTask?.cancel()
        onDelete()
    }

    private func apply(_ style: MarkdownStyle) {
        endEditTask?.cancel()
        if card.isDraft { onBeginEdit() }
        let result = MarkdownFormatting.apply(style, to: draft, selection: editorSelection)
        draft = result.text
        editorSelection = result.selection
    }
}
