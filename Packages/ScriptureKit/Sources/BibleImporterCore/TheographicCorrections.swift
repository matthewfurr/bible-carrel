import Foundation
import ScriptureData

/// Named corrections to Theographic's links from an event to a verse. Each says which events it touches, the
/// verse to take off them and why; `apply` makes it and warns when the data no longer needs it, so a re-pin
/// that fixes the data upstream shows up in the import's warnings instead of going quiet.
enum TheographicCorrections {
    struct Correction: Equatable, Sendable {
        let name: String
        let eventIDs: [Int]
        let verse: VerseLocation
        let reason: String
    }

    static let all: [Correction] = [
        // Theographic gives Deuteronomy 34:1 Genesis's book number (its `verseSort` is 01034001), so the death
        // of Moses reads as an event in Genesis.
        Correction(
            name: "Death of Moses is not in Genesis", eventIDs: [129], verse: VerseLocation(book: "GEN", chapter: 34, verse: 1),
            reason: "Theographic gives Deuteronomy 34:1 Genesis's book number, verseSort 01034001"),
        // Genesis 46:13's Job is a son of Issachar, and the data ties the verse to Job of Uz's birth and life.
        Correction(
            name: "Job of Uz is not Issachar's son", eventIDs: [108, 107], verse: VerseLocation(book: "GEN", chapter: 46, verse: 13),
            reason: "Genesis 46:13's Job is tied to Job of Uz"),
    ]

    /// `verses` without the verse of each correction that names `id`. A correction whose verse is not there
    /// removes nothing and warns.
    static func apply(
        _ corrections: [Correction], toEvent id: Int, verses: [(position: Int, key: Int)], warnings: inout [ImportWarning]
    ) -> [(position: Int, key: Int)] {
        var result = verses
        for correction in corrections where correction.eventIDs.contains(id) {
            guard let key = VerseKey.key(correction.verse) else { continue }
            guard result.contains(where: { $0.key == key }) else {
                warnings.append(ImportWarning(
                    "Correction \"\(correction.name)\" is no longer needed: event \(id) has no \(Self.displayString(correction.verse))"))
                continue
            }
            result.removeAll { $0.key == key }
        }
        return result
    }

    private static func displayString(_ location: VerseLocation) -> String {
        guard let book = BookCatalog.book(code: location.book) else { return "" }
        return Reference(book: book, chapter: location.chapter, verse: location.verse).displayString
    }
}
