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
from pixlib import persp
from pixlib import Canvas, hexc, shade, rrect, finish_module, setback
from pixlib import pp, _ip as _ipt
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
    # the serving hatch to the kitchen: folding louvred doors open onto the dim kitchen beyond — its
    # tiled wall, a shelf of jars, a pan on a hook (round 17: a black hole read as nothing)
    c.box(168, 28, 216, 62, hexc('8a6443'), hexc('3a2718'))
    c.rect(170, 30, 214, 60, hexc('2e2c26'))
    for y in range(33, 60, 5):
        c.hline(170, 214, y, hexc('26241f'))
    for x in range(172, 214, 6):
        c.vline(x, 30, 60, hexc('26241f'))
    c.rect(170, 30, 214, 32, hexc('1e1c18'))                                                  # the lintel's shadow
    c.hline(183, 201, 42, hexc('4a4034'))                                                     # a shelf of jars
    for (jx, col) in ((185, hexc('5a5a44')), (189, hexc('6a4a34')), (193, hexc('4a5448')), (198, hexc('5a4a3a'))):
        c.rect(jx, 37, jx + 2, 41, col)
    c.vline(196, 44, 47, hexc('4a4a48')); c.ellipse(196, 50, 3, 3, hexc('3e3e3c'))           # a pan on a hook
    c.rect(170, 55, 214, 57, hexc('3a362e'))                                                  # the counter beyond
    c.rect(168, 58, 216, 62, hexc('9e7550'))                                                 # its sill
    for (d0, d1) in ((171, 181), (203, 213)):
        c.rect(d0, 31, d1, 57, hexc('9e7550'))
        for y in range(33, 56, 3):
            c.hline(d0 + 1, d1 - 1, y, hexc('6b4a31'))
    c.rect(186, 52, 192, 57, PLATE)                                                           # a plate left on the sill


@persp
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
    setback(c, lambda l: F.moved(l, _drinks, -3, 0), depth=4, top=62, x_range=(5, 45), rake=1.0)   # with depth (round 14; 3px left, clear of window L)
    _pouffe_at(c)


def _drinks(c):
    # a drinks cabinet (the flap down, bottles inside)
    c.shadow(28, 100, 20, 2, 100)
    c.box(10, 62, 46, 99, F.TEAK[0], F.TEAK[3])
    c.rect(12, 64, 44, 80, hexc('2a1d14'))
    for (x, h, col) in ((14, 12, hexc('3a5a3a')), (20, 10, hexc('7a4a2a')), (26, 13, hexc('c9c2b1')), (34, 11, hexc('5a1a22'))):
        c.rect(x, 80 - h, x + 3, 79, col)
        c.rect(x + 1, 80 - h - 3, x + 2, 80 - h - 1, col)
    c.box(12, 82, 44, 97, F.TEAK[0], F.TEAK[2])
    c.rect(26, 88, 30, 88, F.BRASS)
    c.poly([(12, 80), (44, 80), (48, 84), (8, 84)], F.TEAK[1])                                # the drop flap


def _pouffe_at(c):
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
    # a teak sideboard with a record player on the right (with depth)
    def _sb(c):
        F.chest(c, 244, 310, 72, 100, F.TEAK, drawers=2, open_row=1)
        c.box(272, 64, 294, 71, hexc('3a3a3d'), hexc('1c1c1e'))
        c.ellipse(281, 66, 7, 1, hexc('1c1c1e'))
        c.line(291, 65, 285, 67, SILVER)
        for (x, col) in ((299, hexc('d86a3a')), (302, hexc('2f4a63')), (305, hexc('d9c24a'))):
            c.rect(x, 58, x + 2, 71, col)                                                       # records leant up
    setback(c, _sb, depth=4, top=72, x_range=(243, 311))
    F.pendant(c, 140, 22, 'orange', dome=True)                                    # a 70s dome pendant

B_ANCHORS = [('anchor_dining_drinks_cabinet', 23, 72, 'bp s'), ('anchor_dining_pouffe', 62, 94, 's'),
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
    # a sideboard with silver on the right (x > 240), with depth
    def _sb(c):
        F.chest(c, 250, 310, 72, 100, F.WOOD, drawers=2)
        c.rect(256, 67, 266, 71, SILVER); c.hline(254, 268, 67, SILVER)                       # a tea set
        c.rect(276, 66, 282, 71, SILVER); c.put(283, 68, SILVER)
        c.rect(288, 60, 294, 71, SILVER); c.hline(286, 296, 60, SILVER)
        c.ellipse(303, 70, 5, 1, SILVER)
    setback(c, _sb, depth=4, top=72, x_range=(249, 311))
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
    for i in range(4):                                                                        # a bloody handprint
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
    # balloons TIED to the chair backs (round 17: their strings ended in mid-air)
    for (x, y, col) in ((139, 53, PARTY[1]), (219, 54, PARTY[0])):
        c.ellipse(x, y, 5, 6, col)
        c.ellipse(x - 2, y - 2, 1, 2, shade(col, 1.3))
        c.put(x, y + 6, shade(col, 0.7))                                          # the knot
        c.line(x, y + 7, x + 1, y + 11, hexc('9a927e')); c.line(x + 1, y + 11, x, 70, hexc('9a927e'))


@persp
def e_floor(c):
    F.floor_carpet(c, hexc('8a5a4a'), hexc('9a6a58'), hexc('7a4a3c'), worn=hexc('a07060'))


def e_strip(c):
    setback(c, _presents, depth=3)                                          # with depth (owner round 14)
    _torn_box(c)


def _presents(c):
    # a pile of wrapped presents, never opened, and one that was
    c.shadow(28, 100, 22, 2, 100)
    for (x0, y0, x1, col, rib) in ((8, 84, 30, PARTY[1], PARTY[2]), (28, 88, 46, PARTY[0], PARTY[3]),
                                   (14, 72, 34, PARTY[4], PARTY[2])):
        c.box(x0, y0, x1, 99 if y0 > 80 else 83, col, shade(col, 0.6))
        c.vline((x0 + x1) // 2, y0, 99 if y0 > 80 else 83, rib)
        c.hline(x0, x1, y0 + 4, rib)
    c.poly([(22, 72), (26, 66), (30, 72)], PARTY[2])


def _torn_box(c):
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
    # a sideboard with a cassette player and a stack of paper cups (with depth)
    def _sb(c):
        F.chest(c, 250, 310, 72, 100, F.PINE, drawers=2, open_row=0)
        c.box(274, 62, 296, 71, hexc('3a3a3d'), hexc('1c1c1e'))
        c.ellipse(280, 66, 2, 2, hexc('9aa3a8')); c.ellipse(290, 66, 2, 2, hexc('9aa3a8'))
        c.rect(300, 60, 305, 71, hexc('efe8d8'))
        for y in range(62, 71, 2):
            c.hline(300, 305, y, hexc('d0c8b4'))
    setback(c, _sb, depth=4, top=72, x_range=(249, 311))
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
