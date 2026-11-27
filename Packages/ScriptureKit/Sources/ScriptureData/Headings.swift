/// A section heading printed above a verse (BSB headings, shown beside any translation that has the verse).
public struct SectionHeading: Hashable, Sendable {
    public let text: String
    public let level: Int

    public init(text: String, level: Int) {
        self.text = text
        self.level = level
    }
}

/// A book's title block: the name and an optional long traditional title.
public struct BookTitle: Hashable, Sendable {
    public let title: String
    public let subtitle: String?

    public init(title: String, subtitle: String?) {
        self.title = title
        self.subtitle = subtitle
    }
}
