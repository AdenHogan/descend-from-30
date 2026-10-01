"""STAIRWELL art (owner round 31: "continue with the same angle and view as present… keep the stairs and the turn similar to what we
already have, we don't need too different a visual design"). The corridor looks into a stair hall through an 80x115 px sprite — the old
paint-box art, redrawn here as real pixel art on the SAME layout and proportions:

  UP   (Lobby_*)               left half = the hall's plaster wall, a newel post, then a 40 px shaft: a dark back wall, a framed window,
                               nine flat frontal steps (yellow nosing / shadowed riser), a grey stringer on the right with a handrail.
  DOWN (Hallway_Staircase_*)   left half = the dark shaft (a lit far wall above, then black), with ONLY the first step — a yellow lip at
                               the bottom — drawn: the flight itself is never shown (the player steps down out of sight), so the
                               angle stays flat-on; right half = the same plaster wall + newel post.

Nothing about the pan / triggers / slice depends on the art — only its 80x115 box (x 131..211 left, 1139..1219 right; y 291..406).
Outputs assets/Lobby_{Left,Right}.png + assets/Hallway_Staircase_{Left,Right}.png (Right = mirrored; the DOWN default = the 'cleaner'
recess), assets/stairs/down_<recess>_{left,right}.png for each RECESS_KINDS (building_floors rotates them by floor) and, with --mock,
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
    N, y_bot = STEP_N, STEP_BOT
    heights = _step_heights()
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


# ---------------------------------------------------------------- DOWN
# Owner round 31c (with a sketch): the grey part is the BACK of the rear-facing flight that climbs to the next floor (on that floor
# it is the stair going down). Its lower edge sits on the SAME LINE as the top of the yellow up-stairs (`up_steps_top()`), and the
# space under it is NOT empty black — it's the recess under that flight at landing level: a back wall, the landing floor, and
# something stood there (RECESS: extinguisher / junk / table).
RECESS = 'cleaner'
RECESS_KINDS = ['cleaner', 'junk', 'table']   # rotated by floor (building_floors._apply_stair_visuals)
CONCRETE = [(38, 42, 42), (58, 64, 62), (80, 87, 83), (104, 111, 104), (126, 132, 122)]
STEP_N, STEP_BOT = 9, 108


def _step_heights():
    return [6.4 - 0.14 * i for i in range(STEP_N)]


def up_steps_top() -> int:
    """Sprite-y of the top edge of the yellow up-stairs (the line the DOWN stair's grey must sit on)."""
    return int(round(STEP_BOT - sum(_step_heights())))


def shade(c, k):
    return (max(0, min(255, int(c[0] * k))), max(0, min(255, int(c[1] * k))), max(0, min(255, int(c[2] * k))))


def back_of_flight(p, x0, x1, line):
    """The underside/back of the flight rising away to the next floor, seen from the landing: concrete, stepped where each tread's
    back shows (bands shrinking as the flight climbs away), darker toward the top, a lit lip on its lowest edge."""
    hs = [8.2 - 0.62 * i for i in range(STEP_N)]   # nearest (lowest) band is the biggest; they shrink as the flight climbs away
    y = float(line)
    bands = []
    for i, hgt in enumerate(hs):
        top = y - hgt
        bands.append((int(round(top)), int(round(y)), i))
        y = top
    for x in range(x0, x1 + 1):
        for yy in range(0, line + 1):
            p[x, yy] = dither(CONCRETE, 0.6 + 0.9 * (yy / max(1, line)), x, yy, 0.15) + (255,)
    for (t, b, i) in bands:
        for x in range(x0, x1 + 1):
            if 0 <= t < H:
                p[x, t] = dither(CONCRETE, 2.0 + 0.4 * (b / max(1, line)), x, t, 0.0) + (255,)    # the tread's back edge
            if 0 <= t + 1 < H:
                p[x, t + 1] = dither(CONCRETE, 0.4, x, t + 1, 0.0) + (255,)                       # shadow under it
    for yy in range(0, line + 1):                                                                   # the stringers at both sides
        for x in (x0, x0 + 1):
            p[x, yy] = CONCRETE[0] + (255,)
        for x in (x1 - 1, x1):
            p[x, yy] = CONCRETE[1] + (255,)
    for x in range(x0, x1 + 1):
        p[x, line] = CONCRETE[4] + (255,)                                                           # lowest edge, catching light
        p[x, line + 1] = (14, 15, 15, 255)
        p[x, line + 2] = (20, 22, 22, 255)


def recess(p, x0, x1, top, floor_y, lip_y):
    """The space under that flight at landing level: a back wall in shadow (darker up under the stairs), a skirting, and the landing
    floor running to the lip."""
    for y in range(top, floor_y):
        k = (y - top) / max(1, floor_y - top)
        for x in range(x0, x1 + 1):
            p[x, y] = dither(PLASTER, 0.15 + 1.25 * k, x, y, 0.2) + (255,)
    for x in range(x0, x1 + 1):
        p[x, floor_y] = PLASTER[0] + (255,)
        for y in range(floor_y + 1, lip_y):
            k = (y - floor_y) / max(1, lip_y - floor_y)
            p[x, y] = dither(CONCRETE, 1.0 + 1.6 * k, x, y, 0.2) + (255,)


def _box(p, x0, y0, x1, y1, ramp, light=1.0, outline=(18, 18, 18)):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y in (y0, y1)
            if edge:
                p[x, y] = outline + (255,)
            else:
                v = (len(ramp) - 1) * (0.75 - 0.5 * (x - x0) / max(1, x1 - x0)) * light
                p[x, y] = dither(ramp, max(0.0, min(len(ramp) - 1.0, v)), x, y, 0.2) + (255,)


def _shadow(p, x0, x1, y):
    for x in range(x0, x1 + 1):
        c = p[x, y]
        p[x, y] = shade(c, 0.55) + (255,)


RED = [(80, 14, 12), (140, 26, 20), (190, 44, 32), (226, 92, 70)]
CARD = [(92, 66, 36), (132, 98, 56), (168, 128, 76), (196, 160, 104)]
TIMBER = [(58, 38, 20), (92, 62, 32), (124, 86, 46)]
BAG = [(10, 10, 12), (24, 24, 28), (44, 44, 50)]
BUCKET = [(120, 104, 28), (170, 150, 40), (210, 190, 70)]


def props(p, kind, floor_y, lip_y):
    if kind == 'cleaner':
        # a cleaner's corner: a mop bucket stood forward with the mop leaning back on the wall, a folded yellow wet-floor sign
        # (NO extinguisher drawn here: real extinguishers are pickups, and a painted one would read as one you can't take)
        _box(p, 18, floor_y - 6, 29, lip_y - 3, BUCKET, 0.85)                  # the bucket
        _box(p, 20, floor_y - 9, 27, floor_y - 6, STEEL, 0.7)                  # its wringer
        for i in range(0, 28):                                                 # the mop handle leaning back on the wall
            x = 28 + i // 5
            y = lip_y - 6 - i
            if 0 <= y < H:
                p[x, y] = TIMBER[2] + (255,)
        for k in range(0, 18):                                                 # the wet-floor sign: an A-frame, folded
            y = floor_y - 16 + k
            w = 2 + k // 4
            for x in range(8 - w, 8 + w + 1):
                p[x, y] = BUCKET[2] + (255,) if abs(x - 8) < w else (40, 36, 10, 255)
        for x in range(6, 11):
            p[x, floor_y - 8] = (30, 30, 30, 255)                              # its black band
        _shadow(p, 3, 34, lip_y - 2)
    elif kind == 'junk':
        _box(p, 3, floor_y - 12, 19, lip_y - 3, CARD, 0.9)                     # a big box, forward
        _box(p, 6, floor_y - 24, 17, floor_y - 12, CARD, 0.8)                  # a smaller one on it
        for y in range(floor_y - 12, lip_y - 3):
            p[11, y] = (170, 150, 110, 255)                                    # parcel tape
        for x in range(7, 17):
            p[x, floor_y - 18] = (170, 150, 110, 255)
        _box(p, 23, floor_y - 3, 35, lip_y - 3, [(150, 146, 132), (190, 186, 170), (220, 216, 200)], 0.75)   # newspapers, tied
        for x in range(23, 36):
            p[x, floor_y + 2] = (60, 56, 50, 255)
        _box(p, 26, floor_y - 9, 32, floor_y - 3, [(60, 70, 90), (90, 104, 130), (120, 136, 160)], 0.8)      # a paint tin on them
        _shadow(p, 2, 36, lip_y - 2)
    elif kind == 'table':
        _box(p, 4, floor_y - 14, 22, floor_y - 12, TIMBER, 1.0)                # table top
        for x in (5, 21):
            for y in range(floor_y - 11, lip_y - 2):
                p[x, y] = TIMBER[0] + (255,)
                p[x + 1, y] = TIMBER[1] + (255,)
        _box(p, 10, floor_y - 21, 15, floor_y - 15, [(90, 50, 34), (130, 74, 48), (160, 96, 64)], 1.0)    # a pot
        for i, (dx, dy) in enumerate([(-2, -3), (0, -6), (2, -4), (1, -8), (-1, -7), (3, -6)]):          # a dead plant
            p[12 + dx, floor_y - 21 + dy] = (96, 84, 46, 255)
        _box(p, 25, floor_y - 6, 36, lip_y - 3, BAG, 1.0)                      # a bin bag
        p[30, floor_y - 7] = BAG[2] + (255,)
        p[31, floor_y - 8] = BAG[2] + (255,)
        _shadow(p, 3, 37, lip_y - 2)


def down_view(kind=None):
    kind = kind or RECESS
    img = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    p = px(img)
    wall(p, 41, W - 1, lit_from=41)
    floor_strip(p, 0, W - 1)
    line = up_steps_top()
    back_of_flight(p, 1, 38, line)
    floor_y, lip_y = 94, 105
    recess(p, 1, 38, line + 3, floor_y, lip_y)
    props(p, kind, floor_y, lip_y)
    # the lip: the first step down, in yellow
    rect(p, 0, 105, 40, 105, YEL[0])
    rect(p, 0, 106, 40, 107, YEL[2])
    rect(p, 0, 106, 40, 106, YEL[3])
    rect(p, 0, 108, 40, 108, YEL[0])
    newel(p, 40)
    for y in range(0, 108):
        p[0, y] = dither(PLASTER, 2.5, 0, y) + (255,)
    return img


def build():
    up, down = up_view(), down_view()
    for kind in RECESS_KINDS:
        dv = down_view(kind)
        dv.save(os.path.join(ROOT, 'assets', 'stairs', 'down_%s_left.png' % kind))
        dv.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(ROOT, 'assets', 'stairs', 'down_%s_right.png' % kind))
        print('wrote assets/stairs/down_%s_{left,right}.png' % kind)
    outs = {'Lobby_Left.png': up, 'Hallway_Staircase_Left.png': down,
            'Lobby_Right.png': up.transpose(Image.FLIP_LEFT_RIGHT),
            'Hallway_Staircase_Right.png': down.transpose(Image.FLIP_LEFT_RIGHT)}
    for name, im in outs.items():
        im.save(os.path.join(ROOT, 'assets', name))
        print('wrote assets/' + name)
    if '--mock' in sys.argv:
        out = os.path.join(ROOT, 'docs', 'art_reference')
        os.makedirs(out, exist_ok=True)
        S = 5
        views = [up] + [down_view(k) for k in RECESS_KINDS]
        sheet = Image.new('RGBA', (W * S * len(views) + 10 * (len(views) + 1), H * S + 20), (30, 30, 34, 255))
        for i, im in enumerate(views):
            sheet.paste(im.resize((W * S, H * S), Image.NEAREST), (10 + i * (W * S + 10), 10))
        sheet.save(os.path.join(out, 'stairwell.png'))
        print('wrote docs/art_reference/stairwell.png')


if __name__ == '__main__':
    build()
