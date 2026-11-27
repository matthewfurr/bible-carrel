import Foundation
import Observation
import ScriptureData
import Testing
@testable import ScriptureUI
#if os(macOS)
import AppKit
// Only the hosting types: SwiftUI's own `ScrollTarget` would shadow the reader's.
import class SwiftUI.NSHostingController
import class SwiftUI.NSHostingView
#endif

/// The Mac reader's chrome around the chapter's page: the running-head strip, the chapter's
/// footer links, the chapter-note mark and the headings rotor.
@MainActor @Suite struct ReaderChromeTests {
    /// The strip is the spacing scale's `xl` plus one line of the head's own voice, so a bigger
    /// reader size gives a taller strip.
    @Test func theStripIsXLPlusOneLineOfTheHead() {
        let printed = ReaderTypography.styled(.default)
        let font = printed.runningHeadFont
        let line = ceil(font.ascender - font.descender + font.leading)
        #expect(RunningHeadView.stripHeight(for: printed) == AppSpacing.xl + line)
        var large = ReaderPreferences.default
        large.fontSize = 28
        #expect(RunningHeadView.stripHeight(for: .styled(large)) > RunningHeadView.stripHeight(for: printed))
    }

    /// Set when an observed read is invalidated.
    private final class Invalidated: @unchecked Sendable {
        var value = false
    }

    /// Whether the next change to `chrome` invalidates `read`, as SwiftUI observes a view's body.
    private func watch(_ read: () -> Void) -> Invalidated {
        let invalidated = Invalidated()
        withObservationTracking(read) { invalidated.value = true }
        return invalidated
    }

    /// Task 7b: the page's reports change on nearly every scroll frame, so each part is observed
    /// on its own (`ReaderChrome`) and only the small view that draws it is re-evaluated, never
    /// the reader around it (`ReaderView`, the phone's reader screen), which reads none of them.
    /// A frame that moves the progress line invalidates the line's readers alone; a fade, the
    /// head's opacity alone; the foot, the foot links alone; a report that changes nothing,
    /// nothing. Before the text reports on the open chapter (or after another book), the head is
    /// hidden with no progress, as `RunningHeadTitle` has it.
    @Test func eachScrollReportInvalidatesOnlyWhatDrawsIt() {
        let chrome = ReaderChrome()
        #expect(chrome.headOpacity(for: 119) == 0 && chrome.headProgress(for: 119) == 0 && chrome.footReveal == 0)
        chrome.report(RunningHeadState(chapter: 119, progress: 0.2, headOpacity: 1))
        #expect(chrome.headOpacity(for: 119) == 1 && chrome.headProgress(for: 119) == 0.2)
        // A report on the chapter before (a stale one) shows nothing for the open chapter.
        #expect(chrome.headOpacity(for: 118) == 0 && chrome.headProgress(for: 118) == 0)

        var opacity = watch { _ = chrome.headOpacity(for: 119) }
        var progress = watch { _ = chrome.headProgress(for: 119) }
        var foot = watch { _ = chrome.footReveal }
        chrome.report(RunningHeadState(chapter: 119, progress: 0.205, headOpacity: 1))
        #expect(progress.value && !opacity.value && !foot.value)

        progress = watch { _ = chrome.headProgress(for: 119) }
        opacity = watch { _ = chrome.headOpacity(for: 119) }
        chrome.report(RunningHeadState(chapter: 119, progress: 0.205, headOpacity: 1))
        #expect(!progress.value && !opacity.value)

        chrome.report(RunningHeadState(chapter: 119, progress: 0.205, headOpacity: 0.6))
        #expect(opacity.value && !progress.value)

        progress = watch { _ = chrome.headProgress(for: 119) }
        foot = watch { _ = chrome.footReveal }
        chrome.reportFoot(0.5)
        #expect(foot.value && !progress.value && chrome.footReveal == 0.5)
        foot = watch { _ = chrome.footReveal }
        chrome.textChanged()
        #expect(foot.value && chrome.footReveal == 0 && !progress.value)

        opacity = watch { _ = chrome.headOpacity(for: 119) }
        chrome.bookChanged()
        #expect(opacity.value && progress.value)
        #expect(chrome.headOpacity(for: 119) == 0 && chrome.headProgress(for: 119) == 0 && chrome.head == nil)
    }

