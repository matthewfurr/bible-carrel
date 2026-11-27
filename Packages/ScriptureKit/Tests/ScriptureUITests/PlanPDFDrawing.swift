import CoreGraphics
import CoreText
import Foundation

/// Draws pages of table cells with Core Graphics and Core Text (Helvetica 11, 612 by 792 pt) into a PDF in the temporary directory. The caller removes it.
enum PlanPDFDrawing {
    struct Cell { let text: String; let centre: CGFloat; let y: CGFloat; var leading = false }     // `leading`: `centre` is the text's left edge (a date)

    /// In a directory of its own, so the file keeps `name`; remove `url.deletingLastPathComponent()`.
    static func pdf(named name: String = "Drawn Plan.pdf", pages: [[Cell]]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PlanPDFDrawing-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { throw CocoaError(.fileWriteUnknown) }
        let font = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
        for page in pages {
            context.beginPDFPage(nil)
            for cell in page where !cell.text.isEmpty {
                let attributed = NSAttributedString(string: cell.text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
                let line = CTLineCreateWithAttributedString(attributed)
                let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
                context.textPosition = CGPoint(x: cell.leading ? cell.centre : cell.centre - width / 2, y: cell.y)
                CTLineDraw(line, context)
            }
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    static func gen1Header() -> [Cell] {
        [Cell(text: "Wk", centre: 138, y: 663.3), Cell(text: "Wisdom", centre: 198.5, y: 663.3), Cell(text: "Chp", centre: 272, y: 663.3),
         Cell(text: "OT/NT", centre: 364.5, y: 663.3), Cell(text: "Chp", centre: 459.5, y: 663.3)]
    }

    static func gen2Header() -> [Cell] {
        [Cell(text: "Wk", centre: 83.5, y: 665.9), Cell(text: "Wisdom", centre: 126.5, y: 665.9), Cell(text: "Chp", centre: 189.5, y: 665.9),
         Cell(text: "OT/NT", centre: 258, y: 665.9), Cell(text: "Chp", centre: 315.5, y: 665.9), Cell(text: "Meeting Date", centre: 369, y: 665.9, leading: true)]
    }

    static func gen1Row(wk: String = "", _ wisdom: String, _ chapters: String, _ other: String, _ otherChapters: String, y: CGFloat) -> [Cell] {
        [Cell(text: wk, centre: 138, y: y), Cell(text: wisdom, centre: 198.5, y: y), Cell(text: chapters, centre: 272, y: y),
         Cell(text: other, centre: 364.5, y: y), Cell(text: otherChapters, centre: 460, y: y)]
    }

    static func gen2Row(wk: String = "", _ wisdom: String, _ chapters: String, _ other: String, _ otherChapters: String, y: CGFloat) -> [Cell] {
        [Cell(text: wk, centre: 83, y: y), Cell(text: wisdom, centre: 126.5, y: y), Cell(text: chapters, centre: 189.5, y: y),
         Cell(text: other, centre: 258, y: y), Cell(text: otherChapters, centre: 315.5, y: y)]
    }
}
