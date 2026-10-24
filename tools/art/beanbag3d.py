"""A BEAN BAG THAT LOOKS LIKE ONE (owner round 48i: "the beanbag on the right, poorly designed and just looks like flat 2d trash bags").

The old ones were a polygon with two tones. A bean bag is recognised by its SHAPE (a slumped pear: wide soft base, a head that has fallen to one side), its PANELS (sewn gores running from the top
to the base, each one catching the light differently), its PIPING round the base and the carry-handle on top, and the creases where the filling has settled. This draws all of it from a surface
normal per pixel (light from the upper left, like everything else in the rooms) through the propkit's tone ramp, then a selective outline from the Layer.

`draw(c, cx, base_y, col)` stands one on the row `base_y`, `w` px wide and `h` tall, its head leaning `lean` px.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import propkit as K
from pixlib import hexc, shade


def draw(c, cx, base_y, col, w=34, h=22, lean=-3, seed=3, handle=True):
    """A lounger bean bag seen from the front-left: a tall back rest behind and a wide low seat in front (two soft lobes, the seat's rim lit over the back's belly), a dip in the seat, a
    gore seam down each lobe, a stitched foot, the creases of settled filling and a carry loop. `lean` shifts the back rest sideways (it slumps)."""
    rng = random.Random(seed)
    L = K.Layer(c)
    lc = L.c
    c.shadow(cx + 1, base_y + 1, w / 2.0 + 3, 2, 105)
    # --- the back rest, behind: an upright egg
    bx, by = cx + (6 if lean >= 0 else -6) + lean, base_y - h * 0.50
    brx, bry = w * 0.31, h * 0.50
    K.sphere(lc, bx, by, brx, bry, col, n=6, lo=0.44, hi=1.30)
    # --- the seat, in front: a wide low cushion
    sx, sy = cx - lean * 0.3, base_y - h * 0.30
    srx, sry = w * 0.50, h * 0.31
    K.sphere(lc, sx, sy, srx, sry, col, n=6, lo=0.44, hi=1.30)
    # the crease where the seat lies over the back rest: a dark line along the seat's top edge, a soft lit lip just under it
    for x in range(int(sx - srx * 0.80), int(sx + srx * 0.80) + 1):
        u = (x + 0.5 - sx) / srx
        y = int(round(sy - sry * math.sqrt(max(0.0, 1.0 - u * u)))) - 1
        lc.put(x, y, shade(col, 0.52))
        lc.put(x, y + 1, shade(col, 1.18))
    # the dip in the seat: a shaded oval with its back wall in shadow and its front edge catching the light
    dcx, dcy = sx + 1.0, sy - sry * 0.18
    for yy in range(int(dcy - 3), int(dcy + 4)):
        for xx in range(int(dcx - srx * 0.50), int(dcx + srx * 0.50) + 1):
            u = (xx + 0.5 - dcx) / (srx * 0.50)
            v = (yy + 0.5 - dcy) / 3.0
            if u * u + v * v <= 1.0:
                lc.put(xx, yy, shade(col, 0.70 if v < -0.2 else (0.86 if v < 0.45 else 1.12)))
    # the gore seams, following each lobe's curve
    for (ex, ey, erx, ery, us) in ((bx, by, brx, bry, (0.0,)), (sx, sy, srx, sry, (-0.62, 0.0, 0.62))):
        for u in us:
            for k in range(0, int(ery * 1.6)):
                v = -0.9 + k / (ery * 1.6) * 1.55
                xx = ex + u * erx * math.sqrt(max(0.0, 1.0 - v * v))
                yy = ey + v * ery
                if ex == sx and yy < dcy + 3.5:
                    continue
                if ex == bx and yy > sy - sry * 0.6:
                    continue
                lc.put(int(round(xx)), int(round(yy)), shade(col, 0.60))
    # the creases where the filling has settled
    for _ in range(3):
        x0 = sx + rng.uniform(-srx * 0.8, srx * 0.5)
        y0 = sy + rng.uniform(sry * 0.15, sry * 0.6)
        for k in range(5):
            lc.put(int(round(x0 + k * 0.9)), int(round(y0 + k * 0.4)), shade(col, 0.64 + 0.04 * k))
    # a stitched hem along the foot
    for x in range(int(sx - srx * 0.9), int(sx + srx * 0.9) + 1):
        if x % 3:
            lc.put(x, base_y - 2, shade(col, 0.6))
    # a carry loop at the top of the back rest
    if handle:
        tx, ty = int(round(bx)), int(round(by - bry)) + 1
        for dx, dy in ((-2, 0), (-1, -1), (0, -1), (1, -1), (2, 0)):
            lc.put(tx + dx, ty + dy, shade(col, 0.5))
        lc.put(tx, ty - 2, shade(col, 1.1))
    L.flush()
