#if os(iOS)
import ScriptureData
import ScriptureModel
import SwiftUI

/// The iPhone app's shell: Read, Plan, Notes and Ask, and the system search tab. Read shows the
/// reader, Plan the reading plan followed, Notes everything marked, Ask the assistant and search
/// one search for everything.
public struct PhoneRootView: View {
    @Bindable private var navigation: NavigationModel
    /// The book being read, laid out as one scroll (made once by the app).
    private let document: ReaderDocument
    private let markup: MarkupModel
    private let notesBrowser: NotesBrowserModel
    private let plans: ReadingPlanModel
    private let assistant: AssistantModel
    private let exporter: NotesExporter
    @Bindable private var shell: PhoneShellModel
    /// The app's `PhoneSettingsScreen` (the app owns sync), over the page while `shell.isSettingsShown`.
    /// Made as the sheet presents, so it opens at `shell.settingsDestination`.
    private let settings: () -> AnyView
    /// A conversation whose sheet over the page has gone while its reply was still arriving.
    @State private var releaseWhenAnswered: UUID?
    /// Library under a swipe's finger, and the edge swipes between the screens.
    @State private var librarySlide: LibrarySlide
    @State private var edgeSwipes: PhoneEdgeSwipes
    /// Where a reference in a note leads: its verses, and Open in Read, a lookup.
    @State private var noteLinks: NoteLinks
    /// The books opened and closed on the pages pushed inside Search, shared so Open in Read keeps those of the
    /// person or place it was opened from.
    @State private var searchPageMemory = PhoneLibraryPageMemory(opening: nil)

    public init(navigation: NavigationModel, document: ReaderDocument, markup: MarkupModel, notesBrowser: NotesBrowserModel,
                plans: ReadingPlanModel, assistant: AssistantModel, exporter: NotesExporter, shell: PhoneShellModel,
                settings: @escaping () -> AnyView) {
        self.navigation = navigation
        self.document = document
        self.markup = markup
        self.notesBrowser = notesBrowser
        self.plans = plans
        self.assistant = assistant
        self.exporter = exporter
        self.shell = shell
        self.settings = settings
        let slide = LibrarySlide()
        _librarySlide = State(initialValue: slide)
        _edgeSwipes = State(initialValue: PhoneEdgeSwipes(shell: shell, slide: slide))
        _noteLinks = State(initialValue: NoteLinks(navigation: navigation) { [navigation, shell] reference in
            guard let chapter = reference.chapter else { return }
            let location = ChapterLocation(book: reference.book.id, chapter: chapter)
            navigation.lookUp(location, verse: reference.verse)
            navigation.recordLookup(location, verse: reference.verse)
            shell.showInReader()
        })
    }

