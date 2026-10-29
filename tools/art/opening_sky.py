#!/usr/bin/env python3
"""THE OPENING'S SKIES AND CLOUDS (owner round 49: "a lot of their background colours and details are remarkably similar to what you've
been making… sky colours, clouds, moon shapes, buildings… too many similarities that will make people say AI").

WHAT WAS WRONG (measured on the old art, then judged on the same frames as the owner's three reference screenshots):
  * ONE smooth vertical gradient per run, Bayer-dithered through 24 levels — the signature of a generated pixel sky;
  * ONE set of disc-union puffball clouds, RECOLOURED three times — so the three skies were the same sky;
  * a violet→peach "sunset" (the colour of the reference games), a navy night with 170 dot stars and a cratered round moon, and a
    sun made of concentric glow rings.

WHAT THIS DOES INSTEAD: each time of day is an OBSERVED sky, painted as weather, not as a gradient:
  * MORNING — a pewter overcast deck in perspective (cloud rows get finer toward the horizon), a break in it low on the left where the
    light is straw-coloured; the sun is a plain pale disc seen through the thin edge of a cloud, no glow rings. Cold grey, not cyan.
  * AFTERNOON — not a sunset: a smoke-dimmed day. Khaki haze, a dull slate overhead, dark smoke columns leaning one way, a small
    off-white disc. No violet or pink anywhere.
  * NIGHT — no moon and no stars (a city under cloud has neither): a charcoal deck lit from UNDERNEATH by the fires, hot spots
    where they stand, black overhead. No navy, no teal.
  * The clouds are NOISE-built (ragged, torn, lit from the sun's side) and each time of day has its OWN shapes: stratus bars and
    broken fragments by day, smoke drifting in the afternoon, fast low scud at night.

Everything here is deterministic integer-hashed value noise in plain numpy (no scipy, no random module), so a regenerated file is
byte-identical anywhere — `opening.py --check` depends on that.
"""
import math

import numpy as np
from PIL import Image


def rgb(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


# ------------------------------------------------------------------------------------------------------------------ noise
def _hash01(ix, iy, seed):
    """A lattice hash in [0, 1): pure int64 arithmetic, the same on every machine."""
    h = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + np.int64(seed) * 1274126177) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = (h ^ (h >> 16)) & 0xFFFFFFFF
    return h.astype(np.float64) / 4294967296.0


def vnoise(x, y, seed):
    xi = np.floor(x)
    yi = np.floor(y)
    fx = x - xi
    fy = y - yi
    u = fx * fx * (3.0 - 2.0 * fx)
    v = fy * fy * (3.0 - 2.0 * fy)
    a = _hash01(xi, yi, seed)
    b = _hash01(xi + 1, yi, seed)
    c = _hash01(xi, yi + 1, seed)
    d = _hash01(xi + 1, yi + 1, seed)
    return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v


def fbm(x, y, seed, octaves=5, gain=0.5):
    total = np.zeros_like(x, dtype=np.float64)
    amp = 1.0
    norm = 0.0
    f = 1.0
    for o in range(octaves):
        total += amp * vnoise(x * f + 17.3 * o, y * f - 9.1 * o, seed + 101 * o)
        norm += amp
        amp *= gain
        f *= 2.0
    return total / norm


