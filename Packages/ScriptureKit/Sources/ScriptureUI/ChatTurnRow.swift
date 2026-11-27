import ScriptureData
import ScriptureModel
import SwiftUI

/// One turn of the transcript. The reader types like chat and the assistant answers like notes,
/// so the two sides look different on purpose: the reader's turn is a light bubble at the
/// trailing edge, the assistant's a full-width document block on the plum wash (DESIGN.md's
/// `assistant-reply`) with who answered, why it ended early if it did, Copy and Add as Note (or
/// Show Note, once the reply is saved) beneath it. The reply is one selectable text, so a drag
/// can select across its paragraphs; the references in it are plum links (`ReferenceLinker`)
/// that hand the reference to `onOpenReference`.
struct ChatTurnRow: View {
    let message: ChatMessageItem
    /// The note Add as Note made of this reply, while it exists.
    let savedNoteID: UUID?
    let onCopy: () -> Void
    let onAddAsNote: () -> Void
    let onShowNote: () -> Void
    /// The book a bare "5:3" in the reply resolves against: the thread's; nil for "No context".
    var contextBook: Book? = nil
    var chapterCount: (String) -> Int? = { _ in nil }
    /// A click on a reference in the reply.
    var onOpenReference: (Reference) -> Void = { _ in }

    /// When Copy was last clicked: its symbol reads as a checkmark for `copiedDuration`.
    @State private var copiedAt: Date?
    private static let copiedDuration: Duration = .milliseconds(1500)

    @ScaledMetric(relativeTo: .callout) private var bubbleVertical = AppSpacing.xs
    @ScaledMetric(relativeTo: .callout) private var bubbleHorizontal = AppSpacing.sm
    @ScaledMetric(relativeTo: .callout) private var replyVertical = AppSpacing.sm
    @ScaledMetric(relativeTo: .callout) private var replyHorizontal = AppSpacing.md

    var body: some View {
        switch message.role {
        case .user: readerTurn
        case .assistant:
            assistantTurn(linked: ReferenceLinker.linked(NoteMarkdown.document(message.content), contextBook: contextBook, chapterCount: chapterCount))
        }
    }

    /// The references linked in a reply, each once, in the order they first appear.
    nonisolated static func linkedReferences(in text: AttributedString) -> [Reference] {
        var seen = Set<Reference>()
        var references: [Reference] = []
        for run in text.runs {
            guard let url = run.link, let reference = ReferenceLinker.reference(from: url), seen.insert(reference).inserted else { continue }
            references.append(reference)
        }
        return references
    }

    private var readerTurn: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
            if let reference = message.attachedReference {
                Text(reference)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(message.displayText)
                    .font(.callout)
                    .foregroundStyle(Color.inkPrimary)
                    .textSelection(.enabled)
                    .padding(.vertical, bubbleVertical)
                    .padding(.horizontal, bubbleHorizontal)
                    .background(Color.paperOverlay, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
            }
            // At most four fifths of the panel, so a reply is always the wider of the two.
            .containerRelativeFrame(.horizontal, alignment: .trailing) { width, _ in width * 0.8 }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("You")
        .accessibilityValue([message.attachedReference, message.displayText].compactMap { $0 }.joined(separator: ", "))
    }

    private func assistantTurn(linked: AttributedString) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if !message.content.isEmpty {
                Text(linked)
                    .font(.callout)
                    .foregroundStyle(Color.inkPrimary)
                    .tint(Color.assistant)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.scheme == ReferenceLinker.scheme else { return .systemAction }
                        if let reference = ReferenceLinker.reference(from: url) { onOpenReference(reference) }
                        return .handled
                    })
            }
            footer
        }
        .padding(.vertical, replyVertical)
        .padding(.horizontal, replyHorizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.assistantWash, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(["Assistant", message.providerLabel, message.finishReason?.footerText].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue(message.content.isEmpty ? "Answering" : message.content)
        .accessibilityActions {
            // The row is one element, so the links inside it are not reachable on their own:
            // each reference is an action named for it ("John 1:32").
            ForEach(Self.linkedReferences(in: linked), id: \.self) { reference in
                Button(reference.displayString) { onOpenReference(reference) }
            }
            if !message.isStreaming {
                Button("Copy", action: copy)
                if savedNoteID != nil {
                    Button("Show Note", action: onShowNote)
                } else {
                    Button("Add as Note", action: onAddAsNote)
                }
            }
        }
        // Puts the Copy symbol back; cancelled with the row.
        .task(id: copiedAt) {
            guard copiedAt != nil else { return }
            try? await Task.sleep(for: Self.copiedDuration)
            guard !Task.isCancelled else { return }
            copiedAt = nil
        }
    }

    private func copy() {
        onCopy()
        copiedAt = .now
        AccessibilityNotification.Announcement("Copied").post()
    }

    private var footer: some View {
        HStack(spacing: AppSpacing.xs) {
            if message.isStreaming && message.content.isEmpty {
                ProgressView()
                    .controlSize(.small)
                Text("Answering")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            } else {
                if let label = message.providerLabel {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(Color.assistant)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let reason = message.finishReason, !message.isStreaming {
                    Text(reason.footerText)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: AppSpacing.xs)
            if !message.isStreaming {
                RowSymbolButton(title: copiedAt == nil ? "Copy" : "Copied", symbol: copiedAt == nil ? "doc.on.doc" : "checkmark", action: copy)
                if savedNoteID != nil {
                    RowSymbolButton(title: "Show Note", symbol: "note.text", action: onShowNote)
                } else {
                    RowSymbolButton(title: "Add as Note", symbol: "note.text.badge.plus", action: onAddAsNote)
                }
            }
        }
    }
}

#Preview("Turns") {
    ScrollView {
        VStack(spacing: AppSpacing.sm) {
            ChatTurnRow(message: ChatMessageItem(id: UUID(), role: .user, content: "Why are the poor in spirit blessed?", providerLabel: nil, attachedReference: nil, isStreaming: false), savedNoteID: nil, onCopy: {}, onAddAsNote: {}, onShowNote: {})
            ChatTurnRow(message: ChatMessageItem(id: UUID(), role: .assistant, content: "**Poor in spirit** names people who know they bring nothing to God.\n\nJesus begins the sermon by turning the expected order over (5:3).", providerLabel: "Claude · claude-opus-5-5", attachedReference: nil, isStreaming: false), savedNoteID: nil, onCopy: {}, onAddAsNote: {}, onShowNote: {})
            ChatTurnRow(message: ChatMessageItem(id: UUID(), role: .user, content: "Now at Matthew 6…", displayText: "And the Lord's prayer?", providerLabel: nil, attachedReference: "Matthew 6", isStreaming: false), savedNoteID: nil, onCopy: {}, onAddAsNote: {}, onShowNote: {})
            ChatTurnRow(message: ChatMessageItem(id: UUID(), role: .assistant, content: "", providerLabel: "On-device", attachedReference: nil, isStreaming: true), savedNoteID: nil, onCopy: {}, onAddAsNote: {}, onShowNote: {})
        }
        .padding(AppSpacing.md)
    }
    .frame(width: 340, height: 520)
    .background(Color.paperPanel)
}
