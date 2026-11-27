import ScriptureData
import SwiftUI

/// The review and the editor, on both apps: the title, what to check, and every week as lines of text.
/// One plain `List`, so a plan of 86 weeks is laid out as it scrolls. Nothing is stored until Save.
///
/// Each field writes through the session's mutators by id (`PlanEditorRows.swift`), so a field
/// that commits after Save or Cancel reaches nothing. A week's header, its lines and its foot are
/// views of their own over values, so a key re-runs the body of the one line typed in.
public struct PlanEditorView: View {
    let session: PlanEditorSession

    @FocusState private var focus: PlanEditorField?
    @ScaledMetric(relativeTo: .headline) private var numberWidth: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 24
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.undoManager) private var undoManager

    public init(session: PlanEditorSession) {
        self.session = session
    }

    private var model: ReadingPlanModel { session.model }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    head
                    if !session.flags.isEmpty { toCheck(proxy) }
                    ForEach(session.draft?.weeks ?? []) { week in
                        weekSection(week)
                    }
                    foot
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.paperPage)
                #if os(iOS)
                // The number pad has no Return: a drag down the list puts the keyboard away.
                .scrollDismissesKeyboard(.interactively)
                #endif
            }
            #if os(macOS)
            Divider()
            actions
            #endif
        }
        .background(Color.paperPage)
        .tint(Color.accent)
        .navigationTitle(session.heading)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(minWidth: 620, idealWidth: 680, minHeight: 520, idealHeight: 640)
        #else
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { cancelButton }
            ToolbarItem(placement: .confirmationAction) { saveButton }
        }
        #endif
        // Removes and moves in the draft are undone in the sheet's own manager (⌘Z, a shake).
        .onChange(of: undoManager, initial: true) { _, manager in session.undoManager = manager }
        // A save the store refused: said here, over the draft, which stays.
        .alert(
            "Could not save",
            isPresented: Binding(get: { session.saveFailure != nil }, set: { if !$0 { session.clearSaveFailure() } }),
            presenting: session.saveFailure
        ) { _ in
            Button("OK") { session.clearSaveFailure() }
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Head

    private var head: some View {
        Group {
            #if os(macOS)
            Text(session.heading)
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
                .accessibilityAddTraits(.isHeader)
                .editorRow(top: AppSpacing.md)
            #endif
            TextField("Plan title", text: Binding(get: { session.draft?.title ?? "" }, set: { session.setTitle($0) }),
                      prompt: Text("Plan title"))
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($focus, equals: .title)
                .onSubmit { focusFirstLine() }
                .help("The plan's title")
                .editorRow(top: AppSpacing.xs)
            if let year = session.draft?.firstYear {
                startsIn(year)
                    .editorRow(top: AppSpacing.xxs)
            }
        }
    }

    /// The first date with its year; the stepper moves every date that came from the file.
    private func startsIn(_ year: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            Stepper(value: Binding(get: { year }, set: { session.setFirstYear($0) }),
                    in: (model.today.year - 10)...(model.today.year + 10)) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
                    Text("Starts in")
                        .foregroundStyle(Color.inkSecondary)
                    Text(verbatim: String(year))
                        .monospacedDigit()
                        .foregroundStyle(Color.inkPrimary)
                }
                .font(.callout)
            }
            .fixedSize()
            .help("The year the plan starts in; every date from the file follows")
            .accessibilityLabel("Starts in")
            .accessibilityValue(String(year))
            if let first = session.draft?.weeks.first(where: { $0.day != nil }), let day = first.day {
                Text("Week \(first.number) meets \(PlanWeekText.dateWithYear(day, locale: model.locale, calendar: model.calendar))")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    // MARK: - To check

    private func toCheck(_ proxy: ScrollViewProxy) -> some View {
        Group {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text("To check")
                Text(verbatim: "\(session.flags.count)")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.inkSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .editorRow(top: AppSpacing.lg)
            ForEach(session.flags) { flag in
                Button { go(to: flag, proxy) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Color.inkSecondary)
                        Text(flag.sentence)
                            .foregroundStyle(Color.inkPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .font(.callout)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Go to week")
                .editorRow(top: AppSpacing.xxs)
            }
        }
    }

    /// The week comes into view; a line's flag then puts the keyboard in that line, a turn later,
    /// once the row it scrolled to exists.
    private func go(to flag: PlanFlag, _ proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo(flag.weekID, anchor: .top)
        } else {
            withAnimation(.smooth) { proxy.scrollTo(flag.weekID, anchor: .top) }
        }
        if let reading = flag.readingID {
            Task { @MainActor in focus = .reading(reading) }
        }
    }

    // MARK: - A week

    private func weekSection(_ week: PlanDraft.Week) -> some View {
        PlanEditorWeekSection(week: week, numberText: session.numberText(of: week),
                              flags: week.readings.map { session.flags(forReading: $0.id) },
                              locale: model.locale, calendar: model.calendar, numberWidth: numberWidth, buttonSize: buttonSize,
                              session: session, focus: $focus)
            .equatable()
            // Given to the section from outside: a row's own list modifiers are not seen through
            // `.equatable()`. Each row's space above it is its own padding.
            .editorRow(top: 0)
    }

    // MARK: - Foot

    private var foot: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            Button(action: addWeek) {
                Label("Add Week", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accent)
            .help("Add a week after the last")
            if session.offersPaste {
                PasteButton(payloadType: String.self) { strings in
                    let text = strings.joined(separator: "\n")
                    Task { @MainActor in session.paste(text) }
                }
                .help("Add the weeks in the copied text")
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
        .editorRow(top: AppSpacing.lg, bottom: AppSpacing.lg)
    }

    #if os(macOS)
    /// Save is not the default action: Return in a line moves to the next line.
    private var actions: some View {
        HStack(spacing: AppSpacing.xs) {
            Spacer(minLength: 0)
            cancelButton
            saveButton
        }
        .padding(AppSpacing.md)
    }
    #endif

    private var cancelButton: some View {
        Button("Cancel") { session.cancel() }
            .keyboardShortcut(.cancelAction)
            .help("Close without saving")
    }

    private var saveButton: some View {
        #if os(iOS)
        Button("Save", systemImage: "checkmark") { session.save() }
            .disabled(!session.canSave)
            .help(saveHelp)
        #else
        Button("Save") { session.save() }
            .buttonStyle(.borderedProminent)
            .disabled(!session.canSave)
            .help(saveHelp)
        #endif
    }

    private var saveHelp: String {
        if session.canSave { return "Save the plan" }
        if session.draft?.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true { return "Give the plan a title to save it" }
        return "Correct each line that cannot be read to save the plan"
    }

    // MARK: - Moving between lines

    private func addWeek() {
        session.addWeek()
        PlanEditorField.focusLastLine(of: session, in: $focus) { _ in true }
    }

    private func focusFirstLine() {
        if let first = session.draft?.weeks.first?.readings.first { focus = .reading(first.id) }
    }
}
