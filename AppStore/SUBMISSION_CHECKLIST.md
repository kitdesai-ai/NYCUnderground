# App Store Submission Checklist — NYC Underground

A start-to-finish guide. Files referenced here live in this `AppStore/` folder and
in `docs/` (the public website). Check items off as you go.

---

## 0. What's already done (in this branch)
- [x] App icon present (1024) — `NYCUnderground/Assets.xcassets/AppIcon.appiconset`
- [x] `ITSAppUsesNonExemptEncryption = NO` set in build settings (no export-compliance paperwork)
- [x] Device family set to **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`) and
      `SUPPORTED_PLATFORMS = iphoneos iphonesimulator` (dropped macOS/visionOS)
- [x] Location usage string set (`NSLocationWhenInUseUsageDescription`)
- [x] Listing copy written → `metadata.md`
- [x] App Privacy answers → `app-privacy.md`
- [x] Privacy Policy + Support + landing pages → `docs/` (GitHub Pages)
- [x] Pages deploy workflow → `.github/workflows/pages.yml`
- [x] Marketing screenshots generated (1320 × 2868) → `screenshots/` + `screenshots.md`

---

## 1. Publish the website (Privacy Policy + Support URLs are REQUIRED)
The Pages workflow deploys on push to **main/master**. So:
1. Merge this branch into `main` (or run the workflow manually via
   **Actions → Deploy GitHub Pages → Run workflow**).
2. In the repo: **Settings → Pages → Source: GitHub Actions**, then enable Pages.
3. Confirm these load:
   - [ ] `https://kitdesai-ai.github.io/nycunderground/privacy-policy.html`
   - [ ] `https://kitdesai-ai.github.io/nycunderground/support.html`

> If you'd rather not wait on a merge: in **Settings → Pages**, you can instead
> set Source to "Deploy from a branch", pick this branch and the `/docs` folder.

---

## 2. Screenshots (ready, but a real map capture is recommended — see screenshots.md)
- [x] 6.9" iPhone, **1320 × 2868**, 5 marketing slides in `screenshots/`
- [ ] (Recommended) Replace the two **map** slides (01, 04) with real simulator
      captures so the genuine MTA map shows — drop them in `screenshots/raw/` and
      rerun `python3 AppStore/generate_screenshots.py`.

---

## 3. App Store Connect — create the app record
1. Go to https://appstoreconnect.apple.com → **My Apps → +**.
2. Platform: iOS · Name: **NYC Underground** · Primary language: English (U.S.)
   · Bundle ID: **com.kitdesai.NYCUnderground** · SKU: `nycunderground-001`.
3. Fill in fields from `metadata.md`:
   - [ ] Subtitle, Promotional Text, Description, Keywords
   - [ ] Support URL, Marketing URL, Copyright
   - [ ] Primary category **Navigation**, Secondary **Travel**
   - [ ] Upload screenshots
4. **App Privacy** → "Data Not Collected" (see `app-privacy.md`)
   - [ ] Set Privacy Policy URL
5. **Age Rating** → answer all "None" → results in **4+**.

---

## 4. Build, archive & upload
Run on your Mac with automatic signing configured for your team (`46G2XD5786`):
```bash
xcodebuild archive -scheme NYCUnderground \
  -archivePath ./build/NYCUnderground.xcarchive \
  -destination 'generic/platform=iOS'

# Create an ExportOptions.plist (method: app-store-connect, your team ID,
# destination: upload) once, then:
xcodebuild -exportArchive \
  -archivePath ./build/NYCUnderground.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```
- [ ] Build appears in App Store Connect → TestFlight (allow ~5–15 min processing)
- [ ] (Recommended) Test the processed build via TestFlight on a real device

> Bump the build number for each upload. Version stays `1.0`; the build
> (`CURRENT_PROJECT_VERSION`) must increase on each new binary.

---

## 5. Attach build & submit
1. In the **1.0** version page → **Build** → select the uploaded build.
2. **App Review Information**:
   - [ ] Contact info (your name, phone, email)
   - [ ] **Notes for review (IMPORTANT):** Suggested note:

   > "NYC Underground displays the New York City subway map and shows real-time
   > train arrivals from the MTA's public GTFS-realtime feeds (no API key
   > required). It needs an internet connection for live arrival times. Location
   > is **optional** — the app is fully usable without it (browse the map, tap any
   > station, view arrivals); when granted, it only places a dot on the map and
   > ranks nearby stations, and the coordinate never leaves the device. The app
   > collects no data and uses no analytics or trackers. It is an independent app
   > and is not affiliated with the MTA; transit data and map are used under the
   > MTA's open-data program."

   - [ ] Demo account: **Not needed** (no login) — leave blank / mark N/A.
3. **Version Release**: choose Automatic or Manual release.
4. - [ ] Click **Add for Review** → **Submit**.

---

## 6. Likely rejection risks (be ready)
| Risk | Guideline | Mitigation |
|------|-----------|-----------|
| **Uses the MTA map, route bullets, and "MTA" branding** | 4.1 (Copycats) / 5.2 (IP) | The MTA publishes its map and offers transit data under an open-data program, which permits use. The description and the website both carry a clear "independent app, not affiliated with the MTA" disclaimer. If challenged, point to the MTA open-data terms (data.ny.gov / MTA developer resources). **Fallbacks if rejected:** (a) keep only the open GTFS *data* and replace the bundled map with an original schematic you draw, or (b) add a more prominent in-app attribution/disclaimer. |
| Name/関连 to a transit agency | 4.1 | "NYC Underground" does not use the MTA name in the title; the disclaimer covers branding. If asked to rename, the Name field is the only change needed (no code change). |
| "Minimum functionality" for a map app | 4.2 | The app adds real value over a static map: live arrivals, GPS positioning, nearest-station ranking. The description makes this explicit. |
| Location prompt | 5.1.1 | `NSLocationWhenInUseUsageDescription` is set with a clear reason, and location is optional. The review note states this. |
| Background/standby data use | — | None — the app only polls while foregrounded. |

---

## Quick reference — key values
| Item | Value |
|------|-------|
| App name | NYC Underground |
| Bundle ID | com.kitdesai.NYCUnderground |
| SKU | nycunderground-001 |
| Version / Build | 1.0 / (increment per upload) |
| Min iOS | 18.0 |
| Devices | iPhone only |
| Category | Navigation (Travel secondary) |
| Age rating | 4+ |
| Privacy | Data Not Collected |
| Privacy URL | https://kitdesai-ai.github.io/nycunderground/privacy-policy.html |
| Support URL | https://kitdesai-ai.github.io/nycunderground/support.html |
| Keywords | 85 / 100 chars (see metadata.md) |
