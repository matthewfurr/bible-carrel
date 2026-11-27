#if os(macOS)
import AppKit
import BibleImporterCore
import Foundation
// Only the hosting view: SwiftUI's own `ScrollTarget` would shadow the reader's.
import class SwiftUI.NSHostingView
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

/// Psalm 119 (176 verses, each its own paragraph in the KJV) is the spec's long-chapter benchmark. Each ceiling is twice
/// the debug-build median (load 14.7 ms, scroll 4.3 ms, decoration change 1.3 ms) rounded up to 50 ms, with a 100 ms
/// floor so a busy machine does not flake: a regression of several times fails the suite. The reader shows one chapter
/// at a time, so Psalm 119 alone is the page; on the real ESV it is `psalm119LoadsWithSixtyHighlightsWithinASecond`.
@MainActor @Suite(.serialized) struct ReaderBenchmarkTests {
    private func controller(width: CGFloat = 900, height: CGFloat = 700) -> ChapterTextController {
        let controller = ChapterTextController(onReadingPositionChange: { _ in })
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        controller.scrollView.layoutSubtreeIfNeeded()
        return controller
    }

    /// Psalm 119 in the KJV fixture, as the controller shows a chapter.
    private func psalm119Layout() throws -> BookLayout {
        let verses = try BenchmarkChapter.psalm119()
        #expect(verses.count == 176)
        return BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: "PSA", chapter: 119), verses: verses)],
                                opening: BookOpening(bookName: "Psalms", title: BookTitle(title: "Psalms", subtitle: nil)), typography: .default)
    }

    /// Psalm 119 in the real ESV as the reader builds it: the book read from the store, then
    /// `ReaderDocument` laying out the chapter alone with the book's title and headings.
    static func psalm119(store: BibleStore, typography: ReaderTypography) throws -> BookLayout {
        let book = BookText(book: "PSA", translationID: "ESV", chapters: try store.bookChapters("PSA", translationID: "ESV"))
        let document = ReaderDocument(store: store)
        document.show(book, target: ChapterLocation(book: "PSA", chapter: 119), typography: typography)
        let layout = try #require(document.layout)
        #expect(layout.chapters == 119...119 && layout.sections[0].spans.count == 176)
        return layout
    }

    /// Sixty highlights of a few words each, spread through the section's verses, ten of them overlapping.
    static func decorations(in section: BookSection) -> BookDecorations {
        BenchmarkChapter.sixtyHighlights(in: section)
    }

    static func measure(_ label: String, _ work: () -> Void) -> Duration {
        let clock = ContinuousClock()
        let elapsed = clock.measure(work)
        print("benchmark \(label) \(elapsed.formatted(.units(allowed: [.milliseconds], fractionalPart: .show(length: 1))))")
        return elapsed
    }

    /// `work`'s value and how long it took, printed. A failure inside is thrown with its own
    /// reason rather than measured as an absent value.
    static func timed<T>(_ label: String, _ work: () throws -> T) rethrows -> (value: T, elapsed: Duration) {
        let clock = ContinuousClock()
        let start = clock.now
        let value = try work()
        let elapsed = clock.now - start
        print("benchmark \(label) \(elapsed.formatted(.units(allowed: [.milliseconds], fractionalPart: .show(length: 1))))")
        return (value, elapsed)
    }

    /// The median of `runs` timings of `work`, each after an untimed `prepare`, printed. A frame
    /// budget is checked against the median: one run can be pushed over by a suite running
    /// alongside, a regression moves them all.
    static func median(_ label: String, runs: Int = 9, prepare: () -> Void = {}, _ work: () -> Void) -> Duration {
        let clock = ContinuousClock()
        let timings = (0..<runs).map { _ in
            prepare()
            return clock.measure(work)
        }.sorted()
        let median = timings[runs / 2]
        print("benchmark \(label) median of \(runs) \(String(format: "%.1f", BookBenchmarkTests.milliseconds(median))) ms")
        return median
    }

    @Test func psalm119LoadsWithSixtyHighlights() throws {
        let layout = try psalm119Layout()
        let decorations = Self.decorations(in: layout.sections[0])
        let controller = controller()
        let elapsed = Self.measure("load", { controller.update(layout: layout, typography: .default, scrollTarget: ScrollTarget(chapter: 119, verse: 1), decorations: decorations) })
        #expect(elapsed < .milliseconds(100))
        #expect(controller.backgroundFills.count >= 60)
    }

    @Test func aHundredScrollTicksReportTheVerse() throws {
        let layout = try psalm119Layout()
        let decorations = Self.decorations(in: layout.sections[0])
        var reported: [VerseLocation] = []
        let controller = controller()
        controller.onReadingPositionChange = { reported.append($0) }
        controller.update(layout: layout, typography: .default, scrollTarget: ScrollTarget(chapter: 119, verse: 1), decorations: decorations)
        let maxY = controller.scrollView.documentView!.frame.height - controller.scrollView.contentView.bounds.height
        let elapsed = Self.measure("scroll×100", {
            for tick in 1...100 {
                controller.scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY * CGFloat(tick) / 100))
                controller.scrollView.reflectScrolledClipView(controller.scrollView.contentView)
            }
        })
        #expect(elapsed < .milliseconds(100))
        // At the bottom the first visible verse is the top of the last screenful, not verse 176:
        // the hundred ticks must move forward only and land where a single jump there lands.
        var jumped: VerseLocation?
        let bottom = self.controller()
        bottom.onReadingPositionChange = { jumped = $0 }
        bottom.update(layout: layout, typography: .default, scrollTarget: ScrollTarget(chapter: 119, verse: 1), decorations: decorations)
        bottom.scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY))
        bottom.scrollView.reflectScrolledClipView(bottom.scrollView.contentView)
        #expect(reported.count > 1)
        #expect(reported.map(\.verse) == reported.map(\.verse).sorted())
        #expect(jumped != nil && jumped?.verse != 1 && reported.last == jumped)
    }

    @Test func recolouringOneHighlightIsCheap() throws {
        let layout = try psalm119Layout()
        var decorations = Self.decorations(in: layout.sections[0])
        let controller = controller()
        controller.update(layout: layout, typography: .default, scrollTarget: ScrollTarget(chapter: 119, verse: 1), decorations: decorations)
        decorations.outlinedID = decorations.highlights[30].id
        let elapsed = Self.measure("decoration change", { controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: decorations) })
        #expect(elapsed < .milliseconds(100))
    }

    /// The spec's budget (section 6, item 4): Psalm 119 in ESV at 18 pt with sixty highlights
    /// appears within a second. On the real bundle (skipped without `Build/bible.sqlite`,
    /// `.needsRealBible`): the book is read, the document lays Psalm 119 out alone, the
    /// controller lays it out and lands on its first verse with its highlights painted. Then a
    /// hundred scroll ticks through it, printed, ending at the page's foot.
    @Test(.needsRealBible) func psalm119LoadsWithSixtyHighlightsWithinASecond() throws {
        let store = try BenchmarkChapter.realStore()
        let typography = ReaderTypography.default
        let (layout, build) = try Self.timed("psalm119-document-build") { try Self.psalm119(store: store, typography: typography) }
        let decorations = Self.decorations(in: layout.sections[0])
        #expect(decorations.highlights.count >= 60)
        var reported: [VerseLocation] = []
        let controller = controller()
        controller.onReadingPositionChange = { reported.append($0) }
        controller.bottomInset = ReaderView.footHeight
        let load = Self.measure("psalm119-load", {
            controller.update(layout: layout, typography: typography, scrollTarget: ScrollTarget(chapter: 119, verse: 1), decorations: decorations)
        })
        print("benchmark psalm119-total \(String(format: "%.1f", BookBenchmarkTests.milliseconds(build + load))) ms")
        #expect(build + load < .seconds(1))
        #expect(reported == [VerseLocation(book: "PSA", chapter: 119, verse: 1)])
        #expect(controller.backgroundFills.filter { $0.id != nil }.count >= 60)

        let maxY = controller.scrollView.documentView!.frame.height - controller.scrollView.contentView.bounds.height
        let scroll = Self.measure("psalm119-scroll×100", {
            for tick in 1...100 {
                controller.scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY * CGFloat(tick) / 100))
                controller.scrollView.reflectScrolledClipView(controller.scrollView.contentView)
            }
        })
        #expect(scroll < .milliseconds(200))
        // At the foot the head names Psalm 119, read through.
        #expect(controller.runningHead?.chapter == 119 && controller.runningHead?.progress == 1)
        #expect(controller.footReveal == 1)
    }

    /// The median and 95th percentile, in milliseconds, of three hundred 12-point scroll frames
    /// down Psalm 119 (real ESV) from verse 1 in a real window, drawing included, after thirty
    /// untimed frames that warm the window up.
    private func scrollFrames(_ style: PageStyle, decorations: (BookSection) -> BookDecorations, store: BibleStore) throws -> (median: Double, p95: Double) {
        let typography = ReaderTypography.styled(ReaderPreferences(style: style))
        let layout = try Self.psalm119(store: store, typography: typography)
        let controller = ChapterTextController(onReadingPositionChange: { _ in })
        let window = NSWindow(contentRect: NSRect(x: -3000, y: 0, width: 900, height: 800), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = controller.scrollView
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.headLineY = RunningHeadView.stripHeight(for: typography)
        controller.bottomInset = ReaderView.footHeight
        controller.update(layout: layout, typography: typography, scrollTarget: ScrollTarget(chapter: 119, verse: 1),
                          decorations: decorations(layout.sections[0]))
        #expect((controller.numeralView != nil) == (style == .lectern), "\(style)")
        func frame(_ y: CGFloat) {
            controller.scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
            controller.scrollView.reflectScrolledClipView(controller.scrollView.contentView)
            window.layoutIfNeeded()
            window.displayIfNeeded()
            CATransaction.flush()
        }
        window.displayIfNeeded()
        let start = controller.scrollView.contentView.bounds.minY
        for tick in 1...30 { frame(start + CGFloat(tick) * 12) }
        frame(start)
        let clock = ContinuousClock()
        let frames = (1...300).map { tick in
            BookBenchmarkTests.milliseconds(clock.measure { frame(start + CGFloat(tick) * 12) })
        }.sorted()
        return (frames[150], frames[285])
    }

    /// Matt's report (2026-11-12): scrolling Lectern was choppy on the Mac. In a real window,
    /// drawing included, a scroll frame of Psalm 119 (real ESV) costs under a millisecond at the
    /// median in Printed and in Lectern, whose one numeral is a small view of its own (the spec's
    /// baseline is 0.65 ms). With sixty highlights painted, printed beside, Lectern still costs
    /// about what Printed does: within three times Printed's plus a millisecond (relative, so a
    /// busy machine slows both alike).
    @Test(.needsRealBible) func aScrollFrameOfPsalm119CostsUnderAMillisecond() throws {
        let store = try BenchmarkChapter.realStore()
        var marked: [PageStyle: Double] = [:]
        for style in [PageStyle.printed, .lectern] {
            let plain = try scrollFrames(style, decorations: { _ in .none }, store: store)
            print("benchmark \(style)-psalm119-scroll-frame median \(String(format: "%.2f", plain.median)) ms, p95 \(String(format: "%.2f", plain.p95)) ms")
            #expect(plain.median < 1, "\(style): \(plain.median) ms a frame")
            let highlighted = try scrollFrames(style, decorations: Self.decorations(in:), store: store)
            print("benchmark \(style)-psalm119-scroll-frame-sixty-highlights median \(String(format: "%.2f", highlighted.median)) ms, p95 \(String(format: "%.2f", highlighted.p95)) ms")
            marked[style] = highlighted.median
        }
        let printed = try #require(marked[.printed]), lectern = try #require(marked[.lectern])
        #expect(lectern < printed * 3 + 1, "Lectern \(lectern) ms a frame against Printed's \(printed)")
    }

    /// Scroll frames down Psalm 119 (real ESV) in a real window, drawing included, as
    /// `scrollFrames` measures them, with the book thumb laid over the reader's right edge as
    /// the Mac hosts it: Psalms' track in a hosting view, revealed by the controller's
    /// `ThumbRevealTracker` (brought out as a landing does), handed over on the next turn of the main queue as
    /// `ChapterTextView` does. Without `thumb` the track is there but never revealed.
    ///
    /// Each frame is the scroll, its layout and drawing, and then whatever main-actor work is
    /// due: the test yields the main actor once inside the timing (a spun run loop would not
    /// drain the main queue the test runs on), so work queued since the last frame (the reveal,
    /// a lens being drawn on the main actor) lands in this one. The page is Printed set in
    /// Charter, a look no other test draws lenses in, so its lenses start cold. Thirty frames
    /// warm the window up; then the track is hidden and a hundred and twenty timed frames start
    /// from rest, the first of them revealing the track.
    private func thumbScrollFrames(thumb: Bool, store: BibleStore) async throws -> (median: Double, upperQuartile: Double, max: Double) {
        let typography = ReaderTypography.styled(ReaderPreferences(style: .printed, face: .charter))
        let layout = try Self.psalm119(store: store, typography: typography)
        let controller = ChapterTextController(onReadingPositionChange: { _ in })
        let window = NSWindow(contentRect: NSRect(x: -3000, y: 0, width: 900, height: 800), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 800))
        window.contentView = container
        controller.scrollView.frame = container.bounds
        controller.scrollView.autoresizingMask = [.width, .height]
        container.addSubview(controller.scrollView)
        let psalms = BookThumb(chapters: Array(1...150), current: 119)
        func track(revealed: Bool) -> BookThumbView {
            BookThumbView(thumb: psalms, typography: typography, isRevealed: revealed, dragging: .constant(nil), onLand: { _ in })
        }
        let host = NSHostingView(rootView: track(revealed: false))
        host.frame = NSRect(x: 900 - BookThumbView.width - 16, y: 40, width: BookThumbView.width, height: 720)
        container.addSubview(host)
        controller.thumbReveal.linger = 0.05
        controller.thumbReveal.onChange = { revealed in
            DispatchQueue.main.async { host.rootView = track(revealed: thumb && revealed) }
        }
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.headLineY = RunningHeadView.stripHeight(for: typography)
        controller.bottomInset = ReaderView.footHeight
        controller.update(layout: layout, typography: typography, scrollTarget: ScrollTarget(chapter: 119, verse: 1), decorations: .none)
        window.displayIfNeeded()

        let clock = ContinuousClock()
        let start = controller.scrollView.contentView.bounds.minY
        func frame(_ tick: Int) async -> Double {
            let began = clock.now
            controller.scrollView.contentView.scroll(to: NSPoint(x: 0, y: start + CGFloat(tick) * 12))
            controller.scrollView.reflectScrolledClipView(controller.scrollView.contentView)
            window.layoutIfNeeded()
            window.displayIfNeeded()
            CATransaction.flush()
            await Task.yield()
            return BookBenchmarkTests.milliseconds(clock.now - began)
        }
        for tick in 1...30 { _ = await frame(tick) }
        // At rest: the track hidden (the landing's linger over), and any warm it started stopped.
        try await Task.sleep(for: .milliseconds(300))
        #expect(!controller.thumbReveal.isRevealed)
        // The track comes out as for a landing, on the timed scroll's first frame, and stays out
        // through it (a scroll alone never brings it out).
        controller.thumbReveal.linger = 60
        controller.thumbReveal.landed()
        var frames: [Double] = []
        for tick in 31...150 { frames.append(await frame(tick)) }
        #expect(controller.thumbReveal.isRevealed)
        frames.sort()
        return (frames[frames.count / 2], frames[frames.count * 3 / 4], frames[frames.count - 1])
    }

    /// The carried ruling on Task 6: the Mac thumb's track coming out (after a landing, or with
    /// the pointer at the edge) must not cost a scroll. Psalm 119 scrolled with Psalms' thumb revealing from the first
    /// frame costs what the same page costs with its track never shown, at the median and at the
    /// upper quartile: each within a quarter again plus a tenth of a millisecond (relative, so a
    /// busy machine slows both alike). The lenses are not drawn on reveal, and when a grab draws
    /// them their Core Image work is off the main thread. Drawing the whole book on reveal, on
    /// the main actor, cost 1.2-1.5 ms at the median against 0.9 ms and 2.7 ms at the upper
    /// quartile against 1.15 ms; the quartile is the steadier of the two (the lenses meet most
    /// frames but not all, so the median sits near the edge of them). The worst frames are
    /// printed beside.
    @Test(.needsRealBible) func scrollingWhileTheThumbRevealsKeepsTheFrameCost() async throws {
        let store = try BenchmarkChapter.realStore()
        let plain = try await thumbScrollFrames(thumb: false, store: store)
        let revealing = try await thumbScrollFrames(thumb: true, store: store)
        for (label, frames) in [("hidden", plain), ("revealing", revealing)] {
            print("benchmark psalm119-scroll-frame-thumb-\(label) median \(String(format: "%.2f", frames.median)) ms, "
                + "upper quartile \(String(format: "%.2f", frames.upperQuartile)) ms, worst \(String(format: "%.2f", frames.max)) ms")
        }
        #expect(revealing.median < plain.median * 1.25 + 0.1,
                "revealing \(revealing.median) ms a frame against \(plain.median) ms with the track hidden")
        #expect(revealing.upperQuartile < plain.upperQuartile * 1.25 + 0.1,
                "revealing \(revealing.upperQuartile) ms at the upper quartile against \(plain.upperQuartile) ms with the track hidden")
    }

    /// A whole scroll's frame costs, in milliseconds: the median and upper quartile the reader is
    /// held to, and the 90th percentile.
    struct WholeScroll {
        let median: Double
        let upperQuartile: Double
        let ninetiethPercentile: Double

        init(sorted frames: [Double]) {
            median = frames[frames.count / 2]
            upperQuartile = frames[frames.count * 3 / 4]
            ninetiethPercentile = frames[frames.count * 9 / 10]
        }
    }

    /// One pass of the main run loop, for what SwiftUI and AppKit schedule there (a function of
    /// its own: it cannot be called from an async context).
    private static func runMainLoopOnce() {
        RunLoop.main.run(until: .now)
    }

    /// Three hundred 12-point scroll frames of `scrollView` down Psalm 119 in `window`, after
    /// thirty untimed ones. Each frame is the scroll, its layout and drawing, then the main actor
    /// yielded once (the reports the frame queued: `ChapterTextView` hands them over on the next
    /// turn of the main queue, which a spun run loop would not drain) and the main run loop run
    /// once (SwiftUI applies the updates they cause there), then layout and drawing again, so all
    /// a frame causes is timed in that frame. `warmUpStart` runs before the first frame and
    /// `timedFramesStart` once the warm-up is over.
    private static func wholeScrollFrames(window: NSWindow, scrollView: NSScrollView, warmUpStart: () -> Void = {},
                                          timedFramesStart: () -> Void = {}) async -> WholeScroll {
        let clock = ContinuousClock()
        func frame(_ y: CGFloat) async {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            window.layoutIfNeeded()
            window.displayIfNeeded()
            CATransaction.flush()
            await Task.yield()
            runMainLoopOnce()
            window.layoutIfNeeded()
            window.displayIfNeeded()
            CATransaction.flush()
        }
        let start = scrollView.contentView.bounds.minY
        warmUpStart()
        for tick in 1...30 { await frame(start + CGFloat(tick) * 12) }
        timedFramesStart()
        var frames: [Double] = []
        for tick in 31...330 {
            let began = clock.now
            await frame(start + CGFloat(tick) * 12)
            frames.append(BookBenchmarkTests.milliseconds(clock.now - began))
        }
        return WholeScroll(sorted: frames.sorted())
    }

    /// The bare text controller alone in a real 1000 × 900 window, set up as `ReaderView` sets it
    /// up (the head's line, the scroller below the head, the foot's space), on Psalm 119.
    private func bareScroll(_ style: PageStyle, store: BibleStore) async throws -> WholeScroll {
        let typography = ReaderTypography.styled(ReaderPreferences(style: style))
        let layout = try Self.psalm119(store: store, typography: typography)
        let controller = ChapterTextController(onReadingPositionChange: { _ in })
        let window = NSWindow(contentRect: NSRect(x: -3000, y: 0, width: 1000, height: 900), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = controller.scrollView
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.headLineY = RunningHeadView.stripHeight(for: typography)
        controller.scrollerTopInset = RunningHeadView.height(for: typography)
        controller.bottomInset = ReaderView.footHeight
        controller.update(layout: layout, typography: typography, scrollTarget: ScrollTarget(chapter: 119, verse: 1), decorations: .none)
        window.displayIfNeeded()
        return await Self.wholeScrollFrames(window: window, scrollView: controller.scrollView)
    }

    /// Counts evaluations of the host's `body`.
    private final class BodyCount {
        var value = 0
    }

    /// The whole reader (`BenchmarkReaderHost`: `ReaderView` as the Mac window hosts it, on the
    /// package's own models) in a real window with a content area `size`, opened on Psalm 119 in
    /// the ESV at `verse`, and given a few turns of the main actor and run loop for the
    /// document's layout, the markup and the head's first report to land. `close` closes the
    /// window and drops the models' defaults.
    private struct HostedReader {
        let window: NSWindow
        let host: NSView
        let navigation: NavigationModel
        let document: ReaderDocument
        let hostBodies: BodyCount
        let close: () -> Void
    }

    private func hostReader(_ style: PageStyle, store: BibleStore, size: NSSize, verse: Int? = nil) async throws -> HostedReader {
        let typography = ReaderTypography.styled(ReaderPreferences(style: style))
        let defaultsName = "WholeReaderBenchmark-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        let navigation = try NavigationModel(store: store, positionStore: ReadingPositionStore(defaults: defaults), defaultTranslationID: "ESV")
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let markup = MarkupModel(store: MarkupStore(container: container), defaults: defaults)
        let document = ReaderDocument(store: store)
        navigation.open(ChapterLocation(book: "PSA", chapter: 119), verse: verse)
        let hostBodies = BodyCount()
        let host = NSHostingView(rootView: BenchmarkReaderHost(navigation: navigation, markup: markup, document: document,
                                                               typography: typography, onBody: { hostBodies.value += 1 }))
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -3000, y: 0), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        for _ in 0..<10 {
            await Task.yield()
            Self.runMainLoopOnce()
            window.layoutIfNeeded()
            window.displayIfNeeded()
        }
        return HostedReader(window: window, host: host, navigation: navigation, document: document, hostBodies: hostBodies) {
            window.close()
            defaults.removePersistentDomain(forName: defaultsName)
        }
    }

    /// The whole reader in a real 1000 × 900 window, scrolled from Psalm 119's start, with how
    /// many times the scroll re-evaluated `ReaderView` (from its first frame; a scroll leaves the
    /// book thumb hidden) and the host around it (over the timed frames).
    private func readerScroll(_ style: PageStyle, store: BibleStore) async throws -> (frames: WholeScroll, readerBodies: Int, hostBodies: Int) {
        let reader = try await hostReader(style, store: store, size: NSSize(width: 1000, height: 900))
        defer { reader.close() }
        #expect(reader.document.layout?.chapters == 119...119, "\(style)")
        guard let scrollView = Self.textScrollView(in: reader.host) else {
            Issue.record("\(style): no text scroll view in the reader")
            return (WholeScroll(sorted: [.infinity]), -1, -1)
        }
        #expect(scrollView.frame.height > 800, "\(style)")
        var bodiesBefore = 0
        // The landing on Psalm 119 brought the track out; the scroll starts once it has gone.
        let hidden = Date().addingTimeInterval(5)
        while Self.textController(in: scrollView)?.thumbReveal.isRevealed == true, Date() < hidden {
            try await Task.sleep(for: .milliseconds(100))
        }
        let frames = await Self.wholeScrollFrames(window: reader.window, scrollView: scrollView, warmUpStart: {
            #expect(!(Self.textController(in: scrollView)?.thumbReveal.isRevealed ?? true), "\(style): the track starts hidden")
            bodiesBefore = ReaderView.bodyEvaluations
        }, timedFramesStart: {
            reader.hostBodies.value = 0
        })
        let readerBodies = ReaderView.bodyEvaluations - bodiesBefore
        #expect(Self.textController(in: scrollView)?.thumbReveal.isRevealed == false, "\(style): a scroll never brings the track out")
        #expect(reader.navigation.location == ChapterLocation(book: "PSA", chapter: 119), "\(style)")
        return (frames, readerBodies, reader.hostBodies.value)
    }

    /// The chapter's scroll view inside `view`: the one whose document holds the text view.
    private static func textScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView, scroll.documentView?.subviews.contains(where: { $0 is NSTextView }) == true { return scroll }
        for subview in view.subviews {
            if let found = textScrollView(in: subview) { return found }
        }
        return nil
    }

    /// The text controller behind the reader's scroll view.
    private static func textController(in scrollView: NSScrollView) -> ChapterTextController? {
        scrollView.documentView?.subviews.lazy.compactMap { ($0 as? ColumnTextView)?.columnDelegate }.first
    }

    /// Matt's first report on this branch: scrolling the Mac reader was choppy. The bare text
    /// controller scrolls Psalm 119 (real ESV) at about the spec's 0.65 ms baseline, and the whole
    /// reader (`ReaderView` as the window hosts it, with its running head, progress line, foot
    /// links and book thumb) costs about what its text does.
    ///
    /// The running head reports its progress every half percent, about one frame in six here.
    /// When those reports were `ReaderView`'s state, each re-evaluated the reader (its body, its
    /// text view's update, the head and its note mark: 50 times in Printed's 300 frames, 60 in
    /// Lectern's) and that frame cost about 2 ms against 1.2 ms for the others. Now they reach
    /// only the progress line (`ReaderChrome`; `eachScrollReportInvalidatesOnlyWhatDrawsIt`).
    ///
    /// The gate is that count, which does not depend on the machine: in Printed and in Lectern,
    /// the scroll from its first frame (a scroll leaves the book thumb hidden, and its reveal is
    /// `ReaderChrome`'s, read only by the thumb, final review M1) through the three hundred timed
    /// frames evaluates `ReaderView.body` (a debug-build count) no times at all, and the timed
    /// frames evaluate the window's content around it none either. The frame cost is only checked for sanity,
    /// the median within twice the bare controller's plus half a millisecond (measured the same
    /// way); the median, upper quartile and 90th percentile are printed.
    @Test(.needsRealBible) func scrollingTheWholeReaderCostsAboutWhatItsTextDoes() async throws {
        let store = try BenchmarkChapter.realStore()
        for style in [PageStyle.printed, .lectern] {
            let bare = try await bareScroll(style, store: store)
            let (reader, readerBodies, hostBodies) = try await readerScroll(style, store: store)
            for (label, frames) in [("bare", bare), ("reader", reader)] {
                print("benchmark \(style)-psalm119-whole-scroll-\(label) median \(String(format: "%.2f", frames.median)) ms, "
                    + "upper quartile \(String(format: "%.2f", frames.upperQuartile)) ms, "
                    + "90th percentile \(String(format: "%.2f", frames.ninetiethPercentile)) ms")
            }
            print("benchmark \(style)-psalm119-whole-scroll ReaderView bodies \(readerBodies), host bodies \(hostBodies) over 300 frames")
            #expect(readerBodies == 0, "\(style): the scroll re-evaluated ReaderView \(readerBodies) times")
            #expect(hostBodies == 0, "\(style): the scroll re-evaluated the window's content \(hostBodies) times")
            #expect(reader.median < bare.median * 2 + 0.5, "\(style): the reader \(reader.median) ms a frame against the text's \(bare.median) ms")
        }
    }

    /// Task 7b's review: a head report no longer runs the text view's update, so a jump must land
    /// without one. The reader opens on Psalm 119:100 in a window with no content area yet, so the
    /// target waits for the text view to have a size; giving the window its size lands it, within
    /// that layout pass, before any report reaches SwiftUI: the verse's number sits just below
    /// the head's line and the window's content is not re-evaluated.
    @Test(.needsRealBible) func aJumpWaitingForTheViewsSizeLandsWithoutAHeadReport() async throws {
        let store = try BenchmarkChapter.realStore()
        let reader = try await hostReader(.printed, store: store, size: .zero, verse: 100)
        defer { reader.close() }
        let scrollView = try #require(Self.textScrollView(in: reader.host))
        let controller = try #require(Self.textController(in: scrollView))
        let layout = try #require(reader.document.layout)
        #expect(layout.chapters == 119...119)
        // Unsized: nothing has landed, so the head has nothing to report.
        #expect(scrollView.contentView.bounds.height == 0)
        #expect(scrollView.contentView.bounds.minY == 0 && controller.runningHead == nil)

        reader.hostBodies.value = 0
        reader.window.setContentSize(NSSize(width: 1000, height: 900))
        reader.window.layoutIfNeeded()
        // No turn of the main queue yet, so no report has reached SwiftUI.
        #expect(reader.hostBodies.value == 0)
        #expect(scrollView.contentView.bounds.height > 800)
        // Where the same jump lands in a controller sized from the start, set up as the reader sets it up.
        let sized = ChapterTextController(onReadingPositionChange: { _ in })
        sized.scrollView.frame = scrollView.frame
        sized.scrollView.layoutSubtreeIfNeeded()
        sized.headLineY = controller.headLineY
        sized.scrollerTopInset = controller.scrollerTopInset
        sized.bottomInset = controller.bottomInset
        sized.update(layout: layout, typography: .styled(ReaderPreferences(style: .printed)),
                     scrollTarget: ScrollTarget(chapter: 119, verse: 100), decorations: .none)
        #expect(sized.scrollView.contentView.bounds.minY > 0)
        #expect(abs(scrollView.contentView.bounds.minY - sized.scrollView.contentView.bounds.minY) < 0.5,
                "landed at \(scrollView.contentView.bounds.minY) against \(sized.scrollView.contentView.bounds.minY) sized from the start")
        // The landing reports the head itself.
        #expect(controller.runningHead?.chapter == 119 && (controller.runningHead?.progress ?? 0) > 0)
    }

    /// Psalm 119 (real ESV) loaded at verse 20 with sixty highlights, in a controller `width` wide.
    private func psalm119(width: CGFloat = 900) throws -> (controller: ChapterTextController, layout: BookLayout, decorations: BookDecorations) {
        let store = try BenchmarkChapter.realStore()
        let layout = try Self.psalm119(store: store, typography: .default)
        let decorations = Self.decorations(in: layout.sections[0])
        let controller = controller(width: width)
        controller.update(layout: layout, typography: .default, scrollTarget: ScrollTarget(chapter: 119, verse: 20), decorations: decorations)
        return (controller, layout, decorations)
    }

    /// Fix rounds 1–2, finding 3: widening a window already wider than the measure only re-centres
    /// the column; an animated narrowing (the inspector sliding in: twenty frames, each a new
    /// column width) lays nothing out on any frame, and once when it settles, back on the verse.
    /// With overlay scrollers and with legacy ones (a mouse attached): a legacy scroller's 15
    /// points once made the last frames narrower than the waiting column, and a text view
    /// narrower than its container cost TextKit a whole layout per frame (2026-11-12).
    @Test(.needsRealBible, arguments: [NSScroller.Style.overlay, .legacy])
    func resizingPsalm119DoesNotReflowEveryFrame(scrollers: NSScroller.Style) throws {
        let (controller, layout, _) = try psalm119(width: 1400)
        controller.scrollView.scrollerStyle = scrollers
        let verse20 = VerseLocation(book: "PSA", chapter: 119, verse: 20)
        var reported: [VerseLocation] = []
        controller.onReadingPositionChange = { reported.append($0) }
        func resize(_ width: CGFloat) {
            controller.scrollView.frame = NSRect(x: 0, y: 0, width: width, height: 700)
            controller.scrollView.layoutSubtreeIfNeeded()
        }
        // Each run widens or narrows between 1400 and 1500, both wider than the measure.
        var wide = false
        let recentre = Self.median("psalm119-recentre-1400-1500", { wide.toggle(); resize(wide ? 1500 : 1400) })
        #expect(recentre < .milliseconds(16))
        let frames = Self.measure("psalm119-animated-narrowing×20-frames", {
            for step in 0..<20 { resize(735 - CGFloat(step) * 5) }
        })
        #expect(frames < .milliseconds(100))
        let settle = Self.measure("psalm119-animated-narrowing-settle", { controller.flushPendingReflow() })
        #expect(settle < .milliseconds(1000))
        // The last frame's column, and the view back at the clip's width.
        let clip = controller.scrollView.contentView.bounds.width
        #expect(controller.textView.textContainer!.size.width == min(640, clip - 2 * ChapterTextController.horizontalInset), "\(scrollers)")
        #expect(controller.textView.frame.width == clip, "\(scrollers)")
        // Back on verse 20, its line at the top of the page.
        #expect(reported.allSatisfy { $0 == verse20 })
        let line = try #require(controller.frameOfFirstSegment(of: NSRange(location: layout.span(for: verse20)!.textRange.location, length: 3)))
        #expect(line.minY - controller.scrollView.contentView.bounds.minY < 60)
    }

    /// Fix round 1, finding 4: in Psalm 119, applying one more color highlight and one noteless
    /// underline each lands within a frame (16 ms, debug), and so does removing the underline:
    /// the median of nine of each.
    @Test(.needsRealBible) func applyingAHighlightInPsalm119FitsInAFrame() throws {
        let (controller, layout, decorations) = try psalm119()
        let span = try #require(layout.span(for: VerseLocation(book: "PSA", chapter: 119, verse: 21)))
        var colored = decorations
        colored.highlights.append(RangeDecoration(id: UUID(), range: NSRange(location: span.textRange.location, length: 12),
                                                  style: .background(MarkupColor(lightHex: "#C6EBB4", darkHex: "#2F5A1F"))))
        var underlined = colored
        underlined.highlights.append(RangeDecoration(id: UUID(), range: NSRange(location: span.textRange.location + 20, length: 10), style: .dottedUnderline))
        func show(_ shown: BookDecorations) {
            controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: shown)
        }
        let color = Self.median("psalm119-apply-color-highlight", prepare: { show(decorations) }, { show(colored) })
        let underline = Self.median("psalm119-apply-noteless-underline", prepare: { show(colored) }, { show(underlined) })
        let removed = Self.median("psalm119-remove-noteless-underline", prepare: { show(underlined) }, { show(colored) })
        #expect(color < .milliseconds(16))
        #expect(underline < .milliseconds(16))
        #expect(removed < .milliseconds(16))
        #expect(controller.backgroundFills.contains { $0.id == colored.highlights.last?.id })
    }

    /// Lectern's drop numeral costs little on the longest chapter: Psalm 119 (real ESV) builds
    /// and loads with sixty highlights within the spec's second, a reflow to a narrower column
    /// settles within the resize budget (`resizingPsalm119DoesNotReflowEveryFrame`'s second),
    /// and a hundred scroll ticks through it stay within the Printed budget. Printed's numbers
    /// are printed beside for comparison.
    @Test(.needsRealBible) func lecternPsalm119StaysWithinTheBudgets() throws {
        let store = try BenchmarkChapter.realStore()
        for style in [PageStyle.lectern, .printed] {
            let typography = ReaderTypography.styled(ReaderPreferences(style: style))
            let (layout, build) = try Self.timed("\(style)-psalm119-document-build") { try Self.psalm119(store: store, typography: typography) }
            let decorations = Self.decorations(in: layout.sections[0])
            let controller = controller(width: 900)
            let load = Self.measure("\(style)-psalm119-load", {
                controller.update(layout: layout, typography: typography, scrollTarget: ScrollTarget(chapter: 119, verse: 1), decorations: decorations)
            })
            #expect(build + load < .seconds(1), "\(style)")
            if style == .lectern { #expect(controller.numeralView?.chapter == 119) }
            controller.scrollView.frame = NSRect(x: 0, y: 0, width: 600, height: 700)
            controller.scrollView.layoutSubtreeIfNeeded()
            let reflow = Self.measure("\(style)-psalm119-reflow-to-600", { controller.flushPendingReflow() })
            #expect(reflow < .seconds(1), "\(style)")
            let maxY = controller.scrollView.documentView!.frame.height - controller.scrollView.contentView.bounds.height
            let scroll = Self.measure("\(style)-psalm119-scroll×100", {
                for tick in 0...100 {
                    controller.scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY * CGFloat(tick) / 100))
                    controller.scrollView.reflectScrolledClipView(controller.scrollView.contentView)
                }
            })
            #expect(scroll < .milliseconds(200), "\(style)")
        }
    }

    /// Every mutation reloads the markup of the open chapter, so Psalm 119's must reload within a
    /// frame: an on-disk store, sixty highlights in Psalm 119 (seven with notes), a chapter note
    /// and bookmarks. The ceiling is the debug-build budget (8 ms); the median of nine reloads is
    /// printed.
    @Test func reloadingPsalm119sMarkupFitsInAFrame() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReloadBenchmark-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try MarkupContainer.make(at: StoreLocation.resolve(sync: nil, applicationSupport: directory), sync: nil)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        let yellow = try store.colors()[0].uuid
        for verse in stride(from: 1, through: 119, by: 2) {
            let highlight = try store.addHighlight(book: "PSA", chapter: 119, verse: verse, endVerse: verse, startOffset: 0, endOffset: 12,
                                                   translationID: "KJV", colorID: yellow, quotedText: "Blessed are")
            if verse % 18 == 1 { try store.addNote(to: highlight, body: "A note on verse \(verse).") }
        }
        _ = try store.addChapterNote(book: "PSA", chapter: 119, translationID: "KJV", body: "The long psalm.", sourceThreadID: nil)
        for verse in [1, 105, 176] { try store.toggleBookmark(at: VerseLocation(book: "PSA", chapter: 119, verse: verse)) }

        let defaultsName = "ReloadBenchmark-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let model = MarkupModel(store: store, defaults: defaults)
        model.load(book: "PSA", chapters: 119...119, chapterInView: ChapterLocation(book: "PSA", chapter: 119), translationID: "KJV")
        #expect(model.itemsByChapter.count == 1 && model.items.count == 60 && model.lastError == nil)

        let clock = ContinuousClock()
        let runs: [Duration] = (0..<9).map { _ in clock.measure { model.reload() } }.sorted()
        let median = runs[4]
        print("benchmark reload-psalm119 60 highlights median \(String(format: "%.1f", BookBenchmarkTests.milliseconds(median))) ms")
        #expect(median < .milliseconds(8))
        #expect(model.items.count == 60 && model.notesByChapter[119]?.count == 8 && model.bookmarksByChapter[119] == [1, 105, 176])
    }
}