    /// Final review M1: the Mac thumb's reveal is the chrome's too, observed on its own: a scroll
    /// bringing the track out invalidates the thumb, not the head or the foot, and a report of
    /// what already shows invalidates nothing.
    @Test func theThumbsRevealInvalidatesOnlyTheThumb() {
        let chrome = ReaderChrome()
        chrome.report(RunningHeadState(chapter: 119, progress: 0.2, headOpacity: 1))
        #expect(!chrome.thumbRevealed)
        var thumb = watch { _ = chrome.thumbRevealed }
        let progress = watch { _ = chrome.headProgress(for: 119) }
        let opacity = watch { _ = chrome.headOpacity(for: 119) }
        let foot = watch { _ = chrome.footReveal }
        chrome.reportThumbReveal(true)
        #expect(thumb.value && chrome.thumbRevealed)
        #expect(!progress.value && !opacity.value && !foot.value)
        thumb = watch { _ = chrome.thumbRevealed }
        chrome.reportThumbReveal(true)
        #expect(!thumb.value, "already out")
        chrome.reportThumbReveal(false)
        #expect(thumb.value && !chrome.thumbRevealed)
    }

    /// A chapter's links ("Previous: Psalm 72", "Next: Psalm 74") show as the space reserved for
    /// them under every chapter's text comes into view, and only then take clicks and VoiceOver;
    /// never when the chapter has neither.
    @Test func theChapterLinksShowAsTheChaptersFootComesIntoView() {
        #expect(ReaderView.footOpacity(reveal: 0, hasLinks: true) == 0)
        #expect(ReaderView.footOpacity(reveal: 0.4, hasLinks: true) == 0.4)
        #expect(ReaderView.footOpacity(reveal: 1, hasLinks: true) == 1)
        #expect(ReaderView.footOpacity(reveal: 1, hasLinks: false) == 0)
        #expect(!ReaderView.footIsLive(opacity: 0.4) && ReaderView.footIsLive(opacity: 0.6))
    }

    #if os(macOS)
    private typealias F = ControllerFixture

