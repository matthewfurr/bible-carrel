import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// Settings → Reading: line spacing choices mapped onto the paragraph style's multiple.
public enum LineSpacingChoice: String, CaseIterable, Sendable {
    case compact
    case normal
    case relaxed

    public var lineHeightMultiple: CGFloat {
        switch self {
        case .compact: 1.15
        case .normal: 1.3
        case .relaxed: 1.5
        }
    }

    public var title: String {
        switch self {
        case .compact: "Compact"
        case .normal: "Normal"
        case .relaxed: "Relaxed"
        }
    }
}

/// Settings → Reading: the appearance. On macOS it is applied app-wide through `NSApp.appearance`
/// (`nsAppearance`), so every window, sheet, popover and menu follows one source; a per-window
/// `preferredColorScheme(nil)` does not reset a window SwiftUI already forced dark. Sepia is the
/// light appearance with warm paper and ink (`SepiaMode`); system controls stay light.
public enum AppearanceChoice: String, CaseIterable, Sendable {
    case system
    case light
    case sepia
    case dark

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .sepia: .light
        case .dark: .dark
        }
    }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    public var isSepia: Bool { self == .sepia }

    #if canImport(AppKit)
    /// Nil follows the system; Light, Sepia and Dark force the app's appearance.
    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light, .sepia: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// Applies the choice to every window, sheet, popover and menu of the app, Sepia included.
    /// Sepia's flag is set first, so whatever redraws already resolves the new colors; the
    /// windows are taken through `SepiaMode`'s redraw only when the appearance itself stayed put
    /// (Light to Sepia), since a changed appearance (Sepia to Dark) redraws them anyway.
    @MainActor public func apply() {
        let match: (NSApplication) -> NSAppearance.Name? = { $0.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) }
        let before = match(NSApp)
        let sepiaChanged = SepiaMode.update(isSepia)
        NSApp.appearance = nsAppearance
        if sepiaChanged, match(NSApp) == before { SepiaMode.redrawWindows() }
    }
    #else
    /// Applies the choice to every window of the app as the window's own style, so every sheet
    /// and menu over the page follows it and System hands it back to the device
    /// (`preferredColorScheme(nil)` leaves an open sheet in the last style), and Sepia as the
    /// window scenes' `SepiaTrait`.
    @MainActor public func apply() {
        let style: UIUserInterfaceStyle = switch self {
        case .system: .unspecified
        case .light, .sepia: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows { window.overrideUserInterfaceStyle = style }
        }
        SepiaMode.set(isSepia)
    }
    #endif
}

/// The `UserDefaults` keys behind Settings → General and Reading, their defaults, and the
/// mapping from the stored values onto `ReaderTypography`. In a build that syncs, `PreferenceSync`
/// mirrors the keys in `SyncedPreferences.keys` through the iCloud key-value store: the default
/// translation, page style and face, verse layout, verse numbers, section headings and
/// justification. The text size, line spacing, column width and appearance stay with each device.
public enum ReaderSettings {
    public static let defaultTranslationKey = "defaultTranslationID"
    public static let fontSizeKey = "readerFontSize"
    public static let lineSpacingKey = "readerLineSpacing"
    public static let appearanceKey = "readerAppearance"
    public static let pageStyleKey = "readerPageStyle"
    /// The raw value of a `PageFace`; empty means the style's own.
    public static let pageFaceKey = "readerPageFace"
    public static let columnWidthKey = "readerColumnWidth"
    public static let verseLayoutKey = "readerVerseLayout"
    public static let showsVerseNumbersKey = "readerShowsVerseNumbers"
    public static let showsSectionHeadingsKey = "readerShowsSectionHeadings"
    public static let justifiedKey = "readerJustified"

    public static let fontSizeRange: ClosedRange<Double> = 14...28
    /// The Settings slider's step, and the phone menu's Text Size buttons'.
    public static let fontSizeStep: Double = 1
    public static let defaultFontSize: Double = 18
    public static let defaultTranslationID = "ESV"

    public static func clampedFontSize(_ value: Double) -> Double {
        min(max(value, fontSizeRange.lowerBound), fontSizeRange.upperBound)
    }

    /// `size` moved `steps` of `fontSizeStep`, held within `fontSizeRange`.
    public static func steppedFontSize(_ size: Double, by steps: Int) -> Double {
        clampedFontSize(size + Double(steps) * fontSizeStep)
    }

    /// The stored default translation, or ESV. `NavigationModel` falls back further when the
    /// stored one is not bundled.
    public static func defaultTranslationID(from defaults: UserDefaults) -> String {
        defaults.string(forKey: defaultTranslationKey) ?? defaultTranslationID
    }

    /// The reader's typography for the stored preferences; verse numbers, paragraph spacing and the
    /// measure scale with the (clamped) size; `headlineSize` is the system headline size to build
    /// with (`ReaderTypography.styled`). Main actor only, like `ReaderTypography.styled`.
    @MainActor
    public static func typography(_ prefs: ReaderPreferences,
                                  headlineSize: CGFloat = ReaderTypography.systemHeadlineSize) -> ReaderTypography {
        ReaderTypography.styled(prefs, headlineSize: headlineSize)
    }
}
