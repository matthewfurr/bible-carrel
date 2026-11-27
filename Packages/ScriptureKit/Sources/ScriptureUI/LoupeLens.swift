import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// Where the book thumb's loupe gets the page behind it. The reader's text controller sets
/// `capture` (it owns the page's view); the loupe calls it with its own frame.
@MainActor public final class PageBackdrop {
    /// A picture of the page under `frame` (SwiftUI's global coordinates: the window's content,
    /// from its top leading corner), at `scale` pixels a point, without the thumb or the loupe.
    /// Nil when the page cannot be drawn.
    public var capture: ((_ frame: CGRect, _ scale: CGFloat) -> CGImage?)?

    public init() {}
}

extension EnvironmentValues {
    /// The page behind the book thumb, for its loupe (`PageBackdrop`); nil, and the loupe is a
    /// plain disc.
    @Entry public var pageBackdrop: PageBackdrop?
}

/// The loupe's glass (Matt, 2026-11-13: "I want clear Liquid Glass ... there will need to be some
/// blurring, but not to that extent"): a disc of clear glass lying on the page.
///
/// - **Clear through the middle.** The page shows through as it is, the same size, barely
///   softened and under the thinnest veil of the paper, so the words behind stay words and the
///   number (which the loupe draws over the lens, unbent) still reads.
/// - **Bent at the rim.** Where the glass curves down to its edge it bends the light: from
///   `flat` of the radius outward the page is drawn in more and more, until at the rim what lies
///   beyond the loupe is squeezed against the edge, and red and blue part slightly. The bend
///   grows from nothing with no step in it or its slope (`bend(at:)`), so no line shows where it
///   begins.
/// - **Lit.** A thin line of light runs round the inside of the rim, brightest toward the top
///   leading side and again opposite, as the edge of clear glass catches it. Its upper part
///   carries a pale reflection, as a lens under a lamp does.
/// - **Quieter behind the number.** Only at the middle, where the number sits, the words behind
///   are lighter (a soft pool of the paper's light) and a little more blurred, both fading out
///   well inside where the glass begins to curve, so the number reads over text and the rim is
///   as it was (Matt, 2026-11-13).
///
/// The app draws it (Core Image), rather than asking the system for glass: at this size the
/// system's clear glass smeared the page to a flat tint on the phone, and showed nothing of the
/// page on the Mac. So it looks the same on both. The bend is a small Metal warp kernel (it was
/// Core Image's deprecated kernel language until the Metal toolchain was installed, 2026-11-16).
///
/// Turned down on the way here: a lens that bent only a ring (its inner edge showed), one that
/// only blurred, and a raindrop that magnified and blurred too much to read as glass.
public enum LoupeLens {
    // Calls; tune on a device.
    /// How soft the page is behind the glass, in points (a Gaussian's sigma).
    public static let blur: CGFloat = 0.8
    /// How much of the paper is laid over the page behind the number (0 none, 1 opaque).
    public static let veil: CGFloat = 0.15
    /// Where the glass begins to curve, as a part of the radius: flat and clear inside it.
    public static let flat: CGFloat = 0.58
    /// How far beyond the rim the glass reaches for what it bends into its edge, as a part of
    /// the radius; and how far red and blue part from green there, as a part of that.
    public static let reach: CGFloat = 0.5
    public static let fringe: CGFloat = 0.07
    /// The page the lens needs around the loupe, to bend into its rim: this much of the loupe's
    /// diameter on every side.
    public static let margin: CGFloat = 0.3
    /// The line of light inside the rim: how wide, in points, and how bright all the way round
    /// and where it catches the light (shares of full white).
    public static let edgeWidth: CGFloat = 1.5
    public static let edgeLight: CGFloat = 0.45
    public static let highlight: CGFloat = 0.85
    /// The pool of light behind the number: how much of the paper's own light at the centre
    /// (it fades to nothing by `poolReach` of the radius), so the number stands clear of words
    /// behind it.
    public static let pool: CGFloat = 0.64
    public static let poolReach: CGFloat = 0.62
    /// How soft the page is right behind the number, in points: more than elsewhere, fading to
    /// the glass's own `blur` by `poolReach`.
    public static let centreBlur: CGFloat = 2.2
    /// The reflection across the glass's upper part, at its brightest (a share of full white).
    public static let reflection: CGFloat = 0.26

    /// How much of its reach the glass bends by at `radius` (0 the centre, 1 the rim): nothing
    /// across the flat middle, then rising with no step in it or in its slope to all of it at
    /// the rim. The warp kernel computes the same curve.
    public static func bend(at radius: CGFloat) -> CGFloat {
        let t = min(max((radius - flat) / (1 - flat), 0), 1)
        return t * t * t * (3 - 2 * t)
    }

    /// The bend, a Metal warp kernel (`KernelSources/LoupeWarp.ci.metal`, built for each
    /// platform by `Scripts/build-kernels.sh`): each place in the lens looks outward along the
    /// line from the centre by `reach` radii times `bend(at:)`. Nil only if its library is
    /// missing, and then the glass is flat.
    static let warp: CIWarpKernel? = {
        guard let url = warpLibrary, let data = try? Data(contentsOf: url) else { return nil }
        return try? CIWarpKernel(functionName: "glassRim", fromMetalLibraryData: data)
    }()

    /// The kernel's library for this platform, in ScriptureUI's resources.
    static var warpLibrary: URL? {
        #if os(macOS)
        let platform = "macos"
        #elseif targetEnvironment(simulator)
        let platform = "iossimulator"
        #else
        let platform = "ios"
        #endif
        return Bundle.module.resourceURL?.appendingPathComponent("Kernels/LoupeWarp-\(platform).metallib")
    }

