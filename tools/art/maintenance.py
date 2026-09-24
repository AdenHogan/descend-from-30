"""Maintenance room art (scenes/maintenance.tscn, every 3rd floor) — one 416 x 176 painted overlay
over its placeholder tiles: a cross-section frame, a blockwork back wall with pipes, a pegboard over
a proper WORKBENCH (the scrap upgrade station), a FUSE BOX with its door hanging open (the three
fuse-slot lights are still drawn live on top by room.gd — they show 0-3 fitted), a wired-glass
window, and a crate + a tool chest under the two loot nodes.

Run:  python3 tools/art/maintenance.py
Out:  assets/rooms/maintenance.png, docs/art_reference/modules/maintenance_x4.png

Local (0,0) = world (97,208) — the tilemap's used rect. Geometry (local):
  frame: slab y 0..15, floor edge y 160..175, right end x 400..415, left end x 0..15 with the
  doorway hole y 48..143; back wall y 16..143; floor strip y 144..159 (feet on world 352 = 144).
  window x 288..351, y 32..111; workbench centre x 93 (world 190), top 110; fuse box
  x 197..233, y 58..106 (world 312,290); slot lights x 200..230, y 71..97; loot nodes at
  (311,132) + (365,132).
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, rrect

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
MW, MH = 416, 176
SLAB = hexc('4a4844')
SLAB_DK = hexc('34322e')
SLAB_LT = hexc('5e5b56')
PAINT = hexc('7a8a7a')
PAINT_DK = hexc('5e6e60')
MORTAR = hexc('6a7a6a')
PIPE = hexc('8a8a82')
PIPE_DK = hexc('5a5a54')
PIPE_LT = hexc('a8a8a0')
WOOD = hexc('7a5438')
WOOD_DK = hexc('5a3a26')
WOOD_LT = hexc('94694a')
STEEL = hexc('6a7074')
STEEL_DK = hexc('4a5054')
STEEL_LT = hexc('8a9094')
RED = hexc('a8322c')
YEL = hexc('d9b43a')
OIL = hexc('2a2622', 120)


def frame(c):
    c.rect(0, 0, MW - 1, 15, SLAB)
    c.hline(0, MW - 1, 15, SLAB_DK)
    c.dither(0, 0, MW - 1, 12, SLAB_LT, 0.12, pattern='random')
    c.rect(0, 160, MW - 1, MH - 1, SLAB)
    c.hline(0, MW - 1, 160, SLAB_LT)
    c.dither(0, 162, MW - 1, MH - 1, SLAB_DK, 0.2, pattern='random')
    c.rect(400, 0, MW - 1, MH - 1, SLAB)
    c.vline(400, 16, 159, SLAB_DK)
    c.rect(0, 0, 15, MH - 1, SLAB)
    c.vline(15, 16, 47, SLAB_DK); c.vline(15, 144, 159, SLAB_DK)
    # the doorway through the left end: dark beyond, a steel frame on the room side
    c.rect(0, 48, 15, 143, hexc('141210'))
    c.dither(0, 48, 15, 60, hexc('24201c'), 0.5)
    c.rect(14, 44, 19, 143, STEEL)
    c.rect(0, 44, 19, 47, STEEL)
    c.vline(19, 44, 143, STEEL_DK)
    c.hline(0, 19, 47, STEEL_DK)


def wall(c):
    c.rect(16, 16, 399, 143, PAINT)
    for y in range(16, 144, 8):                                    # painted blockwork
        c.hline(16, 399, y, MORTAR)
        off = 8 if (y // 8) % 2 else 0
        for x in range(16 + off, 400, 16):
            c.vline(x, y, y + 7, MORTAR)
    c.rect(16, 100, 399, 143, PAINT_DK)                            # darker paint below
    c.hline(16, 399, 100, shade(PAINT_DK, 0.8))
    for y in range(100, 144, 8):
        c.hline(16, 399, y, shade(PAINT_DK, 0.88))
    for x in range(16, 400, 8):                                    # hazard stripe at the base
        for y in range(138, 144):
            c.put(x + ((y - 138) % 8), y, YEL if ((x // 8) % 2) else hexc('26262a'))
    c.rect(16, 138, 399, 138, hexc('26262a'))
    # damp + rust stains
    c.dither(360, 16, 399, 40, hexc('4a5a4a', 90), 0.4, pattern='random')
    c.line(262, 30, 263, 100, hexc('8a5a3a', 120))


def pipes(c):
    for (y, h) in ((19, 3), (25, 2)):
        c.rect(16, y, 399, y + h, PIPE)
        c.hline(16, 399, y, PIPE_LT)
        c.hline(16, 399, y + h, PIPE_DK)
    for x in range(40, 400, 64):
        c.rect(x, 18, x + 3, 29, PIPE_DK)                          # brackets
    c.rect(258, 29, 261, 143, PIPE)                                 # a riser down into the floor
    c.vline(258, 29, 143, PIPE_LT); c.vline(261, 29, 143, PIPE_DK)
    c.ellipse(260, 62, 6, 6, RED)                                   # a valve wheel
    c.ellipse(260, 62, 4, 4, shade(RED, 0.6))
    for (dx, dy) in ((0, -5), (5, 0), (0, 5), (-5, 0)):
        c.line(260, 62, 260 + dx, 62 + dy, RED)
    c.rect(214, 29, 216, 57, STEEL_DK)                              # conduit down to the fuse box


def pegboard(c):
    c.box(50, 38, 136, 86, hexc('9a7a52'), hexc('5a4028'))
    for y in range(42, 84, 4):
        for x in range(54, 134, 4):
            c.put(x, y, hexc('6a5234'))
    # tools hung up — and one painted outline with nothing in it (something's been taken)
    c.rect(58, 46, 60, 66, WOOD); c.rect(55, 44, 63, 47, STEEL)                      # hammer
    c.poly([(70, 46), (84, 46), (84, 50), (74, 70), (70, 70)], STEEL_LT)             # saw
    c.rect(70, 70, 74, 76, WOOD)
    c.rect(92, 46, 94, 70, STEEL); c.rect(90, 44, 96, 47, STEEL)                      # wrench
    for (x0, y0, x1, y1) in ((104, 46, 106, 72),):                                    # the missing one: an outline
        c.rect(x0 - 3, y0 - 2, x1 + 3, y0 + 2, hexc('e6e0cc'))
        c.rect(x0 - 2, y0 - 1, x1 + 2, y0 + 1, hexc('9a7a52'))
        c.vline(x0 - 1, y0 + 2, y1, hexc('e6e0cc')); c.vline(x1 + 1, y0 + 2, y1, hexc('e6e0cc'))
        c.hline(x0 - 1, x1 + 1, y1, hexc('e6e0cc'))
    c.rect(116, 46, 118, 64, hexc('c0453a')); c.rect(116, 64, 118, 72, STEEL_LT)      # screwdrivers
    c.rect(124, 46, 126, 62, hexc('3a6a9a')); c.rect(124, 62, 126, 70, STEEL_LT)


def workbench(c):
    x0, x1, top, base = 49, 137, 110, 144
    c.shadow(93, base, 46, 2, 110)
    c.rect(x0, top, x1, top + 4, WOOD_LT)                           # a thick scarred top
    c.hline(x0, x1, top, shade(WOOD_LT, 1.12))
    c.hline(x0, x1, top + 4, WOOD_DK)
    for x in (60, 84, 101, 122):
        c.line(x, top + 1, x + 5, top + 3, WOOD_DK)
    for lx in (x0 + 2, x1 - 5):                                     # legs
        c.rect(lx, top + 5, lx + 3, base, WOOD)
        c.vline(lx + 3, top + 5, base, WOOD_DK)
    c.rect(x0 + 2, 132, x1 - 2, 134, WOOD)                          # the lower shelf
    c.hline(x0 + 2, x1 - 2, 134, WOOD_DK)
    c.box(62, 122, 82, 131, RED, shade(RED, 0.55))                  # a toolbox on it
    c.rect(68, 119, 76, 121, shade(RED, 0.6))
    c.rect(96, 126, 110, 131, hexc('9a7a4e'))                       # a crate of scrap
    for (x, col) in ((98, STEEL_LT), (102, hexc('8a5a3a')), (106, STEEL)):
        c.rect(x, 122, x + 2, 126, col)
    # the vice at the right end, a lamp clamped at the left, bits on the top
    c.rect(122, 102, 134, 109, STEEL)
    c.hline(122, 134, 102, STEEL_LT)
    c.rect(126, 98, 130, 102, STEEL_DK)
    c.line(130, 105, 138, 105, STEEL_LT)
    c.line(54, 109, 56, 92, STEEL_DK); c.line(56, 92, 66, 88, STEEL_DK)
    c.poly([(62, 86), (72, 88), (70, 94), (62, 92)], hexc('3a6a4a'))
    for (x, col) in ((80, STEEL_LT), (86, hexc('b58f4a')), (92, STEEL), (106, hexc('c0453a'))):
        c.rect(x, 107, x + 3, 109, col)
    c.ellipse(100, 108, 3, 1, OIL)


def fuse_box(c):
    x0, x1, y0, y1 = 197, 233, 58, 106
    c.shadow(215, 110, 20, 2, 70)
    c.box(x0, y0, x1, y1, STEEL, STEEL_DK)
    c.hline(x0 + 1, x1 - 1, y0 + 1, STEEL_LT)
    c.rect(x0 + 2, y0 + 10, x1 - 2, y1 - 6, hexc('26282a'))          # the panel behind the slot lights
    for sx in (200, 211, 222):                                      # slot sockets (room.gd lights them)
        c.rect(sx - 1, 70, sx + 9, 98, hexc('3a3c3e'))
    c.rect(x0 + 4, y0 + 3, x0 + 16, y0 + 7, YEL)                    # a warning label
    c.poly([(x0 + 6, y0 + 7), (x0 + 10, y0 + 3), (x0 + 14, y0 + 7)], hexc('26262a'))
    c.rect(x1 - 10, y0 + 3, x1 - 4, y0 + 7, hexc('e6e0cc'))
    c.poly([(x1, y0 + 2), (x1 + 10, y0 + 6), (x1 + 10, y1 - 6), (x1, y1 - 2)], STEEL)   # the door, swung open
    c.line(x1, y0 + 2, x1 + 10, y0 + 6, STEEL_LT)
    c.line(x1 + 3, y0 + 14, x1 + 7, y0 + 18, STEEL_DK)
    c.rect(x1 + 4, (y0 + y1) // 2 - 2, x1 + 6, (y0 + y1) // 2 + 2, STEEL_DK)


def window(c):
    x0, y0, x1, y1 = 288, 32, 351, 111
    c.rect(x0, y0, x1, y1, STEEL_DK)
    c.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, hexc('7a8a96'))           # wired glass, frosted
    c.dither(x0 + 3, y0 + 3, x1 - 3, y1 - 3, hexc('8e9ea8'), 0.5)
    for k in range(-80, 80, 6):                                     # the wire mesh
        for t in range(0, 80):
            for (xx, yy) in ((x0 + 3 + t, y0 + 3 + t + k), (x0 + 3 + t, y1 - 3 - t + k)):
                if x0 + 3 <= xx <= x1 - 3 and y0 + 3 <= yy <= y1 - 3 and (t % 2 == 0):
                    c.put(xx, yy, hexc('5a6a74'))
    c.rect(x0, (y0 + y1) // 2 - 1, x1, (y0 + y1) // 2 + 1, STEEL_DK)  # a transom bar
    c.line(x0 + 30, y0 + 6, x0 + 40, y0 + 30, hexc('d0dcdc'))       # a crack
    c.line(x0 + 40, y0 + 30, x0 + 36, y0 + 36, hexc('d0dcdc'))
    c.rect(x0 - 2, y1, x1 + 2, y1 + 2, STEEL)                       # the sill


def floor(c):
    c.rect(16, 144, 399, 159, hexc('6a6a64'))
    c.hline(16, 399, 144, hexc('4a4a44'))
    for x in range(16, 400, 32):
        c.vline(x, 145, 159, hexc('5a5a54'))
    c.hline(16, 399, 152, hexc('62625c'))
    for (x, rx) in ((150, 8), (240, 5), (330, 10)):
        c.ellipse(x, 153, rx, 2, OIL)
    c.ellipse(262, 150, 5, 2, hexc('3a3a36'))                       # a floor drain
    for x in range(258, 267, 2):
        c.put(x, 150, hexc('1e1e1c'))


def loot_props(c):
    # a wooden crate (node a, 311,132) and a red tool chest (node b, 365,132)
    c.shadow(311, 144, 14, 2, 110)
    c.box(298, 122, 324, 143, hexc('9a7a4e'), hexc('5e4a2e'))
    for y in (128, 134, 140):
        c.hline(299, 323, y, hexc('7c6140'))
    c.line(299, 123, 323, 142, hexc('7c6140'))
    c.shadow(365, 144, 15, 2, 110)
    c.box(352, 110, 378, 143, RED, shade(RED, 0.5))
    for y in (116, 124, 132):
        c.box(354, y, 376, y + 6, RED, shade(RED, 0.6))
        c.rect(362, y + 3, 368, y + 3, STEEL_LT)
    c.poly([(354, 124), (376, 124), (378, 129), (352, 129)], shade(RED, 0.7))   # a drawer pulled out
    c.rect(356, 121, 374, 123, STEEL)
    c.rect(356, 106, 374, 109, shade(RED, 0.8))                      # the lid


def build():
    c = Canvas(w=MW, h=MH, seed=81)
    wall(c)
    pipes(c)
    window(c)
    pegboard(c)
    fuse_box(c)
    floor(c)
    workbench(c)
    loot_props(c)
    frame(c)
    return c


if __name__ == '__main__':
    c = build()
    holes = [(x, y) for y in range(MH) for x in range(MW) if c.img.getpixel((x, y))[3] != 255]
    if holes:
        sys.exit('transparent pixels %s' % holes[:5])
    out = os.path.join(ROOT, 'assets', 'rooms', 'maintenance.png')
    from PIL import Image
    c.img.save(out)
    c.img.resize((MW * 4, MH * 4), Image.NEAREST).save(os.path.join(ROOT, 'docs', 'art_reference', 'modules', 'maintenance_x4.png'))
    print('wrote', out)
