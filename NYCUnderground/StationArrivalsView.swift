import SwiftUI
import WidgetKit

/// Shows arrival times for a single station, grouped by direction.
struct StationArrivalsView: View {
    let station: Station
    let arrivals: [Arrival]

    @AppStorage(SharedDefaults.Key.pinnedStopId, store: SharedDefaults.store)
    private var pinnedStopId: String = ""

    private var isPinned: Bool { pinnedStopId == station.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Station name + route pills
            HStack(spacing: 6) {
                Text(station.name)
                    .font(.headline)
                Spacer()
                Button {
                    pinnedStopId = isPinned ? "" : station.id
                    WidgetCenter.shared.reloadTimelines(ofKind: "StationArrivalsWidget")
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isPinned ? .blue : .secondary)
                        .rotationEffect(.degrees(45))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPinned ? "Unpin from widget" : "Pin to widget")
                ForEach(station.routes, id: \.self) { route in
                    RoutePill(route: route, size: 20)
                }
            }

            if arrivals.isEmpty {
                Text("No upcoming trains")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Arrival.Direction.allCases, id: \.self) { direction in
                    let dirArrivals = arrivals
                        .filter { $0.direction == direction }
                        .prefix(4)

                    if !dirArrivals.isEmpty {
                        let firstArrival = dirArrivals.first!
                        let label = station.directionLabel(forStopId: firstArrival.stopId, direction: direction)
                        directionRow(label: label, arrivals: Array(dirArrivals))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func directionRow(label: String, arrivals: [Arrival]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                ForEach(arrivals) { arrival in
                    HStack(spacing: 3) {
                        RoutePill(route: arrival.routeId, size: 18)
                        Text(arrival.minutesAwayText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(arrival.minutesAway <= 1 ? .red : .primary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
                Spacer()
            }
        }
    }
}
