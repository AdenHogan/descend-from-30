#!/usr/bin/env python3
"""THE HUD PORTRAITS (owner 2026-11-22: "replace the HUD portraits to match the new characters, but remember they need to be more detailed"; then, with a sheet of Viewtiful Joe art: "try something in the viewtiful joe art style… context is essential").

STYLE = VIEWTIFUL JOE: thick black ink outlines (two pixels round the outside, one inside wherever a shape sits in front of another), flat saturated colour with ONE hard shade shape and a crisp light, sharp angular design (pointed chins, spiky tapering hair locks that end in points, narrow bold eyes, heavy angled brows), no gradients, no dither.

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
OUTLINE = (14, 8, 20)
LIGHT = np.array([-0.46, -0.56, 0.69])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
OUT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'Health_Bar'))
REF = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'art_reference', 'portraits'))
STAGES = ['1 - Healthy', '2 - Hurt', '3 - Injured', '4 - Wounded', '5 - Severely Wounded', '6 - Dying']
IDS = {'joe': 'blond_man', 'vivianne': 'blond_woman', 'alex': 'bald_man', 'amina': 'dark_woman'}

YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)
# a fixed screen of noise that nudges where one tone ends and the next begins, so the bands are not ruler-straight (the old portraits' painted edge)
_rng = np.random.RandomState(7)
DITHER = np.zeros((H, W), dtype=np.float32)       # CEL SHADING (owner: the smoothly shaded busts "look like bizarre claymation"): no dithered edges, hard flat tones


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def tone_set(hexcol, pallor=0.0, lo=0.0, hi=0.0):
    """VIEWTIFUL JOE flat colour: a base, a warm light, a hot catch-light, and a SHADE that is darker AND shifted toward violet (the comic-book shadow), plus a near-black ink tone."""
    base = hexrgb(hexcol)
    if pallor > 0.0:
        base = mix(base, (150, 156, 140), pallor)
    t = {
        'dd': mix(tuple(int(v * 0.34) for v in base), (12, 6, 22), 0.55),
        'd': mix(tuple(int(v * 0.66) for v in base), (84, 26, 60), 0.26),
        'm': base,
        'l': mix(base, (255, 244, 210), 0.20),
        'll': mix(base, (255, 255, 255), 0.55),
    }
    return {k: np.array(v, dtype=np.uint8) for k, v in t.items()}


class Canvas:
    def __init__(self):
        self.rgb = np.zeros((H, W, 3), dtype=np.uint8)
        self.alpha = np.zeros((H, W), dtype=bool)
        self.who = np.zeros((H, W), dtype=np.int32)        # which layer last painted a pixel (for the outline's sake)
        self.layer = 0

    def paint(self, mask, colour_fn):
        ys, xs = np.nonzero(mask)
        for y, x in zip(ys, xs):
            self.rgb[y, x] = colour_fn(y, x)
        self.alpha |= mask

    def paint_arr(self, mask, arr):
        self.rgb[mask] = arr[mask]
        self.alpha |= mask
        self.layer += 1
        self.who[mask] = self.layer                         # paint order: a line is inked where one shape sits in front of another

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
            # the inner ink: where a shape sits in front of another, its edge is drawn in a deep shade of its own colour
            ww = self.who
            inner = np.zeros(self.alpha.shape, dtype=bool)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb = np.roll(np.roll(ww, dy, 0), dx, 1)
                inner |= self.alpha & (nb > 0) & (ww > nb)
            inner[0, :] = inner[-1, :] = False
            ink = np.array(OUTLINE, dtype=np.float32)
            im[inner, :3] = (im[inner, :3].astype(np.float32) * 0.22 + ink * 0.78).astype(np.uint8)
            a = self.alpha
            ring = np.zeros_like(a)
            cur = a.copy()
            for _ in range(2):                                      # a TWO-pixel ink line round the outside (the comic-book contour)
                edge = np.zeros_like(a)
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    sh = np.roll(np.roll(cur, dy, 0), dx, 1)
                    edge |= (~cur) & sh
                edge[0, :] = edge[-1, :] = False
                edge[:, 0] = edge[:, -1] = False
                ring |= edge
                cur = cur | edge
            im[ring, :3] = OUTLINE
            im[ring, 3] = 255
        return Image.fromarray(im, 'RGBA')


def lambert(nx, ny, nz):
    return nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]


CEL_CUTS = (0.06, 0.74)


def band(l, tones, cuts=None):
    """CEL: light -> one of THREE flat tones (shade / base / lit), each edge hard. (`cuts` is kept so the callers still read; the cel rule is one for everything.)"""
    l = l + DITHER
    idx = np.zeros(l.shape, dtype=np.int32)
    for c in CEL_CUTS:
        idx += (l > c)
    order = ['d', 'm', 'l']
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
    # FACE STRUCTURE is each person's own, drawn ANGULAR (the sharp jaw, the narrow bold eye, the heavy angled brow): head size, jaw (how steeply it falls to the chin and how far),
    # eyes, brows, nose, mouth.
    'joe': dict(gender='m', hair_style='joe', hair_light='9a7650', eye='5a7a96', lips='b87068', stubble=True, cloth='teal',
                head=(20.5, 26.5), jaw=0.34, jaw_pow=1.0, ear=1.1, eyes=dict(w=(8.4, 6.8), h=2.2, gap=8.9, tilt=-0.4, iris=2.3, drop=0.0, pt=1.5), brow=dict(th=3, arch=1.6, tilt=0.5, up=0.0),
                nose=dict(len=13.5, w=3.4, nostril=1.6, bridge=1.0), mouth=dict(w=5.4, thick=1.0, y=18.4), cheek=0.0),
    'vivianne': dict(gender='f', hair_style='viv', hair_light='fff2b0', eye='4a86b8', lips='d2607a', blush='f4a8a8', lash=True, cloth='coral',
                     head=(19.0, 25.0), jaw=0.44, jaw_pow=1.0, ear=0.8, eyes=dict(w=(9.8, 8.0), h=3.4, gap=8.0, tilt=0.8, iris=3.0, drop=0.0, pt=1.8), brow=dict(th=2, arch=2.0, tilt=-0.2, up=1.0),
                     nose=dict(len=10.8, w=2.4, nostril=1.1, bridge=0.5), mouth=dict(w=5.0, thick=1.6, y=17.4), cheek=0.0),
    'alex': dict(gender='m', hair_style='alex', hair_light='5a4856', eye='2a1a14', lips='7a3c34', cloth='overalls',
                 head=(22.0, 26.0), jaw=0.26, jaw_pow=1.0, ear=0.9, eyes=dict(w=(8.0, 6.6), h=2.5, gap=9.6, tilt=-0.5, iris=2.5, drop=0.3, pt=1.5), brow=dict(th=3, arch=0.8, tilt=-0.6, up=-0.3),
                 nose=dict(len=13.0, w=4.8, nostril=2.2, bridge=1.3), mouth=dict(w=6.4, thick=1.8, y=18.4), cheek=0.0),
    'amina': dict(gender='f', hair_style='ami', hair_light='6a6488', eye='2a1a14', lips='a04c4c', lash=True, earring='f0d060', cloth='cardigan',
                  head=(19.6, 26.5), jaw=0.42, jaw_pow=1.0, ear=0.9, eyes=dict(w=(10.0, 8.2), h=3.2, gap=8.6, tilt=1.4, iris=2.9, drop=0.0, pt=1.8), brow=dict(th=2, arch=2.2, tilt=-0.3, up=1.2),
                  nose=dict(len=12.0, w=2.8, nostril=1.3, bridge=0.7), mouth=dict(w=6.0, thick=1.5, y=17.8), cheek=0.0),
}


def head_masks(look):
    """The head: a rounded cranium and an ANGULAR jaw — straight lines falling to a small flat chin."""
    cx, cy = CX - 1.0, HY
    rx, ry = look['head']
    jy = cy + 5.0
    wj = rx * math.sqrt(max(0.0, 1.0 - ((jy - cy) / ry) ** 2))
    m = np.zeros((H, W), dtype=bool)
    for y in range(H):
        yy = y + 0.5
        if yy < cy - ry or yy > cy + ry:
            continue
        if yy <= jy:
            w = rx * math.sqrt(max(0.0, 1.0 - ((yy - cy) / ry) ** 2))
        else:
            t = (yy - jy) / (cy + ry - jy)
            w = max(2.6, wj * (1.0 - look['jaw'] * 2.1 * t ** look['jaw_pow']))
        m[y] = np.abs(XX[y] + 0.5 - cx) <= w
    z = np.zeros((H, W), dtype=np.float32)
    return m, z, z, z


def lock(pts, w0):
    """A TAPERING lock of hair: a ribbon along the path `pts` that is `w0` wide at the root and comes to a POINT at the tip.
    -> (mask, light) where `light` is how far a pixel sits toward the light (upper left) from the ribbon's own centre line, in half-widths."""
    best = np.full((H, W), 1e9, dtype=np.float32)
    px_ = np.zeros((H, W), dtype=np.float32)
    py_ = np.zeros((H, W), dtype=np.float32)
    tt_ = np.zeros((H, W), dtype=np.float32)
    segs = list(zip(pts, pts[1:]))
    lens = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in segs]
    tot = sum(lens)
    acc = 0.0
    for (a, b), L in zip(segs, lens):
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = np.clip(((XX + 0.5 - a[0]) * dx + (YY + 0.5 - a[1]) * dy) / (L * L), 0.0, 1.0)
        qx, qy = a[0] + t * dx, a[1] + t * dy
        d = np.hypot(XX + 0.5 - qx, YY + 0.5 - qy)
        better = d < best
        best = np.where(better, d, best)
        px_ = np.where(better, qx, px_)
        py_ = np.where(better, qy, py_)
        tt_ = np.where(better, (acc + t * L) / tot, tt_)
        acc += L
    hw = 0.5 * w0 * np.clip(1.0 - tt_, 0.0, 1.0) ** 0.8
    m = (best <= hw) & (tt_ < 0.999)
    light = ((XX + 0.5 - px_) * -0.6 + (YY + 0.5 - py_) * -0.8) / np.maximum(hw, 0.5)
    return m, light


