import CoreGraphics
import Foundation
import ScriptureData
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A count the Mac's tree folds names into (spec 5.2), and the phone's "and n more" (Task 11).
public enum FamilyChip: Hashable, Sendable { case siblings, halfSiblings, households, notNamed, children }

/// What the Mac's tree folds at one width (spec 5.2, Folding). `foldedHouseholds` counts the mothers'
/// row in `FamilyTreeFolding.folded`'s order, never the "not named" column; `childrenShown` nil shows
/// every child.
struct FamilyFold: Equatable, Sendable {
    var siblings = false, halfSiblings = false
    var foldedHouseholds = 0
    var notNamed = false
    var childrenShown: Int?
}

/// The tree's kinds of text, each with its own type style (spec 5.2, Rows).
enum FamilyTreeStyle: Sendable { case grandparent, name, person, child, chip, notNamedLabel }

/// A tree style's text style, weight and slant: what the measure sets and the view draws, so the two never disagree.
struct FamilyTreeText: Equatable {
    let style: Font.TextStyle
    var weight: Font.Weight?
    var italic = false
}

extension FamilyTreeStyle {
    /// The style in `type`: names in `.body`, the person semibold, a chip in `.callout`, "not named" in italic
    /// `.caption`; grandparents and children in the reading style (the reader size on the Mac's Library, Matt's
    /// review of 2026-11-24; `.callout` with the system's styles).
    func text(_ type: LibraryType) -> FamilyTreeText {
        switch self {
        case .name: FamilyTreeText(style: .body)
        case .person: FamilyTreeText(style: .body, weight: .semibold)
        case .chip: FamilyTreeText(style: .callout)
        case .notNamedLabel: FamilyTreeText(style: .caption, italic: true)
        case .grandparent, .child: FamilyTreeText(style: type.reading)
        }
    }
}

/// The size a name takes in the tree, its padding included (the person's wash, a chip's capsule).
protocol FamilyTreeMeasure {
    func size(_ text: String, _ style: FamilyTreeStyle) -> CGSize
}

#if os(macOS)
/// The tree's styles (`FamilyTreeStyle.text`) at `type`'s fonts, as the tree sets them, measured by Core Text as
/// `BookNameMeasure.width` is, widths and heights rounded up. Fonts are made per measure, never kept in a
/// `static let` (ruling 31), so a measure made after a change of the system's fonts sees it. Each text is measured
/// once per measure: the fold and the builder ask the same names many times over (a mothers' row once per fold tried).
struct SystemFamilyTreeMeasure: FamilyTreeMeasure {
    private let fonts: [FamilyTreeStyle: NSFont]
    private let chevron: CGSize
    private let known = Known()

    /// The sizes measured so far, by text and style.
    private final class Known {
        struct Key: Hashable {
            let text: String
            let style: FamilyTreeStyle
        }

        var sizes: [Key: CGSize] = [:]
    }

    init(type: LibraryType = .system) {
        let styles: [FamilyTreeStyle] = [.grandparent, .name, .person, .child, .chip, .notNamedLabel]
        fonts = Dictionary(uniqueKeysWithValues: styles.map { style in
            let text = style.text(type)
            return (style, type.platformFont(text.style, weight: text.weight?.platformWeight ?? .regular, italic: text.italic))
        })
        chevron = FamilyTreeChevron.size(type)
    }

    func size(_ text: String, _ style: FamilyTreeStyle) -> CGSize {
        let key = Known.Key(text: text, style: style)
        if let size = known.sizes[key] { return size }
        let size = measured(text, style)
        known.sizes[key] = size
        return size
    }

    private func measured(_ text: String, _ style: FamilyTreeStyle) -> CGSize {
        let label = Self.size(of: text, font: fonts[style] ?? .systemFont(ofSize: NSFont.systemFontSize))
        switch style {
        case .grandparent, .name, .child, .notNamedLabel: return label
        case .person:
            // On the `accent.wash`: `xs` at the sides, `xxs` above and below.
            return label.padded(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs)
        case .chip:
            // The count, `xxs`, the chevron (as `ChipLabel` spaces them), in a capsule `sm` at the sides, `xxs` above and below.
            return CGSize(width: label.width + AppSpacing.xxs + chevron.width, height: max(label.height, chevron.height))
                .padded(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs)
        }
    }

    private static func size(of text: String, font: NSFont) -> CGSize {
        CGSize(width: BookNameMeasure.width(of: text, font: font), height: (font.ascender - font.descender + font.leading).rounded(.up))
    }
}

/// A chip's chevron at the chip's own size (the reader's `.callout`, else the system's style), rounded up: what the
/// measure takes and the box the view draws the symbol in (`FamilyTreeChipLabel`). SwiftUI sets the symbol a point wider
/// or narrower than its `NSImage` at some sizes (the reader's 14 and 24 pt among them), so drawn at its own width a chip
/// at the tree's edge reached past the measured width.
enum FamilyTreeChevron {
    static func size(_ type: LibraryType) -> CGSize {
        let configuration = type.readerSize == nil
            ? NSImage.SymbolConfiguration(textStyle: .callout)
            : NSImage.SymbolConfiguration(pointSize: type.size(FamilyTreeStyle.chip.text(type).style), weight: .regular)
        let size = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?.withSymbolConfiguration(configuration)?.size ?? .zero
        return CGSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
    }
}
#endif

private extension CGSize {
    func padded(horizontal: CGFloat, vertical: CGFloat) -> CGSize {
        CGSize(width: width + 2 * horizontal, height: height + 2 * vertical)
    }
}

/// The folding rules of spec 5.2 ("the never scrolls sideways rule"), worked at one width.
enum FamilyTreeFolding {
    /// Between two names of a generation as spec 5.2 first had it ("with `sm` between them"): the default of `fold` and
    /// `FamilyTreeGeometry.make`, at which the tests' figures are worked. The view lays the tree at `gap(_:)`.
    static let gap = AppSpacing.sm

    /// The gap between two neighbouring names, columns or chips, in ems of the tree's `.body` (its names' size).
    /// Matt, 2026-11-24, of Lot's page in a wide window: "a comfortable/readable width between names horizontally that
    /// is evenly spread apart". At 1 em two short names ("Abigail Zeruiah") read as one name with a wide space; at
    /// 2 ems a large family folds sooner than it needs to; 1.5 ems keeps each name its own and a row compact.
    static let namesApart: CGFloat = 1.5

    /// The gap at `type`: `namesApart` ems of `.body`, to the point (27 at the reader's 18 pt, 20 with the system's
    /// styles), so it grows with the reader's size and is the same between every two names of the tree.
    static func gap(_ type: LibraryType) -> CGFloat {
        (type.size(.body) * namesApart).rounded()
    }
    /// "Mother not named" folds when taller than the tallest mother's column plus this many lines.
    static let notNamedSlack = 3

    /// A chip's text: "7 siblings", "1 sibling", "2 half-siblings", "3 more", "11", "5 more".
    static func chipLabel(_ chip: FamilyChip, count: Int) -> String {
        let number = count.formatted()
        return switch chip {
        case .siblings: "\(number) \(count == 1 ? "sibling" : "siblings")"
        case .halfSiblings: "\(number) \(count == 1 ? "half-sibling" : "half-siblings")"
        case .households, .children: "\(number) more"
        case .notNamed: number
        }
    }

