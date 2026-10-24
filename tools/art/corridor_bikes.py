"""BICYCLES for the corridor — plain, clean, readable at a glance (owner round 48h, third pass: "it should immediately present as a bicycle. Considering this is the first thing players will
see, it needs to look correct, logical, clean and frankly not look like AI").

What went wrong in the first two redraws, found by looking at them next to the title's wall: they were rendered like 3D objects (every tube a shaded cylinder sampled at sub-pixel positions, a far-side
copy of each wheel stood one row up and darker, a chainring + spider + derailleur + kickstand + bell + lever all packed into a few pixels). The result was true to a bicycle's geometry and still read as
a smear of grey — "machine made". A pixel artist would not draw it that way. So now:

  * ONE crisp convention for every part: tubes are 2 px (the down tube 3) with ONE lit row / column on the upper-left edge and the body tone under it — no gradients, no dither, no sub-pixel anything;
    every point is an integer, every line a clean Bresenham run;
  * a wheel is a pixel-centre ring test (exactly round, exactly the same on both ends of the bike): a 2 px tyre (a lit arc upper-left, a darker one lower-right), a 1 px bright rim, 8 thin spokes on the
    45-degree grid (so every spoke is a perfectly straight run) and a hub; the SAME wheel at both ends. No far-side copy, no mudguards;
  * the parts a child would name and no others: two wheels, a diamond frame, a fork, a saddle on a post, a stem and swept-back bars with a grip, a chainring + chain, a crank and a pedal, a rear
    reflector, a headlamp. (A rack + a crate, or a basket, on the variants that carry one.) No bell, lever, derailleur or kickstand — at this size they were noise;
  * the proportions are still a real bike's, in wheel radii (R): wheelbase 3.2 R, chainstay 1.25 R, a level top tube, a 73-degree seat tube, a 73-degree fork, the bottom bracket a little below the
    hubs. There is NO damaged version: a bicycle stands where someone left it, in every run (the old "wrecked" sprites — a flat tyre, a buckled wheel, chain off — read as the same melted look the
    owner objected to, and are gone).

Sprite sizes and floor contacts are fixed by the corridor (the wall between two door frames is ~74 px and corridor_decals.gd's seeded placement reads the sprite size): 64 x 39 adult, 46 x 29 kid's.
Called by corridor_props.bike.
"""
import math

from pixlib import hexc, shade, mix

TYRE = hexc('34312f')
TYRE_LIT = hexc('6a6560')                    # the arc the light (upper left) catches
TYRE_DK = hexc('1e1c1b')                     # the lower-right arc
RIM = hexc('d2d5dc')
RIM_DK = hexc('8e929c')
SPOKE = hexc('a2a6b0')
SPOKE_DK = hexc('6c707a')
HUB = hexc('e4e7ee')
HUB_DK = hexc('7c808a')
STEEL = hexc('b6bac2')
STEEL_DK = hexc('6a6e78')
CHAIN = hexc('3e4048')
FORK = hexc('4a4d57')
FORK_LIT = hexc('7a7e8a')
RUBBER = hexc('26231f')
RUBBER_LIT = hexc('6e675f')                  # a lit top edge that reads on a dark wall
SADDLE = hexc('2c2522')
SADDLE_LIT = hexc('9a8672')
LAMP = hexc('f2e8b8')
REFLECTOR = hexc('d23a32')
REFLECTOR_LIT = hexc('f08a80')
WICKER = hexc('b88e50')

FRAMES = [hexc('c0453a'), hexc('3a72b0'), hexc('3f8a4c'), hexc('d6a838'), hexc('5a5f6e')]   # red, blue, green, mustard, slate — each reads against the brown wainscot
KID_FRAMES = [hexc('e0568f'), hexc('46a8d6'), hexc('e6a82a')]

# a real adult bike, in pixels at wheel radius 11, measured from the rear hub (x right) and level with the hubs (y down). Scaled by R / 11 for the kid's.
WHEELBASE = 35
BB = (14, 2)                                  # bottom bracket: 1.25 R from the rear hub, a little below the hubs
SEAT_TOP = (9, -15)                           # the seat-tube / top-tube lug (the top tube is level)
HEAD_TOP = (30, -15)                          # the head tube's top (WHEELBASE - 5)
HEAD_FOOT = (32, -10)                         # the fork crown / head tube's foot (WHEELBASE - 3)


