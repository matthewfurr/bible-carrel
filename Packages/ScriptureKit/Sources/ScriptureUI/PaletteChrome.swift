import ScriptureData
import SwiftUI

/// Who has the Tab key in the palette.
public enum PaletteKeys {
    /// Tab steps the chips when there are chips and VoiceOver is off, whatever Keyboard navigation
    /// (`fullKeyboardAccess`) is; under VoiceOver Tab is the system's. (Controller's ruling after
    /// the live pass: the reader keeps Keyboard navigation on, and the chips must still step.)
    public static func tabStepsChips(chipCount: Int, fullKeyboardAccess: Bool, voiceOver: Bool) -> Bool {
        chipCount > 0 && !voiceOver
    }

    /// ⌃Tab and ⌃⇧Tab step the scope while its menu shows, so it can be reached from the keyboard
    /// with Tab stepping the chips; under VoiceOver Tab is the system's, ⌃Tab with it.
    public static func controlTabStepsScope(showsScopeMenu: Bool, voiceOver: Bool) -> Bool {
        showsScopeMenu && !voiceOver
    }
}

/// A chip's face: `.caption` semibold in a capsule on `paper.panel`, on `accent.wash` when it is
/// the one in force. No stroke. The scope menu's label is one too.
struct ChipLabel<Content: View>: View {
    let isOn: Bool
    /// The Label style by default; the Library's place page passes its own type's.
    var font: Font = .caption.weight(.semibold)
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: AppSpacing.xxs) { content }
            .font(font)
            .foregroundStyle(Color.inkPrimary)
            .lineLimit(1)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs)
            .background(isOn ? Color.accentWash : Color.paperPanel, in: Capsule())
            .fixedSize()
    }
}

/// The scope's menu, on both apps; `label` draws its capsule. The sections the translation has,
/// the open book, then every book under its canon section; the scope in force carries the
/// menu's own checkmark.
public struct ScopeMenu<Label: View>: View {
    @Binding var scope: SearchScope
    let books: [TranslationBook]
    let currentBook: Book?
    let label: Label

    public init(scope: Binding<SearchScope>, books: [TranslationBook], currentBook: Book?, @ViewBuilder label: () -> Label) {
        self._scope = scope
        self.books = books
        self.currentBook = currentBook
        self.label = label()
    }

    public var body: some View {
        Menu {
            ForEach(SearchScope.sections(in: books), id: \.self) { section in
                option(section, title: section.title)
            }
            Divider()
            if let currentBook {
                option(.book(currentBook.id), title: "This Book: \(currentBook.name)")
            }
            Menu("Book") {
                ForEach(Canon.allCases, id: \.self) { canon in
                    let inCanon = books.filter { $0.book.canon == canon }
                    if !inCanon.isEmpty {
                        Section(canon.displayName) {
                            ForEach(inCanon, id: \.book.id) { entry in
                                option(.book(entry.book.id), title: entry.book.name)
                            }
                        }
                    }
                }
            }
        } label: {
            label
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Search in")
        .accessibilityValue(scope.title)
    }

    /// A scope as a toggle, so the menu draws its own checkmark beside the one in force.
    private func option(_ option: SearchScope, title: String) -> some View {
        Toggle(title, isOn: Binding(get: { scope == option }, set: { if $0 { scope = option } }))
    }
}

/// Under the field once something is typed: All, then each kind present with its count, and
/// the scope menu at the trailing end while Scripture can be narrowed.
struct PaletteChipRow: View {
    let chips: [SearchChip]
    let results: SearchResults
    let chosen: SearchChip?
    let showsScopeMenu: Bool
    @Binding var scope: SearchScope
    let books: [TranslationBook]
    let currentBook: Book?
    let choose: (SearchChip?) -> Void

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            ViewThatFits(in: .horizontal) {
                chipStack
                ScrollView(.horizontal) { chipStack }
                    .scrollIndicators(.hidden)
            }
            Spacer(minLength: 0)
            if showsScopeMenu {
                ScopeMenu(scope: $scope, books: books, currentBook: currentBook) {
                    ChipLabel(isOn: scope != .wholeBible) {
                        Text(scope.title)
                        Image(systemName: "chevron.down")
                            .foregroundStyle(Color.inkSecondary)
                            .accessibilityHidden(true)
                    }
                }
                .help("Where Scripture is searched")
            }
        }
    }

    private var chipStack: some View {
        HStack(spacing: AppSpacing.xs) {
            chip(nil, title: "All", count: nil)
            ForEach(chips, id: \.self) { kind in
                chip(kind, title: kind.title, count: results.count(of: kind))
            }
        }
    }

    private func chip(_ kind: SearchChip?, title: String, count: Int?) -> some View {
        Button {
            choose(kind)
        } label: {
            ChipLabel(isOn: chosen == kind) {
                Text(title)
                if let count {
                    Text(count, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(chosen == kind ? .isSelected : [])
    }
}

/// The panel's foot: what Return does with the selected row, how to move, narrow and step the
/// scope, and how to close. One line, one element for VoiceOver.
struct PaletteFoot: View {
    /// Return's word for the selected row; nil with no row.
    let returnVerb: String?
    let narrows: Bool
    /// ⌃Tab steps the scope (its menu is showing and the key is the palette's).
    let stepsScope: Bool
    /// "Close", or "Back" while the translations alone are showing.
    let escapeWord: String

    var body: some View {
        VStack(spacing: 0) {
            Color.inkRule.frame(height: 1)
            HStack(spacing: AppSpacing.md) {
                if let returnVerb { part(["↩"], returnVerb) }
                part(["↑", "↓"], "Move")
                if narrows { part(["⇥"], "Narrow") }
                if stepsScope { part(["⌃", "⇥"], "Scope") }
                Spacer(minLength: AppSpacing.xs)
                part(["esc"], escapeWord)
            }
            .font(.caption)
            .foregroundStyle(Color.inkSecondary)
            .lineLimit(1)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(returnVerb: returnVerb, narrows: narrows, stepsScope: stepsScope, escapeWord: escapeWord))
    }

    private func part(_ keys: [String], _ word: String) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            KeycapRow(keys, fill: .paperPanel)
            Text(word)
        }
        .fixedSize()
    }

    /// The foot as VoiceOver reads it, its parts in the order they show.
    nonisolated static func spoken(returnVerb: String?, narrows: Bool, stepsScope: Bool, escapeWord: String) -> String {
        var parts: [String] = []
        if let returnVerb { parts.append("Return: \(returnVerb)") }
        parts.append("Up and down arrows: Move")
        if narrows { parts.append("Tab: Narrow") }
        if stepsScope { parts.append("Control Tab: Scope") }
        parts.append("Escape: \(escapeWord)")
        return parts.joined(separator: ". ")
    }
}