    /// The "not named" column's label (spec 5.1; Departure 5).
    static func notNamedLabel(_ relation: Relation) -> String {
        relation == .father ? "Father not named" : "Mother not named"
    }

    /// Spec 5.2's folds at `width`:
    /// - the person's generation against the whole width (the person need not be centred): the siblings fold when the
    ///   siblings, the person and the half-siblings do not fit side by side a gap apart, then the half-siblings when
    ///   the siblings' chip, the person and theirs do not (Departure 11 places a chip that itself does not fit);
    /// - "Mother not named" folds by height, against every mother's column (ruling 28), when it holds more
    ///   than the tallest mother's children plus `notNamedSlack`; no width changes it (Departure 3);
    /// - the mothers' row then folds one more (`folded(_:count:)`'s order: the childless partners first)
    ///   until its columns, its "n more" column and the "not named" column fit with `gap` between them;
    /// - with no mothers' row, the children show as many names as fit with an "n more" chip after them.
    static func fold(_ tree: FamilyTree, width: CGFloat, gap: CGFloat = FamilyTreeFolding.gap, measure: some FamilyTreeMeasure) -> FamilyFold {
        var fold = FamilyFold()
        // The person's generation against the whole width (Judah's brothers, 2026-11-24): the siblings fold only when
        // the siblings, the person and the half-siblings do not fit side by side, one gap apart; then the half-siblings.
        let person = measure.size(tree.person.name, .person).width
        func fits(_ siblings: CGFloat, _ half: CGFloat) -> Bool {
            (siblings > 0 ? siblings + gap : 0) + person + (half > 0 ? half + gap : 0) <= width
        }
        // A side folds only into a chip that stands for two or more names and is narrower than them by more than a gap
        // (Matt, 2026-11-24, Benjamin's "1 sibling": a chip that saves no room is pointless). The folds tried in turn:
        // none, the siblings, the half-siblings, both; the first that fits, else every side that can fold.
        let siblingsRun = run(tree.siblings.map { measure.size($0.name, .name).width }, gap: gap)
        let halfRun = run(tree.halfSiblings.map { measure.size($0.name, .name).width }, gap: gap)
        let siblingsChip = measure.size(chipLabel(.siblings, count: tree.siblings.count), .chip).width
        let halfChip = measure.size(chipLabel(.halfSiblings, count: tree.halfSiblings.count), .chip).width
        let siblingsFold = savesRoom(count: tree.siblings.count, run: siblingsRun, chip: siblingsChip, gap: gap)
        let halfFold = savesRoom(count: tree.halfSiblings.count, run: halfRun, chip: halfChip, gap: gap)
        let tries = [(false, false), (true, false), (false, true), (true, true)].filter { (!$0.0 || siblingsFold) && (!$0.1 || halfFold) }
        let chosen = tries.first { fits($0.0 ? siblingsChip : siblingsRun, $0.1 ? halfChip : halfRun) } ?? (siblingsFold, halfFold)
        (fold.siblings, fold.halfSiblings) = chosen
        if tree.hasMothersRow {
            let (named, unnamed) = mothers(of: tree)
            if let unnamed {
                fold.notNamed = unnamed.children.count > (named.map(\.children.count).max() ?? 0) + notNamedSlack
            }
            let unnamedColumn = unnamed.map { [columnWidth($0, folded: fold.notNamed, measure: measure)] } ?? []
            // Never "1 more" (a chip for one mother saves nothing worth a click).
            fold.foldedHouseholds = ([0] + (named.count >= 2 ? Array(2...named.count) : [])).first { count in
                let chip = count == 0 ? [] : [measure.size(chipLabel(.households, count: count), .chip).width]
                let widths = shown(named, folding: count).map { columnWidth($0, folded: false, measure: measure) }
                return run(widths + chip + unnamedColumn, gap: gap) <= width
            } ?? (named.count >= 2 ? named.count : 0)
        } else if !tree.children.isEmpty {
            let widths = tree.children.map { measure.size($0.name, .child).width }
            // Never "1 more": at least two children go into the chip.
            if run(widths, gap: gap) > width, widths.count >= 2 {
                fold.childrenShown = (0...(widths.count - 2)).reversed().first { shown in
                    run(widths.prefix(shown) + [measure.size(chipLabel(.children, count: widths.count - shown), .chip).width], gap: gap) <= width
                } ?? 0
            }
        }
        return fold
    }

    /// Whether folding `count` names `run` wide into a chip `chip` wide is worth it: two names or more, and the chip
    /// narrower than them by more than a gap.
    static func savesRoom(count: Int, run: CGFloat, chip: CGFloat, gap: CGFloat) -> Bool {
        count >= 2 && chip + gap < run
    }

    /// Names side by side with `gap` between them; zero for none.
    static func run(_ widths: some Collection<CGFloat>, gap: CGFloat = FamilyTreeFolding.gap) -> CGFloat {
        widths.isEmpty ? 0 : widths.reduce(0, +) + gap * CGFloat(widths.count - 1)
    }

    /// The mothers' row's columns: the partners and named other parents, and the "not named" column.
    static func mothers(of tree: FamilyTree) -> (named: [FamilyTree.Household], notNamed: FamilyTree.Household?) {
        let named = tree.households.filter { if case .notNamed = $0.head { false } else { true } }
        return (named, tree.households.first { if case .notNamed = $0.head { true } else { false } })
    }

    /// The mothers that fold first, `count` of them, in the row's own order. Spec 5.2 folds the row "from
    /// its end (the childless partners first, by 5.1's order)": the childless partners from their end,
    /// then the other parents from theirs, then the partners with children from theirs.
    static func folded(_ named: [FamilyTree.Household], count: Int) -> [FamilyTree.Household] {
        func isPartner(_ household: FamilyTree.Household) -> Bool { if case .partner = household.head { true } else { false } }
        let order = named.filter { isPartner($0) && $0.children.isEmpty }.reversed()
            + named.filter { !isPartner($0) }.reversed()
            + named.filter { isPartner($0) && !$0.children.isEmpty }.reversed()
        let ids = Set(order.prefix(count).map(\.id))
        return named.filter { ids.contains($0.id) }
    }

    /// The mothers left on the row when `count` fold, in the row's order.
    static func shown(_ named: [FamilyTree.Household], folding count: Int) -> [FamilyTree.Household] {
        let ids = Set(folded(named, count: count).map(\.id))
        return named.filter { !ids.contains($0.id) }
    }

    /// Each width's share of `available` with `gap` between them: all of it when the run fits; else the
    /// narrower ones keep their widths and the rest share what is left equally (max-min fairness).
    static func shares(_ widths: [CGFloat], within available: CGFloat, gap: CGFloat = FamilyTreeFolding.gap) -> [CGFloat] {
        let room = available - gap * CGFloat(max(0, widths.count - 1))
        guard run(widths, gap: gap) > available, !widths.isEmpty else { return widths }
        var left = room, count = CGFloat(widths.count), share = room / count
        for width in widths.sorted() {
            share = left / count
            guard width <= share else { break }
            left -= width
            count -= 1
        }
        return widths.map { min($0, share) }
    }

