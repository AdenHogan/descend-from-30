"""Living room module mockup — 320 x 144 native pixel art.

Run:  python3 tools/art/living_room.py
Out:  assets/rooms/living_room.png  (+ docs/art_reference/modules/living_room_x4.png preview)

Layout follows the module's scavenge anchors (scenes/Room_Modules/living_room.tscn) so each glowing
node sits ON its piece of furniture, keeps both runtime window slots clear, and puts every base on
the floor in front of the wall/floor seam. Flat/neutral lighting — the engine lights the room.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, mix, SEAM_Y, W, H

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

# --- palette (muted, lived-in, slightly tired) --------------------------------
WALL = hexc('6b775e')          # faded sage wallpaper
WALL_STRIPE = hexc('636f57')
WALL_MOTIF = hexc('76836a')
WALL_TOP = hexc('5d684f')      # nicotine/soot darkening near the ceiling
CROWN = hexc('4a5242')
CROWN_HI = hexc('5f6a55')
PLASTER = hexc('b3a88f')
RAIL = hexc('7a5a3e')
RAIL_HI = hexc('8f6c4c')
RAIL_LO = hexc('4d3726')
WAINS = hexc('5c4230')
WAINS_LINE = hexc('47321f')
WAINS_HI = hexc('6a4c37')
SKIRT = hexc('3f2c1e')
SKIRT_HI = hexc('58402e')
SEAM = hexc('2c1f17')
PLANK = [hexc('6f4b31'), hexc('775139'), hexc('6a472f'), hexc('73503a')]
PLANK_SEAM = hexc('4a321f')
PLANK_HI = hexc('82603f')
OUT = hexc('2a1c14')           # general dark outline (never pure black)

RUG = hexc('6c302c')
RUG_DK = hexc('4f2320')
RUG_PAT = hexc('87493a')
RUG_BORDER = hexc('9c7b4c')
RUG_FRINGE = hexc('c4b595')

SHELF = hexc('4b3021')
SHELF_HI = hexc('5f3e2b')
SHELF_BACK = hexc('2f2119')
BOOKS = [hexc(h) for h in ('8a3a2e', '3e5969', 'b0894d', '4e6a3a', '6a4a68', 'c7b797', '94603a', '5a6f80', '7d7c42')]

SOFA = hexc('a3843f')
SOFA_DK = hexc('84692f')
SOFA_LT = hexc('b6974f')
SOFA_OUT = hexc('4c3b1b')
STUFF = hexc('d8cfbb')
THROW = hexc('5a6e79')
THROW_DK = hexc('46575f')

CHAIR = hexc('4f6f6b')
CHAIR_DK = hexc('3e5855')
CHAIR_LT = hexc('61817c')
CHAIR_OUT = hexc('24302e')

TABLE_TOP = hexc('7b5537')
TABLE_EDGE = hexc('5e3f28')
TABLE_LEG = hexc('3f2a1b')

BOX = hexc('9a7a4e')
BOX_DK = hexc('7c6140')
BOX_TAPE = hexc('c0a676')

LAMP_SHADE = hexc('c4b088')
LAMP_SHADE_DK = hexc('a8946d')
LAMP_POLE = hexc('3d3a35')

POT = hexc('985a3c')
POT_DK = hexc('77432b')
LEAF_DEAD = [hexc('6d6a3b'), hexc('85703d'), hexc('5b5530')]

FRAME = hexc('6b4a2c')
FRAME_DK = hexc('3b2718')
PAINT_SKY = hexc('8ea0a3')
PAINT_HILL = hexc('687a58')
PAINT_HILL2 = hexc('556647')
PAINT_SUN = hexc('c9b37c')

CLOCK_FACE = hexc('d6cdb6')
STAIN = hexc('8d7d55', 70)
BLOOD = hexc('4a1d1b', 150)


def wall(c):
    # wallpaper field
    c.rect(0, 0, W - 1, 71, WALL)
    for x in range(0, W, 16):                      # soft vertical stripes
        c.rect(x + 7, 6, x + 8, 71, WALL_STRIPE)
    for y in range(12, 70, 12):                    # tiny diamond motif, staggered
        off = 0 if (y // 12) % 2 == 0 else 8
        for x in range(off + 3, W, 16):
            c.put(x, y, WALL_MOTIF)
            c.put(x - 1, y + 1, WALL_MOTIF)
            c.put(x + 1, y + 1, WALL_MOTIF)
            c.put(x, y + 2, WALL_MOTIF)
    # age: darker toward the ceiling (dithered, not a gradient)
    c.rect(0, 6, W - 1, 9, WALL_TOP)
    c.dither(0, 10, W - 1, 15, WALL_TOP, 0.5)
    # crown moulding
    c.rect(0, 0, W - 1, 4, CROWN)
    c.hline(0, W - 1, 4, CROWN_HI)
    c.hline(0, W - 1, 5, shade(CROWN, 0.8))
    # chair rail + wainscot
    c.rect(0, 70, W - 1, 72, RAIL)
    c.hline(0, W - 1, 70, RAIL_HI)
    c.hline(0, W - 1, 73, RAIL_LO)
    c.rect(0, 74, W - 1, 93, WAINS)
    for x0 in range(4, W, 40):                     # raised panels
        c.box(x0, 77, x0 + 33, 90, WAINS, WAINS_LINE)
        c.hline(x0 + 1, x0 + 32, 78, WAINS_HI)
        c.vline(x0 + 1, 78, 89, WAINS_HI)
    # skirting + seam
    c.rect(0, 94, W - 1, 99, SKIRT)
    c.hline(0, W - 1, 94, SKIRT_HI)
    c.hline(0, W - 1, SEAM_Y, SEAM)


def floor(c):
    # planks, rows getting taller toward the viewer (a gentle perspective)
    rows = [101, 104, 108, 113, 119, 126, 134, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        col = PLANK[r % len(PLANK)]
        c.rect(0, y0, W - 1, y1, col)
        c.hline(0, W - 1, y0, PLANK_HI if r > 0 else shade(col, 0.85))
        c.hline(0, W - 1, y1, PLANK_SEAM)
        # staggered butt joints
        run = 22 + (y1 - y0) * 9
        x = (r * 37) % run
        while x < W:
            c.vline(x, y0 + 1, y1, PLANK_SEAM)
            x += run + (r * 13 + x) % 17
        # a little grain
        for k in range(W // 9):
            gx = c.rng.randrange(W)
            gy = c.rng.randrange(y0 + 1, max(y0 + 2, y1))
            c.hline(gx, gx + c.rng.randrange(3, 8), gy, shade(col, 0.9))


def rug(c):
    top, bot = 113, 138
    pts = [(84, top), (252, top), (266, bot), (70, bot)]
    c.poly(pts, RUG_BORDER)
    inner = [(88, top + 2), (248, top + 2), (261, bot - 2), (75, bot - 2)]
    c.poly(inner, RUG)
    field = [(93, top + 5), (243, top + 5), (254, bot - 5), (82, bot - 5)]
    c.poly(field, RUG_DK)
    c.poly([(97, top + 7), (239, top + 7), (249, bot - 7), (87, bot - 7)], RUG)
    # medallions
    for cx in (118, 168, 218):
        cy = 125
        for d in range(0, 5):
            c.hline(cx - d, cx + d, cy - 4 + d, RUG_PAT)
            c.hline(cx - d, cx + d, cy + 4 - d, RUG_PAT)
        c.put(cx, cy, RUG_BORDER)
    # fringe along the front edge
    for x in range(71, 266, 2):
        c.vline(x, bot + 1, bot + 2, RUG_FRINGE)
    # a worn, stained patch
    c.dither(120, 128, 140, 133, shade(RUG, 0.7), 0.5)


def bookshelf(c):
    x0, x1, top = 12, 48, 50
    c.shadow(30, 101, 21, 3, 90)
    c.box(x0, top, x1, SEAM_Y, SHELF, OUT)
    c.rect(x0 + 3, top + 3, x1 - 3, SEAM_Y - 4, SHELF_BACK)
    c.vline(x0 + 1, top + 1, SEAM_Y - 1, SHELF_HI)
    shelves = [64, 78, 92]
    for sy in shelves:
        c.rect(x0 + 1, sy, x1 - 1, sy + 1, SHELF)
        c.hline(x0 + 2, x1 - 2, sy, SHELF_HI)
    # books per compartment (bottom of each compartment = the shelf line)
    comps = [(top + 3, 63), (66, 77), (80, 91)]
    for ci, (cy0, cy1) in enumerate(comps):
        x = x0 + 4
        k = ci * 3
        while x < x1 - 4:
            bw = 2 + (k * 7 + ci) % 3
            bh = (cy1 - cy0) - 1 - (k * 5 + ci) % 4
            if ci == 2 and 30 <= x <= 40:           # a gap: something was taken (the scavenge node)
                x += 3
                k += 1
                continue
            col = BOOKS[(k * 4 + ci * 3) % len(BOOKS)]
            c.rect(x, cy1 - bh, min(x + bw - 1, x1 - 4), cy1, col)
            c.vline(x, cy1 - bh, cy1, shade(col, 0.75))
            if bh > 6:
                c.hline(x, min(x + bw - 1, x1 - 4), cy1 - bh + 2, shade(col, 1.15))
            x += bw + (1 if k % 4 == 3 else 0)
            k += 1
        if ci == 1:                                  # a leaning book at the end of the row
            col = BOOKS[5]
            c.line(x1 - 8, cy1, x1 - 5, cy0 + 2, col)
            c.line(x1 - 7, cy1, x1 - 4, cy0 + 2, col)
    # on top: a small framed photo + a trailing pot
    c.box(17, top - 7, 25, top - 1, FRAME, FRAME_DK)
    c.rect(19, top - 5, 23, top - 3, PAINT_SKY)
    c.box(36, top - 5, 43, top - 1, POT, POT_DK)
    for i, dx in enumerate((-2, 0, 2, 4)):
        c.vline(39 + dx, top - 9 + i % 2, top - 5, LEAF_DEAD[i % 3])
    c.line(44, top - 2, 47, top + 8, LEAF_DEAD[0])


def floor_box(c):
    # the lower scavenge node (36,118): a half-packed box + spilled books in front of the shelf
    c.shadow(36, 125, 14, 2, 80)
    c.box(26, 110, 45, 124, BOX, OUT)
    c.rect(27, 111, 31, 123, BOX_DK)                 # left face in shade
    c.hline(26, 45, 116, BOX_TAPE)
    c.poly([(26, 110), (30, 104), (34, 110)], BOX_DK)   # open flaps
    c.poly([(40, 110), (46, 105), (45, 110)], BOX)
    c.rect(48, 121, 56, 123, BOOKS[1])                # spilled books
    c.hline(48, 56, 121, shade(BOOKS[1], 1.15))
    c.rect(18, 122, 24, 124, BOOKS[0])


def picture(c):
    x0, y0, x1, y1 = 104, 26, 154, 54
    c.box(x0, y0, x1, y1, FRAME, FRAME_DK)
    c.box(x0 + 2, y0 + 2, x1 - 2, y1 - 2, FRAME_DK)
    c.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, PAINT_SKY)
    c.ellipse(136, 34, 3, 3, PAINT_SUN)
    c.poly([(x0 + 3, 46), (118, 38), (134, 44), (x1 - 3, 40), (x1 - 3, y1 - 3), (x0 + 3, y1 - 3)], PAINT_HILL)
    c.poly([(x0 + 3, 50), (124, 45), (x1 - 3, 49), (x1 - 3, y1 - 3), (x0 + 3, y1 - 3)], PAINT_HILL2)
    c.line(146, y0 + 3, 150, y0 + 11, shade(PAINT_SKY, 0.8))   # cracked glass
    c.line(150, y0 + 11, 148, y0 + 16, shade(PAINT_SKY, 0.8))
    # the wire it hangs from
    c.line(x0 + 10, y0, 129, 18, FRAME_DK)
    c.line(x1 - 10, y0, 129, 18, FRAME_DK)
    c.put(129, 17, OUT)


def clock(c):
    cx, cy = 190, 40
    c.ellipse(cx, cy, 7, 7, OUT)
    c.ellipse(cx, cy, 6, 6, FRAME)
    c.ellipse(cx, cy, 5, 5, CLOCK_FACE)
    for a, b in ((0, -4), (4, 0), (0, 4), (-4, 0)):
        c.put(cx + a, cy + b, shade(CLOCK_FACE, 0.6))
    c.vline(cx, cy - 3, cy, OUT)                       # stopped at a quarter past something
    c.hline(cx, cx + 2, cy, OUT)


def decay(c):
    # a tide-line water stain spreading from the ceiling corner: a pale bloom with a darker rim
    for (sx, sy, rx, ry) in ((298, 10, 17, 11), (284, 20, 9, 6)):
        c.ellipse(sx, sy, rx, ry, hexc('7f7a55', 55))
    for (sx, sy, rx, ry) in ((298, 10, 17, 11), (284, 20, 9, 6)):
        for y in range(int(sy - ry), int(sy + ry) + 1):
            for x in range(int(sx - rx), int(sx + rx) + 1):
                d = ((x - sx) / rx) ** 2 + ((y - sy) / ry) ** 2
                if 0.8 <= d <= 1.0 and y > 5:
                    c.put(x, y, hexc('5e5838', 110))
    # peeling wallpaper by the sofa: a strip lifting off the plaster, curling down
    c.poly([(161, 50), (167, 50), (168, 66), (164, 70), (160, 64)], PLASTER)
    c.vline(160, 51, 63, shade(PLASTER, 0.8))
    c.dither(161, 52, 166, 66, shade(PLASTER, 0.92), 0.3, 'random')
    c.poly([(167, 50), (171, 52), (173, 60), (170, 66), (168, 64)], shade(WALL, 0.8))   # the flap's underside
    c.line(167, 50, 170, 66, shade(WALL, 0.62))
    c.line(171, 52, 173, 60, WALL_MOTIF)
    # something dragged along the wainscot low on the right (old, dark)
    for x in range(232, 252):
        y = 86 + (x - 232) // 6
        c.put(x, y, BLOOD)
        if x % 3:
            c.put(x, y + 1, BLOOD)
    # the floor darkens right at the wall (contact shade under the skirting — ambient, not a light)
    c.dither(0, 101, W - 1, 102, hexc('2c1f17', 90), 0.5)


def lamp(c):
    c.shadow(303, 125, 7, 2, 90)
    c.poly([(299, 56), (307, 56), (311, 68), (295, 68)], LAMP_SHADE)
    c.vline(295, 67, 68, LAMP_SHADE_DK)
    c.hline(295, 311, 68, LAMP_SHADE_DK)
    c.line(299, 56, 295, 68, LAMP_SHADE_DK)
    c.line(307, 56, 311, 68, LAMP_SHADE_DK)
    c.vline(303, 69, 123, LAMP_POLE)
    c.ellipse(303, 124, 5, 1, LAMP_POLE)


def plant(c):
    c.shadow(183, 121, 8, 2, 80)
    c.poly([(177, 108), (189, 108), (187, 120), (179, 120)], POT)
    c.hline(176, 190, 107, POT_DK)
    c.hline(176, 190, 108, shade(POT, 1.12))
    c.vline(178, 109, 119, POT_DK)
    # a dried-out fern: drooping fronds with little leaflets
    fronds = [((183, 106), (172, 99), (170, 108)), ((183, 106), (178, 92), (176, 96)),
              ((183, 106), (185, 90), (188, 92)), ((183, 106), (192, 96), (196, 104)),
              ((183, 106), (189, 100), (194, 108))]
    for i, (a, mid, tip) in enumerate(fronds):
        col = LEAF_DEAD[i % 3]
        c.line(a[0], a[1], mid[0], mid[1], col)
        c.line(mid[0], mid[1], tip[0], tip[1], col)
        for t in (0.35, 0.65):
            lx = int(a[0] + (mid[0] - a[0]) * t)
            ly = int(a[1] + (mid[1] - a[1]) * t)
            c.put(lx - 1, ly, shade(col, 1.1))
            c.put(lx + 1, ly - 1, shade(col, 0.85))
    c.rect(189, 121, 191, 121, LEAF_DEAD[1])          # fallen leaves
    c.put(171, 122, LEAF_DEAD[0])


def sofa(c):
    x0, x1, base = 86, 172, 124
    c.shadow(129, base + 1, 46, 3, 110)
    # back
    c.rect(x0 + 6, 90, x1 - 6, 108, SOFA)
    c.hline(x0 + 7, x1 - 7, 89, SOFA_OUT)
    c.hline(x0 + 7, x1 - 7, 90, SOFA_LT)
    for bx in (x0 + 6 + 27, x0 + 6 + 54):             # back-cushion splits
        c.vline(bx, 92, 107, SOFA_DK)
    c.rect(x0 + 6, 104, x1 - 6, 108, SOFA_DK)          # shade where the back meets the seat
    # seat cushions (the nodes sit on them: 107,114 and 151,114)
    c.rect(x0 + 8, 108, x1 - 8, 116, SOFA_LT)
    c.hline(x0 + 8, x1 - 8, 108, shade(SOFA_LT, 1.08))
    c.vline(129, 109, 116, SOFA_DK)
    c.hline(x0 + 8, x1 - 8, 116, SOFA_DK)
    # front skirt + legs
    c.rect(x0 + 4, 117, x1 - 4, 122, SOFA)
    c.hline(x0 + 4, x1 - 4, 122, SOFA_DK)
    for lx in (x0 + 6, x1 - 7):
        c.rect(lx, 123, lx + 1, base, OUT)
    # arms
    for ax0 in (x0, x1 - 9):
        c.rect(ax0, 98, ax0 + 9, 122, SOFA)
        c.hline(ax0 + 1, ax0 + 8, 97, SOFA_OUT)
        c.hline(ax0 + 1, ax0 + 8, 98, SOFA_LT)
        c.vline(ax0, 98, 122, SOFA_OUT)
        c.vline(ax0 + 9, 98, 122, SOFA_OUT)
        c.rect(ax0 + 1, 118, ax0 + 8, 122, SOFA_DK)
    c.vline(x0 + 6, 90, 97, SOFA_OUT)
    c.vline(x1 - 6, 90, 97, SOFA_OUT)
    c.hline(x0, x1, 123, SOFA_OUT)
    # a slashed cushion, stuffing spilling
    c.line(140, 110, 147, 113, OUT)
    c.put(142, 110, STUFF); c.put(144, 111, STUFF); c.put(143, 112, STUFF); c.put(146, 112, STUFF)
    c.put(145, 110, STUFF)
    # a throw slung over the back, spilling onto the left cushion
    c.poly([(100, 89), (116, 88), (118, 104), (114, 114), (104, 115), (100, 108)], THROW)
    c.line(100, 89, 100, 108, THROW_DK)
    for y in range(93, 113, 4):
        c.hline(102, 115, y, THROW_DK)
    c.put(104, 116, THROW_DK); c.put(108, 116, THROW_DK); c.put(112, 115, THROW_DK)   # tassels


def armchair(c):
    x0, x1, base = 252, 290, 124
    c.shadow(271, base + 1, 21, 3, 110)
    c.rect(x0 + 5, 94, x1 - 5, 110, CHAIR)
    c.hline(x0 + 6, x1 - 6, 93, CHAIR_OUT)
    c.hline(x0 + 6, x1 - 6, 94, CHAIR_LT)
    c.rect(x0 + 5, 106, x1 - 5, 110, CHAIR_DK)
    c.rect(x0 + 7, 110, x1 - 7, 117, CHAIR_LT)          # seat (node 270,116)
    c.hline(x0 + 7, x1 - 7, 117, CHAIR_DK)
    c.rect(x0 + 4, 118, x1 - 4, 122, CHAIR)
    c.hline(x0 + 4, x1 - 4, 122, CHAIR_DK)
    for ax0 in (x0, x1 - 7):
        c.rect(ax0, 101, ax0 + 7, 122, CHAIR)
        c.hline(ax0 + 1, ax0 + 6, 100, CHAIR_OUT)
        c.hline(ax0 + 1, ax0 + 6, 101, CHAIR_LT)
        c.vline(ax0, 101, 122, CHAIR_OUT)
        c.vline(ax0 + 7, 101, 122, CHAIR_OUT)
    c.vline(x0 + 5, 94, 100, CHAIR_OUT)
    c.vline(x1 - 5, 94, 100, CHAIR_OUT)
    c.hline(x0, x1, 123, CHAIR_OUT)
    for lx in (x0 + 3, x1 - 4):
        c.rect(lx, 123, lx + 1, base, OUT)
    # a split seam on the back
    c.line(262, 97, 266, 101, CHAIR_DK)


def coffee_table(c):
    x0, x1 = 194, 242
    c.shadow(218, 128, 26, 2, 100)
    c.poly([(x0 + 3, 116), (x1 - 3, 116), (x1, 120), (x0, 120)], TABLE_TOP)   # top (node 218,122)
    c.hline(x0 + 3, x1 - 3, 116, shade(TABLE_TOP, 1.1))
    c.rect(x0, 121, x1, 123, TABLE_EDGE)
    for lx in (x0 + 2, x1 - 3):
        c.rect(lx, 124, lx + 1, 127, TABLE_LEG)
    # on the table: a mug, a couple of magazines, an ashtray
    c.rect(203, 112, 207, 117, CLOCK_FACE)
    c.vline(203, 112, 117, shade(CLOCK_FACE, 0.8))
    c.put(208, 113, CLOCK_FACE); c.put(208, 115, CLOCK_FACE); c.put(209, 114, CLOCK_FACE)
    c.rect(222, 117, 234, 118, hexc('7f8f98'))
    c.rect(224, 116, 236, 117, hexc('b7584a'))
    c.ellipse(214, 118, 3, 1, hexc('6c6a66'))


def build():
    c = Canvas(seed=7)
    wall(c)
    decay(c)
    picture(c)
    clock(c)
    floor(c)
    rug(c)
    bookshelf(c)
    lamp(c)
    plant(c)
    sofa(c)
    armchair(c)
    coffee_table(c)
    floor_box(c)
    return c


if __name__ == '__main__':
    out = os.path.join(ROOT, 'assets', 'rooms', 'living_room.png')
    prev_dir = os.path.join(ROOT, 'docs', 'art_reference', 'modules')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    os.makedirs(prev_dir, exist_ok=True)
    c = build()
    c.save(out, os.path.join(prev_dir, 'living_room_x4.png'))
    print('wrote', out)
