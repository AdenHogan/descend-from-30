"""The opening's runners, drawn from a SKELETON: a person running in fear and a black cat, each in THREE size tiers (owner round 49c: "the
man on the ground who runs toward the building… gets weirdly smaller… strange body pixel proportions and look generally unrefined", then, on
the first hand-typed version of these, "both look mangled… we need to be accurate, and not make them look disabled and nightmarish").

Why a skeleton: typing a figure pixel by pixel put its limbs wherever the eye last left them (a stump of an arm, a leg that did not join the
hip). Here every pose is a set of JOINTS — head, shoulder, hip, elbows, hands, knees, feet; for the cat the spine, head, tail and four legs —
the limbs are two segments of one fixed length joined at a knee or an elbow, and the pose is drawn at four times the size and sampled down to
whole pixels (a cell takes the colour of the topmost part that covers most of it), so the same figure is the same figure at every tier and a
limb is always attached. The three tiers are the three sizes a figure is ever shown at (`TIERS`: chosen by the ground row it stands on —
never a drawing rescaled to a fractional size); the smallest, at the building's own plane, is still about a person's height against a 14 px
storey.

Sheet: assets/opening/figures.png + meta['figures'] = {name: {x, y, w, h}}. Names: person_<L|M|S>_<a|p1|b|p2> (a four-frame run, facing
right), person_S_pound_<a|b> (seen from behind, a fist up on the boards), cat_<L|M|S>_<a|b> (a gallop: stretched, then gathered). All
face right; the game mirrors them.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, 'assets', 'opening')

# ground rows (0 = the building's foot, 43 = the front edge): a figure standing on row >= the tier's `row` is drawn at that tier
TIERS = {'L': 28, 'M': 14, 'S': 0}
PERSON_H = {'L': 16, 'M': 13, 'S': 10}
CAT_H = {'L': 9, 'M': 8, 'S': 6}
RUN_FRAMES = ('a', 'p1', 'b', 'p2')
SS = 6                                                  # the drawing is made at this many times the size, then sampled down

PAL = {
    'hair': (40, 28, 24, 255),
    'skin': (214, 160, 126, 255),
    'skin_d': (170, 120, 92, 255),                      # the far arm
    'shirt': (204, 72, 62, 255),
    'shirt_d': (150, 50, 46, 255),                      # the far sleeve / the shaded back
    'pants': (50, 58, 92, 255),
    'pants_d': (32, 38, 64, 255),                       # the far leg
    'shoe': (24, 22, 28, 255),
    'cat': (14, 14, 18, 255),
    'cat_lit': (40, 40, 52, 255),                       # the far legs, a shade lighter than the body so they read as a second pair
    'eye': (206, 214, 84, 255),
}

# ---- the person -------------------------------------------------------------------------------------------------------------------
# Joints in a 9 x 13 box (the L tier; x right, y down, the feet at y 13). Facing right, leaning into the run. Near arm / leg = the ones
# toward the viewer. `a` = contact, the near leg reaching forward and the near arm swung back; `p1` = passing, the near leg tucked up
# under the hip; `b` = contact with the other leg forward; `p2` = passing the other way.
RUN = {
    'a': dict(head=(5.0, 2.2), neck=(4.5, 3.8), hip=(3.7, 7.5),
              n_elbow=(3.0, 6.0), n_hand=(1.9, 5.0), f_elbow=(6.1, 6.0), f_hand=(7.5, 4.9),
              n_knee=(5.4, 9.8), n_foot=(6.9, 12.7), f_knee=(2.8, 9.9), f_foot=(0.9, 11.6)),
    'p1': dict(head=(4.9, 2.3), neck=(4.4, 3.9), hip=(3.7, 7.6),
               n_elbow=(3.6, 6.5), n_hand=(5.1, 6.3), f_elbow=(3.3, 6.4), f_hand=(2.4, 7.6),
               n_knee=(5.0, 9.2), n_foot=(2.6, 10.3), f_knee=(3.9, 10.0), f_foot=(3.9, 12.7)),
    'b': dict(head=(5.0, 2.2), neck=(4.5, 3.8), hip=(3.7, 7.5),
              n_elbow=(6.1, 6.0), n_hand=(7.5, 4.9), f_elbow=(3.0, 6.0), f_hand=(1.9, 5.0),
              n_knee=(2.8, 9.9), n_foot=(0.9, 11.6), f_knee=(5.4, 9.8), f_foot=(6.9, 12.7)),
    'p2': dict(head=(4.9, 2.3), neck=(4.4, 3.9), hip=(3.7, 7.6),
               n_elbow=(3.3, 6.4), n_hand=(2.4, 7.6), f_elbow=(3.6, 6.5), f_hand=(5.1, 6.3),
               n_knee=(3.9, 10.0), n_foot=(3.9, 12.7), f_knee=(5.0, 9.2), f_foot=(2.6, 10.3)),
}


def _canvas(w, h):
    return Image.new('L', (w * SS, h * SS), 0)


def _line(d, pts, width):
    """A polyline of round-capped segments, `width` in output pixels."""
    pts = [(x * SS, y * SS) for (x, y) in pts]
    wpx = max(1, int(round(width * SS)))
    for a, b in zip(pts[:-1], pts[1:]):
        d.line([a, b], fill=255, width=wpx)
    r = wpx / 2.0
    for (x, y) in pts:
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)


def _ellipse(d, cx, cy, rx, ry):
    d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=255)


def _poly(d, pts):
    d.polygon([(x * SS, y * SS) for (x, y) in pts], fill=255)


def _sample(layers, w, h):
    """Layers = [(mask, colour)] bottom to top -> an RGBA image of whole pixels: a cell takes the topmost layer covering at least 45 % of it."""
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = img.load()
    for mask, col in layers:
        mp = mask.load()
        for y in range(h):
            for x in range(w):
                tot = 0
                for yy in range(SS):
                    for xx in range(SS):
                        tot += 1 if mp[x * SS + xx, y * SS + yy] else 0
                if tot >= 0.45 * SS * SS:
                    px[x, y] = col
    return img


def scaled(pose, k, ox=0.0):
    return {n: (p[0] * k + ox, p[1] * k) for n, p in pose.items()}


def person(tier, frame):
    """One frame of the runner at a tier."""
    H = PERSON_H[tier]
    k = H / 13.0
    W = int(math.ceil(9 * k)) + 1
    j = scaled(RUN[frame], k, 0.5)
    hr0 = {'L': 1.5, 'M': 1.5, 'S': 1.0}[tier]
    odd = int(round(2 * hr0)) % 2 == 1                           # a 3 px head is centred on a pixel's middle, a 2 px head on a corner: so it is whole pixels, not a stalk of one
    hx = math.floor(j['head'][0]) + (0.5 if odd else 0.0)
    j['head'] = (hx, hr0)                                          # …and its top is the figure's top row
    wt = {'L': 3.0, 'M': 2.5, 'S': 2.1}[tier]                  # the torso's thickness
    wl = {'L': 2.0, 'M': 1.7, 'S': 1.4}[tier]                  # a leg's
    wa = {'L': 1.3, 'M': 1.1, 'S': 1.0}[tier]                  # an arm's
    hr = {'L': 1.5, 'M': 1.5, 'S': 1.0}[tier]                  # the head's radius: 3, 3 and 2 whole pixels across
    layers = []

    def part(col, fn):
        m = _canvas(W, H)
        fn(ImageDraw.Draw(m))
        layers.append((m, col))

    def shoe(knee, foot):
        """The foot: a short block at the end of the shin, pointing the way the runner faces."""
        back = _toward(foot, knee, 0.6 * k)
        return [(back[0], back[1]), (foot[0] + 0.9 * k, foot[1] - 0.1)]

    part(PAL['shirt_d'], lambda d: _line(d, [j['neck'], j['f_elbow'], j['f_hand']], wa))               # the far arm: a long sleeve in shade…
    part(PAL['skin_d'], lambda d: _ellipse(d, j['f_hand'][0], j['f_hand'][1], 0.6, 0.6))                 # …and its hand
    part(PAL['pants_d'], lambda d: _line(d, [j['hip'], j['f_knee'], j['f_foot']], wl))                # the far leg
    part(PAL['shoe'], lambda d: _line(d, shoe(j['f_knee'], j['f_foot']), wl * 0.95))
    part(PAL['shirt'], lambda d: _line(d, [j['neck'], j['hip']], wt))                                  # the torso
    part(PAL['shirt_d'], lambda d: _line(d, [(j['neck'][0] - 0.7 * k, j['neck'][1] + 0.6 * k), (j['hip'][0] - 0.7 * k, j['hip'][1] - 0.4 * k)], 0.8))   # its shaded back
    part(PAL['pants'], lambda d: _line(d, [j['hip'], j['n_knee'], j['n_foot']], wl))                  # the near leg
    part(PAL['shoe'], lambda d: _line(d, shoe(j['n_knee'], j['n_foot']), wl * 0.95))
    part(PAL['hair'], lambda d: _ellipse(d, j['head'][0], j['head'][1], hr, hr * 1.05))               # the head: hair all round…
    part(PAL['skin'], lambda d: _face(d, j['head'], hr, W, H))                                         # …and the face on the lower right of it
    part(PAL['shirt'], lambda d: _line(d, [j['neck'], j['n_elbow'], j['n_hand']], wa))                # the near arm: a long sleeve…
    part(PAL['skin'], lambda d: _ellipse(d, j['n_hand'][0], j['n_hand'][1], 0.6, 0.6))                  # …and its hand
    img = _sample(layers, W, H)
    return _trim(img, H)


def _toward(a, b, dist):
    """The point `dist` from `a` toward `b`."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1.0
    return (a[0] + dx / n * dist, a[1] + dy / n * dist)


