#!/usr/bin/env python3
"""VIVIANNE'S CAT (owner round 37: "Vivianne's pixel black cat… running in the foreground and meow, and also on the standard Y plane
on some building_floor scenes… the cat never dies"). A small black cat, side-on, facing RIGHT (the game flips it), drawn at native pixel
size and shown at integer scale: 28x18 art px per frame, feet on the bottom row.

    assets/cat/cat_<anim>.png        a horizontal strip of frames:  walk (4) · run (4) · sit (2, a tail flick) · meow (2, mouth opening)
    assets/cat/cat_eyes_<anim>.png   the SAME strips with ONLY the two eye pixels (bright amber) — the game draws them UNSHADED over the
                                     body, so a black cat in an unlit night corridor is two glints
    assets/cat/cat_meta.json         frame size, frame counts, fps

A black cat has to stay READABLE on dark floors and walls: a faint cool rim light on every upward-facing edge (never a flat black blob).

    python3 tools/art/cat.py             # writes assets/cat/*
    python3 tools/art/cat.py --preview   # also /tmp/cat_preview.png (8x, on a dark floor and a pale one)
    python3 tools/art/cat.py --check     # the gate-style freshness check
"""
import json
import math
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'cat')
FW, FH = 28, 18

BODY = (17, 17, 24, 255)
DARK = (9, 9, 13, 255)
RIM = (52, 56, 76, 255)
EYE_DIM = (120, 104, 26, 255)
EYE = (240, 212, 70, 255)
MOUTH = (176, 70, 84, 255)
EARIN = (58, 32, 44, 255)


class Frame:
    def __init__(self):
        self.px = {}
        self.eyes = []

    def put(self, x, y, c=BODY):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < FW and 0 <= y < FH:
            self.px[(x, y)] = c

    def ell(self, cx, cy, rx, ry, c=BODY):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c=BODY, w=1):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            y = y0 + (y1 - y0) * i / n
            for k in range(w):
                self.put(x, y + k, c)

    def finish(self):
        """Rim light on the upward-facing edge, a darker belly line; returns (body image, eyes image)."""
        body = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
        eyes = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            if c == BODY and (x, y - 1) not in self.px:
                c = RIM
            body.putpixel((x, y), c)
        for (x, y) in self.eyes:
            body.putpixel((x, y), EYE_DIM)
            eyes.putpixel((x, y), EYE)
        return body, eyes


def head(f, hx, hy, tilt=0, open_mouth=0, ears_back=False):
    """Head at (hx, hy) = its centre, facing right: a round face, two ears, an eye, a muzzle, a mouth when open."""
    f.ell(hx, hy, 3.2, 2.7)
    f.put(hx + 3, hy + 1)                                   # muzzle
    ey = -2 if not ears_back else -1
    f.put(hx - 2, hy + ey - 1)                              # ears: two small triangles
    f.put(hx - 1, hy + ey - 1)
    f.put(hx - 2, hy + ey - 2)
    f.put(hx + 1, hy + ey - 1)
    f.put(hx + 2, hy + ey - 1)
    f.put(hx + 2, hy + ey - 2)
    f.put(hx - 1, hy + ey, EARIN) if not ears_back else None
    f.eyes.append((int(round(hx + 1.2)), int(round(hy - 0.4))))
    if open_mouth:
        f.put(hx + 2, hy + 2, MOUTH)
        f.put(hx + 3, hy + 2, MOUTH)
        if open_mouth > 1:
            f.put(hx + 2, hy + 3, MOUTH)
            f.put(hx + 3, hy + 3, DARK)


def leg(f, x, y0, y1, fx=0, c=BODY):
    """A leg down from y0 to y1 at x, the paw reaching `fx` px forward."""
    f.line(x, y0, x + fx * 0.5, y1 - 1, c, 2 if c == BODY else 1)
    f.put(x + fx, y1, c)
    f.put(x + fx + 1, y1, c)


def walk(i):
    f = Frame()
    bob = (0, -1, 0, -1)[i]
    f.ell(11, 9 + bob, 6.6, 3.2)                            # body
    head(f, 19, 7 + bob)
    f.line(17, 7 + bob, 15, 8 + bob, BODY, 2)               # neck
    # tail up behind, a curl at the tip that sways
    sway = (0, 1, 0, -1)[i]
    f.line(5, 8 + bob, 3, 6 + bob, BODY)
    f.line(3, 6 + bob, 2 + sway, 3 + bob)
    f.put(3 + sway, 2 + bob)
    f.put(4 + sway, 2 + bob)
    # legs: far pair darker; phases 0..3
    ph = [(-2, 2), (0, 0), (2, -2), (0, 0)][i]
    leg(f, 15, 11, 15, ph[0], DARK)
    leg(f, 7, 11, 15, ph[1], DARK)
    leg(f, 16, 11, 15, ph[1])
    leg(f, 6, 11, 15, ph[0])
    return f.finish()


