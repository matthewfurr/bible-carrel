import SwiftUI

/// Settings → Reading: page style, font, size, spacing, layout, visibility and appearance. Every
/// control writes its `ReaderSettings` key (the same keys the Mac's Text & Layout popover uses),
/// so the open reader changes at once; the size slider writes when its drag ends.
public struct ReadingSettingsView: View {
    /// The Section headings footer: the headings come from the BSB whatever the translation.
    static let headingsFooter = "Headings from the Berean Standard Bible."

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
    @ScaledMetric(relativeTo: .body) private var valueWidth: CGFloat = 40
    /// The size slider's drag, written when it ends (`FontSizeSlider`); the label follows it.
    @State private var sizeDraft = SliderDraft()

    public init() {}

    public var body: some View {
        Form {
            Section("Page") {
                PageStyleTiles(selection: $pageStyle)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Page style")
                LabeledContent("Font") {
                    PageFaceMenu(selection: $pageFace)
                        .labelsHidden()
                }
            }
            Section("Text") {
                LabeledContent("Size") {
                    HStack(spacing: AppSpacing.xs) {
                        FontSizeSlider(fontSize: $fontSize, draft: $sizeDraft)
                            .frame(maxWidth: 220)
                        Text("\(Int(ReaderSettings.clampedFontSize(sizeDraft.shown(fontSize)))) pt")
                            .monospacedDigit()
                            .foregroundStyle(Color.inkSecondary)
                            .frame(minWidth: valueWidth, alignment: .trailing)
                    }
                }
                segmented("Line spacing", $lineSpacing, LineSpacingChoice.allCases, \.title)
                #if os(macOS)
                segmented("Column width", $columnWidth, ColumnWidthChoice.allCases, \.title)
                #endif
            }
            Section {
                segmented("Layout", $verseLayout, VerseLayoutChoice.allCases, \.title)
                Toggle("Verse numbers", isOn: $showsVerseNumbers)
                Toggle("Section headings", isOn: $showsSectionHeadings)
                Toggle("Justify text", isOn: $justified)
            } header: {
                Text("Layout")
            } footer: {
                Text(Self.headingsFooter)
            }
            Section("Appearance") {
                // Ruling R3: every appearance the app has, so Sepia joins when it exists.
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearanceChoice.allCases, id: \.self) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }

    /// A segmented row. An iOS form draws a segmented picker without its title, so the row
    /// carries it; the Mac's grouped form shows the picker's own label.
    @ViewBuilder
    private func segmented<Choice: Hashable>(_ title: String, _ selection: Binding<Choice>, _ choices: [Choice],
                                             _ name: KeyPath<Choice, String>) -> some View {
        let picker = Picker(title, selection: selection) {
            ForEach(choices, id: \.self) { choice in
                Text(choice[keyPath: name]).tag(choice)
            }
        }
        .pickerStyle(.segmented)
        #if os(macOS)
        picker
        #else
        LabeledContent(title) { picker.labelsHidden() }
        #endif
    }
}
