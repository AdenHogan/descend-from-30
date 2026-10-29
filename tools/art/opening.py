#!/usr/bin/env python3
"""THE OPENING — the exterior shot a NEW GAME begins on (owner round 35: "a nice pixel art exterior image of our building,
clouds in the sky, city scape in the background. Camera pans up the building, then the title of the game, fade to black, then the
run information").

THREE LOOKS (owner round 35b: "three versions for different run times… a player loading a file might be on a run 2 or 3 save…
that exterior can also be used to show more damage and disaster outside"): run 1 MORNING, run 2 AFTERNOON (the sun low and orange, lamps on, more
broken windows, a wrecked street, fires in the city), run 3 NIGHT (stars, a moon, a blood-orange horizon, a breach in the wall, the street
burning). Files are `<layer>_<run>.png` + `opening_meta_<run>.json`. The BURNT FLOORS are NOT baked: the game reads this playthrough's real
fire (`WorldState.fire_intensity`) and lays `burn.png`'s charred windows, soot and animated flames on those floors.

ONE look at a time, drawn at the game's native look (288x162 shown at 4x = the 1152x648 screen) as PARALLAX LAYERS the game slides at
different rates while the camera climbs the tower from the street to the roof:

    sky.png    p 0.30   dithered dawn gradient + a low sun            (288 x 330)
    clouds.png  --      an atlas of pixel clouds, placed + drifted by the game (opening_meta.json "clouds")
    far.png    p 0.50   pale hazy skyline, a crane, a radio mast      (288 x 230)
    mid.png    p 0.75   darker towers with window grids, rooftop kit  (288 x 300)
    scene.png  p 1.00   THE BUILDING (30 floors), its entrance, the street, a wrecked car (288 x 526)
    fore.png   p 1.30   a telegraph pole + wires + crows              (288 x 200)

The building's three sections read like the corridors inside it (owner: sectional identity): floors 21-30 faded hotel stone with a
cornice, 11-20 brick, 1-10 grey institutional concrete, getting more dilapidated downward — a sheet hung out saying HELP, a burnt
stretch with soot, boarded and broken windows, a few lamps still on. Floor 30 (where you wake) keeps one warm window.

Everything the game animates (smoke from the burnt windows, a flickering lamp, the roof beacon, the clouds, birds) is listed in
`assets/opening/opening_meta.json` in each layer's own pixel coordinates.

    python3 tools/art/opening.py            # writes assets/opening/*
    python3 tools/art/opening.py --preview  # also docs/art_reference/opening.png (composites at several camera heights)
    python3 tools/art/opening.py --check    # the gate: regenerate in memory, compare to the files on disk
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from PIL import Image  # noqa: E402
from pixlib import Canvas, hexc, mix, shade  # noqa: E402
import opening_sky  # noqa: E402
import opening_city  # noqa: E402
import opening_birds  # noqa: E402

RUNS = (1, 2, 3)
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'opening')

W = 288
VIEW_H = 162

# ---- the building (scene.png coordinates) -----------------------------------------------------------------------------
BX0, BX1 = 78, 209                 # facade, inclusive (132 wide)
BAYS = 8
BAY_W = 15
INNER_X0 = BX0 + 6                 # 6 px pilaster each side, 8 bays of 15 between
FH = 14                            # a floor
TOP_Y = 30                         # floor 30's top edge
LOBBY_Y = TOP_Y + 30 * FH          # 450
LOBBY_H = 32
GROUND_Y = LOBBY_Y + LOBBY_H       # 482 — the sidewalk's top
SCENE_H = 526
PARAPET_Y = 22

SKY_H, FAR_H, MID_H, FORE_H = 330, 230, 300, 200
GARDEN_P = 1.18                    # the garden layer slides this much per px of camera climb (the building 1.00): the 2.5D separation
STREET_FROM_BOTTOM = 44            # the ground line sits this far above each city layer's bottom


def floor_y(n):
    """Top row of floor n's band (30 = the top floor)."""
    return TOP_Y + (30 - n) * FH


def section(n):
    return 'hotel' if n >= 21 else 'brick' if n >= 11 else 'concrete'


PAL = {
    'hotel': dict(wall=hexc('e0d0a8'), lit=hexc('ece0bd'), dark=hexc('bba988'), trim=hexc('46777d'), frame=hexc('6a4a36'),
                  band=hexc('f0e6c8'), mortar=None),
    'brick': dict(wall=hexc('a85e44'), lit=hexc('b96d50'), dark=hexc('864a38'), trim=hexc('d9c19c'), frame=hexc('e3dcc8'),
                  band=hexc('cdb48f'), mortar=hexc('8a5040')),
    'concrete': dict(wall=hexc('a09a8a'), lit=hexc('b4ae9c'), dark=hexc('807a6d'), trim=hexc('cfc9b8'), frame=hexc('3e4654'),
                     band=hexc('857f72'), mortar=None),
}

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x, y):
    return (BAYER[y & 3][x & 3] + 0.5) / 16.0


def lerp_stops(stops, t):
    for i in range(len(stops) - 1):
        if stops[i][0] <= t <= stops[i + 1][0]:
            u = (t - stops[i][0]) / max(1e-6, stops[i + 1][0] - stops[i][0])
            return mix(stops[i][1], stops[i + 1][1], u)
    return stops[-1][1]


# ================================================================================================================ LOOKS
# The sky, the clouds and the skyline live in opening_sky.py / opening_city.py (owner round 49 — they read as a generated look: one
# gradient, one set of puffballs recoloured three times, rectangles with random windows). What stays here is what the BUILDING and the
# street need per time of day.
LOOK = {
    1: dict(grade=None, wear=0.0, lit_p=0.07, helps=0, city_fires=0, city_smokes=(0, 0), survivors=0.22, city_lit=(0.04, 0.07), columns=(0, 0)),
    2: dict(grade=dict(sat=0.88, mul=(1.00, 0.91, 0.76), add=(5, 0, -4)), wear=0.07, lit_p=0.16, helps=2, city_fires=2, city_smokes=(3, 2),
            survivors=0.15, city_lit=(0.08, 0.12), columns=(2, 0)),
    3: dict(grade=dict(sat=0.60, mul=(0.27, 0.23, 0.21), add=(6, 2, 0)), wear=0.13, lit_p=0.05, helps=3, city_fires=5, city_smokes=(4, 3),
            survivors=0.55, city_lit=(0.06, 0.10), columns=(3, 0)),
}
NIGHT_GLOWS = [(58, 304, 1.5), (118, 312, 1.1), (204, 306, 1.6), (262, 300, 1.2)]      # where the fires stand, under the night's cloud deck


# =============================================================================================================== SKY
def draw_sky(run):
    return opening_sky.paint_sky(run, W, SKY_H, fires=NIGHT_GLOWS if run == 3 else None)


def draw_clouds(run):
    """The atlas of drifting clouds: ten cells, the SAME sizes in every run (the game places them by index), each time of day with its
    own kinds (opening_sky.CELL_KINDS)."""
    specs = [('big', 84, 34), ('big', 72, 30), ('big', 96, 38), ('mid', 52, 20), ('mid', 44, 18), ('mid', 60, 22),
             ('wisp', 80, 9), ('wisp', 64, 8), ('mid', 36, 14), ('big', 64, 26)]
    sprites = [opening_sky.cloud_cell(w, h, 31 + i * 7 + run, opening_sky.CELL_KINDS[run][k], run) for i, (k, w, h) in enumerate(specs)]
    aw = max(s.width for s in sprites)
    ah = sum(s.height + 2 for s in sprites)
    atlas = Image.new('RGBA', (aw, ah), (0, 0, 0, 0))
    meta = []
    y = 0
    for i, s in enumerate(sprites):
        atlas.paste(s, (0, y))
        meta.append({'i': i, 'x': 0, 'y': y, 'w': s.width, 'h': s.height, 'kind': specs[i][0]})
        y += s.height + 2
    return atlas, meta


# ============================================================================================================= CITY
def draw_far(run):
    L = LOOK[run]
    return opening_city.skyline('far', W, FAR_H, FAR_H - STREET_FROM_BOTTOM, run, L['city_lit'][0], sun_gap=(34, 100, 30), extras=True,
                                columns=L['columns'][0], low=[(0, 60, 56)])


def draw_mid(run):
    L = LOOK[run]
    return opening_city.skyline('mid', W, MID_H, MID_H - STREET_FROM_BOTTOM, run, L['city_lit'][1], sun_gap=(30, 104, 44), low=[(0, 72, 70)],
                                columns=L['columns'][1])


# ======================================================================================================= THE BUILDING
FONT3 = {
    'H': ['X.X', 'X.X', 'XXX', 'X.X', 'X.X'],
    'E': ['XXX', 'X..', 'XX.', 'X..', 'XXX'],
    'L': ['X..', 'X..', 'X..', 'X..', 'XXX'],
    'P': ['XX.', 'X.X', 'XX.', 'X..', 'X..'],
    'S': ['XXX', 'X..', 'XXX', '..X', 'XXX'],
    'O': ['XXX', 'X.X', 'X.X', 'X.X', 'XXX'],
}


def text3(c, x, y, word, col):
    for ch in word:
        g = FONT3[ch]
        for yy, row in enumerate(g):
            for xx, v in enumerate(row):
                if v == 'X':
                    c.put(x + xx, y + yy, col)
        x += 4


GLASS_TOP, GLASS_BOT = hexc('9cc3e2'), hexc('6d97bd')
DARK_IN = hexc('3e4256')
CURTAINS = [hexc('d9c9a2'), hexc('b8665c'), hexc('7e9a8a'), hexc('d6d2c4'), hexc('c79a6a'), hexc('8d7fa5')]
# every window is its own: a glass tint, an interior tone, a way of being dressed (owner round 36f: "many of the windows look too much
# like copy and pasted… improvements can be made to colouring"). All of it comes from the window's OWN seeded rng, so it is the same in
# every run (the tower doesn't change — only the light and the damage do).
GLASS_TINTS = [hexc('b4c8dc'), hexc('9cb8cc'), hexc('a8c0b0'), hexc('c4c0d8'), hexc('8fb0c8'), hexc('b8c8b8')]
INTERIORS = [hexc('3a4a58'), hexc('46404e'), hexc('2e3a46'), hexc('4a4640'), hexc('3c4a44'), hexc('50424a')]
LIT_KINDS = ('warm', 'warm', 'amber', 'tv', 'white', 'rose')
LIT_COLS = {'warm': (hexc('ffd37c'), hexc('ffeaa8'), hexc('d99a48')),
            'amber': (hexc('ffb85c'), hexc('ffd890'), hexc('c4742c')),
            'tv': (hexc('9cc4f0'), hexc('d8ecff'), hexc('5a7cae')),
            'white': (hexc('f2efe0'), hexc('ffffff'), hexc('a8a698')),
            'rose': (hexc('f2a890'), hexc('ffd2c0'), hexc('b86a58'))}
SHIRTS = [hexc('c9605a'), hexc('4f7ab0'), hexc('d8c25a'), hexc('5aa070'), hexc('b58ad0'), hexc('e8e4d8'), hexc('d8884a')]


def bay_x(b):
    return INNER_X0 + b * BAY_W


