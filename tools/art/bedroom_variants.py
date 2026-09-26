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
from pixlib import persp
from pixlib import Canvas, hexc, shade, rrect, finish_module, pp, pbox
import furn as F

OUT = hexc('2a1c17')
SHEET = hexc('c9c2b1')
SHEET_DK = hexc('aaa293')
PILLOW = hexc('d8d1bf')
PILLOW_DK = hexc('b7af9c')
BLOOD = hexc('4a1d1b', 150)
CLOTH = [hexc('8a4a42'), hexc('4e5d70'), hexc('c1b69c'), hexc('5f6b4e'), hexc('7d6a8a'), hexc('2e2e33')]


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
    # posters you can read (owner round 14: the abstract colour blocks "don't really make any sense")
    F.poster_gig(c, 10, 18, 40, 48, 'ROCK', paper=hexc('e8dcc0'), ink=hexc('1e1e24'), spot=hexc('c8322a'))
    F.poster_film(c, 102, 22, 128, 58, 'NIGHT', torn=True)
    F.poster_map(c, 180, 26, 216, 50)
    F.poster_game(c, 278, 20, 308, 44, 'SPACE')
    F.sticky(c, 188, 54, 'EXAM', col=hexc('9ad0e0'))                                   # (was a stray scrawl)


@persp
def b_floor(c):
    F.floor_carpet(c, hexc('5a5f7a'), hexc('6a6f8a'), hexc('4a4f68'), worn=hexc('70748e'))


