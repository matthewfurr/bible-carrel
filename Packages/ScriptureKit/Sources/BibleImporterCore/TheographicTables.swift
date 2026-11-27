import Foundation
import ScriptureData

/// The people, places, families and events of Theographic Bible Metadata (CC BY-SA 4.0), read from its
/// `books.json`, `people.json`, `places.json`, `events.json` and `verses.json` and put in the shape the
/// Bible database keeps them in. Every record is keyed by the data's own integer id, every verse by `VerseKey`.
public enum TheographicTables {
    public struct Person: Equatable, Sendable {
        public let id: Int, name: String, label: String?, alsoCalled: [String]
        public let birthYear: Int?, deathYear: Int?, searchNames: String, dictionary: String?
        /// Verse keys, ascending.
        public let verses: [Int]
    }

    public struct Relation: Equatable, Sendable {
        public let personID: Int, kind: String, ordinal: Int, relativeID: Int
    }

    public struct Place: Equatable, Sendable {
        public let id: Int, name: String, label: String?, alsoCalled: [String], kind: String?
        public let latitude: Double?, longitude: Double?, point: String?, isApproximate: Bool
        public let searchNames: String, dictionary: String?, verses: [Int]
    }

    public struct Event: Equatable, Sendable {
        public let id: Int, title: String, year: Int, sortKey: Double, passages: [ClosedRange<Int>]
        /// How long it lasts, in days; nil when the data's length is not read.
        public let durationDays: Double?
        /// The event it is part of: a life when it is part of one, else the first.
        public let partOf: Int?
        /// The person of a "Lifetime of" event.
        public let personID: Int?
    }

    public struct Writer: Equatable, Sendable {
        public let book: String, ordinal: Int, personID: Int
    }

    public struct Tables: Equatable, Sendable {
        public let people: [Person], relations: [Relation], places: [Place], events: [Event], writers: [Writer]
    }

    /// The kinds of relation, in the order they are written.
    static let relationKinds = ["father", "mother", "partner", "sibling", "halfSibling", "child"]

    // MARK: Loading

    /// Reads the five tables in `folder`. A record that cannot be used is left out with a warning.
    public static func load(from folder: URL, warnings: inout [ImportWarning]) throws -> Tables {
        let verses = try VerseTable(records: read("verses.json", in: folder, as: VerseFields.self, warnings: &warnings), warnings: &warnings)
        let peopleRecords = try read("people.json", in: folder, as: PersonFields.self, warnings: &warnings)
        let placeRecords = try read("places.json", in: folder, as: PlaceFields.self, warnings: &warnings)
        let eventRecords = try read("events.json", in: folder, as: EventFields.self, warnings: &warnings)
        let bookRecords = try read("books.json", in: folder, as: BookFields.self, warnings: &warnings)

        let (people, relations, personIDsByLookup, personIDsByRecord) = buildPeople(peopleRecords, verses: verses, warnings: &warnings)
        let places = buildPlaces(placeRecords, verses: verses, warnings: &warnings)
        let events = buildEvents(eventRecords, verses: verses, personIDsByRecord: personIDsByRecord, warnings: &warnings)
        let writers = buildWriters(bookRecords, personIDsByLookup: personIDsByLookup, warnings: &warnings)
        return Tables(people: people, relations: relations, places: places, events: events, writers: writers)
    }

    // MARK: The pure helpers

    /// A length such as "930Y" or "1Y6M" in days: one or more `<number><unit>`, a number being digits with at
    /// most one ".", and a unit `Y` (365.25 days), `M` (30.44), `W` (7) or `D` (1); nil for anything else.
    static func days(_ duration: String) -> Double? {
        let units: [Character: Double] = ["Y": 365.25, "M": 30.44, "W": 7, "D": 1]
        var total = 0.0
        var number = ""
        var parts = 0
        for character in duration {
            if character.isASCII, character.isNumber {
                number.append(character)
            } else if character == ".", !number.contains(".") {
                number.append(character)
            } else if let unit = units[character], number.contains(where: \.isNumber), let amount = Double(number) {
                total += amount * unit
                number = ""
                parts += 1
            } else {
                return nil
            }
        }
        return number.isEmpty && parts > 0 ? total : nil
    }

