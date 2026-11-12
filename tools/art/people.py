#!/usr/bin/env python3
"""PEOPLE — a LOOK TEST for the game's humans (owner 2026-11-11, with a reference of chunky pixel figures: "I want our people, NPCs, and player
characters to be more like this… increase the size so you can perfect a best version of a few different NPCs with that bulky cartoon pixel
style… Not spaghetti broke. Pixel legs… an animation sprite for Idle and walking").

NOT wired into the game. It draws a few neighbours in that manner and writes a sheet and looping GIFs for the owner to judge:

    python3 tools/art/people.py            ->  docs/art_reference/people/people_sheet.png, people_walk.gif, people_idle.gif, <name>_walk.gif, <name>_idle.gif

The manner: a person is a few BIG soft masses — hair, a coat or jumper far too large, a pale face that is two dark eyes — on short SOLID legs
(four pixels wide, a lit near leg and a shaded far one, a shoe with a toe), no outlines. Every mass is a VOLUME in five tones lit from the upper front (`Cel.vol`):
deep shade down the back and underneath, a lit panel, a catch-light on the shoulder; then the things that make cloth cloth — the shadow a sleeve throws
on the coat, a fold where the belly turns under, a rib, a pocket flap, toggles, the head's shadow on the shoulders, the hem's on the legs. Every figure is built from the
same parts posed by data (`pose`), so a leg is the same width in every frame and one body can be re-dressed. Facing right; the game would
mirror. Feet on the bottom row of a 36 x 46 cell.
"""
import math
import os
import sys

from PIL import Image

W, H = 36, 46
GROUND = H - 1
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, '..', '..', 'docs', 'art_reference', 'people'))
EYE = (22, 18, 24, 255)
BG = (126, 124, 128, 255)


def rgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def tones(h, dk=0.80, lt=1.13):
    """Five tones of one colour: dd (deep shade) / d (shade) / m / l (lit) / ll (the catch-light). The shade leans cool and the light warm, the
    way the reference's do — a darker copy of the same hue reads flat."""
    r, g, b, _ = rgb(h)

    def f(k, warm):
        return (max(0, min(255, int(r * k + warm * 10))), max(0, min(255, int(g * k + warm * 3))), max(0, min(255, int(b * k - warm * 12))), 255)
    return {'dd': f(dk * dk * 0.92, -1.2), 'd': f(dk, -0.6), 'm': rgb(h), 'l': f(lt, 0.6), 'll': f(lt * lt, 1.0)}


class Cel:
    def __init__(self):
        self.im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        self.px = self.im.load()

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = c

    def has(self, x, y):
        return 0 <= x < W and 0 <= y < H and self.px[int(x), int(y)][3] > 0

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, c)

    def vol(self, x0, y0, x1, y1, t, top=(2, 1), bot=(1,), belly=0, back=0.24, front=0.70, under=0.84, flat=False):
        """A soft VOLUME lit from the upper front (the right): the corners are cut by `top` / `bot`, the front edge swells by `belly` px over its
        lower half, and every pixel takes its tone from where it sits on the form — deep shade down the back edge and along the underside, shade
        behind that, a lit panel on the upper front, a catch-light along the top of the shoulder. Returns the rows it filled: [(y, xa, xb)]."""
        rows = int(y1) - int(y0) + 1
        out = []
        for i in range(rows):
            y = int(y0) + i
            cut = top[i] if i < len(top) else (bot[rows - 1 - i] if rows - 1 - i < len(bot) else 0)
            v = i / float(max(1, rows - 1))
            sw = belly if 0.42 <= v <= 0.9 and cut == 0 else 0
            xa, xb = int(x0) + cut, int(x1) - cut + sw
            out.append((y, xa, xb))
            for x in range(xa, xb + 1):
                u = (x - xa) / float(max(1, xb - xa))
                k = 'm'
                if u < back:
                    k = 'd'
                if u < back * 0.34:
                    k = 'dd'
                if not flat and u > front and v < 0.62:
                    k = 'l'
                if v > under:
                    k = 'd' if k in ('m', 'l') else 'dd'
                if i == rows - 1:
                    k = 'dd'
                if not flat and i == len(top) - 1 and u > 0.45:
                    k = 'll'
                self.put(x, y, t[k])
        return out


