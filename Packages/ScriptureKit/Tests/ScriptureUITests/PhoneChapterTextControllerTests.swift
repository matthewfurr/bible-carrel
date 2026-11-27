#if os(iOS)
import ScriptureData
import ScriptureModel
// Only the hosting controller: SwiftUI's own `ScrollTarget` would shadow the reader's.
import class SwiftUI.UIHostingController
import Testing
import UIKit
@testable import ScriptureUI

/// Chapter layouts and a controller in a window for the phone's suite: Matthew-shaped chapters of
/// long verses that wrap in the column, a paragraph break every four verses (as the Mac's fixture).
@MainActor enum PhoneControllerFixture {
    static let opening = BookOpening(bookName: "Matthew", title: BookTitle(title: "Matthew", subtitle: "The Gospel According to Matthew"))

    static func verses(chapter: Int, count: Int, translation: String = "WEB", book: String = "MAT") -> [Verse] {
        (1...count).map { n in
            Verse(
                id: VerseLocation(book: book, chapter: chapter, verse: n),
                translationID: translation,
                text: "Verse \(n) of \(translation) says enough words to wrap onto a second line in a narrow column, surely.",
                breakAfter: n % 4 == 0)
        }
    }

    /// Chapters `range` of a book whose chapter n has `counts[n]` verses (30 when not given); the
    /// reader shows one chapter, so the suite passes a range of one.
    static func book(_ range: ClosedRange<Int>, counts: [Int: Int] = [:], book: String = "MAT",
                     headings: [Int: [Int: [SectionHeading]]] = [:], typography: ReaderTypography = .default) -> BookLayout {
        let inputs = range.map { chapter in
            BookChapterInput(location: ChapterLocation(book: book, chapter: chapter),
                             verses: verses(chapter: chapter, count: counts[chapter] ?? 30, book: book),
                             headings: headings[chapter] ?? [:])
        }
        return BookLayout.build(chapters: inputs, opening: opening, typography: typography)
    }

    /// The controller's page in a window of its own, laid out; the window must outlive the test's use.
    @MainActor final class Harness {
        let controller: PhoneChapterTextController
        let window: UIWindow

        init(width: CGFloat, height: CGFloat, reported: @escaping (VerseLocation) -> Void) {
            controller = PhoneChapterTextController(onReadingPositionChange: reported)
            window = TestWindow.make(frame: CGRect(x: 0, y: 0, width: width, height: height))
            controller.pageView.frame = window.bounds
            window.addSubview(controller.pageView)
            window.isHidden = false
            window.layoutIfNeeded()
        }

        var textView: UITextView { controller.textView }

        func show(_ layout: BookLayout, typography: ReaderTypography = .default, target: ScrollTarget? = nil,
                  decorations: BookDecorations = .none, marks: [MarginMark] = [], footer: UIView? = nil) {
            controller.update(layout: layout, typography: typography, scrollTarget: target, decorations: decorations,
                              marginMarks: marks, footer: footer)
            textView.layoutIfNeeded()
        }

        func scroll(toY y: CGFloat) {
            textView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }

        /// Puts the head's line (the line just under the bar) at `y` in the text view's content.
        func scrollHeadLine(to y: CGFloat) {
            scroll(toY: y - (controller.headLineY ?? 0) - PhoneChapterTextController.scrollLeadIn)
        }

        /// How far below the visible top the first line of `range` sits.
        func offsetBelowTop(_ range: NSRange) -> CGFloat {
            (controller.rect(for: range)?.minY ?? .nan) - textView.contentOffset.y
        }

        var maxOffsetY: CGFloat {
            max(-textView.adjustedContentInset.top,
                textView.contentSize.height + textView.adjustedContentInset.bottom - textView.bounds.height)
        }

        var isAtEnd: Bool { abs(textView.contentOffset.y - maxOffsetY) < 1 }

        /// The bottom of the visible page, above the bars below it.
        var visibleBottom: CGFloat {
            textView.contentOffset.y + textView.bounds.height - textView.adjustedContentInset.bottom
        }
    }

    /// `ChapterEndLinks` hosted as the phone's footer is (`PhoneChapterTextView.Coordinator`).
    static func links(previous: String?, next: String?) -> UIHostingController<ChapterEndLinks> {
        let hosting = UIHostingController(rootView: ChapterEndLinks(previousTitle: previous, nextTitle: next, onPrevious: {}, onNext: {}))
        hosting.safeAreaRegions = []
        hosting.view.backgroundColor = .clear
        return hosting
    }
}

/// Drives the phone's TextKit 2 controller in a window of its own (a pending scroll waits for one).
@MainActor @Suite struct PhoneChapterTextControllerTests {
    private typealias F = PhoneControllerFixture

    private func at(_ chapter: Int, _ verse: Int, book: String = "MAT") -> VerseLocation {
        VerseLocation(book: book, chapter: chapter, verse: verse)
    }

    /// The pen never starts a stroke in an opening (the title block, a later chapter's hairline), only in
    /// the verse text, in every style (classified by `openingRange`, not by role), each chapter
    /// shown alone.
    @Test(arguments: PageStyle.allCases)
    func paintingNeverStartsInAnOpening(style: PageStyle) throws {
        var prefs = ReaderPreferences.default
        prefs.style = style
        let typography = ReaderTypography.styled(prefs)
        let page = F.Harness(width: 390, height: 700) { _ in }
        page.controller.setPen(isOn: true, color: .systemYellow, selectedID: nil)
        for chapter in 1...3 {
            let layout = F.book(chapter...chapter, counts: [chapter: 6], typography: typography)
            page.show(layout, typography: typography)
            let section = layout.sections[0]
            let string = layout.attributedString.string as NSString
            // Every run of the opening: the title, the subtitle, the label; a later chapter's hairline.
            var index = section.openingRange.location
            while index < NSMaxRange(section.openingRange) {
                let paragraph = string.paragraphRange(for: NSRange(location: index, length: 0))
                let run = NSIntersectionRange(paragraph, section.openingRange)
                if let rect = page.controller.rect(for: run) {
                    let point = CGPoint(x: rect.midX, y: rect.midY)
                    #expect(!page.controller.isPaintable(point), "\(style) chapter \(section.location.chapter) at \(string.substring(with: run))")
                }
                index = NSMaxRange(paragraph)
            }
            let span = try #require(layout.span(for: at(chapter, 2)))
            let rect = try #require(page.controller.rect(for: NSRange(location: span.textRange.location, length: 5)))
            #expect(page.controller.isPaintable(CGPoint(x: rect.midX, y: rect.midY)), "\(style) chapter \(chapter)")
        }
    }

