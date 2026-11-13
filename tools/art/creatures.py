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
    spitter    THE GULLET    a grub upright on bird legs with a tube of neck, and behind it a sack of something yellow that fills as it breathes.
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
    for (x, y) in pts:
        c.raw(int(x * K), int(y * K), col)
        c.raw(int(x * K), int(y * K) + 1, col)
        c.raw(int(x * K) + 1, int(y * K), col)


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
    """A boil going: droplets thrown out in a ring. u in 0..1."""
    for i in range(7):
        a = -math.pi * (0.1 + 0.8 * i / 6.0)
        r = (2.0 + 4.6 * u) * K
        px, py = int(x * K + r * math.cos(a)), int(y * K + r * math.sin(a) + 3.0 * u * u * K)
        c.raw(px, py, col)
        c.raw(px + 1, py, hi if i % 2 else col)
        c.raw(px, py + 1, col)


def glow(c, cx, cy, r, col):
    """A light under the skin: a checker of the glow colour over what is there (it shows THROUGH)."""
    for y in range(int((cy - r) * K), int((cy + r) * K) + 1):
        for x in range(int((cx - r) * K), int((cx + r) * K) + 1):
            if ((x / K - cx) ** 2 + (y / K - cy) ** 2) <= r * r and (x + y) % 2 == 0 and c.px[x, y][3]:
                c.raw(x, y, col)


