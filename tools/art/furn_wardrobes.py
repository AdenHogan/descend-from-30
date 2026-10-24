"""WARDROBES AND THE PILL CABINET — redrawn with carved detail (owner round 47b: "the bottom wardrobes are generally fine but also look a little too plain… more detail and love").

What they gained: a built-up cornice (cap, cove, a frieze of dentils, a bead), doors with real raised panels (a lit top / left edge, a shaded bottom / right edge, a lighter field), wood grain, an
astragal strip down the join, brass escutcheons with a keyhole and a knob, a drawer with its own panel and pulls, a plinth with bracket feet. The mirrored wardrobe has a gilt frame, a glass that
reflects the room in two tones with streaks (one of them cracked), a pediment with a finial; the child's wardrobe is painted cream with a scalloped pelmet, a stencilled star / moon / flower on each
door and round knobs; the pill cabinet bottles that are round glass with caps and labels.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import propkit as K
import wardrobe_inside as WI
from furnlib import piece
from pixlib import hexc, shade, mix

BRASS = hexc('b09456')
BRASS_LT = hexc('e0c878')
BRASS_DK = hexc('7a6430')
WOOD_OUT = hexc('2b1c13')


# -------------------------------------------------------------------------------------------------------------------------------- shared bits
def _grain(c, x0, y0, x1, y1, col, seed, n):
    rng = random.Random(seed)
    for _ in range(n):
        x = rng.randint(x0, x1)
        y = rng.randint(y0, max(y0, y1 - 6))
        for k in range(rng.randint(3, 8)):
            if y + k <= y1:
                c.put(x, y + k, col)


def _raised(c, x0, y0, x1, y1, col, lt, dk, out=None):
    """A raised panel: an outline, a lit top / left edge, a shaded bottom / right edge, a slightly lighter field."""
    out = out or shade(dk, 0.62)
    c.rect(x0, y0, x1, y1, shade(col, 1.07))
    c.hline(x0, x1, y0, lt)
    c.vline(x0, y0, y1, lt)
    c.hline(x0, x1, y1, dk)
    c.vline(x1, y0, y1, dk)
    c.hline(x0 - 1, x1 + 1, y0 - 1, out)
    c.hline(x0 - 1, x1 + 1, y1 + 1, out)
    c.vline(x0 - 1, y0 - 1, y1 + 1, out)
    c.vline(x1 + 1, y0 - 1, y1 + 1, out)


def _escutcheon(c, x, y):
    """A brass escutcheon plate, a knob and a keyhole."""
    c.rect(x, y, x + 1, y + 4, BRASS)
    c.vline(x, y, y + 4, BRASS_LT)
    c.put(x + 1, y + 4, BRASS_DK)
    c.put(x, y + 2, hexc('2a1c17'))


def _pull(c, x0, x1, y):
    c.hline(x0, x1, y, BRASS)
    c.hline(x0, x1, y - 1, BRASS_LT)
    c.hline(x0, x1, y + 1, BRASS_DK)
    c.put(x0 - 1, y, BRASS_DK)
    c.put(x1 + 1, y, BRASS_DK)


def _cornice(c, x0, x1, top, WA, WA_DK, WA_LT):
    """A built-up cornice: a lit cap, a stepped overhang, a cove in shadow, a frieze of dentils and a bead — 7 rows from `top`."""
    c.rect(x0 - 2, top, x1 + 2, top + 1, WA)
    c.hline(x0 - 2, x1 + 2, top, shade(WA_LT, 1.15))
    c.hline(x0 - 2, x1 + 2, top + 1, WA_LT)
    c.hline(x0 - 3, x1 + 3, top + 2, shade(WA_LT, 0.9))
    c.hline(x0 - 3, x1 + 3, top + 3, shade(WA_DK, 0.65))
    c.rect(x0 - 1, top + 4, x1 + 1, top + 5, WA)
    for x in range(x0, x1 + 1, 2):
        c.put(x, top + 4, WA_LT)                                          # dentils
        c.put(x + 1, top + 5, shade(WA, 0.78))
    c.hline(x0 - 1, x1 + 1, top + 6, WA_DK)
    c.hline(x0 - 1, x1 + 1, top + 7, shade(WA_DK, 0.6))


def _feet(c, x0, x1, base, WA, WA_DK, WA_LT):
    """A plinth skirt with bracket feet at the corners (rows base-5 .. base)."""
    c.rect(x0, base - 5, x1, base - 3, WA_DK)
    c.hline(x0, x1, base - 5, WA)
    c.hline(x0 + 1, x1 - 1, base - 4, shade(WA_DK, 1.15))
    for fx in (x0 - 1, x1 - 4):
        c.rect(fx, base - 3, fx + 4, base - 1, WA)
        c.hline(fx, fx + 4, base - 3, WA_LT)
        c.vline(fx, base - 3, base, WA_LT)
        c.hline(fx, fx + 4, base, WOOD_OUT)
        c.vline(fx + 4, base - 3, base, WA_DK)
        c.put(fx + 1, base, WOOD_OUT)
        c.put(fx + 3, base - 3, WA_DK)


def _door(c, xa, xb, ya, yb, WA, WA_DK, WA_LT, seed, handle_x=None):
    """One door leaf: a framed carcass, a tall raised panel over a short one with a rail between, wood grain, and an escutcheon at the join side."""
    out = shade(WA_DK, 0.62)
    c.rect(xa, ya, xb, yb, WA)
    c.hline(xa, xb, ya, WA_LT)
    c.vline(xa, ya, yb, shade(WA_LT, 0.92))
    c.hline(xa, xb, yb, WA_DK)
    c.vline(xb, ya, yb, shade(WA_DK, 0.9))
    _grain(c, xa + 1, ya + 1, xb - 1, yb - 1, shade(WA, 0.9), seed, 7)
    h = yb - ya
    split = ya + int(h * 0.64)
    _raised(c, xa + 3, ya + 3, xb - 3, split - 2, WA, WA_LT, WA_DK, out)
    _raised(c, xa + 3, split + 2, xb - 3, yb - 3, WA, WA_LT, WA_DK, out)
    # arched shoulders on the tall panel: its top corners cut
    for (px, py) in ((xa + 3, ya + 3), (xb - 3, ya + 3)):
        c.put(px, py, WA)
    if handle_x is not None:
        _escutcheon(c, handle_x, (ya + yb) // 2 - 2)


# ================================================================================================================================ the wardrobe
def _wardrobe_body(c, x0, x1, top, base, pal, t):
    """The adult wardrobe: cornice, two panelled doors, a drawer, a plinth on bracket feet; at t > 0 the RIGHT door swings out on its hinge to show the inside (wardrobe_inside.py)."""
    WA, WA_DK, WA_LT = pal
    out = shade(WA_DK, 0.55)
    c.shadow((x0 + x1) // 2, base + 1, 23, 2, 100)
    mid = (x0 + x1) // 2
    c.rect(x0 - 1, top + 8, x1 + 1, base - 5, out)                       # the carcass (its outline)
    c.rect(x0, top + 8, x1, base - 5, shade(WA, 0.86))
    _cornice(c, x0, x1, top, WA, WA_DK, WA_LT)
    dy0, dy1 = top + 9, base - 19
    _door(c, x0 + 1, mid - 1, dy0, dy1, WA, WA_DK, WA_LT, 3, handle_x=mid - 4)
    if t <= 0.0:
        _door(c, mid + 1, x1 - 1, dy0, dy1, WA, WA_DK, WA_LT, 9, handle_x=mid + 3)
    else:
        WI.draw(c.put, (mid + 1, dy0, x1 - 1, dy1), WA)                    # the inside, with real geometry (wardrobe_inside.py: shared with the baked wardrobes)
        dw = (x1 - 1) - (mid + 1)
        wd = max(3, int(round(dw * (1.0 - t) ** 0.8)))                      # the leaf seen foreshortened as it swings out
        xa = x1 - 1 - wd + 1
        _door(c, xa, x1 - 1, dy0, dy1, WA, WA_DK, WA_LT, 9, handle_x=None)
        out_w = int(round(5 * t))
        if out_w:
            c.poly([(x1, dy0), (x1 + out_w, dy0 + 2), (x1 + out_w, dy1 - 1), (x1, dy1)], WA_LT)
            c.line(x1 + out_w, dy0 + 2, x1 + out_w, dy1 - 1, WA_DK)
    # the drawer, its own raised panel and two pulls
    c.hline(x0 + 1, x1 - 1, dy1 + 1, shade(WA_DK, 0.7))
    c.hline(x0 + 1, x1 - 1, dy1 + 2, WA_DK)
    _raised(c, x0 + 3, dy1 + 5, x1 - 3, base - 8, WA, WA_LT, WA_DK, out)
    _pull(c, x0 + 8, x0 + 11, (dy1 + 5 + base - 8) // 2)
    _pull(c, x1 - 11, x1 - 8, (dy1 + 5 + base - 8) // 2)
    c.vline(mid, dy0, dy1, out)                                           # the astragal over the doors' join
    if t <= 0.0:
        c.vline(mid - 1, dy0 + 1, dy1 - 1, WA_LT)
    _feet(c, x0, x1, base, WA, WA_DK, WA_LT)


@piece('wardrobe_wood', 46, 73, 'wall', rooms={'bedroom': 6}, styles={'adult': 6, 'sick': 1, 'teen': 1}, tags=('storage', 'wardrobe', 'tall'), depth=4,
       variants={'walnut': {'pal': (hexc('6a4a33'), hexc('533826'), hexc('7e5a3f'))}, 'oak': {'pal': (hexc('7a5a3a'), hexc('5e4430'), hexc('8e6a46'))},
                 'dark': {'pal': (hexc('4e3626'), hexc('3a281c'), hexc('62463a'))}, 'painted': {'pal': (hexc('7a8a80'), hexc('5a685f'), hexc('94a498'))}},
       slots=({'id': 'top', 'dx0': 3, 'dx1': 42, 'dy': -72, 'top': True, 'kinds': ('big',)},),
       anchors=({'name': 'wardrobe_upper', 'dx': 33, 'dy': -53}, {'name': 'wardrobe_lower', 'dx': 22, 'dy': -9}),
       opens={'kind': 'door_h', 'frames': 3, 'anchor': 'wardrobe_upper'}, feet=(105, 108),
       note='a tall wardrobe: built-up cornice, two raised-panel doors with escutcheons, a drawer on bracket feet; the right door opens on clothes (walnut, oak, dark, or painted sage)')
def wardrobe_wood(c, ox, oy, p):
    _wardrobe_body(c, ox, ox + 45, oy - 72, oy, p['pal'], p['open'])


# ================================================================================================================================ the mirrored wardrobe
def _mirror_glass(c, x0, y0, x1, y1, cracked, seed):
    """Glass that reflects the room in two tones: paler toward the top, a darker band low down, two diagonal streaks of light, tarnish at the corners; optionally a crack with a few branches."""
    rng = random.Random(seed)
    top, bot = hexc('a8b6bc'), hexc('6e7e86')
    h = y1 - y0
    for y in range(y0, y1 + 1):
        f = (y - y0) / float(max(1, h))
        col = mix(top, bot, f * 0.9)
        c.hline(x0, x1, y, col)
    yb = y0 + int(h * 0.64)                                                                         # the reflected floor: a dithered edge, then a darker plain band
    c.dither(x0, yb - 1, x1, yb, shade(bot, 0.96), 0.5)
    c.rect(x0, yb + 1, x1, y1, shade(bot, 0.94))
    w = x1 - x0
    for (sx, sw) in ((0.18, 2), (0.42, 1)):
        xs = int(x0 + w * sx)
        c.line(xs + 0, y1 - 2, xs + int(w * 0.55), y0 + 2, hexc('dce6e8'))
        if sw > 1:
            c.line(xs + 1, y1 - 2, xs + 1 + int(w * 0.55), y0 + 2, hexc('c4d2d6'))
    for (cx_, cy_) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        c.put(cx_, cy_, hexc('4a5860'))
        c.put(cx_ + (1 if cx_ == x0 else -1), cy_, hexc('566870'))
    if cracked:
        a = (x0 + int(w * 0.62), y0 + 2)
        pts = [a]
        x, y = a
        for k in range(8):
            x += rng.choice((-1, 0, -1, 1))
            y += 4
            pts.append((x, min(y, y1 - 1)))
        for i in range(len(pts) - 1):
            c.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], hexc('30383c'))
        for (px_, py_) in (pts[2], pts[5]):
            c.line(px_, py_, px_ + rng.choice((-6, 6)), py_ + 3, hexc('3a4448'))
        c.put(pts[0][0] + 1, pts[0][1], hexc('f0f6f8'))


@piece('wardrobe_mirror', 46, 80, 'wall', rooms={'bedroom': 4}, styles={'sick': 8, 'adult': 2}, tags=('wardrobe', 'storage', 'mirror', 'tall'), depth=5,
       variants={'clean': {'cracked': False}, 'cracked': {'cracked': True}},
       anchors=({'name': 'wardrobe', 'dx': 9, 'dy': -39},), feet=(105, 108),
       note='a tall mahogany wardrobe with a pediment and finial, a panelled door and a gilt-framed mirrored door whose glass reflects the room (one is cracked)')
def wardrobe_mirror(c, ox, oy, p):
    WA, WA_DK, WA_LT = hexc('5e3a2a'), hexc('46291d'), hexc('7a4e38')
    out = shade(WA_DK, 0.55)
    x0, x1 = ox, ox + 45
    top, base = oy - 79, oy
    c.shadow((x0 + x1) // 2, base + 1, 23, 2, 100)
    c.rect(x0 - 1, top + 12, x1 + 1, base - 5, out)
    c.rect(x0, top + 12, x1, base - 5, shade(WA, 0.86))
    _cornice(c, x0, x1, top + 5, WA, WA_DK, WA_LT)
    mid = (x0 + x1) // 2 - 2                                              # the panelled door is narrower than the mirror door
    # the pediment: a shallow arch with a carved crest and a turned finial
    for k, (xa, xb) in enumerate(((x0 + 8, x1 - 8), (x0 + 12, x1 - 12), (x0 + 15, x1 - 15))):
        c.hline(xa, xb, top + 4 - k - 1, WA_LT if k == 0 else WA)
        c.hline(xa, xb, top + 4 - k, WA)
    c.rect((x0 + x1) // 2 - 1, top, (x0 + x1) // 2 + 1, top + 1, BRASS)
    c.put((x0 + x1) // 2, top - 1 if top > 0 else top, BRASS_LT)
    c.hline(x0 + 8, x1 - 8, top + 4, shade(WA_DK, 0.8))
    dy0, dy1 = top + 14, base - 19
    _door(c, x0 + 1, mid - 1, dy0, dy1, WA, WA_DK, WA_LT, 5, handle_x=mid - 4)
    # the mirror door: a gilt frame with a bevel round the glass
    fx0, fx1 = mid + 1, x1 - 1
    c.rect(fx0, dy0, fx1, dy1, WA)
    c.hline(fx0, fx1, dy0, WA_LT)
    c.rect(fx0 + 1, dy0 + 2, fx1 - 1, dy1 - 2, BRASS)
    c.hline(fx0 + 1, fx1 - 1, dy0 + 2, BRASS_LT)
    c.vline(fx0 + 1, dy0 + 2, dy1 - 2, BRASS_LT)
    c.hline(fx0 + 1, fx1 - 1, dy1 - 2, BRASS_DK)
    c.vline(fx1 - 1, dy0 + 2, dy1 - 2, BRASS_DK)
    c.rect(fx0 + 2, dy0 + 3, fx1 - 2, dy1 - 3, shade(BRASS_DK, 0.7))        # the bevel's inner shadow
    _mirror_glass(c, fx0 + 3, dy0 + 4, fx1 - 3, dy1 - 4, p['cracked'], 3)
    _escutcheon(c, fx0 - 1, (dy0 + dy1) // 2 - 2)
    c.vline(mid, dy0, dy1, out)
    c.hline(x0 + 1, x1 - 1, dy1 + 1, shade(WA_DK, 0.7))
    c.hline(x0 + 1, x1 - 1, dy1 + 2, WA_DK)
    _raised(c, x0 + 3, dy1 + 5, x1 - 3, base - 8, WA, WA_LT, WA_DK, out)
    _pull(c, (x0 + x1) // 2 - 2, (x0 + x1) // 2 + 2, (dy1 + 5 + base - 8) // 2)
    _feet(c, x0, x1, base, WA, WA_DK, WA_LT)


# ================================================================================================================================ the child's wardrobe
KID_WARD = {'pink': hexc('d98aa0'), 'blue': hexc('7aa0c8'), 'yellow': hexc('e6c24a')}


def _stencil(c, cx, cy, kind, col):
    if kind == 'star':
        for (dx, dy) in ((0, -2), (-1, -1), (0, -1), (1, -1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (-1, 2), (1, 2)):
            c.put(cx + dx, cy + dy, col)
    elif kind == 'moon':
        for (dx, dy) in ((-1, -2), (0, -2), (-2, -1), (-2, 0), (-2, 1), (-1, 2), (0, 2), (-1, -1), (-1, 1), (0, -1), (0, 1)):
            c.put(cx + dx, cy + dy, col)
        c.put(cx + 2, cy - 1, col)
    else:
        c.put(cx, cy, hexc('e8c040'))
        for (dx, dy) in ((0, -1), (1, 0), (0, 1), (-1, 0), (0, -2), (2, 0), (0, 2), (-2, 0)):
            c.put(cx + dx, cy + dy, col)


@piece('wardrobe_small', 38, 70, 'wall', rooms={'bedroom': 4}, styles={'kid': 8}, tags=('wardrobe', 'storage'), depth=4,
       variants={k: {'trim': k} for k in KID_WARD},
       anchors=({'name': 'small_wardrobe', 'dx': 18, 'dy': -29},), feet=(105, 108),
       note='a small cream-painted wardrobe with a scalloped pelmet, a stencilled star and moon on the doors, round knobs and bracket feet')
def wardrobe_small(c, ox, oy, p):
    draw_small_wardrobe(c, ox, oy, KID_WARD[p['trim']], 38)


def draw_small_wardrobe(c, ox, oy, trim, w=38):
    """The kid's wardrobe, `w` px wide (38 in the library; the baked child's room — bedroom_variants.py — stands it 28 wide in its corner, where a window box leaves no more)."""
    cream, cream_dk, cream_lt = hexc('e6e0cc'), hexc('b9b3a4'), hexc('f6f2e4')
    out = hexc('8a8270')
    x0, x1 = ox, ox + w - 1
    top, base = oy - 68, oy
    c.shadow((x0 + x1) // 2, base + 1, w // 2, 2, 100)
    # the rounded top with a cap moulding, the scalloped pelmet under it
    c.rect(x0 - 1, top + 3, x1 + 1, top + 5, cream_lt)
    c.hline(x0 - 1, x1 + 1, top + 3, hexc('ffffff'))
    c.hline(x0 - 1, x1 + 1, top + 5, cream_dk)
    c.rect(x0 + 1, top + 1, x1 - 1, top + 2, cream_lt)
    c.hline(x0 + 3, x1 - 3, top, cream_lt)
    c.rect(x0, top + 6, x1, base - 5, out)
    c.rect(x0 + 1, top + 6, x1 - 1, base - 5, cream)
    c.vline(x0 + 1, top + 6, base - 5, cream_lt)
    c.vline(x1 - 1, top + 6, base - 5, cream_dk)
    for x in range(x0 + 1, x1, 4):                                           # the scalloped pelmet
        c.rect(x, top + 6, x + 3, top + 8, trim)
        c.hline(x, x + 3, top + 6, shade(trim, 1.2))
        c.put(x, top + 9, trim); c.put(x + 3, top + 9, trim)
        c.hline(x + 1, x + 2, top + 9, shade(trim, 0.8))
        c.put(x + 1, top + 10, shade(trim, 0.75)); c.put(x + 2, top + 10, shade(trim, 0.75))
    mid = (x0 + x1) // 2
    dy0, dy1 = top + 12, base - 7
    for (xa, xb, kind) in ((x0 + 3, mid - 1, 'star'), (mid + 1, x1 - 3, 'moon')):
        sx = (xa + xb) // 2                                                  # each stencil on the middle of its door
        c.rect(xa, dy0, xb, dy1, cream)
        c.hline(xa, xb, dy0, cream_lt)
        c.hline(xa, xb, dy1, cream_dk)
        c.vline(xb, dy0, dy1, cream_dk)
        _raised(c, xa + 2, dy0 + 3, xb - 2, dy1 - 3, cream, cream_lt, cream_dk, out)
        _stencil(c, sx, (dy0 + dy1) // 2 - 6, kind, trim)
        c.put(sx - 3, (dy0 + dy1) // 2 + 2, shade(trim, 0.9)); c.put(sx + 3, (dy0 + dy1) // 2 + 4, shade(trim, 0.9))      # a few more stencilled dots
    c.vline(mid, dy0, dy1, out)
    for kx in (mid - 3, mid + 2):                                            # round wooden knobs
        c.rect(kx, (dy0 + dy1) // 2, kx + 1, (dy0 + dy1) // 2 + 1, hexc('c9a24a'))
        c.put(kx, (dy0 + dy1) // 2, hexc('f0d880'))
    c.hline(x0 + 1, x1 - 1, base - 6, cream_dk)
    c.hline(x0 + 1, x1 - 1, base - 5, out)
    for fx in (x0 + 1, x1 - 4):                                              # little bracket feet
        c.rect(fx, base - 4, fx + 3, base, cream)
        c.vline(fx, base - 4, base, cream_lt)
        c.hline(fx, fx + 3, base, out)
        c.vline(fx + 3, base - 4, base, cream_dk)


# ================================================================================================================================ the pill cabinet
def _bottle(c, x, base, w, h, glass, cap, label=None):
    """A little glass bottle: a lit left edge, a shaded right edge, a cap, an optional paper label."""
    top = base - h + 1
    for yy in range(top + 2, base + 1):
        for xx in range(x, x + w):
            f = (xx - x) / float(max(1, w - 1))
            c.put(xx, yy, shade(glass, 1.25 - 0.62 * f))
    c.vline(x, top + 3, base - 1, shade(glass, 1.6))
    c.hline(x, x + w - 1, base, shade(glass, 0.45))
    c.rect(x + 1, top, x + w - 2, top + 1, cap)
    c.hline(x + 1, x + w - 2, top, shade(cap, 1.25))
    c.hline(x, x + w - 1, top + 2, shade(glass, 0.7))
    if label:
        c.rect(x, top + 4, x + w - 1, top + 3 + max(2, h // 3), label)
        c.put(x + 1, top + 5, hexc('7a7468'))


@piece('pill_cabinet', 28, 30, 'wall', rooms={'bedroom': 4, 'bathroom': 5}, styles={'sick': 8, 'adult': 1}, tags=('storage', 'medical'), depth=4,
       variants={'a': {'order': 0}, 'b': {'order': 1}}, surface_h=19, slots=(), anchors=({'name': 'pill_cabinet', 'dx': 13, 'dy': -14},), feet=(105, 108),
       note='a small dark cabinet, two panelled drawers with brass pulls, its top crowded with pill bottles and a tin of dressings')
def pill_cabinet(c, ox, oy, p):
    WA, WA_DK, WA_LT = hexc('5d3f2c'), hexc('46301f'), hexc('71503a')
    out = hexc('2b1c13')
    x0, x1 = ox, ox + 26
    top, base = oy - 19, oy
    c.shadow((x0 + x1) // 2, base + 1, 16, 2, 90)
    # the top slab with a little overhang
    c.rect(x0 - 1, top, x1 + 1, top + 1, WA_LT)
    c.hline(x0 - 1, x1 + 1, top, shade(WA_LT, 1.25))
    c.hline(x0 - 1, x1 + 1, top + 2, out)
    c.rect(x0, top + 3, x1, base - 3, out)
    c.rect(x0 + 1, top + 3, x1 - 1, base - 3, shade(WA, 0.9))
    for (ya, yb) in ((top + 5, top + 11), (top + 13, top + 19 - 5)):
        _raised(c, x0 + 3, ya, x1 - 3, yb, WA, WA_LT, WA_DK, out)
        _pull(c, (x0 + x1) // 2 - 2, (x0 + x1) // 2 + 2, (ya + yb) // 2)
    for fx in (x0 + 1, x1 - 3):
        c.rect(fx, base - 2, fx + 2, base, WA_DK)
        c.hline(fx, fx + 2, base, out)
    # the bottles on top, standing in a row, with a tin and a glass
    order = [(5, 6, hexc('c2701e'), hexc('ece8dc'), hexc('ece6d6')), (4, 4, hexc('e0d9b8'), hexc('3a6a9a'), None), (5, 7, hexc('c2701e'), hexc('ece8dc'), hexc('ece6d6')),
             (4, 5, hexc('6f8fa0'), hexc('d8d4c4'), hexc('dcd6c4')), (4, 4, hexc('c2701e'), hexc('b0453a'), hexc('ece6d6'))]
    if p['order']:
        order = order[::-1]
    x = x0 + 1
    for (w, h, glass, cap, label) in order:
        _bottle(c, x, top - 1, w, h, glass, cap, label)
        x += w
    # (the tin of dressings, a tumbler) at the right end
    c.rect(x0 + 21, top - 5, x0 + 25, top - 1, hexc('d9d0bc'))
    c.hline(x0 + 21, x0 + 25, top - 5, hexc('f4f0e4'))
    c.hline(x0 + 21, x0 + 25, top - 3, hexc('a8322c'))
