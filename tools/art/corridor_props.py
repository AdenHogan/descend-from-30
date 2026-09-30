"""The corridor's STANDING DRESSING — what residents leave outside their doors — drawn with geometry and
weight (owner round 24b: "most of the decorations you have placed outside apartments, they are very flat
and on the wall… If you design a thing to be out there, it needs to have geometry and weight to it. AND
logic… Don't just randomly have things on the floor, place them logically with reason").

Called by tools/art/corridor_decals.py (its main() writes every decal). Each prop is seen the way the
corridor is: straight on, a little from above — so it shows its TOP (a lid, a seat, the open top of a box
or a bag, the soil in a planter) as well as its front, stands on the floor with its back to the skirting,
and casts a soft shadow forward onto the floor.

Sprite convention (assets/corridor/decals/dressing.json, read by scripts/corridor_decals.gd):
  contact  the sprite row of the prop's FRONT floor contact (a shadow may run two rows below it)
  depth    how far the prop stands out from the wall on the floor (its back sits on the skirting line,
           corridor local y 160, so the game draws it with contact at y 160 + depth)
  rule     WHERE it goes, with reason: "door" = beside a flat's door (shoes, a shoe rack, an umbrella
           stand, parcels, a pram, bin bags put out, the recycling, a bike leant on the wall...);
           "open" = a stretch of wall between the doors or by the lift (a planter, a plant on its stand,
           a hall chair).
"""
import math
import random

from PIL import Image
from pixlib import Canvas, hexc, shade, mix

META = {}
SHADOW = 2                       # rows of floor shadow below the front contact


def new(w, h, seed=1):
    return Canvas(w=w, h=h, seed=seed)


def ground(c, x0, x1, back, front, alpha=95):
    """The prop's footprint shadow on the floor: darkest under it, softening forward and at the ends."""
    cx, cy = (x0 + x1) / 2.0, (back + front) / 2.0 + 1.5
    c.shadow(cx, cy, (x1 - x0) / 2.0 + 2.5, (front - back) / 2.0 + 2.5, alpha)


def block(c, x0, x1, top, bottom, d, col, top_col=None, rim=True):
    """A box seen straight on and a little from above: its top face (d rows) over its front face."""
    tc = top_col if top_col is not None else shade(col, 1.2)
    c.rect(x0, top - d, x1, top - 1, tc)
    c.hline(x0, x1, top - d, shade(tc, 0.86))                       # the back edge, against the wall
    c.rect(x0, top, x1, bottom, col)
    if rim:
        c.hline(x0, x1, top, shade(col, 1.32))                      # the lit front edge
    c.vline(x0, top, bottom, shade(col, 1.08))
    c.vline(x1, top - d + 1, bottom, shade(col, 0.72))
    c.hline(x0, x1, bottom, shade(col, 0.62))


def cylinder(c, cx, rx, top, bottom, ry, col, lid=None, inner=None):
    """Upright cylinder: shaded body, the front of its base ellipse, an open or lidded top ellipse.
    `bottom` is the base ellipse's centre row; the front contact is bottom + ry."""
    for x in range(cx - rx, cx + rx + 1):
        k = (x - cx) / float(rx)                                    # -1 .. 1, lit from the left
        col_x = shade(col, 1.18 - 0.42 * ((k + 0.45) ** 2) ** 0.5)
        yb = bottom + int(round(ry * (1 - k * k) ** 0.5))
        c.vline(x, top, yb, col_x)
    for x in range(cx - rx, cx + rx + 1):                           # the base rim
        k = (x - cx) / float(rx)
        c.put(x, bottom + int(round(ry * (1 - k * k) ** 0.5)), shade(col, 0.6))
    c.ellipse(cx, top, rx, ry, shade(col, 1.25))                    # the top rim
    if inner is not None:
        c.ellipse(cx, top, max(1, rx - 1), max(1, ry - 1), inner)
    elif lid is not None:
        c.ellipse(cx, top, max(1, rx - 1), max(1, ry - 1), lid)


def record(name, rule, depth, contact):
    # a prop's VARIANTS are named <base>, <base>__2, <base>__3 ... (the game picks one per placement)
    META[name] = {"rule": rule, "depth": depth, "contact": contact, "base": name.split('__')[0]}


# --- by the door --------------------------------------------------------------------------------
# --- SHOES, side-on (owner round 25: the first rack "looked like a bulletin board with pagers and
# phones" — its shoes were tiny front-on blocks). Side-on, a shoe is a shoe: toe, heel, sole, laces. ---
SHOE_STYLES = ('trainer', 'brogue', 'heel', 'boot', 'kid')


def shoe_side(c, x, base, style, col, face=1, k=1.0):
    """One shoe seen from the side, heel at x, toe toward `face` (+1 right / -1 left), sole on row `base`.
    k < 1 darkens it (a shoe further back)."""
    col = shade(col, k)
    L = {'trainer': 11, 'brogue': 11, 'heel': 10, 'boot': 10, 'kid': 8}[style]
    top = {'trainer': (5, 5, 5, 4, 4, 3, 3, 3, 2, 2, 2), 'brogue': (4, 4, 4, 3, 3, 3, 2, 2, 2, 2, 1),
           'heel': (4, 4, 4, 3, 2, 2, 2, 1, 1, 1), 'boot': (8, 8, 8, 7, 4, 3, 3, 2, 2, 2),
           'kid': (4, 4, 4, 3, 3, 2, 2, 2)}[style]
    X = (lambda i: x + i) if face > 0 else (lambda i: x - i)
    lift = (lambda i: max(0, 3 - i)) if style == 'heel' else (lambda i: 0)     # a stiletto's raised heel
    sole = shade(hexc('ece6da'), k) if style in ('trainer', 'kid') else shade(hexc('241c18'), k)
    for i in range(L):
        b = base - lift(i)
        c.put(X(i), b, sole)                                          # the sole
        for r in range(1, top[i] + 1):
            cc = col
            if r == top[i]:
                cc = shade(col, 1.25)                                 # lit top edge
            elif r == 1:
                cc = shade(col, 0.72)                                 # the shaded welt above the sole
            c.put(X(i), b - r, cc)
    c.put(X(0), base - lift(0) - 1, shade(col, 0.6))                  # the heel's back edge
    c.put(X(L - 1), base - lift(L - 1) - 1, shade(col, 0.85))         # the toe's end
    if style in ('trainer', 'kid', 'brogue'):                         # the open collar at the heel
        c.put(X(1), base - top[1], shade(col, 0.35))
        c.put(X(2), base - top[2], shade(col, 0.35))
    if style == 'trainer':
        for i in (4, 5, 6):                                           # laces
            c.put(X(i), base - top[i], hexc('f4f0e6'))
        for i, r in ((3, 2), (4, 2), (5, 3), (6, 3)):                 # the side stripe
            c.put(X(i), base - r, shade(hexc('e8e4dc'), k))
        c.put(X(0), base - 1, sole)
    elif style == 'kid':
        c.put(X(4), base - 3, hexc('f8f0a0'))                         # a velcro strap
        c.put(X(5), base - 3, hexc('f8f0a0'))
    elif style == 'brogue':
        for i in (4, 5):
            c.put(X(i), base - top[i], shade(col, 0.55))              # laces
        c.put(X(8), base - 2, shade(col, 1.7))                        # the polish on the toe
        c.put(X(0), base - 1, sole); c.put(X(1), base - 1, sole)      # a stacked heel
    elif style == 'heel':
        for r in range(0, 4):
            c.put(X(1), base - r, shade(hexc('1a1614'), k))           # the stiletto
        c.put(X(6), base - 2, shade(col, 1.6))
    elif style == 'boot':
        c.put(X(0), base - 8, shade(col, 0.5))                        # the pull tab
        c.put(X(1), base - 8, shade(col, 0.5))
        for i in range(L):
            c.put(X(i), base, shade(hexc('241c18'), k))
            if i < 3:
                c.put(X(i), base - 1, shade(hexc('3a2e26'), k))       # a chunky heel
    return L


def shoe_pair(c, x, base, style, col, face=1, depth_up=3):
    """A pair on a shelf: the far shoe set back (higher, darker, a little along), the near one in front."""
    shoe_side(c, x + 2 * face, base - depth_up, style, col, face, 0.78)
    shoe_side(c, x, base, style, col, face, 1.0)


def shoe_back(c, x, base, style, col, k=1.0):
    """One shoe seen from BEHIND (heel toward us): the heel counter, the collar's opening, the sole — 5px wide."""
    col = shade(col, k)
    dark = shade(col, 0.35)
    sole = shade(hexc('ece6da'), k) if style in ('trainer', 'kid') else shade(hexc('241c18'), k)
    hgt = {'trainer': 4, 'kid': 3, 'brogue': 3, 'heel': 3, 'boot': 7}[style]
    lift = 2 if style == 'heel' else 0
    b = base - lift
    c.hline(x, x + 4, b, sole)                                        # the sole / heel block
    for r in range(1, hgt + 1):
        for i in range(5):
            cc = col
            if i == 0:
                cc = shade(col, 1.2)                                  # lit left side
            elif i == 4:
                cc = shade(col, 0.7)
            c.put(x + i, b - r, cc)
    c.hline(x + 1, x + 3, b - hgt, dark)                              # the collar, open
    c.put(x, b - hgt, shade(col, 1.3)); c.put(x + 4, b - hgt, shade(col, 0.8))
    if style == 'trainer':
        c.put(x + 2, b - hgt + 1, hexc('d8483a'))                     # the heel tab
        c.hline(x + 1, x + 3, b - 1, shade(col, 0.85))
    elif style == 'heel':
        c.vline(x + 2, b + 1, base, shade(hexc('1a1614'), k))         # the stiletto under it
    elif style == 'boot':
        c.put(x + 2, b - hgt + 1, shade(col, 0.55))                   # the pull loop
        c.hline(x, x + 4, b - 1, shade(hexc('3a2e26'), k))


