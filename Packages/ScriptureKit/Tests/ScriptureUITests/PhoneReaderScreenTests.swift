#if os(iOS)
import Foundation
import ScriptureData
import ScriptureLLM
import ScriptureModel
// Only the hosting controller: SwiftUI's own `ScrollTarget` would shadow the reader's.
import class SwiftUI.UIHostingController
import Testing
import UIKit
@testable import ScriptureUI

/// The whole Read tab (`PhoneReaderScreen`, as `PhoneRootView` hosts it, on the package's own
/// models) in a window, on Psalm 119 in the ESV: the phone's scroll gate (final review I3), as
/// the Mac's `scrollingTheWholeReaderCostsAboutWhatItsTextDoes` is for `ReaderView`. The page's
/// reports as it scrolls, and the chapter switcher's pull, reach only the small views that
/// draw them, never the screen's `body` (debug-build counts).
@MainActor @Suite(.serialized) struct PhoneReaderScreenTests {
    /// The screen in its window with the models behind it; the window must outlive the test's use.
    private struct Hosted {
        let window: UIWindow
        let navigation: NavigationModel
        let controller: PhoneChapterTextController
        let positions: ReadingPositionStore
        let close: () -> Void
    }

    /// One turn of the main actor (the reports the text view hands over on the next turn of the
    /// main queue) and of the run loop (where SwiftUI applies what they change), then layout.
    private static func pump(_ window: UIWindow, turns: Int = 1) async {
        for _ in 0..<turns {
            await Task.yield()
            runMainLoopBriefly()
            window.layoutIfNeeded()
        }
    }