    private func show(_ controller: ChapterTextController, _ layout: BookLayout) {
        controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: .none)
    }

    /// The pointer within 40 points of the reader's right edge brings the thumb out, followed in
    /// AppKit over the text; away from the edge, or out of the reader, it goes after the linger.
    @Test func thePointerNearTheRightEdgeBringsTheThumbOut() throws {
        let controller = F.makeController(width: 900, height: 400)
        let window = NSWindow(contentRect: NSRect(x: -3000, y: 0, width: 900, height: 400), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = controller.scrollView
        let tracker = controller.thumbReveal
        tracker.linger = 0.05
        #expect(controller.scrollView.trackingAreas.contains { $0.owner === tracker })
        var reports: [Bool] = []
        tracker.onChange = { reports.append($0) }

        func event(_ type: NSEvent.EventType, x: CGFloat) throws -> NSEvent {
            let point = controller.scrollView.convert(NSPoint(x: x, y: 200), to: nil)
            if type == .mouseMoved {
                return try #require(NSEvent.mouseEvent(with: .mouseMoved, location: point, modifierFlags: [], timestamp: 0,
                                                       windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                                       clickCount: 0, pressure: 0))
            }
            return try #require(NSEvent.enterExitEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                                                       windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                                       trackingNumber: 0, userData: nil))
        }

        tracker.mouseMoved(with: try event(.mouseMoved, x: 450))
        #expect(!tracker.isPointerNearEdge && !tracker.isRevealed, "the middle of the page")
        tracker.mouseMoved(with: try event(.mouseMoved, x: 880))
        #expect(tracker.isPointerNearEdge && tracker.isRevealed, "20 points from the right edge")
        tracker.mouseMoved(with: try event(.mouseMoved, x: 700))
        #expect(!tracker.isPointerNearEdge)
        #expect(tracker.isRevealed, "it lingers")
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        #expect(!tracker.isRevealed, "and goes")

        tracker.mouseEntered(with: try event(.mouseEntered, x: 870))
        #expect(tracker.isRevealed)
        tracker.mouseExited(with: try event(.mouseExited, x: 905))
        #expect(!tracker.isPointerNearEdge)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        #expect(!tracker.isRevealed, "out of the reader")
        #expect(reports == [true, false, true, false])
    }

    /// Matt, 2026-11-13: the thumb shows on hover and after a landing, never for a scroll. A
    /// landing brings it out for the linger (two and a half seconds; one was too short); the
    /// clip moved as a wheel or the scroller would leaves it hidden.
    @Test func aLandingBringsTheThumbOutAndAScrollDoesNot() {
        #expect(ThumbRevealTracker().linger == 2.5)
        let controller = F.makeController(width: 900, height: 300)
        let tracker = controller.thumbReveal
        tracker.linger = 0.1
        show(controller, F.book(1...1, counts: [1: 40]))
        F.sizeToContent(controller)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        #expect(!tracker.isRevealed)
        F.scroll(controller, toY: 120)
        #expect(controller.scrollView.contentView.bounds.minY == 120)
        #expect(!tracker.isRevealed, "a scroll never brings it out")
        controller.update(layout: F.book(1...1, counts: [1: 40]), typography: .default,
                          scrollTarget: ScrollTarget(chapter: 1, verse: 20), decorations: .none)
        #expect(tracker.isRevealed, "a landing does")
        RunLoop.main.run(until: Date().addingTimeInterval(0.06))
        F.scroll(controller, toY: 240)
        #expect(tracker.isRevealed, "it lingers through a scroll")
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        #expect(!tracker.isRevealed, "gone the linger after the landing")
    }

    /// Final review M2: one hiding timer, made once and moved on: the same timer through every
    /// landing, the hide that follows, and the next landing.
    @Test func everyLandingMovesTheSameHidingTimer() throws {
        let tracker = ThumbRevealTracker()
        tracker.linger = 0.1
        tracker.landed()
        let timer = try #require(tracker.hide)
        for _ in 0..<20 {
            tracker.landed()
            #expect(tracker.hide === timer)
        }
        #expect(timer.isValid && tracker.isRevealed)
        let fire = timer.fireDate.timeIntervalSinceNow
        #expect(fire > 0.05 && fire <= 0.1, "a linger from the last landing: \(fire)")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        #expect(!tracker.isRevealed, "gone after the last landing's linger")
        #expect(tracker.hide === timer && timer.isValid, "and the timer waits for the next one")
        tracker.landed()
        #expect(tracker.isRevealed && tracker.hide === timer)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        #expect(!tracker.isRevealed)
    }

    /// The thumb sits just inside the vertical scroller: the reader's trailing edge less the
    /// scroller's width in the style the system prefers now.
    @Test func theThumbSitsInsideTheScroller() {
        #expect(ReaderView.thumbTrailingInset
                == NSScroller.scrollerWidth(for: .regular, scrollerStyle: NSScroller.preferredScrollerStyle))
    }

    /// The middle of the last line of `section`'s opening, in the text view's coordinates.
    private func openingLastLineMidY(_ controller: ChapterTextController, _ section: BookSection) throws -> CGFloat {
        let textView = controller.textView
        let storage = try #require(textView.textContentStorage)
        let layoutManager = try #require(textView.textLayoutManager)
        let location = try #require(storage.location(storage.documentRange.location, offsetBy: NSMaxRange(section.openingRange) - 1))
        let fragment = try #require(layoutManager.textLayoutFragment(for: location))
        let line = try #require(fragment.textLineFragments.last)
        return fragment.layoutFragmentFrame.minY + line.typographicBounds.midY + textView.textContainerInset.height
    }

    /// Chapter 1 with chapter notes carries a mark at the trailing end of its opening's line (the
    /// title block's CHAPTER 1); without, it carries none. The mark follows a count change and a
    /// reflow, and VoiceOver finds it among the text's children. (A later chapter's page has no
    /// label to carry one: `aLaterChaptersMarkIsTheRunningHeads`.)
    @Test func chapterOneWithChapterNotesCarriesAMarkOnItsOpeningLine() throws {
        let chapter = 1
        let controller = F.makeController(width: 900, height: 400)
        let layout = F.book(chapter...chapter, counts: [chapter: 6])
        show(controller, layout)
        controller.chapterNoteCounts = [chapter: 12]
        #expect(Set(controller.chapterNoteMarkViews.keys) == [chapter])

        func expectOnOpeningLine() throws {
            let inset = controller.textView.textContainerInset.width
            let column = try #require(controller.textView.textContainer?.size.width)
            let view = try #require(controller.chapterNoteMarkViews[chapter])
            let section = try #require(layout.section(for: chapter))
            #expect(abs(view.frame.maxX - (inset + column)) < 1)
            #expect(abs(view.frame.midY - (try openingLastLineMidY(controller, section))) < 1)
            #expect(view.frame.width > 0 && view.frame.height > 0)
        }
        try expectOnOpeningLine()
        #expect(controller.chapterNoteMarkViews[chapter]?.rootView.count == 12)
        let children = controller.textView.accessibilityChildren() ?? []
        #expect(children.contains { ($0 as? NSView) === controller.chapterNoteMarkViews[chapter] })

        controller.chapterNoteCounts = [chapter: 3]
        #expect(controller.chapterNoteMarkViews[chapter]?.rootView.count == 3)
        #expect(controller.textView.subviews.filter { $0 is ChapterTextController.NoteMarkView }.count == 1)

        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 520, height: 400)
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.flushPendingReflow()
        try expectOnOpeningLine()

        controller.chapterNoteCounts = [:]
        #expect(controller.chapterNoteMarkViews.isEmpty)
        #expect(controller.textView.subviews.filter { $0 is ChapterTextController.NoteMarkView }.isEmpty)
    }

    /// Matt, 2026-11-13: a later chapter has no label on the page, and its running head, shown
    /// from the top, carries the chapter-note mark. The page's own mark is kept (its count
    /// follows) but never shown beside it: hidden at rest at the top, through a count change, a
    /// reflow and a scroll, and out of VoiceOver's reach, so the mark is never doubled.
    @Test func aLaterChaptersMarkIsTheRunningHeads() throws {
        let chapter = 3
        let controller = F.makeController(width: 900, height: 400)
        let layout = F.book(chapter...chapter, counts: [chapter: 30])
        show(controller, layout)
        #expect(controller.runningHead?.chapter == chapter && controller.runningHead?.headOpacity == 1)
        controller.chapterNoteCounts = [chapter: 12]
        #expect(Set(controller.chapterNoteMarkViews.keys) == [chapter])

        func expectLeftToTheHead(_ when: String) throws {
            let view = try #require(controller.chapterNoteMarkViews[chapter])
            #expect(view.isHidden && view.alphaValue == 0, "\(when)")
            let children = controller.textView.accessibilityChildren() ?? []
            #expect(!children.contains { $0 is ChapterTextController.NoteMarkView }, "\(when)")
        }
        try expectLeftToTheHead("at rest at the top")
        #expect(controller.chapterNoteMarkViews[chapter]?.rootView.count == 12)

        controller.chapterNoteCounts = [chapter: 3]
        #expect(controller.chapterNoteMarkViews[chapter]?.rootView.count == 3)
        #expect(controller.textView.subviews.filter { $0 is ChapterTextController.NoteMarkView }.count == 1)
        try expectLeftToTheHead("after a count change")

        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 520, height: 400)
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.flushPendingReflow()
        try expectLeftToTheHead("after a reflow")

        F.scroll(controller, toY: try #require(controller.chapterBand).openingMaxY + 200)
        try expectLeftToTheHead("scrolled")
        F.scroll(controller, toY: 0)
        try expectLeftToTheHead("back at the top")

        controller.chapterNoteCounts = [:]
        #expect(controller.chapterNoteMarkViews.isEmpty)
        #expect(controller.textView.subviews.filter { $0 is ChapterTextController.NoteMarkView }.isEmpty)
    }

    /// The mark shows its own chapter's notes.
    @Test func aChapterNoteMarkReportsItsOwnChapter() throws {
        var shown: [Int] = []
        let controller = F.makeController(width: 900, height: 400)
        controller.onShowChapterNotes = { shown.append($0) }
        show(controller, F.book(3...3, counts: [3: 6]))
        controller.chapterNoteCounts = [3: 1]
        try #require(controller.chapterNoteMarkViews[3]).rootView.action()
        #expect(shown == [3])
    }

    /// Fix round 3: a note's highlight scrolled to reports its own verse, not the verse an earlier
    /// jump landed on.
    @Test func aHighlightScrolledToReportsItsVerse() throws {
        var positions: [VerseLocation] = []
        let controller = F.makeController(width: 700, height: 400) { positions.append($0) }
        controller.headLineY = 46
        let layout = F.book(2...2, counts: [2: 60])
        let item = MarkupItem(id: UUID(), chapter: 2, verse: 40, endVerse: 40, startOffset: 0, endOffset: 5,
                              translationID: "WEB", color: MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00"), hasNote: true)
        var decorations = F.decorations([item], layout: layout)
        controller.update(layout: layout, typography: .default, scrollTarget: ScrollTarget(chapter: 2, verse: 5), decorations: decorations)
        #expect(positions.last == VerseLocation(book: "MAT", chapter: 2, verse: 5))
        decorations.outlinedID = item.id
        controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: decorations)
        #expect(controller.runningHead?.chapter == 2)
        #expect(positions.last == VerseLocation(book: "MAT", chapter: 2, verse: 40))
    }

    /// The space reserved under a chapter's text is revealed only at the foot of its page, so its
    /// links never lie over the text mid-way through the chapter.
    @Test func theChaptersFootIsRevealedOnlyAtItsFoot() {
        var reveals: [Double] = []
        let controller = F.makeController(width: 700, height: 400)
        controller.onFootReveal = { reveals.append($0) }
        controller.bottomInset = 40
        let layout = F.book(2...2, counts: [2: 30])
        controller.update(layout: layout, typography: .default, scrollTarget: ScrollTarget(chapter: 2, verse: 10), decorations: .none)
        #expect(controller.footReveal == 0)
        let maxY = controller.scrollView.documentView!.frame.height - controller.scrollView.contentView.bounds.height
        F.scroll(controller, toY: maxY - 20)
        #expect(abs(controller.footReveal - 0.5) < 0.01)
        F.scroll(controller, toY: maxY)
        #expect(controller.footReveal == 1 && reveals.last == 1)
        F.scroll(controller, toY: maxY - 200)
        #expect(controller.footReveal == 0 && reveals.last == 0)
    }

    /// The reader view forgets the reveal whenever the text changes, so every new text (another
    /// chapter, another translation) reports its reveal afresh even when it equals the last
    /// (Psalm 117 into Psalm 118's opening, both fitting the window); a reflow of the same text
    /// reports only a change.
    @Test func everyNewTextReportsItsFootAfresh() {
        var reveals: [Double] = []
        let controller = F.makeController(width: 700, height: 400)
        controller.onFootReveal = { reveals.append($0) }
        controller.bottomInset = 40
        controller.update(layout: F.book(2...2, counts: [2: 2]), typography: .default, scrollTarget: nil, decorations: .none)
        #expect(reveals == [1])
        controller.update(layout: F.book(3...3, counts: [3: 2]), typography: .default, scrollTarget: nil, decorations: .none)
        #expect(reveals == [1, 1])
        controller.update(layout: F.book(3...3, counts: [3: 2], translation: "KJV"), typography: .default, scrollTarget: nil, decorations: .none)
        #expect(reveals == [1, 1, 1])
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 520, height: 400)
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.flushPendingReflow()
        #expect(reveals == [1, 1, 1])
    }

    /// The scroller's track starts under the whole head (strip, progress line and fade), so the
    /// head never covers its knob or takes its clicks.
    @Test func theScrollerStartsBelowTheHead() {
        let controller = F.makeController()
        let typography = ReaderTypography.default
        controller.scrollerTopInset = RunningHeadView.height(for: typography)
        #expect(controller.scrollView.scrollerInsets.top == RunningHeadView.height(for: typography))
        #expect(RunningHeadView.height(for: typography)
            == RunningHeadView.stripHeight(for: typography) + ReadingProgressLine.height + RunningHeadView.fadeHeight)
    }

    /// When the links stack (long names at the narrowest column the Mac allows, 200 pt), the foot
    /// keeps room for both rows: in the reader as laid out, the space kept under the chapter's
    /// last line is at least the links' height as `ChapterEndLinks` lays them out at that column,
    /// so the links laid over the foot never cover the last line. A wide reader keeps one row.
    @Test func theFootKeepsRoomForTheLinksWhenTheyStack() throws {
        let previous = "Song of Solomon 8", next = "Isaiah 1"
        let links = NSHostingController(rootView: ChapterEndLinks(previousTitle: previous, nextTitle: next, onPrevious: {}, onNext: {}))
        let row = links.sizeThatFits(in: CGSize(width: 2000, height: CGFloat.greatestFiniteMagnitude)).height
        let stacked = links.sizeThatFits(in: CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude)).height
        #expect(stacked >= 2 * row + AppSpacing.xs - 0.5, "they stack at 200 pt: \(stacked) against \(row)")

        let verses = (1...40).map {
            Verse(id: VerseLocation(book: "SNG", chapter: 8, verse: $0), translationID: "WEB",
                  text: "Verse \($0) of the song says enough words to wrap onto a second line in a column.", breakAfter: $0 % 4 == 0)
        }
        let document = ReaderDocument(store: try FixtureStore.make())
        document.show(BookText(book: "SNG", translationID: "WEB", chapters: [8: verses]), target: ChapterLocation(book: "SNG", chapter: 8),
                      typography: .default)
        for (width, expected) in [(200 + 2 * ChapterTextController.horizontalInset, stacked), (1000, row)] {
            let reader = ReaderView(document: document, scrollTarget: ScrollTarget(chapter: 8, verse: 1), onReadingPositionChange: { _ in },
                                    onHeadingTap: {}, previousChapterTitle: previous, onPreviousChapter: {},
                                    nextChapterTitle: next, onNextChapter: {})
            let window = NSWindow(contentRect: NSRect(x: -3000, y: 0, width: width, height: 600), styleMask: [.borderless],
                                  backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            let host = NSHostingView(rootView: reader)
            window.contentView = host
            // The links' height is measured in one pass and handed to the text's foot in the next.
            for _ in 0..<5 {
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
            let scrollView = try #require(Self.descendant(of: host, NSScrollView.self))
            let documentView = try #require(scrollView.documentView)
            let textView = try #require(Self.descendant(of: documentView, NSTextView.self))
            let usage = try #require(textView.textLayoutManager?.usageBoundsForTextContainer)
            let lastLine = textView.convert(NSPoint(x: 0, y: textView.textContainerOrigin.y + usage.maxY), to: documentView).y
            let kept = documentView.frame.height - lastLine - ChapterTextController.verticalInset
            #expect(kept >= expected - 0.5, "\(width) pt: \(kept) kept under the last line, the links \(expected)")
            #expect(kept < expected + AppSpacing.sm, "\(width) pt: no more than the links take")
        }
    }

    private static func descendant<V: NSView>(of view: NSView, _ type: V.Type) -> V? {
        for subview in view.subviews {
            if let match = subview as? V ?? descendant(of: subview, type) { return match }
        }
        return nil
    }

    /// Every chapter with a link to follow (the first, a middle one, the last) reserves the links'
    /// height below its text, so the links laid over the scroll's foot never cover the last line
    /// and showing them never changes where the end is; a chapter with neither link reserves none.
    @Test func theFootReservesTheLinksHeightInEveryChapter() {
        #expect(ReaderView.bottomInset(hasLinks: true) == ReaderView.footHeight)
        #expect(ReaderView.bottomInset(hasLinks: false) == 0)
        #expect(ReaderView.footHeight > 2 * AppSpacing.sm)
        // Stacked links keep their two rows; nothing is kept with no link, however measured.
        #expect(ReaderView.bottomInset(hasLinks: true, linksHeight: 2 * ReaderView.footHeight + 7.6) == ceil(2 * ReaderView.footHeight + 7.6))
        #expect(ReaderView.bottomInset(hasLinks: false, linksHeight: 100) == 0)
        let controller = F.makeController()
        controller.bottomInset = ReaderView.bottomInset(hasLinks: true)
        for chapter in [1, 14, 28] {
            controller.update(layout: F.book(chapter...chapter, counts: [chapter: 20]), typography: .default, scrollTarget: nil, decorations: .none)
            // The top inset holds a later chapter's room for the head; the foot keeps the page's own inset.
            let textHeight = ceil(controller.textView.textLayoutManager!.usageBoundsForTextContainer.maxY
                + controller.textView.textContainerInset.height + ChapterTextController.verticalInset)
            #expect(abs(controller.scrollView.documentView!.frame.height - (textHeight + ReaderView.footHeight)) < 1, "chapter \(chapter)")
        }
        let height = controller.scrollView.documentView!.frame.height
        controller.bottomInset = 0
        #expect(abs(controller.scrollView.documentView!.frame.height - (height - ReaderView.footHeight)) < 1)
    }

    /// During the title block's morph the in-text mark beside its label (chapter 1's CHAPTER 1)
    /// fades with the label, so it never doubles the head's own mark. A later chapter has no
    /// label (Matt, 2026-11-13): its head is shown from the top, so its in-text mark is never
    /// shown at all.
    @Test func theTitleBlocksChapterNoteMarkFadesWithItsLabel() throws {
        let controller = F.makeController(width: 900, height: 400)
        controller.headLineY = 46
        let layout = F.book(1...1, counts: [1: 30])
        show(controller, layout)
        controller.chapterNoteCounts = [1: 1]
        let band = try #require(controller.chapterBand)
        // The head's line 30 pt above the end of the title block: halfway through the fade.
        let y = band.openingMaxY - RunningHead.fadeDistance / 2 - 46 - ChapterTextController.scrollLeadIn - 0.5
        F.scroll(controller, toY: y)
        let alpha = controller.openingLabelAlpha
        #expect(alpha > 0.3 && alpha < 0.7)
        let one = try #require(controller.chapterNoteMarkViews[1])
        #expect(abs(one.alphaValue - alpha) < 0.01)
        F.scroll(controller, toY: band.openingMaxY + 200)
        #expect(one.alphaValue == 0 && one.isHidden)
        F.scroll(controller, toY: 0)
        #expect(one.alphaValue == 1 && !one.isHidden)
        // A later chapter's mark has no label to fade with: the head carries the mark from the
        // top, so the page's is hidden there, scrolled, and back at the top.
        show(controller, F.book(2...2, counts: [2: 30]))
        controller.chapterNoteCounts = [2: 1]
        let two = try #require(controller.chapterNoteMarkViews[2])
        #expect(controller.runningHead?.headOpacity == 1 && controller.openingLabelAlpha == 0)
        #expect(two.alphaValue == 0 && two.isHidden)
        F.scroll(controller, toY: try #require(controller.chapterBand).openingMaxY + 200)
        #expect(two.alphaValue == 0 && two.isHidden)
        F.scroll(controller, toY: 0)
        #expect(controller.runningHead?.headOpacity == 1)
        #expect(two.alphaValue == 0 && two.isHidden)
        // Back on chapter 1, the mark shows beside its label again.
        show(controller, layout)
        controller.chapterNoteCounts = [1: 1]
        let again = try #require(controller.chapterNoteMarkViews[1])
        #expect(again.alphaValue == 1 && !again.isHidden)
    }

    /// Matt, 2026-11-13 (superseding spec 4.2's "every chapter opens as chapter 1 does"): a later
    /// chapter shown alone (John 3; Psalm 119, the long one) has no label and no air above it.
    /// At rest at its top the head is fully shown, naming it, and the chapter's hairline opening
    /// rests right under the head, a landed line's lead-in below the strip (never above the
    /// page's inset), its first line of text at the hairline; no line of the chapter (the
    /// hairline, Lectern's numeral's top, the first line of text) sits under the head's strip.
    /// The head stays fully shown as the page scrolls. In every page style, at the smallest,
    /// default and largest sizes.
    @Test(arguments: [PageStyle.printed, .lectern, .classic, .study])
    func aLaterChapterOpensRightUnderTheHeadWhichShowsFromTheTop(style: PageStyle) throws {
        let psalm119 = try BenchmarkChapter.psalm119()
        for size in [14.0, 18.0, 28.0] {
            var prefs = ReaderPreferences(style: style)
            prefs.fontSize = size
            let typography = ReaderTypography.styled(prefs)
            let john3 = JohnFixture.layout(3...3, style: style) { $0.fontSize = size }
            let psalm = BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: "PSA", chapter: 119), verses: psalm119)],
                                         opening: BookOpening(bookName: "Psalms", title: BookTitle(title: "Psalms", subtitle: nil)),
                                         typography: typography)
            for layout in [john3, psalm] {
                let label = "\(style) \(size) \(layout.sections[0].location.chapter)"
                let controller = F.makeController(width: 900, height: 600)
                let strip = RunningHeadView.stripHeight(for: typography)
                controller.headLineY = strip
                controller.update(layout: layout, typography: typography, scrollTarget: ScrollTarget(chapter: layout.sections[0].location.chapter, verse: 1),
                                  decorations: .none)
                let section = layout.sections[0]
                let inset = controller.textView.textContainerInset.height
                #expect(controller.scrollView.contentView.bounds.minY == 0, "\(label)")
                #expect(controller.runningHead?.headOpacity == 1 && controller.runningHead?.chapter == section.location.chapter,
                        "\(label): shown at rest at the top")
                #expect(controller.openingLabelAlpha == 0, "\(label)")
                let rest = max(ChapterTextController.verticalInset, strip + ChapterTextController.scrollLeadIn)
                #expect(inset == rest, "\(label): the inset \(inset), the head's room \(rest)")
                let opening = try #require(controller.lineFrame(forCharacterIndex: section.openingRange.location))
                let text = try #require(controller.lineFrame(forCharacterIndex: section.spans[0].textRange.location))
                #expect(layout.attributedString.readerRole(at: section.openingRange.location)
                        == (style == .lectern ? .dropNumeral(section.location.chapter) : .chapterStart(section.location.chapter)), "\(label)")
                #expect(abs(opening.minY + inset - rest) < 0.5, "\(label): the opening at \(opening.minY + inset), right under the head at \(rest)")
                #expect(opening.height <= 1.5 && abs(text.minY - opening.maxY) < 0.5, "\(label): the text starts at the hairline, no label and no air")
                #expect(opening.minY + inset >= strip, "\(label): the opening at \(opening.minY + inset), the strip to \(strip)")
                #expect(text.minY + inset >= strip, "\(label): the first line at \(text.minY + inset)")
                if style == .lectern {
                    let numeral = try #require(controller.numeralView, "\(label)")
                    #expect(numeral.chapter == section.location.chapter && numeral.ink.minY >= strip, "\(label): the numeral's top at \(numeral.ink.minY)")
                } else {
                    #expect(controller.numeralView == nil, "\(label)")
                }
                // The head never fades: a point down, the opening's end past the head's line, and well into the text.
                let band = try #require(controller.chapterBand)
                let fadeEnd = max(band.openingMaxY, strip + ChapterTextController.scrollLeadIn + RunningHead.headLineTolerance + RunningHead.minimumFade)
                for y in [1, fadeEnd + 1 - strip - ChapterTextController.scrollLeadIn, band.openingMaxY + 200] {
                    F.scroll(controller, toY: y)
                    #expect(controller.runningHead?.headOpacity == 1 && controller.runningHead?.chapter == section.location.chapter, "\(label) at \(y)")
                }
                F.scroll(controller, toY: 0)
                #expect(controller.runningHead?.headOpacity == 1, "\(label): back at the top")
            }
        }
    }
    /// The marks name their chapter for VoiceOver and the help tag.
    @Test func aMarkNamesItsChapter() {
        let controller = F.makeController(width: 900, height: 400)
        show(controller, F.book(2...2, counts: [2: 4]))
        controller.chapterNoteCounts = [2: 2]
        #expect(controller.chapterNoteMarkViews[2]?.rootView.chapter == "Matthew 2")
    }

    /// The headings rotor walks the book's title, the chapter's opening and its section headings
    /// in text order, forwards and back, and filters by what VoiceOver types.
    @Test func theHeadingsRotorVisitsTitlesLabelsAndSectionHeadings() throws {
        let controller = F.makeController(width: 900, height: 400)
        let headings = [1: [3: [SectionHeading(text: "The Wedding at Cana", level: 1)]]]
        let layout = F.book(1...1, counts: [1: 4], headings: headings)
        show(controller, layout)

        let items = controller.headingItems
        #expect(items.map(\.label) == ["Matthew", "Matthew 1", "The Wedding at Cana"])
        #expect(items.map(\.range.location) == items.map(\.range.location).sorted())
        let text = layout.attributedString.string as NSString
        #expect(text.substring(with: items[1].range) == "CHAPTER 1")
        #expect(text.substring(with: items[2].range) == "The Wedding at Cana")
        // Matt, 2026-11-13: a later chapter has no label, and the rotor still names its opening,
        // at its empty hairline, before its headings.
        let later = F.book(2...2, counts: [2: 4], headings: [2: [1: [SectionHeading(text: "The Visit of the Wise Men", level: 1)]]])
        let laterItems = ChapterTextController.headingItems(in: later)
        #expect(laterItems.map(\.label) == ["Matthew 2", "The Visit of the Wise Men"])
        #expect(laterItems.first?.range == NSRange(location: later.sections[0].openingRange.location, length: 1))
        #expect(later.attributedString.readerRole(at: later.sections[0].openingRange.location) == .chapterStart(2))

        // The system's heading rotor type, so VoiceOver lists it as Headings and its
        // next-heading command (VO-⌘-H) uses it.
        let rotor = try #require(controller.textView.accessibilityCustomRotors().first { $0.type == .heading })
        let delegate = try #require(rotor.itemSearchDelegate)
        let parameters = NSAccessibilityCustomRotor.SearchParameters()
        parameters.searchDirection = .next
        var visited: [NSRange] = []
        while let result = delegate.rotor(rotor, resultFor: parameters) {
            visited.append(result.targetRange)
            parameters.currentItem = result
            if visited.count > items.count { break }
        }
        #expect(visited == items.map(\.range))

        parameters.searchDirection = .previous
        let back = try #require(delegate.rotor(rotor, resultFor: parameters))
        #expect(back.targetRange == items[1].range && back.customLabel == "Matthew 1")
        #expect((back.targetElement as? NSView) === controller.textView)

        let filtered = NSAccessibilityCustomRotor.SearchParameters()
        filtered.searchDirection = .next
        filtered.filterString = "cana"
        #expect(delegate.rotor(rotor, resultFor: filtered)?.targetRange == items[2].range)
    }
    #endif
}
