import ScriptureData
import SwiftUI

/// The phone's family as a line and its household (spec 5.3), on the timeline's rail with no leading column:
/// grandparents and parents on rings, the siblings between, the person on a dot in the accent, then the household
/// on a branch of the same line, each partner on an elbow and under her, after a short elbow, her children. Every
/// name pushes that person's page; "and n more" opens its list in place (it has no way back, Departure 15).
///
/// The Mac shows it in place of the tree where the page is too narrow for the tree (`FamilyTreeLayoutRule`; Matt,
/// 2026-11-24), at the Library's type, each name and "n more" a plain button so Tab reaches it with keyboard
/// navigation on; VoiceOver reads each row as the phone does.
struct FamilyLineView: View {
    let tree: FamilyTree
    @Binding var open: Set<FamilyChip>
    let onWalk: (PersonSummary) -> Void

    init(tree: FamilyTree, open: Binding<Set<FamilyChip>>, onWalk: @escaping (PersonSummary) -> Void) {
        self.tree = tree
        self._open = open
        self.onWalk = onWalk
    }

    var body: some View {
        let rows = FamilyLine.rows(tree, open: open)
        let trunks = FamilyLine.trunks(rows)
        TimelineRail {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                FamilyLineRow(row: row, trunk: trunks[index], onWalk: onWalk) { open.insert($0) }
            }
        }
    }
}

/// One row of the line, its own view since a household repeats it many times. Its closures make each row
/// differ on every body of the line, so a change of one row still builds them all.
private struct FamilyLineRow: View {
    let row: FamilyLine.Row
    let trunk: FamilyLine.Trunk
    let onWalk: (PersonSummary) -> Void
    let onOpen: (FamilyChip) -> Void

    #if os(macOS)
    /// The Library's type: the reader's on the Mac's pages.
    @Environment(\.libraryType) private var type
    #endif

    var body: some View {
        RailRow(marker: marker, leading: nil, above: trunk.above ? .solid : .none, below: trunk.below ? .solid : .none,
                showsLeadingColumn: false, spoken: FamilyLine.spoken(row)) {
            #if os(macOS)
            macContent
            #else
            content
            #endif
        }
        .modifier(RowAccess(row: row, onWalk: onWalk, onOpen: onOpen))
        .tint(Color.accent)
        .environment(\.openURL, OpenURLAction { url in
            guard let link = Link(url) else { return .systemAction }
            switch link {
            case .person(let id): if let person = people.first(where: { $0.id == id }) { onWalk(person) }
            case .more: if let chip = FamilyLineRow.chip(for: row) { onOpen(chip) }
            }
            return .handled
        })
    }

    private var marker: RailMarker {
        switch row {
        case .grandparent, .parent: .ring
        case .person: .accent
        case .head, .moreHeads: .elbow
        case .siblings, .children: .none
        }
    }

    /// The people a row's links can walk to.
    private var people: [PersonSummary] { FamilyLineRow.people(in: row) }

    static func people(in row: FamilyLine.Row) -> [PersonSummary] {
        switch row {
        case .grandparent(let who), .parent(let who, _): [who]
        case .siblings(let people, _, _), .children(let people): people
        case .head(let household):
            switch household.head {
            case .partner(let who), .otherParent(let who, _): [who]
            case .notNamed: []
            }
        case .person, .moreHeads: []
        }
    }

    static func chip(for row: FamilyLine.Row) -> FamilyChip? {
        switch row {
        case .siblings(_, _, let half): half ? .halfSiblings : .siblings
        case .moreHeads: .households
        default: nil
        }
    }

    // MARK: Text

    private enum Link {
        case person(Int), more

        init?(_ url: URL) {
            guard url.scheme == FamilyLineRow.scheme else { return nil }
            if url.host() == "more" { self = .more } else if url.host() == "person", let id = Int(url.lastPathComponent) { self = .person(id) } else { return nil }
        }
    }

    fileprivate nonisolated static let scheme = "familyline"

