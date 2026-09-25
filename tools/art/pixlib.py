"""Tiny pixel-art drawing kit for the room-module mockups (tools/art/*.py).

Everything is drawn at NATIVE resolution (1 image px = 1 world px; the game camera zooms ~3x with
nearest filtering), with hard edges only — no anti-aliasing. Art is authored FLAT / neutrally lit
(docs/ART_REQUIREMENTS.md rule 2): gentle form shading and soft contact shadows only, never a baked
directional light — the engine's 2D lights do that.

Module geometry (docs/blueprints — the locked room template, docs/Y_PLANES.md):
  320 x 144 px. Wall/floor seam (skirting) at y ~100. Room floor line = local 128; the player's
  feet = 129. The balcony plane (study/dining modules) is feet 104.
  Runtime WALL WINDOWS may appear at L (50..94, 10..66) or R (226..270, 10..66) — on the
  wallpaper band above the chair rail. Keep wall decor out of those boxes.
"""
from PIL import Image
import random
import zlib

W, H = 320, 144

# LIGHT FIXTURES (owner round 14 — lamps on desks / drawers / coffee tables + ceiling lights, lit for
# real in the evening and at night): the lamp helpers in furn.py draw a fixture AND register its bulb
# here; finish_module collects them from the render and writes them into the module scene as a
# `Lights` container (scripts/apartment_lights.gd turns them on, off, flickering or cutting out).
# moved()/shifted() push their offset so a lamp drawn inside a moved piece lands where it's drawn.
LIGHT_KINDS = ('table', 'desk', 'floor', 'lava', 'lantern', 'pendant', 'bulb', 'flush', 'tube', 'chandelier')
LIGHTS = []
_LIGHT_OFF = [(0, 0)]


def light(x, y, kind):
    assert kind in LIGHT_KINDS, kind
    ox, oy = _LIGHT_OFF[-1]
    LIGHTS.append((int(round(x + ox)), int(round(y + oy)), kind))


def push_light_offset(dx, dy):
    ox, oy = _LIGHT_OFF[-1]
    _LIGHT_OFF.append((ox + dx, oy + dy))


def pop_light_offset():
    _LIGHT_OFF.pop()


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


def save_floor_strip(floor_fn, name, root, seed=1, level=None):
    """Export the module's FLOOR ALONE (rows SEAM_Y..H-1, no furniture/shadows):
      assets/rooms/<name>_floor.png      — the floor exactly as the art shows it (perspective), 320x44:
                                           what the blueprint tool compares the art against;
      assets/rooms/<name>_floor_ext.png  — the same floor running FLOOR_EXT_M px past each edge, which
                                           scripts/module_walls.gd lays where the room's floor runs on
                                           to an end wall's base line (nothing standing near the edge is
                                           ever carried on).
    `level` 2/3 adds that run's floor grime (the run looks). Returns the FLAT floor rows, which must
    repeat every 32px (the pattern the perspective is sampled from)."""
    import os
    if getattr(floor_fn, '_flat', None) is None:
        raise SystemExit('%s: wrap the floor function in @persp (pixlib) — floors are drawn in perspective' % name)
    dirt = (58, 46, 34)
    c = Canvas(seed=seed)
    floor_fn(c)
    strip = c.img.crop((0, SEAM_Y, W, H))
    flat = Canvas(seed=seed)
    _PERSP_DEPTH[0] += 1                  # a floor built from another's (lr.floor) draws flat too
    try:
        floor_fn._flat(flat)
    finally:
        _PERSP_DEPTH[0] -= 1
    if level is not None:
        _floor_grime(strip, 0, level, dirt)
    suffix = '' if level is None else '_r%d' % level
    strip.save(os.path.join(root, 'assets', 'rooms', name + suffix + '_floor.png'))
    ext = floor_ext(flat.img, level, dirt)
    ext.save(os.path.join(root, 'assets', 'rooms', name + suffix + '_floor_ext.png'))
    if ext.crop((FLOOR_EXT_M, 0, FLOOR_EXT_M + W, H - SEAM_Y)).tobytes() != strip.tobytes():
        raise SystemExit('%s%s: the extended floor does not match the art\'s own floor' % (name, suffix))
    return flat.img.crop((0, SEAM_Y, W, H))


# --- FLOORS IN PERSPECTIVE (owner round 14 — a tile floor "looks like an optical illusion where you're
# standing on glass… the tiles go directly down and not along what would be a flat surface"): every
# module floor is drawn FLAT (a pattern repeating every 32px, rows already taller toward the viewer),
# then each floor row is remapped toward the module's vanishing point — the horizon is the ceiling
# (y 0) and the vanishing point the module centre, the perspective module_walls and setback() use — so
# tile / board seams CONVERGE up the screen like a real floor: at row y art column x shows flat column
# VP + (x − VP)·(1 + PERSP_K·(SEAM/y − 1)) (_persp_sx; PERSP_K 1 would be the full SEAM/y). `persp(floor_fn)` wraps a floor function; nested calls draw flat (a variant
# floor built from another's). finish_module also exports <name>_floor_ext.png: the same perspective
# floor FLOOR_EXT_M px past each edge, which module_walls lays where a room's floor runs on to an END
# wall's base line (between two rooms the join is fixed at the module edge).
PERSP_K = 0.55                      # how much of the full convergence the floor takes: the art's
                                    # vanishing point is the MODULE's centre but the player stands
                                    # anywhere, so at full strength a floor at the module's edge leaned
                                    # ~58° (sheared diagonal stripes); ~0.55 reads flat without that
FLOOR_EXT_M = 96                    # a multiple of 32, so the periodic floor grime lines up
                                    # (module_walls.FLOOR_EXT_M: keep in step)
_PERSP_DEPTH = [0]


