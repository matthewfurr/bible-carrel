import SwiftUI

/// The reader's inspector: the notes column, or the chat panel while a conversation is open. The
/// swap is a quick cross-fade, a cut under Reduce Motion.
public struct InspectorContentView: View {
    @Bindable var markup: MarkupModel
    @Bindable var assistant: AssistantModel
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(markup: MarkupModel, assistant: AssistantModel, onOpenSettings: @escaping () -> Void) {
        self.markup = markup
        self.assistant = assistant
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        ZStack {
            if assistant.isPanelShown {
                ChatPanelView(model: assistant, onOpenSettings: onOpenSettings)
                    .transition(.opacity)
            } else {
                NotesColumnView(model: markup)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: assistant.isPanelShown)
    }
}
