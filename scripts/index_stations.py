#!/usr/bin/env python3
"""
Pre-index station text positions on the subway map via full-image OCR.

Uses Apple's Vision framework (via PyObjC) to detect all text on the subway map,
then fuzzy-matches recognized text against station names from stops_subway.json.
Outputs station_positions.json mapping station IDs to their visual position on the map.

Usage:
    python3 scripts/index_stations.py              # auto-match only
    python3 scripts/index_stations.py --interactive # prompt for unmatched stations

Requirements:
    pip3 install pyobjc-framework-Vision pyobjc-framework-Quartz
"""

import json
import math
import sys
from pathlib import Path

import Quartz
from Foundation import NSURL
import Vision


# All reference points from CoordinateMapper.swift — hand-calibrated pixel positions.
# Used for GPS→pixel interpolation AND as known positions for stations.
REFERENCE_POINTS = [
    # Manhattan - Lower
    {"name": "South Ferry", "lat": 40.7019, "lon": -74.0130, "nx": 0.246, "ny": 0.718},
    {"name": "Whitehall St", "lat": 40.7033, "lon": -74.0129, "nx": 0.248, "ny": 0.695},
    {"name": "Bowling Green", "lat": 40.7044, "lon": -74.0141, "nx": 0.270, "ny": 0.688},
    {"name": "Wall St", "lat": 40.7072, "lon": -74.0105, "nx": 0.324, "ny": 0.669},
    {"name": "Rector St", "lat": 40.7075, "lon": -74.0130, "nx": 0.240, "ny": 0.683},
    {"name": "Cortlandt St", "lat": 40.7118, "lon": -74.0120, "nx": 0.241, "ny": 0.669},
    {"name": "WTC Cortlandt", "lat": 40.7118, "lon": -74.0122, "nx": 0.165, "ny": 0.669},
    {"name": "Fulton St", "lat": 40.7092, "lon": -74.0065, "nx": 0.282, "ny": 0.656},
    {"name": "World Trade Center", "lat": 40.7126, "lon": -74.0098, "nx": 0.198, "ny": 0.651},
    {"name": "Chambers St (1/2/3)", "lat": 40.7143, "lon": -74.0071, "nx": 0.186, "ny": 0.617},
    {"name": "Chambers St (J/Z)", "lat": 40.7143, "lon": -74.0071, "nx": 0.298, "ny": 0.605},
    {"name": "Franklin St", "lat": 40.7193, "lon": -74.0069, "nx": 0.141, "ny": 0.601},
    {"name": "Canal St", "lat": 40.7197, "lon": -74.0023, "nx": 0.188, "ny": 0.587},
    {"name": "Prince St", "lat": 40.7243, "lon": -73.9977, "nx": 0.240, "ny": 0.566},
    {"name": "W 4 St-Wash Sq", "lat": 40.7322, "lon": -73.9970, "nx": 0.195, "ny": 0.541},
    {"name": "Brooklyn Bridge-City Hall", "lat": 40.7131, "lon": -74.0040, "nx": 0.268, "ny": 0.605},
    {"name": "Spring St", "lat": 40.7223, "lon": -73.9974, "nx": 0.184, "ny": 0.585},
    {"name": "Houston St", "lat": 40.7283, "lon": -74.0054, "nx": 0.141, "ny": 0.572},
    {"name": "Christopher St-Stonewall", "lat": 40.7334, "lon": -74.0029, "nx": 0.140, "ny": 0.559},
    {"name": "Bowery", "lat": 40.7203, "lon": -73.9939, "nx": 0.312, "ny": 0.576},
    {"name": "Spring St (6)", "lat": 40.7243, "lon": -74.0004, "nx": 0.277, "ny": 0.566},
    {"name": "Bleecker St", "lat": 40.7259, "lon": -73.9946, "nx": 0.278, "ny": 0.534},
    {"name": "Astor Pl", "lat": 40.7305, "lon": -73.9910, "nx": 0.277, "ny": 0.523},
    {"name": "Broadway-Lafayette St", "lat": 40.7254, "lon": -73.9960, "nx": 0.284, "ny": 0.551},
    # Manhattan - East Village / Gramercy (calibrated)
    {"name": "1 Av", "lat": 40.730953, "lon": -73.981628, "nx": 0.328, "ny": 0.511},
    {"name": "3 Av", "lat": 40.732849, "lon": -73.986122, "nx": 0.307, "ny": 0.513},
    {"name": "23 St (6)", "lat": 40.739864, "lon": -73.986599, "nx": 0.277, "ny": 0.488},
    {"name": "28 St (6)", "lat": 40.74307, "lon": -73.984264, "nx": 0.277, "ny": 0.476},
    {"name": "18 St", "lat": 40.74104, "lon": -73.997871, "nx": 0.142, "ny": 0.504},
    {"name": "2 Av", "lat": 40.723402, "lon": -73.989938, "nx": 0.333, "ny": 0.544},
    {"name": "21 St", "lat": 40.744065, "lon": -73.949724, "nx": 0.375, "ny": 0.416},
    {"name": "28 St (N/R/W)", "lat": 40.745494, "lon": -73.988691, "nx": 0.223, "ny": 0.487},
    {"name": "28 St (1)", "lat": 40.747215, "lon": -73.993365, "nx": 0.142, "ny": 0.486},
    {"name": "36 St (Brooklyn)", "lat": 40.655144, "lon": -74.003549, "nx": 0.461, "ny": 0.816},
    {"name": "42 St-Bryant Pk", "lat": 40.754222, "lon": -73.984569, "nx": 0.222, "ny": 0.429},
    {"name": "5 Av/53 St", "lat": 40.760167, "lon": -73.975224, "nx": 0.236, "ny": 0.396},
    {"name": "57 St", "lat": 40.763972, "lon": -73.97745, "nx": 0.209, "ny": 0.382},
    {"name": "7 Av (F/G)", "lat": 40.666271, "lon": -73.980305, "nx": 0.484, "ny": 0.782},
    # Manhattan - Midtown
    {"name": "14 St (1/2/3)", "lat": 40.7390, "lon": -73.9994, "nx": 0.107, "ny": 0.512},
    {"name": "14 St (F/M)", "lat": 40.7390, "lon": -73.9994, "nx": 0.148, "ny": 0.513},
    {"name": "14 St-Union Sq", "lat": 40.7359, "lon": -73.9906, "nx": 0.403, "ny": 0.539},
    {"name": "23 St (1)", "lat": 40.7435, "lon": -73.9940, "nx": 0.108, "ny": 0.494},
    {"name": "23 St (6 Av)", "lat": 40.7423, "lon": -73.9927, "nx": 0.390, "ny": 0.505},
    {"name": "33 St (6)", "lat": 40.7461, "lon": -73.9821, "nx": 0.277, "ny": 0.465},
    {"name": "34 St-Penn Station (1/2/3)", "lat": 40.7513, "lon": -73.9922, "nx": 0.107, "ny": 0.463},
    {"name": "34 St-Penn Station (A/C/E)", "lat": 40.7513, "lon": -73.9922, "nx": 0.148, "ny": 0.463},
    {"name": "34 St-Herald Sq (B/D/F/M)", "lat": 40.7496, "lon": -73.9879, "nx": 0.203, "ny": 0.455},
    {"name": "34 St-Herald Sq (N/Q/R/W)", "lat": 40.7496, "lon": -73.9879, "nx": 0.185, "ny": 0.450},
    {"name": "Times Sq-42 St (1/2/3)", "lat": 40.7554, "lon": -73.9870, "nx": 0.170, "ny": 0.427},
    {"name": "42 St-Port Authority", "lat": 40.7573, "lon": -73.9897, "nx": 0.106, "ny": 0.428},
    {"name": "47-50 Sts-Rockefeller Ctr", "lat": 40.7587, "lon": -73.9813, "nx": 0.210, "ny": 0.407},
    {"name": "49 St", "lat": 40.7599, "lon": -73.9841, "nx": 0.164, "ny": 0.404},
    {"name": "51 St", "lat": 40.7571, "lon": -73.9719, "nx": 0.276, "ny": 0.406},
    {"name": "57 St-7 Av", "lat": 40.7647, "lon": -73.9807, "nx": 0.167, "ny": 0.381},
    {"name": "Grand Central-42 St", "lat": 40.7520, "lon": -73.9774, "nx": 0.277, "ny": 0.429},
    # Manhattan - Upper
    {"name": "59 St-Columbus Circle", "lat": 40.7681, "lon": -73.9819, "nx": 0.106, "ny": 0.376},
    {"name": "Lexington Av/59 St", "lat": 40.7627, "lon": -73.9680, "nx": 0.460, "ny": 0.410},
    {"name": "Lexington Av/63 St", "lat": 40.7646, "lon": -73.9661, "nx": 0.252, "ny": 0.352},
    {"name": "68 St-Hunter College", "lat": 40.7681, "lon": -73.9639, "nx": 0.277, "ny": 0.342},
    {"name": "96 St (4/5/6)", "lat": 40.7889, "lon": -73.9588, "nx": 0.309, "ny": 0.310},
    {"name": "103 St (4/5/6)", "lat": 40.7954, "lon": -73.9591, "nx": 0.277, "ny": 0.300},
    {"name": "110 St (4/5/6)", "lat": 40.7950, "lon": -73.9443, "nx": 0.278, "ny": 0.292},
    {"name": "116 St (4/5/6)", "lat": 40.8019, "lon": -73.9487, "nx": 0.276, "ny": 0.281},
    {"name": "125 St (4/5/6)", "lat": 40.8046, "lon": -73.9484, "nx": 0.271, "ny": 0.271},
    {"name": "66 St-Lincoln Center", "lat": 40.7734, "lon": -73.9822, "nx": 0.084, "ny": 0.367},
    # Calibrated: 72, 77, 79, 86, 96 per-line
    {"name": "72 St (A/B/C)", "lat": 40.775594, "lon": -73.97641, "nx": 0.110, "ny": 0.355},
    {"name": "72 St (Q)", "lat": 40.768799, "lon": -73.958424, "nx": 0.308, "ny": 0.338},
    {"name": "77 St (4/6)", "lat": 40.77362, "lon": -73.959874, "nx": 0.277, "ny": 0.331},
    {"name": "79 St (1)", "lat": 40.783934, "lon": -73.979917, "nx": 0.080, "ny": 0.343},
    {"name": "86 St (A/B/C)", "lat": 40.785868, "lon": -73.968916, "nx": 0.112, "ny": 0.333},
    {"name": "86 St (4/5/6)", "lat": 40.779492, "lon": -73.955589, "nx": 0.274, "ny": 0.320},
    {"name": "86 St (Q)", "lat": 40.777891, "lon": -73.951787, "nx": 0.308, "ny": 0.320},
    {"name": "96 St (A/B/C)", "lat": 40.791642, "lon": -73.964696, "nx": 0.113, "ny": 0.321},
    {"name": "96 St (4/6)", "lat": 40.785672, "lon": -73.95107, "nx": 0.275, "ny": 0.310},
    {"name": "96 St (Q)", "lat": 40.784318, "lon": -73.947152, "nx": 0.308, "ny": 0.310},
    {"name": "72 St (1/2/3)", "lat": 40.7785, "lon": -73.9816, "nx": 0.082, "ny": 0.354},
    {"name": "72 St (B/C)", "lat": 40.7743, "lon": -73.9723, "nx": 0.112, "ny": 0.355},
    {"name": "81 St-Museum of Natural History", "lat": 40.7814, "lon": -73.9721, "nx": 0.110, "ny": 0.342},
    {"name": "86 St (1)", "lat": 40.7889, "lon": -73.9765, "nx": 0.079, "ny": 0.330},
    {"name": "96 St (1/2/3)", "lat": 40.7936, "lon": -73.9722, "nx": 0.084, "ny": 0.320},
    {"name": "103 St (1)", "lat": 40.7990, "lon": -73.9684, "nx": 0.078, "ny": 0.300},
    {"name": "Cathedral Pkwy-110 St", "lat": 40.8008, "lon": -73.9668, "nx": 0.076, "ny": 0.289},
    {"name": "116 St-Columbia University", "lat": 40.8075, "lon": -73.9643, "nx": 0.078, "ny": 0.280},
    {"name": "125 St (1)", "lat": 40.8159, "lon": -73.9585, "nx": 0.080, "ny": 0.271},
    {"name": "110 St-Malcolm X Plaza", "lat": 40.7991, "lon": -73.9518, "nx": 0.191, "ny": 0.289},
    {"name": "125 St (Lex)", "lat": 40.8041, "lon": -73.9375, "nx": 0.474, "ny": 0.310},
    {"name": "137 St-City College", "lat": 40.8220, "lon": -73.9537, "nx": 0.077, "ny": 0.255},
    {"name": "138 St-Grand Concourse", "lat": 40.8132, "lon": -73.9298, "nx": 0.268, "ny": 0.243},
    {"name": "145 St (1)", "lat": 40.8241, "lon": -73.9438, "nx": 0.079, "ny": 0.243},
    {"name": "168 St", "lat": 40.8408, "lon": -73.9395, "nx": 0.320, "ny": 0.195},
    {"name": "Inwood-207 St", "lat": 40.8681, "lon": -73.9199, "nx": 0.308, "ny": 0.130},
    # Brooklyn
    {"name": "York St", "lat": 40.7014, "lon": -73.9868, "nx": 0.404, "ny": 0.619},
    {"name": "High St", "lat": 40.6993, "lon": -73.9905, "nx": 0.393, "ny": 0.669},
    {"name": "Clark St", "lat": 40.6975, "lon": -73.9931, "nx": 0.365, "ny": 0.684},
    {"name": "Jay St-MetroTech", "lat": 40.6923, "lon": -73.9872, "nx": 0.402, "ny": 0.696},
    {"name": "Borough Hall", "lat": 40.6923, "lon": -73.9900, "nx": 0.374, "ny": 0.719},
    {"name": "DeKalb Av", "lat": 40.6906, "lon": -73.9818, "nx": 0.456, "ny": 0.693},
    {"name": "Hoyt St", "lat": 40.6884, "lon": -73.9850, "nx": 0.412, "ny": 0.724},
    {"name": "Nevins St", "lat": 40.6853, "lon": -73.9803, "nx": 0.434, "ny": 0.720},
    {"name": "Atlantic Av-Barclays Ctr", "lat": 40.6862, "lon": -73.9783, "nx": 0.499, "ny": 0.713},
    {"name": "Hoyt-Schermerhorn Sts", "lat": 40.6884, "lon": -73.9850, "nx": 0.418, "ny": 0.753},
    {"name": "Bergen St (2/3)", "lat": 40.6809, "lon": -73.9754, "nx": 0.495, "ny": 0.741},
    {"name": "Bergen St (F/G)", "lat": 40.6835, "lon": -73.9830, "nx": 0.404, "ny": 0.765},
    {"name": "Carroll St", "lat": 40.6803, "lon": -73.9950, "nx": 0.404, "ny": 0.775},
    {"name": "Smith-9 Sts", "lat": 40.6736, "lon": -73.9960, "nx": 0.421, "ny": 0.783},
    {"name": "4 Av-9 St", "lat": 40.6706, "lon": -73.9890, "nx": 0.456, "ny": 0.779},
    {"name": "Grand Army Plaza", "lat": 40.6753, "lon": -73.9709, "nx": 0.507, "ny": 0.749},
    {"name": "Prospect Av", "lat": 40.6654, "lon": -73.9927, "nx": 0.458, "ny": 0.791},
    {"name": "7 Av (B/Q)", "lat": 40.6772, "lon": -73.9726, "nx": 0.515, "ny": 0.731},
    {"name": "15 St-Prospect Park", "lat": 40.6603, "lon": -73.9798, "nx": 0.516, "ny": 0.793},
    {"name": "Fort Hamilton Pkwy", "lat": 40.6509, "lon": -73.9766, "nx": 0.531, "ny": 0.805},
    {"name": "25 St (R)", "lat": 40.6604, "lon": -73.9981, "nx": 0.460, "ny": 0.804},
    {"name": "Eastern Pkwy-Brooklyn Museum", "lat": 40.6720, "lon": -73.9644, "nx": 0.521, "ny": 0.749},
    {"name": "Franklin Av-Medgar Evers College", "lat": 40.6707, "lon": -73.9581, "nx": 0.568, "ny": 0.742},
    {"name": "Church Av", "lat": 40.6508, "lon": -73.9629, "nx": 0.435, "ny": 0.800},
    {"name": "Kings Highway", "lat": 40.6032, "lon": -73.9724, "nx": 0.420, "ny": 0.875},
    {"name": "Bay Ridge-95 St", "lat": 40.6167, "lon": -73.9936, "nx": 0.350, "ny": 0.860},
    {"name": "Coney Island-Stillwell Av", "lat": 40.5771, "lon": -73.9812, "nx": 0.403, "ny": 0.931},
    {"name": "Broadway Junction", "lat": 40.6783, "lon": -73.9053, "nx": 0.530, "ny": 0.760},
    {"name": "Canarsie-Rockaway Pkwy", "lat": 40.6462, "lon": -73.9017, "nx": 0.570, "ny": 0.840},
    {"name": "Greenpoint Av", "lat": 40.7313, "lon": -73.9544, "nx": 0.374, "ny": 0.467},
    {"name": "Nassau Av", "lat": 40.7244, "lon": -73.9512, "nx": 0.379, "ny": 0.487},
    {"name": "Broadway (G)", "lat": 40.7106, "lon": -73.9502, "nx": 0.456, "ny": 0.551},
    {"name": "Flushing Av (G)", "lat": 40.7004, "lon": -73.9506, "nx": 0.497, "ny": 0.593},
    {"name": "Myrtle-Willoughby Avs", "lat": 40.6946, "lon": -73.9493, "nx": 0.497, "ny": 0.609},
    {"name": "Bedford-Nostrand Avs", "lat": 40.6896, "lon": -73.9535, "nx": 0.497, "ny": 0.624},
    {"name": "Classon Av", "lat": 40.6889, "lon": -73.9601, "nx": 0.497, "ny": 0.639},
    {"name": "Clinton-Washington Avs", "lat": 40.6857, "lon": -73.9663, "nx": 0.498, "ny": 0.655},
    # Queens
    {"name": "Astoria-Ditmars Blvd", "lat": 40.7751, "lon": -73.9120, "nx": 0.560, "ny": 0.350},
    {"name": "Queensboro Plaza", "lat": 40.7509, "lon": -73.9402, "nx": 0.520, "ny": 0.420},
    {"name": "61 St-Woodside", "lat": 40.7454, "lon": -73.9030, "nx": 0.600, "ny": 0.430},
    {"name": "Jackson Hts-Roosevelt Av", "lat": 40.7466, "lon": -73.8914, "nx": 0.663, "ny": 0.408},
    {"name": "Forest Hills-71 Av", "lat": 40.7216, "lon": -73.8445, "nx": 0.730, "ny": 0.500},
    {"name": "Flushing-Main St", "lat": 40.7596, "lon": -73.8300, "nx": 0.805, "ny": 0.343},
    {"name": "Jamaica Center-Parsons/Archer", "lat": 40.7023, "lon": -73.8009, "nx": 0.853, "ny": 0.572},
    {"name": "Far Rockaway-Mott Av", "lat": 40.6033, "lon": -73.7551, "nx": 0.820, "ny": 0.900},
    # Bronx
    {"name": "161 St-Yankee Stadium", "lat": 40.8280, "lon": -73.9258, "nx": 0.426, "ny": 0.228},
    {"name": "Fordham Rd", "lat": 40.8614, "lon": -73.8975, "nx": 0.500, "ny": 0.160},
    {"name": "Pelham Bay Park", "lat": 40.8525, "lon": -73.8283, "nx": 0.687, "ny": 0.148},
    {"name": "Woodlawn", "lat": 40.8863, "lon": -73.8787, "nx": 0.520, "ny": 0.090},
    {"name": "Wakefield-241 St", "lat": 40.9032, "lon": -73.8507, "nx": 0.570, "ny": 0.055},
]


