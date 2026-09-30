"""THE LOBBY EXIT (owner round 29 — "rework the lobby exit to look good with art and depth, just like the balcony:
the player walks UP into it, then the white fade"; the old one was a flat blue slab).

A grand entrance set into the lobby wall, drawn like the balcony's loggia: a stone surround with an arched opening,
a vestibule behind it (side reveals, a marble floor that runs back and up, a soffit) and, at the back, the way OUT —
a second opening onto the street where the city stands in glare. The doors are flung open against the reveals,
their glass broken; three marble steps lead up to a brass threshold (the player walks UP these, feet going from the
lane to the vestibule, shrinking with distance — scripts/lobby_exit.gd / player.walk_up_and_out). Boards, a fallen
chair, a dropped suitcase and papers say what happened here. Three run looks (morning / afternoon / night: the light
outside, the glass, the debris).

TWO sprites per run so the outside stays bright in the night-dark world (the same rule as the window views):
  assets/lobby/exit_frame_<run>.png   lit: the surround, vestibule, steps, doors, debris. The back opening is a
                                      TRANSPARENT hole.
  assets/lobby/exit_view_<run>.png    UNSHADED (scripts/lobby_exit_fx.gd): the street seen through that hole.
  assets/lobby/exit_meta.json         where everything sits (frame size, seam, hole box, step rows, beam origin).

Frame canvas 128 x 160, origin = world (FRAME_X, FRAME_Y) in scenes/lobby.tscn; its y = SEAM is the wall/floor seam
(world 403); rows below it are the steps + floor in front of the door (they end at world ~418, the lane's edge).
Run:  python3 tools/art/lobby_exit.py     (also writes docs/art_reference/lobby_exit.png)
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
import cityscape  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'lobby')
PREV = os.path.join(ROOT, 'docs', 'art_reference')

W, H = 128, 160
SEAM = 128                       # the wall/floor seam (world 403)
# the FRONT opening (the arch the lobby sees) and the BACK opening (onto the street), frame-local
FL, FR = 30, 98                  # front opening x
F_TOP = 32                       # front arch crown
F_SPRING = 54                    # where the arch springs from straight jambs
BL, BR = 40, 88                  # back opening x
B_TOP = 50                       # back crown
B_SPRING = 62
B_BOT = 112                      # where the vestibule floor ends at the back (floor rows B_BOT..SEAM)
STEP_ROWS = [(SEAM + 1, 3, 2), (SEAM + 6, 3, 3), (SEAM + 11, 3, 4)]   # (tread y, tread h, riser h)

STONE = hexc('c9bfa8')
STONE_L = hexc('e2d9c2')
STONE_D = hexc('8c836f')
STONE_DD = hexc('5c5446')
BRASS = hexc('b58f4a')
BRASS_D = hexc('6d5228')
MARBLE_A = hexc('d8d2c4')
MARBLE_B = hexc('6a645c')

LOOKS = {
    1: dict(name='morning', glare=hexc('f6fbff'), spill=(255, 252, 240), side=hexc('7d7768'), glass=hexc('bfd4dc'),
            dark=1.0, broken=0, debris=2),
    2: dict(name='afternoon', glare=hexc('ffe6c4'), spill=(255, 214, 160), side=hexc('6e6152'), glass=hexc('e0c0a6'),
            dark=0.92, broken=2, debris=3),
    3: dict(name='night', glare=hexc('a9b9e0'), spill=(150, 170, 220), side=hexc('3c3a40'), glass=hexc('6f7fa6'),
            dark=0.8, broken=4, debris=5),
}


def in_arch(x, y, l, r, top, spring):
    """Inside an opening with straight jambs from `spring` down and a segmental arch above it."""
    if x < l or x > r or y < top:
        return False
    if y >= spring:
        return True
    rise = spring - top
    half = (r - l) / 2.0
    cx = (l + r) / 2.0
    # an ellipse arc: at y, half-width = half * sqrt(1 - ((spring - y)/rise)^2)
    t = (spring - y) / float(max(1, rise))
    return abs(x - cx) <= half * math.sqrt(max(0.0, 1.0 - t * t)) + 0.5


def lerp(a, b, t):
    return a + (b - a) * t


def frame(run, seed=29):
    L = LOOKS[run]
    rng = random.Random(seed + run)
    c = Canvas(W, H, seed=seed + run)
    k = L['dark']

    def tone(col, f=1.0):
        return shade(col, f * k) if f * k <= 1.0 else shade(col, f * k)

    # ---- 1. the stone surround: pilasters, plinths, entablature, a keystone arch over the opening
    # wall plate behind everything (a little wider than the surround so it sits into the wall)
    c.rect(10, 12, 117, SEAM - 1, STONE)
    for y in range(12, SEAM):                                  # cut-stone courses
        if (y - 12) % 8 == 0:
            c.hline(10, 117, y, STONE_D)
    for row, y in enumerate(range(12, SEAM, 8)):
        off = 0 if row % 2 == 0 else 7
        for x in range(10 + off, 118, 14):
            c.vline(x, y, min(SEAM - 1, y + 7), STONE_D)
    # light from the left: left edges lit, right edges shaded
    c.vline(10, 12, SEAM - 1, STONE_L)
    c.vline(117, 12, SEAM - 1, STONE_D)
    # the cornice
    c.rect(6, 6, 121, 11, STONE_L)
    c.hline(6, 121, 6, STONE_D)
    c.hline(6, 121, 11, STONE_DD)
    c.rect(8, 12, 119, 13, STONE_DD)
    for x in range(10, 118, 6):                                # dentils
        c.rect(x, 14, x + 2, 16, STONE_D)
    c.rect(4, 0, 123, 5, shade(STONE, 1.08))
    c.hline(4, 123, 0, STONE_D)
    c.hline(4, 123, 5, STONE_DD)
    # pilasters
    for x0 in (13, 99):
        c.rect(x0, 18, x0 + 15, SEAM - 1, shade(STONE, 1.06))
        c.vline(x0, 18, SEAM - 1, STONE_L)
        c.vline(x0 + 15, 18, SEAM - 1, STONE_D)
        for y in range(20, SEAM - 8, 4):                       # fluting
            pass
        for fx in (x0 + 4, x0 + 8, x0 + 12):
            c.vline(fx, 24, SEAM - 10, STONE_D)
            c.vline(fx + 1, 24, SEAM - 10, STONE_L)
        c.rect(x0 - 2, 18, x0 + 17, 21, STONE_L)               # capital
        c.hline(x0 - 2, x0 + 17, 21, STONE_DD)
        c.rect(x0 - 2, SEAM - 9, x0 + 17, SEAM - 1, STONE_D)   # plinth
        c.hline(x0 - 2, x0 + 17, SEAM - 9, STONE_L)
    # keystone + a small brass plaque over the arch
    c.rect(60, 22, 68, 33, shade(STONE, 1.12))
    c.vline(60, 22, 33, STONE_D)
    c.vline(68, 22, 33, STONE_DD)
    c.rect(44, 15, 83, 20, BRASS_D)
    c.hline(44, 83, 15, BRASS)
    for x in range(47, 81, 3):
        c.put(x, 17, BRASS)                                    # engraved lettering, too small to read
        c.put(x + 1, 18, BRASS)

    # ---- 2. the opening: clear it, then build the vestibule inside
    for y in range(F_TOP - 4, SEAM):
        for x in range(FL - 3, FR + 4):
            if in_arch(x, y, FL - 2, FR + 2, F_TOP - 3, F_SPRING):
                c.px[x, y] = (0, 0, 0, 0)
    # the moulded architrave round the arch (a stone band, lit on its upper-left)
    for y in range(F_TOP - 6, SEAM):
        for x in range(FL - 6, FR + 7):
            inside_o = in_arch(x, y, FL - 2, FR + 2, F_TOP - 3, F_SPRING)
            inside_m = in_arch(x, y, FL - 6, FR + 6, F_TOP - 7, F_SPRING)
            if inside_m and not inside_o:
                edge_in = not in_arch(x, y, FL - 4, FR + 4, F_TOP - 5, F_SPRING)
                c.px[x, y] = STONE_L if edge_in else shade(STONE, 1.0 if x < 64 else 0.9)
    # vestibule shell: side reveals (left lit from the street, right in shade), soffit, floor
    def front_in(x, y):
        return in_arch(x, y, FL, FR, F_TOP, F_SPRING)

    def back_in(x, y):
        return in_arch(x, y, BL, BR, B_TOP, B_SPRING)

    # paint every pixel of the front opening that is NOT the back opening as "reveal" (walls / soffit / floor)
    for y in range(F_TOP, SEAM):
        for x in range(FL, FR + 1):
            if not front_in(x, y):
                continue
            if back_in(x, y):
                c.px[x, y] = (0, 0, 0, 0)           # the hole onto the street
                continue
            # which part of the shell is this? the floor is the trapezoid under the back opening's floor line
            # to the front threshold; above it the reveal walls + soffit
            fy = (y - B_BOT) / float(max(1, SEAM - B_BOT))
            if y >= B_BOT and BL - (BL - FL) * fy <= x <= BR + (FR - BR) * fy:
                # FLOOR: checker receding to the back, lit from the street (brighter toward the back)
                depth = 1.0 - fy                                  # 1 at the back, 0 at the threshold
                u = (x - lerp(FL, BL, depth)) / max(1.0, lerp(FR, BR, depth) - lerp(FL, BL, depth))
                cell = int(u * (5 + depth * 0) * 2.0)
                row = int(fy * 3.0)
                col = MARBLE_A if (cell + row) % 2 == 0 else MARBLE_B
                glow = 0.55 + 0.6 * depth
                c.px[x, y] = tuple(min(255, int(col[i] * glow * (0.8 + 0.2 * k))) for i in range(3)) + (255,)
                continue
            left = x < 64
            if y < B_SPRING and abs(x - 64) < (FR - FL) / 2.0 and not left:
                pass
            # soffit (above the back opening) vs side reveals
            above = (y < B_TOP + 2) or (y < B_SPRING and not back_in(x, y) and abs(x - 64) < 22)
            if above and y < B_SPRING:
                c.px[x, y] = shade(STONE_DD, 0.85 * k)
            else:
                base = L['side']
                # the reveal darkens toward the front, brightens toward the light at the back
                dist_back = min(abs(x - BL), abs(x - BR)) / float(max(1, BL - FL))
                f = 1.15 - 0.55 * min(1.0, dist_back)
                if not left:
                    f *= 0.78
                c.px[x, y] = tuple(min(255, int(base[i] * f)) for i in range(3)) + (255,)
    # panelled reveal lines (stone panels on the side walls) in perspective
    for side, x_front, x_back in (('l', FL, BL), ('r', FR, BR)):
        for frac in (0.0, 0.34, 0.66, 1.0):
            x = int(round(lerp(x_front, x_back, frac)))
            c.vline(x, int(lerp(F_SPRING, B_SPRING, frac)) + 2, int(lerp(SEAM - 1, B_BOT, frac)), shade(L['side'], 0.6))
    # soffit coffer line
    for x in range(BL + 2, BR - 1):
        if (x - BL) % 8 == 0:
            c.vline(x, B_TOP - 5 if False else B_TOP - 3, B_TOP + 1, shade(STONE_DD, 0.7))
    # the light spilling in: a bright rim round the back opening, strongest at the top and on the floor
    for y in range(B_TOP - 4, B_BOT + 1):
        for x in range(BL - 4, BR + 5):
            if back_in(x, y) or not front_in(x, y):
                continue
            if any(back_in(x + dx, y + dy) for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2)):
                px = c.px[x, y]
                if px[3] == 255:
                    c.px[x, y] = mix(px, L['glare'], 0.42)

    # ---- 3. the doors: flung open against the reveals (foreshortened leaves), glass broken
    for side in ('l', 'r'):
        x_front, x_back = (FL + 1, BL - 1) if side == 'l' else (FR - 1, BR + 1)
        sgn = 1 if side == 'l' else -1
        # a leaf is a quad: front edge full height, back edge shorter (perspective)
        yt_f, yb_f = F_SPRING + 4, SEAM - 2
        yt_b, yb_b = B_SPRING + 3, B_BOT + 1
        leaf_dark = hexc('3a2c20')
        c.poly([(x_front, yt_f), (x_back, yt_b), (x_back, yb_b), (x_front, yb_f)], leaf_dark)
        # panes (three stacked glazed panels)
        n = 3
        for i in range(n):
            a0, a1 = (i + 0.12) / n, (i + 0.88) / n
            def pt(xf, t):
                return (xf, lerp(lerp(yt_f, yb_f, t), lerp(yt_b, yb_b, t), (xf - x_front) / float(x_back - x_front) if x_back != x_front else 0))
            xs = (x_front + sgn * 1, x_back - sgn * 1)
            quad = [(xs[0], lerp(yt_f, yb_f, a0)), (xs[1], lerp(yt_b, yb_b, a0)),
                    (xs[1], lerp(yt_b, yb_b, a1)), (xs[0], lerp(yt_f, yb_f, a1))]
            c.poly(quad, L['glass'])
    # glass broken: dark gaps / spiderwebs in the panes on the later looks
    for _ in range(LOOKS[run]['broken']):
        side = rng.choice(('l', 'r'))
        x = (FL + 3 if side == 'l' else FR - 4) + rng.randrange(-1, 2)
        y = rng.randrange(F_SPRING + 8, SEAM - 14)
        for j in range(rng.randrange(3, 7)):
            c.put(x + rng.randrange(-2, 3), y + j, hexc('18141a'))
    # ---- 4. the floor in front: a marble landing + three steps up to a brass threshold
    # the lobby floor itself is the lobby art; the steps are this sprite's rows below the seam
    c.rect(FL - 6, SEAM - 3, FR + 6, SEAM - 2, BRASS)          # brass sill
    c.hline(FL - 6, FR + 6, SEAM - 3, shade(BRASS, 1.25))
    c.hline(FL - 6, FR + 6, SEAM - 1, BRASS_D)
    for i, (ty, th, rh) in enumerate(STEP_ROWS):
        ext = 5 + i * 5                                       # each step steps out a little further
        x0, x1 = FL - ext, FR + ext
        # tread (lit top), then riser (shaded front)
        for y in range(ty, ty + th):
            for x in range(x0, x1 + 1):
                cell = ((x - x0) // 8 + i) % 2
                col = MARBLE_A if cell == 0 else hexc('c4beb0')
                c.put(x, y, tone(col, 1.0 if y == ty else 0.96))
        c.hline(x0, x1, ty, tone(hexc('f2eee2'), 1.0))        # the lip catches the light
        for y in range(ty + th, ty + th + rh):
            for x in range(x0, x1 + 1):
                c.put(x, y, tone(hexc('8c867a'), 0.92 if y == ty + th else 0.72))
        c.vline(x0, ty, ty + th + rh - 1, tone(hexc('f2eee2'), 1.0))
        c.vline(x1, ty, ty + th + rh - 1, tone(hexc('5a554c'), 1.0))
    bot = STEP_ROWS[-1][0] + STEP_ROWS[-1][1] + STEP_ROWS[-1][2]
    # a soft contact shadow under the lowest step
    for y in range(bot, bot + 4):
        a = 70 - (y - bot) * 18
        for x in range(FL - 18, FR + 19):
            c.put(x, y, (20, 14, 12, max(0, a)))

    # ---- 5. what happened here: boards nailed across the left pilaster's foot, a fallen chair, a suitcase, papers
    n_debris = L['debris']
    # boards leaning on the left wall
    for i in range(min(3, n_debris)):
        x0 = 12 + i * 4
        c.poly([(x0, SEAM - 2), (x0 + 3, SEAM - 2), (x0 + 13 + i, 70 + i * 9), (x0 + 10 + i, 70 + i * 9)], hexc('7a5a3a') if i % 2 == 0 else hexc('5e4530'))
        c.line(x0 + 1, SEAM - 2, x0 + 11 + i, 71 + i * 9, hexc('9a7a52'))
    # a fallen bentwood chair lying on the steps' left flank
    if n_debris >= 2:
        cx, cy = 14, SEAM + 10
        c.rect(cx, cy, cx + 14, cy + 2, hexc('4a3426'))               # the seat edge-on
        c.rect(cx + 2, cy + 3, cx + 3, cy + 9, hexc('4a3426'))        # legs up-and-out
        c.rect(cx + 11, cy + 3, cx + 12, cy + 8, hexc('4a3426'))
        c.line(cx + 14, cy + 1, cx + 22, cy - 6, hexc('4a3426'))       # the back
        c.line(cx + 15, cy + 2, cx + 23, cy - 5, hexc('6a4c36'))
    # a dropped suitcase on the right
    if n_debris >= 3:
        sx, sy = 104, SEAM + 9
        c.box(sx, sy, sx + 13, sy + 8, hexc('6b4a36'), hexc('2e2016'))
        c.rect(sx + 5, sy - 2, sx + 8, sy, hexc('2e2016'))              # handle
        c.hline(sx + 1, sx + 12, sy + 4, hexc('3a2a1e'))
        c.put(sx + 6, sy + 4, BRASS)
        c.put(sx + 2, sy + 4, BRASS)
    # papers in the light
    for _ in range(3 + n_debris * 2):
        x = rng.randrange(FL + 6, FR - 4)
        y = rng.randrange(SEAM + 1, bot + 10)
        c.rect(x, y, x + rng.randrange(2, 5), y + 1, hexc('e8e3d2') if rng.random() < 0.8 else hexc('d9c690'))
    if run >= 2:                                              # broken glass fanned out from the threshold
        for _ in range(9 + run * 6):
            x = rng.randrange(FL - 10, FR + 11)
            y = rng.randrange(SEAM + 2, bot + 6)
            c.put(x, y, hexc('dfe9ee'))
            if rng.random() < 0.4:
                c.put(x + 1, y, hexc('a7b7c2'))
    if run == 3:                                              # blood: a long smear dragged up the steps
        for t in range(18):
            x = 70 + int(math.sin(t * 0.5) * 3)
            y = SEAM + 12 - t
            c.rect(x, y, x + 1, y, hexc('4a0d0c'))
        c.rect(74, SEAM + 13, 78, SEAM + 14, hexc('4a0d0c'))
        for yy in range(F_SPRING + 20, SEAM - 10):            # a handprint on the left reveal
            pass
    return c


def view(run, seed=29):
    """The street seen through the back opening — UNSHADED (the game never darkens it)."""
    L = LOOKS[run]
    bw, bh = BR - BL + 1, B_BOT - B_TOP + 1
    c = Canvas(bw, bh, seed=seed + run)
    rng = random.Random(seed * 3 + run)
    cityscape.draw_city(c, (0, 0, bw - 1, bh - 1 - 12), run, rng, layout_seed=7, tall=1.0)
    # the street: kerb, road, a lamp post, a parked wreck
    road = {1: hexc('6f7379'), 2: hexc('5a4a52'), 3: hexc('161822')}[run]
    kerb = {1: hexc('a9a9a0'), 2: hexc('8f7f7b'), 3: hexc('2a2c38')}[run]
    c.rect(0, bh - 12, bw - 1, bh - 1, road)
    c.rect(0, bh - 12, bw - 1, bh - 11, kerb)
    for x in range(0, bw, 9):
        c.rect(x, bh - 5, x + 4, bh - 5, shade(road, 1.5))
    # a lamp post and a burnt-out car silhouette
    post = shade(road, 0.55)
    c.rect(bw - 12, bh - 40, bw - 11, bh - 12, post)
    c.rect(bw - 15, bh - 41, bw - 10, bh - 40, post)
    if run == 3:
        c.rect(bw - 16, bh - 39, bw - 14, bh - 38, hexc('ffd9a0'))
    c.rect(6, bh - 18, 27, bh - 13, shade(road, 0.5))
    c.rect(10, bh - 22, 22, bh - 18, shade(road, 0.5))
    c.rect(11, bh - 21, 14, bh - 19, shade(L['glare'], 0.55))
    # the glare: the light pours in from the top-middle, blowing the scene out toward the centre
    for y in range(bh):
        for x in range(bw):
            d = math.hypot((x - bw * 0.5) / (bw * 0.55), (y - bh * 0.30) / (bh * 0.62))
            g = max(0.0, 1.0 - d) ** 1.6 * (0.78 if run == 1 else 0.62 if run == 2 else 0.42)
            if g > 0.01:
                px = c.px[x, y]
                c.px[x, y] = mix(px, L['glare'], g)
    # clip to the back opening's arched shape
    for y in range(bh):
        for x in range(bw):
            if not in_arch(x + BL, y + B_TOP, BL, BR, B_TOP, B_SPRING):
                c.px[x, y] = (0, 0, 0, 0)
    return c


def compose(run, lobby_bg):
    fr = frame(run)
    vw = view(run)
    img = lobby_bg.copy()
    # the view sits BEHIND the frame (the frame has a hole)
    img.alpha_composite(vw.img, (BL, B_TOP))
    img.alpha_composite(fr.img, (0, 0))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PREV, exist_ok=True)
    meta = {'frame': [W, H], 'seam': SEAM, 'front': [FL, FR, F_TOP, F_SPRING], 'back': [BL, BR, B_TOP, B_SPRING, B_BOT],
            'steps': [list(s) for s in STEP_ROWS], 'beam_origin': [64, B_TOP + 6]}
    sheet = Image.new('RGBA', (W * 3 + 8, H), (20, 20, 24, 255))
    lobby = Image.open(os.path.join(ROOT, 'assets', 'corridor', 'corridor_lobby.png')).convert('RGBA')
    for run in (1, 2, 3):
        fr = frame(run)
        fr.img.save(os.path.join(OUT, 'exit_frame_%d.png' % run))
        vw = view(run)
        vw.img.save(os.path.join(OUT, 'exit_view_%d.png' % run))
        # preview over the real lobby wall: door centred at lobby x 540 (art-local of world 654)
        bg = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        crop = lobby.crop((540 - W // 2, 275 - 243, 540 + W // 2, 275 - 243 + H))
        bg.alpha_composite(crop)
        sheet.alpha_composite(compose(run, bg), ((run - 1) * (W + 4), 0))
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(os.path.join(PREV, 'lobby_exit.png'))
    with open(os.path.join(OUT, 'exit_meta.json'), 'w') as f:
        json.dump(meta, f, indent=1)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
