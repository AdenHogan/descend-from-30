#!/usr/bin/env python3
"""THE HUD PORTRAITS (owner 2026-11-22: "replace the HUD portraits to match the new characters, but remember they need to be more detailed").

Six health stages for each of the four players, 281 x 351 like the ones they replace (assets/Health_Bar/<char_id> - N - <Stage>.png).  Each is painted here at
94 x 117 working pixels and shown at x3 (nearest), so a portrait pixel is three screen pixels: far finer than the chunky 1.5-px sprite, but the same people —
the colours, hair, garments and marks come straight from `people.PLAYERS` / the per-character notes below (one source of truth), and the shading is the same
rule as the sprites (five tones of one colour, `people.tones`, lit from the upper left), only with real volume: a head, a neck, a jaw, a nose, lids, lips.

    python3 tools/art/portraits.py              ->  assets/Health_Bar/*.png  +  docs/art_reference/portraits/*  (contact sheets)

Character ids (WorldState.current_character()): blond_man = Joe, blond_woman = Vivianne, bald_man = Alex, dark_woman = Amina.
Stages (hud.gd PORTRAIT_STAGES): 1 Healthy, 2 Hurt, 3 Injured, 4 Wounded, 5 Severely Wounded, 6 Dying — each worse than the last (a scratch, a bruise and a split lip,
a bandage, a soaked bandage and a shut eye, then ashen and slack with blood down the face).
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

import people as P

W, H = 94, 117
UP = 3
CX = 46.0                                   # the head's middle column
HY = 47.0                                   # the head's middle row
YAW = 4.0                                   # the face is turned this far to the right (the sprites face right)
OUTLINE = (30, 16, 36)
LIGHT = np.array([-0.46, -0.56, 0.69])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
OUT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'Health_Bar'))
REF = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'art_reference', 'portraits'))
STAGES = ['1 - Healthy', '2 - Hurt', '3 - Injured', '4 - Wounded', '5 - Severely Wounded', '6 - Dying']
IDS = {'joe': 'blond_man', 'vivianne': 'blond_woman', 'alex': 'bald_man', 'amina': 'dark_woman'}

YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)
# a fixed screen of noise that nudges where one tone ends and the next begins, so the bands are not ruler-straight (the old portraits' painted edge)
_rng = np.random.RandomState(7)
DITHER = (_rng.rand(H, W).astype(np.float32) - 0.5) * 0.10


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def tone_set(hexcol, pallor=0.0, lo=0.78, hi=1.14):
    """The sprites' five tones of one colour, optionally drained toward a sick grey-green (`pallor`)."""
    t = P.tones(hexcol, lo, hi, mute=0.0)
    if pallor > 0.0:
        sick = (150, 156, 140)
        t = {k: mix(v[:3], sick, pallor) + (255,) for k, v in t.items()}
    return {k: np.array(v[:3], dtype=np.uint8) for k, v in t.items()}


class Canvas:
    def __init__(self):
        self.rgb = np.zeros((H, W, 3), dtype=np.uint8)
        self.alpha = np.zeros((H, W), dtype=bool)
        self.who = np.zeros((H, W), dtype=np.uint8)        # which layer last painted a pixel (for the outline's sake)

    def paint(self, mask, colour_fn):
        ys, xs = np.nonzero(mask)
        for y, x in zip(ys, xs):
            self.rgb[y, x] = colour_fn(y, x)
        self.alpha |= mask

    def paint_arr(self, mask, arr):
        self.rgb[mask] = arr[mask]
        self.alpha |= mask

    def px(self, x, y, col):
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < W and 0 <= yi < H:
            self.rgb[yi, xi] = col[:3]
            self.alpha[yi, xi] = True

    def px_on(self, x, y, col, onto):
        """Paint a pixel only where `onto` (a mask) is set — a mark never leaves the thing it is on."""
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < W and 0 <= yi < H and onto[yi, xi]:
            self.rgb[yi, xi] = col[:3]

    def line(self, p0, p1, col, onto=None, w=1.0):
        n = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1])) * 2) + 1
        for i in range(n + 1):
            t = i / float(n)
            x, y = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
            for dx in range(-int(w), int(w) + 1):
                for dy in range(-int(w), int(w) + 1):
                    if dx * dx + dy * dy <= w * w + 0.25:
                        if onto is None:
                            self.px(x + dx, y + dy, col)
                        else:
                            self.px_on(x + dx, y + dy, col, onto)

    def image(self, outline=True):
        im = np.zeros((H, W, 4), dtype=np.uint8)
        im[..., :3] = self.rgb
        im[..., 3] = np.where(self.alpha, 255, 0)
        if outline:
            a = self.alpha
            edge = np.zeros_like(a)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                sh = np.roll(np.roll(a, dy, 0), dx, 1)
                edge |= (~a) & sh
            edge[0, :] = edge[-1, :] = False
            im[edge, :3] = OUTLINE
            im[edge, 3] = 255
        return Image.fromarray(im, 'RGBA')


def lambert(nx, ny, nz):
    return nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]


def band(l, tones, cuts=(-0.28, 0.12, 0.50, 0.80)):
    """Light -> one of the five tones, with the edge between two of them wandering a little."""
    l = l + DITHER
    idx = np.zeros(l.shape, dtype=np.int32)
    for c in cuts:
        idx += (l > c)
    order = ['dd', 'd', 'm', 'l', 'll']
    out = np.zeros(l.shape + (3,), dtype=np.uint8)
    for i, k in enumerate(order):
        out[idx == i] = tones[k]
    return out


