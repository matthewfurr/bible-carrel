#if os(macOS)
import AppKit
import ScriptureData
import Testing
@testable import ScriptureUI

/// Round-four cases: recolor redraw, wrapped-range outlines, and scroll survival across the
/// text view's own frame resets, including against the real bundle data when it is present.
@MainActor @Suite struct ChapterTextControllerMarkupTests {
    private var yellow: MarkupColor { MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00") }
    private var blue: MarkupColor { MarkupColor(lightHex: "#B9DDFF", darkHex: "#1F4C7A") }

    private typealias F = ControllerFixture

    private func verses(count: Int, translation: String = "WEB") -> [Verse] {
        F.verses(count: count, translation: translation)
    }

    private func makeController(reported: @escaping (VerseLocation) -> Void) -> ChapterTextController {
        F.makeController(reported: reported)
    }

    private func sizeToContent(_ controller: ChapterTextController) {
        F.sizeToContent(controller)
    }

    /// A verse of Matthew 5.
    private func at(_ verse: Int) -> VerseLocation {
        VerseLocation(book: "MAT", chapter: 5, verse: verse)
    }

    private func at(_ chapter: Int, _ verse: Int) -> VerseLocation {
        VerseLocation(book: "MAT", chapter: chapter, verse: verse)
    }

    private func show(_ controller: ChapterTextController, _ layout: BookLayout, target: ScrollTarget? = nil, decorations: BookDecorations = .none) {
        controller.update(layout: layout, typography: .default, scrollTarget: target, decorations: decorations)
    }

    private func decorate(_ items: [MarkupItem], bookmarks: [Int] = [], outlinedID: UUID? = nil, viewing: String = "WEB", layout: BookLayout) -> BookDecorations {
        F.decorations(items, bookmarks: bookmarks.map { at(layout.chapters.lowerBound, $0) }, outlinedID: outlinedID, viewing: viewing, layout: layout)
    }

    private func backgroundColor(_ controller: ChapterTextController, at index: Int) -> NSColor? {
        let storage = controller.textView.textContentStorage!
        let layoutManager = controller.textView.textLayoutManager!
        var found: NSColor?
        layoutManager.enumerateRenderingAttributes(from: layoutManager.documentRange.location, reverse: false) { _, attributes, range in
            let start = storage.offset(from: storage.documentRange.location, to: range.location)
            let end = storage.offset(from: storage.documentRange.location, to: range.endLocation)
            if index >= start && index < end { found = attributes[.backgroundColor] as? NSColor; return false }
            return start <= index
        }
        return found
    }

    private func rgb(_ color: NSColor?) -> [CGFloat] {
        guard let c = color?.usingColorSpace(.sRGB) else { return [] }
        return [c.redComponent, c.greenComponent, c.blueComponent].map { ($0 * 255).rounded() }
    }

    @Test func recoloringAHighlightChangesItsBackgroundAtOnce() {
        let controller = makeController { _ in }
        let chapter = verses(count: 3)
        let layout = F.layout(chapter)
        let id = UUID()
        let asYellow = MarkupItem(id: id, chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 10, translationID: "WEB", color: yellow, hasNote: false)
        show(controller, layout, decorations: decorate([asYellow], bookmarks: [], viewing: "WEB", layout: layout))
        let before = controller.backgroundFills.filter { $0.id == id }
        let asBlue = MarkupItem(id: id, chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 10, translationID: "WEB", color: blue, hasNote: false)
        var recolored = decorate([asBlue], bookmarks: [], viewing: "WEB", layout: layout)
        recolored.outlinedID = id
        show(controller, layout, decorations: recolored)
        let after = controller.backgroundFills.filter { $0.id == id }
        #expect(before.count == 1 && after.count == 1)
        #expect(rgb(before.first?.color) == rgb(yellow.platformColor) && rgb(after.first?.color) == rgb(blue.platformColor))
        #expect(before.first?.rect == after.first?.rect)
        #expect(!controller.outlineView.segmentRects.isEmpty)
    }

    /// One geometry for both: the outline strokes the background's own rects, outset by 2 pt.
    @Test func outlineRectsAreTheBackgroundRectsOutsetByTwo() {
        let controller = makeController { _ in }
        let chapter = verses(count: 2)
        let layout = F.layout(chapter)
        let length = layout.spans[0].textRange.length
        let a = MarkupItem(id: UUID(), chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: length - 8, translationID: "WEB", color: yellow, hasNote: false)   // wraps
        var decorations = decorate([a], bookmarks: [], viewing: "WEB", layout: layout)
        decorations.outlinedID = a.id
        show(controller, layout, decorations: decorations)
        let fills = controller.backgroundFills.filter { $0.id == a.id }.map(\.rect)
        #expect(fills.count >= 2)
        #expect(controller.outlineView.segmentRects == fills.map { $0.insetBy(dx: -2, dy: -2) })
        #expect(controller.outlineView.outset == 0)
    }

    @Test func overlappingHighlightsFillTheOverlapWithABlend() {
        let controller = makeController { _ in }
        let chapter = verses(count: 3)
        let layout = F.layout(chapter)
        let a = MarkupItem(id: UUID(), chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 10, translationID: "WEB", color: yellow, hasNote: false)
        let b = MarkupItem(id: UUID(), chapter: 5, verse: 1, endVerse: 1, startOffset: 5, endOffset: 15, translationID: "WEB", color: blue, hasNote: false)
        show(controller, layout, decorations: decorate([a, b], bookmarks: [], viewing: "WEB", layout: layout))
        let fills = controller.backgroundFills
        let aFill = fills.first { $0.id == a.id }!, bFill = fills.first { $0.id == b.id }!
        let overlap = fills.first { $0.id == nil }
        #expect(overlap != nil)
        #expect(rgb(overlap?.color) != rgb(aFill.color) && rgb(overlap?.color) != rgb(bFill.color))
        #expect(abs((overlap?.rect.minX ?? 0) - bFill.rect.minX) < 0.5 && abs((overlap?.rect.maxX ?? 0) - aFill.rect.maxX) < 0.5)
        #expect(fills.firstIndex { $0.id == nil }! > fills.firstIndex { $0.id == b.id }!)   // drawn after both
    }

    /// Three highlights handed over out of location order: every pairwise overlap is painted
    /// exactly once, in its pair's blend, and only after every original fill.
    @Test func threeOverlappingHighlightsOutOfOrderBlendEachPairOnce() {
        let controller = makeController { _ in }
        let chapter = verses(count: 3)
        let layout = F.layout(chapter)
        let green = MarkupColor(lightHex: "#C6EBB4", darkHex: "#2F5A1F")
        let a = MarkupItem(id: UUID(), chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 10, translationID: "WEB", color: yellow, hasNote: false)
        let b = MarkupItem(id: UUID(), chapter: 5, verse: 1, endVerse: 1, startOffset: 5, endOffset: 15, translationID: "WEB", color: blue, hasNote: false)
        let c = MarkupItem(id: UUID(), chapter: 5, verse: 1, endVerse: 1, startOffset: 8, endOffset: 20, translationID: "WEB", color: green, hasNote: false)
        show(controller, layout, decorations: decorate([c, b, a], bookmarks: [], viewing: "WEB", layout: layout))
        let fills = controller.backgroundFills
        let aFill = fills.first { $0.id == a.id }!, bFill = fills.first { $0.id == b.id }!, cFill = fills.first { $0.id == c.id }!
        let blends = fills.filter { $0.id == nil }
        #expect(blends.count == 3)
        // Painted after both originals of every pair: the first blend follows the last original.
        #expect(fills.firstIndex { $0.id == nil }! > fills.lastIndex { $0.id != nil }!)
        // Pairs blend in the order the decorations were given (c, b, a).
        let expected: [(minX: CGFloat, maxX: CGFloat, color: NSColor)] = [
            (bFill.rect.minX, aFill.rect.maxX, .blendedMarkup(blue.platformColor, yellow.platformColor)),    // a and b
            (cFill.rect.minX, aFill.rect.maxX, .blendedMarkup(green.platformColor, yellow.platformColor)),   // a and c
            (cFill.rect.minX, bFill.rect.maxX, .blendedMarkup(green.platformColor, blue.platformColor)),     // b and c
        ]
        for pair in expected {
            let matches = blends.filter { abs($0.rect.minX - pair.minX) < 0.5 && abs($0.rect.maxX - pair.maxX) < 0.5 }
            #expect(matches.count == 1)
            #expect(rgb(matches.first?.color) == rgb(pair.color))
            #expect(rgb(matches.first?.color) != rgb(aFill.color) && rgb(matches.first?.color) != rgb(bFill.color) && rgb(matches.first?.color) != rgb(cFill.color))
        }
    }

    @Test func outlineOfAWrappedHighlightEndsAtItsLastGlyphOnEachLine() {
        let controller = makeController { _ in }
        let chapter = verses(count: 2)      // long verses: verse 1 wraps in the 604 pt column
        let layout = F.layout(chapter)
        let length = layout.spans[0].textRange.length
        let a = MarkupItem(id: UUID(), chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: length - 8, translationID: "WEB", color: yellow, hasNote: false)
        var decorations = decorate([a], bookmarks: [], viewing: "WEB", layout: layout)
        decorations.outlinedID = a.id
        show(controller, layout, decorations: decorations)
        sizeToContent(controller)
        let rects = controller.backgroundFills.filter { $0.id == a.id }.map(\.rect)
        #expect(rects.count >= 2)
        // The first line's rect ends where its last highlighted, non-space character ends, well
        // short of the column's trailing edge.
        let textView = controller.textView
        let storage = textView.textContentStorage!, layoutManager = textView.textLayoutManager!
        let start = layout.spans[0].textRange.location
        let location = storage.location(storage.documentRange.location, offsetBy: start)!
        let fragment = layoutManager.textLayoutFragment(for: location)!
        let fragmentStart = storage.offset(from: storage.documentRange.location, to: fragment.rangeInElement.location)
        let line = fragment.textLineFragments[0]
        let text = textView.string as NSString
        var lastIndex = fragmentStart + NSMaxRange(line.characterRange) - 1
        while lastIndex > start, text.character(at: lastIndex) == 0x20 { lastIndex -= 1 }
        let expectedRight = fragment.layoutFragmentFrame.minX + line.typographicBounds.minX + line.locationForCharacter(at: lastIndex + 1 - fragmentStart).x + textView.textContainerInset.width
        #expect(abs(rects[0].maxX - expectedRight) < 0.5)
        #expect(rects[0].maxX < textView.textContainerInset.width + textView.textContainer!.size.width - 20)
    }

    @Test func aFrameResetAfterSettlingRestoresTheScroll() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        show(controller, F.layout(verses(count: 60)), target: ScrollTarget(chapter: 5, verse: 29))
        sizeToContent(controller)
        let origin = controller.scrollView.contentView.bounds.minY
        #expect(reported == [at(29)] && origin > 0)
        // The text view's own sizing pass resets the frame to an estimate, clamping the clip view…
        controller.textView.setFrameSize(NSSize(width: controller.textView.frame.width, height: 200))
        // …and then grows it back.
        sizeToContent(controller)
        #expect(abs(controller.scrollView.contentView.bounds.minY - origin) < 0.5)
        #expect(reported == [at(29)])
    }

