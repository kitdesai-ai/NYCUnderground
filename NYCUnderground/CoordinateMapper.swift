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
                       latitude: 40.7072, longitude: -74.0105,
                       normalizedX: 0.324, normalizedY: 0.669),
        ReferencePoint(name: "Rector St",
                       latitude: 40.7075, longitude: -74.0130,
                       normalizedX: 0.240, normalizedY: 0.683),
        ReferencePoint(name: "Cortlandt St",
                       latitude: 40.7118, longitude: -74.0120,
                       normalizedX: 0.241, normalizedY: 0.669),
        ReferencePoint(name: "WTC Cortlandt",
                       latitude: 40.7118, longitude: -74.0122,
                       normalizedX: 0.165, normalizedY: 0.669),
        ReferencePoint(name: "Fulton St",
                       latitude: 40.7092, longitude: -74.0065,
                       normalizedX: 0.282, normalizedY: 0.656),
        ReferencePoint(name: "World Trade Center",
                       latitude: 40.7126, longitude: -74.0098,
                       normalizedX: 0.198, normalizedY: 0.651),
        ReferencePoint(name: "Chambers St (1/2/3)",
                       latitude: 40.7143, longitude: -74.0071,
                       normalizedX: 0.186, normalizedY: 0.617),
        ReferencePoint(name: "Chambers St (J/Z)",
                       latitude: 40.7143, longitude: -74.0071,
                       normalizedX: 0.298, normalizedY: 0.605),
        ReferencePoint(name: "Franklin St",
                       latitude: 40.7193, longitude: -74.0069,
                       normalizedX: 0.141, normalizedY: 0.601),
        ReferencePoint(name: "Canal St",
                       latitude: 40.7197, longitude: -74.0023,
                       normalizedX: 0.188, normalizedY: 0.587),
        ReferencePoint(name: "Prince St",
                       latitude: 40.7243, longitude: -73.9977,
                       normalizedX: 0.240, normalizedY: 0.566),
        ReferencePoint(name: "W 4 St–Washington Sq",
                       latitude: 40.7322, longitude: -73.9970,
                       normalizedX: 0.195, normalizedY: 0.541),

        ReferencePoint(name: "Brooklyn Bridge-City Hall",
                       latitude: 40.7131, longitude: -74.0040,
                       normalizedX: 0.268, normalizedY: 0.605),
        ReferencePoint(name: "Spring St",
                       latitude: 40.7223, longitude: -73.9974,
                       normalizedX: 0.184, normalizedY: 0.585),
        ReferencePoint(name: "Houston St (1)",
                       latitude: 40.7283, longitude: -74.0054,
                       normalizedX: 0.141, normalizedY: 0.572),
        ReferencePoint(name: "Christopher St-Stonewall",
                       latitude: 40.7334, longitude: -74.0029,
                       normalizedX: 0.140, normalizedY: 0.559),
        ReferencePoint(name: "Bowery",
                       latitude: 40.7203, longitude: -73.9939,
                       normalizedX: 0.312, normalizedY: 0.576),
        ReferencePoint(name: "Spring St (6)",
                       latitude: 40.7243, longitude: -74.0004,
                       normalizedX: 0.277, normalizedY: 0.566),
        ReferencePoint(name: "Bleecker St",
                       latitude: 40.7259, longitude: -73.9946,
                       normalizedX: 0.278, normalizedY: 0.534),
        ReferencePoint(name: "Astor Pl",
                       latitude: 40.7305, longitude: -73.9910,
                       normalizedX: 0.277, normalizedY: 0.523),
        ReferencePoint(name: "Broadway-Lafayette",
                       latitude: 40.7254, longitude: -73.9960,
                       normalizedX: 0.284, normalizedY: 0.551),

        // Midtown
        ReferencePoint(name: "14 St (1/2/3)",
                       latitude: 40.7390, longitude: -73.9994,
                       normalizedX: 0.107, normalizedY: 0.512),
        ReferencePoint(name: "14 St (F/M)",
                       latitude: 40.7390, longitude: -73.9994,
                       normalizedX: 0.148, normalizedY: 0.513),
        ReferencePoint(name: "14 St–Union Sq",
                       latitude: 40.7359, longitude: -73.9906,
                       normalizedX: 0.403, normalizedY: 0.539),
        ReferencePoint(name: "23 St (1)",
                       latitude: 40.7435, longitude: -73.9940,
                       normalizedX: 0.108, normalizedY: 0.494),
        ReferencePoint(name: "23 St (6 Av)",
                       latitude: 40.7423, longitude: -73.9927,
                       normalizedX: 0.390, normalizedY: 0.505),
        ReferencePoint(name: "33 St (6)",
                       latitude: 40.7461, longitude: -73.9821,
                       normalizedX: 0.277, normalizedY: 0.465),
        ReferencePoint(name: "34 St–Penn Station (1/2/3)",
                       latitude: 40.7513, longitude: -73.9922,
                       normalizedX: 0.107, normalizedY: 0.463),
        ReferencePoint(name: "34 St–Penn Station (A/C/E)",
                       latitude: 40.7513, longitude: -73.9922,
                       normalizedX: 0.148, normalizedY: 0.463),
        ReferencePoint(name: "34 St–Herald Sq (B/D/F/M)",
                       latitude: 40.7496, longitude: -73.9879,
                       normalizedX: 0.203, normalizedY: 0.455),
        ReferencePoint(name: "34 St–Herald Sq (N/Q/R/W)",
                       latitude: 40.7496, longitude: -73.9879,
                       normalizedX: 0.185, normalizedY: 0.450),
        ReferencePoint(name: "Times Sq–42 St (1/2/3)",
                       latitude: 40.7554, longitude: -73.9870,
                       normalizedX: 0.170, normalizedY: 0.427),
        ReferencePoint(name: "42 St-Port Authority",
                       latitude: 40.7573, longitude: -73.9897,
                       normalizedX: 0.106, normalizedY: 0.428),
        ReferencePoint(name: "47-50 Sts-Rockefeller Ctr",
                       latitude: 40.7587, longitude: -73.9813,
                       normalizedX: 0.210, normalizedY: 0.407),
        ReferencePoint(name: "49 St",
                       latitude: 40.7599, longitude: -73.9841,
                       normalizedX: 0.164, normalizedY: 0.404),
        ReferencePoint(name: "51 St",
                       latitude: 40.7571, longitude: -73.9719,
                       normalizedX: 0.276, normalizedY: 0.406),
        ReferencePoint(name: "57 St-7 Av",
                       latitude: 40.7647, longitude: -73.9807,
                       normalizedX: 0.167, normalizedY: 0.381),
        ReferencePoint(name: "Grand Central–42 St",
                       latitude: 40.7520, longitude: -73.9774,
                       normalizedX: 0.277, normalizedY: 0.429),

        // Upper Midtown / Upper West & East
        ReferencePoint(name: "59 St–Columbus Circle",
                       latitude: 40.7681, longitude: -73.9819,
                       normalizedX: 0.106, normalizedY: 0.376),
        ReferencePoint(name: "Lexington Av/59 St",
                       latitude: 40.7627, longitude: -73.9680,
                       normalizedX: 0.460, normalizedY: 0.410),
        ReferencePoint(name: "Lexington Av/63 St",
                       latitude: 40.7646, longitude: -73.9661,
                       normalizedX: 0.252, normalizedY: 0.352),
        ReferencePoint(name: "68 St-Hunter College",
                       latitude: 40.7681, longitude: -73.9639,
                       normalizedX: 0.277, normalizedY: 0.342),
        ReferencePoint(name: "96 St (4/5/6)",
                       latitude: 40.7889, longitude: -73.9588,
                       normalizedX: 0.309, normalizedY: 0.310),
        ReferencePoint(name: "103 St (4/5/6)",
                       latitude: 40.7954, longitude: -73.9591,
                       normalizedX: 0.277, normalizedY: 0.300),
        ReferencePoint(name: "110 St (4/5/6)",
                       latitude: 40.7950, longitude: -73.9443,
                       normalizedX: 0.278, normalizedY: 0.292),
        ReferencePoint(name: "116 St (4/5/6)",
                       latitude: 40.8019, longitude: -73.9487,
                       normalizedX: 0.276, normalizedY: 0.281),
        ReferencePoint(name: "125 St (4/5/6)",
                       latitude: 40.8046, longitude: -73.9484,
                       normalizedX: 0.271, normalizedY: 0.271),
        ReferencePoint(name: "66 St-Lincoln Center",
                       latitude: 40.7734, longitude: -73.9822,
                       normalizedX: 0.084, normalizedY: 0.367),
        ReferencePoint(name: "72 St (1/2/3)",
                       latitude: 40.7785, longitude: -73.9816,
                       normalizedX: 0.082, normalizedY: 0.354),
        ReferencePoint(name: "72 St (B/C)",
                       latitude: 40.7743, longitude: -73.9723,
                       normalizedX: 0.112, normalizedY: 0.355),
        ReferencePoint(name: "81 St-Museum of Natural History",
                       latitude: 40.7814, longitude: -73.9721,
                       normalizedX: 0.110, normalizedY: 0.342),
        ReferencePoint(name: "86 St (1)",
                       latitude: 40.7889, longitude: -73.9765,
                       normalizedX: 0.079, normalizedY: 0.330),
        ReferencePoint(name: "96 St (1/2/3)",
                       latitude: 40.7936, longitude: -73.9722,
                       normalizedX: 0.084, normalizedY: 0.320),
        ReferencePoint(name: "103 St (1)",
                       latitude: 40.7990, longitude: -73.9684,
                       normalizedX: 0.078, normalizedY: 0.300),
        ReferencePoint(name: "Cathedral Pkwy-110 St",
                       latitude: 40.8008, longitude: -73.9668,
                       normalizedX: 0.076, normalizedY: 0.289),
        ReferencePoint(name: "116 St-Columbia University",
                       latitude: 40.8075, longitude: -73.9643,
                       normalizedX: 0.078, normalizedY: 0.280),

        // Upper Manhattan
        ReferencePoint(name: "125 St (1)",
                       latitude: 40.8159, longitude: -73.9585,
                       normalizedX: 0.080, normalizedY: 0.271),
        ReferencePoint(name: "110 St-Malcolm X Plaza",
                       latitude: 40.7991, longitude: -73.9518,
                       normalizedX: 0.191, normalizedY: 0.289),
        ReferencePoint(name: "125 St (Lex)",
                       latitude: 40.8041, longitude: -73.9375,
                       normalizedX: 0.474, normalizedY: 0.310),
        ReferencePoint(name: "137 St-City College",
                       latitude: 40.8220, longitude: -73.9537,
                       normalizedX: 0.077, normalizedY: 0.255),
        ReferencePoint(name: "138 St-Grand Concourse",
                       latitude: 40.8132, longitude: -73.9298,
                       normalizedX: 0.268, normalizedY: 0.243),
        ReferencePoint(name: "145 St (1)",
                       latitude: 40.8241, longitude: -73.9438,
                       normalizedX: 0.079, normalizedY: 0.243),
        ReferencePoint(name: "168 St",
                       latitude: 40.8408, longitude: -73.9395,
                       normalizedX: 0.320, normalizedY: 0.195),
        ReferencePoint(name: "Inwood–207 St",
                       latitude: 40.8681, longitude: -73.9199,
                       normalizedX: 0.308, normalizedY: 0.130),

        // ── Brooklyn ──

        // Downtown Brooklyn
        ReferencePoint(name: "York St",
                       latitude: 40.7014, longitude: -73.9868,
                       normalizedX: 0.404, normalizedY: 0.619),
        ReferencePoint(name: "High St",
                       latitude: 40.6993, longitude: -73.9905,
                       normalizedX: 0.393, normalizedY: 0.669),
        ReferencePoint(name: "Clark St",
                       latitude: 40.6975, longitude: -73.9931,
                       normalizedX: 0.365, normalizedY: 0.684),
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
        ReferencePoint(name: "Hoyt-Schermerhorn",
                       latitude: 40.6884, longitude: -73.9850,
                       normalizedX: 0.418, normalizedY: 0.753),
        ReferencePoint(name: "Bergen St (2/3)",
                       latitude: 40.6809, longitude: -73.9754,
                       normalizedX: 0.495, normalizedY: 0.741),
        ReferencePoint(name: "Bergen St (F/G)",
                       latitude: 40.6835, longitude: -73.9830,
                       normalizedX: 0.404, normalizedY: 0.765),
        ReferencePoint(name: "Carroll St",
                       latitude: 40.6803, longitude: -73.9950,
                       normalizedX: 0.404, normalizedY: 0.775),
        ReferencePoint(name: "Smith-9 Sts",
                       latitude: 40.6736, longitude: -73.9960,
                       normalizedX: 0.421, normalizedY: 0.783),
        ReferencePoint(name: "4 Av-9 St",
                       latitude: 40.6706, longitude: -73.9890,
                       normalizedX: 0.456, normalizedY: 0.779),
        ReferencePoint(name: "Grand Army Plaza",
                       latitude: 40.6753, longitude: -73.9709,
                       normalizedX: 0.507, normalizedY: 0.749),
        ReferencePoint(name: "Prospect Av",
                       latitude: 40.6654, longitude: -73.9927,
                       normalizedX: 0.458, normalizedY: 0.791),
        ReferencePoint(name: "7 Av (B/Q)",
                       latitude: 40.6772, longitude: -73.9726,
                       normalizedX: 0.515, normalizedY: 0.731),
        ReferencePoint(name: "15 St-Prospect Park",
                       latitude: 40.6603, longitude: -73.9798,
                       normalizedX: 0.516, normalizedY: 0.793),
        ReferencePoint(name: "Fort Hamilton Pkwy",
                       latitude: 40.6509, longitude: -73.9766,
                       normalizedX: 0.531, normalizedY: 0.805),
        ReferencePoint(name: "25 St (R)",
                       latitude: 40.6604, longitude: -73.9981,
                       normalizedX: 0.460, normalizedY: 0.804),
        ReferencePoint(name: "Eastern Pkwy–Bklyn Museum",
                       latitude: 40.6720, longitude: -73.9644,
                       normalizedX: 0.521, normalizedY: 0.749),
        ReferencePoint(name: "Franklin Av-Medgar Evers College",
                       latitude: 40.6707, longitude: -73.9581,
                       normalizedX: 0.568, normalizedY: 0.742),
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

        // Brooklyn — G line
        ReferencePoint(name: "Greenpoint Av (G)",
                       latitude: 40.7313, longitude: -73.9544,
                       normalizedX: 0.374, normalizedY: 0.467),
        ReferencePoint(name: "Nassau Av (G)",
                       latitude: 40.7244, longitude: -73.9512,
                       normalizedX: 0.379, normalizedY: 0.487),
        ReferencePoint(name: "Broadway (G)",
                       latitude: 40.7106, longitude: -73.9502,
                       normalizedX: 0.456, normalizedY: 0.551),
        ReferencePoint(name: "Flushing Av (G)",
                       latitude: 40.7004, longitude: -73.9506,
                       normalizedX: 0.497, normalizedY: 0.593),
        ReferencePoint(name: "Myrtle-Willoughby Avs (G)",
                       latitude: 40.6946, longitude: -73.9493,
                       normalizedX: 0.497, normalizedY: 0.609),
        ReferencePoint(name: "Bedford-Nostrand Avs (G)",
                       latitude: 40.6896, longitude: -73.9535,
                       normalizedX: 0.497, normalizedY: 0.624),
        ReferencePoint(name: "Classon Av (G)",
                       latitude: 40.6889, longitude: -73.9601,
                       normalizedX: 0.497, normalizedY: 0.639),
        ReferencePoint(name: "Clinton-Washington Avs (G)",
                       latitude: 40.6857, longitude: -73.9663,
                       normalizedX: 0.498, normalizedY: 0.655),

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

    // MARK: - Reverse Mapping (pixel → GPS)

    /// Estimates the GPS coordinate corresponding to a normalized point on the map.
    /// Uses inverse distance weighting from the same reference points, but in reverse.
    static func imageToCoordinate(normalizedX: Double, normalizedY: Double) -> CLLocationCoordinate2D? {
        let power: Double = 2.5
        var weightedLat: Double = 0
        var weightedLon: Double = 0
        var totalWeight: Double = 0

        for ref in referencePoints {
            let dx = normalizedX - ref.normalizedX
            let dy = normalizedY - ref.normalizedY
            let distance = sqrt(dx * dx + dy * dy)

            // Very close to a reference point — use it directly
            if distance < 0.005 {
                return CLLocationCoordinate2D(latitude: ref.latitude, longitude: ref.longitude)
            }

            let weight = 1.0 / pow(distance, power)
            weightedLat += weight * ref.latitude
            weightedLon += weight * ref.longitude
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }

        return CLLocationCoordinate2D(
            latitude: weightedLat / totalWeight,
            longitude: weightedLon / totalWeight
        )
    }

    // MARK: - Helpers

    private static func clamp(_ point: CGPoint, within size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }
}