def gps_to_normalized(lat: float, lon: float) -> tuple[float, float] | None:
    """Approximate GPS->normalized position using inverse distance weighting."""
    power = 2.5
    wx, wy, tw = 0.0, 0.0, 0.0
    for ref in REFERENCE_POINTS:
        dlat = lat - ref["lat"]
        dlon = lon - ref["lon"]
        dist = math.sqrt(dlat * dlat + dlon * dlon)
        if dist < 0.0005:
            return ref["nx"], ref["ny"]
        w = 1.0 / (dist ** power)
        wx += w * ref["nx"]
        wy += w * ref["ny"]
        tw += w
    if tw == 0:
        return None
    return wx / tw, wy / tw


def load_image(path: str):
    """Load image and return CGImage + dimensions."""
    url = NSURL.fileURLWithPath_(path)
    source = Quartz.CGImageSourceCreateWithURL(url, None)
    if source is None:
        print(f"Error: Could not load image at {path}")
        sys.exit(1)
    cg_image = Quartz.CGImageSourceCreateImageAtIndex(source, 0, None)
    width = Quartz.CGImageGetWidth(cg_image)
    height = Quartz.CGImageGetHeight(cg_image)
    print(f"Loaded image: {width}x{height}")
    return cg_image, width, height


def run_ocr(cg_image) -> list[dict]:
    """Run Vision OCR on the full image with multiple candidates per observation."""
    results = []
    NUM_CANDIDATES = 3

    def handler(request, error):
        if error:
            print(f"OCR error: {error}")
            return
        observations = request.results()
        if not observations:
            return
        for obs in observations:
            candidates = obs.topCandidates_(NUM_CANDIDATES)
            if not candidates:
                continue
            bbox = obs.boundingBox()
            # Convert from Vision coords (origin bottom-left) to origin top-left
            x = bbox.origin.x
            y = 1.0 - bbox.origin.y - bbox.size.height
            w = bbox.size.width
            h = bbox.size.height
            cx = x + w / 2
            cy = y + h / 2
            # Store all candidate texts for this observation
            texts = [c.string() for c in candidates]
            results.append({
                "texts": texts,
                "text": texts[0],  # primary for backward compat
                "x": cx,
                "y": cy,
                "w": w,
                "h": h,
            })

    request = Vision.VNRecognizeTextRequest.alloc().initWithCompletionHandler_(handler)
    request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
    request.setRecognitionLanguages_(["en"])
    request.setUsesLanguageCorrection_(False)

    img_handler = Vision.VNImageRequestHandler.alloc().initWithCGImage_options_(cg_image, None)
    success = img_handler.performRequests_error_([request], None)
    if not success[0]:
        print(f"OCR perform failed: {success[1]}")
        sys.exit(1)

    print(f"OCR detected {len(results)} text regions ({NUM_CANDIDATES} candidates each)")
    return results