def _persp_sx(x, y):
    """The FLAT floor column shown at art column x on floor row y (perspective toward VP_X)."""
    return VP_X + (x - VP_X) * (1.0 + PERSP_K * (SEAM_Y / float(y) - 1.0))


def persp(fn):
    if getattr(fn, '_flat', None) is not None:
        return fn

    def wrapped(c):
        if _PERSP_DEPTH[0] > 0:
            return fn(c)
        _PERSP_DEPTH[0] += 1
        try:
            flat = Canvas(bg=(0, 0, 0, 0))
            flat.rng = c.rng
            fn(flat)
        finally:
            _PERSP_DEPTH[0] -= 1
        fp_ = flat.px
        for y in range(H):
            for x in range(W):
                if y < SEAM_Y:
                    p_ = fp_[x, y]
                    if p_[3]:
                        c.put(x, y, p_)
                    continue
                sx = int(round(_persp_sx(x, y)))
                p_ = fp_[min(max(sx, 0), W - 1), y]
                if p_[3]:
                    c.put(x, y, p_)
    wrapped._flat = fn
    wrapped.__name__ = getattr(fn, '__name__', 'floor')
    return wrapped


def floor_ext(flat_img, grime_level=None, dirt=(58, 46, 34)):
    """The perspective floor rows (SEAM_Y..H-1) from x −M to W+M, from a FLAT periodic floor image."""
    M = FLOOR_EXT_M
    fp_ = flat_img.load()
    out = Image.new('RGBA', (W + 2 * M, H - SEAM_Y), (0, 0, 0, 0))
    op = out.load()
    for y in range(SEAM_Y, H):
        for xe in range(W + 2 * M):
            x = xe - M
            sx = int(round(_persp_sx(x, y)))
            if not 0 <= sx < W:
                sx = sx % 32 + 128                        # the flat floor repeats every 32px
            op[xe, y - SEAM_Y] = fp_[sx, y]
    if grime_level is not None:
        _floor_grime(out, 0, grime_level, dirt)
    return out


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


# --- SET-BACK FURNITURE WITH DEPTH (owner round 14 — "the drawers, chests, wardrobes, bookshelves,
# they look so flat against the back wall. It just looks like a picture… there needs to be reality and
# weight to things even in pixel form") -----------------------------------------------------------
# A piece against the back wall is drawn as before (its FRONT face), on its own layer, then brought
# FORWARD `depth` px and its silhouette EXTRUDED back to the wall toward the room's vanishing point —
# the horizon is the ceiling (y 0) and each module's vanishing point is its centre (x 160), the same
# perspective module_walls draws the partitions in. So a chest shows its TOP (lit), and the side
# facing the middle of the room (the shadowed side darker); plinths, cornices, legs and mouldings
# carry through because it is the edge pixels that are extruded. Its back lands exactly on the
# wall/floor seam (y 100). Anchors on the piece and lamps drawn on it move with it (finish_module).
TOP_RAKE = 1.8          # tops get a little more depth than the true perspective, so they read
SETBACKS = []           # [(opaque-pixel set of the piece as drawn, depth)] — collected per build
VP_X = W // 2


DEPTH_GAIN = 1.6        # owner round 15 ("I am still seeing items flat against the wall"): every
DEPTH_MAX = 11          # set-back piece stands this much further out than first drawn (3 → 5, 4 → 6,
                        # 5 → 8, 7 → 11); 11 keeps the step-up stand zone (rows 102-114) clear


def setback_depth(depth, forward=0):
    if depth <= 0:
        return 0
    return max(depth, min(DEPTH_MAX - forward, int(round(depth * DEPTH_GAIN))))


def setback(c, fn, depth=5, top=None, x_range=None, vpx=VP_X, rake=None, forward=0):
    """Draw `fn` (a set-back piece, base on the seam) with real depth — see above.
    depth   — how far forward its front comes (px of floor): ~3 shelves, 5 chests, 6-7 wardrobes.
    top     — the y of its top surface: anything drawn above it (a lamp, a vase, a photo) sits ON
              the piece and is not extruded. Default: the highest opaque pixel.
    x_range — (x0, x1) limit what counts as the piece's body (e.g. to leave out a cord).
    rake    — the top's extra depth (default TOP_RAKE); less keeps a tall piece's top off a window box.
    forward — stand it this much further out from the wall first (a box in front of a counter that
              itself came forward); depth 0 + forward = a plain move forward, no extrusion."""
    rake = TOP_RAKE if rake is None else rake
    want = setback_depth(depth, forward)
    for d in range(want, depth - 1, -1):          # the gained depth, backed off if its top would rake
        n0 = len(LIGHTS)                          # into a window box / a side-wall sample column
        ext, lyr_img, opaque = _setback_render(fn, d, top, x_range, vpx, rake, forward)
        if d <= depth or _setback_clear(ext, lyr_img, d + forward):
            break
        del LIGHTS[n0:]
    SETBACKS.append((opaque, d + forward))
    c.img.alpha_composite(ext)
    moved = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    moved.paste(lyr_img, (0, d + forward), lyr_img)
    c.img.alpha_composite(moved)
    c.px = c.img.load()


def _setback_clear(ext, lyr_img, shift):
    ep, lp = ext.load(), lyr_img.load()
    for (x0, y0, x1, y1) in (WIN_L, WIN_R):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if ep[x, y][3] or (0 <= y - shift and lp[x, y - shift][3]):
                    return False
    for x in EDGE_COLS:
        for y in range(0, SEAM_Y):
            if ep[x, y][3] or (0 <= y - shift and lp[x, y - shift][3]):
                return False
    return True


