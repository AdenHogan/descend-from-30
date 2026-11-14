#!/usr/bin/env python3
"""THE THINGS — the game's enemies as original monsters, not zombies (owner 2026-11-12: "grotesque monsters that fit the standard, crawler, big, long
arm, spitter names… horror, pulsating, gross, some can have multiple arms, some might have no discernable heads. Some could look more fly or
creature like"). A DESIGN pass on the people's own canvas, pixels, cel shading and line (tools/art/people.py): idle (it breathes, it pulses) and walk.
Nothing here names or explains what they are (CLAUDE.md "Context" 4): they are bodies, not a story.

    standard   THE HUSK      no head. A hunched trunk on two bent legs, split down the front by a mouth that runs from where the neck was to
                             the belly; a cluster of small eyes on one shoulder; two arms that end in hooks; sacs on its back that swell.
    crawler    THE LOUSE     low and fast: a segmented abdomen, six jointed legs, a small head that is mostly two red eyes and a pair of jaws,
                             stub wings that never stop twitching.
    big        THE BULK      a sack as wide as the corridor allows on four pillars of leg. No head: a ring of teeth at the front, boils that
                             rise and sink across its back, a fringe of small arms hanging under the mouth.
    longarm    THE REACH     a small body carried high on four arms twice its height, elbows above its back; a round sucking mouth underneath;
                             two withered legs that never touch the ground.
    spitter    THE HEAP      a hunched mass of matted fur with no head: raw bald patches, eyes of different sizes that open where they like, a beard
                             of pale tentacles, thin black legs under its skirts, and one puckered tube out of its back that fills with green and spits.
"""
import math

import people as P

G = P.ANKLE_Y + 3            # the ground row, in design pixels
K = P.K
WHITE = (255, 250, 236, 255)


def pal(m, d, dd, l):
    """A body's colours, LOUD on purpose (owner: "the monsters are great, but lack colour, depth and shading… All of it is so flat and soft colouring.
    Too soft"): a saturated base, a shadow that changes HUE as well as value, a deep core shadow, a hot light."""
    return {'m': P.rgb(m), 'd': P.rgb(d), 'dd': P.rgb(dd), 'l': P.rgb(l), 'll': WHITE}


def one(col):
    c = P.rgb(col) if isinstance(col, str) else col
    return {k: c for k in ('m', 'd', 'dd', 'l', 'll')}


def blob(c, cx, cy, rx, ry, t, wet=True, keep=None):
    """A wet, round mass in FOUR hard bands — deep core shadow, shadow, flesh, a lit crescent — and, if it is wet, a white glint where the light
    hits. Hard edges between the bands (it is a cartoon), but enough of them that the thing has weight."""
    cx, cy, rx, ry = cx * K, cy * K, max(0.6, rx * K), max(0.6, ry * K)
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if nx * nx + ny * ny > 1.0 or (keep is not None and not keep(x / K, y / K)):
                continue
            lit = 0.62 * nx - 0.72 * ny
            k = 'dd' if lit < -0.78 else ('d' if lit < -0.28 else ('l' if lit > 0.52 else 'm'))
            if wet and (nx - 0.38) ** 2 + (ny + 0.48) ** 2 < 0.035 and rx > 2.5:
                k = 'll'
            c.raw(x, y, t[k])


def leg(c, hip, foot, bend, w0, w1, t, near=True):
    """A two-bone leg from hip to foot, the knee pushed `bend` px off the line; a knob at the joint."""
    mx, my = (hip[0] + foot[0]) * 0.5, (hip[1] + foot[1]) * 0.5
    dx, dy = foot[0] - hip[0], foot[1] - hip[1]
    ln = math.hypot(dx, dy) or 1.0
    knee = (mx - dy / ln * bend, my + dx / ln * bend)
    P.limb(c, hip, knee, w0, t, near=near)
    P.limb(c, knee, foot, w1, t, near=near)
    if near and w0 > 2.0:
        blob(c, knee[0], knee[1], w0 * 0.55, w0 * 0.55, t, wet=False)
    return knee


