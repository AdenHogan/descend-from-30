"""The GROWTH library — living vegetation for the building's OVERGROWTH (owner round 26: "flowers and plants
in the rooms… dynamic, organic, and in lower level rooms actual overgrown areas… not just monsters but the
building changing").

Everything here is drawn as its own transparent sprite so the game can lay it over corridors and rooms and
sway it (scripts/sway.gd). Sprites are native pixel art (1 px = 1 game px), authored FLAT (no baked light —
the engine's lighting does that) in a green family with dry/brown and flower accents.

  hang_*     ivy / vines hanging from the ceiling — pinned at the TOP, they swing from there
  creeper_*  ivy climbing a wall from the skirting — still (it clings; round 34)
  tuft_*     grass + weeds through the floor, some with flowers — pinned at the foot
  flower_*   taller wildflower stalks — pinned at the foot
  fern_*     arching ferns — pinned at the foot
  shrub_*    big bushes / saplings that have taken a corner — still (dense; round 34)
  roots_*    roots + cracked floor — static
  moss_*     moss on the wall foot / floor — static
  fungus_*   bracket fungus and toadstools — static
  pot_*      houseplants in pots (fern / flowers / tall / dead) — pinned at the foot

  python3 tools/art/growth.py     writes assets/growth/*.png, assets/growth/growth.json and the contact sheet
                                  docs/art_reference/growth.png
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'growth')

# --- palettes: leaf shades run D(ark) M(id) L(ight) H(ighlight); "dry" is the same set gone to straw --------
GREENS = [
    dict(D='23401f', M='3a6630', L='5a9040', H='86b957'),      # forest
    dict(D='2a4a26', M='447a34', L='6ba645', H='9fcf64'),      # fresh
    dict(D='1f3a2a', M='2f5e42', L='498060', H='78ab84'),      # blue-green, damp and shaded
    dict(D='33481f', M='56742c', L='7d9a3c', H='aac457'),      # olive
]
DRY = dict(D='4a3c22', M='75612f', L='9c8640', H='c2ad5e')
STEM = hexc('2f4a26')
WOOD = [hexc('3e2f22'), hexc('5a4630'), hexc('7a6242')]
FLOWERS = ['e8c93e', 'ece6d2', '8a5cb8', 'd8709e', 'd2482e', 'e88a34']


def P(pal):
    return {k: hexc(v) for k, v in pal.items()}


# --- leaf bitmaps (D/M/L/H, '.' clear), rotated + mirrored for variety ---------------------------------------
LEAVES = {
    2: ['LM', 'MD'],
    3: ['.LM', 'LMD', 'MD.'],
    4: ['.LMM', 'LMMD', 'MMDD', '.DD.'],
    5: ['.HLM.', 'HLMMD', 'LMMMD', '.MMDD', '..D..'],
    6: ['..HLM.', '.HLMMD', 'HLMMMD', 'LMMMDD', '.MMDD.', '..DD..'],
}


def _orient(bm, k):
    rows = [list(r) for r in bm]
    if k & 1:
        rows = [r[::-1] for r in rows]                       # mirror
    if k & 2:
        rows = rows[::-1]                                    # flip
    if k & 4:
        rows = [list(r) for r in zip(*rows)]                 # transpose
    return rows


def leaf(c, x, y, size, pal, rng, k=None):
    """Stamp one leaf centred on (x, y)."""
    bm = LEAVES[size]
    rows = _orient(bm, rng.randrange(8) if k is None else k)
    h, w = len(rows), len(rows[0])
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != '.':
                c.put(int(x) - w // 2 + i, int(y) - h // 2 + j, pal[ch])


def flower(c, x, y, col, rng, big=False):
    col = hexc(col)
    dk = shade(col, 0.7)
    x, y = int(x), int(y)
    if big:
        for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            c.put(x + dx, y + dy, col)
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            c.put(x + dx, y + dy, dk)
        c.put(x, y, hexc('f4d848') if col != hexc('e8c93e') else hexc('c78a20'))
    else:
        c.put(x, y, col)
        c.put(x - 1, y, dk) if rng.random() < 0.5 else c.put(x + 1, y, dk)
        c.put(x, y - 1, shade(col, 1.15))


def new(w, h, seed):
    return Canvas(w, h, seed=seed)


def crop(c, keep_bottom=False, keep_top=False, pad=1):
    """Trim to the drawn pixels (+pad). keep_bottom/keep_top pin that edge to where it was drawn."""
    bb = c.img.getbbox()
    if bb is None:
        return c.img
    x0, y0, x1, y1 = bb
    return c.img.crop((max(0, x0 - pad), max(0, y0 - (0 if keep_top else pad)), min(c.w, x1 + pad), min(c.h, y1 + (0 if keep_bottom else pad))))


# ------------------------------------------------------------------------------------------------- vines
def vine_strand(c, x0, y0, length, pal, rng, sway=3.0, leaf_gap=(3, 5), flowers=None, tip_curl=True, thick=1):
    """A hanging vine from (x0, y0) downward: a wandering stem with leaves alternating either side, smaller
    toward the tip, the odd flower."""
    x = float(x0)
    ph = rng.uniform(0, 6.28)
    drift = 0.0
    side = rng.choice((-1, 1))
    gap = rng.randint(*leaf_gap)
    pts = []
    for i in range(length):
        drift += rng.uniform(-0.12, 0.12)
        drift *= 0.94
        x += math.sin(i / 7.0 + ph) * 0.18 + drift
        pts.append((int(round(x)), y0 + i))
    for (px, py) in pts:
        for t in range(thick):
            c.put(px + t, py, STEM if rng.random() < 0.85 else shade(STEM, 1.4))
    for i, (px, py) in enumerate(pts):
        if i < 3:
            continue
        gap -= 1
        if gap > 0:
            continue
        gap = rng.randint(*leaf_gap)
        side = -side
        frac = i / max(1, length - 1)
        size = 5 if frac < 0.55 else (4 if frac < 0.85 else 3)
        if rng.random() < 0.25:
            size = max(3, size - 1)
        off = size // 2 + 1
        leaf(c, px + side * off, py + rng.randint(0, 1), size, pal, rng)
        if flowers and rng.random() < 0.11:
            flower(c, px + side * (off + 2), py + 2, rng.choice(flowers), rng)
    if tip_curl and pts:
        px, py = pts[-1]
        leaf(c, px, py + 2, 3, pal, rng)


def hang_vine(name, seed, kind, out):
    rng = random.Random(seed)
    pal = P(rng.choice(GREENS))
    dry = kind == 'dry'
    if dry:
        pal = P(DRY)
    c = new(46, 96, seed)
    n = {'single': 1, 'pair': 2, 'cluster': 4, 'curtain': 6, 'dry': 2}[kind]
    span = {'single': 0, 'pair': 10, 'cluster': 22, 'curtain': 34, 'dry': 12}[kind]
    base_len = {'single': 46, 'pair': 40, 'cluster': 50, 'curtain': 60, 'dry': 34}[kind]
    top = 2
    fl = [rng.choice(FLOWERS)] if kind in ('pair', 'cluster') and rng.random() < 0.6 else None
    if span:
        c.hline(23 - span // 2 - 2, 23 + span // 2 + 2, top, shade(STEM, 0.8))               # where they root
    for k in range(n):
        x = 23 + (0 if n == 1 else int(-span / 2 + span * k / max(1, n - 1))) + rng.randint(-2, 2)
        ln = int(base_len * rng.uniform(0.55, 1.0))
        vine_strand(c, x, top, ln, pal, rng, flowers=fl)
    out[name] = dict(kind='hang', pin='top', img=crop(c, keep_top=True))


# ------------------------------------------------------------------------------------------------ creeper
def creeper(name, seed, w, h, density, out, dry=False):
    """Ivy climbing up a wall from the foot: branching tendrils dressed with leaves."""
    rng = random.Random(seed)
    pal = P(DRY if dry else rng.choice(GREENS))
    c = new(w, h, seed)
    branches = []
    roots = rng.randint(2, 3 + int(density * 3))
    for r in range(roots):
        branches.append([w * (0.2 + 0.6 * r / max(1, roots - 1)) + rng.uniform(-3, 3), h - 2, -math.pi / 2 + rng.uniform(-0.3, 0.3), int(h * rng.uniform(0.6, 0.98))])
    done = 0
    while branches and done < 40:
        b = branches.pop()
        x, y, ang, life = b
        gap = 0
        for i in range(life):
            ang += rng.uniform(-0.28, 0.28) + (-math.pi / 2 - ang) * 0.05
            x += math.cos(ang) * 1.0
            y += math.sin(ang) * 1.0
            xi, yi = int(round(x)), int(round(y))
            if not (0 <= xi < w and 0 <= yi < h):
                break
            c.put(xi, yi, STEM)
            gap -= 1
            if gap <= 0:
                gap = rng.randint(1, 3)
                size = 5 if rng.random() < 0.45 else 4
                leaf(c, xi + rng.randint(-2, 2), yi + rng.randint(-1, 1), size, pal, rng)
            if rng.random() < 0.05 * density * (1.0 + (h - yi) / h) and len(branches) < 14:
                branches.append([x, y, ang + rng.choice((-1, 1)) * rng.uniform(0.6, 1.1), int(life - i) * rng.randint(4, 8) // 10])
        done += 1
    if not dry and rng.random() < 0.5:
        col = rng.choice(FLOWERS)
        for _ in range(rng.randint(2, 5)):
            px, py = rng.randrange(4, w - 4), rng.randrange(6, h - 4)
            if c.px[px, py][3]:
                flower(c, px, py, col, rng)
    out[name] = dict(kind='creeper', pin='bottom', img=crop(c, keep_bottom=True))


# --------------------------------------------------------------------------------------------- floor plants
def blade(c, x, y, h, lean, col_base, col_tip, rng):
    for j in range(h):
        t = j / max(1, h - 1)
        xx = x + int(round(lean * t * t * 3))
        c.put(xx, y - j, col_base if t < 0.4 else (shade(col_base, 1.25) if t < 0.8 else col_tip))


def tuft(name, seed, w, hmax, out, flowers=None, dry=False):
    rng = random.Random(seed)
    pal = P(DRY if dry else rng.choice(GREENS))
    c = new(w + 6, hmax + 8, seed)
    base = hmax + 5
    n = max(5, w // 2)
    for k in range(n):
        x = 3 + int(w * (k + rng.random() * 0.8) / n)
        h = rng.randint(max(3, hmax // 3), hmax)
        lean = (x - (3 + w / 2)) / (w / 2.0) * rng.uniform(0.6, 1.2) + rng.uniform(-0.4, 0.4)
        blade(c, x, base, h, lean, pal['M'] if rng.random() < 0.6 else pal['D'], pal['H'] if rng.random() < 0.6 else pal['L'], rng)
    for _ in range(2):                                          # a little clover / broad leaf at the foot
        leaf(c, 3 + rng.randrange(w), base - 1, 3, pal, rng)
    if flowers:
        for _ in range(rng.randint(1, 3)):
            x = 3 + rng.randrange(1, w - 1)
            h = rng.randint(hmax // 2, hmax)
            for j in range(h):
                c.put(x, base - j, pal['L'])
            flower(c, x, base - h - 1, rng.choice(flowers), rng, big=rng.random() < 0.5)
    out[name] = dict(kind='tuft', pin='bottom', img=crop(c, keep_bottom=True))


def wildflowers(name, seed, out):
    rng = random.Random(seed)
    pal = P(rng.choice(GREENS))
    c = new(26, 40, seed)
    base = 37
    col = rng.choice(FLOWERS)
    for k in range(rng.randint(3, 6)):
        x = 4 + rng.randrange(18)
        h = rng.randint(14, 30)
        lean = rng.uniform(-1.2, 1.2)
        for j in range(h):
            t = j / max(1, h - 1)
            c.put(x + int(round(lean * t * t * 3)), base - j, pal['M'] if j % 5 else pal['L'])
            if j and j % 6 == 0:
                leaf(c, x + int(round(lean * t * t * 3)) + rng.choice((-2, 2)), base - j, 3, pal, rng)
        hx = x + int(round(lean * 3))
        flower(c, hx, base - h - 1, col if rng.random() < 0.7 else rng.choice(FLOWERS), rng, big=True)
    for _ in range(4):
        leaf(c, 4 + rng.randrange(18), base - rng.randint(0, 2), 4, pal, rng)
    out[name] = dict(kind='flower', pin='bottom', img=crop(c, keep_bottom=True))


def _fern_into(c, bx, by, n, ln, pal, rng):
    for k in range(n):
        spread = (k - (n - 1) / 2.0) / max(0.5, (n - 1) / 2.0)          # -1 .. 1 across the crown
        ang0 = math.radians(-90 + spread * 62 + rng.uniform(-7, 7))       # fan out of the crown
        L = ln * rng.uniform(0.75, 1.0) * (1.0 - 0.18 * abs(spread))
        pts = []
        for i in range(1, int(L) + 1):
            t = i / L
            x = bx + math.cos(ang0) * i * 1.05 + spread * t * t * L * 0.5
            y = by + math.sin(ang0) * i - (t * t) * L * 0.15 + t * t * t * L * 0.5 * (0.4 + abs(spread))
            pts.append((int(round(x)), int(round(y))))
        for a_, b_ in zip(pts, pts[1:]):
            c.line(a_[0], a_[1], b_[0], b_[1], pal['D'])
        for i, (px, py) in enumerate(pts[2:], 2):
            t = i / max(1, len(pts))
            sz = max(1, int(round(4.2 * (1 - t) + 1)))
            col_a, col_b = (pal['M'], pal['L']) if t > 0.25 else (pal['D'], pal['M'])
            for s_ in (-1, 1):
                for j in range(sz):
                    c.put(px + s_ * (j + 1), py + (1 if j > 1 else 0), col_a if (i + j) % 2 else col_b)
                if sz >= 3:
                    c.put(px + s_ * sz, py, pal['H'] if i % 2 else col_b)


def fern(name, seed, n, ln, out):
    rng = random.Random(seed)
    pal = P(rng.choice(GREENS))
    W = ln * 2 + 12
    c = new(W, ln + 16, seed)
    _fern_into(c, W // 2, ln + 13, n, ln, pal, rng)
    out[name] = dict(kind='fern', pin='bottom', img=crop(c, keep_bottom=True))


def shrub(name, seed, w, h, out, flowered=False, dry=False):
    rng = random.Random(seed)
    pal = P(DRY if dry else rng.choice(GREENS))
    c = new(w + 8, h + 8, seed)
    cx, base = (w + 8) // 2, h + 6
    # a few short woody stems at the foot, mostly hidden
    for k in range(rng.randint(3, 5)):
        ang = math.radians(-90 + rng.uniform(-50, 50))
        L = h * rng.uniform(0.18, 0.3)
        x, y = cx + rng.randint(-3, 3), base
        for i in range(int(L)):
            x += math.cos(ang) * 1.0
            y += math.sin(ang) * 1.0
            c.put(int(x), int(y), WOOD[0] if i % 3 else WOOD[1])
    # the crown is 3-5 overlapping LUMPS (an irregular silhouette, not one dome), broadest low down
    lumps = []
    for k in range(rng.randint(3, 5)):
        lx = cx + rng.uniform(-0.32, 0.32) * w
        ly = base - h * rng.uniform(0.28, 0.62)
        lr = w * rng.uniform(0.2, 0.32)
        lumps.append((lx, ly, lr, lr * rng.uniform(0.75, 1.1)))
    lumps.append((cx, base - h * 0.2, w * 0.46, h * 0.22))              # the skirt, sitting on the floor
    leaves = int(w * h / 2.6)
    for i in range(leaves):
        lx, ly, rx, ry = lumps[rng.randrange(len(lumps))]
        u = rng.random() ** 0.55
        a = rng.uniform(0, 2 * math.pi)
        x = lx + math.cos(a) * rx * u
        y = ly + math.sin(a) * ry * u
        if y > base - 1:
            continue
        lightness = (-(x - cx) / max(1.0, w * 0.5) * 0.45 + (base - y) / h * 0.95 + rng.uniform(-0.12, 0.12))
        p2 = dict(pal)
        if lightness < 0.42:
            p2 = {'D': pal['D'], 'M': pal['D'], 'L': pal['M'], 'H': pal['L']}
        elif lightness > 0.95:
            p2 = {'D': pal['M'], 'M': pal['L'], 'L': pal['H'], 'H': pal['H']}
        leaf(c, x, y, rng.choice((3, 4, 4, 5)), p2, rng)
    if flowered:
        col = rng.choice(FLOWERS)
        for _ in range(rng.randint(6, 12)):
            lx, ly, rx, ry = lumps[rng.randrange(len(lumps) - 1)]
            a = rng.uniform(math.pi * 1.05, math.pi * 1.95)
            u = rng.uniform(0.35, 0.95)
            flower(c, lx + math.cos(a) * rx * u, ly + math.sin(a) * ry * u, col, rng, big=True)
    out[name] = dict(kind='shrub', pin='bottom', img=crop(c, keep_bottom=True))


# -------------------------------------------------------------------------------------------- houseplants
POTS = [('b5623c', 'ce7a4c'), ('e6e0d2', 'ffffff'), ('5a6a7a', '7a8ea0'), ('3a3a40', '55555c'), ('2f5f6f', '4a8496')]


def pot_body(c, cx, base, pw, ph, colpair):
    body, hi = hexc(colpair[0]), hexc(colpair[1])
    for j in range(ph):
        t = j / max(1, ph - 1)
        half = pw // 2 - int(round(t * 2))
        for x in range(cx - half, cx + half + 1):
            edge_l = x == cx - half
            edge_r = x == cx + half
            col = shade(body, 1.18) if x < cx - half // 2 else (shade(body, 0.72) if edge_r or x > cx + half // 2 else body)
            if edge_l:
                col = hi
            c.put(x, base - j, col)
    rim = pw // 2 + 1
    for x in range(cx - rim, cx + rim + 1):
        c.put(x, base - ph, shade(body, 1.3))
        c.put(x, base - ph - 1, shade(body, 0.95))
    for x in range(cx - pw // 2 + 2, cx + pw // 2 - 1):
        c.put(x, base - ph - 2, hexc('2a1f16'))                    # the soil, just showing
    c.hline(cx - pw // 2 + 1, cx + pw // 2 - 1, base + 1, hexc('1a1410'))     # a contact line


def potted(name, seed, style, out):
    """A houseplant in its pot: the same greens as the wild growth, but tended — until it isn't."""
    rng = random.Random(seed)
    pal = P(DRY if style == 'dead' else rng.choice(GREENS))
    c = new(46, 72, seed)
    cx, base = 23, 70
    pw = rng.choice((11, 12, 13))
    ph = rng.choice((8, 9, 10))
    pot_body(c, cx, base, pw, ph, rng.choice(POTS))
    top = base - ph - 2
    if style == 'fern':
        _fern_into(c, cx, top, rng.randint(6, 8), rng.randint(15, 20), pal, rng)
    elif style == 'flowers':
        col = rng.choice(FLOWERS)
        for k in range(rng.randint(7, 11)):
            a = rng.uniform(-1.15, 1.15)
            ln = rng.randint(10, 20)
            x, y = float(cx), float(top)
            for i in range(ln):
                x += math.sin(a) * 0.9
                y -= 0.9
                c.put(int(x), int(y), pal['M'])
            leaf(c, x - (1 if a > 0 else -1) * 2, y + ln // 2, 4, pal, rng)
            flower(c, x, y - 1, col if rng.random() < 0.75 else rng.choice(FLOWERS), rng, big=True)
        for _ in range(9):
            leaf(c, cx + rng.randint(-8, 8), top - rng.randint(0, 5), 4, pal, rng)
    elif style == 'tall':
        x = float(cx)
        for i in range(rng.randint(30, 40)):
            x += rng.uniform(-0.15, 0.15)
            c.put(int(x), top - i, WOOD[1] if i % 4 else WOOD[0])
        for k in range(rng.randint(9, 13)):
            i = 12 + k * 2
            side = 1 if k % 2 else -1
            leaf(c, x + side * rng.randint(3, 6), top - i + rng.randint(-1, 1), 6, pal, rng, k=rng.choice((0, 1, 2, 3)))
    else:                                                       # dead: a few dry stalks over the rim
        for k in range(rng.randint(5, 8)):
            a = rng.uniform(-1.0, 1.0)
            x, y = float(cx), float(top)
            for i in range(rng.randint(8, 16)):
                x += math.sin(a) * 0.8 + (0.06 * i * (1 if a > 0 else -1) if i > 5 else 0)
                y -= 0.85 if i < 8 else 0.4
                c.put(int(x), int(y), pal['M'] if i % 3 else pal['D'])
            leaf(c, x, y, 3, pal, rng)
    out[name] = dict(kind='potted', pin='bottom', img=crop(c, keep_bottom=True))


# ------------------------------------------------------------------------------------------- static things
def roots(name, seed, w, out):
    rng = random.Random(seed)
    c = new(w, 16, seed)
    y0 = 9
    crack = hexc('1c1712')
    x = 2
    for i in range(w - 4):                                      # the crack in the floor
        y = y0 + int(round(math.sin(i / 6.0 + seed) * 1.5))
        c.put(x + i, y + 2, crack)
        if i % 5 == 0:
            c.put(x + i, y + 3, shade(crack, 1.6))
    for k in range(rng.randint(2, 4)):
        x0 = rng.randint(4, w - 12)
        thick = rng.choice((2, 2, 3))
        ang = rng.uniform(-0.5, 0.5)
        xx, yy = float(x0), float(y0 + 1)
        for i in range(rng.randint(14, 30)):
            ang += rng.uniform(-0.25, 0.25)
            xx += math.cos(ang) * (1 if rng.random() < 0.6 else 0) * rng.choice((-1, 1, 1))
            yy += math.sin(ang) * 0.35 - 0.05
            t = i / 30.0
            wdt = max(1, int(round(thick * (1.0 - t))))
            for j in range(wdt):
                c.put(int(xx), int(yy) - j, WOOD[1] if j else WOOD[2])
            c.put(int(xx), int(yy) + 1, WOOD[0])
            if rng.random() < 0.07:
                c.put(int(xx) + rng.choice((-1, 1)), int(yy) - wdt - 1, WOOD[1])
    pal = P(rng.choice(GREENS))
    for _ in range(rng.randint(1, 3)):                          # a shoot from the crack
        x = rng.randrange(6, w - 6)
        for j in range(rng.randint(4, 8)):
            c.put(x, y0 - j, pal['L'])
        leaf(c, x, y0 - 8, 4, pal, rng)
    out[name] = dict(kind='roots', pin='none', img=crop(c, keep_bottom=True))


def moss(name, seed, w, h, out, wall=True):
    rng = random.Random(seed)
    pal = P(rng.choice(GREENS))
    c = new(w, h, seed)
    cells = set()
    for _ in range(max(3, w // 5)):
        cx = rng.randrange(3, w - 3)
        cy = h - 1 - (rng.randrange(0, max(1, h // 2)) if wall else rng.randrange(0, max(1, h - 2)))
        rx, ry = rng.randint(3, 8), rng.randint(2, max(3, h // 3))
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    cells.add((x, y))
    for (x, y) in cells:
        if not (0 <= x < w and 0 <= y < h):
            continue
        edge = any((x + dx, y + dy) not in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge and rng.random() < 0.45:
            continue
        r = rng.random()
        col = pal['D'] if edge else (pal['M'] if r < 0.55 else (pal['L'] if r < 0.9 else pal['H']))
        c.put(x, y, col)
    out[name] = dict(kind='moss', pin='none', img=crop(c, keep_bottom=True))


def fungus(name, seed, kind, out):
    rng = random.Random(seed)
    c = new(30, 22, seed)
    cap = hexc(rng.choice(['c98a3a', 'd8c8a0', 'b06a44', 'e0dcc8']))
    under = shade(cap, 0.55)
    if kind == 'bracket':                                        # stacked shelves off a wall
        for k in range(rng.randint(2, 4)):
            x, y = 5 + k * 3 + rng.randint(0, 3), 4 + k * 5
            w = rng.randint(7, 12)
            for i in range(w):
                t = i / max(1, w - 1)
                top = y - int(round(2.2 * math.sin(t * math.pi)))
                c.put(x + i, top, shade(cap, 1.25))
                c.put(x + i, top + 1, cap)
                c.put(x + i, top + 2, under)
    else:                                                        # toadstools on the floor
        for k in range(rng.randint(2, 4)):
            x = 4 + k * 6 + rng.randint(0, 2)
            h = rng.randint(4, 8)
            rw = rng.randint(3, 5)
            for j in range(h):
                c.put(x, 20 - j, hexc('d8d2bc'))
                c.put(x + 1, 20 - j, shade(hexc('d8d2bc'), 0.8))
            for dx in range(-rw, rw + 2):
                dy = int(round(2.5 * (1 - (dx / (rw + 1.0)) ** 2)))
                for j in range(max(1, dy)):
                    c.put(x + dx, 20 - h - j, shade(cap, 1.2) if j == dy - 1 else cap)
                c.put(x + dx, 20 - h + 1, under)
            if rng.random() < 0.6:
                c.put(x, 20 - h - 1, hexc('f0ecd8'))
    out[name] = dict(kind='fungus', pin='none', img=crop(c, keep_bottom=True))


# ---------------------------------------------------------------------------------------------- build all
def build():
    out = {}
    for i, k in enumerate(['single', 'single', 'pair', 'pair', 'cluster', 'cluster', 'curtain', 'dry']):
        hang_vine('hang_%d' % (i + 1), 100 + i, k, out)
    for i, (w, h, d) in enumerate([(30, 44, 0.5), (36, 58, 0.7), (44, 72, 0.9), (28, 40, 0.4), (52, 80, 1.0), (40, 64, 0.8)]):
        creeper('creeper_%d' % (i + 1), 200 + i, w, h, d, out)
    creeper('creeper_dry_1', 260, 36, 56, 0.6, out, dry=True)
    for i, (w, h, fl) in enumerate([(12, 9, None), (16, 12, None), (20, 14, [FLOWERS[0], FLOWERS[1]]), (14, 10, None),
                                    (26, 16, [FLOWERS[1], FLOWERS[2], FLOWERS[3]]), (18, 14, [FLOWERS[0]])]):
        tuft('tuft_%d' % (i + 1), 300 + i, w, h, out, flowers=fl)
    tuft('tuft_dry_1', 340, 14, 10, out, dry=True)
    for i in range(4):
        wildflowers('flower_%d' % (i + 1), 400 + i, out)
    for i, (n, ln) in enumerate([(5, 14), (7, 20), (6, 26), (8, 30)]):
        fern('fern_%d' % (i + 1), 500 + i, n, ln, out)
    for i, (w, h, fl) in enumerate([(30, 36, False), (40, 48, False), (48, 60, False), (36, 44, True), (56, 70, False), (44, 56, True)]):
        shrub('shrub_%d' % (i + 1), 600 + i, w, h, out, flowered=fl)
    shrub('shrub_dry_1', 660, 36, 44, out, dry=True)
    for i, (w, h, fl) in enumerate([(18, 20, False), (22, 24, True), (26, 26, False), (20, 22, True)]):    # small ones, for balconies
        shrub('shrub_small_%d' % (i + 1), 680 + i, w, h, out, flowered=fl)
    for i, w in enumerate([48, 64, 80]):
        roots('roots_%d' % (i + 1), 700 + i, w, out)
    for i, (w, h, wall) in enumerate([(30, 14, True), (44, 18, True), (26, 10, False), (38, 12, False)]):
        moss('moss_%d' % (i + 1), 800 + i, w, h, out, wall=wall)
    for i, k in enumerate(['bracket', 'bracket', 'stool', 'stool']):
        fungus('fungus_%d' % (i + 1), 900 + i, k, out)
    for i, st in enumerate(['fern', 'fern', 'flowers', 'flowers', 'flowers', 'tall', 'tall', 'dead', 'dead']):
        potted('pot_%s_%d' % (st, i + 1), 1000 + i, st, out)
    return out


# What may MOVE in a draught (owner round 34 — "no, we just want some leaves, or cloths, or things that might drape"):
# kinds that cling, are rigid or are static never do, and anything dry or dead has nothing left to catch the wind. The pin
# is what scripts/sway.gd (`growth_spec`) reads: "none" = still.
STILL_KINDS = ('creeper', 'shrub', 'roots', 'moss', 'fungus')


def pin_for(name, d):
    if d['kind'] in STILL_KINDS or 'dry' in name or 'dead' in name:
        return 'none'
    return d['pin']


def main():
    os.makedirs(OUT, exist_ok=True)
    sprites = build()
    meta = {}
    for name, d in sprites.items():
        d['img'].save(os.path.join(OUT, name + '.png'))
        meta[name] = dict(kind=d['kind'], pin=pin_for(name, d), w=d['img'].width, h=d['img'].height)
    with open(os.path.join(OUT, 'growth.json'), 'w') as fh:
        json.dump({'note': 'written by tools/art/growth.py — sprite -> kind / pin / size', 'sprites': meta}, fh, indent=1, sort_keys=True)
    # a contact sheet: every sprite at 3x on a wall-ish ground, grouped by kind
    order = ['hang', 'creeper', 'tuft', 'flower', 'fern', 'shrub', 'roots', 'moss', 'fungus', 'potted']
    rows = []
    for kind in order:
        rows.append([(n, d['img']) for n, d in sprites.items() if d['kind'] == kind])
    S = 3
    W = 1200
    y = 8
    sheet = Image.new('RGBA', (W, 2400), (70, 84, 76, 255))
    for row in rows:
        x, rh = 8, 0
        for n, im in row:
            big = im.resize((im.width * S, im.height * S), Image.NEAREST)
            if x + big.width > W - 8:
                y += rh + 10
                x, rh = 8, 0
            sheet.alpha_composite(big, (x, y))
            x += big.width + 10
            rh = max(rh, big.height)
        y += rh + 14
    sheet = sheet.crop((0, 0, W, y + 4))
    p = os.path.join(ROOT, 'docs', 'art_reference', 'growth.png')
    sheet.save(p)
    print('wrote %d sprites -> %s, sheet %s' % (len(meta), OUT, p))


if __name__ == '__main__':
    main()
