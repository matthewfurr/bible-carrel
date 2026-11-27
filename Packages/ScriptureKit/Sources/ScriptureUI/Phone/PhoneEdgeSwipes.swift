#if os(iOS)
import SwiftUI
import UIKit

/// Library on its way in or out under a finger: how much of it is on screen. The root draws
/// Library from this while `isCarrying`, so a frame of the swipe redraws Library's offset alone.
@MainActor @Observable final class LibrarySlide {
    /// A swipe is carrying Library; it is drawn even before `PhoneShellModel.isLibraryShown`.
    var isCarrying = false
    /// How much of Library is on screen, 0 (none) to 1 (all of it).
    var fraction: CGFloat = 0
    /// The screen's width, for the offset.
    var width: CGFloat = 0
}

/// Library, the screen to the left of Read: over every tab and the tab bar, sliding in from the
/// left edge when it opens (Library's button, or a swipe in from Read's left edge) and out to it
/// when it closes (Close, a chosen chapter, or a swipe in from its right edge). Closing it forgets
/// the page it was on, so it opens again on the list; leaving it for a passage opened from that
/// page (a Library lookup) keeps the page, for the way back to reopen it there.
struct PhoneLibraryLayer: View {
    let navigation: NavigationModel
    let markup: MarkupModel
    let shell: PhoneShellModel
    let slide: LibrarySlide
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if shell.isLibraryShown || slide.isCarrying {
                PhoneLibraryScreen(navigation: navigation, markup: markup, shell: shell) { shell.isLibraryShown = false }
                    .background(Color.paperPage.ignoresSafeArea())
                    .modifier(LibrarySlideOffset(slide: slide))
                    .transition(.move(edge: .leading))
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { shell.isLibraryShown = false }
            }
        }
        .animation(reduceMotion ? nil : PhoneEdgeSwipes.settleAnimation, value: shell.isLibraryShown)
        .onChange(of: shell.isLibraryShown) { _, shown in
            if !shown, !Self.isLeftForALookup(navigation) { navigation.libraryPlace = nil }
        }
    }

    /// Library has gone for a passage opened from the page it shows: the lookup returns to that page.
    static func isLeftForALookup(_ navigation: NavigationModel) -> Bool {
        guard let back = navigation.libraryReturn?.place, let place = navigation.libraryPlace else { return false }
        return back.pages == place.pages
    }
}

/// Library's offset while a swipe carries it; read here, so a frame of the swipe never rebuilds Library.
private struct LibrarySlideOffset: ViewModifier {
    let slide: LibrarySlide

    func body(content: Content) -> some View {
        content.offset(x: slide.isCarrying ? (slide.fraction - 1) * slide.width : 0)
    }
}

/// Puts the edge swipes on the window the root is in.
struct PhoneEdgeSwipeInstaller: UIViewRepresentable {
    let swipes: PhoneEdgeSwipes

    func makeUIView(context: Context) -> InstallerView { InstallerView(swipes: swipes) }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        let swipes: PhoneEdgeSwipes

        init(swipes: PhoneEdgeSwipes) {
            self.swipes = swipes
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            swipes.install(in: window)
        }
    }
}

/// The edge swipes between the phone's screens (spec 4): a swipe in from the left edge moves one
/// screen left (Ask → Notes → Plan → Read → Library), one from the right edge one screen right. The
/// screen follows the finger and settles or springs back on release; under Reduce Motion it is a
/// cut once the finger has come `EdgeSwipe.cutTravel` in.
///
/// Two pans on the window that take only touches starting in the 24 pt at their edge and begin
/// only on an inward move (a screen-edge pan never began for the simulator's touches, and these
/// behave the same on a device). They never begin under a sheet, on search, or with text
/// selected; inside a pushed screen the left edge is the system back swipe's. In the edge zone a
/// scroll view's pan or a row's swipe actions wait for them to fail, so a drag in from the edge
/// changes screens and never deletes a row. A hold at the edge is the reader's thumb: its press
/// takes the touch before a pan begins.
///
/// Between tabs the screen leaving is a picture (`TabSlide`), since the tab bar controller shows
/// one tab at a time; the tab coming in is live from the first frame. Library is a SwiftUI layer
/// over the tabs and moves by `LibrarySlide`.
@MainActor final class PhoneEdgeSwipes: NSObject, UIGestureRecognizerDelegate {
    /// How a swipe settles or springs back, and how Library's button opens it.
    static let settleAnimation = Animation.smooth(duration: 0.35)
    /// The width from each edge in which a swipe may start.
    static let edgeZone: CGFloat = 24

