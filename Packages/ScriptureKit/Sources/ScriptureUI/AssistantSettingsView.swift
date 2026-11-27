import ScriptureLLM
import SwiftUI

/// Settings › Assistant: who answers, then one section per cloud provider with its key and model.
/// A key is saved into the Keychain as you type (once the field rests), at once on Return, and
/// when Settings closes; clearing the field removes it.
public struct AssistantSettingsView: View {
    @Bindable var model: AssistantSettingsModel

    public init(model: AssistantSettingsModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section {
                Picker("Answer with", selection: $model.preference) {
                    choice("Automatic", .auto)
                    choice("On-device", .appleOnDevice)
                    choice("Claude", .anthropic)
                    choice("OpenAI", .openAI)
                    choice("Custom endpoint", .openAICompatible)
                }
            } header: {
                Text("Model")
            } footer: {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Automatic uses the on-device model when the passage fits and a provider with a key when it does not. On-device: \(model.onDeviceStatus)")
                    if let error = model.lastError {
                        Text(error)
                    }
                }
                .foregroundStyle(Color.inkSecondary)
            }

            Section {
                keyRow(text: $model.anthropicKey, isSaved: model.hasAnthropicKey, id: .anthropic)
                labeledField("Model", text: $model.anthropicModel, prompt: Text(AnthropicProvider.defaultModel))
            } header: {
                Text("Claude")
            } footer: {
                Text("Keys are stored in your Keychain and travel through iCloud Keychain.")
                    .foregroundStyle(Color.inkSecondary)
            }

            Section("OpenAI") {
                keyRow(text: $model.openAIKey, isSaved: model.hasOpenAIKey, id: .openAI)
                labeledField("Model", text: $model.openAIModel, prompt: Text(OpenAICompatibleProvider.defaultOpenAIModel))
            }

            Section {
                labeledField("Base URL", text: $model.compatibleBaseURL, prompt: Text("http://localhost:11434/v1"))
                labeledField("Model", text: $model.compatibleModel, prompt: Text("llama3"))
                keyRow(text: $model.compatibleKey, isSaved: model.hasCompatibleKey, id: .openAICompatible)
            } header: {
                Text("Custom endpoint")
            } footer: {
                Text("Any server that speaks OpenAI's Chat Completions API, such as Ollama or LM Studio. It is used once it has a base URL, a model and a key; a local server that needs no key accepts any.")
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: model.anthropicKey) { model.keyFieldChanged(.anthropic) }
        .onChange(of: model.openAIKey) { model.keyFieldChanged(.openAI) }
        .onChange(of: model.compatibleKey) { model.keyFieldChanged(.openAICompatible) }
        .onDisappear { model.flushPendingSaves() }
    }

    /// A cloud choice without a key says so; it would fall back to Automatic.
    private func choice(_ title: String, _ preference: RoutingPreference) -> some View {
        Text(model.hasKey(for: preference) ? title : "\(title) (no key)").tag(preference)
    }

    /// A text field with its title: the Mac's form draws the title beside the field; an iOS form
    /// does not, so there the title is the row's label, as `keyRow` has it.
    @ViewBuilder
    private func labeledField(_ title: LocalizedStringKey, text: Binding<String>, prompt: Text) -> some View {
        #if os(macOS)
        TextField(title, text: text, prompt: prompt)
        #else
        LabeledContent(title) {
            TextField(title, text: text, prompt: prompt)
        }
        #endif
    }

    private func keyRow(text: Binding<String>, isSaved: Bool, id: LLMProviderID) -> some View {
        LabeledContent("API key") {
            HStack(spacing: AppSpacing.xs) {
                SecureField("API key", text: text, prompt: Text("Paste a key"))
                    .labelsHidden()
                    .onSubmit { model.saveKey(id) }
                if isSaved {
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                    Button("Remove") { model.removeKey(id) }
                        .buttonStyle(.bordered)
                        .help("Delete this key from your Keychain")
                        // Inside LabeledContent the button would otherwise be read as "API key".
                        .accessibilityLabel("Remove Key")
                }
            }
        }
    }
}
