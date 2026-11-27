import Foundation

/// One `EN/{canon}/{BOOK}/{VERSION}.json` file from the holybooks repository.
public struct HolyBookFile: Decodable, Sendable {
    public let version: String
    public let ID: String
    public let name: String
    public let text: [Chapter]

    public init(version: String, ID: String, name: String, text: [Chapter]) {
        self.version = version
        self.ID = ID
        self.name = name
        self.text = text
    }

    public struct Chapter: Decodable, Sendable {
        /// e.g. `"NT:MAT.5"`
        public let ID: String
        public let name: String
        public let text: [Entry]

        public init(ID: String, name: String, text: [Entry]) {
            self.ID = ID
            self.name = name
            self.text = text
        }

        /// The chapter number parsed from the trailing `.N` of `ID`, or nil when malformed.
        public var number: Int? {
            guard let dot = ID.lastIndex(of: ".") else { return nil }
            return Int(ID[ID.index(after: dot)...])
        }
    }

    /// One line of source text. Several consecutive entries can share a verse `ID`
    /// (poetry lines); an empty `text` marks a paragraph break after that verse.
    public struct Entry: Decodable, Sendable {
        public let ID: String
        public let text: String

        public init(ID: String, text: String) {
            self.ID = ID
            self.text = text
        }
    }
}
