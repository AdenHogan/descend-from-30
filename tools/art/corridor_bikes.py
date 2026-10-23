"""BICYCLES for the corridor — a real bike, side-on, with volume (owner round 48h: "that bicycle in the scene is very poor. It looks like it lost mass and got crushed by gravity. Can we
fix that and make it a fully realised object with the usual geometry and depth").

The old bikes were one-pixel wire drawings (a frame of 1-px lines, flat spokes) and the "wrecked" one had its front wheel flat on the floor and its frame slumped over it. A bicycle is a
set of ROUND TUBES and ROUND WHEELS: this draws them as such, in the corridor's convention (a little from above, light from the upper left, a few tones per material — see
tools/art/propkit.py):

  * proportions come from a real bike, measured in WHEEL RADII (R): wheelbase 3.2 R, chainstay 1.25 R, bottom bracket 0.2 R below the hubs, a 73 degree seat tube 1.55 R long, a 72 degree
    head tube and fork, a top tube that runs level — so every part is where it belongs and the same on every bike;
  * every tube is a shaded cylinder (`tube`): each pixel across it takes the tone of its own surface normal, so a tube has a lit top edge and a dark underside, not a line;
  * a wheel is a TYRE (a ring that is round, with a lit arc) over a bright RIM, with spokes in two tones and a hub; the far wheel, the far fork blade, the far crank and pedal are drawn first,
    two rows higher and darker — that is the depth: the other side of the bike is behind this one, seen from a little above.

Three states, one geometry (`draw_bike`): `intact`; `wrecked` — still a whole bike standing on its kickstand, but a rear tyre gone flat (the bike sags on its rim), a front wheel buckled
(a bent rim, spokes snapped), the chain off and hanging, the saddle torn and askew, the bars knocked round and a pedal gone (it is damaged, it is not collapsed: the mass is all there);
and `kid` — smaller wheels, stabilisers, a basket or streamers. Called by corridor_props.build.
"""
import math
import random

from pixlib import hexc, shade, mix
import propkit
from propkit import LX, LY, LZ, tones

TYRE = hexc('232120')
TYRE_LIT = hexc('4c4846')
TYRE_FAR = hexc('141211')
RIM = hexc('c4c6cc')
RIM_DK = hexc('7e8088')
SPOKE_LT = hexc('868892')
SPOKE_DK = hexc('585a64')
STEEL = hexc('a8abb2')
DARK_STEEL = hexc('50525a')
FORK = hexc('34363e')
RUBBER = hexc('26221f')
SADDLE = hexc('3a302a')
FRAMES = [hexc('b83a32'), hexc('2e5a8a'), hexc('3a6a3a'), hexc('40424c'), hexc('c8a032')]   # the old list, with the near-black lifted so it reads on a dark wall
FRAMES_WRECKED = [hexc('b83a32'), hexc('2e5a8a'), hexc('3a6a3a'), hexc('c8a032')]
KID_FRAMES = [hexc('d84a8a'), hexc('3a9ac8'), hexc('e0a020')]
FAR_UP = 1                                  # how many rows higher the far side of the bike stands (seen from a little above): the tyre's width, the bike's depth


# ------------------------------------------------------------------------------------------------------------------------------------ primitives
def _put(c, x, y, col):
    c.put(int(math.floor(x)), int(math.floor(y)), col)


def tube(c, p0, p1, w, col, n=5, lo=0.38, hi=1.12):
    """A round tube from p0 to p1, `w` px thick: every pixel across it takes the tone of its own surface normal (light from the upper left), so it has a lit edge and a dark underside."""
    (x0, y0), (x1, y1) = p0, p1
    L = math.hypot(x1 - x0, y1 - y0)
    if L < 1e-6:
        return
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny = -uy, ux
    tn = tones(col, n, lo, hi)
    steps = int(L * 3) + 1
    for i in range(steps + 1):
        t = i / float(steps)
        px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for k in range(w):
            off = k - (w - 1) / 2.0
            o = max(-0.95, min(0.95, off / (w / 2.0)))                       # -1 .. 1 across the tube
            lam = max(0.0, o * (nx * LX + ny * LY) + math.sqrt(1.0 - o * o) * LZ)
            col_k = tn[int(max(0.0, min(0.999, 0.10 + 0.95 * lam)) * len(tn))]
            _put(c, px + nx * off + 0.5, py + ny * off + 0.5, col_k)