def paint_lock(c, pts, w0, tones, shine=None):
    m, light = lock(pts, w0)
    arr = np.zeros((H, W, 3), dtype=np.uint8)
    arr[:] = tones['m']
    arr[light < -0.25] = tones['d']                                 # the shade side: hard
    arr[light > 0.55] = tones['l']                                  # the lit edge
    if shine is not None:
        arr[light > 0.86] = shine
    c.paint_arr(m, arr)
    return m


HAIR = {
    # lock polylines are written relative to the head's middle (cx, cy); the first number is the root width
    'joe': dict(cap=dict(rx=22.5, ry=27.0, ymax=-11.0, slope=0.10), locks=[
        (((-16, -12), (-24, -24), (-31, -31)), 10), (((-8, -18), (-12, -31), (-15, -40)), 10), (((0, -20), (2, -33), (9, -41)), 10), (((8, -18), (16, -29), (25, -34)), 10),
        (((14, -12), (24, -19), (32, -18)), 9), (((-14, -19), (-3, -11), (11, -8)), 9), (((-4, -21), (8, -14), (19, -11)), 8), (((-19, -8), (-23, 3), (-21, 12)), 7)], back=[]),
    'viv': dict(cap=dict(rx=21.5, ry=27.0, ymax=-12.0, slope=0.10), locks=[
        (((-16, -22), (-9, -11), (-6, 0)), 10), (((-6, -24), (-2, -12), (0, -2)), 9), (((3, -24), (7, -15), (10, -7)), 9), (((11, -21), (16, -13), (18, -5)), 8),
        (((-18, -14), (-30, 10), (-32, 38)), 21), (((-12, -17), (-21, 12), (-20, 44)), 17)], back=[(((17, -12), (28, 10), (31, 34)), 19), (((13, -14), (23, 12), (23, 40)), 15)]),
    'alex': dict(cap=dict(rx=22.5, ry=27.0, ymax=-14.0, slope=0.0), locks=[
        (((-17, -16), (-21, -24), (-24, -30)), 6), (((-10, -22), (-12, -30), (-14, -36)), 6), (((-2, -25), (-2, -33), (0, -38)), 6), (((7, -24), (10, -32), (14, -36)), 6),
        (((14, -19), (20, -26), (25, -29)), 6), (((19, -12), (26, -16), (30, -17)), 5)], back=[]),
    'ami': dict(cap=dict(rx=21.5, ry=27.0, ymax=-13.0, slope=0.0), locks=[
        (((-16, -22), (-12, -12), (-10, -2)), 9), (((-8, -24), (-6, -13), (-4, -2)), 9), (((0, -25), (1, -14), (3, -3)), 9), (((8, -24), (10, -14), (11, -3)), 9),
        (((15, -21), (16, -13), (17, -4)), 8), (((-18, -14), (-30, 14), (-30, 48)), 21), (((-12, -17), (-21, 16), (-18, 46)), 16)], back=[(((18, -12), (29, 14), (30, 46)), 20), (((13, -15), (23, 16), (21, 44)), 15)]),
}


