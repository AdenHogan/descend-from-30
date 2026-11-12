#!/usr/bin/env python3
"""PEOPLE — a LOOK TEST for the game's humans (owner 2026-11-11, with a reference of chunky pixel figures: "I want our people, NPCs, and player
characters to be more like this… increase the size so you can perfect a best version of a few different NPCs with that bulky cartoon pixel
style… Not spaghetti broke. Pixel legs… an animation sprite for Idle and walking").

NOT wired into the game. It draws a few neighbours in that manner and writes a sheet and looping GIFs for the owner to judge:

    python3 tools/art/people.py            ->  docs/art_reference/people/people_sheet.png, people_walk.gif, people_idle.gif, <name>_walk.gif, <name>_idle.gif

The manner: a person is a few BIG soft masses — hair, a coat or jumper far too large, a pale face that is two dark eyes — on short SOLID legs
(four pixels wide, a lit near leg and a shaded far one, a shoe with a toe), no outlines, three tones a mass. Every figure is built from the
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


def tones(h, dk=0.78, lt=1.14):
    r, g, b, _ = rgb(h)
    f = lambda k: (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), 255)
    return {'m': rgb(h), 'd': f(dk), 'l': f(lt), 'dd': f(dk * dk)}


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

    def mass(self, x0, y0, x1, y1, t, top=(2, 1), bot=(1,), back=2, hem=2, lit=True):
        """A soft block: corners cut by `top` / `bot` (pixels taken off each end of the first / last rows), the BACK edge (left) and the bottom
        rows in the shade tone, a lit line down the front shoulder."""
        rows = int(y1) - int(y0) + 1
        for i in range(rows):
            y = int(y0) + i
            cut = top[i] if i < len(top) else (bot[rows - 1 - i] if rows - 1 - i < len(bot) else 0)
            for x in range(int(x0) + cut, int(x1) - cut + 1):
                c = t['m']
                if x - (int(x0) + cut) < back or rows - 1 - i < hem:
                    c = t['d']
                self.put(x, y, c)
            if lit and len(top) <= i < rows - hem - 1:
                self.put(int(x1) - cut - 1, y, t['l'])


def leg(c, hx, hy, fx, fy, knee, col, w=4):
    """A solid leg `w` wide from the hip (hx, hy) to the ankle (fx, fy): the knee pushes forward by `knee` px at the middle."""
    n = max(1, int(fy) - int(hy))
    for i in range(n + 1):
        t = i / float(n)
        x = hx + (fx - hx) * t + knee * 4.0 * t * (1.0 - t)
        xi = int(round(x))
        for k in range(w):
            c.put(xi + k, int(hy) + i, col['d'] if k == 0 else (col['l'] if k == w - 1 and col.get('lit') else col['m']))


def shoe(c, fx, fy, col, lift=0, long=6):
    """The shoe under an ankle whose left pixel is fx: a heel, a sole and a toe out in front. A lifted foot tips its toe down."""
    x = int(round(fx))
    c.rect(x, fy, x + 3, fy, col['m'])
    c.rect(x, fy + 1, x + long - 2, fy + 1, col['m'])
    c.rect(x, fy + 2, x + long - 1, fy + 2, col['d'])
    c.put(x + long - 2, fy + 1, col['l'])
    if lift:
        c.put(x, fy + 2, (0, 0, 0, 0))                       # the heel comes up first
        c.put(x + long - 1, fy + 3, col['d'])


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
    skin = tones(p['skin'], 0.84, 1.06)
    legc = tones(p['legs'])
    legf = tones(p['legs'], 0.62, 0.8)
    sho = tones(p['shoes'], 0.7, 1.5)
    hair = tones(p['hair'], 0.74, 1.22)
    ankle = GROUND - 2
    arm = pose.get('arm', 0)

    # ---- behind the body: the far arm, the far leg
    fdx, flift, fknee = pose['far']
    ndx, nlift, nknee = pose['near']
    hip_y = hem - 2
    leg(c, cx + 2, hip_y, cx + 2 + fdx, ankle - flift, fknee, legf)
    shoe(c, cx + 2 + fdx, ankle - flift, tones(p['shoes'], 0.6, 1.2), flift)
    c.rect(x1 - 1 - arm, sh + 4, x1 + 1 - arm, hem - 5, g['d'])                    # the far sleeve, a sliver at the front edge
    c.rect(x1 - arm, hem - 4, x1 + 1 - arm, hem - 3, skin['d'])                    # and its hand
    # ---- the near leg
    legc['lit'] = True
    leg(c, cx - 5, hip_y, cx - 5 + ndx, ankle - nlift, nknee, legc)
    shoe(c, cx - 5 + ndx, ankle - nlift, sho, nlift)
    # ---- long hair down the back goes BEHIND the coat's shoulder
    sway = pose.get('sway', 0)
    if p['hairstyle'] == 'long':
        c.mass(cx - 8 - (1 if sway > 0 else 0), top + 3, cx - 2, top + 21, hair, top=(1,), bot=(2, 1), back=2, hem=1, lit=False)
        c.rect(cx - 8 - sway, top + 19, cx - 4 - sway, top + 22, hair['d'])
    # ---- a skirt or a long hem under the coat
    if p.get('skirt'):
        sk = tones(p['skirt'])
        c.mass(x0 + 1, hem - 1, x1 - 1, hem + p.get('skirt_len', 3), sk, top=(), bot=(1,), back=3, hem=1, lit=False)
    # ---- the coat: one big soft mass, shoulders rounded, the hem in shade
    c.mass(x0, sh, x1, hem, g, top=(3, 2, 1), bot=(1,), back=3, hem=2)
    if p.get('open'):                                                              # worn open: what is under it shows down the front
        inner = tones(p['open'])
        c.rect(x1 - 4, sh + 2, x1 - 3, hem - 1, inner['m'])
        c.rect(x1 - 5, sh + 2, x1 - 5, hem, g['d'])
    if p.get('buttons'):
        for y in range(sh + 5, hem - 2, 4):
            c.put(x1 - 3, y, rgb(p['buttons']))
    if p.get('pocket'):
        c.rect(cx + 1, hem - 7, cx + 4, hem - 7, g['d'])
    if p.get('stripe'):                                                            # a band round the chest
        st = tones(p['stripe'])
        c.rect(x0 + 1, sh + 6, x1 - 1, sh + 8, st['m'])
        c.rect(x0 + 1, sh + 6, x0 + 3, sh + 8, st['d'])
    # ---- the near arm: a sleeve hanging down the side, its edge and cuff in shade, a hand under it
    ax = cx - 3 + arm
    top_ax = cx - 3 + (1 if arm > 0 else (-1 if arm < 0 else 0))
    for y in range(sh + 3, hem - 3):
        t = (y - sh - 3) / float(max(1, hem - 7 - sh))
        xx = int(round(top_ax + (ax - top_ax) * t))
        c.put(xx - 1, y, g['dd'])
        c.rect(xx, y, xx + 3, y, g['m'])
        c.put(xx + 3, y, g['l'])
        c.put(xx + 4, y, g['d'])
    c.rect(ax - 1, hem - 3, ax + 4, hem - 3, g['dd'])                              # the cuff
    c.rect(ax, hem - 2, ax + 2, hem - 1, skin['m'])                                # the hand
    c.put(ax, hem - 2, skin['d'])
    if p.get('scarf'):
        sc = tones(p['scarf'])
        c.mass(x0 + 3, sh - 1, x1 - 1, sh + 2, sc, top=(1,), bot=(1,), back=2, hem=1, lit=False)
        c.rect(x1 - 5, sh + 2, x1 - 3, sh + 8, sc['m'])
        c.rect(x1 - 5, sh + 2, x1 - 5, sh + 8, sc['d'])
    # ---- the head: a block of skin, the face toward the front, the hair a mass over and behind it
    hx0, hx1 = cx - 6, cx + 6
    if p['hairstyle'] == 'hood':
        c.mass(hx0 - 1, top, hx1 + 1, top + 14, g, top=(4, 2, 1), bot=(1,), back=3, hem=1)
        fur = tones(p.get('fur', 'd8ccb8'), 0.82, 1.08)
        c.mass(cx - 2, top + 2, hx1 + 1, top + 13, fur, top=(2, 1), bot=(2, 1), back=1, hem=1, lit=False)
        c.mass(cx - 1, top + 3, hx1, top + 12, skin, top=(2, 1), bot=(2, 1), back=1, hem=1, lit=False)
    else:
        c.mass(hx0, top + 1, hx1, top + 13, skin, top=(3, 2, 1), bot=(3, 2), back=0, hem=1, lit=False)
        st = p['hairstyle']
        if st in ('long', 'bob', 'short', 'bun', 'beanie'):
            c.mass(hx0 - 1, top, hx1, top + 5, hair, top=(4, 2, 1), bot=(), back=3, hem=0, lit=False)        # the cap of hair
            c.rect(hx0 - 1, top + 5, cx - 2, top + (13 if st in ('long', 'bob') else 9), hair['m'])           # down the back of the head
            c.rect(hx0 - 1, top + 5, hx0, top + (13 if st in ('long', 'bob') else 9), hair['d'])
            c.rect(cx - 1, top + 4, hx1 - 1, top + 5, hair['m'])                                               # a fringe
            c.rect(cx + 1, top + 2, cx + 4, top + 2, hair['l'])                                                # a sheen on the crown
            if st == 'bob':
                c.rect(hx0 - 2, top + 9, cx - 2, top + 14, hair['m'])
                c.rect(hx0 - 2, top + 13, cx - 2, top + 14, hair['d'])
            if st == 'bun':
                c.mass(hx0 - 4, top + 1, hx0, top + 6, hair, top=(1,), bot=(1,), back=2, hem=1, lit=False)
            if st == 'beanie':
                hat = tones(p['hat'])
                c.mass(hx0 - 1, top - 1, hx1, top + 4, hat, top=(4, 2, 1), bot=(), back=3, hem=0)
                c.rect(hx0 - 1, top + 4, hx1, top + 5, hat['d'])
                c.rect(cx - 1, top - 2, cx + 1, top - 2, hat['l'])
        elif st == 'bald':
            c.rect(hx0, top + 6, hx0 + 2, top + 10, hair['m'])                                                 # what is left, round the back
            c.rect(hx0, top + 9, hx0 + 1, top + 10, hair['d'])
            c.rect(cx, top + 2, cx + 3, top + 2, skin['l'])
    # ---- the face: two dark eyes, nothing else (a blink is one row)
    ey = top + 7
    for ex in (cx + 1, cx + 5):
        if pose.get('blink'):
            c.rect(ex, ey + 1, ex + 1, ey + 1, EYE)
        else:
            c.rect(ex, ey, ex + 1, ey + 1, EYE)
    if p.get('glasses'):
        gl = rgb(p['glasses'])
        c.rect(cx, ey - 1, cx + 7, ey - 1, gl)
        c.put(cx + 3, ey, gl)
        c.put(cx + 4, ey, gl)
    if p.get('tache'):
        c.rect(cx + 2, ey + 3, cx + 6, ey + 3, tones(p['hair'])['d'])
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
    dict(name='nell', top=4, torso_w=18, hem=35, coat='b5533c', skin='e8d6c8', hair='3a2a34', hairstyle='long', legs='2e2a36', shoes='18161c',
         pocket=True, buttons='e8d6c8'),                                                                     # a girl in a red duffel coat, black tights
    dict(name='mrs_okafor', top=6, torso_w=20, hem=34, coat='8a6f9a', skin='8a5a44', hair='b8b4b8', hairstyle='bun', legs='7a5240', shoes='5a3a4a',
         skirt='4a4458', skirt_len=5, open='e0d8c4', glasses='2a2630'),                                      # an older woman: a long cardigan over a skirt, slippers
    dict(name='dale', top=3, torso_w=20, hem=33, coat='5d7a4a', skin='e2c4a8', hair='6a4a2a', hairstyle='hood', legs='3a4254', shoes='e4e0d8',
         fur='d8c8a8', pocket=True),                                                                         # a lad in a parka, hood up, joggers, white trainers
    dict(name='mr_hale', top=3, torso_w=22, hem=33, coat='c8b48a', skin='e6c8b0', hair='5a5450', hairstyle='bald', legs='55525c', shoes='4a3324',
         scarf='7a2e2e', tache=True, buttons='7a6a4a'),                                                      # a big man in a camel overcoat and a scarf
    dict(name='priya', top=5, torso_w=18, hem=33, coat='e0b23c', skin='b07a56', hair='241c22', hairstyle='bob', legs='34506e', shoes='2a2630',
         stripe='f0e6d0'),                                                                                   # a yellow jumper with a band, jeans
    dict(name='tomasz', top=4, torso_w=19, hem=32, coat='3f5f8a', skin='e4ccb4', hair='c8a468', hairstyle='beanie', hat='b84a36', legs='6a5a48',
         shoes='2a2420', open='d8d4cc'),                                                                     # a blue work jacket worn open, a red beanie
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
