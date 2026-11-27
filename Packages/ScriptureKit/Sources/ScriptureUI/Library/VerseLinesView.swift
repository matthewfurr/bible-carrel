#if os(macOS)
import AppKit
#endif
import ScriptureData
import SwiftUI

/// A book's verses as lines, one for each chapter (spec 6): the first twelve, then "n more
/// chapters" in the accent, which opens the rest in place. Each line is a `VerseLineView`, its own
/// view, so a page of a hundred lines does not redraw as one.
///
/// The Mac's keys (Departure 13): each line is one Tab stop. Tab onto a line focuses its first run;
/// ← and → walk the runs and stop at the line's ends; Tab and Shift-Tab go line to line and, past
/// the first or last, on to the controls around; Return opens the focused run's popover at that
/// run. The focused run sits on the accent wash in `ink.primary`, and the system's ring is drawn on
/// its rounded rectangle. Closing the popover by Esc or Open gives the keyboard back to the line; a
/// click elsewhere leaves it where the click put it.
///
/// The lines are one focusable view, which walks its own lines on Tab, rather than one focusable
/// view each: a focusable view costs about 0.4 ms to lay out, and a page can hold 150 lines. The
/// keyboard, the run frames and the open popover are held here, once for the book; a line holds no
/// state, so a key redraws only the lines it changes.
struct VerseLinesView: View {
    let group: VerseGroup
    let showsAll: Bool
    let navigation: NavigationModel
    let onShowAll: () -> Void
    let onShow: ((Reference) -> Void)?
    let onOpen: (Reference) -> Void

    /// Every line's run frames, in the lines' space; a reference type, so measuring invalidates nothing.
    @State private var frames = RunFrames()
    /// What a run does when clicked or activated by VoiceOver; one object for the book, so the
    /// lines' `openURL` is the same value on every redraw and a key redraws only the lines it changes.
    @State private var runAction = RunAction()
    @Environment(\.libraryType) private var type
    #if os(macOS)
    @State private var keys = LinesKeys()
    @FocusState private var isFocused: Bool
    /// The page's scroll to a line, for a line the keys move onto.
    @Environment(\.libraryRevealLine) private var revealLine
    #endif