def _setback_render(fn, depth, top, x_range, vpx, rake, forward):
    lyr = Canvas(bg=(0, 0, 0, 0), seed=11)
    push_light_offset(0, depth + forward)
    try:
        fn(lyr)
    finally:
        pop_light_offset()
    sp = lyr.px
    opaque = set()
    for y in range(H):
        for x in range(W):
            if sp[x, y][3] == 255:
                opaque.add((x, y))
    back = SEAM_Y + forward                        # where its back stands
    body = set()
    ytop = top if top is not None else min((y for (x, y) in opaque), default=0)
    for (x, y) in opaque:
        if y >= ytop and (x_range is None or x_range[0] <= x <= x_range[1]):
            body.add((x, y))
    k = back / float(back + depth)                 # the back face's scale toward the vanishing point
    ky = 1 - (1 - k) * rake                    # a touch more rake on the tops so they read
    outline_col = min((sp[x, y] for (x, y) in body), key=lambda p_: p_[0] + p_[1] + p_[2]) if body else (0, 0, 0, 255)

    def inward(x, y, dx, dy):
        # the face colour: step in past the outline to the body's own colour
        for n_ in (2, 1, 0):
            q_ = (x + dx * n_, y + dy * n_)
            if q_ in body:
                return sp[q_[0], q_[1]]
        return sp[x, y]
    best = {}                                      # output pixel -> (t, colour): nearest wins
    for (x, y) in body:
        up = (x, y - 1) not in body
        lft = (x - 1, y) not in body
        rgt = (x + 1, y) not in body
        if up:
            col = shade(inward(x, y, 0, 1), 1.12)          # the top, lit from above
        elif rgt and x < vpx:
            col = shade(inward(x, y, -1, 0), 0.62)         # a right-facing side: away from the light
        elif lft and x > vpx:
            col = shade(inward(x, y, 1, 0), 0.80)          # a left-facing side: toward it
        else:
            col = shade(sp[x, y], 0.66)
        py = y + depth + forward
        mag = ((x - vpx) ** 2 + py ** 2) ** 0.5 * (1 - k) * rake
        n = int(mag * 2) + 2
        for i in range(1, n + 1):
            t = i / float(n)
            q = (int(round(vpx + (x - vpx) * (1 - t * (1 - k)))), int(round(py * (1 - t * (1 - ky)))))
            if 0 <= q[0] < W and 0 <= q[1] < H and (q not in best or best[q][0] > t):
                best[q] = (t, col)
    ext = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ep = ext.load()
    for (q, (t, col)) in best.items():
        ep[q[0], q[1]] = col[:3] + (255,)
    front = {(x, y + depth + forward) for (x, y) in opaque}
    for q in best:                                 # re-outline the new silhouette (top + side)
        for (dx, dy) in ((0, -1), (-1, 0), (1, 0)):
            nq = (q[0] + dx, q[1] + dy)
            if nq not in best and nq not in front:
                ep[q[0], q[1]] = outline_col[:3] + (255,)
                break
    return ext, lyr.img, opaque


# --- A TRUE-PERSPECTIVE BOX (owner round 15 — "this toilet looks like it is painted onto the
# background"): for pieces whose shape matters (a toilet, a basin, a bath), describe it in WALL
# coordinates (x, y as if drawn flat on the back wall; y 100 = the floor) plus how far it stands
# out from the wall (depth d, px of floor), and project: a point d px out is scaled by (100 + d) / 100
# about the vanishing point (VP_X, the ceiling line y 0). So a floor-standing piece's feet land on
# y 100 + d, its top shows (we look down on it), and the side facing the room's middle shows.
def pp(x, y, d, vpx=VP_X):
    """Wall-coord point (x, y) brought d px out from the back wall → art coords (floats)."""
    s = (SEAM_Y + d) / float(SEAM_Y)
    return (vpx + (x - vpx) * s, y * s)


def _ip(p_):
    return (int(round(p_[0])), int(round(p_[1])))


def pbox(c, x0, y0, x1, y1, d0, d1, front, top=None, side=None, out=None, vpx=VP_X):
    """A box: wall-coord rect x0..x1 × y0..y1 filling depths d0..d1 out from the wall. Draws the
    side facing the vanishing point, the top, then the front; `out` outlines the silhouette.
    Returns the projected corners {'fl','fr','fbl','fbr','bl','br'} (front-top-left, front-top-right,
    front-bottom-left, front-bottom-right, back-top-left, back-top-right) for decoration."""
    top = top if top is not None else shade(front, 1.12)
    side = side if side is not None else shade(front, 0.72)
    fl, fr = _ip(pp(x0, y0, d1, vpx)), _ip(pp(x1, y0, d1, vpx))
    fbl, fbr = _ip(pp(x0, y1, d1, vpx)), _ip(pp(x1, y1, d1, vpx))
    bl, br = _ip(pp(x0, y0, d0, vpx)), _ip(pp(x1, y0, d0, vpx))
    bbl, bbr = _ip(pp(x0, y1, d0, vpx)), _ip(pp(x1, y1, d0, vpx))
    if x1 < vpx:                                   # left of the middle: its right side shows
        c.poly([br, fr, fbr, bbr], side)
    elif x0 > vpx:                                 # right of the middle: its left side shows
        c.poly([bl, fl, fbl, bbl], side)
    c.poly([bl, br, fr, fl], top)
    c.rect(fl[0], fl[1], fbr[0], fbr[1], front)
    if out is not None:
        c.line(bl[0], bl[1], br[0], br[1], out)
        c.line(fl[0], fl[1], bl[0], bl[1], out)
        c.line(fr[0], fr[1], br[0], br[1], out)
        if x1 < vpx:
            c.line(br[0], br[1], bbr[0], bbr[1], out)
            c.line(bbr[0], bbr[1], fbr[0], fbr[1], out)
        elif x0 > vpx:
            c.line(bl[0], bl[1], bbl[0], bbl[1], out)
            c.line(bbl[0], bbl[1], fbl[0], fbl[1], out)
        c.hline(fl[0], fr[0], fl[1], out)
        c.hline(fbl[0], fbr[0], fbl[1], out)
        c.vline(fl[0], fl[1], fbl[1], out)
        c.vline(fr[0], fr[1], fbr[1], out)
    return {'fl': fl, 'fr': fr, 'fbl': fbl, 'fbr': fbr, 'bl': bl, 'br': br}


