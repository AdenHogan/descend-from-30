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
    META[name] = {"rule": rule, "depth": depth, "contact": contact}


# --- by the door --------------------------------------------------------------------------------
def shoe_rack(save, name, seed):
    rng = random.Random(seed)
    w, d = 30, 7
    h = 24 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    wood = hexc('8a6444')
    ground(c, 1, w - 2, C - d, C)
    for x in (2, w - 3):                                            # the back posts (behind, darker)
        c.vline(x, C - d - 20, C - d, shade(wood, 0.62))
    for (y, lvl) in ((C - 1, 0), (C - 10, 1), (C - 19, 2)):         # three shelves, each a slatted plank
        block(c, 1, w - 2, y, y + 1, d, wood, shade(wood, 1.15))
        for x in range(4, w - 3, 3):                                # slats on the shelf top
            c.vline(x, y - d + 1, y - 1, shade(wood, 0.95))
        if lvl < 2:                                                 # shoes on it: small shoes with open heels
            x = 4
            while x < w - 9:
                col = rng.choice([hexc('3a2a22'), hexc('d8d0c0'), hexc('2a3a5a'), hexc('8a2a2a'), hexc('5a4a3a')])
                sy = y - 2
                block(c, x, x + 5, sy - 1, sy, 3, col)
                c.rect(x + 1, sy - 3, x + 2, sy - 2, shade(col, 0.4))  # the heel opening
                x += 8 + rng.randrange(0, 2)
    for x in (1, w - 2):                                            # the front posts
        c.vline(x, C - 19 - d, C, shade(wood, 0.82))
    c.put(10, C - 19 - d + 2, hexc('c8c0b0')); c.put(11, C - 19 - d + 2, hexc('c8c0b0'))   # keys left on top
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


def umbrella_stand(save, name, seed):
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
    cylinder(c, 9, 5, top, bottom, ry, brass, inner=hexc('141210'))
    c.rect(4, top + 1, 14, top + 2, shade(brass, 1.3))               # its collar
    for x in (6, 12):
        c.vline(x, top + 4, bottom, shade(brass, 0.82))
    save(name, c)
    record(name, "door", d, C)


def parcels(save, name, seed):
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
    ox = 8 + rng.randrange(0, 4)                                    # a smaller one stacked on it, set back
    top2 = C - 10 - 4
    block(c, ox, ox + 12, top2 - 6, top2, 5, shade(card, 1.08))
    c.hline(ox, ox + 12, top2 - 9, tape)
    c.rect(ox + 2, top2 - 4, ox + 6, top2 - 2, hexc('3a6ab8'))       # a courier's sticker
    save(name, c)
    record(name, "door", d, C)


def pram(save, name, seed):
    rng = random.Random(seed)
    w, d = 34, 9
    h = 32 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    body = rng.choice([hexc('2a3a5a'), hexc('5a2a3a'), hexc('3a4a3a')])
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


def bin_bags(save, name, seed):
    rng = random.Random(seed)
    w, d = 32, 11
    h = 18 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 1, w - 2, C - d, C, 110)
    bag, bag_lt, bag_dk = hexc('1c1c20'), hexc('4a4a54'), hexc('0a0a0c')
    # back to front: a big one against the wall, then two in front of it
    for (cx, base, rx, ry) in ((16, C - 7, 9, 9), (8, C, 7, 7), (23, C - 1, 8, 7)):
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


def recycling_box(save, name, seed):
    rng = random.Random(seed)
    w, d = 26, 8
    h = 16 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    box = hexc('2a7a3a')
    ground(c, 1, w - 2, C - d, C)
    top = C - 8
    c.rect(2, top - d, w - 3, top - 1, hexc('0e1a10'))              # the open crate: its dark inside
    for k in range(6):                                              # bottles + cans stood in it
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


def newspapers(save, name, seed):
    rng = random.Random(seed)
    w, d = 22, 9
    h = 8 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 1, w - 2, C - d, C)
    paper = hexc('d8d2c2')
    block(c, 2, 19, C - 6, C, d, shade(paper, 0.9), paper)
    for y in range(C - 5, C):                                       # the edges of the stacked papers
        c.hline(2, 19, y, shade(paper, 0.8 if y % 2 else 0.95))
    for y in range(C - 6 - d + 2, C - 7, 2):                        # the top one's columns of print
        c.hline(4, 9, y, hexc('8a8a86')); c.hline(11, 17, y, hexc('8a8a86'))
    c.rect(4, C - 6 - d + 1, 17, C - 6 - d + 1, hexc('3a3a3a'))      # its masthead
    c.vline(8, C - 6 - d, C, hexc('b88a4a'))                         # the string, over the top and down
    c.vline(14, C - 6 - d, C, hexc('b88a4a'))
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


def shopping_bag(save, name, seed):
    rng = random.Random(seed)
    w, d = 16, 6
    h = 22 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    paper = hexc('b89a6a')
    ground(c, 2, 13, C - d, C, 80)
    top = C - 11
    c.rect(3, top - d, 12, top - 1, shade(paper, 0.45))              # the open top: dark inside
    c.line(4, top - 2, 8, top - 11, hexc('d8c078'))                  # a baguette sticking out
    c.line(5, top - 2, 9, top - 11, shade(hexc('d8c078'), 0.8))
    c.rect(9, top - 6, 11, top - 2, hexc('4a8a3a'))                  # greens
    c.put(10, top - 7, hexc('6aaa4a'))
    c.rect(6, top - 4, 8, top - 1, hexc('e8e8e0'))                   # a milk carton
    block(c, 3, 12, top, C, 0, paper)
    c.hline(3, 12, top, shade(paper, 1.25))
    c.line(5, top, 7, top - 4, hexc('8a6a3a')); c.line(7, top - 4, 9, top, hexc('8a6a3a'))   # its handle
    c.rect(5, top + 3, 10, top + 6, hexc('c83a2a'))                  # the shop's logo
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