def load_stations(path: str) -> list[dict]:
    """Load station data from stops_subway.json."""
    with open(path) as f:
        return json.load(f)


def normalize(text: str) -> str:
    """Normalize text for comparison."""
    s = text.lower().replace("-", " ").replace("\u2013", " ").replace("\u2019", "").replace("'", "").replace(".", "")
    abbreviations = {
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
    }
    words = s.split()
    words = [abbreviations.get(w, w) for w in words]
    return " ".join(words).strip()


def clean_ocr_text(text: str) -> str:
    """Strip common OCR noise: leading/trailing route letters, symbols, numbers jammed onto text."""
    import re
    s = text.strip()
    # Remove common leading noise: route indicators like "6", "B-D", "M", "G", etc.
    s = re.sub(r'^[A-Z]-[A-Z]\s+', '', s)  # "B-D 174-175 Sts" -> "174-175 Sts"
    s = re.sub(r'^[A-GJ-NQ-Z]\s+', '', s)  # "G Flushing Av" -> "Flushing Av" (skip H,I,O,P which could be Avenue H etc)
    s = re.sub(r'^[0-9]-[0-9]\s+', '', s)  # "2-0 Gun Hill Rd" -> "Gun Hill Rd"
    s = re.sub(r'^\d\s+', '', s)            # "6 Spring St" -> "Spring St"
    # Remove trailing noise: route indicators, symbols
    s = re.sub(r'\s+[A-GJ-NQ-Z\d®©€&()\[\]]+\s*$', '', s)  # "145 St B" -> "145 St"
    s = re.sub(r'\s*[®©€&•*]+\s*$', '', s)
    s = re.sub(r'\s+\d+$', '', s)  # "Allerton Av 2-0" trailing numbers
    return s.strip()


