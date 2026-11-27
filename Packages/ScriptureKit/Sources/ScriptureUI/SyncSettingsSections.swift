import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Settings › General › iCloud: the one sentence of sync status, kept true by the minute, and a
/// way to System Settings when the Mac is not signed in.
struct ICloudSettingsSection: View {
    let status: SyncStatusModel
    @Environment(\.openURL) private var openURL

    /// The Apple Account pane of System Settings.
    static let accountSettingsURL = URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings")!

    var body: some View {
        Section {
            // The relative time ("Synced 5 minutes ago") is read from the clock, so redraw each minute.
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                HStack(spacing: AppSpacing.sm) {
                    Label {
                        Text(status.statusText)
                            .foregroundStyle(Color.inkPrimary)
                    } icon: {
                        Image(systemName: status.symbolName)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .font(.body)
                    // One sentence to VoiceOver, read as text, without the symbol's name.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(status.statusText)
                    .accessibilityAddTraits(.isStaticText)
                    // System Settings' Apple Account pane has no URL an iPhone app may open.
                    #if os(macOS)
                    if status.state == .noAccount {
                        Spacer(minLength: AppSpacing.xs)
                        Button("Open iCloud Settings") { openURL(Self.accountSettingsURL) }
                            .buttonStyle(.bordered)
                    }
                    #endif
                }
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text("Highlights, notes, bookmarks, conversations, prompts and colors sync through your private iCloud. Text size and appearance stay with each device.")
                .foregroundStyle(Color.inkSecondary)
        }
    }
}

/// Settings › General › Backups: when the last daily copy was taken, the file in Finder, and
/// Restore, which brings back what a backup has and the store lacks without asking first,
/// because it never changes or deletes anything.
struct BackupsSettingsSection: View {
    let model: BackupsModel

    static func footer(device: String = DeviceName.current) -> String {
        "A copy of your notes is kept on this \(device) each day, for seven days. Restore brings back anything that is missing and changes nothing else."
    }

    var body: some View {
        Section {
            LabeledContent("Last backup") {
                Group {
                    if let date = model.lastBackup {
                        Text(date, format: .dateTime.weekday(.wide).hour().minute())
                    } else {
                        Text("None yet")
                    }
                }
                .foregroundStyle(Color.inkSecondary)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    #if os(macOS)
                    Button("Show in Finder", action: showInFinder)
                        .buttonStyle(.bordered)
                    Button("Restore…", action: chooseBackup)
                        .buttonStyle(.bordered)
                        // Until iCloud has brought the notes back, a restore would duplicate them.
                        .disabled(!model.canRestore)
                    #else
                    // No open panel on the phone, and Files cannot see the app's backups: one item per day kept.
                    Menu("Restore…") {
                        ForEach(model.allBackups, id: \.url) { backup in
                            Button { model.restore(from: backup.url) } label: { Self.dayText(backup.day) }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.canRestore || model.lastBackup == nil)
                    #endif
                }
                if let result = model.resultText {
                    Text(result)
                        .font(.callout)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        } header: {
            Text("Backups")
        } footer: {
            Text(model.canRestore ? Self.footer() : Self.footer() + " " + BackupsModel.restoreUnavailableText)
                .foregroundStyle(Color.inkSecondary)
        }
        .onAppear { model.refresh() }
        .onChange(of: model.resultText) { _, text in
            if let text { AccessibilityNotification.Announcement(text).post() }
        }
    }

    #if !os(macOS)
    /// A backup's `yyyy-MM-dd` as its weekday and date, or as named when it does not parse.
    static func dayText(_ day: String) -> Text {
        if let date = try? Date(day, strategy: Date.ISO8601FormatStyle(timeZone: .current).year().month().day()) {
            return Text(date, format: .dateTime.weekday(.wide).month().day())
        }
        return Text(day)
    }
    #endif

    /// Selects the newest backup in Finder, or opens the folder when there is none.
    private func showInFinder() {
        #if os(macOS)
        if let newest = model.newestBackup {
            NSWorkspace.shared.activateFileViewerSelecting([newest])
        } else {
            NSWorkspace.shared.open(model.backupsDirectory)
        }
        #endif
    }

    /// One file, chosen in an open panel that starts in the backups folder.
    private func chooseBackup() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.directoryURL = model.backupsDirectory
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        let restore: (NSApplication.ModalResponse) -> Void = { [model] response in
            guard response == .OK, let url = panel.url else { return }
            model.restore(from: url)
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: restore)
        } else {
            panel.begin(completionHandler: restore)
        }
        #endif
    }
}

/// The main window's quiet notice, shown only while sync has failed for a day: the symbol in
/// secondary ink, never red and never the accent. Its action opens Settings › General.
public struct SyncAttentionButton: View {
    let status: SyncStatusModel
    let action: () -> Void

    public init(status: SyncStatusModel, action: @escaping () -> Void) {
        self.status = status
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label {
                Text("iCloud")
            } icon: {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .help(status.attentionHelp)
    }
}
