#!/usr/bin/env python3
# Generates App Store marketing screenshots (1320 x 2868) for NYC Underground.
# Each slide: branded gradient + headline + the app UI inside an iPhone frame.
# App UI is recreated faithfully from the SwiftUI source at 393x852 logical pt
# (the app is light-mode only — white background, MTA route-colored pills).
#
# The "map" hero is drawn as an ORIGINAL, stylized subway-line motif rather than
# the bundled MTA map image, so nothing copyrighted is redistributed in these
# marketing assets. To use a real capture for any slide, drop a 1320x2868 PNG
# into screenshots/raw/ with the matching filename and rerun.
#
#   pip install cairosvg   then   python3 AppStore/generate_screenshots.py

import os, math, base64, cairosvg

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "screenshots")
os.makedirs(OUT, exist_ok=True)

CW, CH = 1320, 2868            # required 6.9" screenshot size
ACCENT = "#3D9BFF"             # transit blue — headline highlight + glow
BLUE   = "#007AFF"             # iOS system blue (links, location dot)
GRAY   = "#8A8A8E"             # iOS secondary label
CHIP   = "#F2F2F7"            # systemGray6 (arrival chip background)
SEP    = "#E5E5EA"             # list separators
RED    = "#FF3B30"             # imminent arrival (<=1 min)

# Official-ish MTA route bullet colors (mirrors RoutePill.swift).
ROUTE = {
    "1": "#ED3D45", "2": "#ED3D45", "3": "#ED3D45",
    "4": "#009440", "5": "#009440", "6": "#009440",
    "7": "#B836AB",
    "A": "#003DA3", "C": "#003DA3", "E": "#003DA3",
    "B": "#FF6300", "D": "#FF6300", "F": "#FF6300", "M": "#FF6300",
    "G": "#6BBF42",
    "J": "#996638", "Z": "#996638",
    "L": "#999999",
    "N": "#FCCF1A", "Q": "#FCCF1A", "R": "#FCCF1A", "W": "#FCCF1A",
    "S": "#808080",
}
DARK_TEXT_ROUTES = {"N", "Q", "R", "W"}   # yellow lines use black text


# ---------- tiny svg helpers (operate in 393x852 screen space) ----------

def txt(x, y, s, text, color="#000000", weight="bold", anchor="start",
        op=1.0, family="DejaVu Sans", spacing=None):
    sp = f' letter-spacing="{spacing}"' if spacing is not None else ""
    text = text.replace("&", "&amp;")
    return (f'<text x="{x}" y="{y}" font-family="{family}" font-size="{s}" '
            f'font-weight="{weight}" fill="{color}" fill-opacity="{op}" '
            f'text-anchor="{anchor}"{sp}>{text}</text>')

def rrect(x, y, w, h, r, fill="#FFFFFF", op=1.0, stroke=None, sop=1.0, sw=1):
    s = (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" ry="{r}" '
         f'fill="{fill}" fill-opacity="{op}"')
    if stroke:
        s += f' stroke="{stroke}" stroke-opacity="{sop}" stroke-width="{sw}"'
    return s + "/>"

def circle(cx, cy, r, fill="none", op=1.0, stroke=None, sop=1.0, sw=1):
    s = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" fill-opacity="{op}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-opacity="{sop}" stroke-width="{sw}"'
    return s + "/>"

def line(x1, y1, x2, y2, color, w, op=1.0, cap="round"):
    return (f'<path d="M{x1} {y1} L{x2} {y2}" stroke="{color}" stroke-width="{w}" '
            f'stroke-opacity="{op}" stroke-linecap="{cap}" fill="none"/>')

def route_bullet(cx, cy, r, route):
    """Colored circle with the line letter/number, MTA-style."""
    color = ROUTE.get(route, "#808080")
    tc = "#000000" if route in DARK_TEXT_ROUTES else "#FFFFFF"
    fs = r * 1.15
    return (circle(cx, cy, r, color, 1.0)
            + f'<text x="{cx}" y="{cy + fs*0.36:.1f}" font-family="DejaVu Sans" '
              f'font-size="{fs:.1f}" font-weight="bold" fill="{tc}" '
              f'text-anchor="middle">{route}</text>')

