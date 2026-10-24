"""WALL CLOCKS WITH DEPTH (owner: "Clocks on the wall look too flat too, very basic looking").

* clock_wall — a round wall clock built as an object: a raised bezel ring shaded like a torus (lit upper left), a recessed face that takes the bezel's shadow on its upper-left edge, ticks / numerals, hands that
  cast their own small shadow on the face, a centre cap, a curved reflection on the glass, a soft shadow on the wall behind, a nail with its cord. Variants: brass, white kitchen clock (bold numerals, a red
  second hand), black school clock.
* clock_regulator — a walnut Vienna regulator: a pediment and finial, a dial in an arched case, a glass door over a brass pendulum and two weights, a plinth.
* clock_cuckoo — a chalet clock: a shingled roof, a little door with the bird half out, a carved front, two pine-cone weights and a pendulum on chains.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import propkit as K
from furnlib import piece
from pixlib import hexc, shade, mix
from furn_wardrobes import _raised, BRASS, BRASS_LT, BRASS_DK

LIGHT = (K.LX, K.LY)


def _wall_shadow(c, cx, cy, rx, ry, a=70):
    """A soft shadow thrown on the wall behind a hung object, down and to the right."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = u * u + v * v
            if d <= 1.0:
                c.put(x, y, (0, 0, 0, int(a * (1.0 - 0.6 * d))))


CLOCKS = {
    'brass': {'rim': 'b09456', 'face': 'ece6d0', 'ink': '2a2a2a', 'num': False, 'second': False},
    'white': {'rim': 'e4e0d4', 'face': 'f4f2ea', 'ink': '1a1a1a', 'num': True, 'second': True},
    'black': {'rim': '2e2e32', 'face': 'e2dcc6', 'ink': '1a1a1a', 'num': True, 'second': False},
}


@piece('clock_wall', 18, 21, 'decor', rooms={'bedroom': 4, 'kitchen': 6, 'living_room': 4, 'dining_room': 3, 'study': 3}, styles={'adult': 3, 'kid': 2, 'sick': 3, 'teen': 1}, tags=('clock',),
       variants={k: dict(v) for k, v in CLOCKS.items()}, wall_y=(22, 40),
       note='a round wall clock with a torus-shaded bezel, a recessed face, ticks (bold quarters), hands that cast a shadow, glass with a curved reflection, a wall shadow and a nail (brass / white kitchen / black school)')
def clock_wall(c, ox, oy, p):
    rim, face, ink = hexc(p['rim']), hexc(p['face']), hexc(p['ink'])
    cx, cy, r = ox + 9.0, oy + 11.0, 8.6
    _wall_shadow(c, cx + 1.6, cy + 2.0, r, r, 78)
    c.line(int(cx), oy, int(cx), oy + 2, hexc('3a3228'))                                          # the cord up to its nail
    c.put(int(cx), oy - 1, hexc('8a8a82'))
    _disc(c, cx, cy, r, rim, face, ink, p)


