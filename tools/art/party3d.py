"""True-perspective party props for dining variant E (owner round 36e: "the table lacks the geometry and looks overly
2D as do the chairs behind it, and the decorations on the table… the green open box is poorly designed").

Everything here is described in WALL coordinates (x, y as drawn flat on the back wall; y 100 = the floor) plus a depth d
(px of floor out from the wall) and projected with pixlib.pp — the same projection pbox uses — so a table's top shows as a
real surface, its legs are set back in pairs, and a cake / hat / cup stands on that surface as a solid with a top face.
"""
import math
import pixlib as PX
from pixlib import hexc, shade, pp, pbox, _ip, SEAM_Y, VP_X
import furn as F

SEAM = float(SEAM_Y)


def sc(d):
    return (SEAM + d) / SEAM


def scr(x, y, d):
    """A wall-coord point → rounded art px."""
    p = pp(x, y, d)
    return (int(round(p[0])), int(round(p[1])))


# --- solids standing on a surface ------------------------------------------------------------------
def cyl(c, x, y_base, h, d, r, side, top, side_dk=None, rim=None, ratio=0.36):
    """A cylinder (a cake, a cup, a drum) standing at wall (x, y_base) at depth d, h tall, radius r: a lit side, a
    darker shaded edge, a top ellipse (we look down on it) and a curved base."""
    s = sc(d)
    bx, by = pp(x, y_base, d)
    ty = (y_base - h) * s
    rx = max(1.0, r * s)
    ry = max(0.8, rx * ratio)
    side_dk = side_dk or shade(side, 0.74)
    x0, x1 = int(round(bx - rx)), int(round(bx + rx))
    for xx in range(x0, x1 + 1):
        u = (xx - (bx - rx)) / max(1.0, 2 * rx)                  # 0 left … 1 right
        col = shade(side, 1.08) if u < 0.28 else (side if u < 0.66 else side_dk)
        c.vline(xx, int(round(ty)), int(round(by)), col)
    c.ellipse(bx, by, rx, ry, side_dk)
    for xx in range(x0, x1 + 1):                                  # the base curve takes the side's colour back
        u = (xx - (bx - rx)) / max(1.0, 2 * rx)
        col = shade(side, 1.08) if u < 0.28 else (side if u < 0.66 else side_dk)
        k = ((xx - bx) / max(rx, 0.5))
        yy = by + ry * math.sqrt(max(0.0, 1 - k * k))
        c.vline(xx, int(round(by)), int(round(yy)), col)
    c.ellipse(bx, ty, rx, ry, top)
    if rim is not None:
        for xx in range(x0, x1 + 1):
            k = ((xx - bx) / max(rx, 0.5))
            yy = ty + ry * math.sqrt(max(0.0, 1 - k * k))
            c.put(xx, int(round(yy)), rim)
    return (bx, by, ty, rx, ry)


def disc(c, x, y, d, r, col, edge=None):
    """A flat round thing lying on a surface (a plate, a stain, a coaster) seen from above in perspective."""
    s = sc(d)
    bx, by = pp(x, y, d)
    rx = max(1.0, r * s)
    ry = max(0.7, rx * 0.36)
    if edge is not None:
        c.ellipse(bx, by + 0.5, rx + 0.5, ry + 0.5, edge)
    c.ellipse(bx, by, rx, ry, col)
    return (bx, by, rx, ry)


def cone(c, x, y_base, h, d, r, col, col_dk, stripe=None, pom=None):
    """A party hat: a cone with a lit and a shaded half, its brim a curved base, an optional stripe band + a pom."""
    s = sc(d)
    bx, by = pp(x, y_base, d)
    rx = max(1.5, r * s)
    ry = max(0.8, rx * 0.36)
    ax, ay = bx, by - h * s
    c.poly([(bx - rx, by), (bx + rx, by), (ax, ay)], col)
    c.poly([(bx + rx * 0.15, by), (bx + rx, by), (ax, ay)], col_dk)
    c.ellipse(bx, by, rx, ry, col_dk)
    for xx in range(int(round(bx - rx)), int(round(bx + rx)) + 1):
        k = (xx - bx) / max(rx, 0.5)
        yy = by + ry * math.sqrt(max(0.0, 1 - k * k))
        c.vline(xx, int(round(by)), int(round(yy)), col if k < 0.15 else col_dk)
    if stripe is not None:
        m = by - h * s * 0.45
        w = rx * (1 - 0.45)
        c.line(int(round(bx - w)), int(round(m)), int(round(bx + w)), int(round(m)), stripe)
    if pom is not None:
        c.put(int(round(ax)), int(round(ay)) - 1, pom)
        c.put(int(round(ax)), int(round(ay)), pom)


