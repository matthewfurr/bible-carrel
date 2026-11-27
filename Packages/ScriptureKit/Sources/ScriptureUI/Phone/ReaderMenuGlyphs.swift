#if os(iOS)
import UIKit

/// The pictures on the reader menu's rows of buttons (`PhoneReaderScreen`): each page style as
/// "Aa" in its own face, as the Mac's tiles show it, and each line spacing as three lines that
/// far apart. Template images, so the menu tints them as it tints its symbols.
@MainActor
enum ReaderMenuGlyphs {
    /// The appearances the menu offers: following the system is chosen in Settings.
    static let appearances: [AppearanceChoice] = [.light, .sepia, .dark]

    static func symbol(for appearance: AppearanceChoice) -> String {
        switch appearance {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .sepia: "book"
        case .dark: "moon"
        }
    }

    /// The glyphs' size, following the menu's text size.
    private static var side: CGFloat {
        UIFontMetrics(forTextStyle: .body).scaledValue(for: 24)
    }

    /// "Aa" in the style's face over its name, as the Mac's tiles are: the palette shows pictures
    /// alone, and four "Aa"s are hard to tell apart without their names.
    static func pageStyle(_ style: PageStyle) -> UIImage {
        let sample = NSAttributedString(string: "Aa", attributes: [
            .font: style.defaultFace.font(size: side * 0.8), .foregroundColor: UIColor.black,
        ])
        let name = NSAttributedString(string: style.title, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .caption2), .foregroundColor: UIColor.black,
        ])
        let sampleSize = sample.size()
        let nameSize = name.size()
        let gap: CGFloat = 1
        let canvas = CGSize(width: ceil(max(sampleSize.width, nameSize.width)), height: ceil(sampleSize.height + gap + nameSize.height))
        let image = UIGraphicsImageRenderer(size: canvas).image { _ in
            sample.draw(at: CGPoint(x: (canvas.width - sampleSize.width) / 2, y: 0))
            name.draw(at: CGPoint(x: (canvas.width - nameSize.width) / 2, y: sampleSize.height + gap))
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    static func lineSpacing(_ choice: LineSpacingChoice) -> UIImage {
        let canvas = CGSize(width: side, height: side)
        let stroke = max(1.5, side / 14)
        // Three lines, centred, their gaps told apart more plainly than the multiples themselves.
        let fraction: CGFloat = switch choice {
        case .compact: 0.18
        case .normal: 0.27
        case .relaxed: 0.38
        }
        let gap = side * fraction
        let image = UIGraphicsImageRenderer(size: canvas).image { _ in
            UIColor.black.setFill()
            let top = (canvas.height - 2 * gap - stroke) / 2
            for index in 0..<3 {
                let y = top + CGFloat(index) * gap
                let width = index == 2 ? canvas.width * 0.6 : canvas.width
                UIBezierPath(roundedRect: CGRect(x: 0, y: y, width: width, height: stroke), cornerRadius: stroke / 2).fill()
            }
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}
#endif
