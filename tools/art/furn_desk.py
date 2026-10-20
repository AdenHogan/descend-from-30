"""THE TEEN'S DESK, REDRAWN (owner round 47c: "redo all still on the list that need upgrading").

The old desk was two flat boxes under a slab. Now: a pine top with a lit edge and a dark underside that throws a shadow into the kneehole, a shallow pencil drawer, a dark modesty panel between two
pedestals, each pedestal two raised-panel drawers with round brass knobs, a plinth, a sticker and a scratched doodle on the front, pine grain. The CRT on it is still placed by `_desk_post`.
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
from furn_wardrobes import _raised, BRASS, BRASS_LT, BRASS_DK


def _desk_post(c, ox, oy, p, shift):
    F.crt_on_top(c, shift, ox + 21, 72 + (oy - 99))


def _knob(c, x, y):
    c.rect(x, y, x + 1, y + 1, BRASS)
    c.put(x, y, BRASS_LT)
    c.put(x + 1, y + 1, BRASS_DK)


@piece('desk_crt', 43, 28, 'wall', rooms={'bedroom': 8, 'study': 4}, styles={'teen': 8, 'adult': 1, 'refuge': 0}, tags=('work', 'storage'), depth=8,
       variants={'pine': {}}, anchors=({'name': 'desk', 'dx': 22, 'dy': -21}, {'name': 'desk_drawer', 'dx': 8, 'dy': -11}), feet=(105, 108),
       needs={'tag': 'seat', 'dx': [38, 52], 'chance': 1.0}, post=_desk_post,
       note='a pine desk: a lit top edge, a dark kneehole with a pencil drawer, a pedestal of two raised-panel drawers at each end with brass knobs, a plinth, a sticker and a scratched doodle (it wants its chair)')
def desk_crt(c, ox, oy, p):
    mid, lt, dk, out = F.PINE
    x0, x1 = ox, ox + 42
    top, base = oy - 27, oy
    rng = random.Random(8)
    c.shadow((x0 + x1) // 2, base + 1, 23, 2, 100)
    # the kneehole first: a dark back panel, the shadow of the top across it, a shallow pencil drawer
    kx0, kx1 = x0 + 13, x1 - 13
    c.rect(kx0, top + 3, kx1, base - 1, shade(dk, 0.5))
    for xx in range(kx0 + 2, kx1, 4):
        c.vline(xx, top + 6, base - 2, shade(dk, 0.42))
    c.hline(kx0, kx1, top + 3, shade(dk, 0.3))
    c.hline(kx0, kx1, top + 4, shade(dk, 0.38))
    c.rect(kx0 + 1, top + 3, kx1 - 1, top + 7, mid)
    c.rect(kx0 + 1, top + 3, kx1 - 1, top + 3, lt)
    c.hline(kx0 + 1, kx1 - 1, top + 7, dk)
    c.vline(kx0 + 1, top + 3, top + 7, lt); c.vline(kx1 - 1, top + 3, top + 7, dk)
    _knob(c, (kx0 + kx1) // 2 - 1, top + 5)
    # the two pedestals: outline, a lit left edge and a shaded right edge, two raised-panel drawers each, a plinth
    for (p0, p1) in ((x0 + 2, x0 + 12), (x1 - 12, x1 - 2)):
        c.rect(p0 - 1, top + 3, p1 + 1, base, out)
        c.rect(p0, top + 3, p1, base - 1, shade(mid, 0.94))
        c.vline(p0, top + 3, base - 1, lt)
        c.vline(p1, top + 3, base - 1, dk)
        for (d0, d1) in ((top + 5, top + 13), (top + 15, top + 23)):
            _raised(c, p0 + 2, d0, p1 - 2, d1, mid, lt, dk, out)
            _knob(c, (p0 + p1) // 2, (d0 + d1) // 2)
            for _ in range(3):                                                                    # pine grain: short horizontal flecks
                gx = rng.randint(p0 + 3, p1 - 5)
                c.hline(gx, gx + rng.randint(2, 4), rng.randint(d0 + 2, d1 - 2), shade(mid, 0.9))
        c.rect(p0, base - 3, p1, base - 1, shade(dk, 0.8))
        c.hline(p0, p1, base - 3, shade(dk, 1.1))
    # the top: a thick slab with a lit front edge, an overhang and a dark underside
    c.rect(x0 - 1, top, x1 + 1, top + 2, mid)
    c.hline(x0 - 1, x1 + 1, top, shade(lt, 1.15))
    c.hline(x0 - 1, x1 + 1, top + 1, lt)
    c.hline(x0 - 1, x1 + 1, top + 2, dk)
    c.put(x0 - 1, top, out); c.put(x1 + 1, top, out)
    for xx in range(x0 + 1, x1, 7):
        c.put(xx + rng.randint(0, 3), top + 1, shade(lt, 0.9))
    # a sticker on the left pedestal's top drawer, a scratched initial on the right one
    sx, sy = x0 + 5, top + 7
    c.rect(sx, sy, sx + 2, sy + 2, hexc('e0b83a'))
    c.put(sx + 1, sy + 1, hexc('2a1c17')); c.put(sx, sy, hexc('f4dc78'))
    for (dx, dy) in ((0, 0), (0, 1), (0, 2), (1, 1), (2, 0), (2, 1), (2, 2)):
        c.put(x1 - 8 + dx, top + 8 + dy, shade(mid, 0.7))