def ellipsoid(cx, cy, rx, ry, rz=None, skew=None):
    """-> (mask, nx, ny, nz) of an ellipsoid seen from the front."""
    rz = rz or min(rx, ry) * 0.95
    u = (XX + 0.5 - cx) / rx
    v = (YY + 0.5 - cy) / ry
    d = u * u + v * v
    m = d <= 1.0
    w = np.sqrt(np.clip(1.0 - d, 0.0, 1.0))
    nx, ny, nz = u / 1.0, v / 1.0, w * (rz / max(rx, ry)) * 1.7
    n = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    return m, nx / n, ny / n, nz / n


# -------------------------------------------------------------------------------------------------------------------------------------------------
# the people: what is theirs (hair shape, clothes, the little things)
# -------------------------------------------------------------------------------------------------------------------------------------------------
LOOK = {
    'joe': dict(gender='m', hair_style='mop', hair_light='7a5a3e', brow=0.8, eye='5a6a7a', lips='c08070', stubble=True, jaw=0.0, cloth='teal'),
    'vivianne': dict(gender='f', hair_style='lob', hair_light='fbe9a4', brow=0.6, eye='5a82a8', lips='d4707a', blush='f4a8a8', lash=True, jaw=-0.12, cloth='coral'),
    'alex': dict(gender='m', hair_style='crop', hair_light='3a2e36', brow=1.0, eye='2a1a14', lips='7a3c34', jaw=0.1, cloth='overalls'),
    'amina': dict(gender='f', hair_style='long', hair_light='4a4658', brow=0.8, eye='2a1a14', lips='9c4a44', lash=True, earring='f0d060', jaw=-0.08, cloth='cardigan'),
}


def head_masks(look):
    """The head: an ellipsoid with the jaw drawn in (a narrower chin) -> mask, normals."""
    cx, cy = CX - 1.0, HY
    rx, ry = 20.5, 25.5
    m, nx, ny, nz = ellipsoid(cx, cy, rx, ry, 19.0)
    # jaw: below the cheekbone line the half-width falls away to the chin
    t = np.clip((YY + 0.5 - (cy + 6.0)) / (ry - 6.0), 0.0, 1.0)
    narrow = 1.0 - (0.30 + look.get('jaw', 0.0)) * (t ** 1.35)
    u = (XX + 0.5 - cx) / (rx * narrow)
    v = (YY + 0.5 - cy) / ry
    d = u * u + v * v
    m = d <= 1.0
    w = np.sqrt(np.clip(1.0 - d, 0.0, 1.0))
    nx, ny, nz = u, v, w * 1.2
    n = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    return m, nx / n, ny / n, nz / n


def draw_person(who, stage, seed=1):
    look = LOOK[who]
    p = next(q for q in P.PLAYERS if q['name'] == who)
    rng = random.Random(seed * 131 + stage)
    pallor = (0.0, 0.0, 0.06, 0.16, 0.30, 0.46)[stage - 1]
    skin = tone_set(p['skin'], pallor, 0.80, 1.10)
    hair_t = tone_set(p['hair'], 0.0, 0.70, 1.18)
    hair_lt = np.array(hexrgb(look['hair_light']), dtype=np.uint8)
    coat = tone_set(p['coat'], 0.0, 0.80, 1.14)
    c = Canvas()
    cx, cy = CX - 1.0, HY

    # ---- the body: shoulders, a short neck ---------------------------------------------------------------------------------------------------
    sm, snx, sny, snz = ellipsoid(CX, 132.0, 53.0, 62.0, 40.0)
    shoulders = sm & (YY < H)
    c.snorm = (snx, sny, snz)
    c.paint_arr(shoulders, band(lambert(snx, sny, snz), coat))
    # a ridge where the garment folds at each shoulder, and one deep fold down the chest
    for (x0, y0, x1, y1) in ((12, 100, 30, 112), (82, 98, 66, 112)):
        c.line((x0, y0), (x1, y1), coat['d'], onto=shoulders)
    # the neck
    nk = (np.abs(XX + 0.5 - (CX + 1.0)) < 8.2) & (YY > cy + 17) & (YY < 92)
    nxn = np.clip((XX + 0.5 - (CX + 1.0)) / 8.2, -1, 1)
    nzn = np.sqrt(np.clip(1.0 - nxn * nxn, 0, 1))
    c.paint_arr(nk & ~shoulders | (nk & (YY < 84)), band(lambert(nxn, np.zeros_like(nxn), nzn) - 0.08, skin))
    # the chin's shadow on the neck
    hm0, _a, _b, _c = head_masks(look)
    bot = np.where(hm0.any(axis=0), (YY * hm0).max(axis=0), 0).astype(np.float32)        # the lowest head pixel of each column
    depth = YY - bot[None, :]
    c.rgb[nk & (depth >= 0) & (depth < 3.2)] = skin['dd']
    c.rgb[nk & (depth >= 3.2) & (depth < 7.0) & (((XX.astype(int) + YY.astype(int)) % 3) != 0)] = skin['d']

    _clothes(c, who, p, look, coat, skin, shoulders, rng, stage)
    if look['hair_style'] in ('lob', 'long'):
        _hair_back(c, look, hair_t, hair_lt, cx, cy, rng)

    # ---- the head ----------------------------------------------------------------------------------------------------------------------------
    hm, hnx, hny, hnz = head_masks(look)
    # the face turns to the right: the normals swing with it
    hnx2 = hnx * math.cos(0.30) + hnz * math.sin(0.30) * -1.0 + 0.0
    face_img = band(lambert(hnx, hny, hnz) - 0.10 - 0.12 * np.clip((XX - cx) / 20.0, 0, 1), skin, cuts=(-0.32, 0.08, 0.46, 0.80))
    # ear (near side)
    em, enx, eny, enz = ellipsoid(cx - 19.5, cy + 3.0, 3.6, 6.4, 3.0)
    c.paint_arr(em & ~hm, band(lambert(enx, eny, enz) - 0.1, skin))
    c.paint_arr(hm, face_img)
    inner = em & ((XX - (cx - 19.8)) ** 2 / 1.6 + (YY - (cy + 3.0)) ** 2 / 9.0 < 1.0)
    c.rgb[inner] = skin['d']
    if look.get('earring'):
        for dy in range(0, 4):
            c.px(cx - 19.5, cy + 9 + dy, hexrgb(look['earring']))
        c.px(cx - 19.5, cy + 13, mix(hexrgb(look['earring']), (255, 255, 255), 0.5))

    _face(c, who, p, look, skin, hm, hnx, hny, hnz, cx, cy, stage, rng, hair_t)
    _hair(c, who, p, look, hair_t, hair_lt, skin, hm, cx, cy, rng, stage)
    _wounds(c, who, p, look, skin, hm, shoulders, cx, cy, stage, rng, hair_t)
    return c


