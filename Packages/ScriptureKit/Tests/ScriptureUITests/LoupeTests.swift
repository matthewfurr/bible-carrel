import CoreGraphics
import CoreText
import ScriptureModel
import Testing
@testable import ScriptureUI
#if os(macOS)
import AppKit
// Only what the hosted test needs: SwiftUI's own `ScrollTarget` would shadow the reader's.
import class SwiftUI.NSHostingView
import protocol SwiftUI.View
#endif

/// The book thumb's loupe: its numeral face, where it sits, and the lens it looks at the page
/// through (`LoupeLens`).
@MainActor @Suite struct LoupeTests {
    private func family(_ font: CTFont) -> String { CTFontCopyFamilyName(font) as String }

    /// The numeral is in the page face's lining figures, as a drop numeral and the switcher's
    /// cards are, in every page style, at the size asked (Matt, 2026-11-13: Printed's SF Pro
    /// "didn't look right").
    @Test func theLoupeSetsTheNumberInThePageFace() {
        for style in PageStyle.allCases {
            let typography = ReaderTypography.styled(ReaderPreferences(style: style))
            let font = LoupeView.numeralFont(for: typography, size: 28)
            #expect(family(font) == family(DropNumeral.font(for: typography) as CTFont), "\(style)")
            #expect(family(font) == family(typography.bodyFont as CTFont), "\(style): the page's own face")
            #expect(CTFontGetSize(font) == 28, "\(style)")
        }
    }

    /// The face the reader picked, not the style's own: Study set in Literata.
    @Test func theLoupeFollowsTheReadersChosenFace() {
        let chosen = ReaderTypography.styled(ReaderPreferences(style: .study, face: .literata))
        let own = ReaderTypography.styled(ReaderPreferences(style: .study))
        #expect(family(LoupeView.numeralFont(for: chosen, size: 28)) != family(LoupeView.numeralFont(for: own, size: 28)))
    }

    // MARK: The lens

