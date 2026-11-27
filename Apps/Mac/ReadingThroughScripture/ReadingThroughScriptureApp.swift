import AppKit
import OSLog
import ScriptureData
import ScriptureLLM
import ScriptureModel
import ScriptureUI
import SwiftUI

@main
struct ReadingThroughScriptureApp: App {
    @State private var document: ReaderDocument?
    @State private var model: NavigationModel?
    @State private var markup: MarkupModel?
    @State private var colorSettings: ColorSettingsModel?
    @State private var notesBrowser: NotesBrowserModel?
    /// A note's versions, for the mark and the versions view in every window that shows notes.
    @State private var versions: NoteVersionsModel?
    @State private var plans: ReadingPlanModel?
    @State private var assistant: AssistantModel?
    @State private var assistantSettings: AssistantSettingsModel?
    @State private var templates: PromptTemplateStore?
    @State private var exporter: NotesExporter?
    /// Where a reference in a note leads, in every window that shows notes.
    @State private var noteLinks: NoteLinks?
    @State private var loadError: String?
    @State private var appSync: AppSync
    @AppStorage("showNotesColumn") private var showNotesColumn = true
    @AppStorage(ReaderSettings.appearanceKey) private var appearance: AppearanceChoice = .system
    @AppStorage(ReaderSettings.fontSizeKey) private var fontSize = ReaderSettings.defaultFontSize
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    init() {
        PageFace.registerBundledFonts()
        let appSync = AppSync()
        _appSync = State(initialValue: appSync)
        // Before the container, so the monitor sees its setup event.
        appSync.start()
        // Before the reader is built, so it opens at a position the key-value store already holds.
        appSync.startPreferences()
        do {
            let models = try AppModels.make(appSync: appSync)
            _document = State(initialValue: models.document)
            _model = State(initialValue: models.navigation)
            _markup = State(initialValue: models.markup)
            _colorSettings = State(initialValue: models.colorSettings)
            _assistant = State(initialValue: models.assistant)
            _notesBrowser = State(initialValue: models.notesBrowser)
            _versions = State(initialValue: models.versions)
            _plans = State(initialValue: models.plans)
            _assistantSettings = State(initialValue: models.assistantSettings)
            _templates = State(initialValue: models.templates)
            _exporter = State(initialValue: models.exporter)
            let navigation = models.navigation, markup = models.markup
            // Open on a note's reference shows the passage at that verse in the current
            // translation, as Open on a reply's reference does, in the main window.
            _noteLinks = State(initialValue: NoteLinks(navigation: navigation) { reference in
                guard let chapter = reference.chapter else { return }
                let target = MarkupTarget(location: ChapterLocation(book: reference.book.id, chapter: chapter),
                                          verse: reference.verse ?? 1, translationID: nil, highlightID: nil)
                MarkupNavigation.show(target, navigation: navigation, markup: markup)
                navigation.recordLookup(target.location, verse: reference.verse)
                NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("\(Self.mainWindowID)-") == true }?.makeKeyAndOrderFront(nil)
            })
        } catch {
            Self.startupLogger.error("Startup failed: \(error)")
            _loadError = State(initialValue: AppModels.startupMessage(for: error))
        }
    }

    private static let startupLogger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "startup")

    static let mainWindowID = "main"
    static let notesWindowID = "notes-browser"
    static let planWindowID = "reading-plan"

    /// Takes the reader to the item the way a card click does (a conversation also opens in the
    /// assistant's panel) and brings the main window forward; the Notes window stays open behind it.
    private func showInReader(_ target: MarkupTarget, model: NavigationModel, markup: MarkupModel) {
        MarkupNavigation.show(target, navigation: model, markup: markup)
        if let threadID = target.threadID { assistant?.open(threadID: threadID) }
        showMainWindow()
    }

    /// The main window, when one is open.
    private var mainWindow: NSWindow? {
        NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("\(Self.mainWindowID)-") == true })
    }

    /// Brings the main window forward and makes it key, opening it if it was closed.
    private func showMainWindow() {
        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: Self.mainWindowID)
        }
    }

    /// ⌘K. In the main window it shows or hides the palette. From another window (Notes,
    /// Settings) it first brings the main window forward and makes it key, so what is typed
    /// reaches the palette's field and not that window's list, then shows the palette; the other
    /// window stays open behind.
    private func togglePalette() {
        guard let model else { return }
        if mainWindow?.isKeyWindow == true {
            model.isPaletteShown.toggle()
            return
        }
        showMainWindow()
        model.isPaletteShown = true
    }

    /// ⌘/. When the shortcuts sheet is shown it hides it. Otherwise it closes the palette, brings
    /// the main window forward and key unless it already is (from Notes or Settings, as ⌘K does),
    /// and shows the sheet.
    private func toggleShortcuts() {
        guard let model else { return }
        if model.isShortcutsShown {
            model.isShortcutsShown = false
            return
        }
        model.isPaletteShown = false
        if mainWindow?.isKeyWindow != true { showMainWindow() }
        model.isShortcutsShown = true
    }

    /// Choosing one of the palette's rows shows it like the browser does (its mark rows are
    /// `AppModels.make`'s), and the commands open the app's other windows.
    private func wirePalette(model: NavigationModel, markup: MarkupModel) {
        model.showTarget = { target in showInReader(target, model: model, markup: markup) }
        model.appPaletteState = { paletteState() }
        wirePlans()
        // What its menu item or toolbar button runs; the model runs the rest (Home, Back, the
        // chapters, Read From Here, Text & Layout, Keyboard Shortcuts, Switch Translation, Clear Recents).
        model.performCommand = { command in
            let defaults = UserDefaults.standard
            switch command {
            case .notesBrowser: openWindow(id: Self.notesWindowID)
            case .readingPlan: openWindow(id: Self.planWindowID)
            case .settings: openSettings()
            case .showNotesColumn: showNotesColumn = true
            case .hideNotesColumn: showNotesColumn = false
            case .pageStyle(let style): defaults.set(style.rawValue, forKey: ReaderSettings.pageStyleKey)
            case .appearance(let choice): defaults.set(choice.rawValue, forKey: ReaderSettings.appearanceKey)
            case .largerText: stepText(by: 1)
            case .smallerText: stepText(by: -1)
            case .copyChapterLink:
                if let url = model.chapterLink, let link = PassageLink(url) {
                    MarkupContextMenu.write(PassageLinkClipboard(link: link, scheme: PassageLink.appScheme))
                }
            case .exportNotes: exportNotes(nil)
            case .exportAllData: exportAllData()
            case .importData: importData()
            case .toggleAssistant: toggleAssistant(markup: markup)
            case .newConversation: assistant?.newConversation()
            case .tryAgain: assistant?.retry()
            case .copyLastReply: copyLastReply()
            case .addLastReplyAsNote: assistant?.addLastReplyAsNote()
            case .stopAnswering: assistant?.stop()
            case .home, .back, .forward, .previousChapter, .nextChapter, .readFromHere, .textLayout,
                 .showShortcuts, .switchTranslation, .clearRecents:
                break
            }
        }
    }

    /// A passage opened from a plan brings the main window forward (opening it if it was closed).
    private func wirePlans() {
        plans?.onOpenPassage = { _ in showMainWindow() }
    }

    /// The app's half of what decides which palette commands can run: the stored settings and the assistant.
    private func paletteState() -> PaletteState {
        let defaults = UserDefaults.standard
        var state = PaletteState()
        state.isNotesColumnShown = defaults.object(forKey: "showNotesColumn") as? Bool ?? true
        state.pageStyle = defaults.string(forKey: ReaderSettings.pageStyleKey).flatMap(PageStyle.init(rawValue:)) ?? .printed
        state.appearance = defaults.string(forKey: ReaderSettings.appearanceKey).flatMap(AppearanceChoice.init(rawValue:)) ?? .system
        state.fontSize = ReaderSettings.clampedFontSize(defaults.object(forKey: ReaderSettings.fontSizeKey) as? Double ?? ReaderSettings.defaultFontSize)
        state.canRetry = assistant?.canRetry ?? false
        state.hasLastReply = assistant?.lastReplyID != nil
        state.lastReplyIsSaved = assistant?.lastReplySavedNoteID != nil
        state.isResponding = assistant?.isResponding ?? false
        state.canImportData = appSync.dataTransfer?.canImport ?? false
        return state
    }

    /// The save panel over the front window for everything the reader has made, as one JSON file.
    private func exportAllData() {
        guard let data = appSync.dataTransfer else { return }
        DataPanels.presentExport(in: NSApp.keyWindow, model: data)
    }

    /// The open panel over the front window; the import's sentence is shown as an alert.
    private func importData() {
        guard let data = appSync.dataTransfer, data.canImport else { return }
        DataPanels.presentImport(in: NSApp.keyWindow, model: data)
    }

    /// View › Larger Text and Smaller Text, and the palette's.
    private func stepText(by steps: Int) {
        fontSize = ReaderSettings.steppedFontSize(fontSize, by: steps)
    }

    /// As the toolbar button does: show the panel (on the selection, if any) or go back to Notes.
    private func toggleAssistant(markup: MarkupModel) {
        guard let assistant else { return }
        if assistant.isPanelShown {
            assistant.hidePanel()
        } else {
            assistant.openAskingForContext(selection: markup.currentSelection)
        }
    }

    /// Assistant › Copy Last Reply: the newest finished reply, as Copy in its row puts it.
    private func copyLastReply() {
        guard let text = assistant?.copyLastReply() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// The save panel over the front window, for the given entries or (nil) everything marked;
    /// bookmarks quote their verse in the translation being read.
    private func exportNotes(_ entries: [NotesBrowserEntry]?) {
        guard let exporter, let model else { return }
        let translationID = model.translationID
        ExportPanel.present(in: NSApp.keyWindow) { options in
            try exporter.output(entries: entries ?? exporter.allEntries(), options: options, currentTranslationID: translationID)
        }
    }

    var body: some Scene {
        WindowGroup("Bible Carrel", id: Self.mainWindowID) {
            if let document, let model, let markup, let assistant {
                MainWindowView(model: model, markup: markup, assistant: assistant, sync: appSync.status, plans: plans, document: document)
                    .environment(\.noteLinks, noteLinks)
                    .environment(\.noteVersions, versions)
                    .onAppear { wirePalette(model: model, markup: markup) }
                    // A passage link opens as a lookup in this window; preferring every event
                    // here keeps SwiftUI from making a second window for it.
                    .onOpenURL { model.openPassageLink($0) }
                    .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                    // One source for every window, sheet, popover and menu: the app's appearance,
                    // Sepia included (each scene's root follows it into SwiftUI).
                    .onChange(of: appearance, initial: true) { _, choice in choice.apply() }
                    .followsSepia()
                    .followsPageFace()
            } else {
                ContentUnavailableView {
                    Label("Could not open", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError ?? "The Bible text is missing from the app. Run Scripts/build-bible.sh, then build the app again.")
                } actions: {
                    Button("Quit") { NSApp.terminate(nil) }
                        .keyboardShortcut(.defaultAction)
                }
                .frame(minWidth: 480, minHeight: 320)
            }
        }
        .defaultSize(width: 1100, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .importExport) {
                Button("Export Notes…") { exportNotes(nil) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(exporter == nil || model == nil)
                Button("Export All Data…") { exportAllData() }
                    .disabled(appSync.dataTransfer == nil)
                Divider()
                Button("Import Data…") { importData() }
                    .disabled(!(appSync.dataTransfer?.canImport ?? false))
            }
            CommandMenu("Go") {
                Button("Home") { model?.goHome() }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                    .disabled(model == nil)
                Button("Back") { model?.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!(model?.canGoBack ?? false))
                Button("Forward") { model?.goForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!(model?.canGoForward ?? false))
                // A looked-up passage becomes the place being read; Back returns from it.
                Button("Read From Here") { model?.keepLookup() }
                    .disabled(!(model?.isLookingUp ?? false))
                Divider()
                Button("Previous Chapter") { model?.goToPreviousChapter() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                    .disabled(model?.previousChapter == nil)
                Button("Next Chapter") { model?.goToNextChapter() }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                    .disabled(model?.nextChapter == nil)
                Divider()
                Button("Go to Reference…") { togglePalette() }
                    .keyboardShortcut("k", modifiers: .command)
                    .disabled(model == nil)
            }
            // Into the system View menu, not a second one.
            CommandGroup(after: .toolbar) {
                TextLayoutMenuButton()
                Button("Larger Text") { stepText(by: 1) }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(fontSize >= ReaderSettings.fontSizeRange.upperBound)
                Button("Smaller Text") { stepText(by: -1) }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(fontSize <= ReaderSettings.fontSizeRange.lowerBound)
                Button(showNotesColumn ? "Hide Notes Column" : "Show Notes Column") { showNotesColumn.toggle() }
                    .keyboardShortcut("n", modifiers: [.command, .option])
                Button("Notes Browser") { openWindow(id: Self.notesWindowID) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(notesBrowser == nil)
                Button("Reading Plan") { openWindow(id: Self.planWindowID) }
                    .keyboardShortcut("p", modifiers: [.command, .option])
                    .disabled(plans == nil)
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") { toggleShortcuts() }
                    .keyboardShortcut("/", modifiers: .command)
                    .disabled(model == nil)
            }
            // Ruling 11. Prompt tiles get no shortcuts.
            CommandMenu("Assistant") {
                let inReader = assistant != nil && model?.screen == .reader
                // Stored on the model, so a streaming reply does not re-evaluate the menu per token.
                let hasLastReply = assistant?.lastReplyID != nil
                let lastReplySaved = assistant?.lastReplySavedNoteID != nil
                let isResponding = assistant?.isResponding ?? false
                Button(assistant?.isPanelShown == true ? "Show Notes" : "Show Assistant") {
                    if let markup { toggleAssistant(markup: markup) }
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(!inReader)
                Button("New Conversation…") { assistant?.newConversation() }
                    .keyboardShortcut("n", modifiers: [.command, .control])
                    .disabled(!inReader)
                Divider()
                Button("Try Again") { assistant?.retry() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(!inReader || !(assistant?.canRetry ?? false))
                Button("Copy Last Reply") { copyLastReply() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(!hasLastReply)
                // One note per reply: a saved reply offers Show Note in its row instead. Not while
                // a reply arrives, when the last finished one is no longer the one being read.
                Button("Add Last Reply as Note") { assistant?.addLastReplyAsNote() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(!inReader || !hasLastReply || lastReplySaved || isResponding)
                Divider()
                Button("Stop Answering") { assistant?.stop() }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(!isResponding)
            }
        }
        // One Notes window, reused while open.
        Window("Notes", id: Self.notesWindowID) {
            if let notesBrowser, let model, let markup {
                NotesBrowserView(model: notesBrowser) { target in
                    showInReader(target, model: model, markup: markup)
                } onExport: { entries in
                    exportNotes(entries)
                }
                .environment(\.noteLinks, noteLinks)
                .environment(\.noteVersions, versions)
                .followsSepia()
                .followsPageFace()
            }
        }
        // Wide enough for the filter's five segments beside the toolbar's other controls (six take a menu).
        .defaultSize(width: 1_100, height: 600)
        // One Reading Plan window, reused while open.
        Window("Reading Plan", id: Self.planWindowID) {
            if let plans {
                PlanWindowView(model: plans)
                    .onAppear { wirePlans() }
                    .followsSepia()
                    .followsPageFace()
            }
        }
        .defaultSize(width: 780, height: 560)
        Settings {
            if let colorSettings, let model, let assistantSettings, let templates {
                SettingsView(
                    colors: colorSettings, translations: model.translations,
                    assistantSettings: assistantSettings, templates: templates,
                    templatesRevision: appSync.templatesRevision,
                    onTemplatesChange: { assistant?.reloadTemplates() },
                    sync: appSync.status, backups: appSync.backups)
                .followsSepia()
                .followsPageFace()
            }
        }
    }
}
