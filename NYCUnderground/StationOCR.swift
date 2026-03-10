import UIKit
import Vision

/// Uses Apple's Vision framework to recognize station name text near a tap point
/// on the subway map image, then fuzzy-matches against the station database.
enum StationOCR {

    /// Recognize stations near a tap point by reading text from the map image.
    /// - Parameters:
    ///   - image: The full subway map UIImage
    ///   - tapPoint: Tap location in image pixel coordinates
    ///   - imageSize: The display size of the image (for normalized coordinate validation)
    ///   - cropRadius: Half-width of the square crop region in pixels
    /// - Returns: Matched stations sorted by match confidence, or empty if none found
    static func recognizeStations(
        in image: UIImage,
        nearPoint tapPoint: CGPoint,
        imageSize: CGSize,
        cropRadius: CGFloat = 200
    ) async -> [Station] {
        guard let cgImage = image.cgImage else { return [] }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Crop a square region around the tap point (clamped to image bounds)
        let cropRect = CGRect(
            x: max(0, tapPoint.x - cropRadius),
            y: max(0, tapPoint.y - cropRadius),
            width: min(cropRadius * 2, imageWidth - max(0, tapPoint.x - cropRadius)),
            height: min(cropRadius * 2, imageHeight - max(0, tapPoint.y - cropRadius))
        )

        guard let croppedImage = cgImage.cropping(to: cropRect) else { return [] }

        // Run Vision text recognition
        let recognizedStrings = await performOCR(on: croppedImage)

        if !recognizedStrings.isEmpty {
            print("🔤 OCR near (\(Int(tapPoint.x)), \(Int(tapPoint.y))): \(recognizedStrings)")
        }

        // Match against station database
        let matched = matchStations(from: recognizedStrings)

        // Validate: only keep stations whose visual position is near the tap point.
        // This prevents OCR from matching a far-away station when text is ambiguous.
        let tapNormalized = CGPoint(x: tapPoint.x / imageSize.width, y: tapPoint.y / imageSize.height)
        let validated = matched.filter { station in
            guard let visualPos = StationDatabase.visualPosition(for: station) else { return true }
            let dx = tapNormalized.x - visualPos.x
            let dy = tapNormalized.y - visualPos.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance > 0.08 {
                print("🚫 OCR matched \(station.name) but too far from tap (dist=\(String(format: "%.3f", distance)))")
                return false
            }
            return true
        }

        return validated
    }

    // MARK: - Vision OCR

    private static func performOCR(on image: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var strings: [String] = []
                for observation in observations {
                    if let candidate = observation.topCandidates(1).first {
                        strings.append(candidate.string)
                    }
                }
                continuation.resume(returning: strings)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en"]
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("❌ OCR failed: \(error)")
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Fuzzy Matching

    /// Subway route identifiers that appear as labels on the map (circles with line names).
    /// These should not be matched as station names.
    private static let routeLabels: Set<String> = [
        "1", "2", "3", "4", "5", "6", "7",
        "a", "b", "c", "d", "e", "f", "g",
        "j", "l", "m", "n", "q", "r", "s", "w", "z",
        "si", "sf", "sr",  // Staten Island Railway
        // Common OCR misreads of route circles
        "6x", "7x", "7d",
    ]

    /// Returns true if the string looks like a route label or combination of route labels
    /// rather than a station name.
    private static func isRouteLabel(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        // Single route label
        if routeLabels.contains(trimmed) { return true }
        // Multiple route labels jammed together like "23" or "ACE"
        if trimmed.count <= 3 && trimmed.allSatisfy({ c in
            routeLabels.contains(String(c))
        }) { return true }
        return false
    }

    /// Match OCR text against station names. Returns stations sorted by best match.
    private static func matchStations(from ocrStrings: [String]) -> [Station] {
        let allStations = StationDatabase.stations

        // Filter out route labels (the circled line indicators on the map)
        let filtered = ocrStrings.filter { !isRouteLabel($0) }

        if filtered.count < ocrStrings.count {
            let dropped = ocrStrings.filter { isRouteLabel($0) }
            print("🚫 Filtered route labels: \(dropped)")
        }

        // Normalize OCR strings: join multi-line text, also try each line separately
        var candidates: [String] = []
        for s in filtered {
            candidates.append(s)
            // Also add joined pairs of consecutive OCR results (station names may span lines)
        }
        // Try joining consecutive OCR strings (station name might be split across lines)
        if filtered.count >= 2 {
            for i in 0..<(filtered.count - 1) {
                candidates.append(filtered[i] + " " + filtered[i + 1])
                candidates.append(filtered[i] + "-" + filtered[i + 1])
            }
        }

        var scored: [(Station, Double)] = []

        for station in allStations {
            let bestScore = candidates
                .map { fuzzyScore(ocrText: $0, stationName: station.name) }
                .max() ?? 0

            if bestScore > 0.4 {
                scored.append((station, bestScore))
            }
        }

        scored.sort { $0.1 > $1.1 }

        // Return top matches (usually 1-3 for a station complex)
        let results = scored.prefix(5).map(\.0)
        if !results.isEmpty {
            print("🎯 OCR matched: \(scored.prefix(5).map { "\($0.0.name) (\(String(format: "%.2f", $0.1)))" }.joined(separator: ", "))")
        }
        return Array(results)
    }

    /// Compute a fuzzy match score between OCR text and a station name (0.0–1.0).
    private static func fuzzyScore(ocrText: String, stationName: String) -> Double {
        let ocr = normalize(ocrText)
        let name = normalize(stationName)

        // Exact match
        if ocr == name { return 1.0 }

        // OCR text contains the full station name
        if ocr.contains(name) { return 0.95 }

        // Station name contains the OCR text (partial read)
        if name.contains(ocr) && ocr.count >= 4 {
            return 0.7 * Double(ocr.count) / Double(name.count)
        }

        // Token overlap: compare words
        let ocrTokens = Set(ocr.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        let nameTokens = Set(name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))

        if !ocrTokens.isEmpty && !nameTokens.isEmpty {
            let intersection = ocrTokens.intersection(nameTokens)
            if !intersection.isEmpty {
                // Weighted by how many name tokens matched
                let recall = Double(intersection.count) / Double(nameTokens.count)
                let precision = Double(intersection.count) / Double(ocrTokens.count)
                let f1 = 2 * precision * recall / (precision + recall)
                return f1 * 0.85
            }
        }

        // Check if OCR is a substring of any significant word in the station name
        for token in nameTokens where token.count >= 4 {
            if token.hasPrefix(ocr) || ocr.hasPrefix(String(token)) {
                return 0.5
            }
        }

        return 0
    }

    /// Normalize text for comparison: lowercase, expand common abbreviations.
    private static func normalize(_ text: String) -> String {
        var s = text.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "–", with: " ")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")

        // Expand common abbreviations used on MTA map
        let abbreviations = [
            "st": "street",
            "ave": "avenue",
            "av": "avenue",
            "sq": "square",
            "blvd": "boulevard",
            "pkwy": "parkway",
            "hts": "heights",
            "jct": "junction",
            "ctr": "center",
            "pk": "park",
            "pl": "place",
        ]

        // Only expand if the abbreviation is a standalone word
        var words = s.split(separator: " ").map(String.init)
        for i in words.indices {
            if let expanded = abbreviations[words[i]] {
                words[i] = expanded
            }
        }
        s = words.joined(separator: " ")

        return s.trimmingCharacters(in: .whitespaces)
    }
}
