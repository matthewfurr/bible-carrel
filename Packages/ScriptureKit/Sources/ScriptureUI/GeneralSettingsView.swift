import ScriptureData
import SwiftUI
#if os(iOS)
import OSLog
import UniformTypeIdentifiers
#endif

/// Settings → General: the default translation (applied to the reader when changed, and used on
/// first launch; the toolbar pill still switches per session), and everything about the notes
/// column in one place: whether it shows (mirrors ⌥⌘N), whether highlights without notes appear
/// in it, and which key finishes a note. Then, when the models are given, the iCloud status and
/// the daily backups with Restore.
public struct GeneralSettingsView: View {
    let translations: [ScriptureData.Translation]
    let sync: SyncStatusModel?
    let backups: BackupsModel?
    let data: DataTransferModel?

    @AppStorage(ReaderSettings.defaultTranslationKey) private var defaultTranslationID = ReaderSettings.defaultTranslationID
    @AppStorage("showNotesColumn") private var showNotesColumn = true
    @AppStorage(MarkupModel.showNotelessHighlightsKey) private var showNotelessHighlights = true
    @AppStorage(NoteEditingKeys.settingKey) private var finishWithReturn = false
    @AppStorage(LibraryDates.showKey) private var showDates = true

    public init(translations: [ScriptureData.Translation], sync: SyncStatusModel? = nil, backups: BackupsModel? = nil, data: DataTransferModel? = nil) {
        self.translations = translations
        self.sync = sync
        self.backups = backups
        self.data = data
    }

    public var body: some View {
        Form {
            Section {
                Picker("Default translation", selection: $defaultTranslationID) {
                    ForEach(translations) { translation in
                        Text(translation.title).tag(translation.id)
                    }
                }
            } header: {
                Text("Translation")
            } footer: {
                #if os(macOS)
                Text("Switches the reader now and is used on first launch. The toolbar pill also changes the translation you are reading in.")
                #else
                Text("Switches the reader now and is used on first launch. The reader's menu also changes the translation you are reading in.")
                #endif
            }
            Section {
                CompareSetToggles(translations: translations)
            } header: {
                Text("Compare with")
            } footer: {
                Text("Compare Translations shows these beside the translation you are reading.")
            }
            Section {
                Toggle("Show dates", isOn: Binding(get: { showDates }, set: { LibraryDates.setShows($0, in: .standard) }))
            } header: {
                Text("Library")
            } footer: {
                Text("Years for people and events follow a traditional chronology (Ussher's, as worked out by Floyd Nolen Jones), which puts Creation at 4004 BC. A dictionary entry may still mention a year in its own words.")
            }
            #if os(macOS)
            Section {
                Toggle("Show notes column", isOn: $showNotesColumn)
                Toggle("Show highlights without notes", isOn: $showNotelessHighlights)
                Picker("Finish a note with", selection: $finishWithReturn) {
                    Text("⌘Return").tag(false)
                    Text("Return").tag(true)
                }
            } header: {
                Text("Notes Column")
            } footer: {
                Text(finishWithReturn
                     ? "Shift-Return starts a new line. Escape or a click elsewhere also finishes."
                     : "Return starts a new line. Escape or a click elsewhere also finishes.")
            }
            #else
            // The phone has no column and no finishing key; the highlights setting reaches Notes in This Chapter.
            Section {
                Toggle("Show highlights without notes", isOn: $showNotelessHighlights)
            }
            #endif
            if let sync {
                ICloudSettingsSection(status: sync)
            }
            if let backups {
                BackupsSettingsSection(model: backups)
            }
            #if os(iOS)
            // The Mac has File › Export All Data… and Import Data…; the phone has no menu bar.
            if let data {
                DataSettingsSection(model: data)
            }
            #endif
        }
        .formStyle(.grouped)
    }
}

#if os(iOS)
/// Settings › General › Your Data on the phone: Export All Data… hands one file to the share sheet,
/// Import Data… reads one from Files and says in a line what it added; neither changes what is here.
struct DataSettingsSection: View {
    let model: DataTransferModel
    @State private var isChoosingFile = false
    /// Set when the export file could not be written; the next import's result replaces it.
    @State private var exportFailure: String?

    private static let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "export")

    static let footer = "Export All Data writes everything you have made to one file. Import Data adds what is missing from a file and changes nothing else."
    static let exportFailureText = "Your data could not be exported. Check that the phone has free space."

    private var resultText: String? { exportFailure ?? model.resultText }

    var body: some View {
        Section {
            Button("Export All Data…", action: export)
            Button("Import Data…") { isChoosingFile = true }
                .disabled(!model.canImport)
            if let resultText {
                Text(resultText)
                    .font(.callout)
                    .foregroundStyle(Color.inkSecondary)
            }
        } header: {
            Text("Your Data")
        } footer: {
            Text(model.canImport ? Self.footer : Self.footer + " " + DataTransferModel.importUnavailableText)
                .foregroundStyle(Color.inkSecondary)
        }
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.json]) { result in
            exportFailure = nil
            guard case let .success(url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            // A file that cannot be read is told as a damaged one.
            model.importData((try? Data(contentsOf: url)) ?? Data())
        }
        .onChange(of: resultText) { _, text in
            if let text { AccessibilityNotification.Announcement(text).post() }
        }
    }

    /// The file under the temporary directory's `Export` folder, conversations included, then the share sheet.
    private func export() {
        exportFailure = nil
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(DataTransferModel.fileName(on: Date()))
            try model.exportData(includesConversations: true).write(to: url, options: .atomic)
            PhoneShareSheet.present(url)
        } catch {
            Self.logger.error("Data export failed: \(error.localizedDescription, privacy: .public)")
            exportFailure = Self.exportFailureText
        }
    }
}
#endif
