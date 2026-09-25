"""Corridor art for floors 1-29 (building_floors) — a painted overlay replacing the old tile look.

Run:  python3 tools/art/corridor.py
Out:  assets/corridor/corridor_w<wear><variant>.png (+ _r2 / _r3 run looks), corridor_hallway /
      corridor_lobby, previews in docs/art_reference/corridor/.

One 1120 x 192 image covers the corridor band exactly (world x 115..1235, y 243..435 — the
tilemap's used rect; building_floors.add_corridor_art puts it just above the TileMapLayer, so
doors, stairs, the elevator, lamps, fire and actors all still draw over it). Rows (local y):
  0..15    ceiling + cove
  16..121  wall, 122..124 dado rail, 125..151 lower wall, 152..159 skirting
  160..191 floor, feet line at 176 (world 419)
The two stairwell recesses (local x 16..95 and 1024..1103) get a dim blockwork shaft + a flat
architrave; the staircase sprites draw over them.

SECTIONAL IDENTITY (docs/ART_REQUIREMENTS.md): a NORMAL apartment-block hallway (owner round 12 —
the earlier hotel / mustard / institutional sections were "overly done") that gets more run-down
as you descend: five WEAR levels (building_floors.corridor_wear) x three near-identical VARIANTS
(building_floors.corridor_variant). Run 2 / run 3 redraw the same corridor with more damage +
blood on top. Wear never lands on a door, fixture, stair or the elevator (Spots).
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


# --- the everyday corridor (floors 1-29, and floor 30) ----------------------------------------
# A plain apartment-block hallway: matte paint, a painted dado rail, plain skirting, cord carpet
# or sheet vinyl, and only the fixtures a real one has (radiators, a notice board, fire-alarm call
# points, stairs + exit signs, light switches, a vent). Nothing decorative.
#
# WEAR (by floor, baked in — the building gets more run-down as you go down):
#   0 floors 29-24  kept up           1 floors 23-18  tired: scuffs, a worn carpet path
#   2 floors 17-12  neglected: stains, damp, cracks, a tag or two, a kicked-in patch
#   3 floors 11-6   run down: peeling paint, carpet torn to the screed, tape, bin bags
#   4 floors 5-1    derelict: holes to the blockwork, water damage, mould, carpet ripped up,
#                   skirting gone, rubbish against the walls
# Each level has three VARIANTS (a/b/c) that are nearly the same corridor with small changes
# (paint tone, floor, rail, fixture order), picked per floor by building_floors.corridor_variant.
# The run 2 / run 3 looks (ruin) go on top of whichever one a floor gets.
DADO_Y, LOWER_Y, SKIRT_TOP = 122, 125, 152
DOOR_TOP = 74                      # door sprites cover y >= ~79 at DOORS ±28
ELEV_TOP = 64                      # the elevator sprite covers y >= ~69 at ELEVATOR

VARIANTS = {
    # magnolia over a taupe lower wall, blue-grey cord carpet
    'a': dict(wall='d4ccb9', lower='bcb19b', rail='ebe6d8', skirt='e6e1d3', ceil='dedace',
              floor='carpet', carpet='5b6570', tiles=False, trunking=False,
              fixtures=['notice', 'radiator', 'callpoint', 'radiator'], vent=771, mats=(1, 3)),
    # one pale grey-green all the way down, a wooden rail, brown cord carpet, a suspended ceiling
    # and white cable trunking along the top of the wall
    'b': dict(wall='cfcdbb', lower='c9c7b4', rail='9a7a58', skirt='8c7a62', ceil='dcdad0',
              floor='carpet', carpet='6c6054', tiles=True, trunking=True,
              fixtures=['radiator', 'notice', 'radiator', 'callpoint'], vent=647, mats=(0, 2, 4)),
    # warm white over a grey-green lower wall, dark skirting, speckled sheet vinyl
    'c': dict(wall='d8d0bf', lower='aaa996', rail='e8e3d6', skirt='5f5e58', ceil='dcd8cf',
              floor='vinyl', carpet='a09985', tiles=False, trunking=False,
              fixtures=['callpoint', 'radiator', 'notice', 'radiator'], vent=771, mats=(2,)),
}

WEAR = {
    0: dict(dim=1.00, yellow=0.00, scuffs=8, worn=0.0, stains=0, tide=0, cracks=0, graffiti=0,
            peel=0, kick=0, holes=0, mould=0.0, streaks=0, skirt_gone=0, torn=0, tape=0,
            bags=0, boxes=0, debris=0, ceil_stain=0, ceil_gone=0),
    1: dict(dim=0.98, yellow=0.04, scuffs=26, worn=0.35, stains=4, tide=1, cracks=1, graffiti=0,
            peel=0, kick=0, holes=0, mould=0.0, streaks=0, skirt_gone=0, torn=0, tape=0,
            bags=0, boxes=0, debris=0, ceil_stain=1, ceil_gone=0),
    2: dict(dim=0.955, yellow=0.08, scuffs=40, worn=0.55, stains=9, tide=3, cracks=4, graffiti=2,
            peel=1, kick=1, holes=0, mould=0.0, streaks=1, skirt_gone=0, torn=0, tape=1,
            bags=0, boxes=0, debris=4, ceil_stain=2, ceil_gone=0),
    3: dict(dim=0.925, yellow=0.13, scuffs=55, worn=0.75, stains=14, tide=4, cracks=8, graffiti=4,
            peel=5, kick=2, holes=1, mould=0.25, streaks=3, skirt_gone=1, torn=2, tape=3,
            bags=1, boxes=1, debris=12, ceil_stain=3, ceil_gone=1),
    4: dict(dim=0.89, yellow=0.18, scuffs=65, worn=0.9, stains=20, tide=6, cracks=13, graffiti=6,
            peel=8, kick=3, holes=4, mould=0.5, streaks=6, skirt_gone=3, torn=4, tape=2,
            bags=4, boxes=2, debris=30, ceil_stain=4, ceil_gone=2),
}


class Spots:
    """What's already on the wall, so wear and props never land on a fixture, a door or a stair."""

    def __init__(self):
        self.taken = []

    def take(self, x0, y0, x1, y1):
        self.taken.append((x0, y0, x1, y1))

    def free(self, x0, y0, x1, y1, pad=2):
        if x0 < 6 or x1 > CW - 7:
            return False
        for (a, b) in [RECESS[i] for i in LAYOUT['recess']]:
            if x1 >= a - 8 and x0 <= b + 8:
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


