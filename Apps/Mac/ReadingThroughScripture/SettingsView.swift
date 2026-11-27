import ScriptureData
import ScriptureModel
import ScriptureUI
import SwiftUI

/// The Settings window: General, Reading, Markup, and the study assistant's providers and prompts.
struct SettingsView: View {
    /// The tab shown; the assistant's "Open Settings" sets it to `assistant` first.
    static let tabKey = "settingsTab"

    let colors: ColorSettingsModel
    let translations: [ScriptureData.Translation]
    let assistantSettings: AssistantSettingsModel
    let templates: PromptTemplateStore
    /// Goes up when an import reloads the models, so the Prompts tab reloads its rows.
    let templatesRevision: Int
    let onTemplatesChange: () -> Void
    /// The iCloud status line and the daily backups, for Settings › General.
    let sync: SyncStatusModel
    let backups: BackupsModel?
    @AppStorage(SettingsView.tabKey) private var tab = "general"

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettingsView(translations: translations, sync: sync, backups: backups)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag("general")
            ReadingSettingsView()
                .tabItem { Label("Reading", systemImage: "textformat.size") }
                .tag("reading")
            HighlightColorsSettingsView(model: colors)
                .tabItem { Label("Markup", systemImage: "highlighter") }
                .tag("markup")
            AssistantSettingsView(model: assistantSettings)
                .tabItem { Label("Assistant", systemImage: "sparkles") }
                .tag("assistant")
            PromptTemplatesSettingsView(store: templates, revision: templatesRevision, onChange: onTemplatesChange)
                .tabItem { Label("Prompts", systemImage: "text.quote") }
                .tag("prompts")
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag("about")
        }
        // A minimum, not a fixed size, so larger text sizes grow the window instead of clipping.
        .frame(minWidth: 500, minHeight: 440)
        .tint(Color.accent)
    }
}