def leg(c, hx, hy, fx, fy, knee, col, w=4, near=True):
    """A solid leg `w` wide from the hip (hx, hy) to the ankle (fx, fy), the knee pushed forward by `knee` px at the middle: shaded down its back,
    lit down its shin, darker where the coat's hem throws its shadow, a catch-light on the knee."""
    n = max(1, int(fy) - int(hy))
    for i in range(n + 1):
        t = i / float(n)
        x = hx + (fx - hx) * t + knee * 4.0 * t * (1.0 - t)
        xi = int(round(x))
        for k in range(w):
            tone = 'd' if k == 0 else ('l' if (k == w - 1 and near) else 'm')
            if i <= 2:                                                # under the hem
                tone = {'l': 'm', 'm': 'd', 'd': 'dd'}[tone]
            if not near:
                tone = {'l': 'd', 'm': 'd', 'd': 'dd', 'dd': 'dd'}[tone]
            c.put(xi + k, int(hy) + i, col[tone])
        if near and abs(t - 0.5) < 0.5 / n + 0.01:
            c.put(xi + w - 1, int(hy) + i, col['ll'])


def shoe(c, fx, fy, col, lift=0, long=6, near=True):
    """The shoe under an ankle whose left pixel is fx: an upper, a toe out in front with a light on it, a dark sole. A lifted foot tips."""
    x = int(round(fx))
    up, dk = (col['m'], col['dd']) if near else (col['d'], col['dd'])
    c.rect(x, fy, x + 3, fy, up)
    c.rect(x, fy + 1, x + long - 2, fy + 1, up)
    c.rect(x, fy + 2, x + long - 1, fy + 2, dk)
    c.put(x, fy, col['d'])
    c.put(x, fy + 1, col['d'])
    if near:
        c.put(x + long - 3, fy + 1, col['l'])
        c.put(x + long - 2, fy + 1, col['ll'])
    if lift:
        c.put(x, fy + 2, (0, 0, 0, 0))                       # the heel comes up first
        c.put(x + long - 1, fy + 3, dk)


