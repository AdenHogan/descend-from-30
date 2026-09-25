"""Corridor art for floors 1-29 (building_floors) — a painted overlay replacing the old tile look.

Run:  python3 tools/art/corridor.py
Out:  assets/corridor/corridor_<section>_w<wear><variant>.png (+ _r2 / _r3 run looks),
      corridor_hallway / corridor_lobby, fire_<zone>.png overlays; previews in
      docs/art_reference/corridor/.

One 1120 x 192 image covers the corridor band exactly (world x 115..1235, y 243..435 — the
tilemap's used rect; building_floors.add_corridor_art puts it just above the TileMapLayer, so
doors, stairs, the elevator, lamps, fire and actors all still draw over it). Rows (local y):
  0..15    ceiling + cornice
  16..95   wall (paper / paint)
  96..153  dado rail + wainscot / lower wall
  154..159 skirting
  160..191 floor, feet line at 176 (world 419)
The two stairwell recesses (local x 16..95 and 1024..1103) get a dim stairwell wall + a framed
opening; the staircase sprites draw over them.

SECTIONAL IDENTITY (docs/ART_REQUIREMENTS.md) — three looks, owner-approved (round 12):
  high (21-29) a faded HOTEL-like hallway: teal damask, mahogany panels, a red runner;
  mid  (11-20) tired RESIDENTIAL: mustard stripes, cream tongue-and-groove, brown runner;
  low  (1-10)  INSTITUTIONAL: two-tone gloss paint, a painted line, pipes, checker lino.
Each look has three near-identical VARIANTS a/b/c (palette shift, picture order, one extra
fixture), picked per floor (building_floors.corridor_variant).

DILAPIDATION, three layers of it:
  DEPTH  a wear level by floor (building_floors.corridor_wear: 29-24 -> 0 .. 5-1 -> 4), baked in:
         damp + tide marks, cracks, paper torn to the plaster, holes to the blockwork, kicked-in
         panels, tags, a worn / torn runner, bin bags; pictures go askew, then missing, then fall.
  TIME   run 2 / run 3 redraw the SAME corridor and add more of the same damage + blood (the day
         wears on — the time skip), and the pictures keep failing where they were already loose.
  FIRE   fire_<zone>.png (l / m / r / lm / mr / all): soot plumes up the walls and over the door
         heads, a blackened ceiling, charred runner, ash along the skirting. Drawn ABOVE the
         doors at runtime, picked from where fire has actually burned on that floor
         (WorldState.fire_scar_zone) — the scars stay after the fire is out, and across runs.
Wear never lands on a door, picture, fixture, stair or the elevator (Spots).
"""
import math
import os
import random
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, mix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CW, CH = 1120, 192
RECESS = ((16, 95), (1024, 1103))           # stair openings (the staircase art covers these)
PILASTER = ((0, 15), (96, 111), (1008, 1023), (1104, 1119))
DOORS = [201, 329, 455, 581, 714]            # apartment doors (local x centres), ±28
ELEVATOR = (880, 950)
KIT_X = 814                                  # wall extinguisher / maintenance door
WALL_TOP, RAIL_Y, SKIRT_Y, FLOOR_Y = 16, 96, 154, 160
SPOTS = [265, 392, 518, 647]                 # between doors: pictures / notices
LAYOUT = {'recess': (0, 1), 'spots': SPOTS}  # set per scene (hallway: left stair only; lobby: right)
DOOR_TOP = 74                                # door sprites cover y >= ~79 at DOORS ±28
ELEV_TOP = 64                                # the elevator sprite covers y >= ~69
EXIT_SIGN = (860, 40, 872, 50)
# wear geometry, set per section (set_geom): the dado rail's top, the lower wall's top, skirting
DADO_Y, LOWER_Y, SKIRT_TOP = RAIL_Y, 100, SKIRT_Y
G = {}


def clear_of_openings(x):
    for (a, b) in [RECESS[i] for i in LAYOUT['recess']]:
        if a - 4 <= x <= b + 20:
            return False
    return True


# --- pieces ----------------------------------------------------------------------------------
def ceiling(c, col, cornice, cornice_hi):
    c.rect(0, 0, CW - 1, 9, shade(col, 0.8))
    c.dither(0, 6, CW - 1, 9, shade(col, 0.7), 0.5)
    c.rect(0, 10, CW - 1, 15, cornice)
    c.hline(0, CW - 1, 10, cornice_hi)
    c.hline(0, CW - 1, 12, shade(cornice, 0.85))
    c.hline(0, CW - 1, 15, shade(cornice, 0.6))


def recesses(c, wall):
    """The stairwell shafts behind the openings: a dim wall with a darker band at the top."""
    dim = shade(wall, 0.45)
    for (a, b) in [RECESS[i] for i in LAYOUT['recess']]:
        c.rect(a, WALL_TOP, b, FLOOR_Y - 1, dim)
        c.dither(a, WALL_TOP, b, WALL_TOP + 20, shade(dim, 0.7), 0.5)
        c.vline(a, WALL_TOP, FLOOR_Y - 1, shade(dim, 0.6))
        c.vline(b, WALL_TOP, FLOOR_Y - 1, shade(dim, 0.6))


def pilasters(c, col, hi, out):
    """Moulded door-casing pilasters framing each stair opening + the corridor's end walls."""
    inner = {0: PILASTER[1], 1: PILASTER[2]}
    for (a, b) in [PILASTER[0], PILASTER[3]] + [inner[i] for i in LAYOUT['recess']]:
        c.rect(a, WALL_TOP - 2, b, FLOOR_Y - 1, col)
        c.vline(a, WALL_TOP - 2, FLOOR_Y - 1, out)
        c.vline(b, WALL_TOP - 2, FLOOR_Y - 1, out)
        c.vline(a + 2, WALL_TOP, FLOOR_Y - 4, hi)
        c.vline(b - 3, WALL_TOP, FLOOR_Y - 4, shade(col, 0.8))
        c.rect(a, FLOOR_Y - 8, b, FLOOR_Y - 1, shade(col, 0.8))           # plinth block
        c.hline(a, b, FLOOR_Y - 8, hi)
    for (a, b) in [RECESS[i] for i in LAYOUT['recess']]:                   # the lintel over each opening
        c.rect(a, WALL_TOP - 2, b, WALL_TOP + 2, col)
        c.hline(a, b, WALL_TOP + 2, out)
        c.hline(a, b, WALL_TOP - 1, hi)


def floor_boards(c, cols, seam):
    rows = [160, 164, 169, 175, 182, 192]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        col = cols[r % len(cols)]
        c.rect(0, y0, CW - 1, y1, col)
        c.hline(0, CW - 1, y1, seam)
        for x in range((r * 29) % 64, CW, 64):
            c.vline(x, y0, y1, seam)
    c.hline(0, CW - 1, FLOOR_Y, shade(cols[0], 0.5))


def runner(c, base, border, pattern, y0=166, y1=186):
    c.rect(0, y0, CW - 1, y1, base)
    c.hline(0, CW - 1, y0, border)
    c.hline(0, CW - 1, y0 + 1, border)
    c.hline(0, CW - 1, y1, border)
    c.hline(0, CW - 1, y1 - 1, border)
    for x in range(0, CW, 16):
        cy = (y0 + y1) // 2
        c.put(x + 8, cy - 2, pattern); c.put(x + 7, cy - 1, pattern); c.put(x + 9, cy - 1, pattern)
        c.put(x + 6, cy, pattern); c.put(x + 10, cy, pattern)
        c.put(x + 7, cy + 1, pattern); c.put(x + 9, cy + 1, pattern); c.put(x + 8, cy + 2, pattern)
    for x in range(0, CW, 2):                                               # worn fibre
        if (x * 7) % 5 == 0:
            c.put(x, y0 + 4 + (x % 11), shade(base, 1.12))


def frame(c, cx, y0, w, h, fr, fill):
    x0 = cx - w // 2
    c.box(x0, y0, x0 + w, y0 + h, fr, shade(fr, 0.55))
    c.rect(x0 + 2, y0 + 2, x0 + w - 2, y0 + h - 2, fill)
    c.line(x0 + 3, y0, cx, y0 - 7, shade(fr, 0.55))
    c.line(x0 + w - 3, y0, cx, y0 - 7, shade(fr, 0.55))


def exit_sign(c):
    c.box(860, 40, 872, 50, hexc('2e5a3a'), hexc('1a3020'))                    # a green EXIT sign
    c.rect(862, 43, 870, 46, hexc('d8e8c8'))


def light_switches(c, plate):
    for d in DOORS:                                                          # beside every door
        x, y0 = d + 35, 86
        c.box(x - 2, y0, x + 2, y0 + 5, plate, shade(plate, 0.62))
        c.put(x, y0 + 2, shade(plate, 0.5))


