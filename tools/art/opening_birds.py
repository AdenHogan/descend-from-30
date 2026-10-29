#!/usr/bin/env python3
"""THE OPENING'S BIRDS (owner round 49: "the birds on the telephone wire… are static and could actually fly away with flapping wings, as
if disturbed. The birds at the top just sort of float, and don't flap their wings").

One sheet, `assets/opening/birds.png`, drawn pixel by pixel (every point an integer, no anti-aliasing — the old sky birds were vector
lines over a pixel picture). Two rows:

    row 0  NEAR crows (14 x 12), facing right:  perched · crouch (about to go) · wings up · wings raised · wings level · wings down · glide
    row 1  FAR birds (9 x 6), facing right:     wings up · level · down · glide

The game flips them for a leftward bird and plays the flap cycle  up → raised → level → down → level…  at the rate a crow beats its wings.
`meta['birds']` lists every cell, so the game never hard-codes the sheet's layout.
"""
from PIL import Image

from pixlib import Canvas, hexc

BODY = hexc('1b1b22')
SHADE = hexc('0f0f14')
HI = hexc('3d3d4b')
BEAK = hexc('2a2a31')
NEAR_W, NEAR_H = 14, 12
FAR_K = 0.72                                                   # the sky birds are the crows drawn smaller, not a different bird
FAR_W, FAR_H = 10, 9
NEAR = ['perched', 'crouch', 'up', 'raised', 'level', 'down', 'glide']
FAR = ['up', 'level', 'down', 'glide']


