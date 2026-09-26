"""Apartment doors: closed -> opening -> open, one sheet per corridor look.

Run:  python3 tools/art/doors.py
Out:  assets/doors/door_<high|mid|low>.png — a horizontal strip of FRAMES frames (door.gd
      Sprite2D hframes), previews in docs/art_reference/doors/.

A door is its casing (architrave) plus the leaf. The leaf is hinged on the LEFT and swings IN,
away from the corridor: seen straight on, its face narrows (cos of the angle) and its free edge
shrinks a little with depth, and the dark entry hall of the flat opens up behind it — a floor
strip, a coat on a hook, a warm glow from a room further in. Frame 0 = closed, the last = open
(the leaf nearly edge-on against the inside wall). door.gd plays 0 -> last to open, back to shut,
and holds frame AJAR for a breached door (kicked in, hanging open).

Native resolution (1 px = 1 world px, the corridor's scale): 46 x 84, bottom row on the corridor
floor. The leaf is kept LIGHT because door.gd tints doors by state (warm = unlocked, red = locked,
purple = breached) and a tint only reads on a light surface. Authored FLAT (lit by the engine).
"""
import math
import os
import random
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, mix
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
W, H = 46, 84
CAS = 3                                  # casing width
LW, LH = W - 2 * CAS, H - CAS            # the opening / leaf: 40 x 81
ANGLES = [0, 28, 52, 72, 86]             # degrees the leaf has swung in, per frame
FRAMES = len(ANGLES)
AJAR = 2                                 # the frame a breached door hangs at

# Ten doors. `home` is the corridor section they belong to (door.gd picks mostly from the door's
# own section, now and then one from anywhere — residents replace doors).
STYLES = {
    # --- the hotel floors ---
    'oak': dict(home='high', leaf='c49a66', panel='b08654', line='8a643e', hi='dab282', casing='5e3828',
                casing_hi='7a4a34', metal='d9b86a', metal_dk='8a6a2a', panels=4, plate=True),
    'walnut': dict(home='high', leaf='a88258', panel='987448', line='74553a', hi='c09a70', casing='4a2a1e',
                   casing_hi='6a3e2c', metal='d9b86a', metal_dk='8a6a2a', panels=6, letterbox=True),
    'sage': dict(home='high', leaf='a9b79a', panel='9aa98b', line='76846a', hi='c2cfb4', casing='5e3828',
                 casing_hi='7a4a34', metal='d9b86a', metal_dk='8a6a2a', panels=4, plate=True, kick=True),
    'glazed': dict(home='high', leaf='caa478', panel='b89266', line='94704c', hi='e0bc90', casing='5e3828',
                   casing_hi='7a4a34', metal='d9b86a', metal_dk='8a6a2a', panels=2, glass=True),
    # --- residential ---
    'cream': dict(home='mid', leaf='ddd2b8', panel='cfc3a6', line='aa9e82', hi='ece4d0', casing='d6cbb0',
                  casing_hi='ece4cc', metal='c8ccd0', metal_dk='7a7e84', panels=2, letterbox=True),
    'white': dict(home='mid', leaf='e6e2d8', panel='dcd8cc', line='b4b0a6', hi='f2efe8', casing='d6cbb0',
                  casing_hi='ece4cc', metal='c8ccd0', metal_dk='7a7e84', panels=0, peep=True, number=True),
    'blue': dict(home='mid', leaf='a8bccc', panel='9aaebe', line='7a8e9e', hi='c2d2de', casing='d6cbb0',
                 casing_hi='ece4cc', metal='c8ccd0', metal_dk='7a7e84', panels=4, letterbox=True),
    # --- institutional ---
    'fire': dict(home='low', leaf='b8bcb4', panel='b0b4ac', line='8a8e88', hi='cfd2cc', casing='6e7672',
                 casing_hi='8e9692', metal='d0d4d0', metal_dk='5a5e5c', panels=0, vision=True, kick=True),
    'steel': dict(home='low', leaf='aeb8a8', panel='a6b0a0', line='848e80', hi='c6cec0', casing='6e7672',
                  casing_hi='8e9692', metal='d0d4d0', metal_dk='5a5e5c', panels=0, kick=True, number=True, peep=True),
    'grille': dict(home='low', leaf='c0b8a4', panel='b4ac98', line='8e8672', hi='d4ccb8', casing='6e7672',
                   casing_hi='8e9692', metal='4a4e52', metal_dk='2a2c30', panels=0, grille=True, peep=True),
}
SECTION_STYLES = {s: [k for k, v in STYLES.items() if v['home'] == s] for s in ('high', 'mid', 'low')}
BREACH_HANGING, BREACH_SMASHED = FRAMES, FRAMES + 1
STRIP = FRAMES + 2                       # 0..4 the swing, 5 off its hinges, 6 kicked through


