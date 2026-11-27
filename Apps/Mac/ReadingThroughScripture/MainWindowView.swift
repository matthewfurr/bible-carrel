import AppKit
import ScriptureData
import ScriptureUI
import SwiftUI

/// The single window: front page or reader, the toolbar, and the ⌘K overlay.
struct MainWindowView: View {
    @Bindable var model: NavigationModel
    @Bindable var markup: MarkupModel
    @Bindable var assistant: AssistantModel
    /// The toolbar's iCloud notice reads it.
    let sync: SyncStatusModel
    /// The plan followed: the front page's "This week" band and the reader's button; nil until the store opens.
    let plans: ReadingPlanModel?
    @AppStorage("showNotesColumn") private var showNotesColumn = true
    @AppStorage(MarkupModel.showNotelessHighlightsKey) private var showNotelessHighlights = true
    @AppStorage(ReaderSettings.defaultTranslationKey) private var defaultTranslationID = ReaderSettings.defaultTranslationID
    @AppStorage(ReaderSettings.fontSizeKey) private var fontSize = ReaderSettings.defaultFontSize
    @AppStorage(ReaderSettings.lineSpacingKey) private var lineSpacing: LineSpacingChoice = .normal
    @AppStorage(ReaderSettings.pageStyleKey) private var pageStyle: PageStyle = .printed
    @AppStorage(ReaderSettings.pageFaceKey) private var pageFace = ""
    @AppStorage(ReaderSettings.columnWidthKey) private var columnWidth: ColumnWidthChoice = .normal
    @AppStorage(ReaderSettings.verseLayoutKey) private var verseLayout: VerseLayoutChoice = .paragraphs
    @AppStorage(ReaderSettings.showsVerseNumbersKey) private var showsVerseNumbers = true
    @AppStorage(ReaderSettings.showsSectionHeadingsKey) private var showsSectionHeadings = true
    @AppStorage(ReaderSettings.justifiedKey) private var justified = false
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.undoManager) private var undoManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Classic's later labels are at the system headline size, which a typography captures when
    /// it is made: a new Dynamic Type size makes a new one.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The chapters with a highlight, note or bookmark and their colours, read once each time the front page shows.
    @State private var chapterMarks: [ChapterLocation: ChapterMarks] = [:]
    /// Whether the reader's This Week popover shows.
    @State private var isPlanWeekShown = false
    /// Where the Text & Layout popover shows, if it does.
    @State private var textLayoutAnchor: TextLayoutAnchor?
    /// The reader's text takes the keyboard when this changes (`ReaderFocusRule`).
    @State private var readerFocus: ReaderFocusRequest?
    /// The verse panel asked for (C, R or the selection menu), shown in a popover on its verses'
    /// first line; nil when none is up.
    @State private var versePanelRequest: VersePanelRequest?
    /// The book being read, laid out as one scroll: a window of its chapters (normally all of
    /// them). Made once by the app, so recreating this view never rebuilds it.
    let document: ReaderDocument
    /// Made once per setting change, not per evaluation: building it makes fonts and colors, and
    /// the document's layout and the reader both compare it. Starts from the current settings
    /// through `typography(for:)`, so a window opened after a change starts with it.
    @State private var typography = Self.typography(for: ReaderPreferences.load(from: .standard))
    /// The settings `typography` was built from.
    @State private var typographyPreferences = ReaderPreferences.load(from: .standard)

    /// The last typography built and its settings, shared by every window: recreating this view
    /// (or opening another window) with the same settings reuses it instead of making fonts again,
    /// unless the system's headline size has changed since it was made.
    @MainActor private static var typographyCache: (preferences: ReaderPreferences, typography: ReaderTypography)?

    @MainActor private static func typography(for preferences: ReaderPreferences) -> ReaderTypography {
        if let cache = typographyCache, cache.preferences == preferences,
           cache.typography.headlineSize == ReaderTypography.systemHeadlineSize {
            return cache.typography
        }
        let typography = ReaderSettings.typography(preferences)
        typographyCache = (preferences, typography)
        return typography
    }

    /// What the markup model is loaded for; any change reloads it.
    private struct ChapterKey: Equatable {
        let location: ChapterLocation?
        let translationID: String
        let verses: [Verse]
    }

    private var chapterKey: ChapterKey {
        ChapterKey(location: model.location, translationID: model.translationID, verses: model.verses)
    }

    /// What the document shows: the book being read, the chapter in view and the typography.
    /// `BookText`'s own `==` compares only the book and the translation, so this never compares
    /// verses. The document rebuilds only when the book, translation, typography or window must
    /// change; scrolling from one chapter into the next does not.
    private struct DocumentKey: Equatable {
        let book: BookText?
        let location: ChapterLocation?
        let typography: ReaderTypography
    }

    /// The notes the column shows. When one comes or goes (a delete in the column, an undo), a
    /// reply saved as that note offers Add as Note or Show Note again as it should.
    private var columnNoteIDs: [UUID] {
        markup.columnItems.compactMap { item in
            if case .note(let card) = item { card.id } else { nil }
        }
    }

    /// Each chapter's chapter notes in the window, for the marks on the opening lines and in the
    /// running head. Only for the book and translation the document shows: between a new layout
    /// and the markup that follows it, the old book's counts would mark the new book's chapters.
    private var chapterNoteCounts: [Int: Int] {
        guard let id = document.layout?.id, markup.book == id.book, markup.translationID == id.translationID else { return [:] }
        return markup.notesByChapter.compactMapValues { notes in
            let count = notes.count { $0.isChapterNote }
            return count > 0 ? count : nil
        }
    }

    private var preferences: ReaderPreferences {
        ReaderPreferences(
            style: pageStyle, face: PageFace(rawValue: pageFace), fontSize: fontSize, lineSpacing: lineSpacing,
            columnWidth: columnWidth, layout: verseLayout, showsVerseNumbers: showsVerseNumbers,
            showsSectionHeadings: showsSectionHeadings, justified: justified)
    }

    var body: some View {
        page
            .frame(minWidth: 820, minHeight: 520)
            .tint(Color.accent)
            .navigationTitle(model.screen == .reader ? (model.chapterTitle ?? "Bible Carrel") : "Bible Carrel")
            .toolbar { toolbarContent }
            .overlay {
                if model.isPaletteShown {
                    paletteOverlay
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: model.isPaletteShown)
            // Deletes in the column and the context menu register here, so Edit › Undo brings them back.
            .onChange(of: undoManager, initial: true) { _, manager in
                markup.undoManager = manager
                assistant.undoManager = manager
            }
            .alert(
                "Could not save",
                isPresented: Binding(get: { markup.lastError != nil }, set: { if !$0 { markup.clearError() } }),
                presenting: markup.lastError
            ) { _ in
                Button("OK") { markup.clearError() }
            } message: { message in
                Text(message)
            }
            // Debounced: wait for typing to settle, so the list does not churn with each keystroke.
            // A new query, scope, order, chip or translation searches again (off the main actor).
            .task(id: model.paletteSearchKey) {
                guard model.isPaletteShown else { return }
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                await model.refreshPalette()
            }
            .onChange(of: model.isPaletteShown) { _, shown in
                if shown { model.updatePalette() }
            }
            .onChange(of: DocumentKey(book: model.bookText, location: model.location, typography: typography), initial: true) { _, key in
                guard let book = key.book, let location = key.location, location.book == book.book else { return }
                document.show(book, target: location, typography: key.typography)
            }
            // A new book, translation, chapter or typography: the chapter's markup, mapped onto
            // the new layout.
            .onChange(of: document.layout?.id, initial: true) { _, _ in markup.follow(model.location, in: document.layout) }
            // The open chapter moved (a navigation; the page holds one chapter, so a scroll never
            // moves it): the notes column and the assistant follow.
            .onChange(of: chapterKey, initial: true) { _, key in
                // A verse panel's range belongs to the page that was.
                versePanelRequest = nil
                if let location = key.location {
                    // Also reloads the chapter's markup if `clear` below emptied it while the
                    // document kept its layout (a translation that lacked the book, then back).
                    markup.follow(location, in: document.layout)
                } else {
                    // No chapter (the translation lacks it): an edit ends and the selection clears.
                    markup.clear(translationID: key.translationID)
                }
                assistant.setLocation(key.location, translationID: key.translationID, verses: key.verses)
            }
            // The panel lives in the inspector: showing it shows the inspector, and closing the
            // inspector puts the notes column back for next time.
            .onChange(of: assistant.isPanelShown) { _, shown in
                if shown { showNotesColumn = true }
            }
            .onChange(of: showNotesColumn) { _, shown in
                if !shown { assistant.hidePanel() }
            }
            .onAppear(perform: wireAssistant)
            // The View menu's Text & Layout (⌘T) reaches this window's popover; off the reader it is disabled.
            .focusedSceneValue(\.textLayoutAnchor, model.screen == .reader ? $textLayoutAnchor : nil)
            .onChange(of: model.screen) { _, screen in
                if screen != .reader {
                    textLayoutAnchor = nil
                    versePanelRequest = nil
                }
            }
            // The palette's Text & Layout: as the View menu's does.
            .onChange(of: model.textLayoutRequests) { _, _ in
                guard model.screen == .reader else { return }
                textLayoutAnchor = textLayoutAnchor != nil ? nil : (NSApp.keyWindow?.toolbar?.isVisible == true ? .toolbar : .page)
            }
            .onChange(of: columnNoteIDs) { _, _ in assistant.refresh() }
            // The contents' dots and the pane's rings: one query per visit to the front page.
            .onChange(of: model.screen, initial: true) { _, screen in
                if screen == .frontPage { chapterMarks = markup.chapterMarks() }
            }
            // Settings flips the key; the column re-reads it.
            .onChange(of: showNotelessHighlights) { _, _ in markup.reload() }
            // A font or spacing change re-lays the book out; stay at the verse being read.
            .onChange(of: preferences, initial: true) { old, prefs in syncTypography(prefs, changed: old != prefs) }
            // Settings › General: a new default also switches the reader, as the pill would.
            .onChange(of: defaultTranslationID) { _, id in model.setTranslation(id) }
            .sheet(isPresented: $markup.isAddColorSheetShown) {
                AddColorSheet(
                    onAdd: { name, lightHex, darkHex in
                        if let report = markup.pendingColorReport,
                           let touched = markup.addColorAndApply(name: name, lightHex: lightHex, darkHex: darkHex, to: report) {
                            markup.focus(highlightID: touched)
                        }
                        markup.pendingColorReport = nil
                        markup.isAddColorSheetShown = false
                    },
                    onCancel: {
                        markup.pendingColorReport = nil
                        markup.isAddColorSheetShown = false
                    })
            }
    }

    /// The screen, remade at a new Dynamic Type size (kept out of `body`'s chain, which is at the
    /// type checker's limit).
    private var page: some View {
        content(typography: typography)
            .onChange(of: dynamicTypeSize) { _, _ in dynamicTypeSizeChanged() }
            // The reader takes the keyboard back as the palette or the shortcuts close, or a note's
            // edit is finished, so its single keys work without a click.
            .onChange(of: model.isPaletteShown) { _, shown in
                if !shown { requestReaderFocus(.paletteClosed) }
            }
            .onChange(of: model.isShortcutsShown) { _, shown in
                if !shown { requestReaderFocus(.shortcutsClosed) }
            }
            .sheet(isPresented: $model.isShortcutsShown) {
                ShortcutsSheet { model.isShortcutsShown = false }
            }
            .onChange(of: markup.noteFinishCount) { _, _ in requestReaderFocus(.noteEditFinished) }
            .modifier(PlanWindowWiring(plans: plans, undoManager: undoManager, isWeekShown: $isPlanWeekShown))
            .onChange(of: model.screen) { _, screen in
                if screen != .reader { isPlanWeekShown = false }
            }
    }

    /// A new request for the reader's text to take the keyboard.
    private func requestReaderFocus(_ reason: ReaderFocusRule.Reason) {
        readerFocus = ReaderFocusRequest(reason: reason, serial: (readerFocus?.serial ?? 0) + 1)
    }

    /// The verse panel asked for, in the popover the reader shows on its verses; the reader's own
    /// close (Esc, a click outside) and each of the panel's actions clear the request.
    private var versePanelPresentation: VersePanelPresentation? {
        guard let request = versePanelRequest else { return nil }
        return VersePanelPresentation(request: request, content: versePanelContent(for: request),
                                      // A late close of an earlier popover leaves a newer request alone.
                                      onClose: { if versePanelRequest?.id == request.id { versePanelRequest = nil } })
    }

    private func versePanelContent(for request: VersePanelRequest) -> AnyView {
        let selection = request.selection
        switch request.kind {
        case .compare:
            return AnyView(CompareTranslationsPanel(
                selection: selection, navigation: model,
                // The verse in that translation, as a lookup: Back returns. The row being read only closes.
                onOpen: { row in
                    versePanelRequest = nil
                    guard row.looksUp else { return }
                    model.lookUp(selection.chapterLocation, verse: selection.verse, translationID: row.translationID)
                },
                onAsk: { comparison in
                    versePanelRequest = nil
                    assistant.compareTranslations(comparison.selection, translationIDs: comparison.otherTranslationIDs)
                }))
        case .crossReferences:
            return AnyView(CrossReferencesPanel(
                verse: request.verse, navigation: model, showsPassageInPlace: true,
                // Open on a passage shown in place: a lookup in the translation being read, recorded
                // in Recents as a reference in a note is.
                onOpen: { reference in
                    versePanelRequest = nil
                    model.lookUpPassage(reference)
                },
                onAsk: { references in
                    guard let selection = references.selection, let question = model.crossReferenceQuestion(references) else { return }
                    versePanelRequest = nil
                    assistant.ask(about: selection, sending: question, shownAs: CrossReferences.askTitle)
                }))
        }
    }

    @ViewBuilder
    private func content(typography: ReaderTypography) -> some View {
        switch model.screen {
        case .frontPage:
            FrontPageView(navigation: model, marks: chapterMarks, plans: plans, onShowWholePlan: showWholePlan, onOpenSettings: {
                UserDefaults.standard.set("general", forKey: SettingsView.tabKey)
                openSettings()
            }, readerSize: ReaderSettings.clampedFontSize(fontSize))
        case .reader:
            ReaderView(
                document: document,
                scrollTarget: model.scrollTarget,
                onReadingPositionChange: { model.reportReadingPosition($0) },
                onScrollSinceJump: { model.reportLinesScrolledSinceJump($0, from: $1) },
                onHeadingTap: { model.goHome() },
                onAskAboutChapter: { assistant.askAboutChapter() },
                previousChapterTitle: model.previousChapter.map(model.title(for:)),
                onPreviousChapter: { model.goToPreviousChapter() },
                nextChapterTitle: model.nextChapter.map(model.title(for:)),
                onNextChapter: { model.goToNextChapter() },
                typography: typography,
                markup: ReaderMarkup(
                    decorations: markup.bookDecorations,
                    onSelectionChange: { markup.setSelection($0) },
                    menuProvider: { report, controller in
                        MarkupContextMenu.make(for: report, model: markup, controller: controller)
                    },
                    onKey: { action, report, controller in
                        ReaderKeyCommands.perform(action, report: report, markup: markup, navigation: model, controller: controller)
                    },
                    // No reader key while ⌘K shows or a note is being edited: the letters are typing.
                    keysAreLive: { ReaderKeyCommands.keysAreLive(markup: markup, navigation: model) }),
                chapterNoteCounts: chapterNoteCounts,
                onShowChapterNotes: showChapterNotes,
                bookThumb: model.bookThumb,
                onThumbLand: landThumb,
                focusRequest: readerFocus,
                versePanel: versePanelPresentation)
            // With the toolbar hidden, ⌘T shows Text & Layout from the page's top trailing corner.
            .overlay(alignment: .topTrailing) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .padding(.trailing, AppSpacing.xxl)
                    .popover(isPresented: textLayoutShown(at: .page), arrowEdge: .bottom) { TextLayoutPopover() }
                    .accessibilityHidden(true)
            }
            // A reader view recreated after Home or a reopened window resumes at the last visible verse.
            .onAppear { model.resumeReading() }
            // The system inspector: resizable, its own panel surface, toggled by ⌥⌘N or the toolbar.
            .inspector(isPresented: $showNotesColumn) {
                InspectorContentView(markup: markup, assistant: assistant, onOpenSettings: {
                    UserDefaults.standard.set("assistant", forKey: SettingsView.tabKey)
                    openSettings()
                })
                    .inspectorColumnWidth(min: 260, ideal: 320, max: 480)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { model.goHome() } label: { Label("Home", systemImage: "house") }
                .help("Home (⇧⌘H)")
            Button { model.goBack() } label: { Label("Back", systemImage: "chevron.left") }
                .disabled(!model.canGoBack)
                .help("Back (⌘[)")
            Button { model.goForward() } label: { Label("Forward", systemImage: "chevron.right") }
                .disabled(!model.canGoForward)
                .help("Forward (⌘])")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            // Only after a day of failed sync; offline never counts.
            if sync.needsAttention {
                SyncAttentionButton(status: sync) {
                    UserDefaults.standard.set("general", forKey: SettingsView.tabKey)
                    openSettings()
                }
            }
            Menu {
                ForEach(model.translations) { translation in
                    Button {
                        model.setTranslation(translation.id)
                    } label: {
                        if translation.id == model.translationID {
                            Label(translation.title, systemImage: "checkmark")
                        } else {
                            Text(translation.title)
                        }
                    }
                }
            } label: {
                Label(model.translationID, systemImage: "chevron.up.chevron.down")
                    .labelStyle(.titleAndIcon)
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .help("Translation")
            if let plans, plans.showsWeek {
                planWeekButton(plans)
            }
            // Every reading setting beside the page it changes. ⌘T is the View menu's (it works
            // with the toolbar hidden), so it is not registered here a second time.
            Button { textLayoutAnchor = textLayoutAnchor == nil ? .toolbar : nil } label: {
                Label("Text & Layout", systemImage: "textformat.size")
            }
            .help("Text & Layout (⌘T)")
            .disabled(model.screen != .reader)
            .popover(isPresented: textLayoutShown(at: .toolbar), arrowEdge: .bottom) { TextLayoutPopover() }
            Button { model.isPaletteShown.toggle() } label: { Label("Go to Reference", systemImage: "magnifyingglass") }
                .help("Go to Reference (⌘K)")
            Button { showNotesColumn.toggle() } label: { Label("Notes Column", systemImage: "sidebar.right") }
                .help(showNotesColumn ? "Hide Notes Column (⌥⌘N)" : "Show Notes Column (⌥⌘N)")
                .disabled(model.screen != .reader)
            Button { toggleAssistant() } label: { Label("Assistant", systemImage: "sparkles") }
                .help(assistant.isPanelShown ? "Show Notes (⇧⌘A)" : "Ask the Assistant (⇧⌘A)")
                .disabled(model.screen != .reader)
            Button { openWindow(id: ReadingThroughScriptureApp.notesWindowID) } label: { Label("Notes Browser", systemImage: "note.text") }
                .help("Notes Browser (⇧⌘N)")
        }
    }

    /// This week in the reader: what the front page's band holds, in a popover under the button.
    /// Dimmed off the reader, where the band is; a passage or the whole plan opened closes it.
    private func planWeekButton(_ plans: ReadingPlanModel) -> some View {
        Button { isPlanWeekShown.toggle() } label: { Label("This Week", systemImage: "calendar") }
            .help("This week's readings")
            .disabled(model.screen != .reader)
            .popover(isPresented: $isPlanWeekShown, arrowEdge: .bottom) {
                PlanWeekPopover(model: plans, onShowWholePlan: showWholePlan, onDone: { isPlanWeekShown = false })
            }
    }

    /// The band's and the popover's "The whole plan" (⌥⌘P).
    private func showWholePlan() {
        openWindow(id: ReadingThroughScriptureApp.planWindowID)
    }

    /// Whether the Text & Layout popover shows at `anchor`; closing it clears the anchor.
    private func textLayoutShown(at anchor: TextLayoutAnchor) -> Binding<Bool> {
        Binding(
            get: { textLayoutAnchor == anchor },
            set: { shown in
                if !shown, textLayoutAnchor == anchor { textLayoutAnchor = nil }
            })
    }

    /// Rebuilds the typography when the settings differ from those it was built from (a change,
    /// or a window opened after one); a change also re-targets the verse being read.
    private func syncTypography(_ prefs: ReaderPreferences, changed: Bool) {
        guard prefs != typographyPreferences else { return }
        typographyPreferences = prefs
        typography = Self.typography(for: prefs)
        if changed { model.resumeReading() }
    }

    /// A new Dynamic Type size: a typography at the new headline size (Classic's running head is
    /// set at it). The page is laid out again only if its layout changed; the page itself sets
    /// nothing at the headline size.
    private func dynamicTypeSizeChanged() {
        let made = Self.typography(for: typographyPreferences)
        guard made.headlineSize != typography.headlineSize || made.layoutHash != typography.layoutHash else { return }
        let relays = made.layoutHash != typography.layoutHash
        typography = made
        if relays { model.resumeReading() }
    }

    /// ⇧⌘A, the toolbar and the palette: show the panel (asking about the selection when there
    /// is one, else whether to include where the reader is) or go back to Notes.
    private func toggleAssistant() {
        if assistant.isPanelShown {
            assistant.hidePanel()
        } else {
            assistant.openAskingForContext(selection: markup.currentSelection)
        }
    }

    /// A chapter-note mark: the notes column on the mark's chapter (a later chapter's mark, not
    /// only the chapter in view's), where the chapter notes come first. It shows the inspector if
    /// it is hidden and turns it from the assistant back to the notes if the panel has it; an
    /// open column stays open.
    private func showChapterNotes(chapter: Int) {
        markup.showChapterNotes(chapter: chapter)
        if assistant.isPanelShown { assistant.hidePanel() }
        showNotesColumn = true
    }

    /// Letting go of the book thumb on another chapter: it opens at its start, through the
    /// history, as choosing it from the grid does.
    private func landThumb(on chapter: Int) {
        guard let book = model.location?.book else { return }
        model.open(ChapterLocation(book: book, chapter: chapter))
    }

    /// The context menu asks about a selection; Add as Note (and Show Note) returns to the column
    /// with the note in the editor and its highlight lit. A note in another chapter (a book
    /// thread saves to the chapter asked in; a thread stays open as the reader moves on) is
    /// shown as the Notes browser shows one, and its editor opens once that chapter loads.
    private func wireAssistant() {
        markup.onAskAboutPassage = { assistant.ask(about: $0) }
        // Compare Translations and Cross-References (C, R, the selection menu): a popover on the verses.
        markup.onVersePanel = { kind, report in versePanelRequest = VersePanelRequest(kind: kind, report: report) }
        // A note added (N, or the context menu's Add Note) shows in the notes column, as a
        // chapter-note mark shows the column: the assistant's panel gives way to it.
        markup.onShowNotesColumn = {
            if assistant.isPanelShown { assistant.hidePanel() }
            showNotesColumn = true
        }
        assistant.onNoteSaved = { noteID in
            assistant.hidePanel()
            MarkupNavigation.openSavedNote(noteID, at: assistant.noteTarget(noteID: noteID), navigation: model, markup: markup)
        }
        // Open on a reference's preview shows the passage at that verse in the current
        // translation, as the Notes browser shows a note; the conversation stays open.
        assistant.onOpenPassage = { reference in
            guard let chapter = reference.chapter else { return }
            let target = MarkupTarget(location: ChapterLocation(book: reference.book.id, chapter: chapter),
                                      verse: reference.verse ?? 1, translationID: nil, highlightID: nil)
            MarkupNavigation.show(target, navigation: model, markup: markup)
            model.recordLookup(target.location, verse: reference.verse)
        }
    }

    /// Nothing dims: a clear layer behind the panel takes a click outside it, which closes the
    /// palette and does nothing else.
    private var paletteOverlay: some View {
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { model.isPaletteShown = false }
                .accessibilityHidden(true)
            CommandPaletteView(model: model)
            .padding(.top, AppSpacing.xxxl + AppSpacing.md)
            .accessibilityAddTraits(.isModal)
        }
    }
}

