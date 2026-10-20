"""STILL MORE REDRAWS — the houseplants, the bedside table and the refuge's stack of crates with a camping stove (owner round 47b: "everything very flat and very basic looking… more detail and
love"). Same method as furn_props.py (propkit: tones, a light from the upper left, a selective outline, a contact shadow)."""
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

BRASS = hexc('b09456')
BRASS_LT = hexc('e0c878')
BRASS_DK = hexc('7a6430')
WOOD = hexc('5d3f2c')
WOOD_DK = hexc('46301f')
WOOD_LT = hexc('71503a')
WOOD_OUT = hexc('2b1c13')


# ================================================================================================================================ houseplants
def _leaf(lc, x0, y0, x1, y1, w, col, rib=True):
    """A lens-shaped leaf from (x0, y0) to (x1, y1), `w` wide at its belly, lit on one side, with a midrib."""
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    if ln < 1:
        return
    nx, ny = -dy / ln, dx / ln
    tn = K.tones(col, 4, 0.62, 1.3)
    steps = int(ln * 2.2)
    for i in range(steps + 1):
        t = i / float(steps)
        px, py = x0 + dx * t, y0 + dy * t
        half = w * (math.sin(math.pi * t) ** 0.75)
        k = -half
        while k <= half + 1e-6:
            u = (k / max(half, 0.01)) if half > 0.01 else 0.0
            lc.put(int(round(px + nx * k)), int(round(py + ny * k)), tn[2 if u < -0.35 else (1 if u < 0.45 else 0)] if abs(u) > 0.05 else tn[3])
            k += 0.5
    if rib:
        for i in range(1, steps):
            t = i / float(steps)
            lc.put(int(round(x0 + dx * t)), int(round(y0 + dy * t)), shade(col, 0.62))


@piece('plant_pot', 20, 36, 'floor', rooms={'bedroom': 3, 'living_room': 7, 'study': 3, 'dining_room': 2, 'kitchen': 2, 'bathroom': 2}, styles={'adult': 3, 'sick': 2, 'teen': 1},
       tags=('plant', 'clutter'), variants={'rubber': {'kind': 'rubber'}, 'fern': {'kind': 'fern'}, 'dead': {'kind': 'dead'}}, feet=(112, 119),
       note='a houseplant in a terracotta pot: a rubber plant with broad ribbed leaves, a feathery fern, or one nobody watered — drooping brown leaves, dry soil, a cracked pot and a fallen leaf')
