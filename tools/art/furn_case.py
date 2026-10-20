"""CASE FURNITURE, REDRAWN — the bookcase, the chest of drawers and the dressing table (owner round 47c: "redo all still on the list that need upgrading").

Same vocabulary as the wardrobes (furn_wardrobes.py): a built-up crown / cornice, raised panels lit top-left and shaded bottom-right, brass pulls and escutcheons, grain, bracket feet. The bookcase gained
a back panel in shade, thick shelf boards with a drop shadow, and real books (varied heights and widths, banded spines, one leaning, a pile lying flat, an ornament); the chest has a lipped top, three
raised-panel drawers with bail pulls and a keyhole, and its top drawer pulls out on a search; the dressing table is a vanity with a swivel mirror on turned posts (clean or cracked), a lace doily and
two drawers.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import propkit as K
from furnlib import piece
from pixlib import hexc, shade, mix
from furn_wardrobes import _raised, _grain, _pull, _feet, _mirror_glass, _escutcheon, BRASS, BRASS_LT, BRASS_DK

WOOD = hexc('5d3f2c')
WOOD_DK = hexc('46301f')
WOOD_LT = hexc('71503a')
WOOD_OUT = hexc('2b1c13')
WOOD_PALS = {'dark': (WOOD, WOOD_LT, WOOD_DK, WOOD_OUT), 'light': (hexc('8a6a4a'), hexc('a2805a'), hexc('6c5038'), hexc('3a281a')),
             'oak': (hexc('7a5a3a'), hexc('8e6a46'), hexc('5e4430'), hexc('2e2014'))}
BOOKS = [hexc('7a2e28'), hexc('2f4a63'), hexc('5d6b3a'), hexc('8a6a3a'), hexc('4b3a5c'), hexc('b8a782'), hexc('3b5550'), hexc('6b4a36'), hexc('9c4f33'), hexc('3a3a44')]


def _hgrain(c, x0, y0, x1, y1, dark, light, seed):
    """Short horizontal grain flecks inside a panel — drawers run their grain along the front."""
    rng = random.Random(seed)
    for k in range(max(1, (y1 - y0 + 1) // 2)):
        y = rng.randint(y0, y1)
        x = rng.randint(x0, max(x0, x1 - 6))
        for j in range(rng.randint(3, 6)):
            if x + j <= x1:
                c.put(x + j, y, dark if k % 2 else light)


# ================================================================================================================================ the bookcase
def _book(c, x, yb, w, h, col, rng):
    """One book standing on a shelf: a lit left edge, a shaded right edge, bands on the spine and a title dash, the page block showing at the top."""
    top = yb - h + 1
    for xx in range(x, x + w):
        f = (xx - x) / float(max(1, w - 1))
        for y in range(top, yb + 1):
            c.put(xx, y, shade(col, 1.14 - 0.42 * f))
    c.hline(x, x + w - 1, top, shade(col, 1.32))
    if w >= 3:
        c.hline(x + 1, x + w - 1, top + 2, hexc('c9a84a') if rng.random() < 0.6 else shade(col, 1.45))      # a gilt band
        c.hline(x + 1, x + w - 1, yb - 2, hexc('c9a84a') if rng.random() < 0.5 else shade(col, 0.6))
        c.put(x + w // 2, top + 5 + rng.randint(0, 2), hexc('e8e0c8'))                                       # the title
    c.put(x, yb, shade(col, 0.55))


def _bay(c, xa, xb, yb, bay_h, rng, lean_ok=True):
    x = xa
    left = None
    while x < xb - 1:
        r = rng.random()
        if r < 0.09:
            x += rng.randint(1, 2)
            continue
        w = rng.choice((2, 2, 3, 3, 3, 4))
        if x + w > xb:
            break
        h = rng.randint(max(5, bay_h - 6), bay_h - 1)
        _book(c, x, yb, w, h, rng.choice(BOOKS), rng)
        x += w
        left = x
    if lean_ok and left is not None and xb - left >= 3 and rng.random() < 0.7:
        F.leaning_book(c, left, yb + 1, bay_h - 2, 2, rng.choice(BOOKS), lean=-1)


@piece('bookcase_low', 31, 51, 'wall', rooms={'bedroom': 4, 'living_room': 5, 'study': 6}, styles={'adult': 3, 'teen': 3, 'kid': 1}, tags=('books', 'storage'), depth=5,
       variants={'dark': {'pal': WOOD_PALS['dark'], 'seed': 3}, 'light': {'pal': WOOD_PALS['light'], 'seed': 8}, 'oak': {'pal': WOOD_PALS['oak'], 'seed': 5}},
       slots=({'id': 'top', 'dx0': 3, 'dx1': 26, 'dy': -49, 'top': True, 'kinds': ('small',)},),
       anchors=({'name': 'bookcase', 'dx': 15, 'dy': -30},), feet=(105, 108),
       note='a low bookcase: a crown, thick shelf boards with a shadow under each, a dark back, books of every height with banded spines — one leaning, a pile lying flat, an ornament, a pot plant')
def bookcase_low(c, ox, oy, p):
    W_, WL, WD, WO = p['pal']
    rng = random.Random(p['seed'])
    x0, x1 = ox + 1, ox + 29
    top, base = oy - 49, oy
    c.shadow((x0 + x1) // 2, base + 1, 17, 2, 100)
    c.rect(x0 - 1, top, x1 + 1, base - 3, WO)                                                      # the carcass outline
    c.rect(x0 + 2, top + 4, x1 - 2, base - 6, shade(WD, 0.42))                                       # the dark back
    c.hline(x0 + 2, x1 - 2, top + 4, shade(WD, 0.25))                                                # the shadow the crown throws
    c.hline(x0 + 2, x1 - 2, top + 5, shade(WD, 0.34))
    for (sx0, sx1, lit) in ((x0, x0 + 1, True), (x1 - 1, x1, False)):                                # the uprights
        c.rect(sx0, top + 3, sx1, base - 3, W_)
        c.vline(sx0, top + 3, base - 3, shade(WL, 1.1) if lit else WD)
        c.vline(sx1, top + 3, base - 3, shade(W_, 1.0) if lit else shade(WD, 0.8))
    # the crown: a lit cap, an overhang, a cove in shadow
    c.rect(x0 - 2, top, x1 + 2, top + 1, WL)
    c.hline(x0 - 2, x1 + 2, top, shade(WL, 1.3))
    c.hline(x0 - 1, x1 + 1, top + 2, W_)
    c.hline(x0 - 1, x1 + 1, top + 3, shade(WD, 0.7))
    bays = ((top + 5, top + 17), (top + 20, top + 33), (top + 36, base - 7))
    shelf_y = (top + 18, top + 34, base - 6)
    for k, ((ya, yb), sy) in enumerate(zip(bays, shelf_y)):
        _bay(c, x0 + 3, x1 - 3, yb, yb - ya + 1, rng, lean_ok=(k != 1))
        c.rect(x0 + 2, sy, x1 - 2, sy + 1, WL)                                                      # the board: lit front edge, dark underside
        c.hline(x0 + 2, x1 - 2, sy, shade(WL, 1.25))
        c.hline(x0 + 2, x1 - 2, sy + 2, shade(WD, 0.5))
        if k < 2:
            c.hline(x0 + 3, x1 - 3, sy + 3, shade(WD, 0.32))                                         # …and its shadow on the books below
    # an ornament and a few flat books in the bottom bay's free end, a plant in the middle one
    c.rect(x1 - 9, base - 9, x1 - 4, base - 7, hexc('8a4a3a'))
    c.hline(x1 - 9, x1 - 4, base - 9, hexc('b8705a'))
    c.rect(x1 - 8, base - 12, x1 - 5, base - 10, hexc('c9b078'))
    # the plinth: a kick board on two bracket feet
    c.rect(x0, base - 5, x1, base - 3, WD)
    c.hline(x0, x1, base - 5, W_)
    for fx in (x0, x1 - 3):
        c.rect(fx, base - 3, fx + 3, base, W_)
        c.vline(fx, base - 3, base, WL)
        c.hline(fx, fx + 3, base, WO)
    _grain(c, x0 + 1, top + 4, x0 + 1, base - 4, shade(W_, 0.86), p['seed'], 3)


# ================================================================================================================================ the chest of drawers
@piece('chest_drawers', 46, 41, 'wall', rooms={'bedroom': 6}, styles={'adult': 5, 'teen': 3, 'sick': 2, 'kid': 2}, tags=('storage', 'drawers'), depth=5,
       variants={k: {'pal': v} for k, v in WOOD_PALS.items()},
       slots=({'id': 'top', 'dx0': 4, 'dx1': 41, 'dy': -39, 'top': True, 'kinds': ('small', 'lamp', 'vanity')},),
       anchors=({'name': 'chest_drawers', 'dx': 23, 'dy': -23},), opens={'kind': 'drawer', 'frames': 3, 'anchor': 'chest_drawers'}, feet=(105, 108),
       note='a chest of three drawers: a lipped top, raised-panel drawers with bail pulls and a keyhole, bracket feet; the top drawer pulls out when it is searched')
def chest_drawers(c, ox, oy, p):
    W_, WL, WD, WO = p['pal']
    x0, x1 = ox + 1, ox + 44
    top, base = oy - 39, oy
    c.shadow((x0 + x1) // 2, base + 1, 25, 2, 100)
    # the top: a lipped slab, lit along its front edge, a bead moulding under it
    c.rect(x0 - 2, top, x1 + 2, top + 2, WL)
    c.hline(x0 - 2, x1 + 2, top, shade(WL, 1.3))
    c.hline(x0 - 2, x1 + 2, top + 2, shade(WL, 0.8))
    c.hline(x0 - 1, x1 + 1, top + 3, WO)
    c.hline(x0, x1, top + 4, shade(WD, 0.7))
    c.rect(x0, top + 3, x1, base - 5, WO)                                                            # carcass outline
    c.rect(x0 + 1, top + 4, x1 - 1, base - 5, shade(W_, 0.88))
    c.vline(x0 + 1, top + 4, base - 5, shade(WL, 0.95))
    c.vline(x1 - 1, top + 4, base - 5, shade(WD, 1.0))
    t = p['open']
    dy = int(round(6 * t))
    heights = [(top + 6, top + 13), (top + 15, top + 23), (top + 25, top + 33)]
    for i, (ya, yb) in enumerate(heights):
        off = dy if i == 0 else 0
        if i == 0 and dy:
            c.rect(x0 + 3, ya - 1, x1 - 3, ya + dy, hexc('1c1410'))                                  # the dark gap the drawer came out of
            c.rect(x0 + 4, ya + 1, x1 - 4, ya + 2, hexc('c8b8a0'))                                   # a folded shirt on top of what's inside
            c.hline(x0 + 4, x1 - 4, ya + 1, hexc('e8dcc4'))
        c.rect(x0 + 2, ya + off, x1 - 2, yb + off, WO)
        _raised(c, x0 + 3, ya + 1 + off, x1 - 3, yb - 1 + off, W_, WL, WD, WO)
        _hgrain(c, x0 + 5, ya + 2 + off, x1 - 5, yb - 2 + off, shade(W_, 0.93), shade(WL, 1.0), 6 + i * 3)
        my = (ya + yb) // 2 + off
        for bx in (x0 + 10, x1 - 14):                                                                  # a bail pull: two posts and a bar
            c.rect(bx, my - 1, bx + 4, my, BRASS)
            c.hline(bx, bx + 4, my - 1, BRASS_LT)
            c.put(bx, my + 1, BRASS_DK); c.put(bx + 4, my + 1, BRASS_DK)
        if i == 0:
            c.put((x0 + x1) // 2, my - 1, hexc('2a1c17'))                                              # the keyhole
            c.put((x0 + x1) // 2, my, hexc('2a1c17'))
    c.hline(x0 + 1, x1 - 1, base - 5, shade(WD, 0.8))
    _feet(c, x0, x1, base, W_, WD, WL)


# ================================================================================================================================ the dressing table
@piece('dressing_table', 43, 34, 'wall', rooms={'bedroom': 6}, styles={'adult': 6, 'kid': 1}, tags=('storage', 'mirror', 'dressing'), depth=5,
       variants={'dark': {'pal': WOOD_PALS['dark'], 'cracked': False}, 'light': {'pal': WOOD_PALS['light'], 'cracked': False}, 'dark_cracked': {'pal': WOOD_PALS['dark'], 'cracked': True}},
       slots=({'id': 'top', 'dx0': 24, 'dx1': 40, 'dy': -33, 'top': True, 'kinds': ('small', 'vanity')},),
       anchors=({'name': 'dressing_table', 'dx': 32, 'dy': -37, 'top': True, 'note': 'the jewellery box on the top'},),
       feet=(105, 108), note='a dressing table: a swivel mirror on turned posts (one is cracked), a lace doily on the top, two drawers with brass pulls, turned feet')
def dressing_table(c, ox, oy, p):
    W_, WL, WD, WO = p['pal']
    x0, x1 = ox + 1, ox + 41
    top, base = oy - 33, oy
    c.shadow((x0 + x1) // 2, base + 1, 23, 2, 95)
    # the swivel mirror, above and behind the table top: two turned posts, a bevelled frame, glass that reflects the room
    mx0, mx1, my0, my1 = ox + 8, ox + 36, oy - 69, oy - 38
    for px in (mx0 + 1, mx1 - 2):
        c.rect(px, my1 - 2, px + 1, top, WD)
        c.vline(px, my1 - 2, top, WL)
        c.put(px, my1 - 8, BRASS); c.put(px + 1, my1 - 8, BRASS_DK)                                  # the thumbscrew on each post
    c.rect(mx0, my0, mx1, my1, WO)
    c.rect(mx0 + 1, my0 + 1, mx1 - 1, my1 - 1, W_)
    c.hline(mx0 + 1, mx1 - 1, my0 + 1, shade(WL, 1.3))
    c.vline(mx0 + 1, my0 + 1, my1 - 1, shade(WL, 1.1))
    c.hline(mx0 + 1, mx1 - 1, my1 - 1, WD)
    c.vline(mx1 - 1, my0 + 1, my1 - 1, WD)
    c.rect(mx0 + 3, my0 + 3, mx1 - 3, my1 - 3, shade(WD, 0.5))                                         # the bevel
    _mirror_glass(c, mx0 + 4, my0 + 4, mx1 - 4, my1 - 4, p['cracked'], 7)
    for (cx_, cy_) in ((mx0 + 3, my0 + 3), (mx1 - 3, my0 + 3)):                                       # carved corner rosettes
        c.put(cx_, cy_, BRASS)
    # the table top with an overhang, a lace doily at the left end, a runner of inlay
    c.rect(x0 - 1, top, x1 + 1, top + 2, WL)
    c.hline(x0 - 1, x1 + 1, top, shade(WL, 1.3))
    c.hline(x0 - 1, x1 + 1, top + 2, shade(WL, 0.8))
    c.hline(x0, x1, top + 3, WO)
    c.rect(x0 + 3, top, x0 + 17, top + 1, mix(WL, hexc('e0d6c0'), 0.7))                                # the doily
    # the body: two wide drawers over a shaped apron, short turned legs
    c.rect(x0, top + 3, x1, base - 5, WO)
    c.rect(x0 + 1, top + 4, x1 - 1, base - 5, shade(W_, 0.88))
    c.vline(x0 + 1, top + 4, base - 5, shade(WL, 0.95))
    c.vline(x1 - 1, top + 4, base - 5, WD)
    for (ya, yb) in ((top + 5, top + 13), (top + 16, base - 7)):
        c.rect(x0 + 2, ya, x1 - 2, yb, WO)
        _raised(c, x0 + 3, ya + 1, x1 - 3, yb - 1, W_, WL, WD, WO)
        _hgrain(c, x0 + 5, ya + 2, x1 - 5, yb - 2, shade(W_, 0.93), shade(WL, 1.0), ya)
        my = (ya + yb) // 2
        for bx in (x0 + 11, x1 - 15):
            c.rect(bx, my - 1, bx + 3, my, BRASS)
            c.put(bx, my - 1, BRASS_LT)
    c.hline(x0 + 1, x1 - 1, base - 6, shade(WD, 0.8))
    for fx in (x0 + 1, x1 - 4):                                                                        # turned legs
        c.rect(fx, base - 5, fx + 2, base, W_)
        c.vline(fx, base - 5, base, WL)
        c.put(fx + 1, base - 3, WD)
        c.hline(fx - 1, fx + 3, base, WO)
