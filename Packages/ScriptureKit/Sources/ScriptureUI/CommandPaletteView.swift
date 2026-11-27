import ScriptureData
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// The ⌘K panel: a search field, the chips and the scope menu once something is typed, the
/// results grouped under headers as the phone's search groups them, and a foot that says what
/// the keys do. The headers are not rows: selection, hover, the arrow keys and Return move over
/// `model.paletteItems`, the rows shown.
public struct CommandPaletteView: View {
    @Environment(\.pageFace) private var pageFace
    @Bindable var model: NavigationModel

    @State private var selection = 0
    /// The list's rows' own height, measured, so the list is as tall as they are up to its cap.
    @State private var listContentHeight: CGFloat?
    /// The timestamp of the Esc press last acted on (see `escape()`).
    @State private var lastEscapeEvent: TimeInterval?
    @FocusState private var isFieldFocused: Bool
    @ScaledMetric(relativeTo: .callout) private var iconWidth: CGFloat = 20
    @ScaledMetric(relativeTo: .callout) private var dotSize: CGFloat = 10

    public init(model: NavigationModel) {
        self.model = model
    }

    /// The row an arrow key lands on: `delta` rows on from `current` over the groups' rows as one
    /// list, held at the first and last.
    static func selection(after current: Int, moving delta: Int, in results: SearchResults) -> Int {
        let count = results.flatItems.count
        guard count > 0 else { return 0 }
        return min(max(current + delta, 0), count - 1)
    }

    /// The results as shown: the chosen chip's groups alone, or all of them.
    private var results: SearchResults { model.paletteResults.showing(model.paletteChip) }

    /// `results.flatItems`, as the model's Return takes them.
    private var items: [PaletteItem] { model.paletteItems }

    /// The query trimmed, for bolding the matched words.
    private var trimmedQuery: String {
        model.paletteQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The kinds present, for the chips; none with nothing typed.
    private var chips: [SearchChip] {
        trimmedQuery.isEmpty ? [] : model.paletteResults.chips()
    }

    private var showsChipRow: Bool {
        !trimmedQuery.isEmpty && (chips.count >= 2 || model.showsScopeMenu)
    }

    /// Whether Tab steps the chips now: when there are chips and VoiceOver is off.
    private var tabStepsChips: Bool {
        #if os(macOS)
        PaletteKeys.tabStepsChips(
            chipCount: showsChipRow ? chips.count : 0,
            fullKeyboardAccess: NSApplication.shared.isFullKeyboardAccessEnabled,
            voiceOver: tabIsTheSystems)
        #else
        false
        #endif
    }

    /// Whether ⌃Tab steps the scope now: while the chip row shows the scope menu and VoiceOver is off.
    private var controlTabStepsScope: Bool {
        PaletteKeys.controlTabStepsScope(showsScopeMenu: showsChipRow && model.showsScopeMenu, voiceOver: tabIsTheSystems)
    }

    /// Under VoiceOver Tab is the system's and the chips are ordinary buttons; otherwise the
    /// palette keeps Tab, so first responder never leaves the field. (The panel is the Mac's.)
    private var tabIsTheSystems: Bool {
        #if os(macOS)
        NSWorkspace.shared.isVoiceOverEnabled
        #else
        true
        #endif
    }

    /// The book open in the reader, for the scope menu's "This Book".
    private var currentBook: Book? {
        guard model.screen == .reader, let location = model.location else { return nil }
        return BookCatalog.book(code: location.book)
    }

    /// One line of the list: a group's header, or a row with its index in `results.flatItems`.
    /// Flat, so every header and row is a direct child of the stack with its own identity,
    /// which `scrollTo` needs to find it.
    private enum Line: Identifiable {
        case header(SearchGroup)
        case row(PaletteItem, index: Int)

        var id: String {
            switch self {
            case .header(let group): CommandPaletteView.headerID(group.kind)
            case .row(let item, _): item.id
            }
        }
    }

    /// The groups' headers and rows; "Did you mean" has no header.
    private var lines: [Line] {
        var lines: [Line] = []
        var index = 0
        for group in results.groups {
            if group.kind != .suggestion { lines.append(.header(group)) }
            for item in group.items {
                lines.append(.row(item, index: index))
                index += 1
            }
        }
        return lines
    }

    /// The header above the row at `index`, when that row is its group's first and it has one.
    private func header(openedBy index: Int) -> SearchGroup? {
        var start = 0
        for group in results.groups {
            if start == index { return group.kind == .suggestion ? nil : group }
            start += group.items.count
        }
        return nil
    }

    public var body: some View {
        let state = model.paletteState
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityHidden(true)
                TextField("Go to a passage, search, or run a command", text: $model.paletteQuery)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .foregroundStyle(Color.inkPrimary)
                    .focused($isFieldFocused)
                    .onSubmit { model.submitPalette(selectedIndex: selection) }
                    .accessibilityLabel("Go to")
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)

            if showsChipRow {
                PaletteChipRow(
                    chips: chips, results: model.paletteResults, chosen: model.paletteChip,
                    showsScopeMenu: model.showsScopeMenu, scope: $model.searchScope,
                    books: model.books, currentBook: currentBook,
                    choose: { chip in
                        model.paletteChip = chip
                        // A click leaves the keyboard with the field.
                        isFieldFocused = true
                    })
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xs)
            }

