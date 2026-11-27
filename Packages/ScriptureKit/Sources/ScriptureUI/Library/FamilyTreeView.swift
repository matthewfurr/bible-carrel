#if os(macOS)
import ScriptureData
import SwiftUI

/// The Mac's family tree (spec 5.2, Matt's C): the names laid by `FamilyTreeNamesLayout` at the frames
/// of one `FamilyTreeGeometry`, and a `Canvas` behind them stroking the same geometry's lines, so a line
/// always meets its name. No card and no boxed people: a name is a link, the person sits on the
/// `accent.wash`, and a chip's capsule ("7 siblings", "Fewer") is the one filled shape.
///
/// The geometry is worked once per width and set of open chips (the memo), so a scroll never lays it again.
///
/// The keys (Departure 12): the tree is one Tab stop, entered on the person; names, chips and "Fewer" are
/// not stops of their own (ruling 5), since a focusable view costs about 0.4 ms each to lay. The arrows
/// move between them by `FamilyTreeKeys`, Return walks to a name or opens and closes a chip, Space opens
/// and closes a chip; the system's ring is drawn on the focused slot's rounded rectangle.
struct FamilyTreeView: View {
    /// The row pitch's base: a column's children are this far apart, as are the lines of an open chip's run.
    nonisolated static let rowPitch = AppSpacing.md

    /// The width before the column's is read, so the first pass draws the tree near its width (ruling 20): the
    /// reader's measure, near the page's width in a usual window; with the system's styles, 472.
    nonisolated static func firstWidth(_ type: LibraryType) -> CGFloat {
        type.measure ?? 472
    }

    let tree: FamilyTree
    @Binding var open: Set<FamilyChip>
    /// The width the page expects the tree to have (its own width less its margins), read by the page in the same
    /// pass, so the first layout is at the real width and the tree is not laid twice; nil falls back to `firstWidth`.
    let expectedWidth: CGFloat?
    let onWalk: (PersonSummary) -> Void

    @ScaledMetric(relativeTo: .body) private var rowPitch = FamilyTreeView.rowPitch
    /// A chip's and "Fewer"'s least hit height (DESIGN.md: 24 pt for a symbol button, scaled with the text).
    @ScaledMetric(relativeTo: .callout) private var minimumHit: CGFloat = 24
    @Environment(\.libraryType) private var type
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The page's scroll to an id, for the stop the keys move onto; the same object on every redraw.
    @Environment(\.libraryRevealLine) private var revealLine
    @State private var width: CGFloat?
    @State private var memo = FamilyTreeMemo()
    @FocusState private var isFocused: Bool
    /// The focused stop's slot id while the tree holds the keyboard; it is the person's as Tab enters.
    @State private var focused: String?

    init(tree: FamilyTree, open: Binding<Set<FamilyChip>>, expectedWidth: CGFloat? = nil, onWalk: @escaping (PersonSummary) -> Void) {
        self.tree = tree
        self._open = open
        self.expectedWidth = expectedWidth
        self.onWalk = onWalk
    }

