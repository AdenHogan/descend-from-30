"""THE TOYS, ONE SOURCE (owner round 48j: "the blocks … are standing oddly, especially the top triangle which is also too flat as a shape. Same with the rocking horse, there is no depth to
it. Every item needs to have depth and not just be flat 2D. We really need consistency on this across the board").

The child's room existed twice — as planned pieces (`furn_toys.block_tower`, `furn_seats.rocking_horse`) and as the BAKED bedroom E (`bedroom_variants._e_toys_wall` / `_e_rest`) — and the baked
one was still drawn from flat fills: a 5 x 5 square with a dot, a flat triangle, a cream blob on two sticks. Both now call the drawing in this file, so a toy looks the same wherever it stands:

  cube(...)        a toy block in a true oblique projection: a lit front face carrying a letter / number / picture, a lit TOP face and a shaded SIDE face that both recede toward the room's
                   vanishing point (so a block left of the room's middle shows its right side, one on the right its left), chipped corners, a bevel
  roof(...)        a triangular roof block: the front triangle and the slope behind it — a real prism, drawn from its own normals
  lying_cyl(...)   a cylinder block on its side
  horse(...)       the rocking horse: chair3d's 3D model (rockers, splayed legs, barrel, neck, head, ears, mane, tail, saddle, handles) turned by a yaw, painted white / grey / brown, or bloodied
  extrude_yz(...)  the side-view-outline-to-solid helper the models are built with (furn_seats / furn_medical import it from here)
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chair3d as C3
import furn as F
import propkit as K
from pixlib import hexc, shade

TOY_R, TOY_Y, TOY_B, TOY_G = hexc('c8423a'), hexc('e6c24a'), hexc('4a7ac0'), hexc('5aa05a')
WOOD_BARE = hexc('c8a066')

GLYPHS = {
    'heart': ('01010', '11111', '11111', '01110', '00100'),
    'star': ('00100', '00100', '11111', '01110', '01010'),
    'cat': ('10001', '11111', '10101', '11111', '01110'),
    'duck': ('01100', '11110', '01111', '01110', '01100'),
    'sun': ('10101', '01110', '11111', '01110', '10101'),
}


def glyph(c, x, y, name, col):
    for gy, row in enumerate(GLYPHS[name]):
        for gx, v in enumerate(row):
            if v == '1':
                c.put(x + gx, y + gy, col)


# ================================================================================================================================ blocks
def cube(c, x0, yb, w, col, face, rng, d=3, sgn=1):
    """A wooden toy block, front face x0..x0+w-1 by rows yb-w+1..yb, its depth `d` px receding up and to the `sgn` side (+1 = right: a block left of the room's middle).

    The top face is a parallelogram (each row one px further along than the one below it) and the side face another, both from the same offset, so the corner where the three faces meet is
    a real corner. Light from the upper left: top brightest, the front a gentle gradient, the side dark."""
    y0 = yb - w + 1
    x1 = x0 + w - 1
    tn = K.tones(col, 4, 0.62, 1.22)
    sidecol, topcol = shade(col, 0.64), shade(col, 1.24)
    for j in range(1, d + 1):                                             # the side face: the front face's edge column carried back, each column one row higher
        xx = x1 + j if sgn > 0 else x0 - j
        for y in range(y0 - j, yb - j + 1):
            f = (y - (y0 - j)) / float(max(1, w - 1))
            c.put(xx, y, shade(sidecol, 1.08 - 0.22 * f - 0.05 * (j - 1)))
    for k in range(1, d + 1):                                             # the top face: the front face's top edge carried back, each row one px further along
        xs = (x0 + k, x1 + k) if sgn > 0 else (x0 - k, x1 - k)
        c.hline(xs[0], xs[1], y0 - k, shade(topcol, 1.0 + 0.04 * k))
    for y in range(y0, yb + 1):                                           # the front face
        f = (y - y0) / float(max(1, w - 1))
        c.hline(x0, x1, y, shade(col, 1.06 - 0.20 * f))
    c.hline(x0, x1, y0, tn[-1])                                           # bevel: a lit top edge, a lit left edge, a shaded right edge, a dark foot
    c.vline(x0, y0, yb, shade(col, 1.12))
    c.vline(x1, y0, yb, shade(col, 0.78))
    c.hline(x0, x1, yb, tn[0])
    cream = hexc('f4ecd8')
    if face in GLYPHS:
        glyph(c, x0 + (w - 5) // 2, y0 + (w - 5) // 2, face, cream)
    else:
        F.text3(c, x0 + (w - 3) // 2, y0 + (w - 5) // 2, face, cream)
    for (cx, cy) in ((x0, y0), (x1, y0), (x0, yb), (x1, yb)):             # the corners chipped back to the wood
        if rng.random() < 0.6:
            c.put(cx, cy, WOOD_BARE)
    if rng.random() < 0.8:                                                # a scuff low on the face
        c.put(x0 + rng.randint(1, w - 2), yb - 1, shade(col, 0.6))
    for k in range(d - 1):                                                # a streak of grain across the top
        c.put(x0 + 2 + k * 2 + (1 if sgn > 0 else -1) * (k + 1), y0 - 1 - k, shade(topcol, 1.18))


def roof(c, cx, base, w, h, col, d=3, sgn=1):
    """A triangular roof block standing on its base row `base`: the front triangle (apex row base-h+1) and, behind it, the slope that faces the viewer (the right one for sgn +1) as a
    parallelogram carried back by (d, -d). The ridge along the top is lit, the slope is in shade, the foot is dark — a prism, not a flat triangle."""
    half = w / 2.0
    ax, ay = cx, base - h + 1                                            # the apex (front)
    lx, rx = cx - w // 2, cx + w // 2 - (0 if w % 2 else 1)              # the base corners (front)
    tn = K.tones(col, 4, 0.58, 1.26)
    if sgn > 0:                                                           # the slope that faces the viewer, carried back
        c.poly([(ax, ay), (rx, base), (rx + d, base - d), (ax + d, ay - d)], shade(col, 0.66))
        for k in range(d + 1):                                            # a lighter band where the slope meets the ridge
            c.put(ax + k, ay - k, shade(col, 1.18))
    else:
        c.poly([(ax, ay), (lx, base), (lx - d, base - d), (ax - d, ay - d)], shade(col, 0.66))
        for k in range(d + 1):
            c.put(ax - k, ay - k, shade(col, 1.18))
    for k in range(h):                                                    # the front triangle, row by row from the base up
        hw = int(round(half * (1.0 - k / float(h))))
        y = base - k
        l, r = cx - hw, cx + hw - (1 if w % 2 == 0 and hw > 0 else 0)
        f = k / float(max(1, h - 1))
        c.hline(l, r, y, shade(col, 1.04 - 0.16 * f))
        c.put(l, y, tn[-1] if k < h - 1 else tn[-2])                      # the lit left edge
        c.put(r, y, tn[0])                                                # the shaded right edge
    c.hline(lx, rx, base, tn[0])                                          # the dark foot


def plank(c, x0, x1, yb, col, thick=3, d=2, sgn=1):
    """A wooden plank laid across two blocks: a front face `thick` rows deep (lit at the top edge), a top face `d` rows back, and its end face."""
    y0 = yb - thick + 1
    tn = K.tones(col, 4, 0.62, 1.22)
    for j in range(1, d + 1):                                             # the end face on the side the blocks show
        xx = x1 + j if sgn > 0 else x0 - j
        c.vline(xx, y0 - j, yb - j, shade(col, 0.62))
    for k in range(1, d + 1):                                             # the top face
        xs = (x0 + k, x1 + k) if sgn > 0 else (x0 - k, x1 - k)
        c.hline(xs[0], xs[1], y0 - k, shade(col, 1.18 + 0.05 * k))
    for y in range(y0, yb + 1):
        f = (y - y0) / float(max(1, thick - 1))
        c.hline(x0, x1, y, shade(col, 1.06 - 0.2 * f))
    c.hline(x0, x1, y0, tn[-1])
    c.hline(x0, x1, yb, tn[0])
    for gx in range(x0 + 3, x1 - 2, 7):                                   # a knot or two in the grain
        c.put(gx, y0 + thick // 2, shade(col, 0.74))


def lying_cyl(c, x0, x1, yb, r, col):
    """A cylinder block lying on its side: a lit top, a darker belly, a pale end cap with a ring."""
    tn = K.tones(col, 5, 0.5, 1.3)
    for x in range(x0, x1 + 1):
        for k in range(2 * r):
            f = k / float(2 * r - 1)
            c.put(x, yb - 2 * r + 1 + k, K._pick(tn, 0.95 - 0.8 * f))
    K.ell(c, x0, yb - r + 0.5, 1.6, r, shade(col, 1.25))
    K.ell(c, x0, yb - r + 0.5, 0.9, r * 0.55, shade(col, 0.95))


# ================================================================================================================================ the rocking horse
def extrude_yz(m, poly, x0, x1, part, mat):
    """A solid from a side-view outline: `poly` is [(y, z)…] (convex-ish), thickness from x0 to x1. Faces on both sides and round the edge."""
    n = len(poly)
    m.add([(x0, y, z) for (y, z) in poly], part, mat)
    m.add([(x1, y, z) for (y, z) in reversed(poly)], part, mat)
    for i in range(n):
        (ya, za), (yb, zb) = poly[i], poly[(i + 1) % n]
        m.add([(x0, ya, za), (x1, ya, za), (x1, yb, zb), (x0, yb, zb)], part, mat)


def horse_model():
    """A rocking horse, head toward -y (the chairs' front): side-view outlines extruded across its width. Units are px."""
    m = C3.Model()
    # two curved runners joined by a stretcher: each a strip of short segments along an arc, rising at both ends
    n = 9
    for sx in (-4.4, 4.4):
        for k in range(n):
            ya, yb = -15.0 + 30.0 * k / n, -15.0 + 30.0 * (k + 1) / n
            za = 4.2 * (abs(ya) / 15.0) ** 2
            zb = 4.2 * (abs(yb) / 15.0) ** 2
            extrude_yz(m, [(ya, za), (yb, zb), (yb, zb + 2.0), (ya, za + 2.0)], sx - 0.8, sx + 0.8, 'rocker%d' % (sx > 0), 'rocker')
    m.box(-4.4, 4.4, -0.5, 0.5, 1.2, 2.4, 'stretch', 'rocker')
    # four legs, splayed a little, from the runners up under the body
    for sx in (-3.4, 3.4):
        extrude_yz(m, [(-10.4, 3.4), (-8.9, 3.4), (-6.2, 9.0), (-8.0, 9.0)], sx - 0.8, sx + 0.8, 'legf%d' % (sx > 0), 'wood')
        extrude_yz(m, [(9.4, 3.4), (10.9, 3.4), (8.4, 9.0), (6.6, 9.0)], sx - 0.8, sx + 0.8, 'legb%d' % (sx > 0), 'wood')
    # the body, a bevelled barrel
    m.box(-4.2, 4.2, -9.0, 10.0, 8.5, 15.2, 'body', 'wood', bevel=1.5)
    # the neck, the head with its long face, the ears, the mane
    extrude_yz(m, [(-3.0, 14.2), (-7.4, 23.4), (-11.4, 22.8), (-9.4, 14.2)], -2.6, 2.6, 'neck', 'wood')
    extrude_yz(m, [(-9.6, 23.8), (-14.0, 23.8), (-19.2, 19.6), (-19.4, 16.4), (-16.6, 15.4), (-11.0, 19.4)], -2.3, 2.3, 'head', 'wood')
    for sx in (-1.6, 1.6):
        extrude_yz(m, [(-9.4, 23.6), (-8.6, 27.4), (-7.4, 23.4)], sx - 0.5, sx + 0.5, 'ear%d' % (sx > 0), 'wood')
    extrude_yz(m, [(-3.0, 14.6), (-7.6, 24.2), (-8.6, 23.6), (-4.6, 14.2)], -0.7, 0.7, 'mane', 'mane')
    extrude_yz(m, [(-9.8, 23.6), (-11.6, 24.2), (-12.2, 22.4), (-10.0, 22.2)], -0.7, 0.7, 'forelock', 'mane')
    extrude_yz(m, [(9.8, 14.4), (13.4, 13.0), (15.4, 6.0), (13.6, 5.6), (11.6, 10.4)], -1.0, 1.0, 'tail', 'mane')
    # the saddle, the handles across the neck, the eyes
    m.box(-4.7, 4.7, -2.0, 5.5, 14.8, 16.8, 'saddle', 'saddle', bevel=0.7)
    m.box(-5.8, 5.8, -10.0, -9.0, 19.4, 20.4, 'handle', 'rocker')
    for sx in (-5.8, 5.8):
        m.box(sx - 0.7, sx + 0.7, -10.2, -8.8, 19.2, 20.6, 'knob%d' % (sx > 0), 'rocker')
    for sx in (-2.55, 2.55):
        m.box(sx - 0.3, sx + 0.3, -14.6, -13.6, 20.6, 21.6, 'eye%d' % (sx > 0), 'eye')
    return m


HORSES = {'white': dict(wood=hexc('e2dccb'), mane=hexc('4a3a30'), saddle=hexc('b0453a'), rocker=hexc('a07848')),
          'grey': dict(wood=hexc('9ca0a8'), mane=hexc('34363c'), saddle=hexc('3a5a7a'), rocker=hexc('8a6844')),
          'brown': dict(wood=hexc('8a5a3a'), mane=hexc('2a1c14'), saddle=hexc('c4a040'), rocker=hexc('6a4a2c')),
          'white_blood': dict(wood=hexc('d8d0bc'), mane=hexc('4a3a30'), saddle=hexc('8a3a34'), rocker=hexc('8a6a44'), blood=True)}


def horse(c, cx, base_y, kind, yaw):
    """Draw the rocking horse of paint `kind` turned `yaw` degrees (-62 faces right, +62 left; +-28 are three-quarter views), its rockers resting on row `base_y`, centred on column `cx`.
    Returns the renderer's buffers (a bloodied one is stained, the rockers / eyes left clean)."""
    spec = HORSES[kind]
    pal = {'wood': spec['wood'], 'mane': spec['mane'], 'saddle': spec['saddle'], 'rocker': spec['rocker'], 'eye': hexc('18120e')}
    r = C3.draw_model(c, cx, base_y, horse_model(), yaw, pal, srad=15)
    if r and spec.get('blood'):
        cbuf, pbuf, sbuf = r
        rng = random.Random(41 + int(yaw))
        C3._bloody(c, cx, base_y, cbuf, pbuf, sbuf, rng, heavy=False, fallen=False,
                   blobs=[((0.0, -6.0, 18.0), 3.2), ((0.0, 1.0, 15.2), 4.6)], skip=('rocker', 'stretch', 'eye'))
    return r
