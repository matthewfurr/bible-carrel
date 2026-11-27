import CoreGraphics
import Foundation

/// The chapter pane's width as the reader sets it with the divider (spec 5.1 and 6), kept in
/// `UserDefaults` on this Mac only: never synced. Written when a drag ends or VoiceOver adjusts
/// it and the pane's width changed, removed by a double-click; never on opening or when the size
/// or the window changes. The stored width is kept even where the limits show the pane narrower
/// or wider than it.
struct PaneWidth {
    static let key = "frontPagePaneWidth"

    private let defaults: UserDefaults
    /// The width the reader chose, in points; nil while the pane follows its narrowest.
    private(set) var stored: CGFloat?
    /// The shown width when the drag began, and the width the drag has reached since.
    private var dragStart: CGFloat?
    private var dragged: CGFloat?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        let value = defaults.double(forKey: Self.key)
        stored = value > 0 ? CGFloat(value) : nil
    }

    var isDragging: Bool { dragStart != nil }

    func shown(_ metrics: ChapterPaneMetrics, frontPageWidth: CGFloat) -> CGFloat {
        metrics.shownWidth(stored: dragged ?? stored, frontPageWidth: frontPageWidth)
    }

    /// The pane follows the divider: dragging it left (a negative translation) widens the pane.
    /// Nothing is written until the drag ends.
    mutating func drag(translation: CGFloat, _ metrics: ChapterPaneMetrics, frontPageWidth: CGFloat) {
        let start = dragStart ?? shown(metrics, frontPageWidth: frontPageWidth)
        dragStart = start
        dragged = start - translation
    }

    /// Keeps the width the pane shows as the drag ends, within its limits; a drag that leaves the
    /// pane as wide as it began stores nothing, so the pane goes on following the size.
    mutating func endDrag(_ metrics: ChapterPaneMetrics, frontPageWidth: CGFloat) {
        guard let start = dragStart else { return }
        let width = shown(metrics, frontPageWidth: frontPageWidth)
        dragStart = nil
        dragged = nil
        if width != start { store(width) }
    }

    /// A drag the system cancels (no end): the pane goes back to the width it showed before, and
    /// nothing is written.
    mutating func cancelDrag() {
        dragStart = nil
        dragged = nil
    }

    /// VoiceOver's increment and decrement: one column wider or narrower, within the limits. A step
    /// at a limit changes nothing and stores nothing, so a kept wider width stays kept.
    mutating func adjust(byColumns count: Int, _ metrics: ChapterPaneMetrics, frontPageWidth: CGFloat) {
        let current = shown(metrics, frontPageWidth: frontPageWidth)
        let width = metrics.shownWidth(stored: current + CGFloat(count) * metrics.columnStep, frontPageWidth: frontPageWidth)
        if width != current { store(width) }
    }

    /// The double-click: the pane goes back to its narrowest and follows it from then on.
    mutating func reset() {
        dragStart = nil
        dragged = nil
        stored = nil
        defaults.removeObject(forKey: Self.key)
    }

    private mutating func store(_ width: CGFloat) {
        stored = width
        defaults.set(Double(width), forKey: Self.key)
    }
}
