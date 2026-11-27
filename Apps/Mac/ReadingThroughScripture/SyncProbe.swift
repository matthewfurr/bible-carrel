#if DEBUG
import Foundation
import OSLog
import ScriptureData
import ScriptureModel

/// A Debug-only hook for the sync rehearsal: one change to the store, named by the launch
/// argument `-syncProbe`, made once the coordinator has prepared.
///
/// - `bookmark:GEN.1.1` toggles the bookmark on that verse.
/// - `note:GEN.1:<text>` sets the body of the first chapter note on that chapter in ESV, creating it if there is none.
/// - `quote:GEN.1:<text>` sets that note's quoted words and nothing else (not its body, not its
///   modification time), to show whether a clash is settled a value at a time or a record at a time.
/// - `deleteNote:GEN.1` deletes that note.
///
/// With `-syncProbeOffline YES` the store is opened without its mirror (`AppSync.makeContainer`),
/// so the change is made as on a device with no network; the next ordinary launch sends it.
enum SyncProbe {
    static let argument = "syncProbe"
    static let offlineArgument = "syncProbeOffline"
    static var isOffline: Bool { UserDefaults.standard.bool(forKey: offlineArgument) }
    private static let translationID = "ESV"
    private static let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "sync")

    /// True when a probe was asked for and changed the store, so the models need reloading.
    @MainActor @discardableResult
    static func runIfAsked(store: MarkupStore) -> Bool {
        guard let probes = UserDefaults.standard.string(forKey: argument), !probes.isEmpty else { return false }
        var changed = false
        // Several probes in one launch are separated by `|`, and run in order.
        for probe in probes.split(separator: "|").map(String.init) {
            do {
                if try run(probe, store: store) {
                    logger.log("probe done: \(probe, privacy: .public)")
                    changed = true
                } else {
                    logger.log("probe done: no note")
                }
            } catch {
                logger.error("probe failed: \(probe, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        return changed
    }

    enum ProbeError: Error {
        case unrecognized
    }

    /// False only when `deleteNote` found no note to delete.
    @MainActor private static func run(_ probe: String, store: MarkupStore) throws -> Bool {
        let parts = probe.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else { throw ProbeError.unrecognized }
        let reference = parts[1].split(separator: ".").map(String.init)
        switch parts[0] {
        case "bookmark":
            guard reference.count == 3, let chapter = number(reference[1]), let verse = number(reference[2]) else {
                throw ProbeError.unrecognized
            }
            try store.toggleBookmark(at: VerseLocation(book: reference[0], chapter: chapter, verse: verse))
        case "note":
            guard parts.count == 3, reference.count == 2, let chapter = number(reference[1]) else { throw ProbeError.unrecognized }
            let location = ChapterLocation(book: reference[0], chapter: chapter)
            if let note = try chapterNote(in: location, store: store) {
                try store.updateNote(note, body: parts[2])
            } else {
                try store.addChapterNote(
                    book: location.book, chapter: location.chapter, translationID: translationID,
                    body: parts[2], sourceThreadID: nil)
            }
        case "quote":
            guard parts.count == 3, reference.count == 2, let chapter = number(reference[1]) else { throw ProbeError.unrecognized }
            guard let note = try chapterNote(in: ChapterLocation(book: reference[0], chapter: chapter), store: store) else {
                return false
            }
            note.quotedText = parts[2]
            try store.context.save()
        case "deleteNote":
            guard reference.count == 2, let chapter = number(reference[1]) else { throw ProbeError.unrecognized }
            guard let note = try chapterNote(in: ChapterLocation(book: reference[0], chapter: chapter), store: store) else {
                return false
            }
            try store.deleteNote(note)
        default:
            throw ProbeError.unrecognized
        }
        return true
    }

    /// A chapter or verse number: 1 or more.
    private static func number(_ text: String) -> Int? {
        Int(text).flatMap { $0 >= 1 ? $0 : nil }
    }

    /// The first chapter note on the chapter in ESV, by creation time.
    @MainActor private static func chapterNote(in location: ChapterLocation, store: MarkupStore) throws -> Note? {
        try store.notes(in: location).first { $0.scope == .chapter && $0.translationID == translationID }
    }
}
#endif
