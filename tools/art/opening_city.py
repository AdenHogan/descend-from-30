#!/usr/bin/env python3
"""THE OPENING'S SKYLINE (owner round 49 — "buildings… too many similarities that will make people say AI").

What the old skyline was: towers = rectangles of random width, each a tint of ONE colour (violet by dusk, navy at night), a random grid
of dark / lit window dots, and the same three roof props (a stepped crown, an antenna, a water tank) picked by a die. Every Claude-made
sunset platformer has that skyline.

What this is: a CITY — building TYPES that a person can name, each drawn as itself, in real materials:
    SLAB      a long residential slab with deck-access galleries (a continuous light line every floor), a taller stair core at one end
              with slit windows, a lift motor house on the roof;
    TOWER     a curtain-wall or concrete block, vertical mullions, a setback, roof plant;
    TERRACE   a run of pitched-roof houses in brick / render, a chimney stack on every party wall, slate or tile;
    CHURCH    a nave with a gable and a square tower, a clock, a spire;
    GASHOLDER a drum in its steel guide frame, cross-braced;
    STACK     a tall brick chimney with two pale bands;  COOLING a pair of hyperbolic cooling towers;
and in the far layer, smoke COLUMNS leaning one way (the afternoon, the night) that grow out of particular roofs.

It is ONE city: the plan is a pure function of (layer), never of the run — the same streets by morning, afternoon and night; only the
light on it changes (a per-run grade, then the layer's haze), and the lit windows are drawn LAST so a lamp stays a lamp.
Materials are real (brick, dark brick, concrete, cream render, grey render, glass) — not one hue per time of day.
"""
import math
import random

from PIL import Image

import opening_sky as K
from pixlib import Canvas, hexc, mix, shade

MATERIALS = {
    'brick': ('9a5a45', 'b36e53', '74402f'),
    'dbrick': ('6f4a3f', '86584a', '52332a'),
    'concrete': ('9b9b94', 'b3b3aa', '797973'),
    'cream': ('cdc3a6', 'e0d7bb', 'a89e83'),
    'grey': ('8c9298', 'a5abb1', '6c7279'),
    'glass': ('6f8794', '8fa6b1', '52666d'),
}
ROOFS = {'slate': ('4a4f5a', '5f6573', '363a44'), 'tile': ('9b4f3a', 'b6634a', '773c2c')}
WINDOW = hexc('353b46')
CURTAIN = (hexc('b9a98a'), hexc('a48c7a'), hexc('8d9a90'))

# what each time of day does to the SAME city: a light (multiply), a saturation, and each layer's haze (colour, strength)
GRADE = {
    1: dict(mul=(0.99, 1.00, 1.03), sat=0.80, far=('dfe0d6', 0.52), mid=('d6d8ce', 0.16)),
    2: dict(mul=(1.08, 0.98, 0.80), sat=0.90, far=('d2bb78', 0.52), mid=('c8b070', 0.18)),
    3: dict(mul=(0.30, 0.27, 0.26), sat=0.55, far=('2a160d', 0.55), mid=('1e110b', 0.22)),
}
LIT = {1: ('ffe3a0', 'fff0c4'), 2: ('ffcf72', 'ffe6a0'), 3: ('f0b857', 'ffd98a')}
SMOKE = {2: ('2c2622', '3d352f', '544a40', '6e6253'), 3: ('0e0b0a', '1d1512', '33231a', '4a2d1e')}


def m3(name):
    return tuple(hexc(h) for h in MATERIALS[name])


def r3(name):
    return tuple(hexc(h) for h in ROOFS[name])


class Plan:
    """Collects what the game needs to know and what to draw last."""

    def __init__(self):
        self.lit = []                  # (x, y, w, h) windows that are lamps (drawn after the grade and haze)
        self.fire = []                 # roofs a fire may burn on
        self.smoke = []                # roofs a thin plume may rise from
        self.beacon = []               # masts with a red light
        self.roots = []                # (x, y, h) roofs tall enough to root a column