    var body: some View {
        let shown = VerseLines.shown(group.lines, showingAll: showsAll)
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            lines(shown.lines)
            if shown.hidden > 0 {
                Button(action: onShowAll) {
                    Text(VerseLines.moreLine(shown.hidden))
                        .font(type.font(.callout))
                        .foregroundStyle(Color.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func lines(_ lines: [VerseLine]) -> some View {
        #if os(macOS)
        let washed = washedRun
        #endif
        // The action reads the lines as they are now; setting it invalidates nothing.
        runAction.perform = { reference in
            guard let position = lines.firstIndex(where: { $0.runs.contains(reference) }),
                  let index = lines[position].runs.firstIndex(of: reference) else { return }
            show(reference, at: index, on: position, of: lines)
        }
        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { position, line in
                #if os(macOS)
                let runOnWash = washed?.line == position ? washed?.run : nil
                VerseLineView(line: line, frames: frames, runAction: runAction, washedRun: runOnWash,
                              onWashedFrame: runOnWash == nil ? nil : { frame in if keys.ring != frame { keys.ring = frame } })
                    .id(LibraryScrollID.line(group.book.id, line.chapter))
                #else
                VerseLineView(line: line, frames: frames, runAction: runAction)
                    .id(LibraryScrollID.line(group.book.id, line.chapter))
                #endif
            }
        }
        #if os(macOS)
        .background { if washed != nil, let ring = keys.ring { LibraryChosenRowShape(rect: ring).fill(Color.accentWash) } }
        #endif
        .coordinateSpace(.named(VerseLineView.space))
        .environment(\.openURL, runAction.openURL)
        #if os(macOS)
        .contentShape(.focusEffect, LibraryChosenRowShape(rect: keys.ring ?? .zero))
        .focusable(interactions: .activate)
        .focused($isFocused)
        .accessibilityElement(children: .contain)
        .onChange(of: isFocused) { _, focused in focusChanged(focused, lines: lines) }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .return, .tab, Self.backTab]) { press in key(press, lines: lines) }
        .popover(item: Binding(get: { keys.shown }, set: { if $0 == nil { close(by: .elsewhere) } }),
                 attachmentAnchor: .rect(keys.shown?.anchor.map { Anchor<CGRect>.Source.rect($0) } ?? .bounds)) { shown in
            LibraryPassageView(passage: shown.passage) {
                close(by: .open)
                onOpen(shown.reference)
            }
            .onExitCommand { close(by: .escape) }
        }
        #endif
    }

    /// The id a line the keys move onto is scrolled into view by (each line carries it); nil past the lines.
    nonisolated static func revealID(bookID: String, lines: [VerseLine], at position: Int) -> String? {
        lines.indices.contains(position) ? LibraryScrollID.line(bookID, lines[position].chapter) : nil
    }

    /// A click, or VoiceOver's action: the run's verses, the popover anchored at the clicked run.
    private func show(_ reference: Reference, at index: Int, on position: Int, of lines: [VerseLine]) {
        if let onShow {
            onShow(reference)
            return
        }
        #if os(macOS)
        present(reference, at: index, on: position,
                anchor: VerseLineView.anchorRect(index, frames: frames.frames[lines[position].id] ?? [:]), of: lines)
        #else
        onOpen(reference)
        #endif
    }

    #if os(macOS)
    private static let backTab = KeyEquivalent("\u{19}")

    /// The lines' keyboard: the line and run it is on and that run's frame, and the open popover.
    private struct LinesKeys {
        /// The focused line, by its place among the lines shown.
        var line = 0
        var focus = VerseLineFocus()
        /// The focused run's frame in the lines' space: the wash, the ring and Return's anchor.
        var ring: CGRect?
        var shown: VerseLineView.ShownRun?
        /// The open popover was opened while the lines held the keyboard.
        var openedFromKeyboard = false
        /// Focus is coming back from the popover: keep the run it left from.
        var returning = false
    }

    /// The run on the wash, by line and run: the focused one, while the lines hold the keyboard or
    /// its popover is open.
    private var washedRun: (line: Int, run: Int)? {
        guard let run = keys.focus.index, isFocused || keys.shown != nil else { return nil }
        return (keys.line, run)
    }

    /// Tab onto the lines: the first run of the first line, or of the last line after Shift-Tab
    /// (unless focus is coming back from the popover). Off them, with no popover open: no run.
    private func focusChanged(_ focused: Bool, lines: [VerseLine]) {
        if focused {
            if !keys.returning || keys.focus.index == nil {
                keys.line = VerseLineFocus.entryLine(backward: Self.cameBackward, count: lines.count)
                keys.focus.enter()
                reveal(lines)
            }
            keys.returning = false
            focusRun(lines)
        } else if keys.shown == nil {
            keys.focus.index = nil
        }
    }

    /// Focus arrived by Shift-Tab: the key that moved it is still the current event.
    private static var cameBackward: Bool {
        guard let event = NSApp.currentEvent, event.type == .keyDown else { return false }
        return event.characters == "\u{19}" || (event.keyCode == 48 && event.modifierFlags.contains(.shift))
    }

    /// ← and → walk the line, held at its ends; Tab and Shift-Tab go line to line, and past the
    /// last or first are the system's (under VoiceOver Tab is always the system's); Return opens
    /// the focused run's verses at that run.
    private func key(_ press: KeyPress, lines: [VerseLine]) -> KeyPress.Result {
        guard isFocused, lines.indices.contains(keys.line), keys.focus.index != nil else { return .ignored }
        switch press.key {
        case .return:
            return openFocusedRun(lines)
        case .tab, Self.backTab:
            let back = press.key == Self.backTab || press.modifiers.contains(.shift)
            guard !NSWorkspace.shared.isVoiceOverEnabled, !press.modifiers.contains(.control),
                  let next = VerseLineFocus.nextLine(from: keys.line, backward: back, count: lines.count) else { return .ignored }
            keys.line = next
            keys.focus.enter()
            reveal(lines)
        default:
            guard keys.focus.move(press.key == .leftArrow ? -1 : 1, count: lines[keys.line].runs.count) else { return .ignored }
        }
        focusRun(lines)
        return .handled
    }

    /// The focused line into view, with the least scroll and no animation: the system scrolls the
    /// lines' view as a whole into view when it takes focus, not the line Tab moves to inside it.
    private func reveal(_ lines: [VerseLine]) {
        guard let id = Self.revealID(bookID: group.book.id, lines: lines, at: keys.line) else { return }
        revealLine?.reveal(id)
    }

    private func focusRun(_ lines: [VerseLine]) {
        guard lines.indices.contains(keys.line) else { return }
        keys.ring = VerseLineView.popoverAnchor(focus: keys.focus, frames: frames.frames[lines[keys.line].id] ?? [:])
    }

    private func openFocusedRun(_ lines: [VerseLine]) -> KeyPress.Result {
        let line = lines[keys.line]
        guard let index = keys.focus.index, line.runs.indices.contains(index) else { return .ignored }
        let run = line.runs[index]
        if let onShow {
            onShow(run)
        } else {
            present(run, at: index, on: keys.line,
                    anchor: VerseLineView.popoverAnchor(focus: keys.focus, frames: frames.frames[line.id] ?? [:]), of: lines)
        }
        return .handled
    }

    /// Opens the popover; a run clicked while the lines hold the keyboard becomes the focused run.
    private func present(_ reference: Reference, at index: Int, on position: Int, anchor: CGRect?, of lines: [VerseLine]) {
        if isFocused {
            keys.line = position
            keys.focus.index = index
            focusRun(lines)
        }
        keys.openedFromKeyboard = isFocused
        keys.shown = VerseLineView.ShownRun(passage: LibraryPassage.load(reference, navigation: navigation),
                                            reference: reference, anchor: anchor)
    }

    private func close(by close: VerseLineView.PopoverClose) {
        guard keys.shown != nil else { return }
        let back = VerseLineView.takesFocusBack(after: close, openedFromKeyboard: keys.openedFromKeyboard)
        keys.shown = nil
        keys.openedFromKeyboard = false
        if back {
            if !isFocused {
                keys.returning = true
                isFocused = true
            }
        } else if !isFocused {
            keys.focus.index = nil
        }
    }
    #endif
}

/// One chapter's line: the number in a column as wide as "000" in its own font, then the chapter's
/// runs as links with ", " between them, wrapping under the runs and never under the number. A run
/// is one link (the Mac's click opens all its verses in the lines' popover, its arrow on the run;
/// the phone hands the run over). VoiceOver hears "Chapter 3", then each run, "2 Samuel 1:1 to 5",
/// as a link. It holds no state: `VerseLinesView` keeps the keyboard, the frames and the popover.
struct VerseLineView: View {
    let line: VerseLine
    let frames: RunFrames
    /// What the run does when VoiceOver activates it (a click goes through the lines' `openURL`).
    let runAction: RunAction
    #if os(macOS)
    /// The run on the wash, in `ink.primary`: the focused run; nil on every other line.
    var washedRun: Int?
    /// The focused run was measured again (a re-wrap): the wash and the ring follow it.
    var onWashedFrame: ((CGRect) -> Void)?
    #endif
    /// The lines are set in the reading style: the reader size on the Mac's Library, `.callout` on the phone.
    @Environment(\.libraryType) private var type

