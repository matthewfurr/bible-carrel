import Foundation
import SwiftData
@testable import ScriptureModel

/// A device stood in for by an in-memory store with its own in-memory journal and tag. No test
/// touches iCloud: what sync would bring is handed over by `Arrival`.
@MainActor final class Device {
    let store: MarkupStore

    init(tag: String, kind: String = "Mac") throws {
        let container = try MarkupContainer.make(inMemory: true)
        store = MarkupStore(container: container, journal: LastTextJournal(directory: nil, deviceTag: tag), deviceKind: kind)
    }

    /// The kept versions' texts, sorted.
    var kept: [String] {
        get throws { try keptVersions().map(\.body).sorted() }
    }

    func text(of noteID: UUID) throws -> String? { try store.note(id: noteID)?.body }

    func keptVersions() throws -> [KeptVersion] { try store.context.fetch(FetchDescriptor<KeptVersion>()) }

    func markers() throws -> [DeletionMarker] { try store.context.fetch(FetchDescriptor<DeletionMarker>()) }
}

/// The values of a note that sync carries one at a time (the rehearsal's finding 3).
enum NoteValue: CaseIterable { case body, mark, ancestry, kind }

/// What an import brings, written through the context, never through `updateNote`, so the
/// receiving device's journal never hears of it. The store that syncs last wins: its values go to
/// the other and the other's never reach it.
@MainActor enum Arrival {
    /// `to` takes `from`'s copy of the note, the named values only (`body` brings `modifiedAt`); the note is made there if missing.
    static func note(_ id: UUID, from: Device, to: Device, values: Set<NoteValue> = Set(NoteValue.allCases)) throws {
        guard let source = try from.store.note(id: id) else { return }
        let target: Note
        if let existing = try to.store.note(id: id) {
            target = existing
        } else {
            target = NoteSnapshot(source).make()
            target.body = ""
            target.versionMark = nil
            target.versionAncestry = nil
            target.deviceKind = nil
            to.store.context.insert(target)
            if let anchor = source.highlight {
                let highlight = try to.store.highlight(id: anchor.uuid) ?? {
                    let made = HighlightSnapshot(anchor).make()
                    to.store.context.insert(made)
                    return made
                }()
                highlight.note = target
            }
        }
        if values.contains(.body) {
            target.body = source.body
            target.modifiedAt = source.modifiedAt
        }
        if values.contains(.mark) { target.versionMark = source.versionMark }
        if values.contains(.ancestry) { target.versionAncestry = source.versionAncestry }
        if values.contains(.kind) { target.deviceKind = source.deviceKind }
        try to.store.context.save()
    }

    /// The note is deleted in `to`; `from`'s markers for it come too unless `withMarkers` is false.
    static func delete(_ id: UUID, from: Device, to: Device, withMarkers: Bool = true) throws {
        if let note = try to.store.note(id: id) {
            note.highlight?.note = nil
            to.store.context.delete(note)
        }
        if withMarkers {
            try bringMarkers(from: from, to: to) { $0.noteID == id }
        }
        try to.store.context.save()
    }

    /// `to` gains the kept versions and markers `from` has and it lacks, and loses the kept versions whose uuids are in `deleted`.
    static func versions(from: Device, to: Device, deleted: Set<UUID> = []) throws {
        let present = Set(try to.keptVersions().map(\.uuid))
        for version in try from.keptVersions() where !present.contains(version.uuid) && !deleted.contains(version.uuid) {
            to.store.context.insert(KeptVersionSnapshot(version).make())
        }
        for version in try to.keptVersions() where deleted.contains(version.uuid) {
            to.store.context.delete(version)
        }
        try bringMarkers(from: from, to: to) { _ in true }
        try to.store.context.save()
    }

    private static func bringMarkers(from: Device, to: Device, where include: (DeletionMarker) -> Bool) throws {
        let present = try to.markers().map { MarkerKey($0) }
        for marker in try from.markers() where include(marker) && !present.contains(MarkerKey(marker)) {
            guard let noteID = marker.noteID else { continue }
            to.store.context.insert(DeletionMarker(noteID: noteID, version: marker.version, deletedAt: marker.deletedAt))
        }
    }

    /// A marker has no uuid; two are the same record when every value is.
    private struct MarkerKey: Equatable {
        let noteID: UUID?
        let version: String
        let deletedAt: Date

        init(_ marker: DeletionMarker) {
            noteID = marker.noteID
            version = marker.version
            deletedAt = marker.deletedAt
        }
    }
}
