"""OUR FIRE (owner round 29: "these art assets don't look very good — they cut off in bad places and overall look too basic.
I think you can make better with our art… good animated fire that fits our vision").

The purchased craftpix fire was drawn at a different pixel density from the rest of the game (it was scaled 1.6-2.7x, so its
pixels were twice the size of the doors' and the corridor's) and its floor tiles were CROPPED to a band, slicing the flames
mid-body. This replaces all of it with fire drawn at the game's own 1:1 pixel size, from one generator, in the game's
palette language (warm, slightly desaturated, a deep-red rim that reads against any wall — never a black outline).

HOW A FLAME IS MADE (no hand-placed pixels — a model, so every size/variant/frame is consistent and it LOOPS exactly):
  * a column of heat: a teardrop that narrows and sways with height, its body torn into separate TONGUES at the top by
    ridged noise (pointed tips, not round blobs);
  * the noise SCROLLS UP the flame by exactly one lattice period over the loop, so the last frame flows into the first;
    two layers scroll at different speeds (1x and 2x) so it never reads as one sliding texture;
  * heat -> palette by fraction of the flame's height: a white-hot heart low down, yellow, orange, red, and a dark-red rim
    (the outermost pixels) with sparse embers flung off the tips;
  * beds (the floor carpet of flame) are periodic in x too — they tile seamlessly and are NEVER cropped.

Sheets (assets/fire/, horizontal strips of N frames, loop at 10 fps; `fire_meta.json` lists size + frames + anchor):
  bed_front_<stage>_<v>.png   the flame carpet along the floor, drawn in FRONT of the player's feet (tileable 64 wide)
  bed_back_<stage>_<v>.png    the same, smaller + dimmer, along the wall/floor seam BEHIND the player (depth)
  tongue_<s|m|l|xl>_<v>.png   single flame clumps rising from the bed (bottom-centre anchored)
  wall_<v>.png                a tongue CLIMBING a wall (narrow, tall, licking sideways)
  edge_<v>.png                a flame running up a door frame's edge (slim)
  small_<v>.png               a palm-sized flame stuck to a body (the burning overlay on an enemy)
  spark.png                   embers drifting up (drawn over big flames)
  stair.png                   the fire spilling over the top step of the down stairwell
  stage: light (low, patchy) / blaze (tall, dense)
Run:  python3 tools/art/fire.py      (also writes docs/art_reference/fire.png — every sheet on the corridor wall colour)
"""
import json
import math
import os
import random
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'fire')
PREV = os.path.join(ROOT, 'docs', 'art_reference')

FRAMES = 8
FPS = 10

# palette, hottest first — the game's warm, slightly dusty fire (never pure #ff0000)
PAL = [
    (255, 246, 214),   # white-hot heart
    (255, 222, 110),   # yellow
    (255, 168, 52),    # orange
    (232, 98, 34),     # deep orange
    (178, 48, 28),     # red
    (104, 26, 22),     # dark-red rim
]
EMBER = (255, 190, 90)


# ---------------------------------------------------------------- periodic value noise
class Lattice:
    """2D value noise, periodic in both axes (px, py lattice cells), smooth (quintic) — sampled at float coords."""

    def __init__(self, px, py, seed):
        rng = np.random.default_rng(seed)
        self.px, self.py = px, py
        self.v = rng.random((py, px))

    def at(self, x, y):
        x = np.asarray(x, dtype=float)
        y = np.asarray(y, dtype=float)
        x0 = np.floor(x).astype(int)
        y0 = np.floor(y).astype(int)
        fx = x - x0
        fy = y - y0
        fx = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
        fy = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
        x0m, x1m = x0 % self.px, (x0 + 1) % self.px
        y0m, y1m = y0 % self.py, (y0 + 1) % self.py
        a = self.v[y0m, x0m]
        b = self.v[y0m, x1m]
        c = self.v[y1m, x0m]
        d = self.v[y1m, x1m]
        return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def ridge(n):
    """0..1 noise -> pointed peaks (1 at n=0.5, falling to 0 at both ends)."""
    return 1.0 - np.abs(2.0 * n - 1.0)


