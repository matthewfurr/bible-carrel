import GRDB

/// The on-disk schema of `bible.sqlite`. Shared by the importer (writes) and `BibleStore` (reads).
public enum BibleSchema {
    public static let version = 6

    public static func create(in db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE translation (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL
            );
            CREATE TABLE book (
                id TEXT PRIMARY KEY,
                canon TEXT NOT NULL,
                sort_order INTEGER NOT NULL,
                name TEXT NOT NULL,
                short_name TEXT NOT NULL
            );
            CREATE TABLE translation_book (
                translation_id TEXT NOT NULL REFERENCES translation(id),
                book_id TEXT NOT NULL REFERENCES book(id),
                chapter_count INTEGER NOT NULL,
                first_verse_id INTEGER NOT NULL,
                last_verse_id INTEGER NOT NULL,
                PRIMARY KEY (translation_id, book_id)
            );
            CREATE TABLE verse (
                id INTEGER PRIMARY KEY,
                translation_id TEXT NOT NULL,
                book_id TEXT NOT NULL,
                chapter INTEGER NOT NULL,
                verse INTEGER NOT NULL,
                verse_end INTEGER,
                text TEXT NOT NULL,
                break_after INTEGER NOT NULL DEFAULT 0
            );
            CREATE UNIQUE INDEX verse_lookup ON verse(translation_id, book_id, chapter, verse);
            CREATE TABLE heading (
                source TEXT NOT NULL,
                book_id TEXT NOT NULL,
                chapter INTEGER NOT NULL,
                verse INTEGER NOT NULL,
                ordinal INTEGER NOT NULL,
                level INTEGER NOT NULL,
                text TEXT NOT NULL,
                PRIMARY KEY (source, book_id, chapter, verse, ordinal)
            );
            CREATE TABLE book_title (
                translation_id TEXT NOT NULL,
                book_id TEXT NOT NULL,
                title TEXT NOT NULL,
                subtitle TEXT,
                PRIMARY KEY (translation_id, book_id)
            );
            CREATE TABLE meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            CREATE TABLE cross_reference (
                source INTEGER NOT NULL, target_start INTEGER NOT NULL, target_end INTEGER NOT NULL, votes INTEGER NOT NULL,
                PRIMARY KEY (source, target_start, target_end)
            ) WITHOUT ROWID;
            CREATE INDEX cross_reference_target ON cross_reference(target_start, target_end);
            CREATE INDEX cross_reference_spanning ON cross_reference(target_end) WHERE target_end / 1000 > target_start / 1000;
            CREATE TABLE person (
                id INTEGER PRIMARY KEY, name TEXT NOT NULL, label TEXT, also_called TEXT NOT NULL,
                birth_year INTEGER, death_year INTEGER, verse_count INTEGER NOT NULL, search_names TEXT NOT NULL, dictionary TEXT
            );
            CREATE TABLE person_verse (verse INTEGER NOT NULL, person_id INTEGER NOT NULL, PRIMARY KEY (verse, person_id)) WITHOUT ROWID;
            CREATE INDEX person_verse_person ON person_verse(person_id, verse);
            CREATE TABLE person_relation (
                person_id INTEGER NOT NULL, kind TEXT NOT NULL, ordinal INTEGER NOT NULL, relative_id INTEGER NOT NULL,
                PRIMARY KEY (person_id, kind, ordinal)
            ) WITHOUT ROWID;
            CREATE TABLE place (
                id INTEGER PRIMARY KEY, name TEXT NOT NULL, label TEXT, also_called TEXT NOT NULL, kind TEXT,
                latitude REAL, longitude REAL, point TEXT, approximate INTEGER NOT NULL,
                verse_count INTEGER NOT NULL, search_names TEXT NOT NULL, dictionary TEXT
            );
            CREATE INDEX place_point ON place(point);
            CREATE TABLE place_verse (verse INTEGER NOT NULL, place_id INTEGER NOT NULL, PRIMARY KEY (verse, place_id)) WITHOUT ROWID;
            CREATE INDEX place_verse_place ON place_verse(place_id, verse);
            CREATE TABLE event (
                id INTEGER PRIMARY KEY, title TEXT NOT NULL, year INTEGER NOT NULL, sort_key REAL NOT NULL,
                duration_days REAL, part_of INTEGER, person_id INTEGER
            );
            CREATE TABLE event_passage (start INTEGER NOT NULL, event_id INTEGER NOT NULL, end INTEGER NOT NULL, PRIMARY KEY (start, event_id)) WITHOUT ROWID;
            CREATE TABLE book_writer (book_id TEXT NOT NULL, ordinal INTEGER NOT NULL, person_id INTEGER NOT NULL, PRIMARY KEY (book_id, ordinal)) WITHOUT ROWID;
            """)
    }

    /// "verse_fts_ESV"; nil unless the id is ASCII letters and digits (the name goes into SQL).
    public static func searchTable(for translationID: String) -> String? {
        name("verse_fts_", translationID)
    }

    /// "verse_vocab_ESV": the index's own word list.
    public static func vocabularyTable(for translationID: String) -> String? {
        name("verse_vocab_", translationID)
    }

    private static func name(_ prefix: String, _ translationID: String) -> String? {
        guard !translationID.isEmpty,
              translationID.unicodeScalars.allSatisfy({ $0.isASCII && ($0.properties.isAlphabetic || ("0"..."9").contains($0)) })
        else { return nil }
        return prefix + translationID
    }

    /// Creates and fills both for one translation, once its verses are in. The index holds no text of its
    /// own (contentless): its row ids are the verses' ids, so a scope is a range of ids.
    public static func createSearchIndex(for translationID: String, in db: Database) throws {
        guard let table = searchTable(for: translationID), let vocabulary = vocabularyTable(for: translationID) else {
            throw BibleSchemaError.invalidTranslationID(translationID)
        }
        try db.execute(sql: "CREATE VIRTUAL TABLE \(table) USING fts5(text, content='', tokenize='unicode61 remove_diacritics 2')")
        try db.execute(
            sql: "INSERT INTO \(table)(rowid, text) SELECT id, text FROM verse WHERE translation_id = ? ORDER BY id",
            arguments: [translationID])
        try db.execute(sql: "INSERT INTO \(table)(\(table)) VALUES('optimize')")
        try db.execute(sql: "CREATE VIRTUAL TABLE \(vocabulary) USING fts5vocab('\(table)', 'row')")
    }
}

public enum BibleSchemaError: Error, Equatable {
    case invalidTranslationID(String)
}
