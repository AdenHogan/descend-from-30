"""Bedroom module — 320 x 144 native pixel art, in the living room's style.

Run:  python3 tools/art/bedroom.py
Out:  assets/rooms/bedroom.png  (+ docs/art_reference/modules/bedroom_x4.png preview)

Layout (left -> right): a dressing table with a mirror against the wall (node: its top), a bedside
table with a squat lamp (node: its drawer), the bed lengthwise along the wall with the pillow at the
left (nodes: the pillow, a box pushed under the bed), clothes on the floor, and a wardrobe on the
right with one door ajar (nodes: its top shelf, its bottom drawer). The dressing table, bedside and
wardrobe stand against the back wall (the step-up plane); the bed comes forward to the walking lane.
The runtime window boxes stay bare wallpaper. The carpet repeats every 32px so the floor carries on
past the module edge at a doorway (scripts/module_walls.gd FLOOR_STRIP).
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, mix, SEAM_Y, W, H, check_window_boxes, check_edge_columns, save_floor_strip, floor_is_periodic, rrect

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

# --- palette (dusty, faded, lived-in) -------------------------------------------------------
WALL = hexc('5f6a78')          # faded blue-grey paper
WALL_DK = hexc('56606d')
WALL_SPRIG = hexc('6c7786')
WALL_SPRIG2 = hexc('7b7066')   # tiny rust flower
WALL_TOP = hexc('515b67')
CROWN = hexc('464c55')
CROWN_HI = hexc('5b626c')
PICRAIL = hexc('6a5446')
PICRAIL_HI = hexc('7e6655')
SKIRT = hexc('3c2d24')
SKIRT_HI = hexc('54423a')
SEAM = hexc('2a1f19')

CARPET = hexc('7b5f63')        # dusty mauve carpet
CARPET_DK = hexc('6c5257')
CARPET_LT = hexc('886b6e')
CARPET_WORN = hexc('92797a')
OUT = hexc('2a1c17')

WOOD = hexc('5d3f2c')
WOOD_DK = hexc('46301f')
WOOD_LT = hexc('71503a')
WOOD_OUT = hexc('2b1c13')
BRASS = hexc('b09456')
MIRROR = hexc('8b9aa0')
MIRROR_DK = hexc('6c7a80')
MIRROR_HI = hexc('b8c3c4')

SHEET = hexc('c9c2b1')
SHEET_DK = hexc('aaa293')
DUVET = hexc('6d7e6a')         # sage duvet
DUVET_DK = hexc('586855')
DUVET_LT = hexc('7f8f7a')
PILLOW = hexc('d8d1bf')
PILLOW_DK = hexc('b7af9c')
BED_WOOD = hexc('4f3526')
BED_WOOD_LT = hexc('66462f')

LAMP_SHADE = hexc('c9ab7e')
LAMP_SHADE_DK = hexc('a88c62')
LAMP_BASE = hexc('7b8a86')

WARD = hexc('6a4a33')
WARD_DK = hexc('533826')
WARD_LT = hexc('7e5a3f')
WARD_IN = hexc('2c211b')

CLOTH = [hexc('8a4a42'), hexc('4e5d70'), hexc('c1b69c'), hexc('5f6b4e'), hexc('7d6a8a')]
BOX = hexc('9a7a4e')
BOX_DK = hexc('7c6140')
FRAME = hexc('6b4a2c')
FRAME_DK = hexc('3b2718')
PHOTO = hexc('9c9282')
STAIN = hexc('6e6252', 80)
DAMP = hexc('4f5a52', 60)
BLOOD = hexc('4a1d1b', 150)


def wall(c):
    c.rect(0, 0, W - 1, 93, WALL)
    # sprig wallpaper: a small repeating motif on a 16px grid, staggered rows
    for y in range(22, 92, 10):
        off = 0 if (y // 10) % 2 == 0 else 8
        for x in range(off + 4, W, 16):
            c.put(x, y, WALL_SPRIG)
            c.put(x - 1, y + 1, WALL_SPRIG)
            c.put(x + 1, y + 1, WALL_SPRIG)
            c.put(x, y + 2, WALL_SPRIG2)
    for x in range(0, W, 32):                   # faint paper seams
        c.vline(x + 15, 18, 92, WALL_DK)
    c.rect(0, 6, W - 1, 8, WALL_TOP)
    c.dither(0, 9, W - 1, 13, WALL_TOP, 0.5)
    c.rect(0, 0, W - 1, 4, CROWN)
    c.hline(0, W - 1, 4, CROWN_HI)
    c.hline(0, W - 1, 5, shade(CROWN, 0.8))
    # picture rail
    c.rect(0, 16, W - 1, 17, PICRAIL)
    c.hline(0, W - 1, 16, PICRAIL_HI)
    # skirting + seam
    c.rect(0, 94, W - 1, 99, SKIRT)
    c.hline(0, W - 1, 94, SKIRT_HI)
    c.hline(0, W - 1, 99, SEAM)


def decay(c):
    # a damp bloom creeping down from the ceiling, top right (clear of the R window box's columns
    # only where it's part of the WALL layer — this is the wall layer, so it's allowed there)
    for i in range(9):
        c.ellipse(236 + i * 7, 22 + (i % 3) * 3, 9 - i % 3, 5, DAMP)
    # peeling paper by the door edge
    c.poly([(2, 40), (9, 38), (7, 52), (2, 55)], shade(WALL, 1.12))
    c.line(2, 55, 7, 52, WALL_DK)
    # scuffs along the skirting
    for x in (60, 131, 198):
        c.hline(x, x + 5, 92, shade(WALL, 0.85))


def floor(c):
    # dusty carpet: flat, a soft darkening under the skirting, a worn path. Every texture element
    # repeats every 32px (x) so the floor tiles on seamlessly past the module edge at a doorway.
    c.rect(0, 100, W - 1, H - 1, CARPET)
    c.hline(0, W - 1, 100, shade(CARPET, 0.72))
    c.hline(0, W - 1, 101, shade(CARPET, 0.84))
    for y in range(103, H):
        for x in range(W):
            k = (x * 7 + y * 13) % 32          # 32-periodic speckle
            if k == 3 or k == 19:
                c.put(x, y, CARPET_DK)
            elif k == 11:
                c.put(x, y, CARPET_LT)
    # the worn walking path (horizontal band — no x variation, so it tiles)
    for y in range(124, 136):
        for x in range(W):
            if (x + 2 * y) % 4 == 0:
                c.put(x, y, CARPET_WORN)


def picture(c):
    # a small framed photo hanging a little askew above the bed (between the window boxes)
    c.box(128, 36, 150, 54, FRAME, FRAME_DK)
    c.rect(131, 39, 147, 51, PHOTO)
    c.rect(134, 44, 137, 51, shade(PHOTO, 0.7))       # two figures, faded
    c.rect(141, 43, 144, 51, shade(PHOTO, 0.75))
    c.line(139, 30, 128, 36, FRAME_DK)                  # the string
    c.line(139, 30, 150, 36, FRAME_DK)
    # a pale rectangle where a second picture used to hang
    c.rect(168, 38, 184, 52, shade(WALL, 1.08))
    c.put(176, 32, FRAME_DK)                            # its nail


def dressing_table(c):
    # against the back wall, left of the L window box (x < 50)
    x0, x1, top, base = 6, 46, 66, 100
    c.shadow(26, base, 20, 2, 90)
    # mirror (above the table, x 12..40, y 30..62)
    c.box(12, 30, 40, 63, WOOD, WOOD_OUT)
    c.rect(14, 32, 38, 61, MIRROR)
    c.dither(14, 50, 38, 61, MIRROR_DK, 0.5)
    c.line(16, 58, 24, 34, MIRROR_HI)
    c.line(18, 59, 26, 35, MIRROR_HI)
    c.line(27, 44, 36, 58, shade(MIRROR, 0.8))          # a crack
    c.line(27, 44, 31, 40, shade(MIRROR, 0.8))
    # table top + body
    c.rect(x0 - 1, top, x1 + 1, top + 2, WOOD_LT)
    c.hline(x0 - 1, x1 + 1, top, shade(WOOD_LT, 1.1))
    c.box(x0, top + 3, x1, base - 1, WOOD, WOOD_OUT)
    for (ry0, ry1) in ((top + 5, top + 13), (top + 15, top + 23)):
        c.box(x0 + 2, ry0, x1 - 2, ry1, WOOD, WOOD_DK)
        c.hline(x0 + 3, x1 - 3, ry0 + 1, WOOD_LT)
        c.rect(24, (ry0 + ry1) // 2, 28, (ry0 + ry1) // 2, BRASS)
    c.rect(x0 + 2, base - 5, x0 + 4, base - 1, WOOD_DK)          # legs
    c.rect(x1 - 4, base - 5, x1 - 2, base - 1, WOOD_DK)
    # on top: perfume bottles, a hairbrush, a jewellery box lid up (the node sits on the box)
    c.rect(9, top - 6, 11, top - 1, hexc('b98c97'))
    c.put(10, top - 7, hexc('d4c9a9'))
    c.rect(13, top - 4, 15, top - 1, hexc('8fa3a8'))
    c.rect(32, top - 3, 42, top - 1, hexc('4a3040'))              # jewellery box
    c.poly([(32, top - 4), (42, top - 4), (41, top - 9), (33, top - 9)], hexc('5c3c50'))
    c.hline(34, 40, top - 3, BRASS)
    c.rect(19, top - 2, 27, top - 1, hexc('3d2a1c'))              # hairbrush


def bedside(c):
    # against the wall; the lamp stays below the L window box (its top row y >= 67)
    x0, x1, top, base = 52, 74, 80, 100
    c.shadow(63, base, 12, 2, 90)
    c.rect(x0 - 1, top, x1 + 1, top + 1, WOOD_LT)
    c.box(x0, top + 2, x1, base - 1, WOOD, WOOD_OUT)
    c.box(x0 + 2, top + 4, x1 - 2, top + 11, WOOD, WOOD_DK)      # drawer (the node)
    c.hline(x0 + 3, x1 - 3, top + 5, WOOD_LT)
    c.rect(61, top + 7, 65, top + 7, BRASS)
    c.rect(x0 + 2, top + 13, x1 - 2, base - 2, WOOD_DK)          # open shelf, dark
    c.rect(x0 + 4, top + 15, x0 + 9, base - 3, hexc('7a6a8a'))    # a book lying in it
    # squat lamp
    c.rect(60, top - 4, 66, top - 1, LAMP_BASE)
    c.poly([(58, 67), (68, 67), (71, 74), (55, 74)], LAMP_SHADE)
    c.hline(55, 71, 74, LAMP_SHADE_DK)
    c.vline(63, 75, top - 5, LAMP_BASE)
    # a glass of water
    c.rect(69, top - 4, 71, top - 1, hexc('a9b6b7'))


def bed(c):
    # lengthwise along the wall, coming forward to the walking lane (base ~114 like the sofa). We
    # look down on it a little: the mattress TOP shows (back edge 84 -> front edge 97), then its
    # front face, the side rail, the legs. The duvet lies on top and drapes over the front edge.
    x0, x1 = 78, 214
    c.shadow(146, 115, 70, 3, 110)
    # headboard (left) — top kept below the L window box (y >= 67)
    c.box(x0, 68, x0 + 8, 113, BED_WOOD, WOOD_OUT)
    c.vline(x0 + 1, 69, 112, BED_WOOD_LT)
    c.rect(x0 + 2, 72, x0 + 6, 74, BED_WOOD_LT)
    # mattress: top surface + front face
    c.rect(x0 + 8, 84, x1 - 6, 97, SHEET)
    c.hline(x0 + 8, x1 - 6, 84, SHEET_DK)
    c.rect(x0 + 8, 98, x1 - 6, 103, SHEET_DK)
    c.hline(x0 + 8, x1 - 6, 98, shade(SHEET_DK, 1.08))
    # side rail + legs
    c.rect(x0 + 8, 104, x1, 109, BED_WOOD)
    c.hline(x0 + 8, x1, 104, BED_WOOD_LT)
    c.hline(x0 + 8, x1, 109, WOOD_OUT)
    for lx in (x0 + 10, x1 - 4):
        c.rect(lx, 110, lx + 2, 114, WOOD_OUT)
    # the pillow (node) at the back of the top, dented
    rrect(c, 88, 83, 110, 92, PILLOW, 3)
    c.hline(90, 108, 92, PILLOW_DK)
    c.rect(95, 86, 102, 88, PILLOW_DK)
    # THE DUVET covers the whole mattress top from the back edge to the footboard, turned down in a
    # fold at the pillow end, and drapes over the front edge in a soft, uneven hem.
    xa, xb2 = 112, 208                                   # from just past the pillow to the footboard
    c.rect(xa, 84, xb2, 97, DUVET)                       # the top, back edge to front edge
    c.hline(xa, xb2, 84, DUVET_DK)                       # the far edge, tucked against the wall
    c.hline(xa + 10, xb2, 85, DUVET_LT)
    # the turned-down fold: a lighter band (the duvet's underside) with a shadow under its lip
    c.poly([(xa, 84), (xa + 9, 84), (xa + 12, 97), (xa, 97)], shade(DUVET_LT, 1.08))
    c.line(xa + 9, 84, xa + 12, 97, DUVET_DK)
    c.vline(xa + 13, 86, 96, shade(DUVET, 0.88))
    # soft rumples: short light ridges with a shade under them, never hard straight lines
    for (rx, ry, ln) in ((136, 88, 14), (158, 91, 18), (182, 87, 12), (196, 93, 8)):
        c.hline(rx, rx + ln, ry, DUVET_LT)
        c.hline(rx + 2, rx + ln + 1, ry + 1, shade(DUVET, 0.88))
    # the drape over the front edge (97 -> an uneven hem), darker as it turns away from us
    hem = [105, 106, 106, 107, 106, 105, 105, 106, 107, 107, 106, 105]
    step = (xb2 - xa + 1) / len(hem)
    for k, hy in enumerate(hem):
        x0d = xa + int(k * step)
        x1d = xa + int((k + 1) * step) - 1
        c.rect(x0d, 98, x1d, hy, DUVET_DK)
        c.hline(x0d, x1d, hy, shade(DUVET_DK, 0.8))
    c.hline(xa, xb2, 97, DUVET)                          # the rounded front edge
    c.hline(xa, xb2, 98, shade(DUVET, 0.92))
    for fx in (128, 151, 173, 194):                      # a few soft folds in the drape
        c.vline(fx, 100, 104, shade(DUVET_DK, 0.82))
        c.vline(fx + 1, 99, 103, shade(DUVET_DK, 1.1))
    # a dark stain soaking into the sheet by the pillow
    c.ellipse(111, 90, 2, 1, BLOOD)
    # footboard (right)
    c.box(x1 - 6, 80, x1, 113, BED_WOOD, WOOD_OUT)
    c.vline(x1 - 5, 81, 112, BED_WOOD_LT)
    # a box shoved under the bed (the underbed node) peeking out at the front
    c.box(140, 108, 164, 113, BOX, BOX_DK)
    c.hline(141, 163, 108, shade(BOX, 1.1))


def floor_clutter(c):
    # clothes dropped between the bed and the wardrobe, on the carpet in front of the wall
    c.poly([(222, 110), (238, 107), (246, 112), (234, 116), (220, 115)], CLOTH[1])
    c.line(222, 110, 234, 116, shade(CLOTH[1], 0.8))
    c.poly([(240, 114), (256, 112), (262, 117), (246, 119)], CLOTH[0])
    c.rect(226, 105, 233, 108, CLOTH[2])                  # a shoe
    c.put(233, 108, OUT)


def wardrobe(c):
    # tall, right of the R window box (x > 270); one door ajar showing a shelf + hanging clothes
    x0, x1, top, base = 272, 306, 28, 100
    c.shadow(295, base, 22, 2, 100)
    c.rect(x0 - 1, top, x1 + 1, top + 3, WARD_DK)          # cornice
    c.hline(x0 - 1, x1 + 1, top, WARD_LT)
    c.box(x0, top + 4, x1, base - 1, WARD, WOOD_OUT)
    mid = (x0 + x1) // 2
    # left door, closed
    c.box(x0 + 2, top + 6, mid - 1, base - 16, WARD, WARD_DK)
    c.box(x0 + 5, top + 10, mid - 4, base - 20, WARD, WARD_DK)
    c.rect(mid - 4, (top + base) // 2 - 4, mid - 3, (top + base) // 2 - 1, BRASS)
    # right door AJAR: the dark interior, a top shelf with a hatbox (node), clothes hanging
    c.rect(mid, top + 6, x1 - 2, base - 16, WARD_IN)
    c.hline(mid, x1 - 2, top + 16, WARD_LT)                # the shelf
    c.box(mid + 3, top + 9, mid + 13, top + 15, hexc('8f7a6a'), hexc('5f4f43'))  # hat box
    rail = top + 21
    c.hline(mid + 1, x1 - 3, rail, BRASS)                  # rail
    hanging_clothes(c, mid, rail)
    c.poly([(x1 - 1, top + 6), (x1 + 4, top + 8), (x1 + 4, base - 17), (x1 - 1, base - 16)], WARD_LT)  # the door, swung out
    # bottom drawer (node)
    c.box(x0 + 2, base - 14, x1 - 2, base - 3, WARD, WARD_DK)
    c.hline(x0 + 3, x1 - 3, base - 13, WARD_LT)
    c.rect(mid - 2, base - 9, mid + 2, base - 9, BRASS)
    # a suitcase on top
    c.box(x0 + 4, top - 8, x0 + 26, top - 1, hexc('6b5a45'), hexc('463a2c'))
    c.rect(x0 + 13, top - 10, x0 + 17, top - 9, hexc('463a2c'))


def _hanger(c, cx, rail):
    # a hook over the rail + a little wooden bar under it
    c.put(cx, rail - 1, shade(BRASS, 0.7))
    c.hline(cx - 1, cx + 1, rail + 1, WOOD_LT)


def hanging_clothes(c, x, rail):
    """Three garments on hangers, drawn pixel by pixel inside the 16px-wide open wardrobe (x .. x+15):
    a long navy coat (lapels, a V of shirt collar, buttons, a pocket flap), a checked shirt (collar,
    placket + buttons, cuffs, a breast pocket) and a flared dress (straps, bodice, belt, folds)."""
    y0 = rail + 2                                   # shoulders start under the hanger bar
    # --- long coat, x+1 .. x+6 ---------------------------------------------------------------
    coat, coat_dk, coat_lt = CLOTH[1], shade(CLOTH[1], 0.72), shade(CLOTH[1], 1.12)
    cx0 = x + 1
    _hanger(c, cx0 + 2, rail)
    c.hline(cx0 + 1, cx0 + 4, y0, coat)                     # sloped shoulders
    c.rect(cx0, y0 + 1, cx0 + 5, y0 + 23, coat)
    c.vline(cx0 + 5, y0 + 1, y0 + 23, coat_dk)              # the far side in shade
    c.vline(cx0 + 1, y0 + 2, y0 + 21, coat_lt)
    c.put(cx0 + 2, y0, SHEET); c.put(cx0 + 3, y0, SHEET)    # the collar V (a shirt under it)
    c.put(cx0 + 2, y0 + 1, SHEET); c.put(cx0 + 3, y0 + 1, SHEET)
    c.put(cx0 + 2, y0 + 2, SHEET)
    for (lx, ly) in ((cx0 + 1, y0 + 1), (cx0 + 1, y0 + 2), (cx0 + 4, y0 + 1), (cx0 + 4, y0 + 2), (cx0 + 3, y0 + 3)):
        c.put(lx, ly, coat_dk)                              # lapel edges
    for by in (y0 + 6, y0 + 10, y0 + 14):
        c.put(cx0 + 3, by, shade(BRASS, 0.8))               # buttons
    c.hline(cx0, cx0 + 2, y0 + 15, coat_dk)                 # pocket flap
    c.hline(cx0, cx0 + 5, y0 + 23, coat_dk)                 # hem
    # --- checked shirt, x+7 .. x+11 ------------------------------------------------------------
    sh, sh_dk, sh_lt = CLOTH[0], shade(CLOTH[0], 0.72), shade(CLOTH[0], 1.18)
    sx0 = x + 7
    _hanger(c, sx0 + 2, rail)
    c.hline(sx0 + 1, sx0 + 3, y0, sh)
    c.rect(sx0, y0 + 1, sx0 + 4, y0 + 15, sh)
    for yy in range(y0 + 1, y0 + 16):                        # the check
        for xx in range(sx0, sx0 + 5):
            if (xx * 2 + yy) % 4 == 0:
                c.put(xx, yy, sh_dk)
    c.put(sx0 + 1, y0, sh_lt); c.put(sx0 + 3, y0, sh_lt)    # collar points
    c.put(sx0 + 2, y0, shade(sh, 0.5))                       # the neck
    c.vline(sx0 + 2, y0 + 1, y0 + 15, sh_lt)                 # placket
    for by in (y0 + 3, y0 + 7, y0 + 11):
        c.put(sx0 + 2, by, SHEET)                            # buttons
    c.put(sx0 + 3, y0 + 3, sh_dk)                            # breast pocket
    c.put(sx0, y0 + 11, sh_lt); c.put(sx0 + 4, y0 + 11, sh_lt)   # cuffs of the hanging sleeves
    c.hline(sx0, sx0 + 4, y0 + 15, sh_dk)                    # tail
    # --- dress, x+12 .. x+15 ---------------------------------------------------------------------
    dr, dr_dk, dr_lt = CLOTH[4], shade(CLOTH[4], 0.72), shade(CLOTH[4], 1.15)
    dx0 = x + 12
    _hanger(c, dx0 + 1, rail)
    c.put(dx0, y0, dr); c.put(dx0 + 2, y0, dr)               # straps
    c.rect(dx0, y0 + 1, dx0 + 3, y0 + 6, dr)                 # bodice
    c.vline(dx0 + 3, y0 + 1, y0 + 6, dr_dk)
    c.hline(dx0, dx0 + 3, y0 + 7, dr_dk)                     # belt
    c.put(dx0 + 1, y0 + 7, shade(BRASS, 0.9))
    c.rect(dx0, y0 + 8, dx0 + 3, y0 + 25, dr)                # skirt
    for fx, fy0 in ((dx0 + 1, y0 + 10), (dx0 + 3, y0 + 9)):
        c.vline(fx, fy0, y0 + 24, dr_dk)                     # folds
    c.vline(dx0 + 2, y0 + 12, y0 + 24, dr_lt)
    c.hline(dx0, dx0 + 3, y0 + 25, dr_dk)                    # hem
    # a pair of shoes on the wardrobe floor
    c.rect(x + 2, rail + 30, x + 4, rail + 31, hexc('3a2a22'))
    c.rect(x + 6, rail + 30, x + 8, rail + 31, hexc('3a2a22'))


def build():
    c = Canvas(seed=21)
    wall(c)
    decay(c)
    picture(c)
    floor(c)
    dressing_table(c)
    bedside(c)
    wardrobe(c)
    floor_clutter(c)
    bed(c)
    return c


if __name__ == '__main__':
    out = os.path.join(ROOT, 'assets', 'rooms', 'bedroom.png')
    prev_dir = os.path.join(ROOT, 'docs', 'art_reference', 'modules')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    c = build()
    bare = Canvas(seed=21)
    wall(bare)
    decay(bare)
    bad = check_window_boxes(c.img, bare.img)
    if bad:
        sys.exit('furniture inside a runtime window box: %s' % bad[:8])
    edge = check_edge_columns(c.img, bare.img)
    if edge:
        sys.exit('furniture in the edge columns the side walls are painted from: %s' % edge[:8])
    fl = save_floor_strip(floor, 'bedroom', ROOT, seed=21)
    if not floor_is_periodic(fl):
        sys.exit('the floor must repeat every 32px (it tiles on past the module edge at a doorway)')
    c.save(out, os.path.join(prev_dir, 'bedroom_x4.png'))
    print('wrote', out, '(window boxes clear)')
