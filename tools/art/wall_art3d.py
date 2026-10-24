"""WALL ART WITH BODY — the framed pictures, papers and hangings of the rooms, redrawn so none is a flat coloured rectangle (owner round 48h: "We absolutely do not want any flat
drawings anywhere. Even for wall art, there needs to be quality").

A wall piece is a thing hung ON a wall: it has a THICKNESS and it throws a shadow. So every piece here has: a bevelled moulding or a paper edge (lit on the upper left, shaded on the lower
right), a cast shadow on the wall, a way of being fixed (a nail and cord, tape, a pin with its own shadow), and a surface with more than one tone — stitched thread with a lit side, a glazed
picture with a glint, paper with fibre, a fold and a curling corner, cork with grain, a printed map with tinted blocks, a gilt oval with a convex rim.

Each function draws into a canvas at (ox, oy) inside the footprint its @piece declares (furn_*.py delegate here). Uses the shared kit in tools/art/wallart.py.
"""
import math
import random

import propkit as K
import wallart as W
from pixlib import hexc, shade, mix


def _shadow(c, x0, y0, x1, y1, a=58):
    """A soft cast shadow on the wall: one column to the right and one row below a rect (the wall sits a hair behind the piece)."""
    for x in range(x0 + 1, x1 + 2):
        W.px(c, x, y1 + 1, hexc('000000', a))
    for y in range(y0 + 1, y1 + 1):
        W.px(c, x1 + 1, y, hexc('000000', int(a * 0.75)))


def _bevel(c, x0, y0, x1, y1, col, lit=1.22, dark=0.72):
    """A bevelled box outline: lit along the top and left, shaded along the bottom and right."""
    for x in range(x0, x1 + 1):
        W.px(c, x, y0, shade(col, lit)); W.px(c, x, y1, shade(col, dark))
    for y in range(y0, y1 + 1):
        W.px(c, x0, y, shade(col, lit * 0.96)); W.px(c, x1, y, shade(col, dark * 1.05))


def pin(c, x, y, col):
    """A pin pressed into the wall: a lit round head, its own small cast shadow."""
    W.px(c, x + 1, y + 1, hexc('000000', 80))
    W.px(c, x + 2, y + 1, hexc('000000', 40))
    W.px(c, x, y, shade(col, 1.45))
    W.px(c, x + 1, y, col)
    W.px(c, x, y + 1, shade(col, 0.78))
    W.px(c, x + 1, y + 1, shade(col, 0.55))


# ------------------------------------------------------------------------------------------------------------------------------------ pictures
SEAS = {      # colourways for the sea picture: water, sky (4 bands, top to bottom), sail, jib, hull, stripe, sun
    'blue': dict(water=hexc('5a7a9a'), sky=('6a9ac8', '86b0d4', 'a4c6de', 'c8dcea'), sail=('f2ecde', 'c8c0ae'), jib='e6e0d0', hull='6a3a2a', stripe='b08a5a', sun='f6e8b8'),
    'teal': dict(water=hexc('3e7a7a'), sky=('7ab0b8', '98c4c8', 'b8d8d4', 'd8e8e0'), sail=('f4ead6', 'cabca0'), jib='ecdcc0', hull='2a3a52', stripe='c8a45a', sun='f8ecc0'),
    'grey': dict(water=hexc('5e6e7a'), sky=('7a8892', '98a4ac', 'b4bec4', 'd0d8dc'), sail=('e8e4da', 'b8b4a8'), jib='dcd8cc', hull='3a3a42', stripe='9a9aa2', sun='e8e8e0'),
    'dusk': dict(water=hexc('6a5a7a'), sky=('7a6a9a', 'b0789a', 'e09a8a', 'f4c89a'), sail=('f6e4d0', 'c8a8a0'), jib='ecd0c0', hull='4a2a32', stripe='d8984a', sun='ffe0a0'),
    'red_sail': dict(water=hexc('4e7aa0'), sky=('6a9ac8', '86b0d4', 'a4c6de', 'c8dcea'), sail=('d8584a', 'a03a30'), jib='e8d0b8', hull='2a3a4a', stripe='e0c060', sun='f6e8b8'),
    'ochre': dict(water=hexc('5a8a86'), sky=('8ab4c0', 'a8c8d0', 'c4dcdc', 'e0eae0'), sail=('e0b860', 'b08a3a'), jib='f0e0b8', hull='5a3a22', stripe='e8d8a0', sun='fff0c0'),
}
HILLS = {     # colourways for the landscape: sky, far / mid / near hills, tree
    'green': dict(sky=('6a9ac8', '86b0d4', 'a4c6de', 'c8dcea'), far='9ab0c4', mid='6e9468', near='4a7448', tree=('3a6a38', '4c8444', '5a9650', '2e5a2e'), sun='f6e8b8'),
    'autumn': dict(sky=('8aa4c0', 'a8bcd0', 'c8d4dc', 'e4e4e0'), far='b0a8a4', mid='a4783a', near='7a5a2a', tree=('a8483a', 'c86a2e', 'd89a3a', '7a2e22'), sun='f8e0a8'),
    'dusk': dict(sky=('6a5a8a', 'a0709a', 'd8908a', 'f0c098'), far='8a7098', mid='5a5a74', near='3a4660', tree=('2a3a4a', '3a4a5a', '4a5a6a', '1e2a38'), sun='ffd890'),
    'snow': dict(sky=('8ca4bc', 'a8bccc', 'c4d2dc', 'e0e8ee'), far='c8d4e0', mid='dce6ee', near='eef2f6', tree=('3a5a44', '4a6a54', '5a7a64', '2a4434'), sun='f4f0e0'),
    'meadow': dict(sky=('78a8d8', '98c0e4', 'b8d6ec', 'd8e8f4'), far='a4c0a0', mid='88b068', near='5e9048', tree=('3a7a3a', '5a9a4a', '7ab05a', '2e6a30'), sun='fff0b8'),
}