    var body: some View {
        let laidWidth = Self.laidWidth(expected: expectedWidth, read: width, first: Self.firstWidth(type))
        let laid = memo.laid(tree, width: laidWidth, open: open, rowPitch: type.metric(rowPitch), type: type)
        FamilyTreeNamesLayout(size: laid.geometry.size) {
            // A name is one view while it keeps its place: one that moves when a chip opens is another,
            // so it fades out where it was and in where it is, and nothing slides away from its lines.
            ForEach(laid.geometry.slots, id: \.placed) { slot in
                FamilyTreeName(slot: slot, tree: tree, type: type, minimumHit: type.metric(minimumHit), onWalk: onWalk, onToggle: toggle)
                    .id(LibraryScrollID.tree(slot.id))
                    .layoutValue(key: FamilyTreeSlotFrame.self, value: slot.frame)
                    .transition(.opacity)
            }
        }
        // VoiceOver reads the tree by relation (spec 5.2): one element per group, over its names.
        .modifier(FamilyTreeSpoken(groups: laid.groups, size: laid.geometry.size, onWalk: onWalk, onToggle: toggle))
        .background { FamilyTreeLines(geometry: laid.geometry) }
        .contentShape(.focusEffect, LibraryChosenRowShape(rect: ring(in: laid.geometry)))
        .focusable(interactions: .activate)
        .focused($isFocused)
        .onChange(of: isFocused) { _, isFocused in focused = isFocused ? FamilyTreeKeys.start(laid.geometry) : nil }
        .onChange(of: tree.person.id) { focused = isFocused ? FamilyTreeKeys.start(laid.geometry) : nil }
        // A walk by the keys lands on this page's tree, not on whatever the system focuses when the last one goes.
        .task(id: tree.person.id) {
            guard FamilyTreeWalkFocus.take(tree.person.id) else { return }
            await Task.yield()
            isFocused = true
        }
        .onChange(of: width) { settle(in: laid.geometry) }
        .onChange(of: open) { settle(in: laid.geometry) }
        .onChange(of: focused) { reveal(in: laid.geometry) }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .return, .space]) { press in key(press, in: laid.geometry) }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { read in
            // A reading the laid width ignores (`laidWidth`) is kept as none, so it does not draw the tree again.
            let reading = Self.reading(read, expected: expectedWidth)
            if let reading { if abs(reading - (width ?? -1)) >= 0.5 { width = reading } } else if width != nil { width = nil }
        }
        .accessibilityElement(children: .contain)
    }

    /// The width the tree is laid at: the page's expected width, or the tree's own reading when it is narrower by half a
    /// point or more (the page's guess missed a margin); with none from the page, the tree's own, else `first`. A legacy
    /// scroller that comes and goes as the page is first laid only ever narrows the reading, so the tree is laid once.
    /// A reading within half a point is the expected width: the tree's frame lies on whole points and the page's width
    /// need not (David's tree at a 1,100 pt window reads 774 against 774.08), and taking the reading there laid the whole
    /// tree a second time, its names made again at their new places, for a width no one could see.
    nonisolated static func laidWidth(expected: CGFloat?, read: CGFloat?, first: CGFloat) -> CGFloat {
        guard let expected else { return read ?? first }
        return reading(read, expected: expected) ?? expected
    }

    /// The tree's own reading of its width where `laidWidth` takes it; nil where the page's expected width stands.
    nonisolated static func reading(_ read: CGFloat?, expected: CGFloat?) -> CGFloat? {
        guard let read, let expected else { return read }
        return read <= expected - 0.5 ? read : nil
    }

    /// The focused stop's frame, where the ring is drawn; none while the tree does not hold the keyboard.
    private func ring(in geometry: FamilyTreeGeometry) -> CGRect {
        guard isFocused else { return .zero }
        let id = FamilyTreeKeys.fallback(for: focused ?? FamilyTreeKeys.start(geometry), in: geometry)
        return geometry.slots.first { $0.id == id }?.frame ?? .zero
    }

    /// The scroll id of the stop the focus is on (where `focused` falls back to); nil with no focus.
    nonisolated static func revealID(focused: String?, in geometry: FamilyTreeGeometry) -> String? {
        focused.map { LibraryScrollID.tree(FamilyTreeKeys.fallback(for: $0, in: geometry)) }
    }

    /// The focused stop into view with the least scroll, as a cut: the system scrolls the tree into view
    /// as a whole when Tab enters it, not a stop the keys move onto, nor the "Fewer" a chip opens onto.
    private func reveal(in geometry: FamilyTreeGeometry) {
        guard isFocused, let id = Self.revealID(focused: focused, in: geometry) else { return }
        var cut = Transaction()
        cut.disablesAnimations = true
        withTransaction(cut) { revealLine?.reveal(id) }
    }

    /// A fold changed (a resize, a chip): a focused stop that has gone falls back to the chip that took it,
    /// else the person.
    private func settle(in geometry: FamilyTreeGeometry) {
        guard let focused else { return }
        let settled = FamilyTreeKeys.fallback(for: focused, in: geometry)
        if settled != focused { self.focused = settled }
    }

    /// The arrows move the focus (held at an edge, ruling 4); Return and Space act on the focused stop.
    /// A key with ⌘, ⌥ or ⌃ is left to the page and the menus.
    private func key(_ press: KeyPress, in geometry: FamilyTreeGeometry) -> KeyPress.Result {
        guard isFocused, press.modifiers.isDisjoint(with: [.command, .option, .control]) else { return .ignored }
        let id = FamilyTreeKeys.fallback(for: focused ?? FamilyTreeKeys.start(geometry), in: geometry)
        let arrow: FamilyTreeKey? = switch press.key {
        case .leftArrow: .left
        case .rightArrow: .right
        case .upArrow: .up
        case .downArrow: .down
        default: nil
        }
        if let arrow {
            focused = FamilyTreeKeys.next(from: id, arrow, in: geometry)
            return .handled
        }
        focused = id
        guard let slot = geometry.slots.first(where: { $0.id == id }) else { return .handled }
        switch FamilyTreeKeys.activation(of: slot, space: press.key == .space) {
        case .walk(let person):
            FamilyTreeWalkFocus.walked(to: person.id)
            onWalk(person)
        case .toggle(let chip): toggle(chip)
        case .nothing: break
        }
        return .handled
    }

    /// A chip opens its names in place, or "Fewer" folds them again: what comes and goes fades (`.snappy`),
    /// a cut under Reduce Motion. The lines are drawn at once; a new width is a cut.
    private func toggle(_ chip: FamilyChip) {
        withAnimation(reduceMotion ? nil : .snappy) {
            if open.contains(chip) { open.remove(chip) } else { open.insert(chip) }
        }
    }
}