def pellipse(c, cx, y, d0, d1, rx, col, vpx=VP_X):
    """A flat horizontal ellipse (a seat, a basin rim, a stool top) at wall-height y, spanning depths
    d0..d1 out from the wall, rx wide (wall coords), seen from above in perspective."""
    dm = (d0 + d1) / 2.0
    ccx, _ = pp(cx, y, dm, vpx)
    ya, yb = pp(cx, y, d0, vpx)[1], pp(cx, y, d1, vpx)[1]
    s = (SEAM_Y + dm) / float(SEAM_Y)
    c.ellipse(ccx, (ya + yb) / 2.0, rx * s, max(0.6, (yb - ya) / 2.0), col)
    return (ccx, (ya + yb) / 2.0, rx * s, (yb - ya) / 2.0)


def _setback_anchor(ax, ay):
    """How far an anchor at (ax, ay) moves: the depth of the set-back piece it sits on (0 if none)."""
    for (opaque, depth) in SETBACKS:
        if (ax, ay) in opaque:
            return depth
    return 0


# --- one entry point for every module script -------------------------------------------------
BALCONY_BOX = (4, 0, 96, H - 1)      # where a balcony-capable module's balcony doors go (study/dining)


# The BACK (scavenge) PLANE (scripts/room.gd BACK_PLANE_RISE / back_plane_spot.gd): the player steps
# up to stand at a set-back piece with its feet at local y 115 (world 339), centred on the cluster of
# its spawned 'bp' nodes (nodes within BACK_SPOT_CLUSTER px share a spot). Set-back furniture stands
# at ~101, front furniture at ~114-118 — so a column that is NOT bare floor all the way through rows
# BP_ROWS is a front piece standing exactly where the player would stand (owner round 13b: "wherever
# you're placing these higher up furnitures, y planes will need to be developed to allow the player
# to move up and scavenge"). Rugs start lower, set-back shadows stop higher, so neither trips it.
BP_ROWS = range(102, 115)
BP_HALF_W = 13                  # the player's half-width up there: MEASURED — the idle body is 28-30px
                                # wide (collision capsule r 13) x the plane's 0.89 scale ~ 25-26px
BP_CLUSTER = 40                 # room.gd BACK_SPOT_CLUSTER


def check_back_plane_clear(img, floor_img, anchors):
    xs = sorted(ax for (an, ax, ay, fl_) in anchors if 'bp' in fl_)
    centres = set(xs)
    for i in range(len(xs)):                        # any spawned sub-cluster: centres in between too
        for j in range(i + 1, len(xs)):
            if all(xs[k + 1] - xs[k] <= BP_CLUSTER for k in range(i, j)):
                centres.add((xs[i] + xs[j]) / 2.0)
    bad = []
    for cx in sorted(centres):
        for x in range(int(cx) - BP_HALF_W, int(cx) + BP_HALF_W + 1):
            if 0 <= x < W and all(img.getpixel((x, y)) != floor_img.getpixel((x, y)) for y in BP_ROWS):
                bad.append((int(cx), x))
                break
    return bad