def _disc(c, cx, cy, r, rim, face, ink, p):
    """The clock itself — bezel torus, recessed face, ticks, hands with shadows, centre cap, glass reflection — at any radius (the wall clock and the starburst clock share it)."""
    L = K.Layer(c)
    lc = L.c
    tn = K.tones(rim, 6, 0.48, 1.38)
    lx, ly = -0.62, -0.62
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            u, v = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
            d = math.sqrt(u * u + v * v)
            if d > 1.0:
                continue
            rad = (u / d if d else 0.0, v / d if d else 0.0)
            if d >= 0.74:                                                                           # the bezel: a rounded ring
                pr = (d - 0.74) / 0.26
                sgn = 1.0 if pr > 0.5 else -1.0
                lam = 0.5 + 0.46 * sgn * (rad[0] * lx + rad[1] * ly) / 0.88 + 0.16 * (1.0 - abs(2 * pr - 1.0))
                lc.put(x, y, K._pick(tn, max(0.0, min(0.999, lam))))
            else:                                                                                   # the face, recessed: shadowed under the bezel's upper-left rim
                col = face
                sh = max(0.0, (rad[0] * lx + rad[1] * ly)) * max(0.0, (d - 0.5) / 0.24)
                col = shade(face, 1.0 - 0.28 * sh - 0.05 * d)
                lc.put(x, y, col)
    for k in range(12):                                                                              # twelve ticks, the quarters bold (two pixels long, or a dot pair for the white kitchen clock)
        a_ = k * math.pi / 6.0
        sx, sy = math.sin(a_), -math.cos(a_)
        big = k % 3 == 0
        rr = 5.3
        lc.put(int(cx + sx * rr), int(cy + sy * rr), ink)
        if big:
            lc.put(int(cx + sx * (rr - 1)), int(cy + sy * (rr - 1)), ink)
            if p['num']:
                lc.put(int(cx + sx * (rr - 1) + (1 if sy else 0)), int(cy + sy * (rr - 1) + (1 if sx else 0)), ink)
    # hands, each with a faint shadow on the face
    for (ex, ey, wd) in ((-2, -4, 2), (4, 0, 1)):
        for k in range(1, 6):
            t = k / 5.0
            hx, hy = cx + ex * t, cy + ey * t
            lc.put(int(hx) + 1, int(hy) + 1, shade(face, 0.7))
        lc.line(int(cx), int(cy), int(cx + ex), int(cy + ey), ink)
    if p['second']:
        lc.line(int(cx + 1), int(cy + 1), int(cx + 3), int(cy + 5), hexc('d03a2a'))
    lc.put(int(cx), int(cy), BRASS_LT if p['rim'] == 'b09456' else hexc('8a8a90'))                  # the centre cap
    # the glass: a curved reflection arc and a spark
    for (gx, gy) in ((-4, -2), (-4, -3), (-3, -4), (-2, -5)):
        if lc.px[int(cx + gx), int(cy + gy)][3]:
            lc.put(int(cx + gx), int(cy + gy), mix(face, hexc('ffffff'), 0.6))
    L.flush()


# ================================================================================================================================ the starburst clock
STAR = {
    'brass': {'rim': 'b09456', 'ray': 'c9a24e', 'face': 'ece6d0', 'ink': '2a2a2a'},
    'copper': {'rim': 'a8683a', 'ray': 'c0793e', 'face': 'e8e0c8', 'ink': '2a2420'},
}


@piece('clock_sunburst', 24, 24, 'decor', rooms={}, tags=('clock',), variants={k: dict(v) for k, v in STAR.items()}, wall_y=(20, 34),
       note='a mid-century starburst clock: sixteen shaded brass spikes (long and short) round a bezelled face — baked rooms only (rooms {}): the planner never picks it')
def clock_sunburst(c, ox, oy, p):
    rim, ray, face, ink = hexc(p['rim']), hexc(p['ray']), hexc(p['face']), hexc(p['ink'])
    cx, cy = ox + 12.0, oy + 12.0
    _wall_shadow(c, cx + 1.6, cy + 2.0, 11.0, 11.0, 66)
    c.line(int(cx), oy - 1, int(cx), oy + 1, hexc('3a3228'))
    c.put(int(cx), oy - 2, hexc('8a8a82'))
    tn = K.tones(ray, 5, 0.55, 1.35)
    for k in range(16):                                                                         # sixteen spokes: a long one every 45 degrees, a short one between
        a_ = k * math.pi / 8.0
        sx, sy = math.sin(a_), -math.cos(a_)
        long_ = k % 2 == 0
        r0, r1 = 6.6, 11.0 if long_ else 9.2
        facing = -(sx * 0.7 + sy * 0.7)                                                          # a spoke pointing to the upper left is lit
        tone = K._pick(tn, max(0.0, min(0.999, 0.55 + 0.4 * facing)))
        dark = K._pick(tn, 0.12)
        pts = []
        for t in range(int(r0 * 4), int(r1 * 4) + 1):
            pts.append((int(round(cx + sx * t / 4.0 - 0.5)), int(round(cy + sy * t / 4.0 - 0.5))))
        for (x, y) in dict.fromkeys(pts):
            c.put(x + 1, y + 1, dark)                                                            # the spoke's shadow side, one pixel down-right
        for (x, y) in dict.fromkeys(pts):
            c.put(x, y, tone)
        tx, ty = pts[-1]
        if long_:                                                                                # a little ball at the tip of the long ones
            c.put(tx, ty, K._pick(tn, 0.95)); c.put(tx + 1, ty, tone); c.put(tx, ty + 1, tone); c.put(tx + 1, ty + 1, dark)
    _disc(c, cx, cy, 7.0, rim, face, ink, dict(p, num=False, second=False))


