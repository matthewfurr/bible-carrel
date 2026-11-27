import BibleImporterCore
import Foundation
import ScriptureData
import SwiftUI
import Testing
@testable import ScriptureUI

/// The verse references found in an entry of Easton's Bible Dictionary, and the ones left plain.
@Suite struct DictionaryReferencesTests {
    /// Every book with a hundred and fifty chapters of eighty verses, a one-chapter book with one of twenty-five.
    private static func fakeLastVerses(_ book: Book) -> [Int: Int] {
        ["OBA", "PHM", "2JN", "3JN", "JUD"].contains(book.id) ? [1: 25] : Dictionary(uniqueKeysWithValues: (1...150).map { ($0, 80) })
    }

    private static func scan(_ text: String, lastVerses: (Book) -> [Int: Int] = fakeLastVerses) -> DictionaryReferences.Scan {
        DictionaryReferences.scan(text, lastVerses: lastVerses)
    }

    /// Each link as the text it covers and the reference it opens: "Jer. 37:13 = Jeremiah 37:13".
    private static func links(_ text: String, lastVerses: (Book) -> [Int: Int] = fakeLastVerses) -> [String] {
        let characters = Array(text)
        return scan(text, lastVerses: lastVerses).links.map { "\(String(characters[$0.range])) = \($0.reference.displayString)" }
    }

    private static func unlinked(_ text: String, lastVerses: (Book) -> [Int: Int] = fakeLastVerses) -> [String] {
        let characters = Array(text)
        return scan(text, lastVerses: lastVerses).unlinked.map { "\(String(characters[$0.range])) \($0.why)" }
    }

    // MARK: - Chains

