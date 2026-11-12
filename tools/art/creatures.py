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
FLAT = ('m', 'd', 'dd', 'l', 'll')


def T(h, dk=0.78, lt=1.14):
    return P.tones(h, dk, lt, mute=0.0)


def one(col):
    c = P.rgb(col) if isinstance(col, str) else col
    return {k: c for k in FLAT}


def leg(c, hip, foot, bend, w0, w1, t, near=True):
    """A two-bone leg from hip to foot, the knee pushed `bend` px off the line (+ = toward the back / up)."""
    mx, my = (hip[0] + foot[0]) * 0.5, (hip[1] + foot[1]) * 0.5
    dx, dy = foot[0] - hip[0], foot[1] - hip[1]
    ln = math.hypot(dx, dy) or 1.0
    knee = (mx - dy / ln * bend, my + dx / ln * bend)
    P.limb(c, hip, knee, w0, t, near=near)
    P.limb(c, knee, foot, w1, t, near=near)
    return knee


def step(q, home, stride, lift):
    """Where a foot is at phase q: on the ground it slides back under the body, then lifts and comes forward. -> (x, y)"""
    q %= 1.0
    if q < 0.5:
        return (home + stride * (0.5 - 2.0 * q), G)
    u = (q - 0.5) / 0.5
    return (home - stride * 0.5 + stride * u, G - lift * math.sin(math.pi * u))


def teeth(c, pts, col=(236, 228, 200, 255)):
    for (x, y) in pts:
        c.raw(int(x * P.K), int(y * P.K), col)
        c.raw(int(x * P.K), int(y * P.K) + 1, col)


# ------------------------------------------------------------------------------------------------------------------------------------ standard
def husk(c, ph, pulse, walking):
    flesh, dark, sac = T('b88a8e'), T('7a4a56'), T('e0c8a0')
    q = ph if walking else 0.25
    bob = 1.0 if (walking and (ph % 0.5) < 0.12) else 0.0
    f_far, f_near = step(q + 0.5, 24.0, 9.0 if walking else 0.0, 3.0), step(q, 19.0, 9.0 if walking else 0.0, 3.0)
    hy = 40.0 + bob
    leg(c, (23.5, hy), (f_far[0], f_far[1] - 1), 3.2, 4.4, 3.2, dark, near=False)
    sway = 2.0 * math.sin(2 * math.pi * ph) if walking else 0.6 * pulse
    # the far arm: a hook hanging forward
    P.limb(c, (25.0, 24.0 + bob), (31.0 + sway, 31.0 + bob), 3.0, dark, near=False)
    P.limb(c, (31.0 + sway, 31.0 + bob), (34.0 + sway, 38.0 + bob), 1.8, one('3a2a34'), near=False)
    # sacs on the back, swelling out of step
    c.ell(13.6, 25.0 + bob, 3.2 + 0.7 * pulse, 3.2 + 0.7 * pulse, sac)
    c.ell(12.8, 32.0 + bob, 2.6 - 0.5 * pulse, 2.8 - 0.5 * pulse, sac)
    # the trunk: bent forward, heaviest at the shoulders, nothing above them
    c.ell(20.5, 31.0 + bob, 7.4, 10.5, flesh)
    c.ell(22.5, 22.0 + bob, 6.6, 5.2, flesh)
    c.ell(17.0, 20.6 + bob, 3.4, 2.6, flesh)                                         # the stump where a neck was
    c.ell(17.0, 19.6 + bob, 2.0, 1.0, one('5a2a34'))
    # the mouth: a split from the collar to the belly, opening as it breathes
    gap = 2.0 + 0.8 * pulse
    c.ell(25.2, 31.0 + bob, gap, 7.6, one('3a1420'))
    c.ell(25.2, 31.0 + bob, gap * 0.45, 5.6, one('8a2a3a'))
    teeth(c, [(25.2 - gap + 0.3, y + bob) for y in (25.5, 28.0, 30.5, 33.0, 35.5)] + [(25.2 + gap - 0.6, y + bob) for y in (26.5, 29.2, 31.8, 34.4)])
    for (x, y) in ((21.0, 19.4), (22.8, 18.6), (24.4, 19.8), (22.2, 20.8)):          # eyes, where no eyes go
        c.put(x, y + bob, (236, 206, 90, 255))
        c.raw(int(x * P.K) + 1, int((y + bob) * P.K) + 1, (30, 20, 28, 255))
    leg(c, (18.5, hy), (f_near[0], f_near[1] - 1), 3.6, 4.8, 3.6, flesh)
    for f in (f_far, f_near):                                                        # feet: three toes, splayed
        c.rect(f[0] - 1, f[1], f[0] + 3, f[1], P.rgb('3a2a34'))
    # the near arm: a long forearm ending in a hook
    P.limb(c, (19.0, 24.0 + bob), (22.0 - sway, 33.0 + bob), 3.6, flesh)
    P.limb(c, (22.0 - sway, 33.0 + bob), (27.0 - sway, 41.0 + bob), 2.6, flesh)
    P.limb(c, (27.0 - sway, 41.0 + bob), (30.0 - sway, 44.0 + bob), 1.6, one('3a2a34'))
    P.limb(c, (30.0 - sway, 44.0 + bob), (28.4 - sway, 46.6 + bob), 1.2, one('3a2a34'))


