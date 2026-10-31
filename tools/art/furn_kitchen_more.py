"""MORE KITCHEN (owner, 2026-10-31: "take another pass at more of the 2D furniture art, this time focus more on kitchens… more art and decoration to really fill out those empty spaces").

What the planned kitchens lacked, measured on contact sheets of the five styles: nothing over the cooker, a run made only of cupboards, bare wall between the wall cupboards and the end of the
room, nothing on the floor that a home does with the room (washing is dried in the warm kitchen), and two tables with no seat at all. Everything here is drawn with volume, like the rest of the
kitchen (props3d / propkit: lit upper-left, a shaded side, a contact shadow), and every piece obeys the home logic (a kind in home_kinds.py, a `keep` on the floor):

    hood_extractor   decor   hangs dead-centre over a freestanding cooker (`snap`), steel / white / black, a chimney or a slim glass slab
    washer_unit      wall    a front-loader built into the run, under the worktop of its kitchen's finish
    pan_rail         decor   a steel rail with S-hooks: a frying pan, a saucepan, a ladle, a spatula, a colander
    plate_rack       decor   a wooden plate rack with plates standing on edge and two mugs hung under it
    airer_laundry    floor   a clothes horse with the washing on it

The camping table and the trestle table (furn_kitchen.table_kitchen) gain a seat each — a folding chair, a mismatched wooden one.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furnlib as FL
import propkit as K
from furnlib import piece
from pixlib import hexc, shade, mix
from furn_kitchen import FIN, _fin, _carcass, _slab, _handle, INTERIOR, STEEL, STEEL_DK, STEEL_LT

OUT = hexc('2a1c17')


def _disc(c, cx, cy, r, fn):
    """Fill a disc, asking `fn(x, y, d)` (d = distance from the centre in radii, 0..1) for every pixel's colour."""
    for y in range(int(math.floor(cy - r)), int(math.ceil(cy + r)) + 1):
        for x in range(int(math.floor(cx - r)), int(math.ceil(cx + r)) + 1):
            d = math.hypot(x - cx, y - cy) / float(r)
            if d <= 1.0:
                col = fn(x, y, d)
                if col is not None:
                    c.put(x, y, col)


def _ring(c, cx, cy, r, col):
    for a in range(0, 360, 6):
        c.put(int(round(cx + r * math.cos(math.radians(a)))), int(round(cy + r * math.sin(math.radians(a)))), col)


# ================================================================================================================================ the extractor hood
HOODS = {
    'steel_chimney': dict(col='aeb6b9', kind='chimney', glow='f2dc9a', for_=['classic', 'retro', 'student', 'hoarder']),
    'white_chimney': dict(col='e6e3d8', kind='chimney', glow='f2dc9a', for_=['classic', 'retro', 'hoarder']),
    'black_chimney': dict(col='3c3e42', kind='chimney', glow='f2dc9a', for_=['student', 'classic']),
    'black_slim': dict(col='2c2e32', kind='slim', glow='f2dc9a', for_=['student', 'retro']),
    'cream_slim': dict(col='d4ccb4', kind='slim', glow='f2dc9a', for_=['hoarder', 'classic', 'retro']),
}


def _hood_variants():
    return {k: {'col': v['col'], 'kind': v['kind'], 'glow': v['glow'], 'for': v['for_']} for k, v in HOODS.items()}


@piece('hood_extractor', 28, 41, 'decor', rooms={'kitchen': 7}, styles={'classic': 2, 'retro': 2, 'student': 2, 'hoarder': 1, 'country': 0}, tags=('hood', 'unit_above'),
       variants=_hood_variants(), wall_y=(10, 12), limit=1, above=('hob',), must_above=True, snap=True,
       note='an extractor hood hung dead-centre over a freestanding cooker: a brushed-steel / white / black chimney hood (flue to the ceiling, a canopy with a grille and a warm lamp) or a slim glass slab')
