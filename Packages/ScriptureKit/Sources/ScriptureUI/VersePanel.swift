import Foundation
import ScriptureData
import SwiftUI

/// The two panels a verse can open: its other translations side by side, and what it points to.
/// They are separate panels, not one with tabs.
public enum VersePanelKind: String, Sendable {
    case compare, crossReferences

    public var title: String {
        switch self {
        case .compare: "Compare Translations"
        case .crossReferences: "Cross-References"
        }
    }

    public var symbolName: String {
        switch self {
        case .compare: "rectangle.split.2x1"
        case .crossReferences: "arrow.triangle.branch"
        }
    }
}

/// One asking for a panel: which, the verses selected, and the characters they were (the Mac's anchor).
public struct VersePanelRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: VersePanelKind
    public let selection: TextSelection
    public let range: NSRange

    public init(kind: VersePanelKind, report: SelectionReport) {
        self.id = UUID()
        self.kind = kind
        self.selection = report.selection
        self.range = report.range
    }

    /// The selection's first verse.
    public var verse: VerseLocation {
        VerseLocation(book: selection.book, chapter: selection.chapter, verse: selection.verse)
    }
}

/// A verse panel to show over the page (the Mac's popover, `ChapterTextController.apply`): the
/// request it answers (whose range is the anchor), the panel, and what to do when the reader
/// closes it (Esc, a click outside). Declared on both platforms so `ReaderView` takes it as one
/// parameter; only the Mac shows it.
public struct VersePanelPresentation {
    public let request: VersePanelRequest
    public let content: AnyView
    public let onClose: () -> Void

    public init(request: VersePanelRequest, content: AnyView, onClose: @escaping () -> Void) {
        self.request = request
        self.content = content
        self.onClose = onClose
    }
}

extension View {
    /// A panel row that acts as a button. On the Mac it is its own Tab stop as a chapter grid is
    /// (`ChapterGridView`): a plain view, `.focusable`, its focus-effect shape the rounded wash
    /// (radius `md`) set before `.focusable`, so the system ring is drawn on that shape. A `Button`
    /// draws its ring from its own bounds whatever shape is set outside it, which gave a square box.
    /// It takes focus only from the keyboard (`.activate`, as a button does), and Return or Space
    /// acts. VoiceOver hears a button.
    func versePanelRowAction(_ action: @escaping () -> Void) -> some View {
        modifier(VersePanelRowAction(action: action))
    }
}

private struct VersePanelRowAction: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            #if os(macOS)
            .contentShape(.focusEffect, RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .focusable(interactions: .activate)
            .onKeyPress(keys: [.return, .space]) { _ in
                action()
                return .handled
            }
            #endif
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
}

/// What both panels are laid out in: the header, the middle, then the foot, `xs` apart and padded `sm`,
/// with no background of its own. On the Mac it is 360 pt wide and grows to 480 pt tall (both scaled),
/// the middle scrolling past that, and a middle that is shorter is exactly as tall as it is. On the
/// phone the sheet sets the size and the middle scrolls within it.
struct VersePanelLayout<Header: View, Middle: View, Foot: View>: View {
    /// False for a middle that scrolls itself (a passage's `VersePreviewView`).
    var scrolls = true
    @ViewBuilder let header: Header
    @ViewBuilder let middle: Middle
    @ViewBuilder let foot: Foot

    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 360
    @ScaledMetric(relativeTo: .body) private var maxHeight: CGFloat = 480
    /// The middle's height as laid out, unscrolled, and the header's and the foot's (the Mac's
    /// measures): the scroll is the smaller of the middle and the room the limit leaves it.
    @State private var middleHeight: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    @State private var footHeight: CGFloat = 0
    /// On the Mac the keyboard rests, as the panel opens, on a 1 pt focusable view of its own at the
    /// panel's top leading corner, which draws no ring and VoiceOver does not hear; so no control
    /// shows a ring on open, the first Tab goes to the first control (the first row in Compare, the
    /// Previous verse chevron in Cross-References), and Shift-Tab back from it stops there once. It
    /// sits beside the controls, never round them: a `focusEffectDisabled()` on their ancestor would
    /// take every control's ring away, which an inner `focusEffectDisabled(false)` cannot undo.
    @FocusState private var restsOnPanel: Bool

    var body: some View {
        #if os(macOS)
        panel
            .background(alignment: .topLeading) {
                Spacer(minLength: 0)
                    .frame(width: 1, height: 1)
                    .focusable()
                    .focusEffectDisabled()
                    .focused($restsOnPanel)
                    .accessibilityHidden(true)
            }
            .defaultFocus($restsOnPanel, true)
            .onAppear { restsOnPanel = true }
        #else
        panel
        #endif
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            header
                .padding(.horizontal, AppSpacing.xxs)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
            if scrolls {
                ScrollView {
                    // Room on every side for a row's focus ring, which the scroll would otherwise clip.
                    middle
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.xxs)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { middleHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                #if os(macOS)
                .frame(height: min(middleHeight, roomForMiddle))
                #endif
            } else {
                middle
                    .padding(.horizontal, AppSpacing.xxs)
            }
            foot
                .padding(.horizontal, AppSpacing.xxs)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footHeight = $0 }
        }
        .padding(.horizontal, AppSpacing.sm - AppSpacing.xxs)
        .padding(.vertical, AppSpacing.sm)
        #if os(macOS)
        .frame(width: width, alignment: .topLeading)
        #endif
    }

    /// The limit less the padding, the header, the foot and the gaps (an empty foot has none).
    private var roomForMiddle: CGFloat {
        let gaps = AppSpacing.xs * (footHeight > 0 ? 2 : 1)
        return max(0, maxHeight - 2 * AppSpacing.sm - headerHeight - footHeight - gaps)
    }
}