# ------------------------------------------------------------------------------------------------------------------------------------ primitives
def _ramp(col):
    """Three tones of one colour: the lit edge, the body, the shaded edge."""
    return mix(col, (255, 255, 255, 255), 0.34), col, shade(col, 0.66)


def _run(x0, y0, x1, y1):
    """The pixels of a straight line, end to end (Bresenham)."""
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            return pts
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def tube(c, p0, p1, w, col):
    """A straight tube `w` px thick: the run of the centre line, stacked w px thick across it (down a level-ish run, across a steep one); ONE lit pixel on the upper-left edge,
    the body tone under it (and, on a 3 px tube, a shaded edge)."""
    (x0, y0), (x1, y1) = (int(round(p0[0])), int(round(p0[1]))), (int(round(p1[0])), int(round(p1[1])))
    lit, body, dk = _ramp(col)
    tones = [lit, body] if w == 2 else [lit, body, dk] if w == 3 else [body]
    flat = abs(x1 - x0) >= abs(y1 - y0)
    for (x, y) in _run(x0, y0, x1, y1):
        for k, t in enumerate(tones):
            if flat:
                c.put(x, y + k, t)
            else:
                c.put(x + k, y, t)


def disc_px(c, cx, cy, r, col):
    """A filled round blob: every pixel whose centre is within r of (cx, cy) (cx, cy on a pixel boundary — the blob is symmetric)."""
    for y in range(int(math.floor(cy - r)) - 1, int(math.ceil(cy + r)) + 1):
        for x in range(int(math.floor(cx - r)) - 1, int(math.ceil(cx + r)) + 1):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                c.put(x, y, col)