    /// A column is as wide as the widest of its head, its children and its chip.
    static func columnWidth(_ household: FamilyTree.Household, folded: Bool, measure: some FamilyTreeMeasure) -> CGFloat {
        let below = folded
            ? [measure.size(chipLabel(.notNamed, count: household.children.count), .chip).width]
            : household.children.map { measure.size($0.name, .child).width }
        return ([headSize(household, measure: measure).width] + below).max() ?? 0
    }

    static func headSize(_ household: FamilyTree.Household, measure: some FamilyTreeMeasure) -> CGSize {
        switch household.head {
        case .partner(let person), .otherParent(let person, _): measure.size(person.name, .name)
        case .notNamed(let relation): measure.size(notNamedLabel(relation), .notNamedLabel)
        }
    }
}

/// The Mac's tree as frames and lines at one width (spec 5.2), for the view's `Layout` and `Canvas`
/// (Task 9) and its keys (Task 10). Computed once per width and set of open chips.
struct FamilyTreeGeometry: Equatable {
    struct Slot: Equatable, Identifiable {
        enum Kind: Equatable {
            case grandparent(PersonSummary), parent(PersonSummary, Relation), person
            case sibling(PersonSummary), halfSibling(PersonSummary)
            case head(FamilyTree.Household), child(PersonSummary, household: String?), notNamedLabel(Relation)
            case chip(FamilyChip, label: String), fewer(FamilyChip)
        }

        /// Stable across widths and folds ("person", "sibling-44", "chip-siblings"), for focus.
        let id: String
        let kind: Kind
        let frame: CGRect
        /// The name is narrower than it measures: cut to fit its share of the column, the last resort of
        /// "never a sideways scroll" (Task 12); the view draws it tail-truncated and keeps it whole in help.
        var truncated = false
    }

    struct Line: Equatable {
        let from: CGPoint, to: CGPoint
        let dashed: Bool
    }

    let fold: FamilyFold
    let slots: [Slot]
    let lines: [Line]
    let size: CGSize
    /// Departure 11's narrowest form: the person stands under the siblings' and half-siblings' chips, on a lane.
    let personStacked: Bool
    /// The rows an opened "n more" takes (Matt's B, 2026-11-24); 0 while it is closed or there is none.
    let householdRows: Int

    /// Rows top to bottom (spec 5.2): grandparents, parents, the person's generation, then the mothers'
    /// row and its children, or the children alone. Generations are `lg` apart, a bar `xs` above the row
    /// it joins; an open chip's names are a band under its generation, an opened "n more" further rows of the
    /// tree (Departure 10).
    static func make(_ tree: FamilyTree, width: CGFloat, open: Set<FamilyChip>, rowPitch: CGFloat, gap: CGFloat = FamilyTreeFolding.gap,
                     measure: some FamilyTreeMeasure) -> FamilyTreeGeometry {
        var builder = FamilyTreeBuilder(tree: tree, width: width, open: open, rowPitch: rowPitch, gap: gap, measure: measure,
                                        fold: FamilyTreeFolding.fold(tree, width: width, gap: gap, measure: measure))
        builder.build()
        return FamilyTreeGeometry(fold: builder.fold, slots: builder.slots, lines: builder.lines,
                                  size: CGSize(width: width, height: builder.slots.map(\.frame.maxY).max() ?? 0),
                                  personStacked: builder.personStacked, householdRows: builder.householdRows)
    }
}

/// When the Mac lays a person's family as the tree and when as the phone's family line (Matt, 2026-11-24: "at a certain
/// point it should just fallback to the same family tree design of the iOS app"). Pure: worked from a width, a gap and a
/// measure, never from a view's own size, so the page decides once from the width it reads.
enum FamilyTreeLayoutRule {
    /// Whether `tree` is laid as a tree at `width`: with its "n more" and its "not named" chip open (the most rows it can
    /// need: the eleven's join keeps the opened mothers to its leading side), no name is cut to fit (nor so any column's
    /// children), the person's generation is not Departure 11's stacked form (the person under the chips, the very narrow
    /// case), and the opened "n more" is one row ("Fewer" alone on a third counts as two).
    static func fitsAsTree(_ tree: FamilyTree, width: CGFloat, gap: CGFloat, measure: some FamilyTreeMeasure) -> Bool {
        // Only widths decide, so any row pitch will do: the tree's own base, `md`.
        let laid = FamilyTreeGeometry.make(tree, width: width, open: [.households, .notNamed], rowPitch: AppSpacing.md, gap: gap,
                                           measure: measure)
        return !laid.personStacked && laid.householdRows <= 1 && !laid.slots.contains(where: \.truncated)
    }

    #if os(macOS)
    /// `fitsAsTree` at `type`'s fonts and gap, as the view lays the tree.
    static func fitsAsTree(_ tree: FamilyTree, width: CGFloat, type: LibraryType) -> Bool {
        fitsAsTree(tree, width: width, gap: FamilyTreeFolding.gap(type), measure: SystemFamilyTreeMeasure(type: type))
    }
    #endif
}

/// Lays out one `FamilyTreeGeometry`. Between neighbours on a line, `gap`; every other gap is a step on `AppSpacing`.
private struct FamilyTreeBuilder<Measure: FamilyTreeMeasure> {
    typealias Slot = FamilyTreeGeometry.Slot
    typealias Line = FamilyTreeGeometry.Line

    /// A slot to be placed: its id, kind and measured size.
    struct Item {
        let id: String
        let kind: Slot.Kind
        var size: CGSize
        var dashed = false
        var truncated = false
    }

    /// A vertical line ending on a row: where it lands and whether it is the half-siblings'.
    struct Target {
        let x: CGFloat, y: CGFloat
        let dashed: Bool
    }

    let tree: FamilyTree, width: CGFloat, open: Set<FamilyChip>, rowPitch: CGFloat, measure: Measure
    let fold: FamilyFold
    /// Between every two neighbours: names, columns, chips, "Fewer" and a lane.
    let gap: CGFloat
    private(set) var slots: [Slot] = []
    private(set) var lines: [Line] = []
    /// What `FamilyTreeLayoutRule` reads: the person stacked under the chips, and the opened "n more"'s rows.
    private(set) var personStacked = false
    private(set) var householdRows = 0
    private var centre: CGFloat { width / 2 }

    init(tree: FamilyTree, width: CGFloat, open: Set<FamilyChip>, rowPitch: CGFloat, gap: CGFloat, measure: Measure, fold: FamilyFold) {
        (self.tree, self.width, self.open, self.rowPitch, self.gap, self.measure, self.fold) = (tree, width, open, rowPitch, gap, measure, fold)
    }

    /// Names side by side at this tree's gap.
    private func run(_ widths: some Collection<CGFloat>) -> CGFloat { FamilyTreeFolding.run(widths, gap: gap) }

