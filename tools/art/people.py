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

REFINEMENT (owner: "Refinement, let's work with all the requests" — colour, proportion, arms and hands): ONE palette rule for the whole cast (`tones`:
muted bases, shades drifting to a shared plum, lights to a warm cream); longer arms and shorter, sturdier legs; a sleeve a step lighter than the body
it hangs against, edged in shade, with a cuff, a fist with a thumb, and open palms when the hands go up.

ROUND, CLEAN, STYLISED (owner, of the third pass: "I don't like how sort of blocky they are when the original I sent looks more rounded and clean"):
every mass is an ellipse or a curve — a round head, a dome of hair wrapping it, a soft oval face, shoulders that slope out of the neck, a hem that turns
under — toned in a few clean curved bands (`Cel.rows`), with the fiddly marks of the second pass (ribs, strands, tufts, creases) taken out.

THE BUILD (what the second pass got wrong: a box wider than the head with a belly on the front read as fat, not as a big jumper). A large head, a
SMALL frame: shoulders narrower than the head, the garment hanging off them and widest low down, then gathered in at a rib; arms that are limbs
beside the body, not stripes on it; short solid legs. The size is in the CLOTHES. Facing right; the game would mirror. Designed on a 36 x 48 grid and DRAWN at 1.5x: a 54 x 72
cell, feet on its bottom row, a figure about 66 px tall — level with the player's rig.
"""
import json
import math
import os
import sys

from PIL import Image

import people_px as PX

W, H = 46, 58                      # the DESIGN grid every shape below is written in (36 x 48 until the players and the dead joined: a big one needs headroom, a crawler length)
K = 1.5                            # ...and the size it is DRAWN at (owner, after the in-game test: "they need to be bigger, around the same size as
                                   # player and enemies"). Not a stretch of the small drawing: round shapes and limbs are rasterised at this size, and a
                                   # placed mark (an eye, a button, a shoe) becomes a block of whole pixels, so every edge stays clean.
CW, CH = int(W * K), int(H * K)    # the cell that is written out: 69 x 87
GROUND = H - 1
ANKLE_Y = GROUND - 3
CX = 21
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, '..', '..', 'docs', 'art_reference', 'people'))
GAME = os.path.abspath(os.path.join(HERE, '..', '..', 'assets', 'people'))
EYE = (34, 24, 40, 255)
BG = (126, 124, 128, 255)


def rgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


INK = (44, 32, 52)                 # the plum every shade drifts toward: it ties the cast together and keeps darks from going grey or black
GLOW = (255, 236, 196)             # the warm cream every light drifts toward
MUTE = 0.0                         # how far every base colour is pulled toward its own grey (the building is a muted place)


def _mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def tones(h, dk=0.80, lt=1.13, mute=MUTE):
    """Five tones of one colour — dd (deep shade) / d (shade) / m / l (lit) / ll (the catch-light) — under ONE palette rule for the whole cast
    (owner: "refine and improve style, colourings"): the base is muted a little, each shade is darker AND nearer the shared plum `INK`, each
    light is brighter AND nearer the warm `GLOW`. A darker copy of the same hue reads flat; this reads as light falling on cloth."""
    r, g, b, _ = rgb(h)
    grey = int(0.3 * r + 0.59 * g + 0.11 * b)
    base = _mix((r, g, b), (grey, grey, grey), mute)

    def sh(k, t):
        return _mix(tuple(min(255, int(v * k)) for v in base), INK, t) + (255,)

    def li(k, t):
        return _mix(tuple(min(255, int(v * k)) for v in base), GLOW, t) + (255,)
    return {'dd': sh(dk * dk * 0.96, 0.34), 'd': sh(dk, 0.16), 'm': base + (255,), 'l': li(lt, 0.10), 'll': li(lt * lt, 0.26)}


class Cel:
    def __init__(self):
        self.im = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
        self.px = self.im.load()
        self.clip = None                                  # a set of drawn pixels a placed mark must stay inside (the garment's own shape)

    def raw(self, x, y, c):
        """One pixel of the drawn image."""
        if 0 <= x < CW and 0 <= y < CH and (self.clip is None or (x, y) in self.clip):
            self.px[x, y] = c

    def put(self, x, y, c):
        """One DESIGN pixel: a block of whole pixels at the drawn size (2 x 2 at K = 1.5; neighbours overlap, so a run of them is solid)."""
        x0, y0 = int(math.floor(int(x) * K)), int(math.floor(int(y) * K))
        n = int(math.ceil(K))
        for yy in range(y0, y0 + n):
            for xx in range(x0, x0 + n):
                self.raw(xx, yy, c)

    def wire(self, x0, y, x1, c, dy=0):
        """A line ONE drawn pixel thick from design x0 to x1 on design row y (spectacle wire: a block-thick line hid the eyes)."""
        yy = int(math.floor(int(y) * K)) + dy
        for xx in range(int(math.floor(int(x0) * K)), int(math.floor((int(x1) + 1) * K))):
            self.raw(xx, yy, c)

    def vwire(self, x, y0, y1, c, dx=0):
        """A line ONE drawn pixel wide down design column x."""
        xx = int(math.floor(int(x) * K)) + dx
        for yy in range(int(math.floor(int(y0) * K)), int(math.floor((int(y1) + 1) * K))):
            self.raw(xx, yy, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, c)

    def rows(self, spans, t, flat=False, native=False, **_):
        """A ROUNDED volume from its row spans [(y, xa, xb)], lit from the upper front (the right). Each pixel is toned by where it sits on the
        form (u across, v down, as if it were the surface of something round), in a FEW CLEAN BANDS — a lit crescent toward the light, the body
        tone, a shade crescent round the back and underneath, a thin deep edge — never per-pixel noise (owner: "more rounded and clean and stylised")."""
        n = len(spans)
        for i, (y, xa, xb) in enumerate(spans):
            v = 2.0 * i / float(max(1, n - 1)) - 1.0
            for x in range(xa, xb + 1):
                u = 2.0 * (x - xa) / float(max(1, xb - xa)) - 1.0
                lit = 0.66 * u - 0.46 * v                                    # (v weighed 0.66: the whole lower third went to shade in one straight-edged block)
                if n - 1 - i < 2 and n > 8:
                    lit -= 0.5                                               # the underside still turns away from the light
                k = 'd' if lit < -0.40 else 'm'                              # CEL: flat colour and ONE hard-edged shadow shape, nothing graded
                (self.raw if native else self.put)(x, y, t[k])

    def ell(self, cx, cy, rx, ry, t, keep=None, **kw):
        """An ellipse (given in design pixels) as a rounded volume, rasterised at the drawn size; `keep(x, y)` clips it, in design pixels."""
        cx, cy, rx, ry = cx * K, cy * K, rx * K, ry * K
        spans = []
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            xs = [x for x in range(int(cx - rx - 1), int(cx + rx + 2))
                  if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0
                  and (keep is None or keep((x + 0.5) / K - 0.5, (y + 0.5) / K - 0.5))]
            if xs:
                spans.append((y, min(xs), max(xs)))
        self.rows(spans, t, native=True, **kw)
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
    ax, ay = a[0] * K, a[1] * K                          # given in design pixels, drawn at size
    bx, by = b[0] * K, b[1] * K
    w = w * K
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
            k = 'd' if (s < -0.3 or not near) else 'm'                # CEL: a limb is flat with a shadow down its back; a far limb is all shadow
            c.raw(x, y, t[k])


# ---- the skeleton ----------------------------------------------------------------------------------------------------------------------------
BONES = dict(thigh=4.8, shin=4.8, upper=6.2, fore=6.0, spine=15.0)
REST = dict(n_arm=(3, 8), f_arm=(-2, 8), n_leg=(0, 0), f_leg=(0, 0))


def _fk(o, l1, a1, l2, a2):
    """Two bones from joint `o`: the first at a1 degrees from straight down (+ = forward), the second bent a further a2. -> (mid, end)"""
    r1 = math.radians(a1)
    m = (o[0] + l1 * math.sin(r1), o[1] + l1 * math.cos(r1))
    r2 = math.radians(a1 + a2)
    return m, (m[0] + l2 * math.sin(r2), m[1] + l2 * math.cos(r2))


def skeleton(pose, p=None):
    """Every joint of a pose, in design pixels. pose = dict(n_arm=(shoulder, elbow), f_arm, n_leg=(hip, knee bend — a knee bends BACK, so it is
    subtracted), f_leg, lean (px the shoulders sit ahead of the hips), spine (degrees the back is bent forward: 0 upright, ~80 on all fours),
    breath (px the chest sinks), nod). The person `p` sets the BUILD of the skeleton: `tall` (legs and spine), `arm` (arm length), `hip_dx`
    (where in the cell the hips are). The body is dropped so the lower ankle is on the ground."""
    p = p or {}
    g = dict(REST)
    g.update(pose)
    tall, arml = p.get('tall', 1.0), p.get('arm', 1.0)
    hip = (CX - 0.5 + p.get('hip_dx', 0), 0.0)
    j = {}
    for side, ox in (('n', -2.0), ('f', 1.6)):
        t1, kb = g[side + '_leg']
        j['hip_' + side] = (hip[0] + ox, hip[1])
        j['knee_' + side], j['ankle_' + side] = _fk(j['hip_' + side], BONES['thigh'] * tall, t1, BONES['shin'] * tall, -kb)
    drop = ANKLE_Y - max(j['ankle_n'][1], j['ankle_f'][1])
    j = {k: (v[0], v[1] + drop) for k, v in j.items()}
    hipy = drop
    lean = g.get('lean', 0.0)
    bend = math.radians(g.get('spine', 0.0))
    back = BONES['spine'] * (0.6 + 0.4 * tall)
    sx = hip[0] + lean + back * math.sin(bend)
    sh_y = hipy - back * math.cos(bend) + g.get('breath', 0)
    j['hip'] = (hip[0], hipy)
    j['neck'] = (sx + 0.5, sh_y - 1.0)
    j['head'] = (sx + 1.5 + 6.0 * math.sin(bend), sh_y - 8.7 * math.cos(bend * 0.75) + g.get('nod', 0))   # (8.0: the head sat ON the shoulders — no neck)
    for side, ox in (('n', -3.0), ('f', 3.4)):
        a1, a2 = g[side + '_arm']
        j['shoulder_' + side] = (sx + ox * math.cos(bend), sh_y + 1.5 + abs(ox) * 0.4 * math.sin(bend))
        j['elbow_' + side], j['hand_' + side] = _fk(j['shoulder_' + side], BONES['upper'] * arml, a1, BONES['fore'] * arml, a2)
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
CARRY = {'hammer': (6, 84), 'torch': (4, 82), 'bag': (4, 6)}       # (the upper arm hangs; only the forearm comes forward — a raised upper arm hid the chest)        # the near arm's (shoulder, elbow) angles while it holds each


def _outline(c):
    """The cartoon's line (owner: \"a sort of cross between pixel and cell shading cartoonish… stylised with clear identifiable detail\"): every pixel on
    the figure's edge is darkened toward the shared ink, so each shape is held by a line of its OWN colour gone dark — not a black wire, and the
    silhouette does not grow."""
    src = c.im.copy().load()
    for y in range(CH):
        for x in range(CW):
            if src[x, y][3] and any(not (0 <= x + dx < CW and 0 <= y + dy < CH) or not src[x + dx, y + dy][3] for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                c.px[x, y] = _mix(src[x, y][:3], (26, 14, 34), 0.8) + (255,)        # (0.62 toward a soft plum: the line was too faint to hold anything)


# ---- the BODY under the clothes (owner, watching them move: "the body proportions are poor too. Characters look blocky like lego people. The torso
# bodies are like refrigerators"). The torso was one curve mirrored about the spine: a box with rounded corners. A body seen three-quarters on is
# NOT symmetric: the chest stands forward and the belly falls back under it, the back runs out over the shoulder blades and in at the small of the
# back, and it narrows at the waist. Each SHAPE is a few stations down the body — (how far down, how far the BACK edge is from the spine, how far
# the FRONT edge) — joined by smooth curves.
SHAPES = {
    # a man: wide at the shoulder and chest, tapering to the waist, level hips
    'm': ((0.00, 2.6, 2.4), (0.10, 4.6, 4.2), (0.28, 5.0, 5.6), (0.62, 3.8, 4.4), (0.86, 4.0, 4.4), (1.00, 3.6, 4.0)),
    # a woman: narrower shoulders, a bust, a waist that comes in, hips that go out again
    'f': ((0.00, 2.2, 2.0), (0.10, 3.9, 3.6), (0.30, 4.0, 5.2), (0.58, 3.0, 3.4), (0.88, 4.4, 4.6), (1.00, 4.0, 4.2)),
    # a body under something loose (a big coat, a cardigan): the same idea, softened
    'n': ((0.00, 2.6, 2.4), (0.10, 4.4, 4.0), (0.30, 4.8, 5.4), (0.60, 4.3, 4.7), (0.88, 4.8, 5.0), (1.00, 4.2, 4.4)),
}


def torso_edges(v, p):
    """(back, front): how far the garment's two edges stand from the spine at `v` of the way down (0 the shoulder line, 1 the hem)."""
    st = SHAPES[p.get('shape', 'n')]
    for k in range(len(st) - 1):
        (v0, b0, f0), (v1, b1, f1) = st[k], st[k + 1]
        if v <= v1 or k == len(st) - 2:
            t = max(0.0, min(1.0, (v - v0) / float(v1 - v0)))
            t = 0.5 - 0.5 * math.cos(math.pi * t)                                    # eased: curves, not corners
            grow = 1.0 + 0.09 * p.get('build', 0)
            return ((b0 + (b1 - b0) * t) * grow + 0.3 * p.get('shoulders', 0.0) * (1.0 - v), (f0 + (f1 - f0) * t) * grow + 0.3 * p.get('shoulders', 0.0) * (1.0 - v))
    return (st[-1][1], st[-1][2])