def chevron_right(cx, cy, s, color, sw):
    return (f'<polyline points="{cx-s*0.3:.1f},{cy-s*0.5:.1f} {cx+s*0.3:.1f},{cy:.1f} '
            f'{cx-s*0.3:.1f},{cy+s*0.5:.1f}" fill="none" stroke="{color}" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>')

def location_pin(cx, cy, s, color):
    return (f'<path d="M{cx} {cy+s*0.55} C{cx-s*0.55} {cy} {cx-s*0.45} {cy-s*0.5} {cx} {cy-s*0.5} '
            f'C{cx+s*0.45} {cy-s*0.5} {cx+s*0.55} {cy} {cx} {cy+s*0.55} Z" fill="{color}"/>'
            + circle(cx, cy-s*0.08, s*0.18, "#FFFFFF", 1.0))


# ---------- iOS status bar (light mode -> dark glyphs) ----------

def status_bar(c="#000000"):
    g = txt(28, 34, 17, "9:41", c, "bold")
    bx = 300
    bars = "".join(rrect(bx + i*7, 30 - (5 + i*3), 4.5, 5 + i*3, 1.2, c, 1.0)
                   for i in range(4))
    wifi = (f'<g fill="none" stroke="{c}" stroke-width="2.2" stroke-linecap="round">'
            f'<path d="M333 22 a 9 9 0 0 1 14 0"/><path d="M336 26 a 5 5 0 0 1 8 0"/></g>'
            + circle(340, 30, 1.4, c, 1.0))
    batt = (rrect(353, 22, 22, 11, 3, "none", 0, c, 0.5, 1.4)
            + rrect(355, 24, 16, 7, 1.5, c, 1.0)
            + rrect(376, 25, 1.8, 5, 1, c, 0.6))
    return g + bars + wifi + batt

def nav_bar(title, light=True):
    c = "#000000" if light else "#FFFFFF"
    return (status_bar(c)
            + txt(196.5, 78, 17, title, c, "bold", "middle")
            + txt(369, 78, 16, "Done", BLUE, "bold", "end"))

def drag_indicator(color="#000000", op=0.18):
    return rrect(196.5-18, 12, 36, 5, 2.5, color, op)


# ---------- arrival chip + direction section (shared) ----------

def arrival_chip(x, y, route, mins):
    """Rounded gray chip: route bullet + 'N min'. Returns (svg, width)."""
    label = "Now" if mins == 0 else f"{mins} min"
    w = 56 + len(label) * 7
    tcolor = RED if mins <= 1 else "#000000"
    s = rrect(x, y, w, 30, 7, CHIP, 1.0)
    s += route_bullet(x + 18, y + 15, 9, route)
    s += txt(x + 33, y + 19, 13, label, tcolor, "bold", "start")
    return s, w

def direction_section(x, y, label, chips):
    s = [txt(x, y, 12, label, GRAY, "bold", "start", 1.0, spacing=0.6)]
    cx = x
    cy = y + 12
    for route, mins in chips:
        chip, w = arrival_chip(cx, cy, route, mins)
        s.append(chip)
        cx += w + 8
    return "".join(s), y + 12 + 30


# ---------- screens (each returns inner svg for 0..393 x 0..852) ----------