def veins(c, pts, col):
    for (a, b) in zip(pts[:-1], pts[1:]):
        P.limb(c, a, b, 0.75, one(col))


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
    veins(c, [(14.0, 27.0 + bob), (16.5, 30.0 + bob), (15.0, 34.0 + bob), (17.5, 38.0 + bob)], '6a1648')
    veins(c, [(19.0, 23.0 + bob), (20.5, 26.0 + bob), (19.5, 29.0 + bob)], '6a1648')
    # the mouth: it runs from the collar to the belly and it never quite shuts. Wide on the breath, strings across it, a tongue that comes out
    gap = 2.4 + 1.5 * (0.5 + 0.5 * pulse)
    blob(c, 25.4, 31.0 + bob, gap + 0.8, 8.2, one('ff7a8a'), wet=False)                # the lips
    blob(c, 25.4, 31.0 + bob, gap, 7.6, one('24061a'), wet=False)
    blob(c, 25.6, 32.0 + bob, gap * 0.55, 5.4, pal('c81e3c', '8a0c2c', '500820', 'ff5a6a'), wet=False)
    teeth(c, [(25.4 - gap + 0.2, y + bob) for y in (24.6, 26.6, 28.6, 30.6, 32.6, 34.6, 36.6)] + [(25.4 + gap - 0.8, y + bob) for y in (25.6, 27.6, 29.6, 31.6, 33.6, 35.6)])
    for y in (27.4, 33.2):                                                             # spit strung between its lips
        if gap > 2.8:
            c.wire(int(25.4 - gap + 1), y + bob, int(25.4 + gap - 1), (255, 214, 220, 255))
    if pulse > 0.2 or walking:                                                         # the tongue
        tl = 5.0 + 3.0 * max(0.0, pulse)
        tx = 26.0 + tl * 0.8
        ty = 31.0 + bob + 2.0 * math.sin(2 * math.pi * (ph * 2 if walking else fr / 6.0))
        P.limb(c, (25.6, 31.4 + bob), (tx, ty), 1.9, pal('ff5a7a', 'c81e4a', '8a0c2c', 'ffb0b8'))
        P.limb(c, (tx, ty), (tx + 2.4, ty + 1.8), 1.1, one('ff9aa8'))
    for (x, y) in ((21.0, 19.0), (22.8, 18.0), (24.6, 19.4), (22.4, 20.4), (20.4, 21.0)):   # eyes, where no eyes go — and they blink out of step
        if not ((fr + int(x)) % 5 == 0):
            c.put(x, y + bob, (255, 222, 60, 255))
            c.raw(int(x * K) + 1, int((y + bob) * K) + 1, (20, 6, 20, 255))
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
    veins(c, [(8.0, cy - 2.0), (12.0, cy + 2.0), (10.0, cy + 7.0), (14.0, cy + 11.0)], '34104e')
    veins(c, [(20.0, cy + 1.0), (23.0, cy + 5.0), (21.0, cy + 10.0)], '34104e')
    veins(c, [(27.0, cy - 6.0), (25.0, cy - 2.0), (28.0, cy + 1.0)], '34104e')
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
    mr = 4.6 + 1.2 * pulse
    blob(c, 33.0, cy + 2.0, mr + 0.9, mr + 1.4, one('ff7ab0'), wet=False)              # lips
    blob(c, 33.0, cy + 2.0, mr, mr + 0.6, one('1e0618'), wet=False)
    blob(c, 33.4, cy + 2.2, mr * 0.5, mr * 0.55, pal('e0204a', '900c34', '500820', 'ff6a7a'), wet=False)
    rot = fr * 0.35                                                                    # the ring of teeth turns
    teeth(c, [(33.0 + (mr - 0.7) * math.cos(a + rot), cy + 2.0 + (mr - 0.2) * math.sin(a + rot)) for a in [i * math.pi / 6.0 for i in range(12)]])
    for i, x in enumerate((28.6, 31.0, 33.4, 35.6, 37.6)):                             # small arms under the mouth, never still
        w = math.sin(2 * math.pi * (ph * 2 if walking else fr / 6.0) + i * 1.3)
        P.limb(c, (x, cy + 7.6), (x + 1.8 * w, cy + 12.4), 1.7, hide)
        P.limb(c, (x + 1.8 * w, cy + 12.4), (x + 3.2 * w + 1.0, cy + 15.6), 1.2, one('f08ad8'))
    drip(c, 32.0, cy + 7.6, fr / 6.0 if not walking else ph * 2, P.rgb('f0a0d0'), WHITE)
    drip(c, 35.0, cy + 7.0, (fr / 6.0 + 0.5) if not walking else ph * 2 + 0.5, P.rgb('f0a0d0'), WHITE, length=6.0)
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
    for i, (x, y) in enumerate(((bx - 3.4, by - 3.0), (bx - 0.8, by - 4.8), (bx + 2.0, by - 3.4), (bx - 4.4, by + 0.2))):
        if (fr + i * 2) % 6 != 0:
            c.put(x, y, (255, 200, 40, 255))
            c.raw(int(x * K) + 1, int(y * K) + 1, (30, 8, 20, 255))
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
    hide = pal('f08a2a', 'b04a1e', '6a2414', 'ffd070')
    far = pal('b04a1e', '7a2c18', '4a1810', 'f08a2a')
    acid = pal('a4ff2a', '3ab81e', '167a2a', 'f4ffb0')
    bob = 0.8 * math.sin(4 * math.pi * ph) if walking else 0.0
    f_far, f_near = step(ph + 0.5, 22.0, 7.0 if walking else 0.0, 2.6), step(ph, 17.0, 7.0 if walking else 0.0, 2.6)
    leg(c, (21.0, 44.0 + bob), (f_far[0], f_far[1] - 1), -3.0, 2.6, 1.7, far, near=False)
    fill = 0.5 + 0.5 * pulse                                                           # the sack fills... and fills... and lets go
    sr = 7.0 + 3.4 * fill
    blob(c, 12.6, 28.0 + bob - 0.8 * fill, sr, sr + 0.9, acid)
    inside = lambda x, y: ((x - 12.6) / (sr - 1.0)) ** 2 + ((y - 28.0 - bob + 0.8 * fill) / sr) ** 2 <= 1.0
    for i in range(5):                                                                 # it is boiling in there: bubbles climbing
        u = ((fr / 6.0 if not walking else ph * 2.0) + i * 0.23) % 1.0
        bx_, by_ = 9.0 + 2.0 * i + math.sin(i * 2.1) * 1.2, 34.0 + bob - 12.0 * u
        if inside(bx_, by_):
            blob(c, bx_, by_, 1.0 + 0.7 * u, 1.0 + 0.7 * u, one(acid['l']), wet=False)
            c.raw(int(bx_ * K), int(by_ * K), WHITE)
    veins(c, [(12.6, 36.0 + bob), (9.0, 31.0 + bob), (7.0, 26.0 + bob)], '167a2a')
    veins(c, [(13.0, 36.0 + bob), (14.0, 29.0 + bob), (11.0, 22.0 + bob)], '167a2a')
    blob(c, 19.5, 38.0 + bob, 6.6, 8.8, hide)
    for y in (33.0, 37.0, 41.0):
        c.wire(15, y + bob, 25, P.rgb('6a2414'))
    aim = -1.0 * fill
    P.limb(c, (22.0, 31.0 + bob), (27.0, 24.0 + bob), 4.8, hide)
    P.limb(c, (27.0, 24.0 + bob), (33.0, 22.6 + bob + aim), 4.2, hide)
    blob(c, 24.6, 27.4 + bob, 2.4 + 2.2 * (1.0 - fill), 2.4 + 1.6 * (1.0 - fill), acid)    # a swallow going UP the neck as the sack empties
    blob(c, 34.6, 22.4 + bob + aim, 3.0, 3.2, one('ffd070'), wet=False)
    blob(c, 34.8, 22.4 + bob + aim, 2.2, 2.4, one('2a0a14'), wet=False)
    blob(c, 35.0, 22.4 + bob + aim, 1.2, 1.4, one(acid['m']), wet=False)
    drip(c, 35.2, 25.2 + bob + aim, fr / 6.0 if not walking else ph * 2, acid['m'], acid['l'], length=7.0)
    if fill < 0.25:                                                                    # ...and at the bottom of the breath it spits
        for i in range(4):
            c.put(37.0 + 2.0 * i, 21.6 + bob + aim + 0.4 * i * i, acid['m' if i % 2 else 'l'])
    for i, (x, y) in enumerate(((25.0, 27.6), (27.6, 25.4), (30.0, 24.0))):
        if (fr + i) % 4 != 0:
            c.put(x, y + bob, (255, 60, 40, 255))
    P.limb(c, (22.0, 36.0 + bob), (27.0, 39.0 + bob + pulse), 1.9, far)
    P.limb(c, (27.0, 39.0 + bob + pulse), (29.4, 36.4 + bob + pulse), 1.3, far)
    leg(c, (17.0, 44.0 + bob), (f_near[0], f_near[1] - 1), -3.4, 3.0, 1.9, hide)
    for f in (f_far, f_near):
        c.rect(f[0] - 1, f[1], f[0] + 3, f[1], P.rgb('4a1810'))


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
        P._outline(c)
        out.append((c.im, {}))
    return out