def disc(c, cx, cy, r, col, n=5):
    """A small lit ball (a hub, a bolt, a bell): the sphere of propkit at pixel scale."""
    propkit.sphere(c, cx, cy, r, r, col, n=n)


def _ang(dx, dy):
    return math.atan2(dy, dx)


def _gauss(a, mu, sig):
    d = (a - mu + math.pi) % (2 * math.pi) - math.pi
    return math.exp(-(d * d) / (2 * sig * sig))


# ------------------------------------------------------------------------------------------------------------------------------------ wheels
def wheel(c, cx, cy, R, far=False, squash=0.0, buckle=0.0, buckle_at=0.0, spokes=14, snapped=(), phase=0.0, tyre_w=2.3, narrow=0.0):
    """One wheel seen side-on: a TYRE (a ring, lit on its upper-left arc) over a bright RIM, spokes in two tones, a hub. `far` = the wheel on the other side of the bike (a dark ring only).
    squash > 0 flattens the tyre (it is down: wider than tall, the rim near the ground); buckle > 0 bends the rim in at `buckle_at` radians and out opposite, and `narrow` pinches the wheel in
    from the sides (a buckled, folded wheel)."""
    rx_t, ry_t = R + 0.25 + 0.5 * squash - narrow, R + 0.25 - 1.0 * squash          # the tyre's outer radii
    x0, x1 = int(math.floor(cx - rx_t - 2)), int(math.ceil(cx + rx_t + 2))
    y0, y1 = int(math.floor(cy - ry_t - 2)), int(math.ceil(cy + ry_t + 2))

    def bend(a):
        return buckle * (_gauss(a, buckle_at, 0.55) * -1.0 + 0.55 * _gauss(a, buckle_at + math.pi, 0.7))

    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            a = _ang(dx, dy)
            b = bend(a)
            ex, ey = rx_t + b, ry_t + b
            q = math.hypot(dx / ex, dy / ey)                                       # 1.0 on the tyre's outer edge
            r = q * (R + b)
            if q > 1.0:
                continue
            ring = (R + b) - r                                                    # distance in from the tyre's outer edge, px
            if far:
                if ring <= tyre_w - 0.5:
                    _put(c, x, y, TYRE_FAR)
                continue
            if ring <= tyre_w:
                lit = _ang(dx, dy)                                                 # the upper-left arc catches the light
                up_left = math.cos(lit - math.radians(225.0))
                col = TYRE_LIT if (up_left > 0.78 and ring <= 1.1) else TYRE
                _put(c, x, y, col)
            elif ring <= tyre_w + 1.05:                                            # the rim
                up_left = math.cos(a - math.radians(225.0))
                _put(c, x, y, RIM if up_left > -0.1 else RIM_DK)
    if far:
        return
    # spokes: two tones, crossing — the near-side lacing lighter, the far-side darker
    rim_r = R - tyre_w - 1.0
    for k in range(spokes):
        a = phase + k * 2 * math.pi / spokes
        if k in snapped:
            continue
        col = SPOKE_LT if k % 2 == 0 else SPOKE_DK
        b = bend(a)
        r_end = rim_r + b * 0.9
        ex, ey = cx + math.cos(a + (0.16 if k % 2 == 0 else -0.16)) * r_end, cy + math.sin(a + (0.16 if k % 2 == 0 else -0.16)) * r_end * (ry_t / rx_t)
        c.line(int(round(cx)), int(round(cy)), int(round(ex)), int(round(ey)), col)
    disc(c, cx, cy, 1.9, STEEL)
    _put(c, cx - 0.5, cy - 0.5, hexc('eef0f4'))


