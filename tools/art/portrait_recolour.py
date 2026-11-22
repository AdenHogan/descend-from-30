#!/usr/bin/env python3
"""HUD PORTRAITS by RECOLOURING THE PLACEHOLDERS (fifth start; owner: "go from zero. A plain basic face. Profile to the right like the current placeholder look. Just try to replicate the
original placeholder"). The placeholder busts (assets/Health_Bar from git history, commit 9d5bfb73~1) already ARE the wanted look: a clean 3/4 profile to the right, a plain face, a ribbed
sweater. So the new Joe is that same art with the new colours: the hair and the knit are recoloured; the face, the shading, the wounds, the bandages and the blood are untouched.

    python3 tools/art/portrait_recolour.py joe [out_dir]
"""
import colorsys
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
SRC_COMMIT = '9d5bfb73~1'


def original(name):
    data = subprocess.check_output(['git', '-C', ROOT, 'show', '%s:assets/Health_Bar/%s' % (SRC_COMMIT, name)])
    import io
    return Image.open(io.BytesIO(data)).convert('RGBA')


def to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(2)
    mn = rgb.min(2)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    s = d / (mx + 1e-6)
    return h, s, mx


def from_hsv(h, s, v):
    h6 = (h % 360.0) / 60.0
    c = v * s
    x = c * (1 - np.abs(h6 % 2 - 1))
    m = v - c
    z = np.zeros_like(h)
    conds = [(h6 < 1), (h6 < 2), (h6 < 3), (h6 < 4), (h6 < 5), (h6 >= 5)]
    rs = [c, x, z, z, x, c]
    gs = [x, c, c, x, z, z]
    bs = [z, z, x, c, c, x]
    r = np.select(conds, rs) + m
    g = np.select(conds, gs) + m
    b = np.select(conds, bs) + m
    return np.stack([r, g, b], axis=-1)


def recolour(img, hair=(22.0, 0.58, 0.50), knit=(172.0, 0.46, 1.30), jacket=(200.0, 0.22, 1.0)):
    """hair / knit / jacket: (target hue, saturation scale, value scale)."""
    a = np.array(img).astype(np.float32)
    rgb = a[..., :3] / 255.0
    h, s, v = to_hsv(rgb)
    Hh, Ww = h.shape
    yy, xx = np.mgrid[0:Hh, 0:Ww]
    blood = (h < 18.0) | (h > 340.0)
    grey_hair = (h >= 33.0) & (s > 0.16) & (s <= 0.45) & (v > 0.35) & (yy < 190)                   # the dying stages' hair has gone grey and dull
    hair_m = ((h >= 31.0) & (s > 0.45) & (yy < 235) | grey_hair) & ~blood
    knit_m = (yy >= 215) & (h < 29.0) & (s > 0.40) & (v < 0.72) & (xx > 60) & ~blood
    jacket_m = (yy >= 200) & (h >= 29.0) & (v < 0.62) & (s > 0.30) & ~hair_m & ((yy >= 270) | (xx < 110))      # (not the face / neck: a dark drip there is blood)
    from scipy import ndimage

    def big_only(m, min_px):
        lab, n = ndimage.label(m, structure=np.ones((3, 3)))
        if n == 0:
            return m
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        keep = np.zeros(n + 1, dtype=bool)
        keep[1:] = sizes >= min_px
        return keep[lab]
    hair_m, knit_m, jacket_m = big_only(hair_m, 400), big_only(knit_m, 600), big_only(jacket_m, 600)       # (a stray pixel at a skin / blood edge is not cloth)
    out = rgb.copy()
    for m, (th, ss, vs) in ((hair_m, hair), (knit_m, knit), (jacket_m, jacket)):
        nh = np.full_like(h, th)
        ns = np.clip(s * ss / 0.65, 0, 1)
        nv = np.clip(v * vs, 0, 1)
        out[m] = from_hsv(nh, ns, nv)[m]
    res = np.dstack([out * 255.0, a[..., 3]]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(res, 'RGBA')


STAGES = ['1 - Healthy', '2 - Hurt', '3 - Injured', '4 - Wounded', '5 - Severely Wounded', '6 - Dying']


def joe(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for st in STAGES:
        im = recolour(original('blond_man - %s.png' % st))
        im.save(os.path.join(out_dir, 'blond_man - %s.png' % st))


if __name__ == '__main__':
    who = sys.argv[1] if len(sys.argv) > 1 else 'joe'
    out = sys.argv[2] if len(sys.argv) > 2 else '/tmp/portrait_recolour'
    globals()[who](out)
    print('wrote', out)
