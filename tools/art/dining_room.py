"""Dining room module — 320 x 144 native pixel art, in the living room's style.

Run:  python3 tools/art/dining_room.py
Out:  assets/rooms/dining_room.png (+ dining_room_floor.png, docs preview)

Layout (left -> right): x 4..96 is where the BALCONY doors go on a balcony slot (the scene's Balcony
node draws over the art there), so it only holds a low sideboard and a radiator. Then the dining
table pulled forward to the lane like the bed and the bath, a meal abandoned on it (nodes: either end
of the table top), chairs behind it and one knocked over in front; a pendant lamp and two pictures
above it; a dead plant under the R window box; and a Welsh dresser in the right corner (nodes: the
plate rack drawers, the cupboard below). Damask paper over a painted wainscot; boards that repeat
every 32px.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import (Canvas, hexc, shade, W, H, check_window_boxes, check_edge_columns,
                    save_floor_strip, floor_is_periodic, rrect, finish_module)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SEED = 61

PAPER = hexc('7a5a4c')          # faded rose damask
PAPER_MOTIF = hexc('86665a')
PAPER_MOTIF2 = hexc('6e5045')
PAPER_TOP = hexc('6c4f43')
CROWN = hexc('4c3a33')
CROWN_HI = hexc('625047')
WAINS = hexc('b3a88f')          # painted wainscot, gone yellow
WAINS_DK = hexc('9a8f77')
WAINS_LT = hexc('c4baa2')
RAIL = hexc('5c4436')
RAIL_HI = hexc('745746')
SKIRT = hexc('3e2d23')
SKIRT_HI = hexc('56433a')
SEAM = hexc('241a14')

BOARD = hexc('4f3a2b')          # dark stained boards
BOARD_DK = hexc('44321f')
BOARD_LT = hexc('5a4332')
BOARD_LINE = hexc('33251a')

WOOD = hexc('5e3d28')
WOOD_DK = hexc('472d1d')
WOOD_LT = hexc('76513a')
WOOD_OUT = hexc('27180f')
BRASS = hexc('b09456')
CLOTH = hexc('d6d0bf')          # tablecloth
CLOTH_DK = hexc('b9b2a0')
CLOTH_LT = hexc('e6e1d3')
PLATE = hexc('e8e4d8')
PLATE_DK = hexc('c3beb0')
PLATE_BLUE = hexc('5f7896')
FOOD = hexc('6b4a2f')
MOULD = hexc('7d8a5a')
WINE = hexc('5a1a22', 200)
GLASS = hexc('b6c4c6')
CANDLE = hexc('e3dcc6')
METAL = hexc('6f7572')
METAL_DK = hexc('565b59')
METAL_LT = hexc('878d89')
SHADE = hexc('c9ab7e')
SHADE_DK = hexc('a88c62')
FRAME = hexc('7a5a2a')
FRAME_DK = hexc('3b2718')
LEAF_DEAD = hexc('7a6a3e')
LEAF_DEAD2 = hexc('5f5231')
POT = hexc('9a5a3a')
DAMP = hexc('4f3d36', 70)
BLOOD = hexc('4a1d1b', 150)


def wall(c):
    c.rect(0, 0, W - 1, 93, PAPER)
    # damask: a small diamond-and-dot motif on a 16px grid, staggered rows
    for y in range(18, 56, 12):
        off = 0 if ((y - 18) // 12) % 2 == 0 else 8
        for x in range(off + 4, W, 16):
            c.put(x, y, PAPER_MOTIF)
            c.put(x - 1, y + 1, PAPER_MOTIF); c.put(x + 1, y + 1, PAPER_MOTIF)
            c.put(x - 2, y + 2, PAPER_MOTIF2); c.put(x + 2, y + 2, PAPER_MOTIF2)
            c.put(x - 1, y + 3, PAPER_MOTIF); c.put(x + 1, y + 3, PAPER_MOTIF)
            c.put(x, y + 4, PAPER_MOTIF)
            c.put(x, y + 2, PAPER_MOTIF2)
    c.rect(0, 6, W - 1, 8, PAPER_TOP)
    c.dither(0, 9, W - 1, 13, PAPER_TOP, 0.5)
    c.rect(0, 0, W - 1, 4, CROWN)
    c.hline(0, W - 1, 4, CROWN_HI)
    c.hline(0, W - 1, 5, shade(CROWN, 0.8))
    # the wainscot: a dado rail, tongue-and-groove boards painted cream
    c.rect(0, 60, W - 1, 93, WAINS)
    for x in range(0, W, 8):
        c.vline(x, 64, 93, WAINS_DK)
        c.vline(x + 1, 64, 93, WAINS_LT)
    c.rect(0, 60, W - 1, 63, RAIL)
    c.hline(0, W - 1, 60, RAIL_HI)
    c.hline(0, W - 1, 64, shade(WAINS, 0.8))
    c.rect(0, 94, W - 1, 99, SKIRT)
    c.hline(0, W - 1, 94, SKIRT_HI)
    c.hline(0, W - 1, 99, SEAM)


def decay(c):
    # damp stains + a strip of paper peeling off, the wainscot scuffed and chipped
    for i in range(7):
        c.ellipse(236 + i * 6, 16 + (i % 3) * 3, 8, 5, DAMP)
    c.poly([(208, 20), (216, 18), (214, 36), (209, 40)], shade(PAPER, 1.12))
    c.line(209, 40, 214, 36, PAPER_MOTIF2)
    for x in (110, 176, 238):
        c.dither(x, 84, x + 6, 92, WAINS_DK, 0.5)
    c.dither(0, 6, 26, 16, DAMP, 0.5, pattern='random')


def floor(c):
    # dark boards running along the room, joints staggered on a 32px cycle
    c.rect(0, 100, W - 1, H - 1, BOARD)
    rows = [100, 104, 109, 115, 122, 130, 139, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        col = (BOARD, BOARD_DK, BOARD_LT)[r % 3]
        c.rect(0, y0, W - 1, y1, col)
        c.hline(0, W - 1, y0, BOARD_LINE)
        j = (r * 11) % 32
        for x in range(j, W, 32):
            c.vline(x, y0, y1, BOARD_LINE)
        for x in range(W):                                    # grain, 32-periodic
            if (x * 5 + r * 7) % 32 in (2, 17) and y1 - y0 > 3:
                c.put(x, y0 + 2, shade(col, 0.88))
    c.hline(0, W - 1, 100, shade(BOARD, 0.55))
    c.hline(0, W - 1, 101, shade(BOARD, 0.75))


# --- the balcony strip (x 4..96): only things the balcony may cover ---------------------------
def sideboard(c):
    # a low sideboard left of the L window box, candlesticks and a fruit bowl gone to rot
    x0, x1, top, base = 8, 46, 70, 100
    c.shadow(27, base, 20, 2, 90)
    c.rect(x0 - 1, top, x1 + 1, top + 2, WOOD_LT)
    c.hline(x0 - 1, x1 + 1, top, shade(WOOD_LT, 1.1))
    c.box(x0, top + 3, x1, base - 5, WOOD, WOOD_OUT)
    c.box(x0 + 2, top + 5, 26, base - 7, WOOD, WOOD_DK)
    c.box(28, top + 5, x1 - 2, base - 7, WOOD, WOOD_DK)
    c.rect(24, top + 13, 25, top + 15, BRASS)
    c.rect(29, top + 13, 30, top + 15, BRASS)
    c.rect(x0 + 1, base - 4, x0 + 3, base - 1, WOOD_DK)
    c.rect(x1 - 3, base - 4, x1 - 1, base - 1, WOOD_DK)
    for cx in (13, 41):                                       # candlesticks
        c.rect(cx - 2, top - 1, cx + 2, top - 1, BRASS)
        c.vline(cx, top - 6, top - 2, BRASS)
        c.rect(cx - 1, top - 11, cx + 1, top - 7, CANDLE)
    c.ellipse(27, top - 2, 7, 2, PLATE_DK)                     # the bowl
    c.put(24, top - 4, MOULD); c.put(27, top - 5, MOULD); c.put(30, top - 4, FOOD); c.put(26, top - 4, FOOD)


def radiator(c):
    x0, x1, top, base = 56, 90, 76, 97
    c.shadow(73, 100, 17, 2, 80)
    c.box(x0, top, x1, base, METAL, METAL_DK)
    for x in range(x0 + 3, x1 - 1, 4):
        c.vline(x, top + 2, base - 2, METAL_DK)
        c.vline(x + 1, top + 2, base - 2, METAL_LT)


# --- the room ---------------------------------------------------------------------------------
def pictures(c):
    # a pendant lamp over the table, a landscape and a small portrait either side of it
    c.box(104, 22, 132, 42, FRAME, FRAME_DK)                  # landscape
    c.rect(107, 25, 129, 32, hexc('8a9aa0'))
    c.rect(107, 33, 129, 39, hexc('5f6e4a'))
    c.poly([(107, 33), (114, 28), (121, 33)], hexc('6c7a78'))
    c.line(118, 16, 104, 22, FRAME_DK); c.line(118, 16, 132, 22, FRAME_DK)
    c.box(184, 24, 200, 44, FRAME, FRAME_DK)                  # portrait, face scratched out
    c.rect(187, 27, 197, 41, hexc('6b5a4a'))
    c.ellipse(192, 32, 3, 3, hexc('a58c74'))
    c.rect(189, 36, 195, 41, hexc('3d3430'))
    c.line(189, 29, 195, 35, hexc('d8d0c0')); c.line(195, 29, 189, 35, hexc('d8d0c0'))
    c.put(192, 18, FRAME_DK)
    # the pendant lamp: a cord from the ceiling, a fabric shade
    c.vline(158, 5, 38, hexc('2a2622'))
    c.rect(156, 37, 160, 39, BRASS)
    c.poly([(150, 40), (166, 40), (170, 48), (146, 48)], SHADE)
    c.hline(146, 170, 48, SHADE_DK)
    c.hline(151, 165, 41, shade(SHADE, 1.1))
    from pixlib import light
    light(158, 46, 'pendant')


def back_chairs(c):
    # two chairs tucked in behind the table: only their ladder backs show above the top
    for x0 in (134, 184):
        c.rect(x0, 66, x0 + 2, 88, WOOD_DK)
        c.rect(x0 + 16, 66, x0 + 18, 88, WOOD_DK)
        c.rect(x0, 65, x0 + 18, 67, WOOD)
        c.hline(x0, x0 + 18, 65, WOOD_LT)
        for ry in (72, 78):
            c.rect(x0 + 3, ry, x0 + 15, ry + 1, WOOD)


def table(c):
    # pulled forward to the lane (base 114); we look down onto the cloth-covered top (86..95), the
    # cloth hangs over the front edge; a meal left half-eaten (nodes: either end of the top)
    x0, x1, top, front, base = 118, 214, 86, 95, 114
    c.shadow(159, base + 1, 58, 3, 110)
    c.rect(x0 + 4, front, x0 + 7, base, WOOD_DK)                 # legs
    c.rect(x1 - 7, front, x1 - 4, base, WOOD_DK)
    c.rect(x0 + 20, front, x0 + 22, base - 4, shade(WOOD_DK, 0.8))   # the far legs, set back
    c.rect(x1 - 22, front, x1 - 20, base - 4, shade(WOOD_DK, 0.8))
    c.rect(x0, top, x1, front, CLOTH)                            # the top
    c.hline(x0, x1, top, CLOTH_DK)
    c.hline(x0 + 1, x1 - 1, top + 1, CLOTH_LT)
    hem = [104, 105, 105, 104, 103, 104, 105, 106, 105, 104]
    for x in range(x0, x1 + 1):                                  # the drop over the front edge
        h = hem[(x // 11) % len(hem)]
        c.vline(x, front + 1, h, CLOTH_DK if (x - x0) % 13 in (0, 1) else CLOTH)
        c.put(x, h, shade(CLOTH_DK, 0.9))
    c.hline(x0, x1, front + 1, CLOTH_LT)
    c.dither(x0 + 2, front + 5, x1 - 2, 103, CLOTH_DK, 0.3)
    # the meal: plates, a tureen, glasses, a candle burnt down, a spill of wine
    for (px, py) in ((132, 90), (162, 89), (200, 90)):
        c.ellipse(px, py, 7, 2, PLATE_DK)
        c.ellipse(px, py, 6, 1, PLATE)
        c.hline(px - 3, px + 2, py, FOOD)
    c.put(201, 90, MOULD); c.put(133, 89, MOULD)
    c.ellipse(182, 88, 8, 3, WINE)                               # the spill, running off the edge
    c.vline(185, 95, 101, WINE); c.put(185, 102, WINE)
    c.rect(175, 84, 177, 88, GLASS)                              # a glass, one knocked over
    c.poly([(188, 90), (196, 89), (196, 91), (188, 92)], GLASS)
    c.box(142, 80, 152, 88, PLATE, PLATE_DK)                     # the tureen
    c.hline(141, 153, 80, PLATE_DK)
    c.put(147, 79, PLATE_DK)
    c.hline(143, 151, 84, PLATE_BLUE)
    c.rect(167, 83, 169, 88, CANDLE)                             # the candle in its holder
    c.hline(165, 171, 89, BRASS)
    c.dither(165, 88, 171, 88, hexc('d8cfb4'), 0.5)             # wax run


def side_chair(c, x0, base, facing_right=True):
    """A ladder-back dining chair pulled out from the table, seen exactly side-on: the back post
    runs from the floor up past the seat to the top rail, the seat is a thin plank, the front leg
    drops from the seat's far end, a stretcher low between the legs. 14px deep."""
    d = 1 if facing_right else -1
    back = x0 if facing_right else x0 + 13          # the back post's x
    front = x0 + 12 if facing_right else x0 + 1     # the front leg's x
    seat_y = base - 17
    c.shadow(x0 + 7, base, 9, 2, 110)
    c.rect(min(back, back + d), base - 42, max(back, back + d), base, WOOD)           # back post
    c.vline(back + d, base - 42, base, WOOD_DK)
    c.rect(min(back, back + d) , base - 43, max(back, back + d), base - 43, WOOD_LT)   # finial
    for ry in (base - 38, base - 32, base - 26):                                      # ladder rails, end-on
        c.rect(back + d, ry, back + 2 * d, ry + 1, WOOD_DK)
    c.rect(min(back, front), seat_y, max(back, front) + 1, seat_y + 2, WOOD)            # seat plank
    c.hline(min(back, front), max(back, front) + 1, seat_y, WOOD_LT)
    c.rect(min(front, front + d), seat_y + 3, max(front, front + d), base, WOOD)       # front leg
    c.vline(front + d, seat_y + 3, base, WOOD_DK)
    c.hline(min(back, front) + 1, max(back, front), base - 6, WOOD_DK)                # stretcher