/// Where the Text & Layout popover shows: under its toolbar button, or (the toolbar hidden, so the
/// button has nowhere to show) from the page's top trailing corner.
enum TextLayoutAnchor: Equatable {
    case toolbar, page
}

extension FocusedValues {
    /// The key window's Text & Layout popover, while it shows the reader.
    @Entry var textLayoutAnchor: Binding<TextLayoutAnchor?>?
}

/// View › Text & Layout (⌘T): shows or hides the popover, under the toolbar button when the
/// toolbar is visible and from the page otherwise.
struct TextLayoutMenuButton: View {
    @FocusedValue(\.textLayoutAnchor) private var anchor

    var body: some View {
        Button("Text & Layout") {
            guard let anchor else { return }
            if anchor.wrappedValue != nil {
                anchor.wrappedValue = nil
            } else {
                anchor.wrappedValue = NSApp.keyWindow?.toolbar?.isVisible == true ? .toolbar : .page
            }
        }
        .keyboardShortcut("t", modifiers: .command)
        .disabled(anchor == nil)
    }
}

/// The plan model's undo is this window's while it is key or newly given a manager (the band and
/// the popover tick here), and handed back as the window goes, so it never lands in a closed window.
/// A tick or a date from the band or the popover that could not be saved is said here while this
/// window is in front. The key state is read here, not in the window's body, so a change of key
/// window does not run that body again.
private struct PlanWindowWiring: ViewModifier {
    let plans: ReadingPlanModel?
    let undoManager: UndoManager?
    @Binding var isWeekShown: Bool
    @Environment(\.controlActiveState) private var activeState

    func body(content: Content) -> some View {
        content
            .onChange(of: undoManager, initial: true) { old, manager in
                plans?.releaseUndoManager(old)
                plans?.adoptUndoManager(manager)
            }
            .onChange(of: activeState) { _, state in
                if state == .key { plans?.adoptUndoManager(undoManager) }
            }
            .onDisappear { plans?.releaseUndoManager(undoManager) }
            // The button goes when no week shows; its popover goes with it and does not come back by itself.
            .onChange(of: plans?.showsWeek) { _, shows in
                if shows != true { isWeekShown = false }
            }
            .alert(
                "Could not save",
                isPresented: Binding(get: { plans?.lastError != nil && activeState == .key },
                                     set: { if !$0 { plans?.clearError() } }),
                presenting: plans?.lastError
            ) { _ in
                Button("OK") { plans?.clearError() }
            } message: { message in
                Text(message)
            }
    }
}
