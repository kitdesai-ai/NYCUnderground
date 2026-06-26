import SwiftUI
import WidgetKit

struct StationArrivalsWidgetView: View {
    let entry: StationArrivalsEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular: AccessoryRectangularView(entry: entry)
        case .systemMedium:         MediumView(entry: entry)
        default:                    SmallView(entry: entry)
        }
    }

    static func deepLinkURL(for station: Station?) -> URL? {
        guard let id = station?.id else { return URL(string: "nycunderground://") }
        return URL(string: "nycunderground://station/\(id)")
    }
}

// MARK: - Small (1 station, top 2-3 arrivals)

private struct SmallView: View {
    let entry: StationArrivalsEntry

    var body: some View {
        Group {
            if let station = entry.station {
                let top = entry.arrivals.prefix(4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Divider().padding(.vertical, 1)

                    if top.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No live data right now")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Tap to refresh in app")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(top), id: \.id) { arrival in
                            HStack(spacing: 6) {
                                RoutePill(route: arrival.routeId, size: 18)
                                Text(station.directionLabel(forStopId: arrival.stopId, direction: arrival.direction))
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .minimumScaleFactor(0.85)
                                Spacer(minLength: 0)
                                Text(arrival.minutesAwayShort)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(arrival.minutesAway <= 1 ? .red : .primary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        }
                    }

                    Text("as of \(entry.fetchedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            } else {
                PlaceholderView()
            }
        }
        .widgetURL(StationArrivalsWidgetView.deepLinkURL(for: entry.station))
    }
}

// MARK: - Medium (1 station, both directions)

private struct MediumView: View {
    let entry: StationArrivalsEntry

    var body: some View {
        Group {
            if let station = entry.station {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(station.name)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        Text("as of \(entry.fetchedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    HStack(alignment: .top, spacing: 10) {
                        directionColumn(station: station, direction: .uptown)
                        Divider()
                        directionColumn(station: station, direction: .downtown)
                    }
                    .frame(maxHeight: .infinity)
                }
            } else {
                PlaceholderView()
            }
        }
    }

    private func directionColumn(station: Station, direction: Arrival.Direction) -> some View {
        let dirArrivals = entry.arrivals.filter { $0.direction == direction }.prefix(4)
        let label = dirArrivals.first.map {
            station.directionLabel(forStopId: $0.stopId, direction: direction)
        } ?? (direction == .uptown ? "Uptown" : "Downtown")

        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .lineLimit(1)

            if dirArrivals.isEmpty {
                Text("—")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(dirArrivals), id: \.id) { arrival in
                    Link(destination: StationArrivalsWidgetView.deepLinkURL(for: station)!) {
                        HStack(spacing: 4) {
                            RoutePill(route: arrival.routeId, size: 16)
                            Text(arrival.minutesAwayShort)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(arrival.minutesAway <= 1 ? .red : .primary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Lock screen accessory

private struct AccessoryRectangularView: View {
    let entry: StationArrivalsEntry

    var body: some View {
        Group {
            if let station = entry.station, let top = entry.arrivals.first {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        RoutePill(route: top.routeId, size: 14)
                            .widgetAccentable()
                        Text(top.minutesAwayShort)
                            .font(.system(size: 14, weight: .semibold))
                            .widgetAccentable()
                    }
                    Text(station.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            } else if let station = entry.station {
                Text("\(station.name) · no trains")
                    .font(.system(size: 11))
                    .lineLimit(2)
            } else {
                Text("Pin a station in NYC Underground")
                    .font(.system(size: 11))
                    .lineLimit(2)
            }
        }
        .widgetURL(StationArrivalsWidgetView.deepLinkURL(for: entry.station))
    }
}

// MARK: - Placeholder when no station resolved

private struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "pin")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            Text("Pin a station")
                .font(.system(size: 12, weight: .semibold))
            Text("Open NYC Underground and tap the pin icon on any station.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "nycunderground://"))
    }
}