def trolley(c, x0, base):
    """A brass drinks trolley pulled out near the lane, bottles on its two shelves (node)."""
    x1 = x0 + 30
    c.shadow(x0 + 15, base, 17, 2, 110)
    for lx in (x0, x1):
        c.vline(lx, base - 30, base - 2, BRASS)
        c.ellipse(lx, base - 1, 1, 1, hexc('2a2622'))                   # castors
    for sy in (base - 30, base - 12):
        c.rect(x0, sy, x1, sy + 1, hexc('5e3d28'))
        c.hline(x0, x1, sy, BRASS)
    for i, (bx, col, h) in enumerate(((x0 + 3, hexc('3a5a3a'), 11), (x0 + 9, hexc('7a4a2a'), 9),
                                      (x0 + 15, hexc('c9c2b1'), 7), (x0 + 22, hexc('5a1a22'), 10))):
        c.rect(bx, base - 30 - h, bx + 3, base - 31, col)
        c.rect(bx + 1, base - 33 - h, bx + 2, base - 31 - h, col)
    c.rect(x0 + 4, base - 17, x0 + 8, base - 13, GLASS)                 # glasses below, one broken
    c.rect(x0 + 12, base - 16, x0 + 16, base - 13, GLASS)
    c.poly([(x0 + 20, base - 13), (x0 + 24, base - 16), (x0 + 26, base - 13)], GLASS)