    /// Against the real bundle data when it is present: ESV Matthew 5 with a highlight, switched
    /// to KJV (dashed underline) through a frame reset, then back; the reader stays on verse 29.
    @Test func switchingTranslationsOnRealDataKeepsTheVerse() throws {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        url = url.appendingPathComponent("Build/bible.sqlite")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let store = try BibleStore(databaseURL: url)
        let esv = try store.chapter(ChapterLocation(book: "MAT", chapter: 5), translationID: "ESV")
        let kjv = try store.chapter(ChapterLocation(book: "MAT", chapter: 5), translationID: "KJV")
        guard !esv.isEmpty, !kjv.isEmpty else { return }
        let esvLayout = F.layout(esv), kjvLayout = F.layout(kjv)
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        let highlight = MarkupItem(id: UUID(), chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 20, translationID: "ESV", color: yellow, hasNote: false)
        show(controller, esvLayout, target: ScrollTarget(chapter: 5, verse: 29), decorations: decorate([highlight], bookmarks: [], viewing: "ESV", layout: esvLayout))
        sizeToContent(controller)
        show(controller, kjvLayout, target: ScrollTarget(chapter: 5, verse: 29), decorations: decorate([highlight], bookmarks: [], viewing: "KJV", layout: kjvLayout))
        sizeToContent(controller)
        controller.textView.setFrameSize(NSSize(width: controller.textView.frame.width, height: 200))   // a later sizing pass
        sizeToContent(controller)
        show(controller, esvLayout, target: ScrollTarget(chapter: 5, verse: 29), decorations: decorate([highlight], bookmarks: [], viewing: "ESV", layout: esvLayout))
        sizeToContent(controller)
        #expect(reported == [at(29), at(29), at(29)])
    }

