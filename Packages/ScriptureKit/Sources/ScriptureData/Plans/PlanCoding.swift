import Foundation

/// The stored form of a plan's weeks: JSON with sorted keys, `{"v":1,"weeks":[…]}`.
public enum PlanCoding {
    public static let version = 1

    private struct Stored: Codable {
        var v: Int
        var weeks: [StoredWeek]
    }

    private struct StoredWeek: Codable {
        var n: Int
        var d: String?
        var l: String?
        var r: [StoredReading]
    }

    private struct StoredReading: Codable {
        var id: String
        var l: String?
        var p: [StoredPassage]
    }

    private struct StoredPassage: Codable {
        var b: String
        var c: Int
        var e: Int?
        var v: Int?
        var w: Int?
    }

    private struct VersionOnly: Decodable { var v: Int }

    public static func encode(_ weeks: [PlanWeek]) throws -> Data {
        let stored = Stored(v: version, weeks: weeks.map { week in
            StoredWeek(n: week.number, d: week.day?.iso, l: week.label, r: week.readings.map { reading in
                StoredReading(id: reading.id.uuidString, l: reading.label, p: reading.passages.map { passage in
                    StoredPassage(b: passage.book, c: passage.chapter,
                                  e: passage.endChapter == passage.chapter ? nil : passage.endChapter,
                                  v: passage.verse, w: passage.endVerse)
                })
            })
        })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(stored)
    }

    /// nil for a newer version or data that cannot be read; [] for empty data.
    public static func decode(_ data: Data) -> [PlanWeek]? {
        guard !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(VersionOnly.self, from: data), header.v == version,
              let stored = try? decoder.decode(Stored.self, from: data) else { return nil }
        var weeks: [PlanWeek] = []
        for week in stored.weeks {
            var day: PlanDay?
            if let iso = week.d {
                guard let parsed = PlanDay(iso: iso) else { return nil }
                day = parsed
            }
            var readings: [PlanReading] = []
            for reading in week.r {
                guard let id = UUID(uuidString: reading.id) else { return nil }
                let passages = reading.p.map {
                    PlanPassage(book: $0.b, chapter: $0.c, endChapter: $0.e, verse: $0.v, endVerse: $0.w)
                }
                readings.append(PlanReading(id: id, label: reading.l, passages: passages))
            }
            weeks.append(PlanWeek(number: week.n, day: day, label: week.l, readings: readings))
        }
        return weeks
    }
}
