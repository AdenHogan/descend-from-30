#!/usr/bin/env python3
"""THE OPENING'S BIRDS (owner round 49: "the birds on the telephone wire… are static and could actually fly away with flapping wings, as
if disturbed. The birds at the top just sort of float, and don't flap their wings").

One sheet, `assets/opening/birds.png`, drawn pixel by pixel (every point an integer, no anti-aliasing — the old sky birds were vector
lines over a pixel picture). Two rows:

    row 0  NEAR crows (14 x 12), facing right:  perched · crouch (about to go) · wings up · wings raised · wings level · wings down · glide
    row 1  FAR birds (9 x 6), facing right:     wings up · level · down · glide

The game flips them for a leftward bird and plays the flap cycle  up → raised → level → down → level…  at the rate a crow beats its wings.
`meta['birds']` lists every cell, so the game never hard-codes the sheet's layout.
"""
import math
import random

from PIL import Image, ImageDraw

from pixlib import Canvas, hexc

BODY = hexc('1b1b22')
SHADE = hexc('0f0f14')
HI = hexc('3d3d4b')
BEAK = hexc('2a2a31')
NEAR_W, NEAR_H = 14, 12
FAR_K = 0.72                                                   # the sky birds are the crows drawn smaller, not a different bird
FAR_W, FAR_H = 10, 9
NEAR = ['perched', 'crouch', 'up', 'raised', 'level', 'down', 'glide']
FAR = ['up', 'level', 'down', 'glide']


