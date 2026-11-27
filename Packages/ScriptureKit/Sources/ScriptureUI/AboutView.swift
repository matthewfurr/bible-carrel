import SwiftUI

/// Settings › About, one view for both apps: a colophon. The app's name as a page title with its version
/// under it, then every outside source from `Credits` as one line in one of three sections. A line is
/// the source's name, what the app uses it for and its licence; it opens in place to the holder's notice,
/// the link and the licence's text or link. A plain scrolling page, no card, no fill of its own on the Mac.
public struct AboutView: View {
    private let info: [String: Any]?
    /// The credit ids whose lines, and whose "Licence text", start open: the seeds of each line's
    /// `@State`, for renders; the page opens with every line closed and remembers nothing.
    let initiallyOpened: Set<String>
    let initiallyLicenceOpened: Set<String>
    @ScaledMetric(relativeTo: .body) private var maxWidth: CGFloat = 520

    public init(info: [String: Any]? = Bundle.main.infoDictionary) {
        self.init(info: info, opened: [], licenceOpened: [])
    }

    init(info: [String: Any]?, opened: Set<String>, licenceOpened: Set<String>) {
        self.info = info
        initiallyOpened = opened
        initiallyLicenceOpened = licenceOpened
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    LibraryPageTitle(Self.appName(info: info), subtitle: nil)
                    Text(Self.versionLine(info: info))
                        .font(.callout)
                        .foregroundStyle(Color.inkSecondary)
                }
                .padding(.horizontal, AppSpacing.sm)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                ForEach(Self.page(), id: \.title) { section in
                    GroupLabel(section.title)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, AppSpacing.xxs)
                        .padding(.horizontal, AppSpacing.sm)
                    ForEach(section.lines, id: \.credit.id) { line in
                        CreditLineView(
                            line: line,
                            startsOpen: initiallyOpened.contains(line.credit.id),
                            licenceStartsOpen: initiallyLicenceOpened.contains(line.credit.id)
                        )
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: maxWidth, alignment: .leading)
            // Centred in the Settings window, as the other tabs' grouped forms are (Matt, 2026-11-24).
            .frame(maxWidth: .infinity, alignment: .center)
        }
        #if os(iOS)
        .background(Color.paperPage)
        #endif
    }

    /// What the page draws, section by section: each section's title and its lines in the catalogue's order.
    nonisolated static func page() -> [(title: String, lines: [CreditLine])] {
        Credit.Section.allCases.map { section in
            (title: section.rawValue, lines: Credits.entries(in: section).map { CreditLine(credit: $0) })
        }
    }

    /// `CFBundleDisplayName`, else `CFBundleName`, else "Bible Carrel".
    nonisolated static func appName(info: [String: Any]?) -> String {
        (info?["CFBundleDisplayName"] as? String) ?? (info?["CFBundleName"] as? String) ?? "Bible Carrel"
    }

    /// "Version 0.2 (1)": `CFBundleShortVersionString` and `CFBundleVersion`.
    nonisolated static func versionLine(info: [String: Any]?) -> String {
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (version?, build?): return "Version \(version) (\(build))"
        case let (version?, nil): return "Version \(version)"
        case let (nil, build?): return "Build \(build)"
        case (nil, nil): return "Version unknown"
        }
    }
}

/// One source as a line: a chevron, the name, the use after a dot and the licence trailing (under the name
/// when the row is too narrow for one line). The whole line is a button that opens its notice, link and
/// licence in place, on a tonal fill that starts under the line; several lines may be open at once.
private struct CreditLineView: View {
    let line: CreditLine
    @State private var isOpen: Bool
    @State private var licenceOpen: Bool
    /// The opened block's opacity: it fades in after it is added, never animating its frame.
    @State private var blockShown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var chevronWidth: CGFloat = 12

    init(line: CreditLine, startsOpen: Bool, licenceStartsOpen: Bool) {
        self.line = line
        _isOpen = State(initialValue: startsOpen)
        _licenceOpen = State(initialValue: licenceStartsOpen)
        _blockShown = State(initialValue: startsOpen)
    }

    /// The opened block's fill. The Mac's Settings window is white in Light, where `paper.overlay` shows
    /// no step, so the Mac takes `paper.panel`; the phone's page is `paper.page`, under `paper.overlay`.
    #if os(macOS)
    private static let openedFill = Color.paperPanel
    #else
    private static let openedFill = Color.paperOverlay
    #endif

