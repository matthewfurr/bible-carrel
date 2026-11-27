# Milestone 5: Study Assistant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A study assistant beside the page: ask about a selection or run a chapter prompt from the heading, read the streamed reply in the right-hand panel labelled with the model that answered, keep the conversation as a thread that reopens from history, and save a reply as a note. Apple's on-device model answers by default; Anthropic, OpenAI and OpenAI-compatible endpoints answer when a key is in the Keychain or the passage is too long for the on-device window.

**Architecture:** A new `ScriptureLLM` library in `Packages/ScriptureKit` holds the provider protocol and value types, a pure SSE parser, the three cloud providers over `URLSession`, the Foundation Models provider behind `#if canImport(FoundationModels)`, the token estimate and on-device fit rules, the router, the Keychain-backed `SecretStore`, the built-in prompts and the `PromptBuilder`. `ScriptureModel` gains three SwiftData models (`ChatThread`, `ChatMessage`, `PromptTemplate`), a `sourceThreadID` on `Note`, and two stores (`ChatStore`, `PromptTemplateStore`) on the existing container. `ScriptureUI` gains an `@Observable` `AssistantModel` that composes prompts from `BibleStore`, routes them, streams replies into value-copied messages, persists threads and saves notes; the chat panel that shares the inspector with the notes column; the chapter heading menu; the Settings tabs for providers and prompts; and thread rows in the Notes browser. The app target builds the providers from Settings and the Keychain and wires the menu, the shortcut and the panel.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, FoundationModels (`SystemLanguageModel`, `LanguageModelSession.streamResponse`), `URLSession.bytes(for:)` with Server-Sent Events, Security framework (`SecItemAdd` with `kSecAttrSynchronizable`), Swift Testing with a `URLProtocol` stub. GRDB stays the only third-party dependency.