def landscape(c, x0, y0, x1, y1, water=None, boat=False, seed=1, pal=None):
    """A painted view with its own tones: a sky that deepens toward the top, two clouds with shaded undersides, a sun with a halo, hills in three layers (a hazy far range, a mid
    green, a dark near field with grass flecks and a tree) - or the sea: bands of wave light, a sailing boat whose sail is lit on one side and shaded on the other. `pal` = one of HILLS / SEAS
    (the colourway); the boat is scaled to the picture and kept WHOLLY inside it (owner round 48i: "the sail on the ship clips over the frame")."""
    rng = random.Random(seed)
    h = y1 - y0 + 1
    if pal is None:
        pal = SEAS['blue'] if water is not None else HILLS['green']
    sky = [hexc(k) for k in pal['sky']]
    hz = y0 + int(h * 0.62)
    for y in range(y0, hz + 1):
        W.prect(c, x0, y, x1, y, sky[min(3, (y - y0) * 4 // max(1, hz - y0 + 1))])
    sx, sy = x1 - 3, y0 + 3                                                      # the sun: a pale halo and a bright core
    sun = hexc(pal['sun'])
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if dx * dx + dy * dy <= 5:
                W.px(c, sx + dx, sy + dy, shade(sun, 0.96) if dx * dx + dy * dy > 2 else shade(sun, 1.12))
    for (cx, cy, wid) in ((x0 + 3, y0 + 3, 5), (x0 + 9, y0 + 5, 4)):             # clouds: a white top, a blue-grey underside
        W.prect(c, cx, cy, cx + wid - 1, cy, hexc('f4f6f8'))
        W.prect(c, cx + 1, cy - 1, cx + wid - 2, cy - 1, hexc('ffffff'))
        W.prect(c, cx, cy + 1, cx + wid - 1, cy + 1, hexc('b8cade'))
    if water is not None:
        wat = pal['water']
        for y in range(hz, y1 + 1):
            k = (y - hz) / float(max(1, y1 - hz))
            W.prect(c, x0, y, x1, y, shade(wat, 1.12 - 0.42 * k))
        for yy in range(hz + 1, y1 + 1, 2):                                       # wave light: short bright dashes that spread out toward the viewer
            for xx in range(x0 + (yy % 3), x1 - 1, 5):
                W.prect(c, xx, yy, xx + 1 + (yy - hz) // 3, yy, shade(wat, 1.5))
        if boat:
            bx = x0 + (x1 - x0) * 2 // 5
            sail_h = max(4, min(8, hz - y0 - 3))                                  # the mast's top is at least one row inside the picture
            top = hz - 1 - sail_h
            lit, shd = hexc(pal['sail'][0]), hexc(pal['sail'][1])
            for r in range(sail_h):                                               # the mainsail: a triangle off the mast, lit on its left half and shaded on its right
                wid = 1 + (r * 4) // sail_h
                for dx in range(wid):
                    W.px(c, bx + 1 + dx, top + r, lit if dx < (wid + 1) // 2 else shd)
            for r in range(max(3, sail_h - 3)):                                   # the jib, smaller, on the other side of the mast
                for dx in range(1 + r // 2):
                    W.px(c, bx - 1 - dx, hz - 1 - max(3, sail_h - 3) + r, hexc(pal['jib']))
            W.prect(c, bx - 3, hz - 1, bx + 5, hz, hexc(pal['hull']))             # the hull and its pale stripe
            W.prect(c, bx - 2, hz - 1, bx + 4, hz - 1, hexc(pal['stripe']))
            W.px(c, bx, top - 1, hexc('3a2e24'))                                  # the masthead
            W.prect(c, bx, top, bx, hz - 2, hexc('3a2e24'))                       # the mast itself
    else:
        rows = [(hz - 5, hexc(pal['far']), 0.0), (hz - 3, hexc(pal['mid']), 1.0), (hz, hexc(pal['near']), 2.0)]   # far range, mid hills, near field
        for (base, col, ph) in rows:
            for x in range(x0, x1 + 1):
                top = base + int(round(1.6 * math.sin((x - x0) / (3.4 + ph) + ph) + 1.0 * math.sin((x - x0) / 1.6 + ph * 2)))
                for y in range(max(y0, top), (hz if col != rows[-1][1] else y1) + 1):
                    shade_k = 1.0 - 0.10 * (y - top)
                    W.px(c, x, y, shade(col, max(0.62, shade_k)))
        for y in range(hz + 1, y1 + 1):
            W.prect(c, x0, y, x1, y, shade(hexc(pal['near']), 0.92 - 0.10 * (y - hz) / max(1, y1 - hz)))
        tx = x0 + (x1 - x0) // 3                                                  # a tree: a dark trunk and a canopy in three tones
        W.prect(c, tx, hz - 3, tx, hz, hexc('4a3426'))
        t0, t1, t2, t3 = (hexc(k) for k in pal['tree'])
        for (dx, dy, col) in ((-1, -4, t0), (0, -5, t1), (1, -4, t0), (0, -4, t2), (-1, -3, t3), (1, -3, t3)):
            W.px(c, tx + dx, hz + dy, col)
        for _ in range(5):
            gx, gy = rng.randint(x0, x1), rng.randint(hz + 2, y1)
            W.px(c, gx, gy, shade(hexc(pal['mid']), 1.12))
    return (x0, y0, x1, y1)


def picture_landscape(c, ox, oy, p):
    """A painted landscape in a moulded frame: a bevelled moulding in three tones with a dark rebate, a cream mat with its cut edge, the picture, two soft glints of window light and a
    shadow on the wall, hung from a nail on a cord."""
    kind = W.kind_for(p['fr'])
    r = W.frame(c, ox, oy + 2, ox + 21, oy + 20, kind, mat=hexc('ece2c8'), thick=2, hang='wire', lip=True, matw=1)
    landscape(c, r[0], r[1], r[2], r[3], water=p['water'], boat=p['boat'], seed=p.get('seed', 3 if p['boat'] else 1), pal=(SEAS if p['boat'] else HILLS)[p['pal']])
    W.glint(c, r, 40)


def sampler_home(c, ox, oy, p):
    """A cross-stitched HOME in a walnut frame: linen with a visible weave (a slightly lighter and darker thread), every stitch a lit-and-shaded pair, letters in red thread with a
    shaded lower edge, a stitched heart, a border of running stitch with a flower in each corner, a glint across the glass."""
    ix0, iy0, ix1, iy1 = W.frame(c, ox, oy + 1, ox + 21, oy + 16, 'walnut', mat=None, thick=1, hang=None, lip=True)
    linen, lin_lt, lin_dk = hexc('e8dec2'), hexc('f2ead2'), hexc('cfc2a2')
    for y in range(iy0, iy1 + 1):
        for x in range(ix0, ix1 + 1):
            W.px(c, x, y, linen)
    for y in range(iy0, iy1 + 1):
        for x in range(ix0, ix1 + 1):
            if (x + y) % 2 == 0:
                W.px(c, x, y, lin_lt if y % 2 == 0 else lin_dk)                   # the weave: warp and weft catch the light differently
    green, red, blue, gold = hexc('4e8450'), hexc('b0453a'), hexc('4a6aa0'), hexc('d8b448')

    def stitch(x, y, col):
        W.px(c, x, y, col)
        W.px(c, x, y + 1, shade(col, 0.68)) if y + 1 <= iy1 else None             # the underside of the thread

    for x in range(ix0 + 1, ix1, 2):                                              # a running-stitch border
        W.px(c, x, iy0, green); W.px(c, x + 1, iy0, shade(green, 0.7)) if x + 1 < ix1 else None
        W.px(c, x, iy1, shade(green, 0.82))
    for y in range(iy0 + 1, iy1, 2):
        W.px(c, ix0, y, green); W.px(c, ix1, y, shade(green, 0.82))
    for (fx, fy) in ((ix0, iy0), (ix1, iy0), (ix0, iy1), (ix1, iy1)):            # a flower in each corner: a red petal, a gold heart
        W.px(c, fx, fy, red)
    W.px(c, ix0 + 1, iy0 + 1, gold); W.px(c, ix1 - 1, iy0 + 1, gold)
    import furn as F
    wx = ix0 + 1 + (ix1 - ix0 - 15) // 2
    F.text3(c, wx, iy0 + 2, 'HOME', red)
    for k in range(4):                                                            # a lit pixel on each letter's thread and a shaded underside
        for yy in range(iy0 + 2, iy0 + 7):
            for xx in range(wx + k * 4, wx + k * 4 + 3):
                if c.px[xx, yy][:3] == red[:3]:
                    if c.px[xx, yy + 1][:3] != red[:3]:
                        W.px(c, xx, yy + 1, shade(red, 0.62))
                    if yy == iy0 + 2:
                        W.px(c, xx, yy, shade(red, 1.28))
    hx, hy = (ix0 + ix1) // 2, iy1 - 2
    for (dx, dy, col) in ((-1, 0, blue), (1, 0, blue), (-2, -1, shade(blue, 1.2)), (2, -1, shade(blue, 1.2)), (0, 1, shade(blue, 0.7)), (0, 0, blue)):
        W.px(c, hx + dx, hy + dy, col)
    W.glint(c, (ix0, iy0, ix1, iy1), 34)


def cameos(c, ox, oy, p):
    """A pair of cameos in oval gilt frames: each frame a convex ring (a dark outer edge, a lit upper-left arc, a mid band, a shaded lower-right arc), a black velvet rebate, the cream
    cameo with a soft vignette and the silhouette in profile; a bow of ribbon on the cord, a shadow on the wall."""
    cord = hexc('4a3e30')
    for k, flip in enumerate((1, -1)):
        cx = ox + 10 + k * 18
        cy = oy + 11
        rx, ry = 8.2, 10.4
        for y in range(int(cy - ry) - 1, int(cy + ry) + 3):                       # the cast shadow, an oval offset down-right
            for x in range(int(cx - rx) - 1, int(cx + rx) + 3):
                if ((x + 0.5 - (cx + 1.2)) / rx) ** 2 + ((y + 0.5 - (cy + 1.2)) / ry) ** 2 <= 1.0:
                    W.px(c, x, y, hexc('000000', 46))
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):                       # the gilt ring, shaded by its own roundness
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                q = u * u + v * v
                if q > 1.0:
                    continue
                if q > 0.84:                                                       # the ring: convex, lit toward the upper left
                    lam = 0.5 - 0.5 * (u * 0.7 + v * 0.7) / max(0.01, math.sqrt(q))
                    col = shade(hexc('c9a24e'), 0.55 + 0.95 * lam)
                    if q > 0.96:
                        col = shade(hexc('7a5e24'), 0.9)                           # the outer edge
                    W.px(c, x, y, col)
                elif q > 0.76:
                    W.px(c, x, y, hexc('3a2a14'))                                  # the rebate
                else:
                    t = 1.0 - q
                    W.px(c, x, y, shade(hexc('e8dcc0'), 0.80 + 0.28 * t))         # the cameo's paper, darker toward its edge
        for (dx, dy) in ((-5, -4), (-6, -3), (-4, -6)):                           # a bright catch on the ring's lit arc
            W.px(c, int(cx + dx), int(cy + dy), hexc('fff0b0'))
        sil = hexc('1c1418')                                                       # the silhouette, in profile, facing in
        K.ell(c, cx - 0.5 * flip, oy + 8.5, 2.7, 3.4, sil)
        nx = int(cx + 3 * flip) - (1 if flip < 0 else 0)
        c.put(nx, oy + 9, sil); c.put(nx, oy + 10, sil)
        c.rect(int(cx - 2), oy + 11, int(cx), oy + 13, sil)
        for yy in range(oy + 13, oy + 19):
            hw = 2 + (yy - (oy + 13))
            c.hline(int(cx - 1) - hw, int(cx - 1) + hw, yy, sil)
        (c.put(int(cx - 1) - flip * 4, oy + 8, sil) if k == 1 else c.put(int(cx - 1) - flip * 4, oy + 7, sil))
        W.px(c, int(cx), oy - 1, cord)
    c.hline(ox + 10, ox + 28, oy, cord)
    bx = ox + 19                                                                   # the ribbon bow where the cords meet
    for (dx, dy, col) in ((-2, 1, 'a8322a'), (-1, 1, 'c8483a'), (1, 1, 'c8483a'), (2, 1, 'a8322a'), (0, 1, '7a2018'), (-1, 2, 'a8322a'), (1, 2, 'a8322a')):
        W.px(c, bx + dx, oy - 1 + dy, hexc(col))


def map_street(c, ox, oy, p):
    """A large street map pinned to the wall: folded paper (a vertical and a horizontal crease, a curling corner, a speckle of fibre), tinted blocks with a lit and a shaded edge,
    streets with kerbs, a park with trees, a river with banks and a bridge, tiny grey labels, a compass rose, and coloured pins that each cast their own shadow."""
    rng = random.Random(7)
    x0, y0, x1, y1 = ox, oy, ox + 45, oy + 33
    paper = hexc('ece2c4')
    W.sheet(c, x0, y0, x1, y1, paper, seed=11, fold='v', curl='br', grain=0.07)
    # the printed map inside a thin margin
    mx0, my0, mx1, my1 = x0 + 2, y0 + 2, x1 - 2, y1 - 2
    W.prect(c, mx0, my0, mx1, my1, hexc('f2ead0'))
    blocks = [hexc('dccfae'), hexc('d4c6a2'), hexc('e0d4b6'), hexc('cfc2a0')]
    for gy in range(my0 + 1, my1 - 2, 7):
        for gx in range(mx0 + 1, mx1 - 2, 7):
            col = blocks[(gx // 7 + gy // 7) % 4]
            bx1, by1 = min(gx + 4, mx1 - 1), min(gy + 4, my1 - 1)
            W.prect(c, gx, gy, bx1, by1, col)
            for x in range(gx, bx1 + 1):
                W.px(c, x, gy, shade(col, 1.10)); W.px(c, x, by1, shade(col, 0.84))   # a block's lit top and shaded foot
            if (gx + gy) % 3 == 0:
                W.px(c, gx + 1, gy + 2, shade(col, 0.66)); W.px(c, gx + 2, gy + 2, shade(col, 0.66))   # a label: a hair-thin grey dash
    for gx in range(mx0 + 5, mx1, 7):                                              # streets: pale carriageway with a darker kerb on each side
        for y in range(my0 + 1, my1):
            W.px(c, gx, y, hexc('faf4e0')); W.px(c, gx + 1, y, hexc('f6efd8'))
    for gy in range(my0 + 5, my1, 7):
        for x in range(mx0 + 1, mx1):
            W.px(c, x, gy, hexc('faf4e0')); W.px(c, x, gy + 1, hexc('f6efd8'))
    # the park
    W.prect(c, x0 + 5, y0 + 18, x0 + 14, y0 + 25, hexc('a2c490'))
    for (tx, ty) in ((7, 20), (10, 22), (12, 19), (8, 24), (13, 24)):
        W.px(c, x0 + tx, y0 + ty, hexc('6a9a5a')); W.px(c, x0 + tx + 1, y0 + ty + 1, hexc('4a7a44'))
    _bevel(c, x0 + 5, y0 + 18, x0 + 14, y0 + 25, hexc('a2c490'), 1.12, 0.78)
    # the river: a banked band of blue with a bright centre and a bridge over it
    pts = [(20, 2), (24, 6), (28, 10), (32, 14), (34, 20), (36, 26), (37, 31)]
    for (a, b) in zip(pts, pts[1:]):
        for t in range(0, 13):
            x = x0 + a[0] + (b[0] - a[0]) * t / 12.0
            y = y0 + a[1] + (b[1] - a[1]) * t / 12.0
            for dx in (-2, -1, 0, 1, 2):
                col = hexc('4a7aa8') if abs(dx) == 2 else hexc('6a9ac8') if abs(dx) == 1 else hexc('8ab8e0')
                W.px(c, int(round(x)) + dx, int(round(y)), col)
    bxm, bym = x0 + 31, y0 + 13
    W.prect(c, bxm - 3, bym, bxm + 4, bym + 1, hexc('faf4e0'))
    W.prect(c, bxm - 3, bym - 1, bxm + 4, bym - 1, hexc('8a7a5a')); W.prect(c, bxm - 3, bym + 2, bxm + 4, bym + 2, hexc('8a7a5a'))
    # the compass rose, top right: a four-point star, its north arm red, a lit and a shaded half on each point
    cx, cy = x1 - 6, y0 + 7
    for k in range(1, 5):
        W.px(c, cx, cy - k, hexc('b8322a') if k > 1 else hexc('6a1a14'))
        W.px(c, cx - 1, cy - k, hexc('d8584a')) if k < 3 else None
        W.px(c, cx, cy + k, hexc('3a3228'))
    for k in range(1, 4):
        W.px(c, cx - k, cy, hexc('5a4a3a')); W.px(c, cx + k, cy, hexc('3a3228'))
    W.px(c, cx, cy, hexc('f4ecd4'))
    # pins
    for (x, y, col) in ((6, 10, 'c8302a'), (14, 6, '3a6ab0'), (25, 22, 'e0b830'), (38, 8, 'c8302a'), (41, 26, '3a6ab0'), (10, 28, 'e0b830'), (28, 4, '3a9a52')):
        pin(c, x0 + x, y0 + y, hexc(col))
    for (px_, py_) in ((x0, y0), (x1 - 1, y0), (x0, y1 - 1)):
        pin(c, px_, py_, hexc('d8483a'))


def sketches_wall(c, ox, oy, p):
    """Two sheets of paper taped to the plaster — a line drawing of a sailing boat and a watercolour of tulips — with a row of paint tubes hung below on a string. Both sheets are the same
    size; each has its tape, a shadow, a curling corner, and drawing in more than one tone."""
    paper, edge = hexc('f4f0e4'), hexc('c8c4b4')
    ink, sea = hexc('3a3a44'), hexc('6a9ac8')
    for k, sx in enumerate((ox + 1, ox + 19)):
        W.sheet(c, sx, oy, sx + 14, oy + 16, paper, seed=5 + k, fold=None, curl='br' if k else 'bl', grain=0.05)
        W.tape(c, sx + 5, oy - 1, 6, 3, 0)
    s = ox + 1                                                                      # the boat: pencil lines with a soft wash
    c.line(s + 7, oy + 3, s + 7, oy + 10, ink)
    W.prect(c, s + 8, oy + 4, s + 11, oy + 10, hexc('9ac0e0'))
    c.line(s + 8, oy + 3, s + 12, oy + 10, ink)
    W.prect(c, s + 3, oy + 6, s + 5, oy + 10, hexc('c8dcee'))
    c.line(s + 6, oy + 5, s + 3, oy + 10, ink)
    for k in range(5):
        W.px(c, s + 8 + k // 2, oy + 5 + k, shade(hexc('9ac0e0'), 0.84))        # a shaded edge on the mainsail
    c.hline(s + 3, s + 12, oy + 11, ink); c.hline(s + 4, s + 11, oy + 12, ink)
    W.prect(c, s + 4, oy + 11, s + 11, oy + 11, hexc('8a5a3a'))
    for k, (a, b) in enumerate(((2, 12), (3, 11), (4, 10))):
        W.prect(c, s + a, oy + 13 + k, s + b, oy + 13 + k, shade(sea, 1.18 - 0.2 * k))
    s = ox + 19                                                                      # the tulips: a blue vase with a lit side, three stems, three heads with shaded petals
    W.prect(c, s + 4, oy + 11, s + 10, oy + 15, hexc('5a8ac8'))
    W.prect(c, s + 4, oy + 11, s + 5, oy + 15, hexc('8ab4e4')); W.prect(c, s + 9, oy + 11, s + 10, oy + 15, hexc('3a62a0'))
    W.prect(c, s + 5, oy + 11, s + 9, oy + 11, hexc('2a4a7a'))
    for (sx_, hx, hy, col) in ((s + 5, s + 3, oy + 4, 'd8483a'), (s + 7, s + 6, oy + 2, 'e0b830'), (s + 9, s + 9, oy + 4, 'd8483a')):
        c.line(sx_, oy + 11, hx + 1, hy + 2, hexc('4a7a3a'))
        W.prect(c, hx, hy, hx + 2, hy + 2, hexc(col))
        W.px(c, hx, hy, shade(hexc(col), 1.35)); W.px(c, hx + 2, hy + 2, shade(hexc(col), 0.65)); W.px(c, hx + 1, hy - 1, shade(hexc(col), 0.85))
    for (lx, ly, d) in ((s + 6, oy + 8, 1), (s + 8, oy + 7, -1)):                    # a leaf each side
        W.px(c, lx, ly, hexc('5a9a48')); W.px(c, lx + d, ly + 1, hexc('3a7a3a'))
    # the paint tubes: a string with a pin at each end and a tube hung from each clothes-peg
    for x in range(ox + 3, ox + 33):
        W.px(c, x, oy + 18, hexc('6a5a48'))
    pin(c, ox + 2, oy + 17, hexc('8a8a90')); pin(c, ox + 32, oy + 17, hexc('8a8a90'))
    for k, col in enumerate(('d8483a', '3a78d8', 'e0b830', '3a9a52', 'a85ac8')):
        tx = ox + 5 + k * 6
        base = hexc(col)
        for yy in range(oy + 19, oy + 26):                                            # a tube: shaded across its width, a crimped end, a cap
            W.px(c, tx, yy, shade(base, 1.3)); W.px(c, tx + 1, yy, base); W.px(c, tx + 2, yy, shade(base, 0.68))
        W.prect(c, tx, oy + 26, tx + 2, oy + 26, shade(base, 0.5))
        W.prect(c, tx, oy + 19, tx + 2, oy + 19, hexc('e8e4da'))
        W.px(c, tx + 1, oy + 18, hexc('a8845a'))                                       # the peg


def noticeboard(c, ox, oy, p):
    """A cork board in a wooden frame: a bevelled moulding in four tones, cork with real grain (light and dark flecks in two sizes), notes held by pins with their own shadows (each a
    sheet with a curling corner), a snapshot with a white border — all of it casting a small shadow on the cork."""
    x0, y0, x1, y1 = ox, oy, ox + 39, oy + 27
    _shadow(c, x0, y0, x1, y1, 60)
    wood = hexc('6a4a30')
    W.prect(c, x0, y0, x1, y1, shade(wood, 0.62))
    _bevel(c, x0, y0, x1, y1, wood, 1.35, 0.58)
    _bevel(c, x0 + 1, y0 + 1, x1 - 1, y1 - 1, wood, 1.12, 0.80)
    cork = hexc('b58f5e')
    rng = random.Random(3)
    for y in range(y0 + 2, y1 - 1):
        for x in range(x0 + 2, x1 - 1):
            W.px(c, x, y, cork)
    for _ in range(160):                                                              # cork grain: dark pits and pale crumbs
        x, y = rng.randint(x0 + 2, x1 - 2), rng.randint(y0 + 2, y1 - 2)
        W.px(c, x, y, hexc('8f6c40') if rng.random() < 0.5 else hexc('d0aa78'))
    for _ in range(14):
        x, y = rng.randint(x0 + 2, x1 - 3), rng.randint(y0 + 2, y1 - 3)
        W.prect(c, x, y, x + 1, y, hexc('9a7448'))
    for y in range(y0 + 2, y0 + 4):
        for x in range(x0 + 2, x1 - 1):
            W.px(c, x, y, shade(c.px[x, y][:3] + (255,), 0.88))                       # the frame's shadow falling on the cork
    for x in range(x0 + 2, x0 + 4):
        for y in range(y0 + 2, y1 - 1):
            W.px(c, x, y, shade(c.px[x, y][:3] + (255,), 0.9))
    import furn as F
    for k, (x, y, w, h, col, word) in enumerate(((ox + 3, oy + 3, 14, 11, 'f0ece0', p['a']), (ox + 20, oy + 4, 16, 9, 'f4e07a', p['b']), (ox + 5, oy + 16, 12, 8, 'f0a8b8', p['c']))):
        W.sheet(c, x, y, x + w - 1, y + h - 1, hexc(col), seed=2 + k, fold=None, curl='br' if k % 2 == 0 else 'bl', grain=0.04)
        pin(c, x + w // 2 - 1, y, hexc(['d8483a', '3a6ab0', '4a9a5a'][k]))
        F.text3(c, x + 1, y + 3, word, hexc('3a2a22'))
    sx0, sy0, sx1, sy1 = ox + 22, oy + 16, ox + 34, oy + 24                            # a snapshot: a white border, a picture of a garden with a red door
    W.sheet(c, sx0, sy0, sx1, sy1, hexc('f4f0e4'), seed=9, curl=None, grain=0.0)
    W.prect(c, sx0 + 1, sy0 + 1, sx1 - 1, sy1 - 2, hexc('9ac4e0'))
    W.prect(c, sx0 + 1, sy1 - 4, sx1 - 1, sy1 - 2, hexc('5a8a4a'))
    W.prect(c, sx0 + 1, sy1 - 3, sx1 - 1, sy1 - 2, hexc('487a3c'))
    W.prect(c, sx0 + 4, sy0 + 3, sx0 + 8, sy1 - 3, hexc('d4cdb8'))
    W.prect(c, sx0 + 5, sy0 + 5, sx0 + 7, sy1 - 3, hexc('c0382c'))
    W.prect(c, sx0 + 4, sy0 + 2, sx0 + 8, sy0 + 2, hexc('8a5a3a'))
    pin(c, (sx0 + sx1) // 2, sy0 - 1, hexc('e0b830'))


def banner_party(c, ox, oy, p):
    """A HAPPY BIRTHDAY banner under a swag of bunting: each pennant a folded triangle (lit half, shaded half, a bright hem), the string sagging between two pins; the paper strip with
    a lit top edge, a shaded lower edge, printed letters with a drop shadow, and tape at both ends."""
    import furn as F
    cols = ('4a7ab8', 'e0b830', '3a9a52', 'a85ac8', 'd8483a')
    for k in range(13):                                                              # the bunting
        x = ox + 2 + k * 4
        sag = int(round(4 * math.sin(math.pi * (x - ox) / 56.0)))
        W.px(c, x, oy + 1 + sag, hexc('4a3e30')); W.px(c, x + 1, oy + 1 + sag, hexc('4a3e30'))
        col = hexc(cols[k % 5])
        for r, wid in enumerate((3, 3, 2, 1)):                                        # a pennant: the left half lit, the right half shaded, a bright top hem
            for dx in range(wid):
                t = shade(col, 1.18 if dx < (wid + 1) // 2 else 0.74)
                if r == 0:
                    t = shade(col, 1.42)
                W.px(c, x - 1 + dx, oy + 2 + sag + r, t)
    pin(c, ox, oy, hexc('d8483a')); pin(c, ox + 54, oy, hexc('d8483a'))
    strip = hexc('f0ece0')
    W.sheet(c, ox + 8, oy + 10, ox + 47, oy + 20, strip, seed=4, fold=None, curl='br', grain=0.04)
    W.tape(c, ox + 6, oy + 9, 5, 3, 1); W.tape(c, ox + 45, oy + 9, 5, 3, -1)
    for (wx, word, col) in ((ox + 9, 'HAPPY', hexc('d8483a')), (ox + 31, 'BDAY', hexc('3a7ad8'))):
        F.text3(c, wx + 1, oy + 14, word, mix(strip, col, 0.30))                    # the letters' shadow on the paper, a pale ghost of the ink
        F.text3(c, wx, oy + 13, word, col)


def tea_towel(c, ox, oy, p):
    """A checked tea towel over a hook: a steel hook, cloth that sags in two soft folds (the check darker in each fold, lighter on the ridge), a hemmed lower edge with a small tassel
    of loose thread, a shadow cast on the wall."""
    red, cream = hexc(p['col']), hexc('e8dcc4')
    hook = hexc('7b8083')
    W.prect(c, ox + 4, oy, ox + 6, oy + 1, hook)
    W.px(c, ox + 4, oy, shade(hook, 1.4)); W.px(c, ox + 6, oy + 1, shade(hook, 0.6))
    for y in range(oy + 1, oy + 20):
        for x in range(ox, ox + 9):
            chk = ((x - ox) // 2 + (y - oy) // 2) % 2
            base = red if chk else cream
            fold = 0.0
            for fx in (ox + 2.5, ox + 6.5):                                          # two vertical folds: a dark valley with a light ridge beside it
                d = x - fx
                if abs(d) < 0.7:
                    fold = -0.20
                elif 0.7 <= d < 1.7 or -1.7 < d <= -0.7:
                    fold = max(fold, 0.10)
            if y > oy + 16:
                fold -= 0.04 * (y - oy - 16)                                         # the hem sags into shade
            W.px(c, x, y, shade(base, 1.0 + fold))
    W.prect(c, ox, oy + 1, ox + 8, oy + 1, shade(red, 1.2)); W.prect(c, ox, oy + 2, ox + 8, oy + 2, shade(red, 0.78))
    W.prect(c, ox, oy + 20, ox + 8, oy + 20, shade(red, 0.62))
    for x in range(ox, ox + 9, 2):
        W.px(c, x, oy + 21, shade(cream, 0.82))
    for y in range(oy + 3, oy + 21):                                                 # a cast shadow down the right side
        W.px(c, ox + 9, y, hexc('000000', 50))
    for x in range(ox + 1, ox + 10):
        W.px(c, x, oy + 22, hexc('000000', 34))


# ------------------------------------------------------------------------------------------------------------------------------------ a wall television
def tv_wall(c, ox, oy, p):
    """A flat-screen on the wall: a thin bezel with a lit upper edge and a shaded lower one, a silver chin with a maker's mark, glass that darkens from a cold navy at the top to near-black at
    the bottom with a soft window reflection and two diagonal glints, a vignette in the corners, a standby light that glows, the wall bracket's shadow and the cable hanging down.
    The screen (x 3..38, y 3..22) is where the live picture is laid by module_anim."""
    L = K.Layer(c)
    lc = L.c
    W.prect(lc, ox, oy, ox + 41, oy + 25, hexc('1c1d22'))
    for x in range(ox, ox + 42):                                                    # the bezel, bevelled
        W.px(lc, x, oy, hexc('4a4d58')); W.px(lc, x, oy + 25, hexc('0e0f12'))
    for y in range(oy, oy + 26):
        W.px(lc, ox, y, hexc('3c3f48')); W.px(lc, ox + 41, y, hexc('121316'))
    W.prect(lc, ox + 2, oy + 22, ox + 39, oy + 24, hexc('2a2c33'))                  # the chin
    W.prect(lc, ox + 2, oy + 24, ox + 39, oy + 24, hexc('8a8e98'))                  # its silver lip
    W.prect(lc, ox + 18, oy + 23, ox + 23, oy + 23, hexc('5a5e68'))                 # the maker's mark
    # the glass
    for y in range(oy + 3, oy + 23):
        t = (y - (oy + 3)) / 19.0
        base = mix(hexc('1e2430'), hexc('0a0c10'), t)
        for x in range(ox + 3, ox + 39):
            u = (x - (ox + 3)) / 35.0
            vig = 0.0
            if u < 0.08 or u > 0.92:
                vig = 0.18
            if t < 0.08 or t > 0.92:
                vig += 0.12
            W.px(lc, x, y, shade(base, 1.0 - vig))
    for y in range(oy + 4, oy + 12):                                                # a pale window reflected in the glass: a soft quadrilateral, brighter at its top
        for x in range(ox + 6, ox + 17 - (y - oy - 4) // 3):
            W.px(lc, x, y, hexc('ffffff', 12 + (8 - (y - oy - 4))))
    for k in range(11):                                                             # two diagonal glints
        W.px(lc, ox + 29 + k // 2, oy + 3 + k, hexc('ffffff', 30))
        W.px(lc, ox + 31 + k // 2, oy + 3 + k, hexc('ffffff', 17))
    for dy in (-1, 0, 1):                                                           # the standby light: a red core with a faint halo
        for dx in (-1, 0, 1):
            if dx or dy:
                W.px(lc, ox + 20 + dx, oy + 25 + dy, hexc('d8483a', 70))
    W.px(lc, ox + 20, oy + 25, hexc('ff5a4a'))
    L.flush()
    for x in range(ox + 3, ox + 41):                                                # the set's shadow on the wall and the bracket in the gap behind it
        W.px(c, x, oy + 26, hexc('000000', 80))
        W.px(c, x, oy + 27, hexc('000000', 36))
    for y in range(oy + 2, oy + 27):
        W.px(c, ox + 42, y, hexc('000000', 56))
    W.prect(c, ox + 15, oy + 26, ox + 26, oy + 26, hexc('3a3c44'))
    for k in range(5):                                                              # the cable: a 2 px dark cord with a lit edge, hanging then bending
        W.px(c, ox + 21, oy + 27 + k, hexc('2a2a30')); W.px(c, ox + 20, oy + 27 + k, hexc('4a4c54'))
    for k in range(5):
        W.px(c, ox + 22, oy + 31 + k, hexc('2a2a30')); W.px(c, ox + 21, oy + 31 + k, hexc('4a4c54'))


# ------------------------------------------------------------------------------------------------------------------------------------ chrome + glass
def chrome_rod(c, x0, y0, x1, y1, w=2, dark=False):
    """A chrome bar: a bright upper / left edge, a mid band, a shaded lower / right edge, a white glint pixel every few px."""
    cols = [hexc('f2f6f8'), hexc('b8c0c4'), hexc('6a7276')] if not dark else [hexc('c0c6ca'), hexc('8a9296'), hexc('4a5256')]
    if abs(x1 - x0) >= abs(y1 - y0):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for k in range(w):
                W.px(c, x, y0 + k, cols[0] if k == 0 else cols[2] if k == w - 1 else cols[1])
            if (x - x0) % 7 == 2:
                W.px(c, x, y0, hexc('ffffff'))
    else:
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for k in range(w):
                W.px(c, x0 + k, y, cols[0] if k == 0 else cols[2] if k == w - 1 else cols[1])
            if (y - y0) % 7 == 2:
                W.px(c, x0, y, hexc('ffffff'))


def towel_rail(c, ox, oy, p):
    """A heated towel rail: two chrome uprights on wall plates with screws, five rungs of chrome bar, towels hung over two of them (a rounded fold over the bar lit on top, a soft crease,
    a woven band); the rail casts a thin shadow on the wall. Or a gold stand with a plush red towel."""
    import bathroom as BR
    if p['k'] == 'chrome':
        for yy in range(oy + 1, oy + 28):                                             # the wall shadow, one row right of the rail's uprights
            W.px(c, ox + 2, yy, hexc('000000', 40)); W.px(c, ox + 35, yy, hexc('000000', 40))
        for k in range(5):
            chrome_rod(c, ox + 1, oy + 2 + k * 6, ox + 34, oy + 2 + k * 6, 2)
            W.px(c, ox + 1, oy + 4 + k * 6, hexc('000000', 34))
        for x in (ox, ox + 34):
            chrome_rod(c, x, oy, x, oy + 29, 2, dark=True)
            W.prect(c, x - 1 if x == ox else x, oy, x + 1 if x == ox else x + 2, oy + 1, hexc('d8dcde'))      # the wall plate at the top
            W.px(c, x, oy, hexc('8a9094')); W.px(c, x + 1, oy + 1, hexc('4a5256'))                                     # its screw
        for i, (ti, t0, t1) in enumerate(((0, 4, 22), (2, 17, 24))):
            tx0 = ox + 3 + i * 16
            BR.hung_towel(c, tx0, tx0 + 11, oy + 1 + (0 if i == 0 else 1), oy + t1 - (0 if i == 0 else 3), BR.TOWELS[ti])
    else:
        gold, gold_lt, gold_dk = hexc('c9a24e'), hexc('f0d078'), hexc('7a5e24')
        for y in range(oy + 1, oy + 32):                                              # the pole: a gold rod shaded across, a lit edge
            W.px(c, ox + 6, y, gold_lt); W.px(c, ox + 7, y, gold); W.px(c, ox + 8, y, gold_dk)
        W.prect(c, ox, oy, ox + 13, oy, gold_lt); W.prect(c, ox, oy + 1, ox + 13, oy + 1, gold_dk)    # the crossbar
        for fx in (ox, ox + 13):
            K.sphere(c, fx + 0.5, oy + 0.8, 1.6, 1.6, gold, n=4, lo=0.6, hi=1.5)
        for x in range(ox + 1, ox + 13):                                              # the foot: a disc seen from above
            W.px(c, x, oy + 32, gold_dk); W.px(c, x, oy + 31, gold)
        W.prect(c, ox + 2, oy + 30, ox + 11, oy + 30, gold_lt)
        BR.hung_towel(c, ox + 1, ox + 13, oy + 2, oy + 20, hexc('7a1f2a'))
        for x in range(ox + 2, ox + 12, 2):
            W.px(c, x, oy + 21, shade(hexc('7a1f2a'), 0.6))                           # the fringe


def glass_shade(c, ox, oy, w, h, flat=None):
    """Turn a mirror's FLAT glass colour into glass: a diagonal gradient (lit upper left, deeper lower right), a bright rim on every edge that borders the frame, a darker rim on the
    opposite edges, and a faint horizontal sheen band — on every pixel of the sprite area that is exactly the flat mirror colour."""
    import bathroom as BR
    flat = flat or BR.MIRROR
    cells = []
    for y in range(oy, oy + h + 6):
        for x in range(ox - 6, ox + w + 6):
            if 0 <= x < c.w and 0 <= y < c.h and c.px[x, y][:3] == flat[:3] and c.px[x, y][3] == 255:
                cells.append((x, y))
    if not cells:
        return 0
    s = set(cells)
    xs = [p[0] for p in cells]; ys = [p[1] for p in cells]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    span = max(1, (x1 - x0) + (y1 - y0))
    for (x, y) in cells:
        t = ((x - x0) + (y - y0)) / float(span)
        f = 1.14 - 0.34 * t
        if (x, y - 1) not in s or (x - 1, y) not in s:
            f += 0.16                                                                  # the lit edge, top and left
        if (x, y + 1) not in s or (x + 1, y) not in s:
            f -= 0.14                                                                  # the shaded edge, bottom and right
        if (y - y0) % 7 == 3:
            f += 0.05                                                                  # a faint sheen band across the glass
        c.px[x, y] = shade(flat, max(0.5, f))
    return len(cells)


def convex_ring(c, cx, cy, ro, ri, col):
    """Repaint a round frame (an annulus ro..ri around (cx, cy)) as a convex moulding: lit on its upper-left arc, shaded on its lower-right, a dark outer edge and a dark rebate."""
    for y in range(int(cy - ro) - 1, int(cy + ro) + 2):
        for x in range(int(cx - ro) - 1, int(cx + ro) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > ro or d < ri:
                continue
            f = (d - ri) / max(0.5, ro - ri)                                          # 0 inner .. 1 outer
            lam = 0.5 - 0.5 * (dx + dy) * 0.7071 / max(d, 0.01)
            tone = 0.62 + 0.9 * lam * (0.55 + 0.45 * math.sin(math.pi * f))
            if f > 0.88:
                tone = 0.55
            elif f < 0.12:
                tone = 0.50
            W.px(c, x, y, shade(col, tone))


def bevel_frame(c, x0, y0, x1, y1, col, thick=2):
    """Re-bevel a flat rectangular frame: `thick` rings of moulding, the outer lit on top/left and dark at the bottom/right, the inner the opposite (a picture-frame profile)."""
    for t in range(thick):
        _bevel(c, x0 + t, y0 + t, x1 - t, y1 - t, col, 1.30 - 0.12 * t if t < thick - 1 else 0.72, 0.62 if t < thick - 1 else 1.18)