def gift(c, x0, x1, y_base, h, d0, d1, col, ribbon, lid=None, bow=True, out=None):
    """A wrapped present: a true-perspective box (top, shaded side, front) with a ribbon crossing the front and the top, and a
    bow. (x0..x1) wall x, `y_base` the surface it stands on, `h` its height, d0..d1 its depth range."""
    y_top = y_base - h
    out = out or shade(col, 0.55)
    g = pbox(c, x0, y_top, x1, y_base, d0, d1, col, shade(col, 1.14), shade(col, 0.74), out)
    fl, fr, fbl, fbr, bl, br = g['fl'], g['fr'], g['fbl'], g['fbr'], g['bl'], g['br']
    mx = (fl[0] + fr[0]) // 2
    c.vline(mx, fl[1] + 1, fbl[1] - 1, ribbon)                      # the ribbon down the front …
    c.vline(mx + 1, fl[1] + 1, fbl[1] - 1, shade(ribbon, 0.85))
    tx0, ty0 = (bl[0] + br[0]) // 2, bl[1]                          # … and over the top, front to back
    tx1, ty1 = mx, fl[1]
    c.line(tx0, ty0, tx1, ty1, ribbon)
    if bow:
        bxm, bym = (tx0 + tx1) // 2, (ty0 + ty1) // 2
        c.poly([(bxm, bym), (bxm - 3, bym - 2), (bxm - 3, bym + 1)], ribbon)
        c.poly([(bxm + 1, bym), (bxm + 4, bym - 2), (bxm + 4, bym + 1)], ribbon)
        c.put(bxm, bym - 1, shade(ribbon, 0.7))
        c.put(bxm, bym, shade(ribbon, 0.7))
    return g


# --- a table, from the front and a little above ------------------------------------------------------
def _leg(c, x, d, y_top, wood, wood_lt, wood_dk, out, w=2.6, t=2.4):
    pbox(c, x, y_top, x + w, SEAM, d, d + t, wood, wood_lt, wood_dk, out)


