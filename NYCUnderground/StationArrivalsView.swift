import SwiftUI
import WidgetKit

/// Shows arrival times for a single station, grouped by direction.
struct StationArrivalsView: View {
    let station: Station
    let arrivals: [Arrival]
    /// When true (single-station sheet), each direction's times scroll
    /// horizontally so more upcoming trains are reachable. In multi-station
    /// lists this stays false and only the first few times are shown.
    var scrollableArrivals: Bool = false

    @AppStorage(SharedDefaults.Key.pinnedStopId, store: SharedDefaults.store)
    private var pinnedStopId: String = ""

    private var isPinned: Bool { pinnedStopId == station.id }

    var body: some View {
        VStack(alignment: .leading, spacing: scrollableArrivals ? 18 : 10) {
            // Station name + route pills
            HStack(spacing: 6) {
                Text(station.name)
                    .font(scrollableArrivals ? .title3.bold() : .headline)
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
                        .prefix(scrollableArrivals ? 12 : 4)

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
        VStack(alignment: .leading, spacing: scrollableArrivals ? 8 : 4) {
            Text(label)
                .font(scrollableArrivals ? .footnote : .caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            if scrollableArrivals {
                // Single-station sheet: scroll horizontally for more trains.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(arrivals) { arrivalChip(for: $0) }
                    }
                }
            } else {
                // Multi-station lists: static row, first few times only.
                HStack(spacing: 8) {
                    ForEach(arrivals) { arrivalChip(for: $0) }
                    Spacer()
                }
            }
        }
    }

    private func arrivalChip(for arrival: Arrival) -> some View {
        HStack(spacing: scrollableArrivals ? 5 : 3) {
            RoutePill(route: arrival.routeId, size: scrollableArrivals ? 20 : 18)
            Text(arrival.minutesAwayText)
                .font(.system(size: scrollableArrivals ? 15 : 13, weight: .medium))
                .foregroundColor(arrival.minutesAway <= 1 ? .red : .primary)
        }
        .padding(.horizontal, scrollableArrivals ? 10 : 6)
        .padding(.vertical, scrollableArrivals ? 7 : 3)
        .background(Color(.systemGray6))
        .cornerRadius(scrollableArrivals ? 8 : 6)
    }
}
