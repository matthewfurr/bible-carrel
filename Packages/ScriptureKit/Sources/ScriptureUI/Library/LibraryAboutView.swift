import ScriptureData
import SwiftUI

/// About a book (spec 6): the head (its name, its subtitle), the fact list (Testament, Length, Attributed to,
/// Spans, People, Places; the writers and the people are buttons that open that person in the book's People), then,
/// when the data has events, the timeline: a rail of rows in the order of history, with its era headers and folds
/// of long runs of lives. On the Mac a chart sits over the rail and washes the years of the rows on screen; a click
/// on it scrolls the rail to the row. On coming back from a passage opened from a row, `anchor`'s row is scrolled
/// into view (its fold opened first). Scrolls, in the Library's text column (the reader's measure, centred, on the
/// Mac; a scaled 520 pt page on the phone, as before): the head, the facts, the timeline's header, the chart and the rail.
public struct LibraryAboutView: View {
    let about: BookAbout
    let navigation: NavigationModel
    let onWalk: (LibraryEntity) -> Void
    let onOpenTopic: (LibraryTopic) -> Void
    let onShow: ((Reference) -> Void)?
    let onOpen: (Reference) -> Void
    let anchor: Reference?

    @AppStorage(LibraryDates.showKey) private var showsDates = LibraryDates.defaultShows
    @State private var openFolds: Set<Int> = []
    /// The come-back's row inside a fold being opened, scrolled to once the fold is drawn open.
    @State private var pendingScroll: TimelineItemID?
    @State private var memo = TimelineMemo()
    @State private var landing = RailLanding()
    /// The Mac's rail geometry under the pinned chart (and its height, which a scroll lands a row that far down).
    @State private var geometry = RailGeometry()
    @Environment(\.libraryType) private var type
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(about: BookAbout, navigation: NavigationModel, onWalk: @escaping (LibraryEntity) -> Void,
                onOpenTopic: @escaping (LibraryTopic) -> Void,
                onShow: ((Reference) -> Void)? = nil, onOpen: @escaping (Reference) -> Void, anchor: Reference? = nil) {
        self.about = about
        self.anchor = anchor
        self.navigation = navigation
        self.onWalk = onWalk
        self.onOpenTopic = onOpenTopic
        self.onShow = onShow
        self.onOpen = onOpen
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // The head and the foot as before; the rail a lazy stack of its own, its rows made as they near the
                // window, and a section whose header, the Mac's chart, pins at the window's top (a header pins only in a
                // lazy stack). The whole page in one lazy stack had its height estimated from the head and swing.
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        LibraryDatesNotice(hasDate: about.hasDate)
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            LibraryPageTitle(about.book.name, subtitle: about.subtitle)
                            FactList(rows)
                        }
                        if hasTimeline { timelineHeader }
                    }
                    .modifier(RailEdge(geometry: tracked, edge: .top))
                    if hasTimeline {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: chartShows ? [.sectionHeaders] : []) {
                            timeline(proxy)
                        }
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        if showsDates && about.hasDate { LibraryDatesFootnote() }
                        LibraryCreditLine()
                            .padding(.top, AppSpacing.lg)
                    }
                    .padding(.top, AppSpacing.lg)
                    .modifier(RailEdge(geometry: tracked, edge: .bottom))
                }
                .libraryColumn()
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .coordinateSpace(.named(RailViewport.space))
            }
            .trackingTheRail(tracked)
            .onScrollPhaseChange { _, phase in
                if RailLanding.readerScrolls(phase) { landing.end() }
            }
            .task(id: about.book.id) {
                guard let anchor = TimelineItems.anchor(about.timeline, reference: anchor) else { return }
                if let fold = anchor.fold, !openFolds.contains(fold) {
                    // The fold's lives are rows only once the page has drawn it open: the scroll waits for that.
                    pendingScroll = anchor.scrollID
                    openFolds.insert(fold)
                } else {
                    land(on: anchor.scrollID, proxy: proxy)
                }
            }
            .onChange(of: openFolds) {
                guard let id = pendingScroll else { return }
                pendingScroll = nil
                land(on: id, proxy: proxy)
            }
        }
    }

    /// The facts a book shows, in order; a fact with no value is left out.
    enum Fact: String {
        case testament = "Testament", length = "Length", writers = "Attributed to", spans = "Spans"
        case people = "People", places = "Places"
    }

    nonisolated static func facts(_ about: BookAbout, showingDates: Bool) -> [Fact] {
        var facts: [Fact] = [.testament, .length]
        if !about.writers.isEmpty { facts.append(.writers) }
        if about.spans(showingDates: showingDates) != nil { facts.append(.spans) }
        if !about.topPeople.isEmpty { facts.append(.people) }
        if !about.topPlaces.isEmpty { facts.append(.places) }
        return facts
    }

    /// The labels of the rows the page shows, in order.
    nonisolated static func factLabels(_ about: BookAbout, showingDates: Bool) -> [String] {
        facts(about, showingDates: showingDates).map(\.rawValue)
    }

    private var rows: [FactRow] {
        Self.facts(about, showingDates: showsDates).map(row)
    }

    private func plain(_ text: String) -> some View {
        // A plain value can be selected and copied; a value that names a person stays a link.
        Text(text).font(type.font(type.reading)).foregroundStyle(Color.inkPrimary).librarySelectable()
    }

    private func row(_ fact: Fact) -> FactRow {
        let label = fact.rawValue
        switch fact {
        case .testament:
            return FactRow(label, spoken: about.testamentLine) { plain(about.testamentLine) }
        case .length:
            return FactRow(label, spoken: about.lengthLine) { plain(about.lengthLine) }
        case .writers:
            let names = about.writers.map { LibraryNameRun.Name(entity: .person($0.id), name: $0.name) }
            return nameRow(label, names: names, more: 0, tail: "(by tradition)", topic: nil)
        case .spans:
            let span = about.spans(showingDates: showsDates) ?? ""
            return FactRow(label, spoken: span) { plain(span) }
        case .people:
            let names = about.topPeople.map { LibraryNameRun.Name(entity: .person($0.id), name: $0.name) }
            return nameRow(label, names: names, more: about.morePeople, tail: nil, topic: .people, startsGroup: true)
        case .places:
            let names = about.topPlaces.map { LibraryNameRun.Name(entity: .place($0.id), name: $0.name) }
            return nameRow(label, names: names, more: about.morePlaces, tail: nil, topic: .places)
        }
    }

    private func nameRow(_ label: String, names: [LibraryNameRun.Name], more: Int, tail: String?, topic: LibraryTopic?,
                         startsGroup: Bool = false) -> FactRow {
        var actions = names.map { name in FactRow.Action(name.name) { onWalk(name.entity) } }
        let open = topic.map { topic in { onOpenTopic(topic) } }
        if more > 0, let open { actions.append(FactRow.Action("\(more.formatted()) more", perform: open)) }
        return FactRow(label, spoken: LibraryNameRun.spoken(names, more: more, tail: tail), startsGroup: startsGroup,
                       actions: actions) {
            LibraryNameRun(names, more: more, tail: tail, onWalk: onWalk, onMore: open)
        }
    }

    // MARK: The timeline

    private var hasTimeline: Bool { !about.timeline.entries.isEmpty }

    /// The rail's geometry, kept only while the Mac's chart shows.
    private var tracked: RailGeometry? { chartShows ? geometry : nil }

    /// The rail as a section whose header, on the Mac, is the chart: pinned at the page's top once the rail reaches
    /// it, the rail scrolling under it, and pushed off with the rail's end (Matt's review, 2026-11-24). The heading
    /// "Timeline" scrolls with the page above it.
    private func timeline(_ proxy: ScrollViewProxy) -> some View {
        let rail = memo.rail(about.timeline, openFolds: openFolds, showingDates: showsDates)
        let items = rail.items, dashed = rail.dashed
        if let tracked {
            tracked.items = items
            tracked.domain = memo.chart(about.timeline).domain
        }
        // Stacked with no gap so the rows' lines join, as `TimelineRail` stacks them.
        return Section {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                railRow(item, above: index == 0 ? .none : segment(items[index - 1], dashed),
                        below: index == items.count - 1 ? .none : segment(item, dashed))
                    .id(item.id)
                    .modifier(RailRowTop(id: item.id, landing: landing, geometry: tracked))
            }
        } header: {
            chart(items, proxy: proxy)
        }
    }

    /// "Timeline", a page heading, with the count line beside it on its baseline, or under it where the two do not fit
    /// on one line (an accessibility size on the phone).
    private var timelineHeader: some View {
        LibraryPageHeading("Timeline", count: about.timeline.countLine)
    }

    /// Whether the Mac's chart shows (with dates on, five rows and two years); never on the phone.
    private var chartShows: Bool {
        #if os(macOS)
        TimelineChartModel.shows(about.timeline, showingDates: showsDates)
        #else
        false
        #endif
    }

    /// The Mac's chart over the rail: its band spans the rows in view under it; a click scrolls the rail to the bar's
    /// row or the nearest one (`.smooth`, a cut under Reduce Motion), landing it under the chart.
    @ViewBuilder private func chart(_ items: [TimelineItem], proxy: ScrollViewProxy) -> some View {
        #if os(macOS)
        if chartShows {
            PinnedTimelineChart(model: memo.chart(about.timeline), items: items, state: geometry.state) { id, animation in
                land(on: id, proxy: proxy, animation: animation)
            }
            .equatable()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                geometry.chartHeight = height
                geometry.update()
            }
        } else {
            gapAboveTheRail
        }
        #else
        gapAboveTheRail
        #endif
    }

    /// The heading's gap above the rail where no chart sits between them.
    private var gapAboveTheRail: some View {
        Color.clear.frame(height: AppSpacing.xs)
    }

    private func segment(_ item: TimelineItem, _ dashed: Set<TimelineItemID>) -> RailSegment {
        dashed.contains(item.id) ? .dashed : .solid
    }

    @ViewBuilder private func railRow(_ item: TimelineItem, above: RailSegment, below: RailSegment) -> some View {
        switch item {
        case .era(let era, _):
            RailRow(marker: .none, leading: nil, above: above, below: below, showsLeadingColumn: showsDates,
                    spoken: era.spoken(showingDates: showsDates)) {
                eraRow(era)
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityActions {
                if let passage = era.passage { Button(passage.displayString) { openPassage(passage) } }
            }
        case .entry(let entry, let yearLabel):
            RailRow(marker: Self.isLife(entry) ? .ring : .dot, leading: yearLabel, above: above, below: below,
                    showsLeadingColumn: showsDates, spoken: entry.spoken(showingDates: showsDates)) {
                entryRow(entry)
            }
            .accessibilityActions {
                if let passage = entry.passage { Button(passage.displayString) { openPassage(passage) } }
                if case .life(let id?) = entry.kind { Button(entry.title) { onWalk(.person(id)) } }
            }
        case .fold(let fold, let isOpen, let yearLabel):
            RailRow(marker: .ring, leading: yearLabel, above: above, below: below, showsLeadingColumn: showsDates,
                    spoken: fold.line) {
                foldRow(fold, isOpen: isOpen)
            }
            .accessibilityValue(isOpen ? "expanded" : "collapsed")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { toggle(fold) }
        }
    }

    nonisolated static func isLife(_ entry: BookTimeline.Entry) -> Bool {
        if case .life = entry.kind { true } else { false }
    }

    /// Opens a passage from a row (departure 10): the phone's push, the Mac's open.
    private func openPassage(_ reference: Reference) {
        if let onShow { onShow(reference) } else { onOpen(reference) }
    }

    private func passageRun(_ reference: Reference) -> some View {
        ReferenceRunsText([reference], inBook: about.book, font: type.font(.caption), navigation: navigation, onShow: onShow, onOpen: onOpen)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func eraRow(_ era: BookTimeline.Era) -> some View {
        let label = GroupLabel(era.header(showingDates: showsDates), size: type.readerSize == nil ? nil : type.size(.caption2))
        return Group {
            if let passage = era.passage {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) { label; passageRun(passage) }
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) { label; passageRun(passage) }
                }
            } else {
                label
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    private func entryRow(_ entry: BookTimeline.Entry) -> some View {
        var personID: Int?
        if case .life(let id) = entry.kind { personID = id }
        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            title(entry, personID: personID)
            secondLine(entry.passage, detail: entry.detail(showingDates: showsDates))
        }
    }

    /// The passage and the length side by side, else one over the other. `ViewThatFits` builds both of its
    /// layouts, so it is used only for a row that has both; one alone is drawn as it is.
    @ViewBuilder private func secondLine(_ passage: Reference?, detail: String?) -> some View {
        if let passage, let detail {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) { passageRun(passage); detailText(detail) }
                VStack(alignment: .leading, spacing: 0) { passageRun(passage); detailText(detail) }
            }
        } else if let passage {
            passageRun(passage)
        } else if let detail {
            detailText(detail)
        }
    }

    /// A life's name is a link to People through its person (out of the tab order: the fold's button alone takes Tab).
    @ViewBuilder private func title(_ entry: BookTimeline.Entry, personID: Int?) -> some View {
        let text = Text(entry.title).font(type.font(.callout, weight: .medium)).foregroundStyle(Color.inkPrimary)
        if let personID {
            Button { onWalk(.person(personID)) } label: { text }
                .buttonStyle(.plain)
                .focusable(false)
        } else {
            text
        }
    }

    private func detailText(_ text: String) -> some View {
        Text(text).font(type.font(.caption)).foregroundStyle(Color.inkSecondary)
    }

    private func foldRow(_ fold: TimelineFold, isOpen: Bool) -> some View {
        Button {
            toggle(fold)
        } label: {
            let line = Text(fold.line).font(type.font(.callout, italic: true)).foregroundStyle(Color.inkSecondary)
            let toggle = Text(isOpen ? "Hide" : "Show").font(type.font(.callout)).foregroundStyle(Color.accent)
            // Show beside the line where both fit, else under it: side by side at the largest sizes the line broke
            // inside a name ("Lamec", "h").
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) { line.fixedSize(); toggle }
                VStack(alignment: .leading, spacing: 0) { line; toggle }
            }
        }
        .buttonStyle(.plain)
    }

    /// Scrolls the rail so `id`'s row is at the top (`animation`, or a cut), then settles it there. The rail is lazy:
    /// the scroll goes by the estimated heights of rows not yet made, which can leave the row short of the top or
    /// not yet made, so the rows made since are read and the scroll is taken the rest of the way, with no animation.
    /// On the Mac the row lands under the pinned chart, not behind it: aimed at the chart's foot by its anchor (exactly
    /// for a made row, whose height is known; near it for one not made yet), and corrected once it is made.
    private func land(on id: TimelineItemID, proxy: ScrollViewProxy, animation: Animation? = nil) {
        landing.begin(id)
        withAnimation(animation) { proxy.scrollTo(id, anchor: landingAnchor(id)) }
        // Settled on a clock, not on the animation's completion (which a scroll need not report): at once after a
        // cut, after the animated scroll's own length otherwise.
        Task {
            try? await Task.sleep(for: RailLanding.settleDelay(animated: animation != nil))
            await settle(on: id, proxy: proxy)
        }
    }

    private func settle(on id: TimelineItemID, proxy: ScrollViewProxy) async {
        var cut = Transaction()
        cut.disablesAnimations = true
        for _ in 0..<RailLanding.tries {
            try? await Task.sleep(for: RailLanding.pause)
            guard landing.target == id else { return }
            switch RailLanding.step(target: id, items: memo.railItems, tops: landing.tops, inset: landingInset) {
            case .landed: landing.end(); return
            case .scroll(let row, let edge): withTransaction(cut) { proxy.scrollTo(row, anchor: edge) }
            case .belowChart(let row): withTransaction(cut) { proxy.scrollTo(row, anchor: landingAnchor(row)) }
            }
        }
        landing.end()
    }

    /// How far down the window a row lands: the pinned chart's height on the Mac, read at each step (the come-back's
    /// first scroll can run before the chart is measured); the top on the phone.
    private var landingInset: CGFloat { chartShows ? geometry.chartHeight : 0 }

    private func landingAnchor(_ id: TimelineItemID) -> UnitPoint {
        RailLanding.anchor(inset: landingInset, viewport: geometry.viewportHeight, rowHeight: geometry.height(of: id) ?? 0)
    }

    private func toggle(_ fold: TimelineFold) {
        if openFolds.contains(fold.id) { openFolds.remove(fold.id) } else { openFolds.insert(fold.id) }
    }
}

