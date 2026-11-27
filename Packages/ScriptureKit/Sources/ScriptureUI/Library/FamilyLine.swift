import ScriptureData

/// The phone's family as one line and its household (spec 5.3): grandparents, the parents, the siblings, the
/// person, then the household on a branch of the same line. Pure: `FamilyLineView` draws these rows on the
/// timeline's rail, and the tests read them without a view.
enum FamilyLine {
    /// Names shown before a fold (siblings, partners). A fold hides two or more (Departure 23), so four of a
    /// kind all show.
    static let shownNames = 3

    /// One rail row, top to bottom. A grandparent shows once however many parents it sits over.
    enum Row: Equatable, Identifiable {
        case grandparent(PersonSummary)
        case parent(PersonSummary, Relation)
        /// Siblings, or with `half` the half-siblings; `more` the names folded (0 when all show).
        case siblings([PersonSummary], more: Int, half: Bool)
        case person(PersonSummary)
        /// A partner, a child's other parent or the "not named" column, with the children under it as the next row.
        case head(FamilyTree.Household)
        /// "and n more partners", for the partners after the third.
        case moreHeads(Int)
        case children([PersonSummary])

        var id: String {
            switch self {
            case .grandparent(let who): "grandparent-\(who.id)"
            case .parent(let who, _): "parent-\(who.id)"
            case .siblings(_, _, let half): half ? "halfSiblings" : "siblings"
            case .person: "person"
            case .head(let household): "head-\(household.id)"
            case .moreHeads: "moreHeads"
            case .children(let people): "children-\(people.first?.id ?? 0)"
            }
        }

        /// Whether the row hangs from the trunk by an elbow: a head, or the fold of heads.
        var isHead: Bool {
            switch self {
            case .head, .moreHeads: true
            default: false
            }
        }
    }

    /// The rows for `tree`; `open` lets the siblings, half-siblings and partners show in full.
    static func rows(_ tree: FamilyTree, open: Set<FamilyChip>) -> [Row] {
        var rows: [Row] = []
        var seen: Set<Int> = []
        for grandparent in tree.grandparents where seen.insert(grandparent.person.id).inserted { rows.append(.grandparent(grandparent.person)) }
        if let father = tree.father { rows.append(.parent(father, .father)) }
        if let mother = tree.mother { rows.append(.parent(mother, .mother)) }
        for (people, chip, half) in [(tree.siblings, FamilyChip.siblings, false), (tree.halfSiblings, .halfSiblings, true)] where !people.isEmpty {
            let folded = open.contains(chip) ? 0 : hidden(people.count)
            rows.append(.siblings(Array(people.prefix(people.count - folded)), more: folded, half: half))
        }
        rows.append(.person(tree.person))
        // The partners come first in the households; only they fold.
        let partners = tree.households.prefix { if case .partner = $0.head { true } else { false } }.count
        let foldedPartners = open.contains(.households) ? 0 : hidden(partners)
        for (index, household) in tree.households.enumerated() {
            if index == partners - foldedPartners, foldedPartners > 0 { rows.append(.moreHeads(foldedPartners)) }
            if index >= partners - foldedPartners, index < partners { continue }
            rows.append(.head(household))
            if !household.children.isEmpty { rows.append(.children(household.children)) }
        }
        if tree.households.isEmpty, !tree.children.isEmpty { rows.append(.children(tree.children)) }
        return rows
    }

    /// How many of `count` fold behind "and n more": none under two.
    private static func hidden(_ count: Int) -> Int { count - shownNames >= 2 ? count - shownNames : 0 }

    /// Where a row's line runs. The line above the person is one run; the household's trunk runs on below the
    /// person only while another head follows, so the last head's elbow ends it, and its children hang from its name.
    struct Trunk: Equatable {
        var above: Bool, below: Bool
    }

    static func trunks(_ rows: [Row]) -> [Trunk] {
        let personIndex = rows.firstIndex { if case .person = $0 { true } else { false } } ?? rows.count
        return rows.indices.map { index in
            let headFollows = rows[(index + 1)...].contains { $0.isHead }
            if index < personIndex { return Trunk(above: index > 0, below: true) }
            if index == personIndex { return Trunk(above: index > 0, below: headFollows) }
            return rows[index].isHead ? Trunk(above: true, below: headFollows) : Trunk(above: headFollows, below: headFollows)
        }
    }

    // MARK: Words

    /// One piece of a run of text: plain words, a name that links to its person, or the "n more" link.
    enum Piece: Equatable {
        case plain(String), name(PersonSummary), more(String)
    }

