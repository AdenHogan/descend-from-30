#!/usr/bin/env python3
"""THE OPENING'S BIRDS (owner round 49: "the birds on the telephone wire… are static and could actually fly away with flapping wings, as
if disturbed. The birds at the top just sort of float, and don't flap their wings").

One sheet, `assets/opening/birds.png`, drawn pixel by pixel (every point an integer, no anti-aliasing — the old sky birds were vector
lines over a pixel picture). Two rows:

    row 0  NEAR crows (16 x 13), facing right:  perched · crouch (about to go) · wings up · wings raised · wings level · wings down · glide
    row 1  FAR birds (11 x 6) and TINY ones (7 x 4), seen from below, symmetric:  wings up · raised · level · down · glide

The game flips them for a leftward bird and plays the flap cycle  up → raised → level → down → level…  at the rate a crow beats its wings.
`meta['birds']` lists every cell, so the game never hard-codes the sheet's layout.
"""
import math
import random

from PIL import Image, ImageDraw

from pixlib import Canvas, hexc

# ---- the crows: HAND-PLACED pixels (owner 2026-11-11: "I hate the look of the daytime birds flying above the building. They look poorly
# designed"). The old crows were ellipses and rotated blades rasterised by a formula: a blob with a blade through it. Every pixel below is
# placed by hand on a grid, three tones and a beak: K the body, S the shade (tail, far wing, belly), H the sheen along the back / the leading
# edge of a wing, B the beak, E the eye's glint.
TONES = {'K': hexc('1b1b22'), 'S': hexc('0e0e13'), 'H': hexc('43434f'), 'B': hexc('5a5448'), 'E': hexc('8f8f9a')}
NEAR_W, NEAR_H = 16, 13
FAR_W, FAR_H = 11, 6
TINY_W, TINY_H = 7, 4
NEAR = ['perched', 'crouch', 'up', 'raised', 'level', 'down', 'glide']
FAR = ['up', 'raised', 'level', 'down', 'glide']

# NEAR crows, seen from the side, facing right. The feet (perched / crouch) are on the bottom row at x 8 and 10; in flight the body lies on rows 6-8.
_NEAR = {
    'perched': [
        '................',
        '..........KKK...',
        '.........KKEKBB.',
        '.........KKKKB..',
        '........HKKKK...',
        '......HHKKKKK...',
        '.....HKKKKKKK...',
        '....HKKSKKKKK...',
        '...KKSSSKKKK....',
        '..KKSS.KKKK.....',
        '.KSS....S.S.....',
        'KS......S.S.....',
        '.......SS.SS....',
    ],
    'crouch': [
        '................',
        '................',
        '................',
        '.....HHH........',
        '....HKKKH.......',
        '...HKKKKKH.KKK..',
        '..HKKKKKKKKKEKBB',
        '.KKKSKKKKKKKKK..',
        'KKSSSSKKKKKKK...',
        'KS...KKKKKKK....',
        '.......KKKK.....',
        '........S.S.....',
        '.......SS.SS....',
    ],
    'up': [
        '..KKH...........',
        '..KKKH..........',
        '...KKKKH........',
        '...KKKKKH.......',
        '....KKKKKH......',
        '....KKKKKH.KKK..',
        '..SSSKKKKKKKEKBB',
        'SSSSKKKKKKKKKK..',
        '.SSS.SKKKKKK....',
        '................',
        '................',
        '................',
        '................',
    ],
    'raised': [
        '................',
        'HHH.............',
        'KKKHHH..........',
        '.KKKKKHH........',
        '..KKKKKKH.......',
        '....KKKKKH.KKK..',
        '..SSSKKKKKKKEKBB',
        'SSSSKKKKKKKKKK..',
        '.SSS.SKKKKKK....',
        '................',
        '................',
        '................',
        '................',
    ],
    'level': [
        '................',
        '................',
        '................',
        '................',
        '................',
        '....SSSS...KKK..',
        '..SSHHHHHHKKEKBB',
        'SSSSKKKKKKKKKK..',
        '.SSS.SKKKKKK....',
        '................',
        '................',
        '................',
        '................',
    ],
    'down': [
        '................',
        '................',
        '................',
        '................',
        '................',
        '...........KKK..',
        '..SSSKKKKKKKEKBB',
        'SSSSKKKKKKKKKK..',
        '.SSS.SKKKKKH....',
        '....SKKKKKH.....',
        '...SKKKKKH......',
        '...SKKKH........',
        '...SKK..........',
    ],
    'glide': [
        '................',
        '................',
        '................',
        '................',
        '.KKKHHHH........',
        '...KKKKKHH.KKK..',
        '..SSSKKKKKKKEKBB',
        'SSSSKKKKKKKKKK..',
        '.SSS.SKKKKKK....',
        '................',
        '................',
        '................',
        '................',
    ],
}

