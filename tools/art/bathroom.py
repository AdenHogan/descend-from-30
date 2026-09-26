"""Bathroom module — every art VARIANT (320 x 144 native pixel art, the living room's style).

Run:  python3 tools/art/bathroom.py [variant ...]      (no args = all)
Out:  assets/rooms/bathroom[_<v>].png (+ _floor.png), scenes/Room_Modules/bathroom[_<v>].tscn,
      docs/art_reference/modules/bathroom[_<v>]_x4.png + nodes/…_nodes.png

Variants (owner round 10 — "that bath is way too long… a horse water trough"; round 18 — the fixtures
come forward toward the walking lane, see solid3d.py):
  a  classic   — a roll-top bath on claw feet out in the room, a pedestal basin under a mirrored
                 cabinet, a wicker basket, a heated towel rail, a corner shower (the one step-up).
  b  avocado   — the 70s suite: a panelled bath with a glass screen on its front edge, an avocado toilet
                 + vanity unit, brown flower tiles, orange lino, a mop bucket, a radio on a stool.
  c  gilded    — something silly: a GOLD roll-top on a leopard rug, a gold throne of a toilet, marble,
                 a gilt mirror over a washstand, a champagne bucket by the tub, a chandelier.
  d  wet room  — squalid: a bath with its curtain drawn (hanging INSIDE it), a washing machine spewing
                 clothes, a laundry basket beside it, a basin on iron brackets, black mould.
  e  pink 50s  — a tiled pink bath with its curtain drawn back, a pink suite, a linen cupboard (step-up).
Nodes sit on the fixtures; stand-at fixtures are FRONT nodes — only tall storage is back-plane ('bp').
"""
import math
import os
import random
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import persp
from pixlib import Canvas, hexc, shade, mix, W, H, finish_module, rrect, setback, pp, pbox, pellipse

# --- shared palette ---------------------------------------------------------------------------
PORC = hexc('e1e0d6')
PORC_DK = hexc('bdbcb1')
PORC_LT = hexc('f1f0e8')
PORC_OUT = hexc('6d6c64')
CHROME = hexc('aab0b2')
CHROME_DK = hexc('7a8083')
MIRROR = hexc('8b9aa0')
MIRROR_HI = hexc('b8c3c4')
IRON = hexc('3b3a38')
SEAM = hexc('2a2622')
GLASS = hexc('a9bcbe', 150)
MOULD = hexc('3c4a36', 110)
RUST = hexc('8a5a3a', 140)
BLOOD = hexc('4a1d1b', 150)
TOWELS = [hexc('6e7f95'), hexc('c26b5a'), hexc('d8cfb4'), hexc('7d9a7a'), hexc('b38a5a')]


# --- shared shape helpers ---------------------------------------------------------------------
def rows_shape(c, rows, fill, out=None):
    """rows: {y: (xa, xb)} — fill each row, then a 1px outline round the silhouette."""
    for y, (xa, xb) in rows.items():
        c.hline(xa, xb, y, fill)
    if out is None:
        return
    ys = sorted(rows)
    for i, y in enumerate(ys):
        xa, xb = rows[y]
        c.put(xa, y, out)
        c.put(xb, y, out)
        for ny in (ys[i - 1] if i > 0 else None, ys[i + 1] if i + 1 < len(ys) else None):
            if ny is None:
                c.hline(xa, xb, y, out)
                continue
            na, nb = rows[ny]
            if xa < na:
                c.hline(xa, min(na - 1, xb), y, out)
            if xb > nb:
                c.hline(max(nb + 1, xa), xb, y, out)


def tiled_wall(c, top, tile, tile_dk, grout, trim, size=8, skirting=True):
    c.rect(0, top, W - 1, 93, tile)
    c.rect(0, top, W - 1, top + 2, trim)
    for y in range(top + 3, 94, size):
        c.hline(0, W - 1, y, grout)
    for x in range(0, W, size):
        c.vline(x, top + 3, 93, grout)
    for y in range(top + 4, 93, size * 2):
        c.dither(0, y, W - 1, y + 1, tile_dk, 0.5)
    if skirting:
        c.rect(0, 94, W - 1, 99, trim)
        c.hline(0, W - 1, 94, shade(trim, 1.15))
    c.hline(0, W - 1, 99, SEAM)


def crown(c, col, hi):
    c.rect(0, 0, W - 1, 4, col)
    c.hline(0, W - 1, 4, hi)
    c.hline(0, W - 1, 5, shade(col, 0.8))


# The fixtures stand OUT from the wall in true perspective (owner round 15: "this toilet looks like
# it is painted onto the background"): each is described in wall coordinates + how far it comes out
# (pixlib.pp / pbox / pellipse), so we look DOWN into a basin, onto a seat and a cistern lid, and the
# side facing the middle of the room shows.
def _ipt(p_):
    return (int(round(p_[0])), int(round(p_[1])))


def _wall_x(x, d):
    """The wall-coord x that lands on screen x when brought d px out (callers place fixtures by where
    they SHOW, the old flat coordinates)."""
    return 160 + (x - 160) * 100.0 / (100 + d)


