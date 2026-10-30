"""THE SMALL THINGS — everything that stands ON a surface (a lamp, a clock, a suitcase on a wardrobe, a glass of water…), redrawn with volume (owner round 47b: "everything very flat and very
basic looking, like bad, bad mspaint… better depth and detail not a flat 2D image… it's a good process, let's iterate").

Each is built with the shaded primitives in propkit.py — spheres / cylinders / cones lit by their own surface normal, a few tones per material, a specular dash on glossy things, a selective
outline and a contact shadow — so a lamp shade is a real drum with an open top and a lit inside, a bottle is round glass with liquid in it, a suitcase has binding, corners and latches.

Pieces register exactly as in furn_bedroom.py (furnlib.piece): `draw(c, ox, oy, p)` — the front-left corner at x = ox and the last row of the base at y = oy; the object rises above it.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
from furnlib import piece
from pixlib import hexc, shade, mix
import propkit as K

BRASS = hexc('b09456')
BRASS_DK = hexc('7a6430')
OUTLINE = hexc('2a1c17')


def _shadow(c, cx, cy, rx, ry=1.5, a=95):
    K.contact_shadow(c, cx, cy, rx, ry, a)


# ================================================================================================================================ the alarm clock
@piece('alarm_clock', 10, 11, 'top', rooms={'bedroom': 6}, styles={'adult': 3, 'teen': 4, 'kid': 1, 'sick': 1}, tags=('small',), on=('small',), anims=(), limit=1,
       variants={'red': {'body': 'a8322c'}, 'cream': {'body': 'd8cfb0'}, 'blue': {'body': '3f6a8a'}, 'green': {'body': '4a7a5a'}}, note='a wind-up twin-bell alarm clock')
def alarm_clock(c, ox, oy, p):
    body = hexc(p['body'])
    _shadow(c, ox + 5, oy + 0.5, 5.6)
    L = K.Layer(c)
    lc = L.c
    for lx in (ox + 2, ox + 7):                                              # the two little legs
        lc.put(lx, oy, OUTLINE)
        lc.put(lx, oy - 1, shade(BRASS_DK, 0.9))
    lc.put(ox + 4, oy - 11, hexc('9a9a9a')); lc.put(ox + 4, oy - 10, hexc('3a3a3a'))   # the striker between the bells
    K.sphere(lc, ox + 2.4, oy - 9.2, 2.2, 1.6, BRASS, gloss=True)             # the twin bells
    K.sphere(lc, ox + 7.6, oy - 9.2, 2.2, 1.6, BRASS, gloss=True)
    K.sphere(lc, ox + 5.0, oy - 4.8, 4.5, 4.5, body, gloss=True)               # the case
    K.ell(lc, ox + 5.0, oy - 4.8, 3.2, 3.2, hexc('ece4cc'))                    # the cream face
    for (dx, dy) in ((0, -3), (3, 0), (0, 3), (-3, 0)):
        lc.put(ox + 4 + dx, oy - 5 + dy, hexc('3a3a3a'))
    lc.line(ox + 4, oy - 5, ox + 4, oy - 7, hexc('222222'))                    # minute hand
    lc.line(ox + 4, oy - 5, ox + 6, oy - 4, hexc('222222'))                    # hour hand
    lc.put(ox + 4, oy - 5, hexc('a8322c'))
    lc.put(ox + 2, oy - 7, hexc('fffaf0'))                                     # glass glint
    L.flush()


# ================================================================================================================================ a pile of books
def _book(lc, x0, x1, ybot, h, col, kind, rng):
    top = ybot - h + 1
    if kind == 'spine':
        for y in range(top, ybot + 1):
            f = (y - top) / float(max(1, h - 1))
            lc.hline(x0, x1, y, shade(col, 1.12 - 0.34 * f))
        lc.hline(x0, x1, top, shade(col, 1.28))
        lc.vline(x1, top, ybot, shade(col, 0.6))
        for bx in (x0 + 2, x1 - 2):
            lc.vline(bx, top, ybot, hexc('c9a84a'))
        mid = (x0 + x1) // 2
        lc.hline(mid - 2, mid + 1, top + max(1, h // 2), hexc('e6d9a0'))
    else:
        cov = shade(col, 0.8)
        lc.hline(x0, x1, top, cov)
        lc.hline(x0, x1, ybot, shade(col, 0.55))
        for y in range(top + 1, ybot):
            lc.hline(x0 + 1, x1, y, hexc('e8e0c8') if (y - top) % 2 else hexc('d4cab0'))
        lc.vline(x0, top, ybot, cov)
        lc.vline(x1, top, ybot - 1, shade(hexc('d4cab0'), 0.8))


@piece('book_pile', 15, 12, 'top', rooms={'bedroom': 5, 'study': 6, 'living_room': 4}, tags=('small', 'books'), on=('small',),
       variants={'a': {'cols': (0, 1, 3), 'w': (14, 12, 13), 'kind': ('spine', 'pages', 'spine'), 'ribbon': True},
                 'b': {'cols': (2, 4), 'w': (13, 11), 'kind': ('pages', 'spine'), 'ribbon': False},
                 'c': {'cols': (1, 3, 0, 4), 'w': (12, 13, 11, 12), 'kind': ('spine', 'spine', 'pages', 'spine'), 'ribbon': True}}, note='a few paperbacks and a hardback in a pile')
def book_pile(c, ox, oy, p):
    rng = random.Random(len(p['cols']) * 7 + p['w'][0])
    n = len(p['cols'])
    hs = [3, 4, 3, 3][:n]
    _shadow(c, ox + 7.5, oy + 0.5, 8.5, 1.4)
    L = K.Layer(c)
    lc = L.c
    y = oy
    xs = []
    for i in range(n):
        w = p['w'][i]
        off = (14 - w) // 2 + rng.choice((-1, 0, 1, 1))
        x0 = max(ox, ox + off)
        x1 = x0 + w - 1
        _book(lc, x0, x1, y, hs[i], F.BOOKS[p['cols'][i]], p['kind'][i], rng)
        xs.append((x0, x1))
        y -= hs[i]
    # the top book's cover seen from above, with a ribbon and a worn corner
    x0, x1 = xs[-1]
    cov = F.BOOKS[p['cols'][-1]]
    topy = y
    for k in range(3):
        inset = 1 if k == 2 else 0
        lc.hline(x0 + inset, x1 - inset, topy - k, shade(cov, 1.08 + 0.05 * k))
    lc.hline(x0 + 1, x1 - 1, topy - 2, shade(cov, 1.3))
    lc.hline(x0 + 2, x0 + 5, topy - 1, hexc('e6d9a0'))                       # a title plate
    lc.put(x0 + 1, topy - 1, shade(cov, 0.7))
    if p['ribbon']:
        lc.vline(x1 - 3, topy + 1, topy + 3, hexc('b0453a'))
        lc.put(x1 - 3, topy + 4, hexc('8a2e2a'))
    L.flush()


# ================================================================================================================================ a glass of water
@piece('glass_water', 7, 9, 'top', rooms={'bedroom': 4, 'bathroom': 2, 'kitchen': 3, 'study': 1, 'living_room': 2, 'dining_room': 2}, tags=('small',), on=('small',),
       variants={'full': {'level': 0.7}, 'half': {'level': 0.4}}, note='a tumbler of water')
def glass_water(c, ox, oy, p):
    _shadow(c, ox + 3.5, oy + 0.4, 4.2, 1.2, 80)
    c.put(ox + 6, oy + 1, hexc('dcecf0'))                                    # the little bright spot the water throws on the surface
    c.put(ox + 7, oy + 1, hexc('c8dce2'))
    L = K.Layer(c)
    lc = L.c
    glass, water = hexc('c4dce2'), hexc('6fa6c0')
    K.frustum(lc, ox + 3.5, oy - 7, oy - 1, 3.4, 2.5, glass, ry_t=1.2, ry_b=1.0, n=4, lo=0.78, hi=1.2)
    lvl = int(round(6 * p['level']))
    top_w = oy - 1 - lvl
    for y in range(top_w, oy):
        f = (y - (oy - 7)) / 6.0
        r = 3.4 + (2.5 - 3.4) * f - 0.8
        for x in range(int(ox + 3.5 - r), int(ox + 3.5 + r + 0.5)):
            u = (x + 0.5 - (ox + 3.5)) / max(r, 0.5)
            lc.put(x, y, shade(water, 1.1 - 0.28 * max(0.0, u + 0.2)))
    lc.hline(ox + 1, ox + 5, top_w, hexc('b8e0ee'))                           # the surface catches the light
    lc.hline(ox + 2, ox + 4, oy, hexc('9fb8c0'))                              # the thick glass base
    lc.vline(ox + 1, oy - 6, oy - 2, hexc('f4fafc'))                          # the long highlight
    lc.put(ox + 2, oy - 6, hexc('f4fafc'))
    L.flush()


# ================================================================================================================================ a hairbrush
@piece('hairbrush', 14, 7, 'top', rooms={'bedroom': 3, 'bathroom': 3}, tags=('small', 'dressing'), on=('vanity',),
       variants={'wood': {'wood': '9a6a40'}, 'black': {'wood': '3a343a'}, 'pink': {'wood': 'c07890'}}, note='a hairbrush lying bristles up, a few hairs caught in it')
def hairbrush(c, ox, oy, p):
    wood = hexc(p['wood'])
    _shadow(c, ox + 7, oy + 0.4, 7.8, 1.3, 85)
    L = K.Layer(c)
    lc = L.c
    for x in range(ox + 9, ox + 14):                                           # the handle: a tapered rod, lit along its top, rounded at the end
        f = (x - (ox + 9)) / 4.0
        top = oy - 4 + (1 if f > 0.7 else 0)
        for y in range(top, oy - 1):
            lc.put(x, y, shade(wood, 1.32 if y == top else (0.82 if y == oy - 2 else 1.0)))
    lc.put(ox + 13, oy - 3, shade(wood, 0.7))
    K.ell(lc, ox + 5.5, oy - 2.2, 5.6, 3.0, shade(wood, 0.62))                 # the wooden back, seen edge-on under the head
    K.ell(lc, ox + 5.5, oy - 3.2, 5.6, 3.0, shade(wood, 1.18))                 # the head's pale rim
    K.ell(lc, ox + 5.5, oy - 3.2, 4.4, 2.1, hexc('2c2220'))                    # the bristle cushion
    for yy in range(oy - 5, oy - 1):
        for xx in range(ox + 2, ox + 10):
            if (xx + yy) % 2 == 0 and ((xx - 5.5 - ox) / 4.2) ** 2 + ((yy + 0.5 - (oy - 3.2)) / 1.9) ** 2 <= 1.0:
                lc.put(xx, yy, hexc('b8a488') if yy == oy - 4 else hexc('8a7860'))
    lc.line(ox + 3, oy - 3, ox + 7, oy - 5, hexc('7a4a2a'))                    # a few hairs caught in it
    lc.line(ox + 7, oy - 5, ox + 9, oy - 5, hexc('7a4a2a'))
    L.flush()


# ================================================================================================================================ a jewellery box
@piece('jewel_box', 14, 14, 'top', rooms={'bedroom': 4}, styles={'adult': 4, 'kid': 1}, tags=('small', 'dressing'), on=('vanity',),
       variants={'plum': {'wood': '5c3c50', 'velvet': 'a02a40'}, 'walnut': {'wood': '6a4a33', 'velvet': '2a5a58'}, 'ebony': {'wood': '2e2428', 'velvet': '6a3a7a'}},
       anchors=({'name': 'jewel_box', 'dx': 6, 'dy': -5},), note='a jewellery box, lid thrown back with a quilted lining and a little oval mirror, a necklace trailing over the front')
def jewel_box(c, ox, oy, p):
    wood, vel = hexc(p['wood']), hexc(p['velvet'])
    _shadow(c, ox + 7, oy + 0.5, 8, 1.4)
    L = K.Layer(c)
    lc = L.c
    # the lid thrown back behind the box: leaning away, so it narrows toward the hinge's far edge; satin quilting inside and a little oval mirror
    lc.poly([(ox + 1, oy - 7), (ox + 12, oy - 7), (ox + 11, oy - 14), (ox + 2, oy - 14)], shade(wood, 1.05))
    lc.hline(ox + 2, ox + 11, oy - 14, shade(wood, 1.45))
    sat = hexc('e6d0c4')
    lc.poly([(ox + 2, oy - 8), (ox + 11, oy - 8), (ox + 10, oy - 13), (ox + 3, oy - 13)], sat)
    for yy in range(oy - 13, oy - 7):
        for xx in range(ox + 2, ox + 12):
            if lc.px[xx, yy][3] and (xx + yy) % 4 == 0:
                lc.put(xx, yy, shade(sat, 0.9))                                   # the quilting
    K.ell(lc, ox + 6.5, oy - 10.6, 2.3, 2.7, hexc('b4c4cc'))                      # the mirror in the lid
    lc.put(ox + 5, oy - 12, hexc('f4f8fa')); lc.put(ox + 5, oy - 11, hexc('dce6e8')); lc.put(ox + 7, oy - 9, hexc('8aa0aa'))
    # the box: the opening seen from above (velvet, pearls, a ring), then the front face with its brass
    lc.poly([(ox + 1, oy - 7), (ox + 12, oy - 7), (ox + 13, oy - 4), (ox, oy - 4)], shade(vel, 0.7))
    lc.hline(ox + 2, ox + 11, oy - 6, vel)
    lc.hline(ox + 2, ox + 11, oy - 7, shade(vel, 1.25))
    for px_ in (3, 5, 7):
        lc.put(ox + px_, oy - 6, hexc('f4f0e6'))
    lc.put(ox + 10, oy - 6, BRASS)
    lc.put(ox + 10, oy - 7, hexc('d84a5a'))
    for y in range(oy - 3, oy + 1):
        f = (y - (oy - 3)) / 3.0
        lc.hline(ox, ox + 13, y, shade(wood, 1.12 - 0.4 * f))
    lc.hline(ox, ox + 13, oy - 3, BRASS)                                       # a brass rim round the lip
    lc.rect(ox + 6, oy - 2, ox + 7, oy - 1, BRASS)                             # the clasp
    lc.put(ox + 6, oy - 2, hexc('e8d080'))
    lc.put(ox, oy, BRASS_DK)
    lc.put(ox + 13, oy, BRASS_DK)                                              # brass feet
    # a necklace spilling over the front: a chain and a pendant
    for k in range(5):
        lc.put(ox + 3 + (1 if k > 2 else 0), oy - 4 + k, hexc('e0c060') if k % 2 else BRASS)
    lc.put(ox + 4, oy + 1, hexc('4a8ad0'))
    L.flush()


# ================================================================================================================================ a lava lamp
@piece('lamp_lava', 10, 18, 'top', rooms={'bedroom': 3, 'living_room': 1}, styles={'teen': 8}, tags=('light', 'lamp'), on=('lamp',), limit=1,
       variants={'purple': {'liq': '8a3a9a', 'wax': 'f0902e', 'top': 'c46ad0'}, 'blue': {'liq': '2a5a9a', 'wax': '58e0c8', 'top': '4a90d0'},
                 'green': {'liq': '2a8a4a', 'wax': 'e8e04a', 'top': '4ac870'}, 'red': {'liq': '9a2a2a', 'wax': 'f0a83a', 'top': 'd84a3a'}},
       lights=({'dx': 5, 'dy': -9, 'kind': 'lava', 'top': True},),
       anims=tuple({'kind': 'lava', 'dx': 2, 'dy': -15, 'w': 6, 'h': 10, 'color': wax, 'top': True, 'if': {'wax': wax}} for wax in ('f0902e', '58e0c8', 'e8e04a', 'f0a83a')),
       note='a lava lamp — a tapered glass on a chrome base; the wax in it is a LIVE detail (module_anim `lava`): blobs rising, stretching and sinking on their own slow tides')
def lamp_lava(c, ox, oy, p):
    liq, wax, topc = hexc(p['liq']), hexc(p['wax']), hexc(p['top'])
    chrome = hexc('aab0b6')
    _shadow(c, ox + 5, oy + 0.5, 6.5, 1.4)
    L = K.Layer(c)
    lc = L.c
    cx = ox + 5.0
    K.frustum(lc, cx, oy - 5, oy - 1, 2.6, 4.4, chrome, ry_t=0.9, ry_b=1.3, gloss=True, lo=0.45, hi=1.35)          # the base, chrome
    lc.hline(ox + 1, ox + 8, oy - 1, shade(chrome, 0.55))
    # the glass: a tapered cylinder full of glowing liquid, brighter than a lit object (it IS a light)
    K.frustum(lc, cx, oy - 16, oy - 6, 1.7, 3.0, liq, ry_t=0.7, ry_b=0.8, n=5, lo=0.62, hi=1.18, inner=shade(liq, 1.25), rim=shade(liq, 1.1))
    for y in range(oy - 15, oy - 5):                                          # the liquid is cooler at the top, deeper at the bottom where the bulb sits
        f = (y - (oy - 16)) / 10.0
        r = 1.7 + (3.0 - 1.7) * f
        for x in range(int(cx - r) + 1, int(cx + r + 0.5)):
            u = (x + 0.5 - cx) / r
            if u > -0.3:
                lc.put(x, y, mix(shade(liq, 0.75 - 0.25 * max(0.0, u)), topc, 0.55 * (1.0 - f)))
    # the wax is NOT drawn here: it moves (owner round 49f, "let's make the lava lamp actually have animation") — module_anim.gd `lava` draws three blobs and a pool in this glass
    lc.vline(ox + 2, oy - 14, oy - 8, shade(liq, 1.7))                         # the glass's highlight
    # the metal cap
    K.frustum(lc, cx, oy - 19, oy - 16, 0.8, 1.9, chrome, ry_t=0.5, ry_b=0.8, gloss=True)
    L.flush()


# ================================================================================================================================ a table lamp
LAMP_SHADES = {'cream': hexc('e6dcc0'), 'rose': hexc('cc8890'), 'green': hexc('86a674'), 'mustard': hexc('cfa84a')}
LAMP_BASES = {'blue': ('vase', '5a7ea8'), 'jade': ('vase', '6a9a82'), 'cream': ('vase', 'd8cfb8'), 'brass': ('column', 'b09456'), 'oxblood': ('vase', '8a3a38'),
              'black': ('column', '34343a'), 'walnut': ('drum', '6a4a33')}


def _lamp_variants():
    v = {}
    for sh in LAMP_SHADES:
        for bs in ('blue', 'cream', 'brass', 'oxblood', 'walnut'):
            v['%s_%s' % (sh, bs)] = {'shade': sh, 'base': bs}
    return v


@piece('lamp_table', 13, 20, 'top', rooms={'bedroom': 6, 'living_room': 5, 'study': 3, 'dining_room': 2}, styles=None, tags=('light', 'lamp'), on=('lamp',),
       variants=_lamp_variants(), lights=({'dx': 6, 'dy': -13, 'kind': 'table', 'top': True},), note='a table lamp: a glazed or brass base under a drum shade, its inside glowing')
def lamp_table(c, ox, oy, p):
    kind, bcol = LAMP_BASES[p['base']]
    base = hexc(bcol)
    shd = LAMP_SHADES[p['shade']]
    cx = ox + 6.5
    _shadow(c, cx, oy + 0.5, 6, 1.4)
    L = K.Layer(c)
    lc = L.c
    if kind == 'vase':                                                         # a swelling ceramic base: foot, belly, neck
        K.cyl(lc, cx, oy - 2, oy - 1, 2.4, shade(base, 0.8), ry=0.9)
        K.sphere(lc, cx, oy - 5.2, 3.3, 3.5, base, gloss=True)
        K.cyl(lc, cx, oy - 10, oy - 8, 1.0, shade(base, 0.9), ry=0.5)
    elif kind == 'column':                                                     # a brass / black column on a round foot with a ball node
        K.cyl(lc, cx, oy - 2, oy - 1, 3.0, base, ry=1.1, gloss=True)
        K.cyl(lc, cx, oy - 9, oy - 3, 0.9, shade(base, 1.0), ry=0.4, gloss=True)
        K.sphere(lc, cx, oy - 6.0, 1.8, 1.8, base, gloss=True)
    else:                                                                      # a squat turned-wood drum
        K.cyl(lc, cx, oy - 7, oy - 1, 3.2, base, ry=1.3, gloss=False)
        for yy in (oy - 5, oy - 3):
            lc.hline(int(cx - 3), int(cx + 2), yy, shade(base, 0.7))
        K.cyl(lc, cx, oy - 10, oy - 8, 0.9, shade(base, 0.9), ry=0.4)
    # the drum shade: open at the top so we see the warm inside, a trim band at the bottom
    inner = mix(shd, hexc('fff0b8'), 0.65)
    K.frustum(lc, cx, oy - 17, oy - 11, 4.4, 6.1, shd, ry_t=2.0, ry_b=2.0, inner=inner, rim=shade(shd, 0.86), band=(shade(shd, 0.78), 1), n=5, lo=0.62, hi=1.22)
    lc.put(int(cx + 2), oy - 15, shade(shd, 0.72))                              # the seam
    lc.put(int(cx + 2), oy - 14, shade(shd, 0.72))
    lc.put(int(cx), oy - 21, BRASS)                                             # a brass finial above the harp
    lc.put(int(cx), oy - 20, hexc('f8e8a8')); lc.put(int(cx + 1), oy - 20, hexc('f8e8a8'))   # the bulb's glow in the open top
    L.flush()


# ================================================================================================================================ perfume bottles on a tray
@piece('perfume_set', 13, 12, 'top', rooms={'bedroom': 4, 'bathroom': 3}, styles={'adult': 3, 'kid': 1}, tags=('small', 'dressing'), on=('vanity',),
       variants={'rose': {'a': 'd8909e', 'b': '6a9ab8'}, 'amber': {'a': 'd8a050', 'b': '8a5aa8'}, 'jade': {'a': '7ac0a0', 'b': 'd8909e'}}, note='perfume bottles on a little gilt tray')
def perfume_set(c, ox, oy, p):
    a, b = hexc(p['a']), hexc(p['b'])
    _shadow(c, ox + 6.5, oy + 0.4, 7.5, 1.4)
    L = K.Layer(c)
    lc = L.c
    K.cyl(lc, ox + 6.5, oy - 1, oy - 0, 6.4, BRASS, ry=1.5, gloss=True, inner=shade(BRASS, 0.85))                 # the tray (a shallow dish)
    # the tall faceted bottle with its atomiser bulb and tassel
    K.cyl(lc, ox + 4.0, oy - 8, oy - 2, 2.2, a, ry=0.9, gloss=True, n=4, lo=0.66, hi=1.42, cap_col=shade(a, 1.3))
    lc.hline(ox + 3, ox + 4, oy - 4, shade(a, 1.55))                                                              # the liquid line
    K.cyl(lc, ox + 4.0, oy - 10, oy - 9, 1.0, BRASS, ry=0.4, gloss=True)
    K.sphere(lc, ox + 1.4, oy - 9.4, 1.3, 1.3, shade(a, 1.15), gloss=True)
    lc.vline(ox + 1, oy - 8, oy - 6, BRASS)
    lc.put(ox + 1, oy - 5, hexc('b0453a'))                                                                         # the tassel
    # the round bottle with its cut-glass stopper
    K.sphere(lc, ox + 9.4, oy - 4.4, 3.0, 3.0, b, gloss=True, n=5, lo=0.6, hi=1.45)
    K.cyl(lc, ox + 9.4, oy - 8, oy - 7, 1.0, shade(b, 0.8), ry=0.4)
    K.sphere(lc, ox + 9.4, oy - 9.3, 1.3, 1.3, hexc('e8f2f6'), gloss=True)
    L.flush()


# ================================================================================================================================ a small framed photograph
FRAMES = {'wood': hexc('7a5434'), 'brass': hexc('b8994e'), 'white': hexc('e0dacb'), 'black': hexc('33302e')}


@piece('photo_small', 11, 14, 'top', rooms={'bedroom': 4, 'living_room': 4, 'study': 2, 'dining_room': 1}, styles={'adult': 4, 'sick': 2, 'kid': 1}, tags=('small', 'picture'), on=('small',),
       variants={'wood_sky': {'fr': 'wood', 'bg': '9ac0d8', 'warm': False}, 'brass_warm': {'fr': 'brass', 'bg': 'd8b080', 'warm': True},
                 'white_sky': {'fr': 'white', 'bg': 'a8c8dc', 'warm': False}, 'black_warm': {'fr': 'black', 'bg': 'c8a878', 'warm': True}},
       note='a framed photograph standing on a surface: two people and a child in front of the sea')
def photo_small(c, ox, oy, p):
    fr = FRAMES[p['fr']]
    _shadow(c, ox + 5.5, oy + 0.4, 6.5, 1.3, 85)
    L = K.Layer(c)
    lc = L.c
    # the frame: a bevelled moulding, lit top and left, shaded bottom and right
    lc.rect(ox, oy - 13, ox + 10, oy - 1, fr)
    lc.hline(ox, ox + 10, oy - 13, shade(fr, 1.35))
    lc.vline(ox, oy - 13, oy - 1, shade(fr, 1.18))
    lc.hline(ox, ox + 10, oy - 1, shade(fr, 0.62))
    lc.vline(ox + 10, oy - 13, oy - 1, shade(fr, 0.7))
    lc.rect(ox + 2, oy - 11, ox + 8, oy - 3, hexc('ece4d0'))                  # the mat
    lc.rect(ox + 3, oy - 10, ox + 7, oy - 4, hexc(p['bg']))                   # the picture: sky (or sunset), sand
    lc.hline(ox + 3, ox + 7, oy - 5, hexc('c9b48a'))
    lc.hline(ox + 3, ox + 7, oy - 4, shade(hexc('c9b48a'), 0.85))
    lc.hline(ox + 3, ox + 7, oy - 8, shade(hexc(p['bg']), 1.12))
    skin = hexc('e0b898')
    lc.put(ox + 4, oy - 8, skin); lc.put(ox + 6, oy - 8, skin); lc.put(ox + 5, oy - 7, skin)           # heads
    lc.put(ox + 4, oy - 7, hexc('4a3424')); lc.put(ox + 6, oy - 7, hexc('d8c070') if p['warm'] else hexc('2a2a2e'))
    lc.rect(ox + 3, oy - 6, ox + 4, oy - 5, hexc('b0453a'))
    lc.rect(ox + 6, oy - 6, ox + 7, oy - 5, hexc('3a5a8a'))
    lc.put(ox + 5, oy - 5, hexc('e0c060'))
    lc.put(ox + 3, oy - 10, hexc('f6f2e6')); lc.put(ox + 4, oy - 10, hexc('d8e4e8'))                      # the glass's glint
    L.flush()


# ================================================================================================================================ tablets
@piece('pill_bottles', 17, 10, 'top', rooms={'bedroom': 4, 'bathroom': 6}, styles={'adult': 2, 'sick': 6}, tags=('small', 'medical'), on=('small',),
       variants={'a': {'amber': 'c2701e'}, 'b': {'amber': '9a6428'}}, note='an amber pill bottle with a label and a white cap, one lying on its side, a few tablets spilled beside it (ON the surface: no pixel below the feet row, so the bottle never overhangs a thin desktop)')
def pill_bottles(c, ox, oy, p):
    amber = hexc(p['amber'])
    _shadow(c, ox + 7, oy + 0.5, 8, 1.4)
    L = K.Layer(c)
    lc = L.c
    # the one lying down: a horizontal cylinder, cap to the right
    for y in range(oy - 4, oy):
        f = (y - (oy - 4)) / 3.0
        lc.hline(ox + 6, ox + 11, y, shade(amber, 1.28 - 0.62 * f))
    lc.hline(ox + 6, ox + 11, oy - 4, shade(amber, 1.5))
    lc.rect(ox + 12, oy - 3, ox + 13, oy - 1, hexc('ece8dc'))
    lc.put(ox + 12, oy - 3, hexc('fffcf0'))
    lc.rect(ox + 7, oy - 3, ox + 9, oy - 1, hexc('ece6d6'))                                                           # its label
    lc.hline(ox + 7, ox + 9, oy - 3, hexc('b0453a'))
    # the standing bottle: round amber glass, a label, a ridged white child-proof cap
    K.cyl(lc, ox + 3.5, oy - 8, oy - 1, 2.8, amber, ry=1.0, gloss=True, n=5, lo=0.55, hi=1.4, cap=False)
    lc.rect(ox + 1, oy - 6, ox + 5, oy - 3, hexc('ece6d6'))
    lc.hline(ox + 1, ox + 5, oy - 6, hexc('b0453a'))
    lc.hline(ox + 2, ox + 4, oy - 4, hexc('7a7468'))
    lc.vline(ox + 5, oy - 6, oy - 3, hexc('c4bca8'))
    K.cyl(lc, ox + 3.5, oy - 10, oy - 8, 2.4, hexc('ece8dc'), ry=1.0, gloss=True, n=4, lo=0.72, hi=1.2, cap_col=hexc('f8f4ea'))
    for rx in (ox + 2, ox + 4):
        lc.put(rx, oy - 8, hexc('b8b4a4'))
    for (tx, ty, col) in ((14, -1, 'f4f0e8'), (16, -1, 'e8a8a0'), (15, -2, 'f4f0e8')):                                 # spilled tablets, beside the bottles on the same row they stand on
        lc.put(ox + tx, oy + ty, hexc(col))
    L.flush()


# ================================================================================================================================ a suitcase
CASES = {'tan': {'a': 'a47a4a', 'trim': 'c9a46a', 'metal': 'b8a050', 'kind': 'leather'}, 'blue': {'a': '4c6a8c', 'trim': '7a94b4', 'metal': 'b8bcc0', 'kind': 'hard'},
         'brown': {'a': '6a4630', 'trim': '8a6644', 'metal': 'b09456', 'kind': 'leather'}, 'green': {'a': '4c6a50', 'trim': '78946c', 'metal': 'b09456', 'kind': 'hard'}}


@piece('suitcase', 26, 14, 'top', rooms={'bedroom': 5, 'living_room': 1}, styles={'adult': 4, 'teen': 1, 'bedsit': 3}, tags=('storage',), on=('big',),
       variants={k + ('_stickered' if s else ''): dict(v, stickers=s) for k, v in CASES.items() for s in (False, True)},
       note='a suitcase lying on top of a wardrobe: binding, brass corners and latches, a leather handle; some are covered in travel stickers (scenery — a node up there could not be reached)')
def suitcase(c, ox, oy, p):
    a, trim, metal = hexc(p['a']), hexc(p['trim']), hexc(p['metal'])
    x0, x1 = ox + 1, ox + 24
    _shadow(c, (x0 + x1) / 2.0 + 0.5, oy + 0.5, 14, 1.8, 100)
    L = K.Layer(c)
    lc = L.c
    top_y0, top_y1 = oy - 8, oy - 13                                           # the lid seen from a little above
    for k in range(6):
        i = 1 if k >= 4 else 0
        lc.hline(x0 + i, x1 - i, top_y0 - k, shade(a, 1.18 - 0.02 * k))
    lc.hline(x0 + 1, x1 - 1, top_y1, shade(a, 1.38))                           # the back edge catches the light
    lc.hline(x0, x1, top_y0, trim)                                             # the binding round the lid's front edge
    for y in range(top_y0 + 1, oy + 1):                                        # the front face, darker toward the base
        f = (y - top_y0) / float(oy - top_y0)
        lc.hline(x0, x1, y, shade(a, 1.0 - 0.28 * f))
    lc.hline(x0, x1, oy - 3, shade(trim, 0.75))                                # the seam where the lid meets the case
    lc.hline(x0, x1, oy - 2, shade(a, 0.62))
    lc.hline(x0, x1, oy, shade(a, 0.5))
    lc.vline(x0, top_y0, oy, shade(a, 1.2))
    lc.vline(x1, top_y0, oy, shade(a, 0.62))
    if p['kind'] == 'hard':
        for gx in range(x0 + 4, x1 - 2, 4):                                    # a hard case's ribs
            lc.vline(gx, top_y0 + 1, oy - 4, shade(a, 0.82))
    # the handle on the lid: a leather loop with its two studs
    lc.rect(ox + 10, top_y0 - 4, ox + 15, top_y0 - 3, hexc('4a3020'))
    lc.hline(ox + 10, ox + 15, top_y0 - 4, hexc('7a5a40'))
    lc.put(ox + 9, top_y0 - 3, metal); lc.put(ox + 16, top_y0 - 3, metal)
    # latches: a brass plate and a keyhole either side, brass corners front and back
    for lx in (ox + 5, ox + 19):
        lc.rect(lx, top_y0 + 1, lx + 2, top_y0 + 4, metal)
        lc.hline(lx, lx + 2, top_y0 + 1, shade(metal, 1.35))
        lc.put(lx + 1, top_y0 + 3, hexc('2a1c17'))
    for (cx_, cy_) in ((x0, oy - 1), (x1 - 1, oy - 1), (x0, top_y0 + 1), (x1 - 1, top_y0 + 1)):
        lc.rect(cx_, cy_, cx_ + 1, cy_ + 1, metal)
        lc.put(cx_, cy_, shade(metal, 1.35))
    if p['stickers']:                                                           # travel stickers: a red disc, a yellow flag, a blue label
        lc.rect(ox + 9, top_y0 + 2, ox + 12, top_y0 + 4, hexc('c4432e'))
        lc.put(ox + 10, top_y0 + 3, hexc('f0e8d0'))
        lc.rect(ox + 13, top_y0 + 1, ox + 15, top_y0 + 3, hexc('e0c040'))
        lc.hline(ox + 13, ox + 15, top_y0 + 2, hexc('3a6a9a'))
        lc.rect(ox + 12, top_y0 + 4, ox + 14, top_y0 + 5, hexc('3a7a9a'))
    L.flush()
