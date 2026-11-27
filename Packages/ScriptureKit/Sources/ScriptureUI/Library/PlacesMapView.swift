import MapKit
import ScriptureData
import SwiftUI

/// Apple's map in the muted standard style: one marker to a pin, in the accent; a gathered pin shows its count.
///
/// It opens at `framing`'s frame. The markers never merge or split as the map zooms: a pin is the data's own
/// point, gathered once (`BookPlaces.pins`). A click on a marker writes its pin's id to `selection`,
/// a click on the map itself writes nil. A shared pin takes the chosen place's name, and the chosen pin is
/// drawn last so its balloon sits above its neighbours. MapKit draws every marker's title beneath every balloon, so in
/// a crowded cluster the chosen title was hidden (call 32): the chosen name is the app's own label instead
/// (`PlacesMapLabel`, laid over the map under the pin's point by `MapReader`'s projection, so above every marker), and
/// the chosen marker's system title is hidden so the name is not drawn twice; the others' titles are MapKit's to show or drop. Under a chapter the
/// book's other points are `dots`: small, untitled, not choosable and hidden from VoiceOver, drawn first with the map's
/// own content.
///
/// The camera: a change of `framing` (a chapter chosen or cleared) moves to the new frame, holding `focus`
/// in view at the frame's zoom; when `focus` becomes a pin outside the region in view (a choice in the
/// list), or within a marker's height of its edge, the camera moves to hold it at the same zoom. Each move
/// is `.smooth` and a cut under Reduce Motion, and each waits one turn of the main run loop under a
/// generation (`PlacesCameraQueue`), so steps in quick succession move the camera once, to the last.
/// The region is judged at the map's size now: Places halves the map as a place is chosen, and MapKit
/// reports the new region only after that resize, so the last region reported is scaled to the new size,
/// and the rule is asked again when the size changes.
///
/// On the phone the sheet covers the foot of the map by `bottomCover` (as settled at a detent): a pin under it is
/// out of view, and is moved to the middle of the part above it; a chapter is framed into that part. The sheet is never
/// taller than half the page (`PlacesSheet`), so that part always has room; were it shorter than two marker clearances,
/// nothing would pan and a chapter would be framed as with no sheet, and again once the sheet settled lower. A chapter
/// the map opens at (kept on coming back from a lookup) is framed again once the sheet first settles. The region is judged as MapKit reports it, for the whole map (Departure 17).
///
/// MapKit reports no click on a marker already selected, so a tap is also read through `MapReader`: one on
/// the chosen marker's balloon while one of its several places is chosen calls `onReopen` a turn later
/// (the caller acts only if the map still has that pin). Without a connection the tiles are blank and the
/// markers still work. VoiceOver reads a marker by its title alone ("Jerusalem"): MapKit's marker takes no
/// label of SwiftUI's, so the count is heard on the gathered pin's rows under the map ("7 places here"). The drawn
/// label is hidden from VoiceOver, so the chosen place is heard once, from its marker.
public struct PlacesMapView: View {
    let pins: [BookPlaces.Pin]
    let dots: [BookPlaces.Pin]
    let framing: PlacesFraming
    let chosenPlaceID: Int?
    @Binding var selection: String?
    let focus: BookPlaces.Pin?
    let onReopen: (() -> Void)?
    /// How much of the map's foot the phone's sheet covers, in points; 0 on the Mac.
    let bottomCover: CGFloat

