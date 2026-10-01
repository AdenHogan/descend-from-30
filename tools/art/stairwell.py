"""STAIRWELL art (owner round 31: "continue with the same angle and view as present… keep the stairs and the turn similar to what we
already have, we don't need too different a visual design"). The corridor looks into a stair hall through an 80x115 px sprite — the old
paint-box art, redrawn here as real pixel art on the SAME layout and proportions:

  UP   (Lobby_*)               left half = the hall's plaster wall, a newel post, then a 40 px shaft: a dark back wall, a framed window,
                               nine flat frontal steps (yellow nosing / shadowed riser), a grey stringer on the right with a handrail.
  DOWN (Hallway_Staircase_*)   left half = the dark shaft (a lit far wall above, then black), with ONLY the first step — a yellow lip at
                               the bottom — drawn: the flight itself is never shown (the player steps down out of sight), so the
                               angle stays flat-on; right half = the same plaster wall + newel post.

Nothing about the pan / triggers / slice depends on the art — only its 80x115 box (x 131..211 left, 1139..1219 right; y 291..406).
Outputs assets/Lobby_{Left,Right}.png + assets/Hallway_Staircase_{Left,Right}.png (Right = mirrored) and, with --mock,
docs/art_reference/stairwell.png (sheet, 5x). `python3 tools/art/stairwell.py`."""
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 80, 115

PLASTER = [(52, 58, 56), (66, 73, 70), (82, 90, 86), (98, 106, 100)]       # the hall's side wall, dark -> lit
DARK = [(14, 15, 15), (22, 24, 24), (31, 33, 32), (42, 45, 44)]            # the shaft's dark back wall
FAR = [(70, 76, 74), (88, 95, 92), (106, 113, 108), (124, 130, 122)]       # the DOWN shaft's lit far wall
YEL = [(112, 82, 22), (166, 124, 30), (200, 160, 40), (230, 192, 70)]      # step: shadow, riser, tread, nosing highlight
WOOD = [(70, 48, 14), (110, 78, 20), (150, 108, 34)]
FRAME = [(112, 70, 48), (170, 112, 80), (204, 150, 112)]
GLASS = [(112, 178, 198), (153, 217, 234), (192, 236, 246)]
STEEL = [(60, 66, 72), (110, 118, 126), (160, 168, 174)]
FLOOR = [(70, 70, 68), (100, 100, 96), (130, 130, 124)]
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
SHAFT_X0 = 41                       # UP: where the shaft starts (the wall + post fill 0..40)


def px(img):
    return img.load()


def dither(ramp, v, x, y, spread=0.5):
    """v in 0..len(ramp)-1 (float) -> a ramp colour, ordered-dithered between neighbours."""
    i = int(v)
    f = v - i
    t = 0.5 + ((BAYER[y % 4][x % 4] + 0.5) / 16.0 - 0.5) * spread
    return ramp[min(len(ramp) - 1, i + (1 if f > t else 0))]


def rect(p, x0, y0, x1, y1, col):
    for y in range(max(0, y0), min(H, y1 + 1)):
        for x in range(max(0, x0), min(W, x1 + 1)):
            p[x, y] = col + (255,)


def wall(p, x0, x1, lit_from):
    """The hall's plaster side wall: darker toward the floor (a dado), lit toward `lit_from` (x), a skirting + a faint vertical seam."""
    for y in range(0, 108):
        for x in range(x0, x1 + 1):
            d = abs(x - lit_from) / 40.0
            v = 2.4 - 1.5 * d - (0.9 if y > 74 else 0.0) + (0.25 if y < 20 else 0.0)
            p[x, y] = dither(PLASTER, max(0.0, min(3.0, v)), x, y, 0.12) + (255,)
    for x in range(x0, x1 + 1):
        p[x, 74] = PLASTER[0] + (255,)                       # dado rail
        p[x, 75] = PLASTER[2] + (255,)


def floor_strip(p, x0, x1):
    for x in range(x0, x1 + 1):
        p[x, 108] = FLOOR[0] + (255,)
        for y in range(109, H):
            p[x, y] = dither(FLOOR, 1.0 + (y - 109) * 0.12, x, y, 0.3) + (255,)


def newel(p, x):
    for y in range(0, 109):
        p[x, y] = WOOD[1] + (255,)
        p[x + 1, y] = WOOD[0] + (255,)
        p[x - 1, y] = WOOD[2] + (255,) if y % 9 else WOOD[1] + (255,)


def window(p, x0, y0, x1, y1):
    rect(p, x0 - 1, y0 - 1, x1 + 1, y1 + 1, FRAME[0])
    rect(p, x0, y0, x1, y1, FRAME[1])
    gx0, gy0, gx1, gy1 = x0 + 2, y0 + 2, x1 - 2, y1 - 2
    my = (gy0 + gy1) // 2
    for y in range(gy0, gy1 + 1):
        for x in range(gx0, gx1 + 1):
            if abs(y - my) <= 0:
                p[x, y] = FRAME[1] + (255,)
                continue
            t = (y - gy0) / max(1, gy1 - gy0)
            p[x, y] = dither(GLASS, 2.0 - 1.4 * t + (0.3 if x < gx0 + 4 else 0.0), x, y, 0.4) + (255,)
    for x in range(x0 - 1, x1 + 2):
        p[x, y1 + 1] = FRAME[2] + (255,)                      # the sill, catching light
        p[x, y1 + 2] = FRAME[0] + (255,)


