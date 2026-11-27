import Foundation
import SwiftData

/// The kept versions as the reader sees them, and the choices that settle one (spec 4.1, 4.2): Use
/// This One, Keep Both in the Note and Restore as a Note. Discard is `delete(.keptVersion(_:))`.
/// A kept version is only ever inserted or deleted, never changed, so a choice made on one device
/// at the same moment as another choice elsewhere cannot lose a text.
extension MarkupStore {
    // MARK: - Queries
    //
    // One kept version per uuid (`Twins`), the first fetched.

    /// The note's kept versions, newest `writtenAt` first.
    public func keptVersions(forNote id: UUID) throws -> [KeptVersionSnapshot] {
        let noteID: UUID? = id
        let versions = try context.fetch(FetchDescriptor<KeptVersion>(predicate: #Predicate { $0.noteID == noteID }))
        return newestFirst(versions)
    }

    /// How many kept versions each note has, by `noteID`; a note with none has no entry.
    public func keptVersionCounts() throws -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for version in Twins.firsts(try context.fetch(FetchDescriptor<KeptVersion>()), id: \.uuid) {
            guard let noteID = version.noteID else { continue }
            counts[noteID, default: 0] += 1
        }
        return counts
    }

    /// The kept versions whose note is not in the store (or that name none), newest `writtenAt` first.
    public func orphanVersions() throws -> [KeptVersionSnapshot] {
        let noteIDs = Set(try allNotes().map(\.uuid))
        let versions = try context.fetch(FetchDescriptor<KeptVersion>()).filter { version in
            version.noteID.map { !noteIDs.contains($0) } ?? true
        }
        return newestFirst(versions)
    }

    // MARK: - The choices

    /// Use This One: the kept text becomes the note's, in a sitting of the kept version's kind (this
    /// device's when it has none), and the text it replaces becomes a new kept version (its
    /// `modifiedAt`, its kind, its place) unless blank; the used kept version is deleted, every
    /// record with its uuid. Nothing is changed in place. A draft of the note's open editor that
    /// another device's text replaced is kept first (`settleEntry`), as in Keep Both and an append.
    /// Returns the new kept version of the text it replaced; nil when that text was blank.
    /// Nil too, and nothing changes, when the kept version or its note is gone.
    @discardableResult public func useVersion(_ id: UUID, now: Date = Date()) throws -> KeptVersionSnapshot? {
        let copies = try keptVersionRecords(id)
        guard let used = copies.first, let noteID = used.noteID, let note = try note(id: noteID) else { return nil }
        try settleEntry(beforeWriting: note)
        let body = used.body
        let wasOpen = openSittings.contains(noteID)
        let sitting = openSitting(on: note, deviceKind: used.deviceKind.isEmpty ? nil : used.deviceKind)
        defer { if !wasOpen { endSitting(sitting) } }

        var replaced: KeptVersion?
        if !NoteVersion.isBlank(note.body) {
            let version = keptVersion(of: note)
            context.insert(version)
            replaced = version
        }
        for copy in copies { context.delete(copy) }
        do {
            try updateNote(note, body: body, sitting: sitting, now: now)
        } catch {
            context.rollback()
            throw error
        }
        return replaced.map(KeptVersionSnapshot.init)
    }

    /// Keep Both in the Note: the note's text, a blank line, then the kept text (the kept text alone
    /// when the note is blank); the kept version is deleted, every record with its uuid. Nothing
    /// changes when the kept version or its note is gone.
    public func keepBoth(_ id: UUID, now: Date = Date()) throws {
        let copies = try keptVersionRecords(id)
        guard let kept = copies.first, let noteID = kept.noteID, let note = try note(id: noteID) else { return }
        try settleEntry(beforeWriting: note)
        let body = NoteVersion.isBlank(note.body) ? kept.body : note.body + "\n\n" + kept.body
        for copy in copies { context.delete(copy) }
        do {
            try updateNote(note, body: body, now: now)
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Restore as a Note: a note with the kept version's `noteID` (a new uuid when it has none) and
    /// text, marked as a new note is and journaled. A chapter note when `verse` is 0; otherwise on a
    /// live highlight at the same verses, offsets and translation that has no note, or else on a new
    /// colorless highlight there. The note's markers naming the text are deleted (a marker left
    /// behind would hide a later delete by a device that never saw the text), and so is the kept
    /// version, in the same save.
    /// The note's uuid; nil when a note with that identity is in the store (the text stays its kept
    /// version), or when the kept version is gone.
    @discardableResult public func restoreAsNote(_ id: UUID, now: Date = Date()) throws -> UUID? {
        let copies = try keptVersionRecords(id)
        guard let kept = copies.first else { return nil }
        if let noteID = kept.noteID, try note(id: noteID) != nil { return nil }

        let note = Note(
            body: kept.body, scope: kept.verse == 0 ? .chapter : .highlight,
            book: kept.book, chapter: kept.chapter, verse: kept.verse, endVerse: kept.endVerse,
            translationID: kept.translationID, quotedText: kept.quotedText)
        note.uuid = kept.noteID ?? UUID()
        note.createdAt = now
        note.modifiedAt = now
        let anchor = kept.verse == 0 ? nil : try anchor(for: kept)
        markNew(note, on: anchor, now: now)
        context.insert(note)
        if let anchor {
            anchor.note = note
            anchor.modifiedAt = now
        }
        try removeMarkers(of: note.uuid, naming: note.body)
        for copy in copies { context.delete(copy) }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return note.uuid
    }

    // MARK: - Helpers

    /// Every record with the uuid: a copy can share it.
    func keptVersionRecords(_ id: UUID) throws -> [KeptVersion] {
        try context.fetch(FetchDescriptor<KeptVersion>(predicate: #Predicate { $0.uuid == id }))
    }

    private func newestFirst(_ versions: [KeptVersion]) -> [KeptVersionSnapshot] {
        Twins.firsts(versions, id: \.uuid)
            .sorted { ($0.writtenAt, $0.uuid.uuidString) > ($1.writtenAt, $1.uuid.uuidString) }
            .map(KeptVersionSnapshot.init)
    }

    /// The note's present text as a new kept version: its `modifiedAt`, its kind and its place.
    func keptVersion(of note: Note) -> KeptVersion {
        let version = KeptVersion()
        version.noteID = note.uuid
        version.body = note.body
        version.writtenAt = note.modifiedAt
        version.deviceKind = note.deviceKind ?? ""
        version.book = note.book
        version.chapter = note.chapter
        version.verse = note.verse
        version.endVerse = note.endVerse
        version.translationID = note.translationID
        version.quotedText = note.quotedText
        version.startOffset = note.highlight?.startOffset ?? 0
        version.endOffset = note.highlight?.endOffset ?? 0
        return version
    }

    /// A live highlight at the kept version's place with no note; else a new colorless one there (inserted, not saved).
    private func anchor(for kept: KeptVersion) throws -> Highlight {
        let chapter = try highlights(in: .init(book: kept.book, chapter: kept.chapter))
        if let free = chapter.first(where: {
            $0.note == nil && $0.verse == kept.verse && $0.endVerse == kept.endVerse
                && $0.startOffset == kept.startOffset && $0.endOffset == kept.endOffset && $0.translationID == kept.translationID
        }) {
            return free
        }
        let highlight = Highlight(
            book: kept.book, chapter: kept.chapter, verse: kept.verse, endVerse: kept.endVerse,
            startOffset: kept.startOffset, endOffset: kept.endOffset,
            translationID: kept.translationID, colorID: nil, quotedText: kept.quotedText)
        context.insert(highlight)
        return highlight
    }
}