def leaf_face(st):
    """The door's front face, flat, LW x LH."""
    c = Canvas(w=LW, h=LH, seed=3)
    leaf, panel, line, hi = (hexc(st[k]) for k in ('leaf', 'panel', 'line', 'hi'))
    c.rect(0, 0, LW - 1, LH - 1, leaf)
    for y in range(0, LH, 3):                                    # a faint grain / brushed finish
        for x in range(0, LW):
            if (x * 7 + y * 3) % 11 == 0:
                c.put(x, y, shade(leaf, 0.97))
    c.vline(0, 0, LH - 1, shade(leaf, 1.08))
    c.vline(LW - 1, 0, LH - 1, shade(leaf, 0.8))
    c.hline(0, LW - 1, 0, shade(leaf, 1.08))

    def raised(x0, y0, x1, y1):
        c.rect(x0, y0, x1, y1, panel)
        c.hline(x0, x1, y0, line)
        c.vline(x0, y0, y1, line)
        c.hline(x0, x1, y1, hi)
        c.vline(x1, y0, y1, hi)
        c.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, shade(panel, 1.04))
        c.hline(x0 + 3, x1 - 3, y0 + 3, hi)
        c.vline(x0 + 3, y0 + 3, y1 - 3, hi)
        c.hline(x0 + 3, x1 - 3, y1 - 3, line)
        c.vline(x1 - 3, y0 + 3, y1 - 3, line)
    if st['panels'] == 4:
        raised(5, 5, 18, 34); raised(21, 5, 34, 34)
        raised(5, 40, 18, 75); raised(21, 40, 34, 75)
    elif st['panels'] == 6:
        for (y0, y1) in ((5, 22), (26, 50), (54, 75)):
            raised(5, y0, 18, y1); raised(21, y0, 34, y1)
    elif st['panels'] == 2:
        raised(5, 5, 34, 36); raised(5, 42, 34, 75)
    if st.get('glass'):                                          # a frosted upper pane
        c.rect(7, 7, 32, 34, hexc('c8d2d0'))
        c.rect(8, 8, 31, 33, hexc('aebcbc'))
        for y in range(9, 33, 2):
            for x in range(9, 31, 2):
                if (x + y) % 4 == 0:
                    c.put(x, y, hexc('c2cece'))
        c.line(10, 30, 20, 10, hexc('d8e2e0'))
        c.rect(19, 7, 20, 34, hi)                                # a glazing bar
    if st.get('peep'):
        c.rect(18, 24, 20, 26, hexc(st['metal']))
        c.put(19, 25, hexc('141010'))
    if st.get('number'):                                         # a screwed-on number
        c.rect(15, 14, 17, 19, hexc(st['metal_dk'])); c.rect(21, 14, 23, 19, hexc(st['metal_dk']))
        c.put(16, 16, leaf); c.put(22, 16, leaf)
    metal, mdk = hexc(st['metal']), hexc(st['metal_dk'])
    if st.get('vision'):                                         # a narrow wired-glass pane
        c.rect(24, 8, 31, 34, mdk)
        c.rect(25, 9, 30, 33, hexc('3a4448'))
        for y in range(10, 33, 3):
            for x in range(25, 31):
                if (x + y) % 3 == 0:
                    c.put(x, y, hexc('6a7478'))
        c.line(25, 30, 29, 12, hexc('7a8a8e'))
    if st.get('kick'):                                           # a scuffed kick plate
        c.rect(2, 66, LW - 3, 77, shade(metal, 0.92))
        c.hline(2, LW - 3, 66, shade(metal, 1.08))
        for x in range(4, LW - 4, 5):
            c.put(x, 70 + x % 4, shade(metal, 0.75))
    if st.get('plate'):                                          # brass number plate + knocker
        c.rect(16, 18, 23, 22, metal)
        c.hline(16, 23, 22, mdk)
        c.rect(18, 19, 18, 21, mdk); c.rect(21, 19, 21, 21, mdk)
        c.ellipse(19, 28, 2, 2, metal)
        c.put(19, 28, mdk)
    if st.get('letterbox'):
        c.rect(12, 38, 27, 40, metal)
        c.hline(13, 26, 39, mdk)
        c.rect(17, 14, 22, 17, metal)                            # the number
        c.put(18, 15, mdk); c.put(21, 15, mdk)
    if st.get('grille'):                                         # a steel security grille
        for x in range(3, LW - 3, 5):
            c.vline(x, 3, LH - 4, metal)
            c.vline(x + 1, 3, LH - 4, mdk)
        for y in (3, 26, 52, LH - 4):
            c.rect(2, y, LW - 3, y + 1, metal)
        for y in range(8, LH - 8, 10):                           # diamond braces
            for k in range(5):
                c.put(3 + k * 7, y + (k % 2) * 4, metal)
    c.rect(33, 41, 35, 44, metal)                                # the handle + keyhole
    c.rect(30, 42, 35, 43, metal)
    c.hline(30, 35, 44, mdk)
    c.put(34, 47, hexc('1e1a16'))
    c.put(34, 48, hexc('1e1a16'))
    c.hline(0, LW - 1, LH - 1, shade(leaf, 0.6))
    return c.img


