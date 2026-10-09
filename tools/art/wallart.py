"""WALL ART — posters, framed pictures, notes, notices (owner round 38: "another pass at the various
posters and wall arts… a sign saying bins out Monday but the sign looks very plain and basic for what is an
announcement statement from building management… the child's bedroom variation has posters with generic
words like SPACE, I think we can do away with the words… just image posters that have better visuals and
poster / picture-frame borders etc. quality beyond generic detail").

ONE kit for everything hung on a wall, used by the rooms (tools/art/furn.py delegates its poster / frame /
note helpers here) and by the corridor's notices (tools/art/corridor_decals.py). Drawn at NATIVE
resolution like the rest of the art (1 px = 1 world px, hard edges, FLAT — the engine does the lighting).

  primitives   px (alpha-safe), tape, pushpin, nail, sheet (paper with an edge, a shadow, a fold, a curl)
  frames       frame() — wood / black / gilt / snap / white-border around a picture; returns the inner rect
  pictures     the IMAGE posters (no words): guitar, horror, space, travel, map — each takes an outer rect
  notices      the building's paper: memos on letterhead, safety signs with pictograms, hazard signs, a
               curfew order with its stamp, a missing-person flyer with tear-off tabs, a kid's drawing
  rooms        note / sticky / newspaper / missing flyer for the flats (same footprints as before)

Run:  python3 tools/art/wallart.py      → docs/art_reference/wall_art.png (everything at 4x)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, mix  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

INK = hexc('25262c')
INK_SOFT = hexc('5a5a60')
RED = hexc('b8322a')
RED_DK = hexc('8a2420')
NAVY = hexc('2c4268')
GREEN = hexc('2f6a48')
YELLOW = hexc('e8c43c')
WHITE = hexc('f6f3ea')


# --------------------------------------------------------------------------------------------
# primitives
# --------------------------------------------------------------------------------------------
def px(c, x, y, col):
    """Alpha-safe put: a translucent colour over a transparent pixel keeps its own colour (Canvas.put
    would darken it toward black), over an opaque one it blends."""
    if not (0 <= x < c.w and 0 <= y < c.h):
        return
    a = col[3] if len(col) == 4 else 255
    if a >= 255:
        c.px[x, y] = tuple(col[:3]) + (255,)
    elif a > 0:
        bg = c.px[x, y]
        if bg[3] == 0:
            c.px[x, y] = tuple(col[:3]) + (a,)
        else:
            f = a / 255.0
            c.px[x, y] = tuple(int(round(bg[i] * (1 - f) + col[i] * f)) for i in range(3)) + (max(bg[3], a),)


def prect(c, x0, y0, x1, y1, col):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(c, x, y, col)


def solid(c, x, y):
    return 0 <= x < c.w and 0 <= y < c.h and c.px[x, y][3] > 0


def tape(c, x, y, w=6, h=3, tilt=0, col=hexc('e6dcae', 175)):
    """A strip of masking tape across a corner: translucent, a darker edge top and bottom, torn ends."""
    for j in range(h):
        for i in range(w):
            ox = i
            oy = j + (i * tilt) // max(1, w)
            if (i == 0 or i == w - 1) and (j + i) % 2 == 0:
                continue                                                          # the torn end
            px(c, x + ox, y + oy, col)
        px(c, x, y + j, col)
    for i in range(1, w - 1):
        px(c, x + i, y + (i * tilt) // max(1, w), hexc('b8aa78', 120))
        px(c, x + i, y + h - 1 + (i * tilt) // max(1, w), hexc('b8aa78', 100))


def pushpin(c, x, y, col=hexc('c0453a')):
    """A map pin: a round head with a highlight, a hair of shadow below-right."""
    px(c, x + 1, y + 2, hexc('000000', 70))
    px(c, x, y, col)
    px(c, x + 1, y, shade(col, 0.8))
    px(c, x, y + 1, shade(col, 0.7))
    px(c, x + 1, y + 1, shade(col, 0.55))
    px(c, x, y, shade(col, 1.25))


def nail(c, x, y):
    px(c, x, y, hexc('a8a49a'))
    px(c, x, y + 1, hexc('3a3834', 140))


def screw(c, x, y, col=hexc('8a8f96')):
    px(c, x, y, shade(col, 1.25))
    px(c, x + 1, y, col)
    px(c, x, y + 1, shade(col, 0.7))
    px(c, x + 1, y + 1, shade(col, 0.55))


def sheet(c, x0, y0, x1, y1, paper, seed=1, fold=None, curl=None, grain=0.05, edge=True):
    """A piece of paper stuck to a wall: the sheet, a soft grain, a lit top-left and shaded bottom-right
    edge, a hair of drop shadow outside it, optionally a FOLD (crease line across: 'h' / 'v' / 'h2'),
    a CURL (a lifted corner: 'br' / 'bl' / 'tr' / 'tl')."""
    rng = random.Random(seed * 7919 + x0 * 13 + y0)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            col = paper
            if grain and rng.random() < grain:
                col = shade(paper, 0.95 if rng.random() < 0.7 else 1.04)
            px(c, x, y, col)
    for x in range(x0 + 1, x1 + 2):                                                  # drop shadow
        px(c, x, y1 + 1, hexc('000000', 62))
    for y in range(y0 + 1, y1 + 2):
        px(c, x1 + 1, y, hexc('000000', 46))
    if edge:
        for x in range(x0, x1 + 1):
            px(c, x, y0, shade(paper, 1.07))
            px(c, x, y1, shade(paper, 0.86))
        for y in range(y0, y1 + 1):
            px(c, x0, y, shade(paper, 1.04))
            px(c, x1, y, shade(paper, 0.9))
    if fold in ('h', 'h2'):
        for yy in ((y0 + (y1 - y0) // 2,) if fold == 'h' else (y0 + (y1 - y0) // 3, y0 + 2 * (y1 - y0) // 3)):
            for x in range(x0 + 1, x1):
                px(c, x, yy, shade(paper, 0.9))
                px(c, x, yy + 1, shade(paper, 1.06))
    elif fold == 'v':
        xx = x0 + (x1 - x0) // 2
        for y in range(y0 + 1, y1):
            px(c, xx, y, shade(paper, 0.9))
            px(c, xx + 1, y, shade(paper, 1.06))
    if curl:
        cx = x1 if curl[1] == 'r' else x0
        cy = y1 if curl[0] == 'b' else y0
        sx = -1 if curl[1] == 'r' else 1
        sy = -1 if curl[0] == 'b' else 1
        for k in range(3):                                                           # a lifted triangle
            for j in range(3 - k):
                px(c, cx + sx * k, cy + sy * j, shade(paper, 0.78) if k + j < 2 else shade(paper, 1.1))
        px(c, cx + sx * 3, cy, hexc('000000', 50))
        px(c, cx, cy + sy * 3, hexc('000000', 50))


def text(c, x, y, word, col, scale=1, bold=False):
    """The building's 3x5 capitals at an integer scale; `bold` thickens each stroke a pixel sideways.
    Returns the width drawn."""
    import furn as F
    x0 = x
    for ch in word:
        g = F.FONT3.get(ch, F.FONT3[' '])
        for gy, row in enumerate(g):
            for gx, v in enumerate(row):
                if v == '1':
                    for sy in range(scale):
                        for sx in range(scale):
                            px(c, x + gx * scale + sx, y + gy * scale + sy, col)
                            if bold and scale == 1:
                                px(c, x + gx + 1, y + gy, col)
        x += (len(g[0]) + 1) * scale + (1 if bold and scale == 1 else 0)
    return x - x0 - scale


def width(word, scale=1, bold=False):
    import furn as F
    n = sum((len(F.FONT3.get(ch, F.FONT3[' '])[0]) + 1) * scale + (1 if bold and scale == 1 else 0) for ch in word)
    return n - scale


def centred(c, cx, y, word, col, scale=1, bold=False):
    return text(c, cx - width(word, scale, bold) // 2, y, word, col, scale, bold)


def greek(c, x0, x1, y, col, rng, gap=2):
    """A line of small print too small to read at this size: dashes of random length with word gaps."""
    x = x0
    while x < x1:
        ln = rng.randint(2, 5)
        for i in range(ln):
            if x + i <= x1:
                px(c, x + i, y, col)
        x += ln + gap


def greek_block(c, x0, x1, y, lines, col, seed, last_short=True):
    rng = random.Random(seed)
    for i in range(lines):
        xe = x1 if not (last_short and i == lines - 1) else x0 + (x1 - x0) * rng.randint(40, 70) // 100
        greek(c, x0, xe, y + i * 2, col, rng)


def crest_mark(c, x, y, fg, win):
    """The building's mark, 5 x 6: a stepped tower with its windows."""
    for j, row in enumerate(('..#..', '.###.', '.#w#.', '#####', '#w#w#', '#####')):
        for i, ch in enumerate(row):
            if ch == '#':
                px(c, x + i, y + j, fg)
            elif ch == 'w':
                px(c, x + i, y + j, win)


def scribble_name(c, x, y, w, col, seed):
    """A signature: a loose pen line with a flourish under it."""
    rng = random.Random(seed)
    for i in range(w):
        yy = y + int(round(1.6 * math.sin(i * 0.9 + seed) * (0.4 + 0.6 * math.sin(i * 0.23))))
        px(c, x + i, yy, col)
        if i % 5 == 0 and rng.random() < 0.7:
            px(c, x + i, yy - 1, col)
    for i in range(3, w - 2):
        if i % 2 == 0:
            px(c, x + i, y + 3, col)


