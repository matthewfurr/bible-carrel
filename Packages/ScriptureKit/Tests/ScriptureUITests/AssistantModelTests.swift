import Foundation
import ScriptureData
import ScriptureLLM
import ScriptureModel
import SwiftData
import Testing
@testable import ScriptureUI

/// Who answers, swappable between sends.
@MainActor private final class ProviderBox {
    var providers: [any LLMProvider] = []
}

@MainActor private final class Counter {
    var count = 0
}

/// An on-device provider whose deltas arrive only when the test releases them, so stopping
/// mid-reply does not depend on timing.
private final class GatedProvider: LLMProvider, @unchecked Sendable {
    let id: LLMProviderID = .appleOnDevice
    let modelName = "apple-on-device"
    let maxContextTokens: Int? = 4096
    let availability: LLMAvailability = .available
    private var continuation: AsyncThrowingStream<LLMEvent, any Error>.Continuation?
    private var streams = 0
    private let lock = NSLock()

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, any Error> {
        AsyncThrowingStream { continuation in
            lock.withLock {
                self.continuation = continuation
                streams += 1
            }
        }
    }

    var isAsked: Bool {
        lock.withLock { continuation != nil }
    }

    /// How many replies have been asked for; `release` and `finish` act on the latest.
    var streamCount: Int {
        lock.withLock { streams }
    }

    func release(_ text: String) {
        _ = lock.withLock { continuation }?.yield(.textDelta(text))
    }

    func finish() {
        lock.withLock { continuation }?.finish()
    }
}

/// The fixture has Matthew 1-6 in WEB and KJV and, in KJV only, long Psalms 118 and 119.
@MainActor @Suite struct AssistantModelTests {
    private let matthew5 = ChapterLocation(book: "MAT", chapter: 5)

    /// Holds the container: a `ModelContext` does not keep its container alive.
    private struct Harness {
        let container: ModelContainer
        let markup: MarkupStore
        let bible: BibleStore
        let model: AssistantModel
        let box: ProviderBox
        let defaults: UserDefaults
        let markupChanges: Counter
        let templates: PromptTemplateStore
    }

    private func make(_ providers: [any LLMProvider] = []) throws -> Harness {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let markup = MarkupStore(container: container)
        let templates = PromptTemplateStore(container: container)
        try templates.seedIfNeeded(BuiltInPrompts.all)
        let bible = try FixtureStore.make()
        let name = "AssistantModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let box = ProviderBox()
        box.providers = providers
        let counter = Counter()
        let model = AssistantModel(markup: markup, templates: templates, bible: bible, secrets: InMemorySecretStore(), defaults: defaults,
                                   providerFactory: { box.providers }, onMarkupChange: { counter.count += 1 })
        model.reloadTemplates()
        model.setLocation(matthew5, translationID: "WEB", verses: try bible.chapter(matthew5, translationID: "WEB"))
        return Harness(container: container, markup: markup, bible: bible, model: model, box: box, defaults: defaults, markupChanges: counter, templates: templates)
    }

    private func onDevice(_ deltas: [String] = ["Bles", "sed."], failure: LLMProviderError? = nil) -> FakeProvider {
        FakeProvider(id: .appleOnDevice, modelName: "apple-on-device", maxContextTokens: 4096, deltas: deltas, failure: failure)
    }

    /// "Blessed" at the start of Matthew 5:3.
    private func blessed(primary: UUID? = nil) -> SelectionReport {
        SelectionReport(
            selection: TextSelection(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, quotedText: "Blessed"),
            range: NSRange(location: 0, length: 7), highlightIDs: primary.map { [$0] } ?? [], primaryHighlightID: primary)
    }

