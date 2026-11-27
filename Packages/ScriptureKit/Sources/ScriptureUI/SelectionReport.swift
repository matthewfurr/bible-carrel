import Foundation

/// What the text view tells the markup model when the selection changes: the resolved verse
/// selection, the raw character range it came from, the highlights it touches, and the one it
/// lies inside (the innermost when nested). A caret inside a highlight reports that highlight's
/// own range as the selection, so the context menu can act on it.
public struct SelectionReport: Equatable, Sendable {
    public let selection: TextSelection
    public let range: NSRange
    public let highlightIDs: [UUID]
    public let primaryHighlightID: UUID?

    public init(selection: TextSelection, range: NSRange, highlightIDs: [UUID], primaryHighlightID: UUID? = nil) {
        self.selection = selection
        self.range = range
        self.highlightIDs = highlightIDs
        self.primaryHighlightID = primaryHighlightID
    }
}
