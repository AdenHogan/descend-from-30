"""Living room STYLE variants (mockups for the owner to compare) — same module geometry and rules as
tools/art/living_room.py (variant A): the walking lane stays clear, both runtime window boxes stay
bare wall, and each room has a SET-BACK piece on the left and the right (future scavenge spots on
an upper plane). Turned armchairs are built in 3D by chair3d.py; sofas stay straight (B/C show
one from behind, facing the TV).

Run:  python3 tools/art/living_room_variants.py [b c d]
Out:  assets/rooms/living_room_{b,c,d}.png (+ _floor.png), scenes/Room_Modules/living_room_{b,c,d}.tscn
      (wired: room.MODULE_VARIANTS), previews + node overlays in docs/art_reference/modules/.
"""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, mix, SEAM_Y, W, H, check_window_boxes, rrect, finish_module, setback
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
    # a water stain spreading from the ceiling (a brown tide line, a couple of runs weeping down) —
    # it used to be a 1px streak that read as a cord hanging behind the print
    import math
    tide, stain = hexc('4a5a44'), hexc('466a5a')
    for y in range(4, 22):
        for x in range(186, 232):
            ang = math.atan2(y - 4, (x - 209) / 1.6)
            r = ((x - 209) ** 2 / 2.6 + (y - 4) ** 2) ** 0.5
            edge = 13 + 2.5 * math.sin(ang * 5 + 1.3) + 1.5 * math.sin(ang * 9)
            if r < edge - 1:
                c.put(x, y, stain if (x + y) % 3 else shade(stain, 0.96))
            elif r < edge + 0.6:
                c.put(x, y, tide)
    for (rx, ln) in ((200, 9), (216, 5)):
        for y in range(15, 15 + ln):
            c.put(rx, y, tide if y < 15 + ln - 1 else stain)


def b_decor(c):
    # an abstract print above the sofa
    frame(c, 176, 30, 218, 56, hexc('d9cfb8'), hexc('8a826d'), hexc('d9cfb8'))
    c.rect(181, 35, 196, 51, hexc('c8783b'))
    c.ellipse(205, 42, 7, 7, hexc('d8a641'))
    c.rect(199, 46, 213, 51, hexc('3d5c63'))
    # a starburst clock (between the left window and the TV)
    for dx, dy in ((0, -9), (6, -6), (9, 0), (6, 6), (0, 9), (-6, 6), (-9, 0), (-6, -6)):
        c.line(112, 42, 112 + dx, 42 + dy, hexc('b58f4a'))
    c.ellipse(112, 42, 3, 3, hexc('d9c690'))
    c.put(112, 41, lr.OUT)


def b_floor(c):
    parquet_floor(c, hexc('8a6443'), hexc('7c5a3b'), hexc('5b3e28'))