    @Test func aSemicolonKeepsTheBookAndACommaTheChapter() {
        #expect(Self.links("(Jer. 37:13; 38:7; Zech. 14:10)")
                == ["Jer. 37:13 = Jeremiah 37:13", "38:7 = Jeremiah 38:7", "Zech. 14:10 = Zechariah 14:10"])
        #expect(Self.links("(Lev. 16:8, 10)") == ["Lev. 16:8 = Leviticus 16:8", "10 = Leviticus 16:10"])
        #expect(Self.links("(2 Sam. 3:27, 31-39; 4:12.)")
                == ["2 Sam. 3:27 = 2 Samuel 3:27", "31-39 = 2 Samuel 3:31-39", "4:12 = 2 Samuel 4:12"])
    }

    @Test func rangesTakeAHyphenOrAnEnDash() {
        #expect(Self.links("(Gen. 1:24-26; 2:4\u{2013}7)") == ["Gen. 1:24-26 = Genesis 1:24-26", "2:4\u{2013}7 = Genesis 2:4-7"])
    }

    @Test func aRangeIntoTheNextChapterRunsToItsChaptersEnd() {
        #expect(Self.links("(Judg. 8:33-9:6)") == ["Judg. 8:33-9:6 = Judges 8:33-80"])
    }

    @Test func aChapterAloneLinksTheChapterAndAChapterRangeItsFirst() {
        #expect(Self.links("(Gen. 35). Also in 1 Kings 16-22. (Lev. 8; 9)")
                == ["Gen. 35 = Genesis 35", "1 Kings 16-22 = 1 Kings 16", "Lev. 8 = Leviticus 8", "9 = Leviticus 9"])
    }

    @Test func aOneChapterBooksNumberIsAVerse() {
        #expect(Self.links("(Jude 9; Obad. 1:3)") == ["Jude 9 = Jude 1:9", "Obad. 1:3 = Obadiah 1:3"])
    }

    @Test func comparePrefixesAreNotPartOfTheReference() {
        #expect(Self.links("(Comp. 2 Kings 14:13.) (See Gen. 4:8) (cf. Rom. 5:1; comp. 6:2)")
                == ["2 Kings 14:13 = 2 Kings 14:13", "Gen. 4:8 = Genesis 4:8", "Rom. 5:1 = Romans 5:1", "6:2 = Romans 6:2"])
        #expect(Self.links("(Gen. 4:8, 9. Comp. 1 John 3:12)")
                == ["Gen. 4:8 = Genesis 4:8", "9 = Genesis 4:9", "1 John 3:12 = 1 John 3:12"])
    }

    @Test func eastonsOwnSpellingsAreBooks() {
        #expect(Self.links("(Judge. 20:6; 2 King 25:1; Exek. 1:1; Ge 10:10; 1 Thes. 1:9; Mat. 27:56; Cant. 1:5; 1 Sam 7:4)")
                == ["Judge. 20:6 = Judges 20:6", "2 King 25:1 = 2 Kings 25:1", "Exek. 1:1 = Ezekiel 1:1", "Ge 10:10 = Genesis 10:10",
                    "1 Thes. 1:9 = 1 Thessalonians 1:9", "Mat. 27:56 = Matthew 27:56", "Cant. 1:5 = Song of Solomon 1:5",
                    "1 Sam 7:4 = 1 Samuel 7:4"])
    }

    // MARK: - Never wrongly

    @Test func hebrewIsNotHebrewsAndNumbersAreNotReferences() {
        #expect(Self.links("(Heb. goral, a “pebble”), used in casting lots (Num. 33:54).") == ["Num. 33:54 = Numbers 33:54"])
        #expect(Self.links("It counted 45,600 warriors; it was 26 miles in length and 12 in breadth, in 1000 B.C.").isEmpty)
    }

    @Test func aChainStopsAtANumberThatIsNotAReference() {
        #expect(Self.links("(Gen. 35:19, 2 miles away)") == ["Gen. 35:19 = Genesis 35:19"])
        #expect(Self.links("(Gen. 35:19; 25 miles off)") == ["Gen. 35:19 = Genesis 35:19"])
    }

    @Test func aBookThatIsNotTheBiblesIsPlainAndSoIsWhatFollowsIt() {
        #expect(Self.links("Josephus (Ant. 8:13, 2), however, says (5:3)").isEmpty)
        #expect(Self.unlinked("Josephus (Ant. 8:13, 2), however, says (5:3)") == ["8:13 notABook", "5:3 ambiguous"])
    }

    @Test func aVerseTheTranslationLacksIsPlain() {
        let lastVerses: (Book) -> [Int: Int] = { $0.id == "JHN" ? [15: 27] : Self.fakeLastVerses($0) }
        #expect(Self.links("(John. 15:44; Gen. 151:1)", lastVerses: lastVerses).isEmpty)
        #expect(Self.unlinked("(John. 15:44; Gen. 151:1)", lastVerses: lastVerses) == ["John. 15:44 notInTheTranslation", "Gen. 151:1 notInTheTranslation"])
        #expect(Self.links("(Ps. 23:1)", lastVerses: { $0.id == "PSA" ? [:] : Self.fakeLastVerses($0) }).isEmpty)
    }

    // MARK: - Bare references

    @Test func aBareReferenceTakesTheBookCitedBeforeIt() {
        #expect(Self.links("Went to Bethel (Gen. 35:1). There he built an altar (35:7; 36:2).")
                == ["Gen. 35:1 = Genesis 35:1", "35:7 = Genesis 35:7", "36:2 = Genesis 36:2"])
    }

    @Test func aBookNamedJustBeforeABareReferenceIsItsBook() {
        let text = "On the north (Zech. 14:10). It is called by Jeremiah (20:2) “the high gate;” also “the gate” (17:19)."
        #expect(Self.links(text) == ["Zech. 14:10 = Zechariah 14:10", "20:2 = Jeremiah 20:2", "17:19 = Jeremiah 17:19"])
        #expect(Self.links("Isaiah (22:6), who also mentions it; and the time of Ezekiel (25:9); the Epistle to the Romans (16:23)")
                == ["22:6 = Isaiah 22:6", "25:9 = Ezekiel 25:9", "16:23 = Romans 16:23"])
    }

    @Test func aNameThatMayBeAPersonsLeavesTheBareReferencePlain() {
        // Zechariah's crowning of Joshua the high priest is Zechariah 6, not Joshua 6.
        #expect(Self.links("A vision (Zech. 1:8). The symbolical action, the crowning of Joshua (6:9-15), describes")
                == ["Zech. 1:8 = Zechariah 1:8"])
        // Zacher is "called Zechariah" in 1 Chronicles 9:37.
        #expect(Self.links("A son of Jehiel (1 Chr. 8:31; 9:35); called Zechariah (9:37).")
                == ["1 Chr. 8:31 = 1 Chronicles 8:31", "9:35 = 1 Chronicles 9:35"])
        // Another book's name in the prose since the last citation makes a bare reference unsure.
        #expect(Self.links("He was taken (Matt. 3:1). John preached in the wilderness (3:4).") == ["Matt. 3:1 = Matthew 3:1"])
        #expect(Self.unlinked("He was taken (Matt. 3:1). John preached in the wilderness (3:4).") == ["3:4 ambiguous"])
    }

    @Test func aBareReferenceInTheProseNeedsAWordThatLeadsIntoIt() {
        #expect(Self.links("A priest (Judg. 18:30). His history is recorded in 17:7-13 and 18:30; ch. 1:5. Near Remeth (q.v.), 19:21.")
                == ["Judg. 18:30 = Judges 18:30", "17:7-13 = Judges 17:7-13", "18:30 = Judges 18:30", "1:5 = Judges 1:5",
                    "19:21 = Judges 19:21"])
        #expect(Self.links("Sons (Gen. 46:16); Jahazah, 21:36; a word 3:4.") == ["Gen. 46:16 = Genesis 46:16"])
    }

    @Test func aBookNamedWithACommaOrInFullIsItsBook() {
        #expect(Self.links("The words of the prophet Isaiah, 19:13; 44:16-19, and Jeremiah, 46:19.")
                == ["19:13 = Isaiah 19:13", "44:16-19 = Isaiah 44:16-19", "46:19 = Jeremiah 46:19"])
        #expect(Self.links("(Luke 1:3) and the Acts of the Apostles (1:1); while John (14:22) asks")
                == ["Luke 1:3 = Luke 1:3", "1:1 = Acts 1:1", "14:22 = John 14:22"])
    }

    @Test func eastonsSpaceAfterAColonAndAChapterBeforeAndAreReferences() {
        #expect(Self.links("(Jer. 43: 8-13; Ps. 135: 10-12) and in Neh. 8 and 12:26.")
                == ["Jer. 43: 8-13 = Jeremiah 43:8-13", "Ps. 135: 10-12 = Psalm 135:10-12", "Neh. 8 = Nehemiah 8", "12:26 = Nehemiah 12:26"])
    }

    @Test func aBareReferenceWithNoBookOrNotInItsBookIsPlain() {
        #expect(Self.links("A town (13:8) of the plain.").isEmpty)
        // Daniel 28 is no chapter: the book is a guess, so its 14:14 is not linked either.
        #expect(Self.links("He was contemporary with Daniel (14:14; 28:3).").isEmpty)
        #expect(Self.links("To Hebron (Gen. 14:7) (13. Comp. 13:8)") == ["Gen. 14:7 = Genesis 14:7"])
    }

    @Test func aLoneNumberAfterAVerseIsNeitherChapterNorVerse() {
        #expect(Self.links("Kohath’s sister (Ex. 6:20; comp. 16).") == ["Ex. 6:20 = Exodus 6:20"])
        #expect(Self.unlinked("Kohath’s sister (Ex. 6:20; comp. 16).") == ["16 ambiguous"])
        #expect(Self.links("Three other cities (Josh. 9;17). (Hag. 1:5, 7;2:15)")
                == ["Josh. 9 = Joshua 9", "Hag. 1:5 = Haggai 1:5", "7 = Haggai 1:7", "2:15 = Haggai 2:15"])
    }

    @Test func anEntryNamedForABookTakesNoOtherBookForABareReference() {
        let text = "(Ezra 5:1; 6:14). Then follows a series of eight visions (1:7-6:8). He describes himself (Zech. 1:1) and (1:3)."
        let characters = Array(text)
        let found = DictionaryReferences.scan(text, subject: "Zechariah", lastVerses: Self.fakeLastVerses).links
            .map { "\(String(characters[$0.range])) = \($0.reference.displayString)" }
        #expect(found == ["Ezra 5:1 = Ezra 5:1", "6:14 = Ezra 6:14", "Zech. 1:1 = Zechariah 1:1", "1:3 = Zechariah 1:3"])
        #expect(Self.links(text).contains("1:7-6:8 = Ezra 1:7-80"))
    }

    // MARK: - Real entries

    private static func entry(person id: Int, store: BibleStore) throws -> String {
        try #require(try store.person(id)?.dictionary)
    }

    private static func lastVerses(_ store: BibleStore, translation: String = "KJV") -> (Book) -> [Int: Int] {
        var known: [String: [Int: Int]] = [:]
        return { book in
            if let last = known[book.id] { return last }
            let last = (try? store.lastVerses(ofBook: book.id, translationID: translation)) ?? [:]
            known[book.id] = last
            return last
        }
    }

    @Test(.needsRealBible) func benjaminsEntryLinksEveryReference() throws {
        let store = try BenchmarkChapter.realStore()
        let found = Self.links(try Self.entry(person: 463, store: store), lastVerses: Self.lastVerses(store))
        for expected in ["Gen. 35:18 = Genesis 35:18", "Num. 1:36 = Numbers 1:36", "37 = Numbers 1:37", "Ps. 68:27 = Psalm 68:27",
                         "Josh. 18:21-28 = Joshua 18:21-28", "21 = Judges 20:21", "21:10 = Judges 21:10", "Judge. 20:6 = Judges 20:6",
                         "Jer. 37:13 = Jeremiah 37:13", "38:7 = Jeremiah 38:7", "Zech. 14:10 = Zechariah 14:10",
                         "20:2 = Jeremiah 20:2", "17:19 = Jeremiah 17:19", "2 Kings 14:13 = 2 Kings 14:13"] {
            #expect(found.contains(expected), "\(expected)")
        }
        #expect(found.count == 32)
        #expect(!found.contains { $0.hasPrefix("26 ") || $0.hasPrefix("12 ") || $0.hasPrefix("600") })
    }

    @Test(.needsRealBible) func davidsAndLotsEntriesLinkWhatTheyCite() throws {
        let store = try BenchmarkChapter.realStore()
        let david = Self.links(try Self.entry(person: 994, store: store), lastVerses: Self.lastVerses(store))
        for expected in ["2 Sam. 17:25 = 2 Samuel 17:25", "1 Sam. 16:12 = 1 Samuel 16:12", "17:42 = 1 Samuel 17:42", "35 = 1 Samuel 17:35",
                         "1 Sam. 16:1-13 = 1 Samuel 16:1-13", "1 Sam. 17 = 1 Samuel 17", "Ps. 52 = Psalm 52"] {
            #expect(david.contains(expected), "\(expected)")
        }
        #expect(!david.contains { $0.hasPrefix("16 = ") })
        let lot = Self.links(try Self.entry(person: 1830, store: store), lastVerses: Self.lastVerses(store))
        #expect(lot.prefix(2) == ["Num. 33:54 = Numbers 33:54", "Jonah 1:7 = Jonah 1:7"])
        #expect(!lot.contains { $0.hasPrefix("Heb") })
    }

    /// Every person's and place's entry: how many references are linked, left plain and unsure, with a sample
    /// of the plain ones for the report. Prints `dictionary-references` lines.
    @Test(.needsRealBible) func theWholeDictionaryIsMeasured() throws {
        let store = try BenchmarkChapter.realStore()
        let lastVerses = Self.lastVerses(store)
        var entries: [(name: String, text: String)] = []
        // Each entry is scanned with its subject, as the pages do.
        for id in 1...7400 { if let person = try store.person(id), let text = person.dictionary { entries.append((person.name, text)) } }
        for id in 1...1303 { if let place = try store.place(id), let text = place.dictionary { entries.append((place.summary.name, text)) } }
        var linked = 0, ambiguous = 0, notABook = 0, missing = 0
        var samples: [String] = []
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for entry in entries {
                let scan = DictionaryReferences.scan(entry.text, subject: entry.name, lastVerses: lastVerses)
                linked += scan.links.count
                let characters = Array(entry.text)
                for plain in scan.unlinked {
                    switch plain.why {
                    case .ambiguous: ambiguous += 1
                    case .notABook: notABook += 1
                    case .notInTheTranslation: missing += 1
                    }
                    if samples.count < 400 {
                        let lower = max(0, plain.range.lowerBound - 40), upper = min(characters.count, plain.range.upperBound + 12)
                        samples.append("\(entry.name) [\(plain.why)]: …\(String(characters[lower..<upper]))…")
                    }
                }
            }
        }
        print("dictionary-references: \(entries.count) entries, \(linked) linked, \(notABook + missing) plain (\(notABook) not a book, "
              + "\(missing) not in the KJV), \(ambiguous) ambiguous, \(elapsed)")
        for (index, sample) in samples.enumerated() where index % 13 == 0 {
            print("dictionary-references sample: \(sample.replacingOccurrences(of: "\n", with: " "))")
        }
        if let path = ProcessInfo.processInfo.environment["DICTIONARY_REFERENCES_SAMPLES"] {
            try samples.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
        #expect(entries.count == 2773)
        #expect(linked > 8000)
    }
}

