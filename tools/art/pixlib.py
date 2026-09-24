"""Tiny pixel-art drawing kit for the room-module mockups (tools/art/*.py).

Everything is drawn at NATIVE resolution (1 image px = 1 world px; the game camera zooms ~3x with
nearest filtering), with hard edges only — no anti-aliasing. Art is authored FLAT / neutrally lit
(docs/ART_REQUIREMENTS.md rule 2): gentle form shading and soft contact shadows only, never a baked
directional light — the engine's 2D lights do that.

Module geometry (docs/art_reference/blueprints, docs/Y_PLANES.md):
  320 x 144 px. Wall/floor seam (skirting) at y ~100. Room floor line = local 128; the player's
  feet = 129. The balcony plane (study/dining modules) is feet 104.
  Runtime WALL WINDOWS may appear at L (50..94, 34..86) or R (226..270, 34..86) — keep tall
  furniture and wall decor out of those boxes.
"""
from PIL import Image
import random

W, H = 320, 144
SEAM_Y = 100        # wall meets floor (top of the skirting shadow)
FLOOR_Y = 128       # the room floor line (feet 129)
WIN_L = (50, 34, 94, 86)
WIN_R = (226, 34, 270, 86)


def hexc(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(3)) + (255,)


def shade(c, f):
    """f < 1 darker, > 1 lighter (toward white)."""
    if f <= 1.0:
        return tuple(int(c[i] * f) for i in range(3)) + (255,)
    return mix(c, (255, 255, 255, 255), f - 1.0)


class Canvas:
    def __init__(self, w=W, h=H, bg=(0, 0, 0, 0), seed=1):
        self.img = Image.new('RGBA', (w, h), bg)
        self.px = self.img.load()
        self.w, self.h = w, h
        self.rng = random.Random(seed)

    # --- primitives (all inclusive of x0..x1, y0..y1) ---
    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            if len(c) == 4 and c[3] < 255:
                if c[3] == 0:
                    return
                bg = self.px[x, y]
                a = c[3] / 255.0
                self.px[x, y] = tuple(int(round(bg[i] * (1 - a) + c[i] * a)) for i in range(3)) + (max(bg[3], c[3]),)
            else:
                self.px[x, y] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(max(0, y0), min(self.h - 1, y1) + 1):
            for x in range(max(0, x0), min(self.w - 1, x1) + 1):
                self.put(x, y, c)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def box(self, x0, y0, x1, y1, fill, outline=None):
        self.rect(x0, y0, x1, y1, fill)
        if outline is not None:
            self.hline(x0, x1, y0, outline)
            self.hline(x0, x1, y1, outline)
            self.vline(x0, y0, y1, outline)
            self.vline(x1, y0, y1, outline)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                if ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / max(ry, 0.5)) ** 2 <= 1.0:
                    self.put(x, y, c)

    def poly(self, pts, c):
        """Filled polygon (scanline, even-odd)."""
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            n = len(pts)
            for i in range(n):
                (xa, ya), (xb, yb) = pts[i], pts[(i + 1) % n]
                if ya == yb:
                    continue
                if (y >= min(ya, yb)) and (y < max(ya, yb)):
                    xs.append(xa + (y - ya) * (xb - xa) / (yb - ya))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(round(xs[i])), int(round(xs[i + 1])) + 1):
                    self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def dither(self, x0, y0, x1, y1, c, density=0.5, pattern='checker'):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if pattern == 'checker':
                    on = (x + y) % 2 == 0 if density >= 0.5 else (x % 2 == 0 and y % 2 == 0)
                else:
                    on = self.rng.random() < density
                if on:
                    self.put(x, y, c)

    def shadow(self, cx, cy, rx, ry, alpha=70):
        """Soft contact shadow under an object (allowed by the brief)."""
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                d = ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / max(ry, 0.5)) ** 2
                if d <= 1.0:
                    a = int(alpha * (1.0 - d) ** 0.6)
                    self.put(x, y, (20, 14, 12, a))

    def save(self, path, preview_path=None, scale=4):
        self.img.save(path)
        if preview_path:
            self.img.resize((self.w * scale, self.h * scale), Image.NEAREST).save(preview_path)
