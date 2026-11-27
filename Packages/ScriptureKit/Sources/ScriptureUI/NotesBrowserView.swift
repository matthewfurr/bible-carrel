import SwiftUI

/// The Notes window: every note, highlight, bookmark and conversation across the Bible. Toolbar:
/// sort (Date or Reference), filter (All, Notes, Highlights, Bookmarks, Threads, and Kept versions
/// while there are any; segmented while the window has room, else a menu), Export (what
/// the list shows, as Markdown) and a search field (⌘F). Return or a
/// double-click shows the selected item in the reader; Delete (or the context menu) removes it
/// after confirmation. Edits happen in the reader, not here.
public struct NotesBrowserView: View {
    @Bindable var model: NotesBrowserModel
    let onShow: (MarkupTarget) -> Void
    let onExport: ([NotesBrowserEntry]) -> Void

    @State private var pendingDelete: NotesBrowserEntry?
    @State private var isSearchPresented = false
    /// The row whose versions popover shows.
    @State private var versionsShownID: UUID?
    /// The content's width, which is the window's: it picks the filter's style.
    @State private var windowWidth: CGFloat?
    @FocusState private var listFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(macOS)
    @Environment(\.controlActiveState) private var controlActiveState
    #endif
    @Environment(\.undoManager) private var undoManager

    public init(model: NotesBrowserModel, onShow: @escaping (MarkupTarget) -> Void, onExport: @escaping ([NotesBrowserEntry]) -> Void = { _ in }) {
        self.model = model
        self.onShow = onShow
        self.onExport = onExport
    }

