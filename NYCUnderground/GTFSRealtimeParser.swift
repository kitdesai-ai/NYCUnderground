import Foundation
import SwiftProtobuf

/// Parses MTA GTFS-RT protobuf data into Arrival objects.
struct GTFSRealtimeParser {

    /// Parse raw protobuf data into a FeedMessage.
    static func parse(_ data: Data) throws -> TransitRealtime_FeedMessage {
        try TransitRealtime_FeedMessage(serializedBytes: data)
    }

    /// Extract upcoming arrivals from a FeedMessage for a set of directional stop_ids.
    /// Only returns arrivals in the future (after `after`).
    static func arrivals(
        from message: TransitRealtime_FeedMessage,
        forStopIds stopIds: Set<String>,
        after: Date = Date()
    ) -> [Arrival] {
        var results = [Arrival]()
        let cutoff = after.timeIntervalSince1970

        for entity in message.entity {
            guard entity.hasTripUpdate else { continue }
            let tripUpdate = entity.tripUpdate
            let routeId = tripUpdate.trip.routeID
            let tripId = tripUpdate.trip.tripID

            for stopTime in tripUpdate.stopTimeUpdate {
                let stopId = stopTime.stopID
                guard stopIds.contains(stopId) else { continue }

                let arrivalTime: Double
                if stopTime.hasArrival, stopTime.arrival.time > 0 {
                    arrivalTime = Double(stopTime.arrival.time)
                } else if stopTime.hasDeparture, stopTime.departure.time > 0 {
                    arrivalTime = Double(stopTime.departure.time)
                } else {
                    continue
                }

                guard arrivalTime > cutoff else { continue }

                let direction: Arrival.Direction = stopId.hasSuffix("N") ? .uptown : .downtown

                results.append(Arrival(
                    id: "\(tripId)_\(stopId)",
                    routeId: routeId,
                    stopId: stopId,
                    direction: direction,
                    arrivalTime: Date(timeIntervalSince1970: arrivalTime),
                    tripId: tripId
                ))
            }
        }

        return results.sorted { $0.arrivalTime < $1.arrivalTime }
    }
}