/// The rail's rows and the chart's model, made again only when the timeline, the dates or the open folds change
/// (ruling 21), not on every redraw of the page. Not observed: the page writes it while drawing.
@MainActor final class TimelineMemo {
    struct Rail {
        let items: [TimelineItem]
        let dashed: Set<TimelineItemID>
    }

    private struct RailKey: Equatable {
        let timeline: BookTimeline, openFolds: Set<Int>, showingDates: Bool
    }

    private var railKey: RailKey?, railValue: Rail?
    private var chartKey: BookTimeline?, chartValue: TimelineChartModel?

    /// The rail's rows as last made, in order.
    var railItems: [TimelineItem] { railValue?.items ?? [] }

    func rail(_ timeline: BookTimeline, openFolds: Set<Int>, showingDates: Bool) -> Rail {
        let key = RailKey(timeline: timeline, openFolds: openFolds, showingDates: showingDates)
        if key == railKey, let railValue { return railValue }
        let items = TimelineItems.items(timeline, openFolds: openFolds, showingDates: showingDates)
        let rail = Rail(items: items, dashed: showingDates ? TimelineItems.dashedBelow(items) : [])
        railKey = key
        railValue = rail
        return rail
    }

    func chart(_ timeline: BookTimeline) -> TimelineChartModel {
        if timeline == chartKey, let chartValue { return chartValue }
        let model = TimelineChartModel(timeline)
        chartKey = timeline
        chartValue = model
        return model
    }
}