    /// Each width's share of `available` at this tree's gap.
    private func shares(_ widths: [CGFloat], within available: CGFloat) -> [CGFloat] {
        FamilyTreeFolding.shares(widths, within: available, gap: gap)
    }

    /// Where a generation's drop to the next starts, and its bottom (its open chips' bands included).
    struct Generation {
        let feed: CGPoint
        let bottom: CGFloat
    }

    mutating func build() {
        var row = personRow(towards: centre)
        // The parents are laid over the person; where their grandparents hold them off it (kept inside the width), the
        // person moves under them as far as its row lets it, so the drop stays straight wherever it can.
        if let personX = row.personX, !tree.parents.isEmpty {
            var trial = self
            if let drop = trial.ancestors(over: personX + row.person.size.width / 2)?.x { row = personRow(towards: drop) }
        }
        let generation = generation(row, below: ancestors(over: row.personX.map { $0 + row.person.size.width / 2 } ?? centre))
        if tree.hasMothersRow {
            mothersRow(generation)
        } else if !tree.children.isEmpty {
            childrenRow(generation)
        }
    }

    // MARK: - Rows 1 and 2: grandparents and parents

    /// Each parent centred with its own parents over it (ruling 6), a pair's centres either side of it;
    /// two parents either side of the column's centre, far enough apart for both families. Returns where
    /// the parents' drop starts: under a lone parent, or the midpoint of the two parents' bar.
    private mutating func ancestors(over personMidX: CGFloat) -> CGPoint? {
        let parents = [tree.father.map { ($0, Relation.father) }, tree.mother.map { ($0, Relation.mother) }].compactMap { $0 }
        guard !parents.isEmpty else { return nil }
        // Each parent's unit: the parent at 0, its grandparents laid with `gap` and centred over it; a unit
        // wider than its share of the column has its names cut to fit (the last resort).
        var named = parents.map { parent, relation in
            (item: Item(id: "parent-\(parent.id)", kind: .parent(parent, relation), size: measure.size(parent.name, .name)),
             above: tree.grandparents.filter { $0.parentID == parent.id }.map { grandparent in
                 Item(id: "grandparent-\(grandparent.person.id)-\(parent.id)", kind: .grandparent(grandparent.person),
                      size: measure.size(grandparent.person.name, .grandparent))
             })
        }
        let unitShares = shares(named.map { max($0.item.size.width, run($0.above.map(\.size.width))) }, within: width)
        named = zip(named, unitShares).map { unit, share in (fit(unit.item, to: share), fit(unit.above, within: share)) }
        let units = named.map { item, above in
            let size = item.size
            var offsets = runOffsets(above.map(\.size.width))
            if let first = offsets.first, let last = offsets.last, let firstItem = above.first, let lastItem = above.last {
                let middle = (first + firstItem.size.width / 2 + last + lastItem.size.width / 2) / 2
                offsets = offsets.map { $0 - middle }
            }
            let left = max(size.width / 2, -(offsets.first ?? 0)), right = max(size.width / 2, zip(offsets, above).map { $0 + $1.size.width }.max() ?? 0)
            return (item: item, above: above, offsets: offsets, left: left, right: right)
        }
        var anchors = [CGFloat](repeating: 0, count: units.count)
        for index in units.indices.dropFirst() {
            anchors[index] = anchors[index - 1] + units[index - 1].right + gap + units[index].left
        }
        let shift = clamp(start: (anchors.first ?? 0) - units[0].left, end: (anchors.last ?? 0) + (units.last?.right ?? 0),
                          centredOn: ((anchors.first ?? 0) + (anchors.last ?? 0)) / 2, at: personMidX)
        anchors = anchors.map { $0 + shift }

        let grandparentHeight = units.flatMap(\.above).map(\.size.height).max() ?? 0
        let parentsTop = grandparentHeight > 0 ? grandparentHeight + AppSpacing.lg : 0
        let parentHeight = units.map(\.item.size.height).max() ?? 0
        var placedParents: [CGRect] = []
        for (unit, anchor) in zip(units, anchors) {
            let parent = place(unit.item, midX: anchor, rowTop: parentsTop, rowHeight: parentHeight)
            placedParents.append(parent)
            let placed = zip(unit.above, unit.offsets).map { item, offset in
                place(item, minX: anchor + offset, rowTop: 0, rowHeight: grandparentHeight)
            }
            // A lone grandparent drops straight to its parent; a pair joins on a bar `xs` below the row.
            if placed.count == 1, let only = placed.first {
                lines.append(Line(from: CGPoint(x: only.midX, y: only.maxY), to: CGPoint(x: parent.midX, y: parent.minY), dashed: false))
            } else if placed.count > 1 {
                couple(placed, barY: grandparentHeight + AppSpacing.xs, dropTo: parent.minY)
            }
        }
        if placedParents.count == 1, let only = placedParents.first { return CGPoint(x: only.midX, y: only.maxY) }
        let barY = parentsTop + parentHeight + AppSpacing.xs
        return couple(placedParents, barY: barY, dropTo: nil)
    }

    /// Two (or more) of one generation joined: a drop from each to a bar between their centres, then a
    /// drop from the bar's midpoint to `dropTo` when given. Returns the midpoint.
    @discardableResult
    private mutating func couple(_ frames: [CGRect], barY: CGFloat, dropTo: CGFloat?) -> CGPoint {
        let xs = frames.map(\.midX)
        let middle = CGPoint(x: ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2, y: barY)
        for frame in frames {
            lines.append(Line(from: CGPoint(x: frame.midX, y: frame.maxY), to: CGPoint(x: frame.midX, y: barY), dashed: false))
        }
        lines.append(Line(from: CGPoint(x: xs.min() ?? 0, y: barY), to: CGPoint(x: xs.max() ?? 0, y: barY), dashed: false))
        if let dropTo { lines.append(Line(from: middle, to: CGPoint(x: middle.x, y: dropTo), dashed: false)) }
        return middle
    }

    // MARK: - Row 3: the person's generation

    /// The siblings to the leading side, the half-siblings (dashed) to the trailing side, the person as near the
    /// centre as they let it be (`personRow`); the siblings' run ends a gap before the person and the half-siblings'
    /// starts a gap after it, so a small family stays together in a wide column (Matt, 2026-11-24), and the parents
    /// are laid over the person wherever it stands. Departure 11: when they do not fit side by side, the
    /// siblings and the half-siblings share a row either side of a lane, and the person stands under them
    /// on the lane. Every one of them hangs from the parents' bar, the person by a rise down the lane, so
    /// no one hangs from a chip (the final review's Important 1); the next generation hangs from the person.
    /// The person's generation's items and where the person stands: the siblings, the person and the half-siblings
    /// side by side one gap apart, the person as near the column's centre as that lets them (off-centre when one side
    /// is long: Judah's brothers, 2026-11-24), or as near the parents' drop where the grandparents hold the parents off
    /// the centre (`build`); nil when they do not fit side by side (Departure 11's stacked rows).
    struct PersonRow {
        let siblings: [Item], person: Item, half: [Item]
        let personX: CGFloat?
    }

