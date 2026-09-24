"""Kitchen VARIANTS b-d (variant a is tools/art/kitchen.py). Same rules via pixlib.finish_module.

Run:  python3 tools/art/kitchen_variants.py [b c d]

  b  60s galley — yellow units + a cooker along the left, a formica dinette table with chrome
     chairs out in the middle of the room, a tall larder cupboard on the right.
  c  farmhouse — a pine dresser, a butler sink, a green range cooker in a brick chimney recess
     with copper pans over it, a long pine table with a bench out in the room, a veg basket.
  d  student wreck — a short counter drowning in dishes, a microwave, the fridge left hanging
     open, a stack of pizza boxes and a camping table out in the room, bin bags.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, rrect, finish_module
import furn as F

CHROME = hexc('a9aeb0')
CHROME_DK = hexc('7b8083')
STEEL = hexc('9aa1a3')
STEEL_DK = hexc('737a7c')
BLOOD = hexc('4a1d1b', 150)
DARK = hexc('2c2620')


def base_units(c, x0, x1, top, P, worktop, worktop_edge, doors=None, open_door=None, kick=hexc('3b3027')):
    """A run of floor cupboards against the wall: worktop (top..top+3), door fronts, a kick plate."""
    b, lt, dk, out = P
    c.shadow((x0 + x1) // 2, 100, (x1 - x0) // 2 + 2, 2, 100)
    c.rect(x0 - 1, top, x1 + 1, top + 3, worktop)
    c.hline(x0 - 1, x1 + 1, top, shade(worktop, 1.1))
    c.hline(x0 - 1, x1 + 1, top + 3, worktop_edge)
    c.box(x0, top + 4, x1, 95, b, out)
    c.rect(x0, 96, x1, 99, kick)
    doors = doors or max(1, (x1 - x0) // 20)
    w = (x1 - x0 - 2) // doors
    for i in range(doors):
        d0 = x0 + 2 + i * w
        d1 = d0 + w - 2
        if i == open_door:
            c.rect(d0, top + 6, d1, 93, DARK)
            c.poly([(d0, top + 6), (d0 - 5, top + 8), (d0 - 5, 91), (d0, 93)], b)
            continue
        c.box(d0, top + 6, d1, 93, b, dk)
        c.hline(d0 + 1, d1 - 1, top + 7, lt)
        hx = d1 - 3 if i % 2 == 0 else d0 + 2
        c.rect(hx, top + 12, hx + 1, top + 17, CHROME)


def wall_units(c, x0, x1, top, bottom, P, open_door=None):
    b, lt, dk, out = P
    c.box(x0, top, x1, bottom, b, out)
    doors = max(1, (x1 - x0) // 18)
    w = (x1 - x0 - 2) // doors
    for i in range(doors):
        d0 = x0 + 2 + i * w
        d1 = d0 + w - 2
        if i == open_door:
            c.rect(d0, top + 2, d1, bottom - 2, DARK)
            c.hline(d0, d1, (top + bottom) // 2, dk)
            c.rect(d0 + 2, (top + bottom) // 2 - 6, d0 + 5, (top + bottom) // 2 - 1, hexc('c0a060'))
            c.rect(d0 + 7, bottom - 8, d1 - 2, bottom - 3, hexc('b0453a'))
            continue
        c.box(d0, top + 2, d1, bottom - 2, b, dk)
        c.hline(d0 + 1, d1 - 1, top + 3, lt)
        hx = d1 - 3 if i % 2 == 0 else d0 + 2
        c.rect(hx, bottom - 8, hx + 1, bottom - 4, CHROME)


def cooker(c, x0, top, body, body_dk, out, hob=hexc('2e2c29')):
    """A free-standing cooker slotted into the run: hob on top, a knob strip, the oven door."""
    x1 = x0 + 26
    c.rect(x0, top - 1, x1, top + 2, hob)
    c.box(x0, top + 3, x1, 99, body, out)
    c.rect(x0 + 1, top + 4, x1 - 1, top + 7, body_dk)
    for kx in range(x0 + 4, x1 - 2, 5):
        c.put(kx, top + 5, out)
    c.box(x0 + 3, top + 10, x1 - 3, 94, body, out)
    c.rect(x0 + 6, top + 14, x1 - 6, top + 22, hexc('2f2a26'))
    c.hline(x0 + 5, x1 - 5, top + 11, CHROME)


def a_frame_sink(c, x0, x1, top, steel=STEEL, steel_dk=STEEL_DK):
    c.rect(x0, top, x1, top + 2, steel)
    c.hline(x0 + 2, x1 - 2, top + 1, steel_dk)
    c.rect((x0 + x1) // 2 - 1, top - 8, (x0 + x1) // 2, top - 1, CHROME_DK)
    c.hline((x0 + x1) // 2 - 4, (x0 + x1) // 2, top - 8, CHROME_DK)


# ============================================================================================
# B — 60s galley
# ============================================================================================
B_WALL = hexc('b9c9b0')
YEL = (hexc('d9b84a'), hexc('e8cc6a'), hexc('b89830'), hexc('5e4a18'))


def b_wall(c):
    F.wall_plain(c, B_WALL, hexc('8a9a80'), hexc('3a3a36'))
    # a band of small square tiles behind the counter (x < 150), grease-streaked
    c.rect(0, 56, 150, 93, hexc('e6e2d4'))
    for y in range(56, 94, 6):
        c.hline(0, 150, y, hexc('c8c2b0'))
    for x in range(0, 151, 6):
        c.vline(x, 56, 93, hexc('c8c2b0'))
    c.dither(60, 58, 96, 72, hexc('a89868', 70), 0.3, pattern='random')
    for i in range(5):
        c.ellipse(180 + i * 6, 14 + (i % 2) * 3, 7, 5, hexc('8a9a70', 60))


def b_decor(c):
    c.ellipse(170, 34, 9, 9, hexc('d9b84a'))                                                # a sunburst clock
    c.ellipse(170, 34, 6, 6, hexc('f0ecd8'))
    c.vline(170, 30, 34, hexc('26262a')); c.hline(170, 173, 34, hexc('26262a'))
    c.box(290, 24, 310, 50, hexc('e6dfcc'), hexc('9a927e'))                                 # a calendar
    c.rect(292, 26, 308, 34, hexc('d9b84a'))
    for y in range(37, 49, 3):
        c.hline(292, 308, y, hexc('b9b09a'))


def b_floor(c):
    F.floor_lino(c, hexc('2e2e33'), hexc('dcd8cc'), size=16)


def b_furniture(c):
    wall_units(c, 8, 46, 22, 50, YEL, open_door=1)
    wall_units(c, 100, 146, 22, 50, YEL)
    base_units(c, 8, 150, 70, YEL, hexc('d6d2c4'), hexc('8a8678'), doors=6, open_door=2)
    cooker(c, 98, 70, hexc('ece8dc'), hexc('c9c5b8'), hexc('5e5a50'))
    c.rect(102, 66, 112, 69, hexc('9aa1a3')); c.rect(114, 67, 120, 69, hexc('b0453a'))   # a kettle, a pan
    a_frame_sink(c, 20, 44, 70)
    c.rect(128, 63, 142, 69, hexc('d9c24a'))                                                # a bread bin
    c.hline(128, 142, 63, hexc('b89830'))
    # the dinette: a formica table with chrome legs, two chairs pulled out, side-on
    chr_ = (CHROME, hexc('c9ced0'), CHROME_DK, hexc('4a4e50'))
    F.table_front(c, 170, 230, 92, 120, chr_, depth=5, cloth=hexc('d86a5a'), cloth_dk=hexc('b0453a'), hem=101)
    for y in range(93, 97):
        for x in range(170, 231, 4):
            c.put(x + (y % 2) * 2, y, hexc('e8a090'))
    F.side_chair(c, 152, 120, chr_, facing_right=True)
    c.rect(152, 101, 165, 103, hexc('d86a5a'))
    F.side_chair(c, 234, 120, chr_, facing_right=False)
    c.rect(235, 101, 248, 103, hexc('d86a5a'))
    c.rect(182, 87, 190, 91, hexc('ece8dc')); c.rect(206, 88, 212, 91, hexc('6f8fa0'))       # a plate, a cup
    c.ellipse(200, 90, 3, 1, BLOOD)
    # a tall larder cupboard on the right (x > 270)
    c.shadow(292, 100, 18, 2, 100)
    c.box(274, 16, 310, 99, YEL[0], YEL[3])
    c.box(277, 19, 307, 56, YEL[0], YEL[2])
    c.rect(277, 58, 307, 96, DARK)                                                          # its lower door open
    for sy in (68, 80):
        c.hline(277, 307, sy, YEL[2])
    for (x, h, col) in ((280, 8, hexc('c0a060')), (286, 6, hexc('b0453a')), (292, 9, hexc('6a8a5a')), (300, 5, hexc('c0a060'))):
        c.rect(x, 67 - h, x + 4, 67, col)
    for (x, col) in ((280, hexc('9aa3a8')), (285, hexc('9aa3a8')), (296, hexc('c9b86a'))):
        c.rect(x, 74, x + 3, 79, col)
    c.poly([(310, 58), (314, 60), (314, 94), (310, 96)], YEL[0])                             # the door, swung
    c.rect(304, 36, 305, 42, CHROME)


B_ANCHORS = [('anchor_kitchen_wall_units', 28, 42, 'bp'), ('anchor_kitchen_base_units', 60, 84, 'bp'),
             ('anchor_centre_oven', 111, 88, 'bp'), ('anchor_kitchen_formica_table', 196, 94, ''),
             ('anchor_kitchen_dinette_chair', 158, 102, ''), ('anchor_kitchen_larder', 292, 74, 'bp')]


# ============================================================================================
# C — farmhouse
# ============================================================================================
C_WALL = hexc('d6cbb0')
BRICK = hexc('9a5a3e')


def c_wall(c):
    F.wall_plain(c, C_WALL, hexc('a89a78'), hexc('5e4a3a'), texture=hexc('c9bda0'))
    # the chimney breast recess for the range (x 124..196): brick, sooty at the top
    c.rect(124, 26, 196, 99, hexc('3a2a22'))
    for y in range(28, 99, 4):
        off = 0 if (y // 4) % 2 == 0 else 4
        for x in range(124 + off, 197, 8):
            c.rect(x, y, x + 6, y + 2, BRICK)
    c.dither(126, 28, 194, 44, hexc('2a1e18', 150), 0.5, pattern='random')
    c.rect(118, 22, 202, 26, hexc('6b4a31'))                                                # the mantel beam
    c.hline(118, 202, 22, hexc('8a6443'))
    for y in range(27, 99):
        c.put(123, y, shade(C_WALL, 0.8)); c.put(197, y, shade(C_WALL, 0.8))


def c_decor(c):
    # copper pans hanging on a rail over the range
    c.hline(130, 190, 30, hexc('3a3a36'))
    for (x, r) in ((138, 6), (156, 8), (176, 5)):
        c.vline(x, 30, 34, hexc('3a3a36'))
        c.ellipse(x, 34 + r, r, r, hexc('b8703a'))
        c.ellipse(x - 2, 32 + r, r // 2, r // 2, hexc('d8904a'))


def c_floor(c):
    # quarry tiles: 16px terracotta squares, alternating a shade (repeats every 32px)
    rows = [100, 105, 111, 118, 126, 135, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, 320, 16):
            col = hexc('a8583a') if ((x // 16) + r) % 2 else hexc('9a4e34')
            c.rect(x, y0, x + 15, y1, col)
            c.vline(x, y0, y1, hexc('6e3a26'))
        c.hline(0, 319, y0, hexc('6e3a26'))
    c.hline(0, 319, 100, hexc('4e2a1c'))


def range_cooker(c, x0, x1, top):
    green, green_dk, green_lt, out = hexc('3e6a4a'), hexc('2e5238'), hexc('4e7e5a'), hexc('1a2a1e')
    c.shadow((x0 + x1) // 2, 100, (x1 - x0) // 2 + 2, 2, 110)
    c.rect(x0 - 1, top - 3, x1 + 1, top, hexc('9aa1a3'))                                   # hob lids
    for hx in (x0 + 6, x1 - 16):
        c.ellipse(hx + 5, top - 3, 6, 2, hexc('b9bfc1'))
    c.box(x0, top + 1, x1, 99, green, out)
    c.hline(x0 + 1, x1 - 1, top + 2, green_lt)
    for (d0, d1) in ((x0 + 3, (x0 + x1) // 2 - 2), ((x0 + x1) // 2 + 2, x1 - 3)):
        c.box(d0, top + 5, d1, top + 18, green, green_dk)
        c.hline(d0 + 2, d1 - 2, top + 7, hexc('d6d2c4'))
        c.box(d0, top + 21, d1, 95, green, green_dk)
        c.hline(d0 + 2, d1 - 2, top + 23, hexc('d6d2c4'))
    c.hline(x0 - 2, x1 + 2, top + 3, hexc('d6d2c4'))                                        # the rail
    c.rect(x0 + 4, top + 4, x0 + 12, top + 12, hexc('d8d2c2'))                              # a tea towel on it


def c_furniture(c):
    # a pine dresser on the left (x < 50): plates on the rack, drawers below
    c.shadow(27, 100, 22, 2, 100)
    c.box(8, 20, 46, 58, F.PINE[0], F.PINE[3])
    c.rect(10, 22, 44, 57, hexc('4a3620'))
    for sy in (34, 46):
        c.rect(10, sy, 44, sy + 1, F.PINE[1])
    for i, px in enumerate(range(14, 44, 8)):
        c.ellipse(px, 28, 3, 4, hexc('e6ddc8')); c.ellipse(px, 28, 1, 2, hexc('5f7896'))
        if i != 2:
            c.ellipse(px, 40, 3, 4, hexc('e6ddc8')); c.ellipse(px, 40, 1, 2, hexc('b0453a'))
    c.rect(12, 50, 16, 56, hexc('c9a06a')); c.rect(20, 51, 28, 56, hexc('7a8a5a'))
    F.chest(c, 8, 46, 60, 100, F.PINE, drawers=2, open_row=1)
    # a butler sink on brick piers under the L window box (top >= 67)
    c.shadow(72, 100, 18, 2, 100)
    c.rect(56, 88, 60, 99, BRICK); c.rect(84, 88, 88, 99, BRICK)
    c.box(54, 72, 90, 87, hexc('ece8dc'), hexc('7a766a'))
    c.hline(56, 88, 74, hexc('c9c5b8'))
    c.rect(70, 67, 72, 71, CHROME_DK); c.hline(66, 72, 67, CHROME_DK)
    c.rect(61, 93, 83, 99, hexc('4a3620'))                                                  # a curtain under it
    for x in range(61, 84, 3):
        c.vline(x, 88, 99, hexc('8a6a5a'))
    c.rect(62, 88, 83, 99, hexc('8a6a5a', 200))
    range_cooker(c, 132, 188, 70)
    # the long pine table with a bench, out in the room
    F.table_front(c, 206, 292, 94, 121, F.PINE, depth=6)
    F.chair_back(c, 222, 80, 94, F.PINE, width=16)
    F.chair_back(c, 262, 80, 94, F.PINE, width=16)
    c.rect(210, 112, 288, 114, F.PINE[1])                                                   # the bench
    c.hline(210, 288, 112, F.PINE[3])
    for lx in (214, 284):
        c.rect(lx, 115, lx + 1, 121, F.PINE[2])
    c.ellipse(236, 92, 7, 2, hexc('e6ddc8'))                                                # a loaf, a jug, a knife
    c.rect(232, 88, 240, 91, hexc('c9904a'))
    c.rect(254, 86, 259, 93, hexc('5f7896'))
    c.line(266, 93, 276, 92, hexc('b9bfc1'))
    c.ellipse(270, 95, 3, 1, BLOOD)
    # a basket of veg on the floor by the lane
    c.shadow(112, 121, 10, 2, 110)
    c.poly([(102, 110), (122, 110), (120, 121), (104, 121)], hexc('b39a6a'))
    for y in range(112, 121, 3):
        c.hline(103, 121, y, hexc('8a7348'))
    c.ellipse(108, 108, 3, 2, hexc('c9904a')); c.ellipse(115, 108, 3, 2, hexc('7a8a3a'))
    c.poly([(117, 106), (124, 100), (122, 108)], hexc('4e7e3a'))


C_ANCHORS = [('anchor_kitchen_pine_dresser', 26, 40, 'bp'), ('anchor_kitchen_dresser_drawer', 27, 88, 'bp'),
             ('anchor_kitchen_butler_sink', 72, 78, 'bp'), ('anchor_kitchen_veg_basket', 112, 112, ''),
             ('anchor_centre_oven', 146, 84, 'bp'), ('anchor_kitchen_pine_table', 248, 97, ''),
             ('anchor_kitchen_bench', 238, 113, '')]


# ============================================================================================
# D — student wreck
# ============================================================================================
D_WALL = hexc('c9c0a0')


def d_wall(c):
    F.wall_plain(c, D_WALL, hexc('9a927a'), hexc('4a4a48'), texture=hexc('b9b090'))
    c.rect(100, 58, 230, 93, hexc('d8d2c2'))                                                 # a white splashback
    for y in range(58, 94, 7):
        c.hline(100, 230, y, hexc('b9b3a4'))
    c.dither(150, 60, 190, 76, hexc('8a7a4a', 80), 0.35, pattern='random')                  # grease
    for i in range(6):
        c.ellipse(26 + i * 7, 14 + (i % 2) * 4, 9, 5, hexc('6a6a4a', 60))


def d_decor(c):
    c.rect(200, 26, 214, 44, hexc('e6dfcc'))                                                # a rota nobody kept
    for y in range(29, 43, 3):
        c.hline(202, 212, y, hexc('8a8270'))
    c.line(201, 30, 213, 42, hexc('a8322c'))
    c.rect(106, 30, 118, 40, hexc('d9c24a'))                                                # post-its
    c.rect(122, 34, 132, 43, hexc('e88aa0'))


def d_floor(c):
    F.floor_lino(c, hexc('8a8a78'), hexc('9a9a86'), size=16)
    for y in range(104, 144):
        for x in range(320):
            if (x * 3 + y * 17) % 32 == 5:
                c.put(x, y, hexc('6a6a58'))


def d_furniture(c):
    # the fridge, door hanging wide open (left, x < 50), shelves half empty
    c.shadow(24, 100, 18, 2, 100)
    c.box(8, 34, 40, 99, hexc('e6e2d6'), hexc('6d6c64'))
    c.rect(10, 36, 38, 97, hexc('b9c4c4'))
    for sy in (50, 64, 78):
        c.hline(10, 38, sy, hexc('dfe6e6'))
    c.rect(12, 44, 18, 49, hexc('e0d9b8')); c.rect(28, 58, 34, 63, hexc('b0453a'))
    c.rect(14, 72, 22, 77, hexc('7a8a5a')); c.ellipse(30, 76, 4, 2, hexc('6a7a4a'))         # something gone green
    c.poly([(40, 34), (48, 38), (48, 95), (40, 99)], hexc('d8d4c8'))                         # the door
    for sy in (50, 66, 82):
        c.hline(41, 47, sy, hexc('b9b5a8'))
    c.rect(42, 46, 46, 49, hexc('e8e2d0'))
    # the counter run with a sink full of dishes and a microwave
    base_units(c, 100, 232, 72, (hexc('e6e2d6'), hexc('f0ece2'), hexc('c9c5b8'), hexc('6d6c64')),
               hexc('6a6a66'), hexc('3a3a38'), doors=6, open_door=4)
    a_frame_sink(c, 130, 164, 72)
    for (x, y, col) in ((134, 66, hexc('e6ddc8')), (140, 64, hexc('5f7896')), (146, 67, hexc('e6ddc8')),
                        (152, 63, hexc('b0453a')), (158, 66, hexc('e6ddc8'))):
        c.ellipse(x, y, 4, 2, col)
    c.rect(148, 58, 150, 66, hexc('9aa3a8'))
    c.box(190, 56, 222, 71, hexc('3a3a3d'), hexc('1c1c1e'))                                 # microwave
    c.rect(193, 59, 212, 68, hexc('22302c'))
    c.rect(214, 59, 220, 68, hexc('26262a'))
    c.put(217, 61, hexc('4e8a5a'))
    c.rect(106, 66, 114, 71, hexc('c9b58a')); c.rect(116, 65, 120, 71, hexc('9aa3a8'))       # cereal, a can
    # the camping table out in the room: a kettle, mugs, an ashtray
    c.shadow(84, 121, 18, 2, 110)
    c.rect(66, 98, 102, 100, hexc('a9b0b2'))
    c.hline(66, 102, 98, hexc('c9d0d2'))
    c.line(70, 101, 78, 121, hexc('7b8083')); c.line(78, 101, 70, 121, hexc('7b8083'))
    c.line(90, 101, 98, 121, hexc('7b8083')); c.line(98, 101, 90, 121, hexc('7b8083'))
    c.rect(72, 90, 80, 97, hexc('9aa3a8')); c.put(81, 92, hexc('9aa3a8'))
    c.rect(86, 93, 90, 97, hexc('e6ddc8')); c.rect(93, 94, 97, 97, hexc('4e6ea0'))
    # pizza boxes stacked up by the lane, one open
    c.shadow(254, 121, 16, 2, 110)
    for i in range(5):
        y = 117 - i * 3
        c.box(240 + (i % 2), y, 268 + (i % 2), y + 3, hexc('c9b58a'), hexc('8a7a55'))
    c.poly([(241, 102), (269, 102), (272, 96), (244, 96)], hexc('d8c79a'))
    c.ellipse(256, 101, 8, 1, hexc('b0653a'))
    # bin bags against the wall (right)
    bag, bag_lt = hexc('2f2e2c'), hexc('4a4946')
    c.shadow(292, 100, 18, 2, 100)
    c.poly([(276, 100), (276, 86), (282, 78), (292, 78), (298, 86), (298, 100)], bag)
    c.poly([(286, 78), (288, 72), (291, 73), (290, 79)], hexc('222120'))
    c.poly([(292, 100), (294, 88), (302, 82), (310, 88), (310, 100)], bag)
    c.line(280, 84, 286, 97, bag_lt); c.line(300, 86, 306, 98, bag_lt)


D_ANCHORS = [('anchor_centre_fridge', 24, 60, 'bp'), ('anchor_kitchen_camp_table', 88, 95, ''),
             ('anchor_kitchen_dishes', 146, 70, 'bp'), ('anchor_kitchen_student_cupboard', 186, 84, 'bp'),
             ('anchor_kitchen_microwave', 202, 64, 'bp'), ('anchor_kitchen_pizza_boxes', 256, 108, ''),
             ('anchor_right_trashcan', 292, 90, 'bp')]


# ============================================================================================
# E — the hoarder
# ============================================================================================
E_WALL = hexc('b8a888')


def e_wall(c):
    F.wall_plain(c, E_WALL, hexc('8a7a5e'), hexc('4a3a2a'), texture=hexc('a89878'))
    c.rect(0, 60, 319, 93, hexc('c9b894'))                                      # old tiles, nicotine yellow
    for y in range(60, 94, 8):
        c.hline(0, 319, y, hexc('a89878'))
    for x in range(0, 320, 8):
        c.vline(x, 60, 93, hexc('a89878'))
    c.dither(0, 6, 319, 30, hexc('8a7a4a', 60), 0.3, pattern='random')          # smoke-stained ceiling line


def e_decor(c):
    for (x, y) in ((110, 24), (126, 30), (140, 22), (196, 28), (212, 34)):     # clippings pinned everywhere
        c.rect(x, y, x + 10, y + 12, hexc('d9d0b0'))
        for yy in range(y + 2, y + 11, 2):
            c.hline(x + 1, x + 8, yy, hexc('8a8270'))
    c.line(115, 20, 216, 40, hexc('a8322c'))                                    # string between them


def e_floor(c):
    F.floor_lino(c, hexc('8a7a5e'), hexc('a08e6e'), size=16)


def paper_stack(c, x0, base, h, w=16, lean=0):
    c.shadow(x0 + w // 2, base, w // 2 + 2, 1, 110)
    for i in range(0, h, 3):
        dx = (lean * i) // max(h, 1)
        col = hexc('d8cfb4') if (i // 3) % 3 else hexc('c9bf9e')
        c.rect(x0 + dx, base - i - 2, x0 + dx + w, base - i, col)
        c.hline(x0 + dx, x0 + dx + w, base - i, hexc('9a927e'))
    c.rect(x0 + 3 + lean, base - h - 1, x0 + w - 4 + lean, base - h, hexc('a8322c'))   # string


def e_furniture(c):
    # the old cooker + a counter buried in stuff, against the wall
    base_units(c, 100, 200, 72, (hexc('d6cfb8'), hexc('e6e0cc'), hexc('b9b29a'), hexc('5e584a')),
               hexc('8a8270'), hexc('4a4638'), doors=5, open_door=3)
    cooker(c, 202, 72, hexc('e6e0cc'), hexc('c9c2b1'), hexc('5e584a'))
    for (x, h, col) in ((104, 10, hexc('9aa3a8')), (110, 14, hexc('c9b86a')), (118, 8, hexc('b0453a')),
                        (126, 16, hexc('d8cfb4')), (140, 12, hexc('9aa3a8')), (150, 6, hexc('7a8a5a')),
                        (160, 18, hexc('d8cfb4')), (176, 9, hexc('c9b86a')), (186, 13, hexc('9aa3a8'))):
        c.rect(x, 71 - h, x + 7, 71, col)                                        # piled tins, jars, papers
        c.hline(x, x + 7, 71 - h, shade(col, 1.15))
    c.rect(206, 64, 224, 69, hexc('7a6a58'))                                     # a pile of pans on the hob
    c.rect(209, 59, 221, 63, hexc('5a5249'))
    # newspaper stacks along the left wall, one toppled
    for (x, h, lean) in ((8, 40, 1), (26, 52, -1), (44, 30, 0)):
        paper_stack(c, x, 99, h, 16, lean)
    c.poly([(62, 121), (90, 116), (92, 120), (64, 124)], hexc('d8cfb4'))          # a toppled stack by the lane
    c.poly([(66, 118), (94, 113), (95, 116), (67, 121)], hexc('c9bf9e'))
    c.line(64, 122, 92, 117, hexc('9a927e'))
    # a table out in the room buried in plastic bags + cat food tins
    F.table_front(c, 236, 296, 96, 121, F.WOOD, depth=5)
    for (x, col) in ((238, hexc('e6e0cc')), (252, hexc('c0453a')), (266, hexc('e6e0cc')), (280, hexc('4e6ea0'))):
        rrect(c, x, 86, x + 12, 96, col, 3)                                     # a tied carrier bag
        c.poly([(x + 3, 87), (x + 5, 81), (x + 7, 87)], col)                     # its knotted handles
        c.poly([(x + 6, 87), (x + 9, 82), (x + 10, 87)], shade(col, 0.85))
        c.line(x + 2, 90, x + 9, 94, shade(col, 0.82))
    for x in range(240, 294, 6):
        c.rect(x, 116, x + 4, 120, hexc('b9bfc1'))
        c.hline(x, x + 4, 116, hexc('d8e0e2'))
    # a cat bowl, a cat nowhere to be seen
    c.ellipse(212, 118, 6, 2, hexc('a8322c'))
    c.ellipse(212, 117, 4, 1, hexc('6a4a2a'))


E_ANCHORS = [('anchor_kitchen_paper_stacks', 32, 70, 'bp'), ('anchor_kitchen_toppled_papers', 78, 118, ''),
             ('anchor_kitchen_buried_counter', 150, 80, 'bp'), ('anchor_centre_oven', 214, 88, 'bp'),
             ('anchor_kitchen_bag_table', 258, 90, ''), ('anchor_kitchen_cat_tins', 262, 118, '')]


VARIANTS = {
    'b': ('kitchen_b', 34, (b_wall, b_decor, b_floor, b_furniture), B_ANCHORS),
    'c': ('kitchen_c', 35, (c_wall, c_decor, c_floor, c_furniture), C_ANCHORS),
    'd': ('kitchen_d', 36, (d_wall, d_decor, d_floor, d_furniture), D_ANCHORS),
    'e': ('kitchen_e', 37, (e_wall, e_decor, e_floor, e_furniture), E_ANCHORS),
}


def make(fns):
    wall, decor, floor, furniture = fns

    def bare(c):
        wall(c)

    def build(c):
        wall(c)
        decor(c)
        floor(c)
        furniture(c)
        return c
    return bare, floor, build


if __name__ == '__main__':
    for v in (sys.argv[1:] or sorted(VARIANTS)):
        name, seed, fns, anchors = VARIANTS[v]
        bare, floor, build = make(fns)
        finish_module(name, 'kitchen', seed, bare, floor, build, anchors)
