"""THE CITY OUTSIDE (owner round 28 — "the windows in apartments look pretty simple… stick some city scape in the
background… pixel rain that loops as an animation behind the window, and also on the balcony in the night run…
small pixel fires and explosions on those buildings in the distance").

One place draws the city seen from a flat:

  draw_city(c, box, run, rng)   paints a skyline into a Canvas box — used by the WINDOW views here and by the
                                balcony's view in tools/art/balcony.py — and returns where its fires / blasts /
                                smoke plumes can sit (a tower's roof, a burning floor, a blast's centre);
  window_frame(run)             the window's frame + sill + glass sheen (transparent glass hole);
  fire / explosion / smoke / rain / splash strips   the small looping animations the game plays on top
                                (scripts/city_fx.gd builds SpriteFrames from these horizontal strips).

Everything is authored at native size and drawn with hard pixels. The game never tints or scales these — only the
exposure (scripts/city_fx.gd) so they read in the night-dark CanvasModulate.

Writes assets/city/*.png + assets/city/city_meta.json + a contact sheet docs/art_reference/city/city_views.png.
Run:  python3 tools/art/cityscape.py
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
OUT = os.path.join(ROOT, 'assets', 'city')

# ---- the window's glass (the node's pane; scripts/apartment_window.gd PANE_HALF_*) ---------------------------
GLASS_W, GLASS_H = 44, 52
VARIANTS = 4
# PARALLAX (owner round 33 — "walking past the window, the image in the background is static… extend the city image a little and
# then allow for the view to pan slightly as you go left to right and back"): every view is drawn PAN px wider than its glass on
# each side; the game clips it to the glass and slides it up to PAN px with the player (scripts/city_view.gd).
PAN = 8
VIEW_W = GLASS_W + 2 * PAN

LOOK = {
    1: dict(sky=[(0.0, hexc('79aede')), (0.55, hexc('b5d6ee')), (1.0, hexc('e6f1f3'))],
            far=hexc('b4c6d6'), mid=hexc('8ea3b7'), near=hexc('5e7185'), roof=hexc('3f4c59'),
            lit=None, haze=0.50),
    2: dict(sky=[(0.0, hexc('6c5288')), (0.45, hexc('d0768c')), (1.0, hexc('f8c690'))],
            far=hexc('b98898'), mid=hexc('805a72'), near=hexc('4f3851'), roof=hexc('33233a'),
            lit=(hexc('ffd27a'), 0.07), haze=0.45),
    3: dict(sky=[(0.0, hexc('060916')), (0.6, hexc('131a33')), (1.0, hexc('2a2c48'))],
            far=hexc('1c2339'), mid=hexc('11162b'), near=hexc('0a0d1b'), roof=hexc('06080f'),
            lit=(hexc('e9c273'), 0.13), haze=0.35),
}


def _sky(c, x0, y0, x1, y1, run):
    stops = LOOK[run]['sky']
    for y in range(y0, y1 + 1):
        t = (y - y0) / float(max(1, y1 - y0))
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                u = (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
                col = mix(stops[i][1], stops[i + 1][1], u)
                break
        c.hline(x0, x1, y, col)


def _clouds(c, x0, y0, x1, y1, run, rng):
    """Thin horizontal streaks of cloud in the sky's upper part (day + dusk); stars + a moon at night."""
    if run == 3:
        for _ in range(max(6, (x1 - x0) // 4)):
            x = rng.randrange(x0 + 1, x1)
            y = rng.randrange(y0 + 1, y0 + int((y1 - y0) * 0.45))
            c.put(x, y, hexc('c9d2ee', rng.choice((110, 160, 210))))
        if rng.random() < 0.7:                                   # a moon behind the cloud, just a disc
            mx, my = x0 + rng.randrange(6, max(8, x1 - x0 - 6)), y0 + rng.randrange(4, 12)
            c.ellipse(mx, my, 2.6, 2.6, hexc('e6ebf5', 235))
            c.ellipse(mx + 1, my - 1, 2.0, 2.0, hexc('ffffff', 120))
        return
    tone = hexc('ffffff', 130) if run == 1 else hexc('ffd6b8', 120)
    shadow = hexc('9bb6d2', 90) if run == 1 else hexc('9c6a88', 90)
    for _ in range(max(2, (x1 - x0) // 14)):
        w = rng.randrange(6, 15)
        x = rng.randrange(x0 - 2, x1 - w // 2)
        y = rng.randrange(y0 + 3, y0 + int((y1 - y0) * 0.5))
        c.hline(x, x + w, y, tone)
        c.hline(x + 2, x + w - 2, y - 1, tone)
        c.hline(x + 1, x + w - 1, y + 1, shadow)


def _tower(c, x, yt, w, ybot, body, lit, rng, lit_col, dens, hi, lo, stepped=False):
    """One tower: a lit left edge, a shadowed right edge, a flat (or stepped) roof, a window grid."""
    c.rect(x, yt, x + w - 1, ybot, body)
    if hi is not None:
        c.vline(x, yt, ybot, hi)
        c.hline(x, x + w - 1, yt, hi)
    if lo is not None and w > 3:
        c.vline(x + w - 1, yt + 1, ybot, lo)
    if stepped and w >= 6:
        sw = max(2, w // 2 - 1)
        c.rect(x + 1, yt - 3, x + 1 + sw - 1, yt - 1, body)
        if hi is not None:
            c.hline(x + 1, x + sw, yt - 3, hi)
    if lit is not None and w >= 4:
        for wy in range(yt + 2, ybot - 1, 3):
            for wx in range(x + 1, x + w - 1, 2):
                if rng.random() < dens:
                    c.put(wx, wy, lit_col)


def draw_city(c, box, run, rng, layout_seed=None, tall=1.0):
    """Paint the city into `box` = (x0, y0, x1, y1) of Canvas c. Returns {'fire': [...], 'blast': [...],
    'smoke': [...], 'beacon': [...]} in c's coordinates (points a fire / blast / plume / aircraft light may sit on)."""
    L = LOOK[run]
    x0, y0, x1, y1 = box
    # LAYOUT (which tower stands where) comes from its own seed, so the SAME city stands in all three runs — only the
    # light, the windows, the smoke and the fires change (`rng` drives those details).
    lay = random.Random(layout_seed if layout_seed is not None else rng.random())
    hgt = y1 - y0 + 1
    _sky(c, x0, y0, x1, y1, run)
    _clouds(c, x0, y0, x1, y1, run, rng)
    ground = y1
    meta = {'fire': [], 'blast': [], 'smoke': [], 'beacon': []}
    horizon = mix(L['sky'][-1][1], L['sky'][-1][1], 0)
    far_c = L['far']
    mid_c = L['mid']
    near_c = L['near']

    def lit_towers(x, ybot, hmin, hmax, wmin, wmax, body, lit, dens, hi, lo, gap, log=None, haze=0.0, stepped_p=0.0):
        xx = x
        while xx < x1 + 3:
            w = lay.randrange(wmin, wmax + 1)
            h = lay.randrange(hmin, hmax + 1)
            yt = ybot - h
            col = mix(body, horizon, haze) if haze else body
            hic = (shade(col, 1.12) if run < 3 else mix(col, (84, 96, 150, 255), 0.28)) if hi else None
            loc = shade(col, 0.82) if lo else None
            step = lay.random() < stepped_p
            _tower(c, xx, yt, w, ybot, col, lit, rng, L['lit'][0] if L['lit'] else None, dens, hic, loc, stepped=step)
            if lay.random() < 0.28:
                ax = xx + lay.randrange(1, max(2, w - 1))
                c.vline(ax, yt - lay.randrange(3, 7), yt - 1, col)
                if log is not None and lay.random() < 0.6:
                    log.append((ax, yt - 6))
            elif lay.random() < 0.2 and w >= 5:                     # a water tank on legs
                tx = xx + 1
                c.rect(tx, yt - 4, tx + 2, yt - 2, shade(col, 0.85))
                c.vline(tx, yt - 1, yt - 1, col)
                c.vline(tx + 2, yt - 1, yt - 1, col)
            if log is not None:
                log.append(('tower', xx, yt, w, ybot))
            xx += w + lay.randrange(gap[0], gap[1] + 1)

    # 1. far haze: pale, low contrast, tall
    far_log = []
    lit_towers(x0 - 3, ground, int(hgt * 0.30 * tall), int(hgt * 0.52 * tall), 4, 8, far_c, None, 0.0, False, False, (0, 1),
               far_log, 0.0, 0.3)
    # 2. mid towers: the bulk of the skyline — lit windows, edges, the fires / blasts live here
    mid_log = []
    lit_towers(x0 - 2, ground, int(hgt * 0.22 * tall), int(hgt * 0.44 * tall), 4, 8, mid_c, L['lit'], L['lit'][1] if L['lit'] else 0.0,
               True, True, (0, 2), mid_log, 0.0, 0.25)
    # 3. near roofs at the bottom: dark, low, parapets, rooftop huts
    near_log = []
    lit_towers(x0 - 1, ground, 4, max(6, int(hgt * 0.17)), 7, 13, near_c, L['lit'], (L['lit'][1] * 1.3) if L['lit'] else 0.0,
               True, False, (0, 1), near_log, 0.0, 0.0)

    towers = [t for t in mid_log if t[0] == 'tower' and x0 + 2 < t[1] + t[3] // 2 < x1 - 2]
    far_towers = [t for t in far_log if t[0] == 'tower' and x0 + 2 < t[1] + t[3] // 2 < x1 - 2]
    # where things can happen (seeded by the caller's rng; the GAME picks among these)
    for (_k, tx, tyt, tw, _b) in towers:
        cx = tx + tw // 2
        meta['fire'].append((cx, tyt + 1 + lay.randrange(0, 3)))          # burning on the roof / top floor
        meta['blast'].append((cx + lay.randrange(-1, 2), tyt + 4 + lay.randrange(0, 5)))
    for (_k, tx, tyt, tw, _b) in far_towers:
        meta['blast'].append((tx + tw // 2, tyt + 3))
        if lay.random() < 0.5:
            meta['smoke'].append((tx + tw // 2, tyt))
    meta['beacon'] = [p for p in mid_log if isinstance(p[0], int)][:3]
    if run == 3:
        # the glow of everything burning, low over the horizon (fires are drawn by the game; this is the sky's side of it)
        for y in range(ground - int(hgt * 0.45), ground + 1):
            t = 1.0 - (ground - y) / float(hgt * 0.45)
            for x in range(x0, x1 + 1):
                if rng.random() < 0.18 * t * t:
                    c.put(x, y, hexc('c2482a', int(46 * t)))
    return meta


def window_view(run, variant):
    rng = random.Random(2000 + variant * 37 + run)
    c = Canvas(VIEW_W, GLASS_H, seed=variant)
    meta = draw_city(c, (0, 0, VIEW_W - 1, GLASS_H - 1), run, rng, layout_seed=1000 + variant * 37)
    # the centred coordinates the game uses (the glass centre is the node origin, the view centred on it at rest)
    def cen(p):
        return [p[0] - VIEW_W // 2, p[1] - GLASS_H // 2]
    return c.img, {k: [cen(p) for p in v] for k, v in meta.items()}


# ---- the stairwell windows (owner round 31j) -------------------------------------------------------------------
# The stair art's glass is a HOLE (tools/art/stairwell.py); this city sits behind it (scripts/stair_window.gd). One size fits
# both stairs — the DOWN stair's wide three-light window and the UP stair's narrow sash (the sprite covers the rest). 78 tall
# so the rain sheet wraps seamlessly over its 13 frames (78/13 = 6, 39/13 = 3), like the balcony's.
STAIR_RAIN_W, STAIR_H = 72, 78       # the rain sheet: fixed on the glass (wider than the widest hole, 66)
STAIR_W = STAIR_RAIN_W + 2 * PAN      # the view: wider still, so it can pan (round 33)
STAIR_VARIANTS = 2                    # left / right stairwell look out on different stretches of the same city


def stair_view(run, variant):
    rng = random.Random(4000 + variant * 53 + run)
    c = Canvas(STAIR_W, STAIR_H, seed=variant + 11)
    meta = draw_city(c, (0, 0, STAIR_W - 1, STAIR_H - 1), run, rng, layout_seed=3000 + variant * 53, tall=1.15)
    def cen(p):
        return [p[0] - STAIR_W // 2, p[1] - STAIR_H // 2]
    return c.img, {k: [cen(p) for p in v] for k, v in meta.items()}


# ---- the window's frame --------------------------------------------------------------------------------------
FRAME_BORDER = 3
FR_W, FR_H = GLASS_W + 2 * FRAME_BORDER + 4, GLASS_H + 2 * FRAME_BORDER + 4 + 3      # +4: casing, +3: sill lip
FR_CX, FR_CY = FR_W // 2, FRAME_BORDER + 2 + GLASS_H // 2                            # the glass centre in the frame


def window_frame(run):
    """Sash frame with a cross of glazing bars, a casing, a stone sill, and the glass's sheen. The glass itself
    is left TRANSPARENT so the city + weather draw behind it."""
    c = Canvas(FR_W, FR_H, seed=run)
    wood = [hexc('eee8da'), hexc('cfc6b4'), hexc('6d6a66')][run - 1]
    wood_hi = shade(wood, 1.22)
    wood_lo = shade(wood, 0.72)
    sill = [hexc('c9c2b4'), hexc('a8a092'), hexc('55545a')][run - 1]
    gx0, gy0 = FR_CX - GLASS_W // 2, FR_CY - GLASS_H // 2
    gx1, gy1 = gx0 + GLASS_W - 1, gy0 + GLASS_H - 1
    # casing (outer) then the sash frame
    c.rect(1, 1, FR_W - 2, FR_H - 5, shade(wood, 0.9))
    c.hline(1, FR_W - 2, 1, wood_hi)
    c.vline(1, 1, FR_H - 5, wood_hi)
    c.vline(FR_W - 2, 2, FR_H - 5, wood_lo)
    c.rect(3, 3, FR_W - 4, FR_H - 7, wood)
    c.hline(3, FR_W - 4, 3, wood_hi)
    c.vline(3, 3, FR_H - 7, wood_hi)
    c.vline(FR_W - 4, 4, FR_H - 7, wood_lo)
    # the glass hole (transparent) + its inner bevel
    for y in range(gy0, gy1 + 1):
        for x in range(gx0, gx1 + 1):
            c.px[x, y] = (0, 0, 0, 0)
    c.hline(gx0 - 1, gx1 + 1, gy0 - 1, wood_lo)
    c.vline(gx0 - 1, gy0 - 1, gy1 + 1, wood_lo)
    c.hline(gx0 - 1, gx1 + 1, gy1 + 1, wood_hi)
    c.vline(gx1 + 1, gy0 - 1, gy1 + 1, wood_hi)
    # glazing bars: one vertical, one horizontal (upper third) — a classic two-over-two sash
    mx = FR_CX
    my = gy0 + GLASS_H * 2 // 5
    for dx in (-1, 0):
        c.vline(mx + dx, gy0, gy1, wood)
    c.vline(mx - 1, gy0, gy1, wood_hi)
    c.vline(mx, gy0, gy1, wood_lo)
    for dy in (-1, 0):
        c.hline(gx0, gx1, my + dy, wood)
    c.hline(gx0, gx1, my - 1, wood_hi)
    c.hline(gx0, gx1, my, wood_lo)
    # the stone sill: a step that juts out below
    c.rect(0, FR_H - 6, FR_W - 1, FR_H - 3, sill)
    c.hline(0, FR_W - 1, FR_H - 6, shade(sill, 1.25))
    c.hline(0, FR_W - 1, FR_H - 3, shade(sill, 0.75))
    c.hline(1, FR_W - 2, FR_H - 2, hexc('000000', 90))
    c.hline(2, FR_W - 3, FR_H - 1, hexc('000000', 45))
    # the lintel's shadow on the glass (fades down)
    for k in range(4):
        c.hline(gx0, gx1, gy0 + k, hexc('000000', 70 - 17 * k))
    # sheen: two diagonal streaks across the glass
    sheen = hexc('ffffff', 44 if run < 3 else 26)
    for off, w in ((9, 3), (17, 1)):
        for y in range(gy0 + 2, gy1 - 1):
            x = gx0 + off + int((y - gy0) * 0.55)
            for k in range(w):
                if gx0 <= x + k <= gx1 and abs(x + k - mx) > 1:
                    c.put(x + k, y, sheen)
    if run >= 2:                                                      # grime in the corners and along the sill
        for (x, y) in ((gx0, gy1), (gx1, gy1), (gx0 + 1, gy1 - 1), (gx1 - 1, gy1 - 1)):
            c.put(x, y, hexc('2a2118', 80 if run == 2 else 130))
        for x in range(gx0 + 2, gx1 - 1, 5):
            c.vline(x, gy1 - 3, gy1, hexc('2a2118', 50 if run == 2 else 90))
    if run == 3:                                                      # one pane cracked across, and taped
        cx0, cy0 = gx0 + 6, gy0 + 4
        pts = [(cx0, cy0), (cx0 + 4, cy0 + 3), (cx0 + 6, cy0 + 8), (cx0 + 11, cy0 + 10), (cx0 + 13, cy0 + 16)]
        for a, b in zip(pts, pts[1:]):
            c.line(a[0], a[1], b[0], b[1], hexc('e4ecf6', 105))
        c.line(cx0 + 4, cy0 + 3, cx0 + 9, cy0 + 1, hexc('e4ecf6', 80))
        c.line(cx0 + 6, cy0 + 8, cx0 + 1, cy0 + 12, hexc('e4ecf6', 80))
    return c.img


# ---- the animations (horizontal strips) -----------------------------------------------------------------------
def strip(frames):
    w, h = frames[0].size
    im = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.paste(f, (i * w, 0))
    return im


FIRE_W, FIRE_H, FIRE_N = 9, 12, 6
FLAME = [hexc('a8241a'), hexc('e0561c'), hexc('f7962a'), hexc('ffd04a'), hexc('fff2b8')]


def fire_frames(FIRE_W=FIRE_W, FIRE_H=FIRE_H):
    """A small pixel blaze: a bed with licking tongues, red at the edge to a pale-yellow core; embers. 6 frames
    that loop (the tongues are driven by a travelling sine so the first and last frame join)."""
    rng = random.Random(41)
    frames = []
    for f in range(FIRE_N):
        c = Canvas(FIRE_W, FIRE_H, seed=f)
        cx = FIRE_W // 2
        for x in range(FIRE_W):
            d = abs(x - cx) / float(cx)
            base = (1.0 - d * d) * (FIRE_H - 4.0)
            wob = 0.8 + 0.25 * math.sin(2 * math.pi * f / FIRE_N + x * 1.3) + 0.12 * math.sin(2 * math.pi * 2 * f / FIRE_N + x * 2.1)
            h = int(round(base * wob))
            for k in range(h):
                y = FIRE_H - 1 - k
                u = k / float(max(1, h - 1))              # 0 at the bed .. 1 at the tip
                core = (1.0 - d) * (1.0 - u * 0.7)
                idx = 0 if core < 0.22 else 1 if core < 0.42 else 2 if core < 0.62 else 3 if core < 0.82 else 4
                if u > 0.85:
                    idx = max(0, idx - 1)
                c.put(x, y, FLAME[idx])
        for e in range(2):                                # an ember or two drifting up
            ex = cx + int(round(math.sin(2 * math.pi * (f / FIRE_N + e * 0.5)) * 2.5))
            ey = FIRE_H - FIRE_H * 3 // 4 - 1 - ((f * 2 + e * 3) % 4)
            c.put(ex, max(0, ey), hexc('ffb040', 200))
        frames.append(c.img)
    return strip(frames)


EXP_W, EXP_H, EXP_N = 20, 20, 10


def explosion_frames(size=20):
    """A distant blast: a white flash, a fireball that swells and cools, debris specks, then a dark smoke
    cloud that billows up and thins. 10 frames, played ONCE. Origin = the centre."""
    frames = []
    rng = random.Random(77)
    k = size / 20.0
    EXP_W = EXP_H = size
    blobs = [(rng.uniform(-3, 3) * k, rng.uniform(-3, 2) * k, rng.uniform(3.0, 5.0) * k) for _ in range(6)]
    debris = [(rng.uniform(0, 2 * math.pi), rng.uniform(3.5, 7.0) * k) for _ in range(9)]
    for f in range(EXP_N):
        c = Canvas(EXP_W, EXP_H, seed=f)
        cx, cy = EXP_W // 2, EXP_H // 2 + 1
        if f < 7:                                                     # the fireball
            t = f / 6.0
            grow = 0.35 + 0.65 * math.sin(min(1.0, t * 1.15) * math.pi / 2)
            best = {}
            for (bx, by, br) in blobs:
                r = br * grow * (1.0 - 0.25 * t)
                for y in range(EXP_H):
                    for x in range(EXP_W):
                        d = math.hypot(x - (cx + bx * grow), y - (cy + by * grow - t * 2))
                        if d <= r:
                            u = d / max(0.5, r)
                            heat = (1.0 - u) * (1.0 - t * 0.75)
                            idx = 0 if heat < 0.12 else 1 if heat < 0.3 else 2 if heat < 0.5 else 3 if heat < 0.72 else 4
                            best[(x, y)] = max(best.get((x, y), 0), idx)
            for (x, y), idx in best.items():
                c.px[x, y] = FLAME[idx]
            if f <= 1:                                                # the flash
                c.ellipse(cx, cy, (3 + f * 2) * k, (3 + f * 2) * k, hexc('fffbe0'))
                c.ellipse(cx, cy, (1 + f) * k, (1 + f) * k, hexc('ffffff'))
        if f >= 3:                                                    # smoke, growing and thinning
            t = (f - 3) / 6.0
            for k, (bx, by, br) in enumerate(blobs):
                r = br * (0.7 + 0.7 * t)
                px_, py_ = cx + bx * (1 + t), cy + by - (2 + t * 6) * k
                a = int(215 * (1.0 - t) ** 1.2)
                if a < 8:
                    continue
                for y in range(EXP_H):
                    for x in range(EXP_W):
                        d = math.hypot(x - px_, y - py_)
                        if d <= r and c.px[x, y][3] < 200:
                            shade_ = 0.55 + 0.25 * (1 - d / r)
                            g = int(46 * shade_ + 20)
                            c.put(x, y, (g + 10, g + 4, g, a))
        for (ang, dist) in debris:                                    # specks thrown out, falling
            if f >= 1 and f < 8:
                t = (f - 1) / 6.0
                dx = math.cos(ang) * dist * (0.5 + t)
                dy = math.sin(ang) * dist * (0.5 + t) + t * t * 6 * k
                x, y = int(round(cx + dx)), int(round(cy + dy))
                c.put(x, y, hexc('ffb44a') if f < 5 else hexc('6a3a26'))
        frames.append(c.img)
    return strip(frames)


SM_W, SM_H, SM_N = 14, 32, 10


def smoke_frames(run):
    """A rising plume: puffs born at the foot, drifting up and sideways, swelling and thinning. Loops (each
    puff's life is a fraction of the cycle, offset evenly)."""
    col = {1: (150, 152, 158), 2: (104, 82, 90), 3: (44, 40, 52)}[run]
    frames = []
    puffs = 6
    for f in range(SM_N):
        c = Canvas(SM_W, SM_H, seed=f)
        for p in range(puffs):
            life = ((f / float(SM_N)) + p / float(puffs)) % 1.0
            y = SM_H - 3 - life * (SM_H - 6)
            x = SM_W / 2.0 + math.sin(life * 4.2 + p * 1.7) * (1.0 + life * 3.2)
            r = 1.6 + life * 4.6
            a = int(200 * math.sin(min(1.0, life * 1.4) * math.pi / 2) * (1.0 - life) ** 1.1)
            for yy in range(SM_H):
                for xx in range(SM_W):
                    d = math.hypot(xx - x, yy - y)
                    if d <= r:
                        k = 0.8 + 0.25 * (1.0 - d / r)
                        c.put(xx, yy, (min(255, int(col[0] * k)), min(255, int(col[1] * k)), min(255, int(col[2] * k)), a))
        frames.append(c.img)
    return strip(frames)


def rain_frames(w, h, n, near_n, far_n, near_len, far_len, seed, slant=3):
    """A looping sheet of rain, w x h, n frames. The NEAR layer falls h/n px a frame (one full wrap over the loop),
    the FAR layer half that speed (its pattern repeats every h/2) — so the first and last frame join exactly.
    Streaks slant (wind) `slant` px across per length."""
    rng = random.Random(seed)
    near = [(rng.randrange(w), rng.randrange(h)) for _ in range(near_n)]
    far = [(rng.randrange(w), rng.randrange(h // 2)) for _ in range(far_n)]
    frames = []
    for f in range(n):
        c = Canvas(w, h, seed=f)
        for (x, y0) in far:
            for rep in (0, 1):
                y = (y0 + rep * (h // 2) + f * (h // 2) // n) % h
                for j in range(far_len):
                    a = int(120 * (0.35 + 0.65 * j / float(max(1, far_len - 1))))
                    c.put((x + (j * slant) // max(1, far_len)) % w, (y + j) % h, (126, 150, 196, a))
        for (x, y0) in near:
            y = (y0 + f * h // n) % h
            for j in range(near_len):
                t = j / float(max(1, near_len - 1))
                a = int(235 * (0.28 + 0.72 * t))
                col = (206, 222, 250) if t > 0.7 else (164, 188, 232)
                c.put((x + (j * slant) // max(1, near_len)) % w, (y + j) % h, col + (a,))
        frames.append(c.img)
    return strip(frames)


def splash_frames():
    """A raindrop's ripple on wet tile: a small ellipse that opens and fades (4 frames, 9x5)."""
    frames = []
    for f in range(4):
        c = Canvas(9, 5, seed=f)
        rx, ry = 1.2 + f * 1.05, 0.6 + f * 0.35
        a = int(210 * (1 - f / 4.0))
        for y in range(5):
            for x in range(9):
                d = ((x - 4) / rx) ** 2 + ((y - 2) / ry) ** 2
                if 0.55 <= d <= 1.15:
                    c.put(x, y, (200, 218, 244, a))
        if f == 0:
            c.put(4, 1, (235, 244, 255, 230))
            c.put(4, 0, (235, 244, 255, 150))
        frames.append(c.img)
    return strip(frames)


def main():
    os.makedirs(OUT, exist_ok=True)
    meta = {}
    sheet_rows = []
    for run in (1, 2, 3):
        row = []
        for v in range(VARIANTS):
            img, m = window_view(run, v)
            img.save(os.path.join(OUT, 'view_%d_%d.png' % (run, v)))
            meta['view_%d_%d' % (run, v)] = m
            row.append(img)
        for v in range(STAIR_VARIANTS):
            img, m = stair_view(run, v)
            img.save(os.path.join(OUT, 'stair_view_%d_%d.png' % (run, v)))
            meta['stair_view_%d_%d' % (run, v)] = m
        window_frame(run).save(os.path.join(OUT, 'window_frame_%d.png' % run))
        smoke_frames(run).save(os.path.join(OUT, 'smoke_%d.png' % run))
        sheet_rows.append((run, row))
    fire_frames().save(os.path.join(OUT, 'fire.png'))
    fire_frames(6, 8).save(os.path.join(OUT, 'fire_s.png'))
    explosion_frames(16).save(os.path.join(OUT, 'explosion.png'))
    explosion_frames(12).save(os.path.join(OUT, 'explosion_s.png'))
    # window rain: 44x52, 13 frames (near: 4px a frame; far: 2px)
    rain_frames(GLASS_W, GLASS_H, 13, 15, 10, 6, 3, seed=5, slant=3).save(os.path.join(OUT, 'rain_window.png'))
    # balcony rain: the opening, 78 tall, 13 frames (near 6px, far 3px)
    rain_frames(80, 78, 13, 28, 18, 7, 4, seed=9, slant=4).save(os.path.join(OUT, 'rain_balcony.png'))
    # stairwell rain: 72x78, 13 frames (near 6px, far 3px) — behind the stair windows' glass
    rain_frames(STAIR_RAIN_W, STAIR_H, 13, 22, 14, 7, 4, seed=13, slant=3).save(os.path.join(OUT, 'rain_stair.png'))
    splash_frames().save(os.path.join(OUT, 'splash.png'))
    meta['_sizes'] = {'glass': [GLASS_W, GLASS_H], 'frame': [FR_W, FR_H], 'frame_glass_centre': [FR_CX, FR_CY],
                      'fire': [FIRE_W, FIRE_H, FIRE_N], 'fire_s': [6, 8, FIRE_N], 'explosion': [16, 16, EXP_N], 'explosion_s': [12, 12, EXP_N], 'smoke': [SM_W, SM_H, SM_N],
                      'rain_window': [GLASS_W, GLASS_H, 13], 'rain_balcony': [80, 78, 13],
                      'rain_stair': [STAIR_RAIN_W, STAIR_H, 13], 'stair_view': [STAIR_W, STAIR_H], 'splash': [9, 5, 4],
                      'view': [VIEW_W, GLASS_H], 'pan': PAN}
    with open(os.path.join(OUT, 'city_meta.json'), 'w') as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)
    preview(sheet_rows)
    print('city: %d window views, frames, fire / explosion / smoke / rain / splash strips' % (3 * VARIANTS))


def preview(rows):
    """docs/art_reference/city/city_views.png — every view in its frame, three runs x four variants, 5x, + the strips."""
    Z = 5
    pad = 6
    cell_w, cell_h = FR_W * Z + pad, FR_H * Z + pad
    im = Image.new('RGBA', (cell_w * VARIANTS + 400, cell_h * 3 + 40), (30, 30, 34, 255))
    for ri, (run, views) in enumerate(rows):
        fr = Image.open(os.path.join(OUT, 'window_frame_%d.png' % run)).convert('RGBA')
        for vi, v in enumerate(views):
            cell = Image.new('RGBA', (FR_W, FR_H), (0, 0, 0, 0))
            cell.paste(v.crop((PAN, 0, PAN + GLASS_W, GLASS_H)), (FR_CX - GLASS_W // 2, FR_CY - GLASS_H // 2))
            # a slice of rain + fire on the night ones, so the preview shows the animation's look
            if run == 3:
                rn = Image.open(os.path.join(OUT, 'rain_window.png')).convert('RGBA').crop((3 * GLASS_W, 0, 4 * GLASS_W, GLASS_H))
                cell.alpha_composite(rn, (FR_CX - GLASS_W // 2, FR_CY - GLASS_H // 2))
            cell.alpha_composite(fr)
            big = cell.resize((FR_W * Z, FR_H * Z), Image.NEAREST)
            im.alpha_composite(big, (vi * cell_w + 4, ri * cell_h + 4))
    sx = cell_w * VARIANTS + 12
    for si, name in enumerate(('fire', 'explosion', 'smoke_3')):
        s = Image.open(os.path.join(OUT, name + '.png')).convert('RGBA')
        z = 3 if name != 'explosion' else 2
        s = s.resize((s.width * z, s.height * z), Image.NEAREST)
        if s.width > 380:
            s = s.crop((0, 0, 380, s.height))
        im.alpha_composite(s, (sx, 6 + si * 130))
    d = os.path.join(ROOT, 'docs', 'art_reference', 'city')
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, 'city_views.png'))


if __name__ == '__main__':
    main()