def stripes(c, x0, y0, x1, y1, a, b, step=3):
    """Diagonal hazard stripes."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(c, x, y, a if ((x - x0) + (y - y0)) // step % 2 == 0 else b)


# --------------------------------------------------------------------------------------------
# pictograms (small, drawn with strokes so they work at any size)
# --------------------------------------------------------------------------------------------
def thick_line(c, x0, y0, x1, y1, col, t=2):
    for k in range(t):
        c.line(x0 + k, y0, x1 + k, y1, col)


def running_man(c, x, y, col, h=14, flip=False):
    """The fire-exit figure: head, leaning torso, trailing arm, reaching arm, a stride."""
    s = h / 14.0
    def P(a, b):
        return (x + int(round(a * s)), y + int(round(b * s)))
    sgn = -1 if flip else 1
    def Q(a, b):
        return P(7 + sgn * (a - 7), b)
    hx, hy = Q(8, 1)
    c.ellipse(hx, hy, max(1.2, 1.7 * s), max(1.2, 1.7 * s), col)
    segs = [((7, 4), (6, 8)),          # torso
            ((7, 4), (3, 5)),          # trailing arm
            ((3, 5), (2, 8)),
            ((7, 4), (11, 6)),         # reaching arm
            ((6, 8), (10, 10)),        # front leg
            ((10, 10), (9, 13)),
            ((6, 8), (3, 11)),         # back leg
            ((3, 11), (1, 13))]
    for (a, b) in segs:
        (ax, ay), (bx, by) = Q(*a), Q(*b)
        thick_line(c, ax, ay, bx, by, col, 2 if s >= 0.9 else 1)


def arrow(c, x, y, direction, col, size=5):
    """A solid arrowhead + shaft, 'l' / 'r' / 'u' / 'd'."""
    if direction in ('l', 'r'):
        d = 1 if direction == 'r' else -1
        c.hline(x - d * size, x + d * size, y, col)
        c.hline(x - d * size, x + d * size, y + 1, col)
        c.poly([(x + d * size, y - 3), (x + d * (size + 4), y + 1), (x + d * size, y + 5)], col)
    else:
        d = 1 if direction == 'd' else -1
        c.vline(x, y - d * size, y + d * size, col)
        c.vline(x + 1, y - d * size, y + d * size, col)
        c.poly([(x - 3, y + d * size), (x + 1, y + d * (size + 4)), (x + 5, y + d * size)], col)


def warning_triangle(c, cx, y, w, fill, edge, mark):
    """A hazard triangle (apex up) with an exclamation mark."""
    h = int(w * 0.87)
    c.poly([(cx, y), (cx + w // 2 + 1, y + h), (cx - w // 2 - 1, y + h)], edge)
    c.poly([(cx, y + 3), (cx + w // 2 - 2, y + h - 2), (cx - w // 2 + 2, y + h - 2)], fill)
    c.rect(cx - 1, y + h // 3 + 1, cx, y + h - 5, mark)
    c.rect(cx - 1, y + h - 3, cx, y + h - 2, mark)


def biohazard(c, cx, cy, r, col, bg):
    """The hazard trefoil: three 60 degree blades round a small disc, a ring gap between."""
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d = math.hypot(x - cx, y - cy)
            if d > r + 0.3:
                continue
            ang = (math.degrees(math.atan2(y - cy, x - cx)) + 90.0 + 30.0) % 360.0
            blade = (ang % 120.0) < 60.0
            if d <= max(1.6, r * 0.27):
                px(c, x, y, col)
            elif d >= r * 0.42 and blade:
                px(c, x, y, col)


def water_drop(c, cx, y, h, col, hi):
    for j in range(h):
        t = j / float(h)
        half = int(round((0.3 + 2.2 * t if t < 0.75 else 2.6 * (1 - (t - 0.75) * 2.2)) * (h / 9.0)))
        c.hline(cx - half, cx + half, y + j, col)
    px(c, cx - 1, y + h - 4, hi)
    px(c, cx - 1, y + h - 3, hi)


def speaker(c, x, y, col):
    """A loudspeaker with sound arcs: the 'keep it down' pictogram."""
    c.rect(x, y + 3, x + 2, y + 7, col)
    c.poly([(x + 3, y + 3), (x + 8, y), (x + 8, y + 10), (x + 3, y + 7)], col)
    for (r, d) in ((3, 0), (5, 1)):
        for k in range(-r, r + 1):
            px(c, x + 10 + d + int(round(math.sqrt(max(0, r * r - k * k)) * 0.5)), y + 5 + k, col)


def cigarette(c, cx, cy, col, tip=hexc('e0702c')):
    c.rect(cx - 6, cy - 1, cx + 3, cy + 1, col)                                  # the white body
    c.rect(cx - 6, cy - 1, cx - 3, cy + 1, hexc('d8a860'))                       # the filter
    c.rect(cx + 4, cy - 1, cx + 5, cy + 1, tip)
    for k in range(4):                                                            # smoke
        px(c, cx + 6 + k, cy - 3 - (k % 2) - k // 2, hexc('b8b8b8'))
        px(c, cx + 2 + k, cy - 4 - k // 2, hexc('b8b8b8'))


def prohibition(c, cx, cy, r, ring=RED, thick=2):
    """The red ring + slash."""
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d = math.hypot(x - cx, y - cy)
            if r - thick <= d <= r:
                px(c, x, y, ring)
    for t in range(-thick // 2 - 1, thick // 2 + 1):
        c.line(cx - int(r * 0.7), cy - int(r * 0.7) + t, cx + int(r * 0.7), cy + int(r * 0.7) + t, ring)


# --------------------------------------------------------------------------------------------
# THE BUILDING'S PAPER (corridor notices) — each returns a Canvas (transparent round the sheet).
# The corridor's notice slot (scripts/corridor_decals.gd "poster" zone: y 68..97, under the sconces, over
# the rail) takes up to 52 wide x 29 tall. Everything printed is in the building's own 3x5 capitals; what is
# too small to read is SMALL PRINT (greeked dashes), the way a real notice has it.
# --------------------------------------------------------------------------------------------
PAPER = {
    'white': hexc('f1eee4'), 'cream': hexc('e9e1c8'), 'blue': hexc('d3dee8'), 'green': hexc('d6e4d2'),
    'yellow': hexc('f0e39e'), 'pink': hexc('ecd3cf'), 'grey': hexc('dadad2'), 'kraft': hexc('c9ad82'),
}
SMALL_PRINT = hexc('9a978c')


def _canvas(w, h, seed):
    return Canvas(w=w, h=h, seed=seed)


def letterhead(c, x0, y0, x1, label, band=NAVY, ink=WHITE, rule=hexc('d8c070')):
    """The management's letterhead: a dark band (6 rows), the building's mark at its left, a word beside it, and a
    thin gold rule under (rows y0..y0+6)."""
    prect(c, x0, y0, x1, y0 + 5, band)
    crest_mark(c, x0 + 2, y0, ink, band)
    text(c, x0 + 9, y0 + 1, label, ink)
    for x in range(x0, x1 + 1):
        px(c, x, y0 + 6, rule)


def memo(seed, label, lines, icon=None, icon_w=0, line_cols=None, paper='white', band=NAVY, fold='v',
         bold=(), pin=hexc('c0453a'), w=52, tape_corners=False):
    """A landscape memo on the management's letterhead (52 x 23 — the most the corridor's notice slot allows: it
    hangs under the sconces and clear of the door plates): the band, an optional pictogram on the left, two lines of
    notice beside it, a curled corner, a fold, a pin."""
    h = 23
    c = _canvas(w, h, seed)
    x0, y0, x1, y1 = 1, 1, w - 2, h - 2
    sheet(c, x0, y0, x1, y1, PAPER[paper], seed, fold=fold, curl='br' if seed % 2 else 'bl')
    letterhead(c, x0 + 1, y0 + 1, x1 - 1, label, band)
    tx = x0 + 3 + (icon_w + 1 if icon else 0)
    for i, ln in enumerate(lines):
        assert tx + width(ln, 1, i in bold) <= x1 - 1, 'notice line too wide: %r (%d)' % (ln, tx + width(ln, 1, i in bold))
    assert width(label) + 9 <= x1 - x0 - 2, 'letterhead label too wide: %r' % label
    if icon:
        icon(c, x0 + 2, y0 + 9)
    y = y0 + 9
    for i, ln in enumerate(lines):
        col = line_cols[i] if line_cols else INK
        text(c, tx, y, ln, col, 1, i in bold)
        y += 6
    if tape_corners:
        tape(c, x0 - 1, y0 - 1, 6, 3, 1); tape(c, x1 - 5, y0 - 1, 6, 3, -1)
    else:
        pushpin(c, (x0 + x1) // 2, 0, pin)
    return c


def i_bin(c, x, y):
    """A wheelie bin (9 x 11): green lid, a fatter body lit on the left, a white number plate."""
    prect(c, x, y, x + 8, y + 2, hexc('3a8446'))
    prect(c, x, y, x + 8, y, hexc('58a866'))
    prect(c, x + 1, y + 3, x + 7, y + 9, hexc('4a9a5a'))
    prect(c, x + 1, y + 3, x + 2, y + 9, hexc('62b472'))
    prect(c, x + 7, y + 3, x + 7, y + 9, hexc('2f6e3a'))
    prect(c, x + 3, y + 4, x + 5, y + 7, hexc('f2eee4'))
    px(c, x + 4, y + 5, hexc('2f6e3a'))
    px(c, x + 4, y + 6, hexc('2f6e3a'))
    prect(c, x + 1, y + 10, x + 2, y + 10, hexc('26262a'))
    prect(c, x + 6, y + 10, x + 7, y + 10, hexc('26262a'))


def i_drop(c, x, y):
    water_drop(c, x + 4, y + 1, 10, hexc('3a78b8'), hexc('c0def4'))


def i_clock(c, x, y):
    """A wall clock showing seven (9 x 9): a pale face, a dark rim, the two hands."""
    c.ellipse(x + 4, y + 4, 4.3, 4.3, hexc('3a3a40'))
    c.ellipse(x + 4, y + 4, 3.3, 3.3, hexc('f4f0e4'))
    c.line(x + 4, y + 4, x + 4, y + 1, hexc('2a2a30'))
    c.line(x + 4, y + 4, x + 6, y + 6, hexc('2a2a30'))
    px(c, x + 4, y + 4, hexc('b8322a'))


def n_bins(seed=73):
    return memo(seed, 'MANAGERS', ['BINS OUT', 'MONDAY'], i_bin, 9, [INK, RED], paper='cream')


def n_water(seed=71):
    return memo(seed, 'MANAGERS', ['WATER OFF', 'TUES 9 - 5'], i_drop, 8, [INK, hexc('2c5f9a')], paper='blue',
                band=hexc('2c5f9a'))


def n_meeting(seed=72):
    return memo(seed, 'RESIDENTS', ['MEETING', 'THURS 7PM'], i_clock, 9, [INK, GREEN], paper='green', band=GREEN,
                pin=hexc('3a6a9a'))


def plate(c, x0, y0, x1, y1, col, edge=None, screws=True):
    """A moulded plastic / enamel sign plate: rounded corners, a lit top-left lip, a shaded lower edge,
    a screw at each corner, a hair of shadow."""
    edge = edge or shade(col, 0.6)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x in (x0, x1)) and (y in (y0, y1)):
                continue                                                          # rounded corner
            px(c, x, y, col)
    for x in range(x0 + 1, x1):
        px(c, x, y0, shade(col, 1.12)); px(c, x, y1, shade(col, 0.72))
    for y in range(y0 + 1, y1):
        px(c, x0, y, shade(col, 1.06)); px(c, x1, y, shade(col, 0.8))
    for x in range(x0 + 1, x1 + 2):
        px(c, x, y1 + 1, hexc('000000', 60))
    for y in range(y0 + 1, y1 + 2):
        px(c, x1 + 1, y, hexc('000000', 44))
    if screws:
        for (sx, sy) in ((x0 + 2, y0 + 2), (x1 - 3, y0 + 2), (x0 + 2, y1 - 3), (x1 - 3, y1 - 3)):
            screw(c, sx, sy)


def i_lift(c, x, y):
    """A lift: a steel box with a centre seam and up / down call arrows (9 x 11)."""
    prect(c, x, y, x + 8, y + 10, hexc('8c929a'))
    prect(c, x + 1, y + 1, x + 7, y + 10, hexc('b4bac2'))
    c.vline(x + 4, y + 1, y + 10, hexc('5a5f66'))
    c.poly([(x + 2, y + 4), (x + 3, y + 2), (x + 4, y + 4)], hexc('2a2a30'))
    c.poly([(x + 5, y + 6), (x + 6, y + 8), (x + 7, y + 6)], hexc('2a2a30'))


def n_lift(seed=70):
    """OUT OF ORDER: a yellow card with hazard stripes down both sides, the lift, LIFT at 2x, the verdict under it."""
    c = _canvas(52, 23, seed)
    x0, y0, x1, y1 = 1, 1, 50, 21
    sheet(c, x0, y0, x1, y1, PAPER['yellow'], seed, fold='h', curl='br')
    stripes(c, x0 + 1, y0 + 1, x0 + 2, y1 - 1, hexc('26262a'), hexc('e8c43c'), 3)
    stripes(c, x1 - 2, y0 + 1, x1 - 1, y1 - 1, hexc('26262a'), hexc('e8c43c'), 3)
    i_lift(c, 8, 4)
    text(c, 21, 4, 'LIFT', hexc('26262a'), 2)
    centred(c, 26, 15, 'OUT OF ORDER', RED_DK)
    tape(c, x0 - 1, y0 - 1, 6, 3, 1)
    tape(c, x1 - 5, y0 - 1, 6, 3, -1)
    return c


def n_smoking(seed=74):
    """The standard sign: a white plate, the red ring and slash over a cigarette, NO SMOKING beside it."""
    c = _canvas(52, 23, seed)
    x0, y0, x1, y1 = 1, 1, 50, 21
    plate(c, x0, y0, x1, y1, hexc('f4f2ea'), screws=True)
    cx, cy = x0 + 11, y0 + 10
    c.ellipse(cx, cy, 7.5, 7.5, hexc('fbf9f2'))
    c.rect(cx - 5, cy, cx + 2, cy + 1, hexc('f0eee6'))                      # the cigarette
    c.rect(cx - 5, cy, cx - 3, cy + 1, hexc('d8a860'))
    c.rect(cx + 3, cy, cx + 5, cy + 1, hexc('e0702c'))
    px(c, cx + 5, cy - 2, hexc('b8b8b8')); px(c, cx + 6, cy - 3, hexc('b8b8b8')); px(c, cx + 4, cy - 3, hexc('b8b8b8'))
    prohibition(c, cx, cy, 8, RED, 2)
    text(c, 21, 5, 'NO', INK)
    text(c, 21, 12, 'SMOKING', RED_DK)
    greek(c, 21, 47, 18, hexc('a8a69c'), random.Random(seed))
    return c


def n_quiet(seed=75):
    """A neighbour's note on a page torn from a pad: ruled blue lines, a red margin, punched holes down the
    torn edge, blue biro capitals, a loudspeaker crossed out."""
    c = _canvas(52, 23, seed)
    x0, y0, x1, y1 = 1, 1, 50, 21
    paper = hexc('f3f1e8')
    sheet(c, x0, y0, x1, y1, paper, seed, fold=None, curl='br')
    for yy in range(y0 + 8, y1, 6):
        c.hline(x0 + 1, x1 - 1, yy, hexc('b8cce0'))
    c.vline(x0 + 8, y0 + 1, y1 - 1, hexc('e0a8a0'))
    for hy in (y0 + 4, y0 + 10, y0 + 16):                                  # the punched holes
        c.ellipse(x0 + 3, hy, 1.4, 1.4, hexc('8a8478'))
        px(c, x0 + 3, hy, hexc('b8b4a8'))
    for k in range(0, y1 - y0, 2):                                         # a ragged torn left edge
        px(c, x0, y0 + k, hexc('d4d0c4'))
    ink = hexc('2a4aa8')
    text(c, x0 + 11, y0 + 2, 'PLEASE', ink)
    text(c, x0 + 11, y0 + 8, 'KEEP IT', ink)
    text(c, x0 + 11, y0 + 14, 'DOWN', ink)
    speaker(c, 37, 7, hexc('3a3a40'))
    c.line(36, 5, 48, 16, RED)
    c.line(37, 5, 49, 16, RED)
    tape(c, x1 - 9, y0 - 1, 7, 3, 0)
    return c


def n_evac(seed=76):
    """A green fire-exit plate: the running figure, EVACUATE, the way down and an arrow."""
    c = _canvas(52, 23, seed)
    x0, y0, x1, y1 = 1, 1, 50, 21
    g = hexc('2d7a4c')
    wh = hexc('f4f8f2')
    plate(c, x0, y0, x1, y1, g)
    rule = hexc('e8f2e8', 190)
    for x in range(x0 + 2, x1 - 1):
        px(c, x, y0 + 2, rule); px(c, x, y1 - 2, rule)
    for y in range(y0 + 2, y1 - 1):
        px(c, x0 + 2, y, rule); px(c, x1 - 2, y, rule)
    running_man(c, 4, 5, wh, 13)
    text(c, 15, 6, 'EVACUATE', wh)
    text(c, 15, 13, 'STAIRS', wh)
    c.hline(37, 42, 15, wh)
    c.poly([(42, 13), (45, 15), (42, 17)], wh)
    return c


def n_curfew(seed=77):
    """An order from the authorities: a black band (BY ORDER), the curfew hour, the doors."""
    c = memo(seed, 'BY ORDER', ['CURFEW 8PM', 'DOORS LOCKED'], None, 0, [RED, INK], paper='grey', band=hexc('1e1e22'),
             fold='h', pin=hexc('2a2a2e'))
    return c


def n_dont_open(seed=78):
    c = _canvas(52, 23, seed)
    x0, y0, x1, y1 = 1, 1, 50, 21
    sheet(c, x0, y0, x1, y1, PAPER['yellow'], seed, fold='v', curl='bl')
    for y in range(y0 + 1, y1):
        for k in (1, 2, 3):
            px(c, x0 + k, y, RED); px(c, x1 - k, y, RED)
    warning_triangle(c, 14, 4, 15, hexc('f0d23c'), hexc('26262a'), hexc('26262a'))
    text(c, 27, 3, 'DO NOT', RED_DK)
    text(c, 27, 9, 'OPEN', RED_DK)
    text(c, 27, 15, 'DOORS', RED_DK)
    tape(c, x0 + 1, y0 - 1, 6, 3, 1)
    tape(c, x1 - 6, y0 - 1, 6, 3, -1)
    return c


def n_quarantine(seed=66):
    """Portrait (38 x 29): a hazard-stripe frame, the trefoil, KEEP OUT."""
    c = _canvas(38, 29, seed)
    x0, y0, x1, y1 = 1, 2, 36, 27
    sheet(c, x0, y0, x1, y1, PAPER['yellow'], seed, fold=None, curl='br', edge=False)
    stripes(c, x0, y0, x1, y1, hexc('26262a'), hexc('e8c43c'), 3)
    prect(c, x0 + 2, y0 + 2, x1 - 2, y1 - 2, PAPER['yellow'])
    biohazard(c, 19, 11, 6, hexc('26262a'), PAPER['yellow'])
    centred(c, 19, 18, 'KEEP OUT', RED_DK)
    greek(c, 6, 31, 24, hexc('9a8a4a'), random.Random(seed), 1)
    pushpin(c, 19, 1, hexc('c0453a'))
    return c


def n_fire_door(seed=79):
    c = _canvas(52, 23, seed)
    x0, y0, x1, y1 = 1, 1, 50, 21
    b = hexc('2c5f9a')
    wh = hexc('f4f8fc')
    plate(c, x0, y0, x1, y1, b)
    # the door shut: a white frame, a dark leaf, a handle
    prect(c, 5, 5, 11, 17, wh)
    prect(c, 6, 6, 10, 17, hexc('1f4468'))
    px(c, 9, 12, wh)
    c.vline(8, 6, 17, hexc('2c5f9a'))
    text(c, 15, 5, 'FIRE DOOR', wh)
    text(c, 15, 12, 'KEEP SHUT', wh)
    greek(c, 15, 47, 18, hexc('9ab8d8'), random.Random(seed), 1)
    return c


def face(c, cx, cy, skin, hair, cloth, scale=1.0):
    """A small head and shoulders for a flyer's photo (about 9 x 9)."""
    prect(c, cx - 4, cy + 3, cx + 4, cy + 6, cloth)
    px(c, cx - 4, cy + 3, shade(cloth, 0.7)); px(c, cx + 4, cy + 3, shade(cloth, 0.7))
    c.ellipse(cx, cy, 2.6, 3.0, skin)
    c.hline(cx - 2, cx + 2, cy - 3, hair)
    c.vline(cx - 3, cy - 2, cy, hair)
    c.vline(cx + 3, cy - 2, cy, hair)
    px(c, cx - 1, cy, hexc('2a2220')); px(c, cx + 1, cy, hexc('2a2220'))
    px(c, cx, cy + 2, shade(skin, 0.7))


