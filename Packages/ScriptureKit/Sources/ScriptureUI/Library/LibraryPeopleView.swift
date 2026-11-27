import ScriptureData
import SwiftUI

/// People in a book (spec 6.2): the list at a scaled 200 pt beside the chosen person's page. Up and
/// Down move the choice; a person walked to who is not in the list leaves no row chosen. With no
/// list (the whole Bible, reached by name) the person's page has the width.
struct LibraryPeopleView: View {
    let people: BookPeople?
    let person: PersonPage?
    @Binding var place: LibraryPlace
    let navigation: NavigationModel
    let onWalk: (LibraryEntity) -> Void
    let onOpen: (Reference) -> Void

    @ScaledMetric(relativeTo: .body) private var listWidth: CGFloat = 200
    @Environment(\.libraryType) private var type
    @FocusState private var isFocused: Bool
    /// One choice for People in every book, on this device only.
    @AppStorage(PeopleOrder.key) private var order: PeopleOrder = .mostNamed
    /// The chosen row's rectangle in the list's own space: the focus ring's shape.
    @State private var chosenRect: CGRect = .zero

    nonisolated static let coordinateSpace = "people"

    /// The row of the person showing, while they are in the list.
    nonisolated static func chosenID(showing: LibraryEntity?, in rows: [BookPeople.Row]) -> Int? {
        guard case .person(let id) = showing, rows.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    /// Up and Down from `id` in the ids as shown; with none, Down takes the first and Up the last; nil past an end.
    /// Places' rows and chapters step by the same rule (`PlacesList.neighbour`, `PlacesChapters.step`).
    nonisolated static func neighbour<ID: Equatable>(of id: ID?, step: Int, in ids: [ID]) -> ID? {
        let target = id.flatMap { ids.firstIndex(of: $0) }.map { $0 + step } ?? (step > 0 ? 0 : ids.count - 1)
        return ids.indices.contains(target) ? ids[target] : nil
    }

    private var chosenID: Int? { Self.chosenID(showing: place.showing, in: people?.rows ?? []) }

    var body: some View {
        HStack(spacing: 0) {
            if let people {
                list(people)
                    .frame(width: type.metric(listWidth))
                HairlineRule(.vertical)
            }
            detail
        }
    }

    @ViewBuilder private var detail: some View {
        if let person {
            PersonPagePane(
                page: person, bookName: place.book.flatMap { BookCatalog.book(code: $0)?.name }, navigation: navigation,
                toggledBooks: place.toggledBooks, setToggledBooks: { place.toggledBooks = $0 }, anchor: place.anchor,
                onWalk: onWalk, onOpen: onOpen)
                .equatable()
                .id(person.person.id)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(people?.rows.isEmpty == true ? "No people are named here." : "Choose a person.")
                    .font(type.font(.callout))
                    .foregroundStyle(Color.inkSecondary)
                Spacer(minLength: AppSpacing.lg)
                LibraryCreditLine()
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func list(_ people: BookPeople) -> some View {
        let rows = people.rows(order)
        let chosen = chosenID
        return ScrollViewReader { proxy in
            VStack(spacing: 0) {
                LibraryOrderPicker(selection: $order, orders: PeopleOrder.allCases, title: \.title)
                    .padding(AppSpacing.xs)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rows) { row in
                            self.row(row, isChosen: chosen == row.id)
                        }
                    }
                    .padding(AppSpacing.xs)
                    .coordinateSpace(.named(Self.coordinateSpace))
                    #if os(macOS)
                    .contentShape(.focusEffect, LibraryChosenRowShape(rect: chosenRect))
                    #endif
                    .focusable()
                    .focused($isFocused)
                    .accessibilityElement(children: .contain)
                    .onKeyPress(.upArrow) { move(-1, in: rows, proxy: proxy) }
                    .onKeyPress(.downArrow) { move(1, in: rows, proxy: proxy) }
                }
            }
            // Coming back to a person (from the reader, by Home): their row in view once laid out.
            .task {
                await Task.yield()
                if let chosenID { proxy.scrollTo(chosenID, anchor: .center) }
            }
            // Switching order keeps the chosen person chosen and brings them into view.
            .onChange(of: order) {
                guard let chosenID else { return }
                Task {
                    await Task.yield()
                    proxy.scrollTo(chosenID, anchor: .center)
                }
            }
        }
    }

    private func row(_ row: BookPeople.Row, isChosen: Bool) -> some View {
        PeopleListRow(row: row, isChosen: isChosen, onChosenRect: { chosenRect = $0 }, onChoose: { choose(row.id) })
            .equatable()
    }

    private func choose(_ id: Int) {
        place.choose(.person(id))
    }

    /// Up and Down from the chosen row, in the order shown.
    private func move(_ step: Int, in rows: [BookPeople.Row], proxy: ScrollViewProxy) -> KeyPress.Result {
        guard isFocused, !rows.isEmpty else { return .ignored }
        guard let id = Self.neighbour(of: chosenID, step: step, in: rows.map(\.id)) else { return .handled }
        choose(id)
        proxy.scrollTo(id)
        return .handled
    }
}

/// The chosen person's page, compared by what it shows. The place reaches this view through a binding made of closures,
/// which SwiftUI cannot compare, so this view is built again in every update of the window (a geometry read, a scroll);
/// without the comparison the whole page (its tree, References and verse lines) would be built again each time with it.
/// The closures are left out: they act on the window's place and the navigation, which hold no state of their own.
private struct PersonPagePane: View, @MainActor Equatable {
    let page: PersonPage
    let bookName: String?
    let navigation: NavigationModel
    let toggledBooks: Set<String>
    let setToggledBooks: (Set<String>) -> Void
    let anchor: Reference?
    let onWalk: (LibraryEntity) -> Void
    let onOpen: (Reference) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.page == rhs.page && lhs.bookName == rhs.bookName && lhs.navigation === rhs.navigation
            && lhs.toggledBooks == rhs.toggledBooks && lhs.anchor == rhs.anchor
    }

    var body: some View {
        PersonPageView(page: page, bookName: bookName, navigation: navigation, toggledBooks: toggledBooks,
                       setToggledBooks: setToggledBooks, anchor: anchor, onWalk: onWalk, onOpen: onOpen)
    }
}

/// A row of People's list, compared by what it shows, so the list's updates (each one in the window, as
/// `PersonPagePane` says) do not build every row again; its closures choose the row and report its rectangle.
private struct PeopleListRow: View, @MainActor Equatable {
    let row: BookPeople.Row
    let isChosen: Bool
    let onChosenRect: (CGRect) -> Void
    let onChoose: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.row == rhs.row && lhs.isChosen == rhs.isChosen
    }

    var body: some View {
        LibraryListRow(
            id: row.id, name: row.person.name, detail: row.label, count: row.person.verseCount, isChosen: isChosen,
            accessibilityLabel: row.accessibilityLabel, coordinateSpace: LibraryPeopleView.coordinateSpace,
            onChosenRect: onChosenRect, onChoose: onChoose)
    }
}
