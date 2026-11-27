import ScriptureData
import SwiftUI

/// The links of `verse`, which the chevrons move. `showsPassageInPlace` swaps the list for the
/// passage (the Mac's popover); without it `onShowPassage` is called (the phone pushes it).
/// Spec 5.2: the reference with its chevrons, then "This verse points to" and "Verses that point
/// here", each strongest first, six of four votes or more and Show all.
public struct CrossReferencesPanel: View {
    let showsPassageInPlace: Bool
    let navigation: NavigationModel
    let onShowPassage: (Reference) -> Void
    let onOpen: (Reference) -> Void
    /// Ask About These, for the panel's foot (spec 5.3).
    let onAsk: ((CrossReferences) -> Void)?

    /// The verse shown: the selection's first, then wherever the chevrons have walked.
    @State private var verse: VerseLocation
    /// The groups whose every link is listed (Show all), by title; a new verse starts short.
    @State private var expanded: Set<String> = []
    /// The passage shown in place of the list (Mac), until the reader goes back.
    @State private var passage: Reference?
    @Environment(\.pageFace) private var pageFace
    @ScaledMetric(relativeTo: .callout) private var rowInset: CGFloat = AppSpacing.xs

    public init(verse: VerseLocation, navigation: NavigationModel, showsPassageInPlace: Bool,
                onShowPassage: @escaping (Reference) -> Void = { _ in },
                onOpen: @escaping (Reference) -> Void, onAsk: ((CrossReferences) -> Void)?) {
        _verse = State(initialValue: verse)
        self.navigation = navigation
        self.showsPassageInPlace = showsPassageInPlace
        self.onShowPassage = onShowPassage
        self.onOpen = onOpen
        self.onAsk = onAsk
    }


    public var body: some View {
        let references = navigation.crossReferences(for: verse)
        VersePanelLayout(scrolls: passage == nil) {
            header(references)
        } middle: {
            if let passage {
                passageInPlace(passage)
            } else {
                list(references)
            }
        } foot: {
            foot(references)
        }
        .onChange(of: verse) { _, _ in
            expanded = []
            passage = nil
        }
    }

    // MARK: - Foot

    /// Ask About These, then the credit to the data's source, on one line (spec 5.3, 5.4). When the
    /// line does not fit (large text sizes) the two stack and wrap; the credit is never dropped.
    private func foot(_ references: CrossReferences?) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) {
                askButton(references)
                    .fixedSize()
                Spacer(minLength: 0)
                creditLink
            }
            .lineLimit(1)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                askButton(references)
                    .fixedSize(horizontal: false, vertical: true)
                creditLink
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
        .padding(.horizontal, rowInset)
    }

    @ViewBuilder
    private func askButton(_ references: CrossReferences?) -> some View {
        if let onAsk {
            Button { if let references { onAsk(references) } } label: {
                Label("Ask About These", systemImage: "sparkles")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.assistant)
            .disabled(!(references?.canAsk ?? false))
        }
    }

    private var creditLink: some View {
        Link(CrossReferences.credit, destination: CrossReferences.creditLink)
            .font(.caption)
            .foregroundStyle(Color.inkSecondary)
    }

    // MARK: - Header

    private func header(_ references: CrossReferences?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
            Text(references?.reference.displayString ?? fallbackTitle)
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer(minLength: AppSpacing.xs)
            step("Previous verse", symbol: "chevron.up", to: references?.previous)
            step("Next verse", symbol: "chevron.down", to: references?.next)
        }
        .padding(.leading, rowInset)
    }

    private var fallbackTitle: String {
        BookCatalog.book(code: verse.book).map { Reference(book: $0, chapter: verse.chapter, verse: verse.verse).displayString } ?? ""
    }

    private func step(_ title: String, symbol: String, to target: VerseLocation?) -> some View {
        RowSymbolButton(title: title, symbol: symbol) {
            if let target { verse = target }
        }
        .disabled(target == nil)
    }

    // MARK: - The list

    @ViewBuilder
    private func list(_ references: CrossReferences?) -> some View {
        if let references, !references.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                group(CrossReferences.pointsToTitle, references.pointsTo)
                group(CrossReferences.pointsHereTitle, references.pointsHere)
            }
        } else {
            Text(CrossReferences.emptyLine)
                .font(.callout)
                .foregroundStyle(Color.inkSecondary)
                .padding(.horizontal, rowInset)
        }
    }

    /// Its title and count, the short list (or every link once Show all is chosen), then Show all.
    /// A group with no link is left out.
    @ViewBuilder
    private func group(_ title: String, _ group: CrossReferences.Group) -> some View {
        if !group.all.isEmpty {
            let isExpanded = expanded.contains(title)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text(title)
                    Spacer(minLength: AppSpacing.xs)
                    Text(group.count, format: .number)
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .padding(.horizontal, rowInset)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                ForEach(isExpanded ? group.all : group.short) { row in
                    if row.canOpen {
                        rowContent(row)
                            .versePanelRowAction { show(row.reference) }
                    } else {
                        rowContent(row)
                    }
                }
                if group.showsShowAll && !isExpanded {
                    Button(group.showAllTitle) { expanded.insert(title) }
                        .buttonStyle(.plain)
                        .font(.callout)
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, rowInset)
                }
            }
        }
    }

    /// The passage's reference over its opening words, one line.
    private func rowContent(_ row: CrossReferences.Row) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(row.reference.displayString)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.inkPrimary)
            if let opening = row.opening {
                Text(opening)
                    .font(pageFace.quoteFont())
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, rowInset)
        .padding(.vertical, AppSpacing.xxs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private func show(_ reference: Reference) {
        if showsPassageInPlace {
            passage = reference
        } else {
            onShowPassage(reference)
        }
    }

    // MARK: - A passage in place

    /// "Cross-References" back to the list, then the passage's verses with Open, as a reference
    /// in a note shows them.
    private func passageInPlace(_ reference: Reference) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Button { passage = nil } label: {
                Label("Cross-References", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(Color.accent)
            .padding(.horizontal, rowInset)
            if let preview = navigation.versePreview(reference) {
                VersePreviewView(preview: preview, openTitle: "Open") { onOpen(reference) }
            } else {
                Text(reference.displayString)
                    .font(.callout)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, rowInset)
            }
        }
    }
}
