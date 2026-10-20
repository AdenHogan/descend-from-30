"""THE LIVING ROOM — sofas, tables, sideboard + TV, shelves, the piano, the china cabinet, the hearth (owner round 47f: "expand to other module types too… a big pass to fix the items").

A living room is no longer one of five baked pictures: it is a SHELL (the bare room) plus PIECES laid by the planner from a seed, in five STYLES — cosy (the flat with the gold sofa and the red
armchair), mid (the teak and teal sixties front room, the TV on a sideboard), squat (the grey concrete room with the wall TV and the pallet table), parlour (the rose-papered front parlour
with the piano) and lodge (the green-panelled hunting lodge with the hearth). The living room that holds the GUN CABINET is not planned: it stays the baked module (living_room_e), which
`room.furniture_plan_for` keeps for the one flat a floor that may hold a cabinet.

The sofa and the armchairs are little 3D models turned into pixel art (tools/art/chair3d.py), so they have real volume; the cupboards and tables are drawn front-on and brought forward + leaned
by the kit (pixlib.setback) like the bedroom's. Everything small that stands ON a table is a separate piece (furn_living_small.py and the shared tops).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chair3d as C3
import furn as F
import furnlib as FL
import propkit as K
from furnlib import piece
from pixlib import hexc, shade, mix

OUT = hexc('2a1c17')


# ================================================================================================================================ sofas (3D)
FABS = {   # name: (colour, pattern)
    'gold': ('b8963a', 'plain'), 'rust': ('9a4a2f', 'plain'), 'olive': ('6f7a4a', 'plain'),
    'orange': ('c8602e', 'plain'), 'mustard': ('c09a30', 'plain'), 'avocado': ('7a8a3e', 'plain'),
    'grey': ('70747a', 'worn'), 'denim': ('4a5a7a', 'worn'),
    'floral': ('dcd2b4', 'floral'), 'velvet': ('3e5a4a', 'plain'), 'burgundy': ('7a2e3a', 'plain'),
    'oxblood': ('6e2a2a', 'plain'), 'tan': ('8a5a34', 'plain'), 'tartan': ('4a6a4a', 'plaid'),
}
SOFA_FOR = {
    'gold': ['cosy'], 'rust': ['cosy'], 'olive': ['cosy', 'mid'],
    'orange': ['mid'], 'mustard': ['mid'], 'avocado': ['mid'],
    'grey': ['squat'], 'denim': ['squat'],
    'floral': ['parlour'], 'velvet': ['parlour'], 'burgundy': ['parlour'],
    'oxblood': ['lodge'], 'tan': ['lodge'], 'tartan': ['lodge'],
}


def _sofa_variants():
    return {k: {'fab': k, 'for': SOFA_FOR[k]} for k in FABS}


def _pattern(c, cx, base_y, cbuf, pbuf, kind, col):
    """Upholstery pattern laid over the shaded model, keeping each pixel's own light."""
    rose = hexc('b8707a')
    mid = sum(col[:3]) / 3.0 or 1.0
    for (x, y), px in cbuf.items():
        part = pbuf[(x, y)]
        if not part.startswith(('cushion', 'backcush', 'back', 'base')):
            continue
        f = (sum(px[:3]) / 3.0) / mid
        if kind == 'floral':
            gx, gy = (x + (7 if (y // 8) % 2 else 0)) % 14, y % 8
            cxp, cyp = 6, 3
            d = abs(gx - cxp) + abs(gy - cyp)
            if d == 0:
                c.put(cx + x, base_y + y, tuple(min(255, int(v * f * 1.0)) for v in (236, 206, 196)) + (255,))
            elif d == 1:
                c.put(cx + x, base_y + y, tuple(min(255, int(v * f)) for v in rose[:3]) + (255,))
            elif gx == cxp + 3 and gy == cyp + 3 or gx == cxp - 3 and gy == cyp - 3:
                c.put(cx + x, base_y + y, tuple(min(255, int(v * f)) for v in (110, 128, 96)) + (255,))
        elif kind == 'plaid':
            if x % 7 == 0 or y % 6 == 0:
                c.put(cx + x, base_y + y, shade(px, 0.78))
            elif x % 7 == 3 and y % 2 == 0:
                c.put(cx + x, base_y + y, mix(px, hexc('b8a050'), 0.35))
        elif kind == 'worn':
            if (x * 3 + y * 7) % 41 == 0:
                c.put(cx + x, base_y + y, shade(px, 0.78))


def _draw_sofa(c, ox, oy, p, width, seats, w):
    col, kind = FABS[p['fab']]
    base = hexc(col)
    pal = {'fab': base, 'fab_lt': shade(base, 1.14), 'wood': hexc('3a2618')}
    cx, by = ox + w // 2, oy - 3
    m = C3.sofa_model(width=float(width), seats=seats)
    r = C3.draw_model(c, cx, by, m, 0, pal, srad=int(width / 2) - 3)
    if r is None:
        return
    cbuf, pbuf, _sbuf = r
    if kind != 'plain':
        _pattern(c, cx, by, cbuf, pbuf, kind, base)
    if p['fab'] in ('grey', 'denim'):                                          # the squat's sofa has been slept on and slashed: a pale tear across the back cushion
        xs = [x for (x, y) in cbuf if pbuf[(x, y)].startswith('backcush')]
        if xs:
            tx = min(xs) + (max(xs) - min(xs)) * 2 // 3
            ty = min(y for (x, y) in cbuf if pbuf[(x, y)].startswith('backcush')) + 4
            for k in range(5):
                c.put(cx + tx + k, by + ty + k // 2, hexc('d8d0bc'))
            c.put(cx + tx + 2, by + ty + 3, hexc('3a3228'))


@piece('sofa', 82, 44, 'front', rooms={'living_room': 10}, styles=None, tags=('seating_lounge', 'sofa'), variants=_sofa_variants(), limit=1, feet=(108, 112),
       anchors=({'name': 'sofa_left', 'dx': 24, 'dy': -14}, {'name': 'sofa_right', 'dx': 58, 'dy': -14}), needs={'tag': 'table', 'dx': [16, 16], 'chance': 0.9, 'optional': True},
       note='a three-seat sofa built as a 3D model (arms, back, three seat + back cushions, turned feet): gold / rust / olive, orange / mustard / avocado, a slashed grey or denim one, floral / green velvet / burgundy, oxblood / tan leather or a tartan')
def sofa(c, ox, oy, p):
    _draw_sofa(c, ox, oy, p, 76, 3, 82)


@piece('loveseat', 62, 44, 'front', rooms={'living_room': 4}, styles=None, tags=('seating_lounge', 'sofa'), variants=_sofa_variants(), limit=1, feet=(108, 112),
       anchors=({'name': 'loveseat', 'dx': 31, 'dy': -14},), needs={'tag': 'table', 'dx': [6, 6], 'chance': 0.9, 'optional': True},
       note='a two-seat settee of the same make, for the flat that has no room for the big one')
def loveseat(c, ox, oy, p):
    _draw_sofa(c, ox, oy, p, 54, 2, 62)


# ================================================================================================================================ coffee tables
def _leg(c, x, y0, y1, col):
    c.vline(x, y0, y1, col)
    c.vline(x + 1, y0, y1, shade(col, 0.7))


def _table_top(c, x0, x1, ytop, th, top, topdk, d=4, inset=2, out=None):
    """A table top seen a little from above: a lit top face `d` rows deep that narrows toward the back, a front edge `th` rows thick."""
    out = out or shade(topdk, 0.5)
    for k in range(d):
        i = int(round(inset * (d - k) / float(d)))
        c.hline(x0 + i, x1 - i, ytop - d + k, shade(top, 1.10 - 0.04 * (d - k)))
    c.hline(x0 + inset, x1 - inset, ytop - d - 1, out)
    c.rect(x0, ytop, x1, ytop + th - 1, topdk)
    c.hline(x0, x1, ytop, shade(top, 1.15))
    c.hline(x0, x1, ytop + th, out)
    c.vline(x0 - 1, ytop, ytop + th, out)
    c.vline(x1 + 1, ytop, ytop + th, out)


@piece('coffee_table', 50, 24, 'floor', rooms={'living_room': 8}, styles={'cosy': 8, 'mid': 8, 'squat': 8, 'parlour': 8, 'lodge': 6}, tags=('table',), limit=1, feet=(114, 118), companion_only=True, lap=22,
       variants={'wood': {'kind': 'wood', 'for': ['cosy']}, 'kidney': {'kind': 'kidney', 'for': ['mid']}, 'pallet': {'kind': 'pallet', 'for': ['squat']},
                 'tea': {'kind': 'tea', 'for': ['parlour']}, 'trunk': {'kind': 'trunk', 'for': ['lodge']}},
       slots=({'id': 'top', 'dx0': 6, 'dx1': 43, 'dy': -17, 'top': True, 'kinds': ('small', 'low')},),
       anchors=({'name': 'coffee_table', 'dx': 24, 'dy': -14, 'top': True},),
       note='the low table in front of the sofa: a walnut one with a lower shelf of magazines (cosy), a teak kidney table on splayed brass legs (mid), a pallet on cinder blocks (squat), a round mahogany tea table (parlour), a strapped travelling trunk (lodge)')
def coffee_table(c, ox, oy, p):
    k = p['kind']
    ground = oy - 3
    c.shadow(ox + 25, ground + 1, 26, 2, 110)
    if k == 'wood':
        wood, wl, wd = hexc('7a5238'), hexc('9a6e48'), hexc('52352a')
        _leg(c, ox + 4, oy - 15, ground, wd)
        _leg(c, ox + 43, oy - 15, ground, wd)
        _leg(c, ox + 9, oy - 15, ground - 1, shade(wd, 0.8))
        _leg(c, ox + 38, oy - 15, ground - 1, shade(wd, 0.8))
        c.rect(ox + 6, ground - 6, ox + 43, ground - 5, shade(wd, 0.85))             # the lower shelf
        c.hline(ox + 6, ox + 43, ground - 6, shade(wl, 0.9))
        for i, col in enumerate(('a0584a', '5a7a8a', 'c8b070', '7a6a8a')):           # a magazine rack's worth of spines on the shelf
            c.rect(ox + 10 + i * 8, ground - 9, ox + 16 + i * 8, ground - 7, hexc(col))
        _table_top(c, ox + 1, ox + 48, oy - 16, 3, wl, wood, d=4, inset=3)
    elif k == 'kidney':
        teak, tl, td = hexc('9a6234'), hexc('c08a52'), hexc('5e3a1e')
        for lx, ld in ((ox + 7, -2), (ox + 43, 2), (ox + 17, 1), (ox + 33, -1)):     # splayed brass-capped legs
            c.line(lx, oy - 12, lx + ld * 2, ground, td)
            c.put(lx + ld * 2, ground, hexc('c8a050'))
        for dx in range(-24, 25):                                                      # the kidney top: a bowed back edge, a front edge with the dent in the middle
            u = dx / 24.0
            yb = oy - 22 + int(round(2.2 * u * u))
            yf = oy - 15 - int(round(3.0 * (1.0 - abs(u) ** 1.4)))
            x = ox + 25 + dx
            for y in range(yb, yf + 1):
                f = (y - yb) / float(max(1, yf - yb))
                c.put(x, y, shade(tl, 1.16 - 0.14 * f - 0.05 * max(0.0, u)))
            c.put(x, yb - 1, shade(td, 0.7))
            for t in range(1, 4):                                                        # the thickness of the slab follows the front edge
                c.put(x, yf + t, shade(teak, 0.9 - 0.12 * t))
            c.put(x, yf + 4, shade(td, 0.55))
        c.put(ox + 4, oy - 17, shade(tl, 1.3)); c.put(ox + 5, oy - 18, shade(tl, 1.3))
    elif k == 'pallet':
        wood, wl, wd = hexc('b49a68'), hexc('d0b882'), hexc('7a6240')
        for bx in (ox + 3, ox + 40):                                                   # two cinder blocks
            K.slab(c, bx, oy - 9, bx + 6, ground, hexc('8a8a86'), d=2, top=hexc('a8a8a2'))
            c.put(bx + 2, oy - 6, hexc('55554f')); c.put(bx + 5, oy - 6, hexc('55554f'))
        c.rect(ox + 1, oy - 15, ox + 48, oy - 11, wood)
        for yy in (oy - 15, oy - 13, oy - 11):
            c.hline(ox + 1, ox + 48, yy, wd)
        for x in range(ox + 3, ox + 48, 9):
            c.vline(x, oy - 15, oy - 11, wd)
        c.rect(ox + 1, oy - 19, ox + 48, oy - 16, shade(wl, 0.96))
        for x in range(ox + 1, ox + 48, 11):
            c.vline(x, oy - 19, oy - 16, shade(wl, 0.78))
        c.hline(ox + 1, ox + 48, oy - 20, shade(wd, 0.6))
        c.hline(ox + 1, ox + 48, oy - 19, hexc('e4cf9a'))
    elif k == 'tea':
        mah, ml, md = hexc('6a3a2a'), hexc('8e5640'), hexc('3e2018')
        cx = ox + 25
        K.cyl(c, cx, oy - 14, ground - 1, 2.2, md, ry=1.0)                              # the pedestal
        K.ell(c, cx, ground, 8, 1.8, md)                                                 # a tripod foot, three scrolls
        for sx in (-9, 9):
            c.line(cx, ground - 2, cx + sx, ground, md)
        K.cyl(c, cx, oy - 17, oy - 13, 15.0, mah, ry=3.5, cap_col=ml, lo=0.6, hi=1.25)   # the round top
        K.ell(c, cx, oy - 17.4, 12.5, 2.4, shade(ml, 1.06))
    else:                                                                               # trunk: a strapped travelling trunk used as a table
        lea, ld, ll = hexc('7a4a28'), hexc('4e2e18'), hexc('9a6438')
        K.slab(c, ox + 3, oy - 14, ox + 46, ground, lea, d=4, top=ll, inset=2)
        for sx in (ox + 12, ox + 37):
            c.rect(sx, oy - 14, sx + 2, ground, hexc('3a2a1c'))                         # the straps
            c.rect(sx - 1, oy - 18, sx + 3, oy - 15, hexc('3a2a1c'))
            c.put(sx + 1, oy - 7, hexc('c8a050'))
        c.rect(ox + 22, oy - 10, ox + 28, oy - 7, hexc('c8a050'))                       # the brass lock plate
        c.hline(ox + 22, ox + 28, oy - 10, hexc('f0d27a'))
        c.put(ox + 25, oy - 8, ld)
        for cxp in (ox + 3, ox + 46):                                                    # corner brackets
            c.rect(cxp, ground - 3, cxp + 1, ground, hexc('b09040'))


# ================================================================================================================================ the pouf
@piece('pouf', 24, 18, 'floor', rooms={'living_room': 4}, styles={'squat': 8, 'mid': 2}, tags=('seat',), limit=1,
       variants={'red': {'col': 'a23a34', 'for': ['squat', 'mid']}, 'teal': {'col': '3f7a78', 'for': ['squat', 'mid']}, 'mustard': {'col': 'c09a30', 'for': ['squat', 'mid']}},
       anchors=({'name': 'pouf', 'dx': 11, 'dy': -8},), feet=(112, 122),
       note='a round leather pouf: a seam round the middle, a button and a worn patch where somebody sits')
def pouf(c, ox, oy, p):
    col = hexc(p['col'])
    cx = ox + 11.5
    c.shadow(cx, oy - 1, 13, 2, 110)
    L = K.Layer(c)
    lc = L.c
    K.cyl(lc, cx, oy - 12, oy - 4, 10.5, col, ry=3.0, cap_col=shade(col, 1.12), n=5)
    K.ell(lc, cx, oy - 12.3, 8.2, 2.2, shade(col, 1.2))
    lc.hline(int(cx - 9), int(cx + 8), oy - 8, shade(col, 0.6))                          # the seam
    lc.put(int(cx), oy - 12, shade(col, 0.5))                                             # the button
    L.flush()
