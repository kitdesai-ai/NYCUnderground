import Foundation

struct Arrival: Identifiable {
    let id: String              // tripId + stopId for uniqueness
    let routeId: String         // "A", "C", "E", etc.
    let stopId: String          // "A41N"
    let direction: Direction
    let arrivalTime: Date
    let tripId: String

    enum Direction: String, CaseIterable {
        case uptown     // N suffix
        case downtown   // S suffix

        var label: String {
            switch self {
            case .uptown: return "Uptown"
            case .downtown: return "Downtown"
            }
        }
    }

    var minutesAway: Int {
        max(0, Int(arrivalTime.timeIntervalSinceNow / 60))
    }

    var minutesAwayText: String {
        let mins = minutesAway
        if mins == 0 { return "Now" }
        return "\(mins) min"
    }
}
