import Foundation
import SwiftData
import Testing
@testable import ScriptureModel

/// After an import, a text this device wrote and then lost becomes a kept version, once, and the
/// kept versions are tidied. Two or three devices are in-memory stores; `Arrival` is the sync.
@MainActor @Suite struct VersionKeeperTests {
    private let a: Device
    private let b: Device
    private let c: Device

    init() throws {
        a = try Device(tag: "aaaa")
        b = try Device(tag: "bbbb", kind: "iPhone")
        c = try Device(tag: "cccc", kind: "iPad")
    }

    /// A chapter note "base" on Genesis 1, made on `a` and sent whole to `to`.
    private func shared(to devices: [Device]? = nil) throws -> UUID {
        let note = try a.store.addChapterNote(book: "GEN", chapter: 1, translationID: "WEB", body: "base", sourceThreadID: nil)
        for device in devices ?? [b, c] { try Arrival.note(note.uuid, from: a, to: device) }
        return note.uuid
    }

    /// One sitting on `device`, saving each text in turn, then ended.
    private func write(_ texts: String..., on device: Device, note id: UUID, at now: Date = Date()) throws {
        let sitting = try #require(try device.store.beginSitting(noteID: id))
        let note = try #require(try device.store.note(id: id))
        for text in texts { try device.store.updateNote(note, body: text, sitting: sitting, now: now) }
        device.store.endSitting(sitting)
    }

    private func keep(_ body: String, of noteID: UUID?, writtenAt: Date, uuid: UUID = UUID(), on device: Device) {
        let version = KeptVersion()
        version.uuid = uuid
        version.noteID = noteID
        version.body = body
        version.writtenAt = writtenAt
        device.store.context.insert(version)
    }