def step(q, home, stride, lift):
    q %= 1.0
    if q < 0.5:
        return (home + stride * (0.5 - 2.0 * q), G)
    u = (q - 0.5) / 0.5
    return (home - stride * 0.5 + stride * u, G - lift * math.sin(math.pi * u))


def teeth(c, pts, col=(255, 246, 214, 255)):
    """Each tooth a clean 2 x 2 block: big enough to read as a tooth, not a speck."""
    for (x, y) in pts:
        for dx in (0, 1):
            for dy in (0, 1):
                c.raw(int(x * K) + dx, int(y * K) + dy, col)


def drip(c, x, y, t, col, hi, length=9.0):
    """Something thick leaving the body: a string that stretches, a bead that swells on its end, lets go, falls, and lands as a spot. t in 0..1."""
    t %= 1.0
    x0, y0 = int(x * K), int(y * K)
    if t < 0.55:                                             # the string stretches
        n = int(1 + length * K * 0.45 * (t / 0.55))
        for i in range(n):
            c.raw(x0, y0 + i, col)
        c.raw(x0, y0 + n, col)
        c.raw(x0 + 1, y0 + n, col)
        c.raw(x0, y0 + n + 1, hi)
        c.raw(x0 + 1, y0 + n + 1, col)
    else:                                                    # it lets go
        u = (t - 0.55) / 0.45
        yy = int(y0 + length * K * 0.45 + (G * K - y0 - length * K * 0.45) * u * u)
        for i in range(2):
            c.raw(x0, y0 + i, col)
        if yy < G * K + 1:
            c.raw(x0, yy, col)
            c.raw(x0 + 1, yy, col)
            c.raw(x0, yy + 1, hi)
            c.raw(x0 + 1, yy + 1, col)
        if u > 0.8:
            for dx in (-2, -1, 0, 1, 2, 3):
                c.raw(x0 + dx, int((G + 1) * K) - 1, col)


def splat(c, x, y, u, col, hi):
    """A boil going: a few fat drops thrown out in a ring (they were single pixels, which read as dirt). u in 0..1."""
    for i in range(4):
        a = -math.pi * (0.15 + 0.7 * i / 3.0)
        r = 2.4 + 4.0 * u
        blob(c, x + r * math.cos(a), y + r * math.sin(a) + 2.0 * u * u, 1.1, 1.1, {'m': col, 'd': col, 'dd': col, 'l': hi, 'll': hi}, wet=False)


def glow(c, cx, cy, r, col):
    """A light under the skin: a solid patch with a brighter heart (it was a checker of pixels, which read as a mesh)."""
    dim = tuple(int(v * 0.72) for v in col[:3]) + (255,)
    blob(c, cx, cy, r, r, {'m': dim, 'd': dim, 'dd': dim, 'l': dim, 'll': dim}, wet=False)
    blob(c, cx + 0.2, cy - 0.2, r * 0.55, r * 0.55, {'m': col, 'd': col, 'dd': col, 'l': col, 'll': col}, wet=False)


def veins(c, pts, col):
    """(Hair-thin lines across a body read as scratches: a vein is drawn thick enough to be a shape, or not at all.)"""
    for (a, b) in zip(pts[:-1], pts[1:]):
        P.limb(c, a, b, 1.3, one(col))