ROUTE_LABELS = {
    "1", "2", "3", "4", "5", "6", "7",
    "a", "b", "c", "d", "e", "f", "g",
    "j", "l", "m", "n", "q", "r", "s", "w", "z",
    "si", "sf", "sr", "6x", "7x", "7d",
}


def is_route_label(text: str) -> bool:
    t = text.strip().lower()
    if t in ROUTE_LABELS:
        return True
    if len(t) <= 3 and all(c in "1234567abcdefgjlmnqrswz" for c in t):
        return True
    return False


def fuzzy_score(ocr_text: str, station_name: str) -> float:
    """Compute fuzzy match score between OCR text and station name (0.0-1.0)."""
    ocr = normalize(ocr_text)
    name = normalize(station_name)
    if not ocr or not name:
        return 0.0

    if ocr == name:
        return 1.0
    if name in ocr:
        return 0.95
    if ocr in name and len(ocr) >= 4:
        return 0.7 * len(ocr) / len(name)

    ocr_tokens = set(ocr.split())
    name_tokens = set(name.split())
    if ocr_tokens and name_tokens:
        intersection = ocr_tokens & name_tokens
        if intersection:
            recall = len(intersection) / len(name_tokens)
            precision = len(intersection) / len(ocr_tokens)
            f1 = 2 * precision * recall / (precision + recall)
            return f1 * 0.85

    for token in name_tokens:
        if len(token) >= 4:
            if token.startswith(ocr) or ocr.startswith(token):
                return 0.5

    return 0.0


