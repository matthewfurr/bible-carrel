#if os(macOS)
import AppKit
#endif
import CoreText
import ScriptureData
import SwiftUI

/// The contents of the Mac's front page (spec 4.1, 4.4): every book under its Testament and group,
/// in as many columns as the width holds at a scaled 180 pt each, scrolling on its own when they do
/// not fit. A click chooses a book and a double-click opens it.
///
/// Keyboard: the contents are one Tab stop. The chosen book carries the system focus ring, drawn
/// on its wash by giving the stop's focus-effect shape that book's rounded rectangle (as the
/// chapter grid does for its cursor); the arrows choose down a column and across columns.
public struct ContentsPageView: View {
    let page: ContentsPage
    let markedBooks: Set<String>
    let readerSize: CGFloat
    let onChoose: (String) -> Void
    let onOpen: (String) -> Void

    @Environment(\.pageFace) private var pageFace
    @FocusState private var isFocused: Bool
    /// The chosen book's rectangle in the contents' own space: the focus ring's shape.
    @State private var chosenRect: CGRect = .zero
    #if os(macOS)
    /// Whether the window is key. The contents lose the keyboard when it stops being key and are
    /// given it back when it is key again, if they held it then (`restoresFocus`).
    @Environment(\.controlActiveState) private var activeState
    /// True while the window is not key and the contents held the keyboard as it stopped being key.
    @State private var restoresFocus = false
    #endif

    /// Nonisolated, so the geometry closures (which are Sendable) can name it.
    private nonisolated static let coordinateSpace = "contents"

    public init(page: ContentsPage, markedBooks: Set<String>, readerSize: CGFloat, onChoose: @escaping (String) -> Void, onOpen: @escaping (String) -> Void) {
        self.page = page
        self.markedBooks = markedBooks
        self.readerSize = readerSize
        self.onChoose = onChoose
        self.onOpen = onOpen
    }

    private var metrics: ContentsMetrics { ContentsMetrics(readerSize: readerSize) }

    public var body: some View {
        let metrics = metrics
        let widest = BookNameMeasure.shared.widest(of: page.bookNames, face: pageFace, size: metrics.nameSize)
        let minimumColumnWidth = metrics.columnWidth(widestName: widest)
        return GeometryReader { geometry in
            let width = max(0, geometry.size.width - 2 * AppSpacing.lg)
            let count = ContentsPage.columnCount(width: width, minimumColumnWidth: minimumColumnWidth)
            let layout = page.layout(columns: count)
            ScrollViewReader { proxy in
                ScrollView {
                    contents(layout, columnWidth: Self.columnWidth(for: layout, columns: count, width: width))
                        .padding(AppSpacing.lg)
                }
                // The arrows and the search can choose a book out of view (at a large text size).
                .onChange(of: page.chosenBookID) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
                // A change of the reader's size reflows the page (a cut, no animation) and keeps the
                // chosen book in view. Apart from the opening task below: it never moves the keyboard.
                .onChange(of: readerSize) {
                    Task {
                        await Task.yield()
                        if let id = page.chosenBookID { proxy.scrollTo(id) }
                    }
                }
                // The page opens on the chosen book, which may sit below the fold (the Apocrypha's
                // Tobit, or anything at a large text size); scrolled once the rows are laid out.
                .task {
                    await Task.yield()
                    if let id = page.chosenBookID { proxy.scrollTo(id) }
                    #if os(macOS)
                    // The contents take the keyboard as the page opens (after ⇧⌘H too), though
                    // the "This week" band's buttons come before them in the Tab order; a field
                    // that holds the keyboard keeps it.
                    if (NSApp.keyWindow?.firstResponder as? NSText) == nil { isFocused = true }
                    #endif
                }
            }
        }
    }

    /// One width for every column, so the bands' columns line up: the width less the gaps, shared.
    /// Testaments side by side are `lg` apart and a Testament's columns `md`.
    private static func columnWidth(for layout: ContentsPage.Layout, columns: Int, width: CGFloat) -> CGFloat {
        let sideBySide = layout.bands.contains { $0.count > 1 }
        let gaps = CGFloat(columns - 1) * AppSpacing.md + (sideBySide ? AppSpacing.lg - AppSpacing.md : 0)
        return max(0, (width - gaps) / CGFloat(columns))
    }

