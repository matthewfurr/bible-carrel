import Foundation

/// One of BibleProject's book overview videos: its title as BibleProject names it ("John 1–12")
/// and its page on bibleproject.com, which plays it.
public struct BookVideo: Hashable, Sendable, Identifiable {
    public let title: String
    public let url: URL
    public var id: URL { url }

    init(_ title: String, _ path: String) {
        self.title = title
        self.url = URL(string: "https://bibleproject.com/videos/" + path)!
    }
}

/// BibleProject's book overview videos by book (spec 5.2), from its Old and New Testament
/// Overviews collections on bibleproject.com, compiled 2026-11-13 with every page seen to load.
/// A book may have two (Genesis, John) and a video may cover several books (1 & 2 Kings, 1–3
/// John), listed under each. Books of the Apocrypha have none here. Nothing is fetched: the app
/// only opens the page.
public enum BibleProjectVideos {
    /// The book's overview videos, in the book's order; empty when it has none.
    public static func videos(forBook code: String) -> [BookVideo] {
        table[code] ?? []
    }

    static let table: [String: [BookVideo]] = [
        "GEN": [.init("Genesis 1–11", "genesis-1-11/"), .init("Genesis 12–50", "genesis-12-50/")],
        "EXO": [.init("Exodus 1–18", "exodus-1-18/"), .init("Exodus 19–40", "exodus-19-40/")],
        "LEV": [.init("Leviticus", "leviticus/")],
        "NUM": [.init("Numbers", "numbers/")],
        "DEU": [.init("Deuteronomy", "deuteronomy/")],
        "JOS": [.init("Joshua", "joshua/")],
        "JDG": [.init("Judges", "judges/")],
        "RUT": [.init("Ruth", "ruth/")],
        "1SA": [.init("1 Samuel", "1-samuel/")],
        "2SA": [.init("2 Samuel", "2-samuel/")],
        "1KI": [.init("1 & 2 Kings", "kings/")],
        "2KI": [.init("1 & 2 Kings", "kings/")],
        "1CH": [.init("1 & 2 Chronicles", "chronicles/")],
        "2CH": [.init("1 & 2 Chronicles", "chronicles/")],
        "EZR": [.init("Ezra–Nehemiah", "ezra-nehemiah/")],
        "NEH": [.init("Ezra–Nehemiah", "ezra-nehemiah/")],
        "EST": [.init("Esther", "esther/")],
        "JOB": [.init("Job", "job/")],
        "PSA": [.init("Psalms", "psalms/")],
        "PRO": [.init("Proverbs", "proverbs/")],
        "ECC": [.init("Ecclesiastes", "ecclesiastes/")],
        "SNG": [.init("Song of Songs", "song-songs/")],
        "ISA": [.init("Isaiah 1–39", "isaiah-1-39/"), .init("Isaiah 40–66", "isaiah-40-66/")],
        "JER": [.init("Jeremiah", "jeremiah/")],
        "LAM": [.init("Lamentations", "lamentations/")],
        "EZK": [.init("Ezekiel 1–33", "ezekiel-1-33/"), .init("Ezekiel 34–48", "ezekiel-34-48/")],
        "DAN": [.init("Daniel", "daniel/")],
        "HOS": [.init("Hosea", "hosea/")],
        "JOL": [.init("Joel", "joel/")],
        "AMO": [.init("Amos", "amos/")],
        "OBA": [.init("Obadiah", "obadiah/")],
        "JON": [.init("Jonah", "jonah/")],
        "MIC": [.init("Micah", "micah/")],
        "NAM": [.init("Nahum", "nahum/")],
        "HAB": [.init("Habakkuk", "habakkuk/")],
        "ZEP": [.init("Zephaniah", "zephaniah/")],
        "HAG": [.init("Haggai", "haggai/")],
        "ZEC": [.init("Zechariah", "zechariah/")],
        "MAL": [.init("Malachi", "malachi/")],
        "MAT": [.init("Matthew 1–13", "matthew-1-13/"), .init("Matthew 14–28", "matthew-14-28/")],
        "MRK": [.init("Mark", "mark/")],
        "LUK": [.init("Luke 1–9", "luke-1-9/"), .init("Luke 10–24", "luke-10-24/")],
        "JHN": [.init("John 1–12", "john-1-12/"), .init("John 13–21", "john-13-21/")],
        "ACT": [.init("Acts 1–12", "acts-1-12/"), .init("Acts 13–28", "acts-13-28/")],
        "ROM": [.init("Romans 1–4", "romans-1-4/"), .init("Romans 5–16", "romans-5-16/")],
        "1CO": [.init("1 Corinthians", "1-corinthians/")],
        "2CO": [.init("2 Corinthians", "2-corinthians/")],
        "GAL": [.init("Galatians", "galatians/")],
        "EPH": [.init("Ephesians", "ephesians/")],
        "PHP": [.init("Philippians", "philippians/")],
        "COL": [.init("Colossians", "colossians/")],
        "1TH": [.init("1 Thessalonians", "1-thessalonians/")],
        "2TH": [.init("2 Thessalonians", "2-thessalonians/")],
        "1TI": [.init("1 Timothy", "1-timothy/")],
        "2TI": [.init("2 Timothy", "2-timothy/")],
        "TIT": [.init("Titus", "titus/")],
        "PHM": [.init("Philemon", "philemon/")],
        "HEB": [.init("Hebrews", "hebrews/")],
        "JAS": [.init("James", "james/")],
        "1PE": [.init("1 Peter", "1-peter/")],
        "2PE": [.init("2 Peter", "2-peter/")],
        "1JN": [.init("1–3 John", "1-3-john/")],
        "2JN": [.init("1–3 John", "1-3-john/")],
        "3JN": [.init("1–3 John", "1-3-john/")],
        "JUD": [.init("Jude", "jude/")],
        "REV": [.init("Revelation 1–11", "revelation-1-11/"), .init("Revelation 12–22", "revelation-12-22/")],
    ]
}