def scooter(save, name, seed):
    w, d = 24, 4
    h = 24 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    deck = hexc('c83a4a')
    ground(c, 2, 21, C - d, C, 80)
    for x in (5, 18):                                               # far edge of the deck, then the wheels
        c.ellipse(x, C - 2, 2, 2, hexc('1e1c1a'))
        c.put(x, C - 2, hexc('8a8a8a'))
    block(c, 4, 19, C - 5, C - 4, 2, deck)
    c.line(18, C - 5, 16, C - 23, hexc('8a8a90')); c.line(19, C - 5, 17, C - 23, hexc('6a6a70'))   # the stem
    c.hline(12, 20, C - 23, hexc('2a2a2a'))
    c.put(11, C - 23, hexc('d84a8a'))
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


def hall_chair(save, name, seed, down=False):
    """A hall chair against the wall — somewhere to wait for the lift."""
    wood, dk = hexc('7a5236'), hexc('4e321e')
    seat_c = hexc('8a3a3a') if seed % 2 else hexc('3a5a4a')
    if down:                                                        # knocked over onto its side
        w, d = 30, 10
        h = 16 + d + SHADOW
        C = h - 1 - SHADOW
        c = new(w, h, seed)
        ground(c, 1, w - 2, C - d, C, 90)
        for (yl, col) in ((C - d + 2, shade(dk, 0.6)), (C - d + 10, shade(dk, 0.6))):   # the far legs, behind
            c.hline(17, 28, yl - 2, col)
        c.rect(2, C - d + 1, 15, C - 1, shade(wood, 0.8))            # the chair back, lying on the floor
        c.rect(4, C - d + 2, 13, C - 2, seat_c)                      # its padded panel, face up
        c.hline(2, 15, C - d + 1, shade(wood, 1.2))
        c.hline(2, 15, C, shade(wood, 0.55))
        c.rect(15, C - 14, 17, C, wood)                               # the seat, now standing on its edge
        c.rect(15, C - 14 - 3, 17, C - 15, seat_c)                    # its padded top, seen edge-on from above
        c.vline(17, C - 14, C, shade(wood, 0.7))
        for yl in (C - 2, C - 12):                                    # the near legs, sticking out along the floor
            c.hline(18, 28, yl, dk)
            c.hline(18, 28, yl + 1, shade(dk, 0.7))
        c.vline(24, C - 12, C - 2, shade(dk, 0.9))                    # a stretcher between them
        save(name, c)
        record(name, "open", d, C)
        return
    w, d = 20, 9
    h = 30 + d + SHADOW
    C = h - 1 - SHADOW
    c = new(w, h, seed)
    ground(c, 2, 17, C - d, C)
    seat_y = C - 11
    for x in (3, 16):                                               # back legs, standing further back
        c.vline(x, seat_y, C - d, shade(dk, 0.8))
    c.rect(3, seat_y - d - 14, 16, seat_y - d, wood)                 # the chair back, against the wall
    c.rect(5, seat_y - d - 12, 14, seat_y - d - 2, seat_c)           # its padded panel
    c.hline(3, 16, seat_y - d - 14, shade(wood, 1.3))
    block(c, 2, 17, seat_y, seat_y + 2, d, wood, seat_c)             # the seat (padded top)
    c.hline(3, 16, seat_y - d + 1, shade(seat_c, 1.25))
    for x in (2, 17):                                               # front legs
        c.vline(x, seat_y + 2, C, dk)
    c.hline(3, 16, C - 4, shade(dk, 0.9))                           # a stretcher
    save(name, c)
    record(name, "open", d, C)


def build(save):
    """Every standing prop (names are the catalogue keys in scripts/corridor_decals.gd)."""
    shoe_rack(save, 'shoe_rack', 57)
    shoes(save, 'shoes', 55)
    shoes(save, 'boots', 56, boots=True)
    umbrella_stand(save, 'umbrella_stand', 54)
    parcels(save, 'parcels', 58)
    pram(save, 'pram', 85)
    bin_bags(save, 'bin_bags', 82)
    recycling_box(save, 'recycling_box', 83)
    newspapers(save, 'newspapers', 86)
    suitcase(save, 'suitcase', 62)
    shopping_bag(save, 'shopping_bag', 63)
    bike(save, 'bicycle', 80)
    bike(save, 'bicycle_down', 80, down=True)
    bike(save, 'kids_bike', 81, kid=True)
    scooter(save, 'scooter', 61)
    planter(save, 'plant_tall', 50)
    planter(save, 'plant_dead', 51, dead=True)
    planter(save, 'plant_fallen', 52, fallen=True)
    plant_stand(save, 'plant_stand', 53)
    hall_chair(save, 'chair', 59)
    hall_chair(save, 'chair_down', 60, down=True)
    return META