def shoe_back_pair(c, x, base, style, col, depth_up=2):
    """A pair seen from behind, heels out: side by side, one a touch further back."""
    shoe_back(c, x + 6, base - depth_up, style, col, 0.82)
    shoe_back(c, x, base, style, col, 1.0)


def lying_shoe(c, x, y, style, col, how='side'):
    """A shoe knocked onto the floor, pasted at (x, y) = top-left: 'sole' = flipped over, sole up;
    'toe_up' = stood on its heel; 'side' = fallen over, toe away."""
    t = new(14, 14, 1)
    shoe_side(t, 1, 11, style, col, 1, 1.0)
    im = t.img.crop(t.img.getbbox())
    if how == 'sole':
        im = im.transpose(Image.FLIP_TOP_BOTTOM)
    elif how == 'toe_up':
        im = im.rotate(90, expand=True)
    elif how == 'side':
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    c.img.alpha_composite(im, (x, y))


RACK_SHOES = [('trainer', 'ffffff'), ('trainer', '2a4a8a'), ('brogue', '5a3322'), ('brogue', '1e1a18'),
              ('heel', 'a82a2a'), ('trainer', '3a3a3e'), ('kid', 'e05a8a'), ('brogue', '7a4a2a')]


def _rack_frame(c, x0, x1, C, d, tiers, metal):
    """Two side boards / chrome posts and slatted shelves, seen straight on and a little from above."""
    wood = hexc('8a5f3c') if not metal else hexc('a9b0b8')
    dark, lite = shade(wood, 0.6), shade(wood, 1.3)
    top_y = tiers[-1] - d
    # the back posts, behind everything
    for x in (x0 + 1, x1 - 1):
        c.vline(x, top_y, C - d, dark)
    for y in tiers:
        if metal:
            c.hline(x0, x1, y - d, shade(wood, 0.7))                  # back rail
            c.hline(x0, x1, y, lite)                                  # front rail
            c.hline(x0, x1, y + 1, shade(wood, 0.55))
            for x in range(x0 + 3, x1 - 1, 4):                        # the wires between them
                c.line(x, y - d + 1, x, y - 1, shade(wood, 0.85))
        else:
            for r in range(d):                                        # the shelf's top, seen from above
                yy = y - d + r
                if r % 3 == 2:
                    c.hline(x0 + 1, x1 - 1, yy, shade(wood, 0.45))    # the gaps between slats
                else:
                    c.hline(x0 + 1, x1 - 1, yy, shade(wood, 1.08 - 0.06 * (d - r) / d))
            c.hline(x0, x1, y, lite)                                  # the front edge, catching the light
            c.hline(x0, x1, y + 1, shade(wood, 0.78))
    return wood


def _rack_posts(c, x0, x1, C, d, tiers, wood, metal):
    top_y = tiers[-1] - d
    if metal:
        for x in (x0, x1):
            c.vline(x, top_y - 1, C, shade(wood, 1.25))
            c.put(x, top_y - 2, shade(wood, 1.5))                     # the round cap
    else:
        for x in (x0, x1 - 1):                                        # the side boards: 2px, lit face + edge
            c.vline(x, top_y - 1, C, shade(wood, 1.12))
            c.vline(x + 1, top_y - 1, C, shade(wood, 0.82))
        c.hline(x0, x0 + 1, top_y - 1, shade(wood, 1.4))
        c.hline(x1 - 1, x1, top_y - 1, shade(wood, 1.4))


def shoe_rack(save, name, seed, metal=False, sprawled=False):
    """A three-tier shoe rack by the door, shoes in pairs — some side-on, some heels-out (owner round 25c:
    "some side facing, some back facing is perfectly fine; it's just about visual clarity").
    sprawled: some kicked off onto the floor all round it — beside it on both sides and in front."""
    rng = random.Random(seed)
    rack_w, d = 34, 6
    ml, mr = (12, 12) if sprawled else (0, 0)                         # floor room either side for the kicked-off
    w = ml + rack_w + mr
    tiers_rel = (2, 12, 22)                                           # shelf front rows above the floor contact
    h = tiers_rel[-1] + d + 10 + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    x0, x1 = ml + 1, ml + rack_w - 2
    tiers = [C - t for t in tiers_rel]
    if sprawled:
        ground(c, 1, w - 2, C - 5, C, 50)
    ground(c, x0, x1, C - d, C)
    wood = _rack_frame(c, x0, x1, C, d, tiers, metal)
    pool = RACK_SHOES[:]
    rng.shuffle(pool)
    # which slots show their pair heels-out: seeded, but always at least one of each on a rack
    backs = [rng.random() < 0.45 for _ in range(4)]
    if all(backs) or not any(backs):
        backs[rng.randrange(4)] = not backs[0]
    for ti, y in enumerate(tiers[:2]):                                # shoes on the two lower shelves
        for slot in range(2):
            if sprawled and (ti, slot) in ((0, 1), (1, 0)):
                continue                                              # gaps — those are on the floor
            style, col = pool.pop()
            if backs[ti * 2 + slot]:
                shoe_back_pair(c, x0 + 3 + slot * 15, y - 1, style, hexc(col))
            else:
                shoe_pair(c, x0 + 3 + slot * 15, y - 1, style, hexc(col), 1, depth_up=3)
    if metal:                                                         # a pair of boots on top, heels out
        shoe_back_pair(c, x0 + 5, tiers[2] - 1, 'boot', hexc('4a3526'))
    else:                                                             # slippers + a key dish on top
        shoe_pair(c, x0 + 3, tiers[2] - 1, 'kid', hexc('6a8ac8'), 1, depth_up=3)
        c.ellipse(x1 - 7, tiers[2] - 3, 4, 1, hexc('c8b89a'))
        c.put(x1 - 8, tiers[2] - 4, hexc('d8d8d0')); c.put(x1 - 6, tiers[2] - 4, hexc('c8a84a'))
    _rack_posts(c, x0, x1, C, d, tiers, wood, metal)
    if sprawled:                                                      # the ones that came off, all round it
        lying_shoe(c, 0, C - 7, 'trainer', hexc('d0603c'), 'side')                  # left, fallen over
        shoe_back(c, 6, C - 1, 'heel', hexc('d23a3a'))                              # left front, still standing
        lying_shoe(c, x0 + 10, C - 3, 'trainer', hexc('2a4a8a'), 'side')            # in front, on its side
        shoe_side(c, w - 3, C - 5, 'trainer', hexc('ffffff'), -1, 0.9)              # right, further back
        lying_shoe(c, w - 12, C - 3, 'brogue', hexc('1e1a18'), 'side')              # right front, fallen over
        lying_shoe(c, x0 + 3, tiers[1] - 5, 'trainer', hexc('3a3a3e'), 'sole')      # one hanging off a shelf
    save(name, c)
    record(name, "door", d, C)

def shoes(save, name, seed, boots=False):
    rng = random.Random(seed)
    col = rng.choice([hexc('3a2a22'), hexc('5a3a2a'), hexc('2a2a30'), hexc('7a2a2a')])
    d = 6
    w = 20
    h = (15 if boots else 7) + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 1, w - 2, C - d, C, 80)
    for (ox, back) in ((2, 2), (10, 0)):                            # the pair, one a little further back
        base = C - back
        if boots:
            c.rect(ox + 1, base - 13, ox + 5, base - 2, col)        # the shaft
            c.vline(ox + 5, base - 13, base - 2, shade(col, 0.7))
            c.ellipse(ox + 3, base - 13, 2, 1, shade(col, 0.35))    # its open top
            c.hline(ox + 1, ox + 5, base - 12, shade(col, 1.3))
        block(c, ox, ox + 7, base - 2, base, 3, col)                # the foot
        if not boots:
            c.rect(ox + 1, base - 4, ox + 3, base - 3, shade(col, 0.35))   # the opening at the heel
        c.hline(ox, ox + 7, base, hexc('1a1614'))                   # the sole
        c.put(ox + 6, base - 2, shade(col, 1.45))                   # a shine on the toe
    save(name, c)
    record(name, "door", d, C)


