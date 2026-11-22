#!/usr/bin/env python3
"""HUD PORTRAITS, drawn the way an illustrator draws them (a second start; the procedural / per-pixel-shaded generator is archived in tools/art/_archive).

The method is the opposite of the first one: nothing is shaded per pixel from a formula. A portrait is a stack of DRAWN SHAPES — a head, a jaw, a lock of hair, a collar —
each a closed curve with a flat fill, ONE hard shade shape cut across it by the same light for everything (upper left), a thin lit edge, and an INK LINE round it whose weight
changes along its length (thick where the shape turns away from the light, thin where it faces it). Features (eyes, brows, nose, mouth) are strokes and small shapes drawn on top.
The look is the comic-book cel manner of Viewtiful Joe (bold varying ink, flat colour, hard shade shapes, angular design), not a copy of any of its art.

    python3 tools/art/portrait_ink.py joe        ->  a proof sheet in the scratch folder
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

W, H = 94, 117
UP = 3
INK = (16, 10, 24)
LIGHT = np.array([-0.62, -0.78])


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def palette(hexcol):
    """A flat colour's family: the base, a hard SHADE (darker, pushed toward plum), a LIGHT, and a hot highlight."""
    b = hexrgb(hexcol)
    return dict(m=b, d=mix(tuple(int(v * 0.64) for v in b), (74, 28, 70), 0.28), l=mix(b, (255, 242, 214), 0.26), ll=mix(b, (255, 255, 255), 0.62),
                dd=mix(tuple(int(v * 0.36) for v in b), INK, 0.5))


# ---------------------------------------------------------------------------------------------------------------------------------------------
# geometry
# ---------------------------------------------------------------------------------------------------------------------------------------------
def spline(pts, closed=True, n=10):
    """Catmull-Rom through the points -> a dense polyline."""
    P = list(pts)
    if closed:
        P = [P[-1]] + P + [P[0], P[1]]
    else:
        P = [P[0]] + P + [P[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = (np.array(P[i + k], dtype=float) for k in (-1, 0, 1, 2))
        for s in range(n):
            t = s / float(n)
            out.append(tuple(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)))
    if not closed:
        out.append(tuple(P[-2]))
    return out


def mask_of(poly):
    im = Image.new('L', (W, H), 0)
    ImageDraw.Draw(im).polygon([(x, y) for x, y in poly], fill=255)
    return np.array(im) > 0


def centroid(poly):
    a = np.array(poly)
    return a.mean(axis=0)


class Art:
    def __init__(self):
        self.rgb = np.zeros((H, W, 3), dtype=np.uint8)
        self.alpha = np.zeros((H, W), dtype=bool)

    def put(self, mask, col):
        self.rgb[mask] = col
        self.alpha |= mask

    def dot(self, x, y, col, r=0.6):
        ys, xs = np.mgrid[0:H, 0:W]
        m = (xs + 0.5 - x) ** 2 + (ys + 0.5 - y) ** 2 <= r * r
        self.put(m, col)

    def stroke(self, pts, w0, w1, col, onto=None):
        """A brush stroke along `pts` whose width goes from w0 to w1 (a tapering ink line)."""
        pts = [tuple(p) for p in pts]
        ys, xs = np.mgrid[0:H, 0:W]
        total = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:])) or 1.0
        acc = 0.0
        m = np.zeros((H, W), dtype=bool)
        for a, b in zip(pts, pts[1:]):
            seg = math.hypot(b[0] - a[0], b[1] - a[1])
            steps = max(2, int(seg * 3))
            for s in range(steps + 1):
                t = s / float(steps)
                x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                w = w0 + (w1 - w0) * ((acc + seg * t) / total)
                m |= (xs + 0.5 - x) ** 2 + (ys + 0.5 - y) ** 2 <= (w * 0.5) ** 2
            acc += seg
        if onto is not None:
            m &= onto
        self.put(m, col)
        return m

    def shape(self, poly, tones, shade=0.46, lit_edge=True, ink=1.5, ink_w=None, flat=None, shades=(), lights=()):
        """A drawn shape: flat base, ONE hard shade shape on the side away from the light, a thin lit edge on the side toward it, an ink line round it whose weight follows the turn."""
        poly = [tuple(p) for p in poly]
        m = mask_of(poly)
        ys, xs = np.mgrid[0:H, 0:W]
        c = centroid(poly)
        ext = max(1.0, np.sqrt(((np.array(poly) - c) ** 2).sum(axis=1)).max())
        proj = ((xs + 0.5 - c[0]) * -LIGHT[0] + (ys + 0.5 - c[1]) * -LIGHT[1]) / ext          # + on the side AWAY from the light
        col = np.zeros((H, W, 3), dtype=np.uint8)
        col[:] = tones['m'] if flat is None else flat
        if shade is not None:
            col[proj > (1.0 - 2.0 * shade) * 0.9] = tones['d']
        if lit_edge:
            col[(proj < -0.74)] = tones['l']
        self.rgb[m] = col[m]
        self.alpha |= m
        for sp in shades:                                    # DRAWN shade shapes: a crescent, an underside — designed, not computed
            sm = mask_of(sp) & m
            self.rgb[sm] = tones['d']
        for lp in lights:
            lm = mask_of(lp) & m
            self.rgb[lm] = tones['l']
        if ink:
            self.outline(poly, ink)
        return m

    def outline(self, poly, w):
        """Ink round a closed path; the weight swells where the edge faces away from the light."""
        pts = np.array(poly)
        n = len(pts)
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            tvec = b - a
            L = np.hypot(*tvec) or 1.0
            nrm = np.array([tvec[1], -tvec[0]]) / L                                            # a normal (pointing outward for a clockwise path)
            away = float(np.dot(nrm, -LIGHT))
            wt = w * (0.75 + 0.55 * max(0.0, away))
            self.stroke([a, b], wt, wt, INK)

    def image(self, ink_outer=1.6):
        im = np.zeros((H, W, 4), dtype=np.uint8)
        im[..., :3] = self.rgb
        im[..., 3] = np.where(self.alpha, 255, 0)
        a = self.alpha
        cur = a.copy()
        ring = np.zeros_like(a)
        for _ in range(2):
            edge = np.zeros_like(a)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                edge |= (~cur) & np.roll(np.roll(cur, dy, 0), dx, 1)
            edge[0, :] = edge[-1, :] = False
            edge[:, 0] = edge[:, -1] = False
            ring |= edge
            cur = cur | edge
        im[ring, :3] = INK
        im[ring, 3] = 255
        return Image.fromarray(im, 'RGBA')