def hood_extractor(c, ox, oy, p):
    col = hexc(p['col'])
    glow = hexc(p['glow'])
    x0, x1 = ox, ox + 27
    steel = p['col'] == 'aeb6b9'
    lo, hi = shade(col, 0.66), shade(col, 1.22)
    if p['kind'] == 'chimney':
        fx0, fx1 = ox + 8, ox + 19                                                             # the flue, up to the ceiling
        for x in range(fx0, fx1 + 1):
            u = (x - fx0) / float(fx1 - fx0)
            t = shade(col, 1.2 - 0.62 * u)
            if steel:
                t = shade(t, 1.0 + 0.07 * (((x * 7) % 5) - 2) / 2.0)                              # the brushing: faint vertical streaks
            c.vline(x, oy, oy + 27, t)
        c.vline(fx0, oy, oy + 27, shade(col, 1.38))
        c.vline(fx1, oy, oy + 27, shade(col, 0.5))
        c.hline(fx0, fx1, oy + 1, shade(col, 0.8))                                              # the collar where the flue meets the ceiling
        # ---- the canopy: a trapezoid, narrow at the flue and the full width at the lip, its face lit from the upper left
        top, bot = oy + 25, oy + 36
        for y in range(top, bot + 1):
            f = (y - top) / float(bot - top)
            a = int(round(fx0 - 3 - (fx0 - 3 - x0) * f))
            b = int(round(fx1 + 3 + (x1 - fx1 - 3) * f))
            for x in range(a, b + 1):
                u = (x - a) / float(max(1, b - a))
                t = shade(col, 1.18 - 0.5 * u - 0.1 * f)
                if steel:
                    t = shade(t, 1.0 + 0.06 * (((x * 5 + y) % 4) - 1.5) / 1.5)
                c.put(x, y, t)
            c.put(a, y, hi)
            c.put(b, y, lo)
        c.hline(fx0 - 3, fx1 + 3, top, shade(col, 1.35))                                          # the shoulder, where the canopy turns up into the flue
        # ---- the lip, the grille under it and the lamp
        c.rect(x0, oy + 37, x1, oy + 38, shade(col, 0.72))
        c.hline(x0, x1, oy + 37, hi)
        c.rect(x0 + 1, oy + 39, x1 - 1, oy + 40, hexc('26282a'))                                   # the grille: a dark band with slots
        for gx in range(x0 + 3, x1 - 2, 3):
            c.put(gx, oy + 39, hexc('5a5e62'))
        c.rect(x0 + 4, oy + 39, x0 + 6, oy + 40, glow)                                               # the lamp, warm under the left shoulder
        c.rect(x1 - 6, oy + 39, x1 - 4, oy + 40, shade(glow, 0.8))
        for k, bx in enumerate((ox + 10, ox + 14, ox + 18)):                                         # the buttons on the canopy's face
            c.put(bx, oy + 32, hexc('26282a') if k else hexc('c8483a'))
    else:                                                                                          # slim: a short black flue and a flat glass slab
        fx0, fx1 = ox + 9, ox + 18
        for x in range(fx0, fx1 + 1):
            u = (x - fx0) / float(fx1 - fx0)
            c.vline(x, oy, oy + 29, shade(col, 1.15 - 0.55 * u))
        c.vline(fx0, oy, oy + 29, shade(col, 1.35))
        sl0, sl1 = oy + 29, oy + 38
        c.rect(x0, sl0, x1, sl1, shade(col, 0.55))                                                  # the slab's outline / steel trim
        for y in range(sl0 + 1, sl1):
            f = (y - sl0) / float(sl1 - sl0)
            for x in range(x0 + 1, x1):
                u = (x - x0) / float(x1 - x0)
                c.put(x, y, shade(col, 0.78 + 0.16 * (1 - f) - 0.12 * u))
        c.hline(x0, x1, sl0, hexc('b4bcc0') if p['col'] == '2c2e32' else shade(col, 1.3))
        for k in range(5):                                                                          # a slanting reflection across the glass
            c.put(x0 + 6 + k * 2, sl0 + 2 + k, shade(col, 1.6))
        c.rect(x0 + 2, sl1 - 2, x1 - 2, sl1 - 1, hexc('26282a'))
        for gx in range(x0 + 4, x1 - 3, 3):
            c.put(gx, sl1 - 2, hexc('5a5e62'))
        c.rect(x0 + 5, sl1 + 1, x0 + 7, sl1 + 2, glow)
        c.rect(x1 - 7, sl1 + 1, x1 - 5, sl1 + 2, shade(glow, 0.8))
        for bx in (ox + 11, ox + 14, ox + 17):
            c.put(bx, sl0 + 4, hexc('26282a'))
    # the wall behind it takes a little shadow under the hood
    for k, a in enumerate((90, 60, 34)):
        c.shadow(ox + 14, oy + 43 + k, 12 - k * 2, 1, a)


