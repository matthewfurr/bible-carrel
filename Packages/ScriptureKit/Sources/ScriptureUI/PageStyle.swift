import CoreGraphics
import Foundation

/// A named set of typographic choices for the chapter (DESIGN.md section 3, Page Styles).
public enum PageStyle: String, CaseIterable, Sendable {
    case printed, lectern, study, classic

    public var title: String {
        switch self {
        case .printed: "Printed"
        case .lectern: "Lectern"
        case .study: "Study"
        case .classic: "Classic"
        }
    }

    /// The face the style is set in until the reader picks another.
    public var defaultFace: PageFace {
        switch self {
        case .printed: .literata
        case .lectern: .iowanOldStyle
        case .study: .sourceSerif
        case .classic: .newYork
        }
    }

    /// The line over the chapter in the style's own case ("JOHN · 3", "John · 3", "JOHN 3",
    /// "John 3"); Lectern draws its in small capitals. No style says "chapter" (Matt, 2026-11-13:
    /// Printed's did, alone, and ran too wide for the phone's bar to centre).
    public func runningHead(bookName: String, chapter: Int) -> String {
        switch self {
        case .printed: "\(bookName.uppercased()) · \(chapter)"
        case .lectern: "\(bookName) · \(chapter)"
        case .study: "\(bookName.uppercased()) \(chapter)"
        case .classic: "\(bookName) \(chapter)"
        }
    }
}

/// Settings → Reading: how wide the column runs, as a multiple of the size-derived measure.
public enum ColumnWidthChoice: String, CaseIterable, Sendable {
    case narrow, normal, wide

    public var multiplier: CGFloat {
        switch self {
        case .narrow: 0.85
        case .normal: 1
        case .wide: 1.15
        }
    }

    public var title: String {
        switch self {
        case .narrow: "Narrow"
        case .normal: "Normal"
        case .wide: "Wide"
        }
    }
}

/// Settings → Reading: running paragraphs, or each verse on its own line.
public enum VerseLayoutChoice: String, CaseIterable, Sendable {
    case paragraphs, versePerLine

    public var title: String {
        switch self {
        case .paragraphs: "Paragraphs"
        case .versePerLine: "Verse per line"
        }
    }
}