# -------------------------------------------------------------------------------------------------------------------------------------------------
def _face(c, who, p, look, skin, hm, hnx, hny, hnz, cx, cy, stage, rng, hair_t):
    eye_y = cy - 1.5
    s = YAW
    ex_near, ex_far = cx + s - 8.6, cx + s + 8.0
    mood = {1: 'calm', 2: 'worry', 3: 'worry', 4: 'pain', 5: 'slack', 6: 'out'}[stage]
    ink = tuple(int(v) for v in hair_t['dd'])
    eye_col = hexrgb(look['eye'])
    white = mix(tuple(int(v) for v in skin['ll']), (245, 245, 240), 0.55)
    white_sh = mix(white, tuple(int(v) for v in skin['d']), 0.45)
    droop = {1: 0.0, 2: 0.0, 3: 0.4, 4: 0.8, 5: 1.4, 6: 2.6}[stage]
    for k, (ex, wd) in enumerate(((ex_near, 8.6), (ex_far, 7.0))):
        # the eye: an almond of white, an iris, a pupil, a catch-light
        ey = eye_y + (0.6 if k else 0.0)
        lid_close = min(1.0, droop / 2.6)
        for yy in range(int(ey - 4), int(ey + 5)):
            for xx in range(int(ex - 6), int(ex + 7)):
                u = (xx + 0.5 - ex) / (wd / 2.0)
                v = (yy + 0.5 - ey) / (2.9 - 1.9 * lid_close)
                if u * u * 0.8 + v * v * 1.0 <= 1.0 and (stage < 6 or abs(v) < 0.5):
                    c.px(xx, yy, white if v > -0.2 else white_sh)
        if stage < 6:
            ir = 2.6 if stage < 5 else 2.2
            ix = ex + 0.9 + (0.0 if k == 0 else -0.3)
            iy = ey + 0.3 + droop * 0.15
            for yy in range(int(iy - 3), int(iy + 4)):
                for xx in range(int(ix - 3), int(ix + 4)):
                    d = math.hypot(xx + 0.5 - ix, yy + 0.5 - iy)
                    if d <= ir:
                        top_cut = (yy + 0.5) < (ey - 1.6 + droop * 0.9)
                        if top_cut:
                            continue
                        shade = mix(eye_col, (255, 255, 255), 0.18) if (xx + 0.5 - ix) < -0.5 and (yy + 0.5 - iy) < 0.5 else eye_col
                        c.px(xx, yy, shade)
                        if d <= ir * 0.52:
                            c.px(xx, yy, (18, 10, 16))
            c.px(ix - 1.2, iy - 1.1, (255, 255, 255))
        # lids: the dark top lash line, the crease above it, the lower rim
        lid_y = ey - 2.6 + droop * 0.9
        for xx in range(int(ex - wd / 2.0), int(ex + wd / 2.0) + 1):
            t = (xx - ex) / (wd / 2.0)
            yy = lid_y + 0.9 * t * t + (0.5 if look['gender'] == 'm' else 0.0) * 0
            c.px(xx, yy, ink)
            if look.get('lash') and t < -0.55:
                c.px(xx - 1, yy - 1, ink)
            c.px(xx, yy - 1.6, tuple(int(v) for v in skin['d']))
        for xx in range(int(ex - wd / 2.0 + 1), int(ex + wd / 2.0)):
            c.px(xx, ey + 3.0 - 0.4 * lid_close, tuple(int(v) for v in skin['d']))
        if stage >= 3:                                                                         # shadow under the eye: tired, then ill
            for xx in range(int(ex - 4), int(ex + 5)):
                for dy in (4.0, 5.0):
                    c.px_on(xx, ey + dy, tuple(int(v) for v in mix(tuple(int(q) for q in skin['d']), (90, 60, 110), 0.25 * min(1.0, (stage - 2) / 3.0))), hm)
        if stage == 6:                                                                         # shut: a heavy lid, a lash line
            for xx in range(int(ex - wd / 2.0), int(ex + wd / 2.0) + 1):
                c.px(xx, ey + 0.4, ink)
                c.px(xx, ey - 0.6, tuple(int(v) for v in skin['d']))
    # brows
    bw = look['brow']
    brow_col = tuple(int(v) for v in hair_t['dd'])
    tilt = {'calm': 0.0, 'worry': 1.6, 'pain': 2.4, 'slack': 0.6, 'out': 1.0}[mood]
    for k, (ex, wd) in enumerate(((ex_near, 9.4), (ex_far, 7.6))):
        by = eye_y - 7.6 - (1.2 if mood in ('worry', 'pain') else 0.0) + (0.8 if mood == 'slack' else 0.0)
        inner_x = ex + (wd / 2.0 if k == 0 else -wd / 2.0)
        for i in range(int(wd) + 1):
            t = i / max(1.0, wd)
            xx = ex - wd / 2.0 + wd * t
            near_inner = (t if k == 0 else 1.0 - t)
            yy = by + 1.2 * (1.0 - 4.0 * (t - 0.5) ** 2) * -1.0 - tilt * near_inner
            for th in range(int(1 + bw)):
                c.px_on(xx, yy + th - 0.5, brow_col, hm)
    # nose: the bridge's light side, the shadow side, the nostril, the tip
    nx_ = cx + s + 1.2
    ny0, ny1 = cy + 1.0, cy + 12.5
    nm, nnx, nny, nnz = ellipsoid(nx_ + 0.6, cy + 9.4, 3.4, 4.6, 3.2)
    nose = nm & hm
    c.rgb[nose] = band(lambert(nnx, nny, nnz) - 0.02, skin, cuts=(-0.30, 0.10, 0.45, 0.78))[nose]
    for yy in range(int(ny0), int(cy + 6)):                                              # the bridge: a lit edge and a shaded one, fading into the brow
        t = (yy - ny0) / 5.0
        c.px_on(nx_ - 0.2, yy, tuple(int(v) for v in skin['l']), hm)
        c.px_on(nx_ + 1.8 + 0.4 * t, yy, tuple(int(v) for v in skin['d']), hm)
    for dx in (-1.6, 1.6):
        c.px_on(nx_ + dx + 0.6, ny1 + 0.4, tuple(int(v) for v in skin['dd']), hm)
    c.px_on(nx_ + 0.2, ny1 - 0.6, tuple(int(v) for v in skin['ll']), hm)
    c.px_on(nx_ + 0.9, ny1 + 1.4, tuple(int(v) for v in skin['d']), hm)
    # mouth
    my = cy + 17.4
    mx = cx + s + 1.0
    lips = hexrgb(look['lips'])
    lips_d = mix(lips, (30, 10, 20), 0.45)
    lips_l = mix(lips, (255, 230, 220), 0.35)
    open_ = {'calm': 0.0, 'worry': 0.4, 'pain': 1.4, 'slack': 2.2, 'out': 3.0}[mood]
    half = 6.6
    for i in range(int(half * 2) + 1):
        t = (i - half) / half
        xx = mx + t * half
        sag = {'calm': 0.0, 'worry': 0.4, 'pain': 1.0, 'slack': 0.4, 'out': 0.2}[mood] * (t * t)
        yy = my - 0.6 * (1 - t * t) * (1.0 if mood == 'calm' else 0.2) + sag
        c.px_on(xx, yy, lips_d, hm)
        if open_ > 0.8 and abs(t) < 0.75:
            for d in range(1, int(open_) + 1):
                c.px_on(xx, yy + d, (74, 26, 34), hm)
            if open_ > 1.8 and abs(t) < 0.45:
                c.px_on(xx, yy + 1, (232, 224, 208), hm)
        c.px_on(xx, yy + open_ * (1.0 - t * t) * 0.9 + 1.0, lips, hm)
        if abs(t) < 0.5:
            c.px_on(xx, yy - 1.0, lips, hm)
            c.px_on(xx - 0.5, yy + open_ * 0.9 + 1.0, lips_l, hm)
        c.px_on(xx, yy + open_ + 2.2, tuple(int(v) for v in skin['d']), hm) if abs(t) < 0.35 else None
    if look.get('stubble'):
        for _ in range(70):
            x, y = cx + rng.uniform(-13, 14) + s * 0.5, cy + rng.uniform(10, 25)
            if hm[int(y), int(x)] if 0 <= int(y) < H and 0 <= int(x) < W else False:
                c.px(x, y, tuple(int(v) for v in mix(tuple(int(q) for q in skin['d']), tuple(int(q) for q in hair_t['dd']), 0.5)))
    if look.get('blush') and stage <= 2:
        bl = hexrgb(look['blush'])
        for dx, dy in ((-9, 7), (-8, 8), (-10, 8), (-9, 9), (10, 7), (9, 8), (11, 8)):
            c.px_on(cx + s + dx, cy + dy, mix(tuple(int(v) for v in skin['m']), bl, 0.45), hm)
    # a worried forehead
    if stage >= 2:
        for k in range(2 if stage < 4 else 3):
            yy = cy - 14 - k * 1.6
            for xx in range(int(cx - 5 + s), int(cx + 8 + s)):
                c.px_on(xx, yy + (0.5 if (xx % 3 == 0) else 0.0), tuple(int(v) for v in skin['d']), hm)


