#if os(iOS)
import ScriptureData
import SwiftUI
import UniformTypeIdentifiers

/// The Plan tab: the followed plan's weeks in one plain list, this week at its head with its
/// readings, the weeks to come below and the weeks before above; it opens scrolled to this week
/// each time the tab shows. A week row opens its readings in place, one week at a time; nothing
/// is pushed, so the tab's left edge always belongs to the edge swipes. The `ellipsis` menu
/// chooses the plan followed, imports a file, starts or edits a plan (the editor is a full sheet),
/// changes this week's meeting date and deletes the plan (undone by a shake, as in the Notes
/// tab). A passage opened goes to the Read tab.
public struct PhonePlanScreen: View {
    private let plans: ReadingPlanModel
    private let shell: PhoneShellModel
    @State private var openWeek: Int?
    @State private var changingDate: DateChange?
    @State private var pendingDelete: ReadingPlan?
    @State private var session: PlanEditorSession
    @State private var isImporting = false
    @Environment(\.undoManager) private var undoManager
    @Environment(\.pageFace) private var pageFace
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The circle's and each passage's thumb target.
    @ScaledMetric(relativeTo: .title3) private var hitSize: CGFloat = 44
    /// Between two readings of a week: `xl`, growing with the text as the passages' targets do.
    @ScaledMetric(relativeTo: .title3) private var readingGap: CGFloat = AppSpacing.xl

    /// The week whose meeting date is being changed, in the sheet.
    private struct DateChange: Identifiable {
        let week: Int
        var id: Int { week }
    }

    /// False for the copy built out of sight to warm the tab (`PhoneEdgeSwipes.warmUp`): it neither
    /// reloads the model nor takes the undo manager, which are the shown tab's.
    private let actsOnAppear: Bool

    public init(plans: ReadingPlanModel, shell: PhoneShellModel) {
        self.init(plans: plans, shell: shell, openWeek: nil, session: PlanEditorSession(model: plans))
    }

    /// `openWeek`: a week shown open from the start (a render).
    init(plans: ReadingPlanModel, shell: PhoneShellModel, openWeek: Int?, session: PlanEditorSession, actsOnAppear: Bool = true) {
        self.plans = plans
        self.shell = shell
        self.actsOnAppear = actsOnAppear
        _session = State(initialValue: session)
        _openWeek = State(initialValue: openWeek)
    }

    /// The tab built once out of sight, so the first swipe into it finds its list machinery ready.
    static func warmUpCopy(plans: ReadingPlanModel, shell: PhoneShellModel) -> PhonePlanScreen {
        PhonePlanScreen(plans: plans, shell: shell, openWeek: nil, session: PlanEditorSession(model: plans), actsOnAppear: false)
    }