# ================================================================================================================================ the regulator
@piece('clock_regulator', 16, 36, 'decor', rooms={'living_room': 5, 'dining_room': 4, 'study': 4, 'bedroom': 2}, styles={'adult': 4, 'sick': 2}, tags=('clock',), wall_y=(16, 30), limit=1,
       note='a walnut regulator clock: a pediment with a finial, a dial in an arched case, a glass door over a brass pendulum and two weights, a plinth')
def clock_regulator(c, ox, oy, p):
    wood, wl, wd, wo = hexc('6a4430'), hexc('86583c'), hexc('4a2e20'), hexc('2a1810')
    x0, x1 = ox + 1, ox + 14
    top = oy + 4
    _wall_shadow(c, ox + 9, oy + 20, 8, 16, 55)
    c.put(ox + 8, oy, BRASS_LT); c.rect(ox + 7, oy + 1, ox + 8, oy + 3, BRASS)                         # the finial
    c.poly([(x0 - 1, top + 4), (ox + 8, top - 1), (x1 + 1, top + 4)], wl)                                # the pediment
    c.line(x0 - 1, top + 4, ox + 8, top - 1, shade(wl, 1.3)); c.line(ox + 8, top - 1, x1 + 1, top + 4, wd)
    c.rect(x0, top + 4, x1, top + 6, wl); c.hline(x0, x1, top + 4, shade(wl, 1.25)); c.hline(x0, x1, top + 6, wd)   # the cornice
    c.rect(x0, top + 7, x1, oy + 34, wood)                                                               # the case
    c.vline(x0, top + 7, oy + 34, wl); c.vline(x1, top + 7, oy + 34, wd)
    c.rect(x0 - 1, top + 7, x0 - 1, oy + 34, wo); c.rect(x1 + 1, top + 7, x1 + 1, oy + 34, wo)
    L = K.Layer(c)
    lc = L.c
    K.sphere(lc, ox + 7.5, top + 12.0, 5.2, 5.2, hexc('d8d0b8'), n=5, lo=0.7, hi=1.1)                  # the dial: pale, rimmed in brass
    for k in range(12):
        a = k * math.pi / 6.0
        lc.put(int(ox + 7.5 + math.sin(a) * 4.0), int(top + 12.0 - math.cos(a) * 4.0), hexc('2a2a2a'))
    lc.line(int(ox + 7.5), int(top + 12), int(ox + 5.5), int(top + 9), hexc('222222'))
    lc.line(int(ox + 7.5), int(top + 12), int(ox + 10), int(top + 12), hexc('222222'))
    L.flush()
    c.hline(ox + 3, ox + 12, top + 18, wd)                                                               # the waist
    _raised(c, ox + 3, top + 19, ox + 12, oy + 31, wood, wl, wd, wo)                                      # the glass door
    c.rect(ox + 4, top + 20, ox + 11, oy + 30, hexc('3a2a20'))
    c.vline(ox + 7, top + 20, top + 25, hexc('a89050'))                                                   # the pendulum rod and its brass bob
    K.sphere(c, ox + 7.5, top + 27.0, 2.6, 2.6, BRASS, gloss=True)
    for wx in (ox + 5, ox + 10):                                                                          # two hanging weights
        c.rect(wx, top + 21, wx + 1, top + 23, BRASS_DK)
    c.rect(x0 - 1, oy + 32, x1 + 1, oy + 35, wl)                                                         # the plinth
    c.hline(x0 - 1, x1 + 1, oy + 32, shade(wl, 1.25)); c.hline(x0 - 1, x1 + 1, oy + 35, wo)