# -------------------------------------------------------------------------------------------------------------------------------------------------
def _hair(c, who, p, look, hair_t, hair_lt, skin, hm, cx, cy, rng, stage):
    st = look['hair_style']
    d = tuple(int(v) for v in hair_t['d'])
    m_ = tuple(int(v) for v in hair_t['m'])
    l_ = tuple(int(v) for v in hair_t['l'])
    dd = tuple(int(v) for v in hair_t['dd'])
    ll = tuple(int(v) for v in hair_lt)
    # the hair volume is a bigger ellipsoid over the skull; the hairline is a curve across the forehead
    vol_m, vnx, vny, vnz = ellipsoid(cx - 1.0, cy - 4.0, 25.0, 30.0, 23.0)
    hairline = cy - 13.5 + 7.0 * ((XX - cx) / 22.0) ** 2
    sweep = (XX - cx) * 0.22                                                      # the fringe falls to the right
    top = vol_m & (YY < hairline + (sweep if st in ('mop', 'lob') else 0.0))
    if st == 'crop':
        top = vol_m & (YY < cy - 17.0 + 11.0 * np.clip(np.abs(XX - (cx - 1.0)) / 21.0, 0, 1) ** 2.2) & (YY > cy - 32)
    # side panels (hair at the temples and over the ear's top)
    side = vol_m & ~hm_expand(hm, 0) & (YY < cy + 4) & (XX < cx - 14) if st != 'crop' else vol_m & (XX < cx - 17) & (YY < cy - 3) & (YY > cy - 18)
    mass = top | side
    if st in ('lob', 'long'):
        # long hair: a rounded bundle down the near side, over the shoulder (the far side is painted behind the head: _hair_back)
        yend = 112.0 if st == 'long' else 100.0
        nm, nnx, nny, nnz = ellipsoid(cx - 22.0, (cy - 8.0 + yend) / 2.0, 10.0, (yend - (cy - 8.0)) / 2.0, 8.0)
        near = nm
        mass = mass | near
    mask = mass & ~(hm & (YY >= hairline + (sweep if st in ('mop', 'lob') else 0.0)) & (st != 'crop'))
    if st == 'crop':
        mask = mass
    # the shading: a lit cap
    cuts = (-0.20, 0.25, 0.62, 0.92) if st == 'crop' else (-0.35, 0.05, 0.42, 0.78)
    arr = band(lambert(vnx, vny, vnz) + 0.05, hair_t, cuts=cuts)
    if st in ('lob', 'long'):
        # the curtain's own shading: a gradient across its width, lit on the outer edge, deep where it tucks behind
        curtain = band(lambert(nnx, nny, nnz) + 0.08 * np.sin(YY * 0.5 + XX * 0.2), hair_t, cuts=(-0.35, 0.05, 0.42, 0.78))
        sel = near & (YY > cy - 8)
        arr = np.where(sel[..., None], curtain, arr)
    c.paint_arr(mask, arr)
    # strands: long curved lines along the flow, lighter and darker, so it reads as hair and not a helmet
    n_strands = 70 if st != 'crop' else 90
    for i in range(n_strands):
        if st == 'crop':
            x0, y0 = cx + rng.uniform(-18, 14), cy - rng.uniform(16, 30)
            ln = rng.uniform(2.0, 4.0)
            ang = math.atan2(y0 - (cy - 4), x0 - cx) + rng.uniform(-0.3, 0.3)
            pts = [(x0, y0), (x0 + ln * math.cos(ang), y0 + ln * math.sin(ang))]
        else:
            x0, y0 = cx + rng.uniform(-22, 18), cy - rng.uniform(14, 31)
            ang = math.atan2(0.9, 0.5 + (x0 - cx) * 0.06) + rng.uniform(-0.25, 0.25)
            if st in ('lob', 'long') and x0 < cx - 12:
                ang = math.pi * 0.5 + rng.uniform(-0.15, 0.15)
            ln = rng.uniform(6.0, 13.0)
            pts = [(x0, y0), (x0 + ln * math.cos(ang) * 0.5, y0 + ln * math.sin(ang) * 0.5), (x0 + ln * math.cos(ang), y0 + ln * math.sin(ang) + 1.5)]
        col = ll if rng.random() < 0.46 else (d if rng.random() < 0.14 else l_)
        for a, b in zip(pts, pts[1:]):
            c.line(a, b, col, onto=mask)
    if st in ('lob', 'long'):
        for i in range(34):                                                       # strands down the curtain
            x0 = cx - 30 + rng.uniform(0, 15)
            y0 = cy + rng.uniform(-6, 40)
            col = ll if rng.random() < 0.42 else (d if rng.random() < 0.12 else l_)
            c.line((x0, y0), (x0 - rng.uniform(0, 2.0), y0 + rng.uniform(8, 18)), col, onto=mask)
    # the fringe: a hard bright lock across the brow, a parting
    if st in ('mop', 'lob'):
        c.line((cx - 8, cy - 22), (cx + 6, cy - 18), l_, onto=mask)
        c.line((cx + 7, cy - 17), (cx + 17, cy - 11.5), dd, onto=mask)
    if st == 'long':
        c.line((cx - 2, cy - 30), (cx - 3, cy - 18), tuple(int(v) for v in skin['d']), onto=mask)       # the centre parting, a line of scalp
    # the head's own hair-side shadow on the forehead
    forehead = hm & (YY > hairline + (sweep if st in ('mop', 'lob') else 0.0)) & (YY < hairline + 3.2 + (sweep if st in ('mop', 'lob') else 0.0))
    for y, x in zip(*np.nonzero(forehead)):
        c.rgb[y, x] = skin['d']
    if stage >= 4:                                                                # matted: two loose strands across the forehead
        for i in range(2):
            x0, y0 = cx + rng.uniform(-4, 12), cy - rng.uniform(10, 13)
            c.line((x0, y0), (x0 + rng.uniform(-2, 3), y0 + rng.uniform(4, 8)), d, onto=hm)