def run(i):
    f = Frame()
    arch = (0, -1, -1, 0)[i]
    f.ell(12, 9 + arch, 7.4, 2.7)                           # a long low body
    head(f, 21, 8 + arch, ears_back=True)
    f.line(18, 8 + arch, 16, 8 + arch, BODY, 2)
    f.line(5, 8 + arch, 0, 7 + arch, BODY)                  # tail streaming straight back
    f.put(0, 6 + arch)
    # bounding gait: fore and hind legs reach out and tuck in
    reach = [(3, -3), (1, -1), (-2, 2), (1, -1)][i]
    leg(f, 18, 10, 14, reach[0], DARK)
    leg(f, 17, 10, 15, reach[0])
    leg(f, 8, 10, 14, reach[1], DARK)
    leg(f, 7, 10, 15, reach[1])
    return f.finish()


def sit(i, mouth=0):
    f = Frame()
    f.ell(12, 11, 3.6, 4.4)                                 # upright chest
    f.ell(10, 13, 4.4, 2.6)                                 # haunch
    head(f, 15, 5, open_mouth=mouth)
    f.line(13, 8, 14, 10, BODY, 2)
    leg(f, 15, 11, 15, 1)                                   # front paws together
    leg(f, 13, 11, 15, 1, DARK)
    # tail curled round the front along the ground; the tip flicks on frame 1
    f.line(6, 15, 17, 15)
    f.line(6, 14, 5, 13)
    if i == 0:
        f.put(18, 15)
        f.put(19, 14)
    else:
        f.put(18, 14)
        f.put(19, 13)
        f.put(19, 12)
    return f.finish()


ANIMS = {
    'walk': [walk(i) for i in range(4)],
    'run': [run(i) for i in range(4)],
    'sit': [sit(0), sit(1)],
    'meow': [sit(0, 1), sit(1, 2)],
}
FPS = {'walk': 8, 'run': 14, 'sit': 2, 'meow': 5}


def build():
    files = {}
    for name, frames in ANIMS.items():
        strip = Image.new('RGBA', (FW * len(frames), FH), (0, 0, 0, 0))
        estrip = Image.new('RGBA', (FW * len(frames), FH), (0, 0, 0, 0))
        for k, (b, e) in enumerate(frames):
            strip.paste(b, (FW * k, 0))
            estrip.paste(e, (FW * k, 0))
        files['cat_%s.png' % name] = strip
        files['cat_eyes_%s.png' % name] = estrip
    meta = {'frame': [FW, FH], 'frames': {k: len(v) for k, v in ANIMS.items()}, 'fps': FPS, 'feet_row': FH - 1}
    return files, meta


def write():
    os.makedirs(OUT, exist_ok=True)
    files, meta = build()
    for n, im in files.items():
        im.save(os.path.join(OUT, n))
    with open(os.path.join(OUT, 'cat_meta.json'), 'w') as f:
        json.dump(meta, f, indent=1, sort_keys=True)
        f.write('\n')
    return files


def preview(files):
    S = 8
    names = list(ANIMS)
    cols = max(len(v) for v in ANIMS.values())
    sheet = Image.new('RGBA', (FW * cols * S + 20, (FH * S + 10) * len(names) * 2), (0, 0, 0, 255))
    y = 0
    for bg in ((28, 30, 38, 255), (196, 188, 170, 255)):
        for n in names:
            strip = files['cat_%s.png' % n]
            eyes = files['cat_eyes_%s.png' % n]
            im = Image.new('RGBA', strip.size, bg)
            im.alpha_composite(strip)
            im.alpha_composite(eyes)
            sheet.paste(im.resize((im.width * S, im.height * S), Image.NEAREST), (10, y))
            y += FH * S + 10
    sheet.convert('RGB').save('/tmp/cat_preview.png')


if __name__ == '__main__':
    if '--check' in sys.argv:
        files, meta = build()
        bad = []
        for n, im in files.items():
            p = os.path.join(OUT, n)
            if not os.path.exists(p) or Image.open(p).convert('RGBA').tobytes() != im.tobytes():
                bad.append(n)
        if bad:
            print('cat art out of date:', ', '.join(bad))
            sys.exit(1)
        print('cat art current')
        sys.exit(0)
    fl = write()
    if '--preview' in sys.argv:
        preview(fl)
    print('wrote', ', '.join(sorted(fl)))
