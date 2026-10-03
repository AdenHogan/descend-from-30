#!/usr/bin/env python3
"""THE OPENING — the exterior shot a NEW GAME begins on (owner round 35: "a nice pixel art exterior image of our building,
clouds in the sky, city scape in the background. Camera pans up the building, then the title of the game, fade to black, then the
run information").

ONE morning, drawn at the game's native look (288x162 shown at 4x = the 1152x648 screen) as PARALLAX LAYERS the game slides at
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


# =============================================================================================================== SKY
SKY_STOPS = [(0.0, hexc('4c7fc4')), (0.30, hexc('6fa3dc')), (0.62, hexc('a9cdea')), (0.84, hexc('e7dcc8')), (1.0, hexc('f8d6ae'))]


def draw_sky():
    c = Canvas(W, SKY_H, seed=1)
    levels = 24
    for y in range(SKY_H):
        t = y / float(SKY_H - 1)
        for x in range(W):
            lv = t * (levels - 1)
            lo = int(lv)
            frac = lv - lo
            q = lo + (1 if frac > bayer(x, y) else 0)
            c.put(x, y, lerp_stops(SKY_STOPS, min(1.0, q / float(levels - 1))))
    # the low sun, behind the far city: a warm bloom of dithered rings and a pale disc
    sx, sy = 66, SKY_H - 104
    rings = [(54, hexc('ffe9c4', 40)), (40, hexc('ffe2b4', 62)), (27, hexc('ffdca8', 90)), (16, hexc('fff0cc', 140))]
    for r, col in rings:
        for y in range(sy - r, sy + r + 1):
            for x in range(sx - r, sx + r + 1):
                d = math.hypot(x - sx, y - sy)
                if d <= r and (d / r) > 0.55 * bayer(x, y):
                    c.put(x, y, col)
    c.ellipse(sx, sy, 6.5, 6.5, hexc('fff6dc'))
    c.ellipse(sx, sy, 4.5, 4.5, hexc('ffffff'))
    return c.img


# ============================================================================================================ CLOUDS
CL_HI, CL_WHITE, CL_BODY, CL_MID, CL_SHADE = hexc('fffaf0'), hexc('f4f6fa'), hexc('dde7f3'), hexc('bccde4'), hexc('a4b0d0')


def cloud_sprite(w, h, rng, kind):
    """A pixel cloud: a union of discs with a flat-ish base, shaded by the depth under its upper edge + a rim of light
    on the sun's side (left), the underside tinted cool. kind: 'big' | 'mid' | 'wisp'."""
    mask = [[False] * w for _ in range(h)]
    base = h - 4 if kind != 'wisp' else h - 2
    if kind == 'wisp':
        for (cx, rx, ry, dy) in ((w * 0.5, w * 0.46, 2.6, 0), (w * 0.34, w * 0.26, 2.0, -2), (w * 0.7, w * 0.2, 1.6, -1)):
            cy = base - ry - dy
            for y in range(h):
                for x in range(w):
                    if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                        mask[y][x] = True
    else:
        n = rng.randrange(6, 9) if kind == 'big' else rng.randrange(4, 6)
        rmax = h * (0.40 if kind == 'big' else 0.46)
        for i in range(n):
            t = (i + 0.5) / n
            cx = int(w * (0.10 + 0.80 * t))
            hump = 1.0 - abs(t - 0.5) * 1.3
            r = max(3.0, rmax * (0.55 + 0.6 * hump * rng.random() + 0.25 * hump))
            cy = base - r * 0.55
            for y in range(h):
                for x in range(w):
                    if (x - cx) ** 2 + ((y - cy) * 1.05) ** 2 <= r * r:
                        mask[y][x] = True
        for x in range(w):                                         # a flat, slightly wavering base
            cut = base + int(round(math.sin(x * 0.45) * 0.8))
            for y in range(cut + 1, h):
                mask[y][x] = False
    c = Canvas(w, h, seed=rng.randrange(10 ** 6))
    for x in range(w):
        depth = 0
        col_top = None
        for y in range(h):
            if not mask[y][x]:
                depth = 0
                continue
            depth += 1
            below = 0
            while y + below + 1 < h and mask[y + below + 1][x]:
                below += 1
            left_edge = 0
            while x - left_edge - 1 >= 0 and mask[y][x - left_edge - 1]:
                left_edge += 1
            right_edge = 0
            while x + right_edge + 1 < w and mask[y][x + right_edge + 1]:
                right_edge += 1
            if below <= 1 and kind != 'wisp':
                col = CL_SHADE if below == 0 else CL_MID
            elif kind != 'wisp' and (below <= 3 or (right_edge <= 2 and depth > 4)):
                col = CL_MID
            elif depth <= 1 or (left_edge <= 1 and depth <= 5):
                col = CL_HI
            elif depth <= 4 + (0 if kind == 'wisp' else 2):
                col = CL_WHITE
            elif depth <= 9:
                col = CL_BODY
            else:
                col = CL_BODY
            if kind == 'wisp':
                col = CL_HI if depth <= 1 else CL_WHITE if depth == 2 else CL_BODY
            c.put(x, y, col)
    return c.img