/// Whole-book build and layout on the real ESV data (skipped when `Build/bible.sqlite` is missing):
/// what a whole book costs TextKit 2, printed for comparison with one chapter's cost above.
@MainActor @Suite(.serialized) struct BookBenchmarkTests {
    struct Timing {
        let verses: Int
        let build: Duration
        let layout: Duration
    }

    static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
    }

    /// Builds the chapters `range` of `bookID` (all when nil) and lays the result out in a standalone
    /// TextKit 2 text view 640 wide, as `ChapterTextController.sizeToLayout` does.
    static func run(_ bookID: String, chapters range: ClosedRange<Int>? = nil, label: String, store: BibleStore) throws -> Timing {
        let all = try store.bookChapters(bookID, translationID: "ESV")
        let headings = try store.headings(bookID: bookID, translationID: "ESV")
        let title = try store.bookTitle(bookID: bookID, translationID: "ESV")
        let numbers = all.keys.sorted().filter { range?.contains($0) ?? true }
        let inputs = numbers.map { chapter in
            var byVerse: [Int: [SectionHeading]] = [:]
            for (location, found) in headings where location.chapter == chapter { byVerse[location.verse] = found }
            return BookChapterInput(location: ChapterLocation(book: bookID, chapter: chapter), verses: all[chapter] ?? [], headings: byVerse)
        }
        let opening = BookOpening(bookName: BookCatalog.book(code: bookID)?.name ?? bookID, title: title)
        let typography = ReaderTypography.styled(.default)
        let clock = ContinuousClock()
        var layout: BookLayout?
        let build = clock.measure { layout = BookLayout.build(chapters: inputs, opening: opening, typography: typography) }

        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 640, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0
        layoutManager.textContainer = container
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 640, height: 100), textContainer: container)
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        let text = NSMutableAttributedString(attributedString: try #require(layout).attributedString)
        let laidOut = clock.measure {
            textView.textContentStorage?.performEditingTransaction { textView.textContentStorage?.textStorage?.setAttributedString(text) }
            layoutManager.ensureLayout(for: layoutManager.documentRange)
            _ = layoutManager.usageBoundsForTextContainer
        }
        let verses = inputs.reduce(0) { $0 + $1.verses.count }
        print("benchmark \(label)-build \(verses) verses \(String(format: "%.1f", milliseconds(build))) ms")
        print("benchmark \(label)-layout \(verses) verses \(String(format: "%.1f", milliseconds(laidOut))) ms")
        return Timing(verses: verses, build: build, layout: laidOut)
    }

    /// Five runs; the run with the median build + layout total.
    static func median(_ bookID: String, chapters: ClosedRange<Int>? = nil, label: String, store: BibleStore) throws -> Timing {
        let runs = try (0..<5).map { _ in try run(bookID, chapters: chapters, label: label, store: store) }
        let sorted = runs.sorted { $0.build + $0.layout < $1.build + $1.layout }
        let middle = sorted[2]
        print("benchmark \(label)-median \(middle.verses) verses build \(String(format: "%.1f", milliseconds(middle.build))) ms layout \(String(format: "%.1f", milliseconds(middle.layout))) ms")
        return middle
    }

    @Test(.needsRealBible) func psalmsBookLayoutBuildAndFullTextKitLayout() throws {
        let store = try BenchmarkChapter.realStore()
        let timing = try Self.median("PSA", label: "psalms", store: store)
        #expect(timing.verses > 2000)
    }

    @Test(.needsRealBible) func genesisAndJohnLikewise() throws {
        let store = try BenchmarkChapter.realStore()
        _ = try Self.median("GEN", label: "genesis", store: store)
        _ = try Self.median("JHN", label: "john", store: store)
    }
}
#endif
