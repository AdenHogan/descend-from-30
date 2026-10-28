#!/usr/bin/env python3
"""THE WEAR AND THE BLOOD ON THE LOGO'S LETTERING (owner round 48m: "grimy with a bit of blood is nice"; "the little strikes of blood on the 30").

The look is the owner's reference for a worn, printed title (The Last of Us / Days Gone / The Day Before): FINE grain eaten out of the letters in patches, a few
vertical rub-scratches, ragged eroded edges and a faint dirty wash - fine, never chunky (a first, chunkier pass "went too far").  On top of the lettering, a few
strikes of thrown blood: ragged swipes with a plump head and a broken tail, spatter, a short run - drawn like the hand's drips (a wet uneven edge, a darker pooled rim,
three flat tones), and clipped to the letters, so wherever the letter was worn away the blood is gone too.

THE SAME WEAR ON EVERY LETTER (the words and the 30 get the same grain, scratches and blood: the owner's "same wear everywhere"); the blood strikes are sized to their
letters' strokes (the 30's are bigger than the words').

RESOLUTION: the look is COMPUTED ONCE at the reference size (`REF_W` = 2400 px wide - the exact picture the owner approved) and CARRIED to any size: the letters'
edges are re-cut from the vector outlines at the target size, the wear / blood maps are bicubic-resampled and re-sharpened.  So a 6000 px advertising render is the
approved logo, only sharper - not a new random draw.  `reference()` computes (and caches), `letters()` finishes a layer at any size.

Pure functions of the masks and fixed seeds (numpy + scipy + PIL).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import logo_print as LP

sm = LP._smooth

WARM = (238, 230, 214)                      # the letters on a dark ground (the owner's cream-white)
INK = (24, 16, 28)                          # the near-black of the game's night: the words on a light ground
DIRT_WARM = (168, 158, 142)                 # the faint dirty wash on cream letters
DIRT_INK = (84, 74, 86)                     # ... and on ink ones
BLOOD_A = np.array((142, 26, 28), np.float32)       # a strike of blood: the lit body
BLOOD_B = np.array((98, 16, 22), np.float32)        # ... and its pooled edge
REF_W = 2400                                # the reference size (px wide) the look is computed at
SEED = 41
AMOUNT = 1.4                                # how much wear
SHARP_GAIN = 2.4                            # the contrast put back into the wear / blood edges when they are carried to a bigger size
# the blood strikes: (which letters, swipes, spatter clusters, short runs, size of the strikes, how far in from the letter's edge they may start (px at REF_W))
BLOOD = [('num', 6, 7, 2, 1.0, 12), ('words', 3, 4, 1, 0.7, 5)]
STRIKE_ANGLE = -52.0                        # the way the blood was thrown, degrees


# ---------------------------------------------------------------------------------------------------------------- the wear
def grunge_parts(mask, seed=SEED, amount=AMOUNT):
    """-> {'m': the letters' coverage with a slightly ragged edge, 'gone': where the letter is worn away (0..1), 'wash': the faint dirty wash (0..1)}.
    mask: float 0..1, the letters' vector coverage at the reference size."""
    rng = np.random.RandomState(seed)
    H, W = mask.shape
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    dx = LP._fbm((H, W), rng, (8, 2.0), (1.0, 0.9)) * 0.9
    dy = LP._fbm((H, W), rng, (8, 2.0), (1.0, 0.9)) * 0.9
    m = ndi.map_coordinates(mask, [ys + dy, xs + dx], order=1, mode='constant')
    m = sm(ndi.gaussian_filter(m, 0.6), 0.45, 0.55)
    inside = m > 0.5
    d_in = ndi.distance_transform_edt(inside).astype(np.float32)
    big = LP._fbm((H, W), rng, (110, 45), (1.0, 0.6))
    patch = sm(big, -0.35, 0.9)                                    # wide areas where the wear lives
    patch2 = sm(LP._fbm((H, W), rng, (60, 24), (1.0, 0.6)), -0.2, 1.0)
    wash = sm(LP._fbm((H, W), rng, (70, 28), (1.0, 0.6)), 0.0, 1.2) * 0.10 * min(amount, 1.6)
    grain = LP._fbm((H, W), rng, (1.2, 0.7), (1.0, 0.6))
    pit = sm(grain - 0.9 * (1 - patch) - 0.35 * (1 - patch2), 1.55 - 0.18 * amount, 2.0)                       # fine grain pits
    fleck = sm(LP._fbm((H, W), rng, (2.6, 1.3), (1.0, 0.7)) - 0.8 * (1 - patch2), 2.1 - 0.12 * amount, 2.6)   # mid-size flecks
    sa = LP._streaks((H, W), rng, 2.0, 60.0, 0.9)                                                              # vertical rub scratches, and a few horizontal scuffs
    sb = LP._streaks((H, W), rng, -3.0, 140.0, 1.2)
    sc = LP._streaks((H, W), rng, 85.0, 40.0, 0.9)
    scratch = np.clip(sm(sa, 2.2, 2.9) * 0.9 + sm(sb, 2.4, 3.1) + 0.6 * sm(sc, 2.6, 3.2), 0, 1) * patch
    edge = sm(LP._fbm((H, W), rng, (2.2, 1.1), (1.0, 0.6)) + 1.4 * np.exp(-d_in / 7.0) - 0.7 * (1 - patch), 2.05 - 0.15 * amount, 2.55)         # eroded edges
    gone = np.clip(np.maximum.reduce([pit * 0.95, fleck * 0.9, scratch * 0.8, edge]), 0, 1)
    return {'m': m, 'gone': gone, 'wash': wash}


# ---------------------------------------------------------------------------------------------------------------- the blood
def _band(d, x, y, ang, length, w, ss, rng, bend=0.35):
    """A swipe / thrown strike: a ragged, curved band, widest near (x, y) (where it landed) and thinning to a broken tail along `ang`."""
    n = 28
    curve = rng.uniform(-bend, bend)
    ph = rng.uniform(0, 6.28)
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        a2 = ang + curve * t
        cx = x - math.cos(ang) * length * t + math.sin(ang) * curve * length * t * t * 0.5
        cy = y - math.sin(ang) * length * t - math.cos(ang) * curve * length * t * t * 0.5
        r = w * (1.0 - t) ** 0.7 * (0.75 + 0.25 * math.sin(t * 14 + ph)) * (1.0 + 0.5 * math.exp(-(t / 0.12) ** 2))
        px, py = -math.sin(a2), math.cos(a2)
        left.append(((cx + px * r) * ss, (cy + py * r) * ss))
        right.append(((cx - px * r) * ss, (cy - py * r) * ss))
    d.polygon(left + right[::-1], fill=255)


def _drop(d, cx, cy, r, ss, ang=None, stretch=1.0):
    pts = []
    for i in range(18):
        t = 2 * math.pi * i / 18
        ex, ey = math.cos(t) * r * stretch, math.sin(t) * r
        a = ang or 0.0
        pts.append(((cx + ex * math.cos(a) - ey * math.sin(a)) * ss, (cy + ex * math.sin(a) + ey * math.cos(a)) * ss))
    d.polygon(pts, fill=255)


def blood_parts(mask, regions, seed):
    """The strikes of blood on the letters.  mask: the letters (words + 30) at the reference size; regions: [(area 0/1 array, swipes, spatter clusters, runs,
    size, inset)].  -> (b: the blood's coverage BEFORE the clip to the letters, tone: 0..1, how deep the blood is).  The ORDER of the random draws is part of the picture."""
    rng = np.random.RandomState(seed)
    H, W = mask.shape
    ss = 2
    body = Image.new('L', (W * ss, H * ss), 0)
    bd = ImageDraw.Draw(body)
    base_mask = mask > 0.5
    bscale, erode = 1.0, 12
    for rg in regions:
        reg, n_swipe, n_clusters, n_runs = rg[:4]
        if len(rg) > 4:
            bscale, erode = rg[4], rg[5]
        inside = ndi.binary_erosion(base_mask, iterations=erode)
        pts = np.argwhere(inside & (reg > 0.5))
        if len(pts) == 0:
            continue
        for _ in range(n_swipe):
            y, x = pts[rng.randint(len(pts))]
            ang = math.radians(STRIKE_ANGLE + rng.normal(0, 22))
            L = rng.uniform(70, 190) * bscale ** 0.5
            w = rng.uniform(7.0, 13.0) * bscale
            _band(bd, x, y, ang, L, w, ss, rng)
            _drop(bd, x + rng.normal(0, 3), y + rng.normal(0, 3), w * rng.uniform(0.8, 1.15), ss)
            for _k in range(rng.randint(3, 7)):                                                   # spray beyond the head, along the line of travel
                s = rng.uniform(0.15, 1.1) * L
                cx = x + math.cos(ang) * s * 0.55 + rng.normal(0, 7)
                cy = y + math.sin(ang) * s * 0.55 + rng.normal(0, 7)
                _drop(bd, cx, cy, rng.uniform(1.4, 4.2) * bscale ** 0.7, ss, ang, rng.uniform(1.0, 1.9))
        for _ in range(n_clusters):
            y, x = pts[rng.randint(len(pts))]
            ang = math.radians(STRIKE_ANGLE + rng.normal(0, 40))
            for _k in range(rng.randint(8, 16)):
                r = (abs(rng.normal(0, 1)) * 3.2 + 1.3) * bscale ** 0.7
                cx, cy = x + rng.normal(0, 26 * bscale ** 0.5), y + rng.normal(0, 26 * bscale ** 0.5)
                _drop(bd, cx, cy, r, ss, ang, 1.0 + 0.5 * rng.rand())
        for _ in range(n_runs):                                                                  # a short run, starting where it landed and running down
            y, x = pts[rng.randint(len(pts))]
            L = rng.uniform(50, 130) * bscale ** 0.5
            w = rng.uniform(4.5, 7.5) * bscale
            wob = rng.uniform(0, 6.28)
            for j in range(0, int(L), 3):
                r = w * (0.95 - 0.45 * j / L) * (1 + 0.12 * math.sin(j / 9.0 + wob))
                cx = x + 2.0 * math.sin(j / 25.0 + wob)
                bd.ellipse([(cx - r) * ss, (y + j - r) * ss, (cx + r) * ss, (y + j + r) * ss], fill=255)
            _drop(bd, x + 2.0 * math.sin(L / 25.0 + wob), y + L + w * 0.6, w * 1.25, ss, math.pi / 2, 1.25)
            _drop(bd, x, y, w * 1.9, ss)
    b = np.asarray(body.resize((W, H), Image.BOX), np.float32) / 255.0
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    dx = LP._fbm((H, W), rng, (9, 3.0), (1.0, 0.8)) * 1.6                   # a wet, uneven edge (as the hand's is made)
    dy = LP._fbm((H, W), rng, (9, 3.0), (1.0, 0.8)) * 1.6
    b = ndi.map_coordinates(b, [ys + dy, xs + dx], order=1, mode='constant')
    b = sm(ndi.gaussian_filter(b, 0.8), 0.42, 0.58)
    bc = b * np.clip(mask, 0, 1)
    d_edge = ndi.distance_transform_edt(bc > 0.5)
    rim = np.clip(1.0 - d_edge / 3.0, 0, 1) * (bc > 0.5)                    # darker where it pooled at the edge
    mott = sm(LP._fbm((H, W), rng, (7, 3.0), (1.0, 0.7)), 0.0, 1.2)        # mottled: thicker / thinner blood
    tone = np.clip(0.30 * mott + 0.85 * rim, 0, 1)
    tone = np.round(tone * 3) / 3.0                                          # three flat tones
    tone = ndi.gaussian_filter(tone, 0.7)
    return b, tone


# ---------------------------------------------------------------------------------------------------------------- the reference and the carry
_REF = None


def reference(mw, mn):
    """Compute the look at the reference size (cached): mw / mn = the words' and the 30's coverage (float 0..1) at REF_W."""
    global _REF
    if _REF is None or _REF['shape'] != mw.shape:
        mask = np.clip(mw + mn, 0, 1)
        pw = grunge_parts(mw)
        pn = grunge_parts(mn)
        reg_num = ndi.binary_dilation(mn > 0.5, iterations=2).astype(np.float32)
        reg_words = (mw > 0.5).astype(np.float32)
        regions = [(reg_num if which == 'num' else reg_words,) + tuple(rest) for which, *rest in BLOOD]
        b, tone = blood_parts(mask, regions, SEED + 36)
        _REF = {'shape': mw.shape, 'words': pw, 'num': pn, 'b': b, 'tone': tone}
    return _REF


def up(a, size):
    """Bicubic resample of a float32 map to size = (w, h) (a copy when it is the size already)."""
    if (a.shape[1], a.shape[0]) == tuple(size):
        return a.astype(np.float32).copy()
    return np.asarray(Image.fromarray(a.astype(np.float32), 'F').resize(tuple(size), Image.BICUBIC))


def sharpen(x, gain):
    return np.clip((x - 0.5) * gain + 0.5, 0.0, 1.0)


def _letters(part, m_out, size, theme, which):
    gone = sharpen(np.clip(up(part['gone'], size), 0, 1), SHARP_GAIN)
    wash = up(part['wash'], size)
    ink = theme == 'light' and which == 'words'
    base = np.array(INK if ink else WARM, np.float32)
    dirt = np.array(DIRT_INK if ink else DIRT_WARM, np.float32)
    col = np.zeros(wash.shape + (3,), np.float32)
    col[:] = base
    col = col * (1 - wash[..., None]) + dirt * wash[..., None]
    alpha = m_out * (1 - gone)
    out = np.zeros(alpha.shape + (4,), np.uint8)
    out[..., :3] = np.clip(col, 0, 255).astype(np.uint8)
    out[..., 3] = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    return out


def letters(ref, mw_out, mn_out, theme='dark'):
    """The finished lettering at the output size: -> RGBA PIL image (the words and the 30, worn, with the blood strikes on them).
    mw_out / mn_out: the letters' vector coverage at the OUTPUT size (float 0..1)."""
    H, W = mw_out.shape
    size = (W, H)
    txt = Image.fromarray(_letters(ref['words'], mw_out, size, theme, 'words'), 'RGBA')
    txt.alpha_composite(Image.fromarray(_letters(ref['num'], mn_out, size, theme, 'num'), 'RGBA'))
    mask = np.clip(mw_out + mn_out, 0, 1)
    b = sharpen(np.clip(up(ref['b'], size), 0, 1), SHARP_GAIN) * np.clip(mask, 0, 1)
    tone = np.clip(up(ref['tone'], size), 0, 1)
    col = BLOOD_A[None, None, :] * (1 - tone[..., None]) + BLOOD_B[None, None, :] * tone[..., None]
    ta = np.asarray(txt)[..., 3].astype(np.float32) / 255.0                  # where the letter was worn away there is no blood either
    bl = np.zeros((H, W, 4), np.uint8)
    bl[..., :3] = np.clip(col, 0, 255).astype(np.uint8)
    bl[..., 3] = (np.clip(np.minimum(b, ta), 0, 1) * 255).astype(np.uint8)
    txt.alpha_composite(Image.fromarray(bl, 'RGBA'))
    return txt
