import ScriptureData
import SwiftUI

/// What in the editor can hold the keyboard.
enum PlanEditorField: Hashable {
    case title, number(UUID), label(UUID), reading(UUID)

    /// The new row exists only after the list's next update, so the keyboard goes to it a turn later.
    @MainActor static func focusLastLine(of session: PlanEditorSession, in focus: FocusState<PlanEditorField?>.Binding,
                                         ofLastWeekWhere matches: @escaping (PlanDraft.Week) -> Bool) {
        guard let line = session.draft?.weeks.last(where: matches)?.readings.last?.id else { return }
        Task { @MainActor in focus.wrappedValue = .reading(line) }
    }
}

// The editor's rows. Each is a view over values, compared with `==` (`.equatable()`), so a key
// re-runs only the row whose values changed, and a week's header is only built when it is on
// screen. The session and the focus binding are the same for every row and are not compared.

/// A week: its header, its lines and its foot. Compared by the week's values, so a key in one
/// line leaves every other week as it was.
struct PlanEditorWeekSection: View, Equatable {
    let week: PlanDraft.Week
    let numberText: String
    /// Each line's flags, in the week's order.
    let flags: [[PlanFlag]]
    let locale: Locale
    let calendar: Calendar
    let numberWidth: CGFloat
    let buttonSize: CGFloat
    let session: PlanEditorSession
    let focus: FocusState<PlanEditorField?>.Binding

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.week == rhs.week && lhs.numberText == rhs.numberText && lhs.flags == rhs.flags && lhs.locale == rhs.locale
            && lhs.calendar == rhs.calendar && lhs.numberWidth == rhs.numberWidth && lhs.buttonSize == rhs.buttonSize
    }

    var body: some View {
        Section {
            PlanEditorWeekHeader(id: week.id, number: week.number, numberText: numberText, day: week.day, label: week.label,
                                 locale: locale, calendar: calendar, numberWidth: numberWidth, session: session, focus: focus)
                .equatable()
                .id(week.id)
                .padding(.top, AppSpacing.lg)
            ForEach(Array(week.readings.enumerated()), id: \.element.id) { place, reading in
                PlanEditorReadingRow(reading: reading, place: place + 1, count: week.readings.count, weekID: week.id,
                                     nextID: place + 1 < week.readings.count ? week.readings[place + 1].id : nil,
                                     flags: flags.indices.contains(place) ? flags[place] : [], buttonSize: buttonSize,
                                     session: session, focus: focus)
                    .equatable()
                    .padding(.top, AppSpacing.xxs)
            }
            .onMove { [id = week.id] offsets, destination in
                session.moveReadings(inWeek: id, fromOffsets: offsets, toOffset: destination)
            }
            PlanEditorWeekFoot(id: week.id, number: week.number, buttonSize: buttonSize, session: session, focus: focus)
                .equatable()
                .padding(.top, AppSpacing.xxs)
        }
    }
}

/// "Week", its number, its date and its label.
struct PlanEditorWeekHeader: View, Equatable {
    let id: UUID
    let number: Int
    let numberText: String
    let day: PlanDay?
    let label: String
    let locale: Locale
    let calendar: Calendar
    let numberWidth: CGFloat
    let session: PlanEditorSession
    let focus: FocusState<PlanEditorField?>.Binding

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.number == rhs.number && lhs.numberText == rhs.numberText && lhs.day == rhs.day
            && lhs.label == rhs.label && lhs.locale == rhs.locale && lhs.calendar == rhs.calendar && lhs.numberWidth == rhs.numberWidth
    }

    var body: some View {
        let numberField = TextField("Week number", text: Binding(get: { numberText }, set: { session.setNumberText($0, ofWeek: id) }),
                                    prompt: Text(verbatim: ""))
            .weekField()
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .frame(width: numberWidth)
            .focused(focus, equals: .number(id))
            .help("The week's number")
        let weekText = Text("Week")
            .font(.headline)
            .foregroundStyle(Color.inkPrimary)
            .accessibilityLabel(PlanWeekText.spokenHeader(number: number, day: day, locale: locale, calendar: calendar))
            .accessibilityAddTraits(.isHeader)
        let labelField = TextField("Label", text: Binding(get: { label }, set: { session.setLabel($0, ofWeek: id) }),
                                   prompt: PlanEditorField.prompt("Label"))
            .weekField()
            .frame(maxWidth: .infinity)
            .focused(focus, equals: .label(id))
            .help("A label for the week, such as Leader Dinner or OFF")
        #if os(iOS)
        // On the phone the label has a line of its own, so the number and the date keep their room.
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            let line = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xs))
                : AnyLayout(HStackLayout(alignment: .center, spacing: AppSpacing.sm))
            line {
                HStack(alignment: .center, spacing: AppSpacing.xs) {
                    weekText
                    numberField
                }
                dateControl
            }
            labelField
        }
        #else
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            weekText
            numberField
            dateControl
            labelField
        }
        #endif
    }

    /// The date as a compact picker (Clear in its context menu), or Set Date when it has none.
    @ViewBuilder
    private var dateControl: some View {
        if let day {
            DayPicker(title: "Meets", day: Binding(get: { day }, set: { session.setDay($0, ofWeek: id) }),
                      calendar: calendar, locale: locale)
                .labelsHidden()
                .datePickerStyle(.compact)
                .fixedSize()
                .contextMenu {
                    Button("Clear") { session.setDay(nil, ofWeek: id) }
                }
                .help("The day this week meets; moving it moves the later dated weeks too")
        } else {
            Button("Set Date") { session.setSuggestedDay(ofWeek: id) }
                .fixedSize()
                .help("Give this week a meeting date")
        }
    }
}

