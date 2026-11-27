import SwiftUI

/// An arrow key's move in the chapter grid.
enum ChapterGridMove: Sendable { case left, right, up, down }

/// A quiet grid of chapter numbers, set in the page's serif at the reader's page size and centred
/// in its column: the Mac's book pane draws one under its header, as many cells across as the
/// pane holds (`ChapterPaneMetrics.columns(paneWidth:)`). The chapter being read sits on the
/// accent wash, so "where was I" is found at a glance; a chapter with a highlight, note or
/// bookmark carries a thin ring in the colours of its highlights (`ChapterRing`).
///
/// It has no scroll view of its own: the pane scrolls it, and the book's name and icons stay above. The grid's height is exact (it follows
/// from the chapter count and the column count) and its cells are built lazily.
///
/// Keyboard: the grid is one Tab stop. Inside it a cursor (the searched chapter, else the chapter
/// being read, else 1, until the arrows move it) carries the system focus ring, drawn on the
/// cursor's cell by giving the grid's focus-effect shape that cell's rectangle; Return or Space
/// opens the cursor's chapter. ↑ and ↓ move a whole row of the current column count. A searched
/// chapter is ringed in the accent while the keyboard is elsewhere (in the toolbar's field), as
/// the cursor's ring would ring it.
struct ChapterGridView: View {
    let bookName: String
    let chapterCount: Int
    let currentChapter: Int?
    let marks: [Int: ChapterMarks]
    let ringedChapter: Int?
    /// The cell, numeral and ring sizes at the reader's page size.
    let metrics: ChapterPaneMetrics
    /// How many cells sit across: the pane's width decides it.
    let columnCount: Int
    let onSelect: (Int) -> Void
    let onRevealChapter: ((Int) -> Void)?
    /// Each change asks the grid to take the keyboard (Return or Space on the contents).
    let focusRequests: Int

    @FocusState private var isFocused: Bool
    @State private var cursor: Int?

    /// - Parameters:
    ///   - bookName: names the cells' scroll identities (`cellID(bookName:chapter:)`).
    ///   - onRevealChapter: called when the cursor moves or the grid takes focus, so a scroll view
    ///     around the grid can bring that cell (`cellID(bookName:chapter:)`) into view.
    init(
        bookName: String,
        chapterCount: Int,
        currentChapter: Int?,
        marks: [Int: ChapterMarks] = [:],
        ringedChapter: Int? = nil,
        metrics: ChapterPaneMetrics,
        columnCount: Int,
        onRevealChapter: ((Int) -> Void)? = nil,
        focusRequests: Int = 0,
        onSelect: @escaping (Int) -> Void
    ) {
        self.bookName = bookName
        self.chapterCount = chapterCount
        self.currentChapter = currentChapter
        self.marks = marks
        self.ringedChapter = ringedChapter
        self.metrics = metrics
        self.columnCount = columnCount
        self.onRevealChapter = onRevealChapter
        self.focusRequests = focusRequests
        self.onSelect = onSelect
    }

    /// The scroll identity of a chapter's cell.
    static func cellID(bookName: String, chapter: Int) -> String {
        "\(bookName)#\(chapter)"
    }

    /// The rows `chapters` cells make at `columns` across; a book has at least one.
    nonisolated static func rowCount(chapters: Int, columns: Int) -> Int {
        let columns = max(columns, 1)
        return (max(chapters, 1) + columns - 1) / columns
    }

    /// A chapter's cell rectangle in the grid's own space.
    nonisolated static func cursorRect(chapter: Int, columns: Int, metrics: ChapterPaneMetrics) -> CGRect {
        let columns = max(columns, 1)
        let index = max(chapter, 1) - 1
        return CGRect(
            x: CGFloat(index % columns) * metrics.columnStep,
            y: CGFloat(index / columns) * (metrics.cellHeight + AppSpacing.xs),
            width: metrics.cellWidth,
            height: metrics.cellHeight)
    }

