import ScriptureModel
import SwiftUI
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// One named color with a value per appearance, as `#RRGGBB`. Increase Contrast falls back to the
/// standard value when a token has no high-contrast variant. Sepia is the light appearance with
/// warm values for the paper and ink tokens that have one (`sepia`); every other token keeps its
/// light value there.
///
/// The palette lives in code rather than an asset catalog: SwiftPM's command-line build (and so
/// `swift test`) does not compile `.xcassets`, and a token that loads as nil in tests cannot be
/// checked. `PaletteTests` holds every pairing DESIGN.md promises to its contrast ratio.
public struct ColorToken: Hashable, Sendable {
    public let name: String
    public let light: String
    public let dark: String
    public let lightHighContrast: String?
    public let darkHighContrast: String?
    /// The Sepia value, or nil when the token keeps its light value in Sepia.
    public let sepia: String?

    public init(_ name: String, light: String, dark: String, lightHighContrast: String? = nil, darkHighContrast: String? = nil,
                sepia: String? = nil) {
        self.name = name
        self.light = light
        self.dark = dark
        self.lightHighContrast = lightHighContrast
        self.darkHighContrast = darkHighContrast
        self.sepia = sepia
    }

    /// The hex for one appearance. Sepia applies only to the light appearance: there a token with
    /// a Sepia value takes it, except that Increase Contrast prefers the token's light
    /// high-contrast value (the inks that have one), so the papers stay warm and the inks darken.
    public func hex(dark isDark: Bool, highContrast: Bool = false, sepia isSepia: Bool = false) -> String {
        if isSepia, !isDark, let sepia {
            return highContrast ? lightHighContrast ?? sepia : sepia
        }
        switch (isDark, highContrast) {
        case (false, false): return light
        case (true, false): return dark
        case (false, true): return lightHighContrast ?? light
        case (true, true): return darkHighContrast ?? dark
        }
    }

    /// A dynamic platform color that resolves per appearance. Named after the token, so two
    /// instances compare equal and TextKit does not treat a re-applied color as a change.
    ///
    /// Sepia is read as the color resolves: from `SepiaMode` on macOS, from `SepiaTrait` on iOS.
    public var platformColor: PlatformColor {
        let variants = (
            light: Self.color(light),
            dark: Self.color(dark),
            lightHC: Self.color(lightHighContrast ?? light),
            darkHC: Self.color(darkHighContrast ?? dark),
            sepia: Self.color(hex(dark: false, sepia: true)),
            sepiaHC: Self.color(hex(dark: false, highContrast: true, sepia: true)))
        #if canImport(AppKit)
        return NSColor(name: "token-\(name)") { appearance in
            // The high-contrast appearance names are only ever set by the system, so the flag is
            // read as well: either one means Increase Contrast is on.
            let match = appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
            let isDark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
            let isHigh = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
                || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            return Self.pick(variants, dark: isDark, high: isHigh, sepia: !isDark && SepiaMode.isOn)
        }
        #else
        return UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return Self.pick(variants, dark: isDark, high: traits.accessibilityContrast == .high,
                             sepia: !isDark && traits[SepiaTrait.self])
        }
        #endif
    }

    private typealias Variants = (light: PlatformColor, dark: PlatformColor, lightHC: PlatformColor, darkHC: PlatformColor,
                                  sepia: PlatformColor, sepiaHC: PlatformColor)

    private static func pick(_ variants: Variants, dark: Bool, high: Bool, sepia: Bool) -> PlatformColor {
        switch (dark, high, sepia) {
        case (_, false, true): variants.sepia
        case (_, true, true): variants.sepiaHC
        case (false, false, false): variants.light
        case (true, false, false): variants.dark
        case (false, true, false): variants.lightHC
        case (true, true, false): variants.darkHC
        }
    }

    private static func color(_ hex: String) -> PlatformColor {
        let c = ColorHex.components(hex) ?? (0.5, 0.5, 0.5)
        #if canImport(AppKit)
        return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
        #else
        return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
        #endif
    }
}

/// The app's color tokens (DESIGN.md › Colors: Verdigris on Slate). Chosen in OKLCH: slate-tinted
/// paper and ink at hue 245 to 250, a verdigris accent at hue 175, a plum assistant at hue 330.
/// The reader's highlight defaults live with the data model (`MarkupContainer.defaultColors`).
/// Sepia warms the paper and ink only; the marks, `ink.verse`, the accent, the assistant and the
/// washes keep their light values.
public enum Palette {
    // Paper: surfaces. One tonal step apart; in dark mode raised surfaces are lighter.
    public static let paperPage = ColorToken("paper.page", light: "#F5F7F9", dark: "#101418", sepia: "#F5EDDE")
    public static let paperPanel = ColorToken("paper.panel", light: "#EDF1F4", dark: "#191D22", sepia: "#ECE2CF")
    public static let paperOverlay = ColorToken("paper.overlay", light: "#FAFCFE", dark: "#22272D", sepia: "#F9F3E8")

    // Ink: text and rules.
    public static let inkPrimary = ColorToken("ink.primary", light: "#192028", dark: "#E5E8EC", sepia: "#2A2118")
    public static let inkSecondary = ColorToken("ink.secondary", light: "#5D646C", dark: "#A0A5AB",
                                                lightHighContrast: "#414951", darkHighContrast: "#C0C5C9", sepia: "#6A5B49")
    /// Dates and other metadata that is never the only channel; below 4.5:1 by design.
    public static let inkTertiary = ColorToken("ink.tertiary", light: "#8D9399", dark: "#6D7277",
                                               lightHighContrast: "#515961", darkHighContrast: "#A6ACB1", sepia: "#9A8B78")
    public static let inkRule = ColorToken("ink.rule", light: "#D3D8DC", dark: "#292E34",
                                           lightHighContrast: "#989FA6", darkHighContrast: "#5E646A", sepia: "#DCCFB8")
    /// Verse numbers: bronze, the one warm ink. Holds 4.5:1 on the page and on every default mark.
    public static let inkVerse = ColorToken("ink.verse", light: "#7A5320", dark: "#DDB683")

