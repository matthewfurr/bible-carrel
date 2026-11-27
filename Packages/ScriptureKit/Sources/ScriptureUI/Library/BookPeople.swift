import ScriptureData
import Synchronization

/// People in a book: the rows of the People list.
public struct BookPeople: Equatable, Sendable {
    public struct Row: Identifiable, Equatable, Sendable {
        public let person: PersonSummary
        /// Only when another row has the person's name.
        public let label: String?
        public var id: Int { person.id }

        /// "Jacob, father of Joseph, 2 verses".
        public var accessibilityLabel: String {
            let count = person.verseCount == 1 ? "1 verse" : "\(person.verseCount.formatted()) verses"
            return [person.name, label, count].compactMap { $0 }.joined(separator: ", ")
        }
    }

    public let book: Book, rows: [Row]

    /// The A to Z order, made the first time it is asked for (Departure 18: once per load), so a
    /// load that is shown Most named never pays for the sort.
    private final class NameOrder: Sendable {
        private let sorted = Mutex<[Row]?>(nil)
        func rows(of rows: [Row]) -> [Row] {
            sorted.withLock { cache in
                if let cache { return cache }
                let result = rows.sorted(by: BookPeople.nameOrder)
                cache = result
                return result
            }
        }
    }
    private let byName = NameOrder()

    init(book: Book, rows: [Row]) {
        self.book = book
        self.rows = rows
    }

    /// A to Z: by name, then the data's label (none first), then id.
    public var rowsByName: [Row] { byName.rows(of: rows) }

    private static func nameOrder(_ a: Row, _ b: Row) -> Bool {
        LibraryNameOrder.precedes((a.person.name, a.person.label, a.id), (b.person.name, b.person.label, b.id))
    }

    public func rows(_ order: PeopleOrder) -> [Row] {
        order == .mostNamed ? rows : rowsByName
    }

    public static func == (a: BookPeople, b: BookPeople) -> Bool { a.book == b.book && a.rows == b.rows }

    public var title: String { "People in \(book.name)" }
    public func countLabel(_ order: PeopleOrder) -> String {
        "\(rows.count.formatted()) named · by \(order == .mostNamed ? "mentions" : "name")"
    }

    /// nil outside the 66.
    public static func load(book code: String, store: BibleStore) throws -> BookPeople? {
        guard let book = BookCatalog.book(code: code), book.canon != .apocrypha else { return nil }
        let people = try store.people(inBook: code)
        var uses: [String: Int] = [:]
        for person in people { uses[person.name, default: 0] += 1 }
        return BookPeople(book: book, rows: people.map { Row(person: $0, label: uses[$0.name, default: 0] > 1 ? $0.label : nil) })
    }
}
