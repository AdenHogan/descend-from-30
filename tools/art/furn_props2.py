"""MORE SMALL THINGS, REDRAWN — shoes, trainers, slippers, a heap of clothes, the rug, a backpack, a crate, cardboard boxes, the mark where a picture hung, an armchair (owner round 47b: "everything
very flat and very basic looking… more detail and love"). Same method as furn_props.py: tones, a light from the upper left, a selective outline, a contact shadow — and for the armchair the
3D model renderer the living rooms use (tools/art/chair3d.py)."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import propkit as K
import chair3d as C3
from furnlib import piece
from pixlib import hexc, shade, mix

OUTLINE = hexc('2a1c17')
BRASS = hexc('b09456')


def _shadow(c, cx, cy, rx, ry=1.4, a=90):
    K.contact_shadow(c, cx, cy, rx, ry, a)


# ================================================================================================================================ shoes
def _profile(lc, x, base, heights, col, facing=1, sole=hexc('2a2220'), accent=None, laces=None, cap=None, collar=None, tongue=None):
    """A shoe seen from the side as a column profile: heights[i] rows of upper above a dark sole row; lit along the top, shaded toward the sole; laces, a toe cap and a dark collar mouth on request."""
    L = len(heights)
    cols = range(L) if facing == 1 else range(L - 1, -1, -1)
    for i, h in zip(range(L), heights):
        xx = x + (i if facing == 1 else L - 1 - i)
        lc.put(xx, base, sole)
        if h >= 3 and i < 3:
            lc.put(xx, base, shade(sole, 0.8))
        for k in range(h):
            y = base - 1 - k
            f = k / float(max(1, h - 1))
            lc.put(xx, y, shade(col, 0.74 + 0.5 * f))
        if h > 1:
            lc.put(xx, base - h, shade(col, 1.38))                              # the lit top edge
    if collar is not None:
        for i in collar:
            xx = x + (i if facing == 1 else L - 1 - i)
            lc.put(xx, base - heights[i], shade(col, 0.32))                        # the dark mouth of the shoe
    if laces is not None:
        for i in laces:
            xx = x + (i if facing == 1 else L - 1 - i)
            lc.put(xx, base - heights[i] + 1, hexc('e8e2d0') if (i % 2 == 0) else shade(col, 1.5))
    if cap is not None:
        xx = x + (cap if facing == 1 else L - 1 - cap)
        for k in range(1, heights[cap] + 1):
            lc.put(xx, base - k, shade(col, 0.62))
    if accent is not None:
        for i in range(2, L - 3):
            xx = x + (i if facing == 1 else L - 1 - i)
            lc.put(xx, base - 1 - (i % 3), accent)
    if tongue is not None:
        xx = x + (tongue if facing == 1 else L - 1 - tongue)
        lc.put(xx, base - heights[tongue] - 1, shade(col, 1.45))


def _sole_up(lc, x, base, L=12, col=hexc('2a2220'), heel=hexc('46382e')):
    """A shoe kicked over, sole up: the tread, a heel block, an instep."""
    for i in range(L):
        h = 3 if 1 < i < L - 2 else 2
        for k in range(h):
            lc.put(x + i, base - k, shade(col, 1.0 + (0.18 if k == h - 1 else 0.0)))
    for i in range(0, 4):
        lc.put(x + i, base - 1, heel)
        lc.put(x + i, base, shade(heel, 0.7))
    for i in range(5, L - 2, 2):
        lc.put(x + i, base - 1, shade(col, 1.5))
    lc.put(x + L - 1, base, shade(col, 0.7))


@piece('shoes_pair', 25, 7, 'floor', rooms={'bedroom': 6, 'living_room': 2}, tags=('clutter',),
       variants={'pale': {'col': 'b8a68a', 'kicked': False}, 'dark': {'col': '3a3036', 'kicked': False}, 'brown': {'col': '7a4a2c', 'kicked': True}, 'black': {'col': '2e2c30', 'kicked': True}},
       near=('sleeping',), feet=(116, 121), note='a pair of leather shoes, laces undone — one of them sometimes kicked over, sole up')
def shoes_pair(c, ox, oy, p):
    col = hexc(p['col'])
    _shadow(c, ox + 12, oy + 0.5, 13, 1.3)
    L = K.Layer(c)
    lc = L.c
    H = [5, 6, 6, 5, 4, 4, 5, 5, 4, 3, 3, 2]
    _profile(lc, ox, oy - 1, H, col, 1, laces=(5, 6, 7), cap=9, collar=(3, 4))
    if p['kicked']:
        _sole_up(lc, ox + 13, oy - 1)
    else:
        _profile(lc, ox + 13, oy, H, col, 1, laces=(5, 6, 7), cap=9, collar=(3, 4))
    L.flush()


@piece('trainers', 27, 7, 'floor', rooms={'bedroom': 6, 'living_room': 2}, styles={'teen': 6, 'adult': 1, 'kid': 1}, tags=('clutter',),
       variants={'white': {'col': 'e6e2d6', 'acc': 'a8322c'}, 'grey': {'col': '9aa0a8', 'acc': 'e0b83a'}, 'black': {'col': '3a3a40', 'acc': '5a9ae0'}},
       near=('sleeping', 'work'), feet=(116, 121), note='a pair of trainers kicked off, one on its side')
def trainers(c, ox, oy, p):
    col, acc = hexc(p['col']), hexc(p['acc'])
    _shadow(c, ox + 13, oy + 0.5, 14, 1.3)
    L = K.Layer(c)
    lc = L.c
    H = [5, 6, 6, 5, 4, 4, 5, 5, 5, 4, 3, 3, 2]
    for dx, face in ((0, 1), (14, 1)):
        _profile(lc, ox + dx, oy - 1, H, col, face, sole=hexc('e8e4d8'), accent=acc, laces=(5, 6, 7, 8), cap=11, collar=(3, 4), tongue=5)
        for i in range(13):                                                        # the thick midsole
            lc.put(ox + dx + i, oy - 1, hexc('f4f0e4'))
            lc.put(ox + dx + i, oy, hexc('8a8a82'))
    L.flush()


@piece('slippers', 13, 5, 'floor', rooms={'bedroom': 6, 'bathroom': 2}, styles={'adult': 4, 'sick': 2, 'kid': 1}, tags=('clutter',),
       variants={'blue': {'c': '5a6a8a'}, 'tan': {'c': 'a8845a'}, 'pink': {'c': 'c88a9a'}}, near=('sleeping',), feet=(116, 121), note='a pair of slippers with a fleece trim, side by side by the bed')
def slippers(c, ox, oy, p):
    col = hexc(p['c'])
    _shadow(c, ox + 6.5, oy + 0.4, 7.5, 1.1, 80)
    L = K.Layer(c)
    lc = L.c
    H = [3, 4, 4, 4, 4, 3, 3, 2]
    for dx in (0, 6):
        _profile(lc, ox + dx, oy - 1, H, col, 1, sole=hexc('8a6a44'))
        for i in range(1, 6):
            lc.put(ox + dx + i, oy - 1 - 3, hexc('f0ead8') if i % 2 else hexc('d8d0bc'))      # the fleece lining
    L.flush()


# ================================================================================================================================ clothes
CLOTH = [hexc('8a4a42'), hexc('4e5d70'), hexc('c1b69c'), hexc('5f6b4e'), hexc('7d6a8a'), hexc('2e2e33')]


@piece('clothes_pile', 34, 14, 'floor', rooms={'bedroom': 7, 'bathroom': 2}, styles=None, tags=('clutter', 'clothes'),
       variants={'blue_red': {'a': 1, 'b': 0, 'c': 2}, 'green_grey': {'a': 3, 'b': 5, 'c': 2}, 'plum_tan': {'a': 4, 'b': 2, 'c': 1}}, near=('sleeping', 'wardrobe'),
       anchors=({'name': 'clothes_pile', 'dx': 13, 'dy': -5},), feet=(116, 121), note='clothes dropped where they were taken off: jeans, a shirt with one sleeve flung out, a sock')
def clothes_pile(c, ox, oy, p):
    a, b, cc = CLOTH[p['a']], CLOTH[p['b']], CLOTH[p['c']]
    _shadow(c, ox + 16, oy + 0.5, 17, 1.8, 100)
    L = K.Layer(c)
    lc = L.c
    K.sphere(lc, ox + 12, oy - 3.2, 11, 3.4, a, n=5, lo=0.5, hi=1.3)                      # the jeans: a long low lump
    K.sphere(lc, ox + 20, oy - 4.6, 8.5, 4.2, b, n=5, lo=0.5, hi=1.3)                      # the shirt on top
    K.sphere(lc, ox + 6, oy - 5.2, 4.6, 3.0, shade(b, 1.08), n=4)                          # a bundled-up sleeve
    lc.poly([(ox + 25, oy - 5), (ox + 31, oy - 3), (ox + 33, oy - 1), (ox + 30, oy - 1), (ox + 26, oy - 3)], shade(b, 0.92))   # the other sleeve, flung out
    lc.line(ox + 26, oy - 5, ox + 31, oy - 3, shade(b, 1.35))
    lc.line(ox + 14, oy - 6, ox + 19, oy - 3, shade(a, 0.62))                                # creases
    lc.line(ox + 18, oy - 8, ox + 24, oy - 6, shade(b, 0.62))
    lc.line(ox + 5, oy - 3, ox + 12, oy - 2, shade(a, 0.62))
    lc.rect(ox + 14, oy - 2, ox + 17, oy - 1, cc)                                            # a sock
    lc.hline(ox + 14, ox + 17, oy - 2, shade(cc, 1.3))
    lc.hline(ox + 14, ox + 15, oy - 1, hexc('b8453a'))
    L.flush()


# ================================================================================================================================ the rug
@piece('rug_oblong', 66, 14, 'rug', rooms={'bedroom': 5, 'living_room': 5, 'study': 3, 'dining_room': 2}, styles={'adult': 3, 'kid': 3, 'teen': 2},
       variants={'mauve': {'col': '8a5a62', 'border': '5e3a42', 'pat': 'c9a888'}, 'green': {'col': '5e7a5a', 'border': '3c5238', 'pat': 'c8c498'}, 'blue': {'col': '4e6a8a', 'border': '34485e', 'pat': 'd0c8a8'},
                 'red': {'col': '8a3a38', 'border': '5a2424', 'pat': 'd8b890'}},
       tags=('rug',), feet=(118, 122), note='a woven rug on the floor — border bands, a field of lozenges, a medallion, fringe at both ends, worn in the middle')
def rug_oblong(c, ox, oy, p):
    col, bor, pat = hexc(p['col']), hexc(p['border']), hexc(p['pat'])
    rng = random.Random(len(p['col']) * 31 + ord(p['col'][0]))
    top, bot = oy - 12, oy - 1
    for y in range(top, bot + 1):
        f = (y - top) / float(bot - top)
        inset = int(round(2.5 * (1.0 - f)))                                                  # the far edge is shorter: the rug lies on the floor in perspective
        xa, xb = ox + 3 + inset, ox + 62 - inset
        for x in range(xa, xb + 1):
            edge_x = min(x - xa, xb - x)
            edge_y = min(y - top, bot - y)
            e = min(edge_x, edge_y * 3)
            if e <= 0:
                cc = shade(bor, 0.55)                                                          # the selvedge
            elif e <= 2:
                cc = bor                                                                       # the outer border
            elif e == 3:
                cc = pat                                                                       # a pale guard stripe
            elif e <= 4:
                cc = bor
            else:
                u, v = (x - ox) % 6, (y - top) % 4
                cc = col
                if abs(u - 3) + abs(v - 2) * 1.6 <= 2.2:
                    cc = shade(col, 1.22)                                                      # a field of lozenges
                if abs(u - 3) + abs(v - 2) * 1.6 <= 0.8:
                    cc = pat
            if f > 0.5 and rng.random() < 0.05 and e > 4:
                cc = shade(cc, 0.82)                                                           # worn / dirty patches
            c.put(x, y, cc)
    mx, my = ox + 32, (top + bot) // 2
    for k, r in enumerate((6, 4, 2)):                                                          # the medallion
        for dx in range(-r - 1, r + 2):
            for dy in range(-(r // 2) - 1, r // 2 + 2):
                if abs(dx) / float(r + 0.5) + abs(dy) / (r / 2.0 + 0.5) <= 1.0:
                    c.put(mx + dx, my + dy, (bor, pat, bor)[k])
    for y in range(top + 1, bot):                                                              # fringe at both ends
        if y % 2 == 0:
            f = (y - top) / float(bot - top)
            inset = int(round(2.5 * (1.0 - f)))
            for k in range(1, 3):
                c.put(ox + 2 + inset - k + 1, y, shade(pat, 0.9))
                c.put(ox + 63 - inset + k - 1, y, shade(pat, 0.9))
    c.hline(ox + 4, ox + 60, oy, hexc('1a120d', 90))                                           # its shadow on the boards


# ================================================================================================================================ a backpack
@piece('backpack', 25, 24, 'floor', rooms={'bedroom': 5, 'living_room': 2, 'study': 2}, styles={'refuge': 8, 'teen': 2, 'adult': 1}, tags=('storage', 'bag'),
       variants={'olive': {'col': '5a6a46', 'strap': '2e3a24'}, 'navy': {'col': '3a4a6a', 'strap': '222c44'}, 'red': {'col': '8a3a34', 'strap': '4a1e1c'}, 'tan': {'col': '9a8456', 'strap': '5a4a2a'}},
       anchors=({'name': 'backpack', 'dx': 11, 'dy': -14},), near=('sleeping',), feet=(116, 121), note='a rucksack slumped on the floor: a lid, a front pocket with a zip, a water bottle in the side pocket, a strap trailing')
def backpack(c, ox, oy, p):
    col, st = hexc(p['col']), hexc(p['strap'])
    _shadow(c, ox + 12, oy + 0.5, 14, 1.8, 100)
    L = K.Layer(c)
    lc = L.c
    tn = K.tones(col, 5, 0.5, 1.3)
    # the main body: a rounded slump, lit from the left
    for y in range(oy - 19, oy):
        f = (y - (oy - 19)) / 18.0
        half = 8.5 + 2.2 * f - (3.0 if y < oy - 16 else 0.0)
        for x in range(int(ox + 12 - half), int(ox + 12 + half) + 1):
            u = (x + 0.5 - (ox + 12)) / half
            lc.put(x, y, tn[max(0, min(4, int(1.6 + 2.4 * (0.6 - u * 0.9) + 0.9 * (1 - f) * 0.0)))])
    # the lid flap over the top, with a buckle and its strap
    lc.rect(ox + 5, oy - 19, ox + 19, oy - 13, shade(col, 1.12))
    lc.hline(ox + 5, ox + 19, oy - 19, shade(col, 1.4))
    lc.hline(ox + 5, ox + 19, oy - 13, shade(col, 0.6))
    lc.vline(ox + 12, oy - 13, oy - 9, st)
    lc.rect(ox + 11, oy - 10, ox + 13, oy - 8, hexc('b8bcc0'))
    lc.put(ox + 11, oy - 10, hexc('e8eaec'))
    # the front pocket with a zip and a pull
    lc.rect(ox + 6, oy - 10, ox + 18, oy - 1, shade(col, 0.94))
    lc.hline(ox + 6, ox + 18, oy - 10, shade(col, 0.55))
    lc.hline(ox + 6, ox + 18, oy - 9, shade(col, 1.25))
    lc.vline(ox + 6, oy - 10, oy - 1, shade(col, 1.2))
    lc.vline(ox + 18, oy - 10, oy - 1, shade(col, 0.6))
    for x in range(ox + 7, ox + 18):
        lc.put(x, oy - 7, hexc('8a8e92') if x % 2 else hexc('3a3a3a'))                     # the zip's teeth
    lc.rect(ox + 16, oy - 6, ox + 16, oy - 4, hexc('d8483a'))                                 # a pull tab
    # a bottle in the side pocket
    K.cyl(lc, ox + 3.0, oy - 8, oy - 1, 2.0, hexc('6a9ab8'), ry=0.8, gloss=True, cap_col=hexc('2a2a2e'))
    # the shoulder strap trailing, a carry loop on top, a bit of cloth poking out the lid
    lc.line(ox + 20, oy - 12, ox + 24, oy - 6, st)
    lc.line(ox + 21, oy - 12, ox + 25, oy - 6, shade(st, 1.4))
    lc.line(ox + 24, oy - 6, ox + 24, oy - 2, st)
    lc.rect(ox + 10, oy - 22, ox + 14, oy - 21, st)
    lc.vline(ox + 10, oy - 21, oy - 19, st)
    lc.vline(ox + 14, oy - 21, oy - 19, st)
    lc.poly([(ox + 14, oy - 19), (ox + 19, oy - 18), (ox + 18, oy - 15)], hexc('c9b898'))     # a shirt sleeve out of the lid
    L.flush()


# ================================================================================================================================ a wooden crate
@piece('crate_bedside', 21, 20, 'wall', rooms={'bedroom': 4}, styles={'teen': 6, 'refuge': 2, 'kid': 1}, tags=('storage', 'bedside'), depth=3,
       variants={'pine': {'col': 'b08a58'}, 'grey': {'col': '8a8a7e'}},
       slots=({'id': 'top', 'dx0': 2, 'dx1': 18, 'dy': -19, 'top': True, 'kinds': ('lamp', 'small')},), anchors=({'name': 'crate', 'dx': 10, 'dy': -10},), feet=(105, 108),
       note='a slatted wooden crate stood on end for a bedside table: planks with gaps, corner posts, nail heads, a rope hole, a stencilled mark')
def crate_bedside(c, ox, oy, p):
    col = hexc(p['col'])
    x0, x1 = ox, ox + 19
    top, base = oy - 18, oy
    _shadow(c, ox + 10, oy + 1, 11, 1.4)
    c.rect(x0, top, x1, base, shade(col, 0.4))                                               # the dark inside shows through the gaps
    for (ya, yb) in ((top + 1, top + 5), (top + 7, top + 11), (top + 13, base - 1)):          # three planks
        for y in range(ya, yb + 1):
            f = (y - ya) / float(max(1, yb - ya))
            c.hline(x0 + 1, x1 - 1, y, shade(col, 1.12 - 0.34 * f))
        c.hline(x0 + 1, x1 - 1, ya, shade(col, 1.32))
    for (px, dy) in ((x0 + 3, 0), (x1 - 3, 0)):
        c.rect(px - 1, top, px + 1, base, shade(col, 0.82))                                    # the corner posts
        c.vline(px - 1, top, base, shade(col, 1.15))
        c.vline(px + 1, top, base, shade(col, 0.58))
        for ny in (top + 3, top + 9, top + 15):
            c.put(px, ny, hexc('2a2420'))
    rng = random.Random(len(p['col']))
    _g = shade(col, 0.82)
    for y in (top + 2, top + 8, top + 14):
        for _ in range(2):
            gx = rng.randint(x0 + 6, x1 - 8)
            c.hline(gx, gx + rng.randint(2, 4), y, _g)                                          # grain
    c.rect(x0 + 7, top + 8, x0 + 12, top + 9, hexc('2a2420'))                                    # a rope handle hole
    c.hline(x0 + 7, x0 + 12, top + 7, shade(col, 1.2))
    c.hline(x0 - 1, x1 + 1, top - 1, shade(col, 1.2))
    c.hline(x0 - 1, x1 + 1, top, shade(col, 0.9))
    c.hline(x0, x1, base + 1, hexc('2a2018'))
    c.hline(x0 + 8, x0 + 11, top + 15, hexc('4a3a2a'))                                            # a stencilled mark
    c.hline(x0 + 8, x0 + 11, top + 17, hexc('4a3a2a'))


# ================================================================================================================================ cardboard boxes
@piece('boxes_stack', 34, 40, 'wall', rooms={'bedroom': 5, 'living_room': 3, 'study': 3, 'kitchen': 2, 'dining_room': 1}, styles={'refuge': 8}, tags=('storage',), depth=4,
       variants={'closed': {'lid': False}, 'open': {'lid': True}}, anchors=({'name': 'boxes', 'dx': 16, 'dy': -13},), feet=(105, 108),
       note='cardboard boxes stacked against the wall: taped shut with a label and a marker scrawl, or one open with clothes spilling out; a crushed corner, a handle slot')
def boxes_stack(c, ox, oy, p):
    card, card_dk = hexc('b4915f'), hexc('8a6c42')
    x0, x1 = ox + 1, ox + 31
    base = oy
    _shadow(c, ox + 16, oy + 1, 17, 1.6)
    # the bottom box
    top1 = base - 17
    for y in range(top1, base + 1):
        f = (y - top1) / 17.0
        c.hline(x0, x1, y, shade(card, 1.08 - 0.34 * f))
    c.vline(x0, top1, base, shade(card, 1.25))
    c.vline(x1, top1, base, shade(card, 0.62))
    c.hline(x0, x1, base, shade(card_dk, 0.7))
    c.rect(x0 + 13, top1, x0 + 17, base - 3, hexc('d8c89a'))                                      # packing tape down the middle
    c.vline(x0 + 13, top1, base - 3, hexc('ece0b8'))
    c.hline(x0, x1, top1 + 3, shade(card, 0.72))                                                  # the flap seam
    c.rect(x0 + 21, top1 + 6, x0 + 28, top1 + 12, hexc('ece6d6'))                                 # a shipping label
    c.hline(x0 + 22, x0 + 26, top1 + 8, hexc('5a5448')); c.hline(x0 + 22, x0 + 27, top1 + 10, hexc('5a5448'))
    c.rect(x0 + 3, top1 + 8, x0 + 8, top1 + 9, shade(card, 0.4))                                  # a handle slot
    c.line(x0 + 3, top1 + 13, x0 + 9, top1 + 11, hexc('2a2a2e'))                                  # marker: KITCHEN?
    c.line(x0 + 10, top1 + 13, x0 + 12, top1 + 11, hexc('2a2a2e'))
    c.poly([(x1 - 3, base), (x1, base - 4), (x1, base)], shade(card_dk, 0.8))                     # a crushed corner
    # the top box, narrower and set a little to one side
    bx0, bx1 = ox + 6, ox + 25
    top2 = top1 - 14
    for y in range(top2, top1):
        f = (y - top2) / 14.0
        c.hline(bx0, bx1, y, shade(card, 1.14 - 0.32 * f))
    c.vline(bx0, top2, top1 - 1, shade(card, 1.3))
    c.vline(bx1, top2, top1 - 1, shade(card, 0.66))
    if not p['lid']:
        c.rect(bx0 + 7, top2, bx0 + 11, top1 - 1, hexc('d8c89a'))
        c.hline(bx0, bx1, top2 + 3, shade(card, 0.72))
        c.hline(bx0, bx1, top2, shade(card, 1.35))
        c.rect(bx0 + 13, top2 + 6, bx0 + 17, top2 + 10, hexc('ece6d6'))
        c.put(bx0 + 14, top2 + 8, hexc('a8322c'))
    else:
        c.poly([(bx0, top2 + 1), (bx0 - 4, top2 - 6), (bx0 + 5, top2 - 6), (bx0 + 7, top2 + 1)], shade(card, 1.22))        # the flaps folded back
        c.poly([(bx1, top2 + 1), (bx1 + 4, top2 - 6), (bx1 - 5, top2 - 6), (bx1 - 7, top2 + 1)], shade(card, 0.88))
        c.hline(bx0, bx1, top2, shade(card, 1.35))
        c.rect(bx0 + 2, top2 - 3, bx1 - 2, top2, hexc('6e7f90'))                                                              # clothes bundled in the top
        c.rect(bx0 + 5, top2 - 5, bx0 + 10, top2 - 2, hexc('a8584e'))
        c.hline(bx0 + 3, bx1 - 3, top2 - 3, hexc('8a9aaa'))
        c.put(bx0 + 12, top2 - 6, hexc('e8e0cc'))
    c.hline(bx0 - 1, bx1 + 1, top1, hexc('2a2018'))


# ================================================================================================================================ where a picture used to hang
@piece('frame_ghost', 18, 22, 'decor', rooms={'bedroom': 3, 'living_room': 3, 'dining_room': 2}, styles={'adult': 3}, tags=('picture', 'story'), wall_y=(24, 44),
       note="where a picture used to hang — taken when they left: the unfaded paper, a dirt line round it, a nail, a snapped length of string")
def frame_ghost(c, ox, oy, p):
    base = hexc('5f6a78')
    x0, y0, x1, y1 = ox + 1, oy + 6, ox + 16, oy + 20
    c.rect(x0 - 1, y0 - 1, x1 + 1, y1 + 1, shade(base, 0.82))                                      # the dirt ring where the frame kept the dust off
    c.rect(x0, y0, x1, y1, shade(base, 1.14))                                                      # the unfaded paper
    c.dither(x0, y0, x1, y1, shade(base, 1.2), 0.5)
    c.hline(x0, x1, y0, shade(base, 0.95))
    c.vline(x0, y0, y1, shade(base, 0.98))
    for k in range(3):                                                                              # a smudge of tape, a pale patch low down
        c.put(x0 + 3 + k, y1 - 2, shade(base, 1.35))
    nail = hexc('3b2718')
    c.put(ox + 8, oy + 1, nail)
    c.put(ox + 8, oy + 2, shade(nail, 1.5))
    c.line(ox + 8, oy + 2, ox + 5, oy + 6, hexc('6a5a44'))                                         # the snapped string, still on the nail
    c.put(ox + 4, oy + 7, hexc('6a5a44'))


# ================================================================================================================================ an armchair (3D)
FABRICS = {'mustard': hexc('b08a3a'), 'green': hexc('5a7a55'), 'rose': hexc('a85a62'), 'grey': hexc('7a7f88'), 'red': hexc('a0383a'), 'brown': hexc('9a6a3a'), 'teal': hexc('3f7a78')}
LIVING_FAB_FOR = {'red': ['cosy', 'den'], 'mustard': ['mid', 'studio'], 'teal': ['mid', 'studio'], 'green': ['parlour', 'library'], 'brown': ['lodge', 'den', 'library'], 'rose': ['parlour'], 'grey': ['squat', 'office']}   # which room's chairs wear which fabric


def _arm_variants():
    v = {}
    for style in ('club', 'wing'):
        for k in FABRICS:
            for yn, yaw in (('l35', 35), ('r35', -35), ('l58', 58), ('r58', -58)):          # the turn in degrees — never a case-only difference (l / L): two files that differ only by case collide on Windows / macOS
                params = {'style': style, 'fab': k, 'yaw': yaw}
                if k in LIVING_FAB_FOR:
                    params['for'] = LIVING_FAB_FOR[k] + (['adult', 'sick', 'refuge'] if k in ('mustard', 'green', 'rose', 'grey') else [])
                else:
                    params['for'] = ['adult', 'sick', 'refuge']
                v['%s_%s_%s' % (style, k, yn)] = params
    return v


@piece('armchair', 34, 38, 'front', rooms={'bedroom': 4, 'living_room': 8, 'study': 5, 'dining_room': 1}, styles={'adult': 3, 'sick': 1, 'refuge': 1, 'cosy': 6, 'mid': 6, 'parlour': 6, 'lodge': 6}, tags=('seating_lounge', 'armchair'),
       variants=_arm_variants(), anchors=({'name': 'armchair', 'dx': 17, 'dy': -12},), feet=(114, 119), limit=1,
       note='an armchair, club or wing back, rolled arms, a loose seat cushion — built as a 3D model so it is properly turned toward the room')
def armchair(c, ox, oy, p):
    f = FABRICS[p['fab']]
    pal = {'fab': f, 'fab_lt': shade(f, 1.14), 'wood': hexc('3a2618')}
    C3.armchair(c, ox + 17, oy - 3, p['yaw'], pal, style=p['style'])
