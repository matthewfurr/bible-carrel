import OSLog
import ScriptureLLM
import ScriptureModel
import SwiftUI

/// Settings › Prompts: the chapter prompts (the heading's Ask About This Chapter) and the
/// selection prompts (Ask About This Passage), each grouped under its sections' titles as the
/// panel lists them, in rows like Settings › Markup's: a drag handle, an enabled toggle, the
/// title in a field, and a disclosure for the summary and the body. A row moves within its
/// section by dragging or by Move Up and Move Down in its context menu. A built-in that was
/// edited offers Restore; one the reader added offers Delete.
public struct PromptTemplatesSettingsView: View {
    let store: PromptTemplateStore
    /// Changes when something outside the view (an import) changed the prompts; the rows reload.
    let revision: Int
    let onChange: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rows: [PromptRow] = []
    @State private var expandedID: UUID?
    @State private var pendingDelete: PromptRow?
    @State private var liveOrder: [UUID] = []
    @State private var draggingID: UUID?
    @State private var lastError: String?
    private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "assistant")

    public init(store: PromptTemplateStore, revision: Int = 0, onChange: @escaping () -> Void) {
        self.store = store
        self.revision = revision
        self.onChange = onChange
    }

    public var body: some View {
        Form {
            section(.chapter, title: "Chapter prompts", footer: "Listed when you choose Ask About This Chapter from the chapter heading's menu.")
            section(.selection, title: "Selection prompts", footer: "Listed when you choose Ask About This Passage on selected text.")
            Section {
                Text("Placeholders filled when a prompt runs: \(PromptBuilder.placeholders.map { "{{\($0)}}" }.joined(separator: ", ")). Anything else is sent as typed.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: reload)
        .onChange(of: revision) { reload() }
        .alert(
            "Could not save",
            isPresented: Binding(get: { lastError != nil }, set: { if !$0 { lastError = nil } }),
            presenting: lastError
        ) { _ in
            Button("OK") { lastError = nil }
        } message: { message in
            Text(message)
        }
        .confirmationDialog(
            "Delete \u{201C}\(pendingDelete?.title ?? "this prompt")\u{201D}?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .deleteDialogTitle,
            presenting: pendingDelete
        ) { row in
            Button("Delete", role: .destructive) {
                mutate(row.id) { try store.delete($0) }
            }
        } message: { _ in
            Text("The prompt will be removed from the list.")
        }
    }

    private func ordered(_ scope: PromptScope) -> [PromptRow] {
        let scoped = rows.filter { $0.scope == scope }
        let byID = Dictionary(uniqueKeysWithValues: scoped.map { ($0.id, $0) })
        let known = liveOrder.compactMap { byID[$0] }
        return known.count == scoped.count ? known : scoped
    }

    /// The scope's rows by section, in `PromptSection` order, empty sections left out.
    private func groups(_ scope: PromptScope) -> [(section: PromptSection, rows: [PromptRow])] {
        let scoped = ordered(scope)
        return PromptSection.allCases.compactMap { section in
            let rows = scoped.filter { $0.section == section }
            return rows.isEmpty ? nil : (section, rows)
        }
    }

    private func section(_ scope: PromptScope, title: String, footer: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(groups(scope), id: \.section) { group in
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(group.section.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.inkSecondary)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                            rowView(row, scope: scope, isFirst: index == 0, isLast: index == group.rows.count - 1)
                        }
                    }
                }
            }
            HStack {
                Button { add(scope) } label: { Label("Add Prompt", systemImage: "plus") }
                    .help("Add Prompt")
                Spacer()
            }
            .buttonStyle(.borderless)
        } header: {
            Text(title)
        } footer: {
            Text(footer)
                .foregroundStyle(Color.inkSecondary)
        }
    }

    private func rowView(_ row: PromptRow, scope: PromptScope, isFirst: Bool, isLast: Bool) -> some View {
        PromptRowView(
            row: row,
            isExpanded: expandedID == row.id,
            onToggleExpanded: { expandedID = expandedID == row.id ? nil : row.id },
            onEnabled: { enabled in mutate(row.id) { try store.setEnabled($0, enabled) } },
            onEdit: { title, summary, body in mutate(row.id) { try store.update($0, title: title, summary: summary, body: body) } },
            onRestore: { restore(row) },
            onDelete: { pendingDelete = row },
            onDragStart: { draggingID = row.id })
        .contextMenu {
            Button("Move Up") { mutate(row.id) { try store.move($0, by: -1) } }
                .disabled(isFirst)
            Button("Move Down") { mutate(row.id) { try store.move($0, by: 1) } }
                .disabled(isLast)
        }
        .onDrop(of: [.plainText], delegate: PromptRowDropDelegate(
            rowID: row.id,
            section: row.section,
            sections: Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.section) }),
            draggingID: $draggingID,
            liveOrder: $liveOrder,
            reduceMotion: reduceMotion,
            persist: { persistOrder($0, scope: scope) }))
    }

    // MARK: - Store

    private func reload() {
        do {
            rows = try store.templates().map(PromptRow.init)
        } catch {
            fail(error)
        }
        if draggingID == nil { liveOrder = rows.map(\.id) }
    }

    private func mutate(_ id: UUID, _ work: (PromptTemplate) throws -> Void) {
        do {
            if let template = try store.template(id: id) { try work(template) }
        } catch {
            fail(error)
        }
        reload()
        onChange()
    }

    private func add(_ scope: PromptScope) {
        let body = scope == .chapter
            ? "Here is {{reference}} ({{translation}}):\n\n{{chapter_text}}\n\n"
            : "I am reading {{reference}} ({{translation}}). The passage:\n\n{{selection}}\n\n"
        do {
            let template = try store.add(title: "New prompt", body: body, scope: scope)
            expandedID = template.uuid
        } catch {
            fail(error)
        }
        reload()
        onChange()
    }

    private func restore(_ row: PromptRow) {
        guard let key = row.builtInKey else { return }
        do {
            try store.restoreBuiltIn(key: key, from: BuiltInPrompts.all)
        } catch {
            fail(error)
        }
        reload()
        onChange()
    }

    /// The dragged row's move within its scope, as the store's `move` takes it.
    private func persistOrder(_ order: [UUID], scope: PromptScope) {
        let before = rows.filter { $0.scope == scope }.map(\.id)
        let after = order.filter(before.contains)
        guard let dragged = draggingID ?? before.first(where: { before.firstIndex(of: $0) != after.firstIndex(of: $0) }),
              let from = before.firstIndex(of: dragged), let to = after.firstIndex(of: dragged), from != to
        else { draggingID = nil; return }
        draggingID = nil
        do {
            try store.move(scope: scope, fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        } catch {
            fail(error)
        }
        reload()
        onChange()
    }

    private func fail(_ error: any Error) {
        lastError = "Your last change to the prompts could not be saved. Try it again."
        logger.error("Prompt template change failed: \(error)")
    }
}