def build_candidates(ocr_results: list[dict]) -> list[dict]:
    """Build candidate list from OCR results: raw texts, cleaned texts, and joined pairs."""
    filtered = [r for r in ocr_results if not is_route_label(r["text"])]
    print(f"After filtering route labels: {len(filtered)} text regions (removed {len(ocr_results) - len(filtered)})")

    candidates = []

    for r in filtered:
        # Add all OCR candidate texts for this observation
        for text in r.get("texts", [r["text"]]):
            if not is_route_label(text):
                candidates.append({"text": text, "x": r["x"], "y": r["y"], "w": r["w"], "h": r["h"]})
                # Also add cleaned version
                cleaned = clean_ocr_text(text)
                if cleaned and cleaned != text and not is_route_label(cleaned):
                    candidates.append({"text": cleaned, "x": r["x"], "y": r["y"], "w": r["w"], "h": r["h"]})

    # Join nearby consecutive text regions (station names may span lines)
    sorted_regions = sorted(filtered, key=lambda r: (r["y"], r["x"]))
    for i in range(len(sorted_regions) - 1):
        r1, r2 = sorted_regions[i], sorted_regions[i + 1]
        dy = abs(r2["y"] - r1["y"])
        dx = abs(r2["x"] - r1["x"])
        if dy < 0.015 and dx < 0.08:
            cx = (r1["x"] + r2["x"]) / 2
            cy = (r1["y"] + r2["y"]) / 2
            # Join primary texts
            candidates.append({"text": r1["text"] + " " + r2["text"], "x": cx, "y": cy, "w": 0, "h": 0})
            candidates.append({"text": r1["text"] + "-" + r2["text"], "x": cx, "y": cy, "w": 0, "h": 0})
            # Join cleaned texts
            c1 = clean_ocr_text(r1["text"])
            c2 = clean_ocr_text(r2["text"])
            if c1 and c2:
                candidates.append({"text": c1 + " " + c2, "x": cx, "y": cy, "w": 0, "h": 0})
                candidates.append({"text": c1 + "-" + c2, "x": cx, "y": cy, "w": 0, "h": 0})

    return candidates


