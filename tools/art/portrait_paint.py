#!/usr/bin/env python3
"""HUD PORTRAITS — a painted illustration pipeline (third start; the owner's references: Hades' bold coloured contour and rim light, the RPG head-and-shoulder bust sets, the clean
round cartoon turnaround, the Smash roster's polished shapes).

Everything is drawn at 4x (1124 x 1404) with real antialiasing and brought down to 281 x 351, so lines and curves are smooth and the face has room for real anatomy:
a CONSTRUCTION (cranium, jaw, eye line, nose, mouth) places every feature, then layers are painted over it — flat base colour, a soft-edged cel shadow shape, a warm light,
a rim light on the edge away from the shadow, an ink contour of VARYING weight in a dark colour (not black), and the small details (lids, lashes, iris, lips, knit).

    python3 tools/art/portrait_paint.py joe /path/out.png
"""
import math
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

FW, FH = 281, 351
S = 4
W, H = FW * S, FH * S
LIGHT = np.array([-0.6, -0.8])


def hexrgb(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def mix(a, b, t):
    return np.array(a, dtype=np.float32) * (1 - t) + np.array(b, dtype=np.float32) * t


def spline(pts, closed=True, n=16, tension=0.5):
    P = [tuple(map(float, p)) for p in pts]
    if closed:
        P = [P[-1]] + P + [P[0], P[1]]
    else:
        P = [P[0]] + P + [P[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = (np.array(P[i + k]) for k in (-1, 0, 1, 2))
        m1, m2 = (p2 - p0) * tension, (p3 - p1) * tension
        for s in range(n):
            t = s / float(n)
            h00, h10, h01, h11 = 2 * t ** 3 - 3 * t ** 2 + 1, t ** 3 - 2 * t ** 2 + t, -2 * t ** 3 + 3 * t ** 2, t ** 3 - t ** 2
            out.append(tuple(h00 * p1 + h10 * m1 + h01 * p2 + h11 * m2))
    if not closed:
        out.append(P[-2])
    return out


def sc(pts):
    return [(x * S, y * S) for x, y in pts]


class Painter:
    def __init__(self):
        self.img = np.zeros((H, W, 4), dtype=np.float32)          # premultiplied-free RGBA, 0..255 colour, 0..1 alpha in channel 3

    # ---- masks
    def poly_mask(self, pts):
        im = Image.new('L', (W, H), 0)
        ImageDraw.Draw(im).polygon(sc(pts), fill=255)
        return np.array(im).astype(np.float32) / 255.0

    def line_mask(self, pts, w0, w1=None):
        """A tapering stroke as a mask: width w0 at the start to w1 at the end (final px)."""
        w1 = w0 if w1 is None else w1
        im = Image.new('L', (W, H), 0)
        d = ImageDraw.Draw(im)
        pts = [(x * S, y * S) for x, y in pts]
        total = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:])) or 1.0
        acc = 0.0
        for a, b in zip(pts, pts[1:]):
            seg = math.hypot(b[0] - a[0], b[1] - a[1])
            steps = max(2, int(seg / 1.5))
            for k in range(steps + 1):
                t = k / float(steps)
                x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                r = (w0 + (w1 - w0) * ((acc + seg * t) / total)) * S * 0.5
                d.ellipse([x - r, y - r, x + r, y + r], fill=255)
            acc += seg
        return np.array(im).astype(np.float32) / 255.0

    # ---- compositing
    def paint(self, mask, col, alpha=1.0):
        a = (mask * alpha)[..., None]
        col = np.array(col, dtype=np.float32)
        base_a = self.img[..., 3:4]
        out_a = a + base_a * (1 - a)
        rgb = (col * a + self.img[..., :3] * base_a * (1 - a)) / np.maximum(out_a, 1e-6)
        self.img[..., :3] = rgb
        self.img[..., 3:4] = out_a

    def paint_grad(self, mask, c0, c1, p0, p1, alpha=1.0):
        """A linear gradient from colour c0 at p0 to c1 at p1 (final-px coords), inside the mask."""
        ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
        p0 = np.array(p0, dtype=np.float32) * S
        p1 = np.array(p1, dtype=np.float32) * S
        d = p1 - p0
        t = np.clip(((xs - p0[0]) * d[0] + (ys - p0[1]) * d[1]) / (d @ d), 0, 1)[..., None]
        col = np.array(c0, dtype=np.float32) * (1 - t) + np.array(c1, dtype=np.float32) * t
        a = (mask * alpha)[..., None]
        base_a = self.img[..., 3:4]
        out_a = a + base_a * (1 - a)
        self.img[..., :3] = (col * a + self.img[..., :3] * base_a * (1 - a)) / np.maximum(out_a, 1e-6)
        self.img[..., 3:4] = out_a

    def soft(self, mask, px):
        return ndimage.gaussian_filter(mask, px * S)

    def ink(self, pts, w_min, w_max, col, closed=True, light_aware=True):
        """The contour: a line of VARYING weight — heavier where the edge turns away from the light."""
        pts = list(pts)
        n = len(pts)
        im = Image.new('L', (W, H), 0)
        d = ImageDraw.Draw(im)
        rng = range(n) if closed else range(n - 1)
        for i in rng:
            a, b = np.array(pts[i]), np.array(pts[(i + 1) % n])
            tvec = b - a
            L = np.hypot(*tvec) or 1.0
            nrm = np.array([tvec[1], -tvec[0]]) / L
            away = float(np.dot(nrm, -LIGHT)) if light_aware else 0.0
            wgt = (w_min + (w_max - w_min) * max(0.0, min(1.0, 0.5 + 0.5 * away))) * S * 0.5
            steps = max(2, int(L * S / 1.5))
            for k in range(steps + 1):
                t = k / float(steps)
                x, y = (a[0] + tvec[0] * t) * S, (a[1] + tvec[1] * t) * S
                d.ellipse([x - wgt, y - wgt, x + wgt, y + wgt], fill=255)
        m = np.array(im).astype(np.float32) / 255.0
        self.paint(m, col)
        return m

    def result(self):
        out = np.clip(self.img, 0, 255)
        rgb = out[..., :3].astype(np.uint8)
        alpha = (np.clip(out[..., 3], 0, 1) * 255).astype(np.uint8)
        im = Image.fromarray(np.dstack([rgb, alpha]), 'RGBA')
        return im.resize((FW, FH), Image.LANCZOS)