# ------------------------------------------------------------------------------------------------------------------------------------ standard
def husk(c, ph, pulse, walking, fr):
    flesh = pal('e0566e', 'a02458', '561040', 'ff9c8c')
    far = pal('a02458', '6a1648', '3c0c34', 'c84a6a')
    sac = pal('f6d848', 'd08a1e', '8a4a14', 'fff6b0')
    q = ph if walking else 0.25
    bob = 1.0 if (walking and (ph % 0.5) < 0.12) else 0.4 * pulse
    sq = 0.5 * pulse                                                                  # it swells and sinks as it breathes
    f_far, f_near = step(q + 0.5, 24.0, 9.0 if walking else 0.0, 3.0), step(q, 19.0, 9.0 if walking else 0.0, 3.0)
    hy = 40.0 + bob
    leg(c, (23.5, hy), (f_far[0], f_far[1] - 1), 3.2, 4.6, 3.4, far, near=False)
    sway = 2.4 * math.sin(2 * math.pi * ph) if walking else 1.2 * pulse
    P.limb(c, (25.0, 24.0 + bob), (31.0 + sway, 31.0 + bob), 3.2, far, near=False)
    P.limb(c, (31.0 + sway, 31.0 + bob), (35.0 + sway, 37.0 + bob), 1.8, one('2a0a22'), near=False)
    P.limb(c, (35.0 + sway, 37.0 + bob), (33.6 + sway, 40.0 + bob), 1.3, one('2a0a22'), near=False)
    # the sacs on its back: each fills as the other empties, tight and shining
    blob(c, 13.0, 24.6 + bob, 3.4 + 1.5 * pulse, 3.4 + 1.5 * pulse, sac)
    blob(c, 12.2, 32.4 + bob, 3.0 - 1.3 * pulse, 3.2 - 1.3 * pulse, sac)
    blob(c, 15.4, 37.6 + bob, 1.9 + 0.8 * pulse, 1.9 + 0.8 * pulse, sac)
    # the trunk
    blob(c, 20.5, 31.0 + bob, 7.6 + sq, 10.8 - sq * 0.6, flesh)
    blob(c, 22.5, 21.6 + bob, 6.8 + sq * 0.5, 5.4, flesh)
    blob(c, 17.0, 20.2 + bob, 3.4, 2.8, flesh, wet=False)                              # the stump
    blob(c, 17.0, 19.0 + bob, 2.2, 1.2, one('7a0c2c'), wet=False)
    c.raw(int(17.0 * K), int((18.6 + bob) * K), (255, 150, 160, 255))
    # the mouth: it runs from the collar to the belly and it never quite shuts. Wide on the breath, strings across it, a tongue that comes out
    gap = 2.4 + 1.5 * (0.5 + 0.5 * pulse)
    blob(c, 25.4, 31.0 + bob, gap + 0.8, 8.2, one('ff7a8a'), wet=False)                # the lips
    blob(c, 25.4, 31.0 + bob, gap, 7.6, one('24061a'), wet=False)
    blob(c, 25.6, 32.0 + bob, gap * 0.55, 5.4, pal('c81e3c', '8a0c2c', '500820', 'ff5a6a'), wet=False)
    teeth(c, [(25.4 - gap + 0.2, y + bob) for y in (24.6, 26.6, 28.6, 30.6, 32.6, 34.6, 36.6)] + [(25.4 + gap - 0.8, y + bob) for y in (25.6, 27.6, 29.6, 31.6, 33.6, 35.6)])
    if pulse > 0.2 or walking:                                                         # the tongue
        tl = 5.0 + 3.0 * max(0.0, pulse)
        tx = 26.0 + tl * 0.8
        ty = 31.0 + bob + 2.0 * math.sin(2 * math.pi * (ph * 2 if walking else fr / 6.0))
        P.limb(c, (25.6, 31.4 + bob), (tx, ty), 1.9, pal('ff5a7a', 'c81e4a', '8a0c2c', 'ffb0b8'))
        P.limb(c, (tx, ty), (tx + 2.4, ty + 1.8), 1.1, one('ff9aa8'))
    for i, (x, y) in enumerate(((20.6, 19.6), (23.6, 18.6))):                          # two eyes on the shoulder, big enough to be eyes
        if (fr + i * 3) % 6 != 0:
            blob(c, x, y + bob, 1.5, 1.5, pal('ffde3c', 'e0902a', 'a05a1a', 'fff6b0'), wet=False)
            c.put(x, y + bob, (20, 6, 20, 255))
    drip(c, 25.4, 38.6 + bob, (fr / 6.0 if not walking else ph * 2), P.rgb('ff8a9a'), WHITE)
    leg(c, (18.5, hy), (f_near[0], f_near[1] - 1), 3.6, 5.0, 3.8, flesh)
    for f in (f_far, f_near):
        c.rect(f[0] - 1, f[1], f[0] + 3, f[1], P.rgb('2a0a22'))
    P.limb(c, (19.0, 24.0 + bob), (22.0 - sway, 33.0 + bob), 3.8, flesh)
    P.limb(c, (22.0 - sway, 33.0 + bob), (27.0 - sway, 41.0 + bob), 2.8, flesh)
    blob(c, 22.0 - sway, 33.0 + bob, 2.1, 2.1, flesh, wet=False)
    P.limb(c, (27.0 - sway, 41.0 + bob), (30.4 - sway, 44.0 + bob), 1.7, one('2a0a22'))
    P.limb(c, (30.4 - sway, 44.0 + bob), (28.4 - sway, 47.0 + bob), 1.2, one('2a0a22'))


