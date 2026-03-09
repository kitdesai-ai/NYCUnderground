import Foundation

struct Station: Identifiable, Codable, Hashable {
    let id: String              // primary GTFS stop_id, e.g. "A41"
    let altIds: [String]        // alternate stop_ids for same complex, e.g. ["R29"]
    let name: String            // e.g. "Jay St-MetroTech"
    let latitude: Double
    let longitude: Double
    let routes: [String]        // e.g. ["A", "C", "F", "N", "R", "W"]

    /// All stop_ids (primary + alternates) with N/S suffixes for GTFS-RT matching.
    var allDirectionalStopIds: Set<String> {
        var ids = Set<String>()
        for baseId in [id] + altIds {
            ids.insert(baseId + "N")
            ids.insert(baseId + "S")
        }
        return ids
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Station, rhs: Station) -> Bool {
        lhs.id == rhs.id
    }
}
