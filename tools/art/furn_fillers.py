"""FILLERS — the plain, ordinary things a real room has along its walls (owner round 48i: "modules feel lifeless and empty… spartan").

Measured first (`tools/furniture_dump.tscn`): in the sparsest styles (an office study, a squat's living room, a houseshare's dining room) barely a third of the back wall had anything on it, because the
wall-plane pools held only a few big pieces. These are the things that were missing, each a real object with volume (no flat drawings): a COLUMN RADIATOR under where a window would be, a BLANKET
TRUNK at the foot of a wall, a COAT STAND by the door. All three are low-key on purpose — they give a room presence without handing out loot (only the trunk is searchable).
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furnlib as FL
import propkit as K
from furnlib import piece
from pixlib import hexc, shade, mix

STEEL = hexc('4a4d52')
STEEL_LT = hexc('8a8f96')
STEEL_DK = hexc('2c2e32')
BRASS = hexc('b09456')
BRASS_LT = hexc('e0c878')
BRASS_DK = hexc('7a6430')


# ================================================================================================================================ the column radiator
RAD_COLOURS = {'cream': hexc('d8cfb6'), 'iron': hexc('5a5d62')}


@piece('radiator', 38, 30, 'wall', rooms={'bedroom': 2, 'living_room': 3, 'dining_room': 3, 'study': 3}, tags=('heating',), depth=1, limit=1,
       variants={k: {'col': v} for k, v in RAD_COLOURS.items()}, feet=(105, 109),
       note='a column radiator: nine rounded sections lit across their width, a header rail top and bottom, a lockshield valve and two pipes down to the boards')
def radiator(c, ox, oy, p):
    col = p['col']
    tn = K.tones(col, 5, 0.50, 1.28)
    x0, x1 = ox + 2, ox + 35
    top, base = oy - 27, oy - 4
    c.shadow((x0 + x1) // 2, oy + 1, 20, 2, 95)
    L = K.Layer(c)
    lc = L.c
    # the dark gap behind the sections where the wall shows through
    lc.rect(x0 + 2, top + 4, x1 - 2, base - 3, shade(col, 0.30))
    # nine sections, each three px wide: a lit edge, a body, a shaded edge, a rounded top
    n = 9
    sw = (x1 - x0 - 3) / float(n)
    for i in range(n):
        xa = int(round(x0 + 2 + i * sw))
        xb = xa + 2
        lc.vline(xa, top + 4, base - 3, tn[3])
        lc.vline(xa + 1, top + 4, base - 3, tn[2])
        lc.vline(xb, top + 4, base - 3, tn[1])
        lc.put(xa, top + 3, tn[4])
        lc.put(xa + 1, top + 3, tn[3])
        lc.put(xb, top + 3, tn[2])
        for yy in range(top + 8, base - 6, 5):                       # the ribs a cast-iron section has
            lc.put(xa + 1, yy, tn[1])
    # the header rails: a lit slab along the top, a lower rail above the feet
    for (ya, yb) in ((top, top + 3), (base - 3, base)):
        for y in range(ya, yb + 1):
            f = (y - ya) / float(max(1, yb - ya))
            lc.hline(x0, x1, y, tn[4] if f < 0.2 else (tn[3] if f < 0.55 else (tn[2] if f < 0.85 else tn[1])))
    lc.hline(x0 + 1, x1 - 1, top, shade(col, 1.42))
    for xx in (x0, x1):                                             # the end caps
        lc.vline(xx, top, base, tn[1] if xx == x1 else tn[4])
    # pipes down to the floor and the lockshield valve at the right-hand end
    for px in (x0 + 3, x1 - 4):
        lc.rect(px, base + 1, px + 1, oy, STEEL)
        lc.vline(px, base + 1, oy, STEEL_LT)
    lc.rect(x1 - 6, base - 1, x1 - 1, base + 1, BRASS)
    lc.hline(x1 - 6, x1 - 1, base - 1, BRASS_LT)
    lc.hline(x1 - 6, x1 - 1, base + 1, BRASS_DK)
    lc.put(x1 - 3, base - 2, hexc('8a2e26'))                          # the red cap on the valve
    lc.put(x1 - 4, base - 2, hexc('b8453a'))
    L.flush()


# ================================================================================================================================ the blanket trunk
TRUNK_PALS = {
    'oak': {'pal': (hexc('7a5a3a'), hexc('94704a'), hexc('5e4430'), hexc('2e2014')), 'band': STEEL},
    'green': {'pal': (hexc('55705a'), hexc('6b8a70'), hexc('3f5744'), hexc('233328')), 'band': hexc('3a3d40')},
    'leather': {'pal': (hexc('6b4630'), hexc('85593c'), hexc('4e3223'), hexc('2a1a10')), 'band': hexc('b09456')},
}


@piece('trunk', 40, 24, 'wall', rooms={'bedroom': 3, 'living_room': 2, 'study': 2, 'dining_room': 1}, depth=4, limit=1,
       styles={'bedsit': 5, 'adult': 2, 'kid': 2, 'sick': 1, 'squat': 4, 'lodge': 4, 'cosy': 2, 'houseshare': 3, 'den': 3, 'radio': 3, 'office': 2, 'library': 2,
               'studio': 3, 'diner': 2, 'party': 2},
       tags=('storage',), variants={k: dict(v) for k, v in TRUNK_PALS.items()}, feet=(105, 109),
       slots=({'id': 'top', 'dx0': 4, 'dx1': 35, 'dy': -23, 'top': True, 'kinds': ('small',)},),
       anchors=({'name': 'trunk', 'dx': 20, 'dy': -14},),
       note='a blanket trunk: planked front, a banded lid, corner brackets, a hasp and a brass padlock, four stub feet')
def trunk(c, ox, oy, p):
    W_, WL, WD, WO = p['pal']
    band = p['band']
    x0, x1 = ox + 1, ox + 38
    top, base = oy - 23, oy
    c.shadow((x0 + x1) // 2, base + 1, 22, 2, 100)
    # the lid: a lipped slab, lit along its front edge
    c.rect(x0 - 1, top, x1 + 1, top + 8, WO)
    c.rect(x0, top + 1, x1, top + 7, W_)
    c.hline(x0, x1, top + 1, shade(WL, 1.3))
    c.hline(x0, x1, top + 2, WL)
    c.hline(x0, x1, top + 7, WD)
    c.hline(x0 - 1, x1 + 1, top + 8, shade(WD, 0.6))
    # the body: vertical planks, alternate boards a shade apart, joints dark, a little grain
    c.rect(x0, top + 9, x1, base - 3, WO)
    k = 0
    for xx in range(x0 + 1, x1, 5):
        xe = min(xx + 3, x1 - 1)
        tone = W_ if k % 2 == 0 else shade(W_, 0.88)
        c.rect(xx, top + 9, xe, base - 3, tone)
        c.vline(xx, top + 9, base - 3, shade(tone, 1.14))
        c.vline(xe, top + 9, base - 3, shade(tone, 0.8))
        rng = random.Random(p.get('seed', 1) * 17 + k)
        for _ in range(3):
            gy = rng.randint(top + 11, base - 8)
            c.put(rng.randint(xx + 1, max(xx + 1, xe - 1)), gy, shade(tone, 0.8))
            c.put(rng.randint(xx + 1, max(xx + 1, xe - 1)), gy + 1, shade(tone, 0.8))
        k += 1
    c.hline(x0, x1, base - 3, WD)
    c.hline(x0, x1, top + 9, shade(WD, 0.7))                                                           # the shadow under the lid
    # the straps: two bands from the lid's top to the body's foot, with rivets
    for bx in (x0 + 5, x1 - 8):
        c.rect(bx, top + 1, bx + 2, base - 3, band)
        c.vline(bx, top + 1, base - 3, shade(band, 1.35))
        c.vline(bx + 2, top + 1, base - 3, shade(band, 0.7))
        for ry in (top + 3, top + 12, base - 6):
            c.put(bx + 1, ry, shade(band, 1.6))
    # corner brackets
    for cx_, sgn in ((x0, 1), (x1, -1)):
        for yy in (top + 1, base - 5):
            c.rect(cx_ if sgn > 0 else cx_ - 1, yy, cx_ + (2 if sgn > 0 else 0), yy + 3, band)
            c.put(cx_ + (1 if sgn > 0 else -1), yy + 1, shade(band, 1.6))
    # the hasp on the lid and a brass padlock hanging from it
    mx = (x0 + x1) // 2
    c.rect(mx - 1, top + 5, mx + 1, top + 12, band)
    c.vline(mx - 1, top + 5, top + 12, shade(band, 1.3))
    c.rect(mx - 2, top + 12, mx + 2, top + 16, BRASS)
    c.hline(mx - 2, mx + 2, top + 12, BRASS_LT)
    c.hline(mx - 2, mx + 2, top + 16, BRASS_DK)
    c.put(mx, top + 14, hexc('2a1c17'))
    c.put(mx - 1, top + 11, BRASS_DK)
    c.put(mx + 1, top + 11, BRASS_DK)
    # stub feet
    for fx in (x0, x1 - 3):
        c.rect(fx, base - 2, fx + 3, base, WD)
        c.hline(fx, fx + 3, base - 2, W_)
        c.hline(fx, fx + 3, base, WO)


# ================================================================================================================================ the coat stand
COATS = {'grey': hexc('5d6068'), 'green': hexc('4b5a3c'), 'mustard': hexc('a8873a'), 'navy': hexc('2f3a52')}


@piece('coat_stand', 26, 66, 'wall', rooms={'living_room': 2, 'study': 2, 'dining_room': 1, 'bedroom': 1}, depth=0, limit=1, tags=('hall',),
       variants={k: {'coat': v} for k, v in COATS.items()}, feet=(105, 109),
       note='a turned hat-and-coat stand on a splayed foot: a slim pole with two rings of pegs, a coat on one, a knitted scarf on another, a bowler on the finial')
def coat_stand(c, ox, oy, p):
    coat = p['coat']
    cx = ox + 13
    wood = hexc('5d3f2c')
    c.shadow(cx, oy + 1, 11, 2, 105)
    L = K.Layer(c)
    lc = L.c
    top = oy - 60
    # the pole, turned: a slim shaft with two collars
    K.cyl(lc, cx, top + 3, oy - 6, 1.5, wood, ry=0.7, cap=False)
    K.cyl(lc, cx, oy - 28, oy - 25, 2.2, wood, ry=0.9, cap=False)
    K.cyl(lc, cx, top + 9, top + 10, 2.2, wood, ry=0.9, cap=False)
    K.sphere(lc, cx, top + 1, 2.0, 2.0, wood)                                                           # the finial
    # the foot: a turned boss on three splayed feet, the middle one toward you
    for sgn in (-1, 1):
        for k in range(11):
            f = k / 10.0
            fx = cx + int(round(sgn * 10 * f))
            fy = oy - 6 + int(round(5 * f ** 0.8))
            lc.rect(fx - 1, fy, fx + 1, fy + 1, shade(wood, 1.12 if sgn < 0 else 0.78))
        lc.put(cx + sgn * 10, oy, shade(wood, 0.55))
    K.cyl(lc, cx, oy - 8, oy - 5, 2.6, wood, ry=1.1, cap=True)
    lc.rect(cx - 2, oy - 3, cx + 1, oy, shade(wood, 0.9))
    lc.hline(cx - 2, cx + 1, oy, shade(wood, 0.55))
    # two rings of pegs, each curling up at its tip, a brass ball on the end
    for yy in (top + 14, top + 22):
        for sgn in (-1, 1):
            for k in range(1, 6):
                lc.put(cx + sgn * (1 + k), yy - (1 if k > 3 else 0), shade(wood, 1.2 if sgn < 0 else 0.8))
            lc.put(cx + sgn * 6, yy - 2, hexc('c9a85a'))
    L.flush()
    # the coat on the right-hand peg of the lower ring: a collar over the peg, sloping shoulders, a body that widens to the hem, a darker sleeve on the near side
    yh = top + 23
    xr = cx + 7
    tn = K.tones(coat, 5, 0.46, 1.25)
    for y in range(yh, yh + 27):
        f = (y - yh) / 26.0
        half = int(round(3 + 4 * min(1.0, f * 3.0) + 1.5 * f))
        for x in range(xr - half, xr + half):
            u = (x - (xr - half)) / float(max(1, 2 * half - 1))
            t = tn[3] if u < 0.22 else (tn[2] if u < 0.7 else tn[1])
            if (x - xr - y // 4) % 6 == 0 and 0.22 < u < 0.9:
                t = tn[max(0, tn.index(t) - 1)]                                                         # a fold running down
            c.put(x, y, t)
        c.put(xr - half, y, tn[4])
        c.put(xr + half - 1, y, shade(coat, 0.34))
    c.hline(xr - 3, xr + 2, yh - 1, tn[4])                                                              # the collar standing up
    c.hline(xr - 3, xr + 2, yh, tn[3])
    for k in range(4):
        c.put(xr - 1 + (k % 2), yh + 2 + k, shade(coat, 0.34))                                          # the lapel's notch
    for by in (yh + 9, yh + 15, yh + 21):
        c.put(xr, by, hexc('d9c58a'))
    c.hline(xr - 8, xr + 8, yh + 26, shade(coat, 0.40))                                                 # the hem
    sl = xr + 5                                                                                         # the sleeve, hanging straight down the near side
    for y in range(yh + 3, yh + 22):
        c.put(sl, y, shade(coat, 0.62))
        c.put(sl + 1, y, shade(coat, 0.45))
    # a knitted scarf on the left-hand peg: two ends, diagonal stripes, a fringe
    sc, sc2 = hexc('8a2e3a'), hexc('d9cfb4')
    for y in range(yh - 1, yh + 12):
        for x in range(cx - 9, cx - 6):
            band = ((x - cx + y) // 2) % 2
            t = sc if band == 0 else sc2
            c.put(x, y, shade(t, 1.15 if x == cx - 9 else (0.95 if x == cx - 8 else 0.7)))
    for x in range(cx - 9, cx - 6):
        if x % 2:
            c.put(x, yh + 12, shade(sc2, 0.8))
    # a bowler hat on the finial: a domed crown, a hat band, a flat brim
    hat = hexc('3a3a42')
    K.sphere(c, cx, top - 1, 3.4, 3.0, hat, n=5, lo=0.55, hi=1.5)
    c.hline(cx - 3, cx + 2, top, hexc('8a2e3a'))
    c.hline(cx - 6, cx + 5, top + 1, shade(hat, 0.62))
    c.hline(cx - 5, cx + 4, top + 1, shade(hat, 1.1))
    c.hline(cx - 5, cx + 4, top + 2, shade(hat, 0.45))
