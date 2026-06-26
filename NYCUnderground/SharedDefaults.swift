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
}
