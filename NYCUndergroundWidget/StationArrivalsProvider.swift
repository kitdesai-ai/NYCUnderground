import WidgetKit
import CoreLocation
import Foundation

struct StationArrivalsEntry: TimelineEntry {
    enum Source { case location, pinned, placeholder }

    let date: Date
    let station: Station?
    let arrivals: [Arrival]
    let fetchedAt: Date
    let source: Source
}

/// Timeline provider that finds the user's nearest station (or a pinned fallback)
/// and fetches live GTFS-RT arrivals for it.
final class StationArrivalsProvider: NSObject, TimelineProvider, CLLocationManagerDelegate {
    typealias Entry = StationArrivalsEntry

    // CRITICAL: must be a stored property on the provider itself, NOT scoped to
    // the timeline call. Apple's CoreLocation requires the manager to outlive
    // the request — see https://developer.apple.com/forums/thread/654678
    private let locationManager: CLLocationManager
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        self.locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - TimelineProvider

    func placeholder(in context: Context) -> StationArrivalsEntry {
        StationArrivalsEntry(
            date: Date(),
            station: nil,
            arrivals: [],
            fetchedAt: Date(),
            source: .placeholder
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StationArrivalsEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StationArrivalsEntry>) -> Void) {
        Task {
            let entry = await buildEntry()
            // Emit one entry now, plus 4 future entries every 2 minutes so
            // displayed minutes count down between server refreshes.
            let now = entry.date
            var entries: [StationArrivalsEntry] = [entry]
            for offset in 1...4 {
                let future = StationArrivalsEntry(
                    date: now.addingTimeInterval(TimeInterval(offset * 120)),
                    station: entry.station,
                    arrivals: entry.arrivals,
                    fetchedAt: entry.fetchedAt,
                    source: entry.source
                )
                entries.append(future)
            }

            // Reload sooner if we're showing placeholder (so a freshly-pinned
            // station picks up faster); otherwise stick to the 15-minute budget.
            let nextReload = entry.source == .placeholder
                ? now.addingTimeInterval(60 * 5)
                : now.addingTimeInterval(60 * 15)
            completion(Timeline(entries: entries, policy: .after(nextReload)))
        }
    }

    // MARK: - Entry construction

    private func buildEntry() async -> StationArrivalsEntry {
        let now = Date()
        let station = await resolveStation()

        guard let station else {
            return StationArrivalsEntry(
                date: now,
                station: nil,
                arrivals: [],
                fetchedAt: now,
                source: .placeholder
            )
        }

        let manager = await SubwayFeedManager()
        await manager.fetchArrivals(forStations: [station])
        let arrivals = await manager.arrivalsByStation[station.id] ?? []

        let source: StationArrivalsEntry.Source =
            (SharedDefaults.pinnedStopId == station.id) ? .pinned : .location

        return StationArrivalsEntry(
            date: now,
            station: station,
            arrivals: arrivals,
            fetchedAt: now,
            source: source
        )
    }

    /// Try live location first, then pinned-station fallback, then nil.
    private func resolveStation() async -> Station? {
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if let location = await currentLocation() {
                if let nearest = StationDatabase.nearestStations(to: location.coordinate, count: 1).first {
                    return nearest
                }
            }
        }

        // Fallback 1: the station the user explicitly pinned.
        if let stopId = SharedDefaults.pinnedStopId,
           let pinned = StationDatabase.station(forStopId: stopId) {
            return pinned
        }

        // Fallback 2: last-known location cached by the app. This is what keeps
        // the widget alive after the "When In Use" grace window expires and a live
        // fix is no longer available. Arrivals for the resolved station are still
        // fetched live in buildEntry().
        if let cached = SharedDefaults.cachedLocation {
            let coord = CLLocationCoordinate2D(latitude: cached.latitude, longitude: cached.longitude)
            if let nearest = StationDatabase.nearestStations(to: coord, count: 1).first {
                return nearest
            }
        }

        return nil
    }

    /// One-shot location request with a 4-second timeout so we never hang the
    /// timeline build.
    private func currentLocation() async -> CLLocation? {
        await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
            self.locationContinuation = continuation
            locationManager.requestLocation()

            // Soft timeout
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if let pending = self.locationContinuation {
                    self.locationContinuation = nil
                    pending.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(returning: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(returning: nil)
    }
}
