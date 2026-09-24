"""Living room STYLE variants (mockups for the owner to compare) — same module geometry and rules as
tools/art/living_room.py (variant A): the walking lane stays clear, both runtime window boxes stay
bare wall, and each room has a SET-BACK piece on the left and the right (future scavenge spots on
an upper plane). Front-facing furniture only (the angled armchair was dropped, owner round 9).

Run:  python3 tools/art/living_room_variants.py [b c d]
Out:  assets/rooms/living_room_{b,c,d}.png (+ _floor.png), scenes/Room_Modules/living_room_{b,c,d}.tscn
      (wired: room.MODULE_VARIANTS), previews + node overlays in docs/art_reference/modules/.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, mix, SEAM_Y, W, H, check_window_boxes, rrect, finish_module
import living_room as lr

ROOT = lr.ROOT


# --- shared bits -------------------------------------------------------------------------------

def plain_wall(c, base, trim, skirt, texture=None):
    """A painted wall (no wallpaper): flat paint with a faint plaster texture, a picture rail."""
    c.rect(0, 0, W - 1, 99, base)
    if texture is not None:
        c.dither(0, 6, W - 1, 93, texture, 0.07, 'random')
    c.rect(0, 0, W - 1, 3, shade(base, 0.8))
    c.hline(0, W - 1, 4, shade(base, 0.9))
    c.rect(0, 20, W - 1, 21, trim)                 # picture rail
    c.hline(0, W - 1, 20, shade(trim, 1.15))
    c.rect(0, 94, W - 1, 99, skirt)
    c.hline(0, W - 1, 94, shade(skirt, 1.2))
    c.hline(0, W - 1, SEAM_Y, lr.SEAM)


def parquet_floor(c, a, b, seam):
    """Brick-laid parquet, 16px blocks (two colours → the floor repeats every 32px), rows taller
    toward the viewer, alternate rows offset half a block."""
    rows = [100, 104, 108, 113, 119, 126, 134, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        off = (r % 2) * 8
        for k, x in enumerate(range(-off, W, 16)):
            col = a if (k + r) % 2 == 0 else b
            c.rect(max(x, 0), y0, min(x + 15, W - 1), y1, col)
            if x >= 0:
                c.vline(x, y0, y1, seam)
        c.hline(0, W - 1, y1, seam)
        c.hline(0, W - 1, y0, shade(a, 1.1))


def carpet_floor(c, base, fleck_lt, fleck_dk):
    """Cord carpet: flecks on a 32px-periodic hash (so it tiles at a doorway)."""
    c.rect(0, 100, W - 1, H - 1, base)
    for y in range(100, H):
        for x in range(W):
            k = (x * 7 + y * 13 + (y * y) % 5) % 32
            if k in (3, 11, 26):
                c.put(x, y, fleck_lt)
            elif k in (7, 19):
                c.put(x, y, fleck_dk)
    c.dither(0, 101, W - 1, 103, hexc('1f1d1c', 90), 0.5)


def sofa_as(c, pal, throw=None, dx=3, dy=-10):
    """The owner-approved sofa shape in another fabric (monkeypatching variant A's palette)."""
    keep = (lr.SOFA, lr.SOFA_DK, lr.SOFA_LT, lr.SOFA_OUT, lr.THROW, lr.THROW_DK)
    lr.SOFA, lr.SOFA_DK, lr.SOFA_LT, lr.SOFA_OUT = pal
    if throw:
        lr.THROW, lr.THROW_DK = throw
    lr.shifted(c, lr.sofa, dy, dx)
    lr.SOFA, lr.SOFA_DK, lr.SOFA_LT, lr.SOFA_OUT, lr.THROW, lr.THROW_DK = keep


def lamp_shade(c, x, shade_col, shade_dk, pole, top=56, base=112, cone=False):
    c.shadow(x, base + 1, 7, 2, 90)
    if cone:
        c.poly([(x - 3, top), (x + 3, top), (x + 8, top + 12), (x - 8, top + 12)], shade_col)
        c.hline(x - 8, x + 8, top + 12, shade_dk)
    else:
        c.poly([(x - 4, top), (x + 4, top), (x + 8, top + 12), (x - 8, top + 12)], shade_col)
        c.hline(x - 8, x + 8, top + 12, shade_dk)
    c.vline(x, top + 13, base - 1, pole)
    c.ellipse(x, base, 5, 1, pole)


def frame(c, x0, y0, x1, y1, fr, fr_dk, fill):
    c.box(x0, y0, x1, y1, fr, fr_dk)
    c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, fill)