            if !results.groups.isEmpty {
                Color.inkRule.frame(height: 1)
                ScrollViewReader { proxy in
                    ScrollView {
                        // Not lazy: a lazy stack reports an estimate for rows it has not built,
                        // so the measured height fell short after a query changed and cut the
                        // last row. The palette's limits keep the rows to a few dozen at most.
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(lines) { line in
                                switch line {
                                case .header(let group):
                                    header(group)
                                case .row(let item, let index):
                                    row(item, isSelected: index == selection, state: state)
                                        .onHover { if $0 { selection = index } }
                                }
                            }
                        }
                        .padding(.vertical, AppSpacing.xxs)
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { listContentHeight = $0 }
                    }
                    // As tall as its rows up to 420 pt, then it scrolls. A scroll view takes all the
                    // height it is offered, and a `maxHeight` frame grows to its cap when offered
                    // more, as the window's overlay does: so the height is fixed from the rows' own.
                    .frame(height: min(listContentHeight ?? Self.listCap, Self.listCap))
                    // New results, or a new chip, start at the top.
                    .onChange(of: results) { _, newResults in
                        if let first = newResults.groups.first {
                            if first.kind == .suggestion {
                                if let row = first.items.first { proxy.scrollTo(row.id, anchor: .top) }
                            } else {
                                proxy.scrollTo(Self.headerID(first.kind), anchor: .top)
                            }
                        }
                    }
                    .onChange(of: selection) { oldValue, newValue in
                        // The selected row always comes fully into view. Going up onto a group's
                        // first row, its header is brought in instead, which puts the row just
                        // below it; going down, the row is brought in at the bottom edge with its
                        // header just above. (Scrolling to the header going down left the header
                        // at the bottom edge and the row hidden below it.)
                        if newValue < oldValue, let group = header(openedBy: newValue) {
                            proxy.scrollTo(Self.headerID(group.kind))
                        } else if items.indices.contains(newValue) {
                            proxy.scrollTo(items[newValue].id)
                        }
                    }
                }
            } else if !trimmedQuery.isEmpty {
                Color.inkRule.frame(height: 1)
                noMatches
            }

            PaletteFoot(
                returnVerb: items.indices.contains(selection) ? items[selection].returnVerb : nil,
                narrows: tabStepsChips,
                stepsScope: controlTabStepsScope,
                escapeWord: model.isChoosingTranslation ? "Back" : "Close")
        }
        .frame(width: 560)
        // The one floating surface, solid and bright: nothing behind it dims. Its shadow is the
        // only one in the app but the loupe's, cast by the panel's shape alone so no row or
        // keycap inside it casts one too.
        .background {
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(Color.paperOverlay)
                .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
        }
        .overlay(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous).strokeBorder(Color.inkRule, lineWidth: 1))
        // Deferred a tick: when the panel reopens over a reader whose text view holds first
        // responder, a focus request made during appearance is dropped and typing goes nowhere.
        .onAppear {
            isFieldFocused = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                isFieldFocused = true
            }
        }
        // New results, or a new chip, put the selection on the first row.
        .onChange(of: results) { _, _ in selection = 0 }
        // A scope chosen from the menu: the field takes the keyboard back from it.
        .onChange(of: model.searchScope) { _, _ in isFieldFocused = true }
        .onKeyPress(.upArrow) { move(by: -1); return .handled }
        .onKeyPress(.downArrow) { move(by: 1); return .handled }
        // Tab and Shift-Tab (which may arrive as the back-tab character) step the chips. Without
        // chips they do nothing, but are still the palette's: let through, AppKit would move first
        // responder from the field to the next key view (the reader behind the panel), after which
        // typing and Esc go nowhere. Under VoiceOver Tab is the system's and the chips are ordinary
        // buttons. ⌃Tab steps the scope (`ControlTabKeys`); should it ever arrive here it never
        // steps the chips.
        .onKeyPress(keys: [.tab, Self.backTab], phases: .down) { press in
            guard !tabIsTheSystems else { return .ignored }
            let back = press.modifiers.contains(.shift) || press.key == Self.backTab
            if press.modifiers.contains(.control) {
                if controlTabStepsScope { stepScope(by: back ? -1 : 1) }
            } else if tabStepsChips {
                model.paletteChip = SearchResults.chip(after: model.paletteChip, by: back ? -1 : 1, among: chips)
            }
            return .handled
        }
        #if os(macOS)
        .background {
            ControlTabKeys(isActive: !tabIsTheSystems) { step in
                if controlTabStepsScope { stepScope(by: step) }
            }
        }
        // Escape reaches a focused text field as the cancel command.
        .onExitCommand(perform: escape)
        #endif
        .onKeyPress(.escape) { escape(); return .handled }
    }

    private static let backTab = KeyEquivalent("\u{19}")

    /// The most the list grows to, with the foot under it, before it scrolls (spec 5.1).
    private static let listCap: CGFloat = 420

    /// Esc: back from the translations, else close. Both routes above lead here, and one press is
    /// one `NSEvent`: a second call for the event already acted on is dropped, so a single press
    /// can never go back and close at once.
    private func escape() {
        #if os(macOS)
        if let event = NSApp.currentEvent {
            guard event.timestamp != lastEscapeEvent else { return }
            lastEscapeEvent = event.timestamp
        }
        #endif
        model.escapePalette()
    }

    private nonisolated static func headerID(_ kind: SearchGroupKind) -> String {
        "header:\(kind.rawValue)"
    }

    // MARK: - Groups

    /// The group's title in Label style with its count trailing (Recent has none); not a row, so
    /// never selected.
    private func header(_ group: SearchGroup) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Text(group.title)
            Spacer(minLength: AppSpacing.xs)
            if group.kind != .recent {
                Text(group.totalCount, format: .number)
                    .monospacedDigit()
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.inkSecondary)
        // In line with the rows' symbols: their inset plus the wash's.
        .padding(.horizontal, AppSpacing.sm + AppSpacing.xxs)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Rows

    private func row(_ item: PaletteItem, isSelected: Bool, state: PaletteState) -> some View {
        Button {
            model.select(item)
        } label: {
            Group {
                switch item {
                case .mark(let hit): markRow(hit, isSelected: isSelected)
                case .verse(let verse): verseRow(verse, item: item, isSelected: isSelected)
                case .command(let command): commandRow(command, item: item, isSelected: isSelected, state: state)
                default: placeRow(item, isSelected: isSelected)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(
                isSelected ? Color.accentWash : Color.clear,
                in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.xxs)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func symbol(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.callout)
            .frame(width: iconWidth)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    /// A reference, book, translation, recent or suggestion: its symbol beside its title and subtitle.
    private func placeRow(_ item: PaletteItem, isSelected: Bool) -> some View {
        HStack(spacing: AppSpacing.sm) {
            symbol(item.symbolName, color: isSelected ? Color.accent : Color.inkSecondary)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(item.title)
                    .font(.callout)
                    .foregroundStyle(Color.inkPrimary)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: AppSpacing.xs)
        }
    }

    /// A command: a place row with, trailing, the checkmark on the style or appearance in force
    /// and its shortcut as keycaps on `paper.panel`. VoiceOver hears the title, then the shortcut
    /// by name.
    private func commandRow(_ command: PaletteCommand, item: PaletteItem, isSelected: Bool, state: PaletteState) -> some View {
        let isCurrent = command.isCurrent(in: state)
        return HStack(spacing: AppSpacing.sm) {
            placeRow(item, isSelected: isSelected)
            if isCurrent {
                Image(systemName: "checkmark")
                    .font(.callout)
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityHidden(true)
            }
            if let keycaps = command.keycaps {
                KeycapRow(keycaps, fill: .paperPanel)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([command.title, command.spokenShortcut].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue(isCurrent ? "Current" : "")
    }

    /// One of the reader's marks: the reference with the date trailing, the quoted words in the
    /// page's serif on their mark's fill, then the note's first line. The matched words are
    /// bold and underlined in the quote and the note alike, the underline in the ink's own color,
    /// so the fill and its contrast hold.
    private func markRow(_ hit: SearchMarkHit, isSelected: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            symbol(hit.symbolName, color: markSymbolColor(hit, isSelected: isSelected))
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text(hit.referenceString)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer(minLength: AppSpacing.xs)
                    Text(hit.modifiedAt, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.inkTertiary)
                }
                // A conversation's last line is the assistant's, not scripture: its title stands
                // alone. On a line of its own, up to two, so a match late in a long quote still shows.
                if hit.kind != .thread, !hit.quotedText.isEmpty {
                    Text(filledQuote(hit))
                        .font(pageFace.quoteFont())
                        .foregroundStyle(hit.color == nil ? Color.inkSecondary : Color.inkPrimary)
                        .lineLimit(2)
                }
                if !hit.firstLine.isEmpty {
                    Text(SearchRanker.bolded(hit.firstLine, query: trimmedQuery))
                        .font(.callout)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel { label in
            Text(hit.kindName)
            label
        }
    }

    /// The quoted words, matches in the face's semibold italic and underlined, on their mark's
    /// fill; primary ink keeps its contrast on every mark fill (`PaletteTests`), matched or not.
    /// Without a color the words sit on the panel.
    private func filledQuote(_ hit: SearchMarkHit) -> AttributedString {
        var text = pageFace.settingMatches(SearchRanker.bolded(hit.quotedText, query: trimmedQuery), .callout, italic: true)
        if let color = hit.color { text.backgroundColor = Color(markup: color) }
        return text
    }

    /// The bookmark in the accent and the conversation in plum, as everywhere else; the rest as
    /// the other rows' symbols.
    private func markSymbolColor(_ hit: SearchMarkHit, isSelected: Bool) -> Color {
        switch hit.kind {
        case .bookmark: Color.accent
        case .thread: Color.assistant
        case .note, .highlight: isSelected ? Color.accent : Color.inkSecondary
        }
    }

    /// A verse that matched: its reference with a dot in the color of the reader's mark on it,
    /// and its text in the page's serif beneath, the matched words in its semibold, underlined.
    private func verseRow(_ verse: Verse, item: PaletteItem, isSelected: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            symbol(item.symbolName, color: isSelected ? Color.accent : Color.inkSecondary)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.xs) {
                    Text(item.title)
                        .font(.callout)
                        .foregroundStyle(Color.inkPrimary)
                    if let color = results.verseColors[item.id] {
                        Circle()
                            .fill(Color(markup: color))
                            .overlay(Circle().strokeBorder(Color.inkRule, lineWidth: 0.5))
                            .frame(width: dotSize, height: dotSize)
                            .accessibilityLabel("Marked")
                    }
                }
                Text(pageFace.settingMatches(
                    SearchRanker.bolded(verse.text.replacingOccurrences(of: "\n", with: " "), query: trimmedQuery), .callout))
                    .font(pageFace.swiftUIFont(.callout))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Nothing matched: say so, and show the forms the palette understands.
    private var noMatches: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("No matches for “\(trimmedQuery)”")
                .font(.callout)
                .foregroundStyle(Color.inkPrimary)
            Text("Try a reference like John 3:16, a book like Psalms, or a translation like KJV.")
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    /// ⌃Tab: the scope menu's next top-level choice; the selection goes to the first row, as the
    /// menu's own choice puts it once the new results come.
    private func stepScope(by step: Int) {
        model.searchScope = SearchScope.next(after: model.searchScope, in: model.books, currentBook: currentBook, by: step)
        selection = 0
    }

    private func move(by delta: Int) {
        selection = Self.selection(after: selection, moving: delta, in: results)
    }
}

#if os(macOS)
/// ⌃Tab and ⌃⇧Tab for the palette (⌥Tab is the window manager's on the owner's Mac). They never
/// reach `onKeyPress`: `NSWindow.sendEvent` takes ⌃Tab as a key-view key (it moves focus even out
/// of a text view) before the field sees it. A key equivalent is offered to the window's views
/// first, so this view, behind the panel, takes them whenever Tab is the palette's (`isActive`,
/// VoiceOver off): `step` gets 1, or -1 with Shift, and decides whether the scope moves, and the
/// key never moves focus out of the field. Under VoiceOver it takes nothing and the keys are the
/// system's. (Not a `.keyboardShortcut`: those are the menus' and the shortcuts sheet's.)
private struct ControlTabKeys: NSViewRepresentable {
    let isActive: Bool
    let step: (Int) -> Void

    func makeNSView(context: Context) -> KeyView { KeyView() }

    func updateNSView(_ view: KeyView, context: Context) {
        view.isActive = isActive
        view.step = step
    }

    final class KeyView: NSView {
        var isActive = false
        var step: (Int) -> Void = { _ in }
        /// The Tab key's virtual key code (`kVK_Tab`).
        private static let tabKeyCode: UInt16 = 48

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard isActive, event.type == .keyDown, event.keyCode == Self.tabKeyCode,
                  flags.contains(.control), flags.isDisjoint(with: [.command, .option])
            else { return super.performKeyEquivalent(with: event) }
            step(flags.contains(.shift) ? -1 : 1)
            return true
        }

        /// Never in the way of a click.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
#endif