def interior(st, seed):
    """What you see through the open doorway: the flat's dark entry hall."""
    c = Canvas(w=LW, h=LH, seed=seed)
    rng = random.Random(seed)
    wall_dk, wall = hexc('1e1a17'), hexc('2c2622')
    c.rect(0, 0, LW - 1, LH - 1, wall_dk)
    c.rect(6, 6, LW - 7, LH - 20, wall)                           # the far wall of the hall
    for y in range(6, LH - 20, 4):
        c.hline(6, LW - 7, y, shade(wall, 0.94))
    c.poly([(0, LH - 1), (LW - 1, LH - 1), (LW - 7, LH - 20), (6, LH - 20)], hexc('3a2e24'))   # floor
    for k in range(4):                                            # boards running away from us
        x0 = 6 + k * 8
        c.line(int(x0 - (x0 - LW / 2) * 0.0), LH - 20, int(x0 + (x0 - LW / 2) * 0.9), LH - 1, hexc('2e241c'))
    c.poly([(0, 0), (6, 6), (6, LH - 20), (0, LH - 1)], hexc('141210'))          # side walls
    c.poly([(LW - 1, 0), (LW - 7, 6), (LW - 7, LH - 20), (LW - 1, LH - 1)], hexc('181513'))
    gx = LW - 12                                                  # a warm glow from a room beyond
    for y in range(12, LH - 20):
        for x in range(gx - 4, gx + 5):
            k = 1.0 - abs(x - gx) / 5.0
            if k > 0:
                c.put(x, y, mix(c.px[x, y], hexc('8a6a3e'), 0.35 * k))
    c.rect(gx - 3, 14, gx + 3, LH - 21, mix(hexc('2c2622'), hexc('b08a50'), 0.35))
    c.vline(gx - 4, 14, LH - 21, hexc('141210'))
    c.poly([(gx - 3, LH - 20), (gx + 3, LH - 20), (gx + 6, LH - 12), (gx - 1, LH - 12)],
           mix(hexc('3a2e24'), hexc('b08a50'), 0.3))              # its light spilling on the floor
    c.rect(10, 20, 11, 22, hexc('5a5048'))                        # a coat on a hook
    c.poly([(9, 22), (13, 22), (15, 44), (8, 46)], hexc('2e3240'))
    c.line(9, 22, 8, 46, hexc('3e4254'))
    return c.img


