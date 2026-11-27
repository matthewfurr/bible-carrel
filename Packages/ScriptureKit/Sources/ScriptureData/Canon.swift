/// The three sections of the bundled canon. Raw values match the holybooks folder names.
public enum Canon: String, Codable, Sendable, CaseIterable {
    case oldTestament = "OT"
    case newTestament = "NT"
    case apocrypha = "AP"

    public var displayName: String {
        switch self {
        case .oldTestament: "Old Testament"
        case .newTestament: "New Testament"
        case .apocrypha: "Apocrypha"
        }
    }
}

/// A book of the Bible as known to the app, independent of any translation.
public struct Book: Identifiable, Hashable, Codable, Sendable {
    /// The holybooks code, e.g. `"GEN"`, `"1CO"`, `"NAM"`.
    public let id: String
    public let canon: Canon
    /// 1-based position across the whole catalog, in canon order.
    public let order: Int
    public let name: String
    public let shortName: String
    /// Extra spellings the reference parser accepts.
    public let aliases: [String]

    public init(id: String, canon: Canon, order: Int, name: String, shortName: String, aliases: [String] = []) {
        self.id = id
        self.canon = canon
        self.order = order
        self.name = name
        self.shortName = shortName
        self.aliases = aliases
    }

    /// The name to put in front of a chapter number: `"Psalm 23"` for one psalm, while the book list says "Psalms".
    public var chapterName: String {
        id == "PSA" ? "Psalm" : name
    }
}
