import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// The kind of device a sitting is on, stored with a note's version.
public enum DeviceKind {
    @MainActor public static var current: String {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #else
        "Mac"
        #endif
    }
}

/// A note's last text as this device wrote it, kept on the device before the save.
public struct LastText: Codable, Equatable, Sendable {
    public var noteID: UUID
    public var body: String
    public var writtenAt: Date
    public var book: String
    public var chapter: Int
    public var verse: Int
    public var endVerse: Int
    public var translationID: String
    public var quotedText: String
    public var startOffset: Int
    public var endOffset: Int
    /// The tag of the device that wrote `body`: this device's for a save made here, the note's
    /// mark's for a text put back (undo, backup, import). Nil when unknown, and for an entry
    /// written before entries named their writer; sight of it is then by its digest alone.
    public var tag: String?

    public init(noteID: UUID, body: String, writtenAt: Date, book: String, chapter: Int, verse: Int, endVerse: Int,
                translationID: String, quotedText: String, startOffset: Int, endOffset: Int, tag: String? = nil) {
        self.noteID = noteID
        self.body = body
        self.writtenAt = writtenAt
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.endVerse = endVerse
        self.translationID = translationID
        self.quotedText = quotedText
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.tag = tag
    }
}

/// One file per note (`<uuid>.json`) in a directory beside the store, plus the device's tag in a
/// file named `device`. With no directory it keeps everything in memory.
@MainActor public final class LastTextJournal {
    public let deviceTag: String
    private let directory: URL?
    private var memory: [UUID: LastText] = [:]

    public init(directory: URL?, deviceTag: String? = nil) {
        self.directory = directory
        if let deviceTag {
            self.deviceTag = deviceTag
        } else if let directory {
            self.deviceTag = Self.storedTag(in: directory)
        } else {
            self.deviceTag = Self.newTag()
        }
    }

    public func record(_ entry: LastText) throws {
        guard let directory else {
            memory[entry.noteID] = entry
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(entry).write(to: file(for: entry.noteID), options: .atomic)
    }

    public func entry(for noteID: UUID) -> LastText? {
        guard directory != nil else { return memory[noteID] }
        return read(file(for: noteID))
    }

    public func entries() -> [LastText] {
        guard let directory else { return Array(memory.values) }
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }.compactMap { read($0) }
    }

    public func forget(_ noteID: UUID) {
        guard directory != nil else {
            memory[noteID] = nil
            return
        }
        try? FileManager.default.removeItem(at: file(for: noteID))
    }

    // MARK: Files

    private func file(for noteID: UUID) -> URL {
        directory!.appending(path: "\(noteID.uuidString).json")
    }

    /// Decodes the file; one that cannot be decoded is removed and reads as no entry.
    private func read(_ url: URL) -> LastText? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entry = try? decoder.decode(LastText.self, from: data) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return entry
    }

    private static func newTag() -> String {
        String(format: "%04x", UInt16.random(in: .min ... .max))
    }

    private static func storedTag(in directory: URL) -> String {
        let url = directory.appending(path: "device")
        if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
            let tag = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if tag.count == 4, tag.allSatisfy({ $0.isASCII && $0.isHexDigit && !$0.isUppercase }) { return tag }
        }
        let tag = newTag()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Data(tag.utf8).write(to: url, options: .atomic)
        return tag
    }
}
