import Foundation
import OSLog
import ScriptureData
import ScriptureLLM
import ScriptureModel
import ScriptureUI
import SwiftData

/// The models both apps build at startup, wired to one another and to `AppSync`.
@MainActor struct AppModels {
    /// The book reader's layout, shared by the app's reader views.
    let document: ReaderDocument
    let navigation: NavigationModel
    let markup: MarkupModel
    let colorSettings: ColorSettingsModel
    let notesBrowser: NotesBrowserModel
    /// A note's versions and their choices, for the mark and the versions view on both apps.
    let versions: NoteVersionsModel
    let plans: ReadingPlanModel
    let assistant: AssistantModel
    let assistantSettings: AssistantSettingsModel
    let templates: PromptTemplateStore
    let exporter: NotesExporter

    /// Opens the Bible text and the markup store and builds every model on them. Call after
    /// `appSync.start()` and `appSync.startPreferences()`, so the reader opens at a position the
    /// key-value store already holds.
    static func make(appSync: AppSync) throws -> AppModels {
        guard let url = Bundle.main.url(forResource: "bible", withExtension: "sqlite") else {
            throw BibleStoreError.databaseMissing(Bundle.main.resourceURL ?? Bundle.main.bundleURL)
        }
        let store = try BibleStore(databaseURL: url)
        let navigation = try NavigationModel(
            store: store,
            positionStore: ReadingPositionStore(),
            recents: RecentsStore(defaults: .standard),
            defaultTranslationID: ReaderSettings.defaultTranslationID(from: .standard),
            fallbackTranslationID: ReaderSettings.defaultTranslationID)
        appSync.navigation = navigation
        // Seeding and migrating the store is the sync coordinator's (`appSync.attach` below):
        // on a fresh synced store it waits for what iCloud already holds.
        let container = try appSync.makeContainer()
        let markupStore = MarkupStore(container: container, journal: appSync.journal)
        let markupModel = MarkupModel(store: markupStore)
        let colorSettings = ColorSettingsModel(store: markupStore) { markupModel.reload() }
        let templates = PromptTemplateStore(container: container)
        let keychain = KeychainStore()
        let assistantModel = AssistantModel(
            markup: markupStore, templates: templates, bible: store, secrets: keychain,
            providerFactory: { AssistantSettings.providers(defaults: .standard, secrets: keychain) },
            onMarkupChange: { markupModel.reload() })
        assistantModel.reloadTemplates()
        // A delete or undo in the Notes browser reaches the reader, the assistant and an open
        // versions view (a discarded kept version, or a deleted note's); the versions model is
        // made below, after the browser it reloads.
        weak var versionsModel: NoteVersionsModel?
        let notesBrowser = NotesBrowserModel(store: markupStore) {
            markupModel.reload()
            assistantModel.refresh()
            versionsModel?.reload()
        }
        // A choice reaches the reader and the Notes browser; one that changed a note's text
        // reloads that note's open editor first.
        let versions = NoteVersionsModel(store: markupStore) {
            markupModel.reload()
            notesBrowser.reload()
        } onNoteChange: { noteID in
            markupModel.reloadEditor(noteID: noteID)
        }
        versionsModel = versions
        // An edit that ends may keep its draft as a version: an open versions view shows it.
        markupModel.onSittingEnd = { [weak versions] in versions?.reload() }
        // The palette's (and the phone's search) mark rows come from the markup store.
        navigation.markSearch = { (try? NotesBrowserLoader.entries(store: markupStore, query: "")) ?? [] }
        #if os(iOS)
        // The phone's search screen shows more of each group, and has no commands to offer.
        navigation.searchLimits = .phone
        navigation.includesCommandsInSearch = false
        #endif
        let plans = ReadingPlanModel(store: PlanStore(container: container), navigation: navigation)
        appSync.attach(container: container, store: markupStore, models: AppSync.Models(
            markup: markupModel, assistant: assistantModel, notesBrowser: notesBrowser, versions: versions,
            colorSettings: colorSettings, plans: plans))
        let assistantSettings = AssistantSettingsModel(secrets: keychain)
        appSync.assistantSettings = assistantSettings
        #if DEBUG && os(iOS)
        // `-phoneSeed YES`: the simulator's fixed sample in John 15, on an empty store.
        do {
            if try PhoneSeed.runIfAsked(store: markupStore, bible: store, translationID: navigation.translationID) {
                markupModel.reload()
                assistantModel.refresh()
                notesBrowser.reload()
            }
        } catch {
            Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "startup")
                .error("phone seed failed: \(String(describing: error), privacy: .public)")
        }
        #endif
        let document = ReaderDocument(store: store)
        return AppModels(
            document: document, navigation: navigation, markup: markupModel, colorSettings: colorSettings,
            notesBrowser: notesBrowser, versions: versions, plans: plans, assistant: assistantModel, assistantSettings: assistantSettings,
            templates: templates, exporter: NotesExporter(markup: markupStore, bible: store))
    }

    /// One plain sentence per startup failure the reader can act on; the detail goes to the log.
    static func startupMessage(for error: Error) -> String {
        switch error as? BibleStoreError {
        case .databaseMissing:
            "The Bible text is missing from the app. Run Scripts/build-bible.sh, then build the app again."
        case .schemaMismatch:
            "The Bible text was built by an older version of the importer. Run Scripts/build-bible.sh, then build the app again."
        case nil:
            "Your notes and highlights could not be opened. Quit the app and open it again. If this keeps happening, check that the disk has free space."
        }
    }
}