/// A template by value, with whether a built-in has been edited away from its seed.
private struct PromptRow: Identifiable, Equatable {
    let id: UUID
    let title: String
    let summary: String
    let body: String
    let scope: PromptScope
    let section: PromptSection
    let isEnabled: Bool
    let isBuiltIn: Bool
    let builtInKey: String?
    let isEdited: Bool

    init(_ template: PromptTemplate) {
        id = template.uuid
        title = template.title
        summary = template.summary
        body = template.body
        scope = template.scope
        section = template.section
        isEnabled = template.isEnabled
        isBuiltIn = template.isBuiltIn
        builtInKey = template.builtInKey
        let seed = template.builtInKey.flatMap(BuiltInPrompts.seed(key:))
        isEdited = seed.map { $0.title != template.title || $0.summary != template.summary || $0.body != template.body } ?? false
    }
}

/// Reorders live as a row is dragged over another in the same section; a row never crosses
/// into another section, since the panel groups by section whatever the order.
private struct PromptRowDropDelegate: DropDelegate {
    let rowID: UUID
    let section: PromptSection
    let sections: [UUID: PromptSection]
    @Binding var draggingID: UUID?
    @Binding var liveOrder: [UUID]
    let reduceMotion: Bool
    let persist: ([UUID]) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingID, dragging != rowID, sections[dragging] == section,
              let index = liveOrder.firstIndex(of: rowID) else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            liveOrder = ColorReorder.move(liveOrder, dragged: dragging, toIndex: index)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        persist(liveOrder)
        return true
    }
}

