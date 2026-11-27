import Foundation
import SwiftData

/// What happens to a text this device wrote once an import has changed its note or deleted it
/// (spec 4.2, 4.3). This device's journal is the only place a lost text survives (the clash
/// rehearsal), so an entry whose text is kept is forgotten only once the kept version is saved.
public enum VersionKeeper {
    /// How long a deletion marker is kept before the tidy-up removes it.
    public static let markerLifetime: TimeInterval = 90 * 86_400
}

/// What one journal entry comes to after an import.
enum EntryOutcome {
    /// The note still holds this device's text.
    case unchanged
    /// The note's text, or the delete, was made with sight of it: nothing is lost.
    case forget
    /// The text was lost without sight of it, and is now this kept version (inserted, not saved).
    case kept(KeptVersion)
}

extension MarkupStore {
    /// After an import: settles a note's differing copies, keeps the texts this device lost, tidies,
    /// and returns how many records it inserted or deleted.
    @discardableResult public func settleVersions(now: Date = Date()) throws -> Int {
        let markers = try context.fetch(FetchDescriptor<DeletionMarker>())
        var versions = try context.fetch(FetchDescriptor<KeptVersion>())
        var forgotten: [UUID] = []
        var changes = 0
        let copies = try settleCopies()
        versions += copies.kept
        changes += copies.changes
        for entry in journal.entries() where !openSittings.contains(entry.noteID) {
            switch try settle(entry, markers: markers) {
            case .unchanged:
                break
            case .forget:
                forgotten.append(entry.noteID)
            case .kept(let version):
                versions.append(version)
                forgotten.append(entry.noteID)
                changes += 1
            }
        }
        for version in try untidy(versions, markers: markers) {
            context.delete(version)
            changes += 1
        }
        let oldest = now.addingTimeInterval(-VersionKeeper.markerLifetime)
        for marker in markers where marker.deletedAt < oldest {
            context.delete(marker)
            changes += 1
        }
        if changes > 0 { try context.save() }
        for noteID in forgotten { journal.forget(noteID) }
        return changes
    }

    /// Before step 1, a note's copies (records with one uuid) whose texts differ: the one read
    /// (`Twins`) stays. Each other's text becomes a kept version (inserted, not saved) unless it is
    /// blank or the survivor was made with sight of it; then that copy is deleted. A copy with the
    /// survivor's text is never deleted, and nothing else is deleted for sharing an identity. A
    /// note with a sitting open here waits for the next settle.
    private func settleCopies() throws -> (kept: [KeptVersion], changes: Int) {
        var kept: [KeptVersion] = []
        var changes = 0
        let shared = Dictionary(grouping: try context.fetch(FetchDescriptor<Note>()), by: \.uuid).values.filter { $0.count > 1 }
        for group in shared {
            guard let survivor = Twins.notes(group).first, !openSittings.contains(survivor.uuid) else { continue }
            for copy in group where copy !== survivor && !NoteVersion.sameText(copy.body, survivor.body) {
                if let version = keepUnseen(copy, under: survivor.body, mark: survivor.versionMark, ancestry: survivor.versionAncestry) {
                    kept.append(version)
                    changes += 1
                }
                copy.highlight?.note = nil
                context.delete(copy)
                changes += 1
            }
        }
        return (kept, changes)
    }

    /// A copy's text that would be lost when the copy is deleted or written over by a note holding
    /// `text`, `mark` and `ancestry`: kept as a version (inserted, not saved) unless it is blank,
    /// the same text, or one that note was made with sight of. Nil when nothing is kept.
    func keepUnseen(_ copy: Note, under text: String, mark: String?, ancestry: String?) -> KeptVersion? {
        let writer = NoteVersion.writer(text: copy.body, mark: copy.versionMark, ancestry: copy.versionAncestry)
        guard !NoteVersion.isBlank(copy.body),
              !NoteVersion.hasSight(of: copy.body, writtenBy: writer, noteText: text, mark: mark, ancestry: ancestry)
        else { return nil }
        let version = keptVersion(of: copy)
        context.insert(version)
        return version
    }

