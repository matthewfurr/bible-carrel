import SwiftUI

/// A one-point rule in `ink.rule`: under a Testament's title, closing the "This week" band, and
/// (vertical) the front page's pane divider. A shape is not an accessibility element, so it needs no hiding.
struct HairlineRule: View {
    enum Axis { case horizontal, vertical }

    static let thickness: CGFloat = 1
    private let axis: Axis

    init(_ axis: Axis = .horizontal) {
        self.axis = axis
    }

    var body: some View {
        Rectangle()
            .fill(Color.inkRule)
            .frame(width: axis == .vertical ? Self.thickness : nil, height: axis == .horizontal ? Self.thickness : nil)
    }
}