def sofa_back(c, cx, base, pal, wear=False):
    """The owner-approved sofa seen from BEHIND (round 13b — a TV room: the sofa faces the set on the
    back wall, full width, never turned): the same silhouette as the front view — a tall back panel
    between two lower arms — with piping along the top, the panel seams, a skirt and the back legs.
    `wear` adds a split with stuffing and a stain (the student flat)."""
    SOFA, SOFA_DK, SOFA_LT, SOFA_OUT = pal
    x0, x1, b = cx - 43, cx + 43, base
    c.shadow(cx, b + 1, 46, 3, 110)
    for lx in (x0 + 5, x1 - 6):                                         # the back legs
        c.rect(lx, b - 1, lx + 1, b, lr.OUT)
    # the back panel
    rrect(c, x0 + 6, b - 35, x1 - 6, b - 2, SOFA_OUT, 3)
    rrect(c, x0 + 7, b - 34, x1 - 7, b - 3, SOFA, 2)
    c.hline(x0 + 9, x1 - 9, b - 34, SOFA_LT)                            # the top, seen from a little above
    c.hline(x0 + 8, x1 - 8, b - 33, shade(SOFA_LT, 0.94))
    c.hline(x0 + 8, x1 - 8, b - 31, SOFA_DK)                            # piping
    for k in (1, 2):                                                    # panel seams
        sx = x0 + 6 + (x1 - x0 - 12) * k // 3
        c.vline(sx, b - 30, b - 10, shade(SOFA, 0.88))
    c.rect(x0 + 7, b - 9, x1 - 7, b - 3, SOFA_DK)                        # the skirt
    c.hline(x0 + 7, x1 - 7, b - 9, shade(SOFA_DK, 0.85))
    c.dither(x0 + 8, b - 29, x1 - 8, b - 11, shade(SOFA, 0.95), 0.12, 'random')
    # the arms, lower, at each end
    for ax0 in (x0, x1 - 9):
        rrect(c, ax0, b - 27, ax0 + 9, b - 2, SOFA_OUT, 2)
        rrect(c, ax0 + 1, b - 26, ax0 + 8, b - 3, SOFA, 1)
        c.hline(ax0 + 2, ax0 + 7, b - 26, SOFA_LT)
        c.rect(ax0 + 1, b - 9, ax0 + 8, b - 3, SOFA_DK)
    for lx in (x0 + 1, x1 - 3):                                         # the front legs, peeking under the arms
        c.rect(lx, b - 1, lx + 1, b, lr.OUT)
    if wear:
        c.line(cx + 10, b - 26, cx + 18, b - 21, SOFA_OUT)                # a split, stuffing showing
        for (px_, py_) in ((cx + 12, b - 25), (cx + 14, b - 24), (cx + 16, b - 22), (cx + 13, b - 23)):
            c.put(px_, py_, lr.STUFF)
        c.ellipse(cx - 18, b - 16, 5, 3, shade(SOFA, 0.8))                  # a stain


def b_furniture(c):
    # (No scavenge node on the TV: it stands BEHIND the sofa, so there's nowhere to step up to it —
    # pixlib.check_back_plane_clear.)
    # WATCHING THE TELLY FROM BEHIND (owner round 13b, picked from mockups): the TV sits centred
    # against the back wall on a teak sideboard, the rust sofa faces it with its BACK to us (straight,
    # full width), the armchair on the right turned toward the set; the kidney table on the left,
    # the shelving + rubber plant at the ends — evenly spaced.
    CX = 150
    c.ellipse(CX, 121, 88, 12, hexc('8d6a2c'))                           # an oval mustard rug
    c.ellipse(CX, 121, 85, 10, hexc('b58a3a'))
    c.dither(CX - 80, 111, CX + 80, 131, hexc('a47c33'), 0.25, 'random')
    # LEFT set-back: a teak shelving unit — records below, ornaments above (with depth: owner round
    # 14; 3px left of where it stood flat, so its side panel stays clear of window L)
    def _shelving(c):
        x0, x1, top = 12, 48, 44
        c.shadow(30, 101, 21, 3, 90)
        c.rect(x0 + 2, top + 2, x1 - 2, 99, hexc('3a2818'))                  # the unit's back board
        for sx in (x0, x1 - 2):
            c.rect(sx, top, sx + 2, 100, hexc('6b4a31'))
        for sy in (top, 60, 76, 92):
            c.rect(x0, sy, x1, sy + 1, hexc('8a6443'))
            c.hline(x0, x1, sy, hexc('9e7550'))
        for i, rx in enumerate(range(16, 45, 2)):                             # records, spines out
            c.vline(rx, 80, 91, [hexc('1f1f22'), hexc('a8453a'), hexc('2f3a55'), hexc('d8c79a')][i % 4])
        c.ellipse(22, 72, 3, 4, hexc('c8783b'))                                # a vase
        c.rect(32, 68, 42, 75, hexc('3d5c63'))                                  # a boxed set
        c.rect(18, 53, 30, 59, hexc('b58a3a'))                                  # books lying flat
        c.rect(34, 55, 44, 59, hexc('a8453a'))
    setback(c, lambda l: lr.shifted(l, _shelving, 0, -3), depth=4, top=44, x_range=(9, 45))
    # the sideboard + the wooden TV on it (screen cracked), rabbit ears — tall enough that the
    # sideboard's top shows over the sofa (else the set reads as perched on the sofa's back)
    TEAK, TEAK_DK, TEAK_LT = hexc('7c5a3b'), hexc('3f2a1b'), hexc('9e7550')

    def _sideboard(c):
        _sideboard_tv(c, CX, TEAK, TEAK_DK, TEAK_LT)
    setback(c, _sideboard, depth=6, top=72, x_range=(CX - 34, CX + 34))
    # the kidney coffee table on the left
    def _table(c):
        c.shadow(214, 117, 26, 2, 100)
        c.ellipse(214, 101, 24, 4, hexc('8a6443'))
        c.ellipse(214, 100, 23, 3, hexc('9e7550'))
        for lx in (196, 232):
            c.line(lx, 104, lx - 2, 116, hexc('2a2a2c'))
        c.rect(206, 95, 210, 99, hexc('d9cfb8'))
        c.ellipse(222, 99, 4, 1, hexc('c8783b'))
    lr.shifted(c, _table, 0, -140)
    # the rust sofa, its back to us, facing the set
    sofa_back(c, CX, 118, (hexc('a4532e'), hexc('843f22'), hexc('bd6a41'), hexc('4a2412')))
    # a big rubber plant in the corner, some leaves browning (clear of the side-wall column x 316)
    def plant(c):
        c.shadow(302, 113, 8, 2, 80)
        c.poly([(296, 100), (308, 100), (306, 112), (298, 112)], hexc('d9cfb8'))
        for i, (lx, ly) in enumerate(((294, 70), (300, 62), (307, 72), (292, 84), (309, 86), (301, 80))):
            c.ellipse(lx, ly, 4, 6, hexc('4d6a3c') if i % 3 else hexc('7c6a38'))
            c.line(302, 99, lx, ly + 5, hexc('3e5530'))
    lr.shifted(c, plant, -10, 0)


