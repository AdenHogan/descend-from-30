#!/usr/bin/env python3
"""THE TOWER'S FACE — windows, balconies, plants, vines, the sick lower floors and the roof (owner round 49c).

The owner, on a frame of the climb: "a lot of noise in the image. Too many things in the windows… some windows have these grey almost
concrete looking images on them… the people clip the window frame… potted plants are basic simple images and they look weird where they are
placed… the building goes from red brick to white structure halfway up, one colour only would be best… we need crisp and identifiable quality…
with the night time add the infected look to the lower floors… the items at the top of the building look way too simple".

So this module draws the tower with a small, strict GRAMMAR instead of per-window dither:

  * ONE material for all thirty floors: brick, cream-painted frames, stone sills / lintels / coping. No section changes.
  * A window is a frame, a mullion, a sill and a lintel round 9 x 8 px of glass. The glass is a FLAT two-tone (a sky reflection over the
    dark room, one step between), never a checker; the room is one of five clean things — dark, curtains (two panels), a roller blind,
    lit, or one of the broken states. Nothing is dithered, nothing is a one-pixel speck.
  * A plant is drawn as a plant: a clump of leaves in three tones lit from the upper left, in a pot, in a trough hooked over a balcony
    rail or standing behind it — never a coloured block stuck on glass. Vines are a stem with leaves in pairs.
  * The LOWER FLOORS grow sick over the three runs (the overgrowth rule: nothing wild above floor 12): ivy up the piers, bracket fungus on
    the sills, mould under them, a few windows lit a sickly green. Run 1 clean, run 2 a little, run 3 a lot — the SAME vines, longer.
  * The roof is a roof: a stair head with a door, louvres, a flat roof with a fascia; a water tank on a steel frame with a ladder;
    chimney stacks with pots; condenser units with fans; a yagi aerial and dishes on a lattice mast with a beacon; railings and cables.

Geometry (bays, floor height, the building's x range) belongs to `opening.py`; it hands it over with `bind(globals())`.
"""
import math
import random
from types import SimpleNamespace

from pixlib import hexc, mix, shade

G = SimpleNamespace()


def bind(ns):
    """opening.py's geometry: BX0 BX1 BAYS BAY_W INNER_X0 FH TOP_Y LOBBY_Y GROUND_Y PARAPET_Y."""
    for k in ('BX0', 'BX1', 'BAYS', 'BAY_W', 'INNER_X0', 'FH', 'TOP_Y', 'LOBBY_Y', 'GROUND_Y', 'PARAPET_Y'):
        setattr(G, k, ns[k])


# ======================================================================================================================== PALETTE
# One brick, one stone, one cream paint. (`PAL` in opening.py is this, so everything that reads the building's colours agrees.)
BRICK = dict(wall=hexc('9d5a44'), lit=hexc('b06c52'), dark=hexc('7a4636'), course=hexc('8b4f3b'),
             trim=hexc('d8c29c'), trim_hi=hexc('ece0c0'), trim_lo=hexc('a8916d'), frame=hexc('ece4d0'), frame_lo=hexc('b9b09a'),
             rail=hexc('8995a3'), rail_hi=hexc('c3ccd6'), rail_lo=hexc('5b6572'), band=hexc('cdb48f'), mortar=hexc('8b4f3b'))

SKY_REFLECT = hexc('7f9ab4')                 # what a dark pane reflects: the sky
ROOMS = [hexc('2f3646'), hexc('342f3c'), hexc('2a3640'), hexc('3a3834')]       # the dark behind the glass: four close tones
CURTAIN_COLS = [hexc('d8cba6'), hexc('b86a5c'), hexc('7f9a8a'), hexc('c9a06e'), hexc('8d82a6')]   # muted: cream, brick, sage, ochre, lilac
BLIND_COLS = [hexc('e4dcc6'), hexc('d2c8aa'), hexc('c8d0c4')]
LIT = {'warm': (hexc('f6cf6e'), hexc('ffe8a0'), hexc('c98f40')),               # (glow, core, sill)
       'amber': (hexc('f2a84e'), hexc('ffd088'), hexc('b86a2c')),
       'white': (hexc('eee9d6'), hexc('ffffff'), hexc('a8a498')),
       'tv': (hexc('8fb4e4'), hexc('cfe6ff'), hexc('566f98')),
       'sick': (hexc('b0c268'), hexc('dde29a'), hexc('66803a'))}               # the infected windows: a bile-yellow green
LIT_KINDS = ('warm', 'warm', 'warm', 'amber', 'white', 'tv')
SHIRTS = [hexc('c9605a'), hexc('4f7ab0'), hexc('d8c25a'), hexc('5aa070'), hexc('b58ad0'), hexc('e8e4d8'), hexc('d8884a')]

LEAF_DARK, LEAF_MID, LEAF_LIT = hexc('2f5a36'), hexc('4a8142'), hexc('7db553')
LEAF_SICK_DARK, LEAF_SICK_MID, LEAF_SICK_LIT = hexc('2c4a36'), hexc('55743a'), hexc('a3b94a')
POT_RIM, POT_BODY, POT_LO = hexc('cf8458'), hexc('a2603f'), hexc('6f402b')
FLOWERS = [hexc('e8c24a'), hexc('d9584a'), hexc('f2efe2'), hexc('e08aa8')]
FUNGUS_TOP, FUNGUS_MID, FUNGUS_LO = hexc('e6e0b4'), hexc('c4bb82'), hexc('6b5a3a')

# the jamb's shadow on the glass, the sill's bounce (alpha) — game code re-lays the same ones over the little people, so they are DATA
JAMB_LEFT = (10, 8, 16, 62)
LINTEL_ROW0 = (10, 8, 16, 78)
LINTEL_ROW1 = (10, 8, 16, 26)
SILL_BOUNCE = (255, 255, 255, 22)


