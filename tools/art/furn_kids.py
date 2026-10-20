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
def _toy_chest(c, cx):
    blue, blue_lt, blue_dk, blue_out = hexc('6f98c4'), hexc('9ac0e0'), hexc('3f6288'), hexc('2c4560')
    iron, yellow = hexc('3a3f48'), hexc('e0b83a')
    d0, d1 = 8, 16
    wx0 = 160 + (cx - 14 - 160) * 100.0 / (100 + d1)
    wx1 = 160 + (cx + 14 - 160) * 100.0 / (100 + d1)
    c.shadow(cx, 117, 17, 2, 110)
    # the lid, thrown back against the wall: we see its painted inside, with a stencilled star and a stripe
    lb, lr_ = pp(wx0 + 1, 90, d0), pp(wx1 - 1, 90, d0)
    lt = round(lb[1]) - 12
    lid = [(round(lb[0]), lt), (round(lr_[0]), lt), (round(lr_[0]), round(lr_[1])), (round(lb[0]), round(lb[1]))]
    c.poly(lid, shade(blue, 1.18))
    c.rect(lid[0][0] + 2, lid[0][1] + 2, lid[1][0] - 2, lid[3][1] - 2, shade(blue, 1.3))
    c.hline(lid[0][0] + 2, lid[1][0] - 2, lid[0][1] + 2, hexc('c4dcee'))
    c.hline(lid[0][0] + 2, lid[1][0] - 2, lid[0][1] + 9, shade(blue, 1.08))               # a painted stripe near the hinge
    _star(c, (lid[0][0] + lid[1][0]) // 2, lt + 6, yellow, hexc('f6dc78'))
    for (a, b) in ((lid[0], lid[1]), (lid[0], lid[3]), (lid[1], lid[2])):
        c.line(a[0], a[1], b[0], b[1], blue_out)
    for sx in (lid[0][0] + 1, lid[1][0] - 1):                                              # the iron hinges at the back
        c.rect(sx - 1, lid[3][1] - 3, sx + 1, lid[3][1], iron)
    # the box: planked front, an interior in shadow
    f = pbox(c, wx0, 90, wx1, 100, d0, d1, blue, hexc('1a2432'), shade(blue, 0.7), blue_out)
    fl, fr, fbl, fbr, bl, br = f['fl'], f['fr'], f['fbl'], f['fbr'], f['bl'], f['br']
    x0, x1, y0, y1 = fl[0], fr[0], fl[1], fbl[1]
    for xx in range(x0 + 1, x1):                                                           # vertical planks: lit left edge, shaded right edge of each
        k = (xx - x0) % 6
        if k == 0:
            c.vline(xx, y0 + 1, y1 - 1, shade(blue, 0.8))
        elif k == 1:
            c.vline(xx, y0 + 1, y1 - 1, blue_lt)
        elif k == 5:
            c.vline(xx, y0 + 1, y1 - 1, shade(blue, 0.93))
    c.hline(x0 + 1, x1 - 1, y0 + 1, blue_lt)                                               # the rim, lit
    c.hline(x0 + 1, x1 - 1, y0 + 2, shade(blue, 0.78))
    c.rect(x0 + 1, y1 - 2, x1 - 1, y1 - 1, blue_dk)                                        # a base band
    c.hline(x0 + 1, x1 - 1, y1 - 2, shade(blue_dk, 1.25))
    for (bx0, bx1) in ((x0 + 1, x0 + 4), (x1 - 4, x1 - 1)):                                # iron corner brackets with rivets
        c.rect(bx0, y0 + 1, bx1, y0 + 4, iron)
        c.rect(bx0, y1 - 5, bx1, y1 - 1, iron)
        c.put(bx0 + 1, y0 + 2, hexc('8a9098')); c.put(bx0 + 1, y1 - 3, hexc('8a9098'))
        c.hline(bx0, bx1, y0 + 1, hexc('5a6068'))
    mx = (x0 + x1) // 2                                                                     # the lock plate and the painted star
    c.rect(mx - 2, y0 + 3, mx + 2, y0 + 7, hexc('c9a24e'))
    c.hline(mx - 2, mx + 2, y0 + 3, hexc('e8cc78'))
    c.put(mx, y0 + 5, OUTLINE); c.put(mx, y0 + 6, OUTLINE)
    c.put(x0 + 8, y0 + 7, yellow); c.put(x1 - 8, y0 + 7, yellow)
    # toys heaped inside, clipped at the front rim so none paint over the box
    L = K.Layer(c)
    lc = L.c
    wid = x1 - x0
    base = y0 - 1
    bear = hexc('a8703a')
    K.sphere(lc, x0 + 8, base - 3.2, 3.6, 3.4, bear, gloss=True)                            # a teddy's head
    K.sphere(lc, x0 + 4.8, base - 6.4, 1.5, 1.5, shade(bear, 0.9))
    K.sphere(lc, x0 + 11.4, base - 6.4, 1.5, 1.5, shade(bear, 0.9))
    K.sphere(lc, x0 + 8.4, base - 1.8, 1.8, 1.3, hexc('d8b078'))                            # the snout
    lc.put(x0 + 8, base - 2, hexc('2a1c17')); lc.put(x0 + 6, base - 4, hexc('1a1410')); lc.put(x0 + 10, base - 4, hexc('1a1410'))
    K.slab(lc, x0 + 14, base - 6, x0 + 19, base - 1, TOY_Y, d=2, inset=0)                  # a yellow block behind
    K.sphere(lc, x1 - 9, base - 4.2, 3.2, 3.2, TOY_R, gloss=True)                           # the red ball
    lc.hline(x1 - 12, x1 - 7, base - 4, hexc('f0ead8'))
    for k in range(5):                                                                      # a doll's striped stocking sticking up, a small red shoe turned to one side
        lc.rect(x1 - 5, base - 8 + k, x1 - 4, base - 8 + k, hexc('f0ead8') if k % 2 else TOY_R)
    lc.rect(x1 - 5, base - 10, x1 - 2, base - 9, hexc('8a2e2a'))
    lc.hline(x1 - 5, x1 - 2, base - 10, hexc('c8584a'))
    _clip_below(lc, y0)
    L.flush()


@piece('toy_chest', 36, 30, 'floor', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8, 'teen': 1}, tags=('toy', 'storage'), variants={'blue': {}}, bucketed=True,
       anchors=({'name': 'toy_chest', 'dx': 18, 'dy': -10},), near=('sleeping',), feet=(116, 119),
       note='a blue toy chest in true perspective, lid thrown back with a stencilled star, planked, iron-cornered, a teddy, a ball, a block and a doll\'s leg heaped inside')