def _sideboard_tv(c, CX, TEAK, TEAK_DK, TEAK_LT):
    c.shadow(CX, 101, 36, 2, 90)
    c.box(CX - 34, 72, CX + 34, 97, TEAK, TEAK_DK)
    c.hline(CX - 33, CX + 33, 73, TEAK_LT)
    c.hline(CX - 33, CX + 33, 75, TEAK_DK)
    for sx in (CX - 11, CX + 11):
        c.vline(sx, 76, 95, TEAK_DK)
    for lx in (CX - 31, CX + 30):
        c.rect(lx, 98, lx + 1, 100, hexc('2a2a2c'))
    T = -12
    c.box(CX - 15, 60 + T, CX + 15, 83 + T, TEAK, TEAK_DK)
    c.hline(CX - 14, CX + 14, 61 + T, TEAK_LT)
    c.box(CX - 12, 63 + T, CX + 5, 80 + T, hexc('2c3431'), hexc('1a1f1d'))
    c.rect(CX - 10, 65 + T, CX - 7, 66 + T, hexc('4b5a55'))
    c.line(CX - 6, 66 + T, CX + 2, 76 + T, hexc('7d8b86'))
    c.line(CX - 2, 67 + T, CX - 4, 74 + T, hexc('7d8b86'))
    for gy in range(64 + T, 80 + T, 2):                                     # speaker grille
        c.hline(CX + 8, CX + 12, gy, hexc('5b3e28'))
    c.line(CX - 2, 60 + T, CX - 9, 50 + T, hexc('2a2a2c'))
    c.line(CX + 2, 60 + T, CX + 8, 49 + T, hexc('2a2a2c'))
    import furn as F
    F.table_lamp(c, CX - 26, 71, 'mustard')                          # a lamp at the sideboard's end


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


