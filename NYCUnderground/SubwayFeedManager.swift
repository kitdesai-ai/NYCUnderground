import Foundation
import Combine
import WidgetKit

/// Polls MTA GTFS-RT feeds and provides real-time arrival data per station.
/// Follows the Swift 6.2 ObservableObject pattern with explicit objectWillChange.
class SubwayFeedManager: NSObject, ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    /// Arrivals keyed by parent stop_id, sorted by time.
    var arrivalsByStation: [String: [Arrival]] = [:] {
        willSet { objectWillChange.send() }
    }

    var isLoading: Bool = false {
        willSet { objectWillChange.send() }
    }

    var lastError: String? = nil {
        willSet { objectWillChange.send() }
    }

    // MARK: - Feed Configuration

    private static let feedURLs: [String: URL] = [
        "123456S": URL(string: "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs")!,
        "ACE": URL(string: "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-ace")!,
        "BDFM": URL(string: "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-bdfm")!,
        "G": URL(string: "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-g")!,
        "JZ": URL(string: "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-jz")!,
        "L": URL(string: "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-l")!,
        "NQRW": URL(string: "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-nqrw")!,
        "SI": URL(string: "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-si")!,
    ]

    private static let routeToFeed: [String: String] = [
        "1": "123456S", "2": "123456S", "3": "123456S",
        "4": "123456S", "5": "123456S", "6": "123456S",
        "7": "123456S", "S": "123456S", "GS": "123456S",
        "A": "ACE", "C": "ACE", "E": "ACE",
        "B": "BDFM", "D": "BDFM", "F": "BDFM", "M": "BDFM",
        "G": "G",
        "J": "JZ", "Z": "JZ",
        "L": "L",
        "N": "NQRW", "Q": "NQRW", "R": "NQRW", "W": "NQRW",
        "SI": "SI",
        "FS": "123456S",  // Franklin Av Shuttle
        "H": "ACE",       // Rockaway Shuttle (served by A train feed)
    ]

    private var pollTimer: Timer?
    private var activeStations: [Station] = []

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    // MARK: - Public API

    /// Start polling feeds relevant to the given stations every 30 seconds.
    func startPolling(forStations stations: [Station]) {
        activeStations = stations
        stopPolling()

        // Fetch immediately
        Task { @MainActor in
            await fetchArrivals()
        }

        // Then every 30 seconds
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.fetchArrivals()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Fetch arrivals for the active stations (or a one-off set).
    func fetchArrivals(forStations stations: [Station]? = nil) async {
        let targetStations = stations ?? activeStations
        guard !targetStations.isEmpty else { return }

        isLoading = true
        lastError = nil

        // Determine which feeds we need
        let feedKeys = Set(targetStations.flatMap { station in
            station.routes.compactMap { Self.routeToFeed[$0] }
        })

        // Collect all directional stop_ids we care about
        let allStopIds = Set(targetStations.flatMap(\.allDirectionalStopIds))

        // Fetch feeds concurrently
        var allArrivals = [Arrival]()
        var fetchError: String?

        await withTaskGroup(of: [Arrival]?.self) { group in
            for key in feedKeys {
                guard let url = Self.feedURLs[key] else { continue }
                group.addTask {
                    do {
                        let (data, _) = try await self.session.data(from: url)
                        let message = try GTFSRealtimeParser.parse(data)
                        return GTFSRealtimeParser.arrivals(from: message, forStopIds: allStopIds)
                    } catch {
                        print("⚠️ Feed \(key) failed: \(error.localizedDescription)")
                        return nil
                    }
                }
            }

            for await result in group {
                if let arrivals = result {
                    allArrivals.append(contentsOf: arrivals)
                } else {
                    fetchError = "Some feeds unavailable"
                }
            }
        }

        // Group arrivals by parent station
        var grouped = [String: [Arrival]]()
        for arrival in allArrivals {
            if let station = StationDatabase.station(forStopId: arrival.stopId) {
                grouped[station.id, default: []].append(arrival)
            }
        }
        // Sort each station's arrivals by time, bucketed to 30s with tripId
        // as a stable tiebreaker so near-simultaneous arrivals (both rounding
        // to "Now") don't visibly swap positions when GTFS-RT predictions jitter.
        for key in grouped.keys {
            grouped[key]?.sort { a, b in
                let aBucket = Int(a.arrivalTime.timeIntervalSince1970 / 30)
                let bBucket = Int(b.arrivalTime.timeIntervalSince1970 / 30)
                if aBucket != bBucket { return aBucket < bBucket }
                return a.tripId < b.tripId
            }
        }

        arrivalsByStation = grouped
        isLoading = false
        if allArrivals.isEmpty && fetchError != nil {
            lastError = fetchError
        }

        // Refresh the home-screen widget with the data we just fetched.
        // No-op when the widget extension isn't installed or when called from
        // inside the extension itself.
        WidgetCenter.shared.reloadTimelines(ofKind: "StationArrivalsWidget")
    }
}
