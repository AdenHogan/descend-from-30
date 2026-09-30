"""A small pixel-art ICON kit for the inventory icons (tools/art/item_icons.py).

Every icon is drawn at NATIVE size (56x56 — the HUD slot shows it 1:1, the loot panel 2x) with hard
pixels and one consistent look, so a whole bag of them reads as one set:

  * shapes are MASKS (polygons, ellipses, thick lines, rounded boxes) drawn aliased at 1:1;
  * part() fills a mask with a base colour and SHADES it: a volume term (flat, a vertical / horizontal
    ramp, a CYLINDER across an axis, or a radial dome), then a 1px lit rim on the top-left edges and a
    shadow rim on the bottom-right edges (light always comes from the top left), posterised to a few
    steps so it stays pixel art, not a smooth gradient;
  * where a part lies over an earlier part, its edge gets a dark CONTACT line, so overlapping pieces
    (a blade into a handle, a cap onto a bottle) stay separate;
  * finish() adds the SELECTIVE outline — each outline pixel is a darkened version of the colour it
    borders, not flat black — and a soft ground shadow for things that stand up.

Axis helpers (Axis) place long things (blades, bats, keys) on a clean diagonal: 45 degrees gives
perfect one-pixel stair steps.
"""
import math

import numpy as np
from PIL import Image, ImageDraw

S = 56


def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def scale(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c[:3])


class Icon:
    def __init__(self, size=S):
        self.n = size
        self.rgb = np.zeros((size, size, 3), np.float32)
        self.a = np.zeros((size, size), np.float32)      # 0..1 coverage

    # ---- masks ---------------------------------------------------------------------------------
    def mask(self):
        m = Image.new('L', (self.n, self.n), 0)
        return m, ImageDraw.Draw(m)

    def poly(self, pts):
        m, d = self.mask()
        d.polygon([(round(x), round(y)) for x, y in pts], fill=255)
        return _arr(m)

    def ellipse(self, box):
        m, d = self.mask()
        d.ellipse([round(v) for v in box], fill=255)
        return _arr(m)

    def rect(self, box, r=0):
        m, d = self.mask()
        box = [round(v) for v in box]
        if r:
            d.rounded_rectangle(box, radius=r, fill=255)
        else:
            d.rectangle(box, fill=255)
        return _arr(m)

    def line(self, pts, w=1):
        m, d = self.mask()
        d.line([(round(x), round(y)) for x, y in pts], fill=255, width=w, joint='curve')
        if w >= 3:
            for x, y in pts:
                r = (w - 1) / 2
                d.ellipse([round(x - r), round(y - r), round(x + r), round(y + r)], fill=255)
        return _arr(m)

    def arc(self, box, a0, a1, w=1):
        m, d = self.mask()
        d.arc([round(v) for v in box], a0, a1, fill=255, width=w)
        return _arr(m)

    # ---- painting ------------------------------------------------------------------------------
    def part(self, m, base, shade='flat', axis=None, light=1.22, dark=0.66, rim=True, contact=True,
             steps=5, strength=0.35, alpha=1.0, hl=0.0, clip=None):
        """Fill mask m with `base`, shaded. shade: flat | v | h | cyl (needs axis=(ux,uy), the long
        direction) | dome. hl > 0 adds a specular streak (cyl) / spot (dome) of that strength."""
        m = m.copy()
        if clip is not None:
            m &= clip
        if not m.any():
            return m
        base = np.array(base[:3], np.float32)
        ys, xs = np.nonzero(m)
        k = np.ones(m.shape, np.float32)
        yy, xx = np.mgrid[0:self.n, 0:self.n].astype(np.float32)
        if shade in ('v', 'h', 'cyl', 'dome'):
            if shade == 'v':
                s = _norm(yy, ys.min(), ys.max())
                k = 1 + strength * (0.5 - s) * 2
            elif shade == 'h':
                s = _norm(xx, xs.min(), xs.max())
                k = 1 + strength * (0.5 - s) * 2
            elif shade == 'cyl':
                ux, uy = axis
                L = math.hypot(ux, uy)
                px_, py_ = -uy / L, ux / L                       # across the axis
                if px_ + py_ > 0:                                # make "across" point up-left → lit side
                    px_, py_ = -px_, -py_
                proj = xx * px_ + yy * py_
                pv = proj[m]
                s = (proj - pv.min()) / max(1e-6, pv.max() - pv.min())   # 0 dark side .. 1 lit side
                k = 0.72 + 0.55 * np.sin(np.clip(s, 0, 1) * math.pi * 0.62 + 0.25)
                if hl:
                    k = k + hl * np.exp(-((s - 0.78) ** 2) / 0.006)
            elif shade == 'dome':
                cx, cy = xs.mean(), ys.mean()
                rx = max(1.0, (xs.max() - xs.min()) / 2)
                ry = max(1.0, (ys.max() - ys.min()) / 2)
                d = np.sqrt(((xx - (cx - rx * 0.35)) / rx) ** 2 + ((yy - (cy - ry * 0.35)) / ry) ** 2)
                k = 1.25 - 0.5 * np.clip(d, 0, 1.4)
                if hl:
                    k = k + hl * np.exp(-(d ** 2) / 0.05)
            k = _post(k, steps)
        col = base[None, None, :] * k[..., None]
        if rim:
            lit = m & ~(_shift(m, 1, 0) & _shift(m, 0, 1))        # a neighbour up / left is outside
            shd = m & ~(_shift(m, -1, 0) & _shift(m, 0, -1))      # a neighbour down / right is outside
            col[lit] = col[lit] * light
            col[shd & ~lit] = col[shd & ~lit] * dark
        if contact:
            edge = m & ~_erode(m)
            touch = edge & _dilate((self.a > 0.5) & ~m)
            col[touch] = col[touch] * 0.58
        col = np.clip(col, 0, 255)
        self._blend(m, col[m], alpha)
        return m

    def _blend(self, m, cols, a):
        if a >= 1:
            self.rgb[m] = cols
            self.a[m] = 1.0
            return
        under = (self.a[m] > 0.05)[:, None]
        self.rgb[m] = np.where(under, self.rgb[m] * (1 - a) + cols * a, cols)
        self.a[m] = np.maximum(self.a[m], a)

    def px(self, x, y, c, a=1.0):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.n and 0 <= y < self.n:
            m = np.zeros((self.n, self.n), bool)
            m[y, x] = True
            self._blend(m, np.array([c[:3]], np.float32), a)

    def paint(self, m, c, a=1.0, only_on=False):
        """Flat colour over mask m (details: stripes, text lines, rivets) — no shading, no rim.
        only_on: keep it to pixels already painted (a label that must not spill off its can)."""
        if only_on:
            m = m & (self.a > 0.5)
        if not m.any():
            return
        self._blend(m, np.tile(np.array(c[:3], np.float32), (int(m.sum()), 1)), a)

    def darken(self, m, k):
        m = m & (self.a > 0)
        self.rgb[m] *= k

    def cut(self, m):
        """Punch a hole (torn cloth, a key's bow)."""
        self.a[m] = 0
        self.rgb[m] = 0

    # ---- finishing -----------------------------------------------------------------------------
    def finish(self, shadow=None, outline=0.30):
        solid = self.a > 0.05
        out = np.zeros((self.n, self.n, 4), np.float32)
        if shadow:                                           # (cx, cy, rx, ry): soft ground shadow
            cx, cy, rx, ry = shadow
            yy, xx = np.mgrid[0:self.n, 0:self.n].astype(np.float32)
            d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
            sa = np.where(d < 1, 0.42 * (1 - d * 0.5), 0) * (~solid)
            out[..., 3] = np.maximum(out[..., 3], _post(sa, 3))
        ring = _dilate(solid) & ~solid
        # each outline pixel takes the darkened colour of the solid pixels it touches
        acc = np.zeros((self.n, self.n, 3), np.float32)
        cnt = np.zeros((self.n, self.n), np.float32)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sm = _shift(solid, dx, dy)
            sc = _shift_arr(self.rgb, dx, dy)
            acc += sc * sm[..., None]
            cnt += sm
        oc = acc / np.maximum(cnt, 1)[..., None] * outline
        out[..., :3] = np.where(ring[..., None], oc, out[..., :3])
        out[..., 3] = np.where(ring, 1.0, out[..., 3])
        out[..., :3] = np.where(solid[..., None], self.rgb, out[..., :3])
        out[..., 3] = np.where(solid, np.clip(self.a, 0, 1), out[..., 3])
        img = np.zeros((self.n, self.n, 4), np.uint8)
        img[..., :3] = np.clip(out[..., :3], 0, 255).astype(np.uint8)
        img[..., 3] = np.clip(out[..., 3] * 255, 0, 255).astype(np.uint8)
        return Image.fromarray(img, 'RGBA')