# Owner round 14: the old posters (a black slab with a red block, a yellow shape) "don't really make
# any sense" — now a gig poster you can read (LIVE, a guitarist in a spotlight) and a holiday poster
# with its corner torn away. The guitar (it was "so squished and slim", squeezed under window R) now
# stands upright on a floor stand at full size, right of the window box.
def guitar_on_stand(c, cx, floor):
    """An acoustic guitar upright on a floor stand against the wall — drawn mirror-true about cx:
    a sunburst body (lower bout, waist, upper bout), sound hole + rosette, bridge, a dark fretboard
    with dots, the headstock with three tuning pegs a side; one string snapped and curling."""
    OUT = hexc('2a1a10')
    EDGE = hexc('5a2e14')
    MID = hexc('a4562a')
    CEN = hexc('d8963e')
    NECK = hexc('6a4424')
    BOARD = hexc('2e2018')
    STAND = hexc('2a2a2e')
    bot = floor - 7                       # the body sits in the stand's cradle
    H = 26                                # body height
    top = bot - H
    def half(y):                          # half-width of the body at row y (0 = bottom)
        t = (bot - y) / float(H)
        lower = 8.4 * math.sqrt(max(0.0, 1 - ((t - 0.30) / 0.36) ** 2)) if t < 0.66 else 0
        upper = 6.6 * math.sqrt(max(0.0, 1 - ((t - 0.76) / 0.25) ** 2)) if t > 0.50 else 0
        w = max(lower, upper)
        if 0.52 < t < 0.64:
            w = max(w, 5.4)               # the waist
        return w
    # stand: two splayed legs + the cradle arms, and the neck rest behind the neck
    for s in (-1, 1):
        c.line(cx + s * 3, bot + 1, cx + s * 8, floor, STAND)
        c.line(cx + s * 4, bot + 1, cx + s * 9, floor, STAND)
        c.put(cx + s * 7, bot - 1, STAND)
    c.vline(cx, bot - H - 16, bot, STAND)
    c.rect(cx - 3, bot - H - 17, cx + 3, bot - H - 16, STAND)
    c.shadow(cx, floor + 1, 10, 2, 110)
    # body
    for y in range(top, bot + 1):
        w = half(y)
        if w <= 0:
            continue
        x0, x1 = int(round(cx - w)), int(round(cx + w))
        for x in range(x0, x1 + 1):
            d = abs(x - cx) / max(w, 0.1)
            col = CEN if d < 0.45 else MID if d < 0.8 else EDGE
            c.put(x, y, col)
        c.put(x0, y, OUT); c.put(x1, y, OUT)
    c.hline(int(cx - half(bot)), int(cx + half(bot)), bot, OUT)
    c.hline(int(cx - half(top + 1)), int(cx + half(top + 1)), top, OUT)
    # sound hole + rosette, bridge + saddle
    hy = top + 8
    for y in range(hy - 3, hy + 4):
        for x in range(cx - 3, cx + 4):
            r = ((x - cx) ** 2 + (y - hy) ** 2) ** 0.5
            if r <= 2.4:
                c.put(x, y, hexc('140c08'))
            elif r <= 3.3:
                c.put(x, y, hexc('e8d2a0'))
    c.rect(cx - 4, bot - 6, cx + 4, bot - 5, OUT)
    c.hline(cx - 2, cx + 2, bot - 6, hexc('e8e0cc'))
    # neck + fretboard (over the body's upper bout down to the sound hole)
    ntop = top - 17
    c.rect(cx - 1, ntop, cx + 1, hy - 4, BOARD)
    c.vline(cx - 2, ntop, top, NECK); c.vline(cx + 2, ntop, top, NECK)
    for fy in range(ntop + 3, top, 3):
        c.hline(cx - 1, cx + 1, fy, hexc('8a8a86'))            # frets
    for fy in (ntop + 7, ntop + 12):
        c.put(cx, fy + 1, hexc('e8e0cc'))                        # position dots
    # headstock + pegs
    c.rect(cx - 2, ntop - 7, cx + 2, ntop - 1, NECK)
    c.rect(cx - 1, ntop - 6, cx + 1, ntop - 2, hexc('3a2414'))
    for k in range(3):
        c.put(cx - 3, ntop - 6 + 2 * k, hexc('c8c4b8')); c.put(cx + 3, ntop - 6 + 2 * k, hexc('c8c4b8'))
    c.hline(cx - 2, cx + 2, ntop - 8, OUT)
    # strings (pale, down the middle), one snapped, curling off the headstock
    for y in range(ntop, bot - 5):
        if y < hy - 3 or y > hy + 3:
            c.put(cx, y, mix(hexc('e8e0cc'), BOARD, 0.35) if y < top else hexc('e8e0cc'))
    for k, (dx, dy) in enumerate(((-3, -6), (-5, -4), (-6, -1), (-6, 2), (-5, 4))):
        c.put(cx + dx, ntop + dy, hexc('d9d0bc'))