# ------------------------------------------------------------------------------------------------------------------------------------- crawler
def louse(c, ph, pulse, walking):
    shell, belly, eye = T('3c4458'), T('8c9078'), T('d8483a')
    by = 46.0 - (0.6 if walking and (ph * 3) % 1.0 < 0.3 else 0.0)
    homes = (17.0, 23.0, 29.0)
    # far legs first
    for k, hx in enumerate(homes):
        f = step(ph + (0.5 if k % 2 == 0 else 0.0), hx + 3.0, 7.0 if walking else 0.0, 2.6)
        leg(c, (hx + 2.0, by + 1.0), (f[0], f[1]), 4.6, 1.8, 1.3, shell, near=False)
    # wings: stubs that twitch (drawn before the body so only their tips show)
    wa = 0.9 if (int(ph * 12) % 2 == 0 or not walking and pulse > 0) else -0.4
    P.limb(c, (17.0, by - 3.0), (9.0, by - 8.0 - 3.0 * wa), 2.4, one('b8c4c8'))
    P.limb(c, (15.0, by - 3.0), (6.0, by - 5.0 - 2.0 * wa), 2.0, one('98a4ac'))
    # abdomen (segmented, swelling), thorax, head
    c.ell(13.5, by, 8.6 + 0.5 * pulse, 5.0 + 0.5 * pulse, shell)
    c.ell(13.5, by + 2.4, 7.4, 2.6, belly)
    for x in (9.0, 12.5, 16.0):
        c.vwire(x, by - 4, by + 4, P.rgb('1e2230'))
    c.ell(24.5, by - 0.6, 5.4, 4.8, shell)
    c.ell(31.6, by + 0.8, 3.6, 3.4, shell)
    c.ell(32.4, by - 0.4, 1.9, 1.8, eye)                                             # an eye that is most of the head
    c.raw(int(33.0 * P.K), int((by - 1.0) * P.K), (250, 214, 190, 255))
    P.limb(c, (33.6, by + 2.4), (36.6, by + 4.6 + 0.6 * pulse), 1.3, one('1e2230'))  # jaws
    P.limb(c, (33.0, by + 3.2), (35.4, by + 6.2 - 0.6 * pulse), 1.3, one('1e2230'))
    P.limb(c, (33.0, by - 2.6), (37.6, by - 6.6 + pulse), 0.9, one('1e2230'))        # a feeler
    # near legs: knees above the back, feet wide
    for k, hx in enumerate(homes):
        f = step(ph + (0.0 if k % 2 == 0 else 0.5), hx, 7.0 if walking else 0.0, 3.0)
        leg(c, (hx + 1.0, by + 0.5), (f[0], f[1]), 6.0, 2.2, 1.5, shell)


