#if os(iOS)
import ScriptureData
import SwiftUI
import UIKit

/// One note over the page (spec 3, Matt chose option A, 2026-11-12). It opens to be read, at
/// half height: the reference as its title, the quoted words on their highlight's color, and the
/// note rendered with no markdown symbols, its references links (`NoteBodyText`). **Edit** turns
/// the same sheet into the editor with the keyboard up; **Done** returns to the note as it
/// reads; a swipe down closes it either way. Every change is saved as it is typed and nothing is
/// discarded; a note left empty is removed, as on the Mac. A new, empty note, and Add Note or Edit
/// Note, open straight into the editor (`startsEditing`).
///
/// A tapped reference shows its verses inside the sheet, pushed with Back to the note, and **Open
/// in Read**, a lookup that keeps the reading place. Along the foot, the mark's actions: its
/// color (the edit bar's list), bookmark, Ask and delete, then a menu with Copy, Copy with
/// Reference and Share; a chapter note, with no mark, has delete alone. Delete closes the sheet
/// and is undoable.
public struct PhoneNoteSheet: View {
    @Environment(\.pageFace) private var pageFace
    @Environment(\.noteLinks) private var links
    @Environment(\.dismiss) private var dismiss
    private let noteID: UUID
    private let markup: MarkupModel
    @State private var draft: String
    @State private var isEditing: Bool
    /// The references opened from the note, pushed over it.
    @State private var path: [Reference] = []
    @Environment(\.noteVersions) private var versions
    /// The versions page pushed over the note (spec 4.1).
    @State private var showsVersions = false

    public init(noteID: UUID, markup: MarkupModel, startsEditing: Bool = false) {
        self.noteID = noteID
        self.markup = markup
        let body = Self.card(noteID, in: markup)?.body ?? ""
        _draft = State(initialValue: body)
        // Nothing to read yet: straight into the editor.
        _isEditing = State(initialValue: startsEditing || body.isEmpty)
    }

    static func card(_ noteID: UUID, in markup: MarkupModel) -> NoteCard? {
        for case .note(let card) in markup.columnItems where card.id == noteID { return card }
        return markup.chapterNotes.first { $0.id == noteID }
    }

    private var card: NoteCard? { Self.card(noteID, in: markup) }
    private var book: Book? { markup.book.flatMap(BookCatalog.book(code:)) }

    public var body: some View {
        NavigationStack(path: $path) {
            page
                .containerBackground(Color.paperPage, for: .navigation)
                .navigationTitle(card?.referenceString ?? "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .navigationDestination(for: Reference.self) { reference in
                    verses(reference)
                }
                .navigationDestination(isPresented: $showsVersions) { versionsPage }
        }
        .presentationDetents([.medium, .large])
        .tint(Color.accent)
        .onAppear {
            if isEditing { beginEditing() }
            if let highlightID = card?.highlightID { markup.focus(highlightID: highlightID) }
        }
        .onChange(of: draft) { _, body in
            if isEditing, body != card?.body { markup.updateNoteBody(noteID: noteID, body: body) }
        }
        // A choice or an append changed the note under the editor: the draft is the note's again.
        .onChange(of: markup.editorReloadRequest) { _, _ in
            if isEditing, markup.editingNoteID == noteID, let body = card?.body { draft = body }
        }
        .onDisappear {
            if isEditing { markup.endEditing(noteID: noteID) }
        }
        // Deleted on another device, the chapter changed under it, or emptied and put away.
        .onChange(of: card == nil) { _, gone in
            if gone { dismiss() }
        }
    }