# ------------------------------------------------------------------------------------------------------------------------------------- crawler
def louse(c, ph, pulse, walking, fr):
    shell = pal('1f7a9a', '14406a', '0c1c40', '5ae6e0')
    far = pal('14406a', '0c2248', '08122c', '1f7a9a')
    belly = pal('f08a2a', 'b84a1a', '6a2010', 'ffd070')
    eye = pal('ff3a2a', 'a80c1c', '5a0414', 'ffb09a')
    by = 46.0 - (0.8 if walking and (ph * 3) % 1.0 < 0.3 else 0.3 * pulse)
    homes = (17.0, 23.0, 29.0)
    for k, hx in enumerate(homes):
        f = step(ph + (0.5 if k % 2 == 0 else 0.0), hx + 3.0, 7.0 if walking else 0.0, 2.6)
        leg(c, (hx + 2.0, by + 1.0), (f[0], f[1]), 4.6, 1.9, 1.3, far, near=False)
    buzz = (fr % 2 == 0)                                                               # the wings never stop
    for (a0, a1, w, col) in (((17.0, by - 3.0), (8.0, by - 9.0 - (3.0 if buzz else -1.0)), 2.6, 'c8f4ff'), ((15.0, by - 3.0), (5.0, by - 5.0 - (2.0 if buzz else -2.0)), 2.2, '8ad0e8')):
        P.limb(c, a0, a1, w, one(col))
    swell = 0.9 * pulse
    blob(c, 13.5, by, 8.8 + swell, 5.2 + swell, shell)                                 # the abdomen: it throbs
    blob(c, 13.5, by + 2.6, 7.6 + swell * 0.5, 2.8, belly)
    for x in (8.6, 12.0, 15.6):
        c.vwire(x, by - 5, by + 4, P.rgb('08122c'))
    for i, (x, y) in enumerate(((9.5, by + 2.2), (12.6, by + 3.0), (15.6, by + 2.4), (11.0, by + 0.8))):   # what it is carrying, lit from inside
        if (fr + i) % 3 != 0:
            glow(c, x, y, 1.3 + 0.4 * pulse, (255, 240, 120, 255))
    blob(c, 24.5, by - 0.6, 5.6, 5.0, shell)
    blob(c, 31.6, by + 0.8, 3.8, 3.6, shell)
    blob(c, 32.6, by - 0.4, 2.3 + 0.3 * pulse, 2.2 + 0.3 * pulse, eye)                 # an eye that is most of the head
    c.put(33.0, by - 1.4, WHITE)
    jaw = 1.2 * (0.5 + 0.5 * pulse) if not walking else 1.2 * abs(math.sin(4 * math.pi * ph))
    P.limb(c, (33.6, by + 2.4), (37.0, by + 4.0 + jaw), 1.4, one('ffd070'))
    P.limb(c, (33.0, by + 3.2), (35.6, by + 6.6 - jaw), 1.4, one('f08a2a'))
    P.limb(c, (33.0, by - 2.8), (38.0, by - 7.0 + 2.0 * pulse), 0.9, one('5ae6e0'))
    P.limb(c, (32.0, by - 3.0), (35.0, by - 8.6 - 2.0 * pulse), 0.9, one('1f7a9a'))
    drip(c, 35.6, by + 5.4, (fr / 6.0 + 0.3) if not walking else ph * 2 + 0.3, P.rgb('c8f060'), WHITE, length=4.0)
    for k, hx in enumerate(homes):
        f = step(ph + (0.0 if k % 2 == 0 else 0.5), hx, 7.0 if walking else 0.0, 3.2)
        leg(c, (hx + 1.0, by + 0.5), (f[0], f[1]), 6.4, 2.4, 1.6, shell)