def mirror_cabinet(c, x0, y0, x1, y1, frame, frame_out, open_door=True):
    c.box(x0, y0, x1, y1, frame, frame_out)
    c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, hexc('3a3833'))
    c.hline(x0 + 2, x1, (y0 + y1) // 2 - 5, shade(frame, 0.8))
    c.hline(x0 + 2, x1, (y0 + y1) // 2 + 5, shade(frame, 0.8))
    c.rect(x0 + 4, y0 + 4, x0 + 7, y0 + 9, hexc('c05a3a'))
    c.rect(x0 + 10, y0 + 5, x0 + 12, y0 + 9, hexc('e0d9b8'))
    c.rect(x0 + 15, (y0 + y1) // 2 - 2, x0 + 20, (y0 + y1) // 2 + 4, hexc('6f8fa0'))
    c.rect(x0 + 4, y1 - 7, x0 + 10, y1 - 3, hexc('d9c38a'))
    if open_door == 'left':                                              # hinged on the left, swung open
        c.poly([(x0, y0), (x0 - 7, y0 + 2), (x0 - 7, y1 - 2), (x0, y1)], frame)
        c.poly([(x0 - 1, y0 + 2), (x0 - 6, y0 + 4), (x0 - 6, y1 - 4), (x0 - 1, y1 - 2)], MIRROR)
        c.line(x0 - 2, y1 - 6, x0 - 5, y0 + 6, MIRROR_HI)
    elif open_door:
        c.poly([(x1, y0), (x1 + 7, y0 + 2), (x1 + 7, y1 - 2), (x1, y1)], frame)
        c.poly([(x1 + 1, y0 + 2), (x1 + 6, y0 + 4), (x1 + 6, y1 - 4), (x1 + 1, y1 - 2)], MIRROR)
        c.line(x1 + 2, y1 - 6, x1 + 5, y0 + 6, MIRROR_HI)


def shower_corner(c, x0, x1, top, tile, grout, tray=PORC, tray_out=PORC_OUT):
    c.rect(x0, top, x1, 99, tile)
    for y in range(top + 4, 99, 8):
        c.hline(x0, x1, y, grout)
    pbox(c, x0 - 2, 97, x1 - 5, 100, 0, 8, tray, shade(tray, 1.08), shade(tray, 0.75), tray_out)
    c.rect(x1 - 6, top + 6, x1 - 5, top + 20, CHROME_DK)
    c.rect(x1 - 12, top + 6, x1 - 6, top + 7, CHROME_DK)
    c.rect(x1 - 15, top + 8, x1 - 10, top + 9, CHROME)
    for y in range(top, 96):
        for x in range(x0, x0 + 12):
            c.put(x, y, GLASS)
    c.vline(x0, top, 95, CHROME_DK)
    c.vline(x0 + 12, top, 95, CHROME_DK)
    c.hline(x0, x0 + 12, top, CHROME_DK)
    c.line(x0 + 3, top + 50, x0 + 9, top + 20, hexc('dde6e6'))


# --- FIXTURES BROUGHT FORWARD (owner round 18: "the bathroom scene looks a bit more compact… the
# original design specifications had these items a little more closer to player, meaning we shouldn't
# always be needing to move up to a secondary plane to scavenge"). A toilet, a basin, a bath and a
# washing machine are things you STAND AT, so they come out from the wall toward the walking lane —
# 16-20 px of floor — and are drawn as real solids (tools/art/solid3d.py). Their nodes are FRONT nodes.
import solid3d as S3
import pixlib as PX
from solid3d import P as _P3


def cistern3d(L, wcx, top, bottom, hw, d1, porc):
    """A close-coupled CISTERN (owner round 18: the box one "looks massive, like an air conditioner
    unit"): a rounded body a little narrower than the seat, stood on the back of the pan, and a LID
    that overhangs it all round — its lit top, its rounded front edge, the shadow line under it."""
    lit, dk = shade(porc, 1.12), shade(porc, 0.8)
    for i in range(int(bottom - (top + 2)) + 1):
        y = bottom - i
        plan = S3.rrect_plan(wcx - hw, wcx + hw, 0.0, d1, 2.5, 1.6)
        _shade_poly(L, [S3.P(x, y, d) for (x, d) in plan], lit, porc, dk)
    under = S3.rrect_plan(wcx - hw - 0.8, wcx + hw + 0.8, 0.0, d1 + 0.8, 3.0, 2.0)
    _shade_poly(L, [S3.P(x, top + 2, d) for (x, d) in under], shade(porc, 0.72), shade(porc, 0.66), shade(porc, 0.6))
    for y in (top + 1, top):
        _shade_poly(L, [S3.P(x, y, d) for (x, d) in under], shade(lit, 1.05), shade(porc, 1.06), shade(porc, 0.9))
    a_, b_ = S3.P(wcx - hw + 1, top, d1 + 0.6), S3.P(wcx + hw - 1, top, d1 + 0.6)
    L.hline(a_[0], b_[0], a_[1], shade(porc, 1.25))                                     # its lit front edge


def toilet3d(c, cx, porc=PORC, out=PORC_OUT, lid_up=False, seat=None, lever=CHROME, cistern=True, crest=None):
    """A close-coupled toilet facing the room: the cistern against the wall (0..6 out), the bowl
    coming 20 px out toward us, its seat an oval seen from above, the pan narrowing to its foot."""
    seat = seat or porc
    wcx = S3.wall_x(cx, 12)
    lit, dk = shade(porc, 1.12), shade(porc, 0.78)
    foot = pp(wcx, 100, 12)
    c.shadow(foot[0], foot[1] + 1, 12, 2, 110)
    lay = S3.Layer()
    L = lay.c
    if cistern:
        cistern3d(L, wcx, 71, 84, 8.5, 5.0, porc)
    sl = S3.lerp_slices(100, 93, (6.0, 12.0, 4.0), (6.5, 12.0, 4.5))
    sl += S3.lerp_slices(93, 85, (6.5, 12.0, 4.5), (11.0, 12.5, 7.5), ease=lambda t: t ** 0.55)
    S3.lathe(L, wcx, sl, porc, lit, dk)
    lay.commit(c, out)
    if cistern:
        f = _P3(wcx + 6.5, 74, 5.2)
        c.rect(f[0] - 3, f[1], f[0], f[1] + 1, lever)                              # the flush lever
        c.put(f[0] + 1, f[1], shade(lever, 0.7))
        if crest is not None:                                                       # a moulded front panel + a crown
            a_, b_ = _P3(wcx - 6, 75, 5.1), _P3(wcx + 6, 82, 5.1)
            c.box(a_[0], a_[1], b_[0], b_[1], shade(porc, 1.02), shade(porc, 0.7))
            c.hline(a_[0] + 1, b_[0] - 1, a_[1] + 1, shade(porc, 1.2))
            m_ = ((a_[0] + b_[0]) // 2, (a_[1] + b_[1]) // 2)
            c.hline(m_[0] - 2, m_[0] + 2, m_[1] + 1, crest)
            for dx in (-2, 0, 2):
                c.put(m_[0] + dx, m_[1], crest)
            c.put(m_[0] - 2, m_[1] - 1, crest); c.put(m_[0] + 2, m_[1] - 1, crest); c.put(m_[0], m_[1] - 2, crest)
    # the seat, an oval from above
    ex, ey, erx, ery = S3.ell_geo(wcx, 84.5, 5.0, 20.0, 11.5)
    c.ellipse(ex, ey, erx + 1, ery + 1, out)
    S3.fill_ellipse_shaded(c, ex, ey, erx, ery, shade(seat, 1.12), seat, shade(seat, 0.82))
    if lid_up:
        ix, iy, irx, iry = S3.ell_geo(wcx, 84.5, 7.5, 18.0, 8.0)
        c.ellipse(ix, iy, irx, iry, shade(porc, 0.6))                           # the open pan
        c.ellipse(ix, iy + iry * 0.35, irx * 0.72, iry * 0.55, (96, 110, 100, 255))   # the water
        l0, l1 = _P3(wcx - 9, 70, 6.5), _P3(wcx + 9, 84, 6.5)
        rrect(c, l0[0], l0[1], l1[0], l1[1], out, 3)                             # the lid, up against the cistern
        rrect(c, l0[0] + 1, l0[1] + 1, l1[0] - 1, l1[1] - 1, seat, 3)
        c.hline(l0[0] + 3, l1[0] - 3, l0[1] + 2, shade(seat, 1.14))
    else:
        c.hline(int(ex - erx * 0.55), int(ex + erx * 0.2), int(round(ey - ery)) + 1, shade(seat, 1.22))
        c.hline(int(ex - erx * 0.7), int(ex + erx * 0.7), int(round(ey + ery)), shade(seat, 0.7))
    return wcx


def basin3d(c, wcx, rim=70, porc=PORC, out=PORC_OUT, tap=CHROME, pedestal=True, inside=None, drip=False):
    """A basin coming ~18 px out from the wall, centred on WALL x `wcx` (its tap — hang the mirror
    over the same x): a pedestal (or two wall brackets), the bowl swelling up to its rim, and we look
    DOWN into it — the far inner wall lit, the bottom, the plughole."""
    lit, dk = shade(porc, 1.12), shade(porc, 0.78)
    if not pedestal:                                                               # cast-iron wall brackets, under it
        for sx in (-7, 7):
            a_, b_, m_ = _P3(wcx + sx, rim + 22, 0), _P3(wcx + sx, rim + 10, 7), _P3(wcx + sx, rim + 10, 0)
            c.line(m_[0], m_[1], a_[0], a_[1], IRON)                                  # down the wall
            c.line(a_[0], a_[1], b_[0], b_[1], IRON)                                  # the strut
            c.line(m_[0], m_[1], b_[0], b_[1], shade(IRON, 1.3))                      # the arm under the bowl
    lay = S3.Layer()
    L = lay.c
    if pedestal:
        foot = pp(wcx, 100, 8)
        c.shadow(foot[0], foot[1] + 1, 9, 2, 100)
        sl = S3.lerp_slices(100, 96, (6.0, 8.0, 4.2), (3.6, 8.0, 2.6))
        sl += S3.lerp_slices(96, rim + 12, (3.6, 8.0, 2.6), (3.2, 8.0, 2.3))
        S3.lathe(L, wcx, sl, porc, lit, dk)
    sl = S3.lerp_slices(rim + 12, rim + 1, (4.5, 8.5, 3.0), (14.0, 10.0, 8.5), ease=lambda t: t ** 0.5)
    S3.lathe(L, wcx, sl, porc, lit, dk)
    lay.commit(c, out)
    ex, ey, erx, ery = S3.ell_geo(wcx, rim, 1.0, 19.0, 15.0)
    c.ellipse(ex, ey, erx, ery, out)
    c.ellipse(ex, ey, erx - 1, ery - 0.6, shade(porc, 1.08))                    # the rim
    ix, iy, irx, iry = S3.ell_geo(wcx, rim, 3.5, 16.0, 11.5)
    inside = inside or shade(porc, 0.86)
    c.ellipse(ix, iy, irx, iry, inside)                                           # far inner wall, lit
    c.ellipse(ix, iy + iry * 0.35, irx * 0.72, iry * 0.6, shade(inside, 0.8))     # the bottom
    c.hline(int(ex - erx + 3), int(ex + erx - 3), int(round(ey + ery)) - 1, shade(porc, 1.2))   # the lit front lip
    ph = _P3(wcx, rim + 3, 11)
    c.put(ph[0], ph[1], shade(porc, 0.35))                                         # the plughole
    t0, t1 = _P3(wcx, rim - 6, 2), _P3(wcx, rim, 2)                          # the tap at the back:
    c.rect(t0[0] - 1, t0[1], t0[0] + 1, t1[1], tap)                              # its pillar,
    c.vline(t0[0] + 1, t0[1], t1[1], shade(tap, 0.6))
    s_ = _P3(wcx, rim - 5, 6)
    c.line(t0[0], t0[1], s_[0], s_[1], shade(tap, 0.75))                          # the spout over the bowl
    c.put(s_[0], s_[1] + 1, shade(tap, 0.5))
    c.hline(t0[0] - 2, t0[0] + 2, t0[1] - 1, shade(tap, 1.2))                     # the handle
    if drip:                                                                       # a tap nobody will fix now
        PX.anim(s_[0], s_[1] + 2, 'drip', fall=max(2, int(round(iy + iry * 0.35)) - s_[1] - 2), color='c8dce4')
    return wcx


def bath3d(c, x0, x1, rim, d1=20, body=PORC, lit=PORC_LT, dk=PORC_DK, out=PORC_OUT, inside=None, water=None,
           panel=None):
    """A built-in bath along the wall, its front 20 px out: x0..x1 is where its FRONT shows on screen.
    We look over the front rim INTO it: the far inner wall lit, the bottom, water if any. Returns
    (wall x0, wall x1) and the front face's screen corners."""
    wx0, wx1 = S3.wall_x(x0, d1), S3.wall_x(x1, d1)
    inside = inside or shade(body, 0.82)
    foot = pp((wx0 + wx1) / 2, 100, d1)
    c.shadow(foot[0], foot[1] + 1, (x1 - x0) // 2 + 3, 2, 110)
    f = pbox(c, wx0, rim, wx1, 100, 0, d1, body, lit, dk, out)
    op = S3.rrect_plan(wx0 + 4, wx1 - 4, 3, d1 - 3, 6, 3)
    opening = S3.plan_screen(op, rim)
    c.poly([(int(round(x)), int(round(y))) for (x, y) in opening], shade(inside, 1.1))   # the far inner wall
    bot = S3.rrect_plan(wx0 + 8, wx1 - 8, 5, d1 - 5, 6, 3)
    S3.masked(c, opening, lambda l: S3.plan_poly(l, bot, rim + 14, inside))              # the bottom
    if water is not None:
        wat = S3.rrect_plan(wx0 + 5, wx1 - 5, 3.5, d1 - 3.5, 6, 3)
        S3.masked(c, opening, lambda l: S3.plan_poly(l, wat, rim + 6, water))
    a_, b_ = _P3(wx0 + 4, rim, d1 - 3), _P3(wx1 - 4, rim, d1 - 3)
    c.line(a_[0] + 3, a_[1], b_[0] - 3, b_[1], shade(lit, 1.05))                       # the near lip, lit
    return wx0, wx1, f


def bath_front(c, wx0, wx1, rim, d_from, d1=20, body=PORC, lit=PORC_LT, dk=PORC_DK, out=PORC_OUT):
    """Re-draw the parts of a bath IN FRONT of depth d_from (after a curtain has been hung inside it):
    the two end rims from d_from forward, the front rim, the front face — so the curtain's hem goes
    down INTO the tub, behind the front rim."""
    for (ea, eb) in ((wx0, wx0 + 4), (wx1 - 4, wx1)):
        c.poly([_P3(ea, rim, d_from), _P3(eb, rim, d_from), _P3(eb, rim, d1), _P3(ea, rim, d1)], lit)
    c.poly([_P3(wx0, rim, d1 - 3), _P3(wx1, rim, d1 - 3), _P3(wx1, rim, d1), _P3(wx0, rim, d1)], lit)
    fl, fbr = _P3(wx0, rim, d1), _P3(wx1, 100, d1)
    c.rect(fl[0], fl[1], fbr[0], fbr[1], body)
    for (ea, eb) in ((wx0, wx0 + 4), (wx1 - 4, wx1)):                              # rim inner edges
        q0, q1 = _P3(eb if ea == wx0 else ea, rim, d_from), _P3(eb if ea == wx0 else ea, rim, d1 - 3)
        c.line(q0[0], q0[1], q1[0], q1[1], shade(lit, 0.85))
    c.line(fl[0], fl[1], _P3(wx0, rim, d_from)[0], _P3(wx0, rim, d_from)[1], out)
    c.line(_P3(wx1, rim, d1)[0], fl[1], _P3(wx1, rim, d_from)[0], _P3(wx1, rim, d_from)[1], out)
    c.hline(fl[0], fbr[0], fl[1], out)
    c.hline(fl[0], fbr[0], fbr[1], out)
    c.vline(fl[0], fl[1], fbr[1], out)
    c.vline(fbr[0], fl[1], fbr[1], out)
    c.hline(fl[0] + 1, fbr[0] - 1, fl[1] + 1, shade(lit, 1.05))
    return fl, fbr


def shower_rail(c, wx0, wx1, rail_y, d_r, returns=True):
    """A chrome curtain rail over a bath: a rod along the tub at depth d_r, returning to the wall at
    both ends, a ceiling stay in the middle — clearly a RAIL (owner round 18: a pipe on the wall read
    as one, and the curtain looked higher than it)."""
    a_, b_ = _P3(wx0, rail_y, d_r), _P3(wx1, rail_y, d_r)
    if returns:
        for wx in (wx0, wx1):
            q0, q1 = _P3(wx, rail_y, 0), _P3(wx, rail_y, d_r)
            c.line(q0[0], q0[1], q1[0], q1[1], CHROME_DK)
            c.rect(q0[0] - 1, q0[1] - 1, q0[0] + 1, q0[1] + 1, CHROME_DK)          # the wall flange
    m = _P3((wx0 + wx1) / 2, rail_y, d_r)
    c.vline(m[0], 0, m[1], CHROME_DK)                                             # the ceiling stay
    c.hline(a_[0], b_[0], a_[1], CHROME)
    c.hline(a_[0], b_[0], a_[1] + 1, CHROME_DK)
    return a_[1]


def curtain_in_tub(c, wx0, wx1, rim, d_r, rail_y, col, closed_from, closed_to, bunch_at, d1=20, prints=None):
    """A shower curtain hanging from a rail INSIDE a bath (owner round 17/18: its bottom goes INTO the
    tub, not over its front): from just under the rail down past the rim — the front of the bath is
    re-drawn after it, so the hem disappears behind the front rim. `closed_from`..`closed_to` (wall x)
    is the drawn part, `bunch_at` the end its gathered folds hang at."""
    ry = _P3(wx0, rail_y, d_r)[1]
    top = ry + 2
    hem = _P3(wx0, rim + 10, d_r)[1]
    xa, xb = _P3(closed_from, rail_y, d_r)[0], _P3(closed_to, rail_y, d_r)[0]
    pleated_curtain(c, xa, xb, top, hem, col, period=7)
    for rx_ in range(xa, xb + 1, 7):                                              # rings ON the rail
        c.put(rx_, ry, shade(CHROME, 1.1)); c.put(rx_, ry + 2, CHROME_DK)
    bx = _P3(bunch_at, rail_y, d_r)[0]
    b0, b1 = (bx - 6, bx) if bunch_at > (closed_from + closed_to) / 2 else (bx, bx + 6)
    pleated_curtain(c, b0, b1, top, hem, shade(col, 0.92), period=2, rings=False, wave=0.5)
    return xa, xb, top, hem


def _shade_poly(c, pts, lit, mid, dk):
    """Fill a screen polygon in three vertical bands (lit left, dark right) of its own width."""
    from PIL import Image as _Im, ImageDraw as _ID
    xs = [p_[0] for p_ in pts]
    x0_, x1_ = min(xs), max(xs)
    m = _Im.new('L', (W, H), 0)
    _ID.Draw(m).polygon([(float(x), float(y)) for (x, y) in pts], fill=255)
    bb = m.getbbox()
    if bb is None:
        return
    mp = m.load()
    for y in range(bb[1], bb[3]):
        for x in range(bb[0], bb[2]):
            if mp[x, y]:
                u = (x - x0_) / max(1.0, x1_ - x0_)
                c.put(x, y, lit if u < 0.22 else (mid if u < 0.78 else dk))


def clawfoot3d(c, cx, length, rim, porc, porc_lt, porc_dk, out, feet, inside, water=None, d0=5.0, d1=21.0,
               bubbles=None):
    """A free-standing ROLL-TOP bath on claw feet, out in the room (d0..d1 from the wall): a stack of
    rounded slices swelling up to the rolled lip, the feet under it (the far pair behind), and we
    look down over the lip into it — the far inner wall lit, the water (or the bottom)."""
    wcx = S3.wall_x(cx, (d0 + d1) / 2)
    wx0, wx1 = wcx - length / 2.0, wcx + length / 2.0
    body_bot = rim + 15
    foot_c = pp(wcx, 100, (d0 + d1) / 2)
    c.shadow(foot_c[0], foot_c[1] + 1, int(length * 0.6), 3, 110)

    def _foot(fx, fd, col):
        a_, b_ = _P3(fx, body_bot - 1, fd), _P3(fx, 100, fd)
        c.rect(a_[0] - 1, a_[1], a_[0] + 1, b_[1] - 2, col)
        c.hline(b_[0] - 2, b_[0] + 2, b_[1] - 1, col)                         # the ball and claw
        c.hline(b_[0] - 3, b_[0] + 3, b_[1], shade(col, 0.8))
        c.put(b_[0] - 1, b_[1] - 2, shade(col, 1.3))
    for fx in (wx0 + 9, wx1 - 9):                                             # the far pair, behind
        _foot(fx, d0 + 3, shade(feet, 0.7))
    lay = S3.Layer()
    L = lay.c
    n = int(body_bot - rim)
    for i in range(n + 1):
        t = i / float(n)                                                       # 0 at the bottom, 1 at the lip
        e = t ** 0.45
        ix, idp = 7 * (1 - e), 3.5 * (1 - e)
        y = body_bot - (body_bot - rim) * t
        plan = S3.rrect_plan(wx0 + ix, wx1 - ix, d0 + idp, d1 - idp, 10, 5)
        col = porc if t > 0.35 else shade(porc, 0.86 + 0.4 * t)
        _shade_poly(L, [S3.P(x, y, d) for (x, d) in plan], shade(col, 1.1), col, shade(col, 0.8))
    lay.commit(c, out)
    lip = S3.rrect_plan(wx0 - 1, wx1 + 1, d0 - 0.5, d1 + 0.5, 11, 5.5)
    c.poly([S3.P(x, rim, d) for (x, d) in lip], out)
    lip2 = S3.rrect_plan(wx0, wx1, d0, d1, 10, 5)
    c.poly([S3.P(x, rim, d) for (x, d) in lip2], porc_lt)                      # the rolled lip
    op = S3.rrect_plan(wx0 + 4, wx1 - 4, d0 + 2.5, d1 - 2.5, 8, 3.5)
    opening = [S3.P(x, rim, d) for (x, d) in op]
    c.poly(opening, shade(inside, 1.15))                                      # the far inner wall
    if water is not None:
        wat = S3.rrect_plan(wx0 + 5, wx1 - 5, d0 + 3, d1 - 3, 8, 3.5)
        S3.masked(c, opening, lambda l: S3.plan_poly(l, wat, rim + 5, water))
        ww = S3.P(wcx - length * 0.25, rim + 5, (d0 + d1) / 2)
        c.hline(ww[0], ww[0] + 6, ww[1] + 1, shade(water, 1.2))               # a glint on it
    else:
        bot = S3.rrect_plan(wx0 + 9, wx1 - 9, d0 + 5, d1 - 5, 8, 3)
        S3.masked(c, opening, lambda l: S3.plan_poly(l, bot, rim + 13, inside))
    fr0, fr1 = S3.P(wx0 + 6, rim, d1 - 0.5), S3.P(wx1 - 6, rim, d1 - 0.5)
    c.hline(fr0[0], fr1[0], fr0[1], shade(porc_lt, 1.1))                       # the lip's lit front edge
    c.hline(fr0[0], fr1[0], fr0[1] + 2, shade(porc, 0.8))                      # its shadow under the roll
    for fx in (wx0 + 9, wx1 - 9):                                              # the near pair, in front
        _foot(fx, d1 - 3, feet)
    return wx0, wx1, opening


def vanity3d(c, x0, x1, top, d1=16, wood=hexc('c9b48a'), wood_dk=hexc('9a8660'), basin=None, basin_out=None):
    """A vanity unit standing out from the wall (owner round 18: the first read as a plain box):
    a tiled upstand along the wall behind it, a worktop slab overhanging the cupboard with the basin
    SET INTO it (we look down into the bowl), two panelled doors — one swung open on a mess of
    bleach and sponges — over a recessed plinth."""
    basin = basin or AVO
    basin_out = basin_out or AVO_OUT
    top_col = hexc('e0d6c0')
    wx0, wx1 = S3.wall_x(x0, d1), S3.wall_x(x1, d1)
    foot = pp((wx0 + wx1) / 2, 100, d1)
    c.shadow(foot[0], foot[1] + 1, (x1 - x0) // 2 + 2, 2, 110)
    pbox(c, wx0 - 1, top - 5, wx1 + 1, top, 0, 1.5, hexc('d8cfb8'), hexc('efe8d8'), hexc('b9b09a'), wood_dk)   # the upstand
    pbox(c, wx0 + 1, 96, wx1 - 1, 100, 0, d1 - 3, hexc('3a3228'), None, hexc('2a241c'))            # the plinth, set back
    f = pbox(c, wx0, top + 2, wx1, 96, 0, d1 - 1, wood, top_col, shade(wood, 0.72), wood_dk)        # the cupboard
    g = pbox(c, wx0 - 1, top, wx1 + 1, top + 2, 0, d1, top_col, shade(top_col, 1.06), shade(top_col, 0.8), wood_dk)   # the worktop
    fl, fr, fbr = f['fl'], f['fr'], f['fbr']
    c.hline(g['fl'][0] + 1, g['fr'][0] - 1, g['fl'][1] + 1, shade(top_col, 1.12))       # its lit front edge
    wcx = (wx0 + wx1) / 2
    ex, ey, erx, ery = S3.ell_geo(wcx, top, 3.0, d1 - 3.0, (wx1 - wx0) / 2 - 5)
    c.ellipse(ex, ey, erx, ery, basin_out)
    c.ellipse(ex, ey, erx - 1, ery - 0.6, basin)
    c.ellipse(ex, ey + 0.5, erx - 3, ery - 1.5, shade(basin, 0.8))                    # the bowl, from above
    c.ellipse(ex, ey + ery * 0.3, erx - 5, max(0.8, ery - 2.5), shade(basin, 0.65))
    t0 = _P3(wcx, top - 6, 1.5)
    c.rect(t0[0] - 1, t0[1], t0[0] + 1, t0[1] + 5, CHROME)
    s_ = _P3(wcx, top - 5, 5)
    c.line(t0[0], t0[1], s_[0], s_[1], CHROME_DK)
    mid = (fl[0] + fr[0]) // 2
    d_top, d_bot = fl[1] + 2, fbr[1] - 2
    c.box(fl[0] + 2, d_top, mid - 1, d_bot, wood, wood_dk)                            # the left door, panelled
    c.box(fl[0] + 5, d_top + 3, mid - 4, d_bot - 3, wood, wood_dk)
    c.hline(fl[0] + 6, mid - 5, d_top + 4, shade(wood, 1.12))
    c.rect(mid - 4, d_top + 6, mid - 3, d_top + 10, CHROME_DK)                        # its handle
    c.rect(mid + 1, d_top, fr[0] - 2, d_bot, hexc('3a3228'))                           # the other stands open:
    c.hline(mid + 1, fr[0] - 2, (d_top + d_bot) // 2 + 2, shade(wood, 0.6))           # a shelf inside,
    c.rect(mid + 3, d_top + 5, mid + 7, (d_top + d_bot) // 2 + 1, hexc('e8e0d0'))      # bleach, a sponge
    c.rect(mid + 9, d_top + 9, mid + 14, (d_top + d_bot) // 2 + 1, hexc('d9c24a'))
    c.rect(mid + 4, (d_top + d_bot) // 2 + 4, mid + 12, d_bot - 1, hexc('7ab0c8'))      # a bottle lying down
    c.poly([(fr[0], d_top), (fr[0] + 6, d_top + 3), (fr[0] + 6, d_bot + 2), (fr[0], d_bot)], wood)   # the door, swung out
    c.poly([(fr[0] + 1, d_top + 3), (fr[0] + 4, d_top + 5), (fr[0] + 4, d_bot - 1), (fr[0] + 1, d_bot - 3)], shade(wood, 0.9))
    c.line(fr[0], d_top, fr[0] + 6, d_top + 3, wood_dk)
    c.line(fr[0] + 6, d_top + 3, fr[0] + 6, d_bot + 2, wood_dk)
    return f


def washstand3d(c, x0, x1, top, d1=14):
    """A gilt washstand: a marble slab on cabriole legs, standing out from the wall, a gold basin set
    into the marble (we look down into it), a drawer in the apron, a perfume bottle."""
    wx0, wx1 = S3.wall_x(x0, d1), S3.wall_x(x1, d1)
    foot = pp((wx0 + wx1) / 2, 100, d1 / 2)
    c.shadow(foot[0], foot[1] + 1, (x1 - x0) // 2 + 2, 2, 100)
    for (lx, ld, col) in ((wx0 + 2, 1.5, GOLD_DK), (wx1 - 2, 1.5, GOLD_DK)):          # the back legs
        a_, b_ = _P3(lx, top + 4, ld), _P3(lx, 100, ld)
        c.line(a_[0], a_[1], b_[0], b_[1], col)
    f = pbox(c, wx0, top + 4, wx1, top + 10, 0, d1 - 1, hexc('f0ebe0'), None, shade(hexc('f0ebe0'), 0.8), GOLD_DK)   # the apron
    c.box(f['fl'][0] + 4, f['fl'][1] + 1, f['fr'][0] - 4, f['fbr'][1] - 1, hexc('f0ebe0'), GOLD_DK)   # a drawer
    mx = (f['fl'][0] + f['fr'][0]) // 2
    c.hline(mx - 1, mx + 1, (f['fl'][1] + f['fbr'][1]) // 2, GOLD)
    for (lx, sgn) in ((wx0 + 2, 1), (wx1 - 2, -1)):                                  # the front legs, cabriole
        a_, m_, b_ = _P3(lx, top + 10, d1 - 1.5), _P3(lx + 2 * sgn, 94, d1 - 1.5), _P3(lx, 100, d1 - 1.5)
        c.line(a_[0], a_[1], m_[0], m_[1], GOLD)
        c.line(m_[0], m_[1], b_[0], b_[1], GOLD)
        c.line(a_[0] + 1, a_[1], m_[0] + 1, m_[1], GOLD_DK)
    g = pbox(c, wx0 - 1, top, wx1 + 1, top + 3, 0, d1, MARBLE, shade(MARBLE, 1.05), MARBLE_DK, hexc('9a9486'))   # the marble slab
    c.hline(g['fl'][0] + 1, g['fr'][0] - 1, g['fl'][1] + 1, VEIN)
    wcx = (wx0 + wx1) / 2
    ex, ey, erx, ery = S3.ell_geo(wcx, top, 2.5, d1 - 2.5, 9)
    c.ellipse(ex, ey, erx, ery, GOLD_OUT)
    c.ellipse(ex, ey, erx - 1, ery - 0.5, GOLD)
    c.ellipse(ex, ey + 0.5, erx - 3, max(0.8, ery - 1.5), GOLD_DK)                     # the gold bowl
    t0 = _P3(wcx, top - 7, 1.5)
    c.rect(t0[0] - 1, t0[1], t0[0] + 1, t0[1] + 6, GOLD)
    s_ = _P3(wcx, top - 6, 5)
    c.line(t0[0], t0[1], s_[0], s_[1], GOLD_LT)
    pb = _P3(wx0 + 4, top, 5)
    c.rect(pb[0] - 1, pb[1] - 5, pb[0] + 2, pb[1] - 1, hexc('b8d0d8'))                # perfume
    c.put(pb[0], pb[1] - 6, GOLD)
    return g


def washing_machine3d(c, x0, top=66, d1=11, body=hexc('e6e4dc'), out=hexc('6d6c64'), door_open=True):
    """A front-loader standing out from the wall (owner round 18: the first one was "a big blocky
    cube" with a small door on it). Its FACE is the washing machine: a control panel across the top
    (soap drawer, a little display, the programme dial), a big porthole — chrome bezel, rubber seal,
    the steel drum with its holes — filling most of the front; rounded corners, a kick plate; the
    side is shaded as a turned surface, and the door hangs wide open on its hinge."""
    wx0 = S3.wall_x(x0, d1)
    wx1 = wx0 + 26
    foot = pp((wx0 + wx1) / 2, 100, d1)
    c.shadow(foot[0], foot[1] + 1, 16, 2, 110)
    f = pbox(c, wx0, top, wx1, 100, 0, d1, body, shade(body, 1.05), shade(body, 0.74), out)
    fl, fr, fbr, bl = f['fl'], f['fr'], f['fbr'], f['bl']
    bb = S3.P(wx0, 100, 0)
    for x in range(bl[0] + 1, fl[0]):                     # the side: darker toward the wall
        t = (x - bl[0]) / max(1.0, fl[0] - bl[0])
        yt = int(round(bl[1] + (fl[1] - bl[1]) * t)) + 1
        yb = int(round(bb[1] + (fbr[1] - bb[1]) * t)) - 1
        c.vline(x, yt, yb, shade(body, 0.64 + 0.12 * t))
    sq = S3.P(wx0, top + 7, 0)
    c.line(sq[0], sq[1], fl[0], fl[1] + 7, shade(body, 0.56))           # the panel seam round the side
    for (px_, py_) in ((fl[0], fl[1]), (fr[0], fl[1]), (fl[0], fbr[1]), (fr[0], fbr[1])):   # rounded corners
        c.put(px_, py_, shade(body, 0.8))
    wdt = fr[0] - fl[0]
    py0 = fl[1] + 1                                                      # the control panel
    c.rect(fl[0] + 1, py0, fr[0] - 1, py0 + 6, shade(body, 0.95))
    c.hline(fl[0] + 1, fr[0] - 1, py0 + 7, shade(body, 0.7))
    c.rect(fl[0] + 3, py0 + 2, fl[0] + 10, py0 + 5, shade(body, 0.86))                    # the soap drawer
    c.hline(fl[0] + 5, fl[0] + 8, py0 + 4, shade(body, 0.6))
    c.rect(fl[0] + 13, py0 + 2, fl[0] + 17, py0 + 4, hexc('2a3a34'))                       # the display
    c.put(fl[0] + 14, py0 + 3, hexc('7ac08a'))
    dx_ = fr[0] - 5
    c.ellipse(dx_, py0 + 3, 2.6, 2.6, shade(body, 0.62))                                   # the programme dial
    c.ellipse(dx_, py0 + 3, 1.8, 1.8, hexc('c9c7c0'))
    c.put(dx_, py0 + 2, hexc('3a3a3a'))
    cx_ = (fl[0] + fr[0]) // 2                                            # the porthole — most of the face
    cy_ = (py0 + 8 + fbr[1] - 4) // 2
    r = int(round(wdt * 0.40))
    c.ellipse(cx_, cy_, r + 1, r + 1, shade(body, 0.72))
    c.ellipse(cx_, cy_, r, r, hexc('b9bec2'))                                             # chrome bezel
    c.ellipse(cx_ - 0.5, cy_ - 0.5, r - 1, r - 1, hexc('d9dde0'))
    c.ellipse(cx_, cy_, r - 2, r - 2, hexc('2a2c2e'))                                     # rubber seal
    c.ellipse(cx_, cy_, r - 3.5, r - 3.5, hexc('5a6064'))                                 # the drum
    c.ellipse(cx_ + 0.5, cy_ + 0.5, r - 5, r - 5, hexc('3e4448'))
    for k in range(-r + 5, r - 4, 3):
        for j in range(-r + 5, r - 4, 3):
            if k * k + j * j < (r - 5) ** 2:
                c.put(cx_ + k, cy_ + j, hexc('2e3236'))
    c.rect(fl[0] + 3, fbr[1] - 4, fr[0] - 3, fbr[1] - 2, shade(body, 0.86))              # the kick plate
    c.hline(fl[0] + 3, fr[0] - 3, fbr[1] - 4, shade(body, 0.7))
    if door_open:                                                         # swung wide on its hinge
        hx = cx_ - r
        c.rect(hx - 1, cy_ - 3, hx, cy_ + 3, hexc('8a8e92'))
        ex, ey = hx - 5, cy_ + 2
        c.ellipse(ex, ey, 5, r + 1, hexc('8a8e92'))
        c.ellipse(ex, ey, 3.8, r - 0.5, hexc('d9dde0'))
        c.ellipse(ex + 0.5, ey, 2.4, r - 2.5, hexc('7a8e96'))
        c.line(ex - 1, ey - r + 4, ex - 1, ey - 2, hexc('b8cad0'))
        c.rect(ex - 5, ey - 1, ex - 4, ey + 2, hexc('6a6e72'))
    return cx_, cy_, fl, fr, fbr


# ============================================================================================
# A — classic
# ============================================================================================
A_PAINT = hexc('9fa89a')
A_PAINT_TOP = hexc('8d9688')
A_TILE = hexc('c9cdc0')
A_TILE_DK = hexc('b4b8ab')
A_GROUT = hexc('8d9185')
A_TRIM = hexc('5d7d78')
A_MOS_A = hexc('d3d4cb')
A_MOS_B = hexc('3f4a4d')
A_MOS_G = hexc('9ea196')


def a_wall(c):
    c.rect(0, 0, W - 1, 93, A_PAINT)
    c.rect(0, 6, W - 1, 8, A_PAINT_TOP)
    c.dither(0, 9, W - 1, 13, A_PAINT_TOP, 0.5)
    crown(c, hexc('6f776b'), hexc('858d80'))
    tiled_wall(c, 40, A_TILE, A_TILE_DK, A_GROUT, A_TRIM)
    # decay: black mould from the ceiling corners and along the grout, a cracked tile
    mould_bloom(c, 3, 7, 34, 14, seed=11)
    mould_bloom(c, W - 4, 7, 32, 18, seed=12)
    c.line(150, 48, 158, 60, A_GROUT)                                    # a cracked tile
    c.line(158, 60, 155, 66, A_GROUT)


def mosaic_floor(c, a, b, g):
    c.rect(0, 100, W - 1, H - 1, a)
    rows = [100, 104, 109, 115, 122, 130, 139, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, W, 8):
            col = b if ((x // 8) % 4 == (r % 2) * 2) else a
            c.rect(x, y0, x + 7, y1, col)
            c.vline(x, y0, y1, g)
        c.hline(0, W - 1, y0, g)
    c.hline(0, W - 1, 100, shade(a, 0.55))
    c.hline(0, W - 1, 101, shade(a, 0.75))


@persp
def a_floor(c):
    mosaic_floor(c, A_MOS_A, A_MOS_B, A_MOS_G)


def hung_towel(c, x0, x1, top, bot, col, back_drop=3):
    """A towel folded over a bar (owner round 16: flat towels read as stickers): the rounded fold over
    the bar lit on top, the front half hanging with a soft crease, the back half hanging a little
    lower behind it on one side, a woven band near the hem and a thin shadow down the far edge."""
    lt, dk = shade(col, 1.14), shade(col, 0.8)
    c.rect(x1 - 2, top + 2, x1, bot + back_drop, dk)                       # the back half, lower
    c.rect(x0, top, x1 - 1, bot, col)
    c.hline(x0 + 1, x1 - 2, top, lt)                                        # the fold over the bar
    c.hline(x0, x1 - 1, top + 1, shade(col, 1.06))
    c.hline(x0, x1 - 1, top + 2, dk)                                        # its shadow under the fold
    c.vline(x0, top + 1, bot, lt)
    c.vline(x1 - 1, top + 3, bot, dk)
    cx_ = (x0 + x1) // 2
    c.line(cx_, top + 4, cx_ - 1, bot - 3, shade(col, 0.9))                 # a soft crease
    c.hline(x0, x1 - 1, bot - 3, shade(col, 0.86))                          # the woven band
    c.hline(x0, x1 - 1, bot - 2, shade(col, 1.08))
    for x in range(x0, x1, 2):                                             # the fringe
        c.put(x, bot + 1, dk)


def towel_rail(c, x0, x1, top, bar=CHROME, bar_dk=CHROME_DK, towels=(0, 2)):
    """A heated towel rail on the wall (under the R window box) with towels hung over it."""
    c.vline(x0, top, 97, bar_dk)
    c.vline(x1, top, 97, bar_dk)
    for y in range(top + 2, 96, 6):
        c.hline(x0, x1, y, bar)
    for i, ti in enumerate(towels):
        tx0 = x0 + 3 + i * ((x1 - x0) // 2)
        hung_towel(c, tx0, tx0 + 11, top + 1, top + 21 - i * 4, TOWELS[ti])


def wicker_basket(c, x0, x1, top, base):
    wk, wk_dk = hexc('b39a6a'), hexc('8a7348')
    c.shadow((x0 + x1) // 2, base, (x1 - x0) // 2 + 2, 2, 110)
    c.poly([(x0, top), (x1, top), (x1 - 2, base), (x0 + 2, base)], wk)
    for y in range(top + 2, base, 3):
        c.hline(x0 + 1, x1 - 1, y, wk_dk)
    for x in range(x0 + 3, x1 - 1, 4):
        c.vline(x, top + 1, base - 1, shade(wk, 0.9))
    c.rect(x0 - 1, top - 1, x1 + 1, top + 1, wk_dk)
    # clothes spilling over the rim
    c.poly([(x0 + 2, top - 1), (x0 + 9, top - 5), (x0 + 14, top - 2), (x0 + 12, top + 3)], TOWELS[1])
    c.poly([(x0 + 12, top - 2), (x1 - 3, top - 6), (x1 + 2, top + 6), (x1 - 2, top + 9)], TOWELS[0])
    c.put(x1 + 1, top + 7, shade(TOWELS[0], 0.8))


def a_build(c):
    a_wall(c)
    a_floor(c)
    mirror_cabinet(c, 24, 24, 48, 54, hexc('d6d2c4'), PORC_OUT, open_door='left')   # over the tap
    basin3d(c, 36, rim=70)
    c.ellipse(34, 76, 2, 1, BLOOD)
    toilet3d(c, 72)
    toilet_roll(c, 96, 80)                                              # the roll on its holder by the cistern
    # a short roll-top bath standing out in the room on its claw feet; the hand shower on the wall
    # over it, its hose hanging down to the tap end
    x0 = 112
    c.rect(186, 50, 187, 70, CHROME_DK)                                   # the riser + hand shower
    c.rect(184, 48, 189, 50, CHROME)
    c.line(187, 71, 182, 80, CHROME_DK)
    wx0, wx1, opening = clawfoot3d(c, 150, 64, 80, PORC, PORC_LT, PORC_DK, PORC_OUT, IRON, hexc('4d5a52'),
                                   water=hexc('6a7b5e'))
    tp = _P3(wx1 - 3, 80, 13)                                             # standing taps at the right end
    c.rect(tp[0] - 1, tp[1] - 6, tp[0] + 1, tp[1] - 1, CHROME)
    c.line(tp[0], tp[1] - 6, tp[0] - 4, tp[1] - 3, CHROME)
    c.put(tp[0] - 4, tp[1] - 2, CHROME_DK)
    # a towel slung over the left end, hanging down its side; a streak of blood down the bath
    e0 = _P3(wx0 + 2, 80, 13)
    c.poly([(e0[0] - 2, e0[1] - 2), (e0[0] + 8, e0[1] - 3), (e0[0] + 9, e0[1] + 13), (e0[0] - 1, e0[1] + 15)], TOWELS[3])
    c.vline(e0[0] + 8, e0[1] - 2, e0[1] + 13, shade(TOWELS[3], 0.8))
    c.hline(e0[0] - 1, e0[0] + 8, e0[1] - 2, shade(TOWELS[3], 1.15))
    c.line(152, 102, 154, 112, BLOOD)
    setback(c, lambda l: wicker_basket(l, 198, 222, 84, 100), depth=3, top=84)   # against the wall, under the rail
    towel_rail(c, 232, 262, 70)
    shower_corner(c, 274, 308, 16, shade(A_TILE, 0.95), A_GROUT)
    mould_bloom(c, 291, 97, 16, 7, seed=13, up=True)                     # black mould along the shower's tray
    c.rect(278, 56, 283, 62, hexc('d7c2a0'))                          # soap on the ledge
    c.rect(276, 62, 285, 63, CHROME_DK)
    import furn as F
    F.flush_light(c, 130)                                               # a ceiling dome
    return c


def a_bare(c):
    a_wall(c)


A_ANCHORS = [('anchor_wall_cabinet', 27, 48, ''), ('anchor_wall_sink', 27, 74, ''),
             ('anchor_centre_toilet', 70, 92, ''), ('anchor_bath_left', 132, 88, ''),
             ('anchor_bath_right', 168, 88, ''), ('anchor_floor_laundrybag', 210, 88, ''),
             ('anchor_wall_shower', 291, 68, 'bp')]


# ============================================================================================
# B — avocado (the 70s suite)
# ============================================================================================
AVO = hexc('8a9a4a')
AVO_LT = hexc('a3b25e')
AVO_DK = hexc('6c7a38')
AVO_OUT = hexc('3f4822')
B_TILE = hexc('b8906a')          # brown-beige tiles with a flower motif
B_TILE_DK = hexc('a07b58')
B_GROUT = hexc('7a5e45')
B_FLOWER = hexc('d9a24a')
B_TRIM = hexc('6a4a30')
B_PAINT = hexc('d8b98a')
B_LINO_A = hexc('b8683a')
B_LINO_B = hexc('9a522c')
B_LINO_C = hexc('d18a4e')


def b_wall(c):
    c.rect(0, 0, W - 1, 93, B_PAINT)
    c.dither(0, 6, W - 1, 12, shade(B_PAINT, 0.9), 0.5)
    crown(c, hexc('9a7a58'), hexc('b89870'))
    tiled_wall(c, 34, B_TILE, B_TILE_DK, B_GROUT, B_TRIM, size=10)
    for y in range(37, 94, 20):                                        # a flower tile every other row
        for x in range(4 + ((y // 20) % 2) * 20, W, 40):
            c.put(x + 1, y + 3, B_FLOWER)
            for (dx, dy) in ((0, 2), (2, 2), (1, 1), (1, 3)):
                c.put(x + dx + 1, y + dy + 1, B_FLOWER)
            c.put(x + 2, y + 4, hexc('7a3a20'))
    # decay: a tile fallen off, a brown damp patch in the paint
    c.rect(150, 57, 158, 65, hexc('8a7a68'))
    c.dither(150, 57, 158, 65, hexc('6e6252'), 0.5)
    for i in range(5):
        c.ellipse(200 + i * 5, 14 + (i % 2) * 3, 6, 4, hexc('7a5a3a', 60))


@persp
def b_floor(c):
    # orange lino: a repeating 16px geometric of squares-in-squares (repeats every 32px)
    c.rect(0, 100, W - 1, H - 1, B_LINO_A)
    rows = [100, 105, 111, 118, 126, 135, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, W, 16):
            col = B_LINO_B if ((x // 16) + r) % 2 else B_LINO_A
            c.rect(x, y0, x + 15, y1, col)
            c.rect(x + 5, y0 + (y1 - y0) // 3, x + 10, y1 - (y1 - y0) // 3, B_LINO_C)
        c.hline(0, W - 1, y0, shade(B_LINO_A, 0.8))
    c.hline(0, W - 1, 100, shade(B_LINO_A, 0.5))
    c.hline(0, W - 1, 101, shade(B_LINO_A, 0.72))


def pleated_curtain(c, x0, x1, top, bot, col, period=6, rings=True, wave=1.5):
    """A curtain hanging from a rail in soft vertical FOLDS (owner round 16: the flat panels "need
    fixing"): each fold lit on its crest and shadowed in its trough, the top scalloped between the
    rings, the hem swinging a little, a darker hem band. A tight `period` = a bunched-up curtain."""
    import math as _m
    for x in range(x0, x1 + 1):
        ph = ((x - x0) % period) / float(period)
        f = 0.80 + 0.30 * (0.5 + 0.5 * _m.cos(2 * _m.pi * ph))
        t = top + (1 if 0.3 < ph < 0.7 else 0)
        b = bot + int(round(wave * _m.sin(2 * _m.pi * (x - x0) / (period * 2.3))))
        c.vline(x, t, b, shade(col, f))
        c.vline(x, b - 2, b, shade(col, f * 0.86))
        c.put(x, b, shade(col, f * 0.7))
    if rings:
        for x in range(x0, x1 + 1, period):
            c.put(x, top - 1, CHROME)
            c.put(x, top, CHROME_DK)


def toilet_roll(c, x, y, paper=hexc('ece6d6')):
    """A roll on a wall holder, seen from the front: the chrome arm, the roll's end (the card tube
    showing), the paper's curve and a sheet hanging down."""
    c.hline(x - 1, x + 7, y - 1, CHROME_DK)                                      # the arm
    c.put(x - 1, y, CHROME_DK)
    rrect(c, x, y, x + 7, y + 5, shade(paper, 0.78), 2)
    rrect(c, x, y, x + 6, y + 4, paper, 2)
    c.hline(x + 1, x + 5, y, shade(paper, 1.05))
    c.ellipse(x + 6, y + 2, 1.5, 2.4, shade(paper, 0.9))                        # the end, facing the room
    c.put(x + 6, y + 2, hexc('9a7a52'))                                         # the card tube
    c.rect(x + 1, y + 5, x + 4, y + 8, paper)                                   # a sheet hanging down
    c.hline(x + 1, x + 4, y + 8, shade(paper, 0.8))


def standing_rolls(c, x, base, n=3, paper=hexc('d8d2c2')):
    """Spare rolls stacked on the floor against the wall: a pyramid of short cylinders from above."""
    spots = [(0, 0), (8, 0), (4, -6)][:n]
    for (dx, dh) in spots:
        cx_, bt = x + dx + 3, base + dh
        c.rect(cx_ - 3, bt - 6, cx_ + 3, bt, paper)
        c.vline(cx_ + 3, bt - 6, bt, shade(paper, 0.8))
        c.hline(cx_ - 3, cx_ + 3, bt, shade(paper, 0.7))
        c.ellipse(cx_, bt - 6, 3.4, 1.4, shade(paper, 1.08))
        c.put(cx_, bt - 6, hexc('9a7a52'))


def mop_bucket(c, x0, base):
    """A round red mop bucket standing a little out from the wall (owner round 16: the flat one
    "still looks like a sticker"): we look down into it — the rim, grey water inside, the mop's head
    sunk in it and its handle leant back against the wall, the wire handle, a wringer on one side."""
    red, red_dk, red_lt, red_out = hexc('c0453a'), hexc('8a2e26'), hexc('d8625a'), hexc('5a1c16')
    cx = _wall_x(x0 + 9, 6)
    foot = pp(cx, 100, 6)
    c.shadow(foot[0], foot[1] + 1, 11, 2, 110)
    # the handle of the mop, leant back against the wall (drawn first: the bucket's rim is in front)
    top_ = _ipt(pp(cx + 12, 48, 0))
    c.line(top_[0], top_[1], _ipt(pp(cx + 2, 88, 6))[0], _ipt(pp(cx + 2, 88, 6))[1], hexc('c9b48a'))
    c.line(top_[0] + 1, top_[1], _ipt(pp(cx + 3, 88, 6))[0], _ipt(pp(cx + 3, 88, 6))[1], hexc('a8946a'))
    # the tapered body, darker toward the side away from the light
    b0, b1 = _ipt(pp(cx - 9, 88, 9)), _ipt(pp(cx + 9, 88, 9))
    f0, f1 = _ipt(pp(cx - 7, 100, 8)), _ipt(pp(cx + 7, 100, 8))
    body = [b0, b1, f1, f0]
    c.poly(body, red)
    for k in range(3):
        c.line(b1[0] - 1 - k, b1[1] + 1, f1[0] - 1 - k, f1[1], red_dk if k < 2 else shade(red, 0.9))
    c.line(b0[0] + 1, b0[1] + 1, f0[0] + 1, f0[1] - 1, red_lt)
    c.line(*b0, *f0, red_out)
    c.line(*b1, *f1, red_out)
    c.hline(f0[0], f1[0], f1[1], red_out)
    c.hline(b0[0] + 1, b1[0] - 1, b0[1] + 4, red_dk)                  # a moulded ring
    # the rim + the water from above, the mop head sunk in it
    pellipse(c, cx, 88, 1, 11, 10, red_out)
    pellipse(c, cx, 88, 2, 10, 9, red_lt)
    wx, wy, wrx, wry = pellipse(c, cx, 88, 3, 9, 7, hexc('5a6a5a'))
    c.hline(int(wx - wrx + 2), int(wx + 1), int(round(wy - wry)) + 1, hexc('7a8a78'))   # a glint on the water
    mh = _ipt(pp(cx + 2, 88, 6))
    c.poly([(mh[0] - 4, mh[1] - 1), (mh[0] + 4, mh[1] - 1), (mh[0] + 5, mh[1] + 1), (mh[0] - 5, mh[1] + 1)], hexc('cfc5a6'))
    for k in (-3, -1, 1, 3):
        c.put(mh[0] + k, mh[1] + 1, hexc('b0a684'))
    # the wire handle, lying back against the rim
    h0, h1 = _ipt(pp(cx - 9, 88, 3)), _ipt(pp(cx + 9, 88, 3))
    c.line(h0[0], h0[1], (h0[0] + h1[0]) // 2, h0[1] - 5, hexc('8a8a86'))
    c.line((h0[0] + h1[0]) // 2, h0[1] - 5, h1[0], h1[1], hexc('8a8a86'))

def b_build(c):
    b_wall(c)
    b_floor(c)
    # a round mirror with a shelf under it, over the vanity's tap
    c.ellipse(39, 38, 9.5, 9.5, hexc('9a8660'))
    c.ellipse(39, 38, 7.5, 7.5, MIRROR)
    c.line(34, 43, 42, 32, MIRROR_HI)
    c.line(35, 33, 44, 42, shade(MIRROR, 0.8))                           # cracked
    c.rect(28, 52, 49, 53, hexc('e0d6c0'))
    c.rect(31, 47, 34, 51, hexc('e8a0b0')); c.rect(39, 48, 41, 51, hexc('7ab0c8'))
    vanity3d(c, 6, 50, 72)
    toilet3d(c, 84, porc=AVO, out=AVO_OUT, lid_up=True, seat=hexc('d9cfa8'))
    toilet_roll(c, 106, 78)                                              # a roll on its holder by the cistern
    mop_bucket(c, 110, 100)                                              # by the toilet, against the wall
    # the panelled bath along the wall, its front 20 px out, a glass screen standing on its front edge
    # at the tap end; a shaggy mat on the floor in front of it
    x0, x1, rim = 152, 248, 78
    tx = int(round(S3.wall_x(x0, 20)))
    wx0, wx1, f = bath3d(c, x0, x1, rim, body=AVO, lit=AVO_LT, dk=AVO_DK, out=AVO_OUT, inside=hexc('5f6a34'))
    c.rect(tx + 4, rim - 7, tx + 6, rim - 1, CHROME)                       # taps on the wall at the left end
    c.rect(tx + 10, rim - 7, tx + 12, rim - 1, CHROME)
    c.hline(tx + 3, tx + 13, rim - 7, CHROME_DK)
    c.rect(tx + 2, 30, tx + 3, rim - 8, CHROME_DK)                          # a shower riser
    c.rect(tx + 1, 30, tx + 7, 32, CHROME)
    fl, fr, fbr = f['fl'], f['fr'], f['fbr']
    c.box(fl[0] + 4, fl[1] + 4, fr[0] - 4, fbr[1] - 4, AVO, AVO_DK)        # the moulded front panel
    c.dither(fl[0] + 5, fbr[1] - 8, fr[0] - 5, fbr[1] - 5, AVO_DK, 0.5)
    bx, by = fl[0], fbr[1]                                               # kicked in at one corner
    c.poly([(bx + 10, by - 1), (bx + 16, by - 12), (bx + 26, by - 10), (bx + 30, by - 1)], hexc('1e1a16'))
    c.line(bx + 16, by - 12, bx + 26, by - 10, AVO_LT)
    s0, s1 = _P3(wx0 + 2, 34, 19), _P3(wx0 + 26, rim, 19)                   # the screen, on the front edge
    for y in range(s0[1], s1[1]):
        for x in range(s0[0], s1[0] + 1):
            c.put(x, y, GLASS)
    c.vline(s1[0], s0[1], s1[1] - 1, CHROME_DK)
    c.hline(s0[0], s1[0], s0[1], CHROME_DK)
    c.vline(s0[0], s0[1], s1[1] - 1, CHROME_DK)
    c.line(s0[0] + 4, s1[1] - 8, s0[0] + 12, s0[1] + 8, hexc('dde6e6'))
    c.poly([(158, 123), (226, 123), (230, 129), (154, 129)], hexc('d9a24a'))  # the mat, flat on the floor
    c.dither(158, 124, 228, 128, hexc('b8863a'), 0.5)
    stool_radio3d(c, 276)                                                # a radio on a stool by the bath
    wicker_hamper3d(c, 300)                                              # the laundry hamper in the corner
    import furn as F
    F.flush_light(c, 120)
    return c


def b_bare(c):
    b_wall(c)


B_ANCHORS = [('anchor_bathroom_vanity', 24, 90, ''), ('anchor_bathroom_mirror_shelf', 40, 50, ''),
             ('anchor_bathroom_avocado_toilet', 82, 92, ''), ('anchor_bathroom_mop_bucket', 118, 92, ''),
             ('anchor_bathroom_bath_taps', 176, 76, ''), ('anchor_bathroom_bath_panel', 226, 106, ''),
             ('anchor_bathroom_radio_stool', 278, 83, '')]


# ============================================================================================
# C — gilded (something silly)
# ============================================================================================
GOLD = hexc('d4a83a')
GOLD_LT = hexc('f0cf6a')
GOLD_DK = hexc('9a7424')
GOLD_OUT = hexc('5a4214')
MARBLE = hexc('e4ded2')
MARBLE_DK = hexc('cdc6b8')
VEIN = hexc('cfc7b8')
C_BLACK = hexc('26262a')
C_WHITE = hexc('dedad0')


def c_wall(c):
    c.rect(0, 0, W - 1, 93, MARBLE)
    rng = Canvas(seed=77).rng
    for i in range(16):                                                  # soft veins
        x, y = rng.randrange(6, W - 6), rng.randrange(8, 90)
        for k in range(rng.randrange(6, 18)):
            c.put(x, y, VEIN)
            x += rng.choice((-1, 0, 1, 1))
            y += rng.choice((0, 1, 1))
            if not (6 <= x < W - 6 and y < 92):
                break
    for x in range(0, W, 40):                                            # marble slab joints
        c.vline(x + 20, 6, 93, MARBLE_DK)
    crown(c, GOLD_DK, GOLD)
    c.rect(0, 58, W - 1, 60, GOLD)                                       # a gold dado band
    c.hline(0, W - 1, 58, GOLD_LT)
    c.hline(0, W - 1, 61, GOLD_OUT)
    c.rect(0, 94, W - 1, 99, C_BLACK)
    c.hline(0, W - 1, 94, GOLD_DK)
    c.hline(0, W - 1, 99, SEAM)
    # decay: a streak of something down the marble; the gold band scratched
    c.line(212, 20, 214, 56, hexc('8a7a5a', 90))
    c.hline(120, 131, 59, GOLD_DK)


@persp
def c_floor(c):
    c.rect(0, 100, W - 1, H - 1, C_WHITE)
    rows = [100, 106, 114, 124, 136, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, W, 16):
            if ((x // 16) + r) % 2:
                c.rect(x, y0, x + 15, y1, C_BLACK)
    c.hline(0, W - 1, 100, shade(C_WHITE, 0.5))
    c.hline(0, W - 1, 101, shade(C_WHITE, 0.72))


def chandelier(c, cx):
    c.vline(cx, 5, 16, GOLD_DK)
    c.hline(cx - 12, cx + 12, 17, GOLD)
    c.hline(cx - 8, cx + 8, 20, GOLD)
    for dx in (-12, -6, 0, 6, 12):
        c.vline(cx + dx, 17, 21, GOLD_DK)
        c.rect(cx + dx - 1, 12, cx + dx, 16, hexc('efe8d8'))           # candles
        c.put(cx + dx, 11, hexc('f0cf6a'))
    for dx in (-10, -4, 4, 10):                                          # crystals
        c.put(cx + dx, 23, hexc('cfe0e6')); c.put(cx + dx, 25, hexc('cfe0e6'))
    c.put(cx + 2, 24, hexc('cfe0e6'))
    from pixlib import light
    light(cx, 18, 'chandelier')


def gilt_mirror(c, x0, y0, x1, y1):
    c.box(x0, y0, x1, y1, GOLD, GOLD_OUT)
    c.box(x0 + 2, y0 + 2, x1 - 2, y1 - 2, GOLD_DK)
    c.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, MIRROR)
    c.line(x0 + 5, y1 - 5, x1 - 8, y0 + 5, MIRROR_HI)
    for (px, py) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):           # ornate corners
        c.rect(px - 1, py - 1, px + 1, py + 1, GOLD_LT)
    c.poly([((x0 + x1) // 2 - 5, y0), ((x0 + x1) // 2, y0 - 5), ((x0 + x1) // 2 + 5, y0)], GOLD)


def champagne(c, x0, base):
    c.shadow(x0 + 7, base, 9, 2, 110)
    for lx in (x0 + 2, x0 + 12):                                         # the stand
        c.line(lx, base - 16, lx + (-2 if lx < x0 + 5 else 2), base, GOLD_DK)
    c.poly([(x0, base - 24), (x0 + 14, base - 24), (x0 + 12, base - 14), (x0 + 2, base - 14)], GOLD)
    c.hline(x0, x0 + 14, base - 24, GOLD_LT)
    c.rect(x0 + 5, base - 33, x0 + 8, base - 25, hexc('2e4a2e'))        # the bottle
    c.rect(x0 + 6, base - 36, x0 + 7, base - 34, GOLD)


def c_build(c):
    c_wall(c)
    c_floor(c)
    gilt_mirror(c, 24, 20, 48, 50)                                        # over the washstand's tap
    washstand3d(c, 9, 47, 72)
    toilet3d(c, 84, porc=GOLD, out=GOLD_OUT, seat=hexc('7a1f2a'), lever=GOLD_LT, crest=hexc('7a1f2a'))   # a red velvet seat
    chandelier(c, 160)
    # a leopard rug flat on the floor under the tub, then the GOLD roll-top out in the room
    rug = S3.rrect_plan(118, 202, 1, 27, 6, 4)
    c.poly([S3.P(x, 100, d) for (x, d) in rug], hexc('c89a4a'))
    for (sx, sd) in ((124, 6), (138, 20), (150, 9), (166, 24), (182, 12), (194, 22), (130, 13), (176, 4), (158, 16)):
        q = S3.P(sx, 100, sd)
        c.rect(q[0], q[1], q[0] + 2, q[1] + 1, hexc('4a3220'))
    wx0, wx1, opening = clawfoot3d(c, 160, 62, 82, GOLD, GOLD_LT, GOLD_DK, GOLD_OUT, GOLD_DK, hexc('6a5418'),
                                   water=hexc('d9e0c8'))
    for (bx, bd) in ((wx0 + 12, 8), (wx0 + 20, 12), (wx0 + 28, 7), (wx0 + 36, 13), (wx0 + 44, 9), (wx1 - 12, 11)):   # bubbles heaped up
        q = S3.P(bx, 81, bd)
        c.ellipse(q[0], q[1] - 1, 3, 2, hexc('f4f2ec'))
        c.put(q[0] - 1, q[1] - 2, hexc('ffffff'))
    dk_ = S3.P(wx1 - 10, 81, 15)
    c.rect(dk_[0], dk_[1] - 3, dk_[0] + 4, dk_[1], hexc('f0cf3a')); c.put(dk_[0] + 5, dk_[1] - 2, hexc('e07a2a'))   # a rubber duck
    champagne(c, 205, 118)                                                # on its stand by the tub
    # a potted palm (right of the R window box) + a gold towel stand
    c.shadow(292, 100, 10, 2, 90)
    c.poly([(286, 86), (298, 86), (296, 99), (288, 99)], GOLD)
    for (tx, ty) in ((280, 58), (286, 50), (294, 48), (304, 56), (300, 66), (282, 68)):
        c.line(292, 86, tx, ty, hexc('4a6a34'))
        c.line(292, 85, tx + 1, ty + 2, hexc('5e8240'))
    c.rect(238, 67, 239, 99, GOLD_DK)
    c.hline(232, 245, 99, GOLD_DK)
    c.hline(232, 245, 67, GOLD)  # (the rail tops out under the R window box)
    hung_towel(c, 233, 245, 68, 88, hexc('7a1f2a'))
    return c


def c_bare(c):
    c_wall(c)


C_ANCHORS = [('anchor_bathroom_gilt_mirror', 37, 48, ''), ('anchor_bathroom_washstand', 30, 80, ''),
             ('anchor_bathroom_gold_throne', 82, 92, ''), ('anchor_bathroom_gold_tub', 142, 92, ''),
             ('anchor_bathroom_bubbles', 176, 88, ''), ('anchor_bathroom_champagne', 212, 96, ''),
             ('anchor_bathroom_towel_stand', 239, 78, '')]


# ============================================================================================
# D — wet room (squalid)
# ============================================================================================
D_TILE = hexc('b9c2c0')
D_TILE_DK = hexc('a3aca9')
D_GROUT = hexc('6f7876')
D_TRIM = hexc('7a8480')
D_PAINT = hexc('8e948a')


def mould_bloom(c, sx, sy, rx, ry, seed=1, up=False):
    """Black mould spreading from a source point: dense and dark where it starts, thinning out in
    ragged speckled fingers — never a rectangle."""
    import math as _m
    rng = random.Random(seed)
    for _ in range(int(rx * ry * 0.9)):
        a = rng.uniform(0, _m.pi)
        r = rng.random() ** 1.6
        dx = _m.cos(a) * rx * r * (1 if rng.random() < 0.5 else -1)
        dy = abs(_m.sin(a)) * ry * r * (-1 if up else 1)
        x, y = int(sx + dx), int(sy + dy)
        dens = 1 - r
        col = MOULD if dens > 0.45 else MOULD[:3] + (int(90 + 120 * dens),)
        c.put(x, y, col)
        if dens > 0.6 and rng.random() < 0.5:
            c.put(x + 1, y, col)


def d_wall(c):
    c.rect(0, 0, W - 1, 93, D_PAINT)
    crown(c, hexc('5e645c'), hexc('747a70'))
    tiled_wall(c, 30, D_TILE, D_TILE_DK, D_GROUT, D_TRIM, size=12)
    # heavy black mould: blooms up from the skirting and down from the ceiling
    # (owner round 17: the square blocks of dither read as noise) mould that GROWS: soft blooms
    # spreading out of the corners and down from the ceiling, densest at their source
    mould_bloom(c, 4, 8, 58, 22, seed=1)
    mould_bloom(c, 2, 92, 40, 24, seed=2, up=True)
    mould_bloom(c, 188, 7, 40, 10, seed=3)
    mould_bloom(c, W - 3, 92, 46, 34, seed=4, up=True)


@persp
def d_floor(c):
    # grey sheet vinyl, lifting in a seam line, a drain grate every 64px (periodic by 32)
    base = hexc('8a8f8a')
    c.rect(0, 100, W - 1, H - 1, base)
    for y in range(102, H):
        for x in range(W):
            k = (x * 5 + y * 11) % 32
            if k in (4, 21):
                c.put(x, y, shade(base, 0.9))
            elif k == 13:
                c.put(x, y, shade(base, 1.08))
    for x in range(0, W, 32):
        c.vline(x + 20, 102, H - 1, shade(base, 0.82))
    c.hline(0, W - 1, 100, shade(base, 0.5))
    c.hline(0, W - 1, 101, shade(base, 0.7))


def machine_laundry3d(c, cx, cy, floor_y, r):
    """The wash dragged half out of the machine (owner round 20: the first shirt "floated over empty
    space" in the drum): the wet load SLUMPED in the bottom of the drum — filling it up to a lumpy
    line, following the drum's curve, shaded darker where it presses against the steel — a sleeve
    hauled out over the rubber seal and down the front, the rest in a damp heap on the floor with a
    sock."""
    shirt, shirt_dk, shirt_lt = hexc('5e7a9a'), hexc('445a74'), hexc('7e98b6')
    red, red_dk = hexc('a0463c'), hexc('783228')
    rd = r - 3.5                                                          # the drum's inside
    def surf(x):                                                          # the load's lumpy top line
        return cy - 1 + round(1.4 * math.sin((x - cx) * 0.85 + 0.6) + 0.6 * math.sin((x - cx) * 2.1))
    for y in range(int(cy - rd), int(cy + rd) + 1):
        for x in range(int(cx - rd), int(cx + rd) + 1):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 > rd * rd or y < surf(x):
                continue
            edge = math.sqrt(d2) / rd                                     # 1 at the drum wall
            col = shirt_dk if edge > 0.82 else shirt
            if y == surf(x):
                col = shirt_lt                                            # the lit top of the load
            if (x - cx - 3) ** 2 + 2 * (y - cy - 2) ** 2 <= 4 and y > surf(x):
                col = red if y < cy + 3 else red_dk                       # a red sock in the load
            c.put(x, y, col)
    for x in range(int(cx - rd) + 1, int(cx + rd)):                      # its shadow on the drum above
        y = surf(x) - 1
        if (x - cx) ** 2 + (y - cy) ** 2 <= rd * rd:
            c.put(x, y, hexc('2a2e32'))
    c.line(cx - 4, cy + 2, cx - 1, cy + 3, shirt_dk)                      # creases
    c.line(cx + 2, cy + 4, cx + 5, cy + 3, shirt_dk)
    by = int(cy + rd)                                                     # a sleeve hauled out over the seal
    for k in range(4):
        c.line(cx - 3 + k, by - 2, cx - 4 + k, by + 9, shirt if k not in (0, 3) else (shirt_lt if k == 0 else shirt_dk))
    c.hline(cx - 3, cx, by + 1, shirt_dk)                                 # where it folds over the lip
    c.rect(cx - 4, by + 9, cx - 1, by + 10, shirt_dk)                     # its cuff
    fy = floor_y + 3
    c.shadow(cx - 4, fy + 3, 18, 2, 100)
    towel, towel_dk = TOWELS[1], shade(TOWELS[1], 0.78)
    jeans, jeans_dk = hexc('46607e'), hexc('33475e')
    c.poly([(cx - 22, fy + 3), (cx - 19, fy - 2), (cx - 11, fy - 4), (cx - 5, fy - 3), (cx - 3, fy + 1), (cx - 8, fy + 4), (cx - 18, fy + 5)], towel)
    c.line(cx - 19, fy - 1, cx - 11, fy - 3, shade(towel, 1.12))
    c.line(cx - 16, fy + 2, cx - 7, fy + 1, towel_dk)
    c.poly([(cx - 8, fy + 1), (cx - 4, fy - 5), (cx + 3, fy - 6), (cx + 8, fy - 3), (cx + 9, fy + 2), (cx + 2, fy + 4), (cx - 6, fy + 4)], jeans)
    c.line(cx - 4, fy - 4, cx + 3, fy - 5, shade(jeans, 1.2))
    c.line(cx - 2, fy - 1, cx + 7, fy - 1, jeans_dk)
    c.put(cx + 1, fy + 1, hexc('b89a4a'))                               # a rivet
    c.poly([(cx - 3, fy - 5), (cx + 1, fy - 8), (cx + 6, fy - 7), (cx + 4, fy - 4)], hexc('a8a49a'))
    c.line(cx - 1, fy - 6, cx + 4, fy - 6, hexc('c4c0b6'))
    c.rect(cx + 12, fy + 2, cx + 16, fy + 3, hexc('e6e0d0'))            # a sock
    c.put(cx + 16, fy + 1, hexc('e6e0d0'))


def wicker_hamper3d(c, cx, d_c=7, top=78):
    """A wicker laundry hamper against the wall: a round woven body (lit left, shaded right, the
    weave in rows), its lid on top, a towel caught under it."""
    wk, wk_dk = hexc('c9b48a'), hexc('9a8660')
    wcx = S3.wall_x(cx, d_c)
    foot = pp(wcx, 100, d_c)
    c.shadow(foot[0], foot[1] + 1, 10, 2, 110)
    lay = S3.Layer()
    sl = S3.lerp_slices(100, top, (7.0, d_c, 5.0), (8.0, d_c, 5.6))
    S3.lathe(lay.c, wcx, sl, wk, shade(wk, 1.1), wk_dk)
    lay.commit(c, hexc('6a5638'))
    for i, y in enumerate(range(top + 2, 100, 3)):                                   # the weave
        ex, ey, erx, ery = S3.ell_geo(wcx, y, d_c - 5.4, d_c + 5.4, 7.6)
        c.hline(int(ex - erx + 1), int(ex + erx - 1), int(round(ey + ery)), shade(wk, 0.8))
    for k in range(-3, 4):
        ex, ey, erx, ery = S3.ell_geo(wcx, top, d_c - 5.6, d_c + 5.6, 8.0)
        x = int(round(ex + k * erx / 3.6))
        c.vline(x, int(round(ey + ery)) + 1, int(round(pp(wcx, 100, d_c + 5)[1])) - 1, shade(wk, 0.88))
    ex, ey, erx, ery = S3.ell_geo(wcx, top - 1, d_c - 6.2, d_c + 6.2, 8.8)
    c.ellipse(ex, ey + 1, erx, ery, hexc('6a5638'))                                   # the lid
    c.ellipse(ex, ey, erx, ery, shade(wk, 1.08))
    c.ellipse(ex, ey - 0.5, erx * 0.3, max(0.8, ery * 0.3), wk_dk)                    # its knob
    c.poly([(int(ex + erx * 0.2), int(ey + ery)), (int(ex + erx * 0.7), int(ey + ery) - 1), (int(ex + erx * 0.8), int(ey + ery) + 6), (int(ex + erx * 0.35), int(ey + ery) + 5)], TOWELS[1])   # a towel caught under it


def stool_radio3d(c, cx, d_c=6):
    """A wooden stool against the wall with a transistor radio on it, its aerial up."""
    wood, wood_dk, wood_lt = hexc('9a7a52'), hexc('6a5436'), hexc('c09a6a')
    wcx = S3.wall_x(cx, d_c)
    foot = pp(wcx, 100, d_c)
    c.shadow(foot[0], foot[1] + 1, 10, 2, 110)
    for (lx, ld, col) in ((-6, d_c - 4, wood_dk), (6, d_c - 4, wood_dk), (-6.5, d_c + 4, wood), (6.5, d_c + 4, wood)):
        a_, b_ = _P3(wcx + lx * 0.85, 83, ld), _P3(wcx + lx, 100, ld)
        c.line(a_[0], a_[1], b_[0], b_[1], col)
        c.line(a_[0] + 1, a_[1], b_[0] + 1, b_[1], shade(col, 0.8))
    a_, b_ = _P3(wcx - 6, 93, d_c + 3), _P3(wcx + 6, 93, d_c + 3)                 # a stretcher
    c.line(a_[0], a_[1], b_[0], b_[1], wood_dk)
    pbox(c, wcx - 8, 81, wcx + 8, 83, d_c - 6, d_c + 6, wood, wood_lt, wood_dk, hexc('3a2a1a'))   # the seat
    f = pbox(c, wcx - 6, 72, wcx + 6, 81, d_c - 3, d_c + 2, hexc('3e3a36'), hexc('5a5650'), hexc('2a2622'), hexc('1a1614'))
    fl, fr, fbr = f['fl'], f['fr'], f['fbr']
    for y in range(fl[1] + 2, fbr[1] - 1, 2):                                         # the speaker grille
        c.hline(fl[0] + 2, fl[0] + 7, y, hexc('6a6660'))
    c.rect(fl[0] + 9, fl[1] + 2, fr[0] - 2, fl[1] + 4, hexc('d9c9a0'))                 # the tuning dial
    c.put(fl[0] + 11, fl[1] + 3, hexc('c0453a'))
    c.ellipse(fr[0] - 3, fbr[1] - 3, 1.5, 1.5, CHROME)                               # the knob
    h0 = _P3(wcx - 4, 72, d_c - 0.5)
    h1 = _P3(wcx + 4, 72, d_c - 0.5)
    c.line(h0[0], h0[1], h0[0] + 1, h0[1] - 3, CHROME_DK)                             # the carry handle
    c.line(h0[0] + 1, h0[1] - 3, h1[0] - 1, h1[1] - 3, CHROME_DK)
    c.line(h1[0] - 1, h1[1] - 3, h1[0], h1[1], CHROME_DK)
    ae = _P3(wcx + 5, 72, d_c - 2)
    c.line(ae[0], ae[1], ae[0] + 7, ae[1] - 18, CHROME)                               # the aerial


def laundry_basket3d(c, cx, d_c=8, body=hexc('6a8aa8'), load=True):
    """A plastic laundry basket on the floor by the machine: an oval tub with slots, seen from a
    little above, washing heaped in it."""
    wcx = S3.wall_x(cx, d_c)
    foot = pp(wcx, 100, d_c)
    c.shadow(foot[0], foot[1] + 1, 12, 2, 110)
    lay = S3.Layer()
    sl = S3.lerp_slices(100, 86, (9.0, d_c, 5.0), (11.5, d_c, 6.5))
    S3.lathe(lay.c, wcx, sl, body)
    lay.commit(c, shade(body, 0.5))
    ex, ey, erx, ery = S3.ell_geo(wcx, 86, d_c - 6.5, d_c + 6.5, 11.5)
    for k in range(-3, 4):                                               # the slots round its side
        sx = int(round(ex + k * erx / 4.2))
        c.vline(sx, int(round(ey + ery)) + 2, int(round(ey + ery)) + 8, shade(body, 0.7))
    c.ellipse(ex, ey, erx, ery, shade(body, 1.2))                         # the rim
    c.ellipse(ex, ey, erx - 1.5, ery - 1, shade(body, 0.55))              # inside
    if load:
        for (dx, dy, rr, col) in ((-5, -2, 5, TOWELS[2]), (3, -3, 5, hexc('b9b4a4')), (-1, -5, 4, TOWELS[0]), (6, 0, 3, TOWELS[3])):
            c.ellipse(ex + dx, ey + dy, rr, rr * 0.6, col)
            c.put(int(ex + dx - rr * 0.4), int(ey + dy - rr * 0.3), shade(col, 1.15))
        c.line(int(ex + 8), int(ey - 1), int(ex + 12), int(ey + 6), TOWELS[0])   # a sleeve over the side
    return ex, ey


def d_build(c):
    d_wall(c)
    d_floor(c)
    # a cracked mirror tile over a small basin on iron brackets — the basin comes out to us
    c.box(25, 30, 49, 52, hexc('7a8480'), hexc('3a403e'))                 # over the tap
    c.rect(27, 32, 47, 50, MIRROR)
    c.line(29, 48, 44, 34, MIRROR_HI)
    c.line(34, 34, 40, 48, shade(MIRROR, 0.75)); c.line(40, 48, 45, 42, shade(MIRROR, 0.75))
    c.vline(37, 80, 99, IRON)                                            # the waste pipe, down the wall
    c.rect(34, 92, 40, 97, RUST)
    basin3d(c, 37, rim=66, pedestal=False, inside=hexc('b9b09a'), drip=True)
    c.dither(18, 69, 36, 72, hexc('8a7a5a', 120), 0.4, pattern='random')  # grime in the basin
    mould_bloom(c, 62, 92, 12, 22, seed=14, up=True)                    # mould creeping up behind the pan
    standing_rolls(c, 97, 102)                                           # spare rolls by the pan
    toilet3d(c, 70, lid_up=True, seat=hexc('b9b4a4'))
    # the bath along the wall, its front 20 px out; the curtain hangs from its rail INSIDE the tub,
    # drawn nearly shut — one corner pulled aside, the dark tub behind
    x0, x1, rim = 110, 200, 80
    wx0, wx1, f = bath3d(c, x0, x1, rim, inside=hexc('8a8a70'))
    d_r, rail_y = 11, 13
    shower_rail(c, wx0, wx1, rail_y, d_r)
    cur = hexc('c9c48a')
    xa, xb, top, hem = curtain_in_tub(c, wx0, wx1, rim, d_r, rail_y, cur, wx0 + 13, wx1, wx0 + 13)
    for (fx, fy) in ((xa + 18, top + 12), (xa + 42, top + 8), (xa + 30, top + 26), (xa + 56, top + 30)):   # ducks printed on it
        c.rect(fx, fy, fx + 4, fy + 3, hexc('d9b43a'))
        c.put(fx + 5, fy + 1, hexc('c06a2a'))
    c.dither(xa, hem - 20, xb, hem - 8, hexc('7a7a4a', 90), 0.4, pattern='random')   # grime low down
    c.line(xa + 3, top + 40, xa + 9, top + 58, BLOOD)                   # a smear down the plastic
    c.line(xa + 5, top + 40, xa + 10, top + 54, BLOOD)
    for (hx, hy) in ((xa + 1, top + 44), (xa + 1, top + 47), (xa + 1, top + 50)):   # fingers round its edge
        c.rect(hx - 2, hy, hx, hy + 1, hexc('8a6a5a'))
    fl, fbr = bath_front(c, wx0, wx1, rim, d_r)
    c.box(fl[0] + 4, fl[1] + 5, fbr[0] - 4, fbr[1] - 4, PORC, PORC_DK)       # the bath panel
    c.hline(fl[0] + 5, fbr[0] - 5, fl[1] + 6, PORC_LT)
    c.dither(fl[0] + 1, fbr[1] - 6, fbr[0] - 1, fbr[1] - 1, hexc('8a8a70', 120), 0.45, pattern='random')   # scum at its foot
    c.line(150, fl[1] + 8, 152, fl[1] + 18, BLOOD)
    # the washing machine standing out on the right, the wash dragged out onto the floor; a laundry
    # basket against the wall beside it (loose things go with what they belong to)
    laundry_basket3d(c, 248, d_c=7)
    cx_, cy_, fl, fr, fbr = washing_machine3d(c, 272, top=68)
    machine_laundry3d(c, cx_, cy_, fbr[1], int(round((fr[0] - fl[0]) * 0.40)))
    import furn as F
    F.bare_bulb(c, 220, 22)
    return c


def d_bare(c):
    d_wall(c)


D_ANCHORS = [('anchor_bathroom_small_sink', 27, 70, ''), ('anchor_bathroom_grim_toilet', 70, 92, ''),
             ('anchor_bathroom_toilet_rolls', 101, 96, ''), ('anchor_bathroom_behind_curtain', 158, 70, ''),
             ('anchor_bathroom_curtain_corner', 124, 88, ''), ('anchor_bathroom_laundry_basket', 248, 90, ''),
             ('anchor_bathroom_washer', 290, 86, '')]


# ============================================================================================
# E — pink 50s
# ============================================================================================
PINK = hexc('e0a8b4')
PINK_LT = hexc('efc4cc')
PINK_DK = hexc('c08894')
PINK_OUT = hexc('6a4048')
E_TILE = hexc('e8c4c8')
E_TILE_DK = hexc('d8b0b6')
E_TRIM = hexc('26262a')


def e_wall(c):
    c.rect(0, 0, W - 1, 93, hexc('d8d0c0'))
    crown(c, hexc('a89a88'), hexc('c0b4a0'))
    tiled_wall(c, 44, E_TILE, E_TILE_DK, hexc('b89aa0'), E_TRIM, size=8)
    c.rect(0, 58, W - 1, 59, E_TRIM)                                            # a black pencil-tile line
    mould_bloom(c, 3, 7, 30, 12, seed=21)                                        # creeping from the corners
    mould_bloom(c, W - 4, 7, 26, 14, seed=22)


@persp
def e_floor(c):
    # black and white hexagon-ish mosaic: offset 8px blocks (repeats every 32px)
    c.rect(0, 100, W - 1, H - 1, hexc('e6e2d8'))
    rows = [100, 104, 109, 115, 122, 130, 139, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        off = 4 if r % 2 else 0
        for x in range(-8, W, 8):
            col = hexc('2e2e33') if ((x + 8) // 8 + r) % 4 == 0 else hexc('e6e2d8')
            c.rect(max(0, x + off), y0, min(W - 1, x + off + 7), y1, col)
            if 0 <= x + off < W:
                c.vline(x + off, y0, y1, hexc('b9b5ab'))
        c.hline(0, W - 1, y0, hexc('b9b5ab'))
    c.hline(0, W - 1, 100, hexc('7a766c'))


def e_build(c):
    e_wall(c)
    e_floor(c)
    # a round mirror with a pink frame + a glass shelf of bottles over the pink basin's tap
    c.ellipse(37, 32, 11, 11, PINK_DK)
    c.ellipse(37, 32, 9, 9, MIRROR)
    c.line(32, 38, 41, 25, MIRROR_HI)
    c.rect(25, 49, 49, 50, hexc('c9d8d8'))
    for (x, col) in ((27, hexc('e8a0b0')), (33, hexc('7ab0c8')), (39, hexc('e0d9b8')), (44, hexc('c07a3a'))):
        c.rect(x, 44, x + 3, 48, col)
    basin3d(c, 37, rim=70, porc=PINK, out=PINK_OUT)
    toilet3d(c, 84, porc=PINK, out=PINK_OUT, seat=hexc('26262a'))
    toilet_roll(c, 106, 78, hexc('efe8d8'))
    # a short pink tub on a tiled plinth, its front 20 px out; the curtain drawn back to the right end,
    # hanging from its rail INSIDE the tub
    x0, x1, rim = 118, 206, 80
    wx0, wx1, f = bath3d(c, x0, x1, rim, body=E_TILE, lit=PINK_LT, dk=shade(E_TILE, 0.72), out=PINK_OUT,
                         inside=hexc('b07a86'))
    tx = int(round(wx0))
    c.rect(tx + 4, rim - 8, tx + 6, rim - 1, CHROME)                                  # taps on the wall
    c.rect(tx + 10, rim - 8, tx + 12, rim - 1, CHROME)
    c.hline(tx + 3, tx + 13, rim - 8, CHROME_DK)
    d_r, rail_y = 11, 14
    shower_rail(c, wx0, wx1, rail_y, d_r)
    cur = hexc('efe8d8')
    xa, xb, top, hem = curtain_in_tub(c, wx0, wx1, rim, d_r, rail_y, cur, wx1 - 16, wx1, wx1)
    for (x, y) in ((xb - 10, top + 12), (xb - 4, top + 28), (xb - 9, top + 44)):          # little pink fish on it
        c.rect(x, y, x + 3, y + 1, PINK_DK)
        c.put(x + 4, y, PINK_DK); c.put(x + 4, y + 1, PINK_DK)
    fl, fbr = bath_front(c, wx0, wx1, rim, d_r, body=E_TILE, lit=PINK_LT, dk=shade(E_TILE, 0.72), out=PINK_OUT)
    for y in range(fl[1] + 5, fbr[1], 6):                                             # the tiled plinth
        c.hline(fl[0] + 1, fbr[0] - 1, y, hexc('b89aa0'))
    for x in range(fl[0] + 6, fbr[0], 8):
        c.vline(x, fl[1] + 2, fbr[1] - 1, hexc('b89aa0'))
    c.line(154, fl[1] + 8, 156, fl[1] + 18, BLOOD)
    # a pink fluffy bath mat on the floor in front of it
    c.poly([(132, 123), (186, 123), (189, 129), (129, 129)], PINK_LT)
    c.dither(132, 124, 186, 128, PINK, 0.5)
    def _hamper(c):
        c.shadow(222, 100, 12, 2, 100)
        c.poly([(210, 81), (234, 81), (232, 100), (212, 100)], hexc('efe8d8'))
        for y in range(84, 100, 3):
            c.hline(211, 233, y, hexc('d0c8b4'))
        c.rect(208, 78, 236, 81, PINK_DK)
        c.poly([(214, 78), (220, 72), (224, 78)], TOWELS[1])
    setback(c, _hamper, depth=3, top=78, x_range=(208, 236))
    # a vanity stool against the wall + the linen cupboard on the right
    c.shadow(252, 100, 8, 1, 90)
    c.ellipse(252, 84, 8, 3, PINK)
    for lx in (246, 258):
        c.vline(lx, 86, 99, CHROME_DK)
    setback(c, _linen_cupboard, depth=5, top=44, x_range=(277, 309), rake=1.0)
    import furn as F
    F.flush_light(c, 100)
    return c


def _linen_cupboard(c):
    x0, x1, top = 278, 308, 46
    body, body_dk, trim = hexc('efe8d8'), hexc('c9c0ae'), PINK_DK
    c.shadow(293, 100, 17, 2, 100)
    c.rect(x0 - 1, top - 2, x1 + 1, top, trim)                                  # the cornice
    c.hline(x0 - 1, x1 + 1, top - 2, shade(trim, 1.2))
    c.box(x0, top + 1, x1, 95, body, PINK_OUT)
    c.rect(x0 + 2, top + 3, x1 - 2, 70, hexc('b8aaa8'))                         # the open shelves
    c.rect(x0 + 2, 58, x1 - 2, 59, body)
    c.hline(x0 + 2, x1 - 2, 58, shade(body, 1.05))
    for (tx, ty, col) in ((x0 + 4, 53, TOWELS[1]), (x0 + 4, 50, hexc('f4f0e6')), (x0 + 4, 47, TOWELS[1]),
                          (x0 + 16, 54, hexc('f4f0e6')), (x0 + 16, 51, PINK)):  # folded towels
        c.rect(tx, ty, tx + 10, ty + 3, col)
        c.hline(tx, tx + 10, ty + 3, shade(col, 0.8))
        c.vline(tx + 10, ty, ty + 3, shade(col, 0.85))
    for k in range(4):                                                         # toilet rolls
        rx = x0 + 4 + k * 6
        c.rect(rx, 64, rx + 4, 69, hexc('f4f0e6'))
        c.put(rx + 2, 66, hexc('b8b0a0'))
    c.rect(x0 + 2, 70, x1 - 2, 71, body)
    for (d0, d1) in ((x0 + 2, (x0 + x1) // 2 - 1), ((x0 + x1) // 2 + 1, x1 - 2)):   # two small doors
        c.box(d0, 73, d1, 93, body, body_dk)
        c.box(d0 + 2, 75, d1 - 2, 91, body, body_dk)
    c.put((x0 + x1) // 2 - 3, 83, CHROME); c.put((x0 + x1) // 2 + 3, 83, CHROME)
    for fx in (x0 + 1, x1 - 3):                                                 # bun feet
        c.rect(fx, 96, fx + 2, 99, PINK_OUT)


def e_bare(c):
    e_wall(c)


E_ANCHORS = [('anchor_bathroom_glass_shelf', 37, 49, ''), ('anchor_wall_sink', 36, 76, ''),
             ('anchor_centre_toilet', 82, 92, ''), ('anchor_bathroom_pink_tub', 160, 92, ''),
             ('anchor_bathroom_hamper', 222, 88, ''), ('anchor_bathroom_pink_taps', 130, 76, ''),
             ('anchor_bathroom_frosted_cabinet', 292, 82, 'bp')]


VARIANTS = {
    'a': ('bathroom', 41, a_bare, a_floor, a_build, A_ANCHORS),
    'b': ('bathroom_b', 42, b_bare, b_floor, b_build, B_ANCHORS),
    'c': ('bathroom_c', 43, c_bare, c_floor, c_build, C_ANCHORS),
    'd': ('bathroom_d', 44, d_bare, d_floor, d_build, D_ANCHORS),
    'e': ('bathroom_e', 45, e_bare, e_floor, e_build, E_ANCHORS),
}


if __name__ == '__main__':
    for v in (sys.argv[1:] or sorted(VARIANTS)):
        name, seed, bare, floor, build, anchors = VARIANTS[v]
        finish_module(name, 'bathroom', seed, bare, floor, build, anchors)
