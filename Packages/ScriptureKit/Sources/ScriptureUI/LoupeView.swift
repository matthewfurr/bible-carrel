import CoreText
import ScriptureModel
import SwiftUI

/// The book thumb's loupe (spec 3.3 and 4.4): while the thumb is dragged, the chapter number
/// under it, and nothing else, in a round lens over the page. The number is in the reader's
/// numeral face (its page style in its chosen face), in the accent, at a modest size (Matt: the
/// numbers "do not need to be that big"), and is not bent.
///
/// The lens is the page behind the loupe, seen through `LoupeLens`: a little soft, bent along the
/// rim, veiled with the paper under the number, inside an `ink.rule` hairline. It asks the page
/// for that picture (`PageBackdrop`, from the environment) each time it moves; the picture is
/// taken on the main actor (it is the live page), and the glass is drawn off it (`LensRenderer`),
/// the newest position only, so a fast drag never queues lenses behind the pointer. With Reduce
/// Transparency, or no page to ask, it is a plain `paper.overlay` disc.
///
/// Decorative: VoiceOver reads the thumb's own adjustable element, not the loupe. The thumb that
/// places it (`BookThumbView`) springs it in and out, or fades it under Reduce Motion.
struct LoupeView: View {
    let number: Int
    /// The reader's typography: its page style and the face the reader chose.
    let typography: ReaderTypography

    private var metrics = LoupeMetrics()
    @Environment(\.pageBackdrop) private var backdrop
    /// The page behind the loupe through its lens, where it is now.
    @State private var lens: CGImage?
    /// Where the loupe is, in the window.
    @State private var frame = CGRect.zero
    @State private var renderer = LensRenderer()

    init(number: Int, typography: ReaderTypography) {
        self.number = number
        self.typography = typography
    }

    var body: some View {
        let diameter = metrics.diameter
        Text(verbatim: "\(number)")
            .font(Font(metrics.font(for: typography)))
            .foregroundStyle(Color.accent)
            .lineLimit(1)
            .fixedSize()
            .frame(width: diameter, height: diameter)
            .background {
                if let lens, !metrics.reduceTransparency {
                    Image(decorative: lens, scale: metrics.displayScale).resizable()
                } else {
                    Color.paperOverlay
                }
            }
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.inkRule, lineWidth: 1))
            // Glass lies on the page: the one soft shadow beside the ⌘K panel's (DESIGN.md).
            .shadow(color: .black.opacity(0.14), radius: AppSpacing.xxs, x: 0, y: 2)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                frame = $0
                look(through: $0)
            }
            // A loupe shown before its page can be drawn (as the window comes up) asks again.
            .task {
                for _ in 0..<5 where lens == nil && !metrics.reduceTransparency && backdrop != nil {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    look(through: frame)
                }
            }
            .accessibilityHidden(true)
    }

    /// The page under `frame` through the lens; the plain disc when there is none to be had.
    private func look(through frame: CGRect) {
        // The page under the loupe and a margin around it, which the rim bends in.
        let margin = (frame.width * LoupeLens.margin).rounded()
        guard !metrics.reduceTransparency, frame.width > 0,
              let page = backdrop?.capture?(frame.insetBy(dx: -margin, dy: -margin), metrics.displayScale)
        else {
            lens = nil
            return
        }
        // The margin in the picture's own pixels (the Mac's picture is at the window's scale).
        let pixels = CGFloat(page.width) * margin / (frame.width + 2 * margin)
        renderer.render(LensRenderer.Job(page: page, margin: pixels, scale: pixels / max(margin, 1), paper: metrics.paper)) { image in
            lens = image
        }
    }

    /// The loupe's numeral, at `size`: the page face in lining figures, as Lectern's drop numeral
    /// and the chapter switcher's cards set a chapter's number, in every page style. (Printed and
    /// Study had taken their chapter label's SF Pro, which no longer names a chapter on the page
    /// and looked out of place over it; Matt, 2026-11-13.)
    static func numeralFont(for typography: ReaderTypography, size: CGFloat) -> CTFont {
        // A copy at the new size keeps the face's feature settings (the lining figures).
        CTFontCreateCopyWithAttributes(DropNumeral.font(for: typography) as CTFont, size, nil, nil)
    }
}

/// Draws the loupe's glass off the main actor, one lens at a time. A position asked for while a
/// lens is being drawn waits; a newer one replaces it, so the glass catches up with the pointer
/// in at most one step and never draws positions it has already left.
@MainActor
final class LensRenderer {
    struct Job: @unchecked Sendable {
        let page: CGImage
        let margin: CGFloat
        let scale: CGFloat
        let paper: LoupeLens.RGB
    }

    private var isDrawing = false
    private var waiting: (Job, (CGImage?) -> Void)?

    func render(_ job: Job, then deliver: @escaping (CGImage?) -> Void) {
        guard !isDrawing else {
            waiting = (job, deliver)
            return
        }
        isDrawing = true
        Task { @MainActor in
            let image = await Self.draw(job)
            deliver(image)
            isDrawing = false
            if let (next, nextDeliver) = waiting {
                waiting = nil
                render(next, then: nextDeliver)
            }
        }
    }

    /// Whether a lens is being drawn now (tests).
    var isBusy: Bool { isDrawing }

    @concurrent nonisolated private static func draw(_ job: Job) async -> CGImage? {
        LoupeLens.refract(job.page, margin: job.margin, scale: job.scale, paper: job.paper)
    }
}

/// What the loupe depends on from the environment: the numeral and disc sizes (`.title`'s,
/// growing with Dynamic Type), the appearance (for the paper its lens is veiled with) and the
/// display scale.
@MainActor
struct LoupeMetrics: DynamicProperty {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colorSchemeContrast) var contrast
    @Environment(\.isSepia) var isSepia
    @Environment(\.displayScale) var displayScale
    /// The numeral's size: `.title`'s.
    @ScaledMetric(relativeTo: .title) var numeralSize: CGFloat = PageFace.baseSize(.title)
    @ScaledMetric(relativeTo: .title) var diameter: CGFloat = AppSpacing.xxxl

    func font(for typography: ReaderTypography) -> CTFont {
        LoupeView.numeralFont(for: typography, size: numeralSize)
    }

    /// `paper.overlay` and `ink.primary` for the appearance, as sRGB (the lens is an image, with
    /// no environment to resolve a token in).
    var paper: LoupeLens.RGB { rgb(Palette.paperOverlay, else: (1, 1, 1)) }
    var ink: LoupeLens.RGB { rgb(Palette.inkPrimary, else: (0, 0, 0)) }

    private func rgb(_ token: ColorToken, else fallback: LoupeLens.RGB) -> LoupeLens.RGB {
        let hex = token.hex(dark: colorScheme == .dark, highContrast: contrast == .increased, sepia: isSepia)
        guard let c = ColorHex.components(hex) else { return fallback }
        return (c.red, c.green, c.blue)
    }
}

#Preview("Loupe") {
    Grid(alignment: .leading, horizontalSpacing: AppSpacing.md, verticalSpacing: AppSpacing.md) {
        ForEach(PageStyle.allCases, id: \.self) { style in
            GridRow {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(Color.inkSecondary)
                ForEach([3, 42, 119], id: \.self) { number in
                    LoupeView(number: number, typography: .styled(ReaderPreferences(style: style)))
                }
            }
        }
    }
    .padding(AppSpacing.lg)
    .background(Color.paperPage)
}
