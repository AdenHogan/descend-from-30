"""HOUSEPLANTS, KEPT THE WAY A HOME KEEPS THEM (owner round 48k: "that plant on the floor, if it were my home, it would logically go on a table, right? If it were a larger plant then sure it would be
in a big pot on the floor and it would grow tall in the room").

The old `plant_pot` was a 23 x 39 desk plant dealt onto the FLOOR as clutter — into a bathroom, beside the toilet. Two pieces replace it, and `home_logic` makes the split a rule:

  plant_floor  a TALL plant in a BIG pot (rubber plant, palm, fiddle-leaf fig, yucca; one dead one) — `keep='plant'`: at least 48 px tall, only in a bedroom / living room / dining room / study,
               and it stands beside furniture (`near`), never alone in the middle of a wall;
  plant_desk   a small potted plant you could lift (a succulent, a cactus, a fern, a trailing pothos, a baby rubber plant, a dead one) — a TOP piece: it stands on a table, a shelf, a cistern,
               a counter, never on the floor, in any room.

Same method as furn_props.py: propkit tones, light from the upper left, a selective outline, a contact shadow.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furnlib as FL  # noqa: F401
import propkit as K
from furnlib import piece
from furn_more import _leaf
from pixlib import hexc, shade, mix

SOIL = hexc('3a2a20')
SOIL_DRY = hexc('8a7a68')


# ---------------------------------------------------------------------------------------------------------------------------------------- shared bits
def _pot(lc, cx, oy, rt, rb, ph, col, band=None, glaze=False, dry=False, crack=False):
    """A pot standing on a saucer: a tapered bucket with a lit rim band, the soil showing, a saucer under it. `oy` = its feet row."""
    K.ell(lc, cx, oy - 0.2, rt + 1.6, 1.5, shade(col, 0.72))                              # the saucer
    K.ell(lc, cx, oy - 0.6, rt + 1.0, 1.0, shade(col, 0.92))
    ytop, ybot = oy - ph, oy - 2
    K.frustum(lc, cx, ytop, ybot, rt, rb, col, ry_t=max(1.5, rt * 0.34), ry_b=max(1.1, rb * 0.30), inner=SOIL_DRY if dry else SOIL, rim=shade(col, 1.3),
              gloss=glaze, n=5, lo=0.52, hi=1.30, band=band)
    for k in range(3 if rt > 5 else 2):                                                  # a few grains of grit on the soil
        lc.put(int(cx - rt * 0.5 + k * rt * 0.45), int(ytop), shade(SOIL_DRY if dry else SOIL, 1.5))
    if crack:
        x = int(cx) + 1
        for y in range(int(ytop) + 3, int(ybot) - 1):
            lc.put(x + (1 if (y % 3) == 0 else 0), y, hexc('2a1c14'))


def _stem(lc, x0, y0, x1, y1, col, thick=1):
    for k in range(thick):
        lc.line(int(round(x0)) + k, int(round(y0)), int(round(x1)) + k, int(round(y1)), shade(col, 0.78 if k else 1.0))


def _frond(lc, bx, by, ang, ln, bend, tn, leaflet, droop=0.5, stem=None):
    """A pinnate frond (a palm's, a fern's): a stem that rises at `ang` degrees from the vertical and bends over under its own weight, with paired leaflets along it that shrink toward
    the tip. `tn` = tones darkest first; the side facing the light (up and left) takes the lighter ones."""
    x, y = float(bx), float(by)
    head = math.radians(ang)
    side = 1.0 if ang >= 0 else -1.0
    steps = max(6, int(ln * 1.5))
    pts = []
    for i in range(steps + 1):
        t = i / float(steps)
        pts.append((x, y, t, head))
        head += side * math.radians(bend) * (0.4 + 1.2 * t) / steps * 3.0
        x += math.sin(head) * ln / steps
        y -= math.cos(head) * ln / steps
    sc = stem or tn[1]
    for (px_, py_, t, h) in pts:
        lc.put(int(round(px_)), int(round(py_)), sc)
    for i in range(2, len(pts), 2):
        px_, py_, t, h = pts[i]
        ll = max(1.5, leaflet * (math.sin(math.pi * min(1.0, 0.18 + t * 0.9)) ** 0.8))
        for sgn in (-1, 1):
            a = h + sgn * math.radians(62 - 14 * t)
            ex = px_ + math.sin(a) * ll
            ey = py_ - math.cos(a) * ll + droop * ll * 0.55
            lit = (math.sin(a) < 0.05) or (ey < py_ - 0.5)
            col = tn[3 if lit and t < 0.7 else (2 if lit else (1 if t < 0.8 else 0))]
            lc.line(int(round(px_)), int(round(py_)), int(round(ex)), int(round(ey)), col)


def _specks(lc, rng, cx, cy, rx, ry, col, n):
    for _ in range(n):
        lc.put(int(cx + rng.uniform(-rx, rx)), int(cy + rng.uniform(-ry, ry)), col)


# ---------------------------------------------------------------------------------------------------------------------------------------- the big floor plant
POTS = {                                      # (body colour, band colour or None, glazed)
    'terra': (hexc('b0643c'), None, False),
    'slate': (hexc('5a6a7a'), hexc('7a8ea0'), True),
    'teal': (hexc('2f6a74'), hexc('4a8c98'), True),
    'cream': (hexc('d8d0bc'), hexc('b0a688'), True),
    'char': (hexc('3a3a42'), hexc('55555e'), True),
}


@piece('plant_floor', 26, 56, 'floor', keep='plant', rooms={'living_room': 7, 'study': 3, 'dining_room': 2, 'bedroom': 3}, styles={'adult': 3, 'sick': 2, 'teen': 1},
       tags=('plant',), near=('storage', 'seating_lounge', 'sleeping'), limit=1, feet=(112, 119),
       variants={'rubber': {'kind': 'rubber', 'pot': 'terra'}, 'rubber_slate': {'kind': 'rubber', 'pot': 'slate'}, 'palm': {'kind': 'palm', 'pot': 'teal'},
                 'palm_terra': {'kind': 'palm', 'pot': 'terra'}, 'fig': {'kind': 'fig', 'pot': 'cream'}, 'fig_terra': {'kind': 'fig', 'pot': 'terra'},
                 'yucca': {'kind': 'yucca', 'pot': 'char'}, 'dead': {'kind': 'dead', 'pot': 'terra'}},
       note='a tall houseplant in a big pot on a saucer — a rubber plant, a palm, a fiddle-leaf fig, a yucca, or one nobody watered; it stands beside furniture, a person\'s height or more')
def plant_floor(c, ox, oy, p):
    kind = p['kind']
    body, band, glaze = POTS[p['pot']]
    cx = ox + 13.0
    K.contact_shadow(c, cx, oy + 0.6, 12, 1.9, 100)
    L = K.Layer(c)
    lc = L.c
    rng = random.Random(len(kind) * 17 + len(p['pot']))
    ph = 17
    soil_y = oy - ph
    _pot(lc, cx, oy, 8.2, 6.4, ph, body, band=(band, 3) if band else None, glaze=glaze, dry=(kind == 'dead'), crack=(kind == 'dead'))
    if kind == 'rubber':
        _rubber(lc, cx, soil_y, rng)
    elif kind == 'palm':
        _palm(lc, cx, soil_y, rng)
    elif kind == 'fig':
        _fig(lc, cx, soil_y, rng)
    elif kind == 'yucca':
        _yucca(lc, cx, soil_y, rng)
    else:
        _dead_tall(lc, cx, soil_y, oy, rng)
    L.flush()


def _rubber(lc, cx, soil_y, rng):
    """A rubber plant: one upright woody stem, broad dark glossy leaves up it in alternate pairs, each with a pale midrib, a fresh red-sheathed bud at the top."""
    top = soil_y - 31
    for k in range(2):
        lc.vline(int(cx) - 1 + k, top + 3, int(soil_y), hexc('5a4a30') if k else hexc('46382a'))
    greens = [hexc('2a5230'), hexc('335d38'), hexc('3c6a40'), hexc('47784a')]
    for i in range(9):                                                                     # alternate sides, climbing, leaves getting smaller toward the top
        t = i / 8.0
        y = soil_y - 5 - t * 24
        side = -1 if i % 2 == 0 else 1
        ln = 11.0 - 4.0 * t
        w = 3.5 - 1.0 * t
        rise = 3.0 + 5.5 * t + rng.uniform(-0.8, 0.8)
        _leaf(lc, cx, y, cx + side * ln, y - rise, w, greens[(i + (0 if side < 0 else 1)) % 4])
    sheath = hexc('a8423a')
    lc.vline(int(cx), top, top + 4, sheath)                                                # the new leaf rolled in its red sheath
    lc.put(int(cx) - 1, top + 1, shade(sheath, 0.7))
    lc.put(int(cx), top - 1, hexc('c05a48'))
    _leaf(lc, cx, top + 3, cx + 3, top - 6, 2.2, greens[3])
    _leaf(lc, cx, top + 3, cx - 3, top - 4, 2.0, greens[2])


def _palm(lc, cx, soil_y, rng):
    """An areca / kentia palm: a fountain of arching fronds from one crown, the oldest low and drooping, the newest upright in the middle."""
    tn_back = K.tones(hexc('2e5a34'), 4, 0.7, 1.15)
    tn_mid = K.tones(hexc('3f7040'), 4, 0.72, 1.28)
    tn_front = K.tones(hexc('558a4c'), 4, 0.74, 1.36)
    plan = [(-74, 15, 26, tn_back), (70, 15, 26, tn_back), (-52, 20, 22, tn_mid), (48, 20, 22, tn_mid), (-30, 24, 16, tn_back), (28, 25, 16, tn_back),
            (-12, 28, 10, tn_mid), (11, 29, 10, tn_mid), (-2, 31, 4, tn_front), (-62, 14, 30, tn_front), (58, 15, 30, tn_front)]
    for (ang, ln, bend, tn) in plan:
        _frond(lc, cx + rng.uniform(-1.0, 1.0), soil_y + 1, ang, ln, bend, tn, 3.6, droop=0.7, stem=shade(tn[1], 0.9))


def _fig(lc, cx, soil_y, rng):
    """A fiddle-leaf fig: a slim woody trunk and a few very big paddle leaves with pale veins, held up and out."""
    top = soil_y - 30
    for k in range(2):
        lc.vline(int(cx) - 1 + k, top + 2, int(soil_y), hexc('8a6a48') if k else hexc('6a4e36'))
    greens = [hexc('3f7040'), hexc('4c8048'), hexc('5a9050'), hexc('679c58')]
    for i in range(6):
        t = i / 5.0
        y = soil_y - 7 - t * 20
        side = -1 if i % 2 == 0 else 1
        ln = 11.0 - 2.4 * t
        w = 4.8 - 0.9 * t
        rise = 3.5 + 5 * t
        _leaf(lc, cx, y, cx + side * ln, y - rise, w, greens[(i * 3) % 4])
    _leaf(lc, cx, top + 3, cx + 2, top - 6, 2.8, greens[3])
    _leaf(lc, cx, top + 4, cx - 4, top - 2, 2.8, greens[2])


def _yucca(lc, cx, soil_y, rng):
    """A yucca: a thick, ringed trunk and a burst of stiff sword leaves at the top, the oldest hanging down."""
    top = soil_y - 17
    for k in range(3):
        for y in range(top, int(soil_y) + 1):
            lc.put(int(cx) - 1 + k, y, hexc('7a5e40') if k == 0 else (hexc('6a4f36') if k == 1 else hexc('4e3a28')))
    for y in range(top + 2, int(soil_y), 3):
        lc.hline(int(cx) - 1, int(cx) + 1, y, hexc('3e2e20'))                              # the leaf scars ringing the trunk
    tn = K.tones(hexc('4c7a46'), 5, 0.55, 1.28)
    for (ang, ln) in ((-84, 13), (80, 13), (-66, 17), (62, 17), (-46, 20), (44, 20), (-24, 22), (22, 22), (-6, 23), (8, 22), (-56, 14), (54, 14)):
        a = math.radians(ang)
        droop = 0.40 if abs(ang) > 60 else 0.14
        for i in range(int(ln * 1.7)):
            t = i / (ln * 1.7)
            x = cx + math.sin(a) * ln * t
            y = top + 1 - math.cos(a) * ln * t + droop * ln * t * t * (1.0 if abs(ang) > 45 else 0.4)
            half = 0.7 + 1.5 * (1.0 - t) ** 0.65 * min(1.0, 0.45 + t * 4.0)
            for k in range(-int(math.ceil(half)), int(math.ceil(half)) + 1):
                if abs(k) <= half:
                    edge = abs(k) > half - 0.9
                    lit = (k < 0) == (ang >= -10) if abs(ang) > 10 else (k < 0)
                    col = tn[4] if (edge and lit and t < 0.8) else (tn[3] if lit else (tn[1] if abs(k) < half * 0.4 else tn[0]))
                    lc.put(int(round(x + k * math.cos(a))), int(round(y - k * math.sin(a) * 0.0)), col)


def _dead_tall(lc, cx, soil_y, oy, rng):
    """One nobody watered: a bare woody stem, a few brown leaves still hanging, curled and dry, the rest fallen by the pot."""
    top = soil_y - 26
    for k in range(2):
        lc.vline(int(cx) - 1 + k, top, int(soil_y), hexc('5a4a30') if k else hexc('46382a'))
    dry = [hexc('6a5230'), hexc('7e6238'), hexc('92743e'), hexc('a8884a')]
    for (y, side, ln, dr) in ((soil_y - 6, -1, 8, 5), (soil_y - 10, 1, 9, 6), (soil_y - 14, -1, 8, 6), (soil_y - 18, 1, 8, 7), (soil_y - 21, -1, 7, 6), (soil_y - 24, 1, 6, 6)):
        ex = cx + side * ln
        mx = cx + side * ln * 0.55
        my = y - 3
        lc.line(int(cx), int(y), int(mx), int(my), shade(dry[0], 0.8))                      # the leaf stalk arching up and out…
        _leaf(lc, mx, my, ex, my + dr, 2.4, dry[(int(y) + (0 if side < 0 else 1)) % 4])        # …the dry blade hanging off its end
    for (dx, dy) in ((11, 0), (-12, -1), (14, -1)):                                           # fallen leaves lying by the saucer
        lc.rect(int(cx) + dx, oy + dy - 1, int(cx) + dx + 2, oy + dy, dry[1])
        lc.put(int(cx) + dx + 3, oy + dy, dry[0])


# ---------------------------------------------------------------------------------------------------------------------------------------- the small desk plant
DPOTS = {'terra': (hexc('b0643c'), None), 'white': (hexc('e0dacb'), hexc('b8b098')), 'slate': (hexc('5a6a7a'), hexc('7a8ea0')), 'teal': (hexc('2f6a74'), hexc('4a8c98')),
         'yellow': (hexc('c8a040'), hexc('e0c060'))}


@piece('plant_desk', 16, 22, 'top', rooms={'bedroom': 3, 'living_room': 3, 'study': 3, 'dining_room': 2, 'kitchen': 3, 'bathroom': 3}, tags=('small', 'plant'), on=('small', 'cistern'), limit=2,
       variants={'succulent': {'kind': 'succulent', 'pot': 'white'}, 'cactus': {'kind': 'cactus', 'pot': 'terra'}, 'fern': {'kind': 'fern', 'pot': 'slate'},
                 'trailing': {'kind': 'trailing', 'pot': 'white'}, 'baby_rubber': {'kind': 'baby_rubber', 'pot': 'terra'}, 'herbs': {'kind': 'herbs', 'pot': 'yellow'},
                 'dead': {'kind': 'dead', 'pot': 'terra'}},
       note='a small potted plant you could lift: a succulent, a cactus, a fern, a trailing pothos, a baby rubber plant, a pot of herbs, or a dead one — it stands ON something (a table, a shelf, a cistern, a counter)')
def plant_desk(c, ox, oy, p):
    kind = p['kind']
    body, band = DPOTS[p['pot']]
    cx = ox + 8.0
    K.contact_shadow(c, cx, oy + 0.5, 6.5, 1.3, 90)
    L = K.Layer(c)
    lc = L.c
    rng = random.Random(len(kind) * 13 + len(p['pot']))
    ph = 8
    soil_y = oy - ph
    dead = kind == 'dead'
    K.ell(lc, cx, oy - 0.3, 5.2, 1.0, shade(body, 0.72))                                    # the saucer
    K.frustum(lc, cx, soil_y, oy - 1, 4.2, 3.0, body, ry_t=1.4, ry_b=1.0, inner=SOIL_DRY if dead else SOIL, rim=shade(body, 1.3), gloss=(p['pot'] != 'terra'), band=(band, 2) if band else None)
    if dead:
        for y in range(int(soil_y) + 2, oy - 2):
            lc.put(int(cx) + 1, y, hexc('2a1c14'))
    if kind == 'succulent':
        tn = [hexc('3a7a6a'), hexc('4c9078'), hexc('62a688'), hexc('7cbc9a')]
        for (dx, dy, w) in ((-4, -2, 1.5), (4, -2, 1.5), (-3, -4.5, 1.5), (3, -4.5, 1.5), (0, -6, 1.4), (-5, 0, 1.3), (5, 0, 1.3)):
            _leaf(lc, cx + dx * 0.2, soil_y + 1, cx + dx, soil_y + dy, w, tn[int(dx + dy) % 4])
        lc.put(int(cx), int(soil_y) - 5, hexc('d88a9a'))                                    # a small bud at the heart
    elif kind == 'cactus':
        col = hexc('4a8a52')
        K.cyl(lc, cx, soil_y - 9, soil_y, 2.6, col, ry=1.1, cap=True, n=5)
        lc.vline(int(cx), int(soil_y) - 8, int(soil_y) - 1, shade(col, 0.7))                 # the ridge down its front
        for y in range(int(soil_y) - 8, int(soil_y) - 1, 2):
            lc.put(int(cx) - 1, y, hexc('e8e0b0'))
            lc.put(int(cx) + 1, y + 1, hexc('e8e0b0'))                                      # the spines
        K.sphere(lc, cx + 0.5, soil_y - 10.5, 1.5, 1.2, hexc('d85a7a'), n=4)                   # the flower on top
    elif kind == 'fern':
        tn = K.tones(hexc('3f7a44'), 4, 0.7, 1.34)
        for (ang, ln, bend) in ((-64, 6, 16), (-30, 8, 10), (0, 9, 4), (28, 8, 10), (62, 6, 16)):
            _frond(lc, cx, soil_y + 1, ang, ln, bend, tn, 2.2, droop=0.4, stem=tn[1])
    elif kind == 'trailing':
        tn = [hexc('2f6a3a'), hexc('3c7c46'), hexc('4c9054'), hexc('62a864')]
        for (dx, dy) in ((-3, -3), (0, -5), (3, -3), (-1, -6), (2, -6), (-4, -1), (4, -1)):    # the leafy mound
            _leaf(lc, cx + dx * 0.3, soil_y + 1, cx + dx, soil_y + dy, 1.3, tn[int(dx + dy) % 4])
        for (x0, ln, sg) in ((-4.4, 5, -1), (4.4, 6, 1)):                                    # a vine over the rim and down the pot
            for i in range(int(ln)):
                lc.put(int(cx + x0 + sg * 0.6 * min(1.0, i / 4.0)), int(soil_y + 1 + i), tn[1])
            for i in range(2, int(ln), 3):
                _leaf(lc, cx + x0 + sg * 0.6, soil_y + 1 + i, cx + x0 + sg * 2.8, soil_y + 2 + i, 1.0, tn[(i + 1) % 4])
    elif kind == 'baby_rubber':
        for k in range(2):
            lc.vline(int(cx) - 1 + k, int(soil_y) - 10, int(soil_y), hexc('5a4a30') if k else hexc('46382a'))
        tn = [hexc('2a5230'), hexc('3c6a40'), hexc('47784a')]
        for (y0, dx, dy, w) in ((-3, -5, -2, 1.5), (-5, 5, -2, 1.5), (-7, -4, -2, 1.4), (-8, 4, -3, 1.4)):
            _leaf(lc, cx, soil_y + y0, cx + dx, soil_y + y0 + dy, w, tn[(dx + y0) % 3])
        lc.vline(int(cx), int(soil_y) - 12, int(soil_y) - 10, hexc('a8423a'))               # the new leaf in its red sheath
    elif kind == 'herbs':
        tn = [hexc('3c7c3a'), hexc('52943f'), hexc('6ca84c'), hexc('86bf5a')]
        for (dx, dy) in ((-4, -3), (-2, -5), (0, -4), (2, -6), (4, -3), (-3, -6), (3, -5), (0, -7)):
            _leaf(lc, cx + dx * 0.4, soil_y + 1, cx + dx, soil_y + dy, 1.2, tn[int(dx * 3 + dy) % 4])
    else:                                                                                    # a few dry stems, a leaf hanging dry off each
        for (dx, dy, sg) in ((-2, -8, -1), (3, -9, 1), (-5, -5, -1), (5, -6, 1)):
            lc.line(int(cx), int(soil_y), int(cx + dx), int(soil_y + dy), hexc('6a5a3a'))
            _leaf(lc, cx + dx, soil_y + dy, cx + dx + sg * 1.5, soil_y + dy + 3.5, 1.0, hexc('9a7a3a') if dx % 2 else hexc('6a5230'))
    L.flush()