def plant_pot(c, ox, oy, p):
    kind = p['kind']
    cx = ox + 10.0
    K.contact_shadow(c, cx, oy + 0.5, 9, 1.6, 95)
    L = K.Layer(c)
    lc = L.c
    pot = hexc('b0643c') if kind != 'dead' else hexc('9a6a48')
    rng = random.Random(len(kind) * 9)
    # the pot: a tapered terracotta bucket with a lit rim band, and its soil
    K.frustum(lc, cx, oy - 11, oy - 1, 5.6, 4.0, pot, ry_t=1.7, ry_b=1.1, inner=hexc('3a2a20') if kind != 'dead' else hexc('8a7a68'), rim=shade(pot, 1.25), n=5, lo=0.5, hi=1.3)
    lc.hline(int(cx - 6), int(cx + 5), oy - 10, shade(pot, 1.3))
    lc.hline(int(cx - 5), int(cx + 4), oy - 9, shade(pot, 0.7))
    if kind == 'dead':
        for (px_, py_) in ((int(cx) - 1, oy - 8), (int(cx), oy - 6), (int(cx) + 1, oy - 4), (int(cx) + 1, oy - 3)):
            lc.put(px_, py_, hexc('2a1c14'))                                                    # a crack
        lc.put(int(cx) + 2, oy - 5, hexc('2a1c14'))
    top = oy - 12
    if kind == 'rubber':
        stem = hexc('5a7a3c')
        for dx in (-1, 0):
            lc.vline(int(cx) + dx, oy - 24, top, shade(stem, 0.8))
        for (dx, dy, ln, w) in ((-7, -22, 8, 2.6), (6, -21, 8, 2.6), (-4, -29, 8, 2.6), (3, -27, 8, 2.6), (-9, -16, 7, 2.2), (9, -15, 7, 2.2), (0, -33, 7, 2.2)):
            _leaf(lc, cx, top - 6 - (0 if dy > -20 else 4), cx + dx, oy + dy, w, hexc('3f6a38') if (dx + dy) % 2 else hexc('4f7c40'))
    elif kind == 'fern':
        for k, a in enumerate((-70, -46, -22, 0, 22, 46, 70)):
            ca, sa = math.sin(math.radians(a)), -math.cos(math.radians(a))
            ln = 15 - abs(a) * 0.08
            ex, ey = cx + ca * ln, top + sa * ln * 0.9 + 3
            lc.line(int(cx), top, int(ex), int(ey + 6 * abs(a) / 70.0), hexc('3f6a38'))
            for j in range(2, int(ln), 2):                                                      # the little leaflets along each frond
                px_ = cx + ca * j
                py_ = top + sa * j * 0.9 + 3 * (j / ln) + 6 * abs(a) / 70.0 * (j / ln)
                lc.put(int(px_), int(py_) - 1, hexc('6a9a4a'))
                lc.put(int(px_), int(py_) + 1, hexc('4a7a3a'))
    else:
        stems = ((-7, -19), (-3, -24), (3, -22), (8, -17), (-9, -12), (10, -11))
        for (dx, dy) in stems:                                                                  # bare stems arching out and over, the leaves hanging dry off their ends
            ex, ey = cx + dx, oy + dy
            mx_, my_ = cx + dx * 0.55, top + (dy + 12) * 0.9
            lc.line(int(cx), top, int(mx_), int(my_), hexc('6a5a3a'))
            lc.line(int(mx_), int(my_), int(ex), int(ey), hexc('7a6a44'))
            _leaf(lc, ex, ey, ex + (2 if dx > 0 else -2), ey + 7, 1.8, hexc('9a7a3a') if (dx % 2) else hexc('6a5230'))
        lc.rect(int(cx) + 8, oy - 1, int(cx) + 11, oy, hexc('7a5a30'))                           # a leaf that has fallen
        lc.put(int(cx) + 12, oy - 1, hexc('5a4222'))
    L.flush()


# ================================================================================================================================ the bedside table
@piece('nightstand_wood', 25, 22, 'wall', rooms={'bedroom': 6}, styles={'adult': 6, 'teen': 1, 'kid': 2, 'sick': 1}, tags=('storage', 'bedside'), depth=4,
       variants={'dark': {'pal': (WOOD, WOOD_LT, WOOD_DK, WOOD_OUT), 'book': hexc('7a6a8a')},
                 'light': {'pal': (hexc('8a6a4a'), hexc('a2805a'), hexc('6c5038'), hexc('3a281a')), 'book': hexc('5a7a6a')}},
       slots=({'id': 'top', 'dx0': 4, 'dx1': 21, 'dy': -20, 'top': True, 'kinds': ('lamp', 'small')},),
       anchors=({'name': 'bedside', 'dx': 12, 'dy': -12},), opens={'kind': 'drawer', 'frames': 3, 'anchor': 'bedside'}, feet=(105, 108),
       note='a bedside table: a lipped top, one panelled drawer with a brass pull, an open shelf with a book, turned feet')
