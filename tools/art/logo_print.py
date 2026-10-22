#!/usr/bin/env python3
"""The BLOODIED HANDPRINT of the logo - a print, not a silhouette.

Owner round 48: "the logo is the bloodied handprint and if that doesn't work then the logo doesn't work."  A flat shape in a solid red read as a
cold-war poster, not as blood.  What makes a print read as BLOOD on a wall is not its outline but how it TRANSFERRED, so this draws that:

  * PRESSURE decides everything.  The pads of the fingers and the heel of the palm press hard (solid, dark, blood squeezed out into a pooled rim at the
    edge); the arch of the palm, the creases of the palm and the joints of the fingers barely touch (the print BREAKS there, in a few ragged dry-brush
    streaks - never a clean ring or a ruled band).
  * The EDGE is WET: rounded, blobby, a little uneven where the blood met the wall (a low wobble, then a soft blur and a hard threshold - never the
    torn-paper edge of fine noise), with a few beads of blood where it ran.
  * THICK is dark and THIN is brighter (a film of blood lets the light through); the thick places catch a soft wet SHEEN (a height field lit from the top left).
  * SKIN: the ridges of the fingertips and of the palm leave a faint pattern (loops round the pads, a flowing swirl over the palm) - the tell that this is
    a real hand and not a cut-out.  The hand slid a hair, so the blood is dragged in soft vertical smears (no fine weave: that reads as fabric).
  * It is a wall, so it RUNS: a few plump drips hang from the lowest edge (a meniscus at the top, a swelling, a bead at the foot, a glint down one side),
    and spatter lies round it - round drops, some thrown off in a streak.
  Restrained: the colours stay dark blood (never a bright red).

Pure function of its arguments (a fixed seed), numpy + scipy + PIL.  `print_image(h_px)` -> (RGBA uint8 array, info); `info` maps back to palm-widths.
"""
import math

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

import logo_hand

THICK = np.array((92, 10, 16), np.float32)            # blood in a thick layer: nearly black-red
THIN = np.array((180, 38, 34), np.float32)           # a thin film: lighter, a little warmer
RIM = np.array((50, 5, 10), np.float32)              # where it squeezed out and pooled at the edge
GLINT = np.array((226, 120, 108), np.float32)        # the sheen on wet blood


def _fbm(shape, rng, sigmas, weights):
    out = np.zeros(shape, np.float32)
    for sg, w in zip(sigmas, weights):
        n = ndi.gaussian_filter(rng.standard_normal(shape).astype(np.float32), sg, mode='reflect')
        out += w * n / (n.std() + 1e-6)
    return out / math.sqrt(sum(w * w for w in weights))


