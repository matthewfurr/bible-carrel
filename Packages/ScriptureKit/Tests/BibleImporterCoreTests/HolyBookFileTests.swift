import Foundation
import Testing
@testable import BibleImporterCore

enum Fixtures {
    static func url(_ relative: String) -> URL {
        Bundle.module.resourceURL!.appendingPathComponent("Fixtures/EN/\(relative)")
    }

    static func load(_ relative: String) throws -> HolyBookFile {
        try JSONDecoder().decode(HolyBookFile.self, from: Data(contentsOf: url(relative)))
    }
}

@Suite struct HolyBookFileTests {
    @Test func decodesMatthewWEB() throws {
        let file = try Fixtures.load("NT/MAT/WEB.json")
        #expect(file.version == "WEB")
        #expect(file.text.count == 28)
        #expect(file.text[4].number == 5)
        #expect(file.text[4].text.count == 74)
    }

    @Test func chapterNumberIsNilWhenMalformed() {
        let chapter = HolyBookFile.Chapter(ID: "NT:MAT.x", name: "", text: [])
        #expect(chapter.number == nil)
    }
}