    @State private var position: MapCameraPosition
    /// The region in view, kept from the camera's moves, and the map's size when it was reported.
    @State private var region: MKCoordinateRegion?
    @State private var reportedSize: CGSize = .zero
    @State private var size: CGSize = .zero
    /// The framing the camera last moved to, and the generation of the move waiting to run.
    @State private var framedAt: PlacesFraming
    @State private var cameraQueue = PlacesCameraQueue()
    /// The camera as it moves, frame by frame, for the chosen label alone.
    @State private var camera = PlacesMapCamera()
    /// The last framing was made while the sheet left no room above it (the chapter the map opened at before the sheet
    /// settled), so it is made again once the sheet settles with room.
    @State private var framedWithoutRoom: Bool
    /// How far in from an edge a pin must sit for its marker (balloon and title) to show whole.
    @ScaledMetric(relativeTo: .body) private var markerClearance: CGFloat = 44
    /// A dot of the book's other places: about `xxs` across, with the text.
    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = AppSpacing.xxs
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(pins: [BookPlaces.Pin], dots: [BookPlaces.Pin] = [], framing: PlacesFraming, chosenPlaceID: Int? = nil,
                selection: Binding<String?>, focus: BookPlaces.Pin?, onReopen: (() -> Void)? = nil,
                bottomCover: CGFloat = 0) {
        self.pins = pins
        self.dots = dots
        self.framing = framing
        self.chosenPlaceID = chosenPlaceID
        self._selection = selection
        self.focus = focus
        self.onReopen = onReopen
        self.bottomCover = bottomCover
        let region = framing.frame.map(Self.region(_:))
        self._position = State(initialValue: region.map { .region($0) } ?? .automatic)
        self._region = State(initialValue: region)
        self._framedAt = State(initialValue: framing)
        self._framedWithoutRoom = State(initialValue: Self.opensWithoutRoom(framing))
    }

