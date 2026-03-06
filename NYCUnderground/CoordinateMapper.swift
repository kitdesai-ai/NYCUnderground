import CoreLocation
import CoreGraphics

/// Maps GPS coordinates to pixel positions on the schematic subway map.
///
/// Because the MTA map is a schematic (not geographically accurate), we use a set of
/// manually-calibrated reference points and inverse distance weighted interpolation.
///
/// Reference points use **normalized coordinates (0.0–1.0)** so they work at any
/// render scale or image size.
struct CoordinateMapper {

    /// A known station with both GPS and normalized image coordinates.
    struct ReferencePoint {
        let name: String
        let latitude: Double
        let longitude: Double
        let normalizedX: Double  // 0.0 = left edge, 1.0 = right edge
        let normalizedY: Double  // 0.0 = top edge, 1.0 = bottom edge
    }

    // MARK: - Reference Points
    //
    // GPS coordinates are accurate. Normalized image coordinates are ESTIMATES
    // based on the standard MTA subway map PDF.
    //
    // ⚠️  These are estimates — not pixel-perfect.
    //     Use calibration mode to find exact positions, then divide by image size.
    //
    // The origin (0,0) is the TOP-LEFT corner.

    static let referencePoints: [ReferencePoint] = [
        // ── Manhattan ──

        // Lower Manhattan
        ReferencePoint(name: "South Ferry",
                       latitude: 40.7019, longitude: -74.0130,
                       normalizedX: 0.246, normalizedY: 0.718),
        ReferencePoint(name: "Whitehall St",
                       latitude: 40.7033, longitude: -74.0129,
                       normalizedX: 0.248, normalizedY: 0.695),
        ReferencePoint(name: "Bowling Green",
                       latitude: 40.7044, longitude: -74.0141,
                       normalizedX: 0.270, normalizedY: 0.688),
        ReferencePoint(name: "Wall St",
                       latitude: 40.7069, longitude: -74.0099,
                       normalizedX: 0.269, normalizedY: 0.667),
        ReferencePoint(name: "Rector St",
                       latitude: 40.7075, longitude: -74.0130,
                       normalizedX: 0.240, normalizedY: 0.683),
        ReferencePoint(name: "Cortlandt St",
                       latitude: 40.7118, longitude: -74.0120,
                       normalizedX: 0.241, normalizedY: 0.669),
        ReferencePoint(name: "Fulton St",
                       latitude: 40.7092, longitude: -74.0065,
                       normalizedX: 0.282, normalizedY: 0.656),
        ReferencePoint(name: "Chambers St",
                       latitude: 40.7131, longitude: -74.0097,
                       normalizedX: 0.191, normalizedY: 0.612),
        ReferencePoint(name: "Canal St",
                       latitude: 40.7191, longitude: -73.9999,
                       normalizedX: 0.188, normalizedY: 0.585),
        ReferencePoint(name: "W 4 St–Washington Sq",
                       latitude: 40.7322, longitude: -73.9970,
                       normalizedX: 0.195, normalizedY: 0.541),

        // Midtown
        ReferencePoint(name: "14 St–Union Sq",
                       latitude: 40.7359, longitude: -73.9906,
                       normalizedX: 0.403, normalizedY: 0.539),
        ReferencePoint(name: "23 St (6 Av)",
                       latitude: 40.7423, longitude: -73.9927,
                       normalizedX: 0.390, normalizedY: 0.505),
        ReferencePoint(name: "34 St–Penn Station",
                       latitude: 40.7506, longitude: -73.9910,
                       normalizedX: 0.370, normalizedY: 0.470),
        ReferencePoint(name: "34 St–Herald Sq",
                       latitude: 40.7494, longitude: -73.9878,
                       normalizedX: 0.390, normalizedY: 0.470),
        ReferencePoint(name: "Times Sq–42 St",
                       latitude: 40.7580, longitude: -73.9855,
                       normalizedX: 0.379, normalizedY: 0.441),
        ReferencePoint(name: "Grand Central–42 St",
                       latitude: 40.7527, longitude: -73.9772,
                       normalizedX: 0.450, normalizedY: 0.449),

        // Upper Midtown / Upper West & East
        ReferencePoint(name: "59 St–Columbus Circle",
                       latitude: 40.7681, longitude: -73.9819,
                       normalizedX: 0.365, normalizedY: 0.400),
        ReferencePoint(name: "Lexington Av/59 St",
                       latitude: 40.7627, longitude: -73.9680,
                       normalizedX: 0.460, normalizedY: 0.410),
        ReferencePoint(name: "72 St (1/2/3)",
                       latitude: 40.7785, longitude: -73.9816,
                       normalizedX: 0.355, normalizedY: 0.370),
        ReferencePoint(name: "86 St (1)",
                       latitude: 40.7889, longitude: -73.9765,
                       normalizedX: 0.350, normalizedY: 0.345),
        ReferencePoint(name: "96 St (1/2/3)",
                       latitude: 40.7936, longitude: -73.9722,
                       normalizedX: 0.345, normalizedY: 0.325),

        // Upper Manhattan
        ReferencePoint(name: "125 St (Lex)",
                       latitude: 40.8041, longitude: -73.9375,
                       normalizedX: 0.474, normalizedY: 0.310),
        ReferencePoint(name: "145 St (1)",
                       latitude: 40.8207, longitude: -73.9364,
                       normalizedX: 0.340, normalizedY: 0.245),
        ReferencePoint(name: "168 St",
                       latitude: 40.8408, longitude: -73.9395,
                       normalizedX: 0.320, normalizedY: 0.195),
        ReferencePoint(name: "Inwood–207 St",
                       latitude: 40.8681, longitude: -73.9199,
                       normalizedX: 0.308, normalizedY: 0.130),

        // ── Brooklyn ──

        // Downtown Brooklyn
        ReferencePoint(name: "Jay St–MetroTech",
                       latitude: 40.6923, longitude: -73.9872,
                       normalizedX: 0.402, normalizedY: 0.696),
        ReferencePoint(name: "Borough Hall",
                       latitude: 40.6923, longitude: -73.9900,
                       normalizedX: 0.374, normalizedY: 0.719),
        ReferencePoint(name: "DeKalb Av",
                       latitude: 40.6906, longitude: -73.9818,
                       normalizedX: 0.456, normalizedY: 0.693),
        ReferencePoint(name: "Hoyt St",
                       latitude: 40.6884, longitude: -73.9850,
                       normalizedX: 0.412, normalizedY: 0.724),
        ReferencePoint(name: "Nevins St",
                       latitude: 40.6853, longitude: -73.9803,
                       normalizedX: 0.434, normalizedY: 0.720),
        ReferencePoint(name: "Atlantic Av–Barclays",
                       latitude: 40.6862, longitude: -73.9783,
                       normalizedX: 0.499, normalizedY: 0.713),

        // South Brooklyn
        ReferencePoint(name: "Eastern Pkwy–Bklyn Museum",
                       latitude: 40.6720, longitude: -73.9642,
                       normalizedX: 0.440, normalizedY: 0.745),
        ReferencePoint(name: "Church Av",
                       latitude: 40.6508, longitude: -73.9629,
                       normalizedX: 0.435, normalizedY: 0.800),
        ReferencePoint(name: "Kings Highway",
                       latitude: 40.6032, longitude: -73.9724,
                       normalizedX: 0.420, normalizedY: 0.875),
        ReferencePoint(name: "Bay Ridge–95 St",
                       latitude: 40.6167, longitude: -73.9936,
                       normalizedX: 0.350, normalizedY: 0.860),
        ReferencePoint(name: "Coney Island–Stillwell",
                       latitude: 40.5771, longitude: -73.9812,
                       normalizedX: 0.403, normalizedY: 0.931),

        // East Brooklyn
        ReferencePoint(name: "Broadway Junction",
                       latitude: 40.6783, longitude: -73.9053,
                       normalizedX: 0.530, normalizedY: 0.760),
        ReferencePoint(name: "Canarsie–Rockaway Pkwy",
                       latitude: 40.6462, longitude: -73.9017,
                       normalizedX: 0.570, normalizedY: 0.840),

        // ── Queens ──

        ReferencePoint(name: "Astoria–Ditmars Blvd",
                       latitude: 40.7751, longitude: -73.9120,
                       normalizedX: 0.560, normalizedY: 0.350),
        ReferencePoint(name: "Queensboro Plaza",
                       latitude: 40.7509, longitude: -73.9402,
                       normalizedX: 0.520, normalizedY: 0.420),
        ReferencePoint(name: "Woodside–61 St",
                       latitude: 40.7454, longitude: -73.9030,
                       normalizedX: 0.600, normalizedY: 0.430),
        ReferencePoint(name: "Jackson Hts–Roosevelt",
                       latitude: 40.7466, longitude: -73.8914,
                       normalizedX: 0.663, normalizedY: 0.408),
        ReferencePoint(name: "Forest Hills–71 Av",
                       latitude: 40.7216, longitude: -73.8445,
                       normalizedX: 0.730, normalizedY: 0.500),
        ReferencePoint(name: "Flushing–Main St",
                       latitude: 40.7596, longitude: -73.8300,
                       normalizedX: 0.805, normalizedY: 0.343),
        ReferencePoint(name: "Jamaica Center",
                       latitude: 40.7023, longitude: -73.8009,
                       normalizedX: 0.853, normalizedY: 0.572),
        ReferencePoint(name: "Far Rockaway",
                       latitude: 40.6033, longitude: -73.7551,
                       normalizedX: 0.820, normalizedY: 0.900),

        // ── Bronx ──

        ReferencePoint(name: "Yankee Stadium–161 St",
                       latitude: 40.8280, longitude: -73.9258,
                       normalizedX: 0.426, normalizedY: 0.228),
        ReferencePoint(name: "Fordham Rd",
                       latitude: 40.8614, longitude: -73.8975,
                       normalizedX: 0.500, normalizedY: 0.160),
        ReferencePoint(name: "Pelham Bay Park",
                       latitude: 40.8525, longitude: -73.8283,
                       normalizedX: 0.687, normalizedY: 0.148),
        ReferencePoint(name: "Woodlawn",
                       latitude: 40.8863, longitude: -73.8787,
                       normalizedX: 0.520, normalizedY: 0.090),
        ReferencePoint(name: "Wakefield–241 St",
                       latitude: 40.9032, longitude: -73.8507,
                       normalizedX: 0.570, normalizedY: 0.055),
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
                return CGPoint(
                    x: ref.normalizedX * Double(imageSize.width),
                    y: ref.normalizedY * Double(imageSize.height)
                )
            }

            let weight = 1.0 / pow(distance, power)
            weightedX += weight * ref.normalizedX
            weightedY += weight * ref.normalizedY
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }

        let pt = CGPoint(
            x: (weightedX / totalWeight) * Double(imageSize.width),
            y: (weightedY / totalWeight) * Double(imageSize.height)
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
