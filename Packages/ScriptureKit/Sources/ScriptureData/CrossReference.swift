/// One cross-reference link, read for a translation: a verse and the passage it names.
public struct CrossReference: Hashable, Sendable {
    public let source: VerseLocation
    public let target: VerseLocation, targetEnd: VerseLocation // the same verse for a single one
    public let votes: Int
    /// The row's own verse in the translation asked for: the target's first verse for a link
    /// out, the source for a link in. Nil when the translation lacks it.
    public let openingText: String?
    /// For a target that runs past its first chapter: that chapter's last verse in the
    /// translation asked for (nil when it lacks the chapter). Nil for every other link.
    public let chapterEnd: Int?

    public init(source: VerseLocation, target: VerseLocation, targetEnd: VerseLocation, votes: Int, openingText: String?, chapterEnd: Int?) {
        self.source = source
        self.target = target
        self.targetEnd = targetEnd
        self.votes = votes
        self.openingText = openingText
        self.chapterEnd = chapterEnd
    }
}