    public var body: some View {
        MapReader { proxy in
            Map(position: $position, selection: $selection) {
                ForEach(dots) { dot in
                    Annotation(coordinate: coordinate(dot), anchor: .center) {
                        Circle()
                            .fill(Color.inkTertiary)
                            .frame(width: dotSize, height: dotSize)
                            .mapDecoration()
                    } label: {
                        EmptyView()
                    }
                }
                // The pin's id stays its identity, so a new title or place in the order rebuilds no marker.
                ForEach(Self.drawOrder(pins, chosen: selection)) { pin in
                    marker(pin)
                        .tint(Color.accent)
                        .annotationTitles(Self.titleVisibility(of: pin.id, chosen: selection))
                        .tag(pin.id)
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            // Over the map, not in it: MapKit draws an annotation of the app's beneath its southern neighbours' balloons
            // (seen in Joshua), so the chosen name is placed by the map's own projection and moved with every camera change.
            .overlay {
                if let label = Self.chosenLabel(pins, chosen: selection, placeID: chosenPlaceID) {
                    PlacesMapLabelOverlay(label: label, proxy: proxy, camera: camera)
                }
            }
            .simultaneousGesture(SpatialTapGesture().onEnded { tap in reopenIfOnChosenMarker(tap.location, proxy: proxy) },
                                 including: Self.reopenTapMask(reopening: onReopen != nil))
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { newSize in
            size = newSize
            requestMove()
        }
        .onMapCameraChange { context in
            region = context.region
            reportedSize = size
        }
        // Read only by the chosen label's overlay, so the map's own content is not rebuilt on every frame of a move.
        .onMapCameraChange(frequency: .continuous) { context in camera.region = context.region }
        .onChange(of: focus?.id, initial: true) { requestMove() }
        .onChange(of: framing) { requestMove() }
        .onChange(of: bottomCover) { requestMove() }
    }

    private func coordinate(_ pin: BookPlaces.Pin) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
    }

    @MapContentBuilder private func marker(_ pin: BookPlaces.Pin) -> some MapContent {
        let title = pin.title(choosing: chosenPlaceID)
        if pin.places.count > 1 {
            Marker(title, monogram: Text(pin.places.count, format: .number), coordinate: coordinate(pin))
        } else {
            Marker(title, coordinate: coordinate(pin))
        }
    }

    // MARK: - The camera

    /// Asks for a move a turn from now; a later request in the meantime takes its place.
    private func requestMove() {
        let generation = cameraQueue.request()
        DispatchQueue.main.async {
            guard cameraQueue.isCurrent(generation) else { return }
            move()
        }
    }

    /// To the new framing when it changed (the chapter's frame, `focus` held in it), or when it was made with no room
    /// above the sheet and there is room now; else to hold `focus`.
    private func move() {
        let hasRoom = Self.canReveal(size: size, bottomCover: bottomCover, inset: markerClearance)
        guard Self.reframes(changed: framing != framedAt, framedWithoutRoom: framedWithoutRoom, bottomCover: bottomCover,
                            hasRoom: hasRoom) else {
            reveal(focus)
            return
        }
        framedAt = framing
        framedWithoutRoom = bottomCover > 0 && !hasRoom
        guard let frame = framing.frame else { return }
        let framed = Self.framed(frame, size: size, holding: focus, inset: markerClearance, bottomCover: bottomCover)
        // Until MapKit reports the move's end, a later reveal judges against where the camera is going.
        region = framed
        reportedSize = size
        withAnimation(reduceMotion ? nil : .smooth) {
            position = .region(framed)
        }
    }

    private func reveal(_ pin: BookPlaces.Pin?) {
        guard let pin, let region, Self.canReveal(size: size, bottomCover: bottomCover, inset: markerClearance) else { return }
        let visible = Self.visibleRegion(region, reportedAt: reportedSize, now: size)
        guard let moved = Self.region(visible, size: size, holding: pin, inset: markerClearance, bottomCover: bottomCover) else { return }
        withAnimation(reduceMotion ? nil : .smooth) {
            position = .region(moved)
        }
    }

    // MARK: - The re-click

    /// A tap on the chosen marker while one of its several places is chosen: `onReopen`, a turn later, so a
    /// click MapKit gives to a neighbour has been written first.
    private func reopenIfOnChosenMarker(_ tap: CGPoint, proxy: MapProxy) {
        guard let onReopen, chosenPlaceID != nil, let id = selection,
              let pin = pins.first(where: { $0.id == id }), pin.places.count > 1,
              let point = proxy.convert(coordinate(pin), to: .local),
              Self.isOnChosenMarker(tap, pinPoint: point, clearance: markerClearance) else { return }
        DispatchQueue.main.async { onReopen() }
    }

    // MARK: - The rules

    /// Where the re-click's tap runs: beside the map's own gestures when there is `onReopen`; with none,
    /// only the map's own (`.subviews`; `.none` would turn the map's taps and pans off too).
    nonisolated static func reopenTapMask(reopening: Bool) -> GestureMask {
        reopening ? .all : .subviews
    }

    /// The pins as drawn: the chosen one last, so its marker and title sit above its neighbours; the rest in order.
    nonisolated static func drawOrder(_ pins: [BookPlaces.Pin], chosen pinID: String?) -> [BookPlaces.Pin] {
        guard let pinID, let chosen = pins.first(where: { $0.id == pinID }) else { return pins }
        return pins.filter { $0.id != pinID } + [chosen]
    }

    /// The chosen pin's system title is hidden, since the drawn label carries its name above every balloon (MapKit drew
    /// it beneath its neighbours' in a dense cluster: Joshua's Jordan); every other pin's title is MapKit's to show or drop.
    nonisolated static func titleVisibility(of pinID: String, chosen: String?) -> Visibility {
        pinID == chosen ? .hidden : .automatic
    }

    /// The chosen pin's drawn label: its point and its title for the chosen place (a gathered pin's chosen place, else its
    /// own title); none while no pin the map draws is chosen.
    nonisolated static func chosenLabel(_ pins: [BookPlaces.Pin], chosen pinID: String?, placeID: Int?) -> ChosenLabel? {
        guard let pinID, let pin = pins.first(where: { $0.id == pinID }) else { return nil }
        return ChosenLabel(id: pin.id, name: pin.title(choosing: placeID), latitude: pin.latitude, longitude: pin.longitude)
    }

    /// What the drawn label shows, and where.
    struct ChosenLabel: Equatable {
        let id: String
        let name: String
        let latitude: Double, longitude: Double
    }

    /// A tap inside the chosen marker's balloon: a clearance high above its point and a clearance wide.
    nonisolated static func isOnChosenMarker(_ tap: CGPoint, pinPoint: CGPoint, clearance: CGFloat) -> Bool {
        abs(tap.x - pinPoint.x) <= clearance / 2 && tap.y >= pinPoint.y - clearance && tap.y <= pinPoint.y
    }

    /// A chapter's frame, or, when `focus` would be out of it at `size`, the frame's zoom centred on `focus`.
    /// Under a sheet covering `bottomCover` points of the map's foot, the frame is fitted into the part above it: its
    /// latitude span grown by `height / (height - bottomCover)` and its centre lowered so the frame's centre sits
    /// mid-way down that part. Where that part has no room for a marker (`canReveal`), it is framed as with no sheet.
    nonisolated static func framed(_ frame: BookPlaces.Frame, size: CGSize, holding focus: BookPlaces.Pin?,
                                   inset: CGFloat, bottomCover: CGFloat = 0) -> MKCoordinateRegion {
        let cover = bottomCover > 0 && canReveal(size: size, bottomCover: bottomCover, inset: inset) ? bottomCover : 0
        var framed = region(frame)
        if cover > 0 {
            // MapKit shows at least the longitude asked for, so a wide frame is shown taller than its latitude asks;
            // the centre is lowered by the latitude MapKit will show, so a wide chapter also sits clear of the sheet.
            let grown = frame.latitudeSpan * size.height / (size.height - cover)
            let shownByWidth = size.width > 0
                ? frame.longitudeSpan * cos(frame.latitude * .pi / 180) * size.height / size.width : 0
            let span = max(grown, shownByWidth)
            framed.span.latitudeDelta = span
            framed.center.latitude = frame.latitude - span * cover / (2 * size.height)
        }
        guard let focus else { return framed }
        return region(framed, size: size, holding: focus, inset: inset, bottomCover: cover) ?? framed
    }

    /// Whether the camera frames again: on a new framing, or when the last was made with no room above the phone's
    /// sheet and a settled sheet now leaves room. With no sheet (the Mac, or the phone before its sheet settles) only a
    /// new framing does.
    nonisolated static func reframes(changed: Bool, framedWithoutRoom: Bool, bottomCover: CGFloat, hasRoom: Bool) -> Bool {
        changed || (framedWithoutRoom && bottomCover > 0 && hasRoom)
    }

    /// The map opens at its framing before the phone's sheet settles: a chapter (one kept on coming back from a lookup)
    /// is framed again above the sheet once it does; the book's own frame is not, since nothing was chosen.
    nonisolated static func opensWithoutRoom(_ framing: PlacesFraming) -> Bool {
        framing.chapter != nil
    }

    /// Whether the part of the map above the sheet can hold a marker clear of both its edges; under a sheet of at most
    /// half the page it always can (the large detent, where it could not, is gone).
    nonisolated static func canReveal(size: CGSize, bottomCover: CGFloat, inset: CGFloat) -> Bool {
        size.height - bottomCover > 2 * inset
    }

    nonisolated static func region(_ frame: BookPlaces.Frame) -> MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: frame.latitude, longitude: frame.longitude),
                           span: MKCoordinateSpan(latitudeDelta: frame.latitudeSpan, longitudeDelta: frame.longitudeSpan))
    }

    /// The region a map shows at `size` that showed `region` at `reportedAt`: MapKit keeps the centre
    /// and the zoom as the view resizes, so each span scales with its side. Unchanged until a size is known.
    nonisolated static func visibleRegion(_ region: MKCoordinateRegion, reportedAt: CGSize, now size: CGSize) -> MKCoordinateRegion {
        guard reportedAt.width > 0, reportedAt.height > 0, size.width > 0, size.height > 0 else { return region }
        return MKCoordinateRegion(center: region.center, span: MKCoordinateSpan(
            latitudeDelta: region.span.latitudeDelta * size.height / reportedAt.height,
            longitudeDelta: region.span.longitudeDelta * size.width / reportedAt.width))
    }

    /// The region at the same zoom with `pin` in the middle of the part in view when `pin` is outside `region`
    /// shown at `size`, or within `inset` points of its edge; nil when it is in view. The part in view runs from
    /// `inset` below the top to `bottomCover + inset` above the foot, the foot being under the phone's sheet, so
    /// the moved centre sits `span × bottomCover / (2 × height)` below the pin (Departure 17).
    nonisolated static func region(_ region: MKCoordinateRegion, size: CGSize, holding pin: BookPlaces.Pin,
                                   inset: CGFloat, bottomCover: CGFloat = 0) -> MKCoordinateRegion? {
        let insetLatitude = size.height > 0 ? region.span.latitudeDelta * inset / size.height : 0
        let coverLatitude = size.height > 0 ? region.span.latitudeDelta * bottomCover / size.height : 0
        let insetLongitude = size.width > 0 ? region.span.longitudeDelta * inset / size.width : 0
        let middle = region.center.latitude + coverLatitude / 2
        let halfHeight = max((region.span.latitudeDelta - coverLatitude) / 2 - insetLatitude, 0)
        let inView = abs(pin.latitude - middle) <= halfHeight
            && abs(pin.longitude - region.center.longitude) <= max(region.span.longitudeDelta / 2 - insetLongitude, 0)
        guard !inView else { return nil }
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: pin.latitude - coverLatitude / 2, longitude: pin.longitude),
                                  span: region.span)
    }
}

