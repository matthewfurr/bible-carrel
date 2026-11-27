import CoreGraphics
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct RunningHeadTests {
    /// John 1, opening with the title block (0…200), its text to 1200.
    private let john1 = ChapterBand(chapter: 1, openingMinY: 0, openingMaxY: 200, textMaxY: 1200)
    /// John 3, opening with its label (0…60), its text to 1060.
    private let john3 = ChapterBand(chapter: 3, openingMinY: 0, openingMaxY: 60, textMaxY: 1060)

    private func state(_ y: CGFloat, band: ChapterBand? = nil) -> RunningHeadState {
        RunningHead.state(band: band ?? john1, headLineY: y)
    }

    /// Spec 4.2: the head names the open chapter and its progress runs through that chapter. It is
    /// hidden at the top of every page, where the chapter's opening (chapter 1's title block, a
    /// later chapter's label) morphs into it, and full once the opening has gone under it.
    @Test func theHeadNamesTheOpenChapterAndItsProgress() {
        #expect(state(-400).chapter == 1 && state(1500).chapter == 1)
        #expect(state(-400).headOpacity == 0 && state(200).headOpacity == 1 && state(1500).headOpacity == 1)
        let three = { (y: CGFloat) in self.state(y, band: self.john3) }
        #expect(three(-400).chapter == 3 && three(-400).headOpacity == 0 && three(30).headOpacity == 0.5)
        #expect(three(60).headOpacity == 1 && three(900).headOpacity == 1)
        // Progress runs from the opening's end to the text's end, 0 to 1.
        #expect(three(0).progress == 0 && three(60).progress == 0)
        #expect(three(560).progress == 0.5)
        #expect(three(1060).progress == 1 && three(2000).progress == 1)
        #expect(state(700).progress == 0.5)
        // A chapter with no text after its opening is finished once the line reaches its end.
        let bare = ChapterBand(chapter: 2, openingMinY: 0, openingMaxY: 60, textMaxY: 60)
        #expect(state(59, band: bare).progress == 0 && state(60, band: bare).progress == 1)
    }

    /// At the page's foot the chapter is read through, though its last line never reaches the
    /// head's line (a screen of text, and the links' space, lie below that line): progress 1, the
    /// head's chapter and opacity unchanged. Both controllers pass `atFoot`.
    @Test func atThePagesFootTheProgressIsOne() {
        let three = RunningHead.state(band: john3, headLineY: 400, atFoot: true)
        #expect(three == RunningHeadState(chapter: 3, progress: 1, headOpacity: 1))
        #expect(RunningHead.state(band: john3, headLineY: 400).progress < 1)
        // A short chapter 1 at its foot: read through, the head still fading in over the title block.
        let one = RunningHead.state(band: john1, headLineY: 170, atFoot: true)
        #expect(one.progress == 1 && one.headOpacity == 0.5)
    }

    @Test func headIsInvisibleAtTheBookTopAndFullAtTheLabel() {
        #expect(state(-400).headOpacity == 0)
        #expect(state(200 - RunningHead.fadeDistance).headOpacity == 0)
        #expect(state(170).headOpacity == 0.5)
        #expect(state(200).headOpacity == 1)
        #expect(state(1500).headOpacity == 1)
    }

    /// A compact title block (Classic) whose fade would already have begun at the top of the
    /// book: the head is hidden there, and fades in over what scroll remains before the block's end.
    @Test func headIsHiddenAtTheBookTopHoweverShortTheTitleBlock() {
        let compact = ChapterBand(chapter: 1, openingMinY: 0, openingMaxY: 100, textMaxY: 1200)
        func opacity(_ y: CGFloat) -> Double {
            RunningHead.state(band: compact, headLineY: y, topHeadLineY: 60).headOpacity
        }
        #expect(opacity(60) == 0)
        #expect(opacity(80) == 0.5)
        #expect(opacity(100) == 1)
        // A block that ends above the head's line at the top still starts hidden, and the head
        // fades in over `minimumFade` of scroll.
        let tiny = ChapterBand(chapter: 1, openingMinY: 0, openingMaxY: 40, textMaxY: 1200)
        let start = RunningHead.state(band: tiny, headLineY: 60, topHeadLineY: 60)
        let end = RunningHead.state(band: tiny, headLineY: 60 + RunningHead.minimumFade, topHeadLineY: 60)
        #expect(start.headOpacity == 0)
        #expect(end.headOpacity == 1)
        // A tall block keeps the usual fade distance.
        #expect(RunningHead.state(band: john1, headLineY: 170, topHeadLineY: 60).headOpacity == 0.5)
    }

    /// Spec 3.2: under Reduce Motion the head's fade is a cut, halfway through the fade's distance;
    /// the opening's label (drawn at `1 − headOpacity`) cuts with it.
    @Test func underReduceMotionTheFadeIsACut() {
        func cut(_ y: CGFloat) -> Double {
            RunningHead.state(band: john1, headLineY: y, reducesMotion: true).headOpacity
        }
        #expect(cut(-400) == 0 && cut(160) == 0 && cut(169) == 0)
        #expect(cut(170) == 1 && cut(200) == 1 && cut(1500) == 1)
        #expect(RunningHead.cut(0.3, reducesMotion: false) == 0.3)
        #expect(RunningHead.cut(0.49, reducesMotion: true) == 0 && RunningHead.cut(0.5, reducesMotion: true) == 1)
    }

    /// The Mac's strip and the phone's bar title: the open chapter, in the page style's voice,
    /// read by VoiceOver with the book named and the chapter spelled out, at the head's opacity
    /// and with its progress.
    @Test func theTitleNamesTheOpenChapterInTheStylesVoice() {
        let head = RunningHeadState(chapter: 3, progress: 0.25, headOpacity: 1)
        let printed = RunningHeadTitle(style: .printed, book: "JHN", head: head, chapter: 3)
        #expect(printed == RunningHeadTitle(chapter: 3, text: "JOHN · 3", spokenLabel: "John, chapter 3",
                                            opacity: 1, progress: 0.25))
        #expect(RunningHeadTitle(style: .classic, book: "JHN", head: head, chapter: 3).text == "John 3")
        let psalm = RunningHeadTitle(style: .study, book: "PSA", head: RunningHeadState(chapter: 119, progress: 0, headOpacity: 1),
                                     chapter: 119)
        #expect(psalm.text == "PSALMS 119" && psalm.spokenLabel == "Psalms, chapter 119")
        // Over John 1's title block the head is hidden, and fades in as the block goes under the bar.
        let fading = RunningHeadTitle(style: .printed, book: "JHN", head: RunningHeadState(chapter: 1, progress: 0, headOpacity: 0.4),
                                      chapter: 1)
        #expect(fading.chapter == 1 && fading.opacity == 0.4 && fading.progress == 0)
    }

    /// Before the text's first report on the open chapter (none yet, or one left from the chapter
    /// before), the title names the open chapter, hidden as over every page's opening at its top
    /// (chapter 1's title block, a later chapter's label), with no progress.
    @Test func beforeAReportTheTitleNamesTheOpenChapter() {
        let early = RunningHeadTitle(style: .printed, book: "JHN", head: nil, chapter: 3)
        #expect(early.chapter == 3 && early.opacity == 0 && early.progress == 0)
        let opening = RunningHeadTitle(style: .printed, book: "JHN", head: nil, chapter: 1)
        #expect(opening.chapter == 1 && opening.opacity == 0)
        let stale = RunningHeadTitle(style: .printed, book: "JHN", head: RunningHeadState(chapter: 2, progress: 0.9, headOpacity: 1),
                                     chapter: 3)
        #expect(stale.chapter == 3 && stale.text == "JOHN · 3" && stale.opacity == 0 && stale.progress == 0)
    }

    /// Ruling R12: VoiceOver reads the head (the Mac's strip, the phone's bar title) as the chapter.
    @Test func voiceOverReadsTheHeadAsTheChapter() {
        #expect(RunningHeadTitle.spokenLabel(bookName: "John", chapter: 3) == "John, chapter 3")
        #expect(RunningHeadTitle.spokenLabel(bookName: "Psalms", chapter: 119) == "Psalms, chapter 119")
    }
}
