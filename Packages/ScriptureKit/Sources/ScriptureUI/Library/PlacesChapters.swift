/// The chosen chapter of Places, By chapter (spec 5.5): which one it is after each way of changing it, and its words.
public enum PlacesChapters {
    /// The chapter after a place is shown another way: kept when it names the place, else the place's first
    /// chapter in the book, else (a place not in the book) none. No place on show, or no chapter chosen, keeps it.
    public static func following(showing: LibraryEntity?, chosen: Int?, in places: BookPlaces) -> Int? {
        guard let chosen, case .place(let id)? = showing else { return chosen }
        if places.chapter(chosen)?.places.contains(where: { $0.id == id }) == true { return chosen }
        return places.chapters.first { $0.places.contains { $0.id == id } }?.number
    }

    /// A heading's click (or ← → on the Mac): the chosen heading again clears the chapter while it shows its wash (no
    /// row chosen); with a row of its chapter chosen it shows none, so the click chooses the chapter as on any heading.
    public static func afterHeading(_ number: Int, chosen: Int?, rowChosen: Bool) -> Int? {
        chosen == number && !rowChosen ? nil : number
    }

    /// The chapter in effect: only By chapter has one (another order hides it).
    public static func effective(_ chapter: Int?, order: PlacesOrder) -> Int? {
        order == .byChapter ? chapter : nil
    }

    /// Another order clears the chapter; By chapter keeps what was chosen.
    public static func afterOrderChange(to order: PlacesOrder, chosen: Int?) -> Int? {
        effective(chosen, order: order)
    }

    /// ← (`-1`) and → (`+1`) on the Mac: the previous or next chapter that names a place; nil past an end. With
    /// none chosen, → takes the first chapter and ← the last (Departure 9).
    public static func step(_ step: Int, from chapter: Int?, in places: BookPlaces) -> Int? {
        LibraryPeopleView.neighbour(of: chapter, step: step, in: places.chapters.map(\.number))
    }

    /// Only By chapter has headings to step between; in the other orders ← and → are not the list's.
    public static func takesChapterKeys(_ order: PlacesOrder) -> Bool { order == .byChapter }

    /// "Chapter 2 · 5 places"; "Chapter 12 · 1 place, none on the map".
    public static func headerLine(_ chapter: BookPlaces.Chapter) -> String {
        "Chapter \(chapter.number) · \(countWords(chapter))"
    }

    /// A heading's spoken label: "Chapter 2, 5 places".
    public static func headingSpoken(_ chapter: BookPlaces.Chapter) -> String {
        "Chapter \(chapter.number), \(placeCount(chapter))"
    }

    /// What VoiceOver hears when the chosen chapter changes: "Chapter 12, 1 place, none on the map".
    public static func announcement(_ chapter: BookPlaces.Chapter) -> String {
        "Chapter \(chapter.number), \(countWords(chapter))"
    }

    /// A heading's help tag: what a click does. A heading showing its wash clears the chapter (`afterHeading`).
    public static func headingHelp(_ number: Int, clears: Bool) -> String {
        clears ? "Show the whole book on the map" : "Show chapter \(number) on the map"
    }

    /// What both apps announce on every change of the chapter in effect: the chapter's words, or, when it clears, the
    /// book's count as spoken ("101 places, 101 on the map").
    public static func announcementText(_ places: BookPlaces, chapter: Int?) -> String {
        chapter.flatMap(places.chapter).map(announcement) ?? places.countSpoken
    }

    /// A By chapter row's hint.
    public static func rowHint(chapter: Int) -> String { "in chapter \(chapter)" }

    /// The one line both apps show above the list: the chosen chapter's header line when the book has it,
    /// else the book's count.
    public static func countLine(_ places: BookPlaces, chapter: Int?) -> String {
        chapter.flatMap(places.chapter).map(headerLine) ?? places.countLabel
    }

    private static func placeCount(_ chapter: BookPlaces.Chapter) -> String {
        let count = chapter.places.count
        return "\(count.formatted()) \(count == 1 ? "place" : "places")"
    }

    private static func countWords(_ chapter: BookPlaces.Chapter) -> String {
        chapter.onMapCount == 0 ? "\(placeCount(chapter)), none on the map" : placeCount(chapter)
    }
}

extension LibraryPlace {
    /// A heading: the chapter it names is chosen (or cleared, by the chosen one again while it shows its wash), and a
    /// chosen chapter closes the place's page and clears the trail.
    public mutating func chooseChapter(_ number: Int, rowChosen: Bool) {
        placesChapter = PlacesChapters.afterHeading(number, chosen: placesChapter, rowChosen: rowChosen)
        if placesChapter != nil { clearTrail() }
    }

    /// A row: its chapter (when it has one) is chosen and its place is the one showing. A step to the place
    /// already showing alone keeps its page.
    public mutating func choosePlace(_ id: Int, inChapter chapter: Int?) {
        if let chapter { placesChapter = chapter }
        guard trail != [.place(id)] else { return }
        choose(.place(id))
    }

    /// The place with its chapter moved after the place on show changed another way, or nil when the chapter already
    /// follows it. The caller writes only a change, so a view going (its place read as none on show) writes nothing.
    public func followed(in places: BookPlaces) -> LibraryPlace? {
        let chapter = PlacesChapters.following(showing: showing, chosen: placesChapter, in: places)
        guard chapter != placesChapter else { return nil }
        var followed = self
        followed.placesChapter = chapter
        return followed
    }

    public mutating func clearChapter() { placesChapter = nil }
}