# ------------------------------------------------------------------------------------------------------------------------------------ the bike
def draw_bike(c, C, rx, R, frame, state='intact', kid=False, extra=None, seed=1, stabilisers=False):
    """Draw a whole bicycle on canvas `c` with its wheels' lowest row on row `C`: rear hub at pixel column `rx`, wheel radius `R` (the bike scales with it).
    state 'intact' | 'wrecked'. extra: None | 'basket' | 'rack' | 'bell'."""
    rng = random.Random(seed)
    wrecked = state == 'wrecked'
    cy = C + 1.0 - R                                                     # the hubs: tyre bottom on row C
    sag = 2.0 if wrecked else 0.0                                        # a flat rear tyre: the whole back of the bike sits lower
    hy_r = cy + sag
    wb = 3.2 * R
    fx = rx + wb
    # frame points, in wheel radii off the hubs (a real bike's proportions)
    bb = (rx + 1.22 * R, hy_r + 0.20 * R)
    seat_dir = (-math.cos(math.radians(73.0)), -math.sin(math.radians(73.0)))
    st = (bb[0] + seat_dir[0] * 1.55 * R, bb[1] + seat_dir[1] * 1.55 * R)            # the seat-tube / top-tube lug
    head_dir = (-math.cos(math.radians(72.0)), -math.sin(math.radians(72.0)))
    crown = (fx + head_dir[0] * 1.10 * R, cy + head_dir[1] * 1.10 * R)               # the fork crown = the head tube's foot
    ht = (crown[0] + head_dir[0] * 0.42 * R, crown[1] + head_dir[1] * 0.42 * R)      # the head tube's top
    tt_w = 2 if kid else 3
    dt_w = 3
    st_w = 2 if kid else 3
    stay_w = 2

    far = lambda p: (p[0], p[1] - FAR_UP)

    # ---------------------------------------------------------------- the far side first (behind, two rows up, darker): wheels, fork blade, stays, crank and pedal
    wheel(c, fx, cy - FAR_UP, R, far=True, **(dict(buckle=1.8, buckle_at=math.radians(-40.0), narrow=2.0) if wrecked else {}))
    wheel(c, rx, hy_r - FAR_UP, R, far=True, squash=1.5 if wrecked else 0.0)
    fr_dark = shade(frame, 0.55)
    tube(c, far(bb), far((rx, hy_r)), stay_w, fr_dark, n=3)
    tube(c, far(st), far((rx, hy_r)), stay_w, fr_dark, n=3)
    tube(c, far(crown), far((fx, cy)), stay_w, shade(FORK, 0.8), n=3)
    crank = 0.5 * R
    ca = math.radians(100.0 if not wrecked else 118.0)                       # the near crank points down and a little forward
    near_pedal = (bb[0] + math.cos(ca) * crank, bb[1] + math.sin(ca) * crank)
    far_pedal = (bb[0] - math.cos(ca) * crank, bb[1] - math.sin(ca) * crank - FAR_UP)
    tube(c, far(bb), far_pedal, 1, shade(DARK_STEEL, 0.7), n=3)
    if not wrecked:                                                          # (a wrecked bike has lost its far pedal)
        c.rect(int(far_pedal[0]) - 2, int(far_pedal[1]), int(far_pedal[0]) + 1, int(far_pedal[1]) + 1, shade(RUBBER, 0.8))

    # ---------------------------------------------------------------- the near side
    # chain stays + seat stays (behind the wheel's spokes? they hold the hub, so drawn over it), then the wheels' spokes under the tubes
    rear_args = dict(squash=1.5 if wrecked else 0.0, spokes=14 if not kid else 12, phase=0.3)
    front_args = dict(spokes=14 if not kid else 12, phase=0.1)
    if wrecked:
        front_args.update(buckle=1.8, buckle_at=math.radians(-40.0), snapped=(3, 10), narrow=2.0)
    wheel(c, rx, hy_r, R, **rear_args)
    wheel(c, fx, cy, R, **front_args)
    if stabilisers:                                                          # training wheels: one each side of the rear wheel, on struts from its hub
        sx, sy = rx + 0.5, C - 1.2
        c.line(int(rx), int(hy_r - FAR_UP), int(sx), int(sy - FAR_UP), shade(DARK_STEEL, 0.7))
        propkit.sphere(c, sx, sy - FAR_UP, 2.0, 2.0, shade(RUBBER, 1.0), n=3, lo=0.5, hi=1.2)
        c.line(int(rx), int(hy_r), int(sx), int(sy), DARK_STEEL)
        propkit.sphere(c, sx, sy, 2.2, 2.2, RUBBER, n=4, lo=0.5, hi=1.5)
        _put(c, sx, sy, STEEL)
    if wrecked:                                                              # a few snapped spokes standing out of the buckled rim
        for (a, ln) in ((math.radians(-60), 3.2), (math.radians(150), 2.4)):
            sx, sy = fx + math.cos(a) * (R - 3.2), cy + math.sin(a) * (R - 3.2)
            c.line(int(round(sx)), int(round(sy)), int(round(sx + math.cos(a) * ln)), int(round(sy + math.sin(a) * ln)), SPOKE_LT)

    # mudguard-less rear: a rack or reflector on the seat stay
    if extra == 'rack':
        top = (rx - 1.0, hy_r - R * 0.95)
        tube(c, (rx - 2.2, top[1]), (rx + 0.35 * R, top[1] - 0.5), 1, DARK_STEEL, n=3)
        tube(c, (rx, hy_r), (rx - 0.3, top[1]), 1, DARK_STEEL, n=3)
    # frame
    tube(c, bb, (rx, hy_r), stay_w, frame)                                   # chain stay
    tube(c, (st[0] + 0.3, st[1] + 0.2 * R), (rx, hy_r), stay_w, frame)       # seat stay
    tube(c, bb, st, st_w, frame)                                             # seat tube
    tube(c, bb, crown, dt_w, shade(frame, 0.92))                            # down tube
    tube(c, st, ht, tt_w, frame)                                             # top tube
    tube(c, crown, ht, 3 if not kid else 2, shade(frame, 1.05))              # head tube
    # fork (near blade) — dark steel, with the front hub in its dropouts
    fork_col = FORK if not kid else shade(frame, 0.8)
    tube(c, crown, (fx, cy), 2, fork_col, n=4, lo=0.8, hi=1.4)
    # the chain, chainring, cog, derailleur
    ring_r = 0.40 * R
    if not wrecked:
        cog = (rx, hy_r)
        top_a, top_b = (bb[0], bb[1] - ring_r), (cog[0], cog[1] - 1.9)
        bot_a, bot_b = (bb[0], bb[1] + ring_r), (cog[0], cog[1] + 1.9)
        c.line(int(top_a[0]), int(top_a[1]), int(top_b[0]), int(top_b[1]), DARK_STEEL)
        c.line(int(bot_a[0]), int(bot_a[1]), int(bot_b[0]), int(bot_b[1]), DARK_STEEL)
        for t in (0.25, 0.5, 0.75):                                          # a lighter link now and then
            _put(c, top_a[0] + (top_b[0] - top_a[0]) * t, top_a[1] + (top_b[1] - top_a[1]) * t, STEEL)
    for a in range(0, 360, 12):                                                                                    # the chainring: a ring (it is open — the frame shows through) …
        ang = math.radians(a)
        _put(c, bb[0] + math.cos(ang) * (ring_r + 0.2), bb[1] + math.sin(ang) * (ring_r + 0.2), DARK_STEEL if 30 < a < 210 else STEEL)
    for a in (35, 125, 215, 305):                                                                                  # … on its spider …
        ang = math.radians(a)
        c.line(int(bb[0]), int(bb[1]), int(round(bb[0] + math.cos(ang) * (ring_r - 0.6))), int(round(bb[1] + math.sin(ang) * (ring_r - 0.6))), DARK_STEEL)
    propkit.sphere(c, bb[0], bb[1], 1.5, 1.5, STEEL, n=4)                                                         # … round the crank's boss
    if wrecked:                                                              # the chain has come off: hanging from the ring in a loop to the floor
        px, py = bb[0] + 1.0, bb[1] + ring_r
        n_drop = int(C - py)
        for k in range(n_drop + 1):                                          # the chain drops off the ring to the floor …
            _put(c, px + (1 if k % 3 == 1 else 0) + 0.5, py + k + 0.5, DARK_STEEL if k % 2 == 0 else STEEL)
        for k in range(1, 6):                                                # … and lies in a loose pile
            _put(c, px + k + 0.5, C - (1 if k % 2 else 0) + 0.5, DARK_STEEL if k % 2 else STEEL)
    else:
        c.vline(int(rx), int(hy_r) + 2, int(hy_r) + 4, FORK)                                       # the rear derailleur and its pulley
        _put(c, rx + 1, hy_r + 4.5, DARK_STEEL)
    # near crank arm + pedal (the wrecked bike has lost this pedal's body: just the stub)
    tube(c, bb, near_pedal, 2, STEEL, n=4)
    px, py = near_pedal
    if not wrecked:
        c.rect(int(px) - 2, int(py), int(px) + 1, int(py) + 1, RUBBER)
        c.hline(int(px) - 2, int(px) + 1, int(py), shade(RUBBER, 1.6))
    else:
        c.rect(int(px), int(py), int(px), int(py) + 1, RUBBER)
    # kickstand: from the chain stay down to the ground, a little behind the bottom bracket
    ks_top = (bb[0] - 0.55 * R, bb[1] + 0.35 * R)
    tube(c, ks_top, (ks_top[0] - 2.6, C), 1, DARK_STEEL, n=3)
    c.hline(int(ks_top[0] - 3.6), int(ks_top[0] - 1.6), C, shade(DARK_STEEL, 0.8))
    # seat post + saddle
    sp = (st[0] + seat_dir[0] * 0.30 * R, st[1] + seat_dir[1] * 0.30 * R)
    tube(c, st, sp, 1, STEEL, n=4)
    saddle(c, sp, R, torn=wrecked, askew=wrecked, kid=kid)
    # stem, bars, grip, brake lever (the wrecked bike's bars are knocked round, hanging down)
    stem_top = (ht[0] - 0.05 * R, ht[1] - 0.26 * R)
    tube(c, ht, stem_top, 1, STEEL, n=4)
    if not wrecked:
        grip = (stem_top[0] - 0.48 * R, stem_top[1] - 0.10 * R)
        tube(c, stem_top, (stem_top[0] - 0.22 * R, stem_top[1] - 0.20 * R), 1, STEEL, n=4)
        tube(c, (stem_top[0] - 0.22 * R, stem_top[1] - 0.20 * R), grip, 1, STEEL, n=4)
        tube(c, (grip[0] - 0.1, grip[1] + 0.2), (grip[0] - 0.45 * R, grip[1] + 0.45), 2, RUBBER, n=4)                      # the grip
        c.line(int(grip[0]), int(grip[1] + 1), int(grip[0] + 0.55 * R), int(grip[1] + 2.5), STEEL)                          # the brake lever, forward of it
        if kid:                                                                                                              # streamers from the grip end
            for k, col in enumerate((hexc('e84a8a'), hexc('4ac8e8'), hexc('f0d040'))):
                c.line(int(grip[0] - 0.45 * R), int(grip[1] + 0.8 + k * 0.6), int(grip[0] - 0.45 * R) - 3 - k, int(grip[1] + 1.8 + k), col)
        if extra in ('bell', 'basket') or rng.random() < 0.5:
            disc(c, stem_top[0] - 0.10 * R, stem_top[1] - 1.3, 1.1, hexc('d8c070'))                                          # a bell
    else:                                                                                                                     # knocked round: the bar swings down to the near side
        bx, by = stem_top
        tube(c, (bx, by), (bx + 0.45 * R, by + 0.55 * R), 1, STEEL, n=4)
        tube(c, (bx + 0.45 * R, by + 0.55 * R), (bx + 0.30 * R, by + 1.15 * R), 2, RUBBER, n=4)
        c.line(int(bx + 0.45 * R), int(by + 0.55 * R), int(bx + 0.05 * R), int(by + 1.25 * R), STEEL)                       # the brake lever hanging loose
    if extra == 'basket' and not wrecked:
        basket(c, stem_top, R)
    if extra == 'rack' and not wrecked:
        bag(c, (rx - 1.0, hy_r - R * 0.95), R, rng)
    # a rear reflector + a front lamp, the little things that make it a real bike
    _put(c, rx - 0.3 * R, hy_r - 0.85 * R, hexc('d03030'))
    _put(c, rx - 0.3 * R + 1, hy_r - 0.85 * R, hexc('f06060'))
    if not wrecked:                                                          # the headlamp, clamped to the fork's crown, facing forward
        c.rect(int(crown[0]) + 1, int(crown[1]) - 1, int(crown[0]) + 2, int(crown[1]), hexc('ece6c4'))
        _put(c, crown[0] + 3, crown[1] - 0.5, hexc('fff8dc'))
    # tyre contact shadows
    c.shadow(rx, C + 1.2, R * 0.85, 1.1, 120)
    c.shadow(fx, C + 1.2, R * 0.85, 1.1, 120)
    return {'bb': bb, 'st': st, 'ht': ht, 'fx': fx, 'cy': cy}


