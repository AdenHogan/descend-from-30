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
def clump(w, h, seed, flames, dim=1.0, ember_n=2, edge_amp=1.0, tip=1.7):
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
            prof = np.sqrt(np.clip(1.0 - np.clip(yn, 0, 1) ** tip, 0.0, 1.0))      # ROUND tip (a bigger `tip` = a blunter dome): sqrt falls vertically at the end
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
    """Single clumps — soft rounded LICKS: neither spikes (passes 1-2) nor a cloud (a flat dome, pass 3). Lobes of unequal
    height whose centres overlap so the dips between them are shallow, blunt tops (`tip` 2.6), a gentle lean, a calm edge."""
    r = random.Random(seed)
    if kind == 's':
        flames = [(0.40, 11, 10, r.uniform(-0.6, 0.6), 1.0), (0.68, 9, 7, r.uniform(-0.6, 0.6), 0.9)]
    elif kind == 'm':
        flames = [(0.30, 13, 11, r.uniform(-0.7, -0.1), 1.0), (0.56, 15, 15, r.uniform(-0.3, 0.3), 1.1), (0.80, 11, 10, r.uniform(0.2, 0.7), 1.0)]
    elif kind == 'l':
        flames = [(0.22, 13, 10, -0.7, 1.0), (0.44, 15, 15, -0.3, 1.1), (0.66, 16, 18, r.uniform(0.0, 0.5), 1.2), (0.86, 11, 10, 0.7, 1.0)]
    else:   # xl
        flames = [(0.18, 14, 11, -0.8, 1.0), (0.38, 16, 17, -0.4, 1.1), (0.58, 18, 21, 0.1, 1.2), (0.78, 16, 16, 0.5, 1.1), (0.92, 11, 9, 0.8, 1.0)]
    return clump(w, h, seed, flames, 1.0, ember_n, 0.4, 2.6)


def small_flame(w, h, seed):
    r = random.Random(seed)
    return clump(w, h, seed, [(0.5, 8, h - 2, r.uniform(-0.4, 0.4), 0.6)], 1.0, 0, 0.5, 2.6)


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


# ------------------------------------------------------------------------------ EXTENSION PIECES
# (owner 29b: "extensions… larger pieces independent but they naturally connect to other pieces… the paid assets didn't look
# clean at the top or sides. Clean extension sections are essential".) Two kits, each painted as ONE long strip and cut into
# pieces, so every join is seamless by construction (a piece's edge is exactly the next piece's edge, outline and shells included):
#   RUN (horizontal)  runl_<stage>_N | run_<stage>_N x n | runr_<stage>_N   — a left cap that rises out of nothing, any number of
#                     identical-edge middles (the height field is PERIODIC across one tile), a right cap that sinks to nothing.
#   COLUMN (vertical) col?b_N | col?m_N x n | col?c_N                        — a grounded base with a rounded foot, any number of
#                     mid sections (the sway is periodic over one section), a cap with a blunt rounded top. ?=w (wide) / n (narrow).
# The caps keep a flat PLATEAU where they meet the middle, so the join zone is the same field a middle would have there.
JOIN = 8                       # px of a cap that is exactly the middle's field (>= the erosion depth that colours a pixel)


def _strip_paint(mask, w, h, yn_fn, core):
    depth = depth_map(mask)
    return paint(mask, depth, yn_fn, core, w, h)


def run_kit(w, h, seed, min_h, max_h):
    """Returns (cap_l, run, cap_r): three lists of 8 frames. Tile width w."""
    rng = random.Random(seed)
    # the field is a UNION OF ROUND DOMES (like the approved carpets), their centres wrapping round the tile so the
    # field is periodic in x — a hump that leaves the right edge re-enters on the left
    humps = []
    for i in range(3):
        c = (i + 0.5) * w / 3.0 + rng.uniform(-2.0, 2.0)
        r = rng.uniform(6.5, 9.0)
        hi = min_h + (max_h - min_h) * rng.uniform(0.45, 1.0)
        lo = min_h + (hi - min_h) * rng.uniform(0.25, 0.6)
        humps.append((c, r, lo, hi, rng.choice([1, 1, 2]), rng.uniform(0, 2 * math.pi)))
    n = 5
    W = w * n
    xs = np.arange(W, dtype=float)
    ys, _ = np.mgrid[0:h, 0:W].astype(float)
    yab = (h - 1.0 - ys)
    # envelope: 0 for the cap ends (round, vertical tangent), 1 elsewhere, with JOIN px of exact 1 next to the middle run
    u = np.ones(W)
    ramp = float(w - JOIN)
    xl = np.clip(xs / ramp, 0, 1)
    xr = np.clip((W - 1 - xs) / ramp, 0, 1)
    env = np.sqrt(np.clip(1.0 - (1.0 - np.minimum(xl, xr)) ** 2, 0, 1)) * u
    frames = {0: [], 1: [], 2: []}
    for f in range(FRAMES):
        tt = f / float(FRAMES)
        field = np.full(W, min_h * 0.45)
        for c, r, lo, hi, m, ph in humps:
            hh = lo + (hi - lo) * (0.5 + 0.5 * math.sin(2 * math.pi * m * tt + ph))
            d = np.mod(xs - c + w / 2.0, w) - w / 2.0
            dome = np.clip(1.0 - (d / r) ** 2, 0, 1) ** 0.7
            field = np.maximum(field, hh * dome)
        top = field * env
        mask = (yab < top[None, :]) & (yab >= 0)
        # the grounded edge is a clean row: any column with a body has its base row
        yn = np.clip(yab / max(1.0, float(h)), 0, 1)
        core = (depth_map(mask) >= 6)
        img = _strip_paint(mask, W, h, yn, core)
        for i, name in ((0, 0), (1, 2), (2, 4)):
            frames[i].append(img.crop((name * w, 0, name * w + w, h)))
    return frames[0], frames[1], frames[2]