**Spec:** `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (Decisions › LLM, My calls › on-device limits, Architecture › LLM layer and Data model, Milestones › 5, Verification › LLM). Design rules: `PRODUCT.md`, `DESIGN.md` (Assistant tokens, `assistant-reply` component, symbol inventory), `CLAUDE.md`.

## Global Constraints

- Minimum macOS 26 / iOS 26, Swift language mode 6, Swift Testing, SF Symbols only. GRDB stays the only third-party dependency; no Anthropic or OpenAI SDK (the spec: `URLSession` against `POST /v1/messages` and `/v1/chat/completions`, both streaming SSE).
- Anthropic: `POST https://api.anthropic.com/v1/messages`, headers `x-api-key`, `anthropic-version: 2026-10-21`, `content-type: application/json`; body `{model, max_tokens, stream: true, system, messages}` with no sampling parameters (`temperature` is rejected on this API version). Default model `claude-opus-5-5`, editable in Settings. Text arrives in `content_block_delta` events with `delta.type == "text_delta"`; `message_delta` carries `stop_reason`, and `refusal` is reported to the reader as a decline, not an error.
- OpenAI and compatible: `POST {baseURL}/chat/completions`, header `Authorization: Bearer <key>`, body `{model, stream: true, messages}` with the system prompt as the first message; text in `choices[0].delta.content`; the stream ends at `data: [DONE]`. OpenAI's base URL is `https://api.openai.com/v1`, default model `gpt-5`; the compatible provider takes both from Settings.
- On-device: `SystemLanguageModel.default`, a context window of 4,096 tokens shared by prompt and reply. Tokens are estimated at one per four characters (`TokenEstimator`, rounded up); a request is sent on-device only when instructions plus prompt estimate at or under 3,000 tokens, leaving the rest for the reply (`maximumResponseTokens` 1,000). Routing falls back to a cloud provider when a key is configured, otherwise shows the too-long notice.
- API keys live in the Keychain as generic passwords (service `com.matthewfurr.ReadingThroughScripture`, account `llm.<providerID>`), `kSecAttrSynchronizable` on so iCloud Keychain carries them. Ad-hoc signing has no keychain-access-groups entitlement, so a synchronizable write that fails with `errSecMissingEntitlement` (-34018) is retried without the flag. Keys are never written to `UserDefaults` or the log.
- Settings keys in `UserDefaults`: `assistantProvider` (`auto`, `appleOnDevice`, `anthropic`, `openAI`, `openAICompatible`; default `auto`), `anthropicModel`, `openAIModel`, `compatibleBaseURL`, `compatibleModel`. Prompt templates are SwiftData records, seeded once from `BuiltInPrompts`.
- Design (from the discovery interview): a plain click on the chapter heading never starts a chat; opening the assistant without a passage asks before including where the reader is; Add as Note opens the saved note for editing. The assistant is the only user of the `assistant` and `assistant.wash` tokens and of the `sparkles` symbol (DESIGN.md › Assistant). A reply row is the `assistant-reply` component: `assistant.wash` fill at `AppRadius.lg`, `AppSpacing.sm` vertical and `AppSpacing.md` horizontal padding, `.callout` in `ink.primary`. A reply saved as a note drops the wash and becomes an ordinary note. No fixed-point fonts, no inline colors, no cards by reflex, no shadow (DESIGN.md › Don'ts; CLAUDE.md's three rules). New symbols go into DESIGN.md's inventory.
- Deletes stay undoable through the window's `UndoManager`: deleting a thread registers an undo like a note delete does.
- Reader, column, editor, browser and Settings behaviour from milestones 2 to 4 is unchanged except where this plan names a change. Existing public signatures stay; additions only.
- Tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (232 pass on main). Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData build`. No test touches the real Keychain or the network; `URLProtocol` stubs and an in-memory `SecretStore` stand in.
- Git in this worktree: `/usr/bin/git`, one command per call. Commit per task, ending with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Never merge or push.
- Matt's store (`~/Library/Application Support/ReadingThroughScripture/Markup.store`) holds test data; the in-app verification may add threads and notes to it, nothing else.

## Rulings (plan-level decisions the spec leaves open)

1. **Three ways in, one panel (Matt, discovery interview 2026-10-30).** (a) Right-click a selection, "Ask About This Passage": the panel opens in selection scope with the cursor in the composer and the selection prompts (Explain this, Define words, Compare translations) as a short list above it; clicking one sends it at once. (b) Right-click the chapter heading, "Ask About This Chapter": the same, in chapter scope, with the chapter prompts (Catch me up, Overall summary, Outline, ...) listed above the composer. A plain click on the heading does not open a chat: it goes back to the front page's chapter grid for this book, as other Bible readers do. (c) ⇧⌘A, the toolbar `sparkles` button or View › Assistant with nothing chosen: the panel opens and asks first, in one line above the composer, "Include where you are?" with three bordered buttons, `Matthew 5`, `Matthew` and `No context`; the choice sets the scope and lists that scope's prompts (none for No context). If text is selected when the shortcut is pressed, it behaves as (a). A thread is created when the first message is sent, not when the panel opens; a thread's title is the reference and the first 40 characters of the quoted text (selection), `"<Template title>: Matthew 5"` or the first 60 characters of a typed question (chapter, book, general).

2. **Where the reader is, the model knows, unless asked not to.** Every request's system instructions name the reference, translation and scope; a general thread (No context) gets the role alone and no passage text, and is still filed under the chapter it was opened from so history finds it. `ThreadScope` gains `general` (an additive enum case on the Task 8 model). A selection thread carries the quoted text in its first message. A chapter or book thread's first message carries the chapter text. When a book thread's next question comes from another chapter, that message has `attachedReference` set and its prompt is prefixed with the new reference and chapter text.
3. **On-device history is trimmed, cloud gets everything.** The Foundation Models provider gets a fresh `LanguageModelSession` per request with the instructions, and the prior turns flattened into the prompt (`Reader:` / `Assistant:` lines); `OnDeviceFit.trim` drops the oldest exchanges until the estimate fits, keeping at most four exchanges for book threads. Cloud providers receive the whole thread as `messages`.
4. **Catch me up and Compare translations stay inside the window.** `StudyPromptComposer` builds Catch me up with the previous chapter's full text when the request fits, otherwise its first and last five verses (the spec's rule). Compare translations lists the selected verses in every other bundled translation for cloud routes and at most three (the first three in `BibleStore.translations()` order, skipping the current one) when the on-device model will answer.
5. **Outline is plain text.** The spec's `@Generable` structured output for Outline is deferred: the built-in Outline prompt asks for a numbered list with verse ranges, which renders through `NoteMarkdown` already. `PromptTemplate.outputKind` is stored (`text`) so the field exists for sync, and nothing reads it yet.
6. **Add as Note saves the reply and opens it for editing.** On a selection thread the reply is saved as a note anchored to the selection: the existing highlight's note if the selection lies inside a highlight (appended after a blank line), otherwise a new colorless anchor with a new note. On a chapter, book or general thread it becomes a chapter note (scope `.chapter`, verse 0, shown in the band under the heading). The body is `**Q:** <question>\n\n<reply>` so the question can be kept or deleted; `sourceThreadID` is the thread's uuid. Then the inspector returns to the Notes column with that note in the editor and its highlight lit, so the reply can be trimmed into the note the reader wants.

7. **Model labels.** Each assistant message stores `providerID` and `modelName`; the row's label reads `On-device`, `Claude · claude-opus-5-5`, `OpenAI · gpt-5`, or `<host> · <model>` for a compatible endpoint, in the `assistant` plum at `.caption`.
8. **Routing order under `auto`.** On-device when available and the request fits; otherwise the first configured cloud provider in the order Anthropic, OpenAI, compatible. A chosen cloud provider without a key falls back to `auto`. A chosen on-device provider that cannot take the request behaves as `auto` does (cloud if configured, else the too-long notice), so the reader never sees a dead end that Settings cannot fix.
9. **Failures are sentences.** The panel shows one plain sentence per failure class (`AssistantNotice`): on-device unavailable (device not eligible, Apple Intelligence off, model downloading), too long for on-device (with the Settings button), key rejected (401 or 403), rate limited (429), unreachable (transport error), declined (refusal or guardrail), and a generic failure. The technical detail goes to the log under category `assistant`.
10. **Threads in the Notes browser** are a fourth kind: filter "Threads", `sparkles` marker in plum, the title as the first line and the last message's first line below, newest by `updatedAt`. Showing one opens the chapter in the thread's translation and the thread in the panel. Delete is confirmed there as other kinds are, and undoable.
11. **Cancel.** A Stop button replaces Send while a reply streams; cancelling keeps whatever text arrived and marks nothing. A cancelled reply with no text leaves the thread without an assistant message, and the question remains so it can be sent again.

## Design brief: the chat panel (impeccable-swift `shape`, from the discovery interview with Matt, 2026-10-30)

- **Feature.** The assistant in the right-hand slot of the reader, taking the notes column's place while a conversation is open. Product register. One reader at a desk, mouse and keyboard, daylight or a lamp. The reader types like chat; the assistant answers like notes, so the two sides of the transcript look different on purpose.
- **Primary action.** Read the reply beside the text, then keep it (Add as Note) or follow up (type).
- **Feel.** Patient, literate, unobtrusive.
- **Surface.** macOS inspector, 260 to 480 pt, on `paper.panel`. Dynamic Type baseline AX3: every size a text style or a `@ScaledMetric`. Reduce Motion: the column-to-panel swap is a cut.
- **Color strategy.** Restrained. Plum (`assistant`) only on the `sparkles` symbol, the model label and the reply block; verdigris on the send control and selection; everything else ink on paper. Anchors: Reeder's article pane, Things' quick entry, Craft's rendered note.
- **Layout.** Header like the notes column's: `sparkles` + "Assistant" headline, the scope as a Label (`Matthew 5:3`, `Matthew 5`, `Matthew`, or `No context`), trailing `plus` menu (new conversation: this chapter, this book, no context), `clock` menu (history for this location) and `xmark` (back to Notes). Hairline. The transcript in a `ScrollView`. Hairline. Above the composer, one of: the prompt list for the scope (rows of `.plain` buttons with a `text.quote` glyph, one per enabled template, shown until the first message is sent), or the "Include where you are?" line with its three `.bordered` `.controlSize(.small)` buttons, or nothing. The composer last.
- **Transcript.** A reader turn is a light bubble: `.callout` `ink.primary` on `paper.overlay` at `AppRadius.lg`, `AppSpacing.xs` by `AppSpacing.sm` padding, trailing-aligned and at most four fifths of the width, no stroke, no tail. An assistant turn is a document block: full width, `NoteMarkdown.blocks` rendered in `.callout` `ink.primary` with `AppSpacing.xs` between paragraphs and headings in the same style notes use, on `assistant.wash` at `AppRadius.lg` with `AppSpacing.sm` by `AppSpacing.md` padding (DESIGN.md's `assistant-reply`), and a footer line: the model label in `assistant` plum `.caption`, Spacer, `doc.on.doc` Copy and `note.text.badge.plus` Add as Note as `RowSymbolButton`s. Turns are `AppSpacing.sm` apart; the attached reference, when a book thread moved chapter, is a Label above the bubble.
- **States.** Just opened from a selection or the heading (prompt list, empty composer, cursor in it); just opened by shortcut (the context question); streaming (the reply block grows; a small `ProgressView` with "Answering" sits in its footer until the first delta; Stop replaces Send); done; notice (too long, unavailable, nothing configured, key rejected, rate limited, unreachable, declined: one sentence in `ink.secondary` where the prompt list sits, with an "Open Settings" bordered button for the first four); empty history ("No conversations here yet", disabled); no templates enabled (no list).
- **Interaction.** Return sends; Shift-Return inserts a newline; Escape returns to Notes; ⇧⌘A shows or hides the panel; the heading's context menu offers "Ask About This Chapter"; the selection's offers "Ask About This Passage". Every symbol button has `.help` and an accessibility label; each turn is one VoiceOver element ("You" or "Assistant, Claude").
- **Copy.** Header "Assistant". Composer prompt "Ask about Matthew 5:3" / "Ask about Matthew 5" / "Ask about Matthew" / "Ask anything". Context line "Include where you are?". Buttons "Open Settings", "Stop", "Send", "Copy", "Add as Note". Notices as in Ruling 9.
- **Anti-goals.** Avatars, a typing indicator, a sheet for anything, a gradient or glass on the panel, a plain click on the heading that starts a chat, plum anywhere but the three places named.

## Review Focus

1. A thread whose translation is no longer bundled, opened from history or the browser: the chapter must open in the current translation and the thread still show (Task 9 test `openingAThreadInAnUnbundledTranslationKeepsTheCurrentOne`).
2. An SSE stream cut mid-event (connection dropped): the text received so far is kept as the reply and the panel reports "unreachable" rather than losing the partial answer (Task 3 test `truncatedStreamThrowsAfterTheDeltasReceived`, Task 9 test `aFailureAfterDeltasKeepsThePartialReply`).
3. A chapter prompt on a chapter of a translation that lacks the previous chapter (Catch me up on the first chapter of a book, or on Matthew 1): `{{previous_chapter_text}}` resolves to an empty string and the prompt still runs (Task 9 test `catchMeUpOnTheFirstChapterHasNoPreviousText`).
4. A key pasted with surrounding whitespace or a newline: it is trimmed before storage so a copied key works (Task 4 test `keysAreTrimmedBeforeStorage`).
5. A template body with a placeholder the app does not know (`{{verse}}`): the placeholder is left as typed rather than crashing or silently dropped, so the reader sees it in the reply and fixes the template (Task 5 test `unknownPlaceholdersAreLeftAsTyped`).

---

## File Structure

**ScriptureLLM (create, `Packages/ScriptureKit/Sources/ScriptureLLM/`)**
- `LLMProvider.swift`: `LLMProviderID`, `LLMRole`, `LLMMessage`, `LLMRequest`, `LLMEvent`, `LLMUsage`, `LLMAvailability`, `LLMProviderError`, `protocol LLMProvider`.
- `TokenEstimator.swift`: `TokenEstimator.estimate(_:)`, `LLMRequest.estimatedTokens`.
- `SSEParser.swift`: incremental Server-Sent Events parsing to `SSEEvent`.
- `AnthropicProvider.swift`, `OpenAICompatibleProvider.swift`: the cloud providers; `HTTPStreaming.swift` for the shared request/response/status handling.
- `SecretStore.swift`: `protocol SecretStore`, `InMemorySecretStore`, `KeychainStore`.
- `BuiltInPrompts.swift`: the eleven chapter and three selection prompts as `PromptSeed` values.
- `PromptBuilder.swift`: `PromptContext`, placeholder filling, `SystemInstructions.text(for:)`.
- `OnDeviceFit.swift`: `OnDeviceFit.limit`, `fits(_:)`, `trim(_:keeping:)`.
- `AppleFoundationProvider.swift`: the Foundation Models provider.
- `LLMRouter.swift`: `LLMRouter`, `RoutingPreference`, `RoutingDecision`.
- Tests in `Tests/ScriptureLLMTests/`: `TokenEstimatorTests`, `SSEParserTests`, `AnthropicProviderTests`, `OpenAICompatibleProviderTests`, `StubURLProtocol` (helper), `SecretStoreTests`, `PromptBuilderTests`, `OnDeviceFitTests`, `LLMRouterTests`, `FakeProvider` (helper).

**ScriptureModel (modify/create)**
- `ChatThread.swift`, `ChatMessage.swift`, `PromptTemplate.swift` (create): the models.
- `Note.swift` (modify): `sourceThreadID: UUID?`.
- `MarkupContainer.swift` (modify): the three models join the schema.
- `ChatStore.swift` (create): thread queries and mutations, `ThreadSnapshot`, `MarkupDeletion.thread`.
- `PromptTemplateStore.swift` (create): `PromptSeed`, seeding, queries and mutations.
- `MarkupSnapshot.swift` (modify): `MarkupDeletion.thread(ThreadSnapshot)`; `MarkupStore.swift` (modify): `delete`/`restore` handle it; `addNote(to:body:sourceThreadID:)`, `addChapterNote`, `appendToNote`.
- Tests: `ChatStoreTests`, `PromptTemplateStoreTests`, additions to `MarkupStoreTests`.

**ScriptureUI (create/modify)**
- `StudyPromptComposer.swift` (create): chapter text, previous chapter, other translations from `BibleStore` into `PromptContext`.
- `AssistantItems.swift` (create): `ChatThreadItem`, `ChatMessageItem`, `PromptTemplateItem`, `AssistantNotice`, `ProviderLabel`.
- `AssistantModel.swift` (create): the panel's state and every action.
- `ChatPanelView.swift`, `ChatTurnRow.swift`, `AssistantComposer.swift` (create): the panel.
- `ReaderView.swift` (modify): the heading gets a context menu (`onAskAboutChapter`); a plain click calls `onHeadingTap`.
- `InspectorContentView.swift` (create): notes column or chat panel.
- `MarkupContextMenu.swift`, `MarkupModel.swift`, `NotesColumnItem.swift` (modify): `askAboutPassage` enabled, calls `onAskAboutPassage`.
- `AssistantSettingsView.swift`, `PromptTemplatesSettingsView.swift`, `AssistantSettings.swift` (create): Settings tabs and keys.
- `NotesBrowserEntry.swift`, `NotesBrowserModel.swift`, `NotesBrowserRow.swift`, `NotesBrowserView.swift`, `MarkupTarget.swift` (modify): thread entries.
- `Palette.swift` unchanged (tokens exist); `Metrics.swift` unchanged.
- Tests: `StudyPromptComposerTests`, `AssistantModelTests`, `AssistantSettingsTests`, additions to `NotesBrowserModelTests`, `NotesBrowserQueryTests`.

**App (modify)**
- `ReadingThroughScriptureApp.swift`: builds `KeychainStore`, `ChatStore`, `PromptTemplateStore`, `AssistantModel`; the Assistant menu (⇧⌘A); Settings tabs.
- `MainWindowView.swift`: `InspectorContentView`, heading wiring, context-menu wiring, location updates.
- `SettingsView.swift`: Assistant and Prompts tabs.
- `README.md`, `DESIGN.md` (symbol inventory, component note): documentation.

---

### Task 1: `ScriptureLLM` target, provider protocol and token estimate

**Files:**
- Modify: `Packages/ScriptureKit/Package.swift` (library `ScriptureLLM` depending on `ScriptureData` and `ScriptureModel`; test target `ScriptureLLMTests`; `ScriptureUI` depends on `ScriptureLLM`; `ScriptureUITests` resources unchanged)
- Create: `Packages/ScriptureKit/Sources/ScriptureLLM/LLMProvider.swift`, `TokenEstimator.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureLLMTests/TokenEstimatorTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum LLMProviderID: String, CaseIterable, Codable, Sendable { case appleOnDevice, anthropic, openAI, openAICompatible }
  public enum LLMRole: String, Codable, Sendable { case user, assistant }
  public struct LLMMessage: Equatable, Sendable { public let role: LLMRole; public let content: String }
  public struct LLMRequest: Equatable, Sendable {
      public let instructions: String      // system prompt
      public let messages: [LLMMessage]    // oldest first; the last is the user's new turn
      public let maxTokens: Int            // reply budget; cloud default 4096, on-device 1000
      public var estimatedTokens: Int      // TokenEstimator over instructions and every message
  }
  public struct LLMUsage: Equatable, Sendable { public let inputTokens: Int?; public let outputTokens: Int? }
  public enum LLMEvent: Equatable, Sendable { case textDelta(String); case done(LLMUsage?) }
  public enum LLMAvailability: Equatable, Sendable { case available; case unavailable(reason: String) }
  public enum LLMProviderError: Error, Equatable, Sendable {
      case unauthorized                    // 401 or 403
      case rateLimited                     // 429
      case declined(String)                // refusal / guardrail, with the provider's sentence or ""
      case tooLong                         // the provider's own window refused the request
      case server(status: Int, message: String)
      case transport(String)               // URLError and truncated streams
      case unavailable(String)             // on-device model not usable
  }
  public protocol LLMProvider: Sendable {
      var id: LLMProviderID { get }
      var modelName: String { get }
      var maxContextTokens: Int? { get }          // nil for cloud
      var availability: LLMAvailability { get }
      func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, any Error>
  }
  public enum TokenEstimator { public static func estimate(_ text: String) -> Int }   // ceil(utf8.count / 4), 0 for ""
  ```

- [x] **Step 1: Write the failing test**

```swift
@Suite struct TokenEstimatorTests {
    @Test func fourCharactersPerTokenRoundedUp() {
        #expect(TokenEstimator.estimate("") == 0)
        #expect(TokenEstimator.estimate("abcd") == 1)
        #expect(TokenEstimator.estimate("abcde") == 2)
        #expect(TokenEstimator.estimate(String(repeating: "a", count: 4000)) == 1000)
    }
    @Test func requestEstimateCoversInstructionsAndMessages() {
        let request = LLMRequest(instructions: String(repeating: "i", count: 40), messages: [
            LLMMessage(role: .user, content: String(repeating: "u", count: 8)),
            LLMMessage(role: .assistant, content: String(repeating: "a", count: 9)),
        ], maxTokens: 100)
        #expect(request.estimatedTokens == 10 + 2 + 3)
    }
}
```

- [x] **Step 2: Run to verify failure** — `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit --filter TokenEstimatorTests`. Expected: the build fails, no module `ScriptureLLM`.

- [x] **Step 3: Add the targets to `Package.swift` and implement the two files** with the interfaces above. `LLMRequest.init(instructions:messages:maxTokens:)` is the only initializer; `estimatedTokens` sums `TokenEstimator.estimate` over `instructions` and each message's `content`.

- [x] **Step 4: Run the whole suite** — expected 232 + 2 pass.

- [x] **Step 5: Commit** — `feat: ScriptureLLM target with the provider protocol and token estimate`

---

### Task 2: `SSEParser`

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureLLM/SSEParser.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureLLMTests/SSEParserTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct SSEEvent: Equatable, Sendable { public let name: String?; public let data: String }
  public struct SSEParser: Sendable {
      public init()
      /// Feeds one chunk (any split point) and returns the events completed by it.
      public mutating func feed(_ chunk: String) -> [SSEEvent]
      /// Feeds raw bytes; partial UTF-8 at the end is held for the next chunk.
      public mutating func feed(_ bytes: some Sequence<UInt8>) -> [SSEEvent]
      /// Flushes a final event that had no trailing blank line.
      public mutating func finish() -> [SSEEvent]
  }
  ```
  Rules (WHATWG EventSource): lines end at `\n`, `\r\n` or `\r`; a blank line dispatches; `event:` sets the name; several `data:` lines join with `\n`; one optional space after the colon is dropped; a line starting with `:` is a comment; `id:` and `retry:` are ignored; an event with no data lines is not dispatched.

- [x] **Step 1: Write the failing tests**

```swift
@Suite struct SSEParserTests {
    @Test func eventsSplitAcrossChunksAreReassembled() {
        var parser = SSEParser()
        #expect(parser.feed("event: content_block_delta\ndata: {\"a\":") == [])
        #expect(parser.feed("1}\n\n") == [SSEEvent(name: "content_block_delta", data: "{\"a\":1}")])
    }
    @Test func multipleDataLinesJoinAndCommentsAreIgnored() {
        var parser = SSEParser()
        let events = parser.feed(": ping\ndata: one\ndata:two\n\ndata: [DONE]\n\n")
        #expect(events == [SSEEvent(name: nil, data: "one\ntwo"), SSEEvent(name: nil, data: "[DONE]")])
    }
    @Test func carriageReturnsAndFinishAreHandled() {
        var parser = SSEParser()
        #expect(parser.feed("data: a\r\n\r\ndata: b") == [SSEEvent(name: nil, data: "a")])
        #expect(parser.finish() == [SSEEvent(name: nil, data: "b")])
        #expect(parser.finish() == [])
    }
    @Test func bytesSplitInsideAMultibyteCharacterAreHeld() {
        var parser = SSEParser()
        let bytes = Array("data: é\n\n".utf8)
        #expect(parser.feed(bytes[..<7]) == [])
        #expect(parser.feed(bytes[7...]) == [SSEEvent(name: nil, data: "é")])
    }
}
```

