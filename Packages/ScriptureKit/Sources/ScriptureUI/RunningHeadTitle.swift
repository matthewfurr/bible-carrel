import Foundation
import ScriptureData

/// What a running head shows, for the Mac's pinned strip and the phone's bar title alike: the
/// open chapter, named in the page style's voice ("JOHN · 3"), what VoiceOver reads
/// ("John, chapter 3"), the head's opacity and the chapter's progress.
public struct RunningHeadTitle: Equatable, Sendable {
    public let chapter: Int
    public let text: String
    public let spokenLabel: String
    public let opacity: Double
    public let progress: Double

    public init(chapter: Int, text: String, spokenLabel: String, opacity: Double, progress: Double) {
        self.chapter = chapter
        self.text = text
        self.spokenLabel = spokenLabel
        self.opacity = opacity
        self.progress = progress
    }

    /// The head for the open `chapter` of `book` (its code) in `style`, from the text's report on
    /// it. Before that report (none yet, or one left from the chapter shown before) it is hidden,
    /// as over every page's opening at its top, with no progress.
    public init(style: PageStyle, book: String, head: RunningHeadState?, chapter: Int) {
        let head = head.flatMap { $0.chapter == chapter ? $0 : nil }
        let bookName = BookCatalog.book(code: book)?.name ?? book
        self.init(chapter: chapter, text: style.runningHead(bookName: bookName, chapter: chapter),
                  spokenLabel: Self.spokenLabel(bookName: bookName, chapter: chapter),
                  opacity: head?.headOpacity ?? 0, progress: head?.progress ?? 0)
    }

    /// "John, chapter 3": the book named and the chapter spelled out, whatever the style's voice.
    public static func spokenLabel(bookName: String, chapter: Int) -> String {
        "\(bookName), chapter \(chapter)"
    }
}
