import Foundation
import Testing
@testable import ScriptureModel

@MainActor @Suite struct DataFileTests {
    private func good() throws -> DataFile {
        let store = MarkupStore(container: try MarkupContainer.make(inMemory: true))
        try DataSample.fill(store)
        return try DataExport.file(from: store, includesConversations: true, app: "Bible Carrel 1.0", now: Date(timeIntervalSince1970: 1_700_001_000.123))
    }

    @Test func datesAreISO8601TextWithMilliseconds() throws {
        let file = DataFile(exportedAt: Date(timeIntervalSince1970: 1_700_000_000.5), app: "A")
        let object = try #require(try JSONSerialization.jsonObject(with: file.encoded()) as? [String: Any])
        #expect(object["exportedAt"] as? String == "2023-11-14T22:13:20.500Z")
        let plain = try #require(String(data: file.encoded(), encoding: .utf8)).replacingOccurrences(of: ".500Z", with: "Z")
        #expect(try DataFile.read(Data(plain.utf8)).exportedAt == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func encodingRoundTrips() throws {
        let file = try good()
        #expect(try DataFile.read(file.encoded()) == file)
        #expect(try DataFile.read(file.encoded()).hasTheSameRecords(as: file))
    }

    @Test func theSameRecordsIgnoreOnlyTheDateAndTheApp() throws {
        let file = try good()
        var other = file
        other.exportedAt = Date(timeIntervalSince1970: 5)
        other.app = "Elsewhere"
        #expect(file.hasTheSameRecords(as: other))
        other.notes[0].body = "changed"
        #expect(!file.hasTheSameRecords(as: other))
    }

    /// The published format's key names, one record of each of the ten kinds with every optional
    /// set, so renaming a Swift property cannot silently change the file.
    @Test func everyRecordsKeysArePinned() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let id = UUID()
        let message = DataFile.Message(id: id, role: "user", content: "c", createdAt: date, providerID: "p", modelName: "m",
                                       attachedReference: "Genesis 1", displayText: "d", providerHost: "h", finishReason: "f", savedNoteID: id)
        let file = DataFile(
            exportedAt: date, app: "A",
            colors: [.init(id: id, name: "n", lightHex: "#FFFFFF", darkHex: "#000000", sortOrder: 0, isDefault: true, builtInKey: "yellow")],
            highlights: [.init(id: id, book: "Genesis", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 1, translationID: "WEB",
                               colorID: id, quotedText: "q", createdAt: date, modifiedAt: date)],
            notes: [.init(id: id, body: "b", createdAt: date, modifiedAt: date, scope: "highlight", book: "Genesis", chapter: 1, verse: 1,
                          endVerse: 1, translationID: "WEB", quotedText: "q", highlightID: id, sourceThreadID: id, versionMark: "m",
                          versionAncestry: "a", deviceKind: "Mac")],
            keptVersions: [.init(id: id, noteID: id, body: "b", writtenAt: date, deviceKind: "Mac", book: "Genesis", chapter: 1, verse: 1,
                                 endVerse: 1, translationID: "WEB", quotedText: "q", startOffset: 0, endOffset: 1)],
            bookmarks: [.init(id: id, book: "Genesis", chapter: 1, verse: 1, createdAt: date, label: "l")],
            prompts: [.init(id: id, title: "t", summary: "s", body: "b", scope: "chapter", section: "orient", isEnabled: true, sortOrder: 0,
                            isBuiltIn: true, builtInKey: "summary", outputKind: "text")],
            plans: [.init(id: id, title: "t", createdAt: date, modifiedAt: date, weeks: .object(["v": .number(1)]))],
            ticks: [.init(id: id, planID: id, readingID: id, tickedAt: date)],
            conversations: [.init(id: id, scope: "selection", book: "Genesis", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 1,
                                  translationID: "WEB", quotedText: "q", title: "t", createdAt: date, updatedAt: date, messages: [message])])
        let object = try #require(try JSONSerialization.jsonObject(with: file.encoded()) as? [String: Any])
        func keys(_ kind: String) -> [String] {
            ((object[kind] as? [[String: Any]])?.first?.keys).map { $0.sorted() } ?? []
        }
        let conversation = (object["conversations"] as? [[String: Any]])?.first
        let messageKeys = ((conversation?["messages"] as? [[String: Any]])?.first?.keys).map { $0.sorted() } ?? []

        #expect(keys("colors") == ["builtInKey", "darkHex", "id", "isDefault", "lightHex", "name", "sortOrder"])
        #expect(keys("highlights") == ["book", "chapter", "colorID", "createdAt", "endOffset", "endVerse", "id", "modifiedAt",
                                       "quotedText", "startOffset", "translationID", "verse"])
        #expect(keys("notes") == ["body", "book", "chapter", "createdAt", "deviceKind", "endVerse", "highlightID", "id", "modifiedAt",
                                  "quotedText", "scope", "sourceThreadID", "translationID", "verse", "versionAncestry", "versionMark"])
        #expect(keys("keptVersions") == ["body", "book", "chapter", "deviceKind", "endOffset", "endVerse", "id", "noteID", "quotedText",
                                         "startOffset", "translationID", "verse", "writtenAt"])
        #expect(keys("bookmarks") == ["book", "chapter", "createdAt", "id", "label", "verse"])
        #expect(keys("prompts") == ["body", "builtInKey", "id", "isBuiltIn", "isEnabled", "outputKind", "scope", "section", "sortOrder",
                                    "summary", "title"])
        #expect(keys("plans") == ["createdAt", "id", "modifiedAt", "title", "weeks"])
        #expect(keys("ticks") == ["id", "planID", "readingID", "tickedAt"])
        #expect(keys("conversations") == ["book", "chapter", "createdAt", "endOffset", "endVerse", "id", "messages", "quotedText", "scope",
                                          "startOffset", "title", "translationID", "updatedAt", "verse"])
        #expect(messageKeys == ["attachedReference", "content", "createdAt", "displayText", "finishReason", "id", "modelName", "providerHost",
                                "providerID", "role", "savedNoteID"])
    }

    @Test func aDamagedAForeignAndANewerFileAreToldApart() throws {
        let data = try good().encoded()
        for text in ["", "not json", "[1,2]", "# Notes\n\n- God made it all.\n"] {
            #expect(throws: DataImportError.damaged) { try DataFile.read(Data(text.utf8)) }
        }
        #expect(throws: DataImportError.damaged) { try DataFile.read(data.prefix(data.count / 2)) }
        #expect(throws: DataImportError.damaged) { try DataFile.read(data, maximumBytes: 10) }
        #expect(throws: DataImportError.foreign) { try DataFile.read(Data(#"{"hello":1}"#.utf8)) }
        #expect(throws: DataImportError.foreign) { try DataFile.read(Data(#"{"format":"other","version":1}"#.utf8)) }
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(throws: DataImportError.newer(2)) { try DataFile.read(Data(text.replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 2").utf8)) }
        #expect(throws: DataImportError.damaged) { try DataFile.read(Data(text.replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 0").utf8)) }
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["bookmarks"] = nil
        object["somethingNew"] = ["a": 1]
        let read = try DataFile.read(try JSONSerialization.data(withJSONObject: object))
        #expect(read.bookmarks.isEmpty && read.notes.count == 2)
        object["notes"] = "wrong"
        #expect(throws: DataImportError.damaged) { try DataFile.read(try JSONSerialization.data(withJSONObject: object)) }
    }
}