    /// A page 192 pixels square (the loupe's 128 and 32 of margin on every side): `ink` (0 black
    /// to 1 white) everywhere, with a black line 4 pixels wide down `lineX` when given.
    private func page(ink: CGFloat, lineX: Int? = nil) throws -> CGImage {
        let side = 192
        let context = try #require(CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(srgbRed: ink, green: ink, blue: ink, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        if let lineX {
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: lineX - 2, y: 0, width: 4, height: side))
        }
        return try #require(context.makeImage())
    }

    /// The lens over `page`, veiled in white: on a white page the edge's own light does not
    /// show, so only the bend moves what is seen.
    private func lens(_ page: CGImage) throws -> CGImage {
        try #require(LoupeLens.refract(page, margin: 32, scale: 2, paper: (1, 1, 1)))
    }

    /// The red, green and blue of `image`'s pixel at (`x`, `y`) from its top left, 0 to 255.
    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [Int] {
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return bytes.prefix(3).map(Int.init)
    }

    /// Where a dark line shows along the lens's middle height: the middle of its darkness (a line
    /// seen through the drop is wide and soft, so its darkest pixel is no one place).
    private func darkest(_ image: CGImage) throws -> Int {
        var weight = 0.0, moment = 0.0
        for x in 0..<image.width {
            let dark = Double(255 - (try pixel(image, x: x, y: image.height / 2)[1]))
            weight += dark
            moment += dark * Double(x)
        }
        return weight > 0 ? Int((moment / weight).rounded()) : -1
    }

    /// Matt, 2026-11-13: "I want clear Liquid Glass". Through its middle the glass is clear: the
    /// loupe's own square of the page comes back (its margin gone) under only the thinnest veil
    /// (black page under white paper comes out hardly a sixth of the way to white), and a line 12
    /// pixels from the centre shows 12 pixels from the centre, not enlarged or moved.
    @Test func theGlassIsClearThroughItsMiddle() throws {
        #expect(LoupeLens.veil == 0.15 && LoupeLens.blur <= 0.8)
        let dark = try lens(try page(ink: 0))
        #expect(dark.width == 128 && dark.height == 128)
        // Between the pool of light at the middle and the rim, only the veil lies over the page.
        let clear = try pixel(dark, x: 64 + 44, y: 64 + 10)
        let expected = Int((LoupeLens.veil * 255).rounded())
        #expect(clear.allSatisfy { abs($0 - expected) <= 8 }, "\(clear) against \(expected)")
        #expect(abs(try darkest(try lens(try page(ink: 1, lineX: 96))) - 64) <= 1, "the line through the centre stays put")
        #expect(abs(try darkest(try lens(try page(ink: 1, lineX: 96 + 12))) - 76) <= 1, "and so does one 12 from it")
        #expect(abs(try darkest(try lens(try page(ink: 1, lineX: 96 + 30))) - 94) <= 1, "and one 30 from it, still inside the flat")
    }

    /// The bend grows from nothing with no step (Matt: "you can see division in the loupe" of a
    /// lens that bent only a ring): flat to where the glass begins to curve, hardly any just
    /// past there, and no jump between one place and the next.
    /// The bend is a Metal kernel now, one library per platform (Matt approved the toolchain,
    /// 2026-11-16); without it the glass would be flat and the bending tests below would fail.
    @Test func theBendIsTheMetalKernel() {
        #expect(LoupeLens.warp != nil)
    }

    /// The glass is drawn off the main actor, the newest position only: three positions asked
    /// for while the first is drawing give the first and the last, never the middle one.
    @Test func theLensRendererDrawsOnlyTheNewestWaitingPosition() async throws {
        let renderer = LensRenderer()
        var delivered: [Int] = []
        for index in 0..<3 {
            let image = try page(ink: 0)
            renderer.render(LensRenderer.Job(page: image, margin: 32, scale: 2, paper: (1, 1, 1))) { lens in
                if lens != nil { delivered.append(index) }
            }
        }
        #expect(renderer.isBusy)
        for _ in 0..<200 where renderer.isBusy || delivered.count < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(delivered == [0, 2])
    }

    @Test func theGlassBendsWithNoStep() {
        #expect(LoupeLens.bend(at: 0) == 0 && LoupeLens.bend(at: LoupeLens.flat) == 0)
        #expect(LoupeLens.bend(at: 1) == 1 && LoupeLens.bend(at: 1.4) == 1)
        #expect(LoupeLens.bend(at: LoupeLens.flat + 0.04) < 0.01)
        var last: CGFloat = 0
        for step in 0...200 {
            let now = LoupeLens.bend(at: CGFloat(step) / 200)
            #expect(now >= last && now - last < 0.03, "at \(step): \(last) to \(now)")
            last = now
        }
    }

    /// At its rim the glass bends the page in: a line lying just outside the loupe shows inside
    /// it, and a line under the curve shows nearer the middle than it lies; a line's place moves
    /// smoothly outward as the line does, never jumping.
    @Test func theGlassBendsThePageInAtItsRim() throws {
        // 6 pixels outside the loupe's right edge (the loupe is 32..<160 of the page).
        let outside = try darkest(try lens(try page(ink: 1, lineX: 166)))
        #expect((96..<128).contains(outside), "a line beyond the rim is bent into it, at \(outside)")
        let under = try darkest(try lens(try page(ink: 1, lineX: 96 + 58)))
        #expect(under < 64 + 56 && under > 64 + 30, "drawn in from 122 to \(under)")
        var last = -1
        for offset in stride(from: 0, through: 72, by: 4) {
            let shown = try darkest(try lens(try page(ink: 1, lineX: 96 + offset))) - 64
            #expect(shown >= last && shown - last <= 5, "a line \(offset) out shows at \(shown), after \(last)")
            last = shown
        }
    }

    /// The glass is round: a line across the page just above the loupe is bent into its top, as
    /// one beside it is bent into its side.
    @Test func theGlassBendsTheSameAllTheWayRound() throws {
        let side = 192
        let context = try #require(CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        // 6 pixels above the loupe's top edge (Core Graphics counts up from the bottom).
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 164, width: side, height: 4))
        let lens = try lens(try #require(context.makeImage()))
        var weight = 0.0, moment = 0.0
        for y in 0..<128 {
            let dark = Double(255 - (try pixel(lens, x: 64, y: y)[1]))
            weight += dark
            moment += dark * Double(y)
        }
        let shown = Int((moment / weight).rounded())
        #expect((0..<32).contains(shown), "a line above the rim is bent into the top of the lens, at \(shown)")
    }

    /// Matt, 2026-11-13: more light, so the number reads when words lie right behind it. Over a
    /// black page the glass's middle, where the number sits, is lit by half the paper's light
    /// and more; the light is gone by the pool's reach, where the page shows through as before;
    /// and the upper part carries a reflection the lower does not.
    @Test func theGlassGathersLightBehindTheNumber() throws {
        let dark = try lens(try page(ink: 0))
        let middle = try pixel(dark, x: 64, y: 64)[1]
        let beyond = try pixel(dark, x: 64 + 44, y: 64 + 10)[1]
        let lit = 1 - (1 - LoupeLens.veil) * (1 - LoupeLens.pool)
        #expect(abs(Double(middle) - lit * 255) <= 14, "the middle: \(middle) against \(Int(lit * 255))")
        #expect(middle > beyond + 80, "the pool is at the middle: \(middle) against \(beyond)")
        let upper = try pixel(dark, x: 64, y: 64 - 46)[1]
        let lower = try pixel(dark, x: 64, y: 64 + 46)[1]
        #expect(upper > lower + 25, "the reflection is across the upper part: \(upper) against \(lower)")
    }

    /// Matt, 2026-11-13: the text behind the number "lighter and slightly more blurred just in the
    /// center", the edges kept as they were. A thin line running down through the glass is wider
    /// and paler where it passes the middle than where it passes between the middle and the rim.
    @Test func theGlassIsSofterAndLighterOnlyBehindTheNumber() throws {
        #expect(LoupeLens.centreBlur > LoupeLens.blur && LoupeLens.poolReach < LoupeLens.flat + 0.05)
        let lens = try lens(try page(ink: 1, lineX: 96))
        // Along a row: how dark the line is at its darkest, and how many pixels it darkens at all.
        func line(atRow y: Int) throws -> (darkest: Int, width: Int) {
            let row = try (40..<88).map { 255 - (try pixel(lens, x: $0, y: y)[1]) }
            return (row.max() ?? 0, row.filter { $0 > 12 }.count)
        }
        let middle = try line(atRow: 64)
        let outer = try line(atRow: 64 + 44)
        #expect(middle.darkest < outer.darkest - 40, "paler behind the number: \(middle.darkest) against \(outer.darkest)")
        #expect(middle.width > outer.width + 2, "and softer: \(middle.width) pixels wide against \(outer.width)")
    }

    /// The edge of the glass catches the light: on a mid grey page the rim is brighter than the
    /// middle, and brightest toward the top leading side.
    @Test func theGlassIsLitAtItsEdge() throws {
        let lens = try #require(LoupeLens.refract(try page(ink: 0.5), margin: 32, scale: 2, paper: (0.5, 0.5, 0.5)))
        let middle = try pixel(lens, x: 64, y: 64)[1]
        // On the rim, one pixel inside it: at the top leading side, and at the side.
        let lit = try pixel(lens, x: 64 - 44, y: 64 - 45)[1]
        let side = try pixel(lens, x: 64 - 63, y: 64)[1]
        #expect(side > middle + 15, "the edge all round: \(side) against \(middle)")
        #expect(lit > side + 15, "brighter where it catches the light: \(lit) against \(side)")
    }

    #if os(macOS)
    /// Psalms' thumb, Psalm 73 open, in Study, hosted in a window; the window must outlive its use.
    private func hostedThumb(isRevealed: Bool, dragging: Int?, loupeFrame: (@MainActor (CGRect) -> Void)? = nil) -> NSWindow {
        let view = BookThumbView(thumb: BookThumb(chapters: Array(1...150), current: 73),
                                 typography: .styled(ReaderPreferences(style: .study)),
                                 isRevealed: isRevealed, dragging: .constant(dragging), onLand: { _ in })
            .environment(\.colorScheme, .light)
            .environment(\.loupeFrameProbe, loupeFrame)
        let window = NSWindow(contentRect: NSRect(x: -3000, y: 0, width: 160, height: 600), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: view)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        return window
    }

    /// Hosted mid-drag on Psalm 76, the loupe is laid out beside Psalm 76's tick: centred on it,
    /// wholly to the ruler's left with its gap (Matt, 2026-11-13: it sat at the track's top
    /// corner whatever the drag, its position lost in the overlay's layout).
    @Test func theHostedLoupeSitsBesideItsTick() async throws {
        final class Box { var frame: CGRect? }
        let box = Box()
        let window = hostedThumb(isRevealed: true, dragging: 76) { box.frame = $0 }
        defer { window.close() }
        let deadline = Date().addingTimeInterval(5)
        while box.frame == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        let frame = try #require(box.frame)
        let thumb = BookThumb(chapters: Array(1...150), current: 73)
        let tick = BookThumbView.tickY(for: 76, inTrackHeight: 600, thumb: thumb)
        #expect(abs(frame.midY - tick) < 0.5, "centred on Psalm 76's tick: \(frame)")
        #expect(abs(frame.maxX - (-BookThumbView.loupeGap)) < 0.5, "its gap to the ruler's left: \(frame)")
        #expect(frame.width == AppSpacing.xxxl && frame.height == AppSpacing.xxxl)
    }
    #endif
}
