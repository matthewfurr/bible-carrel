#if os(macOS)
import AppKit
import ScriptureData

/// Draws a bookmark glyph in the left gutter of each bookmarked verse, in the accent. A passive
/// overlay on the text view: flipped like it, never hit-tested. Each glyph is also an
/// accessibility element ("Bookmark, chapter 3 verse 9"), which the text view lists among its children.
public final class MarkupGutterView: NSView {
    public static let symbolName = "bookmark.fill"
    public static let glyphSize: CGFloat = 16

    public var glyphRects: [NSRect] = [] {
        didSet { if glyphRects != oldValue { needsDisplay = true } }
    }
    /// The verse each rect in `glyphRects` marks, in the same order (its span's first verse).
    public var glyphVerses: [VerseLocation] = []

    private let image: NSImage? = {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: Palette.accent.platformColor))
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: "Bookmark")?.withSymbolConfiguration(configuration)
    }()

    public override var isFlipped: Bool { true }
    public override func hitTest(_ point: NSPoint) -> NSView? { nil }

    public override func draw(_ dirtyRect: NSRect) {
        guard let image else { return }
        for rect in glyphRects where rect.intersects(dirtyRect) {
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }

    /// One image element per bookmark, framed in `parent`'s coordinates (the text view, which
    /// shares this view's bounds).
    func accessibilityElements(parent: NSView) -> [NSAccessibilityElement] {
        zip(glyphRects, glyphVerses).map { rect, verse in
            let element = NSAccessibilityElement()
            element.setAccessibilityRole(.image)
            element.setAccessibilityLabel("Bookmark, chapter \(verse.chapter) verse \(verse.verse)")
            element.setAccessibilityParent(parent)
            element.setAccessibilityFrameInParentSpace(rect)
            return element
        }
    }
}
#endif
