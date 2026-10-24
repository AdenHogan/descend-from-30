"""THE KITCHEN'S SMALL THINGS — what stands on a worktop, lies on the kitchen floor, hangs on its walls and from its ceiling (owner round 47e).

Same method as furn_props.py: a few tones per material lit from the upper left (propkit), a selective outline, a contact shadow. Worktop things declare `on=('worktop',)` (or `appliance`) and stand on
the slots the units give them; wall cupboards hang `above` the run; the notes and calendars are the flatmates' / survivors' paper (wallart.py).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import propkit as K
import wallart as W
from furnlib import piece
from pixlib import hexc, shade, mix
from furn_kitchen import FIN, _fin, _door_slab, _handle, INTERIOR, STEEL, STEEL_DK, STEEL_LT

OUTLINE = hexc('2a1c17')


def _shadow(c, cx, cy, rx, ry=1.4, a=90):
    K.contact_shadow(c, cx, cy, rx, ry, a)


# ================================================================================================================================ on the worktop
@piece('kettle', 13, 13, 'top', rooms={'kitchen': 7}, styles=None, tags=('small', 'cooking'), on=('worktop',), anchors=(),
       variants={'steel': {'col': 'b4bcc0', 'for': ['classic', 'student', 'retro']}, 'red': {'col': 'b8362e', 'for': ['retro', 'classic', 'country']},
                 'cream': {'col': 'e0d8bc', 'for': ['hoarder', 'country', 'classic']}}, note='a kettle with a spout and a bakelite handle')
def kettle(c, ox, oy, p):
    col = hexc(p['col'])
    _shadow(c, ox + 6, oy + 0.5, 6.0)
    L = K.Layer(c)
    lc = L.c
    K.frustum(lc, ox + 6.0, oy - 11, oy - 1, 3.6, 5.2, col, ry_t=1.2, ry_b=1.4, rim=shade(col, 1.25), gloss=True)
    K.sphere(lc, ox + 6.0, oy - 12.5, 1.3, 1.1, hexc('2a2622'))                                       # the lid knob
    lc.line(ox + 10, oy - 6, ox + 12, oy - 9, shade(col, 0.8)); lc.put(ox + 12, oy - 9, shade(col, 0.6))   # the spout
    lc.vline(ox + 1, oy - 9, oy - 4, hexc('2a2622')); lc.hline(ox + 1, ox + 3, oy - 10, hexc('2a2622'))    # the handle
    L.flush()


@piece('toaster', 12, 10, 'top', rooms={'kitchen': 5}, styles=None, tags=('small', 'cooking'), on=('worktop',),
       variants={'chrome': {'col': 'b4bcc0', 'for': ['retro', 'classic', 'student']}, 'cream': {'col': 'dcd5bf', 'for': ['hoarder', 'classic']}},
       note='a two-slot toaster with the toast up')
def toaster(c, ox, oy, p):
    col = hexc(p['col'])
    _shadow(c, ox + 6, oy + 0.5, 6.4)
    L = K.Layer(c)
    lc = L.c
    K.slab(lc, ox + 1, oy - 7, ox + 10, oy - 1, col, d=2, inset=1)
    lc.hline(ox + 2, ox + 9, oy - 5, shade(col, 0.7))
    lc.put(ox + 2, oy - 3, hexc('2a2622')); lc.put(ox + 9, oy - 3, hexc('b8362e'))
    for tx in (ox + 3, ox + 7):                                                                       # toast standing in the slots
        lc.rect(tx, oy - 10, tx + 2, oy - 8, hexc('d8a868'))
        lc.hline(tx, tx + 2, oy - 10, hexc('f0d098'))
    L.flush()


@piece('bread_bin', 14, 11, 'top', rooms={'kitchen': 4}, styles=None, tags=('small', 'food'), on=('worktop',),
       variants={'cream': {'col': 'e0d8bc', 'for': ['classic', 'hoarder', 'country']}, 'red': {'col': 'b8362e', 'for': ['retro', 'student']}},
       note='an enamel bread bin with a roll-front lid and BREAD on it')
def bread_bin(c, ox, oy, p):
    col = hexc(p['col'])
    _shadow(c, ox + 7, oy + 0.5, 7.0)
    L = K.Layer(c)
    lc = L.c
    K.slab(lc, ox + 1, oy - 8, ox + 12, oy - 1, col, d=2, inset=1)
    lc.rect(ox + 1, oy - 10, ox + 12, oy - 9, shade(col, 0.85)); lc.hline(ox + 1, ox + 12, oy - 10, shade(col, 1.3))
    F.text3(lc, ox + 2, oy - 7, 'BR', hexc('3a3a3a') if p['col'] != 'b8362e' else hexc('f4ecd8'))
    L.flush()


@piece('mugs', 18, 13, 'top', rooms={'kitchen': 7}, styles=None, tags=('small', 'food'), on=('worktop',),
       variants={'a': {'cols': ('e6e0cc', '3f6a8a')}, 'b': {'cols': ('b8362e', 'e8d45a')}, 'c': {'cols': ('4a7a5a', 'e6e0cc')}},
       note='two mugs, one nearer than the other, and a jar of spoons')
def mugs(c, ox, oy, p):
    """Two mugs (a glazed body shaded across its width, a dark inside seen through an elliptical rim, a handle with thickness) at DIFFERENT depths, and a spoon jar behind them
    (owner round 48i: the three coloured things "feel flat")."""
    _shadow(c, ox + 8, oy + 0.5, 8.6)
    L = K.Layer(c)
    lc = L.c
    jar = hexc('a8c8c0')
    K.cyl(lc, ox + 14.0, oy - 11, oy - 3, 2.9, jar, ry=1.1, cap=True, inner=hexc('3a2a20'), gloss=False, n=4, lo=0.66, hi=1.2)
    lc.vline(ox + 12, oy - 9, oy - 6, shade(jar, 1.5))
    lc.hline(ox + 12, ox + 16, oy - 5, shade(jar, 0.72))                                          # a label band round the jar
    for k in range(4):                                                                            # spoon handles standing in it
        lc.line(ox + 12 + k, oy - 10, ox + 11 + k + (k % 2) * 2, oy - 14, hexc('b08a52') if k % 2 else hexc('c8ccd0'))
    for i, (hx, mx, dy) in enumerate(zip(p['cols'], (ox + 3.4, ox + 9.6), (0, -1))):              # the second mug stands a row further back
        col = hexc(hx)
        top = oy - 8 + dy
        K.cyl(lc, mx, top, oy - 1 + dy, 2.7, col, ry=1.1, cap=True, inner=hexc('3a2a20'), gloss=False, n=4, lo=0.62, hi=1.22)
        lc.vline(int(mx) - 1, top + 2, top + 4, shade(col, 1.5))                                  # a short highlight, not a stripe the whole height
        for hy in (top + 2, top + 5):                                                             # the handle: a C with thickness, shaded
            lc.put(int(mx) + 3, hy, shade(col, 0.8)); lc.put(int(mx) + 4, hy, shade(col, 0.55))
        lc.put(int(mx) + 4, top + 3, shade(col, 0.7)); lc.put(int(mx) + 4, top + 4, shade(col, 0.6))
    L.flush()


@piece('fruit_bowl', 14, 11, 'top', rooms={'kitchen': 5, 'dining_room': 3}, styles=None, tags=('small', 'food'), on=('worktop',),
       variants={'fresh': {'rot': False, 'for': ['classic', 'retro', 'country']}, 'rotten': {'rot': True, 'for': ['student', 'hoarder', 'classic']}}, note='a wooden bowl of fruit — or of what is left of it')
def fruit_bowl(c, ox, oy, p):
    _shadow(c, ox + 7, oy + 0.5, 7.2)
    L = K.Layer(c)
    lc = L.c
    cols = (hexc('8a9a5a'), hexc('6a5a3a'), hexc('7a6a4a')) if p['rot'] else (hexc('d8803a'), hexc('b0302a'), hexc('d8c848'))
    for k, (fx, fy) in enumerate(((ox + 4.5, oy - 6.2), (ox + 9.0, oy - 6.4), (ox + 6.8, oy - 8.6))):
        K.sphere(lc, fx, fy, 2.5, 2.4, cols[k % 3], gloss=not p['rot'])
    if p['rot']:
        lc.put(ox + 8, oy - 8, hexc('c8d8a8')); lc.put(ox + 5, oy - 7, hexc('c8d8a8'))               # mould
    K.frustum(lc, ox + 7.0, oy - 5, oy - 1, 6.2, 4.2, hexc('a8845a'), ry_t=1.4, ry_b=1.0, rim=hexc('c9a478'))
    L.flush()


@piece('canisters', 15, 11, 'top', rooms={'kitchen': 4}, styles=None, tags=('small', 'food'), on=('worktop',),
       variants={'a': {'cols': ('c8483a', 'e0d8bc', '3f6aa8'), 'for': ['classic', 'retro', 'country']}, 'b': {'cols': ('b4bcc0', 'b4bcc0', 'b4bcc0'), 'for': ['student', 'hoarder']}},
       note='three storage tins labelled TEA, SUGAR and COFFEE')
def canisters(c, ox, oy, p):
    _shadow(c, ox + 7.5, oy + 0.5, 7.8)
    L = K.Layer(c)
    lc = L.c
    for i, (hx, tag, h) in enumerate(zip(p['cols'], ('T', 'S', 'C'), (9, 8, 10))):
        cx = ox + 2.6 + i * 5.2
        K.cyl(lc, cx, oy - h, oy - 2, 2.4, hexc(hx), ry=1.0, cap=True, gloss=True)
        F.text3(lc, int(cx) - 1, oy - h + 3, tag, hexc('f4ecd8') if p['cols'][0] != 'b4bcc0' else hexc('3a3a3a'))
    L.flush()


@piece('microwave', 22, 14, 'top', rooms={'kitchen': 5}, styles={'student': 8, 'hoarder': 3, 'classic': 2, 'retro': 2}, tags=('small', 'cooking'), on=('appliance',),
       anchors=({'name': 'microwave', 'dx': 11, 'dy': -6},), variants={'black': {'col': '24262a', 'for': ['student', 'hoarder']}, 'white': {'col': 'e0e0da', 'for': ['classic', 'retro', 'hoarder']}},
       note='a microwave oven: a glass door with a dark window, a display and a handle')
def microwave(c, ox, oy, p):
    col = hexc(p['col'])
    _shadow(c, ox + 11, oy + 0.5, 11.4)
    L = K.Layer(c)
    lc = L.c
    K.slab(lc, ox + 1, oy - 12, ox + 20, oy - 1, col, d=2, inset=1)
    lc.rect(ox + 3, oy - 10, ox + 14, oy - 3, hexc('0e1214'))
    lc.hline(ox + 3, ox + 14, oy - 10, hexc('2a3236'))
    lc.rect(ox + 5, oy - 8, ox + 7, oy - 7, hexc('2a3a3e'))
    lc.rect(ox + 16, oy - 10, ox + 19, oy - 8, hexc('0a1a10')); lc.put(ox + 17, oy - 9, hexc('4ad868'))     # the display
    lc.vline(ox + 15, oy - 10, oy - 3, shade(col, 0.6))
    for ky in (oy - 6, oy - 4):
        lc.hline(ox + 16, ox + 19, ky, shade(col, 0.7))
    L.flush()


@piece('teapot', 11, 11, 'top', rooms={'kitchen': 4, 'dining_room': 4}, styles=None, tags=('small', 'food'), on=('worktop',),
       variants={'brown': {'col': '8a5a3a', 'for': ['classic', 'country', 'family']}, 'blue': {'col': '4f6f8a', 'for': ['classic', 'country', 'formal']}}, note='a glazed teapot in a knitted cosy')
def teapot(c, ox, oy, p):
    col = hexc(p['col'])
    _shadow(c, ox + 5.5, oy + 0.5, 5.6)
    L = K.Layer(c)
    lc = L.c
    K.sphere(lc, ox + 5.0, oy - 5.0, 4.4, 3.8, col, gloss=True)
    K.sphere(lc, ox + 5.0, oy - 9.0, 1.4, 1.0, shade(col, 1.2))
    lc.line(ox + 9, oy - 6, ox + 11, oy - 8, shade(col, 0.8))
    lc.vline(ox, oy - 7, oy - 3, shade(col, 0.7)); lc.put(ox + 1, oy - 7, shade(col, 0.7))
    lc.hline(ox + 2, ox + 7, oy - 3, hexc('c8483a'))                                                  # the cosy's band
    L.flush()


@piece('tin_stack', 14, 12, 'top', rooms={'kitchen': 5}, styles={'hoarder': 8, 'student': 4, 'classic': 1}, tags=('small', 'food'), on=('worktop',), anchors=(),
       variants={'a': {'n': 3}, 'b': {'n': 5}}, note='a pyramid of tinned food, labels turned out')
def tin_stack(c, ox, oy, p):
    _shadow(c, ox + 7, oy + 0.5, 7.2)
    L = K.Layer(c)
    lc = L.c
    labels = (hexc('c8483a'), hexc('e0b83a'), hexc('4a7a4a'), hexc('3f6aa8'), hexc('b86a3a'))
    rows = [(0, 3 if p['n'] == 3 else 4), (1, 2 if p['n'] == 3 else 3), (2, 1 if p['n'] == 3 else 1)]
    k = 0
    for r, cnt in rows:
        for i in range(cnt):
            cx = ox + 7 + (i - (cnt - 1) / 2.0) * 4.6
            cy = oy - 1.2 - r * 4.0
            K.cyl(lc, cx, cy - 3, cy, 2.1, labels[k % 5], ry=0.9, cap=True, cap_col=hexc('c4cacc'), gloss=False)
            k += 1
    L.flush()


@piece('chopping_board', 14, 12, 'top', rooms={'kitchen': 4}, styles=None, tags=('small', 'cooking'), on=('worktop',),
       variants={'a': {'for': ['classic', 'retro', 'country', 'student']}}, note='a chopping board leaning on the wall with an onion and a knife')
def chopping_board(c, ox, oy, p):
    _shadow(c, ox + 7, oy + 0.5, 7.0)
    L = K.Layer(c)
    lc = L.c
    lc.poly([(ox + 2, oy - 1), (ox + 8, oy - 1), (ox + 9, oy - 11), (ox + 3, oy - 11)], hexc('c8a068'))
    lc.line(ox + 3, oy - 11, ox + 2, oy - 1, hexc('e0bc84')); lc.line(ox + 9, oy - 11, ox + 8, oy - 1, hexc('8a6238'))
    lc.rect(ox + 5, oy - 10, ox + 6, oy - 9, hexc('3a3a38'))
    K.sphere(lc, ox + 11.0, oy - 2.8, 2.4, 2.4, hexc('d8a860'), gloss=True)
    lc.line(ox + 9, oy - 1, ox + 13, oy - 1, hexc('c4cacc')); lc.hline(ox + 12, ox + 13, oy, hexc('3a3a38'))
    L.flush()


@piece('utensil_jar', 8, 14, 'top', rooms={'kitchen': 5}, styles=None, tags=('small', 'cooking'), on=('worktop',),
       variants={'a': {'for': ['classic', 'retro', 'country', 'student']}}, note='a jar of wooden spoons and a whisk')
def utensil_jar(c, ox, oy, p):
    _shadow(c, ox + 4, oy + 0.5, 4.2)
    L = K.Layer(c)
    lc = L.c
    for k, (dx, dy, col) in enumerate(((1, 12, hexc('b08a52')), (3, 13, hexc('c9a478')), (5, 11, hexc('8a6238')), (6, 12, hexc('c4cacc')))):
        lc.line(ox + 3 + (k % 2), oy - 4, ox + dx, oy - dy, col)
        K.sphere(lc, ox + dx, oy - dy, 1.0, 1.4, col)
    K.cyl(lc, ox + 4.0, oy - 7, oy - 2, 2.9, hexc('7a9a8a'), ry=1.1, cap=True, inner=hexc('1a2a22'), gloss=True)
    L.flush()


# ================================================================================================================================ the floor
@piece('bin_bags', 30, 24, 'floor', rooms={'kitchen': 7, 'living_room': 1}, styles={'classic': 4, 'student': 8, 'hoarder': 6, 'retro': 2}, tags=('clutter', 'rubbish'), feet=(106, 113),
       anchors=({'name': 'trashcan', 'dx': 12, 'dy': -10},), variants={'two': {'split': False}, 'split': {'split': True}}, near=('unit',),
       note='two tied black bin bags against the end of the counter; or one split open with rubbish on the floor')
def bin_bags(c, ox, oy, p):
    import furn_small3d
    furn_small3d.bin_bags(c, ox, oy, p)


@piece('box_cardboard', 26, 18, 'floor', rooms={'kitchen': 6, 'living_room': 2, 'study': 2}, styles=None, tags=('clutter',), feet=(106, 114),
       anchors=({'name': 'box', 'dx': 13, 'dy': -8},), near=('unit',),
       variants={'tins': {'k': 'tins', 'for': ['classic', 'hoarder', 'student']}, 'bottles': {'k': 'bottles', 'for': ['country', 'retro', 'classic']}, 'flat': {'k': 'flat', 'for': ['student', 'hoarder']}},
       note='a cardboard box on the floor: open on tins, on bottles, or flattened')
def box_cardboard(c, ox, oy, p):
    _shadow(c, ox + 13, oy + 0.6, 13.0, 1.6, 105)
    L = K.Layer(c)
    lc = L.c
    box, box_dk, box_lt = hexc('a88a5c'), hexc('7d6440'), hexc('c4a878')
    if p['k'] == 'flat':
        K.slab(lc, ox + 1, oy - 3, ox + 24, oy - 1, box, d=3, inset=2)
        K.slab(lc, ox + 3, oy - 7, ox + 22, oy - 5, shade(box, 1.05), d=3, inset=2)
        lc.hline(ox + 8, ox + 18, oy - 8, hexc('c8483a'))
    else:
        K.slab(lc, ox + 1, oy - 11, ox + 24, oy - 1, box, d=3, inset=1)
        lc.hline(ox + 1, ox + 24, oy - 11, box_lt)
        lc.rect(ox + 10, oy - 6, ox + 15, oy - 5, hexc('d8d2c2'))                                    # a packing label
        lc.vline(ox + 12, oy - 11, oy - 8, box_dk)
        if p['k'] == 'tins':
            for k, tc in enumerate((hexc('c8483a'), hexc('e0b83a'), hexc('4a7a4a'), hexc('3f6aa8'), hexc('c8483a'))):
                K.cyl(lc, ox + 4.0 + k * 4.2, oy - 16, oy - 12, 1.9, tc, ry=0.8, cap=True, cap_col=hexc('c4cacc'))
        else:
            for k, bc in enumerate((hexc('6a8a52'), hexc('b88a3a'), hexc('6a8a52'), hexc('4a6a8a'))):
                K.cyl(lc, ox + 5.0 + k * 5.0, oy - 17, oy - 12, 1.8, bc, ry=0.8, cap=True, gloss=True)
                lc.rect(ox + 4 + k * 5, oy - 19, ox + 5 + k * 5, oy - 17, bc)
    L.flush()


@piece('pizza_boxes', 24, 9, 'floor', rooms={'kitchen': 5, 'living_room': 3}, styles={'student': 8, 'hoarder': 2}, tags=('clutter', 'food'), feet=(106, 116), anchors=({'name': 'pizza_boxes', 'dx': 12, 'dy': -4},),
       near=('unit',), variants={'a': {}}, note='three flat pizza boxes, grease through the lids, one askew')
def pizza_boxes(c, ox, oy, p):
    _shadow(c, ox + 12, oy + 0.6, 12.4, 1.4, 100)
    L = K.Layer(c)
    lc = L.c
    for k, dx in enumerate((0, 1, -1)):
        K.slab(lc, ox + 2 + dx, oy - 3 - k * 3, ox + 21 + dx, oy - 1 - k * 3, hexc('c8a878') if k % 2 else hexc('b8986a'), d=3, inset=2)
    lc.rect(ox + 8, oy - 12, ox + 14, oy - 11, hexc('a8483a'))
    lc.put(ox + 11, oy - 12, hexc('e8d8a8'))
    L.flush()


@piece('newspaper_stacks', 38, 50, 'wall', rooms={'kitchen': 6, 'living_room': 1, 'study': 1}, styles={'hoarder': 9}, tags=('clutter', 'paper'), depth=3, feet=(105, 108), limit=1,
       anchors=({'name': 'newspapers', 'dx': 18, 'dy': -24},), variants={'a': {'for': ['hoarder']}},
       note='tied bundles of old newspapers stacked against the wall, stepped, the string cutting into the edges')
def newspaper_stacks(c, ox, oy, p):
    rng = random.Random(12)
    c.shadow(ox + 19, oy + 1, 20, 2, 100)
    paper, paper_dk = hexc('d8d0b8'), hexc('a89c82')
    for (bx, bw, bh) in ((0, 13, 46), (12, 11, 38), (22, 12, 30)):
        L = K.Layer(c)
        lc = L.c
        x0, x1, top = ox + bx, ox + bx + bw - 1, oy - bh
        for y in range(top, oy + 1):
            for x in range(x0, x1 + 1):
                lc.put(x, y, shade(mix(paper, hexc('c8bca0'), ((y * 7 + x * 3) % 5) / 6.0), 1.06 - 0.22 * ((x - x0) / float(bw))))
            if (y - top) % 3 == 0:
                lc.hline(x0, x1, y, paper_dk)
        for sy in range(top + 6, oy, 14):                                                            # the twine round each bundle
            lc.hline(x0, x1, sy, hexc('8a6a3a'))
        lc.hline(x0, x1, top, hexc('f0e8d0'))
        L.flush()


@piece('cat_tins', 20, 8, 'floor', rooms={'kitchen': 5}, styles={'hoarder': 9}, tags=('clutter', 'food'), feet=(106, 118), anchors=({'name': 'cat_tins', 'dx': 10, 'dy': -3},), near=('unit',),
       variants={'a': {}}, note='a saucer, two opened cat-food tins licked clean and one rolled away')
def cat_tins(c, ox, oy, p):
    _shadow(c, ox + 10, oy + 0.5, 10.0, 1.2, 90)
    L = K.Layer(c)
    lc = L.c
    K.cyl(lc, ox + 3.5, oy - 4, oy - 1, 2.6, hexc('e0b83a'), ry=1.0, cap=True, cap_col=hexc('c4cacc'))
    K.cyl(lc, ox + 8.5, oy - 4, oy - 1, 2.6, hexc('c8483a'), ry=1.0, cap=True, cap_col=hexc('c4cacc'))
    lc.ellipse(ox + 15, oy - 1.5, 4, 1.4, hexc('ece6d4')); lc.ellipse(ox + 15, oy - 1.8, 3, 0.8, hexc('d8c8a8'))
    lc.rect(ox + 0, oy - 1, ox + 2, oy, hexc('3f6aa8'))
    L.flush()


@piece('pedal_bin', 14, 22, 'floor', rooms={'kitchen': 6}, styles=None, tags=('clutter', 'rubbish'), feet=(106, 114), anchors=({'name': 'trashcan', 'dx': 7, 'dy': -12},), near=('unit',),
       variants={'steel': {'col': 'b4bcc0', 'for': ['classic', 'retro', 'student']}, 'green': {'col': '6a8a62', 'for': ['country', 'hoarder', 'classic']}}, note='a pedal bin with a swing lid')
def pedal_bin(c, ox, oy, p):
    col = hexc(p['col'])
    _shadow(c, ox + 7, oy + 0.6, 7.4, 1.4, 100)
    L = K.Layer(c)
    lc = L.c
    K.cyl(lc, ox + 7.0, oy - 17, oy - 2, 5.6, col, ry=1.6, cap=True, cap_col=shade(col, 1.18), gloss=True)
    lc.rect(ox + 6, oy - 20, ox + 8, oy - 19, shade(col, 0.6))
    lc.rect(ox + 5, oy - 1, ox + 9, oy, hexc('3a3a3e'))                                               # the pedal
    L.flush()


@piece('bucket_mop', 14, 30, 'floor', rooms={'kitchen': 5, 'bathroom': 5}, styles=None, tags=('clutter', 'wet'), feet=(106, 116), anchors=({'name': 'bucket', 'dx': 7, 'dy': -6},), near=('unit',),
       variants={'blue': {'col': '3f6aa8'}, 'yellow': {'col': 'e0b83a'}}, note='a mop in a bucket, the head wrung out grey')
def bucket_mop(c, ox, oy, p):
    col = hexc(p['col'])
    _shadow(c, ox + 7, oy + 0.6, 7.2, 1.4, 95)
    L = K.Layer(c)
    lc = L.c
    lc.line(ox + 8, oy - 26, ox + 6, oy - 11, hexc('b08a52')); lc.line(ox + 9, oy - 26, ox + 7, oy - 11, hexc('8a6238'))
    K.frustum(lc, ox + 7.0, oy - 12, oy - 1, 5.6, 4.4, col, ry_t=1.6, ry_b=1.2, inner=hexc('3a4a5a'), rim=shade(col, 1.25), gloss=True)
    for k in range(5):                                                                                # the mop head's strands hanging over the rim
        lc.vline(ox + 4 + k, oy - 11, oy - 8 + (k % 2), hexc('c8c4b4'))
    L.flush()


@piece('crate_veg', 22, 18, 'floor', rooms={'kitchen': 6}, styles={'country': 9, 'hoarder': 2}, tags=('clutter', 'food'), feet=(106, 114), anchors=({'name': 'crate', 'dx': 11, 'dy': -8},), near=('unit',),
       variants={'a': {}}, note='a slatted wooden crate of potatoes, onions and a cabbage, a sack of flour beside it')
def crate_veg(c, ox, oy, p):
    _shadow(c, ox + 11, oy + 0.6, 11.4, 1.5, 100)
    L = K.Layer(c)
    lc = L.c
    K.slab(lc, ox + 1, oy - 9, ox + 13, oy - 1, hexc('b8895a'), d=2, inset=1)
    for yy in (oy - 7, oy - 4):
        lc.hline(ox + 1, ox + 13, yy, hexc('7a5630'))
    for k, (vx, vy, vc) in enumerate(((3.5, 11.5, hexc('b89868')), (7.0, 12.0, hexc('c8883a')), (10.0, 11.0, hexc('a89858')))):
        K.sphere(lc, ox + vx, oy - vy, 2.4, 2.1, vc, gloss=False)
    K.sphere(lc, ox + 7.5, oy - 14.5, 2.8, 2.4, hexc('7aa84a'), gloss=True)
    K.sphere(lc, ox + 18.0, oy - 5.0, 3.6, 4.4, hexc('e0d8c0'), gloss=False)                       # the flour sack
    lc.rect(ox + 16, oy - 9, ox + 20, oy - 8, hexc('c8c0a8')); lc.hline(ox + 16, ox + 20, oy - 5, hexc('3f6aa8'))
    L.flush()


@piece('trolley_kitchen', 28, 30, 'front', rooms={'kitchen': 5}, styles={'student': 4, 'hoarder': 3, 'classic': 2}, tags=('clutter', 'storage'), feet=(112, 118), anchors=({'name': 'trolley', 'dx': 14, 'dy': -18},),
       variants={'a': {}}, near=('unit',), note='a steel utility trolley on castors with dishes, a pan and a box of cereal on its two shelves')
def trolley_kitchen(c, ox, oy, p):
    _shadow(c, ox + 14, oy + 0.6, 14.0, 1.6, 100)
    L = K.Layer(c)
    lc = L.c
    ch, chd = hexc('b4bcc0'), hexc('737a7c')
    for lx in (ox + 2, ox + 25):
        lc.vline(lx, oy - 26, oy - 2, ch); lc.vline(lx + 1, oy - 26, oy - 2, chd)
        lc.rect(lx - 1, oy - 1, lx + 2, oy, hexc('2a2a2e'))
    for sy in (oy - 26, oy - 13):
        lc.rect(ox, sy, ox + 27, sy + 2, ch); lc.hline(ox, ox + 27, sy, hexc('e0e6e8')); lc.hline(ox, ox + 27, sy + 2, chd)
    K.cyl(lc, ox + 8.0, oy - 33, oy - 27, 4.4, hexc('3a3a3e'), ry=1.4, cap=True, inner=hexc('5a5650'), gloss=True)
    for k in range(4):
        K.cyl(lc, ox + 18.0, oy - 31 + (3 - k) * 0, oy - 27 - k * 1.4, 3.6 - k * 0.2, hexc('ece6d4') if k % 2 else hexc('d4ccb8'), ry=1.0, cap=True)
    K.slab(lc, ox + 4, oy - 22, ox + 12, oy - 14, hexc('e0b83a'), d=2, inset=1)
    lc.rect(ox + 16, oy - 18, ox + 24, oy - 14, hexc('e8e2d0')); lc.hline(ox + 16, ox + 24, oy - 18, hexc('ffffff'))
    L.flush()


# ================================================================================================================================ on the walls
def _cupboard_variants():
    return {'sage_3': {'fin': 'sage', 'n': 3, 'for': ['classic']}, 'yellow_2': {'fin': 'yellow', 'n': 2, 'for': ['retro']}, 'cream_2': {'fin': 'cream', 'n': 2, 'for': ['hoarder']},
            'white_2': {'fin': 'white', 'n': 2, 'for': ['student']}, 'pine_2': {'fin': 'pine', 'n': 2, 'for': ['country']}}


@piece('wall_cupboards', 46, 36, 'decor', rooms={'kitchen': 7}, styles=None, tags=('storage', 'unit_above'), variants=_cupboard_variants(), wall_y=(12, 16), limit=1,
       above=('unit',), note='wall cupboards over the run: three grey-green doors with the left one hanging open (classic), two yellow doors (retro), two cream, two white with one door missing (student), two pine (country)')
def wall_cupboards(c, ox, oy, p):
    fin = _fin(p['fin'])
    n = p['n']
    w = 46 if n == 3 else 38
    x0, x1, top, bot = ox, ox + w - 1, oy, oy + 33
    c.rect(x0, top, x1, bot, fin['out'])
    c.rect(x0 + 1, top + 1, x1 - 1, bot - 1, fin['dk'])
    c.hline(x0 + 1, x1 - 1, top + 1, fin['lt'])
    c.hline(x0, x1, bot + 1, hexc('3a2a22')); c.hline(x0 + 1, x1 - 1, bot + 2, (0, 0, 0, 60))
    dw = (w - 2) // n
    for i in range(n):
        a = x0 + 1 + i * dw
        b = a + dw - 1
        broken = (p['fin'] == 'white' and i == n - 1) or (p['fin'] == 'sage' and i == 0)
        if broken:
            c.rect(a, top + 2, b, bot - 2, INTERIOR)
            c.hline(a, b, top + 16, shade(INTERIOR, 1.6))
            c.rect(a + 3, top + 8, a + 7, top + 15, hexc('b7a36e'))
            c.rect(a + 10, top + 10, a + 13, top + 15, hexc('8a9aa0'))
            c.rect(a + 3, top + 20, a + 10, top + 29, hexc('c05a3a'))
            c.poly([(a, top + 2), (a - 3, top + 4), (a - 3, bot - 3), (a, bot - 2)], shade(fin['door'], 0.85))
        else:
            _door_slab(c, a, top + 2, b, bot - 2, fin)
            _handle(c, b - 3 if i % 2 == 0 else a + 2, bot - 13, fin, True, p['fin'] == 'pine')


@piece('shelf_jars', 40, 22, 'decor', rooms={'kitchen': 6}, styles={'country': 8, 'hoarder': 6, 'classic': 1}, tags=('shelf', 'food'), wall_y=(16, 30), limit=1, above=('unit',),
       variants={'a': {'for': ['country', 'hoarder', 'classic']}}, note='a plank shelf on brackets with jars, tins and a bag of flour')
def shelf_jars(c, ox, oy, p):
    rng = random.Random(4)
    y = oy + 18
    c.rect(ox, y, ox + 39, y + 2, hexc('8a6a4a')); c.hline(ox, ox + 39, y, hexc('b08a62')); c.hline(ox, ox + 39, y + 2, hexc('4a3220'))
    for bx in (ox + 4, ox + 34):
        c.vline(bx, y + 3, y + 7, hexc('3a3f48')); c.line(bx, y + 7, bx + 3, y + 3, hexc('3a3f48'))
    L = K.Layer(c)
    lc = L.c
    x = ox + 2
    cols = [hexc('c8883a'), hexc('6a8a52'), hexc('b0453a'), hexc('d8d0b8'), hexc('4f6f8a')]
    while x < ox + 36:
        w = rng.choice((5, 6, 7))
        h = rng.randint(9, 15)
        c0 = rng.choice(cols)
        K.cyl(lc, x + w / 2.0, y - h, y - 1, w / 2.0, shade(c0, 1.0), ry=1.0, cap=True, cap_col=hexc('c4cacc'), gloss=True)
        lc.rect(x + 1, y - h + 4, x + w - 2, y - h + 7, hexc('ece6d4'))
        x += w + 1
    L.flush()


@piece('tea_towel', 11, 22, 'decor', rooms={'kitchen': 6}, styles=None, tags=('cloth',), wall_y=(24, 36), variants={'red': {'col': 'b8594a', 'for': ['classic', 'country', 'retro']},
       'blue': {'col': '4a6a98', 'for': ['student', 'hoarder', 'country']}}, note='a checked tea towel folded over a hook')
def tea_towel(c, ox, oy, p):
    import wall_art3d
    wall_art3d.tea_towel(c, ox, oy, p)


@piece('note_milk_eggs', 26, 13, 'decor', rooms={'kitchen': 5}, styles={'student': 9, 'hoarder': 1}, tags=('notice',), wall_y=(20, 36), limit=1, variants={'a': {}}, note='two sticky notes: MILK and EGGS')
def note_milk_eggs(c, ox, oy, p):
    F.sticky(c, ox, oy, 'MILK')
    F.sticky(c, ox + 18, oy + 4, 'EGGS', col=hexc('e88aa0'))


@piece('note_rent', 18, 24, 'decor', rooms={'kitchen': 5}, styles={'student': 9}, tags=('notice',), wall_y=(18, 32), limit=1, variants={'a': {}}, note='RENT DUE FRI! taped to the wall')
def note_rent(c, ox, oy, p):
    F.note(c, ox, oy, ['RENT', 'DUE', 'FRI!'], fix='tape')


@piece('note_cat_food', 18, 24, 'decor', rooms={'kitchen': 5}, styles={'hoarder': 9}, tags=('notice',), wall_y=(14, 32), limit=1, variants={'a': {}}, note='a note for whoever feeds the cat: CAT FOOD, TUES')
def note_cat_food(c, ox, oy, p):
    F.note(c, ox, oy, ['CAT', 'FOOD', 'TUES'], fix='tape')


@piece('note_bills', 20, 22, 'decor', rooms={'kitchen': 5}, styles={'hoarder': 9}, tags=('notice',), wall_y=(14, 32), limit=1, variants={'a': {}}, note='a reminder stuck up where it cannot be missed: PAY GAS BILL')
def note_bills(c, ox, oy, p):
    F.note(c, ox, oy, ['PAY', 'GAS', 'BILL'], paper=hexc('e4dcc4'))


# ================================================================================================================================ the ceiling
@piece('light_tube', 36, 6, 'ceiling', rooms={'kitchen': 6, 'study': 3, 'bathroom': 2}, styles={'classic': 8, 'student': 3, 'office': 6}, tags=('light', 'ceiling'), lights=({'dx': 18, 'dy': 4, 'kind': 'tube'},),
       variants={'a': {'for': ['classic', 'student', 'office', 'wetroom']}}, note='a fluorescent batten on the ceiling')
def light_tube(c, ox, oy, p):
    import furn_small3d
    furn_small3d.light_tube(c, ox, oy, p)


@piece('light_dome_orange', 14, 22, 'ceiling', rooms={'kitchen': 5, 'dining_room': 2}, styles={'retro': 9, 'diner': 6}, tags=('light', 'ceiling'), lights=({'dx': 7, 'dy': 20, 'kind': 'pendant'},),
       variants={'orange': {'col': 'd8703a', 'for': ['retro', 'diner']}}, note='a 60s orange enamel dome pendant on a flex')
def light_dome_orange(c, ox, oy, p):
    col = hexc(p['col'])
    cx = ox + 7
    for y in range(0, 15):
        c.put(cx, y, hexc('2a2622') if y % 2 else hexc('4a4640'))
    L = K.Layer(c)
    K.sphere(L.c, cx, 17.5, 6.8, 4.4, col, gloss=True)
    L.c.rect(cx - 7, 18, cx + 7, 19, shade(col, 0.7))
    L.flush()
    c.hline(cx - 6, cx + 6, 20, shade(col, 0.5))
    K.sphere(c, cx, 21.0, 1.6, 1.2, hexc('fff0c0'), n=4, lo=0.9, hi=1.2)


@piece('light_bulb', 8, 22, 'ceiling', rooms={'kitchen': 6, 'living_room': 2, 'study': 2, 'bedroom': 1}, styles={'student': 9, 'hoarder': 9, 'country': 2, 'squat': 6, 'radio': 4}, tags=('light', 'ceiling'),
       lights=({'dx': 4, 'dy': 20, 'kind': 'bulb'},), variants={'a': {'for': ['student', 'hoarder', 'country', 'squat', 'radio']}}, note='a bare bulb on a frayed flex')
def light_bulb(c, ox, oy, p):
    import furn_small3d
    furn_small3d.light_bulb(c, ox, oy, p)