def find_nearby_ocr(ocr_results: list[dict], approx_pos: tuple[float, float], radius: float = 0.06) -> list[dict]:
    """Find OCR text regions near an approximate position."""
    nearby = []
    for r in ocr_results:
        dx = r["x"] - approx_pos[0]
        dy = r["y"] - approx_pos[1]
        dist = math.sqrt(dx * dx + dy * dy)
        if dist < radius:
            nearby.append({"region": r, "dist": dist})
    nearby.sort(key=lambda x: x["dist"])
    return nearby


def find_reference_match(station: dict) -> dict | None:
    """Check if a station matches a hand-calibrated reference point by GPS proximity.
    Returns {"nx": x, "ny": y, "name": name} if found, else None."""
    best = None
    best_dist = float("inf")
    for ref in REFERENCE_POINTS:
        dlat = station["latitude"] - ref["lat"]
        dlon = station["longitude"] - ref["lon"]
        dist = math.sqrt(dlat * dlat + dlon * dlon)
        if dist < best_dist:
            best_dist = dist
            best = ref
    # Match if GPS coords are very close (same station complex)
    if best and best_dist < 0.002:
        return best
    return None


def match_stations(ocr_results: list[dict], stations: list[dict],
                   interactive: bool = False, manual_overrides: dict | None = None) -> tuple:
    """Match OCR text to stations using fuzzy matching + GPS proximity disambiguation."""
    candidates = build_candidates(ocr_results)
    print(f"Total candidates (with alternates and cleaned): {len(candidates)}")

    if manual_overrides is None:
        manual_overrides = {}

    positions = {}
    matched_names = []
    unmatched_stations = []

    for station in stations:
        # Skip stations that already have manual overrides
        if station["id"] in manual_overrides:
            continue

        approx_pos = gps_to_normalized(station["latitude"], station["longitude"])

        # Find ALL matching candidates above threshold
        matches = []
        for cand in candidates:
            score = fuzzy_score(cand["text"], station["name"])
            if score >= 0.55:
                matches.append((cand, score))

        if not matches:
            # Try reference point match before giving up
            ref = find_reference_match(station)
            if ref:
                positions[station["id"]] = {
                    "x": round(ref["nx"], 6),
                    "y": round(ref["ny"], 6),
                }
                matched_names.append(f"  {station['name']} (REF, from='{ref['name']}')")
            else:
                unmatched_stations.append(station)
            continue

        if len(matches) == 1 or approx_pos is None:
            best = max(matches, key=lambda m: m[1])
        else:
            best_score = max(m[1] for m in matches)
            top_matches = [(c, s) for c, s in matches if s >= best_score - 0.1]

            def gps_distance(cand):
                dx = cand["x"] - approx_pos[0]
                dy = cand["y"] - approx_pos[1]
                return math.sqrt(dx * dx + dy * dy)

            best = min(top_matches, key=lambda m: gps_distance(m[0]))

        cand, score = best
        # Sanity check: reject if OCR position is way too far from GPS estimate
        if approx_pos is not None:
            dx = cand["x"] - approx_pos[0]
            dy = cand["y"] - approx_pos[1]
            dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0.25 and score < 0.9:
                unmatched_stations.append(station)
                continue

        positions[station["id"]] = {
            "x": round(cand["x"], 6),
            "y": round(cand["y"], 6),
        }
        matched_names.append(f"  {station['name']} (score={score:.2f}, text='{cand['text']}')")

    # Interactive mode: prompt user for unmatched stations
    if interactive and unmatched_stations:
        print(f"\n{'='*60}")
        # Sort by primary route, then by latitude (north to south along each line)
        def station_sort_key(s):
            route = s["routes"][0] if s["routes"] else "ZZZ"
            # Group numbered routes first, then lettered
            if route.isdigit():
                route_key = f"0{route}"
            else:
                route_key = f"1{route}"
            return (route_key, -s["latitude"])  # negative lat = north first

        unmatched_stations.sort(key=station_sort_key)

        # Show route groupings
        routes_summary = {}
        for s in unmatched_stations:
            r = s["routes"][0] if s["routes"] else "?"
            routes_summary[r] = routes_summary.get(r, 0) + 1
        route_list = ", ".join(f"{r}({n})" for r, n in sorted(routes_summary.items()))

        print(f"Interactive mode: {len(unmatched_stations)} unmatched stations")
        print(f"Grouped by line: {route_list}")
        print(f"Enter number to pick, 's' to skip, 'q' to quit and save.")
        print(f"Or type x,y coords directly (e.g. '0.402,0.696') if none match.")
        print(f"Manual picks are saved to scripts/manual_overrides.json")
        print(f"and persist across re-runs.")
        print(f"{'='*60}\n")

        current_route = None
        still_unmatched = []
        for station in unmatched_stations:
            # Print route header when switching lines
            primary_route = station["routes"][0] if station["routes"] else "?"
            if primary_route != current_route:
                current_route = primary_route
                count = routes_summary[current_route]
                print(f"\n{'─'*40}")
                print(f"  Line {current_route} ({count} stations)")
                print(f"{'─'*40}")
            approx_pos = gps_to_normalized(station["latitude"], station["longitude"])
            if approx_pos is None:
                still_unmatched.append(station)
                continue

            nearby = find_nearby_ocr(ocr_results, approx_pos, radius=0.10)

            # Check if we have a hand-calibrated reference point for this station
            ref_match = find_reference_match(station)

            if not nearby and not ref_match:
                still_unmatched.append(station)
                continue

            # Show how many same-name stations exist and how many are already matched
            same_name = [s for s in stations if s["name"] == station["name"]]
            already_done = sum(1 for s in same_name if s["id"] in positions or s["id"] in manual_overrides)
            name_note = f" [{already_done}/{len(same_name)} same-name matched]" if len(same_name) > 1 else ""
            print(f"\n--- {station['name']} (id={station['id']}, routes={station['routes']}){name_note} ---")
            print(f"    Approx position: ({approx_pos[0]:.3f}, {approx_pos[1]:.3f})")

            if ref_match:
                print(f"      [R] REFERENCE: '{ref_match['name']}' at ({ref_match['nx']:.3f}, {ref_match['ny']:.3f}) ** calibrated **")

            for idx, entry in enumerate(nearby[:10]):
                r = entry["region"]
                all_texts = r.get("texts", [r["text"]])
                texts_str = " | ".join(all_texts)
                print(f"      [{idx}] '{texts_str}' at ({r['x']:.3f}, {r['y']:.3f}) dist={entry['dist']:.3f}")

            prompt_max = min(9, len(nearby) - 1) if nearby else -1
            ref_hint = "'r' for ref, " if ref_match else ""
            try:
                answer = input(f"    Pick [{ref_hint}0-{prompt_max}, x,y coords, 's'kip, 'q'uit]: ").strip()
            except (EOFError, KeyboardInterrupt):
                print("\nSaving progress...")
                still_unmatched.extend(unmatched_stations[unmatched_stations.index(station):])
                break

            if answer.lower() == 'q':
                print("Saving progress...")
                remaining_idx = unmatched_stations.index(station)
                still_unmatched.extend(unmatched_stations[remaining_idx:])
                break

            if answer.lower() == 's' or answer == '':
                still_unmatched.append(station)
                continue

            # Reference point match
            if answer.lower() == 'r' and ref_match:
                pos = {
                    "x": round(ref_match["nx"], 6),
                    "y": round(ref_match["ny"], 6),
                }
                positions[station["id"]] = pos
                manual_overrides[station["id"]] = pos
                matched_names.append(f"  {station['name']} (REF, from='{ref_match['name']}')")
                print(f"    -> Set from reference point ({ref_match['nx']:.3f}, {ref_match['ny']:.3f})")
                continue

            # Check if user entered raw x,y coordinates
            if ',' in answer:
                try:
                    parts = answer.split(',')
                    x_val = float(parts[0].strip())
                    y_val = float(parts[1].strip())
                    if 0 <= x_val <= 1 and 0 <= y_val <= 1:
                        pos = {
                            "x": round(x_val, 6),
                            "y": round(y_val, 6),
                        }
                        positions[station["id"]] = pos
                        manual_overrides[station["id"]] = pos
                        matched_names.append(f"  {station['name']} (MANUAL coords)")
                        print(f"    -> Set to ({x_val:.3f}, {y_val:.3f})")
                    else:
                        print("    Coords must be 0-1. Skipping.")
                        still_unmatched.append(station)
                except (ValueError, IndexError):
                    print("    Invalid format. Use 'x,y' e.g. '0.402,0.696'. Skipping.")
                    still_unmatched.append(station)
                continue

            try:
                choice = int(answer)
                if 0 <= choice < len(nearby):
                    r = nearby[choice]["region"]
                    pos = {
                        "x": round(r["x"], 6),
                        "y": round(r["y"], 6),
                    }
                    positions[station["id"]] = pos
                    manual_overrides[station["id"]] = pos
                    matched_names.append(f"  {station['name']} (MANUAL, text='{r['text']}')")
                    print(f"    -> Matched to ({r['x']:.3f}, {r['y']:.3f})")
                else:
                    print(f"    Invalid choice. Skipping.")
                    still_unmatched.append(station)
            except ValueError:
                print(f"    Invalid input. Skipping.")
                still_unmatched.append(station)

        unmatched_stations = still_unmatched

    unmatched_names = [s["name"] for s in unmatched_stations]
    return positions, matched_names, unmatched_names


