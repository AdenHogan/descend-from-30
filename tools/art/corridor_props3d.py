"""VOLUME PROPS for the corridor — the standing dressing redrawn so nothing in it is a flat drawing (owner round 48h: "We absolutely do not want any flat drawings anywhere").

The old versions of these props were colour fills with a one-pixel highlight: a bin bag was a black ellipse, a scooter a stick figure, a suitcase a front-on slab. These are built the way
the furniture kit builds things (tools/art/propkit.py): every surface takes a tone from its own normal (light from the UPPER LEFT, a little from the front), so a bag is a lump with a
sheen, a bin is a cylinder, a box shows its top, front AND its shaded right side; every material has its own ramp and its own marks (plastic sheen + gathered wrinkles, newsprint edges,
corrugated card + tape, leather ribs + corner guards, rubber + chrome); contacts are shadowed (a bag sags into the one in front of it); small things carry their cast shadow.

Same sprite sizes, depths and floor contacts as the drawings they replace, so scripts/corridor_decals.gd's seeded placement lands every prop where it did. Called by corridor_props.build.
"""
import math
import random

import propkit
from corridor_props import new, ground, record, SHADOW
from pixlib import hexc, shade, mix
from propkit import tones, LX, LY, LZ


# ------------------------------------------------------------------------------------------------------------------------------------ shared pieces
def _ramp(hexes):
    return [hexc(h) for h in hexes]


def pick(tn, lam):
    return tn[int(max(0.0, min(0.999, lam)) * len(tn))]


def box3d(c, x0, x1, yt, yb, d, col, s=2, lo=0.50, hi=1.32, top_col=None, edge=True):
    """A box seen from the front and a little from above and the RIGHT: the front face x0..x1 x yt..yb, a lit top face `d` rows deep whose back edge is shifted `s` px right, and a narrow
    shaded right-hand side face `s` px wide. Returns (front, top, side) tone lists' index helpers as a dict of the rects, for decorations."""
    tn = tones(col, 5, lo, hi)
    tcol = top_col or tn[4]
    # top face: a parallelogram, each row shifted right as it recedes
    for k in range(1, d + 1):
        sh = int(round(s * k / float(d)))
        row_c = tcol if k < d else shade(tcol, 0.88)
        c.hline(x0 + sh, x1 + sh, yt - k, row_c)
    # the right side face: the same recession, a column per px
    for k in range(0, s):
        xx = x1 + 1 + k
        top = yt - int(round(d * (k + 1) / float(max(1, s))))
        for y in range(top, yb - int(round(d * (k + 1) / float(max(1, s)))) + 1):
            c.put(xx, y, tn[1] if y > top + 1 else tn[2])
    # the front face: banded, lit along the top and the left, shaded along the bottom and the right
    h = yb - yt + 1
    for y in range(yt, yb + 1):
        f = (y - yt) / float(max(1, h - 1))
        t = tn[3] if f < 0.30 else tn[2] if f < 0.78 else tn[1]
        c.hline(x0, x1, y, t)
    if edge:
        c.hline(x0, x1, yt, tn[4])
        c.vline(x0, yt, yb, tn[3])
        c.vline(x1, yt, yb, tn[1])
        c.hline(x0, x1, yb, tn[0])
    return {'x0': x0, 'x1': x1, 'yt': yt, 'yb': yb, 'd': d, 's': s, 'tn': tn}


def darken_around(c, mask, f=0.55):
    """Ambient occlusion: every already-drawn pixel touching `mask` (4-neighbourhood) but not in it is darkened — where one thing sits in front of another."""
    out = []
    for (x, y) in mask:
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q in mask or not (0 <= q[0] < c.w and 0 <= q[1] < c.h):
                continue
            px = c.px[q[0], q[1]]
            if px[3] == 255:
                out.append((q, shade(px, f)))
    for (q, col) in out:
        c.put(q[0], q[1], col)


# ------------------------------------------------------------------------------------------------------------------------------------ bin bags
SACK = _ramp(['090a10', '12141e', '1c2030', '282e44', '38405a', '4c5876'])
SACK_SPEC = (hexc('8a96b4'), hexc('c4cde4'))


def sack(c, cx, base, W, H, seed=0, tilt=0.0):
    """A tied black bin bag standing on the floor: a sagging lump (wide belly, flat-ish base), a gathered neck with a twist and two ears, plastic sheen in a broken streak, creases
    radiating from the neck, a cool rim light low on the right. (cx, base) = the bottom centre; returns the set of pixels it covers."""
    rng = random.Random(seed)
    top = base - H
    mask = set()
    hw_max = W / 2.0

    def half(t):
        if t < 0.10:
            return 1.2 + 2.0 * (t / 0.10)
        if t < 0.52:
            k = (t - 0.10) / 0.42
            return 3.2 + (hw_max - 3.2) * math.sin(k * math.pi / 2.0) ** 0.8
        if t < 0.80:
            return hw_max
        k = (t - 0.80) / 0.20
        return hw_max * max(0.0, 1.0 - k ** 3) ** (1.0 / 3.0)

    for y in range(top, base + 1):
        t = (y - top + 0.5) / float(H + 1)
        hw = half(t)
        shift = tilt * (1.0 - t) * 2.0                                      # a bag leans toward its tilt at the neck
        for x in range(int(math.floor(cx + shift - hw)), int(math.ceil(cx + shift + hw))):
            u = (x + 0.5 - (cx + shift)) / max(hw, 0.6)
            if abs(u) > 1.0:
                continue
            v = (t - 0.5) * 2.0
            nz = math.sqrt(max(0.0, 1.0 - u * u))
            lam = max(0.0, LX * u + LY * v * 0.55 + LZ * nz)
            lam = 0.10 + 0.78 * lam
            t_col = pick(SACK, lam)
            if u > 0.70 and v > -0.15:                                      # the cool bounce low on the right
                t_col = pick(SACK, lam + 0.18)
            if abs(u + 0.46) < 0.075 and -0.45 < v < 0.55 and (y + seed) % 5 != 0:
                t_col = SACK_SPEC[0]                                       # the sheen: a broken streak
                if abs(u + 0.46) < 0.03 and (y + seed) % 3 == 0:
                    t_col = SACK_SPEC[1]
            c.put(x, y, t_col)
            mask.add((x, y))
    for (a, ln) in ((-0.55, 0.62), (0.08, 0.78), (0.58, 0.66)):            # gathered wrinkles: a few clean dark lines fanning down from the neck
        for k in range(int(H * ln)):
            t = 0.17 + k / float(H + 1)
            if t > 0.86 or (k + seed) % 6 == 5:
                continue
            u = a * (0.28 + 0.72 * min(1.0, t * 1.5))
            x = int(round(cx + tilt * (1.0 - t) * 2.0 + u * half(t)))
            y = top + int(round(t * H))
            if (x, y) in mask:
                c.put(x, y, shade(c.px[x, y], 0.66))
    # the neck: a twist (diagonal bands), the tie, two ears
    ny = top
    nx = int(round(cx + tilt * 2.0))
    for k in range(0, 4):
        c.put(nx - 1, ny + k, SACK[2 + (k % 2)])
        c.put(nx, ny + k, SACK[3 - (k % 2)])
        c.put(nx + 1, ny + k, SACK[1 + (k % 2)])
        mask.update({(nx - 1, ny + k), (nx, ny + k), (nx + 1, ny + k)})
    ear_l = [(nx - 2, ny - 1), (nx - 3, ny - 2), (nx - 3, ny - 3)]
    ear_r = [(nx + 2, ny - 1), (nx + 3, ny - 1), (nx + 4, ny - 2)]
    for i, (x, y) in enumerate(ear_l + ear_r):
        c.put(x, y, SACK[4] if i in (2, 5) else SACK[2])
        mask.add((x, y))
    c.put(nx, ny - 1, SACK[3])
    c.put(nx - 1, ny - 1, SACK[1])
    mask.update({(nx, ny - 1), (nx - 1, ny - 1)})
    return mask


def pizza_boxes(c, x0, base, n=3, seed=0):
    """A short stack of flat pizza boxes: each a thin cardboard slab with its lid seam, the top one a little out of line, a grease stain and a printed circle on the lid."""
    rng = random.Random(seed)
    card = hexc('c8a870')
    w, hh, dd = 17, 3, 6
    y = base
    for k in range(n):
        off = rng.choice([-1, 0, 0, 1]) if k else 0
        xx = x0 + off
        y_top = y - hh + 1
        last = k == n - 1
        box3d(c, xx, xx + w - 1, y_top, y, dd if last else 2, shade(card, 0.96 - 0.04 * k), s=2, top_col=None)
        c.hline(xx + 1, xx + w - 2, y_top + 1, shade(card, 0.72))                  # the lid's lip
        y = y_top - 1
    # the lid of the top box: a printed pizza disc and a grease stain
    ytop_face = y + 1
    cx = x0 + w // 2 + 2
    cyy = ytop_face - 3
    for yy in range(cyy - 2, cyy + 3):
        for xx in range(cx - 4, cx + 5):
            q = ((xx - cx) / 4.2) ** 2 + ((yy - cyy) / 2.2) ** 2
            if q <= 1.0:
                c.put(xx, yy, hexc('d8a02c') if q > 0.55 else hexc('c0342a'))
    for xx in range(x0 + 2, x0 + 8):
        c.put(xx, ytop_face - 2, shade(card, 0.62))
    c.put(x0 + 4, ytop_face - 3, shade(card, 0.62))