    /// Matt, 2026-11-13: the thumb's ruler ran over the margin's notes and bookmarks. While the
    /// thumb is pressed the marks stand aside, and they are back when it lifts or is cancelled.
    /// The loupe's picture of the page is the text view as drawn, at the size asked.
    @Test func theMarginsMarksStandAsideWhileTheThumbIsPressed() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let layout = F.book(3...3, counts: [3: 8])
        let marks = MarginMark.build(notesByChapter: [:], itemsByChapter: [:], bookmarksByChapter: [3: [5, 7]], layout: layout)
        page.show(layout, marks: marks, footer: nil)
        let buttons = page.controller.markButtons
        #expect(buttons.count == 2 && buttons.allSatisfy { $0.alpha == 1 })
        let edge = CGPoint(x: page.textView.bounds.width - 10, y: 300)
        page.controller.thumbPressed(.began, at: edge, touchStartedAt: edge)
        #expect(page.controller.thumbHidesMarks && buttons.allSatisfy { $0.alpha == 0 })
        let picture = try #require(page.controller.pagePicture(under: CGRect(x: 100, y: 200, width: 64, height: 64), scale: 2))
        #expect(picture.width == 128 && picture.height == 128)
        page.controller.thumbPressed(.ended, at: edge, touchStartedAt: edge)
        #expect(!page.controller.thumbHidesMarks && buttons.allSatisfy { $0.alpha == 1 })
        page.controller.thumbPressed(.began, at: edge, touchStartedAt: edge)
        page.controller.thumbPressed(.cancelled, at: edge, touchStartedAt: edge)
        #expect(buttons.allSatisfy { $0.alpha == 1 })
    }

    /// Notes and bookmarks carry margin marks, each beside its own line, named with its chapter
    /// for VoiceOver; the page lists the text, the marks top down and the footer, in that order.
    @Test func marginMarksSitBesideTheirLines() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let layout = F.book(3...3, counts: [3: 8])
        let highlight = MarkupItem(id: UUID(), chapter: 3, verse: 2, endVerse: 2, startOffset: 6, endOffset: 12,
                                   translationID: "WEB", color: nil, hasNote: true)
        let card = NoteCard(id: UUID(), highlightID: highlight.id, referenceString: "Matthew 3:2", quotedText: "of WEB",
                            body: "A note.", modifiedAt: Date(), color: nil, colorID: nil, isChapterNote: false)
        let marks = MarginMark.build(notesByChapter: [3: [card]], itemsByChapter: [3: [highlight]],
                                     bookmarksByChapter: [3: [5, 7]], layout: layout)
        #expect(marks.count == 3)
        let footer = UILabel()
        footer.text = "Next: Mark"
        page.show(layout, marks: marks, footer: footer)

        let buttons = page.controller.markButtons
        #expect(buttons.count == 3 && buttons.allSatisfy { !$0.isHidden })
        #expect(buttons.map(\.accessibilityLabel) == ["Note, chapter 3 verse 2", "Bookmark, chapter 3 verse 5", "Bookmark, chapter 3 verse 7"])
        let inset = page.textView.textContainerInset
        for (mark, button) in zip(marks, buttons) {
            let line = try #require(page.controller.rect(for: NSRange(location: mark.characterIndex, length: 1)))
            #expect(abs(button.frame.midY - line.midY) < 1.5, "\(mark.id)")
            #expect(button.frame.minX >= page.textView.bounds.width - inset.right - 0.5, "in the right margin")
        }
        #expect(buttons[0].frame.minY < buttons[1].frame.minY && buttons[1].frame.minY < buttons[2].frame.minY)

        let elements = try #require(page.controller.pageView.accessibilityElements)
        #expect((elements.first as? UIView) === page.textView)
        #expect(elements.dropFirst().prefix(3).map { $0 as? UIView } == buttons.map { $0 as UIView? })
        #expect((elements.last as? UIView) === footer)
    }

    /// Ruling R8: copy (⌘C, VoiceOver's Copy) and the edit menu's Copy and Share write only the
    /// selection's verse text, never a label, a hairline's joiner or a heading: a selection from
    /// inside the chapter's opening (chapter 1's label, a later chapter's empty hairline) across
    /// a heading; a selection of the opening alone copies nothing.
    @Test(arguments: [1, 4])
    func copyingASelectionAcrossAnOpeningWritesOnlyVerseText(chapter: Int) throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let pasteboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        page.controller.pasteboard = pasteboard
        let headings: [Int: [Int: [SectionHeading]]] = [chapter: [3: [SectionHeading(text: "A Heading", level: 1)]]]
        let layout = F.book(chapter...chapter, counts: [chapter: 4], headings: headings)
        page.show(layout)
        let from = NSMaxRange(layout.section(for: chapter)!.openingRange) - 2
        let to = layout.span(for: at(chapter, 4))!.textRange.location + 5
        let range = NSRange(location: from, length: to - from)
        page.textView.selectedRange = range
        page.textView.copy(nil)
        let copied = try #require(pasteboard.string)
        #expect(copied.hasPrefix("Verse 1 of WEB") && copied.hasSuffix("Verse") && copied.contains("Verse 3 of WEB"))
        #expect(!copied.contains("CHAPTER") && !copied.contains("A Heading") && !copied.contains("\u{2060}"))

        var menuReport: SelectionReport?
        page.controller.menuProvider = { report in
            menuReport = report
            return nil
        }
        _ = page.controller.textView(page.textView, editMenuForTextIn: range, suggestedActions: [])
        #expect(menuReport?.selection.quotedText == copied)

        pasteboard.items = []
        page.textView.selectedRange = layout.section(for: chapter)!.openingRange
        page.textView.copy(nil)
        #expect(pasteboard.string == nil)
    }

    /// Chapter 1 with chapter notes carries a mark on its opening line (the title block's
    /// CHAPTER 1), at the column's trailing end, naming its chapter; as the bar's title fades in
    /// over the title block the mark fades with the label, and comes back at the top.
    @Test func chapterOnesNoteMarkSitsOnItsLabelAndFadesWithIt() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        page.controller.headLineY = 46
        let chapter = 1, count = 2
        let layout = F.book(chapter...chapter, counts: [chapter: 30])
        page.show(layout, target: ScrollTarget(chapter: chapter, verse: 1))
        page.controller.chapterNoteCounts = [chapter: count]
        #expect(Set(page.controller.chapterNoteMarkViews.keys) == [chapter])
        let mark = try #require(page.controller.chapterNoteMarkViews[chapter])
        let inset = page.textView.textContainerInset
        let columnRight = page.textView.bounds.width - inset.right
        let opening = try #require(layout.section(for: chapter)?.openingRange)
        #expect(!layout.marksAboveOpeningLine(of: layout.sections[0]))
        let label = try #require(page.controller.rect(for: NSRange(location: NSMaxRange(opening) - 2, length: 1)))
        #expect(abs(mark.frame.maxX - columnRight) < 1)
        #expect(abs(mark.frame.midY - label.midY) < 4)
        #expect(mark.frame.width > 0 && mark.frame.height > 0)
        // The touch area never covers the label's text nor runs past the screen.
        let area = mark.convert(mark.hitArea, to: page.textView)
        #expect(area.maxX <= page.textView.bounds.width + 0.5 && area.minX >= label.maxX - 0.5)
        #expect(mark.chapterName == "Matthew 1" && mark.count == count)
        #expect(mark.accessibilityLabel == "2 chapter notes in Matthew 1")
        #expect(!mark.isHidden && mark.alpha == 1, "at the top")

        let band = try #require(page.controller.chapterBand)
        page.scrollHeadLine(to: band.openingMaxY - RunningHead.fadeDistance / 2)
        #expect(abs(mark.alpha - page.controller.openingLabelAlpha) < 0.01)
        #expect(page.controller.openingLabelAlpha > 0.3 && page.controller.openingLabelAlpha < 0.7)
        page.scrollHeadLine(to: band.textMaxY)
        #expect(mark.alpha == 0 && mark.isHidden)
        page.scroll(toY: -page.textView.adjustedContentInset.top)
        #expect(mark.alpha == 1 && !mark.isHidden, "back at the top")
    }

    /// Matt, 2026-11-13: a later chapter has no label for its mark to sit beside or fade with. In
    /// every style its chapter-note mark sits above its hairline opening (as Lectern's did), at
    /// the column's trailing edge, in the air the page keeps above a later chapter's first line,
    /// its touch area clear of the text and of the screen's edge. It is fully drawn at the top,
    /// where the bar's title is already shown, and stays so as it scrolls away with the page.
    @Test(arguments: PageStyle.allCases)
    func aLaterChaptersNoteMarkSitsAboveItsOpeningAndScrollsWithThePage(style: PageStyle) throws {
        let typography = ReaderTypography.styled(ReaderPreferences(style: style))
        let page = F.Harness(width: 390, height: 700) { _ in }
        page.controller.headLineY = 46
        let layout = F.book(3...3, counts: [3: 30], typography: typography)
        page.show(layout, typography: typography, target: ScrollTarget(chapter: 3, verse: 1))
        page.controller.chapterNoteCounts = [3: 12]
        #expect(Set(page.controller.chapterNoteMarkViews.keys) == [3])
        let mark = try #require(page.controller.chapterNoteMarkViews[3])
        let section = try #require(layout.section(for: 3))
        #expect(layout.attributedString.readerRole(at: section.openingRange.location) == (style == .lectern ? .dropNumeral(3) : .chapterStart(3)))
        #expect(layout.marksAboveOpeningLine(of: section), "\(style)")
        let inset = page.textView.textContainerInset
        #expect(inset.top == PhoneChapterTextController.verticalInset + PhoneChapterTextController.laterChapterAir, "\(style)")
        let columnRight = page.textView.bounds.width - inset.right
        let hairline = try #require(page.controller.lineFrame(forCharacterIndex: section.openingRange.location))
        let text = try #require(page.controller.lineFrame(forCharacterIndex: section.spans[0].textRange.location))
        #expect(abs(mark.frame.maxX - columnRight) < 1, "\(style)")
        #expect(mark.frame.width > 0 && mark.frame.height > 0)
        #expect(mark.frame.minY >= 0, "\(style): inside the page's top inset, at \(mark.frame.minY)")
        #expect(abs(mark.frame.maxY - (hairline.minY + inset.top - AppSpacing.xs)) <= 1, "\(style): just above the hairline")
        #expect(mark.frame.maxY <= text.minY + inset.top - AppSpacing.xs + 1, "\(style): in the air above the chapter's text")
        let area = mark.convert(mark.hitArea, to: page.textView)
        #expect(area.maxY <= text.minY + inset.top + 0.5 && area.maxX <= page.textView.bounds.width + 0.5, "\(style): clear of the text")
        #expect(area.height >= MarginMarkButton.minimumHitSize - 0.5 && area.width >= MarginMarkButton.minimumHitSize - 0.5, "\(style)")
        #expect(mark.chapterName == "Matthew 3" && mark.count == 12)
        #expect(mark.accessibilityLabel == "12 chapter notes in Matthew 3")
        #expect(page.controller.runningHead?.headOpacity == 1, "\(style): the bar's title is shown at the top")
        #expect(!mark.isHidden && mark.alpha == 1, "\(style) at the top")

        // It never fades: where chapter 1's is halfway gone, and with the chapter read through.
        let frame = mark.frame
        let band = try #require(page.controller.chapterBand)
        for y in [band.openingMaxY - RunningHead.fadeDistance / 2, band.openingMaxY + 1, band.textMaxY] {
            page.scrollHeadLine(to: y)
            #expect(mark.alpha == 1 && !mark.isHidden && mark.frame == frame, "\(style) at \(y)")
        }
        page.scroll(toY: -page.textView.adjustedContentInset.top)
        #expect(mark.alpha == 1 && !mark.isHidden && mark.frame == frame, "\(style) back at the top")
    }

    /// VoiceOver's Headings rotor walks the book's title, the chapter's opening and its section
    /// headings.
    @Test func theHeadingsRotorVisitsTitlesLabelsAndSectionHeadings() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let headings = [1: [3: [SectionHeading(text: "The Wedding at Cana", level: 1)]]]
        let layout = F.book(1...1, counts: [1: 4], headings: headings)
        page.show(layout)
        let items = page.controller.headingItems
        #expect(items.map(\.label) == ["Matthew", "Matthew 1", "The Wedding at Cana"])
        // Matt, 2026-11-13: a later chapter has no label, and the rotor still names its opening,
        // at its empty hairline, before its headings.
        let later = F.book(2...2, counts: [2: 4], headings: [2: [1: [SectionHeading(text: "The Visit of the Wise Men", level: 1)]]])
        let laterItems = BookHeadings.items(in: later)
        #expect(laterItems.map(\.label) == ["Matthew 2", "The Visit of the Wise Men"])
        #expect(laterItems.first?.range == NSRange(location: later.sections[0].openingRange.location, length: 1))
        #expect(later.attributedString.readerRole(at: later.sections[0].openingRange.location) == .chapterStart(2))

        let rotor = try #require(page.textView.accessibilityCustomRotors?.first { $0.systemRotorType == .heading })
        let predicate = UIAccessibilityCustomRotorSearchPredicate()
        predicate.searchDirection = .next
        var visited: [NSRange] = []
        while let result = rotor.itemSearchBlock(predicate) {
            let range = try #require(result.targetRange)
            let start = page.textView.offset(from: page.textView.beginningOfDocument, to: range.start)
            visited.append(NSRange(location: start, length: page.textView.offset(from: range.start, to: range.end)))
            #expect(result.targetElement as? UITextView === page.textView)
            predicate.currentItem = result
            if visited.count > items.count { break }
        }
        #expect(visited == items.map(\.range))
        predicate.searchDirection = .previous
        let back = try #require(rotor.itemSearchBlock(predicate)?.targetRange)
        #expect(page.textView.offset(from: page.textView.beginningOfDocument, to: back.start) == items[1].range.location)
    }

    /// Every chapter ends with its links (spec 3.1), as on `main`: shown alone, chapters 1, 14
    /// and 28 each carry `ChapterEndLinks` under their text, in the space the page keeps for it
    /// below the text's own inset, fully shown and live at the page's foot with nothing to
    /// reveal, and read last by VoiceOver.
    @Test func everyChapterEndsWithItsLinks() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        for chapter in [1, 14, 28] {
            let links = F.links(previous: chapter > 1 ? "Matthew \(chapter - 1)" : "Malachi 4",
                                next: chapter < 28 ? "Matthew \(chapter + 1)" : "Mark 1")
            page.show(F.book(chapter...chapter, counts: [chapter: 30]), target: ScrollTarget(chapter: chapter, verse: 1),
                      footer: links.view)
            let footer = try #require(links.view)
            let inset = page.textView.textContainerInset
            let textBottom = inset.top + (page.textView.textLayoutManager?.usageBoundsForTextContainer.maxY ?? 0)
            #expect(footer.superview === page.textView, "chapter \(chapter)")
            let fitted = links.sizeThatFits(in: CGSize(width: footer.frame.width, height: CGFloat.greatestFiniteMagnitude))
            #expect(footer.frame.height > 0 && abs(footer.frame.height - ceil(fitted.height)) < 0.5, "chapter \(chapter): \(footer.frame)")
            #expect(abs(footer.frame.minY - (textBottom + PhoneChapterTextController.verticalInset)) < 0.5, "chapter \(chapter)")
            #expect(abs(inset.bottom - (PhoneChapterTextController.verticalInset + footer.frame.height)) < 0.5, "chapter \(chapter)")
            #expect(abs(page.textView.contentSize.height - ceil(textBottom + inset.bottom)) < 0.5, "chapter \(chapter)")
            page.scroll(toY: page.maxOffsetY)
            #expect(footer.frame.maxY <= page.visibleBottom + 0.5, "chapter \(chapter): the links in view at the foot")
            #expect(!footer.isHidden && footer.alpha == 1 && footer.isUserInteractionEnabled, "chapter \(chapter)")
            #expect((page.controller.pageView.accessibilityElements?.last as? UIView) === footer, "chapter \(chapter)")
        }
    }

    /// A turn back lands with the chapter's foot, and its links, at the bottom of the page.
    @Test func turningBackToTheEndLandsAtTheFoot() {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let links = F.links(previous: "Matthew 1", next: "Matthew 3")
        page.show(F.book(2...2, counts: [2: 60]), target: ScrollTarget(chapter: 2, verse: 1, atEnd: true), footer: links.view)
        #expect(page.maxOffsetY > 0)
        #expect(abs(page.textView.contentOffset.y - page.maxOffsetY) < 0.5)
        #expect(page.isAtEnd)
    }

    /// The links never crowd: side by side where they fit; on a phone, where two long names do
    /// not, side by side still without "Previous:" and "Next:" (Matt, 2026-11-13: "why are these
    /// on different lines?"); only narrower than that one above the other at the leading edge.
    /// The page keeps whichever height they take.
    @Test func theChapterLinksStackOnlyWhenEvenTheirNamesDoNotFit() throws {
        let links = F.links(previous: "Lamentations 5", next: "Ezekiel 1")
        let wide = links.sizeThatFits(in: CGSize(width: 1000, height: CGFloat.greatestFiniteMagnitude))
        let phone = links.sizeThatFits(in: CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
        #expect(abs(phone.height - wide.height) < 0.5, "one line at a phone's width: \(phone) against \(wide)")
        let narrow = links.sizeThatFits(in: CGSize(width: 150, height: CGFloat.greatestFiniteMagnitude))
        // Two links one above the other, each with its `sm` above and below and `xs` between, take
        // twice the height of the two side by side and more; side-by-side labels wrapped in the
        // narrow width take less, and links stacked at both widths the same.
        #expect(wide.height > 0 && narrow.height >= 2 * wide.height + AppSpacing.xs - 0.5, "one above the other: \(narrow) against \(wide)")
        let page = F.Harness(width: 200, height: 700) { _ in }
        page.show(F.book(1...1, counts: [1: 14], book: "EZK"), target: ScrollTarget(chapter: 1, verse: 1), footer: links.view)
        let footer = try #require(links.view)
        #expect(footer.frame.height >= 2 * wide.height + AppSpacing.xs - 0.5, "\(footer.frame)")
        // The chapter's last line ends above the stacked links, which end with the page.
        let lastLine = page.textView.textContainerInset.top + (page.textView.textLayoutManager?.usageBoundsForTextContainer.maxY ?? 0)
        #expect(footer.frame.minY >= lastLine && abs(footer.frame.maxY - page.textView.contentSize.height) < 1, "\(footer.frame) under \(lastLine)")
        #expect(abs(page.textView.textContainerInset.bottom - (PhoneChapterTextController.verticalInset + footer.frame.height)) < 0.5)
    }

    /// With the links' space kept under the text, the head's line never reaches the chapter's
    /// last line, yet at the page's foot the chapter is read through: progress 1 there, and short
    /// of 1 a point above it.
    @Test func theProgressIsOneAtTheChaptersFoot() {
        var reported: [RunningHeadState] = []
        let page = F.Harness(width: 390, height: 700) { _ in }
        page.controller.headLineY = 40
        page.controller.onRunningHeadChange = { reported.append($0) }
        let links = F.links(previous: "Matthew 13", next: "Matthew 15")
        page.show(F.book(14...14, counts: [14: 60]), target: ScrollTarget(chapter: 14, verse: 1), footer: links.view)
        page.scroll(toY: page.maxOffsetY - 1)
        #expect((page.controller.runningHead?.progress ?? 1) < 1)
        page.scroll(toY: page.maxOffsetY)
        #expect(page.controller.runningHead == RunningHeadState(chapter: 14, progress: 1, headOpacity: 1))
        #expect(reported.last?.progress == 1)
    }

    /// The room above a later chapter grows with its chapter-note mark at large text sizes, so the
    /// mark sits inside the page; at the default size it is `laterChapterAir` (parked 2026-11-13:
    /// a fixed 16 pt while the mark grew).
    @Test func theRoomAboveALaterChapterGrowsWithItsMark() {
        let regular = UITraitCollection(preferredContentSizeCategory: .large)
        let largest = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        #expect(PhoneChapterTextController.laterChapterAir(for: regular) == PhoneChapterTextController.laterChapterAir)
        let big = ChapterNoteMarkButton.paperSize(for: largest).height
        #expect(big > ChapterNoteMarkButton.paperSize(for: regular).height)
        let air = PhoneChapterTextController.laterChapterAir(for: largest)
        #expect(air > PhoneChapterTextController.laterChapterAir)
        #expect(PhoneChapterTextController.verticalInset + air - AppSpacing.xs - big >= 0, "the mark is inside the page")
    }

    /// Matt, 2026-11-13 (superseding spec 4.2's "every chapter opens as chapter 1 does"): John 3
    /// shown alone has no label and none of the opening's old air ("the massive gap"). Under the
    /// page's inset it keeps only the room for its chapter-note mark (`laterChapterAir`), then
    /// its hairline with the first line of text at it (Lectern: the numeral beside it), so at
    /// rest at the top no line of it is under the bar, and the bar's title is shown there,
    /// naming it. A jump to verse 1 rests at that top. The title stays fully shown as the page
    /// scrolls and back at the top. The text runs under the bar, as in the app.
    @Test(arguments: PageStyle.allCases)
    func aLaterChapterOpensUnderTheBarWhoseTitleShowsFromTheTop(style: PageStyle) throws {
        let typography = ReaderTypography.styled(ReaderPreferences(style: style))
        let page = F.Harness(width: 390, height: 700) { _ in }
        let bar: CGFloat = 46
        page.textView.contentInset.top = bar
        page.controller.headLineY = bar
        let layout = JohnFixture.layout(3...3, style: style)
        page.show(layout, typography: typography, target: ScrollTarget(chapter: 3, verse: 20))
        page.show(layout, typography: typography, target: ScrollTarget(chapter: 3, verse: 1))
        let air = PhoneChapterTextController.laterChapterAir
        #expect(air == AppSpacing.md && air < BookLayout.openingAir(for: typography), "\(style): the gap is closed")
        let inset = page.textView.textContainerInset.top
        #expect(inset == PhoneChapterTextController.verticalInset + air, "\(style)")
        let top = -page.textView.adjustedContentInset.top
        #expect(page.textView.contentOffset.y == top, "\(style): the jump rests at the page's top")
        #expect(page.controller.runningHead?.chapter == 3 && page.controller.runningHead?.headOpacity == 1, "\(style): shown at rest")
        let section = layout.sections[0]
        #expect(layout.attributedString.readerRole(at: section.openingRange.location) == (style == .lectern ? .dropNumeral(3) : .chapterStart(3)))
        let opening = try #require(page.controller.lineFrame(forCharacterIndex: section.openingRange.location))
        let text = try #require(page.controller.lineFrame(forCharacterIndex: section.spans[0].textRange.location))
        let clear = bar + PhoneChapterTextController.verticalInset + air
        #expect(abs(opening.minY) < 0.5, "\(style): the hairline is the text's first line, right under the inset")
        #expect(opening.minY + inset - top >= clear - 0.5, "\(style): the opening at \(opening.minY + inset - top), the bar to \(bar)")
        #expect(opening.height <= 1.5 && abs(text.minY - opening.maxY) < 0.5, "\(style): the text starts at the hairline, no label and no air")
        #expect(text.minY + inset - top >= clear - 0.5, "\(style): the first line at \(text.minY + inset - top)")
        if style == .lectern {
            let numeral = try #require(page.controller.numeralView)
            #expect(numeral.chapter == 3 && numeral.frame.minY - top >= clear - 0.5, "\(style): the numeral at \(numeral.frame.minY - top), the text from \(clear)")
        } else {
            #expect(page.controller.numeralView == nil)
        }
        // The title never fades: a point down, the opening's end past the head's line, and well into the text.
        let band = try #require(page.controller.chapterBand)
        let fadeEnd = max(band.openingMaxY, PhoneChapterTextController.scrollLeadIn + RunningHead.headLineTolerance + RunningHead.minimumFade)
        for y in [top + 1, fadeEnd + 1 - bar - PhoneChapterTextController.scrollLeadIn, band.openingMaxY + 200] {
            page.scroll(toY: y)
            #expect(page.controller.runningHead?.headOpacity == 1 && page.controller.runningHead?.chapter == 3, "\(style) at \(y)")
        }
        page.scroll(toY: top)
        #expect(page.controller.runningHead?.headOpacity == 1, "\(style): still shown at the top")
    }

    /// Chapter 1's title block keeps its place at the page's top inset; only a later chapter
    /// takes air above its opening, and only the room for its chapter-note mark
    /// (`laterChapterAir`; it was the opening's 2.4 × the size until Matt, 2026-11-13). The foot
    /// keeps only the page's own inset (no footer).
    @Test func onlyALaterChapterTakesAirAboveItsOpening() {
        let page = F.Harness(width: 390, height: 700) { _ in }
        page.show(F.book(1...1), target: ScrollTarget(chapter: 1, verse: 1))
        #expect(page.textView.textContainerInset.top == PhoneChapterTextController.verticalInset)
        page.show(F.book(2...2), target: ScrollTarget(chapter: 2, verse: 1))
        #expect(page.textView.textContainerInset.top == PhoneChapterTextController.verticalInset + PhoneChapterTextController.laterChapterAir)
        #expect(PhoneChapterTextController.laterChapterAir == AppSpacing.md)
        #expect(PhoneChapterTextController.laterChapterAir < BookLayout.openingAir(for: .default))
        #expect(page.textView.textContainerInset.bottom == PhoneChapterTextController.verticalInset)
        page.show(F.book(1...1, book: "MRK"), target: ScrollTarget(chapter: 1, verse: 1))
        #expect(page.textView.textContainerInset.top == PhoneChapterTextController.verticalInset)
    }

    /// TextKit 2 drifted on whole-book documents: scrolled upward, lines above the viewport were
    /// laid out again at estimated heights and the page jumped. One chapter is laid out once and
    /// keeps every line, on the phone as on the Mac: Psalm 119 (176 verses) on a page the size of
    /// the iPhone 18 Pro Max's, Printed and Lectern. Three passes from the foot to the top in
    /// 30-point steps, each laid out and flushed, never move the text's end by more than 2 points;
    /// the head names Psalm 119 throughout, and the highlights and the numeral stay where they
    /// were drawn.
    @Test(arguments: [PageStyle.printed, .lectern])
    func oneChapterKeepsEveryLineThroughRepeatedUpwardScrolls(style: PageStyle) throws {
        let verses = try BenchmarkChapter.psalm119()
        let typography = ReaderTypography.styled(ReaderPreferences(style: style))
        let layout = BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: "PSA", chapter: 119), verses: verses)],
                                      opening: BookOpening(bookName: "Psalms", title: BookTitle(title: "Psalms", subtitle: nil)),
                                      typography: typography)
        let decorations = BenchmarkChapter.sixtyHighlights(in: layout.sections[0])
        let page = F.Harness(width: 440, height: 956) { _ in }
        page.textView.contentInset.top = 62
        page.controller.headLineY = 62
        let links = F.links(previous: "Psalm 118", next: "Psalm 120")
        page.show(layout, typography: typography, target: ScrollTarget(chapter: 119, verse: 1), decorations: decorations, footer: links.view)
        let layoutManager = try #require(page.textView.textLayoutManager)
        let end = layoutManager.usageBoundsForTextContainer.maxY
        let fills = page.controller.backgroundFills
        let numeral = page.controller.numeralView?.frame
        #expect(fills.filter { $0.id != nil }.count >= 60)
        #expect((numeral != nil) == (style == .lectern))
        let top = -page.textView.adjustedContentInset.top
        let maxY = page.maxOffsetY
        #expect(maxY > 5000)
        var drift: CGFloat = 0
        var chapters: Set<Int> = []
        for _ in 0..<3 {
            var y = maxY
            while true {
                page.scroll(toY: y)
                page.window.layoutIfNeeded()
                page.textView.layoutIfNeeded()
                CATransaction.flush()
                drift = max(drift, abs(layoutManager.usageBoundsForTextContainer.maxY - end))
                chapters.insert(page.controller.runningHead?.chapter ?? 0)
                if y <= top { break }
                y = max(top, y - 30)
            }
        }
        #expect(drift <= 2, "\(style): the text's end moved \(drift) points")
        #expect(chapters == [119], "\(style)")
        #expect(page.controller.backgroundFills == fills, "\(style)")
        #expect(page.controller.numeralView?.frame == numeral, "\(style)")
    }

    /// Decorations mapped onto another layout (the same chapter, its offsets moved by a heading
    /// that arrived on a retried fetch) are not applied; its own, when they come, are.
    @Test func decorationsForAnotherLayoutAreNotApplied() {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let small = F.book(3...3)
        let grown = F.book(3...3, headings: [3: [1: [SectionHeading(text: "A Heading", level: 1)]]])
        #expect(grown.id != small.id && grown.span(for: at(3, 2))!.textRange.location != small.span(for: at(3, 2))!.textRange.location)
        let item = MarkupItem(id: UUID(), chapter: 3, verse: 2, endVerse: 2, startOffset: 0, endOffset: 5,
                              translationID: "WEB", color: MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00"), hasNote: false)
        let onSmall = BookDecorations.build(itemsByChapter: [3: [item]], bookmarksByChapter: [:], outlinedID: nil,
                                            viewingTranslationID: "WEB", layout: small)
        page.show(small, target: ScrollTarget(chapter: 3, verse: 1), decorations: onSmall)
        #expect(!page.controller.backgroundFills.isEmpty)
        page.show(grown, target: ScrollTarget(chapter: 3, verse: 1), decorations: onSmall)
        #expect(page.controller.backgroundFills.isEmpty)
        let onGrown = BookDecorations.build(itemsByChapter: [3: [item]], bookmarksByChapter: [:], outlinedID: nil,
                                            viewingTranslationID: "WEB", layout: grown)
        page.show(grown, decorations: onGrown)
        let rect = page.controller.rect(for: NSRange(location: grown.span(for: at(3, 2))!.textRange.location, length: 5))
        #expect(page.controller.backgroundFills.first?.rect == rect)
    }

    /// A typography whose layout has not arrived yet (a size change: the typography comes a pass
    /// before the document's layout) waits for it, so the column is laid out once, at the new size.
    @Test func aTypographyWaitsForItsLayout() {
        let page = F.Harness(width: 1200, height: 700) { _ in }
        let layout = F.book(3...3)
        page.show(layout)
        let inset = page.textView.textContainerInset.left
        var prefs = ReaderPreferences.default
        prefs.fontSize = 26
        let large = ReaderTypography.styled(prefs)
        #expect(large.measure != ReaderTypography.default.measure)
        page.show(layout, typography: large)
        #expect(page.textView.textContainerInset.left == inset)
        page.show(F.book(3...3, typography: large), typography: large)
        #expect(page.textView.textContainerInset.left != inset)
    }

    /// The marks are controls: a tap on one reaches its button (not the text, not the pen) and
    /// reports its chapter, with the pen off and on.
    @Test func aTapOnAChapterNoteMarkReportsItsChapterWithThePenOffAndOn() throws {
        var shown: [Int] = []
        let page = F.Harness(width: 390, height: 700) { _ in }
        page.controller.onShowChapterNotes = { shown.append($0) }
        let layout = F.book(2...2, counts: [2: 6])
        page.show(layout, target: ScrollTarget(chapter: 2, verse: 1))
        page.controller.chapterNoteCounts = [2: 1]
        let mark = try #require(page.controller.chapterNoteMarkViews[2])
        let centre = CGPoint(x: mark.frame.midX, y: mark.frame.midY)
        for penOn in [false, true] {
            page.controller.setPen(isOn: penOn, color: .systemYellow, selectedID: nil)
            #expect(page.textView.hitTest(page.textView.convert(centre, to: page.textView), with: nil) === mark, "pen \(penOn)")
            #expect(!page.controller.isPaintable(centre), "pen \(penOn)")
            mark.sendActions(for: .primaryActionTriggered)
        }
        #expect(shown == [2, 2])
    }

    // MARK: The book thumb

    /// A point on the text's line `verse` of chapter 3, `x` points across the text view.
    private func line(_ page: F.Harness, layout: BookLayout, verse: Int, x: CGFloat) throws -> CGPoint {
        let span = try #require(layout.span(for: at(3, verse)))
        let rect = try #require(page.controller.rect(for: NSRange(location: span.textRange.location, length: 3)))
        return CGPoint(x: x, y: rect.midY)
    }

    /// The thumb's press, as its recogniser hands it over: each state at `point` (text-view
    /// coordinates) for a touch that started at `start` (`point` itself unless given), reported
    /// only if the recogniser would have taken the touch at all.
    private func press(_ page: F.Harness, at point: CGPoint, from start: CGPoint? = nil, _ states: [UIGestureRecognizer.State]) {
        let start = start ?? point
        guard page.controller.thumbReceivesTouch(at: start) else { return }
        for state in states { page.controller.thumbPressed(state, at: point, touchStartedAt: start) }
    }

    /// Spec 4.4: a long press in the right edge zone opens the thumb, and with the pen on it is
    /// the thumb's alone: at 10 points from the right edge, beside a line the pen could paint
    /// from, the press reports `.began` (and the rest of its course, its height in the page's
    /// coordinates), while the paint gesture neither begins there nor wins over the thumb.
    @Test func theEdgeLongPressOpensTheThumbNotThePen() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let layout = F.book(3...3, counts: [3: 12])
        page.show(layout, target: ScrollTarget(chapter: 3, verse: 1))
        page.controller.setPen(isOn: true, color: .systemYellow, selectedID: nil)
        var events: [ThumbGesture] = []
        page.controller.onThumb = { events.append($0) }
        #expect(PhoneChapterTextController.thumbEdgeZone == 28)
        #expect(PhoneChapterTextController.thumbHold == 0.3)

        let edge = try line(page, layout: layout, verse: 4, x: page.textView.bounds.width - 10)
        #expect(page.controller.isPaintable(edge), "a stroke could start from this line")
        #expect(!page.controller.paintMayBegin(touchStartedAt: edge, at: edge), "but not in the edge zone")
        #expect(page.controller.paintRequiresThumbToFail(touchStartedAt: edge))
        press(page, at: edge, [.began, .changed, .ended])
        let y = page.textView.convert(edge, to: page.controller.pageView).y
        #expect(events == [.began(y: y), .moved(y: y), .ended(y: y)])

        // A stroke begun in the text is the pen's, even should it run on into the zone.
        let text = try line(page, layout: layout, verse: 4, x: page.textView.bounds.midX)
        #expect(page.controller.paintMayBegin(touchStartedAt: text, at: text))
        #expect(!page.controller.paintRequiresThumbToFail(touchStartedAt: text))
        #expect(!page.controller.thumbReceivesTouch(at: text))

        // Cancelled (a call, the app leaving): the thumb hears of it.
        events = []
        press(page, at: edge, [.began, .cancelled])
        #expect(events == [.began(y: y), .cancelled])
    }

    /// A tap on a margin mark at the right edge still acts on the mark, the pen on and off: the
    /// mark is the view hit there, in the edge zone, and the thumb's press begins only after its
    /// hold, so a tap ends before it and the mark's action runs.
    @Test func aTapOnAMarginMarkStillActsOnTheMark() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let layout = F.book(3...3, counts: [3: 8])
        let marks = MarginMark.build(notesByChapter: [:], itemsByChapter: [:], bookmarksByChapter: [3: [5]], layout: layout)
        page.show(layout, target: ScrollTarget(chapter: 3, verse: 1), marks: marks)
        var tapped: [MarginMark] = []
        page.controller.onMarginMarkTap = { tapped.append($0) }
        var events: [ThumbGesture] = []
        page.controller.onThumb = { events.append($0) }
        let bookmark = try #require(page.controller.markButtons.first)
        let centre = CGPoint(x: bookmark.frame.midX, y: bookmark.frame.midY)
        #expect(centre.x >= page.textView.bounds.width - PhoneChapterTextController.thumbEdgeZone, "the mark is in the edge zone")
        for penOn in [false, true] {
            page.controller.setPen(isOn: penOn, color: .systemYellow, selectedID: nil)
            #expect(page.textView.hitTest(centre, with: nil) === bookmark, "pen \(penOn)")
            #expect(page.controller.thumbReceivesTouch(at: centre), "pen \(penOn)")
            // A tap: the press never reaches its hold, so it fails, and the mark acts.
            press(page, at: centre, [.failed])
            bookmark.sendActions(for: .primaryActionTriggered)
        }
        #expect(page.controller.thumbPressDuration == PhoneChapterTextController.thumbHold)
        #expect(events.isEmpty)
        #expect(tapped == marks + marks)
    }

    /// A long press in the column, away from the edge, is the text's (or the pen's): the thumb's
    /// recogniser never takes the touch, and a press there reports nothing.
    @Test func aPressInsideTheTextNeverOpensTheThumb() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let layout = F.book(3...3, counts: [3: 12])
        page.show(layout, target: ScrollTarget(chapter: 3, verse: 1))
        var events: [ThumbGesture] = []
        page.controller.onThumb = { events.append($0) }
        for penOn in [false, true] {
            page.controller.setPen(isOn: penOn, color: .systemYellow, selectedID: nil)
            let centre = try line(page, layout: layout, verse: 4, x: page.textView.bounds.midX)
            #expect(!page.controller.thumbReceivesTouch(at: centre), "pen \(penOn)")
            // Handed a press there regardless, it still reports nothing.
            for state in [UIGestureRecognizer.State.began, .changed, .ended] {
                page.controller.thumbPressed(state, at: centre, touchStartedAt: centre)
            }
            // Nor does one that began there and drifted into the zone.
            let edge = CGPoint(x: page.textView.bounds.width - 10, y: centre.y)
            page.controller.thumbPressed(.began, at: edge, touchStartedAt: centre)
            // Just outside the zone is the text's too.
            let inside = CGPoint(x: page.textView.bounds.width - PhoneChapterTextController.thumbEdgeZone - 1, y: centre.y)
            #expect(!page.controller.thumbReceivesTouch(at: inside), "pen \(penOn)")
        }
        #expect(events.isEmpty)
    }

    /// Review: a touch that starts in the zone and drifts a few points out of it before the hold
    /// (within the press's allowance) still opens the thumb; the press goes by where the touch
    /// started, not where the hold engaged, so it never begins without reporting.
    @Test func aPressThatDriftsOutOfTheZoneDuringTheHoldStillOpensTheThumb() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let layout = F.book(3...3, counts: [3: 12])
        page.show(layout, target: ScrollTarget(chapter: 3, verse: 1))
        var events: [ThumbGesture] = []
        page.controller.onThumb = { events.append($0) }
        let width = page.textView.bounds.width
        let start = try line(page, layout: layout, verse: 4, x: width - 27)
        let drifted = CGPoint(x: width - 33, y: start.y + 4)
        #expect(!page.controller.isInThumbZone(drifted), "the hold engages outside the zone")
        press(page, at: drifted, from: start, [.began, .ended])
        let y = page.textView.convert(drifted, to: page.controller.pageView).y
        #expect(events == [.began(y: y), .ended(y: y)])
    }

    /// Review: the away tap runs alongside everything, so a press held for the thumb and let go
    /// within a tap's limits would also be a tap away (with the pen on, deselecting its mark).
    /// Once the thumb's press has begun the away tap may not act on that touch, through its end;
    /// the next touch is free again.
    @Test func theAwayTapDoesNotActOnTheThumbsPress() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let layout = F.book(3...3, counts: [3: 12])
        page.show(layout, target: ScrollTarget(chapter: 3, verse: 1))
        page.controller.setPen(isOn: true, color: .systemYellow, selectedID: nil)
        let edge = try line(page, layout: layout, verse: 4, x: page.textView.bounds.width - 10)
        page.controller.awayTapTouchBegan()
        #expect(page.controller.awayTapMayAct)
        press(page, at: edge, [.began])
        #expect(!page.controller.awayTapMayAct, "while the thumb is held")
        press(page, at: edge, [.ended])
        #expect(!page.controller.awayTapMayAct, "on its lift")
        page.controller.awayTapTouchBegan()
        #expect(page.controller.awayTapMayAct, "the next touch")
        // A press that never reached its hold (a tap) leaves the away tap free.
        press(page, at: edge, [.failed])
        #expect(page.controller.awayTapMayAct)
    }

    /// Review: in the edge zone the thumb wins over the text view's own long press, loupe,
    /// selection and taps by rule, not by timing: for a touch that started in the zone each of
    /// the text view's own recognisers waits for the thumb's press to fail; outside it, or for a
    /// touch the press did not take, none does. The scroll's pan and the controller's own
    /// recognisers never wait on it.
    @Test func theTextViewsOwnGesturesWaitForTheThumbInTheZone() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let layout = F.book(3...3, counts: [3: 12])
        page.show(layout, target: ScrollTarget(chapter: 3, verse: 1))
        let controller = page.controller
        let own = (page.textView.gestureRecognizers ?? []).filter { recogniser in
            recogniser !== page.textView.panGestureRecognizer && !controller.ownGestures.contains { $0 === recogniser }
        }
        #expect(own.contains { $0 is UILongPressGestureRecognizer }, "the selectable text view has its own long press")
        let edge = try line(page, layout: layout, verse: 4, x: page.textView.bounds.width - 10)
        let text = try line(page, layout: layout, verse: 4, x: page.textView.bounds.midX)
        for recogniser in own {
            #expect(controller.textViewGestureWaitsForThumb(recogniser, touchStartedAt: edge), "\(type(of: recogniser))")
            #expect(!controller.textViewGestureWaitsForThumb(recogniser, touchStartedAt: text), "\(type(of: recogniser))")
            #expect(!controller.textViewGestureWaitsForThumb(recogniser, touchStartedAt: nil), "\(type(of: recogniser))")
        }
        #expect(!controller.textViewGestureWaitsForThumb(page.textView.panGestureRecognizer, touchStartedAt: edge))
        for recogniser in controller.ownGestures {
            #expect(!controller.textViewGestureWaitsForThumb(recogniser, touchStartedAt: edge))
        }
        #expect(!controller.textViewGestureWaitsForThumb(UILongPressGestureRecognizer(), touchStartedAt: edge), "on another view")
    }

    /// The screen's side of the press (`PhoneThumbScrub`), on Psalms' track 600 points tall and
    /// 100 points down the page, Psalm 73 open: the press's height chooses the chapter on the
    /// track, the grab and each chapter passed are felt (the same chapter is not), letting go on
    /// another chapter lands there, letting go on the one being read lands nowhere, and a cancel
    /// hides.
    @Test func theThumbsPressChoosesAndLandsOnAChapter() {
        let psalms = BookThumb(chapters: Array(1...150), current: 73)
        let track = CGRect(x: 360, y: 100, width: 16, height: 600)
        func y(_ chapter: Int) -> CGFloat { track.minY + BookThumbView.tickY(for: chapter, inTrackHeight: track.height, thumb: psalms) }
        typealias Scrub = PhoneThumbScrub
        typealias Press = PhoneThumbScrub.Press
        #expect(Scrub.step(.began(y: y(73)), dragging: nil, press: nil, thumb: psalms, track: track)
            == .init(dragging: 73, press: Press(start: 73), haptic: .grabbed, landing: nil))
        #expect(Scrub.step(.moved(y: y(74)), dragging: 73, press: Press(start: 73), thumb: psalms, track: track)
            == .init(dragging: 74, press: Press(start: 73, hasLeftStart: true), haptic: .chapterPassed, landing: nil))
        #expect(Scrub.step(.moved(y: y(74) + 0.5), dragging: 74, press: Press(start: 73, hasLeftStart: true), thumb: psalms, track: track)
            == .init(dragging: 74, press: Press(start: 73, hasLeftStart: true), haptic: nil, landing: nil))
        #expect(Scrub.step(.ended(y: y(76)), dragging: 76, press: Press(start: 73, hasLeftStart: true), thumb: psalms, track: track)
            == .init(dragging: nil, press: nil, haptic: nil, landing: 76))
        #expect(Scrub.step(.ended(y: y(73)), dragging: 73, press: Press(start: 90, hasLeftStart: true), thumb: psalms, track: track)
            == .init(dragging: nil, press: nil, haptic: nil, landing: nil), "letting go on the chapter being read")
        #expect(Scrub.step(.cancelled, dragging: 90, press: Press(start: 80, hasLeftStart: true), thumb: psalms, track: track)
            == .init(dragging: nil, press: nil, haptic: nil, landing: nil))
        // Above and below the track: its ends.
        #expect(Scrub.step(.moved(y: 20), dragging: 2, press: Press(start: 2), thumb: psalms, track: track).dragging == 1)
        #expect(Scrub.step(.moved(y: 800), dragging: 149, press: Press(start: 149), thumb: psalms, track: track).dragging == 150)
        // A track not laid out yet lands nowhere.
        #expect(Scrub.step(.ended(y: 300), dragging: nil, press: nil, thumb: psalms, track: .zero).landing == nil)
    }

    /// Runs `gestures` through the scrub from rest, as the screen does, and returns where the
    /// press lands, if anywhere.
    private func scrub(_ gestures: [ThumbGesture], thumb: BookThumb, track: CGRect) -> Int? {
        var dragging: Int?
        var press: PhoneThumbScrub.Press?
        var landing: Int?
        for gesture in gestures {
            let step = PhoneThumbScrub.step(gesture, dragging: dragging, press: press, thumb: thumb, track: track)
            dragging = step.dragging
            press = step.press
            landing = step.landing ?? landing
        }
        return landing
    }

    /// Final review I2: the press begins wherever the finger rests on the edge, so the chapter
    /// under it is no choice. A press held still and lifted lands nowhere, even far from the
    /// chapter being read; so does one that wobbles within its chapter. Dragged to another
    /// chapter and let go, it lands there.
    @Test func aPressThatNeverLeavesItsChapterLandsNowhere() {
        let psalms = BookThumb(chapters: Array(1...150), current: 73)
        let track = CGRect(x: 360, y: 100, width: 16, height: 600)
        func y(_ chapter: Int) -> CGFloat { track.minY + BookThumbView.tickY(for: chapter, inTrackHeight: track.height, thumb: psalms) }
        #expect(PhoneChapterTextController.thumbHold == 0.3)
        // Held still on Psalm 120 and lifted.
        #expect(scrub([.began(y: y(120)), .ended(y: y(120))], thumb: psalms, track: track) == nil)
        // A wobble within Psalm 120.
        #expect(scrub([.began(y: y(120)), .moved(y: y(120) + 0.5), .moved(y: y(120) - 0.5), .ended(y: y(120))],
                      thumb: psalms, track: track) == nil)
        // Dragged on to Psalm 122 and let go there.
        #expect(scrub([.began(y: y(120)), .moved(y: y(121)), .moved(y: y(122)), .ended(y: y(122))],
                      thumb: psalms, track: track) == 122)
        // Dragged to the chapter being read: nowhere, as ever.
        #expect(scrub([.began(y: y(120)), .moved(y: y(73)), .ended(y: y(73))], thumb: psalms, track: track) == nil)
    }

    /// Matt, 2026-11-13: dragging the thumb quickly, the taps "start off ok then just stop
    /// altogether": asked for them faster than it will give them, the system gives none. A
    /// chapter passed within a twentieth of a second of the last tap goes untapped, so a fast
    /// drag through Psalms still taps, steadily, to its end.
    @Test func aFastDragKeepsItsTaps() {
        #expect(ThumbHaptics.shortestGap == 0.05)
        let haptics = ThumbHaptics()
        var now: CFTimeInterval = 100
        haptics.clock = { now }
        // 150 chapters in half a second: one every 3.3 ms.
        for _ in 0..<150 {
            haptics.play(.chapterPassed)
            now += 0.5 / 150
        }
        #expect((9...11).contains(haptics.detentsPlayed), "about twenty a second: \(haptics.detentsPlayed)")
        // A slow drag taps for every chapter.
        let before = haptics.detentsPlayed
        for _ in 0..<5 {
            now += 0.2
            haptics.play(.chapterPassed)
        }
        #expect(haptics.detentsPlayed == before + 5)
    }

    /// The handover's back-to-start case: a press that has been on another chapter is choosing,
    /// so coming back to the chapter it began on and letting go lands there; unless that is the
    /// chapter being read.
    @Test func aPressThatComesBackToItsStartLandsThere() {
        let psalms = BookThumb(chapters: Array(1...150), current: 73)
        let track = CGRect(x: 360, y: 100, width: 16, height: 600)
        func y(_ chapter: Int) -> CGFloat { track.minY + BookThumbView.tickY(for: chapter, inTrackHeight: track.height, thumb: psalms) }
        // Away to Psalm 121 and back to 120.
        #expect(scrub([.began(y: y(120)), .moved(y: y(121)), .moved(y: y(120)), .ended(y: y(120))],
                      thumb: psalms, track: track) == 120)
        // The lift itself is what comes back: the last move was on Psalm 121.
        #expect(scrub([.began(y: y(120)), .moved(y: y(121)), .ended(y: y(120))], thumb: psalms, track: track) == 120)
        // Began on the chapter being read, away and back: nowhere.
        #expect(scrub([.began(y: y(73)), .moved(y: y(80)), .moved(y: y(73)), .ended(y: y(73))],
                      thumb: psalms, track: track) == nil)
    }

    /// Final review M5: in landscape the text view runs under the sensor housing, and the thumb's
    /// track (an overlay that keeps to the safe area) is drawn inside it. The press's zone is
    /// measured from the same edge: with a 59-point right inset it is the 28 points inside it
    /// (and the inset beyond), not the 28 points at the screen's edge.
    @Test func theThumbsZoneKeepsToTheSafeArea() {
        let controller = PhoneChapterTextController()
        let window = TestWindow.make(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        let host = UIViewController()
        host.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59)
        window.rootViewController = host
        window.isHidden = false
        controller.pageView.frame = host.view.bounds
        host.view.addSubview(controller.pageView)
        window.layoutIfNeeded()
        defer { window.isHidden = true }
        let textView = controller.textView
        #expect(textView.bounds.width == 874)
        #expect(textView.safeAreaInsets.right == 59)
        let edge = textView.bounds.width - 59
        #expect(controller.isInThumbZone(CGPoint(x: edge - 10, y: 100)), "beside the track")
        #expect(controller.isInThumbZone(CGPoint(x: edge - 27, y: 100)))
        #expect(!controller.isInThumbZone(CGPoint(x: edge - 29, y: 100)), "in the column")
        #expect(controller.isInThumbZone(CGPoint(x: edge + 20, y: 100)), "under the housing, beyond the track")
        #expect(controller.thumbReceivesTouch(at: CGPoint(x: edge - 10, y: 100)))
        // Without an inset the zone is at the screen's edge, as in portrait.
        host.additionalSafeAreaInsets = .zero
        window.layoutIfNeeded()
        #expect(textView.safeAreaInsets.right == 0)
        #expect(!controller.isInThumbZone(CGPoint(x: edge - 10, y: 100)))
        #expect(controller.isInThumbZone(CGPoint(x: textView.bounds.width - 10, y: 100)))
    }

    /// The thumb takes the system scroll indicator's place at the right edge (spec 4.4): its
    /// long press would otherwise scrub the chapter under the same finger. The head's progress
    /// line still shows the place in the chapter.
    @Test func theSystemScrollIndicatorIsHidden() {
        let page = F.Harness(width: 390, height: 700) { _ in }
        page.show(F.book(3...3, counts: [3: 40]), target: ScrollTarget(chapter: 3, verse: 1))
        #expect(!page.textView.showsVerticalScrollIndicator)
    }

    // MARK: Lectern's drop numeral

    private static let lectern = ReaderTypography.styled(ReaderPreferences(style: .lectern))

    /// The line frames of `count` paragraphs from the one holding `index`, in text-container coordinates.
    private func paragraphLines(_ page: F.Harness, at index: Int, count: Int = 1) -> [[CGRect]] {
        let layoutManager = page.textView.textLayoutManager!
        let storage = layoutManager.textContentManager as! NSTextContentStorage
        guard let location = storage.location(storage.documentRange.location, offsetBy: index) else { return [] }
        var result: [[CGRect]] = []
        layoutManager.enumerateTextLayoutFragments(from: location, options: [.ensuresLayout]) { fragment in
            result.append(fragment.textLineFragments.map {
                $0.typographicBounds.offsetBy(dx: fragment.layoutFragmentFrame.minX, dy: fragment.layoutFragmentFrame.minY)
            })
            return result.count < count
        }
        return result
    }

    /// Lectern's chapters open on a hairline just above their text (DESIGN.md, Page Styles; R16
    /// superseded 2026-11-12): the chapter-note mark sits in the air above it at the column's
    /// trailing edge, above the bookmark on verse 1's line, its touch area clear of the text.
    /// (Since Matt, 2026-11-13 every style's later chapter does the same:
    /// `aLaterChaptersNoteMarkSitsAboveItsOpeningAndScrollsWithThePage`.)
    @Test func aLecternChaptersMarkSitsAboveItsOpening() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let layout = F.book(3...3, counts: [3: 6], typography: Self.lectern)
        let section = try #require(layout.section(for: 3))
        #expect(layout.attributedString.readerRole(at: section.openingRange.location) == .dropNumeral(3))
        let marks = MarginMark.build(notesByChapter: [:], itemsByChapter: [:], bookmarksByChapter: [3: [1]], layout: layout)
        page.show(layout, typography: Self.lectern, marks: marks)
        page.controller.chapterNoteCounts = [3: 2]
        let mark = try #require(page.controller.chapterNoteMarkViews[3])
        let bookmark = try #require(page.controller.markButtons.first)
        let inset = page.textView.textContainerInset
        let columnRight = page.textView.bounds.width - inset.right
        let text = try #require(page.controller.lineFrame(forCharacterIndex: section.spans[0].textRange.location))
        #expect(!mark.isHidden && !bookmark.isHidden)
        #expect(abs(mark.frame.maxX - columnRight) < 1)
        #expect(mark.frame.maxY <= text.minY + inset.top - AppSpacing.xs + 1, "in the air above the chapter's text")
        #expect(mark.frame.maxY <= bookmark.frame.minY, "the bookmark keeps verse 1's line, below")
        let area = mark.convert(mark.hitArea, to: page.textView)
        #expect(area.maxY <= text.minY + inset.top + 0.5 && area.maxX <= page.textView.bounds.width + 0.5, "clear of the text")
        #expect(area.height >= MarginMarkButton.minimumHitSize - 0.5)
    }

    /// As on the Mac: John 3's first three lines start right of the numeral's notch, the rest at
    /// the column's edge, every line at the body's height; the numeral is a view of its own flush
    /// with the column's edge beside them, which VoiceOver reads as "Chapter 3".
    @Test func lecternTextWrapsAroundTheNumeral() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let layout = JohnFixture.layout(3...3, style: .lectern)
        page.show(layout, typography: Self.lectern, target: ScrollTarget(chapter: 3, verse: 1))
        let section = try #require(layout.section(for: 3))
        let notch = DropNumeral.notch(3, typography: Self.lectern)
        let paragraphs = paragraphLines(page, at: section.spans[0].textRange.location, count: 2)
        let lines = paragraphs.flatMap { $0 }
        #expect(lines.count >= 5)
        #expect(lines.prefix(3).allSatisfy { abs($0.minX - notch.width) < 0.5 }, "\(lines.prefix(4))")
        #expect(paragraphs[0].dropFirst(3).allSatisfy { $0.minX == 0 }, "\(paragraphs[0])")
        #expect(lines.allSatisfy { abs($0.height - lines[0].height) < 0.5 }, "every line keeps the body's height")
        let view = try #require(page.controller.numeralView)
        #expect(view.chapter == 3)
        let inset = page.textView.textContainerInset
        #expect(abs(view.frame.minX - (inset.left - 2)) < 1.5, "flush with the column's edge")
        #expect(view.frame.maxX <= inset.left + notch.width)
        #expect(view.frame.minY < lines[0].maxY + inset.top && view.frame.maxY > lines[2].minY + inset.top, "beside the first three lines")
        #expect(!view.isUserInteractionEnabled)
        #expect(view.isAccessibilityElement && view.accessibilityLabel == "Chapter 3")
        let elements = page.controller.pageView.accessibilityElements ?? []
        #expect(elements.contains { ($0 as AnyObject) === view })
        page.show(JohnFixture.layout(3...3), typography: .default)
        #expect(page.controller.numeralView == nil)
        #expect(page.textView.textLayoutManager?.delegate == nil)
    }

    /// A highlight on John 3:1's first words is painted right of the numeral and clear of it, and
    /// a selection from the opening through verse 2 copies only the verses' words, no strut.
    @Test func aHighlightOnVerseOneIsPaintedBesideTheNumeral() throws {
        let page = F.Harness(width: 390, height: 700) { _ in }
        let pasteboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        page.controller.pasteboard = pasteboard
        let layout = JohnFixture.layout(3...3, style: .lectern)
        let section = try #require(layout.section(for: 3))
        let text = section.spans[0].textRange
        let id = UUID()
        let highlight = RangeDecoration(id: id, range: NSRange(location: text.location, length: 9),
                                        style: .background(MarkupColor(lightHex: "#F8E18A", darkHex: "#554704")))
        page.show(layout, typography: Self.lectern, target: ScrollTarget(chapter: 3, verse: 1),
                  decorations: BookDecorations(highlights: [highlight], bookmarks: [], outlinedID: nil))
        let fills = page.controller.backgroundFills.filter { $0.id == id }
        #expect(fills.count == 1)
        let fill = try #require(fills.first)
        let notch = DropNumeral.notch(3, typography: Self.lectern)
        #expect(abs(fill.rect.minX - (page.textView.textContainerInset.left + notch.width)) < 0.5, "right of the notch")
        #expect(!fill.rect.intersects(try #require(page.controller.numeralView).frame.insetBy(dx: 2, dy: 2)))

        let two = section.spans[1]
        page.textView.selectedRange = NSRange(location: section.openingRange.location, length: NSMaxRange(two.textRange) - section.openingRange.location)
        page.textView.copy(nil)
        #expect(pasteboard.string == JohnFixture.text(3, 1) + " " + JohnFixture.text(3, 2))
    }

    /// A narrower page reflows the column: the first three lines still wrap around the numeral,
    /// which moves with its paragraph; another translation's text of the same chapter keeps both.
    @Test func resizingKeepsTheWrapAndTheNumeral() throws {
        let page = F.Harness(width: 430, height: 700) { _ in }
        page.show(JohnFixture.layout(3...3, style: .lectern), typography: Self.lectern, target: ScrollTarget(chapter: 3, verse: 1))
        let notch = DropNumeral.notch(3, typography: Self.lectern)
        func expectWrap(_ label: String) throws {
            let section = try #require(page.controller.layout?.section(for: 3))
            let lines = try #require(paragraphLines(page, at: section.spans[0].textRange.location).first)
            #expect(lines.count >= 4, "\(label)")
            #expect(lines.prefix(3).allSatisfy { abs($0.minX - notch.width) < 0.5 }, "\(label): \(lines)")
            #expect(lines.dropFirst(3).allSatisfy { $0.minX == 0 }, "\(label)")
            let view = try #require(page.controller.numeralView)
            #expect(abs(view.frame.minY - (lines[0].minY + page.textView.textContainerInset.top)) < lines[0].height, "\(label): beside its first line")
        }
        try expectWrap("wide")
        page.controller.pageView.frame.size.width = 320
        page.controller.pageView.layoutIfNeeded()
        page.textView.layoutIfNeeded()
        #expect(page.textView.bounds.width == 320)
        try expectWrap("narrow")
        page.show(BookLayout.build(chapters: JohnFixture.inputs(3...3, translation: "KJV"), opening: JohnFixture.opening,
                                   typography: Self.lectern), typography: Self.lectern)
        try expectWrap("another translation")
    }

    /// The rendering attributes behind the chapter-1 label's fade and the on-mark verse numbers
    /// stay in place once the text view has been told to redraw them.
    @Test func renderingAttributesSurviveTheirRedraw() throws {
        var prefs = ReaderPreferences.default
        prefs.style = .study
        let typography = ReaderTypography.styled(prefs)
        let page = F.Harness(width: 390, height: 700) { _ in }
        page.controller.headLineY = 46
        let layout = F.book(1...1, counts: [1: 30], typography: typography)
        let item = MarkupItem(id: UUID(), chapter: 1, verse: 2, endVerse: 3, startOffset: 0, endOffset: 5, translationID: "WEB",
                              color: MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00"), hasNote: false)
        let decorations = BookDecorations.build(itemsByChapter: [1: [item]], bookmarksByChapter: [:], outlinedID: nil,
                                                viewingTranslationID: "WEB", layout: layout)
        page.show(layout, typography: typography, decorations: decorations)
        let number = try #require(layout.span(for: at(1, 3))).numberRange
        #expect(number.length > 0)
        #expect(renderingColor(page, at: number.location) != nil, "the on-mark number color")

        let labelIndex = try #require((layout.sections[0].openingRange.location..<NSMaxRange(layout.sections[0].openingRange))
            .first { layout.attributedString.readerRole(at: $0) == .chapterLabel(1) })
        page.scrollHeadLine(to: try #require(page.controller.chapterBand).openingMaxY - RunningHead.fadeDistance / 2)
        let faded = try #require(renderingColor(page, at: labelIndex))
        #expect(abs(faded.resolvedColor(with: page.textView.traitCollection).cgColor.alpha - page.controller.openingLabelAlpha) < 0.02)
        page.scroll(toY: -page.textView.adjustedContentInset.top)
        #expect(renderingColor(page, at: labelIndex) == nil, "full alpha removes it")
    }

    /// The foreground color TextKit holds as a rendering attribute at `index`.
    private func renderingColor(_ page: F.Harness, at index: Int) -> UIColor? {
        guard let layoutManager = page.textView.textLayoutManager,
              let storage = layoutManager.textContentManager as? NSTextContentStorage else { return nil }
        var found: UIColor?
        layoutManager.enumerateRenderingAttributes(from: layoutManager.documentRange.location, reverse: false) { _, attributes, range in
            let start = storage.offset(from: storage.documentRange.location, to: range.location)
            let end = storage.offset(from: storage.documentRange.location, to: range.endLocation)
            if index >= start && index < end { found = attributes[.foregroundColor] as? UIColor; return false }
            return start <= index
        }
        return found
    }

    /// A jump to the verse at the top (a return to the Read tab) is already met: the page stays
    /// where it is, part-way into the verse.
    @Test func aJumpToTheVerseAtTheTopKeepsThePage() throws {
        var reported: [VerseLocation] = []
        let page = F.Harness(width: 390, height: 700) { reported.append($0) }
        page.controller.headLineY = 40
        let layout = F.book(3...3)
        page.show(layout, target: ScrollTarget(chapter: 3, verse: 10))
        page.scroll(toY: page.textView.contentOffset.y + 3)
        let partRead = page.textView.contentOffset.y
        #expect(reported.last == at(3, 10))
        page.show(layout, target: ScrollTarget(chapter: 3, verse: 10))
        #expect(page.textView.contentOffset.y == partRead)
    }

    /// The spec's budget (section 6, item 4) on the phone: Psalm 119 in ESV at 18 pt with sixty
    /// highlights appears within a second, on a page the size of the iPhone 18 Pro Max's. On the
    /// real bundle (skipped without `Build/bible.sqlite`): the store's fetch, the document's build
    /// of the chapter, and the controller laying it out and landing on Psalm 119 with its
    /// highlights painted, every fragment still laid out. Printed in ms.
    @Test(.needsRealBible) func psalm119OpensWithSixtyHighlightsWithinASecond() throws {
        let store = try BenchmarkChapter.realStore()
        let clock = ContinuousClock()
        let start = clock.now
        let book = BookText(book: "PSA", translationID: "ESV", chapters: try store.bookChapters("PSA", translationID: "ESV"))
        let fetch = clock.now - start
        let document = ReaderDocument(store: store)
        let build = clock.measure {
            document.show(book, target: ChapterLocation(book: "PSA", chapter: 119), typography: .default)
        }
        let layout = try #require(document.layout)
        #expect(layout.chapters == 119...119)
        let decorations = BenchmarkChapter.sixtyHighlights(in: try #require(layout.section(for: 119)))
        #expect(decorations.highlights.count >= 60)
        var reported: [VerseLocation] = []
        let page = F.Harness(width: 440, height: 956) { reported.append($0) }
        let load = clock.measure {
            page.show(layout, target: ScrollTarget(chapter: 119, verse: 1), decorations: decorations)
        }
        func ms(_ duration: Duration) -> String {
            String(format: "%.1f", Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15)
        }
        print("benchmark phone-psalm-119 \(layout.chapters) fetch \(ms(fetch)) ms, build \(ms(build)) ms, load-at-119 \(ms(load)) ms, total \(ms(fetch + build + load)) ms")
        #expect(fetch + build + load < .seconds(1))
        page.textView.layoutIfNeeded()
        #expect(reported == [at(119, 1, book: "PSA")])
        #expect(page.controller.runningHead?.chapter == 119)
        #expect(page.controller.backgroundFills.filter { $0.id != nil }.count >= 60)
        #expect(discardedFragments(page) == 0)
    }

    /// The fragments the text view has dropped the layout of (it does past about 2,000).
    private func discardedFragments(_ page: F.Harness) -> Int {
        guard let layoutManager = page.textView.textLayoutManager else { return -1 }
        var discarded = 0
        layoutManager.enumerateTextLayoutFragments(from: layoutManager.documentRange.location, options: []) { fragment in
            if fragment.state != .layoutAvailable { discarded += 1 }
            return true
        }
        return discarded
    }

    /// R13: a jump lands on its chapter in the tall books (Psalms, Isaiah,
    /// Jeremiah, all poetry) as in the prose ones that always fitted (Genesis, John, Romans), the
    /// head naming it and the text view keeping every fragment laid out.
    @Test(.needsRealBible, arguments: [("PSA", 119), ("PSA", 23), ("PSA", 150), ("ISA", 66), ("ISA", 40), ("JER", 52),
                      ("GEN", 50), ("JHN", 21), ("JHN", 3), ("ROM", 16)])
    func aJumpLandsOnItsChapterInEveryBook(code: String, chapter: Int) throws {
        let store = try BenchmarkChapter.realStore()
        let book = BookText(book: code, translationID: "ESV", chapters: try store.bookChapters(code, translationID: "ESV"))
        let document = ReaderDocument(store: store)
        document.show(book, target: ChapterLocation(book: code, chapter: chapter), typography: .default)
        let layout = try #require(document.layout)
        var reported: [VerseLocation] = []
        let page = F.Harness(width: 440, height: 956) { reported.append($0) }
        page.show(layout, target: ScrollTarget(chapter: chapter, verse: 1))
        page.textView.layoutIfNeeded()
        #expect(reported == [at(chapter, 1, book: code)], "\(code) \(chapter) in \(layout.chapters)")
        #expect(page.controller.runningHead?.chapter == chapter)
        #expect(discardedFragments(page) == 0)
    }

    // MARK: The chapter switcher

    /// The switcher's cards for the controller's mechanics: a view of a fixed height.
    private final class Cards: UIView {
        override func sizeThatFits(_ size: CGSize) -> CGSize { CGSize(width: size.width, height: 112) }
    }

    /// A long chapter 2 of a five-chapter book on a page in a window (Reduce Motion on, so the
    /// page is at its rest at once), with a switcher whose landings are collected.
    @MainActor private final class SwitcherPage {
        let page: F.Harness
        let model = ChapterSwitcherModel()
        let cards = Cards()
        var landings: [[Int]] = []
        /// The books landed in, for a neighbouring book's card.
        var booksLanded: [String?] = []

        init(atEnd: Bool, chapters: [Int] = Array(1...5), current: Int = 2,
             previous: ChapterSwitcher.BookEnd? = nil, next: ChapterSwitcher.BookEnd? = nil) {
            page = F.Harness(width: 390, height: 700) { _ in }
            page.controller.reducesMotion = { true }
            model.show(book: "TST", chapters: chapters, current: current, previous: previous, next: next)
            model.onLand = { [unowned self] book, chapter, atEnd in
                landings.append([chapter, atEnd ? 1 : 0])
                booksLanded.append(book)
            }
            page.controller.switcher = model
            page.controller.setSwitcherView(cards)
            page.show(F.book(2...2, counts: [2: 60]), target: ScrollTarget(chapter: 2, verse: 1, atEnd: atEnd))
        }

        var controller: PhoneChapterTextController { page.controller }
        var text: UITextView { page.textView }
        var foot: CGFloat { controller.pageEnds.upperBound }
        var top: CGFloat { controller.pageEnds.lowerBound }

        /// Drags from where the page is through `ys` and lifts at the last, at `velocity` points
        /// per second.
        func pull(through ys: [CGFloat], liftVelocity velocity: CGFloat = 0) {
            controller.scrollViewWillBeginDragging(text)
            for y in ys { page.scroll(toY: y) }
            var target = CGPoint(x: 0, y: ys.last ?? 0)
            withUnsafeMutablePointer(to: &target) {
                controller.scrollViewWillEndDragging(text, withVelocity: CGPoint(x: 0, y: velocity / 1000), targetContentOffset: $0)
            }
            controller.scrollViewDidEndDragging(text, willDecelerate: velocity != 0)
        }
    }

    /// Matt, 2026-11-13: the cards "should not cover up the content on the page". A pull past
    /// the foot brings them in below the page's own content, where the pull has opened space,
    /// coming in with it; nothing of the page lies under them.
    @Test func aPullBringsTheCardsInPastThePagesFoot() throws {
        let s = SwitcherPage(atEnd: true)
        #expect(s.controller.switcherFrame == nil, "none at rest")
        s.controller.scrollViewWillBeginDragging(s.text)
        s.page.scroll(toY: s.foot + 28)
        let frame = try #require(s.controller.switcherFrame)
        #expect(frame.minY == s.text.contentSize.height + PhoneChapterTextController.switcherGap, "below everything on the page")
        #expect(frame.height == 112)
        #expect(s.model.deck?.front == 3 && s.model.reveal == 0.5 && !s.model.isOpen)
        #expect(s.controller.openSwitcherEdge == nil && s.controller.switcherInsets == .zero)
    }

    /// Let go past the threshold and the page rests with the cards wholly in view above the
    /// bars' inset: room for them is added to the scroll, so the text has moved up, not under.
    @Test func lettingGoPastTheThresholdRestsThePageWithTheCardsInView() throws {
        let s = SwitcherPage(atEnd: true)
        let foot = s.foot
        s.pull(through: [foot + 30, foot + 60])
        #expect(s.controller.openSwitcherEdge == .bottom)
        #expect(s.model.isOpen && s.model.deck?.front == 3)
        let room = s.controller.switcherRoom
        #expect(room == 112 + PhoneChapterTextController.switcherGap)
        #expect(s.text.contentInset.bottom == room && s.controller.switcherInsets.bottom == room)
        #expect(s.text.contentOffset.y == foot + room, "at rest in the cards' room")
        #expect(s.foot == foot, "the page's own foot is where it was")
        let frame = try #require(s.controller.switcherFrame)
        let visibleBottom = s.text.contentOffset.y + s.text.bounds.height - (s.text.adjustedContentInset.bottom - room)
        #expect(abs(frame.maxY - visibleBottom) < 0.5, "the cards sit on the bars' inset: \(frame) \(visibleBottom)")
    }

    /// Matt: "sometimes attempting to scroll down past the end ... doesn't make it show up". A
    /// drag that begins mid-page, reaches the foot and pulls on opens the switcher too.
    @Test func aPullOpensFromADragThatBeganMidPage() {
        let s = SwitcherPage(atEnd: false)
        s.page.scroll(toY: s.foot - 300)
        s.pull(through: [s.foot - 100, s.foot, s.foot + 40, s.foot + 70], liftVelocity: 100)
        #expect(s.controller.openSwitcherEdge == .bottom && s.model.isOpen)
    }

    /// From inside the page, short of the threshold the cards go as the page springs back, and
    /// nothing is left in the scroll; so does a flick that only ran on past the foot.
    @Test func aShortPullOrAFlickFromInsideThePageLeavesNothing() {
        let s = SwitcherPage(atEnd: false)
        s.page.scroll(toY: s.foot - 200)
        s.pull(through: [s.foot, s.foot + 30])
        #expect(s.controller.openSwitcherEdge == nil && s.controller.switcherFrame == nil)
        #expect(s.model.deck == nil && s.controller.switcherInsets == .zero)
        s.page.scroll(toY: s.foot - 200)
        s.pull(through: [s.foot - 50, s.foot + 70], liftVelocity: 3000)
        #expect(s.controller.openSwitcherEdge == nil && s.model.deck == nil, "a flick that ran on")
    }

    /// Matt's film, 2026-11-13: from the chapter's foot a flick up opens the cards, though the
    /// finger lifted before the page had moved far enough to show them at all.
    @Test func aFlickFromThePagesFootOpensTheCards() {
        let s = SwitcherPage(atEnd: true)
        s.pull(through: [s.foot + 6], liftVelocity: 1500)
        #expect(s.controller.openSwitcherEdge == .bottom && s.model.isOpen && s.model.deck?.front == 3)
        #expect(s.text.contentOffset.y == s.foot + s.controller.switcherRoom)
        let quick = SwitcherPage(atEnd: true)
        quick.pull(through: [], liftVelocity: 1500)
        #expect(quick.controller.openSwitcherEdge == .bottom && quick.model.isOpen, "too quick to have moved the page")
    }

    /// Matt: "it should not disappear unless they tap on something". Open, the cards stay
    /// through a scroll that keeps them on screen; a tap on the page (anywhere but the cards)
    /// sends them away and the page is back at its own foot.
    @Test func theCardsStayUntilThePageIsTapped() throws {
        let s = SwitcherPage(atEnd: true)
        let foot = s.foot
        s.pull(through: [foot + 60])
        s.controller.scrollViewWillBeginDragging(s.text)
        s.page.scroll(toY: foot + 40)
        s.controller.scrollViewDidEndDragging(s.text, willDecelerate: false)
        #expect(s.controller.openSwitcherEdge == .bottom && s.model.isOpen, "still there after a scroll")
        let frame = try #require(s.controller.switcherFrame)
        #expect(s.controller.isOnSwitcher(CGPoint(x: frame.midX, y: frame.midY)), "a tap on the cards is theirs")
        #expect(!s.controller.isOnSwitcher(CGPoint(x: frame.midX, y: frame.minY - 80)), "a tap on the text is a tap away")
        s.controller.closeSwitcher(animated: true)
        #expect(s.controller.openSwitcherEdge == nil && s.controller.switcherFrame == nil && s.model.deck == nil)
        #expect(s.controller.switcherInsets == .zero && s.text.contentOffset.y == foot)
    }

    /// Scrolled back into the chapter until the cards have left the screen, the switcher closes
    /// behind them and the reader is not moved.
    @Test func scrollingTheCardsOffTheScreenClosesTheSwitcher() {
        let s = SwitcherPage(atEnd: true)
        let foot = s.foot
        s.pull(through: [foot + 60])
        s.controller.scrollViewWillBeginDragging(s.text)
        s.page.scroll(toY: foot - 400)
        s.controller.scrollViewDidEndDragging(s.text, willDecelerate: true)
        #expect(s.controller.openSwitcherEdge == .bottom, "still open while the page coasts")
        s.controller.scrollViewDidEndDecelerating(s.text)
        #expect(s.controller.openSwitcherEdge == nil && s.controller.switcherInsets == .zero)
        #expect(s.text.contentOffset.y == foot - 400)
    }

    /// At the top the cards come in above the page's text, the previous chapter in front, and
    /// the page rests below them.
    @Test func pullingDownAtTheTopOpensTheSwitcherAboveThePage() throws {
        let s = SwitcherPage(atEnd: false)
        let top = s.top
        s.pull(through: [top - 30, top - 60])
        #expect(s.controller.openSwitcherEdge == .top && s.model.deck?.front == 1)
        let room = s.controller.switcherRoom
        #expect(s.text.contentInset.top == room && s.text.contentOffset.y == top - room)
        #expect(s.top == top, "the page's own top is where it was")
        let frame = try #require(s.controller.switcherFrame)
        #expect(frame.maxY == 0, "above everything on the page: \(frame)")
    }

    /// A tap on a card lands by Matt's rules: the previous chapter after a pull at the top, at
    /// its end; a later one, at its start. A card not at the front is brought forward first.
    @Test func aTapOnACardTurnsToItsChapter() {
        let top = SwitcherPage(atEnd: false)
        top.pull(through: [top.top - 60])
        top.model.choose(1)
        #expect(top.landings == [[1, 1]])
        let foot = SwitcherPage(atEnd: true)
        foot.pull(through: [foot.foot + 60])
        foot.model.flip(by: 1)
        #expect(foot.model.deck?.front == 4)
        foot.model.choose(4)
        #expect(foot.landings == [[4, 0]])
    }

    /// Matt, 2026-11-13: a flick anywhere on the page while the cards are open moves them, not
    /// only one on the cards. The page's own pan does not begin; a flick up at the foot (its
    /// travel and momentum past 40 points) brings the next card forward, a flick down returns
    /// it, a short drag does nothing, and the front card rides the flick meanwhile.
    @Test func aFlickAnywhereOnThePageMovesTheCards() {
        let s = SwitcherPage(atEnd: true)
        #expect(s.controller.pageMayPan)
        s.pull(through: [s.foot + 60])
        #expect(!s.controller.pageMayPan, "the page itself stays put while the cards are open")
        #expect(ChapterSwitcher.flickTravel == 40)
        s.controller.switcherFlicked(.changed, translation: -30, velocity: -600)
        #expect(s.model.dragTravel == 30, "onward at the foot is up")
        s.controller.switcherFlicked(.ended, translation: -30, velocity: -600)
        #expect(s.model.deck?.front == 4 && s.model.dragTravel == 0)
        s.controller.switcherFlicked(.ended, translation: 10, velocity: 50)
        #expect(s.model.deck?.front == 4, "a short drag moves nothing")
        s.controller.switcherFlicked(.ended, translation: 50, velocity: 300)
        #expect(s.model.deck?.front == 3, "a flick back returns the card")
        #expect(s.controller.openSwitcherEdge == .bottom)
        // At the top, onward is down.
        let top = SwitcherPage(atEnd: false, current: 4)
        top.pull(through: [top.top - 60])
        top.controller.switcherFlicked(.ended, translation: 60, velocity: 400)
        #expect(top.model.deck?.front == 2)
    }

    /// Matt: the fast flick opens the switcher too. A coast still faster than 5,000 points a
    /// second as it meets the foot opens it there; the reader's tap on the previous chapter
    /// after one at the top lands at that chapter's start.
    @Test func aCoastThatMeetsTheEndVeryFastOpensTheSwitcher() {
        let s = SwitcherPage(atEnd: false)
        @MainActor final class Clock { var now: CFTimeInterval = 1000 }
        let clock = Clock()
        s.controller.scrollClock = { clock.now }
        let foot = s.foot
        s.page.scroll(toY: foot - 400)
        s.controller.scrollViewWillBeginDragging(s.text)
        var target = CGPoint(x: 0, y: foot)
        withUnsafeMutablePointer(to: &target) {
            s.controller.scrollViewWillEndDragging(s.text, withVelocity: CGPoint(x: 0, y: 9), targetContentOffset: $0)
        }
        s.controller.scrollViewDidEndDragging(s.text, willDecelerate: true)
        for y in [foot - 300, foot - 200, foot - 100, foot] {
            clock.now += 1.0 / 120
            s.page.scroll(toY: y)
        }
        #expect(s.controller.openSwitcherEdge == .bottom && s.model.isOpen && s.model.deck?.opening == .arrival)
        #expect(s.text.contentOffset.y == foot + s.controller.switcherRoom)
    }

    /// Matt, 2026-11-13: the cards cross books. At a book's last chapter a pull at the foot opens
    /// the next book's card, alone; from the chapter before, a flick past the last chapter's card
    /// brings it to the front (counted, for the cards' closing up and fanning out); a tap on it
    /// turns to that book's first chapter. At a book's first chapter a pull at the top opens the
    /// previous book's card, and a tap lands at its last chapter's end.
    @Test func theCardsCrossIntoTheNeighbouringBook() {
        let jonah = ChapterSwitcher.BookEnd(book: "JON", name: "Jonah", chapter: 1)
        let amos = ChapterSwitcher.BookEnd(book: "AMO", name: "Amos", chapter: 9)
        let last = SwitcherPage(atEnd: true, chapters: [1, 2], current: 2, next: jonah)
        last.pull(through: [last.foot + 60])
        #expect(last.controller.openSwitcherEdge == .bottom && last.model.deck?.isFrontBook == true)
        #expect(last.model.bookArrivals == 1, "it opened on another book's card")
        last.model.chooseBook()
        #expect(last.landings == [[1, 0]] && last.booksLanded == ["JON"])

        let before = SwitcherPage(atEnd: true, chapters: [1, 2, 3], current: 2, next: jonah)
        before.pull(through: [before.foot + 60])
        #expect(before.model.deck?.front == 3 && before.model.bookArrivals == 0)
        before.model.flip(by: 1)
        #expect(before.model.deck?.isFrontBook == true && before.model.bookArrivals == 1)
        before.model.flip(by: 1)
        #expect(before.model.bookArrivals == 1, "the stack ends there")

        let first = SwitcherPage(atEnd: false, chapters: [1, 2], current: 1, previous: amos)
        first.pull(through: [first.top - 60])
        #expect(first.controller.openSwitcherEdge == .top && first.model.deck?.isFrontBook == true)
        first.model.chooseBook()
        #expect(first.landings == [[9, 1]] && first.booksLanded == ["AMO"], "the one chapter back: at its end")
    }

    /// A flick back from the first card pushes the stack away: the switcher closes.
    @Test func flickingBackFromTheFirstCardClosesTheSwitcher() {
        let s = SwitcherPage(atEnd: true)
        s.pull(through: [s.foot + 60])
        s.model.flip(by: -1)
        #expect(s.controller.openSwitcherEdge == nil && s.model.deck == nil && s.controller.switcherInsets == .zero)
    }

    /// The switcher never crosses books: at the book's last chapter a pull at the foot shows
    /// nothing. Nor does it show when the screen does not allow it (VoiceOver), and taking the
    /// allowance away closes it.
    @Test func noCardsWhereThereIsNoChapterOrNoLeave() {
        let last = SwitcherPage(atEnd: true, chapters: [1, 2], current: 2)
        last.pull(through: [last.foot + 60])
        #expect(last.controller.openSwitcherEdge == nil && last.controller.switcherFrame == nil && last.model.deck == nil)
        let s = SwitcherPage(atEnd: true)
        s.model.allow(false)
        s.pull(through: [s.foot + 60])
        #expect(s.controller.openSwitcherEdge == nil && s.model.deck == nil)
        s.model.allow(true)
        s.page.scroll(toY: s.foot)
        s.pull(through: [s.foot + 60])
        #expect(s.controller.openSwitcherEdge == .bottom)
        s.model.allow(false)
        #expect(s.controller.openSwitcherEdge == nil && s.controller.switcherInsets == .zero)
    }

    /// Nothing is pulled while the thumb is pressed, and the thumb's press closes the switcher.
    @Test func theThumbAndTheSwitcherNeverShowTogether() {
        let s = SwitcherPage(atEnd: true)
        let edge = CGPoint(x: s.text.bounds.width - 10, y: s.foot + 300)
        s.controller.thumbPressed(.began, at: edge, touchStartedAt: edge)
        s.pull(through: [s.foot + 60])
        s.controller.thumbPressed(.ended, at: edge, touchStartedAt: edge)
        #expect(s.controller.openSwitcherEdge == nil && s.model.deck == nil)
        s.page.scroll(toY: s.foot)
        s.pull(through: [s.foot + 60])
        #expect(s.controller.openSwitcherEdge == .bottom)
        s.controller.thumbPressed(.began, at: edge, touchStartedAt: edge)
        #expect(s.controller.openSwitcherEdge == nil && s.controller.switcherInsets == .zero)
        s.controller.thumbPressed(.cancelled, at: edge, touchStartedAt: edge)
    }

    /// Another chapter shown (the card's own landing, or any other route) closes the switcher:
    /// the new page starts with its own ends.
    @Test func aNewChapterClosesTheSwitcher() {
        let s = SwitcherPage(atEnd: true)
        s.pull(through: [s.foot + 60])
        #expect(s.controller.openSwitcherEdge == .bottom)
        s.page.show(F.book(3...3, counts: [3: 60]), target: ScrollTarget(chapter: 3, verse: 1))
        #expect(s.controller.openSwitcherEdge == nil && s.controller.switcherInsets == .zero && s.model.deck == nil)
        #expect(s.text.contentOffset.y == s.top)
    }

    // MARK: A tap selects the verse

    /// Spec 4 (verse basics): a tap on a verse selects the whole verse and presents the selection
    /// menu, and leaves the reader's other gestures as they were. Chapter 3's twelve verses on a
    /// page of its own, made for each test.
    @MainActor @Suite struct VerseTap {
        typealias VerseTapTouch = PhoneChapterTextController.VerseTapTouch

        private let layout = F.book(3...3, counts: [3: 12])
        private let page = F.Harness(width: 390, height: 700) { _ in }

        init() {
            page.show(layout, target: ScrollTarget(chapter: 3, verse: 1))
        }

        private func at(_ chapter: Int, _ verse: Int) -> VerseLocation {
            VerseLocation(book: "MAT", chapter: chapter, verse: verse)
        }

        private func span(_ verse: Int) -> VerseSpan? { layout.span(for: at(3, verse)) }

        /// The centre of verse `verse`'s first three text characters.
        private func words(_ verse: Int) throws -> CGPoint {
            let span = try #require(span(verse))
            let rect = try #require(page.controller.rect(for: NSRange(location: span.textRange.location, length: 3)))
            return CGPoint(x: rect.midX, y: rect.midY)
        }

        /// A point on verse `verse`'s first line past its first nine characters (where
        /// `aTapOnAHighlightIsNotAVerseTap` puts a highlight), short of the thumb's zone.
        private func endOfFirstLine(_ verse: Int) throws -> CGPoint {
            let span = try #require(span(verse))
            let line = try #require(page.controller.segmentFrames(of: [span.textRange])[0].first)
            let nine = try #require(page.controller.rect(for: NSRange(location: span.textRange.location, length: 9)))
            let end = min(line.maxX, page.textView.bounds.width - PhoneChapterTextController.thumbEdgeZone)
            return CGPoint(x: (nine.maxX + end) / 2, y: line.midY)
        }

        private func tap(_ point: CGPoint) {
            page.controller.verseTapped(at: point, touch: VerseTapTouch())
        }

        private func hit(_ point: CGPoint, _ touch: VerseTapTouch = VerseTapTouch()) -> VerseSpan? {
            page.controller.verseForTap(at: point, touch: touch)
        }

        private func line(_ page: F.Harness, layout: BookLayout, verse: Int, x: CGFloat) throws -> CGPoint {
            try PhoneChapterTextControllerTests().line(page, layout: layout, verse: verse, x: x)
        }

        /// Chapter 1 with a heading before verse 3, shown on `page`: points beside a line in the
        /// margin, on the title block, on the heading, and below the last line.
        private func offTextPoints() throws -> [CGPoint] {
            let chapter = F.book(1...1, counts: [1: 6], headings: [1: [3: [SectionHeading(text: "A Heading", level: 1)]]])
            page.show(chapter, target: ScrollTarget(chapter: 1, verse: 1))
            let string = chapter.attributedString.string as NSString
            let section = chapter.sections[0]
            let title = string.paragraphRange(for: NSRange(location: section.openingRange.location, length: 0))
            let heading = string.range(of: "A Heading")
            let verse = try #require(chapter.span(for: at(1, 2)))
            let last = try #require(chapter.span(for: at(1, 6)))
            let verseLine = try #require(page.controller.rect(for: verse.textRange))
            let lastLine = try #require(page.controller.segmentFrames(of: [last.textRange])[0].last)
            let titleRect = try #require(page.controller.rect(for: NSIntersectionRange(title, section.openingRange)))
            let headingRect = try #require(page.controller.rect(for: heading))
            return [
                CGPoint(x: page.textView.textContainerInset.left / 2, y: verseLine.midY),
                CGPoint(x: titleRect.midX, y: titleRect.midY),
                CGPoint(x: headingRect.midX, y: headingRect.midY),
                CGPoint(x: lastLine.midX, y: lastLine.maxY + 40),
            ]
        }

        @Test func aTapOnAVerseSelectsItsTextAndPresentsTheMenu() throws {
            var reports: [SelectionReport?] = []
            page.controller.onSelectionChange = { reports.append($0) }
            tap(try words(4))
            let span = try #require(span(4))
            #expect(page.textView.selectedRange == span.textRange)          // the words, not the number
            #expect(reports.last??.selection.verse == 4 && reports.last??.selection.endVerse == 4)
            #expect(reports.last??.selection.startOffset == 0 && reports.last??.selection.endOffset == span.textRange.length)
            #expect(page.controller.menuPresentations == 1)
            let number = try #require(page.controller.rect(for: span.numberRange))
            #expect(hit(CGPoint(x: number.midX, y: number.midY)) == span)   // its number too
        }

        @Test func aTappedVersesMenuIsTheHandSelectionsMenu() throws {
            var asked: [SelectionReport] = []
            page.controller.menuProvider = { asked.append($0); return UIMenu(children: []) }
            tap(try words(4))
            _ = page.controller.textView(page.textView, editMenuForTextIn: page.textView.selectedRange, suggestedActions: [])
            page.textView.selectedRange = NSRange(location: 0, length: 0)
            page.textView.selectedRange = try #require(span(4)).textRange            // by hand
            _ = page.controller.textView(page.textView, editMenuForTextIn: page.textView.selectedRange, suggestedActions: [])
            // The tap's own presentation asks first (`editMenuInteraction(_:menuFor:)`), then the two asks here.
            #expect(asked.count == 3 && asked.allSatisfy { $0 == asked[0] })
        }

        /// Matt, 2026-11-17 (overturning spec 4's "a tap on another verse selects that verse
        /// instead"): with a verse selected, a tap on another verse only deselects; the next tap
        /// there selects it.
        @Test func aTapOnAnotherVerseOnlyDeselectsAndTheNextTapSelectsIt() throws {
            var reports: [SelectionReport?] = []
            page.controller.onSelectionChange = { reports.append($0) }
            tap(try words(4))
            let away = try words(6)
            #expect(page.controller.isTapAway(at: away, touch: VerseTapTouch()))
            #expect(hit(away) == nil)
            tap(away)
            #expect(page.textView.selectedRange.length == 0)
            #expect(reports.count == 2 && reports.last! == nil)
            #expect(page.controller.menuPresentations == 1)
            #expect(!page.controller.isTapAway(at: away, touch: VerseTapTouch()))
            tap(away)
            #expect(page.textView.selectedRange == span(6)?.textRange && page.controller.menuPresentations == 2)
        }

        @Test func aTapAwayAnywhereOnlyDeselects() throws {
            // Off the text (the margin, the title block, a heading, below the last line) and the
            // thumb's zone: each a tap away from the selected verse, which only clears it.
            let points = try offTextPoints()
            let chapter = F.book(1...1, counts: [1: 6], headings: [1: [3: [SectionHeading(text: "A Heading", level: 1)]]])
            let verse = try #require(chapter.span(for: at(1, 5)))
            let first = try #require(page.controller.rect(for: verse.textRange))
            let verseTwo = try #require(chapter.span(for: at(1, 2)))
            let other = try #require(page.controller.rect(for: verseTwo.textRange))
            let zone = CGPoint(x: page.textView.bounds.width - 10, y: other.midY)
            for point in points + [zone] {
                page.controller.verseTapped(at: CGPoint(x: first.minX + 4, y: first.midY), touch: VerseTapTouch())
                #expect(page.textView.selectedRange == verse.textRange, "\(point)")
                #expect(page.controller.isTapAway(at: point, touch: VerseTapTouch()), "\(point)")
                page.controller.verseTapped(at: point, touch: VerseTapTouch())
                #expect(page.textView.selectedRange.length == 0, "\(point)")
            }
        }

        @Test func aTapOnTheSelectedVerseKeepsItAndShowsTheMenuAgain() throws {
            let span = try #require(span(4))
            tap(try words(4))
            tap(try endOfFirstLine(4))
            let number = try #require(page.controller.rect(for: span.numberRange))
            tap(CGPoint(x: number.midX, y: number.midY))                     // its number too
            #expect(page.textView.selectedRange == span.textRange && page.controller.menuPresentations == 3)
            // A word held inside the verse: a tap on the word keeps the word.
            let word = NSRange(location: span.textRange.location, length: 5)
            page.textView.selectedRange = word
            tap(try words(4))
            #expect(page.textView.selectedRange == word && page.controller.menuPresentations == 4)
        }

        @Test func aSecondTapAwayThatTheSystemClearedIsNotSettledIntoAVerse() throws {
            // A repeated tap off the selection, cleared by the system's single tap before it settles.
            tap(try words(4))
            let away = try words(5)
            let touch = page.controller.verseTapTouch(tapCount: 2, at: away)   // as the touch comes down
            #expect(touch.awayFromSelection)
            page.textView.selectedRange = NSRange(location: try #require(span(4)).textRange.location, length: 0)
            #expect(!page.controller.settleRepeatedTap(at: away, touch: touch))
            #expect(page.textView.selectedRange.length == 0)
        }

        @Test func aTapOnAHighlightWithAVerseSelectedOnlyDeselects() throws {
            // A highlight on verse 6's first nine characters, with a note; verse 4 selected.
            let item = MarkupItem(id: UUID(), chapter: 3, verse: 6, endVerse: 6, startOffset: 0, endOffset: 9, translationID: "WEB",
                                  color: MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00"), hasNote: true)
            let decorations = BookDecorations.build(itemsByChapter: [3: [item]], bookmarksByChapter: [:], outlinedID: nil,
                                                    viewingTranslationID: "WEB", layout: layout)
            page.show(layout, decorations: decorations)
            let note = UUID()
            var opened: [UUID] = []
            var highlighted: [UUID] = []
            page.controller.noteForHighlight = { _ in note }
            page.controller.onOpenNote = { opened.append($0) }
            page.controller.onHighlightTap = { highlighted.append($0) }
            tap(try words(4))
            let onHighlight = try words(6)
            #expect(page.controller.highlightForTap(at: onHighlight, touch: VerseTapTouch()) == nil)
            #expect(page.controller.isTapAway(at: onHighlight, touch: VerseTapTouch()))
            page.controller.highlightTapped(at: onHighlight, touch: VerseTapTouch())   // declined: it is the verse tap's
            tap(onHighlight)
            #expect(page.textView.selectedRange.length == 0 && opened.isEmpty && highlighted.isEmpty)
            // The next tap opens it.
            #expect(page.controller.highlightForTap(at: onHighlight, touch: VerseTapTouch())?.id != nil)
            page.controller.highlightTapped(at: onHighlight, touch: VerseTapTouch())
            #expect(opened == [note])
        }

        /// Fix round 1: a margin mark and the chapter-note mark are controls the verse tap never
        /// takes; with a selection up their tap is a tap away too, and only clears it.
        @Test func aTapOnAMarginMarkWithAVerseSelectedOnlyDeselects() throws {
            let marks = MarginMark.build(notesByChapter: [:], itemsByChapter: [:], bookmarksByChapter: [3: [5]], layout: layout)
            page.show(layout, target: ScrollTarget(chapter: 3, verse: 1), marks: marks)
            var tapped: [MarginMark] = []
            page.controller.onMarginMarkTap = { tapped.append($0) }
            let bookmark = try #require(page.controller.markButtons.first)
            tap(try words(4))
            bookmark.sendActions(for: .primaryActionTriggered)
            #expect(page.textView.selectedRange.length == 0 && tapped.isEmpty)
            bookmark.sendActions(for: .primaryActionTriggered)                // nothing selected: the mark acts
            #expect(tapped == marks)
        }

        @Test func aTapOnTheChapterNoteMarkWithAVerseSelectedOnlyDeselects() throws {
            var shown: [Int] = []
            page.controller.onShowChapterNotes = { shown.append($0) }
            page.controller.chapterNoteCounts = [3: 1]
            let mark = try #require(page.controller.chapterNoteMarkViews[3])
            tap(try words(4))
            mark.sendActions(for: .primaryActionTriggered)
            #expect(page.textView.selectedRange.length == 0 && shown.isEmpty)
            mark.sendActions(for: .primaryActionTriggered)
            #expect(shown == [3])
        }

        /// Fix round 1: the second tap of a quick double tap just off the selection. The system's
        /// double tap does not wait for the verse tap, so it may select a word under it after the
        /// verse tap has cleared; once every recogniser on the touch has acted it is cleared too.
        @Test func aQuickSecondTapAwayLeavesNoWordTheSystemsDoubleTapChose() async throws {
            tap(try words(4))
            let away = try words(5)
            let touch = page.controller.verseTapTouch(tapCount: 2, at: away)   // as the touch comes down
            #expect(touch.awayFromSelection)
            page.controller.verseTapped(at: away, touch: touch)
            #expect(page.textView.selectedRange.length == 0)
            let word = NSRange(location: try #require(span(5)).textRange.location, length: 5)
            page.textView.selectedRange = word                                // the system's double tap, after it
            await withCheckedContinuation { done in DispatchQueue.main.async { done.resume() } }
            #expect(page.textView.selectedRange.length == 0)
        }

        @Test func aTapOnAnOpenedHighlightKeepsItAndATapAwayClosesIt() throws {
            // A highlight without a note is selected with its menu; a tap on it keeps it, one off it clears it.
            let item = MarkupItem(id: UUID(), chapter: 3, verse: 6, endVerse: 6, startOffset: 0, endOffset: 9, translationID: "WEB",
                                  color: MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00"), hasNote: false)
            let decorations = BookDecorations.build(itemsByChapter: [3: [item]], bookmarksByChapter: [:], outlinedID: nil,
                                                    viewingTranslationID: "WEB", layout: layout)
            page.show(layout, decorations: decorations)
            let onHighlight = try words(6)
            page.controller.highlightTapped(at: onHighlight, touch: VerseTapTouch())
            let range = page.textView.selectedRange
            #expect(range.length == 9 && page.controller.menuPresentations == 1)
            page.controller.highlightTapped(at: onHighlight, touch: VerseTapTouch())
            #expect(page.textView.selectedRange == range && page.controller.menuPresentations == 2)
            tap(try words(4))
            #expect(page.textView.selectedRange.length == 0 && page.controller.menuPresentations == 2)
        }

        @Test func aTapOffTheTextIsNotAVerseTap() throws {
            // Chapter 1 with a heading before verse 3: the margin beside a line, the title block, the heading, below the last line.
            for point in try offTextPoints() { #expect(hit(point) == nil, "\(point)") }
        }

        @Test func everyPointDownAVersesLinesIsThatVerse() throws {
            var prefs = ReaderPreferences.default
            prefs.lineSpacing = .relaxed
            let typography = ReaderSettings.typography(prefs)
            let second = F.Harness(width: 390, height: 700) { _ in }
            let chapter = F.book(3...3, counts: [3: 12], typography: typography)
            second.show(chapter, typography: typography, target: ScrollTarget(chapter: 3, verse: 1))
            let relaxed = second.controller
            let verseOne = try #require(chapter.span(for: at(3, 1)))
            // Verse 1 opens the chapter, so each of its lines starts at the column's edge.
            let first = try #require(relaxed.rect(for: NSRange(location: verseOne.textRange.location, length: 1)))
            let last = try #require(relaxed.rect(for: NSRange(location: NSMaxRange(verseOne.textRange) - 1, length: 1)))
            #expect(last.minY > first.maxY, "the verse wraps")
            for y in stride(from: first.minY, through: last.maxY, by: 1) {
                #expect(relaxed.verseForTap(at: CGPoint(x: first.minX + 4, y: y), touch: VerseTapTouch()) == verseOne, "y \(y)")
            }
        }

        @Test func aTapOnAHighlightIsNotAVerseTap() throws {
            // A highlight on verse 4's first nine characters; the rest of the verse is still a verse tap.
            let item = MarkupItem(id: UUID(), chapter: 3, verse: 4, endVerse: 4, startOffset: 0, endOffset: 9, translationID: "WEB",
                                  color: MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00"), hasNote: false)
            let decorations = BookDecorations.build(itemsByChapter: [3: [item]], bookmarksByChapter: [:], outlinedID: nil,
                                                    viewingTranslationID: "WEB", layout: layout)
            page.show(layout, decorations: decorations)
            #expect(hit(try words(4)) == nil)
            #expect(hit(try endOfFirstLine(4)) == span(4))
        }

        @Test func theRulesThatMakeATapNotAVerseTap() throws {
            let point = try words(4)
            #expect(hit(point, VerseTapTouch(tapCount: 2)) == nil)            // a double tap's second
            #expect(hit(point, VerseTapTouch(pageWasMoving: true)) == nil)    // it stopped a scroll
            #expect(hit(point, VerseTapTouch(cardsWereOpen: true)) == nil)    // it closes the cards
            page.controller.isVoiceOverRunning = { true }
            #expect(hit(point) == nil)
            page.controller.isVoiceOverRunning = { false }
            page.controller.setPen(isOn: true, color: .systemYellow, selectedID: nil)
            #expect(hit(point) == nil)
            page.controller.setPen(isOn: false, color: .systemYellow, selectedID: nil)
            #expect(hit(try line(page, layout: layout, verse: 4, x: page.textView.bounds.width - 10)) == nil)   // the thumb's zone
            #expect(hit(point) == span(4))
        }

        @Test func aTapWhileTheCardsAreOpenSelectsNothing() throws {
            // `SwitcherPage(atEnd: true)` pulled open, as `theCardsStayUntilThePageIsTapped` does.
            let s = SwitcherPage(atEnd: true)
            s.pull(through: [s.foot + 60])
            /// The words of the last verse, in view above the cards.
            func wordsOnScreen() throws -> CGPoint {
                let span = try #require(F.book(2...2, counts: [2: 60]).span(for: at(2, 60)))
                let rect = try #require(s.controller.rect(for: NSRange(location: span.textRange.location, length: 3)))
                return CGPoint(x: rect.midX, y: rect.midY)
            }
            let touch = s.controller.verseTapTouch(tapCount: 1)             // as the touch comes down
            #expect(s.controller.openSwitcherEdge == .bottom && touch.cardsWereOpen && !touch.pageWasMoving)
            s.controller.closeSwitcher(animated: false)                     // the away tap, at touch-up
            s.controller.verseTapped(at: try wordsOnScreen(), touch: touch)
            #expect(s.text.selectedRange.length == 0 && s.controller.menuPresentations == 0)
            #expect(!s.controller.verseTapTouch(tapCount: 1).cardsWereOpen)
        }

        @Test func theVerseTapActsAtOnceAndLeavesTheDoubleTapToTheSystem() throws {
            let tap = page.controller.verseTapRecognizer
            let own = page.controller.ownGestures
            #expect(tap.numberOfTapsRequired == 1 && own.contains { $0 === tap })
            for other in page.textView.gestureRecognizers ?? [] where !own.contains(where: { $0 === other }) {
                // It waits for nothing, so a single tap never waits to see whether a second follows.
                #expect(!page.controller.gestureRecognizer(tap, shouldRequireFailureOf: other))
                // The text view's single taps wait for it; its double tap does not.
                let single = (other as? UITapGestureRecognizer)?.numberOfTapsRequired == 1
                #expect(page.controller.gestureRecognizer(tap, shouldBeRequiredToFailBy: other) == single)
            }
        }

        /// Spec 4: a tap on the verse already selected selects it again. A second tap UIKit counts
        /// as `tapCount` 2 that came too slowly for the system's double tap is cleared by the
        /// system's single tap; once the touch's recognisers have acted the verse is selected again.
        @Test func aSlowSecondTapOnTheSelectedVerseSelectsItAgain() throws {
            let point = try words(4)
            let span = try #require(span(4))
            tap(point)
            page.textView.selectedRange = NSRange(location: span.textRange.location, length: 0)   // the system's single tap
            let settled = page.controller.settleRepeatedTap(at: point, touch: VerseTapTouch(tapCount: 2))
            #expect(settled)
            #expect(page.textView.selectedRange == span.textRange && page.controller.menuPresentations == 2)
        }

        @Test func aDoubleTapsWordIsLeftAlone() throws {
            let point = try words(4)
            let span = try #require(span(4))
            tap(point)
            let word = NSRange(location: span.textRange.location, length: 5)                       // "Verse", the system's double tap
            page.textView.selectedRange = word
            let settled = page.controller.settleRepeatedTap(at: point, touch: VerseTapTouch(tapCount: 2))
            #expect(!settled)
            #expect(page.textView.selectedRange == word && page.controller.menuPresentations == 1)
        }

        @Test func aRepeatedTapKeepsTheVerseTapsOtherRules() throws {
            let point = try words(4)
            let empty = NSRange(location: try #require(span(4)).textRange.location, length: 0)
            page.textView.selectedRange = empty
            var settled = page.controller.settleRepeatedTap(at: point, touch: VerseTapTouch(tapCount: 1))   // the verse tap's own
            #expect(!settled)
            settled = page.controller.settleRepeatedTap(at: point, touch: VerseTapTouch(tapCount: 2, cardsWereOpen: true))
            #expect(!settled)
            settled = page.controller.settleRepeatedTap(at: point, touch: VerseTapTouch(tapCount: 2, pageWasMoving: true))
            #expect(!settled)
            page.controller.setPen(isOn: true, color: .systemYellow, selectedID: nil)
            settled = page.controller.settleRepeatedTap(at: point, touch: VerseTapTouch(tapCount: 2))
            #expect(!settled)
            page.controller.setPen(isOn: false, color: .systemYellow, selectedID: nil)
            page.textView.selectedRange = empty
            let margin = CGPoint(x: page.textView.textContainerInset.left / 2, y: point.y)
            settled = page.controller.settleRepeatedTap(at: margin, touch: VerseTapTouch(tapCount: 2))
            #expect(!settled)
            #expect(page.textView.selectedRange == empty && page.controller.menuPresentations == 0)
            settled = page.controller.settleRepeatedTap(at: point, touch: VerseTapTouch(tapCount: 3))
            #expect(settled)
        }

        @Test func aMarginMarkIsNotAVerseTap() throws {
            // As `aTapOnAMarginMarkStillActsOnTheMark`: the mark is the view hit at its centre.
            let marks = MarginMark.build(notesByChapter: [:], itemsByChapter: [:], bookmarksByChapter: [3: [5]], layout: layout)
            page.show(layout, target: ScrollTarget(chapter: 3, verse: 1), marks: marks)
            let bookmark = try #require(page.controller.markButtons.first)
            let centre = CGPoint(x: bookmark.frame.midX, y: bookmark.frame.midY)
            #expect(page.textView.hitTest(centre, with: nil) === bookmark && hit(centre) == nil)
        }
    }

    // MARK: Where the selection menu sits

    /// Matt, 2026-11-17: the menu sits directly above the selection or directly below it, never
    /// over the selected words. It was given the first line alone, so it could lie on the rest.
    @MainActor @Suite struct SelectionMenu {
        typealias VerseTapTouch = PhoneChapterTextController.VerseTapTouch
        typealias Placement = PhoneChapterTextController.MenuPlacement

        private let layout = F.book(3...3, counts: [3: 12])
        private let page = F.Harness(width: 390, height: 700) { _ in }

        init() {
            page.show(layout, target: ScrollTarget(chapter: 3, verse: 1))
        }

        private func span(_ verse: Int) throws -> VerseSpan {
            try #require(layout.span(for: VerseLocation(book: "MAT", chapter: 3, verse: verse)))
        }

        private func words(_ verse: Int) throws -> CGPoint {
            let rect = try #require(page.controller.rect(for: NSRange(location: try span(verse).textRange.location, length: 3)))
            return CGPoint(x: rect.midX, y: rect.midY)
        }

        private func bounds(_ range: NSRange) -> CGRect {
            page.controller.segmentFrames(of: [range])[0].reduce(CGRect.null) { $0.union($1) }
        }

        private var targetRect: CGRect {
            let configuration = UIEditMenuConfiguration(identifier: nil, sourcePoint: .zero)
            return page.controller.editMenuInteraction(UIEditMenuInteraction(delegate: nil), targetRectFor: configuration)
        }

        /// The menu presented last is placed against `range`'s whole bounds (the part in view),
        /// and its source point is outside the selected lines, on the side it opens to.
        private func expectPlacedAgainst(_ range: NSRange, _ label: String) throws {
            let configuration = try #require(page.controller.presentedMenuConfiguration, "\(label)")
            let target = bounds(range).intersection(page.controller.visiblePage)
            #expect(targetRect == target, "\(label)")
            let source = configuration.sourcePoint
            #expect(source.y <= target.minY || source.y >= target.maxY, "\(label): \(source) inside \(target)")
            switch configuration.preferredArrowDirection {
            case .down: #expect(source.y == target.minY, "\(label)")
            case .up: #expect(source.y == target.maxY, "\(label)")
            default: Issue.record("\(label): no side chosen")
            }
        }

        // The rule, alone.

        private let visible = CGRect(x: 0, y: 100, width: 400, height: 600)   // 100 to 700
        private let room: CGFloat = 50

        private func lines(from top: CGFloat, to bottom: CGFloat) -> [CGRect] {
            stride(from: top, to: bottom, by: 30).map { CGRect(x: 20, y: $0, width: 300, height: 24) }
        }

        @Test func aSelectionWithRoomAboveHasTheMenuAboveItsFirstLine() {
            let selection = lines(from: 300, to: 400)
            let placement = PhoneChapterTextController.menuPlacement(for: selection, in: visible, room: room)
            #expect(placement == Placement(target: CGRect(x: 20, y: 300, width: 300, height: 114), arrow: .down))
        }

        @Test func aSelectionCloseUnderTheBarHasTheMenuBelowItsLastLine() {
            let selection = lines(from: 120, to: 200)
            let placement = PhoneChapterTextController.menuPlacement(for: selection, in: visible, room: room)
            #expect(placement == Placement(target: CGRect(x: 20, y: 120, width: 300, height: 84), arrow: .up))
        }

        @Test func aSelectionRunningOffTheTopHasTheMenuBelowItsVisiblePart() {
            let selection = lines(from: 0, to: 300)
            let placement = PhoneChapterTextController.menuPlacement(for: selection, in: visible, room: room)
            #expect(placement == Placement(target: CGRect(x: 20, y: 100, width: 300, height: 194), arrow: .up))
        }

        @Test func aSelectionRunningOffTheBottomHasTheMenuAboveItsVisiblePart() {
            let selection = lines(from: 400, to: 900)
            let placement = PhoneChapterTextController.menuPlacement(for: selection, in: visible, room: room)
            #expect(placement == Placement(target: CGRect(x: 20, y: 400, width: 300, height: 300), arrow: .down))
        }

        /// The call: a selection with no room either side (both ends off screen, or a passage
        /// taller than the page) has the menu above its visible part, at the screen's top edge
        /// over the bar, where it covers none of the selected words.
        @Test func aSelectionFillingThePageHasTheMenuAtTheTopEdge() {
            let selection = lines(from: 0, to: 900)
            let placement = PhoneChapterTextController.menuPlacement(for: selection, in: visible, room: room)
            #expect(placement == Placement(target: CGRect(x: 20, y: 100, width: 300, height: 600), arrow: .down))
        }

        @Test func aSelectionOutOfViewKeepsItsBoundsAndNoSelectionHasNoMenu() {
            let selection = lines(from: 800, to: 900)
            let placement = PhoneChapterTextController.menuPlacement(for: selection, in: visible, room: room)
            #expect(placement == Placement(target: CGRect(x: 20, y: 800, width: 300, height: 114), arrow: .automatic))
            #expect(PhoneChapterTextController.menuPlacement(for: [], in: visible, room: room) == nil)
        }

        // Each route that presents the reader's own menu.

        @Test func aTappedVersesMenuIsPlacedAgainstTheWholeVerse() throws {
            let span = try span(6)
            page.controller.verseTapped(at: try words(6), touch: VerseTapTouch())
            #expect(page.controller.segmentFrames(of: [span.textRange])[0].count > 1, "the verse wraps")
            try expectPlacedAgainst(span.textRange, "verse tap")
        }

        @Test func theMenuOfAVerseUnderTheTopOfThePageGoesBelowIt() throws {
            // Verse 1's first line under the page's top: no room above.
            let span = try span(1)
            page.scroll(toY: bounds(span.textRange).minY - 10)
            page.controller.verseTapped(at: try words(1), touch: VerseTapTouch())
            #expect(page.controller.presentedMenuConfiguration?.preferredArrowDirection == .up)
            try expectPlacedAgainst(span.textRange, "verse at the top")
        }

        @Test func aSlowSecondTapsMenuIsPlacedAgainstTheWholeVerse() throws {
            let span = try span(6)
            let point = try words(6)
            page.controller.verseTapped(at: point, touch: VerseTapTouch())
            page.textView.selectedRange = NSRange(location: span.textRange.location, length: 0)   // the system's single tap
            #expect(page.controller.settleRepeatedTap(at: point, touch: VerseTapTouch(tapCount: 2)))
            try expectPlacedAgainst(span.textRange, "slow second tap")
        }

        @Test func anOpenedHighlightsMenuIsPlacedAgainstTheWholeHighlight() throws {
            // A highlight over verses 5 and 6, without a note.
            let item = MarkupItem(id: UUID(), chapter: 3, verse: 5, endVerse: 6, startOffset: 0, endOffset: 40, translationID: "WEB",
                                  color: MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00"), hasNote: false)
            let decorations = BookDecorations.build(itemsByChapter: [3: [item]], bookmarksByChapter: [:], outlinedID: nil,
                                                    viewingTranslationID: "WEB", layout: layout)
            page.show(layout, decorations: decorations)
            let decoration = try #require(decorations.highlights.first)
            page.controller.highlightTapped(at: try words(5), touch: VerseTapTouch())
            #expect(page.textView.selectedRange == decoration.range)
            try expectPlacedAgainst(decoration.range, "highlight")
        }

        @Test func aSelectionTallerThanThePageIsPlacedAgainstItsVisiblePart() throws {
            // The whole chapter selected, then the tap on it that shows its menu again.
            let whole = NSRange(location: try span(1).textRange.location,
                                length: NSMaxRange(try span(12).textRange) - (try span(1).textRange.location))
            page.scroll(toY: bounds(try span(3).textRange).minY)
            page.textView.selectedRange = whole
            let selected = page.textView.selectedRange
            #expect(bounds(selected).height > page.controller.visiblePage.height)
            page.controller.verseTapped(at: try words(5), touch: VerseTapTouch())
            #expect(page.textView.selectedRange == selected)
            try expectPlacedAgainst(selected, "whole chapter")
            #expect(targetRect.minY >= page.controller.visiblePage.minY && targetRect.maxY <= page.controller.visiblePage.maxY)
        }
    }
}
#endif
