import Testing
@testable import ScriptureUI

@Suite struct ColorPairSyncTests {
    @Test func darkFollowsLightUntilTouched() {
        var sync = ColorPairSync(light: "#FFE86B", dark: "#FFE86B")
        sync.setLight("#A0E0E0")
        #expect(sync.dark == "#A0E0E0")
        sync.setDark("#A0E0E0")          // the echo of our own sync, not a user choice
        sync.setLight("#B0B0B0")
        #expect(sync.dark == "#B0B0B0" && !sync.darkTouched)
        sync.setDark("#104040")
        #expect(sync.darkTouched)
        sync.setLight("#C0C0C0")
        #expect(sync.dark == "#104040")
    }
}
