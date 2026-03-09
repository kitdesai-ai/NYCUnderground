import SwiftUI

/// Bottom sheet showing nearby stations with real-time arrival times.
struct NearbyStationsSheet: View {
    let stations: [Station]
    let arrivalsByStation: [String: [Arrival]]
    let isLoading: Bool
    let error: String?
    var onStationTap: ((Station) -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if stations.isEmpty {
                    ContentUnavailableView(
                        "No Stations Found",
                        systemImage: "tram",
                        description: Text("Move closer to a subway station.")
                    )
                } else {
                    List {
                        ForEach(stations) { station in
                            StationArrivalsView(
                                station: station,
                                arrivals: arrivalsByStation[station.id] ?? []
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { onStationTap?(station) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Nearby Stations")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if isLoading && arrivalsByStation.isEmpty {
                    ProgressView("Loading arrivals...")
                }
                if let error, !isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