def draw_window(c, bx, y, state, sec, rng, meta, floor, bay, survivor=0.0):
    """bx = the bay's left x, y = the floor band's top. Frame 11x10 at (bx+2, y+2), glass 9x8 inside it.
    `survivor` = the chance (0..1) that a LIT window has someone at it (the game animates them: meta['survivors'])."""
    P = PAL[sec]
    fx, fy = bx + 2, y + 2
    c.rect(fx, fy, fx + 10, fy + 9, P['frame'])
    gx, gy = fx + 1, fy + 1
    gtop = mix(GLASS_TOP, rng.choice(GLASS_TINTS), 0.45)
    gbot = mix(GLASS_BOT, rng.choice(GLASS_TINTS), 0.35)
    dark_in = mix(DARK_IN, rng.choice(INTERIORS), 0.55)
    glint = rng.choice((0, 0, 1, 2, 3))                                # which reflection (3 = none)
    style = rng.choice(('drapes', 'sheer', 'blinds', 'half', 'tied'))
    lit_kind = rng.choice(LIT_KINDS)
    dark_kind = rng.choice(('plain', 'plain', 'plant', 'shelf', 'lamp', 'frame'))
    # the glass
    for yy in range(8):
        for xx in range(9):
            t = yy / 7.0
            col = mix(gtop, gbot, t)
            if state in ('dark', 'curtain', 'open', 'lit', 'broken', 'boarded', 'burnt'):
                col = mix(dark_in, hexc('59647a'), 0.25 * (1 - t))
            c.put(gx + xx, gy + yy, col)
    if state in ('dark', 'curtain', 'open') and glint < 3:
        # the sky's reflection: a pale diagonal glint across the glass
        if glint == 0:
            for k in range(4):
                c.put(gx + 1 + k, gy + 3 - k, hexc('b4d2ea'))
            for k in range(3):
                c.put(gx + 4 + k, gy + 5 - k, hexc('88acc8'))
        elif glint == 1:
            for k in range(5):
                c.put(gx + 3 + k, gy + 5 - k, hexc('b4d2ea'))
            c.put(gx + 2, gy + 6, hexc('88acc8'))
        else:
            for k in range(3):
                c.put(gx + 1 + k, gy + 2 - k + 1, hexc('b4d2ea'))
            c.put(gx + 7, gy + 1, hexc('88acc8'))
            c.put(gx + 6, gy + 2, hexc('88acc8'))
    if state == 'dark':
        if dark_kind == 'plant':                                     # a plant on the inside sill
            c.rect(gx + 6, gy + 6, gx + 7, gy + 7, hexc('8a5a3c'))
            c.rect(gx + 5, gy + 3, gx + 8, gy + 5, hexc('3f6a3c'))
            c.put(gx + 6, gy + 2, hexc('4f8a4a'))
        elif dark_kind == 'shelf':
            c.hline(gx + 1, gx + 7, gy + 3, hexc('2a2430'))
            for k in range(0, 6, 2):
                c.vline(gx + 2 + k, gy + 1, gy + 2, rng.choice((hexc('7a4a3a'), hexc('3a5a6a'), hexc('8a7a50'))))
        elif dark_kind == 'lamp':                                    # a standard lamp, off
            c.vline(gx + 7, gy + 3, gy + 7, hexc('2a2430'))
            c.rect(gx + 6, gy + 1, gx + 8, gy + 3, hexc('5a5448'))
        elif dark_kind == 'frame':
            c.rect(gx + 5, gy + 1, gx + 7, gy + 3, hexc('5a4a3a'))
            c.rect(gx + 6, gy + 2, gx + 6, gy + 2, hexc('7a8a7a'))
    if state == 'curtain':
        col = rng.choice(CURTAINS)
        dk = shade(col, 0.78)
        wd = rng.choice((2, 3))
        if style == 'drapes':
            for yy in range(8):
                for xx in range(wd):
                    c.put(gx + xx, gy + yy, col if (yy + xx) % 3 else dk)
                    c.put(gx + 8 - xx, gy + yy, col if (yy + xx) % 3 else dk)
            if rng.random() < 0.35:                                 # drawn right across
                for yy in range(8):
                    for xx in range(wd, 9 - wd):
                        c.put(gx + xx, gy + yy, col if (yy * 2 + xx) % 4 else dk)
        elif style == 'sheer':                                      # a pale net across the whole pane, a fold or two
            for yy in range(8):
                for xx in range(9):
                    base = c.px[gx + xx, gy + yy]
                    c.put(gx + xx, gy + yy, mix(base, hexc('e8e4d8'), 0.55 if (xx + yy // 2) % 3 else 0.4))
        elif style == 'blinds':                                     # venetian slats, lowered part way
            drop = rng.choice((3, 5, 7))
            for yy in range(drop):
                for xx in range(9):
                    c.put(gx + xx, gy + yy, shade(col, 0.95) if yy % 2 == 0 else dk)
            c.put(gx + 4, gy + drop, hexc('c4bca8'))
        elif style == 'half':                                       # one side only, drawn back
            side = rng.choice((0, 1))
            for yy in range(8):
                for xx in range(wd + 1):
                    x_ = gx + xx if side == 0 else gx + 8 - xx
                    c.put(x_, gy + yy, col if (yy + xx) % 3 else dk)
        else:                                                       # tied back at the middle height, a pinch of colour
            for yy in range(8):
                pinch = 1 if 3 <= yy <= 4 else wd
                for xx in range(pinch):
                    c.put(gx + xx, gy + yy, col if (yy + xx) % 3 else dk)
                    c.put(gx + 8 - xx, gy + yy, col if (yy + xx) % 3 else dk)
            c.put(gx + 1, gy + 3, hexc('d8c070'))
            c.put(gx + 7, gy + 3, hexc('d8c070'))
    elif state == 'lit':
        glow, core, sill = LIT_COLS[lit_kind]
        if survivor > 0.0 and rng.random() < survivor:
            glow, core, sill = LIT_COLS['warm']                      # someone at the window: a plain warm room so they read against it
            lit_kind = 'warm'
            has_person = True
        else:
            has_person = False
        for yy in range(8):
            for xx in range(9):
                if lit_kind == 'tv':                                 # a cool flicker of a screen, the rest of the room dim
                    f = (xx * 3 + yy * 5) % 7
                    c.put(gx + xx, gy + yy, mix(glow, hexc('2e3a52'), 0.15 + 0.5 * (abs(xx - 4) / 5.0)) if f else core)
                elif lit_kind == 'amber' and (xx < 2 or xx > 6):     # a lamp's pool: the corners stay dim
                    c.put(gx + xx, gy + yy, mix(glow, dark_in, 0.45))
                else:
                    c.put(gx + xx, gy + yy, glow if (xx + yy) % 5 else core)
        c.hline(gx, gx + 8, gy + 7, sill)
        wd = rng.choice((1, 2))
        col = rng.choice(CURTAINS)
        for yy in range(8):
            for xx in range(wd):
                c.put(gx + xx, gy + yy, shade(col, 0.95))
                c.put(gx + 8 - xx, gy + yy, shade(col, 0.95))
        if has_person:
            kinds = ('wave', 'pace', 'peer', 'sway', 'pound', 'shout', 'huddle', 'phone', 'slump')
            meta['survivors'].append({'x': gx, 'y': gy, 'w': 9, 'h': 8, 'floor': floor, 'bay': bay,
                                      'kind': rng.choice(kinds), 'shirt': '%02x%02x%02x' % tuple(rng.choice(SHIRTS)[:3]),
                                      'phase': round(rng.random() * 6.28, 2)})
        meta['lit'].append({'x': gx, 'y': gy, 'w': 9, 'h': 8, 'floor': floor, 'bay': bay})
    elif state == 'open':
        # a casement thrown open (its pane edge-on), the curtain blown out over the sill
        c.vline(gx + 6, gy, gy + 7, hexc('d8d8d0'))
        c.vline(gx + 7, gy + 1, gy + 7, hexc('9aa0a8'))
        col = rng.choice(CURTAINS)
        for k in range(6):
            c.put(gx + 1 + (k % 3), gy + k, col)
            c.put(gx + 2 + (k % 2), gy + k, shade(col, 0.82))
        for k in range(4):
            c.put(fx + 10 + (k % 2), fy + 2 + k, col)
    elif state == 'broken':
        for (x1, y1, x2, y2) in ((4, 0, 4, 3), (4, 3, 1, 5), (4, 3, 7, 6), (7, 6, 8, 7), (1, 5, 0, 7)):
            n = max(abs(x2 - x1), abs(y2 - y1), 1)
            for i in range(n + 1):
                c.put(gx + x1 + (x2 - x1) * i // n, gy + y1 + (y2 - y1) * i // n, hexc('dfe9f0'))
        c.rect(gx + 5, gy + 4, gx + 8, gy + 7, hexc('1c1e2a'))
    elif state == 'boarded':
        wood = rng.choice((hexc('9a7650'), hexc('8a6a48'), hexc('a88458')))
        dk = shade(wood, 0.72)
        for k, yy in enumerate((1, 4)):
            c.rect(gx - 1, gy + yy, gx + 9, gy + yy + 1, wood)
            c.hline(gx - 1, gx + 9, gy + yy + 1, dk)
            c.put(gx + 1, gy + yy, dk)
            c.put(gx + 7, gy + yy, dk)
    elif state == 'burnt':
        c.rect(gx, gy, gx + 8, gy + 7, hexc('171418'))
        for _ in range(5):
            c.put(gx + rng.randrange(1, 8), gy + rng.randrange(3, 8), hexc('c4552a'))
        # sooty frame and a black plume licking up the wall above
        for xx in range(11):
            c.put(fx + xx, fy, hexc('2b231f'))
            c.put(fx + xx, fy + 9, hexc('2b231f'))
        for yy in range(10):
            c.put(fx, fy + yy, hexc('2b231f'))
            c.put(fx + 10, fy + yy, hexc('2b231f'))
        for k in range(1, 15):
            a = int(185 * (1.0 - k / 15.0))
            half = 3 + k // 3
            for xx in range(-half, half + 1):
                if rng.random() < 0.85 - k * 0.04:
                    c.put(fx + 5 + xx + int(math.sin(k * 0.8) * 1.5), fy - k, (30, 24, 24, max(0, a - abs(xx) * 12)))
        meta['smoke'].append({'x': fx + 5, 'y': fy - 2, 'floor': floor, 'bay': bay})
    # the opening is a RECESS in a thick wall: its left jamb and head cast a shadow onto the glass, the sill throws light back up
    if state in ('dark', 'curtain', 'lit', 'open', 'broken'):
        for yy in range(8):
            c.put(gx, gy + yy, (10, 8, 16, 62))
        for xx in range(9):
            c.put(gx + xx, gy, (10, 8, 16, 78))
            c.put(gx + xx, gy + 1, (10, 8, 16, 26))
        for xx in range(1, 9):
            c.put(gx + xx, gy + 7, (255, 255, 255, 22))
    # a mullion; hotel windows get a transom
    if state in ('dark', 'curtain', 'lit', 'open'):
        c.vline(gx + 4, gy, gy + 7, P['frame'])
        if sec == 'hotel':
            c.hline(gx, gx + 8, gy + 2, P['frame'])
    # the sill with its shadow below it, and a lintel
    c.hline(fx - 1, fx + 11, fy + 10, shade(P['trim'], 1.1))
    c.hline(fx - 1, fx + 11, fy + 11, shade(P['dark'], 0.82))
    c.hline(fx - 1, fx + 11, fy - 1, P['trim'])


def draw_balcony_bay(c, bx, y, sec, rng, meta, floor, bay):
    P = PAL[sec]
    fx, fy = bx + 2, y + 2
    c.rect(fx, fy, fx + 10, fy + 9, P['frame'])
    gx, gy = fx + 1, fy + 1
    for yy in range(8):
        for xx in range(9):
            c.put(gx + xx, gy + yy, mix(DARK_IN, hexc('59647a'), 0.25 * (1 - yy / 7.0)))
    for k in range(4):
        c.put(gx + 1 + k, gy + 3 - k, hexc('b4d2ea'))
    c.vline(gx + 4, gy, gy + 7, P['frame'])
    # the slab (2 rows, 1 px proud each side) and a railing over the lower part of the door
    c.hline(bx, bx + 14, y + 12, shade(P['trim'], 1.12))
    c.hline(bx, bx + 14, y + 13, shade(P['dark'], 0.7))
    c.hline(fx - 1, fx + 11, y + 8, shade(P['trim'], 1.05))
    for xx in range(fx - 1, fx + 12):
        if (xx - fx) % 2 == 0:
            c.vline(xx, y + 9, y + 11, shade(P['frame'], 0.85) if sec != 'concrete' else hexc('2c3440'))
    # what's out on it
    r = rng.random()
    if r < 0.30:                                                     # a potted plant, alive or not
        px = fx + rng.randrange(0, 8)
        c.rect(px, y + 6, px + 2, y + 7, hexc('9b5a3c'))
        green = rng.choice((hexc('4f8a4a'), hexc('6f9a3c'), hexc('8a8450')))
        c.rect(px - 1, y + 3, px + 3, y + 5, green)
        c.put(px + 1, y + 2, green)
    elif r < 0.50:                                                   # washing on a line
        col = rng.choice(CURTAINS + [hexc('e8e8e0'), hexc('c9605a')])
        for k in range(3):
            c.rect(fx + 1 + k * 3, y + 4, fx + 2 + k * 3, y + 7, shade(col, 0.9 + 0.1 * (k % 2)))
        c.hline(fx, fx + 10, y + 4, hexc('2c2c2c'))
    elif r < 0.62:                                                   # a chair
        c.vline(fx + 6, y + 5, y + 7, hexc('4a4038'))
        c.hline(fx + 4, fx + 7, y + 6, hexc('4a4038'))
        c.vline(fx + 4, y + 7, y + 7, hexc('4a4038'))
    elif r < 0.70:                                                   # a satellite dish on the rail
        c.ellipse(fx + 8, y + 6, 2.2, 1.6, hexc('d6d6d0'))
        c.put(fx + 8, y + 6, hexc('8a8a86'))


def draw_facade(c, rng, meta, run=1):
    """The tower's 30 floors, the sectional palette, sills, balconies, windows in all their states."""
    # The SAME building in all three runs: every window's choices come from its own seeded draw, so a window that was broken in the
    # morning is still broken at dusk and the damage only ever GROWS (the thresholds below shift with the run). The burnt floors are
    # not here — the game lays those from the playthrough's real fire.
    L = LOOK[run]
    wear_shift = L['wear']
    lit_p = L['lit_p']
    balcony_bays = {1, 4, 6}
    for n in range(30, 0, -1):
        sec = section(n)
        P = PAL[sec]
        y = floor_y(n)
        # wall
        c.rect(BX0, y, BX1, y + FH - 1, P['wall'])
        if sec == 'brick':
            for yy in range(y, y + FH):
                if (yy - y) % 3 == 2:
                    c.hline(BX0, BX1, yy, P['mortar'])
                else:
                    off = ((yy - y) // 3 % 2) * 3
                    for xx in range(BX0 + off, BX1 + 1, 6):
                        c.put(xx, yy, P['mortar'])
            for _ in range(10):
                c.put(rng.randrange(BX0, BX1), y + rng.randrange(0, FH), shade(P['wall'], rng.choice((0.9, 1.08))))
        elif sec == 'hotel':
            for xx in range(BX0, BX1 + 1, 2):                          # a faint stone coursing
                c.put(xx, y + 6, shade(P['wall'], 0.94))
            c.hline(BX0, BX1, y + FH - 1, shade(P['wall'], 0.9))
        else:
            c.hline(BX0, BX1, y + 6, shade(P['wall'], 0.92))
            for xx in range(BX0 + 8, BX1, 24):
                c.vline(xx, y, y + FH - 1, shade(P['wall'], 0.94))
        # pilasters
        for (px0, px1) in ((BX0, BX0 + 5), (BX1 - 5, BX1)):
            c.rect(px0, y, px1, y + FH - 1, P['lit'] if px0 == BX0 else P['dark'])
            c.vline(px0 if px0 == BX0 else px1, y, y + FH - 1, shade(P['lit'] if px0 == BX0 else P['dark'], 0.86))
        # windows
        for b in range(BAYS):
            bx = bay_x(b)
            wr = random.Random(n * 1013 + b * 17 + 404)               # this window's own details
            sr = random.Random(n * 131 + b * 7 + 9)
            r = sr.random()
            r2 = sr.random()
            if b in balcony_bays and (n + b) % 2 == 0 and n != 30:
                draw_balcony_bay(c, bx, y, sec, wr, meta, n, b)
                continue
            if n == 30 and b == 2:
                state = 'lit'                                         # where you wake
            else:
                wear = (30 - n) / 29.0                                # more ruin the further down
                b1 = 0.07 + 0.05 * wear + wear_shift
                if r < b1:
                    state = 'broken' if r2 < 0.6 else 'boarded'
                elif r < b1 + 0.07:
                    state = 'open'
                elif r < b1 + 0.07 + lit_p:
                    state = 'lit'
                elif r < 0.56 + wear_shift:
                    state = 'curtain'
                else:
                    state = 'dark'
            draw_window(c, bx, y, state, sec, wr, meta, n, b, L['survivors'] if (n != 30 or b != 2) else 0.0)
        # the piers between the bays are slightly proud of the glass: a lit edge on the left, a shaded one on the right
        for b in range(BAYS):
            bx = bay_x(b)
            for yy in range(y + 1, y + FH - 1):
                c.put(bx + 14, yy, (255, 255, 255, 26))
                c.put(bx + 13, yy, (20, 14, 20, 34))
        # the pilasters are round-ish: a lit left edge, a shaded right one
        for (px0, px1) in ((BX0, BX0 + 5), (BX1 - 5, BX1)):
            for yy in range(y, y + FH):
                c.put(px0 + 1, yy, (255, 255, 255, 30))
                c.put(px1 - 1, yy, (10, 8, 14, 52))
        # section ledges: a cornice at the top floor and where a section begins
        if n in (30, 21, 11):
            c.hline(BX0 - 1, BX1 + 1, y, shade(P['band'], 1.1))
            c.hline(BX0 - 1, BX1 + 1, y + 1, P['band'])
            c.hline(BX0 - 2, BX1 + 2, y + 2, shade(P['band'], 0.8))
            for k_, a_ in enumerate((88, 56, 30)):                    # the ledge juts out: its shadow falls on the wall (and window heads) below
                for xx in range(BX0, BX1 + 1):
                    c.put(xx, y + 3 + k_, (8, 6, 12, a_))
        if n == 1:
            c.hline(BX0 - 1, BX1 + 1, y + FH - 1, shade(PAL['concrete']['band'], 0.8))
    # sheets hung out of windows with a word on them (more of them as it gets worse)
    for (hf, hbay, word) in [(24, 5, 'HELP'), (13, 1, 'SOS'), (6, 3, 'HELP')][:L['helps']]:
        hang_sheet(c, bay_x(hbay), floor_y(hf), word, hf * 7 + hbay, meta)
    # grime: rain streaks below sills, darker toward the street; and a lit left / shaded right
    for n in range(30, 0, -1):
        y = floor_y(n)
        wear = (30 - n) / 29.0
        for b in range(BAYS):
            bx = bay_x(b)
            if rng.random() < 0.25 + 0.35 * wear:
                sx = bx + rng.randrange(2, 12)
                ln = rng.randrange(3, 9)
                for k in range(ln):
                    px = c.px[sx, y + 12 + k] if 0 <= sx < c.w and y + 12 + k < c.h else None
                    if px and px[3]:
                        a = int(70 * (1 - k / ln))
                        c.put(sx, y + 12 + k, (40, 34, 30, a))
    # the lit / shaded sides of the whole block, so it has a form against the sun
    for x in range(BX0, BX1 + 1):
        t = (x - BX0) / float(BX1 - BX0)
        k = 1.07 - 0.20 * t
        for y in range(TOP_Y, LOBBY_Y):
            r, g, b, a = c.px[x, y]
            if a:
                c.px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a)
    # the right-hand edge in shadow, the left in light
    c.vline(BX0 - 1, TOP_Y, GROUND_Y - 1, hexc('f3ead0'))
    c.vline(BX1 + 1, TOP_Y, GROUND_Y - 1, hexc('5a4c44'))
    if run == 2:
        wreck_balcony(c, bay_x(4), floor_y(14))
    if run == 3:
        wreck_balcony(c, bay_x(4), floor_y(14))
        breach(c, bay_x(3) + 3, floor_y(8) + 1, meta)


def hang_sheet(c, bx, y, word, seed, meta):
    """A bedsheet hung out of the window whose floor band starts at row `y` (bay x `bx`), with the word painted on it.

    Owner round 49 ("help signs clipping things"): the old sheet was a flat 20 x 13 rectangle painted over the whole facade — wider than its
    window, so it ran over the piers and the frames of the windows either side. This one is exactly as wide as a window frame plus a pixel
    each side (13), is tied by its top corners to its own sill and falls over the window BELOW it — whole, never half over a neighbour —
    with folds, a lit edge and a shaded one, a ragged hem, a shadow on the wall, and letters painted by hand (each a pixel off the last,
    one running). HELP is set on two lines (HE / LP) so it fits a window's width; SOS fits on one."""
    rr = random.Random(seed * 31 + 7)
    fx = bx + 2                                                   # the window frame's left edge (the frame is 11 wide)
    x0, x1 = fx - 1, fx + 11                                      # 13 wide: a pixel proud of the frame each side, clear of the piers
    top = y + 12                                                  # the window's own sill row
    bot = y + 25                                                  # the lower window's frame ends here; the hem sits at its foot
    base, lit, shd, fold = hexc('ece6d6'), hexc('f6f1e4'), hexc('c9c2b0'), hexc('d9d2c0')
    for yy in range(top, bot + 1):                                # a faint shadow the sheet throws on the wall to its right and below
        c.put(x1 + 1, yy + 1, (22, 16, 20, 70))
        c.put(x1 + 2, yy + 2, (22, 16, 20, 34))
    for xx in range(x0 + 1, x1 + 2):
        c.put(xx, bot + 1, (22, 16, 20, 60))
    hem = {k: bot - (1 if (k * 5 + seed) % 7 in (0, 3) else 0) for k in range(x0, x1 + 1)}     # a ragged hem: a notch or two
    for xx in range(x0, x1 + 1):
        k = xx - x0
        col = lit if k == 0 else shd if k == x1 - x0 else (fold if k % 4 == 2 else base)
        for yy in range(top, hem[xx] + 1):
            c.put(xx, yy, col)
        if k % 4 == 2:                                            # a fold drawn down the cloth, fading toward the hem
            for yy in range(top + 1, hem[xx] - 3):
                c.put(xx, yy, mix(fold, shd, 0.35 if yy % 2 else 0.1))
    for xx in range(x0, x1 + 1):                                  # the hem: a darker row, and the top edge where it is tied
        c.put(xx, hem[xx], shd)
        c.put(xx, top, mix(base, shd, 0.5))
    knot = hexc('4a4038')
    for kx in (x0, x1):                                           # tied to the sill at both top corners, the ends hanging
        c.put(kx, top, knot)
        c.put(kx, top - 1, knot)
        c.put(kx + (1 if kx == x0 else -1), top + 1, mix(knot, base, 0.4))
    red = hexc('b3231c')
    lines = ['HE', 'LP'] if word == 'HELP' else [word]
    lh = 6 if len(lines) == 2 else 0
    ty = top + 3 if len(lines) == 2 else top + 6
    for li, ln in enumerate(lines):
        tw = len(ln) * 4 - 1
        tx = x0 + (x1 - x0 + 1 - tw) // 2
        for k, ch in enumerate(ln):
            jy = rr.choice((0, 0, 1))                             # painted by hand: each letter a little off the line
            text3(c, tx + k * 4, ty + li * lh + jy, ch, red)
            if rr.random() < 0.34:                                # and the paint ran on one
                for d in range(1, rr.choice((2, 3))):
                    c.put(tx + k * 4 + rr.choice((0, 1, 2)), ty + li * lh + jy + 5 + d - 1, mix(red, base, 0.25 + 0.2 * d))
    meta['helps'].append({'x': x0, 'y': top, 'w': x1 - x0 + 1, 'h': bot - top + 1, 'word': word})


def wreck_balcony(c, bx, y):
    """A balcony whose far half has gone: the slab and rail hang from one side, the door behind it stands open on black."""
    for yy in range(y + 8, y + 14):
        for xx in range(bx + 8, bx + 15):
            c.put(xx, yy, mix(DARK_IN, hexc('1c1e2a'), 0.5))
    for k in range(7):                                             # the rail, slanting down from the post that is left
        c.put(bx + 7 + k, y + 9 + k // 2, hexc('2c3440'))
        c.put(bx + 7 + k, y + 10 + k // 2, hexc('4a5262'))
    c.hline(bx, bx + 7, y + 12, hexc('e0d9c4'))
    c.hline(bx, bx + 7, y + 13, hexc('3e362e'))
    for k in range(5):                                             # the slab's broken end
        c.put(bx + 8 + k, y + 14 + k // 2, hexc('b8b19c'))


def breach(c, x, y, meta=None):
    """A hole blown through the wall, about two windows wide and a floor and a half high (owner round 49: "broken holes in the walls… a clear
    lack of finesse"). It was a black smudge with a lit edge; it is now a wall that has been broken open:
      * a ragged opening cut by noise, its RIM the broken wall in layers — the cream facing stone, the grey concrete behind it, a patch of
        red brick, the pits of spalling round the edge — lit on top and shadowed beneath;
      * REBAR bent out of the rim, a sheet of floor slab hanging off one side;
      * the flat seen in section through it: the ceiling slab and the floor slab as bands, wallpaper, a doorway, a wardrobe and a bed head
        in silhouette, a pendant lamp on its flex, and a low red-orange glow from something burning inside;
      * cracks running out across the facade, a fall of soot above, and rubble and splinters spilled down the face below.
    `meta['breach']` tells the game where the hole is, so it can light it (flames, a flicker, smoke)."""
    import numpy as np
    import opening_sky as K
    rng = random.Random(77)
    w, h = 33, 23
    gx, gy = np.meshgrid(np.arange(w, dtype=np.float64), np.arange(h, dtype=np.float64))
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0 + 1.0
    nz = K.fbm(gx * 0.42 + 3.0, gy * 0.42 + 9.0, 71, 4)
    rr = np.sqrt(((gx - cx) / (w * 0.5)) ** 2 + ((gy - cy) / (h * 0.5)) ** 2)
    inside = rr < 0.98 + (nz - 0.5) * 0.95
    inside[:2, :] = False
    inside[h - 1:, :] = False
    edge = inside & ~(np.roll(inside, 1, 0) & np.roll(inside, -1, 0) & np.roll(inside, 1, 1) & np.roll(inside, -1, 1))
    near_edge = np.zeros_like(inside)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            near_edge |= np.roll(np.roll(edge, dy, 0), dx, 1)
    layer_n = K.fbm(gx * 0.85 + 11.0, gy * 0.85 + 5.0, 83, 3)
    near_edge &= inside
    # the flat behind: ceiling slab, wallpaper, floor slab (rows are in the hole's own frame)
    ceil_y, floor_y_ = 4, 15
    for dy in range(h):
        for dx in range(w):
            if not inside[dy, dx]:
                continue
            if dy <= ceil_y:
                col = hexc('2e2a2e') if dy == ceil_y else hexc('1b181d')                 # the ceiling slab, its underside
            elif dy >= floor_y_:
                col = hexc('5a544e') if dy == floor_y_ else (hexc('2c262a') if dy == floor_y_ + 1 else hexc('141116'))   # the floor slab: a lit lip, then its shadow
            else:
                t = (dy - ceil_y) / float(floor_y_ - ceil_y)
                paper = mix(hexc('2a2127'), hexc('3a2a2a'), t)
                col = mix(paper, hexc('4a3030'), 0.35) if dx % 4 == 1 else paper                 # wallpaper stripes
            c.put(x + dx, y + dy, col)
    # furniture in section: a wardrobe at the left, a bed head at the right, a doorway between, a pendant lamp
    for dx in range(4, 10):
        for dy in range(7, floor_y_):
            if inside[dy, dx]:
                c.put(x + dx, y + dy, hexc('28222a') if dx > 4 else hexc('3a2e34'))
    for dx in range(22, 29):
        for dy in range(10, floor_y_):
            if inside[dy, dx]:
                c.put(x + dx, y + dy, hexc('2a2226') if dy > 11 else hexc('4a3838'))
    for dy in range(7, floor_y_):                                                             # a doorway: darker, a jamb
        for dx in range(14, 18):
            if inside[dy, dx]:
                c.put(x + dx, y + dy, hexc('0e0c10') if 14 < dx < 17 else hexc('3a2c2e'))
    c.vline(x + 19, y + ceil_y + 1, y + 8, hexc('555058'))                                    # a pendant lamp hanging on its flex
    c.put(x + 19, y + 9, hexc('8a7a50'))
    c.put(x + 18, y + 9, hexc('5a5040'))
    c.put(x + 20, y + 9, hexc('5a5040'))
    for dx in range(w):                                                                       # a low red-orange glow along the floor: something burns inside
        for dy in range(floor_y_ - 4, floor_y_):
            if inside[dy, dx] and ((dx * 7 + dy * 3) % 5 < (dy - (floor_y_ - 5))):
                c.put(x + dx, y + dy, (196, 85, 42, 150 - 28 * (floor_y_ - dy)))
    # the rim: the broken wall in layers
    for dy in range(h):
        for dx in range(w):
            if not inside[dy, dx]:
                continue
            if edge[dy, dx]:
                up = dy < cy
                base = hexc('e6dcc0') if up else hexc('6a6054')
                c.put(x + dx, y + dy, shade(base, 0.9 + 0.2 * ((dx * 13 + dy * 7) % 3) / 2.0))
            elif near_edge[dy, dx]:
                lay = layer_n[dy, dx]
                col = hexc('9a948a') if lay < 0.46 else (hexc('8a4a3c') if lay < 0.58 else hexc('b8b0a0'))   # concrete, a patch of brick, pale stone
                c.put(x + dx, y + dy, shade(col, 0.7 if dy > cy else 1.0))
    # spalling: pits of lighter plaster round the hole, and cracks running out across the facade
    for _ in range(46):
        px_, py_ = x + rng.randrange(-5, w + 5), y + rng.randrange(-4, h + 6)
        ok = not (0 <= px_ - x < w and 0 <= py_ - y < h and inside[py_ - y, px_ - x])
        near = any(0 <= px_ - x + ddx < w and 0 <= py_ - y + ddy < h and inside[py_ - y + ddy, px_ - x + ddx] for ddx in (-3, 0, 3) for ddy in (-3, 0, 3))
        if ok and near:
            c.put(px_, py_, hexc('f0e8d2') if rng.random() < 0.5 else hexc('7a7064'))
    for (sx, sy, dx_, dy_) in ((3, 3, -1, -1), (w - 3, 4, 1, -1), (5, h - 3, -1, 1), (w - 5, h - 2, 1, 1), (cx, 2, 0, -1)):
        px_, py_ = x + int(sx), y + int(sy)
        for step in range(rng.randrange(6, 11)):                                              # a crack: a random walk away from the rim
            px_ += dx_ if rng.random() < 0.6 else rng.choice((-1, 0, 1))
            py_ += dy_ if rng.random() < 0.7 else rng.choice((-1, 0, 1))
            c.put(px_, py_, (30, 24, 26, 210))
    # rebar bent out of the rim
    for (sx, sy, ex, ey) in ((6, h - 5, 2, h - 2), (w - 7, 5, w - 3, 2), (11, 3, 9, 0), (w - 10, h - 3, w - 6, h)):
        c.line(x + sx, y + sy, x + ex, y + ey, hexc('2a2628'))
        c.put(x + ex, y + ey, hexc('6a5a50'))
    # a sheet of floor slab hanging off the lower left, folded down
    for k in range(7):
        c.hline(x + 1 + k, x + 6 + k // 2, y + floor_y_ + 2 + k // 2, hexc('6a645c') if k % 2 else hexc('4a4440'))
    c.vline(x + 14, y + floor_y_ + 1, y + floor_y_ + 8, hexc('5a5a62'))                      # a cable down the face
    c.put(x + 14, y + floor_y_ + 9, hexc('c4552a'))
    for k in range(1, 26):                                                                    # soot rolling up the wall from it
        half = 6 + k // 2
        for xx in range(-half, half + 1):
            if rng.random() < 0.78 - k * 0.02:
                c.put(x + w // 2 + xx + int(math.sin(k * 0.6) * 2), y - k, (28, 24, 24, int(150 * (1 - k / 26.0)) - abs(xx) * 5))
    for _ in range(34):                                                                       # rubble and splinters spilled down the face
        c.put(x + rng.randrange(-1, w + 1), y + h + rng.randrange(0, 12), hexc('8a8274') if rng.random() < 0.7 else hexc('5a5248'))
    if meta is not None:
        meta['breach'] = {'x': x, 'y': y, 'w': w, 'h': h, 'floor_y': y + floor_y_, 'cx': x + int(cx)}


def draw_roof(c, rng, meta):
    P = PAL['hotel']
    # parapet: a cap, a face, and the shadow of the cornice below
    c.rect(BX0 - 1, PARAPET_Y, BX1 + 1, TOP_Y - 1, P['wall'])
    c.hline(BX0 - 2, BX1 + 2, PARAPET_Y, hexc('f3ead0'))
    c.hline(BX0 - 2, BX1 + 2, PARAPET_Y + 1, P['band'])
    for xx in range(BX0 + 2, BX1, 6):
        c.rect(xx, PARAPET_Y + 3, xx + 2, TOP_Y - 3, shade(P['wall'], 0.92))
    c.hline(BX0 - 1, BX1 + 1, TOP_Y - 1, shade(P['dark'], 0.8))
    c.vline(BX0 - 2, PARAPET_Y, TOP_Y, hexc('f3ead0'))
    c.vline(BX1 + 2, PARAPET_Y, TOP_Y, hexc('4a4440'))
    # the stair / lift head: a box with a door, louvres and a ladder
    mx0, mx1 = 128, 164
    my0 = PARAPET_Y - 15
    c.rect(mx0, my0, mx1, PARAPET_Y - 1, hexc('c9bd9c'))
    c.rect(mx1 - 4, my0, mx1, PARAPET_Y - 1, hexc('9d9378'))
    c.hline(mx0 - 1, mx1 + 1, my0 - 1, hexc('efe6c8'))
    c.hline(mx0 - 1, mx1 + 1, my0, hexc('7a7160'))
    c.rect(mx0 + 4, my0 + 5, mx0 + 9, PARAPET_Y - 1, hexc('4a3a2e'))      # the door
    c.put(mx0 + 8, my0 + 9, hexc('d9b56a'))
    for k in range(4):
        c.hline(mx0 + 14, mx0 + 24, my0 + 4 + k * 2, hexc('6a634f'))     # louvres
    # a water tank on legs
    tx0, tx1 = 92, 112
    c.rect(tx0, PARAPET_Y - 12, tx1, PARAPET_Y - 5, hexc('9a6a4a'))
    for k in range(0, 21, 4):
        c.vline(tx0 + k, PARAPET_Y - 12, PARAPET_Y - 5, hexc('6a4630'))
    c.hline(tx0 - 1, tx1 + 1, PARAPET_Y - 13, hexc('553a28'))
    c.rect(tx0 + 4, PARAPET_Y - 15, tx1 - 4, PARAPET_Y - 13, hexc('7a5238'))     # lid
    for lx in (tx0 + 1, tx1 - 1):
        c.vline(lx, PARAPET_Y - 4, PARAPET_Y - 1, hexc('4a3a2e'))
    c.hline(tx0, tx1, PARAPET_Y - 4, hexc('4a3a2e'))
    # air-con boxes and a vent stack
    for ax in (176, 188):
        c.rect(ax, PARAPET_Y - 6, ax + 8, PARAPET_Y - 1, hexc('b9b6ac'))
        c.hline(ax, ax + 8, PARAPET_Y - 6, hexc('e8e6dc'))
        c.rect(ax + 2, PARAPET_Y - 5, ax + 6, PARAPET_Y - 2, hexc('55575e'))
    c.rect(118, PARAPET_Y - 9, 120, PARAPET_Y - 1, hexc('8a8f96'))
    c.hline(117, 121, PARAPET_Y - 10, hexc('5a5f66'))
    # an antenna mast with a red beacon on top of the head; a dish
    ax = 146
    c.vline(ax, 0, my0 - 2, hexc('3a3f48'))
    c.hline(ax - 3, ax + 3, 6, hexc('3a3f48'))
    c.hline(ax - 2, ax + 2, 11, hexc('3a3f48'))
    c.rect(ax - 1, 0, ax + 1, 1, hexc('8a1e1e'))
    meta['beacon'] = [{'x': ax, 'y': 0}]
    c.ellipse(182, PARAPET_Y - 11, 3.4, 2.4, hexc('d9d6cc'))
    c.put(182, PARAPET_Y - 11, hexc('7a7770'))
    c.vline(182, PARAPET_Y - 9, PARAPET_Y - 7, hexc('4a4a4a'))


def draw_entrance(c, rng, meta):
    """The ground floor (32 rows): stone base, two big windows (one boarded), the doors flung open under a canopy, steps."""
    y0, y1 = LOBBY_Y, GROUND_Y - 1
    stone = hexc('8c8f93')
    c.rect(BX0, y0, BX1, y1, stone)
    for yy in range(y0, y1 + 1, 4):                                   # ashlar courses
        c.hline(BX0, BX1, yy, shade(stone, 0.86))
        off = ((yy - y0) // 4 % 2) * 7
        for xx in range(BX0 + off, BX1, 14):
            c.vline(xx, yy, min(yy + 3, y1), shade(stone, 0.9))
    c.rect(BX0, y0, BX0 + 5, y1, hexc('a2a5a9'))
    c.rect(BX1 - 5, y0, BX1, y1, hexc('707378'))
    # shop windows each side: dark, one cracked, one boarded
    for (wx0, boarded) in ((BX0 + 10, False), (BX1 - 34, True)):
        c.rect(wx0, y0 + 8, wx0 + 23, y0 + 24, hexc('2c2f3a'))
        c.rect(wx0 + 1, y0 + 9, wx0 + 22, y0 + 23, mix(hexc('5c6a82'), hexc('1c1f2a'), 0.5))
        for k in range(5):
            c.put(wx0 + 3 + k, y0 + 13 - k + 2, hexc('9ab4cc'))
        c.hline(wx0 - 1, wx0 + 24, y0 + 25, hexc('b9b6a8'))
        if boarded:
            for yy in (y0 + 11, y0 + 15, y0 + 19):
                c.rect(wx0, yy, wx0 + 23, yy + 2, hexc('9a7650'))
                c.hline(wx0, wx0 + 23, yy + 2, hexc('6e5236'))
        else:
            for (x1_, y1_, x2_, y2_) in ((12, 0, 11, 7), (11, 7, 4, 12), (11, 7, 18, 11), (18, 11, 21, 16)):
                n = max(abs(x2_ - x1_), abs(y2_ - y1_), 1)
                for i in range(n + 1):
                    c.put(wx0 + 1 + x1_ + (x2_ - x1_) * i // n, y0 + 9 + y1_ + (y2_ - y1_) * i // n, hexc('dfe9f0'))
    # the doors: a deep dark entry, both leaves flung open against the jambs
    cx = (BX0 + BX1) // 2
    dx0, dx1 = cx - 12, cx + 12
    c.rect(dx0 - 2, y0 + 4, dx1 + 2, y1, hexc('c9c2ae'))              # surround
    c.rect(dx0, y0 + 7, dx1, y1, hexc('15131a'))
    for yy in range(y0 + 7, y1):
        for xx in range(dx0, dx1 + 1):
            if (xx + yy) % 7 == 0:
                c.put(xx, yy, hexc('221f2a'))
    c.rect(dx0 + 5, y0 + 18, dx1 - 5, y1, hexc('1f1c28'))             # a lit-less lobby, a glimpse of the far wall
    c.hline(dx0, dx1, y0 + 6, hexc('efe6c8'))
    for side in (-1, 1):                                              # the leaves, slanting open
        xx = dx0 if side < 0 else dx1
        for k in range(18):
            c.put(xx + side * (1 + k // 6), y0 + 8 + k, hexc('5a6170'))
            c.put(xx + side * (2 + k // 6), y0 + 8 + k, hexc('3a404c'))
        c.vline(xx + side * 1, y0 + 8, y0 + 26, hexc('8a93a4'))
    # the canopy
    c.rect(dx0 - 12, y0 + 1, dx1 + 12, y0 + 5, hexc('28483c'))
    for xx in range(dx0 - 12, dx1 + 13, 4):
        c.vline(xx, y0 + 1, y0 + 5, hexc('e0d6b4'))
        c.vline(xx + 1, y0 + 1, y0 + 5, hexc('e0d6b4'))
    c.hline(dx0 - 12, dx1 + 12, y0 + 6, hexc('1a2e26'))
    c.hline(dx0 - 12, dx1 + 12, y0, hexc('3a6a58'))
    for xx in range(dx0 - 12, dx1 + 13, 3):                            # the scalloped edge
        c.put(xx, y0 + 6, hexc('28483c'))
        c.put(xx + 1, y0 + 7, hexc('28483c')) if (xx // 3) % 2 else None
    # the steps down to the pavement
    for k in range(3):
        yy = y1 - 2 + k
        c.hline(dx0 - 5 + k, dx1 + 5 - k, yy, hexc('d6d0c0') if k == 0 else hexc('b9b3a4') if k == 1 else hexc('9a9486'))
    c.hline(dx0 - 5, dx1 + 5, y1 - 2, hexc('efe9d8'))


def cast_shadow(c, x, y, w, ry=1.7, a=78, dx=4):
    """A soft cast shadow lying on the ground at row y, `w` wide, thrown to the right (the sun is low on the left in the
    morning and at dusk): without one every prop floats on the ground as a flat sticker (owner round 36g: more depth)."""
    cx = x + w * 0.5 + dx
    for yy in range(int(y - ry), int(y + ry) + 1):
        for xx in range(int(cx - w * 0.5 - dx), int(cx + w * 0.5 + 1)):
            u = (xx - cx) / max(1.0, w * 0.5 + dx)
            v = (yy - y) / max(0.5, ry)
            if u * u + v * v <= 1.0:
                c.put(xx, yy, (0, 0, 0, int(a * (1.0 - 0.45 * (u * u + v * v)))))


# ================================================================================================================ THE GARDEN
# Owner round 36h: "I don't like the bottom of the building. Get rid of the road. An apartment community sort of garden with trees… a small
# pixel black cat running across the ground. In the afternoon a human running in fear. In the night bodies everywhere and blood on the ground.
# I'm not very fond of the cars and road, it looks too cold." The ground is lawn, a paved path up to the steps, a planting bed + low hedge
# along the plinth, and trees; each run's ground tells its own story (morning: calm, a cat; afternoon: dropped things, a body, a fire, a
# person fleeing; night: the dead and their blood everywhere). The runner is animated by the game (meta['runner']).
GRASS = [hexc('3f7a34'), hexc('4f8f3e'), hexc('5fa046'), hexc('3a6e30')]
DRY = [hexc('8a8a46'), hexc('7a7a3c'), hexc('969650')]
BLOOD = hexc('6a1a1c')
BLOOD_DK = hexc('3e0d10')
PATH_C = hexc('cbc4b2')
PATH_E = hexc('a39c8a')
PATH_J = hexc('9a937f')
CX = (BX0 + BX1) // 2


PATH_A = 16.0                       # half-width of the path at the steps
PATH_B = 0.82                       # how fast it opens toward the viewer (px per ground row)
WALL_T = 4                          # a path wall's thickness (px)
WALL_FROM, WALL_TO = 12, 34         # the walls run from the front of the planting bed to the gate piers (ground rows)
BED_ROWS = 12                       # the planting bed along the plinth


def path_half(yy):
    """Half-width of the paved path at ground-row offset yy (0 at the steps): it opens out toward the viewer."""
    return int(PATH_A + yy * PATH_B)


def wall_h(yy):
    """A path wall's height at ground row yy: low, a little taller toward the viewer (perspective)."""
    return 6 + yy // 4


def path_zone(x0, x1, yy):
    """Where an object spanning x0..x1 at ground row yy stands: 'path' (wholly on the paving), 'lawn' (wholly clear of the path AND the
    walls that edge it) or None (it would overlap the path's edge or a wall) — the rule that keeps trees, shrubs and benches off the path."""
    hw = path_half(yy)
    lo, hi = x0 - CX, x1 - CX
    if lo >= -(hw - 1) and hi <= hw - 1:
        return 'path'
    clear = hw + 2 + (WALL_T + 3 if WALL_FROM - 1 <= yy <= WALL_TO + 2 else 0)
    if hi <= -clear or lo >= clear:
        return 'lawn'
    return None


def lawn_tone(rng, x, y, dry):
    r = rng.random()
    if dry and r < dry:
        return rng.choice(DRY)
    return GRASS[0] if r < 0.28 else (GRASS[1] if r < 0.74 else (GRASS[2] if r < 0.93 else GRASS[3]))


SLAB_TONES = [hexc('d3ccba'), hexc('c6bfac'), hexc('bab3a0'), hexc('cfc8b6'), hexc('c1baa7')]
KERB_A, KERB_B, KERB_GAP = hexc('9b9482'), hexc('aca594'), hexc('6f6959')
MOSS = hexc('5c8a3e')


def slab_bounds():
    """Ground rows where a course of paving slabs starts: shallow at the steps, deeper toward the viewer (perspective)."""
    ys, d = [1], 3
    while ys[-1] < 48:
        ys.append(ys[-1] + d)
        if len(ys) % 2 == 0:
            d += 1
    return ys


def draw_path(c, rng, meta, run):
    """The paved path (owner round 36j: "give more detail to the path itself. It's looking too basic"): a kerb of setts along each edge, then
    courses of slabs laid in running bond (each slab its own tone, a lit top edge and a dark joint, the courses deepening toward the viewer),
    cracks and weeds in the joints, a drain grating, a worn middle, and what the run did to it (leaves, wet puddles at night)."""
    g0 = GROUND_Y
    bounds = slab_bounds()
    nb = len(bounds)
    wear = (0.0, 0.5, 1.0)[run - 1]
    for y in range(g0 + 1, SCENE_H):
        yy = y - g0
        hw = path_half(yy)
        k = 0
        while k + 1 < nb and bounds[k + 1] <= yy:
            k += 1
        v = yy - bounds[k]
        inner = max(4, hw - 4)
        cellw = max(4.0, 2.0 * inner / 3.0)
        off = 0.5 if k % 2 else 0.0
        for x in range(CX - hw, CX + hw + 1):
            dx = x - CX
            adx = abs(dx)
            if adx > hw - 4:                                      # the kerb: little setts end to end
                seg = (yy // 3) % 2
                col = KERB_A if seg else KERB_B
                if yy % 3 == 0:
                    col = KERB_GAP
                if adx == hw:
                    col = shade(KERB_GAP, 0.9)
                c.put(x, y, mix(col, hexc('857e6c'), rng.random() * 0.15))
                continue
            u = dx / float(inner)
            s = (u + 1.0) * 1.5 + off
            cell = int(math.floor(s))
            f = s - cell
            sr = random.Random(k * 977 + cell * 31 + run * 7)
            tone = SLAB_TONES[sr.randrange(len(SLAB_TONES))]
            col = shade(tone, 0.94 + 0.09 * sr.random())
            if f * cellw < 1.0 or v == 0:                         # the joint
                col = shade(PATH_J, 0.88)
            elif v == 1 or f * cellw < 2.0:                       # the lit top / left edge of a slab
                col = shade(tone, 1.07)
            elif v >= (bounds[k + 1] - bounds[k] - 1 if k + 1 < nb else 6):
                col = shade(tone, 0.9)                           # its shaded lower edge
            c.put(x, y, mix(col, hexc('a69f8c'), rng.random() * 0.12))
    # a worn, darker line down the middle where everyone walked
    for yy in range(3, 44):
        for dx in (-1, 0, 1):
            if rng.random() < 0.55:
                c.put(CX + dx + int(2 * math.sin(yy * 0.3)), g0 + yy, (70, 62, 50, 26))
    # cracks across some slabs, more as the world falls apart
    cracks = int(3 + 6 * wear)
    for _ in range(cracks):
        x = CX + rng.randrange(-28, 29)
        y = g0 + 6 + rng.randrange(0, 34)
        for _s in range(rng.randrange(4, 9)):
            if abs(x - CX) < path_half(y - g0) - 5:
                c.put(x, y, shade(PATH_J, 0.7))
            x += rng.choice((-1, 0, 1))
            y += 1 if rng.random() < 0.7 else 0
    # weeds and moss pushing up in the joints
    for _ in range(int(14 + 30 * wear)):
        yy = rng.randrange(3, 44)
        x = CX + rng.randrange(-path_half(yy) + 5, path_half(yy) - 4)
        c.put(x, g0 + yy, MOSS if rng.random() < 0.7 else hexc('86bd58'))
        if rng.random() < 0.4:
            c.put(x, g0 + yy - 1, hexc('86bd58'))
    # a drain grating let into the paving, and the gate's cobbled threshold across the walls' ends
    gx, gy = CX + 20, g0 + 23
    c.rect(gx, gy, gx + 7, gy + 2, hexc('3c3e44'))
    for bx in range(gx + 1, gx + 7, 2):
        c.vline(bx, gy, gy + 2, hexc('1c1d22'))
    c.hline(gx, gx + 7, gy, hexc('6a6c72'))
    for yy in range(WALL_TO, WALL_TO + 3):
        hw = path_half(yy)
        for x in range(CX - hw + 4, CX + hw - 3):
            col = mix(hexc('8f887a'), hexc('6a6458'), 0.5 if ((x // 3 + yy) % 2) else 0.15)
            c.put(x, g0 + yy, col)
    # the run's own marks
    if run <= 2:                                                  # fallen leaves (more in the afternoon)
        for _ in range(16 if run == 1 else 30):
            yy = rng.randrange(3, 44)
            x = CX + rng.randrange(-path_half(yy) + 5, path_half(yy) - 4)
            c.put(x, g0 + yy, rng.choice((hexc('b8742c'), hexc('d2962c'), hexc('8c5a24'), hexc('a8a03c'))))
    if run == 3:                                                  # the night's rain: puddles with a sky-grey sheen, and a few ripples
        for (px_, py_, rx_, ry_) in ((-22, 14, 6, 1.4), (14, 20, 8, 1.6), (-6, 33, 10, 1.8), (28, 38, 7, 1.6), (-30, 41, 6, 1.4)):
            for yy in range(int(py_ - ry_), int(py_ + ry_) + 1):
                for xx in range(int(px_ - rx_), int(px_ + rx_) + 1):
                    if ((xx - px_) / rx_) ** 2 + ((yy - py_) / ry_) ** 2 <= 1.0 and abs(CX + xx - CX) < path_half(yy) - 5:
                        c.put(CX + xx, g0 + yy, mix(hexc('4a566e'), hexc('7e8cac'), 0.5 + 0.5 * rng.random()))
            c.put(CX + int(px_), g0 + int(py_), hexc('b8c4de'))


def draw_path_walls(c, rng, meta, run):
    """A small stone wall along each side of the path, from the planting bed to the gate piers (owner round 36j: "build a small wall alongside
    both sides of the path and keep plants and trees to the correct sides"). Seen from the front a low wall running away along the path is a
    slanted ribbon: its inner face (shaded on the left wall, lit on the right — the sun is on the left), a pale capstone ribbon on top, mortar
    courses and staggered joints, a shadow thrown across the path from the left wall, and a pier at each end."""
    g0 = GROUND_Y
    face_a, face_b, mortar, cap_c = hexc('a89f8a'), hexc('b7ae98'), hexc('766f5e'), hexc('d8d1bf')
    for side in (-1, 1):                                          # far to near so the near stones overlap the far
        for yy in range(WALL_FROM, WALL_TO + 1):
            hw = path_half(yy)
            xi = CX + side * (hw + 1)
            h = wall_h(yy)
            yb = g0 + yy
            top = yb - h
            lit = 1.12 if side == 1 else 0.80
            for y in range(top + 2, yb + 1):
                dy = yb - y
                course = dy // 3
                joint = (dy % 3 == 0)
                along = (yy + (course % 2) * 3) // 6
                tone = face_a if (along + course) % 2 else face_b
                col = shade(tone, lit * (0.96 + 0.08 * ((along * 5 + course * 3) % 4) / 3.0))
                if joint and dy > 0:
                    col = shade(mortar, lit)
                elif (yy + (course % 2) * 3) % 6 == 0:
                    col = shade(mortar, lit)
                if dy == 0:
                    col = shade(mortar, 0.7 * lit)               # the dark line where it meets the ground
                c.put(xi, y, col)
            for d in range(WALL_T):                               # the capstone ribbon
                cc = cap_c if d < WALL_T - 1 else shade(cap_c, 0.82)
                c.put(xi + side * d, top, shade(cap_c, 1.06))
                c.put(xi + side * d, top + 1, cc)
            # a shadow the left wall throws across the path, and on the lawn the right wall's falls away outside
            if side == -1:
                for sx in range(1, 4):
                    c.put(CX - hw + sx, yb, (30, 26, 20, 46 - sx * 9))
            else:
                for sx in range(1, 4):
                    c.put(CX + hw + WALL_T + sx, yb, (20, 30, 14, 52 - sx * 10))
    # piers at both ends of each wall: a square post, a capstone that overhangs, a ball finial
    for side in (-1, 1):
        for (yy, ph) in ((WALL_FROM - 1, 11), (WALL_TO + 1, 19)):
            hw = path_half(yy)
            cx = CX + side * (hw + 1 + WALL_T // 2)
            yb = g0 + yy
            lit = 1.12 if side == 1 else 0.82
            for y in range(yb - ph, yb + 1):
                for x in range(cx - 3, cx + 3):
                    dy = yb - y
                    col = shade(hexc('b0a792'), lit * (1.0 if (dy // 3) % 2 else 0.93))
                    if dy % 3 == 0:
                        col = shade(mortar, lit)
                    if x == cx + 2:
                        col = shade(col, 0.8)
                    c.put(x, y, col)
            c.rect(cx - 4, yb - ph - 2, cx + 3, yb - ph, shade(cap_c, 1.0))
            c.hline(cx - 4, cx + 3, yb - ph - 2, shade(cap_c, 1.12))
            c.ellipse(cx - 0.5, yb - ph - 4, 2.2, 2.0, shade(cap_c, 0.95))
            c.put(cx - 1, yb - ph - 5, hexc('f4eedc'))
            cast_shadow(c, cx - 3, yb + 1, 8, 1.2, 70, 3)
    # the wear: capstones knocked off, stains and moss on the face (a little in the afternoon, a lot after the night)
    if run >= 2:
        for _ in range(3 * run):
            side = rng.choice((-1, 1))
            yy = rng.randrange(WALL_FROM + 3, WALL_TO - 2)
            hw = path_half(yy)
            xi = CX + side * (hw + 1)
            for d in range(WALL_T):
                c.put(xi + side * d, g0 + yy - wall_h(yy), (0, 0, 0, 0))
                c.put(xi + side * d, g0 + yy - wall_h(yy) + 1, shade(hexc('8a8372'), 0.9))
    for _ in range(18 * run):
        side = rng.choice((-1, 1))
        yy = rng.randrange(WALL_FROM, WALL_TO)
        xi = CX + side * (path_half(yy) + 1)
        y = g0 + yy - rng.randrange(0, wall_h(yy))
        c.put(xi, y, MOSS if rng.random() < 0.65 else shade(face_a, 0.7))
    if run == 3:                                                  # a smeared hand on the left wall, blood run down the stones
        yy = 24
        xi = CX - (path_half(yy) + 1)
        for k in range(5):
            c.put(xi, g0 + yy - 2 - k, BLOOD if k % 2 else BLOOD_DK)
        c.vline(xi, g0 + yy - 6, g0 + yy, BLOOD_DK)


def draw_ground(c, rng, meta, run, front=True):
    """Plinth, planting bed, lawn, the hedge. `front` (the garden layer) adds the path and its detail; the plain version is the BACK plane the
    building stands on, which shows through as the garden layer slides past (the opening's 2.5D)."""
    g0 = GROUND_Y
    dry = (0.0, 0.10, 0.26)[run - 1]
    # the lawn first, with mowing bands lighter / darker
    for y in range(g0, SCENE_H):
        yy = y - g0
        band = 1.05 if (yy // 5) % 2 == 0 else 0.97
        for x in range(W):
            col = lawn_tone(rng, x, y, dry)
            c.put(x, y, shade(col, band * (0.92 + 0.10 * min(yy, 30) / 30.0)))
    # blades and tufts (bigger toward the viewer)
    for _ in range(420 if front else 120):
        x, y = rng.randrange(0, W), g0 + 10 + rng.randrange(0, SCENE_H - g0 - 10)
        h = 1 + (y - g0) // 16
        col = rng.choice(GRASS + [hexc('86bd58')])
        for k in range(h):
            c.put(x, y - k, shade(col, 1.12 if k == h - 1 else 0.86))
    # the planting bed along the building: dark soil with mulch, a stone kerb
    c.rect(0, g0, W - 1, g0 + 1, hexc('b9b3a2'))
    c.hline(0, W - 1, g0, hexc('d9d3c2'))
    for y in range(g0 + 2, g0 + 11):
        for x in range(W):
            c.put(x, y, mix(hexc('4a3426'), hexc('62472f'), rng.random() * 0.6))
    c.hline(0, W - 1, g0 + 11, hexc('8a8576'))
    c.hline(0, W - 1, g0 + 12, hexc('5f5b50'))
    # the paved path, opening out toward the viewer
    if front:
        draw_path(c, random.Random(31 + run), meta, run)
    else:
        for y in range(g0 + 2, SCENE_H):
            hw = path_half(y - g0)
            for x in range(CX - hw, CX + hw + 1):
                c.put(x, y, mix(PATH_C, hexc('b4ad9a'), rng.random() * 0.25))
    # the hedge: a low clipped run along the bed, never across the path
    for x in range(0, W):
        bump = int(1.6 * math.sin(x * 0.9) + rng.randrange(0, 2))
        top = g0 + 2 + bump
        for y in range(top, g0 + 10):
            if abs(x - CX) <= path_half(y - g0) + 1:
                continue
            col = mix(hexc('2c5a2a'), hexc('3f7a34'), (y - top) / 8.0 * 0.6 + rng.random() * 0.25)
            c.put(x, y, col)
        if abs(x - CX) > path_half(top - g0) + 1:
            c.put(x, top, hexc('86bd58') if rng.random() < 0.6 else hexc('5fa046'))
    # flowers in front of the hedge, sparse as the world falls apart (never on the path)
    flower_p = (0.55, 0.30, 0.10)[run - 1]
    for x in range(2, W - 2, 3):
        if abs(x - CX) < path_half(10) + 4 or rng.random() > flower_p:
            continue
        col = rng.choice((hexc('e8584a'), hexc('f0c840'), hexc('f4f0e0'), hexc('b07ad8'), hexc('f08ab0')))
        y = g0 + 9 + rng.randrange(0, 2)
        c.put(x, y, col)
        c.put(x, y + 1, hexc('2c5a2a'))


def tree(c, x, base_y, R, kind, rng, run):
    """A tree standing on (x, base_y): a flared trunk and a round canopy lit from the upper left (volume, not a lollipop).
    kind: 'oak' (broad), 'poplar' (tall, narrow), 'blossom' (small, flowering)."""
    cast_shadow(c, x - R * 0.7, base_y + 1, R * 1.6, 2.4, 92, int(R * 0.5))
    tw = max(2, int(R * 0.22))
    th = int(R * (1.5 if kind != 'poplar' else 2.2))
    for yy in range(th):
        wdt = tw + (2 if yy < 3 else 0) + (1 if yy < 1 else 0)
        for xx in range(-wdt // 2 - 0, wdt // 2 + 1):
            t_ = (xx + wdt / 2.0) / max(1.0, wdt)
            col = shade(hexc('6a4a30'), 1.18 - 0.55 * t_)
            c.put(x + xx, base_y - yy, col)
    if kind == 'poplar':
        blobs = [(0, -R * 1.9 + k * R * 0.55, R * 0.55) for k in range(5)]
    elif kind == 'blossom':
        blobs = [(-R * 0.45, -R * 1.5, R * 0.6), (R * 0.45, -R * 1.5, R * 0.6), (0, -R * 1.9, R * 0.65), (0, -R * 1.2, R * 0.6)]
    else:
        blobs = [(-R * 0.55, -R * 1.5, R * 0.62), (R * 0.55, -R * 1.5, R * 0.62), (0, -R * 2.1, R * 0.7), (-R * 0.3, -R * 1.0, R * 0.6),
                 (R * 0.35, -R * 1.05, R * 0.6), (-R * 0.8, -R * 1.9, R * 0.45), (R * 0.85, -R * 1.9, R * 0.45)]
    if kind == 'blossom':
        tones = [hexc('b8587a'), hexc('d87a9c'), hexc('f0a8c0'), hexc('fbd8e4')]
    else:
        tones = [hexc('24502a'), hexc('36743a'), hexc('4f9442'), hexc('7cbc58')]
        if run == 3:
            tones = [shade(t_, 0.86) for t_ in tones]
    cy0 = base_y - th * 0.4
    xs = [bx + x for (bx, by, br) in blobs]
    x0, x1 = int(min(b[0] - b[2] for b in blobs) + x) - 1, int(max(b[0] + b[2] for b in blobs) + x) + 1
    y0, y1 = int(cy0 + min(b[1] - b[2] for b in blobs)) - 1, int(cy0 + max(b[1] + b[2] for b in blobs)) + 1
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            best = None
            for (bx, by, br) in blobs:
                dx = (xx - (x + bx)) / br
                dy = (yy - (cy0 + by)) / br
                d2 = dx * dx + dy * dy
                if d2 <= 1.0 and (best is None or d2 < best[0]):
                    best = (d2, dx, dy)
            if best is None:
                continue
            d2, dx, dy = best
            lit = -0.62 * dx - 0.78 * dy                         # the light comes from the upper left
            v = 0.5 + 0.42 * lit - 0.18 * d2 + (rng.random() - 0.5) * 0.30
            i = 0 if v < 0.28 else (1 if v < 0.52 else (2 if v < 0.76 else 3))
            if d2 > 0.82 and rng.random() < 0.35:
                continue                                          # ragged edge
            c.put(xx, yy, tones[i])
    # a few dark gaps where the sky shows through, and the branches into the foliage
    for _ in range(int(R * 1.5)):
        c.put(x0 + rng.randrange(0, x1 - x0), y0 + rng.randrange(0, max(1, y1 - y0)), (20, 36, 22, 0))
    for k in range(3):
        c.vline(x + (k - 1) * 2, int(cy0 + R * 0.2), base_y - th + 2, shade(hexc('6a4a30'), 0.7))
    if kind == 'blossom' and run < 3:                             # petals fallen on the grass
        for _ in range(10):
            c.put(x + rng.randrange(-int(R), int(R) + 1), base_y + rng.randrange(0, 5), hexc('f4c8d8'))


def bush(c, x, y, r, rng, burnt=False):
    cast_shadow(c, x - r, y + 1, r * 2, 1.4, 80, 3)
    for k in range(int(r * 3)):
        px = x + rng.randrange(-r, r + 1)
        py = y - rng.randrange(0, int(r * 1.2) + 1)
        d = ((px - x) / r) ** 2 + ((py - y + r * 0.5) / (r * 0.8)) ** 2
        if d <= 1.0:
            col = hexc('1e1c1c') if burnt else rng.choice((hexc('2c5a2a'), hexc('3f7a34'), hexc('5fa046')))
            c.ellipse(px, py, 2, 1.6, col)
    c.put(x - r // 2, y - r, hexc('1c1a1a') if burnt else hexc('86bd58'))


def bench(c, x, y, rng, toppled=False):
    wood, dk = hexc('8a5e3a'), hexc('5a3c24')
    cast_shadow(c, x, y + 1, 18, 1.4, 80, 4)
    if toppled:
        c.rect(x, y - 3, x + 17, y - 1, wood)
        c.vline(x + 2, y - 7, y - 3, dk)
        c.vline(x + 15, y - 7, y - 3, dk)
        c.hline(x + 2, x + 15, y - 7, wood)
        return
    c.rect(x, y - 8, x + 17, y - 6, wood)                         # back rest
    c.hline(x, x + 17, y - 8, shade(wood, 1.2))
    c.rect(x, y - 5, x + 17, y - 3, shade(wood, 0.95))             # seat
    c.hline(x, x + 17, y - 5, shade(wood, 1.2))
    for lx in (x + 1, x + 15):
        c.vline(lx, y - 2, y, dk)
        c.vline(lx, y - 8, y - 6, dk)


def planter(c, x, y, rng):
    c.rect(x, y - 5, x + 6, y, hexc('9b5a3c'))
    c.hline(x, x + 6, y - 5, hexc('c4704a'))
    c.vline(x + 6, y - 4, y, hexc('6a3a24'))
    for k in range(5):
        c.put(x + 1 + k, y - 6 - (k % 2), hexc('3f7a34'))
    c.put(x + 3, y - 8, rng.choice((hexc('e8584a'), hexc('f0c840'))))


def blood_pool(c, x, y, rx, ry, rng):
    for yy in range(int(y - ry), int(y + ry) + 1):
        for xx in range(int(x - rx), int(x + rx) + 1):
            d = ((xx - x) / rx) ** 2 + ((yy - y) / ry) ** 2
            if d <= 1.0 + 0.25 * (rng.random() - 0.5):
                c.put(xx, yy, mix(BLOOD, BLOOD_DK, min(1.0, d)))
    c.put(int(x - rx * 0.3), int(y - ry * 0.3), hexc('8a2a2c'))


def blood_trail(c, x0, y0, x1, y1, rng, w=1):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        px = x0 + (x1 - x0) * i // n
        py = y0 + (y1 - y0) * i // n
        for k in range(w):
            c.put(px, py + k, BLOOD if rng.random() < 0.85 else BLOOD_DK)
        if rng.random() < 0.2:
            c.put(px + rng.randrange(-2, 3), py + rng.randrange(-1, 3), BLOOD)


def lamp_post(c, x, base_y, meta):
    cast_shadow(c, x - 2, base_y + 1, 6, 1.0, 80, 5)
    c.vline(x, base_y - 34, base_y, hexc('3a3f48'))
    c.vline(x + 1, base_y - 34, base_y, hexc('5a606a'))
    c.rect(x - 3, base_y - 38, x + 4, base_y - 34, hexc('2c3038'))
    c.hline(x - 2, x + 3, base_y - 33, hexc('c9c2a0'))
    c.rect(x - 2, base_y - 2, x + 3, base_y, hexc('2c3038'))
    meta['lamp'] = {'x': x - 1, 'y': base_y - 33}


def litter(c, x, y, rng, kind):
    """Things dropped by whoever was here (afternoon and night)."""
    if kind == 'bag':
        c.rect(x, y - 3, x + 4, y, hexc('b9605a'))
        c.hline(x, x + 4, y - 3, hexc('d98a82'))
        c.put(x + 1, y - 4, hexc('7a3a36'))
        c.put(x + 3, y - 4, hexc('7a3a36'))
    elif kind == 'shoe':
        c.rect(x, y - 1, x + 3, y, hexc('2c2c34'))
        c.put(x + 3, y - 2, hexc('2c2c34'))
    elif kind == 'pram':                                          # tipped on its side, a wheel still turning
        c.rect(x, y - 5, x + 8, y - 1, hexc('5a6a8a'))
        c.hline(x, x + 8, y - 5, hexc('7a8aaa'))
        c.ellipse(x + 2, y, 2, 2, hexc('16161c'))
        c.ellipse(x + 7, y, 2, 2, hexc('16161c'))
        c.vline(x + 9, y - 7, y - 3, hexc('8a8e96'))
    elif kind == 'toy':
        c.rect(x, y - 2, x + 3, y, hexc('d8c25a'))
        c.put(x + 1, y - 3, hexc('c9605a'))
    cast_shadow(c, x, y + 1, 6, 0.9, 70, 2)


def tree_half(R, kind):
    """How far a tree's canopy reaches sideways of its trunk."""
    return int(R * (0.9 if kind == 'poplar' else 1.4)) + 1


def stand(meta, what, x0, x1, yy, want):
    """Place-check one object: it must stand wholly on the lawn (or on the path, for what the story drops there). A violation stops the build —
    nature never grows through the paving or its walls."""
    z = path_zone(int(x0), int(x1), int(yy))
    if z != want:
        raise SystemExit('opening garden: %s at x %d..%d, ground row %d is %s, wanted %s' % (what, x0, x1, yy, z, want))
    meta['placed'].append({'what': what, 'x0': int(x0), 'x1': int(x1), 'yy': int(yy), 'zone': z})


def draw_garden_objects(c, rng, meta, run):
    """Everything standing / lying ON the ground: the walls, shrubs, planters, a bench, the trees, the lamps, and what happened here. Plants
    and trees stand on the LAWN, outside the path's walls (`stand` checks every one); only what people dropped lies on the path.

    DEPTH ORDER (owner round 49 — "the scene on the ground still has clipping issues"): everything that stands or lies on the ground is
    painted FAR TO NEAR by its base row, as one list (`later`), not category by category. The old order drew all the bushes, then the bench,
    then the trees, then the lamps, then the bodies — so a tree standing BEHIND a bush was painted over it, and in the night a body lying
    behind a poplar was painted over the poplar. `garden_depth_violations(run)` measures it (pixels a farther object put over a nearer one)
    and `--check` fails on any."""
    g0 = GROUND_Y
    xr = random.Random(7000 + run)
    meta['trees'] = []
    meta['bodies'] = []
    meta['bushes'] = []
    meta['placed'] = []
    meta['path'] = {'cx': CX, 'a': PATH_A, 'b': PATH_B, 'wall_t': WALL_T, 'wall_from': WALL_FROM, 'wall_to': WALL_TO}
    draw_path_walls(c, random.Random(55 + run), meta, run)
    ops = []

    def later(y, fn):
        ops.append((y, len(ops), fn))

    # planters flanking the steps, just OUTSIDE the paving
    for (px_, want_x) in ((CX - 32, 'L'), (CX + 27, 'R')):
        stand(meta, 'planter', px_, px_ + 6, 8, 'lawn')
        later(g0 + 8, lambda px_=px_: planter(c, px_, g0 + 8, xr))
    # shrubs along the bed, a few round bushes on the lawn
    for bx in (88, 108, 176, 196, 12, 56):
        r_ = 5 + xr.randrange(0, 3)
        by = g0 + 8 + xr.randrange(0, 2)
        stand(meta, 'bed shrub', bx - r_ - 1, bx + r_ + 1, by - g0, 'lawn')
        later(by, lambda bx=bx, by=by, r_=r_: bush(c, bx, by, r_, xr))
    # low shrubs hugging the OUTSIDE of each wall, spaced along it (a planted border)
    for side in (-1, 1):
        for yy in range(WALL_FROM + 3, WALL_TO, 7):
            bx = CX + side * (path_half(yy) + WALL_T + 11)
            stand(meta, 'wall shrub', bx - 4, bx + 4, yy, 'lawn')
            later(g0 + yy, lambda bx=bx, yy=yy: bush(c, bx, g0 + yy, 3, xr))
    for (bx, by, br) in ((46, g0 + 26, 4), (240, g0 + 30, 5), (76, g0 + 38, 4), (210, g0 + 40, 4)):
        stand(meta, 'lawn bush', bx - br - 1, bx + br + 1, by - g0, 'lawn')
        later(by, lambda bx=bx, by=by, br=br: bush(c, bx, by, br, xr))
        meta['bushes'].append({'x': bx, 'y': by})
    stand(meta, 'bench', 205, 223, 22, 'lawn')
    later(g0 + 22, lambda: bench(c, 205, g0 + 22, xr, toppled=(run >= 2)))
    # trees: two big ones framing the building, small ones near the entrance, flowering ones, poplars at the gate — all on the lawn
    specs = [(30, g0 + 24, 20, 'oak'), (262, g0 + 22, 18, 'oak'), (66, g0 + 17, 9, 'blossom'), (231, g0 + 16, 10, 'oak'), (74, g0 + 37, 8, 'blossom'),
             (14, g0 + 38, 12, 'poplar'), (276, g0 + 39, 12, 'poplar')]
    for (tx, ty, tr, kind) in sorted(specs, key=lambda s_: s_[1]):
        hh = tree_half(tr, kind)
        stand(meta, 'tree ' + kind, tx - hh, tx + hh, ty - g0, 'lawn')
        later(ty, lambda tx=tx, ty=ty, tr=tr, kind=kind: tree(c, tx, ty, tr, kind, xr, run))
        meta['trees'].append({'x': tx, 'y': ty, 'r': tr, 'kind': kind})
    # the lamps stand outside the walls, either side of the gate
    for (k, side) in enumerate((-1, 1)):
        lx = CX + side * (path_half(30) + WALL_T + 13)
        stand(meta, 'lamp', lx - 3, lx + 4, 30, 'lawn')
        later(g0 + 30, lambda lx=lx, k=k: lamp_post(c, lx, g0 + 30, meta if k == 0 else {}))
    # what happened
    if run >= 2:
        for (lx, ly, kind, want) in ((84, g0 + 30, 'bag', 'lawn'), (151, g0 + 19, 'shoe', 'path'), (214, g0 + 34, 'pram', 'lawn'),
                                     (120, g0 + 33, 'toy', 'path'), (170, g0 + 31, 'shoe', 'path')):
            stand(meta, 'litter ' + kind, lx, lx + 9, ly - g0, want)
            later(ly, lambda lx=lx, ly=ly, kind=kind: litter(c, lx, ly, xr, kind))
        blood_trail(c, 118, g0 + 24, 146, g0 + 18, xr)                                  # a smear on the ground: under everything that stands
        meta['fires'].append({'x': 74, 'y': g0 + 12, 'scale': 0.9})
        later(g0 + 12, lambda: bush(c, 74, g0 + 12, 6, xr, burnt=True))
        if run == 2:
            stand(meta, 'body', 152, 170, 24, 'path')

            def body2():
                blood_pool(c, 161, g0 + 26, 9, 2, xr)
                body_lying(c, 152, g0 + 24, xr)
            later(g0 + 24, body2)
            meta['bodies'].append({'x': 152, 'y': g0 + 24})
    if run == 3:
        spots = [(40, g0 + 30, 1, 'lawn'), (62, g0 + 34, 0, 'lawn'), (130, g0 + 22, 1, 'path'), (150, g0 + 29, 0, 'path'), (214, g0 + 20, 1, 'lawn'),
                 (214, g0 + 33, 0, 'lawn'), (248, g0 + 28, 1, 'lawn'), (100, g0 + 41, 0, 'path'), (170, g0 + 40, 1, 'path'), (230, g0 + 41, 0, 'lawn'),
                 (20, g0 + 22, 1, 'lawn'), (136, g0 + 14, 0, 'path')]
        for (bx, by, fl, want) in spots:
            lo, hi = (bx - 16, bx + 1) if fl else (bx - 1, bx + 16)
            stand(meta, 'body', lo, hi, by - g0, want)

            def body3(bx=bx, by=by, fl=fl):
                blood_pool(c, bx + (6 if not fl else -6), by + 2, 10, 2, xr)
                blood_trail(c, bx + (14 if not fl else -14), by + 1, bx + (28 if not fl else -28), by - 3 + xr.randrange(0, 4), xr, 1)
                body_lying(c, bx, by, xr, flip=bool(fl))
            later(by, body3)
            meta['bodies'].append({'x': bx, 'y': by})
        # the path is smeared where they were dragged to the doors, handprints on the steps (the ground, under everything)
        blood_trail(c, CX - 10, g0 + 34, CX - 4, g0 + 4, xr, 2)
        blood_trail(c, CX + 8, g0 + 43, CX + 3, g0 + 5, xr, 2)
        for _ in range(26):
            c.put(CX - 14 + xr.randrange(0, 29), g0 + 2 + xr.randrange(0, 40), BLOOD)
        meta['fires'].append({'x': 90, 'y': g0 + 18, 'scale': 1.0})
        later(g0 + 18, lambda: bush(c, 90, g0 + 18, 5, xr, burnt=True))
    for (_y, _i, fn) in sorted(ops, key=lambda o: (o[0], o[1])):                          # FAR to NEAR
        fn()
    garden_runner(meta, run)


def garden_runner(meta, run):
    """The one thing that crosses the garden (the game animates it; here only where): a black cat in the morning, a person running in fear
    in the afternoon, nothing at night. See `RUNNERS`."""
    rn = dict(RUNNERS.get(run, {'kind': ''}))
    rn['y0'] = GROUND_Y                                           # the row the building stands on: a path point (x, r) is drawn at y = y0 + r
    rn['scale'] = [PATH_A, PATH_B, 43.0]                          # size on row r: (A + B r) / (A + B 43) — the path's own width law
    meta['runner'] = rn


# Where the runner goes, in the garden layer's own pixels (y is the row it stands on: GROUND_Y = the foot of the building, +43 = the
# viewer's edge). It does NOT run along the bottom edge any more (owner round 49): it comes in from the front and goes DEEPER into the scene,
# shrinking with the same perspective the path's width has (`runner_scale`), and `runner_clearance(run)` checks that nothing standing
# NEARER than it covers it on the way (it is drawn over the garden, so the path has to stay clear of every nearer object).
RUNNERS = {
    # the black cat comes up out of the bottom of the screen at the front-left, cuts across the lawn's front corner, then climbs the path to
    # the open door and is gone in the dark
    1: {'kind': 'cat', 'speed': 46.0, 'start': 0.5, 'end': 'vanish', 'path': [[60, 47], [67, 40], [108, 40], [111, 37], [111, 34], [142, 3]]},
    # a person comes up from the front-right and runs for the barricaded door — and stands there, hammering on it (the camera leaves them)
    2: {'kind': 'human', 'speed': 52.0, 'start': 0.3, 'end': 'pound', 'path': [[230, 47], [225, 42], [201, 42], [199, 40], [188, 40], [187, 39], [184, 39], [178, 33], [167, 33], [165, 31], [165, 28], [169, 24], [149, 4], [142, 4]]},
    3: {'kind': ''},
}


def runner_scale(yy):
    """How big a thing standing on row `yy` (0 = the building's foot, 43 = the front edge) is drawn, 1.0 at the front: the path's own width law."""
    return (PATH_A + PATH_B * yy) / (PATH_A + PATH_B * 43.0)


GARDEN_OBJECTS = ('planter', 'bush', 'bench', 'tree', 'lamp_post', 'litter', 'body_lying')


def garden_footprints(run):
    """Draw the run's garden once with every standing / lying object's pixels recorded: [(name, base row, set of (x, y) painted)], in the
    order they were painted, plus the path walls' pixels. The measuring tool behind `garden_depth_violations` and `runner_clearance`."""
    import numpy as np
    log = []
    wrapped = {}

    def wrap(name):
        orig = globals()[name]
        wrapped[name] = orig

        def w(c, *a, **k):
            before = np.array(c.img)
            r = orig(c, *a, **k)
            changed = (before != np.array(c.img)).any(axis=2)
            log.append((name, a[1], changed))
            return r
        globals()[name] = w
    try:
        for n in GARDEN_OBJECTS:
            wrap(n)
        orig_walls = globals()['draw_path_walls']

        def walls(c, rng, meta, run_):
            before = np.array(c.img)
            orig_walls(c, rng, meta, run_)
            log.append(('walls', -1, (before != np.array(c.img)).any(axis=2)))
        globals()['draw_path_walls'] = walls
        wrapped['draw_path_walls'] = orig_walls
        cg = Canvas(W, SCENE_H, seed=505)
        gmeta = {'fires': []}
        draw_ground(cg, random.Random(516), gmeta, run, front=True)
        draw_garden_objects(cg, random.Random(7100 + run), gmeta, run)
    finally:
        for n, f in wrapped.items():
            globals()[n] = f
    return log, gmeta


def garden_depth_violations(run):
    """[(pixels, nearer object, farther object)] — a FARTHER object painted over pixels of a NEARER one. Must be empty (see draw_garden_objects)."""
    log, _ = garden_footprints(run)
    bad = []
    log = [e for e in log if e[0] != 'walls']
    for i in range(len(log)):
        for j in range(i + 1, len(log)):
            ni, yi, mi = log[i]
            nj, yj, mj = log[j]
            if yj < yi - 1:
                ov = int((mi & mj).sum())
                if ov > 3:
                    bad.append((ov, '%s@%d' % (ni, yi), '%s@%d' % (nj, yj)))
    return sorted(bad, reverse=True)


# The runner's footprint at full size (the front edge): width x height in garden pixels, tail / arms included.
RUNNER_SIZE = {'cat': (11, 8), 'human': (9, 14)}
RUNNER_X_MIN, RUNNER_X_MAX = -16, 304          # the lane runs a little past both screen edges (the runner enters and leaves off-screen)
RUNNER_ROW_MAX = 47                            # …and a few rows below the picture's front edge (row 43): it can come up out of the bottom of the screen


def _runner_blocked(log, kind, x, yy):
    """Would a runner of this kind, standing at (x, row yy), be covered by — or stand inside — something? Objects NEARER than it
    (base row at or below its own: the ones it would have to pass in front of) and the path walls (its feet may not stand on them)."""
    w, h = RUNNER_SIZE[kind]
    s = runner_scale(yy)
    fw, fh = max(2, int(round(w * s))), max(3, int(round(h * s)))
    y = GROUND_Y + yy
    x0, x1 = int(x) - fw // 2, int(x) - fw // 2 + fw
    if x0 < 0 or x1 > W:
        return False                                                   # off the edge of the picture: nobody sees it
    for (nm, by, mask) in log:
        if nm == 'walls':
            if mask[y - 1:y + 1, x0:x1].any():
                return True
        elif by >= y and mask[y - fh + 1:y + 1, x0:x1].any():
            return True
    return False


def plan_lane(run, kind, start, goal, step=1, front=1.6):
    """A shortest route over FREE ground from `start` to `goal` (both (x, row yy)), by A* on a grid; the planner's answer is then
    pasted into RUNNERS as waypoints (the game never plans) and `runner_clearance` keeps it honest."""
    import heapq
    log, _ = garden_footprints(run)
    xs = list(range(RUNNER_X_MIN, RUNNER_X_MAX + 1, step))
    ys = list(range(0, 44))
    sx = min(xs, key=lambda v: abs(v - start[0]))
    gx = min(xs, key=lambda v: abs(v - goal[0]))
    startn, goaln = (sx, start[1]), (gx, goal[1])
    openq = [(0.0, startn)]
    came = {}
    cost = {startn: 0.0}
    cache = {}

    def blocked(n):                                                    # a node is only free if its 4 neighbours are too (a diagonal run rounds onto them)
        if n not in cache:
            cache[n] = any(_runner_blocked(log, kind, n[0] + dx, min(43, max(0, n[1] + dy))) for (dx, dy) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)))
        return cache[n]
    while openq:
        _, cur = heapq.heappop(openq)
        if cur == goaln:
            break
        for dx in (-step, 0, step):
            for dy in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                n = (cur[0] + dx, cur[1] + dy)
                if not (RUNNER_X_MIN <= n[0] <= RUNNER_X_MAX and 0 <= n[1] <= RUNNER_ROW_MAX) or (blocked(n) and n != goaln):
                    continue
                c = cost[cur] + (dx * dx + (dy * 2.4) ** 2) ** 0.5 * (1.0 + front * n[1] / 43.0)    # the front edge costs more: go deeper
                if c < cost.get(n, 1e9):
                    cost[n] = c
                    came[n] = cur
                    heapq.heappush(openq, (c + ((goaln[0] - n[0]) ** 2 + ((goaln[1] - n[1]) * 2.4) ** 2) ** 0.5, n))
    if goaln not in came and startn != goaln:
        return []
    path = [goaln]
    while path[-1] != startn:
        path.append(came[path[-1]])
    path.reverse()
    # keep the corners: drop points that lie on a straight run
    out = [path[0]]
    for i in range(1, len(path) - 1):
        a, b, c = out[-1], path[i], path[i + 1]
        if (b[0] - a[0]) * (c[1] - b[1]) != (b[1] - a[1]) * (c[0] - b[0]):
            out.append(b)
    out.append(path[-1])
    return [[int(x), int(y)] for (x, y) in out]


def runner_clearance(run):
    """Rows / columns on the runner's route where something would cover it, or stand under its feet: [(x, row)]. Must be empty."""
    rn = RUNNERS.get(run, {})
    if not rn.get('path'):
        return []
    log, _ = garden_footprints(run)
    pts = rn['path']
    bad = []
    for (a, b) in zip(pts[:-1], pts[1:]):                              # sampled finely, rounded exactly as the game rounds what it draws
        n = max(abs(b[0] - a[0]), abs(b[1] - a[1]), 1) * 4
        for i in range(n + 1):
            x = math.floor(a[0] + (b[0] - a[0]) * i / n + 0.5)
            yy = int(math.floor(a[1] + (b[1] - a[1]) * i / n + 0.5))
            if _runner_blocked(log, rn['kind'], x, yy):
                bad.append((x, yy))
    return sorted(set(bad))


def planks(c, x0, y0, x1, y1, rng, n):
    """Boards nailed across an opening."""
    for k in range(n):
        yy = y0 + int((y1 - y0) * (k + 0.5) / n) + rng.randrange(-1, 2)
        slope = rng.randrange(-3, 4)
        for xx in range(x0, x1 + 1):
            y = yy + (xx - x0) * slope // max(1, (x1 - x0))
            c.put(xx, y, hexc('a07c55'))
            c.put(xx, y + 1, hexc('a07c55'))
            c.put(xx, y + 2, hexc('6e5236'))
        c.put(x0 + 1, yy + 1, hexc('2c2c2c'))
        c.put(x1 - 1, yy + 1 + slope // 2, hexc('2c2c2c'))


def body_lying(c, x, y, rng, flip=False):
    """Someone lying in the street: clothes, a head, and what happened round them."""
    d = -1 if flip else 1
    cast_shadow(c, min(x, x + 11 * d), y + 3, 12, 1.0, 70, 3)
    c.ellipse(x + 6 * d, y + 2, 8, 2.4, hexc('5a1c20'))
    clothes = rng.choice((hexc('3a4a6a'), hexc('6a4a3a'), hexc('4a5a44'), hexc('7a6a52')))
    c.rect(min(x, x + 8 * d), y, max(x, x + 8 * d), y + 2, clothes)
    c.rect(min(x + 8 * d, x + 11 * d), y, max(x + 8 * d, x + 11 * d), y + 1, hexc('c9a98a'))
    c.hline(min(x - 3 * d, x), max(x - 3 * d, x), y + 2, shade(clothes, 0.7))
    c.put(x + 12 * d, y, hexc('2a1e18'))


def barricade_door(c, rng, run):
    """The front doors stopped up with whatever the residents had: a chair, a table, boards (all of it, and stained, by night)."""
    cx = (BX0 + BX1) // 2
    dx0, dx1 = cx - 12, cx + 12
    y0 = LOBBY_Y
    if run == 2:
        planks(c, dx0 + 1, y0 + 9, dx1 - 1, y0 + 29, rng, 3)
        c.rect(dx0 + 4, y0 + 20, dx0 + 11, y0 + 30, hexc('5a4030'))          # a chair on its back
        c.hline(dx0 + 4, dx0 + 11, y0 + 20, hexc('7a5a40'))
        c.vline(dx0 + 4, y0 + 24, y0 + 31, hexc('3a2a20'))
        c.vline(dx0 + 11, y0 + 24, y0 + 31, hexc('3a2a20'))
    else:
        planks(c, dx0 + 1, y0 + 8, dx1 - 1, y0 + 30, rng, 5)
        c.rect(dx0 + 12, y0 + 18, dx1 - 2, y0 + 31, hexc('4a5668'))          # a fridge laid against the doors
        c.rect(dx0 + 13, y0 + 19, dx0 + 14, y0 + 30, hexc('8a96a8'))
        c.hline(dx0 + 12, dx1 - 2, y0 + 18, hexc('9aa6b6'))
        for k in range(6):                                                  # blood down the boards
            c.vline(dx0 + 3 + k * 4, y0 + 10, y0 + 14 + rng.randrange(0, 10), hexc('6a1a1c'))


def draw_scene(run=1):
    """TWO pictures on the SAME grid (owner round 36j: "the garden is a front facing image, the building doesn't need to be a 3D cuboid… 2.5D
    where items in the foreground appear on a different plane from the background"): the BUILDING — a flat, front-on facade with a crisp
    silhouette — on a plain back lawn, and the GARDEN (lawn, path, walls, trees, what happened) as its own layer the game slides faster. At
    camera 0 they coincide exactly; as it climbs the garden slides away and the building looms behind."""
    rng = random.Random(404)
    L = LOOK[run]
    c = Canvas(W, SCENE_H, seed=404)
    meta = {'lit': [], 'smoke': [], 'beacon': [], 'survivors': [], 'helps': [],
            'grid': {'x0': INNER_X0, 'bay_w': BAY_W, 'bays': BAYS, 'floor0_y': TOP_Y, 'floor_h': FH, 'frame': [2, 2, 11, 10]}}
    draw_facade(c, rng, meta, run)
    draw_roof(c, rng, meta)
    draw_entrance(c, rng, meta)
    barricade_door(c, random.Random(77 + run), run) if run >= 2 else None
    draw_ground(c, random.Random(515), {}, run, front=False)     # the back plane the building stands on
    edge_light(c, run)
    xr = random.Random(900 + run)
    if run == 3:
        for k in range(18):                                       # parapet knocked off at the corner, the pieces down the face
            x0 = BX0 - 1 + k
            for yy in range(PARAPET_Y, PARAPET_Y + 2 + (k * 7) % 5):
                if xr.random() < 0.9 - k * 0.02:
                    c.px[x0, yy] = (0, 0, 0, 0)
    if L['grade'] is not None:
        grade_scene(c.img, L['grade'], meta['lit'], run)
        c.px = c.img.load()
    # the garden layer, on its own canvas
    cg = Canvas(W, SCENE_H, seed=505)
    gmeta = {'fires': []}
    draw_ground(cg, random.Random(516), gmeta, run, front=True)
    draw_garden_objects(cg, random.Random(7100 + run), gmeta, run)
    base_shadow(cg, run)
    if L['grade'] is not None:
        grade_scene(cg.img, L['grade'], [], run)
    return c.img, meta, cg.img, gmeta


def edge_light(c, run):
    """A crisp silhouette for the flat facade: a dark hairline down each side with a pale rim on the sunward (left) edge, so the front-on
    tower stands off the sky and the city behind it instead of melting into them."""
    top, bot = PARAPET_Y, GROUND_Y - 1
    c.vline(BX0 - 1, top, bot, hexc('2c2824'))
    c.vline(BX1 + 1, top, bot, hexc('2c2824'))
    rim = (hexc('d6c9a8'), hexc('c9a98a'), hexc('8a5636'))[run - 1]
    c.vline(BX0, top + 2, bot, mix(rim, hexc('2c2824'), 0.25))
    c.vline(BX1 + 2, top, bot, (20, 16, 24, 70))                  # a faint soft edge-shadow on the sky side
    c.hline(BX0 - 1, BX1 + 1, top - 1, hexc('2c2824'))


def base_shadow(cg, run):
    """The building's contact shadow on the planting bed, in the garden layer (so it travels with the ground it falls on)."""
    for yy in range(0, 10):
        a = int((60, 70, 30)[run - 1] * (1.0 - yy / 10.0))
        for x in range(BX0 - 2, BX1 + 4):
            cg.put(x, GROUND_Y + yy, (0, 0, 0, a))


def grade_scene(img, g, lit, run):
    """The time of day over the whole picture: desaturate, multiply by the light, add its cast — then put the LAMPS back on top, still
    warm (a lit window must read as light at dusk and glow at night), with a faint halo round each."""
    px = img.load()
    before = img.copy()
    bp = before.load()
    for y in range(img.height):
        for x in range(img.width):
            r, gg, b, a = px[x, y]
            if not a:
                continue
            lum = 0.30 * r + 0.59 * gg + 0.11 * b
            r = lum + (r - lum) * g['sat']
            gg = lum + (gg - lum) * g['sat']
            b = lum + (b - lum) * g['sat']
            px[x, y] = (max(0, min(255, int(r * g['mul'][0] + g['add'][0]))), max(0, min(255, int(gg * g['mul'][1] + g['add'][1]))),
                        max(0, min(255, int(b * g['mul'][2] + g['add'][2]))), a)
    for w in lit:
        x0, y0 = w['x'], w['y']
        for yy in range(y0 - 2, y0 + w['h'] + 2):
            for xx in range(x0 - 2, x0 + w['w'] + 2):
                inside = x0 <= xx < x0 + w['w'] and y0 <= yy < y0 + w['h']
                if inside:
                    r, gg, b, a = bp[xx, yy]
                    px[xx, yy] = (min(255, int(r * 1.04)), min(255, int(gg * 1.0)), min(255, int(b * 0.96)), a)
                elif run == 3:
                    r, gg, b, a = px[xx, yy]
                    if a:
                        px[xx, yy] = (min(255, r + 26), min(255, gg + 16), min(255, b + 4), a)


# =============================================================================================================== FORE
def draw_fore(run=1):
    rng = random.Random(9)
    c = Canvas(W, FORE_H, seed=9)
    dark = hexc('26262c')
    px = 14
    c.rect(px, 0, px + 4, FORE_H - 1, hexc('4a3a2e'))
    c.vline(px + 4, 0, FORE_H - 1, hexc('2c2218'))
    c.vline(px, 0, FORE_H - 1, hexc('6a5440'))
    for k in range(20, 60, 3):
        c.put(px + 1, k, hexc('362a20'))
    c.rect(px - 8, 24, px + 12, 26, hexc('4a3a2e'))                 # cross arms
    c.rect(px - 6, 40, px + 10, 41, hexc('4a3a2e'))
    for ix in (px - 7, px - 2, px + 6, px + 11):
        c.rect(ix, 20, ix + 1, 23, hexc('9ab4a8'))                  # insulators
    wires = []
    last_x = W if run == 1 else (W if run == 2 else 168)         # by night the wires have come down
    for k, (y0, sag) in enumerate(((22, 10), (23, 8), (21, 12))):
        pts = []
        for x in range(px + 10, last_x):
            t = (x - px - 10) / float(W - px - 10)
            y = y0 + sag * math.sin(t * math.pi / 2.0) * 0.9 + t * 8
            pts.append((x, int(round(y))))
            c.put(x, int(round(y)), dark)
        wires.append(pts)
        if run == 3 and k != 1:                                      # a snapped end swinging down
            ex, ey = pts[-1]
            for d in range(1, 40 + 10 * k):
                c.put(ex + int(math.sin(d * 0.11) * 2.0), ey + d, dark)
    if run == 2:                                                     # one wire sagging low, nearly on the cars
        for x in range(px + 10, W):
            t = (x - px - 10) / float(W - px - 10)
            c.put(x, int(round(30 + 40 * math.sin(t * math.pi / 2.0) * 0.8)), dark)
    perches = []                                                     # where the crows sit (owner round 49: they are live now, they startle and fly)
    if run <= 2:
        for (wi, x) in ((0, 104), (0, 117), (1, 190)):
            for (xx, yy) in wires[wi]:
                if xx == x:
                    perches.append({'x': xx, 'y': yy})
    if run >= 2:
        g = LOOK[run]['grade']
        img = c.img
        pxl = img.load()
        for y in range(img.height):
            for x in range(img.width):
                r, gg, b, a = pxl[x, y]
                if a:
                    pxl[x, y] = (max(0, min(255, int(r * g['mul'][0]))), max(0, min(255, int(gg * g['mul'][1]))),
                                 max(0, min(255, int(b * g['mul'][2]))), a)
    return c.img, {'perches': perches}


# ================================================================================================================== FOG
def draw_fog(run, kind):
    """The afternoon's FOG (owner round 36j: "in the afternoon we can add a little fog"): soft, dithered banks that tile sideways so the game can
    drift them. 'mid' lies between the building and the garden — a thick bank on the ground, a thin one up the tower; 'front' lies over the
    garden — a low veil. Pixel-honest: alpha steps through four levels with a Bayer dither at the edges, no smooth gradient."""
    rng = random.Random(8800 + (1 if kind == 'mid' else 2))
    img = Image.new('RGBA', (W, SCENE_H), (0, 0, 0, 0))
    px = img.load()

    def noise(gw, gh, seed):
        r = random.Random(seed)
        g = Image.new('L', (gw, gh))
        gp = g.load()
        for yy in range(gh):
            for xx in range(gw):
                gp[xx, yy] = r.randrange(256)
        big = Image.new('L', (gw * 3, gh))
        for k in range(3):
            big.paste(g, (k * gw, 0))
        big = big.resize((W * 3, SCENE_H), Image.BICUBIC)
        return big.crop((W, 0, W * 2, SCENE_H)).load()
    n1 = noise(9, 40, 11 + (0 if kind == 'mid' else 50))
    n2 = noise(20, 90, 23 + (0 if kind == 'mid' else 50))
    tint = (236, 206, 204)
    for y in range(SCENE_H):
        if kind == 'mid':
            ground = math.exp(-((y - (GROUND_Y - 8)) / 20.0) ** 2) * 1.0           # a bank hugging the ground line
            tower = math.exp(-((y - 300) / 26.0) ** 2) * 0.42 + math.exp(-((y - 120) / 22.0) ** 2) * 0.30
            env = max(ground, tower)
        else:
            env = math.exp(-((y - (GROUND_Y + 30)) / 16.0) ** 2) * 0.75
        if env < 0.02:
            continue
        for x in range(W):
            v = (0.62 * n1[x, y] + 0.38 * n2[x, y]) / 255.0
            a = (v - 0.34) * 2.2 * env
            a += (bayer(x, y) - 0.5) * 0.12
            lvl = 0 if a < 0.12 else (1 if a < 0.30 else (2 if a < 0.52 else 3))
            if lvl:
                px[x, y] = tint + ((0, 34, 64, 98)[lvl],)
    return img


# ============================================================================================================== BURN
def draw_burn():
    """What the game lays over a floor that is ACTUALLY on fire in this playthrough (WorldState.fire_intensity): three charred windows
    (11x10, the frame sooted, the glass black and cracked) and four soot streaks (11x20, dense at the foot — the window — and
    feathering up the wall). Shared by all three runs."""
    img = Image.new('RGBA', (48, 32), (0, 0, 0, 0))
    c = Canvas(48, 32, seed=3)
    rng = random.Random(31)
    cells = {'char': [], 'soot': []}
    for i in range(3):
        x0 = i * 12
        c.rect(x0, 0, x0 + 10, 9, hexc('231c1a'))
        c.rect(x0 + 1, 1, x0 + 9, 8, hexc('0e0c10'))
        for k in range(4 + i):
            c.put(x0 + rng.randrange(1, 10), rng.randrange(1, 9), hexc('3a3236'))
        for k in range(3):                                          # a pane left hanging, cracked
            c.put(x0 + 2 + k, 1 + k, hexc('4a4044'))
        c.hline(x0 + 5, x0 + 9, 8, hexc('3a2a22'))
        cells['char'].append({'x': x0, 'y': 0, 'w': 11, 'h': 10})
    for i in range(4):
        x0, y0 = i * 12, 12
        for yy in range(20):
            t = 1.0 - yy / 19.0                                     # 1 at the foot, 0 at the top
            half = 2 + int(3.0 * t) + rng.randrange(0, 2)
            for dx in range(-half, half + 1):
                if rng.random() < 0.35 + 0.65 * t:
                    a = int(210 * (t ** 1.3)) - abs(dx) * 14
                    if a > 6:
                        c.put(x0 + 5 + dx, y0 + yy, (24, 20, 20, a))
        cells['soot'].append({'x': x0, 'y': y0, 'w': 11, 'h': 20})
    return c.img, cells


# ============================================================================================================== BUILD
def build(run):
    out = {}
    out['sky_%d.png' % run] = draw_sky(run)
    atlas, cloud_meta = draw_clouds(run)
    out['clouds_%d.png' % run] = atlas
    far, far_meta = draw_far(run)
    out['far_%d.png' % run] = far
    mid, mid_meta = draw_mid(run)
    out['mid_%d.png' % run] = mid
    scene, scene_meta, garden, garden_meta = draw_scene(run)
    out['scene_%d.png' % run] = scene
    out['garden_%d.png' % run] = garden
    if run == 2:                                                  # the afternoon's fog (owner round 36j)
        out['fog_2.png'] = draw_fog(2, 'mid')
        out['fogf_2.png'] = draw_fog(2, 'front')
    fore, fore_meta = draw_fore(run)
    out['fore_%d.png' % run] = fore
    L = LOOK[run]
    meta = {
        'run': run,
        'view': [W, VIEW_H],
        'layers': {'sky': {'p': 0.30, 'h': SKY_H}, 'far': {'p': 0.50, 'h': FAR_H}, 'mid': {'p': 0.75, 'h': MID_H},
                   'scene': {'p': 1.00, 'h': SCENE_H}, 'fog': {'p': 1.08, 'h': SCENE_H, 'drift': 3.0},
                   'garden': {'p': GARDEN_P, 'h': SCENE_H}, 'fogf': {'p': 1.22, 'h': SCENE_H, 'drift': 5.0}, 'fore': {'p': 1.30, 'h': FORE_H, 'lift': 30}},
        'scroll': 457,
        'clouds_atlas': cloud_meta,
        'far': far_meta, 'mid': mid_meta, 'scene': scene_meta, 'garden': garden_meta, 'fore': fore_meta,
        'building': {'x0': BX0, 'x1': BX1, 'ground': GROUND_Y, 'parapet': PARAPET_Y, 'top_floor_y': TOP_Y, 'floor_h': FH},
        'look': {'city_fires': L['city_fires'], 'city_smokes': list(L['city_smokes']), 'rain': run == 3,
                 'night': run == 3, 'fog': run == 2},
    }
    return out, meta


def clouds_placement():
    """Where the game puts clouds: {i atlas index, x, y at camera 0, p parallax, v drift px/s}. A cloud with parallax p sits on
    screen at y + p*c; the targets are picked for the END of the pan (c = scroll) so the title's sky is dressed, then a few
    more are scattered so the middle of the climb has some too."""
    rng = random.Random(2024)
    S = 457
    out = []
    # (x, y on screen at the end of the pan, parallax, atlas index): the sky above the roof — clouds at the edges, the middle open
    end = [(4, 20, 0.50, 0), (196, 30, 0.58, 2), (-14, 68, 0.70, 1), (214, 78, 0.64, 9), (120, 8, 0.46, 6), (96, 96, 0.80, 3),
           (60, 44, 0.54, 7), (236, 52, 0.52, 4), (150, 60, 0.74, 5), (-20, 108, 0.86, 8)]
    for (x, ye, p, i) in end:
        out.append({'i': i, 'x': x, 'y': int(ye - p * S), 'p': p, 'v': round(rng.uniform(1.5, 5.0), 2)})
    # through the middle of the climb (c ~ 150-330), mostly out to the sides of the tower
    for k in range(7):
        p = rng.choice((0.62, 0.7, 0.78, 0.86))
        c_mid = rng.uniform(150, 340)
        ys = rng.randrange(10, 130)
        side = -1 if k % 2 == 0 else 1
        x = rng.randrange(-30, 40) if side < 0 else rng.randrange(196, 262)
        out.append({'i': rng.randrange(0, 10), 'x': x, 'y': int(ys - p * c_mid), 'p': p, 'v': round(rng.uniform(1.5, 5.0), 2)})
    return out


def build_all():
    files = {}
    metas = {}
    for run in RUNS:
        f, m = build(run)
        m['clouds'] = clouds_placement()
        files.update(f)
        metas['opening_meta_%d.json' % run] = m
    burn, cells = draw_burn()
    files['burn.png'] = burn
    birds, birds_meta = opening_birds.draw_birds()
    files['birds.png'] = birds
    for m in metas.values():
        m['burn'] = cells
        m['birds'] = birds_meta
    return files, metas


def write_all(dst=OUT):
    os.makedirs(dst, exist_ok=True)
    files, metas = build_all()
    for name, im in files.items():
        im.save(os.path.join(dst, name))
    for name, m in metas.items():
        with open(os.path.join(dst, name), 'w') as f:
            json.dump(m, f, indent=1, sort_keys=True)
            f.write('\n')
    return files, metas


def compose(files, meta, cam, run):
    img = Image.new('RGBA', (W, VIEW_H), (0, 0, 0, 255))
    L = meta['layers']
    for key in ('sky', 'far', 'mid'):
        top = VIEW_H - L[key]['h'] + int(round(L[key]['p'] * cam))
        img.alpha_composite(files['%s_%d.png' % (key, run)], (0, top))
    atlas = files['clouds_%d.png' % run]
    for cl in meta['clouds']:
        a = meta['clouds_atlas'][cl['i']]
        spr = atlas.crop((a['x'], a['y'], a['x'] + a['w'], a['y'] + a['h']))
        y = cl['y'] + int(round(cl['p'] * cam))
        if -a['h'] < y < VIEW_H:
            img.alpha_composite(spr, (cl['x'], y))
    top = VIEW_H - L['scene']['h'] + int(round(L['scene']['p'] * cam))
    img.alpha_composite(files['scene_%d.png' % run], (0, top))
    for key, f in (('fog', 'fog_%d.png'), ('garden', 'garden_%d.png'), ('fogf', 'fogf_%d.png')):
        if (f % run) in files:
            top = VIEW_H - L[key]['h'] + int(round(L[key]['p'] * cam))
            img.alpha_composite(files[f % run], (0, top))
    top = VIEW_H - L['fore']['h'] + L['fore']['lift'] + int(round(L['fore']['p'] * cam))
    img.alpha_composite(files['fore_%d.png' % run], (0, top))
    return img.convert('RGB')


def preview(files, metas):
    """Composites of the screen at several camera heights, one row per run — what the game will show (without the animation)."""
    rows = []
    for run in RUNS:
        meta = metas['opening_meta_%d.json' % run]
        S = meta['scroll']
        shots = [compose(files, meta, c_, run) for c_ in (0, 120, 240, 340, S)]
        row = Image.new('RGB', (W * len(shots) + 4 * (len(shots) - 1), VIEW_H), (0, 0, 0))
        for i, sh in enumerate(shots):
            row.paste(sh, (i * (W + 4), 0))
        rows.append(row)
        for i, c_ in enumerate((0, 240, S)):
            compose(files, meta, c_, run).resize((W * 4, VIEW_H * 4), Image.NEAREST).save('/tmp/opening_r%d_%d.png' % (run, i))
    sheet = Image.new('RGB', (rows[0].width, sum(r.height for r in rows) + 4 * (len(rows) - 1)), (0, 0, 0))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height + 4
    big = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    os.makedirs(os.path.join(ROOT, 'docs', 'art_reference'), exist_ok=True)
    big.save(os.path.join(ROOT, 'docs', 'art_reference', 'opening.png'))


def check():
    files, metas = build_all()
    bad = []
    for name, im in files.items():
        p = os.path.join(OUT, name)
        if not os.path.exists(p):
            bad.append('missing ' + name)
            continue
        if Image.open(p).convert('RGBA').tobytes() != im.convert('RGBA').tobytes():
            bad.append('stale ' + name)
    for run in RUNS:                                               # the runner's route must stay clear of everything nearer than it
        for (x, r) in runner_clearance(run)[:3]:
            bad.append('runner run %d: covered at x %d, row %d (re-plan with plan_lane)' % (run, x, r))
    for run in RUNS:                                               # the garden's depth order (a far object over a near one is a clipping fault)
        for (ov, near, far) in garden_depth_violations(run):
            bad.append('garden run %d: %s is painted over by the FARTHER %s (%d px)' % (run, near, far, ov))
    for name, m in metas.items():
        mp = os.path.join(OUT, name)
        if not os.path.exists(mp):
            bad.append('missing ' + name)
            continue
        with open(mp) as f:
            if json.load(f) != json.loads(json.dumps(m, sort_keys=True)):
                bad.append('stale ' + name)
    return bad


if __name__ == '__main__':
    if '--check' in sys.argv:
        bad = check()
        if bad:
            print('opening art is out of date:', ', '.join(bad))
            sys.exit(1)
        print('opening art current')
        sys.exit(0)
    files, metas = write_all()
    if '--preview' in sys.argv:
        preview(files, metas)
    print('wrote', ', '.join(sorted(files)), '+', ', '.join(sorted(metas)))