# --- B: MID-CENTURY ----------------------------------------------------------------------------

def b_wall(c):
    TEAL = hexc('3f6663')
    plain_wall(c, TEAL, hexc('7a5537'), hexc('6b4a31'), hexc('466f6b'))
    # a water streak running down from the ceiling
    for y in range(4, 60):
        c.put(206 + (y // 11) % 2, y, hexc('35544f'))
    c.dither(203, 4, 211, 14, hexc('35544f'), 0.5)


def b_decor(c):
    # an abstract print above the sofa
    frame(c, 108, 30, 150, 56, hexc('d9cfb8'), hexc('8a826d'), hexc('d9cfb8'))
    c.rect(113, 35, 128, 51, hexc('c8783b'))
    c.ellipse(137, 42, 7, 7, hexc('d8a641'))
    c.rect(131, 46, 145, 51, hexc('3d5c63'))
    # a starburst clock
    for dx, dy in ((0, -9), (6, -6), (9, 0), (6, 6), (0, 9), (-6, 6), (-9, 0), (-6, -6)):
        c.line(190, 42, 190 + dx, 42 + dy, hexc('b58f4a'))
    c.ellipse(190, 42, 3, 3, hexc('d9c690'))
    c.put(190, 41, lr.OUT)


def b_floor(c):
    parquet_floor(c, hexc('8a6443'), hexc('7c5a3b'), hexc('5b3e28'))


def b_furniture(c):
    # an oval mustard rug
    def rug(cc):
        cc.ellipse(206, 121, 90, 13, hexc('8d6a2c'))
        cc.ellipse(206, 121, 87, 11, hexc('b58a3a'))
        cc.dither(122, 110, 290, 132, hexc('a47c33'), 0.25, 'random')
    rug(c)
    # LEFT set-back: a teak shelving unit — records below, ornaments above
    x0, x1, top = 12, 48, 44
    c.shadow(30, 101, 21, 3, 90)
    for sx in (x0, x1 - 2):
        c.rect(sx, top, sx + 2, 100, hexc('6b4a31'))
    for sy in (top, 60, 76, 92):
        c.rect(x0, sy, x1, sy + 1, hexc('8a6443'))
        c.hline(x0, x1, sy, hexc('9e7550'))
    for i, rx in enumerate(range(16, 45, 2)):                     # records, spines out
        c.vline(rx, 80, 91, [hexc('1f1f22'), hexc('a8453a'), hexc('2f3a55'), hexc('d8c79a')][i % 4])
    c.ellipse(22, 72, 3, 4, hexc('c8783b'))                        # a vase
    c.rect(32, 68, 42, 75, hexc('3d5c63'))                          # a boxed set
    c.rect(18, 53, 30, 59, hexc('b58a3a'))                          # books lying flat
    c.rect(34, 55, 44, 59, hexc('a8453a'))
    # the rust sofa
    sofa_as(c, (hexc('a4532e'), hexc('843f22'), hexc('bd6a41'), hexc('4a2412')), (hexc('d2c6a8'), hexc('b6aa8c')), dx=102)
    def _table(c):
        # a kidney coffee table on hairpin legs
        c.shadow(214, 117, 26, 2, 100)
        c.ellipse(214, 101, 24, 4, hexc('8a6443'))
        c.ellipse(214, 100, 23, 3, hexc('9e7550'))
        for lx in (196, 232):
            c.line(lx, 104, lx - 2, 116, hexc('2a2a2c'))
        c.rect(206, 95, 210, 99, hexc('d9cfb8'))
        c.ellipse(222, 99, 4, 1, hexc('c8783b'))
    lr.shifted(c, _table, 0, -58)
    def _tv(c):
        # RIGHT set-back: a wooden console TV (screen cracked)
        x0, x1, top = 258, 294, 70
        c.shadow(276, 101, 20, 2, 90)
        c.box(x0, top, x1, 97, hexc('7c5a3b'), hexc('3f2a1b'))
        c.hline(x0 + 1, x1 - 1, top + 1, hexc('9e7550'))
        c.box(x0 + 3, top + 4, x0 + 24, top + 20, hexc('2c3431'), hexc('1a1f1d'))
        c.rect(x0 + 5, top + 6, x0 + 9, top + 8, hexc('4b5a55'))
        c.line(x0 + 10, top + 7, x0 + 19, top + 17, hexc('7d8b86'))
        c.line(x0 + 14, top + 8, x0 + 12, top + 15, hexc('7d8b86'))
        for gy in range(top + 5, top + 21, 2):                          # speaker grille
            c.hline(x0 + 27, x1 - 3, gy, hexc('5b3e28'))
        for lx in (x0 + 3, x1 - 4):
            c.rect(lx, 98, lx + 1, 100, hexc('2a2a2c'))
        c.rect(x0 + 26, top - 6, x0 + 28, top - 1, hexc('b58f4a'))       # a brass lamp base on top
        c.poly([(x0 + 23, top - 12), (x0 + 31, top - 12), (x0 + 29, top - 6), (x0 + 25, top - 6)], hexc('d9c690'))
    lr.shifted(c, _tv, 0, -158)
    # a big rubber plant in the corner, some leaves browning (clear of the side-wall column x 316)
    c.shadow(302, 113, 8, 2, 80)
    c.poly([(296, 100), (308, 100), (306, 112), (298, 112)], hexc('d9cfb8'))
    for i, (lx, ly) in enumerate(((294, 70), (300, 62), (307, 72), (292, 84), (309, 86), (301, 80))):
        c.ellipse(lx, ly, 4, 6, hexc('4d6a3c') if i % 3 else hexc('7c6a38'))
        c.line(302, 99, lx, ly + 5, hexc('3e5530'))


def c_wall(c):
    plain_wall(c, hexc('9b978a'), hexc('8a867a'), hexc('6f6c63'), hexc('a6a293'))
    # damp: greenish-brown blooms creeping from the corners
    for (sx, sy, rx, ry) in ((10, 14, 22, 16), (300, 80, 26, 14), (160, 6, 30, 7)):
        c.ellipse(sx, sy, rx, ry, hexc('7c7a5e', 70))
        c.ellipse(sx, sy, rx - 5, ry - 4, hexc('6d6b50', 60))
    # cracks
    for (pts) in (((120, 4), (124, 12), (122, 20), (127, 30)), ((230, 88), (236, 80), (234, 72))):
        for a, b in zip(pts, pts[1:]):
            c.line(a[0], a[1], b[0], b[1], hexc('5e5b52'))
    # a fist-sized hole in the plaster
    c.ellipse(212, 58, 4, 3, hexc('3b3530'))
    c.ellipse(212, 58, 5, 4, hexc('b9b2a0', 90))


def c_decor(c):
    # posters, taped up — one torn half off
    c.rect(104, 26, 130, 60, hexc('2b2a33'))
    c.rect(108, 30, 126, 44, hexc('b8453a'))
    c.rect(108, 48, 126, 50, hexc('d9d0bc'))
    c.rect(108, 53, 120, 54, hexc('d9d0bc'))
    for tx, ty in ((104, 26), (130, 26), (104, 60), (130, 60)):
        c.put(tx, ty, hexc('d9d0bc'))
    c.poly([(140, 30), (160, 28), (161, 44), (150, 50), (140, 46)], hexc('c9b25a'))
    c.poly([(150, 50), (161, 44), (158, 58)], hexc('b7a04e'))             # the torn flap hanging


def c_floor(c):
    carpet_floor(c, hexc('59605f'), hexc('6b7271'), hexc('474d4c'))


def c_furniture(c):
    c.ellipse(120, 128, 10, 3, hexc('3f3a33', 120))                        # stains
    c.ellipse(236, 136, 7, 2, hexc('4a2520', 110))
    # LEFT set-back: milk crates stacked as shelving
    crates = [(12, 76, hexc('a8453a')), (31, 76, hexc('2f4f7a')), (12, 57, hexc('c9a03a')), (31, 57, hexc('a8453a'))]
    c.shadow(30, 101, 21, 3, 90)
    for (cx0, cy0, col) in crates:
        c.box(cx0, cy0, cx0 + 17, cy0 + 18 if cy0 == 57 else cy0 + 24, col, shade(col, 0.6))
        c.rect(cx0 + 2, cy0 + 2, cx0 + 15, (cy0 + 16 if cy0 == 57 else cy0 + 22), shade(col, 0.45))
        for gx in range(cx0 + 4, cx0 + 15, 4):
            c.vline(gx, cy0 + 2, cy0 + 5, col)
    for i, bx in enumerate(range(15, 44, 3)):
        if 29 <= bx <= 32:
            continue
        col = lr.BOOKS[i % len(lr.BOOKS)]
        c.rect(bx, 88, bx + 1, 98, col)
    c.rect(15, 66, 26, 73, hexc('1f1f22'))                                 # records
    # the couch: a slumped grey sofa with a sleeping bag
    sofa_as(c, (hexc('6d6e70'), hexc('555658'), hexc('848587'), hexc('2c2d2f')), (hexc('3f5f7a'), hexc('33506a')), dx=48)
    def _pallet(c):
        # a pallet table: pizza box, cans
        c.shadow(214, 117, 26, 2, 100)
        for py in (104, 110):
            c.rect(190, py, 238, py + 2, hexc('a58a5d'))
            c.hline(190, 238, py, hexc('b99c6b'))
        for lx in (191, 213, 236):
            c.rect(lx, 104, lx + 1, 116, hexc('8a7048'))
        c.box(196, 99, 214, 103, hexc('c9b58a'), hexc('8a7a55'))                # pizza box
        for cx_ in (220, 225, 229):
            c.rect(cx_, 98, cx_ + 2, 103, hexc('9aa3a8'))
            c.hline(cx_, cx_ + 2, 98, hexc('c9d0d4'))
        c.rect(241, 114, 244, 116, hexc('9aa3a8'))                              # a can on the floor
    lr.shifted(c, _pallet, 0, -128)
    # RIGHT set-back: a CRT TV on two crates, a console + cables
    c.shadow(276, 101, 20, 2, 90)
    c.box(260, 84, 290, 100, hexc('3a3a3d'), hexc('1c1c1e'))
    c.rect(262, 86, 288, 98, hexc('2a2a2c'))
    c.box(262, 67, 290, 83, hexc('4a4a4d'), hexc('1c1c1e'))              # top at 67: under the R window box
    c.box(265, 69, 285, 80, hexc('23302c'), hexc('111615'))
    c.rect(267, 71, 271, 72, hexc('3e524b'))
    c.rect(265, 88, 279, 91, hexc('5a5a5f'))                                 # a console
    c.line(280, 91, 296, 100, hexc('1c1c1e'))                               # cables
    c.line(284, 90, 300, 99, hexc('1c1c1e'))
    # a guitar leaning in the corner, a string snapped
    c.ellipse(306, 102, 5, 7, hexc('a86a3a'))
    c.ellipse(306, 94, 4, 5, hexc('a86a3a'))
    c.ellipse(306, 100, 2, 2, hexc('2a1c14'))
    c.rect(305, 70, 307, 89, hexc('4a3020'))
    c.rect(304, 66, 308, 70, hexc('2a1c14'))
    c.line(305, 71, 300, 84, hexc('d9d0bc'))



# --- D: GRANDMOTHER'S PARLOUR ------------------------------------------------------------------

ROSE = hexc('9a6d70')


def d_wall(c):
    c.rect(0, 0, W - 1, 71, ROSE)
    for y in range(8, 70, 10):                                             # rosebud sprigs
        off = 0 if (y // 10) % 2 == 0 else 6
        for x in range(off + 3, W, 12):
            c.put(x, y, hexc('b8878a'))
            c.put(x + 1, y, hexc('b8878a'))
            c.put(x, y + 1, hexc('c69a9c'))
            c.put(x - 1, y + 2, hexc('6f7d58'))
            c.put(x + 2, y + 2, hexc('6f7d58'))
    c.rect(0, 0, W - 1, 4, hexc('6e4a45'))
    c.hline(0, W - 1, 4, hexc('8a5f59'))
    # dark mahogany wainscot (reusing variant A's structure in other wood)
    keep = (lr.WAINS, lr.WAINS_LINE, lr.WAINS_HI, lr.RAIL, lr.RAIL_HI, lr.RAIL_LO, lr.SKIRT, lr.SKIRT_HI)
    lr.WAINS, lr.WAINS_LINE, lr.WAINS_HI = hexc('4a2a22'), hexc('361d17'), hexc('5a352b')
    lr.RAIL, lr.RAIL_HI, lr.RAIL_LO = hexc('5e3a2e'), hexc('74493a'), hexc('33201a')
    lr.SKIRT, lr.SKIRT_HI = hexc('33201a'), hexc('4a2e24')
    tmp = Canvas(seed=44)
    lr.wall(tmp)
    c.img.paste(tmp.img.crop((0, 70, W, 101)), (0, 70))
    c.px = c.img.load()
    lr.WAINS, lr.WAINS_LINE, lr.WAINS_HI, lr.RAIL, lr.RAIL_HI, lr.RAIL_LO, lr.SKIRT, lr.SKIRT_HI = keep


def d_decor(c):
    # oval portraits (one slashed)
    for (cx_, col) in ((122, hexc('7c6a5a')), (144, hexc('6a5a4c'))):
        c.ellipse(cx_, 38, 8, 11, hexc('b58f4a'))
        c.ellipse(cx_, 38, 6, 9, col)
        c.ellipse(cx_, 36, 3, 4, hexc('c8b39a'))
    c.line(141, 31, 148, 45, hexc('2a1c14'))
    # a strip of wallpaper peeling off the plaster (like variant A's), not a corner flag
    c.poly([(199, 30), (205, 30), (206, 46), (202, 50), (198, 44)], hexc('c0b39c'))
    c.vline(198, 31, 43, shade(hexc('c0b39c'), 0.8))
    c.poly([(205, 30), (209, 32), (211, 40), (208, 46), (206, 44)], shade(ROSE, 0.75))
    c.line(205, 30, 208, 46, shade(ROSE, 0.6))


def d_floor(c):
    lr.floor(c)


def d_furniture(c):
    # an ornate green carpet with a gold border
    top, bot = 106, 130
    c.poly([(80, top), (252, top), (264, bot), (68, bot)], hexc('b58f4a'))
    c.poly([(84, top + 2), (248, top + 2), (259, bot - 2), (73, bot - 2)], hexc('3f5a45'))
    for cx_ in (110, 166, 222):
        c.ellipse(cx_, 118, 12, 4, hexc('5a7a5e'))
        c.ellipse(cx_, 118, 5, 2, hexc('a0505a'))
    for x in range(69, 264, 2):
        c.vline(x, bot + 1, bot + 2, hexc('d9cfb8'))
    # LEFT set-back: an upright piano, photos and a metronome on top
    c.shadow(32, 101, 24, 3, 90)
    c.box(10, 67, 56, 99, hexc('3a2019'), hexc('1f110d'))
    c.hline(10, 56, 67, hexc('5a352b'))
    c.rect(13, 82, 53, 84, hexc('e6ddc8'))                                  # keys
    for kx in range(14, 53, 3):
        c.vline(kx, 82, 83, hexc('1f110d'))
    c.rect(13, 85, 53, 86, hexc('2a1712'))
    c.rect(20, 70, 32, 79, hexc('d9d0bc'))                                   # sheet music
    for sy in range(72, 79, 2):
        c.hline(22, 30, sy, hexc('8a826d'))
    for lx in (13, 51):
        c.rect(lx, 87, lx + 2, 99, hexc('2a1712'))
    c.box(14, 60, 20, 66, hexc('b58f4a'), hexc('7a5a2a'))                    # photo frames (x < 50)
    c.rect(16, 62, 18, 64, hexc('8c8272'))
    c.box(24, 58, 31, 66, hexc('b58f4a'), hexc('7a5a2a'))
    c.rect(26, 60, 29, 64, hexc('7c6a5a'))
    c.poly([(38, 66), (44, 66), (41, 57)], hexc('5a352b'))                  # metronome
    # the chintz sofa (cream with roses)
    sofa_as(c, (hexc('c8b89a'), hexc('a99a7c'), hexc('d9cbb0'), hexc('5e5040')), (hexc('a0505a'), hexc('7c3a42')), dx=40)
    rng = c.rng
    for _ in range(40):                                                     # the chintz print
        x = rng.randrange(129, 212)
        y = rng.randrange(82, 110)
        if c.px[x, y][:3] in ((0xc8, 0xb8, 0x9a), (0xd9, 0xcb, 0xb0)):
            c.put(x, y, hexc('a0505a'))
            c.put(x + 1, y, hexc('6f7d58'))
    def _tea(c):
        # a mahogany tea table: a doily, a teapot, a toppled cup
        c.shadow(214, 117, 24, 2, 100)
        c.ellipse(214, 101, 22, 4, hexc('3a2019'))
        c.ellipse(214, 100, 21, 3, hexc('5a352b'))
        c.ellipse(214, 99, 10, 2, hexc('e6ddc8'))
        for lx in (198, 230):
            c.rect(lx, 104, lx + 1, 116, hexc('2a1712'))
            c.put(lx - 1, 116, hexc('2a1712'))
        c.ellipse(210, 95, 4, 3, hexc('e6ddc8'))
        c.rect(214, 94, 216, 95, hexc('e6ddc8'))
        c.ellipse(222, 99, 2, 1, hexc('e6ddc8'))
        c.put(224, 100, hexc('7a4a2a'))
    lr.shifted(c, _tea, 0, -132)
    # RIGHT set-back: a glass-front china cabinet
    c.shadow(276, 101, 20, 2, 90)
    x0, x1, top = 258, 294, 67
    c.box(x0, top, x1, 99, hexc('3a2019'), hexc('1f110d'))
    c.box(x0 + 3, top + 3, x1 - 3, top + 20, hexc('9fb3b0'), hexc('2a1712'))
    c.vline((x0 + x1) // 2, top + 3, top + 20, hexc('2a1712'))
    for py in (top + 8, top + 15):                                          # plates on stands
        for px_ in range(x0 + 6, x1 - 4, 7):
            c.ellipse(px_, py, 2, 3, hexc('e6ddc8'))
            c.put(px_, py, hexc('7ea0b8'))
    c.rect(x0 + 3, top + 23, x1 - 3, 96, hexc('4a2a22'))                     # cupboard below
    c.vline((x0 + x1) // 2, top + 23, 96, hexc('1f110d'))
    c.put((x0 + x1) // 2 - 2, top + 28, hexc('b58f4a'))
    c.put((x0 + x1) // 2 + 2, top + 28, hexc('b58f4a'))
    c.line(x0 + 5, top + 5, x0 + 12, top + 17, hexc('d6e2e0'))              # a crack in the glass
    # a fringed standard lamp
    lamp_shade(c, 306, hexc('d6b78a'), hexc('a8864a'), hexc('3a2019'), top=58)
    for fx in range(298, 315, 2):
        c.vline(fx, 71, 73, hexc('a8864a'))





# --- E: HUNTING LODGE --------------------------------------------------------------------------

def e_wall(c):
    import furn as F
    F.wall_plain(c, hexc('3e4a36'), hexc('2e3628'), hexc('3a2618'), rail=hexc('6b4a31'), rail_y=58)
    c.rect(0, 60, W - 1, 93, hexc('6b4a31'))                                     # vertical boarding
    for x in range(0, W, 7):
        c.vline(x, 60, 93, hexc('5a3d28'))
        c.vline(x + 1, 60, 93, hexc('7a5638'))
    c.rect(0, 58, W - 1, 60, hexc('8a6443'))
    c.hline(0, W - 1, 58, hexc('9e7550'))
    for i in range(5):
        c.ellipse(212 + i * 6, 16 + (i % 2) * 3, 8, 5, hexc('2e3628', 70))


def e_decor(c):
    # antlers on a shield plaque, a hunting print
    cx = 162
    c.poly([(cx - 6, 34), (cx + 6, 34), (cx + 5, 46), (cx, 50), (cx - 5, 46)], hexc('6b4a31'))
    c.poly([(cx - 3, 36), (cx + 3, 36), (cx + 2, 42), (cx - 2, 42)], hexc('8a7a6a'))
    for d in (-1, 1):
        pts = [(cx + 3 * d, 36), (cx + 10 * d, 30), (cx + 16 * d, 22), (cx + 20 * d, 14)]
        for a, b in zip(pts, pts[1:]):
            c.line(a[0], a[1], b[0], b[1], hexc('d9cfb8'))
        c.line(cx + 10 * d, 30, cx + 14 * d, 34, hexc('d9cfb8'))
        c.line(cx + 16 * d, 22, cx + 22 * d, 24, hexc('d9cfb8'))
        c.line(cx + 16 * d, 22, cx + 14 * d, 14, hexc('d9cfb8'))
    frame(c, 196, 26, 220, 46, hexc('b58f4a'), hexc('7a6a4a'), hexc('6a7a5a'))
    c.poly([(200, 40), (206, 34), (212, 38), (216, 32), (216, 42), (200, 42)], hexc('4a5a3a'))


def e_floor(c):
    import furn as F
    F.floor_planks(c, [hexc('5e4230'), hexc('563c2a'), hexc('644734')], hexc('36261a'))


def e_furniture(c):
    import furn as F
    # a gun cabinet on the left (x < 50): glass door, rifle racks, one slot empty
    c.shadow(26, 101, 20, 2, 100)
    c.box(8, 22, 44, 99, hexc('4a2e1e'), hexc('24160e'))
    c.rect(11, 25, 41, 80, hexc('2a1d14'))
    for i, gx in enumerate((15, 22, 29, 36)):
        if i == 2:
            c.rect(gx - 1, 72, gx + 1, 78, hexc('5a3a26'))                      # the empty cradle
            continue
        c.rect(gx, 30, gx + 1, 76, hexc('3a3a36'))                             # barrel
        c.rect(gx - 1, 60, gx + 2, 78, hexc('7a4a2a'))                         # stock
    for y in range(25, 81):
        for x in range(11, 42):
            if (x + y) % 9 == 0:
                c.put(x, y, hexc('9ab0b0', 90))                                # glass sheen
    c.box(11, 83, 41, 96, hexc('4a2e1e'), hexc('24160e'))
    c.rect(24, 88, 28, 89, F.BRASS)
    # a stone fireplace against the wall: mantel, dead grate, poker set
    c.shadow(128, 101, 28, 2, 100)
    c.rect(102, 52, 154, 56, hexc('6b4a31'))                                   # the mantel
    c.hline(102, 154, 52, hexc('8a6443'))
    for y in range(57, 100, 5):
        off = 0 if (y // 5) % 2 == 0 else 5
        for x in range(104 + off, 153, 10):
            c.rect(x, y, x + 8, y + 3, hexc('8a8478'))
            c.hline(x, x + 8, y, hexc('a09a8c'))
    c.rect(114, 70, 142, 99, hexc('1e1a16'))                                   # the firebox
    c.poly([(114, 70), (142, 70), (138, 66), (118, 66)], hexc('6a645a'))
    c.rect(118, 92, 138, 94, hexc('3a3a36'))                                   # the grate
    for x in range(120, 137, 4):
        c.vline(x, 88, 92, hexc('3a3a36'))
    c.dither(118, 94, 138, 98, hexc('8a8278'), 0.5)                            # ash
    c.rect(120, 46, 126, 51, hexc('c9c2b1')); c.rect(130, 44, 134, 51, hexc('7a4a2a'))   # a clock + a decanter
    c.rect(146, 74, 147, 99, hexc('3a3a36')); c.hline(144, 149, 99, hexc('3a3a36'))       # poker stand
    # a game bag slumped on the floor by the lane
    c.shadow(92, 121, 10, 2, 110)
    c.poly([(82, 121), (84, 108), (94, 104), (102, 110), (102, 121)], hexc('6a6a4a'))
    c.line(86, 108, 98, 104, hexc('3a3a28'))
    c.rect(88, 112, 98, 116, hexc('5a5a3e'))
    # a chesterfield in oxblood leather, and a bear-skin rug before it
    sofa_as(c, (hexc('6e2a24'), hexc('55201c'), hexc('84403a'), hexc('2a100e')), (hexc('7a8a6a'), hexc('5a6a4a')), dx=92)
    bear, bear_dk = hexc('9a7450'), hexc('6a4a34')
    c.poly([(118, 126), (128, 120), (132, 116), (140, 120), (170, 119), (178, 115), (184, 120), (196, 124),
            (184, 128), (178, 132), (170, 128), (140, 129), (132, 133), (128, 129)], bear)   # the pelt, legs out
    c.poly([(196, 124), (206, 120), (212, 123), (208, 128)], bear)                              # the head
    c.put(206, 122, hexc('1e1a16')); c.put(211, 124, hexc('d9cfb8'))
    c.line(140, 124, 170, 124, bear_dk)
    F.floor_lamp(c, 300, 60, 114, hexc('c9ab7e'), hexc('3a2a1a'))


E_ANCHORS = [('anchor_living_gun_cabinet', 26, 56, 'bp'), ('anchor_living_fireplace', 128, 90, 'bp'),
             ('anchor_living_game_bag', 92, 112, ''), ('anchor_centre_sofaleft', 203, 103, ''),
             ('anchor_centre_sofaright', 238, 101, '')]


def _variant(wall, decor, floor, furniture, seed):
    def bare(c):
        wall(c)

    def build(c):
        wall(c)
        decor(c)
        floor(c)
        furniture(c)
        return c
    return bare, floor, build


B_ANCHORS = [('anchor_living_records', 30, 86, 'bp'), ('anchor_living_teak_shelf', 38, 72, 'bp'),
             ('anchor_living_console_tv', 118, 82, 'bp'), ('anchor_living_kidney_table', 156, 100, ''),
             ('anchor_centre_sofaleft', 213, 103, ''), ('anchor_centre_sofaright', 248, 101, '')]
C_ANCHORS = [('anchor_living_crates', 22, 68, 'bp'), ('anchor_living_crate_books', 36, 92, 'bp'),
             ('anchor_living_pallet_table', 77, 101, ''), ('anchor_centre_sofaleft', 159, 103, ''),
             ('anchor_centre_sofaright', 194, 101, ''), ('anchor_living_crt', 272, 90, 'bp')]
D_ANCHORS = [('anchor_living_piano', 26, 74, 'bp'), ('anchor_living_tea_table', 82, 99, ''),
             ('anchor_centre_sofaleft', 151, 103, ''), ('anchor_centre_sofaright', 186, 101, ''),
             ('anchor_living_china_cabinet', 276, 76, 'bp'), ('anchor_living_cabinet_cupboard', 270, 90, 'bp')]

VARIANTS = {
    'b': ('living_room_b', 21, (b_wall, b_decor, b_floor, b_furniture), B_ANCHORS),
    'c': ('living_room_c', 33, (c_wall, c_decor, c_floor, c_furniture), C_ANCHORS),
    'd': ('living_room_d', 44, (d_wall, d_decor, d_floor, d_furniture), D_ANCHORS),
    'e': ('living_room_e', 45, (e_wall, e_decor, e_floor, e_furniture), E_ANCHORS),
}


if __name__ == '__main__':
    for v in (sys.argv[1:] or sorted(VARIANTS)):
        name, seed, fns, anchors = VARIANTS[v]
        bare, floor, build = _variant(*fns, seed)
        finish_module(name, 'living_room', seed, bare, floor, build, anchors)