def compose(st, angle, seed):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cas, cas_hi = hexc(st['casing']), hexc(st['casing_hi'])
    c = Canvas(w=W, h=H, seed=seed)
    c.img = img
    c.px = img.load()
    c.rect(0, 0, W - 1, H - 1, cas)                               # the casing
    c.vline(0, 0, H - 1, shade(cas, 0.6))
    c.vline(W - 1, 0, H - 1, shade(cas, 0.55))
    c.hline(0, W - 1, 0, shade(cas, 0.7))
    c.vline(1, 1, H - 1, cas_hi)
    c.hline(1, W - 2, 1, cas_hi)
    c.vline(W - 3, CAS, H - 1, shade(cas, 0.8))
    face = leaf_face(st).load()
    ins = interior(st, seed).load()
    ox, oy = CAS, CAS
    for y in range(LH):                                           # the doorway, behind the leaf
        for x in range(LW):
            c.px[ox + x, oy + y] = ins[x, y]
    if angle == 0:
        for y in range(LH):
            for x in range(LW):
                c.px[ox + x, oy + y] = face[x, y]
        return img
    a = math.radians(angle)
    wv = max(2, int(round(LW * math.cos(a))))                     # how wide the face still looks
    sink = int(round(3.5 * math.sin(a)))                          # the free edge recedes (shorter)
    dark = 1.0 - 0.45 * math.sin(a)                               # turned from the corridor's light
    for x in range(wv):
        t = x / float(max(1, wv - 1))
        top, bot = oy + int(round(sink * t)), oy + LH - 1 - int(round(sink * t))
        sx = min(LW - 1, int(x * LW / float(wv)))
        for y in range(top, bot + 1):
            sy = min(LH - 1, int((y - top) * LH / float(max(1, bot - top + 1))))
            c.px[ox + x, y] = shade(face[sx, sy], dark)
    edge = shade(hexc(st['hi']), 0.9)                             # the door's thickness at its free edge
    thick = 1 if angle < 60 else 2
    for k in range(thick):
        x = ox + wv + k
        if x < ox + LW:
            for y in range(oy + sink, oy + LH - sink):
                c.px[x, y] = shade(edge, 1.0 - 0.1 * k)
    for y in range(oy + sink + 2, oy + LH - sink):                # its shadow on the hall floor/wall
        x = ox + wv + thick
        if x < ox + LW:
            c.px[x, y] = shade(c.px[x, y], 0.55)
    c.vline(ox, oy, oy + LH - 1, shade(cas, 0.45))                # the hinge side's shadow line
    return img


def _blob(rng, cx, cy, rx, ry):
    ph = [rng.random() * 6.28 for _ in range(3)]

    def f(x, y):
        a = math.atan2((y - cy) / ry, (x - cx) / rx)
        k = 1.0 + 0.22 * math.sin(3 * a + ph[0]) + 0.14 * math.sin(5 * a + ph[1]) + 0.1 * math.sin(11 * a + ph[2])
        return (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2) ** 0.5 / k
    return f


def _casing(c, st):
    cas, cas_hi = hexc(st['casing']), hexc(st['casing_hi'])
    c.rect(0, 0, W - 1, H - 1, cas)
    c.vline(0, 0, H - 1, shade(cas, 0.6))
    c.vline(W - 1, 0, H - 1, shade(cas, 0.55))
    c.hline(0, W - 1, 0, shade(cas, 0.7))
    c.vline(1, 1, H - 1, cas_hi)
    c.hline(1, W - 2, 1, cas_hi)
    c.vline(W - 3, CAS, H - 1, shade(cas, 0.8))


