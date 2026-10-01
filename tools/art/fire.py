"""OUR FIRE, v2 — chunky pixel fire with shells you can control (owner round 29b: "keep it pixelated rather than the
stylised… something similar to our previous fire but with better edges so things don't just cut off… pixelated allows you
to develop stronger controllable detail… [v1] looks too straight and pointy and tall in places").

v1 was a smooth noise model at the game's 1:1 pixel size — hair-fine, straight and spiky. The look the owner liked is the
OLD one: fat pixels, round-topped licks, concentric colour shells. So this draws every flame at HALF resolution and the
game shows it at an integer 2x (`scale: 2` in fire_meta.json — pixels are 2 world px, like the old fire at its usual size;
integer so the pixel grid stays perfectly even). The craft, all of it explicit and tunable:

  * SHAPE: a flame is a stack of round TEARDROPS — width profile sqrt(1 - yn^P) (a ROUND tip, never a point), a lean + an S-curl,
    a lumpy edge (low-amplitude periodic noise, +-1 px), short and wide (height ~1.3-1.8x width). A clump is 2-4 teardrops of
    different height that overlap, so tongues merge low and split high.
  * SHELLS: colour comes from the DEPTH of a pixel inside the silhouette (erosion), not from a height gradient: a 1-px dark-red
    outline, then red, deep orange, orange, yellow, and a small white-hot core low in the middle. Concentric contours are what make
    pixel fire read as pixel fire — and every pixel is explainable.
  * LOOP: 8 frames; heights pulse, tips sway and the edge lumps drift, all on exact sinusoid / periodic-lattice phases, so the last
    frame flows into the first. Embers are single orange pixels that rise and die.
  * EDGES: nothing is ever cropped. Beds are CLUMPS whose humps shrink to nothing at both ends (laid overlapping they read as one
    carpet); the base row is ragged with a dark scorch line and loose coals instead of a ruled cut.

Sheets (assets/fire/, horizontal strips, 8 frames, 10 fps; fire_meta.json = frame size, frames, scale, anchor):
  bed_front_<light|blaze>_<1-3>  the carpet at the player's feet     bed_back_<light|blaze>_<1-3>  the dimmer carpet at the wall seam
  tongue_<s|m|l|xl>_<1-3>        single clumps on the carpet         wall_<1-3>   a lick climbing the wall
  edge_<1-3>                     a door frame catching                small_<1-3>  a palm-sized flame stuck to a body
  stair                          fire over the top step
Run:  python3 tools/art/fire.py      (also writes docs/art_reference/fire.png — every sheet at game size on the corridor wall)
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
SCALE = 2                      # the game draws every sheet at this integer scale (a fire pixel = 2 world px)

# the shells, outermost first: outline, red, deep orange, orange, yellow, white-hot
OUTLINE = (96, 24, 20)
SHELLS = [(184, 52, 30), (228, 96, 34), (255, 152, 50), (255, 212, 96)]
HOT = (255, 244, 204)
EMBER = (255, 176, 70)


class Lattice:
    """2D value noise, periodic in both axes, smooth."""

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
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        a = self.v[y0 % self.py, x0 % self.px]
        b = self.v[y0 % self.py, (x0 + 1) % self.px]
        c = self.v[(y0 + 1) % self.py, x0 % self.px]
        d = self.v[(y0 + 1) % self.py, (x0 + 1) % self.px]
        return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def depth_map(mask, limit=7):
    """Pixels of `mask` -> how many 4-neighbour erosions it survives (0 = outline pixel). Outside = -1."""
    d = np.full(mask.shape, -1, dtype=int)
    cur = mask.copy()
    k = 0
    while cur.any() and k <= limit:
        up = np.zeros_like(cur); up[1:] = cur[:-1]
        dn = np.zeros_like(cur); dn[:-1] = cur[1:]
        lf = np.zeros_like(cur); lf[:, 1:] = cur[:, :-1]
        rt = np.zeros_like(cur); rt[:, :-1] = cur[:, 1:]
        inner = cur & up & dn & lf & rt
        d[cur & ~inner] = k
        cur = inner
        k += 1
    d[cur] = limit
    return d


BAND_EDGES = [1.6, 2.8, 4.1, 5.5]          # eff-depth thresholds: red | deep orange | orange | yellow  (white-hot above CORE_AT)
CORE_AT = 6.6


def paint(mask, depth, yn, core_ok, w, h, dim=1.0):
    """mask/depth -> RGBA Image. Colour = shell depth (+ a lift toward the base, since heat falls with height), with a 1-px
    checker DITHER where two shells meet — the hand-placed look of pixel fire, and a knob (BAND_EDGES) to tune it."""
    out = np.zeros((h, w, 4), dtype=np.uint8)
    eff = depth.astype(float) + (1.0 - np.clip(yn, 0, 1)) * 1.6
    for y in range(h):
        for x in range(w):
            if not mask[y, x]:
                continue
            d = depth[y, x]
            if d == 0:
                col = OUTLINE
            else:
                e = eff[y, x]
                k = 0
                for i, edge in enumerate(BAND_EDGES):
                    if e >= edge - (0.45 if (x + y) % 2 == 0 else 0.0):      # the checker pulls half the pixels up a band near each edge
                        k = i + 1
                if k >= 4 and core_ok[y, x] and e >= CORE_AT - (0.4 if (x + y) % 2 == 0 else 0.0):
                    col = HOT
                else:
                    col = SHELLS[min(k, 3)]
            out[y, x] = (*col, 255)
    img = Image.fromarray(out, 'RGBA')
    if dim < 1.0:
        a = np.array(img).astype(float)
        a[..., 0] *= dim
        a[..., 1] *= dim * 0.93
        a[..., 2] *= dim * 0.8
        img = Image.fromarray(a.astype(np.uint8), 'RGBA')
    return img


def strip(frames):
    w, h = frames[0].size
    s = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    return s


def embers(frames, w, h, seed, count, y0, y1):
    """Single orange pixels that rise 1-2 px a frame and die — a few per sheet, never many."""
    rng = random.Random(seed)
    out = [f.copy() for f in frames]
    for _ in range(count):
        x0 = rng.uniform(w * 0.3, w * 0.7)
        yy = rng.uniform(y0, y1)
        life = rng.choice([3, 4, 5])
        start = rng.randrange(FRAMES)
        drift = rng.uniform(-0.5, 0.5)
        for k in range(life):
            fi = (start + k) % FRAMES
            x = int(round(x0 + drift * k))
            y = int(round(yy - k * 1.6))
            if 0 <= x < w and 0 <= y < h and out[fi].getpixel((x, y))[3] == 0:
                out[fi].putpixel((x, y), (*(EMBER if k < life - 1 else SHELLS[0]), 255))
    return out


# ------------------------------------------------------------------------------ a clump of round teardrops
def clump(w, h, seed, flames, dim=1.0, ember_n=2, edge_amp=1.0):
    """flames = [(cx_frac, width_px, height_px, lean, curl)] — each a round-topped teardrop, base on the bottom row.
    Returns frames. cx_frac in 0..1 across the frame."""
    n_edge = Lattice(6, 6, seed * 3 + 1)
    rng = random.Random(seed)
    phases = [rng.random() for _ in flames]
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    yab = (h - 1.0 - ys)
    frames = []
    for f in range(FRAMES):
        tt = f / float(FRAMES)
        mask = np.zeros((h, w), dtype=bool)
        ynmap = np.zeros((h, w))
        core = np.zeros((h, w), dtype=bool)
        for i, (cxf, wd, ht, lean, curl) in enumerate(flames):
            ph = phases[i]
            hh = ht * (1.0 + 0.10 * math.sin(2 * math.pi * (tt + ph)))             # the lick rises and falls
            yn = yab / max(1.0, hh)
            cx = cxf * (w - 1) + lean * (yn ** 1.5) * hh * 0.28 \
                + curl * np.sin(2 * math.pi * (tt + ph) + yn * 2.6) * np.clip(yn, 0, 1)
            prof = np.sqrt(np.clip(1.0 - np.clip(yn, 0, 1) ** 1.7, 0.0, 1.0))      # ROUND tip: sqrt falls vertically at the end
            half = wd * 0.5 * prof * (0.78 + 0.22 * np.clip(yn * 5.0, 0, 1)) * (1.0 - 0.15 * np.clip(yn, 0, 1))   # a rounded FOOT, a belly, a round tip
            lump = (n_edge.at(yab * 0.34 + i * 2.1, np.full_like(yab, tt * 6.0) + i * 1.3) - 0.5) * 2.0 * edge_amp \
                * (0.35 + np.clip(yn, 0, 1))
            inside = (np.abs(xs - cx) <= half + lump) & (yn >= 0) & (yn < 1.0)
            inside &= (half > 0.45)
            mask |= inside
            ynmap = np.where(inside, yn, ynmap)
            core |= inside & (np.abs(xs - cx) <= half * 0.42) & (yn < 0.5)
        depth = depth_map(mask)
        frames.append(paint(mask, depth, ynmap, core, w, h, dim))
    return embers(frames, w, h, seed * 7, ember_n, h * 0.06, h * 0.5)


def tongue(w, h, seed, kind, ember_n=2):
    """Single clumps — the bed's own character grown taller: WIDE round-topped lobes (height at most ~1.3x width), the
    middle one tallest, gentle lean + curl, never a thin spike (owner 29b: "too straight and pointy and tall")."""
    r = random.Random(seed)
    if kind == 's':
        flames = [(0.36, 10, 8, r.uniform(-0.8, 0.8), 1.0), (0.66, 8, 6, r.uniform(-0.8, 0.8), 0.9)]
    elif kind == 'm':
        flames = [(0.25, 10, 10, r.uniform(-1.0, -0.2), 1.1), (0.52, 14, 15, r.uniform(-0.6, 0.6), 1.2), (0.78, 10, 10, r.uniform(0.2, 1.0), 1.1)]
    elif kind == 'l':
        flames = [(0.20, 11, 10, -1.0, 1.1), (0.42, 14, 16, -0.4, 1.2), (0.64, 14, 19, r.uniform(0.0, 0.7), 1.3), (0.84, 10, 11, 1.0, 1.1)]
    else:   # xl
        flames = [(0.15, 12, 11, -1.2, 1.1), (0.35, 15, 18, -0.6, 1.2), (0.56, 17, 22, 0.1, 1.3), (0.76, 15, 17, 0.7, 1.2), (0.91, 10, 10, 1.2, 1.0)]
    return clump(w, h, seed, flames, 1.0, ember_n, 0.8)


def wall_flame(w, h, seed):
    r = random.Random(seed)
    flames = [(0.28, 11, h * 0.5, r.uniform(-1.0, -0.2), 1.3), (0.54, 17, h - 5, r.uniform(-0.5, 0.6), 1.5), (0.80, 12, h * 0.45, 1.0, 1.2)]
    return clump(w, h, seed, flames, 1.0, 2, 0.8)


def edge_flame(w, h, seed):
    r = random.Random(seed)
    flames = [(0.42, 9, h - 3, 0.8, 1.2), (0.68, 7, h * 0.5, r.uniform(0.2, 0.9), 0.9)]
    return clump(w, h, seed, flames, 1.0, 1, 0.8)


def small_flame(w, h, seed):
    r = random.Random(seed)
    return clump(w, h, seed, [(0.5, 7, h - 2, r.uniform(-0.5, 0.5), 0.6)], 1.0, 0, 0.7)


# ------------------------------------------------------------------------------ the carpet
def bed(w, h, seed, max_h, min_h, humps, dim=1.0, ember_n=2):
    """A row of overlapping round humps (a clump: the humps shrink to nothing at both ends). Ragged base + scorch line."""
    rng = random.Random(seed)
    cx_list = []
    for i in range(humps):
        base = (i + 0.5) / humps
        cx_list.append(base + rng.uniform(-0.35, 0.35) / humps)
    flames = []
    for i, cxf in enumerate(cx_list):
        win = math.sin(math.pi * min(1.0, max(0.0, cxf))) ** 0.8                   # tapers to nothing at both ends
        ht = (min_h + (max_h - min_h) * (0.4 + 0.6 * rng.random())) * max(0.28, win)
        wd = rng.uniform(12.0, 19.0) * (0.65 + 0.35 * win)
        flames.append((cxf, wd, max(3.0, ht), rng.uniform(-0.5, 0.5), rng.uniform(0.5, 1.0)))
    frames = clump(w, h, seed, flames, dim, 0, 1.0)
    # ragged base + scorch: knock a few base pixels out and darken the bottom row, so it never reads as a ruled line
    out = []
    for fi, im in enumerate(frames):
        px = im.load()
        for x in range(w):
            if rng.random() < 0.08:
                px[x, h - 1] = (0, 0, 0, 0)
            elif px[x, h - 1][3] > 0:
                px[x, h - 1] = (*OUTLINE, 255) if rng.random() < 0.55 else px[x, h - 1]
        out.append(im)
    return embers(out, w, h, seed * 11, ember_n, h * 0.25, h * 0.8)


SHEETS = {}


def add(name, frames, note=''):
    sheet = strip(frames)
    sheet.save(os.path.join(OUT, name + '.png'))
    SHEETS[name] = {'frame': list(frames[0].size), 'frames': len(frames), 'scale': SCALE, 'anchor': 'bottom', 'fps': FPS, 'note': note}


def build():
    os.makedirs(OUT, exist_ok=True)
    for v in (1, 2, 3):
        # frames are HALF-res (the game draws them at 2x): a 32-px bed clump is 64 world px
        add('bed_front_light_%d' % v, bed(32, 14, 10 + v, 9, 3, 4, 1.0, 1), 'front carpet, LIGHT')
        add('bed_front_blaze_%d' % v, bed(32, 22, 20 + v, 17, 5, 5, 1.0, 3), 'front carpet, BLAZE')
        add('bed_back_light_%d' % v, bed(32, 10, 30 + v, 6, 2, 4, 0.8, 0), 'back seam carpet, LIGHT')
        add('bed_back_blaze_%d' % v, bed(32, 15, 40 + v, 11, 3, 5, 0.82, 1), 'back seam carpet, BLAZE')
        add('tongue_s_%d' % v, tongue(16, 10, 100 + v, 's', 1))
        add('tongue_m_%d' % v, tongue(24, 18, 110 + v, 'm', 2))
        add('tongue_l_%d' % v, tongue(32, 22, 120 + v, 'l', 3))
        add('tongue_xl_%d' % v, tongue(40, 26, 130 + v, 'xl', 4))
        add('wall_%d' % v, wall_flame(30, 26, 140 + v))
        add('edge_%d' % v, edge_flame(14, 20, 150 + v))
        add('small_%d' % v, small_flame(9, 11, 160 + v))
    add('stair', bed(26, 16, 170, 12, 4, 4, 1.0, 2), 'fire spilling over a step')
    with open(os.path.join(OUT, 'fire_meta.json'), 'w') as f:
        json.dump({'fps': FPS, 'frames': FRAMES, 'scale': SCALE, 'sheets': SHEETS}, f, indent=1, sort_keys=True)


def preview():
    """Frames 0 and 3 of every sheet, at GAME size (x2) on the corridor wall tone, then x2 again for the eye."""
    bg = (201, 170, 118, 255)
    names = sorted(SHEETS.keys())
    groups = [[n for n in names if n.startswith(p)] for p in ('bed_front', 'bed_back', 'tongue', 'wall', 'edge', 'small', 'stair')]
    rows = []
    for g in groups:
        ims = []
        for n in g:
            sh = Image.open(os.path.join(OUT, n + '.png'))
            fw, fh = SHEETS[n]['frame']
            for fi in (0, 3):
                im = sh.crop((fi * fw, 0, fi * fw + fw, fh))
                ims.append(im.resize((fw * SCALE, fh * SCALE), Image.NEAREST))
        rows.append(ims)
    rw = [sum(i.width for i in ims) + 6 * len(ims) for ims in rows]
    rh = [max(i.height for i in ims) + 8 for ims in rows]
    sheet = Image.new('RGBA', (max(rw), sum(rh)), bg)
    y = 0
    for ims, h in zip(rows, rh):
        x = 0
        for im in ims:
            sheet.alpha_composite(im, (x, y + h - im.height - 4))
            x += im.width + 6
        y += h
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    os.makedirs(PREV, exist_ok=True)
    sheet.save(os.path.join(PREV, 'fire.png'))
    return sheet


if __name__ == '__main__':
    build()
    s = preview()
    print('wrote', len(SHEETS), 'sheets; preview', s.size)