/// The camera's moves, coalesced: each request takes a new generation, and only the latest may run.
struct PlacesCameraQueue: Equatable {
    private var generation = 0

    mutating func request() -> Int {
        generation += 1
        return generation
    }

    func isCurrent(_ generation: Int) -> Bool { generation == self.generation }
}

/// The chosen place's name on the map (Matt's review, 2026-11-24; call 32): drawn by the app under the pin's point,
/// where MapKit puts a title, and above every balloon in a crowded cluster. The app's voice for chrome
/// (SF Pro, `.caption` semibold, `ink.primary`) on a plate of `paper.page` at radius `sm`, just large enough to keep the
/// name legible over the tiles: no stroke, no shadow, no card. The plate follows Dark and Sepia as the page does.
struct PlacesMapLabel: View {
    let name: String

    @ScaledMetric(relativeTo: .caption) private var horizontal: CGFloat = AppSpacing.xs
    @ScaledMetric(relativeTo: .caption) private var vertical: CGFloat = AppSpacing.xxs
    /// The gap between the pin's point and the plate, as MapKit leaves under a marker.
    @ScaledMetric(relativeTo: .caption) private var gap: CGFloat = AppSpacing.xxs

    var body: some View {
        Text(name)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.inkPrimary)
            .lineLimit(1)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(Color.paperPage, in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
            .padding(.top, gap)
    }
}