def _face(d, head, r, W, H):
    """The face: the part of the head's circle right of the ear and below the brow (the figure looks right); the rest of the circle stays hair."""
    cx, cy = head
    _ellipse(d, cx, cy, r, r * 1.05)
    ear_x, brow_y = cx - 0.15 * r, cy - 0.3 * r
    d.rectangle([0, 0, (ear_x) * SS, H * SS], fill=0)                  # left of the ear: the back of the head
    d.rectangle([0, 0, W * SS, (brow_y) * SS], fill=0)                  # above the brow: the crown


def _trim(img, h):
    """Keep the figure's own height: the bottom row is its feet."""
    bbox = img.getbbox()
    if bbox is None:
        return img
    x0, _, x1, _ = bbox
    return img.crop((x0, 0, x1, h))


# ---- the person at the door, from behind ---------------------------------------------------------------------------------------------
def pound(frame):
    """Seen from behind at the smallest tier (10 px of body, a fist a pixel above the head): hair, shoulders, one arm up on the boards and the other
    hanging at the side — then the other way round."""
    H, W = 11, 8
    layers = []

    def part(col, fn):
        m = _canvas(W, H)
        fn(ImageDraw.Draw(m))
        layers.append((m, col))

    up_left = frame == 'a'
    part(PAL['pants_d'], lambda d: _line(d, [(3.1, 7.0), (3.1, 10.6)], 1.5))                  # legs
    part(PAL['pants'], lambda d: _line(d, [(4.9, 7.0), (4.9, 10.6)], 1.5))
    part(PAL['shoe'], lambda d: _line(d, [(2.6, 10.6), (3.7, 10.6)], 0.9))
    part(PAL['shoe'], lambda d: _line(d, [(4.3, 10.6), (5.4, 10.6)], 0.9))
    part(PAL['shirt'], lambda d: _poly(d, [(2.4, 4.4), (5.6, 4.4), (5.4, 7.6), (2.6, 7.6)]))   # the back
    part(PAL['shirt_d'], lambda d: _line(d, [(2.6, 7.2), (5.4, 7.2)], 0.7))                   # the hem, in shade
    left_up = [(2.4, 5.0), (1.5, 3.4), (1.5, 1.4)]
    left_dn = [(2.4, 5.0), (1.8, 6.4), (2.0, 7.6)]
    right_up = [(5.6, 5.0), (6.5, 3.4), (6.5, 1.4)]
    right_dn = [(5.6, 5.0), (6.2, 6.4), (6.0, 7.6)]
    la, ra = (left_up, right_dn) if up_left else (left_dn, right_up)
    part(PAL['shirt'], lambda d: _line(d, la, 1.0))
    part(PAL['shirt'], lambda d: _line(d, ra, 1.0))
    part(PAL['skin'], lambda d: _ellipse(d, la[-1][0], la[-1][1], 0.55, 0.55))                  # the hands
    part(PAL['skin'], lambda d: _ellipse(d, ra[-1][0], ra[-1][1], 0.55, 0.55))
    part(PAL['hair'], lambda d: _ellipse(d, 4.0, 2.9, 1.3, 1.35))                              # the head from behind: hair
    part(PAL['skin_d'], lambda d: _line(d, [(3.5, 4.1), (4.5, 4.1)], 0.6))                     # the nape
    return _sample(layers, W, H)