def _smooth(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _seg_dist(xs, ys, a, b):
    """Distance from every grid point to the segment a-b."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy + 1e-9
    t = np.clip(((xs - ax) * dx + (ys - ay) * dy) / L2, 0, 1)
    return np.hypot(xs - (ax + t * dx), ys - (ay + t * dy))


def _raster(geom, W, H, k, ox, oy, ss=2):
    big = Image.new('L', (W * ss, H * ss), 0)
    d = ImageDraw.Draw(big)
    polys = [geom] if geom.geom_type == 'Polygon' else list(geom.geoms)
    for p in polys:
        d.polygon([((x * k + ox) * ss, (y * k + oy) * ss) for x, y in p.exterior.coords], fill=255)
        for r in p.interiors:
            d.polygon([((x * k + ox) * ss, (y * k + oy) * ss) for x, y in r.coords], fill=0)
    return np.asarray(big.resize((W, H), Image.BOX), np.float32) / 255.0


def _blob(draw, x, y, rx, ry, ang, ss):
    """A filled ellipse (rx along `ang`) on a supersampled mask."""
    pts = []
    for i in range(20):
        t = 2 * math.pi * i / 20
        ex, ey = math.cos(t) * rx, math.sin(t) * ry
        pts.append(((x + ex * math.cos(ang) - ey * math.sin(ang)) * ss, (y + ex * math.sin(ang) + ey * math.cos(ang)) * ss))
    draw.polygon(pts, fill=255)


def _drip(draw, shine, x, y, length, w0, rng, ss):
    """A run of blood hanging from (x, y): it leaves the print in a small flare, narrows, swells where a drop is on its way down, narrows again
    and ends in a plump teardrop; a thin glint down its left shoulder.  Drawn on supersampled masks."""
    n = max(10, int(length / 2.5))
    wob = rng.uniform(0.5, 1.5)
    sway = rng.uniform(-0.30, 0.30) * w0
    swell = rng.uniform(0.30, 0.65)
    swell_w = rng.uniform(0.12, 0.2)
    pts, rad = [], []
    for i in range(n + 1):
        t = i / n
        px = x + math.sin(t * 3.4 + wob) * w0 * 0.18 * t + sway * t * t
        py = y + t * length
        r = w0 * (0.58 - 0.26 * t ** 0.7) * (1.0 + 0.30 * math.exp(-((t - swell) / swell_w) ** 2))
        r += w0 * 0.12 * math.exp(-(t / 0.05) ** 2)                      # a faint flare where it leaves the print
        pts.append((px, py))
        rad.append(r)
    for (px, py), r in zip(pts, rad):
        draw.ellipse([(px - r) * ss, (py - r) * ss, (px + r) * ss, (py + r) * ss], fill=255)
    bx, by = pts[-1]
    br = w0 * 0.74
    _blob(draw, bx, by + br * 0.55, br * 1.55, br, math.pi / 2, ss)          # the drop at the foot: a tall teardrop
    glint = [((px - r * 0.45) * ss, py * ss) for (px, py), r in zip(pts[2:-1], rad[2:-1])]
    shine.line(glint, fill=255, width=max(1, int(w0 * 0.20 * ss)))
    shine.ellipse([(bx - br * 0.42 - br * 0.16) * ss, (by + br * 0.05) * ss, (bx - br * 0.42 + br * 0.16) * ss, (by + br * 0.95) * ss], fill=255)


def print_image(h_px=1600, seed=11):
    rng = np.random.RandomState(seed)
    g = logo_hand.hand_geometry()
    f = logo_hand.features()
    gx0, gy0, gx1, gy1 = g.bounds
    pad = 0.07
    k = h_px * (1.0 - pad - 0.26) / (gy1 - gy0)                   # px per palm-width; the bottom quarter is left for the drips
    W = int(round((gx1 - gx0) * k + 2 * pad * h_px))
    H = int(h_px)
    ox, oy = pad * h_px - gx0 * k, pad * h_px - gy0 * k
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)

    def P(pt):                                                    # palm-widths -> px
        return (pt[0] * k + ox, pt[1] * k + oy)

    S = _raster(g, W, H, k, ox, oy)
    # --- the WET edge: displace the shape with a low wobble and a little blobby roughness, then soften and re-threshold, so the outline is
    # rounded and uneven like blood that met a wall - not the torn edge of fine noise
    n_lo = _fbm((H, W), rng, (46, 22), (1.0, 0.6))
    n_mid = _fbm((H, W), rng, (7, 3.5), (1.0, 0.7))
    n_hi = _fbm((H, W), rng, (1.8, 1.0), (1.0, 0.6))
    dy = n_lo * 0.0060 * H + n_mid * 0.0022 * H
    dx = _fbm((H, W), rng, (46, 22), (1.0, 0.6)) * 0.0060 * H + _fbm((H, W), rng, (7, 3.5), (1.0, 0.7)) * 0.0022 * H
    S = ndi.map_coordinates(S, [ys + dy, xs + dx], order=1, mode='constant')
    S = _smooth(ndi.gaussian_filter(S, 0.0042 * H), 0.46, 0.54)
    inside = S > 0.5
    d_in = ndi.distance_transform_edt(inside).astype(np.float32)
    d_in[~inside] = 0.0

    # --- pressure
    press = np.full((H, W), 0.86, np.float32)
    pads = []
    pcx0, pcy0 = P(f['palm'])
    for (tx, ty, r) in f['tips'] + [f['thumb_tip']]:                 # the pad of every finger presses hard
        cx, cy = P((tx, ty))
        v = np.array((pcx0 - cx, pcy0 - cy), np.float32)
        v /= np.hypot(*v) + 1e-6
        cx, cy = cx + v[0] * r * k * 0.75, cy + v[1] * r * k * 0.75   # the pad is a little below the very tip
        pads.append((cx, cy, r * k))
        rr = r * k * 1.9
        press += 0.34 * np.exp(-(((xs - cx) ** 2 + (ys - cy) ** 2) / (rr * rr)))
    cx, cy = P(f['palm'])
    press -= 0.13 * np.exp(-(((xs - cx) ** 2 + (ys - cy - 0.02 * H) ** 2) / ((0.20 * k) ** 2)))        # the arch of the palm barely touches
    hx, hy = P((f['palm'][0] - 0.04, f['palm'][1] + 0.46))
    press += 0.16 * np.exp(-(((xs - hx) ** 2 + (ys - hy) ** 2) / ((0.22 * k) ** 2)))                    # the heel presses
    for (jx, jy, ux, uy, half) in f['joints']:                       # the joints of the fingers: the print breaks across them, in streaks that don't quite meet
        a = P((jx - ux * half * 0.95, jy - uy * half * 0.95))
        b = P((jx + ux * half * 0.95, jy + uy * half * 0.95))
        dist = _seg_dist(xs, ys, a, b)
        gap = np.exp(-(dist / (0.0075 * H)) ** 2)
        press -= (0.52 * _smooth(n_mid + 0.35 * n_lo, -0.15, 0.95)) * gap
    for line in f['creases']:                                        # the creases of the palm: thin, broken
        pts = [P(p) for p in line]
        dist = np.minimum.reduce([_seg_dist(xs, ys, pts[i], pts[i + 1]) for i in range(len(pts) - 1)])
        press -= 0.34 * (0.3 + 0.7 * _smooth(n_mid, -0.7, 0.6)) * np.exp(-(dist / (0.0060 * H)) ** 2)
    # the hand slid a hair: soft vertical smears (a wide, smooth drag - never a fine weave)
    smear = ndi.gaussian_filter(rng.standard_normal((H, W)).astype(np.float32), (70, 9))
    smear /= smear.std() + 1e-6
    press += 0.10 * n_lo + 0.05 * n_mid + 0.02 * n_hi + 0.07 * smear

    # --- skin: ridges round every pad (loops) and a swirl over the palm; a pattern in the thickness, not an outline
    ridge = np.zeros((H, W), np.float32)
    pitch = 0.0074 * H
    warp = _fbm((H, W), rng, (30, 14), (1.0, 0.7))
    for (cx, cy, r) in pads:
        u = np.hypot((xs - cx), (ys - cy) * 0.78) + warp * 0.0045 * H
        mask = np.exp(-((u / (r * 1.7)) ** 2))
        ridge += mask * np.sin(2 * math.pi * u / pitch)
    tcx, tcy = P((f['palm'][0] - 0.12, f['palm'][1] + 0.34))
    u = np.hypot(xs - tcx, (ys - tcy) * 1.15) + warp * 0.010 * H
    mask = np.exp(-((np.hypot(xs - pcx0, ys - pcy0 - 0.12 * k) / (0.50 * k)) ** 2))
    ridge += 0.9 * mask * np.sin(2 * math.pi * u / (pitch * 1.25))
    ridge = np.clip(ridge, -1.0, 1.0)
    press += 0.065 * ridge

    # --- how much transferred
    edge = np.clip(d_in / (0.0042 * H) + 0.30 * n_mid, 0.0, 1.0)     # the very edge thins a little
    Q = S * edge * (press + 0.03 * n_hi)
    cover = _smooth(Q, 0.33, 0.47)
    D = np.clip((Q - 0.36) / 0.52, 0.0, 1.0)                          # thickness
    rim = np.exp(-d_in / (0.0085 * H)) * (d_in > 0)                   # pooled at the edge
    D = np.clip(D + 0.45 * rim, 0.0, 1.0)
    colour = THIN[None, None, :] * (1 - D[..., None]) + THICK[None, None, :] * D[..., None]
    colour = colour * (1.0 + 0.08 * n_mid[..., None]) + (RIM - colour) * (0.60 * rim[..., None])
    # the lightest films are thin enough to let the wall show a little
    alpha = cover * (0.84 + 0.16 * D)

    # --- the wet sheen: a height field (thick = high, the pooled rim highest) lit from the top left; a soft specular, only where there is blood
    height = ndi.gaussian_filter(D * 1.0 + 0.9 * rim, 0.0085 * H)
    gy_, gx_ = np.gradient(height)
    nx, ny = -gx_ * 0.0085 * H * 7.0, -gy_ * 0.0085 * H * 7.0
    nz = np.ones_like(nx)
    nn = np.sqrt(nx * nx + ny * ny + nz * nz)
    L = np.array((-0.45, -0.55, 0.70), np.float32)
    Hv = L + np.array((0, 0, 1.0), np.float32)
    Hv /= np.linalg.norm(Hv)
    spec = np.clip((nx * Hv[0] + ny * Hv[1] + nz * Hv[2]) / nn, 0, 1) ** 40
    spec = np.clip(spec * 2.2, 0, 1) * (cover > 0.5) * _smooth(D, 0.45, 0.85)
    colour = colour * (1 - 0.26 * spec[..., None]) + GLINT[None, None, :] * (0.26 * spec[..., None])

    # --- drips: a few plump runs from the lowest edge
    big = Image.new('L', (W * 2, H * 2), 0)
    dr = ImageDraw.Draw(big)
    shn = Image.new('L', (W * 2, H * 2), 0)
    shd = ImageDraw.Draw(shn)
    lowest = np.full(W, -1.0, np.float32)
    rows = np.where(cover > 0.5)
    for yy, xx in zip(rows[0][::7], rows[1][::7]):
        lowest[xx] = max(lowest[xx], yy)
    cand = [x for x in range(int(0.12 * W), int(0.92 * W)) if lowest[x] > 0.5 * H]
    drips = []
    if cand:
        for _ in range(80):
            x = cand[rng.randint(len(cand))]
            if all(abs(x - q) > 0.055 * W for q, _l in drips):
                drips.append((x, 0))
            if len(drips) >= 5:
                break
    for (x, _l) in drips:
        y0 = lowest[x] - 0.006 * H
        length = rng.uniform(0.05, 0.20) * H
        _drip(dr, shd, x, y0, length, rng.uniform(0.0125, 0.021) * H, rng, 2)
    dmask = np.asarray(big.resize((W, H), Image.BOX), np.float32) / 255.0
    dmask = np.clip(dmask, 0, 1)
    dcol = (THICK * 0.80 + RIM * 0.20)[None, None, :]
    shine = np.asarray(shn.resize((W, H), Image.BOX), np.float32) / 255.0

    # --- spatter: round drops round the print, a few thrown off in a streak
    sp = Image.new('L', (W * 2, H * 2), 0)
    sd = ImageDraw.Draw(sp)
    pcx, pcy = P(f['palm'])
    for _ in range(60):
        ang = rng.uniform(0, 2 * math.pi)
        rad = (0.40 + abs(rng.normal(0, 0.32))) * k
        x, y = pcx + math.cos(ang) * rad * 1.05, pcy + math.sin(ang) * rad * 1.2
        if not (0.02 * W < x < 0.98 * W and 0.02 * H < y < 0.80 * H):
            continue
        if S[int(y), int(x)] > 0.5 and rng.rand() < 0.7:
            continue
        r = math.exp(rng.normal(math.log(0.0030 * H), 0.55))
        r = min(r, 0.0085 * H)
        a = math.atan2(y - pcy, x - pcx)
        streak = r > 0.0042 * H and rng.rand() < 0.5                 # a bigger drop thrown off the hand, a tail pointing back to it
        _blob(sd, x, y, r * (1.0 + (1.2 if streak else 0.35 * rng.rand())), r, a, 2)
        if streak:
            for j in range(1, 4):
                _blob(sd, x - math.cos(a) * r * (1.8 + 1.3 * j), y - math.sin(a) * r * (1.8 + 1.3 * j), r * (0.6 - 0.12 * j), r * (0.5 - 0.1 * j), a, 2)
    smask = np.asarray(sp.resize((W, H), Image.BOX), np.float32) / 255.0

    # --- composite the layers (drips + spatter are thick blood)
    A = np.clip(np.maximum.reduce([alpha, dmask * 0.97, smask * 0.95]), 0, 1)
    col = colour.copy()
    for m, c in ((dmask, dcol), (smask, dcol)):
        col = col * (1 - m[..., None]) + c * m[..., None]
    sh = np.clip(shine * dmask, 0, 1) * 0.26                         # the glint down a drip's shoulder
    col = col * (1 - sh[..., None]) + GLINT[None, None, :] * sh[..., None]
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = np.clip(col, 0, 255).astype(np.uint8)
    out[..., 3] = (A * 255).astype(np.uint8)
    info = {'scale': k, 'ox': ox, 'oy': oy, 'w': W, 'h': H}
    return out, info


if __name__ == '__main__':
    import sys
    im, info = print_image(int(sys.argv[2]) if len(sys.argv) > 2 else 1200)
    base = np.zeros(im.shape[:2] + (3,), np.uint8)
    base[...] = (18, 13, 22)
    a = im[..., 3:4].astype(np.float32) / 255
    Image.fromarray((base * (1 - a) + im[..., :3] * a).astype(np.uint8)).save(sys.argv[1])
