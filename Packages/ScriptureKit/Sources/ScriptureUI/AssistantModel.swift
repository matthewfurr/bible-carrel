import Foundation
import Observation
import OSLog
import ScriptureData
import ScriptureLLM
import ScriptureModel
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// The study assistant beside the page: which conversation is open or about to start, its turns,
/// the history for where the reader is, and every action the chat panel takes. Like
/// `MarkupModel` it keeps the SwiftData objects private and gives the views value copies.
///
/// A conversation starts pending (a selection, the chapter, the book or no context) and becomes a
/// thread when its first message is routed. Each send is composed from the bundled text, routed
/// (on-device when it fits, else a configured cloud provider), streamed into a trailing reply and
/// saved when it ends, stops or fails.
@MainActor @Observable
public final class AssistantModel {
    public private(set) var isPanelShown = false
    public private(set) var thread: ChatThreadItem?
    public private(set) var messages: [ChatMessageItem] = []
    /// Conversations for the current chapter and its book, newest first.
    public private(set) var history: [ChatThreadItem] = []
    /// Every conversation, newest first: the phone's Ask tab lists them all. Loaded the first time
    /// something asks for it and kept fresh from then on, so the Mac, which never asks, never pays
    /// for it.
    public var allThreads: [ChatThreadItem] {
        if !isListingAllThreads {
            isListingAllThreads = true
            loadAllThreads()
        }
        return listedThreads
    }
    private var listedThreads: [ChatThreadItem] = []
    @ObservationIgnored private var isListingAllThreads = false
    public private(set) var isResponding = false
    public private(set) var notice: AssistantNotice?
    public var draft = ""
    /// The scope of a conversation not yet started (Ruling 1); nil while asking "Include where
    /// you are?" or when a thread is open.
    public private(set) var pendingScope: ThreadScope?
    /// Ruling 1 (c): opened with nothing chosen, the panel asks before including where the reader is.
    public private(set) var isAskingForContext = false
    /// Bumped when the panel opens on a new conversation, so the composer takes keyboard focus.
    public private(set) var composerFocusRequest = 0
    public private(set) var location: ChapterLocation?
    public private(set) var translationID = ""
    /// The window's undo manager; deleting a conversation registers an undo here.
    public var undoManager: UndoManager?
    /// After Add as Note: the app returns to the Notes column with that note in the editor.
    public var onNoteSaved: ((UUID) -> Void)?
    /// Open on a reference's preview: the app shows the passage at that verse.
    public var onOpenPassage: ((Reference) -> Void)?