def stylized_map(dot_cx, dot_cy, big_pulse=False):
    """Original abstract subway network — NOT the MTA map image."""
    s = ['<rect x="0" y="0" width="393" height="852" fill="#F4F5F7"/>']
    # soft "water" wedge for a maplike feel
    s.append('<path d="M0 640 C120 600 150 740 393 700 L393 852 L0 852 Z" '
             'fill="#DCE8F5" fill-opacity="0.7"/>')
    # colored trunk lines (smooth diagonals), drawn thick with light casing
    lines = [
        ("M40 120 C140 220 150 420 120 760", "#ED3D45"),   # red 1/2/3
        ("M70 90 C200 240 230 520 300 800",  "#009440"),   # green 4/5/6
        ("M-10 300 C120 320 240 300 410 360", "#003DA3"),  # blue A/C/E
        ("M120 -10 C160 200 300 360 420 470", "#FF6300"),  # orange B/D/F/M
        ("M-10 520 C140 470 260 520 410 470", "#FCCF1A"),  # yellow N/Q/R/W
        ("M30 760 C160 700 250 640 410 600",  "#B836AB"),  # purple 7
    ]
    for d, col in lines:
        s.append(f'<path d="{d}" stroke="#FFFFFF" stroke-width="13" fill="none" '
                 f'stroke-linecap="round" stroke-opacity="0.9"/>')
    for d, col in lines:
        s.append(f'<path d="{d}" stroke="{col}" stroke-width="7" fill="none" '
                 f'stroke-linecap="round"/>')
    # interchange / station dots
    for (sx, sy, r) in [(120, 240, 6), (150, 360, 5), (210, 300, 7), (300, 470, 6),
                        (120, 520, 5), (250, 520, 6), (300, 640, 5), (95, 640, 6),
                        (230, 470, 5), (180, 470, 6)]:
        s.append(circle(sx, sy, r, "#FFFFFF", 1.0, "#3A3A3C", 1.0, 2))
    # user location dot with pulse rings
    if big_pulse:
        s.append(circle(dot_cx, dot_cy, 46, BLUE, 0.10))
        s.append(circle(dot_cx, dot_cy, 30, BLUE, 0.16))
    s.append(circle(dot_cx, dot_cy, 16, BLUE, 0.22))
    s.append(circle(dot_cx, dot_cy, 8, BLUE, 1.0, "#FFFFFF", 1.0, 2.5))
    return "".join(s)

def location_banner(near_name, sub, y=748):
    """The floating glass 'Near <station>' banner from ContentView."""
    s = [rrect(16, y, 361, 64, 16, "#FFFFFF", 0.96, "#000000", 0.06, 1)]
    # blue location dot with halo
    s.append(circle(44, y + 32, 9, BLUE, 0.25))
    s.append(circle(44, y + 32, 5, BLUE, 1.0))
    s.append(txt(70, y + 28, 15, near_name, "#000000", "bold", "start"))
    s.append(txt(70, y + 48, 12.5, sub, GRAY, "normal", "start"))
    s.append(chevron_right(350, y + 32, 11, GRAY, 2.4))
    return "".join(s)

def screen_map():
    s = [stylized_map(196.5, 380)]
    s.append(status_bar("#000000"))
    s.append(location_banner("Near Times Sq–42 St", "Very close"))
    return "".join(s)

def screen_locating():
    s = [stylized_map(196.5, 430, big_pulse=True)]
    s.append(status_bar("#000000"))
    # permission prompt pill (first-run) above the banner
    py = 672
    s.append(rrect(16, py, 361, 52, 14, "#FFFFFF", 0.96, "#000000", 0.06, 1))
    s.append(location_pin(40, py + 26, 15, BLUE))
    s.append(txt(64, py + 31, 15, "Show My Location", "#000000", "bold", "start"))
    s.append(chevron_right(352, py + 26, 10, GRAY, 2.2))
    s.append(location_banner("Near 14 St–Union Sq", "0.2 mi away", y=740))
    return "".join(s)

def screen_arrivals(station, routes, sections):
    s = ['<rect x="0" y="0" width="393" height="852" fill="#FFFFFF"/>']
    s.append(drag_indicator())
    s.append(nav_bar(station))
    # route pills row (the StationArrivalsView header)
    bx = 24
    for r in routes:
        s.append(route_bullet(bx + 14, 130, 14, r))
        bx += 34
    s.append(f'<rect x="24" y="158" width="345" height="1" fill="{SEP}"/>')
    y = 196
    for label, chips in sections:
        block, y = direction_section(24, y, label, chips)
        s.append(block)
        y += 30
    return "".join(s)

