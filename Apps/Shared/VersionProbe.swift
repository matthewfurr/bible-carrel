#if DEBUG
import Foundation
import OSLog
import ScriptureData
import ScriptureModel
import SwiftData

/// A Debug-only hook for the kept-versions rehearsal: `-versionProbe "<verb>:<REF>[:<text>]|…"`,
/// run in order once the coordinator has prepared, after `-syncProbe`, on both apps. `REF` is a
/// chapter, `GEN.1`; "its note" is the first ESV chapter note there.
///
/// - `note:GEN.1:<text>` makes its note or sets its text, as `SyncProbe`'s does (so the phone can).
/// - `type:GEN.1:<text>` is one sitting: its note's text becomes each prefix of `<text>` in turn, a save for each.
/// - `use:GEN.1` and `keepBoth:GEN.1` settle its note's newest kept version.
/// - `discard:GEN.1` deletes the newest kept version of its note, or, with no note there, the
///   newest text with no note in that chapter.
/// - `restore:GEN.1` restores the newest text with no note in that chapter as a note.
/// - `seed:GEN.1:<text>` inserts a kept version of its note, kind "iPhone", written a day ago.
/// - `seedOrphan:GEN.1:<text>` inserts one with a new `noteID` on that chapter.
/// - `clear` deletes every kept version and every deletion marker.
///
/// Every choice goes through the store's own methods, never around them. It refuses the main store
/// (`StoreLocation.refusesProbes`, tested in `StoreLocationTests`) and never writes a preference.
enum VersionProbe {
    static let argument = "versionProbe"
    private static let translationID = "ESV"
    private static let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "sync")

    enum ProbeError: Error {
        case unrecognized
        case noNote
        case noKeptVersion
        case notApplied
    }

    /// True when a probe was asked for and ran, so the models need reloading.
    @MainActor @discardableResult
    static func runIfAsked(store: MarkupStore, location: StoreLocation, sync: SyncConfiguration?) -> Bool {
        guard let probes = UserDefaults.standard.string(forKey: argument), !probes.isEmpty else { return false }
        if location.refusesProbes(sync: sync) {
            logger.log("version probe refused: never in the main store")
            return false
        }
        var changed = false
        // Several probes in one launch are separated by `|`, and run in order.
        for probe in probes.split(separator: "|").map(String.init) {
            do {
                try run(probe, store: store)
                logger.log("version probe done: \(probe, privacy: .public)")
                changed = true
            } catch {
                logger.error("version probe failed: \(probe, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        return changed
    }

    @MainActor private static func run(_ probe: String, store: MarkupStore) throws {
        let parts = probe.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        if parts == ["clear"] {
            try clear(store: store)
            return
        }
        guard parts.count >= 2 else { throw ProbeError.unrecognized }
        let reference = parts[1].split(separator: ".").map(String.init)
        guard reference.count == 2, let number = Int(reference[1]), number >= 1 else { throw ProbeError.unrecognized }
        let location = ChapterLocation(book: reference[0], chapter: number)
        let text = parts.count == 3 ? parts[2] : nil

        switch (parts[0], text) {
        case ("note", let text?):
            if let note = try chapterNote(in: location, store: store) {
                try store.updateNote(note, body: text)
            } else {
                try store.addChapterNote(
                    book: location.book, chapter: location.chapter, translationID: translationID,
                    body: text, sourceThreadID: nil)
            }
        case ("type", let text?):
            guard let note = try chapterNote(in: location, store: store),
                let sitting = try store.beginSitting(noteID: note.uuid)
            else { throw ProbeError.noNote }
            defer { store.endSitting(sitting) }
            for length in 1...max(text.count, 1) {
                try store.updateNote(note, body: String(text.prefix(length)), sitting: sitting)
            }
        case ("use", nil):
            // Nil means the version or its note was gone; a note whose text was blank replaces nothing, which is fine.
            try store.useVersion(try newestKept(of: location, store: store).uuid)
        case ("keepBoth", nil):
            try store.keepBoth(try newestKept(of: location, store: store).uuid)
        case ("discard", nil):
            let version: KeptVersionSnapshot
            if let note = try chapterNote(in: location, store: store) {
                guard let newest = try store.keptVersions(forNote: note.uuid).first else { throw ProbeError.noKeptVersion }
                version = newest
            } else {
                version = try newestOrphan(in: location, store: store)
            }
            guard try store.delete(.keptVersion(version)) != nil else { throw ProbeError.notApplied }
        case ("restore", nil):
            guard try store.restoreAsNote(try newestOrphan(in: location, store: store).uuid) != nil else {
                throw ProbeError.notApplied
            }
        case ("seed", let text?):
            guard let note = try chapterNote(in: location, store: store) else { throw ProbeError.noNote }
            let version = keptVersion(book: location.book, chapter: location.chapter, text: text, noteID: note.uuid)
            version.verse = note.verse
            version.endVerse = note.endVerse
            version.translationID = note.translationID
            version.quotedText = note.quotedText
            store.context.insert(version)
            try store.context.save()
        case ("seedOrphan", let text?):
            let version = keptVersion(book: location.book, chapter: location.chapter, text: text, noteID: UUID())
            version.translationID = translationID
            store.context.insert(version)
            try store.context.save()
        default:
            throw ProbeError.unrecognized
        }
    }

    /// A kept version of kind "iPhone", written a day ago, on the chapter.
    private static func keptVersion(book: String, chapter: Int, text: String, noteID: UUID) -> KeptVersion {
        let version = KeptVersion()
        version.noteID = noteID
        version.body = text
        version.writtenAt = Date().addingTimeInterval(-86_400)
        version.deviceKind = "iPhone"
        version.book = book
        version.chapter = chapter
        return version
    }

    @MainActor private static func clear(store: MarkupStore) throws {
        for version in try store.context.fetch(FetchDescriptor<KeptVersion>()) { store.context.delete(version) }
        for marker in try store.context.fetch(FetchDescriptor<DeletionMarker>()) { store.context.delete(marker) }
        try store.context.save()
    }

    /// The first chapter note on the chapter in ESV, by creation time.
    @MainActor private static func chapterNote(in location: ChapterLocation, store: MarkupStore) throws -> Note? {
        try store.notes(in: location).first { $0.scope == .chapter && $0.translationID == translationID }
    }

    @MainActor private static func newestKept(of location: ChapterLocation, store: MarkupStore) throws -> KeptVersionSnapshot {
        guard let note = try chapterNote(in: location, store: store) else { throw ProbeError.noNote }
        guard let newest = try store.keptVersions(forNote: note.uuid).first else { throw ProbeError.noKeptVersion }
        return newest
    }

    /// The newest kept version in the chapter whose note is not in the store.
    @MainActor private static func newestOrphan(in location: ChapterLocation, store: MarkupStore) throws -> KeptVersionSnapshot {
        guard let newest = try store.orphanVersions().first(where: { $0.book == location.book && $0.chapter == location.chapter }) else {
            throw ProbeError.noKeptVersion
        }
        return newest
    }
}
#endif
