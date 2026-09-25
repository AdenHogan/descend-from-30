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

STYLES = {
    # the hotel floors: an oak panelled door, brass furniture, mahogany casing
    'high': dict(leaf='c49a66', panel='b08654', line='8a643e', hi='dab282', casing='5e3828',
                 casing_hi='7a4a34', metal='d9b86a', metal_dk='8a6a2a', panels=4, plate=True),
    # residential: a cream painted two-panel door, chrome furniture, a letterbox
    'mid': dict(leaf='ddd2b8', panel='cfc3a6', line='aa9e82', hi='ece4d0', casing='d6cbb0',
                casing_hi='ece4cc', metal='c8ccd0', metal_dk='7a7e84', panels=2, letterbox=True),
    # institutional: a pale grey steel fire door, a wired vision pane, a kick plate
    'low': dict(leaf='b8bcb4', panel='b0b4ac', line='8a8e88', hi='cfd2cc', casing='6e7672',
                casing_hi='8e9692', metal='d0d4d0', metal_dk='5a5e5c', panels=0, vision=True, kick=True),
}


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
    elif st['panels'] == 2:
        raised(5, 5, 34, 36); raised(5, 42, 34, 75)
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


def main():
    out_dir = os.path.join(ROOT, 'assets', 'doors')
    prev_dir = os.path.join(ROOT, 'docs', 'art_reference', 'doors')
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(prev_dir, exist_ok=True)
    rows = []
    for i, (name, st) in enumerate(STYLES.items()):
        sheet = Image.new('RGBA', (W * FRAMES, H), (0, 0, 0, 0))
        for f, ang in enumerate(ANGLES):
            sheet.paste(compose(st, ang, 10 + i), (W * f, 0))
        sheet.save(os.path.join(out_dir, 'door_%s.png' % name))
        rows.append(sheet)
        print('wrote door_%s (%d frames)' % (name, FRAMES))
    prev = Image.new('RGBA', (W * FRAMES + 8 * FRAMES, (H + 8) * len(rows)), (120, 110, 96, 255))
    for r, sheet in enumerate(rows):
        for f in range(FRAMES):
            prev.alpha_composite(sheet.crop((W * f, 0, W * f + W, H)), (f * (W + 8) + 4, r * (H + 8) + 4))
    prev.resize((prev.size[0] * 3, prev.size[1] * 3), Image.NEAREST).save(os.path.join(prev_dir, 'doors.png'))


if __name__ == '__main__':
    main()
