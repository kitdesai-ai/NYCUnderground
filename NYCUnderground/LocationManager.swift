import CoreLocation
import Combine

/// Manages Core Location updates for the user's current position.
/// Requires NSLocationWhenInUseUsageDescription in Info.plist (set via Xcode target > Info tab).
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    // Swift 6.2 / Xcode 26: explicit objectWillChange for MainActor-isolated ObservableObject
    nonisolated let objectWillChange = ObservableObjectPublisher()

    var location: CLLocation? {
        willSet { objectWillChange.send() }
    }

    var authorizationStatus: CLAuthorizationStatus = .notDetermined {
        willSet { objectWillChange.send() }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 20 // Update every ~20m to save battery
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        Task { @MainActor in
            self.location = newLocation
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startUpdating()
            }
        }
    }
}