    public var body: some View {
        Group {
            if model.entries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(minWidth: 520, minHeight: 320)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
        .background(Color.paperPage)
        // The window is titled "Notes"; the count rides beside it instead of in a second header.
        .navigationSubtitle(model.entries.isEmpty ? "" : countText)
        .tint(Color.accent)
        .onChange(of: undoManager, initial: true) { _, manager in model.undoManager = manager }
        .alert(
            "Could not delete",
            isPresented: Binding(get: { model.lastError != nil }, set: { if !$0 { model.clearError() } }),
            presenting: model.lastError
        ) { _ in
            Button("OK") { model.clearError() }
        } message: { message in
            Text(message)
        }
        .background {
            // ⌘F focuses the toolbar search field.
            Button("Find") { isSearchPresented = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .searchable(text: $model.query, isPresented: $isSearchPresented, placement: .toolbar, prompt: "Search notes")
        .toolbar { toolbarContent }
        // Debounced: the store search runs on the main thread, so wait for typing to pause.
        .task(id: model.query) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            model.applySearch()
        }
        .onAppear { model.reload() }
        // The row whose popover was showing lost its mark (or left the list) before the popover
        // closed itself: forget it, so it cannot reopen when a mark comes back.
        .onChange(of: model.entries) { _, entries in
            if let id = versionsShownID, !entries.contains(where: { $0.id == id && hasVersions($0) }) { versionsShownID = nil }
        }
        #if os(macOS)
        // Markup made in the reader meanwhile shows when this window comes back to the front.
        .onChange(of: controlActiveState) { _, state in
            if state == .key { model.reload() }
        }
        #endif
        .confirmationDialog(
            pendingDelete.map(Self.deleteTitle(for:)) ?? "Delete this item?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { entry in
            if isKeptVersion(entry) {
                // Discard is never red: the text comes back with Undo, and nothing is lost.
                Button("Discard") { model.delete(id: entry.id) }
            } else {
                Button("Delete", role: .destructive) { model.delete(id: entry.id) }
            }
        } message: { entry in
            Text(deleteMessage(for: entry))
        }
    }

    private var countText: String {
        model.entries.count == 1 ? "1 item" : "\(model.entries.count) items"
    }

    @ViewBuilder
    private var emptyState: some View {
        let query = model.query.trimmingCharacters(in: .whitespaces)
        Group {
            if model.totalCount == 0 {
                ContentUnavailableView(
                    "No notes yet",
                    systemImage: "note.text",
                    description: Text("Highlights, notes, bookmarks and conversations you make in the reader appear here."))
            } else if model.timeFilter != .anyTime {
                ContentUnavailableView("Nothing in this range.", systemImage: "note.text")
            } else if query.isEmpty {
                ContentUnavailableView(
                    "Nothing of this kind yet",
                    systemImage: "note.text",
                    description: Text("Choose All to see everything you have marked."))
            } else {
                ContentUnavailableView.search(text: query)
            }
        }
        .foregroundStyle(Color.inkSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The groups (days by date, books by passage), each under its heading, a rule the stack's
    /// width between two groups (`xxs` under the group's last row, so a wash never sits on it) and a
    /// hairline inset `sm` between two notes of one, hidden beside the selection.
    /// No space of their own between rows: each row's `sm` padding is the rhythm.
    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.groups.enumerated()), id: \.element.id) { index, group in
                        if index > 0 {
                            HairlineRule()
                                .padding(.top, NotesBrowserList.spaceAboveGroupRule)
                        }
                        NotesGroupHeading(
                            title: group.title,
                            count: NotesBrowserQuery.countLabel(group.entries.count, filter: model.filter),
                            spoken: NotesBrowserQuery.headingSpoken(group, filter: model.filter))
                            .padding(.horizontal, AppSpacing.sm)
                            // The first sits `xs` under the stack's own `xs`: `md` from the top, as every other.
                            .padding(.top, index == 0 ? AppSpacing.xs : AppSpacing.md)
                            .padding(.bottom, AppSpacing.xxs)
                        ForEach(Array(group.entries.enumerated()), id: \.element.id) { position, entry in
                            if position > 0 {
                                // It fades with the wash beside it and keeps its point, so nothing below moves.
                                HairlineRule()
                                    .padding(.horizontal, AppSpacing.sm)
                                    .opacity(NotesBrowserList.showsRule(above: group.entries[position - 1].id, below: entry.id, selected: model.selectedID) ? 1 : 0)
                                    .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: model.selectedID)
                            }
                            row(entry)
                        }
                    }
                }
                .padding(AppSpacing.xs)
            }
            // The list is one focus stop and the selection is the only state: the keys act on
            // `model.selectedID`, so they work whichever row is on screen, after a filter, and on open.
            .focusable()
            .focused($listFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) { move(by: -1) }
            .onKeyPress(.downArrow) { move(by: 1) }
            .onKeyPress(.return) {
                guard let id = model.selectedID else { return .ignored }
                show(id)
                return .handled
            }
            #if os(macOS)
            .onDeleteCommand {
                if let id = model.selectedID { confirmDelete(id) }
            }
            #endif
            .onChange(of: model.selectedID) { _, id in
                guard let id else { return }
                if reduceMotion {
                    proxy.scrollTo(id)
                } else {
                    withAnimation(.smooth) { proxy.scrollTo(id) }
                }
            }
            // The list comes back whenever a search finds rows again: it takes the keyboard only
            // when nothing is being searched, never from the search field being typed in.
            .onAppear {
                if !isSearchPresented && model.query.isEmpty { listFocused = true }
            }
        }
    }

    /// One row: a click selects, a double-click or Return shows it, ↑ ↓ move, Delete asks. The
    /// system's List selection is not used; the selection is the row's own accent wash.
    private func row(_ entry: NotesBrowserEntry) -> some View {
        NotesBrowserRow(
            entry: entry,
            parts: NotesBrowserRowParts.make(entry, underDay: model.sort == .date, calendar: model.calendar, locale: model.locale),
            isSelected: model.selectedID == entry.id,
            versionsShown: Binding(get: { versionsShownID == entry.id }, set: { shown in
                // A closing popover clears only its own row, never one just opened elsewhere.
                if shown { versionsShownID = entry.id } else if versionsShownID == entry.id { versionsShownID = nil }
            }),
            undoManager: model.undoManager)
            .contentShape(Rectangle())
            // A click selects at once; the double click rides beside it, so the wash never waits.
            .onTapGesture {
                model.selectedID = entry.id
                listFocused = true
            }
            .simultaneousGesture(TapGesture(count: 2).onEnded { show(entry.id) })
            #if os(macOS)
            .overlay { SecondaryClickHook { model.selectedID = entry.id } }
            #endif
            .contextMenu {
                // The row took the wash when the secondary click began (SecondaryClickHook).
                Button("Show in Reader") { show(entry.id) }
                if hasVersions(entry) {
                    Button("Show Versions") { versionsShownID = entry.id }
                }
                Divider()
                if isKeptVersion(entry) {
                    Button("Discard…") { confirmDelete(entry.id) }
                } else {
                    Button("Delete…", role: .destructive) { confirmDelete(entry.id) }
                }
            }
            .accessibilityAddTraits(model.selectedID == entry.id ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(named: "Show in Reader") { show(entry.id) }
            .accessibilityAction(named: isKeptVersion(entry) ? "Discard" : "Delete") { confirmDelete(entry.id) }
            .id(entry.id)
    }

    private func isKeptVersion(_ entry: NotesBrowserEntry) -> Bool {
        if case .keptVersion = entry.kind { return true }
        return false
    }

    /// A note with kept versions, or a kept version whose note is gone: its mark shows the versions.
    private func hasVersions(_ entry: NotesBrowserEntry) -> Bool {
        if case .note = entry.kind { return entry.versionCount > 1 }
        return isKeptVersion(entry)
    }

    private func move(by step: Int) -> KeyPress.Result {
        guard model.moveSelection(by: step) != nil else { return .ignored }
        return .handled
    }

    private func confirmDelete(_ id: UUID) {
        model.selectedID = id
        pendingDelete = model.entry(id: id)
    }

    private var showsKeptVersionsFilter: Bool { model.hasKeptVersions || model.filter == .keptVersions }

    /// Whether the filter is segmented: while the window is wide enough for its segments beside
    /// the toolbar's other controls and search field, else a menu of the same choices, as "How
    /// far back" is (left alone, AppKit moves the segments into the toolbar's overflow). Set by an
    /// offscreen render of the window: the segments are equal, and with five everything fits from
    /// 1,000 pt (at 980 Sort and Export overflow), with six from 1,200 (at 1,160 they overflow).
    nonisolated static func filterIsSegmented(width: CGFloat, segments: Int) -> Bool {
        width >= (segments > 5 ? 1_200 : 1_000)
    }

    private var filterPicker: some View {
        Picker("Show", selection: $model.filter) {
            Text("All").tag(NotesBrowserFilter.all)
            Text("Notes").tag(NotesBrowserFilter.notes)
            Text("Highlights").tag(NotesBrowserFilter.highlights)
            Text("Bookmarks").tag(NotesBrowserFilter.bookmarks)
            Text("Threads").tag(NotesBrowserFilter.threads)
            if showsKeptVersionsFilter {
                Text("Kept versions").tag(NotesBrowserFilter.keptVersions)
            }
        }
        .labelsHidden()
        .help("Show everything, or only notes, highlights, bookmarks, conversations or kept versions")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Until the window is measured, segmented: a new window opens at 1,100 pt.
            if windowWidth.map({ Self.filterIsSegmented(width: $0, segments: showsKeptVersionsFilter ? 6 : 5) }) ?? true {
                filterPicker.pickerStyle(.segmented)
            } else {
                filterPicker.pickerStyle(.menu)
            }
            Picker("How far back", selection: $model.timeFilter) {
                ForEach(NotesBrowserTimeFilter.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
            .help("Show everything, or only what changed in the past week, month, three months or year")
            Menu {
                Picker("Sort by", selection: $model.sort) {
                    Text("Date").tag(NotesBrowserSort.date)
                    Text("Reference").tag(NotesBrowserSort.reference)
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .help("Sort by date or reference")
            Button { onExport(model.entries) } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export these notes as Markdown…")
            .disabled(model.entries.isEmpty)
        }
    }

    private func show(_ id: UUID) {
        model.selectedID = id
        if let target = model.target(for: id) { onShow(target) }
    }

    /// The delete dialog's title: "Delete John 15:5?", or for a kept version whose note is gone,
    /// "Discard the kept version of John 15:9?".
    nonisolated static func deleteTitle(for entry: NotesBrowserEntry) -> String {
        if case .keptVersion = entry.kind { return "Discard the kept version of \(entry.referenceString)?" }
        return "Delete \(entry.referenceString)?"
    }

    /// What will go, in the future tense, and that it can come back.
    private func deleteMessage(for entry: NotesBrowserEntry) -> String {
        let consequence: String
        switch entry.kind {
        case .note(_, let highlightID):
            if highlightID == nil {
                consequence = "The note will be deleted."
            } else {
                consequence = entry.color == nil ? "The note and its underline will be deleted." : "The note will be deleted. The highlight keeps its color."
            }
        case .highlight: consequence = "The highlight will be deleted."
        case .bookmark: consequence = "The bookmark will be deleted."
        case .thread: consequence = "The conversation will be deleted."
        case .keptVersion: consequence = "The kept version will be discarded."
        }
        return consequence + " Edit › Undo brings it back."
    }
}

/// The Notes window list's rules, as pure decisions.
enum NotesBrowserList {
    /// The space between a group's last row and the rule under it: the row's wash, when it is
    /// selected, stops short of the line (spec 5.3), and the next heading's `md` follows the rule.
    static let spaceAboveGroupRule: CGFloat = AppSpacing.xxs

    /// Whether the hairline between two neighbouring notes of a group shows: not when either is
    /// selected, so the wash stands alone (the rule between groups always shows).
    static func showsRule(above: UUID, below: UUID, selected: UUID?) -> Bool {
        selected != above && selected != below
    }
}