def dark_back(p, x0, x1, y0, y1, glow=None):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            v = 1.0 + (0.5 if y < 8 else 0.0)
            if glow:
                gx, gy, gr = glow
                d = ((x - gx) ** 2 + ((y - gy) * 0.7) ** 2) ** 0.5
                v += max(0.0, 1.6 * (1 - d / gr))
            p[x, y] = dither(DARK, min(3.0, v), x, y, 0.2) + (255,)


def up_view():
    img = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    p = px(img)
    wall(p, 0, 39, lit_from=39)
    floor_strip(p, 0, W - 1)
    # the shaft: dark back wall, the window high up, light spilling down toward the steps
    dark_back(p, SHAFT_X0, W - 1, 0, 108, glow=(59, 24, 30))
    window(p, 48, 3, 69, 36)
    # nine flat frontal steps, a touch narrower toward the top (the stringer leans in); nosing / tread / shadowed riser
    N, y_bot = 9, 108
    heights = [6.4 - 0.14 * i for i in range(N)]
    y = float(y_bot)
    for i in range(N):
        hgt = heights[i]
        top = int(round(y - hgt))
        right = 79 - int(round(i * 0.55))
        for yy in range(top, int(round(y))):
            r = (yy - top) / max(1.0, hgt - 1)
            for xx in range(SHAFT_X0, right + 1):
                if r < 0.18:
                    col = YEL[3]                                  # the nosing's bright edge
                elif r < 0.52:
                    col = YEL[2]                                  # tread
                elif r < 0.86:
                    col = YEL[1]                                  # riser
                else:
                    col = YEL[0]                                  # the shadow under the next nosing
                lit = 0.0 if (xx - SHAFT_X0) > 14 else 0.0
                p[xx, yy] = col + (255,)
        y -= hgt
    top_y = int(round(y))
    # the stringer on the right: a grey wedge that leans in with the steps, a lit top edge, and one clean handrail line above it
    for yy in range(top_y - 2, 109):
        edge = 79 - int(round((108 - yy) / (108.0 - top_y) * 5.0))
        for xx in range(edge + 1, W):
            p[xx, yy] = (STEEL[1] if xx == edge + 1 else STEEL[0]) + (255,)
    for yy in range(top_y - 8, 104):
        xx = 77 - int(round((104 - yy) / (104.0 - top_y + 8) * 4.0))
        p[xx, yy] = STEEL[2] + (255,)
    newel(p, 40)
    return img


def down_view():
    img = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    p = px(img)
    wall(p, 41, W - 1, lit_from=41)
    floor_strip(p, 0, W - 1)
    # the shaft is the LEFT half: x 1..38. Upper part: the lit far wall (a landing's wall far below, seen over the lip)
    for y in range(0, 35):
        for x in range(1, 39):
            v = 1.4 + 0.9 * (1 - abs(x - 20) / 20.0) * (1 - y / 40.0) + (0.3 if y % 8 == 0 else 0.0)
            p[x, y] = dither(FAR, min(3.0, v), x, y, 0.15) + (255,)
    # the dark opening below it: just the black of the shaft (the flight is NOT drawn — you only ever see the first step, and the
    # player goes down out of sight past it, so the angle stays flat-on exactly as it always was)
    dark_back(p, 1, 38, 35, 106)
    for y in range(35, 40):                                          # the far wall's foot, a soft dark edge
        for x in range(1, 39):
            p[x, y] = dither(DARK, 2.2 - (y - 35) * 0.4, x, y, 0.2) + (255,)
    # the lip: a yellow tactile strip at the top of the stairs
    rect(p, 0, 105, 40, 105, YEL[0])
    rect(p, 0, 106, 40, 107, YEL[2])
    rect(p, 0, 106, 40, 106, YEL[3])
    rect(p, 0, 108, 40, 108, YEL[0])
    newel(p, 40)
    for y in range(0, 108):                                       # the left edge's lit wall sliver
        p[0, y] = dither(PLASTER, 2.5, 0, y) + (255,)
    return img


def build():
    up, down = up_view(), down_view()
    outs = {'Lobby_Left.png': up, 'Hallway_Staircase_Left.png': down,
            'Lobby_Right.png': up.transpose(Image.FLIP_LEFT_RIGHT),
            'Hallway_Staircase_Right.png': down.transpose(Image.FLIP_LEFT_RIGHT)}
    for name, im in outs.items():
        im.save(os.path.join(ROOT, 'assets', name))
        print('wrote assets/' + name)
    if '--mock' in sys.argv:
        out = os.path.join(ROOT, 'docs', 'art_reference')
        os.makedirs(out, exist_ok=True)
        sheet = Image.new('RGBA', (W * 5 * 2 + 30, H * 5 + 20), (30, 30, 34, 255))
        sheet.paste(up.resize((W * 5, H * 5), Image.NEAREST), (10, 10))
        sheet.paste(down.resize((W * 5, H * 5), Image.NEAREST), (W * 5 + 20, 10))
        sheet.save(os.path.join(out, 'stairwell.png'))
        print('wrote docs/art_reference/stairwell.png')


if __name__ == '__main__':
    build()
