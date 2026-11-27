#if os(macOS)
import ScriptureData
import SwiftUI
import UniformTypeIdentifiers

/// The Reading Plan window: every week of the followed plan down the side, the chosen week's
/// readings beside it. Toolbar: the plans menu (choosing one follows it; Delete Plan… under the
/// plans), Change Meeting Date… for the chosen week, Import…, New Plan and Edit Plan…, which open
/// the review in a sheet. A PDF or text file dropped on the window is imported too. A delete is
/// undone with Edit › Undo.
public struct PlanWindowView: View {
    let model: ReadingPlanModel

    @State private var session: PlanEditorSession
    @State private var isImporting = false
    /// The chosen week, read only by the sidebar, the detail and Change Meeting Date…, so choosing
    /// a week does not run this body, its toolbar or its wiring.
    @State private var choice: PlanWindowChoice
    @State private var pendingDelete: ReadingPlan?
    @ScaledMetric(relativeTo: .body) private var sidebarWidth: CGFloat = 230
    @ScaledMetric(relativeTo: .title3) private var circleHitSize: CGFloat = 24
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.undoManager) private var undoManager

    public init(model: ReadingPlanModel) {
        self.model = model
        _session = State(initialValue: PlanEditorSession(model: model))
        // Chosen before the first layout, so the sidebar opens with this week in the middle.
        _choice = State(initialValue: PlanWindowChoice(plan: model.followed, now: model.now))
    }

    public var body: some View {
        content
            .overlay { readingOverlay }
            .frame(minWidth: 560, minHeight: 360)
            .background(Color.paperPage)
            .navigationSubtitle(model.followed?.title ?? "")
            .tint(Color.accent)
            .toolbar { toolbarContent }
            // The model's undo is this window's while it acts, and given back as it closes.
            .onChange(of: undoManager, initial: true) { old, manager in
                model.releaseUndoManager(old)
                model.adoptUndoManager(manager)
            }
            .onAppear {
                model.reload()
                reopen()
            }
            .onDisappear { model.releaseUndoManager(undoManager) }
            // A tick or a date changed in the main window or on another device meanwhile shows
            // when this window comes back to the front.
            .onChange(of: controlActiveState) { _, active in
                if active == .key {
                    model.adoptUndoManager(undoManager)
                    model.reload()
                }
            }
            .onChange(of: model.followed?.id) { _, _ in reopen() }
            .onChange(of: model.followed?.weeks.count) { _, count in
                if let chosen = choice.state.chosenWeek, chosen >= (count ?? 0) { reopen() }
            }
            // Midnight after the meeting: a window left on this week moves to the new one.
            .onChange(of: model.now) { old, new in
                choice.dayChanged(from: old, to: new, on: model.followed)
            }
            // Said by the window in front; the main window says what fails while it is.
            .alert(
                "Could not save",
                isPresented: Binding(get: { model.lastError != nil && controlActiveState == .key },
                                     set: { if !$0 { model.clearError() } }),
                presenting: model.lastError
            ) { _ in
                Button("OK") { model.clearError() }
            } message: { message in
                Text(message)
            }
            .confirmationDialog(
                "Delete “\(pendingDelete?.title ?? "this plan")”?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                presenting: pendingDelete
            ) { plan in
                Button("Delete", role: .destructive) { model.delete(plan.id) }
            } message: { _ in
                Text("The plan and what you have ticked in it will be deleted. Edit › Undo brings it back.")
            }
            .modifier(PlanImportWiring(session: session, isImporting: $isImporting))
    }

    /// While a file is read: the window's content is covered, and the window stays live.
    @ViewBuilder
    private var readingOverlay: some View {
        if case .reading = session.phase {
            ProgressView("Reading the plan…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.paperPage)
        }
    }

    /// This week again, in the middle of the sidebar: on opening, another plan followed, dates set.
    private func reopen() {
        choice.reopen(on: model.followed, now: model.now)
    }

    @ViewBuilder
    private var content: some View {
        if let plan = model.followed {
            if let line = PlanWeekText.placeholderLine(for: plan) {
                Text(line)
                    .font(.callout)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                HStack(spacing: 0) {
                    PlanWindowSidebar(model: model, choice: choice, plan: plan)
                        .frame(width: sidebarWidth)
                        .background(Color.paperPanel)
                    Divider()
                    PlanWindowDetail(model: model, choice: choice, plan: plan, circleHitSize: circleHitSize)
                }
            }
        } else {
            ContentUnavailableView {
                Label("No reading plan", systemImage: "calendar")
            } description: {
                Text("Import your group's plan, or type one in.")
            } actions: {
                HStack(spacing: AppSpacing.xs) {
                    Button("Import…") { isImporting = true }
                        .help("Bring in a plan from a PDF or a text file")
                    Button("New Plan") { session.newPlan() }
                        .help("Type a plan in")
                }
                .foregroundStyle(Color.inkPrimary)
                .disabled(isBusy)
            }
            .foregroundStyle(Color.inkSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Toolbar

    /// A file being read, or the review open: `isEditing`, which a key in the editor leaves alone.
    private var isBusy: Bool {
        if case .reading = session.phase { return true }
        return session.isEditing
    }

    /// The plans menu, Import…, New Plan, Edit Plan… and Change Meeting Date…, in one group.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if let followed = model.followed {
                plansMenu(followed)
            }
            Button { isImporting = true } label: {
                Label("Import…", systemImage: "square.and.arrow.down")
            }
            .help("Bring in a plan from a PDF or a text file")
            .disabled(isBusy)
            Button { session.newPlan() } label: {
                Label("New Plan", systemImage: "plus")
            }
            .help("Type a plan in")
            .disabled(isBusy)
            Button { session.editFollowedPlan() } label: {
                Label("Edit Plan…", systemImage: "pencil")
            }
            .help("Change this plan's weeks and readings")
            .disabled(isBusy || model.followed?.isReadable != true)
            if let followed = model.followed {
                PlanChangeDateButton(model: model, choice: choice, followed: followed)
            }
        }
    }

    private func plansMenu(_ followed: ReadingPlan) -> some View {
        Menu {
            Picker("Plan", selection: Binding(get: { Optional(followed.id) },
                                              set: { if let id = $0 { model.follow(id) } })) {
                ForEach(model.plans) { plan in
                    Text(plan.title).tag(Optional(plan.id))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            Divider()
            Button("Delete Plan…", role: .destructive) { pendingDelete = followed }
        } label: {
            Text(followed.title)
        }
        .help("Choose the plan to follow, or delete this one")
    }
}

/// The window's chosen week and where its sidebar opens, observed by the views that show them.
@MainActor @Observable final class PlanWindowChoice {
    var state = PlanWindowState()
    /// Where the sidebar's scroll rests: the chosen week, in the middle, as it opens.
    var openingWeek: Int?

    init(plan: ReadingPlan?, now: PlanSchedule.Now?) {
        reopen(on: plan, now: now)
    }

    func reopen(on plan: ReadingPlan?, now: PlanSchedule.Now?) {
        state.open(on: plan, now: now)
        openingWeek = state.chosenWeek
    }

    func dayChanged(from old: PlanSchedule.Now?, to new: PlanSchedule.Now?, on plan: ReadingPlan?) {
        let before = state.chosenWeek
        state.dayChanged(from: old, to: new, on: plan)
        if state.chosenWeek != before { openingWeek = state.chosenWeek }
    }

    /// The chosen week of a readable plan, when it is one of its weeks.
    func chosenWeek(of plan: ReadingPlan) -> Int? {
        guard plan.isReadable, let index = state.chosenWeek, plan.weeks.indices.contains(index) else { return nil }
        return index
    }
}

// MARK: - Sidebar

/// Every week, the chosen one on the accent's wash. One focus stop; the chosen week is the only
/// state, so ↑ and ↓ act on it whichever row is on screen.
private struct PlanWindowSidebar: View {
    let model: ReadingPlanModel
    @Bindable var choice: PlanWindowChoice
    let plan: ReadingPlan

    @FocusState private var listFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    ForEach(plan.weeks.indices, id: \.self) { index in
                        PlanSidebarRow(week: plan.weeks[index], progress: model.progress(ofWeek: index),
                                       isChosen: choice.state.chosenWeek == index,
                                       locale: model.locale, calendar: model.calendar) { choose(index) }
                            .equatable()
                            .id(index)
                    }
                }
                .padding(AppSpacing.xs)
                .scrollTargetLayout()
            }
            .scrollPosition(id: $choice.openingWeek, anchor: .center)
            .focusable()
            .focused($listFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) { move(by: -1) }
            .onKeyPress(.downArrow) { move(by: 1) }
            .onChange(of: choice.state.chosenWeek) { _, index in
                guard let index else { return }
                if reduceMotion {
                    proxy.scrollTo(index)
                } else {
                    withAnimation(.smooth) { proxy.scrollTo(index) }
                }
            }
            .onAppear { listFocused = true }
        }
    }

    private func choose(_ index: Int) {
        choice.state.choose(index)
        listFocused = true
    }

    private func move(by step: Int) -> KeyPress.Result {
        let before = choice.state.chosenWeek
        choice.state.move(by: step, count: plan.weeks.count)
        return choice.state.chosenWeek == before ? .ignored : .handled
    }
}

