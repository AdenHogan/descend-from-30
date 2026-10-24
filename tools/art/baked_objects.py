"""BAKED OBJECTS — what a baked room module is made of, measured (owner round 48j: "every item needs to have depth and not just be flat 2D. We really need consistency on this across the board").

The furniture library and the corridor props are audited sprite by sprite (tools/art/volume_audit.py); a baked module is ONE picture, so its objects have to be found in it first. While a module is
rendered, `pixlib.finish_module` hands this file the final art and the bare wall + floor it was drawn on: every pixel that differs from the bare shell and is not a soft SHADOW (the floor darkened,
same hue) belongs to something drawn on it; touching pixels are one object. Each object is then measured the way a library sprite is — how many distinct colours it uses, how much of it one colour
covers, its tonal range — and the module's list is written to assets/rooms/object_meta.json (generated; `volume_audit.py --check` reads it, says when it is stale, and fails on a flat object that is not
on the owner-visible debt list).

An object that touches another (a sofa on its rug, a table carrying its tea set) is ONE object here, so the measure is generous: it finds the flat things that stand alone — a toy, a stool, a rug.
"""
import hashlib
import json
import os

W, H = 320, 144
MIN_PX = 60                         # smaller than this is a speck (a nail, a crumb), not an object
SHADOW_LO, SHADOW_HI = 0.30, 0.97   # a pixel that is the bare one scaled by this much, hue unchanged, is shadow
HUE_TOL = 14                        # ... within this many 0-255 steps of the scaled colour
META = os.path.join('assets', 'rooms', 'object_meta.json')


def _is_shadow(p, b):
    """The pixel is the bare floor / wall darkened: each channel the bare one times ONE factor."""
    if b[0] + b[1] + b[2] < 30:
        return False
    k = (p[0] + p[1] + p[2]) / float(b[0] + b[1] + b[2])
    if not (SHADOW_LO <= k <= SHADOW_HI):
        return False
    return all(abs(p[i] - b[i] * k) <= HUE_TOL for i in range(3))


def objects(img, bare):
    """[{bbox, n, colours, dom, range}] for every object drawn on `bare` in `img` (both RGBA, 320 x 144)."""
    px, bp = img.load(), bare.load()
    mask = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            p, b = px[x, y], bp[x, y]
            if p[3] < 200 or p == b:
                continue
            if _is_shadow(p, b):
                continue
            mask[y][x] = True
    seen = [[False] * W for _ in range(H)]
    out = []
    for y0 in range(H):
        for x0 in range(W):
            if not mask[y0][x0] or seen[y0][x0]:
                continue
            stack, comp = [(x0, y0)], []
            seen[y0][x0] = True
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < W and 0 <= ny < H and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if len(comp) < MIN_PX:
                continue
            cols = {}
            lums = []
            for (x, y) in comp:
                p = px[x, y]
                cols[p[:3]] = cols.get(p[:3], 0) + 1
                lums.append((0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]) / 255.0)
            lums.sort()
            n = len(comp)
            xs = [c[0] for c in comp]
            ys = [c[1] for c in comp]
            out.append({'bbox': [min(xs), min(ys), max(xs), max(ys)], 'n': n, 'colours': len(cols), 'dom': round(max(cols.values()) / float(n), 3),
                        'range': round(lums[int(n * 0.95)] - lums[int(n * 0.05)], 3)})
    return out


def need(n):
    """Colours an object of n opaque px must use (the furniture library's rule)."""
    return 16 if n >= 600 else 12 if n >= 200 else 8


def is_flat(o):
    return o['colours'] < need(o['n']) or o['dom'] > 0.5


def key(name, o):
    x0, y0, x1, y1 = o['bbox']
    return '%s@%d,%d' % (name, ((x0 + x1) // 2) // 8 * 8, ((y0 + y1) // 2) // 8 * 8)


def sha(img):
    return hashlib.sha1(img.tobytes()).hexdigest()


def write(name, img, bare, root, art=None):
    """Record the module's objects in assets/rooms/object_meta.json — one line per module, so a regenerated module changes one line. `img` = the module with its balcony strip (what is measured),
    `art` = the picture exported as assets/rooms/<name>.png (what the staleness hash covers)."""
    objs = objects(img, bare)
    path = os.path.join(root, META)
    data = {}
    if os.path.exists(path):
        data = json.load(open(path))
    data[name] = {'sha': sha(art if art is not None else img), 'objects': objs}
    with open(path, 'w') as f:
        f.write('{\n' + ',\n'.join('%s: %s' % (json.dumps(k), json.dumps(data[k], sort_keys=True, separators=(',', ':'))) for k in sorted(data)) + '\n}\n')
    return objs