/// A scroll to a rail row on its way to the top: the row, and the tops of the rows made, in the scroll view's space.
/// Not observed: the rows write it while they are laid out, and it redraws nothing.
@MainActor final class RailLanding {
    enum Step: Equatable {
        case landed
        /// Scroll `row` to `edge`: the target itself, or a made row on the way to it.
        case scroll(TimelineItemID, UnitPoint)
        /// Scroll the target to the pinned chart's foot (the Mac), by its anchor.
        case belowChart(TimelineItemID)
    }

    /// Where a scroll lines a row up so its top lands `inset` down a window `viewport` high: SwiftUI lines the row's
    /// point at a fraction of its height up with the window's point at the same fraction, so the fraction is the
    /// inset over the window less the row (`rowHeight`, 0 for a row not made yet, which then lands a fraction of its
    /// height short and is corrected once made). The top with no inset (the phone) or no window yet.
    nonisolated static func anchor(inset: CGFloat, viewport: CGFloat, rowHeight: CGFloat = 0) -> UnitPoint {
        guard inset > 0, viewport - rowHeight > inset else { return .top }
        return UnitPoint(x: 0, y: inset / (viewport - rowHeight))
    }

    /// How many corrections a scroll is given, and the pause before each (a frame or so, for the rows to be made).
    static let tries = 6
    static let pause = Duration.milliseconds(20)