def paint_column(mask, depth, m, w, h):
    """A column is shaded by LATERAL position (a bright core down the middle that breathes, shells outward, the outline at the
    edge) — erosion depth alone made a wide column one flat yellow. Dithered at each shell boundary, like `paint`."""
    out = np.zeros((h, w, 4), dtype=np.uint8)
    edges = [0.16, 0.38, 0.62]
    for y in range(h):
        for x in range(w):
            if not mask[y, x]:
                continue
            if depth[y, x] == 0:
                col = OUTLINE
            else:
                v = m[y, x] - (0.05 if (x + y) % 2 == 0 else 0.0)
                k = 0
                for i, e in enumerate(edges):
                    if v >= e:
                        k = i + 1
                col = HOT if (v >= 0.93) else SHELLS[min(k, 3)]
            out[y, x] = (*col, 255)
    return Image.fromarray(out, 'RGBA')


def column_kit(wc, hw, seed, hb=12, hm=18, hc=22, curl=1.3, amp=1.8, lump=0.0):
    """Returns (base, mid, cap): three lists of 8 frames. Width wc, centred; base hb rows, mid hm rows, cap hc rows.
    The two sides BREATHE independently (so the trunk bulges and pinches like a flame, not a sausage), the centreline
    sways, and every term has period hm (and loops in time) so mids stack seamlessly."""
    rng = random.Random(seed)
    nm = 3
    H = hb + nm * hm + hc
    ph = [rng.uniform(0, 2 * math.pi) for _ in range(4)]
    ys, xs = np.mgrid[0:H, 0:wc].astype(float)
    yab = (H - 1.0 - ys)
    yc0 = hb + nm * hm                                    # where the cap starts
    out = {0: [], 1: [], 2: []}
    for f in range(FRAMES):
        tt = f / float(FRAMES)
        yj = (yab - hb) / float(hm)                          # one unit = one mid section (the pattern's period)
        cx = (wc - 1) / 2.0 + curl * np.sin(2 * math.pi * yj + ph[0] - 2 * math.pi * tt)
        half_l = hw + amp * np.sin(2 * math.pi * yj + ph[1] - 2 * math.pi * tt)
        half_r = hw + amp * np.sin(2 * math.pi * yj + ph[2] - 2 * math.pi * tt + 2.3)
        fy = np.clip(yab / 6.0, 0, 1)
        foot = 0.6 + 0.4 * np.sqrt(np.clip(1.0 - (1.0 - fy) ** 2, 0, 1))
        sc = np.where(yab < hb, foot, 1.0)
        # a rounded taper up the cap: full width for the first 4 rows (the join), then closing to a blunt tip
        uc = np.clip((yab - yc0 - 4.0) / float(hc - 4), 0, 1)
        sc = sc * np.where(yab >= yc0, np.power(np.clip(1.0 - np.power(uc, 1.7), 0, 1), 0.5), 1.0)
        hl = half_l * sc
        hr = half_r * sc
        dx = xs - cx
        side = np.where(dx < 0, hl, hr)
        mask = (np.abs(dx) <= side) & (yab >= 0) & (side > 0.6)
        mask[:, 0] = False
        mask[:, -1] = False
        lat = 1.0 - np.abs(dx) / np.maximum(side, 0.01)      # 1 at the centreline, 0 at the edge
        core = lat + 0.14 * np.sin(2 * math.pi * 2 * yj + ph[3] - 2 * math.pi * 2 * tt) - 0.10 * np.clip((yab - yc0) / float(hc), 0, 1)
        depth = depth_map(mask)
        img = paint_column(mask, depth, core, wc, H)
        out[0].append(img.crop((0, H - hb, wc, H)))
        mid_top = H - (hb + 2 * hm)
        out[1].append(img.crop((0, mid_top, wc, mid_top + hm)))
        out[2].append(img.crop((0, 0, wc, hc)))
    return out[0], out[1], out[2]


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
        add('tongue_s_%d' % v, tongue(16, 12, 100 + v, 's', 1))
        add('tongue_m_%d' % v, tongue(24, 18, 110 + v, 'm', 2))
        add('tongue_l_%d' % v, tongue(32, 22, 120 + v, 'l', 3))
        add('tongue_xl_%d' % v, tongue(40, 26, 130 + v, 'xl', 4))
        add('small_%d' % v, small_flame(9, 11, 160 + v))
        # EXTENSION KITS (clean joins at the sides and the top — see the block above)
        for stage, hh, lo, hi in (('light', 13, 3, 11), ('blaze', 22, 7, 20)):
            cl, rn, cr = run_kit(24, hh, 200 + v * 7 + (0 if stage == 'light' else 50), lo, hi)
            add('runl_%s_%d' % (stage, v), cl, 'run, left cap (rises out of nothing)')
            add('run_%s_%d' % (stage, v), rn, 'run, middle tile (identical edges, tiles to any width)')
            add('runr_%s_%d' % (stage, v), cr, 'run, right cap (sinks to nothing)')
        for tag, wc, hw, sd in (('w', 30, 9, 300), ('n', 22, 6, 400)):
            bs, md, cp = column_kit(wc, hw, sd + v, hb=12 if tag == 'w' else 10, hc=18 if tag == 'w' else 14, curl=1.3 if tag == 'w' else 0.9, amp=1.8 if tag == 'w' else 1.2)
            add('col%sb_%d' % (tag, v), bs, 'column base (rounded foot)')
            add('col%sm_%d' % (tag, v), md, 'column mid (stacks to any height)')
            add('col%sc_%d' % (tag, v), cp, 'column cap (blunt round top)')
    add('stair', bed(26, 16, 170, 12, 4, 4, 1.0, 2), 'fire spilling over a step')
    with open(os.path.join(OUT, 'fire_meta.json'), 'w') as f:
        json.dump({'fps': FPS, 'frames': FRAMES, 'scale': SCALE, 'sheets': SHEETS}, f, indent=1, sort_keys=True)


