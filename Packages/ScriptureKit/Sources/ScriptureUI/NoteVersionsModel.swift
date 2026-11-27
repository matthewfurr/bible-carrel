import Foundation
import Observation
import OSLog
import ScriptureModel
import SwiftData
import SwiftUI

/// A note's text and its kept versions, as the versions view shows them (spec 4.1).
public struct NoteVersions: Equatable, Sendable {
    /// The note's own text: what iCloud kept.
    public struct Current: Equatable, Sendable {
        public let body: String
        public let deviceKind: String?
        public let modifiedAt: Date
    }

    public let noteID: UUID
    /// The note's book code, for its references.
    public let book: String
    public let current: Current
    /// Newest `writtenAt` first.
    public let kept: [KeptVersionSnapshot]
}

/// What a versions view shows: a note with kept versions, or a kept version whose note is gone.
public enum VersionsSubject: Hashable, Sendable {
    case note(UUID)
    case orphan(UUID)
}

/// The choices under a kept version (spec 4.1, 4.2).
public enum VersionChoice: CaseIterable, Sendable {
    case use, keepBoth, discard, restoreAsNote

    public var title: String {
        switch self {
        case .use: "Use This One"
        case .keepBoth: "Keep Both in the Note"
        case .discard: "Discard"
        case .restoreAsNote: "Restore as a Note"
        }
    }

    public var help: String {
        switch self {
        case .use: "Make this the note's text. The other becomes the kept version."
        case .keepBoth: "Put this text under the note's text."
        case .discard: "Remove this kept version. Undo brings it back."
        case .restoreAsNote: "Put this text back as a note on its passage."
        }
    }

    /// Under a kept version of a note, or under one whose note is gone.
    public static func offered(hasNote: Bool) -> [VersionChoice] {
        hasNote ? [.use, .keepBoth, .discard] : [.restoreAsNote, .discard]
    }

    /// The one prominent choice: Restore as a Note with no note; Use This One when there is one
    /// kept version; otherwise none.
    public static func prominent(hasNote: Bool, keptCount: Int) -> VersionChoice? {
        if !hasNote { return .restoreAsNote }
        return keptCount == 1 ? .use : nil
    }
}

/// The words of the mark and the versions view.
public enum VersionText {
    public static let symbolName = "square.on.square"
    public static let orphanMark = "Kept version"
    public static let subtitle = "It was changed on two devices before they synced. Nothing was lost."
    public static let orphanTitle = "A version with no note"
    public static let orphanSubtitle = "The note was deleted on one device and changed on another before they synced. Nothing was lost."

    private static let counted = ["Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]

    /// The mark's help tag: a kept version whose note is gone has no note's versions to show.
    public static func help(for subject: VersionsSubject) -> String {
        switch subject {
        case .note: "Show the versions of this note"
        case .orphan: "Show the kept version"
        }
    }

    /// "2 versions".
    public static func mark(count: Int) -> String {
        count == 1 ? "1 version" : "\(count) versions"
    }

    /// "Two versions of this note" to "Nine versions of this note"; above nine, the figure.
    public static func title(count: Int) -> String {
        let number = (2...9).contains(count) ? counted[count - 2] : String(count)
        return "\(number) \(count == 1 ? "version" : "versions") of this note"
    }

    /// "This version · iPhone", "Kept version · Mac"; the name alone with no kind.
    public static func name(kept: Bool, deviceKind: String?) -> String {
        let name = kept ? "Kept version" : "This version"
        guard let deviceKind, !deviceKind.isEmpty else { return name }
        return "\(name) · \(deviceKind)"
    }

    /// "Today 8:14 AM", "Yesterday 9:40 PM", "Nov 12, 9:40 PM", or "Nov 12, 2025, 9:40 PM" in
    /// another year than `now`'s. The time is the system's for the locale.
    public static func time(_ date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        var clock = Date.FormatStyle(time: .shortened)
        clock.locale = locale
        clock.calendar = calendar
        clock.timeZone = calendar.timeZone
        let time = date.formatted(clock)
        if calendar.isDate(date, inSameDayAs: now) { return "Today \(time)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday \(time)"
        }
        var day = Date.FormatStyle().month(.abbreviated).day()
        if calendar.component(.year, from: date) != calendar.component(.year, from: now) { day = day.year() }
        day.locale = locale
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        return "\(date.formatted(day)), \(time)"
    }

    /// What VoiceOver reads for a version: its name and time, comma separated.
    public static func spoken(kept: Bool, deviceKind: String?, at date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        "\(name(kept: kept, deviceKind: deviceKind)), \(time(date, now: now, calendar: calendar, locale: locale))"
    }
}

/// The one model the mark and the versions view read on both apps: a note's versions, a kept
/// version whose note is gone, and the choices that settle them. Every choice goes through
/// `MarkupStore`, bumps `revision` and tells the app (`onChange`).
@MainActor @Observable
public final class NoteVersionsModel {
    /// Bumped by every reload and choice; the reads below depend on it, so a view redraws.
    public private(set) var revision = 0
    /// A plain sentence for the reader when a choice could not be saved; stays until `clearError()`.
    public private(set) var lastError: String?

