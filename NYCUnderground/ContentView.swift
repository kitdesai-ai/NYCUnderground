import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var showLocationBanner = true

    var body: some View {
        ZStack {
            // Full-screen zoomable map
            ZoomableMapView(userLocation: locationManager.location)
                .ignoresSafeArea()

            // Floating location banner at bottom
            if showLocationBanner, let location = locationManager.location {
                VStack {
                    Spacer()
                    locationBanner(for: location.coordinate)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                .transition(.move(edge: .bottom))
            }

            // Location permission prompt (only shown when not yet determined)
            if locationManager.authorizationStatus == .notDetermined {
                VStack {
                    Spacer()
                    locationPrompt
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }

            // PDF missing overlay
            if isPDFMissing {
                pdfMissingOverlay
            }
        }
        .onAppear {
            if let url = Bundle.main.url(forResource: "subway-map", withExtension: "pdf") {
                print("✅ PDF found at: \(url)")
            } else {
                print("❌ PDF not found in bundle")
            }
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
            // Pulsing dot indicator
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

    private var isPDFMissing: Bool {
        Bundle.main.url(forResource: "subway-map", withExtension: "pdf") == nil
    }

    private var pdfMissingOverlay: some View {
        VStack(spacing: 20) {
            Image(systemName: "tram.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Subway Map Not Found")
                .font(.title2.weight(.semibold))

            Text("Add **subway-map.pdf** to the Xcode project.\n\nDownload the official MTA map from:\nnew.mta.info/map/5256")
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