- [x] **Step 2: Run to verify failure** — `--filter SSEParserTests`; expected compile failure.

- [x] **Step 3: Implement `SSEParser`** as a buffer of pending text plus the current event's name and data lines; `feed(_ bytes:)` decodes the longest valid UTF-8 prefix and keeps the remainder.

- [x] **Step 4: Run the suite** — expected all pass.

- [x] **Step 5: Commit** — `feat: incremental Server-Sent Events parser`

---

### Task 3: Anthropic and OpenAI-compatible providers over `URLSession`

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureLLM/HTTPStreaming.swift`, `AnthropicProvider.swift`, `OpenAICompatibleProvider.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureLLMTests/StubURLProtocol.swift`, `AnthropicProviderTests.swift`, `OpenAICompatibleProviderTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct AnthropicProvider: LLMProvider {
      public static let defaultModel = "claude-opus-5-5"
      public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
      public static let apiVersion = "2026-10-21"
      public init(apiKey: String, modelName: String = defaultModel, session: URLSession = .shared)
      // id .anthropic, maxContextTokens nil, availability .available
  }
  public struct OpenAICompatibleProvider: LLMProvider {
      public static let openAIBaseURL = URL(string: "https://api.openai.com/v1")!
      public static let defaultOpenAIModel = "gpt-5"
      /// `id` is `.openAI` when `baseURL == openAIBaseURL`, else `.openAICompatible`.
      public init(baseURL: URL, apiKey: String, modelName: String, session: URLSession = .shared)
  }
  /// Shared by both: builds the request, opens `session.bytes(for:)`, maps non-2xx to
  /// `LLMProviderError` (401/403 unauthorized, 429 rateLimited, else server(status:message:) with the
  /// body's `error.message` when present), feeds `SSEParser`, and turns `URLError` and an EOF
  /// before the terminal event into `.transport`.
  enum HTTPStreaming {
      static func stream(request: URLRequest, session: URLSession, parse: @escaping @Sendable (SSEEvent) throws -> [LLMEvent]?) -> AsyncThrowingStream<LLMEvent, any Error>
  }
  ```
  `parse` returns the events for one SSE event, or `nil` when the stream is complete (Anthropic `message_stop`; OpenAI `[DONE]`). Anthropic: `content_block_delta` with `delta.type == "text_delta"` yields `.textDelta`; `message_delta` with `stop_reason == "refusal"` throws `LLMProviderError.declined("")`, with `stop_reason == "max_tokens"` is ignored; `usage.output_tokens` from `message_delta` and `usage.input_tokens` from `message_start` fill `LLMUsage` in `.done`; an `error` event throws `.server(status: 0, message:)`. OpenAI: `choices[0].delta.content` yields `.textDelta`; `choices[0].finish_reason == "content_filter"` throws `.declined("")`; `usage` when present fills `.done`.
  Request bodies: Anthropic `{"model", "max_tokens", "stream": true, "system": instructions, "messages": [{"role","content"}]}`; OpenAI `{"model", "stream": true, "stream_options": {"include_usage": true}, "messages": [{"role":"system","content": instructions}] + turns}`. Both send `content-type: application/json` and `accept: text/event-stream`; Anthropic sends `x-api-key` and `anthropic-version`, OpenAI `Authorization: Bearer`.

- [x] **Step 1: Write the stub and the failing tests**

`StubURLProtocol`: a `URLProtocol` subclass whose `handler: @Sendable (URLRequest) -> (HTTPURLResponse, [Data])` is stored in a lock-protected static; it replays each `Data` chunk through `client?.urlProtocol(_:didLoad:)` and then `urlProtocolDidFinishLoading`, or `didFailWithError` when the handler's response status is 0. `StubURLProtocol.session()` returns a `URLSession` whose configuration's `protocolClasses` is `[StubURLProtocol.self]`. A `recordedRequest` static captures the last request with its `httpBody` (read from `httpBodyStream` when needed) so tests can assert on it.

```swift
@Suite(.serialized) struct AnthropicProviderTests {
    private func collect(_ provider: some LLMProvider, _ request: LLMRequest) async throws -> [LLMEvent] {
        var events: [LLMEvent] = []
        for try await event in provider.stream(request) { events.append(event) }
        return events
    }
    private let request = LLMRequest(instructions: "Be brief.", messages: [LLMMessage(role: .user, content: "Who wrote Matthew?")], maxTokens: 256)

    @Test func sendsTheMessagesRequestAndStreamsTextDeltas() async throws {
        StubURLProtocol.handler = { _ in (HTTPURLResponse(url: AnthropicProvider.endpoint, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/event-stream"])!, [
            Data("event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":12}}}\n\nevent: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Tradition says \"}}\n\n".utf8),
            Data("event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Matthew.\"}}\n\nevent: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"output_tokens\":5}}\n\nevent: message_stop\ndata: {\"type\":\"message_stop\"}\n\n".utf8),
        ]) }
        let provider = AnthropicProvider(apiKey: "sk-test", session: StubURLProtocol.session())
        let events = try await collect(provider, request)
        #expect(events == [.textDelta("Tradition says "), .textDelta("Matthew."), .done(LLMUsage(inputTokens: 12, outputTokens: 5))])
        let sent = StubURLProtocol.recordedRequest!
        #expect(sent.url == AnthropicProvider.endpoint && sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "x-api-key") == "sk-test")
        #expect(sent.value(forHTTPHeaderField: "anthropic-version") == "2026-10-21")
        let body = try JSONSerialization.jsonObject(with: StubURLProtocol.recordedBody!) as! [String: Any]
        #expect(body["model"] as? String == "claude-opus-5-5" && body["stream"] as? Bool == true && body["max_tokens"] as? Int == 256)
        #expect(body["system"] as? String == "Be brief." && body["temperature"] == nil)
        #expect((body["messages"] as? [[String: String]]) == [["role": "user", "content": "Who wrote Matthew?"]])
    }
    @Test func unauthorizedAndRateLimitedAndServerErrorsAreTyped() async throws {
        for (status, expected) in [(401, LLMProviderError.unauthorized), (403, .unauthorized), (429, .rateLimited), (500, .server(status: 500, message: "Overloaded"))] {
            StubURLProtocol.handler = { _ in (HTTPURLResponse(url: AnthropicProvider.endpoint, statusCode: status, httpVersion: nil, headerFields: nil)!, [Data("{\"type\":\"error\",\"error\":{\"type\":\"x\",\"message\":\"Overloaded\"}}".utf8)]) }
            let provider = AnthropicProvider(apiKey: "k", session: StubURLProtocol.session())
            await #expect(throws: expected) { try await collect(provider, request) }
        }
    }
    @Test func refusalStopReasonIsADecline() async throws {
        StubURLProtocol.handler = { _ in (HTTPURLResponse(url: AnthropicProvider.endpoint, statusCode: 200, httpVersion: nil, headerFields: nil)!, [Data("event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"refusal\"},\"usage\":{\"output_tokens\":0}}\n\n".utf8)]) }
        let provider = AnthropicProvider(apiKey: "k", session: StubURLProtocol.session())
        await #expect(throws: LLMProviderError.declined("")) { try await collect(provider, request) }
    }
    @Test func truncatedStreamThrowsAfterTheDeltasReceived() async throws {
        StubURLProtocol.handler = { _ in (HTTPURLResponse(url: AnthropicProvider.endpoint, statusCode: 200, httpVersion: nil, headerFields: nil)!, [Data("event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Half\"}}\n\n".utf8)]) }
        let provider = AnthropicProvider(apiKey: "k", session: StubURLProtocol.session())
        var received: [LLMEvent] = []
        var failure: (any Error)?
        do { for try await event in provider.stream(request) { received.append(event) } } catch { failure = error }
        #expect(received == [.textDelta("Half")])
        #expect(failure as? LLMProviderError == .transport("The stream ended before the reply was complete."))
    }
}
```

`OpenAICompatibleProviderTests` mirrors the first test for `OpenAICompatibleProvider(baseURL: .openAIBaseURL, apiKey: "k", modelName: "gpt-5", session:)`: asserts the URL is `https://api.openai.com/v1/chat/completions`, the `Authorization` header is `Bearer k`, the body's first message is `{"role":"system","content":"Be brief."}`, `stream` is true; the chunks `data: {"choices":[{"delta":{"content":"Tra"}}]}\n\n`, `data: {"choices":[{"delta":{"content":"dition"}}]}\n\n`, `data: {"choices":[],"usage":{"prompt_tokens":9,"completion_tokens":2}}\n\ndata: [DONE]\n\n` yield `[.textDelta("Tra"), .textDelta("dition"), .done(LLMUsage(inputTokens: 9, outputTokens: 2))]`; a second test `idFollowsTheBaseURL` checks `.openAI` for the OpenAI base URL and `.openAICompatible` for `http://localhost:11434/v1`, and that the compatible URL's request goes to `http://localhost:11434/v1/chat/completions` (a trailing slash on the base URL is tolerated).

- [x] **Step 2: Run to verify failure** — `--filter AnthropicProviderTests`; expected compile failure.

- [x] **Step 3: Implement `HTTPStreaming`, `AnthropicProvider`, `OpenAICompatibleProvider`.** Bodies are built with `JSONSerialization` from `[String: Any]` (no Codable models needed). The stream is an `AsyncThrowingStream` whose task reads `session.bytes(for:)`, checks the status first (reading the whole body for the error message on non-2xx), then feeds the parser byte by byte through `feed(_ bytes:)` in chunks of the `AsyncBytes` sequence; cancellation of the consumer cancels the task (`continuation.onTermination`). The transport message for an early EOF is exactly `"The stream ended before the reply was complete."`.

- [x] **Step 4: Run the suite** — expected all pass.

- [x] **Step 5: Commit** — `feat: Anthropic and OpenAI-compatible streaming providers over URLSession`

---

### Task 4: `SecretStore` and the Keychain

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureLLM/SecretStore.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureLLMTests/SecretStoreTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public protocol SecretStore: Sendable {
      func secret(for id: LLMProviderID) throws -> String?
      /// Trims whitespace and newlines; an empty result deletes the item.
      func setSecret(_ value: String?, for id: LLMProviderID) throws
  }
  public final class InMemorySecretStore: SecretStore { public init() }   // lock-protected dictionary
  public struct KeychainStore: SecretStore {
      public static let service = "com.matthewfurr.ReadingThroughScripture"
      public init(service: String = service)
      static func account(for id: LLMProviderID) -> String   // "llm.anthropic"
  }
  public enum SecretStoreError: Error, Equatable { case keychain(OSStatus) }
  ```
  `KeychainStore` queries `kSecClassGenericPassword` with `kSecAttrService`, `kSecAttrAccount`, `kSecAttrSynchronizable: kSecAttrSynchronizableAny` on reads and deletes; writes add with `kSecAttrSynchronizable: true` and `kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock`, and on `errSecMissingEntitlement` retry without the synchronizable attribute. `setSecret` deletes any existing item (both variants) before adding. Trimming and the account name are tested through the in-memory store and the static helper; the Keychain itself is exercised in the app (Task 13).

- [x] **Step 1: Write the failing tests**

```swift
@Suite struct SecretStoreTests {
    @Test func keysAreTrimmedBeforeStorage() throws {
        let store = InMemorySecretStore()
        try store.setSecret("  sk-abc\n", for: .anthropic)
        #expect(try store.secret(for: .anthropic) == "sk-abc")
        #expect(try store.secret(for: .openAI) == nil)
    }
    @Test func emptyOrNilRemovesTheSecret() throws {
        let store = InMemorySecretStore()
        try store.setSecret("k", for: .openAI)
        try store.setSecret("   ", for: .openAI)
        #expect(try store.secret(for: .openAI) == nil)
        try store.setSecret("k", for: .openAI)
        try store.setSecret(nil, for: .openAI)
        #expect(try store.secret(for: .openAI) == nil)
    }
    @Test func keychainAccountsAreNamedPerProvider() {
        #expect(KeychainStore.account(for: .anthropic) == "llm.anthropic")
        #expect(KeychainStore.account(for: .openAICompatible) == "llm.openAICompatible")
        #expect(KeychainStore.service == "com.matthewfurr.ReadingThroughScripture")
    }
}
```

- [x] **Step 2: Run to verify failure** — `--filter SecretStoreTests`; expected compile failure.

- [x] **Step 3: Implement `SecretStore.swift`.** The trimming lives in a `SecretStore` protocol extension helper `static func normalized(_:) -> String?` both stores call.

- [x] **Step 4: Run the suite** — expected all pass.

- [x] **Step 5: Commit** — `feat: SecretStore with Keychain and in-memory implementations`

---

### Task 5: Built-in prompts and the `PromptBuilder`

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureLLM/BuiltInPrompts.swift`, `PromptBuilder.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureLLMTests/PromptBuilderTests.swift`