    /// The tabs, with Library over them when it is open: the screen to the left of Read, over the
    /// tab bar too. A swipe in from either edge moves one screen along (`PhoneEdgeSwipes`).
    public var body: some View {
        ZStack {
            tabs
                .accessibilityHidden(shell.isLibraryShown)
            PhoneLibraryLayer(navigation: navigation, markup: markup, shell: shell, slide: librarySlide)
        }
        .background { PhoneEdgeSwipeInstaller(swipes: edgeSwipes) }
        .environment(\.noteLinks, noteLinks)
        // A passage link (bible:// or, in Debug, bible-dev://) opens as a lookup on the page.
        .onOpenURL { url in
            if navigation.openPassageLink(url) { shell.showInReader() }
        }
        // The first swipe into Notes waited about 0.7 s (debug, simulator) while SwiftUI built
        // it, the screen standing still under the finger. Once the page has settled, a copy of
        // Notes is built out of sight and let go, so the tab's first build finds its fonts and
        // list machinery ready; then a copy of Plan, which is one swipe from Read too. Plan's
        // copy neither reloads the model nor takes the undo manager.
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            edgeSwipes.warmUp(PhoneNotesScreen(notesBrowser: notesBrowser, navigation: navigation, markup: markup,
                                               assistant: assistant, exporter: exporter, shell: shell))
            try? await Task.sleep(for: .milliseconds(200))
            edgeSwipes.warmUp(PhonePlanScreen.warmUpCopy(plans: plans, shell: shell))
        }
    }

    private var tabs: some View {
        TabView(selection: $shell.tab) {
            Tab("Read", systemImage: "book", value: PhoneTab.read) {
                PhoneReaderScreen(navigation: navigation, document: document, markup: markup, assistant: assistant, shell: shell)
            }
            Tab("Plan", systemImage: "calendar", value: PhoneTab.plan) {
                PhonePlanScreen(plans: plans, shell: shell)
            }
            Tab("Notes", systemImage: "note.text", value: PhoneTab.notes) {
                PhoneNotesScreen(notesBrowser: notesBrowser, navigation: navigation, markup: markup,
                                 assistant: assistant, exporter: exporter, shell: shell)
            }
            Tab("Ask", systemImage: "sparkles", value: PhoneTab.ask) {
                PhoneAskScreen(assistant: assistant, navigation: navigation, shell: shell)
            }
            Tab(value: PhoneTab.search, role: .search) {
                // A person or place found by name is pushed here, and what is walked to from them
                // (spec 6.6); a passage opened from one comes back to this stack (6.7).
                NavigationStack(path: $shell.searchPath) {
                    PhoneSearchScreen(navigation: navigation, shell: shell)
                        .navigationDestination(for: PhoneLibraryPage.self) { page in
                            PhoneLibraryPageView(page: page, navigation: navigation, shell: shell, path: $shell.searchPath)
                        }
                }
                .environment(searchPageMemory)
                // The pages' books opened and closed are forgotten with the pages.
                .onChange(of: shell.searchPath.isEmpty) { _, isEmpty in
                    if isEmpty { searchPageMemory = PhoneLibraryPageMemory(opening: nil) }
                }
                // On the search tab's own stack: on the tab view it reached every tab's navigation
                // bar too, putting a search field over the reader. The tab still becomes the bar's
                // search field.
                .searchable(text: $navigation.paletteQuery, prompt: "Search")
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
        }
        // Choosing the search tab activates search: the button appearance, not a landing page.
        .tabViewSearchActivation(.searchTabSelection)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Color.accent)
        // A reference tapped in the Ask tab. Over the page the conversation is already a sheet, so
        // it presents the verse itself; only one sheet is ever asked of each presenter.
        .sheet(item: versePreviewInAsk) { preview in
            PhoneVerseSheet(preview: preview, navigation: navigation, shell: shell)
        }
        // Bound to the shell, so Done or a swipe resets it and the next opening is a change; the
        // page it opened at is forgotten with it.
        .sheet(isPresented: $shell.isSettingsShown, onDismiss: { shell.settingsDismissed() }) { settings() }
        // ⌘K from any tab, as Go to Reference on the Mac: the search tab, its field active.
        .background {
            Button("Search") { shell.tab = .search }
                .keyboardShortcut("k", modifiers: .command)
                .hidden()
        }
        .onAppear {
            wireAssistant()
            wireSearch()
            wirePlans()
        }
        // A conversation asked over the page is let go when its sheet goes (Done, a swipe, Open
        // in Read, Add as Note), so the Ask tab opens on its own screen with it listed. A reply
        // still arriving finishes first. Here rather than in a tab, because the root is always live.
        .onChange(of: shell.askSheetThreadID) { old, new in
            guard let old, new == nil else { return }
            if assistant.isResponding {
                releaseWhenAnswered = old
            } else {
                release(old)
            }
        }
        .onChange(of: assistant.isResponding) { _, responding in
            guard !responding, let id = releaseWhenAnswered else { return }
            releaseWhenAnswered = nil
            release(id)
        }
    }

    /// Lets go of the conversation if it is still the open one.
    private func release(_ threadID: UUID) {
        guard assistant.thread?.id == threadID, !assistant.isResponding else { return }
        assistant.startNew(scope: .chapter)
    }

    /// A mark chosen in search shows as a Notes row does: its verse in the reader as a lookup, or
    /// its conversation in Ask.
    private func wireSearch() {
        navigation.showTarget = { [navigation, markup, assistant, shell] target in
            if let threadID = target.threadID {
                assistant.open(threadID: threadID)
                shell.tab = .ask
                return
            }
            MarkupNavigation.show(target, navigation: navigation, markup: markup)
        }
    }

    /// A passage opened from the Plan tab is read on the Read tab.
    private func wirePlans() {
        plans.onOpenPassage = { [shell] _ in shell.showInReader() }
    }

    private var versePreviewInAsk: Binding<VersePreview?> {
        Binding(get: { shell.tab == .ask ? shell.versePreview : nil }, set: { shell.versePreview = $0 })
    }

    /// Add as Note and Show Note open the note over the page, as the Mac returns to its column
    /// with the note in the editor. A note in a chapter other than the one loaded is shown as the
    /// Notes tab shows one, and opens once that chapter loads.
    private func wireAssistant() {
        assistant.onNoteSaved = { [navigation, markup, assistant, shell] noteID in
            shell.showInReader()
            MarkupNavigation.openSavedNote(noteID, at: assistant.noteTarget(noteID: noteID), navigation: navigation, markup: markup)
        }
    }
}
#endif