    let shell: PhoneShellModel
    let slide: LibrarySlide
    /// Read when a swipe begins; tests set it.
    var reduceMotion: () -> Bool = { UIAccessibility.isReduceMotionEnabled }

    private let leftPan = UIPanGestureRecognizer()
    private let rightPan = UIPanGestureRecognizer()
    private(set) weak var window: UIWindow?
    private var carry: Carry?
    /// The finger is on the glass: the swipe follows it. Once it lifts the swipe settles, and a
    /// new one may begin.
    private var isTracking = false
    /// Lands the settling swipe at once; the settle's own completion then does nothing.
    private var settleNow: (() -> Void)?
    private var settleGeneration = 0
    /// Where each pan's touch came down, in the window: a pan's own translation still reads zero
    /// when it asks to begin a slow drag, which refused every slow swipe (Matt, 2026-11-16).
    private var touchStart: [ObjectIdentifier: CGPoint] = [:]

    /// The swipe under way.
    private enum Carry {
        /// Between tabs: the picture of the one leaving and the one arriving, live.
        case tabs(TabSlide, from: PhoneTab)
        /// Library opening over Read, or closing off it.
        case library(opening: Bool)
        /// Under Reduce Motion, or with no tab bar controller to move: nothing moves until the
        /// finger has come far enough, then the screen changes as a cut.
        case cut(to: PhoneScreen)
    }

    init(shell: PhoneShellModel, slide: LibrarySlide) {
        self.shell = shell
        self.slide = slide
        super.init()
        for pan in [leftPan, rightPan] {
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
            pan.addTarget(self, action: #selector(handlePan(_:)))
        }
    }

    func install(in newWindow: UIWindow?) {
        guard newWindow !== window else { return }
        window?.removeGestureRecognizer(leftPan)
        window?.removeGestureRecognizer(rightPan)
        window = newWindow
        newWindow?.addGestureRecognizer(leftPan)
        newWindow?.addGestureRecognizer(rightPan)
    }

    /// A swipe is following the finger or settling.
    var isSwiping: Bool { carry != nil }

    /// Builds `screen` once out of sight, behind the app, then lets it go: what its first build
    /// costs (fonts, a list's machinery) is paid at rest rather than under a swipe's finger.
    func warmUp(_ screen: some View) {
        guard let window, let rootView = window.rootViewController?.view,
              let root = TabSlide.ancestor(of: rootView, under: window) else { return }
        let host = UIHostingController(rootView: screen)
        host.view.frame = window.bounds
        host.view.isUserInteractionEnabled = false
        host.view.accessibilityElementsHidden = true
        window.insertSubview(host.view, belowSubview: root)
        host.view.layoutIfNeeded()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            host.view.removeFromSuperview()
        }
    }

    /// The picture of the tab leaving, while a swipe between tabs is under way.
    var tabPicture: UIView? {
        if case .tabs(let slide, _) = carry { return slide.picture }
        return nil
    }

    /// The picture of the tab arriving, once it is taken.
    var arrivingPicture: UIView? {
        if case .tabs(let slide, _) = carry { return slide.arriving }
        return nil
    }

    // MARK: The swipe

    /// Whether a swipe in from `edge` may change screens now.
    func maySwipe(from edge: SwipeEdge) -> Bool {
        guard carry == nil, let window, shell.screen(swipingFrom: edge) != nil else { return false }
        // A sheet takes the swipe for itself or ignores it; tabs never change under one.
        guard !Self.isPresenting(window.rootViewController) else { return false }
        // Inside a pushed screen the system back swipe comes first.
        if edge == .left, !shell.isLibraryShown,
           let tabs = Self.tabBarController(in: window.rootViewController), Self.isPushed(tabs.selectedViewController) {
            return false
        }
        // A selection's handles at the edge are the selection's.
        return !Self.hasSelectedText(in: window)
    }