# ---------------------------------------------------------------------------------------------------------------------------------------------
INK = np.array([34, 18, 30], dtype=np.float32)          # a dark plum-brown, not black (the Hades contour)


def lit_shade(base, shade_amt=0.30, warm=(255, 232, 196), cool=(92, 44, 86)):
    b = hexrgb(base) if isinstance(base, str) else np.array(base, dtype=np.float32)
    return dict(base=b, shade=mix(b * (1 - shade_amt), cool, 0.30), light=mix(b, warm, 0.30), hot=mix(b, (255, 255, 255), 0.55))


def region(pts, painter, tones, shades=(), lights=(), rim=None, ink=(1.6, 3.2), shade_soft=1.2, light_soft=1.6, grad=None):
    """Paint one drawn shape: base (optionally a gentle gradient), designed shade shapes with a soft edge, designed light shapes, a rim, and the ink contour."""
    m = painter.poly_mask(pts)
    if grad is not None:
        painter.paint_grad(m, tones['light'], tones['shade'], *grad, alpha=1.0)
        painter.paint(m, tones['base'], 0.55)
    else:
        painter.paint(m, tones['base'])
    for sp in shades:
        sm = painter.soft(painter.poly_mask(sp), shade_soft) * m
        painter.paint(sm, tones['shade'], 0.92)
    for lp in lights:
        lm = painter.soft(painter.poly_mask(lp), light_soft) * m
        painter.paint(lm, tones['light'], 0.85)
    if rim is not None:
        rm = painter.soft(painter.poly_mask(rim), 0.8) * m
        painter.paint(rm, tones['hot'], 0.7)
    if ink:
        painter.ink(pts, ink[0], ink[1], INK)
    return m


