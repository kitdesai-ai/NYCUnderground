import Foundation

/// App Group-shared defaults used by both the main app and the widget extension.
/// The App Group capability must be enabled on both targets with this identifier.
enum SharedDefaults {
    static let suiteName = "group.com.kitdesai.NYCUnderground"

    /// Force-unwrapping is intentional — a missing suite means the App Group
    /// entitlement is misconfigured, which we want to crash on during development.
    static let store = UserDefaults(suiteName: suiteName)!

    enum Key {
        static let pinnedStopId = "pinnedStopId"
        static let cachedLat = "cachedLocationLatitude"
        static let cachedLon = "cachedLocationLongitude"
        static let cachedLocationDate = "cachedLocationDate"
    }

    /// stop_id of the station the user has pinned for the widget. Empty/nil means
    /// the widget should fall back to live location, then to a placeholder.
    static var pinnedStopId: String? {
        get {
            let value = store.string(forKey: Key.pinnedStopId)
            return (value?.isEmpty ?? true) ? nil : value
        }
        set { store.set(newValue ?? "", forKey: Key.pinnedStopId) }
    }

    /// A location snapshot with the time it was captured. Plain doubles so this
    /// file has no CoreLocation dependency and stays trivially shareable.
    struct CachedLocation {
        let latitude: Double
        let longitude: Double
        let date: Date
    }

    /// Last-known device location written by the main app whenever it gets a GPS
    /// fix. The widget reads this as a fallback: with only "When In Use"
    /// authorization, a widget can read live location for a limited grace window
    /// after the app is last used, and then stops. This cache keeps the widget
    /// showing a sensible nearest station instead of going blank once that window
    /// expires. (Arrivals are always fetched live regardless of the location source.)
    static var cachedLocation: CachedLocation? {
        get {
            // A missing key reads back as 0.0; require the date sentinel to exist.
            guard store.object(forKey: Key.cachedLocationDate) != nil else { return nil }
            return CachedLocation(
                latitude: store.double(forKey: Key.cachedLat),
                longitude: store.double(forKey: Key.cachedLon),
                date: Date(timeIntervalSince1970: store.double(forKey: Key.cachedLocationDate))
            )
        }
        set {
            guard let newValue else {
                store.removeObject(forKey: Key.cachedLat)
                store.removeObject(forKey: Key.cachedLon)
                store.removeObject(forKey: Key.cachedLocationDate)
                return
            }
            store.set(newValue.latitude, forKey: Key.cachedLat)
            store.set(newValue.longitude, forKey: Key.cachedLon)
            store.set(newValue.date.timeIntervalSince1970, forKey: Key.cachedLocationDate)
        }
    }
}