def _noise(c, x0, y0, x1, y1, col, rng, amt=0.05, lo=0.965, hi=1.025):
    """Flat paint with a faint roller texture, so a big wall isn't plastic-flat."""
    dk, lt = shade(col, lo), shade(col, hi)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            r = rng.random()
            c.px[x, y] = dk if r < amt else lt if r < amt * 1.6 else col


def plain_ceiling(c, v, rng):
    col = hexc(v['ceil'])
    _noise(c, 0, 0, CW - 1, 11, col, rng, 0.04)
    c.dither(0, 0, CW - 1, 2, shade(col, 0.9), 0.5)                     # recedes into the dark
    if v['tiles']:                                                       # a suspended grid
        for x in range(20, CW, 48):
            c.vline(x, 0, 11, shade(col, 0.86))
        c.hline(0, CW - 1, 5, shade(col, 0.9))
    c.rect(0, 12, CW - 1, 15, shade(col, 1.03))                          # a plain cove
    c.hline(0, CW - 1, 12, shade(col, 0.84))
    c.hline(0, CW - 1, 15, shade(col, 0.74))
    for x in (300, 790):                                                 # smoke detectors
        c.rect(x - 3, 9, x + 3, 11, hexc('eeece6'))
        c.hline(x - 3, x + 3, 11, hexc('b8b6ae'))
        c.put(x + 1, 10, hexc('c83a2c'))


def plain_wall(c, v, rng):
    wall, lower = hexc(v['wall']), hexc(v['lower'])
    _noise(c, 0, WALL_TOP, CW - 1, DADO_Y - 1, wall, rng)
    c.hline(0, CW - 1, WALL_TOP, shade(wall, 0.82))                      # under the cove
    _noise(c, 0, LOWER_Y, CW - 1, SKIRT_TOP - 1, lower, rng)
    rail = hexc(v['rail'])
    c.rect(0, DADO_Y, CW - 1, LOWER_Y - 1, rail)
    c.hline(0, CW - 1, DADO_Y, shade(rail, 1.1))
    c.hline(0, CW - 1, LOWER_Y - 1, shade(rail, 0.7))
    c.hline(0, CW - 1, LOWER_Y, shade(lower, 0.9))                       # the rail's shadow
    sk = hexc(v['skirt'])
    c.rect(0, SKIRT_TOP, CW - 1, FLOOR_Y - 1, sk)
    c.hline(0, CW - 1, SKIRT_TOP, shade(sk, 1.12))
    c.hline(0, CW - 1, SKIRT_TOP + 1, shade(sk, 1.05))
    c.hline(0, CW - 1, FLOOR_Y - 1, shade(sk, 0.72))
    if v['trunking']:
        c.rect(0, 18, CW - 1, 20, hexc('e4e2da'))
        c.hline(0, CW - 1, 20, hexc('a8a69e'))
        for x in range(60, CW, 180):
            c.vline(x, 18, 20, hexc('c4c2ba'))