def _hair_back(c, look, hair_t, hair_lt, cx, cy, rng):
    for pts, w0 in HAIR[look['hair_style']]['back']:
        paint_lock(c, [(cx + x, cy + y) for x, y in pts], w0, hair_t)


def _hair(c, who, p, look, hair_t, hair_lt, skin, hm, cx, cy, rng, stage):
    spec = HAIR[look['hair_style']]
    cap = spec['cap']
    u = (XX + 0.5 - (cx - 1.0)) / cap['rx']
    v = (YY + 0.5 - (cy - 4.0)) / cap['ry']
    capm = (u * u + v * v <= 1.0) & (YY < cy + cap['ymax'] + cap['slope'] * (XX - cx) + 4.0 * (np.abs(XX - cx) / cap['rx']) ** 2)
    arr = np.zeros((H, W, 3), dtype=np.uint8)
    arr[:] = hair_t['m']
    arr[((XX - cx) / cap['rx'] > 0.42) | (YY > cy - 12.0)] = hair_t['d']
    arr[(((XX - (cx - 9.0)) / 8.0) ** 2 + ((YY - (cy - 22.0)) / 3.5) ** 2) < 1.0] = hair_t['l']
    c.paint_arr(capm, arr)
    for pts, w0 in spec['locks']:
        paint_lock(c, [(cx + x, cy + y) for x, y in pts], w0, hair_t, shine=np.array(hair_lt, dtype=np.uint8))
    if stage >= 4:                                                                  # matted: a loose lock across the forehead
        paint_lock(c, [(cx + 2, cy - 17), (cx + 8, cy - 10), (cx + 11, cy - 3)], 5, hair_t)