def draw_clouds():
    rng = random.Random(77)
    specs = [('big', 84, 34), ('big', 72, 30), ('big', 96, 38), ('mid', 52, 20), ('mid', 44, 18), ('mid', 60, 22),
             ('wisp', 80, 9), ('wisp', 64, 8), ('mid', 36, 14), ('big', 64, 26)]
    sprites = [cloud_sprite(w, h, rng, k) for (k, w, h) in specs]
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
def city_layer(h, ground_row, tmin, tmax, wmin, wmax, body, hi, lo, windows, seed, haze_c=None, extras=False, sun_gap=None):
    """A skyline across the layer's full width, towers standing on `ground_row`. Returns (image, meta)."""
    rng = random.Random(seed)
    c = Canvas(W, h, seed=seed)
    meta = {'smoke': [], 'beacon': [], 'fire': []}
    x = -rng.randrange(0, 6)
    towers = []
    while x < W + 4:
        w = rng.randrange(wmin, wmax + 1)
        th = rng.randrange(tmin, tmax + 1)
        if sun_gap is not None and x + w > sun_gap[0] and x < sun_gap[1]:
            th = min(th, sun_gap[2])
        towers.append((x, w, th))
        x += w + rng.randrange(-2, 4)
    for (x, w, th) in towers:
        yt = ground_row - th
        col = body
        c.rect(x, yt, x + w - 1, h - 1, col)
        c.vline(x, yt, h - 1, hi)                                   # the sun's side
        c.hline(x, x + w - 1, yt, hi)
        if w > 4:
            c.vline(x + w - 1, yt + 1, h - 1, lo)
        if windows is not None:
            wcol, wlit = windows
            for wy in range(yt + 4, ground_row - 3, 4):
                for wx in range(x + 2, x + w - 2, 3):
                    r = rng.random()
                    if r < 0.62:
                        c.put(wx, wy, wcol)
                        c.put(wx + 1, wy, wcol)
                    elif r < 0.66 and wlit is not None:
                        c.put(wx, wy, wlit)
                        c.put(wx + 1, wy, wlit)
        # roof kit
        r = rng.random()
        if r < 0.25 and w >= 6:                                      # stepped crown
            sw = w // 2
            sx = x + (w - sw) // 2
            c.rect(sx, yt - 5, sx + sw - 1, yt - 1, col)
            c.vline(sx, yt - 5, yt - 1, hi)
            c.hline(sx, sx + sw - 1, yt - 5, hi)
        elif r < 0.50:                                               # antenna
            ax = x + rng.randrange(1, max(2, w - 1))
            ah = rng.randrange(6, 16) if extras else rng.randrange(3, 8)
            c.vline(ax, yt - ah, yt - 1, lo)
            if extras and rng.random() < 0.5:
                meta['beacon'].append((ax, yt - ah))
        elif r < 0.65 and w >= 7:                                    # a water tank on legs
            tx = x + 1
            c.rect(tx, yt - 6, tx + 4, yt - 3, shade(col, 0.88))
            c.hline(tx - 1, tx + 5, yt - 7, shade(col, 0.8))
            c.vline(tx, yt - 2, yt - 1, lo)
            c.vline(tx + 4, yt - 2, yt - 1, lo)
        if rng.random() < 0.34:
            meta['smoke'].append((x + w // 2, yt))
    if extras:                                                       # a construction crane, long abandoned
        cx = 214
        top = ground_row - 188
        c.vline(cx, top, ground_row, lo)
        c.vline(cx + 1, top, ground_row, lo)
        for yy in range(top, ground_row, 4):
            c.put(cx - 1 if (yy // 4) % 2 else cx + 2, yy, lo)
        c.hline(cx - 26, cx + 16, top, lo)
        c.hline(cx - 26, cx + 16, top + 1, lo)
        c.vline(cx - 26, top, top + 12, lo)                          # the cable and its hook
        c.rect(cx - 27, top + 12, cx - 25, top + 13, lo)
        c.hline(cx + 4, cx + 15, top - 3, lo)
        c.vline(cx + 1, top - 7, top - 1, lo)
        meta['beacon'].append((cx + 1, top - 7))
        # a radio mast
        mx = 22
        mtop = ground_row - 205
        c.vline(mx, mtop, ground_row, lo)
        for k in range(1, 14):
            hw = int(k * 0.55)
            yy = mtop + k * 6
            c.hline(mx - hw, mx + hw, yy, lo)
        meta['beacon'].append((mx, mtop))
    return c.img, meta


def haze_blend(img, color, k):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r + (color[0] - r) * k), int(g + (color[1] - g) * k), int(b + (color[2] - b) * k), a)
    return img


def draw_far():
    img, meta = city_layer(FAR_H, FAR_H - STREET_FROM_BOTTOM, 40, 120, 9, 18, hexc('b4c2d8'), hexc('d0d9e8'), hexc('9fb0cb'),
                           None, 5, extras=True, sun_gap=(34, 100, 30))
    haze_blend(img, hexc('f2e2cc'), 0.22)
    return img, meta


def draw_mid():
    img, meta = city_layer(MID_H, MID_H - STREET_FROM_BOTTOM, 36, 150, 12, 26, hexc('6f7fa4'), hexc('93a3c6'), hexc('566690'),
                           (hexc('5e6e94'), hexc('f1d58c')), 11, sun_gap=(30, 104, 44))
    return img, meta


# ======================================================================================================= THE BUILDING
FONT3 = {
    'H': ['X.X', 'X.X', 'XXX', 'X.X', 'X.X'],
    'E': ['XXX', 'X..', 'XX.', 'X..', 'XXX'],
    'L': ['X..', 'X..', 'X..', 'X..', 'XXX'],
    'P': ['XX.', 'X.X', 'XX.', 'X..', 'X..'],
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


def bay_x(b):
    return INNER_X0 + b * BAY_W


def draw_window(c, bx, y, state, sec, rng, meta, floor, bay):
    """bx = the bay's left x, y = the floor band's top. Frame 11x10 at (bx+2, y+2), glass 9x8 inside it."""
    P = PAL[sec]
    fx, fy = bx + 2, y + 2
    c.rect(fx, fy, fx + 10, fy + 9, P['frame'])
    gx, gy = fx + 1, fy + 1
    # the glass
    for yy in range(8):
        for xx in range(9):
            t = yy / 7.0
            col = mix(GLASS_TOP, GLASS_BOT, t)
            if state in ('dark', 'curtain', 'open', 'lit', 'broken', 'boarded', 'burnt'):
                col = mix(DARK_IN, hexc('59647a'), 0.25 * (1 - t))
            c.put(gx + xx, gy + yy, col)
    if state in ('dark', 'curtain', 'open'):
        # the sky's reflection: a pale diagonal glint across the upper left
        for k in range(4):
            c.put(gx + 1 + k, gy + 3 - k, hexc('b4d2ea'))
        c.put(gx + 2 + 4, gy + 2 - 2 if False else gy, hexc('b4d2ea'))
        for k in range(3):
            c.put(gx + 4 + k, gy + 5 - k, hexc('88acc8'))
    if state == 'curtain':
        col = rng.choice(CURTAINS)
        dk = shade(col, 0.78)
        wd = rng.choice((2, 3))
        for yy in range(8):
            for xx in range(wd):
                c.put(gx + xx, gy + yy, col if (yy + xx) % 3 else dk)
                c.put(gx + 8 - xx, gy + yy, col if (yy + xx) % 3 else dk)
        if rng.random() < 0.35:                                     # drawn right across
            for yy in range(8):
                for xx in range(wd, 9 - wd):
                    c.put(gx + xx, gy + yy, col if (yy * 2 + xx) % 4 else dk)
    elif state == 'lit':
        glow = hexc('ffd37c')
        core = hexc('ffeaa8')
        for yy in range(8):
            for xx in range(9):
                c.put(gx + xx, gy + yy, glow if (xx + yy) % 5 else core)
        c.hline(gx, gx + 8, gy + 7, hexc('d99a48'))
        wd = rng.choice((1, 2))
        col = rng.choice(CURTAINS)
        for yy in range(8):
            for xx in range(wd):
                c.put(gx + xx, gy + yy, shade(col, 0.95))
                c.put(gx + 8 - xx, gy + yy, shade(col, 0.95))
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
        wood = hexc('9a7650')
        dk = hexc('6e5236')
        for k, yy in enumerate((1, 4)):
            c.rect(gx - 1, gy + yy, gx + 9, gy + yy + 1, wood)
            c.hline(gx - 1, gx + 9, gy + yy + 1, dk)
            c.put(gx + 1, gy + yy, dk)
            c.put(gx + 7, gy + yy, dk)
    elif state == 'burnt':
        c.rect(gx, gy, gx + 8, gy + 7, hexc('171418'))
        for _ in range(5):
            c.put(gx + rng.randrange(1, 8), gy + rng.randrange(3, 8), hexc('c4552a'))
        c.rect(fx, fy, fx + 10, fy + 9, hexc('2b231f')) if False else None
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


def draw_facade(c, rng, meta):
    """The tower's 30 floors, the sectional palette, sills, balconies, windows in all their states."""
    # fire stretch + other fixed story beats
    fire_floors = {17: (3, 4), 16: (3,)}
    help_floor, help_bay = 24, 5
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
        fire_bays = fire_floors.get(n, ())
        for b in range(BAYS):
            bx = bay_x(b)
            if b in balcony_bays and (n + b) % 2 == 0 and n != 30 and n not in fire_floors:
                draw_balcony_bay(c, bx, y, sec, rng, meta, n, b)
                continue
            if b in fire_bays:
                state = 'burnt'
            elif n == 30 and b == 2:
                state = 'lit'                                         # where you wake
            else:
                wear = (30 - n) / 29.0                                # more ruin the further down
                r = rng.random()
                if r < 0.07 + 0.05 * wear:
                    state = 'broken' if rng.random() < 0.6 else 'boarded'
                elif r < 0.14 + 0.05 * wear:
                    state = 'open'
                elif r < 0.21:
                    state = 'lit'
                elif r < 0.56:
                    state = 'curtain'
                else:
                    state = 'dark'
            draw_window(c, bx, y, state, sec, rng, meta, n, b)
        # section ledges: a cornice at the top floor and where a section begins
        if n in (30, 21, 11):
            c.hline(BX0 - 1, BX1 + 1, y, shade(P['band'], 1.1))
            c.hline(BX0 - 1, BX1 + 1, y + 1, P['band'])
            c.hline(BX0 - 2, BX1 + 2, y + 2, shade(P['band'], 0.8))
        if n == 1:
            c.hline(BX0 - 1, BX1 + 1, y + FH - 1, shade(PAL['concrete']['band'], 0.8))
    # the sheet: HELP, hung from a window and weighted at the corners
    hy = floor_y(help_floor)
    hx = bay_x(help_bay)
    sheet = hexc('ece6d6')
    c.rect(hx - 2, hy + 11, hx + 17, hy + 11 + 12, sheet)
    c.hline(hx - 2, hx + 17, hy + 11 + 12, hexc('c9c2b0'))
    for k in range(0, 16, 3):
        c.vline(hx - 2 + k + 1, hy + 11, hy + 11 + 12, hexc('d9d2c0'))
    text3(c, hx + 1, hy + 15, 'HELP', hexc('b3231c'))
    c.put(hx - 2, hy + 10, hexc('4a4038'))
    c.put(hx + 17, hy + 10, hexc('4a4038'))
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


def draw_street(c, rng, meta):
    """Pavement, kerb, road; a wrecked car, a streetlamp, a hydrant, bags, litter, a manhole, the outbreak's mark."""
    c.rect(0, GROUND_Y, W - 1, SCENE_H - 1, hexc('7d7a76'))
    # pavement: slabs with cracks, then the kerb, then the road
    c.rect(0, GROUND_Y, W - 1, GROUND_Y + 13, hexc('a39f96'))
    c.hline(0, W - 1, GROUND_Y, hexc('d0ccc0'))
    for xx in range(0, W, 24):
        c.vline(xx, GROUND_Y + 1, GROUND_Y + 13, hexc('8a867e'))
    for _ in range(14):
        sx, sy = rng.randrange(0, W), GROUND_Y + rng.randrange(2, 12)
        for k in range(rng.randrange(3, 8)):
            c.put(sx + k, sy + (k % 2), hexc('6c6862'))
    c.hline(0, W - 1, GROUND_Y + 14, hexc('d9d5c8'))
    c.hline(0, W - 1, GROUND_Y + 15, hexc('6a665f'))
    road_y = GROUND_Y + 16
    c.rect(0, road_y, W - 1, SCENE_H - 1, hexc('4a4a52'))
    for yy in range(road_y, SCENE_H):
        for xx in range(W):
            if rng.random() < 0.05:
                c.put(xx, yy, hexc('5a5a64') if rng.random() < 0.5 else hexc('3a3a42'))
    for xx in range(4, W, 36):                                         # the centre line, worn
        c.rect(xx, road_y + 17, xx + 15, road_y + 18, hexc('c9b24a'))
        for k in range(4):
            c.put(xx + rng.randrange(0, 16), road_y + 17 + rng.randrange(0, 2), hexc('4a4a52'))
    c.ellipse(60, road_y + 8, 7, 2.2, hexc('3a3a42'))                  # a manhole, its lid off-centre
    c.ellipse(60, road_y + 7, 6, 1.6, hexc('55555e'))
    # the car (left): a sedan stopped half on the kerb, doors open, glass out, a tyre flat
    car(c, 8, GROUND_Y + 10, hexc('7c2a2e'), rng)
    # the other car (right), nose-in on the road, dark and sooty
    car(c, 214, road_y + 4, hexc('2f3846'), rng, flip=True)
    # hydrant
    c.rect(52, GROUND_Y + 5, 55, GROUND_Y + 12, hexc('b33a2a'))
    c.rect(51, GROUND_Y + 7, 56, GROUND_Y + 8, hexc('8a2a1e'))
    c.hline(52, 55, GROUND_Y + 4, hexc('d4604a'))
    c.hline(51, 56, GROUND_Y + 13, hexc('5a2018'))
    # streetlamp (right of the building): a pole, an arm, a head — bent a little
    lx = 232
    c.vline(lx, GROUND_Y - 56, GROUND_Y + 12, hexc('3a3f48'))
    c.vline(lx + 1, GROUND_Y - 56, GROUND_Y + 12, hexc('5a606a'))
    c.hline(lx - 12, lx + 1, GROUND_Y - 57, hexc('3a3f48'))
    c.rect(lx - 16, GROUND_Y - 56, lx - 10, GROUND_Y - 53, hexc('2c3038'))
    c.hline(lx - 15, lx - 11, GROUND_Y - 52, hexc('c9c2a0'))
    c.rect(lx - 3, GROUND_Y + 10, lx + 4, GROUND_Y + 12, hexc('2c3038'))
    meta['lamp'] = {'x': lx - 13, 'y': GROUND_Y - 52}
    # bags, a cart, litter, papers
    for (bx, by, col) in ((70, 9, hexc('1c1c22')), (74, 10, hexc('2a2a32')), (66, 11, hexc('1c1c22')), (250, 8, hexc('24262e'))):
        c.ellipse(bx, GROUND_Y + by, 3.2, 2.6, col)
        c.put(bx - 1, GROUND_Y + by - 3, shade(col, 1.4))
        c.put(bx - 1, GROUND_Y + by - 1, shade(col, 1.6))
    for _ in range(20):
        c.put(rng.randrange(0, W), GROUND_Y + rng.randrange(2, 13), hexc('e4e0d0') if rng.random() < 0.7 else hexc('b9605a'))
    # a shopping cart on its side
    cx = 36
    c.hline(cx, cx + 10, GROUND_Y + 9, hexc('8a9098'))
    c.hline(cx, cx + 10, GROUND_Y + 6, hexc('8a9098'))
    c.vline(cx, GROUND_Y + 6, GROUND_Y + 9, hexc('8a9098'))
    c.vline(cx + 10, GROUND_Y + 6, GROUND_Y + 9, hexc('8a9098'))
    for k in range(1, 10, 2):
        c.vline(cx + k, GROUND_Y + 7, GROUND_Y + 8, hexc('6a7078'))
    c.put(cx + 1, GROUND_Y + 11, hexc('2c2c2c'))
    c.put(cx + 9, GROUND_Y + 11, hexc('2c2c2c'))
    # the lamp's pool of light on the pavement, and dark stains on the road
    for k in range(5):
        c.put(206 + k * 3, road_y + 12 + (k % 2), hexc('5a2a2a'))
    for (sx, sy, rx) in ((100, road_y + 10, 9), (160, road_y + 22, 6)):
        c.ellipse(sx, sy, rx, 2.2, hexc('4a2a2e'))


def car(c, x, y, body, rng, flip=False):
    """A sedan in side view, ~44 wide. y = its wheels' ground line."""
    w = 44
    def X(dx):
        return x + (w - 1 - dx if flip else dx)
    def R(dx0, dy0, dx1, dy1, col):
        a, b = X(dx0), X(dx1)
        c.rect(min(a, b), y + dy0, max(a, b), y + dy1, col)
    dk = shade(body, 0.62)
    lt = shade(body, 1.22)
    R(0, -9, 43, -3, body)                                         # lower body
    R(2, -10, 41, -9, lt)
    R(9, -17, 33, -10, body)                                       # cabin
    R(10, -16, 32, -10, hexc('29303c'))                            # glass, dark
    for k in range(5):
        c.put(X(12 + k), y - 15 + k // 2 if False else y - 15, hexc('8aa4bc'))
    R(21, -16, 21, -10, body)                                      # the B pillar
    R(0, -4, 43, -3, dk)
    R(0, -2, 43, -2, hexc('1c1c22'))
    for wx in (9, 34):                                             # wheels
        a = X(wx)
        c.ellipse(a, y - 2, 4.2, 4.0, hexc('16161c'))
        c.ellipse(a, y - 2, 2.2, 2.2, hexc('7a7e86'))
        c.put(a, y - 2, hexc('2c2c34'))
    c.put(X(0), y - 7, hexc('d9c36a'))
    c.put(X(43), y - 7, hexc('a8281e'))
    # an open door hanging, and glass on the ground
    R(14, -15, 14, -4, shade(body, 0.8))
    for _ in range(8):
        c.put(X(rng.randrange(0, 44)), y + rng.randrange(0, 2), hexc('cfe2ee'))


def draw_scene():
    rng = random.Random(404)
    c = Canvas(W, SCENE_H, seed=404)
    meta = {'lit': [], 'smoke': [], 'beacon': []}
    draw_facade(c, rng, meta)
    draw_roof(c, rng, meta)
    draw_entrance(c, rng, meta)
    draw_street(c, rng, meta)
    # window-on-window shadow cast by the floor above, a soft band under each ledge
    return c.img, meta


# =============================================================================================================== FORE
def draw_fore():
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
    for k, (y0, sag) in enumerate(((22, 10), (23, 8), (21, 12))):
        pts = []
        for x in range(px + 10, W):
            t = (x - px - 10) / float(W - px - 10)
            y = y0 + sag * math.sin(t * math.pi / 2.0) * 0.9 + t * 8
            pts.append((x, int(round(y))))
            c.put(x, int(round(y)), dark)
        wires.append(pts)
    # crows on the wires
    for (wi, x) in ((0, 104), (0, 117), (1, 190)):
        for (xx, yy) in wires[wi]:
            if xx == x:
                crow(c, xx, yy - 1)
    return c.img


def crow(c, x, y):
    k = hexc('15151a')
    c.rect(x - 2, y - 4, x + 2, y - 1, k)
    c.rect(x + 2, y - 5, x + 4, y - 3, k)
    c.put(x + 5, y - 4, hexc('8a6a2a'))
    c.hline(x - 5, x - 3, y - 3, k)
    c.put(x - 1, y, k)
    c.put(x + 1, y, k)


# ============================================================================================================== BUILD
def build():
    out = {}
    out['sky.png'] = draw_sky()
    atlas, cloud_meta = draw_clouds()
    out['clouds.png'] = atlas
    far, far_meta = draw_far()
    out['far.png'] = far
    mid, mid_meta = draw_mid()
    out['mid.png'] = mid
    scene, scene_meta = draw_scene()
    out['scene.png'] = scene
    out['fore.png'] = draw_fore()
    meta = {
        'view': [W, VIEW_H],
        'layers': {'sky': {'p': 0.30, 'h': SKY_H}, 'far': {'p': 0.50, 'h': FAR_H}, 'mid': {'p': 0.75, 'h': MID_H},
                   'scene': {'p': 1.00, 'h': SCENE_H}, 'fore': {'p': 1.30, 'h': FORE_H, 'lift': 30}},
        'scroll': 457,
        'clouds_atlas': cloud_meta,
        'far': far_meta, 'mid': mid_meta, 'scene': scene_meta,
        'building': {'x0': BX0, 'x1': BX1, 'ground': GROUND_Y, 'parapet': PARAPET_Y, 'top_floor_y': TOP_Y, 'floor_h': FH},
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


def write_all(dst=OUT):
    os.makedirs(dst, exist_ok=True)
    files, meta = build()
    meta['clouds'] = clouds_placement()
    for name, im in files.items():
        im.save(os.path.join(dst, name))
    with open(os.path.join(dst, 'opening_meta.json'), 'w') as f:
        json.dump(meta, f, indent=1, sort_keys=True)
        f.write('\n')
    return files, meta


def preview(files, meta):
    """Composites of the screen at several camera heights — what the game will show."""
    S = meta['scroll']
    shots = []
    for c_ in (0, 120, 240, 340, S):
        shots.append(compose(files, meta, c_))
    sheet = Image.new('RGB', (W * len(shots) + 4 * (len(shots) - 1), VIEW_H), (0, 0, 0))
    for i, s in enumerate(shots):
        sheet.paste(s, (i * (W + 4), 0))
    big = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    os.makedirs(os.path.join(ROOT, 'docs', 'art_reference'), exist_ok=True)
    big.save(os.path.join(ROOT, 'docs', 'art_reference', 'opening.png'))
    for i, c_ in enumerate((0, 240, S)):
        compose(files, meta, c_).resize((W * 4, VIEW_H * 4), Image.NEAREST).save('/tmp/opening_%d.png' % i)


def compose(files, meta, cam):
    img = Image.new('RGBA', (W, VIEW_H), (0, 0, 0, 255))
    L = meta['layers']

    def put(name, p, h, lift=0):
        top = VIEW_H - h + lift + int(round(p * cam))
        img.alpha_composite(files[name], (0, top)) if top > -h and top < VIEW_H else None
        return top

    for name, key in (('sky.png', 'sky'), ('far.png', 'far'), ('mid.png', 'mid')):
        top = VIEW_H - L[key]['h'] + int(round(L[key]['p'] * cam))
        img.alpha_composite(files[name], (0, top))
    # clouds
    atlas = files['clouds.png']
    for cl in meta['clouds']:
        a = meta['clouds_atlas'][cl['i']]
        spr = atlas.crop((a['x'], a['y'], a['x'] + a['w'], a['y'] + a['h']))
        y = cl['y'] + int(round(cl['p'] * cam))
        img.alpha_composite(spr, (cl['x'], y)) if -a['h'] < y < VIEW_H else None
    top = VIEW_H - L['scene']['h'] + int(round(L['scene']['p'] * cam))
    img.alpha_composite(files['scene.png'], (0, top))
    top = VIEW_H - L['fore']['h'] + L['fore']['lift'] + int(round(L['fore']['p'] * cam))
    img.alpha_composite(files['fore.png'], (0, top))
    return img.convert('RGB')


def check():
    files, meta = build()
    meta['clouds'] = clouds_placement()
    bad = []
    for name, im in files.items():
        p = os.path.join(OUT, name)
        if not os.path.exists(p):
            bad.append('missing ' + name)
            continue
        if Image.open(p).convert('RGBA').tobytes() != im.convert('RGBA').tobytes():
            bad.append('stale ' + name)
    mp = os.path.join(OUT, 'opening_meta.json')
    if not os.path.exists(mp):
        bad.append('missing opening_meta.json')
    else:
        with open(mp) as f:
            if json.load(f) != json.loads(json.dumps(meta, sort_keys=True)):
                bad.append('stale opening_meta.json')
    return bad


if __name__ == '__main__':
    if '--check' in sys.argv:
        bad = check()
        if bad:
            print('opening art is out of date:', ', '.join(bad))
            sys.exit(1)
        print('opening art current')
        sys.exit(0)
    files, meta = write_all()
    if '--preview' in sys.argv:
        preview(files, meta)
    print('wrote', ', '.join(sorted(files)), '+ opening_meta.json')