def bin_bags(save, name, seed, style='three'):
    rng = random.Random(seed)
    w, d = 32, 11
    h = 18 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 1, w - 2, C - d, C, 110)
    # back to front, so each lower bag darkens the one behind it where it sits against it
    plans = {'three': [(16, C - 6, 16, 18, 1), (8, C, 13, 15, 2), (23, C - 1, 14, 14, 3)],
             'two': [(11, C - 5, 16, 18, 4), (22, C, 13, 15, 5)],
             'pizza': [(23, C - 3, 16, 18, 6)]}[style]
    if style == 'pizza':
        pizza_boxes(c, 1, C - 2, 3, seed)
    for (cx, base, W, H, sd) in plans:
        m = sack(c, cx, base, W, H, seed=sd + seed, tilt=rng.choice([-0.5, 0.0, 0.5]))
        darken_around(c, m, 0.62)
        for k in range(2):                                                   # a wrinkle of floor shadow under the belly
            c.put(cx - W // 2 + 1 + k, base + 1, shade(hexc('090a10'), 1.0))
    for k in range(5):                                                       # a split one: scraps on the floor in front, each with a little form
        x = rng.randrange(21, 30)
        yy = C + rng.randrange(-1, 1)
        col = rng.choice([hexc('d8d0c0'), hexc('8a6a3a'), hexc('6a8a4a')])
        c.put(x, yy, col)
        c.put(x + 1, yy, shade(col, 0.7))
        c.put(x, yy - 1, shade(col, 1.3))
    save(name, c)
    record(name, "door", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ newspapers
def _top_x(x0, x1, k, d, s):
    """The left / right x of row k (1..d) up the top face of a box3d: the back edge is `s` px to the right."""
    sh = int(round(s * k / float(d)))
    return x0 + sh, x1 + sh


def newspapers(save, name, seed):
    """A tied bundle of newspapers: a block of folded sheets (the edge of every sheet a pale line, the pack a little ragged where sheets sit proud), the front page on top (masthead bar,
    a headline slab, a photograph, ruled columns of text — no readable words), two turns of twine with a knot, and a loose page curling on the floor."""
    rng = random.Random(seed)
    w, d = 26, 8
    h = 15 + d + SHADOW                                                   # 26 x 25, as the drawing it replaced
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 2, w - 4, C - d, C)
    paper, ink = hexc('d6d0ba'), hexc('2a2a2e')
    x0, x1, yt, yb, dd, s = 3, 19, C - 12, C - 1, 5, 2
    box3d(c, x0, x1, yt, yb, dd, paper, s=s, lo=0.58, hi=1.18, top_col=shade(paper, 1.10))
    # every sheet's edge: pale / mid lines down the front with the odd grey one, and a ragged left side where sheets sit proud
    for i, y in enumerate(range(yt + 1, yb)):
        tone = shade(paper, 1.05) if i % 2 == 0 else shade(paper, 0.80 if rng.random() < 0.7 else 0.66)
        c.hline(x0 + 1, x1 - 1, y, tone)
        j = rng.choice([0, 0, 0, 1, -1])
        if j < 0:
            c.put(x0 - 1, y, shade(paper, 0.9))
        elif j > 0:
            c.put(x0, y, shade(paper, 0.55))
    # the front page, on the top face (each row further back sits `sh` px to the right)
    for k in range(1, dd):
        a, b = _top_x(x0 + 1, x1 - 1, k, dd, s)
        if k == 4:                                          # the masthead
            c.hline(a, b, yt - k, ink)
        elif k == 3:                                        # the headline slab
            c.hline(a + 1, a + 9, yt - k, shade(ink, 1.15))
            c.hline(a + 10, b, yt - k, shade(paper, 0.8))
        else:                                               # a photograph (left) and ruled columns (right)
            c.hline(a, a + 6, yt - k, hexc('6a6a72') if k == 2 else hexc('a2a2a8'))
            for xx in range(a + 8, b, 2):
                c.put(xx, yt - k, shade(paper, 0.62))
    # twine: two turns round the bundle, a knot where they cross on the top, two loose ends
    twine, twine_lt, twine_dk = hexc('a8864c'), hexc('d0ac6c'), hexc('6a5230')
    for xx in (8, 14):
        c.vline(xx, yt + 1, yb - 1, twine)
        c.vline(xx - 1, yt + 1, yb - 1, twine_lt)
        c.vline(xx + 1, yt + 1, yb - 1, twine_dk)
        for k in range(1, dd):
            a, _ = _top_x(xx, xx, k, dd, s)
            c.put(a, yt - k, twine)
            c.put(a - 1, yt - k, twine_lt)
    c.rect(7, yt - 1, 9, yt, twine_dk)
    c.put(8, yt - 1, twine_lt)
    c.put(6, yt - 2, twine); c.put(10, yt - 2, twine)
    # a loose page on the floor in front: a curled sheet with a fold line and a smudge of print
    c.poly([(15, C), (23, C - 2), (24, C), (17, C + 1)], hexc('e6e2d2'))
    c.line(15, C, 23, C - 2, hexc('f6f4ea'))
    c.hline(18, 22, C - 1, shade(ink, 1.3))
    c.line(17, C + 1, 24, C, shade(paper, 0.6))
    save(name, c)
    record(name, "door", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ parcels
def parcels(save, name, seed, style='stack'):
    """A cardboard parcel on the floor (and a smaller one set back on it, or a padded envelope): corrugated edges, a lit top with the flaps' seam, packing tape down the seam and the
    front, a printed label with a barcode, scuffs and a crushed corner."""
    rng = random.Random(seed)
    w, d = 26, 9
    h = 20 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    card = hexc('b88e5c')
    tape, tape_dk = hexc('e4d8a8'), hexc('b0a070')
    ground(c, 1, w - 3, C - d, C)
    x0, x1, yt, yb, dd, s = 1, 19, C - 10, C, 8, 3
    box3d(c, x0, x1, yt, yb, dd, card, s=s, lo=0.52, hi=1.22)
    # the flaps meet in a seam across the middle of the top; tape runs front-to-back over it and down the front
    for k in range(1, dd):
        a, b = _top_x(x0, x1, k, dd, s)
        if k == dd // 2:
            c.hline(a, b, yt - k, shade(card, 0.62))
    tx = 9
    for k in range(0, dd):
        a, _ = _top_x(tx, tx, k, dd, s)
        c.put(a, yt - k, tape)
        c.put(a + 1, yt - k, tape)
        c.put(a + 2, yt - k, tape_dk)
    c.vline(tx, yt, yb - 3, tape)
    c.vline(tx + 1, yt, yb - 3, tape)
    c.vline(tx + 2, yt, yb - 3, tape_dk)
    c.put(tx, yb - 2, tape_dk); c.put(tx + 1, yb - 3, tape_dk)           # the tape's torn end
    # corrugation showing at the cut edges of the top, a crushed lower-left corner, scuffs
    for yy in range(yt + 1, yb, 2):
        c.put(x0 + 1, yy, shade(card, 1.22))
    c.put(x0, yb, shade(card, 0.6)); c.put(x0 + 1, yb, shade(card, 0.6)); c.put(x0, yb - 1, shade(card, 0.7))
    for (sx, sy) in ((13, yt + 2), (15, yt + 6), (4, yt + 3)):
        c.hline(sx, sx + 2, sy, shade(card, 1.18))
    # the label: white sheet with a coloured band, address rules and a barcode
    c.rect(3, yb - 8, 8, yb - 2, hexc('eeeae0'))
    c.hline(3, 8, yb - 8, hexc('ffffff'))
    c.hline(3, 8, yb - 2, hexc('b0aca0'))
    c.hline(3, 8, yb - 7, hexc('c83a2a'))
    c.hline(4, 7, yb - 5, hexc('6a6a6a')); c.hline(4, 6, yb - 4, hexc('8a8a8a'))
    for xx in (4, 5, 7):
        c.vline(xx, yb - 3, yb - 3, hexc('1a1a1a'))
    if style == 'env':
        # a padded envelope left on top: a flat slab with its flap, quilted bubbles, a label
        env, env_dk = hexc('e0b860'), hexc('b08c38')
        ex, ey = 3, yt - 3
        c.poly([(ex, ey), (ex + 13, ey - 1), (ex + 15, ey - 5), (ex + 3, ey - 6)], env)
        c.line(ex, ey, ex + 13, ey - 1, shade(env, 1.28))
        c.line(ex + 13, ey - 1, ex + 15, ey - 5, env_dk)
        for q in range(ex + 3, ex + 13, 3):
            for r in range(ey - 5, ey, 2):
                c.put(q + (r % 4) // 2, r, shade(env, 1.14))
        c.poly([(ex + 1, ey - 2), (ex + 14, ey - 3), (ex + 13, ey - 4), (ex + 2, ey - 3)], shade(env, 0.84))
        c.rect(ex + 5, ey - 4, ex + 9, ey - 3, hexc('eeeae0'))
        c.hline(ex + 5, ex + 9, ey - 4, hexc('ffffff'))
        c.put(ex + 6, ey - 3, hexc('6a6a6a')); c.put(ex + 8, ey - 3, hexc('6a6a6a'))
    else:
        ox = 6 + rng.randrange(0, 4)
        yb2 = yt - 3
        box3d(c, ox, ox + 11, yb2 - 5, yb2, 5, shade(card, 1.06), s=2, lo=0.52, hi=1.22)
        c.hline(ox + 1, ox + 10, yb2 - 7, tape)
        c.rect(ox + 2, yb2 - 4, ox + 6, yb2 - 1, hexc('3a6ab8'))        # a courier's sticker: blue with a pale stripe
        c.hline(ox + 2, ox + 6, yb2 - 2, hexc('e8eef8'))
        c.hline(ox + 2, ox + 6, yb2 - 4, shade(hexc('3a6ab8'), 1.3))
    save(name, c)
    record(name, "door", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ luggage
def _disc(c, cx, cy, r, col, hi=None):
    """A small round lit disc (a caster, a stud): pixel-centre test, lit upper left."""
    tn = tones(col, 4, 0.5, 1.5)
    for y in range(int(math.floor(cy - r)) - 1, int(math.ceil(cy + r)) + 1):
        for x in range(int(math.floor(cx - r)) - 1, int(math.ceil(cx + r)) + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if dx * dx + dy * dy <= r * r:
                lam = 0.5 - 0.5 * (dx * 0.7 + dy * 0.7) / max(r, 0.5)
                c.put(x, y, pick(tn, lam))
    if hi is not None:
        c.put(int(round(cx - r * 0.4)), int(round(cy - r * 0.4)), hi)


def suitcase(save, name, seed):
    """An upright hard-shell case on four spinner casters: a ribbed shell (each rib lit on its left, shaded on its right), a zip seam round the middle with a pull, plastic corner guards,
    the telescopic handle drawn out of the top (two chrome posts and a grip bar), a carry handle, a luggage tag on a strap and a travel sticker. Top, front and the shaded right side."""
    rng = random.Random(seed)
    w, d = 18, 7
    h = 26 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    col = rng.choice([hexc('23364a'), hexc('6a2a30'), hexc('30382c'), hexc('7a6a52')])
    ground(c, 2, 16, C - d, C)
    x0, x1, yt, yb, dd, s = 2, 13, C - 21, C - 3, 5, 3
    b = box3d(c, x0, x1, yt, yb, dd, col, s=s, lo=0.46, hi=1.28)
    tn = b['tn']
    # the telescopic handle: two chrome posts rising from the top face, a grip bar across them
    steel = [hexc('4a4e58'), hexc('8a8e98'), hexc('c4c8d0'), hexc('f0f2f6')]
    ptop = yt - dd - 7
    for px in (5, 10):
        a, _ = _top_x(px, px, dd, dd, s)
        for y in range(ptop, yt - 1):
            c.put(a, y, steel[2])
            c.put(a + 1, y, steel[1])
        c.put(a, ptop, steel[3])
    a1, _ = _top_x(5, 5, dd, dd, s)
    a2, _ = _top_x(10, 10, dd, dd, s)
    c.hline(a1 - 1, a2 + 2, ptop - 1, hexc('18181c'))                     # the grip: black rubber, lit on top
    c.hline(a1, a2 + 1, ptop - 2, hexc('3a3a42'))
    c.hline(a1 - 1, a2 + 2, ptop, hexc('0e0e12'))
    # the zip seam round the middle of the shell: a row of teeth and a pull
    zy = yt + 8
    for xx in range(x0 + 1, x1):
        c.put(xx, zy, tn[0] if xx % 2 else steel[1])
    c.put(x0 + 2, zy + 1, steel[2]); c.put(x0 + 2, zy + 2, steel[1])
    # ribs: embossed uprights, each lit on its left edge and shaded on its right, rounded off at the ends
    for rx in (4, 7, 10):
        for y in range(yt + 2, yb - 1):
            if y == zy:
                continue
            c.put(rx, y, tn[4] if y < zy else tn[3])
            c.put(rx + 1, y, tn[0])
    # corner guards: dark plastic caps, lit on their upper-left corner
    guard, guard_lt = hexc('15151a'), hexc('3a3a44')
    for (gx, gy) in ((x0, yt), (x1 - 1, yt), (x0, yb - 1), (x1 - 1, yb - 1)):
        c.rect(gx, gy, gx + 1, gy + 1, guard)
        c.put(gx, gy, guard_lt)
    # spinner casters under the front corners
    for cx in (4, 11):
        _disc(c, cx, yb + 2, 1.8, hexc('18181c'), hexc('7a7a86'))
        c.put(cx, yb + 1, steel[1])
    # a carry handle on the lit side of the top, a luggage tag hanging off the front by a strap
    c.hline(x0 + 1, x0 + 3, yt - 1, hexc('15151a'))
    c.vline(x0 + 1, yt - 1, yt + 2, hexc('15151a'))
    c.vline(x0 + 4, yt + 3, yt + 6, hexc('b08850'))
    c.rect(x0 + 3, yt + 6, x0 + 5, yt + 9, hexc('ead890'))
    c.hline(x0 + 3, x0 + 5, yt + 6, hexc('fff4c0'))
    c.put(x0 + 4, yt + 8, hexc('5a5a5a'))
    # a round travel sticker low on the front
    sx, sy = 9, yb - 4
    _disc(c, sx, sy, 2.2, rng.choice([hexc('d8c038'), hexc('c83a3a'), hexc('f0f0e8')]), hexc('ffffff'))
    save(name, c)
    record(name, "door", d, C)


def holdall(save, name, seed):
    """A soft duffel lying on the floor: a cylinder lit from above (top bright, belly dark), a zip along the top between two webbing handles that arch up off it, a leather
    base strip with rivets, an end pocket on the shaded right with its own zip, a printed roundel and a brass buckle."""
    rng = random.Random(seed)
    w, d = 26, 8
    h = 10 + d + SHADOW                                                   # 26 x 20, as the drawing it replaced
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    col = rng.choice([hexc('34364a'), hexc('5a3a30'), hexc('40503a')])
    ground(c, 1, w - 2, C - d, C)
    tn = tones(col, 6, 0.40, 1.50)
    x0, x1, yt, yb = 2, 19, C - 11, C - 1
    # body: a horizontal cylinder (shading by height), its ends rounded in by a pixel
    for y in range(yt, yb + 1):
        v = (y - yt) / float(yb - yt)                                      # 0 top .. 1 bottom
        lam = 0.95 - 0.78 * v ** 1.1
        t = pick(tn, lam)
        a = x0 + (1 if y in (yt, yb) else 0)
        b_ = x1 - (1 if y in (yt, yb) else 0)
        c.hline(a, b_, y, t)
    # the right end: the stuffed end of the bag, a shaded oval with its own pocket + zip
    for y in range(yt + 1, yb):
        for x in range(x1 + 1, x1 + 4):
            if ((x - (x1 + 0.5)) / 3.2) ** 2 + ((y - (yt + yb) / 2.0) / 5.4) ** 2 <= 1.0:
                c.put(x, y, tn[1] if y < (yt + yb) / 2.0 else tn[0])
    c.hline(x1 + 1, x1 + 2, yt + 4, shade(tn[3], 0.8))
    c.put(x1 + 2, yt + 5, steel_lt := hexc('b0b4bc'))
    # leather base strip with rivets
    base = hexc('3a2618')
    c.hline(x0 + 1, x1 - 1, yb, base)
    c.hline(x0, x1, yb - 1, shade(base, 1.25))
    for xx in range(x0 + 3, x1 - 1, 4):
        c.put(xx, yb - 1, hexc('b8a888'))
    # the top zip + two webbing handles arching over it, each a 2 px band with a lit edge and a shadow under it
    c.hline(x0 + 2, x1 - 2, yt + 1, shade(tn[0], 0.7))
    for xx in range(x0 + 3, x1 - 2, 3):
        c.put(xx, yt + 1, hexc('5a5a62'))
    web, web_lt, web_dk = hexc('8a7a58'), hexc('c4b48a'), hexc('4a3e2a')
    for hx in (6, 14):                                                         # each strap: an arch standing off the top, lit on its upper edge, dark underneath
        c.hline(hx - 1, hx + 1, yt - 4, web_lt)
        c.put(hx - 2, yt - 3, web_lt); c.put(hx + 2, yt - 3, web)
        c.put(hx - 3, yt - 2, web); c.put(hx + 3, yt - 2, web_dk)
        c.vline(hx - 3, yt - 1, yt, web_dk); c.vline(hx + 3, yt - 1, yt, web_dk)
        c.hline(hx - 1, hx + 1, yt - 3, web)
        c.hline(hx - 1, hx + 1, yt, shade(tn[1], 0.7))                         # its shadow on the bag
        c.put(hx - 3, yt, web); c.put(hx + 3, yt, web_dk)
    # a printed roundel and a brass strap buckle on the front
    _disc(c, 9, (yt + yb) // 2 + 1, 2.6, hexc('d8d0c0'), None)
    _disc(c, 9, (yt + yb) // 2 + 1, 1.4, shade(col, 0.8), None)
    c.rect(15, yt + 4, 16, yt + 6, hexc('c8a448'))
    c.put(15, yt + 4, hexc('f0d880'))
    save(name, c)
    record(name, "door", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ bags
KRAFT = hexc('b99562')


def paper_bag(save, name, seed):
    """A tall kraft paper carrier bag: a front face with a folded base crease and a printed band, a gusseted side with its V fold, the opening seen from above (a dark inside, the
    rim folded over), rope handles that stand up off the top in two loops, and what is in it showing over the rim — a baguette and a bunch of leeks."""
    rng = random.Random(seed)
    w, d = 22, 7
    h = 34 + d + SHADOW                                                   # 22 x 43, as the drawing it replaced
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 2, 18, C - d, C)
    x0, x1, yt, yb, dd, s = 3, 14, C - 26, C, 4, 4
    b = box3d(c, x0, x1, yt, yb, dd, KRAFT, s=s, lo=0.52, hi=1.24)
    tn = b['tn']
    # the opening: the top face is the inside of the bag — dark, its back rim lit, its front rim a folded-over band
    for k in range(1, dd):
        a, bb = _top_x(x0 + 1, x1 - 1, k, dd, s)
        c.hline(a, bb, yt - k, shade(KRAFT, 0.28 + 0.06 * k))
    a, bb = _top_x(x0, x1, dd, dd, s)
    c.hline(a, bb, yt - dd, tn[4])
    c.hline(x0, x1, yt, shade(KRAFT, 1.28))                               # the folded-over rim, a pale band
    c.hline(x0, x1, yt + 1, tn[4])
    c.hline(x0, x1, yt + 2, shade(KRAFT, 0.78))
    # contents standing out of the opening: a baguette (a lit golden cylinder at a slant) and leeks
    for k in range(8):
        px, py = x0 + 3 + k // 2, yt - 3 - k
        c.put(px, py, hexc('e0b868')); c.put(px + 1, py, hexc('c89448')); c.put(px + 2, py, hexc('8a5e28'))
    c.put(x0 + 3, yt - 3, hexc('f0d08a'))
    for (lx, ln) in ((x0 + 8, 7), (x0 + 9, 6)):
        c.vline(lx, yt - 2 - ln, yt - 2, hexc('f0f0d8'))
        c.vline(lx + 1, yt - 2 - ln, yt - 2, hexc('b8c898'))
        c.hline(lx - 1, lx + 2, yt - 3 - ln, hexc('3a7a3a'))
        c.hline(lx - 2, lx + 3, yt - 4 - ln, hexc('4a9a4a'))
    # rope handles: two loops that stand up off the front and back of the opening, each a 1 px cord with a lit side and a dark side, knotted through the card
    rope, rope_lt = hexc('7a5a34'), hexc('c09a64')
    for xx in (x0 + 2, x1 - 3):
        c.vline(xx, yt - 12, yt - 2, rope)
        c.vline(xx - 1, yt - 12, yt - 2, rope_lt)
        c.put(xx, yt + 3, hexc('2a1e12')); c.put(xx - 1, yt + 3, shade(rope, 0.7))
    c.hline(x0 + 2, x0 + 6, yt - 13, rope_lt)
    c.hline(x1 - 3, x1 + 1, yt - 13, rope_lt)
    # the front: a folded base crease, vertical fold lines near the edges, a printed band with a pictogram (a basket: two arcs on a bar)
    c.hline(x0 + 1, x1 - 1, yb - 4, shade(KRAFT, 0.72))
    c.hline(x0 + 1, x1 - 1, yb - 3, tn[4])
    c.vline(x0 + 2, yt + 4, yb - 5, shade(KRAFT, 0.86))
    c.vline(x1 - 2, yt + 4, yb - 5, shade(KRAFT, 0.8))
    red = hexc('c4382c')
    c.rect(x0 + 2, yt + 8, x1 - 2, yt + 14, red)
    c.hline(x0 + 2, x1 - 2, yt + 8, shade(red, 1.3))
    c.hline(x0 + 2, x1 - 2, yt + 14, shade(red, 0.7))
    c.rect(x0 + 4, yt + 10, x1 - 4, yt + 11, hexc('f4ecd8'))
    c.rect(x0 + 4, yt + 12, x1 - 6, yt + 12, hexc('f4ecd8'))
    # the gusset: a V fold down the middle of the side face
    for y in range(yt - dd + 2, yb - 3):
        c.put(x1 + 2, y - 1, shade(KRAFT, 0.52))
    save(name, c)
    record(name, "door", d, C)


def carrier_bags(save, name, seed):
    """Two plastic carrier bags stood against each other: white and blue, each a slumped lump of film (lit upper left, a broken sheen streak, creases running down from the gathered top,
    two handle loops), with the shopping showing through — a bottle pushing out the front of the white one and its neck out of the top, a box corner in the blue."""
    rng = random.Random(seed)
    w, d = 26, 6
    h = 26 + d + SHADOW                                                   # 26 x 34, as the drawing it replaced
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 2, w - 3, C - d, C)

    def film(cx, base, W, H, ramp, spec, sd):
        m = set()
        top = base - H

        def half(t):
            if t < 0.16:
                return 1.6 + 3.2 * (t / 0.16)
            if t < 0.78:
                return W / 2.0
            k = (t - 0.78) / 0.22
            return W / 2.0 * max(0.0, 1.0 - k ** 3) ** (1.0 / 3.0)

        for y in range(top, base + 1):
            t = (y - top + 0.5) / float(H + 1)
            hw = half(t)
            for x in range(int(math.floor(cx - hw)), int(math.ceil(cx + hw))):
                u = (x + 0.5 - cx) / max(hw, 0.7)
                if abs(u) > 1.0:
                    continue
                v = (t - 0.5) * 2.0
                nz = math.sqrt(max(0.0, 1.0 - u * u))
                lam = 0.12 + 0.80 * max(0.0, LX * u + LY * v * 0.5 + LZ * nz)
                col = pick(ramp, lam)
                if abs(u + 0.5) < 0.09 and -0.2 < v < 0.6 and (y + sd) % 4 != 0:
                    col = spec
                c.put(x, y, col)
                m.add((x, y))
        for (a_, ln) in ((-0.5, 0.55), (0.1, 0.7), (0.55, 0.5)):          # creases from the gathered top
            for k in range(int(H * ln)):
                t = 0.18 + k / float(H + 1)
                if t > 0.85 or (k + sd) % 5 == 4:
                    continue
                u = a_ * (0.3 + 0.7 * min(1.0, t * 1.5))
                x = int(round(cx + u * half(t)))
                y = top + int(round(t * H))
                if (x, y) in m:
                    c.put(x, y, shade(c.px[x, y], 0.78))
        return m, top

    white = _ramp(['8c909c', 'a8acb8', 'c4c8d2', 'dcdee6', 'eef0f4'])
    blue = _ramp(['10244e', '1a3a78', '2650a2', '3c6ccc', '6a98e8'])
    # the blue one first (behind), a box corner pushing out of its right side
    m, top = film(18, C - 1, 13, 21, blue, hexc('b4cdf6'), 3)
    c.rect(21, top + 9, 23, top + 14, shade(blue[3], 1.05))
    c.vline(23, top + 9, top + 14, blue[1])
    c.hline(21, 23, top + 9, blue[4])
    for (hx, dx) in ((16, -1), (19, 1)):                                    # handles: two loops, the front one lit
        c.vline(hx, top - 4, top, blue[3]); c.vline(hx + dx, top - 5, top - 3, blue[2])
    c.hline(16, 19, top - 5, blue[4])
    # then the white one in front, a bottle in it
    m2, top2 = film(9, C, 13, 22, white, hexc('ffffff'), 5)
    darken_around(c, m2, 0.70)
    for yy in range(top2 + 8, top2 + 17):                                    # the bottle's bulge in the film: a lighter rounded form with a shaded right edge
        c.put(6, yy, white[4]); c.put(7, yy, white[3]); c.put(8, yy, white[3]); c.put(9, yy, white[2]); c.put(10, yy, white[1])
    c.put(6, top2 + 8, white[3]); c.put(10, top2 + 8, white[2])
    glass, glass_lt = hexc('2a6a3a'), hexc('7ac88a')
    c.vline(8, top2 - 7, top2 - 1, glass); c.vline(9, top2 - 7, top2 - 1, shade(glass, 0.7)); c.vline(7, top2 - 6, top2 - 1, glass_lt)
    c.hline(7, 9, top2 - 8, hexc('b8a050'))                                 # the foil cap
    for (hx, dx) in ((6, -1), (11, 1)):
        c.vline(hx, top2 - 4, top2, white[3]); c.vline(hx + dx, top2 - 5, top2 - 2, white[2])
    c.hline(5, 12, top2 - 5, white[4])
    save(name, c)
    record(name, "door", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ wheels + chrome (shared by the pram and the scooter)
CHROME = _ramp(['3a3e48', '6a6e7a', '9a9eaa', 'c8ccd6', 'f2f4f8'])


def line_px(c, x0, y0, x1, y1, cols, w=2):
    """A straight chrome / steel tube `w` px thick (a lit edge on the upper left, a dark one on the lower right): cols = a ramp, darkest first."""
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    steep = dy > dx
    pts = []
    x, y = x0, y0
    sx, sy = (1 if x1 > x0 else -1), (1 if y1 > y0 else -1)
    err = dx - dy
    while True:
        pts.append((x, y))
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x += sx
        if e2 < dx:
            err += dx
            y += sy
    for (x, y) in pts:
        for k in range(w):
            col = cols[3] if k == 0 else cols[1] if k == w - 1 else cols[2]
            if steep:
                c.put(x + k, y, col)
            else:
                c.put(x, y + k, col)


def wheel_side(c, cx, cy, r, tyre=2.0, spokes=4, rim=CHROME, tyre_cols=None):
    """A wheel seen side-on: a tyre ring (lit arc upper-left, dark lower-right), a chrome rim ring, thin spokes and a hub. (cx, cy) on a pixel boundary."""
    tc = tyre_cols or _ramp(['0e0e10', '1c1c20', '2a2a30', '44444c'])
    ri = r - tyre
    for y in range(int(math.floor(cy - r)) - 1, int(math.ceil(cy + r)) + 1):
        for x in range(int(math.floor(cx - r)) - 1, int(math.ceil(cx + r)) + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d2 = dx * dx + dy * dy
            if d2 > r * r:
                continue
            k = -(dx + dy) * 0.7071 / max(math.sqrt(d2), 0.01)
            if d2 <= (ri - 1.0) ** 2:
                c.put(x, y, tc[0])                                          # the dark back of the wheel, so nothing behind shows through the spokes
            elif d2 > ri * ri:
                c.put(x, y, tc[3] if (k > 0.6 and d2 > (r - 1.1) ** 2) else tc[0] if k < -0.45 else tc[1])
            elif d2 > (ri - 1.0) ** 2:
                c.put(x, y, rim[3] if k > -0.3 else rim[1])
    reach = ri - 1.4
    for i in range(spokes):
        a = i * math.pi / spokes
        for sgn in (1, -1):
            ex, ey = int(round(math.cos(a) * reach * sgn)), int(round(math.sin(a) * reach * sgn))
            col = rim[2] if (sgn * (math.cos(a) + math.sin(a))) <= 0.01 else rim[1]
            c.line(int(cx), int(cy), int(cx) + ex, int(cy) + ey, col)
    c.put(int(cx) - 1, int(cy) - 1, rim[3]); c.put(int(cx), int(cy) - 1, rim[2]); c.put(int(cx) - 1, int(cy), rim[2]); c.put(int(cx), int(cy), rim[1])


def wheel_solid(c, cx, cy, r, tyre=2.0, core=None):
    """A small wheel with a solid hub disc (a pram's or a scooter's — at this size spokes read as eyes): a tyre ring lit upper-left / dark lower-right, a bevelled core disc
    shaded like a ball in the core colour (chrome by default), a dark centre bolt. (cx, cy) on a pixel boundary."""
    core = core or CHROME[2]
    tc = _ramp(['0e0e10', '1c1c20', '2a2a30', '4c4c56'])
    ri = r - tyre
    for y in range(int(math.floor(cy - r)) - 1, int(math.ceil(cy + r)) + 1):
        for x in range(int(math.floor(cx - r)) - 1, int(math.ceil(cx + r)) + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d2 = dx * dx + dy * dy
            if d2 > r * r:
                continue
            k = -(dx + dy) * 0.7071 / max(math.sqrt(d2), 0.01)
            if d2 > ri * ri:
                c.put(x, y, tc[3] if (k > 0.55 and d2 > (r - 1.2) ** 2) else tc[0] if k < -0.4 else tc[1])
    propkit.sphere(c, cx, cy, ri, ri, core, n=5, lo=0.46, hi=1.40)
    c.put(int(cx) - 1, int(cy) - 1, shade(core, 0.45)); c.put(int(cx), int(cy) - 1, shade(core, 0.6)); c.put(int(cx) - 1, int(cy), shade(core, 0.6))


# ------------------------------------------------------------------------------------------------------------------------------------ pram
def pram(save, name, seed, body_hex=None):
    """A pram seen from the side and a little above: a deep carrycot (leatherette — a lit shoulder, a darker belly, white piping), its open top showing a quilted blanket and a bear, a
    ribbed hood folded up over the head end, a chrome chassis with crossed legs, four real wheels (tyre, rim, spokes, hub; the far pair showing behind), a padded push bar."""
    rng = random.Random(seed)
    w, d = 34, 9
    h = 32 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    body = rng.choice([hexc('2a3a5a'), hexc('5a2a3a'), hexc('3a4a3a')]) if body_hex is None else hexc(body_hex)
    ground(c, 2, w - 3, C - d, C)
    btn = tones(body, 6, 0.50, 1.55)
    r = 5.5
    # far wheels first, higher and dimmer (the other side of the pram, seen over the top of the near ones)
    for fx in (9.0, 25.0):
        wheel_solid(c, fx, C - 5 - 3, 5.0, tyre=1.8, core=shade(CHROME[2], 0.55))
    # the chassis: crossed legs (chrome) from the axles up to the cot's underside
    ax_f, ax_r = 9, 25
    cot_bottom = C - 10
    line_px(c, ax_f, C - 5, 20, cot_bottom, CHROME, 2)
    line_px(c, ax_r, C - 5, 14, cot_bottom, CHROME, 2)
    c.put(17, cot_bottom + 2, CHROME[4])
    # the carrycot: a boat-shaped tub, shaded by height (lit shoulder, shadowed belly), a white piping line, a lit rim
    x0, x1, top, bot = 5, 28, C - 22, cot_bottom
    for y in range(top, bot + 1):
        f = (y - top) / float(bot - top)
        inset = 0 if f < 0.7 else int(round(3.0 * ((f - 0.7) / 0.3) ** 1.6))
        t = btn[4] if f < 0.10 else btn[3] if f < 0.34 else btn[2] if f < 0.6 else btn[1] if f < 0.85 else btn[0]
        c.hline(x0 + inset, x1 - inset, y, t)
        c.put(x0 + inset, y, btn[4] if f < 0.6 else btn[2])               # the lit left end
        c.put(x1 - inset, y, btn[0])                                      # the shaded right end
    c.hline(x0 + 1, x1 - 1, top, shade(body, 1.9))                        # the rim catches the light
    py = top + 6
    c.hline(x0, x1, py, hexc('e8e4da'))                                    # piping
    c.hline(x0, x1, py + 1, shade(hexc('e8e4da'), 0.7))
    for sx in (x0 + 5, x1 - 5):                                           # a pair of studs holding the apron
        c.put(sx, py + 4, CHROME[4]); c.put(sx + 1, py + 4, CHROME[1])
    # the open top: the inside in shadow, a quilted blanket with a folded edge, a bear's head over the lip
    for k in range(1, 6):
        c.hline(x0 + 1 + k // 3, x1 - 1 + k // 3, top - k, shade(body, 0.30 + 0.05 * k))
    c.hline(x0 + 2, x1 - 1, top - 5, btn[3])
    bl, bl_dk = hexc('f0e8dc'), hexc('b8aea0')
    for k in range(1, 5):
        c.hline(x0 + 10 + k // 3, x1 - 2 + k // 3, top - k, bl if (k % 2) else shade(bl, 0.9))
    c.hline(x0 + 10, x1 - 2, top - 1, bl_dk)
    for qx in range(x0 + 12, x1 - 2, 4):                                  # quilting
        c.put(qx, top - 2, bl_dk); c.put(qx + 2, top - 3, bl_dk)
    bear = hexc('b88850')
    propkit.sphere(c, x0 + 12.5, top - 4.5, 2.6, 2.4, bear, n=5, lo=0.55, hi=1.45)
    for ex in (x0 + 10.6, x0 + 14.6):
        propkit.sphere(c, ex, top - 6.6, 1.1, 1.1, bear, n=4, lo=0.55, hi=1.4)
    c.put(x0 + 12, top - 4, hexc('1a1410')); c.put(x0 + 13, top - 4, hexc('1a1410'))
    # the hood: a folded canopy over the head end, a lit dome with three ribs and a piped edge
    hx, hr, hy = x0 + 7.0, 9.0, top - 0.5
    htn = tones(shade(body, 1.12), 6, 0.52, 1.30)
    for y in range(int(hy - 11), int(hy) + 1):
        for x in range(int(hx - hr), int(hx + hr) + 1):
            u, v = (x + 0.5 - hx) / hr, (y + 0.5 - hy) / 11.0
            q = u * u + v * v
            if q > 1.0:
                continue
            nz = math.sqrt(1.0 - q)
            lam = 0.10 + 0.88 * max(0.0, LX * u + LY * v + LZ * nz)
            c.put(x, y, pick(htn, lam))
    rib_pts = set()
    for rr in (0.50, 0.78):                                              # the hood's ribs: two concentric arcs, one pixel each, a step darker than the fabric under them
        for x in range(int(hx - hr * rr), int(hx + hr * rr) + 1):
            u = (x + 0.5 - hx) / (hr * rr)
            if abs(u) <= 1.0:
                y = int(round(hy - 11.0 * rr * math.sqrt(1.0 - u * u)))
                rib_pts.add((x, y))
    for (x, y) in rib_pts:
        if c.px[x, y][3]:
            c.put(x, y, shade(c.px[x, y], 0.66))
    for x in range(int(hx - hr), int(hx + hr) + 1):                     # a piped edge along the dome's outline
        u = (x + 0.5 - hx) / hr
        if abs(u) <= 1.0:
            y = int(round(hy - 11.0 * math.sqrt(1.0 - u * u)))
            c.put(x, y, hexc('d8d4ca') if u < 0.35 else shade(hexc('d8d4ca'), 0.6))
    c.hline(int(hx - hr), int(hx + hr), top, btn[0])                     # the hood's hem on the rim
    # the push bar: a chrome stem up from the cot's back, a black foam grip
    line_px(c, x1 - 1, top + 2, 31, top - 10, CHROME, 2)
    c.rect(29, top - 13, 33, top - 11, hexc('141418'))
    c.hline(29, 33, top - 13, hexc('4a4a54'))
    c.put(29, top - 12, hexc('2a2a30'))
    # the near wheels over everything
    for fx in (9.0, 25.0):
        wheel_solid(c, fx, C - 5, r, tyre=2.0)
    c.hline(6, 12, C + 1, hexc('0a0a0c')); c.hline(22, 28, C + 1, hexc('0a0a0c'))
    save(name, c)
    record(name, "door", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ scooter
def scooter(save, name, seed):
    """A child's kick scooter, seen from the side and a little above: a deck with a lit top face, grip-tape dots and a side stripe, a chrome stem on a raked head tube with a clamp
    and lever, a T-bar with a pink rubber grip at the near end, a small front wheel on a fork, a rear wheel under a spring brake, a kickstand."""
    rng = random.Random(seed)
    w, d = 34, 5
    h = 38 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    deck_c = rng.choice([hexc('3a82d0'), hexc('6ac038'), hexc('d8a028')])
    grip = hexc('e04a8c')
    ground(c, 2, w - 3, C - d, C)
    wr = 3.5
    fwx, rwx, wy = 7.0, 28.0, C - 3.5
    # the deck: a thin slab, its top face a lit parallelogram with grip-tape dots, its front edge a coloured stripe
    dx0, dx1, dyt, dyb = 10, 28, C - 9, C - 7
    for k in range(1, 4):
        sh = int(round(2 * k / 3.0))
        c.hline(dx0 + sh, dx1 + sh, dyt - k, shade(deck_c, 1.18 - 0.08 * k))
    for k in range(1, 4):                                               # grip tape: a darker band down the middle of the top face, a pale edge each side
        sh = int(round(2 * k / 3.0))
        c.hline(dx0 + 2 + sh, dx1 - 2 + sh, dyt - k, shade(deck_c, 0.62 - 0.04 * k))
    for y in range(dyt, dyb + 1):
        c.hline(dx0, dx1, y, shade(deck_c, 0.95 - 0.16 * (y - dyt)))
    c.hline(dx0, dx1, dyt, shade(deck_c, 1.4))
    c.hline(dx0 + 1, dx1 - 1, dyb, hexc('141418'))
    c.vline(dx1 + 1, dyt - 3, dyb - 1, shade(deck_c, 0.45))
    # rear wheel under its spring brake
    wheel_solid(c, rwx, wy, wr, tyre=1.5, core=hexc('d8dce4'))
    c.hline(int(rwx) - 4, int(rwx) + 3, int(wy) - 5, CHROME[3])           # the fender: a curved plate over the wheel
    c.hline(int(rwx) - 3, int(rwx) + 2, int(wy) - 6, CHROME[2])
    c.put(int(rwx) - 5, int(wy) - 4, CHROME[2]); c.put(int(rwx) + 4, int(wy) - 4, CHROME[1])
    # head tube + stem: raked up and back from the front wheel
    hx0, hy0 = 9, C - 8
    hx1, hy1 = 13, C - 32
    line_px(c, 8, C - 4, hx0, hy0, [shade(q, 0.9) for q in CHROME], 2)    # the fork
    line_px(c, hx0, hy0, hx1, hy1, CHROME, 3)                            # the stem: a chrome tube, lit on its left
    mid = (hx0 + (hx1 - hx0) * 0.52, hy0 + (hy1 - hy0) * 0.52)
    c.rect(int(mid[0]) - 1, int(mid[1]) - 1, int(mid[0]) + 4, int(mid[1]) + 1, hexc('2a2a30'))   # the clamp collar
    c.hline(int(mid[0]) - 1, int(mid[0]) + 4, int(mid[1]) - 1, hexc('5a5a64'))
    c.rect(int(mid[0]) + 4, int(mid[1]) - 1, int(mid[0]) + 6, int(mid[1]), hexc('e04a8c'))          # its quick-release lever
    # the T-bar: it runs across the scooter, so from the side it is a short bar with the NEAR grip end-on as a pink disc and the far grip a smaller, darker one behind the stem
    c.hline(hx1 - 5, hx1 + 4, hy1 - 1, CHROME[3])
    c.hline(hx1 - 5, hx1 + 4, hy1, CHROME[1])
    gx, gy = int(hx1) + 5, int(hy1) - 1                                   # the near grip, end-on: a rounded 5 x 5 block, lit upper left
    for yy in range(gy - 2, gy + 3):
        for xx in range(gx - 2, gx + 3):
            if (abs(xx - gx) == 2 and abs(yy - gy) == 2):
                continue
            lam = 1.0 - ((xx - gx) + (yy - gy) + 4) / 8.0
            c.put(xx, yy, shade(grip, 0.55 + 0.9 * lam))
    c.put(gx - 1, gy - 1, shade(grip, 1.75))
    gx2, gy2 = int(hx1) - 6, int(hy1) - 1                                  # the far grip, behind the stem, smaller and darker
    for yy in range(gy2 - 1, gy2 + 2):
        for xx in range(gx2 - 1, gx2 + 2):
            c.put(xx, yy, shade(grip, 0.78 if (xx + yy) % 2 == 0 or yy > gy2 else 0.66))
    c.put(gx2 - 1, gy2 - 1, shade(grip, 0.95))
    # front wheel
    wheel_solid(c, fwx, wy, wr, tyre=1.5, core=hexc('d8dce4'))
    # kickstand
    line_px(c, 20, dyb + 1, 17, C, [shade(q, 0.8) for q in CHROME], 1)
    save(name, c)
    record(name, "door", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ rods (legs, handles, umbrellas)
def rod(c, p0, p1, r0, r1, col, bulge=0.0, n=5, lo=0.46, hi=1.20, cap0=True, cap1=True):
    """A straight round rod from p0 to p1 (radius r0 -> r1, plus a `bulge` swell midway), shaded across its width like a cylinder lit from the upper left: the side facing the light is
    the lightest, the far side the darkest. Pixel-centre test, so it is as thick on a slant as upright."""
    (x0, y0), (x1, y1) = p0, p1
    L = math.hypot(x1 - x0, y1 - y0)
    if L < 1e-6:
        return
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny = -uy, ux
    if nx * LX + ny * LY < 0.0:
        nx, ny = -nx, -ny                                                    # +n faces the light
    tn = tones(col, n, lo, hi)
    rmax = max(r0, r1) + bulge + 1
    for y in range(int(math.floor(min(y0, y1) - rmax)) - 1, int(math.ceil(max(y0, y1) + rmax)) + 1):
        for x in range(int(math.floor(min(x0, x1) - rmax)) - 1, int(math.ceil(max(x0, x1) + rmax)) + 1):
            dx, dy = x + 0.5 - x0, y + 0.5 - y0
            t = (dx * ux + dy * uy) / L
            if t < 0.0 or t > 1.0:
                if not ((t < 0.0 and cap0 and -t * L <= r0 * 0.6) or (t > 1.0 and cap1 and (t - 1.0) * L <= r1 * 0.6)):
                    continue
            tt = min(1.0, max(0.0, t))
            rad = r0 + (r1 - r0) * tt + bulge * math.sin(math.pi * tt)
            o = dx * nx + dy * ny
            if abs(o) > rad:
                continue
            u = o / max(rad, 0.5)
            nz = math.sqrt(max(0.0, 1.0 - u * u))
            lam = 0.14 + 0.82 * max(0.0, 0.62 * u + 0.78 * nz * 0.55 + 0.2)
            c.put(x, y, pick(tn, min(1.0, lam)))


# ------------------------------------------------------------------------------------------------------------------------------------ hall chairs
WOOD, WOOD_DK = hexc('7a5236'), hexc('4e321e')


def hall_chair(save, name, seed, down=False, spindle=False):
    """A hall chair against the wall, somewhere to wait for the lift: four turned legs (the near pair full height, the far pair behind and shorter on the page), a side rail and a
    front rail, a deep seat — frame, a padded top with piped edges and a button — and a back of two posts with a curved crest rail and either an upholstered panel or four spindles."""
    seat_c = hexc('8a3a3a') if seed % 2 else hexc('3a5a4a')
    wood = WOOD
    if spindle:
        seat_c = shade(wood, 1.12)
        wood = hexc('8a6a48')
    if down:
        return chair_fallen(save, name, seed, wood, WOOD_DK, seat_c)
    w, d = 20, 9
    h = 30 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 2, 18, C - d, C)
    seat_y = C - 12                                                         # the top of the seat's front frame
    dd, s = 6, 2
    back_y = C - d + 1                                                      # where the back legs stand (floor line of the far side)
    # the far (back) legs, standing behind: shorter on the page, a step darker
    for bx in (5, 15):
        rod(c, (bx + 0.5, seat_y - dd + 3), (bx + 0.5, back_y), 1.0, 0.8, shade(wood, 0.78))
    # the back: two posts rising from the far seat corners, a crest rail, then the filling
    post_top = seat_y - dd - 15
    for bx in (5, 15):
        rod(c, (bx + 1.0, seat_y - dd + 1), (bx + 1.0, post_top + 1), 1.1, 1.1, wood)
    crest = [(5, post_top), (6, post_top - 1)]
    for x in range(5, 18):                                                  # the crest rail: an arch, 3 px deep, lit along the top
        arch = int(round(1.4 * math.sin(math.pi * (x - 5) / 12.0)))
        c.vline(x, post_top - arch, post_top - arch + 2, shade(wood, 1.0))
        c.put(x, post_top - arch, shade(wood, 1.22))
        c.put(x, post_top - arch + 2, shade(wood, 0.6))
    if spindle:
        for sx in (7, 9, 11, 13):
            rod(c, (sx + 0.5, post_top + 3), (sx + 0.5, seat_y - dd - 1), 0.7, 0.7, wood, n=4)
        c.hline(6, 15, seat_y - dd - 4, shade(wood, 0.82))                  # the lower back rail
        c.hline(6, 15, seat_y - dd - 5, shade(wood, 1.3))
    else:
        px0, px1, py0, py1 = 7, 14, post_top + 4, seat_y - dd - 3
        for yy in range(py0, py1 + 1):
            f = (yy - py0) / float(max(1, py1 - py0))
            c.hline(px0, px1, yy, shade(seat_c, 1.18 - 0.5 * f))
        c.hline(px0, px1, py0, shade(seat_c, 1.6)); c.hline(px0, px1, py1, shade(seat_c, 0.45))   # piped edges: lit above, dark below
        c.vline(px0, py0, py1, shade(seat_c, 1.35)); c.vline(px1, py0, py1, shade(seat_c, 0.55))
        c.put(px0 + 2, (py0 + py1) // 2, shade(seat_c, 0.5)); c.put(px1 - 2, (py0 + py1) // 2, shade(seat_c, 0.5))   # two buttons
    # the seat: the frame's front face (an apron), the right side face, the cushion on top with piping
    b = box3d(c, 2, 16, seat_y, seat_y + 3, dd, wood, s=s, lo=0.46, hi=1.34, top_col=shade(seat_c, 1.0))
    for k in range(1, dd):                                                  # the cushion's top: lit toward the left front, shaded toward the back, piped round
        a, bb = _top_x(3, 15, k, dd, s)
        c.hline(a, bb, seat_y - k, shade(seat_c, 1.28 - 0.1 * k))
    a, bb = _top_x(3, 15, 1, dd, s)
    c.hline(a, bb, seat_y - 1, shade(seat_c, 1.65))                         # the piping along the front edge
    c.put((_top_x(9, 9, 3, dd, s)[0]), seat_y - 3, shade(seat_c, 0.5))      # the button in its middle
    # the near (front) legs: turned — a cylinder shaft with a thicker block at the top and a slim ankle
    for fx in (3, 16):
        rod(c, (fx + 0.5, seat_y + 4), (fx + 0.5, C), 1.0, 0.75, wood, bulge=0.25)
        c.put(fx, seat_y + 4, shade(wood, 1.2))
        c.hline(fx - 1, fx + 1, C, shade(WOOD_DK, 0.7))                     # the foot's contact
    # a front rail between the near legs and a side rail running back on the shaded side
    c.hline(5, 15, C - 5, shade(wood, 1.1)); c.hline(5, 15, C - 4, shade(wood, 0.62))
    c.line(17, C - 4, 17 + 1, C - d + 2, shade(WOOD_DK, 0.9))
    save(name, c)
    record(name, "open", d, C)


def chair_fallen(save, name, seed, wood, dk, seat_c):
    """A hall chair knocked onto its side: the backrest lying flat on the floor to the left (its padded face up toward us, in a frame), the seat standing on its edge, and the legs
    — turned rods, near pair and far pair, with a rail between — stretching out along the floor to the right."""
    wood = shade(wood, 1.25)
    w, d = 38, 12
    h = 22 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 1, w - 2, C - d, C, 95)
    # the backrest, a frame lying flat: its top face (the padded face) a parallelogram going back, its front edge a thin lit rail
    bx0, bx1, byb = 2, 14, C - 1
    box3d(c, bx0, bx1, byb - 2, byb, d - 3, wood, s=2, lo=0.46, hi=1.34, top_col=shade(wood, 0.95))
    for k in range(2, d - 4):
        a, bb = _top_x(bx0 + 2, bx1 - 2, k, d - 3, 2)
        c.hline(a, bb, byb - 2 - k, shade(seat_c, 1.25 - 0.05 * k))
    a, bb = _top_x(bx0 + 2, bx1 - 2, 2, d - 3, 2)
    c.hline(a, bb, byb - 4, shade(seat_c, 1.65))
    for k in (4, d - 6):
        a, _ = _top_x(bx0 + 4, bx0 + 4, k, d - 3, 2)
        c.put(a + 3, byb - 2 - k, shade(seat_c, 0.5))
    # the seat standing on its edge: a thick frame, the cushion facing left
    sx0, sx1 = 15, 19
    for y in range(C - 19, C):
        f = (y - (C - 19)) / 18.0
        c.hline(sx0, sx1, y, shade(wood, 1.15 - 0.55 * f))
    c.vline(sx0, C - 19, C - 1, shade(seat_c, 1.0)); c.vline(sx0 + 1, C - 19, C - 1, shade(seat_c, 1.3))
    c.hline(sx0, sx1, C - 19, shade(wood, 1.55))
    c.vline(sx1, C - 19, C - 1, shade(wood, 0.5))
    # the legs: near pair (low) and far pair (up the page, behind), each a turned rod lying along the floor
    for yl, f in ((C - 4, 1.0), (C - 13, 0.78)):
        rod(c, (20, yl), (34, yl), 1.4, 1.0, shade(wood, f), bulge=0.3)
        c.put(35, yl, shade(dk, 0.7)); c.put(35, yl + 1, shade(dk, 0.55))     # the foot's end
    rod(c, (27, C - 4), (27, C - 13), 0.8, 0.8, shade(wood, 0.8), n=4)       # the rail between them, across the depth
    rod(c, (21, C - 8.5), (33, C - 8.5), 0.8, 0.7, shade(wood, 0.7), n=4)
    save(name, c)
    record(name, "open", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ umbrella stand
def umbrella_stand(save, name, seed, ceramic=False):
    """An umbrella stand by the door: a pot (brass or blue-grey metal with a turned rim, collar and foot ring — or a tall glazed ceramic jar with painted bands and a chipped lip), its
    dark mouth, and what stands in it — a black umbrella furled and strapped, a walking-stick umbrella with a curved wooden crook leaning out over the rim."""
    rng = random.Random(seed)
    w, d = 18, 6
    h = 30 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 3, 14, C - d, C)
    top, bot = C - 15, C - 3
    cx = 9.0
    # the umbrellas first, then the pot over their lower ends
    cloth = hexc('2a3248')
    rod(c, (7.0, top + 1), (6.2, top - 16), 1.4, 1.2, cloth, bulge=0.9, lo=0.40, hi=1.5)       # a furled one, slightly swelling in the middle, leaning a touch
    for yy in (top - 5, top - 9, top - 13):                                                    # its folds
        c.put(5, yy, shade(cloth, 0.62)); c.put(6, yy - 1, shade(cloth, 1.35))
    c.hline(5, 7, top - 8, hexc('c8b890')); c.hline(5, 7, top - 7, hexc('8a7a58'))           # the strap
    c.put(6, top - 16, hexc('9a9aa4')); c.put(6, top - 17, hexc('c8c8d0'))                    # the ferrule
    stick = hexc('7a3a2a')
    rod(c, (11.5, top + 1), (14.6, top - 14), 0.95, 0.85, stick, lo=0.40, hi=1.35)            # a walking-stick umbrella, leaning out to the right
    wood = hexc('b88a50')
    rod(c, (14.6, top - 14), (14.8, top - 17), 0.9, 0.9, wood)                                # the crook: up, over, down
    rod(c, (14.8, top - 17), (12.0, top - 18.5), 0.9, 0.9, wood)
    rod(c, (12.0, top - 18.5), (11.2, top - 16.0), 0.9, 0.8, wood)
    c.put(13, top - 19, shade(wood, 1.3)); c.put(14, top - 18, shade(wood, 1.3))
    if ceramic:
        glaze = hexc('e6e2da')
        propkit.cyl(c, cx, top - 1, bot, 5.0, glaze, ry=2.2, inner=hexc('1a1816'), n=6, lo=0.50, hi=1.12, gloss=True)
        for yy in (top + 3, top + 8):                                                          # painted bands, shaded round the jar like the glaze under them
            for x in range(4, 14):
                u = (x + 0.5 - cx) / 5.0
                lam = 0.2 + 0.7 * max(0.0, -0.6 * u + 0.6)
                c.put(x, yy, pick(tones(hexc('2e58a8'), 5, 0.45, 1.3), lam))
                c.put(x, yy + 1, shade(pick(tones(hexc('2e58a8'), 5, 0.45, 1.3), lam), 0.82))
        c.put(5, top - 1, shade(glaze, 0.5)); c.put(6, top - 2, hexc('1a1816'))                # a chip out of the lip
    else:
        metal = rng.choice([hexc('b08840'), hexc('52606e')])
        propkit.frustum(c, cx, top, bot, 5.0, 4.3, metal, ry_t=2.2, ry_b=1.9, inner=hexc('141210'), rim=shade(metal, 1.35), n=6, lo=0.46, hi=1.30, gloss=True)
        for yy in (top + 3,):                                                                  # a collar band
            for x in range(4, 14):
                u = (x + 0.5 - cx) / 5.0
                if abs(u) <= 1.0:
                    c.put(x, yy, shade(metal, 0.62 + 0.5 * max(0.0, -0.5 * u + 0.6)))
        for x in range(4, 14):                                                                 # a foot ring
            u = (x + 0.5 - cx) / 4.4
            if abs(u) <= 1.0:
                c.put(x, bot + 1, shade(metal, 0.5 + 0.5 * max(0.0, -0.5 * u + 0.6)))
    save(name, c)
    record(name, "door", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ shoe trays
def shoe_tray(save, name, seed, kind='shoes'):
    """A rubber boot tray by the door: a shallow moulded tray — a thick front lip (lit top edge, shaded face), a raised back wall, a ribbed floor with drain slots and a smear of wet —
    so the shoes in it sit INSIDE something. (The shoes are the corridor's own: corridor_props.shoe_pair / shoe_back_pair / welly.)"""
    import corridor_props as base
    rng = random.Random(seed)
    w, d = 38, 6
    tall = 12 if kind == 'boots' else 7
    h = tall + d + SHADOW + 2
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    rubber = hexc('2a2a30')
    rt = tones(rubber, 5, 0.62, 1.50)
    ground(c, 1, w - 2, C - d, C, 90)
    x0, x1 = 1, w - 2
    # the floor of the tray, seen from above: ribs running along it, darker at the back
    for r in range(1, d):
        y = C - d + r
        c.hline(x0 + 1, x1 - 1, y, rt[1] if r % 2 else rt[2])
    for x in range(6, w - 5, 5):                                    # drain slots
        c.hline(x, x + 2, C - 2, rt[0])
    for x in range(x0 + 3, x1 - 3, 7):                              # a smear of damp that has caught the light
        c.hline(x, x + 3, C - d + 3, shade(rubber, 1.25))
    # back wall (raised, its top edge lit), the two end walls, the front lip with its face
    c.hline(x0, x1, C - d, rt[4]); c.hline(x0, x1, C - d + 1, rt[2])
    c.vline(x0, C - d, C, rt[4]); c.vline(x0 + 1, C - d + 1, C - 1, rt[3])
    c.vline(x1, C - d, C, rt[1]); c.vline(x1 - 1, C - d + 1, C - 1, rt[0])
    c.hline(x0, x1, C - 1, rt[3])                                    # the front lip's lit top
    c.hline(x0, x1, C, rt[1])                                        # … and its face
    cols = ['ffffff', '2a4a8a', '8a5a3a', 'c8c0b0', 'd83a3a', '3a7a4a']
    bas = C - 1
    if kind == 'boots':
        col = hexc(rng.choice(['2a5a2a', '2a2a30', 'a83030', 'e0c030']))
        base.welly(c, 4, bas - 3, shade(col, 0.85))
        base.welly(c, 13, bas, col)
        base.shoe_side(c, 24, bas - 1, 'kid', hexc('e05a8a'), 1)
        base.shoe_side(c, 24, bas - 4, 'kid', hexc('e05a8a'), 1, 0.8)
    elif kind == 'family':
        base.shoe_pair(c, 3, bas, 'trainer', hexc(rng.choice(cols)), 1, depth_up=2)
        base.shoe_back_pair(c, 20, bas, 'brogue', hexc('5a3322'), depth_up=2)
        base.shoe_side(c, 28, bas - 1, 'kid', hexc('e05a8a'), 1)
    else:
        base.shoe_pair(c, 3, bas, 'trainer', hexc(rng.choice(cols)), 1, depth_up=2)
        base.shoe_back_pair(c, 22, bas, 'heel', hexc(rng.choice(cols[3:])), depth_up=2)
    c.hline(x0, x1, C - 1, rt[3])                                    # the front lip drawn over the shoes' soles
    c.hline(x0, x1, C, rt[1])
    save(name, c)
    record(name, "door", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ plants
def leaf(c, x, y, ang, L, W, col, droop=0.0, rib=True, band=None, edge=None, n=5, lo=0.46, hi=1.22):
    """One leaf, drawn as a shaded lanceolate blade: it starts at (x, y), points along `ang` (radians, 0 = right, -pi/2 = up), is `L` long and `W` wide at its fullest, and sags by
    `droop` (the tip falls that fraction of L under its own weight). The half facing the light (upper left) is lit, the other half and the underside darker; a lighter midrib runs along it;
    `band` = (period, darker factor) stripes it across; `edge` = a colour for its outer rim (a snake plant's yellow)."""
    tn = tones(col, n, lo, hi)
    steps = max(6, int(L * 2.2))
    for i in range(steps + 1):
        t = i / float(steps)
        px = x + math.cos(ang) * L * t
        py = y + math.sin(ang) * L * t + droop * L * t * t
        dx = math.cos(ang) * L
        dy = math.sin(ang) * L + 2.0 * droop * L * t
        m = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / m, dx / m
        if nx * LX + ny * LY < 0.0:
            nx, ny = -nx, -ny
        hw = 0.5 * W * max(0.0, math.sin(math.pi * min(1.0, t ** 0.8))) ** 0.85
        hw = max(hw, 0.0)
        k = 0.0
        while k <= hw + 0.01:
            for sgn in ((1, -1) if k > 0 else (1,)):
                sx = k * sgn
                side = sx / max(hw, 0.4)
                lam = 0.46 + 0.40 * side
                col_px = pick(tn, lam)
                if rib and abs(sx) < 0.5:
                    col_px = tn[min(len(tn) - 1, int(lam * len(tn)) + 1)]
                if band is not None and int(t * L / band[0]) % 2 == 1:
                    col_px = shade(col_px, band[1])
                if edge is not None and abs(side) > 0.78 and 0.08 < t < 0.92:
                    col_px = edge if side > 0 else shade(edge, 0.7)
                c.put(int(math.floor(px + nx * sx)), int(math.floor(py + ny * sx)), col_px)
            k += 0.5


def soil_top(c, cx, cy, rx, ry, seed, col=None):
    """The soil in a pot, seen from above: a dark lumpy ellipse lit toward its upper left, with a few pebbles and a crumb of lighter earth."""
    rng = random.Random(seed)
    col = col or hexc('3a281c')
    tn = tones(col, 5, 0.55, 1.45)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if u * u + v * v <= 1.0:
                c.put(x, y, pick(tn, 0.35 + 0.30 * (-u * 0.7 - v * 0.5) + 0.10 * rng.random()))
    for _ in range(int(rx * 0.9)):
        x, y = int(cx + rng.uniform(-rx * 0.7, rx * 0.7)), int(cy + rng.uniform(-ry * 0.6, ry * 0.6))
        c.put(x, y, tn[4]); c.put(x + 1, y, tn[1])


def planter_pot(c, cx, top, bot, rx, ry, pot, seed, mouth=True):
    """The big floor planter: a slightly tapering pot lit by its own roundness, a heavy rolled rim with a lit lip, a shadowed foot band, and the soil in its mouth."""
    propkit.frustum(c, cx, top, bot, rx, rx - 1.2, pot, ry_t=ry, ry_b=ry - 0.6, rim=shade(pot, 1.30), n=6, lo=0.42, hi=1.32, gloss=False)
    for x in range(int(cx - rx) - 1, int(cx + rx) + 1):                       # the rolled rim: a band under the lip, lit on the left
        u = (x + 0.5 - cx) / rx
        if abs(u) <= 1.0:
            lam = 0.30 + 0.62 * max(0.0, -0.7 * u + 0.5)
            tn = tones(pot, 5, 0.50, 1.40)
            c.put(x, top + 1, pick(tn, lam)); c.put(x, top + 2, shade(pick(tn, lam), 0.8))
    if mouth:
        soil_top(c, cx, top, rx - 1.2, ry - 0.7, seed)


def tall_plant(save, name, seed, dead=False):
    """A tall indoor plant in the hotel's floor planter (a rubber plant): a trunk, five branches, and leaves drawn one by one — oval, shaded, ribbed, the back ones darker. The dead one has the
    same bones with a few limp, browned leaves, bare branches and leaves on the floor."""
    rng = random.Random(seed)
    w, d = 24, 8
    h = 44 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    pot = hexc('3c3c42') if seed % 2 == 0 else hexc('b0603e')
    if seed in (50, 51):                                                    # (kept: the old rule, the planter's colour by seed parity)
        pot = hexc('a8573a') if seed % 2 else hexc('3a3a3e')
    ground(c, 3, 20, C - d, C)
    ry = 4
    top, bot = C - 16, C - ry
    # plant first (the pot's rim goes in front of its stem)
    soil_y = top
    stem = hexc('6a4a2a') if not dead else hexc('5a4a34')
    tips = [(12, soil_y - 28), (6, soil_y - 20), (18, soil_y - 22), (4, soil_y - 11), (20, soil_y - 12)]
    rod(c, (12.0, soil_y), (12.0, soil_y - 16), 1.3, 0.9, stem)
    for (tx, ty) in tips:
        rod(c, (12.0, soil_y - 4.0), (float(tx), float(ty)), 0.9, 0.5, stem)
    base_col = [hexc('2a5a2a'), hexc('34702e'), hexc('3e7e34')] if not dead else [hexc('8a7a3a'), hexc('6a5a2e'), hexc('a08a44')]
    leaves = []
    for (tx, ty) in tips:
        a0 = math.atan2(ty - (soil_y - 4), tx - 12)
        count = 7 if not dead else 2
        for k in range(count):
            f = 0.35 + 0.65 * (k / float(max(1, count - 1)))
            ax, ay = 12 + (tx - 12) * f, (soil_y - 4) + (ty - (soil_y - 4)) * f
            ang = a0 + rng.uniform(-1.1, 1.1) + (math.pi if rng.random() < 0.3 else 0.0)
            leaves.append((ay + rng.uniform(-1, 1), ax, ay, ang))
    leaves.sort()
    for (_, ax, ay, ang) in leaves:
        L = rng.uniform(6.5, 9.0) if not dead else rng.uniform(5.0, 7.0)
        W = rng.uniform(3.8, 5.0) if not dead else rng.uniform(2.6, 3.6)
        depth_f = 0.72 + 0.28 * ((ay - (soil_y - 30)) / 30.0)             # higher = further back = darker
        col = shade(rng.choice(base_col), max(0.6, min(1.0, depth_f)))
        leaf(c, ax, ay, ang, L, W, col, droop=0.35 if not dead else 1.1)
    if dead:                                                                # bare twigs standing out
        for (tx, ty) in tips[:3]:
            rod(c, (float(tx), float(ty)), (tx + rng.uniform(-3, 3), ty - rng.uniform(4, 7)), 0.55, 0.3, shade(stem, 0.8), n=4)
    planter_pot(c, 12.0, top, bot, 8.0, ry, pot, seed)
    if dead:                                                                # dropped leaves, each a tiny shaded blade on the floor
        for k in range(6):
            x = rng.randrange(4, 20)
            leaf(c, x, C + rng.randrange(-1, 1) + 0.5, rng.uniform(-0.3, 0.3), rng.uniform(3, 4), 2.0, hexc('7a6a3a'), rib=False)
    save(name, c)
    record(name, "open", d, C)


def planter_fallen(save, name, seed):
    """The planter knocked onto its side: a pot lying on the floor (lit on top, dark underneath, its mouth a dark ellipse with a lit lip), soil fanned out of it in lumpy mounds, and the
    plant lying along the floor — its stems and a few leaves."""
    rng = random.Random(seed)
    w, d = 34, 12
    h = 12 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    pot = hexc('3a3a3e') if seed % 2 == 0 else hexc('a8573a')
    ground(c, 1, w - 2, C - d, C, 90)
    # soil first: lumpy mounds spilling right from the mouth
    for (sx, sy, r) in ((22, C - 2, 3.4), (26, C - 1, 3.0), (30, C, 2.2), (24, C - 5, 2.4), (28, C - 3, 2.0)):
        propkit.sphere(c, sx, sy, r + 0.8, r * 0.7 + 0.5, hexc('3a281c'), n=5, lo=0.5, hi=1.5)
    soil_top(c, 25, C - 1, 5, 1.5, seed)
    # the plant on the floor: stems in a fan and leaves with their own shading
    stem = hexc('5a4a2a')
    for (ex, ey) in ((30, C - 6), (32, C - 3), (29, C - 8)):
        rod(c, (21.0, C - 5.0), (float(ex), float(ey)), 0.8, 0.45, stem, n=4)
    for k in range(6):
        leaf(c, 24 + k * 1.3, C - 5 + rng.uniform(-1, 1), rng.uniform(-0.8, 0.5), rng.uniform(5, 7), 3.2, rng.choice([hexc('2a5a2a'), hexc('34702e'), hexc('3e7e34')]), droop=0.5)
    # the pot, a horizontal cylinder: lit along its top, dark under, the rolled rim at the left end, the open mouth to the right
    px0, px1, cy, r = 3.0, 19.0, C - 6.0, 6.0
    tn = tones(pot, 6, 0.40, 1.32)
    for x in range(int(px0), int(px1) + 1):
        rr = 4.6 + (r - 4.6) * (x - px0) / (px1 - px0)                      # the pot widens toward its mouth
        for y in range(int(cy - rr) - 1, int(cy + rr) + 1):
            v = (y + 0.5 - cy) / rr
            if abs(v) > 1.0:
                continue
            nz = math.sqrt(1.0 - v * v)
            lam = 0.12 + 0.82 * max(0.0, 0.7 * (-v) + 0.36 * nz + 0.12)
            c.put(x, y, pick(tn, lam))
    c.vline(int(px0), int(cy - 3.6), int(cy + 3.6), tn[2]); c.vline(int(px0) + 1, int(cy - 3.8), int(cy + 3.8), tn[3])
    propkit.sphere(c, px1, cy, 2.6, r, shade(pot, 1.0), n=5, lo=0.5, hi=1.35)                    # the mouth's rim ring, an upright ellipse
    for y in range(int(cy - r + 1.2), int(cy + r - 1.2)):
        for x in range(int(px1 - 1.6), int(px1 + 1.8)):
            if ((x + 0.5 - (px1 + 0.2)) / 1.7) ** 2 + ((y + 0.5 - cy) / (r - 1.2)) ** 2 <= 1.0:
                c.put(x, y, hexc('1e140e'))
    c.put(int(px1 - 1), int(cy - r + 1), tn[5])
    save(name, c)
    record(name, "open", d, C)


def snake_plant(save, name, seed, dead=False):
    """A snake plant in a pot: upright sword leaves, each a shaded blade with a yellow rim and darker cross-bands (a tiger pattern); the dead one has yellowed blades, several folded
    over at the middle and hanging down the pot."""
    rng = random.Random(seed)
    w, d = 22, 8
    h = 40 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    pot = rng.choice([hexc('e4e0d8'), hexc('3a3a3e'), hexc('7a8a8a')])
    ground(c, 3, 18, C - d, C)
    top, bot = C - 14, C - 3
    order = list(range(9))
    rng.shuffle(order)
    leaves = []
    for k in order:
        x = 4.0 + k * 1.7 + rng.uniform(-0.6, 0.6)
        tall = rng.uniform(14, 28) if not dead else rng.uniform(7, 15)
        lean = (x - 11.0) / 11.0 * 0.45 + rng.uniform(-0.1, 0.1)
        leaves.append((tall, x, lean))
    leaves.sort(key=lambda q: -q[0])
    green = hexc('2a5e2c') if not dead else hexc('8a7a38')
    for (tall, x, lean) in leaves:
        ang = -math.pi / 2.0 + lean
        col = shade(green, 0.75 + 0.25 * (tall / 28.0))
        if dead and tall > 10:
            L1 = tall * 0.55
            leaf(c, x, top + 1, ang, L1, 3.4, col, edge=hexc('b8a050'), band=(3.0, 0.78))
            ex, ey = x + math.cos(ang) * L1, top + 1 + math.sin(ang) * L1
            leaf(c, ex, ey, math.pi / 2.0 - 0.6 * (1 if lean < 0 else -1), tall * 0.5, 3.0, shade(col, 0.82), droop=0.0, edge=hexc('9a8a44'), band=(3.0, 0.78))
        else:
            leaf(c, x, top + 1, ang, tall, 3.6 if not dead else 3.0, col, edge=(hexc('d0cc5a') if not dead else hexc('b8a050')), band=(3.0, 0.78))
    propkit.frustum(c, 11.0, top, bot, 7.0, 5.6, pot, ry_t=2.6, ry_b=2.2, rim=shade(pot, 1.25), n=6, lo=0.42, hi=1.25, gloss=True)
    soil_top(c, 11.0, top, 5.8, 1.9, seed)
    for k in range(4):                                                      # a few blades in front of the rim, so the plant rises OUT of the pot
        x = 7.0 + k * 2.4
        leaf(c, x, top + 1, -math.pi / 2.0 + (x - 11) * 0.06, rng.uniform(6, 9) if not dead else rng.uniform(3, 5), 3.2, shade(green, 0.95), edge=hexc('d0cc5a') if not dead else None, band=(3.0, 0.8))
    save(name, c)
    record(name, "open", d, C)


def palm(save, name, seed):
    """A parlour palm in a pot: a short trunk and nine arching fronds, each an arc of rachis with paired leaflets down both sides (shaded blades, the upper ones lit), the front fronds
    brighter than the back."""
    rng = random.Random(seed)
    w, d = 30, 8
    h = 42 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    pot = rng.choice([hexc('a8573a'), hexc('3a3a3e'), hexc('b8a888')])
    ground(c, 6, 23, C - d, C)
    top, bot = C - 13, C - 3
    cx = 15.0
    rod(c, (cx, top), (cx, top - 8), 1.5, 1.1, hexc('6a5230'))
    for i in range(8):
        ang = math.radians(-172 + i * 23.5)
        ln = rng.uniform(14, 19)
        f = 0.60 + 0.40 * (i % 3) / 2.0                                       # alternate fronds sit back and darker
        col = shade(rng.choice([hexc('3a7a34'), hexc('2e6a2c'), hexc('468a3c')]), f)
        pts = []
        for t in range(0, 15):
            tt = t / 14.0
            pts.append((cx + math.cos(ang) * ln * tt, top - 8 + math.sin(ang) * ln * tt + 8.0 * tt * tt))
        for (a_, b_) in zip(pts, pts[1:]):
            rod(c, a_, b_, 0.5, 0.45, shade(hexc('4a6a2e'), f), n=4, cap0=False, cap1=False)
        for j, (px, py) in enumerate(pts[3:], start=3):
            if j % 2:
                continue
            ll = 5.4 - 0.25 * j
            for sgn in (-1, 1):
                la = ang + sgn * (math.pi / 2.0 - 0.8)
                leaf(c, px, py, la, max(2.2, ll), 1.5, col, droop=0.7, rib=False)
    propkit.frustum(c, cx, top, bot, 8.0, 6.0, pot, ry_t=3.0, ry_b=2.4, rim=shade(pot, 1.3), n=6, lo=0.42, hi=1.3)
    soil_top(c, cx, top, 6.8, 2.3, seed)
    save(name, c)
    record(name, "open", d, C)


def _stand(c, ty, wood, shadow_legs=True):
    """The little round plant table: a thick round top lit across (a rim of its own), three turned legs spreading to the floor — one set back — and a ring stretcher."""
    C = c.h - 1 - SHADOW
    d = 7
    rod(c, (9.5, ty + 3), (9.5, C - d + 1), 0.9, 0.7, shade(wood, 0.65), n=4)           # the back leg
    rod(c, (5.0, ty + 3), (3.2, C), 1.1, 0.8, wood, bulge=0.2)
    rod(c, (13.8, ty + 3), (15.8, C), 1.1, 0.8, shade(wood, 0.85), bulge=0.2)
    c.hline(4, 14, C - 9, shade(wood, 0.62)); c.hline(4, 14, C - 10, shade(wood, 1.0))   # the ring stretcher
    propkit.cyl(c, 9.0, ty, ty + 2, 7.0, wood, ry=3.0, n=6, lo=0.45, hi=1.35)


def plant_stand(save, name, seed):
    """A small plant on a tall three-legged stand: the round top with real thickness, turned legs, a glazed pot and a little rosette of shaded leaves with a trailing vine over the edge."""
    rng = random.Random(seed)
    w, d = 18, 7
    h = 40 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    wood = hexc('5a3a26')
    ground(c, 3, 14, C - d, C, 80)
    ty = C - 24
    _stand(c, ty, wood)
    potc = rng.choice([hexc('d8d0c0'), hexc('c07050'), hexc('3a6a7a')])
    for (ax, ay) in ((9.0, ty - 9.0),):
        for k in range(12):
            ang = -math.pi / 2.0 + rng.uniform(-1.3, 1.3)
            leaf(c, 9.0, ty - 6.0, ang, rng.uniform(5, 8.5), rng.uniform(3, 4), rng.choice([hexc('2e6a2e'), hexc('3e7e34'), hexc('4a8c3c')]), droop=0.45)
    propkit.frustum(c, 9.0, ty - 8, ty - 1, 4.2, 3.2, potc, ry_t=1.6, ry_b=1.3, inner=hexc('3a2a1e'), rim=shade(potc, 1.3), n=6, lo=0.45, hi=1.3)
    for (x, y) in ((5.5, ty - 5.0), (13.0, ty - 4.0)):                       # a vine trailing over the edge: a stem and a few leaves going down
        rod(c, (x, y), (x - 0.4, y + 6.0), 0.5, 0.4, hexc('3e6a30'), n=4)
        for k in range(3):
            leaf(c, x - 0.2, y + 1.5 + k * 2.0, math.pi / 2.0 + (0.9 if k % 2 else -0.9), 3.0, 2.0, hexc('4a8c3c'), rib=False)
    save(name, c)
    record(name, "open", d, C)


def plant_stand_fallen(save, name, seed):
    """The plant on its stand, KNOCKED OVER: the stand still up and empty (a ring of soil on its top), the pot on its side on the floor in front — cracked, a shard lying by it — a
    trail of soil crumbs between them, and the plant dead on the floor."""
    rng = random.Random(seed)
    w, d = 34, 11
    h = 40 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    wood = hexc('5a3a26')
    ground(c, 2, w - 2, C - d, C, 85)
    ty = C - 24
    _stand(c, ty, wood)
    soil_top(c, 9.0, ty - 0.5, 4.2, 1.2, seed)
    # the trail of soil: lumpy crumbs from the stand's foot to the pot, each a tiny shaded lump
    for k in range(18):
        t = rng.random()
        x = 10 + t * 13 + rng.uniform(-1.2, 1.2)
        y = C - 2 - t * 3 + rng.uniform(-1.0, 1.0)
        propkit.sphere(c, x, y, rng.uniform(0.9, 1.5), rng.uniform(0.6, 1.0), hexc('3a281c'), n=4, lo=0.55, hi=1.5)
    # the dead plant lying on the floor
    for k in range(6):
        leaf(c, 15 + rng.uniform(0, 5), C - 3 + rng.uniform(-2, 1), rng.uniform(-0.9, 0.9), rng.uniform(4, 6), 2.6, rng.choice([hexc('7a6a3a'), hexc('8a7a44'), hexc('5a4a2a')]), droop=0.5, rib=False)
    # the pot on its side: a lit horizontal cylinder, its mouth toward the stand, a crack and a shard
    potc = hexc('c07050')
    px0, px1, cy, r = 22.0, 30.0, C - 4.0, 3.6
    tn = tones(potc, 6, 0.42, 1.34)
    for y in range(int(cy - r) - 1, int(cy + r) + 1):
        v = (y + 0.5 - cy) / r
        if abs(v) > 1.0:
            continue
        nz = math.sqrt(1.0 - v * v)
        lam = 0.12 + 0.82 * max(0.0, 0.7 * (-v) + 0.36 * nz + 0.12)
        for x in range(int(px0), int(px1) + 1):
            c.put(x, y, pick(tn, lam))
    for y in range(int(cy - r + 0.8), int(cy + r - 0.8)):
        for x in range(int(px0 - 1.4), int(px0 + 1.6)):
            if ((x + 0.5 - (px0 + 0.1)) / 1.5) ** 2 + ((y + 0.5 - cy) / (r - 0.8)) ** 2 <= 1.0:
                c.put(x, y, hexc('2a1e16'))
    c.line(26, int(cy - r), 28, int(cy), shade(potc, 0.38)); c.line(28, int(cy), 27, int(cy + r), shade(potc, 0.38))
    c.poly([(31, C - 1), (33, C - 1), (32, C - 3)], tn[3])
    c.line(31, C - 1, 33, C - 1, tn[1])
    save(name, c)
    record(name, "open", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ recycling crate
def recycling_box(save, name, seed, cardboard=False):
    """The recycling crate by the door: a moulded plastic crate (a lit rim, a ribbed front with recessed slots, a handle grip and a label) and what is standing in it, seen over the rim —
    bottles (glass bodies with a lit stripe, necks and caps), cans (rims and a label band), or flattened cardboard stood on edge, its corrugated edge showing."""
    rng = random.Random(seed)
    w, d = 26, 8
    h = 16 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    col = hexc('2a7a3a') if not cardboard else hexc('2a4a8a')
    ground(c, 1, w - 2, C - d, C)
    x0, x1, yt, yb, dd, s = 2, 21, C - 8, C, 7, 2
    b = box3d(c, x0, x1, yt, yb, dd, col, s=s, lo=0.44, hi=1.30, top_col=shade(col, 0.30))      # the top face is the dark inside of the crate
    tn = b['tn']
    # what is in it, standing on the inside floor (back to front), then the crate's front wall over its lower part
    inside_y = yt - 2
    if cardboard:
        card = hexc('b88e5c')
        for k, (px, lean, hgt) in enumerate(((5, -1, 14), (10, 0, 13), (15, 1, 14))):
            box3d(c, px, px + 6, inside_y - hgt, inside_y, 2, shade(card, 1.0 - 0.07 * k), s=1, lo=0.5, hi=1.2)
            for yy in range(inside_y - hgt + 2, inside_y, 3):
                c.put(px + 6, yy, shade(card, 1.25))                          # the corrugated edge, a lit dash every few rows
        c.rect(7, inside_y - 7, 11, inside_y - 4, hexc('d8d0b8'))             # a printed tag on the middle board
        c.hline(7, 11, inside_y - 7, hexc('f4f0e0'))
        for k in range(2):                                                     # two cans leaning in front
            propkit.cyl(c, 18.0 + k * 2.4, yt - 5 + k, yt - 1 + k, 1.7, hexc('c8ccd0'), ry=0.8, n=5, lo=0.5, hi=1.25, inner=hexc('3a3e46'))
    else:
        cols = [hexc('3a6a3a'), hexc('6a4a2a'), hexc('b8c8c8'), hexc('c83a2a'), hexc('d8d0b8'), hexc('3a6a3a')]
        for k in range(6):
            bx = 4.0 + k * 3.0 + rng.uniform(-0.4, 0.4)
            back = inside_y - (k % 2) * 2                                       # alternate rows stand a little further back
            tall = rng.randrange(6, 9)
            bc = cols[k]
            propkit.cyl(c, bx, back - tall, back, 1.5, bc, ry=0.8, n=5, lo=0.45, hi=1.35, gloss=True, spec=shade(bc, 1.8))
            propkit.cyl(c, bx, back - tall - 3, back - tall, 0.8, bc, ry=0.5, n=4, lo=0.5, hi=1.3)     # the neck
            c.put(int(bx), back - tall - 4, shade(hexc('c8a050'), 1.0))                              # its cap
    # the crate's front wall: lit rim, recessed slots with a lit lower lip, a hand grip, a label
    c.hline(x0, x1 + s, yt, tn[4]); c.hline(x0, x1, yt + 1, tn[3])
    for sx in range(x0 + 3, x1 - 2, 4):
        c.rect(sx, yt + 3, sx + 1, yb - 3, tn[0])                               # a slot cut into the face
        c.hline(sx, sx + 1, yb - 2, tn[4])                                      # its lit lower lip
        c.put(sx + 2, yt + 3, tn[3])
    gx = (x0 + x1) // 2
    c.rect(gx - 3, yt + 2, gx + 3, yt + 3, tn[0]); c.hline(gx - 3, gx + 3, yt + 4, tn[4])   # the hand grip: a recess with a lit lip under it
    c.rect(gx - 3, yb - 3, gx + 2, yb - 2, hexc('e8e8e0'))                      # the council's label
    c.hline(gx - 3, gx + 2, yb - 3, hexc('ffffff'))
    save(name, c)
    record(name, "door", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ hall table
def hall_table(save, name, seed, kind='flowers'):
    """A slim console table by the door: a top of real thickness with a lit grained face, a bevelled drawer with a brass knob in its apron, four legs (the near pair square and tapering,
    lit on the left, with a shaded side) and whatever lives on it — flowers in a glass vase with a fan of letters, a lamp with a bowl of keys, or a pot plant with the post."""
    rng = random.Random(seed)
    w, d = 30, 7
    h = 40 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    wood = rng.choice([hexc('5a3a26'), hexc('7a5236'), hexc('3a2a22')])
    ground(c, 1, w - 2, C - d, C, 85)
    ty = C - 20
    x0, x1, dd, s = 1, w - 4, 6, 2
    wt = tones(wood, 5, 0.50, 1.35)
    # back legs, set back and darker
    for bx in (4, x1 - 2):
        rod(c, (bx + 0.5, ty + 3), (bx + 0.5, C - d + 1), 0.8, 0.6, shade(wood, 0.62), n=4)
    # the apron + drawer under the top, then the near legs (square, tapering)
    for y in range(ty + 2, ty + 7):
        c.hline(x0 + 1, x1 - 1, y, wt[2] if y < ty + 6 else wt[1])
    c.hline(x0 + 1, x1 - 1, ty + 2, wt[1])                                       # a shadow line under the top
    c.rect(x0 + 4, ty + 3, x1 - 4, ty + 5, wt[3]); c.hline(x0 + 4, x1 - 4, ty + 3, wt[4]); c.hline(x0 + 4, x1 - 4, ty + 5, wt[1])   # the drawer panel: a lit upper bevel, a shaded lower
    c.vline(x0 + 4, ty + 3, ty + 5, wt[4]); c.vline(x1 - 4, ty + 3, ty + 5, wt[1])
    kx = (x0 + x1) // 2
    c.put(kx, ty + 4, hexc('e0b858')); c.put(kx - 1, ty + 4, hexc('a07828')); c.put(kx, ty + 3, hexc('fff0b0'))
    for lx in (x0 + 1, x1 - 2):
        for y in range(ty + 7, C + 1):
            f = (y - (ty + 7)) / float(max(1, C - ty - 7))
            wdt = 3 if f < 0.35 else 2
            c.hline(lx, lx + wdt - 1, y, wt[3] if True else wt[2])
            c.put(lx, y, wt[4]); c.put(lx + wdt - 1, y, wt[1])
            if wdt == 3:
                c.put(lx + 1, y, wt[2])
        c.hline(lx - 1, lx + 2, C, shade(wt[0], 0.8))                              # the foot's contact
    c.vline(x1 + 1, ty + 7, C - 2, wt[0])                                          # the right near leg's shaded side
    # the top: a thick slab, its front edge (two rows: lit, then shaded), its grained top face
    box3d(c, x0, x1, ty, ty + 1, dd, wood, s=s, lo=0.50, hi=1.35, top_col=wt[3])
    for k in (2, 4):                                                               # wood grain along the top: two long faint lines
        a, b = _top_x(x0 + 1, x1 - 1, k, dd, s)
        c.hline(a + 3, b - 4, ty - k, wt[2])
    # the things on it
    back, front = ty - dd + 2, ty - 1
    if kind == 'flowers':
        vx = x0 + 6
        propkit.frustum(c, float(vx), back - 7, back - 1, 2.2, 1.6, hexc('9ab8c4'), ry_t=1.0, ry_b=0.8, inner=hexc('3a5a5a'), rim=hexc('d4ecf4'), n=5, lo=0.55, hi=1.5, gloss=True)
        for yy in range(back - 4, back - 1):
            c.put(vx - 1, yy, hexc('5a8a9a'))                                       # the water level through the glass
        petals = [hexc('d84a5a'), hexc('e8c84a'), hexc('e8d8e8'), hexc('d84a5a')]
        for k in range(7):
            fx, fy = vx + rng.uniform(-4.5, 4.5), back - 10 - rng.uniform(0, 5)
            rod(c, (vx + 0.5, back - 7.0), (fx, fy), 0.45, 0.35, hexc('3a6a2e'), n=3, cap0=False)
            propkit.sphere(c, fx, fy - 0.5, 1.5, 1.4, petals[k % len(petals)], n=4, lo=0.55, hi=1.45)
            c.put(int(fx), int(fy - 1), shade(petals[k % len(petals)], 1.6))
        for k in range(3):                                                          # letters fanned out in front, each a thin slab with its stamp and address lines
            ex = x1 - 13 + k * 1
            ey = front - 1 - k
            box3d(c, ex, ex + 7, ey - 1, ey, 1, [hexc('eeeae0'), hexc('d8c8a8'), hexc('e8e0f0')][k], s=1, lo=0.7, hi=1.1)
            c.put(ex + 6, ey - 1, hexc('c83a3a'))
            c.hline(ex + 1, ex + 4, ey, shade(hexc('9a9a9a'), 1.0))
    elif kind == 'lamp':
        lx = x0 + 6
        propkit.sphere(c, float(lx), back - 3.0, 2.8, 2.2, hexc('4a5058'), n=5, lo=0.5, hi=1.45, gloss=True)
        rod(c, (lx + 0.5, back - 4.0), (lx + 0.5, back - 11.0), 0.6, 0.5, hexc('b0904a'))
        propkit.frustum(c, float(lx), back - 17, back - 11, 3.4, 4.6, hexc('d8ccb0'), ry_t=1.0, ry_b=1.4, inner=hexc('f0e4c0'), rim=hexc('f4ecd4'), n=5, lo=0.6, hi=1.2)
        propkit.frustum(c, float(x1 - 7), front - 3, front - 1, 3.8, 2.8, hexc('7a6a54'), ry_t=1.2, ry_b=1.0, inner=hexc('2a2218'), rim=hexc('9a8a70'), n=5, lo=0.5, hi=1.4)   # a bowl
        c.put(x1 - 8, front - 3, hexc('e0c040')); c.put(x1 - 6, front - 3, hexc('b8b8bc')); c.put(x1 - 7, front - 4, hexc('d8d8dc'))                                  # keys in it
    else:
        px = x1 - 7
        propkit.frustum(c, float(px), back - 5, back - 1, 3.4, 2.6, hexc('c07050'), ry_t=1.3, ry_b=1.0, inner=hexc('3a2a1e'), rim=hexc('d88a68'), n=5, lo=0.5, hi=1.4)
        for k in range(8):
            leaf(c, px + 0.5, back - 5.0, -math.pi / 2.0 + rng.uniform(-1.2, 1.2), rng.uniform(4.5, 7.5), rng.uniform(2.6, 3.4), rng.choice([hexc('2e6a2e'), hexc('3e7e34'), hexc('4a8c3c')]), droop=0.4)
        for k in range(3):                                                          # the post: a short stack of envelopes with a rubber band
            ex = x0 + 3 + k
            ey = front - 1 - k
            box3d(c, ex, ex + 8, ey - 1, ey, 1, [hexc('eeeae0'), hexc('d8c8a8'), hexc('e8e0f0')][k], s=1, lo=0.7, hi=1.1)
        c.vline(x0 + 7, front - 4, front - 1, hexc('c83a3a'))
    save(name, c)
    record(name, "door", d, C)


# ------------------------------------------------------------------------------------------------------------------------------------ shoe rack
def _rack_frame3d(c, x0, x1, C, d, tiers, metal):
    """Slatted shelves seen from a little above: every slat is a board with a lit top and a shaded front edge, the gaps between them dark, a soft shadow under each shelf, and back posts
    in shade. (Metal: a chrome rail front and back with wire rods between, lit on top.)"""
    wood = hexc('8a5f3c') if not metal else hexc('a9b0b8')
    wt = tones(wood, 5, 0.42, 1.30)
    top_y = tiers[-1] - d
    for x in (x0 + 1, x1 - 1):
        c.vline(x, top_y, C - d, wt[0])
        c.vline(x + 1, top_y, C - d, wt[1])
    for y in tiers:
        if metal:
            c.hline(x0, x1, y - d, wt[1]); c.hline(x0, x1, y - d + 1, wt[2])
            for x in range(x0 + 3, x1 - 1, 4):
                c.line(x, y - d + 2, x, y - 2, wt[3] if x % 8 == 3 else wt[2])
            c.hline(x0, x1, y - 1, wt[4]); c.hline(x0, x1, y, wt[3]); c.hline(x0, x1, y + 1, wt[1])
        else:
            for r in range(d):
                yy = y - d + r
                if r % 3 == 2:
                    c.hline(x0 + 1, x1 - 1, yy, wt[0])                       # the gap between slats: dark
                else:
                    c.hline(x0 + 1, x1 - 1, yy, wt[3] if r % 3 == 0 else wt[2])
            c.hline(x0, x1, y, wt[4])                                        # the front slat's lit top edge
            c.hline(x0, x1, y + 1, wt[2]); c.hline(x0, x1, y + 2, wt[1])      # its front face, shading down
        for r in range(3, 5):                                                # a shadow cast onto whatever is below
            c.hline(x0 + 2, x1 - 2, y + r, (14, 10, 8, 80 if r == 3 else 46))
    return wood


def _rack_posts3d(c, x0, x1, C, d, tiers, wood, metal):
    top_y = tiers[-1] - d
    wt = tones(wood, 5, 0.42, 1.30)
    if metal:
        for x in (x0, x1):
            for y in range(top_y - 1, C + 1):
                c.put(x, y, wt[4]); c.put(x + 1 if x == x0 else x - 1, y, wt[1])
            propkit.sphere(c, x + 0.5, top_y - 2.0, 1.4, 1.4, wood, n=4, lo=0.6, hi=1.5)
    else:
        for x in (x0, x1 - 1):                                               # the two side boards: a lit face, a shaded edge, a lit top cap
            for y in range(top_y - 1, C + 1):
                c.put(x, y, wt[4] if (y - top_y) % 11 else wt[3]); c.put(x + 1, y, wt[1])
            c.hline(x, x + 1, top_y - 1, wt[4])
            c.hline(x, x + 1, top_y - 2, wt[3])


def shoe_rack(save, name, seed, metal=False, sprawled=False):
    """A three-tier shoe rack by the door, shoes in pairs — some side-on, some heels-out — on a frame with real depth: slatted shelves with a lit top and shaded edge, a shadow cast
    onto the shelf below, posts / side boards with their own faces. (Sprawled: some kicked off round it.)"""
    import corridor_props as base
    rng = random.Random(seed)
    rack_w, d = 34, 6
    ml, mr = (12, 12) if sprawled else (0, 0)
    w = ml + rack_w + mr
    tiers_rel = (2, 12, 22)
    h = tiers_rel[-1] + d + 10 + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    x0, x1 = ml + 1, ml + rack_w - 2
    tiers = [C - t for t in tiers_rel]
    if sprawled:
        ground(c, 1, w - 2, C - 5, C, 50)
    ground(c, x0, x1, C - d, C)
    wood = _rack_frame3d(c, x0, x1, C, d, tiers, metal)
    pool = base.RACK_SHOES[:]
    rng.shuffle(pool)
    backs = [rng.random() < 0.45 for _ in range(4)]
    if all(backs) or not any(backs):
        backs[rng.randrange(4)] = not backs[0]
    for ti, y in enumerate(tiers[:2]):
        for slot in range(2):
            if sprawled and (ti, slot) in ((0, 1), (1, 0)):
                continue
            style, col = pool.pop()
            if backs[ti * 2 + slot]:
                base.shoe_back_pair(c, x0 + 3 + slot * 15, y - 1, style, hexc(col))
            else:
                base.shoe_pair(c, x0 + 3 + slot * 15, y - 1, style, hexc(col), 1, depth_up=3)
    if metal:
        base.shoe_back_pair(c, x0 + 5, tiers[2] - 1, 'boot', hexc('4a3526'))
    else:
        base.shoe_pair(c, x0 + 3, tiers[2] - 1, 'kid', hexc('6a8ac8'), 1, depth_up=3)
        propkit.frustum(c, float(x1 - 7), tiers[2] - 3, tiers[2] - 1, 3.8, 3.0, hexc('c8b89a'), ry_t=1.2, ry_b=1.0, inner=hexc('4a3e30'), rim=hexc('e0d4b8'), n=5, lo=0.55, hi=1.35)    # a key dish
        c.put(x1 - 8, tiers[2] - 3, hexc('d8d8d0')); c.put(x1 - 6, tiers[2] - 3, hexc('c8a84a'))
    _rack_posts3d(c, x0, x1, C, d, tiers, wood, metal)
    if sprawled:
        base.lying_shoe(c, 0, C - 7, 'trainer', hexc('d0603c'), 'side')
        base.shoe_back(c, 6, C - 1, 'heel', hexc('d23a3a'))
        base.lying_shoe(c, x0 + 10, C - 3, 'trainer', hexc('2a4a8a'), 'side')
        base.shoe_side(c, w - 3, C - 5, 'trainer', hexc('ffffff'), -1, 0.9)
        base.lying_shoe(c, w - 12, C - 3, 'brogue', hexc('1e1a18'), 'side')
        base.lying_shoe(c, x0 + 3, tiers[1] - 5, 'trainer', hexc('3a3a3e'), 'sole')
    save(name, c)
    record(name, "door", d, C)
