"""BICYCLES for the corridor — a real bike, side-on, with weight and volume (owner round 48h: "that bicycle in the scene is very poor. It looks like it lost mass and got crushed by gravity. Can we
fix that and make it a fully realised object with the usual geometry and depth"; then, of the first redraw, "the bike still needs work").

The old bikes were one-pixel wire drawings and the "wrecked" one had its front wheel flat on the floor and its frame slumped over it. The first redraw had the right geometry but still read as
WIRE at game zoom, for three reasons found by looking at it in the lit corridor, at night, at 3.4x: (1) its tyres were near-black, so on a dark wall they vanished and only the thin rim + spokes
showed; (2) the wrecked bike's wheels were SQUASHED (a flat tyre drawn as a squashed ring, a folded front wheel) — the "crushed" look again; (3) the frame tubes were thin. So now:

  * a wheel is a THICK mid-grey TYRE (3 px, lit on its upper-left arc, dark on its lower right — it reads on a dark wall) over a two-ring RIM (bright outer, dark inner), 12-14 spokes, a hub with a
    nut. EVERY wheel is round, in every state; the far wheel stands behind it, one row higher, darker — the tyre's width and the bike's depth;
  * adult bikes carry MUDGUARDS (a lit arc over each wheel on stays) — the solid shapes a bike has over its wheels, so the wheels are not just rings — and the tubes are fat: a 4 px down tube, 3 px
    top / seat tubes and head tube, 3 px chainstays, a 3 px fork;
  * proportions still come from a real bike in WHEEL RADII (R): wheelbase 3.2 R, chainstay 1.25 R, bottom bracket 0.2 R below the hubs, a 73 degree seat tube 1.55 R long, a 72 degree head tube and
    fork, a level top tube; every tube is a shaded cylinder (`tube`: each pixel across it takes the tone of its own surface normal);
  * WRECKED = still a whole bike with all its mass, standing on its kickstand: the rear tyre FLAT (the wheel is round but sits 1.5 px low, its tread cut flat on the floor — it is down on the rim),
    the front wheel out of true (a slight egg, a kink in the rim, spokes snapped and standing out), a mudguard hanging off, the chain off and lying on the floor, the saddle torn and askew, the bars
    knocked round and a pedal gone.

Sprite sizes and floor contacts are fixed by the corridor (the wall between two door frames is ~74 px, and corridor_decals.gd's seeded placement reads the sprite size): 64 x 39 adult, 66 x 37
wrecked, 46 x 29 kid's. Called by corridor_props.build.
"""
import math
import random

from pixlib import hexc, shade, mix
import propkit
from propkit import LX, LY, LZ, tones

TYRE_DK = hexc('2a2826')                    # a tyre's shaded side (lower right)
TYRE = hexc('46423f')                       # … its body: a mid grey-brown, not black, so it holds on a dark wall
TYRE_LIT = hexc('7c7772')                   # … and the arc the light catches
TYRE_FAR = hexc('201e1c')
RIM = hexc('d0d2d8')
RIM_DK = hexc('868890')
RIM_IN = hexc('4e5058')                     # the rim's inner ring
SPOKE_LT = hexc('a4a6ae')
SPOKE_DK = hexc('6a6c76')
STEEL = hexc('b0b3ba')
DARK_STEEL = hexc('585a62')
FORK = hexc('3a3c44')
RUBBER = hexc('2c2824')
SADDLE = hexc('443830')
FRAMES = [hexc('b83a32'), hexc('2e5a8a'), hexc('3a6a3a'), hexc('40424c'), hexc('c8a032')]   # the old list, with the near-black lifted so it reads on a dark wall
FRAMES_WRECKED = [hexc('b83a32'), hexc('2e5a8a'), hexc('3a6a3a'), hexc('c8a032')]
KID_FRAMES = [hexc('d84a8a'), hexc('3a9ac8'), hexc('e0a020')]
FAR_UP = 1                                  # how many rows higher the far side of the bike stands (seen from a little above): the tyre's width, the bike's depth