def toy_chest(c, ox, oy, p):
    _legacy(c, lambda l: _toy_chest(l, ox + 18), 0, oy - 117)


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
def _block(c, x0, y1, w, col, ch, tilt=0):
    K.slab(c, x0, y1 - w + 1, x0 + w - 1, y1, col, d=3, inset=1)
    F.text3(c, x0 + (w - 3) // 2, y1 - w + 2 + (w - 5) // 2 - 1, ch, hexc('f4ecd8'))


@piece('block_tower', 16, 24, 'floor', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8}, tags=('toy',), near=('toy',), feet=(106, 112), variants={'a': {}},
       note='lettered blocks stacked against the wall, a green roof block on top, one knocked off beside it')
def block_tower(c, ox, oy, p):
    K.contact_shadow(c, ox + 8, oy + 0.5, 9.5, 1.5, 95)
    L = K.Layer(c)
    lc = L.c
    _block(lc, ox, oy, 8, TOY_B, 'A')
    _block(lc, ox + 8, oy, 8, TOY_R, 'B')
    _block(lc, ox + 4, oy - 8, 8, TOY_Y, 'C')
    # the roof: a triangular prism, lit on its left slope, standing on the top face of the middle block
    rb, cx = oy - 19, ox + 8
    for k, half in enumerate((4, 4, 3, 2, 2, 1, 0)):
        lc.hline(cx - half, cx + half - (1 if half else 0), rb - k, shade(TOY_G, 0.92))
        lc.put(cx - half, rb - k, shade(TOY_G, 1.32))
        if half:
            lc.put(cx + half - 1, rb - k, shade(TOY_G, 0.62))
    L.flush()


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
@piece('rag_doll', 10, 16, 'floor', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8}, tags=('toy',), variants={'a': {}}, near=('sleeping',), feet=(112, 119),
       note='a rag doll slumped against the foot of the bed: yarn hair, button eyes, a blue dress with an apron, striped stockings')
def rag_doll(c, ox, oy, p):
    K.contact_shadow(c, ox + 5, oy + 0.5, 6.0, 1.3, 90)
    L = K.Layer(c)
    lc = L.c
    skin, hair, dress = hexc('f0d4b8'), hexc('c8742c'), hexc('5a82c0')
    for lx in (ox + 2, ox + 6):                                                            # legs: striped stockings, black boots
        for k in range(5):
            lc.rect(lx, oy - 5 + k, lx + 1, oy - 5 + k, hexc('f0ead8') if k % 2 else TOY_R)
        lc.rect(lx, oy - 1, lx + 2, oy, hexc('2a2228'))
    K.sphere(lc, ox + 5.0, oy - 8.4, 4.0, 3.2, dress, gloss=False)                         # the skirt / body
    lc.rect(ox + 3, oy - 10, ox + 6, oy - 7, hexc('f0ead8'))                               # the apron
    lc.hline(ox + 3, ox + 6, oy - 10, hexc('ffffff'))
    lc.rect(ox, oy - 10, ox + 1, oy - 7, skin)                                              # an arm dangling each side
    lc.rect(ox + 9, oy - 10, ox + 9, oy - 7, skin)
    K.sphere(lc, ox + 5.0, oy - 12.8, 3.2, 3.0, skin, gloss=True)                           # the head
    K.sphere(lc, ox + 2.4, oy - 13.6, 1.5, 2.2, hair)                                       # yarn hair either side + a fringe
    K.sphere(lc, ox + 7.6, oy - 13.6, 1.5, 2.2, hair)
    lc.hline(ox + 3, ox + 7, oy - 15, hair); lc.hline(ox + 3, ox + 6, oy - 14, shade(hair, 0.85))
    lc.put(ox + 4, oy - 12, hexc('1a1410')); lc.put(ox + 6, oy - 12, hexc('1a1410'))        # button eyes
    lc.put(ox + 5, oy - 11, hexc('c0604c'))                                                 # a stitched mouth
    L.flush()


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