**Interfaces:**
- Produces:
  ```swift
  // In ScriptureModel (create `Sources/ScriptureModel/PromptTemplate.swift` holding only this enum; Task 8 adds the model beside it):
  public enum PromptScope: String, Codable, Sendable { case chapter, selection }
  // In ScriptureLLM:
  public struct PromptSeed: Equatable, Sendable {
      public let key: String        // stable identity: "overall-summary", "key-themes", ... "compare-translations"
      public let title: String
      public let body: String
      public let scope: PromptScope
  }
  public enum BuiltInPrompts {
      /// Eleven chapter prompts in the spec's order (Overall summary, Key themes, Cross-references,
      /// Catch me up, Outline, Context, People and places, Hard verses, Reflection questions,
      /// Word study, Memory verse), then three selection prompts (Explain this, Define words,
      /// Compare translations).
      public static let all: [PromptSeed]
      public static func seed(key: String) -> PromptSeed?
  }
  public struct PromptContext: Equatable, Sendable {
      public var reference: String            // "Matthew 5" or "Matthew 5:3-4"
      public var translation: String          // "ESV"
      public var chapterText: String          // "1 Seeing the crowds...\n2 And he opened..." (one verse per line, "12-13" for a combined verse, poetry lines kept)
      public var selection: String            // the quoted phrase, "" for chapter scope
      public var previousChapterText: String  // "" when there is none
      public var otherTranslations: String    // "KJV\n3 Blessed are...\n\nWEB\n3 ..." or ""
      public init(reference:translation:chapterText:selection:previousChapterText:otherTranslations:)
  }
  public enum PromptBuilder {
      public static let placeholders = ["reference", "chapter_text", "translation", "selection", "previous_chapter_text", "other_translations"]
      /// Replaces `{{name}}` for the six known placeholders; unknown ones are left as typed.
      public static func fill(_ body: String, with context: PromptContext) -> String
      /// The system instructions for every request: the role, the reference, translation and scope.
      public static func instructions(reference: String, translation: String, scope: ThreadScopeDescription) -> String
  }
  public enum ThreadScopeDescription: Equatable, Sendable { case selection(quoted: String), chapter, book }
  ```
  Instructions text, exactly: `"You are a careful study assistant helping one reader through the Bible. The reader is at <reference> in the <translation>. <scope sentence> Cite verses by reference. Say plainly when you are uncertain. Never invent references or quotations. Keep answers concise and in plain prose; use a numbered list only when the reader asks for an outline or a list."` where the scope sentence is `"They are asking about this passage: “<quoted>”."`, `"They are asking about this chapter."` or `"They are reading through this book and may move between chapters; each message names where they are."`.
  Every built-in chapter body starts with the chapter: e.g. Overall summary: `"Here is {{reference}} ({{translation}}):\n\n{{chapter_text}}\n\nGive an overall summary of this chapter in two or three short paragraphs: what happens or is argued, and why it matters in the book."`. Catch me up: `"I am about to read {{reference}} ({{translation}}). Here is the chapter before it:\n\n{{previous_chapter_text}}\n\nCatch me up in a few sentences on where the story or argument stands as this chapter opens. If no previous chapter is given, say this is the start of the book and set the scene from what the book is."`. Compare translations: `"Here is {{reference}} as I am reading it ({{translation}}):\n\n{{selection}}\n\nThe same verses in other translations:\n\n{{other_translations}}\n\nCompare the wording. Point out the differences that change the sense and say what lies behind them."`. The remaining bodies follow the same shape (reference, translation, chapter text, then one clear ask in a sentence or two).

- [x] **Step 1: Write the failing tests**

```swift
@Suite struct PromptBuilderTests {
    private let context = PromptContext(reference: "Matthew 5", translation: "ESV", chapterText: "1 Seeing the crowds\n2 And he opened", selection: "", previousChapterText: "", otherTranslations: "")

    @Test func placeholdersAreFilled() {
        #expect(PromptBuilder.fill("{{reference}} ({{translation}}):\n{{chapter_text}}", with: context) == "Matthew 5 (ESV):\n1 Seeing the crowds\n2 And he opened")
    }
    @Test func unknownPlaceholdersAreLeftAsTyped() {
        #expect(PromptBuilder.fill("Explain {{verse}} of {{reference}}", with: context) == "Explain {{verse}} of Matthew 5")
    }
    @Test func builtInPromptsCoverTheSpecInOrder() {
        #expect(BuiltInPrompts.all.map(\.title) == ["Overall summary", "Key themes", "Cross-references", "Catch me up", "Outline", "Context", "People and places", "Hard verses", "Reflection questions", "Word study", "Memory verse", "Explain this", "Define words", "Compare translations"])
        #expect(BuiltInPrompts.all.filter { $0.scope == .selection }.map(\.key) == ["explain-this", "define-words", "compare-translations"])
        #expect(Set(BuiltInPrompts.all.map(\.key)).count == 14)
        #expect(BuiltInPrompts.seed(key: "catch-me-up")?.body.contains("{{previous_chapter_text}}") == true)
        for seed in BuiltInPrompts.all where seed.scope == .chapter && seed.key != "catch-me-up" {
            #expect(seed.body.contains("{{chapter_text}}"), seed.key)
        }
        for seed in BuiltInPrompts.all where seed.scope == .selection {
            #expect(seed.body.contains("{{selection}}"), seed.key)
        }
    }
    @Test func instructionsNameThePlaceAndScope() {
        let text = PromptBuilder.instructions(reference: "Matthew 5:3", translation: "ESV", scope: .selection(quoted: "Blessed are the poor"))
        #expect(text.hasPrefix("You are a careful study assistant"))
        #expect(text.contains("Matthew 5:3 in the ESV") && text.contains("“Blessed are the poor”") && text.contains("Never invent references"))
        #expect(PromptBuilder.instructions(reference: "Matthew", translation: "KJV", scope: .book).contains("move between chapters"))
    }
}
```

- [x] **Step 2: Run to verify failure** — `--filter PromptBuilderTests`; expected compile failure.

- [x] **Step 3: Implement the two files.** `fill` replaces each known placeholder with `replacingOccurrences`; nothing else is interpreted.

- [x] **Step 4: Run the suite** — expected all pass.

- [x] **Step 5: Commit** — `feat: built-in study prompts and the PromptBuilder`

---

### Task 6: On-device fit and the Foundation Models provider

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureLLM/OnDeviceFit.swift`, `AppleFoundationProvider.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureLLMTests/OnDeviceFitTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum OnDeviceFit {
      public static let contextWindow = 4096
      public static let promptLimit = 3000        // instructions + prompt, estimated
      public static let replyBudget = 1000
      public static func fits(_ request: LLMRequest) -> Bool   // request.estimatedTokens <= promptLimit
      /// Drops the oldest exchanges (a user turn and the assistant turn after it) until the request
      /// fits, never dropping the last message; `maxExchanges` caps the history kept before that.
      public static func trim(_ request: LLMRequest, maxExchanges: Int? = nil) -> LLMRequest
      /// The prior turns flattened for a single prompt: "Reader: …\n\nAssistant: …\n\n" lines, then the
      /// last user message on its own; an empty history yields the last message alone.
      public static func flattenedPrompt(_ messages: [LLMMessage]) -> String
  }
  public struct AppleFoundationProvider: LLMProvider {
      public init()
      // id .appleOnDevice, modelName "apple-on-device", maxContextTokens 4096
      // availability: .available, or .unavailable(reason:) with one of
      //   "This Mac cannot run the on-device model."
      //   "Apple Intelligence is not enabled on this Mac. Turn it on in System Settings."
      //   "The on-device model is still downloading. Try again in a while."
      //   "The on-device model is not available on this system."  (framework missing or other)
      // stream: throws .unavailable(reason) when not available, .tooLong when !OnDeviceFit.fits(request);
      //   otherwise a fresh LanguageModelSession(instructions:) streams `streamResponse(to: flattenedPrompt,
      //   options: GenerationOptions(maximumResponseTokens: replyBudget))`; each snapshot's `content` is
      //   the accumulated text, so the provider yields the suffix beyond what it already sent.
      //   GenerationError.exceededContextWindowSize -> .tooLong; .guardrailViolation / .refusal -> .declined;
      //   .assetsUnavailable -> .unavailable; others -> .server(status: 0, message: localizedDescription).
  }
  ```
  The whole provider body is inside `#if canImport(FoundationModels)`; without the framework `availability` is the last reason above and `stream` throws it.

- [x] **Step 1: Write the failing tests**

```swift
@Suite struct OnDeviceFitTests {
    private func request(_ sizes: [Int], instructions: Int = 100) -> LLMRequest {
        LLMRequest(instructions: String(repeating: "i", count: instructions), messages: sizes.enumerated().map {
            LLMMessage(role: $0.offset.isMultiple(of: 2) ? .user : .assistant, content: String(repeating: "x", count: $0.element))
        }, maxTokens: OnDeviceFit.replyBudget)
    }
    @Test func fitIsJudgedAgainstThePromptLimit() {
        #expect(OnDeviceFit.fits(request([11_900])))          // 25 + 2975 = 3000
        #expect(!OnDeviceFit.fits(request([11_904])))         // 25 + 2976
    }
    @Test func trimDropsOldestExchangesFirstAndKeepsTheLastMessage() {
        let trimmed = OnDeviceFit.trim(request([4000, 4000, 4000, 4000, 2000]))
        #expect(trimmed.messages.map(\.content.count) == [4000, 4000, 2000])
        let tooBig = OnDeviceFit.trim(request([20_000]))
        #expect(tooBig.messages.count == 1 && !OnDeviceFit.fits(tooBig))
    }
    @Test func maxExchangesCapsTheHistory() {
        let trimmed = OnDeviceFit.trim(request([10, 10, 10, 10, 10, 10, 10]), maxExchanges: 1)
        #expect(trimmed.messages.map(\.content.count) == [10, 10, 10])
    }
    @Test func flattenedPromptLabelsTurns() {
        let messages = [LLMMessage(role: .user, content: "Who?"), LLMMessage(role: .assistant, content: "Matthew."), LLMMessage(role: .user, content: "When?")]
        #expect(OnDeviceFit.flattenedPrompt(messages) == "Reader: Who?\n\nAssistant: Matthew.\n\nReader: When?")
        #expect(OnDeviceFit.flattenedPrompt([messages[2]]) == "When?")
    }
    @Test func providerDescribesItself() {
        let provider = AppleFoundationProvider()
        #expect(provider.id == .appleOnDevice && provider.maxContextTokens == 4096)
        if case .unavailable(let reason) = provider.availability { #expect(!reason.isEmpty) }
    }
}
```

- [x] **Step 2: Run to verify failure** — `--filter OnDeviceFitTests`; expected compile failure.

- [x] **Step 3: Implement both files.** In `trim`, an "exchange" is `messages[0]` plus `messages[1]` when it is an assistant turn; the last message is never dropped.

- [x] **Step 4: Run the suite** — expected all pass. (`providerDescribesItself` passes whether or not Apple Intelligence is on.)

- [x] **Step 5: Commit** — `feat: on-device fit rules and the Foundation Models provider`

---

### Task 7: `LLMRouter`

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureLLM/LLMRouter.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureLLMTests/FakeProvider.swift`, `LLMRouterTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum RoutingPreference: String, CaseIterable, Sendable { case auto, appleOnDevice, anthropic, openAI, openAICompatible }
  public enum RoutingDecision: Sendable {
      case provider(any LLMProvider)
      case tooLongForOnDevice         // on-device is the only provider and the request does not fit
      case onDeviceUnavailable(String) // no cloud provider configured and on-device is unavailable
      case nothingConfigured          // no providers at all (framework missing, no keys)
  }
  public struct LLMRouter: Sendable {
      /// `providers` are the configured ones: on-device (always, when the framework exists) and each
      /// cloud provider that has a key, in the order Anthropic, OpenAI, compatible.
      public init(providers: [any LLMProvider])
      public func route(_ request: LLMRequest, preference: RoutingPreference) -> RoutingDecision
  }
  ```
  Rules (Ruling 8): a cloud preference whose provider is present wins. Otherwise (auto, on-device chosen, or a chosen cloud provider missing): on-device when present, `.available`, and `OnDeviceFit.fits(request)`; else the first cloud provider; else `.tooLongForOnDevice` when on-device is present and available but the request does not fit; else `.onDeviceUnavailable(reason)` when on-device is present; else `.nothingConfigured`.
  `FakeProvider` (test helper, also used by Task 9): `final class FakeProvider: LLMProvider, @unchecked Sendable` with `id`, `modelName`, `maxContextTokens`, `availability`, a `deltas: [String]`, an optional `failure: LLMProviderError` thrown after the deltas, a `delayPerDelta: Duration`, and `private(set) var requests: [LLMRequest]` recorded under a lock.

- [x] **Step 1: Write the failing tests**

```swift
@Suite struct LLMRouterTests {
    private let small = LLMRequest(instructions: "i", messages: [LLMMessage(role: .user, content: "q")], maxTokens: 100)
    private let large = LLMRequest(instructions: "i", messages: [LLMMessage(role: .user, content: String(repeating: "x", count: 20_000))], maxTokens: 100)
    private let onDevice = FakeProvider(id: .appleOnDevice, modelName: "apple", maxContextTokens: 4096)
    private let offline = FakeProvider(id: .appleOnDevice, modelName: "apple", maxContextTokens: 4096, availability: .unavailable(reason: "Apple Intelligence is not enabled on this Mac."))
    private let claude = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5")
    private let openAI = FakeProvider(id: .openAI, modelName: "gpt-5")