# ----------------------------------------------------------------------------------------------------------------------------------------- big
def bulk(c, ph, pulse, walking):
    hide, dark, boil = T('a88c98'), T('6a4a5c'), T('e4d48c')
    bob = 0.8 * math.sin(4 * math.pi * ph) if walking else 0.5 * pulse
    cy = 30.0 + bob
    homes = (9.0, 17.0, 26.0, 34.0)
    for k in (1, 3):                                                                 # far pillars
        f = step(ph + 0.5 * (k // 2) + 0.25, homes[k], 5.0 if walking else 0.0, 1.6)
        P.limb(c, (homes[k], 42.0 + bob), (f[0], f[1] - 1), 6.4, dark, near=False)
    c.ell(21.0, cy, 16.0, 15.0 + 0.6 * pulse, hide)                                  # the sack
    c.ell(20.0, cy + 8.0, 13.0, 6.0, hide)
    for x in (10.0, 24.0):                                                           # folds
        c.vwire(x, cy + 2, cy + 12, dark['m'])
    for i, (x, y, r) in enumerate(((12.0, 19.0, 3.0), (20.0, 15.6, 3.6), (28.0, 18.6, 2.8), (8.0, 27.0, 2.4), (16.0, 24.0, 2.0), (25.0, 25.0, 2.2))):
        k = math.sin(2 * math.pi * (ph if walking else (pulse * 0.25 + 0.25)) + i * 1.7)
        rr = r + 0.8 * (k if walking else pulse * (1 if i % 2 else -1))
        c.ell(x, y + bob, rr, rr, boil)                                              # boils that rise and sink, out of step
        c.put(x, y + bob - 0.5, (250, 240, 190, 255))
    # the mouth: a ring of teeth where a face would be
    mr = 4.4 + 0.7 * pulse
    c.ell(33.0, cy + 2.0, mr, mr + 0.6, one('3a1420'))
    c.ell(33.4, cy + 2.0, mr * 0.45, mr * 0.5, one('8a2a3a'))
    teeth(c, [(33.0 + (mr - 0.6) * math.cos(a), cy + 2.0 + (mr - 0.2) * math.sin(a)) for a in [i * math.pi / 5.0 for i in range(10)]])
    for i, x in enumerate((29.0, 32.0, 35.0, 37.5)):                                 # small arms hanging under it, never still
        sw = 1.6 * math.sin(2 * math.pi * ph * (2 if walking else 1) + i * 1.3) if walking else 1.0 * pulse * (1 if i % 2 else -1)
        P.limb(c, (x, cy + 7.0), (x + sw, cy + 12.0), 1.6, dark)
        P.limb(c, (x + sw, cy + 12.0), (x + sw * 1.8 + 1.0, cy + 15.0), 1.2, dark)
    for k in (0, 2):                                                                 # near pillars
        f = step(ph + 0.5 * (k // 2), homes[k], 5.0 if walking else 0.0, 1.8)
        P.limb(c, (homes[k], 42.0 + bob), (f[0], f[1] - 1), 7.4, hide)
        c.rect(f[0] - 3, f[1], f[0] + 3, f[1], P.rgb('3a2a34'))


# ------------------------------------------------------------------------------------------------------------------------------------- longarm
def reach(c, ph, pulse, walking):
    skin, dark = T('6c7a5c'), T('3c4638')
    bob = 0.8 * math.sin(4 * math.pi * ph) if walking else 0.5 * pulse
    bx, by = 21.0, 20.0 + bob
    homes = (8.0, 16.0, 27.0, 35.0)
    feet = [step(ph + (0.0, 0.5, 0.25, 0.75)[k], homes[k], 5.0 if walking else 0.0, 4.0) for k in range(4)]
    elbows = ((8.0, 7.0), (14.0, 9.0), (29.0, 9.0), (35.0, 7.0))
    for k in (1, 3):                                                                 # far arms: up to an elbow above its back, then all the way down
        P.limb(c, (bx + (-2 if k < 2 else 2), by - 2.0), (elbows[k][0], elbows[k][1] + bob), 2.6, dark, near=False)
        P.limb(c, (elbows[k][0], elbows[k][1] + bob), (feet[k][0], feet[k][1]), 2.0, dark, near=False)
    for i, x in enumerate((19.0, 22.0)):                                             # withered legs that never reach the floor
        sw = 1.2 * math.sin(2 * math.pi * ph + i * 2.0) if walking else 0.6 * pulse
        P.limb(c, (x, by + 5.0), (x + sw, by + 12.0), 1.8, dark)
        P.limb(c, (x + sw, by + 12.0), (x + sw + 1.4, by + 16.0), 1.3, dark)
    c.ell(bx, by, 6.2, 6.8 + 0.5 * pulse, skin)                                      # the body, small and high
    c.ell(bx - 1.0, by - 4.4, 4.4, 2.6, skin)
    mr = 2.4 + 0.5 * pulse                                                           # a round sucking mouth underneath, at the front
    c.ell(bx + 3.2, by + 3.4, mr, mr, one('3a1420'))
    teeth(c, [(bx + 3.2 + (mr - 0.5) * math.cos(a), by + 3.4 + (mr - 0.5) * math.sin(a)) for a in [i * math.pi / 3.0 for i in range(6)]])
    for (x, y) in ((bx - 3.0, by - 3.0), (bx - 0.6, by - 4.4), (bx + 2.0, by - 3.2)):
        c.put(x, y, (236, 206, 90, 255))
    for k in (0, 2):                                                                 # near arms
        P.limb(c, (bx + (-3 if k < 2 else 3), by - 1.0), (elbows[k][0], elbows[k][1] + bob), 3.0, skin)
        P.limb(c, (elbows[k][0], elbows[k][1] + bob), (feet[k][0], feet[k][1]), 2.4, skin)
        c.ell(elbows[k][0], elbows[k][1] + bob, 1.9, 1.9, skin)
    for f in feet:                                                                   # hands: three fingers spread on the floor
        for d in (-2.0, 0.0, 2.0):
            P.limb(c, (f[0], f[1] - 1.0), (f[0] + d, f[1] + 0.6), 1.1, one('2a3028'))


# ------------------------------------------------------------------------------------------------------------------------------------- spitter
def gullet(c, ph, pulse, walking):
    hide, dark, acid = T('9c9468'), T('5c5840'), T('cfe04a', 0.74, 1.2)
    bob = 0.7 * math.sin(4 * math.pi * ph) if walking else 0.0
    f_far, f_near = step(ph + 0.5, 22.0, 7.0 if walking else 0.0, 2.6), step(ph, 17.0, 7.0 if walking else 0.0, 2.6)
    leg(c, (21.0, 44.0 + bob), (f_far[0], f_far[1] - 1), -3.0, 2.4, 1.6, dark, near=False)
    # the sack: most of it, behind and above, filling on the breath
    sr = 8.2 + 1.3 * pulse
    c.ell(12.6, 28.0 + bob, sr, sr + 0.8, acid)
    c.ell(11.0, 26.0 + bob, sr * 0.45, sr * 0.5, one(acid['ll']))
    for a in (0.6, 1.5, 2.6):                                                        # veins over it
        P.limb(c, (12.6, 28.0 + bob), (12.6 - sr * 0.95 * math.cos(a), 28.0 + bob - sr * 0.95 * math.sin(a)), 0.9, one('6a7a2a'))
    c.ell(19.5, 38.0 + bob, 6.4, 8.6, hide)                                          # the grub of a body
    for y in (33.0, 37.0, 41.0):
        c.wire(15, y + bob, 25, dark['m'])
    # the neck: a tube that aims
    P.limb(c, (22.0, 31.0 + bob), (27.0, 24.0 + bob), 4.6, hide)
    P.limb(c, (27.0, 24.0 + bob), (33.0, 22.6 + bob - 0.6 * pulse), 4.0, hide)
    c.ell(34.6, 22.4 + bob - 0.6 * pulse, 2.4, 2.6, one('3a1420'))                   # its end: a wet hole
    c.ell(34.9, 22.4 + bob - 0.6 * pulse, 1.0, 1.2, one(acid['m']))
    drip = int((ph * 12) % 4) if walking else int(2 + 2 * pulse)
    c.rect(35.0, 25.0 + bob, 35.0, 25.0 + bob + drip, acid['m'])
    for (x, y) in ((25.0, 27.6), (27.4, 25.6)):
        c.put(x, y + bob, (236, 206, 90, 255))
    P.limb(c, (22.0, 36.0 + bob), (27.0, 39.0 + bob + pulse), 1.8, dark)             # two small arms it does not seem to need
    P.limb(c, (27.0, 39.0 + bob + pulse), (29.0, 36.6 + bob + pulse), 1.3, dark)
    leg(c, (17.0, 44.0 + bob), (f_near[0], f_near[1] - 1), -3.4, 2.8, 1.8, hide)
    for f in (f_far, f_near):
        c.rect(f[0] - 1, f[1], f[0] + 3, f[1], P.rgb('3a3424'))


KINDS = {'standard': husk, 'crawler': louse, 'big': bulk, 'longarm': reach, 'spitter': gullet}


def frames(name, kind):
    """-> [(image, {})]: the idle breathes over 6 frames, the walk is the people's 12."""
    out = []
    n = P.WALK_N if kind == 'walk' else 6
    for i in range(n):
        c = P.Cel()
        if kind == 'walk':
            KINDS[name](c, i / float(n), math.sin(2 * math.pi * i / float(n) * 2.0), True)
        else:
            KINDS[name](c, 0.0, math.sin(2 * math.pi * i / 6.0), False)
        P._outline(c)
        out.append((c.im, {}))
    return out