def palette_image(heat, rim, w, h):
    """heat: HxW floats (0 = none). rim: HxW bool (an outline pixel). -> RGBA Image."""
    out = np.zeros((h, w, 4), dtype=np.uint8)
    # band edges on heat (descending): white-hot, yellow, orange, deep orange, red, dark rim
    edges = [0.86, 0.68, 0.50, 0.34, 0.20, 0.07]
    for i in range(len(edges) - 1, -1, -1):          # coolest first, so hotter bands paint over it
        e = edges[i]
        m = heat >= e
        out[m, 0:3] = PAL[i]
        out[m, 3] = 255
    out[rim & (out[..., 3] == 0)] = (*PAL[5], 255)
    return Image.fromarray(out, 'RGBA')


def outline_mask(alpha_on):
    """Pixels adjacent (4-way) to a lit pixel that aren't lit themselves."""
    a = alpha_on
    up = np.zeros_like(a); up[1:] = a[:-1]
    dn = np.zeros_like(a); dn[:-1] = a[1:]
    lf = np.zeros_like(a); lf[:, 1:] = a[:, :-1]
    rt = np.zeros_like(a); rt[:, :-1] = a[:, 1:]
    return (up | dn | lf | rt) & ~a


def strip(frames):
    w, h = frames[0].size
    s = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    return s


def sparks(img_frames, w, h, rng_seed, count, y_range):
    """Fling a few embers off the tips: drawn into every frame so they drift up and fade over the loop."""
    rng = random.Random(rng_seed)
    out = [f.copy() for f in img_frames]
    for _ in range(count):
        x0 = rng.uniform(w * 0.25, w * 0.75)
        y0 = rng.uniform(*y_range)
        life = rng.choice([4, 5, 6])
        start = rng.randrange(FRAMES)
        drift = rng.uniform(-0.6, 0.6)
        for k in range(life):
            fi = (start + k) % FRAMES
            x = int(round(x0 + drift * k))
            y = int(round(y0 - k * 2.2))
            if 0 <= x < w and 0 <= y < h:
                col = EMBER if k < life - 2 else PAL[4]
                out[fi].putpixel((x, y), (*col, 255))
    return out


# ---------------------------------------------------------------- a single flame clump
def tongue(w, h, seed, base_w, height, tongues=3, lean=0.0, sway=1.6, stage_heat=1.0, spark_n=2):
    """One flame clump, bottom-centre anchored on a w x h frame. `height` = flame height in px (<= h - 2)."""
    n1 = Lattice(8, 8, seed * 3 + 1)      # the body's torn edge (scrolls 1x)
    n2 = Lattice(6, 12, seed * 3 + 2)     # finer flicker (scrolls 2x)
    n3 = Lattice(4, 4, seed * 3 + 3)      # sideways wobble per tongue
    rng = random.Random(seed)
    subs = []                              # sub-flames: (dx, height factor, width factor, phase)
    for i in range(tongues):
        t = (i + 0.5) / tongues
        subs.append(((t - 0.5) * base_w * 1.25 + rng.uniform(-0.8, 0.8), 0.55 + 0.45 * math.sin(math.pi * t) ** 0.8 * rng.uniform(0.85, 1.1),
                     rng.uniform(0.72, 1.0), rng.random()))
    frames = []
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    cx = (w - 1) / 2.0
    yab = (h - 1.0 - ys)                   # pixels above the base row
    for f in range(FRAMES):
        tt = f / float(FRAMES)
        heat = np.zeros((h, w))
        for (dx, hf, wf, ph) in subs:
            sub_h = height * hf
            yn = np.clip(yab / max(1.0, sub_h), 0.0, 1.0)
            # the column leans + sways more toward the tip; the sway loops once per cycle
            off = lean * yn ** 1.5 * sub_h * 0.25 + sway * yn ** 1.3 * math.sin(2 * math.pi * (tt + ph)) \
                + (n3.at(np.full_like(xs, 1.3 * ph * 4), yn * 3 + tt * 4) - 0.5) * 2.0 * yn
            wid = base_w * wf * (1.0 - yn) ** 0.72 * 0.5 + 0.35
            d = np.abs(xs - (cx + dx + off)) / np.maximum(0.6, wid)
            # the torn edge: ridged noise scrolling up the flame
            e1 = n1.at(xs * 0.22 + ph * 8, yab * 0.16 + (1.0 - tt) * 8)       # scrolls one full period (8) over the loop
            e2 = n2.at(xs * 0.35 + ph * 6, yab * 0.22 + (1.0 - tt) * 12 * 2 % 12)
            tear = (e1 - 0.5) * 0.9 * (0.25 + yn) + (e2 - 0.5) * 0.55 * yn
            dens = 1.0 - d + tear
            # tips shred into points: density falls off faster than linear near the top
            dens *= np.clip(1.0 - yn ** 2.6, 0.0, 1.0) ** 0.5 if True else 1.0
            dens[yab < 0] = 0
            heat = np.maximum(heat, dens)
        # hottest at the heart low down: heat = density, boosted near the base, cooled toward the tips
        yn_all = np.clip(yab / max(1.0, height), 0.0, 1.0)
        pocket = n2.at(xs * 0.3 + seed * 0.37, yab * 0.2 + (1.0 - tt) * 12 % 12 + 2.0)
        heat = heat * (1.0 - 0.5 * yn_all) * (0.82 + 0.5 * (pocket - 0.5)) * stage_heat
        heat = np.clip(heat, 0.0, 1.0)
        on = heat >= 0.07
        rim = outline_mask(on)
        frames.append(palette_image(heat, rim, w, h))
    return sparks(frames, w, h, seed * 7, spark_n, (h * 0.08, h * 0.45))


