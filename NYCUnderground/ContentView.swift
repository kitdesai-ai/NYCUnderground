import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var feedManager = SubwayFeedManager()
    @State private var showLocationBanner = true
    @State private var showNearbySheet = false
    @State private var selectedStation: Station? = nil
    @State private var tappedStations: [Station] = []
    @State private var nearbyStations: [Station] = []
    /// Measured height of the single-station sheet's content, used as its detent
    /// so the sheet hugs the content (no dead space at the bottom).
    @State private var stationSheetHeight: CGFloat = 300

    // Calibration state
    @State private var calibrationTapPoint: CGPoint? = nil
    @State private var calibrationCandidates: [Station] = []

    /// Set to true to enable calibration mode: tap stations to log normalized coordinates.
    private let calibrationMode = false

    var body: some View {
        ZoomableMapView(
            userLocation: locationManager.location,
            calibrationMode: calibrationMode,
            onStationsTapped: { stations in
                if stations.count == 1 {
                    selectedStation = stations[0]
                } else {
                    tappedStations = stations
                    feedManager.startPolling(forStations: stations)
                }
            },
            onCalibrationTap: { point in
                calibrationTapPoint = point
                // Use reverse mapping to suggest candidate stations
                if let approxCoord = CoordinateMapper.imageToCoordinate(
                    normalizedX: Double(point.x),
                    normalizedY: Double(point.y)
                ) {
                    calibrationCandidates = StationDatabase.nearestStations(
                        to: approxCoord, count: 10
                    )
                }
            }
        )
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                // Location permission prompt
                if locationManager.authorizationStatus == .notDetermined {
                    locationPrompt
                }

                // Floating location banner
                if showLocationBanner, let location = locationManager.location {
                    locationBanner(for: location.coordinate)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .overlay {
            if isMapMissing {
                pdfMissingOverlay
            }
        }
        .onAppear {
            if locationManager.authorizationStatus == .authorizedWhenInUse ||
               locationManager.authorizationStatus == .authorizedAlways {
                locationManager.startUpdating()
            }
        }
        .onChange(of: locationManager.location) {
            updateNearbyStations()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .animation(.easeInOut(duration: 0.3), value: showLocationBanner)
        .sheet(isPresented: $showNearbySheet) {
            NearbyStationsSheet(
                stations: nearbyStations,
                arrivalsByStation: feedManager.arrivalsByStation,
                isLoading: feedManager.isLoading,
                error: feedManager.lastError,
                onStationTap: { station in
                    showNearbySheet = false
                    selectedStation = station
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedStation) { station in
            // No NavigationStack/title here: StationArrivalsView already shows the
            // station name + route pills as its header, so a nav bar would just
            // repeat the name and add empty space at the top.
            //
            // The sheet hugs its content: we measure the laid-out height and use it
            // as the detent, so there's no dead space at the bottom regardless of
            // how many directions the station has.
            VStack(spacing: 0) {
                StationArrivalsView(
                    station: station,
                    arrivals: feedManager.arrivalsByStation[station.id] ?? [],
                    scrollableArrivals: true
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
                // Fix the vertical size to the content's ideal height so the
                // measurement below reflects the true content height rather than
                // being compressed by the current (possibly smaller) detent.
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: SheetContentHeightKey.self,
                                               value: proxy.size.height)
                    }
                )
                Spacer(minLength: 0)
            }
            .onPreferenceChange(SheetContentHeightKey.self) { height in
                if height > 0 { stationSheetHeight = height }
            }
            .presentationDetents([.height(stationSheetHeight)])
            .presentationDragIndicator(.visible)
            .onAppear {
                feedManager.startPolling(forStations: [station])
            }
        }
        .sheet(isPresented: Binding(
            get: { !tappedStations.isEmpty },
            set: { if !$0 { tappedStations = [] } }
        )) {
            NavigationStack {
                List(tappedStations) { station in
                    StationArrivalsView(
                        station: station,
                        arrivals: feedManager.arrivalsByStation[station.id] ?? []
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        tappedStations = []
                        selectedStation = station
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Select Station")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: Binding(
            get: { calibrationTapPoint != nil },
            set: { if !$0 { calibrationTapPoint = nil; calibrationCandidates = [] } }
        )) {
            calibrationSheet
        }
    }

    // MARK: - Calibration Sheet

    private var calibrationSheet: some View {
        NavigationStack {
            List(calibrationCandidates) { station in
                Button {
                    if let point = calibrationTapPoint {
                        let line = "\(station.name)\t\(station.latitude)\t\(station.longitude)\t\(String(format: "%.3f", point.x))\t\(String(format: "%.3f", point.y))\n"
                        print("✅ \(station.name): (\(String(format: "%.3f", point.x)), \(String(format: "%.3f", point.y)))")

                        // Append to calibration file
                        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent("calibration.tsv")
                        if let data = line.data(using: .utf8) {
                            if FileManager.default.fileExists(atPath: fileURL.path) {
                                if let handle = try? FileHandle(forWritingTo: fileURL) {
                                    handle.seekToEndOfFile()
                                    handle.write(data)
                                    handle.closeFile()
                                }
                            } else {
                                try? data.write(to: fileURL)
                            }
                        }
                        print("📁 Saved to: \(fileURL.path)")
                    }
                    calibrationTapPoint = nil
                    calibrationCandidates = []
                } label: {
                    HStack(spacing: 8) {
                        Text(station.name)
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        ForEach(station.routes, id: \.self) { route in
                            RoutePill(route: route, size: 20)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Which station?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        calibrationTapPoint = nil
                        calibrationCandidates = []
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Deep Link

    /// Handles `nycunderground://station/<stopId>` URLs from the widget.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "nycunderground", url.host == "station" else { return }
        let stopId = url.lastPathComponent
        guard !stopId.isEmpty,
              let station = StationDatabase.station(forStopId: stopId) else { return }

        // Dismiss any other open sheets first to avoid presentation conflicts.
        tappedStations = []
        showNearbySheet = false
        calibrationTapPoint = nil
        selectedStation = station
    }

    // MARK: - Nearby Stations

    private func updateNearbyStations() {
        guard let location = locationManager.location else { return }
        let stations = StationDatabase.nearestStations(to: location.coordinate, count: 5)
        nearbyStations = stations
        if !stations.isEmpty {
            feedManager.startPolling(forStations: stations)
        }
    }

    // MARK: - Location Banner

    private func locationBanner(for coordinate: CLLocationCoordinate2D) -> some View {
        let nearest = StationDatabase.nearestStations(to: coordinate, count: 1).first

        return HStack(spacing: 10) {
            Circle()
                .fill(Color.blue)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                        .frame(width: 18, height: 18)
                )

            if let station = nearest {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Near \(station.name)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(formatDistance(to: station, from: coordinate))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Locating…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Tap banner area to show nearby sheet
            Button {
                showNearbySheet = true
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .onTapGesture {
            showNearbySheet = true
        }
    }

    // MARK: - Permission Prompt

    private var locationPrompt: some View {
        Button {
            locationManager.requestPermission()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                Text("Show My Location")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
    }

    // MARK: - PDF Missing

    private var isMapMissing: Bool {
        UIImage(named: "subway-map") == nil
    }

    private var pdfMissingOverlay: some View {
        VStack(spacing: 20) {
            Image(systemName: "tram.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Subway Map Not Found")
                .font(.title2.weight(.semibold))

            Text("Add **subway-map.png** to the Xcode asset catalog.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Helpers

    private func formatDistance(to station: Station, from coordinate: CLLocationCoordinate2D) -> String {
        let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let meters = userLocation.distance(from: stationLocation)

        if meters < 160 {
            return "Very close"
        } else {
            let miles = meters / 1609.34
            return String(format: "%.1f mi away", miles)
        }
    }
}

/// Reports the laid-out height of the single-station sheet's content so the
/// sheet can size its detent to fit.
private struct SheetContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    ContentView()
}
