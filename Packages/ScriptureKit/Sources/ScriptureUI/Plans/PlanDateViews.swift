import ScriptureData
import SwiftUI

/// A calendar day as the date picker's `Date`, in the model's calendar, its time zone and its
/// locale, so the picker shows the same day the plan stores, written as every other date is.
struct DayPicker: View {
    let title: String
    @Binding var day: PlanDay
    let calendar: Calendar
    let locale: Locale

    var body: some View {
        DatePicker(title, selection: Binding(get: { day.date(in: calendar) },
                                             set: { day = PlanDay($0, calendar: calendar) }),
                   displayedComponents: .date)
            .environment(\.calendar, calendar)
            .environment(\.timeZone, calendar.timeZone)
            .environment(\.locale, locale)
    }
}

/// Change Meeting Date…: the week's new day; later dated weeks move by the same number of days.
/// Content only: the Mac's popover and the phone's sheet each give it their own frame. Cancel and
/// Change sit under the content (the Mac's popover), or in the bar of the stack it is shown in
/// (`actionsInBar`, the phone's sheet).
public struct ChangeMeetingDateView: View {
    let week: PlanWeek
    let calendar: Calendar
    let locale: Locale
    let actionsInBar: Bool
    let onChange: (PlanDay) -> Void
    let onCancel: () -> Void
    @State private var day: PlanDay

    /// `today` is where the picker starts for a week with no date (the model's day).
    public init(week: PlanWeek, calendar: Calendar, locale: Locale, today: PlanDay, actionsInBar: Bool = false,
                onChange: @escaping (PlanDay) -> Void, onCancel: @escaping () -> Void) {
        self.week = week
        self.calendar = calendar
        self.locale = locale
        self.actionsInBar = actionsInBar
        self.onChange = onChange
        self.onCancel = onCancel
        _day = State(initialValue: week.day ?? today)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            DayPicker(title: "Week \(week.number) meets", day: $day, calendar: calendar, locale: locale)
            if let caption = Self.caption(for: week) {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !actionsInBar {
                HStack(spacing: AppSpacing.xs) {
                    Spacer(minLength: 0)
                    cancelButton
                        .keyboardShortcut(.cancelAction)
                    changeButton
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .toolbar {
            if actionsInBar {
                // The keys stay with the buttons in the bar (Esc and Return on a keyboard).
                ToolbarItem(placement: .cancellationAction) { cancelButton.keyboardShortcut(.cancelAction) }
                ToolbarItem(placement: .confirmationAction) { changeButton.keyboardShortcut(.defaultAction) }
            }
        }
    }

    /// Only a week with a date moves the later ones; setting a date that was unset moves nothing else.
    nonisolated static func caption(for week: PlanWeek) -> String? {
        week.day == nil ? nil : "Later weeks move by the same number of days."
    }

    private var cancelButton: some View {
        Button("Cancel", action: onCancel)
            .help("Keep the week's date")
    }

    private var changeButton: some View {
        Button("Change") { onChange(day) }
            .help("Move this week and the weeks after it")
    }
}

/// A plan with no dates: which week the group is on and when it next meets. Every week is then
/// seven days from its neighbor.
public struct PlanAnchorView: View {
    let weeks: [PlanWeek]
    let calendar: Calendar
    let locale: Locale
    let onSet: (_ week: Int, _ day: PlanDay) -> Void
    @State private var week: Int
    @State private var day: PlanDay

    /// `today` is where the picker starts (the model's day); `startWeek` the week it offers first
    /// (the Mac's chosen week; Week 1 on the phone).
    public init(weeks: [PlanWeek], calendar: Calendar, locale: Locale, today: PlanDay, startWeek: Int = 0,
                onSet: @escaping (_ week: Int, _ day: PlanDay) -> Void) {
        self.weeks = weeks
        self.calendar = calendar
        self.locale = locale
        self.onSet = onSet
        _week = State(initialValue: weeks.indices.contains(startWeek) ? startWeek : 0)
        _day = State(initialValue: today)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Picker("Which week is your group on?", selection: $week) {
                ForEach(weeks.indices, id: \.self) { index in
                    Text("Week \(weeks[index].number)").tag(index)
                }
            }
            .fixedSize()
            .help("The week your group is reading now")
            DayPicker(title: "When does it next meet?", day: $day, calendar: calendar, locale: locale)
                .help("The day that week meets")
            Button("Set Dates") { onSet(week, day) }
                .buttonStyle(.borderedProminent)
                .disabled(weeks.isEmpty)
                .help("Date every week from this one, seven days apart")
        }
    }
}