def smooth(a, lo, hi):
    t = np.clip((a - lo) / max(1e-9, hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def ramp_pick(ramp, idx):
    """ramp: list of (r, g, b); idx: float array in [0, n-1] -> an RGB array, rounded to whole steps (hard bands, no blending)."""
    pal = np.array(ramp, dtype=np.uint8)
    i = np.clip(np.rint(idx), 0, len(ramp) - 1).astype(np.int64)
    return pal[i]


# --------------------------------------------------------------------------------------------------------------------- SKIES
# One dict per run. `gap` = the sky between clouds, zenith -> horizon; `cloud` = the cloud body, lit side -> shadow.
SKY = {
    1: dict(
        gap=['8ea4b2', 'a9bbc3', 'c6d0cc', 'e0dcc2', 'f0dfae'],
        cloud=['f4efe0', 'dedcd0', 'bec5c2', '9aa5a9', '77838b', '57636c'],
        cover=0.66, clear_x=0.22, clear_w=0.30, seed=31, fu=0.016, fv=12.0, bright=0.7, sun=dict(x=66, dy=-98, r=5, col='fff3cf')),
    2: dict(
        gap=['6c7a84', '84918f', 'a5a98a', 'c5b57c', 'd9bb6c'],
        cloud=['d8c9a0', 'b6a57b', '8f7d5e', '6c5d49', '4b4137', '302a25'],
        cover=0.58, clear_x=0.22, clear_w=0.28, seed=47, fu=0.014, fv=11.0, bright=0.2, sun=dict(x=66, dy=-84, r=6, col='f4e4aa')),
    3: dict(
        gap=['09090a', '0f0e0e', '171312', '231a14', '36231a'],
        cloud=['6a3d24', '4c2e20', '35241c', '261b17', '19130f', '0e0a0a'],
        cover=0.80, clear_x=0.5, clear_w=0.0, seed=59, fu=0.018, fv=13.0, bright=0.0, sun=None),
}


def paint_sky(run, w, h, fires=None):
    """The sky layer, w x h (the horizon is a little below the bottom edge, behind the towers). Returns an RGBA image."""
    p = SKY[run]
    seed = p['seed']
    hz = h + 10.0                                              # the horizon row (just below the layer: towers hide it)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    e = np.clip((hz - ys) / hz, 0.0, 1.0)                      # 0 at the horizon, 1 overhead
    # the deck, in perspective-lite: rows stretched along the wind (wide in x), packed closer toward the horizon (v warps with 1/elevation)
    # but NOT fanned out — a true ground-plane projection streaks the noise into rays
    cx = (xs - w * 0.5)
    fu, fv = p['fu'], p['fv']
    near = 1.0 + 1.1 * (1.0 - e)                              # horizontal detail doubles toward the horizon
    u = cx * fu * near + 3.0
    v = fv / (0.20 + 0.80 * e) * 0.55
    rows = fbm(u, v, seed, 6, 0.52)
    mass = fbm(u * 0.35 + 40.0, v * 0.35 + 11.0, seed + 7, 3, 0.5)
    dens = rows * 0.82 + mass * 0.30
    # a break in the deck (the sun's side) — wide near the horizon, closing overhead
    xn = xs / float(w)
    brk = np.exp(-((xn - p['clear_x']) / max(0.05, p['clear_w'])) ** 2) if p['clear_w'] > 0 else np.zeros_like(xn)
    dens = dens - brk * (0.14 + 0.30 * (1.0 - e) ** 0.6)
    thr = 1.0 - p['cover'] * 0.78
    cov = smooth(dens, thr - 0.015, thr + 0.050)               # 0 gap .. 1 cloud, a tight edge (pixels stay crisp)
    # light: derivative of the density toward the sun (left / low): lit rims, shaded undersides
    dl = fbm(u - 0.10, v + 0.05, seed, 6, 0.52) * 0.82 + fbm((u - 0.10) * 0.35 + 40.0, (v + 0.05) * 0.35 + 11.0, seed + 7, 3, 0.5) * 0.30
    lit = np.clip((dens - dl) * 5.0, -1.0, 1.0)                # >0 on the side facing the light
    thick = smooth(dens, thr, thr + 0.26)                      # how deep into the cloud we are
    tone = 1.7 - p['bright'] + thick * 2.3 - lit * 1.25 + (1.0 - e) * 0.25
    ncl = len(p['cloud'])
    cloud_rgb = ramp_pick([rgb(c) for c in p['cloud']], np.clip(tone, 0, ncl - 1))
    # the sky between: horizontal bands, their edges wavering (never a smooth gradient, never dithered)
    wob = fbm(xs * 0.020, ys * 0.035, seed + 3, 4) - 0.5
    gi = np.clip((1.0 - e + wob * 0.34) * (len(p['gap']) - 0.01), 0, len(p['gap']) - 1)
    gap_rgb = ramp_pick([rgb(c) for c in p['gap']], gi)
    out = np.where((cov > 0.5)[..., None], cloud_rgb, gap_rgb).astype(np.uint8)

    if run == 3:
        out = _night_glow(out, xs, ys, w, h, e, cov, dens, thr, fires or [], seed, p)
    img = Image.fromarray(out, 'RGB').convert('RGBA')
    px = img.load()
    if p['sun']:
        s = p['sun']
        sy = h + s['dy']
        sc = rgb(s['col'])
        for yy in range(int(sy - s['r'] - 1), int(sy + s['r'] + 2)):
            for xx in range(int(s['x'] - s['r'] - 1), int(s['x'] + s['r'] + 2)):
                if 0 <= xx < w and 0 <= yy < h and (xx - s['x']) ** 2 + (yy - sy) ** 2 <= s['r'] ** 2:
                    px[xx, yy] = sc + (255,)
    return img


def _night_glow(out, xs, ys, w, h, e, cov, dens, thr, fires, seed, p):
    """The deck lit from UNDERNEATH: warm where the city burns (hot spots at the fires), faint orange along the whole horizon, none
    overhead — each cloud's lower side takes it, a few steps of the ramp, hard banded."""
    glow = (1.0 - e) ** 3.2 * 1.9                               # the whole horizon
    for (fx, fy_, power) in fires:
        glow = glow + power * np.exp(-(((xs - fx) / 46.0) ** 2 + ((ys - fy_) / 70.0) ** 2))
    ncl = len(p['cloud'])
    # undersides catch it hardest: the shaded side of a cloud (low `dens` edge near a gap) is the one facing down
    under = smooth(dens, thr, thr + 0.12)
    rim = (1.0 - smooth(dens, thr + 0.10, thr + 0.30)) * 1.1    # a thin lit lower edge
    deep = smooth(dens, thr + 0.05, thr + 0.45)                 # the heart of a cloud is the darkest part; its thin edges scatter light
    tone = ncl - 2.2 + deep * 1.1 - glow * 2.6 - rim * (glow + 0.35) * 1.3 - under * 0.0
    cloud_rgb = ramp_pick([rgb(c) for c in p['cloud']], np.clip(tone, 0, ncl - 1))
    gi = np.clip(glow * 2.2, 0, len(p['gap']) - 1)              # the gaps glow too, low down
    gap_rgb = ramp_pick([rgb(c) for c in p['gap']], gi)
    return np.where((cov > 0.5)[..., None], cloud_rgb, gap_rgb).astype(np.uint8)


if __name__ == '__main__':
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else '/tmp/sky_%d.png'
    for run in (1, 2, 3):
        im = paint_sky(run, 288, 330, fires=[(60, 300, 1.4), (200, 306, 1.0)] if run == 3 else None)
        im.save(out % run if '%d' in out else out)


# ------------------------------------------------------------------------------------------------------------------ CLOUD SPRITES
# The drifting clouds the game slides across the baked deck. Noise-built (ragged, torn, WIND-SHEARED — the tops lean downwind),
# never a union of discs, and each time of day has its own kinds. Cells keep the SAME sizes in every run (the game places them by
# atlas index), their character changes: by day sheared stratocumulus / torn strata / broken fragments; in the afternoon plumes of smoke
# drifting off the city; at night fast ragged scud, lit from underneath.
CELL_KINDS = {1: {'big': 'bank', 'mid': 'frag', 'wisp': 'strat'},
              2: {'big': 'plume', 'mid': 'puff', 'wisp': 'streak'},
              3: {'big': 'scud', 'mid': 'scud_s', 'wisp': 'scud_w'}}


def cloud_cell(w, h, seed, style, run):
    """One sprite, w x h RGBA. `style` is one of bank / frag / strat / plume / puff / streak / scud / scud_s / scud_w."""
    ramp = [rgb(c) for c in SKY[run]['cloud']]
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    nx = (xs + 0.5) / w
    ny = (ys + 0.5) / h
    envx = np.clip(1.0 - ((nx - 0.5) / 0.5) ** 2, 0.0, 1.0)                  # a lens: thick in the middle, torn to nothing at the ends
    shear = {'bank': 0.30, 'frag': 0.22, 'strat': 0.0, 'plume': 0.9, 'puff': 0.6, 'streak': 0.2,
             'scud': 0.15, 'scud_s': 0.15, 'scud_w': 0.05}[style]
    sx = xs - (1.0 - ny) * shear * h                                          # the top leans downwind (right)
    flat = style in ('strat', 'streak', 'scud', 'scud_s', 'scud_w', 'plume', 'puff')
    amp0, amp1 = {'plume': (0.12, 0.30), 'puff': (0.14, 0.30)}.get(style, (0.30, 0.58))      # smoke humps are LOW (no pointed mounds)
    fx, fy = (0.045, 0.30) if flat else (0.075, 0.115)
    n = fbm(sx * fx + 5.0, ys * fy + seed * 0.37, seed, 4, 0.52)
    n2 = fbm(sx * fx * 2.3 + 90.0, ys * fy * 2.3, seed + 9, 2, 0.5)
    # the vertical profile: a thin bar for the flat kinds; a body that stands up from its base for the others (the base TORN, not ruled)
    base_y = 0.80 + (fbm(xs * 0.06, np.zeros_like(xs) + seed, seed + 3, 3) - 0.5) * 0.30
    if flat:
        rag = 0.55 + 0.9 * fbm(sx * 0.09, ys * 0.35 + seed, seed + 29, 3)        # ragged: the bar's thickness wanders along its length
        ex = envx ** (0.38 if style in ('plume', 'puff') else 0.7)                 # smoke bars end bluntly and ragged, not in a lens's two points
        prof = np.clip(1.0 - np.abs(ny - 0.5) / ((0.16 + 0.30 * ex) * rag), 0.0, 1.0)
    else:
        top = base_y - (amp0 + amp1 * envx) * (0.55 + 0.9 * (fbm(sx * 0.05, np.zeros_like(xs) + 2.0 + seed, seed + 17, 3) - 0.30))
        prof = np.clip((ny - top) / 0.18, 0.0, 1.0) * np.clip((base_y - ny) / 0.16 + 0.35, 0.0, 1.0)
    dens = (n * 0.85 + n2 * 0.22) * (0.28 + 0.9 * envx) * prof * 1.9
    thr = 0.50
    solid = dens > thr
    veil = (dens > thr - 0.07) & ~solid
    # light from the upper left; the underside shaded by how little cloud lies below a pixel
    below = np.zeros_like(dens)
    for y in range(h - 2, -1, -1):
        below[y] = np.where(solid[y], below[y + 1] + 1.0, 0.0)
    below = np.where(solid, below, 0.0)
    sm = (dens + np.roll(dens, 1, 0) + np.roll(dens, -1, 0) + np.roll(dens, 1, 1) + np.roll(dens, -1, 1)) / 5.0   # a light blur, so the lit rim is not speckle
    dl = np.roll(np.roll(sm, 1, axis=0), 1, axis=1)
    lit = np.clip((sm - dl) * 5.5, -1.0, 1.0)
    thick = np.clip((dens - thr) / 0.55, 0.0, 1.0)
    tone = 1.25 + thick * 1.5 + (1.0 - np.clip(below / 7.0, 0, 1)) * 1.9 - lit * 1.1
    if run == 2:                                                              # smoke: dark at the heart, lifting as it ages (toward the right)
        tone = 2.6 + thick * 1.8 - (nx * 1.6) + (1.0 - np.clip(below / 6.0, 0, 1)) * 0.9 - lit * 0.8
    if run == 3:                                                              # lit from underneath: the lowest rows take the fires' colour
        tone = 4.0 + thick * 0.9 - (1.0 - np.clip(below / 4.0, 0, 1)) * 1.5 * (0.4 + 0.6 * ny) + lit * 0.3
    idx = np.clip(tone, 0, len(ramp) - 1)
    rgbs = ramp_pick(ramp, idx)
    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[..., :3] = rgbs
    out[..., 3] = np.where(solid, 255, np.where(veil, 120, 0))
    return Image.fromarray(out, 'RGBA')