    // Accent: selection, the current chapter, the focused-highlight outline, bookmarks, the icon.
    public static let accent = ColorToken("accent", light: "#247966", dark: "#73C3AE",
                                          lightHighContrast: "#005B4B", darkHighContrast: "#91DCC7")
    public static let accentWash = ColorToken("accent.wash", light: "#D1F0E6", dark: "#0A3028",
                                              lightHighContrast: "#B6E3D5", darkHighContrast: "#084236")

    // Assistant: the study assistant's voice only (milestone 5).
    public static let assistant = ColorToken("assistant", light: "#7E517A", dark: "#D3A6CE",
                                             lightHighContrast: "#61355D", darkHighContrast: "#EAC2E6")
    public static let assistantWash = ColorToken("assistant.wash", light: "#F7E4F5", dark: "#372435")

    public static let all: [ColorToken] = [
        paperPage, paperPanel, paperOverlay,
        inkPrimary, inkSecondary, inkTertiary, inkRule, inkVerse,
        accent, accentWash, assistant, assistantWash,
    ]
}

/// SwiftUI's side of a token: resolved from the environment's color scheme, contrast and Sepia
/// (`EnvironmentValues.isSepia`). A platform color would not do: SwiftUI re-resolves one only
/// when the color scheme or contrast changes, and Sepia is still the light scheme.
struct TokenStyle: ShapeStyle, Hashable {
    let token: ColorToken
    /// Every appearance's color, parsed once: light, dark, light and dark high contrast, Sepia,
    /// Sepia high contrast (`index(dark:high:sepia:)`).
    private let variants: [Color.Resolved]

    init(token: ColorToken) {
        self.token = token
        variants = [(false, false, false), (true, false, false), (false, true, false), (true, true, false),
                    (false, false, true), (false, true, true)].map { dark, high, sepia in
            let c = ColorHex.components(token.hex(dark: dark, highContrast: high, sepia: sepia)) ?? (0.5, 0.5, 0.5)
            return Color.Resolved(colorSpace: .sRGB, red: Float(c.red), green: Float(c.green), blue: Float(c.blue))
        }
    }

    static func index(dark: Bool, high: Bool, sepia: Bool) -> Int {
        if sepia, !dark { return high ? 5 : 4 }
        return (dark ? 1 : 0) + (high ? 2 : 0)
    }

    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        variants[Self.index(dark: environment.colorScheme == .dark, high: environment.colorSchemeContrast == .increased,
                            sepia: environment.isSepia)]
    }

    // The variants follow from the token.
    static func == (a: Self, b: Self) -> Bool { a.token == b.token }
    func hash(into hasher: inout Hasher) { hasher.combine(token) }
}

/// A platform color (a token's `platformColor`, as `ReaderTypography` holds them) in SwiftUI,
/// resolved for the environment's appearance and Sepia, so it changes with them as the palette's
/// own SwiftUI colors do.
struct PlatformColorStyle: ShapeStyle, Hashable {
    let color: PlatformColor

    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let isDark = environment.colorScheme == .dark
        #if canImport(AppKit)
        // The tokens read Sepia from `SepiaMode`, which the environment's `isSepia` follows;
        // reading it here is what makes SwiftUI resolve this again when Sepia changes.
        _ = environment.isSepia
        var resolved = color
        NSAppearance(named: isDark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.sRGB) ?? color
        }
        return Color.Resolved(colorSpace: .sRGB, red: Float(resolved.redComponent), green: Float(resolved.greenComponent),
                              blue: Float(resolved.blueComponent), opacity: Float(resolved.alphaComponent))
        #else
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = isDark ? .dark : .light
            traits.accessibilityContrast = environment.colorSchemeContrast == .increased ? .high : .normal
            traits[SepiaTrait.self] = environment.isSepia
        }
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color.Resolved(colorSpace: .sRGB, red: Float(r), green: Float(g), blue: Float(b), opacity: Float(a))
        #endif
    }
}

extension Color {
    public init(token: ColorToken) {
        self.init(TokenStyle(token: token))
    }

    /// A platform color made of tokens (`ReaderTypography`'s inks), following Sepia in SwiftUI.
    public init(platform color: PlatformColor) {
        self.init(PlatformColorStyle(color: color))
    }

    public static let paperPage = Color(token: Palette.paperPage)
    public static let paperPanel = Color(token: Palette.paperPanel)
    public static let paperOverlay = Color(token: Palette.paperOverlay)
    public static let inkPrimary = Color(token: Palette.inkPrimary)
    public static let inkSecondary = Color(token: Palette.inkSecondary)
    public static let inkTertiary = Color(token: Palette.inkTertiary)
    public static let inkRule = Color(token: Palette.inkRule)
    public static let inkVerse = Color(token: Palette.inkVerse)
    /// Verdigris. Named `accent`, not `accentColor`: on macOS the system accent follows the
    /// user's choice unless it is Multicolor, so the app's own marks use this token directly.
    public static let accent = Color(token: Palette.accent)
    public static let accentWash = Color(token: Palette.accentWash)
    public static let assistant = Color(token: Palette.assistant)
    public static let assistantWash = Color(token: Palette.assistantWash)
}