    public var body: some View {
        NavigationStack {
            content
                .background(Color.paperPage)
                .navigationTitle(plans.followed?.title ?? "Plan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .tint(Color.accent)
        .onAppear { if actsOnAppear { plans.reload() } }
        // The scene's undo manager, so a deleted plan comes back with shake or a three-finger swipe.
        .onChange(of: undoManager, initial: true) { old, manager in
            guard actsOnAppear else { return }
            plans.releaseUndoManager(old)
            plans.adoptUndoManager(manager)
        }
        .background {
            if actsOnAppear { UndoResponder(undoManager: undoManager).frame(width: 0, height: 0) }
        }
        // Another plan followed: its own weeks, none of them open.
        .onChange(of: plans.followed?.id) { openWeek = nil }
        .sheet(item: $changingDate) { change in
            dateSheet(change.week)
        }
        .modifier(PhonePlanImportWiring(session: session, isImporting: $isImporting))
        .confirmationDialog(
            "Delete “\(pendingDelete?.title ?? "this plan")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { plan in
            Button("Delete", role: .destructive) { plans.delete(plan.id) }
        } message: { _ in
            Text("The plan and what you have ticked in it will be deleted.")
        }
        .alert(
            "Could not save",
            isPresented: Binding(get: { plans.lastError != nil }, set: { if !$0 { plans.clearError() } }),
            presenting: plans.lastError
        ) { _ in
            Button("OK") { plans.clearError() }
        } message: { message in
            Text(message)
        }
    }

    private var isReading: Bool {
        if case .reading = session.phase { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        if isReading {
            ProgressView("Reading the plan…")
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let plan = plans.followed {
            if PlanWeekText.placeholderLine(for: plan) == nil, let now = plans.now {
                list(plan, PhonePlanList(plan: plan, now: now, openWeek: openWeek))
            } else {
                Text(PlanWeekText.placeholderLine(for: plan) ?? PlanWeekText.unreadableLine)
                    .font(.callout)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            ContentUnavailableView {
                Label("No reading plan", systemImage: "calendar")
                    .foregroundStyle(Color.inkSecondary)
            } description: {
                Text("Import your group's plan, or type one in.")
                    .foregroundStyle(Color.inkSecondary)
            } actions: {
                Button(PhonePlanMenu.title(.importFile)) { isImporting = true }
                Button(PhonePlanMenu.title(.newPlan)) { session.newPlan() }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - The list

    private func list(_ plan: ReadingPlan, _ rows: PhonePlanList) -> some View {
        ScrollViewReader { proxy in
            List {
                ForEach(rows.rows, id: \.self) { row in
                    self.row(row, in: plan)
                        .listRowBackground(Color.paperPage)
                        .listRowSeparatorTint(Color.inkRule)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            // This week at the head, as a cut, each time the tab shows; again once the bar's
            // inset is applied, which it is not at appearance. Another plan followed, and the day
            // moving this week on, bring the new this week to the head too.
            .onAppear { scrollToThisWeek(rows, proxy) }
            .onChange(of: plans.followed?.id) { scrollToThisWeek(rows, proxy) }
            .onChange(of: plans.thisWeek?.index) { scrollToThisWeek(rows, proxy) }
        }
    }

    private func scrollToThisWeek(_ rows: PhonePlanList, _ proxy: ScrollViewProxy) {
        guard let target = rows.scrollTarget else { return }
        proxy.scrollTo(target, anchor: .top)
        Task { @MainActor in
            await Task.yield()
            proxy.scrollTo(target, anchor: .top)
        }
    }

    @ViewBuilder
    private func row(_ row: PhonePlanList.Row, in plan: ReadingPlan) -> some View {
        switch row {
        case .finished:
            Text(PlanWeekText.finishedLine)
                .font(.callout)
                .foregroundStyle(Color.inkSecondary)
                .listRowInsets(Self.textInsets)
                .listRowSeparator(.hidden)
        case .anchor:
            PlanAnchorView(weeks: plan.weeks, calendar: plans.calendar, locale: plans.locale, today: plans.today) { week, day in
                plans.anchor(week: week, on: day)
                openWeek = nil
            }
            .environment(\.locale, plans.locale)
            .listRowInsets(EdgeInsets(top: AppSpacing.md, leading: AppSpacing.lg, bottom: AppSpacing.md, trailing: AppSpacing.lg))
        case .week(let index):
            weekRow(plan.weeks[index], index: index)
        case .thisWeek:
            if let thisWeek = plans.thisWeek { thisWeekHeader(thisWeek) }
        case .reading(let week, let id):
            if let offset = plan.weeks[week].readings.firstIndex(where: { $0.id == id }) {
                let readings = plan.weeks[week].readings
                PlanReadingRow(reading: readings[offset], index: offset, count: readings.count, layout: .stacked,
                               hitSize: hitSize, passageHeight: hitSize, model: plans)
                    // The hairline under the block starts where the weeks' do.
                    .alignmentGuide(.listRowSeparatorLeading) { _ in AppSpacing.lg - AppSpacing.sm }
                    // The circle's glyph, centred in its target, lines up with the titles' text;
                    // readings are `readingGap` apart, so the space between two readings is at least
                    // twice the space between two passages of one, and each reads as one.
                    .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.sm, bottom: readingGap, trailing: AppSpacing.lg))
                    // The readings of one week are one block; a hairline closes it.
                    .listRowSeparator(offset == readings.count - 1 ? .visible : .hidden, edges: .bottom)
            }
        case .next:
            Text("Next")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .accessibilityAddTraits(.isHeader)
                .listRowInsets(EdgeInsets(top: AppSpacing.lg, leading: AppSpacing.lg, bottom: AppSpacing.xxs, trailing: AppSpacing.lg))
                .listRowSeparator(.hidden)
        }
    }

    private static let textInsets = EdgeInsets(top: AppSpacing.md, leading: AppSpacing.lg, bottom: AppSpacing.xs, trailing: AppSpacing.lg)

    /// "This week" in the page face, the week's title line under it, then the plan's progress.
    private func thisWeekHeader(_ thisWeek: ReadingPlanModel.ThisWeek) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("This week")
                .font(pageFace.swiftUIFont(.title2))
                .foregroundStyle(Color.inkPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(PlanWeekText.titleLine(thisWeek.week, count: thisWeek.count, today: plans.today,
                                        locale: plans.locale, calendar: plans.calendar))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Color.inkSecondary)
            PlanProgressLine(progress: plans.progress)
                .padding(.top, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: AppSpacing.lg, leading: AppSpacing.lg, bottom: AppSpacing.xs, trailing: AppSpacing.lg))
        .listRowSeparator(.hidden)
    }

    /// "Week 54" with its date and count trailing (under it at the accessibility sizes); a tap
    /// opens it in place and closes any other, another tap closes it.
    private func weekRow(_ week: PlanWeek, index: Int) -> some View {
        let progress = plans.progress(ofWeek: index)
        let isOpen = openWeek == index
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: AppSpacing.xs))
        return Button {
            openWeek = isOpen ? nil : index
        } label: {
            layout {
                Text("Week \(week.number)")
                    .font(.body)
                    .foregroundStyle(Color.inkPrimary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: AppSpacing.xs) }
                Text(PlanWeekText.sidebarLine(week, progress: progress, locale: plans.locale, calendar: plans.calendar))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PlanWeekText.spokenWeek(week, progress: progress, locale: plans.locale, calendar: plans.calendar))
        .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
        // One hairline the full width of every row, as in the Notes tab.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .contextMenu {
            Button("Change Meeting Date…", systemImage: "calendar") { changingDate = DateChange(week: index) }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.lg, bottom: 0, trailing: AppSpacing.lg))
        // An open week's readings follow without a hairline under its name.
        .listRowSeparator(isOpen ? .hidden : .visible, edges: .bottom)
    }

    // MARK: - Change Meeting Date…

    @ViewBuilder
    private func dateSheet(_ index: Int) -> some View {
        if let plan = plans.followed, plan.isReadable, plan.weeks.indices.contains(index) {
            NavigationStack {
                ChangeMeetingDateView(week: plan.weeks[index], calendar: plans.calendar, locale: plans.locale,
                                      today: plans.today, actionsInBar: true) { day in
                    plans.setDay(day, ofWeek: index)
                    changingDate = nil
                } onCancel: {
                    changingDate = nil
                }
                .environment(\.locale, plans.locale)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.paperPage)
                .navigationTitle("Change Meeting Date")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
            .tint(Color.accent)
        }
    }

    // MARK: - The menu

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let followed = plans.followed {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(PhonePlanMenu.items(planCount: plans.plans.count, followedIsReadable: followed.isReadable,
                                                hasThisWeek: plans.thisWeek != nil), id: \.self) { item in
                        menuItem(item, followed: followed)
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .disabled(isReading)
            }
        }
    }

    @ViewBuilder
    private func menuItem(_ item: PhonePlanMenu.Item, followed: ReadingPlan) -> some View {
        switch item {
        case .plans:
            Picker(PhonePlanMenu.title(item), selection: Binding(get: { followed.id }, set: { plans.follow($0) })) {
                ForEach(plans.plans) { plan in
                    Text(plan.title).tag(plan.id)
                }
            }
            .pickerStyle(.inline)
        case .importFile:
            Button(PhonePlanMenu.title(item), systemImage: "square.and.arrow.down") { isImporting = true }
        case .newPlan:
            Button(PhonePlanMenu.title(item), systemImage: "plus") { session.newPlan() }
        case .editPlan:
            Button(PhonePlanMenu.title(item), systemImage: "pencil") { session.editFollowedPlan() }
        case .changeMeetingDate:
            if let thisWeek = plans.thisWeek {
                Button(PhonePlanMenu.title(item), systemImage: "calendar") { changingDate = DateChange(week: thisWeek.index) }
            }
        case .deletePlan:
            Button(PhonePlanMenu.title(item), systemImage: "trash", role: .destructive) { pendingDelete = followed }
        }
    }
}

/// The editor's full sheet, the system's file picker and the alert for a file that could not be
/// read; kept off the screen's own chain.
private struct PhonePlanImportWiring: ViewModifier {
    let session: PlanEditorSession
    @Binding var isImporting: Bool

