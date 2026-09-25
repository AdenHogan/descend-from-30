"""Living room STYLE variants (mockups for the owner to compare) — same module geometry and rules as
tools/art/living_room.py (variant A): the walking lane stays clear, both runtime window boxes stay
bare wall, and each room has a SET-BACK piece on the left and the right (future scavenge spots on
an upper plane). Turned seating (armchairs, B/C's sofas and TVs) is built in 3D by chair3d.py.

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


def sofa_as(c, pal, dx=3, dy=-10):
    """The owner-approved sofa shape in another fabric (monkeypatching variant A's palette)."""
    keep = (lr.SOFA, lr.SOFA_DK, lr.SOFA_LT, lr.SOFA_OUT)
    lr.SOFA, lr.SOFA_DK, lr.SOFA_LT, lr.SOFA_OUT = pal
    lr.shifted(c, lr.sofa, dy, dx)
    lr.SOFA, lr.SOFA_DK, lr.SOFA_LT, lr.SOFA_OUT = keep


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
    # WATCHING THE TELLY (owner round 13 — "if a room has a TV the furniture should be facing it"):
    # the console TV stands turned in the left corner, the armchair and the sofa are turned toward it
    # across the kidney table — all built in 3D (chair3d) so the angles hold together.
    def rug(cc):
        cc.ellipse(166, 121, 92, 13, hexc('8d6a2c'))
        cc.ellipse(166, 121, 89, 11, hexc('b58a3a'))
        cc.dither(80, 110, 252, 132, hexc('a47c33'), 0.25, 'random')
    rug(c)
    # RIGHT set-back: a teak shelving unit — records below, ornaments above (right of the R window box)
    def shelf(c):
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
        c.poly([(38, 43), (44, 43), (43, 38), (39, 38)], hexc('d9cfb8'))   # a little potted plant on top
        for (lx, ly) in ((37, 33), (41, 30), (45, 34)):
            c.line(41, 38, lx, ly, hexc('4d6a3c'))
    lr.shifted(c, shelf, 0, 260)
    # the TV, turned in the corner toward the seats
    tv = C3.draw_model(c, 34, 104, C3.console_tv(), -40,
                       {'wood': hexc('7c5a3b'), 'metal': hexc('2a2a2c'), 'screen': hexc('2c3431'),
                        'grille': hexc('6b4a31')}, outline=hexc('3f2a1b'), srad=17)
    C3.screen_detail(c, 34, 104, *tv, cracked=True, grille=hexc('4a3020'))
    def _table(c):
        # a kidney coffee table on hairpin legs
        c.shadow(214, 117, 26, 2, 100)
        c.ellipse(214, 101, 24, 4, hexc('8a6443'))
        c.ellipse(214, 100, 23, 3, hexc('9e7550'))
        for lx in (196, 232):
            c.line(lx, 104, lx - 2, 116, hexc('2a2a2c'))
        c.rect(206, 95, 210, 99, hexc('d9cfb8'))
        c.ellipse(222, 99, 4, 1, hexc('c8783b'))
    lr.shifted(c, _table, 0, -56)
    # the rust sofa, turned toward the TV
    C3.draw_model(c, 226, 121, C3.sofa_model(), 35,
                  {'fab': hexc('a4532e'), 'fab_lt': hexc('bd6a41'), 'wood': hexc('2e1e14')}, srad=36)


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
    def guitar(c):
        # a guitar leaning against the wall beside the crates, a string snapped
        c.ellipse(306, 102, 5, 7, hexc('a86a3a'))
        c.ellipse(306, 94, 4, 5, hexc('a86a3a'))
        c.ellipse(306, 100, 2, 2, hexc('2a1c14'))
        c.rect(305, 70, 307, 89, hexc('4a3020'))
        c.rect(304, 66, 308, 70, hexc('2a1c14'))
        c.line(305, 71, 300, 84, hexc('d9d0bc'))
    lr.shifted(c, guitar, 1, -246)
    # WATCHING THE TELLY (owner round 13): the slumped grey sofa turned toward the CRT, which sits
    # on two crates in the right corner turned back toward it, the pallet table between them.
    C3.draw_model(c, 146, 121, C3.sofa_model(), -35,
                  {'fab': hexc('7a7b7e'), 'fab_lt': hexc('939497'), 'wood': hexc('2c2d2f')}, srad=36)
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
    lr.shifted(c, _pallet, 0, -2)
    tv = C3.draw_model(c, 286, 104, C3.crt_on_crates(), 40,
                       {'crate': hexc('a8453a'), 'crate2': hexc('2f4f7a'), 'tv': hexc('4a4a4d'),
                        'screen': hexc('23302c')}, outline=hexc('1c1c1e'), srad=16)
    C3.screen_detail(c, 286, 104, *tv)


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


def d_floor(c):
    lr.floor(c)


def d_furniture(c):
    # EVEN SPACING (owner round 13b): piano | armchair turned to the sofa | tea table | sofa | china
    # cabinet — one piece every ~50px, the group sitting on the carpet in the middle.
    # an ornate green carpet with a gold border
    top, bot = 106, 130
    c.poly([(74, top), (246, top), (258, bot), (62, bot)], hexc('b58f4a'))
    c.poly([(78, top + 2), (242, top + 2), (253, bot - 2), (67, bot - 2)], hexc('3f5a45'))
    for cx_ in (104, 160, 216):
        c.ellipse(cx_, 118, 12, 4, hexc('5a7a5e'))
        c.ellipse(cx_, 118, 5, 2, hexc('a0505a'))
    for x in range(63, 258, 2):
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
    sofa_as(c, (hexc('c8b89a'), hexc('a99a7c'), hexc('d9cbb0'), hexc('5e5040')), dx=66)
    rng = c.rng
    for _ in range(40):                                                     # the chintz print
        x = rng.randrange(155, 238)
        y = rng.randrange(82, 110)
        if c.px[x, y][:3] in ((0xc8, 0xb8, 0x9a), (0xd9, 0xcb, 0xb0)):
            c.put(x, y, hexc('a0505a'))
            c.put(x + 1, y, hexc('6f7d58'))
    def _tea(c):
        # a small mahogany tea table: a doily, a teapot, a toppled cup
        c.shadow(214, 117, 18, 2, 100)
        c.ellipse(214, 101, 16, 4, hexc('3a2019'))
        c.ellipse(214, 100, 15, 3, hexc('5a352b'))
        c.ellipse(214, 99, 9, 2, hexc('e6ddc8'))
        for lx in (203, 225):
            c.rect(lx, 104, lx + 1, 116, hexc('2a1712'))
            c.put(lx - 1, 116, hexc('2a1712'))
        c.ellipse(210, 95, 4, 3, hexc('e6ddc8'))
        c.rect(214, 94, 216, 95, hexc('e6ddc8'))
        c.ellipse(222, 99, 2, 1, hexc('e6ddc8'))
        c.put(224, 100, hexc('7a4a2a'))
    lr.shifted(c, _tea, 0, -90)
    # RIGHT set-back: a glass-front china cabinet
    c.shadow(280, 101, 20, 2, 90)
    x0, x1, top = 262, 298, 67
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
    # a stone fireplace against the wall, SYMMETRIC about x 128 (owner round 13): hearth, stone
    # surround laid in courses mirrored about the centre, an arched firebox with the grate and its
    # charred logs centred, a candlestick at each end of the mantel, the antlers above the middle.
    # The poker stand stands on the hearth to the right, a log basket to the left (the old game bag
    # slumped on the floor went — owner: "strange items just on the floor").
    # EVEN SPACING (owner round 13b): gun cabinet | armchair turned to the fire | the fireplace in the
    # MIDDLE under the antlers | sofa — the room's pieces spread across it, not piled on the right.
    FX = 160
    STONE, STONE_HI, MORTAR = hexc('8a8478'), hexc('a09a8c'), hexc('5e584e')
    c.shadow(FX, 101, 32, 2, 100)
    c.rect(FX - 30, 97, FX + 30, 100, hexc('7a7468'))                          # the hearth slab
    c.hline(FX - 30, FX + 30, 97, hexc('948e82'))
    c.rect(FX - 24, 57, FX + 24, 96, MORTAR)                                   # the surround
    for k, y in enumerate(range(57, 96, 5)):
        offs = range(-24, 25, 10) if k % 2 == 0 else range(-29, 25, 10)
        for ox in offs:
            x0, x1 = max(FX + ox, FX - 24), min(FX + ox + 8, FX + 24)
            if x1 >= x0:
                c.rect(x0, y, x1, y + 3, STONE)
                c.hline(x0, x1, y, STONE_HI)
    for y in range(57, 97):                                                    # mirror = exact symmetry
        for dx in range(1, 25):
            c.put(FX + dx, y, c.px[FX - dx, y])
    c.rect(FX - 28, 52, FX + 28, 56, hexc('6b4a31'))                           # the mantel
    c.hline(FX - 28, FX + 28, 52, hexc('8a6443'))
    c.hline(FX - 28, FX + 28, 56, hexc('4a3020'))
    c.rect(FX - 12, 70, FX + 12, 96, hexc('1e1a16'))                           # the firebox
    for i in range(4):                                                         # the arch, pixel-mirrored
        c.hline(FX - 9 - i, FX + 9 + i, 66 + i, hexc('1e1a16'))
        c.put(FX - 10 - i, 66 + i, hexc('6a645a'))
        c.put(FX + 10 + i, 66 + i, hexc('6a645a'))
    c.hline(FX - 9, FX + 9, 65, hexc('6a645a'))
    c.dither(FX - 10, 93, FX + 10, 96, hexc('8a8278'), 0.5)                    # ash
    for (lx0, lx1, ly) in ((FX - 8, FX - 1, 87), (FX + 1, FX + 8, 87), (FX - 4, FX + 4, 84)):   # charred logs
        c.rect(lx0, ly, lx1, ly + 2, hexc('2e2620'))
        c.hline(lx0, lx1, ly, hexc('4a3e34'))
        c.put(lx0, ly + 1, hexc('6a5a4a'))
        c.put(lx1, ly + 1, hexc('6a5a4a'))
    c.rect(FX - 10, 90, FX + 10, 92, hexc('3a3a36'))                           # the grate
    for x in range(FX - 8, FX + 9, 4):
        c.vline(x, 86, 90, hexc('3a3a36'))
    for dx in (-22, 22):                                                       # candlesticks
        c.rect(FX + dx - 1, 49, FX + dx + 1, 51, hexc('b58f4a'))
        c.vline(FX + dx, 44, 48, hexc('e6ddc8'))
    # the poker stand on the hearth, right
    c.vline(FX + 34, 72, 99, hexc('3a3a36')); c.hline(FX + 31, FX + 37, 99, hexc('3a3a36'))
    c.hline(FX + 31, FX + 37, 74, hexc('3a3a36'))
    for tx in (FX + 32, FX + 36):
        c.vline(tx, 75, 92, hexc('4a4a44'))
    # a log basket on the hearth, left (a set-back scavenge spot)
    bx0, bx1 = FX - 48, FX - 33
    c.shadow((bx0 + bx1) // 2, 100, 10, 2, 100)
    for (lx, ly, ln) in ((bx0 + 2, 83, 11), (bx0 + 4, 81, 9), (bx0 + 1, 85, 12)):     # logs poking out
        c.rect(lx, ly, lx + ln, ly + 2, hexc('6b4a31'))
        c.hline(lx, lx + ln, ly, hexc('8a6443'))
        c.rect(lx + ln, ly, lx + ln, ly + 2, hexc('b58f6a'))
    c.box(bx0, 86, bx1, 99, hexc('8a6a3a'), hexc('4a3a1e'))
    for y in range(88, 98, 2):                                                 # wicker weave
        for x in range(bx0 + 1 + (y // 2) % 2, bx1, 2):
            c.put(x, y, hexc('a6844a'))
    # a chesterfield in oxblood leather, and a bear-skin rug before it
    sofa_as(c, (hexc('6e2a24'), hexc('55201c'), hexc('84403a'), hexc('2a100e')), dx=128)
    bear, bear_dk = hexc('9a7450'), hexc('6a4a34')
    c.poly([(118, 126), (128, 120), (132, 116), (140, 120), (170, 119), (178, 115), (184, 120), (196, 124),
            (184, 128), (178, 132), (170, 128), (140, 129), (132, 133), (128, 129)], bear)   # the pelt, legs out
    c.poly([(196, 124), (206, 120), (212, 123), (208, 128)], bear)                              # the head
    c.put(206, 122, hexc('1e1a16')); c.put(211, 124, hexc('d9cfb8'))
    c.line(140, 124, 170, 124, bear_dk)


E_ANCHORS = [('anchor_living_gun_cabinet', 26, 56, 'bp'), ('anchor_living_fireplace', 160, 90, 'bp'),
             ('anchor_living_log_basket', 120, 92, 'bp'), ('anchor_centre_sofaleft', 239, 103, ''),
             ('anchor_centre_sofaright', 274, 101, ''), ('anchor_living_armchair', 78, 104, '')]


# Turned armchairs (tools/art/chair3d.py — built in 3D so the angle is right), each grouped with
# what it's for: B watches the TV, D sits at the rug's end facing the sofa, E is the reading chair
# by the lamp, turned toward the fire. (C, the bare student flat, has none.)
import chair3d as C3


def b_chair(c):
    C3.armchair(c, 104, 118, 70, {'fab': hexc('a8843a'), 'fab_lt': hexc('b8944a'), 'wood': hexc('3a2618')},
                style='club', plan={3: 'tipped'}, key='living_b')              # mustard, facing the telly


def d_chair(c):
    C3.armchair(c, 82, 118, -35, {'fab': hexc('6a7a5a'), 'fab_lt': hexc('7a8a68'), 'wood': hexc('4a2e1e')},
                style='wing', plan={2: 'side', 3: 'side'}, key='living_d')      # sage tall-back, at the rug's end


def e_chair(c):
    C3.armchair(c, 78, 118, -40, {'fab': hexc('8a5a34'), 'fab_lt': hexc('9a6a40'), 'wood': hexc('2e1e14')},
                style='wing', plan={2: 'blood', 3: 'blood'}, key='living_e')    # tan leather, turned to the fire


def _with(furniture, chair):
    def f(c):
        furniture(c)
        chair(c)
    return f


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


B_ANCHORS = [('anchor_living_records', 290, 86, 'bp'), ('anchor_living_teak_shelf', 298, 72, 'bp'),
             ('anchor_living_console_tv', 34, 86, 'bp'), ('anchor_living_kidney_table', 158, 100, ''),
             ('anchor_centre_sofaleft', 212, 106, ''), ('anchor_centre_sofaright', 240, 100, ''),
             ('anchor_living_armchair', 104, 104, '')]
C_ANCHORS = [('anchor_living_crates', 22, 68, 'bp'), ('anchor_living_crate_books', 36, 92, 'bp'),
             ('anchor_living_pallet_table', 203, 101, ''), ('anchor_centre_sofaleft', 132, 106, ''),
             ('anchor_centre_sofaright', 160, 100, ''), ('anchor_living_crt', 286, 84, 'bp')]
D_ANCHORS = [('anchor_living_piano', 26, 74, 'bp'), ('anchor_living_tea_table', 124, 99, ''),
             ('anchor_centre_sofaleft', 177, 103, ''), ('anchor_centre_sofaright', 212, 101, ''),
             ('anchor_living_china_cabinet', 280, 76, 'bp'), ('anchor_living_cabinet_cupboard', 274, 90, 'bp'),
             ('anchor_living_armchair', 82, 104, '')]

VARIANTS = {
    'b': ('living_room_b', 21, (b_wall, b_decor, b_floor, _with(b_furniture, b_chair)), B_ANCHORS),
    'c': ('living_room_c', 33, (c_wall, c_decor, c_floor, c_furniture), C_ANCHORS),
    'd': ('living_room_d', 44, (d_wall, d_decor, d_floor, _with(d_furniture, d_chair)), D_ANCHORS),
    'e': ('living_room_e', 45, (e_wall, e_decor, e_floor, _with(e_furniture, e_chair)), E_ANCHORS),
}


if __name__ == '__main__':
    for v in (sys.argv[1:] or sorted(VARIANTS)):
        name, seed, fns, anchors = VARIANTS[v]
        bare, floor, build = _variant(*fns, seed)
        finish_module(name, 'living_room', seed, bare, floor, build, anchors,
                      per_run=lambda r: setattr(C3, 'RUN', r))