    /// Waits for the reply to finish, up to two seconds.
    private func settle(_ model: AssistantModel) async throws {
        for _ in 0..<200 where model.isResponding {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Until `provider` has been asked for its `count`th reply.
    private func waitForStream(_ provider: GatedProvider, count: Int) async throws {
        for _ in 0..<200 where provider.streamCount < count {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(provider.streamCount == count)
    }

    private func templateID(_ model: AssistantModel, _ title: String) -> UUID {
        model.prompts.first { $0.title == title }!.id
    }

    private func askWhy(_ h: Harness, primary: UUID? = nil) async throws {
        h.model.ask(about: blessed(primary: primary))
        h.model.draft = "Why?"
        h.model.send()
        try await settle(h.model)
    }

    // MARK: - Ways in

    @Test func askingAboutASelectionShowsThePromptsWithoutAThread() throws {
        let h = try make([onDevice()])
        h.model.ask(about: blessed())
        #expect(h.model.isPanelShown && h.model.pendingScope == .selection && h.model.thread == nil)
        #expect(h.model.prompts.map(\.title) == ["Explain this passage", "Define the words", "Compare translations"])
        #expect(h.model.composerPlaceholder == "Ask about Matthew 5:3")
        #expect(try h.markup.chat.allThreads().isEmpty)
    }

    @Test func askingAboutTheChapterListsTheChapterPrompts() throws {
        let h = try make([onDevice()])
        h.model.askAboutChapter()
        #expect(h.model.isPanelShown && h.model.pendingScope == .chapter && h.model.prompts.count == 11)
        #expect(h.model.composerPlaceholder == "Ask about Matthew 5")
    }

    @Test func openingByShortcutAsksForContextFirst() async throws {
        let provider = onDevice()
        let h = try make([provider])
        h.model.openAskingForContext(selection: nil)
        #expect(h.model.isPanelShown && h.model.isAskingForContext && h.model.prompts.isEmpty && h.model.pendingScope == nil)
        h.model.chooseContext(.general)
        #expect(!h.model.isAskingForContext && h.model.pendingScope == .general && h.model.composerPlaceholder == "Ask anything")
        h.model.draft = "q"
        h.model.send()
        try await settle(h.model)
        #expect(!provider.requests[0].instructions.contains("Matthew"))
        #expect(provider.requests[0].messages.map(\.content) == ["q"])
        #expect(h.model.thread?.scope == .general && h.model.history.map(\.id) == [h.model.thread!.id])
    }

    @Test func aShortcutWithASelectionAsksAboutIt() throws {
        let h = try make([onDevice()])
        h.model.openAskingForContext(selection: blessed())
        #expect(!h.model.isAskingForContext && h.model.pendingScope == .selection)
    }

    // MARK: - The phone's Ask tab

    @Test func allThreadsListsEveryChapterNewestFirst() throws {
        let h = try make([onDevice()])
        let psalm = try h.markup.chat.createThread(
            scope: .chapter, book: "PSA", chapter: 23, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0,
            translationID: "KJV", quotedText: "", title: "The shepherd")
        psalm.updatedAt = Date(timeIntervalSinceNow: -60)
        let john = try h.markup.chat.createThread(
            scope: .chapter, book: "JHN", chapter: 15, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0,
            translationID: "WEB", quotedText: "", title: "Abide")
        john.updatedAt = Date()
        h.model.setLocation(ChapterLocation(book: "JHN", chapter: 15), translationID: "WEB", verses: [])
        #expect(h.model.history.map(\.id) == [john.uuid])
        #expect(h.model.allThreads.map(\.id) == [john.uuid, psalm.uuid])
    }

    @Test func startNewGeneralSendsNoPassage() async throws {
        let provider = onDevice()
        let h = try make([provider])
        h.model.startNew(scope: .general)
        #expect(h.model.pendingScope == .general && h.model.thread == nil)
        #expect(!h.model.isPanelShown && !h.model.isAskingForContext)
        #expect(h.model.prompts.isEmpty && h.model.composerPlaceholder == "Ask anything")
        h.model.draft = "Who wrote Hebrews?"
        h.model.send()
        try await settle(h.model)
        let request = try #require(provider.requests.first)
        #expect(request.messages.map(\.content) == ["Who wrote Hebrews?"])
        #expect(!request.instructions.contains("Matthew"))
        #expect(!request.messages.contains { $0.content.contains("Blessed are the poor") })
        #expect(h.model.thread?.scope == .general && h.model.allThreads.map(\.id) == [h.model.thread!.id])
    }

    @Test func startNewChapterUsesTheCurrentChapter() async throws {
        let provider = onDevice()
        let h = try make([provider])
        h.model.ask(about: blessed())
        h.model.startNew(scope: .chapter)
        #expect(h.model.pendingScope == .chapter && h.model.thread == nil && h.model.quotedText == nil)
        #expect(!h.model.isAskingForContext)
        #expect(h.model.prompts.count == 11 && h.model.composerPlaceholder == "Ask about Matthew 5")
        h.model.draft = "What is this chapter about?"
        h.model.send()
        try await settle(h.model)
        let request = try #require(provider.requests.first)
        #expect(request.messages.last?.content.hasPrefix("Here is Matthew 5 (WEB):") == true)
        #expect(request.messages.last?.content.hasSuffix("What is this chapter about?") == true)
        #expect(h.model.thread?.scope == .chapter && h.model.thread?.referenceString == "Matthew 5")
    }

    // MARK: - Following the open chapter

    /// Ask About This Chapter, nothing sent yet, follows the reader to another chapter: the
    /// composer names the new chapter, and a prompt run there asks about it, with its verses
    /// (parked 2026-11-13: nothing tested this).
    @Test func askingAboutTheChapterFollowsAChapterChange() async throws {
        let provider = onDevice()
        let h = try make([provider])
        h.model.askAboutChapter()
        #expect(h.model.composerPlaceholder == "Ask about Matthew 5")
        let matthew6 = ChapterLocation(book: "MAT", chapter: 6)
        h.model.setLocation(matthew6, translationID: "WEB", verses: try h.bible.chapter(matthew6, translationID: "WEB"))
        #expect(h.model.pendingScope == .chapter && h.model.thread == nil)
        #expect(h.model.composerPlaceholder == "Ask about Matthew 6")
        h.model.runPrompt(templateID(h.model, "Summarize this chapter"))
        try await settle(h.model)
        #expect(h.model.thread?.scope == .chapter && h.model.thread?.referenceString == "Matthew 6")
        #expect(provider.requests[0].instructions.contains("Matthew 6"))
        #expect(!provider.requests[0].instructions.contains("Matthew 5"))
    }

    /// The open chapter moved (a navigation: the reader shows one chapter, so a scroll never
    /// moves it). A chapter conversation closes while the panel is hidden.
    @Test func navigatingStillClosesAChapterConversationWhileThePanelIsHidden() async throws {
        let h = try make([onDevice()])
        h.model.askAboutChapter()
        h.model.runPrompt(templateID(h.model, "Summarize this chapter"))
        try await settle(h.model)
        h.model.hidePanel()
        let matthew6 = ChapterLocation(book: "MAT", chapter: 6)
        h.model.setLocation(matthew6, translationID: "WEB", verses: try h.bible.chapter(matthew6, translationID: "WEB"))
        #expect(h.model.thread == nil)
    }

    // MARK: - Sending

    @Test func sendingCreatesTheThreadStreamsAReplyAndPersistsIt() async throws {
        let provider = onDevice()
        let h = try make([provider])
        try await askWhy(h)
        #expect(h.model.thread?.scope == .selection && h.model.thread?.referenceString == "Matthew 5:3")
        #expect(h.model.thread?.title == "Matthew 5:3 · Blessed")
        #expect(h.model.messages.map(\.role) == [.user, .assistant])
        #expect(h.model.messages.map(\.content) == ["Why?", "Blessed."])
        #expect(h.model.messages[1].providerLabel == "On-device" && !h.model.messages[1].isStreaming)
        #expect(try h.markup.chat.allThreads()[0].orderedMessages.count == 2)
        #expect(provider.requests[0].instructions.contains("Matthew 5:3 in the WEB"))
        #expect(provider.requests[0].messages.last?.content == "Why?")
        #expect(h.model.history.count == 1 && h.model.prompts.isEmpty && h.model.draft.isEmpty)
    }

    @Test func aFollowUpSendsTheWholeThread() async throws {
        let provider = onDevice()
        let h = try make([provider])
        try await askWhy(h)
        h.model.draft = "And then?"
        h.model.send()
        try await settle(h.model)
        #expect(provider.requests[1].messages.map(\.content) == ["Why?", "Blessed.", "And then?"])
        #expect(h.model.messages.count == 4)
    }

    @Test func aChapterPromptFillsTheTemplateAndTitlesTheThread() async throws {
        let h = try make([onDevice()])
        h.model.askAboutChapter()
        h.model.runPrompt(templateID(h.model, "Summarize this chapter"))
        try await settle(h.model)
        #expect(h.model.thread?.title == "Summarize this chapter: Matthew 5" && h.model.thread?.scope == .chapter)
        #expect(h.model.messages[0].content.hasPrefix("Here is Matthew 5 (WEB):\n\n1 "))
        #expect(h.model.messages[0].displayText == "Summarize this chapter")
        #expect(h.model.prompts.isEmpty)
    }

    @Test func catchMeUpAbridgesThePreviousChapterWhenOnDeviceCannotFit() async throws {
        let small = onDevice()
        let h = try make([small])
        let psalm119 = ChapterLocation(book: "PSA", chapter: 119)
        h.model.setLocation(psalm119, translationID: "KJV", verses: try h.bible.chapter(psalm119, translationID: "KJV"))
        h.model.askAboutChapter()
        h.model.runPrompt(templateID(h.model, "Catch me up"))
        try await settle(h.model)
        let abridged = try #require(small.requests.last?.messages.last?.content)
        #expect(abridged.contains("\n…\n") && abridged.contains("psalm 118 verse 5.") && !abridged.contains("psalm 118 verse 6."))

        let cloud = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", deltas: ["ok"])
        h.box.providers = [small, cloud]
        h.model.askAboutChapter()
        h.model.runPrompt(templateID(h.model, "Catch me up"))
        try await settle(h.model)
        let full = try #require(cloud.requests.last?.messages.last?.content)
        #expect(full.contains("psalm 118 verse 6.") && !full.contains("\n…\n"))
        #expect(h.model.messages.last?.providerLabel == "Claude · claude-opus-5-5")
    }

    @Test func compareTranslationsListsAtMostThreeOnDevice() async throws {
        let provider = onDevice()
        let h = try make([provider])
        h.model.ask(about: blessed())
        h.model.runPrompt(templateID(h.model, "Compare translations"))
        try await settle(h.model)
        let content = try #require(provider.requests.last?.messages.last?.content)
        #expect(content.contains("KJV\n3 Blessed are the poor in spirit: for theirs"))
        #expect(h.model.thread?.title == "Matthew 5:3 · Blessed" && h.model.messages[0].displayText == "Compare translations")
    }

    @Test func thePromptFromTheAssistantsListSendsTheCompareSet() async throws {
        let provider = onDevice()
        let h = try make([provider])
        func run() async throws -> String {
            h.model.ask(about: blessed())
            h.model.runPrompt(templateID(h.model, "Compare translations"))
            try await settle(h.model)
            return try #require(provider.requests.last?.messages.last?.content)
        }
        h.defaults.set("NASB,KJV", forKey: CompareSet.key)
        let chosen = try await run()
        h.defaults.set("WEB", forKey: CompareSet.key)
        let readingAlone = try await run()
        // Every box off: the default four, not a comparison with nothing in it.
        h.defaults.set("", forKey: CompareSet.key)
        let none = try await run()
        #expect(chosen.contains("\n\nKJV\n3 Blessed are the poor in spirit: for theirs") && !readingAlone.contains("KJV\n3 "))
        #expect(none.contains("\n\nKJV\n3 Blessed are the poor in spirit: for theirs"))
    }

    /// The prompt run from the list sends the set as the panel's rows have it: in the translation list's
    /// order, whatever order the boxes were ticked in, so the on-device three are the panel's three.
    @Test func thePromptsCompareSetFollowsTheListsOrderAsThePanelsRowsDo() {
        let list = ["ESV", "NASB", "KJV", "WEB", "AMP"].map { Translation(id: $0, title: $0) }
        let ticked = ["AMP", "WEB", "XYZ", "KJV", "ESV", "NASB"]               // XYZ is not bundled
        let sent = CompareSet.promptIDs(ticked, in: list)
        #expect(sent == ["ESV", "NASB", "KJV", "WEB", "AMP"])
        let panel = VerseComparison(selection: blessed().selection, readingTranslationID: "ESV", compareSet: ticked, translations: list,
                                    verses: Dictionary(uniqueKeysWithValues: list.map { ($0.id, [Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: 3), translationID: $0.id, text: "Blessed.", breakAfter: false)]) }))
        #expect(AssistantModel.otherTranslationIDs(sent, reading: "ESV", compact: true) == Array(panel.otherTranslationIDs.prefix(3)))
        #expect(CompareSet.promptIDs([], in: list) == ["ESV", "NASB", "KJV", "WEB"] && CompareSet.promptIDs(["XYZ"], in: list) == ["ESV", "NASB", "KJV", "WEB"])
    }

    @Test func askAboutTheDifferencesSendsExactlyTheRowsShownAndThreeOnDevice() async throws {
        let provider = onDevice()
        let h = try make([provider])
        h.defaults.set("", forKey: CompareSet.key)                           // the rows travel with the request, not the setting
        // The reader's own wording, hidden.
        let stored = try #require(try h.templates.templates().first { $0.builtInKey == "compare-translations" })
        try h.templates.update(stored, title: stored.title, summary: stored.summary, body: "Only this: {{other_translations}}")
        try h.templates.setEnabled(stored, false)
        h.model.reloadTemplates()
        h.model.compareTranslations(blessed().selection, translationIDs: ["KJV"])
        try await settle(h.model)
        #expect(provider.requests.last?.messages.last?.content.hasPrefix("Only this: KJV\n3 Blessed are the poor in spirit") == true)
        #expect(h.model.messages[0].displayText == "Compare translations" && h.model.isPanelShown && h.model.thread?.scope == .selection)
        let shown = ["ESV", "NASB", "KJV", "WEB", "AMP"]
        #expect(AssistantModel.otherTranslationIDs(shown, reading: "ESV", compact: true) == ["NASB", "KJV", "WEB"])
        #expect(AssistantModel.otherTranslationIDs(shown, reading: "ESV", compact: false) == ["NASB", "KJV", "WEB", "AMP"])
    }

    @Test func tooLongForOnDeviceShowsTheNotice() throws {
        let h = try make([onDevice()])
        let psalm119 = ChapterLocation(book: "PSA", chapter: 119)
        h.model.setLocation(psalm119, translationID: "KJV", verses: try h.bible.chapter(psalm119, translationID: "KJV"))
        h.model.askAboutChapter()
        h.model.runPrompt(templateID(h.model, "Summarize this chapter"))
        #expect(h.model.notice == .tooLongForOnDevice && h.model.notice?.offersSettings == true)
        #expect(h.model.messages.isEmpty && !h.model.isResponding)
        #expect(try h.markup.chat.allThreads().isEmpty)
    }

    @Test func aFailureAfterDeltasKeepsThePartialReply() async throws {
        let h = try make([onDevice(["Half"], failure: .transport("connection dropped"))])
        try await askWhy(h)
        #expect(h.model.messages.last?.content == "Half" && h.model.messages.last?.isStreaming == false)
        #expect(h.model.notice == .unreachable)
        #expect(try h.markup.chat.allThreads()[0].orderedMessages.last?.content == "Half")
    }

    @Test func stopKeepsWhatArrived() async throws {
        let provider = GatedProvider()
        let h = try make([provider])
        h.model.ask(about: blessed())
        h.model.draft = "Why?"
        h.model.send()
        for _ in 0..<200 where !provider.isAsked {
            try await Task.sleep(for: .milliseconds(10))
        }
        provider.release("A")
        for _ in 0..<200 where h.model.messages.last?.content != "A" {
            try await Task.sleep(for: .milliseconds(10))
        }
        h.model.stop()
        provider.release("B")
        provider.finish()
        try await Task.sleep(for: .milliseconds(50))
        #expect(h.model.messages.last?.content == "A" && h.model.messages.last?.isStreaming == false)
        #expect(!h.model.isResponding && h.model.notice == nil)
        #expect(try h.markup.chat.allThreads()[0].orderedMessages.map(\.content) == ["Why?", "A"])
    }

    /// Escape stops a reply that is still arriving; with nothing arriving it goes back to Notes.
    @Test func escapeStopsAReplyBeforeItHidesThePanel() async throws {
        let provider = onDevice(["A", "B"])
        provider.delayPerDelta = .milliseconds(300)
        let h = try make([provider])
        h.model.ask(about: blessed())
        h.model.draft = "Why?"
        h.model.send()
        h.model.escape()
        #expect(!h.model.isResponding && h.model.isPanelShown)
        h.model.escape()
        #expect(!h.model.isPanelShown)
    }

    /// Three long on-device exchanges overflow the window: the passage in the first message is
    /// kept and the oldest reply goes instead.
    @Test func askAboutTheseComposesTheVerseAndTheShortListsAndStoresNoPrompt() async throws {
        let cloud = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", deltas: ["ok"])
        let h = try make([cloud])
        let x = try CrossReferences.load(VerseLocation(book: "MAT", chapter: 5, verse: 3), translationID: "WEB", store: h.bible)
        let stored = try h.templates.templates().count
        h.model.ask(about: try #require(x.selection), sending: try x.question(store: h.bible), shownAs: CrossReferences.askTitle)
        try await settle(h.model)
        let content = try #require(cloud.requests.last?.messages.last?.content)
        // This fixture has the words of Psalm 1:1 alone among these passages: every other row is its reference alone.
        #expect(content.hasPrefix("Here is Matthew 5:3 (WEB):\n\n") && content.contains("\n\nThis verse points to:\n\nPsalm 1:1 \u{2014} 1 "))
        #expect(content.contains("\nMatthew 6:19-21\n") && content.contains("\nMatthew 3:2\n\nVerses that point here:\n\nMatthew 6:33\nPsalm 1:1 \u{2014} 1 "))
        #expect(content.contains("\nMatthew 4:25\n\nExplain how each"))
        #expect(!content.contains("Isaiah 57:15") && !content.contains("Luke 6:20") && !content.contains("3 John"))   // the short lists alone
        #expect(content.hasSuffix(CrossReferences.request(for: "Matthew 5:3")))
        #expect(h.model.messages[0].displayText == "Explain these cross-references" && h.model.thread?.scope == .selection && h.model.isPanelShown)
        #expect(try h.templates.templates().count == stored)
    }

    @Test func aQuestionTooLongForOnDeviceSaysSo() throws {
        let h = try make([onDevice()])
        h.model.ask(about: blessed().selection, sending: String(repeating: "word ", count: 20_000), shownAs: CrossReferences.askTitle)
        #expect(h.model.notice == .tooLongForOnDevice && h.model.messages.isEmpty)
    }

    @Test func onDeviceTrimmingKeepsThePassage() async throws {
        let provider = onDevice([String(repeating: "word ", count: 1200)])
        let h = try make([provider])
        h.model.askAboutChapter()
        h.model.runPrompt(templateID(h.model, "Summarize this chapter"))
        try await settle(h.model)
        for question in ["q2", "q3"] {
            h.model.draft = question
            h.model.send()
            try await settle(h.model)
        }
        let last = try #require(provider.requests.last)
        #expect(last.messages.first?.content.hasPrefix("Here is Matthew 5 (WEB):") == true && last.messages.last?.content == "q3")
        #expect(OnDeviceFit.fits(last) && last.messages.count < 5)
    }

    /// Chosen in Settings, on-device answers whatever it can take once trimmed; a key for a
    /// cloud provider does not pull a long conversation off the Mac.
    @Test func anOnDevicePreferenceKeepsLongConversationsOnDevice() async throws {
        let local = onDevice([String(repeating: "word ", count: 1200)])
        let cloud = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", deltas: ["cloud"])
        let h = try make([local, cloud])
        h.defaults.set("appleOnDevice", forKey: AssistantSettings.providerKey)
        h.model.askAboutChapter()
        h.model.runPrompt(templateID(h.model, "Summarize this chapter"))
        try await settle(h.model)
        for question in ["q2", "q3"] {
            h.model.draft = question
            h.model.send()
            try await settle(h.model)
        }
        #expect(local.requests.count == 3 && cloud.requests.isEmpty)
    }

    /// Claude's thinking shares the reply budget; a cloud reply gets room to finish.
    @Test func cloudRepliesHaveRoomToFinish() async throws {
        let cloud = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", deltas: ["ok"])
        let h = try make([onDevice(), cloud])
        h.defaults.set("anthropic", forKey: AssistantSettings.providerKey)
        try await askWhy(h)
        #expect(cloud.requests.first?.maxTokens == 16_000)
    }

    // MARK: - Offline fallback

    @Test func anUnreachableCloudIsAnsweredOnDevice() async throws {
        let cloud = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", failure: .transport("offline"))
        let local = onDevice(["ok"])
        let h = try make([local, cloud])
        h.defaults.set("anthropic", forKey: AssistantSettings.providerKey)
        try await askWhy(h)
        let model = h.model
        #expect(model.messages.last?.content == "ok")
        #expect(model.messages.last?.providerLabel == "On-device · Claude unreachable")
        #expect(model.notice == nil)
        #expect(cloud.requests.count == 1 && local.requests.count == 1)
        #expect(OnDeviceFit.fits(try #require(local.requests.first)))
        let saved = try #require(try h.markup.chat.allThreads()[0].orderedMessages.last)
        #expect(saved.content == "ok" && saved.providerID == "appleOnDevice")
    }

    /// Review Focus 5: offline, a question too long for the on-device model is not answered by it.
    @Test func aTooLongQuestionKeepsTheUnreachableNotice() async throws {
        let cloud = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", failure: .transport("offline"))
        let local = onDevice(["ok"])
        let h = try make([local, cloud])
        h.defaults.set("anthropic", forKey: AssistantSettings.providerKey)
        let psalm119 = ChapterLocation(book: "PSA", chapter: 119)
        h.model.setLocation(psalm119, translationID: "KJV", verses: try h.bible.chapter(psalm119, translationID: "KJV"))
        h.model.askAboutChapter()
        h.model.runPrompt(templateID(h.model, "Summarize this chapter"))
        try await settle(h.model)
        #expect(h.model.notice == .unreachable)
        #expect(h.model.messages.map(\.role) == [.user])
        #expect(cloud.requests.count == 1 && local.requests.isEmpty)
        #expect(h.defaults.string(forKey: AssistantSettings.providerKey) == "anthropic")
    }

    @Test func aReplyCutOffMidwayIsNotRestarted() async throws {
        let cloud = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", deltas: ["Half"], failure: .transport("connection dropped"))
        let local = onDevice(["ok"])
        let h = try make([local, cloud])
        h.defaults.set("anthropic", forKey: AssistantSettings.providerKey)
        try await askWhy(h)
        #expect(h.model.messages.last?.content == "Half" && h.model.messages.last?.finishReason == .failed)
        #expect(h.model.messages.last?.providerLabel == "Claude · claude-opus-5-5")
        #expect(h.model.notice == .unreachable)
        #expect(local.requests.isEmpty)
    }

    @Test func theFallbackNeverChangesThePreference() async throws {
        let cloud = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", failure: .transport("offline"))
        let local = onDevice(["ok"])
        let h = try make([local, cloud])
        h.defaults.set("anthropic", forKey: AssistantSettings.providerKey)
        try await askWhy(h)
        #expect(h.model.messages.last?.providerLabel == "On-device · Claude unreachable")
        #expect(h.defaults.string(forKey: AssistantSettings.providerKey) == "anthropic")
        // The next question goes to Claude first again.
        h.model.draft = "And then?"
        h.model.send()
        try await settle(h.model)
        #expect(cloud.requests.count == 2 && local.requests.count == 2)
        #expect(h.defaults.string(forKey: AssistantSettings.providerKey) == "anthropic")
    }

    @Test func tryAgainFallsBackToo() async throws {
        let cloud = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", failure: .server(status: 500, message: "busy"))
        let local = onDevice(["ok"])
        let h = try make([local, cloud])
        h.defaults.set("anthropic", forKey: AssistantSettings.providerKey)
        try await askWhy(h)
        #expect(h.model.notice == .failed && local.requests.isEmpty)
        cloud.failure = .transport("offline")
        h.model.retry()
        try await settle(h.model)
        #expect(h.model.messages.last?.content == "ok" && h.model.messages.last?.providerLabel == "On-device · Claude unreachable")
        #expect(h.model.notice == nil && local.requests.count == 1)
    }

    @Test func aReplyCutShortKeepsItsTextAndSaysSo() async throws {
        let h = try make([onDevice(["Half"], failure: .cutShort)])
        try await askWhy(h)
        #expect(h.model.messages.last?.content == "Half" && h.model.notice == .cutShort && h.model.notice?.offersSettings == false)
        #expect(AssistantNotice.cutShort.message == "The answer was cut short. Ask the assistant to go on.")
    }

    @Test func stopBeforeAnyTextLeavesTheQuestion() async throws {
        let provider = onDevice(["A"])
        provider.delayPerDelta = .milliseconds(300)
        let h = try make([provider])
        h.model.ask(about: blessed())
        h.model.draft = "Why?"
        h.model.send()
        h.model.stop()
        #expect(h.model.messages.map(\.content) == ["Why?"] && !h.model.isResponding)
        try await Task.sleep(for: .milliseconds(400))
        #expect(try h.markup.chat.allThreads()[0].orderedMessages.map(\.content) == ["Why?"])
    }

    @Test func bookThreadsAttachTheNewReferenceWhenTheReaderMoves() async throws {
        let provider = onDevice()
        let h = try make([provider])
        h.model.openAskingForContext(selection: nil)
        h.model.chooseContext(.book)
        #expect(h.model.composerPlaceholder == "Ask about Matthew")
        h.model.draft = "q1"
        h.model.send()
        try await settle(h.model)
        let first = try #require(provider.requests.last?.messages.last?.content)
        #expect(first.hasPrefix("Here is Matthew 5 (WEB):\n\n1 ") && first.hasSuffix("\n\nq1"))
        let matthew6 = ChapterLocation(book: "MAT", chapter: 6)
        h.model.setLocation(matthew6, translationID: "WEB", verses: try h.bible.chapter(matthew6, translationID: "WEB"))
        h.model.draft = "q2"
        h.model.send()
        try await settle(h.model)
        #expect(h.model.messages[2].attachedReference == "Matthew 6" && h.model.messages[2].displayText == "q2")
        #expect(provider.requests.last?.messages.last?.content.hasPrefix("Now at Matthew 6 (WEB):\n\n1 ") == true)
        #expect(h.model.history.map(\.id) == [h.model.thread!.id])
        h.model.draft = "q3"
        h.model.send()
        try await settle(h.model)
        #expect(provider.requests.last?.messages.last?.content == "q3" && h.model.messages[4].attachedReference == nil)
    }

    // MARK: - Add as Note

    @Test func addAsNoteOnASelectionThreadAnchorsTheReply() async throws {
        let h = try make([onDevice()])
        var saved: UUID?
        h.model.onNoteSaved = { saved = $0 }
        try await askWhy(h)
        h.model.addAsNote(messageID: h.model.messages[1].id)
        let highlights = try h.markup.highlights(in: matthew5)
        #expect(highlights.count == 1 && highlights[0].colorID == nil && highlights[0].verse == 3 && highlights[0].endOffset == 7)
        let note = try #require(highlights[0].note)
        #expect(note.body == "**Q:** Why?\n\nBlessed." && note.sourceThreadID == h.model.thread?.id)
        #expect(h.markupChanges.count == 1 && saved == note.uuid)
    }

    /// Spec 4.1, end to end: Ask About the Differences on a comparison made from part of two verses keeps the
    /// verses shown, whole, on the conversation, and a reply saved as a note highlights exactly them.
    @Test func askAboutTheDifferencesFromPartOfAVerseSavesTheReplyOnTheWholeVersesShown() async throws {
        let h = try make([onDevice()])
        let part = TextSelection(book: "MAT", chapter: 5, verse: 3, endVerse: 4, startOffset: 9, endOffset: 12, quotedText: "the poor … those")
        let comparison = try VerseComparison.load(selection: part, readingTranslationID: "WEB", compareSet: ["KJV"],
                                                  translations: ["KJV", "WEB"].map { Translation(id: $0, title: $0) }, store: h.bible)
        let shown = comparison.selection
        #expect(shown.startOffset == 0 && shown.endOffset > 12)              // whole, not the part selected
        h.model.compareTranslations(shown, translationIDs: comparison.otherTranslationIDs)
        try await settle(h.model)
        let thread = try #require(h.model.thread)
        #expect(thread.verse == 3 && thread.endVerse == 4 && thread.startOffset == shown.startOffset && thread.endOffset == shown.endOffset)
        h.model.addAsNote(messageID: h.model.messages[1].id)
        let highlights = try h.markup.highlights(in: matthew5)
        #expect(highlights.count == 1)
        let highlight = try #require(highlights.first)
        #expect(highlight.verse == 3 && highlight.endVerse == 4 && highlight.startOffset == shown.startOffset && highlight.endOffset == shown.endOffset)
        #expect(highlight.note != nil)
    }

    /// Deleted through a second context on the same container, as an iCloud import does.
    @Test func addingAReplyAsANoteAfterItsThreadWasDeletedElsewhereDoesNothing() async throws {
        let h = try make([onDevice()])
        var saved: UUID?
        h.model.onNoteSaved = { saved = $0 }
        try await askWhy(h)
        let threadID = try #require(h.model.thread?.id)
        let replyID = h.model.messages[1].id
        #expect(h.model.lastReplyID == replyID)

        let other = ModelContext(h.container)
        for thread in try other.fetch(FetchDescriptor<ChatThread>(predicate: #Predicate { $0.uuid == threadID })) { other.delete(thread) }
        try other.save()

        h.model.addAsNote(messageID: replyID)
        h.model.addLastReplyAsNote()
        h.model.showSavedNote(messageID: replyID)
        #expect(h.model.savedNoteID(for: replyID) == nil)
        #expect(try h.markup.allNotes().isEmpty && h.markup.allHighlights().isEmpty)
        #expect(saved == nil && h.markupChanges.count == 0)
        #expect(h.model.notice == nil)
        #expect(!h.model.canRetry)

        h.model.refresh()
        #expect(h.model.thread == nil && h.model.messages.isEmpty)
        #expect(!h.model.history.contains { $0.id == threadID })
        #expect(h.model.notice == nil)
    }

    @Test func addAsNoteInsideAnExistingNoteAppends() async throws {
        let h = try make([onDevice()])
        let highlight = try h.markup.addHighlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 12,
                                                  translationID: "WEB", colorID: nil, quotedText: "Blessed are ")
        try h.markup.addNote(to: highlight, body: "mine")
        try await askWhy(h, primary: highlight.uuid)
        h.model.addAsNote(messageID: h.model.messages[1].id)
        #expect(try h.markup.highlights(in: matthew5).count == 1)
        #expect(highlight.note?.body == "mine\n\n**Q:** Why?\n\nBlessed.")
    }

    @Test func addAsNoteOnAChapterThreadMakesAChapterNote() async throws {
        let h = try make([onDevice()])
        h.model.askAboutChapter()
        h.model.runPrompt(templateID(h.model, "Summarize this chapter"))
        try await settle(h.model)
        h.model.addAsNote(messageID: h.model.messages[1].id)
        let notes = try h.markup.notes(in: matthew5)
        #expect(notes.count == 1 && notes[0].scope == .chapter && notes[0].verse == 0)
        #expect(notes[0].body == "**Q:** Summarize this chapter\n\nBlessed." && notes[0].sourceThreadID == h.model.thread?.id)
    }

    /// Show Note from Matthew 5 on a book thread's reply asked at Matthew 6: the note is a
    /// chapter note on Matthew 6, so the app has to go there before it can open the editor.
    @Test func showNoteNamesTheChapterTheNoteIsIn() async throws {
        let h = try make([onDevice()])
        let matthew6 = ChapterLocation(book: "MAT", chapter: 6)
        h.model.setLocation(matthew6, translationID: "WEB", verses: try h.bible.chapter(matthew6, translationID: "WEB"))
        h.model.openAskingForContext(selection: nil)
        h.model.chooseContext(.book)
        h.model.draft = "q1"
        h.model.send()
        try await settle(h.model)
        let reply = h.model.messages[1].id
        h.model.addAsNote(messageID: reply)
        let note = try #require(try h.markup.notes(in: matthew6).first)
        h.model.setLocation(matthew5, translationID: "WEB", verses: try h.bible.chapter(matthew5, translationID: "WEB"))
        #expect(h.model.thread?.scope == .book)
        var shown: UUID?
        h.model.onNoteSaved = { shown = $0 }
        h.model.showSavedNote(messageID: reply)
        #expect(shown == note.uuid)
        let target = try #require(h.model.noteTarget(noteID: note.uuid))
        #expect(target == MarkupTarget(location: matthew6, verse: 1, translationID: "WEB", highlightID: note.highlight?.uuid))
        #expect(h.model.noteTarget(noteID: UUID()) == nil)
    }

    /// A note on a highlight names its verse and the highlight to light.
    @Test func noteTargetOfAHighlightNoteNamesTheHighlight() async throws {
        let h = try make([onDevice()])
        try await askWhy(h)
        h.model.addAsNote(messageID: h.model.messages[1].id)
        let highlight = try #require(try h.markup.highlights(in: matthew5).first)
        let note = try #require(highlight.note)
        #expect(h.model.noteTarget(noteID: note.uuid) == MarkupTarget(location: matthew5, verse: 3, translationID: "WEB", highlightID: highlight.uuid))
    }

    @Test func copyTextIsTheReply() async throws {
        let h = try make([onDevice()])
        try await askWhy(h)
        #expect(h.model.copyText(messageID: h.model.messages[1].id) == "Blessed.")
        #expect(h.model.copyText(messageID: UUID()) == nil)
    }

    // MARK: - History

    @Test func openingAThreadInAnUnbundledTranslationKeepsTheCurrentOne() throws {
        let h = try make([onDevice()])
        let thread = try h.markup.chat.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0,
                                                    translationID: "ESV", quotedText: "", title: "Outline: Matthew 5")
        try h.markup.chat.append(to: thread, role: .user, content: "Here is Matthew 5 (ESV)…", providerID: "", modelName: "", attachedReference: nil)
        try h.markup.chat.append(to: thread, role: .assistant, content: "1. Beatitudes", providerID: "anthropic", modelName: "claude-opus-5-5", attachedReference: nil)
        h.model.open(threadID: thread.uuid)
        #expect(h.model.thread?.translationID == "ESV" && h.model.isPanelShown)
        #expect(h.model.messages.count == 2 && h.model.messages[1].providerLabel == "Claude · claude-opus-5-5")
        #expect(h.model.thread?.lastLine == "1. Beatitudes" || h.model.thread?.lastLine == "Beatitudes")
    }

    /// The Notes browser can delete the open conversation; the panel must let go of it.
    @Test func aThreadDeletedElsewhereClosesOnRefresh() async throws {
        let h = try make([onDevice()])
        try await askWhy(h)
        let id = try #require(h.model.thread?.id)
        try h.markup.delete(.thread(ThreadSnapshot(try #require(try h.markup.chat.thread(id: id)))))
        h.model.refresh()
        #expect(h.model.thread == nil && h.model.messages.isEmpty && h.model.history.isEmpty && h.model.isAskingForContext)
    }

    @Test func deletingAThreadIsUndoable() async throws {
        let h = try make([onDevice()])
        let undo = UndoManager()
        h.model.undoManager = undo
        try await askWhy(h)
        let id = try #require(h.model.thread?.id)
        h.model.deleteThread(id: id)
        #expect(h.model.history.isEmpty && h.model.thread == nil && h.model.isPanelShown)
        #expect(try h.markup.chat.allThreads().isEmpty)
        undo.undo()
        #expect(h.model.history.count == 1)
        #expect(try h.markup.chat.allThreads()[0].orderedMessages.count == 2)
    }

    // MARK: - Routing and notices

    @Test func preferenceAndNoticesFollowTheRouter() async throws {
        let offline = FakeProvider(id: .appleOnDevice, modelName: "apple-on-device", availability: .unavailable(reason: "Apple Intelligence is off."))
        let h = try make([offline])
        h.model.ask(about: blessed())
        h.model.draft = "Why?"
        h.model.send()
        #expect(h.model.notice == .onDeviceUnavailable("Apple Intelligence is off.") && h.model.draft == "Why?")

        h.box.providers = []
        h.model.send()
        #expect(h.model.notice == .nothingConfigured)

        h.defaults.set("anthropic", forKey: AssistantSettings.providerKey)
        h.box.providers = [onDevice(), FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", failure: .unauthorized)]
        h.model.send()
        try await settle(h.model)
        #expect(h.model.notice == .unauthorized)
        #expect(h.model.messages.map(\.role) == [.user])
    }

    @Test func noticesAndLabelsAreSentences() {
        #expect(AssistantNotice.tooLongForOnDevice.offersSettings && AssistantNotice.nothingConfigured.offersSettings)
        #expect(AssistantNotice.onDeviceUnavailable("x").offersSettings && AssistantNotice.unauthorized.offersSettings)
        #expect(!AssistantNotice.rateLimited.offersSettings && !AssistantNotice.declined.offersSettings)
        #expect(AssistantNotice.onDeviceUnavailable("Turn it on.").message.hasSuffix("Turn it on."))
        #expect(ProviderLabel.text(providerID: "appleOnDevice", modelName: "apple-on-device", baseURL: nil) == "On-device")
        #expect(ProviderLabel.text(providerID: "anthropic", modelName: "claude-opus-5-5", baseURL: nil) == "Claude · claude-opus-5-5")
        #expect(ProviderLabel.text(providerID: "openAI", modelName: "gpt-5", baseURL: nil) == "OpenAI · gpt-5")
        #expect(ProviderLabel.text(providerID: "openAICompatible", modelName: "llama3", baseURL: URL(string: "http://localhost:11434/v1")) == "localhost · llama3")
    }

    // MARK: - Try Again, saved notes, finish reasons, host, identity

    @Test func aFailedQuestionStaysAndTryAgainResends() async throws {
        let provider = onDevice([], failure: .transport("down"))
        let h = try make([provider])
        h.model.askAboutChapter(); h.model.draft = "Why?"; h.model.send()
        try await settle(h.model)
        #expect(h.model.notice == .unreachable)
        #expect(h.model.messages.map(\.role) == [.user])
        #expect(h.model.canRetry)
        provider.deltas = ["Because."]; provider.failure = nil
        h.model.retry()
        try await settle(h.model)
        #expect(h.model.notice == nil)
        #expect(h.model.messages.map(\.role) == [.user, .assistant])
        #expect(h.model.messages.last?.content == "Because.")
        #expect(provider.requests.count == 2)
    }

    /// ⌘R from the Assistant menu with the panel hidden shows the panel, so the reply is seen.
    @Test func tryAgainShowsThePanel() async throws {
        let provider = onDevice([], failure: .transport("down"))
        let h = try make([provider])
        h.model.askAboutChapter(); h.model.draft = "Why?"; h.model.send()
        try await settle(h.model)
        h.model.hidePanel()
        provider.deltas = ["Because."]; provider.failure = nil
        h.model.retry()
        #expect(h.model.isPanelShown)
        try await settle(h.model)
        #expect(h.model.messages.last?.content == "Because." && h.model.isPanelShown)
    }

    /// The Assistant menu reads the last reply from stored values that change when a reply
    /// finishes, a note is made of it or the conversation changes, never as tokens arrive.
    @Test func theLastReplyIsStoredAndFollowsTheConversation() async throws {
        let provider = GatedProvider()
        let h = try make([provider])
        h.model.askAboutChapter(); h.model.draft = "Q"; h.model.send()
        #expect(h.model.lastReplyID == nil)
        try await waitForStream(provider, count: 1)
        provider.release("Peace.")
        provider.finish()
        try await settle(h.model)
        let first = try #require(h.model.messages.last?.id)
        #expect(h.model.lastReplyID == first && h.model.lastReplySavedNoteID == nil)

        // The second reply's "B" is held back until after the check, so nothing races it.
        h.model.draft = "Again"; h.model.send()
        try await waitForStream(provider, count: 2)
        provider.release("A")
        for _ in 0..<200 where h.model.messages.last?.content != "A" {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(h.model.messages.last?.content == "A")
        #expect(h.model.isResponding && h.model.lastReplyID == first)
        provider.release("B")
        provider.finish()
        try await settle(h.model)
        let second = try #require(h.model.messages.last?.id)
        #expect(h.model.messages.last?.content == "AB")
        #expect(second != first && h.model.lastReplyID == second)

        h.model.addAsNote(messageID: second)
        let noteID = try #require(h.model.savedNoteID(for: second))
        #expect(h.model.lastReplySavedNoteID == noteID)

        let threadID = try #require(h.model.thread?.id)
        h.model.newConversation()
        #expect(h.model.lastReplyID == nil && h.model.lastReplySavedNoteID == nil)
        h.model.open(threadID: threadID)
        #expect(h.model.lastReplyID == second && h.model.lastReplySavedNoteID == noteID)

        try h.markup.deleteNote(try #require(try h.markup.note(id: noteID)))
        h.model.refresh()
        #expect(h.model.lastReplyID == second && h.model.lastReplySavedNoteID == nil)
    }

    @Test func theReplyKeepsItsRowIdentityWhenSaved() async throws {
        let h = try make([onDevice(["Peace."])])
        h.model.askAboutChapter(); h.model.draft = "Q"; h.model.send()
        let streamingID = h.model.messages.last!.id
        try await settle(h.model)
        #expect(h.model.messages.last?.id == streamingID)
        #expect(try h.markup.chat.thread(id: h.model.thread!.id)!.orderedMessages.last?.uuid == streamingID)
    }

    @Test func addAsNoteIsRecordedOnTheMessageAndForgottenWhenTheNoteGoes() async throws {
        let h = try make([onDevice(["Peace."])])
        h.model.askAboutChapter(); h.model.draft = "Q"; h.model.send()
        try await settle(h.model)
        let reply = h.model.messages.last!.id
        h.model.addAsNote(messageID: reply)
        let noteID = try #require(h.model.savedNoteID(for: reply))
        try h.markup.deleteNote(try #require(try h.markup.note(id: noteID)))
        #expect(h.model.savedNoteID(for: reply) == nil)
    }

    @Test func aCompatibleReplyRemembersItsHost() async throws {
        let provider = FakeProvider(id: .openAICompatible, modelName: "fake-model", deltas: ["Hi"])
        provider.hostName = "lmstudio.local"
        let h = try make([provider])
        h.model.askAboutChapter(); h.model.draft = "Q"; h.model.send()
        try await settle(h.model)
        #expect(h.model.messages.last?.providerLabel == "lmstudio.local · fake-model")
        h.defaults.set("http://elsewhere:1234/v1", forKey: AssistantSettings.compatibleBaseURLKey)
        h.model.open(threadID: h.model.thread!.id)
        #expect(h.model.messages.last?.providerLabel == "lmstudio.local · fake-model")
    }

    @Test func aDeclinedPartialReplyIsMarked() async throws {
        let h = try make([onDevice(["Half an answer"], failure: .declined(""))])
        h.model.askAboutChapter(); h.model.draft = "Q"; h.model.send()
        try await settle(h.model)
        #expect(h.model.messages.last?.content == "Half an answer")
        #expect(h.model.messages.last?.finishReason == .declined)
        #expect(h.model.notice == .declined)
    }

    @Test func aReopenedThreadWithAnUnansweredQuestionCanBeRetried() async throws {
        let provider = onDevice([], failure: .transport("down"))
        let h = try make([provider])
        h.model.askAboutChapter(); h.model.draft = "Why?"; h.model.send()
        try await settle(h.model)
        let threadID = try #require(h.model.thread?.id)
        h.model.askAboutChapter()
        #expect(h.model.thread == nil && !h.model.canRetry)
        h.model.open(threadID: threadID)
        #expect(h.model.canRetry)
        provider.deltas = ["Because."]; provider.failure = nil
        h.model.retry()
        try await settle(h.model)
        let stored = try #require(try h.markup.chat.thread(id: threadID)).orderedMessages
        #expect(stored.map(\.role) == [.user, .assistant])
        #expect(stored.last?.content == "Because.")
        #expect(provider.requests.count == 2)
        #expect(provider.requests[1].messages.last?.content == stored.first?.content)
        #expect(provider.requests[1].instructions == provider.requests[0].instructions)
    }

    /// A question trimmed for on-device that failed there goes whole to a cloud provider chosen
    /// since: Try Again builds the request again in the form the new provider takes.
    @Test func tryAgainOnAnotherProviderSendsTheFormItTakes() async throws {
        let local = onDevice([String(repeating: "word ", count: 1200)])
        let cloud = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", deltas: ["cloud"])
        let h = try make([local, cloud])
        h.defaults.set("appleOnDevice", forKey: AssistantSettings.providerKey)
        h.model.askAboutChapter()
        h.model.runPrompt(templateID(h.model, "Summarize this chapter"))
        try await settle(h.model)
        for question in ["q2", "q3"] {
            h.model.draft = question
            h.model.send()
            try await settle(h.model)
        }
        local.deltas = []; local.failure = .transport("down")
        h.model.draft = "q4"
        h.model.send()
        try await settle(h.model)
        #expect(h.model.canRetry && local.requests.last.map(\.messages.count).map { $0 < 7 } == true)
        h.defaults.set("anthropic", forKey: AssistantSettings.providerKey)
        h.model.retry()
        try await settle(h.model)
        let sent = try #require(cloud.requests.last)
        #expect(sent.messages.count == 7 && sent.messages.last?.content == "q4")
        #expect(h.model.messages.last?.content == "cloud")
    }

    /// Assistant › New Conversation: whatever is open, the panel asks "Include where you are?".
    @Test func newConversationAlwaysAsksForContext() async throws {
        let h = try make([onDevice(["Peace."])])
        h.model.askAboutChapter(); h.model.draft = "Q"; h.model.send()
        try await settle(h.model)
        h.model.hidePanel()
        h.model.newConversation()
        #expect(h.model.isPanelShown && h.model.isAskingForContext)
        #expect(h.model.thread == nil && h.model.pendingScope == nil && h.model.messages.isEmpty)
        h.model.askAboutChapter()
        h.model.newConversation()
        #expect(h.model.isAskingForContext && h.model.pendingScope == nil)
    }

    @Test func aReplyCutOffByAConnectionFailureIsMarked() async throws {
        let h = try make([onDevice(["Half an answer"], failure: .transport("down"))])
        h.model.askAboutChapter(); h.model.draft = "Q"; h.model.send()
        try await settle(h.model)
        #expect(h.model.messages.last?.content == "Half an answer")
        #expect(h.model.messages.last?.finishReason == .failed)
        #expect(h.model.notice == .unreachable)
        #expect(ChatFinishReason.failed.footerText == "Ended early")
    }
}
