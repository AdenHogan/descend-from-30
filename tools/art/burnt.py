"""BURNT-OUT MODULE ART (owner round 34: "while the hallway looks burned and ruined, the burned out apartment
looked mostly normal. We need to implement burned out module art too so we feel it's been an awful fire").

A CHARRED apartment (WorldState.is_apartment_charred — the fire's worst stage, run 3) swaps every module's
art for a burnt version of the SAME room: the furniture is still where it was (so the nodes still sit on
something), but it is a blackened husk. Made from the finished run-3 art (so nothing about the room's layout
or the run's decay is lost), by a pass that reads what each pixel IS and burns it that way:

  wood        -> alligator-charred (a cellular crackle of black blocks, embers glowing in the cracks)
  cloth       -> ash grey, with burnt-through holes
  pale things -> sooted (porcelain, appliances, linen, paper)
  walls       -> sooted from the ceiling down and above where things burned (flame-lick plumes), the paper
                 burnt away in patches to blackened plaster, two burnt-through holes to the lath
  ceiling     -> a ragged collapsed edge with lath showing
  floor       -> blackened boards, ash drifts, wet black patches, charred planks and ash heaps lying about

Every field is a pure function of (x, y, seed) in MODULE coordinates, so the floor wedge strip, the balcony-strip
furniture and the module itself all agree where they meet.

Writes assets/rooms/<name>_burnt.png (+ _burnt_strip.png, _burnt_floor_ext.png, _burnt_floor.png) for the 30
module variants, and assets/rooms/balcony_burnt.png. room.gd's apply_burnt_art swaps them in.

Run:  python3 tools/art/burnt.py [--preview] [--check]     (after tools/art/build_all.py)
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
ROOMS = os.path.join(ROOT, 'assets', 'rooms')
W, H = 320, 144
SEAM = 100
FLOOR_EXT_M = 96
TYPES = ['living_room', 'bedroom', 'kitchen', 'bathroom', 'study', 'dining_room']
VARIANTS = ['', '_b', '_c', '_d', '_e']
CHAR = np.array([24, 19, 16], np.float32) / 255.0
ASH = np.array([104, 100, 94], np.float32) / 255.0
SOOT = np.array([66, 57, 49], np.float32) / 255.0
EMBER = np.array([226, 104, 38], np.float32) / 255.0


# --- coordinate-hash noise (a pure function of integer lattice coords, so strips agree with the module) ----------
def _h(ix, iy, seed):
    n = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    n = n ^ (n >> 16)
    return (n & 0xFFFF).astype(np.float32) / 65535.0


def vnoise(X, Y, scale, seed):
    x, y = X / scale, Y / scale
    x0, y0 = np.floor(x), np.floor(y)
    fx, fy = x - x0, y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = _h(x0, y0, seed), _h(x0 + 1, y0, seed)
    c, d = _h(x0, y0 + 1, seed), _h(x0 + 1, y0 + 1, seed)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(X, Y, scale, seed, octaves=3):
    out, amp, tot = 0.0, 1.0, 0.0
    for o in range(octaves):
        out = out + vnoise(X, Y, scale / (2 ** o), seed + o * 17) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def worley_edge(X, Y, cell, seed):
    """F2 - F1 of a jittered grid: ~0 along the cracks between cells (alligator-char blocks)."""
    gx, gy = np.floor(X / cell), np.floor(Y / cell)
    f1 = np.full(X.shape, 9.0, np.float32)
    f2 = np.full(X.shape, 9.0, np.float32)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            cx, cy = gx + dx, gy + dy
            px = (cx + _h(cx, cy, seed)) * cell
            py = (cy + _h(cx, cy, seed + 91)) * cell
            d = np.sqrt((X - px) ** 2 + (Y - py) ** 2) / cell
            m = d < f1
            f2 = np.where(m, f1, np.minimum(f2, d))
            f1 = np.where(m, d, f1)
    return f2 - f1


def _rgb_to_hsv(rgb):
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    sat = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx)
    dd = np.maximum(d, 1e-6)
    h = np.where(mx == r, ((g - b) / dd) % 6, h)
    h = np.where(mx == g, (b - r) / dd + 2, h)
    h = np.where(mx == b, (r - g) / dd + 4, h)
    return (h / 6.0) % 1.0, sat, mx


def _smooth(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def plumes(X, Y, seed):
    """Where flame licked up the wall: a few soft-edged tongues rising from the skirting, ragged at the top."""
    rng = np.random.default_rng(seed)
    out = np.zeros(X.shape, np.float32)
    for _ in range(7):
        cx = rng.uniform(10, W - 10)
        wid = rng.uniform(10, 30)
        hgt = rng.uniform(45, 100)
        across = np.exp(-(((X - cx) / wid) ** 2))
        up = np.clip(1.0 - (SEAM - Y) / hgt, 0, 1)
        out = np.maximum(out, across * up ** 0.7)
    return out


def burn(arr, seed, ox=0, oy=0, kind='module'):
    """arr: float RGBA 0..1, (h, w, 4). ox, oy: this image's top-left in MODULE coordinates.
    kind 'module' (the full art), 'strip' (furniture on transparent), 'floor' (a bare floor strip)."""
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    X, Y = xx + ox, yy + oy
    rgb = arr[..., :3].copy()
    alpha = arr[..., 3]
    hue, sat, val = _rgb_to_hsv(rgb)
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    floor = (Y >= SEAM).astype(np.float32) if kind != 'floor' else np.ones_like(Y)
    out = rgb.copy()

    # --- soot: heavy at the ceiling, sooty everywhere, tongues above where things burned
    ceil_g = np.clip(1.0 - Y / 105.0, 0, 1) ** 0.8
    S = np.clip(0.50 + 0.40 * ceil_g + 0.45 * plumes(X, Y, seed) + 0.14 * (fbm(X, Y, 40, seed + 3) - 0.5), 0, 1)

    # --- material masks
    wood = ((hue > 0.02) & (hue < 0.14) & (sat > 0.16) & (sat < 0.85) & (val < 0.72)).astype(np.float32)
    cloth = (sat > 0.34).astype(np.float32) * (1 - wood)
    cloth = np.maximum(cloth, ((sat > 0.22) & ~((hue > 0.02) & (hue < 0.14))).astype(np.float32) * 0.8)
    pale = ((val > 0.62) & (sat < 0.3)).astype(np.float32)

    edge = worley_edge(X, Y, 4.6, seed + 11)
    block = _smooth(edge, 0.02, 0.22)                       # 0 in the cracks, 1 across a block's face
    char_amt = np.clip(0.62 + 0.38 * (1 - block) + 0.25 * (fbm(X, Y, 9, seed + 5) - 0.4), 0, 1)
    wood_out = out * 0.30 * (0.6 + 0.6 * block[..., None]) * (1 - char_amt[..., None]) + CHAR * char_amt[..., None] * 0.85
    cloth_g = lum[..., None] * np.array([0.34, 0.33, 0.32], np.float32) + ASH * 0.10
    holes = _smooth(fbm(X, Y, 7, seed + 21), 0.66, 0.72)
    cloth_out = cloth_g * (1 - holes[..., None]) + CHAR * holes[..., None]
    pale_out = (out * 0.52 * (1 - 0.45 * S[..., None])) + SOOT * 0.35 * S[..., None]

    grey = lum[..., None] * np.ones(3, np.float32)
    base = (out * 0.25 + grey * 0.75) * 0.80 * (1 - 0.40 * S[..., None]) + SOOT * (0.52 * S[..., None])   # wall / everything else
    m_w, m_c, m_p = wood[..., None], cloth[..., None], pale[..., None]
    res = base
    res = pale_out * m_p + res * (1 - m_p)
    res = cloth_out * m_c + res * (1 - m_c)
    res = wood_out * m_w + res * (1 - m_w)

    if kind != 'floor':
        # the wallpaper burnt off in patches to blackened plaster; two holes right through to the lath
        wall = (1 - floor) * (1 - wood) * (1 - cloth)
        patch = _smooth(fbm(X, Y, 22, seed + 31), 0.64, 0.655) * wall * (S > 0.55)
        plaster = SOOT * 0.50 * (0.7 + 0.6 * fbm(X, Y, 4, seed + 33)[..., None])
        res = plaster * patch[..., None] + res * (1 - patch[..., None])
        rng = np.random.default_rng(seed + 7)
        for _ in range(1):
            cx, cy = rng.uniform(40, W - 40), rng.uniform(18, 70)
            rx, ry = rng.uniform(9, 17), rng.uniform(7, 14)
            wob = (fbm(X, Y, 3.2, seed + int(cx)) - 0.5) * 2.4
            d = ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 + wob
            hole = (d < 1.0).astype(np.float32) * wall
            rim = ((d >= 1.0) & (d < 1.5)).astype(np.float32) * wall
            lath = ((Y.astype(np.int32) % 6) < 2).astype(np.float32)
            inner = CHAR * (1 - 0.0) + np.array([60, 42, 28], np.float32) / 255.0 * lath[..., None] * 0.7
            res = inner * hole[..., None] + res * (1 - hole[..., None])
            res = res * (1 - 0.5 * rim[..., None]) + CHAR * 0.5 * rim[..., None]
        # the ceiling came down in places: a ragged edge hanging with lath
        coll = 4 + 12 * _smooth(fbm(X, np.zeros_like(Y) + 7, 18, seed + 41), 0.50, 0.75) \
            + 3 * (fbm(X, Y, 3, seed + 43) - 0.5)
        ceil = (Y < coll).astype(np.float32)
        lath_c = ((Y.astype(np.int32) % 4) < 1).astype(np.float32)
        res = (CHAR * 1.2 + np.array([54, 38, 26], np.float32) / 255.0 * lath_c[..., None] * 0.6) * ceil[..., None] + res * (1 - ceil[..., None])

    if kind in ('module', 'floor'):
        # the floor: blackened boards, ash drifts, wet black patches
        ash = _smooth(fbm(X, Y, 14, seed + 51), 0.66, 0.74) * 0.8
        wet = _smooth(fbm(X, Y, 18, seed + 53), 0.60, 0.70)
        fl = (floor * (1 - wood * (1 - floor))) if kind == 'module' else floor
        fg = (res @ np.array([0.299, 0.587, 0.114], np.float32))[..., None] * np.ones(3, np.float32)
        floor_col = (res * 0.5 + fg * 0.5) * 0.9
        floor_col = ASH * 0.7 * (0.9 + 0.2 * block[..., None]) * ash[..., None] + floor_col * (1 - ash[..., None])
        floor_col = (CHAR * 0.8 + np.array([20, 24, 30], np.float32) / 255.0 * 0.4) * wet[..., None] * 0.9 + floor_col * (1 - wet[..., None] * 0.9)
        if kind == 'module':
            # furniture standing on the floor keeps its own burnt look: only floor-ish pixels (not wood / cloth)
            keep = np.maximum(wood, cloth)
            floor_mask = fl * (1 - keep)
        else:
            floor_mask = fl
        res = floor_col * floor_mask[..., None] + res * (1 - floor_mask[..., None])

    # embers in the cracks (a few, dim) — only where it is char
    if kind != 'floor':
        crack = ((1 - block) > 0.85) & (wood > 0.5)
        sparks = crack & (_h(X.astype(np.int32), Y.astype(np.int32), seed + 61) > 0.985) & (Y < SEAM)
        res = np.where(sparks[..., None], EMBER, res)

    res = np.clip(res, 0, 1)
    outa = np.concatenate([res, alpha[..., None]], -1)
    return outa


def debris(img, seed):
    """Things lying on the burnt floor: charred planks, ash heaps, a few embers. Module only (PIL)."""
    rng = np.random.default_rng(seed + 99)
    d = ImageDraw.Draw(img)
    for _ in range(9):
        x, y = int(rng.uniform(14, W - 14)), int(rng.uniform(SEAM + 8, H - 8))
        kind = rng.integers(0, 3)
        if kind == 0:                                              # a charred plank, slanting
            ln = int(rng.uniform(9, 24))
            dy = int(rng.uniform(-5, 5))
            d.line([(x, y), (x + ln, y + dy)], fill=(22, 17, 14, 255), width=2)
            d.line([(x, y - 1), (x + ln, y + dy - 1)], fill=(64, 46, 34, 255), width=1)
            if rng.random() < 0.5:
                d.point((x + ln // 2, y + dy // 2 - 1), fill=(226, 104, 38, 255))
        elif kind == 1:                                            # an ash heap
            rx, ry = int(rng.uniform(5, 11)), int(rng.uniform(2, 4))
            d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(86, 83, 78, 255))
            d.ellipse([x - rx + 2, y - ry, x + rx - 3, y + ry - 1], fill=(112, 108, 102, 255))
            d.point((x - 2, y - ry), fill=(150, 146, 140, 255))
        else:                                                      # a blackened lump of something
            r = int(rng.uniform(2, 5))
            d.ellipse([x - r, y - r // 2, x + r, y + r // 2 + 1], fill=(28, 23, 20, 255))
            d.point((x - 1, y - r // 2), fill=(70, 62, 54, 255))
    return img


def burn_file(src, dst, seed, kind='module', ox=0, oy=0, with_debris=False):
    if not os.path.exists(src):
        return False
    im = Image.open(src).convert('RGBA')
    arr = np.asarray(im, np.float32) / 255.0
    out = burn(arr, seed, ox, oy, kind)
    img = Image.fromarray((out * 255 + 0.5).astype(np.uint8), 'RGBA')
    if with_debris:
        img = debris(img, seed)
    img.save(dst)
    return True


def build(preview=False, out_dir=ROOMS):
    done = []
    for t in TYPES:
        for v in VARIANTS:
            name = t + v
            seed = abs(hash(('burnt', name))) % 100000 if False else sum(ord(c) * (i + 3) for i, c in enumerate(name)) % 100000
            src = os.path.join(ROOMS, name + '_r3.png')
            if not os.path.exists(src):
                src = os.path.join(ROOMS, name + '.png')
            if burn_file(src, os.path.join(out_dir, name + '_burnt.png'), seed, 'module', 0, 0, True):
                done.append(name)
            strip = os.path.join(ROOMS, name + '_r3_strip.png')
            if not os.path.exists(strip):
                strip = os.path.join(ROOMS, name + '_strip.png')
            burn_file(strip, os.path.join(out_dir, name + '_burnt_strip.png'), seed, 'strip', 0, 0, False)
            for suffix in ('_floor_ext', '_floor'):
                fsrc = os.path.join(ROOMS, name + '_r3' + suffix + '.png')
                if not os.path.exists(fsrc):
                    fsrc = os.path.join(ROOMS, name + suffix + '.png')
                ox = -FLOOR_EXT_M if suffix == '_floor_ext' else 0
                burn_file(fsrc, os.path.join(out_dir, name + '_burnt' + suffix + '.png'), seed, 'floor', ox, SEAM)
    bsrc = os.path.join(ROOMS, 'balcony_r3.png')
    if not os.path.exists(bsrc):
        bsrc = os.path.join(ROOMS, 'balcony.png')
    burn_file(bsrc, os.path.join(out_dir, 'balcony_burnt.png'), 4242, 'module', 0, 0, False)
    return done


def preview():
    names = ['living_room', 'kitchen_d', 'bedroom_e', 'bathroom', 'study_b', 'dining_room_c']
    cells = []
    for n in names:
        a = Image.open(os.path.join(ROOMS, n + ('_r3.png' if os.path.exists(os.path.join(ROOMS, n + '_r3.png')) else '.png'))).convert('RGB')
        b = Image.open(os.path.join(ROOMS, n + '_burnt.png')).convert('RGB')
        c = Image.new('RGB', (W * 2 + 6, H), (14, 14, 16))
        c.paste(a, (0, 0)); c.paste(b, (W + 6, 0))
        cells.append(c.resize((c.width * 2, c.height * 2), Image.NEAREST))
    sheet = Image.new('RGB', (cells[0].width, sum(c.height + 4 for c in cells)), (10, 10, 12))
    y = 0
    for c in cells:
        sheet.paste(c, (0, y)); y += c.height + 4
    out = os.path.join(ROOT, 'docs', 'art_reference', 'burnt_rooms.png')
    sheet.save(out)
    print('wrote', out)


def check():
    import tempfile
    tmp = tempfile.mkdtemp(prefix='burnt_')
    build(False, tmp)
    bad = []
    for fn in sorted(os.listdir(tmp)):
        a, b = os.path.join(tmp, fn), os.path.join(ROOMS, fn)
        if not os.path.exists(b) or open(a, 'rb').read() != open(b, 'rb').read():
            bad.append(fn)
    if bad:
        print('BURNT: stale or missing — run: python3 tools/art/burnt.py  (%s)' % ', '.join(bad[:6]))
        sys.exit(1)
    print('burnt art current (%d files)' % len(os.listdir(tmp)))


if __name__ == '__main__':
    if '--check' in sys.argv:
        check()
    else:
        n = build()
        print('burnt %d modules' % len(n))
        if '--preview' in sys.argv:
            preview()
