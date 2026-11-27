import Foundation
import SwiftData
import Testing
@testable import ScriptureModel

/// Settling a kept version: Use This One, Keep Both in the Note, Discard with its undo, and
/// Restore as a Note. Two devices are in-memory stores; `Arrival` is the sync.
@MainActor @Suite struct KeptVersionChoiceTests {
    private let a: Device
    private let b: Device

    init() throws {
        a = try Device(tag: "aaaa", kind: "iPhone")
        b = try Device(tag: "bbbb", kind: "iPad")
    }

    private let written = Date(timeIntervalSince1970: 100)

    /// A chapter note "N" on Genesis 1 written on `a` (an iPhone) at 100, with a kept "K" from a
    /// Mac, both sent whole to `others`. Returns the note's uuid and the kept version's.
    private func noteWithKept(_ text: String = "N", to others: [Device] = []) throws -> (note: UUID, kept: UUID) {
        let note = try a.store.addChapterNote(book: "GEN", chapter: 1, translationID: "WEB", body: "", sourceThreadID: nil)
        try a.store.updateNote(note, body: text, now: written)
        let kept = keep("K", of: note.uuid, kind: "Mac", on: a)
        try a.store.context.save()
        for device in others {
            try Arrival.note(note.uuid, from: a, to: device)
            try Arrival.versions(from: a, to: device)
        }
        return (note.uuid, kept)
    }

    @discardableResult
    private func keep(_ body: String, of noteID: UUID?, kind: String = "Mac", writtenAt: Date = Date(timeIntervalSince1970: 50),
                      verse: Int = 0, endVerse: Int = 0, startOffset: Int = 0, endOffset: Int = 0, on device: Device) -> UUID {
        let version = KeptVersion()
        version.noteID = noteID
        version.body = body
        version.writtenAt = writtenAt
        version.deviceKind = kind
        version.book = "GEN"
        version.chapter = 1
        version.verse = verse
        version.endVerse = endVerse
        version.translationID = "WEB"
        version.quotedText = verse == 0 ? "" : "In the beginning"
        version.startOffset = startOffset
        version.endOffset = endOffset
        device.store.context.insert(version)
        return version.uuid
    }

    private func snapshot(_ id: UUID, on device: Device) throws -> KeptVersionSnapshot {
        try #require(try device.keptVersions().first { $0.uuid == id }.map(KeptVersionSnapshot.init))
    }

    // MARK: Use This One

    @Test func useThisOneSwapsAndKeepsTheOther() throws {
        let (id, kept) = try noteWithKept()
        let made = try #require(try a.store.useVersion(kept))

        let note = try #require(try a.store.note(id: id))
        #expect(note.body == "K" && note.deviceKind == "Mac")
        let versions = try a.store.keptVersions(forNote: id)
        #expect(versions.count == 1)
        let version = try #require(versions.first)
        #expect(version == made)
        #expect(version.body == "N" && version.writtenAt == written && version.deviceKind == "iPhone")
        #expect(version.uuid != kept)
        #expect(version.book == "GEN" && version.chapter == 1 && version.verse == 0 && version.translationID == "WEB")
        #expect(NoteVersion.hasSight(of: "N", writtenBy: "aaaa", noteText: note.body, mark: note.versionMark, ancestry: note.versionAncestry))
        #expect(a.store.journal.entry(for: id)?.body == "K")
        #expect(a.store.openSittings.isEmpty)
    }

    @Test func useThisOneOnABlankNoteKeepsNothingOfIt() throws {
        let (id, kept) = try noteWithKept("")
        #expect(try a.store.useVersion(kept) == nil)
        #expect(try a.text(of: id) == "K")
        #expect(try a.kept.isEmpty)
    }

    @Test func useThisOneAgainstADiscardElsewhereLosesNeitherText() throws {
        let (id, kept) = try noteWithKept(to: [b])
        try a.store.useVersion(kept)
        #expect(try b.store.delete(.keptVersion(try snapshot(kept, on: b))) != nil)

        try Arrival.note(id, from: a, to: b)
        try Arrival.versions(from: a, to: b, deleted: [kept])
        try Arrival.versions(from: b, to: a, deleted: [kept])
        for device in [a, b] { _ = try device.store.settleVersions() }
        for device in [a, b] {
            #expect(try device.text(of: id) == "K")
            #expect(try device.kept == ["N"])
        }
    }