# ======================================================================================================================== BRICK
def brick_wall(c, x0, x1, y, h, P=BRICK):
    """A run of wall, regular and quiet: the brick colour and a course line every third row (no speckle, no joints)."""
    c.rect(x0, y, x1, y + h - 1, P['wall'])
    for yy in range(y, y + h):
        if (yy - G.TOP_Y) % 3 == 2:
            c.hline(x0, x1, yy, P['course'])


def pilasters(c, y, h, P=BRICK):
    for (px0, px1) in ((G.BX0, G.BX0 + 5), (G.BX1 - 5, G.BX1)):
        left = px0 == G.BX0
        c.rect(px0, y, px1, y + h - 1, P['lit'] if left else P['dark'])
        for yy in range(y, y + h):
            if (yy - G.TOP_Y) % 3 == 2:
                c.hline(px0, px1, yy, shade(P['lit'] if left else P['dark'], 0.92))
        c.vline(px0 if left else px1, y, y + h - 1, shade(P['lit'] if left else P['dark'], 0.86))


# ======================================================================================================================== WINDOWS
def window(c, bx, y, state, rng, meta, floor, bay, survivor=0.0, sick=False, P=BRICK):
    """One window. bx = the bay's left x, y = the floor band's top. Frame 11 x 10 at (bx+2, y+2), glass 9 x 8 inside it.
    `survivor` = the chance (0..1) that a LIT window has someone at it (the game animates them: meta['survivors']).
    Every choice comes from `rng`, which is this window's OWN seeded generator."""
    fx, fy = bx + 2, y + 2
    gx, gy = fx + 1, fy + 1
    room = rng.choice(ROOMS)
    glint = rng.choice((0, 0, 1, 2))                  # 0 / 1 = a glint in the left / right pane, 2 = none
    style = rng.choice(('drapes', 'drapes', 'blind', 'half'))
    lit_kind = rng.choice(LIT_KINDS)
    c.rect(fx, fy, fx + 10, fy + 9, P['frame'])
    # the glass: a sky reflection over the dark of the room, one step between — flat tones, no gradient dither
    for yy in range(8):
        col = mix(room, SKY_REFLECT, 0.34) if yy < 3 else mix(room, SKY_REFLECT, 0.14) if yy == 3 else room
        for xx in range(9):
            c.put(gx + xx, gy + yy, col)
    if state in ('dark', 'curtain', 'open') and glint < 2:
        gxo = 1 if glint == 0 else 5                   # the glint: three pixels on a diagonal, in one pane
        for k in range(3):
            c.put(gx + gxo + k, gy + 3 - k, mix(room, hexc('c4d8ea'), 0.62))
    if state == 'curtain':
        col = rng.choice(CURTAIN_COLS)
        edge = shade(col, 0.78)
        if style == 'blind':                          # a roller blind part way down: flat, a darker bar at its foot, a pull
            bcol = rng.choice(BLIND_COLS)
            drop = rng.choice((3, 4, 6))
            c.rect(gx, gy, gx + 8, gy + drop - 1, bcol)
            c.hline(gx, gx + 8, gy + drop - 1, shade(bcol, 0.8))
            c.put(gx + 4, gy + drop, shade(bcol, 0.7))
        else:
            wd = rng.choice((2, 3))
            sides = (0, 1) if style == 'drapes' else (rng.choice((0, 1)),)
            for s in sides:
                xs = range(0, wd) if s == 0 else range(9 - wd, 9)
                for xx in xs:
                    inner = (xx == wd - 1) if s == 0 else (xx == 9 - wd)
                    for yy in range(8):
                        c.put(gx + xx, gy + yy, edge if inner else col)
                c.put(gx + (0 if s == 0 else 8), gy, shade(col, 0.9))          # the rail's end
    elif state == 'lit':
        if sick:
            kind = 'sick'
            has_person = False
        elif survivor > 0.0 and rng.random() < survivor:
            kind = 'warm'                              # someone at the window: a plain warm room so they read against it
            has_person = True
        else:
            kind = lit_kind
            has_person = False
        glow, core, sill = LIT[kind]
        for yy in range(8):
            for xx in range(9):
                inner = 2 <= xx <= 6 and 1 <= yy <= 5
                c.put(gx + xx, gy + yy, core if inner and kind != 'tv' else glow)
        if kind == 'tv':                                # a screen's cool light, brightest in the middle, the room dim at the edges
            for yy in range(8):
                for xx in range(9):
                    if xx in (0, 8) or yy in (0, 7):
                        c.put(gx + xx, gy + yy, mix(glow, hexc('2e3a52'), 0.55))
        c.hline(gx, gx + 8, gy + 7, sill)
        if not has_person:                              # curtains pulled to the sides (a person's window is left clear)
            wd = rng.choice((1, 2))
            cc = shade(rng.choice(CURTAIN_COLS), 0.95)
            for xx in range(wd):
                c.rect(gx + xx, gy, gx + xx, gy + 6, cc)
                c.rect(gx + 8 - xx, gy, gx + 8 - xx, gy + 6, cc)
        if has_person:
            kinds = ('wave', 'pace', 'peer', 'sway', 'pound', 'slump')
            meta['survivors'].append({'x': gx, 'y': gy, 'w': 9, 'h': 8, 'floor': floor, 'bay': bay,
                                      'kind': rng.choice(kinds), 'shirt': '%02x%02x%02x' % tuple(rng.choice(SHIRTS)[:3]),
                                      'phase': round(rng.random() * 6.28, 2)})
        meta['lit'].append({'x': gx, 'y': gy, 'w': 9, 'h': 8, 'floor': floor, 'bay': bay, 'tint': kind if sick else ''})
    elif state == 'open':                               # a casement thrown open: its pane edge-on, and a curtain taken out by the draught
        c.vline(gx + 6, gy, gy + 7, hexc('e4e4dc'))
        c.vline(gx + 7, gy + 1, gy + 7, hexc('9aa0a8'))
        col = rng.choice(CURTAIN_COLS)
        for yy in range(6):
            c.put(gx + 1 + (yy // 3), gy + yy, col)
            c.put(gx + 2 + (yy // 3), gy + yy, shade(col, 0.82))
    elif state == 'broken':
        left = rng.random() < 0.5                          # a corner of the glass is gone (dark), and one crack runs from it across the pane
        if left:
            corner = [(0, 3), (0, 4), (0, 5), (0, 6), (0, 7), (1, 5), (1, 6), (1, 7), (2, 6), (2, 7), (3, 7)]
            crack = [(1, 4), (2, 3), (3, 2), (3, 1), (2, 0)]
        else:
            corner = [(8, 3), (8, 4), (8, 5), (8, 6), (8, 7), (7, 5), (7, 6), (7, 7), (6, 6), (6, 7), (5, 7)]
            crack = [(7, 4), (6, 3), (5, 2), (5, 1), (6, 0)]
        for (xx, yy) in corner:
            c.put(gx + xx, gy + yy, hexc('1c1e2a'))
        for (xx, yy) in crack:
            c.put(gx + xx, gy + yy, hexc('dfe9f0'))
    elif state == 'boarded':
        wood = rng.choice((hexc('a07c55'), hexc('8f6d4a'), hexc('b08a5c')))
        dk = shade(wood, 0.72)
        for yy in (1, 5):
            c.rect(gx - 1, gy + yy, gx + 9, gy + yy + 1, wood)
            c.hline(gx - 1, gx + 9, gy + yy + 1, dk)
            c.put(gx + 1, gy + yy, dk)
            c.put(gx + 7, gy + yy, dk)
    # the opening is a RECESS in a thick wall: its jamb and head cast a shadow onto the glass, the sill throws light back up
    if state in ('dark', 'curtain', 'lit', 'open', 'broken'):
        for yy in range(8):
            c.put(gx, gy + yy, JAMB_LEFT)
        for xx in range(9):
            c.put(gx + xx, gy, LINTEL_ROW0)
            c.put(gx + xx, gy + 1, LINTEL_ROW1)
        for xx in range(1, 9):
            c.put(gx + xx, gy + 7, SILL_BOUNCE)
    if state in ('dark', 'curtain', 'lit', 'open', 'broken'):
        c.vline(gx + 4, gy, gy + 7, P['frame'])           # the mullion
    # the sill and its shadow, and the lintel
    c.hline(fx - 1, fx + 11, fy + 10, P['trim_hi'])
    c.hline(fx - 1, fx + 11, fy + 11, P['trim_lo'])
    c.hline(fx - 1, fx + 11, fy - 1, P['trim'])


# ======================================================================================================================== PLANTS
def clump(c, cx, cy, rx, ry, rng, sick=False, flowers=0, dead=False):
    """A clump of foliage centred (cx, cy), half-size (rx, ry), in three tones lit from the upper left: a soft outline with a notch or two
    cut into it, a shaded lower right, a lit upper left, a few leaves picked out inside — and, if asked, some flowers."""
    dark, mid, lit = (LEAF_SICK_DARK, LEAF_SICK_MID, LEAF_SICK_LIT) if sick else (LEAF_DARK, LEAF_MID, LEAF_LIT)
    if dead:
        dark, mid, lit = hexc('4a3a2a'), hexc('7a6240'), hexc('a28a5c')
    pts = set()
    for y in range(int(cy - ry - 1), int(cy + ry) + 2):
        for x in range(int(cx - rx - 1), int(cx + rx) + 2):
            if ((x - cx) / max(rx, 0.6)) ** 2 + ((y - cy) / max(ry, 0.6)) ** 2 <= 1.0:
                pts.add((x, y))
    edge = [p for p in pts if any((p[0] + dx, p[1] + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for p in rng.sample(sorted(edge), min(len(edge), max(1, len(edge) // 6))):          # notches: leaves, not an ellipse
        if len(pts) > 6:
            pts.discard(p)
    for (x, y) in pts:
        col = mid
        if (x + 1, y + 1) not in pts or (x + 1, y) not in pts and (x, y + 1) not in pts:
            col = dark
        elif (x - 1, y - 1) not in pts or (x, y - 1) not in pts:
            col = lit
        c.put(x, y, col)
    inner = sorted(p for p in pts if p not in edge)
    for p in rng.sample(inner, min(len(inner), max(1, len(inner) // 5))):                # a few leaves picked out
        c.put(p[0], p[1], lit if (p[0] + p[1]) % 2 == 0 else dark)
    for p in rng.sample(sorted(pts), min(len(pts), flowers)):
        c.put(p[0], p[1], rng.choice(FLOWERS))


def pot(c, x, y, w=3, h=3):
    """A terracotta pot standing on row y (its foot), x the left edge: a lit rim, a body, a shaded foot."""
    c.rect(x, y - h + 1, x + w - 1, y - h + 1, POT_RIM)
    c.rect(x, y - h + 2, x + w - 1, y, POT_BODY)
    c.hline(x + 1, x + w - 2, y, POT_LO)
    c.put(x + w - 1, y - 1, POT_LO)


def trailing_vine(c, x, y0, n, rng, sick=False):
    """A vine hanging from (x, y0) down n rows: a thin stem that wanders a pixel, leaves in pairs, a leaf at the tip."""
    dark, mid, lit = (LEAF_SICK_DARK, LEAF_SICK_MID, LEAF_SICK_LIT) if sick else (LEAF_DARK, LEAF_MID, LEAF_LIT)
    px = x
    for i in range(n):
        if i and rng.random() < 0.28:
            px += rng.choice((-1, 1))
        c.put(px, y0 + i, dark)
        if i % 2 == 1:
            c.put(px - 1, y0 + i, mid)
            c.put(px + 1, y0 + i, lit if i % 4 == 1 else mid)
    c.put(px, y0 + n, lit)


# ======================================================================================================================== BALCONIES
def balcony_bay(c, bx, y, rng, meta, floor, bay, P=BRICK):
    """A glass door with a slab and a railing. What stands on the slab is one thing, drawn as itself: a planter hooked over the rail with
    leaves spilling out of it, a tall plant in a pot behind the rail, washing on a line, a dish on the rail — or nothing."""
    fx, fy = bx + 2, y + 2
    gx, gy = fx + 1, fy + 1
    c.rect(fx, fy, fx + 10, fy + 9, P['frame'])
    room = rng.choice(ROOMS)
    for yy in range(8):
        col = mix(room, SKY_REFLECT, 0.34) if yy < 3 else mix(room, SKY_REFLECT, 0.14) if yy == 3 else room
        for xx in range(9):
            c.put(gx + xx, gy + yy, col)
    for k in range(3):
        c.put(gx + 1 + k, gy + 3 - k, mix(room, hexc('c4d8ea'), 0.62))
    for yy in range(8):
        c.put(gx, gy + yy, JAMB_LEFT)
    c.vline(gx + 4, gy, gy + 7, P['frame'])
    r = rng.random()
    plant = None
    if r < 0.28:
        plant = 'trough'
    elif r < 0.44:
        plant = 'tall'
    # a plant standing behind the rail goes down BEFORE it, so the balusters pass in front of the pot
    if plant == 'tall':
        px = fx + rng.randrange(1, 7)
        pot(c, px, y + 11, 3, 3)
        clump(c, px + 1, y + 6, 2.6, 2.4, rng, flowers=rng.choice((0, 0, 2)))
        c.put(px + 1, y + 8, LEAF_DARK)
    # the slab (2 rows, 1 px proud each side) and the railing: a top bar and balusters over the lower part of the door
    c.hline(bx, bx + 14, y + 12, P['trim_hi'])
    c.hline(bx, bx + 14, y + 13, P['trim_lo'])
    c.hline(fx - 1, fx + 11, y + 8, P['rail_hi'])
    for xx in range(fx - 1, fx + 12):
        if (xx - fx) % 2 == 0:
            c.vline(xx, y + 9, y + 11, P['rail'])
            c.put(xx, y + 11, P['rail_lo'])
    if plant == 'trough':                                    # hooked over the top rail, outside the balusters
        c.rect(fx, y + 8, fx + 10, y + 10, POT_BODY)
        c.hline(fx, fx + 10, y + 8, POT_RIM)
        c.hline(fx, fx + 10, y + 10, POT_LO)
        for k in range(3):
            clump(c, fx + 2 + k * 3, y + 6 - (k % 2), 2.4, 2.0, rng, flowers=rng.choice((0, 1, 2)))
        for vx in rng.sample((fx + 1, fx + 4, fx + 6, fx + 9), 2):
            trailing_vine(c, vx, y + 11, rng.choice((2, 3)), rng)
    elif r < 0.56:                                           # washing on a line: two shirts and a pair of trousers, clean shapes
        col = rng.choice(CURTAIN_COLS + [hexc('e8e8e0'), hexc('c9605a')])
        c.hline(fx - 1, fx + 11, y + 4, hexc('3a3a3a'))
        for k, w_ in enumerate((3, 3, 2)):
            x0 = fx + 1 + k * 4
            cc = col if k != 1 else shade(col, 0.82)
            c.rect(x0, y + 5, x0 + w_ - 1, y + 7, cc)
            c.hline(x0, x0 + w_ - 1, y + 7, shade(cc, 0.84))
            c.put(x0 + w_ // 2, y + 4, hexc('d8d0b8'))
    elif r < 0.64:                                           # a dish on the rail
        sx = fx + rng.choice((2, 8))
        c.ellipse(sx, y + 6, 2.0, 1.6, hexc('d6d6d0'))
        c.put(sx - 1, y + 5, hexc('f0f0ea'))
        c.put(sx, y + 6, hexc('7a7a76'))
        c.vline(sx, y + 7, y + 7, hexc('5a5a58'))


# ======================================================================================================================== SICK FLOORS
# The designed look (docs/ART_REQUIREMENTS.md "Sectional identity", docs/OVERGROWTH.md "depth BIOMES"): the building is sickest at the BOTTOM.
# Floors 12-6 "the Green" — ivy up the piers, bracket fungus on the sills, mould running down from them; floors 5-1 + the lobby "the Nest" —
# the growth turns to flesh: wet red-brown tendrils with nodules, a grey-pink membrane growing over some windows, glossy drips from the
# sills. A few windows down there give a bile-yellow light of their own (glowing fungus at night on the darkest floors).
LOW_GROWTH_TOP = 12                  # the overgrowth rule: nothing wild above floor 12
NEST_TOP = 5                         # floors 5..1 (and the lobby) turn to flesh
GROWTH_BY_RUN = {1: 0.0, 2: 0.42, 3: 1.0}
FLESH_DARK, FLESH_MID, FLESH_LIT = hexc('4d2230'), hexc('86384a'), hexc('bd6678')
FLESH_PALE, FLESH_WET = hexc('c9aaa4'), hexc('f0cdd0')


def _dim(col, k):
    return (int(col[0] * k), int(col[1] * k), int(col[2] * k), 255)


def _leaf(c, x, y, pal, flip=1):
    """A leaf: 2 x 2, a lit top, a shaded foot."""
    dark, mid, lit = pal
    c.put(x, y, lit)
    c.put(x + flip, y, mid)
    c.put(x, y + 1, mid)
    c.put(x + flip, y + 1, dark)


def growth(c, run, floor_y_fn, dim=1.0, rng_seed=4021):
    """Draw the sick lower floors for this run. A pure function of the run: which piers carry a vine, how it wanders, and how high it WOULD
    climb are fixed; the run only decides how far each has got — so run 2's vines are run 3's, shorter. `dim` darkens every colour (it is
    drawn after the grade, so the growth is lit the way the night is)."""
    k = GROWTH_BY_RUN.get(run, 0.0)
    if k <= 0.0:
        return
    green = tuple(_dim(col, dim) for col in (LEAF_SICK_DARK, LEAF_SICK_MID, LEAF_SICK_LIT))
    flesh = tuple(_dim(col, dim) for col in (FLESH_DARK, FLESH_MID, FLESH_LIT))
    pale, wet = _dim(FLESH_PALE, dim), _dim(FLESH_WET, dim)
    bloom = tuple(_dim(col, dim) for col in (FUNGUS_TOP, FUNGUS_MID, FUNGUS_LO))
    foot = G.GROUND_Y - 1
    nest_y = floor_y_fn(NEST_TOP) + G.FH - 1                 # around this row the growth turns from leaf to flesh
    top_cap = floor_y_fn(LOW_GROWTH_TOP)
    mid_x = (G.BX0 + G.BX1) // 2
    door0, door1 = mid_x - 14, mid_x + 14                    # the lobby's doorway stays clear
    rr = random.Random(rng_seed)
    # ---- the climbers: six of the nine piers (never evenly — a pair side by side, a lone one, a gap), each its own height and wander
    piers = [b for b in range(G.BAYS + 1) if not door0 <= 82 + b * G.BAY_W + 1 <= door1]
    rr.shuffle(piers)
    chosen = sorted(piers[:6])
    for b in chosen:
        cx = 82 + b * G.BAY_W + 1 + rr.choice((-1, 0, 0, 1))
        full = rr.randrange(int((foot - top_cap) * 0.45), foot - top_cap + 1)
        thick = rr.choice((1, 2, 2))
        vr = random.Random(rr.randrange(1, 10 ** 6))
        n = int(full * k)
        x = cx
        branch_rows = sorted(vr.sample(range(10, max(11, full - 3)), 4))
        for i in range(n):
            yy = foot - i
            if i % 6 == 2 and vr.random() < 0.7:
                x = max(G.BX0 + 2, min(G.BX1 - 3, x + vr.choice((-1, -1, 1, 1, 2, -2))))
            # leaf above the nest line, flesh below it, a mixed band between (no hard seam)
            p_flesh = min(1.0, max(0.0, (yy - (nest_y - 12)) / 24.0)) if run == 3 else 0.0       # the Nest is the night's: before it, only leaves
            fl = vr.random() < p_flesh
            body = flesh if fl else green
            c.put(x, yy, body[0])
            if thick == 2:
                c.put(x + 1, yy, body[1] if fl else body[0])
            if i % 2 == 1:
                side = -1 if (i // 2) % 2 == 0 else 1
                lx = x - 2 if side < 0 else x + 1 + thick
                if fl:
                    if vr.random() < 0.55:                                      # a nodule: wet, with a highlight and a shaded foot
                        c.rect(lx, yy, lx + 1, yy + 1, flesh[1])
                        c.put(lx, yy, wet if vr.random() < 0.5 else flesh[2])
                        c.put(lx + 1, yy + 1, flesh[0])
                else:
                    _leaf(c, lx, yy, green, -side)
                    if i % 6 == 1:
                        _leaf(c, lx - side * 2, yy - 2, green, -side)
            if i in branch_rows and i < n - 3:                                    # a runner crossing a sill toward the next window
                dirn = vr.choice((-1, 1))
                bx, by = x, yy
                for j in range(1, vr.randrange(5, 10)):
                    bx += dirn
                    if not (G.BX0 + 2 < bx < G.BX1 - 2):
                        break
                    if j % 3 == 0:
                        by -= 1
                    c.put(bx, by, (flesh if fl else green)[0])
                    if j % 2 == 0:
                        if fl:
                            c.put(bx, by + 1, flesh[1])
                            c.put(bx, by + 2, wet) if j % 4 == 0 else None
                        else:
                            _leaf(c, bx, by + 1, green, dirn)
            if i % 19 == 11 and not fl and vr.random() < 0.8:                      # a pale bloom among the leaves
                c.put(x - 1, yy - 1, bloom[0])
                c.put(x, yy - 1, bloom[1])
    # ---- over the windows: a membrane on some of the Nest's (clean sheets, a vein, a wet highlight) and glossy drips from sills
    for n in range(NEST_TOP if run == 3 else 0, 0, -1):
        y = floor_y_fn(n)
        for b in range(G.BAYS):
            fr = random.Random(n * 4099 + b * 131 + 7)
            fx = G.INNER_X0 + b * G.BAY_W + 2
            if fr.random() < 0.18 * k and not (door0 - 12 <= fx <= door1):
                _mass(c, fx + 1, y + 3, fr, flesh, pale, wet)
            if fr.random() < 0.30 * k:
                mx = fx + fr.randrange(1, 10)
                ln = fr.randrange(3, 8)
                for d in range(ln):
                    c.put(mx, y + 12 + d, flesh[0])
                c.put(mx, y + 12 + ln, wet)
                c.put(mx + 1, y + 12 + ln - 1, flesh[1])
    # ---- the Green's mould: a dark stain running down from some sills (floors 12-6)
    for n in range(LOW_GROWTH_TOP, NEST_TOP, -1):
        y = floor_y_fn(n)
        depth = (LOW_GROWTH_TOP - n + 1) / float(LOW_GROWTH_TOP)
        for b in range(G.BAYS):
            fr = random.Random(n * 7001 + b * 131 + 3)
            if fr.random() < (0.10 + 0.25 * depth) * k:
                fx = G.INNER_X0 + b * G.BAY_W + 2
                mx = fx + fr.randrange(1, 10)
                for d in range(fr.randrange(3, 8)):
                    c.put(mx, y + 12 + d, (30, 52, 30, int(120 * (1.0 - d / 8.0))))
                    if d < 3:
                        c.put(mx + 1, y + 12 + d, (30, 52, 30, int(70 * (1.0 - d / 3.0))))
    # ---- the base: a fringe of flesh along the foot of the lobby, short and thick, wet at the tips (the night's)
    for x in range(G.BX0 + 2, G.BX1 - 2, 3):
        if door0 <= x <= door1 or run != 3:
            continue
        fr = random.Random(x * 31 + 5)
        if fr.random() < 0.8 * k:
            h = fr.randrange(3, 9)
            for d in range(h):
                c.put(x, foot - d, flesh[1] if d < h - 1 else flesh[2])
                if d % 3 == 1:
                    c.put(x + 1, foot - d, flesh[0])
            c.put(x, foot - h, wet if fr.random() < 0.5 else flesh[2])


def _mass(c, gx, gy, fr, flesh, pale, wet):
    """A mass of growth filling a window from the sill up: an irregular top edge, dark flesh with lighter lobes, nodules with a wet highlight,
    and two or three tendrils reaching out over the sill. (Round 49c: the first version, a flat pink sheet, read as a pink window.)"""
    cover = fr.randrange(4, 8)                                           # how many rows of the 8 it fills, from the bottom
    for xx in range(9):
        h = max(2, min(8, cover + fr.choice((-2, -1, 0, 0, 1, 2)) - (1 if xx in (0, 8) else 0)))
        for yy in range(8 - h, 8):
            c.put(gx + xx, gy + yy, flesh[0])
    for _ in range(6):                                                    # lighter lobes: small clumps of the mid tone
        lx = gx + fr.randrange(0, 8)
        ly = gy + fr.randrange(8 - cover, 7)
        for (dx, dy) in ((0, 0), (1, 0), (0, 1)):
            if gx <= lx + dx < gx + 9 and c.px[lx + dx, ly + dy][:3] == flesh[0][:3]:
                c.put(lx + dx, ly + dy, flesh[1])
    for _ in range(3):                                                    # nodules: a lit pixel over a wet highlight
        nx = gx + fr.randrange(1, 8)
        ny = gy + fr.randrange(8 - cover + 1, 7)
        if c.px[nx, ny][:3] in (flesh[0][:3], flesh[1][:3]):
            c.put(nx, ny, flesh[2])
            c.put(nx, ny - 1, wet) if c.px[nx, ny - 1][:3] in (flesh[0][:3], flesh[1][:3]) else None
    for tx in fr.sample(range(1, 8), 2):                                  # tendrils over the sill
        for d in range(fr.randrange(2, 5)):
            c.put(gx + tx, gy + 8 + d, flesh[1] if d else flesh[2])


# ======================================================================================================================== ROOF
def roof(c, meta, P=BRICK):
    """The roof, in the 22 rows above the parapet. Sun from the left: every form is lit on its left and shaded on its right."""
    py = G.PARAPET_Y
    foot = py - 1                                            # the roof's own surface: everything stands with its feet on this row
    # parapet: a stone coping over the brick, with a shadow under it, and a drip course
    c.rect(G.BX0 - 1, py, G.BX1 + 1, G.TOP_Y - 1, P['wall'])
    for yy in range(py + 3, G.TOP_Y - 1):
        if (yy - G.TOP_Y) % 3 == 2:
            c.hline(G.BX0 - 1, G.BX1 + 1, yy, P['course'])
    c.hline(G.BX0 - 2, G.BX1 + 2, py, P['trim_hi'])
    c.hline(G.BX0 - 2, G.BX1 + 2, py + 1, P['trim'])
    c.hline(G.BX0 - 2, G.BX1 + 2, py + 2, P['trim_lo'])
    for a, yy in ((70, py + 3), (40, py + 4), (18, py + 5)):
        for xx in range(G.BX0 - 1, G.BX1 + 2):
            c.put(xx, yy, (8, 6, 12, a))
    c.hline(G.BX0 - 1, G.BX1 + 1, G.TOP_Y - 1, shade(P['dark'], 0.8))
    c.vline(G.BX0 - 2, py, G.TOP_Y, P['trim_hi'])
    c.vline(G.BX1 + 2, py, G.TOP_Y, shade(P['trim_lo'], 0.8))

    def steel(x0, y0, x1, y1, lo=0.7):
        c.rect(x0, y0, x1, y1, hexc('7e8794'))
        c.vline(x0, y0, y1, hexc('aab3be'))
        c.vline(x1, y0, y1, shade(hexc('7e8794'), lo))

    # ---- a railing along the near edge, in three runs: a top rail, a mid rail and posts
    for (rx0, rx1) in ((G.BX0 + 1, 86), (120, 126), (176, G.BX1 - 1)):
        c.hline(rx0, rx1, foot - 4, hexc('2d333d'))
        c.hline(rx0, rx1, foot - 2, hexc('3b424d'))
        for xx in range(rx0, rx1 + 1, 4):
            c.vline(xx, foot - 4, foot, hexc('2d333d'))
    # ---- chimney stacks with pots (left corner)
    for (cx0, cw, ch) in ((82, 5, 12), (90, 4, 9)):
        top = foot - ch
        c.rect(cx0, top, cx0 + cw - 1, foot, P['lit'])
        c.vline(cx0 + cw - 1, top, foot, P['dark'])
        for yy in range(top + 1, foot + 1):
            if (yy - foot) % 3 == 0:
                c.hline(cx0, cx0 + cw - 1, yy, P['course'])
        c.hline(cx0 - 1, cx0 + cw, top - 1, P['trim_hi'])
        c.hline(cx0 - 1, cx0 + cw, top, P['trim_lo'])
        for k in range(2):                                   # two clay pots
            pxx = cx0 + 1 + k * (cw // 2)
            c.rect(pxx, top - 4, pxx + 1, top - 2, POT_BODY)
            c.put(pxx, top - 4, POT_RIM)
            c.put(pxx + 1, top - 5, hexc('6a6a70'))
    # ---- the water tank on a steel frame, with a ladder (the iconic rooftop one)
    tx0, tx1 = 99, 118
    tt, tb = foot - 13, foot - 7                              # the tank body rows
    for lx in (tx0 + 1, tx0 + 6, tx1 - 6, tx1 - 1):          # legs with cross bracing
        c.vline(lx, tb + 1, foot, hexc('4a525e'))
    for lx0, lx1 in ((tx0 + 1, tx0 + 6), (tx1 - 6, tx1 - 1)):
        for i in range(0, 8):
            xx = lx0 + (lx1 - lx0) * i // 7
            c.put(xx, tb + 1 + i, hexc('5e6672'))
            c.put(lx1 - (lx1 - lx0) * i // 7, tb + 1 + i, hexc('5e6672'))
    c.hline(tx0 - 1, tx1 + 1, tb + 1, hexc('3a414c'))          # the cradle the tank sits in
    c.rect(tx0, tt, tx1, tb, hexc('9a6a46'))                  # staves
    for xx in range(tx0, tx1 + 1):
        k = xx - tx0
        c.vline(xx, tt, tb, hexc('b07c52') if k % 3 == 0 else hexc('9a6a46') if k % 3 == 1 else hexc('84583a'))
    c.vline(tx0, tt, tb, hexc('c89466'))
    c.vline(tx1, tt, tb, hexc('6a4630'))
    c.vline(tx1 - 1, tt, tb, hexc('74502f'))
    for hy in (tt + 1, tt + 4, tb - 1):                         # iron hoops
        c.hline(tx0 - 1, tx1 + 1, hy, hexc('2d2f36'))
        c.put(tx0 - 1, hy, hexc('4a4d56'))
    for k in range(4):                                         # the conical lid, shingled
        c.hline(tx0 + 1 + k * 2, tx1 - 1 - k * 2, tt - 1 - k, hexc('4e3a2e') if k % 2 else hexc('5e4838'))
    c.vline((tx0 + tx1) // 2, tt - 6, tt - 5, hexc('2d2f36'))   # a finial
    c.put((tx0 + tx1) // 2, tt - 6, hexc('c8c0a8'))
    lad = tx1 + 3                                              # the ladder: two rails and rungs, up to the tank's hoop
    c.vline(lad, tt + 1, foot, hexc('3a414c'))
    c.vline(lad + 3, tt + 1, foot, hexc('4a525e'))
    for yy in range(tt + 2, foot, 2):
        c.hline(lad, lad + 3, yy, hexc('4a525e'))
    c.vline(tx1 + 1, tb + 2, foot, hexc('5a6270'))             # the pipe down to the roof
    c.hline(tx1 + 1, tx1 + 2, foot, hexc('5a6270'))
    # ---- the stair head: brick, a flat roof with a fascia, a steel door with a lamp over it, louvres, a vent stack
    mx0, mx1 = 128, 168
    mt = foot - 15
    c.rect(mx0, mt, mx1, foot, P['wall'])
    for yy in range(mt, foot + 1):
        if (yy - foot) % 3 == 0:
            c.hline(mx0, mx1, yy, P['course'])
    c.rect(mx0, mt, mx0 + 1, foot, P['lit'])
    c.rect(mx1 - 4, mt, mx1, foot, P['dark'])
    for yy in range(mt, foot + 1):
        if (yy - foot) % 3 == 0:
            c.hline(mx1 - 4, mx1, yy, shade(P['dark'], 0.9))
    c.rect(mx0 - 1, mt - 2, mx1 + 1, mt - 1, P['trim'])          # the roof slab: a fascia
    c.hline(mx0 - 1, mx1 + 1, mt - 3, hexc('3a3d44'))           # its tar edge
    c.hline(mx0 - 1, mx1 + 1, mt - 2, P['trim_hi'])
    c.hline(mx0, mx1, mt, hexc('6a4030'))
    c.hline(mx0, mx1, mt + 1, (8, 6, 12, 50))
    dx0 = mx0 + 5                                              # the door: a steel leaf in a frame, a handle, a number plate, a lamp
    c.rect(dx0 - 1, mt + 4, dx0 + 6, foot, P['trim'])
    c.rect(dx0, mt + 5, dx0 + 5, foot, hexc('6a7480'))
    c.vline(dx0, mt + 5, foot, hexc('8d98a6'))
    c.vline(dx0 + 5, mt + 5, foot, hexc('50596a'))
    c.hline(dx0, dx0 + 5, mt + 8, hexc('565f6e'))
    c.put(dx0 + 4, mt + 9, hexc('e8c46a'))
    c.rect(dx0 + 1, mt + 6, dx0 + 2, mt + 6, hexc('d8d4c4'))
    c.rect(dx0 + 2, mt + 2, dx0 + 3, mt + 3, hexc('3a3d44'))      # a caged lamp over it
    c.put(dx0 + 2, mt + 3, hexc('f6e6a8'))
    lx0 = mx0 + 16                                             # louvres: slats with dark gaps, in a frame
    c.rect(lx0 - 1, mt + 3, lx0 + 12, mt + 12, P['trim'])
    c.rect(lx0, mt + 4, lx0 + 11, mt + 11, hexc('2a2d34'))
    for k in range(4):
        c.hline(lx0, lx0 + 11, mt + 4 + k * 2, hexc('8a8f96'))
        c.hline(lx0, lx0 + 11, mt + 5 + k * 2, hexc('5e6470'))
    c.rect(mx1 - 11, mt + 3, mx1 - 8, mt + 7, hexc('3a3d44'))      # a small window with a grille
    c.hline(mx1 - 11, mx1 - 8, mt + 5, hexc('6a7480'))
    c.vline(mx1 - 10, mt + 3, mt + 7, hexc('6a7480'))
    c.vline(mx1 - 9, mt + 3, mt + 7, hexc('6a7480'))
    stk = mx0 + 31                                             # a vent stack through the roof slab with a cowl
    c.rect(stk, mt - 6, stk + 1, mt - 3, hexc('8e96a2'))
    c.vline(stk, mt - 6, mt - 3, hexc('b4bcc6'))
    c.hline(stk - 1, stk + 2, mt - 7, hexc('5a6270'))
    c.put(stk - 1, mt - 8, hexc('7a8290'))
    c.put(stk + 2, mt - 8, hexc('7a8290'))
    # ---- condenser units on a rail (right): a casing, a round grille with a fan, a pipe run
    for ax in (180, 192):
        c.rect(ax, foot - 7, ax + 9, foot - 1, hexc('c9ccc6'))
        c.vline(ax, foot - 7, foot - 1, hexc('e6e8e2'))
        c.vline(ax + 9, foot - 7, foot - 1, hexc('8e928c'))
        c.hline(ax, ax + 9, foot - 7, hexc('eceee8'))
        c.hline(ax, ax + 9, foot - 1, hexc('6e726c'))
        c.ellipse(ax + 4.5, foot - 4, 3.2, 3.0, hexc('3a3d44'))
        for (fxx, fyy) in ((0, -2), (1, -1), (2, 0), (1, 1), (0, 2), (-1, 1), (-2, 0), (-1, -1)):
            c.put(int(ax + 4.5) + fxx, foot - 4 + fyy, hexc('70757e'))
        c.put(int(ax + 4.5), foot - 4, hexc('9aa0a8'))
        c.hline(ax, ax + 9, foot, hexc('2d333d'))               # its rail
    c.hline(190, 191, foot - 5, hexc('b87a4a'))                  # pipework between them
    c.hline(190, 191, foot - 4, hexc('8a5a38'))
    # ---- the lattice mast with a yagi, two dishes and a beacon, standing on the main roof beside the stair head
    mxx = 172
    top_y = 0
    for yy in range(top_y + 1, foot):                              # two legs with a zig-zag of bracing between them
        c.put(mxx, yy, hexc('59616d'))
        c.put(mxx + 2, yy, hexc('3e4651'))
        if yy % 2 == 0:
            c.put(mxx + 1, yy, hexc('6a7380'))
    c.vline(mxx + 1, top_y + 1, foot, hexc('3a414c'))
    c.hline(mxx - 1, mxx + 3, foot, hexc('2d333d'))                 # its foot plate
    c.rect(mxx - 1, top_y, mxx + 3, top_y + 1, hexc('8a1e1e'))      # the beacon's housing; the game blinks a light over it
    c.put(mxx + 1, top_y, hexc('e84a3a'))
    for (yy, ln) in ((top_y + 4, 3), (top_y + 6, 4), (top_y + 8, 5)):        # a yagi: a boom with elements, the longest at the back
        c.hline(mxx + 1 - ln, mxx + 1 + ln, yy, hexc('b4bcc6'))
        c.put(mxx + 1 - ln, yy, hexc('7a8290'))
    c.vline(mxx + 1, top_y + 3, top_y + 9, hexc('8a929e'))
    c.hline(mxx + 3, mxx + 4, top_y + 12, hexc('5a6270'))            # a dish on a bracket, facing right
    c.ellipse(mxx + 7, top_y + 12, 2.6, 2.6, hexc('dcdad0'))
    c.ellipse(mxx + 7, top_y + 12, 1.4, 1.4, hexc('b4b2a8'))
    c.put(mxx + 7, top_y + 12, hexc('5a5a58'))
    c.put(mxx + 5, top_y + 9, hexc('3a3a3a'))
    c.hline(mxx - 3, mxx - 1, top_y + 14, hexc('5a6270'))            # a smaller one on the left
    c.ellipse(mxx - 5, top_y + 14, 2.2, 2.2, hexc('cfcdc3'))
    c.put(mxx - 5, top_y + 14, hexc('5a5a58'))
    # ---- cables: guys from the mast to the parapet and a run to the stair head
    for (x0, y0, x1, y1) in ((mxx + 3, top_y + 10, G.BX1 - 3, foot - 1), (mxx - 1, top_y + 10, 168, foot - 15)):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            c.put(x0 + (x1 - x0) * i // n, y0 + (y1 - y0) * i // n, hexc('2d333d'))
    meta['beacon'] = [{'x': mxx + 1, 'y': top_y}]
