#if os(macOS)
import AppKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// The save panel for File › Export Notes… and the Notes browser's Export: the system panel with
/// a Layout picker (One file, One file per book) and an Include conversations toggle beneath it,
/// both remembered in the defaults. `render` builds the Markdown for the options chosen.
@MainActor
public enum ExportPanel {
    public static let layoutKey = "exportLayout"
    public static let includesConversationsKey = "exportIncludesConversations"

    private static let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "export")

    /// One file with conversations, until the reader chooses otherwise.
    public static func options(from defaults: UserDefaults) -> MarkdownExport.Options {
        MarkdownExport.Options(
            layout: defaults.string(forKey: layoutKey).flatMap(MarkdownExport.Layout.init(rawValue:)) ?? .singleFile,
            includesConversations: defaults.object(forKey: includesConversationsKey) as? Bool ?? true)
    }

    public static func remember(_ options: MarkdownExport.Options, in defaults: UserDefaults) {
        defaults.set(options.layout.rawValue, forKey: layoutKey)
        defaults.set(options.includesConversations, forKey: includesConversationsKey)
    }

    /// A sheet on `window` (or a free panel without one), named from a first render. OK writes the
    /// file, or the folder with a README and one file per book; a failure shows one alert.
    public static func present(in window: NSWindow?, defaults: UserDefaults = .standard, render: @escaping (MarkdownExport.Options) throws -> MarkdownExport.Output) {
        // While a sheet is up (this panel, an alert) the key window is that sheet: a second ⇧⌘E
        // would stack a panel on the panel, so it does nothing.
        guard window?.sheetParent == nil, window?.attachedSheet == nil else { return }
        let choice = ExportChoice(options(from: defaults))
        let first: MarkdownExport.Output
        do {
            first = try render(choice.options)
        } catch {
            fail(error, in: window)
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = first.name
        panel.allowedContentTypes = contentTypes(for: choice.layout)
        // Its own SwiftUI root, so it takes the app's Sepia itself.
        let accessory = NSHostingView(rootView: ExportPanelAccessory(choice: choice).followsSepia())
        accessory.setFrameSize(accessory.fittingSize)
        panel.accessoryView = accessory
        choice.onLayoutChange = { [weak panel] layout in
            guard let panel else { return }
            panel.allowedContentTypes = contentTypes(for: layout)
            panel.nameFieldStringValue = name(panel.nameFieldStringValue, for: layout)
        }

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            let options = choice.options
            do {
                try write(render(options), layout: options.layout, to: url)
            } catch {
                fail(error, in: window)
            }
            remember(options, in: defaults)
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            panel.begin(completionHandler: finish)
        }
    }

    /// The single file as written; the folder built beside the destination and moved into place,
    /// replacing one already there (the panel has asked), so no file from an earlier export lingers.
    static func write(_ output: MarkdownExport.Output, layout: MarkdownExport.Layout, to url: URL) throws {
        switch layout {
        case .singleFile:
            try (output.files.first?.text ?? "").write(to: url, atomically: true, encoding: .utf8)
        case .folderPerBook:
            let manager = FileManager.default
            let staging = try manager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: url, create: true)
            defer { try? manager.removeItem(at: staging) }
            let folder = staging.appendingPathComponent(url.lastPathComponent, isDirectory: true)
            try manager.createDirectory(at: folder, withIntermediateDirectories: false)
            for file in output.files {
                try file.text.write(to: folder.appendingPathComponent(file.relativePath), atomically: false, encoding: .utf8)
            }
            if manager.fileExists(atPath: url.path) {
                _ = try manager.replaceItemAt(url, withItemAt: folder)
            } else {
                try manager.moveItem(at: folder, to: url)
            }
        }
    }

    private static func contentTypes(for layout: MarkdownExport.Layout) -> [UTType] {
        layout == .singleFile ? [.plainText] : []
    }

    /// The name as the reader left it, with `.md` for one file and without it for a folder.
    private static func name(_ name: String, for layout: MarkdownExport.Layout) -> String {
        let bare = name.hasSuffix(".md") ? String(name.dropLast(3)) : name
        return layout == .singleFile ? bare + ".md" : bare
    }

    private static func fail(_ error: Error, in window: NSWindow?) {
        logger.error("Export failed: \(error)")
        let alert = NSAlert()
        alert.messageText = "The notes could not be exported."
        alert.informativeText = "Choose another place to save them, or check that the disk has free space."
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}

/// The panel's two choices; a layout change renames the file and changes what it may be saved as.
@Observable @MainActor
final class ExportChoice {
    var layout: MarkdownExport.Layout {
        didSet { if layout != oldValue { onLayoutChange?(layout) } }
    }
    var includesConversations: Bool
    @ObservationIgnored var onLayoutChange: ((MarkdownExport.Layout) -> Void)?

    init(_ options: MarkdownExport.Options) {
        layout = options.layout
        includesConversations = options.includesConversations
    }

    var options: MarkdownExport.Options {
        MarkdownExport.Options(layout: layout, includesConversations: includesConversations)
    }
}

/// System controls in the panel's own type: a Layout pop-up and a checkbox.
private struct ExportPanelAccessory: View {
    @Bindable var choice: ExportChoice

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Picker("Layout", selection: $choice.layout) {
                Text("One file").tag(MarkdownExport.Layout.singleFile)
                Text("One file per book").tag(MarkdownExport.Layout.folderPerBook)
            }
            .fixedSize()
            Toggle("Include conversations", isOn: $choice.includesConversations)
        }
        .font(.body)
        .padding(AppSpacing.md)
    }
}
#endif
