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


def bike(save, name, seed, kid=False, extra=None, stabilisers=False):
    """A bike leant on the wall beside a door, side on: a whole bicycle with real proportions and volume (tools/art/corridor_bikes.py — owner round 48h:
    "a fully realised object with the usual geometry and depth"). The sprite sizes and the floor contact are the ones the planner has always reserved
    (64 x 39 adult, 46 x 29 kid's), so every floor's dressing lands exactly where it did."""
    import corridor_bikes
    rng = random.Random(seed)
    frame = rng.choice(corridor_bikes.FRAMES)
    if kid:
        frame = rng.choice(corridor_bikes.KID_FRAMES)
    w, h, d = (46, 29, 3) if kid else (64, 39, 3)
    C = h - 1 - SHADOW
    R, rx = (8, 9) if kid else (11, 14)
    c = new(w, h, seed)
    ground(c, rx - R, rx + 3.2 * R + R, C - d, C, 85)
    corridor_bikes.draw_bike(c, C, rx, R, frame, kid=kid, extra=extra, seed=seed, stabilisers=stabilisers)
    save(name, c)
    record(name, "door", d, C)


# --- the open wall between the doors / by the lift ----------------------------------------------
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


def build(save):
    """Every standing prop (base names are the catalogue keys in scripts/corridor_decals.gd; `__N` are
    that prop's variants — the game picks one per placement)."""
    import corridor_props3d as V                                    # the volume props (round 48h: no flat drawings)
    V.shoe_rack(save, 'shoe_rack', 57)
    V.shoe_rack(save, 'shoe_rack__2', 157, metal=True)
    V.shoe_rack(save, 'shoe_rack__3', 257, sprawled=True)
    V.shoe_tray(save, 'shoe_tray', 55, 'shoes')
    V.shoe_tray(save, 'shoe_tray__2', 56, 'boots')
    V.shoe_tray(save, 'shoe_tray__3', 155, 'family')
    V.umbrella_stand(save, 'umbrella_stand', 54)
    V.umbrella_stand(save, 'umbrella_stand__2', 154, ceramic=True)
    V.hall_table(save, 'hall_table', 90, 'flowers')
    V.hall_table(save, 'hall_table__2', 91, 'lamp')
    V.hall_table(save, 'hall_table__3', 92, 'post')
    V.parcels(save, 'parcels', 58)
    V.parcels(save, 'parcels__2', 158, 'env')
    V.pram(save, 'pram', 85)
    V.pram(save, 'pram__2', 185, body_hex='6a3a4a')
    V.bin_bags(save, 'bin_bags', 82)
    V.bin_bags(save, 'bin_bags__2', 182, 'two')
    V.bin_bags(save, 'bin_bags__3', 282, 'pizza')
    V.recycling_box(save, 'recycling_box', 83)
    V.recycling_box(save, 'recycling_box__2', 183, cardboard=True)
    V.newspapers(save, 'newspapers', 86)
    V.suitcase(save, 'suitcase', 62)
    V.suitcase(save, 'suitcase__2', 162)
    V.holdall(save, 'suitcase__3', 262)
    V.paper_bag(save, 'shopping_bag', 63)
    V.carrier_bags(save, 'shopping_bag__2', 163)
    bike(save, 'bicycle', 80, extra='rack')
    bike(save, 'bicycle__2', 180, extra='basket')
    bike(save, 'kids_bike', 81, kid=True)
    bike(save, 'kids_bike__2', 181, kid=True, stabilisers=True, extra='basket')
    V.scooter(save, 'scooter', 61)
    V.scooter(save, 'scooter__2', 161)
    V.tall_plant(save, 'plant_tall', 50)
    V.snake_plant(save, 'plant_tall__2', 150)
    V.palm(save, 'plant_tall__3', 250)
    V.tall_plant(save, 'plant_dead', 51, dead=True)
    V.snake_plant(save, 'plant_dead__2', 151, dead=True)
    V.planter_fallen(save, 'plant_fallen', 52)
    V.plant_stand(save, 'plant_stand', 53)
    V.plant_stand(save, 'plant_stand__2', 153)
    V.plant_stand_fallen(save, 'plant_stand_fallen', 53)
    V.plant_stand_fallen(save, 'plant_stand_fallen__2', 153)
    V.hall_chair(save, 'chair', 59)
    V.hall_chair(save, 'chair__2', 159, spindle=True)
    V.hall_chair(save, 'chair_down', 60, down=True)
    return META