def table3d(c, wx0, wx1, d0, d1, y_top, wood, wood_lt, wood_dk, out, cloth=None, cloth_dk=None, hem=13, thick=2.4,
            shadow=96, register='table'):
    """A table in true perspective: soft shadow, four legs (the far pair set back, so smaller + higher), then either a
    bare top + apron or a CLOTH — a top plane and a front skirt hung to `hem` wall-px below the top, scalloped, folded —
    with the legs showing below its hem. Returns the front-top corners + the top surface's wall y for the things set on it."""
    ds = (d0 + d1) / 2.0
    sx, sy = pp((wx0 + wx1) / 2.0, SEAM, ds)
    c.shadow(sx, sy + 1, (wx1 - wx0) / 2.0 * sc(ds) + 5, 4.2, shadow)
    inset = 3.0
    legs = [(wx0 + inset, d0 + 1.5), (wx1 - inset - 2.6, d0 + 1.5), (wx0 + inset, d1 - 1.5 - 2.4), (wx1 - inset - 2.6, d1 - 1.5 - 2.4)]
    for (lx, ld) in legs[:2]:
        _leg(c, lx, ld, y_top + thick, shade(wood, 0.9), shade(wood_lt, 0.85), shade(wood_dk, 0.85), out)
    for (lx, ld) in legs[2:]:
        _leg(c, lx, ld, y_top + thick, wood, wood_lt, wood_dk, out)
    # feet registry (the floor-clip check): the two near legs' feet
    spans = []
    for (lx, ld) in legs[2:]:
        a = scr(lx, SEAM, ld + 1.2)
        b = scr(lx + 2.6, SEAM, ld + 1.2)
        spans.append((min(a[0], b[0]), max(a[0], b[0])))
    F._register_feet(register, spans, scr(wx0, SEAM, d1)[1])
    if cloth is None:
        g = pbox(c, wx0 + 1, y_top + thick, wx1 - 1, y_top + thick + 3.2, d0 + 1.5, d1 - 1.5, shade(wood, 0.92), None, shade(wood_dk, 0.9), out)
        t = pbox(c, wx0, y_top, wx1, y_top + thick, d0, d1, wood, wood_lt, shade(wood, 0.7), out)
        return {'top_y': y_top, 'front': t}
    cd = cloth_dk or shade(cloth, 0.86)
    ex = 1.6                                                       # the cloth overhangs the top by this much each side
    dfr = d1 + 1.2
    fl_, fr_ = scr(wx0 - ex, y_top, dfr), scr(wx1 + ex, y_top, dfr)
    bl_, br_ = scr(wx0 - ex, y_top, d0 - 0.8), scr(wx1 + ex, y_top, d0 - 0.8)
    c.poly([bl_, br_, fr_, fl_], shade(cloth, 1.05))               # the top plane, a shade lighter than the skirt
    y_hem = scr(wx0, y_top + hem, dfr)[1]
    x_a, x_b = fl_[0], fr_[0]
    rng = c.rng
    # the skirt: lit toward the middle, folds hanging straight down in a regular-ish rhythm, a scalloped hem
    for xx in range(x_a, x_b + 1):
        k = (xx - x_a) % 9
        col = cd if k in (0, 1) else (shade(cloth, 1.03) if k in (4, 5) else cloth)
        drop = (2 if k in (0, 1) else 0) if (xx // 5) % 2 == 0 else (1 if k in (0, 1) else 0)
        c.vline(xx, fl_[1] + 1, y_hem + drop, col)
    c.hline(x_a, x_b, fl_[1], shade(cloth, 1.1))                    # the front edge, catching the light
    c.hline(x_a, x_b, fl_[1] + 1, shade(cloth, 0.96))
    return {'top_y': y_top, 'front': (fl_, fr_), 'back': (bl_, br_), 'hem_y': y_hem}


def knife(c, x, y, d, ang=0.0, blade=hexc('c8ced2'), grip=hexc('3a2a22'), length=6.0):
    """A knife lying on a surface (wall x, wall y of the surface, depth d), seen from above."""
    px, py = pp(x, y, d)
    s = sc(d)
    dx, dy = math.cos(ang) * length * s * 0.5, math.sin(ang) * length * s * 0.18
    c.line(int(round(px - dx)), int(round(py - dy)), int(round(px)), int(round(py)), grip)
    c.line(int(round(px)), int(round(py)), int(round(px + dx)), int(round(py + dy)), blade)


# --- an opened present (the torn box) ------------------------------------------------------------------
def _quad(c, pts, col, edge=None):
    c.poly([scr(*q) for q in pts], col)
    if edge is not None:
        sp = [scr(*q) for q in pts]
        for i in range(4):
            a, b = sp[i], sp[(i + 1) % 4]
            c.line(a[0], a[1], b[0], b[1], edge)


def torn_box(c, x0, x1, d0, d1, y_base, h, paper, paper_dk, inner, ribbon):
    """A gift box someone tore open, in true perspective: a wrapped box with its TOP FLAPS torn open — the back flap leaning
    up and away, the two side flaps folded out and down, the front flap hanging over the front — a dark cavity between them
    with the lining showing on the far wall, a long ribbon dragged out across the floor and a scrunch of torn wrapping
    paper in front. (Owner round 36e: the first box read as a green wedge with no sense of what was open.)"""
    y_top = y_base - h
    edge = shade(paper, 0.5)
    g = pbox(c, x0, y_top, x1, y_base, d0, d1, paper, shade(paper, 1.08), paper_dk, edge)
    fl, fr, fbl, fbr = g['fl'], g['fr'], g['fbl'], g['fbr']
    ins = 1.2
    # the open mouth: black cavity, the far inside wall lit, a dark band where the near rim shadows it
    mouth = [(x0 + ins, y_top, d0 + ins), (x1 - ins, y_top, d0 + ins), (x1 - ins, y_top, d1 - ins), (x0 + ins, y_top, d1 - ins)]
    _quad(c, mouth, hexc('16120f'))
    _quad(c, [(x0 + ins, y_top, d0 + ins), (x1 - ins, y_top, d0 + ins), (x1 - ins, y_top + h * 0.42, d0 + ins),
              (x0 + ins, y_top + h * 0.42, d0 + ins)], inner)
    _quad(c, [(x0 + ins, y_top + h * 0.42, d0 + ins), (x1 - ins, y_top + h * 0.42, d0 + ins), (x1 - ins, y_top + h * 0.6, d0 + ins),
              (x0 + ins, y_top + h * 0.6, d0 + ins)], shade(inner, 0.6))
    # the flaps. Outer face = the wrapping paper, inner face (what we see on an open flap leaning away) a paler lining.
    lift = 7.0
    _quad(c, [(x0, y_top, d0), (x1, y_top, d0), (x1 - 1, y_top - lift, d0 - 3.5), (x0 + 1, y_top - lift, d0 - 3.5)],
          shade(inner, 1.12), shade(paper, 0.6))                                                       # back flap, leaning up + away
    _quad(c, [(x0, y_top, d0), (x0, y_top, d1), (x0 - 6.5, y_top + 3.0, d1 - 0.5), (x0 - 6.5, y_top + 3.0, d0 + 0.5)],
          shade(paper, 1.12), edge)                                                                     # left flap, folded out + down
    _quad(c, [(x1, y_top, d0), (x1, y_top, d1), (x1 + 6.5, y_top + 3.0, d1 - 0.5), (x1 + 6.5, y_top + 3.0, d0 + 0.5)],
          shade(paper, 0.9), edge)                                                                      # right flap
    _quad(c, [(x0, y_top, d1), (x1, y_top, d1), (x1 - 1.5, y_top + 5.0, d1 + 3.2), (x0 + 1.5, y_top + 5.0, d1 + 3.2)],
          paper, edge)                                                                                  # front flap, hanging toward us
    # the torn edge of the front flap: a few nicks
    ny = scr(x0, y_top + 5.0, d1 + 3.2)[1]
    for xx in range(scr(x0 + 2, y_top, d1 + 3.2)[0], scr(x1 - 2, y_top, d1 + 3.2)[0], 3):
        c.put(xx, ny, hexc('16120f') if (xx // 3) % 3 == 0 else shade(paper, 1.3))
    # the ribbon: still tied to the lid-less box's side, trailing out over the floor
    r0 = scr(x1 + 1.0, y_base - 3.0, d1 - 1.0)
    pts = [r0, (r0[0] + 3, r0[1] + 1), (r0[0] + 7, r0[1] + 3), (r0[0] + 9, r0[1] + 6), (r0[0] + 6, r0[1] + 8), (r0[0] + 2, r0[1] + 7)]
    for i in range(len(pts) - 1):
        c.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], ribbon)
        c.put(pts[i][0], pts[i][1] + 1, shade(ribbon, 0.75))
    # torn wrapping paper, scrunched on the floor beside it: crumpled facets
    bx, by = pp(x0 - 2.0, SEAM, d1 + 2.0)
    for (ox, oy, w, hgt) in ((-7, 1, 6, 3), (-2, 3, 5, 3), (-10, 3, 4, 2)):
        px, py = int(round(bx)) + ox, int(round(by)) + oy
        c.poly([(px, py), (px + w, py - 1), (px + w - 1, py - hgt), (px + 1, py - hgt + 1)], paper)
        c.hline(px + 1, px + w - 1, py - hgt + 1, shade(paper, 1.25))
        c.put(px + 2, py - 1, paper_dk)
    return g
