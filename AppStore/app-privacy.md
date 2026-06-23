# App Privacy — "Nutrition Label" Answers

Enter these in **App Store Connect → App Privacy**. This app collects nothing, so
the label is the simplest possible: **Data Not Collected**.

## Data Collection

> **Question: "Do you or your third-party partners collect data from this app?"**
>
> **Answer: No, we do not collect data from this app.**

Justification (for your own records — confirmed from the source code):
- No analytics, crash-reporting, advertising, or tracking SDKs are linked.
- **Location is used only on the device.** `LocationManager.swift` reads the GPS
  position via `CoreLocation` to draw the user dot on the map and rank nearby
  stations (`ContentView.swift`, `StationDatabase`). The coordinate is **never
  transmitted off the device** — it is not sent to the MTA, to us, or to anyone.
  In Apple's terms, location is *used* but **not collected**, so it does not
  appear on the privacy label.
- The app's only outbound network connections are to the **MTA's public
  real-time GTFS feeds** (`SubwayFeedManager.swift`). These requests carry **no
  user data** — no location, no identifiers — they only fetch train arrival
  times. No API key or account is required.
- No account, login, or contact information is requested.

## Tracking
- **Does this app track users?** No.
- No `NSUserTrackingUsageDescription` / App Tracking Transparency prompt is needed.

## Export Compliance (Encryption)
- `Info.plist` already sets `ITSAppUsesNonExemptEncryption = NO`
  (`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` in the build settings).
- In App Store Connect, when asked about encryption, answer:
  - "Does your app use encryption?" → The app uses only standard HTTPS/TLS
    provided by the OS to fetch MTA data, which is **exempt**.
  - You will **not** need to provide export compliance documentation.

## Permissions the app requests (for your reference)
| Permission | Info.plist key | Why |
|-----------|----------------|-----|
| Location (When In Use) | `NSLocationWhenInUseUsageDescription` — "Shows your location on the subway map" | Place the GPS dot on the map and find nearby stations. **Optional** — the app works fully without it. |

This is a device-access permission, not data collection — it does not change the
"Data Not Collected" label because the location never leaves the device.

> Tip for review: in **App Review Information → Notes**, mention that location is
> optional and the app is fully usable (browse map, tap stations, view arrivals)
> without granting it. See SUBMISSION_CHECKLIST.md §5.
