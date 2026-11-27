import SwiftUI
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// The Library pages' type and column on the Mac, from the reader's own settings (Matt's review, 2026-11-24:
/// "this must not being matching what the user has selected for their reading font size").
///
/// Every text style is set at its macOS size times the reader size over `.body`'s 13 pt, to the half point, so
/// `.body` is the reader size (18 pt by default) and every smaller role (a fact's label, a section's header, a
/// caption, a chip) steps down in proportion; at the least reader size (14) nothing is smaller than the
/// system's own style. Sizes and gaps tied to text grow by the same scale (`metric`). The text column is the
/// reader's measure (`ReaderTypography.measure`, the Column width setting included), centred in the page.
///
/// `.system`, the environment's default, keeps the semantic styles and Dynamic Type and gives no column: the
/// phone's Library and Settings › About, which share these views, are unchanged. `FrontPageView` sets the
/// reader's for the Mac's Library views (DESIGN.md names it as an exception to the fixed-size rule).
public struct LibraryType: Equatable, Sendable {
    /// The reader's page size, held to `ReaderSettings.fontSizeRange`; nil keeps the system's text styles.
    public let readerSize: CGFloat?
    public let columnWidth: ColumnWidthChoice

    public static let system = LibraryType(readerSize: nil)

    public init(readerSize: CGFloat?, columnWidth: ColumnWidthChoice = .normal) {
        self.readerSize = readerSize.map { CGFloat(ReaderSettings.clampedFontSize(Double($0))) }
        self.columnWidth = columnWidth
    }

    /// What every size grows by: the reader size over `.body`'s own; 1 for the system's styles.
    public var scale: CGFloat {
        readerSize.map { $0 / PageFace.baseSize(.body) } ?? 1
    }

    /// The style of the text a page is read in (names, facts' values, the dictionary paragraph, the verse lines):
    /// `.body`, the reader size, at the reader's; the system's `.callout`, as these pages had it, otherwise.
    public var reading: Font.TextStyle {
        readerSize == nil ? .callout : .body
    }

    /// A style's point size: its macOS size times `scale`, to the half point; the system's base size otherwise.
    public func size(_ style: Font.TextStyle) -> CGFloat {
        guard readerSize != nil else { return PageFace.baseSize(style) }
        return (PageFace.baseSize(style) * scale * 2).rounded() / 2
    }

    /// A size or gap tied to the text (a `@ScaledMetric`'s value), grown by `scale`.
    public func metric(_ value: CGFloat) -> CGFloat {
        value * scale
    }

    /// The reader's measure, the text column's widest; nil with the system's styles.
    public var measure: CGFloat? {
        readerSize.map { ReaderTypography.measure(size: $0, columnWidth: columnWidth) }
    }

    /// The text column's widest (`LibraryColumn`): the reader's measure; with the system's styles, what the pages had
    /// before, `systemPage` (a scaled 520 pt page) less its `lg` margins. `outset` is added at each side.
    public func columnMaxWidth(systemPage: CGFloat, outset: CGFloat = 0) -> CGFloat {
        (measure ?? max(0, systemPage - 2 * AppSpacing.lg)) + 2 * outset
    }

    /// SF Pro in `style`: at `size(style)` with the reader's, else the semantic style (Dynamic Type).
    public func font(_ style: Font.TextStyle, weight: Font.Weight? = nil, italic: Bool = false) -> Font {
        var font: Font = readerSize == nil ? .system(style) : .system(size: size(style))
        if let weight { font = font.weight(weight) }
        return italic ? font.italic() : font
    }

    /// The page face in `style` (a title, a quoted or dictionary text): at `size(style)` with the reader's, else
    /// the face's own scaled style.
    @MainActor public func pageFont(_ face: PageFace, _ style: Font.TextStyle, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        guard readerSize != nil else { return face.swiftUIFont(style, weight: weight, italic: italic) }
        return Font(face.font(size: size(style), weight: weight.platformWeight, italic: italic) as CTFont)
    }

    /// The SF Pro font `font(_:weight:italic:)` draws, for measuring text as it will be set (the family tree).
    public func platformFont(_ style: Font.TextStyle, weight: PlatformFont.Weight = .regular, italic: Bool = false) -> PlatformFont {
        let plain = PlatformFont.systemFont(ofSize: size(style), weight: weight)
        guard italic else { return plain }
        #if canImport(AppKit)
        return NSFont(descriptor: plain.fontDescriptor.withSymbolicTraits(.italic), size: plain.pointSize) ?? plain
        #else
        return plain.fontDescriptor.withSymbolicTraits(.traitItalic).map { UIFont(descriptor: $0, size: plain.pointSize) } ?? plain
        #endif
    }
}

extension EnvironmentValues {
    /// The Library pages' type: the reader's on the Mac's front page, the system's everywhere else.
    @Entry public var libraryType = LibraryType.system
}
