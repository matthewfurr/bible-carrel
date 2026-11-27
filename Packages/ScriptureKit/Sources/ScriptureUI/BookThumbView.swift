import Observation
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// The book thumb (spec 3.3 and 4.4), on both devices: the whole book as a ruler's edge along the
/// reader's right edge, a tick per chapter the translation has, the chapter being read lit, and
/// while it is dragged the chapter under the finger or pointer in the loupe beside it. Letting go
/// on another chapter lands at its start (`onLand`); on the chapter being read it does nothing.
///
/// - **The ruler** (Matt, 2026-11-13: the ruler, refined; no rail, no dots): no line down it.
///   Each chapter is a 1 pt tick of `ink.tertiary` from the trailing edge, round-ended, at its
///   band's centre (`BookThumb.fraction(of:)`); every fifth chapter's is longer and in
///   `ink.secondary`, so the eye can count along it; the chapter being read's is longest, 2 pt
///   and in the `accent`. Under the pointer or finger the ticks swell toward it and fall away
///   to either side (`swell`), the one under it in `ink.primary`, so the place being chosen is
///   seen on the ruler as well as in the loupe. In Psalms the ticks are dense; the loupe carries
///   the precision.
/// - **When it shows:** `isRevealed` is the host's (the Mac: `ThumbRevealTracker`, the pointer
///   near the reader's right edge, or a landing a moment ago; the phone: its long press). It
///   also shows while dragged and while VoiceOver runs. It comes in with `fadeIn` and goes,
///   slowly, with `fadeOut`; hidden, it takes no clicks.
/// - **The drag (Mac):** a `DragGesture(minimumDistance: 0)` on the ruler sets `dragging`; each
///   chapter passed gives an alignment haptic on a Force Touch trackpad. Letting go lands only if
///   the press has left the chapter it came down on (`BookThumb.Press`), so a click alone shows
///   the loupe and lands nowhere. The pointer resting on
///   the ruler swells it too. The phone drives `dragging` from its own edge long press instead.
/// - **The loupe:** `LoupeView` in the page's numeral face, its trailing edge `loupeGap` to
///   the thumb's left (clear of the finger holding the edge, on the phone) and centred on the
///   pointer or finger, moving with it smoothly while the number changes as chapters pass (Matt,
///   2026-11-13: stepping from tick to tick felt choppy), held inside the ruler at its ends
///   (`loupeCentre`). It springs
///   in and out, and fades under Reduce Motion.
/// - **VoiceOver:** one adjustable element, labelled "Chapter" with the value "73 of 150": swipe
///   up or down moves a pending chapter (announced as the value), double-tap lands on it.
public struct BookThumbView: View {
    let thumb: BookThumb
    /// The reader's typography, for the loupe's numeral face.
    let typography: ReaderTypography
    /// Whether the host shows the ruler now (see the type's notes).
    let isRevealed: Bool
    /// The chapter under the drag, while there is one.
    @Binding var dragging: Int?
    let onLand: (Int) -> Void
    /// Where the host's own drag is on the ruler (the phone's finger, `ThumbPointer`); nil where
    /// the thumb takes the drag itself (the Mac).
    var pointer: ThumbPointer?

    /// VoiceOver's chapter, moved by its adjust gestures; nil is the chapter being read.
    @State private var pending: Int?
    /// The pointer's height on the ruler during the drag, for the loupe and the swell.
    @State private var pointerY: CGFloat?
    /// The Mac's press on the ruler: the chapter it came down on, and whether it has left it.
    @State private var press: BookThumb.Press?
    /// The pointer's height while it rests on the ruler without dragging (the Mac), for the swell.
    @State private var hoverY: CGFloat?
    @State private var trackHeight: CGFloat = 0
    /// The loupe's own sizes, for placing it.
    private var metrics = LoupeMetrics()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    public init(thumb: BookThumb, typography: ReaderTypography, isRevealed: Bool, dragging: Binding<Int?>,
                pointer: ThumbPointer? = nil, onLand: @escaping (Int) -> Void) {
        self.pointer = pointer
        self.thumb = thumb
        self.typography = typography
        self.isRevealed = isRevealed
        self._dragging = dragging
        self.onLand = onLand
    }

