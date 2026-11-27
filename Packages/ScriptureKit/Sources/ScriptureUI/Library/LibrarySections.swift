import ScriptureData
import SwiftUI

/// What a person's page and a place's page (Task 8) share, each a view of its own that takes plain
/// values. The sections open with a `LibraryPageHeading`; a list's group label keeps the Label style.

/// A Library page's text column (Matt's review, 2026-11-24): at most the reader's measure, centred in the page as
/// the reader centres its column. With the system's styles (the phone) it is what these pages had before: a scaled
/// 520 pt page less its `lg` margins, at the leading edge. `outset` widens it at each side, for rows whose padding
/// hangs outside the text's edge.
private struct LibraryColumn: ViewModifier {
    let outset: CGFloat
    @Environment(\.libraryType) private var type
    /// The page's widest with the system's styles, its margins included.
    @ScaledMetric(relativeTo: .body) private var systemPage: CGFloat = 520

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: type.columnMaxWidth(systemPage: systemPage, outset: outset), alignment: .leading)
            .frame(maxWidth: .infinity, alignment: type.measure == nil ? .leading : .center)
    }
}

/// A Library page's plain text that can be selected and copied on the Mac (Matt's review, 2026-11-24); the phone's
/// pages are as they were.
private struct LibrarySelectable: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.textSelection(.enabled)
        #else
        content
        #endif
    }
}

extension View {
    /// The section in the Library's text column (`LibraryColumn`).
    func libraryColumn(outset: CGFloat = 0) -> some View {
        modifier(LibraryColumn(outset: outset))
    }

    /// Plain text a reader can select and copy on the Mac (`LibrarySelectable`).
    func librarySelectable() -> some View {
        modifier(LibrarySelectable())
    }
}

/// A Library page's section heading (Matt's choice C, 2026-11-24: "headings that look like headings", with a divider):
/// a 1 pt `ink.rule` hairline across the text column, then the heading in the page face, semibold, a step above the
/// reading size (`.title3`, 21 pt at the Mac's 18), in `ink.primary`, with the header trait; a count beside it on its
/// baseline ("226 verses") in the system face at the reading size, `ink.secondary`, or under it where the two do not
/// fit on one line. `rule` is false for a heading nothing precedes. A rule, not a card: nothing is boxed.
struct LibraryPageHeading: View {
    let title: String
    let count: String?
    let rule: Bool
    @Environment(\.libraryType) private var type
    @Environment(\.pageFace) private var pageFace
    /// Under the rule, and the more room above it than a section's own rows have: tied to the heading's text, so scaled
    /// with it (Dynamic Type on the phone, the reader's size on the Mac).
    @ScaledMetric(relativeTo: .title3) private var scaledUnderRule: CGFloat = AppSpacing.sm
    @ScaledMetric(relativeTo: .title3) private var scaledAboveRule: CGFloat = AppSpacing.xs

    init(_ title: String, count: String? = nil, rule: Bool = true) {
        self.title = title
        self.count = count
        self.rule = rule
    }

    /// What VoiceOver reads: "References, 896 verses".
    nonisolated static func spoken(_ title: String, count: String?) -> String {
        count.map { "\(title), \($0)" } ?? title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: type.metric(scaledUnderRule)) {
            if rule { HairlineRule() }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: type.metric(scaledUnderRule)) { heading; countText?.fixedSize() }
                VStack(alignment: .leading, spacing: AppSpacing.xxs) { heading; countText }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.spoken(title, count: count))
            .accessibilityAddTraits(.isHeader)
        }
        // Room above the rule, more than between a section's own rows, so the rule starts a section.
        .padding(.top, rule ? type.metric(scaledAboveRule) : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heading: some View {
        Text(title)
            .font(type.pageFont(pageFace, .title3, weight: .semibold))
            .foregroundStyle(Color.inkPrimary)
    }

    private var countText: Text? {
        count.map { Text($0).font(type.font(type.reading)).foregroundStyle(Color.inkSecondary) }
    }
}

