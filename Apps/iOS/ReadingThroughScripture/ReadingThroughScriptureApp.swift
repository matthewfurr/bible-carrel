import OSLog
import ScriptureUI
import SwiftUI
import UIKit

@main
struct ReadingThroughScriptureApp: App {
    @State private var models: AppModels?
    @State private var loadError: String?
    @State private var appSync: AppSync
    @State private var shell = PhoneShellModel()
    /// Settings › Reading › Appearance, this iPhone's own.
    @AppStorage(ReaderSettings.appearanceKey) private var appearance: AppearanceChoice = .system

    init() {
        PageFace.registerBundledFonts()
        let appSync = AppSync()
        _appSync = State(initialValue: appSync)
        // Before the container, so the monitor sees its setup event.
        appSync.start()
        // Before the reader is built, so it opens at a position the key-value store already holds.
        appSync.startPreferences()
        do {
            _models = State(initialValue: try AppModels.make(appSync: appSync))
        } catch {
            Self.startupLogger.error("Startup failed: \(error)")
            _loadError = State(initialValue: AppModels.startupMessage(for: error))
        }
    }

    private static let startupLogger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "startup")

    /// The reader's Settings: the Mac's panes, with the iCloud status and the backups from `appSync`,
    /// open at the page the reader asked for (More Settings… opens Reading).
    /// Made as the sheet presents, from the models captured when the root was built.
    private static func settingsScreen(_ models: AppModels, appSync: AppSync, shell: PhoneShellModel) -> PhoneSettingsScreen {
        PhoneSettingsScreen(
            translations: models.navigation.translations, sync: appSync.status, backups: appSync.backups,
            data: appSync.dataTransfer,
            colors: models.colorSettings, assistantSettings: models.assistantSettings, templates: models.templates,
            templatesRevision: appSync.templatesRevision, destination: shell.settingsDestination,
            onTemplatesChange: { [assistant = models.assistant] in assistant.reloadTemplates() })
    }

    var body: some Scene {
        WindowGroup {
            if let models {
                PhoneRootView(
                    navigation: models.navigation, document: models.document, markup: models.markup, notesBrowser: models.notesBrowser,
                    plans: models.plans, assistant: models.assistant, exporter: models.exporter, shell: shell,
                    settings: { [appSync, shell] in AnyView(Self.settingsScreen(models, appSync: appSync, shell: shell)) })
                .environment(\.noteVersions, models.versions)
                .followsPageFace()
                // The window's own style, so every sheet and menu over the page follows it, and
                // System hands it back to the device (`preferredColorScheme(nil)` leaves an open
                // sheet in the last style); Sepia as the window scene's trait.
                .onChange(of: appearance, initial: true) { _, choice in choice.apply() }
            } else {
                ContentUnavailableView {
                    Label("Could not open", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError ?? "The Bible text is missing from the app. Run Scripts/build-bible.sh, then build the app again.")
                }
            }
        }
    }
}
