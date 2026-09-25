"""Study VARIANTS b-d (variant a is tools/art/study.py). Same rules via pixlib.finish_module.
A study can hold the BALCONY doors (x 4..96): that strip's furniture goes in strip() — hidden, with
its nodes, on a balcony slot.

Run:  python3 tools/art/study_variants.py [b c d]

  b  90s home office — a beige computer on a desk against the wall, an office chair rolled out,
     a printer on a stand, box files; strip: a low bookshelf + a stack of files on the floor.
  c  library — two tall bookcases with a ladder, a wingback reading chair + side table + lamp
     out in the room, a globe; strip: a third bookcase + books piled on the floor.
  d  prepper's radio room — a ham radio bench, maps on the wall, supply crates + jerry cans
     out in the room, a folding chair with a gas mask; strip: shelves of tins.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import persp
from pixlib import Canvas, hexc, shade, rrect, finish_module, setback
import furn as F
import chair3d as C3

BLOOD = hexc('4a1d1b', 150)
BEIGE = (hexc('d6cfb8'), hexc('e6e0cc'), hexc('b9b29a'), hexc('5e584a'))


# ============================================================================================
# B — 90s home office
# ============================================================================================
def b_wall(c):
    F.wall_plain(c, hexc('a9aeb0'), hexc('7e8486'), hexc('5a5e60'), texture=hexc('9ea3a5'),
                 dado=hexc('7c8a94'), dado_y=62)
    for i in range(5):
        c.ellipse(292 + i * 4, 16 + (i % 2) * 3, 7, 5, hexc('7a7a6a', 60))


def b_decor(c):
    F.frame_pic(c, 104, 26, 130, 44, hexc('26262a'), hexc('e6e0cc'), wire=False)            # a certificate
    for y in range(30, 42, 3):
        c.hline(108, 126, y, hexc('9a927e'))
    c.put(117, 39, hexc('b0453a'))
    c.box(148, 20, 200, 52, hexc('9a7650'), hexc('3b2718'))                                  # a corkboard
    c.rect(152, 24, 166, 34, hexc('e6dfcc')); c.rect(170, 26, 184, 38, hexc('d9c24a'))
    c.rect(186, 30, 196, 48, hexc('e6dfcc')); c.rect(154, 38, 168, 48, hexc('e88aa0'))
    for y in range(40, 48, 2):
        c.hline(156, 166, y, hexc('b0453a'))


@persp
def b_floor(c):
    F.floor_carpet(c, hexc('6a6e74'), hexc('7a7e84'), hexc('5a5e64'), worn=hexc('82868c'))


def b_strip(c):
    # a low bookshelf against the wall + a stack of box files on the floor beside it
    def _low(l):
        F.shelves(l, 8, 46, 70, 100, F.TEAK, [83, 96], c.rng)
        l.rect(10, 66, 22, 69, hexc('d6cfb8')); l.rect(28, 64, 36, 69, hexc('4e8a5a'))       # a desk tidy, a plant
        l.poly([(26, 64), (30, 58), (34, 62), (38, 57), (40, 64)], hexc('5e8240'))
    setback(c, _low, depth=3, top=70, x_range=(8, 46))
    # the box files kept in a small file shelf beside it (not stacked on the floor)
    setback(c, lambda l: F.file_shelf(l, 50, 78, 70, 101, F.TEAK, c.rng), depth=3, top=70)


def b_furniture(c):
    # EVEN SPACING (owner round 13b — "good even spacing across the modules is essential for our
    # scavenge nodes"): strip shelves | desk + office chair | printer stand | armchair turned to the
    # desk + its side table | a bin in the corner — the right end no longer piles up (the tall shelf
    # that sat behind the side table went).
    def desk(c):
        # the computer desk against the wall
        c.shadow(146, 100, 36, 2, 100)
        c.rect(108, 70, 184, 73, BEIGE[1])
        c.hline(108, 184, 70, BEIGE[3])
        c.hline(108, 184, 73, BEIGE[2])
        c.box(110, 74, 128, 99, BEIGE[0], BEIGE[3])
        for (d0, d1) in ((76, 83), (85, 92)):
            c.box(112, d0, 126, d1, BEIGE[0], BEIGE[2])
            c.rect(117, (d0 + d1) // 2, 121, (d0 + d1) // 2, hexc('7e8486'))
        c.rect(180, 74, 182, 99, BEIGE[2])
        c.box(132, 48, 160, 68, BEIGE[0], BEIGE[3])                                           # the monitor
        c.rect(135, 51, 157, 64, hexc('1e2a3a'))
        c.rect(138, 54, 150, 55, hexc('3a5a8a'))
        c.rect(142, 68, 150, 69, BEIGE[2])
        c.box(162, 56, 178, 69, BEIGE[0], BEIGE[3])                                           # the tower
        c.rect(164, 59, 176, 60, BEIGE[2]); c.put(170, 64, hexc('4e8a5a'))
        c.rect(130, 69, 158, 69, hexc('e6e0cc'))                                              # keyboard
        c.rect(112, 64, 118, 69, hexc('e6e0cc')); c.put(119, 66, hexc('e6e0cc'))              # a mug
    setback(c, lambda l: F.moved(l, desk, -8, 0), depth=5, top=70, x_range=(100, 176), rake=1.0)
    # an office chair rolled out from the desk and left swivelled at an angle (owner round 13: the
    # square-on chair "looks a bit weird" — built in 3D like the armchairs). It stands at the desk's
    # RIGHT end, clear of the desk's back-plane spot at the drawer end — upright or knocked over.
    C3.office_chair_at(c, 160, 118, 40, {'fab': hexc('3a3a44'), 'metal': hexc('2a2a30')},
                       plan={2: 'down', 3: 'down_blood'}, key='study_b_office', outline=hexc('141418'))
    PAPER, PAPER_DK, INK = hexc('f0ece2'), hexc('d6d0c2'), hexc('b3aea3')

    def words(c, xa, ya, xb, yb, rng):
        """One line of 'writing': short pale dashes with 1px gaps along a line — reads as text."""
        n = max(int(abs(xb - xa)), 1)
        k, word = 0, rng.randrange(2, 5)
        while k <= n:
            if word > 0:
                t = k / n
                c.put(int(round(xa + (xb - xa) * t)), int(round(ya + (yb - ya) * t)), INK)
                word -= 1
            else:
                word = rng.randrange(2, 5)
            k += 1

    def _printer(c):
        # a printer on a little stand against the wall beside the desk
        c.shadow(214, 119, 14, 2, 110)
        c.rect(202, 96, 226, 98, BEIGE[1])
        c.hline(202, 226, 96, BEIGE[3])
        for lx in (203, 225):
            c.vline(lx, 99, 118, BEIGE[2])
        c.hline(203, 225, 112, BEIGE[2])
        c.box(204, 86, 224, 95, BEIGE[0], BEIGE[3])
        c.rect(208, 88, 220, 89, hexc('26262a'))
        # owner round 13: a sheet hanging out of the printer (its writing pale, broken dashes)
        c.poly([(209, 94), (220, 94), (221, 101), (219, 106), (210, 105)], PAPER)
        c.vline(209, 95, 105, PAPER_DK)
        c.hline(211, 218, 105, PAPER_DK)
        for y in range(97, 104, 2):
            words(c, 211, y, 218 if y % 4 == 1 else 215, y, c.rng)
    F.moved(c, _printer, -18, -18)

    def sheet(pts):
        # a printed sheet lying flat on the FLOOR (below the skirting line): pale dashed lines of text
        c.poly(pts, PAPER)
        c.line(pts[3][0], pts[3][1], pts[2][0], pts[2][1], PAPER_DK)
        (x0, y0), (x1, y1), (x2, y2), (x3, y3) = pts
        for t in (0.35, 0.7):
            words(c, x0 + (x3 - x0) * t + 2, y0 + (y3 - y0) * t, x1 + (x2 - x1) * t - 2, y1 + (y2 - y1) * t, c.rng)
    # two sheets that slid off the stand onto the floor at its foot
    sheet([(183, 104), (197, 103), (200, 108), (186, 109)])
    sheet([(196, 106), (211, 106), (213, 111), (198, 111)])
    # the armchair pulled up for reading printouts, turned toward the desk, a side table at its elbow
    C3.armchair(c, 238, 117, 35, {'fab': hexc('6a6a5a'), 'fab_lt': hexc('7a7a68'), 'wood': hexc('3a2a1e')},
                style='club', plan={3: 'side'}, key='study_b')
    F.table_front(c, 262, 290, 106, 121, F.TEAK, depth=4)
    c.rect(266, 103, 270, 107, hexc('e6e0cc')); c.put(271, 104, hexc('e6e0cc'))            # a mug
    c.hline(266, 270, 103, hexc('4a3a2a'))
    c.poly([(274, 107), (285, 106), (287, 108), (276, 109)], PAPER)                        # printouts
    c.poly([(276, 105), (286, 104), (288, 106), (278, 107)], hexc('e6e0cc'))
    c.line(280, 105, 285, 104, hexc('2a3a6a'))
    # a wastepaper basket against the wall in the corner
    c.shadow(303, 100, 8, 2, 90)
    c.poly([(296, 86), (310, 86), (308, 99), (298, 99)], hexc('3a3a44'))
    for x in range(298, 309, 3):
        c.vline(x, 87, 98, hexc('4a4a56'))
    F.tube_light(c, 220)                                                 # the office fluorescent

B_ANCHORS = [('anchor_study_low_shelf', 26, 88, 'bp s'), ('anchor_study_box_files', 64, 88, 'bp s'),
             ('anchor_centre_desk', 128, 62, 'bp'), ('anchor_study_desk_drawer', 111, 88, 'bp'),
             ('anchor_study_office_chair', 160, 100, ''), ('anchor_study_printer', 196, 72, 'bp'),
             ('anchor_study_armchair', 234, 98, ''),
             ('anchor_study_side_table', 278, 107, '')]


# ============================================================================================
# C — library
# ============================================================================================
def c_wall(c):
    F.wall_plain(c, hexc('6a3a34'), hexc('4a2824'), hexc('3a2019'), rail=hexc('8a6443'), rail_y=16,
                 dado=hexc('4a2a22'), dado_y=64)
    F.wall_motif(c, hexc('7a4a42'), hexc('5a2e2a'), y1=60)
    for i in range(5):
        c.ellipse(196 + i * 5, 20 + (i % 2) * 3, 6, 4, hexc('3a2019', 70))


def c_decor(c):
    F.frame_pic(c, 146, 26, 176, 50, hexc('b58f4a'), hexc('4a5a4a'))                          # a dark oil painting
    c.ellipse(161, 36, 5, 6, hexc('7a6a5a'))


@persp
def c_floor(c):
    import living_room_variants as LV
    LV.parquet_floor(c, hexc('7a5238'), hexc('6a4630'), hexc('4a3020'))


def c_strip(c):
    setback(c, lambda l: F.shelves(l, 8, 46, 18, 100, F.WOOD, [34, 50, 66, 82, 96], c.rng), depth=3, rake=1.0)
    # books pulled off the shelf, stacked on a low cabinet at its foot
    def _cab(l):
        F.side_cabinet(l, 48, 78, 86, 101, F.WOOD)
        F.book_stack(l, 50, 86, [24, 22, 20, 17], [F.BOOKS[1], F.BOOKS[0], F.BOOKS[5], F.BOOKS[3]])
    setback(c, _cab, depth=3, top=86, x_range=(48, 78))


def c_furniture(c):
    setback(c, lambda l: F.shelves(l, 100, 142, 12, 100, F.WOOD, [28, 44, 60, 76, 96], c.rng), depth=4, rake=1.0)
    setback(c, lambda l: F.shelves(l, 180, 222, 12, 100, F.WOOD, [28, 44, 60, 76, 96], c.rng), depth=4, rake=1.0)
    c.line(214, 16, 206, 104, hexc('8a6443')); c.line(220, 18, 214, 104, hexc('8a6443'))  # the ladder
    for y in range(24, 104, 10):
        c.line(213 - (y - 16) // 11, y, 219 - (y - 18) // 11, y, hexc('8a6443'))
    # the reading corner out in the room: wingback, side table, lamp — in front of the LADDER
    # bookcase (it has no back-plane spot), keeping the centre bookcase's spot clear to step up to
    # (owner round 13b; pixlib.check_back_plane_clear)
    def corner(c):
        # a worn rug under the reading corner ties the chair, table and lamp together
        for y in range(111, 125):
            t = (y - 111) / 13.0
            x0, x1 = int(118 - 8 * t), int(200 + 8 * t)                           # wider nearer us
            for x in range(x0, x1 + 1):
                edge = y in (111, 124) or x in (x0, x1)
                inner = y in (113, 122) or x in (x0 + 3, x1 - 3)
                col = hexc('5a2a26') if edge else hexc('c9a86a') if inner else (hexc('7a3a30') if (x // 4 + y // 3) % 5 else hexc('4a5a6a'))
                c.put(x, y, col)
        for x in range(110, 209, 2):                                               # fringe
            c.put(x, 125, hexc('d8ccb0'))
    F.moved(c, corner, 60, 0)
    C3.armchair(c, 201, 117, -30, {'fab': hexc('3e5a4a'), 'fab_lt': hexc('4a6a58'), 'wood': hexc('3a2618')},
                style='wing', plan={2: 'blood', 3: 'tipped'}, key='study_c')   # turned toward the lamp
    def table_lamp(c):
        c.shadow(170, 121, 9, 2, 110)
        c.ellipse(170, 104, 9, 2, F.WOOD[1])
        c.vline(170, 106, 119, F.WOOD[0])
        c.hline(165, 175, 120, F.WOOD[0])
        c.rect(164, 100, 172, 103, F.BOOKS[0]); c.hline(164, 172, 100, shade(F.BOOKS[0], 1.2))
        c.rect(174, 99, 177, 103, hexc('c9c2b1'))
        F.floor_lamp(c, 188, 67, 121, hexc('c9ab7e'), hexc('3a2a1a'))
    F.moved(c, table_lamp, 60, 0)
    # a writing slope on the right against the wall
    def _slope(l):
        F.chest(l, 276, 310, 70, 100, F.WOOD, drawers=3, open_row=0)
        l.poly([(278, 69), (308, 69), (304, 60), (282, 60)], F.WOOD[1])
        l.rect(286, 62, 300, 67, hexc('e6e0cc'))
        l.line(302, 58, 306, 50, hexc('2b2622'))
    setback(c, _slope, depth=4, top=70, x_range=(275, 311))


C_ANCHORS = [('anchor_study_tall_shelf', 28, 58, 'bp s'), ('anchor_study_floor_books', 60, 96, 'bp s'),
             ('anchor_centre_bookcaseupper', 120, 40, 'bp'), ('anchor_centre_bookcaselower', 122, 72, 'bp'),
             ('anchor_study_wingback', 194, 96, ''), ('anchor_study_side_table', 228, 101, ''),
             ('anchor_right_shelf', 292, 64, 'bp')]


# ============================================================================================
# D — prepper's radio room
# ============================================================================================
def d_wall(c):
    F.wall_plain(c, hexc('7a8270'), hexc('5a6250'), hexc('3a3a30'), texture=hexc('727a68'))
    for i in range(6):
        c.ellipse(20 + i * 6, 16 + (i % 2) * 3, 8, 5, hexc('4a5240', 70))


def d_decor(c):
    c.rect(102, 22, 176, 58, hexc('d9d0b0'))                                                  # a map, marked up
    for (x0, x1, y) in ((106, 170, 30), (104, 150, 40), (130, 176, 50)):
        c.line(x0, y, x1, y + 4, hexc('7a9a6a'))
    c.line(120, 26, 140, 54, hexc('6a8ab0'))
    for (x, y) in ((128, 34), (152, 44), (166, 32)):
        c.ellipse(x, y, 3, 3, hexc('a8322c'))
    c.line(128, 34, 152, 44, hexc('a8322c')); c.line(152, 44, 166, 32, hexc('a8322c'))
    c.box(184, 26, 206, 44, hexc('26262a'), hexc('111114'))                                  # a clock set to a frequency chart
    for y in range(29, 42, 3):
        c.hline(187, 203, y, hexc('d9c24a'))


@persp
def d_floor(c):
    F.floor_planks(c, [hexc('4e4a40'), hexc('46423a'), hexc('544f44')], hexc('2e2b24'))


def d_strip(c):
    def _rack(c):
        F.shelves(c, 8, 46, 34, 100, F.METAL, [52, 70, 86, 97], c.rng, fill=0.0)
        for (y, h) in ((52, 8), (70, 9), (86, 8)):
            for x in range(11, 44, 5):
                col = [hexc('b0453a'), hexc('c9b86a'), hexc('6a8a5a')][(x // 5 + y) % 3]
                c.rect(x, y - h, x + 3, y - 1, col)
                c.hline(x, x + 3, y - h, hexc('c9c7bd'))
    setback(c, _rack, depth=3, top=34, x_range=(8, 46), rake=1.0)
    def _crate(c):
        # an ammo crate against the wall by the shelves, a gas mask dumped on it
        c.shadow(76, 121, 12, 2, 110)
        c.box(64, 106, 88, 121, hexc('5a6a4a'), hexc('2e3a24'))
        c.hline(65, 87, 107, hexc('6a7a5a'))
        c.rect(70, 112, 82, 114, hexc('d9d0b0'))
        c.rect(62, 108, 63, 111, hexc('3a3a36')); c.rect(89, 108, 90, 111, hexc('3a3a36'))     # handles
        rrect(c, 68, 96, 82, 105, hexc('3a3a36'), 3)                                             # the mask
        c.ellipse(72, 99, 2, 2, hexc('9aa3a8')); c.ellipse(78, 99, 2, 2, hexc('9aa3a8'))
        c.ellipse(72, 99, 1, 1, hexc('4a5a6a')); c.ellipse(78, 99, 1, 1, hexc('4a5a6a'))
        c.rect(73, 103, 77, 107, hexc('5a5a52'))                                                 # the filter
        c.hline(73, 77, 105, hexc('3a3a36'))
        c.line(68, 97, 62, 104, hexc('26262a'))                                                  # its strap
    F.moved(c, _crate, -12, -21)


def d_furniture(c):
    # WITH DEPTH (owner round 14): the radio bench, the folded camp bed
    setback(c, _d_bench, depth=5, top=72, x_range=(106, 190), rake=1.0)
    c.line(182, 77, 216, 20, hexc('26262a'))                                                 # the antenna lead up the wall
    _d_rest(c)


def _d_bench(c):
    # the radio bench against the wall
    c.shadow(148, 100, 36, 2, 100)
    c.rect(106, 72, 190, 75, hexc('6a6a5a'))
    c.hline(106, 190, 72, hexc('8a8a78'))
    for lx in (108, 188):
        c.rect(lx, 76, lx + 2, 99, hexc('4a4a40'))
    c.hline(108, 190, 92, hexc('4a4a40'))
    c.box(112, 58, 146, 71, hexc('3a3a36'), hexc('1c1c1a'))                                 # the transceiver
    for kx in range(116, 144, 6):
        c.ellipse(kx, 66, 2, 2, hexc('9aa3a8'))
    c.rect(116, 60, 134, 62, hexc('d9a24a'))
    c.box(150, 60, 168, 71, hexc('4a5a4a'), hexc('1c2a1c'))                                  # an amplifier
    c.rect(153, 62, 158, 66, hexc('d9d0b0'))
    c.line(174, 71, 180, 48, hexc('26262a')); c.ellipse(180, 47, 2, 2, hexc('26262a'))     # a desk mic
    c.rect(114, 84, 138, 91, hexc('9a7a4e'))                                                 # a battery box


def _d_rest(c):
    def _supplies(c):
        # supply crates + jerry cans stacked against the wall
        c.shadow(214, 121, 18, 2, 110)
        for (x0, y0, col) in ((198, 104, hexc('5a6a4a')), (214, 104, hexc('4e5e40')), (204, 90, hexc('5a6a4a'))):
            c.box(x0, y0, x0 + 15, y0 + 13 if y0 == 90 else 121, col, shade(col, 0.6))
            c.rect(x0 + 4, y0 + 4, x0 + 11, y0 + 6, hexc('d9d0b0'))
        for (x, col) in ((236, hexc('a8322c')), (250, hexc('4a5a3a'))):
            c.shadow(x + 6, 121, 7, 1, 110)
            c.box(x, 102, x + 12, 121, col, shade(col, 0.55))
            c.rect(x + 8, 98, x + 10, 101, shade(col, 0.7))
            c.line(x + 2, 104, x + 10, 118, shade(col, 0.8)); c.line(x + 10, 104, x + 2, 118, shade(col, 0.8))
    F.moved(c, _supplies, 0, -21)
    # a folding planning table out in the room: a map weighed down with a radio handset, a torch
    F.table_front(c, 190, 252, 98, 121, F.METAL, depth=5)
    c.rect(196, 96, 232, 99, hexc('d9d0b0'))
    c.line(200, 97, 226, 98, hexc('a8322c'))
    c.rect(236, 93, 244, 97, hexc('3a3a36')); c.line(244, 94, 248, 90, hexc('26262a'))
    c.rect(210, 95, 216, 96, hexc('d9b43a'))
    # a camp bed folded against the wall on the right
    def _camp(c):
        c.shadow(292, 100, 16, 2, 100)
        c.box(278, 40, 306, 99, hexc('5a6a4a'), hexc('2e3a24'))
        c.vline(292, 42, 97, hexc('4a5a3a'))
        c.rect(280, 44, 304, 46, hexc('7a8a6a'))
        c.rect(284, 60, 300, 72, hexc('3a3a36'))                                             # a sleeping roll strapped to it
        c.hline(284, 300, 64, hexc('26262a'))
    setback(c, _camp, depth=3, top=40, rake=1.0)
    F.bare_bulb(c, 216, 22)

D_ANCHORS = [('anchor_study_tins', 26, 62, 'bp s'), ('anchor_study_gas_mask', 63, 87, 'bp s'),
             ('anchor_study_radio', 130, 64, 'bp'), ('anchor_centre_desk', 126, 86, 'bp'),
             ('anchor_study_crates', 212, 77, 'bp'), ('anchor_study_map_table', 214, 97, ''),
             ('anchor_study_handset', 240, 95, ''),
             ('anchor_right_shelf', 292, 66, 'bp')]


# ============================================================================================
# E — artist's studio
# ============================================================================================
SPLASH = [hexc('c0453a'), hexc('3a6a9a'), hexc('d9b43a'), hexc('4e8a5a'), hexc('7a3a6a')]


def e_wall(c):
    F.wall_plain(c, hexc('d8d2c4'), hexc('a8a294'), hexc('8a8478'), texture=hexc('ccc6b8'))
    for x in range(0, 320, 16):                                                   # whitewashed brick
        for y in range(16, 92, 8):
            off = 8 if (y // 8) % 2 else 0
            c.hline(0, 319, y, hexc('c9c3b5'))
            c.vline((x + off) % 320, y, y + 7, hexc('c9c3b5'))
    for i in range(4):
        c.ellipse(26 + i * 7, 18 + (i % 2) * 3, 8, 5, hexc('9a9486', 60))


def e_decor(c):
    rng = Canvas(seed=91).rng
    for _ in range(40):                                                           # paint flicked on the wall
        x, y = rng.randrange(104, 270), rng.randrange(40, 92)
        if 226 <= x <= 270 and y <= 66:
            continue
        col = rng.choice(SPLASH)
        c.put(x, y, col)
        if rng.random() < 0.4:
            c.put(x + 1, y, col); c.put(x, y + 1, col)


@persp
def e_floor(c):
    F.floor_planks(c, [hexc('9a8a70'), hexc('928266'), hexc('a09076')], hexc('6a5e4a'))
    for y in range(104, 144):                                                     # paint drips, periodic
        for x in range(320):
            k = (x * 13 + y * 7) % 32
            if k == 9 and y % 5 == 0:
                c.put(x, y, SPLASH[((x % 32) // 7) % len(SPLASH)])


def e_strip(c):
    # a plan chest with rolled drawings + tins of paint on the floor
    def _plan_chest(c):
        F.chest(c, 8, 46, 70, 100, F.WOOD, drawers=4, open_row=1)
        for (x, col) in ((12, hexc('e6e0cc')), (20, hexc('d9d0b0')), (30, hexc('e6e0cc'))):
            c.rect(x, 64, x + 10, 69, col)
            c.ellipse(x, 66, 1, 2, shade(col, 0.8))
    setback(c, _plan_chest, depth=4, top=70, x_range=(7, 47), rake=1.0)
    def _tins(c):
        # (paint tins against the wall beside the chest)
        c.shadow(72, 121, 14, 2, 110)
        for (x, col) in ((60, SPLASH[0]), (70, SPLASH[1]), (80, SPLASH[2])):
            c.box(x, 110, x + 8, 121, hexc('9aa3a8'), hexc('5a6064'))
            c.rect(x + 1, 112, x + 7, 116, col)
            c.line(x + 1, 110, x + 4, 106, hexc('5a6064'))
        c.rect(88, 118, 96, 120, SPLASH[3])
    F.moved(c, _tins, -10, -21)


def e_furniture(c):
    setback(c, _canvases, depth=3, rake=1.0)
    _e_rest(c)


def _canvases(c):
    # canvases stacked against the wall
    c.shadow(128, 100, 26, 2, 100)
    for i, (x0, top, col) in enumerate(((104, 40, hexc('d8cfb4')), (112, 48, hexc('c9bf9e')), (120, 58, hexc('d8cfb4')),
                                         (132, 52, hexc('b9ae8e')))):
        c.box(x0, top, x0 + 26, 99, col, hexc('7a6a50'))
        c.rect(x0 + 2, top + 2, x0 + 24, 97, shade(col, 0.95))
    c.rect(134, 54, 156, 97, hexc('3a5a7a'))                                      # the front one painted: a sea
    c.rect(134, 76, 156, 97, hexc('2a4a5a'))
    c.poly([(138, 76), (146, 68), (152, 76)], hexc('e6e0cc'))


def _e_rest(c):
    # the easel out in the room, a portrait with its face smeared out
    c.shadow(186, 121, 14, 2, 110)
    c.line(176, 121, 184, 64, F.PINE[2]); c.line(196, 121, 188, 64, F.PINE[2]); c.line(186, 121, 186, 70, F.PINE[3])
    c.rect(170, 104, 202, 106, F.PINE[1])                                          # the tray
    c.box(172, 66, 200, 103, hexc('e6e0cc'), hexc('7a6a50'))
    c.rect(174, 68, 198, 101, hexc('8a7a6a'))
    c.ellipse(186, 80, 7, 9, hexc('c8b39a'))
    c.rect(178, 90, 194, 101, hexc('3a3a4a'))
    for (x, y) in ((180, 74), (184, 78), (188, 76), (182, 84), (190, 82)):          # the smear
        c.line(x, y, x + 6, y + 3, hexc('5a1a16'))
    for (x, col) in ((174, SPLASH[0]), (180, SPLASH[1]), (188, SPLASH[2])):
        c.rect(x, 102, x + 3, 103, col)
    # a paint-spattered trestle table out by the lane: jars of brushes, a palette
    F.table_front(c, 214, 268, 96, 121, (hexc('b9ae92'), hexc('c9c0a8'), hexc('8a8270'), hexc('4a4638')), depth=5)
    for (x, y, col) in ((218, 98, SPLASH[0]), (230, 99, SPLASH[1]), (244, 97, SPLASH[2]), (258, 100, SPLASH[3])):
        c.put(x, y, col); c.put(x + 1, y, col)
    for x in (220, 228):
        c.rect(x, 88, x + 5, 95, hexc('b9c4c4'))
        for bx in (x + 1, x + 3):
            c.line(bx, 88, bx - 1 + (bx - x), 82, F.PINE[2])
    c.ellipse(250, 94, 9, 2, F.PINE[1])
    for (x, col) in ((244, SPLASH[0]), (248, SPLASH[1]), (252, SPLASH[2]), (256, SPLASH[4])):
        c.put(x, 94, col)
    # shelves of jars and rags on the right
    def _jars(l):
        F.shelves(l, 276, 310, 40, 100, F.PINE, [58, 78, 96], c.rng, fill=0.0)
        for (y, n) in ((58, 5), (78, 4), (96, 5)):
            for k in range(n):
                x = 280 + k * 6
                l.rect(x, y - 7, x + 4, y - 1, hexc('b9c4c4'))
                l.rect(x + 1, y - 5, x + 3, y - 2, SPLASH[(k + y) % len(SPLASH)])
    setback(c, _jars, depth=3, rake=1.0)
    F.bare_bulb(c, 160, 24)

E_ANCHORS = [('anchor_study_plan_chest', 26, 88, 'bp s'), ('anchor_study_paint_tins', 64, 94, 'bp s'),
             ('anchor_study_canvases', 124, 70, 'bp'), ('anchor_study_easel', 186, 104, ''),
             ('anchor_study_trestle', 240, 97, ''), ('anchor_right_shelf', 292, 70, 'bp')]


VARIANTS = {
    'b': ('study_b', 52, (b_wall, b_decor, b_floor, b_furniture, b_strip), B_ANCHORS),
    'c': ('study_c', 53, (c_wall, c_decor, c_floor, c_furniture, c_strip), C_ANCHORS),
    'd': ('study_d', 54, (d_wall, d_decor, d_floor, d_furniture, d_strip), D_ANCHORS),
    'e': ('study_e', 55, (e_wall, e_decor, e_floor, e_furniture, e_strip), E_ANCHORS),
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
        finish_module(name, 'study', seed, bare, floor, build, anchors, strip_fn=strip,
                      per_run=lambda r: setattr(C3, 'RUN', r))