class Axis:
    """A straight line to hang a long object on: at(t, o) = p0 + t*u + o*v (u along, v across,
    v = u turned 90 degrees clockwise, so +o is the lower-right side on a rising diagonal)."""

    def __init__(self, p0, deg):
        self.p0 = p0
        a = math.radians(deg)
        self.u = (math.cos(a), -math.sin(a))
        self.v = (-self.u[1], self.u[0])
        if self.v[0] + self.v[1] < 0:
            self.v = (-self.v[0], -self.v[1])

    def at(self, t, o=0.0):
        return (self.p0[0] + self.u[0] * t + self.v[0] * o, self.p0[1] + self.u[1] * t + self.v[1] * o)

    def band(self, t0, t1, w0, w1=None, o0=0.0):
        """A quad from t0 to t1, half-width w0 → w1, centred o0 across."""
        w1 = w0 if w1 is None else w1
        return [self.at(t0, o0 - w0), self.at(t1, o0 - w1), self.at(t1, o0 + w1), self.at(t0, o0 + w0)]

    def pts(self, tos):
        return [self.at(t, o) for t, o in tos]

    @property
    def dir(self):
        return self.u


# ---- numpy helpers -------------------------------------------------------------------------------
def _arr(m):
    return np.array(m) > 127


def _norm(v, lo, hi):
    return np.clip((v - lo) / max(1e-6, hi - lo), 0, 1)


def _post(k, steps):
    q = 1.0 / steps * 1.6
    return np.round(k / q) * q


def _shift(m, dx, dy):
    """Shift a boolean mask so out[y, x] = m[y - dy, x - dx] (outside → False)."""
    out = np.zeros_like(m)
    h, w = m.shape
    ys = slice(max(dy, 0), h + min(dy, 0))
    yd = slice(max(-dy, 0), h + min(-dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = m[yd, xd]
    return out


def _shift_arr(a, dx, dy):
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    ys = slice(max(dy, 0), h + min(dy, 0))
    yd = slice(max(-dy, 0), h + min(-dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = a[yd, xd]
    return out


def _erode(m):
    return m & _shift(m, 1, 0) & _shift(m, -1, 0) & _shift(m, 0, 1) & _shift(m, 0, -1)


def _dilate(m):
    return m | _shift(m, 1, 0) | _shift(m, -1, 0) | _shift(m, 0, 1) | _shift(m, 0, -1)
