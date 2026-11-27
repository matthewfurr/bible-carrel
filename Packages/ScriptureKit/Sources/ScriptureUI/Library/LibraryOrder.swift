import SwiftUI

/// The order of the People list (spec 7), kept on this device only: never in `SyncedPreferences`,
/// the store or the export.
public enum PeopleOrder: String, CaseIterable, Sendable {
    case mostNamed, alphabetical

    public static let key = "libraryPeopleOrder"

    public var title: String {
        switch self {
        case .mostNamed: "Most named"
        case .alphabetical: "A to Z"
        }
    }
}

/// The order of the Places list (project 4, spec 5), kept on this device only under its own key, never in
/// `SyncedPreferences`, the store or the export.
public enum PlacesOrder: String, CaseIterable, Sendable {
    case mostNamed, alphabetical, byChapter

    public static let key = "libraryPlacesOrder"

    public var title: String {
        switch self {
        case .mostNamed: "Most named"
        case .alphabetical: "A to Z"
        case .byChapter: "By chapter"
        }
    }
}

/// A to Z (People's spec 7, Places' spec 5.3): by name in the reader's language order, then the data's label
/// (none first), then id. One comparator for both lists (pre-flight ruling 8b).
enum LibraryNameOrder {
    static func precedes(_ a: (name: String, label: String?, id: Int), _ b: (name: String, label: String?, id: Int)) -> Bool {
        let byName = a.name.localizedStandardCompare(b.name)
        if byName != .orderedSame { return byName == .orderedAscending }
        switch (a.label, b.label) {
        case (nil, .some): return true
        case (.some, nil): return false
        case (let x?, let y?):
            let byLabel = x.localizedStandardCompare(y)
            if byLabel != .orderedSame { return byLabel == .orderedAscending }
        case (nil, nil): break
        }
        return a.id < b.id
    }
}

/// Whether Places' order control is its three segments or a menu of the same choices, by a measured width as
/// the Notes window's filter is (`NotesBrowserView.filterIsSegmented`), not by `ViewThatFits`.
///
/// `segmentedWidth` is the control's own minimum width: the system segmented `Picker` with "Most named",
/// "A to Z" and "By chapter" laid out at the least (segments sized to their labels), measured 2026-11-23 by
/// `sizeThatFits` of a hosting controller at a 1 pt proposal on the Mac (`.small`: 210; ideally 249; People's two
/// segments are 134) and by `systemLayoutSizeFitting` on the iPhone (285 at every text size, the control's text
/// does not scale). Places' Mac column is a scaled 232 pt so its inside (216) holds the Mac's 210. The phone's
/// sheet is 402 pt, 354 inside; at an accessibility size it is a menu whatever its width (the labels would not fit).
enum PlacesOrderControl {
    #if os(macOS)
    static let segmentedWidth: CGFloat = 210
    #else
    static let segmentedWidth: CGFloat = 285
    #endif

    static func isSegmented(width: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Bool {
        #if os(iOS)
        if dynamicTypeSize.isAccessibilitySize { return false }
        #endif
        return width >= segmentedWidth
    }
}

/// A Library list's order control: the system segmented `Picker` labelled "Order", or, with `asMenu`, a menu of
/// the same choices. Generic over its orders so Places can add a third segment from the view that holds it.
struct LibraryOrderPicker<Order: Hashable>: View {
    @Binding var selection: Order
    let orders: [Order]
    let title: (Order) -> String
    let asMenu: Bool

    init(selection: Binding<Order>, orders: [Order], title: @escaping (Order) -> String, asMenu: Bool = false) {
        _selection = selection
        self.orders = orders
        self.title = title
        self.asMenu = asMenu
    }

    var body: some View {
        if asMenu {
            picker.pickerStyle(.menu).labelsHidden().controlSizeForMac().tint(Color.accent).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            picker.pickerStyle(.segmented).labelsHidden().controlSizeForMac()
        }
    }

    private var picker: some View {
        Picker("Order", selection: $selection) {
            ForEach(orders, id: \.self) { order in
                Text(title(order)).tag(order)
            }
        }
    }
}

private extension View {
    @ViewBuilder func controlSizeForMac() -> some View {
        #if os(macOS)
        controlSize(.small)
        #else
        self
        #endif
    }
}
