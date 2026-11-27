import ScriptureModel
import SwiftUI

/// Settings → Markup: the highlight colors (add, rename, recolor, reorder, delete). The notes
/// column's own settings live under General, beside the toggle that shows the column.
///
/// The color rows are a plain stack, not a `List`: a `List` with `onMove` puts a row-wide drag
/// gesture between the pointer and the name field, which then needs a second click. Here the
/// drag starts on the handle glyph only, rows shift live as the drag passes over them, and the
/// drop persists the order. Nothing on a row intercepts a click on its field.
public struct HighlightColorsSettingsView: View {
    @Bindable var model: ColorSettingsModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pendingDelete: ColorRow?
    /// The order shown while a drag is in flight; follows `model.rows` otherwise.
    @State private var liveOrder: [UUID] = []
    @State private var draggingID: UUID?

    public init(model: ColorSettingsModel) {
        self.model = model
    }

    private var orderedRows: [ColorRow] {
        let byID = Dictionary(uniqueKeysWithValues: model.rows.map { ($0.id, $0) })
        let known = liveOrder.compactMap { byID[$0] }
        return known.count == model.rows.count ? known : model.rows
    }

    public var body: some View {
        Form {
            Section {
                // A plain stack inside the form, not a second scroll view: the form scrolls.
                if orderedRows.isEmpty {
                    Text("No highlight colors. Add one to start marking text.")
                        .foregroundStyle(Color.inkSecondary)
                } else {
                    VStack(spacing: AppSpacing.xxs) {
                        ForEach(orderedRows) { row in
                            ColorRowView(
                                row: row,
                                model: model,
                                onDelete: { pendingDelete = row },
                                onDragStart: { draggingID = row.id })
                            .onDrop(of: [.plainText], delegate: ColorRowDropDelegate(
                                rowID: row.id,
                                draggingID: $draggingID,
                                liveOrder: $liveOrder,
                                reduceMotion: reduceMotion,
                                persist: { model.reorder(to: $0) }))
                        }
                    }
                    #if os(iOS)
                    // The rows' separator from the row's edge, not from the first text the form finds (a count).
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    #endif
                }
                HStack {
                    Button { model.add() } label: { Label("Add Color", systemImage: "plus") }
                        .help("Add Color")
                    Spacer()
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Highlight Colors")
            } footer: {
                Text("Edit a name in its field; drag the handle to reorder. The order sets the swatch row in the selection menu.")
            }
        }
        .formStyle(.grouped)
        .alert(
            "Could not save",
            isPresented: Binding(get: { model.lastError != nil }, set: { if !$0 { model.clearError() } }),
            presenting: model.lastError
        ) { _ in
            Button("OK") { model.clearError() }
        } message: { message in
            Text(message)
        }
        // The reader adds colors and highlights too; show the current rows each time the pane opens.
        .onAppear {
            model.reload()
            liveOrder = model.rows.map(\.id)
        }
        .onChange(of: model.rows.map(\.id)) { _, ids in
            if draggingID == nil { liveOrder = ids }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.name ?? "this color")?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .deleteDialogTitle,
            presenting: pendingDelete
        ) { row in
            Button("Delete", role: .destructive) {
                model.delete(id: row.id)
            }
        } message: { row in
            if row.highlightCount > 0 {
                Text("\(row.highlightCount) highlights use this color. They keep their notes but lose the color.")
            } else {
                Text("No highlights use this color.")
            }
        }
    }
}

extension Visibility {
    /// A settings delete dialog's title ("Delete New Color?"): the Mac's default, and shown on the
    /// phone, where a dialog hides its title unless asked, so the dialog names what goes. Settings ›
    /// Prompts uses it too.
    #if os(macOS)
    static let deleteDialogTitle = Visibility.automatic
    #else
    static let deleteDialogTitle = Visibility.visible
    #endif
}

/// Shifts rows live as the dragged handle passes over them and persists the order on drop.
private struct ColorRowDropDelegate: DropDelegate {
    let rowID: UUID
    @Binding var draggingID: UUID?
    @Binding var liveOrder: [UUID]
    let reduceMotion: Bool
    let persist: ([UUID]) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingID, dragging != rowID, let index = liveOrder.firstIndex(of: rowID) else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            liveOrder = ColorReorder.move(liveOrder, dragged: dragging, toIndex: index)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        let order = liveOrder
        draggingID = nil
        persist(order)
        return true
    }
}