    /// The row with the person's middle as near `target` (the column's centre, or the parents' drop) as the sides let it.
    private func personRow(towards target: CGFloat) -> PersonRow {
        let person = Item(id: "person", kind: .person, size: measure.size(tree.person.name, .person))
        let siblings = side(tree.siblings, folded: fold.siblings, chip: .siblings)
        let half = side(tree.halfSiblings, folded: fold.halfSiblings, chip: .halfSiblings)
        let lead = siblings.isEmpty ? 0 : run(siblings.map(\.size.width)) + gap
        let trail = half.isEmpty ? 0 : run(half.map(\.size.width)) + gap
        guard lead + person.size.width + trail <= width else { return PersonRow(siblings: siblings, person: person, half: half, personX: nil) }
        let personX = min(max(target - person.size.width / 2, lead), width - person.size.width - trail)
        return PersonRow(siblings: siblings, person: person, half: half, personX: personX)
    }

    private mutating func generation(_ laidRow: PersonRow, below parentsDrop: CGPoint?) -> Generation {
        let (siblings, person, half) = (laidRow.siblings, laidRow.person, laidRow.half)
        let row: [(Item, CGFloat)]
        var lane: (x: CGFloat, person: Item)?
        if let personX = laidRow.personX {
            row = laid(siblings, from: personX - gap - run(siblings.map(\.size.width))) + [(person, personX)]
                + laid(half, from: personX + person.size.width + gap)
        } else {
            let laid = stacked(siblings, person, half, under: parentsDrop?.x ?? centre)
            (row, lane) = (laid.row, (laid.lane, laid.person))
            personStacked = true
        }
        let below = tree.hasMothersRow || !tree.children.isEmpty
        // A bar sits `xs` above its row: `lg` under a lone parent, `md` under the parents' own bar.
        let top = parentsDrop.map { $0.y + AppSpacing.lg - (tree.parents.count > 1 ? AppSpacing.xs : 0) }
            ?? (siblings.isEmpty && half.isEmpty ? 0 : AppSpacing.md)
        let height = row.map(\.0.size.height).max() ?? 0
        var targets: [Target] = [], bands: [(chip: FamilyChip, target: Int)] = []
        var personFrame: CGRect?
        for (item, minX) in row {
            if case .chip(let chip, _) = item.kind, open.contains(chip) {
                bands.append((chip, targets.count))
                targets.append(Target(x: minX + item.size.width / 2, y: 0, dashed: item.dashed))
                continue
            }
            let frame = place(item, minX: minX, rowTop: top, rowHeight: height)
            if item.kind == .person { personFrame = frame }
            targets.append(Target(x: frame.midX, y: frame.minY, dashed: item.dashed))
        }
        var bottom = top + height
        if let lane {
            // The person's rise passes down the lane, between the sides and between their open runs.
            bottom = sideBands(bands, targets: &targets, below: bottom, drop: lane.x, person: nil, keepingSides: true)
            let frame = place(lane.person, midX: lane.x, rowTop: row.isEmpty ? top : bottom + AppSpacing.md, rowHeight: 0)
            targets.append(Target(x: frame.midX, y: frame.minY, dashed: false))
            (personFrame, bottom) = (frame, frame.maxY)
        } else {
            // Only the person's drop passes through the bands.
            bottom = sideBands(bands, targets: &targets, below: bottom, drop: below ? personFrame?.midX : nil, person: personFrame)
        }
        hang(targets, from: parentsDrop, barY: top - AppSpacing.xs)
        return Generation(feed: personFrame.map { CGPoint(x: $0.midX, y: $0.maxY) } ?? CGPoint(x: centre, y: bottom), bottom: bottom)
    }

    /// Departure 11's narrowest case: the siblings to the leading side of a lane and the half-siblings to the
    /// trailing side, `gap / 2` clear of it (as a run keeps clear of a lane), the lane under the parents' drop
    /// where both sides fit, else moved the least that lets them; the person (cut to the column if wider) is
    /// laid on the lane, under the row. The sides are cut to fit, the last resort, when even that is too narrow.
    private func stacked(_ siblings: [Item], _ person: Item, _ half: [Item], under drop: CGFloat)
        -> (row: [(Item, CGFloat)], lane: CGFloat, person: Item) {
        let margin = gap / 2
        let person = fit(person, to: width), reach = person.size.width / 2
        var left = siblings, right = half
        let both = !left.isEmpty && !right.isEmpty
        // Each side, with its margin, within the column; both sides together within it less two margins.
        if both {
            let sides = shares([run(left.map(\.size.width)), run(right.map(\.size.width))], within: width - 2 * margin + gap)
            (left, right) = (fit(left, within: sides[0]), fit(right, within: sides[1]))
        }
        // Each side short enough to leave the person's lane its reach from either edge, so the person, centred on the
        // lane, stays inside the column (a side of one name, which never folds into a chip, can be as wide as the column).
        left = fit(left, within: width - margin - reach)
        right = fit(right, within: width - margin - reach)
        let (leading, trailing) = (run(left.map(\.size.width)), run(right.map(\.size.width)))
        let low = max(left.isEmpty ? 0 : leading + margin, reach)
        let high = min(right.isEmpty ? width : width - trailing - margin, width - reach)
        let lane = min(max(drop, low), max(low, high))
        let row = centred(left, in: 0...max(0, lane - margin)) + centred(right, in: min(width, lane + margin)...width)
        return (row, lane, person)
    }

    /// The open sides' runs under their row, each hung from a bar of its own (Departure 10): the siblings in
    /// the leading side (to the person's drop less `gap / 2`), the half-siblings in the trailing side, side by
    /// side, so the drop never crosses them (in Departure 11's stacked case, the person's rise down the lane).
    /// When a side's run cannot keep to its side (a name wider than the side), the runs are the tree's width
    /// one under the other, keeping clear of the drop and the later run's join; `keepingSides` (the stacked
    /// case, where the drop runs down from the bar) keeps each run to its side, a name too wide for it cut to
    /// fit (the last resort). Returns the bottom.
    private mutating func sideBands(_ bands: [(chip: FamilyChip, target: Int)], targets: inout [Target], below row: CGFloat,
                                    drop: CGFloat?, person: CGRect?, keepingSides: Bool = false) -> CGFloat {
        guard !bands.isEmpty else { return row }
        let split = drop ?? person?.midX ?? centre
        func items(_ chip: FamilyChip) -> [Item] {
            (chip == .siblings ? tree.siblings : tree.halfSiblings).map { sideItem($0, chip) } + [fewer(chip)]
        }
        func range(_ chip: FamilyChip) -> ClosedRange<CGFloat> {
            chip == .siblings ? 0...max(0, split - gap / 2) : min(width, split + gap / 2)...width
        }
        let top = row + AppSpacing.sm
        let sideBySide = keepingSides || bands.allSatisfy { band in
            let side = range(band.chip), joinX = targets[band.target].x
            return side.contains(joinX) && items(band.chip).allSatisfy { $0.size.width <= side.upperBound - side.lowerBound }
        }
        var bottom = row
        for (number, band) in bands.enumerated() {
            let joinX = targets[band.target].x, bandTop = sideBySide ? top : bottom + AppSpacing.sm
            targets[band.target] = Target(x: joinX, y: bandTop, dashed: targets[band.target].dashed)
            let lanes = sideBySide ? [] : [drop].compactMap { $0 } + bands[(number + 1)...].map { targets[$0.target].x }
            let end = self.band(items(band.chip), joinX: joinX, top: bandTop, in: sideBySide ? range(band.chip) : 0...width,
                                lanes: lanes, dashed: band.chip == .halfSiblings)
            bottom = sideBySide ? max(bottom, end) : end
        }
        return bottom
    }