/// "Week 63" with its date and count trailing. Compared by its values, so choosing a week redraws
/// the two rows whose state changed and no other formats its dates again.
struct PlanSidebarRow: View, Equatable {
    let week: PlanWeek
    let progress: PlanProgress
    let isChosen: Bool
    let locale: Locale
    let calendar: Calendar
    let onChoose: () -> Void

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.week == rhs.week && lhs.progress == rhs.progress && lhs.isChosen == rhs.isChosen
            && lhs.locale == rhs.locale && lhs.calendar == rhs.calendar
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            Text("Week \(week.number)")
                .font(.callout)
                .foregroundStyle(Color.inkPrimary)
            Spacer(minLength: AppSpacing.xs)
            Text(PlanWeekText.sidebarLine(week, progress: progress, locale: locale, calendar: calendar))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(AppSpacing.xs)
        .background {
            if isChosen {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous).fill(Color.accentWash)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onChoose)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PlanWeekText.spokenWeek(week, progress: progress, locale: locale, calendar: calendar))
        .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onChoose() }
    }
}

// MARK: - Detail

/// The chosen week: its title in the page face, its line, then its readings.
private struct PlanWindowDetail: View {
    let model: ReadingPlanModel
    let choice: PlanWindowChoice
    let plan: ReadingPlan
    let circleHitSize: CGFloat