/// Return on a name walks to that person's page, which is built anew, so the focused tree goes and the system
/// would put the keyboard in the next pane. The walk leaves the person's id here; the tree of that person's page
/// takes it as it appears and is focused (the final review's Important 3). Any other tree appearing first drops it.
@MainActor enum FamilyTreeWalkFocus {
    private static var pending: Int?

    static func walked(to id: Int) { pending = id }

    /// Whether the tree of `id`'s page takes the focus; the hand-off is used up either way.
    static func take(_ id: Int) -> Bool {
        defer { pending = nil }
        return pending == id
    }
}

private extension FamilyTreeGeometry.Slot {
    /// The slot and where it stands.
    var placed: String { "\(id)@\(frame.minX),\(frame.minY)" }
}

/// The geometry and VoiceOver's elements for the last width, open chips, row pitch and type asked.
@MainActor final class FamilyTreeMemo {
    struct Laid {
        let geometry: FamilyTreeGeometry
        /// VoiceOver's elements, one per relation group, in reading order (`FamilyTreeSpeech.groups`).
        let groups: [FamilyTreeSpeech.Group]
    }

    private struct Key: Equatable {
        let tree: FamilyTree
        let width: CGFloat, rowPitch: CGFloat
        let open: Set<FamilyChip>
        let type: LibraryType
    }

    private var key: Key?
    private var value: Laid?

    func laid(_ tree: FamilyTree, width: CGFloat, open: Set<FamilyChip>, rowPitch: CGFloat, type: LibraryType) -> Laid {
        let key = Key(tree: tree, width: width, rowPitch: rowPitch, open: open, type: type)
        if key == self.key, let value { return value }
        let geometry = FamilyTreeGeometry.make(tree, width: width, open: open, rowPitch: rowPitch, gap: FamilyTreeFolding.gap(type),
                                               measure: SystemFamilyTreeMeasure(type: type))
        let laid = Laid(geometry: geometry, groups: FamilyTreeSpeech.groups(tree, geometry: geometry))
        (self.key, value) = (key, laid)
        return laid
    }
}

