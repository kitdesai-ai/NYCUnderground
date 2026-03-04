# NYC Underground — Project Brief

## What This Is
An offline NYC subway map iOS app. Phase 1 is a high-res zoomable MTA map with current location overlay. Phase 2 will add real-time train arrival times.

## Current State: Phase 1 — Working
The app bundles the official MTA subway map PDF, renders it at 4× resolution as a bitmap, and displays it in a UIScrollView with pinch-to-zoom. A blue dot shows the user's approximate location on the schematic map. A floating banner shows the nearest reference station by GPS distance.

## Tech Stack
- Swift / SwiftUI (targeting Swift 6.2 / Xcode 26)
- UIKit `UIScrollView` bridged via `UIViewRepresentable` for map zoom/pan
- `CoreLocation` for GPS
- `CoreGraphics` for PDF rendering
- No dependencies, no packages, no network calls

## File Structure
```
NYCUnderground/
  NYCUndergroundApp.swift          — App entry point, forces light mode
  Views/
    ContentView.swift              — Root view: map + location banner + permission prompt
    ZoomableMapView.swift          — UIViewRepresentable wrapping UIScrollView + PDF render
  Services/
    LocationManager.swift          — CLLocationManager wrapper (Swift 6.2 ObservableObject pattern)
    CoordinateMapper.swift         — GPS-to-pixel mapping via inverse distance weighting
  subway-map.pdf                   — Bundled MTA map (not in repo, downloaded from MTA site)
```

## Key Architecture Decisions

### PDF Rendering
The MTA map PDF (1656×2016pt) is rendered to a UIImage at 4× scale on a background thread. The renderer must use `format.scale = 1.0` explicitly — otherwise UIGraphicsImageRenderer multiplies by the device screen scale (3×), producing a ~480MP image that silently fails. Final image is 6624×8064px at scale 1.0.

### UIScrollView vs SwiftUI
We use UIKit's UIScrollView bridged to SwiftUI because pure SwiftUI ScrollView + MagnifyGesture is unreliable at extreme zoom levels. The UIScrollView handles zoom via its delegate (`viewForZooming`), and we center content in `scrollViewDidZoom`. There's also a deferred zoom setup in `configureZoom` that retries if the scroll view hasn't been laid out yet (race condition between async PDF render and SwiftUI layout).

### Location on a Schematic Map
The MTA map is NOT geographically accurate — it's a schematic with distorted distances and angles. We can't use a simple lat/lon projection. Instead, `CoordinateMapper` uses ~15 manually-placed reference points (known stations with both GPS coords and estimated pixel positions) and inverse distance weighted interpolation to map any GPS coordinate to a pixel position. The reference point pixel coordinates are rough estimates and need calibration against the actual rendered PDF.

### Swift 6.2 Compatibility
`LocationManager` uses the explicit `objectWillChange` pattern: `nonisolated let objectWillChange = ObservableObjectPublisher()` with `willSet { objectWillChange.send() }` instead of `@Published`. Delegate callbacks dispatch to MainActor via `Task { @MainActor in }`.

## Known Issues / TODOs
- **Location dot calibration**: The reference point pixel coordinates in `CoordinateMapper` are estimates. They need to be calibrated by tapping known stations on the rendered map and recording actual pixel positions. The README describes the calibration process.
- **No loading indicator**: The PDF renders on a background thread; there's a brief white screen on cold launch before the image appears.
- **Memory**: The 6624×8064 bitmap is ~200MB uncompressed in memory. Fine on modern iPhones but worth watching. Could tile the PDF instead if this becomes an issue.
- **Light mode only**: App forces `.preferredColorScheme(.light)` since the MTA map is white-background. A dark/inverted mode could be a nice-to-have.

## Phase 2 Plan — Train Arrival Times
The goal is to show real-time train arrival times, either by tapping a station on the map or via a nearby-stations list.

### Data Sources to Research
- **MTA GTFS-RT feeds**: Real-time transit data via protocol buffers. Free API key from `api.mta.info`. Provides trip updates, vehicle positions, and service alerts.
- **Station data**: GTFS static feeds have `stops.txt` with all station coordinates and IDs, which we'd need to map stations on the schematic to their GTFS stop IDs.
- **Existing app reference**: NYC Subway Widget (`https://apps.apple.com/us/app/nyc-subway-widget/id6737175908`) shows nearby station times — this is the UX target.

### Phase 2 Architecture (Rough)
- Add a station database (GTFS stops.txt, bundled or fetched once)
- Network layer to poll GTFS-RT feeds for arrival predictions
- Tap-on-station interaction: overlay tap targets on the map at station positions, show a sheet/popover with upcoming trains
- Nearby stations view: use GPS to find closest stations and show next arrivals
- iOS widget showing nearest station times (WidgetKit)

## Info.plist Keys (set via Xcode target > Info tab, NOT a standalone file)
- `NSLocationWhenInUseUsageDescription`: "Shows your location on the subway map"

## Map Asset
Download from `https://new.mta.info/map/5256`, rename to `subway-map.pdf`, add to target's bundle resources.
