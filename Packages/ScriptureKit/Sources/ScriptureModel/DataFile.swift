import Foundation

/// Any JSON value, so a reading plan's weeks can be carried as the stored `PlanCoding` JSON, whatever it holds.
public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

/// Why a data file could not be read.
public enum DataImportError: Error, Equatable {
    /// Not a data file's shape: too large, not JSON, cut off, or a known key of the wrong shape.
    case damaged
    /// JSON, but not this app's data file.
    case foreign
    /// Written by a newer format version than this build reads.
    case newer(Int)
}

/// Everything the reader has made, as one JSON file (format version 1). Every `id` is the record's uuid;
/// an optional value that is nil is left out of the file. A kind that is missing reads as empty and an
/// unknown key is ignored, so a later version can add to a file without this build refusing it.
public struct DataFile: Codable, Equatable, Sendable {
    public static let formatName = "bible-carrel-data"
    public static let currentVersion = 1
    public static let maximumBytes = 268_435_456

    public var format: String
    public var version: Int
    public var exportedAt: Date
    public var app: String
    public var colors: [Color]
    public var highlights: [Highlight]
    public var notes: [Note]
    public var keptVersions: [KeptVersion]
    public var bookmarks: [Bookmark]
    public var prompts: [Prompt]
    public var plans: [Plan]
    public var ticks: [Tick]
    public var conversations: [Conversation]

    public init(
        exportedAt: Date, app: String,
        colors: [Color] = [], highlights: [Highlight] = [], notes: [Note] = [], keptVersions: [KeptVersion] = [],
        bookmarks: [Bookmark] = [], prompts: [Prompt] = [], plans: [Plan] = [], ticks: [Tick] = [],
        conversations: [Conversation] = []
    ) {
        format = Self.formatName
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.app = app
        self.colors = colors
        self.highlights = highlights
        self.notes = notes
        self.keptVersions = keptVersions
        self.bookmarks = bookmarks
        self.prompts = prompts
        self.plans = plans
        self.ticks = ticks
        self.conversations = conversations
    }

    // MARK: - Records