    /// A side of the person's generation: its names, or its chip when folded; the half-siblings dashed.
    private func side(_ people: [PersonSummary], folded: Bool, chip: FamilyChip) -> [Item] {
        guard !people.isEmpty else { return [] }
        guard folded else { return people.map { sideItem($0, chip) } }
        let label = FamilyTreeFolding.chipLabel(chip, count: people.count)
        return [Item(id: "chip-\(chip)", kind: .chip(chip, label: label), size: measure.size(label, .chip), dashed: chip == .halfSiblings)]
    }

    private func sideItem(_ person: PersonSummary, _ chip: FamilyChip) -> Item {
        let size = measure.size(person.name, .name)
        return chip == .siblings
            ? Item(id: "sibling-\(person.id)", kind: .sibling(person), size: size)
            : Item(id: "halfSibling-\(person.id)", kind: .halfSibling(person), size: size, dashed: true)
    }

    private func fewer(_ chip: FamilyChip) -> Item {
        Item(id: "fewer-\(chip)", kind: .fewer(chip), size: measure.size("Fewer", .chip))
    }

    // MARK: - Rows 4 and 5: the mothers' row and its children

    /// The columns side by side a gap apart, centred under the person's drop and kept inside the column (never
    /// spread across it, Matt, 2026-11-24): the shown mothers, the "n more" chip, the "not named" column; each column's
    /// children stacked under its head's centre, one `rowPitch` apart. An opened "n more" is further rows of columns under the tallest column
    /// (`foldedRows`), its column on this row left empty; an opened eleven is a band under them.
    private mutating func mothersRow(_ above: Generation) {
        let (named, unnamed) = FamilyTreeFolding.mothers(of: tree)
        let shown = FamilyTreeFolding.shown(named, folding: fold.foldedHouseholds)
        let folded = FamilyTreeFolding.folded(named, count: fold.foldedHouseholds)
        let label = FamilyTreeFolding.chipLabel(.households, count: folded.count)
        let chip = folded.isEmpty ? [] : [Item(id: "chip-households", kind: .chip(.households, label: label), size: measure.size(label, .chip))]
        // A column wider than its share of the column (the row folded as far as it goes) has its names cut to fit.
        let columns = shares(shown.map { FamilyTreeFolding.columnWidth($0, folded: false, measure: measure) } + chip.map(\.size.width)
            + (unnamed.map { [FamilyTreeFolding.columnWidth($0, folded: fold.notNamed, measure: measure)] } ?? []), within: width)
        let heads = zip(shown.map(head) + chip + (unnamed.map { [head($0)] } ?? []), columns).map { fit($0, to: $1) }
        let mids = packed(columns, under: above.feed.x, in: 0...width)
        let top = above.bottom + AppSpacing.lg, height = heads.map(\.size.height).max() ?? 0
        let childTop = top + height + AppSpacing.sm
        var targets: [Target] = [], bottom = top + height
        var householdsTarget: Int?, unnamedJoin: CGPoint?
        for ((item, mid), share) in zip(zip(heads, mids), columns) {
            if case .chip = item.kind, open.contains(.households) {
                householdsTarget = targets.count
                targets.append(Target(x: mid, y: 0, dashed: false))
                continue
            }
            let frame = place(item, midX: mid, rowTop: top, rowHeight: height)
            targets.append(Target(x: mid, y: frame.minY, dashed: false))
            switch item.kind {
            case .head(let household):
                bottom = max(bottom, stack(household, under: frame, top: childTop, within: share))
            case .notNamedLabel:
                guard let unnamed else { break }
                if !fold.notNamed {
                    bottom = max(bottom, stack(unnamed, under: frame, top: childTop, within: share))
                } else if open.contains(.notNamed) {
                    unnamedJoin = CGPoint(x: mid, y: frame.maxY)
                } else {
                    let count = FamilyTreeFolding.chipLabel(.notNamed, count: unnamed.children.count)
                    let chip = place(fit(Item(id: "chip-notNamed", kind: .chip(.notNamed, label: count), size: measure.size(count, .chip)), to: share),
                                     midX: mid, rowTop: childTop, rowHeight: 0)
                    lines.append(Line(from: CGPoint(x: mid, y: frame.maxY), to: CGPoint(x: mid, y: chip.minY), dashed: false))
                    bottom = max(bottom, chip.maxY)
                }
            default: break
            }
        }
        // The opened "n more" as rows of the tree under this one (Matt's B, 2026-11-24), then the eleven's run. The eleven's
        // join (at the trailing side, the "not named" column being last) passes the rows, so they keep to its leading side.
        if let householdsTarget {
            let end = unnamedJoin.map { max(0, $0.x - gap / 2) } ?? width
            let rows = foldedRows(folded, joinX: mids[shown.count], below: bottom, in: 0...end, under: above.feed.x)
            targets[householdsTarget] = Target(x: mids[shown.count], y: rows.barY, dashed: false)
            bottom = rows.bottom
        }
        if let unnamedJoin, let unnamed {
            lines.append(Line(from: unnamedJoin, to: CGPoint(x: unnamedJoin.x, y: bottom + AppSpacing.sm), dashed: false))
            band(children(unnamed) + [fewer(.notNamed)], joinX: unnamedJoin.x, top: bottom + AppSpacing.sm,
                 in: 0...width, lanes: [], dashed: false)
        }
        hang(targets, from: above.feed, barY: top - AppSpacing.xs)
    }

