import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var showLocationBanner = true

    /// Set to true to enable calibration mode: tap stations to log normalized coordinates.
    private let calibrationMode = true

    var body: some View {
        ZoomableMapView(userLocation: locationManager.location, calibrationMode: calibrationMode)
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
            .animation(.easeInOut(duration: 0.3), value: showLocationBanner)
    }

    // MARK: - Location Banner

    private func locationBanner(for coordinate: CLLocationCoordinate2D) -> some View {
        let nearest = CoordinateMapper.nearestStation(to: coordinate)

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
                    Text(formatDistance(station.distanceMeters))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Locating…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                withAnimation { showLocationBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
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

    private func formatDistance(_ meters: Double) -> String {
        if meters < 160 { // ~0.1 miles
            return "Very close"
        } else {
            let miles = meters / 1609.34
            return String(format: "%.1f mi away", miles)
        }
    }
}

#Preview {
    ContentView()
}