def saddle(c, sp, R, torn=False, askew=False, kid=False):
    """A saddle with volume: a wide rear, a narrow nose, a lit top, a dark underside; torn = the cover ripped open with the foam showing, tilted nose-down."""
    x, y = sp
    ln = max(5.0, 0.62 * R)
    tilt = 1.3 if askew else 0.0                                              # nose down
    body = SADDLE
    tn = tones(body, 5, 0.5, 1.5)
    for i in range(int(ln) + 1):
        f = i / max(1.0, ln)                                                  # 0 rear .. 1 nose
        px = x - ln * 0.42 + i
        thick = 2.6 - 1.4 * f
        top = y - 1.6 + tilt * f * 1.4 + (0.0 if i else 0.4)
        for k in range(int(round(thick)) + 1):
            col = tn[min(4, 3 - k)] if k < 3 else tn[0]
            _put(c, px + 0.5, top + k + 0.5, col)
        _put(c, px + 0.5, top + 0.5, tn[4])                                   # the lit top edge
    if torn:
        for (i, col) in ((1, hexc('c8b070')), (2, hexc('9a8650')), (3, hexc('c8b070'))):
            _put(c, x - ln * 0.42 + i + 0.5, y - 1.6 + 1.0 + 0.5, col)       # the foam showing through the rip


