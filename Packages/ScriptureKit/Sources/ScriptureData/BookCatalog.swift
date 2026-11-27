/// The fixed list of books the app knows about, in canon order.
public enum BookCatalog {
    public static let all: [Book] = {
        var order = 0
        func make(_ canon: Canon, _ entries: [(String, String, String, [String])]) -> [Book] {
            entries.map { code, name, short, aliases in
                order += 1
                return Book(id: code, canon: canon, order: order, name: name, shortName: short, aliases: aliases)
            }
        }
        return make(.oldTestament, oldTestament) + make(.newTestament, newTestament) + make(.apocrypha, apocrypha)
    }()

    private static let byCode: [String: Book] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func book(code: String) -> Book? {
        byCode[code]
    }

    // (code, name, shortName, aliases)
    private static let oldTestament: [(String, String, String, [String])] = [
        ("GEN", "Genesis", "Gen", ["Ge", "Gn"]),
        ("EXO", "Exodus", "Exod", ["Ex", "Exo"]),
        ("LEV", "Leviticus", "Lev", ["Le", "Lv"]),
        ("NUM", "Numbers", "Num", ["Nu", "Nm", "Nb"]),
        ("DEU", "Deuteronomy", "Deut", ["De", "Dt"]),
        ("JOS", "Joshua", "Josh", ["Jos", "Jsh"]),
        ("JDG", "Judges", "Judg", ["Jdg", "Jg", "Jdgs"]),
        ("RUT", "Ruth", "Ruth", ["Rth", "Ru"]),
        ("1SA", "1 Samuel", "1 Sam", ["1 Sm", "1Sa", "I Samuel"]),
        ("2SA", "2 Samuel", "2 Sam", ["2 Sm", "2Sa", "II Samuel"]),
        ("1KI", "1 Kings", "1 Kgs", ["1 Ki", "1Kgs", "I Kings"]),
        ("2KI", "2 Kings", "2 Kgs", ["2 Ki", "2Kgs", "II Kings"]),
        ("1CH", "1 Chronicles", "1 Chr", ["1 Ch", "1Chron", "I Chronicles"]),
        ("2CH", "2 Chronicles", "2 Chr", ["2 Ch", "2Chron", "II Chronicles"]),
        ("EZR", "Ezra", "Ezra", ["Ezr"]),
        ("NEH", "Nehemiah", "Neh", ["Ne"]),
        ("EST", "Esther", "Esth", ["Es", "Est"]),
        ("JOB", "Job", "Job", ["Jb"]),
        ("PSA", "Psalms", "Ps", ["Psalm", "Pss", "Psa", "Psm"]),
        ("PRO", "Proverbs", "Prov", ["Pr", "Prv", "Pro"]),
        ("ECC", "Ecclesiastes", "Eccl", ["Ec", "Ecc", "Qoheleth"]),
        ("SNG", "Song of Solomon", "Song", ["Song of Songs", "Canticles", "SoS", "Sg", "Cant"]),
        ("ISA", "Isaiah", "Isa", ["Is"]),
        ("JER", "Jeremiah", "Jer", ["Je", "Jr"]),
        ("LAM", "Lamentations", "Lam", ["La"]),
        ("EZK", "Ezekiel", "Ezek", ["Eze", "Ezk"]),
        ("DAN", "Daniel", "Dan", ["Da", "Dn"]),
        ("HOS", "Hosea", "Hos", ["Ho"]),
        ("JOL", "Joel", "Joel", ["Jl", "Joe"]),
        ("AMO", "Amos", "Amos", ["Am"]),
        ("OBA", "Obadiah", "Obad", ["Ob", "Oba"]),
        ("JON", "Jonah", "Jonah", ["Jnh", "Jon"]),
        ("MIC", "Micah", "Mic", ["Mc"]),
        ("NAM", "Nahum", "Nah", ["Na", "Nam"]),
        ("HAB", "Habakkuk", "Hab", ["Hb"]),
        ("ZEP", "Zephaniah", "Zeph", ["Zep", "Zp"]),
        ("HAG", "Haggai", "Hag", ["Hg"]),
        ("ZEC", "Zechariah", "Zech", ["Zec", "Zc"]),
        ("MAL", "Malachi", "Mal", ["Ml"]),
    ]