/// Whether a person's page lays the family as the tree (`FamilyTreeLayoutRule`) at the page's width: worked once per
/// tree, type and width, so a scroll or a redraw never lays the tree to decide, and a resize lays it once per new width.
@MainActor final class FamilyTreeFitMemo {
    private struct Key: Equatable {
        let tree: FamilyTree
        let type: LibraryType
    }

    /// Widths known for the key; a long live resize asks many, so past this many they are dropped and worked again.
    private static let kept = 64
    private var key: Key?
    private var known: [CGFloat: Bool] = [:]

    func fitsAsTree(_ tree: FamilyTree, width: CGFloat, type: LibraryType) -> Bool {
        let key = Key(tree: tree, type: type)
        if key != self.key { (self.key, known) = (key, [:]) }
        if let fits = known[width] { return fits }
        if known.count >= Self.kept { known.removeAll() }
        let fits = FamilyTreeLayoutRule.fitsAsTree(tree, width: width, type: type)
        known[width] = fits
        return fits
    }
}

/// Where a name sits in the tree: its slot's frame in the geometry.
struct FamilyTreeSlotFrame: LayoutValueKey {
    static let defaultValue = CGRect.zero
}

/// Places each name centred on its slot's frame, at its own size, and is as tall as the geometry. It takes
/// the width it is offered, so the width read from it is the column's, even before the geometry is laid at
/// it. A name keeps the frame it was given while it fades out, so it leaves from where it stood.
struct FamilyTreeNamesLayout: Layout {
    let size: CGSize

    func sizeThatFits(proposal: ProposedViewSize, subviews _: Subviews, cache _: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        for subview in subviews {
            let frame = subview[FamilyTreeSlotFrame.self]
            subview.place(at: CGPoint(x: bounds.minX + frame.midX, y: bounds.minY + frame.midY), anchor: .center, proposal: .unspecified)
        }
    }
}

/// One slot of the tree: a name (a link in the accent, a grandparent in `ink.tertiary`), the person on the
/// wash, the "not named" label, a chip or "Fewer". Its own view, since a tree repeats it many times.
private struct FamilyTreeName: View {
    let slot: FamilyTreeGeometry.Slot
    let tree: FamilyTree
    /// The fonts the measure set the slot in (`FamilyTreeStyle.text`).
    let type: LibraryType
    let minimumHit: CGFloat
    let onWalk: (PersonSummary) -> Void
    let onToggle: (FamilyChip) -> Void

    /// How far a chip's or "Fewer"'s hit area reaches above and below what it draws, to `minimumHit`.
    private var reach: CGFloat { max(0, (minimumHit - slot.frame.height) / 2) }

    /// What VoiceOver reads is the tree's groups (`FamilyTreeGroupElement`), not these.
    @ViewBuilder var body: some View {
        switch slot.kind {
        case .grandparent(let person): link(person, style: .grandparent, ink: .inkTertiary)
        case .parent(let person, _), .sibling(let person), .halfSibling(let person): link(person, style: .name, ink: .accent)
        case .child(let person, _): link(person, style: .child, ink: .accent)
        case .head(let household):
            switch household.head {
            case .partner(let person), .otherParent(let person, _): link(person, style: .name, ink: .accent)
            case .notNamed(let relation): label(relation)
            }
        case .notNamedLabel(let relation): label(relation)
        case .person:
            Text(tree.person.name)
                .font(font(.person))
                .foregroundStyle(Color.inkPrimary)
                .modifier(FamilyTreeFit(slot: slot, inset: 2 * AppSpacing.xs, whole: tree.person.name))
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxs)
                .background(Color.accentWash, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        case .chip(let chip, let label): capsule(label, symbol: "chevron.down", help: "Show the names", chip: chip)
        // "Fewer" is a chip as "7 siblings" is (Matt's review, 2026-11-24: it has to look like a button).
        case .fewer(let chip): capsule("Fewer", symbol: "chevron.up", help: "Fold the names", chip: chip)
        }
    }