def load_manual_overrides(path: Path) -> dict:
    """Load manually confirmed positions from a separate file (survives re-runs)."""
    if path.exists():
        with open(path) as f:
            return json.load(f)
    return {}


def save_manual_overrides(path: Path, overrides: dict):
    """Save manual overrides to a separate file."""
    with open(path, "w") as f:
        json.dump(overrides, f, indent=2)


def main():
    interactive = "--interactive" in sys.argv or "-i" in sys.argv

    project_root = Path(__file__).parent.parent
    image_path = project_root / "NYCUnderground" / "Assets.xcassets" / "subway-map.imageset" / "subway-map.png"
    stations_path = project_root / "NYCUnderground" / "stops_subway.json"
    output_path = project_root / "NYCUnderground" / "station_positions.json"
    overrides_path = project_root / "scripts" / "manual_overrides.json"

    if not image_path.exists():
        print(f"Error: Map image not found at {image_path}")
        sys.exit(1)
    if not stations_path.exists():
        print(f"Error: Station data not found at {stations_path}")
        sys.exit(1)

    # Load any previously saved manual overrides
    manual_overrides = load_manual_overrides(overrides_path)
    if manual_overrides:
        print(f"Loaded {len(manual_overrides)} manual overrides from previous runs")

    print("Loading map image...")
    cg_image, width, height = load_image(str(image_path))

    print("Running OCR on full map (this may take a minute)...")
    ocr_results = run_ocr(cg_image)

    print("Loading station database...")
    stations = load_stations(str(stations_path))
    print(f"Loaded {len(stations)} stations")

    print("Matching OCR text to stations...")
    positions, matched, unmatched = match_stations(
        ocr_results, stations, interactive=interactive, manual_overrides=manual_overrides
    )

    # Merge manual overrides (these take priority)
    override_count = 0
    for station_id, pos in manual_overrides.items():
        positions[station_id] = pos
        override_count += 1
    # Remove overridden stations from unmatched list
    override_ids = set(manual_overrides.keys())
    station_by_id = {s["id"]: s for s in stations}
    unmatched = [name for name in unmatched
                 if not any(s["id"] in override_ids for s in stations if s["name"] == name)]

    if override_count:
        print(f"Applied {override_count} manual overrides")

    # Save any new manual overrides from interactive session
    if interactive:
        save_manual_overrides(overrides_path, manual_overrides)

    print(f"\nMatched {len(positions)}/{len(stations)} stations:")
    for m in sorted(matched):
        print(m)

    if unmatched:
        print(f"\nUnmatched ({len(unmatched)}):")
        for name in sorted(unmatched):
            print(f"  {name}")

    # Write output
    with open(output_path, "w") as f:
        json.dump(positions, f, indent=2)
    print(f"\nWrote {output_path}")


if __name__ == "__main__":
    main()
