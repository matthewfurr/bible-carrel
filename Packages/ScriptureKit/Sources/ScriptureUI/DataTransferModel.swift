import Foundation
import Observation
import ScriptureModel
import SwiftData

/// Export All Data and Import Data: the file's name, the bytes of an export, and an import that
/// says in one sentence what it did. The panels and the phone's rows are its views.
@MainActor @Observable public final class DataTransferModel {
    /// The sentence after an import; nil until one runs.
    public private(set) var resultText: String?

    @ObservationIgnored private let store: MarkupStore
    @ObservationIgnored private let app: String
    @ObservationIgnored private let onImport: @MainActor () -> Void
    @ObservationIgnored private let isImportSafe: @MainActor () -> Bool
    @ObservationIgnored private let prepare: @MainActor () -> Void

    /// The sentence while Import waits: shown under the rows and given when an import is refused.
    public static let importUnavailableText = "Import is available once iCloud has brought your notes back."

    /// Given when what the reader had pending could not be saved before the import: nothing was imported.
    public static let unsavedText = "Your data could not be saved, so nothing was imported."

    /// `app` is the bundle's short version and build ("1.0 (42)"). `canImport` says whether an
    /// import is safe now (`SyncStatusModel.canRestore` in the app); read inside a view, any
    /// observable state it reads is tracked. `prepare` runs first on every import: the app ends an
    /// open edit there, so nothing is unsaved when the import begins.
    public init(
        store: MarkupStore, app: String, onImport: @escaping @MainActor () -> Void,
        canImport: @escaping @MainActor () -> Bool = { true }, prepare: @escaping @MainActor () -> Void = {}
    ) {
        self.store = store
        self.app = app
        self.onImport = onImport
        isImportSafe = canImport
        self.prepare = prepare
    }

    /// False until an import cannot double what iCloud is about to bring back.
    public var canImport: Bool { isImportSafe() }

    /// `Bible Carrel Data 2026-11-16.json`, the day in `calendar`.
    public static func fileName(on date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "Bible Carrel Data \(day).json"
    }

    /// Everything the reader has made as the file's bytes.
    public func exportData(includesConversations: Bool, now: Date = Date()) throws -> Data {
        try DataExport.file(from: store, includesConversations: includesConversations, app: app, now: now).encoded()
    }

    /// Adds what `data` has and the store lacks, reloads the models and says what happened. While
    /// `canImport` is false it only says so. Nothing unsaved is in the store when the import
    /// begins (an open edit ends, a pending change is saved; if that save fails nothing is
    /// imported): a failed import rolls its context back, which would take an unsaved change with it.
    public func importData(_ data: Data) {
        guard canImport else {
            resultText = Self.importUnavailableText
            return
        }
        // First, so a file that is refused leaves nothing open either.
        prepare()
        if store.context.hasChanges {
            do {
                try store.context.save()
            } catch {
                resultText = Self.unsavedText
                return
            }
        }
        do {
            let file = try DataFile.read(data)
            resultText = Self.sentence(for: try DataImport.apply(file, to: store))
            onImport()
        } catch let error as DataImportError {
            resultText = Self.sentence(for: error)
        } catch {
            resultText = Self.sentence(for: .damaged)
        }
    }

    /// `Added 12 notes and 3 highlights. 2 notes have another version kept. 40 were already here.`
    /// Each part appears only when it is more than nothing; with nothing added, `Nothing was added.`
    public static func sentence(for summary: ImportSummary) -> String {
        let added = summary.added
        let list = CountList.text([
            (added.notes, "note"), (added.highlights, "highlight"), (added.bookmarks, "bookmark"),
            (added.colors, "color"), (added.conversations, "conversation"), (added.prompts, "prompt"),
            (added.plans, "reading plan"), (added.ticks, "tick"), (added.keptVersions, "kept version"),
        ])
        var sentence = list.map { "Added \($0)." } ?? "Nothing was added."
        if summary.versionsKept > 0 {
            sentence += summary.versionsKept == 1
                ? " 1 note has another version kept." : " \(summary.versionsKept) notes have another version kept."
        }
        if summary.alreadyHere > 0 {
            sentence += summary.alreadyHere == 1 ? " 1 was already here." : " \(summary.alreadyHere) were already here."
        }
        return sentence
    }

    public static func sentence(for error: DataImportError) -> String {
        switch error {
        case .damaged: "That file is damaged and could not be read. Nothing was changed."
        case .foreign: "That file was not made by Bible Carrel. Nothing was changed."
        case .newer: "That file was made by a newer version of Bible Carrel. Nothing was changed."
        }
    }
}
