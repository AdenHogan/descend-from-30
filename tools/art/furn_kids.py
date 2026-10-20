"""THE CHILD'S ROOM THINGS, REDRAWN — a toy chest with its lid up and toys piled in it, a painted toy shelf, a block tower, a ball, a rag doll, a pencilled height chart (owner round 47c: "redo all
still on the list that need upgrading").

Same method as furn_props.py: a few tones per material lit from the upper left (propkit), a selective outline, a contact shadow. The toy chest keeps its true-perspective box (it leans with the
module's vanishing point, bucketed) and gains planks, straps, corner brackets, a lock plate, a stencilled star and the toys heaped inside; the shelf stands on carved brackets with lettered blocks,
a plush bunny and a toy car; the blocks have letters and a roof; the ball is a rubber ball with a curved band; the doll has yarn hair, button eyes and striped stockings; the height chart is a
tape of notches with the marks fading with age.
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
from pixlib import hexc, shade, mix, pp, pbox
from furn_bedroom import _legacy

TOY_R, TOY_Y, TOY_B, TOY_G = hexc('c8483a'), hexc('e0b83a'), hexc('4a78b8'), hexc('5a9a5a')
OUTLINE = hexc('2a1c17')


def _clip_below(lc, y):
    """Make every pixel of a scratch layer on or below row y transparent (the toys in the chest must not paint over its front)."""
    for yy in range(y, lc.h):
        for xx in range(lc.w):
            lc.px[xx, yy] = (0, 0, 0, 0)


def _star(c, cx, cy, col, hi=None):
    """A little five-point star, 7 px wide."""
    rows = ((3, 3), (3, 3), (0, 6), (1, 5), (1, 5), (1, 2), (0, 1))
    for k, (a, b) in enumerate(rows):
        for x in range(a, b + 1):
            c.put(cx - 3 + x, cy - 3 + k, col)
    c.put(cx, cy - 3, hi or shade(col, 1.3))


# ================================================================================================================================ the toy chest
# ================================================================================================================================ the toy shelf
@piece('toy_shelf', 28, 22, 'decor', rooms={'bedroom': 5, 'living_room': 2}, styles={'kid': 8}, tags=('toy', 'shelf'), wall_y=(36, 50), limit=1,
       note='a painted shelf on carved brackets: three lettered blocks, a plush bunny and a toy car')
def toy_shelf(c, ox, oy, p):
    paint, paint_lt, paint_dk = hexc('d8c46a'), hexc('ecdc8e'), hexc('a8943c')
    y = oy + 15
    # the board, a thick front edge lit on top, a shadow thrown on the wall beneath it
    c.rect(ox + 1, y + 1, ox + 26, y + 3, paint_dk)
    c.rect(ox, y, ox + 27, y + 1, paint)
    c.hline(ox, ox + 27, y, paint_lt)
    c.hline(ox, ox + 27, y + 2, shade(paint_dk, 0.85))
    c.hline(ox + 1, ox + 26, y + 4, hexc('7a6a30'))
    for bx in (ox + 3, ox + 23):                                                            # little angle brackets, a scroll at the foot
        c.rect(bx, y + 4, bx + 2, y + 5, paint)
        c.put(bx + 1, y + 6, paint); c.put(bx, y + 6, paint_lt)
        c.put(bx + 2, y + 4, paint_dk); c.put(bx + 2, y + 5, paint_dk)
    L = K.Layer(c)
    lc = L.c
    # three alphabet blocks
    for i, (col, ch) in enumerate(((TOY_B, 'A'), (TOY_R, 'B'), (TOY_G, 'C'))):
        bx = ox + (2 if i != 1 else 9)
        by = y - 1 if i < 2 else y - 8
        K.slab(lc, bx, by - 6, bx + 5, by, col, d=2, inset=0)
        F.text3(lc, bx + 1, by - 5, ch, hexc('f4ecd8'))
    # a plush bunny sitting: body, head, long ears, a tail
    gx = ox + 19
    K.sphere(lc, gx, y - 3.4, 3.4, 3.2, hexc('d8d0c8'), gloss=True)
    K.sphere(lc, gx + 0.4, y - 8.4, 2.4, 2.2, hexc('e2dad2'), gloss=True)
    K.sphere(lc, gx - 1.2, y - 12.0, 0.9, 2.2, hexc('e2dad2'))
    K.sphere(lc, gx + 1.8, y - 12.0, 0.9, 2.2, hexc('e2dad2'))
    lc.put(int(gx - 1), int(y - 12), hexc('d89a9a')); lc.put(int(gx + 2), int(y - 12), hexc('d89a9a'))
    lc.put(int(gx - 0), int(y - 9), hexc('1a1410')); lc.put(int(gx + 2), int(y - 9), hexc('1a1410'))
    K.sphere(lc, gx - 3.4, y - 2.0, 1.3, 1.3, hexc('f0eae0'))
    L.flush()
    # a little red toy car at the right end
    cc = ox + 24
    c.rect(cc, y - 3, cc + 3, y - 2, TOY_R)
    c.rect(cc + 1, y - 5, cc + 2, y - 4, TOY_R)
    c.put(cc + 1, y - 4, hexc('b8d8e8')); c.put(cc + 2, y - 4, hexc('b8d8e8'))
    c.put(cc, y - 1, hexc('1a1410')); c.put(cc + 3, y - 1, hexc('1a1410'))


# ================================================================================================================================ the block tower
# ================================================================================================================================ the ball
@piece('ball', 10, 10, 'floor', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8, 'teen': 1}, tags=('toy',), near=('toy',), feet=(106, 119), variants={'red': {}}, limit=1,
       note='a rubber ball: red with a curved white band, a lit side and a highlight')
def ball(c, ox, oy, p):
    K.contact_shadow(c, ox + 5, oy + 0.5, 5.2, 1.3, 90)
    L = K.Layer(c)
    lc = L.c
    cx, cy, r = ox + 5.0, oy - 4.5, 4.5
    tn = K.tones(TOY_R, 5, 0.5, 1.3)
    wh = K.tones(hexc('f4f0e4'), 5, 0.78, 1.12)
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            u, v = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
            r2 = u * u + v * v
            if r2 > 1.0:
                continue
            nz = math.sqrt(1.0 - r2)
            lam = max(0.0, K.LX * u + K.LY * v + K.LZ * nz)
            band = abs(v - 0.28 * u * 0 - 0.05 + 0.32 * (u * u)) < 0.2                      # a band that curves with the ball
            tab = wh if band else tn
            lc.put(x, y, K._pick(tab, 0.12 + 0.95 * lam))
    lc.put(int(cx - 2), int(cy - 3), hexc('ffffff'))
    L.flush()


# ================================================================================================================================ the rag doll
# ================================================================================================================================ the height chart
@piece('height_chart', 18, 30, 'decor', rooms={'bedroom': 4, 'living_room': 2, 'kitchen': 2}, styles={'kid': 8}, tags=('mark',), wall_y=(54, 66), limit=1,
       note='a growth chart: a thin tape of notches, pencilled marks with the age beside each, older marks faded, her name on a tab at the top')
def height_chart(c, ox, oy, p):
    rng = random.Random(7)
    tape, tape_dk = hexc('d9ceb0'), hexc('a89c7c')
    c.rect(ox + 1, oy + 4, ox + 3, oy + 29, tape)                                           # a paper measuring tape pinned up the wall
    c.vline(ox + 1, oy + 4, oy + 29, shade(tape, 1.12))
    c.vline(ox + 3, oy + 4, oy + 29, tape_dk)
    for k in range(0, 26, 3):
        c.hline(ox + 1 if k % 9 else ox, ox + 3 if k % 9 else ox + 3, oy + 29 - k, hexc('6b5f44'))
    c.put(ox + 2, oy + 4, hexc('b04a3a'))                                                   # a red pin at the top
    c.put(ox + 2, oy + 29, hexc('b04a3a'))
    tab = (ox + 5, oy, ox + 17, oy + 4)                                                      # a name tab
    c.rect(*tab, hexc('e8dcc0'))
    c.hline(tab[0], tab[2], tab[1], hexc('f6ecd2'))
    c.hline(tab[0], tab[2], tab[3], tape_dk)
    F.text3(c, ox + 6, oy + 0, 'MIA', hexc('7a3a3a'))
    for i, (y, age) in enumerate(((27, '3'), (21, '4'), (15, '5'), (9, '6'))):
        fade = 1.0 - 0.15 * (3 - i) * 0.9                                                    # the oldest marks are the faintest
        col = mix(hexc('c4b9a0'), hexc('3a3a40'), fade)
        w = 8 + (i % 2)
        wob = rng.choice((0, 0, 1))
        c.hline(ox + 4, ox + 4 + w - 3, oy + y, col)
        c.hline(ox + 4 + w - 2, ox + 4 + w, oy + y - wob, col)
        F.text3(c, ox + 4 + w + 1, oy + y - 2, age, mix(hexc('c4b9a0'), hexc('45454c'), fade * 0.9))
    c.put(ox + 15, oy + 9, hexc('c0504a')); c.put(ox + 16, oy + 8, hexc('c0504a')); c.put(ox + 17, oy + 9, hexc('c0504a'))  # a crayon heart beside the newest mark