    /// Starts a swipe in from `edge`, if one may start: the next screen comes in at the edge.
    @discardableResult
    func beginSwipe(from edge: SwipeEdge) -> Bool {
        landSettlingSwipe()
        guard maySwipe(from: edge), let window, let destination = shell.screen(swipingFrom: edge) else { return false }
        isTracking = true
        let width = window.bounds.width
        if reduceMotion() {
            carry = .cut(to: destination)
        } else if destination == .library || shell.screen == .library {
            let opening = destination == .library
            slide.width = width
            slide.fraction = opening ? 0 : 1
            slide.isCarrying = true
            carry = .library(opening: opening)
        } else if let tabs = Self.tabBarController(in: window.rootViewController),
                  let picture = TabSlide(tabBarController: tabs, edge: edge, width: width) {
            let from = shell.tab
            carry = .tabs(picture, from: from)
            withoutAnimation { shell.show(destination) }
        } else {
            carry = .cut(to: destination)
        }
        return true
    }

    /// The finger has come `travel` in from its edge.
    func moveSwipe(travel: CGFloat) {
        guard let carry, let width = window?.bounds.width else { return }
        let travel = EdgeSwipe.clampedTravel(travel, width: width)
        switch carry {
        case .tabs(let picture, _):
            picture.takeArrivingPicture()
            picture.move(travel: travel)
        case .library(let opening):
            slide.fraction = opening ? travel / width : 1 - travel / width
        case .cut(let destination):
            guard travel >= EdgeSwipe.cutTravel else { return }
            self.carry = nil
            isTracking = false
            withoutAnimation { shell.show(destination) }
            window?.endEditing(true)
            // The rest of this drag is not a swipe.
            for pan in [leftPan, rightPan] where pan.state == .began || pan.state == .changed {
                pan.isEnabled = false
                pan.isEnabled = true
            }
        }
    }

    /// The finger has lifted (or the swipe was cancelled, `settles` false): settle on the next
    /// screen or spring back to the one it began on.
    func endSwipe(settles: Bool, speed: CGFloat = 0) {
        guard let carry, isTracking else { return }
        isTracking = false
        settleGeneration += 1
        let generation = settleGeneration
        switch carry {
        case .tabs(let picture, let from):
            if settles { window?.endEditing(true) }
            settleNow = { [weak self] in
                picture.stopMoving()
                if !settles { self?.withoutAnimation { self?.shell.tab = from } }
                picture.tearDown()
            }
            picture.finish(settles: settles, speed: speed) { [weak self] in
                guard let self, self.settleGeneration == generation else { return }
                self.settleNow = nil
                if settles {
                    picture.tearDown()
                    self.carry = nil
                } else {
                    // Back to the tab it began on; its picture stays over it until it is live
                    // again, or until a new swipe begins.
                    self.withoutAnimation { self.shell.tab = from }
                    self.settleNow = { picture.tearDown() }
                    picture.tearDownWhenShowingStart {
                        guard self.settleGeneration == generation else { return }
                        self.settleNow = nil
                        self.carry = nil
                    }
                }
            }
        case .library(let opening):
            let shown: CGFloat = opening == settles ? 1 : 0
            let land = { [weak self] in
                guard let self else { return }
                self.withoutAnimation {
                    self.slide.fraction = shown
                    self.shell.isLibraryShown = shown == 1
                    self.slide.isCarrying = false
                }
            }
            settleNow = land
            withAnimation(Self.settleAnimation) {
                slide.fraction = shown
            } completion: { [weak self] in
                guard let self, self.settleGeneration == generation else { return }
                self.settleNow = nil
                land()
                self.carry = nil
            }
        case .cut:
            self.carry = nil
        }
    }

    /// A swipe that begins while the last one is still settling lands the last one at once, so
    /// two quick swipes move two screens.
    private func landSettlingSwipe() {
        guard carry != nil, !isTracking else { return }
        settleGeneration += 1
        settleNow?()
        settleNow = nil
        carry = nil
    }

