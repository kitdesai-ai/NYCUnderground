# NYC Underground — Project Brief

## What This Is
A NYC subway map iOS app with real-time train arrivals. Bundles the official MTA map with GPS overlay, station tap detection (OCR + distance-based), and live GTFS-RT arrival times.

## Current State: Phase 2 — Working
Zoomable MTA map with location dot, tap any station to see real-time arrivals, tap the location banner for nearby stations sheet. Station data sourced from MTA's Stations.csv with proper complex groupings and per-station direction labels.

## Tech Stack
- Swift / SwiftUI (targeting Swift 6.2 / Xcode 26)
- UIKit `UIScrollView` bridged via `UIViewRepresentable` for map zoom/pan
- `CoreLocation` for GPS
- `Vision` framework for OCR-based station detection on tap
- `SwiftProtobuf` for GTFS-RT feed parsing
- Network calls to MTA GTFS-RT endpoints (no API key required)

## File Structure
```
NYCUnderground/
  NYCUndergroundApp.swift          — App entry point, forces light mode
  ContentView.swift                — Root view: map + banners + sheets for arrivals
  ZoomableMapView.swift            — UIViewRepresentable: scroll/zoom + tap handling
  LocationManager.swift            — CLLocationManager wrapper (Swift 6.2 pattern)
  CoordinateMapper.swift           — GPS-to-pixel mapping via inverse distance weighting (~120 ref points)
  StationDatabase.swift            — Loads stops_subway.json, lookup by ID/GPS/visual position
  StationOCR.swift                 — Vision OCR: crop map near tap, fuzzy-match text to station names
  Station.swift                    — Station model with directionLabels per platform
  Arrival.swift                    — Arrival model (route, direction, time)
  SubwayFeedManager.swift          — Polls MTA GTFS-RT feeds every 30s
  GTFSRealtimeParser.swift         — Protobuf → Arrival parsing
  StationArrivalsView.swift        — Arrivals grouped by direction with route pills
  NearbyStationsSheet.swift        — Nearby stations list with arrivals
  RoutePill.swift                  — Colored route indicator (matches MTA colors)
  stops_subway.json                — 445 stations from MTA Stations.csv + GTFS (Complex ID groupings)
  Proto/
    gtfs-realtime.proto            — GTFS-RT protobuf schema
    gtfs-realtime.pb.swift         — Generated Swift protobuf code (nonisolated for Swift 6.2)
  Assets.xcassets/
    subway-map.imageset/           — Pre-rendered MTA map PNG (6766×8060px)
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

## Key Architecture Decisions (continued)

### Station Tap Detection
Two-layer approach: OCR primary, distance fallback.
1. **OCR** (`StationOCR.swift`): Crops region around tap from map image, runs `VNRecognizeTextRequest`, fuzzy-matches recognized text against station names. Filters out route label circles (single letters/numbers like "2", "A"). Adapts crop radius to zoom level.
2. **Distance-based** (`StationDatabase.stations(nearNormalizedPoint:...)`): Pre-computes visual positions via `CoordinateMapper.mapToImage()` forward mapping. Falls back here if OCR finds nothing.

### Station Data
`stops_subway.json` is generated from two MTA sources:
- **MTA Stations.csv** (`http://web.mta.info/developers/data/nyct/subway/Stations.csv`): Complex ID for proper station groupings, direction labels (north/south) per platform
- **GTFS static** (`http://web.mta.info/developers/data/nyct/subway/google_transit.zip`): `stop_times.txt` for actual routes per stop, `stops.txt` for coordinates
- Station complexes are defined by MTA Complex ID (NOT by name matching — many stations share names across boroughs)
- Direction labels are per-platform from MTA data (e.g., Jay St R: "Manhattan" / "Bay Ridge - 95 St")

### GTFS-RT Feed Polling
`SubwayFeedManager` polls 8 MTA feed endpoints (one per line group) every 30 seconds. Each feed returns protobuf with `TripUpdate` entities containing `StopTimeUpdate` with arrival times. The `GTFSRealtimeParser` extracts arrivals matching requested station stop_ids.

## Known Issues / TODOs
- **No loading indicator**: Brief white screen on cold launch before the map image appears.
- **Memory**: The 6766×8060 bitmap is ~200MB uncompressed. Fine on modern iPhones but could tile if needed.
- **Light mode only**: App forces `.preferredColorScheme(.light)` since the MTA map has a white background.
- **Calibration mode**: `calibrationMode = false` in ContentView. Set to `true` to tap stations and log normalized coordinates to `calibration.tsv` in Documents.

## Phase 3 — Potential Features

### MTA Data Sources Available
| Dataset | URL | Potential Use |
|---------|-----|---------------|
| Service Alerts | `https://data.ny.gov/d/7kct-peq7` | Show disruptions/planned work on affected stations and routes |
| Elevator & Escalator Availability | `https://data.ny.gov/d/rc78-7x78` | Real-time accessibility status per station |
| Elevator/Escalator Inventory | `https://data.ny.gov/d/94fv-bak7` | Which stations have elevators, current status |
| Station Entrances & Exits | `https://data.ny.gov/d/i9wp-a4ja` | GPS coords of every entrance with street corner info |
| Hourly Ridership | `https://data.ny.gov/d/5wq4-mkjj` | "How crowded is this station?" indicator |
| Supplemented GTFS | `https://rrgtfsfeeds.s3.amazonaws.com/gtfs_supplemented.zip` | Schedule with service changes for next 7 days, updated hourly |
| Stations & Complexes | `https://data.ny.gov/d/5f5g-n3cz` | ADA accessibility details per complex |

### Feature Ideas
- **Service alerts**: Show weekend/planned work banners on station arrival sheets, route-level disruption indicators
- **Elevator/escalator status**: Accessibility icon on stations, alert when elevator is out at a station you're heading to
- **Station entrances**: "Navigate to nearest entrance" with walking directions
- **iOS widget** (WidgetKit): Nearest station arrival times on home screen
- **Dark mode**: Inverted/dark map variant

## Info.plist Keys (set via Xcode target > Info tab, NOT a standalone file)
- `NSLocationWhenInUseUsageDescription`: "Shows your location on the subway map"

## Map Asset
Download from `https://new.mta.info/map/5256`, rename to `subway-map.pdf`, add to target's bundle resources.