    /// Before a write that is not the editor's (a choice, an append): the note's journal entry is
    /// settled as an import would, and a text it keeps is inserted for the write's own save, so the
    /// write does not journal over a draft the store no longer holds. In the ordinary case the entry
    /// is the note's text and nothing happens.
    func settleEntry(beforeWriting note: Note) throws {
        guard let entry = journal.entry(for: note.uuid) else { return }
        _ = try settle(entry, markers: [])
    }

    /// Step 1 for one entry: compares this device's last text with what the store now holds. A
    /// kept version is inserted, not saved; the caller saves, then forgets the entry.
    func settle(_ entry: LastText, markers: [DeletionMarker]) throws -> EntryOutcome {
        guard !NoteVersion.isBlank(entry.body) else { return .forget }
        if let note = try note(id: entry.noteID) {
            if NoteVersion.sameText(entry.body, note.body) { return .unchanged }
            if NoteVersion.hasSight(of: entry.body, writtenBy: entry.tag, noteText: note.body, mark: note.versionMark, ancestry: note.versionAncestry) {
                return .forget
            }
            return .kept(keep(entry, on: note))
        }
        if markers.contains(where: { $0.noteID == entry.noteID && NoteVersion.marker($0.version, names: entry.body, writtenBy: entry.tag) }) {
            return .forget
        }
        return .kept(keep(entry, on: nil))
    }

    /// The entry's text as a kept version of this device's kind, at the note's place when the note
    /// is here and at the entry's when it is gone.
    private func keep(_ entry: LastText, on note: Note?) -> KeptVersion {
        let version = KeptVersion()
        version.noteID = entry.noteID
        version.body = entry.body
        version.writtenAt = entry.writtenAt
        version.deviceKind = deviceKind
        version.book = note?.book ?? entry.book
        version.chapter = note?.chapter ?? entry.chapter
        version.verse = note?.verse ?? entry.verse
        version.endVerse = note?.endVerse ?? entry.endVerse
        version.translationID = note?.translationID ?? entry.translationID
        version.quotedText = note?.quotedText ?? entry.quotedText
        if let note {
            version.startOffset = note.highlight?.startOffset ?? 0
            version.endOffset = note.highlight?.endOffset ?? 0
        } else {
            version.startOffset = entry.startOffset
            version.endOffset = entry.endOffset
        }
        context.insert(version)
        return version
    }

    /// Step 2, the kept versions the tidy-up removes: of one note's versions with the same text all
    /// but the earliest written (ties, the lowest uuid; a copy sharing the survivor's uuid stays);
    /// one whose text is its note's; one whose note is gone and whose text a marker for it names as
    /// the text deleted (never as one the deleted text came from: that one the reader was promised).
    private func untidy(_ versions: [KeptVersion], markers: [DeletionMarker]) throws -> [KeptVersion] {
        var removed: [KeptVersion] = []
        for group in Dictionary(grouping: versions, by: \.noteID).values {
            var survivors: [KeptVersion] = []
            let ordered = group.sorted { ($0.writtenAt, $0.uuid.uuidString) < ($1.writtenAt, $1.uuid.uuidString) }
            for version in ordered {
                if let first = survivors.first(where: { NoteVersion.sameText($0.body, version.body) }), first.uuid != version.uuid {
                    removed.append(version)
                } else {
                    survivors.append(version)
                }
            }
            guard let noteID = group.first?.noteID else { continue }
            let note = try note(id: noteID)
            for version in survivors {
                if let note {
                    if NoteVersion.sameText(version.body, note.body) { removed.append(version) }
                } else if markers.contains(where: { $0.noteID == noteID && NoteVersion.marker($0.version, deleted: version.body) }) {
                    removed.append(version)
                }
            }
        }
        return removed
    }
}
