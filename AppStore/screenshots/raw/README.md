# Real screenshots go here

Drop real app captures in this folder to have them framed with the marketing
flair (gradient background + headline + iPhone frame) instead of the synthetic
drawn UI.

## How

1. Capture from a **6.9" simulator** (iPhone 16 Pro Max) so the image is natively
   **1320 × 2868**:
   ```bash
   xcrun simctl io booted screenshot 02-arrivals.png
   ```
2. Save it here using the **same filename** as the slide you want to replace:
   - `01-map.png` → "The whole subway, in your pocket."
   - `02-arrivals.png` → "Real-time arrivals, one tap away."
   - `03-nearby.png` → "The closest trains, right now."
   - `04-location.png` → "Always know where you are."
   - `05-hub.png` → "Every line, every borough."
3. Re-run the renderer:
   ```bash
   python3 AppStore/generate_screenshots.py
   ```
   Any slide with a matching file here is built from the real screenshot; the
   rest fall back to the synthetic UI. You can mix and match.

## Notes

- The image is scaled to fill the screen area (`xMidYMid slice`), so a native
  1320 × 2868 capture maps almost 1:1 — only a hairline is cropped.
- The synthetic "dynamic island" overlay is **skipped** for real screenshots,
  since your capture already includes the top of the device.
- The map slides (01, 04) are the best candidates for real captures — the
  synthetic versions intentionally avoid drawing the actual MTA map, so a real
  capture shows the genuine map.
- To tweak a headline/subtitle/accent color, edit the `SLIDES` list in
  `generate_screenshots.py`.
