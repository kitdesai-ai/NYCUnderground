import Foundation

struct Station: Identifiable, Codable, Hashable {
    let id: String              // primary GTFS stop_id, e.g. "A41"
    let altIds: [String]        // alternate stop_ids for same complex, e.g. ["R29"]
    let name: String            // e.g. "Jay St-MetroTech"
    let latitude: Double
    let longitude: Double
    let routes: [String]        // e.g. ["A", "C", "F", "N", "R", "W"]

    /// Per-stop direction labels from MTA Stations.csv, keyed by GTFS stop_id.
    /// e.g. {"A41": {"north": "Manhattan", "south": "Euclid - Lefferts..."}}
    let directionLabels: [String: DirectionLabel]?

    struct DirectionLabel: Codable, Hashable {
        let north: String
        let south: String
    }

    /// All stop_ids (primary + alternates) with N/S suffixes for GTFS-RT matching.
    var allDirectionalStopIds: Set<String> {
        var ids = Set<String>()
        for baseId in [id] + altIds {
            ids.insert(baseId + "N")
            ids.insert(baseId + "S")
        }
        return ids
    }

    /// Get the direction label for a given stop_id and direction.
    /// Falls back to generic "Uptown"/"Downtown" if not available.
    func directionLabel(forStopId stopId: String, direction: Arrival.Direction) -> String {
        let baseId = stopId.hasSuffix("N") || stopId.hasSuffix("S")
            ? String(stopId.dropLast()) : stopId
        if let label = directionLabels?[baseId] {
            return direction == .uptown ? label.north : label.south
        }
        // Try primary stop's label as fallback
        if let label = directionLabels?[id] {
            return direction == .uptown ? label.north : label.south
        }
        return direction == .uptown ? "Uptown" : "Downtown"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Station, rhs: Station) -> Bool {
        lhs.id == rhs.id
    }
}
