"""OPENABLE FURNITURE (owner round 34 — "in This War of Mine, when you search a piece of furniture, many
pieces of furniture change appearance when you're done. The drawer opens, a door swings open").

The module art is baked, so an "opened" look is a PATCH: a small sprite sheet laid over the art once
the node on that furniture has been searched. For every opening in OPENINGS this tool reads the FINAL
module PNG (run 1, and the aged _r2 / _r3 looks, so a patch always matches the art it sits on), draws
the furniture with its drawer pulled out / door swung open in TRUE perspective, and writes

    assets/rooms/open/<art>__<anchor>[_r2|_r3].png   FRAMES frames side by side (the opening animation;
                                                      the last frame is the rest state)
    assets/rooms/open/open_meta.json                 {art: {anchor: {x, y, w, h, frames}}}

Only pixels that CHANGE are opaque, so the patch sits on the art like a decal. scripts/open_furniture.gd
plays it when loot_ui marks the anchor searched (and shows the last frame for one already searched).

Geometry. The room is drawn from a camera at the ceiling line (art y 0) over the room's middle (x 160):
a point drawn at (X, Y) on a piece's FRONT plane that is E px nearer the camera lands at
(160 + (X-160)*s, Y*s), s = (BASE+E)/BASE (pixlib.pp, relative to the front plane). A hinged door, a
drop-down oven door and a drawer front are all flat rectangles moved through that map; each is warped
by the homography of its four projected corners (warp()), so a door foreshortens, grows toward the
camera and is seen from the side it really is — no hand-drawn quads (the fridge door's old failure).

Run:  python3 tools/art/openables.py            (build_all.py does NOT call it: it reads the finished art,
                                                 so run it AFTER build_all.py)
      python3 tools/art/openables.py --preview  (also writes docs/art_reference/open_furniture.png)
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
ROOMS = os.path.join(ROOT, 'assets', 'rooms')
OUT = os.path.join(ROOMS, 'open')
VPX = 160.0
FRAMES = 3                     # opening animation frames; the last is the rest state
RUN_SUFFIX = {1: '', 2: '_r2', 3: '_r3'}


def P(X, Y, E, base):
    """Front-plane point (X, Y) brought E px nearer the camera -> art coords."""
    s = (base + E) / float(base)
    return (VPX + (X - VPX) * s, Y * s)


# --- warping ---------------------------------------------------------------------------------------
def _homography(src, dst):
    a, b = [], []
    for (x, y), (u, v) in zip(src, dst):
        a.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); b.append(u)
        a.append([0, 0, 0, x, y, 1, -v * x, -v * y]); b.append(v)
    h = np.linalg.solve(np.array(a, float), np.array(b, float))
    return np.append(h, 1.0).reshape(3, 3)


def warp(canvas, src, quad):
    """Paste `src` (a PIL RGBA image) onto `canvas` as the quad (TL, TR, BR, BL) of art coords —
    nearest-neighbour through the inverse homography, so it stays pixel art and never leaves holes."""
    w, h = src.size
    H = _homography([(0, 0), (w, 0), (w, h), (0, h)], quad)
    Hi = np.linalg.inv(H)
    xs = [p[0] for p in quad]; ys = [p[1] for p in quad]
    x0, x1 = int(math.floor(min(xs))), int(math.ceil(max(xs)))
    y0, y1 = int(math.floor(min(ys))), int(math.ceil(max(ys)))
    sp = src.load()
    cp = canvas.load()
    for y in range(max(0, y0), min(canvas.height, y1 + 1)):
        for x in range(max(0, x0), min(canvas.width, x1 + 1)):
            u, v, q = Hi @ np.array([x + 0.5, y + 0.5, 1.0])
            u, v = u / q, v / q
            if 0 <= u < w and 0 <= v < h:
                px = sp[int(u), int(v)]
                if px[3]:
                    cp[x, y] = px[:3] + (255,)


def shade(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c[:3]) + (255,)


def mean_colour(img, rect):
    x0, y0, x1, y1 = rect
    px = [img.getpixel((x, y)) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if img.getpixel((x, y))[3]]
    if not px:
        return (90, 70, 50, 255)
    return tuple(int(sum(p[i] for p in px) / len(px)) for i in range(3)) + (255,)


def poly(canvas, pts, col):
    ImageDraw.Draw(canvas).polygon([(round(x), round(y)) for (x, y) in pts], fill=col)


def line(canvas, a, b, col):
    ImageDraw.Draw(canvas).line([(round(a[0]), round(a[1])), (round(b[0]), round(b[1]))], fill=col)


def rect_fill(canvas, x0, y0, x1, y1, col):
    ImageDraw.Draw(canvas).rectangle([x0, y0, x1, y1], fill=col)


# --- interiors ---------------------------------------------------------------------------------------
def fill_cavity(canvas, rect, kind, body):
    """The dark / lit space a door or an oven front hides. `body` = the furniture's own mean colour."""
    x0, y0, x1, y1 = rect
    if kind == 'fridge':                                           # a lit white box: back wall, left wall, glass shelves
        back, wall = (176, 190, 192, 255), (214, 226, 226, 255)
        rect_fill(canvas, x0, y0, x1, y1, back)
        wl = max(2, (x1 - x0) // 8)
        rect_fill(canvas, x0, y0, x0 + wl, y1, wall)
        rect_fill(canvas, x0, y0, x1, y0 + 1, shade(back, 0.82))
        rect_fill(canvas, x0 + wl + 3, y0 + 2, x0 + wl + 8, y0 + 3, (255, 244, 200, 255))      # the light
        n = 4
        for i in range(1, n):
            sy = y0 + (y1 - y0) * i // n
            rect_fill(canvas, x0, sy - 3, x1, sy, (224, 236, 236, 255))
            line(canvas, (x0, sy), (x1, sy), (132, 148, 150, 255))
        return
    if kind == 'oven':                                             # the oven cavity: near black, two racks
        rect_fill(canvas, x0, y0, x1, y1, (34, 30, 28, 255))
        for sy in (y0 + (y1 - y0) // 3, y0 + 2 * (y1 - y0) // 3):
            line(canvas, (x0 + 1, sy), (x1 - 1, sy), (96, 92, 88, 255))
        rect_fill(canvas, x0 + 1, y1 - 1, x1 - 1, y1, (60, 54, 48, 255))
        return
    dark = shade(body, 0.22)                                       # a cupboard: the body's own wood, in shadow
    rect_fill(canvas, x0, y0, x1, y1, dark)
    rect_fill(canvas, x0, y0, x1, y0 + 1, shade(body, 0.12))
    sy = y0 + (y1 - y0) // 2
    rect_fill(canvas, x0, sy, x1, sy + 1, shade(body, 0.38))


def fridge_items(canvas, rect):
    x0, y0, x1, y1 = rect
    n = 4
    cols = [((176, 60, 52), (216, 190, 80)), ((90, 130, 70), (230, 230, 220)), ((60, 90, 150), (150, 110, 70)),
            ((220, 200, 120), (120, 150, 90))]
    for i in range(n):
        sy = y0 + (y1 - y0) * (i + 1) // n - 4
        a, b = cols[i]
        bx = x0 + 4 + (i * 5) % 9
        rect_fill(canvas, bx, sy - 7, bx + 3, sy - 1, a + (255,))
        rect_fill(canvas, bx, sy - 8, bx + 3, sy - 8, shade(a + (255,), 1.25))
        rect_fill(canvas, bx + 7, sy - 4, bx + 12, sy - 1, b + (255,))
        rect_fill(canvas, bx + 7, sy - 5, bx + 12, sy - 5, shade(b + (255,), 1.2))


# --- the three motions -------------------------------------------------------------------------------
def draw_drawer(canvas, base_img, rect, f, depth, base, contents=None, side='auto'):
    """A drawer pulled out `depth*f` px toward the camera: its front warped nearer (bigger, lower), the
    box's open top (we look down into it) and the side that faces the room's middle."""
    x0, y0, x1, y1 = rect
    X0, X1, Y0, Y1 = float(x0), float(x1 + 1), float(y0), float(y1 + 1)
    k = depth * f
    body = mean_colour(base_img, rect)
    face = base_img.crop((x0, y0, x1 + 1, y1 + 1))
    # the gap the drawer left: dark, so a rounding sliver of the old front never shows through
    rect_fill(canvas, x0, y0, x1, y1, shade(body, 0.16))
    mid = (X0 + X1) / 2.0
    if mid < VPX:                                                  # left of the middle: its RIGHT side shows
        sx = X1
    else:
        sx = X0
    side_q = [P(sx, Y0, 0, base), P(sx, Y0, k, base), P(sx, Y1, k, base), P(sx, Y1, 0, base)]
    poly(canvas, side_q, shade(body, 0.55))
    top_q = [P(X0, Y0, 0, base), P(X1, Y0, 0, base), P(X1, Y0, k, base), P(X0, Y0, k, base)]
    poly(canvas, top_q, shade(body, 0.20))                          # the inside of the box
    a, b = P(X0, Y0, 0, base), P(X1, Y0, 0, base)
    line(canvas, a, b, shade(body, 0.38))                           # the back wall's lit lip
    if contents:
        for (cu0, cu1, cv, col) in contents:                        # (u0, u1) across, v 0..1 back→front, colour
            pa = P(X0 + (X1 - X0) * cu0, Y0, k * cv, base)
            pb = P(X0 + (X1 - X0) * cu1, Y0, k * cv, base)
            pc = P(X0 + (X1 - X0) * cu1, Y0, k * min(1.0, cv + 0.34), base)
            pd = P(X0 + (X1 - X0) * cu0, Y0, k * min(1.0, cv + 0.34), base)
            poly(canvas, [pa, pb, pc, pd], col)
            line(canvas, pa, pb, shade(col, 1.25))
    quad = [P(X0, Y0, k, base), P(X1, Y0, k, base), P(X1, Y1, k, base), P(X0, Y1, k, base)]
    warp(canvas, face, quad)
    ImageDraw.Draw(canvas).line([(round(quad[3][0]), round(quad[3][1]) + 1), (round(quad[2][0]), round(quad[2][1]) + 1)],
                                fill=(20, 14, 10, 150))             # its shadow on what's below


def draw_door_h(canvas, base_img, rect, f, max_angle, base, hinge='l', cavity='dark', items=None, inner=None):
    """A hinged door swung `max_angle*f` degrees toward the camera about its left / right edge."""
    x0, y0, x1, y1 = rect
    X0, X1, Y0, Y1 = float(x0), float(x1 + 1), float(y0), float(y1 + 1)
    w = X1 - X0
    body = mean_colour(base_img, rect)
    face = base_img.crop((x0, y0, x1 + 1, y1 + 1))
    fill_cavity(canvas, (x0, y0, x1, y1), cavity, body)
    if items:
        items(canvas, (x0, y0, x1, y1))
    ang = math.radians(max_angle * f)
    e = w * math.sin(ang)
    dx = w * math.cos(ang)
    if hinge == 'l':
        fx = X0 + dx
        quad = [P(X0, Y0, 0, base), P(fx, Y0, e, base), P(fx, Y1, e, base), P(X0, Y1, 0, base)]
    else:
        fx = X1 - dx
        quad = [P(fx, Y0, e, base), P(X1, Y0, 0, base), P(X1, Y1, 0, base), P(fx, Y1, e, base)]
    warp(canvas, face, quad)
    free = quad[1] if hinge == 'l' else quad[0]                      # a hint of the door's edge, thickness
    freeb = quad[2] if hinge == 'l' else quad[3]
    line(canvas, free, freeb, shade(body, 0.45))


def draw_door_drop(canvas, base_img, rect, f, max_angle, base, cavity='oven'):
    """A drop-down door (an oven) hinged on its bottom edge, lowered `max_angle*f` degrees from upright."""
    x0, y0, x1, y1 = rect
    X0, X1, Y0, Y1 = float(x0), float(x1 + 1), float(y0), float(y1 + 1)
    h = Y1 - Y0
    body = mean_colour(base_img, rect)
    face = base_img.crop((x0, y0, x1 + 1, y1 + 1))
    fill_cavity(canvas, (x0 + 1, y0, x1 - 1, y1), cavity, body)
    ang = math.radians(max_angle * f)
    top_y = Y1 - h * math.cos(ang)
    e = h * math.sin(ang)
    quad = [P(X0, top_y, e, base), P(X1, top_y, e, base), P(X1, Y1, 0, base), P(X0, Y1, 0, base)]
    # the front's own frame stays; only what the door covered is replaced
    warp(canvas, face, quad)
    line(canvas, quad[0], quad[1], shade(body, 0.5))


# --- the openings --------------------------------------------------------------------------------------
# art -> anchor -> how it opens. Rects are the furniture's front in module-local art px (inclusive).
OPENINGS = {
    'living_room': {
        'anchor_right_chair': dict(kind='drawer', rect=(264, 78, 298, 87), depth=11, base=108,
                                   contents=[(0.12, 0.42, 0.25, (106, 138, 160, 255)), (0.5, 0.82, 0.45, (170, 128, 150, 255))]),
    },
    'bedroom': {
        'anchor_bedside': dict(kind='drawer', rect=(53, 89, 74, 97), depth=9, base=108,
                               contents=[(0.15, 0.5, 0.3, (190, 176, 150, 255)), (0.58, 0.85, 0.5, (130, 90, 70, 255))]),
        'anchor_wall_right_lower': dict(kind='drawer', rect=(279, 90, 310, 101), depth=12, base=108,
                                        contents=[(0.1, 0.5, 0.2, (96, 110, 140, 255)), (0.45, 0.9, 0.55, (180, 90, 80, 255))]),
        'anchor_floor_underbed': dict(kind='drawer', rect=(140, 108, 165, 114), depth=9, base=112,
                                      contents=[(0.1, 0.5, 0.3, (170, 150, 120, 255)), (0.55, 0.9, 0.5, (110, 100, 130, 255))]),
    },
    'study': {
        'anchor_study_desk_drawer': dict(kind='drawer', rect=(199, 96, 218, 105), depth=8, base=108,
                                         contents=[(0.1, 0.55, 0.25, (214, 206, 180, 255)), (0.4, 0.9, 0.5, (190, 180, 150, 255))]),
        'anchor_study_filing': dict(kind='drawer', rect=(279, 67, 308, 77), depth=11, base=108,
                                    contents=[(0.1, 0.9, 0.2, (218, 208, 178, 255)), (0.15, 0.85, 0.55, (200, 190, 160, 255))]),
    },
    'kitchen': {
        'anchor_centre_fridge': dict(kind='door_h', rect=(7, 34, 37, 103), angle=33, base=106, hinge='l',
                                     cavity='fridge', items=fridge_items),
        'anchor_centre_oven': dict(kind='door_drop', rect=(157, 87, 183, 105), angle=72, base=106),
    },
    'dining_room': {
        'anchor_right_upperdrawers': dict(kind='drawer', rect=(279, 67, 294, 74), depth=9, base=108,
                                          contents=[(0.15, 0.55, 0.3, (214, 206, 190, 255)), (0.6, 0.9, 0.5, (150, 120, 90, 255))]),
        'anchor_right_lowerdrawers': dict(kind='door_h', rect=(279, 76, 294, 101), angle=100, base=108, hinge='l',
                                          cavity='dark'),
    },
}


def render(art_img, spec, f):
    cv = art_img.copy()
    kind = spec['kind']
    if kind == 'drawer':
        draw_drawer(cv, art_img, spec['rect'], f, spec['depth'], spec['base'], spec.get('contents'))
    elif kind == 'door_h':
        draw_door_h(cv, art_img, spec['rect'], f, spec['angle'], spec['base'], spec.get('hinge', 'l'),
                    spec.get('cavity', 'dark'), spec.get('items'))
    elif kind == 'door_drop':
        draw_door_drop(cv, art_img, spec['rect'], f, spec['angle'], spec['base'])
    return cv


def build_one(art_name, run, anchor, spec):
    path = os.path.join(ROOMS, art_name + RUN_SUFFIX[run] + '.png')
    if not os.path.exists(path):
        return None
    base = Image.open(path).convert('RGBA')
    fracs = [(i + 1) / float(FRAMES) for i in range(FRAMES)]
    frames = [render(base, spec, f) for f in fracs]
    bp = base.load()
    x0 = y0 = 10 ** 6
    x1 = y1 = -1
    for fr in frames:
        fp = fr.load()
        for y in range(base.height):
            for x in range(base.width):
                if fp[x, y] != bp[x, y]:
                    x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
    if x1 < 0:
        raise SystemExit('%s %s: the opened look changes nothing' % (art_name, anchor))
    if x0 < 0 or y0 < 0 or x1 >= base.width or y1 >= base.height:
        raise SystemExit('%s %s: bounds %s' % (art_name, anchor, (x0, y0, x1, y1)))
    w, h = x1 - x0 + 1, y1 - y0 + 1
    sheet = Image.new('RGBA', (w * FRAMES, h), (0, 0, 0, 0))
    sp = sheet.load()
    for k, fr in enumerate(frames):
        fp = fr.load()
        for y in range(h):
            for x in range(w):
                if fp[x0 + x, y0 + y] != bp[x0 + x, y0 + y]:
                    sp[k * w + x, y] = fp[x0 + x, y0 + y]
    name = '%s__%s%s.png' % (art_name, anchor, RUN_SUFFIX[run])
    sheet.save(os.path.join(OUT, name))
    return {'x': x0, 'y': y0, 'w': w, 'h': h, 'frames': FRAMES}, frames[-1], base


def main():
    global OUT
    check = '--check' in sys.argv
    real_out = OUT
    if check:
        import tempfile
        OUT = tempfile.mkdtemp(prefix='openables_')
    os.makedirs(OUT, exist_ok=True)
    meta = {}
    preview = []
    for art, anchors in OPENINGS.items():
        for anchor, spec in anchors.items():
            for run in (1, 2, 3):
                r = build_one(art, run, anchor, spec)
                if r is None:
                    continue
                m, last, base = r
                if run == 1:
                    meta.setdefault(art, {})[anchor] = m
                    preview.append((art + ' ' + anchor, base, last, m))
    with open(os.path.join(OUT, 'open_meta.json'), 'w') as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)
    if check:
        bad = []
        for fn in sorted(set(os.listdir(OUT)) | set(os.listdir(real_out))):
            if fn.endswith('.import'):
                continue
            a, b = os.path.join(OUT, fn), os.path.join(real_out, fn)
            if not (os.path.exists(a) and os.path.exists(b)) or open(a, 'rb').read() != open(b, 'rb').read():
                bad.append(fn)
        if bad:
            print('OPENABLES: stale or missing — run: python3 tools/art/openables.py  (%s)' % ', '.join(bad[:6]))
            sys.exit(1)
        print('openables current (%d files)' % len(os.listdir(OUT)))
        return
    print('wrote %d openings to %s' % (sum(len(v) for v in meta.values()), OUT))
    if '--preview' in sys.argv:
        sheet_preview(preview)


def sheet_preview(items, zoom=4):
    cells = []
    for (title, base, last, m) in items:
        pad = 16
        x0, y0 = max(0, m['x'] - pad), max(0, m['y'] - pad)
        x1, y1 = min(320, m['x'] + m['w'] + pad), min(144, m['y'] + m['h'] + pad)
        a = base.crop((x0, y0, x1, y1)).resize(((x1 - x0) * zoom, (y1 - y0) * zoom), Image.NEAREST)
        b = last.crop((x0, y0, x1, y1)).resize(((x1 - x0) * zoom, (y1 - y0) * zoom), Image.NEAREST)
        cell = Image.new('RGBA', (a.width * 2 + 8, a.height + 14), (24, 24, 26, 255))
        cell.paste(a, (0, 14)); cell.paste(b, (a.width + 8, 14))
        ImageDraw.Draw(cell).text((2, 1), title, fill=(230, 220, 190))
        cells.append(cell)
    cols = 2
    rows = (len(cells) + cols - 1) // cols
    cw = max(c.width for c in cells); ch = max(c.height for c in cells)
    sheet = Image.new('RGBA', (cols * (cw + 6) + 6, rows * (ch + 6) + 6), (14, 14, 16, 255))
    for i, c in enumerate(cells):
        sheet.paste(c, (6 + (i % cols) * (cw + 6), 6 + (i // cols) * (ch + 6)))
    out = os.path.join(ROOT, 'docs', 'art_reference', 'open_furniture.png')
    sheet.convert('RGB').save(out)
    print('wrote', out)


if __name__ == '__main__':
    main()