# ---- the cat ----------------------------------------------------------------------------------------------------------------
# Joints in a 15 x 8 box (the L tier), facing right. `a` = stretched (the fore legs reaching, the hind legs thrown back, the spine long and
# low); `b` = gathered (all four feet bunched under the body, the back arched).
CAT = {
    'a': dict(shoulder=(9.4, 4.4), hip=(5.0, 4.5), head=(11.6, 3.3), tail=[(4.2, 4.3), (2.6, 3.8), (1.4, 2.6), (1.5, 1.0)],
              nf=[(9.6, 5.4), (11.2, 6.9), (12.8, 8.4)], ff=[(9.0, 5.4), (10.4, 6.8), (11.4, 8.5)],
              nh=[(4.8, 5.4), (3.2, 6.9), (1.4, 8.4)], fh=[(5.6, 5.4), (4.4, 6.8), (2.8, 8.5)]),
    'b': dict(shoulder=(9.0, 4.0), hip=(5.2, 3.9), head=(11.0, 3.1), tail=[(4.4, 3.8), (3.0, 3.2), (2.0, 2.0), (2.1, 0.6)],
              nf=[(9.2, 5.2), (9.6, 6.8), (10.8, 8.5)], ff=[(8.6, 5.2), (8.8, 6.8), (9.6, 8.5)],
              nh=[(5.0, 5.0), (6.0, 6.9), (7.2, 8.5)], fh=[(5.6, 5.0), (6.6, 6.8), (8.0, 8.5)]),
}