    /// The line keeps its padding open or closed, so its name never moves; the block sits under it on
    /// its own fill, `xxs` below the line so the line's focus ring and the fill never cross.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(line.spoken)
                .accessibilityValue(line.value(isOpen: isOpen))
                .versePanelRowAction(toggleLine)
            if isOpen {
                block
                    .padding(.leading, chevronWidth + AppSpacing.xs)
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Self.openedFill, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    .padding(.top, AppSpacing.xxs)
                    .padding(.bottom, AppSpacing.xs)
                    .opacity(blockShown ? 1 : 0)
                    .animation(reduceMotion ? nil : .snappy, value: blockShown)
                    .onAppear { blockShown = true }
            }
        }
    }

    private func toggleLine() {
        isOpen.toggle()
        if !isOpen { blockShown = false }
    }

    /// The closed line: on one line when it fits, else the licence under the name.
    private var heading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                chevron(isOpen)
                nameAndUse.lineLimit(1).fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: AppSpacing.xs)
                licence.lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                chevron(isOpen)
                VStack(alignment: .leading, spacing: 0) {
                    nameAndUse
                    licence
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// A disclosure's chevron in its scaled column, turned down while open (`.snappy`, a cut under Reduce Motion).
    private func chevron(_ open: Bool) -> some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(Color.inkTertiary)
            .accessibilityLabel(open ? "Collapse" : "Expand")
            .animation(reduceMotion ? nil : .snappy) { symbol in
                symbol.rotationEffect(.degrees(open ? 90 : 0))
            }
            .frame(width: chevronWidth)
    }

    private var nameAndUse: Text {
        let name = Text(line.name).font(.body).foregroundStyle(Color.inkPrimary)
        guard let afterName = line.afterName else { return name }
        let after = Text(afterName).font(.callout).foregroundStyle(Color.inkSecondary)
        return Text("\(name)\(after)")
    }

    private var licence: Text {
        Text(line.licence).font(.callout).foregroundStyle(Color.inkSecondary)
    }

    /// The opened line's notice, link and licence.
    private var block: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ForEach(Array(line.opened.enumerated()), id: \.offset) { _, part in
                switch part {
                case let .notice(text):
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(Color.inkSecondary)
                        .textSelection(.enabled)
                case let .link(address, url):
                    Link(destination: url) {
                        Text(address).font(.callout).foregroundStyle(Color.accent)
                    }
                case .licenceText:
                    licenceText
                case let .licenceLink(name, url):
                    Link(destination: url) {
                        Text(name).font(.callout).foregroundStyle(Color.accent)
                    }
                }
            }
        }
    }

    /// "Licence text" as a second disclosure of its own, over the file's reflowed text.
    @ViewBuilder private var licenceText: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            chevron(licenceOpen)
            Text("Licence text").font(.callout).foregroundStyle(Color.inkSecondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.xxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Licence text")
        .accessibilityValue(licenceOpen ? "Expanded" : "Collapsed")
        .versePanelRowAction { licenceOpen.toggle() }
        if licenceOpen, let text = Credits.licenseText(for: line.credit) {
            Text(LicenseText.reflowed(text))
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
                .textSelection(.enabled)
        }
    }
}

/// A licence file's text laid out for the width it is shown at.
enum LicenseText {
    /// The file's hard-wrapped lines joined into paragraphs, changing line breaks only. A blank line,
    /// a heading (a short line with no lowercase letters, such as "PREAMBLE", or a rule of dashes) and
    /// a list item ("* ", "- ", "1) ", "(a) ") each start their own line; a line after prose that is
    /// none of those (indented or not) continues it, and a heading's next line starts afresh.
    nonisolated static func reflowed(_ text: String) -> String {
        var lines: [String] = []
        var continuable = false   // whether the last output line is prose a wrapped line may join
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                lines.append("")
                continuable = false
            } else if continuable, !startsBlock(line) {
                lines[lines.count - 1] += " " + line
            } else {
                lines.append(line)
                continuable = !isHeading(line)
            }
        }
        return lines.joined(separator: "\n")
    }

    private nonisolated static func isHeading(_ line: String) -> Bool {
        if line.allSatisfy({ "-=_*".contains($0) }) { return true }
        return line.count <= 40 && line.rangeOfCharacter(from: .lowercaseLetters) == nil
            && !(line.last.map { ".,;:".contains($0) } ?? false)
    }

    private nonisolated static func startsBlock(_ line: String) -> Bool {
        isHeading(line) || line.wholeMatch(of: /(?:[*\-\u{2022}]|\d+[.)]|\([a-z0-9]+\))\s.*/) != nil
    }
}
