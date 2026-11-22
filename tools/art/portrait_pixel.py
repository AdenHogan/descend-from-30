#!/usr/bin/env python3
"""HUD PORTRAITS — a plain, normal pixel face, MEASURED (fourth start; owner: "just make a normal looking face. Use pixels to get the measurements right").

The portrait is a 70 x 88 pixel grid shown at x4 (280 x 352, cropped to 281 x 351). Nothing is shaded by a formula and nothing is a curve: every feature is placed by the
measurements below and drawn pixel by pixel (the eyes, brows, nose and mouth are little hand-written pixel maps).

THE MEASUREMENTS (pixels; the face is centred on the column line x = 35.0, between columns 34 and 35):
    head           34 wide (x 18..51), 43 tall (y 12..54); a rounded cranium, the jaw narrowing to a 10-px chin
    eye line       y = 33   = the middle of the head (12 + 54) / 2
    eyes           7 wide, 4 tall: left x 25..31, right x 38..44   (the gap between them, 6, is about one eye width; the margin to the head edge, 7, is one eye width too)
    brows          y 28..29, 9 wide, 3 above the eyes
    nose           6 wide (x 32..37), its base y = 43 = half way from the eye line (33) to the chin (54)
    mouth          10 wide (x 30..39), y = 47..50 = a third of the way from the nose to the chin
    ears           3 wide, from the brow line to the nose base (y 29..41), x 15..17 and 52..54
    neck           16 wide (x 27..42), shoulders from y 62
Light comes from the upper left: one shade tone down the right side and under the jaw, one light tone on the left of the forehead and cheek.

    python3 tools/art/portrait_pixel.py joe /path/out.png
"""
import sys

import numpy as np
from PIL import Image

W, H = 70, 88
UP = 4
CX = 35.0                                  # the middle line (a pixel boundary)


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def tones(base, shade_to=(70, 36, 70), light_to=(255, 240, 214)):
    b = hexrgb(base)
    return dict(m=b, d=mix(tuple(int(v * 0.74) for v in b), shade_to, 0.18), dd=mix(tuple(int(v * 0.5) for v in b), (30, 16, 36), 0.45), l=mix(b, light_to, 0.30), ll=mix(b, (255, 255, 255), 0.6))


OUTLINE = (52, 32, 50)


class Grid:
    def __init__(self):
        self.px = [[None] * W for _ in range(H)]

    def set(self, x, y, col):
        if 0 <= x < W and 0 <= y < H and col is not None:
            self.px[y][x] = col

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < W and 0 <= y < H else None

    def rows(self, x0, y0, rows, legend):
        """Draw a little hand-written pixel map: one string per row, one character per pixel ('.' = leave alone)."""
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch != '.' and ch in legend:
                    self.set(x0 + dx, y0 + dy, legend[ch])

    def image(self):
        # a one-pixel outline in a dark plum round the whole figure
        solid = [[self.px[y][x] is not None for x in range(W)] for y in range(H)]
        out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        o = out.load()
        for y in range(H):
            for x in range(W):
                if solid[y][x]:
                    o[x, y] = self.px[y][x] + (255,)
        for y in range(H):
            for x in range(W):
                if not solid[y][x]:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < W and 0 <= yy < H and solid[yy][xx]:
                            o[x, y] = OUTLINE + (255,)
                            break
        big = out.resize((W * UP, H * UP), Image.NEAREST)
        canvas = Image.new('RGBA', (281, 351), (0, 0, 0, 0))
        canvas.alpha_composite(big.crop((0, 0, 281, 351)) if big.width >= 281 else big, (0, 0))
        return canvas


# the head: half-width of each row, measured from the centre line
HEAD_HW = {12: 8.5, 13: 11.5, 14: 13.5, 15: 14.8, 16: 15.8, 17: 16.4, 41: 16.2, 42: 15.6, 43: 15.0, 44: 14.2, 45: 13.4, 46: 12.5, 47: 11.6, 48: 10.7, 49: 9.8, 50: 8.9, 51: 8.0,
           52: 7.0, 53: 6.0, 54: 5.0}
for _y in range(18, 41):
    HEAD_HW[_y] = 17.0


def head_span(y):
    hw = HEAD_HW.get(y)
    if hw is None:
        return None
    xs = [x for x in range(W) if abs(x + 0.5 - CX) <= hw]
    return (xs[0], xs[-1]) if xs else None


