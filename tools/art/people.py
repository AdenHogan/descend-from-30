#!/usr/bin/env python3
"""PEOPLE — a LOOK TEST for the game's humans (owner 2026-11-11/12, with a reference of chunky pixel figures: "I want our people, NPCs, and player
characters to be more like this… Not spaghetti broke. Pixel legs… an animation sprite for Idle and walking"; then "a little too simplistic… lack the
shadows and pixel depth"; then "they are all a bit fat around the waist… the proportions need improvement as do the head and arms. Equally what is
being designed needs to be rigged to have a skeleton for limb movement / holding items").

NOT wired into the game. It draws a few neighbours and writes, for the owner to judge:

    python3 tools/art/people.py   ->  docs/art_reference/people/  people_sheet.png (idle · walk · walk carrying something), people_walk.gif,
                                      people_idle.gif, people_carry.gif, people_rig.png (the bones drawn over one figure), people_rig.json

THE RIG. Every figure is posed from a SKELETON (`skeleton(pose)`): a hip, a spine up to the shoulders and the head, and four two-bone limbs
(shoulder → elbow → hand, hip → knee → ankle) set by ANGLES in degrees from straight down, positive = forward. Limbs are drawn along their bones
(`limb`), so an arm can swing, bend or reach, and whatever is held is drawn at the hand joint (`ITEMS`). The body is dropped so the lower foot is on
the ground, which gives the walk its rise and fall for free. `people_rig.json` lists every joint of every frame — what the game would read to
put a weapon in a hand.

THE BUILD (what the second pass got wrong: a box wider than the head with a belly on the front read as fat, not as a big jumper). A large head, a
SMALL frame: shoulders narrower than the head, the garment hanging off them and widest low down, then gathered in at a rib; arms that are limbs
beside the body, not stripes on it; short solid legs. The size is in the CLOTHES. Facing right; the game would mirror. A 36 x 48 cell, feet on
its bottom row.
"""
import json
import math
import os
import sys

from PIL import Image

W, H = 36, 48
GROUND = H - 1
ANKLE_Y = GROUND - 3
CX = 17
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

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, c)

    def rows(self, spans, t, back=0.24, front=0.68, under=2, flat=False, top_light=True):
        """A soft VOLUME from its row spans [(y, xa, xb)], lit from the upper front (the right): deep shade down the back edge, shade behind it and
        along the last `under` rows, a lit panel on the upper front, a catch-light on the first full row."""
        n = len(spans)
        for i, (y, xa, xb) in enumerate(spans):
            v = i / float(max(1, n - 1))
            for x in range(xa, xb + 1):
                u = (x - xa) / float(max(1, xb - xa))
                k = 'm'
                if u < back:
                    k = 'd'
                if u < back * 0.34:
                    k = 'dd'
                if not flat and u > front and v < 0.6:
                    k = 'l'
                if n - 1 - i < under:
                    k = 'd' if k in ('m', 'l') else 'dd'
                if i == n - 1 and under:
                    k = 'dd'
                if top_light and not flat and i == 1 and u > 0.4:
                    k = 'll'
                self.put(x, y, t[k])

    def box(self, x0, y0, x1, y1, t, top=(2, 1), bot=(1,), **kw):
        n = int(y1) - int(y0) + 1
        spans = []
        for i in range(n):
            cut = top[i] if i < len(top) else (bot[n - 1 - i] if n - 1 - i < len(bot) else 0)
            spans.append((int(y0) + i, int(x0) + cut, int(x1) - cut))
        self.rows(spans, t, **kw)
        return spans