    /// The wait before the first correction: none after a cut; after an animated scroll, its length (`.smooth`'s
    /// half second) and a little more, so a correction never cuts into it.
    nonisolated static func settleDelay(animated: Bool) -> Duration { animated ? .milliseconds(550) : .zero }

    /// Whether the reader is scrolling (dragging, the wheel, or its fling), so a scroll on its way to a row gives way
    /// and is not corrected; the page's own animated scroll is not the reader's.
    nonisolated static func readerScrolls(_ phase: ScrollPhase) -> Bool {
        switch phase {
        case .tracking, .interacting, .decelerating: true
        case .idle, .animating: false
        @unknown default: false
        }
    }

    private(set) var target: TimelineItemID?
    private(set) var tops: [TimelineItemID: CGFloat] = [:]

    func begin(_ id: TimelineItemID) { target = id }
    func end() { target = nil }
    func top(_ id: TimelineItemID, _ top: CGFloat?) { tops[id] = top }

    /// What to do next for `target`: landed when its top is within a point of `inset` down the scroll view (the pinned
    /// chart's foot on the Mac, the top on the phone); the target again when it is made but elsewhere (to the chart's
    /// foot by its anchor on the Mac); otherwise the made row nearest it, at the top or the bottom edge, so the rows between come on
    /// screen and are made.
    nonisolated static func step(target: TimelineItemID, items: [TimelineItem], tops: [TimelineItemID: CGFloat],
                                 inset: CGFloat = 0) -> Step {
        if let top = tops[target] {
            if abs(top - inset) < 1 { return .landed }
            return inset > 0 ? .belowChart(target) : .scroll(target, .top)
        }
        guard let index = items.firstIndex(where: { $0.id == target }) else { return .landed }
        let made = items.indices.filter { tops[items[$0].id] != nil }
        if let below = made.first(where: { $0 > index }), made.allSatisfy({ $0 > index }) {
            return .scroll(items[below].id, .bottom)
        }
        if let above = made.last(where: { $0 < index }) { return .scroll(items[above].id, .top) }
        return .scroll(target, .top)
    }
}

