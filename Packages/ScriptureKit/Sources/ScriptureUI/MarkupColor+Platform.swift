import ScriptureModel
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

extension MarkupColor {
    /// A dynamic color that picks the light or dark variant for the current appearance.
    public var platformColor: PlatformColor {
        let light = Self.color(hex: lightHex)
        let dark = Self.color(hex: darkHex)
        #if canImport(AppKit)
        // Named per hex pair: nameless dynamic colors compare equal, so a recolor would look
        // like the same attribute to TextKit and not repaint.
        return NSColor(name: "markup-\(lightHex)-\(darkHex)") { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
        #else
        return UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
        #endif
    }

    static func color(hex: String) -> PlatformColor {
        // An unreadable stored hex draws as a neutral rule, never as a saturated system color.
        guard let c = ColorHex.components(hex) else { return Palette.inkRule.platformColor }
        #if canImport(AppKit)
        return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
        #else
        return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
        #endif
    }
}

#if canImport(AppKit)
extension NSColor {
    /// A dynamic 50/50 blend of two (possibly dynamic) colors, resolved per appearance.
    static func blendedMarkup(_ first: NSColor, _ second: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            var result = second
            appearance.performAsCurrentDrawingAppearance {
                if let a = first.usingColorSpace(.sRGB), let b = second.usingColorSpace(.sRGB) {
                    result = a.blended(withFraction: 0.5, of: b) ?? b
                }
            }
            return result
        }
    }
}
#else
extension UIColor {
    /// A dynamic 50/50 blend of two (possibly dynamic) colors, resolved per trait collection.
    static func blendedMarkup(_ first: UIColor, _ second: UIColor) -> UIColor {
        UIColor { traits in
            var a: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            var b: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            guard first.resolvedColor(with: traits).getRed(&a.0, green: &a.1, blue: &a.2, alpha: &a.3),
                  second.resolvedColor(with: traits).getRed(&b.0, green: &b.1, blue: &b.2, alpha: &b.3)
            else { return second.resolvedColor(with: traits) }
            return UIColor(red: (a.0 + b.0) / 2, green: (a.1 + b.1) / 2, blue: (a.2 + b.2) / 2, alpha: (a.3 + b.3) / 2)
        }
    }
}
#endif
