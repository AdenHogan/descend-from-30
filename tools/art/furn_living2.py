"""THE LIVING ROOM, part two: the sideboard + the TVs, open shelving, the milk-crate cubes, the piano, the china cabinet and the hearth (owner round 47f). See furn_living.py."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import propkit as K
from furnlib import piece
from furn_case import _book
from pixlib import hexc, shade, mix

INTERIOR = hexc('2c2620')
BRASS, BRASS_LT = hexc('b89a48'), hexc('e4cc78')

FIN = {
    'teak': dict(body='9a6234', lt='c08a52', dk='5e3a1e', out='2e1c10', handle='c8a050'),
    'walnut': dict(body='5e3a2a', lt='84553e', dk='36201a', out='1c100c', handle='c8a050'),
    'cream': dict(body='d6ceb4', lt='ece6d0', dk='aaa28a', out='5e5846', handle='8a8a84'),
    'oak': dict(body='b08a58', lt='d2aa72', dk='7a5a34', out='3e2a14', handle='4a3a2a'),
}
FIN_C = {k: {kk: hexc(vv) for kk, vv in v.items()} for k, v in FIN.items()}


def _slab_door(c, x0, y0, x1, y1, f, t=0.0, hinge='left', knob_side=None):
    """A cupboard door: a lit slab with a thin dark joint; open t of the way = a narrow slab at the hinge edge over the dark inside."""
    if t > 0.001:
        c.rect(x0, y0, x1, y1, INTERIOR)
        c.hline(x0, x1, (y0 + y1) // 2, shade(INTERIOR, 1.7))
        c.rect(x0 + 2, y1 - 5, x0 + 5, y1 - 1, hexc('8a4a3a'))
        w = x1 - x0 + 1
        dw = max(2, int(round(w * (1.0 - 0.85 * t))))
        xs = (x0, x0 + dw - 1) if hinge == 'left' else (x1 - dw + 1, x1)
        c.rect(xs[0], y0, xs[1], y1, shade(f['body'], 0.8))
        c.hline(xs[0], xs[1], y0, f['lt'])
        c.vline(xs[1] if hinge == 'left' else xs[0], y0, y1, f['dk'])
        return
    c.rect(x0, y0, x1, y1, f['body'])
    c.hline(x0, x1, y0, f['lt'])
    c.vline(x0, y0, y1, shade(f['lt'], 0.95))
    c.hline(x0, x1, y1, f['dk'])
    c.vline(x1, y0, y1, f['dk'])
    hx = x1 - 3 if hinge == 'left' else x0 + 2
    c.vline(hx, (y0 + y1) // 2 - 2, (y0 + y1) // 2 + 2, f['handle'])
    c.put(hx, (y0 + y1) // 2 - 2, BRASS_LT)


# ================================================================================================================================ the sideboard
@piece('sideboard', 66, 28, 'wall', rooms={'living_room': 7, 'dining_room': 7}, styles={'mid': 8, 'parlour': 3, 'cosy': 2, 'formal': 4, 'family': 4, 'diner': 5, 'party': 6}, tags=('storage', 'sideboard'), depth=5,
       variants={'teak': {'fin': 'teak', 'for': ['mid', 'diner']}, 'walnut': {'fin': 'walnut', 'for': ['parlour', 'formal']}, 'cream': {'fin': 'cream', 'for': ['cosy', 'family', 'party']},
                 'oak': {'fin': 'oak', 'for': ['cosy', 'family', 'formal', 'party']}},
       slots=({'id': 'top', 'dx0': 4, 'dx1': 62, 'dy': -26, 'top': True, 'kinds': ('lamp', 'small', 'tv', 'big')},),
       anchors=({'name': 'sideboard', 'dx': 50, 'dy': -12}, {'name': 'sideboard_drawers', 'dx': 33, 'dy': -14}), opens={'kind': 'door_h', 'frames': 3, 'anchor': 'sideboard'}, feet=(105, 108),
       note='a long sideboard on tapered legs: a cupboard each end and three drawers between, brass pulls, a lipped top; the right-hand door swings open when searched')
def sideboard(c, ox, oy, p):
    f = FIN_C[p['fin']]
    t = p['open']
    x0, x1 = ox + 1, ox + 64
    top, body_b = oy - 26, oy - 6
    c.shadow((x0 + x1) // 2, oy + 1, 35, 2, 100)
    for lx in (x0 + 3, x1 - 5):                                                                  # the legs: tapered, splayed a pixel
        for k in range(6):
            c.hline(lx + (0 if k < 3 else 1) - (1 if lx < ox + 30 else 0), lx + 1 + (0 if k < 3 else 0), oy - 5 + k, f['dk'] if k % 2 else shade(f['dk'], 1.15))
    c.rect(x0, top + 3, x1, body_b, f['out'])                                                    # the carcass
    c.rect(x0 + 1, top + 3, x1 - 1, body_b - 1, shade(f['dk'], 0.92))
    c.rect(x0 - 1, top, x1 + 1, top + 2, f['lt'])                                                # the lipped top
    c.hline(x0 - 1, x1 + 1, top, shade(f['lt'], 1.25))
    c.hline(x0 - 1, x1 + 1, top + 2, f['body'])
    c.hline(x0 - 1, x1 + 1, top + 3, f['out'])
    ya, yb = top + 5, body_b - 2
    _slab_door(c, x0 + 1, ya, x0 + 20, yb, f, 0.0, 'right')                                      # left cupboard
    for k in range(3):                                                                           # three drawers between
        y0 = ya + k * 5
        c.rect(x0 + 22, y0, x1 - 22, y0 + 4, f['body'])
        c.hline(x0 + 22, x1 - 22, y0, f['lt'])
        c.hline(x0 + 22, x1 - 22, y0 + 4, f['dk'])
        c.hline(ox + 30, ox + 36, y0 + 2, f['handle'])
        c.put(ox + 30, y0 + 2, BRASS_LT)
    _slab_door(c, x1 - 20, ya, x1 - 1, yb, f, t, 'left')                                         # right cupboard (opens)
    c.hline(x0, x1, body_b, f['dk'])
    for k in range(4):                                                                           # the grain
        c.hline(x0 + 2 + k * 14, x0 + 6 + k * 14, top + 1, shade(f['lt'], 0.86))


# ================================================================================================================================ the TVs
@piece('tv_crt', 26, 28, 'top', rooms={'living_room': 6}, styles={'mid': 8, 'cosy': 1, 'parlour': 0.4}, tags=('tv',), on=('tv',), limit=1,
       variants={'wood': {'case': '8a5a34', 'for': ['mid', 'cosy']}, 'white': {'case': 'd8d2c0', 'for': ['mid']}, 'black': {'case': '2a2a2e', 'for': ['mid', 'cosy']}},
       anchors=({'name': 'tv', 'dx': 13, 'dy': -11, 'top': True},), opens={'kind': 'screen_off', 'frames': 1, 'anchor': 'tv'},
       anims=({'kind': 'static', 'dx': 4, 'dy': -17, 'w': 13, 'h': 11, 'color': 'c8d4d0', 'top': True},),
       note='a small CRT television on a cabinet case with rabbit-ear aerials: a curved glass with a glare, two knobs and a speaker grille; its live picture is snow, and goes dark when it is searched')
def tv_crt(c, ox, oy, p):
    case = hexc(p['case'])
    on = p['open'] <= 0.001
    L = K.Layer(c)
    lc = L.c
    cx = ox + 11
    c.shadow(cx + 2, oy, 14, 1.6, 100)
    for ex, ey in ((-1, 0), (1, 0)):                                                             # rabbit ears
        lc.line(cx + 1, oy - 20, cx + 1 + ex * 7, oy - 27, hexc('b8bcc0'))
    K.slab(lc, ox + 1, oy - 18, ox + 23, oy - 1, case, d=2, top=shade(case, 1.22))
    lc.rect(ox + 3, oy - 16, ox + 17, oy - 4, shade(case, 0.55))                                # the bezel
    glass = hexc('2a3a38') if on else hexc('1a1e1e')
    lc.rect(ox + 4, oy - 15, ox + 16, oy - 5, glass)
    lc.hline(ox + 4, ox + 16, oy - 15, shade(glass, 1.6))
    lc.vline(ox + 4, oy - 15, oy - 5, shade(glass, 1.3))
    for k in range(3):                                                                           # the glare
        lc.put(ox + 6 + k, oy - 13 + k // 2, hexc('9aaaa6') if on else hexc('4a5a58'))
    for ky in (oy - 14, oy - 11):                                                                # two knobs and a grille on the right
        lc.rect(ox + 19, ky, ox + 20, ky + 1, hexc('b8b0a0'))
    for gy in range(oy - 8, oy - 3, 2):
        lc.hline(ox + 19, ox + 21, gy, shade(case, 0.5))
    lc.put(ox + 3, oy - 3, hexc('d8483a') if on else hexc('3a1a18'))
    for fx in (ox + 3, ox + 20):
        lc.rect(fx, oy, fx + 1, oy, shade(case, 0.4))
    L.flush()


@piece('tv_wall', 42, 28, 'decor', rooms={'living_room': 6}, styles={'squat': 8}, tags=('tv',), limit=1, wall_y=(26, 36),
       variants={'black': {}}, anims=({'kind': 'tv', 'dx': 3, 'dy': 3, 'w': 36, 'h': 20, 'color': 'c8d4d0'},),
       note='a big flat-screen on the wall: a thin bezel, the black glass with a diagonal glare, a standby light, the cable hanging down behind — its picture is the struck-TV detail: snow, flashes, a crack')
def tv_wall(c, ox, oy, p):
    import wall_art3d
    wall_art3d.tv_wall(c, ox, oy, p)


# ================================================================================================================================ open shelving
@piece('shelving_open', 34, 64, 'wall', rooms={'living_room': 6, 'study': 5}, styles={'mid': 8, 'lodge': 1}, tags=('books', 'storage'), depth=6,
       variants={'teak': {'fin': 'teak', 'seed': 4}, 'oak': {'fin': 'oak', 'seed': 9}},
       slots=({'id': 'top', 'dx0': 4, 'dx1': 30, 'dy': -62, 'top': True, 'kinds': ('small', 'lamp')},),
       anchors=({'name': 'shelving_upper', 'dx': 17, 'dy': -44}, {'name': 'shelving_records', 'dx': 17, 'dy': -17}), feet=(105, 108),
       note='mid-century open shelving: a teak frame with three open shelves — books, an orange vase and a bust, a rack of vinyl records — over a closed cupboard on tapered legs')
def shelving_open(c, ox, oy, p):
    f = FIN_C[p['fin']]
    rng = random.Random(p['seed'])
    x0, x1 = ox + 1, ox + 32
    top, base = oy - 62, oy
    c.shadow((x0 + x1) // 2, base + 1, 18, 2, 100)
    c.rect(x0 - 1, top, x1 + 1, base - 5, f['out'])
    c.rect(x0 + 1, top + 2, x1 - 1, base - 18, shade(f['dk'], 0.5))                              # the dark back
    for sx0, sx1, lit in ((x0, x0 + 1, True), (x1 - 1, x1, False)):                              # uprights
        c.rect(sx0, top + 1, sx1, base - 6, f['body'])
        c.vline(sx0, top + 1, base - 6, f['lt'] if lit else f['dk'])
    c.rect(x0 - 1, top, x1 + 1, top + 2, f['lt'])                                                # the top board
    c.hline(x0 - 1, x1 + 1, top, shade(f['lt'], 1.25))
    c.hline(x0 - 1, x1 + 1, top + 2, f['dk'])
    shelves = (top + 21, top + 38)
    bays = ((top + 3, shelves[0] - 1), (shelves[0] + 2, shelves[1] - 1), (shelves[1] + 2, base - 19))
    for sy in shelves + (base - 18,):
        c.rect(x0, sy, x1, sy + 1, f['body'])
        c.hline(x0, x1, sy, f['lt'])
        c.hline(x0, x1, sy + 2, shade(f['dk'], 0.6))
    ya, yb = bays[0][0], bays[0][1]                                                              # top bay: books, a vase, a bust
    x = x0 + 2
    for w in (2, 3, 2, 3):
        h = rng.randint(10, 15)
        _book(c, x, yb, w, h, rng.choice(F.BOOKS), rng)
        x += w
    K.sphere(c, x1 - 8, yb - 5, 4.4, 5.0, hexc('d8803a'), gloss=True)                           # an orange glass vase
    K.cyl(c, x1 - 8, yb - 12, yb - 9, 1.2, hexc('c26c2a'), ry=0.6)
    ya, yb = bays[1][0], bays[1][1]                                                              # middle bay: a plant and a framed photo, a few lying books
    K.cyl(c, x0 + 8, yb - 6, yb - 1, 3.6, hexc('c8b8a0'), ry=1.4, inner=hexc('3a2a1c'))
    for k in range(4):
        c.line(x0 + 8, yb - 7, x0 + 4 + k * 3, yb - 14 + (k % 2) * 2, hexc('5a7a3a'))
        c.put(x0 + 4 + k * 3, yb - 14 + (k % 2) * 2, hexc('7a9a4a'))
    for k, col in enumerate(('7a2e28', '2f4a63', 'b8a782')):
        c.rect(x0 + 15, yb - 2 - k * 3, x0 + 27, yb - k * 3, hexc(col))
        c.hline(x0 + 15, x0 + 27, yb - 2 - k * 3, shade(hexc(col), 1.25))
    ya, yb = bays[2][0], bays[2][1]                                                              # bottom open bay: vinyl records
    x = x0 + 2
    while x < x1 - 2:
        col = rng.choice(('2a2a2e', '7a2e28', '2f4a63', 'b8a782', '5d6b3a', 'c8a050', '4b3a5c'))
        w = rng.choice((1, 2, 2, 3))
        c.rect(x, yb - 13, x + w - 1, yb, hexc(col))
        c.vline(x, yb - 13, yb, shade(hexc(col), 1.25))
        if w >= 2 and rng.random() < 0.5:
            c.rect(x, yb - 9, x + w - 1, yb - 6, mix(hexc(col), hexc('f0e4c0'), 0.55))          # a sleeve's label band
        x += w
    c.rect(x0, base - 17, x1, base - 6, f['out'])                                                # the cupboard below
    c.rect(x0 + 1, base - 16, x1 - 1, base - 7, f['body'])
    c.vline((x0 + x1) // 2, base - 16, base - 7, f['dk'])
    c.hline(x0 + 1, x1 - 1, base - 16, f['lt'])
    for hx in ((x0 + x1) // 2 - 3, (x0 + x1) // 2 + 2):
        c.vline(hx, base - 13, base - 10, f['handle'])
    for lx in (x0 + 2, x1 - 4):                                                                  # the tapered legs
        c.rect(lx, base - 5, lx + 1, base, f['dk'])
        c.put(lx, base - 5, f['lt'])


# ================================================================================================================================ milk-crate cubes
@piece('crate_cubes', 34, 40, 'wall', rooms={'living_room': 6}, styles={'squat': 8}, tags=('books', 'storage'), depth=5,
       variants={'primary': {'cols': ('e0b830', 'c43a30', '2f5aa8', '3a8a4a'), 'seed': 1}, 'dairy': {'cols': ('d8d8d0', 'c43a30', 'e0b830', '2f5aa8'), 'seed': 2}},
       anchors=({'name': 'crates_upper', 'dx': 17, 'dy': -30}, {'name': 'crates_lower', 'dx': 17, 'dy': -10}), feet=(105, 108),
       note='four milk crates stacked two by two on their sides, each stuffed with paperbacks and vinyl — a squatter\'s bookshelf')
def crate_cubes(c, ox, oy, p):
    rng = random.Random(p['seed'])
    cols = [hexc(k) for k in p['cols']]
    c.shadow(ox + 17, oy + 1, 20, 2, 100)
    for r in range(2):
        for k in range(2):
            x0, y0 = ox + 1 + k * 16, oy - 38 + r * 19
            col = cols[(r * 2 + k) % 4]
            c.rect(x0, y0, x0 + 15, y0 + 18, shade(col, 0.55))                                   # the crate's outline and shadowed inside
            c.rect(x0 + 2, y0 + 2, x0 + 13, y0 + 16, hexc('1c1814'))
            xx = x0 + 3
            while xx < x0 + 13:                                                                  # the spines inside
                w = rng.choice((1, 2, 2))
                h = rng.randint(8, 13)
                bc = rng.choice(F.BOOKS)
                c.rect(xx, y0 + 16 - h, xx + w - 1, y0 + 15, bc)
                c.vline(xx, y0 + 16 - h, y0 + 15, shade(bc, 1.25))
                xx += w
            c.rect(x0, y0, x0 + 15, y0 + 1, col)                                                 # the crate's rim and slotted sides
            c.hline(x0, x0 + 15, y0, shade(col, 1.3))
            c.rect(x0, y0, x0 + 1, y0 + 18, col)
            c.rect(x0 + 14, y0, x0 + 15, y0 + 18, shade(col, 0.82))
            c.rect(x0, y0 + 17, x0 + 15, y0 + 18, shade(col, 0.7))
            for sy in (y0 + 5, y0 + 9, y0 + 13):                                                 # the handle slots
                c.put(x0, sy, shade(col, 0.4)); c.put(x0 + 15, sy, shade(col, 0.4))


# ================================================================================================================================ the piano
@piece('piano_upright', 46, 60, 'wall', rooms={'living_room': 6}, styles={'parlour': 9, 'lodge': 1}, tags=('music', 'storage'), depth=7,
       variants={'mahogany': {'fin': 'walnut'}, 'ebonised': {'fin': 'black'}},
       slots=({'id': 'top', 'dx0': 4, 'dx1': 42, 'dy': -58, 'top': True, 'kinds': ('small', 'lamp')},),
       anchors=({'name': 'piano', 'dx': 23, 'dy': -26},), feet=(105, 108),
       note='an upright piano: a panelled case with a music desk and sheet music, a keyboard of ivory and black keys, a candle bracket each side, pedals; the stool is a separate piece')
def piano_upright(c, ox, oy, p):
    f = FIN_C['walnut'] if p['fin'] == 'walnut' else dict(body=hexc('2a2a30'), lt=hexc('484a54'), dk=hexc('14141a'), out=hexc('0a0a0e'), handle=BRASS)
    x0, x1 = ox + 1, ox + 44
    top, base = oy - 58, oy
    c.shadow((x0 + x1) // 2, base + 1, 26, 2, 105)
    c.rect(x0 - 1, top, x1 + 1, base - 5, f['out'])
    c.rect(x0, top + 2, x1, top + 4, f['lt'])                                                    # the lid
    c.hline(x0 - 1, x1 + 1, top, shade(f['lt'], 1.2))
    c.rect(x0 + 1, top + 5, x1 - 1, top + 22, f['body'])                                         # the upper case
    c.rect(x0 + 5, top + 8, x1 - 5, top + 19, shade(f['body'], 0.86))                            # a panel, with a carved fret
    c.hline(x0 + 5, x1 - 5, top + 8, f['dk'])
    c.vline(x0 + 5, top + 8, top + 19, f['dk'])
    c.hline(x0 + 5, x1 - 5, top + 19, f['lt'])
    for k in range(5):
        c.put(x0 + 9 + k * 6, top + 13, BRASS if f is FIN_C['walnut'] else hexc('6a6a74'))
    c.rect(x0 + 2, top + 23, x1 - 2, top + 25, f['dk'])                                          # the music desk
    c.rect(x0 + 12, top + 17, x0 + 24, top + 24, hexc('ece6d0'))                                 # sheet music on it
    for k in range(4):
        c.hline(x0 + 13, x0 + 23, top + 19 + k, hexc('9a9484'))
    c.put(x0 + 15, top + 20, hexc('1a1a1a')); c.put(x0 + 19, top + 21, hexc('1a1a1a')); c.put(x0 + 22, top + 19, hexc('1a1a1a'))
    c.rect(x0 + 1, top + 26, x1 - 1, top + 28, f['lt'])                                          # the fall
    c.rect(x0 + 2, top + 29, x1 - 2, top + 36, hexc('e8e0cc'))                                   # the keyboard: ivory keys
    c.hline(x0 + 2, x1 - 2, top + 36, hexc('b8b09a'))
    for k in range(x0 + 4, x1 - 3, 3):
        c.vline(k, top + 29, top + 36, hexc('b8b09a'))
    for k in range(x0 + 5, x1 - 4, 3):
        if (k - x0) % 9 not in (2, 8):
            c.rect(k, top + 29, k + 1, top + 33, hexc('1a1a1e'))                                  # the black keys
    c.rect(x0 + 1, top + 37, x1 - 1, top + 38, f['dk'])
    c.rect(x0 + 1, top + 39, x1 - 1, base - 6, f['body'])                                        # the lower panel
    c.rect(x0 + 4, top + 42, x1 - 4, base - 9, shade(f['body'], 0.9))
    c.hline(x0 + 4, x1 - 4, top + 42, f['dk'])
    c.vline(x0 + 4, top + 42, base - 9, f['dk'])
    c.hline(x0 + 4, x1 - 4, base - 9, f['lt'])
    for bx in (x0 + 8, x1 - 9):                                                                   # candle brackets either side of the desk
        c.rect(bx, top + 26, bx + 1, top + 27, BRASS)
    for px in (x0 + 18, x0 + 23, x0 + 28):                                                        # the pedals, brass, under the case
        c.rect(px, base - 4, px + 2, base - 3, BRASS)
        c.hline(px, px + 2, base - 4, BRASS_LT)
    c.rect(x0, base - 5, x1, base - 3, f['dk'])
    for lx in (x0 + 1, x1 - 4):
        c.rect(lx, base - 3, lx + 3, base, f['body'])
        c.vline(lx, base - 3, base, f['lt'])
    for k in range(3):
        c.hline(x0 + 3 + k * 11, x0 + 8 + k * 11, top + 3, shade(f['lt'], 0.8))


# ================================================================================================================================ the china cabinet
@piece('china_cabinet', 34, 76, 'wall', rooms={'living_room': 5, 'dining_room': 8}, styles={'parlour': 8, 'cosy': 1, 'formal': 8, 'family': 3}, tags=('storage', 'display'), depth=6,
       variants={'mahogany': {'fin': 'walnut'}, 'oak': {'fin': 'oak'}},
       anchors=({'name': 'china_cabinet', 'dx': 17, 'dy': -53}, {'name': 'cabinet_cupboard', 'dx': 17, 'dy': -17}), opens={'kind': 'door_h', 'frames': 3, 'anchor': 'cabinet_cupboard'}, feet=(105, 108),
       note='a glazed china cabinet: a pediment, two glass doors over shelves of blue-and-white plates, cups and a tureen, a drawer and a panelled cupboard below on bracket feet')
def china_cabinet(c, ox, oy, p):
    f = FIN_C[p['fin']]
    t = p['open']
    rng = random.Random(7)
    x0, x1 = ox + 1, ox + 32
    top, base = oy - 74, oy
    c.shadow((x0 + x1) // 2, base + 1, 19, 2, 100)
    c.rect(x0 - 1, top + 3, x1 + 1, base - 3, f['out'])
    c.rect(x0 - 2, top, x1 + 2, top + 3, f['lt'])                                                 # the cornice
    c.hline(x0 - 2, x1 + 2, top, shade(f['lt'], 1.25))
    c.hline(x0 - 2, x1 + 2, top + 3, f['dk'])
    c.rect(x0 + 8, top - 2, x1 - 8, top, f['lt'])                                                 # a pediment
    c.hline(x0 + 8, x1 - 8, top - 2, shade(f['lt'], 1.25))
    c.rect(x0, top + 4, x1, top + 44, f['body'])
    gx0, gx1, gy0, gy1 = x0 + 2, x1 - 2, top + 6, top + 42                                       # the glazed front: the dark inside shows plates on shelves
    c.rect(gx0, gy0, gx1, gy1, shade(f['dk'], 0.4))
    for sy in (gy0 + 11, gy0 + 23):
        c.rect(gx0, sy, gx1, sy + 1, f['lt'])
        c.hline(gx0, gx1, sy + 2, shade(f['dk'], 0.6))
    plate = (hexc('dcdcd0'), hexc('3a5a9a'))
    for sy in (gy0 + 11, gy0 + 23, gy1 + 1):                                                      # blue-and-white plates standing on edge along each shelf
        for k in range(5):
            px = gx0 + 2 + k * 5
            for yy in range(sy - 9, sy):
                c.put(px, yy, plate[0]); c.put(px + 1, yy, shade(plate[0], 0.85)); c.put(px + 2, yy, plate[0] if yy % 3 else plate[1])
            c.put(px + 1, sy - 5, plate[1])
    for k in range(3):                                                                            # cups hanging on hooks and a tureen on the middle shelf
        c.rect(gx0 + 2 + k * 5, gy0 + 13, gx0 + 5 + k * 5, gy0 + 15, hexc('e8e4d8'))
    K.sphere(c, (gx0 + gx1) // 2 + 3, gy0 + 20, 5.0, 3.2, hexc('f0ece0'), gloss=True)
    c.vline((x0 + x1) // 2, gy0, gy1, f['dk'])                                                    # the door meeting
    for hx in ((x0 + x1) // 2 - 2, (x0 + x1) // 2 + 2):
        c.put(hx, gy0 + 18, BRASS_LT)
    for k in range(8):                                                                            # the glass: reflection streaks
        c.put(gx0 + 2 + k, gy0 + 2 + k, hexc('dce8f0', 120)) if k < 6 else None
    c.rect(x0 - 1, top + 45, x1 + 1, top + 47, f['lt'])                                           # the ledge
    c.hline(x0 - 1, x1 + 1, top + 45, shade(f['lt'], 1.25))
    c.rect(x0, top + 48, x1, top + 53, f['body'])                                                 # a drawer
    c.hline(x0, x1, top + 48, f['lt'])
    c.hline(x0 + 12, x0 + 19, top + 50, BRASS)
    _slab_door(c, x0 + 1, top + 56, (x0 + x1) // 2 - 1, base - 6, f, 0.0, 'right')               # the cupboard doors below
    _slab_door(c, (x0 + x1) // 2 + 1, top + 56, x1 - 1, base - 6, f, t, 'left')
    c.rect(x0, base - 5, x1, base - 3, f['dk'])
    for lx in (x0 + 1, x1 - 4):
        c.rect(lx, base - 3, lx + 3, base, f['body'])


# ================================================================================================================================ the hearth
@piece('fireplace', 72, 82, 'wall', rooms={'living_room': 8}, styles={'lodge': 10, 'parlour': 2, 'cosy': 1}, tags=('hearth', 'storage'), depth=5,
       variants={'stone': {'kind': 'stone'}, 'brick': {'kind': 'brick'}},
       slots=({'id': 'top', 'dx0': 6, 'dx1': 66, 'dy': -41, 'top': True, 'kinds': ('small', 'lamp')},),
       anchors=({'name': 'fireplace', 'dx': 36, 'dy': -18},), feet=(105, 108),
       note='a hearth: a stone (or brick) surround, a timber mantel, a dark firebox with a grate, logs and a heap of embers, a hearth slab in front; the chimney breast runs up to the ceiling')
def fireplace(c, ox, oy, p):
    stone = p['kind'] == 'stone'
    base_c, lt, dk = (hexc('8a8a84'), hexc('aaaaa2'), hexc('55554f')) if stone else (hexc('9a4a3a'), hexc('b8604a'), hexc('5e2a22'))
    rng = random.Random(3 if stone else 5)
    x0, x1 = ox + 2, ox + 69
    top, base = oy - 80, oy
    c.shadow((x0 + x1) // 2, base + 1, 40, 2, 105)
    c.rect(x0 + 8, top, x1 - 8, base - 40, base_c)                                                # the chimney breast above the mantel
    c.vline(x0 + 8, top, base - 40, lt)
    c.vline(x1 - 8, top, base - 40, dk)
    for ry in range(top + 2, base - 40, 5):                                                       # courses of stone / brick
        c.hline(x0 + 8, x1 - 8, ry, dk)
        off = 0 if ((ry - top) // 5) % 2 == 0 else (6 if stone else 4)
        step = 12 if stone else 9
        for rx in range(x0 + 8 + off, x1 - 8, step):
            c.vline(rx, ry, ry + 4, dk)
    c.rect(x0, base - 41, x1, base - 38, hexc('7a5638'))                                          # the mantel beam
    c.hline(x0, x1, base - 41, hexc('a2784a'))
    c.hline(x0, x1, base - 38, hexc('3e2a1a'))
    for cx in (x0 + 4, x1 - 5):                                                                   # the surround: two piers
        c.rect(cx - 3, base - 37, cx + 4, base - 4, base_c)
        c.vline(cx - 3, base - 37, base - 4, lt)
        c.vline(cx + 4, base - 37, base - 4, dk)
        for ry in range(base - 36, base - 4, 5):
            c.hline(cx - 3, cx + 4, ry, dk)
    fx0, fx1, fy0, fy1 = x0 + 10, x1 - 10, base - 37, base - 5                                    # the firebox
    c.rect(fx0, fy0, fx1, fy1, hexc('17120e'))
    c.hline(fx0, fx1, fy0, hexc('0a0806'))
    c.rect(fx0 + 1, fy0 + 1, fx0 + 3, fy1 - 1, hexc('221a14'))
    for k in range(7):                                                                            # the grate bars and the logs
        c.rect(fx0 + 8 + k * 6, fy1 - 8, fx0 + 8 + k * 6, fy1 - 1, hexc('3a3a3e'))
    c.rect(fx0 + 6, fy1 - 9, fx1 - 6, fy1 - 8, hexc('4a4a50'))
    K.cyl(c, (fx0 + fx1) / 2.0 - 8, fy1 - 12, fy1 - 10, 2.2, hexc('5a3a22'), ry=0.8)
    for lx, ly, lr in ((fx0 + 11, fy1 - 12, 8), (fx0 + 24, fy1 - 14, 9), (fx0 + 37, fy1 - 11, 7)):
        c.rect(lx, ly, lx + lr, ly + 3, hexc('4a2e1c'))
        c.hline(lx, lx + lr, ly, hexc('6a4228'))
        c.put(lx + lr, ly + 1, hexc('2a1810')); c.put(lx + lr, ly + 2, hexc('a8782a'))
    for k in range(10):                                                                           # embers, a few bright
        c.put(fx0 + 6 + rng.randint(0, fx1 - fx0 - 12), fy1 - 2 - rng.randint(0, 3), hexc('c8441c') if k % 3 else hexc('f0a030'))
    c.rect(x0 - 3, base - 3, x1 + 3, base - 1, hexc('6e6a64'))                                    # the hearth slab
    c.hline(x0 - 3, x1 + 3, base - 3, hexc('9a968a'))
    c.hline(x0 - 3, x1 + 3, base - 1, hexc('3e3a34'))
    c.rect(x0 - 2, base, x1 + 2, base, hexc('1c1a16'))