/// Keeps a rail row's top, in the scroll view's space, in `landing` while the row is made. With the Mac's chart
/// (`geometry`) it also keeps the row's frame in the page's content space, which a scroll does not change, and
/// whether the row is made.
private struct RailRowTop: ViewModifier {
    let id: TimelineItemID
    let landing: RailLanding
    let geometry: RailGeometry?

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .scrollView).minY } action: { landing.top(id, $0) }
            .modifier(RailRowFrame(id: id, geometry: geometry))
            .onDisappear { landing.top(id, nil) }
    }
}

/// A rail row's frame in the page's content space, and its comings and goings, for the rows in view under the Mac's
/// chart. The frame is kept when the row goes: a row made again where it was reports no new frame (the lazy stack
/// reports one only on a change), only its appearance (Matt's review, 2026-11-24: the band froze after scrolling
/// down, up and down again).
struct RailRowFrame: ViewModifier {
    let id: TimelineItemID
    let geometry: RailGeometry?

    func body(content: Content) -> some View {
        if let geometry {
            content
                .onGeometryChange(for: ClosedRange<CGFloat>.self) { proxy in
                    let frame = proxy.frame(in: .named(RailViewport.space))
                    return frame.minY ... frame.maxY
                } action: { geometry.row(id, $0) }
                .onAppear { geometry.appeared(id) }
                .onDisappear { geometry.disappeared(id) }
        } else {
            content
        }
    }
}

