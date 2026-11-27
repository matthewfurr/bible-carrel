#if os(iOS)
import SwiftUI
import Testing
import UIKit
@testable import ScriptureUI

/// The edge swipes between the phone's screens, on a real window with SwiftUI's tab view: the
/// tab arriving comes in live while a picture of the one leaving moves aside; a release past
/// halfway settles, short of it springs back to the tab it began on; Library comes and goes over
/// Read; a pushed screen keeps its left edge for the back swipe; nothing moves under a sheet.
@MainActor @Suite(.serialized) struct PhoneEdgeSwipesTests {
    /// Four tabs and Library over them, as the root draws them, with a stack on Notes that can push.
    private struct Shell: View {
        @Bindable var shell: PhoneShellModel
        let slide: LibrarySlide
        let swipes: PhoneEdgeSwipes
        @Binding var pushed: Bool

        var body: some View {
            ZStack {
                TabView(selection: $shell.tab) {
                    Tab("Read", systemImage: "book", value: PhoneTab.read) { Text("Read page") }
                    Tab("Plan", systemImage: "calendar", value: PhoneTab.plan) { Text("Plan") }
                    Tab("Notes", systemImage: "note.text", value: PhoneTab.notes) {
                        NavigationStack {
                            List { Text("Notes list") }
                                .navigationTitle("Notes")
                                .navigationDestination(isPresented: $pushed) { Text("A note") }
                        }
                    }
                    Tab("Ask", systemImage: "sparkles", value: PhoneTab.ask) { Text("Ask") }
                }
                if shell.isLibraryShown || slide.isCarrying { Text("Library") }
            }
            .background { PhoneEdgeSwipeInstaller(swipes: swipes) }
        }
    }

    @MainActor private struct Hosted {
        let window: UIWindow
        let shell: PhoneShellModel
        let slide: LibrarySlide
        let swipes: PhoneEdgeSwipes
        let pushed: Binding<Bool>
        var tabs: UITabBarController? { PhoneEdgeSwipes.tabBarController(in: window.rootViewController) }
    }

    private final class PushedBox { var value = false }

    private func host() async throws -> Hosted {
        let shell = PhoneShellModel()
        let slide = LibrarySlide()
        let swipes = PhoneEdgeSwipes(shell: shell, slide: slide)
        swipes.reduceMotion = { false }
        let box = PushedBox()
        let pushed = Binding(get: { box.value }, set: { box.value = $0 })
        let hosting = UIHostingController(rootView: Shell(shell: shell, slide: slide, swipes: swipes, pushed: pushed))
        let window = TestWindow.make(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = hosting
        window.isHidden = false
        await pump(window, seconds: 0.2)
        return Hosted(window: window, shell: shell, slide: slide, swipes: swipes, pushed: pushed)
    }

    private func pump(_ window: UIWindow, seconds: TimeInterval = 0.05) async {
        let end = Date(timeIntervalSinceNow: seconds)
        while Date() < end {
            await Task.yield()
            Self.runMainLoopBriefly()
            window.layoutIfNeeded()
        }
    }

    /// Until the swipe has settled or sprung back (a spring, slower under a loaded test run).
    private func settle(_ hosted: Hosted) async {
        let end = Date(timeIntervalSinceNow: 5)
        while Date() < end, hosted.swipes.isSwiping || hosted.slide.isCarrying {
            await pump(hosted.window, seconds: 0.05)
        }
        await pump(hosted.window, seconds: 0.05)
    }

    private static func runMainLoopBriefly() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
    }


