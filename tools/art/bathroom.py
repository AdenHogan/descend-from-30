"""Bathroom module — every art VARIANT (320 x 144 native pixel art, the living room's style).

Run:  python3 tools/art/bathroom.py [variant ...]      (no args = all)
Out:  assets/rooms/bathroom[_<v>].png (+ _floor.png), scenes/Room_Modules/bathroom[_<v>].tscn,
      docs/art_reference/modules/bathroom[_<v>]_x4.png + nodes/…_nodes.png

Variants (owner round 10 — "that bath is way too long… a horse water trough"):
  a  classic   — a short white roll-top on claw feet, a pedestal sink under a mirrored cabinet, a
                 wicker basket, a heated towel rail, a corner shower.
  b  avocado   — the 70s suite: a panelled rectangular bath on the right with a glass screen, an
                 avocado toilet + vanity unit, brown flower tiles, orange lino, a mop bucket.
  c  gilded    — something silly: a GOLD claw-foot tub, a gold throne of a toilet, marble, a gilt
                 mirror over a washstand, a champagne bucket, a chandelier.
  d  wet room  — squalid: a tub hidden behind a drawn shower curtain, a washing machine spewing
                 clothes, a clothes horse out in the room, black mould.
Nodes sit on the furniture; most are reachable from the walking line (front) — only things
against the back wall are back-plane ('bp').
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import persp
from pixlib import Canvas, hexc, shade, mix, W, H, finish_module, rrect, setback

# --- shared palette ---------------------------------------------------------------------------
PORC = hexc('e1e0d6')
PORC_DK = hexc('bdbcb1')
PORC_LT = hexc('f1f0e8')
PORC_OUT = hexc('6d6c64')
CHROME = hexc('aab0b2')
CHROME_DK = hexc('7a8083')
MIRROR = hexc('8b9aa0')
MIRROR_HI = hexc('b8c3c4')
IRON = hexc('3b3a38')
SEAM = hexc('2a2622')
GLASS = hexc('a9bcbe', 150)
MOULD = hexc('3c4a36', 110)
RUST = hexc('8a5a3a', 140)
BLOOD = hexc('4a1d1b', 150)
TOWELS = [hexc('6e7f95'), hexc('c26b5a'), hexc('d8cfb4'), hexc('7d9a7a'), hexc('b38a5a')]


# --- shared shape helpers ---------------------------------------------------------------------
def rows_shape(c, rows, fill, out=None):
    """rows: {y: (xa, xb)} — fill each row, then a 1px outline round the silhouette."""
    for y, (xa, xb) in rows.items():
        c.hline(xa, xb, y, fill)
    if out is None:
        return
    ys = sorted(rows)
    for i, y in enumerate(ys):
        xa, xb = rows[y]
        c.put(xa, y, out)
        c.put(xb, y, out)
        for ny in (ys[i - 1] if i > 0 else None, ys[i + 1] if i + 1 < len(ys) else None):
            if ny is None:
                c.hline(xa, xb, y, out)
                continue
            na, nb = rows[ny]
            if xa < na:
                c.hline(xa, min(na - 1, xb), y, out)
            if xb > nb:
                c.hline(max(nb + 1, xa), xb, y, out)


def tiled_wall(c, top, tile, tile_dk, grout, trim, size=8, skirting=True):
    c.rect(0, top, W - 1, 93, tile)
    c.rect(0, top, W - 1, top + 2, trim)
    for y in range(top + 3, 94, size):
        c.hline(0, W - 1, y, grout)
    for x in range(0, W, size):
        c.vline(x, top + 3, 93, grout)
    for y in range(top + 4, 93, size * 2):
        c.dither(0, y, W - 1, y + 1, tile_dk, 0.5)
    if skirting:
        c.rect(0, 94, W - 1, 99, trim)
        c.hline(0, W - 1, 94, shade(trim, 1.15))
    c.hline(0, W - 1, 99, SEAM)


def crown(c, col, hi):
    c.rect(0, 0, W - 1, 4, col)
    c.hline(0, W - 1, 4, hi)
    c.hline(0, W - 1, 5, shade(col, 0.8))


def pedestal_sink(c, cx, top, porc=PORC, porc_dk=PORC_DK, out=PORC_OUT, tap=CHROME):
    """A pedestal basin centred on cx, its bowl rim at `top`, the pedestal down to 99."""
    c.shadow(cx, 100, 12, 2, 90)
    c.rect(cx - 3, top + 10, cx + 3, 99, porc)
    c.vline(cx + 2, top + 10, 99, porc_dk)
    c.vline(cx - 3, top + 10, 99, out)
    c.vline(cx + 3, top + 10, 99, out)
    rrect(c, cx - 15, top, cx + 15, top + 10, out, 3)
    rrect(c, cx - 14, top + 1, cx + 14, top + 9, porc, 3)
    c.hline(cx - 12, cx + 12, top + 2, porc_dk)
    c.rect(cx - 9, top + 3, cx + 9, top + 5, shade(porc, 0.86))
    c.rect(cx - 1, top - 4, cx + 1, top - 1, tap)
    c.put(cx + 1, top, shade(tap, 0.7))


def toilet(c, cx, porc=PORC, out=PORC_OUT, lid_up=False, seat=None, lever=CHROME):
    """A low-cistern toilet against the wall, centred on cx (cistern top 67 — under the L box)."""
    c.shadow(cx, 100, 13, 2, 90)
    c.box(cx - 10, 67, cx + 10, 77, porc, out)
    c.hline(cx - 9, cx + 9, 68, shade(porc, 1.08))
    c.rect(cx + 7, 70, cx + 9, 71, lever)
    if lid_up:
        c.box(cx - 9, 70, cx + 9, 78, seat or porc, out)          # the lid up against the cistern
    rrect(c, cx - 12, 78, cx + 12, 88, out, 4)
    rrect(c, cx - 11, 79, cx + 11, 87, seat or porc, 4)
    if lid_up:
        rrect(c, cx - 8, 81, cx + 8, 86, shade(porc, 0.55), 3)   # the dark bowl
    else:
        c.hline(cx - 9, cx + 9, 80, shade(porc, 1.08))
    c.poly([(cx - 8, 88), (cx + 8, 88), (cx + 5, 99), (cx - 5, 99)], porc)
    c.line(cx - 8, 88, cx - 5, 99, out)
    c.line(cx + 8, 88, cx + 5, 99, out)
    c.hline(cx - 5, cx + 5, 99, out)


def clawfoot_tub(c, x0, x1, rim, porc, porc_lt, porc_dk, out, feet, inside, water=None):
    """A short double-ended ROLL-TOP bath on claw feet: the rolled lip at `rim` (rising a touch at
    both ends), a glimpse of the inside, a body that curves in toward the bottom, four feet (the
    far pair set back), feet standing on rim+28."""
    base = rim + 28
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 4, 3, 110)
    for fx in (x0 + 12, x1 - 12):                                     # far feet, set back + darker
        c.rect(fx - 1, rim + 20, fx + 1, base - 3, shade(feet, 0.7))
    body_top, body_bot = rim + 3, rim + 21
    rows = {}
    for y in range(rim - 2, body_bot + 1):
        if y < rim:                                                    # the raised ends of the lip
            rows[y] = None
            continue
        t = max(0.0, (y - body_top) / float(body_bot - body_top))
        inset = int(round(8 * t * t))
        rows[y] = (x0 + inset, x1 - inset)
    rows = {y: v for y, v in rows.items() if v is not None}
    rows_shape(c, rows, porc, out)
    for (ex0, ex1) in ((x0, x0 + 9), (x1 - 9, x1)):                  # the rolled ends stand proud
        rrect(c, ex0, rim - 3, ex1, rim + 1, out, 2)
        rrect(c, ex0 + 1, rim - 2, ex1 - 1, rim, porc_lt, 1)
    c.hline(x0 + 9, x1 - 9, rim, porc_lt)                             # the lip, lit
    c.rect(x0 + 5, rim + 1, x1 - 5, rim + 2, inside)                  # the inside, glimpsed
    if water is not None:
        c.hline(x0 + 8, x1 - 8, rim + 2, water)
    c.hline(x0 + 2, x1 - 2, rim + 3, porc_lt)
    c.dither(x0 + 6, body_bot - 5, x1 - 6, body_bot - 1, porc_dk, 0.5)
    for fx in (x0 + 7, x1 - 7):                                       # front claw feet
        c.rect(fx - 1, body_bot - 1, fx + 1, base - 2, feet)
        c.hline(fx - 2, fx + 2, base - 1, feet)
        c.hline(fx - 3, fx + 3, base, shade(feet, 0.8))
        c.put(fx + (2 if fx < x1 - 20 else -2), base - 2, shade(feet, 1.2))


def mirror_cabinet(c, x0, y0, x1, y1, frame, frame_out, open_door=True):
    c.box(x0, y0, x1, y1, frame, frame_out)
    c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, hexc('3a3833'))
    c.hline(x0 + 2, x1, (y0 + y1) // 2 - 5, shade(frame, 0.8))
    c.hline(x0 + 2, x1, (y0 + y1) // 2 + 5, shade(frame, 0.8))
    c.rect(x0 + 4, y0 + 4, x0 + 7, y0 + 9, hexc('c05a3a'))
    c.rect(x0 + 10, y0 + 5, x0 + 12, y0 + 9, hexc('e0d9b8'))
    c.rect(x0 + 15, (y0 + y1) // 2 - 2, x0 + 20, (y0 + y1) // 2 + 4, hexc('6f8fa0'))
    c.rect(x0 + 4, y1 - 7, x0 + 10, y1 - 3, hexc('d9c38a'))
    if open_door:
        c.poly([(x1, y0), (x1 + 7, y0 + 2), (x1 + 7, y1 - 2), (x1, y1)], frame)
        c.poly([(x1 + 1, y0 + 2), (x1 + 6, y0 + 4), (x1 + 6, y1 - 4), (x1 + 1, y1 - 2)], MIRROR)
        c.line(x1 + 2, y1 - 6, x1 + 5, y0 + 6, MIRROR_HI)


def shower_corner(c, x0, x1, top, tile, grout, tray=PORC, tray_out=PORC_OUT):
    c.rect(x0, top, x1, 99, tile)
    for y in range(top + 4, 99, 8):
        c.hline(x0, x1, y, grout)
    c.box(x0 - 2, 96, x1 + 2, 100, tray, tray_out)
    c.rect(x1 - 6, top + 6, x1 - 5, top + 20, CHROME_DK)
    c.rect(x1 - 12, top + 6, x1 - 6, top + 7, CHROME_DK)
    c.rect(x1 - 15, top + 8, x1 - 10, top + 9, CHROME)
    for y in range(top, 96):
        for x in range(x0, x0 + 12):
            c.put(x, y, GLASS)
    c.vline(x0, top, 95, CHROME_DK)
    c.vline(x0 + 12, top, 95, CHROME_DK)
    c.hline(x0, x0 + 12, top, CHROME_DK)
    c.line(x0 + 3, top + 50, x0 + 9, top + 20, hexc('dde6e6'))


# ============================================================================================
# A — classic
# ============================================================================================
A_PAINT = hexc('9fa89a')
A_PAINT_TOP = hexc('8d9688')
A_TILE = hexc('c9cdc0')
A_TILE_DK = hexc('b4b8ab')
A_GROUT = hexc('8d9185')
A_TRIM = hexc('5d7d78')
A_MOS_A = hexc('d3d4cb')
A_MOS_B = hexc('3f4a4d')
A_MOS_G = hexc('9ea196')


def a_wall(c):
    c.rect(0, 0, W - 1, 93, A_PAINT)
    c.rect(0, 6, W - 1, 8, A_PAINT_TOP)
    c.dither(0, 9, W - 1, 13, A_PAINT_TOP, 0.5)
    crown(c, hexc('6f776b'), hexc('858d80'))
    tiled_wall(c, 40, A_TILE, A_TILE_DK, A_GROUT, A_TRIM)
    # decay: black mould from the ceiling corners and along the grout, a cracked tile
    c.dither(0, 6, 30, 20, MOULD, 0.4, pattern='random')
    c.dither(290, 6, W - 1, 24, MOULD, 0.4, pattern='random')
    c.dither(110, 44, 190, 52, MOULD, 0.18, pattern='random')
    c.line(150, 48, 158, 60, A_GROUT)
    c.line(158, 60, 155, 66, A_GROUT)


def mosaic_floor(c, a, b, g):
    c.rect(0, 100, W - 1, H - 1, a)
    rows = [100, 104, 109, 115, 122, 130, 139, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, W, 8):
            col = b if ((x // 8) % 4 == (r % 2) * 2) else a
            c.rect(x, y0, x + 7, y1, col)
            c.vline(x, y0, y1, g)
        c.hline(0, W - 1, y0, g)
    c.hline(0, W - 1, 100, shade(a, 0.55))
    c.hline(0, W - 1, 101, shade(a, 0.75))


@persp
def a_floor(c):
    mosaic_floor(c, A_MOS_A, A_MOS_B, A_MOS_G)


def towel_rail(c, x0, x1, top, bar=CHROME, bar_dk=CHROME_DK, towels=(0, 2)):
    """A heated towel rail on the wall (under the R window box) with towels hung over it."""
    c.vline(x0, top, 97, bar_dk)
    c.vline(x1, top, 97, bar_dk)
    for y in range(top + 2, 96, 6):
        c.hline(x0, x1, y, bar)
    for i, ti in enumerate(towels):
        tx0 = x0 + 3 + i * ((x1 - x0) // 2)
        col = TOWELS[ti]
        c.rect(tx0, top + 1, tx0 + 11, top + 22 - i * 4, col)
        c.hline(tx0, tx0 + 11, top + 1, shade(col, 1.15))
        c.vline(tx0 + 11, top + 1, top + 22 - i * 4, shade(col, 0.8))
        for y in range(top + 20 - i * 4, top + 23 - i * 4):          # fringe
            for x in range(tx0, tx0 + 12, 2):
                c.put(x, y, shade(col, 0.85))


def wicker_basket(c, x0, x1, top, base):
    wk, wk_dk = hexc('b39a6a'), hexc('8a7348')
    c.shadow((x0 + x1) // 2, base, (x1 - x0) // 2 + 2, 2, 110)
    c.poly([(x0, top), (x1, top), (x1 - 2, base), (x0 + 2, base)], wk)
    for y in range(top + 2, base, 3):
        c.hline(x0 + 1, x1 - 1, y, wk_dk)
    for x in range(x0 + 3, x1 - 1, 4):
        c.vline(x, top + 1, base - 1, shade(wk, 0.9))
    c.rect(x0 - 1, top - 1, x1 + 1, top + 1, wk_dk)
    # clothes spilling over the rim
    c.poly([(x0 + 2, top - 1), (x0 + 9, top - 5), (x0 + 14, top - 2), (x0 + 12, top + 3)], TOWELS[1])
    c.poly([(x0 + 12, top - 2), (x1 - 3, top - 6), (x1 + 2, top + 6), (x1 - 2, top + 9)], TOWELS[0])
    c.put(x1 + 1, top + 7, shade(TOWELS[0], 0.8))


def a_build(c):
    a_wall(c)
    a_floor(c)
    mirror_cabinet(c, 14, 26, 40, 56, hexc('d6d2c4'), PORC_OUT)
    pedestal_sink(c, 27, 70)
    c.ellipse(34, 73, 2, 1, BLOOD)
    toilet(c, 70)
    c.rect(86, 84, 90, 88, hexc('ece6d6'))                            # the toilet roll on its holder
    # the curtain on a wall rail over the bath, bunched and torn at the left end
    x0, x1, rim = 108, 180, 80
    c.hline(x0 - 2, x1 + 2, 22, CHROME_DK)
    for rx in range(x0, x1 + 1, 6):
        c.put(rx, 23, CHROME)
    cur, cur_dk = hexc('7fa3a0'), hexc('5f817e')
    c.poly([(x0 - 1, 24), (x0 + 12, 24), (x0 + 10, rim - 4), (x0 - 1, rim - 2)], cur)
    for fx in (x0 + 2, x0 + 5, x0 + 8):
        c.line(fx, 25, fx - 1, rim - 4, cur_dk)
    c.poly([(x0 + 12, 24), (x0 + 18, 24), (x0 + 15, 40), (x0 + 12, 44)], cur_dk)
    # the taps: a pipe down the wall to a gooseneck over the right end + a hand shower
    c.rect(x1 - 14, 58, x1 - 13, rim - 4, CHROME_DK)
    c.hline(x1 - 20, x1 - 7, 64, CHROME)
    c.rect(x1 - 21, 62, x1 - 20, 66, CHROME_DK)
    c.rect(x1 - 7, 62, x1 - 6, 66, CHROME_DK)
    c.line(x1 - 14, rim - 4, x1 - 20, rim - 7, CHROME)
    c.rect(x1 - 5, 68, x1 - 3, 72, CHROME)
    c.line(x1 - 4, 73, x1 - 13, rim - 4, CHROME_DK)
    clawfoot_tub(c, x0, x1, rim, PORC, PORC_LT, PORC_DK, PORC_OUT, IRON, hexc('4d5a52'), hexc('6a7b5e'))
    # a towel slung over the left end, a streak of blood down the side
    c.poly([(x0 + 2, rim - 3), (x0 + 12, rim - 3), (x0 + 13, rim + 14), (x0 + 3, rim + 12)], TOWELS[3])
    c.vline(x0 + 12, rim - 2, rim + 13, shade(TOWELS[3], 0.8))
    c.line(150, rim + 4, 152, rim + 15, BLOOD)
    c.put(153, rim + 16, BLOOD)
    setback(c, lambda l: wicker_basket(l, 198, 222, 84, 100), depth=3, top=84)   # against the wall, under the rail
    towel_rail(c, 232, 262, 70)
    shower_corner(c, 274, 308, 16, shade(A_TILE, 0.95), A_GROUT)
    c.dither(274, 90, 308, 95, MOULD, 0.5)
    c.rect(278, 56, 283, 62, hexc('d7c2a0'))                          # soap on the ledge
    c.rect(276, 62, 285, 63, CHROME_DK)
    import furn as F
    F.flush_light(c, 130)                                               # a ceiling dome
    return c


def a_bare(c):
    a_wall(c)


A_ANCHORS = [('anchor_wall_cabinet', 27, 42, 'bp'), ('anchor_wall_sink', 27, 74, 'bp'),
             ('anchor_centre_toilet', 70, 80, 'bp'), ('anchor_bath_left', 122, 83, ''),
             ('anchor_bath_right', 166, 83, ''), ('anchor_floor_laundrybag', 210, 88, 'bp'),
             ('anchor_wall_shower', 291, 68, 'bp')]


# ============================================================================================
# B — avocado (the 70s suite)
# ============================================================================================
AVO = hexc('8a9a4a')
AVO_LT = hexc('a3b25e')
AVO_DK = hexc('6c7a38')
AVO_OUT = hexc('3f4822')
B_TILE = hexc('b8906a')          # brown-beige tiles with a flower motif
B_TILE_DK = hexc('a07b58')
B_GROUT = hexc('7a5e45')
B_FLOWER = hexc('d9a24a')
B_TRIM = hexc('6a4a30')
B_PAINT = hexc('d8b98a')
B_LINO_A = hexc('b8683a')
B_LINO_B = hexc('9a522c')
B_LINO_C = hexc('d18a4e')


def b_wall(c):
    c.rect(0, 0, W - 1, 93, B_PAINT)
    c.dither(0, 6, W - 1, 12, shade(B_PAINT, 0.9), 0.5)
    crown(c, hexc('9a7a58'), hexc('b89870'))
    tiled_wall(c, 34, B_TILE, B_TILE_DK, B_GROUT, B_TRIM, size=10)
    for y in range(37, 94, 20):                                        # a flower tile every other row
        for x in range(4 + ((y // 20) % 2) * 20, W, 40):
            c.put(x + 1, y + 3, B_FLOWER)
            for (dx, dy) in ((0, 2), (2, 2), (1, 1), (1, 3)):
                c.put(x + dx + 1, y + dy + 1, B_FLOWER)
            c.put(x + 2, y + 4, hexc('7a3a20'))
    # decay: a tile fallen off, a brown damp patch in the paint
    c.rect(150, 57, 158, 65, hexc('8a7a68'))
    c.dither(150, 57, 158, 65, hexc('6e6252'), 0.5)
    for i in range(5):
        c.ellipse(200 + i * 5, 14 + (i % 2) * 3, 6, 4, hexc('7a5a3a', 60))


@persp
def b_floor(c):
    # orange lino: a repeating 16px geometric of squares-in-squares (repeats every 32px)
    c.rect(0, 100, W - 1, H - 1, B_LINO_A)
    rows = [100, 105, 111, 118, 126, 135, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, W, 16):
            col = B_LINO_B if ((x // 16) + r) % 2 else B_LINO_A
            c.rect(x, y0, x + 15, y1, col)
            c.rect(x + 5, y0 + (y1 - y0) // 3, x + 10, y1 - (y1 - y0) // 3, B_LINO_C)
        c.hline(0, W - 1, y0, shade(B_LINO_A, 0.8))
    c.hline(0, W - 1, 100, shade(B_LINO_A, 0.5))
    c.hline(0, W - 1, 101, shade(B_LINO_A, 0.72))


def vanity_unit(c, x0, x1, top):
    """A boxy vanity unit with an avocado basin set in, two cupboard doors (one hanging off)."""
    wood, wood_dk = hexc('c9b48a'), hexc('9a8660')
    c.shadow((x0 + x1) // 2, 100, (x1 - x0) // 2 + 2, 2, 100)
    c.box(x0, top, x1, 99, wood, wood_dk)
    c.rect(x0 - 1, top - 3, x1 + 1, top, hexc('e0d6c0'))               # the top
    rrect(c, x0 + 6, top - 3, x1 - 6, top + 1, AVO_OUT, 2)             # the basin, set in
    rrect(c, x0 + 7, top - 2, x1 - 7, top, AVO, 1)
    c.rect((x0 + x1) // 2 - 1, top - 8, (x0 + x1) // 2 + 1, top - 4, CHROME)
    mid = (x0 + x1) // 2
    c.box(x0 + 2, top + 3, mid - 1, 96, wood, wood_dk)
    c.rect(mid - 4, top + 12, mid - 3, top + 16, CHROME_DK)
    c.rect(mid + 1, top + 3, x1 - 2, 96, hexc('3a3228'))               # the other door's gone:
    c.rect(mid + 3, top + 12, mid + 8, 95, hexc('e8e0d0'))              # bleach, a sponge
    c.rect(mid + 10, top + 18, x1 - 4, 95, hexc('d9c24a'))


def panel_bath(c, x0, x1, rim):
    """A rectangular built-in bath with a front panel, along the wall; a glass screen at the tap end."""
    base = rim + 26
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 2, 2, 110)
    c.rect(x0, rim, x1, rim + 3, AVO_LT)                                # the rim, seen from above
    c.hline(x0, x1, rim, AVO_OUT)
    c.rect(x0 + 4, rim + 1, x1 - 4, rim + 2, AVO_DK)                    # the inside edge
    c.box(x0, rim + 4, x1, base, AVO, AVO_OUT)                          # the panel
    c.hline(x0 + 1, x1 - 1, rim + 5, AVO_LT)
    c.box(x0 + 4, rim + 8, x1 - 4, base - 4, AVO, AVO_DK)               # a moulded inset
    c.dither(x0 + 5, base - 8, x1 - 5, base - 5, AVO_DK, 0.5)
    c.hline(x0, x1, base + 1, shade(AVO_OUT, 0.7))
    # the panel's been kicked in at one corner — the dark cavity under the tub shows
    c.poly([(x0 + 10, base - 1), (x0 + 16, rim + 14), (x0 + 26, rim + 16), (x0 + 30, base - 1)], hexc('1e1a16'))
    c.line(x0 + 16, rim + 14, x0 + 26, rim + 16, AVO_LT)
    # taps (left end) + a glass screen hinged at the wall (kept between the window boxes)
    c.rect(x0 + 4, rim - 8, x0 + 6, rim - 1, CHROME)
    c.rect(x0 + 10, rim - 8, x0 + 12, rim - 1, CHROME)
    c.hline(x0 + 3, x0 + 13, rim - 8, CHROME_DK)
    for y in range(26, rim):
        for x in range(x0 + 14, x0 + 25):
            c.put(x, y, GLASS)
    c.vline(x0 + 25, 26, rim - 1, CHROME_DK)
    c.hline(x0 + 14, x0 + 25, 26, CHROME_DK)
    c.line(x0 + 17, rim - 8, x0 + 22, 34, hexc('dde6e6'))
    c.rect(x0 + 2, 30, x0 + 3, 52, CHROME_DK)                           # a shower riser
    c.rect(x0 + 2, 30, x0 + 7, 32, CHROME)


def mop_bucket(c, x0, base):
    c.shadow(x0 + 9, base, 11, 2, 110)
    c.poly([(x0, base - 13), (x0 + 18, base - 13), (x0 + 16, base), (x0 + 2, base)], hexc('c0453a'))
    c.hline(x0, x0 + 18, base - 13, hexc('8a2e26'))
    c.rect(x0 + 2, base - 12, x0 + 16, base - 11, hexc('5a6a5a'))       # grey water
    c.line(x0 + 1, base - 13, x0 + 9, base - 19, hexc('8a8a86'))        # the handle
    c.line(x0 + 9, base - 19, x0 + 17, base - 13, hexc('8a8a86'))
    c.line(x0 + 12, base - 12, x0 + 22, base - 52, hexc('c9b48a'))      # the mop, leant up
    c.poly([(x0 + 7, base - 14), (x0 + 16, base - 14), (x0 + 15, base - 9), (x0 + 8, base - 9)], hexc('cfc5a6'))


def b_build(c):
    b_wall(c)
    b_floor(c)
    # a round mirror with a shelf under it over the vanity
    c.ellipse(28, 40, 13, 13, hexc('9a8660'))
    c.ellipse(28, 40, 11, 11, MIRROR)
    c.line(21, 46, 31, 32, MIRROR_HI)
    c.line(24, 34, 34, 44, shade(MIRROR, 0.8))                           # cracked
    c.rect(14, 56, 42, 57, hexc('e0d6c0'))
    c.rect(18, 51, 21, 55, hexc('e8a0b0')); c.rect(26, 52, 28, 55, hexc('7ab0c8'))
    setback(c, lambda l: vanity_unit(l, 8, 46, 72), depth=4, top=69, x_range=(7, 47), rake=1.0)   # with depth (round 14)
    toilet(c, 70, porc=AVO, out=AVO_OUT, lid_up=True, seat=hexc('d9cfa8'))
    c.rect(86, 80, 91, 86, hexc('ece6d6'))                               # a roll on the cistern's side
    mop_bucket(c, 94, 100)                                             # by the toilet, against the wall
    # a shaggy bath mat in front of the bath, rucked up
    c.poly([(176, 110), (224, 110), (228, 118), (172, 118)], hexc('d9a24a'))
    c.dither(174, 111, 226, 117, hexc('b8863a'), 0.5)
    panel_bath(c, 158, 246, 76)
    def _stool(c):
        c.rect(270, 78, 290, 99, hexc('9a8660'))                         # a stool with a radio
        c.hline(270, 290, 78, hexc('c9b48a'))
        c.rect(272, 80, 274, 99, hexc('7a6648')); c.rect(286, 80, 288, 99, hexc('7a6648'))
        c.box(272, 68, 288, 77, hexc('3e3a36'), hexc('1e1a16'))
        c.rect(274, 70, 280, 75, CHROME)
        c.put(284, 72, hexc('d9a24a'))
        c.line(286, 68, 294, 50, CHROME_DK)                              # its aerial

    def _hamper(c):
        c.rect(296, 70, 308, 99, hexc('c9b48a'))                         # a laundry hamper
        c.box(296, 68, 308, 71, hexc('9a8660'), hexc('6a5638'))
    setback(c, _stool, depth=3, top=78, x_range=(270, 290))
    setback(c, _hamper, depth=3, top=68)
    import furn as F
    F.flush_light(c, 110)
    return c


def b_bare(c):
    b_wall(c)


B_ANCHORS = [('anchor_bathroom_vanity', 20, 84, 'bp'), ('anchor_bathroom_mirror_shelf', 19, 53, 'bp'),
             ('anchor_bathroom_avocado_toilet', 70, 83, 'bp'), ('anchor_bathroom_mop_bucket', 103, 90, 'bp'),
             ('anchor_bathroom_bath_taps', 172, 80, ''), ('anchor_bathroom_bath_panel', 226, 98, ''),
             ('anchor_bathroom_radio_stool', 280, 74, 'bp')]


# ============================================================================================
# C — gilded (something silly)
# ============================================================================================
GOLD = hexc('d4a83a')
GOLD_LT = hexc('f0cf6a')
GOLD_DK = hexc('9a7424')
GOLD_OUT = hexc('5a4214')
MARBLE = hexc('e4ded2')
MARBLE_DK = hexc('cdc6b8')
VEIN = hexc('cfc7b8')
C_BLACK = hexc('26262a')
C_WHITE = hexc('dedad0')


def c_wall(c):
    c.rect(0, 0, W - 1, 93, MARBLE)
    rng = Canvas(seed=77).rng
    for i in range(16):                                                  # soft veins
        x, y = rng.randrange(6, W - 6), rng.randrange(8, 90)
        for k in range(rng.randrange(6, 18)):
            c.put(x, y, VEIN)
            x += rng.choice((-1, 0, 1, 1))
            y += rng.choice((0, 1, 1))
            if not (6 <= x < W - 6 and y < 92):
                break
    for x in range(0, W, 40):                                            # marble slab joints
        c.vline(x + 20, 6, 93, MARBLE_DK)
    crown(c, GOLD_DK, GOLD)
    c.rect(0, 58, W - 1, 60, GOLD)                                       # a gold dado band
    c.hline(0, W - 1, 58, GOLD_LT)
    c.hline(0, W - 1, 61, GOLD_OUT)
    c.rect(0, 94, W - 1, 99, C_BLACK)
    c.hline(0, W - 1, 94, GOLD_DK)
    c.hline(0, W - 1, 99, SEAM)
    # decay: a streak of something down the marble; the gold band scratched
    c.line(212, 20, 214, 56, hexc('8a7a5a', 90))
    c.hline(120, 131, 59, GOLD_DK)


@persp
def c_floor(c):
    c.rect(0, 100, W - 1, H - 1, C_WHITE)
    rows = [100, 106, 114, 124, 136, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, W, 16):
            if ((x // 16) + r) % 2:
                c.rect(x, y0, x + 15, y1, C_BLACK)
    c.hline(0, W - 1, 100, shade(C_WHITE, 0.5))
    c.hline(0, W - 1, 101, shade(C_WHITE, 0.72))


def chandelier(c, cx):
    c.vline(cx, 5, 16, GOLD_DK)
    c.hline(cx - 12, cx + 12, 17, GOLD)
    c.hline(cx - 8, cx + 8, 20, GOLD)
    for dx in (-12, -6, 0, 6, 12):
        c.vline(cx + dx, 17, 21, GOLD_DK)
        c.rect(cx + dx - 1, 12, cx + dx, 16, hexc('efe8d8'))           # candles
        c.put(cx + dx, 11, hexc('f0cf6a'))
    for dx in (-10, -4, 4, 10):                                          # crystals
        c.put(cx + dx, 23, hexc('cfe0e6')); c.put(cx + dx, 25, hexc('cfe0e6'))
    c.put(cx + 2, 24, hexc('cfe0e6'))
    from pixlib import light
    light(cx, 18, 'chandelier')


def gilt_mirror(c, x0, y0, x1, y1):
    c.box(x0, y0, x1, y1, GOLD, GOLD_OUT)
    c.box(x0 + 2, y0 + 2, x1 - 2, y1 - 2, GOLD_DK)
    c.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, MIRROR)
    c.line(x0 + 5, y1 - 5, x1 - 8, y0 + 5, MIRROR_HI)
    for (px, py) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):           # ornate corners
        c.rect(px - 1, py - 1, px + 1, py + 1, GOLD_LT)
    c.poly([((x0 + x1) // 2 - 5, y0), ((x0 + x1) // 2, y0 - 5), ((x0 + x1) // 2 + 5, y0)], GOLD)


def washstand(c, x0, x1, top):
    c.shadow((x0 + x1) // 2, 100, (x1 - x0) // 2 + 2, 2, 100)
    c.rect(x0 - 1, top, x1 + 1, top + 3, MARBLE)                         # a marble top
    c.hline(x0 - 1, x1 + 1, top, VEIN)
    c.hline(x0 - 1, x1 + 1, top + 3, MARBLE_DK)
    c.ellipse((x0 + x1) // 2, top, 8, 1, GOLD_DK)                        # the gold basin set in
    c.rect((x0 + x1) // 2 - 1, top - 6, (x0 + x1) // 2 + 1, top - 1, GOLD)
    c.put((x0 + x1) // 2 + 2, top - 6, GOLD_LT)
    for lx in (x0 + 2, x1 - 3):                                          # gilt cabriole legs
        c.line(lx, top + 4, lx + (2 if lx < x1 - 5 else -2), 94, GOLD)
        c.line(lx + (2 if lx < x1 - 5 else -2), 94, lx, 99, GOLD)
    c.box(x0 + 4, top + 4, x1 - 4, top + 10, hexc('f0ebe0'), GOLD_DK)   # a drawer
    c.rect((x0 + x1) // 2 - 1, top + 7, (x0 + x1) // 2 + 1, top + 7, GOLD)
    c.rect(x0 + 2, top - 5, x0 + 6, top - 1, hexc('b8d0d8'))             # perfume
    c.put(x0 + 4, top - 6, GOLD)


def champagne(c, x0, base):
    c.shadow(x0 + 7, base, 9, 2, 110)
    for lx in (x0 + 2, x0 + 12):                                         # the stand
        c.line(lx, base - 16, lx + (-2 if lx < x0 + 5 else 2), base, GOLD_DK)
    c.poly([(x0, base - 24), (x0 + 14, base - 24), (x0 + 12, base - 14), (x0 + 2, base - 14)], GOLD)
    c.hline(x0, x0 + 14, base - 24, GOLD_LT)
    c.rect(x0 + 5, base - 33, x0 + 8, base - 25, hexc('2e4a2e'))        # the bottle
    c.rect(x0 + 6, base - 36, x0 + 7, base - 34, GOLD)


def c_build(c):
    c_wall(c)
    c_floor(c)
    gilt_mirror(c, 14, 20, 44, 52)
    setback(c, lambda l: washstand(l, 10, 46, 72), depth=4, top=72, x_range=(9, 47), rake=1.0)
    toilet(c, 72, porc=GOLD, out=GOLD_OUT, seat=hexc('7a1f2a'), lever=GOLD_LT)   # a red velvet seat
    chandelier(c, 160)
    # a leopard rug under the tub
    c.poly([(116, 110), (204, 110), (212, 120), (108, 120)], hexc('c89a4a'))
    for (sx, sy) in ((120, 113), (132, 116), (148, 112), (166, 117), (180, 113), (196, 116), (204, 118), (140, 118)):
        c.rect(sx, sy, sx + 2, sy + 1, hexc('4a3220'))
    clawfoot_tub(c, 124, 196, 84, GOLD, GOLD_LT, GOLD_DK, GOLD_OUT, GOLD_DK, hexc('6a5418'), hexc('d9e0c8'))
    # bubbles piled over the rim + a rubber duck
    for (bx, by) in ((140, 81), (146, 79), (152, 80), (158, 78), (164, 80), (170, 79), (176, 81)):
        c.ellipse(bx, by, 3, 2, hexc('f4f2ec'))
    c.rect(180, 76, 184, 79, hexc('f0cf3a')); c.put(185, 77, hexc('e07a2a'))
    champagne(c, 216, 118)
    # a potted palm (right of the R window box) + a gold towel stand
    c.shadow(292, 100, 10, 2, 90)
    c.poly([(286, 86), (298, 86), (296, 99), (288, 99)], GOLD)
    for (tx, ty) in ((280, 58), (286, 50), (294, 48), (304, 56), (300, 66), (282, 68)):
        c.line(292, 86, tx, ty, hexc('4a6a34'))
        c.line(292, 85, tx + 1, ty + 2, hexc('5e8240'))
    c.rect(238, 67, 239, 99, GOLD_DK)
    c.hline(232, 245, 99, GOLD_DK)
    c.hline(232, 245, 67, GOLD)  # (the rail tops out under the R window box)
    c.rect(233, 68, 244, 88, hexc('7a1f2a'))
    c.hline(233, 244, 68, hexc('9a3a44'))
    return c


def c_bare(c):
    c_wall(c)


C_ANCHORS = [('anchor_bathroom_gilt_mirror', 29, 44, 'bp'), ('anchor_bathroom_washstand', 28, 79, 'bp'),
             ('anchor_bathroom_gold_throne', 72, 82, 'bp'), ('anchor_bathroom_gold_tub', 136, 88, ''),
             ('anchor_bathroom_bubbles', 176, 86, ''), ('anchor_bathroom_champagne', 223, 100, ''),
             ('anchor_bathroom_towel_stand', 239, 78, 'bp')]


# ============================================================================================
# D — wet room (squalid)
# ============================================================================================
D_TILE = hexc('b9c2c0')
D_TILE_DK = hexc('a3aca9')
D_GROUT = hexc('6f7876')
D_TRIM = hexc('7a8480')
D_PAINT = hexc('8e948a')


def d_wall(c):
    c.rect(0, 0, W - 1, 93, D_PAINT)
    crown(c, hexc('5e645c'), hexc('747a70'))
    tiled_wall(c, 30, D_TILE, D_TILE_DK, D_GROUT, D_TRIM, size=12)
    # heavy black mould: blooms up from the skirting and down from the ceiling
    c.dither(0, 6, 60, 26, MOULD, 0.5, pattern='random')
    c.dither(0, 70, 40, 93, MOULD, 0.35, pattern='random')
    c.dither(150, 6, 226, 16, MOULD, 0.4, pattern='random')
    c.dither(272, 60, W - 1, 93, MOULD, 0.45, pattern='random')
    for x in (104, 186, 214):                                            # rust runs from pipes
        c.line(x, 30, x + 1, 60, RUST)


@persp
def d_floor(c):
    # grey sheet vinyl, lifting in a seam line, a drain grate every 64px (periodic by 32)
    base = hexc('8a8f8a')
    c.rect(0, 100, W - 1, H - 1, base)
    for y in range(102, H):
        for x in range(W):
            k = (x * 5 + y * 11) % 32
            if k in (4, 21):
                c.put(x, y, shade(base, 0.9))
            elif k == 13:
                c.put(x, y, shade(base, 1.08))
    for x in range(0, W, 32):
        c.vline(x + 20, 102, H - 1, shade(base, 0.82))
    c.hline(0, W - 1, 100, shade(base, 0.5))
    c.hline(0, W - 1, 101, shade(base, 0.7))


def curtained_tub(c, x0, x1, rim):
    """A plastic curtain drawn right across the front of the bath — you can't see what's behind it;
    a hand has pulled one corner aside. The rail runs on the wall above."""
    base = rim + 26
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 2, 2, 110)
    c.box(x0, rim, x1, base, PORC, PORC_OUT)                             # the tub's end, glimpsed
    c.hline(x0 + 1, x1 - 1, rim + 1, PORC_LT)
    cur = hexc('c9c48a', 235)
    c.hline(x0 - 2, x1 + 2, 30, CHROME_DK)
    for x in range(x0 + 12, x1 + 1):                                     # the curtain, hanging in folds
        top = 31
        bot = base - 2 + (1 if (x // 4) % 2 else 0)
        c.vline(x, top, bot, cur)
        if (x - x0) % 7 == 0:
            c.vline(x, top, bot, shade(cur, 0.82))
        if (x - x0) % 7 == 3:
            c.vline(x, top, bot, shade(cur, 1.08))
    for x in range(x0 + 12, x1 + 1, 6):                                  # rings
        c.put(x, 31, CHROME)
    c.dither(x0 + 12, base - 20, x1, base - 3, hexc('7a7a4a', 90), 0.4, pattern='random')   # grime at the hem
    for (fx, fy) in ((x0 + 30, 44), (x0 + 50, 40), (x0 + 40, 58)):     # ducks printed on it
        c.rect(fx, fy, fx + 4, fy + 3, hexc('d9b43a'))
        c.put(fx + 5, fy + 1, hexc('c06a2a'))
    c.poly([(x0 + 12, 31), (x0 + 16, 31), (x0 + 22, base - 2), (x0 + 12, base - 4)], shade(cur, 0.9))
    c.line(x0 + 12, 31, x0 + 12, base - 4, shade(cur, 0.7))
    c.line(x0 + 24, 70, x0 + 30, 88, BLOOD)                              # a smear down the plastic
    c.line(x0 + 26, 70, x0 + 31, 84, BLOOD)


def washing_machine(c, x0, top):
    x1 = x0 + 32
    c.shadow(x0 + 16, 100, 18, 2, 100)
    c.box(x0, top, x1, 99, hexc('e0ded6'), hexc('6d6c64'))
    c.rect(x0 + 1, top + 1, x1 - 1, top + 5, hexc('cfcdc4'))
    c.rect(x0 + 3, top + 2, x0 + 8, top + 4, hexc('5a6a78'))
    c.put(x1 - 5, top + 3, hexc('c0453a'))
    c.ellipse(x0 + 16, top + 18, 10, 10, hexc('6d6c64'))
    c.ellipse(x0 + 16, top + 18, 8, 8, hexc('2a2e30'))
    # its door hanging open, a tangle of clothes dragged out onto the floor
    c.ellipse(x0 - 4, top + 18, 5, 9, hexc('9aa6ac'))
    c.ellipse(x0 - 4, top + 18, 3, 7, GLASS)
    c.poly([(x0 + 12, top + 20), (x0 + 20, top + 19), (x0 + 18, top + 25), (x0 + 12, top + 26)], TOWELS[0])
    c.poly([(x0 + 13, top + 25), (x0 + 18, top + 25), (x0 + 12, 100), (x0 + 4, 100)], TOWELS[0])
    c.line(x0 + 15, top + 26, x0 + 8, 99, shade(TOWELS[0], 0.8))
    c.poly([(x0 - 6, 99), (x0 + 6, 97), (x0 + 10, 102), (x0 - 4, 104)], TOWELS[1])
    c.line(x0 - 4, 101, x0 + 8, 100, shade(TOWELS[1], 0.8))


def clothes_horse(c, x0, x1, base):
    """A folding clothes airer standing out in the room, damp laundry hung over its rails."""
    wood, wood_dk = hexc('c9b48a'), hexc('9a8660')
    top = base - 34
    c.shadow((x0 + x1) // 2, base, (x1 - x0) // 2 + 2, 2, 110)
    for lx in (x0, x1):                                                  # the two frames
        c.rect(lx, top, lx + 1, base, wood)
        c.vline(lx + 1, top, base, wood_dk)
    for ry in (top, top + 11, top + 22):
        c.hline(x0, x1 + 1, ry, wood)
    # hung laundry: a towel, a shirt, a pair of socks — each folded OVER a rail
    t = TOWELS[2]
    c.rect(x0 + 3, top + 1, x0 + 15, top + 20, t)
    c.hline(x0 + 3, x0 + 15, top + 1, shade(t, 1.1))
    c.vline(x0 + 15, top + 1, top + 20, shade(t, 0.82))
    for x in range(x0 + 3, x0 + 16, 2):
        c.put(x, top + 21, shade(t, 0.85))
    sh = TOWELS[4]
    c.poly([(x0 + 19, top + 12), (x0 + 31, top + 12), (x0 + 33, top + 16), (x0 + 31, top + 17), (x0 + 30, top + 27), (x0 + 20, top + 27), (x0 + 19, top + 17), (x0 + 17, top + 16)], sh)
    c.vline(x0 + 25, top + 13, top + 26, shade(sh, 0.85))
    c.hline(x0 + 19, x0 + 31, top + 12, shade(sh, 1.1))
    for (sx, col) in ((x1 - 9, TOWELS[3]), (x1 - 5, TOWELS[1])):
        c.rect(sx, top + 23, sx + 2, top + 30, col)
        c.hline(sx, sx + 3, top + 30, col)
    c.put(x0 + 8, top + 24, hexc('6a7a8a', 140)); c.put(x0 + 11, top + 27, hexc('6a7a8a', 140))
    c.ellipse(x0 + 10, base, 5, 1, hexc('6a7a8a', 90))                  # a puddle under it


def d_build(c):
    d_wall(c)
    d_floor(c)
    # a cracked mirror tile + a small sink on brackets
    c.box(14, 32, 40, 54, hexc('7a8480'), hexc('3a403e'))
    c.rect(16, 34, 38, 52, MIRROR)
    c.line(18, 50, 34, 36, MIRROR_HI)
    c.line(24, 36, 30, 50, shade(MIRROR, 0.75)); c.line(30, 50, 36, 44, shade(MIRROR, 0.75))
    rrect(c, 12, 66, 42, 74, PORC_OUT, 3)
    rrect(c, 13, 67, 41, 73, PORC, 3)
    c.rect(26, 60, 28, 65, CHROME_DK)
    c.line(16, 75, 18, 84, IRON); c.line(38, 75, 36, 84, IRON)           # brackets
    c.vline(27, 75, 99, IRON)                                            # the waste pipe
    c.rect(24, 92, 30, 97, RUST)
    toilet(c, 70, lid_up=True, seat=hexc('b9b4a4'))
    c.dither(60, 67, 80, 70, MOULD, 0.5)
    c.rect(86, 88, 96, 99, hexc('d8d2c2'))                               # toilet rolls stacked
    c.hline(86, 96, 93, shade(hexc('d8d2c2'), 0.8))
    curtained_tub(c, 106, 178, 80)
    clothes_horse(c, 204, 244, 121)
    setback(c, lambda l: washing_machine(l, 277, 60), depth=5, top=60, x_range=(277, 309), rake=1.0)
    import furn as F
    F.bare_bulb(c, 200, 22)
    return c


def d_bare(c):
    d_wall(c)


D_ANCHORS = [('anchor_bathroom_small_sink', 27, 70, 'bp'), ('anchor_bathroom_grim_toilet', 70, 84, 'bp'),
             ('anchor_bathroom_toilet_rolls', 91, 94, 'bp'), ('anchor_bathroom_behind_curtain', 150, 84, ''),
             ('anchor_bathroom_curtain_corner', 118, 94, ''), ('anchor_bathroom_clothes_horse', 226, 100, ''),
             ('anchor_bathroom_washer', 283, 88, 'bp')]


# ============================================================================================
# E — pink 50s
# ============================================================================================
PINK = hexc('e0a8b4')
PINK_LT = hexc('efc4cc')
PINK_DK = hexc('c08894')
PINK_OUT = hexc('6a4048')
E_TILE = hexc('e8c4c8')
E_TILE_DK = hexc('d8b0b6')
E_TRIM = hexc('26262a')


def e_wall(c):
    c.rect(0, 0, W - 1, 93, hexc('d8d0c0'))
    crown(c, hexc('a89a88'), hexc('c0b4a0'))
    tiled_wall(c, 44, E_TILE, E_TILE_DK, hexc('b89aa0'), E_TRIM, size=8)
    c.rect(0, 58, W - 1, 59, E_TRIM)                                            # a black pencil-tile line
    c.dither(0, 6, 40, 18, MOULD, 0.35, pattern='random')
    c.dither(286, 6, W - 1, 20, MOULD, 0.35, pattern='random')


@persp
def e_floor(c):
    # black and white hexagon-ish mosaic: offset 8px blocks (repeats every 32px)
    c.rect(0, 100, W - 1, H - 1, hexc('e6e2d8'))
    rows = [100, 104, 109, 115, 122, 130, 139, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        off = 4 if r % 2 else 0
        for x in range(-8, W, 8):
            col = hexc('2e2e33') if ((x + 8) // 8 + r) % 4 == 0 else hexc('e6e2d8')
            c.rect(max(0, x + off), y0, min(W - 1, x + off + 7), y1, col)
            if 0 <= x + off < W:
                c.vline(x + off, y0, y1, hexc('b9b5ab'))
        c.hline(0, W - 1, y0, hexc('b9b5ab'))
    c.hline(0, W - 1, 100, hexc('7a766c'))


def e_build(c):
    e_wall(c)
    e_floor(c)
    # a round mirror with a pink frame + a glass shelf of bottles over a pink pedestal sink
    c.ellipse(28, 34, 12, 12, PINK_DK)
    c.ellipse(28, 34, 10, 10, MIRROR)
    c.line(22, 40, 32, 26, MIRROR_HI)
    c.rect(14, 50, 42, 51, hexc('c9d8d8'))
    for (x, col) in ((16, hexc('e8a0b0')), (22, hexc('7ab0c8')), (30, hexc('e0d9b8')), (36, hexc('c07a3a'))):
        c.rect(x, 45, x + 3, 49, col)
    pedestal_sink(c, 28, 70, porc=PINK, porc_dk=PINK_DK, out=PINK_OUT)
    toilet(c, 70, porc=PINK, out=PINK_OUT, seat=hexc('26262a'))
    c.rect(86, 80, 91, 86, hexc('efe8d8'))
    # a short pink tub on a tiled plinth, pulled to the lane, a shower curtain drawn back
    x0, x1, rim = 110, 186, 82
    c.hline(x0 - 2, x1 + 2, 24, CHROME_DK)
    cur = hexc('efe8d8')
    c.poly([(x1 - 12, 25), (x1 + 2, 25), (x1 + 2, rim - 2), (x1 - 8, rim - 4)], cur)
    for fx in (x1 - 9, x1 - 5, x1 - 1):
        c.line(fx, 26, fx - 1, rim - 4, hexc('d0c8b4'))
    for (x, y) in ((x1 - 8, 36), (x1 - 3, 50), (x1 - 7, 64)):                   # little pink fish on it
        c.rect(x, y, x + 3, y + 1, PINK_DK)
    c.shadow((x0 + x1) // 2, rim + 27, (x1 - x0) // 2 + 3, 3, 110)
    rrect(c, x0, rim, x1, rim + 5, PINK_OUT, 3)
    rrect(c, x0 + 1, rim + 1, x1 - 1, rim + 4, PINK_LT, 2)
    c.rect(x0 + 5, rim + 2, x1 - 5, rim + 3, hexc('8a6a74'))
    c.box(x0, rim + 6, x1, rim + 26, E_TILE, PINK_OUT)                          # the tiled plinth
    for y in range(rim + 10, rim + 26, 6):
        c.hline(x0 + 1, x1 - 1, y, hexc('b89aa0'))
    for x in range(x0 + 6, x1, 8):
        c.vline(x, rim + 7, rim + 25, hexc('b89aa0'))
    c.rect(x0 + 6, rim - 8, x0 + 8, rim - 1, CHROME)                             # taps
    c.rect(x0 + 12, rim - 8, x0 + 14, rim - 1, CHROME)
    c.hline(x0 + 5, x0 + 15, rim - 8, CHROME_DK)
    c.line(150, rim + 6, 152, rim + 20, BLOOD)
    # a pink fluffy bath mat in front of the tub + a laundry hamper against the wall beside it
    c.poly([(124, 112), (170, 112), (172, 118), (122, 118)], PINK_LT)
    c.dither(124, 113, 170, 117, PINK, 0.5)
    def _hamper(c):
        c.shadow(214, 100, 12, 2, 100)
        c.poly([(202, 81), (226, 81), (224, 100), (204, 100)], hexc('efe8d8'))
        for y in range(84, 100, 3):
            c.hline(203, 225, y, hexc('d0c8b4'))
        c.rect(200, 78, 228, 81, PINK_DK)
        c.poly([(206, 78), (212, 72), (216, 78)], TOWELS[1])
    setback(c, _hamper, depth=3, top=78, x_range=(200, 228))
    # a vanity stool + a frosted-glass cabinet on the right
    c.shadow(242, 100, 8, 1, 90)
    c.ellipse(242, 84, 8, 3, PINK)
    for lx in (236, 248):
        c.vline(lx, 86, 99, CHROME_DK)
    # a LINEN CUPBOARD on the right (owner round 14: the old tall frosted-glass cabinet "looks like a
    # door. It isn't a door. Players will think it's a door"): chest height, a cornice, open shelves of
    # folded towels + toilet rolls, two little doors below, bun feet — and depth, so it's a piece of
    # furniture standing in the room, not a panel in the wall
    setback(c, _linen_cupboard, depth=5, top=44, x_range=(277, 309), rake=1.0)
    import furn as F
    F.flush_light(c, 100)
    return c


def _linen_cupboard(c):
    x0, x1, top = 278, 308, 46
    body, body_dk, trim = hexc('efe8d8'), hexc('c9c0ae'), PINK_DK
    c.shadow(293, 100, 17, 2, 100)
    c.rect(x0 - 1, top - 2, x1 + 1, top, trim)                                  # the cornice
    c.hline(x0 - 1, x1 + 1, top - 2, shade(trim, 1.2))
    c.box(x0, top + 1, x1, 95, body, PINK_OUT)
    c.rect(x0 + 2, top + 3, x1 - 2, 70, hexc('b8aaa8'))                         # the open shelves
    c.rect(x0 + 2, 58, x1 - 2, 59, body)
    c.hline(x0 + 2, x1 - 2, 58, shade(body, 1.05))
    for (tx, ty, col) in ((x0 + 4, 53, TOWELS[1]), (x0 + 4, 50, hexc('f4f0e6')), (x0 + 4, 47, TOWELS[1]),
                          (x0 + 16, 54, hexc('f4f0e6')), (x0 + 16, 51, PINK)):  # folded towels
        c.rect(tx, ty, tx + 10, ty + 3, col)
        c.hline(tx, tx + 10, ty + 3, shade(col, 0.8))
        c.vline(tx + 10, ty, ty + 3, shade(col, 0.85))
    for k in range(4):                                                         # toilet rolls
        rx = x0 + 4 + k * 6
        c.rect(rx, 64, rx + 4, 69, hexc('f4f0e6'))
        c.put(rx + 2, 66, hexc('b8b0a0'))
    c.rect(x0 + 2, 70, x1 - 2, 71, body)
    for (d0, d1) in ((x0 + 2, (x0 + x1) // 2 - 1), ((x0 + x1) // 2 + 1, x1 - 2)):   # two small doors
        c.box(d0, 73, d1, 93, body, body_dk)
        c.box(d0 + 2, 75, d1 - 2, 91, body, body_dk)
    c.put((x0 + x1) // 2 - 3, 83, CHROME); c.put((x0 + x1) // 2 + 3, 83, CHROME)
    for fx in (x0 + 1, x1 - 3):                                                 # bun feet
        c.rect(fx, 96, fx + 2, 99, PINK_OUT)


def e_bare(c):
    e_wall(c)


E_ANCHORS = [('anchor_bathroom_glass_shelf', 23, 47, 'bp'), ('anchor_wall_sink', 28, 74, 'bp'),
             ('anchor_centre_toilet', 70, 82, 'bp'), ('anchor_bathroom_pink_tub', 148, 84, ''),
             ('anchor_bathroom_hamper', 214, 90, 'bp'), ('anchor_bathroom_pink_taps', 117, 78, ''), ('anchor_bathroom_frosted_cabinet', 292, 82, 'bp')]


VARIANTS = {
    'a': ('bathroom', 41, a_bare, a_floor, a_build, A_ANCHORS),
    'b': ('bathroom_b', 42, b_bare, b_floor, b_build, B_ANCHORS),
    'c': ('bathroom_c', 43, c_bare, c_floor, c_build, C_ANCHORS),
    'd': ('bathroom_d', 44, d_bare, d_floor, d_build, D_ANCHORS),
    'e': ('bathroom_e', 45, e_bare, e_floor, e_build, E_ANCHORS),
}


if __name__ == '__main__':
    for v in (sys.argv[1:] or sorted(VARIANTS)):
        name, seed, bare, floor, build, anchors = VARIANTS[v]
        finish_module(name, 'bathroom', seed, bare, floor, build, anchors)
