import Foundation
import Observation
import ScriptureModel
import SwiftData

/// Settings › General › Backups: when the newest daily backup was taken, and Restore, which
/// copies back whatever a backup has that the store is missing and says what came back.
@MainActor @Observable public final class BackupsModel {
    /// The newest backup file's modification date; nil when there is none.
    public private(set) var lastBackup: Date?
    /// The sentence after a restore; nil until one runs.
    public private(set) var resultText: String?

    @ObservationIgnored private let location: StoreLocation
    @ObservationIgnored private let store: MarkupStore
    @ObservationIgnored private let onRestore: @MainActor () -> Void
    @ObservationIgnored private let isRestoreSafe: @MainActor () -> Bool

    /// The sentence while Restore waits: shown under Backups and given when a restore is refused.
    public static let restoreUnavailableText = "Restore is available once iCloud has brought your notes back."

    /// `canRestore` says whether a restore is safe now (`SyncStatusModel.canRestore` in the app);
    /// read inside a view, any observable state it reads is tracked.
    public init(
        location: StoreLocation, store: MarkupStore, onRestore: @escaping @MainActor () -> Void,
        canRestore: @escaping @MainActor () -> Bool = { true }
    ) {
        self.location = location
        self.store = store
        self.onRestore = onRestore
        isRestoreSafe = canRestore
        refresh()
    }

    /// False until a restore cannot double what iCloud is about to bring back.
    public var canRestore: Bool { isRestoreSafe() }

    public var backupsDirectory: URL { location.backupsDirectory }

    /// The newest backup's file, if any.
    public var newestBackup: URL? {
        allBackups.first?.url
    }

    /// Every backup kept, newest first: the phone's Restore menu, which has no open panel.
    public var allBackups: [StoreBackup.Backup] {
        (try? StoreBackup.backups(in: location)) ?? []
    }

    /// Reads the newest backup's date again.
    public func refresh() {
        lastBackup = newestBackup.flatMap { url in
            (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)))?[.modificationDate] as? Date
        }
    }

    /// Copies in what the backup at `url` has and the store lacks, reloads the models and says
    /// what came back. Never changes a record; a note it brings back is journaled and loses its
    /// markers naming its text, as an undone delete does (`MarkupStore.restoreMissing`). Does
    /// nothing but say so while `canRestore` is false.
    public func restore(from url: URL) {
        guard canRestore else {
            resultText = Self.restoreUnavailableText
            return
        }
        do {
            let summary = try store.restoreMissing(fromBackup: url)
            onRestore()
            resultText = Self.sentence(for: summary)
        } catch {
            resultText = "That backup could not be read."
        }
    }

    /// `Nothing was missing.`, or `Restored ` and the non-zero counts (`2 highlights, 1 note and
    /// 1 bookmark`) and a period.
    public static func sentence(for summary: RestoreSummary) -> String {
        guard summary.total > 0 else { return "Nothing was missing." }
        let list = CountList.text([
            (summary.highlights, "highlight"), (summary.notes, "note"), (summary.bookmarks, "bookmark"),
            (summary.colors, "color"), (summary.conversations, "conversation"), (summary.prompts, "prompt"),
            (summary.plans, "reading plan"), (summary.ticks, "tick"), (summary.keptVersions, "kept version"),
        ]) ?? ""
        return "Restored \(list)."
    }
}
