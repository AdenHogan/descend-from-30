"""THE INSIDE OF A WARDROBE, drawn once for everyone (owner round 48i: "the interior should have a clear geometric interior. I just see a black square").

Used by the baked pipeline (tools/art/openables.py, a PIL canvas) AND the planned wardrobe piece (tools/art/furn_wardrobes.py, a pixlib Canvas): the caller hands in a `put(x, y, rgba)`
that writes a pixel and the cavity rectangle; every tone comes from the furniture's own wood colour, so a cream wardrobe is cream inside and an oak one is oak.

What is drawn: a slatted back panel lit from the open side and from above, a lit left wall and a shaded right wall that widen toward the camera, a dark ceiling, a shelf with its lit front
edge and the shadow under it (a hat box and a folded jumper on it), a brass rail with hangers and garments of different lengths and colours (shoulders, a fold, lit left / shaded right),
and a floor with a lit front lip and a pair of shoes.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import shade


def _c(r, g, b):
    return (r, g, b, 255)


def draw(put, rect, body):
    x0, y0, x1, y1 = rect
    w, h = x1 - x0 + 1, y1 - y0 + 1
    px = lambda x, y, col: put(x, y, col) if (x0 <= x <= x1 and y0 <= y <= y1) else None

    wall_l, wall_r = max(2, w // 7), max(2, w // 7)
    for y in range(y0, y1 + 1):
        v = (y - y0) / float(max(1, h - 1))
        for x in range(x0, x1 + 1):
            u = (x - x0) / float(max(1, w - 1))
            f = 0.64 - 0.16 * u - 0.12 * v                              # the back panel: light comes in from the open left, and from above
            col = shade(body, f)
            if (x - x0) % 4 == 3:
                col = shade(col, 0.86)                                  # a slat joint
            px(x, y, col)
    for y in range(y0, y1 + 1):                                         # the walls, in perspective: each is a strip that widens toward the camera (the bottom)
        v = (y - y0) / float(max(1, h - 1))
        grow = int(round(v * 1.0))
        for k in range(wall_l + grow):
            px(x0 + k, y, shade(body, 0.86 - 0.10 * k / max(1, wall_l)))
        for k in range(wall_r + grow):
            px(x1 - k, y, shade(body, 0.36 + 0.06 * k / max(1, wall_r)))
    for k in range(3):                                                  # the ceiling: dark, with the front edge lit
        for x in range(x0, x1 + 1):
            px(x, y0 + k, shade(body, 0.26 + 0.04 * k))
    for x in range(x0, x1 + 1):
        px(x, y0 + 3, shade(body, 0.30))
    sh = y0 + max(8, int(h * 0.26))                                     # the shelf: a board seen from a little below, its lit front edge, the shadow it throws
    for x in range(x0 + 1, x1):
        px(x, sh, shade(body, 1.05))
        px(x, sh + 1, shade(body, 0.80))
        px(x, sh + 2, shade(body, 0.30))
        px(x, sh + 3, shade(body, 0.40))
    box = [(_c(140, 118, 96), 5, 4), (_c(98, 108, 124), 4, 3)]    # a hat box and a folded jumper on the shelf
    bx = x0 + wall_l + 1
    for col, bw, bh in box:
        if bx + bw >= x1 - wall_r:
            break
        for yy in range(sh - bh, sh):
            for xx in range(bx, bx + bw):
                px(xx, yy, shade(col, 1.0 - 0.18 * (xx - bx) / max(1, bw)))
        for xx in range(bx, bx + bw):
            px(xx, sh - bh, shade(col, 1.25))
        bx += bw + 1
    rail = sh + 8
    for x in range(x0 + 1, x1):
        px(x, rail, (176, 150, 86, 255))                               # the brass rail
        px(x, rail + 1, (110, 92, 50, 255))
    cols = [(132, 62, 62), (66, 84, 118), (122, 108, 70), (92, 72, 104), (70, 100, 84), (150, 130, 112)]
    gx = x0 + wall_l + 1
    i = 0
    while gx + 2 < x1 - wall_r:
        gw = 3 if i % 3 else 4
        gl = 14 + (i * 5) % 13                                          # garments hang to different lengths
        gl = min(gl, (y1 - 6) - (rail + 2))
        gc = cols[i % len(cols)] + (255,)
        px(gx + 1, rail - 1, (60, 56, 52, 255))                        # the hanger's hook
        px(gx, rail, (60, 56, 52, 255)); px(gx + gw - 1, rail, (60, 56, 52, 255))
        for yy in range(rail + 2, rail + 2 + gl):
            for xx in range(gx, gx + gw):
                t = (xx - gx) / float(max(1, gw - 1))
                px(xx, yy, shade(gc, 1.10 - 0.42 * t))                 # lit on its left, folded into shade on its right
        px(gx, rail + 2, shade(gc, 1.35))
        for yy in (rail + 2, rail + 3):                                 # the shoulders, a hair wider than the body they hang from
            px(gx - 1, yy, shade(gc, 0.92)); px(gx + gw, yy, shade(gc, 0.62))
        px(gx + gw // 2, rail + 2 + gl // 2, shade(gc, 0.8))           # a fold
        gx += gw + 2
        i += 1
    for k in range(3):                                                  # the floor: a lit front lip, then the shadowed boards
        for x in range(x0 + 1, x1):
            px(x, y1 - k, shade(body, 0.92 - 0.22 * k))
    for sx in (x0 + wall_l + 2, x0 + wall_l + 8):                       # a pair of shoes
        if sx + 4 < x1 - wall_r:
            for xx in range(sx, sx + 4):
                px(xx, y1 - 3, (38, 32, 30, 255)); px(xx, y1 - 4, (58, 50, 46, 255))


def _c(r, g, b):
    return (r, g, b, 255)
