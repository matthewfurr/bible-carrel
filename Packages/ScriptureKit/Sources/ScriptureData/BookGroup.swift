/// The headings the contents page sets books under: five in the Old Testament, four in the New, and the Apocrypha as one.
public enum BookGroup: String, CaseIterable, Sendable {
    case law, history, poetryAndWisdom, majorProphets, minorProphets
    case gospelsAndActs, paulsLetters, generalLetters, revelation
    case apocrypha

    public var title: String {
        switch self {
        case .law: "Law"
        case .history: "History"
        case .poetryAndWisdom: "Poetry & Wisdom"
        case .majorProphets: "Major Prophets"
        case .minorProphets: "Minor Prophets"
        case .gospelsAndActs: "Gospels & Acts"
        case .paulsLetters: "Paul's Letters"
        case .generalLetters: "General Letters"
        case .revelation: "Revelation"
        case .apocrypha: "Apocrypha"
        }
    }

    public var canon: Canon {
        switch self {
        case .law, .history, .poetryAndWisdom, .majorProphets, .minorProphets: .oldTestament
        case .gospelsAndActs, .paulsLetters, .generalLetters, .revelation: .newTestament
        case .apocrypha: .apocrypha
        }
    }

    /// The group of `book`, by its place in the catalog (Genesis is 1, Revelation 66); any Apocrypha book is `.apocrypha`.
    public static func group(of book: Book) -> BookGroup {
        guard book.canon != .apocrypha else { return .apocrypha }
        switch book.order {
        case ...5: return .law                    // Genesis to Deuteronomy
        case 6...17: return .history              // Joshua to Esther
        case 18...22: return .poetryAndWisdom     // Job to Song of Solomon
        case 23...27: return .majorProphets       // Isaiah to Daniel
        case 28...39: return .minorProphets       // Hosea to Malachi
        case 40...44: return .gospelsAndActs      // Matthew to Acts
        case 45...57: return .paulsLetters        // Romans to Philemon
        case 58...65: return .generalLetters      // Hebrews to Jude
        default: return .revelation
        }
    }
}
