"""THE SMALL THINGS EVERY BAKED ROOM SHARES — drawn with volume (owner round 48j: "every item needs to have depth and not just be flat 2D. We really need consistency on this across the board").

`tools/art/furn.py` holds the helpers the baked room modules call for the small things — a pendant, a table lamp, a potted plant, a tin, a bin bag, a cardboard box, a stack of books. They were
silhouettes (a lamp shade a filled trapezoid, a plant a handful of sticks, a box a front face with a label), while the furniture library (data/furniture.json) and the corridor props are shaded
solids. Each helper in furn.py now delegates here, to the same kit the library uses (`propkit` shaded cylinders / frustums / spheres / slabs, `corridor_props3d` boxes / sacks / rods / leaves):
a lit left, a shaded right, a visible top or rim, a contact shadow, a selective outline — and the SAME signature and footprint as before, so no room's layout, node or light moves.

Every function draws on the canvas it is given (a room canvas, or the layer `pixlib.setback` hands a piece) through a `propkit.Layer`, so the outline is added once round the whole thing.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import corridor_props3d as CP
import propkit as K
from pixlib import hexc, shade

_CORD = hexc('2a2622')


def _rose(c, x):
    """The ceiling rose a flex hangs from."""
    c.hline(x - 2, x + 2, 0, hexc('cfc8b8'))
    c.hline(x - 1, x + 1, 1, hexc('8a8478'))


# ================================================================================================================================ ceiling lights
def pendant(c, x, drop, sc, sd, dome):
    """A pendant: the flex and its rose, a shade lit on the left and shaded on the right with its rim bowed toward us, the bulb glinting under it."""
    L = K.Layer(c)
    lc = L.c
    _rose(lc, x)
    lc.vline(x, 2, drop - 7, _CORD)
    top_ = drop - 6
    K.sphere(lc, x, drop + 2.2, 1.7, 1.6, hexc('f0e6c8'), n=3, lo=0.8, hi=1.1)                    # the bulb under the rim
    if dome:
        # a paper dome: a half sphere, its rim a darker band, a lit seam up the left
        K.sphere(lc, x, drop - 1.0, 7.2, 5.0, sc, n=5, lo=0.62, hi=1.16)
        px = lc.img.load()
        for yy in range(int(drop) + 1, int(drop) + 7):                                                # the lower half is not there
            for xx in range(int(x) - 9, int(x) + 10):
                px[xx, yy] = (0, 0, 0, 0)
        lc.hline(x - 7, x + 6, drop, sd)
        lc.hline(x - 6, x + 5, drop + 1, shade(sd, 0.8))
    else:
        K.frustum(lc, x, top_, drop, 2.2, 7.3, sc, ry_t=0.8, ry_b=1.8, rim=shade(sc, 1.22), n=5, lo=0.6, hi=1.18, band=(sd, 1))
    L.flush()


def bare_bulb(c, x, drop):
    """A bare bulb on a flex: a socket with a ridge, a glass bulb with a highlight."""
    L = K.Layer(c)
    lc = L.c
    lc.vline(x, 0, drop - 4, _CORD)
    K.cyl(lc, x, drop - 3.6, drop - 2.0, 1.7, hexc('6e6e6a'), ry=0.6, n=4)
    lc.hline(x - 1, x + 1, drop - 2, shade(hexc('6e6e6a'), 0.7))
    K.sphere(lc, x, drop + 0.4, 2.5, 2.6, hexc('ece6d0'), n=4, lo=0.72, hi=1.12, gloss=True)
    L.flush()


def flush_light(c, x):
    """A flush ceiling dome: a shallow glass bowl seen from below the rim, a lit left, a darker mounting ring."""
    L = K.Layer(c)
    lc = L.c
    K.sphere(lc, x, 0.5, 8.0, 3.8, hexc('e6e0d0'), n=5, lo=0.62, hi=1.12)
    lc.hline(x - 8, x + 7, 0, hexc('bdb6a4'))
    L.flush()


def tube_light(c, x, w):
    """A fluorescent batten: a steel housing with a lit top edge, the opal lens along its underside, end caps."""
    L = K.Layer(c)
    lc = L.c
    x0, x1 = x - w // 2, x + w // 2
    K.slab(lc, x0, 0, x1, 2, hexc('c9c6bc'), d=0, inset=0, n=4, lo=0.7, hi=1.1)
    lc.hline(x0 + 1, x1 - 1, 3, hexc('eef0ec'))
    for ex in (x0, x1):
        lc.put(ex, 3, hexc('7a7870'))
        lc.vline(ex, 0, 2, hexc('8a8880'))
    L.flush()


# ================================================================================================================================ lamps
def table_lamp(c, x, surface, sc, sd, bc, tall):
    """A table lamp: a turned foot, a stem, a fabric shade (lit left, shaded right, its rim bowed, a darker hem). Same height as before."""
    L = K.Layer(c)
    lc = L.c
    h = 8 if tall else 5
    K.cyl(lc, x, surface - 2.4, surface - 0.6, 2.7, bc, ry=0.9, n=4, lo=0.55, hi=1.25)               # the foot
    CP.rod(lc, (x + 0.5, surface - 2.0), (x + 0.5, surface - 2 - h - 1.5), 0.8, 0.8, bc, n=4)         # the stem
    top = surface - 2 - h - 7
    K.frustum(lc, x, top, top + 6, 3.0, 5.2, sc, ry_t=0.8, ry_b=1.5, rim=shade(sc, 1.2), n=5, lo=0.6, hi=1.18, band=(sd, 1))
    L.flush()
    return top


def desk_lamp(c, x, surface, k, facing):
    """An anglepoise: a weighted foot, two jointed arms (round rods), a shaded head tipped toward the desk."""
    L = K.Layer(c)
    lc = L.c
    K.cyl(lc, x, surface - 2.4, surface - 0.8, 3.4, k, ry=1.1, n=4, lo=0.55, hi=1.3)
    CP.rod(lc, (x + 0.5, surface - 2.0), (x - 2 * facing + 0.5, surface - 9.0), 0.8, 0.8, k, n=4, hi=1.4)
    K.sphere(lc, x - 2 * facing + 0.5, surface - 9.0, 1.4, 1.4, k, n=4, hi=1.4)
    CP.rod(lc, (x - 2 * facing + 0.5, surface - 9.0), (x + 4 * facing + 0.5, surface - 14.0), 0.8, 0.8, k, n=4, hi=1.4)
    hx = x + 6 * facing
    K.frustum(lc, hx, surface - 16, surface - 11, 2.8, 4.6, k, ry_t=0.9, ry_b=1.6, rim=shade(k, 1.5), n=5, lo=0.55, hi=1.5)
    L.flush()
    return hx


def floor_lamp(c, x, top, base, shade_col, pole):
    """A standard lamp: a weighted foot disc, a slim pole, a drum-ish shade lit on the left."""
    L = K.Layer(c)
    lc = L.c
    K.cyl(lc, x, base - 1.4, base - 0.4, 4.4, pole, ry=1.3, n=4, lo=0.55, hi=1.3)
    CP.rod(lc, (x + 0.5, top + 11.0), (x + 0.5, base - 1.5), 0.8, 0.8, pole, n=4, hi=1.4)
    K.frustum(lc, x, top, top + 10, 4.4, 8.4, shade_col, ry_t=1.1, ry_b=2.2, rim=shade(shade_col, 1.2), n=5, lo=0.6, hi=1.18, band=(shade(shade_col, 0.78), 1))
    L.flush()


def candle(c, x, base, h):
    """A candle: a wax cylinder lit on the left, its top softened, a wick, a drip down one side."""
    L = K.Layer(c)
    lc = L.c
    wax = hexc('e3dcc6')
    K.cyl(lc, x, base - h + 0.6, base - 0.6, 1.7, wax, ry=0.7, n=4, lo=0.7, hi=1.12)
    lc.put(x, base - h - 1, hexc('3a2a1a'))
    lc.put(x + 1, base - h + 1, shade(wax, 0.88)) if h > 3 else None
    L.flush()


# ================================================================================================================================ plants, bins, tins, boxes
def potted_plant(c, cx, base, dead, big, seed=3):
    """A pot plant: a terracotta pot with a rolled rim and soil, leaves each a shaded blade fanned out of the middle (dead ones yellowed and drooping)."""
    L = K.Layer(c)
    lc = L.c
    rng = random.Random(seed + (5 if dead else 0) + (3 if big else 0))
    pot = hexc('9a5a3a')
    c.shadow(cx, base, 8, 2, 90)
    K.frustum(lc, cx, base - 11, base - 1, 6.0, 4.2, pot, ry_t=1.7, ry_b=1.0, rim=shade(pot, 1.32), n=5, lo=0.5, hi=1.32)
    for x in range(int(cx - 6), int(cx + 6)):                                    # the rolled rim: a band under the lip
        u = (x + 0.5 - cx) / 6.0
        if abs(u) <= 1.0:
            lc.put(x, base - 10, shade(pot, 1.12 - 0.35 * max(0.0, u + 0.2)))
    CP.soil_top(lc, cx, base - 11, 4.6, 1.3, seed)
    leaf = [hexc('4d6a3c'), hexc('5e8240')] if not dead else [hexc('8a7a42'), hexc('6a5a34')]
    n = 8 if big else 6
    reach = 22.0 if big else 14.0
    for i in range(n):
        t = i / float(n - 1)
        spread = (2.3 if big else 2.5) if not dead else 2.9
        ang = -math.pi / 2.0 + (t - 0.5) * spread + rng.uniform(-0.08, 0.08)
        Ln = reach * (0.78 + 0.3 * rng.random()) * (1.0 - 0.25 * abs(t - 0.5) * 2.0)
        droop = (0.30 + 0.30 * rng.random()) if dead else 0.06 + 0.22 * abs(t - 0.5) * 2.0
        CP.leaf(lc, cx + (t - 0.5) * 3.0, base - 11.5, ang, Ln, 3.6 if big else 3.2, leaf[i % 2], droop=droop)
    L.flush()


def waste_basket(c, cx, base, r, h, body, paper):
    """A mesh wastepaper basket: a tapering cylinder with bands, a rolled rim, the dark inside and crumpled paper heaped in it."""
    L = K.Layer(c)
    lc = L.c
    top = base - h
    c.shadow(cx + 1, base + 1, r + 2, 1.5, 110)
    K.frustum(lc, cx, top, base - 1, r, r - 1.4, body, ry_t=max(1.5, r * 0.38), ry_b=1.1, inner=hexc('141418'), rim=shade(body, 1.4), n=5, lo=0.55, hi=1.3)
    for yy in range(top + 2, base - 1, 3):                                       # the mesh bands
        rr = r - 1.4 * (yy - top) / float(max(1, h))
        for x in range(int(cx - rr) + 1, int(cx + rr)):
            u = (x + 0.5 - cx) / rr
            if abs(u) < 1.0:
                lc.put(x, yy, shade(body, 1.16 - 0.4 * max(0.0, u)))
    if paper:
        for (dx, dy, rr_) in ((-2, -1, 2.0), (1, -2, 2.4), (3, 0, 1.6)):
            K.sphere(lc, cx + dx, top + dy, rr_, rr_ * 0.85, hexc('e6e0cc'), n=4, lo=0.68, hi=1.15)
    L.flush()


def tin(c, cx, base, r, h, body, label, lid, open_col, handle):
    """A tin / paint can: a cylinder lit on the left, a label band that follows its curve, a rolled seam top and bottom, a lid (or open, with the paint inside), a wire handle."""
    L = K.Layer(c)
    lc = L.c
    ry = max(1.0, r * 0.4)
    top = base - h
    c.shadow(cx + 1, base + 1, r + 2, 1.5, 100)
    K.cyl(lc, cx, top, base - 1, r, body, ry=ry, cap=True, cap_col=shade(lid, 0.9) if open_col is None else shade(lid, 0.8), inner=open_col, n=5, lo=0.5, hi=1.3)
    if label is not None:
        lt_ = top + max(2, h // 3)
        lh = max(2, h // 3)
        for x in range(int(cx - r), int(cx + r)):
            u = (x + 0.5 - cx) / float(r)
            if abs(u) > 1.0:
                continue
            nz = math.sqrt(1.0 - u * u)
            col = shade(label, 1.12 - 0.5 * max(0.0, u + 0.35))
            for yy in range(lt_, lt_ + lh + 1):
                lc.put(x, yy, col)
    for x in range(int(cx - r), int(cx + r)):                                    # the rolled seams
        u = (x + 0.5 - cx) / float(r)
        if abs(u) <= 1.0:
            lc.put(x, top + 1, shade(body, 1.3 - 0.6 * max(0.0, u + 0.3)))
            lc.put(x, base - 2, shade(body, 0.7))
    if handle:
        hc = hexc('6a6e70')
        lc.line(cx - r, int(top), cx - r + 2, int(top - ry - 3), hc)
        lc.line(cx - r + 2, int(top - ry - 3), cx + r - 2, int(top - ry - 3), hc)
        lc.line(cx + r - 2, int(top - ry - 3), cx + r, int(top), hc)
    L.flush()


def bin_bag(c, cx, base, w, h, knot, split, seed):
    """A tied black bin bag: corridor_props3d.sack (the same bag the corridor sets out by a door), split open with a can and paper spilling for the torn one."""
    c.shadow(cx, base + 1, w / 2.0 + 3, 2, 110)
    L = K.Layer(c)
    lc = L.c
    CP.sack(lc, cx, base, w, h, seed=seed, tilt=0.0)
    px = lc.img.load()                                                    # the corridor's bag has a cool sheen; a room's bag is plain black plastic: pull the blue out
    for yy in range(lc.img.height):
        for xx in range(lc.img.width):
            r_, g_, b_, a_ = px[xx, yy]
            if a_:
                lum = 0.3 * r_ + 0.59 * g_ + 0.11 * b_
                px[xx, yy] = (int(lum + (r_ - lum) * 0.35), int(lum + (g_ - lum) * 0.35), int(lum + (b_ - lum) * 0.35), a_)
    if split:
        sy = base - h // 3
        lc.poly([(cx + 1, sy - 3), (cx + w // 3, sy - 1), (cx + w // 4, sy + 3)], hexc('141312'))
        K.cyl(lc, cx + 5, sy, sy + 3, 1.8, hexc('b0453a'), ry=0.7, n=4)                  # a can fallen out
    L.flush()
    if split:
        K.slab(c, cx - 1, base, cx + 3, base + 1, hexc('d8d2c2'), d=1, inset=0, n=3)     # paper


def cardboard_box(c, x0, x1, top, base, open_flaps, label, col):
    """A cardboard box: a corrugated front face (banded, a lit top edge), a top face with a flap seam or the flaps thrown open, a shaded side, a packing-tape strip and a label."""
    c.shadow((x0 + x1) // 2, base, (x1 - x0) // 2 + 3, 2, 110)
    L = K.Layer(c)
    lc = L.c
    d = 3
    CP.box3d(lc, x0, x1, top, base, d, col, s=2, lo=0.6, hi=1.22)
    tn = CP.tones(col, 5, 0.6, 1.22)
    if open_flaps:
        lc.poly([(x0, top - d), (x0 - 4, top - d - 4), (x0 - 3, top - d - 5), (x0 + 2, top - d - 1)], tn[1])      # the flaps folded back / out
        lc.poly([(x1 + 2, top - d), (x1 + 6, top - d - 5), (x1 + 7, top - d - 4), (x1 + 3, top - d + 1)], tn[3])
        lc.hline(x0 + 3, x1 - 1, top - d + 1, tn[1])                           # the dark mouth
    else:
        lc.hline(x0 + 1, x1 - 1, top + (base - top) // 3, shade(col, 0.82))        # the seam of the closed flaps
        mid = (x0 + x1) // 2
        lc.vline(mid, top - d + 1, top - 1, shade(col, 0.82))
        lc.hline(mid - 1, mid + 1, top - 1, hexc('cfc2a0'))                         # tape across the seam
    if label:
        ly = top + (base - top) // 2
        lc.rect(x0 + 4, ly - 1, x1 - 4, ly + 1, hexc('ece4cc'))
        lc.hline(x0 + 4, x1 - 4, ly + 2, shade(col, 0.6))
        lc.hline(x0 + 5, x1 - 6, ly, hexc('9a927e'))
    L.flush()


def book_stack(c, x0, top_y, widths, cols):
    """Books lying flat in a stack whose top rests at top_y: each a lit cover edge, the paper block (pale, ruled), a dark under-cover, the top one with its cover seen from above."""
    L = K.Layer(c)
    lc = L.c
    n = len(widths)
    for i, (w_, col) in enumerate(zip(widths, cols)):
        y = top_y - 3 - i * 3
        x = x0 + (i % 2) * 2
        lc.hline(x, x + w_, y, shade(col, 1.22))                                    # the upper cover's edge
        pages = hexc('e0d6bc')
        lc.hline(x + 1, x + w_ - 1, y + 1, pages)                                   # the paper block
        lc.put(x + w_ - 1, y + 1, shade(pages, 0.8))
        lc.hline(x, x + w_, y + 2, shade(col, 0.66))                                # the lower cover
        lc.vline(x, y, y + 2, shade(col, 1.0))                                      # the spine
        lc.vline(x + w_, y, y + 2, shade(col, 0.55))
        lc.put(x + 2, y + 1, shade(col, 0.8)) if w_ > 8 else None                    # a band across the spine
        if i == n - 1:                                                                # the top book shows its cover
            lc.hline(x + 1, x + w_ - 1, y - 1, shade(col, 1.35))
            lc.hline(x + 2, x + w_ - 2, y - 2, shade(col, 1.1)) if w_ > 6 else None
    L.flush()


# ================================================================================================================================ a bearskin rug
def bearskin(c, pelt, head, eye, nose, seed=5):
    """A bearskin rug on the boards: a pelt with a rolled, shadowed edge (it has thickness), fur laid in short strokes that run away from the head, a paler belly line, the head a raised dome
    (lit upper left) with ears, a snout, a dark nose and glass eyes. `pelt` / `head` = polygon points; `eye` / `nose` = pixels."""
    from PIL import Image, ImageDraw
    rng = random.Random(seed)
    W_, H_ = c.img.size

    def mask_of(pts):
        im = Image.new('L', (W_, H_), 0)
        ImageDraw.Draw(im).polygon(pts, fill=255)
        return im.load()
    pm, hm = mask_of(pelt), mask_of(head)
    fur = hexc('9a7450')
    tn = K.tones(fur, 6, 0.46, 1.30)
    xs = [p[0] for p in pelt + head]
    ys = [p[1] for p in pelt + head]
    x0, x1, y0, y1 = min(xs) - 2, max(xs) + 2, min(ys) - 2, max(ys) + 3
    inside = lambda m, x, y: 0 <= x < W_ and 0 <= y < H_ and m[x, y] > 0
    # the thickness: the pelt's lower edge casts a dark rim one row below it
    for y in range(y1, y0, -1):
        for x in range(x0, x1):
            if inside(pm, x, y - 1) and not inside(pm, x, y) and not inside(hm, x, y):
                c.put(x, y, shade(fur, 0.34))
    cx = (min(p[0] for p in pelt) + max(p[0] for p in pelt)) / 2.0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if not inside(pm, x, y):
                continue
            d = 0                                                               # steps in from the edge (up to 3)
            while d < 3 and all(inside(pm, x + dx, y + dy) for dx, dy in ((-d - 1, 0), (d + 1, 0), (0, -d - 1), (0, d + 1))):
                d += 1
            lam = 0.30 + 0.09 * d + 0.12 * math.sin(x * 0.55 + seed) * math.cos(y * 1.3)       # the pelt swells toward its middle
            lam += 0.12 * (1.0 if (x * 3 + y * 7) % 5 == 0 else (-0.12 if (x * 5 + y * 3) % 4 == 0 else 0.0))   # fur strokes: a lighter and a darker tick
            if abs(y - (y0 + y1) / 2.0) < 1.6:
                lam += 0.14                                                     # the paler spine
            if rng.random() < 0.05:
                lam += 0.18
            c.put(x, y, K._pick(tn, min(0.98, max(0.02, lam))))
    for k in range(int((x1 - x0) * 0.8)):                                       # a few long hairs lying over the edge
        x = rng.randint(x0, x1 - 1)
        y = rng.randint(y0, y1 - 1)
        if inside(pm, x, y) and not inside(pm, x, y + 1):
            c.put(x, y + 1, tn[3])
    # the head: a raised dome
    hx = [p[0] for p in head]
    hy = [p[1] for p in head]
    hcx, hcy = (min(hx) + max(hx)) / 2.0, (min(hy) + max(hy)) / 2.0
    hrx, hry = (max(hx) - min(hx)) / 2.0 + 0.5, (max(hy) - min(hy)) / 2.0 + 0.5
    for y in range(int(hcy - hry) - 1, int(hcy + hry) + 3):
        for x in range(int(hcx - hrx) - 1, int(hcx + hrx) + 2):
            if not inside(hm, x, y):
                continue
            u, v = (x + 0.5 - hcx) / hrx, (y + 0.5 - hcy) / hry
            nz = math.sqrt(max(0.0, 1.0 - min(1.0, u * u + v * v)))
            lam = max(0.0, K.LX * u + K.LY * v + K.LZ * nz)
            c.put(x, y, K._pick(tn, 0.12 + 0.62 * lam + (0.10 if (x * 5 + y * 3) % 4 == 0 else 0.0)))
    K.sphere(c, hcx - hrx * 0.55, hcy - hry * 0.75, 1.9, 1.9, fur, n=5, lo=0.4, hi=1.2)          # the ears
    K.sphere(c, hcx + hrx * 0.45, hcy - hry * 0.85, 1.9, 1.9, fur, n=5, lo=0.4, hi=1.2)
    K.sphere(c, hcx + hrx * 0.62, hcy + hry * 0.2, hrx * 0.42, hry * 0.5, hexc('b8946a'), n=5)      # the snout
    c.put(nose[0], nose[1], hexc('1a1410')); c.put(nose[0] - 1, nose[1], hexc('2a2018'))
    c.put(eye[0], eye[1], hexc('120e0a')); c.put(eye[0], eye[1] - 1, hexc('d9cfb8'))


# ================================================================================================================================ chest of drawers
def chest(c, x0, x1, top, base, P, drawers, open_row, knobs, legs, dark):
    """A chest of drawers / sideboard against the wall (the baked rooms' `furn.chest`, SAME footprint and drawer rows as before so no node or opening moves): a polished top with a lit
    front edge and a lip, a shadow under it, raised-panel drawer fronts (a lit top / left bevel, a shaded bottom / right one, wood grain along the front), bail pulls, bracket feet that
    are lit on the left and shaded on the right; an `open_row` drawer stands pulled out with its dark gap above and its own shadow."""
    b, lt, dk, out = P
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 2, 2, 100)
    c.rect(x0 - 1, top, x1 + 1, top + 2, shade(lt, 1.08))                                   # the top: a polished slab, two rows thick (the set-back pass lights it as a surface)
    c.hline(x0 - 1, x1 + 1, top, out)
    c.hline(x0, x1, top + 1, shade(lt, 1.28))                                                # its lit front edge
    c.hline(x0 - 1, x1 + 1, top + 2, shade(lt, 0.82))                                        # the lip's underside
    c.put(x0 - 1, top + 1, shade(lt, 1.2)); c.put(x1 + 1, top + 1, shade(dk, 1.0))
    foot = 3 if legs else 0
    c.box(x0, top + 3, x1, base - foot, b, out)                                              # the carcass
    c.vline(x0 + 1, top + 4, base - foot - 1, shade(lt, 0.96))                               # lit left edge, shaded right
    c.vline(x1 - 1, top + 4, base - foot - 1, shade(dk, 1.0))
    c.hline(x0 + 1, x1 - 1, top + 4, dk)                                                     # the shadow under the top
    c.hline(x0 + 1, x1 - 1, top + 5, shade(dk, 1.15))
    h = (base - foot - top - 5) // drawers
    for i in range(drawers):
        y0 = top + 5 + i * h
        y1 = y0 + h - 2
        if i == open_row:
            c.rect(x0 + 2, y0, x1 - 2, y0 + 1, dark)                                         # the gap the drawer came out of
            c.box(x0 + 1, y0 + 2, x1 - 1, y1 + 1, b, out)
            c.hline(x0 + 2, x1 - 2, y0 + 3, lt)
            c.hline(x0 + 2, x1 - 2, y1 + 2, shade(dk, 0.7))                                  # its shadow on the drawer below
            front = (y0 + 4, y1)
        else:
            c.box(x0 + 2, y0, x1 - 2, y1, b, dk)
            c.hline(x0 + 3, x1 - 3, y0 + 1, lt)
            front = (y0 + 2, y1 - 1)
        fy0, fy1 = front                                                                      # the raised panel on the drawer front
        if fy1 - fy0 >= 2 and x1 - x0 > 12:
            c.rect(x0 + 4, fy0, x1 - 4, fy1, shade(b, 1.06))
            c.hline(x0 + 4, x1 - 4, fy0, shade(lt, 1.12)); c.vline(x0 + 4, fy0, fy1, shade(lt, 1.05))
            c.hline(x0 + 4, x1 - 4, fy1, shade(dk, 0.95)); c.vline(x1 - 4, fy0, fy1, shade(dk, 0.95))
            rng = random.Random(x0 * 31 + y0)
            for _ in range(max(1, (fy1 - fy0) // 2)):                                         # grain along the front
                gy = rng.randint(fy0 + 1, max(fy0 + 1, fy1 - 1))
                gx = rng.randint(x0 + 6, max(x0 + 6, x1 - 12))
                for j in range(rng.randint(3, 6)):
                    if gx + j < x1 - 5:
                        c.put(gx + j, gy, shade(b, 0.92) if (gy + j) % 2 else shade(lt, 1.0))
        my = (y0 + y1) // 2 + (1 if i == open_row else 0)
        pulls = ((x0 + 6, x0 + 9), (x1 - 9, x1 - 6)) if x1 - x0 > 24 else (((x0 + x1) // 2 - 1, (x0 + x1) // 2 + 1),)
        for (a, z) in pulls:                                                                  # a bail pull: a lit bar on two dark posts
            c.hline(a, z, my, knobs)
            c.hline(a, z, my - 1, shade(knobs, 1.3))
            c.put(a - 1, my, shade(knobs, 0.5)); c.put(z + 1, my, shade(knobs, 0.5))
            c.hline(a, z, my + 1, shade(knobs, 0.45))                                         # its shadow on the drawer
    if legs:
        for fx in (x0 + 1, x1 - 3):                                                           # bracket feet: lit on the left, shaded on the right
            c.rect(fx, base - 2, fx + 2, base, out)
            c.vline(fx, base - 2, base - 1, shade(lt, 0.9)); c.put(fx + 1, base - 2, shade(b, 0.9)); c.put(fx + 2, base - 1, shade(dk, 0.7))


# ================================================================================================================================ cabinet doors
def door_slab(c, x0, y0, x1, y1, door, lt, dk, shaker=False):
    """A cabinet door — the ONE drawing the furniture library's kitchen units (`furn_kitchen._door_slab`) and the baked kitchen's wall / base cupboards share: a flat-fronted door is not one
    colour (lit toward the top, a hair darker at the foot, a faint fleck of grain, a second soft bevel row inside the edge), a shaker door is a frame with an inset panel; both have a lit
    top / left edge and a shaded bottom / right edge."""
    c.rect(x0, y0, x1, y1, door)
    if not shaker and x1 - x0 >= 6 and y1 - y0 >= 8:
        h = y1 - y0
        for yy in range(y0, y1 + 1):
            f = (yy - y0) / float(max(1, h))
            c.hline(x0, x1, yy, shade(door, 1.05 - 0.10 * f))
        for k, yy in enumerate(range(y0 + 5, y1 - 2, 7)):
            c.hline(x0 + 2 + (k * 5) % 5, min(x1 - 2, x0 + 4 + (k * 5) % 5), yy, shade(door, 0.95))
        c.hline(x0 + 1, x1 - 1, y0 + 1, shade(lt, 0.98))
        c.vline(x1 - 1, y0 + 1, y1 - 1, shade(dk, 1.08))
    c.hline(x0, x1, y0, lt)
    c.vline(x0, y0, y1, lt)
    c.hline(x0, x1, y1, dk)
    c.vline(x1, y0, y1, dk)
    if shaker and x1 - x0 >= 8 and y1 - y0 >= 9:
        c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, shade(door, 0.94))
        c.hline(x0 + 2, x1 - 2, y1 - 2, lt)
        c.vline(x1 - 2, y0 + 2, y1 - 2, lt)
        c.hline(x0 + 2, x1 - 2, y0 + 2, dk)
        c.vline(x0 + 2, y0 + 2, y1 - 2, dk)


# ================================================================================================================================ a hanging copper pot
def copper_pot(c, x, rail_y, r):
    """A copper pan hung from a rail by its handle's hook: a rounded body lit on the upper left with a bright glint, a darker rolled rim, a dark inside showing at the lip, a short handle."""
    cy = rail_y + 4 + r
    L = K.Layer(c)
    lc = L.c
    lc.vline(x, rail_y, rail_y + 4, hexc('3a3a36'))                                          # the hook
    K.sphere(lc, x, cy + 1, r, r * 0.92, hexc('b8703a'), n=6, lo=0.52, hi=1.3, gloss=True)
    lc.hline(x - r + 1, x + r - 1, cy - r + 1, hexc('4a2a18'))                                # the lip, dark inside
    lc.hline(x - r + 2, x + r - 2, cy - r, hexc('d8904a'))
    lc.rect(x + r, cy - 1, x + r + 3, cy, hexc('6a4a30'))                                     # the handle
    L.flush()
