#!/usr/bin/env python3
"""The HANDPRINT in the game's logo - one slim, believable hand as a single flat vector shape.

Owner round 48: the first version (pixel art, dithered pressure texture, brick-tower numerals) read as "AI crap": too much going on.
This one is deliberately plain - ONE flat colour, one clean outline, no texture - and gets its character from the DRAWING.

The two failures of the AI attempts it was set against ("too fat at the base and comically red, or red paint gore slop"):
  * no fat base: proportions are measured in palm-widths W (palm 0.9 wide x 1.0 long, middle finger 0.97, index 0.84, ring 0.88,
    pinky 0.66, finger width 0.19-0.22, a narrow thumb off the thenar swell) and the palm TAPERS to a wrist only 0.49 wide, cut off short (a print has no base);
  * no gore: no drips, splatter, gloss or texture.  (A first try cut thin joint creases across the fingers; they read as rings and
    bandages, so they went.)

Pure function (shapely): `hand_geometry()` -> a shapely (Multi)Polygon in palm-widths, +y DOWN, origin at the centre of the knuckle line.
"""
import math

from shapely import affinity
from shapely.geometry import Point, Polygon
from shapely.ops import unary_union

# anatomy table (palm-widths).  (name, base x, base y, lean in degrees, length, width at the base, width at the tip)
FINGERS = [
    ('index', -0.335, 0.02, -13.0, 0.80, 0.216, 0.180),
    ('middle', -0.112, -0.02, -4.0, 0.94, 0.226, 0.186),
    ('ring', 0.112, -0.005, 5.0, 0.86, 0.216, 0.176),
    ('pinky', 0.318, 0.05, 15.0, 0.64, 0.190, 0.156),
]
# the palm, clockwise from the index knuckle: a smooth closed curve through these points
PALM = [(-0.43, 0.06), (-0.22, -0.02), (0.00, -0.045), (0.20, -0.02), (0.40, 0.04), (0.435, 0.22), (0.425, 0.44), (0.385, 0.64),
        (0.33, 0.84), (0.27, 1.00), (0.25, 1.13), (-0.25, 1.13), (-0.26, 1.00), (-0.31, 0.90), (-0.40, 0.82), (-0.47, 0.64),
        (-0.45, 0.36), (-0.435, 0.16)]
THUMB = ((-0.29, 0.80), (-0.68, 0.64), (-0.84, 0.10), 0.33, 0.225)                  # a curve base -> control -> tip, base width, tip width
ROT = -9.0                                                                          # the hand is a little tilted, as a pressed hand is


def _catmull(pts, n=14):
    """A smooth CLOSED curve through `pts` (Catmull-Rom)."""
    out = []
    m = len(pts)
    for i in range(m):
        p0, p1, p2, p3 = pts[(i - 1) % m], pts[i], pts[(i + 1) % m], pts[(i + 2) % m]
        for k in range(n):
            t = k / float(n)
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 +
                                    (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    return out


def _stroke(path, w0, w1, steps=48):
    """A smooth tapered stroke: the union of the hulls of neighbouring circles along `path` (a function t -> (x, y))."""
    circles = []
    for i in range(steps + 1):
        t = i / float(steps)
        x, y = path(t)
        circles.append(Point(x, y).buffer((w0 + (w1 - w0) * t) / 2.0, 32))
    return unary_union([unary_union([circles[i], circles[i + 1]]).convex_hull for i in range(steps)])


def hand_geometry(rot=ROT):
    """-> shapely geometry of the hand, in palm-widths (W = 1), y down, rotated by `rot` degrees about the origin."""
    parts = [Polygon(_catmull(PALM))]
    for name, bx, by, lean, ln, w0, w1 in FINGERS:
        a = math.radians(lean)
        x0, y0 = bx, by + 0.10
        x1, y1 = x0 + math.sin(a) * ln, y0 - math.cos(a) * ln
        parts.append(_stroke(lambda t, x0=x0, y0=y0, x1=x1, y1=y1: (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t), w0, w1))
    (bx, by), (cx, cy), (tx, ty), tw0, tw1 = THUMB
    parts.append(_stroke(lambda t: ((1 - t) ** 2 * bx + 2 * (1 - t) * t * cx + t * t * tx, (1 - t) ** 2 * by + 2 * (1 - t) * t * cy + t * t * ty), tw0, tw1))
    g = unary_union(parts)
    g = g.buffer(0.022, join_style=1).buffer(-0.022, join_style=1)          # round the valleys between the fingers and at the thumb's web
    g = g.buffer(-0.010, join_style=1).buffer(0.010, join_style=1)          # and the corners (the wrist's)
    return affinity.rotate(g, rot, origin=(0, 0))


if __name__ == '__main__':
    g = hand_geometry()
    print(g.geom_type, [round(v, 3) for v in g.bounds])