def screen_nearby():
    s = ['<rect x="0" y="0" width="393" height="852" fill="#FFFFFF"/>']
    s.append(drag_indicator())
    s.append(nav_bar("Nearby Stations"))
    rows = [
        ("Times Sq–42 St", ["N", "Q", "R", "W", "1", "2", "3", "7", "S"],
         "UPTOWN", [("N", 2), ("Q", 5), ("R", 9)]),
        ("34 St–Herald Sq", ["B", "D", "F", "M", "N", "Q", "R", "W"],
         "QUEENS", [("F", 1), ("M", 4), ("R", 7)]),
        ("Grand Central–42 St", ["4", "5", "6", "7", "S"],
         "DOWNTOWN", [("6", 3), ("4", 6), ("5", 11)]),
    ]
    y = 120
    for name, routes, dirlabel, chips in rows:
        s.append(txt(24, y + 22, 17, name, "#000000", "bold", "start"))
        # pills on the right (cap to keep clear of the station name)
        shown = routes[:5]
        bx = 369 - len(shown) * 26
        for r in shown:
            s.append(route_bullet(bx + 11, y + 17, 11, r))
            bx += 26
        # one direction row of chips
        block, _ = direction_section(24, y + 52, dirlabel, chips)
        s.append(block)
        y += 116
        s.append(f'<rect x="24" y="{y-18}" width="345" height="1" fill="{SEP}"/>')
    return "".join(s)


# ---------- compose marketing slide ----------

def _png_data_uri(path):
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("ascii")
    return "data:image/png;base64," + b64

def compose(filename, headline, subtitle, screen_svg=None, glow=ACCENT,
            screen_image=None, draw_island=None):
    """Render one marketing slide.

    Pass either screen_svg (synthetic UI) or screen_image (path to a real PNG
    capture, e.g. a 1320x2868 simulator screenshot). The chosen screen is placed
    inside the iPhone frame with the headline/gradient flair.
    """
    use_image = screen_image is not None
    if draw_island is None:
        draw_island = not use_image    # real captures already show the device top

    SW, SH = 864, int(864 * 852 / 393)
    FP = 30
    FW, FH = SW + 2*FP, SH + 2*FP
    FX = (CW - FW) // 2
    FY = 770
    SX, SY = FX + FP, FY + FP

    svg = []
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" '
               f'xmlns:xlink="http://www.w3.org/1999/xlink" '
               f'width="{CW}" height="{CH}" viewBox="0 0 {CW} {CH}">')
    svg.append('<defs>')
    svg.append('<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
               '<stop offset="0" stop-color="#0d1b2a"/>'
               '<stop offset="0.55" stop-color="#0a1320"/>'
               '<stop offset="1" stop-color="#070b12"/></linearGradient>')
    svg.append(f'<radialGradient id="glow" cx="0.5" cy="0.32" r="0.6">'
               f'<stop offset="0" stop-color="{glow}" stop-opacity="0.24"/>'
               f'<stop offset="1" stop-color="{glow}" stop-opacity="0"/></radialGradient>')
    svg.append('<linearGradient id="frame" x1="0" y1="0" x2="1" y2="1">'
               '<stop offset="0" stop-color="#2b313c"/>'
               '<stop offset="0.5" stop-color="#161a22"/>'
               '<stop offset="1" stop-color="#2b313c"/></linearGradient>')
    svg.append(f'<clipPath id="screenclip"><rect x="{SX}" y="{SY}" width="{SW}" height="{SH}" rx="86" ry="86"/></clipPath>')
    svg.append('</defs>')

    svg.append(f'<rect width="{CW}" height="{CH}" fill="url(#bg)"/>')
    svg.append(f'<rect width="{CW}" height="{CH}" fill="url(#glow)"/>')

    hy = 360
    fs = 104
    for ln in headline:
        accent = ln.startswith("*") and ln.endswith("*")
        text = ln.strip("*")
        color = glow if accent else "#FFFFFF"
        svg.append(f'<text x="{CW/2}" y="{hy}" font-family="DejaVu Sans" '
                   f'font-size="{fs}" font-weight="bold" fill="{color}" '
                   f'text-anchor="middle">{text}</text>')
        hy += 124
    if subtitle:
        svg.append(f'<text x="{CW/2}" y="{hy+6}" font-family="DejaVu Sans" font-size="46" '
                   f'font-weight="normal" fill="#FFFFFF" fill-opacity="0.55" '
                   f'text-anchor="middle">{subtitle}</text>')

    svg.append(f'<ellipse cx="{CW/2}" cy="{FY+FH+30}" rx="{FW*0.46}" ry="46" fill="#000000" fill-opacity="0.45"/>')

    svg.append(rrect(FX-6, FY-6, FW+12, FH+12, 122, "#000000", 0.6))
    svg.append(f'<rect x="{FX}" y="{FY}" width="{FW}" height="{FH}" rx="116" ry="116" fill="url(#frame)"/>')
    svg.append(rrect(FX+8, FY+8, FW-16, FH-16, 108, "#000000", 1.0))

    svg.append(f'<g clip-path="url(#screenclip)">')
    if use_image:
        svg.append(f'<image x="{SX}" y="{SY}" width="{SW}" height="{SH}" '
                   f'preserveAspectRatio="xMidYMid slice" '
                   f'xlink:href="{_png_data_uri(screen_image)}"/>')
    else:
        svg.append(f'<svg x="{SX}" y="{SY}" width="{SW}" height="{SH}" viewBox="0 0 393 852" preserveAspectRatio="xMidYMid slice">')
        svg.append(screen_svg)
        svg.append('</svg>')
    svg.append('</g>')

    if draw_island:
        isl_w, isl_h = 250, 74
        svg.append(rrect(CW/2 - isl_w/2, SY + 30, isl_w, isl_h, isl_h/2, "#000000", 1.0))

    svg.append('</svg>')
    data = "".join(svg)

    png = os.path.join(OUT, filename)
    cairosvg.svg2png(bytestring=data.encode(), write_to=png,
                     output_width=CW, output_height=CH)
    print("wrote", png)