    /// A chip: its text and chevron in a capsule on `paper.panel`, a button that opens or folds `chip`.
    private func capsule(_ text: String, symbol: String, help: String, chip: FamilyChip) -> some View {
        Button { onToggle(chip) } label: {
            FamilyTreeChipLabel(type: type) { Text(text) } symbol: { Image(systemName: symbol) }
                .background(Color.paperPanel, in: Capsule())
                .modifier(FamilyTreeHitArea(reach: reach))
        }
        .modifier(FamilyTreeControl(font: font(.chip), help: help, reach: reach))
    }

    /// A style's font, as the measure set it.
    private func font(_ style: FamilyTreeStyle) -> Font {
        let text = style.text(type)
        return type.font(text.style, weight: text.weight, italic: text.italic)
    }

    /// A click walks to the person. A tap on the text, not a `Button`: a plain button cost about 0.4 ms more per name
    /// to lay, and David's tree at a wide window's width shows some forty (Matt's review, 2026-11-24). The keys are the
    /// tree's own and VoiceOver reads the relation groups, so the name needs no button of its own.
    private func link(_ person: PersonSummary, style: FamilyTreeStyle, ink: Color) -> some View {
        Text(person.name).font(font(style)).foregroundStyle(ink).modifier(FamilyTreeFit(slot: slot, whole: person.name))
            .contentShape(Rectangle())
            .onTapGesture { onWalk(person) }
            .pointerStyle(.link)
            .accessibilityLabel(person.name)
            .accessibilityAddTraits(.isLink)
            .accessibilityAction { onWalk(person) }
    }

    private func label(_ relation: Relation) -> some View {
        Text(FamilyTreeFolding.notNamedLabel(relation))
            .font(font(.notNamedLabel))
            .foregroundStyle(Color.inkSecondary)
            .modifier(FamilyTreeFit(slot: slot, whole: FamilyTreeFolding.notNamedLabel(relation)))
    }
}

/// A chip's or "Fewer"'s label as the tree draws it: its text, `xxs`, the chevron (at the chip's font) centred in the
/// box the measure laid for it (`FamilyTreeChevron`), `sm` at the sides and `xxs` above and below, so the chip is
/// exactly as wide as its slot at every size.
struct FamilyTreeChipLabel<Label: View, Symbol: View>: View {
    let type: LibraryType
    @ViewBuilder let label: Label
    @ViewBuilder let symbol: Symbol

    var body: some View {
        let box = FamilyTreeChevron.size(type)
        HStack(spacing: AppSpacing.xxs) {
            label
            Color.clear
                .frame(width: box.width, height: box.height)
                .overlay { symbol }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xxs)
    }
}

/// The tree's accessibility children, its relation groups, laid over their names. Only while an assistive
/// technology is on (`accessibilityEnabled`): built for every open, they cost David's page about 8 ms.
private struct FamilyTreeSpoken: ViewModifier {
    let groups: [FamilyTreeSpeech.Group]
    let size: CGSize
    let onWalk: (PersonSummary) -> Void
    let onToggle: (FamilyChip) -> Void

    @Environment(\.accessibilityEnabled) private var accessibilityEnabled

    func body(content: Content) -> some View {
        if accessibilityEnabled {
            content.accessibilityChildren {
                FamilyTreeNamesLayout(size: size) {
                    ForEach(groups) { group in
                        FamilyTreeGroupElement(group: group, onWalk: onWalk, onToggle: onToggle)
                            .layoutValue(key: FamilyTreeSlotFrame.self, value: group.frame)
                    }
                }
            }
        } else {
            content
        }
    }
}

/// One of VoiceOver's elements in the tree: a relation group read as one ("Parents: Jesse", "Bathsheba, partner.
/// Children: …"), drawn over its names; activating it walks to its one person or opens its chip, and each name
/// (and an open run's "Fewer") is a named action.
private struct FamilyTreeGroupElement: View {
    let group: FamilyTreeSpeech.Group
    let onWalk: (PersonSummary) -> Void
    let onToggle: (FamilyChip) -> Void