def finish_module(name, room_type, seed, wall_fn, floor_fn, build_fn, anchors, strip_fn=None, per_run=None):
    """Render, check and export one module variant, and write its scene.

    wall_fn(c)  — the bare wall (wall + decay): the reference the window/edge checks compare to.
    floor_fn(c) — the floor alone (exported as <name>_floor.png, must repeat every 32px).
    build_fn(c) — everything (wall, floor, furniture) EXCEPT the balcony-strip furniture.
    strip_fn(c) — balcony-capable rooms only: the furniture standing in the balcony strip
                  (x 4..96); exported separately as <name>_strip.png so room.gd can hide it (and
                  its nodes) on a balcony slot.
    anchors     — [(node_name, x, y, flags)], flags 'bp' back plane / 's' balcony strip.
    per_run     — optional per_run(run): called before REBUILDING the module for runs 2 and 3 (and
                  with 1 after), so furniture can change between runs (a chair knocked back and
                  bloodied — chair3d.RUN). The run looks then age THOSE images, and every node is
                  checked to still sit on something drawn in them. None = the run looks age run 1.
    """
    import os
    import sys
    from modscene import write_scene, BALCONY_TYPES, ROOT
    LIGHTS.clear()
    main = Canvas(seed=seed)
    build_fn(main)
    main_lights = list(LIGHTS)
    LIGHTS.clear()
    SETBACKS.clear()
    full = Canvas(seed=seed)
    build_fn(full)
    n_main = len(LIGHTS)
    if strip_fn is not None:
        strip_fn(full)
    strip_lights = LIGHTS[n_main:]
    # nodes on a set-back piece come forward with it (setback())
    anchors = [(an, ax, ay + _setback_anchor(ax, ay), fl_) for (an, ax, ay, fl_) in anchors]
    lights = [(x, y, k, '') for (x, y, k) in main_lights] + [(x, y, k, 's') for (x, y, k) in strip_lights]
    bare = Canvas(seed=seed)
    wall_fn(bare)
    bare_floor = Canvas(seed=seed)
    wall_fn(bare_floor)
    floor_fn(bare_floor)
    errs = []
    bad = check_window_boxes(full.img, bare.img)
    if bad:
        errs.append('furniture inside a runtime window box: %s' % bad[:6])
    edge = check_edge_columns(full.img, bare.img)
    if edge:
        errs.append('furniture in the side-wall sample columns: %s' % edge[:6])
    if room_type in BALCONY_TYPES:
        x0, y0, x1, y1 = BALCONY_BOX
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if main.img.getpixel((x, y)) != bare_floor.img.getpixel((x, y)):
                    errs.append('balcony strip (x %d..%d) must be bare in the main art — put it in strip_fn: (%d,%d)' % (x0, x1, x, y))
                    break
            else:
                continue
            break
    elif strip_fn is not None:
        errs.append('only balcony-capable rooms have a strip')
    holes = [(x, y) for y in range(H) for x in range(W) if main.img.getpixel((x, y))[3] != 255]
    if holes:
        errs.append('transparent pixels in the art (they show the grey placeholder in game): %s' % holes[:6])
    fl = save_floor_strip(floor_fn, name, ROOT, seed=seed)
    if not floor_is_periodic(fl):
        errs.append('the (flat) floor must repeat every 32px')
    # nodes: on furniture, below the window line, the right side of the strip, enough in front
    n_front = 0
    n_main = 0
    for (an, ax, ay, fl_) in anchors:
        in_strip = 's' in fl_.replace('bp', '')
        if ay < 40:
            errs.append('%s: y %d is above the window line (>= 40)' % (an, ay))
        if not (6 <= ax <= 314):
            errs.append('%s: x %d off the module' % (an, ax))
        ref = full if in_strip else main
        if ref.img.getpixel((ax, ay)) == bare_floor.img.getpixel((ax, ay)):
            errs.append('%s at (%d,%d) is not on anything drawn' % (an, ax, ay))
        if room_type in BALCONY_TYPES:
            if in_strip and ax > 96:
                errs.append('%s: a strip node must sit in x <= 96' % an)
            if not in_strip and ax <= 100:
                errs.append('%s: in the balcony strip — flag it "s"' % an)
        if not in_strip:
            n_main += 1
            if 'bp' not in fl_:
                n_front += 1
    if n_main < 2:
        errs.append('needs >= 2 nodes outside the balcony strip (ANCHOR_RANGES min)')
    if n_front < 2:
        errs.append('needs >= 2 FRONT nodes (reachable from the walking line) — owner round 10')
    for (lx, ly, lk, lf) in lights:
        if not (0 <= lx < W and 0 <= ly < H):
            errs.append('light fixture %s at (%d,%d) is off the module' % (lk, lx, ly))
    if os.environ.get('FLAT_REPORT'):               # audit: pieces standing on the seam with no depth
        runs_, cur_ = [], []
        for x in range(W):
            up = all(full.img.getpixel((x, y)) != bare_floor.img.getpixel((x, y)) for y in (96, 97, 98))
            fwd = any(full.img.getpixel((x, y)) != bare_floor.img.getpixel((x, y)) for y in (104, 105))
            if up and not fwd:
                cur_.append(x)
            elif cur_:
                runs_.append(cur_); cur_ = []
        if cur_:
            runs_.append(cur_)
        runs_ = [(r[0], r[-1]) for r in runs_ if len(r) >= 3]
        if runs_:
            print('FLAT %s: %s' % (name, runs_))
    bp = check_back_plane_clear(full.img, bare_floor.img, anchors)
    if bp and os.environ.get('BP_REPORT'):          # audit mode: list every module, don't stop
        print('BP %s run 1: %s' % (name, bp))
        bp = []
    if bp:
        errs.append('front furniture stands where the player would step up to a back-plane spot '
                    '(spot x, blocked column): %s' % bp)
    if errs:
        sys.exit(name + ':\n  ' + '\n  '.join(errs))
    out = os.path.join(ROOT, 'assets', 'rooms', name + '.png')
    prev = os.path.join(ROOT, 'docs', 'art_reference', 'modules')
    main.img.save(out)
    full.img.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(prev, name + '_x4.png'))
    if strip_fn is not None:
        s = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        for y in range(H):
            for x in range(W):
                p = full.img.getpixel((x, y))
                if p != main.img.getpixel((x, y)):
                    s.putpixel((x, y), p)
        s.save(os.path.join(ROOT, 'assets', 'rooms', name + '_strip.png'))
    _node_overlay(full.img, anchors, os.path.join(prev, 'nodes', name + '_nodes.png'))
    per_level = {}
    if per_run is not None:
        for lv in (2, 3):
            per_run(lv)
            mr = Canvas(seed=seed)
            build_fn(mr)
            fr = Canvas(seed=seed)
            build_fn(fr)
            if strip_fn is not None:
                strip_fn(fr)
            per_level[lv] = (mr.img, fr.img)
            for (an, ax, ay, fl_) in anchors:
                ref = fr if 's' in fl_.replace('bp', '') else mr
                if ref.img.getpixel((ax, ay)) == bare_floor.img.getpixel((ax, ay)):
                    sys.exit('%s: %s at (%d,%d) is not on anything drawn in the run-%d look' % (name, an, ax, ay, lv))
            bp = check_back_plane_clear(fr.img, bare_floor.img, anchors)
            if bp and os.environ.get('BP_REPORT'):
                print('BP %s run %d: %s' % (name, lv, bp))
                bp = []
            if bp:
                sys.exit('%s: in the run-%d look, front furniture stands where the player would step up '
                         'to a back-plane spot (spot x, blocked column): %s' % (name, lv, bp))
        per_run(1)
    runs = run_looks(name, ROOT, main.img, full.img, bare.img, bare_floor.img, floor_fn, seed, strip_fn is not None,
                     per_level=per_level)
    sheet = Image.new('RGBA', (W * 2, H * 2 * 3), (0, 0, 0, 255))
    for i, im in enumerate((full.img, runs[2], runs[3])):
        sheet.paste(im.resize((W * 2, H * 2), Image.NEAREST), (0, H * 2 * i))
    os.makedirs(os.path.join(prev, 'runs'), exist_ok=True)
    sheet.save(os.path.join(prev, 'runs', name + '_runs.png'))
    write_scene(name, room_type, anchors, strip=strip_fn is not None, lights=lights)
    print('wrote', name, '(%d nodes, %d front, %d lights)' % (len(anchors), n_front, len(lights)))
    return full


