/// The "dark follows light until the dark picker is touched" rule for a new color, kept out of
/// the view so it can be tested: SwiftUI delivers the echo of a programmatic dark change as a
/// later `onChange`, so "touched" means a dark value that differs from the light one.
struct ColorPairSync: Equatable {
    private(set) var light: String
    private(set) var dark: String
    private(set) var darkTouched = false

    init(light: String, dark: String) {
        self.light = light
        self.dark = dark
    }

    mutating func setLight(_ hex: String) {
        light = hex
        if !darkTouched { dark = hex }
    }

    mutating func setDark(_ hex: String) {
        dark = hex
        if hex != light { darkTouched = true }
    }
}
