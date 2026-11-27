import ScriptureData
import ScriptureModel
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The study assistant in the inspector, in the notes column's place while a conversation is
/// open: a header like the column's (what the conversation is about, a new one, history, back to
/// Notes), the transcript, then above the composer either the prompts for the scope, the
/// question "Include where you are?", or a notice that says why nothing was sent.
///
/// Escape stops a reply that is arriving, else returns to Notes. Plum appears in three places only: the `sparkles` in the header, the
/// model label and the reply block.
public struct ChatPanelView: View {
    @Environment(\.pageFace) private var pageFace
    @Bindable var model: AssistantModel
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The verses of the reference last clicked in a reply, shown in a popover on that reply.
    @State private var preview: VersePreview?
    /// The reply the preview's popover is attached to.
    @State private var previewMessageID: UUID?

    public init(model: AssistantModel, onOpenSettings: @escaping () -> Void) {
        self.model = model
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Color.inkRule.frame(height: 1)
            if model.messages.isEmpty {
                opening
            } else {
                transcript
            }
            Color.inkRule.frame(height: 1)
            band
            AssistantComposer(
                draft: $model.draft,
                placeholder: model.composerPlaceholder,
                isResponding: model.isResponding,
                focusRequest: model.composerFocusRequest,
                onSend: { model.send() },
                onStop: { model.stop() })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.paperPanel)
        #if os(macOS)
        .onExitCommand { model.escape() }
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Color.assistant)
                    .accessibilityHidden(true)
                Text("Assistant")
                    .font(.headline)
                    .foregroundStyle(Color.inkPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let scope = model.scopeLabel {
                    Text(scope)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityLabel("About \(scope)")
                }
            }
            Spacer(minLength: AppSpacing.xs)
            HStack(spacing: AppSpacing.xxs) {
                newConversationMenu
                historyMenu
                RowSymbolButton(title: "Show Notes", symbol: "xmark") { model.hidePanel() }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    private var newConversationMenu: some View {
        Menu {
            if let chapter = model.chapterTitle {
                Button(chapter) { model.chooseContext(.chapter) }
            }
            if let book = model.bookTitle {
                Button(book) { model.chooseContext(.book) }
            }
            Button("No context") { model.chooseContext(.general) }
        } label: {
            HeaderMenuGlyph(symbol: "plus")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("New Conversation")
        .accessibilityLabel("New Conversation")
    }

    private var historyMenu: some View {
        Menu {
            if model.history.isEmpty {
                Button("No conversations here yet") {}
                    .disabled(true)
            } else {
                // A toggle per conversation gives the menu's own checkmark column for the open one
                // and keeps the date as the item's subtitle (an inline Picker's options drop the
                // second line). Choosing the open one again does nothing, so it neither stops a
                // reply that is arriving nor drops Try Again.
                ForEach(model.history) { item in
                    Toggle(isOn: Binding(
                        get: { item.id == model.thread?.id },
                        set: { on in if on { model.open(threadID: item.id) } }
                    )) {
                        Text(item.title)
                        Text(item.updatedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    }
                }
            }
            if let thread = model.thread {
                Divider()
                Button("Delete This Conversation", role: .destructive) { model.deleteThread(id: thread.id) }
            }
        } label: {
            HeaderMenuGlyph(symbol: "clock")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Conversations Here")
        .accessibilityLabel("Conversations Here")
    }

    // MARK: - Middle

    /// Before the first message: the quoted phrase, if the conversation is about one, and the
    /// scope's prompts as tiles in sections, settled at the bottom just above the composer.
    private var opening: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let quoted = model.quotedText, !quoted.isEmpty {
                    quote(quoted)
                }
                if !model.prompts.isEmpty {
                    PromptTilesView(prompts: model.prompts, isDisabled: model.isResponding) { id in
                        model.runPrompt(id)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.bottom)
        // Shorter than the panel, the content sits at the bottom, by the composer.
        .defaultScrollAnchor(.bottom, for: .alignment)
        .frame(maxHeight: .infinity)
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
                    if let quoted = model.quotedText, !quoted.isEmpty {
                        quote(quoted)
                    }
                    ForEach(model.messages) { message in
                        ChatTurnRow(
                            message: message,
                            savedNoteID: message.savedNoteID,
                            onCopy: { copy(messageID: message.id) },
                            onAddAsNote: { model.addAsNote(messageID: message.id) },
                            onShowNote: { model.showSavedNote(messageID: message.id) },
                            contextBook: model.referenceContextBook,
                            chapterCount: model.chapterCount(ofBook:),
                            onOpenReference: { reference in showPreview(of: reference, on: message.id) })
                        .id(message.id)
                        .popover(item: previewBinding(for: message.id)) { preview in
                            VersePreviewView(preview: preview, openTitle: "Open") {
                                self.preview = nil
                                model.onOpenPassage?(preview.reference)
                            }
                        }
                    }
                }
                .padding(AppSpacing.md)
            }
            // A short conversation sits by the composer; a long one opens at its end, and a
            // growing reply does not drag the view along, so its opening stays readable.
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .defaultScrollAnchor(.bottom, for: .alignment)
            .onAppear { showLastReply(proxy) }
            .onChange(of: model.thread?.id) { _, _ in showLastReply(proxy) }
            .onChange(of: model.messages.count) { old, new in
                // A send adds the question and its reply: bring the question to the top once.
                guard new == old + 2, model.messages.last?.isStreaming == true else { return }
                scroll(proxy, to: model.messages[new - 2].id)
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// A reopened conversation shows the start of its last reply.
    private func showLastReply(_ proxy: ScrollViewProxy) {
        guard let id = model.messages.last(where: { $0.role == .assistant })?.id else { return }
        proxy.scrollTo(id, anchor: .top)
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: UUID) {
        if reduceMotion {
            proxy.scrollTo(id, anchor: .top)
        } else {
            withAnimation(.smooth) { proxy.scrollTo(id, anchor: .top) }
        }
    }

    // MARK: - Above the composer

    @ViewBuilder
    private var band: some View {
        if let notice = model.notice {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(notice.message)
                    .font(.callout)
                    .foregroundStyle(Color.inkSecondary)
                if notice.offersSettings {
                    Button("Open Settings", action: onOpenSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
        } else if model.isAskingForContext {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Include where you are?")
                    .font(.callout)
                    .foregroundStyle(Color.inkSecondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.xs) { contextButtons }
                    VStack(alignment: .leading, spacing: AppSpacing.xs) { contextButtons }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
        }
    }

    @ViewBuilder
    private var contextButtons: some View {
        if let chapter = model.chapterTitle {
            Button(chapter) { model.chooseContext(.chapter) }
        }
        if let book = model.bookTitle {
            Button(book) { model.chooseContext(.book) }
        }
        Button("No context") { model.chooseContext(.general) }
    }

    // MARK: - Actions

    /// A reference clicked in a reply: its verses in a popover on that reply. A reference to
    /// verses the translation does not have shows nothing.
    private func showPreview(of reference: Reference, on messageID: UUID) {
        guard let loaded = model.versePreview(reference) else { return }
        previewMessageID = messageID
        preview = loaded
    }

    /// The preview, for the one reply it belongs to; nil for every other row.
    private func previewBinding(for messageID: UUID) -> Binding<VersePreview?> {
        Binding(
            get: { previewMessageID == messageID ? preview : nil },
            set: { newValue in
                guard previewMessageID == messageID else { return }
                preview = newValue
            })
    }

    private func copy(messageID: UUID) {
        guard let text = model.copyText(messageID: messageID) else { return }
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

/// A header menu's symbol with the row buttons' 24 pt hit area.
private struct HeaderMenuGlyph: View {
    let symbol: String
    @ScaledMetric(relativeTo: .caption) private var hitSize: CGFloat = 24

    var body: some View {
        Image(systemName: symbol)
            .font(.callout)
            .foregroundStyle(Color.inkSecondary)
            .frame(minWidth: hitSize, minHeight: hitSize)
            .contentShape(Rectangle())
    }
}