def plain_floor(c, v, rng):
    base = hexc(v['carpet'])
    rows = [160, 165, 171, 178, 186, 192]                                # tile rows, nearer = deeper
    if v['floor'] == 'carpet':
        for r in range(len(rows) - 1):
            y0, y1 = rows[r], rows[r + 1] - 1
            off = 0 if r % 2 == 0 else 24
            for x in range(-off, CW, 48):
                tone = shade(base, (0.97, 1.0, 1.03)[((x + off) // 48 * 7 + r * 5) % 3])
                dk, lt = shade(tone, 0.9), shade(tone, 1.07)
                for y in range(y0, y1 + 1):
                    for xx in range(max(0, x), min(CW, x + 48)):
                        q = rng.random()
                        c.px[xx, y] = dk if q < 0.22 else lt if q < 0.3 else tone
                for y in range(y0, y1 + 1, 2):                           # a barely-there seam
                    if 0 <= x < CW:
                        c.put(x, y, shade(tone, 0.92))
    else:                                                                # speckled sheet vinyl
        flecks = [shade(base, 0.8), shade(base, 1.12), hexc('7a8a8a'), hexc('a88a6a')]
        for y in range(FLOOR_Y, CH):
            for x in range(CW):
                q = rng.random()
                c.px[x, y] = flecks[int(q * 40) % 4] if q < 0.1 else base
        for x in range(150, CW, 370):                                    # a welded seam
            for y in range(FLOOR_Y, CH):
                c.put(x + (y - FLOOR_Y) // 8, y, shade(base, 0.84))
        c.hline(0, CW - 1, 183, shade(base, 1.05))                       # a faint sheen
    c.hline(0, CW - 1, FLOOR_Y, shade(base, 0.52))                       # contact shadow
    c.hline(0, CW - 1, FLOOR_Y + 1, shade(base, 0.76))


def plain_stairs(c, v):
    """The stairwell openings: a dim painted-block shaft + a flat painted architrave."""
    wall = hexc(v['wall'])
    dim = shade(mix(wall, hexc('8a8a86'), 0.4), 0.46)
    trim = hexc(v['rail']) if v['rail'] != '9a7a58' else hexc('e6e1d3')
    for (a, b) in [RECESS[i] for i in LAYOUT['recess']]:
        c.rect(a, WALL_TOP, b, FLOOR_Y - 1, dim)
        for y in range(WALL_TOP + 6, FLOOR_Y, 8):                        # blockwork courses
            c.hline(a, b, y, shade(dim, 0.86))
            for x in range(a + (0 if (y // 8) % 2 else 12), b, 24):
                c.vline(x, y - 7, y, shade(dim, 0.86))
        c.dither(a, WALL_TOP, b, WALL_TOP + 14, shade(dim, 0.72), 0.5)
        for (x0, x1) in ((a - 5, a - 1), (b + 1, b + 5)):
            c.rect(x0, WALL_TOP, x1, FLOOR_Y - 1, trim)
            c.vline(x0, WALL_TOP, FLOOR_Y - 1, shade(trim, 0.72))
            c.vline(x1, WALL_TOP, FLOOR_Y - 1, shade(trim, 0.8))
            c.vline(x0 + 1, WALL_TOP, FLOOR_Y - 1, shade(trim, 1.06))


# --- fixtures --------------------------------------------------------------------------------
def radiator(c, cx, lvl, sp):
    x0, x1, y0, y1 = cx - 17, cx + 17, 129, 147
    body = shade(hexc('e8e6dc'), 1.0 - 0.03 * lvl)
    c.rect(x0, y0, x1, y1, body)
    for x in range(x0 + 2, x1, 3):                                       # the convector fins
        c.vline(x, y0 + 2, y1 - 1, shade(body, 0.86))
    c.hline(x0, x1, y0, shade(body, 1.06))
    c.hline(x0, x1, y1, shade(body, 0.66))
    c.vline(x0, y0, y1, shade(body, 0.8))
    c.vline(x1, y0, y1, shade(body, 0.72))
    for x in (x0 + 4, x1 - 4):                                           # brackets
        c.rect(x, y1 + 1, x + 1, y1 + 2, hexc('8a8880'))
    c.rect(x0 - 3, y1 - 3, x0 - 1, y1 - 1, hexc('c8c6be'))               # valve + pipe to the floor
    c.vline(x0 - 2, y1, FLOOR_Y - 1, hexc('b8b6ae'))
    c.put(x0 - 2, y1 - 4, hexc('7a7870'))
    rng = random.Random(cx * 7 + lvl)
    if lvl >= 2:                                                         # rust weeping from the valve
        for k in range(lvl * 2):
            x = rng.randrange(x0, x1)
            for y in range(y1 - rng.randrange(2, 4 + 3 * lvl), y1 + 1):
                c.put(x, y, hexc('8a5a34', 150 + 20 * min(lvl, 4)))
    if lvl >= 3:                                                         # paint flaking off
        for k in range(lvl * 4):
            x, y = rng.randrange(x0 + 1, x1), rng.randrange(y0 + 1, y1)
            c.rect(x, y, x + 1, y, hexc('7a5236'))
    if lvl >= 4:
        c.rect(x0 + 8, y0 + 4, x0 + 12, y0 + 9, hexc('6a4a30'))          # a dent, rusted through
        c.hline(x0 + 8, x0 + 12, y0 + 4, shade(body, 0.6))
    sp.take(x0 - 4, y0, x1, FLOOR_Y - 1)


def notice_board(c, cx, lvl, sp, rng):
    x0, x1, y0, y1 = cx - 17, cx + 17, 34, 60
    sp.take(x0, y0, x1, y1)
    if lvl >= 4:                                                          # taken down: a clean patch
        p = c.px[cx, 30]
        clean = (min(255, p[0] + 16), min(255, p[1] + 16), min(255, p[2] + 14), 255)
        c.rect(x0, y0, x1, y1, clean)
        for (x, y) in ((x0 + 1, y0 + 1), (x1 - 1, y0 + 1), (x0 + 1, y1 - 1), (x1 - 1, y1 - 1)):
            c.put(x, y, hexc('4a4640'))
        return
    c.rect(x0, y0, x1, y1, hexc('b8b6b0'))                               # an aluminium frame
    c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, hexc('a47c52'))              # cork
    c.dither(x0 + 2, y0 + 2, x1 - 2, y1 - 2, hexc('94703f'), 0.3, pattern='random')
    c.hline(x0, x1, y1, hexc('6a6862'))
    c.vline(x1, y0, y1, hexc('7a7872'))
    paper = shade(hexc('eeeae0'), 1.0 - 0.04 * lvl)
    notes = [(x0 + 4, y0 + 4, 10, 13, paper), (x0 + 16, y0 + 5, 12, 9, hexc('e0cf5a')),
             (x0 + 17, y0 + 16, 10, 6, paper), (x0 + 5, y0 + 19, 9, 3, hexc('9cc0d8'))]
    keep = len(notes) - (1 if lvl >= 2 else 0) - (2 if lvl >= 3 else 0)
    for i, (x, y, w, h, col) in enumerate(notes[:keep]):
        if lvl >= 1 and i == 0:                                           # curling at a corner
            c.rect(x, y, x + w, y + h, col)
            c.poly([(x + w - 3, y + h), (x + w, y + h - 3), (x + w, y + h)], hexc('a47c52'))
        elif lvl >= 2 and i == keep - 1:                                  # hanging by one pin
            c.poly([(x, y), (x + w, y + 2), (x + w - 2, y + h + 2), (x - 2, y + h)], col)
        else:
            c.rect(x, y, x + w, y + h, col)
        if col == paper:
            for yy in range(y + 3, y + h - 1, 2):
                c.hline(x + 2, x + w - 3, yy, hexc('9a968c'))
        c.put(x + w // 2, y + 1, hexc('c83a2c'))
    if lvl >= 3:                                                          # scraps left on the pins
        for (x, y) in ((x0 + 8, y0 + 5), (x0 + 22, y0 + 8), (x0 + 12, y0 + 18)):
            c.rect(x - 1, y, x + 2, y + 2, paper)
            c.put(x, y, hexc('c83a2c'))


def call_point(c, cx, lvl, sp):
    x0, y0 = cx - 4, 64
    c.box(x0, y0, x0 + 8, y0 + 8, hexc('c43a2e'), hexc('7a1e18'))
    c.rect(x0 + 2, y0 + 2, x0 + 6, y0 + 6, hexc('eeeae0') if lvl < 4 else hexc('3a2a26'))
    if lvl == 3:
        c.line(x0 + 2, y0 + 2, x0 + 6, y0 + 6, hexc('8a8a86'))
    c.hline(x0 + 1, x0 + 7, y0 + 7, hexc('9a2a22'))
    sp.take(x0, y0, x0 + 8, y0 + 8)


def light_switch(c, x, lvl, sp):
    y0 = 86
    if lvl >= 3 and x % 3 == 0:                                          # the cover's gone
        c.rect(x - 2, y0, x + 2, y0 + 5, hexc('4a4640'))
        c.put(x, y0 + 5, hexc('b8423a'))
        c.put(x, y0 + 6, hexc('b8423a'))
    else:
        col = shade(hexc('e6e2d6'), 1.0 - 0.04 * lvl)
        c.box(x - 2, y0, x + 2, y0 + 5, col, shade(col, 0.72))
        c.put(x, y0 + 2, hexc('d88a3a'))                                  # the timer button
    sp.take(x - 2, y0, x + 2, y0 + 6)


def stairs_sign(c, cx, pointing, lvl, sp):
    x0, x1, y0, y1 = cx - 13, cx + 13, 30, 39
    col = shade(hexc('eeeae0'), 1.0 - 0.03 * lvl)
    drop = 7 if lvl >= 4 else 0                                          # hanging off one screw
    bg = c.img.crop((x0, y0, x1 + 1, y1 + 1 + drop)) if drop else None
    c.box(x0, y0, x1, y1, col, hexc('3a8a4a'))
    c.rect(x0 + 1, y0 + 1, x0 + 8, y1 - 1, hexc('3a8a4a'))                # the green pictogram tab
    c.put(x0 + 5, y0 + 2, col)
    c.vline(x0 + 4, y0 + 3, y0 + 5, col)
    c.line(x0 + 4, y0 + 5, x0 + 2, y0 + 7, col)
    c.line(x0 + 4, y0 + 5, x0 + 6, y0 + 7, col)
    ax = x1 - 5
    if pointing < 0:
        ax = x0 + 13
    for k in range(4):                                                    # an arrow + "STAIRS" squiggle
        c.put(ax + (k if pointing < 0 else -k), y0 + 4 - k // 2, hexc('3a8a4a'))
        c.put(ax + (k if pointing < 0 else -k), y0 + 5 + k // 2, hexc('3a8a4a'))
    c.hline(ax - 3 if pointing > 0 else ax, ax if pointing > 0 else ax + 3, y0 + 4, hexc('3a8a4a'))
    for x in range(x0 + 11 if pointing > 0 else x0 + 18, (x1 - 8 if pointing > 0 else x1 - 2), 2):
        c.put(x, y0 + 4, hexc('5a5a56'))
    if drop:
        sign = c.img.crop((x0, y0, x1 + 1, y1 + 1))
        c.img.paste(bg, (x0, y0))
        for x in range(x1 - x0 + 1):
            dy = int(round(drop * x / (x1 - x0))) if pointing > 0 else int(round(drop * (x1 - x0 - x) / (x1 - x0)))
            c.img.paste(sign.crop((x, 0, x + 1, y1 - y0 + 1)), (x0 + x, y0 + dy))
        c.put(x1 - 2 if pointing > 0 else x0 + 2, y0 + 2, hexc('4a4640'))      # the screw it lost
        c.px = c.img.load()
    sp.take(x0, y0, x1, y1 + drop)


def exit_sign(c, lvl, sp):
    x0, x1, y0, y1 = 856, 876, 40, 49
    lit = lvl < 4
    c.box(x0, y0, x1, y1, hexc('2f8a48') if lit else hexc('1f4a2a'), hexc('1a3a22'))
    c.rect(x0 + 2, y0 + 2, x0 + 7, y1 - 2, hexc('e6f2e0') if lit else hexc('8a9a88'))
    for x in range(x0 + 10, x1 - 2, 2):
        c.vline(x, y0 + 3, y1 - 3, hexc('d8ecd2') if lit else hexc('5a6a58'))
    sp.take(x0, y0, x1, y1)


def vent(c, cx, lvl, sp):
    x0, x1, y0, y1 = cx - 8, cx + 8, 23, 30
    c.box(x0, y0, x1, y1, hexc('d0cec6'), hexc('8a8880'))
    for y in range(y0 + 2, y1, 2):
        c.hline(x0 + 2, x1 - 2, y, hexc('6a6862') if lvl < 3 else hexc('3a3834'))
    if lvl >= 3:                                                           # grime streaking down
        for x in range(x0 + 2, x1 - 1, 3):
            for y in range(y1 + 1, y1 + 3 + (x * 5) % (4 + 2 * lvl)):
                c.put(x, y, hexc('4a4236', 70))
    if lvl >= 4:                                                           # a wire hanging out
        c.line(x1 - 3, y1, x1 - 1, y1 + 9, hexc('2a2a2a'))
        c.line(x1 - 1, y1 + 9, x1 + 2, y1 + 14, hexc('b8423a'))
    sp.take(x0, y0, x1, y1 + 4)


def fixtures(c, v, lvl, sp, rng):
    for kind, x in zip(v['fixtures'], LAYOUT['spots']):
        if kind == 'notice':
            notice_board(c, x, lvl, sp, rng)
        elif kind == 'radiator':
            radiator(c, x, lvl, sp)
        elif kind == 'callpoint':
            call_point(c, x, lvl, sp)
            radiator(c, x, lvl, sp)
    if LAYOUT['spots']:
        for d in DOORS:
            light_switch(c, d + 35, lvl, sp)
        vent(c, v['vent'], lvl, sp)
        if v['vent'] != 771:
            radiator(c, 771, lvl, sp)
    for x in LAYOUT.get('radiators', []):
        radiator(c, x, lvl, sp)
    rec = LAYOUT['recess']
    if 0 in rec:
        stairs_sign(c, 143, -1, lvl, sp)
    if 1 in rec:
        stairs_sign(c, 975, 1, lvl, sp)
    exit_sign(c, lvl, sp)


# --- wear -------------------------------------------------------------------------------------
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
    for y in range(CH):
        wall = WALL_TOP <= y < SKIRT_TOP
        yb = 1.0 - w['yellow'] if wall else 1.0 - w['yellow'] * 0.4
        for x in range(CW):
            p = c.px[x, y]
            c.px[x, y] = _mul(p, w['dim'], w['dim'] * (1.0 - w['yellow'] * 0.25), w['dim'] * yb)


def wear_walls(c, w, sp, rng, zones):
    px = c.px

    def wall_ok(x, y):
        return 0 <= x < CW and WALL_TOP + 1 <= y < SKIRT_TOP and sp.free(x, y, x, y, 0)

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
        rx, ry = rng.randrange(14, 26), rng.randrange(12, 24)
        f = _blob(rng, cx, WALL_TOP, rx, ry)                                 # hangs off the ceiling
        for y in range(WALL_TOP + 1, WALL_TOP + ry * 2):
            for x in range(cx - rx * 2, cx + rx * 2):
                if not wall_ok(x, y):
                    continue
                d, p = f(x, y), px[x, y]
                if d < 0.84:                                                  # a faint brown wash
                    put(x, y, _mul(p, 0.95, 0.92, 0.84))
                elif d < 0.97:                                                # the dried tide line
                    put(x, y, _mul(p, 0.8, 0.72, 0.58))
                elif d < 1.08 and (x + y) % 2:
                    put(x, y, _mul(p, 0.9, 0.85, 0.74))
        rings = 1 + (w['tide'] >= 4)
        for k in range(1, rings):                                              # an older, wider ring
            f2 = _blob(rng, cx + rng.randrange(-4, 5), WALL_TOP, rx * 1.35, ry * 1.3)
            for y in range(WALL_TOP + 1, WALL_TOP + ry * 3):
                for x in range(cx - rx * 3, cx + rx * 3):
                    if wall_ok(x, y) and 0.93 < f2(x, y) < 1.02 and (x + y) % 3:
                        put(x, y, _mul(px[x, y], 0.86, 0.8, 0.68))
        for _ in range(w['streaks'] // max(1, w['tide']) + (1 if w['streaks'] else 0)):
            x = cx + rng.randrange(-rx // 2, rx // 2 + 1)                     # water running down
            for y in range(WALL_TOP + ry, WALL_TOP + ry + 20 + rng.randrange(0, 60)):
                put(x, y, _mul(get(x, y), 0.84, 0.78, 0.66))
                if rng.random() < 0.06:
                    x += rng.choice((-1, 1))
        if w['mould'] > 0:                                                    # black mould in the wet
            for y in range(WALL_TOP + 1, WALL_TOP + ry):
                for x in range(cx - rx, cx + rx):
                    d = f(x, y)
                    k = w['mould'] * max(0.0, 0.9 - d) * (1.0 - (y - WALL_TOP) / ry)
                    if rng.random() < k * 1.6:
                        put(x, y, hexc('2c3228', 170 + int(80 * min(1.0, k * 2))))
    for _ in range(w['cracks']):
        x, y = rng.randrange(20, CW - 20), rng.randrange(WALL_TOP + 1, 70)
        if zones and rng.random() < 0.7:
            x = min(max(20, int(rng.gauss(rng.choice(zones), 60))), CW - 20)
        for k in range(rng.randrange(10, 34)):
            put(x, y, _mul(get(x, y), 0.55, 0.55, 0.55))
            x += rng.choice((-1, 0, 1, 1))
            y += 1
    old = hexc('aab0a0')                                                     # the grey-green it used to be
    plaster = hexc('cbb89c')
    for _ in range(w['peel']):                                               # paint flaking off
        at = sp.find(rng, 18, 22, WALL_TOP + 4, DADO_Y - 4, pad=3, zones=zones)
        if not at:
            continue
        x0, y0 = at
        f = _blob(rng, x0 + 9, y0 + 11, rng.randrange(5, 9), rng.randrange(6, 11))
        g = _blob(rng, x0 + 9, y0 + 12, rng.randrange(2, 5), rng.randrange(3, 6))
        for y in range(y0 - 6, y0 + 28):
            for x in range(x0 - 6, x0 + 24):
                d = f(x, y)
                if d <= 1.0:
                    put(x, y, plaster if g(x, y) <= 1.0 else (old if (x * 5 + y * 3) % 11 else shade(old, 0.92)))
                elif d <= 1.14:
                    p = get(x, y)                                             # the lifted, curling lip
                    put(x, y, shade(p, 1.1) if (y < y0 + 11) == (x < x0 + 9) else _mul(p, 0.66, 0.64, 0.6))
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
    for _ in range(w['kick']):                                               # a kicked-in lower wall
        at = sp.find(rng, 14, 10, LOWER_Y + 4, SKIRT_TOP - 2, pad=3, zones=zones)
        if not at:
            continue
        x0, y0 = at
        f = _blob(rng, x0 + 7, y0 + 5, 6, 4)
        for y in range(y0 - 4, y0 + 12):
            for x in range(x0 - 4, x0 + 18):
                d = f(x, y)
                if d <= 1.0:
                    put(x, y, hexc('2e2a26') if y < y0 + 3 else hexc('4a443c'))
                elif d <= 1.3 and (x + 2 * y) % 3:
                    put(x, y, plaster)
        sp.take(x0, y0, x0 + 14, y0 + 10)
    tags = [hexc('1e1e22'), hexc('8a2a2a'), hexc('2a3a6a')]
    for i in range(w['graffiti']):                                           # a marker tag, 2px strokes
        at = sp.find(rng, 30, 14, 44, DADO_Y - 4, pad=4, zones=zones)
        if not at:
            continue
        x0, y0 = at
        col = tags[i % 3]
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
        x, y = rng.randrange(8, CW - 20), rng.choice((rng.randrange(LOWER_Y + 2, SKIRT_TOP - 1),
                                                      rng.randrange(DADO_Y - 18, DADO_Y - 1)))
        for k in range(rng.randrange(2, 9)):
            put(x + k, y + (k // 4), _mul(get(x + k, y), 0.8, 0.79, 0.77))
    for _ in range(w['skirt_gone']):                                         # skirting ripped off
        at = sp.find(rng, 30, 6, SKIRT_TOP, SKIRT_TOP + 1, pad=2, zones=zones)
        if not at:
            continue
        x0 = at[0]
        for x in range(x0, x0 + 30):                                        # bare plaster the paint
            for y in range(SKIRT_TOP, FLOOR_Y):                              # never reached
                c.put(x, y, plaster if (x * 3 + y) % 7 else shade(plaster, 0.9))
            c.put(x, SKIRT_TOP, _mul(get(x, SKIRT_TOP - 1), 0.72, 0.7, 0.66))
            c.put(x, FLOOR_Y - 1, hexc('5a5044'))                            # grime along the floor
        c.vline(x0, SKIRT_TOP, FLOOR_Y - 1, hexc('5a5044'))
        c.vline(x0 + 29, SKIRT_TOP, FLOOR_Y - 1, hexc('5a5044'))
        for x in range(x0 + 4, x0 + 28, 8):                                  # the nail holes
            c.put(x, SKIRT_TOP + 3, hexc('3a3a3a'))


def wear_ceiling(c, v, w, rng):
    for i in range(w['ceil_stain']):
        cx = rng.randrange(60, CW - 60)
        f = _blob(rng, cx, 6, rng.randrange(10, 20), 5)
        for y in range(0, 12):
            for x in range(cx - 30, cx + 30):
                if 0 <= x < CW and f(x, y) <= 1.0:
                    p = c.px[x, y]
                    c.px[x, y] = _mul(p, 0.86, 0.8, 0.66) if f(x, y) > 0.7 else _mul(p, 0.94, 0.9, 0.8)
    for i in range(w['ceil_gone'] if v['tiles'] else 0):                      # a ceiling tile down
        x0 = 20 + 48 * rng.randrange(3, 20) + 1
        c.rect(x0, 0, x0 + 46, 11, hexc('1e1c1a'))
        c.dither(x0, 0, x0 + 46, 4, hexc('2e2a26'), 0.5)
        c.line(x0 + 14, 11, x0 + 16, 15, hexc('2a2a2a'))                     # cables hanging out
        c.line(x0 + 30, 11, x0 + 29, 17, hexc('b8423a'))
    if not v['tiles'] and w['ceil_gone']:                                     # plaster ceiling: cracked
        for i in range(w['ceil_gone'] * 2):
            x, y = rng.randrange(80, CW - 80), rng.randrange(2, 9)
            for k in range(rng.randrange(20, 50)):
                c.put(x, y, _mul(c.px[min(x, CW - 1), y], 0.62, 0.62, 0.62))
                x += 1
                if rng.random() < 0.35:
                    y = min(10, max(1, y + rng.choice((-1, 1))))


def wear_floor(c, v, w, sp, rng):
    px = c.px
    base = hexc(v['carpet'])
    if w['worn'] > 0:                                                        # the walked-on path
        for y in range(168, 186):
            k = 1.0 - abs(y - 177) / 9.0
            for x in range(CW):
                if rng.random() < w['worn'] * k * 0.5:
                    p = px[x, y]
                    px[x, y] = _mul(p, 1.06, 1.04, 1.0) if v['floor'] == 'carpet' else _mul(p, 0.9, 0.88, 0.84)
    for _ in range(w['stains']):
        sx, sy = rng.randrange(10, CW - 10), rng.randrange(163, 190)
        f = _blob(rng, sx, sy, rng.randrange(4, 13), rng.randrange(1, 4))
        col = rng.choice([(0.72, 0.66, 0.58), (0.8, 0.78, 0.74), (0.62, 0.5, 0.46)])
        for y in range(sy - 6, sy + 6):
            for x in range(sx - 20, sx + 20):
                if 0 <= x < CW and FLOOR_Y + 2 <= y < CH and f(x, y) <= 1.0:
                    px[x, y] = _mul(px[x, y], *col)
    screed, glue = hexc('8e8a80'), hexc('6e6440')
    for i in range(w['torn']):                                               # carpet torn up to the screed
        x0 = rng.randrange(40, CW - 140)
        ww = rng.randrange(40, 90) + 30 * (w['torn'] >= 4)
        y0 = rng.randrange(163, 172)
        f = _blob(rng, x0 + ww // 2, y0 + 10, ww // 2, rng.randrange(6, 11))
        for y in range(FLOOR_Y + 2, CH):
            for x in range(x0 - 10, x0 + ww + 10):
                if not (0 <= x < CW):
                    continue
                d = f(x, y)
                if d <= 1.0:
                    px[x, y] = glue if (x * 7 + y * 3) % 23 == 0 else (screed if (x + y) % 5 else shade(screed, 0.92))
                elif d <= 1.12:
                    px[x, y] = shade(base, 1.18) if y < y0 + 10 else shade(base, 0.6)   # the ragged edge
    for i in range(w['tape']):                                               # gaffer tape over a split
        x0 = rng.randrange(40, CW - 60)
        y0 = rng.randrange(166, 184)
        for k in range(rng.randrange(18, 36)):
            for t in range(3):
                x, y = x0 + k, y0 + t + k // 12
                if 0 <= x < CW and y < CH:
                    px[x, y] = hexc('a8aaa6') if t else hexc('c8cac6')


def bin_bag(c, x0, sp, rng):
    """A black bin bag slumped against the wall, sitting on the carpet at the skirting."""
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
        mid = cx + lean * int(2 * (1 - t))
        for x in range(int(mid - hw), int(mid + hw) + 1):
            u = (x - (mid - hw)) / max(1, 2 * hw)
            col = hexc('25272b')
            if u < 0.22 and 0.2 < t < 0.85:
                col = hexc('3b3f45')                                       # the sheen on the plastic
            elif u > 0.8:
                col = hexc('17181b')
            if (x - int(mid) + int(t * 9)) % 7 == 0 and 0.15 < t < 0.9:
                col = hexc('1c1d20')                                       # creases
            c.put(x, y, col)
        if y == base_y:
            c.hline(int(mid - hw), int(mid + hw), y, hexc('121314'))
    c.rect(cx - 2, top + 1, cx + 2, top + 4, hexc('2e3136'))              # the gathered neck
    c.poly([(cx - 1, top + 1), (cx - 6, top - 3), (cx - 3, top + 2)], hexc('2e3136'))   # the tied ears
    c.poly([(cx + 1, top + 1), (cx + 6, top - 2), (cx + 3, top + 2)], hexc('25272b'))
    c.put(cx - 1, top + 2, hexc('4a4e56'))
    sp.take(x0 - 4, top - 4, x0 + w + 4, base_y)


def doormats(c, v, lvl):
    """A mat outside some flats — the residents who still bother. Fewer and filthier lower down."""
    mats = v['mats'][:max(0, len(v['mats']) - lvl // 2)] if lvl < 4 else ()
    for i in mats:
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
        c.rect(x0 + 3, y0 + 2, x1 - 3, y0 + 2, shade(col, 0.8))
        c.shadow(d, y1 + 1, 16, 1, alpha=60)


def flat_box(c, x0, sp, rng):
    """A flattened cardboard box leaning against the wall."""
    w = rng.randrange(20, 28)
    x1, y0, y1 = x0 + w, 126, FLOOR_Y + 3
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
        at = sp.find(rng, 44, 30, SKIRT_TOP - 20, SKIRT_TOP - 18, pad=3, zones=zones)
        if at:
            n = 1 + (rng.random() < 0.6)                                   # bags come in heaps
            for k in range(n):
                bin_bag(c, at[0] + k * 16, sp, rng)
    for _ in range(w['boxes']):
        at = sp.find(rng, 34, 34, 124, 126, pad=3, zones=zones)
        if at:
            flat_box(c, at[0], sp, rng)
    for _ in range(w['debris']):                                            # grit, never mid-lane:
        x = rng.randrange(8, CW - 8)                                        # it lies along the wall
        y = FLOOR_Y + 2 + rng.randrange(0, 4)
        c.rect(x, y, x + rng.randrange(0, 2), y, rng.choice([hexc('d2c2a6'), hexc('8a8478'), hexc('5a544a')]))


def normal(c, level, variant, seed):
    """One everyday corridor at a wear level (0 kept up .. 4 derelict), variant a/b/c."""
    v, w = VARIANTS[variant], WEAR[level]
    rng = random.Random(seed)
    sp = Spots()
    plain_ceiling(c, v, rng)
    plain_wall(c, v, rng)
    plain_floor(c, v, rng)
    plain_stairs(c, v)
    fixtures(c, v, level, sp, rng)
    doormats(c, v, level)
    age_paint(c, w)
    # the rot gathers in a few stretches (a leak, a flat that went bad) rather than evenly
    zones = [rng.randrange(170, CW - 170) for _ in range(1 + level // 2)] if level >= 2 else None
    wear_ceiling(c, v, w, rng)
    wear_walls(c, w, sp, rng, zones)
    wear_floor(c, v, w, sp, rng)
    props(c, w, sp, rng, zones)
    return sp, zones


# --- run looks: the same corridor, later in the day ------------------------------------------
# Run 2 / run 3 redraw the floor's own corridor and ADD damage in the same style on top (more in
# the stretches that were already rotting), dim it, and bring the blood in. Every count below is
# an extra on top of the floor's wear level.
_NONE = {k: 0 for k in WEAR[0]}
RUN_EXTRA = {
    2: dict(_NONE, dim=0.95, yellow=0.0, scuffs=20, stains=6, tide=1, cracks=3, peel=2,
            graffiti=1, debris=10, bags=1, blood=2),
    3: dict(_NONE, dim=0.88, yellow=0.0, scuffs=30, stains=12, tide=2, cracks=6, peel=4, holes=1,
            kick=1, graffiti=2, mould=0.2, torn=1, debris=24, bags=2, blood=5),
}


def blood(c, n, sp, rng, zones):
    # smears at hand height, a handprint, drips, and (run 3) a trail dragged along the floor
    red, dk = hexc('5e1c18', 200), hexc('3e1210', 220)

    def put(x, y, col):
        if 0 <= x < CW and WALL_TOP < y < SKIRT_TOP and sp.free(x, y, x, y, 0):
            c.put(x, y, col)
    for i in range(n):
        at = sp.find(rng, 40, 24, 84, DADO_Y + 6, pad=3, zones=zones)
        if not at:
            continue
        x0, y0 = at
        kind = i % 3
        if kind == 0:                                                    # a smear dragged sideways
            ln = rng.randrange(18, 38)
            for k in range(ln):
                th = max(1, 3 - k * 3 // ln)
                for t in range(th):
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
            x = x0 + k
            if rng.random() < 0.75 - k / 400.0:
                c.put(x, y + (k // 40) % 2, hexc('4a1612', 150))
                if rng.random() < 0.5:
                    c.put(x, y + 1 + (k // 40) % 2, hexc('4a1612', 110))


def run_look(c, v, level, run, sp, zones, seed):
    x = RUN_EXTRA[run]
    rng = random.Random(seed * 7 + run * 1009)
    zones = zones or [rng.randrange(170, CW - 170) for _ in range(1 + run // 2)]
    age_paint(c, x)
    wear_walls(c, x, sp, rng, zones)
    wear_floor(c, v, x, sp, rng)
    props(c, x, sp, rng, zones)
    blood(c, x['blood'], sp, rng, zones)


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
    c.box(860, 40, 872, 50, hexc('2e5a3a'), hexc('1a3020'))
    c.rect(862, 43, 870, 46, hexc('d8e8c8'))


# --- run looks -------------------------------------------------------------------------------
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
    blood = (74, 29, 27, 170)
    for i in range(d['blood']):
        x0, y0 = rng.randrange(30, CW - 40), rng.randrange(40, 120)
        ln = rng.randrange(10, 30)
        for k in range(ln):
            put(x0 + k, y0 + k // 5, blood)
            put(x0 + k, y0 + 1 + k // 5, blood)
        for k in range(rng.randrange(2, 5)):
            dx = x0 + rng.randrange(0, ln)
            for y in range(y0 + 2, y0 + 2 + rng.randrange(4, 20)):
                put(dx, y, blood)
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


def hallway(c, seed):
    # floor 30: the kept-up corridor (wear 0, variant a) — pale walls so the tutorial's red wall
    # hints read; radiators only (the hints live between its doors); left stair only
    return normal(c, 0, 'a', seed)


LEVELS = range(5)
SCENES = {'hallway': (hallway, 74, {'recess': (0,), 'spots': [], 'radiators': SPOTS}),
          'lobby': (lambda c, seed: lobby(c), 75, {'recess': (1,), 'spots': []})}


def main():
    from PIL import Image
    out_dir = os.path.join(ROOT, 'assets', 'corridor')
    prev_dir = os.path.join(ROOT, 'docs', 'art_reference', 'corridor')
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(prev_dir, exist_ok=True)
    for f in os.listdir(out_dir):                          # old looks this script no longer makes
        if f.startswith('corridor_') and f.split('.')[0].split('_r')[0] not in \
                ['corridor_w%d%s' % (l, v) for l in LEVELS for v in VARIANTS] + ['corridor_%s' % n for n in SCENES]:
            os.remove(os.path.join(out_dir, f))
            if os.path.exists(os.path.join(out_dir, f + '.import')):
                os.remove(os.path.join(out_dir, f + '.import'))
    jobs = []
    for level in LEVELS:
        for i, variant in enumerate(VARIANTS):
            seed = 100 + level * 10 + i
            jobs.append(('w%d%s' % (level, variant), (lambda c, s, l=level, v=variant: normal(c, l, v, s)),
                         seed, {'recess': (0, 1), 'spots': SPOTS}, (level, variant)))
    jobs += [(n, fn, seed, lay, (0, 'a') if n == 'hallway' else None) for n, (fn, seed, lay) in SCENES.items()]
    made = {}

    def opaque(name, im):
        holes = [(x, y) for y in range(CH) for x in range(CW) if im.getpixel((x, y))[3] != 255]
        if holes:
            sys.exit('%s: transparent pixels %s' % (name, holes[:5]))
    for name, fn, seed, lay, spec in jobs:
        LAYOUT.clear()
        LAYOUT.update(lay)
        c = Canvas(w=CW, h=CH, seed=seed)
        fn(c, seed)
        opaque(name, c.img)
        c.img.save(os.path.join(out_dir, 'corridor_%s.png' % name))
        made[name] = c.img.copy()
        for run in (2, 3):
            if spec:                                              # the everyday corridors: redraw + add
                c = Canvas(w=CW, h=CH, seed=seed)
                sp, zones = fn(c, seed)
                run_look(c, VARIANTS[spec[1]], spec[0], run, sp, zones, seed)
                im = c.img
            else:                                                 # the lobby keeps its old overlay
                im = ruin(c.img.copy(), run, seed)
            opaque('%s_r%d' % (name, run), im)
            im.save(os.path.join(out_dir, 'corridor_%s_r%d.png' % (name, run)))
            made['%s_r%d' % (name, run)] = im.copy()
        print('wrote corridor_%s (+ r2, r3)' % name)

    def sheet(names, out):
        im = Image.new('RGBA', (CW, (CH + 4) * len(names)), (0, 0, 0, 255))
        for i, n in enumerate(names):
            im.paste(made[n], (0, (CH + 4) * i))
        im.save(os.path.join(prev_dir, out))
    for f in os.listdir(prev_dir):                         # previews: rebuilt from scratch
        if f.endswith('.png') or f.endswith('.png.import'):
            os.remove(os.path.join(prev_dir, f))
    sheet(['w%da' % l for l in LEVELS], 'corridor_descent.png')          # 29 -> 1, one variant
    for l in LEVELS:
        sheet(['w%d%s' % (l, v) for v in VARIANTS], 'corridor_wear%d_variants.png' % l)
    sheet(['w2b', 'w2b_r2', 'w2b_r3'], 'corridor_runs.png')
    sheet(['hallway', 'lobby'], 'corridor_endpoints.png')


if __name__ == '__main__':
    main()