# ================================================================================================================================ the cuckoo clock
@piece('clock_cuckoo', 16, 30, 'decor', rooms={'living_room': 3, 'kitchen': 4, 'dining_room': 4, 'bedroom': 1}, styles={'adult': 3, 'kid': 2, 'sick': 1}, tags=('clock',), wall_y=(16, 30), limit=1,
       note='a chalet cuckoo clock: a shingled roof, a carved front with a little door and the bird half out, two pine-cone weights and a pendulum on chains')
def clock_cuckoo(c, ox, oy, p):
    wood, wl, wd, wo = hexc('7a5434'), hexc('96683e'), hexc('54381f'), hexc('2c1c10')
    roof, roof_lt = hexc('5a3a24'), hexc('7a5232')
    _wall_shadow(c, ox + 9, oy + 14, 7.5, 13, 55)
    for k in range(8):                                                                                   # the roof: a steep pitch with courses of shingles
        half = 2 + k
        c.hline(ox + 8 - half, ox + 8 + half, oy + k, roof if k % 2 else roof_lt)
        c.put(ox + 8 - half, oy + k, shade(roof_lt, 1.2)); c.put(ox + 8 + half, oy + k, shade(roof, 0.6))
    c.hline(ox, ox + 15, oy + 8, wo)
    c.rect(ox + 2, oy + 9, ox + 13, oy + 20, wood)                                                      # the house
    c.vline(ox + 2, oy + 9, oy + 20, wl); c.vline(ox + 13, oy + 9, oy + 20, wd)
    c.rect(ox + 5, oy + 10, ox + 10, oy + 15, hexc('2e2014'))                                           # the cuckoo's door, open, with the bird
    K.sphere(c, ox + 7.5, oy + 13.0, 2.0, 2.0, hexc('c8483a'), gloss=True)
    c.put(ox + 9, oy + 12, hexc('e0b83a')); c.put(ox + 10, oy + 12, hexc('e0b83a'))
    c.hline(ox + 5, ox + 10, oy + 10, hexc('e8d8b0'))
    K.ell(c, ox + 7.5, oy + 18.0, 2.4, 2.4, hexc('d8d0b8'))                                             # the little dial below
    c.line(int(ox + 7.5), int(oy + 18), int(ox + 7.5), int(oy + 16), hexc('222222')); c.line(int(ox + 7.5), int(oy + 18), int(ox + 9), int(oy + 18), hexc('222222'))
    for (lx, ly) in ((ox + 3, oy + 11), (ox + 12, oy + 11), (ox + 3, oy + 17), (ox + 12, oy + 17)):    # carved leaves in the corners
        c.put(lx, ly, wl)
    for wx in (ox + 4, ox + 11):                                                                         # chains and pine-cone weights
        c.vline(wx, oy + 21, oy + 25, hexc('8a8a82'))
        K.sphere(c, wx + 0.5, oy + 27.0, 1.7, 2.2, hexc('8a6a3a'), gloss=False)
        c.put(wx, oy + 26, hexc('5a4020')); c.put(wx + 1, oy + 28, hexc('5a4020'))
    c.vline(ox + 8, oy + 21, oy + 26, hexc('a89050'))                                                    # the pendulum
    K.sphere(c, ox + 8.5, oy + 27.0, 1.5, 1.5, BRASS, gloss=True)