/// The rail's ends in the page's content space, from what stands above the chart (the chart pins once the page
/// passes its foot) and below the rail (the chart leaves with it).
private struct RailEdge: ViewModifier {
    enum Edge { case top, bottom }
    let geometry: RailGeometry?
    let edge: Edge

    func body(content: Content) -> some View {
        if let geometry {
            content
                .onGeometryChange(for: CGFloat.self) { proxy in
                    let frame = proxy.frame(in: .named(RailViewport.space))
                    return edge == .top ? frame.maxY : frame.minY
                } action: { value in
                    if edge == .top { geometry.above(value) } else { geometry.below(value) }
                }
        } else {
            content
        }
    }
}

/// The window's top (below any inset) and foot in the content's space, at each scroll step.
private struct VisibleSpan: Equatable {
    let top: CGFloat, bottom: CGFloat, height: CGFloat
}

private extension View {
    /// Keeps the window's span in `geometry` as the page scrolls; the phone, and a page with no chart, pass none.
    @ViewBuilder func trackingTheRail(_ geometry: RailGeometry?) -> some View {
        if let geometry {
            onScrollGeometryChange(for: VisibleSpan.self) { scroll in
                VisibleSpan(top: scroll.visibleRect.minY + scroll.contentInsets.top, bottom: scroll.visibleRect.maxY,
                            height: scroll.containerSize.height)
            } action: { _, span in
                geometry.visible(span.top ... max(span.top, span.bottom), height: span.height)
            }
        } else {
            self
        }
    }
}

#if os(macOS)
/// The chart as the rail's section header: on `paper.page` across the column, so the rows going under it do not
/// show through, with a 1 pt `ink.rule` hairline under it only while it is pinned. It alone reads `state`, so a
/// scroll step that moves the band redraws the chart and nothing else; skipped on a redraw of the page unless its
/// model or rows change. The band moves with no animation (a cut under Reduce Motion too).
private struct PinnedTimelineChart: View, Equatable {
    let model: TimelineChartModel
    let items: [TimelineItem]
    let state: PinnedChartState
    let scrollTo: (TimelineItemID, Animation?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `scrollTo` is the page's one scroll view, wherever the closure was made.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model == rhs.model && lhs.items == rhs.items && lhs.state === rhs.state
    }

    var body: some View {
        let band = state.years.flatMap { TimelineChartModel.band(years: [$0.lowerBound, $0.upperBound], domain: model.domain) }
        TimelineChartView(model: model, band: band) { target in
            guard let id = TimelineItems.scrollTarget(target, items: items) else { return }
            scrollTo(id, reduceMotion ? nil : .smooth)
        }
        .transaction { $0.animation = nil }
        // The heading's gap above the chart, and below it the chart's own gap and the rail's.
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
        .background(Color.paperPage)
        .overlay(alignment: .bottom) { HairlineRule().opacity(state.isPinned ? 1 : 0) }
    }
}
#endif
