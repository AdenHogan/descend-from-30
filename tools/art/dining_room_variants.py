"""Dining room VARIANTS b-d (variant a is tools/art/dining_room.py). Same rules via
pixlib.finish_module. A dining room can hold the BALCONY doors (x 4..96): that strip's furniture goes
in strip() — hidden, with its nodes, on a balcony slot.

Run:  python3 tools/art/dining_room_variants.py [b c d]

  b  70s — a round pedestal table with tulip chairs out in the room, a serving hatch in the wall,
     a teak sideboard with a record player; strip: a drinks cabinet, a pouffe.
  c  formal — a long table with a candelabra, high-backed chairs, a grandfather clock, a silver
     sideboard, portraits; strip: a glass-front china cabinet.
  d  barricaded — the table flipped on its side across the room as a barricade (something behind
     it), chairs stacked, planks, tins, blood; strip: a pile of broken chairs.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, rrect, finish_module
import furn as F

BLOOD = hexc('4a1d1b', 150)
BLOOD_DK = hexc('3a1512', 190)
PLATE = hexc('e8e4d8')
PLATE_DK = hexc('c3beb0')
SILVER = hexc('b9bfc1')


# ============================================================================================
# B — 70s round table
# ============================================================================================
def b_wall(c):
    F.wall_plain(c, hexc('c9a86a'), hexc('9a7a4a'), hexc('5a4028'), texture=hexc('bb9a5e'))
    # bold 70s wallpaper: big orange/brown circles on a 32px grid above the dado line
    for y in range(20, 64, 22):
        off = 0 if (y // 22) % 2 == 0 else 16
        for x in range(off, 320, 32):
            c.ellipse(x + 8, y, 6, 6, hexc('b0653a'))
            c.ellipse(x + 8, y, 3, 3, hexc('7a4020'))
    c.rect(0, 66, 319, 93, hexc('6a4a2a'))                                                    # a brown dado
    c.rect(0, 66, 319, 67, hexc('4a321c'))
    for i in range(6):
        c.ellipse(290 + i * 4, 18 + (i % 2) * 3, 8, 5, hexc('6a5a3a', 60))


def b_decor(c):
    # the serving hatch to the kitchen: a dark opening with folding louvred doors
    c.rect(170, 30, 214, 60, hexc('1e1a16'))
    c.box(168, 28, 216, 62, hexc('8a6443'), hexc('3a2718'))
    c.rect(170, 30, 214, 60, hexc('1e1a16'))
    c.rect(168, 58, 216, 62, hexc('9e7550'))                                                 # its sill
    for (d0, d1) in ((171, 181), (203, 213)):
        c.rect(d0, 31, d1, 57, hexc('9e7550'))
        for y in range(33, 56, 3):
            c.hline(d0 + 1, d1 - 1, y, hexc('6b4a31'))
    c.rect(186, 52, 192, 57, PLATE)                                                           # a plate left on the sill


def b_floor(c):
    F.floor_carpet(c, hexc('7a5a3a'), hexc('8a6a44'), hexc('6a4a30'), worn=hexc('8a6a4a'))


def tulip_chair(c, x0, base, col, facing_right):
    """A moulded tulip chair side-on: a cup seat on a single flared stem."""
    d = 1 if facing_right else -1
    c.shadow(x0 + 7, base, 8, 1, 110)
    c.hline(x0, x0 + 14, base, shade(col, 0.6))
    c.vline(x0 + 7, base - 14, base - 1, hexc('dcd8cc'))
    c.hline(x0 + 5, x0 + 9, base - 1, hexc('dcd8cc'))
    back = x0 if facing_right else x0 + 14
    c.poly([(x0, base - 16), (x0 + 14, base - 16), (x0 + 12, base - 13), (x0 + 2, base - 13)], col)
    c.poly([(back, base - 16), (back, base - 30), (back + 3 * d, base - 30), (back + 5 * d, base - 16)], col)
    c.vline(back, base - 30, base - 16, shade(col, 0.75))


def b_strip(c):
    # a drinks cabinet (the flap down, bottles inside) + a leather pouffe
    c.shadow(28, 100, 20, 2, 100)
    c.box(10, 62, 46, 99, F.TEAK[0], F.TEAK[3])
    c.rect(12, 64, 44, 80, hexc('2a1d14'))
    for (x, h, col) in ((14, 12, hexc('3a5a3a')), (20, 10, hexc('7a4a2a')), (26, 13, hexc('c9c2b1')), (34, 11, hexc('5a1a22'))):
        c.rect(x, 80 - h, x + 3, 79, col)
        c.rect(x + 1, 80 - h - 3, x + 2, 80 - h - 1, col)
    c.box(12, 82, 44, 97, F.TEAK[0], F.TEAK[2])
    c.rect(26, 88, 30, 88, F.BRASS)
    c.poly([(12, 80), (44, 80), (48, 84), (8, 84)], F.TEAK[1])                                # the drop flap
    def _pouffe(c):
        # (a leather pouffe beside the cabinet)
        c.shadow(72, 120, 12, 2, 110)
        rrect(c, 60, 106, 84, 120, hexc('8a4a2a'), 4)
        c.hline(62, 82, 107, hexc('a8623a'))
        for x in range(64, 82, 4):
            c.vline(x, 109, 118, hexc('6a3a20'))
    F.moved(c, _pouffe, -10, -16)


def b_furniture(c):
    # the round pedestal table + chairs out in the room
    cx = 150
    c.shadow(cx, 121, 34, 3, 110)
    c.ellipse(cx, 94, 32, 6, hexc('e6e0cc'))
    c.ellipse(cx, 93, 31, 5, hexc('f0ece2'))
    c.hline(cx - 31, cx + 31, 99, hexc('9a9486'))
    c.rect(cx - 2, 100, cx + 2, 118, hexc('dcd8cc'))
    c.ellipse(cx, 120, 12, 2, hexc('dcd8cc'))
    tulip_chair(c, 100, 120, hexc('d86a3a'), True)
    tulip_chair(c, 186, 120, hexc('d86a3a'), False)
    c.ellipse(138, 92, 6, 1, PLATE_DK); c.ellipse(138, 92, 5, 1, PLATE)                       # fondue, plates
    c.ellipse(162, 92, 6, 1, PLATE_DK); c.ellipse(162, 92, 5, 1, PLATE)
    c.rect(146, 85, 154, 91, hexc('b0453a')); c.hline(144, 156, 85, hexc('8a3028'))
    c.line(150, 84, 156, 78, SILVER)
    c.ellipse(170, 95, 4, 1, BLOOD)
    # a teak sideboard with a record player on the right
    F.chest(c, 244, 310, 72, 100, F.TEAK, drawers=2, open_row=1)
    c.box(272, 64, 294, 71, hexc('3a3a3d'), hexc('1c1c1e'))
    c.ellipse(281, 66, 7, 1, hexc('1c1c1e'))
    c.line(291, 65, 285, 67, SILVER)
    for (x, col) in ((299, hexc('d86a3a')), (302, hexc('2f4a63')), (305, hexc('d9c24a'))):
        c.rect(x, 58, x + 2, 71, col)                                                           # records leant up
    F.pendant(c, 140, 22, 'orange', dome=True)                                    # a 70s dome pendant

B_ANCHORS = [('anchor_dining_drinks_cabinet', 26, 72, 'bp s'), ('anchor_dining_pouffe', 62, 94, 's'),
             ('anchor_table_left', 138, 93, ''), ('anchor_table_right', 164, 93, ''),
             ('anchor_dining_tulip_chair', 196, 104, ''), ('anchor_dining_record_player', 281, 67, 'bp'),
             ('anchor_right_lowerdrawers', 276, 88, 'bp')]


# ============================================================================================
# C — formal
# ============================================================================================
def c_wall(c):
    F.wall_plain(c, hexc('3e4a5a'), hexc('2a3240'), hexc('2a1e18'), rail=hexc('b58f4a'), rail_y=16,
                 dado=hexc('4a3024'), dado_y=62)
    F.wall_motif(c, hexc('4a586a'), hexc('34404e'), y1=58)
    for x in range(0, 320, 32):                                                                # dado panels
        c.box(x + 4, 67, x + 27, 90, hexc('4a3024'), hexc('36221a'))
    for i in range(6):
        c.ellipse(20 + i * 6, 18 + (i % 2) * 3, 8, 5, hexc('2a303a', 70))


def c_decor(c):
    for (x0, x1, fill) in ((134, 156, hexc('6a5a4a')), (166, 188, hexc('5a4a3e')), (198, 220, hexc('6a5a4a'))):
        F.frame_pic(c, x0, 24, x1, 52, hexc('b58f4a'), fill)
        c.ellipse((x0 + x1) // 2, 34, 5, 6, hexc('c8b39a'))
        c.rect((x0 + x1) // 2 - 6, 42, (x0 + x1) // 2 + 6, 50, hexc('2a2622'))
    c.line(170, 30, 184, 48, hexc('1e1a16'))                                                  # one slashed


def c_floor(c):
    import living_room_variants as LV
    LV.parquet_floor(c, hexc('5a3a26'), hexc('4e321f'), hexc('33200f'))


def grandfather_clock(c, x0, base):
    x1 = x0 + 18
    c.shadow(x0 + 9, base, 11, 2, 100)
    c.box(x0 + 3, base - 50, x1 - 3, base, F.WOOD[0], F.WOOD[3])                              # the trunk
    c.box(x0, base - 76, x1, base - 50, F.WOOD[0], F.WOOD[3])                                 # the hood
    c.poly([(x0, base - 76), (x0 + 9, base - 84), (x1, base - 76)], F.WOOD[1])
    c.ellipse(x0 + 9, base - 64, 7, 7, hexc('e6ddc8'))
    c.ellipse(x0 + 9, base - 64, 7, 7, hexc('e6ddc8'))
    c.vline(x0 + 9, base - 69, base - 64, hexc('26262a')); c.line(x0 + 9, base - 64, x0 + 13, base - 62, hexc('26262a'))
    c.rect(x0 + 6, base - 46, x1 - 6, base - 16, hexc('2a1d14'))                               # the pendulum window
    c.vline(x0 + 9, base - 46, base - 24, F.BRASS)
    c.ellipse(x0 + 9, base - 22, 3, 3, F.BRASS)


def c_strip(c):
    c.shadow(28, 100, 20, 2, 100)
    c.box(8, 30, 46, 99, F.WOOD[0], F.WOOD[3])
    c.rect(7, 27, 47, 30, F.WOOD[1])
    c.box(11, 34, 43, 72, hexc('9fb3b0'), F.WOOD[2])
    c.vline(27, 34, 72, F.WOOD[2])
    for py in (44, 58):
        c.hline(12, 42, py + 6, F.WOOD[2])
        for px in range(15, 42, 7):
            c.ellipse(px, py, 2, 3, PLATE)
            c.put(px, py, hexc('7ea0b8'))
    c.line(13, 36, 21, 52, hexc('d6e2e0'))
    c.box(11, 76, 43, 96, F.WOOD[0], F.WOOD[2])
    c.vline(27, 76, 96, F.WOOD[2])
    c.put(25, 86, F.BRASS); c.put(29, 86, F.BRASS)


def c_furniture(c):
    grandfather_clock(c, 104, 100)
    # the long table, high-backed chairs behind it, a candelabra
    for x in (140, 170, 200):
        F.chair_back(c, x, 62, 94, F.WOOD, width=16, slats=3)
    F.table_front(c, 126, 236, 92, 120, F.WOOD, depth=6)
    c.rect(125, 92, 237, 98, F.WOOD[1])
    c.hline(125, 237, 92, F.WOOD[3])
    c.rect(150, 91, 210, 93, hexc('d6d0bf'))                                                 # a runner
    cx = 180                                                                                  # the candelabra
    c.rect(cx - 3, 88, cx + 3, 90, SILVER)
    c.vline(cx, 76, 88, SILVER)
    c.hline(cx - 10, cx + 10, 80, SILVER)
    for dx in (-10, 0, 10):
        c.vline(cx + dx, 76, 80, SILVER)
        F.candle(c, cx + dx, 75, 5)
    for px in (140, 160, 200, 222):
        c.ellipse(px, 94, 6, 1, PLATE_DK); c.ellipse(px, 94, 5, 1, PLATE)
    c.line(156, 93, 164, 96, SILVER)
    c.ellipse(210, 95, 4, 1, BLOOD)
    # a sideboard with silver on the right (x > 240)
    F.chest(c, 250, 310, 72, 100, F.WOOD, drawers=2)
    c.rect(256, 67, 266, 71, SILVER); c.hline(254, 268, 67, SILVER)                           # a tea set
    c.rect(276, 66, 282, 71, SILVER); c.put(283, 68, SILVER)
    c.rect(288, 60, 294, 71, SILVER); c.hline(286, 296, 60, SILVER)
    c.ellipse(303, 70, 5, 1, SILVER)
    F.flush_light(c, 177)                                                         # above the portraits

C_ANCHORS = [('anchor_dining_china_cabinet', 28, 52, 'bp s'), ('anchor_dining_cabinet_cupboard', 20, 86, 'bp s'),
             ('anchor_dining_grandfather_clock', 113, 70, 'bp'), ('anchor_table_left', 142, 95, ''),
             ('anchor_table_right', 222, 95, ''), ('anchor_dining_candelabra', 180, 84, ''),
             ('anchor_right_upperdrawers', 280, 80, 'bp')]


# ============================================================================================
# D — barricaded
# ============================================================================================
def d_wall(c):
    F.wall_plain(c, hexc('8a7a6a'), hexc('6a5a4a'), hexc('3e3026'), texture=hexc('7e6e5e'))
    for (sx, sy, rx, ry) in ((30, 20, 24, 14), (240, 12, 34, 8)):
        c.ellipse(sx, sy, rx, ry, hexc('5a4a3a', 70))


def d_decor(c):
    # planks nailed across where something came through the plaster
    c.poly([(150, 30), (172, 26), (180, 40), (170, 56), (152, 52)], hexc('2a2019'))
    for (y, a, b) in ((32, 142, 188), (44, 140, 190)):
        c.line(a, y, b, y + 4, hexc('8a6a44'))
        c.line(a, y + 1, b, y + 5, hexc('8a6a44'))
        c.line(a, y + 2, b, y + 6, hexc('6a4e30'))
        c.put(a + 3, y + 1, hexc('3a3a36')); c.put(b - 3, y + 5, hexc('3a3a36'))
    for i in range(4):                                                                        # a bloody handprint
        c.line(118 + i * 2, 58, 117 + i * 2, 50 - i, BLOOD)
    c.ellipse(121, 60, 4, 3, BLOOD)
    c.line(121, 63, 122, 80, BLOOD)


def d_floor(c):
    F.floor_planks(c, [hexc('5a4432'), hexc('523e2e'), hexc('604a36')], hexc('33261a'))


def d_strip(c):
    # a heap of broken chairs piled against the wall (bits to barricade with)
    c.shadow(30, 100, 22, 2, 100)
    for (a, b) in (((10, 99), (40, 72)), ((16, 99), (46, 80)), ((8, 84), (44, 90)), ((24, 70), (30, 99))):
        c.line(a[0], a[1], b[0], b[1], F.WOOD[0])
        c.line(a[0] + 1, a[1], b[0] + 1, b[1], F.WOOD[2])
    c.rect(14, 86, 34, 88, F.WOOD[1])                                                         # a seat
    c.rect(26, 74, 44, 76, F.WOOD[1])
    c.line(38, 70, 38, 62, F.WOOD[0]); c.line(44, 72, 44, 64, F.WOOD[0])
    def _lantern(c):
        # a lantern + tins set down against the wall beside the broken chairs
        c.shadow(72, 120, 10, 2, 110)
        for (x, col) in ((62, hexc('b0453a')), (68, hexc('c9b86a')), (74, hexc('b0453a'))):
            c.rect(x, 113, x + 4, 120, col)
            c.hline(x, x + 4, 113, hexc('c9c7bd'))
        c.box(80, 104, 90, 120, hexc('3a3a36'), hexc('1c1c1a'))
        c.rect(82, 107, 88, 116, hexc('d9b44a'))
        c.hline(81, 89, 104, hexc('5a5a52'))
        F.light(85, 111, 'lantern')
    F.moved(c, _lantern, -12, -21)


def d_furniture(c):
    # the table flipped onto its side across the room: its top faces us, legs sticking back
    x0, x1, top, base = 118, 216, 80, 121
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 4, 3, 120)
    for lx in (x0 + 8, x1 - 12):                                                              # the legs, poking up behind
        c.rect(lx, top - 14, lx + 3, top, F.WOOD[2])
    c.box(x0, top, x1, base, F.WOOD[0], F.WOOD[3])                                            # the underside of the top
    c.rect(x0 + 4, top + 4, x1 - 4, top + 7, F.WOOD[2])                                       # its apron rails
    c.rect(x0 + 4, base - 7, x1 - 4, base - 4, F.WOOD[2])
    for y in range(top + 10, base - 8, 5):
        c.hline(x0 + 2, x1 - 2, y, shade(F.WOOD[0], 0.9))
    for (x, y) in ((140, 94), (176, 100), (196, 90)):                                        # gouges, something clawed at it
        c.line(x, y, x + 6, y + 8, hexc('2a1a10'))
        c.line(x + 3, y, x + 9, y + 8, hexc('2a1a10'))
    c.ellipse(160, 104, 5, 3, BLOOD_DK)
    c.line(158, 106, 157, 118, BLOOD)
    # chairs stacked behind it, their legs up
    F.chair_back(c, 126, 64, 80, F.WOOD, width=14)
    c.line(196, 64, 204, 80, F.WOOD[0]); c.line(202, 62, 210, 80, F.WOOD[0])
    # a mattress propped against the wall on the right
    c.shadow(283, 100, 13, 2, 100)
    c.box(272, 30, 294, 99, hexc('c9c0a8'), hexc('8a8270'))
    for y in range(36, 98, 8):
        c.hline(274, 292, y, hexc('b9b09a'))
    c.dither(276, 60, 290, 80, hexc('8a7a52', 90), 0.4, pattern='random')
    # planks leaning up by the corner; the hammer dropped beside the barricade
    for (x, col) in ((297, hexc('8a6a44')), (301, hexc('9a7a4e')), (305, hexc('7a5a38'))):
        c.line(x, 100, x + 4, 40, col)
        c.line(x + 1, 100, x + 5, 40, col)
    c.shadow(228, 120, 8, 1, 110)                                             # the hammer, dropped at the table's foot
    c.rect(218, 116, 236, 118, F.WOOD[1])
    c.rect(232, 112, 238, 118, hexc('5a5a52'))


D_ANCHORS = [('anchor_dining_broken_chairs', 28, 86, 'bp s'), ('anchor_dining_lantern', 73, 91, 'bp s'),
             ('anchor_dining_behind_table', 168, 90, ''), ('anchor_table_right', 204, 110, ''),
             ('anchor_dining_mattress', 283, 64, 'bp'), ('anchor_dining_hammer', 228, 116, '')]


# ============================================================================================
# E — a birthday party, abandoned
# ============================================================================================
PARTY = [hexc('d86a5a'), hexc('5a8ac0'), hexc('e6c24a'), hexc('6aa06a'), hexc('b07ab8')]


def e_wall(c):
    F.wall_plain(c, hexc('d9c9a0'), hexc('a8986e'), hexc('6a5438'), rail=hexc('8a6443'), rail_y=64)
    F.wall_motif(c, hexc('c9b98e'), hexc('b0a078'), y1=60)
    c.rect(0, 66, 319, 93, hexc('b9a880'))
    for i in range(5):
        c.ellipse(24 + i * 6, 18 + (i % 2) * 3, 8, 5, hexc('8a7a50', 60))


def e_decor(c):
    # bunting strung across the wall, a hand-painted banner, a few balloons gone soft
    for (x0, x1, sag) in ((100, 222, 8),):
        prev = None
        for x in range(x0, x1 + 1):
            t = (x - x0) / float(x1 - x0)
            y = 20 + int(4 * sag * t * (1 - t))
            if prev:
                c.line(prev[0], prev[1], x, y, hexc('6a5438'))
            prev = (x, y)
            if (x - x0) % 10 == 0 and x0 < x < x1:
                col = PARTY[((x - x0) // 10) % len(PARTY)]
                c.poly([(x - 3, y + 1), (x + 3, y + 1), (x, y + 7)], col)
    c.rect(122, 34, 200, 44, hexc('efe8d8'))                                     # the banner
    for (x, col) in ((128, PARTY[0]), (138, PARTY[1]), (148, PARTY[2]), (158, PARTY[3]),
                     (170, PARTY[4]), (180, PARTY[0]), (190, PARTY[1])):
        c.rect(x, 36, x + 5, 42, col)
    for (x, y, col) in ((108, 50, PARTY[1]), (214, 52, PARTY[0])):
        c.ellipse(x, y, 5, 6, col)
        c.ellipse(x - 2, y - 2, 1, 2, shade(col, 1.3))
        c.line(x, y + 6, x + 2, y + 18, hexc('9a927e'))


def e_floor(c):
    F.floor_carpet(c, hexc('8a5a4a'), hexc('9a6a58'), hexc('7a4a3c'), worn=hexc('a07060'))


def e_strip(c):
    # a pile of wrapped presents, never opened, and one that was
    c.shadow(28, 100, 22, 2, 100)
    for (x0, y0, x1, col, rib) in ((8, 84, 30, PARTY[1], PARTY[2]), (28, 88, 46, PARTY[0], PARTY[3]),
                                   (14, 72, 34, PARTY[4], PARTY[2])):
        c.box(x0, y0, x1, 99 if y0 > 80 else 83, col, shade(col, 0.6))
        c.vline((x0 + x1) // 2, y0, 99 if y0 > 80 else 83, rib)
        c.hline(x0, x1, y0 + 4, rib)
    c.poly([(22, 72), (26, 66), (30, 72)], PARTY[2])
    def _box(c):
        # a torn-open box beside the pile of presents, something dark inside
        c.shadow(72, 121, 12, 2, 110)
        c.box(62, 108, 84, 121, PARTY[3], shade(PARTY[3], 0.6))
        c.rect(64, 110, 82, 113, hexc('1e1a16'))
        c.poly([(62, 108), (56, 102), (58, 100), (64, 106)], PARTY[3])
        c.poly([(84, 108), (92, 104), (92, 106), (85, 110)], PARTY[3])
        c.line(58, 118, 50, 121, hexc('efe8d8'))
    F.moved(c, _box, -8, -21)


def e_furniture(c):
    # the party table out in the room: a cake with the candles burnt down, paper plates, hats
    F.chair_back(c, 132, 70, 94, F.PINE, width=14)
    F.chair_back(c, 176, 70, 94, F.PINE, width=14)
    F.chair_back(c, 214, 70, 94, F.PINE, width=14)
    F.table_front(c, 116, 244, 92, 120, F.PINE, depth=6, cloth=hexc('efe8d8'), cloth_dk=hexc('d0c8b4'), hem=104)
    for x in range(118, 244, 8):                                                  # a paper cloth, printed
        c.put(x, 95, PARTY[(x // 8) % len(PARTY)])
    c.ellipse(180, 90, 12, 2, hexc('e6ddc8'))                                     # the cake
    c.rect(170, 82, 190, 89, hexc('d98aa0'))
    c.hline(170, 190, 82, hexc('f0d0dc'))
    c.dither(170, 84, 190, 86, hexc('efe8d8'), 0.5)
    c.poly([(184, 82), (190, 82), (190, 89), (186, 89)], hexc('8a5a3a'))           # a slice cut, the sponge showing
    for x in (174, 178, 182):
        c.rect(x, 78, x, 81, PARTY[x % 5])
    c.put(178, 77, hexc('3a2a1a'))
    for (x, col) in ((136, PARTY[0]), (152, PARTY[1]), (206, PARTY[3]), (226, PARTY[4])):
        c.ellipse(x, 92, 6, 1, hexc('efe8d8'))
        c.poly([(x - 3, 90), (x + 3, 90), (x, 83)], col)                          # party hats left on the plates
    c.ellipse(212, 96, 4, 1, BLOOD)
    # a sideboard with a cassette player and a stack of paper cups
    F.chest(c, 250, 310, 72, 100, F.PINE, drawers=2, open_row=0)
    c.box(274, 62, 296, 71, hexc('3a3a3d'), hexc('1c1c1e'))
    c.ellipse(280, 66, 2, 2, hexc('9aa3a8')); c.ellipse(290, 66, 2, 2, hexc('9aa3a8'))
    c.rect(300, 60, 305, 71, hexc('efe8d8'))
    for y in range(62, 71, 2):
        c.hline(300, 305, y, hexc('d0c8b4'))
    F.flush_light(c, 160)

E_ANCHORS = [('anchor_dining_presents', 24, 80, 'bp s'), ('anchor_dining_torn_box', 64, 91, 'bp s'),
             ('anchor_table_left', 140, 94, ''), ('anchor_dining_cake', 180, 86, ''),
             ('anchor_table_right', 226, 94, ''), ('anchor_right_upperdrawers', 280, 82, 'bp')]


VARIANTS = {
    'b': ('dining_room_b', 62, (b_wall, b_decor, b_floor, b_furniture, b_strip), B_ANCHORS),
    'c': ('dining_room_c', 63, (c_wall, c_decor, c_floor, c_furniture, c_strip), C_ANCHORS),
    'd': ('dining_room_d', 64, (d_wall, d_decor, d_floor, d_furniture, d_strip), D_ANCHORS),
    'e': ('dining_room_e', 65, (e_wall, e_decor, e_floor, e_furniture, e_strip), E_ANCHORS),
}


def make(fns):
    wall, decor, floor, furniture, strip = fns

    def bare(c):
        wall(c)

    def build(c):
        wall(c)
        decor(c)
        floor(c)
        furniture(c)
        return c
    return bare, floor, build, strip


if __name__ == '__main__':
    for v in (sys.argv[1:] or sorted(VARIANTS)):
        name, seed, fns, anchors = VARIANTS[v]
        bare, floor, build, strip = make(fns)
        finish_module(name, 'dining_room', seed, bare, floor, build, anchors, strip_fn=strip)