    private func id(_ decision: RoutingDecision) -> LLMProviderID? { if case .provider(let p) = decision { return p.id } else { return nil } }

    @Test func autoPrefersOnDeviceWhenItFits() {
        let router = LLMRouter(providers: [onDevice, claude, openAI])
        #expect(id(router.route(small, preference: .auto)) == .appleOnDevice)
        #expect(id(router.route(large, preference: .auto)) == .anthropic)
    }
    @Test func aChosenCloudProviderWins() {
        let router = LLMRouter(providers: [onDevice, claude, openAI])
        #expect(id(router.route(small, preference: .openAI)) == .openAI)
        #expect(id(router.route(small, preference: .anthropic)) == .anthropic)
    }
    @Test func aMissingChoiceFallsBackToAuto() {
        let router = LLMRouter(providers: [onDevice, openAI])
        #expect(id(router.route(small, preference: .anthropic)) == .appleOnDevice)
        #expect(id(router.route(large, preference: .appleOnDevice)) == .openAI)
    }
    @Test func tooLongWithoutACloudKeyIsReported() {
        let router = LLMRouter(providers: [onDevice])
        if case .tooLongForOnDevice = router.route(large, preference: .auto) {} else { Issue.record("expected tooLongForOnDevice") }
    }
    @Test func unavailableOnDeviceFallsToCloudOrReports() {
        #expect(id(LLMRouter(providers: [offline, claude]).route(small, preference: .auto)) == .anthropic)
        if case .onDeviceUnavailable(let reason) = LLMRouter(providers: [offline]).route(small, preference: .auto) {
            #expect(reason == "Apple Intelligence is not enabled on this Mac.")
        } else { Issue.record("expected onDeviceUnavailable") }
        if case .nothingConfigured = LLMRouter(providers: []).route(small, preference: .auto) {} else { Issue.record("expected nothingConfigured") }
    }
}
```

- [x] **Step 2: Run to verify failure** — `--filter LLMRouterTests`; expected compile failure.

- [x] **Step 3: Implement `LLMRouter` and `FakeProvider`.**

- [x] **Step 4: Run the suite** — expected all pass.

- [x] **Step 5: Commit** — `feat: LLMRouter picks on-device, a chosen cloud provider, or reports why not`

---

### Task 8: Threads, messages and templates in `ScriptureModel`

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureModel/ChatThread.swift`, `ChatMessage.swift`, `PromptTemplate.swift`, `ChatStore.swift`, `PromptTemplateStore.swift`
- Modify: `Note.swift` (`sourceThreadID`), `MarkupContainer.swift` (schema), `MarkupSnapshot.swift` (`MarkupDeletion.thread`), `MarkupStore.swift` (`delete`/`restore` for threads; `addNote(to:body:sourceThreadID:)`, `addChapterNote`, `appendToNote`)
- Test: `Tests/ScriptureModelTests/ChatStoreTests.swift`, `PromptTemplateStoreTests.swift`, additions to `MarkupStoreTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum ThreadScope: String, Codable, Sendable { case selection, chapter, book }
  @Model public final class ChatThread {
      public var uuid: UUID = UUID(); public var scopeRaw: String = ThreadScope.chapter.rawValue
      public var book: String = ""; public var chapter: Int = 0        // chapter 0 for book scope
      public var verse: Int = 0; public var endVerse: Int = 0; public var startOffset: Int = 0; public var endOffset: Int = 0   // selection scope only
      public var translationID: String = ""; public var quotedText: String = ""; public var title: String = ""
      public var createdAt: Date = Date(); public var updatedAt: Date = Date()
      @Relationship(deleteRule: .cascade, inverse: \ChatMessage.thread) public var messages: [ChatMessage]? = []
      public var scope: ThreadScope { get set }; public var chapterLocation: ChapterLocation
      public var orderedMessages: [ChatMessage]   // by createdAt
  }
  public enum ChatRole: String, Codable, Sendable { case user, assistant }
  @Model public final class ChatMessage {
      public var uuid: UUID = UUID(); public var roleRaw: String = ChatRole.user.rawValue; public var content: String = ""
      public var createdAt: Date = Date(); public var providerID: String = ""; public var modelName: String = ""
      /// Set on a user turn sent from a chapter other than the one before it (book threads): "Matthew 6".
      public var attachedReference: String?
      public var thread: ChatThread?
      public var role: ChatRole { get set }
  }
  @Model public final class PromptTemplate {
      public var uuid: UUID = UUID(); public var title: String = ""; public var body: String = ""
      public var scopeRaw: String = "chapter"; public var isEnabled: Bool = true; public var sortOrder: Int = 0
      public var isBuiltIn: Bool = false; public var builtInKey: String?; public var outputKind: String = "text"
      public var scope: PromptScope  // the enum Task 5 declared in this file
  }
  // Note.swift
  public var sourceThreadID: UUID?
  // ChatStore.swift
  @MainActor public final class ChatStore {
      public init(container: ModelContainer)
      public func threads(in chapter: ChapterLocation) throws -> [ChatThread]   // selection + chapter threads of the chapter, plus book threads of the book; newest updatedAt first
      public func allThreads() throws -> [ChatThread]
      public func thread(id: UUID) throws -> ChatThread?
      @discardableResult public func createThread(scope: ThreadScope, book: String, chapter: Int, verse: Int, endVerse: Int, startOffset: Int, endOffset: Int, translationID: String, quotedText: String, title: String) throws -> ChatThread
      @discardableResult public func append(to thread: ChatThread, role: ChatRole, content: String, providerID: String, modelName: String, attachedReference: String?) throws -> ChatMessage   // bumps updatedAt
      public func updateContent(of message: ChatMessage, _ content: String) throws
      public func delete(_ message: ChatMessage) throws
      public func deleteThread(_ thread: ChatThread) throws
      public func restore(_ snapshot: ThreadSnapshot) throws   // no-op when the uuid exists
  }
  public struct ThreadSnapshot: Equatable, Sendable { /* every field of the thread and its messages by value */ public init(_ thread: ChatThread) }
  // MarkupSnapshot.swift
  case thread(ThreadSnapshot)   // actionName "Delete Conversation"
  // MarkupStore.swift
  public func addNote(to highlight: Highlight, body: String, sourceThreadID: UUID?) throws -> Note   // existing addNote(to:body:) calls it with nil
  @discardableResult public func addChapterNote(book: String, chapter: Int, translationID: String, body: String, sourceThreadID: UUID?) throws -> Note   // scope .chapter, verse 0, endVerse 0, quotedText ""
  public func appendToNote(_ note: Note, _ addition: String) throws   // body + "\n\n" + addition (just addition when the body is blank); modifiedAt now
  // MarkupStore.delete/restore gain the `.thread` case through a `ChatStore` on the same container (MarkupStore owns one: `public let chat: ChatStore`).
  // PromptTemplateStore.swift
  @MainActor public final class PromptTemplateStore {
      public init(container: ModelContainer)
      /// Inserts every seed whose key is absent; existing records are never changed. Returns how many were added.
      @discardableResult public func seedIfNeeded(_ seeds: [PromptSeed]) throws -> Int
      public func templates(scope: PromptScope? = nil) throws -> [PromptTemplate]   // by sortOrder
      public func template(id: UUID) throws -> PromptTemplate?
      @discardableResult public func add(title: String, body: String, scope: PromptScope) throws -> PromptTemplate   // appended, enabled, not built-in
      public func update(_ template: PromptTemplate, title: String, body: String) throws
      public func setEnabled(_ template: PromptTemplate, _ enabled: Bool) throws
      public func move(scope: PromptScope, fromOffsets: IndexSet, toOffset: Int) throws   // MarkupStore.moving semantics within the scope
      public func delete(_ template: PromptTemplate) throws
      /// Resets a built-in's title and body to its seed; a deleted built-in is re-created at the end.
      public func restoreBuiltIn(key: String, from seeds: [PromptSeed]) throws
  }
  ```
  `MarkupContainer.make` schema: `[Highlight, Note, Bookmark, HighlightColor, ChatThread, ChatMessage, PromptTemplate]`.

- [x] **Step 1: Write the failing tests**

```swift
@MainActor @Suite struct ChatStoreTests {
    private func make() throws -> ChatStore {
        ChatStore(container: try MarkupContainer.make(inMemory: true))
    }
    @Test func threadsInAChapterIncludeTheBooksThreadsNewestFirst() throws {
        let store = try make()
        let chapter = try store.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "Key themes: Matthew 5")
        let book = try store.createThread(scope: .book, book: "MAT", chapter: 0, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "Matthew")
        _ = try store.createThread(scope: .chapter, book: "MAT", chapter: 6, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "Outline: Matthew 6")
        let selection = try store.createThread(scope: .selection, book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", quotedText: "Blessed", title: "Matthew 5:3")
        chapter.updatedAt = Date(timeIntervalSince1970: 100); book.updatedAt = Date(timeIntervalSince1970: 300); selection.updatedAt = Date(timeIntervalSince1970: 200)
        try store.context.save()
        #expect(try store.threads(in: ChapterLocation(book: "MAT", chapter: 5)).map(\.title) == ["Matthew", "Matthew 5:3", "Key themes: Matthew 5"])
        #expect(try store.allThreads().count == 4)
    }
    @Test func appendingKeepsOrderAndBumpsUpdatedAt() throws {
        let store = try make()
        let thread = try store.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "t")
        thread.updatedAt = .distantPast
        let q = try store.append(to: thread, role: .user, content: "Who?", providerID: "", modelName: "", attachedReference: nil)
        let a = try store.append(to: thread, role: .assistant, content: "Matt", providerID: "anthropic", modelName: "claude-opus-5-5", attachedReference: nil)
        try store.updateContent(of: a, "Matthew.")
        #expect(thread.orderedMessages.map(\.content) == ["Who?", "Matthew."])
        #expect(thread.orderedMessages.map(\.role) == [.user, .assistant])
        #expect(thread.updatedAt > Date(timeIntervalSinceNow: -5))
        try store.delete(q)
        #expect(thread.orderedMessages.map(\.uuid) == [a.uuid])
    }
    @Test func aDeletedThreadIsRestoredWithItsMessages() throws {
        let store = try make()
        let thread = try store.createThread(scope: .selection, book: "MAT", chapter: 5, verse: 3, endVerse: 4, startOffset: 2, endOffset: 9, translationID: "KJV", quotedText: "poor", title: "Matthew 5:3-4")
        try store.append(to: thread, role: .user, content: "q", providerID: "", modelName: "", attachedReference: "Matthew 6")
        let snapshot = ThreadSnapshot(thread)
        try store.deleteThread(thread)
        #expect(try store.allThreads().isEmpty)
        try store.restore(snapshot)
        let back = try store.thread(id: snapshot.uuid)
        #expect(back?.title == "Matthew 5:3-4" && back?.endOffset == 9 && back?.translationID == "KJV")
        #expect(back?.orderedMessages.map(\.attachedReference) == ["Matthew 6"])
        try store.restore(snapshot)
        #expect(try store.allThreads().count == 1)
    }
}

@MainActor @Suite struct PromptTemplateStoreTests {
    private let seeds = [
        PromptSeed(key: "a", title: "A", body: "{{chapter_text}} a", scope: .chapter),
        PromptSeed(key: "b", title: "B", body: "b", scope: .chapter),
        PromptSeed(key: "s", title: "S", body: "{{selection}}", scope: .selection),
    ]
    private func make() throws -> PromptTemplateStore {
        let store = PromptTemplateStore(container: try MarkupContainer.make(inMemory: true))
        try store.seedIfNeeded(seeds)
        return store
    }
    @Test func seedingIsIdempotentAndOrdered() throws {
        let store = try make()
        #expect(try store.seedIfNeeded(seeds) == 0)
        #expect(try store.templates().map(\.title) == ["A", "B", "S"])
        #expect(try store.templates(scope: .selection).map(\.builtInKey) == ["s"])
        #expect(try store.templates().allSatisfy { $0.isBuiltIn && $0.isEnabled })
    }
    @Test func templatesCanBeEditedReorderedDisabledAddedAndDeleted() throws {
        let store = try make()
        let a = try store.templates()[0]
        try store.update(a, title: "A2", body: "changed")
        try store.setEnabled(a, false)
        let mine = try store.add(title: "Mine", body: "m", scope: .chapter)
        #expect(mine.isBuiltIn == false && mine.sortOrder == 3)
        try store.move(scope: .chapter, fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(try store.templates(scope: .chapter).map(\.title) == ["Mine", "A2", "B"])
        try store.delete(try store.templates(scope: .chapter)[2])
        #expect(try store.templates(scope: .chapter).map(\.title) == ["Mine", "A2"])
        #expect(try store.templates(scope: .chapter)[1].isEnabled == false)
    }
    @Test func builtInsCanBeRestoredEvenAfterDeletion() throws {
        let store = try make()
        let a = try store.templates()[0]
        try store.update(a, title: "A2", body: "changed")
        try store.restoreBuiltIn(key: "a", from: seeds)
        #expect(a.title == "A" && a.body == "{{chapter_text}} a")
        try store.delete(try store.templates()[1])   // B
        try store.restoreBuiltIn(key: "b", from: seeds)
        #expect(try store.templates().map(\.title) == ["A", "S", "B"])
    }
}
```