    private func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let window else { return }
        let edge: SwipeEdge = pan === leftPan ? .left : .right
        let sign: CGFloat = edge == .left ? 1 : -1
        let travel = movement(of: pan).x * sign
        let speed = pan.velocity(in: window).x * sign
        switch pan.state {
        case .began:
            if beginSwipe(from: edge) { moveSwipe(travel: travel) }
        case .changed:
            moveSwipe(travel: travel)
        case .ended:
            endSwipe(settles: EdgeSwipe.settles(travel: travel, speed: speed, width: window.bounds.width), speed: speed)
        case .cancelled, .failed:
            endSwipe(settles: false)
        default:
            break
        }
    }

    /// How far the pan's touch has come from where it came down, in the window.
    private func movement(of pan: UIPanGestureRecognizer) -> CGPoint {
        guard let window, let start = touchStart[ObjectIdentifier(pan)] else { return .zero }
        let now = pan.location(in: window)
        return CGPoint(x: now.x - start.x, y: now.y - start.y)
    }

    // MARK: Gesture rules

    /// A pan that starts in an edge zone is a swipe only when it moves inward, more across than
    /// up or down; any other drag from the edge is the page's. At either end of the chain (Ask's
    /// right edge, Library's left) the pan still takes the drag and does nothing, so nothing under
    /// the finger moves: a drag in from the edge never swipes a row or the page (Matt, 2026-11-16).
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        return takesDrag(from: pan === leftPan ? .left : .right, movement: movement(of: pan))
    }

    /// Whether a drag from `edge` that has come `movement` from where it came down is the edge
    /// swipe's: a swipe, or a drag at the chain's end that it holds so nothing else moves.
    func takesDrag(from edge: SwipeEdge, movement: CGPoint) -> Bool {
        guard let window else { return false }
        let inward = edge == .left ? movement.x : -movement.x
        guard inward > 0, inward > abs(movement.y) else { return false }
        landSettlingSwipe()
        if maySwipe(from: edge) { return true }
        return isDeadEnd(edge) && !Self.isPresenting(window.rootViewController)
    }

    /// A swipe from `edge` would leave the chain: Ask's right edge, Library's left.
    private func isDeadEnd(_ edge: SwipeEdge) -> Bool {
        shell.screen != nil && shell.screen(swipingFrom: edge) == nil
    }

    /// Only touches that start in the edge zone, so nothing else ever waits on these pans.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let window else { return false }
        let point = touch.location(in: window)
        let takes = gestureRecognizer === leftPan ? point.x <= Self.edgeZone : point.x >= window.bounds.width - Self.edgeZone
        if takes { touchStart[ObjectIdentifier(gestureRecognizer)] = point }
        return takes
    }

    /// In the edge zone a scroll view's pan and a row's swipe actions wait for the edge swipe to
    /// fail; the system back swipe (an edge pan of its own) does not, nor do these two each other.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        otherGestureRecognizer is UIPanGestureRecognizer && !(otherGestureRecognizer is UIScreenEdgePanGestureRecognizer)
            && otherGestureRecognizer !== leftPan && otherGestureRecognizer !== rightPan
    }

    // MARK: Finding things in the window

    /// The tab bar controller SwiftUI's `TabView` is drawn in.
    static func tabBarController(in controller: UIViewController?) -> UITabBarController? {
        guard let controller else { return nil }
        if let tabs = controller as? UITabBarController { return tabs }
        for child in controller.children {
            if let tabs = tabBarController(in: child) { return tabs }
        }
        return nil
    }

    /// Whether a controller in the tab's tree has a screen pushed over its root.
    static func isPushed(_ controller: UIViewController?) -> Bool {
        guard let controller else { return false }
        if let stack = controller as? UINavigationController, stack.viewControllers.count > 1 { return true }
        return controller.children.contains { isPushed($0) }
    }

    /// Whether a sheet, cover or popover is up over the root or any controller under it.
    static func isPresenting(_ controller: UIViewController?) -> Bool {
        guard let controller else { return false }
        if controller.presentedViewController != nil { return true }
        return controller.children.contains { isPresenting($0) }
    }

    /// Whether text is selected in a text view or field on screen.
    static func hasSelectedText(in view: UIView) -> Bool {
        if view.isHidden || view.alpha == 0 { return false }
        if let text = view as? UITextView, text.selectedRange.length > 0 { return true }
        if let field = view as? UITextField, let range = field.selectedTextRange, !range.isEmpty { return true }
        return view.subviews.contains { hasSelectedText(in: $0) }
    }
}

/// A swipe between tabs, drawn on the tab bar controller's view under its tab bar, in pictures
/// only: one of the tab leaving, taken as the swipe begins, and one of the tab arriving, taken
/// once the tab bar controller shows it. The live tabs never move. (Moved, a screen laid out
/// away from the window's edge loses UIKit's minimum side margins: Matt saw the Notes and Ask
/// titles against the left edge after a swipe, 2026-11-16.) Swiping in from the left edge (to
/// the screen on the left) carries the leaving picture off to the right over the arriving one,
/// which drifts in from a third of the way across, as the system back swipe does; from the right
/// edge the arriving picture comes in over the leaving one, which drifts left beneath it.
///
/// The bars' Liquid Glass buttons are not in the pictures: the render server draws glass, and
/// neither `snapshotView` nor `drawHierarchy` includes it (tried 2026-11-16). They are gone for
/// the moment of a swipe and back when it lands.
@MainActor final class TabSlide {
    let edge: SwipeEdge
    let width: CGFloat
    /// The tab leaving.
    let picture: UIView
    /// The tab arriving, once it is shown and drawn.
    private(set) var arriving: UIView?
    /// The tab bar controller's view's own subview that holds the shown tab; never moved.
    let content: UIView
    private weak var tabs: UITabBarController?
    /// The tab the swipe began on, by the tab bar controller's index.
    private let startIndex: Int
    private(set) var travel: CGFloat = 0
    /// When the arriving picture was taken; it is taken once more a moment later, for rows a
    /// list adds on the turn after it appears.
    private var arrivedAt: CFTimeInterval?
    private var isRetaken = false

