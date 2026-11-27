import ScriptureData

/// The Library's views of a book.
public enum LibraryTopic: String, Hashable, Sendable, CaseIterable { case people, places, about }

/// A person or a place, by the data's id.
public enum LibraryEntity: Hashable, Sendable { case person(Int), place(Int) }

/// Where the reader is in the Library: a book's People, Places or About (or the whole Bible's, reached by name),
/// and the people or places walked to from there.
public struct LibraryPlace: Hashable, Sendable {
    /// nil: the whole Bible.
    public var book: String?
    public var topic: LibraryTopic
    /// The people or places walked to; the last is the one showing.
    public private(set) var trail: [LibraryEntity]
    /// The books the reader opened or closed on the page showing, each turned from how the page opens (the first book
    /// open, or every book with few references: `LibraryReferences`); empty is the page as it opens.
    public var toggledBooks: Set<String> = []
    /// The reference last opened from it, brought back into view on return.
    public private(set) var anchor: Reference?
    /// Places, By chapter: the chapter chosen by its heading (or by a place under it); part of the "as it was".
    public var placesChapter: Int? = nil

    public init(book: String?, topic: LibraryTopic, trail: [LibraryEntity] = []) {
        self.book = book
        self.topic = topic
        self.trail = trail
    }

    public var showing: LibraryEntity? { trail.last }

    /// The list's choice: the trail is that one alone.
    public mutating func choose(_ entity: LibraryEntity) {
        trail = [entity]
        forgetThePage()
    }

    /// A family name, a place at the same spot: one more on the trail.
    public mutating func walk(to entity: LibraryEntity) {
        trail.append(entity)
        forgetThePage()
    }

    /// The header's way back to the one before; from the first, none is chosen.
    public mutating func stepBack() {
        guard !trail.isEmpty else { return }
        trail.removeLast()
        forgetThePage()
    }

    /// Nothing chosen: a choice in Places' list or map that leaves no place showing.
    public mutating func clearTrail() {
        trail = []
        forgetThePage()
    }

    /// Opens a person in the book's People (a place in its Places) from another topic, as About's
    /// writers do: the topic becomes the entity's own and the trail is that one alone.
    public mutating func chooseInItsTopic(_ entity: LibraryEntity) {
        switch entity {
        case .person: topic = .people
        case .place: topic = .places
        }
        choose(entity)
    }

    /// The place with the anchor set to `reference`, the one opened from it.
    public func opening(_ reference: Reference) -> LibraryPlace {
        var place = self
        place.anchor = reference
        return place
    }

    /// The books turned and the anchor belong to the page showing.
    private mutating func forgetThePage() {
        toggledBooks = []
        anchor = nil
    }
}

/// What a lookup begun in the Library returns to: its place and the book chosen on the front page.
public struct LibraryReturn: Equatable, Sendable {
    public let place: LibraryPlace
    public let chosenBookID: String?
}