def joe():
    g = Grid()
    skin = tones('#f0c9a6')
    hair = tones('#6a4a32')
    coat = tones('#3f8c88', light_to=(190, 245, 232))
    tee = tones('#b9bec6')
    # ---------------------------------------------------------------- the shoulders and the jumper (crew neck over a grey tee)
    for y in range(58, H):
        hw = min(35.0, 8.0 + (y - 58) * 3.6)
        for x in range(W):
            if abs(x + 0.5 - CX) <= hw:
                c = coat['m']
                if x >= 47 or y >= 82:
                    c = coat['d']
                if (x <= 14 and y <= 74) or (x <= 22 and 58 <= y <= 62):
                    c = coat['l']
                g.set(x, y, c)
    for x, y in ((14, 80), (15, 81), (16, 82), (17, 83), (52, 78), (53, 79), (54, 80)):             # a fold of the knit
        g.set(x, y, coat['d'])
    # the neck
    for y in range(50, 62):
        for x in range(27, 43):
            g.set(x, y, skin['m'] if x < 38 else skin['d'])
    # the tee and the ribbed collar
    for y in range(58, 63):
        half = 8 - (y - 58) * 1.4
        for x in range(W):
            if abs(x + 0.5 - CX) <= half:
                g.set(x, y, tee['m'] if x < 38 else tee['d'])
    for y in range(57, 64):                                                                           # the collar: a ribbed band round the neck opening
        half = 10.5 - (y - 57) * 0.6
        inner = 8 - (y - 58) * 1.4
        for x in range(W):
            d = abs(x + 0.5 - CX)
            if inner < d <= half + 1.0 and y >= 58:
                g.set(x, y, coat['dd'] if (x + y) % 2 == 0 else coat['d'])
    # ---------------------------------------------------------------- the ears
    for y in range(29, 42):
        for x in (15, 16, 17):
            g.set(x, y, skin['m'])
        for x in (52, 53, 54):
            g.set(x, y, skin['d'])
    for y in range(32, 39):
        g.set(16, y, skin['d'])
        g.set(53, y, skin['dd'])
    # ---------------------------------------------------------------- the head
    for y in range(12, 55):
        sp = head_span(y)
        if not sp:
            continue
        for x in range(sp[0], sp[1] + 1):
            c = skin['m']
            if x >= 44 and y >= 22:                                                                   # the shade down the right side of the face
                c = skin['d']
            if y >= 51 or (y >= 49 and x >= 40):                                                      # the chin and jaw underside
                c = skin['d']
            if 24 <= y <= 36 and x <= 30 and y <= 30:                                                # a light across the left of the brow
                c = skin['l']
            if 40 <= y <= 46 and 22 <= x <= 27:                                                       # a light on the left cheek
                c = skin['l']
            g.set(x, y, c)
    for x in range(27, 43):                                                                           # the shadow of the jaw on the neck
        g.set(x, 55, skin['dd'])
        g.set(x, 56, skin['d'])
    # blush
    for x, y in ((24, 42), (25, 42), (25, 43), (44, 42), (45, 42), (44, 43)):
        g.set(x, y, mix(skin['m'], (230, 130, 120), 0.45) if x < 35 else mix(skin['d'], (200, 100, 100), 0.35))
    # ---------------------------------------------------------------- the eyes (7 x 4) — a lid line, white corners, a 3-px iris, a pupil, a catch-light, a lower lid
    iris = hexrgb('#5a7f9c')
    wh = (246, 244, 240)
    pup = (20, 12, 24)
    lid = hair['dd']
    eye_l = ['.DDDDD.',
             'DWIIIWD',
             '.WIPIW.',
             '..sss..']
    eye_r = ['.DDDDD.',
             'DWIIIWD',
             '.WIPIW.',
             '..sss..']
    leg = {'D': lid, 'W': wh, 'I': iris, 'P': pup, 's': skin['d']}
    g.rows(25, 32, eye_l, leg)
    g.rows(38, 32, eye_r, leg)
    g.set(26 + 1, 33, (255, 255, 255))                                                                 # a catch-light on each iris
    g.set(39 + 1, 33, (255, 255, 255))
    # ---------------------------------------------------------------- the brows (9 x 2), a little weight and an arch
    bl = ['.BBBBBBB.',
          'BB.......']
    br = ['.BBBBBBB.',
          '.......BB']
    g.rows(24, 28, bl, {'B': hair['dd']})
    g.rows(37, 28, br, {'B': hair['dd']})
    # ---------------------------------------------------------------- the nose (6 wide, base at y = 43): a lit ridge, a shaded side, the tip, the nostrils
    for y in range(36, 42):
        g.set(34, y, skin['l'])
        g.set(36, y, skin['d'])
        g.set(37, y, skin['d'])
    g.rows(32, 41, ['.lllll', 'sllmdd', 'sdmmdn'], {'l': skin['l'], 'm': skin['m'], 'd': skin['d'], 's': skin['d'], 'n': skin['dd']})
    g.set(32, 43, skin['dd'])
    g.set(37, 43, skin['dd'])
    # ---------------------------------------------------------------- the mouth (10 wide, y 47..50): a closed, easy mouth — a dark line, an upper lip in shade, a lower lip
    lip = hexrgb('#c4766a')
    g.rows(30, 47, ['.uuuuuuuu.',
                    'LLLLLLLLLL',
                    '.lllllllL.',
                    '..lhhlll..'],
           {'u': mix(lip, (60, 24, 40), 0.30), 'L': mix(lip, (60, 24, 40), 0.55), 'l': lip, 'h': mix(lip, (255, 220, 200), 0.45)})
    g.set(29, 48, skin['dd'])
    g.set(40, 48, skin['dd'])
    # the shadow under the lip and a hint of the chin
    for x in range(32, 38):
        g.set(x, 51, skin['d'])
    # stubble: a few darker pixels along the jaw, not a smudge
    for x, y in ((24, 47), (26, 49), (28, 51), (30, 52), (33, 53), (36, 53), (39, 52), (42, 51), (44, 48), (46, 46), (25, 51), (41, 49), (21, 44), (48, 44)):
        c = g.get(x, y)
        if c is not None:
            g.set(x, y, mix(c, (70, 52, 50), 0.45))
    # ---------------------------------------------------------------- the hair: a brown mop swept to the right; written as rows of the hair's width at each y
    # (left edge, right edge) of the hair mass for each row; the forehead shows below it
    mass = {5: (29, 40), 6: (24, 45), 7: (21, 48), 8: (19, 50), 9: (18, 51), 10: (17, 52), 11: (16, 53), 12: (16, 53), 13: (16, 53), 14: (16, 53), 15: (16, 53), 16: (16, 53), 17: (16, 53), 18: (16, 53),
            19: (16, 53), 20: (16, 53), 21: (17, 52), 22: (17, 52), 23: (17, 52), 24: (17, 52), 25: (17, 52), 26: (17, 51), 27: (17, 51)}
    for (tx, ty) in ((27, 4), (28, 4), (26, 3), (33, 3), (34, 2), (35, 3), (36, 3), (41, 4), (42, 5), (43, 5), (46, 6), (47, 6), (23, 6), (22, 6), (21, 7), (50, 7), (51, 8)):
        g.set(tx, ty, hair['m'])
    for (tx, ty) in ((34, 3), (35, 4), (36, 4)):
        g.set(tx, ty, hair['l'])
    for y, (a, b) in mass.items():
        for x in range(a, b + 1):
            c = hair['m']
            if x >= 46 or (y >= 22 and x >= 40):
                c = hair['d']
            if y <= 10 and x <= 36:
                c = hair['l']
            g.set(x, y, c)
    # the forehead: skin shows below the fringe, which is swept right (it comes lower on the right)
    fringe_low = {x: (23 if x < 26 else 24 if x < 30 else 25 if x < 34 else 26 if x < 38 else 27 if x < 42 else 28 if x < 46 else 29) for x in range(18, 52)}
    for x in range(18, 52):
        sp = head_span(23)
        for y in range(19, fringe_low[x] + 1):
            c = skin['m'] if x < 44 else skin['d']
            g.set(x, y, hair['m'] if y < fringe_low[x] - 1 else hair['d'])
    # the sideburns and the hair over the top of the ears
    for y in range(28, 34):
        for x in (18, 19, 50, 51):
            g.set(x, y, hair['d'] if x > 40 else hair['m'])
    for y in range(24, 34):
        for x in (15, 16, 17, 52, 53, 54):
            g.set(x, y, hair['m'] if x < 40 else hair['d'])
    # locks and shine: diagonal strokes of the light and dark following the sweep to the right
    for k in range(7):
        x0, y0 = 22 + k * 4, 7 + (k % 3)
        for t in range(6):
            g.set(x0 + t, y0 + t // 2 + 1, hair['l'])
    for k in range(6):
        x0, y0 = 20 + k * 5, 14 + (k % 2) * 2
        for t in range(6):
            g.set(x0 + t, y0 + t // 2, hair['dd'] if (k + t) % 3 else hair['d'])
    for k in range(4):
        x0, y0 = 22 + k * 7, 21
        for t in range(5):
            g.set(x0 + t, y0 + t // 2, hair['l'] if k % 2 == 0 else hair['d'])
    return g


if __name__ == '__main__':
    who = sys.argv[1] if len(sys.argv) > 1 else 'joe'
    out = sys.argv[2] if len(sys.argv) > 2 else '/tmp/portrait_pixel.png'
    img = globals()[who]().image()
    bg = Image.new('RGBA', img.size, (58, 58, 68, 255))
    bg.alpha_composite(img)
    bg.save(out)
    print('wrote', out)