    @Test func swipesAreOnTheWindowAndTheTabViewIsATabBarController() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        #expect(hosted.swipes.window === hosted.window)
        #expect(hosted.window.gestureRecognizers?.filter { $0 is UIPanGestureRecognizer }.count == 2)
        let tabs = try #require(hosted.tabs, "SwiftUI's TabView is a UITabBarController")
        #expect(tabs.selectedIndex == 0)
    }

    @Test func aReleasePastHalfwaySettlesOnTheNextTab() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        let tabs = try #require(hosted.tabs)
        #expect(hosted.swipes.beginSwipe(from: .right))
        await pump(hosted.window)
        // The tab arriving is live at once, coming in from the right over the picture of Read.
        #expect(hosted.shell.tab == .plan)
        #expect(tabs.selectedIndex == 1)
        let picture = try #require(hosted.swipes.tabPicture)
        #expect(picture.superview === tabs.view)
        hosted.swipes.moveSwipe(travel: 300)
        let shown = try #require(tabs.selectedViewController?.view)
        let content = try #require(TabSlide.ancestor(of: shown, under: tabs.view))
        // Pictures move; the live tab never does.
        let arriving = try #require(hosted.swipes.arrivingPicture)
        #expect(abs(arriving.transform.tx - (402 - 300)) < 0.5)
        #expect(abs(picture.transform.tx - (-300 * EdgeSwipe.underneathDrift)) < 0.5)
        #expect(content.transform == .identity)
        hosted.swipes.endSwipe(settles: true, speed: 0)
        await settle(hosted)
        #expect(!hosted.swipes.isSwiping)
        #expect(hosted.shell.tab == .plan)
        #expect(content.transform == .identity)
        #expect(picture.superview == nil && arriving.superview == nil)
    }

    /// In the simulator a second swipe 30 ms after the first was refused while the first settled:
    /// two quick swipes must move two screens, the first landing at once.
    @Test func aSwipeDuringTheLastOnesSettleLandsItAndGoesOn() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        let tabs = try #require(hosted.tabs)
        #expect(hosted.swipes.beginSwipe(from: .right))
        await pump(hosted.window)
        hosted.swipes.moveSwipe(travel: 300)
        hosted.swipes.endSwipe(settles: true, speed: 400)
        let first = try #require(hosted.swipes.tabPicture)
        #expect(hosted.swipes.isSwiping)
        #expect(hosted.swipes.beginSwipe(from: .right))
        #expect(first.superview == nil)
        await pump(hosted.window)
        #expect(hosted.shell.tab == .notes)
        hosted.swipes.moveSwipe(travel: 300)
        hosted.swipes.endSwipe(settles: true, speed: 400)
        await settle(hosted)
        #expect(hosted.shell.tab == .notes && tabs.selectedIndex == 2)
        let shown = try #require(tabs.selectedViewController?.view)
        let content = try #require(TabSlide.ancestor(of: shown, under: tabs.view))
        #expect(content.transform == .identity)
        // And straight back from a spring-back.
        #expect(hosted.swipes.beginSwipe(from: .left))
        hosted.swipes.moveSwipe(travel: 40)
        hosted.swipes.endSwipe(settles: false)
        #expect(hosted.swipes.beginSwipe(from: .left))
        await pump(hosted.window)
        #expect(hosted.shell.tab == .plan)
        hosted.swipes.moveSwipe(travel: 300)
        hosted.swipes.endSwipe(settles: true, speed: 400)
        await settle(hosted)
        #expect(hosted.shell.tab == .plan && content.transform == .identity)
    }

    /// Matt, 2026-11-16: after a swipe to Notes or Ask the large title sometimes sat against the
    /// left edge, and a later swipe on Ask moved the page. UIKit can lay the tab view out while a
    /// swipe has it moved; a frame set on a moved view shifts its centre, and once the move is
    /// cleared the tab stayed shifted by however far it was moved at that moment.
    @Test func aLayoutDuringTheSwipeLeavesTheTabInPlace() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        let tabs = try #require(hosted.tabs)
        let shown = try #require(tabs.selectedViewController?.view)
        let content = try #require(TabSlide.ancestor(of: shown, under: tabs.view))
        let home = content.frame
        #expect(hosted.swipes.beginSwipe(from: .right))
        await pump(hosted.window)
        hosted.swipes.moveSwipe(travel: 380)
        // What the tab bar controller does when it lays out (the keyboard going, the bar minimizing).
        tabs.view.setNeedsLayout()
        tabs.view.layoutIfNeeded()
        content.frame = home
        hosted.swipes.moveSwipe(travel: 390)
        hosted.swipes.endSwipe(settles: true, speed: 400)
        await settle(hosted)
        #expect(hosted.shell.tab == .plan)
        #expect(content.transform == .identity)
        #expect(content.frame == home)
    }

    /// Matt, 2026-11-16: "When swiping to notes sometimes the Notes header loses its margin and
    /// is right up against the left edge." UIKit gives a screen its minimum side margins only
    /// where it meets the window's edge; laid out while a swipe has it moved, the screen loses
    /// them, and they must be back once it lands.
    @Test func theArrivingScreenKeepsItsMargins() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        let tabs = try #require(hosted.tabs)
        hosted.shell.tab = .notes
        await pump(hosted.window, seconds: 0.3)
        let notes = try #require(tabs.selectedViewController)
        let stack = try #require(Self.navigationController(in: notes))
        let restingMargin = stack.navigationBar.layoutMargins.left
        let restingList = Self.collectionView(in: stack.view)?.layoutMargins.left
        #expect(restingMargin > 0)
        hosted.shell.tab = .plan
        await pump(hosted.window, seconds: 0.3)
        #expect(hosted.swipes.beginSwipe(from: .right))
        await pump(hosted.window)
        for travel in stride(from: CGFloat(20), through: 380, by: 60) {
            hosted.swipes.moveSwipe(travel: travel)
            stack.view.setNeedsLayout()
            stack.navigationBar.setNeedsLayout()
            await pump(hosted.window, seconds: 0.02)
        }
        hosted.swipes.endSwipe(settles: true, speed: 400)
        await settle(hosted)
        await pump(hosted.window, seconds: 0.2)
        #expect(hosted.shell.tab == .notes)
        #expect(stack.navigationBar.layoutMargins.left == restingMargin)
        #expect(Self.collectionView(in: stack.view)?.layoutMargins.left == restingList)
    }

    private static func collectionView(in view: UIView) -> UICollectionView? {
        if let list = view as? UICollectionView { return list }
        for subview in view.subviews {
            if let list = collectionView(in: subview) { return list }
        }
        return nil
    }

    /// Matt, 2026-11-16: on Ask, with nowhere to the right, a drag in from the right edge "still
    /// moves the page sometimes". At the chain's end the edge holds the drag and nothing moves;
    /// a drag outward or mostly up or down is never the edge's.
    @Test func theChainsEndsHoldTheDragAndMoveNothing() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        hosted.shell.tab = .ask
        await pump(hosted.window)
        #expect(!hosted.swipes.maySwipe(from: .right))
        #expect(hosted.swipes.takesDrag(from: .right, movement: CGPoint(x: -30, y: 4)))
        #expect(!hosted.swipes.takesDrag(from: .right, movement: CGPoint(x: 30, y: 0)))
        #expect(!hosted.swipes.takesDrag(from: .right, movement: CGPoint(x: -10, y: 30)))
        #expect(!hosted.swipes.beginSwipe(from: .right))
        hosted.swipes.moveSwipe(travel: 200)
        hosted.swipes.endSwipe(settles: true, speed: 900)
        #expect(hosted.shell.tab == .ask && !hosted.swipes.isSwiping)
        // The left edge from Ask is a swipe, as from every other tab.
        #expect(hosted.swipes.takesDrag(from: .left, movement: CGPoint(x: 30, y: 4)))
        hosted.shell.show(.library)
        await pump(hosted.window)
        #expect(hosted.swipes.takesDrag(from: .left, movement: CGPoint(x: 30, y: 0)))
        #expect(!hosted.swipes.beginSwipe(from: .left))
        #expect(hosted.shell.isLibraryShown)
    }

    /// The first swipe into Notes waited about 0.7 s while SwiftUI built it; a copy is built out
    /// of sight at rest and let go, behind the app, never taking a touch.
    @Test func aWarmUpBuildsOutOfSightAndLetsGo() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        let before = hosted.window.subviews.count
        hosted.swipes.warmUp(Text("Notes warming"))
        #expect(hosted.window.subviews.count == before + 1)
        let rootView = try #require(hosted.window.rootViewController?.view)
        let root = try #require(TabSlide.ancestor(of: rootView, under: hosted.window))
        let index = try #require(hosted.window.subviews.firstIndex(of: root))
        #expect(index > 0, "behind the app")
        let warm = hosted.window.subviews[index - 1]
        #expect(!warm.isUserInteractionEnabled && warm.accessibilityElementsHidden)
        await pump(hosted.window, seconds: 0.4)
        #expect(hosted.window.subviews.count == before)
    }

    @Test func aShortReleaseSpringsBackToTheTabItBeganOn() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        let tabs = try #require(hosted.tabs)
        hosted.shell.tab = .ask
        await pump(hosted.window)
        #expect(hosted.swipes.beginSwipe(from: .left))
        await pump(hosted.window)
        #expect(hosted.shell.tab == .notes)
        let picture = try #require(hosted.swipes.tabPicture)
        hosted.swipes.moveSwipe(travel: 80)
        hosted.swipes.endSwipe(settles: false)
        await settle(hosted)
        #expect(!hosted.swipes.isSwiping)
        #expect(hosted.shell.tab == .ask)
        #expect(tabs.selectedIndex == 3)
        #expect(picture.superview == nil)
        let shown = try #require(tabs.selectedViewController?.view)
        let content = try #require(TabSlide.ancestor(of: shown, under: tabs.view))
        #expect(content.transform == .identity)
    }

    @Test func libraryComesInFromReadsLeftEdgeAndGoesFromItsRight() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        #expect(hosted.swipes.beginSwipe(from: .left))
        #expect(hosted.slide.isCarrying && hosted.slide.fraction == 0)
        hosted.swipes.moveSwipe(travel: 201)
        #expect(abs(hosted.slide.fraction - 0.5) < 0.01)
        hosted.swipes.endSwipe(settles: true)
        await settle(hosted)
        #expect(hosted.shell.isLibraryShown && !hosted.slide.isCarrying)
        // Library's left edge is the chain's end.
        #expect(!hosted.swipes.maySwipe(from: .left))
        #expect(hosted.swipes.beginSwipe(from: .right))
        #expect(hosted.slide.fraction == 1)
        hosted.swipes.moveSwipe(travel: 300)
        hosted.swipes.endSwipe(settles: true)
        await settle(hosted)
        #expect(!hosted.shell.isLibraryShown && hosted.shell.tab == .read)
    }

    @Test func underReduceMotionTheScreenCutsOnceTheFingerIsFarEnoughIn() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        hosted.swipes.reduceMotion = { true }
        #expect(hosted.swipes.beginSwipe(from: .right))
        hosted.swipes.moveSwipe(travel: EdgeSwipe.cutTravel - 1)
        #expect(hosted.shell.tab == .read)
        hosted.swipes.moveSwipe(travel: EdgeSwipe.cutTravel)
        #expect(hosted.shell.tab == .plan)
        #expect(!hosted.swipes.isSwiping)
    }

    @Test func aPushedScreenKeepsItsLeftEdgeForTheBackSwipe() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        hosted.shell.tab = .notes
        await pump(hosted.window)
        #expect(hosted.swipes.maySwipe(from: .left))
        hosted.pushed.wrappedValue = true
        // The binding is not observed, so the stack is pushed through its controller's state.
        let tabs = try #require(hosted.tabs)
        let selected = try #require(tabs.selectedViewController)
        let stack = try #require(Self.navigationController(in: selected))
        stack.pushViewController(UIViewController(), animated: false)
        await pump(hosted.window)
        #expect(!hosted.swipes.maySwipe(from: .left))
        #expect(hosted.swipes.maySwipe(from: .right))
    }

    @Test func nothingMovesUnderASheet() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        let root = try #require(hosted.window.rootViewController)
        #expect(hosted.swipes.maySwipe(from: .right))
        root.present(UIViewController(), animated: false)
        await pump(hosted.window)
        #expect(!hosted.swipes.maySwipe(from: .right))
        #expect(!hosted.swipes.maySwipe(from: .left))
        // A scene-less test window never finishes a dismissal, so the sheet stays to the end.
        root.dismiss(animated: false)
    }

    @Test func selectedTextKeepsTheEdgesForItsHandles() async throws {
        let hosted = try await host()
        defer { hosted.window.isHidden = true }
        let text = UITextView(frame: CGRect(x: 0, y: 100, width: 300, height: 100))
        text.text = "In the beginning"
        hosted.window.addSubview(text)
        #expect(hosted.swipes.maySwipe(from: .right))
        text.selectedRange = NSRange(location: 0, length: 2)
        #expect(!hosted.swipes.maySwipe(from: .right))
        text.removeFromSuperview()
    }

    private static func navigationController(in controller: UIViewController) -> UINavigationController? {
        if let stack = controller as? UINavigationController { return stack }
        for child in controller.children {
            if let stack = navigationController(in: child) { return stack }
        }
        return nil
    }
}
#endif
