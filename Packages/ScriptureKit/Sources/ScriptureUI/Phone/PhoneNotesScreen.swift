#if os(iOS)
import OSLog
import SwiftUI
import UIKit

/// The Notes tab: everything marked, newest first, narrowed by three menus (how far back, what
/// kind, which order). A row opens its verse in the reader as a lookup, or its conversation in
/// Ask; a swipe deletes it, undoably; the `ellipsis` menu shares what is listed as Markdown.
public struct PhoneNotesScreen: View {
    @Bindable private var notesBrowser: NotesBrowserModel
    private let navigation: NavigationModel
    private let markup: MarkupModel
    private let assistant: AssistantModel
    private let exporter: NotesExporter
    private let shell: PhoneShellModel
    @Environment(\.undoManager) private var undoManager
    @Environment(\.noteVersions) private var versions
    @State private var exportFailed = false
    /// The kept version whose note is gone that is open in its sheet.
    @State private var keptVersion: KeptVersionSheet?

    /// What a kept version's sheet needs: it is told apart by the version's id.
    private struct KeptVersionSheet: Identifiable {
        let id: UUID
        let reference: String
    }

    private static let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "export")

    public init(notesBrowser: NotesBrowserModel, navigation: NavigationModel, markup: MarkupModel,
                assistant: AssistantModel, exporter: NotesExporter, shell: PhoneShellModel) {
        self.notesBrowser = notesBrowser
        self.navigation = navigation
        self.markup = markup
        self.assistant = assistant
        self.exporter = exporter
        self.shell = shell
    }

    public var body: some View {
        NavigationStack {
            list
                .overlay {
                    // Over the list, never in front of its menus: taps pass through to them.
                    if notesBrowser.entries.isEmpty { emptyState.allowsHitTesting(false) }
                }
                .background(Color.paperPage)
                .navigationTitle("Notes")
                .toolbar { toolbarContent }
        }
        // Marks made in the reader meanwhile show when the tab comes back; sync reloads the model itself.
        .onAppear { notesBrowser.reload() }
        // The scene's undo manager, so a swiped delete comes back with shake or a three-finger swipe.
        .onChange(of: undoManager, initial: true) { _, manager in
            notesBrowser.undoManager = manager
        }
        // A list holds no first responder, and shake and ⌘Z ask the first responder for its undo
        // manager: this one answers with the scene's while the tab shows.
        .background { UndoResponder(undoManager: undoManager).frame(width: 0, height: 0) }
        .alert("The notes could not be exported.", isPresented: $exportFailed) {
            Button("OK") {}
        }
        .sheet(item: $keptVersion) { sheet in
            // Opened only when the model is there (`open`), so this never presents empty.
            if let versions {
                PhoneVersionSheet(id: sheet.id, reference: sheet.reference, model: versions, undoManager: undoManager)
            }
        }
    }

    private var list: some View {
        List {
            // With nothing marked there is nothing to narrow.
            if notesBrowser.totalCount > 0 {
                menus
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.paperPage)
            }
            PhoneNotesGroups(model: notesBrowser) { row(for: $0) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(for entry: NotesBrowserEntry) -> some View {
        Button { open(entry) } label: { Self.markRow(for: entry) }
        // One hairline the full width of every row, whether or not it leads with a symbol.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .listRowBackground(Color.paperPage)
        .listRowSeparatorTint(Color.inkRule)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if Self.isKeptVersion(entry) {
                // Never red: a discarded version comes back with a shake.
                Button("Discard", systemImage: "trash") { notesBrowser.delete(id: entry.id) }
            } else {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    notesBrowser.delete(id: entry.id)
                }
            }
        }
    }

    /// A mark's row: the symbol, the reference and date, the quoted words and the note's first block.
    static func markRow(for entry: NotesBrowserEntry) -> PhoneMarkRow {
        PhoneMarkRow(
            symbolName: symbolName(for: entry),
            reference: entry.referenceString,
            date: entry.modifiedAt,
            // A conversation's last line is the assistant's, not scripture: its title stands alone.
            quotedText: isThread(entry) ? "" : entry.quotedText,
            color: entry.color,
            body: noteBody(for: entry),
            versions: PhoneNotesKinds.mark(for: entry))
        .kind(kindName(for: entry))
    }

    /// The headings the list shows, group by group: each day with its count when sorted by date,
    /// each book with none when sorted by passage (the phone's book headings stay as they were).
    @MainActor static func notesHeadings(for model: NotesBrowserModel) -> [(title: String, count: String?)] {
        let byDate = model.sort == .date
        return model.groups.map { group in
            (title: group.title,
             count: byDate ? NotesBrowserQuery.countLabel(group.entries.count, filter: model.filter) : nil)
        }
    }

    // MARK: - Menus

    /// How far back, what kind, which order: side by side, or one above another when the text is
    /// too large for them to fit.
    private var menus: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) { menuItems }
            VStack(alignment: .leading, spacing: AppSpacing.xs) { menuItems }
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        Menu {
            Picker("How far back", selection: $notesBrowser.timeFilter) {
                ForEach(NotesBrowserTimeFilter.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            PhoneMenuLabel("How far back", choice: notesBrowser.timeFilter.title,
                      isChanged: notesBrowser.timeFilter != .anyTime)
        }
        Menu {
            Picker("What kind", selection: $notesBrowser.filter) {
                ForEach(PhoneNotesKinds.offered(hasKeptVersions: notesBrowser.hasKeptVersions, current: notesBrowser.filter),
                        id: \.self) { option in
                    Text(PhoneNotesKinds.title(for: option)).tag(option)
                }
            }
        } label: {
            PhoneMenuLabel("What kind", choice: PhoneNotesKinds.title(for: notesBrowser.filter),
                      isChanged: notesBrowser.filter != .all)
        }
        Menu {
            Picker("Order", selection: $notesBrowser.sort) {
                ForEach(NotesBrowserSort.allCases, id: \.self) { option in
                    Text(Self.title(for: option)).tag(option)
                }
            }
        } label: {
            PhoneMenuLabel("Order", choice: Self.title(for: notesBrowser.sort),
                      isChanged: notesBrowser.sort != .date)
        }
    }

    // The phone's words for the orders (the design's, not the Mac picker's); the kinds' are `PhoneNotesKinds`'s.
    private static func title(for sort: NotesBrowserSort) -> String {
        switch sort {
        case .date: "Newest first"
        case .reference: "Bible order"
        }
    }

    // MARK: - Rows

    /// A bookmark, a conversation and a chapter note name themselves; a colorless anchor shows the
    /// underline; a colored mark needs no symbol, its words carry the color.
    private static func symbolName(for entry: NotesBrowserEntry) -> String? {
        switch entry.kind {
        case .bookmark: "bookmark.fill"
        case .thread: "sparkles"
        case .keptVersion: VersionText.symbolName
        case .note, .highlight:
            entry.isChapterNote ? "note.text" : (entry.color == nil ? "underline" : nil)
        }
    }

    /// What VoiceOver reads first, as the Mac's notes browser row names its kind.
    private static func kindName(for entry: NotesBrowserEntry) -> String {
        switch entry.kind {
        case .bookmark: "Bookmark"
        case .highlight: "Highlight"
        case .note: entry.isChapterNote ? "Chapter note" : "Note"
        case .thread: "Conversation"
        case .keptVersion: VersionText.orphanMark
        }
    }

    private static func isKeptVersion(_ entry: NotesBrowserEntry) -> Bool {
        if case .keptVersion = entry.kind { return true }
        return false
    }

    private static func isThread(_ entry: NotesBrowserEntry) -> Bool {
        if case .thread = entry.kind { return true }
        return false
    }

    /// A note's first block; a conversation's title.
    static func noteBody(for entry: NotesBrowserEntry) -> AttributedString? {
        switch entry.kind {
        case .note, .keptVersion: entry.body.isEmpty ? nil : NoteMarkdown.blocks(entry.body, headingsAtTextSize: true).first
        case .thread: entry.body.isEmpty ? nil : AttributedString(entry.body)
        case .highlight, .bookmark: nil
        }
    }

    /// A mark opens its chapter at its verse as a lookup, with the way back to the place being
    /// read; a conversation opens in Ask.
    private func open(_ entry: NotesBrowserEntry) {
        if case .thread(let threadID) = entry.kind {
            assistant.open(threadID: threadID)
            shell.tab = .ask
            return
        }
        // A text whose note is gone has no verse to open: its page of versions is what it is for.
        if case .keptVersion(let keptID) = entry.kind {
            // Without the versions model there is nothing to show: nothing is presented.
            guard versions != nil else { return }
            keptVersion = KeptVersionSheet(id: keptID, reference: entry.referenceString)
            return
        }
        guard let target = notesBrowser.target(for: entry.id) else { return }
        MarkupNavigation.show(target, navigation: navigation, markup: markup)
        shell.showInReader()
    }

    // MARK: - Empty states

    @ViewBuilder
    private var emptyState: some View {
        Group {
            if notesBrowser.totalCount == 0 {
                ContentUnavailableView(
                    "No notes yet",
                    systemImage: "note.text",
                    description: Text("Highlights, notes, bookmarks and conversations you make in the reader appear here."))
            } else {
                ContentUnavailableView("Nothing in this range.", systemImage: "note.text")
            }
        }
        .foregroundStyle(Color.inkSecondary)
    }

    // MARK: - Export

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Export Notes", systemImage: "square.and.arrow.up") { export() }
                    .disabled(notesBrowser.entries.isEmpty)
            } label: {
                Label("More", systemImage: "ellipsis")
            }
        }
    }

    /// The Mac exporter's Markdown for the entries listed, one file with conversations, offered
    /// through the system share sheet.
    private func export() {
        do {
            let output = try exporter.output(
                entries: notesBrowser.entries, options: MarkdownExport.Options(),
                currentTranslationID: navigation.translationID)
            guard let file = output.files.first else { return }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(file.relativePath)
            try file.text.write(to: url, atomically: true, encoding: .utf8)
            PhoneShareSheet.present(url)
        } catch {
            Self.logger.error("Export failed: \(error)")
            exportFailed = true
        }
    }
}

