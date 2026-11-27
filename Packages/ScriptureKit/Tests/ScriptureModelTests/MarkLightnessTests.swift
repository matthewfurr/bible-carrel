import Testing
@testable import ScriptureModel

/// The marks' shared lightness band (DESIGN.md › Marks), now enforced on the reader's own colors.
@Suite struct MarkLightnessTests {
    @Test func defaultsAreAlreadyInsideTheBand() {
        for color in MarkupContainer.defaultColors {
            #expect(MarkLightness.isInBand(hex: color.lightHex, dark: false), "\(color.name)")
            #expect(MarkLightness.isInBand(hex: color.darkHex, dark: true), "\(color.name)")
            #expect(MarkLightness.conformed(hex: color.lightHex, dark: false) == color.lightHex, "\(color.name)")
            #expect(MarkLightness.conformed(hex: color.darkHex, dark: true) == color.darkHex, "\(color.name)")
        }
    }

    @Test func aDarkPickOnTheLightSideIsLifted() {
        let lifted = MarkLightness.conformed(hex: "#1F4C7A", dark: false)
        #expect(MarkLightness.isInBand(hex: lifted, dark: false))
        #expect(MarkLightness.lightness(ofHex: lifted)! >= 0.88)
    }

    /// Out of band, L moves only as far as the nearest edge (rounding to bytes may step it a
    /// thousandth or two inside).
    @Test func outOfBandPicksLandAtTheNearestEdge() {
        let lifted = MarkLightness.lightness(ofHex: MarkLightness.conformed(hex: "#000000", dark: false))!
        let lowered = MarkLightness.lightness(ofHex: MarkLightness.conformed(hex: "#FFFFFF", dark: false))!
        let darkLowered = MarkLightness.lightness(ofHex: MarkLightness.conformed(hex: "#FFFFFF", dark: true))!
        let darkLifted = MarkLightness.lightness(ofHex: MarkLightness.conformed(hex: "#000000", dark: true))!
        #expect(lifted >= 0.88 && lifted < 0.885)
        #expect(lowered <= 0.93 && lowered > 0.925)
        #expect(darkLowered <= 0.41 && darkLowered > 0.405)
        #expect(darkLifted >= 0.37 && darkLifted < 0.375)
    }

    @Test func conformingIsIdempotent() {
        for hex in ["#FF0000", "#00FF00", "#0000FF", "#FFFFFF", "#000000", "#7E517A"] {
            for dark in [false, true] {
                let once = MarkLightness.conformed(hex: hex, dark: dark)
                #expect(MarkLightness.conformed(hex: once, dark: dark) == once, "\(hex) dark=\(dark)")
            }
        }
    }

    @Test func garbageBecomesTheBandGray() {
        #expect(MarkLightness.conformed(hex: "nope", dark: false) == MarkLightness.conformed(hex: "#D0D0D0", dark: false))
    }
}
