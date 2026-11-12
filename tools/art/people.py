#!/usr/bin/env python3
"""PEOPLE — a LOOK TEST for the game's humans (owner 2026-11-11/12, with a reference of chunky pixel figures: "I want our people, NPCs, and player
characters to be more like this… Not spaghetti broke. Pixel legs… an animation sprite for Idle and walking"; then "a little too simplistic… lack the
shadows and pixel depth"; then "they are all a bit fat around the waist… the proportions need improvement as do the head and arms. Equally what is
being designed needs to be rigged to have a skeleton for limb movement / holding items").

NOT wired into the game. It draws a few neighbours and writes, for the owner to judge:

    python3 tools/art/people.py   ->  docs/art_reference/people/  people_sheet.png (idle · walk · walk carrying something), people_walk.gif,
                                      people_idle.gif, people_carry.gif, people_moods.png / .gif (every mood), people_faces.png,
                                      people_rig.png (the bones drawn over one figure), people_rig.json

THE RIG. Every figure is posed from a SKELETON (`skeleton(pose)`): a hip, a spine up to the shoulders and the head, and four two-bone limbs
(shoulder → elbow → hand, hip → knee → ankle) set by ANGLES in degrees from straight down, positive = forward. Limbs are drawn along their bones
(`limb`), so an arm can swing, bend or reach, and whatever is held is drawn at the hand joint (`ITEMS`). The body is dropped so the lower foot is on
the ground, which gives the walk its rise and fall for free. `people_rig.json` lists every joint of every frame — what the game would read to
put a weapon in a hand.

ROUND, CLEAN, STYLISED (owner, of the third pass: "I don't like how sort of blocky they are when the original I sent looks more rounded and clean"):
every mass is an ellipse or a curve — a round head, a dome of hair wrapping it, a soft oval face, shoulders that slope out of the neck, a hem that turns
under — toned in a few clean curved bands (`Cel.rows`), with the fiddly marks of the second pass (ribs, strands, tufts, creases) taken out.

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

    def rows(self, spans, t, flat=False, **_):
        """A ROUNDED volume from its row spans [(y, xa, xb)], lit from the upper front (the right). Each pixel is toned by where it sits on the
        form (u across, v down, as if it were the surface of something round), in a FEW CLEAN BANDS — a lit crescent toward the light, the body
        tone, a shade crescent round the back and underneath, a thin deep edge — never per-pixel noise (owner: "more rounded and clean and stylised")."""
        n = len(spans)
        for i, (y, xa, xb) in enumerate(spans):
            v = 2.0 * i / float(max(1, n - 1)) - 1.0
            for x in range(xa, xb + 1):
                u = 2.0 * (x - xa) / float(max(1, xb - xa)) - 1.0
                lit = 0.62 * u - 0.66 * v
                k = 'm'
                if lit < -0.42:
                    k = 'd'
                if lit < -1.02:
                    k = 'dd'
                if not flat and lit > 0.58:
                    k = 'l'
                if not flat and lit > 1.04:
                    k = 'll'
                self.put(x, y, t[k])

    def ell(self, cx, cy, rx, ry, t, keep=None, **kw):
        """An ellipse as a rounded volume; `keep(x, y)` clips it. Returns its spans."""
        spans = []
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            xs = [x for x in range(int(cx - rx - 1), int(cx + rx + 2))
                  if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0 and (keep is None or keep(x, y))]
            if xs:
                spans.append((y, min(xs), max(xs)))
        self.rows(spans, t, **kw)
        return spans

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
    c.ell(fx + 0.5, fy + 1.5, 1.7, 1.7, {k: skin['d'] for k in skin})
    limb(c, j['hip_f'], j['knee_f'], 4.0, legc, near=False)
    limb(c, j['knee_f'], j['ankle_f'], 3.8, legc, near=False)
    shoe(j['ankle_f'], False)
    # ---- the near leg
    limb(c, j['hip_n'], j['knee_n'], 4.2, legc)
    limb(c, j['knee_n'], j['ankle_n'], 4.0, legc)
    kx, ky = R(j['knee_n'])
    shoe(j['ankle_n'], True)
    # ---- long hair down the back, behind the shoulders
    hcx, hcy = R(j['head'])
    st = p['hairstyle']
    sway = pose.get('sway', 0)
    if st == 'long':                                                                # one smooth drape down the back, its end rounded
        c.ell(hcx - 4.0 - 0.4 * sway, hcy + 6.0, 4.4, 10.5, hair)
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
    wide = 7.0 + build * 0.6
    for i in range(n):
        v = i / float(max(1, n - 1))
        t_ = min(1.0, v / 0.7)
        hw = 3.6 + (wide - 3.6) * math.sin(t_ * math.pi / 2.0) ** 0.8                # round shoulders sloping out of the neck
        under = n - 1 - i
        if under < 3:                                                               # and the hem turns under on a curve
            hw -= (3.0 - math.sqrt(9.0 - (3 - under - 0.5) ** 2)) * 0.9
        mx = hipx + 0.5 + lean * (1.0 - v)
        spans.append((shy + i, int(round(mx - hw)), int(round(mx + hw))))
    c.rows(spans, g)
    fxe = spans[len(spans) // 2][2]                                                 # the garment's front edge at mid-height
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
    # ---- the head: ROUND, bigger than the shoulders are wide. Hair is one dome that wraps the top and the back; the face is a soft oval set into
    # its front; two dark eyes high on it. No corners anywhere.
    hx, hy = hcx - 0.5, hcy - 0.5
    face = lambda x, y: ((x + 0.5 - hx - 1.9) / 4.7) ** 2 + ((y + 0.5 - hy - 1.5) / 5.3) ** 2 <= 1.0
    skull = lambda x, y: ((x + 0.5 - hx) / 6.6) ** 2 + ((y + 0.5 - hy) / 7.0) ** 2 <= 1.0
    if st == 'hood':
        fur = tones(p.get('fur', 'd8ccb8'), 0.8, 1.1)
        c.ell(hx, hy, 7.4, 7.8, g)
        c.ell(hx + 1.6, hy + 1.2, 5.6, 6.2, fur, flat=True)                          # a clean ring of trim round the face
        c.ell(hx + 1.9, hy + 1.5, 4.5, 5.1, skin, flat=True)
    else:
        c.ell(hx, hy, 6.6, 7.0, skin, flat=True)
        if st in ('long', 'bob'):
            c.ell(hx, hy, 6.9, 7.3, hair, keep=lambda x, y: not face(x, y) or y < hy - 3.6)
            if st == 'bob':
                c.ell(hx - 3.2, hy + 4.0, 4.4, 5.6, hair, keep=lambda x, y: not face(x, y))
        elif st in ('short', 'bun', 'beanie'):
            c.ell(hx, hy, 6.9, 7.3, hair, keep=lambda x, y: (y < hy - 2.6 or (x < hx - 2.6 and y < hy + 3.5)) and not (face(x, y) and y >= hy - 3.6))
            if st == 'bun':
                c.ell(hx - 6.6, hy - 3.6, 2.7, 2.7, hair)
            if st == 'beanie':
                hat = tones(p['hat'])
                c.ell(hx, hy - 0.6, 7.2, 7.6, hat, keep=lambda x, y: y < hy - 2.6)
                c.ell(hx, hy - 0.6, 7.2, 7.6, {k: hat['d'] for k in hat}, keep=lambda x, y: hy - 4.6 <= y < hy - 2.6)
        elif st == 'bald':
            c.ell(hx - 4.6, hy + 1.6, 2.0, 2.8, hair, keep=skull)
            c.ell(hx + 0.5, hy - 3.6, 2.6, 1.4, {k: skin['l'] for k in skin})        # the light on the dome
    # ---- the FACE (owner, of the fourth pass: "is there anything you can do to give them more facial personality"). Still a few clean marks, but each
    # person's OWN: the eyes' size and set, brows that say a mood, a mouth, and one or two things only they have (see `FACES`).
    f = dict(FACE_DEFAULT)
    f.update(p.get('face', {}))
    f.update(MOODS.get(pose.get('mood') or 'calm', {}).get('face', {}))             # the mood changes brows, eyes and mouth; what is the person's own stays
    _put = c.put
    c.put = lambda x, y, col: _put(x, y, col) if face(x, y) else None             # nothing of the face is ever drawn off the face
    ew, eh = f['eye']
    eh += f.get('eye_grow', 0)
    shut = pose.get('blink') or f.get('squint')
    ex0, ey = int(round(hx - 1.0)) + f.get('dx', 0), int(round(hy + 1.0)) + f.get('dy', 0)
    ex1 = ex0 + ew + f['gap']
    brow = hair['dd'] if st != 'bald' else tones(p['hair'])['d']
    lid = skin['d']
    if f.get('bags'):                                                               # tired: a shadow under each eye
        for ex in (ex0, ex1):
            c.rect(ex, ey + eh, ex + ew - 1, ey + eh, lid)
    if f.get('cheek'):                                                              # colour in the cheek
        ck = rgb(f['cheek'])
        c.rect(ex1 + 0, ey + eh + 1, ex1 + 1, ey + eh + 1, ck)
        c.put(ex0 - 1, ey + eh + 1, ck)
    if f.get('glasses'):                                                            # spectacles: a pale lens behind each eye, a dark rim over it, a bridge
        gl = rgb(f['glasses'])
        for ex in (ex0, ex1):
            c.rect(ex - 1, ey - 1, ex + ew, ey + eh, (206, 214, 220, 255))
            c.rect(ex - 1, ey - 2, ex + ew, ey - 2, gl)
        c.rect(ex0 + ew + 1, ey - 1, ex1 - 2, ey - 1, gl)
    for ex in (ex0, ex1):
        if shut:
            c.rect(ex, ey + eh - 1, ex + ew - 1, ey + eh - 1, EYE)
        else:
            c.rect(ex, ey, ex + ew - 1, ey + eh - 1, EYE)
            if f.get('glint') and eh >= 2:
                c.put(ex + ew - 1, ey, (236, 232, 226, 255))
            if f.get('lids'):                                                       # heavy lids: the top row of the eye is skin shade
                c.rect(ex, ey, ex + ew - 1, ey, lid)
    b = f.get('brow')
    if b:
        by = ey - 2
        for k, ex in enumerate((ex0, ex1)):
            inner = ex + ew - 1 if k == 0 else ex                                   # the end of each brow nearest the other eye
            outer = ex if k == 0 else ex + ew - 1
            if b == 'flat':
                c.rect(ex, by, ex + ew - 1, by, brow)
            elif b == 'worried':                                                    # inner ends UP
                c.put(inner, by - 1, brow)
                c.put(outer, by, brow)
                if ew > 2:
                    c.put((inner + outer) // 2, by, brow)
            elif b == 'stern':                                                      # inner ends DOWN, hard on the eye
                c.put(outer, by - 1 + 1, brow)
                c.put(inner, by + 1, brow)
                c.put(outer, by, brow)
            elif b == 'raised':
                c.rect(ex, by - 1, ex + ew - 1, by - 1, brow)
            elif b == 'heavy':
                c.rect(ex - (1 if k == 0 else 0), by, ex + ew - (0 if k == 0 else 0), by, brow)
                c.rect(ex, by + 1, ex + ew - 1, by + 1, brow) if eh < 2 else None
    mx, my_ = (ex0 + ex1 + ew) // 2, ey + eh + 2
    m = f.get('mouth')
    mouth = tones(p['skin'], 0.62, 1.0)['d']
    if m == 'line':
        c.rect(mx - 1, my_, mx + 1, my_, mouth)
    elif m == 'small':
        c.rect(mx, my_, mx + 1, my_, mouth)
    elif m == 'smile':
        c.rect(mx - 1, my_, mx + 1, my_, mouth)
        c.put(mx - 2, my_ - 1, mouth)
        c.put(mx + 2, my_ - 1, mouth)
    elif m == 'frown':
        c.rect(mx - 1, my_, mx + 1, my_, mouth)
        c.put(mx - 2, my_ + 1, mouth)
        c.put(mx + 2, my_ + 1, mouth)
    elif m == 'o':                                                                  # a mouth open a little: a breath, a fright
        c.rect(mx, my_, mx + 1, my_ + 1, (70, 34, 40, 255))
    elif m == 'lips':
        c.rect(mx - 1, my_, mx + 1, my_, rgb(f.get('lip', 'a8463e')))
    if f.get('nose'):
        c.put(ex1 + ew - 1 + (1 if ew < 3 else 0), ey + eh, skin['d'])
    for (dx_, dy_) in f.get('freckles', ()):
        c.put(ex0 + dx_, ey + eh + dy_, tones(p['skin'], 0.8, 1.0)['d'])
    if f.get('wrinkle'):                                                            # lines of age: beside the eye, by the mouth
        c.put(ex0 - 1, ey + 1, lid)
        c.put(mx - 3, my_ - 1, lid)
        c.put(mx + 3, my_ - 1, lid)
    if f.get('mole'):
        c.put(mx + 2, my_ - 1, EYE)
    if f.get('stubble'):
        stb = tones(p['skin'], 0.74, 1.0)['d']
        for x in range(mx - 3, mx + 4):
            for y in range(my_ + 1, my_ + 3):
                if (x + y) % 2 == 0 and face(x, y):
                    c.put(x, y, stb)
    if f.get('tache') or p.get('tache'):
        c.rect(mx - 2, my_ - 1, mx + 2, my_ - 1, hair['d'])
        c.put(mx - 3, my_, hair['d'])
        c.put(mx + 3, my_, hair['d'])
    if f.get('beard'):
        for y in range(my_ - 1, int(hy + 8)):
            for x in range(int(hx - 4), int(hx + 8)):
                if face(x, y) and not (my_ <= y <= my_ and mx - 1 <= x <= mx + 1):
                    c.put(x, y, hair['m'] if x > mx - 2 else hair['d'])
    c.put = _put
    if f.get('earring'):
        c.put(int(hx - 3), int(hy + 4), rgb(f['earring']))
    # ---- the near arm, over everything: its shadow on the body first, then the sleeve along its two bones, the cuff, the fist — and what it holds
    sn, en, hn = j['shoulder_n'], j['elbow_n'], j['hand_n']
    for (a, b) in ((sn, en), (en, hn)):
        limb(c, (a[0] - 1.0, a[1] + 0.6), (b[0] - 1.0, b[1] + 0.6), 4.2, {'l': g['dd'], 'm': g['dd'], 'd': g['dd'], 'dd': g['dd'], 'll': g['dd']})
    limb(c, sn, en, 4.4, sleeve)
    limb(c, en, hn, 4.0, sleeve)
    sx, sy = R(sn)
    c.rect(sx - 1, sy - 2, sx + 1, sy - 2, sleeve['ll'])                            # the light on the shoulder
    ex_, ey_ = R(en)
    hx, hy = R(hn)
    if item:
        ITEMS[item](c, hx, hy)
    c.ell(hx + 0.5, hy + 1.5, 1.9, 1.9, skin)                                       # a round fist
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


def idle_pose(i, carry=None, mood=None):
    pose = dict(breath=(0, 0, 0, 1, 1, 1)[i % 6], blink=(i % 6 == 4))
    if mood:
        extra = dict(MOODS[mood]['pose'])
        extra['breath'] = extra.get('breath', 0) + pose['breath']
        pose.update(extra)
        pose['mood'] = mood
    if carry:
        pose['n_arm'] = CARRY[carry]
    return pose


FACE_DEFAULT = dict(eye=(2, 2), gap=2)

# ---- MOODS (owner: "dynamic emotions… when they are attacked or saved their visual attitude can change based on context"). A mood is DATA laid over
# the person's own face — brows, the eyes' openness, the mouth, colour in the cheek — plus a change to the skeleton's pose (hands up, a flinch, a
# slump). What is theirs (freckles, a beard, spectacles, the set of their eyes) stays, so a frightened Mr Hale is still Mr Hale. The game would set
# `pose['mood']` from what has just happened to them; nothing here decides WHEN.
MOODS = {
    'calm': dict(face={}, pose={}),                                                                       # their own face
    'wary': dict(face=dict(brow='flat', mouth='line', lids=True, glint=False), pose=dict(lean=-0.6)),                    # watching you, not sure yet
    'scared': dict(face=dict(brow='worried', mouth='o', eye_grow=1, glint=True, lids=False, bags=False),
                   pose=dict(n_arm=(38, 96), f_arm=(30, 100), lean=-1.2)),                                # hands up in front, leaning away
    'hurt': dict(face=dict(brow='stern', mouth='frown', squint=True), pose=dict(n_arm=(18, 110), lean=1.6, breath=1)),   # eyes screwed shut, a hand to the body
    'angry': dict(face=dict(brow='stern', mouth='frown', lids=False, glint=False, cheek='c8685a'), pose=dict(n_arm=(-8, 30), f_arm=(-10, 34), lean=1.0)),
    'sad': dict(face=dict(brow='worried', mouth='frown', lids=True, glint=False), pose=dict(lean=0.8, breath=1, n_arm=(1, 3), f_arm=(-1, 3))),
    'relieved': dict(face=dict(brow='raised', mouth='smile', lids=False, bags=False, cheek='e8a8a0'), pose=dict()),      # saved: the face opens
    'grateful': dict(face=dict(brow='raised', mouth='smile', squint=True, cheek='e8a8a0'), pose=dict(n_arm=(24, 118))),   # eyes creased in a smile, a hand to the chest
}


# ---- the neighbours (ours, not the reference's) --------------------------------------------------------------------------------------------
PEOPLE = [
    dict(name='nell', face=dict(eye=(2, 3), gap=2, glint=True, brow='worried', mouth='small', cheek='e8a8a0', freckles=((0, 1), (3, 1))), coat='b5533c', skin='e8d6c8', hair='3a2a34', hairstyle='long', legs='3a3444', shoes='1e1a22', toggles='e8d6c8', drop=3,
         carry='torch'),                                                                                     # a girl in a red duffel coat, black tights
    dict(name='mrs_okafor', face=dict(eye=(2, 2), gap=3, dx=-1, mouth='smile', wrinkle=True, glasses='3a2a2a', earring='e8c860'), coat='8a6f9a', skin='8a5a44', hair='b8b4b8', hairstyle='bun', legs='7a5240', shoes='5a3a4a', skirt='4a4458',
         skirt_len=5, open='e0d8c4', garment='jumper', build=1, carry='bag'),               # an older woman: a long cardigan over a skirt
    dict(name='dale', face=dict(eye=(2, 2), gap=2, lids=True, bags=True, brow='flat', mouth='line', stubble=True), coat='5d7a4a', skin='e2c4a8', hair='6a4a2a', hairstyle='hood', legs='3a4254', shoes='e4e0d8', fur='d8c8a8', pocket=True,
         garment='parka', drop=2, carry='hammer'),                                                           # a lad in a parka, hood up, white trainers
    dict(name='mr_hale', face=dict(eye=(1, 2), gap=3, brow='heavy', mouth='frown', nose=True, cheek='d89a88', tache=True), coat='c8b48a', skin='e6c8b0', hair='5a5450', hairstyle='bald', legs='55525c', shoes='4a3324', scarf='7a2e2e', tache=True,
         buttons='5a4a30', build=1, drop=4, carry='bag'),                                                    # a big man in a camel overcoat and a scarf
    dict(name='priya', face=dict(eye=(2, 2), gap=2, glint=True, brow='stern', mouth='lips', lip='8a3a34', mole=True, earring='f0e6d0'), coat='e0b23c', skin='b07a56', hair='241c22', hairstyle='bob', legs='34506e', shoes='2a2630', stripe='f0e6d0',
         garment='jumper', carry='hammer'),                                                                  # a yellow jumper with a band, jeans
    dict(name='tomasz', face=dict(eye=(2, 2), gap=2, brow='flat', mouth='o', beard=True), coat='3f5f8a', skin='e4ccb4', hair='c8a468', hairstyle='beanie', hat='b84a36', legs='6a5a48', shoes='2a2420',
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
                    for mood in MOODS:                                               # every mood draws, inside the cell
                        mi, _ = draw(p, idle_pose(i, mood=mood))
                        mp = mi.load()
                        if any(mp[x, 0][3] for x in range(W)) or any(mp[0, y][3] or mp[W - 1, y][3] for y in range(H)):
                            errs.append('%s %s: touches the edge of its cell' % (p['name'], mood))
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
    # the moods: every person in every mood, labelled, and a loop that goes through them
    from PIL import ImageDraw
    names = list(MOODS)
    S = 5
    ms = Image.new('RGBA', (W * S * len(names), (H * len(PEOPLE)) * S + 16), BG)
    d = ImageDraw.Draw(ms)
    for k, mood in enumerate(names):
        d.text((k * W * S + 8, 2), mood, fill=(240, 236, 228, 255))
        for r, p in enumerate(PEOPLE):
            im, _ = draw(p, idle_pose(0, mood=mood))
            ms.alpha_composite(im.resize((W * S, H * S), Image.NEAREST), (k * W * S, 16 + r * H * S))
    ms.save(os.path.join(OUT, 'people_moods.png'))
    loop = []
    for mood in names:
        for i in (0, 1, 2, 3, 4, 5):
            fr = Image.new('RGBA', (W * len(PEOPLE), H), (0, 0, 0, 0))
            for r, p in enumerate(PEOPLE):
                fr.alpha_composite(draw(p, idle_pose(i, mood=mood))[0], (r * W, 0))
            loop.append(fr)
    _gif(os.path.join(OUT, 'people_moods.gif'), loop, 220)
    rig = {'cell': [W, H], 'ground_row': GROUND, 'bones': BONES, 'moods': list(MOODS), 'people': {}}
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
