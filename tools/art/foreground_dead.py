"""FOREGROUND DEAD silhouettes (owner round 21c — "in the foreground black shadows, like in hollow
knight and silk song… items right on the camera… this room has bodies everywhere even right up to
the camera"; a TEST look, scripts/foreground_dead.gd).

Black shapes at the world's own pixel size (1 px = 1 world px, like the room art — scaled-up sprites
went blocky), bottom-anchored: the bottom rows sit below the frame's edge. A faint rim on the upper
edges gives them form in the dark. Kinds:
  heap_1..3   the dead piled up close to the camera: bodies, a head, an arm over the top
  slumped_1..2 one of them sat slumped against something, head fallen forward, an arm hanging
  hand_1..2   a hand and forearm reaching up out of the bottom edge

Run:  python3 tools/art/foreground_dead.py   ->  assets/foreground/fg_<kind>.png + a contact sheet
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'foreground')
INK = (10, 8, 9, 255)
RIM = (38, 30, 32, 255)


SS = 4                     # drawn at 4x, then brought down: clean, organic edges at the world's pixel size


def _limb(d, x0, y0, x1, y1, w0, w1):
    a = math.atan2(y1 - y0, x1 - x0) + math.pi / 2
    ca, sa = math.cos(a), math.sin(a)
    d.polygon([(x0 + ca * w0, y0 + sa * w0), (x1 + ca * w1, y1 + sa * w1),
               (x1 - ca * w1, y1 - sa * w1), (x0 - ca * w0, y0 - sa * w0)], fill=INK)
    d.ellipse((x0 - w0, y0 - w0, x0 + w0, y0 + w0), fill=INK)                   # round joints
    d.ellipse((x1 - w1, y1 - w1, x1 + w1, y1 + w1), fill=INK)


def _blob(d, cx, cy, rx, ry):
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=INK)


def _hand(d, x, y, ang, size, rng, curl=0.0):
    # a palm and fingers along `ang`, curled by `curl` (0 open .. 1 clawed)
    _blob(d, x, y, size * 1.1, size)
    for k in range(4):
        fa = ang + (k - 1.5) * 0.28 + rng.uniform(-0.06, 0.06)
        ln = size * rng.uniform(1.5, 1.9)
        mx, my = x + math.cos(fa) * ln * 0.6, y + math.sin(fa) * ln * 0.6
        fa2 = fa + curl * 1.1
        _limb(d, x, y, mx, my, size * 0.33, size * 0.28)
        _limb(d, mx, my, mx + math.cos(fa2) * ln * 0.5, my + math.sin(fa2) * ln * 0.5, size * 0.28, size * 0.22)
    ta = ang - 1.25
    _limb(d, x, y, x + math.cos(ta) * size * 1.3, y + math.sin(ta) * size * 1.3, size * 0.4, size * 0.3)


def _torso(d, cx, cy, length, thick, s, rng):
    # a body lying on its side: hips, a waist, the ribcage and shoulders heavier, the head tipped
    _blob(d, cx - s * length * 0.3, cy, length * 0.26, thick * 0.95)                 # hips
    _blob(d, cx, cy + thick * 0.1, length * 0.3, thick * 0.8)                        # waist
    _blob(d, cx + s * length * 0.28, cy - thick * 0.15, length * 0.28, thick * 1.1)  # chest + shoulders
    hx, hy = cx + s * length * 0.56, cy - thick * 0.55
    _limb(d, cx + s * length * 0.42, cy - thick * 0.4, hx, hy, thick * 0.45, thick * 0.4)   # the neck
    _blob(d, hx + s * thick * 0.35, hy - thick * 0.1, thick * 0.78, thick * 0.72)          # the head, tipped
    return hx, hy


def _rim(img):
    px = img.load()
    w, h = img.size
    edge = [(x, y) for y in range(1, h) for x in range(w) if px[x, y][3] and not px[x, y - 1][3]]
    for (x, y) in edge:
        px[x, y] = RIM


def _finish(big):
    # 4x -> 1x, keeping a hard edge (pixel art), then the rim
    small = big.resize((big.width // SS, big.height // SS), Image.LANCZOS)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            px[x, y] = INK if px[x, y][3] > 110 else (0, 0, 0, 0)
    _rim(small)
    return small


def heap(seed, w=210, h=84):
    # the dead piled up by the camera — three or four of them, an arm hanging off the top, a leg
    rng = random.Random(seed)
    big = Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    S = SS
    base = (h - 4) * S
    d.rectangle((6 * S, base - 6 * S, (w - 6) * S, h * S), fill=INK)                  # under them, off the frame
    n = rng.randint(3, 4)
    tops = []
    for k in range(n):
        s = 1 if rng.random() < 0.5 else -1
        cx = (w * (0.22 + 0.56 * k / max(1, n - 1)) + rng.uniform(-10, 10)) * S
        cy = base - (10 + (k % 2) * rng.uniform(8, 16) + (4 if k == n // 2 else 0)) * S
        length, thick = rng.uniform(70, 92) * S, rng.uniform(11, 14) * S
        tops.append(_torso(d, cx, cy, length, thick, s, rng))
    # an arm hung over the top of the pile, the hand dangling
    hx, hy = tops[rng.randrange(len(tops))]
    sx = hx + rng.uniform(-30, 30) * S
    ex, ey = sx + rng.uniform(-12, 12) * S, hy + rng.uniform(4, 10) * S
    _limb(d, hx, hy + 8 * S, sx, hy - 6 * S, 4.2 * S, 3.6 * S)
    _limb(d, sx, hy - 6 * S, ex, ey + 12 * S, 3.6 * S, 3.0 * S)
    _hand(d, ex, ey + 16 * S, math.pi / 2 + rng.uniform(-0.3, 0.3), 3.6 * S, rng, curl=0.5)
    if rng.random() < 0.7:                                                            # a leg, bent at the knee
        lx = (w * 0.08) * S
        _limb(d, lx + 30 * S, base - 14 * S, lx + 12 * S, base - 34 * S, 6 * S, 5 * S)
        _limb(d, lx + 12 * S, base - 34 * S, lx, base - 8 * S, 5 * S, 4 * S)
        _blob(d, lx - 3 * S, base - 6 * S, 7 * S, 4.5 * S)                            # the shoe
    return _finish(big)


def slumped(seed, w=120, h=96):
    # one of them sat slumped against something off the frame, head fallen forward, an arm hanging
    rng = random.Random(seed)
    big = Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    S = SS
    s = 1 if rng.random() < 0.5 else -1
    bx = (w * 0.5 - s * 18) * S
    base = h * S
    _blob(d, bx, base - 10 * S, 30 * S, 16 * S)                                         # hips + thighs
    _limb(d, bx, base - 18 * S, bx + s * 10 * S, base - 58 * S, 17 * S, 15 * S)         # the back, leaning
    sx, sy = bx + s * 12 * S, base - 62 * S
    _blob(d, sx, sy, 17 * S, 11 * S)                                                    # shoulders
    _limb(d, sx + s * 6 * S, sy - 4 * S, sx + s * 18 * S, sy + 6 * S, 5 * S, 4.5 * S)   # the neck, bowed
    _blob(d, sx + s * 22 * S, sy + 8 * S, 9 * S, 10 * S)                                # the head, fallen forward
    ax = sx + s * 14 * S
    _limb(d, ax, sy + 2 * S, ax + s * 8 * S, base - 22 * S, 5 * S, 4 * S)               # an arm, hanging
    _hand(d, ax + s * 9 * S, base - 16 * S, math.pi / 2, 3.8 * S, rng, curl=0.7)
    _limb(d, bx + s * 20 * S, base - 14 * S, bx + s * 52 * S, base - 26 * S, 8 * S, 6 * S)   # a knee up
    _limb(d, bx + s * 52 * S, base - 26 * S, bx + s * 58 * S, base, 6 * S, 5 * S)
    return _finish(big)


def hand(seed, w=54, h=96):
    # a hand and forearm reaching up out of the bottom edge
    rng = random.Random(seed)
    big = Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    S = SS
    bx, tx = w * 0.42 * S, (w * 0.5 + rng.uniform(-6, 6)) * S
    ty = h * rng.uniform(0.22, 0.3) * S
    _limb(d, bx, h * S, tx, ty + 14 * S, 8 * S, 5.2 * S)
    _hand(d, tx, ty + 4 * S, -math.pi / 2 + rng.uniform(-0.25, 0.25), 6 * S, rng, curl=rng.uniform(0.1, 0.6))
    return _finish(big)


def main():
    os.makedirs(OUT, exist_ok=True)
    made = {}
    for i, sd in enumerate((11, 12, 13)):
        made['fg_heap_%d' % (i + 1)] = heap(sd)
    for i, sd in enumerate((21, 22)):
        made['fg_slumped_%d' % (i + 1)] = slumped(sd)
    for i, sd in enumerate((31, 32)):
        made['fg_hand_%d' % (i + 1)] = hand(sd)
    for n, im in made.items():
        im.save(os.path.join(OUT, n + '.png'))
    sheet = Image.new('RGBA', (sum(im.width + 8 for im in made.values()) + 8, 110), (120, 110, 96, 255))
    x = 8
    for im in made.values():
        sheet.alpha_composite(im, (x, 110 - im.height))
        x += im.width + 8
    prev = os.path.join(ROOT, 'docs', 'art_reference', 'foreground_dead.png')
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(prev)
    print('wrote %d foreground silhouettes' % len(made))


if __name__ == '__main__':
    main()