    // MARK: - Geometry

    /// The ruler coming in: quick, so it is there by the time the pointer reaches it.
    nonisolated static let fadeIn = Animation.snappy(duration: 0.2)
    /// The ruler going: slow enough to be watched leaving (Matt, 2026-11-13: it went too fast).
    nonisolated static let fadeOut = Animation.smooth(duration: 0.9)

    /// How near the reader's right edge the pointer brings the ruler out, in points.
    nonisolated static let revealEdge: CGFloat = 40
    /// The thumb's width: its longest tick at full swell, and (the Mac) the area a drag starts in.
    #if os(iOS)
    nonisolated static let width: CGFloat = AppSpacing.xxl
    #else
    nonisolated static let width: CGFloat = AppSpacing.lg
    #endif
    /// A chapter's tick, from the trailing edge; every fifth chapter's; the chapter being read's.
    nonisolated static let tickLength: CGFloat = AppSpacing.xxs + 2
    nonisolated static let fifthTickLength: CGFloat = AppSpacing.xs + 2
    nonisolated static let currentTickLength: CGFloat = AppSpacing.md
    /// How much longer the tick under the pointer grows, and how far to either side the swell
    /// reaches before it has fallen away.
    /// On the phone the finger lies over the edge, so the swell is long enough to stand out from
    /// under it and reaches further (Matt, 2026-11-13: "you can't even tell").
    #if os(iOS)
    nonisolated static let swell: CGFloat = AppSpacing.xl
    nonisolated static let swellReach: CGFloat = AppSpacing.xxxl
    #else
    nonisolated static let swell: CGFloat = AppSpacing.xs
    nonisolated static let swellReach: CGFloat = AppSpacing.xl
    #endif
    /// The loupe's gap to the ruler's left. On the phone the finger holds the edge, so the loupe
    /// stands clear of it.
    #if os(iOS)
    nonisolated static let loupeGap: CGFloat = AppSpacing.lg
    #else
    nonisolated static let loupeGap: CGFloat = AppSpacing.sm
    #endif
    /// The thumb's own coordinate space, which the loupe is placed in.
    nonisolated static let space = "BookThumb"

    /// Where the loupe's centre sits in the thumb's own frame (its top leading corner the
    /// origin), for a pointer or tick at height `y` on a ruler `trackHeight` tall: its trailing
    /// edge `gap` to the left of the thumb, its centre at `y`, held inside the ruler at either
    /// end so it never runs under the bars. A ruler shorter than the loupe centres it.
    nonisolated static func loupeCentre(y: CGFloat, trackHeight: CGFloat, diameter: CGFloat, gap: CGFloat) -> CGPoint {
        let radius = diameter / 2
        let heldY = trackHeight >= diameter ? min(max(y, radius), trackHeight - radius) : trackHeight / 2
        return CGPoint(x: -gap - radius, y: heldY)
    }

    /// A tick's length at height `y`: its own (`resting`), and the swell toward a pointer at
    /// `pointer`, full under it and eased away to nothing `swellReach` to either side.
    nonisolated static func tickLength(resting: CGFloat, y: CGFloat, pointer: CGFloat?) -> CGFloat {
        guard let pointer else { return resting }
        let distance = abs(y - pointer) / swellReach
        guard distance < 1 else { return resting }
        return resting + swell * (1 + cos(.pi * distance)) / 2
    }

    /// A chapter's resting tick: every fifth chapter's is longer.
    nonisolated static func restingTickLength(for chapter: Int) -> CGFloat {
        chapter.isMultiple(of: 5) ? fifthTickLength : tickLength
    }

    /// The chapter at height `y` on a track `height` tall: that fraction of the book. A track not
    /// yet laid out reads as the chapter being read.
    nonisolated static func chapter(forY y: CGFloat, inTrackHeight height: CGFloat, thumb: BookThumb) -> Int {
        guard height > 0 else { return thumb.current }
        return thumb.chapter(atFraction: Double(y / height))
    }

