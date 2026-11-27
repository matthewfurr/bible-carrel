import Foundation

/// What the Plan tab's `ellipsis` menu offers, in order.
public enum PhonePlanMenu {
    public enum Item: Hashable, Sendable { case plans, importFile, newPlan, editPlan, changeMeetingDate, deletePlan }

    /// The plans (when there is one), Import…, New Plan, Edit Plan… (a readable plan), Change
    /// Meeting Date… (while there is a this week) and Delete Plan… (a plan).
    public static func items(planCount: Int, followedIsReadable: Bool, hasThisWeek: Bool) -> [Item] {
        var items: [Item] = []
        if planCount > 0 { items.append(.plans) }
        items += [.importFile, .newPlan]
        if followedIsReadable { items.append(.editPlan) }
        if hasThisWeek { items.append(.changeMeetingDate) }
        if planCount > 0 { items.append(.deletePlan) }
        return items
    }

    /// The title of an item; `.plans` is a picker and has none of its own.
    public static func title(_ item: Item) -> String {
        switch item {
        case .plans: "Plan"
        case .importFile: "Import…"
        case .newPlan: "New Plan"
        case .editPlan: "Edit Plan…"
        case .changeMeetingDate: "Change Meeting Date…"
        case .deletePlan: "Delete Plan…"
        }
    }
}