def hm_expand(hm, n):
    return hm


def _hair_back(c, look, hair_t, hair_lt, cx, cy, rng):
    """The hair behind the head, on the far side: a bundle that shows past the cheek and falls behind the neck."""
    yend = 108.0 if look['hair_style'] == 'long' else 98.0
    m, nx, ny, nz = ellipsoid(cx + 24.0, (cy - 14.0 + yend) / 2.0, 8.5, (yend - (cy - 14.0)) / 2.0, 7.0)
    arr = band(lambert(nx, ny, nz) - 0.25, hair_t, cuts=(-0.35, 0.05, 0.42, 0.78))
    c.paint_arr(m, arr)
    for i in range(18):
        x0 = cx + 17 + rng.uniform(0, 14)
        y0 = cy + rng.uniform(-8, 30)
        col = tuple(int(v) for v in hair_lt) if rng.random() < 0.25 else tuple(int(v) for v in hair_t['l'])
        c.line((x0, y0), (x0 + rng.uniform(-1, 1), y0 + rng.uniform(6, 16)), col, onto=m)


# -------------------------------------------------------------------------------------------------------------------------------------------------
def _clothes(c, who, p, look, coat, skin, shoulders, rng, stage):
    kind = look['cloth']
    cx = CX
    if kind == 'teal':                                                            # a crew-neck jumper over a grey tee, the ribbed collar
        tee = tone_set(p.get('open', 'b8bcc0'))
        collar = (YY > 78) & (YY < 96) & (np.abs(XX - (cx + 1.0)) < 15) & (((XX - (cx + 1.0)) / 15.0) ** 2 + ((YY - 76) / 21.0) ** 2 < 1.0) & shoulders
        c.rgb[collar] = tee['m']
        inner = collar & (((XX - (cx + 1.0)) / 11.5) ** 2 + ((YY - 76) / 15.0) ** 2 < 1.0)
        c.rgb[inner] = tee['d']
        for k in range(8):                                                        # the rib: short lines round the neck
            yy = 77 + k * 2.4
            x0 = (cx + 1.0) - 14.5 * math.sqrt(max(0.0, 1.0 - ((yy - 76) / 21.0) ** 2))
            c.line((x0, yy), (x0 + 3.6, yy + 1.0), coat['dd'], onto=shoulders & ~inner)
            x1 = (cx + 1.0) + 14.5 * math.sqrt(max(0.0, 1.0 - ((yy - 76) / 21.0) ** 2))
            c.line((x1 - 3.6, yy + 1.0), (x1, yy), coat['dd'], onto=shoulders & ~inner)
        for (x0, y0, x1, y1, col) in ((22, 98, 30, 116, 'd'), (66, 96, 60, 116, 'd'), (36, 104, 40, 116, 'l'), (50, 101, 52, 116, 'l')):   # a few soft folds of knit
            c.line((x0, y0), (x1, y1), coat[col], onto=shoulders)
    elif kind == 'coral':                                                         # a zip-up with a white yoke and a high collar
        white = tone_set('f4f0e8')
        yoke = shoulders & (YY < 104) & (YY > 84 + 0.18 * np.abs(XX - cx))
        c.rgb[yoke & (YY < 100 - 0.07 * np.abs(XX - cx))] = white['m']
        for xx in range(0, W):
            for yy in range(80, 106):
                pass
        yoke2 = shoulders & (YY > 98) & (YY < 102.5) & (np.abs(XX - cx) > 8)
        c.rgb[yoke2] = white['l']
        c.line((cx + 7, 86), (cx + 12, 116), white['ll'], onto=shoulders, w=0.6)         # the zip, the teeth a dotted dark line
        for k in range(0, 30, 2):
            c.px(cx + 7.3 + k * 0.18, 88 + k, coat['dd'])
        col = (YY > 80) & (YY < 94) & (np.abs(XX - (cx + 1.0)) < 11 - (YY - 80) * 0.45) & shoulders          # the collar's inside: the white top
        c.rgb[col] = white['m']
        c.rgb[col & (XX > cx + 3)] = white['d']
        c.line((cx - 12, 84), (cx - 7, 92), coat['ll'], onto=shoulders)
        c.line((cx + 13, 84), (cx + 8, 92), coat['l'], onto=shoulders)
        for k in range(4):
            c.line((18 + k * 4, 104 + k * 3), (28 + k * 4, 112 + k * 2), coat['d'], onto=shoulders)
    elif kind == 'overalls':                                                      # bare shoulders, navy straps and bib with brass buttons and a name patch
        bare = shoulders
        sk = skin
        c.rgb[bare] = band(lambert(*c.snorm) - 0.06, sk, cuts=(-0.32, 0.08, 0.46, 0.80))[bare]
        tee = tone_set('a8a498')
        scoop = ((XX - (cx + 1.0)) / 12.0) ** 2 + ((YY - 78.0) / 11.0) ** 2 < 1.0
        tee_m = shoulders & (np.abs(XX - (cx + 1.0)) < 27) & (YY > 84) & (YY < 100) & ~scoop
        c.rgb[tee_m] = band(lambert(*c.snorm) - 0.04, tee, cuts=(-0.32, 0.08, 0.46, 0.80))[tee_m]
        bib = shoulders & (XX > 34) & (XX < 82) & (YY > 90)
        c.rgb[bib] = coat['m']
        c.rgb[bib & (XX > 62)] = coat['d']
        for sx, lean in ((38, 1.0), (72, -1.0)):                                   # the straps
            for yy in range(76, 117):
                xx = sx + (yy - 76) * 0.2 * lean
                for dx in range(-4, 5):
                    xi = int(round(xx + dx))
                    if 0 <= xi < W and shoulders[yy, xi]:
                        c.rgb[yy, xi] = coat['m'] if dx > -3 else coat['l']
            c.line((sx + 0.2 * (92 - 76) * lean + 0, 92), (sx + 0.2 * (92 - 76) * lean + 0, 92), coat['dd'])
        for (bx, by) in ((41, 96), (69, 96)):                                      # brass buttons
            brass = tone_set('c8a040')
            c.rgb[int(by - 1):int(by + 2), int(bx - 1):int(bx + 2)] = brass['m']
            c.px(bx - 1, by - 1, brass['ll'])
        c.rgb[100:109, 50:61] = tone_set('f0ece0')['m']                              # the name patch, with a line of dark where the name is
        c.rgb[100:109, 50:61][np.array([0, 8])] = tone_set('f0ece0')['d']
        c.rgb[103:105, 52:59] = coat['dd']
        c.rgb[106:107, 52:57] = coat['d']
        c.line((34, 90), (82, 90), coat['ll'], onto=shoulders)
    elif kind == 'cardigan':                                                      # a mustard cardigan open over a magenta top; a lanyard
        top = tone_set(p.get('open', 'c83a6a'))
        v = shoulders & (YY > 84) & (YY < 120) & (np.abs(XX - (cx + 4)) < 7 + (YY - 84) * 0.32)
        c.rgb[v] = top['m']
        c.rgb[v & (XX > cx + 6)] = top['d']
        scoop = shoulders & (YY > 80) & (YY < 90) & (((XX - (cx + 1.0)) / 11.0) ** 2 + ((YY - 80) / 8.0) ** 2 < 1.0)
        c.rgb[scoop] = skin['d']
        for k in range(14):                                                       # the cardigan's rib
            x = 8 + k * 6
            c.line((x, 98 + (x % 5)), (x - 1, 116), coat['d'], onto=shoulders & ~v)
        c.line((cx - 5, 86), (cx - 12, 116), coat['ll'], onto=shoulders)             # the open edge, lit
        c.line((cx + 12, 86), (cx + 18, 116), coat['dd'], onto=shoulders)
        c.line((cx - 3, 84), (cx + 3, 116), tone_set('f0f0f0')['d'], onto=shoulders, w=0.5)  # the lanyard's cord
        icx = int(cx)
        c.rgb[102:111, icx - 6:icx + 2] = tone_set('f0f0f0')['m']                       # the card
        c.rgb[104:106, icx - 4:icx] = coat['dd']
        c.rgb[107:108, icx - 5:icx - 1] = coat['d']
    # buttons / seams catch light
    c.line((6, 104), (14, 98), coat['l'], onto=shoulders)


