import CoreGraphics
import CoreText
import Foundation
import Synchronization

/// The widest book name of a translation at a face and size (spec 4.2), measured in Core Text
/// and cached, so the front page measures once per face, size and set of names, never per redraw.
public final class BookNameMeasure: Sendable {
    public static let shared = BookNameMeasure()

    private struct Key: Hashable {
        let face: PageFace
        let size: CGFloat
        let names: [String]
    }

    private struct State {
        var widths: [Key: CGFloat] = [:]
        var passes = 0
    }

    private let state = Mutex(State())

    public init() {}

    /// The widest name's typographic width in the face at `size`, rounded up; zero for no names.
    public func widest(of names: [String], face: PageFace, size: CGFloat) -> CGFloat {
        let key = Key(face: face, size: size, names: names)
        if let width = state.withLock({ $0.widths[key] }) { return width }
        let font = face.font(size: size)
        let width = names.map { Self.width(of: $0, font: font) }.max() ?? 0
        state.withLock {
            $0.widths[key] = width
            $0.passes += 1
        }
        return width
    }

    /// Passes made over a name list (a cache hit is not one).
    var measurements: Int { state.withLock { $0.passes } }

    static func width(of name: String, font: PlatformFont) -> CGFloat {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: name, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
        return CTLineGetTypographicBounds(line, nil, nil, nil).rounded(.up)
    }
}