    func body(content: Content) -> some View {
        content
            // Swiping the sheet down is Cancel: nothing was stored, so nothing is asked.
            .sheet(isPresented: Binding(get: { session.isEditing }, set: { if !$0 { session.cancel() } })) {
                NavigationStack {
                    PlanEditorView(session: session)
                }
                .presentationDetents([.large])
                .background(Color.paperPage)
                .tint(Color.accent)
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf, .plainText]) { result in
                switch result {
                case let .success(url): importFile(url)
                case .failure: session.importFailed()
                }
            }
            .alert(
                failureMessage ?? "",
                isPresented: Binding(get: { failureMessage != nil }, set: { if !$0 { session.dismissFailure() } })
            ) {
                Button("OK") { session.dismissFailure() }
                if offersNewPlan {
                    Button(PhonePlanMenu.title(.newPlan)) {
                        session.dismissFailure()
                        session.newPlan()
                    }
                }
            }
    }

    private var failureMessage: String? {
        if case let .failed(message, _) = session.phase { return message }
        return nil
    }

    private var offersNewPlan: Bool {
        if case let .failed(_, offers) = session.phase { return offers }
        return false
    }

    /// A file from the picker is outside the app's container: `PlanFileImport.draft` asks for
    /// access itself, around its read.
    private func importFile(_ url: URL) {
        Task { await session.importFile(at: url) }
    }
}

#endif
