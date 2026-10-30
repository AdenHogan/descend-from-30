"""THE DINING ROOM — the table with its chairs, the clock, the trolley, and the things set out on a table (owner round 47f: "expand to other module types too… a big pass").

A dining room is a SHELL (the bare room) plus PIECES laid by the planner, in five STYLES — family (the cloth-covered table, the Welsh dresser, the ladder-backed chairs), diner (the sixties
tulip table and chairs, the sideboard with the record player), formal (the long mahogany table, the portraits, the grandfather clock, the candelabra), houseshare (a bare pine table of a shared house, no two chairs alike, the takeaway
boxes still out) and party (the birthday table: bunting, balloons, a cake, party hats, a boombox). The long table carries its chairs: they stand BEHIND it, so the table covers
their legs (the kitchen table does the same).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chair3d as C3
import furn as F
import furnlib as FL
import propkit as K
from furnlib import piece
from pixlib import hexc, shade, mix
from furn_seats import WOODS, SEATS

BRASS, BRASS_LT = hexc('b89a48'), hexc('e4cc78')


def _chair(c, cx, by, style, wood, seat, yaw=0, fallen=None, srad=9):
    model = C3.dining_chair(style)
    if fallen:
        model = C3.fall(model, fallen, 6.0 * (1 if yaw >= 0 else -1))
    pal = {'wood': WOODS[wood], 'seat': SEATS[seat] if seat in SEATS else hexc(seat), 'fab': SEATS[seat] if seat in SEATS else hexc(seat)}
    return C3.draw_model(c, cx, by, model, yaw, pal, srad=srad, shadow='footprint' if fallen else 'round')


def _drape(c, x0, x1, y0, y1, col, pattern, rng):
    """A cloth hanging from the table's edge: folds in alternating tones, a hem, a pattern. Rows y0..y1."""
    lt, dk = shade(col, 1.12), shade(col, 0.82)
    for x in range(x0, x1 + 1):
        u = (x - x0) / float(max(1, x1 - x0))
        fold = int(math.floor(u * 11.0)) % 2
        for y in range(y0, y1 + 1):
            c.put(x, y, lt if fold == 0 else col)
        edge = (int(math.floor(u * 11.0 + 0.0)) - u * 11.0)
        if abs(edge) < 0.08:
            c.vline(x, y0, y1, dk)
    for x in range(x0, x1 + 1):                                                                    # a scalloped hem
        s = 1 if ((x - x0) // 3) % 2 == 0 else 0
        c.put(x, y1 + s, shade(col, 0.74))
    if pattern == 'lace':
        for y in range(y0 + 2, y1 - 1, 3):
            for x in range(x0 + 2 + (y // 3 % 2) * 2, x1 - 1, 4):
                c.put(x, y, shade(col, 0.9))
        for x in range(x0, x1 + 1, 2):
            c.put(x, y1 - 1, shade(col, 0.88))
    elif pattern == 'party':
        for k in range(40):
            c.put(rng.randint(x0, x1), rng.randint(y0, y1), hexc(rng.choice(('d8483a', '3a7ad8', 'e0b830', '3a9a52', 'a85ac8'))))


def _top_face(c, x0, x1, y_back, y_front, col, edge, inset=3):
    """The table top seen from a little above: a face from y_back to y_front, narrower at the back; a bright front lip."""
    n = y_front - y_back + 1
    for k in range(n):
        i = int(round(inset * (n - 1 - k) / float(max(1, n - 1))))
        c.hline(x0 + i, x1 - i, y_back + k, shade(col, 1.12 - 0.08 * (n - 1 - k) / float(max(1, n - 1))))
    c.hline(x0 + inset, x1 - inset, y_back - 1, shade(edge, 0.7))
    c.hline(x0, x1, y_front + 1, edge)


# ================================================================================================================================ the table
def _table_variants():
    return {
        'family': {'kind': 'family', 'for': ['family']},
        'diner': {'kind': 'diner', 'for': ['diner']},
        'formal': {'kind': 'formal', 'for': ['formal']},
        'party': {'kind': 'party', 'for': ['party']},
        'shared': {'kind': 'shared', 'for': ['houseshare']},
    }


@piece('table_dining', 92, 44, 'front', rooms={'dining_room': 10}, styles=None, tags=('dining', 'table'), variants=_table_variants(), limit=1, feet=(114, 118),
       slots=tuple({'id': 'top', 'dx0': 8, 'dx1': 84, 'dy': -26 if k != 'diner' else -27, 'top': True, 'kinds': ('table', 'small'), 'if': {'kind': k}} for k in ('family', 'diner', 'formal', 'party', 'shared')),
       anchors=({'name': 'table', 'dx': 30, 'dy': -26, 'top': True}, {'name': 'table_end', 'dx': 66, 'dy': -26, 'top': True}),
       note='the dining table with its chairs standing behind it: a lace-clothed family table with spindle chairs, a round sixties tulip table with two moulded chairs, a long bare mahogany table with high-backed chairs, a birthday table under a confetti cloth with small chairs — or a bare pine table of a shared house with three chairs that do not match')
def table_dining(c, ox, oy, p):
    k = p['kind']
    rng = random.Random(len(k) * 17)
    if k == 'diner':
        _diner(c, ox, oy)
        return
    top_y = oy - 22
    ground = oy - 3
    c.shadow(ox + 46, ground + 1, 46, 2, 105)
    if k == 'party':
        for cx, ys in ((ox + 8, 3), (ox + 84, 3)):                                                # small chairs at both ends, in front of the cloth
            pass
        for cx in (ox + 16, ox + 40, ox + 64):
            C3.draw_model(c, cx, oy - 9, _kid_chair(), 0, _kid_pal('d98aa0' if cx % 2 else '4a7ab0'), srad=8)
    elif k == 'formal':
        for cx in (ox + 14, ox + 40, ox + 66):
            _chair(c, cx, oy - 9, 'high', 'dark', 'cloth')
    elif k == 'shared':                                                                          # three chairs from three different sets
        for cx, st, wd, sk in ((ox + 14, 'ladder', 'dark', 'cloth'), (ox + 44, 'spindle', 'white', 'blue'), (ox + 74, 'ladder', 'green', 'rush')):
            _chair(c, cx, oy - 9, st, wd, sk)
    else:
        for cx in (ox + 16, ox + 46, ox + 76):
            _chair(c, cx, oy - 9, 'spindle', 'oak', 'rush')
    if k in ('formal', 'shared'):                                                                # bare wood: apron, four legs, a lipped top (mahogany, or the shared house's pine)
        wood, wl, wd = (hexc('6a3a2a'), hexc('8e5640'), hexc('3e2018')) if k == 'formal' else (hexc('b08a58'), hexc('d0aa72'), hexc('7a5a38'))
        for lx in (ox + 5, ox + 82):
            for dx in (0, 5):
                c.rect(lx + dx, top_y + 4, lx + dx + 1, ground, wd if dx else shade(wd, 1.15))
        _top_face(c, ox + 2, ox + 89, top_y - 5, top_y - 1, wl, wd, 4)
        c.rect(ox + 2, top_y, ox + 89, top_y + 2, wood)
        c.hline(ox + 2, ox + 89, top_y, shade(wl, 1.2))
        c.hline(ox + 2, ox + 89, top_y + 3, wd)
        c.rect(ox + 8, top_y + 3, ox + 83, top_y + 5, shade(wd, 1.1))                               # the apron
        c.hline(ox + 8, ox + 83, top_y + 3, shade(wl, 0.8))
        for x in range(ox + 14, ox + 80, 9):
            c.put(x, top_y + 1, shade(wl, 1.05))
    else:
        cloth = hexc('ece4cc') if k == 'family' else hexc('f2f0ea')
        for lx in (ox + 6, ox + 83):                                                               # the legs show below the cloth's hem
            c.rect(lx, ground - 5, lx + 1, ground, hexc('6a4a2e'))
        _top_face(c, ox + 2, ox + 89, top_y - 5, top_y - 1, cloth, shade(cloth, 0.7), 4)
        _drape(c, ox + 2, ox + 89, top_y, top_y + (10 if k == 'family' else 13), cloth, 'lace' if k == 'family' else 'party', rng)
    # whatever stands on the table is a separate piece (slot 'top')


def _kid_chair():
    import furn_seats as FS
    return FS.scaled(C3.dining_chair('ladder'), 0.68)


def _kid_pal(hexcol):
    col = hexc(hexcol)
    return {'wood': col, 'seat': shade(col, 1.25), 'fab': col}


def _diner(c, ox, oy):
    """A round tulip table (white pedestal, formica top) with two moulded chairs behind it, orange."""
    ground = oy - 3
    c.shadow(ox + 46, ground + 1, 40, 2, 105)
    shell = hexc('f0ece0')
    for cx, yaw in ((ox + 18, 0), (ox + 74, 0)):
        pal = {'shell': hexc('e8742a'), 'fab': hexc('f0e0c0')}
        C3.draw_model(c, cx, oy - 9, C3.tulip_chair(), yaw, pal, srad=10)
    pal = {'shell': shell, 'top': hexc('e8dfc8')}
    C3.draw_model(c, ox + 46, ground, C3.tulip_table(28.0), 0, pal, srad=24)


# ================================================================================================================================ things on the table
@piece('candelabra', 14, 24, 'top', rooms={'dining_room': 6}, styles={'formal': 8, 'family': 1, 'houseshare': 0.01}, tags=('small', 'light'), on=('table',), limit=1,
       variants={'silver': {'col': 'c8ccd0'}, 'brass': {'col': 'c8a050'}}, lights=({'dx': 7, 'dy': -20, 'kind': 'lantern', 'top': True},),
       note='a three-branch candelabrum with a candle in each arm, the flames small and warm')
def candelabra(c, ox, oy, p):
    col = hexc(p['col'])
    K.contact_shadow(c, ox + 7, oy + 0.5, 7, 1.3, 95)
    L = K.Layer(c)
    lc = L.c
    K.cyl(lc, ox + 7, oy - 2, oy - 1, 3.2, col, ry=1.0, gloss=True)                              # the foot
    lc.vline(ox + 7, oy - 12, oy - 2, col)
    K.sphere(lc, ox + 7, oy - 6, 1.6, 1.6, col, gloss=True)
    lc.line(ox + 3, oy - 12, ox + 11, oy - 12, col)                                              # the arms: a shallow vee
    lc.line(ox + 3, oy - 12, ox + 3, oy - 10, col)
    lc.line(ox + 11, oy - 12, ox + 11, oy - 10, col)
    for cx in (ox + 3, ox + 7, ox + 11):
        lc.rect(cx, oy - 18 if cx == ox + 7 else oy - 17, cx, oy - 13 if cx == ox + 7 else oy - 12, hexc('ece4cc'))
        lc.put(cx, oy - 19 if cx == ox + 7 else oy - 18, hexc('f8d870'))
    L.flush()


@piece('vase_flowers', 12, 22, 'top', rooms={'dining_room': 7, 'living_room': 2}, styles={'family': 6, 'diner': 6, 'formal': 4, 'cosy': 4, 'parlour': 3}, tags=('small', 'plant'), on=('table', 'small'), limit=1,
       variants={'tulips': {'bloom': 'e8503a', 'vase': '8ab4c0'}, 'daisies': {'bloom': 'f4f0e0', 'vase': 'c8a860'}, 'dead': {'bloom': '6a5a3a', 'vase': '8ab4c0', 'dead': True}},
       note='a glass vase of tulips or daisies on the table — or the same flowers long dead, brown heads hanging over the rim')
def vase_flowers(c, ox, oy, p):
    K.contact_shadow(c, ox + 6, oy + 0.5, 6, 1.2, 90)
    L = K.Layer(c)
    lc = L.c
    vase, bloom = hexc(p['vase']), hexc(p['bloom'])
    dead = p.get('dead', False)
    K.frustum(lc, ox + 6, oy - 8, oy - 1, 2.6, 3.6, vase, ry_t=1.0, ry_b=1.0, inner=shade(vase, 0.5), rim=shade(vase, 1.3), gloss=True)
    for dx, h in ((-3, 9), (0, 12), (3, 8)):
        sx = ox + 6 + dx
        lc.vline(sx, oy - 8 - h, oy - 8, hexc('5a7a3a') if not dead else hexc('6a5a38'))
        by = oy - 9 - h + (3 if dead else 0)
        for (ddx, ddy) in ((0, 0), (-1, 1), (1, 1), (0, 2)) if not dead else ((0, 0), (1, 1), (0, 2)):
            lc.put(sx + ddx, by + ddy, bloom)
        lc.put(sx, by + 1, shade(bloom, 1.3) if not dead else shade(bloom, 0.7))
    L.flush()


@piece('place_settings', 30, 6, 'top', rooms={'dining_room': 8}, styles={'family': 8, 'formal': 8, 'party': 2, 'diner': 3}, tags=('small', 'food'), on=('table',), limit=1,
       variants={'plain': {'plate': 'f0ece0', 'rim': '9ab0c8'}, 'gilt': {'plate': 'f4f0e4', 'rim': 'c9a24e'}, 'messy': {'plate': 'ece4cc', 'rim': '9ab0c8', 'messy': True}},
       note='three places laid: a plate, a knife and a fork either side — or the plates left with a meal half eaten and a toppled glass')
def place_settings(c, ox, oy, p):
    import furn_small3d
    furn_small3d.place_settings(c, ox, oy, p)


@piece('cake_party', 20, 20, 'top', rooms={'dining_room': 7}, styles={'party': 9}, tags=('small', 'food'), on=('table',), limit=1,
       variants={'pink': {'ic': 'f0a8b8'}, 'blue': {'ic': '9ac4f0'}},
       note='a birthday cake on a stand: two tiers of iced sponge, a ring of candles, a slice cut out and left on a plate')
def cake_party(c, ox, oy, p):
    ic = hexc(p['ic'])
    K.contact_shadow(c, ox + 10, oy + 0.5, 10, 1.4, 95)
    L = K.Layer(c)
    lc = L.c
    K.cyl(lc, ox + 10, oy - 3, oy - 1, 8.0, hexc('e8e0d0'), ry=1.4)                              # the stand
    K.cyl(lc, ox + 10, oy - 9, oy - 4, 7.0, hexc('d8a868'), ry=2.0, cap_col=ic)
    K.cyl(lc, ox + 10, oy - 14, oy - 10, 4.6, hexc('d8a868'), ry=1.4, cap_col=shade(ic, 1.08))
    lc.put(ox + 6, oy - 8, hexc('c8483a')); lc.put(ox + 13, oy - 7, hexc('3a7ad8')); lc.put(ox + 10, oy - 6, hexc('e0b830'))   # sprinkles
    for cx in (ox + 7, ox + 10, ox + 13):                                                         # candles with flames
        lc.vline(cx, oy - 19, oy - 15, hexc('f0f0f0') if cx % 2 else hexc('e8a0b0'))
        lc.put(cx, oy - 20, hexc('f8d870'))
    L.flush()


@piece('party_hats', 22, 12, 'top', rooms={'dining_room': 7}, styles={'party': 9}, tags=('small',), on=('table',), limit=1,
       variants={'a': {'cols': ('d8483a', '3a7ad8', '3a9a52')}, 'b': {'cols': ('e0b830', 'a85ac8', 'd8483a')}},
       note='paper party hats, striped and tilted, with a few left on their sides')
def party_hats(c, ox, oy, p):
    cols = [hexc(k) for k in p['cols']]
    L = K.Layer(c)
    lc = L.c
    for k, col in enumerate(cols):
        cx = ox + 4 + k * 7
        lean = (-1, 1, 0)[k]
        for yy in range(oy - 11, oy):
            hw = 1 + (yy - (oy - 11)) // 3
            lc.hline(cx - hw + (lean * (oy - yy) // 5), cx + hw + (lean * (oy - yy) // 5), yy, col if (yy // 2) % 2 else shade(col, 1.25))
        lc.put(cx + lean * 2, oy - 12, hexc('f8f0c8'))
    L.flush()


@piece('boombox', 22, 16, 'top', rooms={'dining_room': 5, 'living_room': 3}, styles={'party': 8, 'diner': 2, 'squat': 5}, tags=('small', 'music'), on=('table', 'small', 'tv'), limit=1,
       variants={'black': {'body': '2a2a2e'}, 'silver': {'body': '9aa0a4'}},
       anchors=({'name': 'boombox', 'dx': 11, 'dy': -8, 'top': True},),
       note='a boombox: two speaker cones, a tape deck with a window, a row of buttons and a telescopic aerial')
def boombox(c, ox, oy, p):
    body = hexc(p['body'])
    K.contact_shadow(c, ox + 11, oy + 0.5, 11, 1.4, 95)
    L = K.Layer(c)
    lc = L.c
    K.slab(lc, ox + 1, oy - 12, ox + 20, oy - 1, body, d=2, top=shade(body, 1.3))
    for cx in (ox + 5, ox + 16):
        K.sphere(lc, cx, oy - 6, 3.6, 3.6, shade(body, 0.7))
        K.sphere(lc, cx, oy - 6, 1.6, 1.6, shade(body, 1.4))
    lc.rect(ox + 8, oy - 10, ox + 13, oy - 7, hexc('1a1a1e'))
    lc.rect(ox + 9, oy - 9, ox + 12, oy - 8, hexc('c8a050'))
    for bx in range(ox + 8, ox + 14, 2):
        lc.put(bx, oy - 5, hexc('c8c8c0'))
    lc.line(ox + 18, oy - 13, ox + 22, oy - 22, hexc('b8bcc0'))
    L.flush()


@piece('record_player', 22, 12, 'top', rooms={'dining_room': 5, 'living_room': 4}, styles={'diner': 8, 'mid': 5, 'parlour': 2}, tags=('small', 'music'), on=('table', 'small', 'tv'), limit=1,
       variants={'teak': {'case': '9a6234'}, 'white': {'case': 'e8e4d8'}},
       anims=({'kind': 'spin', 'dx': 7, 'dy': -8, 'w': 10, 'h': 3, 'color': '1a1a1e', 'top': True},),
       note='a record player in a teak case: the lid up, a black record on the turntable and the tonearm over it')
def record_player(c, ox, oy, p):
    case = hexc(p['case'])
    K.contact_shadow(c, ox + 11, oy + 0.5, 11, 1.4, 95)
    L = K.Layer(c)
    lc = L.c
    K.slab(lc, ox + 1, oy - 6, ox + 20, oy - 1, case, d=3, top=shade(case, 1.15))
    K.ell(lc, ox + 10, oy - 7.5, 8.0, 2.2, hexc('1a1a1e'))
    K.ell(lc, ox + 10, oy - 7.5, 2.0, 0.8, hexc('c8483a'))
    lc.line(ox + 19, oy - 11, ox + 12, oy - 8, hexc('c8ccd0'))
    L.flush()


@piece('bottles_row', 22, 14, 'top', rooms={'dining_room': 5, 'living_room': 2}, styles={'formal': 5, 'family': 3, 'diner': 2}, tags=('small', 'food'), on=('table', 'small'), limit=1,
       variants={'wine': {'cols': ('3a5a3a', '6a2a2a', '3a5a3a')}, 'spirits': {'cols': ('c8a050', '4a6a8a', '6a2a2a')}},
       note='three bottles stood in a row: dark wine bottles or a decanter set, the labels pale')
def bottles_row(c, ox, oy, p):
    L = K.Layer(c)
    lc = L.c
    K.contact_shadow(c, ox + 11, oy + 0.5, 11, 1.2, 90)
    for k, hx in enumerate(p['cols']):
        col = hexc(hx)
        cx = ox + 4 + k * 7
        K.cyl(lc, cx, oy - 8, oy - 1, 2.4, col, ry=0.8, gloss=True)
        K.cyl(lc, cx, oy - 13, oy - 8, 1.1, col, ry=0.5, gloss=True)
        lc.rect(int(cx) - 1, oy - 6, int(cx), oy - 3, hexc('e8dcc0'))
        lc.put(int(cx), oy - 14, hexc('c8a050'))
    L.flush()


# ================================================================================================================================ the grandfather clock
@piece('clock_grandfather', 20, 78, 'wall', rooms={'dining_room': 6, 'living_room': 3}, styles={'formal': 9, 'family': 2, 'parlour': 3, 'cosy': 1}, tags=('clock', 'storage'), depth=5,
       variants={'mahogany': {'wood': '6a3a2a'}, 'oak': {'wood': 'a07848'}},
       anchors=({'name': 'clock', 'dx': 10, 'dy': -40},), feet=(105, 108),
       anims=({'kind': 'pendulum', 'dx': 10, 'dy': -45, 'fall': 25, 'w': 4, 'color': 'd8b860'},),
       note='a grandfather clock: a hooded case with a pale round dial and roman numerals, a long glass door showing a brass pendulum that SWINGS (module_anim `pendulum`, a swing a second) between two weights, a plinth')
def clock_grandfather(c, ox, oy, p):
    wood = hexc(p['wood'])
    wl, wd = shade(wood, 1.3), shade(wood, 0.6)
    x0, x1 = ox + 1, ox + 18
    top, base = oy - 76, oy
    c.shadow((x0 + x1) // 2, base + 1, 12, 2, 100)
    c.rect(x0 + 2, top, x1 - 2, top + 2, wl)                                                      # the pediment
    c.hline(x0 + 2, x1 - 2, top, shade(wl, 1.2))
    c.rect(x0, top + 3, x1, top + 24, wood)                                                       # the hood
    c.vline(x0, top + 3, top + 24, wl)
    c.vline(x1, top + 3, top + 24, wd)
    K.ell(c, (x0 + x1) / 2.0 + 0.5, top + 14, 7.0, 7.0, hexc('c8a050'))                          # a brass ring round the dial
    K.ell(c, (x0 + x1) / 2.0 + 0.5, top + 14, 6.4, 6.4, hexc('d6cdb6'))                          # the dial
    K.ell(c, (x0 + x1) / 2.0 + 0.5, top + 14, 5.2, 5.2, hexc('ece6d4'))
    for k in range(12):                                                                          # hour marks
        a = math.radians(k * 30)
        c.put(int((x0 + x1) / 2.0 + 0.5 + math.sin(a) * 4.4), int(top + 14 - math.cos(a) * 4.4), hexc('2a2018'))
    c.line(int((x0 + x1) / 2.0 + 0.5), top + 14, int((x0 + x1) / 2.0 + 0.5) + 2, top + 11, hexc('1a1410'))
    c.line(int((x0 + x1) / 2.0 + 0.5), top + 14, int((x0 + x1) / 2.0 + 0.5) - 1, top + 10, hexc('1a1410'))
    c.rect(x0 + 1, top + 25, x1 - 1, top + 28, wl)                                                # the waist
    c.hline(x0 + 1, x1 - 1, top + 26, hexc('d8b860'))                                             # a brass band along it
    c.rect(x0 + 2, top + 29, x1 - 2, base - 12, wood)                                             # the long case with its glass door
    c.rect(x0 + 4, top + 31, x1 - 4, base - 14, hexc('2a2018'))
    c.vline(x1 - 3, top + 29, base - 13, wd)                                                      # the door's hinge-side edge, in shadow
    c.put(x1 - 3, top + 40, hexc('e8d080')); c.put(x1 - 3, top + 41, hexc('e8d080'))             # a brass catch
    # (no pendulum here: the rod and its bob are live — module_anim `pendulum`, hung from (ox + 10, top + 31); the weights hang out at the sides so it swings between them)
    for wx in (x0 + 4, x1 - 5):                                                                  # two weights hanging, two px wide, lit on the left
        c.vline(wx, top + 31, top + 44, hexc('8a7a50'))
        c.rect(wx, top + 45, wx, top + 52, hexc('d0b058'))
        c.rect(wx + 1, top + 45, wx + 1, top + 52, hexc('9a8038'))
    for (gy0, gy1) in ((top + 31, top + 43), (top + 54, base - 14)):                              # the glass glint, down the door's own left edge (broken where the left weight hangs; the pendulum swings clear of it)
        c.vline(x0 + 4, gy0, gy1, hexc('9ab0b8'))
    c.rect(x0, base - 11, x1, base - 5, wl)                                                       # the plinth
    c.hline(x0, x1, base - 11, shade(wl, 1.2))
    c.rect(x0 - 1, base - 4, x1 + 1, base - 1, wood)
    c.hline(x0 - 1, x1 + 1, base - 4, wl)
    c.rect(x0 - 1, base, x1 + 1, base, wd)


# ================================================================================================================================ the drinks trolley
@piece('trolley_drinks', 30, 34, 'floor', keep='stand', rooms={'dining_room': 5, 'living_room': 2}, styles={'family': 5, 'formal': 5, 'diner': 2}, tags=('clutter', 'storage'), limit=1,
       variants={'brass': {'col': 'c8a050'}, 'chrome': {'col': 'b8bcc0'}},
       anchors=({'name': 'trolley', 'dx': 15, 'dy': -16},), feet=(110, 120), near=('table', 'storage'),
       note='a two-tier drinks trolley on castors: brass rails, bottles and a soda siphon on the top shelf, glasses and an ice bucket below')
def trolley_drinks(c, ox, oy, p):
    col = hexc(p['col'])
    K.contact_shadow(c, ox + 15, oy + 0.5, 16, 1.6, 100)
    L = K.Layer(c)
    lc = L.c
    for lx in (ox + 3, ox + 26):                                                                  # the uprights and castors
        lc.vline(lx, oy - 31, oy - 2, col)
        lc.vline(lx + 1, oy - 31, oy - 2, shade(col, 0.7))
        lc.rect(lx - 1, oy - 1, lx + 2, oy, hexc('2a2a2e'))
    for sy in (oy - 30, oy - 14):                                                                 # two shelves
        lc.rect(ox + 3, sy, ox + 27, sy + 1, hexc('3a2a22'))
        lc.hline(ox + 3, ox + 27, sy - 1, col)
        lc.hline(ox + 3, ox + 27, sy + 2, shade(col, 0.6))
    for k, hc in enumerate(('3a5a3a', '6a2a2a', 'c8a050')):                                       # bottles on the top shelf
        cx = ox + 7 + k * 5
        K.cyl(lc, cx, oy - 38, oy - 31, 1.9, hexc(hc), ry=0.7, gloss=True)
        K.cyl(lc, cx, oy - 42, oy - 38, 0.9, hexc(hc), ry=0.4)
    K.cyl(lc, ox + 23, oy - 40, oy - 31, 2.4, hexc('9ab4c0'), ry=0.9, gloss=True)               # a soda siphon
    lc.put(ox + 23, oy - 42, hexc('c8ccd0'))
    for k in range(4):                                                                            # glasses and an ice bucket on the lower shelf
        K.frustum(lc, ox + 7 + k * 4, oy - 20, oy - 15, 1.6, 1.2, hexc('c8e0ec'), ry_t=0.6, ry_b=0.5, inner=hexc('8ab0bc'))
    K.frustum(lc, ox + 22, oy - 22, oy - 15, 3.6, 3.0, hexc('c8ccd0'), ry_t=1.2, ry_b=1.0, inner=hexc('9aa4a8'), gloss=True)
    L.flush()


# ================================================================================================================================ the party
@piece('banner_party', 56, 22, 'decor', rooms={'dining_room': 6}, styles={'party': 9}, tags=('picture', 'party'), wall_y=(20, 34), limit=1, variants={'rainbow': {}},
       note='a HAPPY BIRTHDAY banner of printed letters on a paper strip, under a swag of coloured bunting')
def banner_party(c, ox, oy, p):
    import wall_art3d
    wall_art3d.banner_party(c, ox, oy, p)


@piece('balloons', 14, 36, 'top', rooms={'dining_room': 6}, styles={'party': 9}, tags=('party',), on=('table',), limit=2,
       variants={'bunch': {'cols': ('4a7ab8', 'd8483a', 'e0b830')}, 'pair': {'cols': ('a85ac8', '3a9a52')}},
       note='a bunch of helium balloons on curling ribbon, tied to a little foil weight standing on the table (never loose against a wall: the ribbons end ON something)')
def balloons(c, ox, oy, p):
    """Owner round 48i: "These balloons are hanging on nothing." They are a TOP piece now: the ribbons gather in a knot on a small foil weight that stands on the table, the balloons
    float above it."""
    K.contact_shadow(c, ox + 7, oy + 0.5, 3.6, 1.0, 110)
    L = K.Layer(c)
    lc = L.c
    cols = [hexc(k) for k in p['cols']]
    wx, wy = ox + 7, oy - 2                                                                       # the weight: a foil-wrapped lump
    K.sphere(lc, wx, wy, 2.4, 2.0, hexc('b4bac4'), gloss=True)
    lc.put(wx - 1, wy - 1, hexc('f4f6fa'))
    spots = ((4.2, -25.0), (9.8, -26.5), (7.0, -31.0)) if len(cols) > 2 else ((4.8, -25.0), (9.2, -27.5))
    knot = (wx, wy - 3)
    for k, col in enumerate(cols):
        bx, by = spots[k]
        cx, cy = ox + bx, oy + by
        lc.line(int(cx), int(cy + 5), knot[0], knot[1], hexc('d8d0c0'))                           # the ribbon, down to the knot on the weight
        K.sphere(lc, cx, cy, 3.9, 4.7, col, gloss=True)
        lc.put(int(cx), int(cy + 5.2), shade(col, 0.55))                                         # the tied end
    lc.put(knot[0], knot[1], hexc('f0eadc'))
    L.flush()


@piece('portraits_row', 78, 32, 'decor', rooms={'dining_room': 5, 'living_room': 3}, styles={'formal': 9, 'parlour': 3}, tags=('picture',), wall_y=(24, 38), limit=1, variants={'three': {}},
       note='three oil portraits hung in a row: a lady, a gentleman and an old man — the gallery\'s painter at the same size as the single portrait (owner round 49f: "they look like Terrence and Phillip from South Park")')
def portraits_row(c, ox, oy, p):
    import wallart as W
    import portrait_gallery as PG
    for k, (who, nth) in enumerate((('woman', 0), ('man', 0), ('old_man', 0))):
        spec = PG.SPECS[PG.pick(who, 'oil', nth)]
        spec = dict(spec, frame='gilt')
        x0 = ox + k * 26
        r = W.frame(c, x0, oy, x0 + 24, oy + 30, 'gilt', mat=hexc('3a2e22'), thick=1, hang='wire', lip=True, matw=1)
        PG.paint(c, r[0], r[1], r[2], r[3], dict(spec, kind='oil'))
        W.glint(c, r)


@piece('gifts_pile', 26, 18, 'floor', keep='party', rooms={'dining_room': 5}, styles={'party': 9}, tags=('clutter', 'party'), limit=1,
       variants={'a': {'cols': ('d8483a', '3a7ad8', 'e0b830')}, 'b': {'cols': ('a85ac8', '3a9a52', 'd8483a')}},
       anchors=({'name': 'presents', 'dx': 12, 'dy': -8},), feet=(108, 121), near=('table',),
       note='three wrapped presents on the floor, one on top of the other two, ribbons and bows, a gift tag hanging off the nearest')
def gifts_pile(c, ox, oy, p):
    K.contact_shadow(c, ox + 13, oy + 0.5, 13, 1.5, 100)
    L = K.Layer(c)
    lc = L.c
    cols = [hexc(k) for k in p['cols']]
    boxes = [(ox + 1, oy - 9, 13, 9, cols[0]), (ox + 14, oy - 7, 11, 7, cols[1]), (ox + 5, oy - 15, 10, 6, cols[2])]
    for (x, y, w, h, col) in boxes:
        K.slab(lc, x, y, x + w - 1, y + h - 1, col, d=2, top=shade(col, 1.25))
        lc.vline(x + w // 2, y - 2, y + h - 1, hexc('f4f0e0'))                                           # the ribbon
        lc.hline(x, x + w - 1, y + h // 2, hexc('f4f0e0'))
        lc.put(x + w // 2 - 1, y - 3, hexc('f4f0e0')); lc.put(x + w // 2 + 1, y - 3, hexc('f4f0e0'))     # the bow
    lc.put(ox + 22, oy - 4, hexc('f0ece0'))
    L.flush()