/// The list's groups, each a `Section` under its heading: the days with their counts when sorted
/// by date (the Notes window's `NotesGroupHeading`), the books as ever when sorted by passage.
/// Split from the screen so a render can host the groups and rows without the screen's models.
struct PhoneNotesGroups<Row: View>: View {
    let model: NotesBrowserModel
    @ViewBuilder let row: (NotesBrowserEntry) -> Row

    var body: some View {
        let headings = PhoneNotesScreen.notesHeadings(for: model)
        ForEach(Array(model.groups.enumerated()), id: \.element.id) { index, group in
            Section {
                ForEach(group.entries) { row($0) }
            } header: {
                if let count = headings[index].count {
                    NotesGroupHeading(title: group.title, count: count,
                                      spoken: NotesBrowserQuery.headingSpoken(group, filter: model.filter))
                } else {
                    // The browser's group headers: Headline in primary ink.
                    Text(group.title)
                        .font(.headline)
                        .foregroundStyle(Color.inkPrimary)
                }
            }
        }
    }
}

/// An invisible view that takes first responder when it reaches a window and answers with the
/// given undo manager, so shake to undo, the three-finger swipe and ⌘Z reach a screen without text.
/// The Notes and Ask tabs use it.
struct UndoResponder: UIViewRepresentable {
    let undoManager: UndoManager?

    func makeUIView(context: Context) -> ResponderView {
        let view = ResponderView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: ResponderView, context: Context) {
        view.sceneUndoManager = undoManager
    }

    final class ResponderView: UIView {
        var sceneUndoManager: UndoManager?

        override var canBecomeFirstResponder: Bool { true }

        override var undoManager: UndoManager? { sceneUndoManager ?? super.undoManager }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { becomeFirstResponder() }
        }
    }
}
#endif
