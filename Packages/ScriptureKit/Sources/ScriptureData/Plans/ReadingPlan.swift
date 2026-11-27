import Foundation

public struct PlanPassage: Hashable, Sendable {
    /// A `BookCatalog` code.
    public let book: String
    /// Equal for one chapter, and for verses of one chapter.
    public let chapter: Int, endChapter: Int
    /// Verses of `chapter`; nil for whole chapters.
    public let verse: Int?, endVerse: Int?

    public init(book: String, chapter: Int, endChapter: Int? = nil, verse: Int? = nil, endVerse: Int? = nil) {
        self.book = book
        self.chapter = chapter
        self.endChapter = endChapter ?? chapter
        self.verse = verse
        self.endVerse = endVerse
    }

    public var startLocation: ChapterLocation { ChapterLocation(book: book, chapter: chapter) }

    private var bookName: String { BookCatalog.book(code: book)?.name ?? book }

    /// `"Esther 7–8"`, `"Psalms 84"`, `"Psalms 119:1–16"`.
    public var displayString: String { text(dash: "–") }

    /// `"Esther 7 to 8"`, `"Psalms 119, verses 1 to 16"`.
    public var spokenString: String {
        if let verse {
            if let endVerse { return "\(bookName) \(chapter), verses \(verse) to \(endVerse)" }
            return "\(bookName) \(chapter), verse \(verse)"
        }
        if endChapter != chapter { return "\(bookName) \(chapter) to \(endChapter)" }
        return "\(bookName) \(chapter)"
    }

    /// `"Esther 7-8"`, `"Psalms 119:1-16"`.
    public var editString: String { text(dash: "-") }

    private func text(dash: String) -> String {
        if let verse {
            if let endVerse { return "\(bookName) \(chapter):\(verse)\(dash)\(endVerse)" }
            return "\(bookName) \(chapter):\(verse)"
        }
        if endChapter != chapter { return "\(bookName) \(chapter)\(dash)\(endChapter)" }
        return "\(bookName) \(chapter)"
    }
}

public struct PlanReading: Identifiable, Hashable, Sendable {
    /// Its own identity: a tick follows it.
    public let id: UUID
    /// "NT Focus", "NT Focus Week", "Holidays".
    public var label: String?
    public var passages: [PlanPassage]

    public init(id: UUID, label: String?, passages: [PlanPassage]) {
        self.id = id
        self.label = label
        self.passages = passages
    }
}

public struct PlanWeek: Hashable, Sendable {
    public var number: Int
    /// The meeting date.
    public var day: PlanDay?
    /// "Leader Dinner", "OFF".
    public var label: String?
    public var readings: [PlanReading]

    public init(number: Int, day: PlanDay?, label: String?, readings: [PlanReading]) {
        self.number = number
        self.day = day
        self.label = label
        self.readings = readings
    }
}

public struct PlanProgress: Equatable, Sendable {
    public let read: Int, total: Int

    public init(read: Int, total: Int) {
        self.read = read
        self.total = total
    }

    /// 0 when total is 0.
    public var fraction: Double { total > 0 ? Double(read) / Double(total) : 0 }

    /// "done", "3 of 5", nil with nothing read.
    public var label: String? {
        if total > 0, read >= total { return "done" }
        if read > 0 { return "\(read) of \(total)" }
        return nil
    }
}

public struct ReadingPlan: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var createdAt: Date, modifiedAt: Date
    public var weeks: [PlanWeek]
    /// false: stored by a version this build cannot read; `weeks` is empty.
    public var isReadable: Bool

    public init(id: UUID, title: String, createdAt: Date, modifiedAt: Date, weeks: [PlanWeek], isReadable: Bool = true) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.weeks = weeks
        self.isReadable = isReadable
    }

    public var readingIDs: Set<UUID> {
        Set(weeks.flatMap { $0.readings.map(\.id) })
    }

    /// Of every reading; a tick whose reading the plan lacks is not counted.
    public func progress(ticked: Set<UUID>) -> PlanProgress {
        let ids = readingIDs
        return PlanProgress(read: ids.intersection(ticked).count, total: ids.count)
    }

    public func progress(ofWeek index: Int, ticked: Set<UUID>) -> PlanProgress {
        guard weeks.indices.contains(index) else { return PlanProgress(read: 0, total: 0) }
        let ids = Set(weeks[index].readings.map(\.id))
        return PlanProgress(read: ids.intersection(ticked).count, total: ids.count)
    }
}