    private let markup: MarkupStore
    private let bible: BibleStore
    /// Chapters per book in the translation they were read for; a reply's references check
    /// against them on every render, so they are read once per translation.
    @ObservationIgnored private var chapterCounts: (translationID: String, counts: [String: Int])?
    private let templateStore: PromptTemplateStore
    private let composer: StudyPromptComposer
    private let secrets: any SecretStore
    private let defaults: UserDefaults
    private let providerFactory: @MainActor () -> [any LLMProvider]
    private let onMarkupChange: () -> Void
    private var verses: [Verse] = []
    private var pendingSelection: TextSelection?
    /// The templates as they stood at the last `reloadTemplates()`, as values: a template can be
    /// deleted elsewhere (a duplicate merged after an import), and reading a stored object whose
    /// record is gone traps.
    private var templates: [TemplateRow] = []
    /// The open conversation's uuid. The record itself is fetched each time it is used
    /// (`threadRecord`), since it can be deleted on another device while it is open.
    private var threadID: UUID?
    private var responseTask: Task<Void, Never>?
    private var responseID: UUID?
    private var responder: (any LLMProvider)?
    /// The last request sent in the open thread, who it went to and the preference it was routed
    /// under, so Try Again can send it again.
    private var lastSubmission: (request: LLMRequest, provider: any LLMProvider, routed: RoutingPreference)?
    /// For a reply going to a cloud provider while the on-device model is available: the compact
    /// request and the router to ask, should the cloud not be reachable before any text arrives.
    private var offlineFallback: (router: LLMRouter, request: LLMRequest)?
    /// The last reply failed (not stopped): its notice stands and Try Again is offered.
    private var sendFailed = false
    private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "assistant")

    /// What a reply may run to. Claude's thinking counts against it, so it is generous; the
    /// on-device provider caps it at its own budget.
    static let replyTokens = 16_000

    public init(markup: MarkupStore, templates: PromptTemplateStore, bible: BibleStore, secrets: any SecretStore,
                defaults: UserDefaults = .standard, providerFactory: @escaping @MainActor () -> [any LLMProvider],
                onMarkupChange: @escaping () -> Void = {}) {
        self.markup = markup
        self.bible = bible
        self.templateStore = templates
        self.composer = StudyPromptComposer(store: bible)
        self.secrets = secrets
        self.defaults = defaults
        self.providerFactory = providerFactory
        self.onMarkupChange = onMarkupChange
    }

    // MARK: - Derived

    /// The scope of the open thread, else of the pending conversation.
    public var activeScope: ThreadScope? { thread?.scope ?? pendingScope }

    /// The header's scope label: "Matthew 5:3", "Matthew 5", "Matthew" or "No context".
    public var scopeLabel: String? {
        switch activeScope {
        case .selection: thread?.referenceString ?? pendingSelection?.referenceString
        case .chapter: thread?.referenceString ?? chapterTitle
        case .book: thread?.referenceString ?? bookTitle
        case .general: "No context"
        case nil: nil
        }
    }

    public var composerPlaceholder: String {
        switch activeScope {
        case .selection, .chapter, .book: scopeLabel.map { "Ask about \($0)" } ?? "Ask anything"
        case .general, nil: "Ask anything"
        }
    }

    /// The phrase a selection conversation is about; nil for the other scopes.
    public var quotedText: String? {
        activeScope == .selection ? (thread?.quotedText ?? pendingSelection?.quotedText) : nil
    }

    /// "Matthew 5" for the current chapter.
    public var chapterTitle: String? { location.map(Self.reference) }

    /// "Matthew" for the current book.
    public var bookTitle: String? { location.map { Self.book($0.book).name } }

    /// The prompts listed above the composer until the first message is sent: the selection's or
    /// the chapter's enabled templates, by section (in `PromptSection` order) and then by the
    /// order set in Settings; none for book and general conversations.
    public var prompts: [PromptTemplateItem] {
        guard thread == nil, let scope = pendingScope else { return [] }
        let wanted: PromptScope
        switch scope {
        case .selection: wanted = .selection
        case .chapter: wanted = .chapter
        case .book, .general: return []
        }
        let sectionRank = Dictionary(uniqueKeysWithValues: PromptSection.allCases.enumerated().map { ($1, $0) })
        return templates.filter { $0.item.scope == wanted && $0.item.isEnabled }
            .sorted { (sectionRank[$0.item.section] ?? 0, $0.sortOrder) < (sectionRank[$1.item.section] ?? 0, $1.sortOrder) }
            .map(\.item)
    }

    /// Try Again: the open thread's last turn is the reader's (a failure or a stop left no reply,
    /// in this session or an earlier one), or the last send failed and its notice stands; and
    /// nothing is arriving.
    public var canRetry: Bool {
        guard !isResponding, threadID != nil else { return false }
        return (sendFailed && notice != nil && lastSubmission != nil) || messages.last?.role == .user
    }

    /// The newest assistant reply that has finished arriving, and the note Add as Note made of it.
    /// Stored rather than read from `messages`, so the Assistant menu, which reads them, is not
    /// evaluated again for every token that streams in.
    public private(set) var lastReplyID: UUID?
    public private(set) var lastReplySavedNoteID: UUID?

    /// After a change made elsewhere (the Notes browser deleted or restored a conversation):
    /// lets go of an open conversation that no longer exists and reloads the history.
    public func refresh() {
        if let open = threadID, fetchThread(open) == nil {
            stop()
            closeThread()
            isAskingForContext = isPanelShown
        }
        for index in messages.indices where messages[index].role == .assistant && !messages[index].isStreaming {
            messages[index].savedNoteID = savedNoteID(for: messages[index].id)
        }
        updateLastReply()
        reloadHistory()
    }

    /// Sets `lastReplyID` and `lastReplySavedNoteID` from the turns, touching each only when it changes.
    private func updateLastReply() {
        let reply = messages.last { $0.role == .assistant && !$0.isStreaming }
        if lastReplyID != reply?.id { lastReplyID = reply?.id }
        if lastReplySavedNoteID != reply?.savedNoteID { lastReplySavedNoteID = reply?.savedNoteID }
    }

    // MARK: - Location and templates

    /// What the open chapter is; the reader calls it whenever the chapter changes (a navigation:
    /// the reader shows one chapter, so a scroll never changes it). A move to another chapter
    /// drops what belonged to the one before: a pending selection, and a chapter conversation
    /// while the panel is hidden.
    public func setLocation(_ chapter: ChapterLocation?, translationID: String, verses: [Verse]) {
        let moved = chapter != location
        location = chapter
        self.translationID = translationID
        self.verses = verses
        if moved {
            notice = nil
            // A selection belongs to the chapter it was made in.
            if pendingScope == .selection {
                pendingSelection = nil
                pendingScope = nil
                isAskingForContext = isPanelShown
            }
            // A conversation about another chapter closes while the panel is hidden; a book
            // conversation follows the reader.
            if !isPanelShown, threadID != nil, threadRecord?.scope != .book {
                closeThread()
            }
        }
        reloadHistory()
    }

    public func reloadTemplates() {
        attempt {
            templates = try templateStore.templates().map {
                TemplateRow(
                    item: PromptTemplateItem(
                        id: $0.uuid, title: $0.title, summary: $0.summary, scope: $0.scope,
                        section: $0.section, isEnabled: $0.isEnabled),
                    sortOrder: $0.sortOrder)
            }
        }
    }

    // MARK: - Ways in

    /// Ruling 1 (a): the panel opens on the selection with its prompts listed; nothing is sent.
    public func ask(about report: SelectionReport) {
        startPending(.selection, selection: report.selection)
    }

    /// Ruling 1 (b): the panel opens on the chapter with its prompts listed.
    public func askAboutChapter() {
        startPending(.chapter)
    }

    /// Ruling 1 (c): with a selection, as `ask(about:)`; otherwise the open or pending
    /// conversation, or the question "Include where you are?".
    public func openAskingForContext(selection: SelectionReport?) {
        if let selection, !selection.selection.quotedText.isEmpty {
            ask(about: selection)
        } else {
            showPanel()
        }
    }

    /// Assistant › New Conversation: lets go of the open or pending conversation (stopping a
    /// reply that is arriving) and shows the panel asking "Include where you are?".
    public func newConversation() {
        stop()
        closeThread()
        pendingScope = nil
        pendingSelection = nil
        notice = nil
        isAskingForContext = true
        if !isPanelShown { composerFocusRequest += 1 }
        isPanelShown = true
    }

    /// The phone's Ask tab: lets go of the open or pending conversation (stopping a reply that is
    /// arriving) and starts one with `scope` pending, its prompts listed. Unlike the Mac's ways in
    /// it neither shows the panel nor asks "Include where you are?", and it keeps the draft. A
    /// selection conversation starts from `ask(about:)`, which knows the selection.
    public func startNew(scope: ThreadScope) {
        guard scope != .selection else { return }
        stop()
        closeThread()
        pendingScope = scope
        pendingSelection = nil
        isAskingForContext = false
        notice = nil
    }

    /// `.chapter`, `.book` or `.general`, from the three buttons or the `plus` menu.
    public func chooseContext(_ scope: ThreadScope) {
        guard scope != .selection else { return }
        startPending(scope)
    }

    public func showPanel() {
        if thread == nil, pendingScope == nil { isAskingForContext = true }
        if !isPanelShown { composerFocusRequest += 1 }
        isPanelShown = true
    }

    public func hidePanel() {
        isPanelShown = false
    }

    /// Escape in the panel: stops a reply that is still arriving, otherwise goes back to Notes.
    public func escape() {
        if isResponding { stop() } else { hidePanel() }
    }

    public func togglePanel() {
        isPanelShown ? hidePanel() : showPanel()
    }

    /// From history or the Notes browser; shows the panel.
    public func open(threadID: UUID) {
        guard let record = fetchThread(threadID) else { return }
        stop()
        self.threadID = record.uuid
        pendingScope = nil
        pendingSelection = nil
        isAskingForContext = false
        notice = nil
        lastSubmission = nil
        sendFailed = false
        refreshThread()
        messages = record.orderedMessages.map { item($0) }
        updateLastReply()
        isPanelShown = true
        composerFocusRequest += 1
    }

    // MARK: - Sending

    /// Fills the template for the pending conversation and sends it; one deleted elsewhere since
    /// the last `reloadTemplates()` is not sent.
    public func runPrompt(_ templateID: UUID) {
        guard thread == nil, pendingScope != nil, templates.contains(where: { $0.item.id == templateID }) else { return }
        var input: Input?
        attempt {
            if let template = try templateStore.template(id: templateID) {
                // The compare set, for a prompt that names the other translations.
                let compareSet = template.body.contains("{{other_translations}}")
                    ? CompareSet.promptIDs(CompareSet.ids(from: defaults), in: try bible.translations()) : []
                input = .template(title: template.title, body: template.body, otherTranslationIDs: compareSet)
            }
        }
        guard let input else { return }
        submit(input)
    }

    /// Ask About the Differences: opens the panel on `selection` and sends the Compare translations
    /// prompt as the reader has it, edited or hidden, with `translationIDs` as the other translations.
    public func compareTranslations(_ selection: TextSelection, translationIDs: [String]) {
        startPending(.selection, selection: selection)
        var input: Input?
        attempt {
            let key = "compare-translations"
            if let stored = try templateStore.templates().first(where: { $0.builtInKey == key }) {
                input = .template(title: stored.title, body: stored.body, otherTranslationIDs: translationIDs)
            } else if let seed = BuiltInPrompts.seed(key: key) {
                input = .template(title: seed.title, body: seed.body, otherTranslationIDs: translationIDs)
            }
        }
        guard let input else { return }
        submit(input)
    }

    /// Ask About These: opens the panel on `selection` and sends `content` as it is; the reader's turn
    /// reads `title`. Nothing is stored as a prompt.
    public func ask(about selection: TextSelection, sending content: String, shownAs title: String) {
        startPending(.selection, selection: selection)
        submit(.composed(title: title, content: content))
    }

    /// `ids` without the translation being read; three when compact (the on-device model's room).
    static func otherTranslationIDs(_ ids: [String], reading: String, compact: Bool) -> [String] {
        let others = ids.filter { $0 != reading }
        return compact ? Array(others.prefix(3)) : others
    }

    /// The draft, trimmed; empty is ignored. Creates the thread on the first send. Sent while
    /// the panel still asks "Include where you are?", it goes without context.
    public func send() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        if thread == nil, pendingScope == nil {
            pendingScope = .general
            isAskingForContext = false
        }
        submit(.question(question))
    }

    /// Ruling 11: keeps whatever text arrived; with none, the thread keeps only the question.
    public func stop() {
        guard responseID != nil else { return }
        responseTask?.cancel()
        responseID = nil
        finishResponse(failure: CancellationError())
    }

    /// Try Again: sends the last request again, to the provider it went to when Settings still
    /// route there, else to wherever the router now sends it, built again from the stored turns
    /// in the form that provider takes (as for a thread reopened with its question unanswered,
    /// which has no last request in this session). From the menu (⌘R) with the panel hidden, it
    /// shows the panel first, so the reply or its notice is seen.
    public func retry() {
        guard canRetry, let record = threadRecord, let location else { return }
        isPanelShown = true
        let providers = providerFactory()
        let preference = AssistantSettings.preference(from: defaults)
        let request: LLMRequest
        let provider: any LLMProvider
        if let last = lastSubmission, preference == last.routed,
           let same = providers.first(where: {
               $0.id == last.provider.id && $0.modelName == last.provider.modelName && $0.hostName == last.provider.hostName
           }),
           same.availability == .available {
            request = last.request
            provider = same
        } else {
            // Built again from the stored turns (the last reader turn holds the prompt as it was
            // composed) in the form whichever provider answers now takes: a request trimmed for
            // on-device goes whole to a cloud provider.
            let router = LLMRouter(providers: providers)
            let built = route(router, preference: preference, request: { $0 }) { compact in
                storedRequest(record, at: location, compact: compact)
            }
            request = built.composed
            let decision = built.decision
            guard case .provider(let routed) = decision else {
                notice = Self.notice(for: decision)
                return
            }
            provider = routed
        }
        lastSubmission = (request, provider, preference)
        notice = nil
        sendFailed = false
        offlineFallback = Self.mayFallBack(from: provider, among: providers)
            ? (LLMRouter(providers: providers), storedRequest(record, at: location, compact: true)) : nil
        beginReply(request, from: provider)
    }

    private enum Input {
        case question(String)
        case template(title: String, body: String, otherTranslationIDs: [String])
        /// A question the app composed: sent as it is, the reader's turn reading `title`.
        case composed(title: String, content: String)
    }

    /// A composed request and the turn it ends with.
    private struct Composed {
        var request: LLMRequest
        var content: String
        var displayText: String
        var attachedReference: String?
    }

    private func submit(_ input: Input) {
        guard !isResponding, let location, let scope = activeScope else { return }
        // The open conversation was deleted on another device: let go of it, as `refresh` does,
        // rather than send a follow-up that has no thread to go in.
        if threadID != nil, threadRecord == nil {
            closeThread()
            isAskingForContext = isPanelShown
            return
        }
        let providers = providerFactory()
        let router = LLMRouter(providers: providers)
        let preference = AssistantSettings.preference(from: defaults)
        let composed: Composed
        let decision: RoutingDecision
        do {
            let routed = try route(router, preference: preference, request: \.request) { compact in
                try compose(input, scope: scope, at: location, compact: compact)
            }
            composed = routed.composed
            decision = routed.decision
        } catch {
            logger.error("Composing the request failed: \(error)")
            notice = .failed
            return
        }
        guard case .provider(let provider) = decision else {
            notice = Self.notice(for: decision)
            return
        }
        notice = nil
        // The compact form is composed now, before the question joins the thread's history.
        let fallbackRequest = Self.mayFallBack(from: provider, among: providers)
            ? (try? compose(input, scope: scope, at: location, compact: true))?.request : nil
        var userMessage: ChatMessage?
        attempt {
            let record = try threadRecord ?? createThread(input: input, scope: scope, at: location)
            threadID = record.uuid
            userMessage = try markup.chat.append(to: record, role: .user, content: composed.content, displayText: composed.displayText,
                                                 providerID: "", modelName: "", attachedReference: composed.attachedReference)
        }
        guard let userMessage else { return }
        if case .question = input { draft = "" }
        pendingScope = nil
        pendingSelection = nil
        refreshThread()
        reloadHistory()
        messages.append(item(userMessage))
        lastSubmission = (composed.request, provider, preference)
        sendFailed = false
        offlineFallback = fallbackRequest.map { (router, $0) }
        beginReply(composed.request, from: provider)
    }

    /// Builds the request in the form routing wants and routes it. `build` makes the whole
    /// request (`compact: false`) or the shorter one the on-device window can take; `request`
    /// reads the request from what it built.
    private func route<Built>(
        _ router: LLMRouter, preference: RoutingPreference, request: (Built) -> LLMRequest,
        _ build: (_ compact: Bool) throws -> Built
    ) rethrows -> (composed: Built, decision: RoutingDecision) {
        var composed: Built
        var decision: RoutingDecision
        if preference == .appleOnDevice {
            // Chosen in Settings, on-device answers whatever it can take once trimmed; only
            // what it cannot goes to a cloud provider, which then gets everything.
            composed = try build(true)
            decision = router.route(request(composed), preference: preference)
            if Self.isCloud(decision) {
                composed = try build(false)
                decision = router.route(request(composed), preference: preference)
            }
        } else {
            composed = try build(false)
            decision = router.route(request(composed), preference: preference)
            // On-device, or nobody yet: the shorter form (three translations, a trimmed
            // history, an abridged previous chapter when the whole one does not fit) is what
            // the on-device window can take.
            if !Self.isCloud(decision) {
                composed = try build(true)
                decision = router.route(request(composed), preference: preference)
            }
        }
        return (composed, decision)
    }

    /// The request for a reopened thread's unanswered question: its instructions as `compose`
    /// frames them, and its stored turns through the last reader turn (whose `content` is the
    /// prompt as it was composed).
    private func storedRequest(_ record: ChatThread, at location: ChapterLocation, compact: Bool) -> LLMRequest {
        let ordered = record.orderedMessages
        let turns = ordered.lastIndex { $0.role == .user }.map { ordered[...$0] } ?? ordered[...]
        let request = LLMRequest(instructions: framing(record.scope, at: location).instructions,
                                 messages: Self.llmMessages(turns), maxTokens: Self.replyTokens)
        return compact ? Self.trimmedForOnDevice(request, scope: record.scope) : request
    }

    /// Appends the streaming reply (its id becomes the saved record's) and starts it.
    private func beginReply(_ request: LLMRequest, from provider: any LLMProvider) {
        messages.append(ChatMessageItem(id: UUID(), role: .assistant, content: "",
                                        providerLabel: label(providerID: provider.id.rawValue, modelName: provider.modelName, host: provider.hostName),
                                        attachedReference: nil, isStreaming: true))
        stream(request, from: provider)
    }

    private func stream(_ request: LLMRequest, from provider: any LLMProvider) {
        let id = UUID()
        responseID = id
        responder = provider
        isResponding = true
        responseTask = Task { [weak self] in
            var received = false
            do {
                for try await event in provider.stream(request) {
                    guard let self, self.responseID == id else { return }
                    if case .textDelta(let text) = event, let last = self.messages.indices.last {
                        received = true
                        self.messages[last].content += text
                    }
                }
                guard let self, self.responseID == id else { return }
                self.responseID = nil
                self.finishResponse(failure: nil)
            } catch {
                guard let self, self.responseID == id else { return }
                if !received, self.fallBackOnDevice(after: error) { return }
                self.responseID = nil
                self.finishResponse(failure: error)
            }
        }
    }

    /// A cloud reply that could not reach its provider before any text arrived starts again
    /// on-device, in the same row, when the compact request fits there. The "Answer with" setting
    /// stays as it is.
    private func fallBackOnDevice(after error: any Error) -> Bool {
        guard case LLMProviderError.transport? = error as? LLMProviderError,
              let fallback = offlineFallback, responder?.id != .appleOnDevice,
              let last = messages.indices.last, messages[last].isStreaming, messages[last].content.isEmpty
        else { return false }
        offlineFallback = nil
        guard let onDevice = fallback.router.offlineFallback(for: fallback.request) else { return false }
        let reply = messages[last]
        let cloudName = reply.providerLabel?.components(separatedBy: " · ").first ?? ""
        logger.notice("The cloud provider could not be reached; answering on-device: \(String(describing: error))")
        messages[last] = ChatMessageItem(id: reply.id, role: .assistant, content: "",
                                         providerLabel: ProviderLabel.fallbackText(cloudName: cloudName),
                                         attachedReference: reply.attachedReference, isStreaming: true)
        stream(fallback.request, from: onDevice)
        return true
    }

    /// Saves the reply so far (or drops an empty one) under the streaming row's id, with why it
    /// ended early, and reports a failure as a notice. A reply with text is announced to VoiceOver
    /// unless the reader stopped it.
    private func finishResponse(failure: (any Error)?) {
        responseTask = nil
        isResponding = false
        offlineFallback = nil
        let provider = responder
        responder = nil
        let stopped = failure is CancellationError
        let reason = Self.finishReason(for: failure)
        var answered = false
        if let last = messages.indices.last, messages[last].isStreaming {
            let reply = messages[last]
            if reply.content.isEmpty {
                messages.removeLast()
            } else {
                answered = true
                var saved: ChatMessage?
                if let record = threadRecord, let provider {
                    attempt {
                        saved = try markup.chat.append(
                            to: record, role: .assistant, content: reply.content, displayText: nil,
                            providerID: provider.id.rawValue, modelName: provider.modelName, providerHost: provider.hostName,
                            attachedReference: nil, finishReason: reason?.rawValue, uuid: reply.id)
                    }
                }
                if let saved {
                    // An on-device answer to a cloud question keeps the label it streamed under
                    // ("On-device · Claude unreachable") for as long as the thread stays open.
                    messages[last] = item(saved, providerLabel: reply.providerLabel)
                } else {
                    messages[last].isStreaming = false
                    messages[last].finishReason = reason
                }
            }
        }
        if let failure, !stopped {
            logger.error("The assistant's reply failed: \(String(describing: failure))")
            notice = Self.notice(for: failure, providerID: provider?.id)
            sendFailed = true
        }
        updateLastReply()
        refreshThread()
        reloadHistory()
        if answered, !stopped { announceFinished() }
    }

    /// Nil for a complete reply; any failure other than a refusal or the token budget (a dropped
    /// connection, a server error) ended it early.
    private static func finishReason(for failure: (any Error)?) -> ChatFinishReason? {
        switch failure {
        case nil: nil
        case is CancellationError: .stopped
        case LLMProviderError.declined?: .declined
        case LLMProviderError.cutShort?: .cutShort
        default: .failed
        }
    }

    /// Tells VoiceOver the reply is complete; outside a running app (tests) there is no one to tell.
    private func announceFinished() {
        #if canImport(AppKit)
        guard NSApp != nil else { return }
        #endif
        AccessibilityNotification.Announcement("The assistant has finished answering.").post()
    }

    // MARK: - Composing

    /// What a request is framed by: the open thread's (else the pending conversation's)
    /// translation, selection and references, and the system instructions they make.
    private struct Framing {
        var translation: String
        var selection: TextSelection?
        var chapterReference: String
        var reference: String
        var instructions: String
    }

    private func framing(_ scope: ThreadScope, at location: ChapterLocation) -> Framing {
        let record = threadRecord
        let translation = record?.translationID ?? translationID
        let selection = record.map(Self.selection(of:)) ?? pendingSelection
        let chapterReference = Self.reference(promptChapter(scope, record: record, inView: location))
        let reference = scope == .selection ? (selection?.referenceString ?? chapterReference) : chapterReference

        let instructions: String
        switch scope {
        case .selection:
            instructions = PromptBuilder.instructions(reference: reference, translation: translation, scope: .selection(quoted: selection?.quotedText ?? ""))
        case .chapter:
            instructions = PromptBuilder.instructions(reference: chapterReference, translation: translation, scope: .chapter)
        case .book:
            instructions = PromptBuilder.instructions(reference: Self.reference(location), translation: translationID, scope: .book)
        case .general:
            instructions = PromptBuilder.generalInstructions
        }
        return Framing(translation: translation, selection: selection, chapterReference: chapterReference, reference: reference, instructions: instructions)
    }

    private static func llmMessages(_ messages: some Sequence<ChatMessage>) -> [LLMMessage] {
        messages.map { LLMMessage(role: $0.role == .user ? .user : .assistant, content: $0.content) }
    }

    /// The first turn carries the passage (or the template's), so it outlasts later ones; a book
    /// thread keeps four exchanges.
    private static func trimmedForOnDevice(_ request: LLMRequest, scope: ThreadScope) -> LLMRequest {
        OnDeviceFit.trim(request, maxExchanges: scope == .book ? 4 : nil, keepingFirst: scope != .general)
    }

    /// The chapter a selection's own book and chapter name, which scrolling may have left.
    private func selectionChapter(_ selection: TextSelection?) -> ChapterLocation? {
        selection.map { ChapterLocation(book: $0.book, chapter: $0.chapter) }
    }

    /// The chapter a prompt is about: the open thread's, else a new selection's own, else the
    /// chapter in view. A book thread follows the reader, so it always takes the chapter in view.
    private func promptChapter(_ scope: ThreadScope, record: ChatThread?, inView: ChapterLocation) -> ChapterLocation {
        guard scope != .book else { return inView }
        if let record { return record.chapterLocation }
        return scope == .selection ? selectionChapter(pendingSelection) ?? inView : inView
    }

    private func compose(_ input: Input, scope: ThreadScope, at inView: ChapterLocation, compact: Bool) throws -> Composed {
        let record = threadRecord
        let frame = framing(scope, at: inView)
        let location = promptChapter(scope, record: record, inView: inView)
        let verses = location == inView ? self.verses : try bible.chapter(location, translationID: frame.translation)
        let translation = frame.translation
        let selection = frame.selection
        let chapterReference = frame.chapterReference
        let reference = frame.reference
        let instructions = frame.instructions
        let history = Self.llmMessages(record?.orderedMessages ?? [])

        func build(abridgePrevious: Bool) throws -> Composed {
            var composed: Composed
            switch input {
            case .template(let title, let body, let otherIDs):
                let context = PromptContext(
                    reference: reference,
                    translation: translation,
                    chapterText: StudyPromptComposer.chapterText(verses),
                    selection: selection?.quotedText ?? "",
                    previousChapterText: body.contains("{{previous_chapter_text}}") ? try previousText(of: location, abridged: abridgePrevious) : "",
                    otherTranslations: body.contains("{{other_translations}}") && selection != nil
                        ? try composer.otherTranslations(for: location, verse: selection!.verse, endVerse: selection!.endVerse, translationIDs: Self.otherTranslationIDs(otherIDs, reading: translation, compact: compact), limit: nil)
                        : "")
                composed = Composed(request: LLMRequest(instructions: "", messages: [], maxTokens: 0), content: PromptBuilder.fill(body, with: context), displayText: title)
            case .composed(let title, let content):
                composed = Composed(request: LLMRequest(instructions: "", messages: [], maxTokens: 0), content: content, displayText: title)
            case .question(let question):
                composed = Composed(request: LLMRequest(instructions: "", messages: [], maxTokens: 0), content: question, displayText: question)
                if record == nil, scope == .chapter || scope == .book {
                    composed.content = "Here is \(chapterReference) (\(translation)):\n\n\(StudyPromptComposer.chapterText(verses))\n\n\(question)"
                } else if let record, scope == .book {
                    let here = Self.reference(location)
                    if here != lastAttachedReference(record) {
                        composed.content = "Now at \(here) (\(translationID)):\n\n\(StudyPromptComposer.chapterText(verses))\n\n\(question)"
                        composed.attachedReference = here
                    }
                }
            }
            var request = LLMRequest(instructions: instructions, messages: history + [LLMMessage(role: .user, content: composed.content)], maxTokens: Self.replyTokens)
            if compact { request = Self.trimmedForOnDevice(request, scope: scope) }
            composed.request = request
            return composed
        }

        let whole = try build(abridgePrevious: false)
        guard compact, !OnDeviceFit.fits(whole.request), case .template(_, let body, _) = input, body.contains("{{previous_chapter_text}}") else { return whole }
        return try build(abridgePrevious: true)
    }

    private func previousText(of location: ChapterLocation, abridged: Bool) throws -> String {
        guard let previous = try composer.previousChapter(of: location, translationID: translationID) else { return "" }
        return abridged ? StudyPromptComposer.abridged(previous) : StudyPromptComposer.chapterText(previous)
    }

    /// Where a book thread last spoke from: the latest attached reference, else where it began.
    private func lastAttachedReference(_ record: ChatThread) -> String {
        record.orderedMessages.last { $0.attachedReference != nil }?.attachedReference ?? Self.reference(record.chapterLocation)
    }

    private func createThread(input: Input, scope: ThreadScope, at chapterInView: ChapterLocation) throws -> ChatThread {
        // A selection thread lives on the chapter the selection was made in, which scrolling may
        // have left.
        let location = scope == .selection ? selectionChapter(pendingSelection) ?? chapterInView : chapterInView
        let title: String
        switch (scope, input) {
        case (.selection, _):
            let selection = pendingSelection
            let quoted = (selection?.quotedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            title = "\(selection?.referenceString ?? Self.reference(location)) · \(quoted.prefix(40))"
        case (_, .template(let templateTitle, _, _)):
            title = "\(templateTitle): \(Self.reference(location))"
        case (_, .composed(let composedTitle, _)):
            title = composedTitle
        case (_, .question(let question)):
            title = String(question.replacingOccurrences(of: "\n", with: " ").prefix(60))
        }
        let s = pendingSelection
        return try markup.chat.createThread(
            scope: scope, book: location.book, chapter: location.chapter,
            verse: scope == .selection ? s?.verse ?? 0 : 0, endVerse: scope == .selection ? s?.endVerse ?? 0 : 0,
            startOffset: scope == .selection ? s?.startOffset ?? 0 : 0, endOffset: scope == .selection ? s?.endOffset ?? 0 : 0,
            translationID: translationID, quotedText: scope == .selection ? s?.quotedText ?? "" : "", title: title)
    }

    // MARK: - Replies

    public func copyText(messageID: UUID) -> String? {
        messages.first { $0.id == messageID && $0.role == .assistant }?.content
    }

    public func copyLastReply() -> String? {
        lastReplyID.flatMap(copyText(messageID:))
    }

    public func addLastReplyAsNote() {
        guard let id = lastReplyID else { return }
        addAsNote(messageID: id)
    }

    /// The note Add as Note made of the reply; nil when there is none or it has been deleted.
    public func savedNoteID(for messageID: UUID) -> UUID? {
        guard let noteID = threadRecord?.orderedMessages.first(where: { $0.uuid == messageID })?.savedNoteID else { return nil }
        var exists = false
        attempt { exists = try markup.note(id: noteID) != nil }
        return exists ? noteID : nil
    }

    /// Where a saved note is, as the Notes browser targets it: its chapter (often not the open
    /// one: a book thread saves to the chapter asked in, and a thread stays open as the reader
    /// moves on), verse, translation and highlight. Nil when the note is gone.
    public func noteTarget(noteID: UUID) -> MarkupTarget? {
        var target: MarkupTarget?
        attempt {
            if let note = try markup.note(id: noteID) {
                target = MarkupTarget(entry: NotesBrowserLoader.entry(for: note, colors: []))
            }
        }
        return target
    }

    // MARK: - References in replies

    /// The book a bare "5:3" in a reply resolves against: the open conversation's; none for a
    /// "No context" conversation.
    public var referenceContextBook: Book? {
        guard let thread, thread.scope != .general else { return nil }
        return BookCatalog.book(code: thread.location.book)
    }

    /// How many chapters a book has in the reader's translation; nil when it lacks the book.
    public func chapterCount(ofBook bookID: String) -> Int? {
        if chapterCounts?.translationID != translationID {
            do {
                let books = try bible.books(in: translationID)
                chapterCounts = (translationID, Dictionary(books.map { ($0.book.id, $0.chapterCount) }, uniquingKeysWith: { first, _ in first }))
            } catch {
                logger.error("Reading chapter counts failed: \(error)")
                return nil
            }
        }
        return chapterCounts?.counts[bookID]
    }

    /// The verses a reference in a reply names, in the reader's translation; nil when none exist.
    public func versePreview(_ reference: Reference) -> VersePreview? {
        do {
            return try VersePreview.load(reference, translationID: translationID, store: bible)
        } catch {
            logger.error("Reading a reference's verses failed: \(error)")
            return nil
        }
    }

    /// Show Note: the app opens the reply's saved note, as after Add as Note.
    public func showSavedNote(messageID: UUID) {
        guard let noteID = savedNoteID(for: messageID) else { return }
        onNoteSaved?(noteID)
    }

    /// Ruling 6: the reply, under its question, becomes a note: on the selection's highlight (or
    /// a new colorless one), or on the chapter. Then the app opens it for editing.
    public func addAsNote(messageID: UUID) {
        guard let record = threadRecord else { return }
        let ordered = record.orderedMessages
        guard let index = ordered.firstIndex(where: { $0.uuid == messageID && $0.role == .assistant }) else { return }
        // One note per reply: a saved reply offers Show Note instead.
        guard savedNoteID(for: messageID) == nil else { return }
        let question = ordered[..<index].last { $0.role == .user }.map { $0.displayText ?? $0.content } ?? ""
        let reply = ordered[index].content
        let body = question.isEmpty ? reply : "**Q:** \(question)\n\n\(reply)"
        var noteID: UUID?
        attempt {
            switch record.scope {
            case .selection:
                if let highlight = try enclosingHighlight(of: record) {
                    if let note = highlight.note {
                        try markup.appendToNote(note, body)
                        noteID = note.uuid
                    } else {
                        noteID = try markup.addNote(to: highlight, body: body, sourceThreadID: record.uuid).uuid
                    }
                } else {
                    let highlight = try markup.addHighlight(
                        book: record.book, chapter: record.chapter, verse: record.verse, endVerse: record.endVerse,
                        startOffset: record.startOffset, endOffset: record.endOffset,
                        translationID: record.translationID, colorID: nil, quotedText: record.quotedText)
                    noteID = try markup.addNote(to: highlight, body: body, sourceThreadID: record.uuid).uuid
                }
            case .chapter, .book, .general:
                let chapter = record.scope == .book ? chapterAsked(in: ordered[...index], of: record) : record.chapterLocation
                noteID = try markup.addChapterNote(book: chapter.book, chapter: chapter.chapter, translationID: record.translationID,
                                                   body: body, sourceThreadID: record.uuid).uuid
            }
        }
        guard let noteID else { return }
        attempt { try markup.chat.setSavedNote(noteID, on: ordered[index]) }
        if let row = messages.firstIndex(where: { $0.id == messageID }) { messages[row].savedNoteID = noteID }
        updateLastReply()
        onMarkupChange()
        onNoteSaved?(noteID)
    }

    /// The innermost highlight in the thread's translation that contains its selection.
    private func enclosingHighlight(of record: ChatThread) throws -> Highlight? {
        try markup.highlights(in: record.chapterLocation)
            .filter {
                $0.translationID == record.translationID
                    && ($0.verse, $0.startOffset) <= (record.verse, record.startOffset)
                    && (record.endVerse, record.endOffset) <= ($0.endVerse, $0.endOffset)
            }
            .max { ($0.verse, $0.startOffset, -$0.endVerse, -$0.endOffset) < ($1.verse, $1.startOffset, -$1.endVerse, -$1.endOffset) }
    }

    /// The chapter a book thread was at when this turn was asked.
    private func chapterAsked(in messages: ArraySlice<ChatMessage>, of record: ChatThread) -> ChapterLocation {
        guard let attached = messages.last(where: { $0.attachedReference != nil })?.attachedReference,
              let reference = ReferenceParser.parse(attached), let chapter = reference.chapter
        else { return record.chapterLocation }
        return ChapterLocation(book: reference.book.id, chapter: chapter)
    }

    // MARK: - Deleting

    /// Undoable through `undoManager`; the panel stays open and asks where to start again.
    public func deleteThread(id: UUID) {
        guard let record = fetchThread(id) else { return }
        if threadID == id {
            stop()
            closeThread()
            isAskingForContext = isPanelShown
        }
        deleteUndoably(.thread(ThreadSnapshot(record)))
    }

    private func deleteUndoably(_ deletion: MarkupDeletion) {
        var captured: MarkupDeletion?
        attempt { captured = try markup.delete(deletion) }
        if let captured { registerUndo(restoring: captured) }
        reloadHistory()
    }

    /// As `MarkupModel`'s: the undo restores, its redo deletes again, alternating indefinitely.
    private func registerUndo(restoring deletion: MarkupDeletion) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { model in
            model.attempt { try model.markup.restore(deletion) }
            model.reloadHistory()
            model.undoManager?.registerUndo(withTarget: model) { model in
                if case .thread(let snapshot) = deletion { model.deleteThread(id: snapshot.uuid) }
            }
            model.undoManager?.setActionName(deletion.actionName)
        }
        undoManager.setActionName(deletion.actionName)
    }

    // MARK: - Private

    private func startPending(_ scope: ThreadScope, selection: TextSelection? = nil) {
        stop()
        closeThread()
        pendingScope = scope
        pendingSelection = selection
        isAskingForContext = false
        notice = nil
        isPanelShown = true
        composerFocusRequest += 1
    }

    private func closeThread() {
        threadID = nil
        thread = nil
        messages = []
        updateLastReply()
        lastSubmission = nil
        sendFailed = false
    }

    private func fetchThread(_ id: UUID) -> ChatThread? {
        var record: ChatThread?
        attempt { record = try markup.chat.thread(id: id) }
        return record
    }

    /// The open conversation as the store has it now; nil when none is open or it was deleted
    /// elsewhere (`refresh` then lets go of it).
    private var threadRecord: ChatThread? {
        guard let threadID else { return nil }
        do {
            return try markup.chat.thread(id: threadID)
        } catch {
            logger.error("Reading the open conversation failed: \(error)")
            return nil
        }
    }

    /// The header's copy of the open conversation; kept as it was when the record is gone, until
    /// `refresh` lets go of it.
    private func refreshThread() {
        guard threadID != nil else { thread = nil; return }
        if let record = threadRecord { thread = ChatThreadItem(record) }
    }

    private func loadAllThreads() {
        attempt {
            listedThreads = try markup.chat.allThreads().sorted { $0.updatedAt > $1.updatedAt }.map(ChatThreadItem.init)
        }
    }

    private func reloadHistory() {
        if isListingAllThreads { loadAllThreads() }
        guard let location else { history = []; return }
        attempt { history = try markup.chat.threads(in: location).map(ChatThreadItem.init) }
    }

    /// `providerLabel` replaces the one the record's provider makes.
    private func item(_ message: ChatMessage, providerLabel: String? = nil) -> ChatMessageItem {
        ChatMessageItem(
            id: message.uuid, role: message.role, content: message.content, displayText: message.displayText,
            providerLabel: message.role == .assistant
                ? providerLabel ?? label(providerID: message.providerID, modelName: message.modelName, host: message.providerHost) : nil,
            attachedReference: message.attachedReference, isStreaming: false,
            savedNoteID: message.savedNoteID.flatMap { id in (try? markup.note(id: id)) != nil ? id : nil },
            finishReason: message.finishReason.flatMap(ChatFinishReason.init(rawValue:)))
    }

    /// The host a reply recorded wins over the compatible endpoint in Settings, which may have changed.
    private func label(providerID: String, modelName: String, host: String?) -> String {
        let base = defaults.string(forKey: AssistantSettings.compatibleBaseURLKey).flatMap(URL.init(string:))
        return ProviderLabel.text(providerID: providerID, modelName: modelName, host: host ?? base?.host())
    }

    private func attempt(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            notice = .failed
            logger.error("Assistant storage failed: \(error)")
        }
    }

    /// A template as `prompts` lists it, and where Settings ordered it.
    private struct TemplateRow {
        let item: PromptTemplateItem
        let sortOrder: Int
    }

    private static func book(_ code: String) -> Book {
        BookCatalog.book(code: code) ?? Book(id: code, canon: .oldTestament, order: 0, name: code, shortName: code)
    }

    /// "Matthew 5", "Psalm 119".
    static func reference(_ location: ChapterLocation) -> String {
        Reference(book: book(location.book), chapter: location.chapter).displayString
    }

    private static func selection(of record: ChatThread) -> TextSelection? {
        guard record.scope == .selection else { return nil }
        return TextSelection(book: record.book, chapter: record.chapter, verse: record.verse, endVerse: record.endVerse,
                             startOffset: record.startOffset, endOffset: record.endOffset, quotedText: record.quotedText)
    }

    /// A reply to a cloud provider while the on-device model can answer may fall back to it.
    private static func mayFallBack(from provider: any LLMProvider, among providers: [any LLMProvider]) -> Bool {
        provider.id != .appleOnDevice && providers.contains { $0.id == .appleOnDevice && $0.availability == .available }
    }

    private static func isCloud(_ decision: RoutingDecision) -> Bool {
        if case .provider(let provider) = decision { return provider.id != .appleOnDevice }
        return false
    }

    private static func notice(for decision: RoutingDecision) -> AssistantNotice {
        switch decision {
        case .provider: .failed
        case .tooLongForOnDevice: .tooLongForOnDevice
        case .onDeviceUnavailable(let reason): .onDeviceUnavailable(reason)
        case .nothingConfigured: .nothingConfigured
        }
    }

    private static func notice(for error: any Error, providerID: LLMProviderID?) -> AssistantNotice {
        guard let error = error as? LLMProviderError else { return .failed }
        switch error {
        case .unauthorized: return .unauthorized
        case .rateLimited: return .rateLimited
        case .declined: return .declined
        case .cutShort: return .cutShort
        case .tooLong: return providerID == .appleOnDevice ? .tooLongForOnDevice : .failed
        case .server: return .failed
        case .transport: return .unreachable
        case .unavailable(let reason): return .onDeviceUnavailable(reason)
        }
    }
}
