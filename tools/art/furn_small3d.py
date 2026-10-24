"""SMALL FURNITURE WITH BODY — the little pieces the volume audit found flat (owner round 48h: "no flat drawings anywhere"): a bare bulb, a fluorescent batten, a chandelier, a pile of papers,
laid places at a table, the kitchen's bin bags. Each is built from lit and shaded forms (a glass bulb with a bright core and a halo, a plastic housing with a lit rim, brass arms with
shaded candles and crystal drops, a stack of sheets with their edges, plates in perspective with a glazed well and a gilt rim, a sagging sack with a sheen) — never one colour.

Each function draws into a canvas at (ox, oy) inside the footprint its @piece declares (furn_*.py delegate here).
"""
import math
import random

import propkit as K
from pixlib import hexc, shade, mix


def _px(c, x, y, col):
    c.put(int(x), int(y), col)


def bin_bags(c, ox, oy, p):
    """Two tied black bags against the end of the counter (or one split open with the rubbish out): each a sagging lump lit by its own normals with a sheen streak, creases from the gathered neck,
    a twisted tie with two ears, ambient occlusion where the near bag sits against the far one."""
    import corridor_props3d as V
    c.shadow(ox + 15, oy + 0.6, 15.0, 1.8, 105)
    far = V.sack(c, ox + 10, oy, 17, 22, seed=3, tilt=-0.3)
    near = V.sack(c, ox + 23, oy, 15, 16, seed=7, tilt=0.4)
    V.darken_around(c, near, 0.62)
    if p['split']:
        for (x, y) in ((ox + 20, oy - 8), (ox + 21, oy - 7), (ox + 22, oy - 6), (ox + 21, oy - 9)):         # a tear down the near bag, dark inside
            c.put(x, y, hexc('06070a'))
        for (dx, dy, col) in ((-12, 0, 'd8d2c2'), (-11, 0, 'f0ece0'), (-12, -1, 'b8b2a2'), (-9, 1, 'c7b16a'), (-7, 0, '7a8a5a'), (-5, 1, 'a8483a'), (-4, 0, 'e8e2d2'), (-13, 1, '8a8272')):
            c.put(ox + 15 + dx + 4, oy + dy, hexc(col))                                                         # what spilled: wrapping, a peel, a tin, bones
        c.put(ox + 21, oy - 11, hexc('e8e2d2')); c.put(ox + 22, oy - 10, hexc('c7b16a'))                    # and a bit poking out of the tear
    c.hline(ox + 3, ox + 17, oy, hexc('06070a'))