    @ViewBuilder var body: some View {
        let element = Color.clear
            .frame(width: group.frame.width, height: group.frame.height)
            .accessibilityElement()
            .accessibilityLabel(group.label)
            .accessibilityAddTraits(traits)
            .accessibilityActions {
                ForEach(Array(group.actions.enumerated()), id: \.offset) { _, action in
                    Button(action.name) { perform(action) }
                }
            }
        if let primary = group.primary {
            element.accessibilityAction { perform(primary) }
        } else {
            element
        }
    }

    private var traits: AccessibilityTraits {
        switch group.trait {
        case .link: .isLink
        case .button: .isButton
        case .text: .isStaticText
        }
    }

    private func perform(_ action: FamilyTreeSpeech.Action) {
        switch action {
        case .walk(let person): onWalk(person)
        case .toggle(let chip): onToggle(chip)
        }
    }
}

/// A name on one line at its own width; one the geometry cut to fit its share of the column (the last
/// resort, Task 12) at the slot's width less `inset`, tail-truncated, the whole name its help.
private struct FamilyTreeFit: ViewModifier {
    let slot: FamilyTreeGeometry.Slot
    var inset: CGFloat = 0
    let whole: String

    func body(content: Content) -> some View {
        if slot.truncated {
            content
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: max(0, slot.frame.width - inset), alignment: .leading)
                .help(whole)
        } else {
            content.lineLimit(1).fixedSize()
        }
    }
}

/// A chip and "Fewer": the chip's style (`.callout`) in the accent, plain, off the Tab order (ruling 5). Laid at
/// the size it draws (the geometry's), its label's hit area reaching `reach` beyond it above and below.
private struct FamilyTreeControl: ViewModifier {
    let font: Font
    let help: String
    let reach: CGFloat

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(Color.accent)
            .lineLimit(1)
            .fixedSize()
            .buttonStyle(.plain)
            .focusable(false)
            .help(help)
            .padding(.vertical, -reach)
    }
}

/// A label's hit area grown by `reach` above and below, drawing nothing there.
private struct FamilyTreeHitArea: ViewModifier {
    let reach: CGFloat

    func body(content: Content) -> some View {
        content.padding(.vertical, reach).contentShape(Rectangle())
    }
}

/// The geometry's lines, 1 pt `ink.rule` (the half-siblings' dashed), on the device's pixels.
private struct FamilyTreeLines: View {
    let geometry: FamilyTreeGeometry

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Canvas { context, _ in
            for line in geometry.lines {
                context.stroke(path(line), with: .color(Color.inkRule),
                               style: StrokeStyle(lineWidth: HairlineRule.thickness, dash: line.dashed ? [3, 3] : []))
            }
        }
    }

    /// A line on the pixel grid, a horizontal one run on by half its weight at each end so it closes the
    /// corners where it meets a vertical.
    private func path(_ line: FamilyTreeGeometry.Line) -> Path {
        let half = HairlineRule.thickness / 2
        var from = CGPoint(x: snap(line.from.x), y: snap(line.from.y)), to = CGPoint(x: snap(line.to.x), y: snap(line.to.y))
        if from.y == to.y, !line.dashed {
            (from.x, to.x) = (min(from.x, to.x) - half, max(from.x, to.x) + half)
        }
        return Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
    }

    /// The centre of a 1 pt line where it lies on whole device pixels: a pixel's middle when the line is
    /// an odd number of pixels wide (1x), a pixel's edge when even (2x).
    private func snap(_ value: CGFloat) -> CGFloat {
        let scale = max(1, displayScale)
        let offset: CGFloat = Int((HairlineRule.thickness * scale).rounded()) % 2 == 1 ? 0.5 : 0
        return ((value * scale - offset).rounded() + offset) / scale
    }
}