    private func uuid(_ last: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", last))! }

    // MARK: Clashes

    /// `a` writes "A1", `b` "B1", without sight of each other; the winner's note reaches the loser.
    private func clash(aWinsOver: Bool, aDate: Date = Date(), bDate: Date = Date()) throws {
        let id = try shared()
        try write("A1", on: a, note: id, at: aDate)
        try write("B1", on: b, note: id, at: bDate)
        let (winner, loser, winnerText, loserText) = aWinsOver ? (a, b, "A1", "B1") : (b, a, "B1", "A1")
        try Arrival.note(id, from: winner, to: loser)

        #expect(try loser.store.settleVersions() == 1)
        #expect(try loser.kept == [loserText])
        #expect(try loser.text(of: id) == winnerText)
        #expect(loser.store.journal.entry(for: id) == nil)

        try Arrival.versions(from: loser, to: winner)
        #expect(try winner.store.settleVersions() == 0)
        #expect(try winner.kept == [loserText])
        #expect(try loser.store.settleVersions() == 0)
    }

    @Test(arguments: [true, false])
    func twoEditsWithoutSightKeepTheLosersTextOnceOnBoth(aWins: Bool) throws {
        try clash(aWinsOver: aWins)
    }

    @Test(arguments: [true, false])
    func aLongRunOfTypingAgainstOneEditKeepsExactlyOne(aWins: Bool) throws {
        let id = try shared()
        try write(contentsOf: (1...20).map { "A\($0)" }, on: a, note: id)
        try write(contentsOf: (21...25).map { "A\($0)" }, on: a, note: id)
        try write(contentsOf: (26...30).map { "A\($0)" }, on: a, note: id)
        try write("B1", on: b, note: id)
        let (winner, loser, loserText) = aWins ? (a, b, "B1") : (b, a, "A30")
        try Arrival.note(id, from: winner, to: loser)
        #expect(try loser.store.settleVersions() == 1)
        #expect(try loser.kept == [loserText])
        try Arrival.versions(from: loser, to: winner)
        #expect(try winner.store.settleVersions() == 0)
        #expect(try winner.kept == [loserText])
    }

    private func write(contentsOf texts: [String], on device: Device, note id: UUID) throws {
        let sitting = try #require(try device.store.beginSitting(noteID: id))
        let note = try #require(try device.store.note(id: id))
        for text in texts { try device.store.updateNote(note, body: text, sitting: sitting) }
        device.store.endSitting(sitting)
    }

    @Test func anEditMadeWithSightKeepsNothing() throws {
        let id = try shared()
        try write("A1", on: a, note: id)
        try Arrival.note(id, from: a, to: b)
        try write("B2", on: b, note: id)
        try Arrival.note(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 0)
        #expect(try a.kept.isEmpty)
        #expect(a.store.journal.entry(for: id) == nil)
    }

    @Test(arguments: [("same", "same"), ("same\n", "same")])
    func theSameTextTwiceKeepsNothing(texts: (String, String)) throws {
        let id = try shared()
        try write(texts.0, on: a, note: id)
        try write(texts.1, on: b, note: id)
        try Arrival.note(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 0)
        #expect(try a.kept.isEmpty)
        try Arrival.note(id, from: a, to: b)
        #expect(try b.store.settleVersions() == 0)
        #expect(try b.kept.isEmpty)
    }

    @Test func threeDevicesKeepEachLostTextOnce() throws {
        let id = try shared()
        try write("A1", on: a, note: id)
        try write("B1", on: b, note: id)
        try write("C1", on: c, note: id)
        try Arrival.note(id, from: c, to: a)
        try Arrival.note(id, from: c, to: b)
        let devices = [a, b, c]
        for round in 1...2 {
            for device in devices { _ = try device.store.settleVersions() }
            for from in devices {
                for to in devices where to !== from { try Arrival.versions(from: from, to: to) }
            }
            for device in devices {
                let changed = try device.store.settleVersions()
                if round == 2 { #expect(changed == 0) }
                #expect(try device.kept == ["A1", "B1"])
                #expect(try device.text(of: id) == "C1")
            }
        }
    }

    @Test func aChangeUnderAnUnchangedMarkKeepsThisDevicesText() throws {
        let id = try shared()
        try write("A1", on: a, note: id)
        try write("B1", on: b, note: id)
        try Arrival.note(id, from: b, to: a, values: [.body])
        #expect(try a.store.settleVersions() == 1)
        #expect(try a.kept == ["A1"])
    }

    @Test func aBodyUnderAnotherSittingsAncestryKeepsThisDevicesText() throws {
        let id = try shared()
        try write("A1", on: a, note: id)
        try Arrival.note(id, from: a, to: c)
        try write("C1", on: c, note: id)
        try write("B1", on: b, note: id)
        try Arrival.note(id, from: b, to: a, values: [.body, .mark])
        try Arrival.note(id, from: c, to: a, values: [.ancestry])
        #expect(try a.store.settleVersions() == 1)
        #expect(try a.kept == ["A1"])
    }

    @Test func aTextArrivingWhileTheEditorIsOpenIsKeptByTheDeviceThatWroteIt() throws {
        let id = try shared()
        let sitting = try #require(try a.store.beginSitting(noteID: id))
        let note = try #require(try a.store.note(id: id))
        try a.store.updateNote(note, body: "draft", sitting: sitting)
        try write("B1", on: b, note: id)
        try Arrival.note(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 0)
        #expect(a.store.journal.entry(for: id)?.body == "draft")

        try a.store.updateNote(note, body: "draft2", sitting: sitting)
        a.store.endSitting(sitting)
        #expect(try a.kept.isEmpty)
        try Arrival.note(id, from: a, to: b)
        #expect(try b.store.settleVersions() == 1)
        #expect(try b.kept == ["B1"])
    }

    @Test func closingTheEditorAfterAnArrivalKeepsTheDraft() throws {
        let id = try shared()
        let sitting = try #require(try a.store.beginSitting(noteID: id))
        let note = try #require(try a.store.note(id: id))
        try a.store.updateNote(note, body: "draft", sitting: sitting)
        try write("B1", on: b, note: id)
        try Arrival.note(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 0)

        a.store.endSitting(sitting)
        #expect(try a.kept == ["draft"])
        #expect(try a.text(of: id) == "B1")
        #expect(a.store.journal.entry(for: id) == nil)
        // The kept version was saved by `endSitting`: a rollback leaves it.
        a.store.context.rollback()
        #expect(try a.kept == ["draft"])
    }

    @Test func aBlankTextIsNeverKept() throws {
        let id = try shared()
        try write("A1", "", on: a, note: id)
        try write("B1", on: b, note: id)
        try Arrival.note(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 0)
        #expect(try a.kept.isEmpty)
    }

    // MARK: Deleted against edited

    @Test func aDeleteThatHadNotSeenTheTextLeavesItWithNoNote() throws {
        let id = try shared()
        try write("A1", on: a, note: id)
        try b.store.deleteNote(try #require(try b.store.note(id: id)))
        try Arrival.delete(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 1)
        let versions = try a.keptVersions()
        #expect(versions.count == 1)
        let version = try #require(versions.first)
        #expect(version.noteID == id && version.body == "A1" && version.deviceKind == "Mac")
        #expect(version.book == "GEN" && version.chapter == 1 && version.verse == 0 && version.translationID == "WEB")
        #expect(a.store.journal.entry(for: id) == nil)
        #expect(try a.store.settleVersions() == 0)
    }

    @Test func aDeleteThatHadSeenItKeepsNothing() throws {
        let id = try shared()
        try write("A1", on: a, note: id)
        try Arrival.note(id, from: a, to: b)
        try b.store.deleteNote(try #require(try b.store.note(id: id)))
        try Arrival.delete(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 0)
        #expect(try a.kept.isEmpty)
        #expect(a.store.journal.entry(for: id) == nil)

        // Without its marker the delete looks unseen, so the text is kept until the marker comes.
        let later = try shared(to: [])
        try write("A2", on: a, note: later)
        try Arrival.note(later, from: a, to: b)
        try b.store.deleteNote(try #require(try b.store.note(id: later)))
        try Arrival.delete(later, from: b, to: a, withMarkers: false)
        #expect(try a.store.settleVersions() == 1)
        #expect(try a.kept == ["A2"])
        try Arrival.versions(from: b, to: a)
        #expect(try a.store.settleVersions() == 1)
        #expect(try a.kept.isEmpty)
    }

    @Test func aDeleteWithNoMarkerKeepsTheText() throws {
        let id = try shared()
        try write("A1", on: a, note: id)
        try Arrival.note(id, from: a, to: b)
        try b.store.deleteNote(try #require(try b.store.note(id: id)))
        try Arrival.delete(id, from: b, to: a, withMarkers: false)
        #expect(try a.store.settleVersions() == 1)
        #expect(try a.store.settleVersions() == 0)
        #expect(try a.kept == ["A1"])
    }

    @Test func anUndoneDeleteAgainstAnEditElsewhereStillKeeps() throws {
        let id = try shared()
        let note = try #require(try a.store.note(id: id))
        let deletion = try #require(try a.store.delete(.note(NoteSnapshot(note), anchor: nil)))
        try a.store.restore(deletion)
        try write("B1", on: b, note: id)
        try Arrival.note(id, from: a, to: b)
        try Arrival.versions(from: a, to: b)
        #expect(try b.store.settleVersions() == 1)
        #expect(try b.kept == ["B1"])
    }

    @Test func anUndoneDeleteDoesNotHideALaterUnseenDelete() throws {
        let id = try shared()
        try write("A1", on: a, note: id)
        let note = try #require(try a.store.note(id: id))
        let deletion = try #require(try a.store.delete(.note(NoteSnapshot(note), anchor: nil)))
        try a.store.restore(deletion)
        try b.store.deleteNote(try #require(try b.store.note(id: id)))
        let theirs = try b.markers()
        #expect(theirs.count == 1 && theirs.allSatisfy { !NoteVersion.marker($0.version, names: "A1") })
        try Arrival.delete(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 1)
        let versions = try a.keptVersions()
        #expect(versions.count == 1 && versions.first?.noteID == id && versions.first?.body == "A1")
        #expect(try a.store.note(id: id) == nil)
        #expect(try a.store.settleVersions() == 0)
    }

    @Test func anUndoneDeleteRemovesItsMarker() throws {
        let id = try shared()
        try write("A1", on: a, note: id)
        // A marker for this note naming another text is not the undone delete's, and stays.
        a.store.context.insert(DeletionMarker(noteID: id, version: NoteVersion.digest("other"), deletedAt: Date()))
        try a.store.context.save()
        let note = try #require(try a.store.note(id: id))
        let deletion = try #require(try a.store.delete(.note(NoteSnapshot(note), anchor: nil)))
        #expect(try a.markers().contains { NoteVersion.marker($0.version, names: "A1") })
        try a.store.restore(deletion)
        let left = try a.markers().filter { $0.noteID == id }
        #expect(!left.contains { NoteVersion.marker($0.version, names: "A1") })
        #expect(left.map(\.version) == [NoteVersion.digest("other")])
    }

    /// An undone delete journals the note's text as its writer's, so the writer's next edit,
    /// made from that text, is sight of it.
    @Test func aRestoredNotesTextIsSeenByItsWritersNextEdit() throws {
        let id = try shared(to: [b])
        try write("B1", on: b, note: id)
        try Arrival.note(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 0)
        let note = try #require(try a.store.note(id: id))
        let deletion = try #require(try a.store.delete(.note(NoteSnapshot(note), anchor: nil)))
        try a.store.restore(deletion)
        #expect(a.store.journal.entry(for: id)?.tag == "bbbb")

        try write("B2", on: b, note: id)
        try Arrival.note(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 0)
        #expect(try a.kept.isEmpty)
        #expect(a.store.journal.entry(for: id) == nil)
    }

    /// The editor is open when another device's delete arrives (the settle skips the open note):
    /// ending the edit keeps the draft as a version with no note.
    @Test func endingAnEditOnANoteAnImportDeletedKeepsTheDraftWithNoNote() throws {
        let id = try shared(to: [b])
        let sitting = try #require(try a.store.beginSitting(noteID: id))
        try a.store.updateNote(try #require(try a.store.note(id: id)), body: "draft", sitting: sitting)
        try b.store.deleteNote(try #require(try b.store.note(id: id)))
        try Arrival.delete(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 0)
        #expect(a.store.journal.entry(for: id)?.body == "draft")

        a.store.endSitting(sitting)
        let versions = try a.keptVersions()
        #expect(versions.count == 1 && versions.first?.noteID == id && versions.first?.body == "draft")
        #expect(try a.store.note(id: id) == nil)
        #expect(a.store.journal.entry(for: id) == nil)
        #expect(a.store.openSittings.isEmpty)
    }

    // MARK: Emptied elsewhere

    /// Emptying a note in the editor deletes it; the marker names what the editor opened on.
    private func empty(_ id: UUID, on device: Device) throws {
        try write("", on: device, note: id)
        try device.store.deleteNote(try #require(try device.store.note(id: id)))
    }

    @Test func aNoteEmptiedElsewhereAfterReadingItKeepsNothing() throws {
        let id = try shared(to: [b])
        try write("A1", on: a, note: id)
        try Arrival.note(id, from: a, to: b)
        try empty(id, on: b)
        #expect(try b.markers().count == 1)
        try Arrival.delete(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 0)
        #expect(try a.kept.isEmpty)
        #expect(a.store.journal.entry(for: id) == nil)
    }

    @Test func aNoteEmptiedElsewhereWhileEditedHereKeepsTheEdit() throws {
        let id = try shared(to: [b])
        try write("A1", on: a, note: id)
        try Arrival.note(id, from: a, to: b)
        try write("A2", on: a, note: id)
        try empty(id, on: b)
        try Arrival.delete(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 1)
        #expect(try a.kept == ["A2"])
    }

    @Test func aKeptVersionWhoseNoteArrivesLaterJoinsIt() throws {
        let id = try shared(to: [b])
        try write("A1", on: a, note: id)
        try write("B1", on: b, note: id)
        try Arrival.note(id, from: b, to: a)
        #expect(try a.store.settleVersions() == 1)
        try Arrival.versions(from: a, to: c)
        #expect(try c.store.settleVersions() == 0)
        #expect(try c.kept == ["A1"])
        try Arrival.note(id, from: b, to: c)
        #expect(try c.store.settleVersions() == 0)
        let versions = try c.keptVersions()
        #expect(versions.count == 1 && versions.first?.noteID == id && versions.first?.body == "A1")
    }

    // MARK: The tidy-up

    @Test func sameTextKeptVersionsBecomeOneAndOneEqualToTheNoteGoes() throws {
        let id = try shared(to: [])
        let earlier = UUID(), later = UUID(), datesNoteID = UUID()
        keep("x", of: datesNoteID, writtenAt: Date(timeIntervalSince1970: 20), uuid: later, on: a)
        keep("x\n", of: datesNoteID, writtenAt: Date(timeIntervalSince1970: 10), uuid: earlier, on: a)
        let tieNoteID = UUID()
        keep("y", of: tieNoteID, writtenAt: Date(timeIntervalSince1970: 10), uuid: uuid(9), on: a)
        keep("y", of: tieNoteID, writtenAt: Date(timeIntervalSince1970: 10), uuid: uuid(2), on: a)
        keep(" base ", of: id, writtenAt: Date(timeIntervalSince1970: 10), on: a)
        let twinNoteID = UUID(), twin = UUID()
        keep("z", of: twinNoteID, writtenAt: Date(timeIntervalSince1970: 10), uuid: twin, on: a)
        keep("z", of: twinNoteID, writtenAt: Date(timeIntervalSince1970: 10), uuid: twin, on: a)
        keep("x", of: tieNoteID, writtenAt: Date(timeIntervalSince1970: 5), on: a)
        try a.store.context.save()

        #expect(try a.store.settleVersions() == 3)
        let left = try a.keptVersions()
        #expect(left.filter { $0.noteID == datesNoteID }.map(\.uuid) == [earlier])
        #expect(left.filter { $0.noteID == tieNoteID && $0.body == "y" }.map(\.uuid) == [uuid(2)])
        #expect(left.filter { $0.noteID == tieNoteID && $0.body == "x" }.count == 1)
        #expect(left.filter { $0.noteID == id }.isEmpty)
        #expect(left.filter { $0.noteID == twinNoteID }.map(\.uuid) == [twin, twin])
        #expect(try a.store.settleVersions() == 0)
    }

    @Test func markersOlderThanNinetyDaysGo() throws {
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        let old = UUID(), recent = UUID()
        a.store.context.insert(DeletionMarker(noteID: old, version: "v", deletedAt: now.addingTimeInterval(-91 * 86_400)))
        a.store.context.insert(DeletionMarker(noteID: recent, version: "v", deletedAt: now.addingTimeInterval(-89 * 86_400)))
        try a.store.context.save()
        #expect(try a.store.settleVersions(now: now) == 1)
        #expect(try a.markers().map(\.noteID) == [recent])
        #expect(VersionKeeper.markerLifetime == 90 * 86_400)
    }

    @Test(arguments: [-365.0, 365.0], [true, false])
    func noClockDecidesAClash(bDaysAfterA: Double, aWins: Bool) throws {
        let aDate = Date()
        try clash(aWinsOver: aWins, aDate: aDate, bDate: aDate.addingTimeInterval(bDaysAfterA * 86_400))
    }
}
