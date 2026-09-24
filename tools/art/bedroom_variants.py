"""Bedroom VARIANTS b-d (variant a is tools/art/bedroom.py). Same rules via pixlib.finish_module.

Run:  python3 tools/art/bedroom_variants.py [b c d]

  b  teenager's room — posters, a desk with an old computer, a single bed on the RIGHT with a
     starry duvet, a beanbag out in the room, a clothes pile.
  c  sick room — an iron bedstead in the middle with a drip stand, a wheelchair and a medicine
     trolley out in the room, a mirrored wardrobe, a cabinet of pill bottles.
  d  squat — a mattress on the floor with a sleeping bag, a freestanding clothes rail, a
     backpack, crates with a camping stove and candles, boxes; bare stained plaster.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, rrect, finish_module
import furn as F

OUT = hexc('2a1c17')
SHEET = hexc('c9c2b1')
SHEET_DK = hexc('aaa293')
PILLOW = hexc('d8d1bf')
PILLOW_DK = hexc('b7af9c')
BLOOD = hexc('4a1d1b', 150)
CLOTH = [hexc('8a4a42'), hexc('4e5d70'), hexc('c1b69c'), hexc('5f6b4e'), hexc('7d6a8a'), hexc('2e2e33')]


def mattress_top(c, x0, x1, top, front, duvet, duvet_dk, duvet_lt, pillow_at_right=False, hem=None):
    """A mattress seen from a little above: the top (top..front), a duvet over most of it that
    drapes over the front edge, a pillow at one end."""
    c.rect(x0, top, x1, front, SHEET)
    c.hline(x0, x1, top, SHEET_DK)
    c.rect(x0, front + 1, x1, front + 6, SHEET_DK)
    px0, px1 = (x1 - 24, x1 - 3) if pillow_at_right else (x0 + 3, x0 + 24)
    rrect(c, px0, top - 1, px1, top + 8, PILLOW, 3)
    c.hline(px0 + 2, px1 - 2, top + 8, PILLOW_DK)
    c.rect(px0 + 7, top + 2, px1 - 7, top + 4, PILLOW_DK)
    da, db = (x0, x1 - 27) if pillow_at_right else (x0 + 27, x1)
    c.rect(da, top, db, front, duvet)
    c.hline(da, db, top, duvet_dk)
    fold = db - 9 if pillow_at_right else da
    c.poly([(fold, top), (fold + 9, top), (fold + 9 + (3 if not pillow_at_right else -3), front), (fold, front)], shade(duvet_lt, 1.05))
    hem = hem or [front + 8, front + 9, front + 9, front + 10, front + 9, front + 8]
    step = (db - da + 1) / len(hem)
    for k, hy in enumerate(hem):
        a = da + int(k * step)
        b = da + int((k + 1) * step) - 1
        c.rect(a, front + 1, b, hy, duvet_dk)
        c.hline(a, b, hy, shade(duvet_dk, 0.8))
    c.hline(da, db, front, duvet)
    for (rx, ry, ln) in ((da + 14, top + 4, 12), (da + 36, top + 7, 16), (da + 58, top + 3, 10)):
        if rx + ln < db:
            c.hline(rx, rx + ln, ry, duvet_lt)
            c.hline(rx + 2, rx + ln + 1, ry + 1, shade(duvet, 0.88))


# ============================================================================================
# B — teenager's room
# ============================================================================================
B_WALL = hexc('5e7f86')


def b_wall(c):
    F.wall_plain(c, B_WALL, hexc('4a656b'), hexc('d8d2c2'), texture=hexc('587880'))
    # decay: a scuffed patch where a poster was ripped down, blu-tack marks
    c.rect(150, 28, 170, 50, shade(B_WALL, 1.06))
    for (x, y) in ((150, 28), (170, 28), (150, 50), (170, 50)):
        c.put(x, y, hexc('7aa0c8'))


def b_decor(c):
    F.poster(c, 8, 18, 42, 48, hexc('1e1e24'), hexc('a8322c'), hexc('d8cfb4'))          # band poster
    F.poster(c, 102, 22, 128, 58, hexc('d9c24a'), hexc('2f4a63'), hexc('1e1e24'), torn=True)
    F.poster(c, 186, 24, 212, 54, hexc('7a3a6a'), hexc('d98a4a'), hexc('d8cfb4'))
    F.poster(c, 278, 20, 308, 44, hexc('26262a'), hexc('4e8a5a'), hexc('c9c2b1'))
    c.line(172, 60, 180, 58, hexc('1e1e24'))                                             # a scrawl
    c.line(180, 58, 176, 64, hexc('1e1e24'))


def b_floor(c):
    F.floor_carpet(c, hexc('5a5f7a'), hexc('6a6f8a'), hexc('4a4f68'), worn=hexc('70748e'))


def b_furniture(c):
    # the desk against the wall (x < 50): an old CRT monitor, a keyboard, cans
    c.shadow(27, 100, 22, 2, 100)
    c.rect(6, 72, 48, 74, F.PINE[1])
    c.hline(6, 48, 72, F.PINE[3])
    c.box(8, 75, 20, 99, F.PINE[0], F.PINE[3])
    for (d0, d1) in ((77, 84), (86, 93)):
        c.box(10, d0, 18, d1, F.PINE[0], F.PINE[2])
        c.put(14, (d0 + d1) // 2, F.BRASS)
    c.rect(44, 75, 46, 99, F.PINE[2])
    c.box(16, 52, 38, 70, hexc('c9c2b1'), hexc('6d6a60'))                                  # CRT
    c.rect(19, 55, 35, 66, hexc('22302c'))
    c.rect(21, 57, 25, 58, hexc('3e524b'))
    c.rect(22, 70, 32, 71, hexc('a9a496'))
    c.rect(14, 69, 36, 71, hexc('d8d2c2'))                                                 # keyboard
    c.rect(40, 67, 42, 71, hexc('b0453a')); c.rect(44, 68, 46, 71, hexc('4e8a5a'))          # cans
    # a gaming chair pulled out, turned away
    c.shadow(40, 119, 10, 2, 110)
    c.box(32, 86, 48, 104, hexc('26262a'), hexc('111114'))
    c.rect(34, 88, 46, 90, hexc('a8322c'))
    c.rect(30, 104, 50, 108, hexc('26262a'))
    c.vline(40, 109, 116, hexc('3a3a3d'))
    c.line(40, 116, 32, 119, hexc('3a3a3d')); c.line(40, 116, 48, 119, hexc('3a3a3d'))
    # a clothes pile + trainers out on the carpet
    c.poly([(60, 118), (68, 110), (80, 108), (90, 112), (94, 119)], CLOTH[1])
    c.poly([(66, 118), (74, 112), (84, 114), (86, 120)], CLOTH[5])
    c.line(70, 113, 82, 117, shade(CLOTH[1], 0.8))
    c.rect(96, 116, 104, 119, hexc('e0dcd0')); c.hline(96, 104, 119, hexc('a8322c'))
    # a beanbag slumped in the middle of the room
    c.shadow(128, 121, 16, 2, 110)
    c.poly([(112, 121), (113, 110), (120, 102), (132, 100), (142, 106), (146, 115), (144, 121)], hexc('a8522c'))
    c.poly([(116, 112), (124, 104), (132, 103), (126, 110)], shade(hexc('a8522c'), 1.15))
    c.line(118, 118, 140, 118, shade(hexc('a8522c'), 0.8))
    c.rect(128, 110, 134, 113, hexc('3a3a3d'))                                             # a controller on it
    # the single bed on the RIGHT: headboard at the right end
    x0, x1 = 166, 286
    c.shadow((x0 + x1) // 2, 116, (x1 - x0) // 2 + 3, 3, 110)
    c.box(x1 - 6, 70, x1 + 2, 114, F.PINE[0], F.PINE[3])                                   # headboard
    c.vline(x1 - 5, 71, 113, F.PINE[1])
    c.rect(x0, 104, x1 - 6, 109, F.PINE[0])
    c.hline(x0, x1 - 6, 104, F.PINE[1])
    c.hline(x0, x1 - 6, 109, F.PINE[3])
    for lx in (x0 + 2, x1 - 10):
        c.rect(lx, 110, lx + 2, 114, F.PINE[3])
    duvet = hexc('2f3a63')
    mattress_top(c, x0, x1 - 7, 86, 97, duvet, hexc('252e50'), hexc('3f4c7a'), pillow_at_right=True)
    for (sx, sy) in ((176, 90), (190, 94), (204, 89), (218, 95), (232, 91), (184, 101), (212, 103)):
        c.put(sx, sy, hexc('d9c24a'))                                                       # stars
    c.box(206, 108, 226, 113, hexc('d9d0bc'), hexc('8a8270'))                               # a shoebox under it
    c.rect(210, 110, 214, 111, hexc('a8322c'))
    # a crate as a bedside table in the corner: a lava lamp, an alarm clock
    c.shadow(301, 100, 10, 2, 90)
    c.box(292, 82, 310, 99, hexc('9a7a4e'), hexc('5e4a2e'))
    for gy in (86, 91, 96):
        c.hline(293, 309, gy, hexc('7c6140'))
    c.poly([(296, 81), (300, 66), (304, 81)], hexc('7a3a6a'))
    c.ellipse(300, 74, 2, 3, hexc('d98a4a')); c.ellipse(299, 78, 1, 1, hexc('d98a4a'))
    c.box(304, 76, 309, 81, hexc('26262a'), hexc('111114'))
    c.put(306, 78, hexc('c0453a'))


B_ANCHORS = [('anchor_bedroom_desk', 28, 70, 'bp'), ('anchor_bedroom_desk_drawer', 14, 88, 'bp'),
             ('anchor_bedroom_clothes_pile', 78, 113, ''), ('anchor_bedroom_beanbag', 130, 109, ''),
             ('anchor_bed_pillow', 266, 88, ''), ('anchor_floor_underbed', 216, 110, ''),
             ('anchor_bedroom_crate', 301, 90, 'bp')]


# ============================================================================================
# C — the sick room
# ============================================================================================
C_PAPER = hexc('b3a88a')


def c_wall(c):
    F.wall_plain(c, C_PAPER, hexc('8a8068'), hexc('5e4a3a'), rail=hexc('7a6048'), rail_y=16)
    F.wall_motif(c, hexc('a0957a'), hexc('8a6a5a'))
    # decay: a brown damp tide mark, the paper yellowed behind where the bed stood
    for i in range(6):
        c.ellipse(26 + i * 6, 20 + (i % 2) * 3, 8, 5, hexc('7a6a4a', 55))


def c_decor(c):
    F.frame_pic(c, 146, 30, 174, 52, hexc('6b4a2c'), hexc('9c9282'))                       # wedding photo
    c.rect(154, 38, 158, 50, hexc('d8d0c0')); c.rect(162, 37, 166, 50, hexc('3a3430'))
    c.box(196, 26, 208, 40, hexc('6b4a2c'), hexc('3b2718'))                                # a little sampler
    c.rect(198, 28, 206, 38, hexc('d9d0bc'))
    for y in range(30, 38, 2):
        c.hline(199, 205, y, hexc('a0505a'))


def c_floor(c):
    F.floor_planks(c, [hexc('6b4f3a'), hexc('634835'), hexc('705440')], hexc('3f2d20'))


def iron_bed(c, x0, x1, base):
    iron, knob = hexc('2e2c2a'), F.BRASS
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 4, 3, 110)
    # head (left, tall) + foot (right, lower) frames: posts, rails, spindles
    for (fx, top) in ((x0, 70), (x1 - 3, 80)):
        c.rect(fx, top, fx + 2, base, iron)
        c.ellipse(fx + 1, top - 1, 2, 2, knob)
    c.hline(x0, x0 + 14, 74, iron)
    c.hline(x0, x0 + 14, 84, iron)
    for sx in range(x0 + 4, x0 + 14, 3):
        c.vline(sx, 74, 84, iron)
    c.vline(x0 + 14, 72, base, iron)
    c.ellipse(x0 + 14, 71, 1, 1, knob)
    c.hline(x1 - 14, x1, 84, iron)
    for sx in range(x1 - 12, x1, 3):
        c.vline(sx, 84, 92, iron)
    c.vline(x1 - 14, 82, base, iron)
    c.ellipse(x1 - 14, 81, 1, 1, knob)
    # the mattress + a patchwork quilt
    mattress_top(c, x0 + 3, x1 - 15, 88, 98, hexc('8a6a5a'), hexc('6e5446'), hexc('a0806e'))
    for (qx, qy, col) in ((142, 90, hexc('a0505a')), (164, 93, hexc('5e6f58')), (186, 90, hexc('c9a06a')),
                          (152, 95, hexc('5e6f78')), (176, 96, hexc('a0505a')), (198, 94, hexc('5e6f58'))):
        c.rect(qx, qy, qx + 7, qy + 2, col)
    c.rect(x0 + 3, 104, x1 - 15, 107, iron)                                                # side rail
    c.ellipse(118, 92, 3, 1, BLOOD)
    c.line(116, 96, 117, 104, BLOOD)


def drip_stand(c, x, base):
    c.shadow(x, base, 6, 1, 90)
    c.vline(x, 34, base - 2, hexc('9aa3a8'))
    c.hline(x - 5, x + 5, base - 1, hexc('9aa3a8'))
    c.hline(x - 4, x + 4, 34, hexc('9aa3a8'))
    c.poly([(x - 4, 35), (x, 35), (x, 46), (x - 2, 48), (x - 4, 46)], hexc('d6e2e0', 200))  # the bag
    c.rect(x - 3, 40, x - 1, 45, hexc('a8322c', 160))
    c.line(x - 2, 48, x + 8, 92, hexc('c9d0d4'))                                           # the line


def wheelchair(c, x0, base):
    """Side-on, facing left: the big wheel, a front caster, the seat with a blanket, the back and
    push handles, a footrest."""
    frame, tyre = hexc('8a9094'), hexc('26262a')
    c.shadow(x0 + 16, base, 18, 2, 110)
    cx, cy, r = x0 + 20, base - 11, 11
    for yy in range(cy - r, cy + r + 1):                                                    # the tyre: a ring
        for xx in range(cx - r, cx + r + 1):
            d2 = (xx - cx) ** 2 + (yy - cy) ** 2
            if (r - 2) ** 2 < d2 <= r * r:
                c.put(xx, yy, tyre)
            elif (r - 3) ** 2 < d2 <= (r - 2) ** 2:
                c.put(xx, yy, frame)
    for (dx, dy) in ((0, -9), (8, -4), (8, 4), (0, 9), (-8, 4), (-8, -4)):
        c.line(cx, cy, cx + dx, cy + dy, frame)
    c.ellipse(cx, cy, 2, 2, frame)
    c.ellipse(x0 + 3, base - 3, 3, 3, tyre)                                                # caster
    c.line(x0 + 3, base - 6, x0 + 8, base - 16, frame)
    c.rect(x0 + 6, base - 20, x0 + 26, base - 18, hexc('3a3a3d'))                          # seat
    c.rect(x0 + 24, base - 36, x0 + 26, base - 18, frame)                                  # back post
    c.rect(x0 + 26, base - 36, x0 + 30, base - 35, frame)                                  # handle
    c.rect(x0 + 23, base - 34, x0 + 25, base - 21, hexc('3a3a3d'))
    c.line(x0 + 6, base - 18, x0 + 1, base - 8, frame)                                     # footrest
    c.hline(x0 - 1, x0 + 3, base - 8, frame)
    c.poly([(x0 + 6, base - 22), (x0 + 22, base - 24), (x0 + 24, base - 18), (x0 + 12, base - 10), (x0 + 5, base - 14)], hexc('7a5a8a'))


def med_trolley(c, x0, base):
    x1 = x0 + 30
    c.shadow(x0 + 15, base, 16, 2, 110)
    for lx in (x0 + 1, x1 - 1):
        c.vline(lx, base - 28, base - 2, hexc('9aa3a8'))
        c.ellipse(lx, base - 1, 1, 1, hexc('26262a'))
    for sy in (base - 28, base - 12):
        c.rect(x0, sy, x1, sy + 1, hexc('c9d0d4'))
    c.ellipse(x0 + 9, base - 30, 7, 2, hexc('d6d2c4'))                                     # a basin
    c.ellipse(x0 + 9, base - 30, 5, 1, hexc('a9b8b8'))
    for (bx, col) in ((x0 + 19, hexc('c07a3a')), (x0 + 23, hexc('e0d9b8')), (x0 + 27, hexc('c07a3a'))):
        c.rect(bx, base - 34, bx + 2, base - 29, col)
    c.rect(x0 + 4, base - 17, x0 + 12, base - 13, hexc('d8d2c2'))                          # towels below
    c.rect(x0 + 16, base - 16, x0 + 26, base - 13, hexc('6e7f95'))


def c_furniture(c):
    # a tall wardrobe with a mirror door on the far left (x < 50)
    c.shadow(26, 100, 20, 2, 100)
    c.box(8, 26, 44, 99, F.WOOD[0], F.WOOD[3])
    c.rect(7, 23, 45, 26, F.WOOD[1])
    c.box(10, 30, 25, 94, F.WOOD[0], F.WOOD[2])
    c.box(27, 30, 42, 94, hexc('8b9aa0'), F.WOOD[2])
    c.line(30, 88, 39, 36, hexc('b8c3c4'))
    c.rect(24, 60, 25, 64, F.BRASS); c.rect(27, 60, 28, 64, F.BRASS)
    wheelchair(c, 58, 120)
    drip_stand(c, 104, 116)
    iron_bed(c, 108, 226, 116)
    # a bedside cabinet crowded with pill bottles (under the R window box, top >= 67)
    F.chest(c, 234, 258, 76, 100, F.WOOD, drawers=2)
    for (bx, h, col) in ((236, 6, hexc('c07a3a')), (240, 4, hexc('e0d9b8')), (244, 7, hexc('c07a3a')),
                         (248, 5, hexc('6f8fa0')), (252, 4, hexc('e0d9b8'))):
        c.rect(bx, 75 - h, bx + 2, 75, col)
    c.rect(254, 72, 257, 75, hexc('d9d0bc'))
    med_trolley(c, 276, 120)


C_ANCHORS = [('anchor_bedroom_wardrobe', 18, 60, 'bp'), ('anchor_bedroom_wheelchair', 72, 99, ''),
             ('anchor_bedroom_quilt', 170, 92, ''), ('anchor_bed_pillow', 124, 89, ''),
             ('anchor_bedroom_pill_cabinet', 246, 86, 'bp'), ('anchor_bedroom_med_trolley', 286, 90, '')]


# ============================================================================================
# D — squat
# ============================================================================================
D_PLASTER = hexc('a39a88')


def d_wall(c):
    F.wall_plain(c, D_PLASTER, hexc('7a7262'), hexc('6a6252'), texture=hexc('938a78'))
    for (sx, sy, rx, ry) in ((20, 16, 20, 12), (290, 70, 26, 18), (160, 8, 34, 6)):
        c.ellipse(sx, sy, rx, ry, hexc('6f6a52', 70))
    for pts in (((130, 6), (134, 16), (131, 26), (136, 38)), ((214, 70), (218, 80), (215, 90))):
        for a, b in zip(pts, pts[1:]):
            c.line(a[0], a[1], b[0], b[1], hexc('6a6252'))


def d_decor(c):
    # newspaper taped over the wall, a spray-painted tag, a tally scratched in the plaster
    for (x0, y0) in ((104, 30), (122, 34)):
        c.rect(x0, y0, x0 + 16, y0 + 22, hexc('cfc7b2'))
        for y in range(y0 + 3, y0 + 21, 2):
            c.hline(x0 + 2, x0 + 14 - (y % 5), y, hexc('8a8270'))
    c.line(150, 60, 160, 44, hexc('a8322c')); c.line(160, 44, 168, 60, hexc('a8322c'))
    c.line(164, 52, 176, 48, hexc('a8322c')); c.line(176, 48, 182, 58, hexc('a8322c'))
    for i in range(7):
        c.vline(192 + i * 3, 44, 52, hexc('5a5244'))
    c.line(190, 50, 212, 46, hexc('5a5244'))


def d_floor(c):
    F.floor_planks(c, [hexc('5a4a3a'), hexc('524334'), hexc('604f3e')], hexc('33281e'))


def d_furniture(c):
    # crates against the wall on the left: a camping stove, cans, candles
    c.shadow(28, 100, 22, 2, 100)
    for (cx0, cy0, col) in ((8, 80, hexc('9a7a4e')), (28, 80, hexc('8a6a44')), (16, 62, hexc('9a7a4e'))):
        c.box(cx0, cy0, cx0 + 18, cy0 + 17 if cy0 == 62 else 99, col, shade(col, 0.6))
        for gy in range(cy0 + 4, (cy0 + 17 if cy0 == 62 else 99), 5):
            c.hline(cx0 + 1, cx0 + 17, gy, shade(col, 0.8))
    c.box(20, 55, 32, 61, hexc('3a5a7a'), hexc('1e2e3e'))                                 # a stove
    c.rect(24, 53, 28, 54, hexc('6d6c64'))
    for (x, h) in ((10, 4), (14, 6), (38, 5)):
        c.rect(x, 79 - h, x + 2, 79, hexc('9aa3a8'))
    F.candle(c, 44, 79, 6)
    c.dither(40, 70, 48, 73, hexc('2a2622', 60), 0.5)
    # a backpack slumped out on the floor
    c.shadow(70, 121, 10, 2, 110)
    c.poly([(60, 121), (61, 106), (66, 100), (76, 100), (80, 106), (80, 121)], hexc('4a5a3a'))
    c.rect(62, 110, 78, 116, hexc('3a4a2e'))
    c.line(64, 102, 64, 108, hexc('2e3a24')); c.line(76, 102, 76, 108, hexc('2e3a24'))
    c.rect(68, 99, 72, 101, hexc('2e3a24'))
    # the mattress on the floor, a sleeping bag half off it
    x0, x1 = 100, 204
    c.shadow((x0 + x1) // 2, 117, (x1 - x0) // 2 + 3, 2, 110)
    c.rect(x0, 104, x1, 110, hexc('c9c0a8'))
    c.hline(x0, x1, 104, hexc('a89f88'))
    c.rect(x0, 111, x1, 116, hexc('a89f88'))
    c.hline(x0, x1, 116, hexc('6a6252'))
    for x in range(x0 + 6, x1, 12):
        c.put(x, 113, hexc('8a8270'))
    c.dither(150, 105, 180, 109, hexc('8a7a52', 80), 0.5, pattern='random')              # a stain
    rrect(c, x0 + 3, 101, x0 + 22, 107, PILLOW, 2)
    c.poly([(x0 + 26, 103), (x1 - 12, 102), (x1 + 6, 110), (x1 + 4, 119), (x0 + 30, 114)], hexc('3a5a7a'))
    c.line(x0 + 30, 108, x1 - 4, 108, hexc('2a4460'))
    c.line(x0 + 30, 111, x1 + 2, 113, hexc('2a4460'))
    c.rect(x1 - 30, 104, x1 - 28, 106, hexc('c0453a'))                                    # zip pull
    # a freestanding clothes rail on castors, out in the room (below the R window box)
    rx0, rx1, rtop, rbase = 222, 266, 70, 118
    c.shadow((rx0 + rx1) // 2, rbase, 24, 2, 110)
    c.vline(rx0, rtop, rbase - 2, hexc('9aa3a8'))
    c.vline(rx1, rtop, rbase - 2, hexc('9aa3a8'))
    c.hline(rx0, rx1, rtop, hexc('9aa3a8'))
    c.hline(rx0 - 3, rx0 + 3, rbase - 1, hexc('9aa3a8')); c.hline(rx1 - 3, rx1 + 3, rbase - 1, hexc('9aa3a8'))
    for (hx, col, ln) in ((228, CLOTH[0], 26), (238, CLOTH[3], 34), (248, CLOTH[5], 22), (257, CLOTH[1], 30)):
        c.line(hx, rtop + 1, hx - 3, rtop + 4, hexc('6d6c64'))
        c.line(hx, rtop + 1, hx + 3, rtop + 4, hexc('6d6c64'))
        c.poly([(hx - 4, rtop + 4), (hx + 4, rtop + 4), (hx + 5, rtop + 4 + ln), (hx - 5, rtop + 4 + ln)], col)
        c.vline(hx, rtop + 6, rtop + 3 + ln, shade(col, 0.8))
    # boxes stacked against the wall, right corner
    F.cardboard_box(c, 276, 308, 78, 99, open_flaps=False)
    F.cardboard_box(c, 282, 304, 62, 77, open_flaps=True, label=False)


D_ANCHORS = [('anchor_bedroom_crates', 26, 70, 'bp'), ('anchor_bedroom_backpack', 70, 108, ''),
             ('anchor_bed_pillow', 112, 104, ''), ('anchor_bedroom_sleeping_bag', 170, 108, ''),
             ('anchor_bedroom_clothes_rail', 238, 96, ''), ('anchor_bedroom_boxes', 292, 86, 'bp')]


# ============================================================================================
# E — a child's room
# ============================================================================================
E_WALL = hexc('b9c9d6')


def e_wall(c):
    F.wall_plain(c, E_WALL, hexc('8a9aa6'), hexc('e0dcd0'))
    for y in range(22, 60, 16):                                                  # a duck frieze... in rows
        off = 0 if ((y - 22) // 16) % 2 == 0 else 12
        for x in range(off + 6, 320, 24):
            c.ellipse(x, y, 3, 2, hexc('e6d27a'))
            c.put(x + 3, y - 2, hexc('e6d27a')); c.put(x + 4, y - 2, hexc('d98a4a'))
    c.rect(0, 62, 319, 65, hexc('e6d27a'))                                       # a border strip
    for x in range(0, 320, 8):
        c.rect(x, 63, x + 3, 64, hexc('7aa0c8'))
    for i in range(5):
        c.ellipse(262 + i * 6, 16 + (i % 2) * 3, 8, 5, hexc('7a8a8a', 60))


def e_decor(c):
    # height marks pencilled up the door frame side of the wall, the last one much later
    for (y, w) in ((82, 6), (76, 6), (70, 6), (64, 6), (52, 8)):
        c.hline(100, 100 + w, y, hexc('4a4a4a'))
    c.line(104, 50, 110, 44, BLOOD)
    c.box(170, 24, 196, 46, hexc('e6e0cc'), hexc('8a8270'))                      # a crayon drawing
    c.line(174, 42, 180, 32, hexc('3a7a3a')); c.ellipse(186, 30, 3, 3, hexc('d9c24a'))
    for (x, col) in ((176, hexc('3a3a3a')), (182, hexc('3a3a3a')), (188, hexc('a8322c'))):
        c.vline(x, 36, 42, col); c.ellipse(x, 35, 1, 1, col)


def e_floor(c):
    F.floor_carpet(c, hexc('7a9ab0'), hexc('8aaac0'), hexc('6a8aa0'), worn=hexc('92b0c4'))


def e_furniture(c):
    # a dollhouse on a low table against the wall (x < 50)
    c.shadow(27, 100, 22, 2, 100)
    c.rect(8, 80, 46, 82, F.PINE[1]); c.rect(10, 83, 12, 99, F.PINE[2]); c.rect(42, 83, 44, 99, F.PINE[2])
    c.poly([(10, 58), (27, 44), (44, 58)], hexc('a8322c'))
    c.box(12, 58, 42, 79, hexc('e6e0cc'), hexc('8a8270'))
    c.rect(14, 60, 26, 68, hexc('7aa0c8')); c.rect(28, 60, 40, 68, hexc('d9a0b0'))
    c.rect(14, 70, 26, 78, hexc('d9c24a')); c.rect(28, 70, 40, 78, hexc('1e1a16'))           # one room dark
    c.rect(31, 73, 33, 77, hexc('e6ddc8'))                                                    # a tiny figure in it
    # a rocking horse out on the carpet
    c.shadow(76, 121, 14, 2, 110)
    for x in range(60, 95):                                                                   # the curved rocker
        y = 121 - int(((x - 77) / 17.0) ** 2 * 6)
        c.put(x, y, F.WOOD[0]); c.put(x, y - 1, F.WOOD[1])
    c.line(68, 119, 72, 106, F.WOOD[0]); c.line(86, 119, 82, 106, F.WOOD[0])
    rrect(c, 66, 98, 88, 107, hexc('e6e0cc'), 3)                                              # body
    c.poly([(84, 99), (92, 90), (96, 92), (90, 101)], hexc('e6e0cc'))                         # neck + head
    c.put(93, 92, hexc('1e1a16'))
    c.poly([(86, 98), (90, 90), (88, 98)], hexc('8a4a2a'))                                    # mane
    c.rect(72, 97, 78, 99, hexc('a8322c'))                                                    # saddle
    # a small bed with a teddy, pushed against the wall
    x0, x1 = 118, 196
    c.shadow((x0 + x1) // 2, 116, (x1 - x0) // 2 + 3, 3, 110)
    c.box(x0, 76, x0 + 6, 114, hexc('e6e0cc'), hexc('8a8270'))                               # white headboard
    c.box(x1 - 5, 84, x1, 114, hexc('e6e0cc'), hexc('8a8270'))
    c.rect(x0 + 6, 104, x1 - 5, 108, hexc('e6e0cc'))
    c.hline(x0 + 6, x1 - 5, 108, hexc('8a8270'))
    for lx in (x0 + 8, x1 - 9):
        c.rect(lx, 109, lx + 2, 114, hexc('8a8270'))
    mattress_top(c, x0 + 6, x1 - 6, 88, 97, hexc('d98aa0'), hexc('b86a80'), hexc('e8a8b8'))
    c.ellipse(134, 86, 5, 5, hexc('9a6a3a')); c.ellipse(130, 81, 2, 2, hexc('9a6a3a'))       # the teddy
    c.ellipse(138, 81, 2, 2, hexc('9a6a3a')); c.put(133, 85, hexc('1e1a16')); c.put(136, 85, hexc('1e1a16'))
    c.ellipse(134, 93, 4, 3, hexc('9a6a3a'))
    c.line(130, 94, 140, 90, BLOOD)
    # a toy chest out by the lane, lid up, toys spilling
    c.shadow(232, 121, 16, 2, 110)
    c.box(218, 106, 246, 121, hexc('7aa0c8'), hexc('3a5a78'))
    c.hline(219, 245, 107, hexc('9ac0e0'))
    c.poly([(218, 106), (246, 106), (244, 96), (220, 96)], hexc('5a80a8'))                    # the lid, open
    c.rect(222, 102, 228, 106, hexc('d9c24a')); c.ellipse(236, 104, 3, 3, hexc('a8322c'))
    c.rect(250, 118, 256, 121, hexc('4e8a5a')); c.ellipse(262, 119, 2, 2, hexc('d9c24a'))
    # a small white wardrobe in the corner
    c.shadow(292, 100, 16, 2, 100)
    c.box(278, 36, 306, 99, hexc('e6e0cc'), hexc('8a8270'))
    c.vline(292, 38, 97, hexc('b9b3a4'))
    c.rect(289, 64, 290, 68, hexc('d9c24a')); c.rect(294, 64, 295, 68, hexc('d9c24a'))
    c.poly([(278, 36), (306, 36), (304, 32), (280, 32)], hexc('d98aa0'))


E_ANCHORS = [('anchor_bedroom_dollhouse', 34, 74, 'bp'), ('anchor_bedroom_rocking_horse', 76, 102, ''),
             ('anchor_bed_pillow', 134, 88, ''), ('anchor_bedroom_toy_chest', 232, 112, ''),
             ('anchor_bedroom_small_wardrobe', 292, 70, 'bp')]


VARIANTS = {
    'b': ('bedroom_b', 22, (b_wall, b_decor, b_floor, b_furniture), B_ANCHORS),
    'c': ('bedroom_c', 23, (c_wall, c_decor, c_floor, c_furniture), C_ANCHORS),
    'd': ('bedroom_d', 24, (d_wall, d_decor, d_floor, d_furniture), D_ANCHORS),
    'e': ('bedroom_e', 25, (e_wall, e_decor, e_floor, e_furniture), E_ANCHORS),
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
        finish_module(name, 'bedroom', seed, bare, floor, build, anchors)