# ------------------------------------------------------------------------------------------------------------------------------------ the wheel
def wheel(c, cx, cy, R, tyre_w=2, spokes=8):
    """One wheel seen side-on, centred on the pixel BOUNDARY (cx, cy) so it is exactly round and symmetric: a tyre tyre_w px thick (a lit arc upper-left, a dark one lower-right),
    a 1 px rim inside it, thin spokes on the 45-degree grid and a hub. The same wheel at both ends of a bike."""
    r_in = R - tyre_w
    for y in range(cy - R - 1, cy + R + 1):
        for x in range(cx - R - 1, cx + R + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d2 = dx * dx + dy * dy
            if d2 > R * R:
                continue
            d = math.sqrt(d2)
            k = (dx * -0.7071 + dy * -0.7071) / max(d, 0.01)                 # +1 facing the light (upper left), -1 away from it
            if d2 > r_in * r_in:                                             # the tyre
                if k > 0.62 and d > R - 1.2:
                    col = TYRE_LIT
                elif k < -0.5:
                    col = TYRE_DK
                else:
                    col = TYRE
                c.put(x, y, col)
            elif d2 > (r_in - 1) * (r_in - 1):                               # the rim
                c.put(x, y, RIM if k > -0.35 else RIM_DK)
    reach = r_in - 2                                                         # spokes end just inside the rim
    for k in range(spokes):
        a = k * 2 * math.pi / spokes
        ex, ey = int(round(math.cos(a) * reach)), int(round(math.sin(a) * reach))
        pts = _run(cx, cy, cx + ex, cy + ey)
        col = SPOKE if (math.cos(a) + math.sin(a)) <= 0.01 else SPOKE_DK     # the upper-left spokes catch the light
        for (x, y) in pts:
            c.put(x, y, col)
    c.rect(cx - 1, cy - 1, cx, cy, HUB)                                      # the hub: a 2 x 2 block, its lower-right pixel in shade
    c.put(cx, cy, HUB_DK)


# ------------------------------------------------------------------------------------------------------------------------------------ the bike
def draw_bike(c, C, rx, R, frame, kid=False, extra=None, seed=1, stabilisers=False):
    """Draw a whole bicycle on canvas `c` with its tyres' lowest row on row `C`: rear hub on pixel boundary column `rx`, wheel radius `R` (the bike scales with it).
    extra: None | 'basket' | 'rack'. Returns the main points (for callers / tests)."""
    R, rx = int(R), int(rx)
    s = R / 11.0
    sc = lambda p: (int(round(p[0] * s)), int(round(p[1] * s)))
    cy = C + 1 - R                                                           # the hubs: the tyre's bottom pixel row is C
    wb = int(round(WHEELBASE * s))
    fx = rx + wb
    P = lambda p: (rx + sc(p)[0], cy + sc(p)[1])
    bb, st, ht, hf = P(BB), P(SEAT_TOP), (fx - (WHEELBASE - HEAD_TOP[0]) * 1, cy + sc(HEAD_TOP)[1]), (fx - (WHEELBASE - HEAD_FOOT[0]), cy + sc(HEAD_FOOT)[1])
    if kid:
        ht = (fx - 4, ht[1])
        hf = (fx - 2, hf[1])
    tyre_w = 2
    lit, body, dk = _ramp(frame)

    crank = max(4, int(round(6 * s)))
    ca = math.radians(62.0)
    near = (bb[0] + int(round(math.cos(ca) * crank)), bb[1] + int(round(math.sin(ca) * crank)))

    # --- the wheels, and (for a child's bike) its stabilisers behind the rear one
    if stabilisers:                                                          # training wheels: a small wheel on a strut from the rear hub, peeking out behind the big one
        sx, sy = rx - 6, C - 2
        for (x, y) in _run(rx, cy + 1, sx, sy):
            c.put(x, y, STEEL_DK)
        disc_px(c, sx + 1, sy + 1, 3.2, TYRE)
        disc_px(c, sx + 1, sy + 1, 1.6, RIM_DK)
        c.put(sx - 1, sy - 1, TYRE_LIT)
        c.put(sx, sy, HUB)
    wheel(c, rx, cy, R, tyre_w, 8)
    wheel(c, fx, cy, R, tyre_w, 8)

    # --- the rear rack, behind the frame (adult only): a rail over the wheel on two stays, and a crate on it
    if extra == 'rack':
        ry = cy - R - 2
        for (x, y) in _run(rx - 1, cy, rx - 3, ry):
            c.put(x, y, STEEL_DK)
        c.hline(rx - 5, rx + 6, ry, STEEL)
        c.hline(rx - 5, rx + 6, ry + 1, STEEL_DK)

    # --- the frame: stays, seat tube, down tube, top tube, head tube, fork — drawn back to front so the near joints sit on top
    tube(c, bb, (rx, cy), 2, frame)                                          # chain stay
    tube(c, (st[0] + 1, st[1] + 2), (rx, cy), 2, frame)                      # seat stay
    tube(c, bb, st, 2, frame)                                                # seat tube
    tube(c, bb, hf, 3 if not kid else 2, frame)                              # down tube
    tube(c, st, ht, 2, frame)                                                # top tube (level)
    tube(c, hf, ht, 3, shade(frame, 0.84))                                   # head tube: its own darker short tube, so the three do not melt into one
    fork_lit, fork_body = FORK_LIT, FORK
    for (x, y) in _run(hf[0], hf[1], fx, cy):                                # the fork: dark steel, 2 px, down into the front hub
        c.put(x, y, fork_lit)
        c.put(x + 1, y, fork_body)

    # --- chainring, crank, pedal (no chain: at this size its two thin runs beside the chain stay were noise)
    ring_r = max(3, int(round(3.4 * s)))
    for y in range(bb[1] - ring_r - 1, bb[1] + ring_r + 1):                  # the chainring: a dark disc with a lit rim, round
        for x in range(bb[0] - ring_r - 1, bb[0] + ring_r + 1):
            d2 = (x + 0.5 - bb[0]) ** 2 + (y + 0.5 - bb[1]) ** 2
            if d2 <= ring_r * ring_r:
                c.put(x, y, STEEL if (d2 > (ring_r - 1.2) ** 2 and x + y < bb[0] + bb[1]) else (STEEL_DK if d2 > (ring_r - 1.2) ** 2 else CHAIN))
    for (x, y) in _run(bb[0], bb[1], near[0], near[1]):                      # the near crank arm
        c.put(x, y, STEEL)
        c.put(x, y + 1, STEEL_DK)
    c.rect(near[0] - 2, near[1], near[0] + 2, near[1] + 1, RUBBER)           # the pedal: a flat block, lit on top
    c.hline(near[0] - 2, near[0] + 2, near[1], RUBBER_LIT)
    c.rect(bb[0] - 1, bb[1] - 1, bb[0], bb[1], HUB)                          # the crank's boss

    # --- seat post + saddle: a 2 px steel post from the lug up under the saddle
    top_y = st[1] - 5
    c.rect(st[0] - 1, top_y + 2, st[0], st[1], STEEL)
    c.vline(st[0], top_y + 2, st[1], STEEL_DK)
    saddle(c, (st[0] - 1, top_y), kid)

    # --- stem and bars: a stem up from the head tube, a bar sweeping back and up, a grip pointing at the rider
    stem_top = (ht[0] - 1, ht[1] - 3)
    tube(c, (ht[0], ht[1] - 1), stem_top, 2, STEEL_DK)
    elbow = (stem_top[0] - 3, stem_top[1] - 2)
    grip_end = (elbow[0] - 4, elbow[1])
    tube(c, stem_top, elbow, 2, FORK)
    for (x, y) in _run(elbow[0], elbow[1], grip_end[0], grip_end[1]):        # the grip: a black rubber 2 px bar with a lit top
        c.put(x, y, RUBBER_LIT)
        c.put(x, y + 1, RUBBER)
    c.put(stem_top[0] + 1, stem_top[1] + 1, FORK)                            # the bar's front nub, past the stem

    # --- what it carries
    if extra == 'basket':
        basket(c, stem_top, s)
    if extra == 'rack':
        crate(c, rx - 5, cy - R - 2, seed)

    # --- the two small coloured lights a real bike has: a red reflector on the seat stay, a headlamp on the fork crown
    rr = (st[0] - 1, st[1] + 4) if not kid else (st[0] - 1, st[1] + 3)
    c.rect(rr[0], rr[1], rr[0] + 1, rr[1] + 1, REFLECTOR)
    c.put(rr[0], rr[1], REFLECTOR_LIT)
    if extra != 'basket':
        c.rect(hf[0] + 2, hf[1] - 1, hf[0] + 4, hf[1] + 1, FORK)
        c.rect(hf[0] + 3, hf[1] - 1, hf[0] + 4, hf[1], LAMP)

    # --- tyre contact: a thin dark line on the floor under each wheel
    for x0 in (rx, fx):
        c.hline(x0 - 3, x0 + 2, C + 1, (20, 14, 12, 120))
    return {'bb': bb, 'st': st, 'ht': ht, 'fx': fx, 'cy': cy}


def saddle(c, top, kid=False):
    """A saddle: wide at the rear, tapering to a narrower nose on the right, a lit top edge, a darker underside — three rows, nothing else."""
    x, y = top
    r, n = (5, 5) if not kid else (4, 4)                                      # rear half-width, nose reach
    c.hline(x - r, x + n, y, SADDLE_LIT)
    c.hline(x - r, x + n - 2, y + 1, SADDLE)
    c.hline(x - r + 1, x + 1, y + 2, shade(SADDLE, 0.7))


def basket(c, stem_top, s):
    """A wicker basket on the bars: a lit rim, a body in horizontal rows of weave, a dark base, edged on the shaded side."""
    w, h = int(round(10 * s)), int(round(7 * s))
    x0, y0 = stem_top[0] + 1, stem_top[1] - 1
    x1, y1 = x0 + w - 1, y0 + h - 1
    c.rect(x0, y0, x1, y1, WICKER)
    for y in range(y0 + 2, y1, 2):
        c.hline(x0, x1, y, shade(WICKER, 0.78))
    c.hline(x0, x1, y0, shade(WICKER, 1.35))
    c.hline(x0, x1, y1, shade(WICKER, 0.55))
    c.vline(x0, y0, y1, shade(WICKER, 1.15))
    c.vline(x1, y0, y1, shade(WICKER, 0.6))


def crate(c, x, y, seed):
    """A plastic crate on the rear rack: a lit rim, slots, a shaded side."""
    col = [hexc('3a5a7a'), hexc('7a3a3a'), hexc('4a6a46')][seed % 3]
    w, h = 12, 7
    x0, y0, x1, y1 = x, y - h, x + w - 1, y - 1
    c.rect(x0, y0, x1, y1, col)
    for xx in range(x0 + 2, x1 - 1, 3):
        c.vline(xx, y0 + 2, y1 - 1, shade(col, 0.55))
    c.hline(x0, x1, y0, shade(col, 1.4))
    c.hline(x0, x1, y1, shade(col, 0.6))
    c.vline(x0, y0, y1, shade(col, 1.2))
    c.vline(x1, y0, y1, shade(col, 0.62))
