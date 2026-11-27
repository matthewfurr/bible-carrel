import Foundation
import Testing
@testable import ScriptureUI

/// The book thumb's track: one equal band per chapter the translation has, top to bottom.
@Suite struct BookThumbTests {
    @Test func theThumbCoversExactlyTheBooksChapters() {
        let thumb = BookThumb(chapters: Array(1...150), current: 73)
        #expect(thumb.chapter(atFraction: 0) == 1)
        #expect(thumb.chapter(atFraction: 1) == 150)
        #expect(thumb.chapter(atFraction: -0.2) == 1 && thumb.chapter(atFraction: 1.4) == 150)
        #expect(thumb.chapter(atFraction: thumb.fraction(of: 73)) == 73)
    }

    @Test func theThumbSkipsChaptersTheTranslationLacks() {
        let thumb = BookThumb(chapters: [1, 2, 4, 5], current: 2)
        #expect(!(0...100).map { thumb.chapter(atFraction: Double($0) / 100) }.contains(3))
    }

    /// `ScrollTarget` carries a token, so its fields are compared rather than the value (as an
    /// array: an optional tuple has no `==`).
    @Test func lettingGoOnTheCurrentChapterDoesNothing() {
        let thumb = BookThumb(chapters: Array(1...21), current: 3)
        #expect(thumb.landing(on: 3) == nil)
        #expect(thumb.landing(on: 5).map { [$0.chapter, $0.verse] } == [5, 1])
    }

    @Test func aOneChapterBookHasNoThumb() { #expect(!BookThumb(chapters: [1], current: 1).isShown) }

    /// The pointer's height on the track reads as that fraction of the book; above or below the
    /// track clamps to its ends, and a track not yet laid out reads as the chapter being read.
    @Test func theDragMapsTheTrackToChapters() {
        let thumb = BookThumb(chapters: Array(1...150), current: 73)
        for y in stride(from: CGFloat(0), through: 600, by: 37) {
            #expect(BookThumbView.chapter(forY: y, inTrackHeight: 600, thumb: thumb)
                    == thumb.chapter(atFraction: Double(y / 600)))
        }
        #expect(BookThumbView.chapter(forY: -40, inTrackHeight: 600, thumb: thumb) == 1)
        #expect(BookThumbView.chapter(forY: 900, inTrackHeight: 600, thumb: thumb) == 150)
        #expect(BookThumbView.chapter(forY: 10, inTrackHeight: 0, thumb: thumb) == 73)
    }

    /// A tick sits at its chapter's band centre, so a drag to a tick reads that chapter.
    @Test func eachTickReadsAsItsOwnChapter() {
        let thumb = BookThumb(chapters: [1, 2, 118, 119], current: 2)
        for chapter in thumb.chapters {
            let y = BookThumbView.tickY(for: chapter, inTrackHeight: 400, thumb: thumb)
            #expect(BookThumbView.chapter(forY: y, inTrackHeight: 400, thumb: thumb) == chapter)
        }
    }

    /// The track shows when the pointer is within 40 points of the reader's right edge.
    @Test func thePointerNearTheRightEdgeRevealsTheTrack() {
        #expect(BookThumbView.revealEdge == 40)
        #expect(BookThumbView.isNearEdge(x: 900, width: 900))
        #expect(BookThumbView.isNearEdge(x: 860, width: 900))
        #expect(!BookThumbView.isNearEdge(x: 859, width: 900))
        #expect(!BookThumbView.isNearEdge(x: 450, width: 900))
    }

    /// The loupe rides beside the pointer: its trailing edge the gap to the left of the track's
    /// line, its centre at the pointer's height, held inside the track at either end (Matt,
    /// 2026-11-13: it sat at the track's top corner, half off the edge, wherever the drag was).
    @Test func theLoupeRidesBesideThePointer() {
        let middle = BookThumbView.loupeCentre(y: 300, trackHeight: 600, diameter: 64, gap: 12)
        #expect(middle.y == 300)
        #expect(middle.x + 32 == -12, "its trailing edge is the gap from the ruler")
        #expect(middle.x < 0, "left of the track, never over it or off the right edge")
        #expect(BookThumbView.loupeCentre(y: 0, trackHeight: 600, diameter: 64, gap: 12).y == 32)
        #expect(BookThumbView.loupeCentre(y: 600, trackHeight: 600, diameter: 64, gap: 12).y == 568)
        #expect(BookThumbView.loupeCentre(y: 10, trackHeight: 40, diameter: 64, gap: 12).y == 20,
                "a track shorter than the loupe centres it")
    }

    /// VoiceOver hears "Chapter, 73 of 150": the label names the element and the value, which an
    /// adjustable element announces on each change, carries the chapter. Swiping up or down moves
    /// the pending chapter through the chapters the translation has, stopping at either end.
    @Test func voiceOverAdjustsThroughTheChapters() {
        let thumb = BookThumb(chapters: [1, 2, 118, 119], current: 2)
        #expect(BookThumbView.accessibilityLabel == "Chapter")
        #expect(BookThumbView.accessibilityValue(for: 118, thumb: thumb) == "118 of 119")
        #expect(BookThumbView.adjusted(2, by: 1, thumb: thumb) == 118)
        #expect(BookThumbView.adjusted(118, by: -1, thumb: thumb) == 2)
        #expect(BookThumbView.adjusted(119, by: 1, thumb: thumb) == 119)
        #expect(BookThumbView.adjusted(1, by: -1, thumb: thumb) == 1)
    }

    /// The ruler, refined (Matt, 2026-11-13): every fifth chapter's tick is longer, and the ticks
    /// swell toward the pointer, full under it and eased away to nothing its reach to either side.
    @Test func theRulersTicksSwellTowardThePointer() {
        #expect(BookThumbView.restingTickLength(for: 5) > BookThumbView.restingTickLength(for: 4))
        #expect(BookThumbView.restingTickLength(for: 150) == BookThumbView.fifthTickLength)
        let rest = BookThumbView.tickLength
        #expect(BookThumbView.tickLength(resting: rest, y: 200, pointer: nil) == rest)
        #expect(BookThumbView.tickLength(resting: rest, y: 200, pointer: 200) == rest + BookThumbView.swell)
        let reach = BookThumbView.swellReach
        let near = BookThumbView.tickLength(resting: rest, y: 200 + reach / 2, pointer: 200)
        #expect(abs(near - (rest + BookThumbView.swell / 2)) < 0.001, "half way out, half the swell")
        #expect(BookThumbView.tickLength(resting: rest, y: 200 + reach, pointer: 200) == rest)
        #expect(BookThumbView.tickLength(resting: rest, y: 400, pointer: 200) == rest)
        // The longest tick at full swell still fits the thumb.
        #expect(BookThumbView.currentTickLength + BookThumbView.swell <= BookThumbView.width)
    }

    /// A click on the Mac's ruler jumped at once (parked 2026-11-13). Both apps now share the
    /// phone's rule: a press that never leaves the chapter it came down on lands nowhere; one that
    /// moves on, or away and back, lands where it is let go.
    @Test func aPressLandsOnlyOnceItHasLeftItsFirstChapter() {
        var click = BookThumb.Press(start: 12)
        click.moved(to: 12)
        #expect(!click.chooses(releasingOn: 12))
        var drag = BookThumb.Press(start: 12)
        drag.moved(to: 13)
        #expect(drag.chooses(releasingOn: 13))
        drag.moved(to: 12)
        #expect(drag.chooses(releasingOn: 12))
        // A press let go on another chapter than it came down on, however it got there.
        #expect(BookThumb.Press(start: 12).chooses(releasingOn: 14))
    }
}