def _b_desk(c):
    # the desk against the wall (x < 50), SYMMETRIC (owner round 14: the monitor sat over a one-sided
    # pedestal and "goes over the right side… no symmetry"): a pedestal of drawers at each end, the
    # CRT centred on the top, the keyboard centred under it, two cans at the end
    x0, x1, cx = 6, 48, 27
    c.shadow(cx, 100, 22, 2, 100)
    c.rect(x0, 72, x1, 74, F.PINE[1])
    c.hline(x0, x1, 72, F.PINE[3])
    for (p0, p1) in ((x0 + 2, x0 + 12), (x1 - 12, x1 - 2)):
        c.box(p0, 75, p1, 99, F.PINE[0], F.PINE[3])
        for (d0, d1) in ((77, 84), (86, 93)):
            c.box(p0 + 2, d0, p1 - 2, d1, F.PINE[0], F.PINE[2])
            c.put((p0 + p1) // 2, (d0 + d1) // 2, F.BRASS)
    c.rect(x0 + 13, 75, x1 - 13, 77, F.PINE[2])                                            # the modesty rail
    c.box(cx - 11, 52, cx + 11, 70, hexc('c9c2b1'), hexc('6d6a60'))                        # CRT
    c.rect(cx - 8, 55, cx + 8, 66, hexc('22302c'))
    c.rect(cx - 6, 57, cx - 2, 58, hexc('3e524b'))
    c.rect(cx - 5, 70, cx + 5, 71, hexc('a9a496'))                                          # its foot
    c.rect(cx - 10, 69, cx + 10, 71, hexc('d8d2c2'))                                        # keyboard
    c.hline(cx - 9, cx + 9, 70, hexc('b8b2a2'))
    c.rect(x1 - 5, 67, x1 - 3, 71, hexc('b0453a'))                                          # a can


def b_furniture(c):
    from pixlib import setback
    setback(c, _b_desk, depth=5, top=72, x_range=(6, 48), rake=1.0)
    # the desk chair rolled back from the desk and swivelled toward the room (3D, like the study's) —
    # clear of the desk's back-plane spot, upright or knocked over (owner round 13b)
    import chair3d as C3
    C3.office_chair_at(c, 66, 118, -40, {'fab': hexc('2e2e34'), 'metal': hexc('3a3a3d')},
                       plan={3: 'down'}, key='bedroom_b_chair', outline=hexc('111114'))
    def _clothes(c):
        # a clothes pile + trainers dropped at the foot of the bed
        c.poly([(60, 118), (68, 110), (80, 108), (90, 112), (94, 119)], CLOTH[1])
        c.poly([(66, 118), (74, 112), (84, 114), (86, 120)], CLOTH[5])
        c.line(70, 113, 82, 117, shade(CLOTH[1], 0.8))
        c.rect(96, 116, 104, 119, hexc('e0dcd0')); c.hline(96, 104, 119, hexc('a8322c'))
    F.moved(c, _clothes, 72, -4)                                  # against the bed's foot
    def _beanbag(c):
        # a beanbag slumped against the wall under the posters
        c.shadow(128, 121, 16, 2, 110)
        c.poly([(112, 121), (113, 110), (120, 102), (132, 100), (142, 106), (146, 115), (144, 121)], hexc('a8522c'))
        c.poly([(116, 112), (124, 104), (132, 103), (126, 110)], shade(hexc('a8522c'), 1.15))
        c.line(118, 118, 140, 118, shade(hexc('a8522c'), 0.8))
        c.rect(128, 110, 134, 113, hexc('3a3a3d'))                                             # a controller on it
    F.moved(c, _beanbag, -12, -19)
    # the single bed on the RIGHT: headboard at the right end (kept clear of the crate's back-plane
    # spot in the corner)
    x0, x1 = 160, 282
    duvet = hexc('2f3a63')
    F.persp_bed(c, x0, x1, 114, head='right', head_top=70, foot_top=84,
                board=(F.PINE[0], F.PINE[1], F.PINE[3]), duvet=(duvet, hexc('252e50'), hexc('3f4c7a')))
    for (sx, sy) in ((170, 90), (184, 94), (198, 89), (212, 95), (226, 91), (178, 101), (206, 103)):
        c.put(sx, sy, hexc('d9c24a'))                                                       # stars
    c.box(200, 108, 220, 113, hexc('d9d0bc'), hexc('8a8270'))                               # a shoebox under it
    c.rect(204, 110, 208, 111, hexc('a8322c'))
    # a crate as a bedside table in the corner: a lava lamp, an alarm clock
    def _crate(c):
        c.shadow(301, 100, 10, 2, 90)
        c.box(292, 82, 310, 99, hexc('9a7a4e'), hexc('5e4a2e'))
        for gy in (86, 91, 96):
            c.hline(293, 309, gy, hexc('7c6140'))
        c.poly([(296, 81), (300, 66), (304, 81)], hexc('7a3a6a'))
        c.ellipse(300, 74, 2, 3, hexc('d98a4a')); c.ellipse(299, 78, 1, 1, hexc('d98a4a'))
        F.light(300, 74, 'lava')
        c.box(304, 76, 309, 81, hexc('26262a'), hexc('111114'))
        c.put(306, 78, hexc('c0453a'))
    setback(c, _crate, depth=3, top=82, x_range=(292, 310))
    F.flush_light(c, 148)                                                                  # the ceiling dome


B_ANCHORS = [('anchor_bedroom_desk', 28, 70, 'bp'), ('anchor_bedroom_desk_drawer', 14, 88, 'bp'),
             ('anchor_bedroom_clothes_pile', 150, 109, ''), ('anchor_bedroom_beanbag', 118, 90, 'bp'),
             ('anchor_bed_pillow', 260, 88, ''), ('anchor_floor_underbed', 210, 110, ''),
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
    # (owner round 17: pictures of people, words you can read) the wedding photo, sepia
    F.photo(c, 148, 32, 172, 50, [(hexc('e0c8a8'), hexc('5a4028'), hexc('f4f0e4'), 12),
                                  (hexc('d8b89a'), hexc('2a2420'), hexc('2e2e33'), 13)],
            bg=hexc('c8b89a'), ground=hexc('a8987a'), frame=hexc('6b4a2c'))
    c.line(160, 24, 146, 30, hexc('3b2718')); c.line(160, 24, 174, 30, hexc('3b2718'))
    c.box(192, 26, 212, 40, hexc('6b4a2c'), hexc('3b2718'))                                # a cross-stitch sampler
    c.rect(194, 28, 210, 38, hexc('e6ddc4'))
    F.text3(c, 194 + (17 - F.text3_width('HOME')) // 2, 29, 'HOME', hexc('a0505a'))
    for (hx, hy) in ((200, 35), (202, 35), (199, 36), (203, 36), (200, 36), (201, 36), (202, 36), (201, 37)):
        c.put(hx, hy, hexc('b0453a'))


@persp
def c_floor(c):
    F.floor_planks(c, [hexc('6b4f3a'), hexc('634835'), hexc('705440')], hexc('3f2d20'))


def iron_bed(c, x0, x1, base):
    iron, knob = hexc('2e2c2a'), F.BRASS
    # an iron bedstead in perspective (owner round 16): posts, rails and spindles running back to the
    # wall at both ends, a mattress + a patchwork quilt
    g = F.persp_bed(c, x0, x1, base, head='left', head_top=70, foot_top=80, board=(iron, shade(iron, 1.3), iron),
                    iron=True, knob=knob, duvet=(hexc('8a6a5a'), hexc('6e5446'), hexc('a0806e')), rail=True)
    for (qx, qy, col) in ((142, 90, hexc('a0505a')), (164, 93, hexc('5e6f58')), (186, 90, hexc('c9a06a')),
                          (152, 95, hexc('5e6f78')), (176, 96, hexc('a0505a')), (198, 94, hexc('5e6f58'))):
        c.rect(qx, qy, qx + 7, qy + 2, col)
    c.ellipse(120, 92, 3, 1, BLOOD)
    c.line(118, 96, 119, 104, BLOOD)


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
    # WITH DEPTH (owner round 14): the wardrobe (3px left, clear of window L), the pill cabinet
    from pixlib import setback
    setback(c, lambda l: F.moved(l, _c_wardrobe, -3, 0), depth=5, top=23, x_range=(4, 42), rake=1.0)
    _c_rest(c)
    setback(c, _c_cabinet, depth=4, top=76, x_range=(279, 305))
    F.flush_light(c, 167)                                                                  # a dome over the bed


def _c_wardrobe(c):
    # a tall wardrobe with a mirror door on the far left (x < 50)
    c.shadow(26, 100, 20, 2, 100)
    c.box(8, 26, 44, 99, F.WOOD[0], F.WOOD[3])
    c.rect(7, 23, 45, 26, F.WOOD[1])
    c.box(10, 30, 25, 94, F.WOOD[0], F.WOOD[2])
    c.box(27, 30, 42, 94, hexc('8b9aa0'), F.WOOD[2])
    c.line(30, 88, 39, 36, hexc('b8c3c4'))
    c.rect(24, 60, 25, 64, F.BRASS); c.rect(27, 60, 28, 64, F.BRASS)


def _c_rest(c):
    wheelchair(c, 58, 120)
    drip_stand(c, 104, 116)
    iron_bed(c, 108, 226, 116)
    # the medicine trolley pulled up beside the foot of the bed
    med_trolley(c, 230, 118)


def _c_cabinet(c):
    # a cabinet crowded with pill bottles, against the wall in the corner
    F.chest(c, 280, 304, 76, 100, F.WOOD, drawers=2)
    for (bx, h, col) in ((282, 6, hexc('c07a3a')), (286, 4, hexc('e0d9b8')), (290, 7, hexc('c07a3a')),
                         (294, 5, hexc('6f8fa0')), (298, 4, hexc('e0d9b8'))):
        c.rect(bx, 75 - h, bx + 2, 75, col)
    c.rect(300, 72, 303, 75, hexc('d9d0bc'))


C_ANCHORS = [('anchor_bedroom_wardrobe', 15, 60, 'bp'), ('anchor_bedroom_wheelchair', 72, 99, ''),
             ('anchor_bedroom_quilt', 170, 92, ''), ('anchor_bed_pillow', 124, 89, ''),
             ('anchor_bedroom_med_trolley', 239, 88, ''), ('anchor_bedroom_pill_cabinet', 292, 86, 'bp')]


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
    # (owner round 17: context) a front page taped to the wall, a missing poster, the days scratched
    # into the plaster, and a warning sprayed for anyone who comes in after
    F.newspaper(c, 102, 26, 'EVACUATE', sub='GO NORTH', w=36)
    F.missing_poster(c, 140, 28, name='LUCY')
    F.text_spray(c, 172, 30, 'NO FOOD', hexc('a8322c'))
    for i in range(7):
        c.vline(176 + i * 3, 50, 58, hexc('5a5244'))
    c.line(174, 56, 196, 52, hexc('5a5244'))


@persp
def d_floor(c):
    F.floor_planks(c, [hexc('5a4a3a'), hexc('524334'), hexc('604f3e')], hexc('33281e'))


def d_furniture(c):
    # WITH DEPTH (owner round 14): the crates (3px left, clear of window L), the boxes in the corner
    from pixlib import setback
    setback(c, lambda l: F.moved(l, _d_crates, -3, 0), depth=4, top=62, x_range=(5, 43), rake=1.0)
    setback(c, _d_boxes, depth=4, top=62, x_range=(276, 308))
    _d_rest(c)


def _d_boxes(c):
    # boxes stacked against the wall, right corner
    F.cardboard_box(c, 276, 308, 78, 99, open_flaps=False)
    F.cardboard_box(c, 282, 304, 62, 77, open_flaps=True, label=False)


def _d_crates(c):
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
    F.lantern(c, 42, 79)                                                                   # a battery lantern


def _d_rest(c):
    def _backpack(c):
        # a backpack dumped beside the head of the mattress
        c.shadow(70, 121, 10, 2, 110)
        c.poly([(60, 121), (61, 106), (66, 100), (76, 100), (80, 106), (80, 121)], hexc('4a5a3a'))
        c.rect(62, 110, 78, 116, hexc('3a4a2e'))
        c.line(64, 102, 64, 108, hexc('2e3a24')); c.line(76, 102, 76, 108, hexc('2e3a24'))
        c.rect(68, 99, 72, 101, hexc('2e3a24'))
    F.moved(c, _backpack, 20, -5)
    # the mattress on the floor, a sleeping bag half off it
    x0, x1 = 100, 204
    F.persp_bed(c, x0, x1, 116, head='left', low=True, sheet=(hexc('c9c0a8'), hexc('a89f88')))
    for x in range(x0 + 6, x1, 12):
        c.put(x, 114, hexc('8a8270'))                                                        # buttons
    F.floor_stain(c, 165, 107, 12, 2.5, hexc('9a8a5a'), seed=34)                              # a dried stain
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


D_ANCHORS = [('anchor_bedroom_crates', 23, 70, 'bp'), ('anchor_bedroom_backpack', 90, 103, ''),
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
    # (owner round 17: context) — each pencil tick has the age beside it, and her name at the top
    for (y, age) in ((84, '3'), (78, '4'), (72, '5'), (66, '6')):
        c.hline(100, 105, y, hexc('4a4a4a'))
        F.text3(c, 107, y - 2, age, hexc('5a5a5a'))
    F.text3(c, 100, 57, 'MIA', hexc('5a5a5a'))
    c.box(170, 24, 196, 46, hexc('e6e0cc'), hexc('8a8270'))                      # a crayon drawing
    c.line(174, 42, 180, 32, hexc('3a7a3a')); c.ellipse(186, 30, 3, 3, hexc('d9c24a'))
    for (x, col) in ((176, hexc('3a3a3a')), (182, hexc('3a3a3a')), (188, hexc('a8322c'))):
        c.vline(x, 36, 42, col); c.ellipse(x, 35, 1, 1, col)


@persp
def e_floor(c):
    F.floor_carpet(c, hexc('7a9ab0'), hexc('8aaac0'), hexc('6a8aa0'), worn=hexc('92b0c4'))


def e_furniture(c):
    # WITH DEPTH (owner round 14): the dollhouse table (3px left), the little wardrobe
    from pixlib import setback
    setback(c, lambda l: F.moved(l, _e_dollhouse, -3, 0), depth=4, top=80, x_range=(5, 43), rake=1.0)
    _e_toys_wall(c)
    _e_rest(c)
    setback(c, _e_wardrobe, depth=4, top=32, x_range=(278, 306), rake=1.0)
    import chair3d
    if chair3d.RUN >= 3:
        _e_night_blood(c)


def _e_dollhouse(c):
    # a dollhouse on a low table against the wall (x < 50)
    c.shadow(27, 100, 22, 2, 100)
    c.rect(8, 80, 46, 82, F.PINE[1]); c.rect(10, 83, 12, 99, F.PINE[2]); c.rect(42, 83, 44, 99, F.PINE[2])
    c.poly([(10, 58), (27, 44), (44, 58)], hexc('a8322c'))
    c.box(12, 58, 42, 79, hexc('e6e0cc'), hexc('8a8270'))
    c.rect(14, 60, 26, 68, hexc('7aa0c8')); c.rect(28, 60, 40, 68, hexc('d9a0b0'))
    c.rect(14, 70, 26, 78, hexc('d9c24a')); c.rect(28, 70, 40, 78, hexc('1e1a16'))           # one room dark
    c.rect(31, 73, 33, 77, hexc('e6ddc8'))                                                    # a tiny figure in it


# the child's room gets MORE TOYS (owner round 14: "I love the child's bedroom, add more toys") —
# each where a toy would be put away: on a wall shelf, stacked against the wall, sat on the bed
TOY_R, TOY_Y, TOY_B, TOY_G = hexc('c8423a'), hexc('e6c24a'), hexc('4a7ac0'), hexc('5aa05a')


def _block(c, x, y, col):
    c.box(x, y, x + 4, y + 4, col, shade(col, 0.6))
    c.put(x + 2, y + 2, hexc('f0ead8'))


def _e_toys_wall(c):
    # a painted shelf on brackets (clear of the window boxes: x 200..224): blocks, a bunny, a car
    c.rect(198, 56, 224, 57, hexc('e6e0cc'))
    c.hline(198, 224, 58, hexc('8a8270'))
    for bx in (201, 221):
        c.vline(bx, 59, 62, hexc('8a8270'))
    _block(c, 200, 51, TOY_R); _block(c, 205, 51, TOY_B); _block(c, 202, 46, TOY_Y)
    c.ellipse(214, 52, 3, 3, hexc('e8e2d8'))                                     # the bunny
    c.vline(212, 45, 49, hexc('e8e2d8')); c.vline(215, 45, 49, hexc('e8e2d8'))
    c.put(212, 46, hexc('e8a8b8')); c.put(215, 46, hexc('e8a8b8'))
    c.put(213, 51, hexc('1e1a16')); c.put(215, 51, hexc('1e1a16'))
    c.rect(218, 52, 223, 54, TOY_R); c.rect(219, 50, 222, 51, TOY_R)             # a toy car
    c.put(219, 55, hexc('1e1a16')); c.put(222, 55, hexc('1e1a16'))
    # a tower of blocks stacked against the wall beside the dollhouse table
    for i, (dx, col) in enumerate(((0, TOY_B), (5, TOY_R), (2, TOY_Y), (1, TOY_G))):
        _block(c, 50 + dx, 95 - (0 if i < 2 else 5 * (i - 1)), col)
    c.poly([(52, 85), (55, 80), (58, 85)], TOY_R)                                # a roof block on top
    # a ball against the wall under the window, by the wardrobe
    c.shadow(266, 100, 5, 1, 80)
    c.ellipse(266, 96, 4, 4, TOY_R)
    c.hline(262, 270, 96, hexc('f0ead8'))
    c.put(264, 94, hexc('f0a8a0'))


def _e_rest(c):
    F.pendant(c, 140, 20, 'white', dome=True)                                                 # a paper-shade pendant
    def _horse(c):
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
    F.moved(c, _horse, 0, -4)
    # a small bed with a teddy, pushed against the wall
    x0, x1 = 118, 196
    F.persp_bed(c, x0, x1, 114, head='left', head_top=76, foot_top=84,
                board=(hexc('e6e0cc'), hexc('f4f0e4'), hexc('8a8270')), duvet=(hexc('d98aa0'), hexc('b86a80'), hexc('e8a8b8')))
    c.ellipse(134, 86, 5, 5, hexc('9a6a3a')); c.ellipse(130, 81, 2, 2, hexc('9a6a3a'))       # the teddy
    c.ellipse(138, 81, 2, 2, hexc('9a6a3a')); c.put(133, 85, hexc('1e1a16')); c.put(136, 85, hexc('1e1a16'))
    c.ellipse(134, 93, 4, 3, hexc('9a6a3a'))
    c.line(130, 94, 140, 90, BLOOD)
    # a rag doll sat against the foot of the bed
    c.ellipse(184, 88, 2, 2, hexc('f0d8c0'))                                                 # head
    c.rect(182, 85, 186, 86, hexc('c87a3a'))                                                 # woollen hair
    c.put(183, 88, hexc('1e1a16')); c.put(185, 88, hexc('1e1a16'))
    c.poly([(181, 91), (187, 91), (189, 97), (179, 97)], hexc('7a9ad0'))                      # dress
    c.put(179, 97, hexc('f0d8c0')); c.put(189, 97, hexc('f0d8c0'))
    # a toy chest at the foot of the bed, lid up, toys piled inside (none strewn on the floor) — a real
    # box out on the carpet, seen from above (owner round 15: nothing painted flat)
    blue, blue_lt, blue_out = hexc('7aa0c8'), hexc('9ac0e0'), hexc('3a5a78')
    d0, d1 = 8, 16
    wx0 = 160 + (198 - 160) * 100.0 / (100 + d1)
    wx1 = 160 + (226 - 160) * 100.0 / (100 + d1)
    c.shadow(212, 117, 16, 2, 110)
    lb, lr_ = pp(wx0 + 1, 90, d0), pp(wx1 - 1, 90, d0)                   # the lid, standing open at the back
    lid = [(round(lb[0]), round(lb[1]) - 11), (round(lr_[0]), round(lr_[1]) - 11), (round(lr_[0]), round(lr_[1])),
           (round(lb[0]), round(lb[1]))]
    c.poly(lid, hexc('5a80a8'))
    c.line(lid[0][0], lid[0][1], lid[1][0], lid[1][1], blue_out)
    c.line(lid[0][0], lid[0][1], lid[3][0], lid[3][1], blue_out)
    c.line(lid[1][0], lid[1][1], lid[2][0], lid[2][1], blue_out)
    c.hline(lid[0][0] + 2, lid[1][0] - 2, lid[0][1] + 2, hexc('6f95bd'))
    f = pbox(c, wx0, 90, wx1, 100, d0, d1, blue, hexc('2a3a4e'), shade(blue, 0.72), blue_out)
    c.hline(f['fl'][0] + 1, f['fr'][0] - 1, f['fl'][1] + 1, blue_lt)
    c.hline(f['fl'][0] + 3, f['fr'][0] - 3, f['fbl'][1] - 3, shade(blue, 0.88))
    # toys piled inside, poking up over the rim
    c.rect(f['bl'][0] + 4, f['bl'][1] - 4, f['bl'][0] + 10, f['fl'][1] - 1, hexc('d9c24a'))
    c.hline(f['bl'][0] + 4, f['bl'][0] + 10, f['bl'][1] - 4, shade(hexc('d9c24a'), 1.15))
    c.ellipse(f['br'][0] - 8, f['br'][1] - 1, 3, 3, hexc('a8322c'))
    c.put(f['br'][0] - 9, f['br'][1] - 3, hexc('d8645c'))
    c.line(f['bl'][0] + 14, f['bl'][1] - 6, f['bl'][0] + 17, f['fl'][1] - 1, hexc('8a6a3a'))   # a wooden sword


def _e_wardrobe(c):
    # a small white wardrobe in the corner
    c.shadow(292, 100, 16, 2, 100)
    c.box(278, 36, 306, 99, hexc('e6e0cc'), hexc('8a8270'))
    c.vline(292, 38, 97, hexc('b9b3a4'))
    c.rect(289, 64, 290, 68, hexc('d9c24a')); c.rect(294, 64, 295, 68, hexc('d9c24a'))
    c.poly([(278, 36), (306, 36), (304, 32), (280, 32)], hexc('d98aa0'))


def _e_night_blood(c):
    # NIGHT (owner round 14: "it's grim but also in run 3 add more blood"): small handprints at a
    # child's height on the wall by the bed, the duvet soaked, spatter across the dollhouse, and a drag
    # trail over the carpet from the bed toward the wardrobe
    B1, B2, B3 = hexc('6a1812'), hexc('4a0e0c'), hexc('84241a')
    for (hx, hy) in ((104, 80), (112, 74), (206, 76)):                         # small hands, dragged down
        c.rect(hx, hy, hx + 3, hy + 3, B1)
        for k in range(4):
            c.vline(hx + k, hy - 3 + (k % 2), hy - 1, B1)
        c.put(hx + 4, hy + 1, B1)
        for k in range(1, 4):
            c.vline(hx + k, hy + 4, hy + 4 + (k * 3) % 7, B2)
    c.ellipse(160, 92, 16, 4, B2)                                              # the duvet, soaked
    c.ellipse(158, 91, 12, 3, B1)
    c.vline(170, 96, 103, B2); c.vline(148, 96, 101, B2)                       # dripping off the edge
    for (x, y) in ((16, 60), (21, 64), (27, 58), (33, 66), (24, 71), (37, 61), (14, 70)):
        c.put(x, y, B1)                                                         # spatter on the dollhouse
    c.rect(29, 62, 30, 63, B3)
    for x in range(176, 262):                                                   # the drag trail
        t = (x - 176) / 86.0
        y = 122 + int(3 * t)
        w = 3 - int(2 * t)
        for k in range(w):
            if (x * 5 + k) % 7:
                c.put(x, y + k, B1 if k else B2)
    for x in range(200, 256, 9):                                                # small bloody footprints
        c.rect(x, 128 - (x // 9) % 2 * 3, x + 1, 130 - (x // 9) % 2 * 3, B2)


E_ANCHORS = [('anchor_bedroom_dollhouse', 31, 74, 'bp'), ('anchor_bedroom_rocking_horse', 76, 98, ''),
             ('anchor_bed_pillow', 134, 88, ''), ('anchor_bedroom_toy_chest', 212, 107, ''),
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
        import chair3d
        finish_module(name, 'bedroom', seed, bare, floor, build, anchors,
                      per_run=lambda r: setattr(chair3d, 'RUN', r))