def preview():
    """Frames 0 and 3 of every sheet, at GAME size (x2) on the corridor wall tone, then x2 again for the eye."""
    bg = (201, 170, 118, 255)
    names = sorted(SHEETS.keys())
    groups = [[n for n in names if n.startswith(p)] for p in ('bed_front', 'bed_back', 'tongue', 'small', 'stair')]
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


def _sheet_frame(name, fi):
    sh = Image.open(os.path.join(OUT, name + '.png'))
    fw, fh = SHEETS[name]['frame']
    return sh.crop((fi * fw, 0, fi * fw + fw, fh))


def assemble_run(stage, v, n, fi):
    """cap_l + n middles + cap_r at native size (what FireArt.assemble_run draws, 2x)."""
    pieces = [_sheet_frame('runl_%s_%d' % (stage, v), fi)] + [_sheet_frame('run_%s_%d' % (stage, v), fi)] * n + [_sheet_frame('runr_%s_%d' % (stage, v), fi)]
    w = sum(p.width for p in pieces)
    out = Image.new('RGBA', (w, pieces[0].height), (0, 0, 0, 0))
    x = 0
    for p_ in pieces:
        out.alpha_composite(p_, (x, 0))
        x += p_.width
    return out


def assemble_column(tag, v, n, fi):
    pieces = [_sheet_frame('col%sc_%d' % (tag, v), fi)] + [_sheet_frame('col%sm_%d' % (tag, v), fi)] * n + [_sheet_frame('col%sb_%d' % (tag, v), fi)]
    h = sum(p.height for p in pieces)
    out = Image.new('RGBA', (pieces[0].width, h), (0, 0, 0, 0))
    y = 0
    for p_ in pieces:
        out.alpha_composite(p_, (0, y))
        y += p_.height
    return out


def assembly_preview():
    """The extension kits put together at game size: runs of 0/1/2/3 middles, columns of 0/1/2/3 mids, two frames each."""
    bg = (201, 170, 118, 255)
    rows = []
    for stage in ('light', 'blaze'):
        for v in (1, 2):
            ims = [assemble_run(stage, v, n, fi).resize((assemble_run(stage, v, n, fi).width * SCALE, assemble_run(stage, v, n, fi).height * SCALE), Image.NEAREST) for n in (0, 1, 2, 3) for fi in (0,)]
            rows.append(ims)
    cols = []
    for tag in ('w', 'n'):
        for v in (1, 2, 3):
            for n in (0, 1, 2, 3):
                for fi in (0, 4):
                    im = assemble_column(tag, v, n, fi)
                    cols.append(im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST))
    rows.append(cols)
    rw = [sum(i.width for i in ims) + 10 * len(ims) for ims in rows]
    rh = [max(i.height for i in ims) + 10 for ims in rows]
    sheet = Image.new('RGBA', (max(rw), sum(rh)), bg)
    y = 0
    for ims, h in zip(rows, rh):
        x = 0
        for im in ims:
            sheet.alpha_composite(im, (x, y + h - im.height - 5))
            x += im.width + 10
        y += h
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save(os.path.join(PREV, 'fire_extensions.png'))
    return sheet


if __name__ == '__main__':
    build()
    s = preview()
    assembly_preview()
    print('wrote', len(SHEETS), 'sheets; preview', s.size)