    private func contents(_ layout: ContentsPage.Layout, columnWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            ForEach(Array(layout.bands.enumerated()), id: \.offset) { _, band in
                HStack(alignment: .top, spacing: AppSpacing.lg) {
                    ForEach(band, id: \.testament.id) { section in
                        testament(section, columnWidth: columnWidth, arrows: layout)
                    }
                }
            }
        }
        .coordinateSpace(.named(Self.coordinateSpace))
        #if os(macOS)
        .contentShape(.focusEffect, ChosenShape(rect: chosenRect))
        #endif
        .focusable()
        .focused($isFocused)
        .accessibilityElement(children: .contain)
        .onKeyPress(.upArrow) { move(.up, in: layout) }
        .onKeyPress(.downArrow) { move(.down, in: layout) }
        .onKeyPress(.leftArrow) { move(.left, in: layout) }
        .onKeyPress(.rightArrow) { move(.right, in: layout) }
        #if os(macOS)
        // The window coming back to the front gives the contents the keyboard again when they held
        // it as it went, and no field has taken it since (a click into the toolbar's field brings
        // the window back with that field).
        .onChange(of: isFocused) { _, focused in
            if focused { restoresFocus = false } else if activeState != .key { restoresFocus = true }
        }
        .onChange(of: activeState) { _, state in
            if state != .key {
                if isFocused { restoresFocus = true }
            } else if restoresFocus {
                restoresFocus = false
                if (NSApp.keyWindow?.firstResponder as? NSText) == nil { isFocused = true }
            }
        }
        #endif
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func move(_ move: ContentsPage.Move, in layout: ContentsPage.Layout) -> KeyPress.Result {
        guard isFocused, let chosen = page.chosenBookID else { return .ignored }
        guard let next = page.bookID(moving: move, from: chosen, in: layout) else { return .handled }
        onChoose(next)
        return .handled
    }

    /// A Testament's title and count over a rule, then its columns.
    private func testament(_ section: ContentsPage.Section, columnWidth: CGFloat, arrows: ContentsPage.Layout) -> some View {
        let columns = section.columns.count
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(section.testament.title)
                        .font(Font(pageFace.font(size: metrics.testamentTitleSize) as CTFont))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: AppSpacing.xs)
                    Text(section.testament.countLabel)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
                HairlineRule()
            }
            HStack(alignment: .top, spacing: AppSpacing.md) {
                ForEach(Array(section.columns.enumerated()), id: \.offset) { _, column in
                    self.column(column)
                        .frame(width: columnWidth, alignment: .leading)
                }
            }
        }
        .frame(width: CGFloat(columns) * columnWidth + CGFloat(max(columns - 1, 0)) * AppSpacing.md, alignment: .leading)
    }

    private func column(_ rows: [ContentsPage.Row]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                switch row {
                case .group(let group):
                    // The shared label carries no padding: `sm` above it, except at a column's head.
                    GroupLabel(group.title, size: metrics.groupLabelSize)
                        .padding(.top, index == 0 ? 0 : AppSpacing.sm)
                        .padding(.bottom, AppSpacing.xxs)
                case .book(let entry):
                    book(entry)
                }
            }
        }
    }

    /// A book's name in the page face, on the wash when chosen, and a dot after it when marked.
    /// The wash reaches `xs` beyond the name on each side, so the name itself lines up with the
    /// group's label and the Testament's title above it.
    private func book(_ entry: TranslationBook) -> some View {
        let id = entry.book.id
        let isChosen = page.chosenBookID == id
        let isMarked = markedBooks.contains(id)
        let shape = RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
        let metrics = metrics
        return HStack(spacing: metrics.dotGap) {
            Text(entry.book.name)
                .font(Font(pageFace.font(size: metrics.nameSize) as CTFont))
                .foregroundStyle(page.isDimmed(id) ? Color.inkTertiary : Color.inkPrimary)
                .lineLimit(1)
            if isMarked {
                Circle()
                    .fill(Color.inkTertiary)
                    .frame(width: metrics.markDot, height: metrics.markDot)
            }
        }
        .padding(.vertical, metrics.rowVerticalPadding)
        .padding(.horizontal, metrics.washInset)
        .background {
            if isChosen {
                shape.fill(Color.accentWash)
                    .onGeometryChange(for: CGRect.self) { geometry in
                        geometry.frame(in: .named(Self.coordinateSpace))
                    } action: { rect in
                        chosenRect = rect
                    }
            }
        }
        .padding(.leading, -metrics.washInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { onChoose(id) }
        // Simultaneous, so the first click of a double-click still chooses at once.
        .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen(id) })
        .id(id)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.book.name)
        .accessibilityValue(isMarked ? "Marked" : "")
        .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onChoose(id) }
        .accessibilityAction(named: "Open") { onOpen(id) }
    }
}

/// The chosen book's rounded rectangle, wherever it sits in the contents: the contents' focus-effect
/// shape, so the system ring is drawn on one book.
private struct ChosenShape: Shape {
    let rect: CGRect

    func path(in _: CGRect) -> Path {
        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous).path(in: rect)
    }
}