def umbrella_stand(save, name, seed, ceramic=False):
    rng = random.Random(seed)
    w, d = 18, 6
    h = 30 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ry = 3
    ground(c, 3, 14, C - d, C)
    brass = hexc('9a7a3a') if rng.random() < 0.5 else hexc('3a4a5a')
    top, bottom = C - 16, C - ry
    # the umbrellas go in first (the stand's rim is drawn over them)
    canopy = hexc('2a3a5a')
    c.poly([(7, top - 14), (10, top - 13), (10, top + 1), (6, top + 1)], canopy)   # a furled one, upright
    c.line(7, top - 14, 6, top + 1, shade(canopy, 1.35))
    c.vline(8, top - 18, top - 14, hexc('2a2622'))
    c.rect(8, top - 20, 10, top - 19, hexc('5a3a22')); c.put(11, top - 19, hexc('5a3a22')); c.put(11, top - 18, hexc('5a3a22'))
    stick = hexc('7a3a2a')                                          # a walking-stick umbrella, leant
    c.line(11, top + 1, 15, top - 12, stick)
    c.line(12, top + 1, 16, top - 12, shade(stick, 0.75))
    c.put(15, top - 13, hexc('2a2622')); c.put(14, top - 14, hexc('2a2622')); c.put(13, top - 14, hexc('2a2622'))
    if ceramic:                                                     # a tall glazed pot instead of the brass
        cylinder(c, 9, 5, top - 2, bottom, ry, hexc('e8e4dc'), inner=hexc('141210'))
        for yy in (top + 3, top + 9):
            c.hline(4, 14, yy, hexc('3a5a9a'))                      # its painted bands
            for x in range(5, 14, 3):
                c.put(x, yy + 1, hexc('3a5a9a'))
    else:
        cylinder(c, 9, 5, top, bottom, ry, brass, inner=hexc('141210'))
        c.rect(4, top + 1, 14, top + 2, shade(brass, 1.3))           # its collar
        for x in (6, 12):
            c.vline(x, top + 4, bottom, shade(brass, 0.82))
    save(name, c)
    record(name, "door", d, C)


def parcels(save, name, seed, style='stack'):
    rng = random.Random(seed)
    w, d = 26, 9
    h = 20 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    card, tape = hexc('b08858'), hexc('d8c898')
    ground(c, 1, w - 3, C - d, C)
    block(c, 1, 20, C - 10, C, d, card)                             # the big one, on the floor
    c.vline(10, C - 10 - d, C - 11, tape); c.vline(11, C - 10 - d, C - 11, tape)   # tape along its top...
    c.vline(10, C - 10, C - 1, tape)                                # ...and down the front
    c.rect(3, C - 7, 8, C - 4, hexc('eeeae0'))                       # the address label
    c.hline(4, 7, C - 6, hexc('6a6a6a')); c.hline(4, 6, C - 5, hexc('6a6a6a'))
    if style == 'env':                                              # a padded envelope left on top of it
        c.poly([(4, C - 16), (17, C - 17), (18, C - 13), (5, C - 12)], hexc('e0c870'))
        c.line(4, C - 16, 17, C - 17, shade(hexc('e0c870'), 1.2))
        c.rect(8, C - 15, 12, C - 14, hexc('eeeae0'))
    else:
        ox = 8 + rng.randrange(0, 4)                                # a smaller one stacked on it, set back
        top2 = C - 10 - 4
        block(c, ox, ox + 12, top2 - 6, top2, 5, shade(card, 1.08))
        c.hline(ox, ox + 12, top2 - 9, tape)
        c.rect(ox + 2, top2 - 4, ox + 6, top2 - 2, hexc('3a6ab8'))   # a courier's sticker
    save(name, c)
    record(name, "door", d, C)


def pram(save, name, seed, body_hex=None):
    rng = random.Random(seed)
    w, d = 34, 9
    h = 32 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    body = rng.choice([hexc('2a3a5a'), hexc('5a2a3a'), hexc('3a4a3a')]) if body_hex is None else hexc(body_hex)
    steel, tyre = hexc('8a8a8e'), hexc('1e1c1a')
    ground(c, 2, w - 3, C - d, C)
    fb = C - d + 3                                                  # the far wheels' contact (further back)
    for x in (8, 25):                                               # far wheels: higher, half hidden, dimmer
        c.ellipse(x, fb - 4, 4, 4, shade(tyre, 1.1))
        c.ellipse(x, fb - 4, 2, 2, shade(steel, 0.7))
    c.line(8, fb - 4, 25, fb - 4, shade(steel, 0.7))
    # the carrycot: a deep tub, its open top showing the blanket inside
    x0, x1, top, bottom = 4, 27, C - 22, C - 9
    c.rect(x0 + 1, top, x1 - 1, bottom, body)
    c.rect(x0, top + 1, x1, bottom - 2, body)
    c.hline(x0 + 2, x1 - 2, bottom, shade(body, 0.62))
    c.vline(x1, top + 1, bottom - 2, shade(body, 0.72))
    c.hline(x0, x1, top, shade(body, 1.35))                          # the rim
    c.rect(x0 + 1, top - 5, x1 - 1, top - 1, shade(body, 0.5))        # the inside, seen from above
    c.rect(x0 + 10, top - 4, x1 - 2, top - 2, hexc('e8d8c8'))          # a blanket
    c.hline(x0 + 10, x1 - 2, top - 4, hexc('f4ece0'))
    c.hline(x0 + 1, x1 - 1, top - 5, shade(body, 1.2))
    hood = shade(body, 0.9)                                         # the hood up over the head end: a half dome
    hx, hr = x0 + 7, 8
    for x in range(hx - hr, hx + hr + 1):
        k = (x - hx) / float(hr)
        top_y = top - 1 - int(round(10 * (1 - k * k) ** 0.5))
        c.vline(x, top_y, top - 1, shade(hood, 1.15 - 0.3 * abs(k + 0.3)))
    for rib in (0.45, 0.8):                                         # its folds
        for x in range(hx - int(hr * rib), hx + int(hr * rib) + 1):
            k = (x - hx) / float(hr * rib)
            c.put(x, top - 1 - int(round(10 * rib * (1 - k * k) ** 0.5)), shade(hood, 0.7))
    c.hline(hx - hr, hx + hr, top - 1, shade(hood, 0.55))           # its lower edge
    for x in (8, 25):                                               # near wheels
        c.ellipse(x, C - 4, 4, 4, tyre)
        c.ellipse(x, C - 4, 2, 2, steel)
        c.put(x, C - 4, hexc('d8d8dc'))
    c.line(8, C - 4, 14, bottom, steel); c.line(25, C - 4, 20, bottom, steel)   # the chassis
    c.line(x1, top + 2, x1 + 5, top - 9, steel)                       # the handle, to the far side's grip
    c.line(x1 + 5, top - 9, x1 + 2, top - 12, shade(steel, 0.8))
    c.rect(x1 + 2, top - 12, x1 + 6, top - 10, hexc('2a2a2a'))
    save(name, c)
    record(name, "door", d, C)


def bin_bags(save, name, seed, style='three'):
    rng = random.Random(seed)
    w, d = 32, 11
    h = 18 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 1, w - 2, C - d, C, 110)
    bag, bag_lt, bag_dk = hexc('1c1c20'), hexc('4a4a54'), hexc('0a0a0c')
    # back to front: a big one against the wall, then two in front of it
    bags = {'three': ((16, C - 7, 9, 9), (8, C, 7, 7), (23, C - 1, 8, 7)),
            'two': ((11, C - 5, 9, 9), (21, C, 7, 7)),
            'pizza': ((20, C - 4, 9, 9),)}[style]
    if style == 'pizza':                                            # pizza boxes leant against the wall by it
        for k in range(3):
            c.poly([(2 + k, C - 16 + k), (12 + k, C - 17 + k), (12 + k, C - 1), (2 + k, C)], shade(hexc('c8a878'), 1.0 - 0.08 * k))
        c.rect(5, C - 11, 9, C - 8, hexc('c83a2a'))
    for (cx, base, rx, ry) in bags:
        cy = base - ry
        c.ellipse(cx, cy, rx, ry, bag)
        c.ellipse(cx + 1, cy + 2, rx - 1, ry - 2, shade(bag, 0.8))  # its weight sags to the bottom
        c.line(cx - rx + 2, cy - 1, cx - 2, cy - ry + 2, bag_lt)    # a stretched highlight
        c.line(cx - rx + 3, cy, cx - 1, cy - ry + 3, shade(bag_lt, 0.8))
        c.line(cx + 2, cy + ry - 2, cx + rx - 2, cy + 1, bag_dk)    # a fold
        c.rect(cx - 1, cy - ry - 2, cx + 1, cy - ry, bag_dk)        # the knot
        c.put(cx - 2, cy - ry - 3, bag_lt); c.put(cx + 2, cy - ry - 3, bag_lt)   # its ears
        c.hline(cx - rx + 2, cx + rx - 2, base, bag_dk)
    for k in range(5):                                              # a split one: bits on the floor in front
        x = rng.randrange(22, 30)
        c.put(x, C + rng.randrange(-1, 1), rng.choice([hexc('d8d0c0'), hexc('8a6a3a'), hexc('6a8a4a')]))
    save(name, c)
    record(name, "door", d, C)


