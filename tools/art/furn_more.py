"""STILL MORE REDRAWS — the houseplants and the bedside table (owner round 47b: "everything very flat and very basic looking… more detail and
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


# ================================================================================================================================ houseplants (the leaf helper)
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


# (the houseplants are tools/art/furn_plants.py: a tall FLOOR plant and a small DESK plant — home_logic keeps a small one off the floor)


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