    @Test func twoDevicesUsingTheSameVersionEndWithOne() throws {
        let (id, kept) = try noteWithKept(to: [b])
        try a.store.useVersion(kept)
        try b.store.useVersion(kept)

        try Arrival.note(id, from: a, to: b)
        try Arrival.versions(from: a, to: b, deleted: [kept])
        try Arrival.versions(from: b, to: a, deleted: [kept])
        for device in [a, b] { _ = try device.store.settleVersions() }
        for device in [a, b] {
            #expect(try device.text(of: id) == "K")
            #expect(try device.kept == ["N"])
        }
        #expect(try a.keptVersions().map(\.uuid) == b.keptVersions().map(\.uuid))
    }

    // MARK: Use This One, then a change of mind (sight by the writer)

    /// One sitting on `device`, saving `text`, then ended.
    private func write(_ text: String, on device: Device, note id: UUID) throws {
        let sitting = try #require(try device.store.beginSitting(noteID: id))
        let note = try #require(try device.store.note(id: id))
        try device.store.updateNote(note, body: text, sitting: sitting)
        device.store.endSitting(sitting)
    }

    /// `a` (the phone) writes "N1" and `b` (the Mac) "K" without sight of each other; `a` syncs
    /// last, so `b` keeps "K". Returns the note and the kept version's uuid on `b`.
    private func keptOnB() throws -> (note: UUID, kept: UUID) {
        let note = try a.store.addChapterNote(book: "GEN", chapter: 1, translationID: "WEB", body: "base", sourceThreadID: nil)
        let id = note.uuid
        try Arrival.note(id, from: a, to: b)
        try write("N1", on: a, note: id)
        try write("K", on: b, note: id)
        try Arrival.note(id, from: a, to: b)
        #expect(try b.store.settleVersions() == 1)
        return (id, try #require(try b.keptVersions().first { $0.body == "K" }).uuid)
    }

    /// `keptOnB`, then Use This One on `b`, synced to `a`: the note is "K" with "N1" kept on both.
    /// Returns the note and the kept versions' uuids `b` has deleted.
    private func usedOnB() throws -> (note: UUID, deleted: Set<UUID>) {
        let (id, kept) = try keptOnB()
        try b.store.useVersion(kept)
        try Arrival.note(id, from: b, to: a)
        try Arrival.versions(from: b, to: a, deleted: [kept])
        _ = try a.store.settleVersions()
        #expect(try a.text(of: id) == "K")
        #expect(try a.kept == ["N1"])
        return (id, [kept])
    }

    /// Both devices settle and swap kept versions until neither changes.
    private func syncVersions(deleted: Set<UUID>) throws {
        for _ in 1...2 {
            for device in [a, b] { _ = try device.store.settleVersions() }
            try Arrival.versions(from: a, to: b, deleted: deleted)
            try Arrival.versions(from: b, to: a, deleted: deleted)
        }
        for device in [a, b] { #expect(try device.store.settleVersions() == 0) }
    }

    /// Use This One, then the phone edits "K" to "K2", then Use This One on "N1" on the Mac before
    /// "K2" reaches it. "K2" names "N1" as the phone's, never as the Mac's putting it back.
    @Test(arguments: [true, false])
    func useThisOneTwiceAgainstAnEditElsewhereKeepsTheTextPutBack(phoneSyncsLast: Bool) throws {
        var (id, deleted) = try usedOnB()
        try write("K2", on: a, note: id)
        let n1 = try #require(try b.keptVersions().first { $0.body == "N1" }).uuid
        try b.store.useVersion(n1)
        deleted.insert(n1)

        let (winner, loser) = phoneSyncsLast ? (a, b) : (b, a)
        try Arrival.note(id, from: winner, to: loser)
        try syncVersions(deleted: deleted)
        let (text, kept) = phoneSyncsLast ? ("K2", ["K", "N1"]) : ("N1", ["K", "K2"])
        for device in [a, b] {
            #expect(try device.text(of: id) == text)
            #expect(try device.kept == kept)
        }
    }

    /// The same, with the phone deleting "K": its marker names "N1" as the phone's.
    @Test func useThisOneTwiceAgainstADeleteElsewhereKeepsTheTextPutBack() throws {
        var (id, deleted) = try usedOnB()
        try a.store.deleteNote(try #require(try a.store.note(id: id)))
        let n1 = try #require(try b.keptVersions().first { $0.body == "N1" }).uuid
        try b.store.useVersion(n1)
        deleted.insert(n1)

        try Arrival.delete(id, from: a, to: b)
        try syncVersions(deleted: deleted)
        for device in [a, b] {
            #expect(try device.store.note(id: id) == nil)
            #expect(try device.kept == ["N1"])
        }
    }

    /// Sight by the writer does not bring back a text discarded with sight of it: after Use This
    /// One and Discard on the Mac, the phone's own entry for "N1" is named by "K" as the phone's.
    @Test func theWritersEntryIsForgottenAfterUseThisOneAndDiscard() throws {
        let (id, kept) = try keptOnB()
        let made = try #require(try b.store.useVersion(kept))
        #expect(try b.store.delete(.keptVersion(made)) != nil)
        try Arrival.note(id, from: b, to: a)
        try Arrival.versions(from: b, to: a, deleted: [kept, made.uuid])
        #expect(try a.store.settleVersions() == 0)
        #expect(try a.text(of: id) == "K")
        #expect(try a.kept.isEmpty && b.kept.isEmpty)
        #expect(a.store.journal.entry(for: id) == nil)
    }

    // MARK: Deleting after a choice

    /// The delete's marker names "N" among what "K" came from, not as the text deleted, so the
    /// tidy-up leaves "N" on both devices, and the undone delete brings the note back with it.
    @Test func deletingANoteAfterUseThisOneLeavesTheOtherText() throws {
        let (id, kept) = try noteWithKept(to: [b])
        try a.store.useVersion(kept)
        try Arrival.note(id, from: a, to: b)
        try Arrival.versions(from: a, to: b, deleted: [kept])
        _ = try b.store.settleVersions()
        let note = try #require(try b.store.note(id: id))
        let deletion = try #require(try b.store.delete(.note(NoteSnapshot(note), anchor: nil)))
        try Arrival.delete(id, from: b, to: a)
        for device in [a, b] {
            _ = try device.store.settleVersions()
            #expect(try device.kept == ["N"])
        }
        try b.store.restore(deletion)
        #expect(try b.text(of: id) == "K")
        #expect(try b.store.keptVersions(forNote: id).map(\.body) == ["N"])
    }

    // MARK: A write that is not the editor's, under an open editor

    /// `a` opens the note in its editor and saves "D" in that sitting; then `b`'s "R", written
    /// without sight of "D", arrives (the settle skips the open note). Returns the note, the
    /// editor's sitting and a kept "K" of the note on `a`.
    private func draftUnderAnArrival() throws -> (note: UUID, sitting: NoteSitting, kept: UUID) {
        let note = try a.store.addChapterNote(book: "GEN", chapter: 1, translationID: "WEB", body: "base", sourceThreadID: nil)
        let id = note.uuid
        try Arrival.note(id, from: a, to: b)
        let sitting = try #require(try a.store.beginSitting(noteID: id))
        try a.store.updateNote(note, body: "D", sitting: sitting)
        try write("R", on: b, note: id)
        try Arrival.note(id, from: b, to: a)
        let kept = keep("K", of: id, on: a)
        try a.store.context.save()
        #expect(try a.store.settleVersions() == 0)
        #expect(try a.text(of: id) == "R")
        return (id, sitting, kept)
    }

    @Test func useThisOneUnderAnOpenEditorKeepsTheDraft() throws {
        let (id, sitting, kept) = try draftUnderAnArrival()
        try a.store.useVersion(kept)
        #expect(try a.text(of: id) == "K")
        #expect(try a.kept == ["D", "R"])
        a.store.endSitting(sitting)
        #expect(try a.kept == ["D", "R"])
    }

    @Test func keepBothUnderAnOpenEditorKeepsTheDraft() throws {
        let (id, sitting, kept) = try draftUnderAnArrival()
        try a.store.keepBoth(kept)
        #expect(try a.text(of: id) == "R\n\nK")
        #expect(try a.kept == ["D"])
        a.store.endSitting(sitting)
        #expect(try a.kept == ["D"])
    }

    @Test func anAppendUnderAnOpenEditorKeepsTheDraft() throws {
        let (id, sitting, _) = try draftUnderAnArrival()
        try a.store.appendToNote(try #require(try a.store.note(id: id)), "added")
        #expect(try a.text(of: id) == "R\n\nadded")
        #expect(try a.kept == ["D", "K"])
        a.store.endSitting(sitting)
        #expect(try a.kept == ["D", "K"])
    }

    /// The ordinary case: the journal holds the note's own text, and the choice keeps nothing more.
    @Test func aChoiceUnderAnOpenEditorWithNoArrivalKeepsNoMore() throws {
        let note = try a.store.addChapterNote(book: "GEN", chapter: 1, translationID: "WEB", body: "base", sourceThreadID: nil)
        let sitting = try #require(try a.store.beginSitting(noteID: note.uuid))
        try a.store.updateNote(note, body: "D", sitting: sitting)
        let kept = keep("K", of: note.uuid, on: a)
        try a.store.context.save()
        try a.store.keepBoth(kept)
        try a.store.appendToNote(note, "added")
        a.store.endSitting(sitting)
        #expect(try a.text(of: note.uuid) == "D\n\nK\n\nadded")
        #expect(try a.kept.isEmpty)
    }

    // MARK: Keep Both in the Note

    @Test func keepBothJoinsWithABlankLineAndRemovesTheVersion() throws {
        let (id, kept) = try noteWithKept()
        try a.store.keepBoth(kept)
        #expect(try a.text(of: id) == "N\n\nK")
        #expect(try a.kept.isEmpty)
        #expect(a.store.journal.entry(for: id)?.body == "N\n\nK")

        let blank = try a.store.addChapterNote(book: "GEN", chapter: 2, translationID: "WEB", body: "", sourceThreadID: nil)
        let other = keep("K", of: blank.uuid, on: a)
        try a.store.context.save()
        try a.store.keepBoth(other)
        #expect(try a.text(of: blank.uuid) == "K")
        #expect(try a.kept.isEmpty)
    }

    // MARK: Discard

    @Test func discardRemovesItAndUndoBringsItBack() throws {
        let (id, kept) = try noteWithKept()
        let before = try snapshot(kept, on: a)
        let deletion = try #require(try a.store.delete(.keptVersion(before)))
        #expect(deletion == .keptVersion(before))
        #expect(deletion.actionName == "Discard Version")
        #expect(try a.kept.isEmpty)
        #expect(try a.store.delete(.keptVersion(before)) == nil)

        try a.store.restore(deletion)
        let back = try a.store.keptVersions(forNote: id)
        #expect(back == [before])
        try a.store.restore(deletion)
        #expect(try a.keptVersions().count == 1)
    }

    // MARK: Restore as a Note

    @Test func restoreAsANoteBringsBackAChapterNote() throws {
        let noteID = UUID()
        let kept = keep("lost", of: noteID, on: a)
        a.store.context.insert(DeletionMarker(noteID: noteID, version: NoteVersion.digest("lost"), deletedAt: Date()))
        a.store.context.insert(DeletionMarker(noteID: noteID, version: NoteVersion.digest("other"), deletedAt: Date()))
        try a.store.context.save()

        #expect(try a.store.restoreAsNote(kept) == noteID)
        let note = try #require(try a.store.note(id: noteID))
        #expect(note.body == "lost" && note.scope == .chapter && note.highlight == nil)
        #expect(note.book == "GEN" && note.chapter == 1 && note.verse == 0 && note.translationID == "WEB")
        #expect(NoteVersion.isMarked(text: "lost", mark: note.versionMark))
        #expect(a.store.journal.entry(for: noteID)?.body == "lost")
        #expect(try a.kept.isEmpty)
        #expect(try a.store.allHighlights().isEmpty)
        #expect(try a.markers().map(\.version) == [NoteVersion.digest("other")])
    }

    @Test func restoreAsANoteWithNoNoteIDMakesANewOne() throws {
        let kept = keep("lost", of: nil, on: a)
        try a.store.context.save()
        let noteID = try #require(try a.store.restoreAsNote(kept))
        #expect(try a.text(of: noteID) == "lost")
    }

    @Test func restoreAsANoteJoinsItsColoredHighlight() throws {
        let color = UUID()
        let highlight = try a.store.addHighlight(book: "GEN", chapter: 1, verse: 1, endVerse: 2, startOffset: 3, endOffset: 9,
                                                 translationID: "WEB", colorID: color, quotedText: "In the beginning")
        let noteID = UUID()
        let kept = keep("lost", of: noteID, verse: 1, endVerse: 2, startOffset: 3, endOffset: 9, on: a)
        try a.store.context.save()

        #expect(try a.store.restoreAsNote(kept) == noteID)
        let note = try #require(try a.store.note(id: noteID))
        #expect(note.highlight?.uuid == highlight.uuid && highlight.colorID == color)
        #expect(note.scope == .highlight && note.verse == 1 && note.endVerse == 2 && note.quotedText == "In the beginning")
        #expect(try a.store.allHighlights().count == 1)
        #expect(try a.kept.isEmpty)
    }

    @Test func restoreAsANoteWithItsHighlightGoneMakesAColorlessOne() throws {
        let noteID = UUID()
        let kept = keep("lost", of: noteID, verse: 1, endVerse: 2, startOffset: 3, endOffset: 9, on: a)
        try a.store.context.save()

        #expect(try a.store.restoreAsNote(kept) == noteID)
        let highlight = try #require(try a.store.note(id: noteID)?.highlight)
        #expect(highlight.colorID == nil)
        #expect(highlight.book == "GEN" && highlight.chapter == 1 && highlight.verse == 1 && highlight.endVerse == 2)
        #expect(highlight.startOffset == 3 && highlight.endOffset == 9 && highlight.translationID == "WEB")
        #expect(highlight.quotedText == "In the beginning")
        #expect(a.store.journal.entry(for: noteID)?.endOffset == 9)
    }

    @Test func restoreAsANoteBesideAHighlightWithAnotherNoteMakesASecond() throws {
        let highlight = try a.store.addHighlight(book: "GEN", chapter: 1, verse: 1, endVerse: 2, startOffset: 3, endOffset: 9,
                                                 translationID: "WEB", colorID: UUID(), quotedText: "In the beginning")
        let other = try a.store.addNote(to: highlight, body: "other")
        let noteID = UUID()
        let kept = keep("lost", of: noteID, verse: 1, endVerse: 2, startOffset: 3, endOffset: 9, on: a)
        try a.store.context.save()

        #expect(try a.store.restoreAsNote(kept) == noteID)
        let second = try #require(try a.store.note(id: noteID)?.highlight)
        #expect(second.uuid != highlight.uuid && second.colorID == nil)
        #expect(highlight.note?.uuid == other.uuid)
        #expect(try a.store.allHighlights().count == 2)
    }

    @Test func restoreAsANoteWhoseNoteIsHereKeepsTheVersion() throws {
        let (id, _) = try noteWithKept()
        let orphanLike = keep("lost", of: id, on: a)
        try a.store.context.save()
        #expect(try a.store.restoreAsNote(orphanLike) == nil)
        #expect(try a.text(of: id) == "N")
        #expect(try a.kept == ["K", "lost"])
    }

    // MARK: Counts and orphans

    @Test func countsAndOrphans() throws {
        let (id, _) = try noteWithKept()
        keep("K2", of: id, writtenAt: Date(timeIntervalSince1970: 70), on: a)
        let bare = try a.store.addChapterNote(book: "GEN", chapter: 3, translationID: "WEB", body: "bare", sourceThreadID: nil)
        let gone = UUID()
        let older = keep("gone1", of: gone, writtenAt: Date(timeIntervalSince1970: 10), on: a)
        let newer = keep("gone2", of: gone, writtenAt: Date(timeIntervalSince1970: 20), on: a)
        try a.store.context.save()

        let counts = try a.store.keptVersionCounts()
        #expect(counts[id] == 2)
        #expect(counts[bare.uuid] == nil)
        #expect(try a.store.keptVersions(forNote: id).map(\.body) == ["K2", "K"])
        #expect(try a.store.orphanVersions().map(\.uuid) == [newer, older])
    }
}