def nightstand_wood(c, ox, oy, p):
    W_, WL, WD, WO = p['pal']
    x0, x1 = ox + 1, ox + 23
    top, base = oy - 20, oy
    c.shadow(ox + 12, base + 1, 13, 2, 90)
    c.rect(x0 - 1, top, x1 + 1, top + 1, WL)                                                      # the top: lit front edge, a lip
    c.hline(x0 - 1, x1 + 1, top, shade(WL, 1.3))
    c.hline(x0 - 1, x1 + 1, top + 2, shade(WD, 0.7))
    c.rect(x0, top + 3, x1, base - 3, WO)                                                          # the carcass outline
    c.rect(x0 + 1, top + 3, x1 - 1, base - 3, shade(W_, 0.88))
    c.vline(x0 + 1, top + 3, base - 3, shade(WL, 0.95))
    c.vline(x1 - 1, top + 3, base - 3, shade(WD, 1.0))
    # the open shelf below, dark, a book lying in it
    c.rect(x0 + 3, top + 13, x1 - 3, base - 4, hexc('1c1410'))
    c.hline(x0 + 3, x1 - 3, top + 13, shade(WD, 0.6))
    c.rect(x0 + 5, top + 15, x0 + 12, base - 5, p['book'])
    c.hline(x0 + 5, x0 + 12, top + 15, shade(p['book'], 1.3))
    c.hline(x0 + 5, x0 + 12, top + 16, shade(p['book'], 0.7))
    c.rect(x0 + 13, top + 16, x0 + 14, base - 5, hexc('b8a888'))                                    # a bundle of letters stood on end
    t = p['open']
    dy = int(round(5 * t))
    if dy:
        c.rect(x0 + 3, top + 4, x1 - 3, top + 4 + dy, hexc('1c1410'))                              # the dark gap the drawer came out of
    # the drawer: a raised panel with a lit top edge and a brass pull
    c.rect(x0 + 2, top + 4 + dy, x1 - 2, top + 11 + dy, WO)
    c.rect(x0 + 3, top + 5 + dy, x1 - 3, top + 10 + dy, shade(W_, 1.06))
    c.hline(x0 + 3, x1 - 3, top + 5 + dy, WL)
    c.hline(x0 + 3, x1 - 3, top + 10 + dy, WD)
    c.vline(x0 + 3, top + 5 + dy, top + 10 + dy, shade(WL, 0.9))
    c.rect(x0 + 9, top + 7 + dy, x0 + 13, top + 8 + dy, BRASS)
    c.put(x0 + 9, top + 7 + dy, BRASS_LT)
    c.put(x0 + 13, top + 8 + dy, BRASS_DK)
    if dy:
        c.hline(x0 + 2, x1 - 2, top + 3 + dy, shade(WL, 1.2))
    for fx in (x0, x1 - 2):                                                                        # turned feet
        c.rect(fx, base - 2, fx + 2, base, WD)
        c.vline(fx, base - 2, base, WL)
        c.hline(fx, fx + 2, base, WO)