    @ViewBuilder private var page: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if let card, !card.quotedText.isEmpty { quote(card) }
                PhoneNoteTextEditor(text: $draft, focusOnAppear: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .editorSurface()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    if let card, !card.quotedText.isEmpty { quote(card) }
                    // A reference to verses the translation lacks shows nothing, as in a reply.
                    NoteBodyText(card?.body ?? draft, book: book, font: .body) { reference in
                        if links?.preview(reference) != nil { path.append(reference) }
                    }
                    if let card, card.versionCount > 1, versions != nil { versionsMark(card) }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", systemImage: "checkmark") { finishEditing() }
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { startEditing() }
            }
            ToolbarItemGroup(placement: .bottomBar) { foot }
        }
    }

    // MARK: - Reading and editing

    private func beginEditing() {
        if markup.editingNoteID != noteID { markup.beginEditing(noteID: noteID) }
    }

    private func startEditing() {
        draft = card?.body ?? draft
        isEditing = true
        beginEditing()
    }

    /// Done: back to the note as it reads. A note left empty is removed by the edit's end, and
    /// the sheet goes with it.
    private func finishEditing() {
        markup.endEditing(noteID: noteID)
        isEditing = false
    }

    // MARK: - The foot

    @ViewBuilder private var foot: some View {
        if let card, let highlightID = card.highlightID, let report = markup.report(forHighlight: highlightID) {
            colorMenu(card, highlightID: highlightID)
            Spacer()
            bookmarkButton(report)
            Spacer()
            Button("Ask", systemImage: "sparkles") {
                markup.onAskAboutPassage?(report)
            }
            .disabled(markup.onAskAboutPassage == nil)
            Spacer()
            Button("Delete", systemImage: "trash", role: .destructive) {
                dismiss()
                markup.deleteHighlight(id: highlightID)
            }
            Spacer()
            Menu("More", systemImage: "ellipsis") {
                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = markup.copyText(for: report) }
                Button("Copy with Reference", systemImage: "text.quote") {
                    UIPasteboard.general.string = markup.copyWithReference(for: report)
                }
                ShareLink(item: markup.shareText(for: report)) { Label("Share…", systemImage: "square.and.arrow.up") }
            }
        } else {
            Spacer()
            Button("Delete", systemImage: "trash", role: .destructive) {
                dismiss()
                markup.deleteNote(noteID: noteID)
            }
        }
    }

    /// The highlight's color as a chip; its list is the edit bar's colors, the current one checked.
    private func colorMenu(_ card: NoteCard, highlightID: UUID) -> some View {
        let traits = UITraitCollection.current
        let current = markup.colorChips.first { $0.id == card.colorID }
        let selection = Binding<UUID?>(get: { card.colorID }, set: { markup.setColor($0, highlightID: highlightID) })
        return Menu {
            Picker("Highlight color", selection: selection) {
                ForEach(markup.colorChips) { chip in
                    Label { Text(chip.name) } icon: { Image(uiImage: PhoneMarkupMenu.swatchImage(fill: chip.color.platformColor, traits: traits)) }
                        .tag(Optional(chip.id))
                }
                Label { Text("No Color") } icon: { Image(uiImage: PhoneMarkupMenu.noColorImage(traits: traits)) }
                    .tag(UUID?.none)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Label {
                Text("Highlight color")
            } icon: {
                Image(uiImage: current.map { PhoneMarkupMenu.swatchImage(fill: $0.color.platformColor, traits: traits) }
                      ?? PhoneMarkupMenu.noColorImage(traits: traits))
            }
        }
        .accessibilityValue(current?.name ?? "No color")
    }

    private func bookmarkButton(_ report: SelectionReport) -> some View {
        let verse = report.selection.verse
        let isSet = markup.bookmarksByChapter[report.selection.chapter]?.contains(verse) ?? false
        return Button(isSet ? "Remove Bookmark from Verse \(verse)" : "Bookmark Verse \(verse)",
                      systemImage: isSet ? "bookmark.fill" : "bookmark") {
            markup.toggleBookmark(for: report)
        }
    }

    // MARK: - Versions

    /// Under the note's text while it is read: the quiet mark, a button a scaled 44 pt tall that
    /// pushes the versions (spec 4.1). Not shown while editing.
    private func versionsMark(_ card: NoteCard) -> some View {
        PhoneVersionsMarkButton(text: VersionText.mark(count: card.versionCount)) { showsVersions = true }
    }

    /// The versions of the note open in the sheet, pushed over it. A choice that changes the note's
    /// text reloads the card, so the note reads as chosen when the page pops; once nothing is left
    /// to settle the page pops itself.
    private var versionsPage: some View {
        PhoneNoteVersionsPage(noteID: noteID, undoManager: markup.undoManager) { showsVersions = false }
    }

    // MARK: - A reference's verses

    @ViewBuilder private func verses(_ reference: Reference) -> some View {
        if let preview = links?.preview(reference) {
            ScrollView {
                VersePreviewView(preview: preview, openTitle: "Open in Read") {
                    links?.open(reference)
                }
                .padding(AppSpacing.md)
            }
            // The verses name themselves; on the page's paper, as the note is, so nothing of the
            // note shows through behind them.
            .navigationBarTitleDisplayMode(.inline)
            .containerBackground(Color.paperPage, for: .navigation)
        } else {
            ContentUnavailableView("Not in This Translation", systemImage: "book",
                                   description: Text("\(reference.displayString) is not in the translation being read."))
        }
    }

    /// The quoted words in the page's serif on their highlight color, or over the noteless
    /// anchor's dotted underline. Primary ink, which every mark color keeps readable.
    private func quote(_ card: NoteCard) -> some View {
        var words = AttributedString(card.quotedText)
        if let color = card.color {
            words.backgroundColor = Color(markup: color)
        } else {
            words.underlineStyle = Text.LineStyle(pattern: .dot, color: .inkSecondary)
        }
        return Text(words)
            .font(pageFace.quoteFont())
            .foregroundStyle(Color.inkPrimary)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The quiet versions mark as a button, as tall as the thumb needs: 44 pt, and taller with the text
/// size, never shorter (a scaled metric alone would shrink below the default size).
struct PhoneVersionsMarkButton: View {
    let text: String
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44

    var body: some View {
        Button(action: action) {
            VersionsMark(text: text)
                .frame(minHeight: max(44, height))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityHint("Shows the versions of this note")
    }
}

/// The page pushed over a note in its sheet: the note's versions in a scroll view padded `md`,
/// titled "Versions" inline, on the page's paper. It asks `onSettled` to pop it once nothing is left
/// to settle.
struct PhoneNoteVersionsPage: View {
    @Environment(\.noteVersions) private var versions
    let noteID: UUID
    let undoManager: UndoManager?
    let onSettled: () -> Void

    var body: some View {
        if let versions {
            ScrollView {
                NoteVersionsView(subject: .note(noteID), model: versions, undoManager: undoManager, onSettled: onSettled)
                    .padding(AppSpacing.md)
            }
            .navigationTitle("Versions")
            .navigationBarTitleDisplayMode(.inline)
            .containerBackground(Color.paperPage, for: .navigation)
            // A shake asks the first responder for its undo manager: this answers with the window's.
            .background { UndoResponder(undoManager: undoManager).frame(width: 0, height: 0) }
        }
    }
}
#endif