# ---------------------------------------------------------------- floor beds
def bed(w, h, seed, max_h, min_h, stage_heat=1.0, tongue_freq=0.14, dim=1.0, spark_n=2):
    """A flame carpet, tileable in x, never cropped: heights are ridged noise across x, scrolling over the loop."""
    px = max(1, int(round(w * tongue_freq)))
    nb = Lattice(px, 8, seed * 5 + 1)      # tongue heights across x (periodic in x), changing with time
    nc = Lattice(px * 2, 8, seed * 5 + 2)
    nd = Lattice(px * 2, 16, seed * 5 + 3)
    frames = []
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    yab = (h - 1.0 - ys)
    for f in range(FRAMES):
        tt = f / float(FRAMES)
        xa = xs * (px / float(w))
        # tongue heights: ridged noise over (x, time) — pointed peaks that rise and collapse through the loop
        r1 = ridge(nb.at(xa, tt * 8 % 8))
        r2 = ridge(nc.at(xa * 2 % (px * 2), tt * 8 % 8 + 3))
        hcol = min_h + (max_h - min_h) * np.clip(0.62 * r1 + 0.5 * r2 - 0.05, 0.0, 1.0)
        win = np.sin(np.pi * (xs + 0.5) / w) ** 0.75                   # a CLUMP: tapers to nothing at both ends (overlap to join)
        hcol = hcol * win
        # the flicker: shift each pixel's height by scrolling noise, so edges shimmer instead of sliding
        wob = (nd.at(xa * 2 % (px * 2), yab * 0.12 + (1.0 - tt) * 16 % 16) - 0.5) * 5.0
        frac = (yab + wob) / np.maximum(1.0, hcol)
        pocket = nd.at(xa * 2 % (px * 2) + 3.0, yab * 0.09 + (1.0 - tt) * 16 % 16 + 5.0)     # hot/cool pockets rising through it
        heat = np.clip((1.0 - np.clip(frac, 0.0, 1.0)) ** 1.25 * 1.0 + (pocket - 0.5) * 0.34, 0.0, 1.0)
        heat[frac >= 1.0] = 0
        heat[yab < 0] = 0
        # a base glow: the coal bed — the bottom rows are always hot
        base_rows = (yab < 2) & (win > 0.35)
        heat[base_rows] = np.maximum(heat[base_rows], (0.88 - 0.16 * yab[base_rows] / 2.0) * np.clip(win[base_rows] * 1.3, 0.0, 1.0))
        heat *= stage_heat
        on = heat >= 0.07
        rim = outline_mask(on)
        # no rim on the bottom edge (it sits on the floor) — a rim there reads as a dark line under the fire
        rim[-1, :] = False
        img = palette_image(heat, rim, w, h)
        if dim < 1.0:
            arr = np.array(img).astype(float)
            arr[..., 0] *= dim
            arr[..., 1] *= dim * 0.93
            arr[..., 2] *= dim * 0.82
            img = Image.fromarray(arr.astype(np.uint8), 'RGBA')
        frames.append(img)
    return sparks(frames, w, h, seed * 11, spark_n, (h * 0.25, h * 0.8))


def wall_flame(w, h, seed):
    """A flame climbing a wall: tall and narrow, licking sideways, a tapering streak of heat up the plaster."""
    return tongue(w, h, seed, base_w=w * 0.78, height=h - 4, tongues=3, lean=0.0, sway=2.0, spark_n=2)