    private static let newTestament: [(String, String, String, [String])] = [
        ("MAT", "Matthew", "Matt", ["Mt", "Mat"]),
        ("MRK", "Mark", "Mark", ["Mk", "Mr", "Mrk"]),
        ("LUK", "Luke", "Luke", ["Lk", "Lu", "Luk"]),
        ("JHN", "John", "John", ["Jn", "Jhn"]),
        ("ACT", "Acts", "Acts", ["Ac", "Act"]),
        ("ROM", "Romans", "Rom", ["Ro", "Rm"]),
        ("1CO", "1 Corinthians", "1 Cor", ["1 Co", "1Cor", "I Corinthians"]),
        ("2CO", "2 Corinthians", "2 Cor", ["2 Co", "2Cor", "II Corinthians"]),
        ("GAL", "Galatians", "Gal", ["Ga"]),
        ("EPH", "Ephesians", "Eph", ["Ep"]),
        ("PHP", "Philippians", "Phil", ["Php", "Pp"]),
        ("COL", "Colossians", "Col", ["Co"]),
        ("1TH", "1 Thessalonians", "1 Thess", ["1 Th", "1Thes", "I Thessalonians"]),
        ("2TH", "2 Thessalonians", "2 Thess", ["2 Th", "2Thes", "II Thessalonians"]),
        ("1TI", "1 Timothy", "1 Tim", ["1 Ti", "1Tm", "I Timothy"]),
        ("2TI", "2 Timothy", "2 Tim", ["2 Ti", "2Tm", "II Timothy"]),
        ("TIT", "Titus", "Titus", ["Ti", "Tit"]),
        ("PHM", "Philemon", "Phlm", ["Philem", "Phm", "Pm"]),
        ("HEB", "Hebrews", "Heb", ["He"]),
        ("JAS", "James", "Jas", ["Jm", "Ja"]),
        ("1PE", "1 Peter", "1 Pet", ["1 Pe", "1Pt", "I Peter"]),
        ("2PE", "2 Peter", "2 Pet", ["2 Pe", "2Pt", "II Peter"]),
        ("1JN", "1 John", "1 John", ["1 Jn", "1Jn", "I John"]),
        ("2JN", "2 John", "2 John", ["2 Jn", "2Jn", "II John"]),
        ("3JN", "3 John", "3 John", ["3 Jn", "3Jn", "III John"]),
        ("JUD", "Jude", "Jude", ["Jd", "Jud"]),
        ("REV", "Revelation", "Rev", ["Revelations", "Re", "Apocalypse"]),
    ]

    private static let apocrypha: [(String, String, String, [String])] = [
        ("TOB", "Tobit", "Tob", ["Tb"]),
        ("JDT", "Judith", "Jdt", ["Jth"]),
        ("ESG", "Esther (Greek)", "Esth Gr", ["Greek Esther", "Additions to Esther"]),
        ("WIS", "Wisdom of Solomon", "Wis", ["Wisdom", "Ws"]),
        ("SIR", "Sirach", "Sir", ["Ecclesiasticus", "Ecclus"]),
        ("BAR", "Baruch", "Bar", ["Ba"]),
        ("LJE", "Letter of Jeremiah", "Let Jer", ["Epistle of Jeremiah", "EpJer"]),
        ("S3Y", "Prayer of Azariah", "Pr Azar", ["Song of the Three Young Men", "Song of Three"]),
        ("SUS", "Susanna", "Sus", []),
        ("BEL", "Bel and the Dragon", "Bel", []),
        ("1MA", "1 Maccabees", "1 Macc", ["1 Mac", "I Maccabees"]),
        ("2MA", "2 Maccabees", "2 Macc", ["2 Mac", "II Maccabees"]),
        ("1ES", "1 Esdras", "1 Esd", ["1 Es", "I Esdras"]),
        ("MAN", "Prayer of Manasseh", "Pr Man", ["Manasseh", "Manasses"]),
        ("PS2", "Psalm 151", "Ps 151", ["Psalm CLI"]),
        ("3MA", "3 Maccabees", "3 Macc", ["3 Mac", "III Maccabees"]),
        ("2ES", "2 Esdras", "2 Esd", ["2 Es", "II Esdras"]),
        ("4MA", "4 Maccabees", "4 Macc", ["4 Mac", "IV Maccabees"]),
    ]
}