def light_bulb(c, ox, oy, p):
    """A bare bulb on a frayed flex: a twisted braided cord (two alternating tones with a lit edge), a ceiling rose with a screw, a brass bayonet cap with ridges, a glass bulb with a
    bright core, a warm halo, a filament and a catch of light, the cord's end frayed above the cap."""
    cx = ox + 4
    for y in range(0, 13):                                                           # the braided flex: the weave swaps tone every two rows, one edge lit
        c.put(cx - 1, y, hexc('2a2622') if (y // 2) % 2 else hexc('4a4640'))
        c.put(cx, y, hexc('5a5650') if (y // 2) % 2 else hexc('2a2622'))
    for (x, col) in ((cx - 3, '8a8680'), (cx - 2, 'b8b4aa'), (cx - 1, 'f0ece0'), (cx, 'f0ece0'), (cx + 1, 'b8b4aa'), (cx + 2, '8a8680')):      # the ceiling rose: a low disc, lit in the middle
        c.put(x, 0, hexc(col))
    c.put(cx - 1, 1, hexc('6a665e')); c.put(cx, 1, hexc('6a665e'))
    c.put(cx - 1, 12, hexc('3a362f')); c.put(cx + 1, 13, hexc('3a362f'))              # frayed ends where the flex enters the cap
    for k, col in enumerate(('d8c070', 'a08a3a', 'd8c070', 'a08a3a')):               # the bayonet cap: brass with ridges
        c.rect(cx - 2, 13 + k, cx + 1, 13 + k, hexc(col))
    c.put(cx - 2, 13, hexc('f6e8a0'))
    for y in range(16, 22):                                                          # a halo of warm light round the glass (translucent) …
        for x in range(cx - 4, cx + 4):
            if abs(x - cx + 0.5) + abs(y - 19.5) * 0.6 < 4.6:
                c.put(x, y, (255, 230, 150, 40))
    K.sphere(c, cx - 0.5, 19.2, 2.7, 3.0, hexc('f6ecc8'), n=5, lo=0.78, hi=1.35)    # … the bulb itself, lit upper left
    c.put(cx - 1, 19, hexc('ffffff')); c.put(cx, 19, hexc('fff4c8')); c.put(cx - 1, 20, hexc('f2c868'))
    c.put(cx - 2, 17, hexc('ffffff'))                                                # the glass's highlight


def light_tube(c, ox, oy, p):
    """A fluorescent batten: a steel housing with a lit upper lip and a shaded lower edge, end caps with a screw each, the tube — pale at its edges, white-hot along its middle, banded
    at the ends — and a cool glow under it."""
    for x in range(ox, ox + 36):
        c.put(x, 0, hexc('d8d6cc')); c.put(x, 1, hexc('b8b4a8')); c.put(x, 2, hexc('8a877c'))
    for x in (ox, ox + 35):                                                          # the end caps: dark, the left one catching a little light
        for y in range(0, 5):
            c.put(x, y, hexc('7e7a70') if x == ox else hexc('4a463e'))
    c.put(ox + 1, 1, hexc('3a382f')); c.put(ox + 34, 1, hexc('3a382f'))              # the screws
    for x in range(ox + 6, ox + 30, 6):                                              # the clips that hold the tube in its housing: a dark tab with a lit corner
        c.put(x, 3, hexc('4a483f')); c.put(x, 5, hexc('6a675e')); c.put(x + 1, 2, hexc('e8e6dc'))
    for x in range(ox + 1, ox + 35):                                                 # the tube
        k = (x - ox) / 34.0
        end = min(k, 1 - k) < 0.07
        c.put(x, 3, hexc('c8d4d0') if not end else hexc('8a9490'))
        c.put(x, 4, hexc('ffffff') if not end else hexc('b8c4c0'))
        c.put(x, 5, hexc('e0ece8') if not end else hexc('8a9490'))
    for x in range(ox + 3, ox + 33):                                                 # the cool glow beneath
        c.put(x, 6, (210, 236, 232, 46))


def chandelier(c, ox, oy, p):
    """A gold chandelier: a chain from the ceiling, a brass stem with a bulb and a finial, two tiers of curved arms each ending in a cup with a candle (cream, lit on one side, a warm
    flame with a halo), and crystal drops of three tones hanging from the lower ring."""
    gold, gold_lt, gold_dk = hexc('c9a24e'), hexc('f0d078'), hexc('7a5e24')
    cx = ox + 14
    for y in range(0, 7):                                                            # the chain: links alternate dark and bright
        c.put(cx, y, gold_lt if y % 2 else gold_dk)
    for y in range(6, 18):                                                           # the stem: brass, lit on its left
        c.put(cx - 1, y, gold_lt); c.put(cx, y, gold); c.put(cx + 1, y, gold_dk)
    K.sphere(c, cx + 0.5, 11.5, 2.6, 2.3, gold, n=5, lo=0.55, hi=1.5)                # a bulb on the stem
    K.sphere(c, cx + 0.5, 19.5, 1.8, 1.8, gold, n=4, lo=0.6, hi=1.5)                 # the finial
    for tier, (yb, reach, ncand) in enumerate(((8, 6, 2), (13, 11, 3))):             # two tiers: each an arc of arm either side of the stem to a cup and a candle
        for sgn in (-1, 1):
            for k in range(1, reach + 1):
                ax = cx + sgn * k
                ay = yb + int(round((k * k) / (reach * 1.6)))
                c.put(ax, ay, gold_lt if sgn < 0 else gold_dk)
                c.put(ax, ay + 1, gold)
            tx = cx + sgn * reach
            ty = yb + int(round((reach * reach) / (reach * 1.6)))
            c.rect(tx - 1, ty - 1, tx + 1, ty, gold)                                  # the cup
            c.put(tx - 1, ty - 1, gold_lt)
            for yy in range(ty - 6, ty - 1):                                          # the candle: lit on its left, shaded on its right
                c.put(tx - 1 + 0, yy, hexc('f4ecd0')); c.put(tx, yy, hexc('d8ccaa'))
            for (fx, fy, col) in ((0, -8, 'ffe890'), (0, -7, 'ffc84a'), (-1, -7, 'f0a830')):
                c.put(tx + fx, ty + fy, hexc(col))                                    # the flame, with a halo
            for (hx, hy) in ((-1, -8), (1, -8), (0, -9), (0, -6)):
                c.put(tx + hx, ty + hy, (255, 220, 120, 70))
        if tier == 1:
            for k in range(-reach, reach + 1, 2):                                      # crystal drops hanging from the lower arms, each a small diamond
                dx = cx + k
                dy = yb + int(round((abs(k) ** 2) / (reach * 1.6))) + 2
                for (ox2, oy2, col) in ((0, 0, 'f4fbff'), (0, 1, 'b8e0f0'), (-1, 1, 'd8f0fa'), (1, 1, '8ab8d0'), (0, 2, '6a98b8')):
                    c.put(dx + ox2, dy + oy2, hexc(col))


def papers_pile(c, ox, oy, p):
    """A pile of papers and a manila folder: each sheet a thin slab with its own lit edge and a shaded underside, the pile a little out of true (messier when `n` is high), the top
    sheet carrying ruled lines of writing and a stamp, the folder's tab and a paperclip, a soft shadow on the desk."""
    K.contact_shadow(c, ox + 11, oy + 0.5, 11, 1.3, 90)
    rng = random.Random(p['n'])
    n = p['n']
    top_y = oy
    for k in range(n):
        dx = rng.randint(-2, 2) if n > 5 else (k % 2)
        y = oy - 1 - k // 2
        x0, x1 = ox + 3 + dx, ox + 17 + dx
        base = hexc('ece6d4') if k % 3 else hexc('d8d0b4')
        c.rect(x0, y - 1, x1, y, base)
        c.hline(x0, x1, y - 1, hexc('faf6ea'))                                       # the lit top edge
        c.hline(x0, x1, y, shade(base, 0.74))                                        # the shaded edge of the sheet below it
        c.put(x1, y - 1, shade(base, 0.82)); c.put(x1, y, shade(base, 0.62))
        top_y = y - 1
        tx0, tx1 = x0, x1
    for k, w in enumerate((10, 8, 11)):                                              # the top sheet: lines of writing
        yy = top_y
        if k < 1:
            c.hline(tx0 + 2, tx0 + 2 + w - 1, yy, hexc('5a5a60'))
    c.put(tx1 - 2, top_y, hexc('b8382a')); c.put(tx1 - 3, top_y, hexc('d8584a'))      # a stamp
    c.rect(ox + 4, oy - 5, ox + 12, oy - 3, hexc('c8a050'))                          # the folder: manila, a tab, a lit edge, a shaded foot
    c.hline(ox + 4, ox + 12, oy - 5, hexc('f0d484'))
    c.hline(ox + 4, ox + 12, oy - 3, hexc('8a6a28'))
    c.rect(ox + 5, oy - 6, ox + 7, oy - 6, hexc('e8c870'))
    c.put(ox + 6, oy - 4, hexc('8a6a28'))
    c.put(ox + 10, oy - 6, hexc('b8bcc2')); c.put(ox + 10, oy - 7, hexc('8a8e96')); c.put(ox + 11, oy - 6, hexc('6a6e76'))   # a paperclip


def place_settings(c, ox, oy, p):
    """Three places laid: each a plate seen in perspective — a glazed rim in two tones with a gilt or coloured band, a deeper well, a highlight on the rim's lit side — a knife and a fork
    either side with a bright edge and a dark one, and a folded napkin; the messy variant has food left and a toppled glass."""
    plate, rim = hexc(p['plate']), hexc(p['rim'])
    for cx in (ox + 4, ox + 15, ox + 26):
        K.ell(c, cx, oy - 1.4, 4.4, 1.9, shade(plate, 0.72))                         # the plate's shadow side (a thin lower crescent)
        K.ell(c, cx, oy - 1.7, 4.1, 1.6, shade(rim, 1.0))                            # the glazed rim band
        K.ell(c, cx, oy - 1.8, 3.4, 1.3, shade(plate, 1.06))                         # the flat of the rim
        K.ell(c, cx, oy - 1.7, 2.2, 0.9, shade(plate, 0.9))                          # the well
        c.put(int(cx) - 2, int(oy - 2.6), hexc('ffffff'))                            # a catch on the rim's lit side
        c.put(int(cx) - 3, int(oy - 2), shade(rim, 1.3))
        for dx, side in ((-6, 'k'), (6, 'f')):                                       # the knife (left) and fork (right): a bright blade / tines, a dark handle
            x = int(cx) + dx
            c.put(x, int(oy) - 3, hexc('e6eaee')); c.put(x, int(oy) - 2, hexc('b8bcc0')); c.put(x, int(oy) - 1, hexc('8a8e92'))
            if side == 'f':
                c.put(x - 1, int(oy) - 3, hexc('b8bcc0')); c.put(x + 1, int(oy) - 3, hexc('8a8e92'))
        c.put(int(cx) - 8, int(oy) - 2, hexc('e8dcc4')); c.put(int(cx) - 8, int(oy) - 1, hexc('b8a888'))     # a napkin's folded corner
        if p.get('messy'):
            c.put(int(cx) - 1, int(oy) - 2, hexc('8a3a2a')); c.put(int(cx), int(oy) - 2, hexc('c8a050')); c.put(int(cx) + 1, int(oy) - 1, hexc('5a7a3a'))
            c.put(int(cx) - 2, int(oy) - 1, hexc('a8583a'))
