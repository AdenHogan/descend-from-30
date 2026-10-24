"""OPENABLE FURNITURE (owner round 34 — "in This War of Mine, when you search a piece of furniture, many
pieces of furniture change appearance when you're done. The drawer opens, a door swings open").

The module art is baked, so an "opened" look is a PATCH: a small sprite sheet laid over the art once
the node on that furniture has been searched. For every opening in OPENINGS this tool reads the FINAL
module PNG (run 1, and the aged _r2 / _r3 looks, so a patch always matches the art it sits on), draws
the furniture with its drawer pulled out / door swung open in TRUE perspective, and writes

    assets/rooms/open/<art>__<anchor>[_r2|_r3].png   FRAMES frames side by side (the opening animation;
                                                      the last frame is the rest state)
    assets/rooms/open/open_meta.json                 {art: {anchor: {x, y, w, h, frames, kind}}}

KINDS (round 45c — every one plays the moment the player PRESSES interact on the node, scripts/interactable.gd on_search_begin):
    drawer      pulled out toward the camera, its open top and side shown          door_h     a hinged door swung open on its edge
    door_drop   an oven-style door lowered on its bottom hinge                     lid        a lid lifted on its back hinge
    topple      a small standing thing (glass, jar, candlestick) tips over         shift      a small thing shoved / slid / knocked off
    screen_off  a screen collapses to a line, a dot, dead glass

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

HERE_ = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE_)
import wardrobe_inside  # noqa: E402

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
def _wardrobe_interior(canvas, rect, body):
    """The inside of a wardrobe (tools/art/wardrobe_inside.py - shared with the planned wardrobe piece)."""
    px = canvas.load()
    x0, y0, x1, y1 = rect

    def put(x, y, col):
        if 0 <= x < canvas.width and 0 <= y < canvas.height:
            px[x, y] = col
    wardrobe_inside.draw(put, rect, body)


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
    if kind == 'lit':                                              # a microwave: a pale, warm-lit box with a turntable
        rect_fill(canvas, x0, y0, x1, y1, (226, 214, 168, 255))
        rect_fill(canvas, x0, y0, x1, y0 + 1, (196, 182, 138, 255))
        rect_fill(canvas, x0, y0, x0 + 1, y1, (200, 188, 144, 255))
        rect_fill(canvas, x0 + 2, y1 - 1, x1 - 2, y1, (150, 138, 104, 255))
        return
    if kind == 'wardrobe':
        _wardrobe_interior(canvas, rect, body)
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


# --- things that move without opening (owner round 45c: "search a table and a glass falls over… search a computer and the screen turns off") ---
def _dist(a, b):
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))


def object_mask(base_img, rect, bg=None, thr=36, fg=None, ref=None):
    """The pixels of a small object inside `rect`. Two ways to say which: `fg` = the colours the object is made of (a pixel is the
    object when it is within `thr` of one of them — for a thing against a busy backdrop), or `bg` = a list of sample points (x, y)
    or colours (r, g, b) the backdrop is made of (default: the rect's four corners; a pixel is the object when it differs from
    ALL of them by more than `thr`)."""
    x0, y0, x1, y1 = rect
    det = (ref or base_img).load()                                  # the object is FOUND on the first look (run looks age the colours)…
    px = base_img.load()                                            # …and TAKEN from the art being patched
    if fg:
        keys = [tuple(c[:3]) for c in fg]
        mask = {}
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                c = det[x, y]
                if c[3] and any(_dist(c, k) <= thr for k in keys):
                    mask[(x, y)] = px[x, y]
        return mask
    refs = []
    for p in (bg or [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]):
        refs.append(tuple(det[p[0], p[1]][:3]) if len(p) == 2 else tuple(p[:3]))
    mask = {}
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = det[x, y]
            if c[3] and all(_dist(c, r) > thr for r in refs):
                mask[(x, y)] = px[x, y]
    return mask


def fill_vacated(canvas, base_img, mask, reach=14):
    """Where an object stood, show what was behind it: the nearest backdrop pixel along the same row (a wall, a table top)."""
    bp = base_img.load()
    cp = canvas.load()
    for (x, y) in mask:
        best = None
        for d in range(1, reach + 1):
            for sx in (x - d, x + d):
                if 0 <= sx < base_img.width and (sx, y) not in mask:
                    best = bp[sx, y]
                    break
            if best is not None:
                break
        if best is None:                                            # a tall thin object: look along the column
            for d in range(1, reach + 1):
                for sy in (y + d, y - d):
                    if 0 <= sy < base_img.height and (x, sy) not in mask:
                        best = bp[x, sy]
                        break
                if best is not None:
                    break
        if best is not None:
            cp[x, y] = best[:3] + (255,)


def _paint_moved(canvas, mask, dx, dy, deg, pivot):
    """The object, turned `deg` degrees (clockwise on screen) about `pivot` and moved by (dx, dy). Sampled through the inverse transform
    with four sub-pixel taps (any hit paints), so a 1 px stick — a candlestick, a lamp's stem — stays one piece through a tilt instead of
    breaking into dots; at an exact multiple of 90 degrees the taps all agree and nothing grows."""
    if not mask:
        return
    th = math.radians(deg)
    c, s = math.cos(th), math.sin(th)
    px_, py_ = pivot
    xs = [p[0] for p in mask]; ys = [p[1] for p in mask]
    reach = int(math.ceil(max(max(xs) - min(xs), max(ys) - min(ys)) + 2))
    cp = canvas.load()
    taps = [(0.5, 0.5)] if abs(deg) % 90.0 < 1e-6 else [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)]
    for y in range(max(0, int(py_ + dy) - reach - 2), min(canvas.height, int(py_ + dy) + reach + 3)):
        for x in range(max(0, int(px_ + dx) - reach - 2), min(canvas.width, int(px_ + dx) + reach + 3)):
            hit = None
            for (tx, ty) in taps:
                ux, uy = (x + tx) - dx - px_, (y + ty) - dy - py_
                sx = ux * c + uy * s + px_                                # the inverse turn
                sy = -ux * s + uy * c + py_
                col = mask.get((int(math.floor(sx)), int(math.floor(sy))))
                if col is not None:
                    hit = col
                    break
            if hit is not None:
                cp[x, y] = hit[:3] + (255,)


def draw_topple(canvas, base_img, rect, f, direction, bg=None, thr=36, pivot_pad=0, fg=None, ref=None, front=None):
    """A small thing standing on a surface tips over (a glass, a jar, a candlestick) — hinged on its bottom corner on the side it falls toward.
    `front` = a rect holding something that stands NEARER than the tipping thing (a rocking horse in front of a tower of blocks): whatever in it is not `bg` is laid back over the fall."""
    mask = object_mask(base_img, rect, bg, thr, fg, ref)
    if not mask:
        return
    fill_vacated(canvas, base_img, mask)
    xs = [p[0] for p in mask]; ys = [p[1] for p in mask]
    by = max(ys) + 1.0 + pivot_pad
    if direction == 'r':
        pivot, sign = (max(xs) + 1.0, by), 1.0
    else:
        pivot, sign = (float(min(xs)), by), -1.0
    deg = sign * 90.0 * (f ** 1.6)
    _paint_moved(canvas, mask, 0.0, 0.0, deg, pivot)
    if front:
        cp, bp = canvas.load(), base_img.load()
        for (x, y), col in object_mask(base_img, front, bg, thr, None, ref).items():
            cp[x, y] = col


def draw_shift(canvas, base_img, rect, f, dx, dy, deg=0.0, bg=None, thr=36, hump=0.0, fg=None, ref=None, path=None, idx=0, pivot='center'):
    """A small thing shoved, slid, dropped or SWUNG. Either one move over the animation — by (dx, dy), turned `deg`, with a `hump` that
    lifts it on the way (something knocked off a shelf) — or, with `path`, an explicit (dx, dy, deg) for every frame (a hanging garment
    swinging, a rocker rocking: the last entry is where it rests). `pivot` is what it turns about: its 'center', its 'top' (hung from a
    rail) or its 'bottom' (stood on the floor)."""
    mask = object_mask(base_img, rect, bg, thr, fg, ref)
    if not mask:
        return
    fill_vacated(canvas, base_img, mask)
    xs = [p[0] for p in mask]; ys = [p[1] for p in mask]
    cx = (min(xs) + max(xs) + 1) / 2.0
    cy = {'top': float(min(ys)), 'bottom': float(max(ys) + 1)}.get(pivot, (min(ys) + max(ys) + 1) / 2.0)
    if path:
        mdx, mdy, mdeg = path[max(0, min(idx, len(path) - 1))]
        _paint_moved(canvas, mask, round(mdx), round(mdy), mdeg, (cx, cy))
        return
    lift = -hump * 4.0 * f * (1.0 - f)
    _paint_moved(canvas, mask, round(dx * f), round(dy * f + lift), deg * f, (cx, cy))


def draw_screen_off(canvas, base_img, rect, f, glass=(14, 18, 20)):
    """A screen going off, old-set style: the picture collapses to a bright band, a line, a dot — and sits dead (4 frames: f = .25 .5 .75 1)."""
    x0, y0, x1, y1 = rect
    w, h = x1 - x0 + 1, y1 - y0 + 1
    dark = tuple(glass) + (255,)
    rect_fill(canvas, x0, y0, x1, y1, dark)
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    if f <= 0.26:                                                    # the picture squashes toward the middle, over-bright
        face = base_img.crop((x0, y0, x1 + 1, y1 + 1))
        bh = max(2, int(round(h * 0.34)))
        sq = face.resize((w, bh), Image.NEAREST)
        sp = sq.load()
        for y in range(bh):
            for x in range(w):
                p = sp[x, y]
                sp[x, y] = tuple(min(255, int(p[i] + (255 - p[i]) * 0.45)) for i in range(3)) + (255,)
        canvas.paste(sq, (x0, int(round(cy - bh / 2.0))))
    elif f <= 0.51:                                                  # a thin white line
        yy = int(round(cy))
        rect_fill(canvas, x0, yy, x1, yy, (232, 244, 240, 255))
        if h > 5:
            rect_fill(canvas, x0 + w // 5, yy - 1, x1 - w // 5, yy - 1, (92, 120, 116, 255))
            rect_fill(canvas, x0 + w // 5, yy + 1, x1 - w // 5, yy + 1, (92, 120, 116, 255))
    elif f <= 0.76:                                                  # a dot that fades
        xx, yy = int(round(cx)), int(round(cy))
        rect_fill(canvas, xx - 1, yy, xx, yy, (226, 240, 236, 255))
        rect_fill(canvas, xx - 2, yy, xx - 2, yy, (70, 92, 90, 255))
        rect_fill(canvas, xx + 1, yy, xx + 1, yy, (70, 92, 90, 255))
    else:                                                            # dead glass: a faint diagonal sheen
        sheen = tuple(min(255, v + 16) for v in glass) + (255,)
        for y in range(h):
            for x in range(w):
                if 0 <= (x - y * 1.2 - w * 0.3) % (w * 0.9) < max(2, w * 0.12):
                    canvas.putpixel((x0 + x, y0 + y), sheen)


def draw_lid(canvas, base_img, rect, f, rise, base, items=None, inside=None, under=None):
    """A lid lifted on its back hinge (a chest, a toolbox, a piano, a bin): the top squashes, then the underside stands up over the back edge."""
    x0, y0, x1, y1 = rect
    X0, X1 = x0, x1 + 1
    h = y1 - y0 + 1
    body = mean_colour(base_img, rect)
    face = base_img.crop((x0, y0, x1 + 1, y1 + 1))
    rect_fill(canvas, x0 + 1, y0, x1 - 1, y1, tuple(inside) + (255,) if inside else shade(body, 0.16))   # the open top: dark (or its own lining)
    line(canvas, (x0 + 1, y0), (x1 - 1, y0), shade(body, 0.42))                  # the back wall's lit lip
    if items:
        items(canvas, (x0, y0, x1, y1))
    a = math.radians(84.0 * f)
    fy = y0 + h * math.cos(a) - rise * math.sin(a)                                # the lid's front edge
    if fy >= y0 + 1:                                                              # still over the box: the top, squashed
        quad = [(X0, y0), (X1, y0), (X1, fy), (X0, fy)]
        warp(canvas, face, quad)
    else:                                                                         # stood up behind: the underside, plain wood
        under = tuple(under) + (255,) if under else shade(body, 0.62)
        poly(canvas, [(X0 + 1, fy), (X1 - 1, fy), (X1, y0 + 1), (X0, y0 + 1)], under)
        line(canvas, (X0 + 1, fy), (X1 - 1, fy), shade(body, 0.95))              # its edge catches the light
        line(canvas, (X0, y0 + 1), (X1, y0 + 1), shade(body, 0.4))               # the hinge line


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
    # --- the other variants (owner round 45: "more furniture items need to open up when interacted with") — rects read off the finished art
    'bedroom_b': {
        'anchor_bedroom_desk_drawer': dict(kind='drawer', rect=(14, 99, 20, 107), depth=8, base=108,
                                           contents=[(0.1, 0.5, 0.3, (200, 190, 160, 255)), (0.55, 0.9, 0.5, (120, 90, 80, 255))]),
    },
    'kitchen_c': {
        'anchor_kitchen_dresser_drawer': dict(kind='drawer', rect=(10, 91, 40, 99), depth=10, base=108,
                                              contents=[(0.08, 0.45, 0.3, (206, 200, 186, 255)), (0.5, 0.92, 0.45, (150, 120, 90, 255))]),
    },
    'bedroom_c': {
        'anchor_bedroom_pill_cabinet': dict(kind='drawer', rect=(283, 87, 300, 93), depth=9, base=108,
                                            contents=[(0.1, 0.5, 0.3, (214, 206, 190, 255)), (0.55, 0.9, 0.5, (96, 140, 150, 255))]),
    },
    'dining_room_b': {
        'anchor_right_lowerdrawers': dict(kind='drawer', rect=(252, 96, 307, 103), depth=9, base=108,
                                          contents=[(0.08, 0.5, 0.3, (214, 206, 190, 255)), (0.55, 0.92, 0.5, (170, 130, 90, 255))]),
    },
    'living_room_d': {
        'anchor_living_cabinet_cupboard': dict(kind='drawer', rect=(267, 98, 299, 102), depth=8, base=108,
                                               contents=[(0.1, 0.5, 0.3, (200, 190, 170, 255)), (0.55, 0.9, 0.5, (140, 100, 90, 255))]),
    },
    'study_b': {
        'anchor_study_desk_drawer': dict(kind='drawer', rect=(104, 93, 117, 102), depth=8, base=108,
                                         contents=[(0.1, 0.55, 0.25, (220, 214, 190, 255)), (0.4, 0.9, 0.5, (190, 184, 160, 255))]),
    },
    'dining_room_c': {
        'anchor_right_upperdrawers': dict(kind='drawer', rect=(258, 84, 308, 92), depth=10, base=108,
                                          contents=[(0.08, 0.5, 0.3, (214, 206, 190, 255)), (0.55, 0.92, 0.5, (150, 120, 90, 255))]),
    },
    'dining_room': {
        'anchor_right_upperdrawers': dict(kind='drawer', rect=(279, 67, 294, 74), depth=9, base=108,
                                          contents=[(0.15, 0.55, 0.3, (214, 206, 190, 255)), (0.6, 0.9, 0.5, (150, 120, 90, 255))]),
        'anchor_right_lowerdrawers': dict(kind='door_h', rect=(279, 76, 294, 101), angle=100, base=108, hinge='l',
                                          cavity='dark'),
    },
}


# --- round 45c: "every node, if it makes logical sense, should have an animation" -----------------------------------------------------
# Everything below plays when the player PRESSES interact on the node. Nodes with no entry here still react (a puff + a sound of what
# they are made of: scripts/node_reaction.gd). Rects are module-local art px (inclusive), read off the finished art with the grid crops.
SCREEN = (14, 18, 20)


def pizza_items(canvas, rect):
    """What a pizza box holds: a round pizza, a few toppings (the box's open top, seen from above)."""
    x0, y0, x1, y1 = rect
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    ImageDraw.Draw(canvas).ellipse([cx - 7, cy - 3, cx + 7, cy + 3], fill=(214, 148, 72, 255))
    ImageDraw.Draw(canvas).ellipse([cx - 5, cy - 2, cx + 5, cy + 2], fill=(220, 90, 56, 255))
    for (dx, dy) in ((-3, -1), (1, 0), (3, 1), (-1, 1)):
        canvas.putpixel((cx + dx, cy + dy), (246, 214, 110, 255))
def clock_items(canvas, rect):
    """A grandfather clock's case: the pendulum hanging in the dark, its brass bob."""
    x0, y0, x1, y1 = rect
    mx = (x0 + x1) // 2
    rect_fill(canvas, mx, y0 + 3, mx, y1 - 14, (176, 148, 86, 255))
    rect_fill(canvas, mx - 2, y1 - 14, mx + 2, y1 - 10, (196, 164, 84, 255))
    rect_fill(canvas, mx - 2, y1 - 10, mx + 2, y1 - 10, (120, 98, 52, 255))


def plates_items(canvas, rect):
    """A china cabinet's insides: two shelves of plates stood on edge, a few cups."""
    x0, y0, x1, y1 = rect
    for sy in (y0 + (y1 - y0) // 3, y0 + 2 * (y1 - y0) // 3):
        rect_fill(canvas, x0, sy + 3, x1, sy + 3, (120, 82, 56, 255))
        px_ = x0 + 1
        while px_ + 2 <= x1:
            rect_fill(canvas, px_, sy - 3, px_ + 1, sy + 2, (224, 220, 206, 255))
            rect_fill(canvas, px_, sy - 1, px_ + 1, sy, (96, 132, 176, 255))
            px_ += 4


OPENINGS_45C = {
    # ----- kitchens: ovens, a cooker, a microwave, a pizza box, things on tables -----
    'kitchen_b': {
        'anchor_centre_oven': dict(kind='door_drop', rect=(102, 90, 122, 106), angle=70, base=106),
        'anchor_kitchen_formica_table': dict(kind='shift', rect=(205, 87, 213, 91), dx=9, dy=0, deg=32, hump=3,
                                             bg=[(205, 87), (213, 87), (205, 91)]),
        'anchor_kitchen_larder': dict(kind='topple', rect=(286, 78, 291, 84), dir='r', bg=[(286, 78), (291, 78), (286, 84)]),
    },
    'kitchen_d': {
        'anchor_kitchen_microwave': dict(kind='door_h', rect=(193, 63, 210, 76), angle=58, base=108, hinge='l', cavity='lit'),
        'anchor_kitchen_pizza_boxes': dict(kind='lid', rect=(244, 93, 262, 102), rise=8, base=108, inside=(168, 126, 78), items=pizza_items),
    },
    'kitchen_e': {
        'anchor_centre_oven': dict(kind='door_drop', rect=(204, 91, 222, 106), angle=70, base=106),
    },
    # ----- screens: the picture collapses, a dot, dead glass (a live static / TV under it goes dark too) -----
    'bedroom_b': {
        'anchor_bedroom_desk': dict(kind='screen_off', rect=(29, 62, 44, 74), glass=SCREEN),
    },
    'study_b': {
        'anchor_centre_desk': dict(kind='screen_off', rect=(131, 59, 144, 70), glass=SCREEN),
    },
    'living_room_b': {
        'anchor_centre_sofaleft': dict(kind='screen_off', rect=(139, 55, 155, 70), glass=(20, 24, 24)),
    },
    'study_d': {
        'anchor_study_radio': dict(kind='screen_off', rect=(151, 63, 167, 73), glass=(18, 26, 20)),
    },
    # ----- bathrooms -----
    'bathroom_b': {
        'anchor_bathroom_radio_stool': dict(kind='screen_off', rect=(273, 79, 284, 86), glass=(18, 16, 14)),
        'anchor_bathroom_vanity': dict(kind='door_h', rect=(10, 87, 27, 110), angle=70, base=108, hinge='l', cavity='dark'),
    },
    'bathroom_c': {
        'anchor_bathroom_champagne': dict(kind='topple', rect=(207, 80, 215, 93), dir='l', fg=[(46, 74, 46), (212, 168, 58)], thr=8),
    },
    'bathroom_e': {
        'anchor_bathroom_frosted_cabinet': dict(kind='door_h', rect=(281, 77, 292, 99), angle=75, base=108, hinge='l', cavity='dark'),
        'anchor_bathroom_hamper': dict(kind='lid', rect=(211, 79, 231, 89), rise=9, base=108, inside=(122, 84, 98), under=(150, 100, 114)),
    },
    # ----- bedrooms -----
    'bedroom_c': {
        'anchor_bedroom_wardrobe': dict(kind='door_h', rect=(7, 41, 25, 100), angle=70, base=108, hinge='l', cavity='wardrobe'),
        'anchor_bedroom_med_trolley': dict(kind='topple', rect=(257, 82, 263, 89), dir='r', fg=[(192, 122, 58)], thr=14),
    },
    'bedroom_e': {
        # the block tower beside the table (bedroom_variants.TOWER_X) falls to the right; the rocking horse stands NEARER than it, so what the horse covers is laid back over the fall
        'anchor_bedroom_dollhouse': dict(kind='topple', rect=(61, 68, 77, 99), dir='r', front=(78, 88, 114, 99), thr=30,
                                         bg=[(185, 201, 214), (230, 227, 217), (224, 220, 208), (112, 110, 104)]),
        'anchor_bedroom_small_wardrobe': dict(kind='door_h', rect=(291, 49, 302, 98), angle=75, base=108, hinge='r', cavity='wardrobe'),     # the library's kid wardrobe, 28 wide (bedroom_variants.WARDROBE_X)
    },
    # ----- dining rooms -----
    'dining_room': {
        'anchor_dining_trolley': dict(kind='topple', rect=(245, 74, 251, 87), dir='r', fg=[(90, 26, 34)], thr=12),
    },
    'dining_room_b': {
        'anchor_table_left': dict(kind='topple', rect=(148, 70, 166, 94), dir='r',
                                  fg=[(184, 208, 208), (77, 106, 60), (217, 102, 46), (192, 69, 58), (232, 184, 58)], thr=8),
        'anchor_dining_record_player': dict(kind='lid', rect=(277, 65, 297, 71), rise=8, base=108),
    },
    'dining_room_c': {
        'anchor_dining_grandfather_clock': dict(kind='door_h', rect=(108, 60, 120, 98), angle=80, base=108, hinge='l', cavity='dark',
                                                items=clock_items),
        'anchor_dining_candelabra': dict(kind='topple', rect=(168, 70, 192, 91), dir='r', fg=[(185, 191, 193)], thr=10),
    },
    'dining_room_e': {
        'anchor_table_left': dict(kind='topple', rect=(149, 72, 158, 90), dir='r', fg=[(90, 138, 192), (62, 96, 134)], thr=14),
    },
    # ----- living rooms -----
    'living_room': {
        'anchor_centre_coffeetable': dict(kind='topple', rect=(172, 93, 180, 100), dir='r', bg=[(172, 93), (180, 93)], thr=45),
    },
    'living_room_c': {
        'anchor_centre_sofaleft': dict(kind='screen_off', rect=(148, 34, 203, 61), glass=(6, 6, 8)),
    },
    'living_room_d': {
        'anchor_living_tea_table': dict(kind='topple', rect=(115, 91, 125, 100), dir='r', bg=[(115, 91), (125, 91), (115, 97)], thr=50),
    },
    # ----- studies / kitchens (tables) -----
    'study': {
        'anchor_centre_desk': dict(kind='topple', rect=(148, 70, 166, 91), dir='r', fg=[(63, 122, 82), (94, 156, 114), (176, 148, 86)], thr=10),
    },
    'study_e': {
        'anchor_study_trestle': dict(kind='topple', rect=(226, 78, 234, 98), dir='r', fg=[(185, 196, 196), (147, 112, 63)], thr=8),
    },
    'kitchen_c': {
        'anchor_centre_oven': dict(kind='door_h', rect=(134, 86, 159, 107), angle=62, base=106, hinge='l', cavity='oven'),
        'anchor_kitchen_pine_table': dict(kind='topple', rect=(252, 84, 262, 95), dir='l', fg=[(95, 120, 150)], thr=10),
    },
    'bedroom_d': {
        'anchor_bedroom_boxes': dict(kind='lid', rect=(283, 62, 303, 72), rise=8, base=108, inside=(88, 66, 40), under=(150, 112, 64)),
    },
    # ----- wardrobes (above and below) -----
    'bedroom': {
        'anchor_wall_right_upper': dict(kind='door_h', rect=(277, 42, 293, 88), angle=70, base=108, hinge='l', cavity='wardrobe'),
    },
}
for _art, _d in OPENINGS_45C.items():
    OPENINGS.setdefault(_art, {}).update(_d)

# --- round 45d: more of them — things that SWING or ROCK (a path of per-frame turns about a pivot), more doors, lids and tips ---
OPENINGS_45D = {
    'bedroom_d': {
        # the library's clothes rail (furn_embed.lay 'clothes_rail' at x 220): the garments below the rail bar sway on their hangers; everything that is not the wall behind them moves
        'anchor_bedroom_clothes_rail': dict(kind='shift', rect=(224, 73, 262, 101), pivot='top', thr=30, bg=[(270, 85), (270, 95)],
                                            path=[(0, 0, 6), (0, 0, -5), (0, 0, 3), (0, 0, -2), (0, 0, 0)]),
    },
    'bedroom_e': {
        'anchor_bed_pillow': dict(kind='topple', rect=(126, 78, 143, 99), dir='r', thr=10,           # the library's teddy (furn_beds._teddy): its ramp, ribbon and outline
                                  fg=[(192, 158, 126), (166, 117, 72), (124, 84, 46), (80, 54, 30), (63, 44, 27), (47, 31, 17), (30, 20, 11), (192, 74, 82), (214, 192, 171), (224, 122, 130), (72, 60, 47), (56, 25, 20), (30, 26, 22), (96, 79, 64), (76, 39, 28), (95, 52, 35), (123, 82, 68), (119, 89, 80)]),   # + its eyes and the smear across it
    },
    'bathroom_c': {
        'anchor_bathroom_towel_stand': dict(kind='shift', rect=(232, 66, 248, 93), pivot='top', thr=8,
                                            fg=[(122, 31, 42), (97, 24, 33), (141, 62, 72), (109, 27, 37)],
                                            path=[(0, 0, 6), (0, 0, -5), (0, 0, 3), (0, 0, -2), (0, 0, 0)]),
    },
    'living_room_d': {
        'anchor_living_china_cabinet': dict(kind='door_h', rect=(269, 80, 283, 97), angle=70, base=108, hinge='l', cavity='dark',
                                            items=plates_items),
    },
    'kitchen_c': {
    },
    'kitchen_e': {
        'anchor_kitchen_bag_table': dict(kind='topple', rect=(280, 81, 294, 96), dir='l', fg=[(78, 110, 160), (62, 88, 128)], thr=8),
        'anchor_kitchen_buried_counter': dict(kind='topple', rect=(150, 66, 158, 77), dir='r', fg=[(122, 138, 90)], thr=10),
        'anchor_kitchen_cat_tins': dict(kind='shift', rect=(264, 114, 271, 123), dx=9, dy=0, deg=180, hump=2.5, fg=[(78, 122, 160)], thr=10),
    },
    'study_d': {
        'anchor_study_boxes': dict(kind='lid', rect=(207, 69, 224, 82), rise=7, base=108, inside=(88, 66, 40), under=(150, 112, 64)),
        'anchor_study_handset': dict(kind='shift', rect=(235, 76, 249, 100), pivot='bottom', thr=10,
                                     fg=[(168, 50, 44), (92, 27, 24), (134, 40, 35)],
                                     path=[(0, 0, 8), (1, 0, -6), (0, 0, 3), (0, 0, 0)]),
    },
}
for _art, _d in OPENINGS_45D.items():
    OPENINGS.setdefault(_art, {}).update(_d)


def render(art_img, spec, f, ref=None):
    cv = art_img.copy()
    kind = spec['kind']
    if kind == 'drawer':
        draw_drawer(cv, art_img, spec['rect'], f, spec['depth'], spec['base'], spec.get('contents'))
    elif kind == 'door_h':
        draw_door_h(cv, art_img, spec['rect'], f, spec['angle'], spec['base'], spec.get('hinge', 'l'),
                    spec.get('cavity', 'dark'), spec.get('items'))
    elif kind == 'door_drop':
        draw_door_drop(cv, art_img, spec['rect'], f, spec['angle'], spec['base'])
    elif kind == 'topple':
        draw_topple(cv, art_img, spec['rect'], f, spec.get('dir', 'r'), spec.get('bg'), spec.get('thr', 36), spec.get('pad', 0), spec.get('fg'), ref, spec.get('front'))
    elif kind == 'shift':
        nfr = len(spec['path']) if spec.get('path') else int(spec.get('frames', DEFAULT_FRAMES['shift']))
        draw_shift(cv, art_img, spec['rect'], f, spec.get('dx', 0), spec.get('dy', 0), spec.get('deg', 0.0), spec.get('bg'),
                   spec.get('thr', 36), spec.get('hump', 0.0), spec.get('fg'), ref, spec.get('path'), int(round(f * nfr)) - 1,
                   spec.get('pivot', 'center'))
    elif kind == 'screen_off':
        draw_screen_off(cv, art_img, spec['rect'], f, spec.get('glass', (14, 18, 20)))
    elif kind == 'lid':
        draw_lid(cv, art_img, spec['rect'], f, spec.get('rise', 10), spec.get('base', 108), spec.get('items'), spec.get('inside'), spec.get('under'))
    else:
        raise SystemExit('unknown opening kind %r' % kind)
    return cv


DEFAULT_FRAMES = {'topple': 4, 'screen_off': 4, 'shift': 4}


def build_one(art_name, run, anchor, spec):
    path = os.path.join(ROOMS, art_name + RUN_SUFFIX[run] + '.png')
    if not os.path.exists(path):
        return None
    base = Image.open(path).convert('RGBA')
    first = os.path.join(ROOMS, art_name + '.png')
    ref = Image.open(first).convert('RGBA') if run != 1 and os.path.exists(first) else None
    nfr = len(spec['path']) if spec.get('path') else int(spec.get('frames', DEFAULT_FRAMES.get(spec['kind'], FRAMES)))
    fracs = [(i + 1) / float(nfr) for i in range(nfr)]
    frames = [render(base, spec, f, ref) for f in fracs]
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
    sheet = Image.new('RGBA', (w * nfr, h), (0, 0, 0, 0))
    sp = sheet.load()
    for k, fr in enumerate(frames):
        fp = fr.load()
        for y in range(h):
            for x in range(w):
                if fp[x0 + x, y0 + y] != bp[x0 + x, y0 + y]:
                    sp[k * w + x, y] = fp[x0 + x, y0 + y]
    name = '%s__%s%s.png' % (art_name, anchor, RUN_SUFFIX[run])
    sheet.save(os.path.join(OUT, name))
    return {'x': x0, 'y': y0, 'w': w, 'h': h, 'frames': nfr, 'kind': spec['kind']}, frames[-1], base


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
    # an opening that was dropped must not leave its sheet (or its .import — the engine would draw the cached texture) behind
    wanted = {'open_meta.json'}
    for art, anchors in meta.items():
        for anchor in anchors:
            for run in (1, 2, 3):
                wanted.add('%s__%s%s.png' % (art, anchor, RUN_SUFFIX[run]))
    for fn in sorted(os.listdir(OUT)):
        base = fn[:-len('.import')] if fn.endswith('.import') else fn
        if base not in wanted and not check:
            os.remove(os.path.join(OUT, fn))
            print('removed stale', fn)
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
