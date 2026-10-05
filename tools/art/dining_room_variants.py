"""Dining room VARIANTS b-d (variant a is tools/art/dining_room.py). Same rules via
pixlib.finish_module. A dining room can hold the BALCONY doors (x 4..96): that strip's furniture goes
in strip() — hidden, with its nodes, on a balcony slot.

Run:  python3 tools/art/dining_room_variants.py [b c d]

  b  70s — a round tulip table + tulip chairs in 3D (one knocked over, dinner interrupted), sage trellis
     paper over a cream dado, parquet, a serving hatch, a white sideboard with a record player still
     turning; strip: a mustard drinks cabinet, a velvet pouffe (round 21c redraw).
  c  formal — a long table with a candelabra, high-backed chairs, a grandfather clock, a silver
     sideboard, portraits; strip: a glass-front china cabinet.
  d  barricaded — the table flipped on its side across the room as a barricade (something behind
     it), chairs stacked, planks, tins, blood; strip: a pile of broken chairs.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import persp
from pixlib import Canvas, hexc, shade, rrect, finish_module, setback
from pixlib import pp, _ip as _ipt
import furn as F
import chair3d as C3
import pixlib as PX
import party3d as P3

BLOOD = hexc('4a1d1b', 150)
BLOOD_DK = hexc('3a1512', 190)
PLATE = hexc('e8e4d8')
PLATE_DK = hexc('c3beb0')
SILVER = hexc('b9bfc1')


# ============================================================================================
# B — 70s round table
# ============================================================================================
SAGE, SAGE_LT, SAGE_DK = hexc('7d9e94'), hexc('93b3a8'), hexc('5f8276')
CREAM, CREAM_DK = hexc('e8e0cc'), hexc('c9bfa6')
LACQUER = (hexc('e4ddcc'), hexc('f2ede2'), hexc('bdb4a0'), hexc('6a6252'))     # a white-lacquered sideboard
TULIP = {'shell': hexc('eee8da'), 'fab': hexc('d9662e'), 'top': hexc('f2eee4')}
MUSTARD = hexc('d6a540')


def b_wall(c):
    # (owner round 21c: the old brown dots "incredibly bland… how brown it all is") a sage trellis
    # paper above a picture rail, cream panelled dado below — a bright 70s room someone liked
    F.wall_plain(c, SAGE, CREAM, hexc('e2dac6'), rail=hexc('efe8d6'), rail_y=18, dado=CREAM, dado_y=62)
    for y in range(21, 61):
        for x in range(320):
            if (x + y) % 12 == 0 or (x - y) % 12 == 0:
                c.put(x, y, SAGE_LT)
    for y in range(21 + 5, 61, 12):                                    # a leaf where the lattice crosses
        for x in range((y - 21 + 1) % 12, 320, 12):
            if (x + y) % 12 == 0 and (x - y) % 12 == 0:
                for (dx, dy) in ((-1, 0), (1, 0), (0, -1)):
                    c.put(x + dx, y + dy, SAGE_DK)
                c.put(x, y, hexc('efe6c8'))
    for x0 in range(2, 320, 40):                                       # the dado's panels
        c.rect(x0 + 2, 68, x0 + 34, 69, shade(CREAM, 1.06))
        c.rect(x0 + 2, 68, x0 + 3, 90, shade(CREAM, 1.06))
        c.hline(x0 + 2, x0 + 34, 90, CREAM_DK)
        c.vline(x0 + 34, 68, 90, CREAM_DK)


def b_decor(c):
    # a framed geometric print + a snapshot of the family who ate here
    c.box(104, 24, 138, 54, hexc('e8e2d2'), hexc('3a3a3a'))
    c.rect(107, 27, 135, 51, hexc('f4f0e4'))
    c.rect(109, 29, 121, 49, hexc('d9662e'))
    c.rect(123, 29, 133, 38, hexc('2f6a6a'))
    c.rect(123, 40, 133, 49, MUSTARD)
    c.ellipse(115, 39, 4, 4, hexc('f4f0e4'))
    F.photo(c, 145, 30, 161, 44, [(hexc('e0c0a0'), hexc('3a2a1e'), hexc('d9662e'), 9), (hexc('d8b89a'), hexc('6a4a2a'), hexc('2f6a6a'), 10),
                                  (hexc('e8c8a8'), hexc('b08a50'), hexc('e8b83a'), 6)], frame=hexc('3a2718'))
    # the serving hatch to the kitchen: folding louvred doors open onto the dim kitchen beyond
    c.box(168, 28, 216, 62, hexc('efe8d6'), hexc('7a7262'))
    c.rect(170, 30, 214, 60, hexc('2e2c26'))
    c.rect(170, 30, 214, 32, hexc('1e1c18'))
    c.hline(183, 201, 42, hexc('4a4034'))                                                     # a shelf of jars
    for (jx, col) in ((185, hexc('5a5a44')), (189, hexc('6a4a34')), (193, hexc('4a5448')), (198, hexc('5a4a3a'))):
        c.rect(jx, 37, jx + 2, 41, col)
    c.vline(196, 44, 47, hexc('4a4a48')); c.ellipse(196, 50, 3, 3, hexc('3e3e3c'))           # a pan on a hook
    c.rect(170, 55, 214, 57, hexc('3a362e'))
    c.rect(168, 58, 216, 62, hexc('f2ede2'))                                                 # its sill
    c.hline(168, 216, 62, hexc('bdb4a0'))
    for (d0, d1) in ((171, 181), (203, 213)):
        c.rect(d0, 31, d1, 57, hexc('efe8d6'))
        for y in range(33, 56, 3):
            c.hline(d0 + 1, d1 - 1, y, hexc('c9bfa6'))
    c.rect(186, 52, 192, 57, PLATE)                                                           # a plate left on the sill
    c.put(191, 51, hexc('d9662e'))
    # a sunburst clock over the sideboard, stopped
    for k in range(16):
        import math
        a = 2 * math.pi * k / 16
        c.line(292, 36, 292 + int(round(math.cos(a) * (9 if k % 2 else 12))), 36 + int(round(math.sin(a) * (9 if k % 2 else 12))), hexc('c9a24a'))
    c.ellipse(292, 36, 4, 4, hexc('f4f0e4'))
    c.line(292, 36, 292, 33, hexc('2a2622')); c.line(292, 36, 295, 37, hexc('2a2622'))


@persp
def b_floor(c):
    # honey-oak parquet, basket-woven in 16px blocks (repeats every 32)
    rows = [101, 104, 108, 113, 119, 126, 134, 144]
    oak, oak2, seam = hexc('c89a62'), hexc('b88852'), hexc('8a6238')
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for bx in range(0, 320, 16):
            flip = ((bx // 16) + r) % 2
            col = oak if flip else oak2
            c.rect(bx, y0, bx + 15, y1, col)
            if flip:
                for x in range(bx + 4, bx + 16, 4):
                    c.vline(x, y0 + 1, y1, shade(col, 0.9))
            else:
                for y in range(y0 + 1, y1, max(2, (y1 - y0) // 3)):
                    c.hline(bx + 1, bx + 15, y, shade(col, 0.9))
            c.vline(bx, y0, y1, seam)
        c.hline(0, 319, y0, shade(oak, 1.08))
        c.hline(0, 319, y1, seam)
    c.hline(0, 319, 100, shade(oak2, 0.5))
    c.dither(0, 101, 319, 102, hexc('1f1812', 90), 0.5)


def b_strip(c):
    setback(c, lambda l: F.moved(l, _drinks, -3, 0), depth=4, top=62, x_range=(5, 45), rake=1.0)
    _pouffe_at(c)


def _drinks(c):
    # a mustard-lacquered drinks cabinet, its flap down, bottles inside
    out = hexc('6a4a18')
    c.shadow(28, 100, 20, 2, 100)
    c.box(10, 62, 46, 99, MUSTARD, out)
    c.hline(11, 45, 63, shade(MUSTARD, 1.15))
    c.rect(12, 64, 44, 80, hexc('2a1d14'))
    for (x, h, col) in ((14, 12, hexc('3a5a3a')), (20, 10, hexc('7a4a2a')), (26, 13, hexc('c9c2b1')), (34, 11, hexc('5a1a22'))):
        c.rect(x, 80 - h, x + 3, 79, col)
        c.rect(x + 1, 80 - h - 3, x + 2, 80 - h - 1, col)
    c.rect(38, 76, 39, 79, hexc('d8e0e0'))                                                   # a tumbler
    c.box(12, 82, 44, 97, MUSTARD, shade(MUSTARD, 0.7))
    c.rect(26, 88, 30, 88, F.BRASS)
    c.poly([(12, 80), (44, 80), (48, 84), (8, 84)], shade(MUSTARD, 1.1))                     # the drop flap


def _pouffe_at(c):
    # a round velvet pouffe beside the cabinet (real 3D, like the chairs)
    m = C3.Model()
    C3.prism(m, 0, 0, 9.0, 0, 9.5, 'pouffe', 'fab', 18)
    C3.draw_model(c, 62, 106, m, 0, {'fab': hexc('2f6a6a')}, srad=10)
    for x in (58, 62, 66):
        c.put(x, 96, hexc('1f4a4a'))                                                          # its buttons


def b_furniture(c):
    # the round tulip table + chairs, rendered in 3D (owner round 21c — "flat and small"): one chair
    # pulled round behind, one on the left, one knocked over on its side — dinner didn't finish
    cx, base = 158, 118
    C3.draw_model(c, cx, 105, C3.tulip_chair(), 0, TULIP, srad=9)                              # behind the table
    C3.draw_model(c, cx, base, C3.tulip_table(), 0, TULIP, srad=26)
    C3.draw_model(c, 110, 121, C3.tulip_chair(), -62, TULIP, srad=9)                          # at its left
    fallen = C3.fall(C3.tulip_chair(), 'side', 8.0)
    C3.draw_model(c, 212, 128, fallen, 35, TULIP, shadow='footprint')                         # knocked over
    # what was on the table: two places laid, a vase of tulips going over, a glass knocked down,
    # the wine running off the edge
    top = base - 24
    for (px, py) in ((142, top - 1), (172, top + 1)):
        c.ellipse(px, py, 6, 1.6, PLATE_DK); c.ellipse(px, py, 5, 1.1, PLATE)
    c.ellipse(172, top + 1, 2, 0.8, hexc('b0653a'))                                          # food left on it
    c.line(135, top + 1, 137, top - 1, SILVER); c.line(149, top + 1, 150, top - 2, SILVER)      # cutlery
    c.rect(156, top - 7, 160, top - 1, hexc('b8d0d0')); c.hline(156, 160, top - 7, hexc('dfeeee'))   # the vase
    for (dx, dy, col) in ((-4, -12, hexc('d9662e')), (0, -14, hexc('e8b83a')), (4, -11, hexc('c0453a')), (6, -8, hexc('d9662e'))):
        c.line(158, top - 7, 158 + dx, top - 7 + dy + 3, hexc('4d6a3c'))
        c.ellipse(158 + dx + (1 if dx > 0 else -1 if dx < 0 else 0), top - 7 + dy + 2, 1.5, 1.5, col)   # tulips, drooping
    c.put(165, top - 1, hexc('d9662e')); c.put(163, top, hexc('c0453a'))                     # dropped petals
    c.line(178, top - 3, 184, top - 2, hexc('d8e0e0')); c.put(185, top - 2, hexc('d8e0e0'))    # a wine glass on its side
    c.ellipse(186, top + 1, 5, 1, hexc('6a1a22'))                                             # its wine, spreading
    c.vline(181, top + 3, top + 5, hexc('6a1a22'))
    PX.anim(181, top + 5, 'drip', 22, color='6a1a22')                                         # still dripping
    c.ellipse(181, base + 5, 4, 1, hexc('5a1a22'))                                            # a puddle below
    # a plate smashed on the floor by the fallen chair, a napkin dropped
    for (sx, sy) in ((196, 131), (199, 133), (193, 134), (202, 130), (190, 132)):
        c.rect(sx, sy, sx + 1, sy, PLATE); c.put(sx + 2, sy, PLATE_DK)
    c.poly([(226, 134), (234, 133), (236, 136), (227, 137)], hexc('f4efe2'))
    c.hline(227, 235, 136, hexc('d8d0bc'))
    # a white-lacquered sideboard with a record player on the right (with depth)
    def _sb(c):
        F.chest(c, 244, 310, 72, 100, LACQUER, drawers=2, open_row=1)
        c.rect(243, 72, 311, 73, hexc('b07a4a'))                                               # its teak top
        c.ellipse(257, 70, 6, 1.8, hexc('d86a3a')); c.ellipse(257, 69, 5, 1, hexc('f0a060'))
        for (fx, col) in ((255, hexc('e8b83a')), (258, hexc('6a9a3a')), (260, hexc('b0453a'))):
            c.ellipse(fx, 68, 1.5, 1.2, col)
        for i, col in enumerate((hexc('2f4a63'), hexc('d9c24a'), hexc('c0453a'))):
            c.rect(264 + i, 70 - i, 271 + i, 70 - i, col)
        for y in range(56, 66):                                                               # the lid, open
            for x in range(273 + (65 - y) // 4, 294 - (65 - y) // 4):
                c.put(x, y, hexc('5a5a60', 90))
        c.hline(273, 293, 65, hexc('3a3a40'))
        c.rect(272, 66, 294, 71, F.TEAK[0]); c.hline(272, 294, 66, F.TEAK[1])
        c.hline(272, 294, 71, F.TEAK[3])
        c.rect(273, 67, 293, 68, hexc('b9bfc1'))
        c.ellipse(281, 67, 7.5, 2, hexc('1c1c1e'))
        c.ellipse(281, 67, 5, 1.2, hexc('2a2a2e'))
        c.ellipse(281, 67, 1.6, 0.8, hexc('c0453a'))
        PX.anim(281, 67, 'spin', color='8a8a94', w=6, h=1)
        c.put(292, 67, SILVER); c.line(292, 67, 285, 68, SILVER)
        c.rect(289, 69, 291, 70, hexc('d9c24a'))
        for (x, col) in ((299, hexc('d86a3a')), (302, hexc('2f4a63')), (305, hexc('d9c24a'))):
            c.rect(x, 58, x + 2, 71, col)
    setback(c, _sb, depth=4, top=72, x_range=(243, 311))
    F.potted_plant(c, 232, 99)                                                               # a plant by the sideboard
    F.pendant(c, cx, 22, 'orange', dome=True)                                                # a 70s dome pendant

B_ANCHORS = [('anchor_dining_drinks_cabinet', 23, 72, 'bp s'), ('anchor_dining_pouffe', 62, 97, 's'),
             ('anchor_table_left', 142, 93, ''), ('anchor_table_right', 172, 95, ''),
             ('anchor_dining_tulip_chair', 110, 105, ''), ('anchor_dining_record_player', 281, 67, 'bp'),
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
    # three generations in oils (round 17: blank ovals read as nothing): grandfather, grandmother —
    # her canvas slashed — and their son
    gilt = hexc('b58f4a')
    for (x0, x1, sitter, bg, hair) in ((134, 156, 'old', hexc('4a4a3a'), hexc('c9c4bc')),
                                       (166, 188, 'woman', hexc('3e4a4a'), hexc('5a3a26')),
                                       (198, 220, 'man', hexc('4a3e34'), hexc('2a1e16'))):
        F.portrait(c, x0 + 2, 26, x1 - 2, 50, sitter=sitter, bg=bg, hair=hair, frame=gilt)
        mx = (x0 + x1) // 2
        c.line(x0 + 3, 24, mx, 18, shade(gilt, 0.55)); c.line(x1 - 3, 24, mx, 18, shade(gilt, 0.55))
    c.line(170, 30, 184, 48, hexc('1e1a16'))                                                  # one slashed
    c.line(171, 30, 185, 48, hexc('8a7a5a'))                                                  # the torn canvas edge


@persp
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
    # the china cabinet with depth (owner round 14), 3px left of where it stood flat (clear of window L)
    setback(c, lambda l: F.moved(l, _china, -3, 0), depth=4, top=27, x_range=(4, 44), rake=1.0)


def _china(c):
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
    setback(c, lambda l: grandfather_clock(l, 104, 100), depth=3, rake=1.0)
    # the long table, high-backed chairs behind it, a candelabra
    HIGH = {'wood': hexc('4a2c1c'), 'seat': hexc('5a3622'), 'fab': hexc('6a2a2e')}
    for (x, yaw) in ((148, 180), (178, 180)):                                                # high-backs, backs to us
        C3.draw_model(c, x, 100, C3.dining_chair('high'), yaw, HIGH, srad=10)
    C3.draw_model(c, 276, 128, C3.fall(C3.dining_chair('high'), 'side', -8.0), -30, HIGH, shadow='footprint')   # the third, knocked flying — CLEAR of the table's legs (owner round 34)
    F.table_front(c, 126, 236, 92, 120, F.WOOD, depth=6)
    c.rect(125, 92, 237, 98, F.WOOD[1])
    c.hline(125, 237, 92, F.WOOD[3])
    c.rect(150, 91, 210, 93, hexc('d6d0bf'))                                                 # a runner
    c.line(207, 93, 211, 95, hexc('d6d0bf'))                                                 # dragged askew at one end
    cx = 180                                                                                  # the candelabra
    c.rect(cx - 3, 88, cx + 3, 90, SILVER)
    c.vline(cx, 76, 88, SILVER)
    c.hline(cx - 10, cx + 10, 80, SILVER)
    for dx in (-10, 0, 10):
        c.vline(cx + dx, 76, 80, SILVER)
    F.candle(c, cx - 10, 75, 5)                                                               # burnt down unevenly,
    F.candle(c, cx, 75, 2)                                                                    # one guttered to a stub
    c.put(cx + 10, 75, hexc('d8cfb4')); c.put(cx + 11, 76, hexc('d8cfb4'))                   # the third knocked out —
    c.rect(186, 89, 191, 90, hexc('e3dcc6')); c.put(192, 89, hexc('3a2a1a'))                 # — lying on the runner
    c.hline(186, 191, 90, hexc('c8bfa6'))
    # a DINNER LEFT MID-MEAL (owner round 20: "a broken cup and a puddle… says way more than four
    # generic cups in a row"): one plate still served, one shoved back, a chair's place bare, a wine
    # glass knocked over — the wine runs to the edge and still drips to the floor
    def plate(px, py, food=False):
        c.ellipse(px, py, 6, 1.4, PLATE_DK); c.ellipse(px, py - 0.3, 5, 1, PLATE)
        c.ellipse(px, py - 0.3, 3, 0.6, shade(PLATE, 0.9))
        if food:
            c.ellipse(px - 1, py - 1, 2.2, 0.9, hexc('7a4a2a')); c.put(px + 2, py - 1, hexc('5e8240'))
            c.put(px + 1, py - 1, hexc('5e8240')); c.put(px - 2, py - 2, hexc('9a6a3a'))
    plate(141, 95, food=True)
    c.line(134, 96, 136, 93, SILVER); c.line(147, 97, 150, 95, SILVER)                       # its knife + fork, put down
    plate(163, 93)                                                                            # shoved back, empty
    c.line(157, 97, 161, 97, SILVER)
    plate(223, 96, food=True)
    c.ellipse(212, 96, 3, 0.8, BLOOD)                                                         # someone bled here
    c.put(215, 97, BLOOD)
    wine, wine_lt = hexc('6a1620'), hexc('9a2e36')
    c.ellipse(199, 96, 5, 1.2, wine); c.ellipse(196, 97, 3, 1, wine)                          # the spill, to the edge
    c.rect(193, 97, 196, 98, wine); c.put(197, 95, wine_lt); c.put(201, 96, wine_lt)
    c.vline(194, 99, 101, wine); c.vline(195, 99, 100, shade(wine, 0.8))                     # down the apron
    c.line(200, 95, 205, 94, hexc('d8e2e4')); c.put(205, 93, hexc('eef4f4'))                  # the glass on its side
    c.vline(206, 92, 95, hexc('b8c8cc')); c.put(199, 95, hexc('c8d4d6'))                      # its foot, its rim
    PX.anim(194, 101, 'drip', fall=15, color='7a1c26')
    c.ellipse(194, 117, 3, 0.8, wine); c.put(193, 117, wine_lt)                               # the drip's pool below
    # a sideboard with the TEA SET — someone was pouring when it happened (round 20: it stood in a
    # tidy row): the tray pushed askew, the teapot's lid off beside it, one cup still on its saucer,
    # the sugar bowl tipped, the other cup on its side in its own spill (added after the setback, on
    # the top face) and its twin smashed on the floor
    def _sb(c):
        F.chest(c, 250, 310, 72, 100, F.WOOD, drawers=2)
        F.silver(c, 'cup', 265, 71, hexc('e6ddc8'))
        c.line(268, 71, 271, 70, SILVER)                                                      # a spoon on its saucer
        F.silver(c, 'sugar', 279, 71, SILVER)
        for (gx, gy) in ((274, 71), (275, 70), (273, 71), (271, 71), (283, 71)):               # sugar spilt round it
            c.put(gx, gy, hexc('f2efe6'))
        c.ellipse(293, 71, 11, 1.4, shade(SILVER, 0.7)); c.line(282, 70, 303, 69, SILVER)    # the tray, pushed askew
        F.silver(c, 'teapot', 288, 70, SILVER)
        c.hline(286, 290, 64, hexc('3a3a40')); c.put(288, 63, SILVER)                          # its lid off —
        c.ellipse(297, 69, 2.2, 0.8, shade(SILVER, 1.1)); c.put(297, 68, shade(SILVER, 0.66))   # — lying on the tray
        F.silver(c, 'coffee', 304, 71, SILVER)
    setback(c, _sb, depth=4, top=72, x_range=(249, 311))
    cup, cup_dk, cup_lt = hexc('e6ddc8'), hexc('b0a690'), hexc('f6f0e2')
    coffee, coffee_lt = hexc('3a2010'), hexc('7a5030')
    c.ellipse(253, 77, 4, 1, coffee); c.rect(249, 77, 254, 77, coffee)                        # the spill, to the edge
    c.put(252, 77, coffee_lt); c.put(256, 77, coffee)
    c.hline(256, 259, 72, cup_lt); c.rect(255, 73, 260, 75, cup)                              # the cup, on its side:
    c.hline(256, 259, 76, cup_dk); c.vline(261, 73, 75, cup_dk)                               # a round body,
    c.vline(254, 73, 75, cup_dk); c.put(254, 74, coffee); c.put(255, 74, coffee)              # its mouth to the spill,
    c.put(257, 71, cup_dk); c.put(258, 70, cup_dk); c.put(259, 71, cup_dk)                    # its handle up
    c.vline(250, 78, 84, coffee); c.vline(251, 78, 81, shade(coffee, 1.3))                    # run down the front
    PX.anim(250, 85, 'drip', fall=18, color='4a2c16')
    c.ellipse(251, 104, 6, 1.3, coffee); c.ellipse(254, 105, 3, 0.8, coffee)                  # a puddle on the boards —
    c.put(248, 104, coffee_lt); c.put(253, 104, coffee_lt)
    shard, shard_dk = hexc('c8bea8'), hexc('7e7662')                                          # — its twin smashed in it
    for (sx, sy, sw) in ((256, 104, 2), (259, 106, 1), (246, 106, 1)):
        c.hline(sx, sx + sw, sy, shard); c.put(sx, sy + 1, shard_dk)
    c.put(262, 104, shard_dk); c.put(263, 103, shard); c.put(263, 105, shard_dk)              # its snapped-off handle
    F.flush_light(c, 177)                                                         # above the portraits

C_ANCHORS = [('anchor_dining_china_cabinet', 25, 52, 'bp s'), ('anchor_dining_cabinet_cupboard', 17, 86, 'bp s'),
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
    with PX.wall_mark(c):                  # a mark on the wall: it can run down behind the sideboard
        for i in range(4):                                                                    # a bloody handprint
            c.line(118 + i * 2, 58, 117 + i * 2, 50 - i, BLOOD)
        c.ellipse(121, 60, 4, 3, BLOOD)
        c.line(121, 63, 122, 80, BLOOD)


@persp
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
        for (x, col, h) in ((64, hexc('b0453a'), 7), (70, hexc('c9b86a'), 8), (76, hexc('b0453a'), 6)):
            F.tin(c, x, 120, 2, h, col, lid=hexc('c9c7bd'), handle=False)          # food tins
        # a camping lantern: a glass chimney in a cage, a domed cap, a carry loop, a heavy base
        c.rect(80, 116, 90, 120, hexc('3a3a36')); c.hline(80, 90, 120, hexc('1c1c1a'))
        c.hline(80, 90, 116, hexc('5a5a52'))
        c.rect(81, 107, 89, 115, hexc('d9b44a'))
        c.vline(81, 107, 115, hexc('f0d27a')); c.vline(89, 107, 115, hexc('a8842e'))
        for x in (81, 85, 89):
            c.vline(x, 106, 116, hexc('2a2a26'))                                   # the cage bars
        c.poly([(79, 106), (91, 106), (88, 102), (82, 102)], hexc('3a3a36'))      # the domed cap
        c.hline(82, 88, 102, hexc('5a5a52'))
        c.line(82, 102, 84, 98, hexc('2a2a26')); c.line(84, 98, 86, 98, hexc('2a2a26')); c.line(86, 98, 88, 102, hexc('2a2a26'))
        F.light(85, 111, 'lantern')
    F.moved(c, _lantern, -12, -21)


def d_furniture(c):
    # the table flipped onto its side across the room: its top faces us, its legs sticking straight
    # BACK toward the wall (round 17: they poked straight up like sticks) — seen from above, they
    # run in toward the vanishing point, and the tabletop's edge shows along the top
    x0, x1, top, base = 118, 216, 80, 121
    wood_top = shade(F.WOOD[0], 1.15)
    F.chair_back(c, 152, 60, 80, F.WOOD, width=16)                                            # a chair wedged behind it
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 4, 3, 120)
    for lx in (x0 + 6, x1 - 10):                                                              # the legs, running back
        ax, ay = lx, top
        bx, by = _ipt(pp(160 + (lx - 160) / 1.21, 66, 5))
        c.poly([(ax, ay), (ax + 4, ay), (bx + 3, by), (bx, by)], F.WOOD[2])
        c.line(ax, ay, bx, by, shade(F.WOOD[2], 1.2))
        c.line(ax + 4, ay, bx + 3, by, F.WOOD[3])
        c.hline(bx, bx + 3, by, shade(F.WOOD[2], 1.25))                                        # the foot, end-on
    c.poly([(x0, top), (x1, top), (x1 - 2, top - 2), (x0 + 2, top - 2)], wood_top)             # the tabletop's edge
    c.hline(x0 + 2, x1 - 2, top - 2, F.WOOD[3])
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
    # planks leaning up in the corner, then a MATTRESS dragged off a bed and propped in front of them —
    # both leaning: their tops against the wall, their feet out on the floor (round 17: the mattress
    # was a flat pale box painted on the wall)
    for (wx, col) in ((297, hexc('8a6a44')), (302, hexc('9a7a4e')), (307, hexc('7a5a38'))):
        a_, b_ = _ipt(pp(wx, 40, 0)), _ipt(pp(wx, 100, 3))
        c.shadow(b_[0] + 2, b_[1] + 1, 3, 1, 100)
        c.poly([(a_[0], a_[1]), (a_[0] + 3, a_[1]), (b_[0] + 3, b_[1]), (b_[0], b_[1])], col)
        c.line(a_[0], a_[1], b_[0], b_[1], shade(col, 1.2))
        c.line(a_[0] + 3, a_[1], b_[0] + 3, b_[1], shade(col, 0.6))
        c.hline(a_[0], a_[0] + 3, a_[1], shade(col, 1.3))
    _leaning_mattress(c, 272, 291, 30, 100)
    c.shadow(228, 120, 8, 1, 110)                                             # the hammer, dropped at the table's foot
    c.rect(218, 116, 236, 118, F.WOOD[1])
    c.rect(232, 112, 238, 118, hexc('5a5a52'))


def _leaning_mattress(c, wx0, wx1, wtop, wbot, lean=6, thick=4):
    """A mattress stood on end and leaned on the wall: its back top against the wall, its foot `lean`
    px out on the floor, `thick` px thick. We see its striped TICKING front, its left side (the room's
    middle is to the left) and a sliver of its top — buttons in rows, a stain, a sag."""
    tick, tick_st, side = hexc('d8d0bc'), hexc('9aa8b8'), hexc('a8a090')
    btl, btr = _ipt(pp(wx0, wtop, 0)), _ipt(pp(wx1, wtop, 0))
    ftl, ftr = _ipt(pp(wx0, wtop + 1, thick)), _ipt(pp(wx1, wtop + 1, thick))
    fbl, fbr = _ipt(pp(wx0, wbot, lean + thick)), _ipt(pp(wx1, wbot, lean + thick))
    bbl = _ipt(pp(wx0, wbot, lean))
    c.shadow((fbl[0] + fbr[0]) // 2, fbl[1] + 1, (fbr[0] - fbl[0]) // 2 + 3, 2, 110)
    c.poly([btl, ftl, fbl, bbl], side)                                          # its left side
    for t in (0.25, 0.5, 0.75):                                                 # the side's quilting seam
        c.put(int(round(ftl[0] + (fbl[0] - ftl[0]) * t)) - 1, int(round(ftl[1] + (fbl[1] - ftl[1]) * t)), shade(side, 0.8))
    c.poly([btl, btr, ftr, ftl], shade(tick, 1.08))                            # a sliver of its top
    c.poly([ftl, ftr, fbr, fbl], tick)                                          # the front
    rows = fbl[1] - ftl[1]
    for k in range(1, 7):                                                       # ticking stripes, in perspective
        u = k / 7.0
        a_ = (ftl[0] + (ftr[0] - ftl[0]) * u, ftl[1])
        b_ = (fbl[0] + (fbr[0] - fbl[0]) * u, fbl[1])
        c.line(int(round(a_[0])), int(round(a_[1])), int(round(b_[0])), int(round(b_[1])), tick_st)
    for r in range(1, 5):                                                       # tufted buttons in rows
        v = r / 5.0
        for k in (1, 3, 5):
            u = k / 6.0
            x = ftl[0] + (ftr[0] - ftl[0]) * u + ((fbl[0] - ftl[0]) + ((fbr[0] - fbl[0]) - (ftr[0] - ftl[0])) * u) * v
            y = ftl[1] + rows * v
            c.put(int(round(x)), int(round(y)), shade(tick, 0.6))
    sx, sy = (ftl[0] + ftr[0]) // 2 + 2, ftl[1] + 36                            # a dried stain, tide-marked
    c.ellipse(sx, sy, 6, 9, hexc('b8a67a', 150))
    c.ellipse(sx + 1, sy + 1, 4, 6, hexc('c8b88e', 120))
    c.line(ftl[0], ftl[1], fbl[0], fbl[1], shade(side, 0.7))                   # outline
    c.line(ftr[0], ftr[1], fbr[0], fbr[1], shade(tick, 0.62))
    c.line(fbl[0], fbl[1], fbr[0], fbr[1], shade(tick, 0.55))
    c.line(btl[0], btl[1], btr[0], btr[1], shade(tick, 0.7))


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
    c.rect(122, 34, 200, 44, hexc('efe8d8'))                                     # the banner, hand-painted
    c.hline(122, 200, 44, shade(hexc('efe8d8'), 0.85))
    word = 'HAPPY BIRTHDAY'
    x = 122 + (79 - F.text3_width(word)) // 2
    for i, ch in enumerate(word):
        g = F.FONT3.get(ch, F.FONT3[' '])
        F.text3(c, x, 37, ch, PARTY[i % len(PARTY)] if ch != ' ' else PARTY[0])
        x += len(g[0]) + 1


@persp
def e_floor(c):
    F.floor_carpet(c, hexc('8a5a4a'), hexc('9a6a58'), hexc('7a4a3c'), worn=hexc('a07060'))


def e_strip(c):
    # (the gift table + the torn box are FRONT-LAYER pieces — drawn above the runtime window, e_front_strip below)
    pass


# --- the gift table: a small pine table in true perspective, the presents stacked on it ---------------------
G_TOP = 72.0            # wall y of the gift table's top surface (a tall little table: the stack reaches the window's sill)


def e_front_strip(c):
    """The presents, owner round 36e: SMALLER (they were huge), on a TABLE, standing in front of the left wall's window — a
    stack reaching up across the window's lower pane — and the torn-open box on the floor under the table. Drawn in the FRONT
    layer so the window sits behind them (it is only there when this slot has no balcony, exactly when the strip shows)."""
    P3.table3d(c, 54, 104, 6, 17, G_TOP, F.PINE[0], F.PINE[1], F.PINE[2], F.PINE[3])
    # (wall x0, x1, height, d0, d1, paper, ribbon, y_base) — bottom row, then a second layer, then the top one
    top = G_TOP
    P3.gift(c, 59, 72, top, 7, 8, 15, PARTY[1], PARTY[2])
    P3.gift(c, 75, 86, top, 5, 9, 16, PARTY[0], PARTY[3])
    P3.gift(c, 89, 99, top, 6, 8, 14, PARTY[4], PARTY[2])
    P3.gift(c, 61, 70, top - 7, 6, 9, 14, PARTY[2], PARTY[0])
    P3.gift(c, 77, 85, top - 5, 4, 10, 15, PARTY[3], PARTY[4])
    P3.gift(c, 63, 69, top - 13, 5, 10, 13, PARTY[0], PARTY[2])
    # balloons tied to the stack, drifting up across the window's glass behind them
    _balloon(c, 60, 36, PARTY[4], 59, tie=56)
    _balloon(c, 71, 29, PARTY[1], 59, tie=58)
    P3.torn_box(c, 74, 88, 13, 21, 100.0, 9.0, PARTY[3], shade(PARTY[3], 0.62), hexc('9cc89c'), hexc('efe8d8'))


# --- the party table ---------------------------------------------------------------------------------------
T_X0, T_X1, T_D0, T_D1, T_TOP = 123.0, 218.0, 8.0, 20.0, 75.0
CLOTH, CLOTH_DK = hexc('efe8d8'), hexc('cfc6b0')


def _e_balloons(c):
    # balloons TIED to the chair backs (round 17: their strings ended in mid-air; round 23: drawn in FRONT of the chairs,
    # the string knotted round the top rail instead of vanishing behind it). The LEFT one is part of the room; the cluster
    # over the right-hand chair is a front-layer piece (e_front) so it can drift across the window beside it.
    for (x, y, col, top) in ((139, 53, PARTY[1], 70),):
        _balloon(c, x, y, col, top)


def _balloon(c, x, y, col, top, tie=None):
    c.ellipse(x, y, 5, 6, col)
    c.ellipse(x - 2, y - 2, 1, 2, shade(col, 1.3))
    c.put(x, y + 6, shade(col, 0.7))                                          # the knot
    tx = tie if tie is not None else x
    c.line(x, y + 7, (x + tx) // 2 + 1, y + 11, hexc('9a927e')); c.line((x + tx) // 2 + 1, y + 11, tx, top, hexc('9a927e'))
    c.put(tx - 1, top, hexc('9a927e')); c.put(tx + 1, top, hexc('9a927e'))     # tied round the rail


def e_front(c):
    # a bunch of balloons rising off the right-hand chair — the last one drifts out over the window on that side
    for (x, y, col) in ((221, 54, PARTY[0]), (231, 47, PARTY[2]), (238, 38, PARTY[3])):
        _balloon(c, x, y, col, 70, tie=221)


def e_furniture(c):
    # the party table out in the room: a cake with the candles burnt down, paper plates, hats
    PINEP = {'wood': hexc('b58a55'), 'seat': hexc('c9a06a')}
    mdl = C3.dining_chair('spindle')
    for (x, yaw) in ((139, 168), (183, 198), (221, 184)):                                    # spindle-backs round the table, none square-on
        C3.draw_model(c, x, 100, mdl, yaw, PINEP, srad=10)
    C3.draw_model(c, 107, 114, mdl, 78, PINEP, srad=9)                                       # the head chair, turned toward the table (a whole side shows)
    C3.draw_model(c, 241, 113, mdl, 282, PINEP, srad=9)                                      # and one at the other end, turned the other way
    _e_balloons(c)
    t = P3.table3d(c, T_X0, T_X1, T_D0, T_D1, T_TOP, F.PINE[0], F.PINE[1], F.PINE[2], F.PINE[3],
                   cloth=CLOTH, cloth_dk=CLOTH_DK, hem=13)
    top = T_TOP
    for xw in range(129, 226, 8):                                                  # a paper cloth, printed (dots in perspective)
        for dd in (10.5, 14.5, 18.5):
            px, py = P3.scr(xw + (4 if dd == 14.5 else 0), top, dd)
            c.put(px, py, PARTY[(xw // 8 + int(dd)) % len(PARTY)])
        px, py = P3.scr(xw, top + 4.5, T_D1 + 1.2)
        c.put(px, py, PARTY[(xw // 8) % len(PARTY)])
    # plates + the hats left on them
    for (xw, dd, col, dk) in ((141, 13.5, PARTY[0], shade(PARTY[0], 0.7)), (157, 17.0, PARTY[1], shade(PARTY[1], 0.7)),
                              (203, 12.5, PARTY[3], shade(PARTY[3], 0.7)), (219, 16.5, PARTY[4], shade(PARTY[4], 0.7))):
        P3.disc(c, xw, top, dd, 6.0, hexc('efe8d8'), edge=hexc('c3beb0'))
        P3.cone(c, xw, top, 10.0, dd, 3.6, col, dk, stripe=hexc('efe8d8'), pom=PARTY[2])
    # paper cups
    for (xw, dd) in ((167, 18.0), (193, 11.5)):
        P3.cyl(c, xw, top, 4.5, dd, 2.3, hexc('efe8d8'), hexc('f8f4ea'), hexc('d0c8b4'), rim=hexc('b8b0a0'))
        c.hline(*(lambda b: (b[0] - 2, b[0] + 2, b[1] - 2))(P3.scr(xw, top, dd)), PARTY[1])
    # the cake: a plate, a pink-iced sponge with a slice cut from it, candles burnt down
    cx_, cd = 177.0, 14.0
    P3.disc(c, cx_, top, cd, 11.5, hexc('efe8d8'), edge=hexc('c3beb0'))
    bx, by, ty, rx, ry = P3.cyl(c, cx_, top - 0.4, 7.0, cd, 8.4, hexc('d98aa0'), hexc('f4d6de'), hexc('b86880'), rim=hexc('f0d0dc'))
    for xx in range(int(bx - rx) + 1, int(bx + rx), 2):                            # the icing's drips down the side
        c.put(xx, int(ty + ry * 0.6) + 2, hexc('f0d0dc'))
    # the slice cut out of the front-right: sponge showing on the cut faces
    c.poly([(bx, ty + 1), (bx + rx, ty + 1), (bx + rx - 1, by + 1), (bx + 1, by + ry * 0.7)], hexc('8a5a3a'))
    c.poly([(bx, ty + 1), (bx + rx, ty + 1), (bx + rx * 0.6, ty + ry * 0.8)], hexc('c89a68'))
    c.hline(int(bx + 1), int(bx + rx - 1), int((ty + by) / 2), hexc('e8d8c0'))        # the cream layer
    for k, (ox, oy) in enumerate(((-4, -0.4), (-1.5, 0.5), (1, -0.5), (-6.5, 0.4))):  # four candles, burnt to stubs
        px, py = int(round(bx + ox)), int(round(ty + oy))
        c.vline(px, py - 3, py, PARTY[(k * 2 + 1) % 5])
        c.put(px, py - 4, hexc('3a2a1a'))
    # the blood on the cloth + a dropped knife
    s_ = P3.disc(c, 211.0, top, 15.5, 4.2, BLOOD)
    P3.disc(c, 214.0, top, 16.5, 2.2, BLOOD_DK)
    P3.knife(c, 206.0, top, 17.0, ang=0.5)
    # the toppled chair, clear of the table's legs (owner round 36e: a leg was clipping into it)
    C3.draw_model(c, 187, 131, C3.fall(mdl, 'side', 8.0), 40, PINEP, shadow='footprint')
    # a sideboard with a cassette player and a stack of paper cups (with depth)
    def _sb(c):
        F.chest(c, 250, 310, 72, 100, F.PINE, drawers=2, open_row=0)
        # a boombox for the party (round 19: it read as a dark box): two speaker cones, the
        # cassette deck between them, a carry handle, an aerial; a stack of paper cups beside it
        c.ellipse(258, 70, 5, 1.6, hexc('c0453a')); c.ellipse(258, 69, 4, 1, hexc('e8b83a'))   # a bowl of crisps
        c.put(256, 68, hexc('f0cf6a')); c.put(259, 68, hexc('f0cf6a'))
        c.ellipse(268, 70.5, 5, 1.3, hexc('efe8d8'))                                           # a plate of sandwiches
        for sx_ in (266, 269):
            c.poly([(sx_ - 2, 70), (sx_ + 2, 70), (sx_, 67)], hexc('e6d2a0')); c.hline(sx_ - 1, sx_ + 1, 69, hexc('b0453a'))
        c.box(274, 62, 296, 71, hexc('3a3a3d'), hexc('1c1c1e'))
        c.hline(275, 295, 63, hexc('5a5a60'))
        for sx in (279, 291):
            c.ellipse(sx, 67, 3.5, 3.5, hexc('1c1c1e')); c.ellipse(sx, 67, 2.5, 2.5, hexc('6a6e72'))
            c.ellipse(sx - 0.5, 66.5, 1, 1, hexc('9aa3a8'))
        c.rect(282, 65, 288, 69, hexc('9aa3a8')); c.rect(283, 66, 287, 68, hexc('2a2a2e'))     # the cassette deck
        c.put(284, 67, hexc('d9c24a')); c.put(286, 67, hexc('d9c24a'))
        c.line(276, 62, 278, 58, hexc('7a8083')); c.hline(278, 292, 58, hexc('7a8083')); c.line(292, 58, 294, 62, hexc('7a8083'))
        c.line(295, 62, 300, 50, hexc('9aa3a8'))                                               # the aerial
        for i, y in enumerate(range(70, 59, -2)):                                              # paper cups, stacked
            c.hline(300, 306, y, hexc('efe8d8')); c.hline(300, 306, y + 1, hexc('d0c8b4'))
        c.vline(306, 60, 71, hexc('b8b0a0')); c.vline(300, 60, 71, hexc('f8f4ea'))
        c.ellipse(303, 60, 3, 1, hexc('b8b0a0'))
    setback(c, _sb, depth=4, top=72, x_range=(249, 311))
    F.flush_light(c, 160)

E_ANCHORS = [('anchor_dining_presents', 66, 77, 's'), ('anchor_dining_torn_box', 82, 114, 's'),
             ('anchor_table_left', 143, 90, ''), ('anchor_dining_cake', 177, 86, ''),
             ('anchor_table_right', 219, 90, ''), ('anchor_right_upperdrawers', 280, 82, 'bp')]

FRONTS = {'e': (e_front, e_front_strip)}


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
        ff, fs = FRONTS.get(v, (None, None))
        finish_module(name, 'dining_room', seed, bare, floor, build, anchors, strip_fn=strip, front_fn=ff, front_strip_fn=fs)