def doormats(c, mats, lvl):
    """A mat outside some flats — the residents who still bother. Fewer and filthier lower down."""
    for i in (mats[:max(0, len(mats) - lvl // 2)] if lvl < 4 else ()):
        d = DOORS[i] + (3 if lvl >= 2 and i % 2 else 0)
        col = shade(hexc('9a7448' if i % 2 else '5a6a58'), 1.0 - 0.07 * lvl)
        x0, x1, y0, y1 = d - 15, d + 15, 161, 167
        c.rect(x0, y0, x1, y1, col)
        c.hline(x0, x1, y0, shade(col, 1.1))
        c.hline(x0, x1, y1, shade(col, 0.6))
        c.vline(x0, y0, y1, shade(col, 0.75))
        c.vline(x1, y0, y1, shade(col, 0.7))
        for x in range(x0 + 2, x1 - 1, 2):
            c.vline(x, y0 + 2, y1 - 2, shade(col, 0.88))


def radiator(c, cx, body=hexc('e2ded2')):
    x0, x1, y0, y1 = cx - 17, cx + 17, 126, 146
    c.rect(x0, y0, x1, y1, body)
    for x in range(x0 + 2, x1, 3):
        c.vline(x, y0 + 2, y1 - 1, shade(body, 0.86))
    c.hline(x0, x1, y0, shade(body, 1.06))
    c.hline(x0, x1, y1, shade(body, 0.66))
    c.vline(x0, y0, y1, shade(body, 0.8))
    c.vline(x1, y0, y1, shade(body, 0.72))
    c.rect(x0 - 3, y1 - 3, x0 - 1, y1 - 1, hexc('c8c6be'))                   # valve + pipe to the floor
    c.vline(x0 - 2, y1, FLOOR_Y - 1, hexc('b8b6ae'))


def console_table(c, cx, wood, top):
    """A hotel console under a picture: a narrow table against the panelling, a vase on it."""
    x0, x1 = cx - 15, cx + 15
    c.rect(x0, 126, x1, 129, top)
    c.hline(x0, x1, 126, shade(top, 1.2))
    c.hline(x0, x1, 129, shade(top, 0.6))
    c.rect(x0 + 1, 130, x1 - 1, 133, wood)
    for x in (x0 + 2, x1 - 3):
        c.rect(x, 134, x + 1, FLOOR_Y + 2, shade(wood, 0.8))
    c.rect(cx - 3, 116, cx + 3, 125, hexc('b8c4c0'))                           # a vase
    c.rect(cx - 2, 113, cx + 2, 115, hexc('a8b4b0'))
    c.hline(cx - 3, cx + 3, 125, hexc('7a8a86'))
    for (dx, dy) in ((-4, 108), (0, 105), (4, 109), (-2, 110), (2, 108)):      # dried stems
        c.line(cx, 113, cx + dx, dy, hexc('8a7a5a'))


def mirror(c, cx, fr):
    x0 = cx - 9
    c.box(x0, 30, x0 + 18, 58, fr, shade(fr, 0.55))
    c.rect(x0 + 2, 32, x0 + 16, 56, hexc('9aa8a8'))
    c.line(x0 + 4, 50, x0 + 12, 34, hexc('c8d4d2'))
    c.line(x0 + 6, 52, x0 + 14, 38, hexc('b0bebc'))


def hose_reel(c, cx):
    """A fire-hose reel cabinet: red box, glass door, the reel inside."""
    x0 = cx - 11
    c.box(x0, 30, x0 + 22, 58, hexc('b8322a'), hexc('5a1a16'))
    c.rect(x0 + 3, 33, x0 + 19, 55, hexc('7a8a8a'))
    c.ellipse(cx, 44, 7, 7, hexc('a82a22'))
    c.ellipse(cx, 44, 3, 3, hexc('3a2a26'))
    c.rect(x0 + 3, 33, x0 + 19, 34, hexc('b8c8c8'))


# --- the three sections, and their near-identical variants -----------------------------------
HIGH = {
    'a': dict(wall='3f5a5a', motif='7a8a6a', runner=('7a2424', 'b58f4a', 'a8483a'),
              pics=('land', 'port', 'land', 'port'), fills=('6a7a5a', '5a4a3e'), mats=(1, 3)),
    'b': dict(wall='3a5462', motif='6f8492', runner=('6a2632', 'b58f4a', '9a4452'),
              pics=('port', 'land', 'port', 'land'), fills=('5a6a7a', '6a4a3e'), console=1, mats=(0, 2)),
    'c': dict(wall='465f58', motif='83926e', runner=('7e3222', 'c09a52', 'aa5638'),
              pics=('land', 'land', 'port', 'mirror'), fills=('7a6a4a', '5a6a5a'), mats=(2, 4)),
}
MID = {
    'a': dict(wall='b39a5a', dark='a38a4e', light='bca562', pitch=8,
              pics=('frame', 'board', 'frame', 'board'), runner=('6a5040', '4a3428', '8a6a54'), mats=(0, 3)),
    'b': dict(wall='a99e62', dark='988e54', light='b4aa6e', pitch=8,
              pics=('board', 'frame', 'board', 'frame'), runner=('5a4a44', '3e3230', '7a6660'),
              radiators=True, mats=(1, 2, 4)),
    'c': dict(wall='b8955a', dark='a6844c', light='c4a266', pitch=10,
              pics=('frame', 'frame', 'board', 'board'), runner=('6e4a3a', '4e3024', '946a54'), mats=(3,)),
}
LOW = {
    'a': dict(upper='a9b8a0', lower='3e5a48', lino=('8a8a78', '5a5e52'),
              pics=('notice', 'call', 'notice', 'call'), mats=(2,)),
    'b': dict(upper='a8b6b6', lower='3e4e5c', lino=('8a8a82', '4e5662'),
              pics=('call', 'notice', 'call', 'notice'), mats=(0,)),
    'c': dict(upper='b6b69c', lower='5a4a3c', lino=('8c7c62', '5a4e40'),
              pics=('notice', 'call', 'hose', 'notice'), mats=(1, 4)),
}


def high(c, P, occ):
    """Upper floors: a faded hotel-like hallway."""
    wall, motif = hexc(P['wall']), hexc(P['motif'])
    ceiling(c, hexc('c9c0a8'), hexc('d8cfb4'), hexc('ece4cc'))
    c.rect(0, WALL_TOP, CW - 1, RAIL_Y - 1, wall)
    for y in range(WALL_TOP + 6, RAIL_Y - 4, 12):                            # damask diamonds
        off = 0 if ((y - WALL_TOP) // 12) % 2 == 0 else 12
        for x in range(off, CW, 24):
            for (dx, dy) in ((0, -3), (-1, -2), (1, -2), (-2, -1), (2, -1), (-3, 0), (3, 0),
                             (-2, 1), (2, 1), (-1, 2), (1, 2), (0, 3)):
                c.put(x + dx, y + dy, motif)
            c.put(x, y, hexc('b58f4a'))
    c.rect(0, RAIL_Y, CW - 1, RAIL_Y + 3, hexc('b58f4a'))                     # a brass-capped rail
    c.hline(0, CW - 1, RAIL_Y, hexc('d9b86a'))
    c.hline(0, CW - 1, RAIL_Y + 3, hexc('5a3a20'))
    wood, wood_dk, wood_lt = hexc('4a2a1e'), hexc('3a1f16'), hexc('5e3828')
    c.rect(0, RAIL_Y + 4, CW - 1, SKIRT_Y - 1, wood)
    for x in range(0, CW, 40):                                                # raised panels
        c.box(x + 4, RAIL_Y + 9, x + 35, SKIRT_Y - 5, wood, wood_dk)
        c.hline(x + 5, x + 34, RAIL_Y + 10, wood_lt)
        c.vline(x + 5, RAIL_Y + 10, SKIRT_Y - 6, wood_lt)
    c.rect(0, SKIRT_Y, CW - 1, FLOOR_Y - 1, hexc('2a1810'))
    c.hline(0, CW - 1, SKIRT_Y, wood_lt)
    floor_boards(c, [hexc('6a4630'), hexc('5e3e2a'), hexc('704a34')], hexc('3a2418'))
    rb, rd, rp = (hexc(h) for h in P['runner'])
    runner(c, rb, rd, rp)
    recesses(c, wall)
    pilasters(c, hexc('5e3828'), hexc('7a4a34'), hexc('2a1810'))
    light_switches(c, hexc('b58f4a'))
    for i, x in enumerate(LAYOUT['spots']):
        kind = P['pics'][i]
        if kind == 'land':
            frame(c, x, 34, 28, 22, hexc('b58f4a'), hexc(P['fills'][(i // 2) % 2]))
            c.poly([(x - 12, 51), (x - 4, 44), (x + 4, 48), (x + 12, 42), (x + 12, 53), (x - 12, 53)], hexc('4a5a3a'))
        elif kind == 'port':
            frame(c, x, 36, 18, 22, hexc('b58f4a'), hexc('5a4a3e'))
            c.ellipse(x, 44, 3, 4, hexc('c8b39a'))
        else:
            mirror(c, x, hexc('b58f4a'))
        occ.append((x - 17, 24, x + 17, 62))
        if P.get('console') == i:
            console_table(c, x, hexc('4a2a1e'), hexc('6e4230'))
            occ.append((x - 16, 104, x + 16, FLOOR_Y + 2))
    exit_sign(c)


def mid(c, P, occ):
    """Middle floors: tired residential."""
    wall = hexc(P['wall'])
    ceiling(c, hexc('c9bda0'), hexc('d6cbb0'), hexc('e6dcc2'))
    c.rect(0, WALL_TOP, CW - 1, RAIL_Y - 1, wall)
    p = P['pitch']
    for x in range(0, CW, p):                                                  # stripes
        c.vline(x + 2, WALL_TOP, RAIL_Y - 1, hexc(P['dark']))
        c.vline(x + 3, WALL_TOP, RAIL_Y - 1, hexc(P['dark']))
        c.vline(x + p - 2, WALL_TOP, RAIL_Y - 1, hexc(P['light']))
    c.dither(0, WALL_TOP, CW - 1, WALL_TOP + 6, hexc('8a7644'), 0.5)
    c.rect(0, RAIL_Y, CW - 1, RAIL_Y + 3, hexc('8a6443'))
    c.hline(0, CW - 1, RAIL_Y, hexc('a47a54'))
    c.hline(0, CW - 1, RAIL_Y + 3, hexc('4a3020'))
    cream = hexc('d6cbb0')
    c.rect(0, RAIL_Y + 4, CW - 1, SKIRT_Y - 1, cream)
    for x in range(0, CW, 6):                                                  # tongue and groove
        c.vline(x, RAIL_Y + 4, SKIRT_Y - 1, hexc('b9ae92'))
        c.vline(x + 1, RAIL_Y + 4, SKIRT_Y - 1, hexc('e2d8be'))
    c.dither(0, SKIRT_Y - 10, CW - 1, SKIRT_Y - 1, hexc('a89e84'), 0.5)        # scuffed low down
    c.rect(0, SKIRT_Y, CW - 1, FLOOR_Y - 1, hexc('6b4a31'))
    c.hline(0, CW - 1, SKIRT_Y, hexc('8a6443'))
    floor_boards(c, [hexc('7a5a3e'), hexc('6e5036'), hexc('846244')], hexc('4a3424'))
    rb, rd, rp = (hexc(h) for h in P['runner'])
    runner(c, rb, rd, rp)
    recesses(c, wall)
    pilasters(c, hexc('d6cbb0'), hexc('ece4cc'), hexc('7a6a50'))
    light_switches(c, hexc('e6e0cc'))
    for i, x in enumerate(LAYOUT['spots']):
        if P['pics'][i] == 'frame':
            frame(c, x, 36, 24, 18, hexc('6b4a2c'), hexc('9c9282'))
        else:
            c.box(x - 12, 30, x + 12, 56, hexc('9a7650'), hexc('3b2718'))         # a residents' board
            c.rect(x - 9, 33, x - 1, 42, hexc('e6dfcc')); c.rect(x + 1, 35, x + 9, 46, hexc('d9c24a'))
            c.rect(x - 8, 45, x, 53, hexc('e6dfcc'))
        occ.append((x - 17, 24, x + 17, 62))
        if P.get('radiators'):
            radiator(c, x)
            occ.append((x - 20, 124, x + 17, FLOOR_Y - 1))
    exit_sign(c)


def low(c, P, occ):
    """Lower floors: institutional two-tone gloss paint, pipes, checker lino."""
    upper, lower = hexc(P['upper']), hexc(P['lower'])
    ceiling(c, hexc('b9bdb0'), hexc('c9ccc0'), hexc('dcdfd4'))
    c.rect(0, WALL_TOP, CW - 1, RAIL_Y - 1, upper)
    c.dither(0, WALL_TOP, CW - 1, RAIL_Y - 1, shade(upper, 1.05), 0.08, pattern='random')
    c.rect(0, 18, CW - 1, 21, hexc('7a8480'))                                   # a pipe run along the top
    c.hline(0, CW - 1, 18, hexc('9aa3a0'))
    c.hline(0, CW - 1, 21, hexc('4a524e'))
    for x in range(40, CW, 96):
        c.rect(x, 17, x + 3, 22, hexc('5a625e'))                                # brackets
    c.rect(0, 24, CW - 1, 25, hexc('6a7270'))                                   # a thin conduit
    c.rect(0, RAIL_Y, CW - 1, RAIL_Y + 2, hexc('26302a'))                       # the painted line
    c.rect(0, RAIL_Y + 3, CW - 1, SKIRT_Y - 1, lower)
    c.dither(0, RAIL_Y + 3, CW - 1, RAIL_Y + 6, shade(lower, 1.18), 0.5)
    c.rect(0, SKIRT_Y, CW - 1, FLOOR_Y - 1, hexc('26302a'))
    rows = [160, 165, 171, 178, 186, 192]                                       # checker lino
    la, lb = hexc(P['lino'][0]), hexc(P['lino'][1])
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, CW, 16):
            c.rect(x, y0, x + 15, y1, la if ((x // 16) + r) % 2 else lb)
    c.hline(0, CW - 1, FLOOR_Y, hexc('3a3e36'))
    recesses(c, upper)
    pilasters(c, hexc('7a8480'), hexc('9aa3a0'), hexc('3a403e'))
    light_switches(c, hexc('c8ccc4'))
    for i, x in enumerate(LAYOUT['spots']):                                     # notices, a fire-drill card
        kind = P['pics'][i]
        if kind == 'notice':
            c.box(x - 9, 36, x + 9, 58, hexc('e6e2d6'), hexc('6a6a66'))
            c.rect(x - 7, 38, x + 7, 42, hexc('a8322c'))
            for y in range(45, 57, 3):
                c.hline(x - 6, x + 6, y, hexc('8a8a86'))
        elif kind == 'call':
            c.box(x - 6, 40, x + 6, 52, hexc('a8322c'), hexc('5a1a16'))          # an alarm call point
            c.rect(x - 3, 43, x + 3, 49, hexc('e6e2d6'))
        else:
            hose_reel(c, x)
        occ.append((x - 17, 24, x + 17, 62))
    exit_sign(c)


def lobby(c):
    """The ground floor: a once-smart entrance hall — marble wainscot, a bank of brass mailboxes,
    a residents' notice board, a floor directory by the lift, big marble floor tiles, a doormat."""
    wall = hexc('c9b894')
    ceiling(c, hexc('d6cbb0'), hexc('e2d8be'), hexc('f0e8d0'))
    c.rect(0, WALL_TOP, CW - 1, RAIL_Y - 1, wall)
    for x in range(0, CW, 64):                                                  # plaster panels
        c.box(x + 6, WALL_TOP + 8, x + 57, RAIL_Y - 8, wall, shade(wall, 0.88))
    c.rect(0, RAIL_Y, CW - 1, RAIL_Y + 3, hexc('8a7a5a'))
    c.hline(0, CW - 1, RAIL_Y, hexc('b0a078'))
    marble, vein = hexc('d8d2c4'), hexc('b8b0a0')
    c.rect(0, RAIL_Y + 4, CW - 1, SKIRT_Y - 1, marble)
    rng = random.Random(7)
    for _ in range(90):                                                         # veins
        x, y = rng.randrange(0, CW), rng.randrange(RAIL_Y + 5, SKIRT_Y - 2)
        for k in range(rng.randrange(5, 14)):
            if 0 <= x < CW and RAIL_Y + 4 <= y < SKIRT_Y:
                c.put(x, y, vein)
            x += rng.choice((-1, 1, 1))
            y += rng.choice((0, 1, -1, 1))
    for x in range(0, CW, 48):
        c.vline(x, RAIL_Y + 4, SKIRT_Y - 1, hexc('a8a090'))
    c.rect(0, SKIRT_Y, CW - 1, FLOOR_Y - 1, hexc('3a3430'))
    c.hline(0, CW - 1, SKIRT_Y, hexc('5a524a'))
    rows = [160, 168, 178, 192]                                                 # big marble floor tiles
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, CW, 32):
            c.rect(x, y0, x + 31, y1, hexc('d8d2c4') if ((x // 32) + r) % 2 else hexc('3e3a36'))
            c.vline(x, y0, y1, hexc('8a8478'))
        c.hline(0, CW - 1, y0, hexc('8a8478'))
    c.rect(500, 170, 580, 186, hexc('5a3a2a'))                                  # a doormat at the exit
    c.hline(500, 580, 170, hexc('7a4a34'))
    for x in range(504, 578, 4):
        c.vline(x, 172, 184, hexc('4a2e20'))
    recesses(c, wall)
    pilasters(c, hexc('8a7a5a'), hexc('b0a078'), hexc('3a3228'))
    # the mailbox bank: brass doors in a grid, a few hanging open, letters on the floor below
    x0, y0, cols, rows_ = 150, 34, 8, 4
    c.box(x0 - 3, y0 - 3, x0 + cols * 16 + 2, y0 + rows_ * 13 + 2, hexc('6b4a31'), hexc('3a2718'))
    for r in range(rows_):
        for k in range(cols):
            bx, by = x0 + k * 16, y0 + r * 13
            if (r * cols + k) in (5, 13, 22):
                c.rect(bx, by, bx + 14, by + 11, hexc('1e1a16'))
                c.poly([(bx, by), (bx - 5, by + 2), (bx - 5, by + 12), (bx, by + 11)], hexc('b58f4a'))
                c.rect(bx + 3, by + 6, bx + 10, by + 10, hexc('e6e0cc'))
                continue
            c.box(bx, by, bx + 14, by + 11, hexc('b58f4a'), hexc('7a5a2a'))
            c.rect(bx + 3, by + 3, bx + 11, by + 4, hexc('3a2a1a'))
            c.put(bx + 12, by + 8, hexc('7a5a2a'))
            c.rect(bx + 3, by + 7, bx + 8, by + 8, hexc('e6e0cc'))
    for (lx, ly) in ((170, 164), (186, 167), (214, 163), (262, 168)):
        c.rect(lx, ly, lx + 6, ly + 3, hexc('e6e0cc'))
        c.hline(lx, lx + 6, ly + 3, hexc('b9b3a4'))
    c.box(360, 30, 404, 64, hexc('9a7650'), hexc('3b2718'))                     # the notice board
    c.rect(364, 34, 380, 46, hexc('e6dfcc')); c.rect(384, 36, 400, 50, hexc('d9c24a'))
    c.rect(366, 50, 382, 60, hexc('e88aa0'))
    for y in range(37, 45, 2):
        c.hline(366, 378, y, hexc('8a8270'))
    c.box(800, 26, 850, 70, hexc('2a2622'), hexc('111010'))                     # the floor directory
    for i, y in enumerate(range(30, 67, 4)):
        c.hline(804, 822 + (i * 7) % 20, y, hexc('d9c690'))
        c.put(846, y, hexc('d9c690'))
    exit_sign(c)


# per-section wear geometry + materials (what the damage reveals, what a tag is drawn in)
SECTION = {
    'high': dict(fn=high, variants=HIGH, lower=RAIL_Y + 4, peel='paper', floor='runner',
                 boards=('6a4630', '5e3e2a', '704a34'), tags=('c8c4b8', 'c84a3a', 'd8c040')),
    'mid': dict(fn=mid, variants=MID, lower=RAIL_Y + 4, peel='paper', floor='runner',
                boards=('7a5a3e', '6e5036', '846244'), tags=('1e1e22', '8a2a2a', '2a3a6a')),
    'low': dict(fn=low, variants=LOW, lower=RAIL_Y + 3, peel='paint', floor='lino',
                boards=None, tags=('1e1e22', '8a2a2a', '2a3a6a')),
}
# which wear levels each section can meet (building_floors.corridor_wear over its floors)
SECTION_LEVELS = {'high': (0, 1), 'mid': (1, 2, 3), 'low': (3, 4)}


def set_geom(section):
    global LOWER_Y
    G.clear()
    G.update(SECTION[section])
    LOWER_Y = G['lower']


class Spots:
    """What's already on the wall, so wear and props never land on a fixture, a door or a stair."""

    def __init__(self, taken=()):
        self.taken = list(taken)

    def take(self, x0, y0, x1, y1):
        self.taken.append((x0, y0, x1, y1))

    def free(self, x0, y0, x1, y1, pad=2):
        if x0 < 6 or x1 > CW - 7:
            return False
        for (a, b) in [RECESS[i] for i in LAYOUT['recess']]:
            if x1 >= a - 8 and x0 <= b + 20:
                return False
        if y1 >= DOOR_TOP:
            for d in DOORS:
                if x1 >= d - 30 - pad and x0 <= d + 30 + pad:
                    return False
        if y1 >= ELEV_TOP and x1 >= ELEVATOR[0] - 4 and x0 <= ELEVATOR[1] + 4:
            return False
        if x1 >= KIT_X - 14 and x0 <= KIT_X + 14 and y1 >= 70:
            return False
        for (a, b, c_, d) in self.taken:
            if x1 >= a - pad and x0 <= c_ + pad and y1 >= b - pad and y0 <= d + pad:
                return False
        return True

    def find(self, rng, w, h, y_lo, y_hi, tries=60, pad=2, zones=None):
        for _ in range(tries):
            x0 = rng.randrange(8, CW - 8 - w)
            if zones and rng.random() < 0.8:                  # damage gathers where the rot is
                x0 = min(max(8, int(rng.gauss(rng.choice(zones), 55)) - w // 2), CW - 8 - w)
            y0 = rng.randrange(y_lo, max(y_lo + 1, y_hi - h))
            if self.free(x0, y0, x0 + w, y0 + h, pad):
                return x0, y0
        return None


# --- pictures failing: askew, then gone (a clean patch + the nail), then down on the floor ----
def _lum(p):
    return 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]


def picture_damage(c, bare, score_of, rng_seed):
    """`bare` is the same corridor drawn without its pictures, so a moved / missing picture
    leaves the real wall behind it. `score_of(i)` is how far spot i has gone (0 fine .. 1+)."""
    rng = random.Random(rng_seed)
    for i, cx in enumerate(LAYOUT['spots']):
        tilt = rng.choice((-1, 1))
        s = score_of(i)
        x0, y0, x1, y1 = cx - 18, 22, cx + 18, 64
        mask = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)
                if c.px[x, y] != bare.getpixel((x, y))]
        if s < 0.45 or not mask:
            continue
        pic = {(x, y): c.px[x, y] for (x, y) in mask}
        for (x, y) in mask:                                         # take it off the wall
            c.px[x, y] = bare.getpixel((x, y))
        rows = {}
        for (x, y) in mask:
            rows[y] = rows.get(y, 0) + 1
        body = [y for y in rows if rows[y] > 4]                      # the frame, not its wire
        top, bot = min(body), max(body)
        if s < 0.75:                                                 # hanging crooked
            k = tilt * (2 if s < 0.6 else 4)
            for (x, y), p in pic.items():
                c.px[x, y + int(round(k * (x - cx) / 18.0))] = p
            continue
        for (x, y) in mask:                                          # gone: the unfaded patch
            if top <= y <= bot:
                q = c.px[x, y]
                c.px[x, y] = (min(255, int(q[0] * 1.14) + 6), min(255, int(q[1] * 1.14) + 6),
                              min(255, int(q[2] * 1.12) + 5), 255)
        c.px[cx, top - 3] = hexc('2a2622')
        if s < 0.95:
            continue
        dx = rng.randrange(-6, 7)                                    # fallen, leaning at the skirting
        drop = FLOOR_Y + 3 - bot
        for (x, y), p in pic.items():
            if top <= y <= bot:
                lean = int((y - top) * 0.25) * tilt
                nx, ny = x + dx + lean, y + drop
                if 0 <= nx < CW and ny < CH:
                    c.px[nx, ny] = p
        for k in range(8):                                           # broken glass
            gx, gy = cx + dx + rng.randrange(-20, 21), FLOOR_Y + 3 + rng.randrange(0, 5)
            c.px[gx, gy] = (196, 214, 214, 255)


# --- wear -------------------------------------------------------------------------------------
WEAR = {
    0: dict(dim=1.00, yellow=0.00, scuffs=6, worn=0.0, stains=0, tide=0, cracks=0, graffiti=0,
            peel=0, kick=0, holes=0, mould=0.0, streaks=0, torn=0, tape=0,
            bags=0, boxes=0, debris=0, ceil_stain=0),
    1: dict(dim=0.98, yellow=0.03, scuffs=22, worn=0.35, stains=4, tide=1, cracks=2, graffiti=0,
            peel=1, kick=0, holes=0, mould=0.0, streaks=0, torn=0, tape=0,
            bags=0, boxes=0, debris=0, ceil_stain=1),
    2: dict(dim=0.955, yellow=0.06, scuffs=36, worn=0.55, stains=9, tide=3, cracks=5, graffiti=2,
            peel=3, kick=1, holes=0, mould=0.0, streaks=2, torn=0, tape=1,
            bags=0, boxes=0, debris=4, ceil_stain=2),
    3: dict(dim=0.925, yellow=0.1, scuffs=50, worn=0.75, stains=14, tide=4, cracks=9, graffiti=4,
            peel=6, kick=2, holes=1, mould=0.25, streaks=4, torn=2, tape=2,
            bags=1, boxes=1, debris=12, ceil_stain=3),
    4: dict(dim=0.89, yellow=0.14, scuffs=60, worn=0.9, stains=20, tide=6, cracks=14, graffiti=6,
            peel=9, kick=3, holes=4, mould=0.5, streaks=7, torn=4, tape=2,
            bags=4, boxes=2, debris=30, ceil_stain=4),
}
# Run 2 / run 3 (the time skip): the same corridor, more of the same damage on top, and blood.
_NONE = {k: 0 for k in WEAR[0]}
RUN_EXTRA = {
    2: dict(_NONE, dim=0.95, scuffs=20, stains=6, tide=1, cracks=3, peel=2,
            graffiti=1, debris=10, bags=1, blood=2),
    3: dict(_NONE, dim=0.88, scuffs=30, stains=12, tide=2, cracks=6, peel=4, holes=1,
            kick=1, graffiti=2, mould=0.2, torn=1, debris=24, bags=2, blood=5),
}
TAN = (140, 112, 76, 255)


def _blob(rng, cx, cy, rx, ry):
    ph = [rng.random() * 6.28 for _ in range(3)]

    def f(x, y):
        a = math.atan2((y - cy) / ry, (x - cx) / rx)
        k = 1.0 + 0.26 * math.sin(3 * a + ph[0]) + 0.14 * math.sin(5 * a + ph[1]) + 0.07 * math.sin(9 * a + ph[2])
        return (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2) ** 0.5 / k
    return f


def _mul(p, r, g, b):
    return (int(p[0] * r), int(p[1] * g), int(p[2] * b), 255)


def age_paint(c, w):
    """Grime + nicotine yellowing: the whole band dims, the walls yellow."""
    if w['dim'] >= 1.0 and w['yellow'] <= 0.0:
        return
    for y in range(CH):
        wall = WALL_TOP <= y < SKIRT_Y
        yb = 1.0 - w['yellow'] if wall else 1.0 - w['yellow'] * 0.4
        for x in range(CW):
            p = c.px[x, y]
            c.px[x, y] = _mul(p, w['dim'], w['dim'] * (1.0 - w['yellow'] * 0.25), w['dim'] * yb)


def wear_walls(c, w, sp, rng, zones):
    px = c.px

    def wall_ok(x, y):
        return 0 <= x < CW and WALL_TOP + 1 <= y < SKIRT_Y and sp.free(x, y, x, y, 0)

    def put(x, y, col):
        if wall_ok(x, y):
            c.put(x, y, col)

    def get(x, y):
        return px[min(max(x, 0), CW - 1), min(max(y, 0), CH - 1)]
    for i in range(w['tide']):                                              # damp coming through
        at = sp.find(rng, 50, 30, WALL_TOP + 1, 60, pad=4, zones=zones)
        if not at:
            continue
        cx = at[0] + 25
        rx, ry = rng.randrange(14, 26), rng.randrange(12, 26)
        f = _blob(rng, cx, WALL_TOP, rx, ry)                                 # hangs off the ceiling
        for y in range(WALL_TOP + 1, WALL_TOP + ry * 2):
            for x in range(cx - rx * 2, cx + rx * 2):
                if not wall_ok(x, y):
                    continue
                d, p = f(x, y), px[x, y]
                if d < 0.84:                                                  # a faint brown wash
                    put(x, y, mix(p, TAN, 0.14))
                elif d < 0.97:                                                # the dried tide line
                    put(x, y, mix(mix(p, TAN, 0.45), (60, 44, 30, 255), 0.25))
                elif d < 1.08 and (x + y) % 2:
                    put(x, y, mix(p, TAN, 0.25))
        for _ in range(w['streaks'] // max(1, w['tide']) + (1 if w['streaks'] else 0)):
            x = cx + rng.randrange(-rx // 2, rx // 2 + 1)                     # water running down
            for y in range(WALL_TOP + ry, WALL_TOP + ry + 20 + rng.randrange(0, 60)):
                put(x, y, mix(get(x, y), TAN, 0.3))
                if rng.random() < 0.06:
                    x += rng.choice((-1, 1))
        if w['mould'] > 0:                                                    # black mould in the wet
            for y in range(WALL_TOP + 1, WALL_TOP + ry):
                for x in range(cx - rx, cx + rx):
                    k = w['mould'] * max(0.0, 0.9 - f(x, y)) * (1.0 - (y - WALL_TOP) / ry)
                    if rng.random() < k * 1.6:
                        put(x, y, hexc('222820', 170 + int(80 * min(1.0, k * 2))))
    for _ in range(w['cracks']):
        x, y = rng.randrange(20, CW - 20), rng.randrange(WALL_TOP + 1, 70)
        if zones and rng.random() < 0.7:
            x = min(max(20, int(rng.gauss(rng.choice(zones), 60))), CW - 20)
        for k in range(rng.randrange(10, 34)):
            put(x, y, mix(get(x, y), (26, 22, 18, 255), 0.5))
            x += rng.choice((-1, 0, 1, 1))
            y += 1
    plaster = hexc('cbb89c')
    backing = hexc('ddd3bc') if G['peel'] == 'paper' else hexc('c8c2a0')    # paper backing / old paint
    for _ in range(w['peel']):                                               # paper torn / paint flaking
        at = sp.find(rng, 18, 22, WALL_TOP + 4, DADO_Y - 4, pad=3, zones=zones)
        if not at:
            continue
        x0, y0 = at
        f = _blob(rng, x0 + 9, y0 + 11, rng.randrange(5, 9), rng.randrange(6, 11))
        g = _blob(rng, x0 + 9, y0 + 12, rng.randrange(2, 6), rng.randrange(3, 7))
        for y in range(y0 - 6, y0 + 28):
            for x in range(x0 - 6, x0 + 24):
                d = f(x, y)
                if d <= 1.0:
                    put(x, y, plaster if g(x, y) <= 1.0 else (backing if (x * 5 + y * 3) % 11 else shade(backing, 0.92)))
                elif d <= 1.14:
                    p = get(x, y)                                             # the lifted, curling lip
                    put(x, y, shade(p, 1.25) if (y < y0 + 11) == (x < x0 + 9) else _mul(p, 0.6, 0.58, 0.55))
        if G['peel'] == 'paper' and rng.random() < 0.6:                       # a strip hanging down
            sx = x0 + rng.randrange(4, 14)
            for y in range(y0 + 18, y0 + 18 + rng.randrange(6, 14)):
                put(sx, y, backing)
                put(sx + 1, y, shade(backing, 0.86))
        sp.take(x0, y0, x0 + 18, y0 + 22)
    for _ in range(w['holes']):                                              # through to the blockwork
        at = sp.find(rng, 22, 18, 30, DADO_Y - 6, pad=4, zones=zones)
        if not at:
            continue
        x0, y0 = at
        cx, cy = x0 + 11, y0 + 9
        f = _blob(rng, cx, cy, rng.randrange(7, 11), rng.randrange(5, 8))
        for y in range(cy - 16, cy + 16):
            for x in range(cx - 20, cx + 20):
                d = f(x, y)
                sh = 6 if (y // 5) % 2 else 0
                if d <= 1.0:
                    blk = hexc('6e6a64') if ((y // 5) + (x + sh) // 12) % 2 else hexc('7a766e')
                    if y % 5 == 0 or (x + sh) % 12 == 0:
                        blk = hexc('4a4640')
                    if d > 0.8 and y < cy:
                        blk = hexc('2e2a26')                                  # the lip's shadow
                    put(x, y, blk)
                elif d <= 1.3:
                    put(x, y, plaster if (x + y) % 3 else shade(plaster, 0.9))
        sp.take(x0 - 6, y0 - 4, x0 + 28, y0 + 22)
        for k in range(12):                                                  # what fell out, at the wall
            dx = x0 + rng.randrange(-6, 28)
            dy = FLOOR_Y + 1 + rng.randrange(0, 4)
            c.rect(dx, dy, dx + rng.randrange(0, 3), dy + rng.randrange(0, 2), plaster)
    for _ in range(w['kick']):                                               # a kicked-in panel
        at = sp.find(rng, 14, 10, LOWER_Y + 8, SKIRT_Y - 6, pad=3, zones=zones)
        if not at:
            continue
        x0, y0 = at
        f = _blob(rng, x0 + 7, y0 + 5, 6, 4)
        for y in range(y0 - 4, y0 + 12):
            for x in range(x0 - 4, x0 + 18):
                d = f(x, y)
                if d <= 1.0:
                    put(x, y, hexc('1e1a16') if y < y0 + 3 else hexc('36302a'))
                elif d <= 1.3 and (x + 2 * y) % 3:
                    put(x, y, shade(get(x, y), 1.35))                         # splinters / chips
        sp.take(x0, y0, x0 + 14, y0 + 10)
    for i in range(w['graffiti']):                                           # a marker tag, 2px strokes
        at = sp.find(rng, 30, 14, 44, DADO_Y - 4, pad=4, zones=zones)
        if not at:
            continue
        x0, y0 = at
        col = hexc(G['tags'][i % 3])
        x, y = x0, y0 + 7
        for k in range(rng.randrange(22, 34)):
            put(x, y, col)
            put(x, y + 1, col)
            if k % 4 == 3:
                x += 2
            else:
                y += rng.choice((-2, -1, 1, 2)) if 1 < y - y0 < 11 else (2 if y - y0 <= 1 else -2)
                x += rng.choice((0, 1))
        if rng.random() < 0.5:
            c.hline(x0 - 1, min(x + 2, x0 + 30), y0 + 14, col)
        sp.take(x0, y0, x0 + 30, y0 + 14)
    for _ in range(w['scuffs']):                                             # knocks and scrapes
        x, y = rng.randrange(8, CW - 20), rng.choice((rng.randrange(LOWER_Y + 2, SKIRT_Y - 1),
                                                      rng.randrange(DADO_Y - 18, DADO_Y - 1)))
        for k in range(rng.randrange(2, 9)):
            p = get(x + k, y)
            put(x + k, y + (k // 4), shade(p, 1.22) if _lum(p) < 90 else _mul(p, 0.8, 0.79, 0.77))


def wear_ceiling(c, w, rng):
    for i in range(w['ceil_stain']):
        cx = rng.randrange(60, CW - 60)
        f = _blob(rng, cx, 5, rng.randrange(10, 20), 5)
        for y in range(0, 10):
            for x in range(cx - 30, cx + 30):
                if 0 <= x < CW and f(x, y) <= 1.0:
                    c.px[x, y] = mix(c.px[x, y], TAN, 0.4 if f(x, y) > 0.7 else 0.15)


def wear_floor(c, w, sp, rng):
    px = c.px
    runner_kind = G['floor'] == 'runner'
    if w['worn'] > 0:                                                        # the walked-on path
        for y in range(169, 184):
            k = 1.0 - abs(y - 176) / 8.0
            for x in range(CW):
                if rng.random() < w['worn'] * k * 0.5:
                    p = px[x, y]
                    px[x, y] = mix(p, (150, 132, 112, 255), 0.2) if runner_kind else _mul(p, 0.9, 0.88, 0.84)
    for _ in range(w['stains']):
        sx, sy = rng.randrange(10, CW - 10), rng.randrange(163, 190)
        f = _blob(rng, sx, sy, rng.randrange(4, 13), rng.randrange(1, 4))
        col = rng.choice([(0.72, 0.66, 0.58), (0.8, 0.78, 0.74), (0.62, 0.5, 0.46)])
        for y in range(sy - 6, sy + 6):
            for x in range(sx - 20, sx + 20):
                if 0 <= x < CW and FLOOR_Y + 2 <= y < CH and f(x, y) <= 1.0:
                    px[x, y] = _mul(px[x, y], *col)
    screed, glue = hexc('8e8a80'), hexc('6e6440')
    for i in range(w['torn']):                                               # runner / lino torn up
        x0 = rng.randrange(40, CW - 140)
        ww = rng.randrange(40, 90) + 30 * (w['torn'] >= 4)
        if runner_kind:                                                      # the runner, to the boards
            f = _blob(rng, x0 + ww // 2, 176, ww // 2, 11)
            boards = [hexc(b) for b in G['boards']]
            r = [160, 164, 169, 175, 182, 192]
            for y in range(166, 187):
                for x in range(x0 - 10, x0 + ww + 10):
                    if not (0 <= x < CW):
                        continue
                    d = f(x, y)
                    if d <= 1.0:
                        band = max(k for k in range(5) if r[k] <= y)
                        col = boards[band % 3]
                        if y == r[band + 1] - 1 or (x - (band * 29) % 64) % 64 == 0:
                            col = hexc('3a2418')
                        px[x, y] = shade(col, 0.9)
                    elif d <= 1.14:
                        px[x, y] = shade(px[x, y], 1.3) if (x + y) % 2 else shade(px[x, y], 0.7)   # fraying
        else:                                                                # lino, to the screed
            f = _blob(rng, x0 + ww // 2, rng.randrange(166, 180), ww // 2, rng.randrange(6, 11))
            for y in range(FLOOR_Y + 2, CH):
                for x in range(x0 - 10, x0 + ww + 10):
                    if not (0 <= x < CW):
                        continue
                    d = f(x, y)
                    if d <= 1.0:
                        px[x, y] = glue if (x * 7 + y * 3) % 23 == 0 else (screed if (x + y) % 5 else shade(screed, 0.92))
                    elif d <= 1.12:
                        px[x, y] = shade(px[x, y], 1.2) if y < 176 else shade(px[x, y], 0.6)
    for i in range(w['tape']):                                               # gaffer tape over a split
        x0 = rng.randrange(40, CW - 60)
        y0 = rng.randrange(168, 182)
        for k in range(rng.randrange(18, 36)):
            for t in range(3):
                x, y = x0 + k, y0 + t + k // 12
                if 0 <= x < CW and y < CH:
                    px[x, y] = hexc('a8aaa6') if t else hexc('c8cac6')


def bin_bag(c, x0, sp, rng):
    """A black bin bag slumped against the wall, sitting on the floor at the skirting."""
    w = rng.randrange(20, 28)
    h = rng.randrange(17, 23)
    base_y = FLOOR_Y + 5
    top = base_y - h
    cx = x0 + w // 2
    c.shadow(cx + 1, base_y, w // 2 + 4, 3, alpha=120)
    lean = rng.choice((-1, 1))
    for y in range(top + 4, base_y + 1):
        t = (y - top - 4) / max(1, base_y - top - 4)
        hw = w / 2 * (min(1.0, 0.45 + 1.2 * t) if t < 0.8 else 1.0 - (t - 0.8) * 0.4)
        m = cx + lean * int(2 * (1 - t))
        for x in range(int(m - hw), int(m + hw) + 1):
            u = (x - (m - hw)) / max(1, 2 * hw)
            col = hexc('25272b')
            if u < 0.22 and 0.2 < t < 0.85:
                col = hexc('3b3f45')                                       # the sheen on the plastic
            elif u > 0.8:
                col = hexc('17181b')
            if (x - int(m) + int(t * 9)) % 7 == 0 and 0.15 < t < 0.9:
                col = hexc('1c1d20')                                       # creases
            c.put(x, y, col)
        if y == base_y:
            c.hline(int(m - hw), int(m + hw), y, hexc('121314'))
    c.rect(cx - 2, top + 1, cx + 2, top + 4, hexc('2e3136'))              # the gathered neck
    c.poly([(cx - 1, top + 1), (cx - 6, top - 3), (cx - 3, top + 2)], hexc('2e3136'))   # the tied ears
    c.poly([(cx + 1, top + 1), (cx + 6, top - 2), (cx + 3, top + 2)], hexc('25272b'))
    c.put(cx - 1, top + 2, hexc('4a4e56'))
    sp.take(x0 - 4, top - 4, x0 + w + 4, base_y)


def flat_box(c, x0, sp, rng):
    """A flattened cardboard box leaning against the wall."""
    w = rng.randrange(20, 28)
    x1, y0, y1 = x0 + w, 124, FLOOR_Y + 3
    card = hexc('a8845a')
    c.poly([(x0, y1), (x0 + 5, y0), (x1 + 5, y0), (x1, y1)], card)
    c.line(x0, y1, x0 + 5, y0, shade(card, 0.7))
    c.line(x1, y1, x1 + 5, y0, shade(card, 0.62))
    c.hline(x0 + 5, x1 + 5, y0, shade(card, 1.12))
    c.line(x0 + w // 2, y1, x0 + w // 2 + 5, y0, shade(card, 0.84))       # the fold
    c.rect(x0 + 6, y0 + 10, x0 + 12, y0 + 14, hexc('3a3a3a'))             # a printed mark
    c.shadow(x0 + w // 2, y1, w // 2 + 2, 2, alpha=90)
    sp.take(x0, y0, x1 + 6, y1)


def props(c, w, sp, rng, zones):
    for _ in range(w['bags']):
        at = sp.find(rng, 44, 30, SKIRT_Y - 20, SKIRT_Y - 18, pad=3, zones=zones)
        if at:
            for k in range(1 + (rng.random() < 0.6)):                     # bags come in heaps
                bin_bag(c, at[0] + k * 16, sp, rng)
    for _ in range(w['boxes']):
        at = sp.find(rng, 34, 36, 122, 124, pad=3, zones=zones)
        if at:
            flat_box(c, at[0], sp, rng)
    for _ in range(w['debris']):                                            # grit along the wall
        x = rng.randrange(8, CW - 8)
        y = FLOOR_Y + 2 + rng.randrange(0, 4)
        c.rect(x, y, x + rng.randrange(0, 2), y, rng.choice([hexc('d2c2a6'), hexc('8a8478'), hexc('5a544a')]))


def blood(c, n, sp, rng, zones):
    # smears at hand height, a handprint, drips, and (run 3) a trail dragged along the floor
    red, dk = hexc('5e1c18', 200), hexc('3e1210', 220)

    def put(x, y, col):
        if 0 <= x < CW and WALL_TOP < y < SKIRT_Y and sp.free(x, y, x, y, 0):
            c.put(x, y, col)
    for i in range(n):
        at = sp.find(rng, 40, 24, 70, 120, pad=3, zones=zones)
        if not at:
            continue
        x0, y0 = at
        kind = i % 3
        if kind == 0:                                                    # a smear dragged sideways
            ln = rng.randrange(18, 38)
            for k in range(ln):
                for t in range(max(1, 3 - k * 3 // ln)):
                    if rng.random() < 1.0 - k / ln * 0.6:
                        put(x0 + k, y0 + 6 + t + k // 9, red if t else dk)
            for k in range(rng.randrange(2, 4)):                           # runs off it
                dx = x0 + rng.randrange(2, ln // 2)
                for y in range(y0 + 8, y0 + 8 + rng.randrange(4, 14)):
                    put(dx, y, red)
        elif kind == 1:                                                  # a handprint
            hx, hy = x0 + 8, y0 + 8
            for y in range(hy, hy + 7):
                for x in range(hx - 3, hx + 4):
                    if ((x - hx) / 3.2) ** 2 + ((y - hy - 3) / 3.2) ** 2 <= 1.0:
                        put(x, y, red)
            for (fx, ln) in ((-3, 3), (-1, 4), (1, 4), (3, 3)):
                for k in range(ln):
                    put(hx + fx, hy - 1 - k, red)
            put(hx + 5, hy + 2, red)
            put(hx + 6, hy + 1, red)
            for y in range(hy + 6, hy + 6 + rng.randrange(3, 9)):             # a drip from the palm
                put(hx, y, red)
        else:                                                            # a spray of drips
            for k in range(rng.randrange(6, 12)):
                x = x0 + rng.randrange(0, 26)
                y = y0 + rng.randrange(0, 8)
                put(x, y, dk)
                for yy in range(y + 1, y + rng.randrange(2, 10)):
                    put(x, yy, red)
        sp.take(x0, y0, x0 + 40, y0 + 24)
    if n >= 4:                                                           # something was dragged
        x0 = rng.randrange(60, CW - 260)
        y = rng.randrange(166, 174)
        for k in range(rng.randrange(120, 220)):
            if rng.random() < 0.75 - k / 400.0:
                c.put(x0 + k, y + (k // 40) % 2, hexc('4a1612', 150))
                if rng.random() < 0.5:
                    c.put(x0 + k, y + 1 + (k // 40) % 2, hexc('4a1612', 110))


def corridor(section, variant, level, run, seed):
    """One section corridor at a wear level (depth) and run (time), as an Image."""
    set_geom(section)
    P = SECTION[section]['variants'][variant]
    fn = SECTION[section]['fn']
    spots = LAYOUT['spots']
    LAYOUT['spots'] = []
    bare = Canvas(w=CW, h=CH, seed=seed)
    fn(bare, P, [])
    LAYOUT['spots'] = spots
    c = Canvas(w=CW, h=CH, seed=seed)
    occ = []
    fn(c, P, occ)
    fragile = random.Random(seed * 13 + 5)
    frag = [fragile.random() for _ in spots]
    # how far each picture has gone: depth + the time skip + how loosely it was hung
    picture_damage(c, bare.img, lambda i: level * 0.2 + (run - 1) * 0.22 + frag[i] * 0.45, seed + 3)
    doormats(c, P.get('mats', ()), min(4, level + run - 1))
    sp = Spots(occ + [EXIT_SIGN] + [(d + 32, 85, d + 38, 92) for d in DOORS])
    w = WEAR[level]
    rng = random.Random(seed)
    # the rot gathers in a few stretches (a leak, a flat that went bad) rather than evenly
    zones = [rng.randrange(170, CW - 170) for _ in range(1 + level // 2)] if level >= 2 else None
    age_paint(c, w)
    wear_ceiling(c, w, rng)
    wear_walls(c, w, sp, rng, zones)
    wear_floor(c, w, sp, rng)
    props(c, w, sp, rng, zones)
    if run > 1:                                                      # the time skip, on top
        rr = random.Random(seed * 7 + run * 1009)
        zones = zones or [rr.randrange(170, CW - 170) for _ in range(1 + run // 2)]
        for r in range(2, run + 1):                                  # run 3 carries run 2's damage
            x = RUN_EXTRA[r]
            rr = random.Random(seed * 7 + r * 1009)
            age_paint(c, dict(x, yellow=0.0))
            wear_walls(c, x, sp, rr, zones)
            wear_floor(c, x, sp, rr)
            props(c, x, sp, rr, zones)
            blood(c, x['blood'], sp, rr, zones)
    return c.img


# --- FIRE: soot + char overlays, one per burnt stretch of the corridor --------------------------
# Zones are in local x; building_floors picks one from WorldState.fire_scar_zone (which thirds have
# burned). Drawn ABOVE the doors (soot climbs door frames too), below the stairs and everything
# spawned at runtime. Alpha-blended (not multiply) so the lighting treats it like the wall.
FIRE_ZONES = {'l': (0, 400), 'm': (350, 770), 'r': (720, 1120), 'lm': (0, 770),
              'mr': (350, 1120), 'all': (0, 1120)}


def _vnoise(seed):
    """Smooth value noise (0..1) for blotchy soot."""
    rng = random.Random(seed)
    grid = {}

    def g(ix, iy):
        if (ix, iy) not in grid:
            grid[(ix, iy)] = rng.random()
        return grid[(ix, iy)]

    def n(x, y, s):
        fx, fy = x / s, y / s
        ix, iy = int(math.floor(fx)), int(math.floor(fy))
        tx, ty = fx - ix, fy - iy
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = g(ix, iy) + (g(ix + 1, iy) - g(ix, iy)) * tx
        b = g(ix, iy + 1) + (g(ix + 1, iy + 1) - g(ix, iy + 1)) * tx
        return a + (b - a) * ty
    return lambda x, y: 0.6 * n(x, y, 23.0) + 0.3 * n(x, y, 9.0) + 0.1 * n(x, y, 4.0)


def fire_overlay(zone, seed):
    from PIL import Image
    a, b = FIRE_ZONES[zone]
    img = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    px = img.load()
    rng = random.Random(seed)
    noise = _vnoise(seed)
    grain = _vnoise(seed + 1)
    feather = 70

    def edge(x, y):                                         # 0 outside .. 1 well inside the zone
        k = 1.0                                             # (a ragged, wandering boundary)
        wob = 40 * (noise(3.0, y * 1.5) - 0.5)
        if a > 0:
            k = min(k, (x - a - wob) / feather)
        if b < CW:
            k = min(k, (b - x + wob) / feather)
        return max(0.0, min(1.0, k))
    # the burn points: where it burned hottest — each throws a V of soot up the wall
    pts = []
    x = a + rng.randrange(30, 70)
    while x < b - 30:
        pts.append((x, rng.randrange(128, 156), rng.uniform(0.28, 0.62), rng.uniform(0.3, 0.75)))
        x += rng.randrange(70, 160)
    heads = [d for d in DOORS if a + 20 < d < b - 20]         # smoke poured out of these flats
    soot = (30, 25, 22)
    for y in range(CH):
        for x in range(CW):
            e = edge(x, y)
            if e <= 0.0:
                continue
            n = noise(x, y)
            if y < WALL_TOP:                                     # the ceiling: blackest of all
                s = 0.8 + 0.12 * n
            elif y < FLOOR_Y:
                # the hot smoke layer banked down from the ceiling to a wavering line
                line = 34 + 30 * noise(x * 0.5, 7.0)
                s = 0.78 - 0.3 * (y - WALL_TOP) / max(1.0, line - WALL_TOP) if y < line else \
                    max(0.1, 0.48 * (1.0 - (y - line) / 30.0))
                for (bx, by, spread, st) in pts:                  # V-plumes above the burn points
                    if y < by:
                        h = by - y
                        half = h * spread + 4 + 10 * (grain(x * 0.7, y) - 0.5)
                        dx = abs(x - bx)
                        if dx < half + 12:
                            k = max(0.0, min(1.0, (half + 12 - dx) / 14.0))
                            s = max(s, st * k * (1.0 - 0.35 * h / 140.0) + 0.1)
                for d in heads:                                   # soot curling up over the door head
                    if y < DOOR_TOP + 8:
                        h = DOOR_TOP + 8 - y
                        half = 26 + h * 0.45 + 12 * (grain(x, y * 0.6) - 0.5)
                        dx = abs(x - d)
                        if dx < half:
                            s = max(s, (0.62 - 0.004 * h) * min(1.0, (half - dx) / 16.0))
                    elif abs(x - d) < 29:                          # the door itself, scorched
                        s = max(s, 0.34 * (1.0 - (y - DOOR_TOP) / 86.0))
            else:
                s = 0.2 + 0.25 * n                               # the floor, grimed
            s *= (0.72 + 0.56 * n) * e
            if RECESS[0][0] <= x <= RECESS[0][1] or RECESS[1][0] <= x <= RECESS[1][1]:
                s *= 0.55                                        # the stair shafts, less so
            s = min(0.9, s)
            if s > 0.03:
                px[x, y] = soot + (int(255 * s),)
    # char on the floor: the runner / lino burnt black in clumps, scorched brown at the edges
    for (bx, by, spread, st) in pts:
        cx0 = bx + rng.randrange(-20, 21)
        f = _blob(rng, cx0, 176, rng.randrange(30, 64), rng.randrange(9, 15))
        for y in range(FLOOR_Y + 1, CH):
            for x in range(max(0, cx0 - 100), min(CW, cx0 + 100)):
                if edge(x, y) < 0.5:
                    continue
                d = f(x, y) + 0.35 * (grain(x * 1.6, y * 1.6) - 0.5)
                if d <= 0.85:
                    g = grain(x * 2.3, y * 2.3)
                    px[x, y] = (16, 12, 10, 255) if g < 0.62 else (46, 40, 36, 255) if g < 0.78 else (92, 86, 80, 255)
                elif d <= 1.1:
                    px[x, y] = (58, 34, 22, 190)                     # scorched, not burnt through
    # ash drifted along the skirting, blistered paint in the hot band
    for x in range(CW):
        e = edge(x, FLOOR_Y)
        if e <= 0.2:
            continue
        depth = int(1 + 3 * grain(x * 0.3, 3.0))
        for k in range(depth):
            if rng.random() < e * 0.9:
                px[x, FLOOR_Y + k] = (124, 118, 110, 255) if k < depth - 1 else (86, 80, 74, 255)
    for _ in range(int((b - a) / 4)):
        x, y = rng.randrange(a, b), rng.randrange(WALL_TOP + 26, 120)
        if edge(x, y) > 0.4 and not (y >= DOOR_TOP and any(abs(x - d) < 30 for d in DOORS)):
            px[x, y] = (160, 146, 126, 190)                          # a blister's raised rim
            if y + 1 < CH:
                px[x, y + 1] = (18, 14, 12, 210)
    # charred scraps + fallen ceiling along the wall base
    for _ in range(int((b - a) / 12)):
        x = rng.randrange(max(4, a), min(CW - 6, b))
        if edge(x, FLOOR_Y) < 0.4:
            continue
        y = FLOOR_Y + 1 + rng.randrange(0, 5)
        col = rng.choice([(24, 20, 16, 255), (58, 50, 44, 255), (150, 142, 128, 255)])
        for dx in range(rng.randrange(1, 4)):
            px[x + dx, y] = col
    return img


# --- the endpoint floors -----------------------------------------------------------------------
# floor 30 (hallway — the upper look in a PALE cream damask so the tutorial's red wall hints read,
# only the LEFT stair, and no pictures: the tutorial's hints live between its doors) and the lobby
# (0 — only the RIGHT stair, its own older run overlay `ruin`).
HALLWAY = dict(HIGH['a'], wall='cdbf9c', motif='b9a882', mats=(1, 3))


def main():
    from PIL import Image
    out_dir = os.path.join(ROOT, 'assets', 'corridor')
    prev_dir = os.path.join(ROOT, 'docs', 'art_reference', 'corridor')
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(prev_dir, exist_ok=True)
    made = {}
    keep = set()

    def save(name, im):
        if not name.startswith('fire_'):
            holes = [(x, y) for y in range(CH) for x in range(CW) if im.getpixel((x, y))[3] != 255]
            if holes:
                sys.exit('%s: transparent pixels %s' % (name, holes[:5]))
        im.save(os.path.join(out_dir, '%s.png' % name))
        made[name] = im.copy()
        keep.add(name)
    for si, section in enumerate(('high', 'mid', 'low')):
        for level in SECTION_LEVELS[section]:
            for vi, variant in enumerate(('a', 'b', 'c')):
                seed = 200 + si * 100 + level * 10 + vi
                for run in (1, 2, 3):
                    LAYOUT.clear()
                    LAYOUT.update({'recess': (0, 1), 'spots': SPOTS})
                    name = 'corridor_%s_w%d%s%s' % (section, level, variant, '' if run == 1 else '_r%d' % run)
                    save(name, corridor(section, variant, level, run, seed))
            print('wrote corridor_%s_w%d (a/b/c, runs 1-3)' % (section, level))
    SECTION['hallway'] = dict(SECTION['high'], variants={'h': HALLWAY})
    for run in (1, 2, 3):
        LAYOUT.clear()
        LAYOUT.update({'recess': (0,), 'spots': []})
        save('corridor_hallway' + ('' if run == 1 else '_r%d' % run), corridor('hallway', 'h', 0, run, 74))
    for run in (1, 2, 3):
        LAYOUT.clear()
        LAYOUT.update({'recess': (1,), 'spots': []})
        c = Canvas(w=CW, h=CH, seed=75)
        lobby(c)
        save('corridor_lobby' + ('' if run == 1 else '_r%d' % run), c.img if run == 1 else ruin(c.img.copy(), run, 75))
    print('wrote corridor_hallway, corridor_lobby')
    LAYOUT.clear()
    LAYOUT.update({'recess': (0, 1), 'spots': SPOTS})
    for i, zone in enumerate(FIRE_ZONES):
        save('fire_%s' % zone, fire_overlay(zone, 900 + i))
    print('wrote fire_%s' % '/'.join(FIRE_ZONES))
    for f in os.listdir(out_dir):                          # old looks this script no longer makes
        if f.endswith('.png') and f[:-4] not in keep:
            os.remove(os.path.join(out_dir, f))
            if os.path.exists(os.path.join(out_dir, f + '.import')):
                os.remove(os.path.join(out_dir, f + '.import'))

    def sheet(names, out, under=None):
        im = Image.new('RGBA', (CW, (CH + 4) * len(names)), (0, 0, 0, 255))
        for i, n in enumerate(names):
            if n.startswith('fire_'):
                base = made[under].copy()
                base.alpha_composite(made[n])
                im.paste(base, (0, (CH + 4) * i))
            else:
                im.paste(made[n], (0, (CH + 4) * i))
        im.save(os.path.join(prev_dir, out))
    for f in os.listdir(prev_dir):                         # previews: rebuilt from scratch
        if f.endswith('.png') or f.endswith('.png.import'):
            os.remove(os.path.join(prev_dir, f))
    sheet(['corridor_high_w0a', 'corridor_high_w1a', 'corridor_mid_w1a', 'corridor_mid_w2a',
           'corridor_mid_w3a', 'corridor_low_w3a', 'corridor_low_w4a'], 'corridor_descent.png')
    for s in ('high', 'mid', 'low'):
        lv = SECTION_LEVELS[s][0]
        sheet(['corridor_%s_w%d%s' % (s, lv, v) for v in 'abc'], 'corridor_%s_variants.png' % s)
    sheet(['corridor_mid_w2b', 'corridor_mid_w2b_r2', 'corridor_mid_w2b_r3'], 'corridor_time.png')
    sheet(['fire_%s' % z for z in FIRE_ZONES], 'corridor_fire.png', under='corridor_high_w1a')
    sheet(['corridor_hallway', 'corridor_hallway_r3', 'corridor_lobby'], 'corridor_endpoints.png')


# --- the lobby's run looks (its own older overlay) -----------------------------------------------
DECAY = {2: dict(dark=0.92, damp=4, cracks=6, peel=3, holes=0, blood=2, mould=0.0, debris=18, stains=4),
         3: dict(dark=0.84, damp=8, cracks=14, peel=7, holes=4, blood=6, mould=0.35, debris=44, stains=10)}


def ruin(img, level, seed):
    d = DECAY[level]
    rng = random.Random(seed * 31 + level)
    c = Canvas(w=CW, h=CH, seed=seed)
    c.img = img
    c.px = img.load()
    px = c.px
    for y in range(CH):
        for x in range(CW):
            p = px[x, y]
            px[x, y] = (int(p[0] * d['dark']), int(p[1] * d['dark']), int(p[2] * d['dark']), 255)

    def ok_wall(x, y):
        return clear_of_openings(x) and WALL_TOP + 2 <= y < SKIRT_Y and 18 <= x < CW - 18

    def put(x, y, col):
        if ok_wall(x, y):
            c.put(x, y, col)

    def blob(cx0, cy0, rx, ry):
        ph = [rng.random() * 6.28 for _ in range(3)]

        def f(x, y):
            a = math.atan2((y - cy0) / ry, (x - cx0) / rx)
            k = 1.0 + 0.28 * math.sin(3 * a + ph[0]) + 0.16 * math.sin(5 * a + ph[1]) + 0.08 * math.sin(9 * a + ph[2])
            return (((x - cx0) / rx) ** 2 + ((y - cy0) / ry) ** 2) ** 0.5 / k
        return f
    for _ in range(d['damp']):
        sx, sy = rng.randrange(40, CW - 40), rng.randrange(20, 70)
        rx, ry = rng.randrange(12, 30), rng.randrange(8, 18)
        f = blob(sx, sy, rx, ry)
        for y in range(sy - 2 * ry, sy + 2 * ry):
            for x in range(sx - 2 * rx, sx + 2 * rx):
                if not ok_wall(x, y):
                    continue
                dd = f(x, y)
                p = px[x, y]
                if dd <= 0.86 and ((x * 3 + y * 5) % 4 == 0 or (dd < 0.5 and (x + y) % 2 == 0)):
                    put(x, y, (int(p[0] * 0.75), int(p[1] * 0.72), int(p[2] * 0.62), 255))
                elif 0.86 < dd <= 1.0 and (x + 2 * y) % 3:
                    put(x, y, (int(p[0] * 0.6), int(p[1] * 0.56), int(p[2] * 0.48), 255))
    for _ in range(d['cracks']):
        x, y = rng.randrange(30, CW - 30), rng.randrange(WALL_TOP + 2, 60)
        for k in range(rng.randrange(12, 40)):
            p = px[min(max(x, 0), CW - 1), min(max(y, 0), CH - 1)]
            put(x, y, (int(p[0] * 0.45), int(p[1] * 0.45), int(p[2] * 0.45), 255))
            x += rng.choice((-1, 0, 1, 1))
            y += rng.choice((1, 1, 0))
    plaster = (200, 190, 168, 255)
    for _ in range(d['peel']):
        x0, y0 = rng.randrange(30, CW - 40), rng.randrange(WALL_TOP + 4, 70)
        w, h = rng.randrange(5, 10), rng.randrange(10, 22)
        for y in range(y0, y0 + h):
            s = (y - y0) // 3
            for x in range(x0 + s // 2, x0 + w - s // 2):
                put(x, y, plaster)
        for k in range(h - 4):
            p = px[min(x0 + w + 2, CW - 1), y0 + k]
            put(x0 + w + k // 5, y0 + k, (int(p[0] * 0.6), int(p[1] * 0.6), int(p[2] * 0.6), 255))
    for _ in range(d['holes']):
        cx0, cy0 = rng.randrange(40, CW - 40), rng.randrange(28, 80)
        f = blob(cx0, cy0, rng.randrange(6, 11), rng.randrange(5, 8))
        for y in range(cy0 - 16, cy0 + 16):
            for x in range(cx0 - 22, cx0 + 22):
                dd = f(x, y)
                if dd <= 1.0:
                    put(x, y, (38, 29, 23, 255) if (y - cy0) % 3 else (104, 76, 50, 255))
                elif dd <= 1.3 and (x + y) % 3:
                    put(x, y, plaster)
    if d['mould'] > 0:
        for _ in range(6):
            x0 = rng.randrange(20, CW - 80)
            for y in range(WALL_TOP, WALL_TOP + rng.randrange(10, 24)):
                for x in range(x0, x0 + rng.randrange(30, 70)):
                    if rng.random() < d['mould'] * (1.0 - (y - WALL_TOP) / 26.0):
                        put(x, y, (38, 46, 34, 150))
    blood_c = (74, 29, 27, 170)
    for i in range(d['blood']):
        x0, y0 = rng.randrange(30, CW - 40), rng.randrange(40, 120)
        ln = rng.randrange(10, 30)
        for k in range(ln):
            put(x0 + k, y0 + k // 5, blood_c)
            put(x0 + k, y0 + 1 + k // 5, blood_c)
        for k in range(rng.randrange(2, 5)):
            dx = x0 + rng.randrange(0, ln)
            for y in range(y0 + 2, y0 + 2 + rng.randrange(4, 20)):
                put(dx, y, blood_c)
    for _ in range(d['stains']):
        sx, sy = rng.randrange(10, CW - 10), rng.randrange(164, 190)
        rx, ry = rng.randrange(5, 14), rng.randrange(1, 3)
        col = rng.choice([(58, 20, 18, 140), (40, 34, 26, 120)])
        for y in range(sy - ry, sy + ry + 1):
            for x in range(sx - rx, sx + rx + 1):
                if 0 <= x < CW and FLOOR_Y + 1 <= y < CH and ((x - sx) / rx) ** 2 + ((y - sy) / max(ry, 1)) ** 2 <= 1.0:
                    c.put(x, y, col)
    for _ in range(d['debris']):
        x, y = rng.randrange(6, CW - 6), rng.randrange(162, 190)
        kind = rng.random()
        pts = ([(0, 0), (1, 0), (0, -1), (2, 0)] if kind < 0.5 else [(k, 0) for k in range(5)] if kind < 0.8 else [(0, 0), (2, 1)])
        col = plaster if kind < 0.5 else (214, 208, 190, 255) if kind < 0.8 else (200, 220, 222, 255)
        for (dx, dy) in pts:
            if 0 <= x + dx < CW and FLOOR_Y + 1 <= y + dy < CH:
                c.put(x + dx, y + dy, col)
    return img


if __name__ == '__main__':
    main()
