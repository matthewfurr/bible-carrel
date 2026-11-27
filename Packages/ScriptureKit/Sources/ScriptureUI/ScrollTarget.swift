import Foundation

/// A request to scroll the reader to a verse of a chapter in the book being read. Each request
/// carries a fresh token so that asking for the same verse twice still scrolls. A target with
/// `atEnd` lands with the chapter's foot at the bottom of the page (a chapter turned back to).
public struct ScrollTarget: Equatable, Sendable {
    public let chapter: Int
    public let verse: Int
    public let atEnd: Bool
    public let token: UUID

    public init(chapter: Int, verse: Int, atEnd: Bool = false) {
        self.chapter = chapter
        self.verse = verse
        self.atEnd = atEnd
        self.token = UUID()
    }
}