# ================================================================================================================================ the washing machine in the run
def _washer_variants():
    v = {}
    for fname, fin in FIN.items():
        v[fname] = {'fin': fname, 'body': 'dcd5bf' if fname in ('cream',) else 'e8e8e4', 'for': [fin['style']]}
    return v


@piece('washer_unit', 30, 32, 'wall', rooms={'kitchen': 2}, styles={'student': 4, 'classic': 2, 'retro': 2, 'hoarder': 3, 'country': 1}, tags=('unit', 'laundry'), depth=4,
       variants=_washer_variants(), limit=1, feet=(106, 106),
       slots=({'id': 'top', 'dx0': 3, 'dx1': 27, 'dy': -31, 'top': True, 'kinds': ('worktop', 'appliance')},),
       note='a front-loading washing machine built into the run under the worktop of its kitchen: a detergent drawer and a dial over a chrome-ringed porthole with a wash behind the glass')
def washer_unit(c, ox, oy, p):
    fin = _fin(p['fin'])
    body = hexc(p['body'])
    x0, x1, top, base = ox, ox + 29, oy - 31, oy
    c.shadow((x0 + x1) // 2, base + 1, 16, 2, 100)
    _carcass(c, x0, x1, top, base, fin)
    # the machine's front fills the unit: white enamel, lit on the left, shaded on the right, a seam all round
    fx0, fx1, fy0, fy1 = x0 + 1, x1 - 1, top + 4, base - 4
    for x in range(fx0, fx1 + 1):
        u = (x - fx0) / float(fx1 - fx0)
        c.vline(x, fy0, fy1, shade(body, 1.08 - 0.2 * u))
    c.vline(fx0, fy0, fy1, shade(body, 1.2))
    c.vline(fx1, fy0, fy1, shade(body, 0.7))
    c.hline(fx0, fx1, fy1, shade(body, 0.62))
    c.hline(fx0, fx1, fy0 + 7, shade(body, 0.7))                                                    # the seam under the control panel
    c.rect(fx0 + 2, fy0 + 2, fx0 + 10, fy0 + 5, shade(body, 0.62))                                    # the detergent drawer: a dark slot with its handle
    c.hline(fx0 + 3, fx0 + 9, fy0 + 3, shade(body, 1.2))
    c.hline(fx0 + 3, fx0 + 9, fy0 + 5, shade(body, 0.45))
    _disc(c, fx1 - 6, fy0 + 4, 3, lambda x, y, d: shade(hexc('9aa0a4'), 1.25 - 0.55 * d - (0.2 if x > fx1 - 6 else 0)))    # the programme dial
    c.line(fx1 - 6, fy0 + 4, fx1 - 6, fy0 + 2, hexc('2a2622'))
    c.put(fx1 - 11, fy0 + 3, hexc('4ac06a'))                                                       # a lit LED
    # the porthole: a chrome ring, the rubber gasket, the glass with a wash in it and a reflection
    cx, cy, r = (fx0 + fx1) // 2 + 0.5, fy0 + 17, 9
    _disc(c, cx, cy, r, lambda x, y, d: shade(hexc('b8c0c4'), 1.3 - 0.75 * d - (0.2 if (x > cx and y > cy) else 0)))
    _disc(c, cx, cy, r - 2, lambda x, y, d: shade(hexc('3a3e42'), 1.0 + 0.3 * (1 - d) - (0.2 if x > cx else 0)))
    for k, (dx, dy, cc) in enumerate(((-2, 3, '5a7ab0'), (1, 4, 'e8e4d8'), (3, 2, '4a6aa0'), (-3, 5, 'd8d0c0'), (0, 1, '6a8ac0'))):      # the washing, swirling in the water
        _disc(c, cx + dx, cy + dy, 2, lambda x, y, d, cc=cc: shade(hexc(cc), 1.15 - 0.4 * d))
    _disc(c, cx, cy + 3, 5, lambda x, y, d: None if d < 0.72 else shade(hexc('4a6a90'), 0.8))      # the water's edge
    for k in range(4):                                                                              # a slanting glint on the glass
        c.put(int(cx) - 4 + k, int(cy) - 4 + k, hexc('d4e4f0'))
    _ring(c, cx, cy, r - 2, hexc('1e2124'))
    c.put(fx1 - 3, fy0 + 17, hexc('7a8084'))                                                         # the door's hinge
    _slab(c, x0, x1, top, fin)


# ================================================================================================================================ a pan rail
PANS = {
    'steel': dict(pan='8e969a', hand='3a2a1c', rim='c4cacc', in_='5a6064', for_=['classic', 'retro', 'student', 'hoarder', 'country']),
    'copper': dict(pan='b8683a', hand='2a2622', rim='e09a60', in_='7a4426', for_=['country', 'classic', 'retro']),
    'iron': dict(pan='3c3d40', hand='3c3d40', rim='6a6c70', in_='26272a', for_=['student', 'hoarder', 'classic']),
}


@piece('pan_rail', 34, 30, 'decor', rooms={'kitchen': 7}, styles=None, tags=('storage', 'rail'), variants={k: {'p': k, 'for': v['for_']} for k, v in PANS.items()}, wall_y=(18, 26), limit=1,
       above=('unit',), must_above=True,
       note='a steel rail on two wall plates with S-hooks: a frying pan, a saucepan, a ladle, a spatula and a colander hanging over the worktop')
def pan_rail(c, ox, oy, p):
    pp = PANS[p['p']]
    pan, hand, rim, inn = (hexc(pp[k]) for k in ('pan', 'hand', 'rim', 'in_'))
    x0, x1 = ox, ox + 33
    for bx in (x0, x1 - 1):                                                                          # the wall plates
        c.rect(bx, oy, bx + 1, oy + 3, STEEL_DK)
        c.put(bx, oy, STEEL_LT)
    c.hline(x0 + 1, x1 - 1, oy + 1, STEEL_LT)                                                        # the rail: lit above, shaded below
    c.hline(x0 + 1, x1 - 1, oy + 2, STEEL)
    c.hline(x0 + 1, x1 - 1, oy + 3, STEEL_DK)
    c.shadow((x0 + x1) // 2, oy + 25, 14, 1, 40)                                                     # the wall behind takes their shadow
    # ---- the frying pan: a handle from a hook, then the pan face-on with a lit rim and a darker inside
    def hook(x, y0, y1):
        c.vline(x, y0, y1, STEEL)
        c.put(x, y0 - 1, STEEL_LT)
    hook(x0 + 5, oy + 4, oy + 8)
    c.vline(x0 + 5, oy + 8, oy + 12, hand); c.vline(x0 + 6, oy + 8, oy + 12, shade(hand, 1.5))
    _disc(c, x0 + 5.5, oy + 19, 7, lambda x, y, d: rim if d > 0.82 else shade(inn, 1.0 + 0.45 * (1 - d) - (0.18 if (x > x0 + 5 and y > oy + 19) else 0)))
    _disc(c, x0 + 5.5, oy + 19, 7, lambda x, y, d: None if d <= 0.82 else shade(pan, 0.85 + 0.45 * (1.0 - (x - x0) / 12.0)))
    c.put(x0 + 3, oy + 16, shade(rim, 1.3))
    # ---- the saucepan, smaller, with its handle out to one side
    hook(x0 + 16, oy + 4, oy + 7)
    c.vline(x0 + 16, oy + 7, oy + 10, hand)
    _disc(c, x0 + 16.5, oy + 15, 5, lambda x, y, d: rim if d > 0.8 else shade(inn, 1.0 + 0.4 * (1 - d) - (0.16 if x > x0 + 16 else 0)))
    _disc(c, x0 + 16.5, oy + 15, 5, lambda x, y, d: None if d <= 0.8 else shade(pan, 0.8 + 0.5 * (1.0 - (x - x0 - 11) / 10.0)))
    c.hline(x0 + 21, x0 + 25, oy + 15, hand); c.hline(x0 + 21, x0 + 25, oy + 16, shade(hand, 1.4))   # the pan's own handle, off to the right
    # ---- a ladle and a spatula, hung by their holes
    hook(x0 + 25, oy + 4, oy + 7)
    c.vline(x0 + 25, oy + 7, oy + 19, STEEL); c.vline(x0 + 26, oy + 7, oy + 19, STEEL_DK)
    _disc(c, x0 + 25.5, oy + 21, 2.6, lambda x, y, d: shade(STEEL, 1.35 - 0.8 * d - (0.2 if x > x0 + 25 else 0)))
    hook(x0 + 29, oy + 4, oy + 7)
    c.vline(x0 + 29, oy + 7, oy + 16, hexc('8a6a3c')); c.vline(x0 + 30, oy + 7, oy + 16, hexc('5a4226'))
    c.rect(x0 + 28, oy + 17, x0 + 31, oy + 22, shade(pan, 0.9))
    c.hline(x0 + 28, x0 + 31, oy + 17, shade(pan, 1.3))
    c.vline(x0 + 29, oy + 19, oy + 21, shade(pan, 0.5)); c.vline(x0 + 30, oy + 19, oy + 21, shade(pan, 0.5))   # the slots in the spatula
    c.vline(x0 + 31, oy + 17, oy + 22, shade(pan, 0.6))


# ================================================================================================================================ a plate rack
RACKS = {
    'blue': dict(rim='3f6a9a', wood='b08a5a', for_=['classic', 'country', 'hoarder']),
    'green': dict(rim='4a7a5a', wood='8a6238', for_=['country', 'retro', 'classic']),
    'plain': dict(rim='c8bfa6', wood='c8a068', for_=['student', 'retro', 'hoarder']),
}


@piece('plate_rack', 34, 27, 'decor', rooms={'kitchen': 6}, styles=None, tags=('storage', 'rack', 'food'), variants={k: {'r': k, 'for': v['for_']} for k, v in RACKS.items()}, wall_y=(18, 24),
       limit=1, above=('unit',), must_above=True,
       note='a wooden plate rack on the wall: three plates on edge with a painted rim, a lipped shelf under them, two mugs hung from hooks')
def plate_rack(c, ox, oy, p):
    rk = RACKS[p['r']]
    wood = hexc(rk['wood'])
    rim = hexc(rk['rim'])
    x0, x1 = ox, ox + 33
    # the rack: a top rail, two end posts and a lipped shelf, lit from the left
    c.rect(x0, oy + 2, x1, oy + 3, wood); c.hline(x0, x1, oy + 2, shade(wood, 1.3)); c.hline(x0, x1, oy + 3, shade(wood, 0.7))
    for px in (x0, x1 - 1):
        c.rect(px, oy + 2, px + 1, oy + 17, shade(wood, 0.9)); c.vline(px, oy + 2, oy + 17, shade(wood, 1.25))
    c.rect(x0, oy + 15, x1, oy + 17, wood); c.hline(x0, x1, oy + 15, shade(wood, 1.3)); c.hline(x0, x1, oy + 17, shade(wood, 0.6))
    # three plates on edge, face-on: a painted rim, a pale well, a hint of the next plate behind
    for cx in (x0 + 7, x0 + 17, x0 + 27):
        cy = oy + 9
        _disc(c, cx, cy, 5.6, lambda x, y, d: shade(rim, 1.1 - 0.25 * (x - (cx - 5)) / 10.0) if d > 0.8 else shade(hexc('ece8dc'), 1.1 - 0.3 * d - (0.12 if (x > cx and y > cy) else 0)))
        c.put(int(cx) - 3, int(cy) - 3, hexc('ffffff'))
    # the slats the plates lean on, seen between them
    for sx in (x0 + 12, x0 + 22):
        c.vline(sx, oy + 4, oy + 14, shade(wood, 0.7))
    # two mugs hanging under the shelf from hooks
    for mx, mc in ((x0 + 9, hexc('e6e0cc')), (x0 + 24, shade(rim, 1.0))):
        c.put(mx, oy + 18, STEEL_LT)
        L = K.Layer(c)
        K.cyl(L.c, mx + 0.5, oy + 19, oy + 25, 2.6, mc, ry=1.0, cap=True, inner=hexc('3a2a20'), gloss=False, n=4, lo=0.62, hi=1.2)
        L.c.hline(int(mx) + 3, int(mx) + 4, oy + 20, shade(mc, 0.78)); L.c.vline(int(mx) + 4, oy + 20, oy + 23, shade(mc, 0.58)); L.c.hline(int(mx) + 3, int(mx) + 4, oy + 23, shade(mc, 0.68))   # the handle: a C
        L.flush()
    c.shadow(ox + 17, oy + 26, 15, 1, 36)


# ================================================================================================================================ the clothes airer
AIRERS = {
    'wood': dict(frame='b8895a', wash=('4f6f9a', 'e6e0d0', 'b0453a', 'd8d0b8'), for_=['classic', 'country', 'hoarder', 'retro']),
    'white': dict(frame='d8d8d2', wash=('e8e4d8', '6a8aa8', 'a8b0b4', '4a5a6a'), for_=['student', 'classic', 'retro']),
}


@piece('airer_laundry', 36, 38, 'floor', keep='airer', rooms={'kitchen': 5}, styles={'student': 8, 'classic': 4, 'retro': 3, 'hoarder': 4, 'country': 3}, tags=('clutter', 'laundry'), feet=(110, 118),
       variants={k: {'a': k, 'for': v['for_']} for k, v in AIRERS.items()},
       note='a clothes airer, its wings opened out, with the washing on it: a towel and a shirt over the rails, socks, a tea towel')
def airer_laundry(c, ox, oy, p):
    ak = AIRERS[p['a']]
    frame = hexc(ak['frame'])
    w1, w2, w3, w4 = (hexc(h) for h in ak['wash'])
    x0, x1 = ox + 1, ox + 33
    c.shadow(ox + 17, oy + 1, 17, 2, 95)
    # the frame: an end frame each side with splayed feet, and four rails across it
    for ex in (x0, x1):
        c.rect(ex, oy - 34, ex + 1, oy, shade(frame, 0.85)); c.vline(ex, oy - 34, oy, shade(frame, 1.3))
        c.line(ex + (1 if ex == x0 else 0), oy - 6, ex + (-3 if ex == x0 else 4), oy, shade(frame, 0.7))
    rails = (oy - 33, oy - 25, oy - 17, oy - 9)
    for ry in rails:
        c.hline(x0, x1 + 1, ry, shade(frame, 1.25)); c.hline(x0, x1 + 1, ry + 1, shade(frame, 0.7))
    # the washing: lit on the left, shaded on the right, folds as dark columns
    def cloth(xa, xb, ya, yb, col, folds=3):
        for x in range(xa, xb + 1):
            u = (x - xa) / float(max(1, xb - xa))
            t = shade(col, 1.12 - 0.34 * u)
            if folds and (x - xa) % max(2, (xb - xa) // folds) == 0 and x != xa:
                t = shade(t, 0.78)
            c.vline(x, ya, yb, t)
        c.hline(xa, xb, ya, shade(col, 1.3))
        c.hline(xa, xb, yb, shade(col, 0.62))
    cloth(x0 + 3, x0 + 14, rails[0] - 1, rails[0] + 15, w1)                                          # a big towel over the top rail, stripe across it
    c.hline(x0 + 3, x0 + 14, rails[0] + 6, w2); c.hline(x0 + 3, x0 + 14, rails[0] + 7, shade(w2, 0.85))
    cloth(x0 + 17, x0 + 29, rails[0] - 1, rails[0] + 5, w3, folds=2)                                  # a shirt: body hanging, sleeves out over the rail
    c.rect(x0 + 15, rails[0], x0 + 17, rails[0] + 3, shade(w3, 0.9)); c.rect(x0 + 29, rails[0], x0 + 31, rails[0] + 3, shade(w3, 0.7))
    cloth(x0 + 5, x0 + 12, rails[2] - 1, rails[2] + 6, w4, folds=2)                                   # a tea towel on the third rail
    for sx in (x0 + 17, x0 + 21, x0 + 25):                                                            # socks pegged on the lowest rail
        c.rect(sx, rails[3], sx + 2, rails[3] + 5, shade(w2 if sx % 8 else w3, 1.0))
        c.put(sx, rails[3], shade(w2, 1.3))
        c.rect(sx + 1, rails[3] + 5, sx + 3, rails[3] + 6, shade(w2 if sx % 8 else w3, 0.7))


# ================================================================================================================================ seats for the two tables that had none
def seat_for_table(c, ox, oy, kind):
    """A camping table gets a folding chair (a steel frame, a canvas seat); the trestle a mismatched wooden one. Called by furn_kitchen.table_kitchen."""
    from furn_kitchen import _chair
    if kind == 'camping':
        _chair(c, ox + 43, oy, None, hexc('c8b48a'), tall=24, chrome=True)
        c.hline(ox + 42, ox + 52, oy - 12, hexc('a89868'))                                            # the canvas sags a little between the rails
    else:
        _chair(c, ox - 14, oy, hexc('7a5a3c'), tall=22)
