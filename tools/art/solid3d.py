"""Solid 3D pieces in the room's one perspective (owner round 18 — "the bathroom scene looks a bit more
compact… these items a little more closer to the player"): fixtures you stand at — toilets, basins,
baths, washing machines, counters — come OUT from the wall toward the walking lane, so they are drawn
as real solids, not panels.

Everything is described in WALL coordinates (x, y as if drawn flat on the back wall, y 100 = the floor)
plus a depth d (px of floor out from the wall) and projected with `pixlib.pp` (horizon at the ceiling,
vanishing point x 160). A round fixture is a stack of flat horizontal SLICES (a lathe: each slice an
ellipse at a height, centred at a depth), a long one a stack of rounded-rectangle slices. A piece is
drawn into its own transparent layer, outlined once round its silhouette and composited, so the slices
never show seams.
"""
import math

from PIL import Image, ImageDraw

from pixlib import Canvas, W, H, pp, shade

VP = W // 2


def P(x, y, d):
    q = pp(x, y, d)
    return (int(round(q[0])), int(round(q[1])))


def wall_x(x, d):
    """The wall-coord x that lands on screen x when brought d px out."""
    return VP + (x - VP) * 100.0 / (100 + d)


def ell_geo(cx, y, d0, d1, rx):
    """Screen ellipse (cx, cy, rx, ry) of a flat plan ellipse at wall-height y, depths d0..d1."""
    dm = (d0 + d1) / 2.0
    ccx = pp(cx, y, dm)[0]
    ya, yb = pp(cx, y, d0)[1], pp(cx, y, d1)[1]
    s = (100 + dm) / 100.0
    return ccx, (ya + yb) / 2.0, rx * s, max(0.6, (yb - ya) / 2.0)


def fill_ellipse_shaded(c, ex, ey, erx, ery, lit, mid, dk, lit_u=-0.45, dk_u=0.4):
    """An ellipse filled in three vertical bands: lit on the left, dark on the right."""
    for y in range(int(math.floor(ey - ery)), int(math.ceil(ey + ery)) + 1):
        t = (y - ey) / max(0.5, ery)
        if abs(t) > 1.0:
            continue
        hw = erx * math.sqrt(max(0.0, 1 - t * t))
        for x in range(int(round(ex - hw)), int(round(ex + hw)) + 1):
            u = (x - ex) / max(0.5, erx)
            c.put(x, y, lit if u < lit_u else (mid if u < dk_u else dk))


def rrect_plan(x0, x1, d0, d1, rx, rd, n=5):
    """Plan points (x, d) of a rounded rectangle x0..x1 × d0..d1, corner radii rx (x) and rd (d)."""
    pts = []
    for (cxp, cdp, a0) in ((x1 - rx, d0 + rd, -90), (x1 - rx, d1 - rd, 0), (x0 + rx, d1 - rd, 90), (x0 + rx, d0 + rd, 180)):
        for k in range(n + 1):
            a = math.radians(a0 + 90.0 * k / n)
            pts.append((cxp + rx * math.cos(a), cdp + rd * math.sin(a)))
    return pts


def plan_poly(c, plan, y, col):
    c.poly([P(x, y, d) for (x, d) in plan], col)


def plan_screen(plan, y):
    return [pp(x, y, d) for (x, d) in plan]


class Layer:
    """Draw a piece into a transparent layer, then `commit` it onto the room with a 1px outline round
    its silhouette (and optionally only where a mask allows)."""

    def __init__(self):
        self.c = Canvas(bg=(0, 0, 0, 0))

    def commit(self, room, out=None):
        src = self.c.img
        px = self.c.px
        if out is not None:
            edge = []
            for y in range(H):
                for x in range(W):
                    if px[x, y][3] != 0:
                        continue
                    for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        qx, qy = x + dx, y + dy
                        if 0 <= qx < W and 0 <= qy < H and px[qx, qy][3] == 255:
                            edge.append((x, y))
                            break
            for (x, y) in edge:
                px[x, y] = out
        room.img.alpha_composite(src)
        room.px = room.img.load()


def masked(c, poly_screen, draw_fn):
    """Run draw_fn on a scratch layer and keep only what falls inside poly_screen (screen points)."""
    lay = Canvas(bg=(0, 0, 0, 0))
    draw_fn(lay)
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).polygon([(float(x), float(y)) for (x, y) in poly_screen], fill=255)
    mp = m.load()
    lp = lay.px
    for y in range(H):
        for x in range(W):
            if mp[x, y] == 0:
                lp[x, y] = (0, 0, 0, 0)
    c.img.alpha_composite(lay.img)
    c.px = c.img.load()


def lathe(c, cx, slices, body, lit=None, dk=None):
    """A turned solid: slices = [(y, rx, d_centre, rd)] from the BOTTOM up; each a flat ellipse. Drawn
    bottom-up so upper slices sit on lower ones (lit left, dark right)."""
    lit = lit or shade(body, 1.12)
    dk = dk or shade(body, 0.78)
    for (y, rx, dc, rd) in slices:
        ex, ey, erx, ery = ell_geo(cx, y, dc - rd, dc + rd, rx)
        fill_ellipse_shaded(c, ex, ey, erx, ery, lit, body, dk)


def lerp_slices(y_bot, y_top, bot, top, ease=None):
    """Slices from (rx, dc, rd) at y_bot up to (rx, dc, rd) at y_top, one per wall px."""
    out = []
    n = max(1, int(round(y_bot - y_top)))
    for i in range(n + 1):
        t = i / float(n)
        e = ease(t) if ease else t
        y = y_bot - (y_bot - y_top) * t
        out.append((y,) + tuple(b + (a - b) * e for (b, a) in zip(bot, top)))
    return out