    @Test func aTargetBeyondTheChapterClampsToTheLastVerse() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        show(controller, F.layout(verses(count: 50)), target: ScrollTarget(chapter: 5, verse: 99))
        let clip = controller.scrollView.contentView.bounds
        #expect(abs(clip.minY - (controller.textView.frame.height - clip.height)) < 0.5)   // scrolled to the end
        #expect(reported.count == 1 && reported[0].verse <= 50 && reported[0].verse > 1)
    }

    /// The real bundle: Matthew 6 ESV at verse 29 with a highlight, switched through every other
    /// bundled translation and back. The first visible verse is 29 after each switch and verse 1
    /// is never reported (so never saved) on the way.
    @Test func switchingThroughEveryTranslationOnRealDataKeepsVerse29() throws {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        url = url.appendingPathComponent("Build/bible.sqlite")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let store = try BibleStore(databaseURL: url)
        let ids = try store.translations().map(\.id)
        guard ids.contains("ESV") else { return }
        let sequence = ["KJV", "WEB", "ASV", "NASB", "ESV"].filter { ids.contains($0) }
        let chapter = ChapterLocation(book: "MAT", chapter: 6)
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        let highlight = MarkupItem(id: UUID(), chapter: 6, verse: 9, endVerse: 9, startOffset: 0, endOffset: 12, translationID: "ESV", color: yellow, hasNote: false)
        func showTranslation(_ translation: String) throws {
            let verses = try store.chapter(chapter, translationID: translation)
            #expect(!verses.isEmpty)
            let layout = F.layout(verses)
            let decorations = decorate([highlight], bookmarks: [3], viewing: translation, layout: layout)
            show(controller, layout, target: ScrollTarget(chapter: 6, verse: 29), decorations: decorations)
            // Whatever a later sizing pass does to the frame, the place holds.
            controller.textView.setFrameSize(NSSize(width: controller.textView.frame.width, height: 150))
        }
        try showTranslation("ESV")
        for translation in sequence { try showTranslation(translation) }
        #expect(reported.count == sequence.count + 1)
        #expect(reported.allSatisfy { $0 == at(6, 29) })
    }

    /// The first update happens before the column has its width; a reflow must recompute the
    /// fills along with the outline, from the same rects.
    @Test func backgroundFillsFollowAColumnReflow() {
        let controller = makeController { _ in }
        let chapter = verses(count: 6)
        let layout = F.layout(chapter)
        let length = layout.spans[0].textRange.length
        let a = MarkupItem(id: UUID(), chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: length - 8, translationID: "WEB", color: yellow, hasNote: false)
        var decorations = decorate([a], bookmarks: [], viewing: "WEB", layout: layout)
        decorations.outlinedID = a.id
        show(controller, layout, decorations: decorations)
        let before = controller.backgroundFills.filter { $0.id == a.id }.map(\.rect)
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 1100, height: 300)
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.flushPendingReflow()      // the resize settles
        let after = controller.backgroundFills.filter { $0.id == a.id }.map(\.rect)
        #expect(after != before)
        #expect(controller.outlineView.segmentRects == after.map { $0.insetBy(dx: -2, dy: -2) })
    }

    /// A card click outlines a highlight that may be far off screen: the reader scrolls so its
    /// first line is visible.
    @Test func outliningAnOffscreenHighlightScrollsItIntoView() {
        let controller = makeController { _ in }
        let chapter = verses(count: 60)
        let layout = F.layout(chapter)
        let a = MarkupItem(id: UUID(), chapter: 5, verse: 50, endVerse: 50, startOffset: 0, endOffset: 12, translationID: "WEB", color: yellow, hasNote: true)
        var decorations = decorate([a], bookmarks: [], viewing: "WEB", layout: layout)
        show(controller, layout, target: ScrollTarget(chapter: 5, verse: 1), decorations: decorations)
        let first = controller.frameOfFirstSegment(of: decorations.decoration(id: a.id)!.range)!
        #expect(!controller.scrollView.documentVisibleRect.intersects(first))
        decorations.outlinedID = a.id
        show(controller, layout, target: ScrollTarget(chapter: 5, verse: 1), decorations: decorations)
        #expect(controller.scrollView.documentVisibleRect.contains(first))
    }

    /// An outline on a highlight already on screen (a click inside it) leaves the scroll alone.
    @Test func outliningAVisibleHighlightDoesNotScroll() {
        let controller = makeController { _ in }
        let chapter = verses(count: 60)
        let layout = F.layout(chapter)
        let a = MarkupItem(id: UUID(), chapter: 5, verse: 21, endVerse: 21, startOffset: 0, endOffset: 12, translationID: "WEB", color: yellow, hasNote: true)
        var decorations = decorate([a], bookmarks: [], viewing: "WEB", layout: layout)
        show(controller, layout, target: ScrollTarget(chapter: 5, verse: 20), decorations: decorations)
        let origin = controller.scrollView.contentView.bounds.origin
        decorations.outlinedID = a.id
        show(controller, layout, target: ScrollTarget(chapter: 5, verse: 20), decorations: decorations)
        #expect(controller.scrollView.contentView.bounds.origin == origin)
    }

    /// The text system's own rects for `range`, one per line, in text-view coordinates: what the
    /// selection highlight would cover.
    private func systemSegments(_ controller: ChapterTextController, _ range: NSRange) -> [NSRect] {
        let textView = controller.textView
        let storage = textView.textContentStorage!, layoutManager = textView.textLayoutManager!
        let start = storage.location(storage.documentRange.location, offsetBy: range.location)!
        let end = storage.location(start, offsetBy: range.length)!
        var rects: [NSRect] = []
        layoutManager.enumerateTextSegments(in: NSTextRange(location: start, end: end)!, type: .standard, options: []) { _, frame, _, _ in
            rects.append(frame.offsetBy(dx: textView.textContainerInset.width, dy: textView.textContainerInset.height))
            return true
        }
        return rects
    }

    /// The KJV sets each verse as its own indented paragraph: a highlight from a verse's first
    /// word covers exactly its words on the indented first line and on the line after.
    @Test func aHighlightOnAnIndentedFirstLineCoversItsOwnWords() {
        let controller = makeController { _ in }
        let chapter = (1...3).map { n in
            Verse(id: VerseLocation(book: "MRK", chapter: 1, verse: n), translationID: "KJV",
                  text: "And straightway they forsook their nets, and followed him, and the words run on to wrap the line again.",
                  breakAfter: true)
        }
        let layout = F.layout(chapter)
        let span = layout.spans[1]          // a prose paragraph: indented first line
        let a = MarkupItem(id: UUID(), chapter: 1, verse: 2, endVerse: 2, startOffset: 0, endOffset: span.textRange.length, translationID: "KJV", color: yellow, hasNote: false)
        var decorations = decorate([a], bookmarks: [], viewing: "KJV", layout: layout)
        decorations.outlinedID = a.id
        show(controller, layout, decorations: decorations)
        let fills = controller.backgroundFills.filter { $0.id == a.id }.map(\.rect)
        let system = systemSegments(controller, span.textRange)
        #expect(fills.count >= 2 && fills.count == system.count)
        for (fill, line) in zip(fills, system) {
            #expect(abs(fill.minX - line.minX) < 0.5, "fill starts at \(fill.minX), its words at \(line.minX)")
        }
        // The first line ends where its last word ends (the system's rect runs on over the space).
        let firstLineWords = fills[0]
        #expect(firstLineWords.maxX <= system[0].maxX + 0.5 && firstLineWords.maxX > system[0].maxX - 20)
        #expect(controller.outlineView.segmentRects == fills.map { $0.insetBy(dx: -2, dy: -2) })
    }

    /// A wrapped poetry line hangs: the fill on its second line starts under its own words, not
    /// in the hanging indent.
    @Test func aHighlightOnAWrappedPoetryLineCoversItsOwnWords() {
        let controller = makeController { _ in }
        let line = "Blessed is the man that walketh not in the counsel of the ungodly, nor standeth in the way of sinners, nor sitteth"
        let chapter = [Verse(id: VerseLocation(book: "PSA", chapter: 1, verse: 1), translationID: "KJV", text: line + "\nin the seat of the scornful.", breakAfter: true)]
        let layout = F.layout(chapter)
        let range = NSRange(location: layout.spans[0].textRange.location, length: (line as NSString).length)
        let a = MarkupItem(id: UUID(), chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: range.length, translationID: "KJV", color: yellow, hasNote: false)
        show(controller, layout, decorations: decorate([a], bookmarks: [], viewing: "KJV", layout: layout))
        let fills = controller.backgroundFills.filter { $0.id == a.id }.map(\.rect)
        let system = systemSegments(controller, range)
        #expect(fills.count >= 2 && fills.count == system.count)
        for (fill, segment) in zip(fills, system) {
            #expect(abs(fill.minX - segment.minX) < 0.5, "fill starts at \(fill.minX), its words at \(segment.minX)")
        }
    }

    /// A click on a line maps to a character on that line (not the document end).
    @Test func pointsInsideTheTextMapToTheirCharacters() {
        let controller = makeController { _ in }
        let chapter = verses(count: 20)
        let layout = F.layout(chapter)
        show(controller, layout, target: ScrollTarget(chapter: 5, verse: 8))
        // The first segment of verse 10, in text-view coordinates.
        let span = layout.span(for: at(10))!
        let frame = controller.frameOfFirstSegment(of: NSRange(location: span.textRange.location, length: 5))!
        let index = controller.textView.characterIndexForInsertion(at: NSPoint(x: frame.midX, y: frame.midY))
        #expect(index >= span.textRange.location && index <= span.textRange.location + 5)
        // And the same through the scroll view, as a window would deliver it.
        let inClip = controller.textView.convert(NSPoint(x: frame.midX, y: frame.midY), to: controller.scrollView.contentView)
        let hit = controller.scrollView.contentView.hitTest(controller.scrollView.contentView.convert(inClip, to: controller.scrollView.contentView.superview))
        #expect(hit === controller.textView)
    }
}
#endif