# ---------- slides ----------
# To use a REAL screenshot for any slide, drop a 1320x2868 PNG with the same
# filename into screenshots/raw/ and rerun — it is framed with the same
# headline/gradient instead of the drawn UI.

TIMES_SQ = lambda: screen_arrivals(
    "Times Sq–42 St", ["N", "Q", "R", "W", "1", "2", "3", "7", "S"],
    [("UPTOWN & QUEENS", [("N", 2), ("Q", 5), ("R", 9)]),
     ("DOWNTOWN & BROOKLYN", [("1", 1), ("2", 4), ("3", 8)]),
     ("42 ST SHUTTLE", [("S", 0), ("S", 6)])])

ATLANTIC = lambda: screen_arrivals(
    "Atlantic Av–Barclays Ctr", ["B", "D", "N", "Q", "R", "2", "3", "4", "5"],
    [("MANHATTAN", [("4", 1), ("5", 3), ("2", 6)]),
     ("CONEY ISLAND & BAY RIDGE", [("N", 2), ("Q", 7), ("R", 12)]),
     ("BRONX & QUEENS", [("D", 4), ("B", 9)])])

# Per-slide accent = the MTA route-bullet color for that line group.
MTA_BLUE   = ROUTE["A"]   # #003DA3  (A/C/E)
MTA_RED    = ROUTE["1"]   # #ED3D45  (1/2/3)
MTA_GREEN  = ROUTE["4"]   # #009440  (4/5/6)
MTA_YELLOW = ROUTE["N"]   # #FCCF1A  (N/Q/R/W)
MTA_ORANGE = ROUTE["B"]   # #FF6300  (B/D/F/M)

SLIDES = [
    ("01-map.png",      ["The whole subway,", "*in your pocket.*"],
     "The official map, zoomable and bundled in.", screen_map,     MTA_BLUE),
    ("02-arrivals.png", ["Real-time arrivals,", "*one tap away.*"],
     "Tap any station for live train times.",      TIMES_SQ,       MTA_RED),
    ("03-nearby.png",   ["The closest trains,", "*right now.*"],
     "Your nearest stations, ranked by distance.", screen_nearby,  MTA_GREEN),
    ("04-location.png", ["Always know", "*where you are.*"],
     "A live GPS dot, right on the map.",          screen_locating, MTA_YELLOW),
    ("05-hub.png",      ["Every line,", "*every borough.*"],
     "All 445 stations. Live MTA data at your fingertips.", ATLANTIC,     MTA_ORANGE),
]

RAW = os.path.join(OUT, "raw")

for fname, headline, subtitle, screen_fn, glow in SLIDES:
    raw_path = os.path.join(RAW, fname)
    if os.path.exists(raw_path):
        compose(fname, headline, subtitle, glow=glow, screen_image=raw_path)
        print("   ^ framed real screenshot from raw/" + fname)
    else:
        compose(fname, headline, subtitle, screen_svg=screen_fn(), glow=glow)

print("done")