def draw_person(who, stage, seed=1):
    look = LOOK[who]
    p = next(q for q in P.PLAYERS if q['name'] == who)
    rng = random.Random(seed * 131 + stage)
    pallor = (0.0, 0.0, 0.06, 0.16, 0.30, 0.46)[stage - 1]
    skin = tone_set(p['skin'], pallor)
    hair_t = tone_set(p['hair'])
    hair_t['d'] = ((hair_t['d'].astype(np.int32) + hair_t['dd'].astype(np.int32)) // 2).astype(np.uint8)       # comic-book hair: the shade side goes nearly black
    hair_lt = np.array(hexrgb(look['hair_light']), dtype=np.uint8)
    coat = tone_set(p['coat'])
    c = Canvas()
    cx, cy = CX - 1.0, HY

    # ---- the body: broad angled shoulders, a short neck ---------------------------------------------------------------------------------------
    sm, snx, sny, snz = ellipsoid(CX, 134.0, 54.0, 62.0, 40.0)
    shoulders = sm & (YY < H)
    c.snorm = (snx, sny, snz)
    c.paint_arr(shoulders, band(lambert(snx, sny, snz), coat))
    nk = (np.abs(XX + 0.5 - (CX + 1.0)) < 7.6) & (YY > cy + 17) & (YY < 92)
    nxn = np.clip((XX + 0.5 - (CX + 1.0)) / 7.6, -1, 1)
    neck_m = (nk & ~shoulders) | (nk & (YY < 84))
    c.rgb[neck_m] = np.where((nxn > 0.30)[..., None], skin['d'], skin['m'])[neck_m]
    c.alpha |= neck_m
    _clothes(c, who, p, look, coat, skin, shoulders, rng, stage)
    hm0, _a, _b, _c = head_masks(look)
    bot = np.where(hm0.any(axis=0), (YY * hm0).max(axis=0), 0).astype(np.float32)
    depth = YY - bot[None, :]
    c.rgb[nk & (depth >= 0) & (depth < 6.0)] = skin['d']
    _hair_back(c, look, hair_t, hair_lt, cx, cy, rng)

    # ---- the head: flat skin, one hard shade down the far side and under the jaw, one crisp light -------------------------------------------------
    hm, hnx, hny, hnz = head_masks(look)
    ry_h = look['head'][1]
    em, enx, eny, enz = ellipsoid(cx - 19.5, cy + 3.0, 3.6 * look['ear'], 6.2 * look['ear'], 3.0)
    ear_arr = np.zeros((H, W, 3), dtype=np.uint8)
    ear_arr[:] = skin['m']
    ear_arr[(XX > cx - 19.0)] = skin['d']
    c.paint_arr(em & ~hm, ear_arr)
    face_img = np.zeros((H, W, 3), dtype=np.uint8)
    face_img[:] = skin['m']
    far_shade = (XX > cx + 10.0 + 5.0 * ((YY - cy) / ry_h) ** 2)
    jaw_shade = (YY > cy + ry_h - 4.5) & (XX > cx - 2.0)
    face_img[(((XX - (cx - 9.0)) / 6.0) ** 2 + ((YY - (cy - 9.0)) / 3.0) ** 2 < 1.0)] = skin['l']
    face_img[far_shade | jaw_shade] = skin['d']
    c.paint_arr(hm, face_img)
    if look.get('earring'):
        for dy in range(0, 4):
            c.px(cx - 19.5, cy + 9 + dy, hexrgb(look['earring']))
        c.px(cx - 19.5, cy + 13, mix(hexrgb(look['earring']), (255, 255, 255), 0.5))

    _face(c, who, p, look, skin, hm, hnx, hny, hnz, cx, cy, stage, rng, hair_t)
    _hair(c, who, p, look, hair_t, hair_lt, skin, hm, cx, cy, rng, stage)
    _wounds(c, who, p, look, skin, hm, shoulders, cx, cy, stage, rng, hair_t)
    return c


def _t(col):
    return tuple(int(v) for v in col)


def _face(c, who, p, look, skin, hm, hnx, hny, hnz, cx, cy, stage, rng, hair_t):
    """The face in the SPRITES' language, drawn large and cel: big dark eyes with a bold catch-light (no realistic whites), a plain brow stroke, a tiny nose mark, a short mouth.
    What makes one person not another is STRUCTURE (`LOOK`): the head and jaw, the eyes' shape / size / spacing, the brow's weight and arch, the nose, the mouth."""
    s = YAW
    E, B, N, M = look['eyes'], look['brow'], look['nose'], look['mouth']
    ink = _t(hair_t['dd'])
    line = (30, 16, 34)
    sk_d, sk_l, sk_m, sk_dd = _t(skin['d']), _t(skin['l']), _t(skin['m']), _t(skin['dd'])
    eye_col = hexrgb(look['eye'])
    mood = {1: 'calm', 2: 'worry', 3: 'worry', 4: 'pain', 5: 'slack', 6: 'out'}[stage]
    droop = {1: 0.0, 2: 0.0, 3: 0.4, 4: 0.8, 5: 1.4, 6: 2.6}[stage]
    eye_y = cy - 1.5 + E['drop']
    gender_f = look['gender'] == 'f'
    # --- the eyes: a tall dark oval (a rounder, bigger one for the women, a flatter lidded one for Alex), the lower part in the iris colour, two catch-lights
    for k, (ex, wd) in enumerate(((cx + s - E['gap'], E['w'][0]), (cx + s + E['gap'] * 0.92, E['w'][1]))):
        ey = eye_y + (0.5 if k else 0.0)
        outer = -1.0 if k == 0 else 1.0
        hh = max(1.0, E['h'] * 1.55 - 2.0 * min(1.0, droop / 2.6))
        ww = wd * 0.5
        shape = np.zeros((H, W), dtype=bool)
        for yy in range(int(ey - 8), int(ey + 9)):
            for xx in range(int(ex - 8), int(ex + 9)):
                u = (xx + 0.5 - ex) / ww
                lift = E['tilt'] * 1.6 * max(0.0, u * outer)                       # the outer corner rises (or falls) with the person's tilt
                v = (yy + 0.5 - (ey - lift)) / hh
                if abs(u) ** E['pt'] + abs(v) ** E['pt'] <= 1.0 and not (stage == 6 and v < 0.0):
                    shape[yy, xx] = True
        if stage == 6:
            for xx in range(int(ex - ww), int(ex + ww) + 1):                       # shut: a heavy dark lid line and its lash
                c.px(xx, ey + 0.4, line)
                c.px(xx, ey - 0.6, line)
            continue
        c.rgb[shape] = (22, 14, 24)
        lower = shape & (YY > ey + hh * 0.15)
        c.rgb[lower & (((XX + 0.5 - ex) / (ww * 0.78)) ** 2 + ((YY - (ey + hh * 0.5)) / (hh * 0.7)) ** 2 < 1.0)] = eye_col
        top_rows = {}
        for xx in range(int(ex - ww) - 1, int(ex + ww) + 2):
            if 0 <= xx < W:
                ys = np.nonzero(shape[:, xx])[0]
                if len(ys):
                    top_rows[xx] = int(ys.min())
        for xx, ty in top_rows.items():
            c.px(xx, ty, line)                                                     # the lid line: heavy and black (the Viewtiful ink)
            c.px(xx, ty - 1, line)
            if gender_f:
                c.px(xx, ty - 2, line)
        if gender_f and top_rows:
            xo = (min(top_rows) - 1) if k == 0 else (max(top_rows) + 1)
            yo = top_rows[min(top_rows) if k == 0 else max(top_rows)]
            c.px(xo, yo - 1, line)
            c.px(xo + (-1 if k == 0 else 1), yo - 2, line)
        if look['who'] == 'alex' if 'who' in look else False:
            pass
        cxh, cyh = ex - ww * 0.35, ey - hh * 0.35
        for dx_, dy_ in ((0, 0), (1, 0), (0, 1), (1, 1)):                          # the big catch-light, a 2 x 2 block of white
            c.px_on(cxh + dx_, cyh + dy_, (255, 255, 255), shape)
        c.px_on(ex + ww * 0.45, ey + hh * 0.5, (255, 255, 255), shape)             # and the small one low on the other side
        if stage >= 3:                                                              # tired: a hard shadow under the eye, then ill
            col = _t(mix(sk_d, (96, 60, 112), 0.3 * min(1.0, (stage - 2) / 3.0)))
            for xx in range(int(ex - ww), int(ex + ww) + 1):
                c.px_on(xx, ey + hh + 1.4, col, hm)
                if stage >= 4:
                    c.px_on(xx, ey + hh + 2.4, col, hm)
    # --- the brows: one dark stroke of the person's own weight and arch
    tilt = {'calm': 0.0, 'worry': 1.6, 'pain': 2.4, 'slack': 0.6, 'out': 1.0}[mood]
    for k, (ex, wd) in enumerate(((cx + s - E['gap'], E['w'][0] + 1.6), (cx + s + E['gap'] * 0.92, E['w'][1] + 1.4))):
        by = eye_y - 7.0 - B['up'] - (1.2 if mood in ('worry', 'pain') else 0.0) + (0.8 if mood == 'slack' else 0.0)
        for i in range(int(wd) + 1):
            t = i / max(1.0, wd)
            xx = ex - wd / 2.0 + wd * t
            near_inner = (t if k == 0 else 1.0 - t)
            ridge = (1.0 - abs(t - 0.38) / 0.62) if t < 0.38 else (1.0 - abs(t - 0.38) / 0.62)       # an ANGLED brow: a straight rise to a peak and a straight fall
            yy = by - B['arch'] * max(0.0, ridge) * 1.4 - tilt * near_inner * 0.5 + B['tilt'] * (t - 0.5) * (1 if k == 0 else -1)
            th = B['th'] if 0.12 < t < 0.9 else max(1, B['th'] - 1)
            for q in range(th):
                c.px_on(xx, yy + q - th / 2.0 + 0.5, line, hm)
    # --- the nose: a short shaded side and a shadow under the tip, one lit pixel; its size is the person's
    nx_ = cx + s + 1.2
    tip_y = cy - 1.0 + N['len']
    for yy in range(int(cy + 3), int(tip_y - 1)):
        t = (yy - (cy + 3)) / max(1.0, tip_y - 1 - (cy + 3))
        for q in range(int(N['bridge'] + 0.5)):
            c.px_on(nx_ + 1.6 + 1.4 * t + q, yy, sk_d, hm)
    wn = int(N['w'])
    for dx in range(0, wn):
        c.px_on(nx_ + 0.5 + dx - wn / 2.0 + 1.0, tip_y - 0.5, sk_d, hm)                 # the underside of the nose
        c.px_on(nx_ + 0.5 + dx - wn / 2.0 + 1.0, tip_y + 0.5, sk_d, hm) if dx > 0 else None
    c.px_on(nx_ + 0.2, tip_y - 1.5, sk_l, hm)
    for dx in (-N['nostril'] * 0.5, N['nostril'] * 0.5):
        c.px_on(nx_ + 0.6 + dx, tip_y, sk_dd, hm)
    # --- the mouth: a short dark line, a flat lower lip, corners
    my = cy + M['y']
    mx = cx + s + 1.0
    lips = hexrgb(look['lips'])
    lips_d = _t(mix(lips, (36, 12, 24), 0.55))
    open_ = {'calm': 0.0, 'worry': 0.4, 'pain': 1.4, 'slack': 2.2, 'out': 3.0}[mood]
    half = M['w']
    th = max(1, int(round(M['thick'])))
    for i in range(int(half * 2) + 1):
        t = (i - half) / half
        xx = mx + t * half
        sag = {'calm': 0.0, 'worry': 0.4, 'pain': 1.0, 'slack': 0.4, 'out': 0.2}[mood] * (t * t)
        yy = my - 0.5 * (1 - t * t) * (1.0 if mood == 'calm' else 0.2) + sag
        if open_ > 0.8 and abs(t) < 0.75:
            for d in range(1, int(open_) + 1):
                c.px_on(xx, yy + d, (74, 26, 34), hm)
        c.px_on(xx, yy, lips_d, hm)
        if abs(t) < 0.7:
            for q in range(1, th + 1):
                c.px_on(xx, yy + open_ * 0.9 + q, lips, hm)
    if look.get('stubble'):
        for _ in range(46):
            x, y = cx + rng.uniform(-12, 13) + s * 0.5, cy + rng.uniform(12, 25)
            if 0 <= int(y) < H and 0 <= int(x) < W and hm[int(y), int(x)]:
                c.px(x, y, _t(mix(sk_d, ink, 0.5)))
    if look.get('blush') and stage <= 2:                                            # a flat blush: two small ovals
        bl = _t(mix(sk_m, hexrgb(look['blush']), 0.55))
        for ex_, dir_ in ((cx + s - E['gap'] * 0.9, 1), (cx + s + E['gap'] * 0.9, 1)):
            for dx in range(-2, 3):
                for dy in range(0, 2):
                    c.px_on(ex_ + dx, cy + 8 + dy, bl, hm)
    if stage >= 2:                                                                  # a worried forehead: hard creases
        for k in range(2 if stage < 4 else 3):
            yy = cy - 14 - k * 1.8
            for xx in range(int(cx - 5 + s), int(cx + 8 + s)):
                c.px_on(xx, yy + (0.5 if (xx % 4 == 0) else 0.0), sk_d, hm)




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
        pass
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
        bx, by = cx + s - look['eyes']['gap'], cy - 1.5
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
        bx, by = cx + s - look['eyes']['gap'], cy - 1.5                                                    # the near eye swollen shut
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
