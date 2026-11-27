import BibleImporterCore
import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// Psalm 119 in the KJV, the spec's long-chapter benchmark, as the app sees it: the raw holybooks
/// chapter run through `VerseMerger`, so line breaks and `breakAfter` match an imported chapter.
/// The fixture sits outside `Fixtures/EN` so `SourceTree` never imports it.
enum BenchmarkChapter {
    private struct Chapter: Decodable {
        let ID: String
        let name: String
        let text: [HolyBookFile.Entry]
    }

    static func psalm119() throws -> [Verse] {
        let url = try #require(Bundle.module.url(forResource: "PSA-119-KJV", withExtension: "json", subdirectory: "Fixtures/Benchmarks"))
        let chapter = try JSONDecoder().decode(Chapter.self, from: Data(contentsOf: url))
        var warnings: [ImportWarning] = []
        return VerseMerger.merge(chapter.text, warnings: &warnings).map {
            Verse(id: VerseLocation(book: "PSA", chapter: 119, verse: $0.number), translationID: "KJV", endVerse: $0.endNumber, text: $0.text, breakAfter: $0.breakAfter)
        }
    }

    /// Sixty highlights of a few words each, spread through the section's verses, ten of them
    /// overlapping, and three bookmarks: the spec's Psalm 119 benchmark load, on both platforms.
    @MainActor static func sixtyHighlights(in section: BookSection) -> BookDecorations {
        var highlights: [RangeDecoration] = []
        for (index, span) in section.spans.enumerated() where index % 3 == 0 {
            let length = min(18, span.textRange.length)
            highlights.append(RangeDecoration(id: UUID(), range: NSRange(location: span.textRange.location, length: length), style: .background(MarkupColor(lightHex: "#F8E18A", darkHex: "#554704"))))
            if index % 18 == 0 {
                highlights.append(RangeDecoration(id: UUID(), range: NSRange(location: span.textRange.location + 6, length: length), style: .background(MarkupColor(lightHex: "#B8E8FF", darkHex: "#144D6E"))))
            }
        }
        let bookmarks = [8, 105, 176].map { VerseLocation(book: section.location.book, chapter: section.location.chapter, verse: $0) }
        return BookDecorations(highlights: highlights, bookmarks: bookmarks, outlinedID: nil)
    }

    /// The real bundle database, `Build/bible.sqlite` at the repository root (five levels up from
    /// this file).
    static let realStoreURL: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        return url.appendingPathComponent("Build/bible.sqlite")
    }()

    static var hasRealStore: Bool { FileManager.default.fileExists(atPath: realStoreURL.path) }

    /// The real bundle database. A test that reads it carries `.needsRealBible`, so it runs only
    /// when the database has been built and is reported as skipped (with the reason) otherwise.
    static func realStore() throws -> BibleStore {
        try BibleStore(databaseURL: realStoreURL)
    }
}

extension Trait where Self == ConditionTrait {
    /// Runs the test only when `Build/bible.sqlite` exists; otherwise it is skipped with a visible
    /// reason, so a fresh clone does not report the real-data tests as passing.
    static var needsRealBible: Self {
        .enabled(if: BenchmarkChapter.hasRealStore, "Needs Build/bible.sqlite: run Scripts/ensure-bible.sh")
    }
}
