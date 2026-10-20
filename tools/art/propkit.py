"""PROP KIT — shaded primitives for hand-built furniture and objects (owner round 47b: "everything very flat and very basic looking, like bad, bad mspaint… depth and detail").

The first furniture pieces were flat colour fills with an outline. These helpers give small things VOLUME the way pixel artists do it: a few tones per material (a ramp), light from the
upper left, spheres / cylinders / cones lit by their own surface normal (posterised into the ramp so it stays crisp pixel art), a rim light, a specular dash on glossy things, a
selective outline (the darkened colour of the pixel it surrounds, never plain black) and a soft contact shadow.

    L = Layer(c)               draw the thing on L.c with the primitives below, then
    L.flush()                  add the outline and lay it on the real canvas

A pixel (x, y) covers [x, x+1); centres / radii are floats in those edge coordinates, so a thing spanning pixels 3..10 has cx = 7.0, rx = 4.0.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import Canvas, hexc, shade, mix

LX, LZ = -0.62, 0.78                      # the light, from the upper left and the front (x, z of a unit vector, y handled per primitive)
LY = -0.45


def tones(col, n=5, lo=0.52, hi=1.34):
    """n tones of a colour, darkest first."""
    return [shade(col, lo + (hi - lo) * i / float(n - 1)) for i in range(n)]


def _pick(tn, lam):
    i = int(max(0.0, min(0.999, lam)) * len(tn))
    return tn[i]


class Layer:
    """A scratch canvas for one object: draw on `.c`, then `flush()` adds a selective outline and composites it onto `dst`."""

    def __init__(self, dst):
        self.dst = dst
        self.c = Canvas(w=dst.w, h=dst.h, bg=(0, 0, 0, 0), seed=11)

    def flush(self, outline=True, out_f=0.38, bottom_f=None):
        img = self.c.img
        if outline:
            px = img.load()
            w, h = img.size
            bb = img.getchannel('A').getbbox()
            if bb:
                add = []
                for y in range(max(0, bb[1] - 1), min(h, bb[3] + 1)):
                    for x in range(max(0, bb[0] - 1), min(w, bb[2] + 1)):
                        if px[x, y][3] != 0:
                            continue
                        best = None
                        for (dx, dy) in ((0, 1), (-1, 0), (1, 0), (0, -1)):
                            nx, ny = x + dx, y + dy
                            if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 255:
                                col = px[nx, ny]
                                if best is None or sum(col[:3]) < sum(best[:3]):
                                    best = col
                        if best is not None:
                            add.append((x, y, shade(best, out_f if bottom_f is None else out_f)))
                for (x, y, col) in add:
                    px[x, y] = col
        self.dst.img.alpha_composite(img)
        self.dst.px = self.dst.img.load()


def contact_shadow(c, cx, cy, rx, ry=1.6, alpha=95):
    c.shadow(cx, cy, rx, ry, alpha)


# ------------------------------------------------------------------------------------------------------------------------------------ round things
def sphere(c, cx, cy, rx, ry, col, n=5, gloss=False, lo=0.50, hi=1.34, spec=None):
    """A lit ellipsoid (a ball, a bulb, a bean) — each pixel takes the tone of its own surface normal."""
    tn = tones(col, n, lo, hi)
    for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
        for x in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            r2 = u * u + v * v
            if r2 > 1.0:
                continue
            nz = math.sqrt(1.0 - r2)
            lam = max(0.0, LX * u + LY * v + LZ * nz)
            c.put(x, y, _pick(tn, 0.12 + 0.95 * lam))
    if gloss:
        sx, sy = int(round(cx - rx * 0.38)), int(round(cy - ry * 0.45))
        c.put(sx, sy, spec or shade(col, 1.9))
        if rx >= 3:
            c.put(sx + 1, sy, spec or shade(col, 1.65))


def _col_lam(u, tilt=0.0):
    nz = math.sqrt(max(0.0, 1.0 - u * u))
    return max(0.0, LX * u + (LZ - tilt) * nz + 0.18 * tilt)


def cyl(c, cx, ytop, ybot, rx, col, ry=None, cap=True, cap_col=None, gloss=False, n=5, lo=0.50, hi=1.34, spec=None, inner=None):
    """A vertical cylinder seen a little from above: the side spans rows ytop..ybot (centres of the top / bottom ellipses), `ry` is how far the rims bow. The cap is the lit top face;
    `inner` = a colour makes the top an open mouth (a glass, a tin) with that colour as its inside."""
    ry = ry if ry is not None else max(1.0, rx * 0.38)
    tn = tones(col, n, lo, hi)
    x0, x1 = int(math.floor(cx - rx)), int(math.ceil(cx + rx)) - 1
    for x in range(x0, x1 + 1):
        u = (x + 0.5 - cx) / rx
        if abs(u) > 1.0:
            continue
        nz = math.sqrt(1.0 - u * u)
        lam = _col_lam(u)
        t = _pick(tn, 0.10 + 0.95 * lam)
        yb = ybot + ry * nz
        for y in range(int(math.floor(ytop)), int(math.floor(yb)) + 1):
            c.put(x, y, t)
        if gloss and abs(u + 0.5) < 0.2:
            for y in range(int(ytop + 1), int(ybot - 1) + 1):
                c.put(x, y, shade(col, 1.55) if spec is None else spec)
    if cap:
        cc = cap_col or shade(col, 1.22)
        _ell(c, cx, ytop, rx, ry, cc)
        if inner is not None:
            _ell(c, cx, ytop + 0.3, rx - 0.9, max(0.6, ry - 0.7), inner)
            c.put(int(round(cx - rx * 0.5)), int(round(ytop - ry * 0.3)), shade(inner, 1.25))


def _ell(c, cx, cy, rx, ry, col):
    for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
        for x in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
            u, v = (x + 0.5 - cx) / max(rx, 0.5), (y + 0.5 - cy) / max(ry, 0.5)
            if u * u + v * v <= 1.0:
                c.put(x, y, col)


def ell(c, cx, cy, rx, ry, col):
    _ell(c, cx, cy, rx, ry, col)


def frustum(c, cx, ytop, ybot, rt, rb, col, ry_t=None, ry_b=None, inner=None, rim=None, gloss=False, n=5, lo=0.50, hi=1.34, band=None, band_h=2, spec=None):
    """A cone frustum seen a little from above (a lamp shade, a glass, a bucket, a pot): radius rt at the top rim (row ytop), rb at the bottom (row ybot). `inner` opens the top (we see
    the inside), `band` = (colour, rows) paints a trim band at the bottom, `rim` a brighter lip."""
    ry_t = ry_t if ry_t is not None else max(0.8, rt * 0.34)
    ry_b = ry_b if ry_b is not None else max(0.8, rb * 0.34)
    tn = tones(col, n, lo, hi)
    span = max(1, ybot - ytop)
    for y in range(int(ytop), int(ybot) + 1):
        f = (y - ytop) / float(span)
        r = rt + (rb - rt) * f
        for x in range(int(math.floor(cx - r)), int(math.ceil(cx + r))):
            u = (x + 0.5 - cx) / r
            if abs(u) > 1.0:
                continue
            c.put(x, y, _pick(tn, 0.10 + 0.95 * _col_lam(u)))
    # the front lip of the bottom edge bows down
    for x in range(int(math.floor(cx - rb)), int(math.ceil(cx + rb))):
        u = (x + 0.5 - cx) / rb
        if abs(u) > 1.0:
            continue
        nz = math.sqrt(1.0 - u * u)
        t = _pick(tn, 0.10 + 0.95 * _col_lam(u))
        for y in range(int(ybot) + 1, int(ybot + ry_b * nz) + 1):
            c.put(x, y, t)
    if band is not None:
        bc, bh = band
        btn = tones(bc, n, lo, hi)
        for y in range(int(ybot) - bh + 1, int(ybot) + 1):
            f = (y - ytop) / float(span)
            r = rt + (rb - rt) * f
            for x in range(int(math.floor(cx - r)), int(math.ceil(cx + r))):
                u = (x + 0.5 - cx) / r
                if abs(u) <= 1.0:
                    c.put(x, y, _pick(btn, 0.10 + 0.95 * _col_lam(u)))
        for x in range(int(math.floor(cx - rb)), int(math.ceil(cx + rb))):
            u = (x + 0.5 - cx) / rb
            if abs(u) <= 1.0:
                nz = math.sqrt(1.0 - u * u)
                for y in range(int(ybot) + 1, int(ybot + ry_b * nz) + 1):
                    c.put(x, y, _pick(btn, 0.10 + 0.95 * _col_lam(u)))
    if gloss:
        sx = int(round(cx - r_at(rt, rb, 0.5) * 0.5))
        for y in range(int(ytop) + 1, int(ybot)):
            c.put(sx, y, shade(col, 1.5) if spec is None else spec)
    _ell(c, cx, ytop, rt, ry_t, rim or shade(col, 1.25))
    if inner is not None:
        _ell(c, cx, ytop + 0.35, max(0.6, rt - 0.9), max(0.6, ry_t - 0.75), inner)


def r_at(rt, rb, f):
    return rt + (rb - rt) * f


# ------------------------------------------------------------------------------------------------------------------------------------ square things
def slab(c, x0, y0, x1, y1, col, d=3, top=None, n=4, lo=0.62, hi=1.22, bevel=True, inset=1, side=0):
    """A box seen from a little above: front face rows y0..y1, x0..x1, with a top face `d` rows above it (the back edge `inset` px narrower each side). `side` = +1 / -1 adds a narrow side
    face on that side (the one turned toward the room's middle). Edges get a bevel: a light line along the top of the front, a darker one on the bottom and the shaded end."""
    tn = tones(col, n, lo, hi)
    tcol = top or shade(col, 1.20)
    for k in range(d):
        i = int(round(inset * (k + 1) / float(max(1, d))))
        c.hline(x0 + i, x1 - i, y0 - 1 - k, tcol if k < d - 1 else shade(tcol, 1.1))
    for y in range(y0, y1 + 1):
        f = (y - y0) / float(max(1, y1 - y0))
        c.hline(x0, x1, y, shade(col, 1.06 - 0.20 * f))
    if bevel:
        c.hline(x0, x1, y0, tn[-1])
        c.vline(x0, y0, y1, shade(col, 1.12))
        c.vline(x1, y0, y1, shade(col, 0.78))
        c.hline(x0, x1, y1, tn[0])
    if side:
        sx = (x1 + 1, x1 + 2) if side > 0 else (x0 - 2, x0 - 1)
        for xx in sx:
            c.vline(xx, y0 - d + 1, y1 - 1, shade(col, 0.66))


def stipple(c, x0, y0, x1, y1, col, density=0.3, seed=1):
    import random
    r = random.Random(seed)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if r.random() < density:
                c.put(x, y, col)


def glint(c, x, y, col=None):
    col = col or hexc('fff6dc')
    c.put(x, y, col)