def basket(c, stem_top, R):
    """A wicker basket on the bars: a woven front, a rim, a lit top face."""
    bx, by = stem_top[0] + 0.2 * R, stem_top[1] + 0.2
    w, h = int(round(0.9 * R)), int(round(0.55 * R))
    col = hexc('a47a42')
    c.rect(int(bx), int(by), int(bx) + w, int(by) + h, shade(col, 0.9))
    for yy in range(int(by) + 1, int(by) + h):
        for xx in range(int(bx) + 1, int(bx) + w):
            if (xx + yy) % 2 == 0:
                _put(c, xx, yy, shade(col, 0.7))
    c.hline(int(bx), int(bx) + w, int(by), shade(col, 1.4))
    c.hline(int(bx), int(bx) + w, int(by) + h, shade(col, 0.55))
    c.vline(int(bx), int(by), int(by) + h, shade(col, 1.15))
    c.vline(int(bx) + w, int(by), int(by) + h, shade(col, 0.6))


def bag(c, top, R, rng):
    """A pannier-bag strapped on a rear rack: a rounded sack with a flap and a strap."""
    x, y = top
    col = rng.choice([hexc('3a5a7a'), hexc('7a3a3a'), hexc('4a6a46')])
    w, h = 7, 5
    c.rect(int(x) - 1, int(y) - h, int(x) - 1 + w, int(y) - 1, col)
    c.hline(int(x) - 1, int(x) - 1 + w, int(y) - h, shade(col, 1.4))
    c.vline(int(x) - 1, int(y) - h, int(y) - 1, shade(col, 1.15))
    c.vline(int(x) - 1 + w, int(y) - h, int(y) - 1, shade(col, 0.6))
    c.hline(int(x), int(x) + w - 2, int(y) - h + 1, shade(col, 0.7))        # the flap's edge
    c.rect(int(x) + 1, int(y) - h + 1, int(x) + 2, int(y) - 1, shade(col, 0.8))   # a strap
