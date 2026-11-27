import Foundation
import SwiftData

/// One spell of editing a note: its token (new each time editing begins) and what it started from,
/// fixed when it began, so every save in it names the version the editor opened with.
public struct NoteSitting: Equatable, Sendable {
    public let noteID: UUID
    public let token: String
    public let ancestry: String
    public let deviceKind: String
}

extension MarkupStore {
    /// Begins a sitting on the note as it stands; nil when the note is gone. A nil kind is this device's.
    public func beginSitting(noteID: UUID, deviceKind: String? = nil) throws -> NoteSitting? {
        guard let note = try note(id: noteID) else { return nil }
        return openSitting(on: note, deviceKind: deviceKind)
    }

    /// Ends the sitting, then settles the note's journal entry as an import would
    /// (`settleVersions`' first step): a text that arrived while the editor was open, and was never
    /// typed over, keeps the reader's draft. A save that fails is logged and rolled back, and the
    /// entry stays for the next import to keep.
    public func endSitting(_ sitting: NoteSitting) {
        openSittings.remove(sitting.noteID)
        guard let entry = journal.entry(for: sitting.noteID) else { return }
        do {
            let noteID: UUID? = sitting.noteID
            let markers = try context.fetch(FetchDescriptor<DeletionMarker>(predicate: #Predicate { $0.noteID == noteID }))
            switch try settle(entry, markers: markers) {
            case .unchanged:
                break
            case .forget:
                journal.forget(sitting.noteID)
            case .kept:
                try context.save()
                journal.forget(sitting.noteID)
            }
        } catch {
            context.rollback()
            logger.error("keeping a version failed for note \(sitting.noteID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func openSitting(on note: Note, deviceKind: String? = nil) -> NoteSitting {
        let token = NoteVersion.newToken(deviceTag: journal.deviceTag)
        let ancestry = NoteVersion.ancestry(token: token, openedOn: note.body, mark: note.versionMark, ancestry: note.versionAncestry)
        openSittings.insert(note.uuid)
        return NoteSitting(noteID: note.uuid, token: token, ancestry: ancestry, deviceKind: deviceKind ?? self.deviceKind)
    }

    /// A new note with text is a sitting with nothing before it; an empty one has no mark.
    func markNew(_ note: Note, on highlight: Highlight?, now: Date) {
        guard !NoteVersion.isBlank(note.body) else { return }
        let token = NoteVersion.newToken(deviceTag: journal.deviceTag)
        note.versionMark = NoteVersion.mark(token: token, text: note.body)
        note.versionAncestry = NoteVersion.ancestry(token: token, openedOn: "", mark: nil, ancestry: nil)
        note.deviceKind = deviceKind
        journalText(of: note, body: note.body, on: highlight, writtenAt: now, writer: journal.deviceTag)
    }

    /// Records a non-blank text in the journal, as written by the device tagged `writer` (this
    /// device for a save made here), and forgets a blank one. A failed write is logged and the
    /// save goes on.
    func journalText(of note: Note, body: String, on highlight: Highlight?, writtenAt: Date, writer: String?) {
        guard !NoteVersion.isBlank(body) else {
            journal.forget(note.uuid)
            return
        }
        let entry = LastText(
            noteID: note.uuid, body: body, writtenAt: writtenAt,
            book: note.book, chapter: note.chapter, verse: note.verse, endVerse: note.endVerse,
            translationID: note.translationID, quotedText: note.quotedText,
            startOffset: highlight?.startOffset ?? 0, endOffset: highlight?.endOffset ?? 0, tag: writer)
        do {
            try journal.record(entry)
        } catch {
            logger.error("journal write failed for note \(note.uuid, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// A restored note's text is journaled again (written when the note was last changed, by the
    /// device its mark names when the three values hang together), and the note's markers naming
    /// that text are deleted for the same save: the undo cancels that delete, and a marker left
    /// behind would read as sight of the text when another device deletes it unseen.
    func restoreText(of note: Note, on highlight: Highlight?) throws {
        let writer = NoteVersion.writer(text: note.body, mark: note.versionMark, ancestry: note.versionAncestry)
        journalText(of: note, body: note.body, on: highlight, writtenAt: note.modifiedAt, writer: writer)
        try removeMarkers(of: note.uuid, naming: note.body)
    }

    /// Deletes, for the caller's save, the note's markers that name a non-blank `text`.
    func removeMarkers(of noteID: UUID, naming text: String) throws {
        guard !NoteVersion.isBlank(text) else { return }
        let id: UUID? = noteID
        let markers = try context.fetch(FetchDescriptor<DeletionMarker>(predicate: #Predicate { $0.noteID == id }))
        for marker in markers where NoteVersion.marker(marker.version, names: text) {
            context.delete(marker)
        }
    }

    /// The marker the delete leaves, inserted for the same save as the delete, whenever it names a
    /// text: the note's, or, for a note emptied in the editor, what the editor opened on. A note
    /// that never held text leaves none. The journal forgets the note either way.
    func markDeletion(of note: Note, now: Date) {
        journal.forget(note.uuid)
        guard let version = NoteVersion.deleted(text: note.body, mark: note.versionMark, ancestry: note.versionAncestry) else { return }
        context.insert(DeletionMarker(noteID: note.uuid, version: version, deletedAt: now))
    }
}