/// The map's camera while it moves, kept apart from the map's view so that only the chosen label reads it.
@Observable @MainActor final class PlacesMapCamera {
    var region: MKCoordinateRegion?
}

/// The chosen label laid over the map at the pin's point: the plate's top a gap under the point, centred on it, moved
/// with the camera (it reads `camera` so each frame of a move places it again). Clipped to the map, never takes a tap,
/// and hidden from VoiceOver, which hears the place once, from its marker.
struct PlacesMapLabelOverlay: View {
    let label: PlacesMapView.ChosenLabel
    let proxy: MapProxy
    let camera: PlacesMapCamera

    var body: some View {
        _ = camera.region
        let point = proxy.convert(CLLocationCoordinate2D(latitude: label.latitude, longitude: label.longitude), to: .local)
        return ZStack(alignment: .topLeading) {
            Color.clear
            if let point {
                // The plate's centre on the point's x, its top on the point's y.
                PlacesMapLabel(name: label.name)
                    .fixedSize()
                    .alignmentGuide(.leading) { $0[HorizontalAlignment.center] - point.x }
                    .alignmentGuide(.top) { $0[.top] - point.y }
            }
        }
        .clipped()
        .mapDecoration()
    }
}

extension View {
    /// Drawn on the map for the eye alone (a chapter's dot, the chosen place's label): never takes a tap, and hidden from
    /// VoiceOver, which hears the place from its marker.
    func mapDecoration() -> some View {
        allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
