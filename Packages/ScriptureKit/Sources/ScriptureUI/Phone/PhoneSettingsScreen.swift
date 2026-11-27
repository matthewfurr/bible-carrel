#if os(iOS)
import ScriptureData
import ScriptureModel
import SwiftUI

/// Settings over the page: the Mac's Settings panes as pages pushed from one list (General with
/// iCloud and Backups, Reading, Highlight Colors, Prompts, Assistant), under a bar with Done.
/// The app builds it, since the sync status, the backups and the prompts' revision are its.
public struct PhoneSettingsScreen: View {
    let translations: [ScriptureData.Translation]
    let sync: SyncStatusModel
    let backups: BackupsModel?
    let data: DataTransferModel?
    let colors: ColorSettingsModel
    let assistantSettings: AssistantSettingsModel
    let templates: PromptTemplateStore
    /// Goes up when an import reloads the models, so Prompts reloads its rows.
    let templatesRevision: Int
    let onTemplatesChange: () -> Void
    @Environment(\.dismiss) private var dismiss
    /// The pages pushed over the list; More Settings… opens with Reading already pushed, so Back
    /// leads to the list.
    @State private var path: [Page]

    /// The list's pages, pushed by value so the stack can open on one.
    private enum Page: Hashable {
        case general, reading, highlightColors, prompts, assistant, about

        init(_ destination: SettingsDestination) {
            switch destination {
            case .reading: self = .reading
            case .general: self = .general
            }
        }
    }

    /// `destination` is the page to open at (the reader menu's More Settings… opens Reading); nil
    /// opens the list. Read once, when Settings is presented.
    public init(
        translations: [ScriptureData.Translation], sync: SyncStatusModel, backups: BackupsModel?,
        data: DataTransferModel? = nil, colors: ColorSettingsModel, assistantSettings: AssistantSettingsModel, templates: PromptTemplateStore,
        templatesRevision: Int, destination: SettingsDestination? = nil, onTemplatesChange: @escaping () -> Void
    ) {
        self.translations = translations
        self.sync = sync
        self.backups = backups
        self.data = data
        self.colors = colors
        self.assistantSettings = assistantSettings
        self.templates = templates
        self.templatesRevision = templatesRevision
        self.onTemplatesChange = onTemplatesChange
        _path = State(initialValue: destination.map { [Page($0)] } ?? [])
    }

    public var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    link("General", systemImage: "gearshape", to: .general)
                    link("Reading", systemImage: "textformat.size", to: .reading)
                    link("Highlight Colors", systemImage: "highlighter", to: .highlightColors)
                    link("Prompts", systemImage: "text.quote", to: .prompts)
                    link("Assistant", systemImage: "sparkles", to: .assistant)
                    link("About", systemImage: "info.circle", to: .about)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Page.self) { page in
                content(of: page)
                    .navigationTitle(title(of: page))
                    .navigationBarTitleDisplayMode(.inline)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        // As the Mac's Settings window: switches, pickers and buttons in the accent, not the system's.
        .tint(Color.accent)
    }

    private func link(_ title: LocalizedStringKey, systemImage: String, to page: Page) -> some View {
        NavigationLink(value: page) {
            Label(title, systemImage: systemImage)
        }
    }

    private func title(of page: Page) -> LocalizedStringKey {
        switch page {
        case .general: "General"
        case .reading: "Reading"
        case .highlightColors: "Highlight Colors"
        case .prompts: "Prompts"
        case .assistant: "Assistant"
        case .about: "About"
        }
    }

    @ViewBuilder
    private func content(of page: Page) -> some View {
        switch page {
        case .general: GeneralSettingsView(translations: translations, sync: sync, backups: backups, data: data)
        case .reading: ReadingSettingsView()
        case .highlightColors: HighlightColorsSettingsView(model: colors)
        case .prompts: PromptTemplatesSettingsView(store: templates, revision: templatesRevision, onChange: onTemplatesChange)
        case .assistant: AssistantSettingsView(model: assistantSettings)
        case .about: AboutView()
        }
    }
}
#endif
