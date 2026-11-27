import Observation
import SwiftUI
import Synchronization
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// Whether the app is in Sepia: the light appearance with warm paper and ink (`ColorToken.sepia`).
/// Neither platform has a sepia appearance of its own, so the tokens learn it here, in three places:
///
/// - AppKit drawing (`ColorToken.platformColor` on macOS) reads a lock-protected flag, since AppKit
///   may resolve a color off the main thread.
/// - UIKit drawing (`platformColor` on iOS) reads `SepiaTrait`, which `set` puts on every window
///   scene, so it reaches every view controller and sheet the way light and dark do.
/// - SwiftUI (`Color.paperPage` and the rest) reads `EnvironmentValues.isSepia`. On iOS the trait
///   bridges into it; on macOS each scene's root takes it from here with `followsSepia()`.
public enum SepiaMode {
    #if canImport(AppKit)
    private static let state = Mutex(false)

    /// True while the app is in Sepia.
    public static var isOn: Bool { state.withLock { $0 } }

    /// The flag for SwiftUI to observe (`followsSepia()`).
    @MainActor static let observed = Observed()

    @MainActor @Observable final class Observed {
        var isOn = false
    }

    /// Turns Sepia on or off. A change redraws every window: nothing in AppKit knows a color
    /// changed when the appearance stays light, so the windows are made to re-resolve theirs.
    @MainActor public static func set(_ on: Bool) {
        if update(on) { redrawWindows() }
    }

    /// Sets the flag without redrawing, for a caller that changes the app's appearance itself
    /// (`AppearanceChoice.apply()`); true when it changed.
    @MainActor static func update(_ on: Bool) -> Bool {
        let changed = state.withLock { current in
            defer { current = on }
            return current != on
        }
        if changed { observed.isOn = on }
        return changed
    }

    /// Takes the app through the other appearance and back within one turn of the run loop: every
    /// AppKit view, text view and layer sees its effective appearance change and re-resolves its
    /// colors, and nothing draws in between, so nothing flashes. SwiftUI coalesces the two changes
    /// into none and follows `isSepia` instead.
    @MainActor static func redrawWindows() {
        guard let app = NSApp else { return }
        let appearance = app.appearance
        let isDark = app.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        app.appearance = NSAppearance(named: isDark ? .aqua : .darkAqua)
        app.appearance = appearance
    }
    #else
    /// Turns Sepia on or off on every window scene of the app. The trait affects color
    /// appearance, so UIKit redraws whatever resolved a token's color, as a light or dark change does.
    @MainActor public static func set(_ on: Bool) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.traitOverrides[SepiaTrait.self] = on
        }
    }
    #endif
}

#if canImport(UIKit)
/// The iOS trait behind Sepia: true on a window scene in Sepia. `ColorToken.platformColor` reads it,
/// and it bridges into SwiftUI as `EnvironmentValues.isSepia`.
public struct SepiaTrait: UITraitDefinition {
    public static let defaultValue = false
    public static let identifier = "com.matthewfurr.ReadingThroughScripture.sepia"
    public static let name = "Sepia"
    public static let affectsColorAppearance = true
}
#endif

struct SepiaKey: EnvironmentKey {
    static let defaultValue = false
}

#if canImport(UIKit)
extension SepiaKey: UITraitBridgedEnvironmentKey {
    static func read(from traitCollection: UITraitCollection) -> Bool { traitCollection[SepiaTrait.self] }
    static func write(to mutableTraits: inout any UIMutableTraits, value: Bool) { mutableTraits[SepiaTrait.self] = value }
}
#endif

extension EnvironmentValues {
    /// True in Sepia: the palette's SwiftUI colors take their Sepia values in the light appearance.
    public var isSepia: Bool {
        get { self[SepiaKey.self] }
        set { self[SepiaKey.self] = newValue }
    }
}

extension View {
    /// Puts the app's Sepia into this root's environment, so the palette's colors below follow it.
    /// Each macOS scene's root and each SwiftUI view hosted in AppKit takes it; on iOS the window
    /// scene's `SepiaTrait` already bridges into the environment, so this changes nothing there.
    public func followsSepia() -> some View {
        modifier(FollowsSepia())
    }
}

private struct FollowsSepia: ViewModifier {
    func body(content: Content) -> some View {
        #if canImport(AppKit)
        content.environment(\.isSepia, SepiaMode.observed.isOn)
        #else
        content
        #endif
    }
}