    /// "Abinadab, Eliab, Elihu and 4 more": commas, then "and" before the last (the fold counts as one).
    static func pieces(label: String?, names: [PersonSummary], more: Int) -> [Piece] {
        var pieces: [Piece] = label.map { [.plain("\($0): ")] } ?? []
        let count = names.count + (more > 0 ? 1 : 0)
        func separator(_ index: Int) -> Piece? {
            index == 0 ? nil : .plain(index == count - 1 ? " and " : ", ")
        }
        for (index, person) in names.enumerated() {
            separator(index).map { pieces.append($0) }
            pieces.append(.name(person))
        }
        if more > 0 {
            separator(names.count).map { pieces.append($0) }
            pieces.append(.more("\(more.formatted()) more"))
        }
        return pieces
    }

    /// One unit of a run as the Mac lays it, where a line may wrap: a word, a name or the "n more", with the text that
    /// follows it (", ", " "), so each name and "n more" is a button of its own (a Tab stop with keyboard navigation on).
    struct Cut: Equatable {
        enum Unit: Equatable { case word(String), name(PersonSummary), more(String) }
        let unit: Unit
        var trailing: String
    }

    /// A run's pieces cut into units: "Siblings:", "Abinadab, ", "Eliab, ", "Elihu ", "and ", "4 more". Joined, they read
    /// as `text(pieces)` does.
    static func cuts(_ pieces: [Piece]) -> [Cut] {
        var cuts: [Cut] = []
        for piece in pieces {
            switch piece {
            case .name(let person): cuts.append(Cut(unit: .name(person), trailing: ""))
            case .more(let text): cuts.append(Cut(unit: .more(text), trailing: ""))
            case .plain(let text):
                // What comes before the first word (", ", " ") follows the unit before; each word is a unit with its space.
                let start = text.firstIndex { !$0.isWhitespace && !$0.isPunctuation } ?? text.endIndex
                if !cuts.isEmpty { cuts[cuts.count - 1].trailing += text[..<start] }
                var rest = text[start...]
                while !rest.isEmpty {
                    let end = rest.firstIndex(where: \.isWhitespace) ?? rest.endIndex
                    let next = rest[end...].firstIndex { !$0.isWhitespace } ?? rest.endIndex
                    cuts.append(Cut(unit: .word(String(rest[..<end])), trailing: String(rest[end..<next])))
                    rest = rest[next...]
                }
            }
        }
        return cuts
    }

    static func text(_ pieces: [Piece]) -> String {
        pieces.map { piece in
            switch piece {
            case .plain(let text), .more(let text): text
            case .name(let person): person.name
            }
        }.joined()
    }

    /// "Siblings: Abinadab, Eliab, Elihu and 4 more".
    static func namesText(_ label: String, _ names: [String], more: Int) -> String {
        let people = names.enumerated().map { PersonSummary(id: $0.offset, name: $0.element, label: nil, verseCount: 0) }
        return text(pieces(label: label, names: people, more: more))
    }

    static func moreHeads(_ count: Int) -> String { "and \(count.formatted()) more partners" }

    /// "Mother not named", "Father not named".
    static func notNamed(_ relation: Relation) -> String { "\(relationWord(relation).capitalized) not named" }

    /// The data's own words for a kind; the app never says son, daughter, brother or sister.
    static func relationWord(_ relation: Relation) -> String {
        switch relation {
        case .father: "father"
        case .mother: "mother"
        case .partner: "partner"
        case .sibling: "sibling"
        case .halfSibling: "half-sibling"
        case .child: "child"
        }
    }

    static let grandparentWord = "grandparent"

    /// What a row reads as to VoiceOver.
    static func spoken(_ row: Row) -> String {
        switch row {
        case .grandparent(let who): "\(who.name), \(grandparentWord)"
        case .parent(let who, let relation): "\(who.name), \(relationWord(relation))"
        case .siblings(let people, let more, let half): text(pieces(label: half ? "Half-siblings" : "Siblings", names: people, more: more))
        case .person(let who): who.name
        case .head(let household):
            switch household.head {
            case .partner(let who): "\(who.name), \(relationWord(.partner))"
            case .otherParent(let who, let relation): "\(who.name), \(relationWord(relation))"
            case .notNamed(let relation): notNamed(relation)
            }
        case .moreHeads(let count): moreHeads(count)
        case .children(let people): text(pieces(label: "Children", names: people, more: 0))
        }
    }
}
