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
import zlib

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
    main = Canvas(seed=seed)
    build_fn(main)
    full = Canvas(seed=seed)
    build_fn(full)
    if strip_fn is not None:
        strip_fn(full)
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
        errs.append('the floor must repeat every 32px')
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
    write_scene(name, room_type, anchors, strip=strip_fn is not None)
    print('wrote', name, '(%d nodes, %d front)' % (len(anchors), n_front))
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
        # damp blooms: a soft stipple, a broken tide line, heavier toward the top edge
        for _ in range(d['damp']):
            sx, sy = rng.randrange(20, W - 20), rng.randrange(8, 56)
            rx, ry = rng.randrange(10, 24), rng.randrange(7, 14)
            f_ = blob(sx, sy, rx, ry)
            for y in range(sy - 2 * ry, sy + 2 * ry + 1):
                for x in range(sx - 2 * rx, sx + 2 * rx + 1):
                    dd = f_(x, y)
                    if dd <= 0.86:
                        if (x * 3 + y * 5) % 4 == 0 or (dd < 0.5 and (x + y) % 2 == 0):
                            put_both(x, y, (damp[0], damp[1], damp[2], 90))
                    elif dd <= 1.0 and (x + 2 * y) % 3 != 0:
                        put_both(x, y, (tide[0], tide[1], tide[2], 110))
        # cracks: jagged random walks, mostly downward, with a light lip on one side
        for _ in range(d['cracks']):
            x, y = rng.randrange(14, W - 14), rng.randrange(8, 50)
            for k in range(rng.randrange(10, 30)):
                put_both(x, y, _mul(base_wall, 0.45))
                if k % 4 == 2:
                    put_both(x + 1, y, mix(base_wall, (230, 222, 205, 255), 0.25))
                x += rng.choice((-1, 0, 1, 1))
                y += rng.choice((1, 1, 0))
        # peeled paper: a strip curling off, the plaster behind a paler wall tone
        for _ in range(d['peel']):
            x0, y0 = rng.randrange(16, W - 30), rng.randrange(14, 66)
            w, h = rng.randrange(5, 9), rng.randrange(10, 18)
            for y in range(y0, y0 + h):
                shrink = (y - y0) // 3
                for x in range(x0 + shrink // 2, x0 + w - shrink // 2):
                    put_both(x, y, plaster)
            for k in range(h - 4):                                  # the curling flap, in shadow
                put_both(x0 + w + k // 5, y0 + k, _mul(base_wall, 0.62))
                put_both(x0 + w + 1 + k // 5, y0 + k, _mul(base_wall, 0.8))
        # holes knocked through to the lath (run 3): ragged, dark, the lath strips showing
        for _ in range(d['holes']):
            cx0, cy0 = rng.randrange(24, W - 24), rng.randrange(20, 70)
            rx, ry = rng.randrange(5, 9), rng.randrange(4, 7)
            f_ = blob(cx0, cy0, rx, ry)
            for y in range(cy0 - 2 * ry, cy0 + 2 * ry + 1):
                for x in range(cx0 - 2 * rx, cx0 + 2 * rx + 1):
                    dd = f_(x, y)
                    if dd <= 1.0:
                        put_both(x, y, (38, 29, 23, 255) if (y - cy0) % 3 else (104, 76, 50, 255))
                    elif dd <= 1.3 and (x + y) % 3:
                        put_both(x, y, plaster)
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
        # blood: a smear with drips, (run 3) a handprint + a splatter
        blood = (74, 29, 27, 170)
        for i in range(d['blood']):
            x0, y0 = rng.randrange(20, W - 30), rng.randrange(30, 80)
            ln = rng.randrange(8, 20)
            for k in range(ln):
                put_both(x0 + k, y0 + k // 4, blood)
                put_both(x0 + k, y0 + 1 + k // 4, blood)
            for k in range(rng.randrange(2, 5)):
                dx = x0 + rng.randrange(0, ln)
                for y in range(y0 + 2, y0 + 2 + rng.randrange(4, 16)):
                    put_both(dx, y, blood)
            if level == 3 and i == 0:
                hx, hy = rng.randrange(24, W - 24), rng.randrange(36, 70)
                for (dx, dy) in ((0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1), (3, 1), (0, 2), (1, 2), (2, 2), (3, 2), (1, 3), (2, 3)):
                    put_both(hx + dx, hy + dy, blood)
                for fx in range(4):
                    for fy in range(1, 4 + (fx % 2)):
                        put_both(hx + fx, hy - fy, blood)
                put_both(hx - 1, hy + 1, blood); put_both(hx - 2, hy, blood)
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
        fl = Canvas(seed=seed)
        floor_fn(fl)
        strip = fl.img.crop((0, SEAM_Y, W, H))
        _floor_grime(strip, 0, level, dirt)
        strip.save(os.path.join(root, 'assets', 'rooms', name + suffix + '_floor.png'))
        if has_strip:
            s = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            spx = s.load()
            for y in range(H):
                for x in range(W):
                    if base_full.getpixel((x, y)) != base_main.getpixel((x, y)):
                        spx[x, y] = fp[x, y]
            s.save(os.path.join(root, 'assets', 'rooms', name + suffix + '_strip.png'))
        if not floor_is_periodic(strip):
            raise SystemExit('%s%s: the run floor must repeat every 32px' % (name, suffix))
        out[level] = f
    return out
