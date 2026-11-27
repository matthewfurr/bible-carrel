import Foundation

/// A color in OKLab (Björn Ottosson, 2020), converted from and to sRGB with his reference matrices.
public struct OKLab: Equatable, Sendable {
    public var l: Double
    public var a: Double
    public var b: Double

    public init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }

    /// Nil when `hex` is not `#RRGGBB`.
    public init?(srgbHex hex: String) {
        guard let c = ColorHex.components(hex) else { return nil }
        let r = Self.linear(c.red), g = Self.linear(c.green), b = Self.linear(c.blue)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        self.l = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        self.a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        self.b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    }

    /// Uppercase `#RRGGBB`, or nil when the color lies outside the sRGB gamut.
    public func srgbHex() -> String? {
        let l = pow(self.l + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(self.l - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(self.l - 0.0894841775 * a - 1.2914855480 * b, 3)
        let linear = [
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
        ]
        // The matrices are inverse to about 1e-10, so a hair of slack keeps grays in gamut.
        let tolerance = 1e-7
        guard linear.allSatisfy({ $0 >= -tolerance && $0 <= 1 + tolerance }) else { return nil }
        let encoded = linear.map(Self.encoded)
        return ColorHex.string(red: encoded[0], green: encoded[1], blue: encoded[2])
    }

    private static func linear(_ v: Double) -> Double {
        v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    private static func encoded(_ v: Double) -> Double {
        let v = min(max(v, 0), 1)
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
    }
}

/// OKLab in polar form: lightness, chroma and hue (degrees).
public struct OKLCH: Equatable, Sendable {
    public var l: Double
    public var c: Double
    public var hueDegrees: Double

    public init(l: Double, c: Double, hueDegrees: Double) {
        self.l = l
        self.c = c
        self.hueDegrees = hueDegrees
    }

    public init(_ lab: OKLab) {
        l = lab.l
        c = hypot(lab.a, lab.b)
        hueDegrees = atan2(lab.b, lab.a) * 180 / .pi
    }

    /// Nil when `hex` is not `#RRGGBB`.
    public init?(hex: String) {
        guard let lab = OKLab(srgbHex: hex) else { return nil }
        self.init(lab)
    }

    public var lab: OKLab {
        let h = hueDegrees * .pi / 180
        return OKLab(l: l, a: c * cos(h), b: c * sin(h))
    }

    /// Uppercase `#RRGGBB`, or nil when the color lies outside the sRGB gamut.
    public func hex() -> String? { lab.srgbHex() }

    /// The color at this lightness and hue, with chroma stepped down by 0.005 until it fits sRGB.
    public func hexReducingChroma() -> String {
        var color = OKLCH(l: min(max(l, 0), 1), c: max(c, 0), hueDegrees: hueDegrees)
        while true {
            if let hex = color.hex() { return hex }
            // Chroma 0 is a gray, in gamut for any lightness in 0...1, so this guard never fires.
            guard color.c > 0 else { return "#808080" }
            color.c = max(color.c - 0.005, 0)
        }
    }
}

/// Holds highlight colors to the lightness band the five defaults share (DESIGN.md › Marks), so
/// primary ink stays readable on every mark, the reader's own colors included.
public enum MarkLightness {
    /// OKLab L of a light-appearance mark. The defaults measure 0.887...0.910.
    public static let lightBand: ClosedRange<Double> = 0.88...0.93
    /// OKLab L of a dark-appearance mark. The defaults measure 0.400...0.401.
    /// Capped at 0.41 so a saturated green at the top edge still clears 6.5:1 against primary ink.
    public static let darkBand: ClosedRange<Double> = 0.37...0.41

    /// OKLab L of `hex`; nil when it is not `#RRGGBB`.
    public static func lightness(ofHex hex: String) -> Double? {
        OKLab(srgbHex: hex)?.l
    }

    public static func isInBand(hex: String, dark: Bool) -> Bool {
        guard let l = lightness(ofHex: hex) else { return false }
        return band(dark: dark).contains(l)
    }

    /// `hex` as uppercase `#RRGGBB` when it is already in the band. Otherwise the same hue with L
    /// clamped to the nearest band edge and chroma reduced until it fits sRGB. Anything that is
    /// not `#RRGGBB` becomes the band's gray. Conforming a conformed color changes nothing.
    public static func conformed(hex: String, dark: Bool) -> String {
        let band = band(dark: dark)
        guard let c = ColorHex.components(hex), let lab = OKLab(srgbHex: hex) else {
            return conformed(hex: dark ? "#505050" : "#D0D0D0", dark: dark)
        }
        // Already in band: keep the exact bytes, never re-encode through the matrices.
        if band.contains(lab.l) { return ColorHex.string(red: c.red, green: c.green, blue: c.blue) }
        var color = OKLCH(lab)
        color.l = min(max(lab.l, band.lowerBound), band.upperBound)
        // Rounding to bytes can land L a hair outside the edge; step inward until the stored
        // bytes themselves are in band, which is what keeps conforming idempotent.
        let inward = lab.l < band.lowerBound ? 0.001 : -0.001
        var result = color.hexReducingChroma()
        for _ in 0..<20 where !isInBand(hex: result, dark: dark) {
            color.l += inward
            result = color.hexReducingChroma()
        }
        return result
    }

    private static func band(dark: Bool) -> ClosedRange<Double> { dark ? darkBand : lightBand }
}
