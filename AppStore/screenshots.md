# App Store Screenshots — Requirements & Plan

## ✅ Ready-made marketing screenshots are in `screenshots/`

Five branded marketing slides (1320 × 2868, the required 6.9" size) have already
been generated and are ready to upload to App Store Connect as-is:

| File | Headline | Screen shown |
|------|----------|--------------|
| `screenshots/01-map.png` | The whole subway, in your pocket. | Map + location banner |
| `screenshots/02-arrivals.png` | Real-time arrivals, one tap away. | Station arrivals sheet |
| `screenshots/03-nearby.png` | The closest trains, right now. | Nearby stations list |
| `screenshots/04-location.png` | Always know where you are. | Map + GPS dot |
| `screenshots/05-hub.png` | Every line, every borough. | Busy-hub arrivals sheet |

These are vector-rendered mockups that recreate the app's real SwiftUI UI (a
branded transit-night gradient, a headline, and the screen inside an iPhone
frame). The map hero uses an **original, stylized subway-line motif** rather than
the bundled MTA map image, so nothing copyrighted is redistributed in these
marketing assets. Regenerate or tweak them anytime with
`python3 AppStore/generate_screenshots.py` (requires `pip install cairosvg`).

> Mockup vs. real capture: App Store guidelines allow marketing screenshots that
> frame/caption the UI like these. If you prefer pixel-exact captures from the
> live app, follow the simulator steps below and drop them in — either works.

### Want the flair on REAL screenshots?

The renderer can frame your actual app captures with the same headline/gradient.
Drop a 6.9" capture (1320 × 2868) into `screenshots/raw/` using the matching
slide filename (e.g. `screenshots/raw/02-arrivals.png`) and rerun
`python3 AppStore/generate_screenshots.py`. Slides with a real capture use it;
the rest stay synthetic — mix and match freely. Details in
[`screenshots/raw/README.md`](screenshots/raw/README.md).

> Strong candidates for a real capture: the **map** screens (01, 04), since the
> synthetic versions intentionally avoid reproducing the actual MTA map. A real
> capture from the simulator shows the genuine map and looks great.

---

## Requirements reference

You chose **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`), so you only need one
iPhone screenshot set. Apple auto-scales it down for smaller iPhones.

## Required size (iPhone, 2025+ requirement)

| Display | Device example | Portrait pixels | Required? |
|---------|----------------|-----------------|-----------|
| **6.9"** | iPhone 16 Pro Max | **1320 × 2868** | ✅ Required (primary) |
| 6.5" | iPhone 11 Pro Max | 1242 × 2688 | Accepted as the set instead of 6.9" |

Upload the **6.9" (1320 × 2868)** set. That single set satisfies the iPhone
requirement; App Store Connect scales it for all other iPhones.

- **Minimum:** 1 screenshot. **Maximum:** 10. **Recommended:** 4–6.
- No alpha channel. PNG or JPEG. RGB. Portrait orientation.

## Capturing real screenshots (needs a Mac)

Real device screenshots need Xcode + the iOS Simulator (or a physical iPhone),
which requires macOS.

### Capture on the Simulator (recommended)
```bash
# 1. Open the 6.9" simulator
xcrun simctl boot "iPhone 16 Pro Max"
open -a Simulator

# 2. Build & run the app to that simulator from Xcode (⌘R). The map loads;
#    grant location to show the dot, then tap a station / the location banner.

# 3. Capture a pixel-perfect screenshot (saves 1320 × 2868 PNG):
xcrun simctl io booted screenshot ~/Desktop/02-arrivals.png
```

### Suggested shot list (the 5 screens that sell the app)
1. **Map** — zoomed map with the location dot and the "Near …" banner (hero).
2. **Arrivals** — a station's arrivals sheet, grouped by direction with line bullets.
3. **Nearby** — the Nearby Stations list with live times.
4. **Location** — the map with the GPS dot prominent.
5. **Busy hub** — a multi-line station (e.g. Atlantic Av–Barclays Ctr) showing many lines.

## iPad
Not needed — the app is configured iPhone-only (`TARGETED_DEVICE_FAMILY = 1`).
