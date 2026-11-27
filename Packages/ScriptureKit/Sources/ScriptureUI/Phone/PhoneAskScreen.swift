#if os(iOS)
import ScriptureData
import ScriptureModel
import SwiftUI

/// The Ask tab: what a new question is about (the chapter being read, as a tag that can be
/// removed), the chapter's prompts as tiles, every earlier conversation as a plain dated row, and
/// the composer above the tab bar, ready as the tab opens. A question, a tile or a row pushes the
/// conversation; arriving with one already open (a Notes row) shows it, with Back to this screen.
public struct PhoneAskScreen: View {
    @Bindable private var assistant: AssistantModel
    private let navigation: NavigationModel
    private let shell: PhoneShellModel
    @Environment(\.undoManager) private var undoManager
    @State private var path: [AskRoute] = []
    /// The chapter the tag was removed in; opening the tab from another chapter brings it back.
    @State private var tagRemovedIn: ChapterLocation?
    /// The conversation Back left while its reply was still arriving; let go once it ends.
    @State private var leftWhileAnswering: UUID?

    private enum AskRoute: Hashable {
        case conversation
    }

    public init(assistant: AssistantModel, navigation: NavigationModel, shell: PhoneShellModel) {
        self.assistant = assistant
        self.navigation = navigation
        self.shell = shell
    }

    /// The chapter the tag names; nil when it was removed or nothing is being read.
    private var tagTitle: String? {
        guard tagRemovedIn == nil else { return nil }
        return assistant.chapterTitle
    }

    /// With the tag a new question is about the chapter; without it, about anything.
    private var newScope: ThreadScope { tagTitle == nil ? .general : .chapter }

    public var body: some View {
        NavigationStack(path: $path) {
            list
                .background(Color.paperPage)
                .navigationTitle("Ask")
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    AssistantComposer(
                        draft: $assistant.draft,
                        placeholder: assistant.composerPlaceholder,
                        isResponding: assistant.isResponding,
                        onSend: send,
                        onStop: { assistant.stop() })
                    .background(Color.paperPage)
                }
                .navigationDestination(for: AskRoute.self) { _ in
                    PhoneChatScreen(assistant: assistant, navigation: navigation, shell: shell)
                }
        }
        .onAppear(perform: arrive)
        .onChange(of: shell.tab) { _, tab in
            if tab == .ask { arrive() }
        }
        // Back from a conversation (only ever on this tab): the next question starts a new one. A
        // reply still arriving finishes first; only the conversation left is let go, never one
        // started since (the model is shared with the sheet over the page).
        .onChange(of: path.isEmpty) { _, isEmpty in
            guard isEmpty, shell.tab == .ask else { return }
            if assistant.isResponding {
                leftWhileAnswering = assistant.thread?.id
            } else {
                assistant.startNew(scope: newScope)
            }
        }
        .onChange(of: assistant.isResponding) { _, responding in
            guard !responding, let left = leftWhileAnswering else { return }
            leftWhileAnswering = nil
            if assistant.thread?.id == left, path.isEmpty { assistant.startNew(scope: newScope) }
        }
        // The scene's undo manager, so a swiped delete comes back with shake or a three-finger swipe.
        .onChange(of: undoManager, initial: true) { _, manager in
            assistant.undoManager = manager
        }
        .background { UndoResponder(undoManager: undoManager).frame(width: 0, height: 0) }
    }

    private var list: some View {
        List {
            if let tagTitle {
                tag(tagTitle)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.paperPage)
                if !assistant.prompts.isEmpty {
                    Section {
                        PromptTilesView(prompts: assistant.prompts, isDisabled: assistant.isResponding, onRun: runPrompt)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.paperPage)
                    } header: {
                        sectionTitle("Start with a prompt")
                    }
                }
            }
            if !assistant.allThreads.isEmpty {
                Section {
                    ForEach(assistant.allThreads) { item in
                        Button { open(item.id) } label: { ConversationRow(item: item) }
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            .listRowBackground(Color.paperPage)
                            .listRowSeparatorTint(Color.inkRule)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    assistant.deleteThread(id: item.id)
                                }
                            }
                    }
                } header: {
                    sectionTitle("Earlier conversations")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    /// "About John 15" with an `xmark` that removes it, on the panel paper like the Notes tab's menus.
    private func tag(_ title: String) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Text("About \(title)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkPrimary)
            RowSymbolButton(title: "Remove", symbol: "xmark", action: removeTag)
        }
        .padding(.leading, AppSpacing.sm)
        .padding(.trailing, AppSpacing.xxs)
        .padding(.vertical, AppSpacing.xxs)
        .background(Color.paperPanel, in: Capsule())
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.inkSecondary)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Actions

    /// The tab opened: a conversation opened for it (a Notes row or a search result, whose
    /// `open(threadID:)` leaves nothing arriving) is shown; otherwise this screen, with a new
    /// conversation waiting, about the chapter unless the tag was removed in this one. A reply
    /// still arriving (one left by Back, or one asked over the page) is not pushed: it is let go
    /// when it ends.
    private func arrive() {
        if let removed = tagRemovedIn, removed != assistant.location { tagRemovedIn = nil }
        if assistant.thread != nil {
            if path.isEmpty, !assistant.isResponding { path = [.conversation] }
        } else if !path.isEmpty {
            // The conversation shown here was let go meanwhile (asked over the page since).
            path = []
        } else if assistant.pendingScope != newScope {
            assistant.startNew(scope: newScope)
        }
    }

    private func removeTag() {
        tagRemovedIn = assistant.location
        assistant.startNew(scope: .general)
    }

    /// A conversation left open (a reply that was still arriving) gives way to a new one.
    private func prepareNew() {
        if assistant.thread != nil || assistant.pendingScope != newScope { assistant.startNew(scope: newScope) }
    }

    private func send() {
        guard !assistant.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !assistant.isResponding else { return }
        prepareNew()
        assistant.send()
        path = [.conversation]
    }

    private func runPrompt(_ id: UUID) {
        prepareNew()
        assistant.runPrompt(id)
        path = [.conversation]
    }

    private func open(_ threadID: UUID) {
        assistant.open(threadID: threadID)
        path = [.conversation]
    }
}

/// An earlier conversation: the `sparkles`, its title with the date on the trailing edge, and
/// what it is about under it. A row with rhythm, not a card.
private struct ConversationRow: View {
    let item: ChatThreadItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(2)
                    Spacer(minLength: AppSpacing.xs)
                    Text(item.updatedAt, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.inkTertiary)
                }
                Text(item.referenceString)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.vertical, AppSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
#endif