/// A list's group label ("Not on the map", "7 places here"): `.caption` semibold `ink.secondary`. A page's sections
/// take `LibraryPageHeading`.
struct LibrarySectionHeader: View {
    let title: String
    @Environment(\.libraryType) private var type

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(type.font(.caption, weight: .semibold))
            .foregroundStyle(Color.inkSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The scroll identity of a book's group on a page, and of a chapter's line in it, for coming back
/// to the reference opened from it.
enum LibraryScrollID {
    static func group(_ bookID: String) -> String { "verses-\(bookID)" }
    static func line(_ bookID: String, _ chapter: Int?) -> String { "line-\(bookID)-\(chapter ?? 0)" }
    /// A stop of the Mac's family tree, by its slot id: the keys scroll the focused one into view.
    static func tree(_ slotID: String) -> String { "tree-\(slotID)" }
}

/// What coming back to a run needs of the verse lines (Departure 14), shared by both pages; the run's book is opened
/// by `LibraryReferences.opening`.
enum LibraryVersesAnchor {
    /// The books whose lines are all shown at first: the anchor's book when its line is past the twelfth.
    static func initialChapters(here: VerseGroup?, elsewhere: [VerseGroup], anchor: Reference?) -> Set<String> {
        guard let anchor, let group = ([here].compactMap { $0 } + elsewhere).first(where: { $0.book == anchor.book }),
              VerseLines.showsAll(group.lines, anchor: anchor) else { return [] }
        return [group.book.id]
    }

    /// The anchor's chapter line; a one-chapter book's line has no chapter.
    static func scrollID(_ anchor: Reference) -> String {
        LibraryScrollID.line(anchor.book.id, VerseLines.oneChapterBooks.contains(anchor.book.id) ? nil : anchor.chapter)
    }

    /// Where a page scrolls to on coming back: the run's chapter line when the book has one, else its group.
    static func scrollTarget(_ anchor: Reference, in groups: [VerseGroup]) -> String {
        guard let group = groups.first(where: { $0.book == anchor.book }) else { return LibraryScrollID.group(anchor.book.id) }
        let id = scrollID(anchor)
        let lines = group.lines.map { LibraryScrollID.line(group.book.id, $0.chapter) }
        return lines.contains(id) ? id : LibraryScrollID.group(group.book.id)
    }
}

/// The References section's books (Matt, 2026-11-24: "all ... in one section with the heading 'References'"): the
/// book the page was opened from first, open at first; then every other book in canon order, closed, or all open where
/// the page holds few references (`PersonPage.opensEveryBookUpTo`). A page opened from no book (the whole Bible), or
/// from a book that does not name them, has no first book.
///
/// What the reader opens and closes is kept as the books turned from how the page opens (`toggled`), so an empty set
/// is the page as it opens: a first book closed stays closed while the page stays, and nothing has to be seeded.
///
/// It holds the page's own groups, not a joined copy: a page's redraw compares them by their storage, not verse by verse.
struct LibraryReferences: Equatable {
    /// The book the page was opened from, the first; nil for the whole Bible or a book that does not name them.
    let here: VerseGroup?
    /// Every other book, in canon order.
    let elsewhere: [VerseGroup]
    /// Every book is open at first.
    let opensEveryBook: Bool

    init(here: VerseGroup?, elsewhere: [VerseGroup]) {
        self.here = here
        self.elsewhere = elsewhere
        opensEveryBook = (here?.references.count ?? 0) + elsewhere.reduce(0) { $0 + $1.references.count } <= PersonPage.opensEveryBookUpTo
    }

    /// The page's books: the first, then the rest in canon order.
    var groups: [VerseGroup] { [here].compactMap { $0 } + elsewhere }

    /// The book the page was opened from, open at first.
    var firstBook: String? { here?.book.id }

    /// The heading.
    static let title = "References"

    /// "945 verses", "1 verse": beside the heading (the page's whole count) and a book's row's value.
    nonisolated static func count(_ count: Int) -> String { "\(count.formatted()) \(count == 1 ? "verse" : "verses")" }

    /// Every verse of the page, the heading's count.
    var total: Int { (here?.count ?? 0) + elsewhere.reduce(0) { $0 + $1.count } }

    /// Whether `book` is open, the reader's turns `toggled` against how the page opens.
    func isOpen(_ book: String, toggled: Set<String>) -> Bool {
        (opensEveryBook || book == firstBook) != toggled.contains(book)
    }

    /// The reader's turns with `book` opened or closed (a click or Space on its row).
    func toggling(_ book: String, in toggled: Set<String>) -> Set<String> {
        toggled.symmetricDifference([book])
    }

    /// The reader's turns with `book` open, for coming back to a run in it (the first book too, where the reader had
    /// closed it); a book not on the page, or open, leaves them as they are.
    func opening(_ book: String, in toggled: Set<String>) -> Set<String> {
        guard groups.contains(where: { $0.book.id == book }), !isOpen(book, toggled: toggled) else { return toggled }
        return toggling(book, in: toggled)
    }
}

/// "References" and the page's count, then each book a row of its name and count that opens to its lines, one line a
/// chapter written without the book's name: the first book open at first (`LibraryReferences`). `toggledBooks` holds
/// the reader's turns, and `onToggle` takes them back changed; `showsAll` the books whose every line is shown. The turns are
/// a value, not a binding: the page's binding reaches back to the window's place through closures, which SwiftUI cannot
/// compare, so a binding of it counts as changed in every update and would build every row again each time.
struct LibraryReferencesSection: View {
    let references: LibraryReferences
    let toggledBooks: Set<String>
    let onToggle: (Set<String>) -> Void
    let showsAll: Set<String>
    let navigation: NavigationModel
    let onShowAll: (String) -> Void
    let onShow: ((Reference) -> Void)?
    let onOpen: (Reference) -> Void

    @Environment(\.libraryType) private var type

    /// The chevron's column, grown with the reader's type.
    private var chevronColumn: CGFloat { type.metric(AppSpacing.md) }

    /// What VoiceOver reads after a row's name: "945 verses, expanded".
    nonisolated static func spokenValue(count: Int, isOpen: Bool) -> String {
        "\(LibraryReferences.count(count)), \(isOpen ? "expanded" : "collapsed")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            LibraryPageHeading(LibraryReferences.title, count: LibraryReferences.count(references.total))
                .padding(.bottom, AppSpacing.xxs)
            if let here = references.here { row(here) }
            ForEach(references.elsewhere) { group in
                row(group)
            }
        }
    }

    private func row(_ group: VerseGroup) -> some View {
        let isOpen = references.isOpen(group.book.id, toggled: toggledBooks)
        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Button {
                onToggle(references.toggling(group.book.id, in: toggledBooks))
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "chevron.right")
                        .font(type.font(.caption2, weight: .semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .frame(width: chevronColumn)
                    Text(group.book.name)
                        .font(type.font(type.reading))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer(minLength: AppSpacing.xs)
                    Text(group.count, format: .number)
                        .font(type.font(.caption).monospacedDigit())
                        .foregroundStyle(Color.inkSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(group.book.name)
            .accessibilityValue(Self.spokenValue(count: group.count, isOpen: isOpen))
            if isOpen {
                VerseLinesView(group: group, showsAll: showsAll.contains(group.book.id), navigation: navigation,
                               onShowAll: { onShowAll(group.book.id) }, onShow: onShow, onOpen: onOpen)
                    .padding(.leading, chevronColumn + AppSpacing.xs)
                    .padding(.bottom, AppSpacing.xxs)
            }
        }
        .id(LibraryScrollID.group(group.book.id))
    }
}

/// The notice at the head of a page that shows a date, while it is unanswered and dates are on; it
/// scrolls with the page. `LibraryDatesFootnote` takes its place once it is answered, never beside it.
struct LibraryDatesNotice: View {
    let hasDate: Bool
    @AppStorage(LibraryDates.showKey) private var showsDates = LibraryDates.defaultShows
    @AppStorage(LibraryDates.noticeAnsweredKey) private var answered = false
    @Environment(\.openLibrarySettings) private var openSettings

    var body: some View {
        // Both settings are read here so that answering redraws this (on iOS an unread `@AppStorage`
        // did not: the notice stayed after OK until the page was built again); the rule is `LibraryDates`'.
        let _ = (showsDates, answered)
        if LibraryDates.showsNotice(.standard, viewHasDate: hasDate) {
            DatesNotice(onOpenSettings: openSettings.open)
        }
    }
}

/// The line under a date once the notice has been answered (or dates were turned off and on again).
struct LibraryDatesFootnote: View {
    @AppStorage(LibraryDates.showKey) private var showsDates = LibraryDates.defaultShows
    @AppStorage(LibraryDates.noticeAnsweredKey) private var answered = false
    @Environment(\.openLibrarySettings) private var openSettings

    var body: some View {
        let _ = (showsDates, answered)
        if !LibraryDates.showsNotice(.standard, viewHasDate: true) {
            DatesFootnote(onOpenSettings: openSettings.open)
        }
    }
}

/// Where the page's footnote under a date sends the reader: Settings › General. The window sets it.
struct LibrarySettingsOpener {
    let open: () -> Void
}

extension EnvironmentValues {
    @Entry var openLibrarySettings = LibrarySettingsOpener(open: {})
}

/// A row of People's or Places' list: the name, a second line where there is one, the count of
/// verses trailing in `.monospacedDigit()` (none when `count` is nil), or a `note` in its place. The
/// chosen row is on the accent wash at radius `md` and reports its rectangle in `coordinateSpace`, the
/// list's focus ring's shape. A dimmed row (another chapter's, while one is chosen) sets its name and
/// detail in `ink.tertiary`.
struct LibraryListRow<ID: Hashable>: View {
    let id: ID
    let name: String
    let detail: String?
    let count: Int?
    var note: String?
    var isDimmed = false
    let isChosen: Bool
    let accessibilityLabel: String
    var accessibilityHint: String?
    let coordinateSpace: String
    let onChosenRect: (CGRect) -> Void
    let onChoose: () -> Void
    @Environment(\.libraryType) private var type

    init(id: ID, name: String, detail: String?, count: Int?, note: String? = nil, isDimmed: Bool = false, isChosen: Bool,
         accessibilityLabel: String, accessibilityHint: String? = nil, coordinateSpace: String,
         onChosenRect: @escaping (CGRect) -> Void, onChoose: @escaping () -> Void) {
        self.id = id
        self.name = name
        self.detail = detail
        self.count = count
        self.note = note
        self.isDimmed = isDimmed
        self.isChosen = isChosen
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.coordinateSpace = coordinateSpace
        self.onChosenRect = onChosenRect
        self.onChoose = onChoose
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(type.font(type.reading))
                    .foregroundStyle(isDimmed ? Color.inkTertiary : Color.inkPrimary)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(type.font(.caption))
                        .foregroundStyle(isDimmed ? Color.inkTertiary : Color.inkSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: AppSpacing.xxs)
            if let count {
                Text(count, format: .number)
                    .font(type.font(.caption).monospacedDigit())
                    .foregroundStyle(Color.inkSecondary)
            } else if let note {
                Text(note)
                    .font(type.font(.caption))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
        .background {
            if isChosen {
                // The space by value, so the closure holds no `self` (a generic view's metatype is not Sendable).
                let space = coordinateSpace
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(Color.accentWash)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { onChosenRect($0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onChoose)
        .id(id)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onChoose() }
    }
}

/// The chosen row's rounded rectangle, wherever it sits in the list: the list's focus-effect shape.
struct LibraryChosenRowShape: Shape {
    let rect: CGRect

    func path(in _: CGRect) -> Path {
        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous).path(in: rect)
    }
}