/// Handle glyph (the only drag source), swatch, an editable name field, usage count, the two
/// color wells and a delete button. Edits persist as they happen.
private struct ColorRowView: View {
    let row: ColorRow
    let model: ColorSettingsModel
    let onDelete: () -> Void
    let onDragStart: () -> Void

    @Environment(\.self) private var environment
    @State private var name: String
    @State private var light: Color
    @State private var dark: Color
    @ScaledMetric(relativeTo: .body) private var swatchSize: CGFloat = 16

    init(row: ColorRow, model: ColorSettingsModel, onDelete: @escaping () -> Void, onDragStart: @escaping () -> Void) {
        self.row = row
        self.model = model
        self.onDelete = onDelete
        self.onDragStart = onDragStart
        _name = State(initialValue: row.name)
        _light = State(initialValue: Self.color(hex: row.lightHex))
        _dark = State(initialValue: Self.color(hex: row.darkHex))
    }

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(Color.inkSecondary)
                .frame(width: swatchSize)
                .contentShape(Rectangle())
                .help("Drag to reorder")
                .accessibilityLabel("Reorder")
                // The glyph is the only drag source; the closure runs as the drag starts, which
                // records the dragged row for the live shifting.
                .onDrag {
                    onDragStart()
                    return NSItemProvider(object: row.id.uuidString as NSString)
                }
            Circle()
                .fill(Color(markup: MarkupColor(lightHex: row.lightHex, darkHex: row.darkHex)))
                .overlay(Circle().strokeBorder(Color.inkRule, lineWidth: 0.5))
                .frame(width: swatchSize, height: swatchSize)
                .accessibilityHidden(true)
            // "Name" is the placeholder only; a Form would otherwise draw the title as a label.
            TextField("", text: $name, prompt: Text("Name"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
                .onChange(of: name) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty, trimmed != row.name { model.rename(id: row.id, to: trimmed) }
                }
            Spacer()
            if row.highlightCount > 0 {
                Text(row.highlightCount, format: .number)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.inkSecondary)
                    .help("Highlights using this color")
                    .accessibilityLabel("\(row.highlightCount) highlights")
            }
            ColorPicker("Light", selection: $light, supportsOpacity: false)
                .labelsHidden()
                .help("Light appearance")
                .onChange(of: light) { _, _ in save() }
            ColorPicker("Dark", selection: $dark, supportsOpacity: false)
                .labelsHidden()
                .help("Dark appearance")
                .onChange(of: dark) { _, _ in save() }
            RowSymbolButton(title: "Delete Color", symbol: "trash", role: .destructive, action: onDelete)
        }
        .padding(.vertical, AppSpacing.xxs)
        // Undo, reload, or the store's lightness band replace the hex from outside the wells.
        .onChange(of: row) { _, newRow in show(newRow) }
    }

    /// Passes the raw picks; the store holds them to the marks' lightness band, and the wells then
    /// show what was kept. Read back here as well as in `onChange(of: row)`, because a pick that
    /// conforms to the value already stored leaves the row unchanged.
    private func save() {
        let lightHex = hex(light), darkHex = hex(dark)
        guard lightHex != row.lightHex || darkHex != row.darkHex else { return }
        model.setHex(id: row.id, lightHex: lightHex, darkHex: darkHex)
        if let stored = model.rows.first(where: { $0.id == row.id }) { show(stored) }
    }

    private func show(_ stored: ColorRow) {
        if hex(light) != stored.lightHex { light = Self.color(hex: stored.lightHex) }
        if hex(dark) != stored.darkHex { dark = Self.color(hex: stored.darkHex) }
    }

    private func hex(_ color: Color) -> String {
        let resolved = color.resolve(in: environment)
        return ColorHex.string(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue))
    }

    private static func color(hex: String) -> Color {
        guard let c = ColorHex.components(hex) else { return .gray }
        return Color(.sRGB, red: c.red, green: c.green, blue: c.blue)
    }
}