    /// Where `chapter`'s tick sits on a track `height` tall: its band's centre.
    nonisolated static func tickY(for chapter: Int, inTrackHeight height: CGFloat, thumb: BookThumb) -> CGFloat {
        CGFloat(thumb.fraction(of: chapter)) * height
    }

    /// Whether a pointer at `x` in a reader `width` wide is near enough its right edge to show
    /// the track.
    nonisolated static func isNearEdge(x: CGFloat, width: CGFloat) -> Bool {
        x <= width && width - x <= revealEdge
    }

    // MARK: - VoiceOver

    /// The element's name; its value carries the chapter, so VoiceOver reads "Chapter, 73 of 150"
    /// and announces the new value on each adjust.
    nonisolated static let accessibilityLabel = "Chapter"

    /// "73 of 150": the book's last chapter is its extent, though the translation lack one.
    nonisolated static func accessibilityValue(for chapter: Int, thumb: BookThumb) -> String {
        "\(chapter) of \(thumb.chapters.last ?? chapter)"
    }

    /// The chapter `step` places on from `chapter` among those the translation has, held at
    /// either end.
    nonisolated static func adjusted(_ chapter: Int, by step: Int, thumb: BookThumb) -> Int {
        guard let index = thumb.chapters.firstIndex(where: { $0 >= chapter }) ?? thumb.chapters.indices.last
        else { return chapter }
        return thumb.chapters[min(max(index + step, 0), thumb.chapters.count - 1)]
    }

    // MARK: - Body