    @ViewBuilder private var content: some View {
        switch row {
        case .grandparent(let who):
            Text(run(who, font: .callout, ink: .inkTertiary, word: FamilyLine.grandparentWord))
        case .parent(let who, let relation):
            Text(run(who, font: .body, ink: .accent, word: FamilyLine.relationWord(relation)))
        case .siblings(let people, let more, let half):
            Text(runs(FamilyLine.pieces(label: half ? "Half-siblings" : "Siblings", names: people, more: more)))
                .font(.callout)
        case .person(let who):
            Text(who.name).font(.body.weight(.semibold)).foregroundStyle(Color.inkPrimary)
        case .head(let household):
            head(household.head)
        case .moreHeads(let count):
            FamilyLineMore(text: FamilyLine.moreHeads(count)) { onOpen(.households) }
        case .children(let people):
            HStack(alignment: .top, spacing: AppSpacing.xxs) {
                RailElbow()
                Text(runs(FamilyLine.pieces(label: nil, names: people, more: 0))).font(.callout)
            }
        }
    }

    @ViewBuilder private func head(_ head: FamilyTree.Household.Head) -> some View {
        switch head {
        case .partner(let who), .otherParent(let who, _):
            Text(run(who, font: .body, ink: .accent, word: nil))
        case .notNamed(let relation):
            Text(FamilyLine.notNamed(relation)).font(.callout).italic().foregroundStyle(Color.inkSecondary)
        }
    }

    #if os(macOS)
    // MARK: The Mac's rows

    /// The phone's rows at the Library's type, each name and "n more" a button of its own (a Tab stop with keyboard
    /// navigation on), the runs wrapping between names as text does.
    @ViewBuilder private var macContent: some View {
        switch row {
        case .grandparent(let who):
            named(who, style: .callout, ink: .inkTertiary, word: FamilyLine.grandparentWord)
        case .parent(let who, let relation):
            named(who, style: .body, ink: .accent, word: FamilyLine.relationWord(relation))
        case .siblings(let people, let more, let half):
            macRun(FamilyLine.pieces(label: half ? "Half-siblings" : "Siblings", names: people, more: more))
        case .person(let who):
            Text(who.name).font(type.font(.body, weight: .semibold)).foregroundStyle(Color.inkPrimary)
        case .head(let household):
            switch household.head {
            case .partner(let who), .otherParent(let who, _): named(who, style: .body, ink: .accent, word: nil)
            case .notNamed(let relation):
                Text(FamilyLine.notNamed(relation)).font(type.font(.callout, italic: true)).foregroundStyle(Color.inkSecondary)
            }
        case .moreHeads(let count):
            FamilyLineMore(text: FamilyLine.moreHeads(count)) { onOpen(.households) }
        case .children(let people):
            HStack(alignment: .top, spacing: AppSpacing.xxs) {
                RailElbow()
                macRun(FamilyLine.pieces(label: nil, names: people, more: 0))
            }
        }
    }