def _blade(c, x0, y0, x1, y1, w0, w1, col, notch=True):
    """A wing: a tapered blade from the shoulder (x0, y0) to the tip (x1, y1), with the tip split into primaries."""
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        t = i / float(n)
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        w = w0 + (w1 - w0) * t
        # the blade is thickest across its short axis: thicken in whichever direction the line is flatter
        if abs(x1 - x0) >= abs(y1 - y0):
            for k in range(int(round(w))):
                c.put(int(round(x)), int(round(y)) + k - int(w // 2), col)
        else:
            for k in range(int(round(w))):
                c.put(int(round(x)) + k - int(w // 2), int(round(y)), col)
    if notch:                                                    # primaries: three short feathers fanning off the tip
        dx = 1 if x1 >= x0 else -1
        dy = 1 if y1 >= y0 else -1
        c.put(int(round(x1)) + dx, int(round(y1)), col)
        c.put(int(round(x1)), int(round(y1)) + dy, col)


def _near(name):
    c = Canvas(NEAR_W, NEAR_H, seed=3)
    if name in ('perched', 'crouch'):
        low = 1 if name == 'crouch' else 0
        c.poly([(4, 6 + low), (0, 9 + low), (1, 10 + low), (5, 8 + low)], SHADE)           # the tail, down and back
        c.ellipse(8, 7 + low, 4.2, 2.7 if not low else 2.2, BODY)                           # the body
        c.ellipse(12, 5 + low, 1.9, 1.7, BODY)                                              # the head
        c.poly([(13, 5 + low), (15, 5 + low), (13, 6 + low)], BEAK)                         # the beak
        c.hline(5, 9, 5 + low, HI)                                                          # a sheen along the back
        c.line(5, 7 + low, 10, 8 + low, SHADE)                                              # the folded wing's edge
        if name == 'perched':
            c.put(8, 10, SHADE)
            c.put(10, 10, SHADE)
            c.put(8, 11, SHADE)
            c.put(10, 11, SHADE)
        else:                                                                               # about to go: the wings lift off the back
            c.poly([(5, 6), (10, 4), (9, 3), (6, 4)], BODY)
            c.line(6, 4, 9, 3, HI)
            c.put(10, 11, SHADE)
            c.put(8, 11, SHADE)
        return c.img
    return _flight(name, 1.0)


def _flight(name, k):
    """A crow in flight at scale k (1.0 = the near crow's 14 x 12): a long level body, head forward, a fan of tail behind, and the wings as
    scalloped blades rotated about the shoulder."""
    w, h = int(round(NEAR_W * k)), int(round(NEAR_H * k))
    c = Canvas(w, h, seed=3)
    spec = {                       # (angle of the wing's spine, its visible length, width): the foreshortening is real — level wings are edge-on
        'up': (-122.0, 9.0, 3.2), 'raised': (-72.0, 6.6, 3.0), 'level': (-8.0, 4.4, 3.2), 'down': (58.0, 8.6, 3.2), 'glide': (-38.0, 7.6, 2.8),
    }[name]
    ang, ln, wd = spec
    S = (7.5 * k, 5.5 * k)
    if name != 'level':
        _wing(c, S, ang + 16.0, ln * 0.86 * k, wd * 0.9 * k, SHADE, None)                  # the far wing, behind, a little apart
    c.poly([(3 * k, 5 * k), (0, 5 * k), (0, 8 * k), (3 * k, 7 * k)], SHADE)                  # the tail fan
    c.ellipse(7 * k, 6 * k, 4.0 * k, 2.2 * k, BODY)                                         # the body
    c.ellipse(11 * k, 5 * k, 1.8 * k, 1.6 * k, BODY)                                        # the head
    c.poly([(12 * k, 5 * k), (14 * k, 5 * k), (12 * k, 6 * k)], BEAK)
    if k >= 1.0:
        c.hline(5, 9, 4, HI)
    _wing(c, S, ang, ln * k, wd * k, BODY, HI if k >= 1.0 else None)                        # the near wing over it
    return c.img


def _wing(c, S, ang, ln, wd, col, edge):
    """A wing rotated `ang` degrees about the shoulder S: a broad blade, its leading edge a gentle bulge, its trailing edge scalloped into
    four primaries. Rasterised by pixel centre (no anti-aliasing); `edge` lights the leading edge."""
    import math
    loc = [(0.0, -1.0), (0.45, -1.7), (0.85, -1.3), (1.0, -0.25),                          # root front -> bulge -> tip
           (0.93, 0.35), (0.84, 0.15), (0.77, 0.95), (0.66, 0.55), (0.56, 1.2), (0.44, 0.8), (0.30, 1.1), (0.0, 0.9)]
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    pts = []
    for (u, v) in loc:
        x = u * ln
        y = v * wd * 0.5
        pts.append((S[0] + x * ca - y * sa, S[1] + x * sa + y * ca))

    def inside(px, py):
        n = len(pts)
        ok = False
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi:
                ok = not ok
            j = i
        return ok

    for y in range(c.h):
        for x in range(c.w):
            if inside(x + 0.5, y + 0.5):
                c.put(x, y, col)
    if edge:                                                                                 # the leading edge, a lit line along the first few pixels
        for k in range(1, int(ln * 0.8)):
            u = k / ln
            x = S[0] + (u * ln) * ca - (-1.2 * wd * 0.5) * sa
            y = S[1] + (u * ln) * sa + (-1.2 * wd * 0.5) * ca
            if inside(x + 0.0, y + 0.0):
                c.put(int(x), int(y), edge)


def _far(name):
    return _flight(name, FAR_K)


def draw_birds():
    """-> (the sheet, its meta): {'near': [{name, x, y, w, h}], 'far': [...]}"""
    gap = 1
    w = max(len(NEAR) * (NEAR_W + gap), len(FAR) * (FAR_W + gap))
    sheet = Image.new('RGBA', (w, NEAR_H + FAR_H + 2 * gap), (0, 0, 0, 0))
    meta = {'near': [], 'far': []}
    for i, n in enumerate(NEAR):
        x = i * (NEAR_W + gap)
        sheet.paste(_near(n), (x, 0))
        meta['near'].append({'name': n, 'x': x, 'y': 0, 'w': NEAR_W, 'h': NEAR_H})
    for i, n in enumerate(FAR):
        x = i * (FAR_W + gap)
        sheet.paste(_far(n), (x, NEAR_H + gap))
        meta['far'].append({'name': n, 'x': x, 'y': NEAR_H + gap, 'w': FAR_W, 'h': FAR_H})
    return sheet, meta


# ---------------------------------------------------------------------------------------------------------------------- MONSTERS
# THE NIGHT'S FLIERS (owner round 49c: "instead of those birds we had for the nice day version above the building, we can have flying
# monsters. Just shadow silhouettes, but that would show how bad it has gotten"; then, on the first bat-with-a-horned-head version: "they appear
# more harpy-like, rather they should be not humanish in form. Lovecraftian is the way we want to go. Shadowy and lovecraftian.").
#
# So nothing here has a head, a face, arms, legs or a bat's wing. What is left is what a Lovecraftian thing in a storm sky reads as: a lumpy
# MASS with no front or back, two great TORN SHEETS of membrane that beat it along (no finger bones, no scallops like a bat's: broad, sail-shaped,
# the trailing edge ragged with long tatters and a few holes, one wing bigger than the other), a smaller THIRD sheet standing up off its back that
# no flying animal would have, a hanging cluster of sinuous TENDRILS of different lengths that curl at the tips, two thin whip FILAMENTS trailing from
# the wing tips, and a few pin-pricks of sky showing THROUGH the mass where eyes would be if it had any (negative space, not light: it stays a shadow).
# Drawn at 6x with PIL and sampled down to whole pixels; one drawing per (size, pose) in five poses — up, raised, level, down, glide — and
# they are NOT mirror-symmetric, so the game's flip never gives two the same silhouette. Three sizes (L / M / S = near / mid / far).
MON_BODY = (13, 9, 12, 255)
MON_RIM = (44, 24, 22, 255)                          # the faintest warm edge on the underside: it is lit from the burning city below
MON_SIZES = {'L': (52, 30, 1.0), 'M': (36, 21, 0.69), 'S': (24, 14, 0.46)}
MON_POSES = ['up', 'raised', 'level', 'down', 'glide']
MON_SS = 6


def _bez(p0, p1, p2, n):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / float(n) for i in range(n + 1)]]


def _sheet_wing(d, root, tip, under, rng, scale, tatters):
    """A broad torn membrane from `root` (at the mass) out to `tip`, closed back along its trailing edge to `under` (a point low on the mass).
    The leading edge bows out and up; the trailing edge falls away in a long curve broken into `tatters` torn points of different lengths."""
    S = MON_SS
    chord = (tip[0] - root[0], tip[1] - root[1])
    n = math.hypot(*chord) or 1.0
    nx, ny = -chord[1] / n, chord[0] / n                       # a normal to the chord
    if ny > 0:
        nx, ny = -nx, -ny                                       # …pointing UP the picture
    lead = _bez(root, (root[0] + chord[0] * 0.5 + nx * n * 0.20, root[1] + chord[1] * 0.5 + ny * n * 0.20), tip, 14)
    trail = []
    for i in range(1, tatters + 1):                              # from the tip back toward the mass: tatters of different depth
        u = i / float(tatters)
        bx = tip[0] + (under[0] - tip[0]) * u
        by = tip[1] + (under[1] - tip[1]) * u
        belly = math.sin(math.pi * u) * n * 0.30                # the sheet sags below the chord between its tip and the mass
        trail.append((bx - nx * belly, by - ny * belly))
    pts = list(lead)
    # between each pair of trailing points a torn notch: in toward the root, then a long point
    prev = tip
    for i, (px, py) in enumerate(trail):
        mx, my = (prev[0] + px) / 2.0, (prev[1] + py) / 2.0
        notch = (0.10 + 0.20 * rng.random()) * n
        pts.append((mx + (root[0] - mx) * notch / n * 0.9, my + (root[1] - my) * notch / n * 0.9))
        reach = (0.05 + 0.15 * rng.random()) * n
        pts.append((px - nx * reach * 0.5, py - ny * reach))   # the long torn point hangs below the line
        prev = (px, py)
    pts.append(under)
    d.polygon([(x * S, y * S) for (x, y) in pts], fill=255)
    return lead


def _tendril(d, x0, y0, length, sway, phase, curl, thick):
    S = MON_SS
    pts = []
    n = 10
    for i in range(n + 1):
        u = i / float(n)
        pts.append((x0 + sway * math.sin(phase + u * 3.4) * u + curl * (u ** 3) * length * 0.35, y0 + u * length))
    for i in range(n):
        w = max(1.0, thick * (1.0 - 0.7 * i / n))
        d.line([(pts[i][0] * S, pts[i][1] * S), (pts[i + 1][0] * S, pts[i + 1][1] * S)], fill=255, width=int(round(w * S * 0.55)))


def _monster(size, pose):
    """One flier: see the header. The same torn edges, holes and tendril lengths in every pose of a size (its own seed); only the wings'
    angles and the tendrils' sway change between poses."""
    w, h, k = MON_SIZES[size]
    S = MON_SS
    rng = random.Random({'L': 11, 'M': 23, 'S': 37}[size])
    m = Image.new('L', (w * S, h * S), 0)
    d = ImageDraw.Draw(m)
    cx = w * 0.5 + w * 0.02
    el = {'up': 62.0, 'raised': 30.0, 'level': -3.0, 'down': -48.0, 'glide': 12.0}[pose]
    reach = w * 0.47
    # the mass: three lobes of different size down a slightly crooked axis (no head — no front)
    body_y = h * 0.36
    for (ox, oy, rx, ry) in ((-0.025, -0.07, 0.085, 0.12), (0.02, 0.03, 0.10, 0.14), (-0.01, 0.13, 0.075, 0.10)):
        _e = [(cx + ox * w - rx * w) * S, (body_y + oy * h - ry * h) * S, (cx + ox * w + rx * w) * S, (body_y + oy * h + ry * h) * S]
        d.ellipse(_e, fill=255)
    # the two great sheets: the left one the bigger, each angled a little differently
    for side, scl, skew in ((-1, 1.0, 5.0), (1, 0.80, -7.0)):
        e = math.radians(el + skew)
        root = (cx + side * w * 0.05, body_y - h * 0.04)
        tip = (root[0] + side * math.cos(e) * reach * scl, root[1] - math.sin(e) * reach * scl)
        under = (cx + side * w * 0.03, body_y + h * 0.17)
        lead = _sheet_wing(d, root, tip, under, random.Random(rng.random()), scl, 5 if size != 'S' else 4)
        # a whip filament from the tip, hanging
        tx, ty = tip
        _tendril(d, tx, ty, h * (0.26 if side < 0 else 0.20), side * w * 0.03, 1.1 + side, side * 1.2, 1.0)
    # the third sheet: smaller, hanging crooked off one flank where no wing grows — a wing too many
    e3 = math.radians(-62.0 + (10.0 if pose in ('up', 'raised') else -6.0))
    r3 = (cx - w * 0.045, body_y + h * 0.06)
    t3 = (r3[0] + math.cos(e3) * w * 0.20, r3[1] - math.sin(e3) * w * 0.20)
    _sheet_wing(d, r3, t3, (cx + w * 0.01, body_y + h * 0.17), random.Random(rng.random()), 0.7, 3)
    # the hanging tendrils: 8 (L) / 6 (M) / 4 (S), long, spread wide, each its own length, swaying with the pose and hooked at the tip
    nt = {'L': 8, 'M': 6, 'S': 4}[size]
    ph = {'up': 0.0, 'raised': 0.9, 'level': 1.8, 'down': 2.7, 'glide': 3.6}[pose]
    for i in range(nt):
        u = (i + 0.5) / nt - 0.5
        x0 = cx + u * w * 0.24 + rng.uniform(-0.012, 0.012) * w
        y0 = body_y + h * (0.12 + 0.05 * (1 - abs(u) * 2))
        ln = h * (0.30 + 0.42 * rng.random())
        _tendril(d, x0, y0, ln, w * (0.05 + 0.04 * rng.random()), ph + i * 1.7, (1.0 if i % 2 else -1.0) * (1.2 + rng.random()), 1.3 if size == 'L' else 1.0)
    # thin tatters hanging off the trailing edge of the sheets: filaments, not fingers
    for side in (-1, 1):
        for j in range(3 if size == 'L' else 2):
            fx = cx + side * w * (0.14 + 0.11 * j + rng.uniform(0.0, 0.03))
            fy = body_y + h * (0.20 + 0.04 * j)
            _tendril(d, fx, fy, h * (0.16 + 0.14 * rng.random()), side * w * 0.02, ph + j + side, side * 0.6, 1.0)
    # pin-pricks of sky showing through the mass where eyes would be: cut out, in an arrangement nothing living has
    if size != 'S':
        for (ox, oy) in ((-0.03, -0.02), (0.02, -0.06), (0.035, 0.03), (-0.005, 0.07)):
            r = 0.012 * w if size == 'L' else 0.014 * w
            d.ellipse([(cx + ox * w - r) * S, (body_y + oy * h - r) * S, (cx + ox * w + r) * S, (body_y + oy * h + r) * S], fill=0)
    # sample down to whole pixels (thin parts survive on a third of a cell), then a faint warm rim under the underside
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = img.load()
    mp = m.load()
    for y in range(h):
        for x in range(w):
            tot = sum(1 for yy in range(S) for xx in range(S) if mp[x * S + xx, y * S + yy])
            if tot >= 0.36 * S * S:
                px[x, y] = MON_BODY
    for y in range(h - 1):
        for x in range(w):
            if px[x, y][3] and not px[x, y + 1][3] and (x * 3 + y) % 4 == 0:
                px[x, y + 1] = MON_RIM
    return img


def draw_monsters():
    """-> (the sheet, its meta): {'L': [{name, x, y, w, h}], 'M': [...], 'S': [...]} — one row per size, one cell per pose."""
    gap = 1
    width = max(len(MON_POSES) * (MON_SIZES[s][0] + gap) for s in MON_SIZES)
    height = sum(MON_SIZES[s][1] + gap for s in MON_SIZES)
    sheet = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    meta = {}
    y = 0
    for size in ('L', 'M', 'S'):
        w, h, _ = MON_SIZES[size]
        meta[size] = []
        for i, pose in enumerate(MON_POSES):
            x = i * (w + gap)
            sheet.paste(_monster(size, pose), (x, y))
            meta[size].append({'name': pose, 'x': x, 'y': y, 'w': w, 'h': h})
        y += h + gap
    return sheet, meta


if __name__ == '__main__':
    import sys
    if '--monsters' in sys.argv:
        sheet, meta = draw_monsters()
        out = sys.argv[sys.argv.index('--monsters') + 1] if len(sys.argv) > sys.argv.index('--monsters') + 1 else '/tmp/monsters.png'
        bg = Image.new('RGBA', sheet.size, (110, 70, 48, 255))
        bg.alpha_composite(sheet)
        bg.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(out)
        print(out, sheet.size)
        sys.exit(0)
    sheet, meta = draw_birds()
    out = sys.argv[1] if len(sys.argv) > 1 else '/tmp/birds.png'
    bg = Image.new('RGBA', sheet.size, (176, 196, 210, 255))
    bg.alpha_composite(sheet)
    bg.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save(out)
    print(out, sheet.size)
