#if os(macOS)
import SwiftUI

/// The Mac's list of every keyboard shortcut, from `ShortcutCatalog`: a title with a filter field,
/// three columns of groups, and a foot with Done. Presented by `.sheet`, so it takes the window's
/// Sepia and page face from the environment.
public struct ShortcutsSheet: View {
    @State private var query = ""
    @FocusState private var isFilterFocused: Bool
    @ScaledMetric(relativeTo: .callout) private var columnWidth: CGFloat = 220
    @ScaledMetric(relativeTo: .callout) private var filterWidth: CGFloat = 180
    /// The columns' room, so the sheet keeps its size while the filter narrows the rows.
    @ScaledMetric(relativeTo: .callout) private var columnsHeight: CGFloat = 340

    let onDone: () -> Void

    public init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    private var columns: [[ShortcutGroup]] { ShortcutCatalog.columns(ShortcutCatalog.filtered(query)) }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.md) {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                    .foregroundStyle(Color.inkPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: AppSpacing.md)
                TextField("Filter", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: filterWidth)
                    .focused($isFilterFocused)
            }
            Group {
                if columns.isEmpty {
                    Text("No shortcut matches “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”.")
                        .font(.callout)
                        .foregroundStyle(Color.inkSecondary)
                } else {
                    HStack(alignment: .top, spacing: AppSpacing.lg) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { _, groups in
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                ForEach(groups) { group in
                                    ShortcutGroupView(group: group)
                                }
                            }
                            .frame(width: columnWidth, alignment: .topLeading)
                        }
                    }
                }
            }
            .frame(minWidth: columnWidth * 3 + AppSpacing.lg * 2, maxWidth: .infinity, minHeight: columnsHeight, alignment: .topLeading)
            HStack {
                Text("Press ⌘/ any time to see this.")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.paperPanel)
        .onExitCommand(perform: onDone)
        .onAppear { isFilterFocused = true }
    }
}

/// One group: its name as a header over its rows.
private struct ShortcutGroupView: View {
    let group: ShortcutGroup

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(group.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(group.shortcuts) { shortcut in
                ShortcutRow(shortcut: shortcut)
            }
        }
    }
}

/// A row: its label, with its keys as keycaps at the trailing end. One element for VoiceOver.
private struct ShortcutRow: View {
    let shortcut: Shortcut

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            Text(shortcut.label)
                .font(.callout)
                .foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            KeycapRow(shortcut.keys)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shortcut.accessibilityLabel)
    }
}
#endif
