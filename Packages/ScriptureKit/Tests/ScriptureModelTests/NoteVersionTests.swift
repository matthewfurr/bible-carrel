import Foundation
import Testing
@testable import ScriptureModel

private func d(_ text: String) -> String { NoteVersion.digest(text) }

@Suite struct NoteVersionTests {
    @Test func theDigestIsOfTheTrimmedText() {
        #expect(d("abide") == "072469151f645102")
        #expect(d("  abide\n") == d("abide"))
        #expect(d("Abide") != d("abide"))
        #expect(NoteVersion.sameText("a\n", "a"))
        #expect(NoteVersion.isBlank(" \n"))
    }

    @Test func aMarkIsItsSittingAndItsTextsDigest() {
        #expect(NoteVersion.newToken(deviceTag: "a1b2", random: { 42 }) == "a1b20000002a")
        #expect(NoteVersion.mark(token: "a1b20000002a", text: "abide") == "a1b20000002a.072469151f645102")
        let mark = NoteVersion.mark(token: "a1b20000002a", text: "abide")
        #expect(NoteVersion.token(ofMark: mark) == "a1b20000002a")
        #expect(NoteVersion.token(ofMark: nil) == nil)
        #expect(NoteVersion.token(ofMark: "junk") == nil)
        #expect(NoteVersion.isMarked(text: "abide ", mark: mark))
        #expect(!NoteVersion.isMarked(text: "other", mark: mark))
        #expect(!NoteVersion.isMarked(text: "abide", mark: nil))
    }

    @Test func anAncestryNamesWhatASittingOpenedOnOnePerChangeOfDevice() {
        #expect(NoteVersion.ancestry(token: "aaaa00000001", openedOn: "", mark: nil, ancestry: nil) == "aaaa00000001:")
        let one = NoteVersion.mark(token: "aaaa00000001", text: "one")
        #expect(NoteVersion.ancestry(token: "bbbb00000002", openedOn: "one", mark: one, ancestry: "aaaa00000001:") == "bbbb00000002:aaaa\(d("one"))")
        let two = NoteVersion.mark(token: "bbbb00000002", text: "two")
        let second = "bbbb00000002:aaaa\(d("one"))"
        #expect(NoteVersion.ancestry(token: "bbbb00000003", openedOn: "two", mark: two, ancestry: second) == "bbbb00000003:bbbb\(d("two")),aaaa\(d("one"))")
        let three = NoteVersion.mark(token: "bbbb00000003", text: "three")
        let third = "bbbb00000003:bbbb\(d("two")),aaaa\(d("one"))"
        #expect(NoteVersion.ancestry(token: "bbbb00000004", openedOn: "three", mark: three, ancestry: third) == "bbbb00000004:bbbb\(d("three")),aaaa\(d("one"))")
    }

    @Test func aTextWithNoMarkIsNamedByTheUnknownDeviceAndTwoOfThemStay() {
        #expect(NoteVersion.ancestry(token: "cccc00000001", openedOn: "plain", mark: nil, ancestry: nil) == "cccc00000001:0000\(d("plain"))")
        // A marked text whose sitting began 0000..., on top of an unknown entry: both stay.
        let mark = NoteVersion.mark(token: "000000000001", text: "second")
        let result = NoteVersion.ancestry(token: "bbbb00000001", openedOn: "second", mark: mark, ancestry: "000000000001:0000\(d("first"))")
        #expect(result == "bbbb00000001:0000\(d("second")),0000\(d("first"))")
    }

    @Test func nineDevicesInTurnLeaveEight() {
        var ancestry: String?
        var mark: String?
        var text = ""
        for (i, tag) in ["aaaa", "bbbb", "cccc", "dddd", "eeee", "ffff", "1111", "2222", "3333"].enumerated() {
            let token = tag + String(format: "%08x", i)
            ancestry = NoteVersion.ancestry(token: token, openedOn: text, mark: mark, ancestry: ancestry)
            text = "text \(i)"
            mark = NoteVersion.mark(token: token, text: text)
        }
        let entries = ancestry!.split(separator: ":", maxSplits: 1)[1].split(separator: ",")
        #expect(entries.count == NoteVersion.ancestryLimit)
    }

    private var four: (mark: String, ancestry: String) {
        (NoteVersion.mark(token: "bbbb00000004", text: "four"), "bbbb00000004:bbbb\(d("three")),aaaa\(d("one"))")
    }

    @Test func sightIsTheSameTextOrAnAncestorByItsWriter() {
        let v = four
        for (seen, writer) in [("four", "cccc"), ("three", "bbbb"), ("one", "aaaa")] {
            #expect(NoteVersion.hasSight(of: seen, writtenBy: writer, noteText: "four", mark: v.mark, ancestry: v.ancestry), "\(seen)")
        }
        #expect(!NoteVersion.hasSight(of: "never", writtenBy: "aaaa", noteText: "four", mark: v.mark, ancestry: v.ancestry))
        // The same words put back by another device are not the ones seen.
        #expect(!NoteVersion.hasSight(of: "one", writtenBy: "bbbb", noteText: "four", mark: v.mark, ancestry: v.ancestry))
        #expect(!NoteVersion.hasSight(of: "three", writtenBy: "aaaa", noteText: "four", mark: v.mark, ancestry: v.ancestry))
    }