    /// A name as a button in `style` and `ink`, then its relation word in the caption.
    private func named(_ who: PersonSummary, style: Font.TextStyle, ink: Color, word: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            nameButton(who.name, style: style, ink: ink) { onWalk(who) }
            if let word {
                Text(" \(word)").font(type.font(.caption)).foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private func nameButton(_ name: String, style: Font.TextStyle, ink: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name).font(type.font(style)).foregroundStyle(ink)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    /// A run in `.callout`: its words in the secondary ink, its names and "n more" buttons in the accent, wrapping
    /// between units (`FamilyLine.cuts`).
    private func macRun(_ pieces: [FamilyLine.Piece]) -> some View {
        FlowLayout(spacing: 0, isCentered: false) {
            ForEach(Array(FamilyLine.cuts(pieces).enumerated()), id: \.offset) { _, cut in
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    switch cut.unit {
                    case .word(let word): Text(word).font(type.font(.callout)).foregroundStyle(Color.inkSecondary)
                    case .name(let who): nameButton(who.name, style: .callout, ink: .accent) { onWalk(who) }
                    case .more(let text):
                        nameButton(text, style: .callout, ink: .accent) { if let chip = FamilyLineRow.chip(for: row) { onOpen(chip) } }
                    }
                    if !cut.trailing.isEmpty {
                        Text(cut.trailing).font(type.font(.callout)).foregroundStyle(Color.inkSecondary)
                    }
                }
            }
        }
    }
    #endif

    private func personURL(_ who: PersonSummary) -> URL? { URL(string: "\(Self.scheme)://person/\(who.id)") }

    private func link(_ text: String, to url: URL?) -> AttributedString {
        var piece = AttributedString(text)
        piece.link = url
        piece.foregroundColor = Color.accent
        return piece
    }

    /// A name as a link in `font` and `ink`, then its relation word in the caption.
    private func run(_ who: PersonSummary, font: Font, ink: Color, word: String?) -> AttributedString {
        var name = AttributedString(who.name)
        name.link = personURL(who)
        name.font = font
        name.foregroundColor = ink
        guard let word else { return name }
        var relation = AttributedString(" \(word)")
        relation.font = .caption
        relation.foregroundColor = Color.inkSecondary
        return name + relation
    }

    /// A run of names: the names and "n more" links in the accent, the words between and any label secondary.
    private func runs(_ pieces: [FamilyLine.Piece]) -> AttributedString {
        var result = AttributedString()
        for piece in pieces {
            switch piece {
            case .plain(let text):
                var plain = AttributedString(text)
                plain.foregroundColor = Color.inkSecondary
                result.append(plain)
            case .name(let who): result.append(link(who.name, to: personURL(who)))
            case .more(let text): result.append(link(text, to: URL(string: "\(Self.scheme)://more")))
            }
        }
        return result
    }
}

/// "and 5 more partners": a button in the accent whose hit area is a scaled 44 pt tall (the phone's least, as
/// the tree's chips are 24 on the Mac), laid at its line's height so the rail's rhythm holds.
private struct FamilyLineMore: View {
    let text: String
    let action: () -> Void

    @ScaledMetric(relativeTo: .callout) private var minimumHit: CGFloat = 44
    @ScaledMetric(relativeTo: .callout) private var firstLine: CGFloat = RailMetrics.firstLineAtDefault
    /// The Library's type: the system's on the phone (so its sizes are as they were), the reader's on the Mac.
    @Environment(\.libraryType) private var type

    private var reach: CGFloat { max(0, (type.metric(minimumHit) - type.metric(firstLine)) / 2) }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(type.font(.callout))
                .foregroundStyle(Color.accent)
                .padding(.vertical, reach)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -reach)
    }
}

/// VoiceOver: a one-name row is one link to that person; a run has an action for each name and for "and n more".
private struct RowAccess: ViewModifier {
    let row: FamilyLine.Row
    let onWalk: (PersonSummary) -> Void
    let onOpen: (FamilyChip) -> Void

    func body(content: Content) -> some View {
        switch row {
        case .grandparent, .parent, .head:
            if let who = FamilyLineRow.people(in: row).first {
                content.accessibilityAddTraits(.isLink).accessibilityAction { onWalk(who) }
            } else {
                content
            }
        case .moreHeads:
            content.accessibilityAddTraits(.isButton).accessibilityAction { onOpen(.households) }
        case .siblings(let people, let more, _):
            content.accessibilityActions { names(people, more: more) }
        case .children(let people):
            content.accessibilityActions { names(people, more: 0) }
        case .person:
            content
        }
    }

    @ViewBuilder private func names(_ people: [PersonSummary], more: Int) -> some View {
        ForEach(people) { person in Button(person.name) { onWalk(person) } }
        if more > 0, let chip = FamilyLineRow.chip(for: row) { Button("\(more.formatted()) more") { onOpen(chip) } }
    }
}
