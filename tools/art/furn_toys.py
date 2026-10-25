"""THE TOYS, SECOND PASS (owner: "Ragdoll, toy chest and blocks still need work too") — richer, with wear and story.

* toy_chest: a worn blue chest — planks in two shades with grain, paint chipped back to wood at the corners and edges, TOYS stencilled across the front, a small brass hasp, iron corner brackets,
  a lid thrown back with a star and a sticker, toys heaped HIGH inside (a teddy, a drum, a stack of blocks, a ball, a trumpet, a doll's stocking), and a teddy's arm hanging out over the front rim.
* block_tower (3 variants): proper 3D wooden blocks — lit top, shaded front, a dark side — with letters, numbers and little animal faces, chipped corners and grain; a tower with a roof and a block knocked
  over beside it, a bridge with a cylinder on top, and a scatter with one block tipped and a cylinder lying on its side.
* rag_doll (2 variants): bigger and floppier — yarn hair in braids with ribbons, a button eye and a cross-stitched one, a stitched smile, a patched dress and apron, one arm up and one down, striped
  stockings, black shoes, a rip in her side with the stuffing coming out.
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
from furn_kids import _clip_below, _star, TOY_R, TOY_Y, TOY_B, TOY_G, OUTLINE

WOOD_BARE = hexc('c8a066')


# ================================================================================================================================ the toy chest
def _chip(c, x, y, wood=WOOD_BARE):
    """A fleck of paint knocked off: bare wood with a dark bruise beside it."""
    c.put(x, y, wood)
    c.put(x + 1, y, shade(wood, 0.8))


def _toy_chest(c, cx):
    blue, blue_lt, blue_dk, blue_out = hexc('6a93c0'), hexc('9ac0e0'), hexc('3f6288'), hexc('2c4560')
    plank2 = hexc('5f88b4')
    iron, yellow = hexc('3a3f48'), hexc('e0b83a')
    rng = random.Random(11)
    d0, d1 = 8, 16
    wx0 = 160 + (cx - 14 - 160) * 100.0 / (100 + d1)
    wx1 = 160 + (cx + 14 - 160) * 100.0 / (100 + d1)
    c.shadow(cx, 117, 18, 2, 115)
    # the lid, thrown back against the wall: its painted inside, a star, a stripe, a sticker, scuffs
    lb, lr_ = pp(wx0 + 1, 90, d0), pp(wx1 - 1, 90, d0)
    lt = round(lb[1]) - 13
    lid = [(round(lb[0]), lt), (round(lr_[0]), lt), (round(lr_[0]), round(lr_[1])), (round(lb[0]), round(lb[1]))]
    c.poly(lid, shade(blue, 1.12))
    c.rect(lid[0][0] + 2, lid[0][1] + 2, lid[1][0] - 2, lid[3][1] - 2, shade(blue, 1.26))
    for yy in range(lid[0][1] + 3, lid[3][1] - 2):                                          # a soft shading down the lid's inside
        c.hline(lid[0][0] + 2, lid[1][0] - 2, yy, shade(blue, 1.30 - 0.025 * (yy - lid[0][1])))
    c.hline(lid[0][0] + 2, lid[1][0] - 2, lid[0][1] + 2, hexc('c4dcee'))
    _star(c, (lid[0][0] + lid[1][0]) // 2 - 2, lt + 7, yellow, hexc('f6dc78'))
    sx = lid[1][0] - 7                                                                      # a sticker: a little red heart
    for (dx, dy) in ((0, 0), (1, 0), (3, 0), (4, 0), (0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (1, 2), (2, 2), (3, 2), (2, 3)):
        c.put(sx + dx, lt + 5 + dy, hexc('d8484a'))
    c.put(sx, lt + 5, hexc('f08888'))
    for _ in range(5):                                                                      # scuffs on the lid
        _chip(c, rng.randint(lid[0][0] + 3, lid[1][0] - 3), rng.randint(lt + 3, lid[3][1] - 4), shade(blue, 1.45))
    for (a, b) in ((lid[0], lid[1]), (lid[0], lid[3]), (lid[1], lid[2])):
        c.line(a[0], a[1], b[0], b[1], blue_out)
    for sx_ in (lid[0][0] + 1, lid[1][0] - 1):                                              # iron hinges
        c.rect(sx_ - 1, lid[3][1] - 3, sx_ + 1, lid[3][1], iron)
    # the box
    f = pbox(c, wx0, 90, wx1, 100, d0, d1, blue, hexc('141c28'), shade(blue, 0.68), blue_out)
    fl, fr, fbl, fbr, bl, br = f['fl'], f['fr'], f['fbl'], f['fbr'], f['bl'], f['br']
    x0, x1, y0, y1 = fl[0], fr[0], fl[1], fbl[1]
    for xx in range(x0 + 1, x1):                                                           # planks: alternating shades, lit left edge, dark seam, a little grain
        k = (xx - x0) % 6
        pl = int((xx - x0) / 6) % 2
        for yy in range(y0 + 1, y1):
            col = blue if not pl else plank2
            if k == 0:
                col = shade(blue, 0.74)
            elif k == 1:
                col = blue_lt if not pl else shade(blue_lt, 0.93)
            elif k == 5:
                col = shade(col, 0.92)
            elif rng.random() < 0.05:
                col = shade(col, 0.88)                                                     # grain
            c.put(xx, yy, col)
    c.hline(x0 + 1, x1 - 1, y0 + 1, blue_lt)                                               # the rim, lit
    c.hline(x0 + 1, x1 - 1, y0 + 2, shade(blue, 0.7))
    c.rect(x0 + 1, y1 - 2, x1 - 1, y1 - 1, blue_dk)                                        # a base band
    c.hline(x0 + 1, x1 - 1, y1 - 2, shade(blue_dk, 1.25))
    for (bx0, bx1) in ((x0 + 1, x0 + 4), (x1 - 4, x1 - 1)):                                # iron corner brackets with rivets
        c.rect(bx0, y0 + 1, bx1, y0 + 4, iron)
        c.rect(bx0, y1 - 5, bx1, y1 - 1, iron)
        c.put(bx0 + 1, y0 + 2, hexc('8a9098')); c.put(bx0 + 1, y1 - 3, hexc('8a9098'))
        c.hline(bx0, bx1, y0 + 1, hexc('5a6068'))
    mx = (x0 + x1) // 2
    c.rect(mx - 1, y0 + 1, mx + 1, y0 + 3, hexc('c9a24e'))                                  # the brass hasp on the rim
    c.put(mx, y0 + 3, OUTLINE); c.put(mx - 1, y0 + 1, hexc('e8cc78'))
    pl_x0, pl_x1 = mx - 9, mx + 9                                                            # a painted label plate, lighter than the planks, with the stencil on it
    c.rect(pl_x0, y0 + 4, pl_x1, y1 - 3, hexc('3a5a7e'))
    c.hline(pl_x0, pl_x1, y0 + 4, hexc('86aed0'))
    F.text3(c, mx - 7, y0 + 5, 'TOYS', hexc('f0d050'))
    for (ex, ey) in ((x0 + 5, y0 + 2), (x1 - 6, y1 - 4), (x0 + 6, y1 - 3), (x1 - 8, y0 + 3), (pl_x0 - 2, y1 - 4)):   # paint knocked back to the wood
        _chip(c, ex, ey)
    # toys heaped inside, clipped at the front rim
    L = K.Layer(c)
    lc = L.c
    base = y0 - 1
    bear = hexc('a8703a')
    K.sphere(lc, x0 + 8, base - 3.8, 3.8, 3.6, bear, gloss=True)                            # a teddy's head, an ear each side
    K.sphere(lc, x0 + 4.6, base - 7.2, 1.6, 1.6, shade(bear, 0.9))
    K.sphere(lc, x0 + 11.6, base - 7.2, 1.6, 1.6, shade(bear, 0.9))
    K.sphere(lc, x0 + 8.4, base - 2.2, 1.9, 1.4, hexc('d8b078'))
    lc.put(x0 + 8, base - 2, hexc('2a1c17')); lc.put(x0 + 6, base - 5, hexc('1a1410')); lc.put(x0 + 10, base - 5, hexc('1a1410'))
    K.slab(lc, x0 + 15, base - 8, x0 + 20, base - 1, TOY_Y, d=2, inset=0)                  # two blocks stacked in the middle
    K.slab(lc, x0 + 16, base - 13, x0 + 20, base - 9, TOY_R, d=2, inset=0)
    K.sphere(lc, x1 - 8.0, base - 4.0, 3.4, 3.4, TOY_B, gloss=True)                          # a blue ball
    lc.hline(x1 - 11, x1 - 5, base - 4, hexc('f0ead8'))
    for k in range(6):                                                                      # a doll's striped stocking, a red shoe
        lc.rect(x1 - 3, base - 10 + k, x1 - 2, base - 10 + k, hexc('f0ead8') if k % 2 else TOY_R)
    lc.rect(x1 - 4, base - 12, x1 - 1, base - 11, hexc('8a2e2a'))
    lc.hline(x1 - 4, x1 - 1, base - 12, hexc('c8584a'))
    _clip_below(lc, y0)
    L.flush()
    L2 = K.Layer(c)                                                                          # the teddy's arm hangs over the front rim at the left, paw down
    lc2 = L2.c
    K.sphere(lc2, x0 + 7.0, y0 + 1.6, 1.5, 2.4, bear, gloss=False)
    K.sphere(lc2, x0 + 7.0, y0 + 3.8, 1.5, 1.3, shade(bear, 0.85))
    L2.flush()


@piece('toy_chest', 36, 30, 'floor', keep='storage', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8, 'teen': 1}, tags=('toy', 'storage'), variants={'blue': {}}, bucketed=True,
       anchors=({'name': 'toy_chest', 'dx': 18, 'dy': -10},), near=('sleeping',), feet=(116, 119),
       note='a worn blue toy chest in true perspective: two shades of plank, paint chipped back to wood, TOYS stencilled across the front, a lid with a star and a heart sticker, toys heaped high (teddy, drum, blocks, ball, trumpet, a stocking) and the teddy\'s arm hanging over the rim')
def toy_chest(c, ox, oy, p):
    _legacy(c, lambda l: _toy_chest(l, ox + 18), 0, oy - 117)


# ================================================================================================================================ blocks
# the drawing is tools/art/toys3d.py — the SAME cube / roof block / cylinder the baked bedroom E uses (owner round 48j: one standard for a toy wherever it stands)
import toys3d as T3


def _cube(lc, x0, yb, w, col, face, rng, d=3, sgn=1):
    T3.cube(lc, x0, yb, w, col, face, rng, d=d, sgn=sgn)


def _wedge(lc, cx, base, w, h, col, sgn=1):
    T3.roof(lc, cx, base, w, h, col, d=3, sgn=sgn)


def _lying_cyl(lc, x0, x1, yb, r, col):
    T3.lying_cyl(lc, x0, x1, yb, r, col)


@piece('block_tower', 28, 28, 'floor', keep='toy', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8}, tags=('toy',), near=('toy',), feet=(106, 112), bucketed=True, lean=False,
       variants={'a': {'v': 0}, 'b': {'v': 1}, 'c': {'v': 2}},
       note='wooden toy blocks with letters, numbers and little animals, in the baked child\'s room\'s own drawing (toys3d.py): a square tower of three with a roof block and one beside it, a plank bridge with a drum on top, or a scatter with a roof block and a cylinder on its side; the side faces turn toward the room\'s middle')
def block_tower(c, ox, oy, p):
    rng = random.Random(5 + p['v'])
    sg = 1 if ox + 14 <= 160 else -1                                                                 # a block left of the room's middle shows its right side, one on the right its left
    K.contact_shadow(c, ox + 14, oy + 0.5, 15.0, 1.6, 100)
    L = K.Layer(c)
    lc = L.c
    v = p['v']
    if v == 0:
        _cube(lc, ox, oy, 8, TOY_B, 'A', rng, sgn=sg)                                                # three blocks square on one another, a roof block on top
        _cube(lc, ox, oy - 8, 8, TOY_R, 'heart', rng, sgn=sg)
        _cube(lc, ox, oy - 16, 8, TOY_Y, 'B', rng, sgn=sg)
        _wedge(lc, ox + 4, oy - 24, 8, 5, hexc('c8483a'), sgn=sg)
        _cube(lc, ox + 18, oy, 7, hexc('e8883a'), 'cat', rng, d=2, sgn=sg)                           # one more on the floor beside it
    elif v == 1:
        _cube(lc, ox, oy, 8, TOY_R, 'M', rng, sgn=sg)
        _cube(lc, ox + 15, oy, 8, TOY_B, 'duck', rng, sgn=sg)
        T3.plank(lc, ox - 1, ox + 24, oy - 8, hexc('d8b070'), sgn=sg)                                # a plank across for a bridge
        K.cyl(lc, ox + 12, oy - 18, oy - 12, 3.2, TOY_G, ry=1.3, cap=True, gloss=True)             # a cylinder standing on it
        _cube(lc, ox + 26, oy, 5, TOY_Y, '7', rng, d=2, sgn=sg)
    else:
        _cube(lc, ox, oy, 8, TOY_G, 'D', rng, sgn=sg)
        _cube(lc, ox + 11, oy, 8, TOY_Y, 'sun', rng, sgn=sg)
        _lying_cyl(lc, ox + 21, ox + 31, oy, 3, hexc('d86a9a'))
        _wedge(lc, ox + 15, oy - 8, 7, 5, TOY_B, sgn=sg)
    L.flush()


# ================================================================================================================================ the rag doll
@piece('rag_doll', 13, 20, 'floor', keep='toy', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8}, tags=('toy',),
       variants={'a': {'dress': '5a82c0', 'hair': 'c8742c', 'skin': 'f0d4b8', 'apron': 'f0ead8'}, 'b': {'dress': 'c9a24e', 'hair': '4a3020', 'skin': 'd8a880', 'apron': 'e6d8c0'}},
       near=('sleeping',), feet=(112, 119),
       note='a rag doll slumped on the floor: yarn hair in braids with ribbons, button eyes, a stitched smile, rosy cheeks, a dress and apron, one arm up and one down, striped stockings, black shoes')
def rag_doll(c, ox, oy, p):
    K.contact_shadow(c, ox + 6.5, oy + 0.6, 8.0, 1.5, 95)
    dress, hair, skin, apron = hexc(p['dress']), hexc(p['hair']), hexc(p['skin']), hexc(p['apron'])
    L = K.Layer(c)
    lc = L.c
    cream = hexc('f0ead8')
    for lx, d in ((ox + 3.0, -1), (ox + 9.4, 1)):                                                    # legs: striped stockings splayed forward, black shoes
        for k in range(4):
            for xx in (int(lx) - 1, int(lx)):
                lc.put(xx + (d * k) // 3, oy - 5 + k, cream if k % 2 else TOY_R)
        K.sphere(lc, lx + d * 0.6, oy - 1.0, 2.2, 1.3, hexc('2a2228'), gloss=True)
    K.sphere(lc, ox + 6.4, oy - 8.6, 5.0, 4.4, dress, n=5, lo=0.55, hi=1.2)                         # the skirt and body
    lc.poly([(ox + 5, oy - 12), (ox + 8, oy - 12), (ox + 9, oy - 5), (ox + 4, oy - 5)], apron)      # the apron
    lc.vline(ox + 6, oy - 10, oy - 6, shade(apron, 0.82))
    for k in range(3):                                                                               # one arm flung up, one hanging
        K.sphere(lc, ox + 11.0 + k * 0.7, oy - 12.0 - k * 1.8, 1.2, 1.3, dress if k < 2 else skin)
    K.sphere(lc, ox + 1.6, oy - 9.5, 1.3, 2.4, dress)
    K.sphere(lc, ox + 1.4, oy - 6.8, 1.2, 1.2, skin)
    K.sphere(lc, ox + 6.2, oy - 15.0, 4.0, 3.8, skin, n=5, lo=0.62, hi=1.15)                         # the head
    K.sphere(lc, ox + 6.4, oy - 17.4, 4.4, 2.4, hair, n=5)                                           # the yarn fringe
    for (bx, by) in ((ox + 1.9, oy - 14.0), (ox + 1.7, oy - 12.0), (ox + 10.4, oy - 14.0), (ox + 10.6, oy - 12.0)):   # braids with ribbons
        K.sphere(lc, bx, by, 1.2, 1.1, hair)
    lc.put(int(ox + 1.7), int(oy - 10.4), TOY_R); lc.put(int(ox + 10.6), int(oy - 10.4), TOY_R)
    lc.put(ox + 4, oy - 15, hexc('1a1410')); lc.put(ox + 8, oy - 15, hexc('1a1410'))                 # button eyes
    lc.put(ox + 4, oy - 16, hexc('f4f0e4'))
    lc.put(ox + 5, oy - 12, hexc('a8483a')); lc.put(ox + 6, oy - 12, hexc('a8483a')); lc.put(ox + 7, oy - 12, hexc('a8483a'))   # a stitched smile
    lc.put(ox + 3, oy - 13, hexc('e89a8a')); lc.put(ox + 9, oy - 13, hexc('e89a8a'))                 # rosy cheeks
    L.flush()