    struct ShownRun: Identifiable, Equatable {
        let passage: LibraryPassage
        let reference: Reference
        /// The run's frame in the lines' space; nil points at the lines.
        let anchor: CGRect?
        var id: String { reference.displayString }
    }

    /// How a run's popover was closed.
    enum PopoverClose: Equatable {
        /// Esc, inside the popover.
        case escape
        /// The popover's Open.
        case open
        /// The system's dismissal: a click outside it.
        case elsewhere
    }

    /// The clicked run's frame; nil when it is not known, which anchors the popover to the lines.
    nonisolated static func anchorRect(_ index: Int, frames: [Int: CGRect]) -> CGRect? {
        frames[index]
    }

    /// Return's anchor: the focused run's frame; nil with no run focused or its frame not known.
    nonisolated static func popoverAnchor(focus: VerseLineFocus, frames: [Int: CGRect]) -> CGRect? {
        focus.index.flatMap { anchorRect($0, frames: frames) }
    }

    /// Whether the line takes the keyboard back as the popover closes: only when it held the
    /// keyboard as the popover opened, and only for Esc or Open. A click elsewhere has put the
    /// keyboard where the reader wanted it.
    nonisolated static func takesFocusBack(after close: PopoverClose, openedFromKeyboard: Bool) -> Bool {
        openedFromKeyboard && close != .elsewhere
    }