    private let store: MarkupStore
    private let onChange: @MainActor () -> Void
    private let onNoteChange: @MainActor (UUID) -> Void
    private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "markup")

    /// `onNoteChange` is told the note whose text a choice changed (Use This One, Keep Both in the
    /// Note), before `onChange`: the app reloads that note's open editor.
    public init(store: MarkupStore, onChange: @escaping @MainActor () -> Void = {},
                onNoteChange: @escaping @MainActor (UUID) -> Void = { _ in }) {
        self.store = store
        self.onChange = onChange
        self.onNoteChange = onNoteChange
    }

    /// After changes arrive: every read is made again.
    public func reload() {
        revision += 1
    }

    /// The note's text and its kept versions; nil when it has none, or the note is gone.
    public func versions(forNote id: UUID) -> NoteVersions? {
        _ = revision
        do {
            let kept = try store.keptVersions(forNote: id)
            guard !kept.isEmpty, let note = try store.note(id: id) else { return nil }
            return NoteVersions(
                noteID: id, book: note.book,
                current: .init(body: note.body, deviceKind: note.deviceKind, modifiedAt: note.modifiedAt),
                kept: kept)
        } catch {
            logger.error("Could not read a note's versions: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// A kept version whose note is gone; nil when it is not one.
    public func orphan(id: UUID) -> KeptVersionSnapshot? {
        _ = revision
        do {
            return try store.orphanVersions().first { $0.uuid == id }
        } catch {
            logger.error("Could not read a kept version: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Settles the kept version. Discard registers its undo, and the undo its redo, in `undoManager`.
    public func perform(_ choice: VersionChoice, on keptID: UUID, undoManager: UndoManager?) {
        switch choice {
        case .use, .keepBoth:
            let noteID = keptVersion(keptID)?.noteID
            attempt {
                if choice == .use { try store.useVersion(keptID) } else { try store.keepBoth(keptID) }
            }
            if let noteID { onNoteChange(noteID) }
            changed()
        case .restoreAsNote:
            attempt { try store.restoreAsNote(keptID) }
            changed()
        case .discard:
            guard let version = keptVersion(keptID) else { return changed() }
            discard(.keptVersion(version), undoManager: undoManager)
        }
    }

    public func clearError() {
        lastError = nil
    }

    // MARK: - Private

    static let saveFailure = "That change could not be saved. Try it again."

    private func discard(_ deletion: MarkupDeletion, undoManager: UndoManager?) {
        var captured: MarkupDeletion?
        attempt { captured = try store.delete(deletion) }
        if let captured, let undoManager {
            undoManager.registerUndo(withTarget: self) { model in
                model.restore(captured, undoManager: undoManager)
            }
            undoManager.setActionName(captured.actionName)
        }
        changed()
    }

    private func restore(_ deletion: MarkupDeletion, undoManager: UndoManager) {
        attempt { try store.restore(deletion) }
        undoManager.registerUndo(withTarget: self) { model in
            model.discard(deletion, undoManager: undoManager)
        }
        undoManager.setActionName(deletion.actionName)
        changed()
    }

    private func changed() {
        revision += 1
        onChange()
    }

    /// Any kept version by uuid, with its note or without.
    private func keptVersion(_ id: UUID) -> KeptVersionSnapshot? {
        var found: KeptVersionSnapshot?
        attempt {
            found = try store.context.fetch(FetchDescriptor<KeptVersion>(predicate: #Predicate { $0.uuid == id })).first.map(KeptVersionSnapshot.init)
        }
        return found
    }

    private func attempt(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            lastError = Self.saveFailure
            logger.error("Version choice failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension EnvironmentValues {
    /// The versions model, for the mark and the versions view; nil outside the apps.
    @Entry public var noteVersions: NoteVersionsModel?
}