    /// An opened "n more" (Departure 10 as Matt chose it, 2026-11-24, B): its mothers as further rows of the tree, the
    /// first `lg` under `bottom`, each mother a column as on the row above (her head, her children stacked under its
    /// centre) and "Fewer" ending the last row, hung from the row's bar as the heads are; each row's columns side by side a
    /// gap apart, centred under the person's drop (`feed`) and kept inside `range`. The first row's bar reaches `joinX`,
    /// where the chip's column stays empty above, and the row above's rise there meets it. A row too wide for `range`
    /// continues on the next: the row keeps a lane (a column of no width) a gap after its last column, and a vertical down
    /// the lane joins its bar to the next row's. A lane rather than a gap between two columns (a call): a row of one column
    /// has no gap, and the lane is `gap` from every name in its row.
    /// Returns the first row's bar and the last row's bottom.
    private mutating func foldedRows(_ folded: [FamilyTree.Household], joinX: CGFloat, below bottom: CGFloat,
                                     in range: ClosedRange<CGFloat>, under feed: CGFloat) -> (barY: CGFloat, bottom: CGFloat) {
        let span = range.upperBound - range.lowerBound, close = fewer(.households)
        let items = folded.map(head) + [close]
        let widths = folded.map { FamilyTreeFolding.columnWidth($0, folded: false, measure: measure) } + [close.size.width]
        // Every column that is left when they fit; else as many as fit with the lane.
        var rows: [[Int]] = [[]], next = 0
        while next < items.count {
            let row = rows[rows.count - 1], rest = Array(next..<items.count)
            if run((row + rest).map { widths[$0] }) <= span {
                rows[rows.count - 1] += rest
                break
            }
            if row.isEmpty || run((row + [next]).map { widths[$0] } + [0]) <= span {
                rows[rows.count - 1].append(next)
                next += 1
            } else {
                rows.append([])
            }
        }
        householdRows = rows.count
        var top = bottom + AppSpacing.lg, join = joinX, end = bottom
        var firstBar: CGFloat?, barAbove: CGFloat?
        for (number, row) in rows.enumerated() {
            let continues = number < rows.count - 1, barY = top - AppSpacing.xs
            // A column wider than its share of the row (the lane's room kept) has its names cut to fit, the last resort.
            let columns = shares(row.map { widths[$0] }, within: continues ? span - gap : span)
            let mids = packed(columns + (continues ? [0] : []), under: feed, in: range)
            let heads = zip(row, columns).map { fit(items[$0], to: $1) }
            let height = heads.map(\.size.height).max() ?? 0
            var rises: [Target] = []
            end = top + height
            for ((item, mid), share) in zip(zip(heads, mids), columns) {
                let frame = place(item, midX: mid, rowTop: top, rowHeight: height)
                rises.append(Target(x: mid, y: frame.minY, dashed: false))
                if case .head(let household) = item.kind {
                    end = max(end, stack(household, under: frame, top: top + height + AppSpacing.sm, within: share))
                }
            }
            if let barAbove { lines.append(Line(from: CGPoint(x: join, y: barAbove), to: CGPoint(x: join, y: barY), dashed: false)) }
            let lane = continues ? mids.last : nil
            bar(rises, joins: [join] + (lane.map { [$0] } ?? []), at: barY)
            (firstBar, barAbove, join, top) = (firstBar ?? barY, barY, lane ?? join, end + AppSpacing.lg)
        }
        return (firstBar ?? bottom, end)
    }

    /// Columns side by side a gap apart, the run centred on `x` and moved the least that keeps it inside `range`: their
    /// centres. A run wider than `range` starts at its leading edge.
    private func packed(_ columns: [CGFloat], under x: CGFloat, in range: ClosedRange<CGFloat>) -> [CGFloat] {
        let start = packedStart(run(columns), under: x, in: range)
        return zip(columns, runOffsets(columns)).map { start + $1 + $0 / 2 }
    }

    /// Where a run `total` wide starts, centred on `x` and kept inside `range` (at its leading edge when wider).
    private func packedStart(_ total: CGFloat, under x: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
        max(range.lowerBound, min(x - total / 2, range.upperBound - total))
    }

    private func head(_ household: FamilyTree.Household) -> Item {
        let size = FamilyTreeFolding.headSize(household, measure: measure)
        if case .notNamed(let relation) = household.head {
            return Item(id: "head-\(household.id)", kind: .notNamedLabel(relation), size: size)
        }
        return Item(id: "head-\(household.id)", kind: .head(household), size: size)
    }

    private func children(_ household: FamilyTree.Household?) -> [Item] {
        let people = household?.children ?? tree.children
        return people.map { Item(id: "child-\($0.id)", kind: .child($0, household: household?.id), size: measure.size($0.name, .child)) }
    }

    /// A column's children under its head (each cut to the column's `share` if wider), one `rowPitch` apart (or a name's height, if more), the first hung from the head. Returns the bottom.
    private mutating func stack(_ household: FamilyTree.Household, under head: CGRect, top: CGFloat, within share: CGFloat) -> CGFloat {
        var bottom = head.maxY
        let items = children(household).map { fit($0, to: share) }
        // As `flow`: never closer than a name's own height, whatever `rowPitch` is.
        let pitch = max(rowPitch, items.map(\.size.height).max() ?? 0)
        for (index, item) in items.enumerated() {
            let frame = place(item, midX: head.midX, rowTop: top + CGFloat(index) * pitch, rowHeight: 0)
            if index == 0 { lines.append(Line(from: CGPoint(x: head.midX, y: head.maxY), to: CGPoint(x: head.midX, y: frame.minY), dashed: false)) }
            bottom = frame.maxY
        }
        return bottom
    }

    // MARK: - Row 4 without a mothers' row: the children

    /// The children side by side a gap apart, centred under the person's drop, as many as fit, then an "n more" chip.
    private mutating func childrenRow(_ above: Generation) {
        let all = children(nil), shownCount = fold.childrenShown ?? all.count
        let hidden = Array(all.dropFirst(shownCount))
        let label = FamilyTreeFolding.chipLabel(.children, count: hidden.count)
        let items = all.prefix(shownCount) + (hidden.isEmpty ? [] : [Item(id: "chip-children", kind: .chip(.children, label: label), size: measure.size(label, .chip))])
        let top = above.bottom + AppSpacing.lg, height = items.map(\.size.height).max() ?? 0
        var targets: [Target] = []
        let start = packedStart(run(items.map(\.size.width)), under: above.feed.x, in: 0...width)
        for (item, minX) in laid(Array(items), from: start) {
            if case .chip = item.kind, open.contains(.children) {
                targets.append(Target(x: minX + item.size.width / 2, y: top + height + AppSpacing.sm, dashed: false))
                band(hidden + [fewer(.children)], joinX: minX + item.size.width / 2, top: top + height + AppSpacing.sm,
                     in: 0...width, lanes: [], dashed: false)
                continue
            }
            let frame = place(item, minX: minX, rowTop: top, rowHeight: height)
            targets.append(Target(x: frame.midX, y: frame.minY, dashed: false))
        }
        hang(targets, from: above.feed, barY: top - AppSpacing.xs)
    }

    // MARK: - Lines and placing

    /// A generation's lines: the drop from `feed` to the bar, the bar across every rise (solid, the
    /// half-siblings' part dashed), and a rise to each target. A lone target under the feed is one line.
    private mutating func hang(_ targets: [Target], from feed: CGPoint?, barY: CGFloat) {
        // Nothing to join: no target, or a lone one with nothing above it (a person with no parents or siblings).
        guard targets.count > (feed == nil ? 1 : 0) else { return }
        if let feed, targets.count == 1, let only = targets.first, abs(only.x - feed.x) < 0.5 {
            lines.append(Line(from: feed, to: CGPoint(x: feed.x, y: only.y), dashed: only.dashed))
            return
        }
        let solid = targets.filter { !$0.dashed }.map(\.x) + (feed.map { [$0.x] } ?? [])
        let dashed = targets.filter(\.dashed).map(\.x)
        if let feed { lines.append(Line(from: feed, to: CGPoint(x: feed.x, y: barY), dashed: false)) }
        if let low = solid.min(), let high = solid.max(), high > low {
            lines.append(Line(from: CGPoint(x: low, y: barY), to: CGPoint(x: high, y: barY), dashed: false))
        }
        if let high = dashed.max() {
            let start = solid.max() ?? dashed.min() ?? high
            if high > start { lines.append(Line(from: CGPoint(x: start, y: barY), to: CGPoint(x: high, y: barY), dashed: true)) }
        }
        for target in targets {
            lines.append(Line(from: CGPoint(x: target.x, y: barY), to: CGPoint(x: target.x, y: target.y), dashed: target.dashed))
        }
    }