/// VoiceOver's tree (spec 5.2): read by relation, not by position. The tree's accessibility elements are these
/// groups, one each, in this order (the view applies them as its children, over their slots' frames): the person;
/// "Grandparents: Obed"; "Parents: Jesse"; the siblings ("7 siblings, folded" in the chip's place, ruling 29) and
/// half-siblings; each mother with her children ("Bathsheba, partner. Children: …", "Tamar, mother of Pharez and
/// Zerah"), then "4 more, folded" or, open, the folded mothers; the children with no named mother ("Children,
/// mother not named: 11, folded", Departure 4); or, with no mothers' row, "Children: …" and the chip.
///
/// Each name in a group is a named action that walks to that person. A group of one person, and a mother's group
/// (whose label starts with her name), is a link whose activation walks to that person; a folded chip is a button
/// that opens it; an open run's groups offer "Fewer". The keys are the tree's own (`FamilyTreeKeys`), not these.
enum FamilyTreeSpeech {
    enum Trait: Equatable { case link, button, text }

    enum Action: Equatable {
        case walk(PersonSummary), toggle(FamilyChip)

        /// The action's name in VoiceOver's actions: the person's name, or "Fewer".
        var name: String {
            switch self {
            case .walk(let person): person.name
            case .toggle: "Fewer"
            }
        }
    }

    struct Group: Equatable, Identifiable {
        /// The group's first slot.
        let id: String
        let label: String
        let trait: Trait
        /// What activating the element does; nil for a group of several names (each is an action).
        let primary: Action?
        let actions: [Action]
        /// The slots it reads, in the geometry; `frame` covers them.
        let slots: [String]
        let frame: CGRect
    }