    @Test func anEntryOfTheUnknownDeviceOrAWriterUnknownIsSightByDigest() {
        let mark = NoteVersion.mark(token: "bbbb00000004", text: "four")
        let ancestry = "bbbb00000004:0000\(d("plain")),aaaa\(d("one"))"
        #expect(NoteVersion.hasSight(of: "plain", writtenBy: "cccc", noteText: "four", mark: mark, ancestry: ancestry))
        #expect(NoteVersion.hasSight(of: "one", writtenBy: nil, noteText: "four", mark: mark, ancestry: ancestry))
        #expect(!NoteVersion.hasSight(of: "never", writtenBy: nil, noteText: "four", mark: mark, ancestry: ancestry))
    }

    @Test func valuesThatDoNotHangTogetherGiveNoSight() {
        let v = four
        #expect(NoteVersion.ancestorDigests(text: "other", mark: v.mark, ancestry: v.ancestry).isEmpty)
        #expect(!NoteVersion.hasSight(of: "one", writtenBy: nil, noteText: "other", mark: v.mark, ancestry: v.ancestry))
        let foreign = "cccc00000009:aaaa\(d("one"))"
        #expect(NoteVersion.ancestorDigests(text: "four", mark: v.mark, ancestry: foreign).isEmpty)
        #expect(!NoteVersion.hasSight(of: "one", writtenBy: "aaaa", noteText: "four", mark: v.mark, ancestry: foreign))
    }

    @Test func theWriterIsTheMarksTagWhenTheValuesHangTogether() {
        let v = four
        #expect(NoteVersion.writer(text: "four", mark: v.mark, ancestry: v.ancestry) == "bbbb")
        #expect(NoteVersion.writer(text: "other", mark: v.mark, ancestry: v.ancestry) == nil)
        #expect(NoteVersion.writer(text: "four", mark: v.mark, ancestry: "cccc00000009:aaaa\(d("one"))") == nil)
        #expect(NoteVersion.writer(text: "four", mark: v.mark, ancestry: nil) == nil)
        #expect(NoteVersion.writer(text: "four", mark: nil, ancestry: nil) == nil)
        let new = NoteVersion.mark(token: "aaaa00000001", text: "new")
        #expect(NoteVersion.writer(text: "new", mark: new, ancestry: "aaaa00000001:") == "aaaa")
    }

    @Test func aMarkerNamesTheDeletedTextAndWhatItCameFromEachWithItsWriter() throws {
        let v = four
        let version = try #require(NoteVersion.deleted(text: "four", mark: v.mark, ancestry: v.ancestry))
        #expect(version == "bbbb\(d("four")),bbbb\(d("three")),aaaa\(d("one"))")
        for named in ["four", "three", "one"] { #expect(NoteVersion.marker(version, names: named), "\(named)") }
        #expect(!NoteVersion.marker(version, names: "never"))
        #expect(NoteVersion.marker(version, names: "one", writtenBy: "aaaa"))
        #expect(!NoteVersion.marker(version, names: "one", writtenBy: "bbbb"))
        #expect(NoteVersion.marker(version, names: "one", writtenBy: nil))
        #expect(NoteVersion.marker(version, names: "four", writtenBy: "bbbb"))
        #expect(NoteVersion.deleted(text: "plain", mark: nil, ancestry: nil) == "0000\(d("plain"))")
        #expect(NoteVersion.marker("0000\(d("plain"))", names: "plain", writtenBy: "cccc"))
    }

    @Test func aMarkersDeletedTextIsItsFirstEntryOnly() throws {
        let v = four
        let version = try #require(NoteVersion.deleted(text: "four", mark: v.mark, ancestry: v.ancestry))
        #expect(NoteVersion.marker(version, deleted: "four"))
        #expect(!NoteVersion.marker(version, deleted: "three"))
        #expect(!NoteVersion.marker(version, deleted: "one"))
        #expect(NoteVersion.marker("\(d("four")),\(d("three"))", deleted: "four"))
        #expect(!NoteVersion.marker("\(d("four")),\(d("three"))", deleted: "three"))
    }

    @Test func anEmptiedNoteNamesOnlyWhatItCameFrom() {
        let mark = NoteVersion.mark(token: "bbbb00000004", text: "")
        let ancestry = "bbbb00000004:aaaa\(d("one"))"
        #expect(NoteVersion.deleted(text: " \n", mark: mark, ancestry: ancestry) == "aaaa\(d("one"))")
        #expect(NoteVersion.deleted(text: "", mark: mark, ancestry: "bbbb00000004:") == nil)
        #expect(NoteVersion.deleted(text: "", mark: nil, ancestry: nil) == nil)
    }

    /// A marker written before the tag (digests alone) is read by digest, whoever asks.
    @Test func aMarkerFromBeforeTheTagIsReadByDigest() {
        let old = "\(d("four")),\(d("three")),\(d("one"))"
        for named in ["four", "three", "one"] {
            #expect(NoteVersion.marker(old, names: named))
            #expect(NoteVersion.marker(old, names: named, writtenBy: "cccc"))
        }
        #expect(!NoteVersion.marker(old, names: "never", writtenBy: "cccc"))
        #expect(!NoteVersion.marker("junk,,\(d("x"))zz", names: "x", writtenBy: nil))
        #expect(!NoteVersion.marker("", names: "x"))
    }
}
