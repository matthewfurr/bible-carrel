import Foundation

/// One thing the review marks for the reader to look at.
public struct PlanFlag: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case unknownBook, unreadable, missingChapter, noSuchDate, dateOutOfOrder, numberOutOfSequence }

    public let kind: Kind
    public let weekID: UUID
    /// The line it marks, for the three kinds a line can have.
    public let readingID: UUID?
    /// The passage's place in its line, for a chapter the book lacks: one line can name the same one twice.
    public let passageIndex: Int?
    /// With its week, for the list to check: "Week 3: “Hezekiah 3” names a book Bible Carrel does not know."
    public let sentence: String
    /// Without its week, for the mark under its own line: "“Hezekiah 3” names a book Bible Carrel does not know."
    public let lineSentence: String

    public init(kind: Kind, weekID: UUID, readingID: UUID?, passageIndex: Int? = nil, sentence: String, lineSentence: String? = nil) {
        self.kind = kind
        self.weekID = weekID
        self.readingID = readingID
        self.passageIndex = passageIndex
        self.sentence = sentence
        self.lineSentence = lineSentence ?? sentence
    }

    /// Unique within one review.
    public var id: String { "\(weekID.uuidString)/\(readingID?.uuidString ?? "-")/\(passageIndex.map(String.init) ?? "-")/\(sentence)" }
}

public enum PlanReview {
    /// In week order, a week's own before its lines'. `chapterCounts`: each book's chapters in the translation being read; a book it lacks is not flagged.
    /// `parse` reads one line (the editor keeps each line's reading by its text, so a key reads one line).
    public static func flags(_ draft: PlanDraft, chapterCounts: [String: Int],
                             parse: (String) -> Result<PlanReadingText.Parsed, PlanReadingText.Failure> = PlanReadingText.parse) -> [PlanFlag] {
        var flags: [PlanFlag] = []
        let placed = draft.firstYear.map { PlanYears.place(draft.weeks.map(\.monthDay), firstYear: $0) }
        var lastDated: PlanDraft.Week?
        for (index, week) in draft.weeks.enumerated() {
            func flag(_ kind: PlanFlag.Kind, _ sentence: String, reading: UUID? = nil, passage: Int? = nil) {
                flags.append(PlanFlag(kind: kind, weekID: week.id, readingID: reading, passageIndex: passage,
                                      sentence: "Week \(week.number): \(sentence)", lineSentence: sentence))
            }
            if index > 0, week.number != draft.weeks[index - 1].number + 1 {
                flag(.numberOutOfSequence, "numbered \(week.number) after \(draft.weeks[index - 1].number).")
            }
            if let day = week.day {
                if let lastDated, let before = lastDated.day, day <= before {
                    flag(.dateOutOfOrder, "its date is not after week \(lastDated.number)'s.")
                }
                lastDated = week
            }
            if let monthDay = week.monthDay, week.day == nil, let year = placed?.years[index] {
                flag(.noSuchDate, "\(PlanYears.abbreviation(ofMonth: monthDay.month)) \(monthDay.day) is not a date in \(year). Set the date, or change the year the plan starts.")
            }
            for reading in week.readings where !PlanDraft.isBlank(reading.text) {
                let line = reading.text.trimmingCharacters(in: .whitespacesAndNewlines)
                switch parse(reading.text) {
                case .failure(.unknownBook):
                    flag(.unknownBook, "“\(line)” names a book Bible Carrel does not know.", reading: reading.id)
                case .failure:
                    flag(.unreadable, "“\(line)” cannot be read.", reading: reading.id)
                case let .success(parsed):
                    for (place, passage) in parsed.passages.enumerated() {
                        guard let count = chapterCounts[passage.book], passage.endChapter > count else { continue }
                        let name = BookCatalog.book(code: passage.book)?.name ?? passage.book
                        flag(.missingChapter, "\(name) has no chapter \(passage.endChapter).", reading: reading.id, passage: place)
                    }
                }
            }
        }
        return flags
    }
}
