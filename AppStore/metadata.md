# App Store Connect — Listing Metadata

Copy-paste these fields into **App Store Connect → My Apps → NYC Underground → App Store** tab.
Character limits are enforced by Apple; counts below are within limits.

---

## App Information (app-level)

| Field | Value |
|-------|-------|
| **Name** (≤30) | `NYC Underground` |
| **Subtitle** (≤30) | `Live NYC subway arrivals` |
| **Bundle ID** | `com.kitdesai.NYCUnderground` |
| **SKU** | `nycunderground-001` |
| **Primary Category** | Navigation |
| **Secondary Category** | Travel |
| **Content Rights** | Does not contain, show, or access third-party content* |
| **Age Rating** | 4+ |

> \* See the trademark/IP note below — this app **does** display the MTA's subway
> map and uses MTA route names/colors and live data. Answer Apple's content-rights
> question honestly: you are displaying third-party transit data and artwork that
> you are authorized to use under the MTA's open-data terms. Keep the
> "not affiliated with the MTA" disclaimer (it's in the description and on the
> website) to reduce trademark risk.

> ⚠️ **Trademark / copyright note (read SUBMISSION_CHECKLIST.md §6):** "MTA",
> "New York City Transit", the subway **map**, and the colored **line bullets**
> are property of the Metropolitan Transportation Authority. This app uses the
> MTA's publicly published map and open GTFS data. To reduce rejection risk under
> **Guideline 4.1 (Copycats)** / **5.2 (Intellectual Property)**, the description
> and website include a clear "independent app, not affiliated with the MTA"
> disclaimer. If rejected on naming/branding, the description note and the public
> disclaimer page are your first response; see the checklist for fallbacks.

---

## Version Information (1.0)

### Promotional Text (≤170, editable any time without review)
```
Real-time NYC subway arrivals on the official map. Tap any station for live train times, see your GPS location, and find the nearest stops. No account, no ads.
```

### Description (≤4000)
```
NYC Underground turns your iPhone into a fast, native New York City subway companion. The complete MTA subway map is bundled right into the app — pinch to zoom anywhere, tap any station, and see real-time train arrivals the instant you look.

No account, no sign-up, no ads. Your location never leaves your device.

FEATURES

• The whole subway map — the full New York City subway map is built in and renders at high resolution. Smooth pinch-to-zoom and pan, even at street level.
• Real-time arrivals — tap any station to see live train times, straight from the MTA's official real-time feeds, grouped by direction with colored line bullets.
• Your location on the map — an optional GPS dot shows exactly where you are on the subway map, so you always know which station is closest.
• Nearby stations — one tap shows the closest stations ranked by distance, each with live arrivals.
• All 445 stations — every line, every borough, with proper station complexes and direction labels sourced from official MTA data.
• Always current — arrivals refresh automatically every 30 seconds. No API key, no login, nothing to configure.

PRIVATE BY DESIGN

NYC Underground does not collect analytics, has no trackers, and requires no account. Your GPS location is used only on your device to place the dot on the map and find nearby stations — it is never transmitted anywhere. The app's only network requests are to the MTA's public real-time data feeds.

HOW IT WORKS

1. Open the app — the subway map loads instantly.
2. (Optional) Allow location to see your position and nearest stations.
3. Tap any station to see real-time arrivals by direction.
4. Tap the location banner for a ranked list of nearby stations.

REQUIREMENTS

• iPhone running iOS 18 or later.
• An internet connection for live arrival times (the map itself works offline).

NYC Underground is an independent app and is not affiliated with, authorized, endorsed by, or in any way officially connected to the Metropolitan Transportation Authority (MTA) or New York City Transit. "MTA", the subway map, and the route symbols are trademarks of their respective owners and are used here only to describe and display the transit system this app helps you navigate. Real-time and schedule data is provided by the MTA under its open-data program.
```

### Keywords (≤100, comma-separated, no wasted spaces)
```
subway,nyc,mta,train,transit,map,arrivals,real-time,metro,gtfs,station,nearby,tracker
```
> Count: 85 characters. Do not add the app name or your developer name — Apple
> indexes those automatically, so repeating them wastes space.

### Support URL (required)
```
https://kitdesai-ai.github.io/nycunderground/support.html
```

### Marketing URL (optional)
```
https://kitdesai-ai.github.io/nycunderground/
```

### Copyright
```
2026 Kit Desai
```

### Version & Build
| Field | Value |
|-------|-------|
| Version | 1.0 |
| Build | (from latest TestFlight upload) |

### What's New in This Version
> Not required for a first 1.0 release. Leave blank or use:
```
Initial release.
```

---

## Privacy Policy URL (required, set under App Privacy)
```
https://kitdesai-ai.github.io/nycunderground/privacy-policy.html
```

See `app-privacy.md` for the full App Privacy ("nutrition label") answers.