# ------------------------------------------------------------------------------------------------------------- the types
def slab(c, rng, pl, x, ground, w, h, mat, lit_p):
    col, hi, lo = m3(mat)
    top = ground - h
    core_w = 6
    c.rect(x, top, x + w - 1, ground, col)
    c.vline(x, top, ground, hi)
    c.vline(x + w - 1, top + 1, ground, lo)
    c.hline(x, x + w - 1, top, hi)
    c.hline(x, x + w - 1, top + 1, shade(col, 1.06))
    deck = 4
    floors = (h - 4) // deck
    for f in range(floors):
        y = top + 4 + f * deck
        c.hline(x + 1, x + w - core_w - 1, y + 2, shade(col, 1.10))                       # the deck: a light gallery line
        c.hline(x + 1, x + w - core_w - 1, y + 3, shade(col, 0.82))                       # and the shadow under it
        for wx in range(x + 2, x + w - core_w - 2, 4):
            r = rng.random()
            if r < 0.78:
                c.put(wx, y, WINDOW)
                c.put(wx + 1, y, WINDOW)
                c.put(wx, y + 1, WINDOW)
                c.put(wx + 1, y + 1, WINDOW)
                if r < lit_p:
                    pl.lit.append((wx, y, 2, 2))
                elif r > 0.62:
                    k = CURTAIN[int(r * 100) % 3]
                    c.put(wx, y, k)
                    c.put(wx, y + 1, k)
            if rng.random() < 0.06:                                                        # a balcony rail break
                c.put(wx + 2, y + 2, shade(hi, 0.9))
    cx0 = x + w - core_w                                                                   # the stair core: taller, slit windows
    c.rect(cx0, top - 5, x + w - 1, ground, shade(col, 0.90))
    c.vline(cx0, top - 5, ground, shade(col, 1.04))
    c.hline(cx0, x + w - 1, top - 5, shade(col, 1.12))
    for wy in range(top - 2, ground - 3, 4):
        c.vline(cx0 + 2, wy, wy + 2, WINDOW)
    mx = x + rng.randrange(2, max(3, w - core_w - 6))                                      # the lift motor house
    c.rect(mx, top - 3, mx + 4, top - 1, shade(col, 0.88))
    c.hline(mx, mx + 4, top - 3, shade(col, 1.15))
    pl.fire.append((x + w // 2, top + 1))
    pl.smoke.append((x + w // 2, top))
    pl.roots.append((x + w - 3, top - 5, h))


def tower(c, rng, pl, x, ground, w, h, mat, lit_p, tier=True):
    col, hi, lo = m3(mat)
    top = ground - h
    c.rect(x, top, x + w - 1, ground, col)
    c.vline(x, top, ground, hi)
    c.vline(x + w - 1, top + 1, ground, lo)
    c.hline(x, x + w - 1, top, hi)
    step = 3 if mat == 'glass' else 4
    for mx in range(x + 2, x + w - 1, step):                                              # vertical mullions
        c.vline(mx, top + 3, ground - 2, shade(col, 0.86 if mat == 'glass' else 0.90))
    for wy in range(top + 5, ground - 3, 5):                                               # spandrels
        c.hline(x + 1, x + w - 2, wy, shade(col, 0.80))
        for mx in range(x + 1, x + w - 2, step):
            if rng.random() < 0.52:
                c.put(mx, wy + 1, WINDOW if mat != 'glass' else shade(hi, 0.85))
                c.put(mx, wy + 2, WINDOW if mat != 'glass' else shade(hi, 0.85))
                if rng.random() < lit_p:
                    pl.lit.append((mx, wy + 1, 1, 2))
    top2 = top
    if tier and w >= 16 and h > 56:                                                         # a setback crown
        tw = w - 8
        th = max(8, h // 6)
        c.rect(x + 4, top - th, x + 4 + tw - 1, top, shade(col, 0.96))
        c.vline(x + 4, top - th, top, hi)
        c.hline(x + 4, x + 4 + tw - 1, top - th, hi)
        for mx in range(x + 6, x + 4 + tw - 1, step):
            c.vline(mx, top - th + 2, top - 2, shade(col, 0.84))
        top2 = top - th
    r = rng.random()
    if r < 0.5:                                                                             # plant: two boxes and a flue
        c.rect(x + 2, top2 - 3, x + 6, top2 - 1, shade(col, 0.86))
        c.rect(x + w - 8, top2 - 2, x + w - 4, top2 - 1, shade(col, 0.78))
        c.vline(x + w - 6, top2 - 6, top2 - 3, shade(lo, 0.9))
    else:                                                                                   # a mast
        ax = x + w // 2
        c.vline(ax, top2 - 12, top2 - 1, lo)
        c.hline(ax - 1, ax + 1, top2 - 9, lo)
        pl.beacon.append((ax, top2 - 12))
    pl.fire.append((x + w // 2, top2 + 1))
    pl.smoke.append((x + w // 2, top2))
    pl.roots.append((x + w // 2, top2, h))


def terrace(c, rng, pl, x, ground, n, uw, uh, lit_p):
    roof = r3('slate' if rng.random() < 0.6 else 'tile')
    for i in range(n):
        ux = x + i * uw
        wall = m3(('brick', 'cream', 'dbrick', 'grey')[(i + rng.randrange(0, 2)) % 4])
        col, hi, lo = wall
        h = uh + rng.choice((-1, 0, 0, 1))
        top = ground - h
        c.rect(ux, top, ux + uw - 1, ground, col)
        c.vline(ux, top, ground, hi)
        c.vline(ux + uw - 1, top, ground, lo)
        rh = uw // 2 + 2                                                                    # the gable roof
        pts = [(ux - 1, top), (ux + uw // 2, top - rh), (ux + uw, top)]
        c.poly(pts, roof[0])
        for k in range(rh):                                                                 # the lit slope on the left, the shaded on the right
            y = top - k - 1
            c.put(ux + k, y + 1, roof[1]) if k < uw // 2 else None
        c.line(ux + uw // 2, top - rh, ux + uw, top, roof[2])
        c.hline(ux - 1, ux + uw, top, shade(roof[0], 0.8))                                   # the eaves
        if i % 2 == 0:                                                                       # a chimney stack on the party wall
            c.rect(ux + uw - 2, top - rh - 2, ux + uw, top - rh + 3, m3('dbrick')[0])
            c.hline(ux + uw - 3, ux + uw + 1, top - rh - 3, shade(m3('dbrick')[1], 1.1))
            c.put(ux + uw - 2, top - rh - 5, shade(lo, 0.9))
            c.put(ux + uw, top - rh - 5, shade(lo, 0.9))
        for wy in range(top + 3, ground - 3, 6):
            for wx in (ux + 2, ux + uw - 4):
                if wx + 1 < ux + uw - 1:
                    c.put(wx, wy, WINDOW)
                    c.put(wx + 1, wy, WINDOW)
                    c.put(wx, wy + 1, WINDOW)
                    c.put(wx + 1, wy + 1, WINDOW)
                    c.put(wx, wy + 2, shade(hi, 1.05))
                    if rng.random() < lit_p:
                        pl.lit.append((wx, wy, 2, 2))
        c.rect(ux + uw // 2 - 1, ground - 4, ux + uw // 2, ground, shade(lo, 0.7))        # a door
    pl.fire.append((x + n * uw // 2, ground - uh - 6))


def church(c, rng, pl, x, ground):
    col, hi, lo = m3('grey')
    roof = r3('slate')
    nw, nh = 24, 20
    c.rect(x + 9, ground - nh, x + 9 + nw - 1, ground, col)                                  # the nave
    c.vline(x + 9, ground - nh, ground, hi)
    c.vline(x + 9 + nw - 1, ground - nh, ground, lo)
    c.poly([(x + 8, ground - nh), (x + 9 + nw // 2, ground - nh - 10), (x + 10 + nw, ground - nh)], roof[0])
    c.line(x + 9 + nw // 2, ground - nh - 10, x + 10 + nw, ground - nh, roof[2])
    for wx in range(x + 12, x + 9 + nw - 3, 6):                                              # tall arched windows
        c.rect(wx, ground - 15, wx + 1, ground - 6, WINDOW)
        c.put(wx, ground - 16, WINDOW)
    tw, th = 9, 40
    c.rect(x, ground - th, x + tw - 1, ground, shade(col, 0.96))                             # the tower
    c.vline(x, ground - th, ground, hi)
    c.vline(x + tw - 1, ground - th, ground, lo)
    c.hline(x - 1, x + tw, ground - th, hi)
    c.rect(x + 3, ground - th + 4, x + 5, ground - th + 9, shade(lo, 0.7))                   # the belfry louvres
    for yy in range(ground - th + 5, ground - th + 10, 2):
        c.hline(x + 3, x + 5, yy, shade(hi, 0.9))
    c.rect(x + 3, ground - th + 14, x + 5, ground - th + 16, hexc('d8d2bc'))                  # the clock
    c.put(x + 4, ground - th + 15, shade(lo, 0.6))
    c.poly([(x - 1, ground - th), (x + tw // 2, ground - th - 19), (x + tw, ground - th)], roof[0])    # the spire
    c.line(x + tw // 2, ground - th - 19, x + tw, ground - th, roof[2])
    c.vline(x + tw // 2, ground - th - 23, ground - th - 19, shade(lo, 0.8))
    c.hline(x + tw // 2 - 1, x + tw // 2 + 1, ground - th - 22, shade(lo, 0.8))
    pl.smoke.append((x + 4, ground - th - 20))


def gasholder(c, rng, pl, x, ground, w=34):
    """A gasholder: a steel drum riding up inside a tall guide frame — two lattice columns per side, rungs and cross-braces every bay,
    a ring beam on top — the drum itself half risen with its plate courses and rivet lines."""
    col, hi, lo = hexc('6d7378'), hexc('8b9298'), hexc('474c52')
    fh = 40                                                    # the frame's height
    dh = 16                                                    # the drum is up this far
    for fx in (x, x + w - 3):                                  # the two lattice columns (each a pair of struts)
        c.vline(fx, ground - fh, ground, lo)
        c.vline(fx + 2, ground - fh, ground, lo)
        for yy in range(ground - fh, ground, 6):
            c.hline(fx, fx + 2, yy, lo)
            c.put(fx + 1, yy + 3, shade(lo, 1.1))
    c.hline(x, x + w - 1, ground - fh, lo)                     # the ring beam
    c.hline(x, x + w - 1, ground - fh + 1, shade(lo, 1.25))
    for k in range(0, fh, 8):                                  # cross-braces between the columns
        c.line(x + 3, ground - k, x + w - 4, ground - k - 6, shade(lo, 1.15))
        c.line(x + w - 4, ground - k, x + 3, ground - k - 6, shade(lo, 1.15))
    c.rect(x + 3, ground - dh, x + w - 4, ground, col)         # the drum, inside the frame
    c.vline(x + 3, ground - dh, ground, hi)
    c.vline(x + w - 4, ground - dh, ground, lo)
    c.hline(x + 3, x + w - 4, ground - dh, hi)
    c.hline(x + 3, x + w - 4, ground - dh + 1, shade(hi, 0.86))
    for yy in range(ground - dh + 5, ground, 5):
        c.hline(x + 4, x + w - 5, yy, shade(col, 0.80))
    pl.fire.append((x + w // 2, ground - fh))


def stack(c, rng, pl, x, ground, h=72):
    col, hi, lo = m3('brick')
    for k in range(h):
        y = ground - k
        hw = 3 - (k // 30) * 0 + (1 if k < h // 3 else 0)
        c.hline(x - hw, x + hw, y, col)
        c.put(x - hw, y, hi)
        c.put(x + hw, y, lo)
    for yy in (ground - h + 5, ground - h + 8):                                              # the pale bands
        c.hline(x - 3, x + 3, yy, hexc('d9cdb0'))
    c.hline(x - 4, x + 4, ground - h, shade(hi, 1.1))
    c.rect(x - 14, ground - 14, x - 5, ground, shade(m3('dbrick')[0], 0.95))                  # a boiler house
    c.hline(x - 14, x - 5, ground - 14, m3('dbrick')[1])
    pl.beacon.append((x, ground - h - 1))
    pl.smoke.append((x, ground - h - 1))
    pl.fire.append((x, ground - h))
    pl.roots.append((x, ground - h, h))


def cooling(c, rng, pl, x, ground, w=22, h=46):
    col, hi, lo = hexc('a6a39a'), hexc('c4c1b6'), hexc('77756e')
    for k in range(h):
        y = ground - k
        t = k / float(h)
        hw = w / 2.0 * (0.80 + 0.55 * (t - 0.66) ** 2 * 2.6)
        xl, xr = int(round(x - hw)), int(round(x + hw))
        c.hline(xl, xr, y, col)
        c.put(xl, y, hi)
        c.put(xl + 1, y, hi)
        c.put(xr, y, lo)
        c.put(xr - 1, y, lo)
    c.hline(x - w // 2 + 1, x + w // 2 - 1, ground - h, shade(hi, 1.08))
    pl.smoke.append((x, ground - h))


# ---------------------------------------------------------------------------------------------------------------- columns
def column(img, x0, y0, height, lean, w0, run, seed):
    """A column of smoke leaning one way, rooted on a roof at (x0, y0): a billowing, torn-edged mass from a density field (a core
    that is dark and a rim that lifts as it ages), widening as it climbs, thinning to ragged wisps at the top."""
    import numpy as np
    pal = [hexc(h) for h in SMOKE[run]]
    wmax = int(w0 * 4.2 + abs(lean) * height * 0.42 + 14)
    xs0 = int(x0 - wmax)
    width = wmax * 2 + 6
    ys, xs = np.mgrid[0:height, 0:width].astype(np.float64)
    k = (height - 1 - ys)                                                                 # rows above the root
    t = k / float(height)
    cx = (x0 - xs0) + lean * k * 0.42 + (K.fbm(k * 0.05, np.zeros_like(k) + 4.0, seed, 3) - 0.5) * 9.0 * (0.3 + t)
    half = w0 * (0.9 + 2.9 * t ** 0.72)
    d = np.abs(xs - cx) / np.maximum(half, 0.5)
    billow = K.fbm(xs * 0.11, k * 0.085, seed + 5, 4, 0.55)
    dens = (1.0 - d) + (billow - 0.5) * (0.9 + 0.8 * t) - 0.22 * t
    inside = dens > 0.0
    tone = np.clip(0.35 + (1.0 - np.clip(dens * 1.8, 0, 1)) * 1.7 + t * 1.2 - (billow - 0.5) * 0.8, 0, 3)
    idx = np.rint(tone).astype(int)
    alpha = np.clip(252 - 150 * t ** 1.15, 0, 255).astype(int)
    px = img.load()
    for yy in range(height):
        y = y0 - (height - 1 - yy)
        if y < 0 or y >= img.height:
            continue
        for xx in range(width):
            if not inside[yy, xx]:
                continue
            gx = xs0 + xx
            if not (0 <= gx < img.width):
                continue
            if tone[yy, xx] > 2.4 and (gx + y) % 2:
                continue
            px[gx, y] = pal[idx[yy, xx]][:3] + (int(alpha[yy, xx]),)


# ----------------------------------------------------------------------------------------------------------------- layers
def _plan_layer(layer):
    """The city's layout for one layer: an ordered list of (kind, x, params), a pure function of the layer alone. Landmarks stand at fixed
    places (what the owner sees beside the tower: the flanks 0..78 and 209..288); the streets between them are seeded."""
    rng = random.Random({'far': 5, 'mid': 11}[layer])
    landmarks = ({'far': [(2, 'cooling'), (238, 'church'), (276, 'stack')], 'mid': [(4, 'gasholder')]})[layer]
    out = []
    x = -rng.randrange(0, 6)
    kinds = ('slab', 'tower', 'terrace', 'tower', 'slab', 'terrace')
    while x < 292:
        if landmarks and x >= landmarks[0][0] - 3:
            fx, name = landmarks.pop(0)
            x = max(x, fx)
            if name == 'cooling':
                out.append(('cooling', x + 12, {'w': 22, 'h': 46}))
                out.append(('cooling', x + 38, {'w': 20, 'h': 40}))
                x += 54
            elif name == 'church':
                out.append(('church', x, {}))
                x += 36
            elif name == 'stack':
                out.append(('stack', x + 15, {'h': 70}))
                x += 22
            elif name == 'gasholder':
                out.append(('gasholder', x, {'w': 34}))
                x += 38
            continue
        k = rng.choice(kinds)
        nxt = landmarks[0][0] if landmarks else 999
        if layer == 'far':
            if k == 'terrace':
                k = 'slab'
            w = rng.randrange(16, 30) if k == 'tower' else rng.randrange(30, 56)
            h = rng.randrange(46, 118) if k == 'tower' else rng.randrange(28, 62)
        else:
            if k == 'tower':
                w, h = rng.randrange(16, 24), rng.randrange(56, 146)
            elif k == 'slab':
                w, h = rng.randrange(28, 46), rng.randrange(34, 66)
            else:
                w, h = 0, 0
        if x + max(w, 30) > nxt and nxt - x > 8:                                             # squeeze to fit before the next landmark
            w = max(10, min(w, nxt - x - 2)) if w else 0
            if k in ('slab', 'tower') and w < 12:
                k, w, h = 'tower', max(10, nxt - x - 2), min(h, 60)
        if k == 'terrace':
            n = rng.randrange(3, 6)
            uw = rng.randrange(9, 12)
            while x + n * uw > nxt and n > 2:
                n -= 1
            out.append(('terrace', x, {'n': n, 'uw': uw, 'uh': rng.randrange(16, 24)}))
            x += n * uw + rng.randrange(1, 5)
        else:
            mat = rng.choice(('brick', 'concrete', 'cream', 'grey', 'dbrick') if k == 'slab' else ('glass', 'concrete', 'grey', 'glass'))
            out.append((k, x, {'w': w, 'h': h, 'mat': mat}))
            x += w + rng.randrange(0, 4)
    return out


def _grade(img, g):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, gg, b, a = px[x, y]
            if not a:
                continue
            lum = 0.30 * r + 0.59 * gg + 0.11 * b
            r = lum + (r - lum) * g['sat']
            gg = lum + (gg - lum) * g['sat']
            b = lum + (b - lum) * g['sat']
            px[x, y] = (max(0, min(255, int(r * g['mul'][0]))), max(0, min(255, int(gg * g['mul'][1]))), max(0, min(255, int(b * g['mul'][2]))), a)


def _haze(img, colour, k):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r + (colour[0] - r) * k), int(g + (colour[1] - g) * k), int(b + (colour[2] - b) * k), a)


def skyline(layer, w, h, ground, run, lit_p, sun_gap=None, extras=False, columns=0, low=None):
    """One layer of the city for one run. Returns (image, meta) in the shape the game already reads (`smoke`, `beacon`, `fire`)."""
    rng = random.Random({'far': 105, 'mid': 211}[layer])
    c = Canvas(w, h, seed=7)
    pl = Plan()
    for (kind, x, p) in _plan_layer(layer):
        for zone in ([sun_gap] if sun_gap is not None else []) + (low or []):
            if kind in ('slab', 'tower') and x + p['w'] > zone[0] and x < zone[1]:
                p = dict(p)
                p['h'] = min(p['h'], zone[2])
        if kind == 'slab':
            slab(c, rng, pl, x, ground, p['w'], p['h'], p['mat'], lit_p)
        elif kind == 'tower':
            tower(c, rng, pl, x, ground, p['w'], p['h'], p['mat'], lit_p)
        elif kind == 'terrace':
            terrace(c, rng, pl, x, ground, p['n'], p['uw'], p['uh'], lit_p)
        elif kind == 'church':
            church(c, rng, pl, x, ground)
        elif kind == 'gasholder':
            gasholder(c, rng, pl, x, ground, p['w'])
        elif kind == 'stack':
            stack(c, rng, pl, x, ground, p['h'])
        elif kind == 'cooling':
            cooling(c, rng, pl, x, ground, p['w'], p['h'])
    if extras:
        _crane_and_mast(c, pl, ground)
    img = c.img
    base = img.load()
    for xx in range(w):                                                                     # the body runs down to the layer's foot
        col = base[xx, ground]
        if col[3] == 0:
            col = hexc('4a463f')
        for yy in range(ground + 1, h):
            base[xx, yy] = col
    if columns and run in SMOKE:
        roots = [r for r in pl.roots if r[2] >= 46 and 0 < r[0] < w]
        rr = random.Random(77)
        rr.shuffle(roots)
        for i, (rx, ry, rh) in enumerate(roots[:columns]):
            column(img, rx, ry, rr.randrange(96, 168), 1.0 if i % 3 else 0.7, 2.0 + rr.random() * 1.6, run, 40 + i * 13)
    g = GRADE[run]
    _grade(img, g)
    _haze(img, tuple(int(g[layer][0][i:i + 2], 16) for i in (0, 2, 4)), g[layer][1])
    px = img.load()
    lc = LIT[run]
    for (lx, ly, lw, lh) in pl.lit:
        for yy in range(ly, ly + lh):
            for xx in range(lx, lx + lw):
                if 0 <= xx < w and 0 <= yy < h:
                    px[xx, yy] = hexc(lc[0] if (xx + yy) % 5 else lc[1])
    meta = {'smoke': [list(p) for p in pl.smoke], 'beacon': [list(p) for p in pl.beacon], 'fire': [list(p) for p in pl.fire]}
    return img, meta


def _crane_and_mast(c, pl, ground):
    lo = hexc('3a3d44')
    cx = 214
    top = ground - 188
    c.vline(cx, top, ground, lo)
    c.vline(cx + 1, top, ground, lo)
    for yy in range(top, ground, 4):
        c.put(cx - 1 if (yy // 4) % 2 else cx + 2, yy, lo)
    c.hline(cx - 26, cx + 16, top, lo)
    c.hline(cx - 26, cx + 16, top + 1, lo)
    c.vline(cx - 26, top, top + 12, lo)
    c.rect(cx - 27, top + 12, cx - 25, top + 13, lo)
    c.hline(cx + 4, cx + 15, top - 3, lo)
    c.vline(cx + 1, top - 7, top - 1, lo)
    pl.beacon.append((cx + 1, top - 7))
    mx = 66
    mtop = ground - 205
    c.vline(mx, mtop, ground, lo)
    for k in range(1, 14):
        hw = int(k * 0.55)
        c.hline(mx - hw, mx + hw, mtop + k * 6, lo)
    pl.beacon.append((mx, mtop))
