"""WALL THINGS AND CEILING LIGHTS, REDRAWN — the framed family photo, the wedding photograph, the HOME sampler, the arched mirror, the wall clock, the bracket shelf, the scratched tally marks, the
sprayed NO FOOD, and the three ceiling lights (owner round 47c: "redo all still on the list that need upgrading").

The frames use the wall-art kit's bevelled mouldings with a mat and a glint (wallart.frame); the pictures inside have people in them (round heads, hair, shoulders, a dress, a veil); the mirror has an
arched crown, a gilt inner line and foxed silvering; the clock a shaded rim, twelve marks and a stopped time; the shelf a thick board on brackets with spined books and a vase; the lights are
shaded drums, a ribbed paper lantern and a flush dome with a rim and a lit glass.
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
from furn_wardrobes import _mirror_glass

OUTLINE = hexc('2a1c17')
GILT, GILT_LT, GILT_DK = hexc('c9a24e'), hexc('f0d078'), hexc('7a5e24')


def _person(c, px, base, h, skin, hair, cloth, kind='adult'):
    """A figure in a photograph: a round head with hair, shoulders, a body that tapers (a skirt for a dress)."""
    top = base - h
    head = 3 if h >= 6 else 2
    c.rect(px - 1, top, px + (1 if head == 3 else 0), top + head - 1, skin)
    c.hline(px - 1, px + (1 if head == 3 else 0), top, hair)
    if head == 3:
        c.put(px - 1, top + 1, hair)
    if kind == 'dress':
        for k, y in enumerate(range(top + head, base + 1)):
            half = min(2, 1 + (k * 2) // max(1, base - top - head))
            c.hline(px - half, px + half, y, cloth if k % 5 else shade(cloth, 0.86))
    elif kind == 'child':
        c.rect(px - 1, top + head, px, base, cloth)
    else:
        c.rect(px - 1, top + head, px + 1, base - (1 if h > 6 else 0), cloth)
        if h > 6:
            c.put(px - 1, base, shade(cloth, 0.6)); c.put(px + 1, base, shade(cloth, 0.6))


# ================================================================================================================================ the family photo
@piece('frame_family', 20, 24, 'decor', rooms={'bedroom': 5, 'living_room': 5, 'dining_room': 4, 'study': 3}, styles={'adult': 5, 'sick': 1, 'kid': 1}, tags=('picture',),
       variants={'seaside': {}}, wall_y=(24, 44), note='a framed family photo at the seaside: a mat, an oak moulding, a glint on the glass, three figures, a gull')
def frame_family(c, ox, oy, p):
    ix0, iy0, ix1, iy1 = W.frame(c, ox, oy + 5, ox + 19, oy + 23, 'oak', mat=hexc('eae2cc'), thick=1, hang='wire', matw=1)
    c.rect(ix0, iy0, ix1, iy1, hexc('9ec6dc'))                                                  # sky, paler toward the horizon
    c.rect(ix0, iy0 + 4, ix1, iy0 + 5, hexc('b4d4e4'))
    hz = iy0 + 6
    c.rect(ix0, hz, ix1, hz + 2, hexc('4a82a8'))                                                # the sea
    c.hline(ix0, ix1, hz, hexc('78a8c4'))
    c.rect(ix0, hz + 3, ix1, iy1, hexc('d8c490'))                                               # the sand
    c.dither(ix0, hz + 3, ix1, hz + 3, hexc('c0aa78'), 0.5)
    c.put(ix0 + 2, iy0 + 1, hexc('fff2b0')); c.put(ix0 + 3, iy0 + 1, hexc('fff2b0'))             # the sun
    c.put(ix1 - 3, iy0 + 2, hexc('ffffff')); c.put(ix1 - 2, iy0 + 1, hexc('ffffff'))             # a gull
    base = iy1
    _person(c, ix0 + 4, base, 9, hexc('e8c0a0'), hexc('4a3424'), hexc('3f6aa0'))               # dad
    _person(c, ix0 + 7, base, 7, hexc('e8c0a0'), hexc('d8a040'), hexc('d8c04a'), 'child')      # the child between them
    _person(c, ix0 + 10, base, 9, hexc('e8c0a0'), hexc('6a3a2a'), hexc('b84a42'), 'dress')     # mum
    W.glint(c, (ix0, iy0, ix1, iy1))


# ================================================================================================================================ the wedding photo
@piece('photo_wedding', 29, 33, 'decor', rooms={'bedroom': 4, 'living_room': 4}, styles={'sick': 6, 'adult': 2}, tags=('picture',), wall_y=(24, 40), limit=1,
       note='a sepia wedding portrait in an oval mat: the bride in a veil and white dress, the groom in a dark suit')
def photo_wedding(c, ox, oy, p):
    ix0, iy0, ix1, iy1 = W.frame(c, ox, oy + 5, ox + 28, oy + 32, 'walnut', mat=hexc('d8c8a4'), thick=1, lip=False, hang='wire', matw=2)
    cx, cy = (ix0 + ix1) / 2.0 + 0.5, (iy0 + iy1) / 2.0 + 0.5
    rx, ry = (ix1 - ix0) / 2.0 + 0.5, (iy1 - iy0) / 2.0 + 0.5
    sepia = [hexc('2a1e14'), hexc('4a3424'), hexc('7a5e44'), hexc('a8896a'), hexc('d8c09a'), hexc('efe2c6')]
    mat = hexc('d8c8a4')
    c.rect(ix0, iy0, ix1, iy1, mat)                                                              # the mat, with an oval window cut in it
    def in_oval(x, y, lim):
        u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        return u * u + v * v <= lim
    for y in range(iy0, iy1 + 1):
        for x in range(ix0, ix1 + 1):
            if in_oval(x, y, 1.0):
                u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                c.put(x, y, mix(sepia[3], sepia[2], min(1.0, (u * u + v * v) * 0.95)))             # a studio backdrop, vignetted
    L = K.Layer(c)
    lc = L.c
    mid = int(cx)
    base = iy1 - 2
    gx, bx = mid - 5, mid + 5
    skin, hair = sepia[4], sepia[1]
    # the groom: dark shoulders, a white shirt front and tie, a round head with short dark hair
    lc.ellipse(gx, base + 3, 6.4, 6.4, sepia[0])
    lc.poly([(gx - 2, base - 3), (gx + 2, base - 3), (gx, base + 1)], sepia[5])
    lc.vline(gx, base - 2, base + 1, sepia[1])
    lc.ellipse(gx, base - 7.5, 3.0, 3.9, skin)
    lc.ellipse(gx, base - 10.8, 3.1, 1.9, hair)
    lc.put(gx - 1, base - 8, sepia[0]); lc.put(gx + 1, base - 8, sepia[0])
    lc.hline(gx - 1, gx + 1, base - 5, sepia[2])
    # the bride: a veil round her head, a white dress, a bouquet held low
    lc.ellipse(bx, base - 7.5, 5.3, 7.2, sepia[5])
    lc.ellipse(bx, base + 3, 6.4, 6.4, sepia[5])
    lc.hline(bx - 5, bx + 5, base - 2, sepia[4])
    lc.ellipse(bx, base - 7.0, 2.8, 3.7, skin)
    lc.ellipse(bx, base - 10.2, 3.0, 1.8, hair)
    lc.put(bx - 1, base - 8, sepia[0]); lc.put(bx + 1, base - 8, sepia[0])
    lc.hline(bx - 1, bx + 1, base - 5, sepia[2])
    lc.rect(bx - 2, base - 3, bx + 2, base, sepia[3]); lc.put(bx, base - 3, sepia[5]); lc.put(bx - 2, base, sepia[2]); lc.put(bx + 2, base - 2, sepia[5])
    for y in range(lc.h):                                                                         # keep the figures inside the oval
        for x in range(lc.w):
            if lc.px[x, y][3] and not (ix0 <= x <= ix1 and iy0 <= y <= iy1 and in_oval(x, y, 0.88)):
                lc.px[x, y] = (0, 0, 0, 0)
    L.flush(outline=False)
    for y in range(iy0, iy1 + 1):                                                                # the window's thin gilt edge
        for x in range(ix0, ix1 + 1):
            if in_oval(x, y, 1.0) and not in_oval(x, y, 0.88):
                c.put(x, y, GILT_DK)
    W.glint(c, (ix0, iy0, ix1, iy1), 34)


# ================================================================================================================================ the HOME sampler
@piece('sampler_home', 22, 17, 'decor', rooms={'bedroom': 3, 'living_room': 3, 'kitchen': 3}, styles={'sick': 6, 'adult': 2}, tags=('picture',), wall_y=(24, 40), limit=1,
       note='a cross-stitched HOME in a walnut frame: stitched letters, a heart, a border of little flowers')
def sampler_home(c, ox, oy, p):
    ix0, iy0, ix1, iy1 = W.frame(c, ox, oy + 1, ox + 21, oy + 16, 'walnut', mat=None, thick=1, hang=None, lip=False)
    c.rect(ix0, iy0, ix1, iy1, hexc('e6dcc0'))                                                  # linen
    for y in range(iy0, iy1 + 1, 2):
        for x in range(ix0 + ((y - iy0) // 2) % 2, ix1 + 1, 2):
            c.put(x, y, hexc('d8ccae'))                                                          # the weave
    green, red, blue = hexc('5a8a5a'), hexc('b0453a'), hexc('4a6aa0')
    for x in range(ix0 + 1, ix1, 2):                                                             # a running-stitch border
        c.put(x, iy0, green); c.put(x, iy1, green)
    for y in range(iy0 + 1, iy1, 2):
        c.put(ix0, y, green); c.put(ix1, y, green)
    for (fx, fy) in ((ix0, iy0), (ix1, iy0), (ix0, iy1), (ix1, iy1)):
        c.put(fx, fy, red)                                                                       # a flower in each corner
    F.text3(c, ix0 + 1 + (ix1 - ix0 - 15) // 2, iy0 + 2, 'HOME', red)
    hx, hy = (ix0 + ix1) // 2, iy1 - 2
    for (dx, dy) in ((-1, 0), (1, 0), (-2, -1), (2, -1), (0, 1)):                                # a stitched heart
        c.put(hx + dx, hy + dy, blue)
    c.put(hx, hy, blue)
    W.glint(c, (ix0, iy0, ix1, iy1), 30)


# ================================================================================================================================ the arched mirror
@piece('mirror_wall', 20, 28, 'decor', rooms={'bedroom': 5, 'bathroom': 8, 'living_room': 3, 'dining_room': 1}, styles={'adult': 4, 'sick': 1}, tags=('picture', 'mirror'),
       variants={'gilt': {'fr': 'c9a24e', 'dk': '7a5e24', 'lt': 'f0d078'}, 'dark': {'fr': '5a3e2c', 'dk': '2e1e14', 'lt': '7a5640'}}, wall_y=(22, 40),
       note='an arched wall mirror: a moulded frame with a gilt inner line and a small crest, glass that reflects the room, silvering going at the corners, hung from a nail')
def mirror_wall(c, ox, oy, p):
    fr, dk, lt = hexc(p['fr']), hexc(p['dk']), hexc(p['lt'])
    x0, x1, y0, y1 = ox + 1, ox + 18, oy + 3, oy + 27
    cxm = (x0 + x1) / 2.0 + 0.5
    rxm = (x1 - x0) / 2.0 + 0.5
    def inside(x, y, shrink):                                                                     # the arched outline: a rectangle with a half-ellipse head
        u = (x + 0.5 - cxm) / (rxm - shrink)
        if abs(u) > 1.0:
            return False
        if y < y0 + rxm - shrink * 0.2:
            v = (y + 0.5 - (y0 + rxm)) / (rxm - shrink)
            return u * u + v * v <= 1.0 and y + 0.5 >= y0 + shrink
        return y <= y1 - shrink and y >= y0
    for y in range(y0 - 1, y1 + 2):
        for x in range(x0 - 1, x1 + 2):
            if inside(x, y, 0):
                c.put(x, y, dk)                                                                    # the frame's outer edge
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if inside(x, y, 1):
                f = (x - x0) / float(x1 - x0)
                c.put(x, y, mix(lt, fr, min(1.0, f * 1.4)) if f < 0.7 else shade(fr, 0.84))      # the moulding, lit on the left
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if inside(x, y, 3) and not inside(x, y, 4):
                c.put(x, y, GILT if p['fr'] == '5a3e2c' else hexc('f4dc90'))                     # a bright inner line (gilt inside a dark frame)
    gx0, gx1, gy0, gy1 = x0 + 4, x1 - 4, y0 + 6, y1 - 4
    tb, bt = hexc('a8b6bc'), hexc('6e7e86')
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if inside(x, y, 4):
                f = (y - y0) / float(y1 - y0)
                col = mix(tb, bt, f * 0.9)
                if f > 0.62:
                    col = shade(col, 0.94)
                c.put(x, y, col)
    for (sx, ln) in ((x0 + 6, 9), (x0 + 9, 4)):                                                   # two streaks of window light
        for j in range(ln):
            if inside(sx - j, y0 + 10 + j, 4):
                c.put(sx - j, y0 + 10 + j, hexc('dce6e8'))
    rng = random.Random(5)
    for _ in range(9):                                                                              # foxing: the silvering lifting at the edge
        x, y = rng.randint(gx0 - 1, gx1 + 1), rng.randint(gy0 - 5, gy1 + 1)
        if inside(x, y, 4) and not inside(x, y, 7):
            c.put(x, y, hexc('4a5860'))
    cx_ = int(cxm)
    c.rect(cx_ - 1, y0 - 2, cx_ + 1, y0, GILT); c.put(cx_, y0 - 3, GILT_LT)                      # a small crest
    c.put(cx_ - 1, y0 - 1, GILT_LT)
    c.line(cx_, y0 - 3, cx_, oy + 1, hexc('4a3e30'))                                                # the hanging cord
    W.nail(c, cx_, oy)


# ================================================================================================================================ the wall clock
@piece('clock_wall', 14, 16, 'decor', rooms={'bedroom': 4, 'kitchen': 6, 'living_room': 4, 'dining_room': 3, 'study': 3}, styles={'adult': 3, 'kid': 2, 'sick': 3, 'teen': 1}, tags=('clock',),
       variants={'brass': {'rim': 'b09456'}, 'white': {'rim': 'd8d2c2'}}, wall_y=(22, 40),
       note='a round wall clock: a shaded rim, a cream face with twelve marks, hands stopped at the hour it all went wrong, a glint on the glass')
def clock_wall(c, ox, oy, p):
    rim = hexc(p['rim'])
    cx, cy, r = ox + 7.0, oy + 8.0, 7.0
    L = K.Layer(c)
    lc = L.c
    tn = K.tones(rim, 5, 0.5, 1.3)
    for y in range(int(cy - r) - 1, int(cy + r) + 2):                                              # the rim: a ring lit from the upper left
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            u, v = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
            d2 = u * u + v * v
            if d2 > 1.0:
                continue
            lam = max(0.0, 0.5 + 0.5 * (K.LX * u + K.LY * v) / 0.9)
            lc.put(x, y, K._pick(tn, 0.15 + 0.85 * lam))
    K.ell(lc, cx, cy, 5.2, 5.2, hexc('ece6d0'))                                                      # the face
    for k in range(12):                                                                              # twelve marks
        a = k * math.pi / 6.0
        long = k % 3 == 0
        rr = 4.4 if long else 4.1
        lc.put(int(cx + math.sin(a) * rr), int(cy - math.cos(a) * rr), hexc('2a2a2a') if long else hexc('5a5a5a'))
    lc.line(int(cx), int(cy), int(cx - 2), int(cy - 3), hexc('222222'))                              # minute hand, stopped near ten to
    lc.line(int(cx), int(cy), int(cx + 3), int(cy - 1), hexc('222222'))
    lc.put(int(cx), int(cy), hexc('a8322c'))
    lc.put(int(cx - 3), int(cy - 4), hexc('ffffff'))                                                 # glint
    L.flush()
    c.put(int(cx), oy, hexc('4a3e30'))                                                               # the nail


# ================================================================================================================================ the bracket shelf
@piece('wall_shelf', 28, 18, 'decor', rooms={'bedroom': 4, 'living_room': 5, 'study': 4, 'kitchen': 3, 'dining_room': 2}, styles={'adult': 3, 'teen': 2, 'kid': 2}, tags=('shelf',),
       variants={'a': {'x': 0}, 'b': {'x': 1}}, wall_y=(30, 46),
       note='a shelf on iron brackets with a thick board: spined books and a vase of dried flowers (a), a plant, a photo frame and a few books (b)')
def wall_shelf(c, ox, oy, p):
    y = oy + 14
    wood, wood_lt, wood_dk = hexc('8a6a4a'), hexc('b08a62'), hexc('5a4430')
    c.rect(ox, y, ox + 27, y + 2, wood)
    c.hline(ox, ox + 27, y, wood_lt)
    c.hline(ox, ox + 27, y + 2, wood_dk)
    c.hline(ox + 1, ox + 27, y + 3, hexc('3a2a1c'))
    for bx in (ox + 3, ox + 22):                                                                      # iron brackets: an upright and a diagonal brace
        c.vline(bx, y + 3, y + 7, hexc('3a3f48'))
        c.vline(bx + 1, y + 3, y + 7, hexc('5a6068'))
        c.line(bx + 1, y + 7, bx + 4, y + 3, hexc('3a3f48'))
        c.put(bx, y + 4, hexc('8a9098'))
    L = K.Layer(c)
    lc = L.c
    if p['x'] == 0:
        books = ((3, 10, F.BOOKS[1]), (3, 12, F.BOOKS[0]), (2, 9, F.BOOKS[2]), (3, 11, F.BOOKS[3]))
        x = ox + 2
        for w, h, col in books:
            for xx in range(x, x + w):
                f = (xx - x) / float(max(1, w - 1))
                for yy in range(y - h, y):
                    lc.put(xx, yy, shade(col, 1.14 - 0.4 * f))
            lc.hline(x, x + w - 1, y - h, shade(col, 1.3))
            lc.hline(x, x + w - 1, y - h + 2, hexc('c9a84a'))
            x += w
        K.cyl(lc, ox + 21.5, y - 6, y - 2, 2.6, hexc('7aa0a8'), ry=1.2, cap=True, inner=hexc('2a3a3e'), gloss=True)   # a vase
        for k, (dx, dy, col) in enumerate(((-1, 9, hexc('b8a05a')), (1, 11, hexc('a8885a')), (3, 8, hexc('c8b872')), (0, 12, hexc('9a7a4a')))):
            lc.vline(int(ox + 21 + k), y - dy, y - 6, hexc('6a5a3a'))
            lc.put(int(ox + 21 + k), y - dy, col)
    else:
        K.frustum(lc, ox + 6.5, y - 6, y - 1, 3.2, 2.4, hexc('b86a4a'), inner=hexc('3a2a1c'), rim=hexc('d08a64'), n=5)      # a plant pot
        for k, (dx, dy) in enumerate(((-3, -10), (-1, -12), (1, -11), (3, -9), (0, -8))):
            lc.line(int(ox + 6.5), y - 6, int(ox + 6.5 + dx), y + dy + 2, hexc('3f6a3a'))
            K.sphere(lc, ox + 6.5 + dx, y + dy + 2, 1.7, 1.2, hexc('5a9a4a'))
        W.frame(lc, ox + 12, y - 10, ox + 19, y - 1, 'walnut', mat=hexc('e6dcc0'), thick=1, glass=False)
        lc.rect(ox + 14, y - 8, ox + 17, y - 4, hexc('9ac0d8'))
        lc.rect(ox + 14, y - 5, ox + 17, y - 3, hexc('7a9a5a'))
        for i, (h, col) in enumerate(((7, F.BOOKS[4]), (9, F.BOOKS[2]), (8, F.BOOKS[1]))):
            for xx in range(ox + 21 + i * 2, ox + 23 + i * 2):
                for yy in range(y - h, y):
                    lc.put(xx, yy, shade(col, 1.1 if xx % 2 else 0.78))
    L.flush()


# ================================================================================================================================ scratched tally
@piece('tally_marks', 31, 12, 'decor', rooms={'bedroom': 4, 'living_room': 2, 'study': 2}, styles={'refuge': 8, 'sick': 1}, tags=('mark',), wall_y=(44, 60), limit=1,
       note='the days, scratched into the plaster: groups of five struck through, each scratch a dark groove with pale chipped plaster along it, dust below')
def tally_marks(c, ox, oy, p):
    rng = random.Random(21)
    groove, chip, dust = hexc('4a4236'), hexc('d6cdb6'), hexc('c4bba4')
    def scratch(x, y0, y1):
        wob = 0
        for y in range(y0, y1 + 1):
            if rng.random() < 0.12:
                wob = rng.choice((-1, 0, 1)) if abs(wob) < 1 else 0
            c.put(x + wob, y, groove if y % 3 else shade(groove, 0.8))
            c.put(x + wob - 1, y, chip)                                                             # the pale lip of chipped plaster
        c.put(x + wob, y1 + 1, dust)
    for g in range(2):
        gx = ox + g * 13
        for i in range(4):
            scratch(gx + i * 2, oy + 1 + (i % 2), oy + 8 + rng.randint(0, 1))
        for k in range(10):                                                                          # the strike through the four
            t = k / 9.0
            x, y = int(gx - 1 + 8 * t), int(oy + 7 - 5 * t)
            c.put(x, y, groove); c.put(x, y + 1, chip)
    for i in range(3):                                                                               # the days since, not yet struck through
        scratch(ox + 25 + i * 2, oy + 2 + (i % 2), oy + 9)
    for (dx, dy) in ((3, 10), (9, 11), (15, 10), (6, 11), (20, 11)):                                # fallen plaster dust
        c.put(ox + dx, oy + dy, dust)


# ================================================================================================================================ sprayed NO FOOD
@piece('spray_nofood', 35, 18, 'decor', rooms={'bedroom': 4, 'living_room': 3, 'kitchen': 3}, styles={'refuge': 8}, tags=('notice',), wall_y=(24, 38), limit=1,
       note='NO FOOD, sprayed on the plaster in red: a soft halo of overspray round every letter, long runs that end in a bead, a crossed-out arrow under it')
def spray_nofood(c, ox, oy, p):
    rng = random.Random(3)
    red = hexc('a8322c')
    # overspray first: a faint wider halo, then the letters on top
    wd = F.text_spray(c, ox, oy, 'NO FOOD', red, scale=2, drips=False, seed=3)
    for y in range(oy, oy + 10):                                                                    # wet paint catches the light on the upper-left edge of each stroke
        for x in range(ox, ox + wd):
            if c.px[x, y][3] == 255 and c.px[x - 1, y][3] == 0 and c.px[x, y - 1][3] == 0:
                c.put(x, y, shade(red, 1.28))
    for y in range(oy - 2, oy + 12):
        for x in range(ox - 2, ox + wd + 2):
            if c.px[x, y][3] == 0:
                near = 0
                for (dx, dy) in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    if 0 <= x + dx < c.w and 0 <= y + dy < c.h and c.px[x + dx, y + dy][3] == 255:
                        near += 1
                if near and rng.random() < 0.4:
                    c.put(x, y, red[:3] + (80,))
    for gx in (3, 9, 17, 29, 36, 44, 50):                                                            # drips: a long run that thickens to a bead at its end
        x = ox + gx
        if not (0 <= x < c.w) or c.px[x, oy + 9][3] == 0:
            continue
        ln = rng.randint(3, 9)
        c.vline(x, oy + 10, oy + 10 + ln, red[:3] + (200,))
        c.put(x, oy + 11 + ln, red); c.put(x + 1, oy + 11 + ln, shade(red, 0.8)); c.put(x, oy + 10 + ln, shade(red, 1.25))
    for (dx, dy) in ((-2, 3), (wd + 1, 6), (wd - 6, -2), (12, 13)):                                  # stray flecks
        c.put(ox + dx, oy + dy, red[:3] + (160,))


# ================================================================================================================================ the ceiling lights
@piece('ceiling_flush', 17, 5, 'ceiling', rooms={'bedroom': 6, 'living_room': 4, 'study': 3, 'dining_room': 2, 'bathroom': 4, 'kitchen': 3}, styles=None, tags=('light', 'ceiling'),
       lights=({'dx': 0, 'dy': 4, 'kind': 'flush'},), note='a flush ceiling dome: a metal rim, a frosted glass bowl lit from inside, a ring of dust on the lip')
def ceiling_flush(c, ox, oy, p):
    cx = ox + 8.5
    rim, rim_dk = hexc('b8b2a2'), hexc('7a7466')
    c.rect(ox, 0, ox + 16, 0, rim_dk)                                                                # the ceiling plate
    c.rect(ox + 1, 0, ox + 15, 1, rim)
    c.hline(ox + 1, ox + 15, 0, hexc('d8d2c0'))
    L = K.Layer(c)
    lc = L.c
    K.sphere(lc, cx, 0.5, 7.6, 4.0, hexc('ece6d4'), n=5, lo=0.66, hi=1.18)                         # the glass bowl, shaded softly
    lc.hline(ox + 4, ox + 12, 2, hexc('fff6dc'))                                                     # the lit centre
    lc.hline(ox + 6, ox + 10, 3, hexc('fffaea'))
    for yy in range(0, 2):                                                                           # the ceiling hides the top
        for xx in range(lc.w):
            lc.px[xx, yy] = (0, 0, 0, 0)
    L.flush()
    c.hline(ox + 1, ox + 15, 1, rim)
    c.hline(ox, ox + 16, 0, rim_dk)
    c.put(ox + 2, 1, hexc('d8d2c0'))


LAMP_SHADES = {'cream': 'e6dcc0', 'rose': 'c27a82', 'green': '6f8f68', 'mustard': 'c9a24e'}


@piece('ceiling_pendant', 15, 26, 'ceiling', rooms={'bedroom': 4, 'living_room': 4, 'dining_room': 5, 'study': 2, 'kitchen': 2}, styles={'adult': 4, 'kid': 3, 'sick': 1},
       variants={s: {'shade': col} for s, col in LAMP_SHADES.items()}, tags=('light', 'ceiling'), lights=({'dx': 7, 'dy': 24, 'kind': 'pendant'},),
       note='a pendant on a twisted flex: a ceiling rose, a bulb holder and a shaded cone with a trim band and a bulb glowing under the hem')
def ceiling_pendant(c, ox, oy, p):
    cx = ox + 7
    col = hexc(p['shade'])
    c.rect(cx - 2, 0, cx + 2, 1, hexc('d8d2c0'))                                                     # the ceiling rose
    c.hline(cx - 2, cx + 2, 1, hexc('8a8678'))
    for y in range(2, 15):                                                                           # a twisted flex: alternating tones
        c.put(cx, y, hexc('2a2622') if y % 2 else hexc('4a4640'))
    c.rect(cx - 1, 14, cx + 1, 15, hexc('3a3834'))                                                   # the holder
    L = K.Layer(c)
    lc = L.c
    K.frustum(lc, cx, 15, 23, 2.6, 7.0, col, ry_t=0.8, ry_b=1.6, band=(shade(col, 0.72), 2), n=5, lo=0.55, hi=1.32)
    L.flush()
    K.sphere(c, cx, 25.0, 1.9, 1.5, hexc('fff0c0'), n=4, lo=0.9, hi=1.2)                            # the bulb under the hem
    c.put(cx, 24, hexc('fffbe8'))


@piece('ceiling_paper', 15, 22, 'ceiling', rooms={'bedroom': 3, 'living_room': 2}, styles={'kid': 8}, tags=('light', 'ceiling'), variants={'white': {}},
       lights=({'dx': 7, 'dy': 20, 'kind': 'pendant'},), note='a paper lantern: ribbed, soft white, a wire cap top and bottom, hung on a cord')
def ceiling_paper(c, ox, oy, p):
    cx = ox + 7
    for y in range(0, 8):
        c.put(cx, y, hexc('3a3834') if y % 2 else hexc('5a5650'))
    L = K.Layer(c)
    lc = L.c
    paper = hexc('f0e8d6')
    tn = K.tones(paper, 5, 0.62, 1.12)
    cy, rx, ry = 14.0, 6.6, 6.0
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if u * u + v * v > 1.0:
                continue
            nz = math.sqrt(max(0.0, 1.0 - u * u - v * v))
            lam = max(0.0, K.LX * u + K.LY * v + K.LZ * nz)
            col = K._pick(tn, 0.2 + 0.85 * lam)
            if (y - int(cy - ry)) % 3 == 0:                                                           # the paper ribs
                col = shade(col, 0.82)
            lc.put(x, y, col)
    lc.rect(cx - 2, 7, cx + 2, 8, hexc('6a6a66'))                                                   # the wire caps
    lc.rect(cx - 2, 20, cx + 2, 20, hexc('6a6a66'))
    lc.hline(cx - 1, cx + 1, 14, hexc('fff6dc'))                                                     # the glow through the paper
    L.flush()