def cat(tier, frame):
    H = CAT_H[tier]
    k = H / 9.0
    W = int(math.ceil(14 * k)) + 1
    c = CAT[frame]
    S = lambda p: (p[0] * k + 0.4, p[1] * k)
    sh, hp, hd = S(c['shoulder']), S(c['hip']), S(c['head'])
    wb = {'L': 3.0, 'M': 2.6, 'S': 2.2}[tier]
    wl = {'L': 1.3, 'M': 1.1, 'S': 1.0}[tier]
    layers = []

    def part(col, fn):
        m = _canvas(W, H)
        fn(ImageDraw.Draw(m))
        layers.append((m, col))

    part(PAL['cat_lit'], lambda d: _line(d, [S(p) for p in c['ff']], wl))                    # the far legs (a shade lighter)
    part(PAL['cat_lit'], lambda d: _line(d, [S(p) for p in c['fh']], wl))
    part(PAL['cat'], lambda d: _line(d, [S(p) for p in c['tail']], 1.0))                      # the tail
    part(PAL['cat'], lambda d: _line(d, [hp, sh], wb))                                        # the body
    part(PAL['cat'], lambda d: _line(d, [S(p) for p in c['nh']], wl * 1.15))                  # the near legs
    part(PAL['cat'], lambda d: _line(d, [S(p) for p in c['nf']], wl * 1.15))
    r = {'L': 1.8, 'M': 1.6, 'S': 1.35}[tier]
    part(PAL['cat'], lambda d: _ellipse(d, hd[0], hd[1], r, r * 0.95))                         # the head
    part(PAL['cat'], lambda d: _poly(d, [(hd[0] - r * 1.0, hd[1] - r * 0.2), (hd[0] - r * 0.6, hd[1] - r * 1.95), (hd[0] + 0.0, hd[1] - r * 0.6)]))   # the ears
    part(PAL['cat'], lambda d: _poly(d, [(hd[0] + 0.1, hd[1] - r * 0.6), (hd[0] + r * 0.75, hd[1] - r * 1.95), (hd[0] + r * 1.05, hd[1] - r * 0.2)]))
    part(PAL['eye'], lambda d: _ellipse(d, hd[0] + r * 0.45, hd[1] - r * 0.15, 0.5, 0.5))
    img = _sample(layers, W, H)
    return _trim(img, H)