    /// The leading whole number, signed: "-1995" is -1995, "0030-05-01" is 30; nil when the text does not begin with one.
    static func year(_ text: String) -> Int? {
        let scalars = Array(text.trimmingCharacters(in: .whitespaces).unicodeScalars)
        var end = 0
        if end < scalars.count, scalars[end] == "-" { end += 1 }
        let digitsStart = end
        while end < scalars.count, ("0"..."9").contains(scalars[end]) { end += 1 }
        guard end > digitsStart else { return nil }
        var number = ""
        number.unicodeScalars.append(contentsOf: scalars[0..<end])
        return Int(number)
    }

    /// A title's trailing "(…)" is its label: "Jacob (Israel)" is "Jacob" and "Israel".
    static func shownName(_ displayTitle: String) -> (name: String, label: String?) {
        let title = displayTitle.trimmingCharacters(in: .whitespaces)
        guard title.hasSuffix(")"), let open = title.lastIndex(of: "(") else { return (title, nil) }
        let inner = title[title.index(after: open)..<title.index(before: title.endIndex)]
        let name = title[..<open].trimmingCharacters(in: .whitespaces)
        let label = inner.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !label.isEmpty, !inner.contains("(") else { return (title, nil) }
        return (name, label)
    }

    /// Markdown to plain text: each `[label](target)` is `label`; paragraphs split at blank lines keep one
    /// line each and are joined by a blank line.
    static func plainText(_ markdown: String) -> String {
        let linked = markdown.replacing(/\[([^\]]*)\]\([^)]*\)/) { String($0.1) }
        var paragraphs: [String] = []
        var lines: [String] = []
        func close() {
            if !lines.isEmpty { paragraphs.append(lines.joined(separator: " ")) }
            lines = []
        }
        for line in linked.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { close() } else { lines.append(trimmed) }
        }
        close()
        return paragraphs.joined(separator: "\n\n")
    }

    /// Every word of every name, each once, in order, each led by a space: " jacob israel".
    static func searchNames(_ names: [String]) -> String {
        var seen = Set<String>()
        var result = ""
        for name in names {
            for token in SearchQuery.tokens(in: name) where seen.insert(token.word).inserted {
                result += " " + token.word
            }
        }
        return result
    }

    /// A place's spot to about 110 m: "31.777,35.235".
    static func pointKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.3f,%.3f", latitude, longitude)
    }

    /// What tells apart those who share a shown name. `own` is the title's "(…)"; `relation` the first of parent, child, partner.
    static func labels(_ people: [(id: Int, name: String, own: String?, relation: String?, firstVerse: String)]) -> [Int: String] {
        let byName = Dictionary(grouping: people, by: \.name)
        var labels: [Int: String] = [:]
        for person in people {
            if let own = person.own, !own.isEmpty {
                labels[person.id] = own
            } else if byName[person.name, default: []].count > 1 {
                if let relation = person.relation, !relation.isEmpty {
                    labels[person.id] = relation
                } else if !person.firstVerse.isEmpty {
                    labels[person.id] = person.firstVerse
                }
            }
        }
        for group in byName.values where group.count > 1 {
            var uses: [String: Int] = [:]
            for person in group { if let label = labels[person.id] { uses[label, default: 0] += 1 } }
            for person in group {
                guard let label = labels[person.id], uses[label, default: 0] > 1,
                      !person.firstVerse.isEmpty, label != person.firstVerse else { continue }
                labels[person.id] = label + ", " + person.firstVerse
            }
        }
        return labels
    }

    // MARK: People

    private static func buildPeople(
        _ records: [Record<PersonFields>], verses: VerseTable, warnings: inout [ImportWarning]
    ) -> (people: [Person], relations: [Relation], idsByLookup: [String: Int], idsByRecord: [String: Int]) {
        var seen = Set<Int>()
        var kept: [(record: String, fields: PersonFields)] = []
        for record in records {
            guard seen.insert(record.fields.personID).inserted else {
                warnings.append(ImportWarning("Skipped person \(record.fields.personLookup ?? String(record.fields.personID)): the id is used twice"))
                continue
            }
            kept.append((record.id, record.fields))
        }
        kept.sort { $0.fields.personID < $1.fields.personID }
        var idsByRecord: [String: Int] = [:]
        var idsByLookup: [String: Int] = [:]
        for (record, fields) in kept {
            idsByRecord[record] = fields.personID
            if let lookup = fields.personLookup { idsByLookup[lookup] = fields.personID }
        }
        var shownNames: [Int: String] = [:]
        for (_, fields) in kept { shownNames[fields.personID] = shownName(fields.displayTitle).name }

        var relations: [Relation] = []
        var firstRelative: [Int: (parent: Int?, child: Int?, partner: Int?)] = [:]
        var people: [Person] = []
        var labelInputs: [(id: Int, name: String, own: String?, relation: String?, firstVerse: String)] = []
        for (_, fields) in kept {
            let id = fields.personID
            let (shown, own) = shownName(fields.displayTitle)
            let lists: [(String, [String])] = [
                ("father", fields.father ?? []), ("mother", fields.mother ?? []), ("partner", fields.partners ?? []),
                ("sibling", fields.siblings ?? []), ("halfSibling", (fields.halfSiblingsSameFather ?? []) + (fields.halfSiblingsSameMother ?? [])),
                ("child", fields.children ?? []),
            ]
            var firstOf: [String: Int] = [:]
            for (kind, list) in lists {
                for (ordinal, link) in list.enumerated() {
                    guard let relative = idsByRecord[link] else {
                        warnings.append(ImportWarning("Skipped \(kind) \(link) of person \(id): not among the people"))
                        continue
                    }
                    relations.append(Relation(personID: id, kind: kind, ordinal: ordinal, relativeID: relative))
                    if firstOf[kind] == nil { firstOf[kind] = relative }
                }
            }
            firstRelative[id] = (firstOf["father"] ?? firstOf["mother"], firstOf["child"], firstOf["partner"])

            let personVerses = verses.keys(of: fields.verses, owner: "person \(id)", warnings: &warnings)
            let alsoCalledField = splitList(fields.alsoCalled)
            let name = fields.name ?? shown
            var seenNames = Set([shown.lowercased(), name.lowercased()])
            var alsoCalled: [String] = []
            for entry in alsoCalledField where seenNames.insert(entry.lowercased()).inserted { alsoCalled.append(entry) }
            let dictionary = fields.dictText?.first.map(plainText)
            people.append(Person(
                id: id, name: shown, label: nil, alsoCalled: alsoCalled,
                birthYear: fields.birthYear.flatMap { year($0.value) }, deathYear: fields.deathYear.flatMap { year($0.value) },
                searchNames: searchNames([shown, name] + (fields.surname.map { [$0] } ?? []) + alsoCalledField),
                dictionary: dictionary?.isEmpty == false ? dictionary : nil, verses: personVerses))
            labelInputs.append((id, shown, own, nil, personVerses.first.map(displayString) ?? ""))
        }

        // What each person is to the first of their parent, child and partner, for the labels.
        let genders = Dictionary(uniqueKeysWithValues: kept.map { ($0.fields.personID, $0.fields.gender == "Female") })
        for index in labelInputs.indices {
            let id = labelInputs[index].id
            let female = genders[id] ?? false
            guard let first = firstRelative[id] else { continue }
            if let parent = first.parent, let name = shownNames[parent] {
                labelInputs[index].relation = (female ? "daughter of " : "son of ") + name
            } else if let child = first.child, let name = shownNames[child] {
                labelInputs[index].relation = (female ? "mother of " : "father of ") + name
            } else if let partner = first.partner, let name = shownNames[partner] {
                labelInputs[index].relation = (female ? "wife of " : "husband of ") + name
            }
        }
        let labelled = labels(labelInputs)
        people = people.map {
            Person(id: $0.id, name: $0.name, label: labelled[$0.id], alsoCalled: $0.alsoCalled, birthYear: $0.birthYear,
                   deathYear: $0.deathYear, searchNames: $0.searchNames, dictionary: $0.dictionary, verses: $0.verses)
        }
        let kindOrder = Dictionary(uniqueKeysWithValues: relationKinds.enumerated().map { ($1, $0) })
        relations.sort {
            if $0.personID != $1.personID { return $0.personID < $1.personID }
            if $0.kind != $1.kind { return kindOrder[$0.kind, default: 0] < kindOrder[$1.kind, default: 0] }
            return $0.ordinal < $1.ordinal
        }
        return (people, relations, idsByLookup, idsByRecord)
    }

    // MARK: Places

    private static func buildPlaces(_ records: [Record<PlaceFields>], verses: VerseTable, warnings: inout [ImportWarning]) -> [Place] {
        var seen = Set<Int>()
        var kept: [(fields: PlaceFields, verses: [Int])] = []
        for record in records.sorted(by: { $0.fields.placeID < $1.fields.placeID }) {
            guard seen.insert(record.fields.placeID).inserted else {
                warnings.append(ImportWarning("Skipped place \(record.fields.placeLookup ?? String(record.fields.placeID)): the id is used twice"))
                continue
            }
            let placeVerses = verses.keys(of: record.fields.verses, owner: "place \(record.fields.placeID)", warnings: &warnings)
            if !placeVerses.isEmpty { kept.append((record.fields, placeVerses)) }
        }
        var counts: [String: Int] = [:]
        for (fields, _) in kept { counts[shownName(fields.displayTitle).name, default: 0] += 1 }

        return kept.map { fields, placeVerses in
            let (shown, own) = shownName(fields.displayTitle)
            let label = own ?? (counts[shown, default: 0] > 1 ? displayString(placeVerses[0]) : nil)
            let aliases = splitList(fields.aliases)
            var seenNames = Set([shown.lowercased()])
            var alsoCalled: [String] = []
            for entry in [fields.kjvName, fields.esvName].compactMap({ $0?.trimmingCharacters(in: .whitespaces) }) + aliases
            where !entry.isEmpty && seenNames.insert(entry.lowercased()).inserted {
                alsoCalled.append(entry)
            }
            let kind = [fields.featureSubType, fields.featureType].lazy.compactMap { $0 }.first { !$0.isEmpty }?.lowercased()
            var latitude = fields.latitude.flatMap { Double($0.value) }, longitude = fields.longitude.flatMap { Double($0.value) }
            if latitude == nil || longitude == nil || fields.precision == "Unlocated" { latitude = nil; longitude = nil }
            let dictionary = fields.dictText?.first.map(plainText)
            return Place(
                id: fields.placeID, name: shown, label: label, alsoCalled: alsoCalled, kind: kind,
                latitude: latitude, longitude: longitude,
                point: latitude.flatMap { lat in longitude.map { pointKey(latitude: lat, longitude: $0) } },
                isApproximate: ["Rough", "Related-Surrounding", "Related-Within"].contains(fields.precision ?? ""),
                searchNames: searchNames([shown, fields.kjvName, fields.esvName].compactMap { $0 } + aliases),
                dictionary: dictionary?.isEmpty == false ? dictionary : nil, verses: placeVerses)
        }
    }

    // MARK: Events

    private static func buildEvents(
        _ records: [Record<EventFields>], verses: VerseTable, personIDsByRecord: [String: Int], warnings: inout [ImportWarning]
    ) -> [Event] {
        var seen = Set<Int>()
        var kept: [(record: String, fields: EventFields, year: Int)] = []
        for record in records {
            let fields = record.fields
            guard let year = fields.startDate.flatMap({ year($0.value) }) else {
                warnings.append(ImportWarning("Skipped event \(fields.eventID) (\(fields.title)): no year"))
                continue
            }
            guard seen.insert(fields.eventID).inserted else {
                warnings.append(ImportWarning("Skipped event \(fields.eventID) (\(fields.title)): the id is used twice"))
                continue
            }
            kept.append((record.id, fields, year))
        }
        var idsByRecord: [String: Int] = [:]
        var titles: [Int: String] = [:]
        for (record, fields, _) in kept {
            idsByRecord[record] = fields.eventID
            titles[fields.eventID] = fields.title
        }
        for correction in TheographicCorrections.all {
            for id in correction.eventIDs where titles[id] == nil {
                warnings.append(ImportWarning("Correction \"\(correction.name)\" names event \(id), which the data does not have"))
            }
        }

        var events: [Event] = []
        for (_, fields, year) in kept {
            let id = fields.eventID
            let ordered = TheographicCorrections.apply(
                TheographicCorrections.all, toEvent: id,
                verses: verses.positions(of: fields.verses, owner: "event \(id)", warnings: &warnings), warnings: &warnings)
            var durationDays: Double?
            if let duration = fields.duration?.value {
                durationDays = days(duration)
                if durationDays == nil {
                    warnings.append(ImportWarning("Event \(id) (\(fields.title)): its length \"\(duration)\" is not read"))
                }
            }
            var parents: [Int] = []
            for link in fields.partOf ?? [] {
                if let parent = idsByRecord[link] {
                    parents.append(parent)
                } else {
                    warnings.append(ImportWarning("Dropped a part-of link of event \(id): \(link) is not among the events"))
                }
            }
            let partOf = parents.first { titles[$0]?.hasPrefix(lifetimePrefix) == true } ?? parents.first
            var personID: Int?
            if fields.title.hasPrefix(lifetimePrefix), let participants = fields.participants, !participants.isEmpty {
                personID = participants.lazy.compactMap { personIDsByRecord[$0] }.first
                if personID == nil {
                    warnings.append(ImportWarning("Dropped the person of event \(id) (\(fields.title)): none of its participants is among the people"))
                }
            }
            events.append(Event(
                id: id, title: fields.title, year: year, sortKey: fields.sortKey, passages: runs(ordered),
                durationDays: durationDays, partOf: partOf, personID: personID))
        }
        return events.sorted { $0.sortKey != $1.sortKey ? $0.sortKey < $1.sortKey : $0.id < $1.id }
    }

    /// What a life's title starts with.
    private static let lifetimePrefix = "Lifetime of "

    /// Verses in the table's order cut into runs of neighbours: next to each other in the table and either one
    /// verse on in a chapter or verse 1 of the next chapter. A run never crosses a book.
    private static func runs(_ ordered: [(position: Int, key: Int)]) -> [ClosedRange<Int>] {
        var runs: [ClosedRange<Int>] = []
        var current: (start: Int, last: (position: Int, key: Int))?
        for verse in ordered {
            if let run = current, verse.position == run.last.position + 1, areNeighbours(run.last.key, verse.key) {
                current = (run.start, verse)
                continue
            }
            if let run = current { runs.append(run.start...run.last.key) }
            current = (verse.key, verse)
        }
        if let run = current { runs.append(run.start...run.last.key) }
        return runs
    }

    private static func areNeighbours(_ first: Int, _ second: Int) -> Bool {
        guard first / 1_000_000 == second / 1_000_000 else { return false }
        let (chapter, verse) = (first / 1_000 % 1_000, first % 1_000)
        let (nextChapter, nextVerse) = (second / 1_000 % 1_000, second % 1_000)
        return (nextChapter == chapter && nextVerse == verse + 1) || (nextChapter == chapter + 1 && nextVerse == 1)
    }

    // MARK: Writers

    private static func buildWriters(_ records: [Record<BookFields>], personIDsByLookup: [String: Int], warnings: inout [ImportWarning]) -> [Writer] {
        var writers: [(order: Int, writer: Writer)] = []
        for record in records {
            let osisName = record.fields.osisName
            guard let code = CrossReferenceFile.books[osisName], let order = BookCatalog.book(code: code)?.order else {
                warnings.append(ImportWarning("Skipped book \(osisName): not among the 66"))
                continue
            }
            var ordinal = 0
            for lookup in record.fields.writers ?? [] {
                guard let personID = personIDsByLookup[lookup] else {
                    warnings.append(ImportWarning("Skipped writer \(lookup) of \(osisName): not among the people"))
                    continue
                }
                writers.append((order, Writer(book: code, ordinal: ordinal, personID: personID)))
                ordinal += 1
            }
        }
        return writers.sorted { ($0.order, $0.writer.ordinal) < ($1.order, $1.writer.ordinal) }.map(\.writer)
    }

    // MARK: Shared

    /// "Gen" to "Genesis 1:31": a verse key as `Reference.displayString` writes it.
    private static func displayString(_ key: Int) -> String {
        guard let location = VerseKey.location(key), let book = BookCatalog.book(code: location.book) else { return "" }
        return Reference(book: book, chapter: location.chapter, verse: location.verse).displayString
    }

    private static func splitList(_ text: String?) -> [String] {
        (text ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    // MARK: The files

    private static func read<Fields: Decodable>(_ file: String, in folder: URL, as: Fields.Type, warnings: inout [ImportWarning]) throws -> [Record<Fields>] {
        let data = try Data(contentsOf: folder.appendingPathComponent(file))
        let entries = try JSONDecoder().decode([Lossy<Fields>].self, from: data)
        var records: [Record<Fields>] = []
        for entry in entries {
            if let id = entry.id, let fields = entry.fields {
                records.append(Record(id: id, fields: fields))
            } else {
                warnings.append(ImportWarning("Skipped a record of \(file) that cannot be read (\(entry.id ?? "no id"))"))
            }
        }
        return records
    }

    private struct Record<Fields> {
        let id: String
        let fields: Fields
    }

    /// One record of a table; a record whose fields do not decode is kept as nil, so one bad record is not the whole table.
    private struct Lossy<Fields: Decodable>: Decodable {
        let id: String?
        let fields: Fields?

        private enum CodingKeys: String, CodingKey { case id, fields }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try? container.decode(String.self, forKey: .id)
            fields = try? container.decode(Fields.self, forKey: .fields)
        }
    }

    /// A value the data writes as a string or a number.
    private struct Loose: Decodable {
        let value: String

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                value = text
            } else if let whole = try? container.decode(Int.self) {
                value = String(whole)
            } else {
                value = String(try container.decode(Double.self))
            }
        }
    }

    private struct VerseFields: Decodable { let osisRef: String, verseID: String }

    private struct PersonFields: Decodable {
        let personID: Int, displayTitle: String
        let personLookup: String?, name: String?, surname: String?, alsoCalled: String?, gender: String?
        let birthYear: Loose?, deathYear: Loose?
        let father: [String]?, mother: [String]?, partners: [String]?, siblings: [String]?
        let halfSiblingsSameFather: [String]?, halfSiblingsSameMother: [String]?, children: [String]?
        let verses: [String]?, dictText: [String]?
    }

    private struct PlaceFields: Decodable {
        let placeID: Int, displayTitle: String
        let placeLookup: String?, kjvName: String?, esvName: String?, aliases: String?
        let featureType: String?, featureSubType: String?, precision: String?
        let latitude: Loose?, longitude: Loose?
        let verses: [String]?, dictText: [String]?
    }

    private struct EventFields: Decodable {
        let eventID: Int, title: String, sortKey: Double
        let startDate: Loose?, duration: Loose?
        let verses: [String]?, partOf: [String]?, participants: [String]?
    }

    private struct BookFields: Decodable {
        let osisName: String
        let writers: [String]?
    }

    /// The verse table: record ids to verse keys, and each verse's place in the table (its `verseID` order).
    private struct VerseTable {
        private var entries: [String: (key: Int, position: Int)] = [:]

        init(records: [Record<VerseFields>], warnings: inout [ImportWarning]) {
            var parsed: [(record: String, verseID: String, key: Int)] = []
            for record in records {
                let parts = record.fields.osisRef.split(separator: ".", omittingEmptySubsequences: false)
                guard parts.count == 3, let code = CrossReferenceFile.books[String(parts[0])],
                      let chapter = Int(parts[1]), let verse = Int(parts[2]), (1...999).contains(chapter), (1...999).contains(verse),
                      let key = VerseKey.key(VerseLocation(book: code, chapter: chapter, verse: verse))
                else {
                    warnings.append(ImportWarning("Skipped verse \(record.fields.osisRef): not one of the 66 books' verses"))
                    continue
                }
                parsed.append((record.id, record.fields.verseID, key))
            }
            parsed.sort { $0.verseID < $1.verseID }
            for (position, verse) in parsed.enumerated() { entries[verse.record] = (verse.key, position) }
        }

        /// Verse keys of the links, ascending and each once; a link to a verse outside the table is dropped with a warning.
        func keys(of links: [String]?, owner: String, warnings: inout [ImportWarning]) -> [Int] {
            Array(Set(positions(of: links, owner: owner, warnings: &warnings).map(\.key))).sorted()
        }

        /// The links' verses in the table's order, each once.
        func positions(of links: [String]?, owner: String, warnings: inout [ImportWarning]) -> [(position: Int, key: Int)] {
            var found: [Int: Int] = [:]
            for link in links ?? [] {
                guard let entry = entries[link] else {
                    warnings.append(ImportWarning("Skipped a verse link of \(owner): \(link) is not in the verse table"))
                    continue
                }
                found[entry.position] = entry.key
            }
            return found.sorted { $0.key < $1.key }.map { (position: $0.key, key: $0.value) }
        }
    }
}