    /// The main run loop for a few milliseconds (not callable from an async context directly).
    private static func runMainLoopBriefly() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
    }

    private static func textView(in view: UIView) -> UITextView? {
        if let text = view as? UITextView, text.delegate is PhoneChapterTextController { return text }
        for subview in view.subviews {
            if let found = textView(in: subview) { return found }
        }
        return nil
    }

    private func host(store: BibleStore) async throws -> Hosted {
        let defaultsName = "PhoneReaderScreenTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        let positions = ReadingPositionStore(defaults: defaults)
        let navigation = try NavigationModel(store: store, positionStore: positions, defaultTranslationID: "ESV")
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let markupStore = MarkupStore(container: container)
        let markup = MarkupModel(store: markupStore, defaults: defaults)
        let templates = PromptTemplateStore(container: container)
        let assistant = AssistantModel(markup: markupStore, templates: templates, bible: store, secrets: InMemorySecretStore(),
                                       defaults: defaults, providerFactory: { [] })
        let document = ReaderDocument(store: store)
        navigation.open(ChapterLocation(book: "PSA", chapter: 119))
        let screen = PhoneReaderScreen(navigation: navigation, document: document, markup: markup, assistant: assistant,
                                       shell: PhoneShellModel())
        let hosting = UIHostingController(rootView: screen)
        let window = TestWindow.make(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = hosting
        window.isHidden = false
        window.layoutIfNeeded()
        await Self.pump(window, turns: 40)
        let text = try #require(Self.textView(in: hosting.view), "the page's text view")
        let controller = try #require(text.delegate as? PhoneChapterTextController)
        return Hosted(window: window, navigation: navigation, controller: controller, positions: positions) {
            // `container` held to here: a context does not keep its container alive.
            _ = container
            window.isHidden = true
            window.rootViewController = nil
            defaults.removePersistentDomain(forName: defaultsName)
        }
    }

    /// Final review I3: two hundred 12-point scroll frames down Psalm 119, from its opening (so
    /// the head, shown from the top, moves its progress and the verse at the top changes, all reported)
    /// evaluate the screen's `body` and the bar title's no times at all.
    @Test(.needsRealBible) func scrollReportsNeverReEvaluateTheScreen() async throws {
        let reader = try await host(store: BenchmarkChapter.realStore())
        defer { reader.close() }
        let text = reader.controller.textView
        #expect(reader.controller.layout?.chapters == 119...119)
        #expect(text.contentSize.height > text.bounds.height * 4, "a long chapter to scroll")
        let start = text.contentOffset.y
        let screenBefore = PhoneReaderScreen.bodyEvaluations
        let titleBefore = PhoneBarTitle.bodyEvaluations
        for tick in 1...200 {
            text.setContentOffset(CGPoint(x: 0, y: start + CGFloat(tick) * 12), animated: false)
            await Self.pump(reader.window)
        }
        await Self.pump(reader.window, turns: 5)
        let screenBodies = PhoneReaderScreen.bodyEvaluations - screenBefore
        let titleBodies = PhoneBarTitle.bodyEvaluations - titleBefore
        // The reports happened: the head is out with progress, and the place was saved further on.
        let head = try #require(reader.controller.runningHead)
        #expect(head.chapter == 119 && head.headOpacity == 1 && head.progress > 0, "\(head)")
        #expect((reader.positions.load()?.firstVisibleVerse ?? 0) > 1, "the verse at the top was reported")
        #expect(screenBodies == 0, "the scroll re-evaluated PhoneReaderScreen \(screenBodies) times")
        #expect(titleBodies == 0, "the scroll re-evaluated PhoneBarTitle \(titleBodies) times")
        #expect(reader.navigation.location == ChapterLocation(book: "PSA", chapter: 119))
    }

    /// Final review I3, for the chapter switcher: a pull at Psalm 119's foot brings the cards in
    /// tick by tick and opens them, redrawing the cards' own view and never the screen's `body`.
    /// The cards show the next psalm with its opening words, and a tap on the page's card turns
    /// to it through the history.
    @Test(.needsRealBible) func aPullNeverReEvaluatesTheScreen() async throws {
        let reader = try await host(store: BenchmarkChapter.realStore())
        defer { reader.close() }
        let controller = reader.controller
        let text = controller.textView
        controller.reducesMotion = { true }
        let model = try #require(controller.switcher, "the screen gave the page its switcher")
        let foot = controller.pageEnds.upperBound
        text.setContentOffset(CGPoint(x: 0, y: foot), animated: false)
        await Self.pump(reader.window, turns: 5)
        let cardsBefore = ChapterSwitcherDeckView.bodyEvaluations
        let screenBefore = PhoneReaderScreen.bodyEvaluations
        controller.scrollViewWillBeginDragging(text)
        for distance in stride(from: CGFloat(4), through: 64, by: 4) {
            text.setContentOffset(CGPoint(x: 0, y: foot + distance), animated: false)
            await Self.pump(reader.window)
        }
        #expect(model.deck?.front == 120 && model.reveal == 1)
        #expect(model.verses(for: 120).first?.number == 1, "Psalm 120's opening verses, numbered")
        var target = CGPoint(x: 0, y: foot)
        withUnsafeMutablePointer(to: &target) {
            controller.scrollViewWillEndDragging(text, withVelocity: .zero, targetContentOffset: $0)
        }
        controller.scrollViewDidEndDragging(text, willDecelerate: false)
        await Self.pump(reader.window, turns: 5)
        #expect(controller.openSwitcherEdge == .bottom && model.isOpen)
        #expect(ChapterSwitcherDeckView.bodyEvaluations > cardsBefore, "the cards were drawn")
        let screenBodies = PhoneReaderScreen.bodyEvaluations - screenBefore
        #expect(screenBodies == 0, "the pull re-evaluated PhoneReaderScreen \(screenBodies) times")
        model.choose(120)
        await Self.pump(reader.window, turns: 10)
        #expect(reader.navigation.location == ChapterLocation(book: "PSA", chapter: 120))
        #expect(controller.openSwitcherEdge == nil, "the new chapter closed it")
    }


    /// Matt, 2026-11-13: "I can't swipe past the last chapter in the book." Through the whole
    /// screen, from the middle of a book: at Psalm 148 the stack at the foot is Psalms 149 and
    /// 150, then Proverbs' title card, then Proverbs 2 and on ("I can't swipe into the 2nd
    /// chapter"); flicks bring each to the front in turn and a tap opens the one in front. The
    /// stack at the top runs back into Job from its last chapter.
    @Test(.needsRealBible) func theCardsCrossBooksFromTheMiddleOfABook() async throws {
        let reader = try await host(store: BenchmarkChapter.realStore())
        defer { reader.close() }
        reader.navigation.open(ChapterLocation(book: "PSA", chapter: 148))
        await Self.pump(reader.window, turns: 30)
        let controller = reader.controller
        let text = controller.textView
        controller.reducesMotion = { true }
        let model = try #require(controller.switcher)
        #expect(model.nextBook == ChapterSwitcher.BookEnd(book: "PRO", name: "Proverbs", chapter: 1))
        #expect(model.previousBook == ChapterSwitcher.BookEnd(book: "JOB", name: "Job", chapter: 42))
        let foot = controller.pageEnds.upperBound
        text.setContentOffset(CGPoint(x: 0, y: foot), animated: false)
        await Self.pump(reader.window, turns: 5)
        controller.scrollViewWillBeginDragging(text)
        text.setContentOffset(CGPoint(x: 0, y: foot + 64), animated: false)
        var target = CGPoint.zero
        withUnsafeMutablePointer(to: &target) { controller.scrollViewWillEndDragging(text, withVelocity: .zero, targetContentOffset: $0) }
        controller.scrollViewDidEndDragging(text, willDecelerate: false)
        await Self.pump(reader.window, turns: 5)
        #expect(model.deck?.cards == [149, 150])
        #expect(model.deck?.other(at: 2) == ChapterSwitcher.BookEnd(book: "PRO", name: "Proverbs", chapter: 1))
        #expect(model.deck?.other(at: 3) == ChapterSwitcher.BookEnd(book: "PRO", name: "Proverbs", chapter: 2))
        #expect(model.deck?.isBook(at: 2) == true && model.deck?.isBook(at: 3) == false)
        // A flick up, as the reader makes it anywhere on the page, reaches Psalm 150; a second, Proverbs.
        for _ in 0..<2 { controller.switcherFlicked(.ended, translation: -60, velocity: -600) }
        #expect(model.deck?.isFrontBook == true && model.bookArrivals == 1)
        #expect(!model.verses(for: try #require(model.nextBook)).isEmpty, "Proverbs' opening words")
        // On into Proverbs: the second chapter's card, with its own opening words.
        controller.switcherFlicked(.ended, translation: -60, velocity: -600)
        let second = try #require(model.deck.flatMap { $0.other(at: $0.frontIndex) })
        #expect(second.book == "PRO" && second.chapter == 2 && model.deck?.isFrontBook == false && model.bookArrivals == 1)
        #expect(!model.verses(for: second).isEmpty)
        model.chooseFront()
        await Self.pump(reader.window, turns: 10)
        #expect(reader.navigation.location == ChapterLocation(book: "PRO", chapter: 2))
    }

    /// Found 2026-11-13 in a picture of the screen: the thumb read the finger a bar's height too
    /// far down the book, because its track was measured from under the bars and the press from
    /// the page's top. Through the whole screen: a press dragged to the ruler's top end and let
    /// go opens the book's first chapter, and one dragged to its bottom end the last.
    @Test(.needsRealBible) func theRulersEndsAreTheBooksEnds() async throws {
        let reader = try await host(store: BenchmarkChapter.realStore())
        defer { reader.close() }
        let controller = reader.controller
        let text = controller.textView
        // A point at the right edge, `y` points down the window.
        func edge(_ y: CGFloat) -> CGPoint { CGPoint(x: text.bounds.width - 10, y: text.contentOffset.y + y) }
        let top = text.adjustedContentInset.top
        let start = edge(400)
        controller.thumbPressed(.began, at: start, touchStartedAt: start)
        await Self.pump(reader.window, turns: 5)
        controller.thumbPressed(.changed, at: edge(top + 9), touchStartedAt: start)
        await Self.pump(reader.window, turns: 5)
        controller.thumbPressed(.ended, at: edge(top + 9), touchStartedAt: start)
        await Self.pump(reader.window, turns: 10)
        #expect(reader.navigation.location == ChapterLocation(book: "PSA", chapter: 1), "the ruler's top is Psalm 1")
        let bottom = text.bounds.height - text.adjustedContentInset.bottom
        let again = edge(400)
        controller.thumbPressed(.began, at: again, touchStartedAt: again)
        await Self.pump(reader.window, turns: 5)
        controller.thumbPressed(.changed, at: edge(bottom - 25), touchStartedAt: again)
        await Self.pump(reader.window, turns: 5)
        controller.thumbPressed(.ended, at: edge(bottom - 25), touchStartedAt: again)
        await Self.pump(reader.window, turns: 10)
        #expect(reader.navigation.location == ChapterLocation(book: "PSA", chapter: 150), "the ruler's bottom is Psalm 150")
    }






}
#endif