/// One line of a week: its text, Remove Reading, and what the review marks in it.
struct PlanEditorReadingRow: View, Equatable {
    let reading: PlanDraft.Reading
    /// From 1.
    let place: Int
    let count: Int
    let weekID: UUID
    /// The week's next line; nil for its last.
    let nextID: UUID?
    let flags: [PlanFlag]
    let buttonSize: CGFloat
    let session: PlanEditorSession
    let focus: FocusState<PlanEditorField?>.Binding

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.reading == rhs.reading && lhs.place == rhs.place && lhs.count == rhs.count && lhs.weekID == rhs.weekID
            && lhs.nextID == rhs.nextID && lhs.flags == rhs.flags && lhs.buttonSize == rhs.buttonSize
    }

    var body: some View {
        let id = reading.id
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                TextField("Reading \(place) of \(count)", text: Binding(get: { reading.text }, set: { session.setText($0, ofReading: id) }),
                          prompt: Text("Psalms 84; Esther 7-8"))
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused(focus, equals: .reading(id))
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    #endif
                    .onSubmit(advance)
                    .help("A reading: its passages separated by semicolons, and a label in parentheses after them")
                Button { session.removeReading(id) } label: {
                    Image(systemName: "minus.circle")
                        .frame(minWidth: buttonSize, minHeight: buttonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.inkSecondary)
                .help("Remove Reading")
                .accessibilityLabel("Remove Reading")
            }
            // Read by VoiceOver after the line's text, as the next element. The week is in the
            // header above, so the mark leaves it out.
            ForEach(flags) { flag in
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
                    Image(systemName: "exclamationmark.triangle")
                        .accessibilityHidden(true)
                    Text(flag.lineSentence)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
                .accessibilityElement(children: .combine)
            }
        }
        #if os(iOS)
        .swipeActions {
            Button("Remove Reading", role: .destructive) { session.removeReading(id) }
        }
        #endif
    }

    /// Return: the next line of the week; at the week's end a new line, unless this one is blank.
    private func advance() {
        if let nextID {
            focus.wrappedValue = .reading(nextID)
        } else if !reading.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            session.addReading(toWeek: weekID)
            PlanEditorField.focusLastLine(of: session, in: focus) { [weekID] in $0.id == weekID }
        }
    }
}

/// Add Reading, and the week's menu with Remove Week.
struct PlanEditorWeekFoot: View, Equatable {
    let id: UUID
    let number: Int
    let buttonSize: CGFloat
    let session: PlanEditorSession
    let focus: FocusState<PlanEditorField?>.Binding

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.number == rhs.number && lhs.buttonSize == rhs.buttonSize
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            Button {
                session.addReading(toWeek: id)
                PlanEditorField.focusLastLine(of: session, in: focus) { [id] in $0.id == id }
            } label: {
                Label("Add Reading", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accent)
            .help("Add a line to week \(number)")
            Spacer(minLength: 0)
            Menu {
                Button("Remove Week", role: .destructive) { session.removeWeek(id) }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(minWidth: buttonSize, minHeight: buttonSize)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(Color.inkSecondary)
            .help("More for week \(number)")
            .accessibilityLabel("More for week \(number)")
        }
        .font(.callout)
    }
}

extension PlanEditorField {
    /// A field's prompt. On the phone the week's fields sit on the panel tone, so the prompt is in
    /// `ink.tertiary` there, a pairing `PaletteTests` holds; on the Mac it is the system's.
    static func prompt(_ text: String) -> Text {
        #if os(iOS)
        Text(text).foregroundStyle(Color.inkTertiary)
        #else
        Text(text)
        #endif
    }
}

extension View {
    /// The number and label fields: the system's bordered field on the Mac; on the phone a field
    /// on the panel tone, so it follows Sepia and dark.
    @ViewBuilder
    func weekField() -> some View {
        #if os(iOS)
        textFieldStyle(.plain)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.paperPanel, in: RoundedRectangle(cornerRadius: AppRadius.md))
        #else
        textFieldStyle(.roundedBorder)
        #endif
    }

    /// A row with rhythm: on the page, no separator, the editor's side margins.
    func editorRow(top: CGFloat, bottom: CGFloat = 0) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: AppSpacing.lg, bottom: bottom, trailing: AppSpacing.lg))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.paperPage)
    }
}