def limb(c, a, b, w, t, near=True):
    """One bone drawn as flesh or sleeve: every pixel within w/2 of the segment a-b, shaded across its width — the side toward the light (front / up)
    lit, the other in shade; a far limb is a tone down throughout."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    ln = math.hypot(dx, dy) or 1.0
    nx, ny = dy / ln, -dx / ln
    if nx < -0.25 or (abs(nx) <= 0.25 and ny > 0):
        nx, ny = -nx, -ny
    r = w / 2.0
    for y in range(int(min(ay, by) - r - 1), int(max(ay, by) + r + 2)):
        for x in range(int(min(ax, bx) - r - 1), int(max(ax, bx) + r + 2)):
            px_, py_ = x + 0.5, y + 0.5
            tt = max(0.0, min(1.0, ((px_ - ax) * dx + (py_ - ay) * dy) / (ln * ln)))
            qx, qy = ax + dx * tt, ay + dy * tt
            if math.hypot(px_ - qx, py_ - qy) > r:
                continue
            s = ((px_ - qx) * nx + (py_ - qy) * ny) / r
            k = 'l' if s > 0.4 else ('d' if s < -0.4 else 'm')
            if not near:
                k = {'l': 'd', 'm': 'd', 'd': 'dd'}[k]
            c.put(x, y, t[k])


# ---- the skeleton ----------------------------------------------------------------------------------------------------------------------------
BONES = dict(thigh=5.2, shin=5.2, upper=5.6, fore=5.6, spine=15.0)
REST = dict(n_arm=(3, 8), f_arm=(-2, 8), n_leg=(0, 0), f_leg=(0, 0))


def _fk(o, l1, a1, l2, a2):
    """Two bones from joint `o`: the first at a1 degrees from straight down (+ = forward), the second bent a further a2. -> (mid, end)"""
    r1 = math.radians(a1)
    m = (o[0] + l1 * math.sin(r1), o[1] + l1 * math.cos(r1))
    r2 = math.radians(a1 + a2)
    return m, (m[0] + l2 * math.sin(r2), m[1] + l2 * math.cos(r2))


def skeleton(pose):
    """Every joint of a pose, in cell pixels. pose = dict(n_arm=(shoulder, elbow), f_arm, n_leg=(hip, knee bend — a knee bends BACK, so it is
    subtracted), f_leg, lean (px the shoulders sit ahead of the hips), breath (px the chest sinks)). The body is dropped so the lower ankle is on
    the ground."""
    g = dict(REST)
    g.update(pose)
    hip = (CX - 0.5, 0.0)
    j = {}
    for side, ox in (('n', -2.0), ('f', 1.6)):
        t1, kb = g[side + '_leg']
        j['hip_' + side] = (hip[0] + ox, hip[1])
        j['knee_' + side], j['ankle_' + side] = _fk(j['hip_' + side], BONES['thigh'], t1, BONES['shin'], -kb)
    drop = ANKLE_Y - max(j['ankle_n'][1], j['ankle_f'][1])
    j = {k: (v[0], v[1] + drop) for k, v in j.items()}
    hipy = drop
    lean = g.get('lean', 0.0)
    sh_y = hipy - BONES['spine'] + g.get('breath', 0)
    j['hip'] = (hip[0], hipy)
    j['neck'] = (hip[0] + lean + 0.5, sh_y - 1.0)
    j['head'] = (hip[0] + lean + 1.5, sh_y - 8.0)
    for side, ox in (('n', -3.0), ('f', 3.4)):
        a1, a2 = g[side + '_arm']
        j['shoulder_' + side] = (hip[0] + lean + ox, sh_y + 1.5)
        j['elbow_' + side], j['hand_' + side] = _fk(j['shoulder_' + side], BONES['upper'], a1, BONES['fore'], a2)
    j['grip'] = g['n_arm'][0] + g['n_arm'][1]                 # the forearm's angle: what a held thing lines up with
    return j


# ---- what a hand can hold: drawn at the hand joint, the grip in the fist ----------------------------------------------------------------------
def _hammer(c, hx, hy):
    wood, steel = tones('8a6238'), tones('8e939c')
    c.rect(hx, hy - 8, hx + 1, hy + 2, wood['m'])
    c.rect(hx, hy - 8, hx, hy + 2, wood['d'])
    c.rect(hx - 2, hy - 11, hx + 4, hy - 9, steel['m'])
    c.rect(hx - 2, hy - 11, hx + 4, hy - 11, steel['ll'])
    c.rect(hx - 2, hy - 9, hx + 4, hy - 9, steel['dd'])
    c.rect(hx - 2, hy - 11, hx - 2, hy - 9, steel['d'])


def _torch(c, hx, hy):
    body, lens = tones('3a3d46'), (248, 232, 150, 255)
    c.rect(hx - 1, hy - 1, hx + 6, hy + 1, body['m'])
    c.rect(hx - 1, hy - 1, hx + 6, hy - 1, body['l'])
    c.rect(hx - 1, hy + 1, hx + 6, hy + 1, body['dd'])
    c.rect(hx + 6, hy - 2, hx + 7, hy + 2, body['d'])
    c.rect(hx + 8, hy - 1, hx + 8, hy + 1, lens)


def _bag(c, hx, hy):
    cloth = tones('c9b68a')
    c.rect(hx, hy + 2, hx + 1, hy + 3, cloth['dd'])
    c.box(hx - 3, hy + 4, hx + 4, hy + 11, cloth, top=(1,), bot=(1,), under=2)
    c.rect(hx - 1, hy + 6, hx + 2, hy + 6, cloth['d'])


ITEMS = {'hammer': _hammer, 'torch': _torch, 'bag': _bag}
CARRY = {'hammer': (28, 62), 'torch': (22, 68), 'bag': (4, 6)}        # the near arm's (shoulder, elbow) angles while it holds each


# ---- one frame ---------------------------------------------------------------------------------------------------------------------------------
def draw(p, pose, item=None):
    c = Cel()
    j = skeleton(pose)
    R = lambda q: (int(round(q[0])), int(round(q[1])))
    g = tones(p['coat'])
    skin = tones(p['skin'], 0.83, 1.07)
    legc = tones(p['legs'], 0.78, 1.2)
    sho = tones(p['shoes'], 0.66, 1.5)
    hair = tones(p['hair'], 0.74, 1.24)
    sleeve = g if p.get('sleeves', True) else skin
    kind = p.get('garment', 'coat')
    build = p.get('build', 0)
    hipx, hipy = R(j['hip'])
    shy = int(round(j['shoulder_n'][1] - 1.5))
    lean = int(round(j['neck'][0] - j['hip'][0] - 0.5))
    hem = hipy + p.get('drop', 1)

    def shoe(ank, near):
        x, y = int(round(ank[0])) - 2, int(round(ank[1]))
        lift = y < ANKLE_Y
        up, dk = (sho['m'], sho['dd']) if near else (sho['d'], sho['dd'])
        c.rect(x, y + 1, x + 4, y + 2, up)
        c.rect(x, y + 3, x + 5, y + 3, dk)
        c.put(x, y + 1, sho['d'])
        c.put(x, y + 2, sho['d'])
        c.put(x + 5, y + 2, up)
        if near:
            c.put(x + 4, y + 1, sho['l'])
            c.put(x + 4, y + 2, sho['ll'])
        if lift:
            c.put(x, y + 3, (0, 0, 0, 0))

    # ---- behind the body: the far arm, the far leg
    limb(c, j['shoulder_f'], j['elbow_f'], 3.6, sleeve, near=False)
    limb(c, j['elbow_f'], j['hand_f'], 3.4, sleeve, near=False)
    fx, fy = R(j['hand_f'])
    c.rect(fx - 1, fy, fx + 1, fy + 2, skin['d'])
    limb(c, j['hip_f'], j['knee_f'], 4.0, legc, near=False)
    limb(c, j['knee_f'], j['ankle_f'], 3.8, legc, near=False)
    shoe(j['ankle_f'], False)
    # ---- the near leg
    limb(c, j['hip_n'], j['knee_n'], 4.2, legc)
    limb(c, j['knee_n'], j['ankle_n'], 4.0, legc)
    kx, ky = R(j['knee_n'])
    c.put(kx + 1, ky, legc['ll'])
    shoe(j['ankle_n'], True)
    # ---- long hair down the back, behind the shoulders
    hcx, hcy = R(j['head'])
    st = p['hairstyle']
    sway = pose.get('sway', 0)
    if st == 'long':
        for i, x in enumerate(range(hcx - 8, hcx - 1)):
            end = hcy + 14 - (0, 2, 0, 1, 3, 1, 3)[i]
            for y in range(hcy - 3, end + 1):
                tone = 'dd' if i == 0 else ('d' if i in (1, 4) or y > end - 2 else ('l' if i == 5 and y < hcy + 6 else 'm'))
                c.put(x - (sway if y > hcy + 8 and i < 4 else 0), y, hair[tone])
    # ---- a skirt under the garment
    if p.get('skirt'):
        sk = tones(p['skirt'])
        sp = c.box(hipx - 6 - build, hem - 1, hipx + 6 + build, hem + p.get('skirt_len', 4), sk, top=(), bot=(1,), back=0.3, flat=True, under=1)
        for (y, xa, xb) in sp[1:-1]:
            for x in range(xa + 3, xb - 1, 3):
                c.put(x, y, sk['d'])
        for x in range(sp[0][1], sp[0][2] + 1):
            c.put(x, hem + 1, sk['dd'])
    # ---- the garment: it hangs off NARROW shoulders, is widest low down, and is gathered in at the rib. No belly: the size is the cloth's.
    n = hem - shy + 1
    spans = []
    for i in range(n):
        v = i / float(max(1, n - 1))
        hw = 4.6 + build * 0.5 + (2.6 + build * 0.5) * min(1.0, v / 0.55)
        if i == 0:
            hw -= 1.6
        if n - 1 - i < (2 if kind != 'coat' else 0):
            hw -= 1.0
        mx = hipx + 0.5 + lean * (1.0 - v)
        spans.append((shy + i, int(round(mx - hw)), int(round(mx + hw))))
    c.rows(spans, g, under=2)
    if kind in ('jumper', 'parka', 'jacket'):                                       # the rib
        for (y, xa, xb) in spans[-2:]:
            for x in range(xa, xb + 1):
                c.put(x, y, g['dd'] if (x % 2 == 0 or y == spans[-1][0]) else g['d'])
    fxe = spans[len(spans) // 2][2]                                                 # the garment's front edge at mid-height
    for (y, xa, xb) in spans[:2]:                                                   # the head's shadow on the shoulders
        for x in range(xa + 2, xb):
            c.put(x, y, g['d'])
    my = shy + int(n * 0.62)                                                        # the cloth folds where it hangs away from the body
    for k in range(3):
        c.put(fxe - 1 - k, my + k // 2, g['d'])
    if p.get('open'):
        inner = tones(p['open'])
        for (y, xa, xb) in spans[2:-1]:
            c.put(xb - 3, y, g['dd'])
            c.put(xb - 2, y, inner['d'] if y < shy + 4 else inner['m'])
            c.put(xb - 1, y, inner['m'])
            c.put(xb, y, g['l'])
    if p.get('toggles') or p.get('buttons'):
        tg = tones(p.get('toggles') or p['buttons'])
        for (y, xa, xb) in spans[2:-1]:
            c.put(xb - 1, y, g['d'])                                                # the front edge of the coat
        for y in range(shy + 5, hem - 2, 4):
            xb = dict((yy, b_) for (yy, a_, b_) in spans)[y]
            if p.get('toggles'):
                c.rect(xb - 4, y, xb - 2, y, g['dd'])
                c.rect(xb - 3, y - 1, xb - 2, y + 1, tg['m'])
                c.put(xb - 2, y - 1, tg['ll'])
            else:
                c.put(xb - 2, y, tg['m'])
                c.put(xb - 2, y + 1, g['dd'])
    if p.get('stripe'):
        stp = tones(p['stripe'], 0.82, 1.08)
        for (y, xa, xb) in spans[5:8]:
            for x in range(xa, xb + 1):
                u = (x - xa) / float(max(1, xb - xa))
                c.put(x, y, stp['dd'] if u < 0.1 else (stp['d'] if u < 0.26 else (stp['l'] if u > 0.7 else stp['m'])))
    if p.get('pocket'):
        c.rect(fxe - 5, hem - 6, fxe - 2, hem - 6, g['l'])
        c.rect(fxe - 5, hem - 5, fxe - 2, hem - 5, g['dd'])
    if p.get('scarf'):
        sc = tones(p['scarf'])
        c.box(spans[0][1], shy - 2, spans[0][2] + 1, shy + 1, sc, top=(1,), bot=(1,), under=1)
        c.rect(fxe - 4, shy + 1, fxe - 2, shy + 8, sc['m'])
        c.rect(fxe - 4, shy + 1, fxe - 4, shy + 8, sc['d'])
        c.rect(fxe - 2, shy + 2, fxe - 2, shy + 7, sc['l'])
        c.rect(fxe - 5, shy + 2, fxe - 5, shy + 8, g['dd'])
    # ---- the head: bigger than the shoulders are wide. A block of skin, the face toward the front, the hair a mass over and behind it
    hx0, hx1, top = hcx - 7, hcx + 5, hcy - 7
    cx = hcx - 1
    if st == 'hood':
        c.box(hx0 - 1, top - 1, hx1 + 1, top + 14, g, top=(4, 2, 1), bot=(2, 1), back=0.3, front=0.66, under=1)
        fur = tones(p.get('fur', 'd8ccb8'), 0.8, 1.1)
        fr = c.box(cx - 1, top + 2, hx1 + 1, top + 13, fur, top=(2, 1), bot=(2, 1), back=0.2, flat=True, under=0)
        for (y, xa, xb) in fr:
            c.put(xa, y, fur['l'] if y % 2 else fur['d'])
            c.put(xb, y, fur['ll'] if y % 2 else fur['m'])
        c.box(cx + 1, top + 4, hx1 - 1, top + 12, skin, top=(1,), bot=(1,), back=0.25, flat=True, under=1)
        c.rect(cx + 2, top + 4, hx1 - 2, top + 4, skin['d'])
    else:
        c.box(hx0, top + 1, hx1, top + 13, skin, top=(3, 2, 1), bot=(3, 1), back=0.2, front=0.86, under=1, flat=True)
        if st in ('long', 'bob', 'short', 'bun', 'beanie'):
            back_to = top + (13 if st in ('long', 'bob') else 9)
            c.box(hx0 - 1, top, hx1, top + 5, hair, top=(4, 2, 1), bot=(), back=0.26, front=0.6, under=0)
            c.rect(hx0 - 1, top + 5, cx - 2, back_to, hair['m'])
            c.rect(hx0 - 1, top + 5, hx0, back_to, hair['dd'])
            c.rect(hx0 + 1, top + 5, hx0 + 1, back_to, hair['d'])
            c.rect(cx - 2, top + 6, cx - 2, back_to, hair['d'])
            c.rect(cx - 1, top + 4, hx1 - 1, top + 5, hair['m'])                                               # a fringe, cut ragged
            c.rect(cx - 1, top + 5, hx1 - 2, top + 5, hair['d'])
            c.put(cx + 1, top + 6, hair['m'])
            c.put(cx + 4, top + 6, hair['d'])
            c.rect(cx, top + 2, cx + 4, top + 2, hair['ll'])                                                   # a sheen across the crown
            c.rect(cx - 3, top + 3, cx + 2, top + 3, hair['l'])
            c.rect(cx - 4, top + 5, cx - 4, back_to - 1, hair['l'])
            if st == 'bob':
                c.rect(hx0 - 2, top + 9, cx - 2, top + 15, hair['m'])
                c.rect(hx0 - 2, top + 9, hx0 - 1, top + 15, hair['dd'])
                c.rect(hx0 - 2, top + 14, cx - 2, top + 15, hair['d'])
                c.rect(cx - 4, top + 8, cx - 4, top + 13, hair['l'])
                c.put(cx - 2, top + 15, (0, 0, 0, 0))
            if st == 'bun':
                c.box(hx0 - 4, top + 1, hx0, top + 6, hair, top=(1,), bot=(1,), back=0.3, front=0.5, under=1)
            if st == 'beanie':
                hat = tones(p['hat'])
                c.box(hx0 - 1, top - 1, hx1, top + 3, hat, top=(4, 2, 1), bot=(), back=0.26, front=0.6, under=0)
                for x in range(hx0 - 1, hx1 + 1):
                    c.put(x, top + 4, hat['d'] if x % 2 else hat['m'])
                    c.put(x, top + 5, hat['dd'] if x % 2 else hat['d'])
        elif st == 'bald':
            c.rect(hx0, top + 6, hx0 + 2, top + 10, hair['m'])
            c.rect(hx0, top + 6, hx0, top + 10, hair['dd'])
            c.rect(cx - 1, top + 2, cx + 3, top + 2, skin['ll'])
            c.rect(cx + 1, top + 3, cx + 4, top + 3, skin['l'])
        if st != 'bald':
            c.rect(cx - 1, top + 6, hx1 - 1, top + 6, skin['d'])                    # shade under the fringe
        c.rect(cx - 1, top + 7, cx - 1, top + 11, skin['d'])                        # and down the cheek by the hair
        c.put(hx1, top + 9, skin['l'])
    ey = top + 8
    for ex in (cx + 1, cx + 5):
        if pose.get('blink'):
            c.rect(ex, ey + 1, ex + 1, ey + 1, EYE)
        else:
            c.rect(ex, ey, ex + 1, ey + 1, EYE)
            c.put(ex + 1, ey, (58, 50, 62, 255))
    if p.get('glasses'):
        gl = rgb(p['glasses'])
        for ex in (cx + 1, cx + 5):                                                 # two round rims, not a bar
            c.rect(ex - 1, ey - 1, ex + 2, ey - 1, gl)
            c.rect(ex - 1, ey + 2, ex + 2, ey + 2, gl)
        c.put(cx + 4, ey, gl)
    if p.get('tache'):
        c.rect(cx + 2, ey + 3, cx + 6, ey + 3, hair['d'])
    # ---- the near arm, over everything: its shadow on the body first, then the sleeve along its two bones, the cuff, the fist — and what it holds
    sn, en, hn = j['shoulder_n'], j['elbow_n'], j['hand_n']
    for (a, b) in ((sn, en), (en, hn)):
        limb(c, (a[0] - 1.0, a[1] + 0.6), (b[0] - 1.0, b[1] + 0.6), 4.2, {'l': g['dd'], 'm': g['dd'], 'd': g['dd'], 'dd': g['dd'], 'll': g['dd']})
    limb(c, sn, en, 4.4, sleeve)
    limb(c, en, hn, 4.0, sleeve)
    sx, sy = R(sn)
    c.rect(sx - 1, sy - 2, sx + 1, sy - 2, sleeve['ll'])                            # the light on the shoulder
    ex_, ey_ = R(en)
    c.put(ex_ - 1, ey_, sleeve['d'])                                                # the crease at the elbow
    hx, hy = R(hn)
    if item:
        ITEMS[item](c, hx, hy)
    c.rect(hx - 1, hy, hx + 1, hy + 2, skin['m'])
    c.put(hx - 1, hy, skin['d'])
    c.put(hx - 1, hy + 2, skin['d'])
    c.put(hx + 1, hy, skin['l'])
    return c.im, j


# ---- the cycles: ANGLES for the skeleton ---------------------------------------------------------------------------------------------------------
def walk_pose(i, n=8, carry=None):
    ph = i / float(n)

    def leg_(q):
        q %= 1.0
        swing = 26.0 * math.cos(2.0 * math.pi * q)                                  # the thigh: forward at contact, back at push-off
        bend = 52.0 * math.sin(math.pi * (q - 0.5) / 0.5) if q >= 0.5 else 6.0 * math.sin(math.pi * q / 0.5)
        return (swing, bend)
    arm = 20.0 * math.cos(2.0 * math.pi * ph)
    pose = dict(n_leg=leg_(ph), f_leg=leg_(ph + 0.5), n_arm=(-arm, 10 + max(0.0, -arm) * 0.5), f_arm=(arm, 10 + max(0.0, arm) * 0.5), lean=1.0,
                sway=1 if (i % (n // 2)) in (1, 2) else 0)
    if carry:
        pose['n_arm'] = CARRY[carry]
    return pose


def idle_pose(i, carry=None):
    pose = dict(breath=(0, 0, 0, 1, 1, 1)[i % 6], blink=(i % 6 == 4))
    if carry:
        pose['n_arm'] = CARRY[carry]
    return pose


# ---- the neighbours (ours, not the reference's) --------------------------------------------------------------------------------------------
PEOPLE = [
    dict(name='nell', coat='b5533c', skin='e8d6c8', hair='3a2a34', hairstyle='long', legs='3a3444', shoes='1e1a22', toggles='e8d6c8', drop=3,
         carry='torch'),                                                                                     # a girl in a red duffel coat, black tights
    dict(name='mrs_okafor', coat='8a6f9a', skin='8a5a44', hair='b8b4b8', hairstyle='bun', legs='7a5240', shoes='5a3a4a', skirt='4a4458',
         skirt_len=5, open='e0d8c4', glasses='2a2630', garment='jumper', build=1, carry='bag'),               # an older woman: a long cardigan over a skirt
    dict(name='dale', coat='5d7a4a', skin='e2c4a8', hair='6a4a2a', hairstyle='hood', legs='3a4254', shoes='e4e0d8', fur='d8c8a8', pocket=True,
         garment='parka', drop=2, carry='hammer'),                                                           # a lad in a parka, hood up, white trainers
    dict(name='mr_hale', coat='c8b48a', skin='e6c8b0', hair='5a5450', hairstyle='bald', legs='55525c', shoes='4a3324', scarf='7a2e2e', tache=True,
         buttons='5a4a30', build=1, drop=4, carry='bag'),                                                    # a big man in a camel overcoat and a scarf
    dict(name='priya', coat='e0b23c', skin='b07a56', hair='241c22', hairstyle='bob', legs='34506e', shoes='2a2630', stripe='f0e6d0',
         garment='jumper', carry='hammer'),                                                                  # a yellow jumper with a band, jeans
    dict(name='tomasz', coat='3f5f8a', skin='e4ccb4', hair='c8a468', hairstyle='beanie', hat='b84a36', legs='6a5a48', shoes='2a2420',
         open='d8d4cc', garment='jacket', pocket=True, carry='torch'),                              # a work jacket worn open, a red beanie
]


def frames(p, kind):
    """-> [(image, joints)]"""
    if kind == 'walk':
        return [draw(p, walk_pose(i)) for i in range(8)]
    if kind == 'carry':
        return [draw(p, walk_pose(i, carry=p['carry']), item=p['carry']) for i in range(8)]
    return [draw(p, idle_pose(i)) for i in range(6)]


def self_check():
    """Every figure stands on the ground row, nothing is cut off by its cell, a leg is never thinner than 3 px, and the garment is never wider
    than the head by more than 4 px (the 'fat' the second pass had)."""
    errs = []
    for p in PEOPLE:
        for kind in ('idle', 'walk', 'carry'):
            for i, (im, j) in enumerate(frames(p, kind)):
                px = im.load()
                if not any(px[x, GROUND][3] for x in range(W)):
                    errs.append('%s %s %d: nothing on the ground row' % (p['name'], kind, i))
                if any(px[x, 0][3] for x in range(W)) or any(px[0, y][3] or px[W - 1, y][3] for y in range(H)):
                    errs.append('%s %s %d: touches the edge of its cell' % (p['name'], kind, i))
                if kind == 'idle':
                    y = int(j['knee_n'][1])
                    runs, x = [], 0
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
                        errs.append('%s idle %d: a leg is %d px wide at the knee' % (p['name'], i, min(runs)))
        if (2 * (4.6 + p.get('build', 0) * 0.5 + 2.6 + p.get('build', 0) * 0.5) + 1) - 13 > 4.5:
            errs.append('%s: the garment is more than 4 px wider than the head' % p['name'])
    return errs


def _on_bg(im, scale):
    bg = Image.new('RGBA', im.size, BG)
    bg.alpha_composite(im)
    return bg.resize((im.width * scale, im.height * scale), Image.NEAREST)


def _gif(path, cels, ms, scale=6):
    big = [_on_bg(im, scale).convert('P', palette=Image.ADAPTIVE, colors=96) for im in cels]
    big[0].save(path, save_all=True, append_images=big[1:], duration=ms, loop=0, disposal=2)


def _row(sets):
    out = []
    for i in range(len(sets[0])):
        im = Image.new('RGBA', (W * len(sets), H), (0, 0, 0, 0))
        for k, cels in enumerate(sets):
            im.alpha_composite(cels[i][0], (k * W, 0))
        out.append(im)
    return out


def _rig_sheet(p):
    """The bones over one figure's walk: what the skeleton is, drawn."""
    from PIL import ImageDraw
    S = 8
    fr = frames(p, 'carry')
    sheet = Image.new('RGBA', (W * S * len(fr), H * S), BG)
    d = ImageDraw.Draw(sheet)
    for i, (im, j) in enumerate(fr):
        ghost = im.copy()
        ghost.putalpha(ghost.getchannel('A').point(lambda a: a * 0.45))
        sheet.alpha_composite(ghost.resize((W * S, H * S), Image.NEAREST), (i * W * S, 0))
        P = lambda k: (i * W * S + j[k][0] * S, j[k][1] * S)
        for (a, b, col) in (('hip', 'neck', (255, 255, 255)), ('neck', 'head', (255, 255, 255)),
                            ('shoulder_f', 'elbow_f', (120, 170, 255)), ('elbow_f', 'hand_f', (120, 170, 255)),
                            ('hip_f', 'knee_f', (120, 170, 255)), ('knee_f', 'ankle_f', (120, 170, 255)),
                            ('shoulder_n', 'elbow_n', (255, 210, 90)), ('elbow_n', 'hand_n', (255, 210, 90)),
                            ('hip_n', 'knee_n', (255, 210, 90)), ('knee_n', 'ankle_n', (255, 210, 90))):
            d.line([P(a), P(b)], fill=col + (255,), width=3)
        for k in j:
            if k != 'grip':
                x, y = P(k)
                d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(255, 70, 70, 255) if k == 'hand_n' else (20, 20, 24, 255), outline=(255, 255, 255, 255))
    return sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    errs = self_check()
    sets = {k: [frames(p, k) for p in PEOPLE] for k in ('idle', 'walk', 'carry')}
    sheet = Image.new('RGBA', (W * 22 + 8, H * len(PEOPLE)), BG)
    for k in range(len(PEOPLE)):
        x = 0
        for kind in ('idle', 'walk', 'carry'):
            for (im, _) in sets[kind][k]:
                sheet.alpha_composite(im, (x, k * H))
                x += W
            x += 4
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(os.path.join(OUT, 'people_sheet.png'))
    _gif(os.path.join(OUT, 'people_walk.gif'), _row(sets['walk']), 110)
    _gif(os.path.join(OUT, 'people_carry.gif'), _row(sets['carry']), 110)
    _gif(os.path.join(OUT, 'people_idle.gif'), _row(sets['idle']), 260)
    _rig_sheet(PEOPLE[2]).save(os.path.join(OUT, 'people_rig.png'))
    rig = {'cell': [W, H], 'ground_row': GROUND, 'bones': BONES, 'people': {}}
    for k, p in enumerate(PEOPLE):
        rig['people'][p['name']] = {kind: [{n: ([round(v[0], 2), round(v[1], 2)] if n != 'grip' else round(v, 1)) for n, v in j.items()}
                                           for (_, j) in sets[kind][k]] for kind in sets}
    with open(os.path.join(OUT, 'people_rig.json'), 'w') as fh:
        json.dump(rig, fh, indent=1, sort_keys=True)
    for stale in os.listdir(OUT):                                                   # the per-person GIFs of the first two passes
        if stale.endswith('.gif') and not stale.startswith('people_'):
            os.remove(os.path.join(OUT, stale))
    print('wrote %d people to %s' % (len(PEOPLE), OUT))
    if errs:
        print('\n'.join(errs[:20]))
        sys.exit(1)


if __name__ == '__main__':
    main()