    public var body: some View {
        let shown = isRevealed || dragging != nil || voiceOverEnabled
        let spoken = pending ?? thumb.current
        track
            .frame(width: Self.width)
            .frame(maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { trackHeight = $0 }
            .opacity(shown ? 1 : 0)
            .animation(shown ? Self.fadeIn : Self.fadeOut, value: shown)
            .contentShape(Rectangle())
            #if os(macOS)
            .allowsHitTesting(shown)
            .gesture(drag)
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): hoverY = point.y
                case .ended: hoverY = nil
                }
            }
            #else
            // The phone's edge long press drives the drag; the track never takes a touch, so a
            // margin mark under it still gets its tap.
            .allowsHitTesting(false)
            #endif
            // The loupe is placed in the thumb's own frame (`loupeCentre`), outside its bounds.
            .overlay { loupe }
            .coordinateSpace(.named(Self.space))
            .animation(loupeAnimation, value: dragging == nil)
            .accessibilityElement()
            .accessibilityLabel(Self.accessibilityLabel)
            .accessibilityValue(Self.accessibilityValue(for: spoken, thumb: thumb))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: pending = Self.adjusted(spoken, by: 1, thumb: thumb)
                case .decrement: pending = Self.adjusted(spoken, by: -1, thumb: thumb)
                @unknown default: break
                }
            }
            .accessibilityAction {
                if thumb.landing(on: spoken) != nil { onLand(spoken) }
            }
            // A new chapter open: VoiceOver starts again from it.
            .onChange(of: thumb.current) { _, _ in pending = nil }
    }

    /// The ruler: each chapter's tick from the trailing edge, swelling toward the pointer (the
    /// drag's, the host's dragged chapter's tick, or the pointer resting on it).
    private var track: some View {
        let pointer = pointerY ?? self.pointer?.y ?? dragging.map { Self.tickY(for: $0, inTrackHeight: trackHeight, thumb: thumb) } ?? hoverY
        return Canvas { context, size in
            func tick(at y: CGFloat, length: CGFloat, thickness: CGFloat, color: Color) {
                let rect = CGRect(x: size.width - length, y: y - thickness / 2, width: length, height: thickness)
                context.fill(Path(roundedRect: rect, cornerRadius: thickness / 2), with: .color(color))
            }
            for chapter in thumb.chapters where chapter != thumb.current {
                let y = Self.tickY(for: chapter, inTrackHeight: size.height, thumb: thumb)
                let length = Self.tickLength(resting: Self.restingTickLength(for: chapter), y: y, pointer: pointer)
                let color: Color = chapter == dragging ? .inkPrimary : chapter.isMultiple(of: 5) ? .inkSecondary : .inkTertiary
                tick(at: y, length: length, thickness: 1, color: color)
            }
            let y = Self.tickY(for: thumb.current, inTrackHeight: size.height, thumb: thumb)
            tick(at: y, length: Self.tickLength(resting: Self.currentTickLength, y: y, pointer: pointer), thickness: 2, color: .accent)
        }
    }

    /// The loupe beside the track, centred on the pointer, or on the dragged chapter's tick when
    /// the host moves `dragging` itself (then it glides from tick to tick). It grows out of its
    /// own trailing edge, beside the track.
    @ViewBuilder
    private var loupe: some View {
        if let number = dragging {
            let diameter = metrics.diameter
            // With the pointer or finger, smoothly; with neither (VoiceOver), on the chapter's tick.
            let followed = pointerY ?? pointer?.y
            let y = followed ?? Self.tickY(for: number, inTrackHeight: trackHeight, thumb: thumb)
            let centre = Self.loupeCentre(y: y, trackHeight: trackHeight, diameter: diameter, gap: Self.loupeGap)
            // The loupe's trailing edge, as a point of the thumb's frame (`.position` fills it).
            let anchor = UnitPoint(x: (centre.x + diameter / 2) / Self.width, y: centre.y / max(trackHeight, 1))
            LoupeView(number: number, typography: typography)
                #if DEBUG
                .modifier(LoupeFrameProbe())
                #endif
                .position(centre)
                .animation(followed == nil && !reduceMotion ? .snappy(duration: 0.12) : nil, value: centre.y)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.5, anchor: anchor).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    /// The loupe springs in and out; under Reduce Motion it fades.
    private var loupeAnimation: Animation {
        reduceMotion ? .snappy(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.7)
    }

    #if os(macOS)
    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                pointerY = min(max(value.location.y, 0), trackHeight)
                let chapter = Self.chapter(forY: value.location.y, inTrackHeight: trackHeight, thumb: thumb)
                if press == nil { press = BookThumb.Press(start: chapter) } else { press?.moved(to: chapter) }
                guard chapter != dragging else { return }
                if dragging != nil {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
                dragging = chapter
            }
            .onEnded { _ in
                let chapter = dragging
                let chose = chapter.map { press?.chooses(releasingOn: $0) ?? false } ?? false
                dragging = nil
                pointerY = nil
                press = nil
                if let chapter, chose, thumb.landing(on: chapter) != nil { onLand(chapter) }
            }
    }
    #endif
}

/// Where the phone's finger is on the ruler during its press, in the thumb's own coordinates;
/// nil between presses. Read only by the thumb, so a press's every move redraws the thumb and
/// never the screen.
@MainActor @Observable public final class ThumbPointer {
    public var y: CGFloat?

    public init() {}
}

#if DEBUG
extension EnvironmentValues {
    /// Tests only: hears the loupe's frame in the thumb's own coordinate space (`BookThumbView.space`).
    @Entry var loupeFrameProbe: (@MainActor (CGRect) -> Void)?
}

/// Reports the loupe's frame to `loupeFrameProbe`, when a test has set one.
private struct LoupeFrameProbe: ViewModifier {
    @Environment(\.loupeFrameProbe) private var probe

    func body(content: Content) -> some View {
        if let probe {
            content.onGeometryChange(for: CGRect.self) { $0.frame(in: .named(BookThumbView.space)) } action: { probe($0) }
        } else {
            content
        }
    }
}
#endif

#Preview("Book thumb") {
    @Previewable @State var dragging: Int? = 76
    HStack {
        Spacer()
        BookThumbView(thumb: BookThumb(chapters: Array(1...150), current: 73),
                      typography: .styled(ReaderPreferences(style: .lectern)),
                      isRevealed: true, dragging: $dragging, onLand: { _ in })
    }
    .frame(width: 320, height: 480)
    .padding(.vertical, AppSpacing.lg)
    .background(Color.paperPage)
}
