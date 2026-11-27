import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite final class RecentsTests {
    private let suiteName = "RecentsTests-\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let store: RecentsStore
    private let esv = Translation(id: "ESV", title: "English Standard Version")
    /// Midnight, Monday 2 November 2026; `day: n` is n days after it.
    private let start = Date(timeIntervalSince1970: 1_793_577_600)

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        store = RecentsStore(defaults: defaults)
    }

    deinit {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    private func add(_ target: Recent.Target, _ translation: String?, day: Int) {
        store.record(target, translationID: translation, at: start.addingTimeInterval(Double(day) * 86_400))
    }

    private func john(_ chapter: Int) -> ChapterLocation { ChapterLocation(book: "JHN", chapter: chapter) }

    private func mark(_ kind: SearchMarkHit.Kind) -> Recent.Target {
        .mark(id: UUID(), kind: kind,
              target: MarkupTarget(location: john(15), verse: 5, translationID: nil, highlightID: nil), reference: "John 15:5")
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    /// The subtitle of such a `Recent` at noon on Monday 16 November 2026.
    private func says(_ target: Recent.Target, _ translation: String?, daysAgo: Int) -> String {
        let now = Date(timeIntervalSince1970: 1_794_830_400)   // 2026-11-16 12:00 UTC
        let date = now.addingTimeInterval(-Double(daysAgo) * 86_400)
        return Recent(target: target, translationID: translation, date: date).subtitle(now: now, calendar: utc)
    }

    @Test func theNewestTwentyAreKeptOncePerTargetAndOutliveTheStore() {
        for chapter in 1...25 { add(.chapter(john(chapter)), "ESV", day: chapter) }
        #expect(store.items.count == 20 && store.items.first?.target == .chapter(john(25)) && store.items.last?.target == .chapter(john(6)))
        add(.chapter(john(10)), "KJV", day: 30)                                     // again: to the front, once, as it is now
        #expect(store.items.count == 20 && store.items.first?.translationID == "KJV")
        // A lookup in the same chapter is its own row; a search is the same whatever its case and spacing.
        add(.lookup(john(10), verse: 4), "KJV", day: 31)
        add(.search(query: "Remain fruit", scope: .wholeBible, verseCount: 4), nil, day: 32)
        add(.search(query: "remain  FRUIT", scope: .wholeBible, verseCount: 5), nil, day: 33)
        #expect(store.items.prefix(3).map(\.title) == ["remain  FRUIT", "John 10:4", "John 10"])
        #expect(RecentsStore(defaults: defaults).items == store.items)
        store.clear()
        #expect(store.items.isEmpty && defaults.object(forKey: RecentsStore.key) == nil)
    }

    @Test func whatCannotBeReadOrOpenedIsLeftOut() {
        for chapter in 1...7 { add(.chapter(john(chapter)), chapter == 6 ? "NIV" : "ESV", day: chapter) }
        add(.lookup(john(7), verse: 2), "ESV", day: 8)
        // Five, without the chapter that is open or the row in a translation the app no longer has.
        #expect(store.shown(openChapter: john(7), translations: [esv]).map(\.title) == ["John 7:2", "John 5", "John 4", "John 3", "John 2"])
        // A list from another build, or damaged, reads as empty and can be written again.
        for junk in [Data("not a list".utf8) as Any, "a string"] {
            defaults.set(junk, forKey: RecentsStore.key)
            let fresh = RecentsStore(defaults: defaults)
            #expect(fresh.items.isEmpty)
            fresh.record(.chapter(john(1)), translationID: "ESV")
            #expect(RecentsStore(defaults: defaults).items.count == 1)
        }
    }

    @Test func eachRowSaysWhatItIsAndWhen() {
        #expect(says(.chapter(john(15)), "ESV", daysAgo: 1) == "Read yesterday · ESV")
        #expect(says(.lookup(john(15), verse: 5), "KJV", daysAgo: 6) == "Looked up Tuesday · KJV")
        #expect(says(.chapter(john(15)), "ESV", daysAgo: 0) == "Read today · ESV" && says(.chapter(john(15)), "ESV", daysAgo: 7) == "Read Nov 9 · ESV")
        #expect(says(.search(query: "remain fruit", scope: .wholeBible, verseCount: 12), nil, daysAgo: 0) == "Search · 12 verses")
        #expect(says(.search(query: "x", scope: .newTestament, verseCount: 1), nil, daysAgo: 0) == "Search · 1 verse · New Testament")
        #expect(says(mark(.note), nil, daysAgo: 3) == "Note" && says(mark(.thread), nil, daysAgo: 3) == "Conversation")
    }
}