# ---------------------------------------------------------------------------------------------------------------------------------------------
# eyes
# ---------------------------------------------------------------------------------------------------------------------------------------------
def eye(p, cx, cy, wd, ht, inner_left, iris_col, look=(0.0, 0.0), lid=0.0, tilt=0.0, lash=False, droop=0.0, skin=None):
    """One eye drawn properly: the almond (upper lid arching to a peak, lower lid a shallow curve), shaded white, an iris with a ring and a lighter lower half, a pupil, two specular
    highlights, the heavy upper-lid ink with a crease above it, a thin lower lid line."""
    sgn = 1.0 if inner_left else -1.0
    inner = (cx + sgn * wd / 2, cy + tilt * 0.4)
    outer = (cx - sgn * wd / 2, cy - tilt)
    top_peak = (cx - sgn * wd * 0.08, cy - ht * 1.05 + droop)
    top_mid1 = (cx + sgn * wd * 0.22, cy - ht * 0.72 + droop * 0.8)
    top_mid2 = (cx - sgn * wd * 0.30, cy - ht * 0.88 + droop * 0.8 - tilt * 0.5)
    bot = [(inner[0], inner[1] + 0.5), (cx + sgn * wd * 0.1, cy + ht * 0.78), (cx - sgn * wd * 0.25, cy + ht * 0.72 - tilt * 0.4), (outer[0], outer[1] + 0.6)]
    upper = spline([inner, top_mid1, top_peak, top_mid2, outer], closed=False, n=14)
    lower = spline(bot, closed=False, n=14)
    shape = upper + lower[::-1]
    m = p.poly_mask(shape)
    p.paint(m, (248, 244, 240))
    p.paint(p.soft(p.poly_mask(upper[:len(upper)] + [(x, y - 12) for x, y in upper[::-1]]), 1.0) * m, (190, 176, 190), 0.5)       # the lid's shadow on the white
    ix, iy = cx + look[0], cy + look[1] + droop * 0.3
    r = ht * 1.05
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    ring = ((xs - ix * S) ** 2 + (ys - iy * S) ** 2) <= (r * S) ** 2
    ringm = ring.astype(np.float32) * m
    p.paint(ringm, iris_col * 0.55)
    inner_iris = (((xs - ix * S) ** 2 + (ys - iy * S) ** 2) <= ((r * 0.82) * S) ** 2).astype(np.float32) * m
    p.paint_grad(inner_iris, iris_col * 0.8, mix(iris_col, (230, 240, 255), 0.45), (ix, iy - r), (ix, iy + r))
    pupil = (((xs - ix * S) ** 2 + (ys - iy * S) ** 2) <= ((r * 0.42) * S) ** 2).astype(np.float32) * m
    p.paint(pupil, (14, 8, 18))
    for (dx, dy, rr) in ((-r * 0.36, -r * 0.40, r * 0.26), (r * 0.30, r * 0.34, r * 0.12)):
        hl = (((xs - (ix + dx) * S) ** 2 + (ys - (iy + dy) * S) ** 2) <= (rr * S) ** 2).astype(np.float32) * m
        p.paint(hl, (255, 255, 255))
    # the lid: heavy ink, thick toward the outer corner
    p.paint(p.line_mask(upper, 1.3, 3.0 if inner_left else 3.0), INK) if False else None
    p.paint(p.line_mask(upper if inner_left else upper, 3.4, 1.4) if inner_left else p.line_mask(upper, 3.4, 1.4), INK)
    if lash:
        ox, oy = outer
        p.paint(p.line_mask([(ox, oy - 0.5), (ox - sgn * 3.5, oy - 3.0)], 2.2, 0.6), INK)
        p.paint(p.line_mask([(ox + sgn * 2.0, oy - ht * 0.6), (ox - sgn * 1.5, oy - ht * 0.6 - 3.0)], 1.8, 0.5), INK)
    crease = spline([(inner[0] - sgn * 1.0, inner[1] - ht * 1.35), (cx + sgn * 0.1 * wd, cy - ht * 1.9 + droop), (outer[0] + sgn * 0.5, outer[1] - ht * 1.2)], closed=False, n=10)
    p.paint(p.line_mask(crease, 1.0, 0.5), skin['shade'] if skin else INK, 0.85)
    p.paint(p.line_mask(lower, 1.0, 0.7), skin['shade'] if skin else INK, 0.9)