def _node_overlay(img, anchors, path):
    import os
    from PIL import ImageDraw
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im = img.convert('RGBA').resize((W * 4, H * 4), Image.NEAREST)
    d = ImageDraw.Draw(im)
    for (an, x, y, fl_) in anchors:
        c = (80, 160, 255) if 'bp' in fl_ else (255, 200, 40)
        if 's' in fl_.replace('bp', ''):
            c = (120, 230, 120)
        d.ellipse((x * 4 - 9, y * 4 - 9, x * 4 + 9, y * 4 + 9), outline=c, width=3)
        d.text((x * 4 + 11, y * 4 - 6), an.replace('anchor_', ''), fill=c)
    im.save(path)


# --- the runs: the same room, more ruined -----------------------------------------------------
# Run 2 (afternoon) and run 3 (night) show the SAME furniture in a worse state: the building has
# been rotting since the morning. Generated from the variant's own layers so every variant gets it:
#   wall  — darker, damp blooms with tide lines, cracks, peeled paper, (run 3) holes to the lath,
#           black mould, blood;
#   floor — periodic grime (identical in the floor-only export, so the doorway wedges match) plus
#           debris + stains on the room's own floor;
#   furniture — a little darker and dustier.
# Written as <name>_r2 / _r3 (.png, _floor.png, _strip.png); room._apply_run_art swaps them in.
DECAY = {2: dict(wall=0.93, furn=0.95, floor=0.95, damp=2, cracks=2, peel=1, holes=0, blood=1,
                 mould=0.0, debris=7, stains=2, grime=0.10),
         3: dict(wall=0.85, furn=0.88, floor=0.88, damp=4, cracks=5, peel=3, holes=2, blood=3,
                 mould=0.35, debris=16, stains=5, grime=0.22)}


def _mul(p, f):
    return (int(p[0] * f), int(p[1] * f), int(p[2] * f), p[3])


def _floor_grime(img, y0, level, dirt):
    """A 32px-periodic grime + darken over the floor rows (applied identically to the room art's
    visible floor and to the floor-only export)."""
    d = DECAY[level]
    px = img.load()
    w, h = img.size
    for y in range(y0, h):
        for x in range(w):
            p = px[x, y]
            if p[3] == 0:
                continue
            p = _mul(p, d['floor'])
            k = (x * 11 + y * 7 + (y * y) % 3) % 32
            if k < int(32 * d['grime']):
                p = (int(p[0] * 0.8 + dirt[0] * 0.2), int(p[1] * 0.8 + dirt[1] * 0.2), int(p[2] * 0.8 + dirt[2] * 0.2), p[3])
            px[x, y] = p