/// The entry's links as the view shows them: each shown text with the links wholly inside it, found once.
@MainActor @Suite struct DictionaryLinksTests {
    private static let entry = "The gate (Jer. 37:13; 38:7). Called by Jeremiah (20:2).\n\nAlso (Gen. 35:18)."

    private static func lastVerses(_ book: String) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: (1...60).map { ($0, 40) })
    }

    @Test func aShownTextCarriesTheLinksInsideItInTheAccent() throws {
        let links = DictionaryLinks()
        links.update(Self.entry, subject: nil, translationID: "KJV", lastVerses: Self.lastVerses)
        let first = links.linked("The gate (Jer. 37:13; 38:7). Called by Jeremiah (20:2).")
        #expect(first.references.map(\.displayString) == ["Jeremiah 37:13", "Jeremiah 38:7", "Jeremiah 20:2"])
        let runs = first.text.runs.filter { $0.link != nil }
        #expect(runs.map { String(first.text[$0.range].characters) } == ["Jer. 37:13", "38:7", "20:2"])
        #expect(runs.allSatisfy { $0.foregroundColor == Color.accent })
        #expect(runs.first?.link == ReferenceLinker.url(for: first.references[0]))
        // A cut first paragraph keeps only the links wholly inside it; the second paragraph has its own.
        #expect(links.linked("The gate (Jer. 37:13; 38:7).").references.count == 2)
        #expect(links.linked("Also (Gen. 35:18).").references.map(\.displayString) == ["Genesis 35:18"])
        #expect(links.linked("Not in the entry.").references.isEmpty)
    }

    @Test func theFirstParagraphIsScannedAloneUntilMoreIsShownThenTheEntryOnce() {
        let links = DictionaryLinks()
        var asked: [String] = []
        let counting: (String) -> [Int: Int] = { asked.append($0); return Self.lastVerses($0) }
        links.update(Self.entry, subject: nil, translationID: "KJV", lastVerses: counting)
        #expect(asked.isEmpty)
        _ = links.linked("The gate (Jer. 37:13; 38:7). Called by Jeremiah (20:2).")
        #expect(asked == ["JER"])
        _ = links.linked("The gate (Jer. 37:13; 38:7).")
        links.update(Self.entry, subject: nil, translationID: "KJV", lastVerses: counting)
        #expect(asked == ["JER"])
        // Show more: the whole entry, once.
        #expect(links.linked("Also (Gen. 35:18).").references.map(\.displayString) == ["Genesis 35:18"])
        _ = links.linked("The gate (Jer. 37:13; 38:7). Called by Jeremiah (20:2).")
        #expect(asked == ["JER", "JER", "GEN"])
        // Another translation is another scan.
        links.update(Self.entry, subject: nil, translationID: "ESV", lastVerses: counting)
        _ = links.linked("The gate (Jer. 37:13; 38:7).")
        #expect(asked.count == 4)
    }

    @Test func voiceOverHearsAReferenceAsTheVerseLinesSayIt() {
        let reference = Reference(book: BookCatalog.book(code: "JER")!, chapter: 37, verse: 13)
        #expect(VerseLines.spoken(reference) == "Jeremiah 37:13")
        #expect(VerseLines.spoken(Reference(book: BookCatalog.book(code: "JOS")!, chapter: 18, verse: 21, endVerse: 28)) == "Joshua 18:21 to 28")
    }
}
