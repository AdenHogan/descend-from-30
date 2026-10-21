"""FLOOR THINGS, REDRAWN — a wicker laundry basket with clothes heaped over its rim, a freestanding clothes rail with garments hung from it, a stain on the boards (owner round 47c: "redo all
still on the list that need upgrading").

The basket is a woven frustum (basketweave pattern, a rim ring, handle holes) with a mound of clothes and a sleeve draped over the front; the rail is a chrome frame on castors with wire hangers and
five different garments (shirt, dress, coat, jumper, trousers) each lit and creased; the stain is an irregular dried tide-line with a darker rim, a pale middle and a few splashes.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import propkit as K
from furnlib import piece
from pixlib import hexc, shade, mix
from furn_bedroom import CLOTH

OUTLINE = hexc('2a1c17')
WICKER, WICKER_DK, WICKER_LT = hexc('a8845a'), hexc('6b4f30'), hexc('c9a478')


# ================================================================================================================================ the laundry basket
@piece('laundry_basket', 20, 16, 'floor', rooms={'bedroom': 5, 'bathroom': 6}, styles={'adult': 3, 'teen': 3, 'kid': 2, 'sick': 1}, tags=('clutter', 'clothes'),
       variants={'blue': {'a': 1}, 'grey': {'a': 5}, 'cream': {'a': 2}}, anchors=({'name': 'laundry_basket', 'dx': 9, 'dy': -8},), near=('wardrobe', 'sleeping'), feet=(116, 121),
       note='a woven wicker laundry basket with a loop handle each side, clothes heaped over the rim and a sleeve hanging down the front')
def laundry_basket(c, ox, oy, p):
    cl = CLOTH[p['a']]
    cx = ox + 10.0
    K.contact_shadow(c, cx, oy + 0.6, 10.5, 1.6, 100)
    L = K.Layer(c)
    lc = L.c
    K.frustum(lc, cx, oy - 10, oy - 1, 8.6, 7.2, WICKER, ry_t=1.8, ry_b=1.5, inner=shade(WICKER_DK, 0.55), rim=WICKER_LT, n=5)
    # the weave: pairs of rows alternate a dark and a light stroke, shifted every other pair
    for y in range(oy - 9, oy + 1):
        for x in range(ox, ox + 20):
            if lc.px[x, y][3] == 0:
                continue
            col = tuple(lc.px[x, y][:3])
            k = ((y - oy) // 2) & 1
            if (x + 2 * k) % 4 == 0:
                lc.put(x, y, shade(col, 0.78))                                                  # the seam between two strands
            elif (y - oy) % 2 == 0:
                lc.put(x, y, shade(col, 1.1))                                                   # the lit upper edge of a strand
    for sx, d in ((cx - 9.6, 1), (cx + 8.6, -1)):                                             # a loop handle on each side, at the rim
        lc.vline(int(sx), oy - 9, oy - 7, WICKER_DK)
        lc.put(int(sx) + d, oy - 10, WICKER_LT); lc.put(int(sx) + d, oy - 6, WICKER_DK)
        lc.put(int(sx), oy - 10, WICKER)
    L.flush()
    # the clothes: three lumps over the rim, a sleeve hanging down the front
    L = K.Layer(c)
    lc = L.c
    c2, c3 = CLOTH[(p['a'] + 3) % 6], CLOTH[(p['a'] + 2) % 6]
    K.sphere(lc, cx - 3.4, oy - 12.0, 4.4, 3.0, c2, n=4, lo=0.58, hi=1.25)
    K.sphere(lc, cx + 3.4, oy - 12.6, 4.2, 3.2, c3, n=4, lo=0.58, hi=1.25)
    K.sphere(lc, cx + 0.2, oy - 13.4, 4.6, 3.6, cl, n=4, lo=0.58, hi=1.25)
    for k in range(5):                                                                            # a sleeve over the front rim
        lc.hline(int(cx - 6) + (k > 3), int(cx - 4), oy - 10 + k, shade(c2, 0.86 + 0.06 * k))
    lc.put(int(cx - 6), oy - 5, shade(c2, 0.6))
    for (sx, sy) in ((cx - 1.0, oy - 14.2), (cx + 2.0, oy - 13.0)):                              # a crease on the top lump
        lc.put(int(sx), int(sy), shade(cl, 0.7))
    L.flush()


# ================================================================================================================================ the clothes rail
def _garment(lc, cx, top, kind, col, rng):
    """One garment hanging by a wire hanger whose hook sits at (cx, top). The cloth is lit from the left and creased by a few vertical folds."""
    def cloth(x0, x1, y0, y1):
        for y in range(y0, y1 + 1):
            fy = (y - y0) / float(max(1, y1 - y0))
            for x in range(x0, x1 + 1):
                fx = (x - x0) / float(max(1, x1 - x0))
                fold = 0.5 + 0.5 * math.sin((fx * 5.2 + col[0] * 0.013) * math.pi)
                lam = 1.12 - 0.32 * fx - 0.14 * fold - 0.10 * fy
                lc.put(x, y, shade(col, lam))
    hook = hexc('8a8a82')
    lc.vline(cx, top, top + 1, hook)
    lc.put(cx + 1, top, hook)
    hy = top + 2
    lc.line(cx, hy, cx - 5, hy + 3, hook)                                                       # the wire shoulders
    lc.line(cx, hy, cx + 5, hy + 3, hook)
    if kind == 'shirt':
        y0 = hy + 3
        cloth(cx - 5, cx + 5, y0, y0 + 20)
        for k in range(4):                                                                       # short sleeves, shaded
            lc.hline(cx - 8 + k, cx - 5, y0 + k, shade(col, 0.95 - 0.04 * k))
            lc.hline(cx + 5, cx + 8 - k, y0 + k, shade(col, 0.58 + 0.04 * k))
        lc.hline(cx - 1, cx + 1, y0, shade(col, 0.45))                                           # the neck hole
        lc.put(cx - 2, y0, hexc('e8e0cc')); lc.put(cx + 2, y0, hexc('e8e0cc'))                   # collar points
        lc.vline(cx, y0 + 2, y0 + 17, shade(col, 0.72))                                          # the button placket
        for yy in range(y0 + 3, y0 + 18, 4):
            lc.put(cx, yy, hexc('ece4cc'))
    elif kind == 'dress':
        y0 = hy + 3
        for y in range(y0, y0 + 36):                                                             # an A-line dress: narrow shoulders, wide hem
            half = 4 + int((y - y0) * 0.17)
            for x in range(cx - half, cx + half + 1):
                fx = (x - (cx - half)) / float(max(1, 2 * half))
                fold = 0.5 + 0.5 * math.sin((fx * 6.0) * math.pi)
                lc.put(x, y, shade(col, 1.12 - 0.34 * fx - 0.16 * fold - 0.05 * ((y - y0) / 36.0)))
        lc.hline(cx - 4, cx + 4, y0 + 8, shade(col, 0.6))                                        # a belt
        lc.hline(cx - 4, cx + 4, y0 + 9, hexc('e0c878'))
        lc.hline(cx - 6, cx + 6, y0 + 35, shade(col, 0.62))                                      # the hem
    elif kind == 'coat':
        y0 = hy + 3
        cloth(cx - 6, cx + 6, y0, y0 + 30)
        for k in range(10):                                                                      # long sleeves hanging in front
            lc.hline(cx - 9, cx - 7, y0 + 2 + k, shade(col, 0.92 - 0.02 * k))
            lc.hline(cx + 7, cx + 9, y0 + 2 + k, shade(col, 0.52))
        lc.vline(cx - 1, y0 + 1, y0 + 30, shade(col, 0.55))                                      # the lapel line
        lc.vline(cx, y0 + 1, y0 + 30, shade(col, 0.45))
        for yy in (y0 + 8, y0 + 14, y0 + 20):
            lc.put(cx + 2, yy, hexc('2a2a2e')); lc.put(cx + 1, yy, hexc('4a4a50'))
        lc.hline(cx - 5, cx + 5, y0, shade(col, 1.3))                                            # the collar
    elif kind == 'jumper':
        y0 = hy + 3
        cloth(cx - 5, cx + 5, y0, y0 + 14)
        for k in range(9):
            lc.hline(cx - 8, cx - 6, y0 + 1 + k, shade(col, 0.95 - 0.03 * k))
            lc.hline(cx + 6, cx + 8, y0 + 1 + k, shade(col, 0.55))
        for yy in range(y0, y0 + 15, 2):                                                          # knitted ribs
            lc.hline(cx - 5, cx + 5, yy, shade(col, 0.88))
        lc.hline(cx - 5, cx + 5, y0 + 14, shade(col, 0.6))
    else:                                                                                           # trousers folded over the hanger bar
        y0 = hy + 3
        cloth(cx - 5, cx - 1, y0, y0 + 26)
        cloth(cx + 1, cx + 5, y0, y0 + 26)
        lc.vline(cx, y0, y0 + 26, shade(col, 0.4))
        lc.hline(cx - 5, cx + 5, y0, shade(col, 1.25))                                          # the waistband
        lc.hline(cx - 5, cx - 1, y0 + 26, shade(col, 0.5)); lc.hline(cx + 1, cx + 5, y0 + 26, shade(col, 0.5))


@piece('clothes_rail', 49, 52, 'floor', rooms={'bedroom': 4, 'living_room': 1}, styles={'bedsit': 8, 'sick': 1, 'teen': 1}, tags=('storage', 'clothes'),
       variants={'a': {'kinds': ('shirt', 'dress', 'coat', 'trousers'), 'cols': (0, 1, 5, 3)}, 'b': {'kinds': ('coat', 'jumper', 'dress', 'shirt'), 'cols': (1, 3, 0, 2)}},
       anchors=({'name': 'clothes_rail', 'dx': 16, 'dy': -22},), feet=(116, 119), near=('sleeping',),
       note='a freestanding chrome clothes rail on castors: wire hangers, four garments (shirt, dress, coat, jumper, trousers by variant), each lit, creased and outlined against the next')
def clothes_rail(c, ox, oy, p):
    K.contact_shadow(c, ox + 22.5, oy + 0.8, 26.0, 1.8, 105)
    rx0, rx1, rtop = ox + 2, ox + 44, oy - 48
    chrome, chrome_dk = hexc('b4bcc2'), hexc('6a7278')
    rng = random.Random(3)
    xs = (rx0 + 9, rx0 + 18, rx0 + 28, rx0 + 36)
    for x, kind, ci in reversed(list(zip(xs, p['kinds'], p['cols']))):                            # back to front, each outlined so overlaps read
        L = K.Layer(c)
        _garment(L.c, x, rtop + 1, kind, CLOTH[ci], rng)
        L.flush(out_f=0.30)
    L = K.Layer(c)
    lc = L.c
    for x in (rx0, rx1):                                                                          # the uprights, lit on the left
        lc.rect(x, rtop, x + 1, oy - 3, chrome)
        lc.vline(x + 1, rtop, oy - 3, chrome_dk)
        lc.vline(x, rtop, oy - 3, hexc('e4ecee'))
    lc.rect(rx0, rtop, rx1 + 1, rtop + 1, chrome)                                                 # the top rail
    lc.hline(rx0, rx1 + 1, rtop, hexc('e4ecee'))
    lc.hline(rx0, rx1 + 1, rtop + 1, chrome_dk)
    for fx0, fx1 in ((rx0 - 3, rx0 + 5), (rx1 - 3, rx1 + 5)):                                    # splayed feet with castors
        lc.hline(fx0, fx1, oy - 3, chrome)
        lc.hline(fx0, fx1, oy - 2, chrome_dk)
        lc.rect(fx0, oy - 1, fx0 + 1, oy, hexc('2a2a2e'))
        lc.rect(fx1 - 1, oy - 1, fx1, oy, hexc('2a2a2e'))
    lc.hline(rx0, rx1 + 1, oy - 4, shade(chrome, 0.9))                                            # a low cross-bar
    L.flush()


# ================================================================================================================================ a stain on the boards
@piece('floor_stain', 28, 8, 'rug', rooms={'bedroom': 4, 'living_room': 3, 'kitchen': 3, 'bathroom': 3}, styles={'bedsit': 6, 'sick': 3, 'teen': 1}, tags=('stain',), feet=(113, 119),
       variants={'a': {'seed': 34, 'col': '9a8a5a'}, 'b': {'seed': 41, 'col': '6a5a42'}},
       note='a dried stain on the boards: an irregular tide-line with a darker rim, a paler middle and a few spots')
def floor_stain(c, ox, oy, p):
    rng = random.Random(p['seed'])
    base = hexc(p['col'])
    cx, cy, rx, ry = ox + 13.5, oy - 3.6, 11.0, 3.4
    ph = [rng.random() * 6.28 for _ in range(3)]
    for y in range(oy - 8, oy + 1):
        for x in range(ox, ox + 28):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            th = math.atan2(v, u)
            wob = 1.0 + 0.16 * math.sin(2 * th + ph[0]) + 0.10 * math.sin(3 * th + ph[1]) + 0.05 * math.sin(5 * th + ph[2])
            r = math.sqrt(u * u + v * v) / wob
            if r > 1.0:
                continue
            if r > 0.78:
                col = shade(base, 0.62)                                                      # the dried rim: darker
                if rng.random() < 0.18:
                    col = shade(base, 0.8)
            else:
                col = mix(shade(base, 0.92), shade(base, 1.18), 1.0 - r) if rng.random() > 0.12 else shade(base, 0.85)
            c.put(x, y, tuple(col[:3]) + (215 if r > 0.78 else 185,))
    for _ in range(7):                                                                         # a few spots flicked out beyond the edge
        a = rng.random() * 6.28
        d = 1.12 + rng.random() * 0.35
        x, y = int(cx + math.cos(a) * rx * d), int(cy + math.sin(a) * ry * d)
        if ox <= x < ox + 28 and oy - 8 <= y <= oy:
            c.put(x, y, shade(base, 0.7))