    /// Where an arrow takes the cursor: ← and → a chapter (running on to the next or previous
    /// row), ↑ and ↓ a row of `columns`. Nil when the move leaves the grid.
    nonisolated static func target(from chapter: Int, moving move: ChapterGridMove, columns: Int, chapterCount: Int) -> Int? {
        let columns = max(columns, 1)
        let target = switch move {
        case .left: chapter - 1
        case .right: chapter + 1
        case .up: chapter - columns
        case .down: chapter + columns
        }
        return target >= 1 && target <= chapterCount ? target : nil
    }

    /// The cell to bring into view when the cells move (a new column count or size): the cursor's,
    /// while the grid has the keyboard; otherwise the pane's scroll is left where it is.
    nonisolated static func chapterToRevealOnRelayout(gridFocused: Bool, cursor: Int) -> Int? {
        gridFocused ? cursor : nil
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(metrics.cellWidth), spacing: AppSpacing.xs), count: max(columnCount, 1))
    }

    private var gridWidth: CGFloat {
        let columns = CGFloat(max(columnCount, 1))
        return columns * metrics.cellWidth + (columns - 1) * AppSpacing.xs
    }

    private var gridHeight: CGFloat {
        let rows = CGFloat(Self.rowCount(chapters: chapterCount, columns: columnCount))
        return rows * metrics.cellHeight + (rows - 1) * AppSpacing.xs
    }

    private var cursorChapter: Int {
        min(cursor ?? ringedChapter ?? currentChapter ?? 1, max(chapterCount, 1))
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            LazyVGrid(columns: columns, alignment: .center, spacing: AppSpacing.xs) {
                ForEach(Array(1...max(chapterCount, 1)), id: \.self) { chapter in
                    if chapter <= chapterCount {
                        chapterButton(chapter)
                    }
                }
            }
            .frame(width: gridWidth, height: gridHeight, alignment: .top)
            // A new column count is a cut, never an animated reflow.
            .animation(nil, value: columnCount)
            #if os(macOS)
            .contentShape(.focusEffect, CellShape(rect: Self.cursorRect(chapter: cursorChapter, columns: columnCount, metrics: metrics)))
            #endif
            .focusable()
            .focused($isFocused)
            // Tabbing into a tall grid (Psalms) brings the cursor's cell, and its ring, into view.
            .onChange(of: isFocused) { _, focused in
                if focused { onRevealChapter?(cursorChapter) }
            }
            .onChange(of: focusRequests) { _, _ in isFocused = true }
            // ⌘+, ⌘− or the divider moves the cells; the cursor's cell stays in view, as a cut.
            .onChange(of: columnCount) { _, _ in revealCursorAfterRelayout() }
            .onChange(of: metrics) { _, _ in revealCursorAfterRelayout() }
            // A new search starts the cursor again at its chapter; a grid made with the ring already
            // set (a reference pasted whole) brings it into view too.
            .onChange(of: ringedChapter, initial: true) { _, chapter in
                cursor = nil
                if let chapter { onRevealChapter?(chapter) }
            }
            .accessibilityElement(children: .contain)
            .onKeyPress(.leftArrow) { moveCursor(.left) }
            .onKeyPress(.rightArrow) { moveCursor(.right) }
            .onKeyPress(.upArrow) { moveCursor(.up) }
            .onKeyPress(.downArrow) { moveCursor(.down) }
            .onKeyPress(keys: [.return, .space]) { _ in
                guard isFocused else { return .ignored }
                onSelect(cursorChapter)
                return .handled
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func revealCursorAfterRelayout() {
        guard let chapter = Self.chapterToRevealOnRelayout(gridFocused: isFocused, cursor: cursorChapter) else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { onRevealChapter?(chapter) }
    }

    private func moveCursor(_ move: ChapterGridMove) -> KeyPress.Result {
        guard isFocused,
              let target = Self.target(from: cursorChapter, moving: move, columns: columnCount, chapterCount: chapterCount)
        else { return .ignored }
        cursor = target
        onRevealChapter?(target)
        return .handled
    }

    /// A cell is a plain view that acts as a button: the grid, not the cell, takes keyboard focus,
    /// so a book is one Tab stop however many chapters it has.
    private func chapterButton(_ chapter: Int) -> some View {
        ChapterCell(
            chapter: chapter,
            isCurrent: chapter == currentChapter,
            marks: marks[chapter],
            size: .pane(metrics),
            isRinged: !isFocused && chapter == ringedChapter,
            accessibilityName: "Chapter \(chapter)"
        ) { onSelect(chapter) }
        .id(Self.cellID(bookName: bookName, chapter: chapter))
    }
}

/// One chapter's cell: its numeral in the page's serif, on the accent wash when it is the chapter
/// being read, with a thin ring in the colours of its highlights when it has a highlight, note or
/// bookmark. The Mac's book pane and the phone's Library draw it. A searched chapter (the Mac's
/// "rom 8") is ringed in the accent outside the cell, as the keyboard's focus ring would ring it.
struct ChapterCell: View {
    /// `.grid` is the phone's: 56 by 40 at `.title3`. `.pane` is the Mac's book pane's, at the
    /// reader's page size: 52 by 40 at 18, its numerals at the reader size.
    enum Size: Equatable {
        case grid
        case pane(ChapterPaneMetrics)
    }

    @Environment(\.pageFace) private var pageFace
    @ScaledMetric(relativeTo: .title3) private var gridNumeralSize: CGFloat = PageFace.baseSize(.title3)
    let chapter: Int
    let isCurrent: Bool
    /// Nil: not marked. Empty colours: marked, with no colour.
    let marks: ChapterMarks?
    var size: Size = .grid
    /// The chapter a typed reference names, while the keyboard is in the search field.
    var isRinged = false
    /// What VoiceOver calls it: "Chapter 15" under a book's name.
    let accessibilityName: String
    let onSelect: () -> Void

    @ScaledMetric(relativeTo: .title3) private var gridWidth: CGFloat = 56
    @ScaledMetric(relativeTo: .title3) private var gridHeight: CGFloat = 40
    @ScaledMetric(relativeTo: .callout) private var gridSearchRingWidth: CGFloat = 3

    private var isMarked: Bool { marks != nil }

    var body: some View {
        let cellShape = RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
        Text(chapter, format: .number)
            .font(numeralFont)
            .foregroundStyle(isCurrent ? Color.inkPrimary : Color.inkSecondary)
            .frame(width: cellSize.width, height: cellSize.height)
            .background(isCurrent ? Color.accentWash : Color.clear, in: cellShape)
            .overlay {
                if let marks { ChapterRingView(marks: marks, cornerRadius: AppRadius.lg, lineWidth: ringLineWidth) }
            }
            .overlay {
                if isRinged {
                    RoundedRectangle(cornerRadius: AppRadius.lg + searchRingWidth, style: .continuous)
                        .strokeBorder(Color.accent, lineWidth: searchRingWidth)
                        .padding(-searchRingWidth)
                }
            }
            .contentShape(cellShape)
            .onTapGesture(perform: onSelect)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityName)
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { onSelect() }
    }

    private var numeralFont: Font {
        switch size {
        case .grid: pageFace.numeralFont(size: gridNumeralSize)
        case .pane(let metrics): pageFace.paneNumeralFont(size: metrics.numeralSize)
        }
    }

    private var cellSize: CGSize {
        switch size {
        case .grid: CGSize(width: gridWidth, height: gridHeight)
        case .pane(let metrics): CGSize(width: metrics.cellWidth, height: metrics.cellHeight)
        }
    }

    private var searchRingWidth: CGFloat {
        switch size {
        case .grid: gridSearchRingWidth
        case .pane(let metrics): metrics.searchRingWidth
        }
    }

    /// Nil keeps the ring's own scaled line.
    private var ringLineWidth: CGFloat? {
        switch size {
        case .grid: nil
        case .pane(let metrics): metrics.ringLineWidth
        }
    }

    private var accessibilityValue: String {
        [isCurrent ? "Where you left off" : nil, isMarked ? "Marked" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

/// The cursor cell's rounded rectangle, wherever it sits in the grid: the grid's focus-effect
/// shape, so the system ring is drawn on one cell.
private struct CellShape: Shape {
    let rect: CGRect

    func path(in _: CGRect) -> Path {
        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous).path(in: rect)
    }
}
