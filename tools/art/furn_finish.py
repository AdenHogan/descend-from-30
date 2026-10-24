"""SURFACE FINISH for furniture that is built from big flat faces (owner round 48h: "no flat drawings anywhere").

A cabinet, a fridge, a table is drawn as a few big colour fields, and a colour field with a hard outline reads as a painted-on slab. Real objects catch light on their edges: the
upper-left edge of every face is lit, the lower-right edge sits in shade, a flat panel is a hair lighter at the top than at the foot, and a grain or a fleck runs through it.
These helpers add exactly that — and nothing else — to a finished sprite, so one pass lifts a whole family of pieces without redrawing their shapes.

    rimlight(c)            lit upper-left / shaded lower-right edge on every opaque face (inside the outline)
    vertical_falloff(c)    each opaque column fades a little from its top pixel to its bottom pixel (a lit top, a shaded foot)
    grain(c, col, seed)    a faint run of lighter / darker flecks along every large flat area, so a wide panel is not one colour
"""
import random

from pixlib import hexc, shade


def _lum(p):
    return (0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]) / 255.0


def outline_lum(c):
    """The luminance below which a pixel is the sprite's OUTLINE rather than a surface: well under the median of its opaque pixels (so a dark-wood chair's brown is a surface, its near-black edge is not)."""
    ls = sorted(_lum(c.px[x, y]) for y in range(c.h) for x in range(c.w) if c.px[x, y][3] == 255)
    if not ls:
        return 0.1
    return max(0.03, min(0.14, 0.5 * ls[len(ls) // 2]))


def rimlight(c, lit=1.16, dark=0.82, min_lum=None, region=None, lift=0):
    """Lighten every opaque pixel whose up- or left-neighbour is empty or an outline (very dark), and darken every one whose down- or right-neighbour is. An outline pixel itself is left alone."""
    px = c.px
    w, h = c.w, c.h
    min_lum = outline_lum(c) if min_lum is None else min_lum
    x0, y0, x1, y1 = region or (0, 0, w - 1, h - 1)
    ups = []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            p = px[x, y]
            if p[3] < 255 or _lum(p) < min_lum:
                continue

            def edge(nx, ny):
                if not (0 <= nx < w and 0 <= ny < h):
                    return True
                q = px[nx, ny]
                return q[3] < 200 or (q[3] == 255 and _lum(q) < min_lum * 0.8)
            up, left, down, right = edge(x, y - 1), edge(x - 1, y), edge(x, y + 1), edge(x + 1, y)
            f = 1.0
            if up or left:
                f *= lit
            if down or right:
                f *= dark
            if f != 1.0:
                col = shade(p, f)
                if lift and (up or left) and not (down or right):                       # a dark material has little to multiply: lift its lit edge by a fixed amount instead
                    col = tuple(min(255, col[i] + lift) for i in range(3)) + (255,)
                ups.append((x, y, col))
    for (x, y, col) in ups:
        px[x, y] = col


def vertical_falloff(c, factors=(1.06, 1.0, 0.93), min_lum=None, region=None):
    """Tilt each column's tone in `len(factors)` bands from its first opaque pixel to its last: a lit top, a plain middle, a shaded foot — banded, not a smooth gradient, so it stays pixel art."""
    px = c.px
    w, h = c.w, c.h
    min_lum = outline_lum(c) if min_lum is None else min_lum
    x0, y0, x1, y1 = region or (0, 0, w - 1, h - 1)
    n = len(factors)
    for x in range(x0, x1 + 1):
        ys = [y for y in range(y0, y1 + 1) if px[x, y][3] == 255 and _lum(px[x, y]) >= min_lum]
        if len(ys) < 2 * n:
            continue
        a_, b_ = ys[0], ys[-1]
        for y in ys:
            k = min(n - 1, int(n * (y - a_) / float(max(1, b_ - a_ + 1))))
            px[x, y] = shade(px[x, y], factors[k])


def rug_pile(c, seed=1, amount=0.05, front=0.70):
    """A rug's pile: threads of slightly different tone in short runs (3 px, along the weave), the front edge a darker face (the rug has thickness) and its far edge a hair lighter."""
    rng = random.Random(seed)
    px = c.px
    w, h = c.w, c.h
    for y in range(h):
        x = 0
        while x < w:
            if px[x, y][3] != 255:
                x += 1
                continue
            run = rng.randint(2, 4)
            f = 1.0 + amount * rng.choice((-1.5, -0.8, 0.0, 0.0, 0.8, 1.5))
            for xx in range(x, min(w, x + run)):
                if px[xx, y][3] == 255:
                    px[xx, y] = shade(px[xx, y], f)
            x += run
    for x in range(w):
        ys = [y for y in range(h) if px[x, y][3] == 255]
        if len(ys) >= 3:
            px[x, ys[-1]] = shade(px[x, ys[-1]], front)                                 # the rug's thick front edge
            px[x, ys[0]] = shade(px[x, ys[0]], 1.12)


def grain(c, seed=1, amount=0.04, region=None, min_run=7, min_lum=None, prob=0.20):
    """Sparse lighter / darker flecks along long runs of one colour (a panel's wood grain or laminate): short horizontal dashes, never on every row."""
    rng = random.Random(seed)
    px = c.px
    w, h = c.w, c.h
    min_lum = outline_lum(c) if min_lum is None else min_lum
    x0, y0, x1, y1 = region or (0, 0, w - 1, h - 1)
    for y in range(y0, y1 + 1):
        x = x0
        while x <= x1:
            p = px[x, y]
            if p[3] != 255 or _lum(p) < min_lum:
                x += 1
                continue
            e = x
            while e + 1 <= x1 and px[e + 1, y][:3] == p[:3] and px[e + 1, y][3] == 255:
                e += 1
            if e - x + 1 >= min_run and rng.random() < prob:
                a = x + rng.randint(1, max(1, (e - x) // 2))
                b = min(e - 1, a + rng.randint(2, 4))
                f = 1.0 + amount * (1 if rng.random() < 0.5 else -1.4)
                for xx in range(a, b + 1):
                    px[xx, y] = shade(px[xx, y], f)
            x = e + 1


# the finishing recipe of each piece that needs one: piece id -> a function (canvas) applied after the piece is drawn (furnlib.render)
def _slab(c, bands=(1.04, 1.0, 0.96), lit=1.14, dark=0.84, seed=1, grain_amount=0.04):
    vertical_falloff(c, bands)
    rimlight(c, lit, dark)
    grain(c, seed, grain_amount)


FINISH = {
    'fridge_tall': lambda c: rimlight(c, 1.08, 0.86),
    'filing_cabinet': lambda c: _slab(c, seed=4),
    'side_table': lambda c: _slab(c, seed=5),
    'sideboard': lambda c: _slab(c, seed=6),
    'wardrobe_small': lambda c: _slab(c, seed=7),
    'washstand': lambda c: _slab(c, seed=8),
    'desk_study': lambda c: _slab(c, seed=9),
    'coffee_table': lambda c: _slab(c, seed=10),
    'easel': lambda c: _slab(c, seed=11),
    'table_dining': lambda c: _slab(c, seed=12),
    'chair_wood': lambda c: (vertical_falloff(c, (1.03, 1.0, 0.95, 0.90)), rimlight(c, 1.30, 0.80, lift=22), grain(c, 13, 0.10, min_run=3, prob=0.85)),
    'chair_child': lambda c: (rimlight(c, 1.30, 0.80, lift=18), grain(c, 14, 0.09, min_run=3, prob=0.5)),
    'chair_office': lambda c: (rimlight(c, 1.55, 0.85, lift=34), grain(c, 15, 0.14, min_run=3, prob=0.5)),
    'rug_oblong': lambda c: rug_pile(c, 21),
    'rug_large': lambda c: rug_pile(c, 22),
    'bath_mat': lambda c: rug_pile(c, 23, 0.06, 0.74),
    'wall_cupboards': lambda c: (rimlight(c, 1.12, 0.86), grain(c, 24, 0.05)),
    'champagne_stand': lambda c: (vertical_falloff(c, (1.10, 1.0, 0.88)), rimlight(c, 1.25, 0.80)),
    'laundry_basket3d': lambda c: (vertical_falloff(c, (1.08, 1.0, 0.90)), rimlight(c, 1.22, 0.80)),
}


def apply(pid, c):
    fn = FINISH.get(pid)
    if fn is not None:
        fn(c)