Additions to `MarkupStoreTests`:

```swift
@Test func chapterNotesAndAppendsCarryTheThread() throws {
    let store = try makeStore()
    let thread = UUID()
    let note = try store.addChapterNote(book: "MAT", chapter: 5, translationID: "ESV", body: "**Q:** why?\n\nBecause.", sourceThreadID: thread)
    #expect(note.scope == .chapter && note.verse == 0 && note.sourceThreadID == thread && note.quotedText == "")
    #expect(try store.notes(in: matthew5).map(\.uuid) == [note.uuid])
    let highlight = try add(store, verse: 3)
    let existing = try store.addNote(to: highlight, body: "mine", sourceThreadID: nil)
    try store.appendToNote(existing, "**Q:** q\n\na")
    #expect(existing.body == "mine\n\n**Q:** q\n\na")
    let blank = try store.addNote(to: try add(store, verse: 4), body: "  ", sourceThreadID: nil)
    try store.appendToNote(blank, "x")
    #expect(blank.body == "x")
}
@Test func threadDeletionIsUndoableThroughTheMarkupStore() throws {
    let store = try makeStore()
    let thread = try store.chat.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "t")
    let captured = try store.delete(.thread(ThreadSnapshot(thread)))
    #expect(try store.chat.allThreads().isEmpty)
    #expect(captured?.actionName == "Delete Conversation")
    try store.restore(captured!)
    #expect(try store.chat.allThreads().map(\.title) == ["t"])
}
```

- [x] **Step 2: Run to verify failure** — `--filter "ChatStoreTests|PromptTemplateStoreTests|MarkupStoreTests"`; expected compile failure.

- [x] **Step 3: Implement** the models, the schema line, `ChatStore`, `PromptTemplateStore`, the `MarkupStore` additions and the `.thread` case.

- [x] **Step 4: Run the suite** — expected all pass.

- [x] **Step 5: Commit** — `feat: chat threads, messages and prompt templates in ScriptureModel`

---

### Task 9: `StudyPromptComposer`, assistant items and `AssistantModel`

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/StudyPromptComposer.swift`, `AssistantItems.swift`, `AssistantSettings.swift` (the keys and `preference(from:)` only; Task 11 adds the rest), `AssistantModel.swift`
- Test: `Tests/ScriptureUITests/StudyPromptComposerTests.swift`, `AssistantModelTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct StudyPromptComposer: Sendable {
      public init(store: BibleStore)
      /// "1 text\n2 text" with "12-13" for a combined verse; poetry newlines kept.
      public static func chapterText(_ verses: [Verse]) -> String
      /// The verses in `verses...endVerse` of every other bundled translation, at most `limit`, as
      /// "KJV\n3 …\n\nWEB\n3 …"; "" when none.
      public func otherTranslations(for location: ChapterLocation, verse: Int, endVerse: Int, excluding translationID: String, limit: Int?) throws -> String
      /// The chapter before `location` in `translationID`, or nil at the start of the book (the previous book is not crossed).
      public func previousChapter(of location: ChapterLocation, translationID: String) throws -> [Verse]?
      /// Verse lines for the first and last five verses with a "…" line between, or the whole text when ten or fewer.
      public static func abridged(_ verses: [Verse]) -> String
  }
  public struct ChatThreadItem: Identifiable, Equatable, Sendable { id, scope: ThreadScope, title, referenceString, location: ChapterLocation, verse, endVerse, startOffset, endOffset, translationID, quotedText, updatedAt, lastLine: String }
  public struct ChatMessageItem: Identifiable, Equatable, Sendable { id, role: ChatRole, content, providerLabel: String?, attachedReference: String?, isStreaming: Bool }
  public struct PromptTemplateItem: Identifiable, Equatable, Sendable { id, title, scope: PromptScope, isEnabled }
  public enum AssistantNotice: Equatable, Sendable {
      case tooLongForOnDevice, onDeviceUnavailable(String), nothingConfigured, unauthorized, rateLimited, unreachable, declined, failed
      public var message: String           // the sentences of Ruling 9
      public var offersSettings: Bool      // true for the first four
  }
  public enum ProviderLabel {
      public static func text(providerID: String, modelName: String, baseURL: URL?) -> String   // Ruling 7
  }
  public enum AssistantSettings {
      public static let providerKey = "assistantProvider"
      public static func preference(from defaults: UserDefaults) -> RoutingPreference   // raw value, "auto" when missing or unknown
  }
  @MainActor @Observable public final class AssistantModel {
      public private(set) var isPanelShown = false
      public private(set) var thread: ChatThreadItem?
      public private(set) var messages: [ChatMessageItem] = []
      public private(set) var history: [ChatThreadItem] = []
      public private(set) var isResponding = false
      public private(set) var notice: AssistantNotice?
      public var draft = ""
      public private(set) var composerPlaceholder: String                   // "Ask about Matthew 5"
      /// What the current chapter is; `MainWindowView` calls it as it calls `MarkupModel.load`.
      public func setLocation(_ chapter: ChapterLocation?, translationID: String, verses: [Verse])
      public func reloadTemplates()
      public private(set) var pendingScope: ThreadScope?                   // the scope of a conversation not yet started (Ruling 1); nil while asking "Include where you are?" or when a thread is open
      public private(set) var isAskingForContext: Bool                      // Ruling 1 (c)
      public var prompts: [PromptTemplateItem]                              // the list above the composer: selection or chapter templates for the pending or open scope; empty for book and general
      public func ask(about report: SelectionReport)            // Ruling 1 (a): pendingScope .selection, panel shown, nothing sent
      public func askAboutChapter()                             // Ruling 1 (b): pendingScope .chapter
      public func openAskingForContext(selection: SelectionReport?)   // Ruling 1 (c): with a selection behaves as ask(about:), else isAskingForContext = true
      public func chooseContext(_ scope: ThreadScope)           // .chapter, .book or .general from the three buttons or the plus menu
      public func runPrompt(_ templateID: UUID)                 // fills the template for the pending or open scope and sends it
      public func open(threadID: UUID)                          // from history or the browser; shows the panel
      public func send()                                        // the draft, trimmed; empty is ignored; creates the thread on the first send
      public func stop()
      public func copyText(messageID: UUID) -> String?
      public func addAsNote(messageID: UUID)                    // Ruling 6; then onMarkupChange() and onNoteSaved(noteID)
      public var onNoteSaved: ((UUID) -> Void)?                 // the app hides the panel and opens the note in the column's editor
      public func deleteThread(id: UUID)                        // undoable through undoManager
      public func showPanel(); public func hidePanel(); public func togglePanel()
      public var undoManager: UndoManager?
      public init(markup: MarkupStore, templates: PromptTemplateStore, bible: BibleStore, secrets: any SecretStore,
                  defaults: UserDefaults = .standard, providerFactory: @escaping @MainActor () -> [any LLMProvider],
                  onMarkupChange: @escaping () -> Void = {})
      // Threads of scope .general send instructions without the reference (Ruling 2).
  }
  ```
  Behaviour pinned by the tests: `send()` appends the user turn (with `attachedReference` when a book thread's location moved), builds the `LLMRequest` through `PromptBuilder` and the composer (the first message of a chapter or book thread is the filled template, or for a typed first question `"Here is <reference> (<translation>):\n\n<chapter text>\n\n<question>"`; later turns are the question alone), routes it with the stored preference, streams deltas into a trailing `isStreaming` assistant message, and on `.done` persists it through `ChatStore.append`. A failure after deltas keeps the text received (persisted) and sets `notice`. A `RoutingDecision` other than `.provider` sets the matching notice and removes nothing. The composer prompt and the Compare translations limit depend on which provider will answer: the model builds the context with `limit: 3` when the router would pick on-device, else `nil`. Cancellation through `stop()` keeps the partial text as in Ruling 11.

- [x] **Step 1: Write the failing tests**

```swift
@MainActor @Suite struct StudyPromptComposerTests {
    @Test func chapterTextNumbersVersesAndKeepsPoetry() throws {
        let store = try FixtureStore.make()
        let verses = try store.chapter(ChapterLocation(book: "MAT", chapter: 5), translationID: "WEB")
        let text = StudyPromptComposer.chapterText(verses)
        #expect(text.hasPrefix("1 ") && text.contains("\n2 ") && text.components(separatedBy: "\n").count >= verses.count)
    }
    @Test func abridgedKeepsFirstAndLastFive() throws {
        let verses = (1...12).map { Verse(id: VerseLocation(book: "PSA", chapter: 119, verse: $0), translationID: "KJV", text: "v\($0)", breakAfter: false) }
        let lines = StudyPromptComposer.abridged(verses).components(separatedBy: "\n")
        #expect(lines == ["1 v1", "2 v2", "3 v3", "4 v4", "5 v5", "…", "8 v8", "9 v9", "10 v10", "11 v11", "12 v12"])
        #expect(StudyPromptComposer.abridged(Array(verses.prefix(10))).components(separatedBy: "\n").count == 10)
    }
    @Test func otherTranslationsListTheSameVersesUpToTheLimit() throws {
        let composer = StudyPromptComposer(store: try FixtureStore.make())
        let text = try composer.otherTranslations(for: ChapterLocation(book: "MAT", chapter: 5), verse: 3, endVerse: 4, excluding: "WEB", limit: nil)
        #expect(text.hasPrefix("KJV\n3 ") && text.contains("\n4 ") && !text.contains("WEB"))
        #expect(try composer.otherTranslations(for: ChapterLocation(book: "MAT", chapter: 5), verse: 3, endVerse: 3, excluding: "WEB", limit: 0) == "")
    }
    @Test func catchMeUpOnTheFirstChapterHasNoPreviousText() throws {
        let composer = StudyPromptComposer(store: try FixtureStore.make())
        #expect(try composer.previousChapter(of: ChapterLocation(book: "MAT", chapter: 1), translationID: "WEB") == nil)
        #expect(try composer.previousChapter(of: ChapterLocation(book: "MAT", chapter: 5), translationID: "WEB")?.first?.id.chapter == 4)
    }
}
```

`AssistantModelTests` (each test builds an in-memory container, `FixtureStore`, `InMemorySecretStore`, a fresh `UserDefaults` suite, a `FakeProvider` list, and calls `setLocation(MAT 5, "WEB", verses)`; `await` the response by polling `isResponding` with `Task.sleep` up to two seconds in a helper `settle()`):

```swift
@Test func askingAboutASelectionShowsThePromptsWithoutAThread() // ask(about:) -> isPanelShown, pendingScope == .selection, thread == nil, prompts.map(\.title) == ["Explain this", "Define words", "Compare translations"], composerPlaceholder == "Ask about Matthew 5:3", store.chat.allThreads().isEmpty
@Test func askingAboutTheChapterListsTheChapterPrompts() // askAboutChapter() -> pendingScope == .chapter, prompts.count == 11, composerPlaceholder == "Ask about Matthew 5"
@Test func openingByShortcutAsksForContextFirst() // openAskingForContext(selection: nil) -> isAskingForContext, prompts empty; chooseContext(.general) -> pendingScope == .general, composerPlaceholder == "Ask anything"; send "q" -> the provider's request.instructions does not contain "Matthew"; the thread is filed under MAT 5 (history contains it)
@Test func sendingCreatesTheThreadStreamsAReplyAndPersistsIt() // FakeProvider(.appleOnDevice, deltas ["Bles", "sed."]); ask; draft "Why?"; send(); settle(); thread?.scope == .selection and thread?.referenceString == "Matthew 5:3"; messages == [user "Why?", assistant "Blessed." providerLabel "On-device"]; store.chat.allThreads()[0].orderedMessages.count == 2; the FakeProvider's request.instructions contains "Matthew 5:3 in the WEB" and its last message content == "Why?"
@Test func aChapterPromptFillsTheTemplateAndTitlesTheThread() // askAboutChapter(); runPrompt(overall summary id); settle(); thread?.title == "Overall summary: Matthew 5"; messages[0].content.hasPrefix("Here is Matthew 5 (WEB):\n\n1 "); thread?.scope == .chapter; prompts is empty once the thread exists
@Test func catchMeUpAbridgesThePreviousChapterWhenOnDeviceCannotFit() // on-device provider only; location PSA 119? (fixture has Psalm 119 KJV): setLocation(PSA 119, "KJV"); askAboutChapter(); runPrompt(catch me up); settle(); the request's last message contains "…" line and does not contain "118 " more than 10 verse lines; and with a large FakeProvider(.anthropic) also configured, the request goes to anthropic with the full previous chapter (no "…")
@Test func tooLongForOnDeviceShowsTheNotice() // only on-device; setLocation(PSA 119 KJV); askAboutChapter(); runPrompt(overall summary); notice == .tooLongForOnDevice; messages empty; isResponding false; store has one thread with zero messages? -> no: the thread is created only when a request is routed; expect allThreads().isEmpty
@Test func aFailureAfterDeltasKeepsThePartialReply() // FakeProvider deltas ["Half"], failure .transport("x"); send; settle; messages.last?.content == "Half", notice == .unreachable, persisted content "Half"
@Test func stopKeepsWhatArrived() // FakeProvider deltas ["A","B","C"] with delayPerDelta 300ms; send; sleep 400ms; stop(); messages.last?.content == "A" (or "AB"), isResponding false, notice nil
@Test func addAsNoteOnASelectionThreadAnchorsTheReply() // after a reply on a selection thread: addAsNote(messageID); markup.highlights(in:) has one colorless highlight on 5:3 with note body "**Q:** Why?\n\nBlessed." and sourceThreadID == thread.id; onMarkupChange called once; onNoteSaved received that note's uuid
@Test func addAsNoteInsideAnExistingNoteAppends() // highlight with note "mine" at 5:3 offsets 0..7; ask(about: report inside it, primaryHighlightID set); reply; addAsNote; note.body == "mine\n\n**Q:** Why?\n\nBlessed."
@Test func addAsNoteOnAChapterThreadMakesAChapterNote() // askAboutChapter(); runPrompt(...); addAsNote; markup.notes(in:) has one scope .chapter note starting "**Q:** Overall summary\n\n" (the question line is the template title for template runs, the typed question otherwise)
@Test func bookThreadsAttachTheNewReferenceWhenTheReaderMoves() // openAskingForContext(selection: nil); chooseContext(.book); send "q1"; setLocation(MAT 6); send "q2"; the second user message's attachedReference == "Matthew 6" and the provider's last request content hasPrefix "Now at Matthew 6 (WEB):\n\n1 "; history at MAT 6 contains the book thread
@Test func openingAThreadInAnUnbundledTranslationKeepsTheCurrentOne() // create a thread with translationID "ESV" (not bundled in the fixture) directly in ChatStore; open(threadID:); thread?.translationID == "ESV"; isPanelShown; messages loaded; (navigation is MainWindowView's job: the model exposes `thread`, and `MarkupTarget`-style opening via NavigationModel.open(location, verse:, translationID:) ignores an unbundled id, which Task 4 of milestone 4 pinned)
@Test func deletingAThreadIsUndoable() // undoManager = UndoManager(); open a thread; deleteThread(id); history empty, thread nil, panel still shown; undoManager.undo(); history.count == 1
@Test func preferenceAndNoticesFollowTheRouter() // providers [offline on-device] -> send -> notice == .onDeviceUnavailable("…"); providers [] -> .nothingConfigured; FakeProvider(.anthropic, failure: .unauthorized) with preference anthropic -> .unauthorized
```

- [x] **Step 2: Run to verify failure** — `--filter "StudyPromptComposerTests|AssistantModelTests"`; expected compile failure.

- [x] **Step 3: Implement the three files.** `AssistantModel` keeps the SwiftData objects private and exposes value copies, like `MarkupModel`. The streaming task is stored so `stop()` can cancel it; every mutation of `messages` happens on the main actor. The chapter-note question line for a template run is the template's title. Logging under `Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "assistant")`.

- [x] **Step 4: Run the suite** — expected all pass.

- [x] **Step 5: Commit** — `feat: AssistantModel composes, routes, streams and saves study conversations`

---

### Task 10: The chat panel, the inspector swap, the heading menu and the context menu

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ChatPanelView.swift`, `ChatTurnRow.swift`, `AssistantComposer.swift`, `InspectorContentView.swift`
- Modify: `ReaderView.swift` (heading), `MarkupContextMenu.swift`, `MarkupModel.swift` (`onAskAboutPassage`), `NotesColumnItem.swift` (doc comment), `Apps/Mac/ReadingThroughScripture/MainWindowView.swift`, `ReadingThroughScriptureApp.swift`, `DESIGN.md` (symbol inventory)
- Test: none beyond the existing suites (views are verified in the app, Task 13); `ReaderView`'s new parameters default so milestone-2 call sites compile.