    @Environment(\.pageFace) private var pageFace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if model.isFinished {
                    Text(PlanWeekText.finishedLine)
                        .font(.callout)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.bottom, AppSpacing.xs)
                }
                if let index = choice.state.chosenWeek, plan.weeks.indices.contains(index) {
                    let week = plan.weeks[index]
                    Text("Week \(week.number)")
                        .font(pageFace.swiftUIFont(.title2))
                        .foregroundStyle(Color.inkPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(PlanWeekText.detailLine(week, progress: model.progress(ofWeek: index), locale: model.locale, calendar: model.calendar))
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.top, AppSpacing.xxs)
                        .padding(.bottom, AppSpacing.xs)
                    if model.needsAnchor {
                        // Starts on the chosen week: the group may be far into the plan.
                        PlanAnchorView(weeks: plan.weeks, calendar: model.calendar, locale: model.locale,
                                       today: model.today, startWeek: index) { week, day in
                            model.anchor(week: week, on: day)
                            choice.reopen(on: model.followed, now: model.now)
                        }
                        .id(index)
                        .padding(.vertical, AppSpacing.sm)
                    }
                    // By place: a row holds no state of its own, so another week's rows update in
                    // place rather than being made again.
                    ForEach(Array(week.readings.enumerated()), id: \.offset) { offset, reading in
                        PlanReadingRow(reading: reading, index: offset, count: week.readings.count,
                                       layout: .inline, hitSize: circleHitSize, model: model)
                            .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.paperPage)
    }
}

/// Change Meeting Date… for the chosen week, in a popover under the button.
private struct PlanChangeDateButton: View {
    let model: ReadingPlanModel
    let choice: PlanWindowChoice
    let followed: ReadingPlan

    @State private var isChangingDate = false

    var body: some View {
        Button { isChangingDate = true } label: {
            Label("Change Meeting Date…", systemImage: "calendar")
        }
        .help("Change the day this week meets")
        .disabled(choice.chosenWeek(of: followed) == nil)
        .popover(isPresented: $isChangingDate, arrowEdge: .bottom) {
            if let index = choice.chosenWeek(of: followed) {
                ChangeMeetingDateView(week: followed.weeks[index], calendar: model.calendar, locale: model.locale,
                                      today: model.today) { day in
                    model.setDay(day, ofWeek: index)
                    isChangingDate = false
                } onCancel: {
                    isChangingDate = false
                }
                .padding(AppSpacing.md)
            }
        }
    }
}

/// The review's sheet, the file panel, a dropped file and a file that could not be read; kept off
/// the window's own chain.
private struct PlanImportWiring: ViewModifier {
    let session: PlanEditorSession
    @Binding var isImporting: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(get: { session.isEditing }, set: { if !$0 { session.cancel() } })) {
                PlanEditorView(session: session)
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf, .plainText]) { result in
                switch result {
                case let .success(url): importFile(url)
                case .failure: session.importFailed()
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard !session.isEditing, let url = urls.first(where: Self.isPlanFile) else { return false }
                importFile(url)
                return true
            }
            .alert(
                failureMessage ?? "",
                isPresented: Binding(get: { failureMessage != nil }, set: { if !$0 { session.dismissFailure() } })
            ) {
                Button("OK") { session.dismissFailure() }
                if offersNewPlan {
                    Button("New Plan") {
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

    private func importFile(_ url: URL) {
        Task { await session.importFile(at: url) }
    }

    /// A PDF or a text file, by its name.
    nonisolated static func isPlanFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .pdf) || type.conforms(to: .plainText)
    }
}
#endif