# ------------------------------------------------------------------------------------------------------------------------------------ primitives
def _put(c, x, y, col):
    c.put(int(math.floor(x)), int(math.floor(y)), col)


def tube(c, p0, p1, w, col, n=5, lo=0.42, hi=1.22, cap=0.0):
    """A straight tube from p0 to p1, EXACTLY `w` px thick (a pixel is in when its centre is within w/2 of the centre line — so a diagonal tube is as thick as a level one, never stair-stepped
    into a wedge): a lit edge on the side that faces the light (upper left), a dark edge on the other, a flat body between. `cap` pushes both ends out a little (to tuck under a joint)."""
    (x0, y0), (x1, y1) = p0, p1
    L = math.hypot(x1 - x0, y1 - y0)
    if L < 1e-6:
        return
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny = -uy, ux
    if nx * LX + ny * LY < 0.0:                                              # make +n the side that faces the light
        nx, ny = -nx, -ny
    tn = tones(col, 5, lo, hi)
    hw = w / 2.0 + 1e-6
    for y in range(int(math.floor(min(y0, y1) - w - 1)), int(math.ceil(max(y0, y1) + w + 1))):
        for x in range(int(math.floor(min(x0, x1) - w - 1)), int(math.ceil(max(x0, x1) + w + 1))):
            dx, dy = x + 0.5 - x0, y + 0.5 - y0
            t = dx * ux + dy * uy
            o = dx * nx + dy * ny                                            # + toward the light
            if t < -cap - 0.5 or t > L + cap + 0.5 or abs(o) > hw:
                continue
            u = o / hw
            if w <= 1:
                k = 3
            elif u > 0.34:
                k = 4                                                        # the lit edge
            elif u > -0.34:
                k = 3 if w >= 3 else 2
            else:
                k = 1                                                        # the shaded edge
            if w >= 4 and -0.34 <= u <= 0.34:
                k = 3 if u > 0.0 else 2
            _put(c, x, y, tn[k])


def disc(c, cx, cy, r, col, n=5):
    """A small lit ball (a hub, a bolt, a bell): the sphere of propkit at pixel scale."""
    propkit.sphere(c, cx, cy, r, r, col, n=n)


def _gauss(a, mu, sig):
    d = (a - mu + math.pi) % (2 * math.pi) - math.pi
    return math.exp(-(d * d) / (2 * sig * sig))


def _in_arc(deg, a0, a1):
    """True when `deg` (0..360, 0 = right, 90 = down, 270 = up) lies in the arc a0 .. a1 (a0 < a1, both in 0..360)."""
    return a0 <= deg <= a1


