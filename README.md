# NYC Underground

A fast, native iOS subway map app with real-time MTA train arrivals for all 445 New York City subway stations.

## Features

- **Zoomable MTA Map** — Smooth pinch-to-zoom and pan via UIScrollView, bundled high-res subway map (6766×8060px)
- **GPS Location Overlay** — Pulsing blue dot on the schematic map, mapped via inverse distance weighted interpolation (~120 reference points)
- **Instant Station Detection** — Tap any station for arrivals. Positions pre-indexed via offline OCR — no runtime latency
- **Real-Time Arrivals** — Live train times from MTA GTFS-RT feeds, polled every 30 seconds, grouped by direction with route pills
- **Nearby Stations** — Tap the location banner to see the closest stations with live arrivals

## Screenshots

<!-- TODO: Add screenshots -->

## Tech Stack

- Swift / SwiftUI (Swift 6.2 / Xcode 26)
- UIKit `UIScrollView` bridged via `UIViewRepresentable`
- CoreLocation for GPS
- SwiftProtobuf for GTFS-RT feed parsing
- Apple Vision framework (offline, via PyObjC) for station position indexing

## How It Works

### Schematic Map + GPS

The MTA subway map is a schematic — distances and angles are distorted for readability. A simple lat/lon projection won't work. Instead, `CoordinateMapper` uses ~120 manually-calibrated reference points and inverse distance weighted interpolation to map GPS coordinates to pixel positions on the map.

### Station Tap Detection

An offline Python script (`scripts/index_stations.py`) runs Apple's Vision OCR on the full map image, fuzzy-matches detected text to station names, and outputs normalized positions for all 445 stations. At runtime, taps are resolved instantly via coordinate lookup — no OCR needed.

### Real-Time Data

The app polls 8 MTA GTFS-RT feed endpoints (one per line group) every 30 seconds. No API key required. Arrivals are parsed from protobuf `TripUpdate` entities and displayed grouped by direction with colored route pills matching MTA branding.

## Building

1. Open `NYCUnderground.xcodeproj` in Xcode 26+
2. Build and run on a simulator or device

The subway map PNG and station data are bundled in the app — no external setup needed.

### Regenerating Station Positions

If the map image changes, re-run the OCR indexing script:

```bash
python3 scripts/index_stations.py
# Interactive mode for unmatched stations:
python3 scripts/index_stations.py --interactive
```

Requires macOS with PyObjC (`pip3 install pyobjc-framework-Vision pyobjc-framework-Quartz`).

## Data Sources

- [MTA GTFS-RT Feeds](http://web.mta.info/developers/developer-data-terms.html) — Real-time train arrivals
- [MTA Stations.csv](http://web.mta.info/developers/data/nyct/subway/Stations.csv) — Station complexes and direction labels
- [MTA GTFS Static](http://web.mta.info/developers/data/nyct/subway/google_transit.zip) — Routes per stop, coordinates
- [MTA Subway Map](https://new.mta.info/map/5256) — Official map PDF

## License

MIT