    /// No colour management: the veil's share and the blur are worked in the page's own (display)
    /// values, so `veil` is the share of paper the eye sees.
    private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])

    public typealias RGB = (red: CGFloat, green: CGFloat, blue: CGFloat)

    /// The glass over `backdrop`: the square of page under the loupe with `margin` pixels more of
    /// it on every side, `scale` pixels a point. The loupe's own square comes back (`backdrop`
    /// less its margin), veiled with `paper` (sRGB).
    public static func refract(_ backdrop: CGImage, margin: CGFloat, scale: CGFloat, paper: RGB) -> CGImage? {
        let page = CIImage(cgImage: backdrop)
        let extent = page.extent
        let lens = extent.insetBy(dx: margin, dy: margin).integral
        guard lens.width > 2, lens.height > 2 else { return nil }
        // Laid on the paper and trimmed by a pixel before its edge is carried outward: a picture
        // whose edge pixels are only part covered would otherwise smear dark into the rim.
        let ground = CIImage(color: CIColor(red: paper.red, green: paper.green, blue: paper.blue)).cropped(to: extent)
        let whole = page.composited(over: ground).cropped(to: extent.insetBy(dx: 1, dy: 1))
        let soft = whole.clampedToExtent().applyingGaussianBlur(sigma: blur * scale)

        let radius = min(lens.width, lens.height) / 2
        let centre = CGPoint(x: lens.midX, y: lens.midY)
        func bent(_ share: CGFloat) -> CIImage {
            let far = reach * share * radius
            return warp?.apply(extent: lens, roiCallback: { _, rect in rect.insetBy(dx: -far - 1, dy: -far - 1) }, image: soft,
                               arguments: [CIVector(cgPoint: centre), radius, flat, reach * share])?.cropped(to: lens)
                ?? soft.cropped(to: lens)
        }
        // Each colour through its own bend, put back together: they part only where the rim bends.
        let fringed = channel(bent(1 - fringe), CIVector(x: 1, y: 0, z: 0, w: 0), \.rVector)
            .applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: channel(bent(1), CIVector(x: 0, y: 1, z: 0, w: 0), \.gVector)])
            .applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: channel(bent(1 + fringe), CIVector(x: 0, y: 0, z: 1, w: 0), \.bVector)])
        let wash = CIImage(color: CIColor(red: paper.red, green: paper.green, blue: paper.blue, alpha: veil)).cropped(to: lens)

        // The edge's light. Core Image's y runs up: the top leading side is up and to the left.
        func white(_ strength: CGFloat) -> CIColor { CIColor(red: 1, green: 1, blue: 1, alpha: strength) }
        func radial(at point: CGPoint, from inner: CGFloat, to outer: CGFloat, _ first: CIColor, _ second: CIColor) -> CIImage {
            let gradient = CIFilter.radialGradient()
            gradient.center = point
            gradient.radius0 = Float(inner)
            gradient.radius1 = Float(outer)
            gradient.color0 = first
            gradient.color1 = second
            return (gradient.outputImage ?? CIImage.empty()).cropped(to: lens)
        }
        let width = edgeWidth * scale
        // A line of light just inside the rim, all the way round...
        let edge = radial(at: centre, from: radius - width, to: radius, white(0), white(edgeLight))
        // ...and brighter where the edge catches the light: the same line, shown only near the
        // top leading side and opposite it.
        let line = radial(at: centre, from: radius - width * 1.6, to: radius, white(0), white(highlight))
        func near(_ dx: CGFloat, _ dy: CGFloat) -> CIImage {
            radial(at: CGPoint(x: centre.x + dx * radius, y: centre.y + dy * radius), from: radius * 0.15, to: radius * 0.85, white(1), white(0))
        }
        let where_ = near(-0.72, 0.72).composited(over: near(0.72, -0.72))
        let caught = line.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: where_])
        // The pool of light at the middle, in the paper's own colour, and the lamp's reflection
        // across the upper part: brightest at the top, gone a little above the middle.
        let gathered = radial(at: centre, from: radius * 0.12, to: radius * poolReach,
                              CIColor(red: paper.red, green: paper.green, blue: paper.blue, alpha: pool),
                              CIColor(red: paper.red, green: paper.green, blue: paper.blue, alpha: 0))
        let reflected = radial(at: CGPoint(x: centre.x, y: centre.y + radius * 1.7), from: radius * 0.8, to: radius * 1.55,
                               white(reflection), white(0))
        // Right behind the number the page is softer too: the more blurred page, shown only at
        // the middle and fading out with the pool.
        let softer = whole.clampedToExtent().applyingGaussianBlur(sigma: centreBlur * scale).cropped(to: lens)
        let middle = radial(at: centre, from: radius * 0.12, to: radius * poolReach, white(1), white(0))
        let quietened = softer.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: fringed, kCIInputMaskImageKey: middle])
        let lit = reflected.composited(over: gathered.composited(over: wash.composited(over: quietened)))
        let glass = caught.composited(over: edge.composited(over: lit))
        return context.createCGImage(glass, from: lens)
    }

    /// One colour of `image`, the other two zero, its alpha kept.
    private static func channel(_ image: CIImage, _ vector: CIVector, _ slot: ReferenceWritableKeyPath<CIColorMatrix, CIVector>) -> CIImage {
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        matrix.rVector = zero
        matrix.gVector = zero
        matrix.bVector = zero
        matrix[keyPath: slot] = vector
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return matrix.outputImage ?? image
    }
}
