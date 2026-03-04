import CoreLocation
import CoreGraphics

/// Maps GPS coordinates to pixel positions on the schematic subway map.
///
/// Because the MTA map is a schematic (not geographically accurate), we use a set of
/// manually-calibrated reference points and inverse distance weighted interpolation.
///
/// ## Calibration
/// To calibrate, you need to find the pixel coordinates of several known stations
/// on your rendered map image. See `referencePoints` below — update the `imageX` and
/// `imageY` values to match your specific PDF rendering.
///
/// **How to find pixel coordinates:**
/// 1. Run the app with `showCalibrationCrosshair = true` in ContentView
/// 2. Pan/zoom to a known station
/// 3. Tap it — the console will log the image-space coordinates
/// 4. Update the corresponding reference point below
struct CoordinateMapper {

    /// A known station with both GPS and image-pixel coordinates.
    struct ReferencePoint {
        let name: String
        let latitude: Double
        let longitude: Double
        let imageX: Double  // pixels in the rendered image (at renderScale)
        let imageY: Double  // pixels in the rendered image (at renderScale)
    }

    /// The scale factor used when rendering the PDF to an image.
    /// Must match `renderScale` in ZoomableMapView.
    static let renderScale: CGFloat = 4.0

    // MARK: - Reference Points
    //
    // GPS coordinates are accurate. Image coordinates are ESTIMATES for the
    // standard MTA subway map PDF (~2112×3060pt at 1x, so ~8448×12240px at 4x).
    //
    // ⚠️  UPDATE THESE image coordinates after rendering your PDF.
    //     Use the calibration crosshair mode to find exact pixel positions.
    //
    // The image origin (0,0) is the TOP-LEFT corner.

    static let referencePoints: [ReferencePoint] = [
        // Manhattan
        ReferencePoint(name: "Times Sq–42 St",
                       latitude: 40.7580, longitude: -73.9855,
                       imageX: 3200, imageY: 5400),
        ReferencePoint(name: "Grand Central–42 St",
                       latitude: 40.7527, longitude: -73.9772,
                       imageX: 3800, imageY: 5500),
        ReferencePoint(name: "14 St–Union Sq",
                       latitude: 40.7359, longitude: -73.9906,
                       imageX: 3400, imageY: 6600),
        ReferencePoint(name: "Chambers St",
                       latitude: 40.7131, longitude: -74.0097,
                       imageX: 3000, imageY: 7800),
        ReferencePoint(name: "125 St (Lex)",
                       latitude: 40.8041, longitude: -73.9375,
                       imageX: 4000, imageY: 3800),
        ReferencePoint(name: "Inwood–207 St",
                       latitude: 40.8681, longitude: -73.9199,
                       imageX: 2600, imageY: 1600),

        // Brooklyn
        ReferencePoint(name: "Atlantic Av–Barclays",
                       latitude: 40.6862, longitude: -73.9783,
                       imageX: 3600, imageY: 8800),
        ReferencePoint(name: "Coney Island–Stillwell",
                       latitude: 40.5771, longitude: -73.9812,
                       imageX: 3400, imageY: 11400),
        ReferencePoint(name: "Jay St–MetroTech",
                       latitude: 40.6923, longitude: -73.9872,
                       imageX: 3300, imageY: 8500),

        // Queens
        ReferencePoint(name: "Flushing–Main St",
                       latitude: 40.7596, longitude: -73.8300,
                       imageX: 6800, imageY: 4200),
        ReferencePoint(name: "Jackson Hts–Roosevelt",
                       latitude: 40.7466, longitude: -73.8914,
                       imageX: 5600, imageY: 5000),
        ReferencePoint(name: "Jamaica Center",
                       latitude: 40.7023, longitude: -73.8009,
                       imageX: 7200, imageY: 7000),

        // Bronx
        ReferencePoint(name: "Yankee Stadium–161 St",
                       latitude: 40.8280, longitude: -73.9258,
                       imageX: 3600, imageY: 2800),
        ReferencePoint(name: "Pelham Bay Park",
                       latitude: 40.8525, longitude: -73.8283,
                       imageX: 5800, imageY: 1800),

        // Staten Island (Ferry terminal area)
        ReferencePoint(name: "South Ferry",
                       latitude: 40.7019, longitude: -74.0130,
                       imageX: 2700, imageY: 8200),
    ]

    /// NYC bounding box — points outside this are off the map.
    static let nycBounds = (
        minLat: 40.49, maxLat: 40.92,
        minLon: -74.06, maxLon: -73.70
    )

    // MARK: - Mapping

    /// Maps a GPS coordinate to an image pixel position using inverse distance weighting.
    /// Returns `nil` if the coordinate is outside the NYC bounding box.
    static func mapToImage(
        coordinate: CLLocationCoordinate2D,
        imageSize: CGSize
    ) -> CGPoint? {
        // Bounds check
        guard coordinate.latitude >= nycBounds.minLat,
              coordinate.latitude <= nycBounds.maxLat,
              coordinate.longitude >= nycBounds.minLon,
              coordinate.longitude <= nycBounds.maxLon else {
            return nil
        }

        // Compute inverse-distance weights from each reference point
        let power: Double = 2.5  // higher = more local influence
        var weightedX: Double = 0
        var weightedY: Double = 0
        var totalWeight: Double = 0

        for ref in referencePoints {
            let dLat = coordinate.latitude - ref.latitude
            let dLon = coordinate.longitude - ref.longitude
            let distance = sqrt(dLat * dLat + dLon * dLon)

            // If we're very close to a reference point, just use it directly
            if distance < 0.0005 {
                let pt = CGPoint(x: ref.imageX, y: ref.imageY)
                return clamp(pt, within: imageSize)
            }

            let weight = 1.0 / pow(distance, power)
            weightedX += weight * ref.imageX
            weightedY += weight * ref.imageY
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }

        let pt = CGPoint(
            x: weightedX / totalWeight,
            y: weightedY / totalWeight
        )
        return clamp(pt, within: imageSize)
    }

    /// Finds the nearest reference station to the given coordinate.
    static func nearestStation(to coordinate: CLLocationCoordinate2D) -> (name: String, distanceMeters: Double)? {
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var closest: (name: String, distanceMeters: Double)?

        for ref in referencePoints {
            let refLocation = CLLocation(latitude: ref.latitude, longitude: ref.longitude)
            let dist = userLocation.distance(from: refLocation)
            if closest == nil || dist < closest!.distanceMeters {
                closest = (ref.name, dist)
            }
        }
        return closest
    }

    // MARK: - Helpers

    private static func clamp(_ point: CGPoint, within size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }
}