    init?(tabBarController: UITabBarController, edge: SwipeEdge, width: CGFloat) {
        let root = tabBarController.view!
        guard width > 0, let shown = tabBarController.selectedViewController?.view,
              let content = Self.ancestor(of: shown, under: root),
              let picture = content.snapshotView(afterScreenUpdates: false)
        else { return nil }
        self.edge = edge
        self.width = width
        self.content = content
        self.picture = picture
        self.tabs = tabBarController
        self.startIndex = tabBarController.selectedIndex
        picture.frame = content.frame
        picture.isUserInteractionEnabled = false
        root.insertSubview(picture, aboveSubview: content)
    }

    /// The view directly under `root` that `view` is in.
    static func ancestor(of view: UIView, under root: UIView) -> UIView? {
        var candidate: UIView? = view
        while let current = candidate, current.superview !== root { candidate = current.superview }
        return candidate
    }

    /// Takes the arriving tab's picture once the tab bar controller shows it, and once more a
    /// moment later. Until the first, nothing moves: the leaving picture covers the screen.
    func takeArrivingPicture() {
        guard let tabs, tabs.selectedIndex != startIndex, let root = tabs.view else { return }
        let now = CACurrentMediaTime()
        if let arrivedAt {
            guard !isRetaken, now - arrivedAt > 0.15 else { return }
            isRetaken = true
        }
        guard let shot = content.snapshotView(afterScreenUpdates: true) else { return }
        shot.frame = content.frame
        shot.isUserInteractionEnabled = false
        if let old = arriving {
            root.insertSubview(shot, aboveSubview: old)
            old.removeFromSuperview()
        } else if edge == .left {
            root.insertSubview(shot, belowSubview: picture)
        } else {
            root.insertSubview(shot, aboveSubview: picture)
        }
        arriving = shot
        arrivedAt = arrivedAt ?? now
        move(travel: travel)
    }

    func move(travel: CGFloat) {
        self.travel = travel
        guard let arriving else { return }
        let drift = EdgeSwipe.underneathDrift
        switch edge {
        case .left:
            picture.transform = CGAffineTransform(translationX: travel, y: 0)
            arriving.transform = CGAffineTransform(translationX: (travel - width) * drift, y: 0)
        case .right:
            arriving.transform = CGAffineTransform(translationX: width - travel, y: 0)
            picture.transform = CGAffineTransform(translationX: -travel * drift, y: 0)
        }
    }

    /// Springs to the far side (`settles`) or back, carrying the finger's speed on.
    func finish(settles: Bool, speed: CGFloat, completion: @escaping @MainActor () -> Void) {
        takeArrivingPicture()
        let target = settles ? width : 0
        let distance = abs(target - travel)
        let velocity = distance > 1 ? abs(speed) / distance : 0
        UIView.animate(springDuration: 0.35, bounce: 0, initialSpringVelocity: velocity, delay: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.move(travel: target)
        } completion: { _ in
            completion()
        }
    }

    /// Stops a settle where it is, for a new swipe to begin.
    func stopMoving() {
        picture.layer.removeAllAnimations()
        arriving?.layer.removeAllAnimations()
    }

    /// Takes the pictures away, showing the live tab.
    func tearDown() {
        picture.removeFromSuperview()
        arriving?.removeFromSuperview()
    }

    /// Once the tab bar controller shows the tab the swipe began on again (a few frames at most),
    /// takes away the pictures that cover it.
    func tearDownWhenShowingStart(then done: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            for _ in 0..<12 {
                if tabs?.selectedIndex == startIndex { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
            // One more frame, so the tab has drawn.
            try? await Task.sleep(for: .milliseconds(16))
            tearDown()
            done()
        }
    }
}
#endif