# ---- the sheet ------------------------------------------------------------------------------------------------------------------
def all_sprites():
    out = {}
    for tier in PERSON_H:
        for f in RUN_FRAMES:
            out['person_%s_%s' % (tier, f)] = person(tier, f)
    for f in ('a', 'b'):
        out['person_S_pound_%s' % f] = pound(f)
    for tier in CAT_H:
        for f in ('a', 'b'):
            out['cat_%s_%s' % (tier, f)] = cat(tier, f)
    return out


def draw_sheet():
    spr = all_sprites()
    gap = 1
    names = sorted(spr)
    wid = sum(spr[n].width + gap for n in names)
    hei = max(spr[n].height for n in names)
    sheet = Image.new('RGBA', (wid, hei), (0, 0, 0, 0))
    meta = {}
    x = 0
    for n in names:
        im = spr[n]
        sheet.paste(im, (x, 0))
        meta[n] = {'x': x, 'y': 0, 'w': im.width, 'h': im.height}
        x += im.width + gap
    return sheet, meta


def tier_for(row):
    """Which of the three drawings a figure standing on ground row `row` uses."""
    for name in ('L', 'M'):
        if row >= TIERS[name]:
            return name
    return 'S'


def size_of(kind, row):
    """(w, h) of the figure on that row, as drawn: what the art tool's clearance check measures."""
    t = tier_for(row)
    im = cat(t, 'a') if kind == 'cat' else person(t, 'a')
    return im.width, im.height


def self_check():
    errs = []
    spr = all_sprites()
    for n, im in spr.items():
        if im.getbbox() is None:
            errs.append('%s: empty' % n)
            continue
        px = im.load()
        # a figure stands on its bottom row: something must touch it
        if not any(px[x, im.height - 1][3] for x in range(im.width)):
            errs.append('%s: nothing on the feet row' % n)
        # one connected body (an arm or a leg that does not join is exactly the "mangled" look this module exists to prevent)
        seen = set()
        todo = [(x, y) for y in range(im.height) for x in range(im.width) if px[x, y][3]][:1]
        while todo:
            x, y = todo.pop()
            if (x, y) in seen or not (0 <= x < im.width and 0 <= y < im.height) or not px[x, y][3]:
                continue
            seen.add((x, y))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    todo.append((x + dx, y + dy))
        total = sum(1 for y in range(im.height) for x in range(im.width) if px[x, y][3])
        if len(seen) != total:
            errs.append('%s: %d of its %d pixels are not joined to the body' % (n, total - len(seen), total))
    for t in PERSON_H:
        for f in RUN_FRAMES:
            if spr['person_%s_%s' % (t, f)].height != PERSON_H[t]:
                errs.append('person %s %s is not %d tall (%d)' % (t, f, PERSON_H[t], spr['person_%s_%s' % (t, f)].height))
    if not (PERSON_H['L'] > PERSON_H['M'] > PERSON_H['S'] >= 10):
        errs.append('person tiers must shrink in steps and never below 10 px (a person at the building plane)')
    return errs


if __name__ == '__main__':
    errs = self_check()
    if '--preview' in sys.argv:
        spr = all_sprites()
        out = sys.argv[sys.argv.index('--preview') + 1]
        names = sorted(spr)
        wid = sum(spr[n].width + 2 for n in names)
        hei = max(spr[n].height for n in names)
        sheet = Image.new('RGBA', (wid, hei), (74, 130, 66, 255))
        x = 0
        for n in names:
            sheet.alpha_composite(spr[n], (x, 0))
            x += spr[n].width + 2
        sheet.resize((sheet.width * 12, sheet.height * 12), Image.NEAREST).save(out)
        print('wrote', out, [n for n in names])
    if errs:
        print('\n'.join(errs))
        sys.exit(1)
