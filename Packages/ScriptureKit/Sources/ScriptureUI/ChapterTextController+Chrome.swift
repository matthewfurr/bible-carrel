#if os(macOS)
import AppKit
import ScriptureData
import SwiftUI

/// What the chapter's page carries besides the text and its markup: a chapter-note mark on its
/// opening line, and the VoiceOver headings rotor over the opening and section headings.
extension ChapterTextController {
    /// A picture of the page under `frame`, for the thumb's loupe (`PageBackdrop`): the scroll
    /// view as it is drawn now, text, highlights and marks, at the window's own scale. `frame` is
    /// in SwiftUI's global coordinates, the window's content from its top leading corner.
    func pagePicture(under frame: CGRect) -> CGImage? {
        guard let content = scrollView.window?.contentView, frame.width > 0, frame.height > 0 else { return nil }
        var inContent = frame
        if !content.isFlipped { inContent.origin.y = content.bounds.height - frame.maxY }
        // On whole pixels, so no edge of the picture is half drawn.
        let rect = scrollView.backingAlignedRect(scrollView.convert(inContent, from: content), options: .alignAllEdgesNearest)
        guard let picture = scrollView.bitmapImageRepForCachingDisplay(in: rect) else { return nil }
        scrollView.cacheDisplay(in: rect, to: picture)
        return picture.cgImage
    }

    /// A chapter's note mark, hosted in the text view like the gutter's glyphs.
    typealias NoteMarkView = NSHostingView<ChapterNoteMark>

    /// One stop of the headings rotor: a run of the text and what the rotor lists it as.
    typealias HeadingItem = BookHeadingItem

    // MARK: - Chapter-note marks

    /// Puts a mark at the trailing end of the opening line when the chapter has chapter notes,
    /// and removes it otherwise. Positioned from line fragments, so it is re-run whenever the
    /// text reflows.
    func refreshChapterNoteMarks() {
        let counts = layout == nil ? [:] : chapterNoteCounts.filter { $0.value > 0 && layout?.section(for: $0.key) != nil }
        for (chapter, view) in chapterNoteMarkViews where counts[chapter] == nil {
            view.removeFromSuperview()
            chapterNoteMarkViews[chapter] = nil
        }
        guard let layout, !counts.isEmpty else { return }
        let bookName = BookCatalog.book(code: layout.id.book)?.chapterName ?? layout.id.book
        for (chapter, count) in counts {
            guard let section = layout.section(for: chapter) else { continue }
            let name = "\(bookName) \(chapter)"
            let view: NoteMarkView
            if let existing = chapterNoteMarkViews[chapter] {
                view = existing
                if existing.rootView.count != count || existing.rootView.chapter != name {
                    existing.rootView = noteMark(count: count, chapter: chapter, name: name)
                }
            } else {
                view = NoteMarkView(rootView: noteMark(count: count, chapter: chapter, name: name))
                textView.addSubview(view)
                chapterNoteMarkViews[chapter] = view
            }
            view.isHidden = !place(view, on: section)
        }
        applyOpeningNoteMarkAlpha()
    }

    /// The page's mark (beside its opening's label, or above Lectern's hairline) fades out as the
    /// running head, with its own mark, fades in: drawn at the opening label's alpha, and hidden
    /// (out of reach and of VoiceOver) once the head has replaced it.
    func applyOpeningNoteMarkAlpha() {
        guard let chapter = layout?.chapters.lowerBound, let view = chapterNoteMarkViews[chapter] else { return }
        view.alphaValue = openingLabelAlpha
        if openingLabelAlpha == 0 {
            view.isHidden = true
        } else if view.isHidden, let section = layout?.section(for: chapter) {
            view.isHidden = !place(view, on: section)
        }
    }

    /// The mark of `chapter` (named `name`, "John 3"), reporting that chapter when clicked.
    private func noteMark(count: Int, chapter: Int, name: String) -> ChapterNoteMark {
        ChapterNoteMark(count: count, chapter: name) { [weak self] in self?.onShowChapterNotes(chapter) }
    }

    /// Centred on the opening's last line (the label, or the title block's CHAPTER 1), flush with
    /// the column's trailing edge; in Lectern, whose chapter text starts just below its hairline
    /// opening, in the air above that line (`marksAboveOpeningLine`). False when the line cannot
    /// be found.
    private func place(_ view: NoteMarkView, on section: BookSection) -> Bool {
        let inset = textView.textContainerInset
        let column = textView.textContainer?.size.width ?? 0
        let size = view.fittingSize
        guard let layout, let line = lineFrame(forCharacterIndex: layout.openingMarkLineIndex(of: section), ensuringLayout: contentHeight <= 0)
        else { return false }
        let y = layout.marksAboveOpeningLine(of: section)
            ? max(0, line.minY + inset.height - AppSpacing.xs - size.height)
            : line.midY + inset.height - size.height / 2
        view.frame = NSRect(x: inset.width + column - size.width, y: y, width: size.width, height: size.height)
        return true
    }

    // MARK: - Headings rotor

    /// The book's title (on chapter 1), the chapter's opening and its section headings, in text order (`BookHeadings`).
    static func headingItems(in layout: BookLayout?) -> [HeadingItem] {
        BookHeadings.items(in: layout)
    }

    /// The next or previous item from `current` (VoiceOver's cursor, nil at the start of a
    /// search), among those whose label contains `filter` when it is not empty.
    static func heading(from current: NSRange?, direction: NSAccessibilityCustomRotor.SearchDirection, filter: String,
                        in items: [HeadingItem]) -> HeadingItem? {
        switch direction {
        case .next: BookHeadings.item(from: current?.location, forward: true, filter: filter, in: items)
        case .previous: BookHeadings.item(from: current?.location, forward: false, filter: filter, in: items)
        @unknown default: nil
        }
    }
}

/// The search behind the text view's headings rotor; the rotor holds it weakly, so the controller keeps it.
@MainActor
final class HeadingsRotorSearch: NSObject, @MainActor NSAccessibilityCustomRotorItemSearchDelegate {
    weak var controller: ChapterTextController?

    func rotor(_ rotor: NSAccessibilityCustomRotor, resultFor searchParameters: NSAccessibilityCustomRotor.SearchParameters)
        -> NSAccessibilityCustomRotor.ItemResult? {
        guard let controller,
              let item = ChapterTextController.heading(
                from: searchParameters.currentItem?.targetRange, direction: searchParameters.searchDirection,
                filter: searchParameters.filterString, in: controller.headingItems)
        else { return nil }
        let result = NSAccessibilityCustomRotor.ItemResult(targetElement: controller.textView)
        result.targetRange = item.range
        result.customLabel = item.label
        return result
    }
}
#endif