# ---------------------------------------------------------------------------------------------------------------------------------------------
# JOE
# ---------------------------------------------------------------------------------------------------------------------------------------------
def joe(stage=1):
    p = Painter()
    skin = lit_shade('#eebf9c', 0.26)
    hair = lit_shade('#5b3d29', 0.42, warm=(214, 160, 96))
    coat = lit_shade('#3f8c88', 0.30, warm=(170, 236, 220))
    tee = lit_shade('#b9bec6', 0.25)
    # ------------------------------------------------------------------ the jumper and the shoulders: broad, relaxed, a knit with soft folds
    body = spline([(-6, 352), (0, 318), (22, 292), (62, 268), (104, 254), (166, 252), (206, 262), (246, 284), (272, 312), (290, 352)], closed=True, n=14)
    region(body, p, coat, shades=[[(180, 262), (236, 278), (276, 316), (290, 352), (150, 352), (186, 300)]], lights=[[(10, 318), (30, 292), (62, 272), (50, 300)]],
           rim=[(-6, 330), (6, 300), (26, 288), (14, 318)], ink=(2.0, 4.0), grad=((20, 280), (260, 352)))
    # the knit: a few soft fold shapes
    for pts, w in (([(52, 330), (82, 318), (112, 350)], 5.0), ([(214, 316), (194, 330), (200, 352)], 5.0), ([(150, 300), (140, 326), (152, 352)], 4.0)):
        p.paint(p.soft(p.line_mask(spline(pts, closed=False, n=10), w, w * 0.4), 1.2), coat['shade'], 0.8)
    # the tee at the neck
    tee_poly = spline([(100, 244), (118, 280), (146, 292), (176, 278), (190, 246), (150, 240)], closed=True, n=10)
    region(tee_poly, p, tee, shades=[[(150, 250), (190, 246), (176, 278), (150, 286)]], ink=(1.4, 2.6))
    # the ribbed collar
    collar_o = spline([(88, 244), (104, 282), (146, 300), (190, 282), (204, 244)], closed=False, n=12)
    collar_i = spline([(104, 244), (116, 274), (146, 288), (180, 274), (192, 244)], closed=False, n=12)
    band = collar_o + collar_i[::-1]
    region(band, p, coat, shades=[[(150, 270), (204, 244), (190, 284), (150, 300)]], ink=(1.6, 3.0))
    for k in range(9):                                                                           # the rib: short strokes across the band
        t = (k + 0.5) / 9.0
        i0 = int(t * (len(collar_o) - 1))
        a, b = collar_o[i0], collar_i[i0]
        p.paint(p.line_mask([a, b], 1.2, 1.0), coat['shade'], 0.7)
    # ------------------------------------------------------------------ the neck
    neck = spline([(106, 180), (190, 176), (194, 250), (150, 272), (102, 248)], closed=True, n=12)
    region(neck, p, skin, shades=[[(150, 176), (194, 176), (196, 252), (160, 266)], [(106, 180), (190, 176), (188, 214), (150, 222), (110, 206)]],
           ink=(1.6, 3.2))
    # ------------------------------------------------------------------ the ear (near side)
    ear = spline([(74, 140), (58, 132), (52, 152), (60, 178), (80, 184)], closed=True, n=10)
    region(ear, p, skin, shades=[[(58, 156), (62, 180), (80, 184), (72, 160)]], ink=(1.4, 2.6))
    p.paint(p.line_mask(spline([(66, 146), (60, 156), (66, 170)], closed=False, n=8), 1.6, 1.0), skin['shade'], 0.9)
    # ------------------------------------------------------------------ the head: a strong cranium, a clear jaw, a chin with some squareness
    head_pts = spline([(72, 104), (84, 52), (126, 28), (176, 34), (212, 66), (222, 112)], closed=False, n=14)
    head_pts += spline([(222, 112), (220, 160), (208, 200), (184, 232), (152, 250), (126, 244), (100, 222), (82, 190), (72, 150)], closed=False, n=12)[1:]
    # the far side of the face in shade: a crescent; the under-jaw shadow; a warm light across the brow and cheekbone
    region(head_pts, p, skin,
           shades=[[(208, 70), (224, 108), (222, 160), (208, 202), (184, 234), (152, 252), (182, 222), (200, 190), (208, 150), (208, 104)],
                   [(104, 224), (150, 252), (196, 232), (168, 238), (136, 234)]],
           lights=[[(96, 70), (130, 50), (166, 52), (128, 72)], [(98, 168), (124, 160), (128, 190), (104, 196)]],
           ink=(2.4, 4.6))
    hair_shadow = p.soft(p.poly_mask([(76, 100), (216, 100), (216, 124), (76, 124)]), 3.0)                 # the brow's shadow where the fringe falls
    p.paint(hair_shadow * p.poly_mask(head_pts), skin['shade'], 0.35)
    # the cheek warmth
    p.paint(p.soft(p.poly_mask(spline([(96, 184), (118, 172), (136, 190), (118, 204)], closed=True, n=8)), 6.0) * p.poly_mask(head_pts), (232, 140, 120), 0.22)
    # ------------------------------------------------------------------ the eyes (3/4 view: the far eye narrower)
    iris_c = hexrgb('#5a7f9c')
    eye(p, 106.0, 146.0, 46.0, 12.0, True, iris_c, look=(3.0, 0.5), droop=0.0 if stage < 3 else 1.5, skin=skin)
    eye(p, 176.0, 148.0, 36.0, 11.0, False, iris_c, look=(2.5, 0.5), droop=0.0 if stage < 3 else 1.5, skin=skin)
    # ------------------------------------------------------------------ the brows: filled, tapered, heavy, a little furrowed
    for pts, w in (([(74, 124), (98, 112), (126, 114), (136, 124)], 11.0), ([(158, 124), (172, 112), (196, 110), (212, 118)], 9.0)):
        top = spline(pts, closed=False, n=10)
        bot = [(x, y + w * (0.6 - 0.5 * i / len(top))) for i, (x, y) in enumerate(top)]
        p.paint(p.poly_mask(top + bot[::-1]), hair['shade'] * 0.7 + INK * 0.3)
        p.paint(p.line_mask(top, 2.0, 1.0), INK, 0.7)
    # ------------------------------------------------------------------ the nose: a shade plane on the far side, a lit ridge, a small tip, the underside and one nostril
    p.paint(p.soft(p.poly_mask([(150, 146), (174, 150), (184, 194), (172, 208), (152, 204)]), 3.2), skin['shade'], 0.5)
    p.paint(p.soft(p.line_mask([(150, 148), (152, 182), (158, 198)], 6.0, 3.5), 1.4), skin['light'], 0.9)
    p.paint(p.line_mask(spline([(176, 194), (182, 202), (174, 208)], closed=False, n=8), 2.2, 1.4), INK, 0.8)             # the wing of the nostril
    p.paint(p.line_mask(spline([(152, 206), (162, 211), (176, 206)], closed=False, n=8), 2.8, 1.6), INK, 0.95)            # the underside of the nose
    p.paint(p.poly_mask(spline([(163, 204), (170, 203), (171, 209), (164, 209)], closed=True, n=6)), (60, 28, 44), 0.9)
    # ------------------------------------------------------------------ the mouth, a third of the way from the nose to the chin
    lip_col = hexrgb('#b8705f')
    upper_lip = spline([(130, 226), (146, 219), (160, 222), (178, 216), (192, 222), (170, 230), (148, 231)], closed=True, n=8)
    p.paint(p.poly_mask(upper_lip), lip_col * 0.78)
    lower_lip = spline([(136, 232), (160, 234), (188, 224), (182, 238), (160, 243), (144, 239)], closed=True, n=8)
    p.paint(p.poly_mask(lower_lip), lip_col)
    p.paint(p.soft(p.poly_mask([(146, 236), (168, 237), (164, 241), (148, 240)]), 1.0), (240, 190, 170), 0.8)
    mouth_line = spline([(126, 228), (146, 232), (168, 231), (192, 221)], closed=False, n=8)
    p.paint(p.line_mask(mouth_line, 3.6, 1.8), INK, 1.0)
    p.paint(p.line_mask([(192, 221), (198, 216)], 2.0, 1.0), INK, 0.8)
    p.paint(p.soft(p.poly_mask([(142, 244), (176, 242), (170, 250), (146, 250)]), 2.0), skin['shade'], 0.55)                   # the shadow under the lip
    p.paint(p.soft(p.line_mask([(152, 206), (154, 218)], 5.0, 3.5), 1.4), skin['shade'], 0.45)                                # the philtrum
    # stubble: a soft speckle over the jaw
    rng = np.random.RandomState(3)
    sm = p.poly_mask(head_pts) * p.poly_mask([(86, 214), (206, 214), (190, 262), (104, 262)])
    ys, xs = np.nonzero(sm > 0.5)
    sel = rng.choice(len(ys), size=min(900, len(ys)), replace=False)
    dots = np.zeros((H, W), dtype=np.float32)
    dots[ys[sel], xs[sel]] = 1.0
    dots = ndimage.maximum_filter(dots, size=3)
    p.paint(dots * sm * (1.0 - p.poly_mask(upper_lip + lower_lip)), skin['shade'] * 0.55 + INK * 0.2, 0.5)
    # ------------------------------------------------------------------ the hair: a swept mop, layered, with a pointed silhouette — drawn over the head
    def lock(pts, w_root, tones, taper=0.8):
        top = spline(pts, closed=False, n=14)
        n = len(top)
        left, right = [], []
        for i, (x, y) in enumerate(top):
            j0, j1 = max(0, i - 1), min(n - 1, i + 1)
            tx, ty = top[j1][0] - top[j0][0], top[j1][1] - top[j0][1]
            L = math.hypot(tx, ty) or 1.0
            nx, ny = -ty / L, tx / L
            t = i / float(n - 1)
            wgt = w_root * 0.5 * (math.sin(math.pi * min(1.0, t * 0.7 + 0.18)) ** 0.6) * (1.0 - t) ** taper
            left.append((x + nx * wgt, y + ny * wgt))
            right.append((x - nx * wgt, y - ny * wgt))
        poly = left + right[::-1]
        m = p.poly_mask(poly)
        p.paint_grad(m, tones['light'], tones['shade'], (pts[0][0] - 10, pts[0][1] - 30), (pts[-1][0] + 10, pts[-1][1] + 30), 1.0)
        p.paint(m, tones['base'], 0.55)
        mid = p.line_mask(top[int(n * 0.1): int(n * 0.75)], max(2.0, w_root * 0.16), 0.6)
        p.paint(p.soft(mid, 0.7) * m, tones['hot'] * 0.7 + tones['light'] * 0.3, 0.6)
        p.ink(poly, 1.3, 3.2, INK)
    cap = spline([(64, 130), (58, 84), (88, 40), (140, 22), (196, 30), (232, 68), (234, 118), (222, 100), (196, 92), (160, 98), (120, 92), (88, 106)], closed=True, n=12)
    region(cap, p, hair, shades=[[(186, 30), (236, 72), (236, 122), (212, 104), (198, 62)], [(64, 112), (116, 100), (108, 134), (66, 142)]],
           lights=[[(94, 58), (128, 38), (164, 36), (128, 62)]], ink=(2.0, 4.2))
    for pts, w in ((((92, 98), (80, 62), (92, 28), (112, 6)), 34), (((124, 84), (126, 48), (150, 18), (178, 2)), 38), (((160, 82), (184, 52), (214, 38), (246, 36)), 34),
                   (((196, 88), (226, 72), (256, 74), (278, 92)), 28), (((74, 128), (58, 106), (54, 84), (64, 64)), 24)):
        lock(list(pts), w, hair)
    # the fringe: two long locks that SWEEP across the brow in an S and one short one, each ending in a point at the temple
    lock([(100, 94), (116, 112), (150, 112), (190, 106), (232, 122)], 40, hair, taper=0.9)
    lock([(140, 84), (170, 96), (206, 96), (246, 108), (268, 132)], 34, hair, taper=1.0)
    lock([(104, 100), (96, 122), (104, 132)], 20, hair, taper=0.9)
    lock([(80, 120), (76, 150), (80, 176)], 16, hair)
    return p


if __name__ == '__main__':
    who = sys.argv[1] if len(sys.argv) > 1 else 'joe'
    out = sys.argv[2] if len(sys.argv) > 2 else '/tmp/portrait_paint.png'
    img = globals()[who](1).result()
    bg = Image.new('RGBA', img.size, (58, 58, 68, 255))
    bg.alpha_composite(img)
    bg.save(out)
    print('wrote', out)