**Interfaces:**
- Produces:
  ```swift
  public struct ChatPanelView: View { public init(model: AssistantModel, onOpenSettings: @escaping () -> Void) }
  struct ChatTurnRow: View { let message: ChatMessageItem; let onCopy: () -> Void; let onAddAsNote: () -> Void }
  struct AssistantComposer: View { @Binding var draft: String; let placeholder: String; let isResponding: Bool; let onSend: () -> Void; let onStop: () -> Void }
  // The heading stays plain text in Display style; a plain click calls `onHeadingTap` (the app's goHome, which lands on this book's chapter grid), and `.contextMenu` offers "Ask About This Chapter" (`onAskAboutChapter`). `ChapterHeadingMenu.swift` is not created.
  public struct InspectorContentView: View { public init(markup: MarkupModel, assistant: AssistantModel, onOpenSettings: @escaping () -> Void) }   // ChatPanelView when assistant.isPanelShown else NotesColumnView; .transition(.opacity) with .snappy(duration: 0.15), a cut under Reduce Motion
  // ReaderView.init gains `onAskAboutChapter: (() -> Void)? = nil`; with it set the heading has a context menu with one item, "Ask About This Chapter" (`sparkles`). `onHeadingTap` is now called on a plain click.
  // MarkupModel gains `public var onAskAboutPassage: ((SelectionReport) -> Void)?`; MarkupContextMenu's item is enabled when it is set and calls it after `controller.collapseSelection()`.
  ```
  The panel follows the design brief: header (sparkles in `Color.assistant`, "Assistant" `.headline`, the scope as `.caption.weight(.semibold)` `ink.secondary`, Spacer, `plus` Menu with "About <chapter title>", "About <book name>" and "No context", `clock` Menu listing `history` titles with their dates (or a disabled "No conversations here yet"), `xmark` "Show Notes"), `Color.inkRule.frame(height: 1)`, the transcript in a `ScrollView` with `ScrollViewReader` scrolling to the last message's id on change, `Color.inkRule.frame(height: 1)`, then above the composer one of: the prompt list (`ForEach(model.prompts)` as `.plain` buttons, `text.quote` glyph + title in `.callout`, `AppSpacing.xs` vertical padding, until the first message is sent), the context line (`Text("Include where you are?")` `.callout` `ink.secondary` and three `.bordered` `.controlSize(.small)` buttons titled with the chapter title, the book name and "No context") when `isAskingForContext`, or the notice (the sentence in `.callout` `ink.secondary` and an "Open Settings" `.bordered` button when `offersSettings`); then `AssistantComposer`. A reader turn: the bubble of the brief (`paper.overlay`, `AppRadius.lg`, trailing, `frame(maxWidth:)` four fifths via `GeometryReader`-free `.containerRelativeFrame` or a fixed fraction of the inspector width), `attachedReference` as a Label above when set, `.textSelection(.enabled)`. An assistant turn: `NoteMarkdown.blocks` rendered `.callout` `ink.primary` with `AppSpacing.xs` between blocks on `Color.assistantWash` at `AppRadius.lg`, padded `AppSpacing.sm` vertical and `AppSpacing.md` horizontal (`@ScaledMetric`), footer row with the provider label in `Color.assistant` `.caption`, a `ProgressView().controlSize(.small)` plus "Answering" while `isStreaming` and the content is empty, Spacer, `RowSymbolButton("Copy", "doc.on.doc")` and `RowSymbolButton("Add as Note", "note.text.badge.plus")` (hidden while streaming). The composer: `TextField(placeholder, text: $draft, axis: .vertical)` `.lineLimit(1...5)` `.textFieldStyle(.plain)` on `paper.overlay` with the `ink.rule` stroke at `AppRadius.md` (the editor style), `.onSubmit(onSend)`, Shift-Return inserts a newline (`onKeyPress(.return, phases: .down)` checking `.shift`), and a trailing `RowSymbolButton` that is "Send" `arrow.up.circle.fill` tinted `Color.accent` or "Stop" `stop.circle` while responding. Escape in the panel calls `hidePanel()`.
  App wiring: `MainWindowView` passes `onHeadingTap: { model.goHome() }` and `onAskAboutChapter: { assistant.askAboutChapter() }`, sets `markup.onAskAboutPassage = { assistant.ask(about: $0) }` and `assistant.onNoteSaved = { noteID in assistant.hidePanel(); markup.beginEditing(noteID: noteID); if let h = markup.highlightID(forNote: noteID) { markup.focus(highlightID: h) } }` in `onAppear`, calls `assistant.setLocation(key.location, translationID:, verses:)` in the same `onChange(of: chapterKey)` that loads markup, replaces the inspector content with `InspectorContentView`, and when `assistant.isPanelShown` becomes true sets `showNotesColumn = true`. The toolbar gains a `sparkles` "Assistant" button after Notes Column (`assistant.openAskingForContext(selection: markup.currentSelection)`, where `MarkupModel` keeps the last non-empty `SelectionReport` as `currentSelection`). The app adds an "Assistant" item to the View menu group (`"Show Assistant" / "Show Notes"`, ⇧⌘A, the same call when showing, `hidePanel()` when hiding), and the palette command `.toggleAssistant` ("Ask the Assistant", `sparkles`). DESIGN.md's inventory gains `sparkles`, `clock`, `plus`, `xmark`, `arrow.up.circle.fill`, `stop.circle`, `doc.on.doc`, `note.text.badge.plus` under "assistant".

- [x] **Step 1: Build the views** in the order structure, spacing, type and color, states, keyboard (craft order); confirm the package still compiles with `swift build --package-path Packages/ScriptureKit`.

- [x] **Step 2: Wire the app** as above; build with the README's xcodebuild line. Expected: `** BUILD SUCCEEDED **`.

- [x] **Step 3: Run the suite** — expected all pass (no new tests; the existing `ReaderView` call sites compile unchanged).

- [x] **Step 4: Commit** — `feat: chat panel in the inspector, chapter heading prompt menu, Ask About This Passage`

---

