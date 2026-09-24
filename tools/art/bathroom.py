"""Bathroom module — 320 x 144 native pixel art, in the living room's style.

Run:  python3 tools/art/bathroom.py
Out:  assets/rooms/bathroom.png (+ bathroom_floor.png, docs preview)

Layout (left -> right): a pedestal sink under a mirrored cabinet hanging ajar (nodes: the cabinet,
the basin), a low-cistern toilet (node), the bath lengthwise along the wall with a torn curtain
(nodes: either end of the tub — the bath comes forward to the lane like the bed), a laundry bag
slumped on the floor (node), and a corner shower cubicle (node). Tiles to shoulder height, grimy
paint above; a small mosaic floor that repeats every 32px.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import (Canvas, hexc, shade, SEAM_Y, W, H, check_window_boxes, check_edge_columns,
                    save_floor_strip, floor_is_periodic, rrect)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

PAINT = hexc('9fa89a')          # grimy pale green paint
PAINT_TOP = hexc('8d9688')
CROWN = hexc('6f776b')
CROWN_HI = hexc('858d80')
TILE = hexc('c9cdc0')           # off-white tiles
TILE_DK = hexc('b4b8ab')
GROUT = hexc('8d9185')
TILE_TRIM = hexc('5d7d78')      # a teal border row
SEAM = hexc('2a2622')

MOS_A = hexc('d3d4cb')          # mosaic floor
MOS_B = hexc('3f4a4d')
MOS_GROUT = hexc('9ea196')

PORC = hexc('e1e0d6')           # porcelain
PORC_DK = hexc('bdbcb1')
PORC_LT = hexc('f1f0e8')
PORC_OUT = hexc('6d6c64')
CHROME = hexc('aab0b2')
CHROME_DK = hexc('7a8083')
MIRROR = hexc('8b9aa0')
MIRROR_HI = hexc('b8c3c4')
CAB = hexc('d6d2c4')
CAB_DK = hexc('aea999')
CAB_IN = hexc('3a3833')
CURTAIN = hexc('7fa3a0')
CURTAIN_DK = hexc('5f817e')
GLASS = hexc('a9bcbe', 150)
WATER = hexc('6a7b5e')
MOULD = hexc('3c4a36', 110)
RUST = hexc('8a5a3a', 140)
BLOOD = hexc('4a1d1b', 150)
BAG = hexc('b7a98a')
BAG_DK = hexc('988b6e')


def wall(c):
    c.rect(0, 0, W - 1, 93, PAINT)
    c.rect(0, 6, W - 1, 8, PAINT_TOP)
    c.dither(0, 9, W - 1, 13, PAINT_TOP, 0.5)
    c.rect(0, 0, W - 1, 4, CROWN)
    c.hline(0, W - 1, 4, CROWN_HI)
    c.hline(0, W - 1, 5, shade(CROWN, 0.8))
    # tiles from y 40 down to the skirting, a teal border row on top
    c.rect(0, 40, W - 1, 93, TILE)
    c.rect(0, 40, W - 1, 42, TILE_TRIM)
    for y in range(43, 94, 8):
        c.hline(0, W - 1, y, GROUT)
    for x in range(0, W, 8):
        c.vline(x, 43, 93, GROUT)
    for y in range(44, 93, 16):
        c.dither(0, y, W - 1, y + 1, TILE_DK, 0.5)
    c.rect(0, 94, W - 1, 99, TILE_TRIM)                    # a tiled skirting
    c.hline(0, W - 1, 94, shade(TILE_TRIM, 1.15))
    c.hline(0, W - 1, 99, SEAM)


def decay(c):
    # black mould creeping from the ceiling corners and along the grout above the bath
    c.dither(0, 6, 30, 20, MOULD, 0.4, pattern='random')
    c.dither(290, 6, W - 1, 24, MOULD, 0.4, pattern='random')
    c.dither(110, 44, 200, 52, MOULD, 0.18, pattern='random')
    c.line(150, 48, 158, 60, GROUT)                          # a cracked tile
    c.line(158, 60, 155, 66, GROUT)


def floor(c):
    # 8px mosaic, a dark tile every other on alternate rows -> repeats every 16/32px
    c.rect(0, 100, W - 1, H - 1, MOS_A)
    rows = [100, 104, 109, 115, 122, 130, 139, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, W, 8):
            col = MOS_B if ((x // 8) % 4 == (r % 2) * 2) else MOS_A
            c.rect(x, y0, x + 7, y1, col)
            c.vline(x, y0, y1, MOS_GROUT)
        c.hline(0, W - 1, y0, MOS_GROUT)
    c.hline(0, W - 1, 100, shade(MOS_A, 0.55))
    c.hline(0, W - 1, 101, shade(MOS_A, 0.75))


def sink(c):
    # left of the L window box (x < 50)
    c.shadow(27, 100, 12, 2, 90)
    c.rect(24, 80, 30, 99, PORC)                              # pedestal
    c.vline(29, 80, 99, PORC_DK)
    c.vline(24, 80, 99, PORC_OUT)
    c.vline(30, 80, 99, PORC_OUT)
    rrect(c, 12, 70, 42, 80, PORC_OUT, 3)                     # basin
    rrect(c, 13, 71, 41, 79, PORC, 3)
    c.hline(15, 39, 72, PORC_DK)                              # the bowl's inside rim
    c.rect(18, 73, 36, 75, shade(PORC, 0.86))
    c.put(27, 74, RUST); c.put(28, 75, RUST)
    c.rect(26, 66, 28, 69, CHROME)                            # tap
    c.put(28, 70, CHROME_DK)
    c.ellipse(34, 73, 2, 1, BLOOD)                            # blood in the basin


def cabinet(c):
    # a mirrored cabinet over the sink, its door hanging open (the cabinet node)
    c.box(14, 26, 40, 56, CAB, PORC_OUT)
    c.rect(16, 28, 38, 54, CAB_IN)
    c.hline(16, 40, 36, CAB_DK)                               # shelves
    c.hline(16, 40, 46, CAB_DK)
    c.rect(18, 30, 21, 35, hexc('c05a3a'))                    # pill bottles
    c.rect(24, 31, 26, 35, hexc('e0d9b8'))
    c.rect(30, 39, 35, 45, hexc('6f8fa0'))
    c.rect(18, 49, 24, 53, hexc('d9c38a'))
    c.poly([(40, 26), (47, 28), (47, 54), (40, 56)], CAB)     # the door, mirror side out
    c.poly([(41, 28), (46, 30), (46, 52), (41, 54)], MIRROR)
    c.line(42, 50, 45, 32, MIRROR_HI)


def toilet(c):
    # low cistern — kept below the L window box (y >= 67) — bowl, pedestal
    c.shadow(70, 100, 13, 2, 90)
    c.box(60, 67, 80, 77, PORC, PORC_OUT)                      # cistern
    c.hline(61, 79, 68, PORC_LT)
    c.rect(77, 70, 79, 71, CHROME)                             # flush lever
    rrect(c, 58, 78, 82, 88, PORC_OUT, 4)                      # seat/bowl rim
    rrect(c, 59, 79, 81, 87, PORC, 4)
    c.hline(61, 79, 80, PORC_LT)
    c.poly([(62, 88), (78, 88), (75, 99), (65, 99)], PORC)     # pedestal
    c.line(62, 88, 65, 99, PORC_OUT)
    c.line(78, 88, 75, 99, PORC_OUT)
    c.hline(65, 75, 99, PORC_OUT)
    c.rect(86, 84, 90, 88, hexc('ece6d6'))                     # a toilet roll on the floor... on its holder
    c.put(88, 86, shade(hexc('ece6d6'), 0.7))


def bath(c):
    # lengthwise along the wall, coming forward to the lane (base ~108): rim top, the tub side,
    # clawed feet; a curtain rail above with the curtain torn and bunched at the left end
    x0, x1 = 98, 214
    c.shadow(156, 109, 60, 3, 110)
    c.hline(x0 + 4, x1 - 4, 20, CHROME_DK)                     # the curtain rail (between the boxes)
    for rx in range(x0 + 6, x1 - 4, 6):
        c.put(rx, 21, CHROME)
    c.poly([(x0 + 4, 22), (x0 + 16, 22), (x0 + 13, 74), (x0 + 4, 76)], CURTAIN)
    for fx in (x0 + 7, x0 + 10, x0 + 13):
        c.line(fx, 23, fx - 1, 74, CURTAIN_DK)
    c.poly([(x0 + 16, 22), (x0 + 22, 22), (x0 + 19, 40), (x0 + 16, 44)], CURTAIN_DK)   # the torn flap
    # the rim (we look down onto it) and the water inside
    rrect(c, x0, 74, x1, 84, PORC_OUT, 4)
    rrect(c, x0 + 1, 75, x1 - 1, 83, PORC, 4)
    c.rect(x0 + 5, 77, x1 - 5, 82, WATER)
    c.hline(x0 + 5, x1 - 5, 77, shade(WATER, 1.15))
    c.dither(x0 + 20, 79, x1 - 30, 81, shade(WATER, 0.8), 0.3, pattern='random')
    # the tub side
    c.poly([(x0 + 1, 84), (x1 - 1, 84), (x1 - 5, 102), (x0 + 5, 102)], PORC)
    c.hline(x0 + 3, x1 - 3, 85, PORC_LT)
    c.hline(x0 + 5, x1 - 5, 102, PORC_OUT)
    c.line(x0 + 1, 84, x0 + 5, 102, PORC_OUT)
    c.line(x1 - 1, 84, x1 - 5, 102, PORC_OUT)
    c.dither(x0 + 8, 96, x1 - 8, 101, PORC_DK, 0.5)
    for fx in (x0 + 8, x1 - 12):                                # claw feet
        c.rect(fx, 103, fx + 3, 107, CHROME_DK)
        c.hline(fx - 1, fx + 4, 107, CHROME_DK)
    # taps at the right end
    c.rect(x1 - 14, 68, x1 - 12, 74, CHROME)
    c.rect(x1 - 8, 68, x1 - 6, 74, CHROME)
    c.hline(x1 - 15, x1 - 5, 68, CHROME_DK)
    # a streak of blood down the side
    c.line(150, 84, 152, 96, BLOOD)
    c.put(153, 97, BLOOD)


def laundry(c):
    # a canvas laundry bag slumped on the floor (the node), clothes spilling
    c.shadow(232, 114, 14, 2, 100)
    c.poly([(220, 114), (222, 100), (228, 94), (238, 95), (244, 102), (245, 114)], BAG)
    c.poly([(228, 94), (231, 90), (235, 90), (238, 95)], BAG_DK)
    c.line(226, 104, 240, 104, BAG_DK)
    c.poly([(244, 110), (254, 108), (258, 114), (246, 116)], hexc('6e7f95'))   # a towel
    c.rect(250, 104, 256, 106, hexc('c26b5a'))                                  # a sock


def shower(c):
    # a corner shower right of the R window box (x > 270): tray, glass door, head, a mouldy seal
    x0, x1, top = 274, 308, 16
    c.rect(x0, top, x1, 99, shade(TILE, 0.95))
    for y in range(top + 4, 99, 8):
        c.hline(x0, x1, y, GROUT)
    c.box(x0 - 2, 96, x1 + 2, 100, PORC, PORC_OUT)               # tray
    c.rect(x1 - 6, top + 6, x1 - 5, top + 20, CHROME_DK)          # pipe + head
    c.rect(x1 - 12, top + 6, x1 - 6, top + 7, CHROME_DK)
    c.rect(x1 - 15, top + 8, x1 - 10, top + 9, CHROME)
    c.dither(x0, 90, x1, 95, MOULD, 0.5)                         # the seal, black
    c.rect(x0 + 4, top + 40, x0 + 9, top + 46, hexc('d7c2a0'))    # a soap dish + soap on the ledge
    c.rect(x0 + 2, top + 46, x0 + 11, top + 47, CHROME_DK)
    # the glass door, half open, a frame line and a sheen
    for y in range(top, 96):
        for x in range(x0, x0 + 12):
            c.put(x, y, GLASS)
    c.vline(x0, top, 95, CHROME_DK)
    c.vline(x0 + 12, top, 95, CHROME_DK)
    c.hline(x0, x0 + 12, top, CHROME_DK)
    c.line(x0 + 3, top + 50, x0 + 9, top + 20, hexc('dde6e6'))


def build():
    c = Canvas(seed=41)
    wall(c)
    decay(c)
    floor(c)
    cabinet(c)
    sink(c)
    toilet(c)
    shower(c)
    bath(c)
    laundry(c)
    return c


if __name__ == '__main__':
    out = os.path.join(ROOT, 'assets', 'rooms', 'bathroom.png')
    prev_dir = os.path.join(ROOT, 'docs', 'art_reference', 'modules')
    c = build()
    bare = Canvas(seed=41)
    wall(bare)
    decay(bare)
    bad = check_window_boxes(c.img, bare.img)
    if bad:
        sys.exit('furniture inside a runtime window box: %s' % bad[:8])
    edge = check_edge_columns(c.img, bare.img)
    if edge:
        sys.exit('furniture in the edge columns the side walls are painted from: %s' % edge[:8])
    fl = save_floor_strip(floor, 'bathroom', ROOT, seed=41)
    if not floor_is_periodic(fl):
        sys.exit('the floor must repeat every 32px (it tiles on past the module edge at a doorway)')
    c.save(out, os.path.join(prev_dir, 'bathroom_x4.png'))
    print('wrote', out, '(window boxes clear)')