def plant(c):
    # a dead plant in a pot under the R window box (top below y 67)
    c.shadow(246, 100, 11, 2, 90)
    c.poly([(238, 86), (254, 86), (252, 99), (240, 99)], POT)
    c.rect(237, 84, 255, 86, shade(POT, 1.1))
    c.hline(240, 252, 99, shade(POT, 0.6))
    c.line(246, 84, 243, 72, LEAF_DEAD2)
    c.line(246, 84, 250, 70, LEAF_DEAD2)
    c.line(246, 84, 254, 76, LEAF_DEAD2)
    for (lx, ly) in ((242, 72), (250, 69), (254, 75), (244, 77), (238, 80)):
        c.poly([(lx, ly), (lx + 4, ly + 2), (lx + 1, ly + 4)], LEAF_DEAD)
    c.poly([(256, 99), (262, 97), (262, 99)], LEAF_DEAD)               # fallen leaves
    c.put(232, 99, LEAF_DEAD2); c.put(234, 98, LEAF_DEAD)


def dresser(c):
    # a Welsh dresser in the right corner: plate rack over drawers + a cupboard (nodes: the upper
    # drawers, the cupboard below)
    x0, x1, base = 274, 310, 100
    c.shadow(292, base, 20, 2, 100)
    # the rack
    c.box(x0 + 2, 14, x1 - 2, 56, WOOD, WOOD_OUT)
    c.rect(x0, 12, x1, 14, WOOD_LT)
    c.hline(x0, x1, 12, shade(WOOD_LT, 1.1))
    c.rect(x0 + 4, 16, x1 - 4, 55, hexc('2a1c13'))
    for sy in (29, 42, 55):
        c.rect(x0 + 4, sy, x1 - 4, sy + 1, WOOD_LT)
    # plates standing on the rack, a gap where two are gone, one smashed
    for i, px in enumerate(range(x0 + 8, x1 - 4, 9)):
        if i == 2:
            continue
        c.ellipse(px, 23, 4, 5, PLATE)
        c.ellipse(px, 23, 2, 3, PLATE_BLUE)
    for i, px in enumerate(range(x0 + 8, x1 - 4, 9)):
        c.ellipse(px, 36, 4, 5, PLATE)
        c.ellipse(px, 36, 2, 3, PLATE_BLUE if i % 2 else hexc('8a5a4a'))
    for px in range(x0 + 6, x1 - 5, 6):                                  # hooked cups
        c.rect(px, 47, px + 3, 51, PLATE)
        c.put(px + 4, 48, PLATE_DK)
    # the counter, two drawers, the cupboard
    c.rect(x0 - 1, 57, x1 + 1, 59, WOOD_LT)
    c.hline(x0 - 1, x1 + 1, 57, shade(WOOD_LT, 1.1))
    c.box(x0, 60, x1, base - 1, WOOD, WOOD_OUT)
    c.box(x0 + 2, 62, 291, 69, WOOD, WOOD_DK)
    c.box(293, 62, x1 - 2, 69, WOOD, WOOD_DK)
    c.rect(282, 65, 285, 65, BRASS)
    c.rect(299, 65, 302, 65, BRASS)
    c.poly([(293, 62), (x1 - 2, 62), (x1, 67), (295, 67)], WOOD_DK)       # one drawer pulled out
    c.rect(296, 61, 306, 62, hexc('c9c2b1'))                               # napkins in it
    c.box(x0 + 2, 71, 291, base - 3, WOOD, WOOD_DK)
    c.box(293, 71, x1 - 2, base - 3, WOOD, WOOD_DK)
    c.hline(x0 + 3, 290, 72, WOOD_LT)
    c.hline(294, x1 - 3, 72, WOOD_LT)
    c.rect(289, 82, 289, 85, BRASS)
    c.rect(295, 82, 295, 85, BRASS)
    c.rect(x0 + 1, base - 2, x1 - 1, base - 1, WOOD_DK)


def strip(c):
    sideboard(c)
    radiator(c)


def build(c=None):
    c = c or Canvas(seed=SEED)
    wall(c)
    decay(c)
    floor(c)
    pictures(c)
    back_chairs(c)
    table(c)
    side_chair(c, 102, 114, facing_right=True)
    trolley(c, 224, 118)
    dresser(c)
    return c


def bare(c):
    wall(c)
    decay(c)


ANCHORS = [('anchor_table_left', 128, 90, ''), ('anchor_table_right', 192, 90, ''),
           ('anchor_dining_trolley', 238, 106, ''), ('anchor_right_upperdrawers', 284, 65, 'bp'),
           ('anchor_right_lowerdrawers', 300, 85, 'bp'), ('anchor_dining_sideboard', 20, 80, 'bp s')]


if __name__ == '__main__':
    finish_module('dining_room', 'dining_room', SEED, bare, floor, build, ANCHORS, strip_fn=strip)
