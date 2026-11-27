#if os(macOS)
import AppKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// The panels for File › Export All Data… and Import Data…: a save panel named for the day with
/// an Include conversations toggle beneath it, and an open panel whose result is told in an alert.
@MainActor
public enum DataPanels {
    private static let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "export")

    /// A sheet on `window` (or a free panel without one). OK writes the file; a failure shows one alert.
    /// Does nothing while the window has a sheet (this panel, an alert), as `ExportPanel.present` does.
    public static func presentExport(in window: NSWindow?, model: DataTransferModel, defaults: UserDefaults = .standard) {
        guard window?.sheetParent == nil, window?.attachedSheet == nil else { return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = DataTransferModel.fileName(on: Date())
        panel.allowedContentTypes = [.json]
        // Its own SwiftUI root, so it takes the app's Sepia itself.
        let accessory = NSHostingView(rootView: DataPanelAccessory(defaults: defaults).followsSepia())
        accessory.setFrameSize(accessory.fittingSize)
        panel.accessoryView = accessory

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            let includes = defaults.object(forKey: ExportPanel.includesConversationsKey) as? Bool ?? true
            do {
                try model.exportData(includesConversations: includes).write(to: url, options: .atomic)
            } catch {
                logger.error("Data export failed: \(error.localizedDescription, privacy: .public)")
                alert(
                    "Your data could not be exported.", "Choose another place to save it, or check that the disk has free space.",
                    in: window)
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            panel.begin(completionHandler: finish)
        }
    }

    /// The open panel for one `.json` file; its data goes to the model, and the sentence it ends
    /// with is shown as an alert on the window.
    public static func presentImport(in window: NSWindow?, model: DataTransferModel) {
        guard window?.sheetParent == nil, window?.attachedSheet == nil else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            // A file that cannot be read is told as a damaged one.
            model.importData((try? Data(contentsOf: url)) ?? Data())
            if let text = model.resultText { alert(text, nil, in: window) }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            panel.begin(completionHandler: finish)
        }
    }

    private static func alert(_ message: String, _ detail: String?, in window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = message
        if let detail { alert.informativeText = detail }
        alert.addButton(withTitle: "OK")
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}

/// The save panel's one choice, remembered with the Markdown export's own.
struct DataPanelAccessory: View {
    let defaults: UserDefaults
    @State private var includesConversations: Bool

    init(defaults: UserDefaults) {
        self.defaults = defaults
        _includesConversations = State(initialValue: defaults.object(forKey: ExportPanel.includesConversationsKey) as? Bool ?? true)
    }

    var body: some View {
        let binding = Binding(
            get: { includesConversations },
            set: { includesConversations = $0; defaults.set($0, forKey: ExportPanel.includesConversationsKey) })
        Toggle("Include conversations", isOn: binding)
            .font(.body)
            .padding(AppSpacing.md)
    }
}
#endif