    /// A row's bar at `barY` across its rises and `joins` (where verticals meet it from above or leave it downwards),
    /// and a rise from it to each target.
    private mutating func bar(_ targets: [Target], joins: [CGFloat], at barY: CGFloat) {
        let xs = targets.map(\.x) + joins
        if let low = xs.min(), let high = xs.max(), high > low {
            lines.append(Line(from: CGPoint(x: low, y: barY), to: CGPoint(x: high, y: barY), dashed: false))
        }
        for target in targets {
            lines.append(Line(from: CGPoint(x: target.x, y: barY), to: CGPoint(x: target.x, y: target.y), dashed: false))
        }
    }

    /// An open chip's run (Departure 10): a bar of its own at `top`, where the chip's join ends, across the
    /// run and the join; the names flow under it, `xs` below, in reading order. A run that fits `range` on one line
    /// with no lane to keep clear of is that line, centred on the join and kept inside `range`, never spread to the
    /// range's edge (Matt, 2026-11-24). The bar is dashed for the half-siblings. Returns the run's bottom.
    @discardableResult
    private mutating func band(_ items: [Item], joinX: CGFloat, top: CGFloat, in range: ClosedRange<CGFloat>,
                               lanes: [CGFloat], dashed: Bool) -> CGFloat {
        var range = range
        let line = run(items.map(\.size.width))
        if lanes.isEmpty, line <= range.upperBound - range.lowerBound {
            let start = packedStart(line, under: joinX, in: range)
            // A hair over the line, so the flow does not wrap its last name on a rounding.
            range = start...min(range.upperBound, start + line + 0.5)
        }
        let (bottom, span) = flow(items, top: top + AppSpacing.xs, in: range, lanes: lanes)
        let low = min(span?.lowerBound ?? joinX, joinX), high = max(span?.upperBound ?? joinX, joinX)
        lines.append(Line(from: CGPoint(x: max(range.lowerBound, low), y: top), to: CGPoint(x: min(range.upperBound, high), y: top), dashed: dashed))
        return bottom
    }

    /// A run's names laid as text is in `range`: each whole on a line (cut to the line if longer), wrapping when
    /// the next does not fit, lines at least `rowPitch` apart, keeping clear of the vertical lines (`lanes`) that
    /// pass through.
    /// Returns the bottom and the run's extent, from the leading edge of its lines to the widest line's end.
    private mutating func flow(_ items: [Item], top: CGFloat, in range: ClosedRange<CGFloat>,
                               lanes: [CGFloat]) -> (bottom: CGFloat, span: ClosedRange<CGFloat>?) {
        let margin = gap / 2
        var rows: [[(Item, CGFloat)]] = [[]], x = range.lowerBound
        for item in items {
            let item = fit(item, to: range.upperBound - range.lowerBound), length = item.size.width
            func clear(_ x: CGFloat) -> CGFloat {
                lanes.filter { x - margin < $0 && $0 < x + length + margin }.map { $0 + margin }.max() ?? x
            }
            func cleared(from x: CGFloat) -> CGFloat {
                var start = x
                while clear(start) != start { start = clear(start) }
                return start
            }
            var start = cleared(from: x)
            if start + length > range.upperBound, !(rows.last?.isEmpty ?? true) {
                rows.append([])
                start = cleared(from: range.lowerBound)
            }
            rows[rows.count - 1].append((item, min(start, max(range.lowerBound, range.upperBound - length))))
            x = start + length + gap
        }
        var y = top, low: CGFloat?, high: CGFloat?
        for row in rows where !row.isEmpty {
            let height = max(rowPitch, row.map(\.0.size.height).max() ?? 0)
            for (item, minX) in row {
                let frame = place(item, minX: minX, rowTop: y, rowHeight: height)
                high = max(high ?? frame.maxX, frame.maxX)
            }
            low = min(low ?? .infinity, row.first?.1 ?? .infinity)
            y += height
        }
        guard let low, let high else { return (y, nil) }
        return (y, low...max(low, high))
    }

    // MARK: - The last resort: a name cut to fit

    /// The item cut to `share` when wider: drawn tail-truncated, whole in its help and to VoiceOver.
    private func fit(_ item: Item, to share: CGFloat) -> Item {
        guard item.size.width > share + 0.01 else { return item }
        var cut = item
        cut.size.width = max(0, share)
        cut.truncated = true
        return cut
    }

    /// A run of items each cut to its share of `available`, when the run is wider.
    private func fit(_ items: [Item], within available: CGFloat) -> [Item] {
        zip(items, shares(items.map(\.size.width), within: available)).map { fit($0, to: $1) }
    }

    /// Items laid side by side a gap apart from `start`.
    private func laid(_ items: [Item], from start: CGFloat) -> [(Item, CGFloat)] {
        zip(items, runOffsets(items.map(\.size.width))).map { ($0, start + $1) }
    }

    /// Items laid side by side with `gap`, the run centred in `range` and kept inside the column.
    private func centred(_ items: [Item], in range: ClosedRange<CGFloat>) -> [(Item, CGFloat)] {
        let offsets = runOffsets(items.map(\.size.width))
        let total = run(items.map(\.size.width))
        let start = min(max(0, (range.lowerBound + range.upperBound - total) / 2), max(0, width - total))
        return zip(items, offsets).map { ($0, start + $1) }
    }

    /// Where each of a run's names starts, from 0, `gap` apart.
    private func runOffsets(_ widths: [CGFloat]) -> [CGFloat] {
        var x: CGFloat = 0
        return widths.map { width in
            defer { x += width + gap }
            return x
        }
    }

    /// The shift that puts a span's `centredOn` at the column's centre, kept inside the column.
    private func clamp(start: CGFloat, end: CGFloat, centredOn middle: CGFloat, at target: CGFloat? = nil) -> CGFloat {
        var shift = (target ?? centre) - middle
        if end + shift > width { shift = width - end }
        if start + shift < 0 { shift = -start }
        return shift
    }

    /// Places an item centred on `midX`, vertically centred in its row (`rowHeight` 0: at the row's top).
    @discardableResult
    private mutating func place(_ item: Item, midX: CGFloat, rowTop: CGFloat, rowHeight: CGFloat) -> CGRect {
        place(item, minX: midX - item.size.width / 2, rowTop: rowTop, rowHeight: rowHeight)
    }

    @discardableResult
    private mutating func place(_ item: Item, minX: CGFloat, rowTop: CGFloat, rowHeight: CGFloat) -> CGRect {
        let frame = CGRect(x: minX, y: rowTop + max(0, rowHeight - item.size.height) / 2, width: item.size.width, height: item.size.height)
        slots.append(Slot(id: item.id, kind: item.kind, frame: frame, truncated: item.truncated))
        return frame
    }
}