    public struct Color: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var name: String
        public var lightHex: String
        public var darkHex: String
        public var sortOrder: Int
        public var isDefault: Bool
        public var builtInKey: String?
    }

    public struct Highlight: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var book: String
        public var chapter: Int
        public var verse: Int
        public var endVerse: Int
        public var startOffset: Int
        public var endOffset: Int
        public var translationID: String
        public var colorID: UUID?
        public var quotedText: String
        public var createdAt: Date
        public var modifiedAt: Date
    }

    public struct Note: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var body: String
        public var createdAt: Date
        public var modifiedAt: Date
        public var scope: String
        public var book: String
        public var chapter: Int
        public var verse: Int
        public var endVerse: Int
        public var translationID: String
        public var quotedText: String
        public var highlightID: UUID?
        public var sourceThreadID: UUID?
        public var versionMark: String?
        public var versionAncestry: String?
        public var deviceKind: String?
    }

    public struct KeptVersion: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var noteID: UUID?
        public var body: String
        public var writtenAt: Date
        public var deviceKind: String
        public var book: String
        public var chapter: Int
        public var verse: Int
        public var endVerse: Int
        public var translationID: String
        public var quotedText: String
        public var startOffset: Int
        public var endOffset: Int
    }

    public struct Bookmark: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var book: String
        public var chapter: Int
        public var verse: Int
        public var createdAt: Date
        public var label: String?
    }

    public struct Prompt: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var title: String
        public var summary: String
        public var body: String
        public var scope: String
        public var section: String?
        public var isEnabled: Bool
        public var sortOrder: Int
        public var isBuiltIn: Bool
        public var builtInKey: String?
        public var outputKind: String
    }

    public struct Plan: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var title: String
        public var createdAt: Date
        public var modifiedAt: Date
        /// The stored `PlanCoding` JSON as it is, so it carries its own `"v"`.
        public var weeks: JSONValue
    }

    public struct Tick: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var planID: UUID?
        public var readingID: UUID?
        public var tickedAt: Date
    }

    public struct Conversation: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var scope: String
        public var book: String
        public var chapter: Int
        public var verse: Int
        public var endVerse: Int
        public var startOffset: Int
        public var endOffset: Int
        public var translationID: String
        public var quotedText: String
        public var title: String
        public var createdAt: Date
        public var updatedAt: Date
        public var messages: [Message]
    }

    public struct Message: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var role: String
        public var content: String
        public var createdAt: Date
        public var providerID: String
        public var modelName: String
        public var attachedReference: String?
        public var displayText: String?
        public var providerHost: String?
        public var finishReason: String?
        public var savedNoteID: UUID?
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case format, version, exportedAt, app, colors, highlights, notes, keptVersions, bookmarks, prompts, plans, ticks, conversations
    }

    /// A missing kind is empty; the top-level values are required.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        format = try values.decode(String.self, forKey: .format)
        version = try values.decode(Int.self, forKey: .version)
        exportedAt = try values.decode(Date.self, forKey: .exportedAt)
        app = try values.decode(String.self, forKey: .app)
        colors = try values.decodeIfPresent([Color].self, forKey: .colors) ?? []
        highlights = try values.decodeIfPresent([Highlight].self, forKey: .highlights) ?? []
        notes = try values.decodeIfPresent([Note].self, forKey: .notes) ?? []
        keptVersions = try values.decodeIfPresent([KeptVersion].self, forKey: .keptVersions) ?? []
        bookmarks = try values.decodeIfPresent([Bookmark].self, forKey: .bookmarks) ?? []
        prompts = try values.decodeIfPresent([Prompt].self, forKey: .prompts) ?? []
        plans = try values.decodeIfPresent([Plan].self, forKey: .plans) ?? []
        ticks = try values.decodeIfPresent([Tick].self, forKey: .ticks) ?? []
        conversations = try values.decodeIfPresent([Conversation].self, forKey: .conversations) ?? []
    }

    // MARK: - Writing and reading

    /// Pretty-printed with sorted keys, so two exports of one store differ only in their date.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(DataDates.text(date))
        }
        return try encoder.encode(self)
    }

    public static func read(_ data: Data, maximumBytes: Int = DataFile.maximumBytes) throws -> DataFile {
        guard data.count <= maximumBytes,
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { throw DataImportError.damaged }
        guard object["format"] as? String == formatName else { throw DataImportError.foreign }
        guard let number = object["version"] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue == Double(number.intValue), number.intValue >= 1
        else { throw DataImportError.damaged }
        if number.intValue > currentVersion { throw DataImportError.newer(number.intValue) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = DataDates.date(text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not an ISO 8601 date: \(text)"))
            }
            return date
        }
        do {
            return try decoder.decode(DataFile.self, from: data)
        } catch {
            throw DataImportError.damaged
        }
    }

    /// Every kind's records equal, each kind by id; `exportedAt` and `app` are not compared.
    public func hasTheSameRecords(as other: DataFile) -> Bool {
        func same<Record: Identifiable & Equatable>(_ a: [Record], _ b: [Record]) -> Bool where Record.ID: Hashable {
            a.count == b.count
                && Dictionary(a.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                == Dictionary(b.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
        return format == other.format && version == other.version
            && same(colors, other.colors) && same(highlights, other.highlights) && same(notes, other.notes)
            && same(keptVersions, other.keptVersions) && same(bookmarks, other.bookmarks) && same(prompts, other.prompts)
            && same(plans, other.plans) && same(ticks, other.ticks) && same(conversations, other.conversations)
    }
}

/// ISO 8601 in UTC with milliseconds, e.g. 2023-11-14T22:13:20.500Z. Reading accepts the date with or without them.
enum DataDates {
    static func milliseconds(_ date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 * 1000).rounded() / 1000)
    }

    static func text(_ date: Date) -> String {
        let total = Int((date.timeIntervalSince1970 * 1000).rounded())
        var seconds = total / 1000, fraction = total % 1000
        if fraction < 0 { fraction += 1000; seconds -= 1 }
        let whole = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double(seconds)))
        return String(whole.dropLast()) + "." + String(format: "%03d", fraction) + "Z"
    }

    static func date(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        return (fractional.date(from: text) ?? plain.date(from: text)).map(milliseconds)
    }
}
