import SwiftUI

/// The panel's composer: a growing field in the note editor's style (overlay paper, the rule as
/// its one border) with Send, or Stop while a reply streams. Return sends; Shift-Return starts a
/// new line.
struct AssistantComposer: View {
    @Binding var draft: String
    let placeholder: String
    let isResponding: Bool
    /// Bumped by the model when the panel opens on a new conversation.
    var focusRequest: Int = 0
    /// The phone's open conversation leaves the keyboard down, so the answer is what shows.
    var focusesOnAppear = true
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool
    /// The caret or selection, so Shift-Return breaks the line where it is.
    @State private var selection: SwiftUI.TextSelection?
    @ScaledMetric(relativeTo: .body) private var fieldInset = AppSpacing.xs

    /// Replaces the selection (or inserts at the caret) with a line break; at the end without one.
    private func breakLine() {
        guard case .selection(let range)? = selection?.indices,
              range.lowerBound >= draft.startIndex, range.upperBound <= draft.endIndex
        else {
            draft.append("\n")
            return
        }
        let offset = draft.distance(from: draft.startIndex, to: range.lowerBound)
        draft.replaceSubrange(range, with: "\n")
        selection = SwiftUI.TextSelection(insertionPoint: draft.index(draft.startIndex, offsetBy: offset + 1))
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.xs) {
            TextField(placeholder, text: $draft, selection: $selection, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1...5)
                .focused($isFocused)
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.shift) {
                        breakLine()
                    } else if !isResponding {
                        onSend()
                    }
                    return .handled
                }
                .padding(fieldInset)
                .editorSurface()
            if isResponding {
                RowSymbolButton(title: "Stop", symbol: "stop.circle", action: onStop)
                    .padding(.bottom, AppSpacing.xxs)
            } else {
                RowSymbolButton(title: "Send", symbol: "arrow.up.circle.fill", tint: canSend ? .accent : .inkTertiary, action: onSend)
                    .disabled(!canSend)
                    .padding(.bottom, AppSpacing.xxs)
            }
        }
        .padding(AppSpacing.sm)
        .onAppear { if focusesOnAppear { isFocused = true } }
        .onChange(of: focusRequest) { _, _ in isFocused = true }
    }
}

#Preview("Composer") {
    @Previewable @State var draft = ""
    VStack(spacing: 0) {
        AssistantComposer(draft: $draft, placeholder: "Ask about Matthew 5:3", isResponding: false, onSend: {}, onStop: {})
        AssistantComposer(draft: .constant("What does meek mean here?"), placeholder: "Ask anything", isResponding: true, onSend: {}, onStop: {})
    }
    .frame(width: 340)
    .background(Color.paperPanel)
}
