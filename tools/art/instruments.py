"""MUSICAL INSTRUMENTS, drawn properly (owner round 48i: "the guitar looks like some bizarre flute thing... please rework musical instruments").

Why the first guitar failed: its body was 12 px wide and 17 tall with a black SQUARE for a sound hole and a 2 px stick for a neck, so at game zoom it read as a long thin pipe with a bulb on it. A real
acoustic guitar is half body, half neck, and the BODY is the thing the eye recognises: a wide lower bout, a pinched waist, a rounder upper bout, a ringed round sound hole above the waist, a bridge
low on the belly, a pickguard, a bound edge, the visible rim; then a slim fretboard with frets and dots, strings, a tapered headstock with tuning pegs. In wheel-of-proportions terms (a dreadnought,
100 cm long): body 50 cm long, lower bout 38 cm wide, waist 24 cm, upper bout 29 cm, neck + head 50 cm. At the rooms' ~52 px per metre that is a body 26 px long and 19 px wide at the lower bout.

`acoustic_guitar(lc, cx, by, ...)` draws the guitar ONLY (no stand, no shadow), on a scratch layer so the caller's `Layer.flush()` outlines it. Everything is per-pixel shaded: a spruce top lit from
the upper left with a sunburst edge and a faint grain, the dark rim visible down the right and under the belly, a cream binding, a lit left edge.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import hexc, shade, mix

BODY_LEN = 26                      # rows from the belly's lowest point to the neck joint
LOWER_W, UPPER_W, WAIST_W = 9.6, 7.4, 6.2
NECK_LEN = 17
HEAD_LEN = 8

CREAM = hexc('e8dcb8')
SILVER = hexc('c4c4bc')
BOARD = hexc('2e1c12')
WOOD_LT, WOOD_DK = hexc('9a6a3c'), hexc('5a3820')


def half_width(t):
    """Half the body's width at height t (0 at the belly's lowest point, 1 at the neck joint)."""
    lower = LOWER_W * math.sqrt(max(0.0, 1 - ((t - 0.30) / 0.34) ** 2)) if t < 0.64 else 0.0
    upper = UPPER_W * math.sqrt(max(0.0, 1 - ((t - 0.78) / 0.23) ** 2)) if t > 0.52 else 0.0
    w = max(lower, upper)
    if 0.50 < t < 0.66:
        w = max(w, WAIST_W + 0.6 * abs(t - 0.58) / 0.08)         # the waist, a soft pinch not a cut
    return w


def _grain(x, y):
    return 1.0 + 0.030 * math.sin(x * 2.1 + 0.4 * math.sin(y * 0.7)) + 0.018 * (((x * 7 + y * 3) % 5) / 4.0 - 0.5)


def acoustic_guitar(lc, cx, by, body, classical=False):
    """Draw an upright acoustic guitar. `cx` = the centre line (a pixel EDGE), `by` = the row of the belly's lowest point. Returns (head_top_y, body_top_y)."""
    top = by - BODY_LEN
    ctr_y = by - 0.30 * BODY_LEN
    edge_col = mix(shade(body, 0.40), hexc('4a1a0c'), 0.35)
    mid_col = shade(body, 0.80)
    cen_col = shade(body, 1.18)
    side_col = shade(body, 0.34)
    # --- the rim: the body's side seen down the right and under the belly (the instrument is turned a touch)
    for y in range(top - 1, by + 3):
        for x in range(int(cx - 14), int(cx + 16)):
            u = x + 0.5 - cx
            t = (by - (y + 0.5 - 1.0)) / BODY_LEN
            if 0.0 <= t <= 1.0 and abs(u - 1.6) <= half_width(t):
                lc.put(x, y, side_col)
    # --- the top plate
    for y in range(top, by + 1):
        t = (by - (y + 0.5)) / BODY_LEN
        w = half_width(t)
        if w <= 0.0:
            continue
        for x in range(int(cx - 14), int(cx + 15)):
            u = x + 0.5 - cx
            if abs(u) > w:
                continue
            d = (((u * 0.92) / 13.0) ** 2 + ((y + 0.5 - (by - 0.46 * BODY_LEN)) / 18.0) ** 2) ** 0.5
            col = cen_col if d < 0.42 else body if d < 0.66 else mid_col if d < 0.86 else edge_col
            col = shade(col, _grain(x, y))
            # light from the upper left: the left rim catches it, the right and lower rim fall away
            edge_d = w - abs(u)
            if edge_d < 1.1:
                col = shade(col, 1.0) if u > 0 else shade(col, 1.18)
                col = binding_col(u, y, by, body)
            elif edge_d < 2.1 and u > 0:
                col = shade(col, 0.86)
            lc.put(x, y, col)
    # --- sound hole, ringed by a rosette
    hy = by - 0.665 * BODY_LEN
    for y in range(int(hy - 6), int(hy + 7)):
        for x in range(int(cx - 6), int(cx + 7)):
            u, v = x + 0.5 - cx, y + 0.5 - hy
            r = math.hypot(u, v)
            if r <= 3.1:
                inner = hexc('140a06')
                if v > 1.0 and u < 0.5:
                    inner = hexc('2a1810')                                   # the lit far wall inside the hole
                lc.put(x, y, inner)
            elif r <= 4.2:
                a = int((math.atan2(v, u) + math.pi) / (2 * math.pi) * 12)
                lc.put(x, y, hexc('c8a870') if a % 2 == 0 else hexc('4a2c18'))
            elif r <= 4.9:
                lc.put(x, y, hexc('2a1810'))
    # --- the pickguard: a dark tortoiseshell teardrop below-right of the hole
    for y in range(int(hy), int(hy + 11)):
        for x in range(int(cx + 1), int(cx + 10)):
            u, v = x + 0.5 - (cx + 5.0), y + 0.5 - (hy + 5.5)
            if (u / 3.4) ** 2 + (v / 5.0) ** 2 <= 1.0 and abs(x + 0.5 - cx) < half_width((by - (y + 0.5)) / BODY_LEN) - 1.4 and math.hypot(x + 0.5 - cx, y + 0.5 - hy) > 5.0:
                lc.put(x, y, hexc('4a2a14') if (x + y) % 5 == 0 else hexc('241208'))
    # --- the bridge, its saddle and the pins
    for y, col in ((by - 5, hexc('4a2e1e')), (by - 4, hexc('2a1810')), (by - 3, hexc('201208'))):
        lc.hline(int(cx - 5), int(cx + 4), y, col)
    lc.hline(int(cx - 3), int(cx + 2), by - 6, CREAM)                                              # the saddle
    for k in range(-2, 2):
        lc.put(int(cx + k * 2 + 1), by - 4, hexc('e0d8c0'))                                        # bridge pins
    # --- strings: two pale lines from the saddle across the hole and up the board
    for sx, amt in ((int(cx) - 1, 0.22), (int(cx), 0.14)):
        for y in range(top, by - 6):
            if abs(y + 0.5 - hy) <= 5.0:
                continue                                                                             # over the hole the strings are lost in the dark
            under = lc.px[sx, y] if 0 <= sx < lc.w and 0 <= y < lc.h else (0, 0, 0, 0)
            if under[3]:
                lc.put(sx, y, mix(under, SILVER, amt))
    # --- the neck: a slim rosewood board between two strips of lit / shaded wood, frets, dots
    ny = top - NECK_LEN
    for y in range(ny, top + 1):
        lc.put(int(cx) - 2, y, WOOD_LT)
        lc.put(int(cx) - 1, y, BOARD)
        lc.put(int(cx), y, BOARD)
        lc.put(int(cx) + 1, y, WOOD_DK)
    for fy in range(ny + 2, top - 1, 3):
        lc.hline(int(cx) - 1, int(cx), fy, SILVER)                                                 # frets
    for fy in (ny + 5, ny + 11):
        lc.put(int(cx) - 1, fy + 1, CREAM)                                                          # position dots
    for y in range(ny + 2, top + 1):                                                               # strings along the board
        for sx, amt in ((int(cx) - 1, 0.40), (int(cx), 0.26)):
            if lc.px[sx, y] == BOARD or True:
                lc.put(sx, y, mix(lc.px[sx, y], SILVER, amt))
    lc.hline(int(cx) - 2, int(cx) + 1, ny, CREAM)                                                  # the nut
    # --- the headstock: a tapered paddle, dark face, a lit left edge, three tuning pegs a side
    hy0 = ny - HEAD_LEN
    for y in range(hy0, ny):
        k = (ny - y) / float(HEAD_LEN)
        half = 2.0 + 1.6 * math.sin(min(1.0, k * 1.15) * math.pi / 2)
        x0, x1 = int(round(cx - half)), int(round(cx + half)) - 1
        for x in range(x0, x1 + 1):
            col = hexc('2a1810') if not classical else hexc('4a2c18')
            if x == x0:
                col = WOOD_LT
            elif x == x1:
                col = hexc('1a0e08')
            lc.put(x, y, col)
    for k, py in enumerate((hy0 + 1, hy0 + 3, hy0 + 5)):
        lc.put(int(cx) - 4, py, SILVER); lc.put(int(cx) - 5, py, hexc('8a8a84'))
        lc.put(int(cx) + 3, py, SILVER); lc.put(int(cx) + 4, py, hexc('8a8a84'))
    lc.hline(int(cx) - 1, int(cx), hy0 + 1, hexc('4a3020'))                                        # the maker's mark
    return hy0, top


def binding_col(u, y, by, body):
    """The cream binding round the top's edge: bright on the lit left, dim on the shaded right."""
    c = CREAM if u < 0 else mix(CREAM, hexc('3a2414'), 0.45)
    return c