# FAR birds: the flock wheeling over the roof, seen from below and a long way off, where a bird is its two wings and a dot of body. Symmetric,
# so one drawing serves whichever way it is going (the old side-view bird was squashed to turn it round). `tiny` is the same bird further off:
# the far side of the circle.
_FAR = {
    'up': [
        'K.........K',
        'KK.......KK',
        '.KK.....KK.',
        '..KKK.KKK..',
        '....KKK....',
        '.....S.....',
    ],
    'raised': [
        '...........',
        'KK.......KK',
        '.KKK...KKK.',
        '...KKKKK...',
        '....KKK....',
        '.....S.....',
    ],
    'level': [
        '...........',
        '...........',
        'KKKK...KKKK',
        '...KKKKK...',
        '....KKK....',
        '.....S.....',
    ],
    'down': [
        '...........',
        '...........',
        '....KKK....',
        '..KKKKKKK..',
        '.KK..S..KK.',
        'K.........K',
    ],
    'glide': [
        '...........',
        '...........',
        '.KKK...KKK.',
        'K..KKKKK..K',
        '....KKK....',
        '.....S.....',
    ],
}
_TINY = {
    'up':     ['K.....K', '.K...K.', '..KKK..', '...K...'],
    'raised': ['.......', 'KK...KK', '..KKK..', '...K...'],
    'level':  ['.......', '.......', 'KKKKKKK', '...K...'],
    'down':   ['.......', '..KKK..', '.KKKKK.', 'K.....K'],
    'glide':  ['.......', '.K...K.', 'K.KKK.K', '...K...'],
}


def _grid(rows, w, h):
    assert len(rows) == h and all(len(r) == w for r in rows), 'a %d x %d grid is ragged' % (w, h)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != '.':
                px[x, y] = TONES[ch]
    return im


def _near(name):
    return _grid(_NEAR[name], NEAR_W, NEAR_H)


def _far(name):
    return _grid(_FAR[name], FAR_W, FAR_H)


def _tiny(name):
    return _grid(_TINY[name], TINY_W, TINY_H)


def draw_birds():
    """-> (the sheet, its meta): {'near': [{name, x, y, w, h}], 'far': [...], 'tiny': [...]}"""
    gap = 1
    w = max(len(NEAR) * (NEAR_W + gap), len(FAR) * (FAR_W + gap + TINY_W + gap))
    sheet = Image.new('RGBA', (w, NEAR_H + FAR_H + 2 * gap), (0, 0, 0, 0))
    meta = {'near': [], 'far': [], 'tiny': []}
    for i, n in enumerate(NEAR):
        x = i * (NEAR_W + gap)
        sheet.paste(_near(n), (x, 0))
        meta['near'].append({'name': n, 'x': x, 'y': 0, 'w': NEAR_W, 'h': NEAR_H})
    y = NEAR_H + gap
    for i, n in enumerate(FAR):
        x = i * (FAR_W + gap)
        sheet.paste(_far(n), (x, y))
        meta['far'].append({'name': n, 'x': x, 'y': y, 'w': FAR_W, 'h': FAR_H})
    x0 = len(FAR) * (FAR_W + gap)
    for i, n in enumerate(FAR):
        x = x0 + i * (TINY_W + gap)
        sheet.paste(_tiny(n), (x, y))
        meta['tiny'].append({'name': n, 'x': x, 'y': y, 'w': TINY_W, 'h': TINY_H})
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
