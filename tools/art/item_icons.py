"""INVENTORY ICONS — every item's icon, drawn as pixel art (replaces the white word cards + red boxes).

56x56, drawn 1:1 for the HUD slot (the loot panel shows them 2x). One light (top left), one outline
rule, readable at a glance on the grey slot — the shape first, the colour second, detail last: a
player should know a bat from a golf club without reading anything (hovering a slot gives the name
and the details).

Run:  python3 tools/art/item_icons.py          writes assets/Items/<file> for every icon + the sheets
      python3 tools/art/item_icons.py 004 016  just those (and the sheets)
The file names are the existing ones (bare "<id>.png", or "<id> - Name.png" where the item had one),
so ItemData's loader and every .import keep working.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from iconlib import Axis, Icon, S, mix, rgb, scale  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ITEMS = os.path.join(ROOT, 'assets', 'Items')

# ---- palette ---------------------------------------------------------------------------------------
STEEL = rgb('9aa3ad')
STEEL_LT = rgb('d6dde3')
STEEL_DK = rgb('5b636c')
GUNMETAL = rgb('464c55')
BLACK = rgb('2a2a2e')
RUBBER = rgb('34343a')
WOOD = rgb('a8703f')
WOOD_LT = rgb('cf9a5c')
WOOD_DK = rgb('6e4424')
WILLOW = rgb('e3cf9c')
BRASS = rgb('d3a24a')
COPPER = rgb('c47a45')
RED = rgb('c23b32')
RED_DK = rgb('8e2721')
WHITE = rgb('eeeae2')
CREAM = rgb('e6dcc3')
LEATHER = rgb('6d4630')
GREEN = rgb('4f8a4a')
BLUE = rgb('4f7fb8')
ORANGE = rgb('e0852f')
YELLOW = rgb('efc84a')


def curved_band(ax, t0, t1, w0, w1, bow, n=24):
    """A band along an axis that bellies sideways by `bow` at its middle (a sabre's sori)."""
    left, right = [], []
    for i in range(n + 1):
        f = i / n
        t = t0 + (t1 - t0) * f
        w = w0 + (w1 - w0) * f
        o = -bow * math.sin(math.pi * f)
        left.append(ax.at(t, o - w))
        right.append(ax.at(t, o + w))
    return left + right[::-1]


# ---- the icons --------------------------------------------------------------------------------------
def knife():
    ic = Icon()
    ax = Axis((6, 50), 45)
    ic.part(ic.poly(ax.band(0, 20, 3.8, 4.1)), rgb('3b2a22'), 'cyl', ax.dir, hl=0.25)      # handle scales
    ic.part(ic.poly(ax.band(-1.5, 0.5, 3.4, 3.8)), STEEL_DK, 'cyl', ax.dir)
    for t in (4.5, 10, 15.5):
        x, y = ax.at(t, 0)
        ic.paint(ic.ellipse((x - 1, y - 1, x + 1, y + 1)), STEEL_LT)
    ic.part(ic.poly(ax.band(20, 23, 4.9, 4.9)), STEEL, 'cyl', ax.dir, hl=0.3)            # bolster
    blade = ax.pts([(23, -3.6), (50, -3.6), (57, -1.8), (53, 1.8), (44, 4.0), (23, 4.5)])
    ic.part(ic.poly(blade), STEEL, 'cyl', ax.dir, hl=0.2)
    edge = ax.pts([(23, 2.4), (44, 2.0), (53, 0.2), (57, -1.8), (53, 1.8), (44, 4.0), (23, 4.5)])
    ic.part(ic.poly(edge), STEEL_LT, 'flat', contact=False)                               # honed edge
    return ic.finish()


def hammer():
    ic = Icon()
    ax = Axis((8, 52), 45)
    ic.part(ic.poly(ax.band(0, 40, 3.2, 2.6)), WOOD, 'cyl', ax.dir, hl=0.25)             # handle
    ic.part(ic.poly(ax.band(-1, 12, 3.7, 3.4)), rgb('2f2f33'), 'cyl', ax.dir, hl=0.15)   # rubber grip
    for t in (2.5, 5.5, 8.5):
        ic.paint(ic.line([ax.at(t, -3.3), ax.at(t, 3.3)], 1), rgb('1c1c20'))
    across = (ax.v[0], ax.v[1])
    # the claw: from the head down-right, curving back toward the handle, split down the middle
    cl = []
    for o, tc, w in ((3, 39.5, 3.4), (7, 39, 3.0), (10, 37.5, 2.5), (12.5, 35.5, 1.9), (14.5, 33, 1.2)):
        cl.append((o, tc, w))
    claw = [ax.at(tc + w, o) for o, tc, w in cl] + [ax.at(cl[-1][1] - 0.5, 15.5)] + \
           [ax.at(tc - w, o) for o, tc, w in reversed(cl)]
    ic.part(ic.poly(claw), STEEL_DK, 'cyl', ax.dir, hl=0.2)
    ic.paint(ic.line([ax.at(38.5, 6), ax.at(34.5, 13.5)], 1), rgb('202327'))
    ic.part(ic.poly(ax.band(34.5, 43.5, 4.2, 4.2, o0=-1)), STEEL_DK, 'cyl', across, hl=0.25)   # eye
    ic.part(ic.poly([ax.at(35.5, -4), ax.at(42.5, -4), ax.at(42.5, -10), ax.at(35.5, -10)]),
            STEEL, 'cyl', across, hl=0.3)                                                   # neck
    ic.part(ic.poly([ax.at(34.5, -10), ax.at(43.5, -10), ax.at(43.5, -13.5), ax.at(34.5, -13.5)]),
            STEEL_LT, 'cyl', across, hl=0.3)                                                # striking face
    return ic.finish()


def gun():
    """A side-on service pistol in dark steel and black polymer: long slide, slim frame, raked grip."""
    ic = Icon()
    slide_c, frame_c, grip_c = rgb('3b4048'), rgb('2b2e34'), rgb('25272c')
    grip = [(11, 21), (20, 21), (21, 25), (16, 42), (6, 42), (8, 33)]
    ic.part(ic.poly(grip), grip_c, 'h', strength=0.22, light=1.3)
    for y in range(26, 41, 3):                                                              # stippled grip
        for x in range(8 + (y % 2), 18, 3):
            if ic.a[y, x] > 0.5:
                ic.px(x, y, rgb('15161a'))
    ic.part(ic.rect((5, 41, 17, 44)), rgb('1c1d21'), 'flat')                                # magazine base
    ic.part(ic.poly([(9, 21), (42, 21), (42, 25), (37, 26), (24, 26), (9, 25)]), frame_c, 'v', strength=0.2)   # frame
    ic.part(ic.arc((23, 21, 36, 31), 0, 180, w=2), frame_c, 'flat')                        # trigger guard
    ic.part(ic.poly([(26, 25), (28, 25), (29, 28), (27, 28)]), rgb('111215'), 'flat')      # trigger
    ic.part(ic.poly([(6, 13), (48, 13), (52, 15), (52, 21), (6, 21)]), slide_c, 'v', strength=0.38, light=1.35)   # slide
    for x in range(8, 14, 2):
        ic.paint(ic.line([(x, 14), (x, 20)], 1), rgb('22252a'))                            # serrations
    for x in range(40, 46, 2):
        ic.paint(ic.line([(x, 14), (x, 20)], 1), rgb('22252a'))
    ic.paint(ic.rect((24, 15, 33, 18)), rgb('17191d'))                                      # ejection port
    ic.paint(ic.line([(14, 14), (46, 14)], 1), rgb('6e7580'))                               # top edge highlight
    ic.paint(ic.rect((51, 16, 52, 18)), rgb('0d0e10'))                                      # muzzle
    ic.part(ic.rect((45, 11, 47, 13)), slide_c, 'flat')                                     # front sight
    ic.part(ic.rect((7, 11, 10, 13)), slide_c, 'flat')                                      # rear sight
    return ic.finish(shadow=(28, 46, 20, 2))


def canned_food():
    ic = Icon()
    body = ic.rect((13, 15, 43, 47))
    ic.part(body, rgb('b9c0c6'), 'cyl', (0, 1), hl=0.3)
    ic.part(ic.ellipse((13, 43, 43, 51)), rgb('9aa1a8'), 'flat', rim=False, contact=False)  # base
    ic.part(ic.rect((13, 15, 43, 47)), rgb('b9c0c6'), 'cyl', (0, 1), hl=0.3, contact=False)
    label = ic.rect((13, 20, 43, 42))
    ic.part(label, rgb('c63a2c'), 'cyl', (0, 1), hl=0.2)
    ic.part(ic.rect((13, 26, 43, 36)), CREAM, 'cyl', (0, 1), hl=0.15)                      # label band
    for (x, y) in ((20, 30), (24, 32), (28, 30), (32, 32), (36, 30), (22, 34), (30, 34), (26, 29)):
        ic.paint(ic.ellipse((x - 1.5, y - 1, x + 1.5, y + 1)), rgb('b8642e'))              # beans
    for y in (22, 40):
        ic.paint(ic.line([(15, y), (41, y)], 1), rgb('e7b04a'))
    ic.part(ic.ellipse((13, 11, 43, 19)), rgb('cfd5da'), 'flat', contact=False)            # lid
    ic.part(ic.ellipse((16, 12.5, 40, 17.5)), rgb('a7aeb5'), 'flat', rim=False, contact=False)
    ic.paint(ic.arc((18, 13, 38, 17), 200, 330, 1), rgb('e9edf0'))
    for y in (17, 44):
        ic.darken(ic.line([(13, y), (43, y)], 1), 0.82)
    return ic.finish(shadow=(28, 50, 17, 3))


def first_aid():
    """A white medical case with a big red cross (the toolbox is the red one)."""
    ic = Icon()
    ic.part(ic.arc((19, 7, 37, 24), 180, 360, w=3), rgb('3a3a40'), 'flat')                  # carry handle
    ic.part(ic.rect((7, 17, 49, 46), r=4), rgb('f1ede4'), 'v', strength=0.22, light=1.05)
    ic.part(ic.rect((7, 17, 49, 23), r=3), rgb('fbf8f1'), 'flat', contact=False, light=1.0)   # lid
    ic.paint(ic.line([(8, 24), (48, 24)], 1), rgb('b9b3a4'))                                # lid seam
    for x in (13, 43):
        ic.part(ic.rect((x - 2, 22, x + 2, 27)), STEEL, 'v')                                # clasps
    ic.part(ic.rect((25, 27, 31, 44)), RED, 'flat', light=1.12)
    ic.part(ic.rect((19, 32, 37, 39)), RED, 'flat', light=1.12, contact=False)
    return ic.finish(shadow=(28, 48, 22, 3))


def _bat(ic, ax, wood, grip, knob=True, hl=0.35):
    L = 55.0 / 46.0
    prof = [(t * L, w) for t, w in ((0, 1.9), (10, 1.9), (18, 2.3), (26, 3.3), (34, 4.6), (42, 5.2), (46, 4.8))]
    top = [ax.at(t, -w) for t, w in prof]
    bot = [ax.at(t, w) for t, w in reversed(prof)]
    ic.part(ic.poly(top + bot), wood, 'cyl', ax.dir, hl=hl)
    x, y = ax.at(46 * L, 0)
    ic.part(ic.ellipse((x - 4.4, y - 4.4, x + 4.4, y + 4.4)), wood, 'dome', hl=0.2, contact=False)
    if grip:
        ic.part(ic.poly(ax.band(0, 11, 2.3, 2.3)), grip, 'cyl', ax.dir, hl=0.12)
        for t in (2, 4.5, 7, 9.5):
            ic.darken(ic.line([ax.at(t, -2.3), ax.at(t + 1.5, 2.3)], 1), 0.7)
    if knob:
        x, y = ax.at(-1.2, 0)
        ic.part(ic.ellipse((x - 3.3, y - 3.3, x + 3.3, y + 3.3)), grip or wood, 'dome')


def baseball_bat():
    ic = Icon()
    ax = Axis((7, 49), 45)
    _bat(ic, ax, rgb('c58b4f'), rgb('2e2e33'))
    return ic.finish()


def bullets():
    ic = Icon()
    for cx, base, h in ((17, 46, 26), (39, 46, 26), (28, 49, 28)):
        top = base - h
        ic.part(ic.rect((cx - 5, top + 9, cx + 5, base)), BRASS, 'cyl', (0, 1), hl=0.35)
        ic.part(ic.rect((cx - 6, base - 3, cx + 6, base)), rgb('b58534'), 'cyl', (0, 1), hl=0.2)
        ic.darken(ic.line([(cx - 5, base - 4), (cx + 5, base - 4)], 1), 0.7)                # extractor groove
        tip = [(cx - 4.5, top + 10), (cx - 4.5, top + 6), (cx - 2.5, top + 1), (cx, top),
               (cx + 2.5, top + 1), (cx + 4.5, top + 6), (cx + 4.5, top + 10)]
        ic.part(ic.poly(tip), COPPER, 'cyl', (0, 1), hl=0.35)
    return ic.finish(shadow=(28, 50, 20, 2.5))


def extinguisher():
    ic = Icon()
    ic.part(ic.line([(34, 13), (43, 14), (47, 22), (46, 34), (44, 40)], 3), RUBBER, 'flat')  # hose
    ic.part(ic.poly([(42, 39), (47, 39), (46, 45), (43, 45)]), BLACK, 'flat')               # nozzle
    ic.part(ic.rect((16, 16, 38, 49), r=6), RED, 'cyl', (0, 1), hl=0.35)                    # cylinder
    ic.part(ic.ellipse((16, 12, 38, 24)), RED, 'dome', hl=0.25, contact=False)
    ic.part(ic.rect((16, 18, 38, 49), r=5), RED, 'cyl', (0, 1), hl=0.35, contact=False)
    ic.part(ic.rect((16, 30, 38, 39)), WHITE, 'cyl', (0, 1), hl=0.1)                         # label
    ic.paint(ic.line([(20, 33), (33, 33)], 1), RED_DK)
    ic.paint(ic.line([(20, 36), (29, 36)], 1), rgb('9a9a9a'))
    ic.part(ic.rect((23, 7, 31, 14)), rgb('3b3b40'), 'v')                                   # valve
    ic.part(ic.poly([(21, 6), (34, 3), (35, 5), (22, 9)]), STEEL, 'flat')                    # lever
    ic.part(ic.poly([(20, 10), (31, 9), (31, 11), (21, 12)]), STEEL_DK, 'flat')
    ic.part(ic.ellipse((30, 6, 37, 13)), WHITE, 'flat')                                      # gauge
    ic.paint(ic.arc((31, 7, 36, 12), 200, 300, 1), rgb('3aa04a'))
    ic.px(33, 9, BLACK)
    return ic.finish(shadow=(27, 50, 14, 2.5))


def sword():
    """A katana: slim, gently curved single-edged blade with a hamon, round tsuba, wrapped handle."""
    ic = Icon()
    ax = Axis((4, 52), 45)
    ic.part(ic.poly(ax.band(0, 2.2, 2.4, 2.4)), rgb('c9a24a'), 'cyl', ax.dir, hl=0.3)    # kashira (pommel cap)
    ic.part(ic.poly(ax.band(2.2, 17, 2.3, 2.3)), rgb('241d21'), 'cyl', ax.dir, hl=0.12)   # tsuka (handle)
    for t in [3.4 + 2.6 * i for i in range(5)]:                                           # diamond wrap
        ic.paint(ic.line([ax.at(t, -2.1), ax.at(t + 1.3, 0), ax.at(t, 2.1)], 1), rgb('7e2730'))
        ic.paint(ic.line([ax.at(t + 1.3, -2.1), ax.at(t, 0), ax.at(t + 1.3, 2.1)], 1), rgb('7e2730'))
    ic.part(ic.poly(ax.band(17, 18.8, 5.8, 5.8)), rgb('3a3136'), 'cyl', ax.dir, hl=0.2)    # tsuba (round guard)
    ic.paint(ic.poly(ax.band(17.2, 18.6, 5.4, 5.4)), rgb('c9a24a'), a=0.45)
    ic.part(ic.poly(ax.band(18.8, 21.3, 2.6, 2.6)), rgb('d8b456'), 'cyl', ax.dir, hl=0.3)  # habaki (collar)
    blade = curved_band(ax, 21.3, 66, 2.3, 1.0, 1.7)
    ic.part(ic.poly(blade), rgb('b4bdc6'), 'cyl', ax.dir, hl=0.3)                          # the blade
    edge = curved_band(ax, 22, 64, 0.55, 0.15, 1.7)
    ic.paint(ic.poly([(px + ax.v[0] * 1.5, py + ax.v[1] * 1.5) for (px, py) in edge]), rgb('f2f6f9'), a=0.9)   # hamon / edge
    back = curved_band(ax, 22, 62, 0.4, 0.15, 1.7)
    ic.paint(ic.poly([(px - ax.v[0] * 1.7, py - ax.v[1] * 1.7) for (px, py) in back]), rgb('7c858f'), a=0.9)   # the back
    return ic.finish(shadow=None)


def bandages():
    """A roll of gauze standing on end, seen from above and in front: a spiral top, wrapped sides, a paper label and a loose tail."""
    ic = Icon()
    gauze, wrap = rgb('efe5d0'), rgb('d6c9ad')
    tail = [(31, 40), (44, 41), (52, 44), (54, 48), (45, 49), (31, 46)]
    ic.part(ic.poly(tail), rgb('f4ecda'), 'v', strength=0.2)                               # the loose tail on the floor
    for x in (38, 44, 49):
        ic.paint(ic.line([(x, 42), (x + 1, 47)], 1), wrap)
    body = ic.poly([(9, 38), (9, 20), (39, 20), (39, 38)]) | ic.ellipse((9, 32, 39, 44))
    ic.part(body, gauze, 'cyl', (0, 1), hl=0.2)                                            # the wound sides
    for y in (25, 30, 35, 40):
        ic.paint(ic.arc((9, y - 3, 39, y + 4), 10, 170, 1), wrap)                          # wraps
    ic.part(ic.rect((18, 26, 30, 38)), rgb('fbf8f1'), 'flat', light=1.02)                  # the paper label
    ic.part(ic.rect((22, 28, 26, 37)), RED, 'flat', light=1.12, contact=False)
    ic.part(ic.rect((19, 31, 29, 34)), RED, 'flat', light=1.12, contact=False)
    ic.part(ic.ellipse((9, 14, 39, 26)), rgb('f7efdd'), 'flat', contact=False)             # the top face
    for r in (1.0, 0.72, 0.46):
        ic.paint(ic.ellipse((24 - 14.5 * r, 20 - 5.6 * r, 24 + 14.5 * r, 20 + 5.6 * r)) & ~ic.ellipse(
            (24 - 14.5 * r + 1, 20 - 5.6 * r + 1, 24 + 14.5 * r - 1, 20 + 5.6 * r - 1)), wrap)
    ic.paint(ic.ellipse((20, 18, 28, 22)), rgb('7d6c52'))                                   # the hollow core
    return ic.finish(shadow=(30, 46, 24, 3))


def clothes():
    ic = Icon()
    # folded jeans under a folded shirt
    ic.part(ic.rect((8, 33, 48, 46), r=2), rgb('3d5f8f'), 'v', strength=0.3)
    ic.paint(ic.line([(9, 39), (47, 39)], 1), rgb('2e4a70'))
    ic.paint(ic.line([(9, 43), (47, 43)], 1), rgb('e0a84b'))                              # stitching
    ic.part(ic.rect((10, 14, 46, 35), r=2), rgb('c8453c'), 'v', strength=0.3)             # shirt
    for x in range(13, 46, 5):
        ic.paint(ic.line([(x, 15), (x, 34)], 1), rgb('a43530'))                           # plaid
    for y in (19, 25, 31):
        ic.paint(ic.line([(11, y), (45, y)], 1), rgb('a43530'))
    ic.part(ic.poly([(21, 14), (28, 22), (35, 14)]), rgb('f0e7d6'), 'flat')               # collar
    ic.part(ic.poly([(21, 14), (26, 21), (21, 21)]), rgb('d45248'), 'flat')
    ic.part(ic.poly([(35, 14), (30, 21), (35, 21)]), rgb('d45248'), 'flat')
    ic.paint(ic.line([(28, 22), (28, 34)], 1), rgb('8f2d28'))                             # placket
    for y in (25, 30):
        ic.paint(ic.rect((27, y, 29, y + 1)), rgb('f2eee4'))
    return ic.finish(shadow=(28, 48, 22, 3))


def torn_clothes():
    """A faded grey-blue tee, ripped and frayed, with deep folds and a torn hem."""
    ic = Icon()
    base = rgb('6d8196')
    tee = [(17, 9), (23, 12), (33, 12), (39, 9), (51, 17), (46, 26), (41, 22), (41, 46), (38, 49), (35, 45), (31, 50),
           (27, 46), (23, 50), (20, 45), (16, 49), (15, 46), (15, 22), (10, 26), (5, 17)]
    ic.part(ic.poly(tee), base, 'v', strength=0.3, light=1.25)
    ic.part(ic.poly([(6, 17), (17, 9), (23, 12), (15, 22), (10, 26)]), rgb('5d7085'), 'h', strength=0.3)   # the sleeves, a shade apart
    ic.part(ic.poly([(50, 17), (39, 9), (33, 12), (41, 22), (46, 26)]), rgb('5d7085'), 'h', strength=0.3)
    ic.part(ic.poly([(23, 12), (28, 19), (33, 12), (31, 10), (28, 14), (25, 10)]), rgb('3c4d5f'), 'flat')  # neckband
    for pts in ([(17, 16), (22, 30), (19, 46), (25, 46), (27, 30), (23, 16)],                             # deep folds
                [(34, 15), (31, 32), (34, 46), (39, 46), (38, 31), (40, 17)]):
        ic.paint(ic.poly(pts), rgb('3f5165'), a=0.5)
    for pts in ([(26, 16), (27, 31), (29, 31), (29, 16)], [(41, 24), (41, 44), (40, 44), (40, 24)]):
        ic.paint(ic.poly(pts), rgb('a3b6c8'), a=0.55)                                                     # lit ridges
    ic.paint(ic.line([(16, 41), (40, 41)], 1), rgb('a3b6c8'), a=0.7)                                        # hem stitching
    ic.cut(ic.poly([(19, 21), (26, 24), (24, 28), (27, 32), (20, 31), (22, 27)]))                          # a big rip at the chest
    for (x, y) in ((18, 22), (27, 25), (25, 33), (19, 32), (22, 20), (28, 31)):
        ic.px(x, y, rgb('c6d4e2'))                                                                          # frayed threads
    ic.cut(ic.poly([(33, 36), (39, 34), (38, 41)]))
    ic.cut(ic.poly([(44, 21), (47, 19), (47, 25)]))                                                       # a torn sleeve
    for x in (17, 24, 28, 32, 36):
        ic.px(x, 48, rgb('c6d4e2'))                                                                        # fringe on the hem
    return ic.finish(shadow=(28, 50, 21, 2.5))


def painkillers():
    ic = Icon()
    ic.part(ic.rect((15, 16, 37, 48), r=3), rgb('d97a2b'), 'cyl', (0, 1), hl=0.45, alpha=0.95)  # bottle
    ic.part(ic.rect((15, 25, 37, 41)), WHITE, 'cyl', (0, 1), hl=0.1)                      # label
    ic.part(ic.rect((22, 28, 30, 38)), RED, 'flat', rim=False, contact=False)
    ic.paint(ic.rect((25, 29, 27, 37)), WHITE)
    ic.paint(ic.rect((23, 32, 29, 34)), WHITE)
    ic.part(ic.rect((13, 8, 39, 17), r=2), WHITE, 'cyl', (0, 1), hl=0.15)                 # cap
    for x in range(15, 38, 3):
        ic.darken(ic.line([(x, 9), (x, 16)], 1), 0.82)
    for (x0, y0) in ((39, 41), (43, 45)):                                                 # loose pills
        ic.part(ic.ellipse((x0, y0, x0 + 8, y0 + 5)), rgb('f3f0e8'), 'dome', hl=0.2)
        ic.paint(ic.line([(x0 + 4, y0 + 1), (x0 + 4, y0 + 4)], 1), rgb('c9c3b5'))
    return ic.finish(shadow=(30, 50, 20, 2.5))


def ice_pack():
    """A reusable gel cold pack: a soft blue pouch sealed round its edge, pinched into two lobes, with a snowflake label."""
    ic = Icon()
    ic.part(ic.rect((5, 13, 51, 45), r=7), rgb('3b82c4'), 'v', strength=0.25)               # the sealed outer edge
    for (x0, x1) in ((8, 27), (29, 48)):
        ic.part(ic.rect((x0, 16, x1, 42), r=6), rgb('67bdea'), 'dome', hl=0.55, light=1.3)   # each gel lobe
    ic.paint(ic.line([(28, 15), (28, 43)], 2), rgb('2d6cae'))                               # the pinch between them
    for y in range(17, 42, 4):
        ic.px(28, y, rgb('a9dcf5'))
    for x in range(7, 50, 3):                                                               # the crimped rim
        ic.px(x, 14, rgb('9fd2f2'))
        ic.px(x, 44, rgb('25609f'))
    ic.part(ic.rect((14, 25, 42, 34), r=2), rgb('f4fbff'), 'flat', light=1.0, contact=False)  # the label
    cx, cy = 28, 29.5
    for a in range(0, 180, 60):
        dx, dy = 3.6 * math.cos(math.radians(a)), 3.6 * math.sin(math.radians(a))
        ic.paint(ic.line([(cx - dx, cy - dy), (cx + dx, cy + dy)], 1), rgb('3b82c4'))
    ic.paint(ic.line([(17, 28), (22, 28)], 1), rgb('9bc3e0'))
    ic.paint(ic.line([(17, 31), (23, 31)], 1), rgb('9bc3e0'))
    ic.paint(ic.line([(34, 28), (39, 28)], 1), rgb('9bc3e0'))
    ic.paint(ic.line([(34, 31), (38, 31)], 1), rgb('9bc3e0'))
    for (x, y) in ((12, 19), (43, 20), (40, 39)):
        ic.px(x, y, rgb('eaf7ff'))                                                           # the glossy glints
        ic.px(x + 1, y, rgb('cfeeff'))
    return ic.finish(shadow=(28, 48, 22, 2.5))


def golf_club():
    """An iron: grip, shaft and a grooved blade — the whole club sits in the cell (no ball)."""
    ic = Icon()
    ax = Axis((47, 6), -128)                                                              # grip at the top right
    ic.part(ic.poly(ax.band(0, 10, 2.5, 2.0)), rgb('2b2b30'), 'cyl', ax.dir, hl=0.15)     # grip
    for t in (2, 4.2, 6.4, 8.6):
        ic.darken(ic.line([ax.at(t, -2.4), ax.at(t + 1.0, 2.4)], 1), 0.7)
    ic.part(ic.poly(ax.band(10, 31, 1.2, 1.0)), STEEL_LT, 'cyl', ax.dir, hl=0.3)          # shaft
    hx, hy = ax.at(31, 0)
    k = 1.15
    head = [(hx + 2 * k, hy - 3 * k), (hx + 3 * k, hy + 6 * k), (hx - 2 * k, hy + 9 * k), (hx - 17 * k, hy + 9 * k),
            (hx - 19 * k, hy + 5 * k), (hx - 15 * k, hy + 1 * k), (hx - 4 * k, hy)]
    ic.part(ic.poly(head), STEEL, 'v', strength=0.35, light=1.35)                         # the iron blade
    for j in range(4):
        ic.paint(ic.line([(hx - 15 * k, hy + (3 + j * 1.6) * k), (hx - 3 * k, hy + (3 + j * 1.6) * k)], 1), rgb('6b737c'))   # grooves
    return ic.finish(shadow=(24, 50, 16, 2))


def cricket_bat():
    ic = Icon()
    ax = Axis((7, 49), 45)
    ic.part(ic.poly(ax.band(0, 17, 1.9, 1.9)), rgb('3f7a3a'), 'cyl', ax.dir, hl=0.2)      # rubber grip
    for t in (2, 5, 8, 11, 14):
        ic.darken(ic.line([ax.at(t, -1.9), ax.at(t + 1.3, 1.9)], 1), 0.7)
    x, y = ax.at(-0.8, 0)
    ic.part(ic.ellipse((x - 2, y - 2, x + 2, y + 2)), rgb('2f5c2b'), 'dome')
    ic.part(ic.poly(ax.band(17, 20, 1.9, 1.9)), WILLOW, 'flat')                           # splice
    blade = ax.pts([(20, -2), (24, -7.5), (57, -7.5), (59, -6), (59, 6), (57, 7.5), (24, 7.5), (20, 2)])
    ic.part(ic.poly(blade), WILLOW, 'cyl', ax.dir, hl=0.15, strength=0.2)                 # the flat blade
    ic.part(ic.poly(ax.pts([(24, 4.5), (58, 4.5), (59, 6), (57, 7.5), (24, 7.5)])), rgb('c7ab74'), 'flat',
            contact=False)                                                                # its edge
    ic.paint(ic.line([ax.at(26, -1), ax.at(56, -1)], 1), rgb('f3e6c1'))                   # the spine
    ic.paint(ic.poly(ax.band(27, 33, 2.5, 2.5, o0=-3.5)), rgb('2c4f8c'))                  # maker's sticker
    ic.px(*ax.at(30, -3.5), rgb('e8d27a'))
    return ic.finish()


def flashlight():
    ic = Icon()
    ax = Axis((6, 50), 45)
    ic.part(ic.poly(ax.band(0, 30, 5.0, 5.0)), rgb('2f3338'), 'cyl', ax.dir, hl=0.35)     # body
    for t in (4, 7, 10, 13):
        ic.darken(ic.line([ax.at(t, -5), ax.at(t, 5)], 1), 0.7)                           # knurling
    ic.part(ic.poly(ax.band(19, 25, 2.0, 2.0, o0=-4.6)), rgb('d8d8d8'), 'flat')          # switch
    ic.part(ic.poly(ax.band(30, 44, 5.0, 7.4)), rgb('3b4047'), 'cyl', ax.dir, hl=0.35)    # head
    ic.part(ic.poly(ax.band(42, 44, 7.4, 7.4)), STEEL, 'cyl', ax.dir, hl=0.4)             # bezel
    lens = [ax.at(44, -6.6), ax.at(46, -6.6), ax.at(46, 6.6), ax.at(44, 6.6)]
    ic.part(ic.poly(lens), rgb('fff4b8'), 'flat', light=1.0, dark=0.95)
    for o in (-9, 0, 9):                                                                  # light rays
        ic.paint(ic.line([ax.at(49, o * 0.9), ax.at(55, o * 1.4)], 1), rgb('ffe98a'))
    return ic.finish()


def alu_bat():
    ic = Icon()
    ax = Axis((7, 49), 45)
    _bat(ic, ax, rgb('3e6fb8'), rgb('1f1f24'), hl=0.9)                                    # anodised blue
    L = 55 / 46
    x, y = ax.at(46 * L, 0)
    ic.part(ic.ellipse((x - 4.4, y - 4.4, x + 4.4, y + 4.4)), rgb('c9d2da'), 'dome', hl=0.5)  # end cap
    for t in (15, 16.2):
        ic.paint(ic.line([ax.at(t * L, -2.6), ax.at(t * L, 2.6)], 1), rgb('c9d2da'))      # silver bands
    ic.paint(ic.line([ax.at(24 * L, -1.5), ax.at(40 * L, -3.5)], 1), rgb('b9d4f5'))       # hard shine
    return ic.finish()


def rope():
    """A coil of rope in perspective: three stacked loops with a twist, the free end lying out in front."""
    ic = Icon()
    col, dk, lt = rgb('c9a46a'), rgb('8f6d3a'), rgb('e6cb92')
    loops = [((6, 29, 50, 49), (15, 34, 41, 44)), ((8, 22, 48, 43), (16, 27, 40, 38)), ((10, 15, 46, 37), (17, 20, 39, 32))]
    ic.part(ic.line([(40, 45), (47, 48), (53, 47)], 5), col, 'v', strength=0.25)           # the free end
    for (o, i) in loops:
        ring = ic.ellipse(o) & ~ic.ellipse(i)
        ic.part(ring, col, 'v', strength=0.4, light=1.3)
        cx, cy = (o[0] + o[2]) / 2, (o[1] + o[3]) / 2
        rx, ry = ((o[2] - o[0]) + (i[2] - i[0])) / 4, ((o[3] - o[1]) + (i[3] - i[1])) / 4
        for a in range(0, 360, 14):                                                        # the twist: slanted strands
            ang = math.radians(a)
            px, py = cx + rx * math.cos(ang), cy + ry * math.sin(ang)
            tx, ty = -math.sin(ang) * rx, math.cos(ang) * ry
            n = math.hypot(tx, ty) or 1
            tx, ty = tx / n, ty / n
            nx, ny = -ty, tx
            ic.paint(ic.line([(px - tx * 1.5 - nx * 2.2, py - ty * 1.5 - ny * 2.2), (px + tx * 1.5 + nx * 2.2, py + ty * 1.5 + ny * 2.2)], 1), dk)
    for (x, y) in ((53, 46), (54, 48), (52, 49)):
        ic.px(x, y, lt)                                                                    # frayed end
    return ic.finish(shadow=(28, 50, 22, 2.5))


def toolbox():
    ic = Icon()
    ic.part(ic.rect((16, 8, 40, 13), r=2), rgb('3a3a40'), 'v')                            # handle
    ic.cut(ic.rect((20, 10, 36, 14)))
    ic.part(ic.rect((18, 11, 20, 18)), STEEL_DK, 'flat')
    ic.part(ic.rect((36, 11, 38, 18)), STEEL_DK, 'flat')
    ic.part(ic.poly([(8, 22), (12, 16), (44, 16), (48, 22)]), rgb('d0463a'), 'flat', light=1.15)  # lid
    ic.part(ic.rect((6, 22, 50, 46), r=2), RED, 'v', strength=0.3)
    ic.paint(ic.line([(7, 28), (49, 28)], 1), RED_DK)
    for x in (13, 43):
        ic.part(ic.rect((x - 2, 25, x + 2, 31)), STEEL, 'v')
    # a spanner poking out of the lid
    ic.part(ic.poly([(38, 17), (46, 5), (49, 7), (41, 19)]), STEEL, 'cyl', (1, -1.5), hl=0.3)
    ic.part(ic.ellipse((44, 1, 52, 9)), STEEL, 'dome')
    ic.cut(ic.poly([(47, 1), (51, 1), (49, 5)]))
    return ic.finish(shadow=(28, 49, 23, 3))


def fuse():
    ic = Icon()
    ax = Axis((8, 44), 35)
    ic.part(ic.poly(ax.band(9, 34, 5.2, 5.2)), rgb('a9d8e8'), 'cyl', ax.dir, hl=0.7, alpha=0.7)  # glass
    zz = [ax.at(9 + k * 2.5, (1.8 if k % 2 else -1.8)) for k in range(11)]
    ic.paint(ic.line(zz, 1), rgb('4d5359'))                                              # the wire
    for t0, t1 in ((1, 10), (33, 42)):
        ic.part(ic.poly(ax.band(t0, t1, 6.2, 6.2)), rgb('b8914a'), 'cyl', ax.dir, hl=0.5)   # brass end caps
        ic.darken(ic.line([ax.at(t0 + 2, -6.2), ax.at(t0 + 2, 6.2)], 1), 0.7)
        ic.darken(ic.line([ax.at(t1 - 2, -6.2), ax.at(t1 - 2, 6.2)], 1), 0.7)
    x, y = ax.at(21.5, -9)
    ic.paint(ic.line([(x - 3, y - 2), (x + 1, y + 1), (x - 1, y + 1), (x + 3, y + 4)], 1), YELLOW)  # the spark
    return ic.finish()


def battery():
    ic = Icon()
    ax = Axis((13, 48), 60)
    ic.part(ic.poly(ax.band(0, 34, 7.5, 7.5)), rgb('26262b'), 'cyl', ax.dir, hl=0.45)      # black body
    ic.part(ic.poly(ax.band(22, 34, 7.5, 7.5)), rgb('c9793c'), 'cyl', ax.dir, hl=0.5)     # copper top
    ic.part(ic.poly(ax.band(-1, 1.5, 7.5, 7.5)), rgb('c9ced4'), 'cyl', ax.dir, hl=0.5)    # negative end
    ic.part(ic.poly(ax.band(34, 36, 7.5, 6.5)), rgb('c9ced4'), 'cyl', ax.dir, hl=0.5)
    ic.part(ic.poly(ax.band(36, 39.5, 3, 3)), rgb('dfe3e8'), 'cyl', ax.dir, hl=0.5)       # the nub
    c = ax.at(28, 0)
    ic.paint(ic.line([ax.at(25.5, 0), ax.at(30.5, 0)], 1), rgb('fff4dc'))                 # "+"
    ic.paint(ic.line([ax.at(28, -2.5), ax.at(28, 2.5)], 1), rgb('fff4dc'))
    ic.paint(ic.line([ax.at(9, -1), ax.at(17, -1)], 1), rgb('6b6b72'))                    # print on the body
    return ic.finish()


def apartment_key():
    ic = Icon()
    ax = Axis((12, 22), -40)
    ic.part(ic.poly(ax.band(10, 40, 2.8, 2.8)), STEEL_LT, 'cyl', ax.dir, hl=0.35)         # blade
    teeth = [ax.at(t, 2.8 + h) for t, h in ((14, 0), (16, 3), (19, 1.5), (22, 3.5), (25, 1), (28, 3),
                                             (31, 1.5), (34, 2.5), (37, 0))]
    ic.part(ic.poly(teeth + [ax.at(37, 2), ax.at(14, 2)]), STEEL, 'flat')
    ic.paint(ic.line([ax.at(12, -0.8), ax.at(39, -0.8)], 1), rgb('8f98a1'))               # groove
    x, y = ax.at(4, 0)
    ic.part(ic.ellipse((x - 9, y - 9, x + 9, y + 9)), rgb('3d6fb0'), 'dome', hl=0.3)      # rubber head
    ic.cut(ic.ellipse((x - 3.5, y - 5.5, x + 0.5, y - 1.5)))                              # ring hole
    ic.part(ic.arc((x - 13, y - 17, x + 3, y - 1), 120, 380, w=2), STEEL_LT, 'flat')      # key ring
    return ic.finish()


def broken_glass():
    """The smashed lower half of a green bottle: one slanting, irregular break, the base, a few flat shards."""
    ic = Icon()
    g = rgb('4fa870')
    wall = [(14, 47), (13, 19), (17, 17), (19, 26), (23, 22), (25, 31), (30, 27), (31, 34), (38, 31), (38, 47)]
    ic.part(ic.poly(wall) | ic.ellipse((14, 41, 38, 52)), g, 'cyl', (0, 1), hl=0.5, alpha=0.95)
    ic.paint(ic.poly([(14, 24), (17, 17), (19, 26), (23, 22), (25, 31), (30, 27), (31, 34), (38, 31), (38, 36), (14, 36)]) & ic.ellipse((13, 22, 39, 39)),
             rgb('2b6c47'), a=0.7)                                                           # the dark inside of the bottle
    for pts in ([(13, 19), (17, 17), (19, 26), (14, 24)], [(19, 26), (23, 22), (25, 31), (21, 29)],
                [(25, 31), (30, 27), (31, 34), (27, 33)], [(31, 34), (38, 31), (38, 35), (33, 36)]):
        ic.paint(ic.poly(pts), rgb('c2f2d3'), a=0.9)                                        # the cut glass faces
    ic.paint(ic.line([(16, 38), (16, 46)], 1), rgb('e9fff2'))                               # the glare down the side
    ic.paint(ic.line([(18, 39), (18, 42)], 1), rgb('e9fff2'), a=0.6)
    ic.paint(ic.ellipse((21, 45, 33, 50)), rgb('2f7a4f'), a=0.7)                            # the punt in the base
    for pts in ([(41, 48), (50, 47), (54, 50), (45, 51)], [(2, 50), (8, 48), (11, 51), (5, 53)], [(43, 53), (52, 53), (49, 55)]):
        ic.part(ic.poly(pts), rgb('72c68d'), 'flat', light=1.3, alpha=0.92)                # flat shards
    ic.px(47, 49, rgb('ffffff'))
    ic.px(7, 50, rgb('ffffff'))
    return ic.finish(shadow=(28, 52, 24, 2))


def empty_bottle():
    ic = Icon()
    g = rgb('3f8f5a')
    ic.part(ic.rect((17, 22, 37, 50), r=4), g, 'cyl', (0, 1), hl=0.6, alpha=0.9)          # body
    ic.part(ic.poly([(18, 24), (23, 15), (31, 15), (36, 24)]), g, 'cyl', (0, 1), hl=0.6, alpha=0.9, contact=False)
    ic.part(ic.rect((23, 5, 31, 16)), g, 'cyl', (0, 1), hl=0.6, alpha=0.9, contact=False)  # neck
    ic.part(ic.rect((22, 3, 32, 7), r=1), rgb('5aa872'), 'cyl', (0, 1), hl=0.4)            # lip
    ic.part(ic.rect((17, 30, 37, 42)), rgb('e9dfc4'), 'cyl', (0, 1), hl=0.1)               # torn label
    ic.cut(ic.poly([(30, 30), (37, 30), (37, 36), (33, 33)]))
    ic.part(ic.poly([(30, 30), (37, 30), (37, 36), (33, 33)]), g, 'flat', alpha=0.9)
    ic.paint(ic.line([(20, 33), (29, 33)], 1), rgb('a33a2f'))
    return ic.finish(shadow=(27, 51, 13, 2.5))


def magazine():
    ic = Icon()
    ic.part(ic.poly([(12, 8), (44, 10), (44, 50), (10, 48)]), rgb('f1eadb'), 'v', strength=0.15)
    ic.part(ic.poly([(12, 8), (44, 10), (44, 17), (12, 15)]), rgb('c93c33'), 'flat')      # masthead
    ic.paint(ic.line([(15, 12), (34, 13)], 2), WHITE)
    ic.part(ic.rect((15, 19, 38, 40)), rgb('6fa0b8'), 'flat', rim=False)                   # cover photo
    ic.part(ic.ellipse((21, 22, 32, 34)), rgb('e3b28e'), 'flat', rim=False)                # a face
    ic.part(ic.poly([(20, 26), (22, 20), (31, 20), (33, 27), (30, 23), (23, 23)]), rgb('5b3a24'), 'flat', rim=False)
    ic.part(ic.poly([(17, 40), (21, 34), (32, 34), (36, 40)]), rgb('c23b32'), 'flat', rim=False)
    for y in (43, 46):
        ic.paint(ic.line([(15, y), (37, y)], 1), rgb('8a8579'))
    ic.part(ic.poly([(44, 42), (44, 50), (36, 50)]), rgb('d7cfbd'), 'flat')                # dog-ear
    return ic.finish(shadow=(28, 51, 18, 2))


def takeaway():
    ic = Icon()
    ic.part(ic.arc((16, 3, 40, 27), 200, 340, w=1), STEEL, 'flat')                        # wire handle
    ic.part(ic.poly([(13, 20), (43, 20), (39, 49), (17, 49)]), rgb('f2efe6'), 'h', strength=0.3)
    ic.part(ic.poly([(13, 20), (20, 12), (28, 18), (36, 12), (43, 20)]), rgb('e2ddd0'), 'flat')  # flaps
    ic.paint(ic.line([(28, 18), (28, 20)], 1), rgb('b9b3a4'))
    ic.part(ic.poly([(21, 30), (35, 30), (33, 42), (23, 42)]), rgb('c23b32'), 'flat', rim=False)  # the emblem
    ic.paint(ic.line([(24, 34), (32, 34)], 1), rgb('f2efe6'))
    ic.paint(ic.line([(25, 38), (31, 38)], 1), rgb('f2efe6'))
    ic.part(ic.poly([(38, 44), (53, 30), (54, 31), (40, 46)]), rgb('c49a5c'), 'flat')      # chopsticks
    ic.part(ic.poly([(40, 47), (54, 34), (55, 35), (42, 49)]), rgb('b08548'), 'flat')
    return ic.finish(shadow=(28, 51, 16, 2.5))


def dead_plant():
    ic = Icon()
    for pts in ([(26, 26), (22, 16), (15, 12), (10, 16)], [(28, 26), (31, 12), (35, 7)],
                [(30, 26), (38, 18), (45, 21), (47, 29)], [(24, 26), (15, 24), (10, 31)]):
        ic.part(ic.line(pts, 1), rgb('6b5232'), 'flat', rim=False)
    for (x, y, c) in ((10, 17, '8a6a36'), (15, 12, '7a5a2c'), (35, 7, '94733c'), (47, 30, '8a6a36'),
                      (10, 32, '7a5a2c'), (40, 18, '94733c'), (20, 19, '8f7a3a')):
        ic.part(ic.ellipse((x - 2.5, y - 1.5, x + 2.5, y + 1.5)), rgb(c), 'flat')        # shrivelled leaves
    ic.part(ic.poly([(14, 30), (42, 30), (38, 50), (18, 50)]), rgb('b85c38'), 'h', strength=0.35)  # pot
    ic.part(ic.rect((12, 26, 44, 32), r=1), rgb('c96a44'), 'h', strength=0.3)             # rim
    ic.part(ic.ellipse((15, 26, 41, 30)), rgb('4a3526'), 'flat', rim=False)               # dry soil
    return ic.finish(shadow=(28, 51, 14, 2))


def broken_remote():
    ic = Icon()
    ax = Axis((15, 50), 62)
    ic.part(ic.poly(ax.band(0, 44, 7, 7)), rgb('2c2c31'), 'cyl', ax.dir, hl=0.3)
    x, y = ax.at(40, -3)
    ic.part(ic.ellipse((x - 2, y - 2, x + 2, y + 2)), rgb('d23a30'), 'dome')              # power
    cols = (rgb('8a8f96'),) * 3
    for i, t in enumerate((12, 17, 22, 27, 32)):
        for o in (-3.5, 0, 3.5):
            px, py = ax.at(t, o)
            ic.paint(ic.rect((px - 1, py - 1, px + 1, py + 1)), cols[0] if t != 32 else rgb('d8b24a'))
    crack = [ax.at(20, -7), ax.at(22, -2), ax.at(19, 2), ax.at(23, 7)]
    ic.paint(ic.line(crack, 1), rgb('d7d9dc'))
    ic.cut(ic.poly([ax.at(0, 2), ax.at(7, 7.5), ax.at(0, 7.5)]))                         # snapped corner
    return ic.finish()


def paperwork():
    ic = Icon()
    for (dx, dy, c) in ((6, 6, 'd8d2c3'), (3, 3, 'e6e0d2'), (0, 0, 'f4f0e6')):
        ic.part(ic.poly([(10 + dx, 10 + dy), (40 + dx, 8 + dy), (42 + dx, 44 + dy), (12 + dx, 46 + dy)]),
                rgb(c), 'flat', light=1.05)
    for k in range(7):
        y = 15 + k * 4
        ic.paint(ic.line([(15, y + 1), (36 - (k % 3) * 4, y)], 1), rgb('8a8a8a'))
    ic.part(ic.rect((24, 38, 38, 43)), rgb('c9443a'), 'flat', rim=False, alpha=0.85)      # the red stamp
    ic.part(ic.poly([(34, 4), (37, 4), (37, 14), (34, 14)]), STEEL_LT, 'flat', rim=False)  # paperclip
    ic.cut(ic.rect((35, 6, 36, 12)))
    return ic.finish(shadow=(30, 52, 20, 2))


def old_shoes():
    """A worn leather shoe, side-on, built from panels (heel counter, vamp, toe cap, tongue, collar) so it has form."""
    ic = Icon()
    leather, dark = rgb('86593a'), rgb('5f3b27')
    ic.part(ic.poly([(6, 49), (5, 45), (52, 45), (55, 47), (53, 49)]), rgb('2b2522'), 'v', strength=0.25)   # outsole
    ic.part(ic.poly([(6, 45), (6, 41), (42, 41), (52, 43), (55, 46), (55, 47), (6, 47)]), rgb('d9ceb4'), 'v', strength=0.2)  # midsole
    ic.paint(ic.line([(7, 46), (53, 46)], 1), rgb('9a8f78'))
    upper = [(8, 42), (7, 27), (11, 22), (17, 21), (20, 26), (26, 24), (33, 27), (43, 31), (51, 36), (55, 42), (55, 43), (8, 43)]
    ic.part(ic.poly(upper), leather, 'v', strength=0.34, light=1.3)
    ic.part(ic.poly([(8, 42), (7, 27), (11, 22), (16, 22), (17, 43), (8, 43)]), dark, 'h', strength=0.3, light=1.2)   # heel counter
    ic.part(ic.poly([(42, 31), (51, 36), (55, 42), (55, 43), (40, 43), (39, 34)]), dark, 'v', strength=0.3)           # toe cap
    ic.part(ic.poly([(11, 22), (17, 20), (22, 23), (19, 27), (12, 26)]), rgb('241812'), 'flat', rim=False)             # the dark opening
    ic.part(ic.poly([(19, 26), (24, 19), (31, 20), (30, 27), (25, 29)]), rgb('a4724b'), 'v', strength=0.25, light=1.3)  # the tongue
    for k in range(3):                                                                                                 # laces + eyelets
        cx, cy = 26.5 + k * 4.4, 27 + k * 2.0
        ic.paint(ic.line([(cx - 1.5, cy + 1.5), (cx + 1.5, cy - 1.5)], 1), rgb('efe6d2'))
        ic.px(cx - 2.5, cy + 2.5, rgb('241812'))
    ic.paint(ic.line([(43, 35), (49, 38)], 1), rgb('c99a72'))                                                           # scuffs
    ic.paint(ic.line([(25, 34), (31, 36)], 1), rgb('c99a72'))
    ic.paint(ic.line([(11, 32), (14, 38)], 1), rgb('3f2618'))                                                           # a crease
    ic.cut(ic.ellipse((47, 39, 50, 41)))                                                                                # worn through
    return ic.finish(shadow=(30, 51, 25, 2))


def empty_wallet():
    """A worn leather billfold, its cash slot gaping — nothing in it."""
    ic = Icon()
    ic.part(ic.rect((6, 15, 50, 43), r=4), rgb('7a4a2c'), 'v', strength=0.3)
    ic.part(ic.rect((9, 17, 47, 24), r=2), rgb('2c180d'), 'flat', rim=False, contact=False)   # the empty cash slot
    ic.paint(ic.line([(10, 24), (46, 24)], 1), rgb('c49a6a'))                               # the lip of the front panel
    for x in range(10, 47, 3):                                                               # stitching
        ic.px(x, 40, rgb('c9a06e'))
    for y in range(27, 39, 3):
        ic.px(9, y, rgb('c9a06e'))
        ic.px(46, y, rgb('c9a06e'))
    ic.paint(ic.rect((36, 29, 43, 35)), rgb('6a3f25'))                                       # a worn patch
    ic.paint(ic.line([(14, 29), (22, 29)], 1), rgb('8f5e3a'))                                # scuff
    ic.paint(ic.ellipse((23, 31, 29, 37)), rgb('5e3a24'))                                    # faint empty-card imprint
    return ic.finish(shadow=(28, 47, 22, 2.5))


def broken_umbrella():
    ic = Icon()
    ic.part(ic.line([(28, 24), (29, 38), (31, 44)], 2), rgb('5e646b'), 'flat')            # bent shaft
    ic.part(ic.arc((25, 40, 35, 52), 0, 180, w=3), rgb('6b4a30'), 'flat')                 # J handle
    canopy = [(6, 26), (10, 17), (19, 10), (28, 8), (37, 10), (46, 17), (50, 26), (43, 23), (36, 27),
              (28, 23), (20, 27), (13, 23)]
    ic.part(ic.poly(canopy), rgb('2f3440'), 'dome', hl=0.25)
    ic.cut(ic.poly([(36, 12), (46, 18), (48, 25), (43, 23), (39, 20)]))                   # torn panel
    for pts in ([(28, 9), (40, 13), (47, 21), (52, 20)], [(28, 9), (37, 16), (41, 24)]):
        ic.part(ic.line(pts, 1), STEEL, 'flat', rim=False)                               # bare ribs
    ic.part(ic.rect((27, 5, 29, 9)), STEEL_DK, 'flat')                                    # ferrule
    return ic.finish()


def bank_notes():
    ic = Icon()
    note = rgb('8fb38a')
    ic.part(ic.poly([(8, 30), (44, 26), (50, 36), (14, 41)]), scale(note, 0.7), 'flat')   # the stack's side
    for k in range(4):
        ic.paint(ic.line([(9 + k, 32 + k * 2), (46 + k, 28 + k * 2)], 1), rgb('d9e6d2'))
    ic.part(ic.poly([(6, 22), (42, 18), (48, 28), (12, 33)]), note, 'flat', light=1.15)    # top note
    ic.part(ic.poly([(9, 22), (40, 19), (45, 27), (14, 31)]), rgb('a9c7a2'), 'flat', rim=False, contact=False)
    ic.part(ic.ellipse((22, 21, 31, 29)), rgb('6f9468'), 'flat', rim=False, contact=False)  # portrait
    ic.paint(ic.line([(11, 24), (15, 24)], 1), rgb('4f7449'))                             # numerals
    ic.paint(ic.line([(37, 23), (41, 22)], 1), rgb('4f7449'))
    ic.part(ic.poly([(24, 20), (30, 19), (37, 38), (31, 39)]), rgb('e9e2cf'), 'flat')      # paper band
    ic.paint(ic.line([(27, 20), (34, 38)], 1), rgb('c9443a'))
    return ic.finish(shadow=(28, 45, 22, 2.5))


def screwdriver():
    ic = Icon()
    ax = Axis((7, 49), 45)
    ic.part(ic.poly(ax.band(0, 18, 4.6, 4.2)), rgb('e2b52c'), 'cyl', ax.dir, hl=0.45, alpha=0.95)  # handle
    for o in (-2.5, 0, 2.5):
        ic.darken(ic.line([ax.at(1, o), ax.at(17, o)], 1), 0.75)                          # flutes
    ic.part(ic.poly(ax.band(-1, 3, 4.8, 4.8)), rgb('2b2b30'), 'cyl', ax.dir)              # end cap
    ic.part(ic.poly(ax.band(18, 22, 3.4, 2.4)), rgb('2b2b30'), 'cyl', ax.dir)             # ferrule
    ic.part(ic.poly(ax.band(22, 50, 1.4, 1.4)), STEEL_LT, 'cyl', ax.dir, hl=0.3)          # shaft
    ic.part(ic.poly(ax.band(50, 55, 1.4, 2.3)), STEEL, 'cyl', ax.dir, hl=0.2)             # flat tip
    return ic.finish()


def crowbar():
    """A long pry bar: painted red, bare steel at the chisel end and the claw. No grip."""
    ic = Icon()
    col = rgb('c53a30')
    ic.part(ic.line([(45, 9), (14, 43)], 5), col, 'cyl', (31, -34), hl=0.35)              # the bar
    ic.part(ic.line([(14, 43), (11, 48), (13, 52), (18, 52), (21, 48)], 5), STEEL, 'cyl', (1, 1), hl=0.3)  # the claw
    ic.part(ic.poly([(19, 45), (23, 47), (21, 49)]), STEEL_DK, 'flat')                    # claw split
    ic.part(ic.poly([(43, 8), (49, 2), (53, 5), (47, 11)]), STEEL, 'flat', light=1.3)      # the flat chisel end
    return ic.finish()


def scrap_bag():
    ic = Icon()
    ic.part(ic.line([(34, 16), (42, 5)], 3), STEEL, 'cyl', (8, -11), hl=0.3)              # a pipe
    ic.part(ic.ellipse((12, 6, 24, 18)), STEEL_DK, 'flat')                                # a cog
    ic.cut(ic.ellipse((16, 10, 20, 14)))
    for a in range(0, 360, 45):
        x, y = 18 + 7 * math.cos(math.radians(a)), 12 + 7 * math.sin(math.radians(a))
        ic.part(ic.rect((x - 1.5, y - 1.5, x + 1.5, y + 1.5)), STEEL_DK, 'flat', contact=False)
    for k in range(4):                                                                   # a spring
        ic.part(ic.arc((26, 8 + k * 2, 32, 12 + k * 2), 180, 360, w=1), STEEL_LT, 'flat', rim=False)
    sack = [(12, 22), (20, 18), (36, 18), (44, 22), (49, 34), (46, 46), (34, 50), (20, 50), (9, 45), (7, 34)]
    ic.part(ic.poly(sack), rgb('b89565'), 'dome', hl=0.1)
    ys, xs = ic.poly(sack).nonzero()
    for y, x in zip(ys, xs):
        if (x * 3 + y * 5) % 7 == 0:
            ic.px(x, y, rgb('9c7b4f'))                                                    # hessian weave
    ic.part(ic.poly([(20, 18), (36, 18), (33, 23), (23, 23)]), rgb('8d6f45'), 'flat')     # gathered neck
    ic.part(ic.rect((21, 20, 35, 22)), rgb('5d4a30'), 'flat', rim=False)                  # twine
    return ic.finish(shadow=(28, 51, 21, 2.5))


def cabinet_key():
    ic = Icon()
    ic.part(ic.line([(18, 18), (27, 20), (33, 26)], 1), rgb('b8a47a'), 'flat', rim=False)  # string
    tag = [(29, 25), (45, 31), (41, 49), (25, 43)]
    ic.part(ic.poly(tag), rgb('d8c69a'), 'v', strength=0.2)                              # manila tag
    ic.cut(ic.ellipse((31, 27, 34, 30)))
    ic.paint(ic.line([(29, 36), (38, 39)], 1), rgb('a33a2f'))                              # "GUNS"
    ic.paint(ic.line([(28, 40), (35, 42)], 1), rgb('6d6252'))
    ax = Axis((14, 16), -50)
    ic.part(ic.poly(ax.band(6, 30, 1.8, 1.8)), BRASS, 'cyl', ax.dir, hl=0.4)               # barrel
    ic.part(ic.poly([ax.at(24, 1.8), ax.at(29, 1.8), ax.at(29, 6), ax.at(24, 6)]), BRASS, 'flat')  # the bit
    ic.cut(ic.poly([ax.at(26, 3.5), ax.at(27, 3.5), ax.at(27, 6.5), ax.at(26, 6.5)]))
    x, y = ax.at(3, 0)
    ic.part(ic.ellipse((x - 5.5, y - 5.5, x + 5.5, y + 5.5)), BRASS, 'dome', hl=0.35)     # bow
    ic.cut(ic.ellipse((x - 2.5, y - 2.5, x + 2.5, y + 2.5)))
    return ic.finish()


# id -> (drawing, file name). Keep the names as they are on disk (the loader + .import files).
ICONS = {
    '001': (knife, '001.png'),
    '002': (hammer, '002.png'),
    '003': (sword, '003.png'),
    '004': (gun, '004.png'),
    '005': (canned_food, '005.png'),
    '006': (bandages, '006.png'),
    '007': (first_aid, '007.png'),
    '008': (clothes, '008.png'),
    '009': (torn_clothes, '009.png'),
    '010': (painkillers, '010.png'),
    '011': (ice_pack, '011.png'),
    '012': (golf_club, '012.png'),
    '013': (cricket_bat, '013.png'),
    '014': (baseball_bat, '014.png'),
    '015': (flashlight, '015.png'),
    '016': (bullets, '016.png'),
    '017': (alu_bat, '017.png'),
    '018': (rope, '018.png'),
    '019': (toolbox, '019.png'),
    '020': (fuse, '020.png'),
    '021': (battery, '021.png'),
    '022': (apartment_key, '022.png'),
    '023': (broken_glass, '023.png'),
    '024': (empty_bottle, '024.png'),
    '025': (magazine, '025.png'),
    '026': (takeaway, '026.png'),
    '027': (dead_plant, '027.png'),
    '028': (broken_remote, '028.png'),
    '029': (paperwork, '029.png'),
    '030': (old_shoes, '030.png'),
    '031': (empty_wallet, '031.png'),
    '032': (broken_umbrella, '032.png'),
    '033': (bank_notes, '033.png'),
    '034': (screwdriver, '034 - Screwdriver.png'),
    '035': (crowbar, '035 - Crowbar.png'),
    '036': (extinguisher, '036 - Fire Extinguisher.png'),
    '037': (scrap_bag, '037 - Scrap Bag.png'),
    '038': (cabinet_key, '038 - Gun Cabinet Key.png'),
}


def sheet(icons, path, zoom=3, cols=8):
    """A contact sheet on the HUD slot's grey (0.25) with its border, each icon at `zoom`x + its id."""
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 11)
    cell = 64 * zoom
    rows = (len(icons) + cols - 1) // cols
    im = Image.new('RGBA', (cols * (cell + 8) + 8, rows * (cell + 24) + 8), (30, 30, 32, 255))
    d = ImageDraw.Draw(im)
    for i, (iid, icon) in enumerate(icons):
        x = 8 + (i % cols) * (cell + 8)
        y = 8 + (i // cols) * (cell + 24)
        d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=(64, 64, 64, 255), outline=(153, 153, 153, 255),
                    width=2 * zoom)
        big = icon.resize((S * zoom, S * zoom), Image.NEAREST)
        im.alpha_composite(big, (x + 4 * zoom, y + 4 * zoom))
        d.text((x, y + cell + 4), iid, fill=(220, 220, 220, 255), font=font)
    im.save(path)


def main(only):
    done = []
    for iid, (fn, fname) in sorted(ICONS.items()):
        icon = fn()
        if not os.environ.get('PREVIEW') and (not only or iid in only):
            icon.save(os.path.join(ITEMS, fname))
        done.append((iid, icon))
    out = os.path.join(ROOT, 'docs', 'art_reference', 'items')
    os.makedirs(out, exist_ok=True)
    sheet(done, os.path.join(out, 'item_icons.png'), zoom=3)
    sheet(done, os.path.join(out, 'item_icons_1x.png'), zoom=1, cols=13)
    print('icons:', len(done))


if __name__ == '__main__':
    main(set(sys.argv[1:]))