def draw(p, pose):
    """One frame of person `p` in `pose` = dict(bob, near=(dx, lift, knee), far=(dx, lift, knee), arm (px the near hand swings forward), sway, blink)."""
    c = Cel()
    bob = pose.get('bob', 0)
    cx = 17
    tw = p['torso_w']
    x0, x1 = cx - tw // 2, cx - tw // 2 + tw - 1
    top = p['top'] + bob                                      # the crown of the head
    sh = top + 12                                             # the shoulder line
    hem = p['hem']                                            # the garment's last row (it does not bob: the body sinks INTO its legs)
    g = tones(p['coat'])
    skin = tones(p['skin'], 0.83, 1.07)
    legc = tones(p['legs'], 0.78, 1.2)
    sho = tones(p['shoes'], 0.66, 1.5)
    hair = tones(p['hair'], 0.74, 1.24)
    ankle = GROUND - 2
    arm = pose.get('arm', 0)
    st = p['hairstyle']

    # ---- behind the body: the far arm, the far leg
    fdx, flift, fknee = pose['far']
    ndx, nlift, nknee = pose['near']
    hip_y = hem - 2
    leg(c, cx + 2, hip_y, cx + 2 + fdx, ankle - flift, fknee, legc, near=False)
    shoe(c, cx + 2 + fdx, ankle - flift, sho, flift, near=False)
    c.rect(x1 - 1 - arm, sh + 4, x1 + 1 - arm, hem - 5, g['d'])                    # the far sleeve, a sliver at the front edge
    c.rect(x1 + 1 - arm, sh + 5, x1 + 1 - arm, hem - 6, g['m'])
    c.rect(x1 - 1 - arm, hem - 5, x1 + 1 - arm, hem - 5, g['dd'])
    c.rect(x1 - arm, hem - 4, x1 + 1 - arm, hem - 3, skin['d'])                    # and its hand
    # ---- the near leg
    leg(c, cx - 5, hip_y, cx - 5 + ndx, ankle - nlift, nknee, legc)
    shoe(c, cx - 5 + ndx, ankle - nlift, sho, nlift)
    # ---- long hair down the back goes BEHIND the coat's shoulder: strands, a ragged end, dark underneath
    sway = pose.get('sway', 0)
    if st == 'long':
        hb = top + 22
        for i, x in enumerate(range(cx - 9, cx - 1)):
            end = hb - (0, 2, 0, 1, 3, 1, 2, 4)[i] - (sway if i < 3 else 0)
            for y in range(top + 3, end + 1):
                tone = 'dd' if i == 0 else ('d' if i in (1, 4) or y > end - 2 else ('l' if i == 6 and y < top + 14 else 'm'))
                c.put(x - (sway if y > top + 16 and i < 4 else 0), y, hair[tone])
    # ---- a skirt or a long hem under the coat
    if p.get('skirt'):
        sk = tones(p['skirt'])
        rows = c.vol(x0 + 1, hem - 1, x1 - 1, hem + p.get('skirt_len', 3), sk, top=(), bot=(1,), back=0.3, flat=True)
        for (y, xa, xb) in rows[1:-1]:                                              # pleats
            for x in range(xa + 4, xb - 1, 4):
                c.put(x, y, sk['d'])
        for x in range(rows[0][1], rows[0][2] + 1):                                 # the coat's shadow on it
            c.put(x, hem + 1, sk['dd'])
    # ---- the coat: one big soft volume, shoulders rounded, a belly, the underside in shade
    rows = c.vol(x0, sh, x1, hem, g, top=(4, 2, 1), bot=(1,), belly=p.get('belly', 1))
    kind = p.get('garment', 'coat')
    if kind in ('jumper', 'parka', 'jacket'):                                       # a ribbed band round the bottom
        for (y, xa, xb) in rows[-3:-1]:
            for x in range(xa, xb + 1):
                c.put(x, y, g['dd'] if (x % 2 == 0 or y == rows[-2][0]) else g['d'])
    for (y, xa, xb) in rows[:2]:                                                    # the head's shadow on the shoulders
        for x in range(max(xa, cx - 5), min(xb, cx + 5) + 1):
            c.put(x, y, g['d'])
    by = sh + int((hem - sh) * 0.58)                                                # a fold where the belly turns under, and one off the far shoulder
    for k in range(4):
        c.put(x1 - 2 - k, by + (k // 2), g['d'])
    for k in range(3):
        c.put(x1 - 3 - k, sh + 4 + k, g['d'])
    if p.get('open'):                                                              # worn open: what is under it shows down the front
        inner = tones(p['open'])
        c.rect(x1 - 4, sh + 2, x1 - 2, hem - 1, inner['m'])
        c.rect(x1 - 4, sh + 2, x1 - 4, hem - 1, inner['d'])
        c.rect(x1 - 4, sh + 2, x1 - 2, sh + 3, inner['d'])
        c.rect(x1 - 5, sh + 2, x1 - 5, hem, g['dd'])
        c.rect(x1 - 1, sh + 3, x1 - 1, hem - 1, g['l'])
        for y in range(sh + 5, hem - 2, 3):
            c.put(x1 - 3, y, inner['dd'])
    if p.get('lapel'):                                                             # a collar turned down: a V of shade and its lit edge
        for k in range(5):
            c.put(x1 - 4 - k // 2, sh + 1 + k, g['dd'])
            c.put(x1 - 3 - k // 2, sh + 1 + k, g['l'])
    if p.get('toggles'):                                                           # a duffel coat's toggles, each on its loop
        tg = tones(p['toggles'])
        for y in range(sh + 6, hem - 4, 5):
            c.rect(x1 - 6, y, x1 - 3, y, g['dd'])
            c.rect(x1 - 4, y - 1, x1 - 3, y + 1, tg['m'])
            c.put(x1 - 3, y - 1, tg['ll'])
        c.rect(x1 - 2, sh + 4, x1 - 2, hem - 2, g['d'])                             # the front edge of the coat
    if p.get('buttons'):
        bt = tones(p['buttons'])
        for y in range(sh + 5, hem - 2, 4):
            c.put(x1 - 3, y, bt['m'])
            c.put(x1 - 3, y + 1, g['dd'])
        c.rect(x1 - 2, sh + 4, x1 - 2, hem - 2, g['d'])
    if p.get('pocket'):                                                            # a pocket flap with its shadow under it
        c.rect(cx + 2, hem - 9, cx + 6, hem - 9, g['l'])
        c.rect(cx + 2, hem - 8, cx + 6, hem - 8, g['dd'])
        c.put(cx + 6, hem - 7, g['d'])
    if p.get('stripe'):                                                            # a band round the chest, shaded with the body it goes round
        stp = tones(p['stripe'], 0.82, 1.08)
        for (y, xa, xb) in rows[6:9]:
            for x in range(xa, xb + 1):
                u = (x - xa) / float(max(1, xb - xa))
                c.put(x, y, stp['dd'] if u < 0.1 else (stp['d'] if u < 0.26 else (stp['l'] if u > 0.7 else stp['m'])))
    if p.get('drawstrings'):
        ds = rgb(p['drawstrings'])
        c.rect(x1 - 5, sh + 2, x1 - 5, sh + 7, ds)
        c.rect(x1 - 3, sh + 2, x1 - 3, sh + 6, ds)
    # ---- the near arm: a sleeve hanging down the side — its own volume, the shadow it throws on the coat behind it, a crease at the elbow, a cuff
    ax = cx - 4 + arm
    top_ax = cx - 4 + (1 if arm > 0 else (-1 if arm < 0 else 0))
    a0, a1 = sh + 3, hem - 4
    for y in range(a0, a1 + 1):
        t = (y - a0) / float(max(1, a1 - a0))
        xx = int(round(top_ax + (ax - top_ax) * t))
        c.put(xx - 1, y, g['dd'])                                                   # its shadow on the body
        for k, tone in enumerate(('d', 'm', 'm', 'l', 'd')):
            c.put(xx + k, y, g[tone])
        if y == a0:
            for k in range(1, 4):
                c.put(xx + k, y, g['ll'])
    ey_ = a0 + (a1 - a0) // 2                                                       # the elbow
    xe = int(round(top_ax + (ax - top_ax) * 0.5))
    c.put(xe + 1, ey_, g['d'])
    c.put(xe + 2, ey_ + 1, g['d'])
    c.put(xe + 3, ey_ + 1, g['m'])
    c.rect(ax - 1, a1 + 1, ax + 4, a1 + 1, g['dd'])                                # the cuff
    if kind in ('jumper', 'parka', 'jacket'):
        c.rect(ax, a1, ax + 3, a1, g['d'])
    c.rect(ax, a1 + 2, ax + 2, a1 + 3, skin['m'])                                  # the hand
    c.put(ax, a1 + 2, skin['d'])
    c.put(ax, a1 + 3, skin['d'])
    c.put(ax + 2, a1 + 2, skin['l'])
    if p.get('scarf'):
        sc = tones(p['scarf'])
        c.vol(x0 + 3, sh - 1, x1 - 1, sh + 2, sc, top=(1,), bot=(1,), back=0.2, front=0.6)
        c.rect(x1 - 5, sh + 2, x1 - 3, sh + 9, sc['m'])
        c.rect(x1 - 5, sh + 2, x1 - 5, sh + 9, sc['d'])
        c.rect(x1 - 3, sh + 3, x1 - 3, sh + 8, sc['l'])
        c.rect(x1 - 6, sh + 3, x1 - 6, sh + 9, g['dd'])
        for x in (x1 - 5, x1 - 3):                                                  # the fringe
            c.put(x, sh + 10, sc['d'])
    # ---- the head: a block of skin, the face toward the front, the hair a mass over and behind it
    hx0, hx1 = cx - 6, cx + 6
    if st == 'hood':
        c.vol(hx0 - 1, top, hx1 + 1, top + 14, g, top=(4, 2, 1), bot=(1,), back=0.3, front=0.66)
        fur = tones(p.get('fur', 'd8ccb8'), 0.8, 1.1)
        fr = c.vol(cx - 2, top + 2, hx1 + 1, top + 13, fur, top=(2, 1), bot=(2, 1), back=0.2, flat=True)
        for (y, xa, xb) in fr:                                                      # the trim is tufted, not a smooth ring
            c.put(xa, y, fur['l'] if y % 2 else fur['d'])
            c.put(xb, y, fur['ll'] if y % 2 else fur['m'])
        c.vol(cx, top + 4, hx1 - 1, top + 12, skin, top=(1,), bot=(1,), back=0.3, flat=True)
        c.rect(cx, top + 4, hx1 - 2, top + 5, skin['d'])                            # the hood's shadow across the brow
    else:
        hd = c.vol(hx0, top + 1, hx1, top + 13, skin, top=(3, 2, 1), bot=(3, 2), back=0.2, front=0.86, under=0.9, flat=True)
        if st in ('long', 'bob', 'short', 'bun', 'beanie'):
            back_to = top + (13 if st in ('long', 'bob') else 9)
            cap = c.vol(hx0 - 1, top, hx1, top + 5, hair, top=(4, 2, 1), bot=(), back=0.26, front=0.6, under=2.0)
            c.rect(hx0 - 1, top + 5, cx - 2, back_to, hair['m'])                                               # down the back of the head
            c.rect(hx0 - 1, top + 5, hx0, back_to, hair['dd'])
            c.rect(hx0 + 1, top + 5, hx0 + 1, back_to, hair['d'])
            c.rect(cx - 2, top + 6, cx - 2, back_to, hair['d'])                                                # where it meets the face
            c.rect(cx - 1, top + 4, hx1 - 1, top + 5, hair['m'])                                               # a fringe, cut ragged
            c.put(cx + 1, top + 6, hair['m'])
            c.put(cx + 4, top + 6, hair['d'])
            c.rect(cx - 1, top + 5, hx1 - 2, top + 5, hair['d'])
            c.rect(cx, top + 2, cx + 4, top + 2, hair['ll'])                                                   # a sheen across the crown
            c.rect(cx - 3, top + 3, cx + 2, top + 3, hair['l'])
            for x in (hx0 + 2, cx - 4):                                                                        # strands
                c.rect(x, top + 4, x, back_to - 1, hair['l'] if x > hx0 + 2 else hair['d'])
            if st == 'bob':
                c.rect(hx0 - 2, top + 9, cx - 2, top + 15, hair['m'])
                c.rect(hx0 - 2, top + 9, hx0 - 1, top + 15, hair['dd'])
                c.rect(hx0 - 2, top + 14, cx - 2, top + 15, hair['d'])
                c.rect(cx - 4, top + 8, cx - 4, top + 13, hair['l'])
                c.put(cx - 2, top + 15, (0, 0, 0, 0))
            if st == 'bun':
                c.vol(hx0 - 4, top + 1, hx0, top + 6, hair, top=(1,), bot=(1,), back=0.3, front=0.5)
                c.put(hx0 - 1, top + 3, hair['dd'])
            if st == 'beanie':
                hat = tones(p['hat'])
                c.vol(hx0 - 1, top - 1, hx1, top + 3, hat, top=(4, 2, 1), bot=(), back=0.26, front=0.6, under=2.0)
                for x in range(hx0 - 1, hx1 + 1):                                                              # the turned-up rib
                    c.put(x, top + 4, hat['d'] if x % 2 else hat['m'])
                    c.put(x, top + 5, hat['dd'] if x % 2 else hat['d'])
                c.rect(cx - 1, top - 2, cx + 1, top - 2, hat['l'])
        elif st == 'bald':
            c.rect(hx0, top + 6, hx0 + 2, top + 10, hair['m'])                                                 # what is left, round the back
            c.rect(hx0, top + 6, hx0, top + 10, hair['dd'])
            c.rect(hx0 + 1, top + 9, hx0 + 2, top + 10, hair['d'])
            c.rect(cx - 1, top + 2, cx + 3, top + 2, skin['ll'])                                               # the light on the dome
            c.rect(cx + 1, top + 3, cx + 4, top + 3, skin['l'])
        # the face's own shade: under the fringe, down the cheek by the hair, under the chin
        if st != 'bald':
            c.rect(cx - 1, top + 6, hx1 - 1, top + 6, skin['d'])
        c.rect(cx - 1, top + 7, cx - 1, top + 11, skin['d'])
        c.put(hx1 - 1, top + 9, skin['l'])
        c.put(hx1, top + 9, skin['l'])                                              # the nose is a lit pixel on the front edge, nothing drawn
    # ---- the face: two dark eyes, a light under each (a blink is one row)
    ey = top + 8
    for ex in (cx + 1, cx + 5):
        if pose.get('blink'):
            c.rect(ex, ey + 1, ex + 1, ey + 1, EYE)
        else:
            c.rect(ex, ey, ex + 1, ey + 1, EYE)
            c.put(ex + 1, ey, (58, 50, 62, 255))
    if p.get('glasses'):
        gl = rgb(p['glasses'])
        c.rect(cx, ey - 1, cx + 7, ey - 1, gl)
        c.put(cx + 3, ey, gl)
        c.put(cx + 4, ey, gl)
        c.put(cx - 1, ey - 1, gl)
    if p.get('tache'):
        c.rect(cx + 2, ey + 3, cx + 6, ey + 3, hair['d'])
        c.put(cx + 2, ey + 4, hair['d'])
    return c.im


# ---- the cycles -------------------------------------------------------------------------------------------------------------------------
STRIDE = 3.0


def _leg_at(ph):
    """(dx, lift, knee) of one leg at phase `ph` of the walk: on the ground it goes back under the body, then it lifts, bends and swings forward."""
    ph %= 1.0
    if ph < 0.5:
        return (int(round(STRIDE - 2.0 * STRIDE * (ph / 0.5))), 0, 0.0)
    u = (ph - 0.5) / 0.5
    return (int(round(-STRIDE + 2.0 * STRIDE * u)), int(round(2.2 * math.sin(math.pi * u))), 0.6 * math.sin(math.pi * u))


def walk_pose(i, n=8):
    ph = i / float(n)
    near = _leg_at(ph)
    far = _leg_at(ph + 0.5)
    return dict(near=near, far=far, bob=1 if i % (n // 2) == 0 else 0, arm=int(round(-2.0 * math.cos(2.0 * math.pi * ph))),
                sway=1 if (i % (n // 2)) in (1, 2) else 0)


def idle_pose(i):
    return dict(near=(0, 0, 0.0), far=(0, 0, 0.0), bob=(0, 0, 0, 1, 1, 1)[i % 6], arm=0, sway=0, blink=(i % 6 == 4))


# ---- the neighbours (ours, not the reference's) --------------------------------------------------------------------------------------------
PEOPLE = [
    dict(name='nell', top=4, torso_w=18, hem=35, coat='b5533c', skin='e8d6c8', hair='3a2a34', hairstyle='long', legs='3a3444', shoes='1e1a22',
         pocket=True, toggles='e8d6c8'),                                                                     # a girl in a red duffel coat, black tights
    dict(name='mrs_okafor', top=6, torso_w=20, hem=34, coat='8a6f9a', skin='8a5a44', hair='b8b4b8', hairstyle='bun', legs='7a5240', shoes='5a3a4a',
         skirt='4a4458', skirt_len=5, open='e0d8c4', glasses='2a2630', garment='jumper', belly=2),                                      # an older woman: a long cardigan over a skirt, slippers
    dict(name='dale', top=3, torso_w=20, hem=33, coat='5d7a4a', skin='e2c4a8', hair='6a4a2a', hairstyle='hood', legs='3a4254', shoes='e4e0d8',
         fur='d8c8a8', pocket=True, garment='parka', drawstrings='d8d4c4'),                                                                         # a lad in a parka, hood up, joggers, white trainers
    dict(name='mr_hale', top=3, torso_w=22, hem=33, coat='c8b48a', skin='e6c8b0', hair='5a5450', hairstyle='bald', legs='55525c', shoes='4a3324',
         scarf='7a2e2e', tache=True, buttons='5a4a30', pocket=True, belly=2),                                                      # a big man in a camel overcoat and a scarf
    dict(name='priya', top=5, torso_w=18, hem=33, coat='e0b23c', skin='b07a56', hair='241c22', hairstyle='bob', legs='34506e', shoes='2a2630',
         stripe='f0e6d0', garment='jumper'),                                                                                   # a yellow jumper with a band, jeans
    dict(name='tomasz', top=4, torso_w=19, hem=32, coat='3f5f8a', skin='e4ccb4', hair='c8a468', hairstyle='beanie', hat='b84a36', legs='6a5a48',
         shoes='2a2420', open='d8d4cc', garment='jacket', pocket=True),                                                                     # a blue work jacket worn open, a red beanie
]


def frames(p, kind):
    if kind == 'walk':
        return [draw(p, walk_pose(i)) for i in range(8)]
    return [draw(p, idle_pose(i)) for i in range(6)]


def self_check():
    """A leg is `w` solid pixels in every frame, every figure stands on the ground row, and nothing is cut off by the cell."""
    errs = []
    for p in PEOPLE:
        for kind in ('idle', 'walk'):
            for i, im in enumerate(frames(p, kind)):
                px = im.load()
                if not any(px[x, GROUND][3] for x in range(W)):
                    errs.append('%s %s %d: nothing on the ground row' % (p['name'], kind, i))
                if any(px[x, 0][3] for x in range(W)) or any(px[0, y][3] or px[W - 1, y][3] for y in range(H)):
                    errs.append('%s %s %d: touches the edge of its cell' % (p['name'], kind, i))
                for y in range(p['hem'] + (p.get('skirt_len', 0) if p.get('skirt') else 0) + 2, GROUND - 3):
                    runs = []
                    x = 0
                    while x < W:
                        if px[x, y][3]:
                            x1 = x
                            while x1 + 1 < W and px[x1 + 1, y][3]:
                                x1 += 1
                            runs.append(x1 - x + 1)
                            x = x1 + 1
                        else:
                            x += 1
                    if runs and min(runs) < 3:
                        errs.append('%s %s %d: a leg is %d px wide on row %d' % (p['name'], kind, i, min(runs), y))
    return errs


def _gif(path, cels, ms, scale=6):
    big = []
    for im in cels:
        bg = Image.new('RGBA', im.size, BG)
        bg.alpha_composite(im)
        big.append(bg.resize((im.width * scale, im.height * scale), Image.NEAREST).convert('P', palette=Image.ADAPTIVE, colors=64))
    big[0].save(path, save_all=True, append_images=big[1:], duration=ms, loop=0, disposal=2)


def _row(cels_per_person):
    n = len(cels_per_person[0])
    out = []
    for i in range(n):
        im = Image.new('RGBA', (W * len(cels_per_person), H), (0, 0, 0, 0))
        for k, cels in enumerate(cels_per_person):
            im.alpha_composite(cels[i], (k * W, 0))
        out.append(im)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    errs = self_check()
    walks = [frames(p, 'walk') for p in PEOPLE]
    idles = [frames(p, 'idle') for p in PEOPLE]
    sheet = Image.new('RGBA', (W * 14 + 4, H * len(PEOPLE)), BG)
    for k in range(len(PEOPLE)):
        for i, im in enumerate(idles[k]):
            sheet.alpha_composite(im, (i * W, k * H))
        for i, im in enumerate(walks[k]):
            sheet.alpha_composite(im, (6 * W + 4 + i * W, k * H))
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(os.path.join(OUT, 'people_sheet.png'))
    _gif(os.path.join(OUT, 'people_walk.gif'), _row(walks), 110)
    _gif(os.path.join(OUT, 'people_idle.gif'), _row(idles), 260)
    for p, wk, idl in zip(PEOPLE, walks, idles):
        _gif(os.path.join(OUT, '%s_walk.gif' % p['name']), wk, 110, scale=8)
        _gif(os.path.join(OUT, '%s_idle.gif' % p['name']), idl, 260, scale=8)
    print('wrote %d people to %s' % (len(PEOPLE), OUT))
    if errs:
        print('\n'.join(errs[:20]))
        sys.exit(1)


if __name__ == '__main__':
    main()