    static func groups(_ tree: FamilyTree, geometry: FamilyTreeGeometry) -> [Group] {
        let slots = geometry.slots
        let frames = Dictionary(slots.map { ($0.id, $0.frame) }, uniquingKeysWith: { first, _ in first })
        var groups: [Group] = []
        /// A group over the slots of `ids` that are laid; none when none is.
        func add(_ label: String, ids: [String], trait: Trait? = nil, primary: Action? = nil, actions: [Action] = []) {
            let laid = ids.filter { frames[$0] != nil }
            guard let first = laid.first else { return }
            let walks = actions.filter { if case .walk = $0 { true } else { false } }
            let primary = primary ?? (walks.count == 1 ? walks.first : nil)
            let trait = trait ?? (primary == nil ? .text : .link)
            let frame = laid.compactMap { frames[$0] }.reduce(CGRect.null) { $0.union($1) }
            groups.append(Group(id: first, label: label, trait: trait, primary: primary, actions: actions, slots: laid, frame: frame))
        }
        func ids(_ kind: (FamilyTreeGeometry.Slot.Kind) -> Bool) -> [String] { slots.filter { kind($0.kind) }.map(\.id) }
        func fewer(_ chip: FamilyChip) -> (ids: [String], actions: [Action]) {
            frames["fewer-\(chip)"] == nil ? ([], []) : (["fewer-\(chip)"], [.toggle(chip)])
        }
        func folded(_ chip: FamilyChip) -> FamilyTreeGeometry.Slot? {
            slots.first { if case .chip(chip, _) = $0.kind { true } else { false } }
        }

        add(tree.person.name, ids: ["person"], trait: .text)
        var seen: Set<Int> = []
        let grandparents = tree.grandparents.map(\.person).filter { seen.insert($0.id).inserted }
        add("Grandparents: " + names(grandparents), ids: ids { if case .grandparent = $0 { true } else { false } }, actions: grandparents.map { .walk($0) })
        add("Parents: " + names(tree.parents), ids: ids { if case .parent = $0 { true } else { false } }, actions: tree.parents.map { .walk($0) })
        for (chip, people, title) in [(FamilyChip.siblings, tree.siblings, "Siblings"), (.halfSiblings, tree.halfSiblings, "Half-siblings")] {
            if let slot = folded(chip) {
                add(spoken(slot), ids: [slot.id], trait: .button, primary: .toggle(chip))
            } else {
                let prefix = chip == .siblings ? "sibling-" : "halfSibling-", run = fewer(chip)
                add("\(title): " + names(people), ids: people.map { prefix + "\($0.id)" } + run.ids, actions: people.map { .walk($0) } + run.actions)
            }
        }
        func household(_ household: FamilyTree.Household, closing run: (ids: [String], actions: [Action]) = ([], [])) {
            let head: PersonSummary
            switch household.head {
            case .partner(let person), .otherParent(let person, _): head = person
            case .notNamed: return
            }
            add(line(household), ids: ["head-\(household.id)"] + household.children.map { "child-\($0.id)" } + run.ids,
                primary: .walk(head), actions: [.walk(head)] + household.children.map { .walk($0) } + run.actions)
        }
        if tree.hasMothersRow {
            let (named, unnamed) = FamilyTreeFolding.mothers(of: tree)
            let foldedMothers = FamilyTreeFolding.folded(named, count: geometry.fold.foldedHouseholds)
            // The mothers left on the row, then the chip or, open, the mothers it folded.
            for mother in named where !foldedMothers.contains(mother) { household(mother) }
            if let slot = folded(.households) {
                add(spoken(slot), ids: [slot.id], trait: .button, primary: .toggle(.households))
            } else {
                // Each mother of the opened rows offers "Fewer"; its slot, which ends the last row, is in the last one's
                // group, so each group is drawn over its own column and none over another's.
                let run = fewer(.households)
                for mother in foldedMothers { household(mother, closing: (mother == foldedMothers.last ? run.ids : [], run.actions)) }
            }
            if let unnamed, case .notNamed(let relation) = unnamed.head {
                let title = "Children, " + FamilyTreeFolding.notNamedLabel(relation).lowercased()
                if let slot = folded(.notNamed) {
                    add("\(title): \(spoken(slot))", ids: ["head-\(unnamed.id)", slot.id], trait: .button, primary: .toggle(.notNamed))
                } else {
                    let run = fewer(.notNamed)
                    add("\(title): " + names(unnamed.children), ids: ["head-\(unnamed.id)"] + unnamed.children.map { "child-\($0.id)" } + run.ids,
                        actions: unnamed.children.map { .walk($0) } + run.actions)
                }
            }
        } else if !tree.children.isEmpty {
            let shown = tree.children.filter { frames["child-\($0.id)"] != nil }, run = fewer(.children)
            add("Children: " + names(shown), ids: shown.map { "child-\($0.id)" } + run.ids, actions: shown.map { .walk($0) } + run.actions)
            if let slot = folded(.children) { add(spoken(slot), ids: [slot.id], trait: .button, primary: .toggle(.children)) }
        }
        return groups
    }

    /// "Bathsheba, partner. Children: Nathan, Shobab", "Michal, partner", "Tamar, mother of Pharez and Zerah".
    private static func line(_ household: FamilyTree.Household) -> String {
        switch household.head {
        case .partner(let person): household.children.isEmpty ? "\(person.name), partner" : "\(person.name), partner. Children: " + names(household.children)
        case .otherParent(let person, let relation): "\(person.name), \(relation.rawValue) of \(list(household.children))"
        case .notNamed(let relation): FamilyTreeFolding.notNamedLabel(relation)
        }
    }

    private static func spoken(_ chip: FamilyTreeGeometry.Slot) -> String {
        if case .chip(_, let label) = chip.kind { return "\(label), folded" }
        return ""
    }

    private static func names(_ people: [PersonSummary]) -> String {
        people.map(\.name).joined(separator: ", ")
    }

    /// "Onan, Shelah and Er".
    private static func list(_ people: [PersonSummary]) -> String {
        let names = people.map(\.name)
        guard let last = names.last, names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }
}
#endif