# -------------------------------------------------------------------------------------------------------------------------------------------------
def _wounds(c, who, p, look, skin, hm, shoulders, cx, cy, stage, rng, hair_t):
    if stage == 1:
        return
    blood = np.array((150, 22, 34), dtype=np.uint8)
    blood_d = np.array((88, 10, 24), dtype=np.uint8)
    blood_l = np.array((214, 56, 62), dtype=np.uint8)
    s = YAW
    bound = hm | shoulders
    # --- 2: a scratch across the cheek, a graze on the jaw, a bead of sweat
    if stage >= 2:
        c.line((cx + 9 + s, cy + 6), (cx + 15 + s, cy + 13), blood, onto=hm)
        c.line((cx + 10 + s, cy + 6), (cx + 16 + s, cy + 13), blood_d, onto=hm)
        c.px_on(cx + 13 + s, cy + 9, blood_l, hm)
        for (x, y) in ((cx - 12, cy - 12), (cx + 17, cy - 8)):
            c.px_on(x, y, (230, 236, 244), hm)
            c.px_on(x, y + 1, (190, 200, 214), hm)
    # --- 3: a bruise round the near eye, a split lip with blood, dirt, a cut on the brow
    if stage >= 3:
        bx, by = cx + s - 8.6, cy - 1.5
        for yy in range(int(by - 6), int(by + 9)):
            for xx in range(int(bx - 9), int(bx + 9)):
                dd_ = math.hypot((xx + 0.5 - bx) / 9.0, (yy + 0.5 - (by + 2)) / 7.0)
                if dd_ <= 1.0 and hm[yy, xx]:
                    t = dd_
                    col = (96, 52, 112) if t < 0.55 else ((140, 84, 128) if t < 0.8 else (176, 140, 90))
                    base = c.rgb[yy, xx].astype(int)
                    if abs(yy + 0.5 - by) > 3.2 or abs(xx + 0.5 - bx) > 5.0:
                        c.rgb[yy, xx] = (np.array(col) * 0.55 + base * 0.45).astype(np.uint8)
        mx, my = cx + s + 1.0, cy + 17.4
        c.line((mx + 1, my + 1), (mx + 4, my + 6), blood, onto=hm)                     # the split in the lip and the trickle off the chin
        c.line((mx + 4, my + 6), (mx + 5, my + 12), blood_d, onto=hm)
        c.px_on(mx + 2, my + 1, blood_l, hm)
        c.line((cx - 5 + s, cy - 15), (cx + 1 + s, cy - 14), blood, onto=hm)           # a cut above the brow
        for _ in range(26):
            x, y = cx + rng.uniform(-14, 16), cy + rng.uniform(-8, 26)
            c.px_on(x, y, tuple(int(v) for v in mix(tuple(int(q) for q in skin['d']), (60, 48, 40), 0.5)), hm)
    # --- 4: the bandage on the head, a blood trail from it down the temple; the colour is gone from the face
    if stage >= 4:
        gauze = tone_set('ece4d2')
        band_m = hm & (YY > cy - 21) & (YY < cy - 11 + 0.18 * (XX - cx))
        wrap_arr = np.zeros(c.rgb.shape, dtype=np.uint8)
        for y, x in zip(*np.nonzero(band_m)):
            k = (x * 0.55 + y * 1.1) % 9.0                                                 # diagonal turns of gauze: lit, mid, a shadowed overlap
            c.rgb[y, x] = gauze['ll'] if k < 1.6 else (gauze['l'] if k < 5.4 else (gauze['m'] if k < 7.6 else gauze['d']))
        top_edge = band_m & ~np.roll(band_m, 1, 0)
        bot_edge = band_m & ~np.roll(band_m, -1, 0)
        c.rgb[top_edge] = gauze['m']
        c.rgb[bot_edge] = gauze['dd']
        for _ in range(9):                                                                # frayed ends
            x, y = cx + rng.uniform(-5, 10), cy - 20 + rng.uniform(0, 4)
            c.line((x, y), (x + rng.uniform(-1, 3), y - rng.uniform(1, 4)), gauze['m'], onto=(YY < cy + 30) & (YY > 0))
        spot = (cx + 4 + s * 0.5, cy - 16)
        for yy in range(int(spot[1] - 4), int(spot[1] + 4)):
            for xx in range(int(spot[0] - 5), int(spot[0] + 5)):
                if math.hypot((xx - spot[0]) / 5.0, (yy - spot[1]) / 3.4) < 1.0 and band_m[yy, xx]:
                    c.rgb[yy, xx] = blood
        c.line((cx + 10 + s * 0.5, cy - 11), (cx + 13 + s * 0.5, cy + 12), blood, onto=hm, w=0.5)
        c.line((cx + 10.5 + s * 0.5, cy - 11), (cx + 13.5 + s * 0.5, cy + 12), blood_d, onto=hm, w=0.3)
    # --- 5: the bandage soaked, a shut swollen eye, blood across the mouth and chest, the clothes spotted
    if stage >= 5:
        band_m = hm & (YY > cy - 21) & (YY < cy - 11 + 0.18 * (XX - cx))
        for y, x in zip(*np.nonzero(band_m)):                                              # the soak: a blot spreading from one side, ragged at its edge
            dist = math.hypot((x - (cx + 7.0)) / 13.0, (y - (cy - 16.0)) / 5.0) + 0.25 * math.sin(x * 0.9 + y * 0.7)
            if dist < 1.0:
                c.rgb[y, x] = blood if dist < 0.65 else blood_d
        bx, by = cx + s - 8.6, cy - 1.5                                                    # the near eye swollen shut
        for yy in range(int(by - 5), int(by + 7)):
            for xx in range(int(bx - 7), int(bx + 8)):
                u = (xx + 0.5 - bx) / 7.0
                v = (yy + 0.5 - by) / 5.2
                if u * u + v * v <= 1.0 and hm[yy, xx]:
                    c.rgb[yy, xx] = (112, 58, 96) if v < 0.2 else (136, 76, 108)
        c.line((bx - 5, by + 0.5), (bx + 5, by + 0.5), (36, 14, 28), onto=hm)
        c.line((bx - 4, by - 1.2), (bx + 4, by - 1.4), (150, 90, 124), onto=hm)
        mx, my = cx + s + 1.0, cy + 17.4
        for yy in range(int(my - 1), int(my + 9)):                                           # blood round the mouth and down the chin, a pool at the lip
            for xx in range(int(mx - 7), int(mx + 8)):
                if math.hypot((xx - mx) / 6.5, (yy - (my + 2.5)) / 4.0) < 1.0 and hm[yy, xx]:
                    c.rgb[yy, xx] = blood if (xx + yy) % 5 else blood_l
        for k, dx_ in enumerate((-3, 2, 6)):
            y1 = my + 9 + 5 * k
            c.line((mx + dx_, my + 4), (mx + dx_, y1), blood_d, onto=hm | shoulders)
            c.px_on(mx + dx_, y1 + 1, blood, hm | shoulders)
        for _ in range(34):                                                                # a little spatter on the clothes
            x, y = rng.uniform(8, 86), rng.uniform(90, 116)
            if shoulders[int(y), int(x)]:
                c.px_on(x, y, blood if rng.random() < 0.6 else blood_d, shoulders)
                if rng.random() < 0.3:
                    c.px_on(x + 1, y, blood_d, shoulders)
    # --- 6: ashen, eyes shut, slack, and the blood everywhere
    if stage >= 6:
        for k in range(4):                                                                 # runs of blood from the soaked bandage, ending in a drop
            x0 = cx - 8 + k * 7.5 + rng.uniform(-1, 1)
            y1 = cy + rng.uniform(8, 26)
            c.line((x0, cy - 12), (x0 + rng.uniform(-1, 1), y1), blood if k % 2 else blood_d, onto=hm | shoulders, w=0.5)
            c.px_on(x0, y1 + 1, blood_d, hm | shoulders)
        for _ in range(60):
            x, y = rng.uniform(4, 90), rng.uniform(84, 116)
            if shoulders[int(y), int(x)]:
                c.px_on(x, y, blood if rng.random() < 0.6 else blood_d, shoulders)
        # the edges go dark: the light is going
        vign = np.clip(((XX - CX) / 48.0) ** 2 + ((YY - 58.0) / 64.0) ** 2 - 0.55, 0.0, 1.0)
        c.rgb = (c.rgb.astype(np.float32) * (1.0 - 0.55 * vign[..., None])).astype(np.uint8)


# -------------------------------------------------------------------------------------------------------------------------------------------------
def render(who, stage):
    c = draw_person(who, stage)
    im = c.image().resize((W * UP, H * UP), Image.NEAREST)
    return im.crop((0, 0, 281, 351))


def write_all():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(REF, exist_ok=True)
    for who, cid in IDS.items():
        for n, st in enumerate(STAGES, 1):
            render(who, n).save(os.path.join(OUT, '%s - %s.png' % (cid, st)))
    sheet = Image.new('RGBA', (281 * 6, 351 * 4), (58, 58, 68, 255))
    for r, who in enumerate(IDS):
        for n in range(1, 7):
            sheet.alpha_composite(render(who, n), ((n - 1) * 281, r * 351))
    sheet.resize((sheet.width // 3, sheet.height // 3), Image.LANCZOS).save(os.path.join(REF, 'portraits_sheet.png'))
    print('wrote portraits to', OUT)


if __name__ == '__main__':
    write_all()
