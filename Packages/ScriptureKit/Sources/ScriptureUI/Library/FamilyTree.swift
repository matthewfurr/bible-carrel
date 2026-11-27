import ScriptureData

/// A person's family as the tree draws it (spec 5.1): the parents, each with their own parents above
/// them, the siblings and half-siblings of the person's generation, and the household, the partners
/// and each child's other parent with the children under them. Pure: built from the relatives the
/// store read, so the tree's layout, its speech and the phone's rail all draw from one place.
public struct FamilyTree: Equatable, Sendable {
    /// A parent's parent, with the parent it sits over (a grandparent two parents share sits over each).
    public struct Grandparent: Equatable, Sendable {
        public let person: PersonSummary
        public let kind: Relation
        public let parentID: Int
    }

    /// One column of the mothers' row: who heads it and the children under it.
    public struct Household: Equatable, Sendable, Identifiable {
        public enum Head: Equatable, Sendable {
            /// A partner of the person.
            case partner(PersonSummary)
            /// The other parent of a child, not a partner, and the kind the child names them by.
            case otherParent(PersonSummary, Relation)
            /// A child's other parent the data does not name: "Mother not named" or "Father not named".
            case notNamed(Relation)
        }

        public let head: Head
        public let children: [PersonSummary]

        public var id: String {
            switch head {
            case .partner(let person): "partner-\(person.id)"
            case .otherParent(let person, _): "parent-\(person.id)"
            case .notNamed(let relation): "notNamed-\(relation.rawValue)"
            }
        }
    }

    public let person: PersonSummary
    public let father: PersonSummary?, mother: PersonSummary?
    public let grandparents: [Grandparent]
    public let siblings: [PersonSummary], halfSiblings: [PersonSummary]
    public let households: [Household]
    public let children: [PersonSummary]

    public var parents: [PersonSummary] { [father, mother].compactMap { $0 } }

    /// With any household the children sit under the mothers' row; without one they hang from the person.
    public var hasMothersRow: Bool { !households.isEmpty }

    public var isEmpty: Bool {
        parents.isEmpty && siblings.isEmpty && halfSiblings.isEmpty && children.isEmpty && households.isEmpty
    }

    private var partnerCount: Int {
        households.filter { if case .partner = $0.head { true } else { false } }.count
    }

    /// The Family fact (Departure 8): the household when the person has a partner or a child ("8 partners,
    /// 21 children"), else the family they were born to ("2 parents, 4 siblings", half-siblings counted
    /// among the siblings); nil with neither.
    public var summary: String? {
        func count(_ number: Int, _ one: String, _ many: String) -> String? {
            number == 0 ? nil : "\(number.formatted()) \(number == 1 ? one : many)"
        }
        let household = [count(partnerCount, "partner", "partners"), count(children.count, "child", "children")].compactMap { $0 }
        if !household.isEmpty { return household.joined(separator: ", ") }
        let born = [count(parents.count, "parent", "parents"), count(siblings.count + halfSiblings.count, "sibling", "siblings")].compactMap { $0 }
        return born.isEmpty ? nil : born.joined(separator: ", ")
    }

    /// The nearer relation wins, in this order (pre-flight ruling 1; Departure 7), so a child who is also a
    /// half-sibling is a child and a mother who is also a half-sibling is only the mother.
    private static let precedence: [Relation] = [.father, .mother, .partner, .child, .sibling, .halfSibling]

    /// Spec 5.1. `relatives` is the person's own, each kind in the data's `ordinal` order;
    /// `parentsOfChildren` and `parentsOfParents` are `BibleStore.parents(of:)` of the children's and the
    /// parents' ids.
    static func make(person: PersonSummary, relatives: [Relative], parentsOfChildren: [Int: [Relative]],
                     parentsOfParents: [Int: [Relative]]) -> FamilyTree {
        var seen: Set<Int> = [person.id]
        var byKind: [Relation: [PersonSummary]] = [:]
        for kind in precedence {
            for relative in relatives where relative.kind == kind && !seen.contains(relative.person.id) {
                seen.insert(relative.person.id)
                byKind[kind, default: []].append(relative.person)
            }
        }
        // One father and one mother; a second named is not placed.
        let father = byKind[.father]?.first, mother = byKind[.mother]?.first
        let grandparents = [father, mother].compactMap { $0 }.flatMap { parent in
            (parentsOfParents[parent.id] ?? []).map { Grandparent(person: $0.person, kind: $0.kind, parentID: parent.id) }
        }
        let partners = byKind[.partner] ?? [], children = byKind[.child] ?? []
        return FamilyTree(
            person: person, father: father, mother: mother, grandparents: grandparents,
            siblings: byKind[.sibling] ?? [], halfSiblings: byKind[.halfSibling] ?? [],
            households: households(of: person, partners: partners, children: children, parentsOfChildren: parentsOfChildren),
            children: children)
    }

    /// The mothers' row (spec 5.1): only when the person has a partner or a child has a named other
    /// parent. A child sits under its other parent (a partner's column when they are one); its mother,
    /// or its father when the person is that mother (Departure 5). Ordered: partners with children, partners
    /// without, other parents in the order their first child appears, then the "not named" column.
    private static func households(of person: PersonSummary, partners: [PersonSummary], children: [PersonSummary],
                                   parentsOfChildren: [Int: [Relative]]) -> [Household] {
        let partnerIDs = Set(partners.map(\.id))
        var partnerChildren: [Int: [PersonSummary]] = [:]
        var otherOrder: [PersonSummary] = [], otherRelation: [Int: Relation] = [:], otherChildren: [Int: [PersonSummary]] = [:]
        var notNamed: [PersonSummary] = [], notNamedRelation: Relation?
        for child in children {
            let parents = parentsOfChildren[child.id] ?? []
            let personIsMother = parents.contains { $0.kind == .mother && $0.person.id == person.id }
            let kind: Relation = personIsMother ? .father : .mother
            guard let other = parents.first(where: { $0.kind == kind && $0.person.id != person.id })?.person else {
                notNamed.append(child)
                notNamedRelation = notNamedRelation ?? kind
                continue
            }
            if partnerIDs.contains(other.id) {
                partnerChildren[other.id, default: []].append(child)
            } else {
                if otherChildren[other.id] == nil {
                    otherOrder.append(other)
                    otherRelation[other.id] = kind
                }
                otherChildren[other.id, default: []].append(child)
            }
        }
        guard !partners.isEmpty || !otherOrder.isEmpty else { return [] }
        let withChildren = partners.filter { partnerChildren[$0.id] != nil }, without = partners.filter { partnerChildren[$0.id] == nil }
        var households = (withChildren + without).map { Household(head: .partner($0), children: partnerChildren[$0.id] ?? []) }
        households += otherOrder.map {
            Household(head: .otherParent($0, otherRelation[$0.id] ?? .mother), children: otherChildren[$0.id] ?? [])
        }
        if let notNamedRelation { households.append(Household(head: .notNamed(notNamedRelation), children: notNamed)) }
        return households
    }
}