def n_missing(seed=65):
    """A MISSING flyer (34 x 29): a red banner, a snapshot of the face, small print, and the strip of
    tear-off phone-number tabs along the bottom — two already taken."""
    c = _canvas(34, 29, seed)
    x0, y0, x1, y1 = 1, 2, 32, 27
    paper = hexc('f3f0e6')
    sheet(c, x0, y0, x1, y1 - 4, paper, seed, fold=None, curl='tr')
    prect(c, x0 + 1, y0 + 1, x1 - 1, y0 + 7, RED)
    centred(c, 17, y0 + 2, 'MISSING', hexc('f6f0e4'))
    prect(c, 10, 11, 24, 21, hexc('fbf9f2'))                               # the snapshot, white border
    prect(c, 11, 12, 23, 20, hexc('8aa4b8'))
    prect(c, 11, 17, 23, 20, hexc('7a9a6a'))
    face(c, 17, 15, hexc('d8b08a'), hexc('4a3424'), hexc('b84a3a'))
    greek(c, 5, 28, 23, SMALL_PRINT, random.Random(seed))
    greek(c, 5, 28, 25, SMALL_PRINT, random.Random(seed + 1))
    tabs_y0 = y1 - 3
    for k in range(7):                                                    # the tear-off tabs
        tx = x0 + 1 + k * 4
        if k in (2, 5):
            continue
        prect(c, tx, tabs_y0, tx + 2, y1, paper)
        c.vline(tx + 3, tabs_y0, y1, shade(paper, 0.8))
        px(c, tx + 1, tabs_y0 + 1, hexc('7a766c'))
    for x in range(x0, x1 + 1):
        px(c, x, y1 + 1, hexc('000000', 0))
    tape(c, x0 + 12, y0 - 1, 7, 3, 0)
    return c