# ================================================================================================================================ crates, a camping stove, cans
def _crate(lc, x0, top, x1, base, col, rng):
    """A slatted crate seen from the front: planks with dark gaps, corner posts, nail heads, grain, a lit top lip."""
    lc.rect(x0, top, x1, base, shade(col, 0.4))
    n = max(2, (base - top) // 5)
    ph = (base - top - 1) // n
    for k in range(n):
        ya, yb = top + 1 + k * ph, top + (k + 1) * ph - (1 if k < n - 1 else 0)
        for y in range(ya, yb + 1):
            f = (y - ya) / float(max(1, yb - ya))
            lc.hline(x0 + 1, x1 - 1, y, shade(col, 1.12 - 0.34 * f))
        lc.hline(x0 + 1, x1 - 1, ya, shade(col, 1.3))
        for _ in range(2):
            gx = rng.randint(x0 + 4, max(x0 + 4, x1 - 7))
            lc.hline(gx, gx + rng.randint(2, 4), (ya + yb) // 2, shade(col, 0.8))
    for px in (x0 + 2, x1 - 2):
        lc.rect(px - 1, top, px + 1, base, shade(col, 0.84))
        lc.vline(px - 1, top, base, shade(col, 1.14))
        lc.vline(px + 1, top, base, shade(col, 0.58))
        for ny in range(top + 3, base - 1, 6):
            lc.put(px, ny, hexc('2a2420'))
    lc.hline(x0 - 1, x1 + 1, top - 1, shade(col, 1.25))
    lc.hline(x0 - 1, x1 + 1, base + 1, hexc('2a2018'))


def _can(lc, cx, base, h, label, rx=2.2):
    """A tin: a label-coloured body with a metal rim top and bottom and a white band."""
    K.cyl(lc, cx, base - h, base - 1, rx, label, ry=0.9, gloss=True, n=4, lo=0.6, hi=1.25, cap_col=hexc('c4ccd0'))
    lc.hline(int(cx - rx), int(cx + rx) - 1, base - 1, hexc('8a949a'))
    lc.hline(int(cx - rx) + 1, int(cx + rx) - 2, base - h + 2, hexc('e8e0cc'))
    lc.put(int(cx), base - h + 4, hexc('2a2a2e'))


@piece('crates_stove', 42, 47, 'wall', rooms={'bedroom': 4, 'living_room': 1}, styles={'refuge': 8}, tags=('storage',), depth=4, surface_h=37,
       slots=({'id': 'lamp', 'dx0': 28, 'dx1': 40, 'dy': -14, 'top': False, 'kinds': ('lamp',)},), anchors=({'name': 'crates', 'dx': 15, 'dy': -29},), feet=(105, 108),
       variants={'a': {'col': 'a88a58', 'pot': 'b0453a'}, 'b': {'col': '8a8a7c', 'pot': '5a7a9a'}},
       note='crates stacked against the wall with a camping stove and a dented pot on top, tins with labels, a candle stub; room beside for a lantern')
def crates_stove(c, ox, oy, p):
    col = hexc(p['col'])
    rng = random.Random(len(p['col']) * 5 + 1)
    base = oy
    c.shadow(ox + 20, base + 1, 22, 2, 95)
    L = K.Layer(c)
    lc = L.c
    _crate(lc, ox + 1, base - 15, ox + 20, base, col, rng)                                     # the bottom left crate
    _crate(lc, ox + 22, base - 13, ox + 39, base, shade(col, 0.92), rng)                       # the lower right crate, a little shorter
    _crate(lc, ox + 3, base - 28, ox + 18, base - 16, shade(col, 1.06), rng)                  # a crate stacked on the first
    # the stove on top: a steel case, a burner ring, a gas can beside it, a dented pot with a lid and a bail handle
    sy = base - 29
    lc.rect(ox + 3, sy - 4, ox + 17, sy, hexc('8a949a'))
    lc.hline(ox + 3, ox + 17, sy - 4, hexc('d8dee2'))
    lc.hline(ox + 3, ox + 17, sy, hexc('4a5258'))
    lc.vline(ox + 3, sy - 4, sy, hexc('b4bcc0'))
    lc.put(ox + 14, sy - 2, hexc('c0453a'))                                                        # the knob
    lc.hline(ox + 6, ox + 11, sy - 5, hexc('3a3a3e'))                                              # the burner
    pot = hexc(p['pot'])
    K.cyl(lc, ox + 8.5, sy - 12, sy - 6, 4.6, pot, ry=1.5, gloss=True, n=5, inner=shade(pot, 0.5))
    lc.rect(ox + 4, sy - 10, ox + 5, sy - 9, hexc('2a2a2e'))
    lc.line(ox + 4, sy - 12, ox + 8, sy - 15, hexc('4a4a4e'))
    lc.line(ox + 8, sy - 15, ox + 13, sy - 12, hexc('4a4a4e'))                                     # the bail handle
    # on the lower right crate: tins with labels and a candle stub with its small flame
    for (cx, h, lab) in ((ox + 25.0, 6, hexc('b0453a')), (ox + 30.5, 5, hexc('5a8a4a')), (ox + 35.5, 7, hexc('d8a83a'))):
        _can(lc, cx, base - 14, h, lab)
    lc.rect(ox + 38, base - 18, ox + 39, base - 14, hexc('ece0c0'))
    lc.put(ox + 38, base - 19, hexc('f4d060'))
    lc.put(ox + 38, base - 20, hexc('f8f0b0'))
    L.flush()