def gig_poster(c, x0, y0, x1, y1):
    """A gig poster: cream paper, the title LIVE in red block letters, a black guitarist's
    silhouette in an orange spotlight, the small print below — tape at the corners."""
    PAPER, INK, RED, SUN = hexc('e4d8bc'), hexc('1e1a1c'), hexc('b8332a'), hexc('e0913a')
    c.rect(x0, y0, x1, y1, PAPER)
    c.rect(x0 + 1, y1, x1 + 1, y1 + 1, hexc('000000', 60))      # a hair of shadow
    GL = {'L': ['1..', '1..', '1..', '1..', '111'], 'I': ['1', '1', '1', '1', '1'],
          'V': ['1.1', '1.1', '1.1', '1.1', '.1.'], 'E': ['111', '1..', '11.', '1..', '111']}
    x = x0 + 4
    for ch in 'LIVE':
        g = GL[ch]
        for gy, row in enumerate(g):
            for gx, v in enumerate(row):
                if v == '1':
                    c.put(x + gx, y0 + 3 + gy, RED)
        x += len(g[0]) + 1
    cx, cy = (x0 + x1) // 2, y0 + 19
    for y in range(cy - 7, cy + 8):
        for xx in range(cx - 8, cx + 9):
            if ((xx - cx) / 8.5) ** 2 + ((y - cy) / 7.5) ** 2 <= 1.0:
                c.put(xx, y, SUN)
    # the guitarist: head, body, legs apart, a guitar across the body
    c.rect(cx - 1, cy - 6, cx + 1, cy - 4, INK)
    c.rect(cx - 2, cy - 3, cx + 2, cy + 2, INK)
    c.line(cx - 1, cy + 3, cx - 3, cy + 7, INK); c.line(cx + 1, cy + 3, cx + 3, cy + 7, INK)
    c.line(cx - 5, cy + 2, cx + 5, cy - 3, INK)                   # the guitar's neck
    c.rect(cx - 5, cy, cx - 3, cy + 3, INK)                       # its body
    c.hline(x0 + 4, x1 - 4, y1 - 5, hexc('7a6e5c'))                # small print
    c.hline(x0 + 6, x1 - 6, y1 - 3, hexc('7a6e5c'))
    for tx, ty in ((x0, y0), (x1, y0)):
        c.rect(tx - 1, ty - 1, tx + 1, ty, hexc('f0ead2', 190))    # tape