def _blade(c, x0, y0, x1, y1, w0, w1, col, notch=True):
    """A wing: a tapered blade from the shoulder (x0, y0) to the tip (x1, y1), with the tip split into primaries."""
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        t = i / float(n)
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        w = w0 + (w1 - w0) * t
        # the blade is thickest across its short axis: thicken in whichever direction the line is flatter
        if abs(x1 - x0) >= abs(y1 - y0):
            for k in range(int(round(w))):
                c.put(int(round(x)), int(round(y)) + k - int(w // 2), col)
        else:
            for k in range(int(round(w))):
                c.put(int(round(x)) + k - int(w // 2), int(round(y)), col)
    if notch:                                                    # primaries: three short feathers fanning off the tip
        dx = 1 if x1 >= x0 else -1
        dy = 1 if y1 >= y0 else -1
        c.put(int(round(x1)) + dx, int(round(y1)), col)
        c.put(int(round(x1)), int(round(y1)) + dy, col)


def _near(name):
    c = Canvas(NEAR_W, NEAR_H, seed=3)
    if name in ('perched', 'crouch'):
        low = 1 if name == 'crouch' else 0
        c.poly([(4, 6 + low), (0, 9 + low), (1, 10 + low), (5, 8 + low)], SHADE)           # the tail, down and back
        c.ellipse(8, 7 + low, 4.2, 2.7 if not low else 2.2, BODY)                           # the body
        c.ellipse(12, 5 + low, 1.9, 1.7, BODY)                                              # the head
        c.poly([(13, 5 + low), (15, 5 + low), (13, 6 + low)], BEAK)                         # the beak
        c.hline(5, 9, 5 + low, HI)                                                          # a sheen along the back
        c.line(5, 7 + low, 10, 8 + low, SHADE)                                              # the folded wing's edge
        if name == 'perched':
            c.put(8, 10, SHADE)
            c.put(10, 10, SHADE)
            c.put(8, 11, SHADE)
            c.put(10, 11, SHADE)
        else:                                                                               # about to go: the wings lift off the back
            c.poly([(5, 6), (10, 4), (9, 3), (6, 4)], BODY)
            c.line(6, 4, 9, 3, HI)
            c.put(10, 11, SHADE)
            c.put(8, 11, SHADE)
        return c.img
    return _flight(name, 1.0)


def _flight(name, k):
    """A crow in flight at scale k (1.0 = the near crow's 14 x 12): a long level body, head forward, a fan of tail behind, and the wings as
    scalloped blades rotated about the shoulder."""
    w, h = int(round(NEAR_W * k)), int(round(NEAR_H * k))
    c = Canvas(w, h, seed=3)
    spec = {                       # (angle of the wing's spine, its visible length, width): the foreshortening is real — level wings are edge-on
        'up': (-122.0, 9.0, 3.2), 'raised': (-72.0, 6.6, 3.0), 'level': (-8.0, 4.4, 3.2), 'down': (58.0, 8.6, 3.2), 'glide': (-38.0, 7.6, 2.8),
    }[name]
    ang, ln, wd = spec
    S = (7.5 * k, 5.5 * k)
    if name != 'level':
        _wing(c, S, ang + 16.0, ln * 0.86 * k, wd * 0.9 * k, SHADE, None)                  # the far wing, behind, a little apart
    c.poly([(3 * k, 5 * k), (0, 5 * k), (0, 8 * k), (3 * k, 7 * k)], SHADE)                  # the tail fan
    c.ellipse(7 * k, 6 * k, 4.0 * k, 2.2 * k, BODY)                                         # the body
    c.ellipse(11 * k, 5 * k, 1.8 * k, 1.6 * k, BODY)                                        # the head
    c.poly([(12 * k, 5 * k), (14 * k, 5 * k), (12 * k, 6 * k)], BEAK)
    if k >= 1.0:
        c.hline(5, 9, 4, HI)
    _wing(c, S, ang, ln * k, wd * k, BODY, HI if k >= 1.0 else None)                        # the near wing over it
    return c.img


def _wing(c, S, ang, ln, wd, col, edge):
    """A wing rotated `ang` degrees about the shoulder S: a broad blade, its leading edge a gentle bulge, its trailing edge scalloped into
    four primaries. Rasterised by pixel centre (no anti-aliasing); `edge` lights the leading edge."""
    import math
    loc = [(0.0, -1.0), (0.45, -1.7), (0.85, -1.3), (1.0, -0.25),                          # root front -> bulge -> tip
           (0.93, 0.35), (0.84, 0.15), (0.77, 0.95), (0.66, 0.55), (0.56, 1.2), (0.44, 0.8), (0.30, 1.1), (0.0, 0.9)]
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    pts = []
    for (u, v) in loc:
        x = u * ln
        y = v * wd * 0.5
        pts.append((S[0] + x * ca - y * sa, S[1] + x * sa + y * ca))

    def inside(px, py):
        n = len(pts)
        ok = False
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi:
                ok = not ok
            j = i
        return ok

    for y in range(c.h):
        for x in range(c.w):
            if inside(x + 0.5, y + 0.5):
                c.put(x, y, col)
    if edge:                                                                                 # the leading edge, a lit line along the first few pixels
        for k in range(1, int(ln * 0.8)):
            u = k / ln
            x = S[0] + (u * ln) * ca - (-1.2 * wd * 0.5) * sa
            y = S[1] + (u * ln) * sa + (-1.2 * wd * 0.5) * ca
            if inside(x + 0.0, y + 0.0):
                c.put(int(x), int(y), edge)


def _far(name):
    return _flight(name, FAR_K)


def draw_birds():
    """-> (the sheet, its meta): {'near': [{name, x, y, w, h}], 'far': [...]}"""
    gap = 1
    w = max(len(NEAR) * (NEAR_W + gap), len(FAR) * (FAR_W + gap))
    sheet = Image.new('RGBA', (w, NEAR_H + FAR_H + 2 * gap), (0, 0, 0, 0))
    meta = {'near': [], 'far': []}
    for i, n in enumerate(NEAR):
        x = i * (NEAR_W + gap)
        sheet.paste(_near(n), (x, 0))
        meta['near'].append({'name': n, 'x': x, 'y': 0, 'w': NEAR_W, 'h': NEAR_H})
    for i, n in enumerate(FAR):
        x = i * (FAR_W + gap)
        sheet.paste(_far(n), (x, NEAR_H + gap))
        meta['far'].append({'name': n, 'x': x, 'y': NEAR_H + gap, 'w': FAR_W, 'h': FAR_H})
    return sheet, meta


if __name__ == '__main__':
    import sys
    sheet, meta = draw_birds()
    out = sys.argv[1] if len(sys.argv) > 1 else '/tmp/birds.png'
    bg = Image.new('RGBA', sheet.size, (176, 196, 210, 255))
    bg.alpha_composite(sheet)
    bg.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save(out)
    print(out, sheet.size)
