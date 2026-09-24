"""Corridor art for floors 1-29 (building_floors) — a painted overlay replacing the old tile look.

Run:  python3 tools/art/corridor.py
Out:  assets/corridor/corridor_<section>.png (+ _r2 / _r3 run looks), previews in
      docs/art_reference/corridor/.

One 1120 x 192 image covers the corridor band exactly (world x 115..1235, y 243..435 — the
tilemap's used rect; building_floors._apply_corridor_art puts it just above the TileMapLayer, so
doors, stairs, the elevator, lamps, fire and actors all still draw over it). Rows (local y):
  0..15    ceiling + cornice          (tile row 20)
  16..95   wall                       (rows 21-25)
  96..159  dado rail + wainscot + skirting (rows 26-29)
  160..191 floor, feet line at 176 (world 419)  (rows 30-31)
The two stairwell recesses (local x 16..111 and 1008..1103) get a dim stairwell wall + a framed
opening; the staircase sprites draw over them.

SECTIONAL IDENTITY (docs/ART_REQUIREMENTS.md): the building reads differently as you descend —
  high (21-29) a faded HOTEL-like hallway: teal damask, mahogany panels, a red runner;
  mid  (11-20) tired RESIDENTIAL: mustard stripes, cream tongue-and-groove, brown carpet;
  low  (1-10)  INSTITUTIONAL: two-tone gloss paint, a painted line, pipes, checker lino.
Each also has run 2 / run 3 looks (damp, cracks, peeling, holes, mould, blood, debris).
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


# --- the three sections ----------------------------------------------------------------------
def high(c, wall=None, motif=None):
    """Upper floors: a faded hotel-like hallway."""
    wall = wall or hexc('3f5a5a')
    motif = motif or hexc('7a8a6a')
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
    runner(c, hexc('7a2424'), hexc('b58f4a'), hexc('a8483a'))
    recesses(c, wall)
    pilasters(c, hexc('5e3828'), hexc('7a4a34'), hexc('2a1810'))
    for i, x in enumerate(LAYOUT['spots']):
        if i % 2 == 0:
            frame(c, x, 34, 28, 22, hexc('b58f4a'), [hexc('6a7a5a'), hexc('5a4a3e')][i // 2])
            c.poly([(x - 12, 51), (x - 4, 44), (x + 4, 48), (x + 12, 42), (x + 12, 53), (x - 12, 53)], hexc('4a5a3a'))
        else:
            frame(c, x, 36, 18, 22, hexc('b58f4a'), hexc('5a4a3e'))
            c.ellipse(x, 44, 3, 4, hexc('c8b39a'))
    c.box(860, 40, 872, 50, hexc('2e5a3a'), hexc('1a3020'))                    # a green EXIT sign
    c.rect(862, 43, 870, 46, hexc('d8e8c8'))


def mid(c):
    """Middle floors: tired residential."""
    wall = hexc('b39a5a')
    ceiling(c, hexc('c9bda0'), hexc('d6cbb0'), hexc('e6dcc2'))
    c.rect(0, WALL_TOP, CW - 1, RAIL_Y - 1, wall)
    for x in range(0, CW, 8):                                                  # stripes
        c.vline(x + 2, WALL_TOP, RAIL_Y - 1, hexc('a38a4e'))
        c.vline(x + 3, WALL_TOP, RAIL_Y - 1, hexc('a38a4e'))
        c.vline(x + 6, WALL_TOP, RAIL_Y - 1, hexc('bca562'))
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
    runner(c, hexc('6a5040'), hexc('4a3428'), hexc('8a6a54'))
    recesses(c, wall)
    pilasters(c, hexc('d6cbb0'), hexc('ece4cc'), hexc('7a6a50'))
    for i, x in enumerate(LAYOUT['spots']):
        if i % 2 == 0:
            frame(c, x, 36, 24, 18, hexc('6b4a2c'), hexc('9c9282'))
        else:
            c.box(x - 12, 30, x + 12, 56, hexc('9a7650'), hexc('3b2718'))         # a residents' board
            c.rect(x - 9, 33, x - 1, 42, hexc('e6dfcc')); c.rect(x + 1, 35, x + 9, 46, hexc('d9c24a'))
            c.rect(x - 8, 45, x, 53, hexc('e6dfcc'))
    c.box(860, 40, 872, 50, hexc('2e5a3a'), hexc('1a3020'))
    c.rect(862, 43, 870, 46, hexc('d8e8c8'))


def low(c):
    """Lower floors: institutional two-tone gloss paint, pipes, checker lino."""
    upper, lower = hexc('a9b8a0'), hexc('3e5a48')
    ceiling(c, hexc('b9bdb0'), hexc('c9ccc0'), hexc('dcdfd4'))
    c.rect(0, WALL_TOP, CW - 1, RAIL_Y - 1, upper)
    c.dither(0, WALL_TOP, CW - 1, RAIL_Y - 1, hexc('b2c0aa'), 0.08, pattern='random')
    c.rect(0, 18, CW - 1, 21, hexc('7a8480'))                                   # a pipe run along the top
    c.hline(0, CW - 1, 18, hexc('9aa3a0'))
    c.hline(0, CW - 1, 21, hexc('4a524e'))
    for x in range(40, CW, 96):
        c.rect(x, 17, x + 3, 22, hexc('5a625e'))                                # brackets
    c.rect(0, 24, CW - 1, 25, hexc('6a7270'))                                   # a thin conduit
    c.rect(0, RAIL_Y, CW - 1, RAIL_Y + 2, hexc('26302a'))                       # the painted line
    c.rect(0, RAIL_Y + 3, CW - 1, SKIRT_Y - 1, lower)
    c.dither(0, RAIL_Y + 3, CW - 1, RAIL_Y + 6, hexc('4e6a58'), 0.5)
    c.rect(0, SKIRT_Y, CW - 1, FLOOR_Y - 1, hexc('26302a'))
    rows = [160, 165, 171, 178, 186, 192]                                       # checker lino
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, CW, 16):
            c.rect(x, y0, x + 15, y1, hexc('8a8a78') if ((x // 16) + r) % 2 else hexc('5a5e52'))
    c.hline(0, CW - 1, FLOOR_Y, hexc('3a3e36'))
    recesses(c, upper)
    pilasters(c, hexc('7a8480'), hexc('9aa3a0'), hexc('3a403e'))
    for i, x in enumerate(LAYOUT['spots']):                                               # notices, a fire-drill card
        if i % 2 == 0:
            c.box(x - 9, 36, x + 9, 58, hexc('e6e2d6'), hexc('6a6a66'))
            c.rect(x - 7, 38, x + 7, 42, hexc('a8322c'))
            for y in range(45, 57, 3):
                c.hline(x - 6, x + 6, y, hexc('8a8a86'))
        else:
            c.box(x - 6, 40, x + 6, 52, hexc('a8322c'), hexc('5a1a16'))          # an alarm call point
            c.rect(x - 3, 43, x + 3, 49, hexc('e6e2d6'))
    c.box(860, 40, 872, 50, hexc('2e5a3a'), hexc('1a3020'))
    c.rect(862, 43, 870, 46, hexc('d8e8c8'))


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


SECTIONS = {'high': (high, 71), 'mid': (mid, 72), 'low': (low, 73)}
# the endpoint floors: floor 30 (hallway — the upper look, only the LEFT stair, and no pictures:
# the tutorial's wall hints live between its doors) and the lobby (0 — only the RIGHT stair).
def hallway(c):
    # floor 30: the same hotel hallway in a PALE cream damask, so the tutorial's blood-red wall
    # hints read clearly (red on the dark teal was hard to read)
    high(c, wall=hexc('cdbf9c'), motif=hexc('b9a882'))


SCENES = {'hallway': (hallway, 74, {'recess': (0,), 'spots': []}),
          'lobby': (lobby, 75, {'recess': (1,), 'spots': []})}


def main():
    from PIL import Image
    out_dir = os.path.join(ROOT, 'assets', 'corridor')
    prev_dir = os.path.join(ROOT, 'docs', 'art_reference', 'corridor')
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(prev_dir, exist_ok=True)
    rows = []
    jobs = [(n, fn, seed, {'recess': (0, 1), 'spots': SPOTS}) for n, (fn, seed) in SECTIONS.items()]
    jobs += [(n, fn, seed, lay) for n, (fn, seed, lay) in SCENES.items()]
    for name, fn, seed, lay in jobs:
        LAYOUT.clear()
        LAYOUT.update(lay)
        c = Canvas(w=CW, h=CH, seed=seed)
        fn(c)
        holes = [(x, y) for y in range(CH) for x in range(CW) if c.img.getpixel((x, y))[3] != 255]
        if holes:
            sys.exit('%s: transparent pixels %s' % (name, holes[:5]))
        c.img.save(os.path.join(out_dir, 'corridor_%s.png' % name))
        rows.append(c.img.copy())
        for level in (2, 3):
            im = ruin(c.img.copy(), level, seed)
            im.save(os.path.join(out_dir, 'corridor_%s_r%d.png' % (name, level)))
            rows.append(im)
        print('wrote corridor_%s (+ r2, r3)' % name)
    sheet = Image.new('RGBA', (CW, CH * len(rows)), (0, 0, 0, 255))
    for i, im in enumerate(rows):
        sheet.paste(im, (0, CH * i))
    sheet.save(os.path.join(prev_dir, 'corridor_sections.png'))


if __name__ == '__main__':
    main()
