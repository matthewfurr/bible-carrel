#if os(iOS)
import ScriptureData
import SwiftUI

/// The search tab: one search for everything, reached from the tab bar's search button. Results
/// come grouped by kind (`NavigationModel.paletteResults`), with chips that narrow to one kind; a
/// passage lists everything marked there in verse order. A row opens its place in the reader, a
/// conversation in Ask; a translation is switched in place; a person or place found by name has
/// their page for the whole Bible pushed on Search's own stack. With nothing typed it lists what was
/// lately read or searched (Recent, with Clear); a near spelling is offered first when nothing
/// matched; Scripture can be narrowed to a part of the Bible and put in Bible order.
public struct PhoneSearchScreen: View {
    private let navigation: NavigationModel
    private let shell: PhoneShellModel
    /// The chip chosen; nil is All.
    @State private var scope: SearchGroupKind?
    /// The query the results were ranked for, trimmed; bolding and "No matches" follow it rather
    /// than the text still being typed.
    @State private var rankedQuery = ""

    /// The kinds that get a chip, in the chips' order, with their names.
    private static let chipKinds: [(SearchGroupKind, String)] = [
        (.marksInPassage, "Marks"), (.notes, "Notes"), (.asked, "Asked"), (.scripture, "Scripture"),
        (.people, "People"), (.places, "Places"),
    ]

    /// The most verses one search shows: Show all on a very common word ("the" has 23,723
    /// matches in ESV) held the main thread for about a third of a second in the simulator.
    private static let mostVersesShown = 500

    public init(navigation: NavigationModel, shell: PhoneShellModel) {
        self.navigation = navigation
        self.shell = shell
    }