    /// The lines' space, set by `VerseLinesView`: the run frames, the wash, the ring and the popover's arrow.
    nonisolated static let space = "verse-lines"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            if let chapter = line.chapter { chapterNumber(chapter) }
            FlowLayout(spacing: 0, isCentered: false) {
                ForEach(Array(line.runs.enumerated()), id: \.offset) { index, run in
                    runView(index, run)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Ch 11" as one unit, right-aligned in the width of "Ch 000" in the same font, so every number ends on one edge
    /// and the column follows the text size (Matt, 2026-11-24).
    private func chapterNumber(_ chapter: Int) -> some View {
        ZStack(alignment: .trailing) {
            Text(VerseLines.widestChapterLabel).hidden()
            Text(VerseLines.chapterLabel(chapter))
        }
        .font(type.font(type.reading, weight: .semibold).monospacedDigit())
        .foregroundStyle(Color.inkSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(VerseLines.chapterSpoken(chapter))
    }

    /// The run as a link in the accent (the focused run in `ink.primary`, on the wash), then ", "
    /// in the secondary ink unless it is the line's last.
    private func runView(_ index: Int, _ run: Reference) -> some View {
        #if os(macOS)
        let isWashed = index == washedRun
        let ink = isWashed ? Color.inkPrimary : Color.accent
        #else
        let ink = Color.accent
        #endif
        return HStack(spacing: 0) {
            Text(Self.linked(run, ink: ink))
                .font(type.font(type.reading))
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frame in
                    frames.frames[line.id, default: [:]][index] = frame
                    #if os(macOS)
                    if isWashed { onWashedFrame?(frame) }
                    #endif
                }
            if index < line.runs.count - 1 {
                Text(", ")
                    .font(type.font(type.reading))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(VerseLines.spoken(run))
        .accessibilityAddTraits(.isLink)
        .accessibilityAction { runAction.perform(run) }
    }

    private nonisolated static func linked(_ run: Reference, ink: Color) -> AttributedString {
        var text = AttributedString(VerseLines.runText(run))
        text.link = ReferenceLinker.url(for: run)
        text.foregroundColor = ink
        return text
    }
}

/// Which run of a line has the keyboard (the Mac's ← and → within a line, Departure 13): none until
/// the line is focused, then its first run; the arrows stop at the line's ends.
struct VerseLineFocus: Equatable {
    var index: Int?

    /// Tab onto the line: its first run.
    mutating func enter() {
        index = 0
    }

    /// One run along, held at the ends. Whether the key was the line's: always while a run is
    /// focused, so an arrow at an end stays on the line; never with none focused.
    mutating func move(_ step: Int, count: Int) -> Bool {
        guard let index, count > 0 else { return false }
        self.index = min(max(index + step, 0), count - 1)
        return true
    }

    /// The line Tab lands on coming into the lines: the first, or the last after Shift-Tab.
    static func entryLine(backward: Bool, count: Int) -> Int {
        backward ? max(count - 1, 0) : 0
    }

    /// The line Tab (or Shift-Tab) goes to next; nil past the last (or first), where Tab is the system's.
    static func nextLine(from line: Int, backward: Bool, count: Int) -> Int? {
        let next = line + (backward ? -1 : 1)
        return (0..<count).contains(next) ? next : nil
    }
}

/// Every line's run frames, by line id and run, in the lines' space; written as they are
/// measured. A reference type held in `@State`.
@MainActor final class RunFrames {
    var frames: [Int: [Int: CGRect]] = [:]
}

/// What a run of the lines does: the popover on the Mac, the run handed over on the phone. One
/// object for the book, so its `openURL` is the same value on every redraw. A reference type held
/// in `@State`; `perform` is set as the lines are drawn, which invalidates nothing.
@MainActor final class RunAction {
    var perform: (Reference) -> Void = { _ in }

    /// Clicks on the runs' links.
    private(set) lazy var openURL = OpenURLAction { [unowned self] url in
        guard url.scheme == ReferenceLinker.scheme, let reference = ReferenceLinker.reference(from: url) else { return .systemAction }
        perform(reference)
        return .handled
    }
}

/// Scrolls the page to a verse line (by `LibraryScrollID.line`) with the least scroll, as a cut. The
/// person's and the place's pages hold one in `@State` and give it their `ScrollViewReader`'s proxy,
/// so the environment carries the same object on every redraw; nil where nothing scrolls the lines.
@MainActor final class LibraryRevealLine {
    var proxy: ScrollViewProxy?

    func reveal(_ id: String) {
        proxy?.scrollTo(id)
    }
}

private struct LibraryRevealLineKey: EnvironmentKey {
    static var defaultValue: LibraryRevealLine? { nil }
}

extension EnvironmentValues {
    var libraryRevealLine: LibraryRevealLine? {
        get { self[LibraryRevealLineKey.self] }
        set { self[LibraryRevealLineKey.self] = newValue }
    }
}
