"""THE KITCHEN — fitted units, appliances, tables (owner round 47e: "expand to other module types too… a big pass").

A kitchen is no longer one of five baked pictures: it is a SHELL (the bare room) plus PIECES laid by the planner from a seed. The fitted things stand edge to edge in a RUN along the back wall
(recipe `run`, tag `unit`: base units, a sink unit, a cooker, a fridge), all on ONE feet row so their worktops line up; a unit's FINISH (sage / yellow / white / pine / cream) names the style it belongs to
(`params.for`), so the classic kitchen has its grey-green units, the retro one its yellow ones. Everything is drawn flat and brought forward + leaned by the kit (pixlib.setback), like the bedroom's.

Things standing ON a worktop (a kettle, a toaster, a pot on the hob) are separate small pieces (furn_kitchen_small.py) that stand on the `worktop` / `appliance` slots the units declare. What opens
when searched (a door, a drawer, the oven) is drawn open for `p['open']` 0..1 and carries a strip, exactly like the bedroom's nightstand.
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
from pixlib import hexc, shade, mix
from furn_wardrobes import _raised

INTERIOR = hexc('2c2620')
OUT = hexc('2a1c17')
STEEL, STEEL_DK, STEEL_LT = hexc('9aa1a3'), hexc('737a7c'), hexc('c4cacc')

FIN = {
    'sage': dict(door='6f8a7a', lt='8aa294', dk='54695c', out='2e3a32', top='8f8a7c', toplt='aaa595', topdk='5e5a50', handle='bab6a8', shaker=True, style='classic'),
    'yellow': dict(door='d9b84a', lt='ecd470', dk='a88a26', out='5e4a18', top='e4e0d0', toplt='f6f2e4', topdk='8a8678', handle='b8bec2', shaker=False, style='retro'),
    'white': dict(door='e4dfd2', lt='f6f2e8', dk='b9b3a4', out='6a665c', top='4a4d50', toplt='6e7276', topdk='2a2c2e', handle='9aa0a4', shaker=False, style='student'),
    'pine': dict(door='b88a58', lt='d4a874', dk='8a6238', out='4a3018', top='c8a068', toplt='e0bc84', topdk='7a5630', handle='3a3a38', shaker=True, style='country'),
    'cream': dict(door='d6ceb4', lt='e8e2cc', dk='aaa28a', out='5e5846', top='7a766a', toplt='96928a', topdk='4a4840', handle='9a9a92', shaker=False, style='hoarder'),
}
FIN_C = {k: {kk: (hexc(vv) if isinstance(vv, str) and len(vv) == 6 and kk not in ('style',) else vv) for kk, vv in v.items()} for k, v in FIN.items()}


def _fin(name):
    return FIN_C[name]


def _handle(c, x, y, fin, vertical=True, knob=False):
    h = fin['handle']
    if knob:
        c.rect(x, y, x + 1, y + 1, h)
        c.put(x, y, shade(h, 1.4))
        return
    if vertical:
        c.vline(x, y, y + 4, h)
        c.vline(x + 1, y, y + 4, shade(h, 0.7))
        c.put(x, y, shade(h, 1.4))
    else:
        c.hline(x, x + 4, y, h)
        c.hline(x, x + 4, y + 1, shade(h, 0.7))
        c.put(x, y, shade(h, 1.4))


def _door_slab(c, x0, y0, x1, y1, fin, shade_f=1.0):
    """A cabinet door: flat with a lit top-left edge (retro / student / hoarder) or a shaker frame with an inset panel (classic / country)."""
    door, lt, dk, out = fin['door'], fin['lt'], fin['dk'], fin['out']
    if shade_f != 1.0:
        door, lt, dk = shade(door, shade_f), shade(lt, shade_f), shade(dk, shade_f)
    c.rect(x0, y0, x1, y1, door)
    if not fin['shaker'] and x1 - x0 >= 6 and y1 - y0 >= 8:                                  # a flat-fronted door is not one colour: lit toward the top, a hair darker at the foot, a faint fleck of grain
        h = y1 - y0
        for yy in range(y0, y1 + 1):
            f = (yy - y0) / float(max(1, h))
            c.hline(x0, x1, yy, shade(door, 1.05 - 0.10 * f))
        for k, yy in enumerate(range(y0 + 5, y1 - 2, 7)):
            c.hline(x0 + 2 + (k * 5) % 5, min(x1 - 2, x0 + 4 + (k * 5) % 5), yy, shade(door, 0.95))
        c.hline(x0 + 1, x1 - 1, y0 + 1, shade(lt, 0.98))                                      # the bevel: a second, softer lit row inside the edge
        c.vline(x1 - 1, y0 + 1, y1 - 1, shade(dk, 1.08))
    c.hline(x0, x1, y0, lt)
    c.vline(x0, y0, y1, lt)
    c.hline(x0, x1, y1, dk)
    c.vline(x1, y0, y1, dk)
    if fin['shaker'] and x1 - x0 >= 8 and y1 - y0 >= 9:
        c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, shade(door, 0.94))
        c.hline(x0 + 2, x1 - 2, y1 - 2, lt)
        c.vline(x1 - 2, y0 + 2, y1 - 2, lt)
        c.hline(x0 + 2, x1 - 2, y0 + 2, dk)
        c.vline(x0 + 2, y0 + 2, y1 - 2, dk)


def _door_cell(c, x0, y0, x1, y1, fin, hinge, t, rng, knob=False):
    """A door in a unit's front: closed (t = 0) or swung open t of the way — a narrow slab at the hinge edge over the dark cupboard inside, with a shelf and a tin in it."""
    if t <= 0.001:
        _door_slab(c, x0, y0, x1, y1, fin)
        if hinge == 'left':
            _handle(c, x1 - 3, (y0 + y1) // 2 - 3, fin, True, knob)
        else:
            _handle(c, x0 + 2, (y0 + y1) // 2 - 3, fin, True, knob)
        if rng.random() < 0.5:                                                                  # a chip in the paint
            c.put(x0 + rng.randint(2, max(2, x1 - x0 - 2)), y1 - rng.randint(1, 4), shade(fin['door'], 0.7))
        return
    c.rect(x0, y0, x1, y1, INTERIOR)
    c.hline(x0, x1, (y0 + y1) // 2, shade(INTERIOR, 1.7))
    c.rect(x0 + 2, (y0 + y1) // 2 - 5, x0 + 4, (y0 + y1) // 2 - 1, hexc('9c4a3a'))
    c.rect(x1 - 5, y1 - 5, x1 - 2, y1 - 1, hexc('8a9aa0'))
    w = x1 - x0 + 1
    dw = max(2, int(round(w * (1.0 - 0.85 * t))))
    if hinge == 'right':
        _door_slab(c, x1 - dw + 1, y0, x1, y1, fin, 0.82)
    else:
        _door_slab(c, x0, y0, x0 + dw - 1, y1, fin, 0.82)


def _slab(c, x0, x1, top, fin):
    """The worktop's front edge: four rows, a lit lip on top, a dark underside; it overhangs the carcass by one pixel each side."""
    c.rect(x0, top, x1, top + 3, fin['top'])
    c.hline(x0, x1, top, fin['toplt'])
    c.hline(x0, x1, top + 1, shade(fin['top'], 1.06))
    c.hline(x0, x1, top + 3, fin['topdk'])
    c.put(x0, top, shade(fin['toplt'], 0.8))


def _carcass(c, x0, x1, top, base, fin):
    """The cabinet body under the worktop: dark joints at both sides, the kick board, the shadow the worktop throws."""
    c.rect(x0, top + 4, x1, base, fin['out'])
    c.rect(x0 + 1, top + 4, x1 - 1, base - 5, shade(fin['dk'], 0.9))
    c.hline(x0 + 1, x1 - 1, top + 4, shade(fin['dk'], 0.55))
    c.rect(x0 + 1, base - 4, x1 - 1, base, hexc('2e2822'))                                      # the kick board
    c.hline(x0 + 1, x1 - 1, base - 4, hexc('4a4038'))


# ================================================================================================================================ base units
LAYOUTS = ('two', 'drawers', 'dd', 'open')


def _base_variants():
    v = {}
    for fname, fin in FIN.items():
        for lay in LAYOUTS:
            v['%s_%s' % (fname, lay)] = {'fin': fname, 'lay': lay, 'for': [fin['style']]}
    return v


@piece('unit_base', 30, 32, 'wall', rooms={'kitchen': 8}, styles=None, tags=('unit', 'storage'), depth=4, variants=_base_variants(), limit=4, feet=(106, 106),
       slots=({'id': 'top', 'dx0': 3, 'dx1': 27, 'dy': -31, 'top': True, 'kinds': ('worktop', 'appliance')},),
       anchors=({'name': 'cupboard', 'dx': 15, 'dy': -15},), opens={'kind': 'door_h', 'frames': 3, 'anchor': 'cupboard'},
       note='a fitted base unit in the finish of its kitchen (sage / yellow / white / pine / cream): two doors, three drawers, a drawer over a door, or a gap with a shelf; the doors / top drawer open when searched')
def unit_base(c, ox, oy, p):
    fin = _fin(p['fin'])
    lay = p['lay']
    t = p['open']
    rng = random.Random(ox * 31 + len(p['fin']) * 7 + len(lay))
    x0, x1, top, base = ox, ox + 29, oy - 31, oy
    c.shadow((x0 + x1) // 2, base + 1, 16, 2, 100)
    _carcass(c, x0, x1, top, base, fin)
    ya, yb = top + 5, base - 5
    mid = (x0 + x1) // 2
    knob = fin['shaker'] and p['fin'] == 'pine'
    if lay == 'two':
        _door_cell(c, x0 + 1, ya, mid - 1, yb, fin, 'left', 0.0, rng, knob)
        _door_cell(c, mid + 1, ya, x1 - 1, yb, fin, 'right', t, rng, knob)
    elif lay == 'drawers':
        ys = (ya, ya + 8, ya + 16)
        for k, y in enumerate(ys):
            off = min(5, int(round(5 * t))) if k == 0 else 0
            if k == 0 and off:
                c.rect(x0 + 2, y - 1, x1 - 2, y + off, INTERIOR)
                c.hline(x0 + 3, x1 - 3, y, shade(fin['door'], 0.7))
            _door_slab(c, x0 + 1, y + off, x1 - 1, min(y + 6, yb) + off, fin)
            _handle(c, mid - 2, y + 2 + off, fin, False, knob)
    elif lay == 'dd':
        off = min(5, int(round(5 * t)))
        if off:
            c.rect(x0 + 2, ya - 1, x1 - 2, ya + off, INTERIOR)
        _door_slab(c, x0 + 1, ya + off, x1 - 1, ya + 6 + off, fin)
        _handle(c, mid - 2, ya + 2 + off, fin, False, knob)
        _door_cell(c, x0 + 1, ya + 8, mid - 1, yb, fin, 'left', 0.0, rng, knob)
        _door_cell(c, mid + 1, ya + 8, x1 - 1, yb, fin, 'right', 0.0, rng, knob)
    else:                                                                                        # open: a door off its hinges, the shelf and a bucket showing
        _door_cell(c, x0 + 1, ya, mid - 1, yb, fin, 'left', 0.0, rng, knob)
        c.rect(mid + 1, ya, x1 - 1, yb, INTERIOR)
        c.hline(mid + 1, x1 - 1, (ya + yb) // 2, shade(INTERIOR, 1.7))
        K.frustum(c, mid + 7.5, (ya + yb) // 2 + 3, yb - 1, 4.2, 3.4, hexc('4f6f8a'), ry_t=1.2, ry_b=1.0, inner=hexc('1a2a38'), rim=hexc('6a8aa4'))
        c.rect(mid + 3, ya + 3, mid + 5, (ya + yb) // 2 - 1, hexc('9c4a3a'))
    _slab(c, x0, x1, top, fin)
    for k in range(3):                                                                           # the worktop's wear: a ring from a hot pan, a nick
        c.put(x0 + rng.randint(3, 26), top + 1, shade(fin['top'], 0.82))


# ================================================================================================================================ the sink unit
def _sink_variants():
    v = {}
    for fname, fin in FIN.items():
        if fname == 'pine':
            continue
        v[fname] = {'fin': fname, 'for': [fin['style']]}
    return v


@piece('unit_sink', 38, 32, 'wall', rooms={'kitchen': 8}, styles=None, tags=('unit', 'wet', 'storage'), depth=4, variants=_sink_variants(), limit=1, feet=(106, 106),
       slots=({'id': 'top', 'dx0': 24, 'dx1': 36, 'dy': -31, 'top': True, 'kinds': ('worktop',)},),
       anchors=({'name': 'sink', 'dx': 14, 'dy': -31, 'top': True}, {'name': 'sink_cupboard', 'dx': 19, 'dy': -14}), opens={'kind': 'door_h', 'frames': 3, 'anchor': 'sink_cupboard'},
       note='a sink unit: a steel basin set in the worktop with a drainer, a gooseneck mixer tap, a dish rack of plates, doors below (one opens on a bucket)')
def unit_sink(c, ox, oy, p):
    fin = _fin(p['fin'])
    t = p['open']
    rng = random.Random(5 + len(p['fin']))
    x0, x1, top, base = ox, ox + 37, oy - 31, oy
    c.shadow((x0 + x1) // 2, base + 1, 20, 2, 100)
    _carcass(c, x0, x1, top, base, fin)
    ya, yb = top + 5, base - 5
    _door_cell(c, x0 + 1, ya, x0 + 12, yb, fin, 'left', 0.0, rng)
    c.rect(x0 + 14, ya, x1 - 1, yb, fin['dk'])                                                  # the plumbing cupboard: doors with a bucket behind
    _door_cell(c, x0 + 14, ya, x0 + 25, yb, fin, 'left', 0.0, rng)
    _door_cell(c, x0 + 26, ya, x1 - 1, yb, fin, 'right', t, rng)
    _slab(c, x0, x1, top, fin)
    # on the worktop: the basin (a flat steel inset seen from above), the drainer's grooves, a mixer tap, a rack of plates — the kit stands them on the top surface
    b0, b1 = x0 + 5, x0 + 22
    c.rect(b0, top - 3, b1, top - 1, STEEL_LT)
    c.hline(b0, b1, top - 3, hexc('e0e4e6'))
    c.rect(b0 + 2, top - 2, b0 + 9, top - 1, hexc('5f6b6a'))                                     # the bowl, dirty water
    c.rect(b0 + 11, top - 2, b1 - 2, top - 1, STEEL)
    for gx in range(b0 + 12, b1 - 1, 2):
        c.put(gx, top - 2, STEEL_DK)
    c.vline(b0 + 4, top - 8, top - 4, STEEL_LT)                                                   # the tap: a short neck up from behind the bowl and over it
    c.hline(b0 + 4, b0 + 7, top - 8, STEEL_LT)
    c.put(b0 + 7, top - 7, STEEL_DK)
    c.put(b0 + 2, top - 5, hexc('b84a3a')); c.put(b0 + 6, top - 5, hexc('3a6ab8'))              # hot and cold
    for k in range(4):                                                                            # plates standing in a rack on the drainer
        px = b1 - 8 + k * 2
        c.vline(px, top - 7, top - 4, hexc('ece6d4') if k % 2 else hexc('d4ccb8'))
    c.hline(b1 - 9, b1 - 1, top - 4, STEEL_DK)
    c.hline(b1 - 9, b1 - 1, top - 3, STEEL_DK)


# ================================================================================================================================ the cooker
COOKERS = {'white': ('e6e0d0', 'b8b19b'), 'cream': ('dcd5bf', 'b0a88e'), 'black': ('3a3a3e', '222226')}


def _cooker_variants():
    return {'white_pan': {'col': 'white', 'on': 'pan', 'for': ['classic', 'retro', 'student']}, 'white_kettle': {'col': 'white', 'on': 'kettle', 'for': ['classic', 'retro', 'student']},
            'white_bare': {'col': 'white', 'on': 'none', 'for': ['classic', 'retro', 'student']}, 'cream_pan': {'col': 'cream', 'on': 'pan', 'for': ['hoarder', 'classic']},
            'cream_bare': {'col': 'cream', 'on': 'none', 'for': ['hoarder']}, 'black_bare': {'col': 'black', 'on': 'none', 'for': ['student', 'hoarder']}}


@piece('unit_cooker', 28, 34, 'wall', rooms={'kitchen': 8}, styles=None, tags=('unit', 'cooking'), depth=4, variants=_cooker_variants(), limit=1, feet=(106, 106),
       slots=(), anchors=({'name': 'oven', 'dx': 14, 'dy': -14},), opens={'kind': 'door_drop', 'frames': 3, 'anchor': 'oven'},
       note='a freestanding cooker: knobs on a fascia, an oven door with a window and a bar handle (it drops open when searched), a hob with rings and a pot / a kettle on it')
def unit_cooker(c, ox, oy, p):
    body, body_dk = (hexc(v) for v in COOKERS[p['col']])
    t = p['open']
    x0, x1, top, base = ox, ox + 27, oy - 33, oy
    c.shadow((x0 + x1) // 2, base + 1, 15, 2, 100)
    c.rect(x0, top, x1, base, hexc('2a2622'))
    c.rect(x0 + 1, top, x1 - 1, base - 3, body)
    c.vline(x0 + 1, top, base - 3, shade(body, 1.14))
    c.vline(x1 - 1, top, base - 3, body_dk)
    c.rect(x0 + 1, top, x1 - 1, top + 2, hexc('2e2c29'))                                         # the hob's front lip
    c.hline(x0 + 1, x1 - 1, top, hexc('5a5650'))
    c.rect(x0 + 2, top + 3, x1 - 2, top + 8, body_dk)                                            # the fascia: knobs and a clock
    for kx in range(x0 + 5, x1 - 4, 5):
        c.rect(kx, top + 4, kx + 1, top + 6, hexc('2a2622'))
        c.put(kx, top + 4, hexc('8a8a86'))
    c.rect(x0 + 2, top + 10, x1 - 2, top + 11, body_dk)                                          # the grill drawer
    c.hline(x0 + 8, x1 - 8, top + 10, hexc('b4b8ba'))
    oy0, oy1 = top + 13, base - 6
    c.rect(x0 + 2, oy0, x1 - 2, oy1, shade(body, 0.96))
    c.hline(x0 + 2, x1 - 2, oy0, shade(body, 1.14)); c.vline(x0 + 2, oy0, oy1, shade(body, 1.1))
    if t <= 0.001:
        c.hline(x0 + 5, x1 - 5, oy0 + 2, STEEL_LT); c.hline(x0 + 5, x1 - 5, oy0 + 3, STEEL_DK)      # the bar handle
        c.rect(x0 + 5, oy0 + 6, x1 - 5, oy1 - 3, hexc('2a2622'))                                  # the window
        c.hline(x0 + 5, x1 - 5, oy0 + 6, hexc('4a423c'))
        c.hline(x0 + 7, x0 + 12, oy0 + 8, hexc('5a524a'))
    else:                                                                                          # the door dropped open: the glowing inside, the door's edge forward
        c.rect(x0 + 3, oy0 + 1, x1 - 3, oy1 - 2, hexc('3a3430'))
        c.hline(x0 + 3, x1 - 3, oy0 + 6, hexc('8a8a86'))
        c.hline(x0 + 3, x1 - 3, oy0 + 10, hexc('8a8a86'))
        dd = int(round(7 * t))
        c.rect(x0 + 2, oy1 - 3, x1 - 2, oy1 + dd - 2, shade(body, 0.85))
        c.hline(x0 + 2, x1 - 2, oy1 + dd - 2, STEEL_DK)
    c.rect(x0 + 1, base - 2, x1 - 1, base, hexc('2e2822'))
    # on the hob (above the top, so the kit stands it ON the surface): the rings seen from above, then what is on them
    for hx in (x0 + 7, x1 - 8):
        c.rect(hx - 3, top - 3, hx + 3, top - 1, hexc('2a2826'))
        c.hline(hx - 2, hx + 2, top - 2, hexc('4a4640'))
    if p['on'] == 'pan':
        K.cyl(c, x0 + 7.5, top - 6, top - 3, 4.0, hexc('7a6f63'), ry=1.4, cap=True, inner=hexc('2e2a26'), gloss=True)
        c.hline(x0 + 2, x0 + 3, top - 5, hexc('3a3834'))
    elif p['on'] == 'kettle':
        K.frustum(c, x1 - 8.0, top - 7, top - 3, 2.8, 4.0, hexc('b4bcc0'), ry_t=1.0, ry_b=1.2, rim=hexc('e0e6e8'), gloss=True)
        c.put(x1 - 11, top - 6, hexc('3a3834')); c.put(x1 - 12, top - 5, hexc('3a3834'))        # the handle


# ================================================================================================================================ fridges
FRIDGES = {
    'cream': dict(col='d2cbb2', lt='e2dcc6', dk='b4ad95', style=['classic', 'hoarder'], round=True),
    'mint': dict(col='b8d4c0', lt='d4e6d8', dk='8ca898', style=['retro'], round=True),
    'white': dict(col='e8e8e4', lt='f6f6f2', dk='c0c0ba', style=['student', 'classic'], round=False),
}


def _fridge_variants():
    v = {k: {'k': k, 'for': f['style']} for k, f in FRIDGES.items()}
    v['white_open'] = {'k': 'white', 'static_open': True, 'for': ['student']}
    return v


@piece('fridge_tall', 28, 76, 'wall', rooms={'kitchen': 6}, styles=None, tags=('unit', 'cold', 'storage'), depth=6, variants=_fridge_variants(), limit=1, feet=(106, 106),
       slots=(), anchors=({'name': 'fridge', 'dx': 14, 'dy': -50},), opens={'kind': 'door_h', 'frames': 3, 'anchor': 'fridge'},
       note='a tall fridge-freezer: a rounded 50s cream one with a chrome handle and magnets, a mint one, a plain white one — or one left open with the milk gone off; the door swings open when searched')
def fridge_tall(c, ox, oy, p):
    f = FRIDGES[p['k']]
    col, lt, dk = hexc(f['col']), hexc(f['lt']), hexc(f['dk'])
    t = 1.0 if p.get('static_open') else p['open']
    x0, x1, top, base = ox + 1, ox + 26, oy - 75, oy
    c.shadow((x0 + x1) // 2, base + 1, 15, 2, 100)
    r = 5 if f['round'] else 2
    from pixlib import rrect
    rrect(c, x0, top, x1, base - 1, hexc('2a2622'), r)
    if t > 0.01:
        # the open fridge: the inside lit and full, the door swung out to the right as a narrow slab
        rrect(c, x0 + 1, top + 1, x1 - 1, base - 2, shade(col, 0.5), r)
        c.rect(x0 + 3, top + 4, x1 - 3, base - 6, hexc('e6ece8'))
        for k, y in enumerate((top + 20, top + 36, top + 52)):
            c.hline(x0 + 3, x1 - 3, y, hexc('9aa8a4'))
            c.hline(x0 + 3, x1 - 3, y + 1, hexc('c4cec8'))
        for (fx, fy, fc, fh) in ((x0 + 5, top + 20, hexc('d4b84a'), 9), (x0 + 12, top + 20, hexc('c8483a'), 7), (x0 + 17, top + 20, hexc('6a9a58'), 10),
                                 (x0 + 6, top + 36, hexc('e8e2d0'), 8), (x0 + 14, top + 36, hexc('8a6a3a'), 6), (x0 + 5, top + 52, hexc('d8d2b8'), 9),
                                 (x0 + 15, top + 52, hexc('4f6f8a'), 7)):
            c.rect(fx, fy - fh + 1, fx + 3, fy - 1, fc)
        c.hline(x0 + 3, x1 - 3, top + 12, hexc('9aa8a4'))
        dw = max(4, int(round(24 * (1.0 - 0.8 * min(1.0, t)))))
        c.rect(x1 - dw + 1, top + 1, x1 + 1, base - 3, shade(col, 0.82))
        c.vline(x1 - dw + 1, top + 1, base - 3, shade(col, 1.1))
        c.vline(x1 + 1, top + 1, base - 3, shade(col, 0.6))
        for yy in (top + 14, top + 30, top + 46):
            c.rect(x1 - dw + 2, yy, x1, yy + 1, hexc('b8bec0'))
        if p.get('static_open'):
            c.ellipse((x0 + x1) // 2 - 2, base + 1, 9, 1.6, hexc('e8e4d8'))                      # the spilt milk
        return
    rrect(c, x0 + 1, top + 1, x1 - 1, base - 2, col, r)
    # the doors are gently domed: every column takes its tone from how far round the curve it is (lit on the left, deep on the right), in four steps; the freezer door a shade lighter
    cxm = (x0 + x1) / 2.0
    half = (x1 - x0) / 2.0
    for y in range(top + 1, base - 1):
        for x in range(x0 + 1, x1):
            if c.px[x, y][:3] != col[:3]:
                continue
            u = (x - cxm) / half
            step = int((u + 1.0) / 2.0 * 4.0)                                                       # 0 lit .. 3 shaded
            c.px[x, y] = shade(col, (1.10, 1.03, 0.97, 0.86)[max(0, min(3, step))])
    for k, (ya, yb) in enumerate(((top + 5, top + 17), (top + 28, top + 56))):                      # a window-light streak down each door, broken in two
        for y in range(ya, yb):
            if (y - ya) % 9 != 8:
                c.px[x0 + 5, y] = shade(lt, 1.18)
                c.px[x0 + 6, y] = shade(lt, 1.05)
    c.hline(x0 + 2, x1 - 2, top + 21, dk)                                                         # the gap between the doors: a dark seam, shaded under the freezer's lower lip
    c.hline(x0 + 2, x1 - 2, top + 22, shade(dk, 0.7))
    c.hline(x0 + 2, x1 - 2, top + 23, lt)
    c.hline(x0 + 2, x1 - 2, top + 2, shade(lt, 1.15))                                             # the lit top edge
    for yy in (top + 4, top + 18, top + 27, top + 60):                                              # the hinges on the left edge
        c.rect(x0 + 1, yy, x0 + 2, yy + 2, shade(dk, 0.6))
        c.put(x0 + 1, yy, hexc('b8bec0'))
    c.hline(x1 - 12, x1 - 6, top + 4, hexc('b8bec0'))                                              # the maker's badge: a chrome dash with a dark underline
    c.hline(x1 - 12, x1 - 6, top + 5, hexc('4a5052'))
    for (hy0, hy1) in ((top + 26, top + 42), (top + 6, top + 16)):                                 # chrome handles, round in section: bright / mid / dark across, a stub at each end, a shadow beside
        for yy in range(hy0, hy1 + 1):
            c.put(x1 - 7, yy, hexc('f2f6f8'))
            c.put(x1 - 6, yy, hexc('b8bec0'))
            c.put(x1 - 5, yy, hexc('6a7276'))
            c.put(x1 - 4, yy, shade(col, 0.72))
        for yy in (hy0, hy1):
            c.rect(x1 - 7, yy, x1 - 5, yy, hexc('4a5052'))
    c.rect(x0 + 6, base - 6, x1 - 6, base - 3, hexc('7b8083'))                                     # the vent grille
    for gx in range(x0 + 7, x1 - 6, 2):
        c.vline(gx, base - 6, base - 3, hexc('565a5c'))
    if p['k'] != 'white':                                                                           # magnets: a photo and a child's drawing of a house under the sun
        F.photo(c, x0 + 5, top + 28, x0 + 12, top + 38, [(hexc('e0c0a0'), hexc('a8783a'), hexc('3a5a8a'), 6)], bg=hexc('7a9ab8'), ground=hexc('5a7aa0'))
        c.put(x0 + 8, top + 27, hexc('b0453a'))
        c.rect(x0 + 13, top + 42, x0 + 20, top + 50, hexc('f4f0e4'))
        c.poly([(x0 + 14, top + 47), (x0 + 16, top + 45), (x0 + 18, top + 47)], hexc('c0453a'))
        c.rect(x0 + 14, top + 47, x0 + 18, top + 49, hexc('c9a06a'))
        c.put(x0 + 19, top + 44, hexc('e8b83a'))
    else:
        c.rect(x0 + 6, top + 10, x0 + 11, top + 15, hexc('f4f0a8'))                                # a yellow note under a magnet
        c.put(x0 + 8, top + 9, hexc('c0453a'))


@piece('larder_tall', 28, 82, 'wall', rooms={'kitchen': 4}, styles={'retro': 8, 'country': 2}, tags=('unit', 'storage', 'food'), depth=6, limit=1, feet=(106, 106),
       variants={'yellow': {'fin': 'yellow', 'for': ['retro']}, 'pine': {'fin': 'pine', 'for': ['country']}},
       anchors=({'name': 'larder', 'dx': 14, 'dy': -30}, {'name': 'larder_top', 'dx': 14, 'dy': -56}),
       note='a tall larder cupboard: a door over open shelves of tins, jars and packets')
def larder_tall(c, ox, oy, p):
    fin = _fin(p['fin'])
    x0, x1, top, base = ox, ox + 27, oy - 81, oy
    c.shadow((x0 + x1) // 2, base + 1, 15, 2, 100)
    c.rect(x0, top, x1, base, fin['out'])
    c.rect(x0 + 1, top + 1, x1 - 1, base - 1, fin['dk'])
    c.rect(x0 + 1, top, x1 - 1, top + 2, fin['top'])                                               # a cap
    c.hline(x0 + 1, x1 - 1, top, fin['toplt'])
    _door_slab(c, x0 + 2, top + 4, x1 - 2, top + 30, fin)                                          # the solid door above
    _handle(c, x1 - 6, top + 16, fin)
    c.rect(x0 + 2, top + 32, x1 - 2, base - 6, INTERIOR)                                           # the open shelves below
    rng = random.Random(9)
    cols = [hexc('d4b84a'), hexc('c8483a'), hexc('6a9a58'), hexc('e8e2d0'), hexc('8a6a3a'), hexc('4f6f8a'), hexc('b0b4b8')]
    for sy in (top + 44, top + 56, base - 7):
        c.hline(x0 + 2, x1 - 2, sy, fin['dk'])
        c.hline(x0 + 2, x1 - 2, sy + 1, shade(fin['dk'], 0.6))
        x = x0 + 3
        while x < x1 - 4:
            w = rng.choice((3, 3, 4, 5))
            h = rng.randint(5, 9)
            col = rng.choice(cols)
            for xx in range(x, min(x + w, x1 - 2)):
                for yy in range(sy - h, sy):
                    c.put(xx, yy, shade(col, 1.15 - 0.4 * ((xx - x) / float(max(1, w - 1)))))
            c.hline(x, min(x + w - 1, x1 - 3), sy - h, shade(col, 1.35))
            x += w + 1
    c.rect(x0 + 1, base - 4, x1 - 1, base, hexc('2e2822'))


# ================================================================================================================================ the country kitchen: range in its recess, dresser, butler sink
@piece('range_recess', 76, 92, 'wall', rooms={'kitchen': 6}, styles={'country': 8}, tags=('unit', 'cooking', 'hearth'), depth=5, limit=1, feet=(106, 106), variants={'green': {'col': '2f5a42', 'for': ['country']},
       'cream': {'col': 'd8d0b8', 'for': ['country']}, 'black': {'col': '2a2a2e', 'for': ['country']}},
       anchors=({'name': 'oven', 'dx': 38, 'dy': -16}, {'name': 'copper_pots', 'dx': 38, 'dy': -55}), opens={'kind': 'door_drop', 'frames': 3, 'anchor': 'oven'},
       note='a brick chimney recess with a mantel beam and copper pans on a rail, and an enamel range cooker in it (green / cream / black), the oven doors dropping open when searched')
def range_recess(c, ox, oy, p):
    col = hexc(p['col'])
    t = p['open']
    x0, x1, top, base = ox, ox + 75, oy - 91, oy
    c.shadow((x0 + x1) // 2, base + 1, 40, 2, 100)
    c.rect(x0 + 2, top + 4, x1 - 2, base, hexc('2a1e18'))                                           # the soot-black back of the recess
    rng = random.Random(4)
    BR = hexc('9a5a3e')
    for y in range(top + 6, base, 4):                                                               # brickwork, sooty toward the top
        off = 0 if ((y - top) // 4) % 2 == 0 else 4
        for x in range(x0 + 2 + off - 8, x1 - 1, 8):
            xa, xb = max(x0 + 3, x), min(x1 - 3, x + 6)
            if xb >= xa:
                shd = 0.55 + 0.45 * ((y - top) / 85.0)
                c.rect(xa, y, xb, y + 2, shade(BR, shd * (0.92 + 0.16 * rng.random())))
    c.rect(x0, top, x1, top + 4, hexc('6b4a31'))                                                    # the mantel beam
    c.hline(x0, x1, top, hexc('8a6443')); c.hline(x0, x1, top + 4, hexc('3a2a1c'))
    c.vline(x0 + 1, top + 5, base, shade(hexc('d6cbb0'), 0.85)); c.vline(x1 - 1, top + 5, base, shade(hexc('d6cbb0'), 0.85))
    c.hline(x0 + 8, x1 - 8, top + 12, hexc('3a3a36'))                                                # the rail with its copper pans
    for (px_, r_) in ((x0 + 16, 7), (x0 + 38, 9), (x0 + 60, 6)):
        c.vline(px_, top + 12, top + 17, hexc('3a3a36'))
        L = K.Layer(c)
        K.sphere(L.c, px_ + 0.5, top + 17 + r_, r_, r_, hexc('b8703a'), n=5, gloss=True)
        K.ell(L.c, px_ + 0.5, top + 17 + r_ * 0.35, r_ * 0.62, r_ * 0.3, hexc('3a2418'))
        L.flush()
    # the range: a steel top, two ovens with rail handles and brass hinges, a warming shelf
    rx0, rx1, rtop = x0 + 10, x1 - 10, base - 38
    c.rect(rx0 - 1, rtop - 2, rx1 + 1, rtop + 2, hexc('c4cacc'))
    c.hline(rx0 - 1, rx1 + 1, rtop - 2, hexc('e8ecee')); c.hline(rx0 - 1, rx1 + 1, rtop + 2, hexc('6a7274'))
    c.rect(rx0, rtop + 3, rx1, base, hexc('141816'))
    c.rect(rx0 + 1, rtop + 3, rx1 - 1, base - 1, col)
    c.vline(rx0 + 1, rtop + 3, base - 1, shade(col, 1.25)); c.vline(rx1 - 1, rtop + 3, base - 1, shade(col, 0.7))
    for (dx0, dx1) in ((rx0 + 4, (rx0 + rx1) // 2 - 2), ((rx0 + rx1) // 2 + 2, rx1 - 4)):
        c.rect(dx0 - 1, rtop + 8, dx1 + 1, base - 8, hexc('141816'))
        dh = max(0, int(round(8 * t)))
        c.rect(dx0, rtop + 9, dx1, base - 9, shade(col, 1.0))
        c.hline(dx0, dx1, rtop + 9, shade(col, 1.3)); c.hline(dx0, dx1, base - 9, shade(col, 0.7))
        c.hline(dx0 + 3, dx1 - 3, rtop + 13, hexc('d8dcd8')); c.hline(dx0 + 3, dx1 - 3, rtop + 14, hexc('7a8284'))          # the rail handle
        c.hline(dx0, dx0 + 1, rtop + 10, hexc('c9a24e')); c.hline(dx1 - 1, dx1, rtop + 10, hexc('c9a24e'))
        if dh:
            c.rect(dx0 + 1, base - 9, dx1 - 1, base - 9 + dh, shade(col, 0.8))
    c.hline(rx0 + 2, rx1 - 2, rtop + 5, hexc('d8dcd8'))
    for kx in range(rx0 + 6, rx1 - 4, 11):                                                          # a tea towel over the rail and a kettle on the plate
        c.rect(kx, rtop + 4, kx + 1, rtop + 6, hexc('2a2622'))
    K.frustum(c, rx1 - 14.0, rtop - 11, rtop - 3, 3.2, 4.6, hexc('3a3a3e'), ry_t=1.0, ry_b=1.3, rim=hexc('7a7a82'), gloss=True)


@piece('dresser_welsh', 36, 86, 'wall', rooms={'kitchen': 6, 'dining_room': 4}, styles={'country': 8, 'hoarder': 1, 'formal': 4, 'family': 2}, tags=('storage', 'dresser'), depth=6, limit=1, feet=(106, 106),
       variants={'pine': {'for': ['country', 'hoarder', 'formal', 'family']}},
       slots=({'id': 'top', 'dx0': 4, 'dx1': 32, 'dy': -85, 'top': True, 'kinds': ('worktop',)},),
       anchors=({'name': 'dresser_plates', 'dx': 18, 'dy': -57}, {'name': 'dresser_drawers', 'dx': 18, 'dy': -28}), opens={'kind': 'drawer', 'frames': 3, 'anchor': 'dresser_drawers'},
       note='a Welsh dresser: three shelves of blue-and-white plates, jugs and cups under a pediment, two drawers over a cupboard below')
def dresser_welsh(c, ox, oy, p):
    fin = _fin('pine')
    t = p['open']
    x0, x1, top, base = ox, ox + 35, oy - 85, oy
    c.shadow((x0 + x1) // 2, base + 1, 20, 2, 100)
    rng = random.Random(6)
    # the rack: sides, a pediment cap, a dark back, three shelves with their plate rails
    c.rect(x0, top, x1, top + 3, fin['out'])
    c.rect(x0 + 1, top, x1 - 1, top + 2, fin['dk'])
    c.hline(x0 + 1, x1 - 1, top, fin['toplt'])
    c.rect(x0 + 1, top + 4, x1 - 1, top + 46, fin['out'])
    c.rect(x0 + 3, top + 4, x1 - 3, top + 46, shade(fin['dk'], 0.45))
    for k, sy in enumerate((top + 16, top + 30, top + 45)):
        c.rect(x0 + 2, sy, x1 - 2, sy + 1, fin['door'])
        c.hline(x0 + 2, x1 - 2, sy, fin['lt'])
        c.hline(x0 + 3, x1 - 3, sy - 1, shade(fin['dk'], 0.7))                                       # the plate rail
    for k, sy in enumerate((top + 16, top + 30)):
        for px_ in range(x0 + 6, x1 - 4, 6):                                                          # plates standing on their edges
            K.ell(c, px_, sy - 6, 2.6, 4.6, hexc('e6e8ec'))
            c.put(px_ - 1, sy - 8, hexc('3a5a98')); c.put(px_ + 1, sy - 5, hexc('3a5a98')); c.put(px_, sy - 6, hexc('6a8ac8'))
            c.hline(px_ - 2, px_ + 2, sy - 2, hexc('b8bcc4'))
    for jx, jc in ((x0 + 8, hexc('c8b890')), (x0 + 16, hexc('4f6f8a')), (x0 + 24, hexc('b0453a'))):   # cups and a jug on the bottom shelf
        K.cyl(c, jx, top + 38, top + 44, 2.6, jc, ry=1.0, cap=True, gloss=True)
        c.put(jx + 3, top + 41, jc)
    # the base: two drawers over a pair of doors, a worktop between
    c.rect(x0, top + 47, x1, top + 50, fin['top']); c.hline(x0, x1, top + 47, fin['toplt']); c.hline(x0, x1, top + 50, fin['topdk'])
    c.rect(x0, top + 51, x1, base, fin['out'])
    c.rect(x0 + 1, top + 51, x1 - 1, base - 1, fin['dk'])
    for k, dx in enumerate((x0 + 2, (x0 + x1) // 2 + 1)):
        off = min(4, int(round(4 * t))) if k == 0 else 0
        if off:
            c.rect(dx, top + 52, dx + 14, top + 52 + off, INTERIOR)
        _door_slab(c, dx, top + 52 + off, dx + 14, top + 60 + off, fin)
        _handle(c, dx + 6, top + 55 + off, fin, False, True)
    _door_slab(c, x0 + 2, top + 62, (x0 + x1) // 2 - 1, base - 3, fin)
    _door_slab(c, (x0 + x1) // 2 + 1, top + 62, x1 - 2, base - 3, fin)
    _handle(c, (x0 + x1) // 2 - 4, top + 70, fin, True, True); _handle(c, (x0 + x1) // 2 + 3, top + 70, fin, True, True)
    c.rect(x0 + 1, base - 2, x1 - 1, base, hexc('2e2822'))


@piece('sink_butler', 30, 40, 'wall', rooms={'kitchen': 6}, styles={'country': 8, 'hoarder': 1}, tags=('wet', 'storage'), depth=6, limit=1, feet=(106, 106),
       variants={'white': {'for': ['country', 'hoarder']}},
       slots=(), anchors=({'name': 'sink', 'dx': 14, 'dy': -32}, {'name': 'sink_cupboard', 'dx': 14, 'dy': -10}),
       note='a deep white butler sink on a brick-and-pine base with a brass swan-neck tap and a slatted wooden drainer')
def sink_butler(c, ox, oy, p):
    x0, x1, top, base = ox, ox + 29, oy - 34, oy
    c.shadow((x0 + x1) // 2, base + 1, 17, 2, 100)
    # the base: slatted pine legs / panel under it
    c.rect(x0 + 2, top + 12, x1 - 2, base, hexc('4a3018'))
    for xx in range(x0 + 4, x1 - 3, 3):
        c.vline(xx, top + 14, base - 2, hexc('8a6238'))
        c.vline(xx + 1, top + 14, base - 2, hexc('6a4a28'))
    c.rect(x0 + 2, base - 2, x0 + 4, base, hexc('4a3018')); c.rect(x1 - 4, base - 2, x1 - 2, base, hexc('4a3018'))
    L = K.Layer(c)
    lc = L.c
    lc.rect(x0, top + 4, x1, top + 16, hexc('eeeae0'))                                              # the deep ceramic bowl
    lc.hline(x0, x1, top + 4, hexc('ffffff'))
    lc.vline(x0, top + 4, top + 16, hexc('f8f6f0')); lc.vline(x1, top + 4, top + 16, hexc('b8b4a8'))
    lc.hline(x0, x1, top + 16, hexc('a8a498'))
    lc.rect(x0 + 2, top + 8, x1 - 2, top + 12, hexc('dedacc'))                                       # the lip's shadow line
    L.flush()
    c.rect(x0, top + 2, x1, top + 3, hexc('f4f2ea'))                                                 # the rim
    c.hline(x0, x1, top + 3, hexc('c4c0b4'))
    c.vline(x0 + 14, top - 10, top + 2, hexc('c9a24e')); c.vline(x0 + 15, top - 10, top + 2, hexc('8a7a30'))    # the swan-neck tap
    c.hline(x0 + 14, x0 + 18, top - 10, hexc('c9a24e')); c.put(x0 + 18, top - 9, hexc('8a7a30'))
    c.put(x0 + 12, top, hexc('c9a24e')); c.put(x0 + 17, top, hexc('c9a24e'))


# ================================================================================================================================ tables (with their chairs)
TABLES = {
    'cloth': dict(for_=['classic'], w=50),
    'dinette': dict(for_=['retro'], w=56),
    'pine': dict(for_=['country'], w=62),
    'camping': dict(for_=['student'], w=40),
    'trestle': dict(for_=['hoarder'], w=54),
}


def _chair(c, x, base, col, seat_col=None, tall=26, chrome=False, flip=False):
    """A kitchen chair seen from the front: four legs, a seat, a back with slats / a chrome frame and a vinyl seat."""
    back_h = tall
    if chrome:
        rail = hexc('b4bcc0')
        for lx in (x, x + 8):
            c.vline(lx, base - back_h, base, rail)
        c.hline(x, x + 8, base - back_h, rail)
        c.hline(x, x + 8, base - back_h + 1, hexc('8a9296'))
        c.rect(x - 1, base - 11, x + 9, base - 8, seat_col)
        c.hline(x - 1, x + 9, base - 11, shade(seat_col, 1.25))
        c.hline(x - 1, x + 9, base - 8, shade(seat_col, 0.6))
        for lx in (x, x + 8):
            c.vline(lx, base - 8, base, rail)
        return
    c.rect(x, base - back_h, x + 1, base, shade(col, 0.8))
    c.rect(x + 8, base - back_h, x + 9, base, shade(col, 0.8))
    c.rect(x, base - back_h, x + 9, base - back_h + 1, shade(col, 1.15))
    c.rect(x + 2, base - back_h + 5, x + 7, base - back_h + 6, col)
    c.rect(x + 2, base - back_h + 10, x + 7, base - back_h + 11, col)
    c.rect(x - 1, base - 10, x + 10, base - 8, shade(col, 1.1))
    c.hline(x - 1, x + 10, base - 10, shade(col, 1.3))
    c.hline(x - 1, x + 10, base - 8, shade(col, 0.6))
    for lx in (x, x + 8):
        c.rect(lx, base - 7, lx + 1, base, shade(col, 0.85))


def _top(c, x0, x1, ytop, col, edge, d=4):
    """A table top seen from a little above: a lit top face `d` rows deep, a front edge, and its shadow."""
    for k in range(d):
        c.hline(x0 + (d - 1 - k) // 2, x1 - (d - 1 - k) // 2, ytop - k, shade(col, 1.12 + 0.03 * k))
    c.rect(x0, ytop + 1, x1, ytop + 3, edge)
    c.hline(x0, x1, ytop + 1, shade(edge, 1.25))
    c.hline(x0, x1, ytop + 3, shade(edge, 0.65))


def _table_variants():
    return {k: {'t': k, 'for': v['for_']} for k, v in TABLES.items()}


@piece('table_kitchen', 62, 40, 'front', rooms={'kitchen': 8}, styles=None, tags=('dining', 'table'), variants=_table_variants(), limit=1, feet=(116, 120),
       anchors=({'name': 'table', 'dx': 24, 'dy': -26}, {'name': 'table_end', 'dx': 40, 'dy': -26}),
       note='the kitchen table of its style: a check oilcloth with a chair behind (classic), a formica dinette with two chrome chairs (retro), a pine table with a bench (country), a folding camping table (student), a trestle table loaded with shopping bags (hoarder)')
def table_kitchen(c, ox, oy, p):
    kind = p['t']
    W = TABLES[kind]['w']
    cx = ox + W // 2
    c.shadow(cx, oy + 1, W // 2 - 4, 2, 105)
    if kind == 'cloth':
        _chair(c, ox + 12, oy - 6, hexc('6a4a33'), tall=24)                                         # a chair tucked behind the table, only its back showing over the top
        top = oy - 24
        for lx in (ox + 4, ox + 40):
            c.rect(lx, top + 8, lx + 2, oy, hexc('5a3d29'))
            c.rect(lx + 4, top + 8, lx + 5, oy - 3, shade(hexc('5a3d29'), 0.75))
        c.rect(ox, top + 5, ox + 46, top + 7, shade(hexc('5a3d29'), 0.85))
        cloth, check = hexc('d9d2c0'), hexc('b0453a')
        for y in range(top - 3, top + 6):
            for x in range(ox - 2, ox + 49):
                on = ((x // 3) + (y // 2)) % 2 == 0
                c.put(x, y, check if on else cloth)
        c.hline(ox - 2, ox + 48, top - 3, shade(cloth, 0.9))
        for x in range(ox - 2, ox + 49):                                                            # the oilcloth hangs over the edge
            h = top + 6 + (2 if (x // 5) % 3 == 0 else 1)
            c.vline(x, top + 6, h, check if (x // 3) % 2 == 0 else cloth)
        K.frustum(c, ox + 10.0, top - 10, top - 4, 3.0, 4.2, hexc('4f6f8a'), ry_t=1.0, ry_b=1.2, rim=hexc('6a8aa4'), gloss=True)   # a teapot, a mug, a tin
        K.cyl(c, ox + 28.0, top - 8, top - 4, 2.2, hexc('e6dfcc'), ry=0.9, cap=True, gloss=True)
        K.cyl(c, ox + 38.0, top - 9, top - 4, 2.6, hexc('b0453a'), ry=1.0, cap=True)
        c.hline(ox + 35, ox + 40, top - 6, hexc('d8d2c2'))
    elif kind == 'dinette':
        _chair(c, ox + 2, oy, None, hexc('d8584a'), tall=30, chrome=True)
        _chair(c, ox + 44, oy, None, hexc('d8584a'), tall=30, chrome=True)
        top = oy - 22
        for lx in (ox + 12, ox + 42):
            c.vline(lx, top + 4, oy, hexc('b4bcc0')); c.vline(lx + 1, top + 4, oy, hexc('7a8286'))
        _top(c, ox + 6, ox + 50, top, hexc('d8584a'), hexc('d8584a'), d=5)
        c.hline(ox + 6, ox + 50, top + 1, hexc('b4bcc0'))                                           # the chrome trim round the formica
        c.hline(ox + 6, ox + 50, top + 4, hexc('7a8286'))
        for (sx, sy) in ((ox + 14, top - 2), (ox + 24, top - 3), (ox + 34, top - 1), (ox + 40, top - 3)):   # the speckle of the pattern
            c.put(sx, sy, hexc('f4d8d0'))
        c.rect(ox + 14, top - 7, ox + 19, top - 3, hexc('f0ece0')); c.hline(ox + 14, ox + 19, top - 7, hexc('ffffff'))    # a bread plate
        K.cyl(c, ox + 34.0, top - 8, top - 4, 2.4, hexc('3f6a8a'), ry=1.0, cap=True, gloss=True)
    elif kind == 'pine':
        top = oy - 24
        for lx in (ox + 4, ox + 54):
            c.rect(lx, top + 5, lx + 3, oy, hexc('b8895a')); c.vline(lx, top + 5, oy, hexc('d4a874')); c.vline(lx + 3, top + 5, oy, hexc('8a6238'))
        c.rect(ox + 6, oy - 8, ox + 56, oy - 7, hexc('9a6e44'))
        _top(c, ox, ox + 60, top, hexc('d4a874'), hexc('b8895a'), d=5)
        for gx in range(ox + 3, ox + 58, 9):
            c.put(gx, top - 2, shade(hexc('d4a874'), 0.9)); c.put(gx + 1, top - 3, shade(hexc('d4a874'), 0.9))
        # a bench along the front, the basket of vegetables on the table
        c.rect(ox + 4, oy - 14, ox + 56, oy - 12, hexc('b8895a')); c.hline(ox + 4, ox + 56, oy - 14, hexc('d4a874'))
        c.vline(ox + 8, oy - 11, oy, hexc('8a6238')); c.vline(ox + 52, oy - 11, oy, hexc('8a6238'))
        L = K.Layer(c)
        K.frustum(L.c, ox + 16.0, top - 9, top - 3, 6.5, 5.5, hexc('b08a52'), ry_t=1.6, ry_b=1.4, inner=hexc('3a2a18'), rim=hexc('d4a870'))
        K.sphere(L.c, ox + 14.0, top - 8.5, 2.2, 2.0, hexc('d8803a'), gloss=True)
        K.sphere(L.c, ox + 18.0, top - 9.0, 2.0, 2.0, hexc('a8c84a'), gloss=True)
        L.c.line(ox + 19, top - 10, ox + 22, top - 14, hexc('5a9a4a'))
        L.flush()
    elif kind == 'camping':
        top = oy - 22
        for lx, d in ((ox + 6, 1), (ox + 32, -1)):                                                  # a folding table: crossed steel legs
            c.line(lx, top + 3, lx + d * 9, oy, hexc('9aa1a3'))
            c.line(lx + d * 9, top + 3, lx, oy, hexc('737a7c'))
        _top(c, ox, ox + 38, top, hexc('b4bcc4'), hexc('8a929a'), d=4)
        c.rect(ox + 6, top - 6, ox + 12, top - 1, hexc('9aa1a3')); c.hline(ox + 6, ox + 12, top - 6, hexc('c4cacc'))     # a stack of dishes, a mug
        c.rect(ox + 18, top - 5, ox + 21, top - 1, hexc('ece6d4'))
        c.rect(ox + 28, top - 4, ox + 32, top - 1, hexc('3f6a8a'))
    else:
        top = oy - 24
        for lx in (ox + 4, ox + 46):
            c.rect(lx, top + 4, lx + 3, oy, hexc('5a3d29')); c.vline(lx, top + 4, oy, hexc('7a5a3c'))
        c.rect(ox + 4, oy - 7, ox + 49, oy - 6, hexc('4a3220'))
        _top(c, ox, ox + 52, top, hexc('6a4a33'), hexc('4a3220'), d=4)
        for k, bc in enumerate((hexc('e8e2d0'), hexc('c8483a'), hexc('e8e2d0'), hexc('3f6aa8'))):    # carrier bags in a row, handles up
            bx = ox + 2 + k * 12
            L = K.Layer(c)
            K.slab(L.c, bx, top - 13, bx + 9, top - 2, bc, d=2, inset=1)
            L.c.hline(bx + 2, bx + 7, top - 16, hexc('9aa0a4')); L.c.vline(bx + 2, top - 16, top - 14, hexc('9aa0a4')); L.c.vline(bx + 7, top - 16, top - 14, hexc('9aa0a4'))
            L.flush()