/// Handle (the only drag source), enabled toggle, title field, then Restore or Delete and the
/// disclosure; expanded, the summary in a field and the body in the note editor's style below.
private struct PromptRowView: View {
    let row: PromptRow
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onEnabled: (Bool) -> Void
    /// Title, summary, body.
    let onEdit: (String, String, String) -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void
    let onDragStart: () -> Void

    @State private var title: String
    @State private var summary: String
    @State private var bodyText: String
    @ScaledMetric(relativeTo: .body) private var handleWidth: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var editorHeight: CGFloat = 160

    init(row: PromptRow, isExpanded: Bool, onToggleExpanded: @escaping () -> Void, onEnabled: @escaping (Bool) -> Void,
         onEdit: @escaping (String, String, String) -> Void, onRestore: @escaping () -> Void, onDelete: @escaping () -> Void, onDragStart: @escaping () -> Void) {
        self.row = row
        self.isExpanded = isExpanded
        self.onToggleExpanded = onToggleExpanded
        self.onEnabled = onEnabled
        self.onEdit = onEdit
        self.onRestore = onRestore
        self.onDelete = onDelete
        self.onDragStart = onDragStart
        _title = State(initialValue: row.title)
        _summary = State(initialValue: row.summary)
        _bodyText = State(initialValue: row.body)
    }

    /// The title as typed, or the stored one while the field is blank.
    private var titleToKeep: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? row.title : title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: handleWidth)
                    .contentShape(Rectangle())
                    .help("Drag to reorder")
                    .accessibilityLabel("Reorder")
                    .onDrag {
                        onDragStart()
                        return NSItemProvider(object: row.id.uuidString as NSString)
                    }
                Toggle("Show \(row.title)", isOn: Binding(get: { row.isEnabled }, set: { onEnabled($0) }))
                    .labelsHidden()
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #endif
                    .help(row.isEnabled ? "Shown in the list" : "Hidden from the list")
                TextField("", text: $title, prompt: Text("Title"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: title) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty, trimmed != row.title { onEdit(trimmed, summary, bodyText) }
                    }
                if row.isEdited {
                    Button("Restore", action: onRestore)
                        .buttonStyle(.borderless)
                        .help("Put back the built-in title, summary and text")
                }
                if !row.isBuiltIn {
                    RowSymbolButton(title: "Delete Prompt", symbol: "trash", role: .destructive, action: onDelete)
                }
                RowSymbolButton(title: isExpanded ? "Hide Prompt Text" : "Edit Prompt Text", symbol: isExpanded ? "chevron.up" : "chevron.down", action: onToggleExpanded)
            }
            if isExpanded {
                TextField("Summary", text: $summary, prompt: Text("One or two sentences shown under the title"), axis: .vertical)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .onChange(of: summary) { _, newValue in
                        if newValue != row.summary { onEdit(titleToKeep, newValue, bodyText) }
                    }
                TextEditor(text: $bodyText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.xs)
                    .frame(minHeight: editorHeight)
                    .editorSurface()
                    .accessibilityLabel("Prompt text")
                    .onChange(of: bodyText) { _, newValue in
                        if newValue != row.body { onEdit(titleToKeep, summary, newValue) }
                    }
            }
        }
        .padding(.vertical, AppSpacing.xxs)
        // Restore and reload replace the row's text from outside the fields.
        .onChange(of: row) { _, newRow in
            if newRow.title != title { title = newRow.title }
            if newRow.summary != summary { summary = newRow.summary }
            if newRow.body != bodyText { bodyText = newRow.body }
        }
    }
}
