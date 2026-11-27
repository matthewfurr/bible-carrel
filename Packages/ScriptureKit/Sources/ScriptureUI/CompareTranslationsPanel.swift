import ScriptureData
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The comparison of `selection`, read again when the compare set or the translation changes.
/// Spec 4.2: the reference and how many translations, then a row per translation (the one being
/// read first, on the wash), then Ask About the Differences, Copy and Translations….
public struct CompareTranslationsPanel: View {
    let selection: TextSelection
    let navigation: NavigationModel
    /// A row that has its verses, clicked; the panel closes, and only a row that `looksUp` is looked up.
    let onOpen: (VerseComparison.Row) -> Void
    let onAsk: ((VerseComparison) -> Void)?

    @AppStorage(CompareSet.key) private var compareSet = CompareSet.defaultValue
    @Environment(\.pageFace) private var pageFace
    /// When Copy last put the rows on the pasteboard; it reads "Copied" for a moment after.
    @State private var copiedAt: Date?
    @ScaledMetric(relativeTo: .callout) private var rowInset: CGFloat = AppSpacing.xs

    public init(selection: TextSelection, navigation: NavigationModel,
                onOpen: @escaping (VerseComparison.Row) -> Void, onAsk: ((VerseComparison) -> Void)?) {
        self.selection = selection
        self.navigation = navigation
        self.onOpen = onOpen
        self.onAsk = onAsk
    }

    public var body: some View {
        // Read on each change of the set (`@AppStorage`) or the translation (`NavigationModel` is observed).
        let comparison = navigation.verseComparison(for: selection, compareSet: CompareSet.ids(compareSet))
        VersePanelLayout {
            header(comparison)
        } middle: {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(comparison?.rows ?? []) { row in
                    if row.canOpen {
                        rowContent(row)
                            .versePanelRowAction { onOpen(row) }
                    } else {
                        rowContent(row)
                    }
                }
            }
        } foot: {
            if let comparison { foot(comparison) }
        }
    }

    private func header(_ comparison: VerseComparison?) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // The count sits beside the title, or under it when the two do not fit on a line.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    title(comparison).fixedSize()
                    Spacer(minLength: AppSpacing.xs)
                    count(comparison).fixedSize()
                }
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    title(comparison).fixedSize(horizontal: false, vertical: true)
                    count(comparison).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let cutLine = comparison?.cutLine {
                Text(cutLine)
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.horizontal, rowInset)
    }

    private func title(_ comparison: VerseComparison?) -> some View {
        Text(comparison?.reference.displayString ?? selection.referenceString)
            .font(.headline)
            .foregroundStyle(Color.inkPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func count(_ comparison: VerseComparison?) -> some View {
        if let comparison {
            Text(comparison.countLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.inkSecondary)
        }
    }

    /// The short name (and "reading"), then the verses as prose, or the line saying they are missing;
    /// the CPDV's line in Psalms under them. The row being read is on the wash.
    private func rowContent(_ row: VerseComparison.Row) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
                Text(row.translationID)
                    .font(.caption.weight(.semibold))
                if row.isReading {
                    Text("reading")
                        .font(.caption)
                }
            }
            .foregroundStyle(Color.inkSecondary)
            if let missing = row.missingLine {
                Text(missing)
                    .font(.callout)
                    .foregroundStyle(Color.inkSecondary)
            } else {
                Text(row.text)
                    .font(pageFace.swiftUIFont(.callout))
                    .foregroundStyle(Color.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = row.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(rowInset)
        .background {
            if row.isReading {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous).fill(Color.accentWash)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    /// One line when it fits; at large text sizes the three controls stack, a label wrapping
    /// rather than overflowing.
    private func foot(_ comparison: VerseComparison) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) {
                askButton(comparison)
                    .fixedSize()
                copyButton(comparison)
                Spacer(minLength: 0)
                translationsMenu
                    .fixedSize()
            }
            .lineLimit(1)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                askButton(comparison)
                    .fixedSize(horizontal: false, vertical: true)
                copyButton(comparison)
                translationsMenu
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
        .padding(.horizontal, rowInset)
    }

    @ViewBuilder
    private func askButton(_ comparison: VerseComparison) -> some View {
        if let onAsk {
            Button { onAsk(comparison) } label: {
                Label("Ask About the Differences", systemImage: "sparkles")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.assistant)
            .disabled(!comparison.canAsk)
        }
    }

    // The symbol alone, as Copy is on an assistant's reply.
    private func copyButton(_ comparison: VerseComparison) -> some View {
        RowSymbolButton(title: copiedAt == nil ? "Copy" : "Copied", symbol: copiedAt == nil ? "doc.on.doc" : "checkmark") {
            copy(comparison)
        }
    }

    private var translationsMenu: some View {
        Menu("Translations…") {
            CompareSetToggles(translations: navigation.translations)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .foregroundStyle(Color.inkSecondary)
    }

    /// Every row that has the verses, as Copy with Reference writes it, one to a line; it reads
    /// "Copied" for a moment and VoiceOver hears it.
    private func copy(_ comparison: VerseComparison) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(comparison.copyText, forType: .string)
        #else
        UIPasteboard.general.string = comparison.copyText
        #endif
        let now = Date()
        copiedAt = now
        AccessibilityNotification.Announcement("Copied").post()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if copiedAt == now { copiedAt = nil }
        }
    }
}