# ---------------------------------------------------------------- the sheets
SHEETS = {}


def add(name, frames, anchor, note=''):
    sheet = strip(frames)
    sheet.save(os.path.join(OUT, name + '.png'))
    SHEETS[name] = {'frame': list(frames[0].size), 'frames': len(frames), 'anchor': anchor, 'fps': FPS, 'note': note}


def build():
    os.makedirs(OUT, exist_ok=True)
    # floor beds — per stage, 3 variants each
    for v in (1, 2, 3):
        add('bed_front_light_%d' % v, bed(64, 24, 10 + v, 18, 6, 0.95, 0.11, 1.0, 1), 'bottom', 'front carpet, LIGHT')
        add('bed_front_blaze_%d' % v, bed(64, 38, 20 + v, 33, 10, 1.0, 0.13, 1.0, 3), 'bottom', 'front carpet, BLAZE')
        add('bed_back_light_%d' % v, bed(64, 16, 30 + v, 11, 4, 0.9, 0.11, 0.8, 0), 'bottom', 'back seam carpet, LIGHT')
        add('bed_back_blaze_%d' % v, bed(64, 24, 40 + v, 21, 6, 0.95, 0.13, 0.82, 1), 'bottom', 'back seam carpet, BLAZE')
    # single flames
    for v in (1, 2, 3):
        add('tongue_s_%d' % v, tongue(26, 30, 100 + v, 17, 26, 2, (v - 2) * 0.6, 1.2, 1.0, 1), 'bottom')
        add('tongue_m_%d' % v, tongue(38, 44, 110 + v, 26, 40, 3, (v - 2) * 0.7, 1.8, 1.0, 2), 'bottom')
        add('tongue_l_%d' % v, tongue(54, 62, 120 + v, 38, 58, 4, (v - 2) * 0.9, 2.4, 1.0, 3), 'bottom')
        add('tongue_xl_%d' % v, tongue(72, 84, 130 + v, 52, 80, 5, (v - 2) * 1.1, 3.0, 1.0, 4), 'bottom')
        add('wall_%d' % v, wall_flame(36, 66, 140 + v), 'bottom')
        add('edge_%d' % v, tongue(24, 46, 150 + v, 16, 40, 2, 0.9, 1.1, 1.0, 1), 'bottom')
        add('small_%d' % v, tongue(14, 20, 160 + v, 8, 17, 2, (v - 2) * 0.5, 0.9, 1.0, 0), 'bottom')
    add('stair', bed(48, 28, 170, 24, 8, 1.0, 0.13, 1.0, 2), 'bottom', 'fire spilling over a step')
    with open(os.path.join(OUT, 'fire_meta.json'), 'w') as f:
        json.dump({'fps': FPS, 'frames': FRAMES, 'sheets': SHEETS}, f, indent=1, sort_keys=True)


def preview():
    """Every sheet's frame 0 + frame 4 on the corridor wall tone, scaled 3x, in rows."""
    bg = (201, 170, 118, 255)
    names = sorted(SHEETS.keys())
    groups = [[n for n in names if n.startswith(p)] for p in ('bed_front', 'bed_back', 'tongue', 'wall', 'edge', 'small', 'stair')]
    rows = []
    for g in groups:
        if not g:
            continue
        row_w = 8
        ims = []
        for n in g:
            sh = Image.open(os.path.join(OUT, n + '.png'))
            fw, fh = SHEETS[n]['frame']
            for fi in (0, 3):
                ims.append(sh.crop((fi * fw, 0, fi * fw + fw, fh)))
        rows.append(ims)
    scale = 3
    W = 0
    H = 0
    rh = []
    rw = []
    for ims in rows:
        rw.append(sum(i.width for i in ims) + 6 * len(ims))
        rh.append(max(i.height for i in ims) + 8)
    sheet = Image.new('RGBA', (max(rw), sum(rh)), bg)
    y = 0
    for ims, h in zip(rows, rh):
        x = 0
        for im in ims:
            sheet.alpha_composite(im, (x, y + h - im.height - 4))
            x += im.width + 6
        y += h
    sheet = sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
    os.makedirs(PREV, exist_ok=True)
    sheet.save(os.path.join(PREV, 'fire.png'))
    return sheet


if __name__ == '__main__':
    build()
    s = preview()
    print('wrote', len(SHEETS), 'sheets; preview', s.size)
