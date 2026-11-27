import Foundation
import ScriptureData
import SwiftData

/// A whole-verse bookmark, shown as a glyph in the reader's gutter.
@Model
public final class Bookmark {
    public var uuid: UUID = UUID()
    public var book: String = ""
    public var chapter: Int = 0
    public var verse: Int = 0
    public var createdAt: Date = Date()
    public var label: String?

    public init(book: String, chapter: Int, verse: Int, label: String? = nil) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.label = label
    }

    public var location: VerseLocation { VerseLocation(book: book, chapter: chapter, verse: verse) }
}
