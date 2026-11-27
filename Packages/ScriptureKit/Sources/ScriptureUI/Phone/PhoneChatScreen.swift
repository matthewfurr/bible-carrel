#if os(iOS)
import ScriptureData
import SwiftUI
import UIKit

/// One conversation on the phone, pushed in the Ask tab or over the page as a sheet: the Mac
/// panel's transcript (`ChatTurnRow`s with Copy and Add as Note and the model label), or before
/// the first message the quoted phrase and the scope's prompts; then the notice with Try Again,
/// and the composer. A reference tapped in a reply shows its verses in a sheet (`shell.versePreview`).
struct PhoneChatScreen: View {
    @Environment(\.pageFace) private var pageFace
    @Bindable private var assistant: AssistantModel
    private let navigation: NavigationModel
    @Bindable private var shell: PhoneShellModel
    /// Over the page this screen is itself a sheet, so it shows the verse sheet; in the Ask tab
    /// the root does.
    private let presentsVersePreview: Bool
    /// A pending conversation (Ask from a selection) takes the keyboard; an open one is for reading.
    private let focusesComposer: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    init(assistant: AssistantModel, navigation: NavigationModel, shell: PhoneShellModel, presentsVersePreview: Bool = false) {
        self.assistant = assistant
        self.navigation = navigation
        self.shell = shell
        self.presentsVersePreview = presentsVersePreview
        focusesComposer = assistant.thread == nil
    }

    var body: some View {
        Group {
            if assistant.messages.isEmpty {
                opening
            } else {
                transcript
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paperPage)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                noticeRow
                AssistantComposer(
                    draft: $assistant.draft,
                    placeholder: assistant.composerPlaceholder,
                    isResponding: assistant.isResponding,
                    focusesOnAppear: focusesComposer,
                    onSend: { assistant.send() },
                    onStop: { assistant.stop() })
            }
            .background(Color.paperPage)
        }
        .navigationTitle(assistant.scopeLabel ?? "Ask")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: presentsVersePreview ? $shell.versePreview : .constant(nil)) { preview in
            PhoneVerseSheet(preview: preview, navigation: navigation, shell: shell)
        }
    }

    // MARK: - Middle

    /// Before the first message: the quoted phrase and the scope's prompts, by the composer.
    private var opening: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let quoted = assistant.quotedText, !quoted.isEmpty {
                    quote(quoted)
                }
                if !assistant.prompts.isEmpty {
                    PromptTilesView(prompts: assistant.prompts, isDisabled: assistant.isResponding) { id in
                        assistant.runPrompt(id)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .alignment)
    }

    private func quote(_ text: String) -> some View {
        Text("\u{201C}\(text)\u{201D}")
            .font(pageFace.quoteFont())
            .foregroundStyle(Color.inkSecondary)
            .lineLimit(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    if let quoted = assistant.quotedText, !quoted.isEmpty {
                        quote(quoted)
                    }
                    ForEach(assistant.messages) { message in
                        ChatTurnRow(
                            message: message,
                            savedNoteID: message.savedNoteID,
                            onCopy: { copy(messageID: message.id) },
                            onAddAsNote: { assistant.addAsNote(messageID: message.id) },
                            onShowNote: { assistant.showSavedNote(messageID: message.id) },
                            contextBook: assistant.referenceContextBook,
                            chapterCount: assistant.chapterCount(ofBook:),
                            onOpenReference: { shell.versePreview = assistant.versePreview($0) })
                        .id(message.id)
                    }
                }
                .padding(AppSpacing.md)
            }
            // As on the Mac: a long conversation opens at its end, and a growing reply does not
            // drag the view along.
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .defaultScrollAnchor(.bottom, for: .alignment)
            .onAppear { showLastReply(proxy) }
            .onChange(of: assistant.thread?.id) { _, _ in showLastReply(proxy) }
            .onChange(of: assistant.messages.count) { old, new in
                // A send adds the question and its reply: bring the question to the top once.
                guard new == old + 2, assistant.messages.last?.isStreaming == true else { return }
                let id = assistant.messages[new - 2].id
                if reduceMotion {
                    proxy.scrollTo(id, anchor: .top)
                } else {
                    withAnimation(.smooth) { proxy.scrollTo(id, anchor: .top) }
                }
            }
        }
    }

    /// A reopened conversation shows the start of its last reply.
    private func showLastReply(_ proxy: ScrollViewProxy) {
        guard let id = assistant.messages.last(where: { $0.role == .assistant })?.id else { return }
        proxy.scrollTo(id, anchor: .top)
    }

    // MARK: - Above the composer

    /// Settings from the root. Over the page this screen is a sheet the root cannot present over,
    /// so it closes first and the reader opens Settings once it has gone.
    private func openSettings() {
        if presentsVersePreview {
            shell.isSettingsQueued = true
            dismiss()
        } else {
            shell.isSettingsShown = true
        }
    }

    /// Why nothing was sent, or why a reply stopped, with Try Again when the last question can be
    /// sent again.
    @ViewBuilder
    private var noticeRow: some View {
        if assistant.notice != nil || assistant.canRetry {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                if let notice = assistant.notice {
                    Text(notice.message)
                        .font(.callout)
                        .foregroundStyle(Color.inkSecondary)
                }
                HStack(spacing: AppSpacing.xs) {
                    if assistant.canRetry {
                        Button("Try Again") { assistant.retry() }
                    }
                    if assistant.notice?.offersSettings == true {
                        Button("Open Settings", action: openSettings)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
        }
    }

    private func copy(messageID: UUID) {
        guard let text = assistant.copyText(messageID: messageID) else { return }
        UIPasteboard.general.string = text
    }
}

/// A reference from a reply, at the sheet's medium detent: its verses, and Open in Read, which
/// shows the chapter at that verse as a lookup, with the way back to the place being read.
struct PhoneVerseSheet: View {
    let preview: VersePreview
    let navigation: NavigationModel
    let shell: PhoneShellModel

    var body: some View {
        VersePreviewView(preview: preview, openTitle: "Open in Read") {
            guard let chapter = preview.reference.chapter else { return }
            let location = ChapterLocation(book: preview.reference.book.id, chapter: chapter)
            navigation.lookUp(location, verse: preview.reference.verse)
            navigation.recordLookup(location, verse: preview.reference.verse)
            shell.showInReader()
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // A sheet does not inherit the tab view's tint.
        .tint(Color.accent)
        .presentationDetents([.medium])
    }
}
#endif
