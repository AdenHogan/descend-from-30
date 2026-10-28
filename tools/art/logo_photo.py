#!/usr/bin/env python3
"""THE HANDPRINT of the logo - the OWNER'S OWN HAND, cut out of their photograph and drawn as a print (owner round 48m).

The owner painted their hand in blood paint and photographed it (the first attempts - an AI edit of that photo and a procedural print - were rejected:
"AI crap", "foam", "a real jpeg under the text").  This module keeps what is real about the photo and stylises only what made it look like a photograph:

  * REAL: the silhouette (the real outline, a calm wobble on top of it), the pressure (where the blood is thick and thin comes from the photo's own large-scale
    shading, posterised to six tones in the game's own oxblood ramp - `logo_print.THIN` .. `THICK`), the palm's lines and the finger joints (the photo's high-pass
    detail, kept in blood tones, never black ink), the dry-brush breaks at the edge.
  * STYLISED: no glare and no gloss (one lighting glare on the palm was inpainted away - it was a lighting accident, not a feature), a pooled darker rim on every
    edge, limited tones with a little blur so it reads as a print, and the drips - drawn, with DIFFERENT endings (tapering, a bead on a neck, a falling droplet,
    a blunt lip, the oval) because identical ovals on every drip read as a stamp.

`print_image()` -> (RGBA uint8 array: the hand + its drips, info) - `info` maps the array back to the layout's units (UNIT px = one unit, origin at the array's
top-left) - and `hand_shape()` -> the hand's outline as a shapely polygon in those units (what the layout, the icon and the checks measure).
Pure functions of tools/art/logo_src/hand_cut.png and fixed seeds (numpy + scipy + scikit-image + PIL).

THE SOURCE: `logo_src/hand_cut.png` is the photo cut out (1748 x 2000 RGBA).  It was made once, by hand-steered image work, from the owner's 4000 x 3000 photograph
turned upright: an AI segmenter (rembg / isnet) for the outline, then a colour rule that keeps only the blood (red, saturated) and drops the pale skin fringe, the wrist
(cut where the blood ends), the table showing through the finger gaps and a few lumps of background, then a gentle smoothing of the outline.  Nothing is invented: the
pixels are the photo's.  It is the only input; the photo itself is not in the repository.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from shapely.geometry import Polygon

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import logo_print as LP

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'logo_src', 'hand_cut.png')
UNIT = 1000.0                       # array pixels per layout unit ("palm-width" in the procedural print this replaced)
PADB = 900                          # room under the hand for the drips
RIM = LP.RIM
THICK = LP.THICK
THIN = LP.THIN
GLINT = LP.GLINT
sm = LP._smooth

# the look the owner chose (rounds 48m, 'q5'): every number below was tuned by eye against the photo
LOOK = dict(
    seed=7,
    levels=6, quant_amt=0.7,            # six tones, 70 % posterised: a print, not a photo
    shade_sigma=9, tone_blur=2.0,       # the photo's own shading, blurred: where the blood is thick / thin
    t_gain=1.2, t_bias=-0.10, t_cap=0.86,
    rim_amt=0.40,                       # the pooled, darker rim on every edge
    streak_tone=0.05, streak_amt=0.12,  # dry-brush streaks: a hint (the creases are not cut out any more: they were the "pruney" look)
    wobble=0.45,                        # the edge wobble, as a share of the old procedural print's
    detail_sigma=(2.2, 9.0), detail_amt=1.3,       # the palm's own lines, at their natural strength, in blood tones
    glare=[(850, 1565, 80, 90)],        # (x, y, rx, ry) of the lighting glare on the palm that was removed
    drip_colour=(128, 17, 24),
)
# the drips: (x as a share of the hand's width, length, stream width, ending) in hand-array px.  Three hang under the thumb (two run down behind the M of FROM),
# two along the heel; no two end alike.
DRIPS = [(0.05, 300, 29, 'taper'), (0.075, 440, 28, 'falling'), (0.095, 250, 25, 'blunt'), (0.50, 230, 31, 'bead'), (0.625, 120, 26, 'oval')]

_HAND = None
_PRINT = None
_SHAPE = None


def load_hand():
    global _HAND
    if _HAND is None:
        _HAND = Image.open(SRC).convert('RGBA')
    return _HAND


def hand_shape():
    """The hand's outline (the photo's, as cut out) as a shapely polygon in layout units (array px / UNIT), y down."""
    global _SHAPE
    if _SHAPE is None:
        from skimage import measure
        a = np.asarray(load_hand().getchannel('A')) > 127
        lab, n = ndi.label(a)
        sizes = ndi.sum(a, lab, range(1, n + 1))
        a = ndi.binary_fill_holes(lab == (1 + int(np.argmax(sizes))))
        cs = measure.find_contours(np.pad(a, 1).astype(np.float32), 0.5)
        c = max(cs, key=len) - 1.0
        _SHAPE = Polygon([(x / UNIT, y / UNIT) for y, x in c]).simplify(0.0015).buffer(0)
    return _SHAPE


# ---------------------------------------------------------------------------------------------------------------- the drips' endings
def _teardrop(draw, cx, cy, r, ss, tip=2.3):
    pts = [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in np.linspace(0, math.pi, 19)]
    pts += [(cx - r * 0.62, cy - r * 0.80), (cx - r * 0.30, cy - r * 1.45), (cx - r * 0.08, cy - r * 2.0), (cx, cy - r * tip),
            (cx + r * 0.08, cy - r * 2.0), (cx + r * 0.30, cy - r * 1.45), (cx + r * 0.62, cy - r * 0.80)]
    draw.polygon([(x * ss, y * ss) for x, y in pts], fill=255)


def _sm01(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def drip_shape(draw, shine, x, y, length, w0, rng, ss, style='oval'):
    """A run of blood hanging from (x, y) - the same path / swell / wander as logo_print._drip - ending as `style`:
    oval (the original plump teardrop) | bead (a big round drop on a thin neck) | taper (thins to a point) | falling (a drop with a separate droplet under it)
    | blunt (a thick run that stops in a flat lip) | double (a bulge part-way down plus an oval end)."""
    n = max(12, int(length / 2.2))
    wob = rng.uniform(0.5, 1.5)
    sway = rng.uniform(-0.45, 0.45) * w0
    swell = rng.uniform(0.28, 0.62)
    swell_w = rng.uniform(0.10, 0.18)
    ph1, ph2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    swell_amp = 0.55
    if style == 'double':
        swell, swell_w, swell_amp = 0.40, 0.11, 1.05
    pts, rad = [], []
    for i in range(n + 1):
        t = i / n
        px = x + math.sin(t * 3.1 + wob) * w0 * 0.22 * t + sway * t * t
        py = y + t * length
        r = w0 * (0.62 - 0.36 * t ** 0.6) * (1.0 + swell_amp * math.exp(-((t - swell) / swell_w) ** 2))
        r *= 1.0 + 0.10 * math.sin(t * 17.0 + ph1) + 0.06 * math.sin(t * 41.0 + ph2)
        r += w0 * 0.12 * math.exp(-(t / 0.08) ** 2)
        if style == 'taper':
            r *= 1.0 - 0.80 * t ** 1.5
        elif style == 'bead':
            r *= 1.0 - 0.38 * _sm01((t - 0.72) / 0.28)
        elif style == 'blunt':
            r = max(r, 0.44 * w0 * _sm01((t - 0.3) / 0.3))
        pts.append((px, py))
        rad.append(max(r, w0 * (0.07 if style == 'taper' else 0.16)))
    for (px, py), r in zip(pts, rad):
        draw.ellipse([(px - r) * ss, (py - r) * ss, (px + r) * ss, (py + r) * ss], fill=255)
    bx, by = pts[-1]
    hi = None                                                          # the foot's highlight: (cx, cy, rx, ry)
    if style in ('oval', 'double', 'falling'):
        br = w0 * {'oval': 0.70, 'double': 0.56, 'falling': 0.55}[style]
        LP._blob(draw, bx, by + br * 0.65, br * 1.65, br, math.pi / 2, ss)
        hi = (bx - br * 0.40, by + br * 0.55, br * 0.14, br * 0.40)
        if style == 'falling':
            dr_ = w0 * 0.34
            cy = by + br * 2.3 + w0 * 0.85 + dr_
            _teardrop(draw, bx + sway * 0.02, cy, dr_, ss)
            hi2 = (bx - dr_ * 0.38, cy - dr_ * 0.15, dr_ * 0.16, dr_ * 0.42)
            shine.ellipse([(hi2[0] - hi2[2]) * ss, (hi2[1] - hi2[3]) * ss, (hi2[0] + hi2[2]) * ss, (hi2[1] + hi2[3]) * ss], fill=255)
    elif style == 'bead':
        rb = w0 * 0.94
        cy = by + rb * 0.55
        draw.ellipse([(bx - rb) * ss, (cy - rb * 1.06) * ss, (bx + rb) * ss, (cy + rb * 1.04) * ss], fill=255)
        hi = (bx - rb * 0.42, cy - rb * 0.10, rb * 0.15, rb * 0.42)
    elif style == 'blunt':
        draw.ellipse([(bx - w0 * 0.64) * ss, (by - w0 * 0.10) * ss, (bx + w0 * 0.64) * ss, (by + w0 * 0.52) * ss], fill=255)
        hi = (bx - w0 * 0.30, by + w0 * 0.20, w0 * 0.10, w0 * 0.12)
    elif style == 'taper':
        r_ = w0 * 0.07
        draw.ellipse([(bx - r_) * ss, (by - r_) * ss, (bx + r_) * ss, (by + r_ * 2.2) * ss], fill=255)
    glint = [((px - r * 0.42) * ss, py * ss) for (px, py), r in zip(pts[n // 4:-2], rad[n // 4:-2])]
    if len(glint) > 2:
        shine.line(glint, fill=255, width=max(1, int(w0 * 0.10 * ss)))
    if hi is not None:
        shine.ellipse([(hi[0] - hi[2]) * ss, (hi[1] - hi[3]) * ss, (hi[0] + hi[2]) * ss, (hi[1] + hi[3]) * ss], fill=255)


# ---------------------------------------------------------------------------------------------------------------- the print
def stylise(hand, drips=(), seed=7, levels=6, quant_amt=0.7, shade_sigma=9, tone_blur=2.0, t_gain=1.2, t_bias=-0.10, t_cap=0.86, rim_amt=0.40, streak_tone=0.05,
            streak_amt=0.12, wobble=0.45, detail_sigma=(2.2, 9.0), detail_amt=1.3, glare=(), drip_colour=(128, 17, 24)):
    """hand: RGBA PIL image (the cut-out).  -> RGBA uint8 array, hand + PADB rows below for the drips.  The ORDER of the random draws is part of the picture
    (the drips take what is left), so do not reorder them."""
    from skimage.restoration import inpaint_biharmonic
    rng = np.random.RandomState(seed)
    W, H0 = hand.size
    H = H0 + PADB
    rgbp = np.zeros((H, W, 4), np.uint8)
    rgbp[:H0] = np.asarray(hand)
    rgb = rgbp[..., :3].astype(np.float32) / 255.0
    A = rgbp[..., 3].astype(np.float32) / 255.0
    inside0 = A > 0.5
    mx = rgb.max(2)
    mn = rgb.min(2)
    sat = (mx - mn) / (mx + 1e-6)
    spec = ((sat < 0.62) & (mx > 0.5) & inside0)                  # the photo's specular glints...
    spec_d = ndi.binary_dilation(spec, iterations=3)
    valid = inside0 & ~spec_d
    idx = ndi.distance_transform_edt(~valid, return_indices=True)[1]
    R = rgb[..., 0][idx[0], idx[1]]                               # ...replaced by the blood next to them: the red channel carries the thickness
    # the lighting glare that was not a feature of the hand: rebuild the area from the blood round it (smooth, no new shape)
    ys0, xs0 = np.mgrid[0:H, 0:W].astype(np.float32)
    for (gx_, gy_, grx, gry) in glare:
        x0g, x1g = int(gx_ - grx * 2.4), int(gx_ + grx * 2.4)
        y0g, y1g = int(gy_ - gry * 2.4), int(gy_ + gry * 2.4)
        win = (slice(y0g, y1g), slice(x0g, x1g))
        ell = (((xs0[win] - gx_) / grx) ** 2 + ((ys0[win] - gy_) / gry) ** 2) < 1.0
        mk = ndi.binary_dilation(ell | spec_d[win], iterations=6) & inside0[win]
        R[win] = inpaint_biharmonic(R[win].astype(np.float64), mk).astype(np.float32)
    # the wet edge: the real outline, a very small wobble and a soft threshold
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    dy = LP._fbm((H, W), rng, (30, 12), (1.0, 0.6)) * 0.0022 * H0 * wobble + LP._fbm((H, W), rng, (5, 2.5), (1.0, 0.7)) * 0.0010 * H0 * wobble
    dx = LP._fbm((H, W), rng, (30, 12), (1.0, 0.6)) * 0.0022 * H0 * wobble + LP._fbm((H, W), rng, (5, 2.5), (1.0, 0.7)) * 0.0010 * H0 * wobble
    S = ndi.map_coordinates(ndi.gaussian_filter(A, 1.5), [ys + dy, xs + dx], order=1, mode='constant')
    S = sm(ndi.gaussian_filter(S, 2.2), 0.46, 0.54)
    inside = S > 0.5
    d_in = ndi.distance_transform_edt(inside).astype(np.float32)
    # thickness from the photo's own large-scale shading (the dark pooled places are thick, the light film is thin)
    Rb = ndi.gaussian_filter(R, shade_sigma)
    lo, hi = np.percentile(Rb[inside0], [3, 97])
    T = 1.0 - np.clip((Rb - lo) / (hi - lo), 0, 1)
    # dry-brush: long thin streaks one way, strongest near the edge; where the worst of them lie the print breaks
    slide = 8.0
    st_a = LP._streaks((H, W), rng, slide, 0.045 * H0, 0.0011 * H0)
    st_b = LP._streaks((H, W), rng, slide + 3.0, 0.080 * H0, 0.0022 * H0)
    patch = sm(LP._fbm((H, W), rng, (60, 28), (1.0, 0.6)), -0.2, 0.9)
    streak = (sm(st_a, 1.1, 2.4) * 0.7 + sm(st_b, 1.3, 2.6)) * patch
    gap = sm(st_a * 0.6 + st_b * 0.8, 1.7, 2.6) * patch
    near_edge = np.exp(-d_in / (0.045 * H0))
    cover = S * (1.0 - np.clip(0.95 * gap * (0.25 + 0.75 * near_edge) * streak_amt, 0, 1))
    cover = sm(cover, 0.30, 0.55)
    d_cov = ndi.distance_transform_edt(cover > 0.5).astype(np.float32)
    rim = np.exp(-d_cov / (0.0065 * H0)) * (d_cov > 0)
    # tone: a few bands (the draw below is kept for the order of the random numbers - it adds nothing)
    LP._fbm((H, W), rng, (2.2, 1.2), (1.0, 0.6))
    streak_s = ndi.gaussian_filter(streak, 4.0)
    t = np.clip(T * t_gain + t_bias - streak_tone * streak_s * streak_amt, 0, 1)
    t = ndi.gaussian_filter(t, tone_blur)
    hp = ndi.gaussian_filter(R, detail_sigma[0]) - ndi.gaussian_filter(R, detail_sigma[1])          # the real hand's own lines, at their natural strength
    hp = hp / (np.percentile(np.abs(hp[inside0 & (d_in > 20)]), 97) + 1e-6)
    t = t - detail_amt * 0.16 * np.clip(hp, -1.6, 1.2)
    t = np.clip(np.minimum(t, t_cap) + rim_amt * rim, 0, 1)
    tq = np.round(t * (levels - 1)) / (levels - 1)
    tq = t * (1 - quant_amt) + tq * quant_amt
    tq = ndi.gaussian_filter(tq, 0.9)
    colour = LP._stops(1.0 - tq, [(0.0, tuple(RIM)), (0.22, tuple(THICK)), (0.50, (122, 16, 22)), (1.0, tuple(THIN))])
    alpha = cover * 0.98
    # the drips, hanging from the real lower edge
    big = Image.new('L', (W * 2, H * 2), 0)
    dr = ImageDraw.Draw(big)
    shn = Image.new('L', (W * 2, H * 2), 0)
    lowest = np.full(W, -1.0, np.float32)
    rows = np.where(cover > 0.5)
    for yy, xx in zip(rows[0][::5], rows[1][::5]):
        lowest[xx] = max(lowest[xx], yy)
    for d_ in drips:
        x, L, w0 = d_[:3]
        style = d_[3] if len(d_) > 3 else 'oval'
        y0 = lowest[int(x)] - 0.006 * H0
        if style == 'oval':
            LP._drip(dr, ImageDraw.Draw(shn), x, y0, L, w0, rng, 2)
        else:
            drip_shape(dr, ImageDraw.Draw(shn), x, y0, L, w0, rng, 2, style)
    dmask = np.asarray(big.resize((W, H), Image.BOX), np.float32) / 255.0
    edge_y = ndi.maximum_filter1d(lowest, size=max(3, int(0.006 * W)), mode='nearest')
    dmask = np.clip(dmask, 0, 1) * (ys > (edge_y[None, :] - 0.004 * H0)).astype(np.float32)
    shn_a = np.asarray(shn.resize((W, H), Image.BOX), np.float32) / 255.0
    # the drips are cel-shaded like the hand: a mid body, a darker pooled edge, one light band down the lit side
    ucol = np.broadcast_to(np.array(drip_colour, np.float32)[None, None, :], colour.shape).copy()
    dm = dmask > 0.5
    core = ndi.binary_erosion(dm, iterations=4)
    edge_band = (dm & ~core).astype(np.float32)
    edge_band = ndi.gaussian_filter(edge_band, 0.8)
    ucol = ucol * (1 - edge_band[..., None] * 0.9) + np.array((66, 7, 13), np.float32)[None, None, :] * (edge_band[..., None] * 0.9)
    band = ndi.gaussian_filter((ndi.binary_dilation(shn_a > 0.5, iterations=2) & core).astype(np.float32), 0.8)
    ucol = ucol * (1 - band[..., None]) + np.array((176, 36, 32), np.float32)[None, None, :] * band[..., None]
    under = dmask * 0.97
    Aout = alpha + under * (1 - alpha)
    col = (colour * alpha[..., None] + ucol * (under * (1 - alpha))[..., None]) / np.maximum(Aout, 1e-4)[..., None]
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = np.clip(col, 0, 255).astype(np.uint8)
    out[..., 3] = (np.clip(Aout, 0, 1) * 255).astype(np.uint8)
    return out


def print_image():
    """-> (RGBA uint8 array of the hand and its drips, info) - cached; `info` = {'scale': UNIT, 'ox': 0, 'oy': 0, 'w', 'h'} (the same contract the procedural print had)."""
    global _PRINT
    if _PRINT is None:
        hand = load_hand()
        Wd = hand.width
        look = dict(LOOK)
        drips = [(Wd * fx, L, w, st) for fx, L, w, st in DRIPS]
        arr = stylise(hand, drips=drips, **look)
        _PRINT = (arr, {'scale': UNIT, 'ox': 0.0, 'oy': 0.0, 'w': arr.shape[1], 'h': arr.shape[0]})
    return _PRINT


def print_scaled(f):
    """The print at f times its size (f >= 1) for a bigger render: resampled premultiplied (no dark fringe) and its edge re-sharpened - the same treatment at f = 1,
    so every size starts from the same picture.  -> (array, info) with info['scale'] = UNIT * f (the layout's contract: array px per unit)."""
    arr, info = print_image()
    H, W = arr.shape[:2]
    size = (int(round(W * f)), int(round(H * f)))
    a = arr[..., 3].astype(np.float32) / 255.0
    pre = arr[..., :3].astype(np.float32) * a[..., None]

    def rs(x):
        if (x.shape[1], x.shape[0]) == size:
            return x
        return np.asarray(Image.fromarray(x.astype(np.float32), 'F').resize(size, Image.LANCZOS))
    a_up = rs(a)
    pre_up = np.stack([rs(pre[..., c]) for c in range(3)], -1)
    rgb = pre_up / np.maximum(a_up, 1e-3)[..., None]
    a_s = np.clip((np.clip(a_up, 0, 1) - 0.5) * 2.0 + 0.5, 0.0, 1.0)
    out = np.zeros(a_s.shape + (4,), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = (a_s * 255).astype(np.uint8)
    return out, {'scale': UNIT * f, 'ox': 0.0, 'oy': 0.0, 'w': out.shape[1], 'h': out.shape[0]}


if __name__ == '__main__':
    arr, info = print_image()
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '_logo_print_preview.png')
    bg = Image.new('RGBA', (arr.shape[1], arr.shape[0]), (24, 16, 28, 255))
    bg.alpha_composite(Image.fromarray(arr, 'RGBA'))
    bg.convert('RGB').save(out)
    print('wrote', out, arr.shape)