def recycling_box(save, name, seed, cardboard=False):
    rng = random.Random(seed)
    w, d = 26, 8
    h = 16 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    box = hexc('2a7a3a') if not cardboard else hexc('2a4a8a')
    ground(c, 1, w - 2, C - d, C)
    top = C - 8
    c.rect(2, top - d, w - 3, top - 1, hexc('0e1a10'))              # the open crate: its dark inside
    if cardboard:                                                   # flattened boxes stood up in it + cans
        for k in range(3):
            x = 4 + k * 6
            c.poly([(x, top - 1), (x + 7, top - 2), (x + 8, top - 14 + k * 2), (x + 1, top - 13 + k * 2)],
                   shade(hexc('b08858'), 1.0 - 0.1 * k))
        for k in range(3):
            c.rect(19 + k % 2 * 2, top - 3 - k, 20 + k % 2 * 2, top - 1 - k, hexc('b8c8c8'))
    for k in range(0 if cardboard else 6):                          # bottles + cans stood in it
        x = 4 + k * 3 + rng.randrange(0, 2)
        base = top - rng.randrange(1, d - 1)                        # at different depths in the crate
        tall = rng.randrange(6, 11)
        col = rng.choice([hexc('3a6a3a'), hexc('6a4a2a'), hexc('b8c8c8'), hexc('c83a2a'), hexc('d8d0b8')])
        c.rect(x, base - tall, x + 1, base, col)
        c.put(x, base - tall, shade(col, 1.4))
        if tall > 8:
            c.rect(x, base - tall - 2, x, base - tall - 1, shade(col, 0.7))     # a neck
    c.hline(2, w - 3, top - d, shade(box, 0.9))                     # the back wall of the crate
    block(c, 2, w - 3, top, C, 0, box, rim=True)                     # its front
    c.hline(2, w - 3, top, shade(box, 1.35))
    for x in range(5, w - 4, 4):
        c.rect(x, top + 2, x + 1, C - 3, shade(box, 0.7))           # the slots
    c.rect(w // 2 - 3, C - 3, w // 2 + 2, C - 2, hexc('e8e8e0'))     # the council's label
    c.vline(2, top - d, top, shade(box, 1.1)); c.vline(w - 3, top - d, top, shade(box, 0.7))   # its sides
    save(name, c)
    record(name, "door", d, C)


def suitcase(save, name, seed):
    rng = random.Random(seed)
    w, d = 18, 7
    h = 26 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    col = rng.choice([hexc('2a3a4a'), hexc('5a2a2a'), hexc('3a3a30'), hexc('7a6a52')])
    ground(c, 2, 15, C - d, C)
    block(c, 2, 15, C - 20, C - 1, d, col)
    for x in (5, 9, 12):                                            # its ribs
        c.vline(x, C - 18, C - 3, shade(col, 0.82))
    c.vline(7, C - 20 - d - 6, C - 20 - d + 3, hexc('8a8a90'))       # the pulled-up handle
    c.vline(11, C - 20 - d - 6, C - 20 - d + 3, hexc('8a8a90'))
    c.hline(7, 11, C - 20 - d - 6, hexc('2a2a2a'))
    for x in (3, 13):                                               # castors
        c.rect(x, C, x + 1, C, hexc('1a1a1a'))
    c.rect(3, C - 12, 6, C - 10, hexc('d8c890'))                     # a luggage tag
    save(name, c)
    record(name, "door", d, C)


def bike(save, name, seed, kid=False, down=False):
    """A bike leant on the wall beside a door, side on (its real outline), a kickstand and a shadow."""
    rng = random.Random(seed)
    r = 6 if kid else 9
    base = 28 if kid else 40
    d = 3
    w = base + 2 * r + 6
    frame = rng.choice([hexc('b83a32'), hexc('2e5a8a'), hexc('3a6a3a'), hexc('2a2a2e'), hexc('c8a032')])
    if kid:
        frame = rng.choice([hexc('d84a8a'), hexc('3a9ac8'), hexc('e0a020')])
    tyre, spoke, steel = hexc('1e1c1a'), hexc('9a9a9e'), hexc('b8b8bc')
    rx, fx = r + 2, r + 2 + base
    if down:                                                        # knocked over, lying on the floor
        d = 10
        h = 8 + d + SHADOW
        C = h - 1 - SHADOW
        c = new(w, h, seed)
        ground(c, 1, w - 2, C - d, C, 90)
        for hx, dy in ((rx, 0), (fx, -3)):                          # wheels flat on the floor: ellipses
            c.ellipse(hx, C - 4 + dy, r, 3, tyre)
            c.ellipse(hx, C - 4 + dy, r - 2, 1, shade(hexc('5a5654'), 0.8))
            c.hline(hx - r + 3, hx + r - 3, C - 4 + dy, spoke)
        c.line(rx, C - 5, fx, C - 8, frame); c.line(rx, C - 4, fx, C - 7, frame)
        c.line(rx + base // 3, C - 5, rx + base // 2, C - 10, frame)
        c.line(fx - 3, C - 8, fx + 4, C - 12, steel)                # the bars, twisted up off the floor
        c.rect(rx + base // 3 - 3, C - 12, rx + base // 3 + 2, C - 11, hexc('2a2622'))   # the saddle
        save(name, c)
        record(name, "door", d, C)
        return
    h = (24 if kid else 34) + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    y = C - r                                                       # the hubs
    ground(c, rx - r, fx + r, C - d, C, 85)
    for hx in (rx, fx):
        for a in range(0, 360, 4):
            t = math.radians(a)
            for rr in (r, r - 1):
                c.put(int(round(hx + rr * math.cos(t))), int(round(y + rr * math.sin(t))), tyre)
        for a in range(0, 360, 45):
            t = math.radians(a + (seed % 20))
            c.line(hx, y, int(round(hx + (r - 2) * math.cos(t))), int(round(y + (r - 2) * math.sin(t))), spoke)
        c.put(hx, y, steel)
    bb = (rx + int(base * 0.42), y + 1)
    seat = (rx + int(base * 0.33), y - int(r * 1.9))
    head = (fx - int(base * 0.14), y - int(r * 1.75))
    far = shade(frame, 0.55)
    c.line(bb[0] - 3, bb[1] - 3, bb[0] + 3, bb[1] + 3, far)          # the far crank + pedal, behind
    c.rect(bb[0] - 5, bb[1] - 4, bb[0] - 3, bb[1] - 4, hexc('1a1a1a'))
    c.line(rx, y, bb[0], bb[1], frame)
    c.line(rx, y, seat[0], seat[1] + 2, frame)
    for dx in (0, 1):
        c.line(bb[0] + dx, bb[1], seat[0] + dx, seat[1] + 2, frame)
        c.line(bb[0] + dx, bb[1], head[0] + dx, head[1] + 3, frame)
    c.line(seat[0], seat[1] + 3, head[0], head[1] + 1, frame)
    c.line(seat[0], seat[1] + 2, head[0], head[1], shade(frame, 1.25))
    c.line(head[0], head[1], fx, y, shade(frame, 0.8))
    c.line(head[0] + 1, head[1], fx + 1, y - 1, shade(frame, 0.8))
    c.ellipse(bb[0], bb[1], 2, 2, hexc('6a6a6e'))
    c.line(bb[0], bb[1], bb[0] - 2, bb[1] + 4, steel)                # the near crank + pedal
    c.rect(bb[0] - 4, bb[1] + 4, bb[0], bb[1] + 4, hexc('2a2a2a'))
    c.line(bb[0] - 4, bb[1] + 1, bb[0] - 9, C, shade(steel, 0.85))    # the kickstand, down to the floor
    c.line(seat[0], seat[1] + 2, seat[0] - 1, seat[1] - 1, steel)
    c.rect(seat[0] - 4, seat[1] - 2, seat[0] + 2, seat[1] - 1, hexc('2a2622'))
    c.line(head[0], head[1], head[0] - 1, head[1] - 4, steel)
    c.hline(head[0] - 3, head[0] + 1, head[1] - 4, hexc('2a2a2a'))
    c.put(head[0] - 1, head[1] - 5, shade(hexc('2a2a2a'), 1.6))      # the far grip, just showing
    if kid:
        c.put(head[0] - 3, head[1] - 3, hexc('e84a8a')); c.put(head[0] - 3, head[1] - 2, hexc('4ac8e8'))
    elif rng.random() < 0.5:
        c.rect(head[0] + 1, head[1] - 3, head[0] + 7, head[1] + 2, hexc('8a6a3a'))
        c.hline(head[0] + 1, head[0] + 7, head[1] - 3, hexc('aa8a5a'))
        c.vline(head[0] + 4, head[1] - 2, head[1] + 2, hexc('6a4a2a'))
    else:
        c.ellipse(seat[0] + 4, seat[1] + 5, 3, 2, hexc('e0c040'))
    save(name, c)
    record(name, "door", d, C)


# --- the open wall between the doors / by the lift ----------------------------------------------
def planter(save, name, seed, dead=False, fallen=False):
    """A big floor planter — the hotel's — its soil and a plant grown out of it."""
    rng = random.Random(seed)
    pot, rim = hexc('3a3a3e'), hexc('5a5a60')
    if seed % 2:
        pot, rim = hexc('a8573a'), hexc('c07050')
    leaf = [hexc('3e6a30'), hexc('4e7e3a'), hexc('2e5226')] if not dead else [hexc('7a6a3a'), hexc('8a7a44'), hexc('5a4a2a')]
    if fallen:                                                      # tipped over: on its side, soil spilled out
        w, d = 34, 12
        h = 12 + d + SHADOW
        C = h - 1 - SHADOW
        c = new(w, h, seed)
        ground(c, 1, w - 2, C - d, C, 90)
        c.rect(4, C - 12, 17, C - 2, pot)                            # its body, lying along the wall
        c.hline(4, 17, C - 12, shade(pot, 1.3))
        c.hline(4, 17, C - 2, shade(pot, 0.6))
        c.ellipse(18, C - 7, 3, 5, rim)                              # the mouth, facing along the floor
        c.ellipse(18, C - 7, 2, 4, hexc('2a1e16'))
        for k in range(60):                                          # the soil fanned out of it
            x = 20 + rng.randrange(0, 12)
            y = C - rng.randrange(0, 1 + max(1, 8 - (x - 20) // 2))
            c.put(x, y, rng.choice([hexc('3a2a1e'), hexc('4a3626'), hexc('2a1e16')]))
        for k in range(16):                                          # the plant, flat on the floor
            x, y = 20 + rng.randrange(0, 12), C - 8 + rng.randrange(0, 5)
            col = rng.choice(leaf)
            c.rect(x, y, x + 2, y, col)
        save(name, c)
        record(name, "open", d, C)
        return
    w, d = 24, 8
    h = 44 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ry = 4
    ground(c, 3, 20, C - d, C)
    top, bottom = C - 16, C - ry
    cylinder(c, 12, 8, top, bottom, ry, pot, inner=hexc('2a1e16'))
    c.ellipse(12, top, 8, ry, rim)
    c.ellipse(12, top, 7, ry - 1, hexc('3a2a1e'))                    # the soil
    stem = hexc('5a4a2a')
    for (x1, y1) in ((12, 4), (7, 12), (17, 10), (4, 20), (20, 18)):
        c.line(12, top, x1, y1, stem)
    for k in range(40 if not dead else 14):                         # foliage, heavier low, some over the rim
        x, y = rng.randrange(2, 22), rng.randrange(2, top + 2)
        if dead and y < 14:
            continue
        col = rng.choice(leaf)
        c.rect(x, y, x + 2, y + 1, col)
        c.put(x + 1, y - 1, shade(col, 1.2))
    if dead:
        for k in range(6):
            c.put(rng.randrange(4, 21), C + rng.randrange(-1, 1), hexc('7a6a3a'))   # dropped leaves
    save(name, c)
    record(name, "open", d, C)


def plant_stand(save, name, seed):
    """A small plant, up on a tall three-legged stand (owner: "put it on top of a high table or stool")."""
    rng = random.Random(seed)
    w, d = 18, 7
    h = 40 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    wood = hexc('5a3a26')
    ground(c, 3, 14, C - d, C, 80)
    ty = C - 24                                                     # the table top's centre row
    c.line(9, ty + 2, 9, C - d, shade(wood, 0.6))                    # the back leg (shorter, further back)
    c.line(5, ty + 2, 3, C, wood); c.line(13, ty + 2, 15, C, shade(wood, 0.8))   # the two front legs
    c.hline(5, 13, C - 9, shade(wood, 0.7))                         # a stretcher
    c.ellipse(9, ty, 7, 3, shade(wood, 1.25))                        # the round top
    c.hline(2, 16, ty + 1, shade(wood, 0.85))
    c.hline(3, 15, ty + 2, shade(wood, 0.65))
    potc = rng.choice([hexc('d8d0c0'), hexc('c07050'), hexc('3a6a7a')])
    cylinder(c, 9, 4, ty - 7, ty - 1, 2, potc, inner=hexc('3a2a1e'))
    for k in range(22):                                             # the plant
        x, y = rng.randrange(3, 16), rng.randrange(2, ty - 7)
        col = rng.choice([hexc('3e6a30'), hexc('5a8a40'), hexc('4e7e3a')])
        c.rect(x, y, x + 1, y, col)
        c.put(x, y + 1, shade(col, 0.8))
    for (x, y) in ((6, ty - 6), (13, ty - 5)):                       # trailing over the edge
        c.vline(x, y, y + 5, hexc('3e6a30'))
    save(name, c)
    record(name, "open", d, C)


def hall_chair(save, name, seed, down=False, spindle=False):
    """A hall chair against the wall — somewhere to wait for the lift."""
    wood, dk = hexc('7a5236'), hexc('4e321e')
    seat_c = hexc('8a3a3a') if seed % 2 else hexc('3a5a4a')
    if spindle:
        seat_c = shade(wood, 1.15)
    if down:
        return chair_fallen(save, name, seed, wood, dk, seat_c)
    w, d = 20, 9
    h = 30 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 2, 17, C - d, C)
    seat_y = C - 11
    for x in (3, 16):                                               # back legs, standing further back
        c.vline(x, seat_y, C - d, shade(dk, 0.8))
    if spindle:                                                     # a spindle back: a rail and uprights
        c.rect(3, seat_y - d - 14, 16, seat_y - d - 12, wood)
        for x in (3, 6, 9, 12, 16):
            c.vline(x, seat_y - d - 12, seat_y - d, wood if x in (3, 16) else shade(wood, 0.85))
    else:
        c.rect(3, seat_y - d - 14, 16, seat_y - d, wood)             # the chair back, against the wall
        c.rect(5, seat_y - d - 12, 14, seat_y - d - 2, seat_c)       # its padded panel
    c.hline(3, 16, seat_y - d - 14, shade(wood, 1.3))
    block(c, 2, 17, seat_y, seat_y + 2, d, wood, seat_c)             # the seat (padded top)
    c.hline(3, 16, seat_y - d + 1, shade(seat_c, 1.25))
    for x in (2, 17):                                               # front legs
        c.vline(x, seat_y + 2, C, dk)
    c.hline(3, 16, C - 4, shade(dk, 0.9))                           # a stretcher
    save(name, c)
    record(name, "open", d, C)



# --- ROUND 24e: variants, trays, tables, a knocked-over stand, a wrecked bike ---------------------
# (owner: "either they shouldn't be on the floor, and should be on a desk or table or something outside the
# apartment door or could have variants… the plant pot on the table… one where the plant has been knocked
# over… the bicycle on its side… looks kind of deflated")
def trainer(c, x, base, col, kid=False):
    """A shoe side-on: a pale sole, a low toe, the heel higher with its collar open."""
    ln = 6 if kid else 8
    sole = hexc('e8e4dc')
    c.hline(x, x + ln - 1, base, sole)
    c.rect(x, base - 2, x + ln - 1, base - 1, col)                   # the upper
    c.rect(x, base - 3, x + ln // 2, base - 3, col)                  # the heel, higher
    c.put(x + 1, base - 3, shade(col, 0.35))                         # the collar, open
    c.put(x + 2, base - 3, shade(col, 0.35))
    c.put(x + ln - 1, base - 2, shade(col, 0.8))                     # the rounded toe
    for k in range(ln // 2 - 1):                                     # laces
        c.put(x + ln // 2 + k, base - 2, shade(col, 1.6))
    c.put(x, base - 1, shade(col, 0.7))


def welly(c, x, base, col):
    c.rect(x + 1, base - 11, x + 4, base - 2, col)                  # the shaft
    c.vline(x + 1, base - 11, base - 2, shade(col, 1.3))
    c.vline(x + 4, base - 11, base - 2, shade(col, 0.7))
    c.hline(x + 1, x + 4, base - 11, shade(col, 0.35))               # its open top
    c.rect(x, base - 2, x + 7, base - 1, col)                        # the foot
    c.hline(x, x + 7, base, hexc('1a1614'))
    for k in range(3):                                               # mud
        c.put(x + 1 + k * 2, base - 1 - (k % 2), hexc('5a4a32'))


def table_top_items(c, rng, kind, x0, x1, ty, d):
    """Things stood on a table's top face (rows ty-d .. ty-1): back ones higher, front ones lower."""
    back, front = ty - d + 2, ty - 1
    if kind == 'flowers':
        vx = x0 + 6
        cylinder(c, vx, 2, back - 7, back - 1, 1, hexc('b8c8c8'), inner=hexc('3a5a5a'))    # a glass vase
        for k in range(7):                                           # the flowers
            fx, fy = vx + rng.randrange(-4, 5), back - 9 - rng.randrange(0, 6)
            c.line(vx, back - 7, fx, fy, hexc('4a6a34'))
            c.rect(fx, fy - 1, fx + 1, fy, rng.choice([hexc('e8d8e8'), hexc('d84a5a'), hexc('e8c84a')]))
        for k in range(3):                                           # letters, fanned out in front
            c.rect(x1 - 12 + k, front - 2 + k % 2, x1 - 5 + k, front - 1 + k % 2, hexc('eeeae0') if k != 1 else hexc('d8c8a8'))
    elif kind == 'lamp':
        lx = x0 + 6
        cylinder(c, lx, 2, back - 2, back - 1, 1, hexc('3a3a3e'))    # a small lamp (off)
        c.vline(lx, back - 9, back - 2, hexc('8a7a5a'))
        c.poly([(lx - 3, back - 9), (lx + 3, back - 9), (lx + 4, back - 14), (lx - 4, back - 14)], hexc('d8ccb0'))
        c.hline(lx - 4, lx + 4, back - 14, shade(hexc('d8ccb0'), 1.1))
        c.ellipse(x1 - 8, front - 1, 4, 1, hexc('6a5a4a'))           # a bowl, keys in it
        c.hline(x1 - 11, x1 - 5, front - 2, shade(hexc('6a5a4a'), 1.3))
        c.put(x1 - 9, front - 2, hexc('e0c040')); c.put(x1 - 8, front - 2, hexc('b8b8bc'))
    else:                                                            # a pot plant + the post
        px = x1 - 7
        cylinder(c, px, 3, back - 5, back - 1, 1, hexc('c07050'), inner=hexc('3a2a1e'))
        for k in range(14):
            lx, ly = px + rng.randrange(-5, 6), back - 6 - rng.randrange(0, 8)
            c.rect(lx, ly, lx + 1, ly, rng.choice([hexc('3e6a30'), hexc('5a8a40'), hexc('4e7e3a')]))
        for k in range(3):
            c.rect(x0 + 3 + k, front - 2 - k, x0 + 11 + k, front - 1 - k, [hexc('eeeae0'), hexc('d8c8a8'), hexc('e8e0f0')][k])


def hall_table(save, name, seed, kind='flowers'):
    """A slim console table by the door — the things that shouldn't sit on the floor sit on it."""
    rng = random.Random(seed)
    w, d = 30, 7
    h = 40 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    wood = rng.choice([hexc('5a3a26'), hexc('7a5236'), hexc('3a2a22')])
    ground(c, 1, w - 2, C - d, C, 85)
    ty = C - 20                                                      # the table top's front edge
    for x in (4, w - 5):                                             # back legs (further back, shorter)
        c.vline(x, ty + 2, C - d, shade(wood, 0.6))
    block(c, 1, w - 2, ty, ty + 1, d, wood, shade(wood, 1.2))        # the top
    c.rect(2, ty + 2, w - 3, ty + 5, shade(wood, 0.9))               # the apron, a drawer
    c.hline(2, w - 3, ty + 5, shade(wood, 0.6))
    c.rect(w // 2 - 1, ty + 3, w // 2, ty + 3, hexc('c8a050'))       # its knob
    for x in (2, w - 3):                                             # front legs, tapering
        c.rect(x, ty + 6, x + 1, C - 6, shade(wood, 0.85))
        c.vline(x, C - 5, C, shade(wood, 0.85))
    table_top_items(c, rng, kind, 1, w - 2, ty, d)
    save(name, c)
    record(name, "door", d, C)


def plant_stand_fallen(save, name, seed):
    """The plant on its stand, KNOCKED OVER: the stand still up, the pot cracked on the floor in front,
    a short trail of soil between them, the plant dead on the floor."""
    rng = random.Random(seed)
    w, d = 34, 11
    h = 40 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    wood = hexc('5a3a26')
    ground(c, 2, w - 2, C - d, C, 85)
    ty = C - 24                                                      # the stand, as it was, empty now
    c.line(9, ty + 2, 9, C - d, shade(wood, 0.6))
    c.line(5, ty + 2, 3, C - 3, wood); c.line(13, ty + 2, 15, C - 3, shade(wood, 0.8))
    c.hline(5, 13, C - 12, shade(wood, 0.7))
    c.ellipse(9, ty, 7, 3, shade(wood, 1.25))
    c.hline(2, 16, ty + 1, shade(wood, 0.85))
    c.hline(3, 15, ty + 2, shade(wood, 0.65))
    c.ellipse(9, ty - 1, 3, 1, hexc('3a2a1e'))                       # a ring of soil where it stood
    soil = [hexc('3a2a1e'), hexc('4a3626'), hexc('2a1e16')]
    for k in range(45):                                              # the trail, from the stand to the pot
        t = rng.random()
        x = int(10 + t * 14 + rng.uniform(-1.5, 1.5))
        y = int(C - 2 - t * 3 + rng.uniform(-1.5, 1.5))
        c.put(x, y, rng.choice(soil))
    potc = hexc('c07050')
    c.rect(22, C - 7, 29, C - 2, potc)                               # the pot on its side
    c.hline(22, 29, C - 7, shade(potc, 1.25))
    c.hline(22, 29, C - 2, shade(potc, 0.6))
    c.ellipse(21, C - 4, 2, 3, shade(potc, 1.1))                     # its mouth, facing back up the trail
    c.ellipse(21, C - 4, 1, 2, hexc('2a1e16'))
    c.line(25, C - 7, 27, C - 4, shade(potc, 0.45)); c.line(27, C - 4, 26, C - 2, shade(potc, 0.45))   # cracked
    c.rect(30, C - 2, 31, C - 1, shade(potc, 0.9))                   # a shard
    dead = [hexc('7a6a3a'), hexc('8a7a44'), hexc('5a4a2a')]
    for k in range(14):                                              # the plant, dead on the floor
        x, y = 14 + rng.randrange(0, 9), C - 5 + rng.randrange(0, 4)
        c.rect(x, y, x + 1, y, rng.choice(dead))
    c.line(15, C - 3, 21, C - 4, hexc('5a4a2a'))                    # its stems, still in the pot
    save(name, c)
    record(name, "open", d, C)


def snake_plant(save, name, seed, dead=False):
    rng = random.Random(seed)
    w, d = 22, 8
    h = 40 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    pot = rng.choice([hexc('e8e4dc'), hexc('3a3a3e'), hexc('7a8a8a')])
    ground(c, 3, 18, C - d, C)
    top, bottom = C - 14, C - 3
    for k in range(8):                                               # sword leaves, from the soil up
        x = 5 + k * 2 + rng.randrange(-1, 2)
        tall = rng.randrange(14, 28) if not dead else rng.randrange(6, 14)
        lean = rng.choice((-1, 0, 0, 1))
        green = hexc('2e5a2a') if not dead else hexc('7a6a3a')
        edge = hexc('c8c85a') if not dead else hexc('5a4a2a')
        for yy in range(tall):
            xx = x + int(lean * yy / 10.0)
            wd = 2 if yy < tall - 3 else 1
            c.rect(xx, top - yy, xx + wd - 1, top - yy, green if (yy // 3) % 2 else shade(green, 1.18))
            c.put(xx + wd, top - yy, edge)
        if dead:
            c.line(x, top, x + 4 * lean + 3, top + 2, hexc('6a5a32'))    # one folded over the rim
    cylinder(c, 11, 7, top, bottom, 3, pot, inner=hexc('2a1e16'))
    save(name, c)
    record(name, "open", d, C)


def palm(save, name, seed):
    rng = random.Random(seed)
    w, d = 30, 8
    h = 42 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    pot = rng.choice([hexc('a8573a'), hexc('3a3a3e'), hexc('b8a888')])
    ground(c, 6, 23, C - d, C)
    top, bottom = C - 13, C - 3
    cx = 15
    for k in range(9):                                               # fronds, arcing out and down
        ang = math.radians(-160 + k * 17.5)
        ln = rng.uniform(12, 17)
        pts = []
        for t in range(0, 11):
            tt = t / 10.0
            fx = cx + math.cos(ang) * ln * tt
            fy = top - 6 + math.sin(ang) * ln * tt + 7 * tt * tt
            pts.append((int(round(fx)), int(round(fy))))
        for (a, b) in zip(pts, pts[1:]):
            c.line(a[0], a[1], b[0], b[1], hexc('3a5a2a'))
        for (px, py) in pts[2::2]:                                   # its leaflets
            c.put(px, py + 1, hexc('4e7e3a')); c.put(px + 1, py + 1, hexc('4e7e3a'))
            c.put(px - 1, py - 1, hexc('5a8a40'))
    c.vline(cx, top - 6, top, hexc('5a4a2a'))
    cylinder(c, cx, 8, top, bottom, 3, pot, inner=hexc('2a1e16'))
    save(name, c)
    record(name, "open", d, C)


def holdall(save, name, seed):
    rng = random.Random(seed)
    w, d = 26, 8
    h = 10 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    col = rng.choice([hexc('2a3a2a'), hexc('3a2a2a'), hexc('2a2a3a')])
    ground(c, 1, w - 2, C - d, C)
    c.ellipse(13, C - 7, 11, 6, shade(col, 1.1))                     # the soft body, lying down
    c.rect(3, C - 8, 23, C - 1, col)
    c.ellipse(13, C - 1, 10, 1, shade(col, 0.6))
    c.hline(5, 21, C - 11, shade(col, 1.45))                        # its top, the zip along it
    for x in range(6, 21, 2):
        c.put(x, C - 10, hexc('b8b8bc'))
    c.line(9, C - 11, 11, C - 15, hexc('1a1a1a')); c.line(11, C - 15, 15, C - 15, hexc('1a1a1a'))   # handles
    c.line(15, C - 15, 17, C - 11, hexc('1a1a1a'))
    c.rect(4, C - 6, 7, C - 3, shade(col, 0.8))                      # an end pocket
    save(name, c)
    record(name, "door", d, C)


# --- ROUND 25c: the props that failed "recognise it instantly" at true size, redrawn bigger + clearer ---
def shoe_tray(save, name, seed, kind='shoes'):
    """A rubber boot tray by the door — a LOW dark plate so the shoes carry it (side-on / heels-out pairs)."""
    rng = random.Random(seed)
    w, d = 38, 6
    tall = 12 if kind == 'boots' else 7
    h = tall + d + SHADOW + 2
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    rubber = hexc('222226')
    ground(c, 1, w - 2, C - d, C, 90)
    for r in range(d):                                               # the tray's floor, seen from above
        c.hline(1, w - 2, C - d + r, shade(rubber, 0.9 + 0.12 * r / d))
    c.hline(1, w - 2, C - d, shade(rubber, 1.9))                     # the raised back lip, catching light
    c.hline(1, w - 2, C, shade(rubber, 1.5))                         # the front lip
    c.vline(1, C - d, C, shade(rubber, 1.7)); c.vline(w - 2, C - d, C, shade(rubber, 1.5))
    for x in range(6, w - 5, 5):                                     # a few drainage slots
        c.hline(x, x + 2, C - 2, shade(rubber, 0.5))
    cols = ['ffffff', '2a4a8a', '8a5a3a', 'c8c0b0', 'd83a3a', '3a7a4a']
    base = C - 1                                                     # shoes stand on the tray's floor
    if kind == 'boots':
        col = hexc(rng.choice(['2a5a2a', '2a2a30', 'a83030', 'e0c030']))
        welly(c, 4, base - 3, shade(col, 0.85))                      # the far one
        welly(c, 13, base, col)
        shoe_side(c, 24, base - 1, 'kid', hexc('e05a8a'), 1)
        shoe_side(c, 24, base - 4, 'kid', hexc('e05a8a'), 1, 0.8)
    elif kind == 'family':
        shoe_pair(c, 3, base, 'trainer', hexc(rng.choice(cols)), 1, depth_up=2)
        shoe_back_pair(c, 20, base, 'brogue', hexc('5a3322'), depth_up=2)
        shoe_side(c, 28, base - 1, 'kid', hexc('e05a8a'), 1)
    else:
        shoe_pair(c, 3, base, 'trainer', hexc(rng.choice(cols)), 1, depth_up=2)
        shoe_back_pair(c, 22, base, 'heel', hexc(rng.choice(cols[3:])), depth_up=2)
    save(name, c)
    record(name, "door", d, C)


def chair_fallen(save, name, seed, wood, dk, seat_c):
    """A hall chair knocked onto its side: the back lying on the floor to the left, the seat standing on
    its edge, four legs sticking out along the floor to the right."""
    wood = shade(wood, 1.25)
    w, d = 38, 12
    h = 22 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 1, w - 2, C - d, C, 95)
    # the backrest: a frame lying flat, its padded panel facing up at us (a slab seen from above)
    for r in range(d):
        y = C - d + r
        c.hline(2, 15, y, shade(wood, 0.8 + 0.25 * r / d))
    c.rect(4, C - d + 2, 13, C - 3, seat_c)                          # the padded panel
    c.hline(4, 13, C - d + 2, shade(seat_c, 1.4))
    c.hline(2, 15, C - d, shade(wood, 1.5))                          # the top rail's lit edge
    c.hline(2, 15, C - 1, shade(wood, 0.5)); c.hline(2, 15, C, shade(wood, 0.4))
    c.vline(2, C - d, C, shade(wood, 1.3)); c.vline(15, C - d, C, shade(wood, 0.6))
    # the seat: standing on its edge, with its cushion facing left toward the back
    c.rect(15, C - 19, 19, C - 1, wood)
    c.rect(15, C - 19, 16, C - 1, shade(seat_c, 1.0))               # the cushion side
    c.vline(19, C - 19, C - 1, shade(wood, 0.6))
    c.hline(15, 19, C - 19, shade(wood, 1.5))
    # the near legs (front of the chair) and the far legs (behind, darker, higher on the floor plane)
    for yl, k in ((C - 3, 1.0), (C - 16, 1.0)):
        c.rect(20, yl - 1, 34, yl, shade(wood, 1.0 * k))              # a leg: a lit top face over a dark side
        c.hline(20, 34, yl - 1, shade(wood, 1.45))
        c.hline(20, 34, yl + 1, shade(dk, 0.7))
        c.rect(34, yl - 1, 35, yl + 1, shade(dk, 0.6))                # the foot
    for yl in (C - 8, C - 12):
        c.hline(21, 32, yl, shade(dk, 0.95))                          # the far pair, behind
    c.vline(27, C - 15, C - 3, shade(wood, 0.75))                    # a stretcher between the legs
    save(name, c)
    record(name, "open", d, C)


def newspapers(save, name, seed):
    """A bundle of old newspapers tied with string, put out by the door: a real STACK with height."""
    rng = random.Random(seed)
    w, d = 26, 8
    stack = 15
    h = stack + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 1, w - 2, C - d, C)
    paper = hexc('e2dcc8')
    block(c, 2, 22, C - stack, C, d, shade(paper, 0.85), shade(paper, 1.1))
    for y in range(C - stack + 1, C, 2):                             # the edges of each folded paper
        c.hline(2, 22, y, shade(paper, 0.7))
    c.vline(2, C - stack, C, shade(paper, 1.15))
    for x in (8, 15):                                                # the string, over the top and down the front
        c.vline(x, C - stack - d, C, hexc('a8763a'))
        c.put(x, C - stack - d + 2, hexc('c8965a'))
    c.hline(2, 22, C - stack - d + 1, shade(paper, 0.8))
    # the front paper's page-one: a masthead, a photo, columns
    c.rect(4, C - stack + 2, 21, C - stack + 3, hexc('2a2a2a'))       # a black masthead
    c.rect(4, C - stack + 5, 11, C - stack + 10, hexc('8a8a86'))      # the photo
    c.rect(5, C - stack + 6, 10, C - stack + 9, hexc('6a6a68'))
    for y in range(C - stack + 5, C - stack + 11, 2):
        c.hline(12, 20, y, hexc('7a7a76'))                            # the columns of print
    c.hline(4, 20, C - stack + 12, hexc('3a3a3a'))                    # a headline
    save(name, c)
    record(name, "door", d, C)


def shopping_bag(save, name, seed):
    """A brown paper shopping bag, folded top, a baguette and greens sticking out."""
    rng = random.Random(seed)
    w, d = 22, 7
    h = 34 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    paper = hexc('c09a66')
    ground(c, 2, w - 3, C - d, C, 85)
    top = C - 20
    c.line(6, top - 1, 4, top - 8, hexc('e6c98a')); c.line(7, top - 1, 5, top - 8, hexc('e6c98a'))    # a baguette
    c.line(8, top - 1, 6, top - 8, shade(hexc('e6c98a'), 0.8))
    c.put(5, top - 6, hexc('b8863a')); c.put(6, top - 4, hexc('b8863a'))                          # its scoring
    for (x, y, k) in ((12, top - 6, 1.0), (14, top - 8, 0.9), (16, top - 5, 1.1)):               # leek / greens
        c.rect(x, y, x + 2, top - 1, shade(hexc('4a9a3a'), k))
        c.hline(x, x + 2, y, hexc('7acc5a'))
    c.rect(9, top - 7, 12, top - 1, hexc('f2f2ea'))                                               # a milk carton
    c.rect(9, top - 7, 12, top - 6, hexc('4a7ac8'))
    block(c, 3, 18, top, C, d, paper, shade(paper, 1.2))                                         # the bag body + its open top
    c.rect(4, top - d + 1, 17, top - 1, shade(paper, 0.4))                                       # dark inside the mouth
    c.hline(3, 18, top, shade(paper, 1.45))
    c.vline(10, top + 1, C - 1, shade(paper, 0.82))                                              # the gusset fold down the front
    c.rect(6, top + 5, 15, top + 12, hexc('c83a2a'))                                             # the shop's logo panel
    c.rect(8, top + 7, 13, top + 8, hexc('f2e8d0')); c.rect(8, top + 10, 11, top + 10, hexc('f2e8d0'))
    c.line(6, top + 1, 8, top - 6, hexc('8a6a3a')); c.line(8, top - 6, 10, top + 1, hexc('8a6a3a'))  # a rope handle
    save(name, c)
    record(name, "door", d, C)


def carrier_bags(save, name, seed):
    """Two plastic carrier bags slumped against each other, knotted handles, groceries bulging."""
    w, d = 26, 6
    h = 26 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 2, w - 3, C - d, C, 80)
    for (x0, x1, col, top) in ((2, 13, 'f2f2ee', C - 20), (12, 23, '3a6ac8', C - 17)):
        base = hexc(col)
        body = [(x0 + 1, top + 4), (x0 + 5, top), (x1 - 5, top), (x1 - 1, top + 4), (x1, C - 3), (x1 - 3, C),
                (x0 + 3, C), (x0, C - 3)]
        c.poly(body, base)
        for y in range(top + 5, C - 1):
            c.put(x0 + 1 + (y % 3), y, shade(base, 1.08 if col != 'f2f2ee' else 0.9))              # crinkles
        c.vline(x1 - 1, top + 6, C - 2, shade(base, 0.7))
        c.hline(x0 + 5, x1 - 5, top, shade(base, 0.6))
        c.line(x0 + 4, top, x0 + 6, top - 5, shade(base, 0.6)); c.line(x1 - 4, top, x1 - 6, top - 5, shade(base, 0.6))
        c.put(x0 + (x1 - x0) // 2, top - 5, shade(base, 0.5))                                        # the knot
    c.rect(5, C - 14, 9, C - 9, hexc('d8483a')); c.rect(15, C - 11, 19, C - 6, hexc('e8b83a'))       # things inside
    save(name, c)
    record(name, "door", d, C)


def scooter(save, name, seed):
    """A kick scooter leant by the door: chunky deck, two wheels, a tall stem and bars — sized to read."""
    w, d = 34, 5
    h = 38 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    deck = random.Random(seed).choice([hexc('d83a4a'), hexc('3a8ad8'), hexc('8ad83a')])
    ground(c, 2, w - 3, C - d, C, 85)
    for x, r in ((6, 4), (27, 4)):                                   # the wheels: tyre, hub, highlight
        c.ellipse(x, C - r, r, r, hexc('1e1c1a'))
        c.ellipse(x, C - r, r - 2, r - 2, hexc('8a8a90'))
        c.put(x, C - r, hexc('d8d8dc')); c.put(x - 1, C - r - 2, hexc('4a4a4e'))
    block(c, 7, 27, C - 7, C - 5, d - 1, deck, shade(deck, 1.3))     # the deck, seen with its top face
    c.hline(7, 27, C - 5, shade(deck, 0.55))
    for x in range(9, 26, 3):
        c.put(x, C - 8, shade(deck, 1.5))                             # the grip tape's dots
    c.rect(27, C - 11, 29, C - 5, hexc('b0b0b6'))                     # the fork over the front wheel
    c.line(28, C - 11, 26, C - 36, hexc('9a9aa2')); c.line(29, C - 11, 27, C - 36, hexc('6a6a72'))   # the stem
    c.line(29, C - 11, 27, C - 36, hexc('6a6a72'))
    c.hline(20, 32, C - 37, hexc('2a2a2e')); c.hline(20, 32, C - 36, hexc('4a4a50'))                 # the handlebars
    c.rect(18, C - 38, 21, C - 36, hexc('d84a8a')); c.rect(31, C - 38, 33, C - 36, hexc('d84a8a'))    # the grips
    c.rect(6, C - 9, 8, C - 6, hexc('b0b0b6'))                        # the rear brake over the wheel
    save(name, c)
    record(name, "door", d, C)


def bike_wrecked(save, name, seed):
    """A bike that's been wrecked: the FRONT WHEEL wrenched off and lying flat on the floor, the frame
    snapped and slumped forward onto it, the rear wheel taco'd (a wedge bent out), bars hanging, saddle askew."""
    rng = random.Random(seed)
    r, base, d = 9, 40, 9
    w = base + 2 * r + 8
    h = 26 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    frame = rng.choice([hexc('b83a32'), hexc('2e5a8a'), hexc('3a6a3a'), hexc('c8a032')])
    tyre, spoke, steel = hexc('1e1c1a'), hexc('9a9a9e'), hexc('b8b8bc')
    rx = r + 2
    ground(c, 1, w - 2, C - d, C, 95)
    y = C - r
    # the REAR wheel, upright but buckled: a wedge of the tyre bent outward + missing spokes
    for a in range(0, 360, 4):
        t = math.radians(a)
        rr = r if not (200 < a < 260) else r - 3                     # the dent
        for k in (rr, rr - 1):
            c.put(int(round(rx + k * math.cos(t))), int(round(y + k * math.sin(t))), tyre)
    for a in range(0, 360, 40):
        if 190 < a < 270:
            continue                                                  # spokes gone where it's crushed
        t = math.radians(a)
        c.line(rx, y, int(round(rx + (r - 2) * math.cos(t))), int(round(y + (r - 2) * math.sin(t))), spoke)
    c.put(rx, y, steel)
    # the frame: seat tube up from the rear, the top tube SNAPPED and drooping to the floor
    bb = (rx + 16, y + 1)
    seat = (rx + 13, y - 15)
    c.line(rx, y, bb[0], bb[1], frame); c.line(rx, y, seat[0], seat[1] + 2, frame)
    c.line(bb[0], bb[1], seat[0] + 1, seat[1] + 2, frame); c.line(bb[0] + 1, bb[1], seat[0] + 2, seat[1] + 2, frame)
    c.line(seat[0], seat[1] + 2, seat[0] + 12, C - 6, frame)          # the top tube, buckled downward
    c.line(seat[0], seat[1] + 3, seat[0] + 12, C - 5, shade(frame, 0.7))
    c.line(bb[0], bb[1], bb[0] + 14, C - 4, shade(frame, 0.85))       # the down tube, dragging on the floor
    c.line(bb[0] - 4, bb[1] + 1, bb[0] - 9, C, shade(steel, 0.85))    # the kickstand, still down
    # the saddle, torn askew off its post
    c.line(seat[0], seat[1] + 2, seat[0] - 2, seat[1] - 1, steel)
    c.rect(seat[0] - 6, seat[1] - 3, seat[0] + 1, seat[1] - 1, hexc('2a2622'))
    c.put(seat[0] - 5, seat[1] - 3, hexc('4a423a'))
    # the FRONT wheel: torn off, lying flat on the floor in front, rim kinked, tyre half off
    fx = w - r - 4
    c.ellipse(fx, C - 4, r, 3, tyre)
    c.ellipse(fx, C - 4, r - 2, 2, shade(hexc('5a5654'), 0.85))
    c.hline(fx - r + 3, fx + r - 3, C - 4, spoke); c.vline(fx, C - 6, C - 2, spoke)
    c.hline(fx + 2, fx + r + 1, C - 2, hexc('0e0c0a'))                # the tyre peeled off the rim
    c.put(fx + r + 1, C - 1, tyre)
    # the fork and bars, twisted, lying across the wheel; the chain hanging from the crank
    c.line(seat[0] + 12, C - 6, fx - 2, C - 9, steel)
    c.line(fx - 2, C - 9, fx + 6, C - 12, steel)
    c.hline(fx + 3, fx + 9, C - 12, hexc('2a2a2a')); c.put(fx + 9, C - 13, hexc('4a4a4e'))
    for k in range(5):
        c.put(bb[0] + 2 + k, bb[1] + 4 + (k % 2), hexc('4a4a4e'))    # the chain
    save(name, c)
    record(name, "door", d, C)



def build(save):
    """Every standing prop (base names are the catalogue keys in scripts/corridor_decals.gd; `__N` are
    that prop's variants — the game picks one per placement)."""
    shoe_rack(save, 'shoe_rack', 57)
    shoe_rack(save, 'shoe_rack__2', 157, metal=True)
    shoe_rack(save, 'shoe_rack__3', 257, sprawled=True)
    shoe_tray(save, 'shoe_tray', 55, 'shoes')
    shoe_tray(save, 'shoe_tray__2', 56, 'boots')
    shoe_tray(save, 'shoe_tray__3', 155, 'family')
    umbrella_stand(save, 'umbrella_stand', 54)
    umbrella_stand(save, 'umbrella_stand__2', 154, ceramic=True)
    hall_table(save, 'hall_table', 90, 'flowers')
    hall_table(save, 'hall_table__2', 91, 'lamp')
    hall_table(save, 'hall_table__3', 92, 'post')
    parcels(save, 'parcels', 58)
    parcels(save, 'parcels__2', 158, 'env')
    pram(save, 'pram', 85)
    pram(save, 'pram__2', 185, body_hex='6a3a4a')
    bin_bags(save, 'bin_bags', 82)
    bin_bags(save, 'bin_bags__2', 182, 'two')
    bin_bags(save, 'bin_bags__3', 282, 'pizza')
    recycling_box(save, 'recycling_box', 83)
    recycling_box(save, 'recycling_box__2', 183, cardboard=True)
    newspapers(save, 'newspapers', 86)
    suitcase(save, 'suitcase', 62)
    suitcase(save, 'suitcase__2', 162)
    holdall(save, 'suitcase__3', 262)
    shopping_bag(save, 'shopping_bag', 63)
    carrier_bags(save, 'shopping_bag__2', 163)
    bike(save, 'bicycle', 80)
    bike(save, 'bicycle__2', 180)
    bike_wrecked(save, 'bicycle_wrecked', 80)
    bike_wrecked(save, 'bicycle_wrecked__2', 180)
    bike(save, 'kids_bike', 81, kid=True)
    bike(save, 'kids_bike__2', 181, kid=True)
    scooter(save, 'scooter', 61)
    scooter(save, 'scooter__2', 161)
    planter(save, 'plant_tall', 50)
    snake_plant(save, 'plant_tall__2', 150)
    palm(save, 'plant_tall__3', 250)
    planter(save, 'plant_dead', 51, dead=True)
    snake_plant(save, 'plant_dead__2', 151, dead=True)
    planter(save, 'plant_fallen', 52, fallen=True)
    plant_stand(save, 'plant_stand', 53)
    plant_stand(save, 'plant_stand__2', 153)
    plant_stand_fallen(save, 'plant_stand_fallen', 53)
    plant_stand_fallen(save, 'plant_stand_fallen__2', 153)
    hall_chair(save, 'chair', 59)
    hall_chair(save, 'chair__2', 159, spindle=True)
    hall_chair(save, 'chair_down', 60, down=True)
    return META