def _splinters(c, rng, x, y, n, col, spread=4):
    for k in range(n):
        dx, dy = rng.randrange(-spread, spread + 1), rng.randrange(-spread, spread + 1)
        ln = rng.randrange(2, 5)
        for j in range(ln):
            c.put(x + dx + (j if dx >= 0 else -j), y + dy + (j // 2), col)


def breach_hanging(st, seed):
    """Torn off its top hinge: the door has dropped and swung, leaning in the frame, the flat's
    dark hall showing round it; the casing is splintered where the hinges ripped out."""
    rng = random.Random(seed)
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    c = Canvas(w=W, h=H, seed=seed)
    c.img, c.px = img, img.load()
    _casing(c, st)
    ins = interior(st, seed).load()
    for y in range(LH):
        for x in range(LW):
            c.px[CAS + x, CAS + y] = ins[x, y]
    leaf = leaf_face(st)
    leaf = leaf.resize((LW - 4, LH - 4), Image.NEAREST)            # pushed back into the hall a little
    tilt = rng.choice((9, 11, 13))
    rot = leaf.rotate(-tilt, resample=Image.NEAREST, expand=True)
    # the bottom-left corner stays on the threshold, the top has fallen across to the right jamb
    ox = CAS + 1
    oy = CAS + LH - rot.size[1] + 1
    dark = Image.new('RGBA', rot.size, (0, 0, 0, 0))
    for y in range(rot.size[1]):
        for x in range(rot.size[0]):
            p = rot.getpixel((x, y))
            if p[3] > 0:
                dark.putpixel((x, y), shade(p, 0.78))
    region = Image.new('RGBA', (LW, LH), (0, 0, 0, 0))
    region.alpha_composite(dark, (ox - CAS, oy - CAS)) if oy >= CAS else region.alpha_composite(dark.crop((0, CAS - oy, dark.size[0], dark.size[1])), (ox - CAS, 0))
    rp = region.load()
    for y in range(LH):
        for x in range(LW):
            if rp[x, y][3] > 0:
                c.px[CAS + x, CAS + y] = rp[x, y]
    edge = hexc(st['hi'])
    for y in range(CAS, CAS + 12):                                   # the hinges torn out, raw wood
        c.put(CAS - 1, y, shade(edge, 1.05))
        c.put(CAS, y, shade(edge, 0.9))
    c.rect(0, 6, 2, 11, shade(edge, 0.95))                           # a split in the casing
    c.line(1, 5, 3, 14, hexc('241a14'))
    _splinters(c, rng, CAS + 2, CAS + 6, 6, shade(edge, 1.1))
    for y in range(CAS + 58, CAS + 64):                               # the lower hinge, bent
        c.put(CAS, y, hexc(st['metal_dk']))
    return img


def breach_smashed(st, seed):
    """Kicked through: the door still in its frame but a ragged hole through the middle into the
    dark hall, splinters round it, cracks running off, the lock torn out, the jamb split."""
    rng = random.Random(seed)
    img = compose(st, 0, seed)
    c = Canvas(w=W, h=H, seed=seed)
    c.img, c.px = img, img.load()
    ins = interior(st, seed).load()
    hx, hy = CAS + 18 + rng.randrange(-3, 4), CAS + 44 + rng.randrange(-6, 6)
    f = _blob(rng, hx, hy, rng.randrange(9, 13), rng.randrange(13, 19))
    edge = hexc(st['hi'])
    for y in range(CAS, CAS + LH):
        for x in range(CAS, CAS + LW):
            d = f(x, y)
            if d <= 1.0:
                p = ins[x - CAS, y - CAS]
                c.px[x, y] = shade(p, 0.85) if d > 0.85 and y < hy else p       # the lip's shadow
            elif d <= 1.18 and rng.random() < 0.75:
                c.px[x, y] = shade(edge, 1.05) if rng.random() < 0.6 else shade(edge, 0.8)   # raw splinters
    for k in range(6):                                                # cracks running off it
        a = rng.uniform(0, 6.28)
        r0 = 12
        for r in range(r0, r0 + rng.randrange(6, 16)):
            x, y = int(hx + math.cos(a) * r * 0.8), int(hy + math.sin(a) * r * 1.2)
            if CAS < x < CAS + LW - 1 and CAS < y < CAS + LH - 1:
                c.put(x, y, shade(hexc(st['leaf']), 0.5))
            a += rng.uniform(-0.15, 0.15)
    c.rect(CAS + 29, CAS + 38, CAS + 35, CAS + 47, hexc('1e1a16'))       # the lock torn out
    c.put(CAS + 33, CAS + 49, hexc(st['metal']))                       # the handle hanging
    c.put(CAS + 33, CAS + 50, hexc(st['metal']))
    c.put(CAS + 32, CAS + 51, hexc(st['metal_dk']))
    for y in range(CAS + 34, CAS + 52):                                # the strike-side jamb split
        c.put(W - 3, y, shade(edge, 1.0 if y % 3 else 0.8))
        c.put(W - 2, y, shade(edge, 0.9))
    c.rect(CAS + 6, CAS + 66, CAS + 16, CAS + 72, shade(hexc(st['leaf']), 0.78))   # a boot print, low down
    return img


def interior_sized(w, h, seed):
    """The flat's dark hall at any size (for the hole in the wall)."""
    c = Canvas(w=w, h=h, seed=seed)
    c.rect(0, 0, w - 1, h - 1, hexc('1e1a17'))
    c.rect(8, 8, w - 9, h - 22, hexc('2c2622'))
    for y in range(8, h - 22, 4):
        c.hline(8, w - 9, y, shade(hexc('2c2622'), 0.94))
    c.poly([(0, h - 1), (w - 1, h - 1), (w - 9, h - 22), (8, h - 22)], hexc('3a2e24'))
    gx = w - 16
    c.rect(gx - 4, 14, gx + 4, h - 23, mix(hexc('2c2622'), hexc('b08a50'), 0.35))
    c.poly([(gx - 4, h - 22), (gx + 4, h - 22), (gx + 8, h - 12), (gx - 1, h - 12)],
           mix(hexc('3a2e24'), hexc('b08a50'), 0.3))
    return c.img


HOLE_W, HOLE_WALL_H, HOLE_DEBRIS = 92, 102, 26
HOLE_H = HOLE_WALL_H + HOLE_DEBRIS          # the wall part, then the corridor floor in front of it
HOLE_VARIANTS = 3


def wall_hole(section, seed):
    """A BREACHED door (owner round 21 — "a kool aid man style breached hole in the wall and then
    broken pieces of the door on the corridor floor"): something came THROUGH the wall. A big
    burst-shaped hole where the door was — wider than the doorway, jagged all round — cracks running
    off across the wall, plaster blown off round it to the blockwork, the dark flat beyond with blood
    up its walls; below the wall line, on the corridor floor, the door in pieces (panels, splinters,
    the handle, a hinge), rubble and dust, and a bloody drag smear out of the hole. Transparent
    outside the damage (the corridor shows)."""
    rng = random.Random(seed)
    st = STYLES[SECTION_STYLES[section][rng.randrange(len(SECTION_STYLES[section]))]]
    img = Image.new('RGBA', (HOLE_W, HOLE_H), (0, 0, 0, 0))
    c = Canvas(w=HOLE_W, h=HOLE_H, seed=seed)
    c.img, c.px = img, img.load()
    cx = HOLE_W // 2 + rng.randint(-3, 3)
    floor_y = HOLE_WALL_H - 1                                      # the wall meets the corridor floor
    blood, blood_dk, blood_lt = hexc('6a0e10'), hexc('3e0808'), hexc('8e1a1a')
    # --- the burst: a radial outline, spiky, wider than the door, sitting on the floor ---
    cy = floor_y - 34
    spikes = [(rng.uniform(-3.1, 0.0), rng.uniform(3, 8)) for _ in range(8)]      # teeth, mostly up + sides

    def radius(ang):
        r = 25.0 + 3.0 * math.cos(2 * ang)
        for (a0, amp) in spikes:
            d = math.atan2(math.sin(ang - a0), math.cos(ang - a0))
            r += amp * max(0.0, 1.0 - abs(d) / 0.2)                  # jagged teeth
        r += 2.0 * math.sin(ang * 11 + seed)
        return min(r, 36.0)

    def inside(x, y):
        if y > floor_y or x < 6 or x > HOLE_W - 7:
            return False
        if y > floor_y - 12 and abs(x - cx) < 21 + (y - floor_y + 12) * 0.4:
            return True                                              # it opens flat onto the floor
        dx, dy = (x - cx) / 1.0, (y - cy) / 1.35                     # upright; it runs into the floor
        return math.hypot(dx, dy) < radius(math.atan2(dy, dx))
    hole = [[inside(x, y) for x in range(HOLE_W)] for y in range(HOLE_H)]

    def ring(x, y, rad):
        for dy in range(-rad, rad + 1):
            for dx in range(-rad, rad + 1):
                xx, yy = x + dx, y + dy
                if 0 <= xx < HOLE_W and 0 <= yy <= floor_y and hole[yy][xx]:
                    return True
        return False
    plaster, plaster_dk, plaster_lt = hexc('cbb89c'), hexc('a8977c'), hexc('ddcdb2')
    brick, mortar = hexc('9a5238'), hexc('5e5046')
    for y in range(HOLE_WALL_H):
        for x in range(HOLE_W):
            if hole[y][x]:
                # the flat beyond: its far wall in the dark, the floor running back at the bottom
                if y < floor_y - 11:
                    t = (y - (cy - 45)) / 60.0
                    c.px[x, y] = mix(hexc('0c0a09'), hexc('2a211c'), max(0.0, min(1.0, 1.0 - abs(t - 0.55) * 1.6)))
                else:
                    c.px[x, y] = mix(hexc('2c2019'), hexc('171210'), (floor_y - y) / 11.0)
            elif ring(x, y, 2):                                     # blockwork, broken through
                sh = 5 if (y // 4) % 2 else 0
                col = mortar if y % 4 == 0 or (x + sh) % 10 == 0 else (brick if (x * 3 + y) % 7 else shade(brick, 0.75))
                c.px[x, y] = col
            elif ring(x, y, 5) and rng.random() < 0.85:             # plaster blown off, ragged
                c.px[x, y] = plaster_lt if rng.random() < 0.3 else (plaster if rng.random() < 0.7 else plaster_dk)
    # the dark inside edge of the hole (depth), and blood up the flat's walls beyond
    for y in range(1, HOLE_WALL_H):
        for x in range(1, HOLE_W - 1):
            if hole[y][x] and not (hole[y - 1][x] and hole[y][x - 1] and hole[y][x + 1]):
                c.px[x, y] = hexc('0e0a08')
    def hput(x, y, col):
        if 0 <= x < HOLE_W and 0 <= y <= floor_y and hole[y][x]:
            c.px[x, y] = col
    # swipes of blood across the far wall at odd angles — dragged hands, something thrown against it —
    # with uneven runs off them; a splash; a pool on the floor in there
    for k in range(rng.randint(2, 4)):
        x0, y0 = cx + rng.randint(-18, 10), cy + rng.randint(-22, 4)
        ang = rng.uniform(-0.9, 0.9) + (0 if rng.random() < 0.5 else 3.14)
        ln = rng.randint(8, 18)
        wid = rng.choice((1, 2, 2, 3))
        for t in range(ln):
            x, y = int(x0 + math.cos(ang) * t), int(y0 + math.sin(ang) * t * 0.6)
            for w_ in range(wid - (1 if t > ln * 0.7 else 0)):
                hput(x, y + w_, blood if rng.random() < 0.75 else blood_dk)
            if rng.random() < 0.12:
                for d in range(rng.randint(2, 9)):
                    hput(x, y + wid + d, blood_dk)
    sx, sy = cx + rng.randint(-12, 12), cy + rng.randint(-12, 6)
    for k in range(14):
        a_, r_ = rng.uniform(0, 6.283), abs(rng.gauss(0, 4))
        hput(int(sx + math.cos(a_) * r_), int(sy + math.sin(a_) * r_), blood if r_ < 3 else blood_dk)
    for x in range(cx - 20, cx + 20):
        for y in range(floor_y - 6, floor_y + 1):
            if ((x - cx) / 20.0) ** 2 + ((y - floor_y + 3) / 3.5) ** 2 < 1.0:
                hput(x, y, blood_dk if rng.random() < 0.75 else blood)
    # cracks running off across the wall
    for k in range(7):
        ang = rng.uniform(-2.9, -0.25) if k < 5 else rng.choice((rng.uniform(-0.2, 0.1), rng.uniform(3.0, 3.3)))
        x, y = cx + math.cos(ang) * 30, cy + math.sin(ang) * 36
        for step in range(rng.randint(8, 18)):
            ang += rng.uniform(-0.5, 0.5)
            x += math.cos(ang) * 1.4
            y += math.sin(ang) * 1.4
            xi, yi = int(x), int(y)
            if 0 <= xi < HOLE_W and 0 <= yi <= floor_y and not hole[yi][xi]:
                c.px[xi, yi] = hexc('3a302a', 200)
    # a bloody hand dragged down the edge of the hole
    hx = cx + (rng.choice((-1, 1)) * 26)
    for y in range(cy - 6, cy + 18):
        for dx in range(3):
            xx = hx + dx + (y - cy) // 9
            if 0 <= xx < HOLE_W and not hole[y][xx]:
                c.px[xx, y] = blood if rng.random() < 0.8 else blood_dk
    # --- the corridor floor: the door in pieces, rubble, a drag smear out of the hole ---
    fy0 = floor_y + 1
    for y in range(fy0 + 2, HOLE_H - 2):                            # the drag smear
        t = (y - fy0) / HOLE_DEBRIS
        x0 = int(cx - 6 + 10 * t)
        for x in range(x0, x0 + 7 - int(3 * t)):
            if 0 <= x < HOLE_W and rng.random() < 0.85 - 0.4 * t:
                c.px[x, y] = blood_dk if rng.random() < 0.6 else blood
    leaf, line_, hi = hexc(st['leaf']), hexc(st['line']), hexc(st['hi'])
    metal = hexc(st['metal'])
    pieces = []
    for k in range(5):                                              # door panels / planks, lying flat
        w_ = rng.randint(10, 22)
        x = rng.randint(4, HOLE_W - w_ - 4)
        y = fy0 + rng.randint(3, HOLE_DEBRIS - 5)
        pieces.append((x, y, w_))
    for (x, y, w_) in sorted(pieces, key=lambda p: p[1]):
        tilt = rng.choice((-2, -1, 1, 2))
        c.poly([(x, y), (x + w_, y + tilt), (x + w_ - 1, y + tilt + 3), (x + 1, y + 3)], leaf)
        c.line(x, y, x + w_, y + tilt, hi)
        c.line(x + 3, y + 1, x + w_ - 3, y + 1 + tilt, line_)     # its panel moulding
        for s_ in range(2):                                         # splintered ends
            c.put(x + w_ + 1, y + 1 + s_, hi); c.put(x - 1, y + 2 - s_, line_)
    kx, ky = rng.randint(10, HOLE_W - 12), fy0 + rng.randint(8, HOLE_DEBRIS - 4)
    c.rect(kx, ky, kx + 1, ky + 1, metal); c.put(kx + 2, ky + 1, shade(metal, 0.6))   # the handle
    hx2, hy2 = rng.randint(8, HOLE_W - 10), fy0 + rng.randint(4, HOLE_DEBRIS - 4)
    c.rect(hx2, hy2, hx2 + 3, hy2, shade(metal, 0.8)); c.put(hx2 + 1, hy2 - 1, shade(metal, 0.8))  # a hinge
    for k in range(70):                                             # rubble + splinters, thick at the wall
        y = fy0 + int(abs(rng.gauss(0, 7)))
        if y >= HOLE_H - 1:
            continue
        x = int(rng.gauss(cx, 16 + (y - fy0)))
        if not (0 <= x < HOLE_W - 2):
            continue
        col = rng.choice([plaster, plaster_dk, plaster_lt, brick, shade(brick, 0.7), mortar, leaf, line_])
        w_ = rng.choice((1, 1, 2, 3))
        for dx in range(w_):
            c.put(x + dx, y, col)
        if w_ > 1 and rng.random() < 0.5:
            c.put(x, y - 1, shade(col, 1.12))
    for x in range(HOLE_W):                                         # dust settled along the wall's foot
        if rng.random() < 0.55 and abs(x - cx) < 40:
            c.put(x, fy0, plaster_dk if rng.random() < 0.5 else plaster)
    return img


def main():
    out_dir = os.path.join(ROOT, 'assets', 'doors')
    prev_dir = os.path.join(ROOT, 'docs', 'art_reference', 'doors')
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(prev_dir, exist_ok=True)
    for f in os.listdir(out_dir):                          # old sheets this script no longer makes
        if f.endswith('.png') or f.endswith('.png.import'):
            os.remove(os.path.join(out_dir, f))
    rows = []
    for i, (name, st) in enumerate(STYLES.items()):
        sheet = Image.new('RGBA', (W * STRIP, H), (0, 0, 0, 0))
        for f, ang in enumerate(ANGLES):
            sheet.paste(compose(st, ang, 10 + i), (W * f, 0))
        sheet.paste(breach_hanging(st, 40 + i), (W * BREACH_HANGING, 0))
        sheet.paste(breach_smashed(st, 60 + i), (W * BREACH_SMASHED, 0))
        sheet.save(os.path.join(out_dir, 'door_%s.png' % name))
        rows.append(sheet)
    holes = []
    for i, sec in enumerate(('high', 'mid', 'low')):
        for k in range(HOLE_VARIANTS):
            im = wall_hole(sec, 80 + i * 10 + k)
            im.save(os.path.join(out_dir, 'doorhole_%s_%d.png' % (sec, k)))
            holes.append(im)
    print('wrote %d doors (%d frames each) + %d wall holes' % (len(rows), STRIP, len(holes)))
    bg = (120, 110, 96, 255)
    prev = Image.new('RGBA', (max((W + 8) * STRIP + 8, (HOLE_W + 8) * 9 + 8), (H + 8) * len(rows) + HOLE_H + 16), bg)
    for r, sheet in enumerate(rows):
        for f in range(STRIP):
            prev.alpha_composite(sheet.crop((W * f, 0, W * f + W, H)), (f * (W + 8) + 4, r * (H + 8) + 4))
    for i, im in enumerate(holes):
        prev.alpha_composite(im, (4 + i * (HOLE_W + 8), (H + 8) * len(rows) + 8))
    prev.resize((prev.size[0] * 2, prev.size[1] * 2), Image.NEAREST).save(os.path.join(prev_dir, 'doors.png'))


if __name__ == '__main__':
    main()
