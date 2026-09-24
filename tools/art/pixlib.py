"""Tiny pixel-art drawing kit for the room-module mockups (tools/art/*.py).

Everything is drawn at NATIVE resolution (1 image px = 1 world px; the game camera zooms ~3x with
nearest filtering), with hard edges only — no anti-aliasing. Art is authored FLAT / neutrally lit
(docs/ART_REQUIREMENTS.md rule 2): gentle form shading and soft contact shadows only, never a baked
directional light — the engine's 2D lights do that.

Module geometry (docs/art_reference/blueprints, docs/Y_PLANES.md):
  320 x 144 px. Wall/floor seam (skirting) at y ~100. Room floor line = local 128; the player's
  feet = 129. The balcony plane (study/dining modules) is feet 104.
  Runtime WALL WINDOWS may appear at L (50..94, 10..66) or R (226..270, 10..66) — on the
  wallpaper band above the chair rail. Keep wall decor out of those boxes.
"""
from PIL import Image
import random

W, H = 320, 144
SEAM_Y = 100        # wall meets floor (top of the skirting shadow)
FLOOR_Y = 128       # the room floor line (feet 129)
WIN_L = (50, 10, 94, 66)      # room.MODULE_WINDOW_Y 262 = local 38; pane 44x52 + frame
WIN_R = (226, 10, 270, 66)


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


def check_window_boxes(full, wall_only):
    """The runtime wall windows (L/R) must land on bare wall: every pixel inside both boxes must
    equal the wall-only render. Returns [] when clean, else a list of offending (box, x, y)."""
    bad = []
    for name, (x0, y0, x1, y1) in (('L', WIN_L), ('R', WIN_R)):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if full.getpixel((x, y)) != wall_only.getpixel((x, y)):
                    bad.append((name, x, y))
    return bad


EDGE_COLS = (3, W - 4)   # module_walls samples each wall face from exactly these columns — furniture
                         # there smears along the side wall


def check_edge_columns(full, wall_only):
    """The partition/end-wall faces are painted from the module's edge columns (scripts/module_walls.gd
    _column: x 3 and W-4, rows 0..99). Furniture there would be smeared along the side wall, so those
    columns of the wall rows must be bare wall. Returns [] when clean."""
    bad = []
    for x in EDGE_COLS:
        for y in range(0, SEAM_Y):
            if full.getpixel((x, y)) != wall_only.getpixel((x, y)):
                bad.append((x, y))
    return bad


def save_floor_strip(floor_fn, name, root, seed=1):
    """Export the module's FLOOR ALONE (rows SEAM_Y..H-1, no furniture/shadows) as
    assets/rooms/<name>_floor.png. scripts/module_walls.gd tiles it across the floor wedge where two
    rooms meet at a doorway, so nothing standing on the floor near the edge is ever smeared into the
    next room. Floors should repeat every 32px (FLOOR_STRIP) so the continuation is seamless."""
    import os
    c = Canvas(seed=seed)
    floor_fn(c)
    strip = c.img.crop((0, SEAM_Y, W, H))
    path = os.path.join(root, 'assets', 'rooms', name + '_floor.png')
    strip.save(path)
    return strip


def floor_is_periodic(strip, period=32):
    """True when the floor-only image repeats every `period` px horizontally."""
    w, h = strip.size
    for y in range(h):
        for x in range(w - period):
            if strip.getpixel((x, y)) != strip.getpixel((x + period, y)):
                return False
    return True


# --- 2:1 pixel ISOMETRIC boxes (clean angled furniture) -------------------------------------
# A piece turned three-quarters (its front facing lower-left) is built from boxes in 2:1 iso:
# every edge steps exactly 2px across per 1px up/down — no jaggy slopes. Axes (per unit):
#   W = (2, 1)   along the piece's width  (its front edge runs down-right)
#   D = (2, -1)  into its depth           (front → back runs up-right)
#   height in plain pixels, up the screen.
ISO_W = (2, 1)
ISO_D = (2, -1)


def iso_pt(ox, oy, w, d, h):
    return (ox + ISO_W[0] * w + ISO_D[0] * d, oy + ISO_W[1] * w + ISO_D[1] * d - h)


def iso_box(c, ox, oy, w0, w1, d0, d1, h0, h1, top, front, side, faces=('top', 'front', 'side')):
    """A box from (w0,d0,h0) to (w1,d1,h1). Draws the three faces a lower-left-facing piece shows:
    FRONT (the d0 plane, facing lower-left), SIDE (the w1 plane, facing lower-right) and TOP."""
    P = lambda w, d, h: iso_pt(ox, oy, w, d, h)
    if 'side' in faces and side is not None:
        c.poly([P(w1, d0, h0), P(w1, d1, h0), P(w1, d1, h1), P(w1, d0, h1)], side)
    if 'front' in faces and front is not None:
        c.poly([P(w0, d0, h0), P(w1, d0, h0), P(w1, d0, h1), P(w0, d0, h1)], front)
    if 'top' in faces and top is not None:
        c.poly([P(w0, d0, h1), P(w1, d0, h1), P(w1, d1, h1), P(w0, d1, h1)], top)


def outline_layer(img, color):
    """1px outer outline around everything opaque on a transparent layer (a clean silhouette)."""
    px = img.load()
    w, h = img.size
    add = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 255:
                    add.append((x, y))
                    break
    for (x, y) in add:
        px[x, y] = color


def rrect(c, x0, y0, x1, y1, col, r=2):
    """Filled rectangle with rounded corners (radius r, pixel-art style — stepped, no AA)."""
    for y in range(y0, y1 + 1):
        inset = 0
        dy = min(y - y0, y1 - y)
        if dy < r:
            inset = r - dy
            if r >= 3 and dy == r - 1:
                inset = 1
        c.hline(x0 + inset, x1 - inset, y, col)
