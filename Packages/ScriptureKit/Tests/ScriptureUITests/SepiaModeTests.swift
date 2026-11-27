import Foundation
import ScriptureData
import ScriptureModel
import SwiftUI
import Testing
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif
@testable import ScriptureUI

/// Sepia reaches every color the app draws: AppKit and UIKit drawing through the tokens' platform
/// colors, SwiftUI through the environment, and the open reader redraws when it is switched on
/// and off. Rendered offscreen into bitmaps from windows that are never ordered on screen.
#if canImport(UIKit)
@MainActor private final class EnvironmentBox {
    var environment: EnvironmentValues?
}

/// Reports the environment its body is evaluated in.
private struct EnvironmentProbe: View {
    let seen: EnvironmentBox
    @Environment(\.self) private var environment

    var body: some View {
        seen.environment = environment
        return Color.paperPage
    }
}
#else
/// Counts the effective-appearance changes a view sees.
private final class AppearanceProbe: NSView {
    var changes = 0

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        changes += 1
    }
}
#endif

@MainActor @Suite(.serialized) struct SepiaModeTests {
    /// Every pixel's `#RRGGBB` in the layer tree as rendered, with its count.
    private static func pixels(of layer: CALayer, size: CGSize) -> [String: Int] {
        let width = Int(size.width), height = Int(size.height)
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        layer.render(in: context)
        let data = context.data!.assumingMemoryBound(to: UInt8.self)
        var counts: [String: Int] = [:]
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            counts[String(format: "#%02X%02X%02X", data[i], data[i + 1], data[i + 2]), default: 0] += 1
        }
        return counts
    }

    private static let sepiaPage = Palette.paperPage.hex(dark: false, sepia: true)
    private static let sepiaInk = Palette.inkPrimary.hex(dark: false, sepia: true)

    private static func verses(count: Int) -> [Verse] {
        (1...count).map { n in
            Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: n), translationID: "WEB",
                  text: "Verse \(n) says enough words to wrap onto a second line in a narrow column, surely.", breakAfter: n % 4 == 0)
        }
    }

    private static func layout() -> BookLayout {
        let opening = BookOpening(bookName: "Matthew", title: BookTitle(title: "Matthew", subtitle: nil))
        return BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: "MAT", chapter: 5), verses: verses(count: 8))],
                                opening: opening, typography: .default)
    }

    /// The first default mark, on most of verse 3.
    private static let mark: MarkupColor = {
        let first = MarkupContainer.defaultColors[0]
        return MarkupColor(lightHex: first.lightHex, darkHex: first.darkHex)
    }()

    private static func highlighted(_ layout: BookLayout) -> BookDecorations {
        let item = MarkupItem(id: UUID(), chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 40, translationID: "WEB",
                              color: mark, hasNote: false)
        return BookDecorations.build(itemsByChapter: [5: [item]], bookmarksByChapter: [:], outlinedID: nil,
                                     viewingTranslationID: "WEB", layout: layout)
    }

    /// A character inside verse 1's text, drawn in primary ink.
    private static let textIndex = layout().span(for: VerseLocation(book: "MAT", chapter: 5, verse: 1))!.textRange.location + 2

    private static func hex(_ c: Color.Resolved) -> String {
        ColorHex.string(red: Double(c.red), green: Double(c.green), blue: Double(c.blue))
    }

    /// SwiftUI's palette colors resolve from the environment's scheme and Sepia, Sepia applying
    /// to the light scheme only.
    @Test func swiftUITokensResolveInEveryAppearance() {
        for token in Palette.all {
            for (dark, sepia) in [(false, false), (true, false), (false, true), (true, true)] {
                var environment = EnvironmentValues()
                environment.colorScheme = dark ? .dark : .light
                environment.isSepia = sepia
                #expect(Self.hex(Color(token: token).resolve(in: environment)) == token.hex(dark: dark, sepia: sepia),
                        "\(token.name) dark: \(dark) sepia: \(sepia)")
            }
        }
        // The precomputed variants line up with `hex(dark:highContrast:sepia:)`'s cases.
        #expect([(false, false, false), (true, false, false), (false, true, false), (true, true, false), (false, false, true),
                 (false, true, true), (true, false, true), (true, true, true)].map { TokenStyle.index(dark: $0, high: $1, sepia: $2) }
            == [0, 1, 2, 3, 4, 5, 1, 3])
    }

    #if canImport(AppKit)
    /// Puts the app in the light appearance with Sepia off, and returns what puts the app's
    /// appearance and Sepia back as they were. Called first, with the result deferred, so no
    /// state outlives the test.
    private static func lightApp() -> () -> Void {
        _ = NSApplication.shared
        let (appearance, sepia) = (NSApp.appearance, SepiaMode.isOn)
        NSApp.appearance = NSAppearance(named: .aqua)
        SepiaMode.set(false)
        return {
            SepiaMode.set(sepia)
            NSApp.appearance = appearance
        }
    }

    private func hex(_ color: NSColor, in name: NSAppearance.Name) -> String {
        var result = ""
        NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
            let c = color.usingColorSpace(.sRGB)!
            result = ColorHex.string(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent)
        }
        return result
    }

    @Test func platformColorsTakeSepiaInTheLightAppearanceOnly() {
        let restore = Self.lightApp()
        defer { restore() }
        let high = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        SepiaMode.set(true)
        #expect(SepiaMode.isOn)
        for token in Palette.all {
            #expect(hex(token.platformColor, in: .aqua) == token.hex(dark: false, highContrast: high, sepia: true), "\(token.name)")
            #expect(hex(token.platformColor, in: .darkAqua) == token.hex(dark: true, highContrast: high), "\(token.name)")
        }
        SepiaMode.set(false)
        #expect(hex(Palette.paperPage.platformColor, in: .aqua) == Palette.paperPage.light)
    }

    /// The open reader: its page, its text's color attributes and the text as drawn all turn warm
    /// when Sepia comes on and go back when it goes off, with the appearance light throughout.
    @Test func switchingRedrawsTheOpenReader() {
        let restore = Self.lightApp()
        defer { restore() }
        let controller = ChapterTextController(onReadingPositionChange: { _ in })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 300), styleMask: [.borderless], backing: .buffered, defer: false)
        let content = NSView(frame: window.contentLayoutRect)
        content.wantsLayer = true
        window.contentView = content
        controller.scrollView.frame = content.bounds
        content.addSubview(controller.scrollView)
        let layout = Self.layout()
        controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: Self.highlighted(layout))
        let height = controller.textView.textLayoutManager!.usageBoundsForTextContainer.maxY + 2 * controller.textView.textContainerInset.height
        controller.textView.setFrameSize(NSSize(width: controller.textView.frame.width, height: height))
        func drawn() -> [String: Int] {
            window.displayIfNeeded()
            CATransaction.flush()
            return Self.pixels(of: content.layer!, size: content.bounds.size)
        }
        func inkAttribute() -> String? {
            let ink = controller.textView.textStorage?.attribute(.foregroundColor, at: Self.textIndex, effectiveRange: nil) as? NSColor
            return ink.map { hex($0, in: controller.textView.effectiveAppearance.name) }
        }

        let light = drawn()
        #expect(light[Palette.paperPage.light, default: 0] > 0 && light[Self.sepiaPage] == nil)
        #expect(light[Palette.inkPrimary.light, default: 0] > 0 && light[Self.sepiaInk] == nil)
        #expect(light[Self.mark.lightHex, default: 0] > 0)

        SepiaMode.set(true)
        // The appearance stays light, yet every layer of the reader is due to draw again: the
        // page, the text's fragments, the highlight fills. (Rendering into a bitmap draws a layer
        // afresh, so the pixels alone would not show a stale on-screen page.)
        #expect(controller.textView.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua)
        #expect(controller.scrollView.contentView.layer?.needsDisplay() == true)
        #expect(controller.textView.layer?.needsDisplay() == true)
        #expect(controller.textView.layer?.sublayers?.allSatisfy { $0.needsDisplay() } == true)
        #expect(controller.fillsView.layer?.needsDisplay() == true)
        #expect(inkAttribute() == Self.sepiaInk)
        let sepia = drawn()
        #expect(sepia[Self.sepiaPage, default: 0] > 0 && sepia[Palette.paperPage.light] == nil)
        #expect(sepia[Self.sepiaInk, default: 0] > 0 && sepia[Palette.inkPrimary.light] == nil)
        // The highlight fill keeps its light value.
        #expect(sepia[Self.mark.lightHex, default: 0] > 0)

        SepiaMode.set(false)
        #expect(controller.textView.layer?.needsDisplay() == true)
        #expect(inkAttribute() == Palette.inkPrimary.light)
        let back = drawn()
        #expect(back[Palette.paperPage.light, default: 0] > 0 && back[Self.sepiaPage] == nil)
    }

    /// SwiftUI's palette colors, and the reader's platform inks shown in SwiftUI (the running
    /// head), follow the root's `followsSepia()`.
    @Test func swiftUIFollowsSepiaAtTheRoot() {
        let restore = Self.lightApp()
        defer { restore() }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 40, height: 40), styleMask: [.borderless], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: HStack(spacing: 0) {
            Color.paperPage
            Color(platform: Palette.inkSecondary.platformColor)
        }.followsSepia())
        window.contentView = host
        // Synchronous throughout, so no other test runs while Sepia is on.
        func drawn() -> [String: Int] {
            host.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            CATransaction.flush()
            return Self.pixels(of: host.layer!, size: host.bounds.size)
        }
        let secondary = Palette.inkSecondary
        let high = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        #expect(drawn() == [Palette.paperPage.light: 800, secondary.hex(dark: false, highContrast: high): 800])
        SepiaMode.set(true)
        #expect(drawn() == [Self.sepiaPage: 800, secondary.hex(dark: false, highContrast: high, sepia: true): 800])
        SepiaMode.set(false)
        #expect(drawn() == [Palette.paperPage.light: 800, secondary.hex(dark: false, highContrast: high): 800])
    }

    /// `apply()` takes the windows through the redraw round trip only when the appearance itself
    /// stays put: Light to Sepia and back. Sepia to Dark and Dark to Sepia change the appearance,
    /// which redraws the windows once on its own.
    @Test func applyRedrawsOnceWhenTheAppearanceChanges() {
        let restore = Self.lightApp()
        defer { restore() }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 40, height: 40), styleMask: [.borderless], backing: .buffered, defer: false)
        let probe = AppearanceProbe(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
        window.contentView = probe
        func changes(applying choice: AppearanceChoice) -> Int {
            let before = probe.changes
            choice.apply()
            #expect(SepiaMode.isOn == choice.isSepia)
            return probe.changes - before
        }
        AppearanceChoice.light.apply()
        #expect(changes(applying: .sepia) == 2)
        #expect(changes(applying: .dark) == 1)
        #expect(changes(applying: .sepia) == 1)
        #expect(changes(applying: .light) == 2)
        #expect(changes(applying: .light) == 0)
    }

    /// Every SwiftUI view hosted in AppKit is its own root, outside any scene's `followsSepia()`,
    /// so each takes it itself or is named here with the reason it need not.
    @Test func everyAppKitHostedSwiftUIRootFollowsSepia() throws {
        let allowed: [String: String] = [
            "ChapterTextController+Chrome.swift": "ChapterNoteMark draws in the accent alone, which Sepia leaves as it is",
        ]
        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let roots = [package.appending(path: "Sources"), package.appending(path: "../../Apps/Mac").standardized]
        var hosts = 0
        for root in roots {
            let files = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            for case let file as URL in files where file.pathExtension == "swift" {
                for (number, line) in try String(contentsOf: file, encoding: .utf8).split(separator: "\n").enumerated()
                where line.contains("NSHostingView") || line.contains("NSHostingController") {
                    hosts += 1
                    #expect(line.contains("followsSepia") || allowed[file.lastPathComponent] != nil,
                            "\(file.lastPathComponent):\(number + 1) hosts SwiftUI without followsSepia()")
                }
            }
        }
        #expect(hosts >= 3)
    }
    #else
    private func hex(_ color: UIColor, dark: Bool, sepia: Bool) -> String {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = dark ? .dark : .light
            traits[SepiaTrait.self] = sepia
        }
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return ColorHex.string(red: r, green: g, blue: b)
    }

    @Test func platformColorsTakeSepiaInTheLightAppearanceOnly() {
        for token in Palette.all {
            #expect(hex(token.platformColor, dark: false, sepia: true) == token.hex(dark: false, sepia: true), "\(token.name)")
            #expect(hex(token.platformColor, dark: true, sepia: true) == token.dark, "\(token.name)")
            #expect(hex(token.platformColor, dark: false, sepia: false) == token.light, "\(token.name)")
        }
    }

    /// The open reader: its page, its text's color attributes and the text as drawn all turn warm
    /// when the window takes the Sepia trait and go back when it loses it.
    @Test func switchingRedrawsTheOpenReader() {
        let controller = PhoneChapterTextController(onReadingPositionChange: { _ in })
        let window = TestWindow.make(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        window.overrideUserInterfaceStyle = .light
        controller.pageView.frame = window.bounds
        window.addSubview(controller.pageView)
        window.isHidden = false
        window.layoutIfNeeded()
        let layout = Self.layout()
        controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: Self.highlighted(layout), marginMarks: [], footer: nil)
        let textView = controller.textView
        func drawn() -> [String: Int] {
            window.layoutIfNeeded()
            textView.layoutIfNeeded()
            return Self.pixels(of: textView.layer, size: textView.bounds.size)
        }
        func inkAttribute() -> String? {
            let ink = textView.textStorage.attribute(.foregroundColor, at: Self.textIndex, effectiveRange: nil) as? UIColor
            return ink.map { color in
                var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
                color.resolvedColor(with: textView.traitCollection).getRed(&r, green: &g, blue: &b, alpha: &a)
                return ColorHex.string(red: r, green: g, blue: b)
            }
        }

        let light = drawn()
        #expect(light[Palette.paperPage.light, default: 0] > 0 && light[Self.sepiaPage] == nil)
        #expect(light[Palette.inkPrimary.light, default: 0] > 0)

        // Layers of the text view due to draw again (the text's fragments).
        func dueToDraw(_ layer: CALayer) -> Int {
            (layer.needsDisplay() ? 1 : 0) + (layer.sublayers ?? []).map(dueToDraw).reduce(0, +)
        }
        func page() -> String? {
            textView.layer.backgroundColor?.components.map { ColorHex.string(red: $0[0], green: $0[1], blue: $0[2]) }
        }
        #expect(dueToDraw(textView.layer) == 0)

        window.traitOverrides[SepiaTrait.self] = true
        window.layoutIfNeeded()
        textView.layoutIfNeeded()
        // The page's layer color is set again and the text is due to draw again: rendering into a
        // bitmap draws a layer afresh, so the pixels alone would not show a stale page.
        #expect(page() == Self.sepiaPage)
        #expect(dueToDraw(textView.layer) > 0)
        let sepia = drawn()
        #expect(textView.traitCollection[SepiaTrait.self])
        #expect(inkAttribute() == Self.sepiaInk)
        #expect(sepia[Self.sepiaPage, default: 0] > 0 && sepia[Palette.paperPage.light] == nil)
        #expect(sepia[Self.sepiaInk, default: 0] > 0 && sepia[Palette.inkPrimary.light] == nil)
        // The highlight fill keeps its light value.
        #expect(sepia[Self.mark.lightHex, default: 0] > 0)

        window.traitOverrides[SepiaTrait.self] = false
        let back = drawn()
        #expect(inkAttribute() == Palette.inkPrimary.light)
        #expect(back[Palette.paperPage.light, default: 0] > 0 && back[Self.sepiaPage] == nil)
        window.isHidden = true
    }

    /// SwiftUI's palette colors follow the window's Sepia trait, bridged into the environment.
    @Test func swiftUIFollowsTheSepiaTrait() async throws {
        let window = TestWindow.make(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        window.overrideUserInterfaceStyle = .light
        // A window with no scene does not render SwiftUI into its layers, so the probe reports
        // the environment its body sees and the palette color is resolved in it.
        let seen = EnvironmentBox()
        let host = UIHostingController(rootView: EnvironmentProbe(seen: seen))
        window.rootViewController = host
        window.isHidden = false
        func page() async throws -> String? {
            try await Task.sleep(for: .milliseconds(100))
            window.layoutIfNeeded()
            host.view.layoutIfNeeded()
            return seen.environment.map { environment in
                let c = Color.paperPage.resolve(in: environment)
                return ColorHex.string(red: Double(c.red), green: Double(c.green), blue: Double(c.blue))
            }
        }
        #expect(try await page() == Palette.paperPage.light)
        window.traitOverrides[SepiaTrait.self] = true
        #expect(try await page() == Self.sepiaPage)
        #expect(seen.environment?.isSepia == true)
        // The reader's platform inks shown in SwiftUI (the phone's bar title) follow it too.
        let secondary = seen.environment.map { Color(platform: Palette.inkSecondary.platformColor).resolve(in: $0) }
        #expect(secondary.map { ColorHex.string(red: Double($0.red), green: Double($0.green), blue: Double($0.blue)) }
            == Palette.inkSecondary.hex(dark: false, sepia: true))
        window.traitOverrides[SepiaTrait.self] = false
        #expect(try await page() == Palette.paperPage.light)
        window.isHidden = true
    }
    #endif
}
