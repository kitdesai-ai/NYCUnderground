import CoreLocation
import CoreGraphics

/// Loads and queries the bundled subway station database.
/// Provides lookup by stop_id, GPS proximity, and approximate map position.
struct StationDatabase {

    /// All subway stations, loaded once from bundled JSON.
    static let stations: [Station] = {
        guard let url = Bundle.main.url(forResource: "stops_subway", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let stations = try? JSONDecoder().decode([Station].self, from: data) else {
            print("❌ Failed to load stops_subway.json")
            return []
        }
        print("✅ Loaded \(stations.count) stations")
        return stations
    }()

    /// Lookup by primary stop_id.
    private static let byId: [String: Station] = {
        var map = [String: Station]()
        for station in stations {
            map[station.id] = station
            for altId in station.altIds {
                map[altId] = station
            }
        }
        return map
    }()

    /// Find a station by any of its stop_ids (with or without N/S suffix).
    static func station(forStopId stopId: String) -> Station? {
        // Strip N/S suffix
        let baseId = stopId.hasSuffix("N") || stopId.hasSuffix("S")
            ? String(stopId.dropLast())
            : stopId
        return byId[baseId]
    }

    /// Find the nearest N stations to a GPS coordinate.
    static func nearestStations(to coordinate: CLLocationCoordinate2D, count: Int = 5) -> [Station] {
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let sorted = stations
            .map { station -> (Station, Double) in
                let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
                return (station, userLocation.distance(from: stationLocation))
            }
            .sorted { $0.1 < $1.1 }

        return Array(sorted.prefix(count).map(\.0))
    }

    /// Get the normalized visual position for a station on the map.
    static func visualPosition(for station: Station) -> CGPoint? {
        stationVisualPositions[station.id]
    }

    /// Pre-indexed positions from offline OCR (station_positions.json).
    /// Maps station id → normalized {x, y} position of the station name text on the map.
    private static let ocrPositions: [String: CGPoint] = {
        guard let url = Bundle.main.url(forResource: "station_positions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: [String: Double]].self, from: data) else {
            print("⚠️ station_positions.json not found, using GPS-only positions")
            return [:]
        }
        var positions = [String: CGPoint]()
        for (id, coords) in dict {
            if let x = coords["x"], let y = coords["y"] {
                positions[id] = CGPoint(x: x, y: y)
            }
        }
        print("📍 Loaded \(positions.count) OCR-indexed station positions")
        return positions
    }()

    /// Pre-computed normalized visual positions for each station on the map.
    /// Prefers OCR-derived positions (actual text locations on the schematic map),
    /// falls back to GPS → pixel via CoordinateMapper for stations not found by OCR.
    private static let stationVisualPositions: [String: CGPoint] = {
        let refSize = CGSize(width: 1000, height: 1000)
        var positions = [String: CGPoint]()
        var ocrCount = 0
        var gpsCount = 0
        for station in stations {
            if let ocrPos = ocrPositions[station.id] {
                positions[station.id] = ocrPos
                ocrCount += 1
            } else {
                let coord = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
                if let pixel = CoordinateMapper.mapToImage(coordinate: coord, imageSize: refSize) {
                    positions[station.id] = CGPoint(x: pixel.x / refSize.width, y: pixel.y / refSize.height)
                    gpsCount += 1
                }
            }
        }
        print("📍 Station positions: \(ocrCount) from OCR, \(gpsCount) from GPS fallback")
        return positions
    }()

    /// Find stations near a normalized tap point on the map.
    /// Always returns the visually nearest station(s) using pre-computed positions.
    /// Includes clustered stations that are nearly as close.
    static func stations(nearNormalizedPoint point: CGPoint, imageSize: CGSize, zoomScale: CGFloat = 1.0, minZoomScale: CGFloat = 1.0) -> [Station] {
        var all: [(Station, CGFloat)] = []
        for station in stations {
            guard let visualPos = stationVisualPositions[station.id] else { continue }
            let dx = point.x - visualPos.x
            let dy = point.y - visualPos.y
            let distance = sqrt(dx * dx + dy * dy)
            all.append((station, distance))
        }
        all.sort { $0.1 < $1.1 }

        guard let closest = all.first else { return [] }

        // Skip if tap is very far from any station (empty area)
        guard closest.1 < 0.15 else { return [] }

        // Include any stations clustered near the closest (within 60% extra or 0.008 min)
        let clusterThreshold = max(closest.1 * 1.6, 0.008)
        let results = all.filter { $0.1 < clusterThreshold }.map(\.0)

        print("🔍 Tap (\(String(format: "%.3f", point.x)), \(String(format: "%.3f", point.y))) → \(results.map(\.name).joined(separator: ", ")) (dist=\(String(format: "%.4f", closest.1)))")
        return results
    }
}
