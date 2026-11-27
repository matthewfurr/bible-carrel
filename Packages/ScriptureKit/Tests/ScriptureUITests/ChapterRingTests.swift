import Foundation
import ScriptureModel
import Testing
@testable import ScriptureUI

@Suite struct ChapterRingTests {
    private let yellow = MarkupColor(lightHex: "#F8E18A", darkHex: "#554704")
    private let green = MarkupColor(lightHex: "#BCF2BD", darkHex: "#2E522F")
    private var seven: [MarkupColor] {
        (0..<7).map { MarkupColor(lightHex: String(format: "#%02X%02X%02X", 0x80 + $0 * 8, 0xA0, 0xC0), darkHex: "#303030") }
    }

    private func marks(_ colors: [MarkupColor]) -> ChapterMarks { ChapterMarks(colors: colors) }

    @Test func oneColourIsAWholeRingAndSeveralShareItEqually() {
        #expect(ChapterRing.segments(for: marks([yellow])) == [.init(start: 0, end: 1, color: yellow)])
        #expect(ChapterRing.segments(for: marks([])) == [.init(start: 0, end: 1, color: nil)])            // a bookmark, a chapter note
        let two = ChapterRing.segments(for: marks([yellow, green]))
        #expect(two.map(\.color) == [yellow, green] && abs(two[0].start - 0.015) < 1e-9 && abs(two[0].end - 0.485) < 1e-9 && abs(two[1].end - 0.985) < 1e-9)
        #expect(ChapterRing.segments(for: marks(seven)).map(\.color) == Array(seven.prefix(6)))
    }

    @Test func theRingKeepsTheHueAtTheRingsLightness() throws {
        let light = try #require(OKLCH(hex: ChapterRing.ringHex("#BCF2BD", dark: false)))
        let dark = try #require(OKLCH(hex: ChapterRing.ringHex("#2E522F", dark: true)))
        let seed = try #require(OKLCH(hex: "#BCF2BD"))
        #expect(abs(light.l - 0.55) < 0.01 && abs(dark.l - 0.68) < 0.01)
        #expect(abs(light.hueDegrees - seed.hueDegrees) < 3)
        let ring = ChapterRing.color(green)
        #expect(ring.lightHex == ChapterRing.ringHex(green.lightHex, dark: false) && ring.darkHex == ChapterRing.ringHex(green.darkHex, dark: true))
    }
}