def cat_silhouette(c, cx, base, col=hexc('18181c'), eye=hexc('9ad84a')):
    """A black cat sitting, seen from the front (13 wide, 11 tall)."""
    c.ellipse(cx, base - 3, 4.2, 3.4, col)                              # the body
    c.ellipse(cx, base - 7, 3.0, 2.6, col)                              # the head
    c.poly([(cx - 3, base - 8), (cx - 3, base - 11), (cx - 1, base - 9)], col)   # ears
    c.poly([(cx + 3, base - 8), (cx + 3, base - 11), (cx + 1, base - 9)], col)
    for k in range(5):                                                  # the tail curling up the right
        px(c, cx + 5 + (k // 3), base - k, col)
        px(c, cx + 4 + (k // 3), base - k, col)
    px(c, cx - 1, base - 7, eye); px(c, cx + 1, base - 7, eye)


def n_lost_cat(seed=81):
    """A LOST CAT flyer (34 x 29): a yellow banner, the black cat, REWARD, tabs."""
    c = _canvas(34, 29, seed)
    x0, y0, x1, y1 = 1, 2, 32, 27
    paper = hexc('f1ecdc')
    sheet(c, x0, y0, x1, y1 - 4, paper, seed, fold=None, curl='br')
    prect(c, x0 + 1, y0 + 1, x1 - 1, y0 + 7, hexc('d8a838'))
    centred(c, 17, y0 + 2, 'LOST CAT', hexc('26262a'))
    prect(c, 8, 11, 26, 22, hexc('e4dcc0'))
    cat_silhouette(c, 17, 22)
    greek(c, 5, 28, 24, SMALL_PRINT, random.Random(seed))
    tabs_y0 = y1 - 3
    for k in range(7):
        tx = x0 + 1 + k * 4
        if k in (1, 4, 6):
            continue
        prect(c, tx, tabs_y0, tx + 2, y1, paper)
        c.vline(tx + 3, tabs_y0, y1, shade(paper, 0.8))
        px(c, tx + 1, tabs_y0 + 1, hexc('7a766c'))
    tape(c, x0 + 12, y0 - 1, 7, 3, 0)
    return c


def n_kid_drawing(seed=64):
    """A child's crayon picture taped up: a sun with rays, a house, two stick people, a wobbly grass line."""
    c = _canvas(28, 24, seed)
    x0, y0, x1, y1 = 1, 2, 26, 21
    sheet(c, x0, y0, x1, y1, hexc('f6f3ea'), seed, fold=None, curl='br', grain=0.02)
    for x in range(x0 + 1, x1):                                            # sky smudge
        for y in range(y0 + 1, y0 + 4):
            if (x + y) % 2 == 0:
                px(c, x, y, hexc('b8d4ec'))
    c.ellipse(21, 7, 2.2, 2.2, hexc('f0c430'))                             # the sun, rays all round
    for (dx, dy) in ((-4, 0), (4, 0), (0, -4), (0, 4), (-3, -3), (3, -3), (-3, 3), (3, 3)):
        px(c, 21 + dx, 7 + dy, hexc('f0c430'))
    prect(c, 6, 12, 14, 18, hexc('d44a3a'))                                # the house
    c.poly([(5, 12), (10, 7), (15, 12)], hexc('6a4a8a'))
    prect(c, 9, 15, 11, 18, hexc('6a4a2a'))
    prect(c, 12, 13, 13, 14, hexc('5a9ad4'))
    for x in range(x0 + 1, x1):                                            # grass, wobbly
        px(c, x, 19 + (1 if (x // 3) % 2 else 0), hexc('4aa04a'))
        px(c, x, 20, hexc('3a8a3a'))
    for fx, col in ((18, hexc('2a58b8')), (23, hexc('c83a8a'))):           # two stick people
        c.ellipse(fx, 13, 1.2, 1.2, hexc('222222'))
        c.vline(fx, 14, 17, col)
        c.line(fx - 2, 15, fx + 2, 15, col)
        c.line(fx, 17, fx - 1, 19, col); c.line(fx, 17, fx + 1, 19, col)
    tape(c, x0 + 1, y0 - 1, 5, 3, 1)
    tape(c, x1 - 5, y0 - 1, 5, 3, -1)
    return c


# --------------------------------------------------------------------------------------------
# FRAMES — a frame's OUTER rect is what you give it; it returns the inner rect for the picture.
# --------------------------------------------------------------------------------------------
WOOD = {'oak': (hexc('b08a52'), hexc('8a6a3a'), hexc('d8b078')), 'walnut': (hexc('5a3a26'), hexc('3e2618'), hexc('7a5238')),
        'pine': (hexc('c8a66a'), hexc('a08048'), hexc('e6c88c')), 'white': (hexc('e8e4da'), hexc('b8b4a8'), hexc('f8f6f0')),
        'black': (hexc('26262c'), hexc('121216'), hexc('46464e')), 'gilt': (hexc('c8a040'), hexc('8a6a1e'), hexc('f0d070'))}


def frame(c, x0, y0, x1, y1, kind='oak', mat=None, glass=True, thick=2, hang=None, lip=True, matw=2):
    """A picture frame round the OUTER rect (x0,y0)-(x1,y1): a drop shadow, a bevelled moulding (lit on top and
    left, shaded below and right), a dark lip against the picture and optionally a MAT (a card border, colour
    `mat`). `glass` lays two soft diagonal glints over the picture. `hang`: 'wire' (a triangle of cord to a
    nail above) / None. Returns the inner (picture) rect."""
    mid, dk, lt = WOOD[kind]
    for x in range(x0 + 1, x1 + 2):
        px(c, x, y1 + 1, hexc('000000', 60))
    for y in range(y0 + 1, y1 + 2):
        px(c, x1 + 1, y, hexc('000000', 46))
    prect(c, x0, y0, x1, y1, dk)                                              # the outer edge
    for t in range(1, thick + 1):                                              # the moulding
        far = mid if thick == 1 else (dk if t == thick else shade(mid, 0.82))
        for x in range(x0 + t, x1 - t + 1):
            px(c, x, y0 + t, lt if t == 1 else mid)
            px(c, x, y1 - t, far)
        for y in range(y0 + t, y1 - t + 1):
            px(c, x0 + t, y, lt if t == 1 else mid)
            px(c, x1 - t, y, far)
    ix0, iy0, ix1, iy1 = x0 + thick + 1, y0 + thick + 1, x1 - thick - 1, y1 - thick - 1
    if lip:
        prect(c, ix0, iy0, ix1, iy1, dk)                                      # the lip / rebate
        ix0, iy0, ix1, iy1 = ix0 + 1, iy0 + 1, ix1 - 1, iy1 - 1
    if mat is not None:
        prect(c, ix0, iy0, ix1, iy1, mat)
        for x in range(ix0, ix1 + 1):
            px(c, x, iy0, shade(mat, 0.9))
        ix0, iy0, ix1, iy1 = ix0 + matw, iy0 + matw, ix1 - matw, iy1 - matw
        for x in range(ix0 - 1, ix1 + 2):                                      # the bevel cut of the mat window
            px(c, x, iy0 - 1, shade(mat, 0.8))
    if hang == 'wire':
        mx = (x0 + x1) // 2
        c.line(x0 + 3, y0, mx, y0 - 5, hexc('4a3e30'))
        c.line(x1 - 3, y0, mx, y0 - 5, hexc('4a3e30'))
        nail(c, mx, y0 - 6)
    return (ix0, iy0, ix1, iy1)


def kind_for(col):
    """Which moulding a frame colour asked for: gold -> gilt, near-black -> black, pale -> white, brown -> walnut / oak."""
    r, g, b = col[0], col[1], col[2]
    lum = (r + g + b) / 3.0
    if r > 150 and g > 110 and b < 110 and r - b > 60:
        return 'gilt'
    if lum < 60:
        return 'black'
    if lum > 190:
        return 'white'
    if lum < 110:
        return 'walnut'
    return 'oak'


def glint(c, r, strength=46):
    """Two soft diagonal glints of window light across a glazed picture."""
    ix0, iy0, ix1, iy1 = r
    w = ix1 - ix0
    for k, (off, ln) in enumerate(((w // 3, 6), (w // 3 + 3, 3))):
        for j in range(ln):
            x, y = ix0 + off - j, iy0 + 1 + j
            if ix0 <= x <= ix1 and iy0 <= y <= iy1:
                px(c, x, y, hexc('ffffff', strength))


def poster_paper(c, x0, y0, x1, y1, border=hexc('efebde'), bw=1, fix='pins', seed=1, curl=None):
    """Printed poster paper: a white margin round the picture, a drop shadow, and how it's held up — 'pins' (a
    coloured pushpin at each corner), 'tape' (two strips on the top corners), 'tack' (blobs of blu-tack).
    Returns the inner (picture) rect."""
    sheet(c, x0, y0, x1, y1, border, seed, fold=None, curl=curl, grain=0.0, edge=True)
    ix0, iy0, ix1, iy1 = x0 + bw, y0 + bw, x1 - bw, y1 - bw
    if fix == 'pins':
        cols = (hexc('c0453a'), hexc('3a78b8'), hexc('e8c43c'), hexc('4a9a5a'))
        for k, (px_, py_) in enumerate(((x0, y0), (x1 - 1, y0), (x0, y1 - 1), (x1 - 1, y1 - 1))):
            pushpin(c, px_, py_, cols[(k + seed) % 4])
    elif fix == 'tape':
        tape(c, x0 - 2, y0 - 1, 6, 3, 1)
        tape(c, x1 - 3, y0 - 1, 6, 3, -1)
    else:                                                                       # blu-tack
        for (tx, ty) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            px(c, tx, ty, hexc('8aa6c8'))
            px(c, tx + (1 if tx == x0 else -1), ty, hexc('6a86a8'))
            px(c, tx, ty + (1 if ty == y0 else -1), hexc('6a86a8'))
    return (ix0, iy0, ix1, iy1)


# --------------------------------------------------------------------------------------------
# THE PICTURES — image posters, no words (owner round 38). Each draws into an inner rect r = (x0, y0, x1, y1).
# --------------------------------------------------------------------------------------------
def _vgrad(c, r, stops, bands=6, dither=True):
    """A vertical gradient through `stops` [(t, colour)…] quantised to `bands` steps with a checker dither
    between neighbouring steps (pixel-art sky)."""
    x0, y0, x1, y1 = r
    h = max(1, y1 - y0)

    def at(t):
        t = max(0.0, min(1.0, t))
        for i in range(len(stops) - 1):
            (ta, ca), (tb, cb) = stops[i], stops[i + 1]
            if t <= tb:
                f = 0.0 if tb == ta else (t - ta) / (tb - ta)
                return mix(ca, cb, f)
        return stops[-1][1]
    for y in range(y0, y1 + 1):
        t = (y - y0) / float(h)
        q = t * bands
        lo = int(q) / float(bands)
        hi = min(1.0, (int(q) + 1) / float(bands))
        frac = q - int(q)
        for x in range(x0, x1 + 1):
            use_hi = dither and frac > 0.5 and (x + y) % 2 == 0 or frac > 0.82
            px(c, x, y, at(hi if use_hi else lo))


def _paint(c, r, fn, *a, **k):
    """Draw a picture function into a scratch canvas the size of rect r and copy it in — so nothing it draws
    (a palm frond, a shadow) can spill outside its poster."""
    x0, y0, x1, y1 = r
    tc = Canvas(w=x1 - x0 + 1, h=y1 - y0 + 1, seed=1)
    fn(tc, (0, 0, x1 - x0, y1 - y0), *a, **k)
    for y in range(tc.h):
        for x in range(tc.w):
            p = tc.px[x, y]
            if p[3]:
                px(c, x0 + x, y0 + y, p)


def _inside_rect(r, x, y):
    return r[0] <= x <= r[2] and r[1] <= y <= r[3]


def _sunburst(c, r, cx, cy, bg_a, bg_b, rays=14, vignette=True):
    x0, y0, x1, y1 = r
    w, h = x1 - x0 + 1, y1 - y0 + 1
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            ang = math.atan2(y - cy, x - cx)
            k = int((ang + math.pi) / (2 * math.pi) * rays * 2 + 0.5)
            col = bg_a if k % 2 == 0 else bg_b
            if vignette:
                d = math.hypot((x - cx) / (w * 0.72), (y - cy) / (h * 0.72))
                if d > 0.8:
                    col = shade(col, 0.84 if d < 0.97 else 0.72)
            px(c, x, y, col)


def img_guitar(c, r, bg_a=hexc('f0b43c'), bg_b=hexc('e0662c'), body=hexc('c8322a'), seed=1, credits=True):
    """A rock poster: a sunburst and ONE clear electric guitar standing upright in the middle — a double-cutaway body
    with a white pickguard, two pickups, a bridge and a knob, a long neck with frets and a string, a headstock with its
    tuners — over a band of tour dates. (Round 38b: the slanting guitar + lightning bolt read as a Pikachu tail.)"""
    x0, y0, x1, y1 = r
    w, h = x1 - x0 + 1, y1 - y0 + 1
    foot = 4 if credits and h >= 22 else 0
    ph = h - foot
    cx = x0 + (w - 1) / 2.0
    _sunburst(c, (x0, y0, x1, y0 + ph - 1), cx, y0 + ph * 0.6, bg_a, bg_b)
    kx = int(round(cx))
    top = y0 + 1
    bot = y0 + ph - 2
    L = bot - top
    hw = max(4.0, w * 0.27)                                             # body half width
    body_top = top + L * 0.46
    body_h = bot - body_top

    def shape(x, y):
        dx = x - cx
        if y < top:
            return None
        if y <= top + L * 0.16 and abs(dx) <= 2.3:
            return 'head'
        if top + L * 0.16 < y < body_top + 2 and abs(dx) <= 1.9:
            return 'neck'
        if y >= body_top:
            t = (y - body_top) / max(1.0, body_h)                        # 0 at the top of the body .. 1 at the foot
            if t < 0.3:                                                  # the horns: two lobes either side of the neck
                for sgn in (-1, 1):
                    if (dx - sgn * hw * 0.55) ** 2 / (hw * 0.38) ** 2 + (t - 0.22) ** 2 / 0.22 ** 2 <= 1.0:
                        return 'body'
                if t > 0.12 and abs(dx) <= hw * 0.7:
                    return 'body'
                return None
            if t < 0.55:                                                 # the waist
                half = hw * (0.7 + (t - 0.3) / 0.25 * 0.3)
            else:                                                        # the lower bout, rounding off at the foot
                u = (t - 0.55) / 0.45
                half = hw * math.sqrt(max(0.0, 1.0 - u * u * 0.85))
            return 'body' if abs(dx) <= half else None
        return None
    mask = {}
    for y in range(y0, y0 + ph):
        for x in range(x0, x1 + 1):
            m = shape(x, y)
            if m:
                mask[(x, y)] = m
    for (x, y) in list(mask):                                            # a hard drop shadow down-right
        if (x + 2, y + 1) not in mask and x0 <= x + 2 <= x1 and y + 1 < y0 + ph:
            px(c, x + 2, y + 1, hexc('3a1a14', 140))
    for (x, y), m in mask.items():
        dx = x - cx
        if m == 'body':
            col = body
            if dx < -hw * 0.45:
                col = shade(body, 1.22)
            elif dx > hw * 0.5:
                col = shade(body, 0.7)
            px(c, x, y, col)
        elif m == 'neck':
            px(c, x, y, hexc('7a5230'))
            if (y - top) % 3 == 0:
                px(c, x, y, hexc('c8c4b8'))                                # frets
        else:
            px(c, x, y, hexc('4a3220'))
    # pickguard, two pickups, a bridge and a knob — few and large, so it reads at this size
    for (x, y), m in mask.items():
        if m == 'body':
            t = (y - body_top) / max(1.0, body_h)
            if 0.42 <= t <= 0.88 and abs(x - cx) <= hw * 0.62 and (x - cx) > -hw * 0.5:
                px(c, x, y, hexc('efebe0') if (x - cx) < hw * 0.35 else hexc('c4c0b4'))
    for t in (0.5, 0.66):
        yy = int(round(body_top + body_h * t))
        c.hline(kx - int(hw * 0.4), kx + int(hw * 0.4), yy, hexc('18181c'))
        c.hline(kx - int(hw * 0.4), kx + int(hw * 0.4), yy + 1, hexc('4a4a52'))
    yb = int(round(body_top + body_h * 0.84))
    c.hline(kx - int(hw * 0.45), kx + int(hw * 0.45), yb, hexc('d8d4c8'))
    c.put(kx + int(hw * 0.55), yb - 3, hexc('d8d4c8')); c.put(kx + int(hw * 0.55), yb - 5, hexc('d8d4c8'))
    c.vline(kx, int(top + L * 0.16) + 1, int(body_top + body_h * 0.5), hexc('e8e4d8'))      # the string down the neck
    for (x, y) in list(mask):                                                  # the outline
        if any((x + dx2, y + dy2) not in mask for (dx2, dy2) in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            px(c, x, y, hexc('1a1214'))
    for sgn in (-1, 1):                                                        # tuners poking from the headstock
        for k in range(2):
            px(c, kx + sgn * 4, top + 1 + k * 3, hexc('d8d4c8'))
            px(c, kx + sgn * 3, top + 1 + k * 3, hexc('d8d4c8'))
    if foot:
        prect(c, x0, y1 - foot + 1, x1, y1, hexc('1a1a1e'))
        greek(c, x0 + 2, x1 - 2, y1 - 2, hexc('e8e2d0'), random.Random(seed), 1)
        px(c, x0 + 1, y1 - 3, hexc('d8322a'))


def img_record(c, r, bg_a=hexc('e8508a'), bg_b=hexc('7a2a6a'), seed=1, credits=True):
    """A music poster: a sunburst and a vinyl record — grooved black disc, a sheen, an orange centre label — with the
    tonearm's needle coming down onto it, over a band of tour dates."""
    x0, y0, x1, y1 = r
    w, h = x1 - x0 + 1, y1 - y0 + 1
    foot = 4 if credits and h >= 22 else 0
    ph = h - foot
    cx, cy = x0 + (w - 1) / 2.0, y0 + ph * 0.52
    _sunburst(c, (x0, y0, x1, y0 + ph - 1), cx, cy, bg_a, bg_b, 12)
    rad = min(w * 0.42, ph * 0.44)
    for y in range(int(cy - rad) - 1, int(cy + rad) + 3):
        for x in range(int(cx - rad) - 1, int(cx + rad) + 3):
            d = math.hypot(x - cx, y - cy)
            if x - 2 >= x0 and x - 2 <= x1 and y - 1 < y0 + ph and math.hypot(x - 2 - cx, y - 1 - cy) <= rad and d > rad:
                px(c, x, y, hexc('3a1a30', 130))                                  # the disc's shadow
    for y in range(y0, y0 + ph):
        for x in range(x0, x1 + 1):
            d = math.hypot(x - cx, y - cy)
            if d <= rad:
                col = hexc('16141a')
                if d > rad * 0.42 and int(d) % 3 == 0:
                    col = hexc('26242c')                                          # the grooves
                ang = math.degrees(math.atan2(y - cy, x - cx)) % 180
                if rad * 0.45 < d < rad * 0.96 and (ang < 24 or 90 < ang < 114):
                    col = hexc('3a3844')                                          # the sheen
                if d < rad * 0.4:
                    col = hexc('e0702c') if d > rad * 0.12 else hexc('16141a')
                    if rad * 0.26 < d < rad * 0.31:
                        col = hexc('f4c050')
                px(c, x, y, col)
    for y in range(y0, y0 + ph):                                                  # the edge
        for x in range(x0, x1 + 1):
            if rad - 0.9 <= math.hypot(x - cx, y - cy) <= rad:
                px(c, x, y, hexc('0a0a0e'))
    ax, ay = x1 - 3, y0 + 2                                                       # the tonearm
    c.line(ax, ay, int(cx + rad * 0.45), int(cy - rad * 0.2), hexc('d8d4c8'))
    c.line(ax + 1, ay, int(cx + rad * 0.45) + 1, int(cy - rad * 0.2), hexc('8a867a'))
    c.rect(int(cx + rad * 0.45) - 1, int(cy - rad * 0.2) - 1, int(cx + rad * 0.45) + 1, int(cy - rad * 0.2) + 1, hexc('2a2a2e'))
    c.ellipse(ax, ay, 2, 2, hexc('b8b4a8'))
    if foot:
        prect(c, x0, y1 - foot + 1, x1, y1, hexc('1a1a1e'))
        greek(c, x0 + 2, x1 - 2, y1 - 2, hexc('e8e2d0'), random.Random(seed + 2), 1)
        px(c, x0 + 1, y1 - 3, hexc('e8508a'))


def img_horror(c, r, seed=1, credits=True):
    """A horror film one-sheet: a bruised sky, a moon, a house on a hill with two lit windows, a bare tree,
    bats, and blood running down from the top edge."""
    x0, y0, x1, y1 = r
    w, h = x1 - x0 + 1, y1 - y0 + 1
    foot = 4 if credits and h >= 24 else 0
    sky = (x0, y0, x1, y1 - foot)
    _vgrad(c, sky, [(0.0, hexc('140f2a')), (0.55, hexc('4a1c46')), (1.0, hexc('c4502e'))], 6)
    mx, my, mr = x0 + w * 0.64, y0 + h * 0.30, w * 0.24
    for y in range(int(my - mr - 3), int(my + mr + 4)):                         # the moon with a halo ring
        for x in range(int(mx - mr - 3), int(mx + mr + 4)):
            d = math.hypot(x - mx, y - my)
            if d <= mr:
                col = hexc('f4ecc0') if d < mr * 0.82 else hexc('d8cc98')
                if ((x - mx + 3) ** 2 + (y - my - 2) ** 2) < (mr * 0.2) ** 2 or ((x - mx - 4) ** 2 + (y - my + 3) ** 2) < (mr * 0.13) ** 2:
                    col = hexc('c4b880')                                        # craters
                px(c, x, y, col)
            elif d <= mr + 2 and (x + y) % 2 == 0:
                px(c, x, y, hexc('7a4a6a'))
    base = y1 - foot
    hill_top = base - h * 0.28
    for x in range(x0, x1 + 1):                                                 # the hill
        yy = int(hill_top + 3.5 * math.sin((x - x0) / (w * 0.35) + 0.6))
        c.vline(x, yy, base, hexc('0c0a14'))
    hx0, hx1 = int(x0 + w * 0.40), int(x0 + w * 0.82)                           # the house
    hb = int(hill_top + 3)
    house = hexc('0c0a14')
    prect(c, hx0, hb - int(h * 0.20), hx1, hb, house)
    c.poly([(hx0 - 2, hb - int(h * 0.20)), ((hx0 + hx1) // 2, hb - int(h * 0.40)), (hx1 + 2, hb - int(h * 0.20))], house)
    prect(c, hx1 - 4, hb - int(h * 0.46), hx1 - 1, hb - int(h * 0.2), house)    # a tower
    c.poly([(hx1 - 5, hb - int(h * 0.46)), (hx1 - 2, hb - int(h * 0.56)), (hx1 + 1, hb - int(h * 0.46))], house)
    for (wx, wy) in ((hx0 + 3, hb - int(h * 0.15)), (hx0 + 10, hb - int(h * 0.15)), (hx1 - 3, hb - int(h * 0.35))):
        prect(c, wx, wy, wx + 1, wy + 2, hexc('f4c84a'))
    tx = int(x0 + w * 0.16)                                                      # a bare tree
    c.vline(tx, hb - 9, hb, house)
    for (dx, dy) in ((-4, -9), (4, -8), (-3, -5), (3, -4), (0, -12)):
        c.line(tx, hb - 6, tx + dx, hb + dy, house)
    for (bx, by) in ((x0 + int(w * 0.18), y0 + int(h * 0.22)), (x0 + int(w * 0.34), y0 + int(h * 0.12)),
                     (x0 + int(w * 0.28), y0 + int(h * 0.36))):                  # bats
        c.put(bx - 2, by, hexc('0c0a14')); c.put(bx + 2, by, hexc('0c0a14'))
        c.put(bx - 1, by + 1, hexc('0c0a14')); c.put(bx + 1, by + 1, hexc('0c0a14')); c.put(bx, by, hexc('0c0a14'))
    for x in range(x0, x1 + 1):                                                  # fog low on the hill
        for y in (base - 4, base - 5):
            if (x + y) % 2 == 0:
                px(c, x, y, hexc('8a6a8a', 140))
    rng = random.Random(seed)
    for dx in (0.12, 0.38, 0.55, 0.86):                                          # blood from the top edge
        xx = x0 + int(w * dx)
        ln = rng.randint(3, 8)
        c.vline(xx, y0, y0 + ln, hexc('a8241e'))
        c.vline(xx + 1, y0, y0 + ln - 2, hexc('c43a2a'))
        px(c, xx, y0 + ln + 1, hexc('a8241e'))
    c.hline(x0, x1, y0, hexc('a8241e'))
    if foot:
        prect(c, x0, y1 - foot + 1, x1, y1, hexc('0c0a14'))
        greek(c, x0 + 2, x1 - 2, y1 - 2, hexc('b8b0a0'), random.Random(seed + 3), 1)
        px(c, x0 + 1, y1 - 3, hexc('d8322a'))


def img_space(c, r, seed=1):
    """A space poster: a nebula, stars, a ringed planet lit from the upper left, a little rocket, a moon."""
    x0, y0, x1, y1 = r
    w, h = x1 - x0 + 1, y1 - y0 + 1
    rng = random.Random(seed)
    _vgrad(c, r, [(0.0, hexc('0c0c22')), (0.5, hexc('1c1240')), (1.0, hexc('3a1650'))], 5)
    for y in range(y0, y1 + 1):                                                  # the nebula: dithered clouds
        for x in range(x0, x1 + 1):
            v = (math.sin(x * 0.21 + 1.3) + math.sin(y * 0.29 - 0.4) + math.sin((x + y) * 0.13) + math.sin((x - 1.7 * y) * 0.17)) / 4
            if v > 0.28 and (x + y) % 2 == 0:
                px(c, x, y, hexc('6a2a7a'))
            if v > 0.52:
                px(c, x, y, hexc('8a3a8a') if (x + y) % 2 else hexc('6a2a7a'))
            if v < -0.5 and (x * 3 + y) % 4 == 0:
                px(c, x, y, hexc('1e4a6a'))
    for k in range(int(w * h / 38)):                                             # stars
        sx, sy = rng.randint(x0, x1), rng.randint(y0, y1)
        col = rng.choice((hexc('f0f0ff'), hexc('c8d4ff'), hexc('ffe8c8')))
        px(c, sx, sy, col)
        if rng.random() < 0.12:                                                  # a twinkle
            for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                px(c, sx + dx, sy + dy, hexc('a8b4e8'))
    pr = max(4, int(min(w, h) * 0.22))
    pcx, pcy = x0 + int(w * 0.36), y0 + int(h * 0.66)
    tilt = math.radians(-18)

    def ring_val(x, y):                                                           # >0 inside the ring band, sign = in front?
        dx, dy = x - pcx, y - pcy
        rx = dx * math.cos(tilt) - dy * math.sin(tilt)
        ry = dx * math.sin(tilt) + dy * math.cos(tilt)
        e = math.hypot(rx / (pr * 1.85), ry / (pr * 0.5))
        return e, ry
    for y in range(y0, y1 + 1):                                                   # the ring's far half
        for x in range(x0, x1 + 1):
            e, ry = ring_val(x, y)
            if 0.72 <= e <= 1.0 and ry < 0:
                px(c, x, y, hexc('c8a070') if e > 0.86 else hexc('a07a50'))
    tones = [hexc('5a2418'), hexc('a8502a'), hexc('dc8a3c'), hexc('f4c878')]
    for y in range(pcy - pr, pcy + pr + 1):                                       # the planet
        for x in range(pcx - pr, pcx + pr + 1):
            dx, dy = (x - pcx) / float(pr), (y - pcy) / float(pr)
            d2 = dx * dx + dy * dy
            if d2 > 1.0:
                continue
            nz = math.sqrt(1 - d2)
            lum = max(0.0, -0.55 * dx - 0.6 * dy + 0.58 * nz)
            band = 0.1 * math.sin(dy * 9.0 + dx * 1.5)
            tone = min(3, max(0, int((lum + band) * 3.2)))
            px(c, x, y, tones[tone])
    for y in range(y0, y1 + 1):                                                   # the ring's near half
        for x in range(x0, x1 + 1):
            e, ry = ring_val(x, y)
            if 0.72 <= e <= 1.0 and ry >= 0:
                px(c, x, y, hexc('e0bc88') if e > 0.86 else hexc('b88a58'))
    mx, my = x0 + int(w * 0.86), y0 + int(h * 0.82)                               # a moon
    c.ellipse(mx, my, 2.6, 2.6, hexc('b8b4c8'))
    px(c, mx - 1, my - 1, hexc('e8e4f4')); px(c, mx + 1, my + 1, hexc('8a86a0'))
    rx, ry = x0 + int(w * 0.74), y0 + int(h * 0.24)                               # the rocket, nose up-right
    for k in range(4):
        px(c, rx - 2 - k, ry + 2 + k, hexc('f0a02c') if k % 2 == 0 else hexc('e0602c'))
        px(c, rx - 3 - k, ry + 2 + k, hexc('e0602c', 160))
    c.line(rx - 1, ry + 1, rx + 3, ry - 3, hexc('e8ecf4'))
    c.line(rx, ry + 2, rx + 4, ry - 2, hexc('e8ecf4'))
    c.line(rx + 1, ry + 1, rx + 4, ry - 2, hexc('c8ccd8'))
    px(c, rx + 4, ry - 3, hexc('d83a2a')); px(c, rx + 5, ry - 4, hexc('d83a2a'))
    px(c, rx, ry + 3, hexc('c8322a')); px(c, rx - 2, ry + 1, hexc('c8322a'))
    px(c, rx + 1, ry, hexc('4a8ac8'))


_CONTINENTS = [
    [(0.05, 0.20), (0.14, 0.10), (0.27, 0.10), (0.32, 0.21), (0.27, 0.31), (0.22, 0.41), (0.18, 0.45), (0.15, 0.34), (0.08, 0.28)],
    [(0.31, 0.07), (0.38, 0.06), (0.37, 0.14), (0.32, 0.15)],
    [(0.20, 0.48), (0.28, 0.50), (0.32, 0.60), (0.27, 0.75), (0.23, 0.86), (0.21, 0.70), (0.19, 0.57)],
    [(0.45, 0.17), (0.52, 0.14), (0.57, 0.21), (0.50, 0.28), (0.45, 0.26)],
    [(0.46, 0.31), (0.55, 0.30), (0.61, 0.43), (0.56, 0.59), (0.51, 0.70), (0.48, 0.57), (0.44, 0.43)],
    [(0.58, 0.12), (0.71, 0.08), (0.88, 0.12), (0.93, 0.25), (0.85, 0.35), (0.77, 0.42), (0.69, 0.35), (0.63, 0.29), (0.58, 0.22)],
    [(0.80, 0.59), (0.90, 0.57), (0.94, 0.67), (0.86, 0.73), (0.80, 0.68)],
]


def img_map(c, r, seed=1, pins=((0.22, 0.30), (0.74, 0.40), (0.52, 0.52))):
    """A school wall map: pale sea, a graticule, the continents with a darker coast, three pins."""
    x0, y0, x1, y1 = r
    w, h = x1 - x0, y1 - y0
    prect(c, x0, y0, x1, y1, hexc('a8cce0'))
    for k in range(1, 6):
        c.vline(x0 + w * k // 6, y0, y1, hexc('bcdcec'))
    for k in range(1, 4):
        c.hline(x0, x1, y0 + h * k // 4, hexc('bcdcec'))
    for i, poly in enumerate(_CONTINENTS):
        pts = [(x0 + int(px_ * w), y0 + int(py_ * h)) for (px_, py_) in poly]
        c.poly(pts, hexc('b4a868') if i % 2 else hexc('8aa860'))
        for j in range(len(pts)):
            a, b = pts[j], pts[(j + 1) % len(pts)]
            c.line(a[0], a[1], b[0], b[1], hexc('6a7a44'))
    for k, (fx, fy) in enumerate(pins):
        pushpin(c, x0 + int(fx * w), y0 + int(fy * h), (hexc('d83a2a'), hexc('e8c43c'), hexc('3a78b8'))[k % 3])


def img_travel(c, r, seed=1):
    """A holiday poster: a sunset in bands, the sun sinking into the sea with its reflection, a palm leaning in from
    the left and a sail — every part sized to the poster and kept INSIDE it (round 38b: the palm ran out of its frame)."""
    x0, y0, x1, y1 = r
    w, h = x1 - x0 + 1, y1 - y0 + 1
    hz = y0 + int(h * 0.62)
    _vgrad(c, (x0, y0, x1, hz), [(0.0, hexc('5a3a7a')), (0.35, hexc('c4607a')), (0.7, hexc('f09a3a')), (1.0, hexc('f8d060'))], 5)
    sx, sy, sr = x0 + w * 0.56, hz, max(2.5, w * 0.2)
    for y in range(int(sy - sr), hz + 1):
        for x in range(int(sx - sr), int(sx + sr) + 1):
            if x0 <= x <= x1 and math.hypot(x - sx, y - sy) <= sr:
                px(c, x, y, hexc('fff0a0') if math.hypot(x - sx, y - sy) < sr * 0.7 else hexc('fcd860'))
    _vgrad(c, (x0, hz + 1, x1, y1), [(0.0, hexc('c8606a')), (0.4, hexc('6a3a7a')), (1.0, hexc('2a2050'))], 4)
    for k, yy in enumerate(range(hz + 1, y1, 2)):                                   # the sun on the water
        half = max(1, int(sr * 0.8 * (1.0 - (yy - hz) / float(y1 - hz + 2))))
        if k % 2 == 0:
            c.hline(max(x0, int(sx) - half), min(x1, int(sx) + half), yy, hexc('f8d060'))
    palm = hexc('10241a')
    palm_lt = hexc('1f4a30')
    fl = max(4, int(w * 0.26))                                                      # frond length, so the crown fits
    tx = x0 + fl + 1                                                                # the trunk's foot
    th = int(h * 0.52)
    top_x, top_y = tx + max(1, th // 4), y1 - th
    for k in range(th + 1):                                                         # the trunk, bowing right
        t = k / float(max(1, th))
        xx = tx + int(round((top_x - tx) * (t ** 1.6)))
        thick = 2 if th > 12 and k < th * 0.7 else 1
        for q in range(thick):
            px(c, xx + q, y1 - k, palm)
        if k % 3 == 1 and thick == 2:
            px(c, xx + 1, y1 - k, palm_lt)                                            # the rings
    for ang, ln in ((-168, 1.0), (-132, 0.95), (-96, 0.7), (-50, 0.95), (-14, 1.0), (24, 0.8), (156, 0.8)):
        a_ = math.radians(ang)
        n = int(fl * ln * 2.2)
        for i in range(n + 1):
            t = i / float(max(1, n))
            fx = top_x + math.cos(a_) * fl * ln * t
            fy = top_y + math.sin(a_) * fl * ln * t * 0.7 + fl * 0.9 * t * t        # a frond arches out then droops
            ex, ey = int(round(fx)), int(round(fy))
            if x0 <= ex <= x1 and y0 <= ey <= y1:
                px(c, ex, ey, palm)
                if t < 0.6 and y0 <= ey + 1 <= y1:
                    px(c, ex, ey + 1, palm_lt if i % 3 == 0 else palm)
    c.ellipse(top_x, top_y + 1, 1, 1, hexc('3a2412'))                                # coconuts
    bx, by = x0 + int(w * 0.8), hz + 3                                              # a sail on the horizon
    if bx + 4 <= x1:
        c.poly([(bx, by - 5), (bx, by), (bx + 3, by)], hexc('1a1230'))
        c.hline(bx - 1, min(x1, bx + 4), by + 1, hexc('1a1230'))


def img_rainbow(c, r, seed=1):
    """A child's poster: a rainbow arch standing on two clouds, a smiling sun, little stars."""
    x0, y0, x1, y1 = r
    w, h = x1 - x0 + 1, y1 - y0 + 1
    _vgrad(c, r, [(0.0, hexc('8ac4ec')), (1.0, hexc('d8ecf8'))], 4)
    cx, cy = x0 + w // 2, y0 + int(h * 0.80)
    outer = w * 0.44
    cols = (hexc('d8402c'), hexc('f08a2c'), hexc('f4d43c'), hexc('5aaa44'), hexc('3a8ad0'), hexc('6a4ab0'))
    band = max(1.4, outer * 0.12)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            d = math.hypot(x - cx, (y - cy) * 1.05)
            if y <= cy and outer - band * len(cols) <= d <= outer:
                k = min(len(cols) - 1, int((outer - d) / band))
                px(c, x, y, cols[k])
    for (ccx, ccy) in ((cx - int(outer - band * 3), cy), (cx + int(outer - band * 3), cy)):   # the clouds at the feet
        for (dx, dy, rr) in ((-4, 0, 3.4), (0, -1, 4.2), (4, 0, 3.4), (-1, 1, 3.2), (3, 1, 3.0)):
            c.ellipse(ccx + dx, ccy + dy, rr, rr * 0.8, hexc('f6f8fc'))
    sx, sy = x0 + int(w * 0.84), y0 + int(h * 0.16)                                  # the sun
    c.ellipse(sx, sy, 3.2, 3.2, hexc('f8d43c'))
    for (dx, dy) in ((-5, 0), (5, 0), (0, -5), (0, 5), (-4, -4), (4, -4), (-4, 4), (4, 4)):
        px(c, sx + dx, sy + dy, hexc('f8d43c'))
    px(c, sx - 1, sy - 1, hexc('3a2a1a')); px(c, sx + 1, sy - 1, hexc('3a2a1a'))
    c.hline(sx - 1, sx + 1, sy + 1, hexc('c8502a'))
    rng = random.Random(seed)
    for k in range(4):
        px(c, x0 + rng.randint(1, w // 3), y0 + rng.randint(1, h // 3), hexc('f8f0a0'))


def img_crayon(c, r, seed=1):
    """A child's crayon picture, drawn SYMMETRICALLY about its centre line and sized to its rect so nothing leaves it:
    a sun over a house with a door and two windows, a stick person each side holding hands with nobody, two flowers,
    a wobbly grass line."""
    x0, y0, x1, y1 = r
    w, h = x1 - x0 + 1, y1 - y0 + 1
    prect(c, x0, y0, x1, y1, hexc('f6f3ea'))
    mid = x0 + (w - 1) / 2.0
    cxi = int(round(mid))
    for x in range(x0, x1 + 1):                                                      # sky in blue crayon, scribbled
        for y in range(y0, y0 + max(2, h // 5)):
            if (x + y) % 2 == 0:
                px(c, x, y, hexc('b8d4ec'))
    gy = y1 - 1                                                                      # the grass line
    for x in range(x0, x1 + 1):
        px(c, x, gy + (0 if (x - x0) % 4 < 2 else -1), hexc('4aa04a'))
        px(c, x, y1, hexc('3a8a3a'))
    sun_y = y0 + max(3, h // 5)
    sr = max(1.6, h * 0.11)
    c.ellipse(cxi, sun_y, sr, sr, hexc('f0c430'))                                    # the sun, centred, rays all round
    ray = int(sr) + 2
    for (dx, dy) in ((-ray, 0), (ray, 0), (0, -ray), (-ray + 1, -ray + 1), (ray - 1, -ray + 1)):
        if x0 <= cxi + dx <= x1 and y0 <= sun_y + dy <= y1:
            px(c, cxi + dx, sun_y + dy, hexc('f0c430'))
    hw = max(3, int(w * 0.2))                                                        # the house, centred
    wall_top = gy - max(4, int(h * 0.34))
    prect(c, cxi - hw, wall_top, cxi + hw, gy - 1, hexc('d44a3a'))
    c.poly([(cxi - hw - 1, wall_top), (cxi, wall_top - max(3, hw)), (cxi + hw + 1, wall_top)], hexc('6a4a8a'))
    prect(c, cxi - 1, gy - 4, cxi, gy - 1, hexc('6a4a2a'))                           # the door
    for sgn in (-1, 1):                                                              # a window each side of it
        wx = cxi + sgn * (hw - 2) - (1 if sgn < 0 else 0)
        prect(c, wx, wall_top + 2, wx + 1, wall_top + 3, hexc('5a9ad4'))
    for sgn, col in ((-1, hexc('2a58b8')), (1, hexc('c83a8a'))):                    # a stick person each side, mirrored
        fx = cxi + sgn * int(round(w * 0.36))
        fx = min(x1 - 2, max(x0 + 2, fx))
        fh = max(5, int(h * 0.38))
        c.ellipse(fx, gy - fh - 1, 1.2, 1.2, hexc('222222'))
        c.vline(fx, gy - fh + 1, gy - 3, col)
        c.line(fx - 2, gy - fh + 3, fx + 2, gy - fh + 3, col)
        c.line(fx, gy - 3, fx - 1, gy - 1, col); c.line(fx, gy - 3, fx + 1, gy - 1, col)
    for sgn in (-1, 1):                                                              # a flower each side of the door
        fx = cxi + sgn * (hw + 3)
        if x0 + 1 <= fx <= x1 - 1:
            c.vline(fx, gy - 3, gy - 1, hexc('3a8a3a'))
            px(c, fx, gy - 4, hexc('e8508a'))


# --------------------------------------------------------------------------------------------
# THE PIECES YOU HANG — an outer rect in, a finished poster / framed picture out (same call shapes the room
# scripts used before; furn.py's poster_* helpers delegate here).
# --------------------------------------------------------------------------------------------
def poster_guitar(c, x0, y0, x1, y1, scheme='sun', fix='pins', seed=1, curl=None):
    pal = {'sun': (hexc('f0b43c'), hexc('e0662c'), hexc('c8322a')),
           'teal': (hexc('3a9aa0'), hexc('1e5a78'), hexc('e0a02c')),
           'night': (hexc('7a3a8a'), hexc('3a1a5a'), hexc('3ac8d8'))}[scheme]
    r = poster_paper(c, x0, y0, x1, y1, hexc('ede6d2'), 1, fix, seed, curl)
    _paint(c, r, img_guitar, pal[0], pal[1], pal[2], seed)


def poster_record(c, x0, y0, x1, y1, fix='pins', seed=1, curl=None):
    r = poster_paper(c, x0, y0, x1, y1, hexc('ede6d2'), 1, fix, seed, curl)
    _paint(c, r, img_record, hexc('e8508a'), hexc('7a2a6a'), seed)


def poster_horror(c, x0, y0, x1, y1, fix='pins', seed=1, torn=False):
    r = poster_paper(c, x0, y0, x1, y1, hexc('d8d0c0'), 1, fix, seed)
    _paint(c, r, img_horror, seed)
    if torn:                                                                       # the bottom corner torn off
        for j in range(6):
            for i in range(6 - j):
                px(c, x1 - i, y1 - j, hexc('d8d0c0') if i else hexc('b8b0a0'))


def poster_space(c, x0, y0, x1, y1, fix='pins', seed=1):
    r = poster_paper(c, x0, y0, x1, y1, hexc('e8e8f0'), 1, fix, seed)
    _paint(c, r, img_space, seed)


def poster_map(c, x0, y0, x1, y1, seed=1):
    """A roller map: a wooden rod top and bottom, a cord up to a nail, the map between."""
    rod, rod_dk = hexc('7a5a3a'), hexc('4a3220')
    mx = (x0 + x1) // 2
    c.line(x0 + 3, y0, mx, y0 - 5, hexc('4a3e30'))
    c.line(x1 - 3, y0, mx, y0 - 5, hexc('4a3e30'))
    nail(c, mx, y0 - 6)
    for x in range(x0 + 1, x1 + 3):
        px(c, x, y1 + 1, hexc('000000', 60))
    for yy in (y0, y1 - 1):                                                         # the two rods
        prect(c, x0 - 1, yy, x1 + 1, yy + 1, rod)
        prect(c, x0 - 1, yy + 1, x1 + 1, yy + 1, rod_dk)
        px(c, x0 - 2, yy, hexc('d8c8a0')); px(c, x0 - 2, yy + 1, hexc('a89868'))
        px(c, x1 + 2, yy, hexc('d8c8a0')); px(c, x1 + 2, yy + 1, hexc('a89868'))
    r = (x0, y0 + 2, x1, y1 - 2)
    prect(c, r[0], r[1], r[2], r[3], hexc('e8e0c8'))
    _paint(c, (r[0] + 1, r[1] + 1, r[2] - 1, r[3] - 1), img_map, seed)


def poster_travel(c, x0, y0, x1, y1, fix='tape', seed=1):
    r = poster_paper(c, x0, y0, x1, y1, hexc('f0e8d4'), 1, fix, seed)
    _paint(c, r, img_travel, seed)


def poster_rainbow(c, x0, y0, x1, y1, fix='tape', seed=1):
    r = poster_paper(c, x0, y0, x1, y1, hexc('fbf8ee'), 1, fix, seed)
    _paint(c, r, img_rainbow, seed)


def picture_crayon(c, x0, y0, x1, y1, kind='white'):
    """A child's crayon picture in a cheap white frame with a thin card mat."""
    r = frame(c, x0, y0, x1, y1, kind, mat=hexc('f4efe2'), glass=True, thick=1, hang='wire', matw=1)
    _paint(c, r, img_crayon)
    glint(c, r, 40)


# --------------------------------------------------------------------------------------------
# PAPER IN THE FLATS (note, sticky, newspaper, missing flyer, timetable) — same footprints the room art used,
# with real paper: grain, lit / shaded edges, a curl, a fold, a proper pin or tape.
# --------------------------------------------------------------------------------------------
def draw_note(c, x0, y0, lines, w, paper, ink, red, fix, seed=1):
    """A note with words (6 rows a line + 4). Returns (x0, y0, x1, y1)."""
    h = 6 * len(lines) + 4
    x1, y1 = x0 + w, y0 + h
    sheet(c, x0, y0, x1, y1, paper, seed + x0 + y0, fold='h' if len(lines) >= 3 else None,
          curl='br' if (x0 + y0) % 2 else 'bl')
    for i, t in enumerate(lines):
        col = red if t.endswith('!') else ink
        text(c, x0 + (w - width(t)) // 2 + 1, y0 + 3 + 6 * i, t, col)
    if fix == 'pin':
        pushpin(c, (x0 + x1) // 2, y0 + 1, hexc('c0453a') if (x0 + y0) % 2 else hexc('3a6a9a'))
    elif fix == 'tape':
        tape(c, x0 - 1, y0 - 1, 5, 3, 1)
        tape(c, x1 - 3, y0 - 1, 5, 3, -1)
    return (x0, y0, x1, y1)


def draw_sticky(c, x0, y0, word, col, ink, w):
    """A square sticky note: a darker glue strip across the top, the word, the bottom corner curling off the wall."""
    px_w = w
    prect(c, x0, y0, x0 + px_w, y0 + 9, col)
    prect(c, x0, y0, x0 + px_w, y0, shade(col, 0.9))                                 # the glue edge
    for x in range(x0 + 1, x0 + px_w + 2):
        px(c, x, y0 + 10, hexc('000000', 50))
    for x in range(x0 + px_w - 2, x0 + px_w + 1):                                     # the curl
        px(c, x, y0 + 9, shade(col, 0.74))
    px(c, x0 + px_w, y0 + 8, shade(col, 0.66))
    text(c, x0 + 2, y0 + 2, word, ink)
    prect(c, x0 + 1, y0 + 8, x0 + 1 + min(px_w - 4, width(word)), y0 + 8, shade(col, 0.82))   # underlined in pen
    return x0 + px_w


def draw_newspaper(c, x0, y0, headline, sub, w, seed=1):
    """A front page (w x 26): the masthead's thick-and-thin rules, an ornament, the headline, the strap line,
    a halftone photo of a smoking skyline with its caption, and columns of small print."""
    x1, y1 = x0 + w, y0 + 26
    paper = hexc('ddd6c2')
    sheet(c, x0, y0, x1, y1, paper, seed + x0, fold='h', curl='bl')
    for x in range(x0 + 1, x1):                                                         # yellowed edges
        px(c, x, y0 + 1, shade(paper, 0.94)); px(c, x, y1 - 1, shade(paper, 0.92))
    c.hline(x0 + 2, x1 - 2, y0 + 2, INK)
    c.hline(x0 + 2, x1 - 2, y0 + 3, INK)
    c.hline(x0 + 2, x1 - 2, y0 + 5, hexc('8a8270'))
    px(c, (x0 + x1) // 2, y0 + 4, RED)                                                  # the paper's ornament
    text(c, x0 + (w - width(headline)) // 2 + 1, y0 + 7, headline, INK)
    yy = y0 + 13
    if sub:
        text(c, x0 + (w - width(sub)) // 2 + 1, yy, sub, hexc('5a544a'))
        yy += 6
    px0, px1 = x0 + 2, x0 + w // 2 - 1                                                  # the photo: halftone
    prect(c, px0, yy, px1, y1 - 4, hexc('9a9484'))
    for x in range(px0, px1 + 1):
        for y in range(yy, y1 - 3):
            if (x + y) % 2 == 0:
                px(c, x, y, hexc('7a7468'))
    for (bx, bh) in ((1, 3), (3, 5), (5, 4), (7, 6), (9, 3)):                          # a skyline with smoke
        if px0 + bx + 1 <= px1:
            prect(c, px0 + bx, y1 - 4 - bh, px0 + bx + 1, y1 - 4, hexc('3a362e'))
    for k in range(4):
        px(c, px0 + 7 + (k % 2), yy + 1 + k, hexc('b8b2a2'))
    c.hline(px0, px1, y1 - 3, hexc('8a8270'))
    for ly in range(yy, y1 - 1, 2):
        greek(c, x0 + w // 2 + 1, x1 - 2, ly, hexc('9a9282'), random.Random(ly + seed), 1)
    tape(c, x0 - 1, y0 - 1, 5, 3, 1)
    tape(c, x1 - 3, y0 - 1, 5, 3, -1)
    return (x0, y0, x1, y1)


def draw_missing(c, x0, y0, name, col=hexc('f0ece0'), seed=1):
    """A MISSING flyer (30 x 30): the red banner, the photograph, the name (or small print), the strip of
    tear-off tabs — two already taken."""
    w, h = 29, 30
    x1, y1 = x0 + w, y0 + h
    sheet(c, x0, y0, x1, y1 - 4, col, seed + x0, fold=None, curl='tr')
    prect(c, x0 + 1, y0 + 1, x1 - 1, y0 + 7, RED)
    centred(c, (x0 + x1) // 2 + 1, y0 + 2, 'MISSING', hexc('f6f0e4'))
    gx0, gx1 = (x0 + x1) // 2 - 8, (x0 + x1) // 2 + 8
    prect(c, gx0, y0 + 9, gx1, y0 + 19, hexc('fbf9f2'))
    prect(c, gx0 + 1, y0 + 10, gx1 - 1, y0 + 18, hexc('8aa4b8'))
    prect(c, gx0 + 1, y0 + 15, gx1 - 1, y0 + 18, hexc('7a9a6a'))
    face(c, (gx0 + gx1) // 2, y0 + 13, hexc('d8b08a'), hexc('4a3424'), hexc('b84a3a'))
    if name:
        centred(c, (x0 + x1) // 2 + 1, y0 + 21, name, INK)
    else:
        greek(c, x0 + 4, x1 - 4, y0 + 22, SMALL_PRINT, random.Random(seed))
    greek(c, x0 + 4, x1 - 4, y0 + 26, SMALL_PRINT, random.Random(seed + 1))
    for k in range(7):
        tx = x0 + 1 + k * 4
        if k in (1, 4):
            continue
        prect(c, tx, y1 - 3, tx + 2, y1, col)
        c.vline(tx + 3, y1 - 3, y1, shade(col, 0.8))
        px(c, tx + 1, y1 - 2, hexc('7a766c'))
    tape(c, x0 + 11, y0 - 1, 7, 3, 0)
    return (x0, y0, x1, y1)


def draw_timetable(c, x0, y0, seed=1):
    """A pinned school timetable (18 x 13): a coloured header row, a grid of coloured lessons, one ringed in red."""
    x1, y1 = x0 + 17, y0 + 12
    sheet(c, x0, y0, x1, y1, hexc('f1eee4'), seed, fold=None, curl='br', grain=0.02)
    prect(c, x0 + 1, y0 + 1, x1 - 1, y0 + 2, hexc('3a6a9a'))
    cols = (hexc('e8c43c'), hexc('7ab06a'), hexc('d8706a'), hexc('6a9ad0'), hexc('c8a8d8'))
    rng = random.Random(seed)
    for r_ in range(3):
        for k in range(5):
            prect(c, x0 + 1 + k * 3 + (1 if k else 0) - (1 if k else 0), y0 + 4 + r_ * 3, x0 + 2 + k * 3, y0 + 5 + r_ * 3,
                  cols[rng.randrange(5)])
    for k in range(1, 5):
        c.vline(x0 + 1 + k * 3, y0 + 3, y1 - 1, hexc('b8b4a8'))
    for (dx, dy) in ((-1, 0), (3, 0), (0, -1), (1, -1), (0, 2), (1, 2)):                # a red ring round one lesson
        px(c, x0 + 11 + dx, y0 + 7 + dy, RED)
    pushpin(c, (x0 + x1) // 2, y0 - 1, hexc('3a6a9a'))
    return (x0, y0, x1, y1)


def draw_certificate(c, x0, y0, x1, y1, title='AWARD'):
    """A framed certificate: a black moulding, a white mat, a cream card with a double rule, the title, lines
    for the citation, a signature scrawl and a red rosette with two tails."""
    r = frame(c, x0, y0, x1, y1, 'black', mat=hexc('f2eee2'), thick=1, lip=True, matw=1)
    ix0, iy0, ix1, iy1 = r
    prect(c, ix0, iy0, ix1, iy1, hexc('ece4cc'))
    for x in range(ix0, ix1 + 1):
        px(c, x, iy0, hexc('b09050')); px(c, x, iy1, hexc('b09050'))
    for y in range(iy0, iy1 + 1):
        px(c, ix0, y, hexc('b09050')); px(c, ix1, y, hexc('b09050'))
    cx = (ix0 + ix1) // 2
    text(c, cx - width(title) // 2, iy0 + 2, title, hexc('2a2622'))
    for k, yy in enumerate((iy0 + 8, iy0 + 10)):
        c.hline(ix0 + 3, ix1 - 3 - (3 if k else 0), yy, hexc('9a927e'))
    scribble_name(c, ix0 + 3, iy1 - 3, 8, hexc('2a3a6a'), 7)
    rx, ry = ix1 - 5, iy1 - 4                                                  # the rosette
    c.line(rx - 1, ry, rx - 2, iy1, hexc('a02a24')); c.line(rx + 1, ry, rx + 2, iy1, hexc('a02a24'))
    c.ellipse(rx, ry - 1, 2.2, 2.2, hexc('c8322a'))
    px(c, rx, ry - 1, hexc('e8c43c'))
    glint(c, r, 34)


def draw_emergency_notice(c, x0, y0, x1, y1, top='STAY', bottom='INSIDE'):
    """A printed emergency notice pushed under every door: hazard stripes top and bottom, the instruction in
    large black capitals, a line of small print, a curl, taped at the corners."""
    sheet(c, x0, y0, x1, y1, hexc('e8c83a'), seed=x0 + y0, fold='h', curl='br')
    stripes(c, x0 + 1, y0 + 1, x1 - 1, y0 + 2, hexc('26262a'), hexc('e8c83a'), 3)
    stripes(c, x0 + 1, y1 - 2, x1 - 1, y1 - 1, hexc('26262a'), hexc('e8c83a'), 3)
    cx = (x0 + x1) // 2 + 1
    centred(c, cx, y0 + 5, top, hexc('1e1e24'))
    centred(c, cx, y0 + 11, bottom, hexc('1e1e24'))
    greek(c, x0 + 4, x1 - 4, y0 + 17, hexc('6a5a20'), random.Random(x0), 1)
    tape(c, x0 - 1, y0 - 1, 5, 3, 1)
    tape(c, x1 - 3, y0 - 1, 5, 3, -1)


def paper_folds(c, x0, y0, x1, y1, vert=(), horiz=(), tone=0.9):
    """Crease lines (a shaded pixel with a lit one beside it) over an already drawn sheet — a map that was folded."""
    for xx in vert:
        for y in range(y0 + 1, y1):
            p = c.px[xx, y]
            px(c, xx, y, shade(p, tone)); px(c, xx + 1, y, shade(c.px[xx + 1, y], 1.05))
    for yy in horiz:
        for x in range(x0 + 1, x1):
            p = c.px[x, yy]
            px(c, x, yy, shade(p, tone)); px(c, x, yy + 1, shade(c.px[x, yy + 1], 1.05))


def img_mcm(c, r, seed=1):
    """A mid-century modern print: a cream ground, an arch of nested half-circles (terracotta, mustard, teal),
    a small sun, a thin horizon and a few black reeds."""
    x0, y0, x1, y1 = r
    w, h = x1 - x0 + 1, y1 - y0 + 1
    prect(c, x0, y0, x1, y1, hexc('f3edde'))
    cx, base = x0 + w * 0.56, y1 - max(3, h // 7)
    for rad, col in ((h * 0.72, hexc('c8602e')), (h * 0.54, hexc('e0a838')), (h * 0.36, hexc('2f6a6a')), (h * 0.17, hexc('f3edde'))):
        for y in range(int(base - rad), int(base) + 1):
            for x in range(int(cx - rad), int(cx + rad) + 1):
                if math.hypot((x - cx), (y - base)) <= rad and x0 <= x <= x1 and y >= y0:
                    px(c, x, y, col)
    sx, sy, sr = x0 + w * 0.17, y0 + h * 0.24, max(2.0, w * 0.09)
    c.ellipse(sx, sy, sr, sr, hexc('d9a02e'))
    c.hline(x0 + 1, x1 - 1, int(base) + 1, hexc('26262a'))
    for k, dx in enumerate((0.08, 0.14, 0.2)):                              # black reeds on the horizon
        rx = int(x0 + w * dx)
        c.vline(rx, int(base) - 3 - k, int(base), hexc('26262a'))
        px(c, rx + 1, int(base) - 2 - k, hexc('26262a'))
    prect(c, x0, int(base) + 2, x1, y1, hexc('e6dcc6'))


def picture_print(c, x0, y0, x1, y1, kind='black', fn=None):
    """A framed print behind glass in a thin moulding with a white card mat (outer rect in)."""
    r = frame(c, x0, y0, x1, y1, kind, mat=hexc('f6f2e6'), thick=1, hang='wire', lip=True)
    _paint(c, r, fn or img_mcm)
    glint(c, r, 40)


# --------------------------------------------------------------------------------------------
# THE CORRIDOR'S PAPER, as one table (tools/art/corridor_decals.py writes these; --check compares the files)
# --------------------------------------------------------------------------------------------
CORRIDOR_PAPER = [
    ('notice_lift', n_lift, 70), ('notice_water', n_water, 71), ('notice_meeting', n_meeting, 72),
    ('notice_bins', n_bins, 73), ('notice_smoking', n_smoking, 74), ('notice_quiet', n_quiet, 75),
    ('notice_evac', n_evac, 76), ('notice_curfew', n_curfew, 77), ('notice_dont_open', n_dont_open, 78),
    ('notice_fire_door', n_fire_door, 79), ('poster_lost_cat', n_lost_cat, 81), ('kid_drawing', n_kid_drawing, 64),
    ('poster_missing', n_missing, 65), ('notice_quarantine', n_quarantine, 66),
]
SLOT_MAX = (52, 29)             # the notice slot on the corridor wall (scripts/corridor_decals.gd "poster" zone, top row 67):
                                # 38 wide x 29 tall between a door's switch and the next door's plate, or 52 x 23 (clear of the plate)


def _swatch(w, h, col=hexc('b4a070')):
    c = Canvas(w=w, h=h, seed=1)
    c.rect(0, 0, w - 1, h - 1, col)
    return c


def preview_sheet():
    """Every piece at 4x on a wall swatch: the corridor's paper, then the room posters and framed pictures."""
    from PIL import Image
    S = 4
    cells = []
    for name, fn, seed in CORRIDOR_PAPER:
        cells.append(fn(seed).img)
    room = Canvas(w=640, h=60, seed=1)
    room.rect(0, 0, 639, 59, hexc('5e7f86'))
    x = 6
    for fn, w_, h_ in ((lambda c, a, b, c2, d: poster_guitar(c, a, b, c2, d, 'sun'), 30, 30),
                       (lambda c, a, b, c2, d: poster_record(c, a, b, c2, d), 30, 30),
                       (lambda c, a, b, c2, d: poster_horror(c, a, b, c2, d), 26, 36),
                       (lambda c, a, b, c2, d: poster_space(c, a, b, c2, d), 30, 24),
                       (lambda c, a, b, c2, d: poster_map(c, a, b, c2, d), 36, 24),
                       (lambda c, a, b, c2, d: poster_travel(c, a, b, c2, d), 24, 28),
                       (lambda c, a, b, c2, d: poster_rainbow(c, a, b, c2, d), 20, 26),
                       (lambda c, a, b, c2, d: picture_crayon(c, a, b, c2, d), 30, 24),
                       (lambda c, a, b, c2, d: picture_print(c, a, b, c2, d), 34, 28),
                       (lambda c, a, b, c2, d: draw_certificate(c, a, b, c2, d), 28, 22)):
        fn(room, x, 12, x + w_ - 1, 12 + h_ - 1)
        x += w_ + 8
    cols = 4
    cw, chh = 60 * S, 34 * S
    rows = (len(cells) + cols - 1) // cols
    sheet_ = Image.new('RGBA', (max(cols * cw, 640 * S // 2), rows * chh + 60 * S // 2 * 2), (180, 160, 112, 255))
    for i, im in enumerate(cells):
        big = im.resize((im.size[0] * S, im.size[1] * S), Image.NEAREST)
        sheet_.alpha_composite(big, ((i % cols) * cw + 2 * S, (i // cols) * chh + 2 * S))
    rimg = room.img.resize((640 * S // 2, 60 * S // 2), Image.NEAREST)
    sheet_.alpha_composite(rimg, (0, rows * chh))
    return sheet_


def check():
    """Every corridor piece builds, fits the notice slot, and matches the PNG on disk; every room piece draws."""
    from PIL import Image, ImageChops
    bad = []
    for name, fn, seed in CORRIDOR_PAPER:
        im = fn(seed).img
        if im.size[0] > SLOT_MAX[0] or im.size[1] > SLOT_MAX[1] or (im.size[0] > 38 and im.size[1] > 23):
            bad.append('%s is %dx%d — over the %dx%d notice slot' % (name, im.size[0], im.size[1], SLOT_MAX[0], SLOT_MAX[1]))
        path = os.path.join(ROOT, 'assets', 'corridor', 'decals', name + '.png')
        if not os.path.exists(path):
            bad.append('%s.png is missing — run tools/art/corridor_decals.py' % name)
        elif ImageChops.difference(Image.open(path).convert('RGBA'), im).getbbox() is not None:
            bad.append('%s.png is stale — run tools/art/corridor_decals.py' % name)
    preview_sheet()                                                       # every room piece draws without raising
    for name in ('img_guitar', 'img_record', 'img_horror', 'img_space', 'img_map', 'img_travel', 'img_rainbow', 'img_crayon',
                 'img_mcm', 'frame', 'draw_note', 'draw_sticky', 'draw_newspaper', 'draw_missing', 'draw_timetable',
                 'draw_certificate', 'draw_emergency_notice', 'paper_folds', 'picture_print', 'poster_paper'):
        if name not in globals():
            bad.append('wallart.%s has gone missing' % name)
    return bad


if __name__ == '__main__':
    if '--check' in sys.argv:
        problems = check()
        for p_ in problems:
            print('wallart: ' + p_)
        print('wall art current' if not problems else '%d wall-art problem(s)' % len(problems))
        sys.exit(1 if problems else 0)
    out = os.path.join(ROOT, 'docs', 'art_reference', 'wall_art.png')
    preview_sheet().save(out)
    print('wrote', out)