# ------------------------------------------------------------------------------------------------------------------------------------ wheels
def wheel(c, cx, cy, R, far=False, flat=0.0, out_of_true=0.0, kink_at=0.0, spokes=14, snapped=(), phase=0.0, tyre_w=3.0, floor=None):
    """One wheel seen side-on, ALWAYS round: a thick TYRE (grey-brown, lit on its upper-left arc, dark on its lower right) over a two-ring RIM (bright outer, dark inner), spokes in two tones and a hub.
    `far` = the wheel on the other side of the bike (a dark ring only). `flat` > 0 cuts the tread flat on row `floor` (a flat tyre: the wheel is lowered by the caller and sits on its rim);
    `out_of_true` bends the rim a little (a slight egg + a kink at `kink_at` radians) — never a squash."""
    x0, x1 = int(math.floor(cx - R - 3)), int(math.ceil(cx + R + 3))
    y0, y1 = int(math.floor(cy - R - 3)), int(math.ceil(cy + R + 3))

    def wob(a):
        return out_of_true * (0.55 * math.sin(2 * a + 0.6) - 0.9 * _gauss(a, kink_at, 0.32))

    for y in range(y0, y1 + 1):
        if floor is not None and y > floor:
            continue
        for x in range(x0, x1 + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            ro = R + 0.25 + wob(a)                                                 # the tyre's outer edge at this angle
            ring = ro - r                                                          # px in from the outer edge
            if ring < 0.0:
                continue
            if far:
                if ring <= tyre_w - 0.5:
                    _put(c, x, y, TYRE_FAR)
                continue
            lam = math.cos(a - math.radians(225.0))                                # +1 = facing the light
            if ring <= tyre_w:
                if lam > 0.55 and ring <= 1.6:
                    col = TYRE_LIT
                elif lam < -0.35 or ring > tyre_w - 0.8 and lam < 0.2:
                    col = TYRE_DK
                else:
                    col = TYRE
                _put(c, x, y, col)
            elif ring <= tyre_w + 1.05:                                            # the rim's bright outer ring
                _put(c, x, y, RIM if lam > -0.25 else RIM_DK)
            elif ring <= tyre_w + 2.0:                                             # … and its dark inner ring: the rim has a thickness
                _put(c, x, y, RIM_IN)
    if far:
        return
    # spokes: two tones, crossing
    rim_r = R - tyre_w - 1.6
    for k in range(spokes):
        if k in snapped:
            continue
        a = phase + k * 2 * math.pi / spokes
        col = SPOKE_LT if k % 2 == 0 else SPOKE_DK
        sk = 0.16 if k % 2 == 0 else -0.16
        r_end = rim_r + wob(a + sk) * 0.5
        c.line(int(round(cx)), int(round(cy)), int(round(cx + math.cos(a + sk) * r_end)), int(round(cy + math.sin(a + sk) * r_end)), col)
    disc(c, cx, cy, 2.1, STEEL)
    _put(c, cx - 0.5, cy - 0.5, hexc('f2f4f8'))


def fender(c, cx, cy, R, a0, a1, col, width=2.0, gap=0.9):
    """A mudguard: a lit arc standing `gap` px off the tyre between screen angles a0 .. a1 (degrees, 270 = straight up), `width` px thick."""
    tn = tones(col, 5, 0.45, 1.25)
    r_in = R + gap
    r_out = r_in + width
    for y in range(int(cy - r_out - 2), int(cy + r_out + 3)):
        for x in range(int(cx - r_out - 2), int(cx + r_out + 3)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r < r_in or r > r_out:
                continue
            deg = math.degrees(math.atan2(dy, dx)) % 360.0
            if not _in_arc(deg, a0, a1):
                continue
            a = math.radians(deg)
            side = (r - r_in) / max(width, 0.1)                                   # 0 inner .. 1 outer: the outer face catches the light
            lam = 0.55 * math.cos(a - math.radians(225.0)) + 0.45 * side
            _put(c, x, y, tn[int(max(0.0, min(0.999, 0.5 + 0.5 * lam)) * 5)])


# ------------------------------------------------------------------------------------------------------------------------------------ the bike
def draw_bike(c, C, rx, R, frame, state='intact', kid=False, extra=None, seed=1, stabilisers=False):
    """Draw a whole bicycle on canvas `c` with its wheels' lowest row on row `C`: rear hub at pixel column `rx`, wheel radius `R` (the bike scales with it).
    state 'intact' | 'wrecked'. extra: None | 'basket' | 'rack' | 'bell'."""
    rng = random.Random(seed)
    wrecked = state == 'wrecked'
    cy = C + 1.0 - R                                                     # the hubs: tyre bottom on row C
    sag = 1.5 if wrecked else 0.0                                        # a FLAT rear tyre: the (round) wheel sits lower, its tread cut flat on the floor
    hy_r = cy + sag
    wb = 3.2 * R
    fx = rx + wb
    big = not kid
    # frame points, in wheel radii off the hubs (a real bike's proportions)
    bb = (rx + 1.22 * R, hy_r + 0.20 * R)
    seat_dir = (-math.cos(math.radians(73.0)), -math.sin(math.radians(73.0)))
    st = (bb[0] + seat_dir[0] * 1.55 * R, bb[1] + seat_dir[1] * 1.55 * R)            # the seat-tube / top-tube lug
    head_dir = (-math.cos(math.radians(72.0)), -math.sin(math.radians(72.0)))
    crown = (fx + head_dir[0] * 1.10 * R, cy + head_dir[1] * 1.10 * R)               # the fork crown = the head tube's foot
    ht = (crown[0] + head_dir[0] * 0.42 * R, crown[1] + head_dir[1] * 0.42 * R)      # the head tube's top
    tt_w, dt_w, st_w, cs_w, ss_w, hd_w, fk_w = (3, 3, 3, 2, 2, 4, 3) if big else (2, 2, 2, 2, 2, 3, 2)
    tyre_w = 3.0 if big else 2.3
    n_spokes = 14 if big else 12

    far = lambda p: (p[0], p[1] - FAR_UP)

    # ---------------------------------------------------------------- the far side first (behind, a row up, darker): wheels, fork blade, stays, crank and pedal
    wheel(c, fx, cy - FAR_UP, R, far=True, tyre_w=tyre_w, out_of_true=0.8 if wrecked else 0.0, kink_at=math.radians(-40.0))
    wheel(c, rx, hy_r - FAR_UP, R, far=True, tyre_w=tyre_w, floor=C)
    fr_dark = shade(frame, 0.55)
    tube(c, far(bb), far((rx, hy_r)), cs_w, fr_dark, n=3)
    tube(c, far(st), far((rx, hy_r)), ss_w, fr_dark, n=3)
    tube(c, far(crown), far((fx, cy)), fk_w, shade(FORK, 0.8), n=3)
    crank = 0.5 * R
    ca = math.radians(62.0 if not wrecked else 80.0)                         # the near crank points down and FORWARD (a real bike's crank at 4 o'clock)
    near_pedal = (bb[0] + math.cos(ca) * crank, bb[1] + math.sin(ca) * crank)
    far_pedal = (bb[0] - math.cos(ca) * crank, bb[1] - math.sin(ca) * crank - FAR_UP)
    tube(c, far(bb), far_pedal, 1, shade(DARK_STEEL, 0.7), n=3)
    if not wrecked:                                                          # (a wrecked bike has lost its far pedal)
        c.rect(int(far_pedal[0]) - 3, int(far_pedal[1]), int(far_pedal[0]) + 2, int(far_pedal[1]) + 1, shade(RUBBER, 0.8))

    # ---------------------------------------------------------------- the near side: wheels first (the frame is bolted on over them)
    wheel(c, rx, hy_r, R, flat=sag, spokes=n_spokes, phase=0.3, tyre_w=tyre_w, floor=C)
    front_args = dict(spokes=n_spokes, phase=0.1, tyre_w=tyre_w)
    if wrecked:
        front_args.update(out_of_true=0.8, kink_at=math.radians(-40.0), snapped=(3, 4, 10))
    wheel(c, fx, cy, R, **front_args)
    if stabilisers:                                                          # training wheels: one each side of the rear wheel, on struts from its hub
        sx, sy = rx + 0.5, C - 1.2
        c.line(int(rx), int(hy_r - FAR_UP), int(sx), int(sy - FAR_UP), shade(DARK_STEEL, 0.7))
        propkit.sphere(c, sx, sy - FAR_UP, 2.0, 2.0, shade(RUBBER, 1.0), n=3, lo=0.5, hi=1.2)
        c.line(int(rx), int(hy_r), int(sx), int(sy), DARK_STEEL)
        propkit.sphere(c, sx, sy, 2.2, 2.2, TYRE, n=4, lo=0.5, hi=1.5)
        _put(c, sx, sy, STEEL)
    if wrecked:                                                              # snapped spokes standing out of the bent rim
        for (a, ln) in ((math.radians(-62), 3.4), (math.radians(-35), 2.6), (math.radians(150), 2.4)):
            sx, sy = fx + math.cos(a) * (R - tyre_w - 1.8), cy + math.sin(a) * (R - tyre_w - 1.8)
            c.line(int(round(sx)), int(round(sy)), int(round(sx + math.cos(a) * ln)), int(round(sy + math.sin(a) * ln)), SPOKE_LT)

    # mudguards: a lit arc over each wheel, on a stay to the hub (adult bikes; the wrecked one's front guard has been torn half off)
    fcol = shade(frame, 0.85) if frame != hexc('40424c') else hexc('5a5e6a')
    if big:
        fender(c, rx, hy_r, R, 202.0, 332.0, fcol)
        c.line(int(rx), int(hy_r), int(rx - 1), int(hy_r - R - 1), DARK_STEEL)
        if not wrecked:
            fender(c, fx, cy, R, 212.0, 346.0, fcol)
            c.line(int(fx), int(cy), int(fx + 3), int(cy - R - 1), DARK_STEEL)
        else:                                                                # hanging off, bent down over the front tyre
            fender(c, fx, cy, R, 212.0, 290.0, fcol)
            c.line(int(fx + 1), int(cy - R - 2), int(fx + 6), int(cy - R + 2), shade(fcol, 0.8))
            c.line(int(fx + 1), int(cy - R - 1), int(fx + 6), int(cy - R + 3), fcol)

    # rear rack
    if extra == 'rack':
        top = (rx - 1.0, hy_r - R * 1.18)
        tube(c, (rx - 4.0, top[1]), (rx + 0.30 * R, top[1] - 0.5), 1, DARK_STEEL, n=3)
        tube(c, (rx - 1.0, hy_r), (rx - 2.0, top[1]), 1, DARK_STEEL, n=3)
    # frame
    tube(c, bb, (rx, hy_r), cs_w, frame)                                     # chain stay
    tube(c, (st[0] + 0.3, st[1] + 0.2 * R), (rx, hy_r), ss_w, frame)         # seat stay
    tube(c, bb, st, st_w, frame)                                             # seat tube
    tube(c, bb, crown, dt_w, shade(frame, 0.92))                            # down tube
    tube(c, st, ht, tt_w, frame)                                             # top tube
    tube(c, crown, ht, hd_w, shade(frame, 0.78), cap=0.6)                    # head tube: a short fat tube of its own, darker than the others, so the three tubes do not melt into one
    for q, wq in ((ht, 5 if big else 4), (crown, 5 if big else 4)):         # headset cups: a lit ring at each end
        c.hline(int(q[0] - wq / 2.0 + 0.5), int(q[0] + wq / 2.0 - 0.5), int(q[1]), STEEL)
    # fork (near blade) — dark steel, with the front hub in its dropouts
    fork_col = FORK if not kid else shade(frame, 0.8)
    tube(c, crown, (fx, cy), fk_w, fork_col, n=4, lo=0.55, hi=1.25)
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
    propkit.sphere(c, bb[0], bb[1], ring_r - 1.0, ring_r - 1.0, shade(DARK_STEEL, 0.85), n=3, lo=0.6, hi=1.0)       # the chainring: a small dark disc …
    for a in range(0, 360, 8):                                                                                     # … with a lit toothed rim
        ang = math.radians(a)
        _put(c, bb[0] + math.cos(ang) * (ring_r + 0.2), bb[1] + math.sin(ang) * (ring_r + 0.2), DARK_STEEL if 30 < a < 210 else STEEL)
    for a in (35, 125, 215, 305):                                                                                  # … on its spider …
        ang = math.radians(a)
        c.line(int(bb[0]), int(bb[1]), int(round(bb[0] + math.cos(ang) * (ring_r - 0.6))), int(round(bb[1] + math.sin(ang) * (ring_r - 0.6))), DARK_STEEL)
    propkit.sphere(c, bb[0], bb[1], 1.6, 1.6, STEEL, n=4)                                                         # … round the crank's boss
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
    tube(c, bb, near_pedal, 2, STEEL, n=4, lo=0.55, hi=1.1)
    px, py = near_pedal
    if not wrecked:                                                          # the pedal: a flat block across the crank's end, lit on top
        c.rect(int(px) - 2, int(py), int(px) + 3, int(py) + 1, RUBBER)
        c.hline(int(px) - 2, int(px) + 3, int(py), shade(RUBBER, 1.45))
    else:
        c.rect(int(px), int(py), int(px), int(py) + 1, RUBBER)
    # kickstand: from the chain stay down to the ground, a little behind the bottom bracket
    ks_top = (bb[0] - 0.55 * R, bb[1] + 0.35 * R)
    tube(c, ks_top, (ks_top[0] - 2.6, C), 1, DARK_STEEL, n=3)
    c.hline(int(ks_top[0] - 3.6), int(ks_top[0] - 1.6), C, shade(DARK_STEEL, 0.8))
    # seat post + saddle
    sp = (st[0] + seat_dir[0] * 0.30 * R, st[1] + seat_dir[1] * 0.30 * R)
    tube(c, st, sp, 2 if big else 1, STEEL, n=4)
    saddle(c, sp, R, torn=wrecked, askew=wrecked, kid=kid)
    # stem + handlebars: SEPARATE dark parts (the old ones were the head tube's own pale steel and melted into it). A stem rises along the head tube's axis to a clamp; a swept-back bar
    # runs from it to a rubber grip (a wrecked bike's bars have been knocked right round, so they sweep FORWARD over the front wheel); the brake lever hangs under the grip; a bell on the bar.
    sw = 1.0 if wrecked else -1.0
    clamp = (ht[0] + head_dir[0] * 0.55 * R, ht[1] + head_dir[1] * 0.55 * R)
    tube(c, ht, clamp, 2, DARK_STEEL, n=4, lo=0.6, hi=1.35)
    elbow = (clamp[0] + sw * 0.28 * R, clamp[1] - 0.14 * R)
    gstart = (elbow[0] + sw * 0.30 * R, elbow[1] + 0.12 * R)
    gend = (gstart[0] + sw * 0.46 * R, gstart[1] + 0.14 * R)
    tube(c, clamp, elbow, 2, FORK, n=4, lo=0.7, hi=1.5)
    tube(c, elbow, gstart, 2, FORK, n=4, lo=0.7, hi=1.5)
    tube(c, gstart, gend, 3 if big else 2, RUBBER, n=5, lo=0.75, hi=1.45)     # the grip: black rubber with a dull lit edge (not white)
    c.line(int(gstart[0]), int(gstart[1]) + 2, int(gstart[0] - sw * 0.50 * R), int(gstart[1]) + 3, STEEL)   # the brake lever, hanging under the grip toward the rider
    if not wrecked:                                                          # (the wrecked bike's bell has been knocked off)
        disc(c, clamp[0] - sw * 0.05 * R, clamp[1] - 1.6, 1.3, hexc('d8c070'))    # a bell
    if extra == 'basket' and not wrecked:
        basket(c, (ht[0] - 0.1 * R, ht[1] - 0.35 * R), R)
    if extra == 'rack' and not wrecked:
        bag(c, (rx - 2.0, hy_r - R * 1.18), R, rng)
    # a rear reflector + a front lamp, the little things that make it a real bike
    if big:                                                                  # on the rear mudguard's tail, where a real one is bolted
        ang = math.radians(209.0)
        qx, qy = rx + math.cos(ang) * (R + 1.9), hy_r + math.sin(ang) * (R + 1.9)
    else:                                                                    # a kid's bike has no mudguard: on the seat stay
        qx, qy = rx - 1.0, hy_r - 0.7 * R
    c.rect(int(qx) - 1, int(qy) - 1, int(qx), int(qy), hexc('d03030'))
    _put(c, qx - 1, qy - 1, hexc('f07070'))
    if not wrecked and extra != 'basket':                                    # the headlamp, clamped to the fork's crown, facing forward (a basket sits there)
        c.rect(int(crown[0]) + 1, int(crown[1]) - 1, int(crown[0]) + 3, int(crown[1]) + 1, hexc('3a3c44'))
        c.rect(int(crown[0]) + 2, int(crown[1]) - 1, int(crown[0]) + 3, int(crown[1]), hexc('ece6c4'))
        _put(c, crown[0] + 3, crown[1] - 1, hexc('fff8dc'))
    # tyre contact shadows
    c.shadow(rx, C + 1.2, R * 0.9, 1.2, 130)
    c.shadow(fx, C + 1.2, R * 0.9, 1.2, 130)
    return {'bb': bb, 'st': st, 'ht': ht, 'fx': fx, 'cy': cy}


def saddle(c, sp, R, torn=False, askew=False, kid=False):
    """A saddle with volume: a wide rear, a narrow nose, a lit top, a dark underside; torn = the cover ripped open with the foam showing, tilted nose-down."""
    x, y = sp
    ln = max(6.0, 0.70 * R)
    tilt = 1.4 if askew else 0.0                                              # nose down
    tn = tones(SADDLE, 5, 0.5, 1.6)
    for i in range(int(ln) + 1):
        f = i / max(1.0, ln)                                                  # 0 rear .. 1 nose
        px = x - ln * 0.42 + i
        thick = 3.4 - 1.8 * f
        top = y - 2.0 + tilt * f * 1.4 + (0.0 if i else 0.4)
        for k in range(int(round(thick)) + 1):
            col = tn[min(4, 3 - k)] if k < 3 else tn[0]
            _put(c, px + 0.5, top + k + 0.5, col)
        _put(c, px + 0.5, top + 0.5, tn[4])                                   # the lit top edge
    if torn:
        for (i, col) in ((1, hexc('c8b070')), (2, hexc('9a8650')), (3, hexc('c8b070'))):
            _put(c, x - ln * 0.42 + i + 0.5, y - 2.0 + 1.0 + 0.5, col)       # the foam showing through the rip


def basket(c, stem_top, R):
    """A wicker basket on the bars: a woven front, a rim, a lit top face."""
    bx, by = stem_top[0] + 0.2 * R, stem_top[1] + 0.2
    w, h = int(round(0.95 * R)), int(round(0.62 * R))
    col = hexc('b08648')
    c.rect(int(bx), int(by), int(bx) + w, int(by) + h, shade(col, 0.9))
    for yy in range(int(by) + 1, int(by) + h):
        for xx in range(int(bx) + 1, int(bx) + w):
            if (xx + yy) % 2 == 0:
                _put(c, xx, yy, shade(col, 0.7))
    c.hline(int(bx), int(bx) + w, int(by), shade(col, 1.45))
    c.hline(int(bx), int(bx) + w, int(by) + 1, shade(col, 1.15))
    c.hline(int(bx), int(bx) + w, int(by) + h, shade(col, 0.55))
    c.vline(int(bx), int(by), int(by) + h, shade(col, 1.15))
    c.vline(int(bx) + w, int(by), int(by) + h, shade(col, 0.6))


def bag(c, top, R, rng):
    """A plastic crate lashed on the rear rack: a rim, vertical slots, a lit top edge and a dark side."""
    x, y = top
    col = rng.choice([hexc('3a5a7a'), hexc('7a3a3a'), hexc('4a6a46')])
    w, h = 8, 6
    x0, x1, y0, y1 = int(x) - 1, int(x) - 1 + w, int(y) - h, int(y) - 1
    c.rect(x0, y0, x1, y1, col)
    for xx in range(x0 + 2, x1 - 1, 2):                                      # the slots
        c.vline(xx, y0 + 2, y1 - 1, shade(col, 0.5))
    c.hline(x0, x1, y0, shade(col, 1.5))                                     # the lit rim
    c.hline(x0, x1, y0 + 1, shade(col, 1.15))
    c.hline(x0, x1, y1, shade(col, 0.6))
    c.vline(x0, y0, y1, shade(col, 1.2))
    c.vline(x1, y0, y1, shade(col, 0.6))