    private var trimmedQuery: String {
        navigation.paletteQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The chosen chip's group, or every group when that group is not among the results.
    private var shownResults: SearchResults {
        let results = navigation.paletteResults
        guard let scope, results.groups.contains(where: { $0.kind == scope }) else { return results }
        return results.only(scope)
    }

    /// What the search task depends on: the model's key, and, with nothing typed, whether this tab
    /// is the one showing, so Recent is asked for again each time he comes back to it (a chapter
    /// read since has changed the list, and the model keeps no results for an empty field).
    private struct SearchTask: Equatable {
        let key: PaletteSearchKey
        let isEmptyAndShown: Bool
    }

    private var searchTask: SearchTask {
        SearchTask(key: navigation.paletteSearchKey, isEmptyAndShown: trimmedQuery.isEmpty && shell.tab == .search)
    }

    public var body: some View {
        content
            .background(Color.paperPage)
            // Typing pauses 150 ms before the search runs. A new query (or none) starts over at
            // All with the phone's limits, so one Show all does not leave every later search
            // unbounded; Show all, a scope or a translation searches the same query again as it is.
            .task(id: searchTask) {
                if trimmedQuery != rankedQuery {
                    scope = nil
                    navigation.searchLimits = .phone
                }
                if trimmedQuery.isEmpty {
                    await refresh()
                    return
                }
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                await refresh()
            }
    }

    @ViewBuilder
    private var content: some View {
        if trimmedQuery.isEmpty {
            if navigation.paletteResults.groups.contains(where: { $0.kind == .recent }) {
                list
            } else {
                Text("Search a reference like John 3:16, a book like Psalms, or a word in the text or your notes.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
            }
        } else if navigation.paletteResults.groups.isEmpty {
            if rankedQuery == trimmedQuery {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    // Narrowed to a part of the Bible, the search can be widened from here.
                    if navigation.searchScope != .wholeBible {
                        menus
                    }
                    Text("No matches for “\(trimmedQuery)”")
                        .font(.callout)
                        .foregroundStyle(Color.inkPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Color.paperPage
            }
        } else {
            list
        }
    }

    private var list: some View {
        List {
            // A lone All chip narrows nothing.
            if hasChips {
                chips
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.paperPage)
                    .listRowInsets(EdgeInsets())
            }
            if showsMenus {
                menus
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.paperPage)
                    .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.md, bottom: AppSpacing.xs, trailing: AppSpacing.md))
            }
            ForEach(shownResults.groups) { group in
                if group.kind == .suggestion {
                    // "Did you mean" is a row of its own, not a group: no header.
                    groupRows(group)
                } else {
                    Section {
                        groupRows(group)
                    } header: {
                        header(group)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    @ViewBuilder
    private func groupRows(_ group: SearchGroup) -> some View {
        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
            row(item, isFirstGoTo: group.kind == .goTo && index == 0)
        }
        if group.items.count < group.totalCount {
            if group.kind == .scripture, group.items.count >= Self.mostVersesShown {
                versesCapped(group)
            } else {
                showAll(group)
            }
        }
    }

    // MARK: - Menus

    /// Order shows while the Scripture chip is chosen.
    private var showsOrder: Bool {
        scope == .scripture && navigation.paletteResults.groups.contains { $0.kind == .scripture }
    }

    private var showsMenus: Bool { navigation.showsScopeMenu || showsOrder }

    /// Side by side, or one above the other when the text is too large to fit.
    private var menus: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) { menuItems }
            VStack(alignment: .leading, spacing: AppSpacing.xs) { menuItems }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var menuItems: some View {
        if navigation.showsScopeMenu {
            ScopeMenu(
                scope: Binding(get: { navigation.searchScope }, set: { navigation.searchScope = $0 }),
                books: navigation.books,
                currentBook: navigation.location.flatMap { location in
                    navigation.books.first { $0.book.id == location.book }?.book
                }
            ) {
                PhoneMenuLabel("Search in", choice: navigation.searchScope.title,
                               isChanged: navigation.searchScope != .wholeBible)
            }
        }
        if showsOrder {
            Menu {
                Picker("Order", selection: Binding(get: { navigation.searchOrder }, set: { navigation.searchOrder = $0 })) {
                    ForEach(SearchOrder.allCases, id: \.self) { order in
                        Text(order.title).tag(order)
                    }
                }
            } label: {
                PhoneMenuLabel("Order", choice: navigation.searchOrder.title,
                               isChanged: navigation.searchOrder != .bestMatch)
            }
        }
    }

    // MARK: - Chips

    /// Whether any group among the results has a chip of its own.
    private var hasChips: Bool {
        navigation.paletteResults.groups.contains { group in Self.chipKinds.contains { $0.0 == group.kind } }
    }

    /// All, then one chip per kind present; sideways when they do not fit.
    private var chips: some View {
        let groups = navigation.paletteResults.groups
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                chip("All", count: nil, kind: nil)
                ForEach(Self.chipKinds, id: \.0) { kind, name in
                    if let group = groups.first(where: { $0.kind == kind }) {
                        chip(name, count: group.totalCount, kind: kind)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
        }
    }

    private func chip(_ name: String, count: Int?, kind: SearchGroupKind?) -> some View {
        let isChosen = scope == kind
        return Button { scope = kind } label: {
            HStack(spacing: AppSpacing.xxs) {
                Text(name)
                    .foregroundStyle(Color.inkPrimary)
                if let count {
                    Text(count, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(isChosen ? Color.accentWash : Color.paperPanel, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    // MARK: - Groups

    @ViewBuilder
    private func header(_ group: SearchGroup) -> some View {
        if group.kind == .recent {
            recentHeader(group)
        } else {
            countedHeader(group)
        }
    }

    /// Recent's title with Clear trailing: the phone has no commands, so Clear Recents lives here.
    private func recentHeader(_ group: SearchGroup) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: Self.symbolName(for: group.kind))
                .foregroundStyle(Color.inkSecondary)
                .accessibilityHidden(true)
            Text(group.title)
                .foregroundStyle(Color.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: AppSpacing.xs)
            Button("Clear") {
                navigation.recents?.clear()
                Task { await refresh() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accent)
        }
        .font(.caption.weight(.semibold))
    }

    private func countedHeader(_ group: SearchGroup) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: Self.symbolName(for: group.kind))
                .accessibilityHidden(true)
            Text(group.title)
            Spacer(minLength: AppSpacing.xs)
            Text(group.totalCount, format: .number)
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.inkSecondary)
        .accessibilityElement(children: .combine)
    }

    /// The end of a Scripture group that Show all has taken as far as it goes.
    private func versesCapped(_ group: SearchGroup) -> some View {
        Text("Showing \(Self.mostVersesShown) of \(group.totalCount). Add a word to narrow it.")
            .font(.callout)
            .foregroundStyle(Color.inkSecondary)
            .listRowBackground(Color.paperPage)
            .listRowSeparatorTint(Color.inkRule)
    }

    /// Chooses the group's chip and lifts its limit to every match; Scripture stops at
    /// `mostVersesShown`.
    private func showAll(_ group: SearchGroup) -> some View {
        Button("Show all \(group.totalCount)") {
            switch group.kind {
            case .marksInPassage: navigation.searchLimits.marksInPassage = group.totalCount
            case .notes: navigation.searchLimits.notes = group.totalCount
            case .asked: navigation.searchLimits.asked = group.totalCount
            case .scripture: navigation.searchLimits.verses = min(group.totalCount, Self.mostVersesShown)
            case .books: navigation.searchLimits.books = group.totalCount
            case .people: navigation.searchLimits.people = group.totalCount
            case .places: navigation.searchLimits.places = group.totalCount
            case .goTo, .translations, .commands, .suggestion, .recent: break
            }
            if Self.chipKinds.contains(where: { $0.0 == group.kind }) { scope = group.kind }
            Task { await refresh() }
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color.accent)
        .listRowBackground(Color.paperPage)
        .listRowSeparatorTint(Color.inkRule)
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(_ item: PaletteItem, isFirstGoTo: Bool) -> some View {
        Button { choose(item) } label: {
            switch item {
            case .mark(let hit):
                PhoneMarkRow(
                    symbolName: hit.symbolName,
                    reference: hit.referenceString,
                    date: hit.modifiedAt,
                    // A conversation's last line is the assistant's, not scripture: its title stands alone.
                    // The matched word is bold and underlined in the quote too, on the mark's own fill.
                    quote: hit.kind == .thread ? AttributedString() : SearchRanker.bolded(hit.quotedText, query: rankedQuery),
                    color: hit.color,
                    body: hit.firstLine.isEmpty ? nil : SearchRanker.bolded(hit.firstLine, query: rankedQuery))
                .kind(hit.kindName)
            case .verse(let verse):
                SearchVerseRow(
                    reference: item.title,
                    color: navigation.paletteResults.verseColors[item.id],
                    text: SearchRanker.bolded(verse.text.replacingOccurrences(of: "\n", with: " "), query: rankedQuery))
            default:
                SearchPlaceRow(symbolName: item.symbolName, title: item.title, subtitle: item.subtitle, isLead: isFirstGoTo)
            }
        }
        .buttonStyle(.plain)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .listRowBackground(Color.paperPage)
        .listRowSeparatorTint(Color.inkRule)
    }

    private static func symbolName(for kind: SearchGroupKind) -> String {
        switch kind {
        case .goTo: "arrow.right.circle"
        case .marksInPassage, .notes: "note.text"
        case .books: "book"
        case .translations: "character.book.closed"
        case .commands: "command"
        case .asked: "sparkles"
        case .scripture: "text.quote"
        case .suggestion: "magnifyingglass"
        case .recent: "clock"
        case .people: "person.2"
        case .places: "map"
        }
    }

    // MARK: - Actions

    /// Searches off the main actor; a refresh overtaken by a newer one leaves the results, and
    /// `rankedQuery`, to it.
    private func refresh() async {
        if await navigation.refreshPalette() { rankedQuery = trimmedQuery }
    }

    /// A conversation opens in Ask (`showTarget`, wired by the root view); a translation is
    /// switched here; anything else shows in the reader, a passage or book as a move and a mark or
    /// verse as a lookup with the way back. The query and its results stay for when he comes back;
    /// a translation switched here ranks them again in it. A person or place is pushed here, on
    /// Search's stack, as their page for the whole Bible; it is not added to Recent.
    private func choose(_ item: PaletteItem) {
        switch item {
        case .person(let person):
            shell.searchPath.append(.entity(book: nil, .person(person.id)))
            return
        case .place(let place):
            shell.searchPath.append(.entity(book: nil, .place(place.id)))
            return
        default:
            break
        }
        navigation.select(item, keepingQuery: true)
        if case .translation = item { Task { await refresh() } }
        if item.showsReaderWhenChosen { shell.showInReader() }
    }
}

/// A place to go: a reference, a book or a translation, its symbol beside its title and subtitle.
/// The lead Go to row sits on the accent wash.
private struct SearchPlaceRow: View {
    let symbolName: String
    let title: String
    let subtitle: String?
    let isLead: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Image(systemName: symbolName)
                .font(.callout)
                .foregroundStyle(isLead ? Color.accent : Color.inkSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(.callout.weight(isLead ? .semibold : .regular))
                    .foregroundStyle(Color.inkPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.xxs)
        .padding(.horizontal, isLead ? AppSpacing.xs : 0)
        .background(
            isLead ? Color.accentWash : Color.clear,
            in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        // The wash reaches past the text, which stays in line with the rows below.
        .padding(.horizontal, isLead ? -AppSpacing.xs : 0)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A verse that matched: its reference, a dot in the color of a mark on it, and its text in the
/// page's serif with the matched words in its semibold, underlined.
private struct SearchVerseRow: View {
    @Environment(\.pageFace) private var pageFace
    let reference: String
    let color: MarkupColor?
    let text: AttributedString
    @ScaledMetric(relativeTo: .subheadline) private var dotSize: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(spacing: AppSpacing.xs) {
                Text(reference)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkPrimary)
                if let color {
                    Circle()
                        .fill(Color(markup: color))
                        .overlay(Circle().strokeBorder(Color.inkRule, lineWidth: 0.5))
                        .frame(width: dotSize, height: dotSize)
                        .accessibilityLabel("Marked")
                }
            }
            Text(pageFace.settingMatches(text, .callout))
                .font(pageFace.swiftUIFont(.callout))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(3)
        }
        .padding(.vertical, AppSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
#endif
