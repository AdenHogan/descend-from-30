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
ROT_SLIDE = logo_hand.ROT_EFF + 4.0 * logo_hand.SGN                       # the way the hand slid, degrees from straight down the image


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
    """A run of blood hanging from (x, y): it leaves the print wide and narrows, thins to a neck, swells where a drop is on its way down, thins again and ends
    in a plump teardrop; its path wanders a little and its width is never quite even.  Drawn on supersampled masks; the print is drawn OVER its top."""
    n = max(12, int(length / 2.2))
    wob = rng.uniform(0.5, 1.5)
    sway = rng.uniform(-0.45, 0.45) * w0
    swell = rng.uniform(0.28, 0.62)
    swell_w = rng.uniform(0.10, 0.18)
    ph1, ph2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    pts, rad = [], []
    for i in range(n + 1):
        t = i / n
        px = x + math.sin(t * 3.1 + wob) * w0 * 0.22 * t + sway * t * t
        py = y + t * length
        r = w0 * (0.62 - 0.36 * t ** 0.6) * (1.0 + 0.55 * math.exp(-((t - swell) / swell_w) ** 2))
        r *= 1.0 + 0.10 * math.sin(t * 17.0 + ph1) + 0.06 * math.sin(t * 41.0 + ph2)          # never an even pipe
        r += w0 * 0.12 * math.exp(-(t / 0.08) ** 2)                                           # a little wider where it leaves the print
        pts.append((px, py))
        rad.append(max(r, w0 * 0.16))
    for (px, py), r in zip(pts, rad):
        draw.ellipse([(px - r) * ss, (py - r) * ss, (px + r) * ss, (py + r) * ss], fill=255)
    bx, by = pts[-1]
    br = w0 * 0.70
    _blob(draw, bx, by + br * 0.65, br * 1.65, br, math.pi / 2, ss)                           # the drop at the foot: a tall teardrop
    glint = [((px - r * 0.42) * ss, py * ss) for (px, py), r in zip(pts[n // 4:-2], rad[n // 4:-2])]
    shine.line(glint, fill=255, width=max(1, int(w0 * 0.10 * ss)))
    shine.ellipse([(bx - br * 0.40 - br * 0.14) * ss, (by + br * 0.15) * ss, (bx - br * 0.40 + br * 0.14) * ss, (by + br * 0.95) * ss], fill=255)


def _stops(t, stops):
    """Colour along a gradient: t in 0..1 -> (H, W, 3); `stops` = [(position, rgb)] ascending."""
    out = np.zeros(t.shape + (3,), np.float32)
    ps = [p for p, _c in stops]
    for ch in range(3):
        out[..., ch] = np.interp(t, ps, [c[ch] for _p, c in stops])
    return out


def _streaks(shape, rng, angle_deg, length, width):
    """Long thin streaks lying along `angle_deg` from vertical (0 = straight down the image): anisotropic noise, rotated, normalised."""
    pad = int(length * 2)
    big = (shape[0] + 2 * pad, shape[1] + 2 * pad)
    n = ndi.gaussian_filter(rng.standard_normal(big).astype(np.float32), (length, width), mode='reflect')
    n = ndi.rotate(n, angle_deg, reshape=False, order=1, mode='reflect')[pad:pad + shape[0], pad:pad + shape[1]]
    return n / (n.std() + 1e-6)


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
    # --- the WET edge: a low wobble and a little blobby roughness, then softened and re-thresholded: rounded and uneven like blood that met a wall
    n_lo = _fbm((H, W), rng, (46, 22), (1.0, 0.6))
    n_mid = _fbm((H, W), rng, (7, 3.5), (1.0, 0.7))
    dy = n_lo * 0.0060 * H + n_mid * 0.0022 * H
    dx = _fbm((H, W), rng, (46, 22), (1.0, 0.6)) * 0.0060 * H + _fbm((H, W), rng, (7, 3.5), (1.0, 0.7)) * 0.0022 * H
    S = ndi.map_coordinates(S, [ys + dy, xs + dx], order=1, mode='constant')
    S = _smooth(ndi.gaussian_filter(S, 0.0042 * H), 0.46, 0.54)
    inside = S > 0.5
    d_in = ndi.distance_transform_edt(inside).astype(np.float32)
    d_in[~inside] = 0.0

    # --- the hand slid a little as it pressed: a few long, thin, DRY-BRUSH streaks all one way (no fine grain - that reads as woven cloth),
    # gathered in patches; they lighten the film and, in the worst places, leave the wall showing
    slide = ROT_SLIDE
    st_a = _streaks((H, W), rng, slide, 0.050 * H, 0.0011 * H)
    st_b = _streaks((H, W), rng, slide + 3.0, 0.085 * H, 0.0022 * H)
    patch = _smooth(_fbm((H, W), rng, (60, 28), (1.0, 0.6)), -0.2, 0.9)
    streak = (_smooth(st_a, 1.1, 2.4) * 0.7 + _smooth(st_b, 1.3, 2.6)) * patch
    gap_streak = _smooth(st_a * 0.6 + st_b * 0.8, 1.7, 2.6) * patch              # the very worst of them: no blood at all

    # --- pressure: where the hand really touched
    press = np.full((H, W), 0.92, np.float32)
    pads = []
    pcx0, pcy0 = P(f['palm'])
    for (tx, ty, r) in f['tips'] + [f['thumb_tip']]:                 # the pads of the fingers press hardest
        cx, cy = P((tx, ty))
        v = np.array((pcx0 - cx, pcy0 - cy), np.float32)
        v /= np.hypot(*v) + 1e-6
        cx, cy = cx + v[0] * r * k * 0.75, cy + v[1] * r * k * 0.75   # the pad is a little below the very tip
        pads.append((cx, cy, r * k))
        rr = r * k * 1.9
        press += 0.20 * np.exp(-(((xs - cx) ** 2 + (ys - cy) ** 2) / (rr * rr)))
    cx, cy = P(f['palm'])
    press -= 0.17 * np.exp(-(((xs - cx) ** 2 + (ys - cy - 0.02 * H) ** 2) / ((0.20 * k) ** 2)))        # the arch of the palm barely touches
    hx, hy = P((f['palm'][0] - 0.04, f['palm'][1] + 0.46))
    press += 0.10 * np.exp(-(((xs - hx) ** 2 + (ys - hy) ** 2) / ((0.22 * k) ** 2)))                    # the heel presses
    press_body = press.copy()                                        # how hard it pressed, before the cut-throughs below
    for (jx, jy, ux, uy, half) in f['joints']:                       # the joints of the fingers: a narrow crease where nothing transfers, broken by the streaks
        a = P((jx - ux * half * 0.95, jy - uy * half * 0.95))
        b = P((jx + ux * half * 0.95, jy + uy * half * 0.95))
        dist = _seg_dist(xs + 0.55 * dx, ys + 0.55 * dy, a, b)       # the crease wanders a little
        gap = np.exp(-(dist / (0.0040 * H)) ** 2)
        press -= (0.80 * _smooth(n_mid + 0.9 * n_lo, -0.35, 0.80)) * gap
    for line in f['creases']:                                        # the creases of the palm: thin, broken
        pts = [P(p) for p in line]
        dist = np.minimum.reduce([_seg_dist(xs, ys, pts[i], pts[i + 1]) for i in range(len(pts) - 1)])
        press -= 0.55 * (0.25 + 0.75 * _smooth(n_mid, -0.7, 0.6)) * np.exp(-(dist / (0.0034 * H)) ** 2)
    press += 0.05 * n_lo - 0.30 * gap_streak
    press_body += 0.05 * n_lo
    # the wrist and the bottom of the heel barely touch: the print fades out downwards, into streaks (never a flat cut)
    cosr, sinr = math.cos(math.radians(logo_hand.ROT_EFF)), math.sin(math.radians(logo_hand.ROT_EFF))
    along = ((xs - ox) * (-sinr) + (ys - oy) * cosr) / k            # the hand's own axis, in palm-widths from the knuckle line (rot undone)
    lat = ((xs - ox) * cosr + (ys - oy) * sinr) / k                  # across the hand
    along = along + 1.15 * np.minimum(np.abs(lat + 0.02 * logo_hand.SGN), 0.46) ** 2   # ... and the heel is round: the sides of the palm let go sooner than its middle
    fade = 1.6 * _smooth(along, 0.86, 1.10) * (0.45 + 0.55 * _smooth(st_b + 0.4 * st_a, -1.2, 1.6))
    press -= fade
    press_body -= fade

    # --- skin: ridges round every pad (loops), visible where the film is thin
    ridge = np.zeros((H, W), np.float32)
    pitch = 0.0072 * H
    warp = _fbm((H, W), rng, (30, 14), (1.0, 0.7))
    for (cx, cy, r) in pads:
        u = np.hypot((xs - cx), (ys - cy) * 0.78) + warp * 0.011 * H
        mask = np.exp(-((u / (r * 1.45)) ** 2))
        ridge += mask * np.sin(2 * math.pi * u / pitch)
    ridge = np.clip(ridge, -1.0, 1.0)
    press += 0.04 * ridge
    press_body += 0.04 * ridge

    # --- how much transferred
    edge = np.clip(d_in / (0.0042 * H) + 0.25 * n_mid, 0.0, 1.0)     # the very edge thins a little
    Q = S * edge * press
    cover = _smooth(Q, 0.34, 0.46)
    # every edge - the outline AND the edge of any gap in the print - pools: darker where the blood was squeezed out
    d_cov = ndi.distance_transform_edt(cover > 0.5).astype(np.float32)
    rim = np.exp(-d_cov / (0.0070 * H)) * (d_cov > 0)
    Qb = S * edge * press_body
    T = np.clip((Qb - 0.40) / 0.80, 0.0, 1.0) + 0.30 * rim            # thickness: 0 = a thin film .. 1 = thick
    T = np.clip(T - 0.22 * streak + 0.06 * ridge + 0.075 * n_lo + 0.02 * n_mid, 0.0, 1.0)
    colour = _stops(1.0 - T, [(0.0, tuple(RIM)), (0.22, tuple(THICK)), (0.50, (122, 16, 22)), (1.0, tuple(THIN))])
    alpha = cover * (0.88 + 0.12 * T)

    # --- wet: a thin glint only along the rim that faces the light, and only where the blood is thick (no blobs of "shine" across the body)
    gys, gxs = np.gradient(ndi.gaussian_filter(S, 0.0034 * H))
    mag = np.hypot(gxs, gys) + 1e-6
    facing = np.clip((-gxs / mag) * -0.55 + (-gys / mag) * -0.83, 0, 1) ** 2         # the edge's outward normal against the light (top left)
    glint = facing * np.exp(-d_in / (0.0030 * H)) * (d_in > 0) * _smooth(0.5 * n_mid + 0.5 * n_lo + 0.6, 0.3, 1.1)
    colour = colour * (1 - 0.40 * glint[..., None]) + GLINT[None, None, :] * (0.40 * glint[..., None])

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
        length = rng.uniform(0.07, 0.22) * H
        _drip(dr, shd, x, y0, length, rng.uniform(0.0125, 0.021) * H, rng, 2)
    dmask = np.asarray(big.resize((W, H), Image.BOX), np.float32) / 255.0
    edge_y = ndi.maximum_filter1d(lowest, size=int(0.03 * W), mode='nearest')           # the print's lower edge, column by column
    dmask = np.clip(dmask, 0, 1) * (ys > (edge_y[None, :] - 0.004 * H)).astype(np.float32)
    dcol = np.array((112, 14, 21), np.float32)[None, None, :]
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
        if S[int(y), int(x)] > 0.3 or x < pcx - 0.50 * k:               # none on the print itself, and none to its left: the words stand there
            continue
        r = math.exp(rng.normal(math.log(0.0030 * H), 0.55))
        r = min(r, 0.0085 * H)
        a = math.atan2(y - pcy, x - pcx)
        streak_drop = r > 0.0042 * H and rng.rand() < 0.5            # a bigger drop thrown off the hand, a tail pointing back to it
        _blob(sd, x, y, r * (1.0 + (1.2 if streak_drop else 0.35 * rng.rand())), r, a, 2)
        if streak_drop:
            for j in range(1, 4):
                _blob(sd, x - math.cos(a) * r * (1.8 + 1.3 * j), y - math.sin(a) * r * (1.8 + 1.3 * j), r * (0.6 - 0.12 * j), r * (0.5 - 0.1 * j), a, 2)
    smask = np.asarray(sp.resize((W, H), Image.BOX), np.float32) / 255.0

    # --- composite: the drips and the spatter are drawn first, the print OVER them, so a drip comes out of the print's pooled edge
    under = np.maximum(dmask * 0.97, smask * 0.95)
    ucol = np.broadcast_to(dcol, colour.shape).copy()
    sh = np.clip(shine * dmask, 0, 1) * 0.22                         # the glint down a drip's shoulder
    ucol = ucol * (1 - sh[..., None]) + GLINT[None, None, :] * sh[..., None]
    A = alpha + under * (1 - alpha)
    col = (colour * alpha[..., None] + ucol * (under * (1 - alpha))[..., None]) / np.maximum(A, 1e-4)[..., None]
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