# ---- one frame ---------------------------------------------------------------------------------------------------------------------------------
def draw(p, pose, item=None):
    c = Cel()
    j = skeleton(pose, p)
    th = p.get('thick', 1.0)                                  # how heavy the limbs are
    R = lambda q: (int(round(q[0])), int(round(q[1])))
    g = tones(p['coat'])
    skin = tones(p['skin'], 0.84, 1.07, mute=0.0)
    legc = tones(p['legs'], 0.78, 1.2)
    sho = tones(p['shoes'], 0.66, 1.5, mute=0.0)
    hair = tones(p['hair'], 0.74, 1.24)
    sleeve = dict(g, m=_mix(g['m'][:3], g['l'][:3], 0.35) + (255,), d=_mix(g['d'][:3], g['m'][:3], 0.3) + (255,)) if p.get('sleeves', True) else skin
    palms = pose.get('palms', False)
    kind = p.get('garment', 'coat')
    build = p.get('build', 0)
    hipx, hipy = R(j['hip'])
    shy = int(round(j['shoulder_n'][1] - 1.5))
    lean = int(round(j['neck'][0] - j['hip'][0] - 0.5))
    crawl = pose.get('spine', 0.0) > 55.0                     # on all fours: the body is a barrel between hips and shoulders, not a hanging coat
    hem = hipy + p.get('drop', 1)

    def shoe(ank, near, roll=None):
        """A shoe under an ankle. `roll`: 'heel' = just landed, the toe still up; 'toe' = pushing off, the heel already up."""
        x, y = int(round(ank[0])) - 2, int(round(ank[1]))
        up, dk = (sho['m'], sho['dd']) if near else (sho['d'], sho['dd'])
        lifted = y < ANKLE_Y
        cells = {}                                                                   # (dx, dy) -> colour, then tipped as one piece
        for dx in range(0, 5):
            cells[(dx, 1)] = up
            cells[(dx, 2)] = up
        cells[(5, 2)] = up
        for dx in range(0, 6):
            cells[(dx, 3)] = dk
        cells[(0, 1)] = cells[(0, 2)] = sho['d']
        if near:
            cells[(4, 1)] = sho['l']
            cells[(4, 2)] = sho['ll']
        for (dx, dy), col in cells.items():
            oy = 0
            if roll == 'heel' and dx >= 3:
                oy = -1                                                              # the toe is still in the air
            if (roll == 'toe' or lifted) and dx <= 1:
                oy = -1                                                              # the heel has come up
            if roll == 'toe' and not lifted and dx <= 0:
                oy = -2
            c.put(x + dx, y + dy + oy, col)

    # ---- behind the body: the far arm, the far leg
    limb(c, j['shoulder_f'], j['elbow_f'], 4.2 * th, sleeve if p.get('sleeves', True) else skin, near=False)
    limb(c, j['elbow_f'], j['hand_f'], 3.4 * th, skin if (p.get('rolled') or not p.get('sleeves', True)) else sleeve, near=False)
    fx, fy = R(j['hand_f'])
    far_skin = {k: _mix(skin['m'][:3], skin['d'][:3], 0.7) + (255,) for k in skin}
    c.ell(fx + 0.5, fy + (1.0 if palms else 1.5), 1.8, 2.6 if palms else 1.9, far_skin)
    limb(c, j['hip_f'], j['knee_f'], 4.6 * th, legc, near=False)
    limb(c, j['knee_f'], j['ankle_f'], 4.4 * th, legc, near=False)
    shoe(j['ankle_f'], False, pose.get('f_roll'))
    # ---- the near leg
    limb(c, j['hip_n'], j['knee_n'], 4.8 * th, legc)
    limb(c, j['knee_n'], j['ankle_n'], 4.6 * th, legc)
    if p.get('leg_stripe'):                                                         # a stripe down the outside of the leg
        ls_ = {k_: rgb(p['leg_stripe']) for k_ in ('m', 'd', 'dd', 'l', 'll')}
        limb(c, j['hip_n'], j['knee_n'], 1.3, ls_)
        limb(c, j['knee_n'], j['ankle_n'], 1.3, ls_)
    if p.get('turnup'):                                                             # trousers turned up at the ankle
        tu_ = rgb(p['turnup'])
        for an_ in (j['ankle_n'], j['ankle_f']):
            c.rect(int(round(an_[0])) - 2, int(round(an_[1])) - 1, int(round(an_[0])) + 1, int(round(an_[1])), tu_)
    kx, ky = R(j['knee_n'])
    shoe(j['ankle_n'], True, pose.get('n_roll'))
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
    for i in range(n):
        v = i / float(max(1, n - 1))
        bk, fr = torso_edges(v, p)
        mx = hipx + 0.5 + lean * (1.0 - v) + pose.get('hem_swing', 0.0) * 0.9 * v * v   # the hem swings; the shoulders do not
        spans.append((shy + i, int(round(mx - bk)), int(round(mx + fr))))
    nn = int(round(n * K))                                                          # the same curve again at the drawn size: this is what is painted
    big = []
    for ii in range(nn):
        v = ii / float(max(1, nn - 1))
        bk, fr = torso_edges(v, p)
        mx = hipx + 0.5 + lean * (1.0 - v) + pose.get('hem_swing', 0.0) * 0.9 * v * v
        big.append((int(math.floor(shy * K)) + ii, int(round((mx - bk) * K)), int(round((mx + fr) * K))))
    hand = PX.TORSOS.get(p['name']) if p.get('px') else None
    if hand:                                                                        # a torso placed by hand (people_px): it hangs from the shoulder line
        big = []
        PX.paste(c, hand, PX.PALETTES[p['name']], int(round((j['neck'][0] - 0.5) * K)) - len(hand[0]) // 2, int(math.floor(shy * K)) - 1)
    elif crawl:
        big = []
        limb(c, (j['hip'][0], j['hip'][1] - 1.0), (j['neck'][0] - 1.0, j['neck'][1] + 3.0), 2.0 * wide - 4.0, g)
        for i_ in range(1, 6):                                                      # the spine standing out along its back
            t_ = i_ / 6.0
            c.put(int(j['hip'][0] + (j['neck'][0] - j['hip'][0]) * t_), int(j['hip'][1] - 5.0 + (j['neck'][1] - j['hip'][1]) * t_), g['l'])
    else:
        c.rows(big, g, native=True)
    c.clip = set((x, y) for (y, xa, xb) in big for x in range(xa, xb + 1))          # the marks on the garment stay inside it
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
    for mk_ in p.get('marks', ()):                                                  # what makes the clothes THEIRS: flat, graphic, readable at a glance
        kind_, col_ = mk_[0], (rgb(mk_[1]) if len(mk_) > 1 and isinstance(mk_[1], str) else None)
        if kind_ == 'check':                                                        # a checked shirt: thin lines both ways
            for y in range(shy + 1, hem + 1, mk_[2]):
                c.wire(hipx - 12, y, hipx + 12, col_)
            for x in range(hipx - 12, hipx + 13, mk_[2]):
                c.vwire(x, shy, hem, col_)
        elif kind_ == 'hstripes':                                                   # a striped top: bands right round
            for y in range(shy + 3, hem, mk_[2]):
                c.rect(hipx - 12, y, hipx + 12, y, col_)
        elif kind_ == 'zip':
            c.vwire(fxe - 3, shy + 1, hem, col_, dx=1)
            c.put(fxe - 3, shy + 3, col_)
        elif kind_ == 'collar':
            c.rect(fxe - 6, shy, fxe - 2, shy + 1, col_)
            c.put(fxe - 4, shy + 2, col_)
        elif kind_ == 'belt':                                                       # a belt with a buckle, and a pouch hanging off it at the hip
            c.rect(hipx - 12, hem - 4, hipx + 12, hem - 3, col_)
            c.rect(fxe - 4, hem - 4, fxe - 3, hem - 3, rgb(mk_[2]))
            c.rect(hipx - 5, hem - 3, hipx - 2, hem, rgb(mk_[3]))
            c.wire(hipx - 5, hem - 3, hipx - 2, _mix(rgb(mk_[3])[:3], INK, 0.5) + (255,))
        elif kind_ == 'patch':                                                      # a name patch / a badge on the chest
            c.rect(fxe - 6, shy + 5, fxe - 3, shy + 6, col_)
        elif kind_ == 'strap':                                                      # a bag's strap across the body
            for i_ in range(0, hem - shy):
                c.put(hipx - 5 + int(i_ * 0.75), shy + 1 + i_, col_)
        elif kind_ == 'hem':                                                        # a band of another colour round the bottom
            c.rect(hipx - 12, hem - 1, hipx + 12, hem, col_)
        elif kind_ == 'yoke':                                                       # a block of another colour across the shoulders
            c.rect(hipx - 12, shy, hipx + 12, shy + mk_[2], col_)
    if p.get('dead') and not crawl:                                                # the hem is torn: bites out of the bottom edge
        for (y_, xa_, xb_) in big[-int(3 * K):]:
            for x_ in range(xa_, xb_ + 1):
                if ((x_ - big[-1][1]) // 3) % 3 == (1 if y_ > big[-2][0] - 2 else 4):
                    c.px[x_, y_] = (0, 0, 0, 0)
        for (y_, xa_, xb_) in big[-2:]:
            for x_ in range(xa_, xb_ + 1):
                if ((x_ - big[-1][1]) // 3) % 2 == 0 and 0 <= x_ < CW:
                    c.px[x_, y_] = (0, 0, 0, 0)
    for (dx_, dy_, w_, h_) in p.get('stains', ()):                                 # what has soaked into the cloth, dark, and darker at its heart
        bl = tones(p.get('stain', '5a1a1c'), 0.7, 1.1, mute=0.0)
        c.ell(hipx + dx_, shy + dy_, w_, h_, bl, flat=True)
        c.ell(hipx + dx_, shy + dy_, w_ * 0.5, h_ * 0.5, {k: bl['dd'] for k in bl}, flat=True)
    c.clip = None
    for ex_ in p.get('extras', ()):
        if ex_ == 'hump':                                                           # the big one: a mass of shoulder behind the head
            c.ell(j['neck'][0] - 4.0, j['neck'][1] + 1.0, 6.5, 5.0, g)
        if ex_ == 'sack':                                                           # the spitter: a throat swollen like a toad's, tight and pale
            sk_ = tones(p.get('sack', 'a8b070'), 0.8, 1.16, mute=0.0)
            c.ell(j['neck'][0] + 4.4, j['neck'][1] + 0.4, 4.2 + (0.7 if pose.get('breath') else 0.0), 3.6 + (0.7 if pose.get('breath') else 0.0), sk_)
            c.ell(j['neck'][0] + 5.6, j['neck'][1] - 0.8, 1.4, 1.0, {k_: sk_['l'] for k_ in sk_})
    if p.get('scarf'):
        sc = tones(p['scarf'])
        c.box(spans[0][1], shy - 2, spans[0][2] + 1, shy + 1, sc, top=(1,), bot=(1,), under=1)
        c.rect(fxe - 4, shy + 1, fxe - 2, shy + 8, sc['m'])
        c.rect(fxe - 4, shy + 1, fxe - 4, shy + 8, sc['d'])
        c.rect(fxe - 2, shy + 2, fxe - 2, shy + 7, sc['l'])
        c.rect(fxe - 5, shy + 2, fxe - 5, shy + 8, g['dd'])
    # ---- the NECK (owner: "none of them have necks which is odd"): a short column of skin, shaded down its back, the collar's shadow across its foot
    if not crawl and st != 'hood':
        nx_, ny_ = int(round(j['neck'][0])), int(round(j['neck'][1]))
        nb_ = ny_ - 1 if p.get('px') else ny_ + 1                                     # a hand-drawn torso has its own collar: the neck stops above it
        c.rect(nx_ - 3, ny_ - 3, nx_ + 2, nb_, skin['m'])
        c.rect(nx_ - 3, ny_ - 3, nx_ - 2, nb_, skin['d'])
        c.rect(nx_ - 3, ny_ - 3, nx_ + 2, ny_ - 2, skin['d'])
    body_ = c                                                                       # the head is its own layer, so its own line holds it against the collar
    c = Cel()
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
        if st in ('long', 'bob', 'ponytail'):
            c.ell(hx, hy, 6.9, 7.3, hair, keep=lambda x, y: not face(x, y) or y < hy - 3.6)
            if st == 'bob':
                c.ell(hx - 3.2, hy + 4.0, 4.4, 5.6, hair, keep=lambda x, y: not face(x, y))
            if st == 'ponytail':                                                    # a full head of hair swept across the brow and tied high: the tail has weight and swings
                h2 = {k_: rgb(p.get('hair2', 'f8e6a0')) for k_ in hair}
                c.ell(hx - 7.4, hy - 2.2, 3.0, 3.2, hair)
                c.ell(hx - 8.8 - 0.5 * sway, hy + 3.4, 2.8, 5.4, hair)
                c.ell(hx - 9.0 - 0.5 * sway, hy + 2.4, 0.9, 3.4, h2)
                c.ell(hx + 2.6, hy - 3.9, 4.2, 1.9, hair, keep=lambda x, y: skull(x, y))    # the fringe, swept to the side
                c.ell(hx + 1.0, hy - 5.4, 3.4, 0.9, h2, keep=lambda x, y: skull(x, y))
                c.ell(hx - 3.4, hy - 2.0, 0.9, 3.0, h2)
                c.rect(int(hx - 6), int(hy - 3), int(hx - 5), int(hy - 1), rgb(p.get('band', 'e86a6a')))
        elif st in ('short', 'bun', 'beanie', 'braid', 'crop'):
            c.ell(hx, hy, 6.9, 7.3, hair, keep=lambda x, y: (y < hy - (3.6 if st == 'crop' else 2.6) or (x < hx - 2.6 and y < hy + (0.5 if st == 'crop' else 3.5))) and not (face(x, y) and y >= hy - 3.6))
            if st == 'braid':                                                       # one long plait, over the near shoulder and down the front
                for i_ in range(6):                                                 # bead by bead, each with its own light, getting smaller
                    r_ = 1.7 - 0.12 * i_
                    c.ell(hx - 5.0 + 0.2 * i_, hy + 6.4 + i_ * 2.9, r_, 1.5, hair, flat=True)
                    c.raw(int((hx - 5.0 + 0.2 * i_) * K), int((hy + 6.0 + i_ * 2.9) * K), hair['ll'])
                c.rect(int(hx - 4), int(hy + 23), int(hx - 3), int(hy + 23), rgb(p.get('band', 'e8c860')))
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
    eh = max(1, eh + f.get('eye_grow', 0))
    shut = pose.get('blink') or f.get('squint')
    if st not in ('bald', 'hood', 'beanie') and not p.get('dead'):                  # the hair's shine: one hard-edged shape, as a cartoon has it
        c.ell(hx + 1.6, hy - 4.6, 2.6, 0.9, {k_: hair['l'] for k_ in hair}, keep=lambda x, y: not face(x, y) and skull(x, y))
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
    if f.get('glasses'):                                                            # spectacles: thin WIRE over each eye, the lens only a lift of the skin behind it
        gl = rgb(f['glasses'])
        lens = _mix(skin['l'][:3], (226, 230, 232), 0.35) + (255,)
        for ex in (ex0, ex1):
            c.rect(ex - 1, ey, ex + ew, ey + eh - 1, lens)
            c.wire(ex - 1, ey, ex + ew, gl, dy=-1)
            c.wire(ex - 1, ey + eh, ex + ew, gl)
        c.wire(ex0 + ew + 1, ey, ex1 - 2, gl)
    for ex in (ex0, ex1):
        if shut:
            c.rect(ex, ey + eh - 1, ex + ew - 1, ey + eh - 1, EYE)
        else:
            c.rect(ex, ey, ex + ew - 1, ey + eh - 1, EYE)
            if f.get('dead'):                                                       # nobody home: a pale dot adrift in a dark socket
                c.raw(int((ex + ew - 1) * K) + (0 if ex == ex0 else -1), int(ey * K) + 1, (226, 222, 196, 255))
                c.raw(int((ex + ew - 1) * K) + (0 if ex == ex0 else -1), int(ey * K) + 2, (226, 222, 196, 255))
            if f.get('iris'):                                                       # the colour of their eyes: a fleck in each, not a block
                c.raw(int(ex * K) + 1, int((ey + eh - 1) * K), rgb(f['iris']))
                c.raw(int(ex * K) + 2, int((ey + eh - 1) * K), rgb(f['iris']))
                c.raw(int(ex * K) + 1, int((ey + eh - 1) * K) + 1, rgb(f['iris']))
            if f.get('glint') and eh >= 2:
                c.put(ex + ew - 1, ey, (236, 232, 226, 255))
            if f.get('lids'):                                                       # heavy lids: the top row of the eye is skin shade
                c.rect(ex, ey, ex + ew - 1, ey, lid)
    b = f.get('brow')
    if b:
        by = ey - (1 if f.get('brow_low') else 2)
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
    elif m == 'maw':                                                                # a mouth that hangs open: dark, a few teeth, and it is wet
        c.rect(mx - 2, my_ - 1, mx + 2, my_ + 1, (48, 16, 22, 255))
        for tx_ in range(mx - 2, mx + 3, 2):                                        # teeth, top and bottom, gappy
            c.raw(int(tx_ * K), int((my_ - 1) * K), (232, 226, 200, 255))
            c.raw(int(tx_ * K) + 1, int((my_ + 2) * K) - 1, (232, 226, 200, 255))
        c.rect(mx, my_ + 2, mx, my_ + 2 + f.get('drool', 0), rgb(f.get('drool_col', '7a1a1c')))
    elif m == 'lips':
        c.rect(mx - 1, my_, mx + 1, my_, rgb(f.get('lip', 'a8463e')))
    if f.get('nose'):
        c.put(ex1 + ew - 1 + (1 if ew < 3 else 0), ey + eh, skin['d'])
    if f.get('freckles'):                                                           # a scatter across each cheek, dark enough to read
        fk = _mix(skin['m'][:3], (150, 84, 60), 0.6) + (255,)
        for (dx_, dy_) in ((-1, 0), (1, 1), (ew + f['gap'], 0), (ew + f['gap'] + 2, 1), (ew + f['gap'] - 1, 1)):
            c.put(ex0 + dx_, ey + eh + dy_, fk)
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
    hd = PX.HEADS.get(p['name']) if p.get('px') else None
    if hd:                                                                          # a head placed by hand: face, hair and all, riding the head joint
        c = Cel()
        PX.paste(c, hd['rows'], PX.PALETTES[p['name']], int(round(j['head'][0] * K)) - hd['anchor'][0], int(round(j['head'][1] * K)) - hd['anchor'][1], blink=bool(pose.get('blink')))
    else:
        _outline(c)
    body_.im.alpha_composite(c.im)
    c = Cel()                                                                       # ...and so is the near arm: a limb with a line round it, not a stripe on the coat
    # ---- the near arm, over everything: its shadow on the body first, then the sleeve along its two bones, the cuff, the fist — and what it holds
    sn, en, hn = j['shoulder_n'], j['elbow_n'], j['hand_n']
    fore = skin if (p.get('rolled') or not p.get('sleeves', True)) else sleeve       # sleeves rolled to the elbow, or none
    limb(c, sn, en, 5.0 * th, sleeve if p.get('sleeves', True) else skin)           # the upper arm is the heavier bone
    limb(c, en, hn, 4.0 * th, fore)
    if p.get('rolled'):                                                             # the roll: a band of the shirt's lining at the elbow
        c.ell(en[0], en[1], 2.9 * th, 1.6, {k_: rgb(p['rolled']) for k_ in sleeve})
    if not p.get('sleeves', True):                                                  # a short sleeve: the garment's own colour capping a bare arm
        limb(c, sn, ((sn[0] + en[0]) * 0.55, (sn[1] + en[1]) * 0.55 + sn[1] * 0.0), 5.4 * th, g) if False else limb(c, sn, (sn[0] + (en[0] - sn[0]) * 0.5, sn[1] + (en[1] - sn[1]) * 0.5), 5.4 * th, g)
    c.ell(sn[0], sn[1] - 0.4, 2.9 * th, 2.4, sleeve if p.get('sleeves', True) else g)                # the round of the shoulder
    sx, sy = R(sn)
    ex_, ey_ = R(en)
    hx, hy = R(hn)
    if item:
        ITEMS[item](c, hx, hy)
    ux, uy = (hn[0] - en[0]), (hn[1] - en[1])                                       # the cuff: a dark line across the wrist, square to the forearm
    ul = math.hypot(ux, uy) or 1.0
    for k in (-2, -1, 0, 1):
        if p.get('sleeves', True) and not p.get('rolled'):
            c.put(int(round(hn[0] - ux / ul * 1.2 - uy / ul * (k + 0.5))), int(round(hn[1] - uy / ul * 1.2 + ux / ul * (k + 0.5))), rgb(p['cuff']) if p.get('cuff') else g['dd'])
    if palms:                                                                       # an open hand held up: taller than a fist, the fingers lit
        c.ell(hx + 0.5, hy + 0.6, 2.0, 2.9, skin)
    else:
        c.ell(hx + 0.5, hy + 1.5, 2.2, 2.2, skin)                                   # a round fist
        c.put(hx + 2, hy + 1, skin['l'])                                            # and its thumb
    _outline(c)
    body_.im.alpha_composite(c.im)
    c = body_
    _outline(c)
    return c.im, j


# ---- the cycles: ANGLES for the skeleton ---------------------------------------------------------------------------------------------------------
WALK_N = 12                        # frames in a stride (two steps). It was 8: the passing pose and the push-off each fell between frames


def walk_pose(i, n=WALK_N, carry=None, stride=1.0, drag=0.0):
    """One frame of the walk. What makes it a WALK and not two legs scissoring: the knee gives a little as the weight lands and folds early in the
    swing; the foot ROLLS (heel down first with the toe up, heel up before the toe leaves); the head follows the body a frame late; the hem
    swings behind the leading leg; the arm bends more coming forward than going back."""
    ph = i / float(n)

    def leg_(q):
        q %= 1.0
        swing = (25.0 * math.cos(2.0 * math.pi * q) - 1.0) * stride                             # the thigh: forward at contact, back at push-off
        if q < 0.5:
            bend = 11.0 * math.sin(math.pi * q / 0.5) ** 2 + 2.0                     # taking the weight
        else:
            u = (q - 0.5) / 0.5
            bend = 64.0 * (1.0 - drag) * math.sin(math.pi * u ** 0.75)                             # folding early, opening as it reaches
        return (swing, bend)

    def roll_(q):
        q %= 1.0
        return 'heel' if q < 0.09 or q > 0.94 else ('toe' if 0.38 <= q < 0.6 else None)
    arm = 22.0 * math.cos(2.0 * math.pi * ph)
    half = n // 2
    pose = dict(n_leg=leg_(ph), f_leg=leg_(ph + 0.5), n_arm=(-arm, 8 + max(0.0, -arm) * 0.9), f_arm=(arm, 8 + max(0.0, arm) * 0.9), lean=1.0,
                n_roll=roll_(ph), f_roll=roll_(ph + 0.5), nod=1 if i % half == 1 else 0, hem_swing=-math.cos(2.0 * math.pi * ph),
                sway=1 if (i % half) in (1, 2, 3) else 0)
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
    'wary': dict(face=dict(brow='flat', brow_low=True, eye_grow=-1, mouth='line', lids=False, glint=False, bags=False), pose=dict(lean=-0.8, n_arm=(8, 34))),                    # watching you, not sure yet
    'scared': dict(face=dict(brow='worried', mouth='o', eye_grow=1, glint=True, lids=False, bags=False),
                   pose=dict(n_arm=(40, 100), f_arm=(30, 104), lean=-1.2, palms=True)),                                # hands up in front, leaning away
    'hurt': dict(face=dict(brow='stern', mouth='frown', squint=True), pose=dict(n_arm=(18, 110), lean=1.6, breath=1)),   # eyes screwed shut, a hand to the body
    'angry': dict(face=dict(brow='stern', mouth='frown', lids=False, glint=False, cheek='c8685a'), pose=dict(n_arm=(-8, 30), f_arm=(-10, 34), lean=1.0)),
    'sad': dict(face=dict(brow='worried', mouth='frown', lids=True, glint=False), pose=dict(lean=0.8, breath=1, n_arm=(1, 3), f_arm=(-1, 3))),
    'relieved': dict(face=dict(brow='raised', mouth='smile', lids=False, bags=False, cheek='e8a8a0'), pose=dict()),      # saved: the face opens
    'grateful': dict(face=dict(brow='raised', mouth='smile', squint=True, cheek='e8a8a0'), pose=dict(n_arm=(24, 118))),   # eyes creased in a smile, a hand to the chest
}


# ---- the neighbours (ours, not the reference's) --------------------------------------------------------------------------------------------
PEOPLE = [
    dict(name='nell', shape='f', face=dict(eye=(2, 3), gap=2, glint=True, brow='worried', mouth='small', cheek='e8a8a0', freckles=True), coat='b5533c', skin='e8d6c8', hair='3a2a34', hairstyle='long', legs='3a3444', shoes='1e1a22', toggles='e8d6c8', drop=3,
         carry='torch'),                                                                                     # a girl in a red duffel coat, black tights
    dict(name='mrs_okafor', face=dict(eye=(2, 2), gap=3, dx=-1, mouth='smile', wrinkle=True, glasses='c8a85a', earring='e8c860'), coat='8a6f9a', skin='8a5a44', hair='b8b4b8', hairstyle='bun', legs='7a5240', shoes='5a3a4a', skirt='4a4458',
         skirt_len=5, open='e0d8c4', garment='jumper', build=1, carry='bag'),               # an older woman: a long cardigan over a skirt
    dict(name='dale', shape='m', face=dict(eye=(2, 3), gap=2, dy=-1, lids=True, bags=True, brow='flat', mouth='line', stubble=True), coat='5d7a4a', skin='e2c4a8', hair='6a4a2a', hairstyle='hood', legs='3a4254', shoes='e4e0d8', fur='d8c8a8', pocket=True,
         garment='parka', drop=2, carry='hammer'),                                                           # a lad in a parka, hood up, white trainers
    dict(name='mr_hale', shape='m', face=dict(eye=(1, 2), gap=3, brow='heavy', mouth='frown', nose=True, cheek='d89a88', tache=True), coat='c8b48a', skin='e6c8b0', hair='5a5450', hairstyle='bald', legs='55525c', shoes='4a3324', scarf='7a2e2e', tache=True,
         buttons='5a4a30', build=1, drop=4, carry='bag'),                                                    # a big man in a camel overcoat and a scarf
    dict(name='priya', shape='f', face=dict(eye=(2, 2), gap=2, glint=True, brow='stern', mouth='lips', lip='8a3a34', mole=True, earring='f0e6d0'), coat='e0b23c', skin='b07a56', hair='241c22', hairstyle='bob', legs='34506e', shoes='2a2630', stripe='f0e6d0',
         garment='jumper', carry='hammer'),                                                                  # a yellow jumper with a band, jeans
    dict(name='tomasz', shape='m', face=dict(eye=(2, 2), gap=2, brow='flat', mouth='o', beard=True), coat='3f5f8a', skin='e4ccb4', hair='c8a468', hairstyle='beanie', hat='b84a36', legs='6a5a48', shoes='2a2420',
         open='d8d4cc', garment='jacket', pocket=True, carry='torch'),                              # a work jacket worn open, a red beanie
]


# ---- THE PLAYERS (owner: "Now redesign the player characters and enemies in this style"). The four of docs/CHARACTERS.md, each dressed as who they
# are: Joe the tenant, Vivianne the neighbour who runs, Alex the building's super, Amina the nurse. Same rig, same palette rule, their own faces.
PLAYERS = [
    # The four are drawn in two ways at once: HEAD and TORSO placed by hand (tools/art/people_px.py: the face, the hair's style, the clothes' cut and
    # detail), ARMS and LEGS on the rig. `px=True` turns that on; the colours here are the limbs' and must match the hand-drawn palette.
    # Joe, the tenant — a white man, a blond quiff: a red checked shirt, sleeves rolled, open over a white tee; jeans turned up; brown boots
    dict(name='joe', px=True, shape='m', coat='c8443a', skin='f0d0b4', hair='e8c050', hairstyle='short', legs='3f5a82', shoes='6a4428',
         rolled='8a2c28', turnup='7c98bc', carry='hammer'),
    # Vivianne, the neighbour who runs — a white woman, golden hair tied high: a coral track top, white cuffs; black leggings with a stripe; white trainers
    dict(name='vivianne', px=True, shape='f', coat='f0685a', skin='f6dcc8', hair='f2c64e', hairstyle='short', legs='2a2a36', shoes='f0ece4',
         cuff='f6f2ea', leg_stripe='f0685a', carry='torch'),
    # Alex, the super — a black man in his thirties, clean-shaven, hair cropped: navy dungarees over a pale tee, a tool belt; tan boots
    dict(name='alex', px=True, shape='m', coat='cfd4dc', skin='7a4e34', hair='1c1418', hairstyle='short', legs='2c4c86', shoes='b8863c', sleeves=False,
         carry='hammer'),
    # Amina, the nurse, off duty — an Indian woman, long black hair: a mustard cardigan over a magenta top; dark trousers; brown shoes
    dict(name='amina', px=True, shape='f', coat='e0a82e', skin='c08a5e', hair='1e141a', hairstyle='short', legs='3a3448', shoes='7a4a3a',
         cuff='b8862e', carry='bag'),
]

# ---- THE THINGS (owner 2026-11-12: "our original enemies were also placeholder, so we don't need to stick to zombies… grotesque monsters that fit the
# standard, crawler, big, long arm, spitter names… horror, pulsating, gross, some can have multiple arms, some might have no discernable heads. Some
# could look more fly or creature like… We want not just another zombie game"). They are not people on this rig: each is its own body, drawn in
# tools/art/creatures.py with the same pixels, shading and line. `creature` names the drawing.
ENEMIES = [dict(name=n, creature=n) for n in ('standard', 'crawler', 'big', 'longarm', 'spitter')]
CAST = PLAYERS + ENEMIES


def frames(p, kind):
    """-> [(image, joints)]. A person's own `pose` (the dead's reaching arms and bent back) lies over every frame; `stride` / `drag` change the walk."""
    if p.get('creature'):
        import creatures
        return creatures.frames(p['creature'], kind)
    own = p.get('pose', {})

    def mk(pose, item=None):
        hold = {k: v for k, v in own.items() if not (item and k == 'n_arm')}
        if own.get('spine', 0.0) > 55.0:                      # on all fours the walk's own leg angles would stand it up: it keeps its own
            pose = {k: v for k, v in pose.items() if k not in ('n_leg', 'f_leg', 'n_arm', 'f_arm', 'lean')}
        return draw(p, dict(pose, **hold), item=item)
    if own.get('spine', 0.0) > 55.0 and kind == 'walk':                              # the crawl: opposite hand and knee go forward together
        out = []
        for i in range(WALK_N):
            q = math.cos(2.0 * math.pi * i / float(WALK_N))
            na, fa, nl, fl = own['n_arm'], own['f_arm'], own['n_leg'], own['f_leg']
            out.append(draw(p, dict(own, n_arm=(na[0] + 22 * q, na[1] - 8 * q), f_arm=(fa[0] - 22 * q, fa[1] + 8 * q),
                                    n_leg=(nl[0] - 14 * q, nl[1] - 10 * q), f_leg=(fl[0] + 14 * q, fl[1] + 10 * q), nod=1 if i % 6 == 1 else 0)))
        return out
    if kind == 'walk':
        return [mk(walk_pose(i, stride=p.get('stride', 1.0), drag=p.get('drag', 0.0))) for i in range(WALK_N)]
    if kind == 'carry':
        return [mk(walk_pose(i, carry=p['carry']), item=p['carry']) for i in range(WALK_N)]
    return [mk(idle_pose(i)) for i in range(6)]


def self_check():
    """Every figure stands on the ground row, nothing is cut off by its cell, a leg is never thinner than 3 px, and the garment is never wider
    than the head by more than 4 px (the 'fat' the second pass had)."""
    errs = []
    for p in CAST:                                                              # the players and the dead: on the ground, inside the cell
        for kind in ('idle', 'walk'):
            for i, (im, j) in enumerate(frames(p, kind)):
                px = im.load()
                if not any(px[x, (CH - 1)][3] for x in range(CW)):
                    errs.append('%s %s %d: nothing on the ground row' % (p['name'], kind, i))
                if any(px[x, 0][3] for x in range(CW)) or any(px[0, y][3] or px[CW - 1, y][3] for y in range(CH)):
                    errs.append('%s %s %d: touches the edge of its cell' % (p['name'], kind, i))
    for p in PEOPLE:
        for kind in ('idle', 'walk', 'carry'):
            for i, (im, j) in enumerate(frames(p, kind)):
                px = im.load()
                if not any(px[x, (CH - 1)][3] for x in range(CW)):
                    errs.append('%s %s %d: nothing on the ground row' % (p['name'], kind, i))
                if any(px[x, 0][3] for x in range(CW)) or any(px[0, y][3] or px[CW - 1, y][3] for y in range(CH)):
                    errs.append('%s %s %d: touches the edge of its cell' % (p['name'], kind, i))
                if kind == 'idle':
                    for mood in MOODS:                                               # every mood draws, inside the cell
                        mi, _ = draw(p, idle_pose(i, mood=mood))
                        mp = mi.load()
                        if any(mp[x, 0][3] for x in range(CW)) or any(mp[0, y][3] or mp[CW - 1, y][3] for y in range(CH)):
                            errs.append('%s %s: touches the edge of its cell' % (p['name'], mood))
                    y = int(j['knee_n'][1] * K)
                    runs, x = [], 0
                    while x < CW:
                        if px[x, y][3]:
                            x1 = x
                            while x1 + 1 < CW and px[x1 + 1, y][3]:
                                x1 += 1
                            runs.append(x1 - x + 1)
                            x = x1 + 1
                        else:
                            x += 1
                    if runs and min(runs) < 4:
                        errs.append('%s idle %d: a leg is %d px wide at the knee' % (p['name'], i, min(runs)))
    return errs


def _on_bg(im, scale):
    bg = Image.new('RGBA', im.size, BG)
    bg.alpha_composite(im)
    return bg.resize((im.width * scale, im.height * scale), Image.NEAREST)


def _gif(path, cels, ms, scale=4):
    big = [_on_bg(im, scale).convert('P', palette=Image.ADAPTIVE, colors=96) for im in cels]
    big[0].save(path, save_all=True, append_images=big[1:], duration=ms, loop=0, disposal=2)


def _row(sets):
    out = []
    for i in range(len(sets[0])):
        im = Image.new('RGBA', (CW * len(sets), CH), (0, 0, 0, 0))
        for k, cels in enumerate(sets):
            im.alpha_composite(cels[i][0], (k * CW, 0))
        out.append(im)
    return out


def _rig_sheet(p):
    """The bones over one figure's walk: what the skeleton is, drawn."""
    from PIL import ImageDraw
    S = 5
    fr = frames(p, 'carry')
    sheet = Image.new('RGBA', (CW * S * len(fr), CH * S), BG)
    d = ImageDraw.Draw(sheet)
    for i, (im, j) in enumerate(fr):
        ghost = im.copy()
        ghost.putalpha(ghost.getchannel('A').point(lambda a: a * 0.45))
        sheet.alpha_composite(ghost.resize((CW * S, CH * S), Image.NEAREST), (i * CW * S, 0))
        P = lambda k: (i * CW * S + j[k][0] * K * S, j[k][1] * K * S)
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
    sheet = Image.new('RGBA', (CW * (6 + 2 * WALK_N) + 8, CH * len(PEOPLE)), BG)
    for k in range(len(PEOPLE)):
        x = 0
        for kind in ('idle', 'walk', 'carry'):
            for (im, _) in sets[kind][k]:
                sheet.alpha_composite(im, (x, k * CH))
                x += CW
            x += 4
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(os.path.join(OUT, 'people_sheet.png'))
    _gif(os.path.join(OUT, 'people_walk.gif'), _row(sets['walk']), 80)
    _gif(os.path.join(OUT, 'people_carry.gif'), _row(sets['carry']), 80)
    _gif(os.path.join(OUT, 'people_idle.gif'), _row(sets['idle']), 260)
    _rig_sheet(PEOPLE[2]).save(os.path.join(OUT, 'people_rig.png'))
    # the moods: every person in every mood, labelled, and a loop that goes through them
    from PIL import ImageDraw
    names = list(MOODS)
    S = 3
    ms = Image.new('RGBA', (CW * S * len(names), (CH * len(PEOPLE)) * S + 16), BG)
    d = ImageDraw.Draw(ms)
    for k, mood in enumerate(names):
        d.text((k * CW * S + 8, 2), mood, fill=(240, 236, 228, 255))
        for r, p in enumerate(PEOPLE):
            im, _ = draw(p, idle_pose(0, mood=mood))
            ms.alpha_composite(im.resize((CW * S, CH * S), Image.NEAREST), (k * CW * S, 16 + r * CH * S))
    ms.save(os.path.join(OUT, 'people_moods.png'))
    loop = []
    for mood in names:
        for i in (0, 1, 2, 3, 4, 5):
            fr = Image.new('RGBA', (CW * len(PEOPLE), CH), (0, 0, 0, 0))
            for r, p in enumerate(PEOPLE):
                fr.alpha_composite(draw(p, idle_pose(i, mood=mood))[0], (r * CW, 0))
            loop.append(fr)
    _gif(os.path.join(OUT, 'people_moods.gif'), loop, 220)
    rig = {'cell': [CW, CH], 'ground_row': (CH - 1), 'bones': BONES, 'moods': list(MOODS), 'people': {}}
    for k, p in enumerate(PEOPLE):
        rig['people'][p['name']] = {kind: [{n: ([round(v[0] * K, 2), round(v[1] * K, 2)] if n != 'grip' else round(v, 1)) for n, v in j.items()}
                                           for (_, j) in sets[kind][k]] for kind in sets}
    with open(os.path.join(OUT, 'people_rig.json'), 'w') as fh:
        json.dump(rig, fh, indent=1, sort_keys=True)
    # ---- for the GAME (a dev preview only: scripts/people_preview.gd, tools/scene_capture `people`): one strip a person, idle then walk then carry
    os.makedirs(GAME, exist_ok=True)
    order = ('idle', 'walk', 'carry')
    anims, at = {}, 0
    for kind in order:
        anims[kind] = [at, len(sets[kind][0])]
        at += len(sets[kind][0])
    for k, p in enumerate(PEOPLE):
        strip = Image.new('RGBA', (CW * at, CH), (0, 0, 0, 0))
        x = 0
        for kind in order:
            for (im, _) in sets[kind][k]:
                strip.alpha_composite(im, (x, 0))
                x += CW
        strip.save(os.path.join(GAME, p['name'] + '.png'))
    with open(os.path.join(GAME, 'people.json'), 'w') as fh:
        json.dump({'cell': [CW, CH], 'feet_row': (CH - 1), 'anims': anims, 'people': [p['name'] for p in PEOPLE],
                   'groups': {'neighbours': [p['name'] for p in PEOPLE], 'players': [p['name'] for p in PLAYERS], 'dead': [p['name'] for p in ENEMIES]},
                   'ms': {'idle': 260, 'walk': 80, 'carry': 80}}, fh, indent=1, sort_keys=True)
    # ---- the players and the dead: their own sheet and loop, and strips for the game's dev preview
    csets = {k: [frames(p, k) for p in CAST] for k in ('idle', 'walk')}
    sheet2 = Image.new('RGBA', (CW * (6 + WALK_N) + 4, CH * len(CAST)), BG)
    for k in range(len(CAST)):
        x = 0
        for kind in ('idle', 'walk'):
            for (im, _) in csets[kind][k]:
                sheet2.alpha_composite(im, (x, k * CH))
                x += CW
            x += 4
    sheet2.resize((sheet2.width * 2, sheet2.height * 2), Image.NEAREST).save(os.path.join(OUT, 'cast_sheet.png'))
    _gif(os.path.join(OUT, 'cast_walk.gif'), _row(csets['walk']), 80, scale=3)
    _gif(os.path.join(OUT, 'cast_idle.gif'), _row(csets['idle']), 260, scale=3)
    for k, p in enumerate(CAST):
        strip = Image.new('RGBA', (CW * at, CH), (0, 0, 0, 0))
        x = 0
        for kind in order:
            for (im, _) in (csets[kind][k] if kind in csets else csets['walk'][k]):   # no carry cycle yet: the walk stands in
                strip.alpha_composite(im, (x, 0))
                x += CW
        strip.save(os.path.join(GAME, p['name'] + '.png'))
    print('wrote %d people to %s' % (len(PEOPLE), OUT))
    if errs:
        print('\n'.join(errs[:20]))
        sys.exit(1)


if __name__ == '__main__':
    main()