def run_looks(name, root, main_img, full_img, bare_wall_img, bare_floor_img, floor_fn, seed, has_strip,
              per_level=None):
    import os
    out = {}
    for level in (2, 3):
        d = DECAY[level]
        rng = random.Random(zlib.crc32(("%s:%d:%d" % (name, level, seed)).encode()))
        # this run's own furniture (per_run rebuilds), else run 1's
        base_main, base_full = (per_level or {}).get(level, (main_img, full_img))
        # masks from the layers: WALL = visible bare wall (y < 100), FLOOR = visible bare floor
        m = base_main.copy()
        f = base_full.copy()
        mp, fp = m.load(), f.load()
        wall_px = bare_wall_img.load()
        floor_px = bare_floor_img.load()
        is_wall = [[False] * H for _ in range(W)]
        is_floor = [[False] * H for _ in range(W)]
        mo, fo = base_main.load(), base_full.load()
        in_strip = [[fo[x, y] != mo[x, y] for y in range(H)] for x in range(W)]
        for y in range(H):
            for x in range(W):
                if y < SEAM_Y and mp[x, y] == wall_px[x, y]:
                    is_wall[x][y] = True
                elif y >= SEAM_Y and mp[x, y] == floor_px[x, y]:
                    is_floor[x][y] = True
        # base tone: walls darker, furniture a little darker (floor via the periodic grime)
        for img, pxs in ((m, mp), (f, fp)):
            for y in range(H):
                for x in range(W):
                    if is_wall[x][y] and pxs[x, y] == wall_px[x, y]:
                        pxs[x, y] = _mul(pxs[x, y], d['wall'])
                    elif not is_floor[x][y] or pxs[x, y] != floor_px[x, y]:
                        pxs[x, y] = _mul(pxs[x, y], d['furn'])
        dirt = (58, 46, 34)
        for img in (m, f):
            fl_img = img.crop((0, SEAM_Y, W, H))
            _floor_grime(fl_img, 0, level, dirt)
            fl_px = fl_img.load()
            px = img.load()
            for y in range(SEAM_Y, H):
                for x in range(W):
                    if is_floor[x][y] and px[x, y] == floor_px[x, y]:
                        px[x, y] = fl_px[x, y - SEAM_Y]
        cv = Canvas(seed=seed)
        cv.img = m
        cv.px = mp
        cf = Canvas(seed=seed)
        cf.img = f
        cf.px = fp

        def on_wall(x, y):
            return 8 <= x <= W - 9 and 6 <= y < SEAM_Y - 1 and is_wall[x][y]

        def put_both(x, y, col):
            if on_wall(x, y):
                cv.put(x, y, col)
                if not in_strip[x][y]:
                    cf.put(x, y, col)

        def floor_put(x, y, col):
            if 0 <= x < W and SEAM_Y + 2 <= y < H and is_floor[x][y]:
                cv.put(x, y, col)
                if not in_strip[x][y]:
                    cf.put(x, y, col)

        base_wall = wall_px[W // 2, 40]
        damp = _mul(base_wall, 0.74)
        tide = _mul(base_wall, 0.6)
        plaster = mix(base_wall, (206, 196, 172, 255), 0.45)
        import math

        def blob(cx0, cy0, rx, ry):
            """An irregular organic outline: radius wobbles with angle (never a clean ellipse)."""
            ph = [rng.random() * 6.28 for _ in range(3)]

            def inside(x, y):
                ang = math.atan2((y - cy0) / ry, (x - cx0) / rx)
                k = 1.0 + 0.28 * math.sin(3 * ang + ph[0]) + 0.16 * math.sin(5 * ang + ph[1]) + 0.08 * math.sin(9 * ang + ph[2])
                return (((x - cx0) / rx) ** 2 + ((y - cy0) / ry) ** 2) ** 0.5 / k
            return inside
        # damp (owner round 14 — the dotted outlines read as scribbles): a FILLED water stain,
        # brown-yellow, darkest in the tide line where it dried, a fainter older ring inside, weeping
        # a run or two down from its lowest edge; most start near the ceiling
        stain_c = mix(base_wall, (118, 96, 58, 255), 0.55)
        tide_c = mix(base_wall, (84, 64, 38, 255), 0.62)
        for _ in range(d['damp']):
            sx, sy = rng.randrange(20, W - 20), rng.randrange(6, 44)
            rx, ry = rng.randrange(10, 22), rng.randrange(6, 12)
            f_ = blob(sx, sy, rx, ry)
            low = {}
            for y in range(sy - 2 * ry, sy + 2 * ry + 1):
                for x in range(sx - 2 * rx, sx + 2 * rx + 1):
                    dd = f_(x, y)
                    if dd <= 0.84:
                        a_ = 110 if abs(dd - 0.55) < 0.06 else 62 + int(34 * dd)
                        put_both(x, y, stain_c[:3] + (a_,))
                    elif dd <= 1.0:
                        put_both(x, y, tide_c[:3] + (130 if dd < 0.94 else 80,))
                    if dd <= 1.0:
                        low[x] = max(low.get(x, -1), y)
            for _k in range(rng.randrange(1, 3)):
                if not low:
                    break
                rx_ = rng.choice(sorted(low)[len(low) // 4: 3 * len(low) // 4 + 1] or sorted(low))
                ln = rng.randrange(6, 16)
                for jj in range(ln):
                    t_ = jj / float(ln)
                    put_both(rx_, low[rx_] + 1 + jj, tide_c[:3] + (int(120 * (1 - t_)) + 20,))
                    if jj < ln // 2:
                        put_both(rx_ + 1, low[rx_] + 1 + jj, stain_c[:3] + (int(60 * (1 - t_)),))
        # cracks: jagged random walks, mostly downward, with a light lip on one side
        for _ in range(d['cracks']):
            x, y = rng.randrange(14, W - 14), rng.randrange(8, 50)
            for k in range(rng.randrange(10, 30)):
                put_both(x, y, _mul(base_wall, 0.45))
                if k % 4 == 2:
                    put_both(x + 1, y, mix(base_wall, (230, 222, 205, 255), 0.25))
                x += rng.choice((-1, 0, 1, 1))
                y += rng.choice((1, 1, 0))
        # torn wallpaper (owner round 14 — the old peeled strip read as a floating white "sock"): a
        # ragged patch torn to the plaster, the paper's pale torn core along its edge, and one corner
        # of the paper curling off the wall, its back to us, with a shadow under it
        core = mix(base_wall, (236, 230, 212, 255), 0.55)
        patch = mix(base_wall, (206, 196, 172, 255), 0.38)
        for _ in range(d['peel']):
            cx0, cy0 = rng.randrange(20, W - 20), rng.randrange(16, 80)
            f_ = blob(cx0, cy0, rng.randrange(6, 10), rng.randrange(5, 8))
            inside = set()
            for y in range(cy0 - 16, cy0 + 17):
                for x in range(cx0 - 20, cx0 + 21):
                    if f_(x, y) <= 1.0 and on_wall(x, y):
                        inside.add((x, y))
            if len(inside) < 20:
                continue
            for (x, y) in inside:
                put_both(x, y, mix(patch, (150, 132, 96, 255), 0.3) if (x * 7 + y * 3) % 9 == 0 else patch)
            for (x, y) in inside:
                for (nx, ny) in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if (nx, ny) not in inside:
                        put_both(nx, ny, core if (nx + ny) % 3 else mix(core, base_wall, 0.4))
            top_ = min(y for (x, y) in inside)
            fx = max(x for (x, y) in inside if y <= top_ + 2) - 1
            for jj in range(5):
                for ii in range(5 - jj):
                    put_both(fx - ii + 1, top_ + jj + 1, _mul(patch, 0.72))
            for jj in range(4):
                for ii in range(4 - jj):
                    put_both(fx - ii, top_ + jj, (224, 214, 190, 255) if ii else (246, 240, 224, 255))
        # holes knocked through to the lath (run 3): a dark cavity with the laths running across
        # it, a ragged broken-plaster rim all round, the top inner edge in shadow, cracks out
        for _ in range(d['holes']):
            cx0, cy0 = rng.randrange(24, W - 24), rng.randrange(22, 72)
            rx, ry = rng.randrange(5, 8), rng.randrange(5, 7)
            f_ = blob(cx0, cy0, rx, ry)
            hole = set()
            for y in range(cy0 - 2 * ry, cy0 + 2 * ry + 1):
                for x in range(cx0 - 2 * rx, cx0 + 2 * rx + 1):
                    if f_(x, y) <= 1.0:
                        hole.add((x, y))
            for (x, y) in hole:
                lath = (y - cy0) % 5 == 1                               # a thin lath now and then
                put_both(x, y, (74, 56, 40, 255) if lath else (22, 17, 14, 255))
                if (x, y - 1) not in hole:
                    put_both(x, y, (14, 10, 8, 255))                      # the top inner edge in shadow
            for (x, y) in hole:
                for (nx, ny) in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1), (x + 1, y + 1)):
                    if (nx, ny) not in hole and (nx * 3 + ny) % 4:
                        put_both(nx, ny, plaster)
            for _k in range(3):                                          # cracks radiating out
                a_ = rng.uniform(0, 6.28)
                for r_ in range(rx + 2, rx + rng.randrange(5, 10)):
                    put_both(int(cx0 + math.cos(a_) * r_), int(cy0 + math.sin(a_) * r_ * 0.8), _mul(base_wall, 0.5))
        # grime: the lower wall darkens toward the skirting (hands, damp, soot)
        for y in range(70, SEAM_Y - 6):
            a_ = int(90 * d['grime'] * (y - 70) / 24.0)
            for x in range(8, W - 8):
                if (x + y) % 2 == 0:
                    put_both(x, y, (30, 24, 18, a_))
        # black mould creeping along the top
        if d['mould'] > 0:
            for _ in range(3):
                x0 = rng.randrange(8, W - 60)
                for y in range(6, 6 + rng.randrange(10, 22)):
                    for x in range(x0, x0 + rng.randrange(30, 60)):
                        if rng.random() < d['mould'] * (1.0 - (y - 6) / 24.0):
                            put_both(x, y, (38, 46, 34, 150))
        # blood (owner round 14 — the old smear read as little red hooks): the corridor's own decals
        # (tools/art/corridor_decals.py — handprints, smears, spatter, a slide down the wall), laid
        # only on bare wall so they sit BEHIND the furniture; the night gets the worst of it
        dec_dir = os.path.join(root, 'assets', 'corridor', 'decals')
        # (smears and the slide-down read wrong in a room — a snake, a red pillar — so rooms get
        # handprints, spatter and claw marks)
        pool = ['hand_1', 'hand_2', 'spatter_1'] if level == 2 else \
            ['hand_3', 'spatter_2', 'hand_2', 'spatter_1', 'claws_1', 'hand_1']
        picks = [pool[rng.randrange(len(pool))] for _ in range(d['blood'])]
        for nm in picks:
            pth = os.path.join(dec_dir, nm + '.png')
            if not os.path.exists(pth):
                continue
            dimg = Image.open(pth).convert('RGBA')
            dw, dh = dimg.size
            dp = dimg.load()
            best_pos, best_n = None, -1
            for _try in range(14):                           # the spot showing the most of it
                if nm.startswith('slide'):
                    ox, oy = rng.randrange(8, W - dw - 8), SEAM_Y - 6 - dh
                else:
                    ox, oy = rng.randrange(8, W - dw - 8), rng.randrange(24, max(25, SEAM_Y - dh - 8))
                n_ = sum(1 for yy in range(0, dh, 2) for xx in range(0, dw, 2)
                         if dp[xx, yy][3] and on_wall(ox + xx, oy + yy))
                if n_ > best_n:
                    best_pos, best_n = (ox, oy), n_
            ox, oy = best_pos
            for yy in range(dh):
                for xx in range(dw):
                    pp = dp[xx, yy]
                    if pp[3]:
                        put_both(ox + xx, oy + yy, pp)
        # floor: stains + debris (plaster chunks, paper, glass)
        for _ in range(d['stains']):
            sx, sy = rng.randrange(10, W - 10), rng.randrange(106, 140)
            rx, ry = rng.randrange(4, 10), rng.randrange(1, 3)
            col = rng.choice([(58, 20, 18, 140), (40, 34, 26, 120)])
            for y in range(sy - ry, sy + ry + 1):
                for x in range(sx - rx, sx + rx + 1):
                    if ((x - sx) / rx) ** 2 + ((y - sy) / max(ry, 1)) ** 2 <= 1.0:
                        floor_put(x, y, col)
        for _ in range(d['debris']):
            x, y = rng.randrange(6, W - 6), rng.randrange(103, 142)
            kind = rng.random()
            if kind < 0.5:
                for (dx, dy) in ((0, 0), (1, 0), (0, -1), (2, 0)):
                    floor_put(x + dx, y + dy, plaster)
                floor_put(x + 1, y + 1, _mul(plaster, 0.6))
            elif kind < 0.8:
                for dx in range(5):
                    floor_put(x + dx, y, (214, 208, 190, 255))
                    floor_put(x + dx, y + 1, (190, 184, 166, 255))
            else:
                floor_put(x, y, (200, 220, 222, 255))
                floor_put(x + 2, y + 1, (160, 180, 184, 255))
        # write
        suffix = '_r%d' % level
        m.save(os.path.join(root, 'assets', 'rooms', name + suffix + '.png'))
        save_floor_strip(floor_fn, name, root, seed=seed, level=level)
        if has_strip:
            s = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            spx = s.load()
            for y in range(H):
                for x in range(W):
                    if base_full.getpixel((x, y)) != base_main.getpixel((x, y)):
                        spx[x, y] = fp[x, y]
            s.save(os.path.join(root, 'assets', 'rooms', name + suffix + '_strip.png'))
        out[level] = f
    return out