# ----------------------------------------------------------------------------------------------------------------------------------------- big
def bulk(c, ph, pulse, walking, fr):
    hide = pal('b04aa8', '6a2484', '34104e', 'f08ad8')
    far = pal('6a2484', '401460', '240a3c', '9a3a9a')
    boil = pal('dcf43a', '8eb01c', '4a6a10', 'fbffb8')
    bob = 0.9 * math.sin(4 * math.pi * ph) if walking else 0.6 * pulse
    sq = 0.9 * pulse
    cy = 30.0 + bob
    homes = (9.0, 17.0, 26.0, 34.0)
    for k in (1, 3):
        f = step(ph + 0.5 * (k // 2) + 0.25, homes[k], 5.0 if walking else 0.0, 1.6)
        P.limb(c, (homes[k], 42.0 + bob), (f[0], f[1] - 1), 6.6, far, near=False)
    blob(c, 21.0, cy, 16.0 + sq, 15.2 - sq * 0.5, hide)                                # the sack: it heaves
    blob(c, 20.0, cy + 8.4, 13.2 + sq, 6.2, hide, wet=False)
    glow(c, 17.0, cy + 2.0, 3.0 + 1.2 * pulse, (255, 120, 200, 255))                   # something alive inside it
    spots = ((12.0, 19.0, 3.2), (20.0, 15.4, 3.8), (28.0, 18.4, 3.0), (7.6, 27.0, 2.6), (15.6, 23.6, 2.2), (25.0, 25.0, 2.4), (31.0, 13.0 + 8.0, 1.8))
    burst = (fr // 2) % len(spots) if not walking else (fr // 3) % len(spots)          # one of them goes, in turn
    stage = fr % 2 if not walking else fr % 3
    for i, (x, y, r) in enumerate(spots):
        k = math.sin(2 * math.pi * (fr / 6.0 if not walking else ph * 2.0) + i * 1.7)
        if i == burst and stage >= 1:                                                  # ...burst: a wet red crater, and what was in it in the air
            blob(c, x, y + bob, r * 0.9, r * 0.7, one('5a0a2a'), wet=False)
            blob(c, x, y + bob, r * 0.5, r * 0.4, one('ff3a5a'), wet=False)
            splat(c, x, y + bob - 1.0, 0.35 if stage == 1 else 0.9, boil['m'], boil['l'])
        else:
            rr = r + 1.2 * k + (1.0 if i == burst else 0.0)                            # the one about to go is the biggest
            blob(c, x, y + bob, rr, rr, boil)
    # no mouth (the owner gave the big mouth to the spitter): where a face would be, three eyes that do not agree with each other
    for i, (x, y, r) in enumerate(((32.0, cy - 1.0, 2.6), (34.6, cy + 4.0, 1.9), (29.6, cy + 4.6, 1.6))):
        if (fr + i * 2) % 6 == 0:
            blob(c, x, y, r + 0.6, 0.9, one('34104e'), wet=False)                      # shut
        else:
            blob(c, x, y, r + 0.7, r + 0.7, one('34104e'), wet=False)
            blob(c, x, y, r, r, pal('ffe04a', 'e0902a', 'a05a1a', 'fff6b0'), wet=False)
            blob(c, x + 0.5 * math.sin(2 * math.pi * (fr / 6.0) + i), y, r * 0.42, r * 0.42, one('1e0618'), wet=False)
    for i, x in enumerate((28.0, 32.0, 36.0)):                                         # three heavy arms under them, never still
        w = math.sin(2 * math.pi * (ph * 2 if walking else fr / 6.0) + i * 1.6)
        P.limb(c, (x, cy + 8.6), (x + 1.6 * w, cy + 13.0), 2.6, hide)
        P.limb(c, (x + 1.6 * w, cy + 13.0), (x + 3.0 * w + 1.0, cy + 16.6), 1.9, hide)
    for k in (0, 2):
        f = step(ph + 0.5 * (k // 2), homes[k], 5.0 if walking else 0.0, 1.8)
        P.limb(c, (homes[k], 42.0 + bob), (f[0], f[1] - 1), 7.6, hide)
        c.rect(f[0] - 3, f[1], f[0] + 3, f[1], P.rgb('240a3c'))


# ------------------------------------------------------------------------------------------------------------------------------------- longarm
def reach(c, ph, pulse, walking, fr):
    skin = pal('4cb84a', '1e7a44', '0c4034', 'b4f46a')
    far = pal('1e7a44', '0e4a38', '082a28', '4cb84a')
    bob = 0.9 * math.sin(4 * math.pi * ph) if walking else 0.7 * pulse
    bx, by = 21.0, 20.0 + bob
    homes = (8.0, 16.0, 27.0, 35.0)
    feet = [step(ph + (0.0, 0.5, 0.25, 0.75)[k], homes[k], 5.0 if walking else 0.0, 4.0) for k in range(4)]
    elbows = ((8.0, 7.0), (14.0, 9.0), (29.0, 9.0), (35.0, 7.0))
    for k in (1, 3):
        P.limb(c, (bx + (-2 if k < 2 else 2), by - 2.0), (elbows[k][0], elbows[k][1] + bob), 2.8, far, near=False)
        P.limb(c, (elbows[k][0], elbows[k][1] + bob), (feet[k][0], feet[k][1]), 2.1, far, near=False)
    for i, x in enumerate((19.0, 22.0)):                                               # withered legs, kicking at nothing
        sw = 1.8 * math.sin(2 * math.pi * (ph if walking else fr / 6.0) + i * 2.0)
        P.limb(c, (x, by + 5.0), (x + sw, by + 12.0), 1.9, far)
        P.limb(c, (x + sw, by + 12.0), (x + sw + 1.6, by + 16.0), 1.3, far)
    beat = 1.0 if fr % 3 == 0 else (0.5 if fr % 3 == 1 else 0.0)                       # a heart, and you can see it
    blob(c, bx, by, 6.4 + 0.5 * beat, 7.0 + 0.6 * beat, skin)
    blob(c, bx - 1.0, by - 4.6, 4.6, 2.8, skin)
    glow(c, bx - 1.2, by + 0.6, 2.2 + 1.2 * beat, (255, 140, 40, 255))
    veins(c, [(bx - 1.2, by + 0.6), (bx - 4.4, by - 2.0), (bx - 5.4, by + 2.0)], 'ff8a28')
    veins(c, [(bx - 1.2, by + 0.6), (bx + 1.4, by - 3.0), (bx + 4.0, by - 2.0)], 'ff8a28')
    mr = 2.6 + 0.9 * pulse
    blob(c, bx + 3.2, by + 3.6, mr + 0.8, mr + 0.8, one('ff5ad0'), wet=False)
    blob(c, bx + 3.2, by + 3.6, mr, mr, one('1e0618'), wet=False)
    rot = fr * 0.5
    teeth(c, [(bx + 3.2 + (mr - 0.5) * math.cos(a + rot), by + 3.6 + (mr - 0.5) * math.sin(a + rot)) for a in [i * math.pi / 4.0 for i in range(8)]])
    for i, (x, y) in enumerate(((bx - 2.6, by - 3.4), (bx + 1.6, by - 3.8))):
        if (fr + i * 3) % 6 != 0:
            blob(c, x, y, 1.4, 1.4, pal('ffc828', 'e0802a', 'a04a1a', 'fff0a0'), wet=False)
            c.put(x, y, (30, 8, 20, 255))
    drip(c, bx + 3.2, by + 6.4, fr / 6.0 if not walking else ph * 2, P.rgb('ffa0e0'), WHITE, length=14.0)   # a long rope of it, all the way down
    for k in (0, 2):
        P.limb(c, (bx + (-3 if k < 2 else 3), by - 1.0), (elbows[k][0], elbows[k][1] + bob), 3.2, skin)
        P.limb(c, (elbows[k][0], elbows[k][1] + bob), (feet[k][0], feet[k][1]), 2.5, skin)
        blob(c, elbows[k][0], elbows[k][1] + bob, 2.3, 2.3, skin)
    for f in feet:
        for d in (-2.2, 0.0, 2.2):
            P.limb(c, (f[0], f[1] - 1.0), (f[0] + d, f[1] + 0.6), 1.1, one('082a28'))


# ------------------------------------------------------------------------------------------------------------------------------------- spitter
def gullet(c, ph, pulse, walking, fr):
    """THE SPITTER: a hunched heap of matted fur that is mostly MOUTH (owner: "I don't like that… thing on its head. Notice how monster 3 has that
    giant gaping mouth. I think we should swap that, so the spitter has the giant mouth where the attack comes from. Also there's too much pixel
    design that looks unclear and sloppy"). Few shapes, each big enough to read: the heap, a skirt of six heavy clumps, one raw bald patch, three
    eyes, four black legs — and the mouth: a ring of teeth as wide as its front, green welling up in the throat, and what it spits leaving it."""
    fur = pal('3c2e3a', '241a2a', '120c18', '6e5c80')
    raw = pal('e0707e', 'a83a5a', '6a1c40', 'ffb0a8')
    acid = pal('a4ff2a', '3ab81e', '167a2a', 'f4ffb0')
    t = (fr / 6.0) if not walking else ph * 2.0
    bob = 0.9 * math.sin(4 * math.pi * ph) if walking else 0.5 * pulse
    sw = 1.6 * math.sin(2 * math.pi * t)
    cx, cy = 18.0, 30.0 + bob
    homes = (10.0, 15.0, 21.0, 26.0)
    for k in (1, 3):
        f = step(ph + (0.5 if k == 1 else 0.0), homes[k], 6.0 if walking else 0.0, 2.4)
        leg(c, (homes[k], 41.0 + bob), (f[0], f[1]), -2.6, 2.2, 1.6, one('120c18'), near=False)
    blob(c, cx, cy, 11.4 + 0.5 * pulse, 12.2 - 0.4 * pulse, fur, wet=False)            # the heap
    blob(c, cx - 3.0, cy - 7.4, 7.8, 6.0, fur, wet=False)                              # its hump
    for (x, y) in ((cx - 7.0, cy - 9.6), (cx - 2.0, cy - 11.4), (cx - 9.6, cy - 3.0)):  # three strokes of sheen: the fur is slick
        P.limb(c, (x, y), (x + 3.0, y + 1.0), 1.5, one('6e5c80'))
    blob(c, cx - 6.4, cy + 2.6, 2.8, 2.2, raw)                                         # one raw patch where the fur has come away
    for i in range(6):                                                                 # the skirt: six heavy clumps, swinging out of step
        x = cx - 9.6 + i * 3.6
        ln = 5.0 + 2.0 * abs(math.sin(i * 2.1))
        s_ = sw * (0.5 + 0.5 * math.sin(i * 1.7))
        y0 = cy + 8.6 + 2.2 * math.sin(math.pi * i / 5.0)
        P.limb(c, (x, y0), (x + s_ * 0.5, y0 + ln * 0.6), 3.4, fur)
        P.limb(c, (x + s_ * 0.5, y0 + ln * 0.6), (x + s_, y0 + ln), 2.0, one('120c18'))
    for i in range(3):                                                                 # and three off its back
        y = cy - 3.0 + i * 4.4
        P.limb(c, (cx - 10.8, y), (cx - 13.6 - 0.4 * sw, y + 3.4), 2.2, fur)
    # THE MOUTH: it opens as it fills, and the spit comes from here
    fill = 0.5 + 0.5 * math.sin(2 * math.pi * t - 1.2)
    mx, my = cx + 7.6, cy + 1.6
    mr = 5.2 + 1.6 * fill
    blob(c, mx, my, mr + 1.1, mr + 1.5, raw, wet=False)                                # the lips: raw, turned out
    blob(c, mx + 0.3, my, mr, mr + 0.4, one('1a0614'), wet=False)                      # the dark
    blob(c, mx + 0.6, my + 0.8, mr * 0.62, mr * 0.66, pal('8a1030', '5a0a28', '3a0620', 'c8284a'), wet=False)   # the throat
    blob(c, mx + 0.8, my + 1.2 + 0.6 * (1.0 - fill), mr * 0.2 + mr * 0.38 * fill, mr * 0.2 + mr * 0.36 * fill, acid)   # green coming up it
    n = 10
    teeth(c, [(mx + 0.3 + (mr - 0.9) * math.cos(a), my + (mr - 0.5) * math.sin(a)) for a in [i * 2.0 * math.pi / n + 0.3 for i in range(n)]])
    if fill > 0.72:                                                                    # full: it spits — fat drops in an arc, out of the mouth
        for i in range(4):
            blob(c, mx + mr + 1.6 + 2.6 * i, my - 1.0 + 0.4 * i * i, 1.5 - 0.2 * i, 1.5 - 0.2 * i, acid, wet=(i == 0))
    drip(c, mx + 1.0, my + mr + 1.0, t + 0.3, acid['m'], acid['l'], length=5.0)        # and it never stops running from the bottom lip
    # three eyes over the mouth, different sizes, not open together
    for i, (x, y, r) in enumerate(((cx + 3.0, cy - 7.4, 1.9), (cx + 7.4, cy - 8.2, 1.4), (cx - 0.6, cy - 4.6, 1.2))):
        if (fr + i * 2) % 6 == 0:
            blob(c, x, y, r + 0.5, 0.8, one('120c18'), wet=False)
        else:
            blob(c, x, y, r + 0.6, r + 0.6, one('120c18'), wet=False)
            blob(c, x, y, r, r, pal('ffe04a', 'e0902a', 'a05a1a', 'fff6b0'), wet=False)
            blob(c, x + 0.4, y, r * 0.42, r * 0.42, one('1e0618'), wet=False)
    for k in (0, 2):
        f = step(ph + (0.0 if k == 0 else 0.5), homes[k], 6.0 if walking else 0.0, 2.6)
        leg(c, (homes[k], 41.0 + bob), (f[0], f[1]), -3.0, 2.6, 1.8, one('1e1424'))
        c.rect(f[0] - 1, f[1], f[0] + 2, f[1], P.rgb('0a0610'))


KINDS = {'standard': husk, 'crawler': louse, 'big': bulk, 'longarm': reach, 'spitter': gullet}


def frames(name, kind):
    """-> [(image, {})]: the idle breathes over 6 frames, the walk is the people's 12. Every frame knows its number, so things can happen ONCE in a
    cycle (a boil goes, a mouthful comes up) rather than only swing back and forth."""
    out = []
    n = P.WALK_N if kind == 'walk' else 6
    for i in range(n):
        c = P.Cel()
        if kind == 'walk':
            KINDS[name](c, i / float(n), math.sin(2 * math.pi * i / float(n) * 2.0), True, i)
        else:
            KINDS[name](c, 0.0, math.sin(2 * math.pi * i / 6.0), False, i)
        P._outline(c, (26, 14, 34), 0.8)                     # the things keep their hard line: it is the people who are soft
        out.append((c.im, {}))
    return out
