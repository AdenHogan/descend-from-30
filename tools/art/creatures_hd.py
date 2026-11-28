"""THE REFINEMENT PASS for the things (owner 2026-11-28: "do the same refinement pass on the enemies"; the same asks as for the players: more detail, more colour, more quality — the variety of
hue of the classic 2D side-scrollers).

`grade(im, kind)` runs on each finished frame BEFORE the outline: SHADOWS are pushed toward a kind-specific cold tone (indigo, wine, deep teal) and LIGHTS toward a warm or acid one, so no creature is one
hue made darker and lighter; a fine MOTTLE (a sparse darker speck pattern on the mid-tones) gives the flesh a surface. `rim(im, kind)` runs AFTER the outline: a thin cool light just inside the
lower-right edge (a comic-book rim) and a hot wet SPECULAR on the upper-left of every large mass.
"""
import math

import people as P

SHADOW = {'standard': (74, 22, 118), 'big': (34, 22, 110), 'longarm': (10, 54, 84), 'spitter': (56, 12, 92), 'crawler': (96, 12, 84), 'flyer': (46, 32, 118)}
LIGHT = {'standard': (255, 206, 150), 'big': (255, 236, 160), 'longarm': (206, 255, 206), 'spitter': (214, 255, 126), 'crawler': (255, 206, 214), 'flyer': (232, 214, 255)}
RIM = {'standard': (150, 214, 255), 'big': (170, 200, 255), 'longarm': (160, 255, 230), 'spitter': (150, 255, 200), 'crawler': (190, 220, 255), 'flyer': (180, 210, 255)}


def _lum(c):
    return (0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]) / 255.0


def grade(im, kind):
    px = im.load()
    W, H = im.size
    sh, li = SHADOW[kind], LIGHT[kind]
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            L = _lum((r, g, b))
            col = (r, g, b)
            s = max(0.0, min(1.0, (0.42 - L) / 0.42))
            h = max(0.0, min(1.0, (L - 0.60) / 0.40))
            if s > 0.0:
                col = P._mix(col, sh, 0.58 * s)
            if h > 0.0:
                col = P._mix(col, li, 0.42 * h)
            if 0.20 < L < 0.66 and (x * 3 + y * 5) % 7 == 0:           # the mottle: a darker speck on the mid-tones (a skin, not a plastic)
                col = P._mix(col, sh, 0.42)
            elif 0.40 < L < 0.80 and (x * 5 + y * 3) % 13 == 0:        # ...and a lighter one, so it is not just dark spots
                col = P._mix(col, li, 0.30)
            px[x, y] = tuple(int(v) for v in col) + (a,)


def rim(im, kind):
    px = im.load()
    W, H = im.size
    src = im.copy().load()

    def opaque(x, y):
        return 0 <= x < W and 0 <= y < H and src[x, y][3] > 0

    def is_edge(x, y):
        return opaque(x, y) and not (opaque(x + 1, y) and opaque(x - 1, y) and opaque(x, y + 1) and opaque(x, y - 1))
    rc = RIM[kind]
    for y in range(H):
        for x in range(W):
            if not opaque(x, y) or is_edge(x, y):
                continue
            # an inner pixel that touches the lower-right edge: the rim light
            if (is_edge(x + 1, y) or is_edge(x, y + 1)) and _lum(src[x, y][:3]) > 0.22 and not (is_edge(x - 1, y) or is_edge(x, y - 1)):
                px[x, y] = tuple(int(v) for v in P._mix(src[x, y][:3], rc, 0.52)) + (255,)
    # a hot wet SPECULAR on the upper-left of each big mass: the brightest-lit pixel of each coarse cell whose neighbours above and to the left are in shadow
    cell = 9
    for cy in range(0, H, cell):
        for cx in range(0, W, cell):
            best, bp = 0.0, None
            for y in range(cy, min(H, cy + cell)):
                for x in range(cx, min(W, cx + cell)):
                    if src[x, y][3] and _lum(src[x, y][:3]) > best and not is_edge(x, y):
                        best, bp = _lum(src[x, y][:3]), (x, y)
            if bp and best > 0.70:
                x, y = bp
                px[x, y] = (255, 255, 250, 255)
                if opaque(x + 1, y) and _lum(src[x + 1, y][:3]) > 0.7:
                    px[x + 1, y] = tuple(int(v) for v in P._mix(src[x + 1, y][:3], (255, 255, 250), 0.6)) + (255,)
