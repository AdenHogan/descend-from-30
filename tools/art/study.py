"""Study module — 320 x 144 native pixel art, in the living room's style.

Run:  python3 tools/art/study.py
Out:  assets/rooms/study.png (+ study_floor.png, docs preview)

Layout (left -> right): x 4..96 is where the BALCONY doors go on a balcony slot (the scene's Balcony
node draws over the art there), so it only holds a radiator and a box of files — nothing a node
needs. Then a tall bookcase against the wall (nodes: upper + lower shelves), a writing desk with a
green lamp and a pinned-up wall of notes above it (node: the desk top), its chair pulled out, a
rug, a pile of papers under the R window box, and shelving over a filing cabinet in the right
corner (node). Dark panelling below a deep green paper; parquet that repeats every 32px.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import (Canvas, hexc, shade, W, H, check_window_boxes, check_edge_columns,
                    save_floor_strip, floor_is_periodic, rrect, finish_module)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SEED = 51

PAPER = hexc('3f5448')          # deep green paper
PAPER_DK = hexc('374a3f')
PAPER_STRIPE = hexc('465c4f')
CROWN = hexc('2f3a33')
CROWN_HI = hexc('45524a')
PANEL = hexc('4a3426')          # dark wood panelling (dado)
PANEL_DK = hexc('3a281d')
PANEL_LT = hexc('5c4231')
RAIL = hexc('604433')
RAIL_HI = hexc('77573f')
SEAM = hexc('211712')

PARQ_A = hexc('6b4a31')         # parquet
PARQ_B = hexc('624430')
PARQ_LINE = hexc('48311f')

WOOD = hexc('5a3b27')
WOOD_DK = hexc('432b1c')
WOOD_LT = hexc('70503a')
WOOD_OUT = hexc('26180f')
BRASS = hexc('b09456')
LEATHER = hexc('6e2f26')
LEATHER_DK = hexc('55231c')
LEATHER_LT = hexc('84403a')
GREEN_GLASS = hexc('3f7a52')
GREEN_GLASS_LT = hexc('5e9c72')
NOTE = hexc('d8cfb4')
NOTE_DK = hexc('b7ad92')
CORK = hexc('9a7650')
CORK_DK = hexc('7e5e3e')
METAL = hexc('6f7572')
METAL_DK = hexc('565b59')
METAL_LT = hexc('878d89')
RUG = hexc('6a2f2c')
RUG_DK = hexc('55241f')
RUG_PAT = hexc('a58a5a')
RED_STRING = hexc('a8322c')
DAMP = hexc('2e3b33', 70)
BLOOD = hexc('4a1d1b', 150)
BOOKS = [hexc('7a2e28'), hexc('2f4a63'), hexc('5d6b3a'), hexc('8a6a3a'), hexc('4b3a5c'),
         hexc('b8a782'), hexc('3b5550'), hexc('6b4a36'), hexc('9c4f33')]


def wall(c):
    c.rect(0, 0, W - 1, 93, PAPER)
    for x in range(0, W, 8):                          # a narrow two-tone stripe, 8px period
        c.vline(x + 5, 12, 57, PAPER_STRIPE)
    c.rect(0, 6, W - 1, 8, PAPER_DK)
    c.dither(0, 9, W - 1, 13, PAPER_DK, 0.5)
    c.rect(0, 0, W - 1, 4, CROWN)
    c.hline(0, W - 1, 4, CROWN_HI)
    c.hline(0, W - 1, 5, shade(CROWN, 0.8))
    # the dado: a moulded rail, raised panels, a deep skirting
    c.rect(0, 58, W - 1, 93, PANEL)
    c.rect(0, 58, W - 1, 60, RAIL)
    c.hline(0, W - 1, 58, RAIL_HI)
    c.hline(0, W - 1, 61, PANEL_DK)
    for x in range(0, W, 32):
        c.box(x + 4, 65, x + 27, 89, PANEL, PANEL_DK)
        c.hline(x + 5, x + 26, 66, PANEL_LT)
        c.vline(x + 5, 66, 88, PANEL_LT)
    c.rect(0, 94, W - 1, 99, PANEL_DK)
    c.hline(0, W - 1, 94, PANEL_LT)
    c.hline(0, W - 1, 99, SEAM)


def decay(c):
    # damp bleeding down the paper from the ceiling, and a gouge in the panelling
    for i in range(6):
        c.ellipse(196 + i * 6, 16 + (i % 2) * 4, 7, 5, DAMP)
    c.dither(8, 6, 40, 18, DAMP, 0.4, pattern='random')
    c.line(248, 72, 256, 80, PANEL_DK)
    c.line(256, 80, 254, 86, PANEL_DK)


def floor(c):
    # parquet: 16px blocks laid in alternating directions, rows staggered; repeats every 32px
    c.rect(0, 100, W - 1, H - 1, PARQ_A)
    rows = [100, 105, 111, 118, 126, 135, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        off = 0 if r % 2 == 0 else 16
        for x in range(0, W + 32, 32):
            bx = x - off
            # a block of boards running across, then one of boards running into the room
            c.rect(bx, y0, bx + 15, y1, PARQ_A)
            for yy in range(y0 + 2, y1, 3):
                c.hline(bx, bx + 15, yy, PARQ_B)
            c.rect(bx + 16, y0, bx + 31, y1, PARQ_B)
            for xx in range(bx + 20, bx + 32, 4):
                c.vline(xx, y0, y1, PARQ_A)
            c.vline(bx, y0, y1, PARQ_LINE)
            c.vline(bx + 16, y0, y1, PARQ_LINE)
        c.hline(0, W - 1, y0, PARQ_LINE)
    c.hline(0, W - 1, 100, shade(PARQ_A, 0.5))
    c.hline(0, W - 1, 101, shade(PARQ_A, 0.72))


# --- the balcony strip (x 4..96): only things the balcony may cover ---------------------------
def radiator(c):
    # under the L window box (y > 66)
    x0, x1, top, base = 54, 90, 74, 97
    c.shadow(72, 100, 18, 2, 80)
    c.box(x0, top, x1, base, METAL, METAL_DK)
    for x in range(x0 + 3, x1 - 1, 4):
        c.vline(x, top + 2, base - 2, METAL_DK)
        c.vline(x + 1, top + 2, base - 2, METAL_LT)
    c.rect(x0 - 3, base - 3, x0 - 1, base - 1, METAL_DK)          # the valve
    c.dither(x0 + 2, base - 4, x1 - 2, base - 1, hexc('7a4a2e', 150), 0.4, pattern='random')


def file_boxes(c):
    # two archive boxes stacked against the wall, the top one's lid off
    c.shadow(28, 100, 20, 2, 90)
    c.box(12, 82, 44, 99, hexc('9a8a66'), hexc('4d4230'))
    c.rect(24, 88, 32, 92, NOTE)
    c.box(16, 68, 40, 81, hexc('a89770'), hexc('4d4230'))
    c.rect(18, 66, 22, 70, NOTE)                                    # files sticking out
    c.rect(24, 65, 27, 69, hexc('c9b58a'))
    c.rect(30, 66, 35, 70, NOTE_DK)


# --- the room ---------------------------------------------------------------------------------
def bookcase(c):
    # floor to near-ceiling between the window boxes (nodes: an upper and a lower shelf)
    x0, x1, top, base = 100, 140, 14, 100
    c.shadow(120, base, 22, 2, 100)
    c.box(x0, top, x1, base - 1, WOOD, WOOD_OUT)
    c.rect(x0 - 1, top - 2, x1 + 1, top, WOOD_LT)                    # cornice
    c.hline(x0 - 1, x1 + 1, top - 2, shade(WOOD_LT, 1.1))
    c.rect(x0 + 2, top + 2, x1 - 2, base - 6, hexc('24180f'))        # the dark inside
    shelves = [top + 2, 30, 46, 62, 78, base - 6]
    for i in range(len(shelves) - 1):
        s0, s1 = shelves[i], shelves[i + 1]
        x = x0 + 3
        while x < x1 - 3:
            bw = c.rng.choice((2, 2, 3, 3, 4))
            if x + bw > x1 - 3:
                break
            if c.rng.random() < 0.12 and i != 1:                      # a gap — books taken
                x += bw + 1
                continue
            bh = c.rng.randint(9, 13)
            col = c.rng.choice(BOOKS)
            if c.rng.random() < 0.15:                                  # one leaning over
                c.poly([(x, s1 - 1), (x + bw, s1 - 1), (x + bw + 4, s1 - bh + 1), (x + 4 - bw // 2, s1 - bh + 1)], col)
                x += bw + 5
                continue
            c.rect(x, s1 - bh, x + bw - 1, s1 - 1, col)
            c.hline(x, x + bw - 1, s1 - bh + 2, shade(col, 1.2))
            x += bw
        c.rect(x0 + 2, s1, x1 - 2, s1 + 1, WOOD_LT)                     # the shelf board
    c.rect(x0 + 2, base - 5, x1 - 2, base - 2, WOOD_DK)                  # plinth
    # a skull-less memento: a small brass carriage clock on the upper shelf, stopped
    c.box(128, 39, 135, 45, BRASS, hexc('5e4c28'))
    c.rect(130, 41, 133, 43, NOTE)


def board(c):
    # pinned-up notes over the desk, strung together — someone was working something out
    x0, x1, y0, y1 = 158, 212, 22, 52
    c.box(x0, y0, x1, y1, CORK, WOOD_OUT)
    c.dither(x0 + 1, y0 + 1, x1 - 1, y1 - 1, CORK_DK, 0.3, pattern='random')
    notes = [(162, 26, 172, 36), (178, 25, 190, 33), (196, 28, 208, 38), (166, 40, 178, 49),
             (186, 38, 196, 48), (200, 42, 209, 50)]
    for (a, b, cx, d) in notes:
        c.rect(a, b, cx, d, NOTE)
        c.hline(a, cx, d, NOTE_DK)
        for yy in range(b + 3, d - 1, 2):
            c.hline(a + 2, cx - 2 - (yy % 3), yy, NOTE_DK)
    c.rect(180, 27, 186, 31, hexc('7c8c90'))                              # a photo
    pins = [(167, 27), (184, 26), (202, 29), (172, 41), (191, 39), (204, 43)]
    for i in range(len(pins) - 1):                                         # the red string
        c.line(pins[i][0], pins[i][1], pins[i + 1][0], pins[i + 1][1], RED_STRING)
    for (px, py) in pins:
        c.put(px, py, hexc('d9c24a'))
    c.rect(200, 42, 209, 50, shade(NOTE, 0.9))
    c.line(201, 44, 207, 48, BLOOD)                                        # a note smeared


def desk(c):
    """A pedestal desk pulled out into the room, facing us (node: the desk top): two banks of
    drawers and a panel between, the top seen from a little above, a green banker's lamp, papers.
    The chair is tucked in BEHIND it (drawn first) — only its studded back shows over the top."""
    x0, x1, top, base = 146, 218, 90, 117
    # the chair behind
    c.box(172, 70, 192, 90, LEATHER, hexc('2d1410'))
    c.hline(173, 191, 71, LEATHER_LT)
    for x in range(174, 191, 3):
        c.put(x, 73, BRASS)
    c.shadow(182, base + 1, 40, 3, 110)
    # the top
    c.rect(x0 - 2, top, x1 + 2, top + 4, WOOD_LT)
    c.hline(x0 - 2, x1 + 2, top, shade(WOOD_LT, 1.12))
    c.rect(x0 + 12, top + 1, x1 - 12, top + 3, hexc('3d5a44'))             # leather inlay
    c.hline(x0 - 2, x1 + 2, top + 4, WOOD_OUT)
    # two pedestals of drawers + the modesty panel between them
    for (p0, p1) in ((x0, x0 + 20), (x1 - 20, x1)):
        c.box(p0, top + 5, p1, base - 1, WOOD, WOOD_OUT)
        for (d0, d1) in ((top + 7, top + 12), (top + 14, top + 19), (top + 21, base - 3)):
            c.box(p0 + 2, d0, p1 - 2, d1, WOOD, WOOD_DK)
            c.hline(p0 + 3, p1 - 3, d0 + 1, WOOD_LT)
            c.rect((p0 + p1) // 2 - 1, (d0 + d1) // 2, (p0 + p1) // 2 + 1, (d0 + d1) // 2, BRASS)
    c.box(x0 + 21, top + 5, x1 - 21, base - 6, WOOD_DK, WOOD_OUT)
    c.box(x0 + 24, top + 8, x1 - 24, base - 9, WOOD_DK, shade(WOOD_DK, 0.8))
    c.rect(x0 + 21, base - 5, x1 - 21, base - 1, hexc('2a1d14'))           # the dark gap under it
    # one drawer pulled out, papers spilling from it
    c.poly([(x1 - 18, top + 14), (x1 - 2, top + 14), (x1 + 1, top + 20), (x1 - 17, top + 20)], WOOD_DK)
    c.rect(x1 - 16, top + 13, x1 - 3, top + 14, NOTE)
    c.poly([(x1 + 1, top + 20), (x1 + 8, top + 24), (x1 + 6, base), (x1 + 2, base - 2)], NOTE_DK)
    # on the top: the lamp (left), papers, a mug, a pen
    c.rect(152, top - 2, 160, top - 1, BRASS)
    c.vline(156, top - 13, top - 3, BRASS)
    c.poly([(148, top - 13), (164, top - 13), (162, top - 18), (150, top - 18)], GREEN_GLASS)
    c.hline(150, 162, top - 17, GREEN_GLASS_LT)
    c.poly([(176, top - 1), (196, top - 1), (198, top - 5), (178, top - 5)], NOTE)
    c.hline(178, 197, top - 3, NOTE_DK)
    c.line(186, top - 2, 192, top - 4, BLOOD)
    c.rect(204, top - 5, 208, top - 1, hexc('c9c2b1'))
    c.put(209, top - 3, hexc('c9c2b1'))
    c.rect(170, top - 2, 173, top - 1, hexc('2b2622'))


def chair(c):
    pass            # (the chair is drawn with the desk — tucked in behind it)


def rug(c):
    # a worn oriental rug in front of the desk (floor furniture — not part of the floor strip)
    c.poly([(146, 104), (238, 104), (246, 124), (138, 124)], RUG)
    c.poly([(150, 106), (234, 106), (240, 122), (144, 122)], RUG_DK)
    c.poly([(154, 108), (230, 108), (235, 120), (149, 120)], RUG)
    for x in range(156, 230, 8):
        c.put(x, 111, RUG_PAT); c.put(x + 2, 116, RUG_PAT)
    c.hline(148, 236, 105, RUG_PAT)
    c.hline(141, 243, 123, RUG_PAT)
    for x in range(138, 247, 2):                                            # fringe
        c.put(x, 125, RUG_PAT)
    c.dither(160, 110, 200, 118, hexc('3c1a17', 120), 0.3, pattern='random')   # a dark stain


def paper_pile(c):
    # newspapers and a toppled stack of books under the R window box (y > 66)
    c.shadow(246, 101, 16, 2, 90)
    for i, col in enumerate((NOTE, NOTE_DK, hexc('cfc5a6'), NOTE)):
        y = 97 - i * 3
        c.rect(232 + i, y, 256 - i, y + 2, col)
        c.hline(232 + i, 256 - i, y + 2, NOTE_DK)
    c.rect(258, 90, 266, 99, BOOKS[1])
    c.rect(259, 86, 267, 89, BOOKS[0])
    c.poly([(260, 80), (267, 83), (266, 86), (259, 85)], BOOKS[3])


def right_shelf(c):
    # shelving over a filing cabinet in the corner, right of the R window box (node: the shelves)
    x0, x1 = 274, 310
    c.shadow(292, 100, 20, 2, 100)
    # the filing cabinet
    c.box(x0 + 2, 62, x1 - 2, 99, METAL, METAL_DK)
    for (d0, d1) in ((64, 75), (77, 88), (90, 97)):
        c.box(x0 + 4, d0, x1 - 4, d1, METAL, METAL_DK)
        c.hline(x0 + 5, x1 - 5, d0 + 1, METAL_LT)
        c.rect(290, d0 + 3, 294, d0 + 4, METAL_LT)
        c.rect(286, d0 + 6, 290, d0 + 8, NOTE)                                 # card labels
    c.poly([(x0 + 4, 77), (x1 - 4, 77), (x1 - 2, 82), (x0 + 2, 82)], METAL_DK)  # a drawer yanked open
    c.rect(x0 + 6, 74, x1 - 6, 77, NOTE)
    # two wall shelves above, on brackets
    for sy in (24, 44):
        c.rect(x0, sy, x1, sy + 1, WOOD_LT)
        c.hline(x0, x1, sy + 2, WOOD_OUT)
        c.line(x0 + 3, sy + 3, x0 + 6, sy + 6, WOOD_DK)
        c.line(x1 - 3, sy + 3, x1 - 6, sy + 6, WOOD_DK)
    x = x0 + 2
    for w_, h_, col in ((3, 12, BOOKS[4]), (3, 11, BOOKS[6]), (4, 13, BOOKS[2]), (3, 12, BOOKS[8])):
        c.rect(x, 24 - h_, x + w_ - 1, 23, col)
        x += w_
    c.box(x0 + 20, 14, x1 - 2, 23, hexc('9a8a66'), hexc('4d4230'))           # a box of tapes
    c.rect(x0 + 2, 36, x0 + 16, 43, hexc('3e3a36'))                           # an old radio
    c.rect(x0 + 4, 38, x0 + 9, 41, METAL_LT)
    c.put(x0 + 13, 39, BRASS)
    c.rect(x0 + 22, 34, x0 + 28, 43, BOOKS[5])
    c.rect(x0 + 29, 36, x0 + 33, 43, BOOKS[1])


def book_pile(c):
    """Books pulled off the shelves and piled on the floor (balcony strip, node) — strip() moves it
    against the radiator."""
    c.shadow(72, 118, 14, 2, 110)
    for i, (w_, col) in enumerate(((24, BOOKS[1]), (22, BOOKS[0]), (20, BOOKS[3]), (18, BOOKS[6]), (15, BOOKS[4]))):
        y = 115 - i * 3
        x = 60 + (i % 2) * 2
        c.rect(x, y, x + w_, y + 2, col)
        c.hline(x, x + w_, y, shade(col, 1.18))
        c.vline(x + w_, y, y + 2, shade(col, 0.75))
    c.poly([(84, 102), (92, 99), (94, 103), (86, 106)], BOOKS[5])            # one fallen open
    c.line(89, 100, 90, 104, NOTE_DK)


def strip(c):
    import furn as F
    file_boxes(c)
    radiator(c)
    F.moved(c, book_pile, -12, -16)            # piled on the floor against the radiator, not out in the room


def build(c=None):
    c = c or Canvas(seed=SEED)
    wall(c)
    decay(c)
    floor(c)
    rug(c)
    bookcase(c)
    board(c)
    paper_pile(c)
    right_shelf(c)
    desk(c)
    return c


def bare(c):
    wall(c)
    decay(c)


ANCHORS = [('anchor_centre_bookcaseupper', 114, 42, 'bp'), ('anchor_centre_bookcaselower', 126, 70, 'bp'),
           ('anchor_centre_desk', 188, 88, ''), ('anchor_study_desk_drawer', 208, 105, ''),
           ('anchor_study_papers', 244, 94, ''), ('anchor_right_shelf', 284, 40, 'bp'),
           ('anchor_study_filing', 292, 76, 'bp'),
           ('anchor_study_file_boxes', 28, 88, 'bp s'), ('anchor_study_book_pile', 60, 94, 'bp s')]


if __name__ == '__main__':
    finish_module('study', 'study', SEED, bare, floor, build, ANCHORS, strip_fn=strip)