### Task 11: Settings › Assistant and Settings › Prompts

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/AssistantSettings.swift`, `AssistantSettingsView.swift`, `PromptTemplatesSettingsView.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/SettingsView.swift`, `ReadingThroughScriptureApp.swift`
- Test: `Tests/ScriptureUITests/AssistantSettingsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum AssistantSettings {   // extends Task 9's enum
      public static let anthropicModelKey = "anthropicModel", openAIModelKey = "openAIModel", compatibleBaseURLKey = "compatibleBaseURL", compatibleModelKey = "compatibleModel"
      /// The configured providers in router order: on-device first (always), then each cloud provider whose key is present.
      public static func providers(defaults: UserDefaults, secrets: any SecretStore) -> [any LLMProvider]
      /// A compatible base URL is used only when it parses with an http or https scheme.
      static func compatibleBaseURL(_ string: String) -> URL?
  }
  @MainActor @Observable public final class AssistantSettingsModel {
      public init(secrets: any SecretStore, defaults: UserDefaults = .standard)
      public var preference: RoutingPreference { didSet }           // writes providerKey
      public var anthropicKey: String, openAIKey: String, compatibleKey: String   // loaded once; `saveKey(_:)` writes through SecretStore and clears any error
      public var anthropicModel, openAIModel, compatibleBaseURL, compatibleModel: String   // didSet writes the key
      public private(set) var hasAnthropicKey, hasOpenAIKey, hasCompatibleKey: Bool
      public private(set) var lastError: String?
      public func saveKey(_ id: LLMProviderID)
      public var onDeviceStatus: String                             // "Available" or the unavailable reason
  }
  public struct AssistantSettingsView: View { public init(model: AssistantSettingsModel) }
  public struct PromptTemplatesSettingsView: View { public init(store: PromptTemplateStore, onChange: @escaping () -> Void) }
  ```
  `AssistantSettingsView` (`Form`, `.formStyle(.grouped)`): section "Model" with a `Picker("Answer with", selection: preference)` listing Automatic, On-device, Claude, OpenAI, Custom endpoint, and the on-device status as the footer; section "Claude" with a `SecureField("API key")` whose `onSubmit` and a "Save" bordered button call `saveKey(.anthropic)`, a `TextField("Model")`, and a footer "Keys are stored in your Keychain and sync through iCloud Keychain."; section "OpenAI" likewise; section "Custom endpoint" with Base URL, Model, API key. A key field shows "Saved" in `ink.secondary` `.caption` beside it when `has…Key`. `PromptTemplatesSettingsView`: two `Section`s (Chapter prompts, Selection prompts), each a `List`-free `VStack` of rows like `HighlightColorsSettingsView` (drag handle `line.3.horizontal`, `Toggle` enabled, title `TextField`, a disclosure to edit the body in a `TextEditor` `.body`, `trash` for user-added ones, "Restore" for edited built-ins), an "Add Prompt" button per section, and a footer naming the placeholders. The Settings window gains tabs "Assistant" (`sparkles`) and "Prompts" (`text.quote`) after Markup; `onChange` calls `assistant.reloadTemplates()`.

- [x] **Step 1: Write the failing tests**

```swift
@Suite struct AssistantSettingsTests {
    private func defaults() -> UserDefaults { let n = "AssistantSettingsTests-\(UUID())"; let d = UserDefaults(suiteName: n)!; d.removePersistentDomain(forName: n); return d }
    @Test func providersFollowTheKeysInRouterOrder() throws {
        let d = defaults(); let secrets = InMemorySecretStore()
        #expect(AssistantSettings.providers(defaults: d, secrets: secrets).map(\.id) == [.appleOnDevice])
        try secrets.setSecret("o", for: .openAI); try secrets.setSecret("a", for: .anthropic)
        #expect(AssistantSettings.providers(defaults: d, secrets: secrets).map(\.id) == [.appleOnDevice, .anthropic, .openAI])
        d.set("http://localhost:11434/v1", forKey: AssistantSettings.compatibleBaseURLKey); d.set("llama3", forKey: AssistantSettings.compatibleModelKey)
        try secrets.setSecret("c", for: .openAICompatible)
        let providers = AssistantSettings.providers(defaults: d, secrets: secrets)
        #expect(providers.map(\.id) == [.appleOnDevice, .anthropic, .openAI, .openAICompatible] && providers[3].modelName == "llama3")
        #expect(providers[1].modelName == "claude-opus-5-5" && providers[2].modelName == "gpt-5")
    }
    @Test func aCompatibleEndpointNeedsAValidURL() throws {
        let d = defaults(); let secrets = InMemorySecretStore()
        try secrets.setSecret("c", for: .openAICompatible)
        d.set("not a url", forKey: AssistantSettings.compatibleBaseURLKey)
        #expect(AssistantSettings.providers(defaults: d, secrets: secrets).map(\.id) == [.appleOnDevice])
        #expect(AssistantSettings.compatibleBaseURL("https://example.com/v1/") == URL(string: "https://example.com/v1/"))
        #expect(AssistantSettings.compatibleBaseURL("ftp://x") == nil)
    }
    @Test func preferenceDefaultsToAutoAndIgnoresGarbage() {
        let d = defaults()
        #expect(AssistantSettings.preference(from: d) == .auto)
        d.set("anthropic", forKey: AssistantSettings.providerKey)
        #expect(AssistantSettings.preference(from: d) == .anthropic)
        d.set("zzz", forKey: AssistantSettings.providerKey)
        #expect(AssistantSettings.preference(from: d) == .auto)
    }
    @MainActor @Test func savingAKeyWritesTheSecretStore() throws {
        let secrets = InMemorySecretStore()
        let model = AssistantSettingsModel(secrets: secrets, defaults: defaults())
        model.anthropicKey = " sk-1 "
        model.saveKey(.anthropic)
        #expect(try secrets.secret(for: .anthropic) == "sk-1" && model.hasAnthropicKey)
        model.anthropicKey = ""
        model.saveKey(.anthropic)
        #expect(try secrets.secret(for: .anthropic) == nil && !model.hasAnthropicKey)
    }
}
```

- [x] **Step 2: Run to verify failure** — `--filter AssistantSettingsTests`; expected compile failure.

- [x] **Step 3: Implement** the settings files and wire the tabs. `AssistantModel`'s `providerFactory` in the app is `{ AssistantSettings.providers(defaults: .standard, secrets: keychain) }`.

- [x] **Step 4: Run the suite and the app build** — expected all pass, `** BUILD SUCCEEDED **`.

- [x] **Step 5: Commit** — `feat: Settings tabs for the assistant's providers, keys and prompt templates`

---

### Task 12: Threads in the Notes browser

**Files:**
- Modify: `NotesBrowserEntry.swift` (`Kind.thread(id:)`, `NotesBrowserFilter.threads`), `NotesBrowserModel.swift` (entries from `ChatStore`, delete), `NotesBrowserRow.swift` (marker and lines), `NotesBrowserView.swift` (filter segment "Threads", delete message), `MarkupTarget.swift` (`threadID`), `ReadingThroughScriptureApp.swift` (`showInReader` opens the thread)
- Test: additions to `NotesBrowserQueryTests.swift`, `NotesBrowserModelTests.swift`

**Interfaces:**
- Produces: `NotesBrowserEntry.Kind.thread(id: UUID)`; for a thread entry `verse`/`endVerse` are the selection's or 0, `translationID` the thread's, `quotedText` the last message's first line (`PaletteNoteHit.firstLine`), `body` the title, `modifiedAt` `updatedAt`; `NotesBrowserFilter.threads` keeps only threads; `.notes`, `.highlights`, `.bookmarks` exclude them; `.all` includes them. `MarkupTarget` gains `public let threadID: UUID?` (nil elsewhere; the `init(entry:)` sets it for a thread, `verse` max(verse, 1)). `MarkupNavigation.show` is unchanged; the app's `showInReader` calls `assistant.open(threadID:)` when set. `NotesBrowserModel.delete(id:)` for a thread goes through `MarkupStore.delete(.thread(...))`, undoable. `NotesBrowserModel.totalCount` includes threads. The row: `sparkles` in `Color.assistant` as the marker, the title in `.callout.weight(.semibold)`, the last line in `.callout` `ink.primary` `lineLimit(2)`, accessibility "Conversation, <reference>". The delete message: "The conversation will be deleted."

- [x] **Step 1: Write the failing tests**

```swift
// NotesBrowserQueryTests
@Test func threadsFilterIsExclusive() {
    let thread = entry(kind: .thread(id: UUID()), book: "MAT", chapter: 5)   // existing helper
    let note = entry(kind: .note(noteID: UUID(), highlightID: nil), book: "MAT", chapter: 5)
    #expect(NotesBrowserQuery.filter([thread, note], by: .threads).map(\.id) == [thread.id])
    #expect(NotesBrowserQuery.filter([thread, note], by: .notes).map(\.id) == [note.id])
    #expect(NotesBrowserQuery.filter([thread, note], by: .all).count == 2)
}
// NotesBrowserModelTests
@Test func threadsAppearWithTitleLastLineAndTarget() throws {
    let (model, store, _) = try make()
    let thread = try store.chat.createThread(scope: .selection, book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "KJV", quotedText: "Blessed", title: "Matthew 5:3 · Blessed")
    try store.chat.append(to: thread, role: .user, content: "Why?", providerID: "", modelName: "", attachedReference: nil)
    try store.chat.append(to: thread, role: .assistant, content: "**Because** it is.\nMore.", providerID: "anthropic", modelName: "claude-opus-5-5", attachedReference: nil)
    model.reload()
    #expect(model.totalCount == 1)
    let entry = model.entries[0]
    #expect(entry.kind == .thread(id: thread.uuid) && entry.body == "Matthew 5:3 · Blessed" && entry.quotedText == "Because it is." && entry.translationID == "KJV")
    let target = model.target(for: entry.id)
    #expect(target?.threadID == thread.uuid && target?.verse == 3 && target?.highlightID == nil)
    model.filter = .notes
    #expect(model.entries.isEmpty)
    model.filter = .threads
    #expect(model.entries.count == 1)
}
@Test func deletingAThreadFromTheBrowserIsUndoable() throws {
    let (model, store, _) = try make()
    let undo = UndoManager(); model.undoManager = undo
    let thread = try store.chat.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "KJV", quotedText: "", title: "Outline: Matthew 5")
    model.reload()
    model.delete(id: thread.uuid)
    #expect(model.entries.isEmpty && (try store.chat.allThreads().isEmpty))
    undo.undo()
    #expect(model.entries.count == 1)
}
```

- [x] **Step 2: Run to verify failure** — `--filter "NotesBrowserQueryTests|NotesBrowserModelTests"`; expected compile failure.

- [x] **Step 3: Implement** the entry kind, filter, model, row, view and app wiring. Every `switch` over `Kind` and `NotesBrowserFilter` gains the new case (the compiler lists them).

- [x] **Step 4: Run the suite and the app build** — expected all pass, `** BUILD SUCCEEDED **`.

- [x] **Step 5: Commit** — `feat: conversations in the Notes browser`

---

### Task 13: README, in-app verification and the whole-branch review

**Files:**
- Modify: `README.md` (Study assistant section: shortcuts, providers, keys, prompts, where threads live), `DESIGN.md` (done in Task 10), `docs/superpowers/plans/2026-10-30-milestone-5-study-assistant.md` (tick the boxes)

- [x] **Step 1: README.** Add "## Study assistant" after "## Notes browser": ⇧⌘A and the toolbar button (which ask whether to include where you are), Ask About This Passage and Ask About This Chapter from the context menus, a click on the heading returning to the chapter grid, the on-device default and the too-long rule, keys in the Keychain, Settings › Assistant and › Prompts, placeholders, threads in the Notes browser, Add as Note. Update the Settings paragraph's key list with the five new keys and the "Current plan" link.

- [x] **Step 2: Build and launch** the app from `Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app`. Run the spec's verification: with no keys, open Matthew 5, right-click the heading, choose Ask About This Chapter, click Catch me up, confirm the reply streams and its label reads "On-device" (or, if Apple Intelligence is off on this Mac, that the panel shows the unavailable sentence and the Settings button; record which). Open Psalm 119, right-click the heading, Ask About This Chapter, click Overall summary, confirm the too-long sentence with "Open Settings". If an Anthropic key is available in the Keychain (Matt's), select a phrase, Ask About This Passage, type a question, confirm the "Claude · claude-opus-5-5" label, Add as Note, confirm the note appears in the column anchored to the phrase, click the `clock` menu and reopen the thread. Capture each state with `screencapture` into the scratchpad and inspect; drive the app through System Events, never touching Matt's store beyond the threads and notes the steps create.

- [x] **Step 3: Critique pass** (`/impeccable-swift critique` on the panel, the heading menu and the two Settings tabs): no inline colors, no fixed-point fonts, every symbol button labelled, the wash only on assistant turns, Dynamic Type at AX3 on the panel, Dark Mode screenshot of the panel. Fix what it finds.

- [x] **Step 4: Whole-branch review** with the superpowers code-review flow, then the full suite and the app build one last time.

- [x] **Step 5: Commit** — `docs: README for the study assistant; verification notes` and leave a hand-over note in the shared notes folder naming what was verified and what needs a key.

## Self-review notes

- Spec coverage: provider protocol (1), Apple FM with availability (6), Anthropic and OpenAI-compatible (3), Keychain (4), router (7), editable templates with editor (5, 8, 11), chat panel with threads and history (9, 10), Add as Note (9), chapter heading menu (10), chapter note band (Add as Note on chapter threads feeds the existing band), too-long message (9, 10), threads in the Notes view (12), verification (13). Deferred and named: `@Generable` Outline (Ruling 5), `fallbacks` on the Anthropic request (not sent; a refusal is shown as a decline).
- Type consistency: `PromptScope` lives in `ScriptureModel` and is used by `PromptSeed` (ScriptureLLM) and `PromptTemplateItem` (ScriptureUI); `RoutingPreference` (ScriptureLLM) is what `AssistantSettings.preference` returns and `LLMRouter.route` takes; `LLMProviderID.rawValue` is what `ChatMessage.providerID` stores and `ProviderLabel.text` reads.
- Review Focus tests: 1 → Task 9, 2 → Tasks 3 and 9, 3 → Task 9, 4 → Task 4, 5 → Task 5.
