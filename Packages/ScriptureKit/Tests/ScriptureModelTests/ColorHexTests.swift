import Testing
@testable import ScriptureModel

@Suite struct ColorHexTests {
    @Test func parsesWithAndWithoutHash() {
        #expect(ColorHex.components("#FFE86B")! == (1.0, 232.0 / 255, 107.0 / 255))
        #expect(ColorHex.components("ffe86b")! == (1.0, 232.0 / 255, 107.0 / 255))
        #expect(ColorHex.components("#FFE") == nil)
        #expect(ColorHex.components("nope") == nil)
    }

    @Test func formatsUppercaseWithHash() {
        #expect(ColorHex.string(red: 1, green: 232.0 / 255, blue: 107.0 / 255) == "#FFE86B")
        #expect(ColorHex.string(red: 0, green: 0, blue: 0) == "#000000")
    }
}
