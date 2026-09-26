"""Kitchen module — 320 x 144 native pixel art, in the living room's style.

Run:  python3 tools/art/kitchen.py
Out:  assets/rooms/kitchen.png  (+ docs/art_reference/modules/kitchen_x4.png preview)

Layout (left -> right): an old rounded fridge (node: its door), a counter run along the back wall
with wall cupboards above (nodes: a wall cupboard, the cupboard under the counter), the cooker with a
pot on the hob (node: the oven), the sink with the cupboard under it (nodes: the sink, the cupboard),
and a pedal bin out on the floor by the walking lane (node). Everything but the bin stands against
the back wall — the step-up plane. The runtime window boxes stay bare wall (nothing taller than the
counter top inside them). The lino repeats every 32px so the floor carries on past the module edge
at a doorway (scripts/module_walls.gd FLOOR_STRIP).
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import persp
from pixlib import Canvas, hexc, shade, mix, SEAM_Y, W, H, check_window_boxes, check_edge_columns, save_floor_strip, floor_is_periodic, finish_module, rrect

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

# --- palette (greasy, sun-faded, 1970s) --------------------------------------------------------
PAINT = hexc('a39a6b')         # tired yellow-olive paint
PAINT_DK = hexc('948b60')
PAINT_TOP = hexc('8a8259')
CROWN = hexc('6d6647')
CROWN_HI = hexc('857d58')
TILE = hexc('c8c1a8')          # splashback tiles
TILE_DK = hexc('b1aa92')
GROUT = hexc('8f8873')
KICK = hexc('3b3027')
SEAM = hexc('2a1f19')

LINO_A = hexc('9aa08a')        # sage / cream checker lino
LINO_B = hexc('c2bd9f')
LINO_LINE = hexc('7c806c')
OUT = hexc('2a1c17')

CAB = hexc('6f7f73')           # painted cabinets, chipped
CAB_DK = hexc('5b695e')
CAB_LT = hexc('829184')
CAB_OUT = hexc('2e2c27')
CAB_IN = hexc('2c2620')
CHIP = hexc('8b6a4c')
WORKTOP = hexc('8f8a7c')
WORKTOP_LT = hexc('a6a193')
WORKTOP_EDGE = hexc('5e5a50')
HANDLE = hexc('b7b3a6')

FRIDGE = hexc('d2cbb2')
FRIDGE_DK = hexc('b4ad95')
FRIDGE_LT = hexc('e2dcc6')
CHROME = hexc('a9aeb0')
CHROME_DK = hexc('7b8083')

OVEN = hexc('dcd5bf')
OVEN_DK = hexc('b8b19b')
OVEN_GLASS = hexc('2f2a26')
HOB = hexc('2e2c29')
POT = hexc('7a6f63')
POT_DK = hexc('5a5249')

STEEL = hexc('9aa1a3')
STEEL_DK = hexc('737a7c')
WATER = hexc('5f6b62')

BIN = hexc('8a8f8e')
BIN_DK = hexc('6b706f')
GREASE = hexc('5b4a2e', 70)
DAMP = hexc('5e5a3c', 60)
BLOOD = hexc('4a1d1b', 150)


def wall(c):
    c.rect(0, 0, W - 1, 93, PAINT)
    c.rect(0, 6, W - 1, 8, PAINT_TOP)
    c.dither(0, 9, W - 1, 13, PAINT_TOP, 0.5)
    c.rect(0, 0, W - 1, 4, CROWN)
    c.hline(0, W - 1, 4, CROWN_HI)
    c.hline(0, W - 1, 5, shade(CROWN, 0.8))
    # a tiled splashback band behind the counter (part of the wall — it runs behind everything)
    c.rect(0, 50, W - 1, 69, TILE)
    for y in range(50, 70, 7):
        c.hline(0, W - 1, y, GROUT)
    for row, y in enumerate(range(50, 70, 7)):
        off = 0 if row % 2 == 0 else 8
        for x in range(off, W, 16):
            c.vline(x, y, min(y + 6, 69), GROUT)
    c.hline(0, W - 1, 70, GROUT)
    # kick board + seam
    c.rect(0, 94, W - 1, 99, KICK)
    c.hline(0, W - 1, 99, SEAM)


def decay(c):
    c.dither(0, 14, W - 1, 22, DAMP, 0.3, pattern='random')
    for i in range(5):                              # a water stain from the flat above
        c.ellipse(24 + i * 5, 12 + i * 2, 6, 4, DAMP)
    c.put(100, 60, TILE_DK); c.line(100, 60, 104, 66, GROUT)   # a cracked tile


@persp
def floor(c):
    # checker lino: 16px tiles, rows growing toward the viewer; the pattern repeats every 32px.
    rows = [100, 104, 109, 115, 122, 130, 139, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, W, 16):
            col = LINO_A if ((x // 16) + r) % 2 == 0 else LINO_B
            c.rect(x, y0, x + 15, y1, col)
            c.vline(x, y0, y1, LINO_LINE)
        c.hline(0, W - 1, y0, LINO_LINE)
    c.hline(0, W - 1, 100, shade(LINO_A, 0.6))
    c.hline(0, W - 1, 101, shade(LINO_A, 0.8))
    # scuffs + a worn path along the lane (horizontal only — keeps the 32px repeat)
    for y in range(124, 134):
        for x in range(W):
            if (x + 3 * y) % 4 == 0:
                c.put(x, y, shade(c.px[x, y], 0.92))


def fridge(c):
    # left of the L window box (x < 50): a rounded 50s fridge, one door
    x0, x1, top, base = 8, 44, 24, 100
    c.shadow(26, base, 19, 2, 100)
    rrect(c, x0, top, x1, base - 1, OUT, 5)
    rrect(c, x0 + 1, top + 1, x1 - 1, base - 2, FRIDGE, 5)
    c.vline(x0 + 3, top + 6, base - 6, FRIDGE_LT)
    c.vline(x1 - 3, top + 6, base - 6, FRIDGE_DK)
    c.hline(x0 + 2, x1 - 2, top + 30, FRIDGE_DK)       # freezer seam
    c.rect(x1 - 7, top + 34, x1 - 5, top + 48, CHROME)  # handle
    c.vline(x1 - 5, top + 34, top + 48, CHROME_DK)
    c.rect(x0 + 6, base - 6, x1 - 6, base - 3, CHROME_DK)   # vent grille
    # magnets + a note + a child's drawing
    c.rect(14, top + 38, 22, top + 48, hexc('e8e2d0'))
    c.hline(15, 21, top + 41, hexc('8a8577'))
    c.hline(15, 20, top + 44, hexc('8a8577'))
    c.put(18, top + 37, hexc('b0453a'))
    c.rect(24, top + 52, 31, top + 60, hexc('e7dcc0'))
    c.put(26, top + 55, hexc('4e6ea0')); c.put(28, top + 56, hexc('d0a040'))
    c.put(27, top + 51, hexc('3e7a4c'))
    c.ellipse(20, base - 12, 5, 2, BLOOD)                   # a smear low on the door


def counter(c):
    # the counter run along the back wall: x 48..262, worktop at 69..72 (below the window boxes)
    x0, x1 = 48, 262
    c.shadow(155, 100, 108, 2, 90)
    # base cabinets
    c.box(x0, 73, x1, 98, CAB, CAB_OUT)
    for dx0 in range(x0 + 2, x1 - 20, 22):
        if 150 <= dx0 <= 186:                               # the cooker sits here
            continue
        c.box(dx0, 75, dx0 + 19, 96, CAB, CAB_DK)
        c.hline(dx0 + 1, dx0 + 18, 76, CAB_LT)
        c.rect(dx0 + 16, 83, dx0 + 16, 88, HANDLE)
    # one door hanging open (the centre cupboard node): the dark inside + a tin
    c.rect(110, 75, 129, 96, CAB_IN)
    c.hline(110, 129, 85, shade(CAB_IN, 1.4))
    c.rect(114, 80, 118, 84, hexc('9c4a3a'))
    c.poly([(110, 75), (104, 77), (104, 95), (110, 96)], CAB_LT)    # the door, swung
    # chips in the paint
    for (px, py) in ((60, 90), (88, 78), (140, 92), (236, 80)):
        c.put(px, py, CHIP); c.put(px + 1, py, CHIP)
    # worktop
    c.rect(x0 - 2, 69, x1 + 2, 72, WORKTOP)
    c.hline(x0 - 2, x1 + 2, 69, WORKTOP_LT)
    c.hline(x0 - 2, x1 + 2, 72, WORKTOP_EDGE)
    c.rect(x0, 94, x1, 98, KICK)
    c.hline(x0, x1, 94, shade(KICK, 1.3))


def wall_cupboards(c):
    # between the two window boxes (x 98..222), above the splashback
    x0, x1, top, bot = 98, 222, 16, 48
    c.box(x0, top, x1, bot, CAB, CAB_OUT)
    c.hline(x0, x1, bot, shade(CAB, 0.7))
    doors = [(x0 + 2, x0 + 40), (x0 + 42, x0 + 80), (x0 + 82, x1 - 2)]
    for i, (a, b) in enumerate(doors):
        if i == 0:
            # the left door hangs open (the left cupboard node): shelves, a jar, a box of cereal
            c.rect(a, top + 2, b, bot - 2, CAB_IN)
            c.hline(a, b, top + 16, shade(CAB_IN, 1.5))
            c.rect(a + 4, top + 8, a + 9, top + 15, hexc('b7a36e'))
            c.rect(a + 12, top + 10, a + 16, top + 15, hexc('8a9aa0'))
            c.rect(a + 22, top + 20, a + 30, top + 29, hexc('c05a3a'))
            c.poly([(a, top + 2), (a - 3, top + 4), (a - 3, bot - 3), (a, bot - 2)], CAB_LT)
        else:
            c.box(a, top + 2, b, bot - 2, CAB, CAB_DK)
            c.hline(a + 1, b - 1, top + 3, CAB_LT)
            c.rect(a + 3, bot - 8, a + 3, bot - 5, HANDLE)
    c.put(150, 30, CHIP); c.put(151, 30, CHIP)


def cooker(c):
    # an enamel cooker in the counter run (x 152..188), a pot on the hob, grease above
    x0, x1 = 152, 188
    c.box(x0, 70, x1, 98, OVEN, OUT)
    c.rect(x0 + 1, 70, x1 - 1, 72, HOB)                          # hob
    for bx in (x0 + 7, x1 - 9):
        c.hline(bx - 3, bx + 3, 71, hexc('4a4640'))
    c.rect(x0 + 3, 74, x1 - 3, 76, OVEN_DK)                      # knob panel
    for kx in range(x0 + 6, x1 - 4, 6):
        c.put(kx, 75, OUT)
    c.box(x0 + 4, 79, x1 - 4, 94, OVEN, OVEN_DK)                 # oven door (the node)
    c.rect(x0 + 8, 82, x1 - 8, 89, OVEN_GLASS)
    c.hline(x0 + 8, x1 - 8, 82, hexc('4a423c'))
    c.rect(x0 + 8, 80, x1 - 8, 80, CHROME)                        # handle
    # the pot (stays between the window boxes — they're only 50..94 and 226..270)
    c.rect(x0 + 18, 61, x0 + 30, 69, POT)
    c.hline(x0 + 17, x0 + 31, 61, POT_DK)
    c.hline(x0 + 19, x0 + 29, 60, hexc('8b8074'))
    c.rect(x0 + 14, 63, x0 + 17, 64, POT_DK)                      # handle


def grease(c):
    for i in range(5):                                           # grease up the tiles over the hob
        c.ellipse(170 + (i % 2) * 3, 58 - i * 4, 7 - i, 3, GREASE)


def sink(c):
    # a steel sink + drainer in the worktop (x 192..224) with the tap rising behind (x < 226)
    c.rect(192, 69, 224, 72, STEEL)
    c.hline(192, 224, 69, hexc('b9bfc1'))
    c.rect(196, 70, 212, 71, WATER)                               # the basin, dirty water
    for x in range(214, 224, 2):
        c.vline(x, 69, 70, STEEL_DK)                               # drainer grooves
    c.rect(203, 58, 204, 68, STEEL_DK)                             # tap
    c.rect(203, 58, 209, 59, STEEL_DK)
    c.put(209, 60, STEEL)
    # dishes stacked on the drainer
    c.rect(214, 64, 222, 68, hexc('d8d2c2'))
    c.hline(214, 222, 66, hexc('b8b1a0'))
    c.rect(216, 62, 220, 63, hexc('d8d2c2'))
    # the cupboard under the sink: doors, one ajar with a bucket inside (the sink cupboard node)
    c.rect(196, 75, 220, 96, CAB_IN)
    c.box(196, 75, 207, 96, CAB, CAB_DK)
    c.rect(210, 84, 218, 95, hexc('4f6f8a'))                       # a bucket
    c.hline(210, 218, 84, hexc('6a8aa4'))


def counter_end(c):
    # right of the counter (x 264..316), on the wall: a tea towel on a hook, a calendar
    c.rect(282, 30, 284, 32, CHROME_DK)                            # hook (right of the R box)
    c.poly([(279, 33), (288, 33), (289, 58), (278, 58)], hexc('b8594a'))
    for y in range(36, 58, 5):
        c.hline(279, 288, y, hexc('e0cfb8'))
    # a calendar, pages curling
    c.box(296, 24, 314, 48, hexc('e6dfcc'), hexc('9a927e'))
    c.rect(298, 26, 312, 33, hexc('7d8f9a'))
    for y in range(36, 47, 3):
        c.hline(298, 312, y, hexc('b9b09a'))
    c.put(304, 39, hexc('b0453a'))


def bin_bags(c):
    import furn as F
    # rubbish at the end of the counter, against the wall (the trash node): two tied black bin bags,
    # one split with rubbish spilling onto the lino
    F.bin_bag(c, 278, 100, 20, 24, seed=3)
    F.bin_bag(c, 293, 100, 18, 18, split=True, seed=7)
    c.rect(283, 99, 287, 101, hexc('d8d2c2'))                              # paper
    c.put(279, 101, hexc('c7b16a')); c.put(281, 102, hexc('7a8a5a'))
    # a broken plate dropped at the foot of the counter
    c.rect(214, 101, 219, 102, hexc('d8d2c2'))
    c.put(217, 100, hexc('d8d2c2')); c.put(222, 102, hexc('d8d2c2'))


def table(c):
    # a small kitchen table pulled out toward the lane, under the L window (node: its top), a chair
    # tucked behind it; an oilcloth with a red check
    x0, x1, top, base = 54, 100, 94, 121
    c.shadow(77, base, 26, 2, 110)
    # the chair behind: only its back shows over the top
    ch = hexc('6a4a33')
    c.rect(66, 76, 68, 94, ch)
    c.rect(84, 76, 86, 94, ch)
    c.rect(66, 76, 86, 78, shade(ch, 1.15))
    c.rect(69, 83, 83, 84, ch)
    # legs (the far pair set back and darker), apron, the top seen from above
    leg = hexc('5a3d29')
    c.rect(x0 + 5, top + 8, x0 + 6, base - 3, shade(leg, 0.75))
    c.rect(x1 - 6, top + 8, x1 - 5, base - 3, shade(leg, 0.75))
    c.rect(x0 + 2, top + 8, x0 + 4, base, leg)
    c.rect(x1 - 4, top + 8, x1 - 2, base, leg)
    c.rect(x0, top + 5, x1, top + 7, shade(leg, 0.85))
    cloth, check = hexc('d9d2c0'), hexc('b0453a')
    for y in range(top, top + 5):
        for x in range(x0 - 2, x1 + 3):
            on = ((x // 3) + (y // 2)) % 2 == 0
            c.put(x, y, check if on else cloth)
    c.hline(x0 - 2, x1 + 2, top, shade(cloth, 0.9))
    for x in range(x0 - 2, x1 + 3):                     # the cloth's hang over the front edge
        h = top + 5 + (1 if (x // 5) % 3 == 0 else 0)
        c.vline(x, top + 5, h, check if (x // 3) % 2 == 0 else cloth)
    # on it: a teapot, a mug, a tin
    c.rect(64, top - 5, 72, top - 1, hexc('4f6f8a'))
    c.hline(65, 71, top - 6, hexc('4f6f8a'))
    c.put(73, top - 4, hexc('4f6f8a')); c.put(74, top - 5, hexc('4f6f8a'))
    c.put(63, top - 3, hexc('4f6f8a'))
    c.rect(80, top - 4, 83, top - 1, hexc('e6dfcc'))
    c.rect(88, top - 5, 92, top - 1, hexc('b0453a'))
    c.hline(88, 92, top - 3, hexc('d8d2c2'))


def tin_box(c):
    # a cardboard box of tins on the floor against the end of the counter (node: the box)
    x0, x1, top, base = 236, 262, 88, 101
    c.shadow(249, base, 15, 2, 110)
    box, box_dk = hexc('a88a5c'), hexc('7d6440')
    c.box(x0, top, x1, base, box, box_dk)
    c.hline(x0 + 1, x1 - 1, top + 1, shade(box, 1.1))
    c.poly([(x0, top), (x0 - 5, top - 4), (x0 - 4, top - 5), (x0 + 1, top - 1)], box_dk)     # flaps
    c.poly([(x1, top), (x1 + 4, top - 5), (x1 + 5, top - 4), (x1 + 1, top + 1)], box)
    for i, col in enumerate((hexc('b0453a'), hexc('c9b86a'), hexc('6a8a5a'), hexc('b0453a'))):
        tx = x0 + 3 + i * 6
        c.rect(tx, top - 4, tx + 4, top, col)
        c.hline(tx, tx + 4, top - 4, hexc('c9c7bd'))
    c.rect(x0 + 6, top + 5, x1 - 6, top + 8, hexc('d8d2c2'))              # a label, scrawled
    c.hline(x0 + 8, x1 - 9, top + 6, hexc('4a3a2a'))
    c.rect(230, 98, 234, 101, hexc('c9b86a'))                             # a tin rolled off the pile
    c.hline(230, 234, 98, hexc('c9c7bd'))


def _run(c):
    counter(c)
    cooker(c)
    sink(c)


def build(c=None):
    # WITH DEPTH (owner round 14 — set-back pieces "look so flat against the back wall"): the fridge,
    # the counter run (its worktop now reads as a worktop), the wall cupboards; the box of tins and
    # the bin bags come forward with the counter so they still stand in front of it.
    from pixlib import setback
    c = c or Canvas(seed=33)
    wall(c)
    decay(c)
    grease(c)
    floor(c)
    setback(c, lambda l: shifted_x(l, fridge, -3), depth=6, top=24, x_range=(5, 41), rake=1.0)
    setback(c, _run, depth=7, top=69, x_range=(46, 264))
    setback(c, wall_cupboards, depth=4, top=16)
    counter_end(c)
    setback(c, bin_bags, depth=0, forward=7)          # soft sacks: brought forward, never extruded
    table(c)
    setback(c, tin_box, depth=4, forward=7, top=88, x_range=(236, 262))
    import furn as F
    F.tube_light(c, 160)                  # a fluorescent batten above the wall cupboards
    return c


def shifted_x(c, fn, dx):
    from PIL import Image
    lyr = Canvas(bg=(0, 0, 0, 0), seed=11)
    from pixlib import push_light_offset, pop_light_offset
    push_light_offset(dx, 0)
    try:
        fn(lyr)
    finally:
        pop_light_offset()
    moved = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    moved.paste(lyr.img, (dx, 0), lyr.img)
    c.img.alpha_composite(moved)
    c.px = c.img.load()


def bare(c):
    wall(c)
    decay(c)


ANCHORS = [('anchor_centre_fridge', 23, 70, 'bp'), ('anchor_right_trashcan', 283, 88, 'bp'),
           ('anchor_left_cupboard', 118, 40, 'bp'), ('anchor_centre_cupboard', 119, 88, 'bp'),
           ('anchor_centre_oven', 170, 86, 'bp'), ('anchor_right_sink', 204, 70, 'bp'),
           ('anchor_right_sinkcupboard', 214, 90, 'bp'),
           ('anchor_kitchen_table', 84, 95, ''), ('anchor_kitchen_teapot', 68, 91, ''),
           ('anchor_kitchen_tins', 249, 92, 'bp')]


if __name__ == '__main__':
    finish_module('kitchen', 'kitchen', 33, bare, floor, build, ANCHORS)
