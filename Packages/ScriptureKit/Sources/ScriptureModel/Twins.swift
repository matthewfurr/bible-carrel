import Foundation

/// Records that share a uuid are read as one (Departure 1). Two copies with one identity are two
/// records in iCloud and nothing in them tells two devices which to delete; each deleting a
/// different one would lose both, since a delete always wins. So copies are never deleted for
/// sharing an identity (but a note's differing copy, `settleVersions`' first step): every list read
/// returns one of them, in one pass over what it fetched.
enum Twins {
    /// One record per uuid, in the order given: of those sharing a uuid, the one `prefer` puts first.
    static func firsts<Record>(_ records: [Record], id: (Record) -> UUID, prefer: (Record, Record) -> Bool = { _, _ in false }) -> [Record] {
        var chosen: [UUID: Int] = [:]
        var shared = false
        for (index, record) in records.enumerated() {
            let key = id(record)
            guard let current = chosen[key] else {
                chosen[key] = index
                continue
            }
            shared = true
            if prefer(record, records[current]) { chosen[key] = index }
        }
        guard shared else { return records }
        return records.indices.filter { chosen[id(records[$0])] == $0 }.map { records[$0] }
    }

    /// Of two notes, the later `modifiedAt`; ties, the greater `body`.
    static func prefers(_ note: Note, over other: Note) -> Bool {
        note.modifiedAt != other.modifiedAt ? note.modifiedAt > other.modifiedAt : note.body > other.body
    }

    /// Of two highlights, one with a note; then the later `modifiedAt`.
    static func prefers(_ highlight: Highlight, over other: Highlight) -> Bool {
        if (highlight.note != nil) != (other.note != nil) { return highlight.note != nil }
        return highlight.modifiedAt > other.modifiedAt
    }

    static func notes(_ notes: [Note]) -> [Note] { firsts(notes, id: \.uuid, prefer: prefers(_:over:)) }

    static func highlights(_ highlights: [Highlight]) -> [Highlight] { firsts(highlights, id: \.uuid, prefer: prefers(_:over:)) }
}