def travel_poster(c, x0, y0, x1, y1):
    """A holiday poster half torn away: sunset bands, the sun going down into the sea, a palm —
    the bottom corner torn off (the wall behind) with the flap folded down, its white back out."""
    bands = [hexc('e8a04a'), hexc('e07a44'), hexc('c85a4a'), hexc('8a4a5e')]
    tear = lambda x: y1 - 4 - int(6 * (x - x0) / max(1, x1 - x0)) + ((x * 5) % 3 == 0)
    for x in range(x0, x1 + 1):
        for y in range(y0, tear(x) + 1):
            k = min(3, (y - y0) * 4 // max(1, (y1 - y0 - 8)))
            c.put(x, y, bands[k])
    sy = y0 + 12
    for y in range(sy - 4, sy + 1):
        for x in range(x0 + 6, x0 + 15):
            if ((x - (x0 + 10)) / 4.5) ** 2 + ((y - sy) / 4.5) ** 2 <= 1.0:
                c.put(x, y, hexc('f6d68a'))
    for x in range(x0, x1 + 1):
        if tear(x) >= sy + 1:
            c.put(x, sy + 1, hexc('3a4a78'))
        for y in range(sy + 2, min(tear(x), sy + 6) + 1):
            c.put(x, y, hexc('2e3a62') if (x + y) % 4 else hexc('4a5a8a'))
    PALM = hexc('1e1a1c')
    px = x1 - 6
    for y in range(y0 + 8, sy + 5):                                   # the trunk, leaning
        c.put(px + (sy + 5 - y) // 6, y, PALM)
    cx_, cy_ = px + (sy + 5 - (y0 + 8)) // 6, y0 + 7
    for (dx, dy) in ((-5, 3), (-4, 2), (-3, 1), (-2, 0), (-1, 0), (1, 0), (2, 0), (3, 1), (4, 2), (5, 3),
                     (-3, -1), (-2, -2), (2, -2), (3, -1), (0, -1)):       # fronds drooping from the crown
        c.put(cx_ + dx, cy_ + dy, PALM)
    # the flap: the torn-off corner folded down, its back (white) showing
    for j in range(5):
        for i in range(6 - j):
            c.put(x1 - i, tear(x1) + 1 + j, hexc('ece6d4') if i else hexc('c8c0aa'))
    for tx, ty in ((x0, y0), (x1, y0)):
        c.rect(tx - 1, ty - 1, tx + 1, ty, hexc('f0ead2', 190))



def c_decor(c):
    gig_poster(c, 104, 26, 128, 58)
    travel_poster(c, 138, 28, 160, 56)


def c_floor(c):
    carpet_floor(c, hexc('59605f'), hexc('6b7271'), hexc('474d4c'))


def c_furniture(c):
    # LEFT set-back: milk crates stacked as shelving (with depth; 3px left of where they stood flat)
    def _crates(c):
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
    setback(c, lambda l: lr.shifted(l, _crates, 0, -3), depth=4, top=57, x_range=(9, 45))
    # WATCHING THE TELLY FROM BEHIND (owner round 13b): the CRT on two crates centred against the
    # back wall, the slumped grey sofa facing it with its back to us; the pallet table on the left,
    # a guitar against the wall and a beanbag on the right — evenly spaced.
    CX = 176

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
    lr.shifted(c, _pallet, 0, -126)
    # the CRT on two crates, a console + its cable
    def _tv(c):
        c.shadow(276, 101, 20, 2, 90)
        for (y0, y1, col) in ((87, 100, hexc('2f4f7a')), (73, 86, hexc('a8453a'))):   # two crates, stacked
            c.box(260, y0, 290, y1, col, shade(col, 0.6))
            c.rect(262, y0 + 2, 288, y1 - 2, shade(col, 0.45))
            for gx in range(264, 288, 5):
                c.vline(gx, y0 + 2, y0 + 4, col)
        c.box(262, 56, 290, 72, hexc('4a4a4d'), hexc('1c1c1e'))              # the CRT on top
        c.box(265, 58, 285, 69, hexc('23302c'), hexc('111615'))
        c.rect(267, 60, 271, 61, hexc('3e524b'))
        c.rect(265, 91, 279, 94, hexc('5a5a5f'))                             # a console in the lower crate
    setback(c, lambda l: lr.shifted(l, _tv, 0, CX - 276), depth=4, top=56)
    sofa_back(c, CX, 118, (hexc('6d6e70'), hexc('555658'), hexc('848587'), hexc('2c2d2f')), wear=True)
    # a slumped beanbag by the sofa, under window R
    BB, BB_DK, BB_LT = hexc('7a2e28'), hexc('551f1b'), hexc('94403a')
    bx = 248
    c.shadow(bx, 112, 16, 2, 110)
    c.ellipse(bx, 104, 15, 9, hexc('2a1210'))
    c.ellipse(bx, 104, 14, 8, BB)
    c.ellipse(bx, 108, 13, 4, BB_DK)
    c.ellipse(bx - 4, 100, 6, 3, BB_LT)
    c.line(bx - 8, 105, bx + 6, 103, BB_DK)
    # the guitar, upright on its floor stand in the corner (right of the window box)
    guitar_on_stand(c, 293, 101)
    import furn as F
    F.bare_bulb(c, 202, 30)                                          # a bare bulb on a flex


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
    # LEFT set-back: an upright piano, photos and a metronome on top (with depth — owner round 14)
    setback(c, lambda l: lr.shifted(l, _piano, 0, -4), depth=5, top=67, x_range=(6, 52), rake=1.2)
    _d_rest(c)


def _piano(c):
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


def _d_rest(c):
    # the chintz sofa: cream with a REGULAR rose print (a scatter of random dots read as spatter —
    # owner round 14), small roses with a leaf on a half-drop grid, only on the upholstery
    sofa_as(c, (hexc('c8b89a'), hexc('a99a7c'), hexc('d9cbb0'), hexc('5e5040')), dx=66)
    cream = ((0xc8, 0xb8, 0x9a), (0xd9, 0xcb, 0xb0), (0xa9, 0x9a, 0x7c))
    for y in range(80, 112, 6):
        off = 4 if (y // 6) % 2 else 0
        for x in range(152 + off, 240, 8):
            if all(c.px[x + dx, y + dy][:3] in cream for dx in (-1, 0, 1, 2) for dy in (0, 1)):
                c.put(x, y, hexc('a0505a'))
                c.put(x + 1, y, hexc('b8686e'))
                c.put(x, y + 1, hexc('8a4048'))
                c.put(x + 2, y + 1, hexc('6f7d58'))
    def _tea(c):
        # a small mahogany tea table on a lace doily: a china teapot, a cup on its saucer
        c.shadow(214, 117, 18, 2, 100)
        c.ellipse(214, 101, 16, 4, hexc('3a2019'))
        c.ellipse(214, 100, 15, 3, hexc('5a352b'))
        c.ellipse(214, 99, 10, 2, hexc('e6ddc8'))
        for x in range(205, 224, 2):
            c.put(x, 101, hexc('e6ddc8'))                                # the doily's scalloped edge
        for lx in (203, 225):
            c.rect(lx, 104, lx + 1, 116, hexc('2a1712'))
            c.put(lx - 1, 116, hexc('2a1712'))
        POT, POT_DK, POT_LT = hexc('ece6d6'), hexc('b8b0a0'), hexc('ffffff')
        c.ellipse(209, 95, 4, 3, POT)                                     # the pot's body
        c.hline(206, 212, 97, POT_DK)
        c.put(208, 93, POT_LT)
        c.rect(208, 91, 210, 92, POT)                                     # lid + knob
        c.put(209, 90, hexc('5a7a9a'))
        c.line(213, 95, 216, 93, POT)                                     # spout
        c.put(204, 94, POT_DK); c.put(204, 95, POT_DK); c.put(205, 96, POT_DK)   # handle
        c.hline(206, 212, 95, hexc('5a7a9a'))                             # a blue band
        c.ellipse(220, 98, 3, 1, POT)                                     # saucer
        c.rect(219, 95, 222, 97, POT)                                     # cup
        c.put(223, 96, POT_DK)
        c.hline(219, 222, 95, POT_LT)
    lr.shifted(c, _tea, 0, -90)
    setback(c, lambda l: lr.shifted(l, _china_cabinet, 0, 3), depth=5, top=67, x_range=(265, 301), rake=1.2)
    import furn as F
    F.pendant(c, 196, 22, 'cream', dome=True)


def _china_cabinet(c):
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
    import furn as F
    F.table_lamp(c, 290, top - 1, 'rose', base=hexc('b58f4a'))              # a lamp on the cabinet





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
    FX = 160

    def _gun_cabinet(c):
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

    def _fireplace(c):
        # a stone fireplace against the wall, SYMMETRIC about x 128 (owner round 13): hearth, stone
        # surround laid in courses mirrored about the centre, an arched firebox with the grate and its
        # charred logs centred, a candlestick at each end of the mantel, the antlers above the middle.
        # The poker stand stands on the hearth to the right, a log basket to the left (the old game bag
        # slumped on the floor went — owner: "strange items just on the floor").
        # EVEN SPACING (owner round 13b): gun cabinet | armchair turned to the fire | the fireplace in the
        # MIDDLE under the antlers | sofa — the room's pieces spread across it, not piled on the right.
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

    def _poker(c):
        # the poker stand on the hearth, right
        c.vline(FX + 34, 72, 99, hexc('3a3a36')); c.hline(FX + 31, FX + 37, 99, hexc('3a3a36'))
        c.hline(FX + 31, FX + 37, 74, hexc('3a3a36'))
        for tx in (FX + 32, FX + 36):
            c.vline(tx, 75, 92, hexc('4a4a44'))

    def _basket(c):
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

    # with depth (owner round 14): the cabinet 3px left of where it stood flat (clear of window L)
    setback(c, lambda l: lr.shifted(l, _gun_cabinet, 0, -3), depth=5, top=22, x_range=(5, 41), rake=1.0)
    setback(c, _fireplace, depth=4, top=52, x_range=(FX - 30, FX + 30))
    setback(c, _basket, depth=3, top=86, x_range=(FX - 48, FX - 33))
    setback(c, _poker, depth=3)
    # a chesterfield in oxblood leather, and a bear-skin rug before it
    sofa_as(c, (hexc('6e2a24'), hexc('55201c'), hexc('84403a'), hexc('2a100e')), dx=128)
    bear, bear_dk = hexc('9a7450'), hexc('6a4a34')
    c.poly([(118, 126), (128, 120), (132, 116), (140, 120), (170, 119), (178, 115), (184, 120), (196, 124),
            (184, 128), (178, 132), (170, 128), (140, 129), (132, 133), (128, 129)], bear)   # the pelt, legs out
    c.poly([(196, 124), (206, 120), (212, 123), (208, 128)], bear)                              # the head
    c.put(206, 122, hexc('1e1a16')); c.put(211, 124, hexc('d9cfb8'))
    c.line(140, 124, 170, 124, bear_dk)
    import furn as F
    F.pendant(c, 296, 22, 'mustard')                                 # over the chesterfield


E_ANCHORS = [('anchor_living_gun_cabinet', 23, 56, 'bp'), ('anchor_living_fireplace', 160, 90, 'bp'),
             ('anchor_living_log_basket', 120, 92, 'bp'), ('anchor_centre_sofaleft', 239, 103, ''),
             ('anchor_centre_sofaright', 274, 101, ''), ('anchor_living_armchair', 78, 104, '')]


# Turned armchairs (tools/art/chair3d.py — built in 3D so the angle is right), each grouped with
# what it's for: B watches the TV, D sits at the rug's end facing the sofa, E is the reading chair
# by the lamp, turned toward the fire. (C, the bare student flat, has none.)
import chair3d as C3


def b_chair(c):
    C3.armchair(c, 240, 118, 110, {'fab': hexc('a8843a'), 'fab_lt': hexc('b8944a'), 'wood': hexc('3a2618')},
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


B_ANCHORS = [('anchor_living_records', 27, 86, 'bp'), ('anchor_living_teak_shelf', 35, 72, 'bp'),
             ('anchor_living_kidney_table', 76, 100, ''),
             ('anchor_centre_sofaleft', 128, 100, ''), ('anchor_centre_sofaright', 172, 98, ''),
             ('anchor_living_armchair', 240, 104, '')]
C_ANCHORS = [('anchor_living_crates', 19, 68, 'bp'), ('anchor_living_crate_books', 33, 92, 'bp'),
             ('anchor_living_pallet_table', 79, 101, ''), ('anchor_centre_sofaleft', 154, 100, ''),
             ('anchor_centre_sofaright', 198, 98, ''), ('anchor_living_beanbag', 248, 102, '')]
D_ANCHORS = [('anchor_living_piano', 22, 74, 'bp'), ('anchor_living_tea_table', 124, 99, ''),
             ('anchor_centre_sofaleft', 177, 103, ''), ('anchor_centre_sofaright', 212, 101, ''),
             ('anchor_living_china_cabinet', 283, 76, 'bp'), ('anchor_living_cabinet_cupboard', 277, 90, 'bp'),
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