# ---------------------------------------------------------------------------------------------------------------------------------------------
# JOE
# ---------------------------------------------------------------------------------------------------------------------------------------------
def joe(stage=1):
    art = Art()
    skin = palette('f0d4bc')
    hair = palette('6a4a32')
    coat = palette('4f8f8a')
    tee = palette('b8bcc0')
    # --- the jumper and the body: a wide soft shape, shoulders sloping, a ribbed collar
    body = spline([(2, 117), (4, 100), (14, 90), (30, 84), (40, 82), (56, 83), (70, 86), (84, 94), (92, 106), (94, 117)], closed=True, n=8)
    art.shape(body, coat, shade=None, lit_edge=False, ink=1.6, shades=[[(60, 84), (76, 88), (92, 106), (94, 117), (58, 117), (68, 102)]], lights=[[(8, 98), (16, 91), (28, 86), (22, 94)]])
    # the tee inside the collar
    art.shape(spline([(36, 80), (44, 92), (52, 93), (60, 82), (52, 78)], closed=True, n=6), tee, shade=0.45, ink=1.2)
    # a fold of the knit
    art.stroke([(20, 104), (30, 110), (34, 117)], 1.6, 0.8, coat['d'])
    art.stroke([(70, 100), (66, 108), (68, 117)], 1.6, 0.8, coat['d'])
    # the ribbed collar: two curved bands
    art.stroke(spline([(33, 80), (38, 91), (47, 95), (57, 91), (62, 80)], closed=False, n=8), 3.0, 3.0, coat['d'])
    art.stroke(spline([(33, 80), (38, 91), (47, 95), (57, 91), (62, 80)], closed=False, n=8), 1.2, 1.2, INK)
    # --- the neck
    neck = [(39, 70), (56, 70), (58, 86), (47, 90), (38, 85)]
    art.shape(neck, skin, shade=None, lit_edge=False, ink=1.2, shades=[[(39, 70), (56, 70), (57, 80), (46, 78), (38, 74)], [(52, 70), (56, 70), (58, 86), (52, 88)]])
    # --- the ear (near side) behind the head
    art.shape(spline([(30, 40), (26, 44), (27, 51), (32, 53)], closed=True, n=6), skin, shade=None, lit_edge=False, ink=1.1, shades=[[(26, 47), (28, 52), (32, 53), (30, 47)]])
    # --- the head: a rounded cranium and an ANGULAR jaw
    head = spline([(31, 33), (35, 21), (45, 15), (57, 17), (64, 26), (66, 38)], closed=False, n=8)
    head += [(65, 50), (60, 60), (50, 70), (43, 68), (36, 61), (30, 50)]
    art.shape(head, skin, shade=None, lit_edge=False, ink=1.6, shades=[[(60, 24), (66, 38), (65, 50), (60, 60), (50, 70), (55, 60), (60, 49), (60, 37)], [(36, 62), (46, 69), (58, 62), (52, 65), (44, 64)]], lights=[[(37, 24), (45, 18), (52, 19), (44, 23)]])
    # a shade shape cut under the jaw
    art.stroke(spline([(37, 62), (46, 68), (58, 61)], closed=False, n=6), 2.2, 2.2, skin['d'])
    # --- the eyes: an angular almond, a heavy black upper lid, a big iris and a catch-light
    iris = hexrgb('5a7a96')
    for (cx, cy, wd, ht, ix) in ((39.0, 43.0, 12.0, 3.6, 41.5), (56.0, 43.6, 9.5, 3.4, 57.5)):
        outer_left = cx < 47
        pts = [(cx - wd / 2, cy + 0.2), (cx - wd * 0.22, cy - ht), (cx + wd * 0.25, cy - ht * 1.05), (cx + wd / 2, cy + 0.4), (cx + wd * 0.1, cy + ht * 0.8), (cx - wd * 0.2, cy + ht * 0.7)]
        m = mask_of(pts)
        art.put(m, (246, 244, 238))
        art.put(m & ((np.mgrid[0:H, 0:W][1] + 0.5 - ix) ** 2 + (np.mgrid[0:H, 0:W][0] + 0.5 - (cy + 0.4)) ** 2 <= 3.1 ** 2), iris)
        art.put(m & ((np.mgrid[0:H, 0:W][1] + 0.5 - ix) ** 2 + (np.mgrid[0:H, 0:W][0] + 0.5 - (cy + 0.4)) ** 2 <= 1.5 ** 2), (14, 8, 18))
        art.dot(ix - 1.0, cy - 0.8, (255, 255, 255), 0.7)
        top = [(cx - wd / 2 - 0.5, cy + 0.6), (cx - wd * 0.22, cy - ht - 0.3), (cx + wd * 0.25, cy - ht * 1.05 - 0.3), (cx + wd / 2 + 0.6, cy + 0.2)]
        art.stroke(spline(top, closed=False, n=8), 1.2, 2.4, INK) if outer_left else art.stroke(spline(top[::-1], closed=False, n=8), 1.2, 2.4, INK)
        art.stroke([(cx - wd * 0.2, cy + ht * 0.8), (cx + wd * 0.1, cy + ht * 0.9)], 0.9, 0.9, skin['d'])
    # --- the brows: heavy angled strokes
    art.stroke([(46.5, 37.4), (40.0, 34.4), (32.5, 36.2)], 3.0, 1.4, INK)
    art.stroke([(50.5, 37.6), (56.5, 34.8), (63.0, 36.6)], 3.0, 1.4, INK)
    # --- the nose: a hooked ink line and a shade plane
    nose_shade = mask_of([(51.5, 44), (55.5, 49), (55.5, 54), (52, 53)])
    art.put(nose_shade, skin['d'])
    art.stroke(spline([(50.0, 41.5), (51.0, 47.0), (52.0, 52.0), (55.2, 54.4)], closed=False, n=6), 1.4, 1.0, INK)
    art.dot(53.6, 54.4, INK, 0.7)
    # --- the mouth: a short ink line with a hard lower lip
    art.stroke(spline([(45.5, 61.4), (51.0, 62.8), (58.0, 60.4)], closed=False, n=6), 1.8, 1.2, INK)
    art.stroke(spline([(47.0, 63.8), (52.0, 65.2), (56.5, 62.6)], closed=False, n=6), 1.8, 1.0, hexrgb('b87068'))
    # stubble
    rng = np.random.RandomState(4)
    jaw_m = mask_of(head) & (np.mgrid[0:H, 0:W][0] > 57)
    ys, xs = np.nonzero(jaw_m)
    for i in rng.choice(len(ys), size=min(60, len(ys)), replace=False):
        art.rgb[ys[i], xs[i]] = skin['d']
    # --- the hair: a dark mop of spiky locks sweeping to the right, each its own shape so each has its own ink
    cap = [(29, 36), (30, 24), (37, 15), (47, 12), (58, 14), (65, 22), (67, 32), (60, 27), (52, 31), (44, 26), (36, 32)]
    art.shape(cap, hair, shade=0.40, ink=1.5)
    for sp in (((33, 22), (22, 7), (41, 16)), ((42, 15), (37, 0), (53, 13)), ((52, 13), (62, 0), (64, 17)), ((60, 15), (77, 8), (68, 27)),
               ((64, 24), (84, 27), (66, 37)), ((29, 28), (18, 36), (29, 47))):
        art.shape(list(sp), hair, shade=0.42, ink=1.4)
    art.shape([(31, 30), (43, 19), (68, 26), (52, 33), (41, 29)], hair, shade=0.44, ink=1.4)
    art.stroke([(40, 24), (48, 20), (58, 22)], 1.4, 0.6, hair['ll'])                    # a shine on the fringe
    return art


def eyes_nose_mouth(art, skin, stage=1):
    pass


if __name__ == '__main__':
    who = sys.argv[1] if len(sys.argv) > 1 else 'joe'
    img = globals()[who](1).image().resize((W * UP, H * UP), Image.NEAREST)
    out = sys.argv[2] if len(sys.argv) > 2 else '/tmp/portrait_proof.png'
    bg = Image.new('RGBA', img.size, (58, 58, 68, 255))
    bg.alpha_composite(img)
    bg.save(out)
    print('wrote', out)
