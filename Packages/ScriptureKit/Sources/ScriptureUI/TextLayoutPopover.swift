import SwiftUI

/// The Mac toolbar's Text & Layout popover (`textformat.size`, ⌘T): every reading setting in one
/// place, each written straight to its `ReaderSettings` key, so the page changes as a control
/// moves; the size slider writes when its drag ends, so the book is re-laid out once. The same keys back Settings › Reading. System controls in semantic text styles; the
/// four page styles are tiles, each "Aa" in its own face, the chosen one on the accent wash.
public struct TextLayoutPopover: View {
    @AppStorage(ReaderSettings.pageStyleKey) private var pageStyle: PageStyle = .printed
    @AppStorage(ReaderSettings.pageFaceKey) private var pageFace = ""
    @AppStorage(ReaderSettings.fontSizeKey) private var fontSize = ReaderSettings.defaultFontSize
    @AppStorage(ReaderSettings.lineSpacingKey) private var lineSpacing: LineSpacingChoice = .normal
    @AppStorage(ReaderSettings.columnWidthKey) private var columnWidth: ColumnWidthChoice = .normal
    @AppStorage(ReaderSettings.verseLayoutKey) private var verseLayout: VerseLayoutChoice = .paragraphs
    @AppStorage(ReaderSettings.showsVerseNumbersKey) private var showsVerseNumbers = true
    @AppStorage(ReaderSettings.showsSectionHeadingsKey) private var showsSectionHeadings = true
    @AppStorage(ReaderSettings.justifiedKey) private var justified = false
    @AppStorage(ReaderSettings.appearanceKey) private var appearance: AppearanceChoice = .system
    /// The size slider's drag, written when it ends (`FontSizeSlider`).
    @State private var sizeDraft = SliderDraft()

    /// The popover's width, grown with the text inside it.
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 300

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Text & Layout")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
                .accessibilityAddTraits(.isHeader)
            group("Page style") {
                PageStyleTiles(selection: $pageStyle)
            }
            group("Font") {
                PageFaceMenu(selection: $pageFace)
                    .labelsHidden()
            }
            group("Size") {
                HStack(spacing: AppSpacing.xs) {
                    Text("A").font(.caption).accessibilityHidden(true)
                    FontSizeSlider(fontSize: $fontSize, draft: $sizeDraft)
                    Text("A").font(.title2).accessibilityHidden(true)
                }
                .foregroundStyle(Color.inkSecondary)
            }
            group("Line spacing") { segmented("Line spacing", $lineSpacing, LineSpacingChoice.allCases, \.title) }
            group("Column width") { segmented("Column width", $columnWidth, ColumnWidthChoice.allCases, \.title) }
            group("Layout") { segmented("Layout", $verseLayout, VerseLayoutChoice.allCases, \.title) }
            group("Show") {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Toggle("Verse numbers", isOn: $showsVerseNumbers)
                    Toggle("Section headings", isOn: $showsSectionHeadings)
                    Toggle("Justify text", isOn: $justified)
                }
            }
            // Ruling R3: every appearance the app has, so Sepia joins when it exists.
            group("Appearance") { segmented("Appearance", $appearance, AppearanceChoice.allCases, \.title) }
        }
        .font(.body)
        .padding(AppSpacing.md)
        .frame(width: width)
    }

    /// A titled group: the Label style of the type ladder over its control.
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func segmented<Choice: Hashable>(_ title: String, _ selection: Binding<Choice>, _ choices: [Choice],
                                             _ name: KeyPath<Choice, String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(choices, id: \.self) { choice in
                Text(choice[keyPath: name]).tag(choice)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

/// The four page styles as a row of tiles; shared by the popover and Settings › Reading.
///
/// One keyboard stop, as a segmented control is: the focus ring goes round the row, never a single
/// tile, so it cannot read as a second selection beside the wash, and the arrow keys choose.
struct PageStyleTiles: View {
    @Binding var selection: PageStyle

    var body: some View {
        tiles
        #if os(macOS)
            .focusable()
        .contentShape(.focusEffect, RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .onMoveCommand { direction in
            let styles = PageStyle.allCases
            guard let index = styles.firstIndex(of: selection) else { return }
            switch direction {
            case .left where index > styles.startIndex: selection = styles[index - 1]
            case .right where index < styles.index(before: styles.endIndex): selection = styles[index + 1]
            default: break
            }
        }
        .accessibilityElement(children: .contain)
        #endif
    }

    private var tiles: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(PageStyle.allCases, id: \.self) { style in
                StyleTile(style: style, isSelected: style == selection) { selection = style }
            }
        }
    }
}

/// The Font menu: the style's own font ("" in the key) or one of the available faces.
struct PageFaceMenu: View {
    @Binding var selection: String

    var body: some View {
        Picker("Font", selection: $selection) {
            Text("The style's font").tag("")
            Divider()
            ForEach(PageFace.available, id: \.self) { face in
                Text(face.title).tag(face.rawValue)
            }
        }
        .pickerStyle(.menu)
    }
}

/// One page style as a tile: "Aa" in the style's face over its name. A step in the paper at rest
/// and the accent wash when chosen; no stroke, as the prompt tiles.
private struct StyleTile: View {
    let style: PageStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xxs) {
                Text("Aa")
                    .font(style.defaultFace.swiftUIFont(.title2))
                    .foregroundStyle(Color.inkPrimary)
                Text(style.title)
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, AppSpacing.xs)
            .frame(maxWidth: .infinity)
            .background(shape.fill(isSelected ? Color.accentWash : Color.paperOverlay))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        // The row is the keyboard stop (`PageStyleTiles`).
        .focusable(false)
        #endif
        .help(style.title)
        .accessibilityLabel(style.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
    }
}
