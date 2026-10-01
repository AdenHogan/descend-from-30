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


# The art is DESIGNED on the 80x115 frame (all y below are design rows, 0 = the old sprite top, world 291) but the sprite is EXT rows
# taller: the stairwell art now fills the whole opening up to the lintel (owner round 31e: the corridor's brown filler band showed
# above it — "it should be part of the stairwell area image"). Rows -EXT..-1 are that top extension; the sprite spans world
# 262..406 (80x144, centre y 334).
EXT = 29
WINDOW_TOP = -22                    # the stair hall's window runs up into the extension (a tall sash)
WINDOW_BOT = 28                     # its sill clears the top of the raised flight (STEP_TOP 40)


class _Shifted:
    """Pixel access in design coordinates: p[x, y] writes row y + EXT of the real (taller) image."""
    def __init__(self, img):
        self.a = img.load()

    def __getitem__(self, xy):
        return self.a[xy[0], xy[1] + EXT]

    def __setitem__(self, xy, c):
        if 0 <= xy[0] < W and -EXT <= xy[1] < H:
            self.a[xy[0], xy[1] + EXT] = c


def new_canvas():
    return Image.new('RGBA', (W, H + EXT), (0, 0, 0, 255))


def px(img):
    return _Shifted(img)


def dither(ramp, v, x, y, spread=0.5):
    """v in 0..len(ramp)-1 (float) -> a ramp colour, ordered-dithered between neighbours."""
    i = int(v)
    f = v - i
    t = 0.5 + ((BAYER[y % 4][x % 4] + 0.5) / 16.0 - 0.5) * spread
    return ramp[min(len(ramp) - 1, i + (1 if f > t else 0))]


def rect(p, x0, y0, x1, y1, col):
    for y in range(max(-EXT, y0), min(H, y1 + 1)):
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
    for y in range(-EXT, 109):
        p[x, y] = WOOD[1] + (255,)
        p[x + 1, y] = WOOD[0] + (255,)
        p[x - 1, y] = WOOD[2] + (255,) if y % 9 else WOOD[1] + (255,)


GLASS_RECTS = {}                    # 'up' / 'down' -> (x0, y0, x1, y1) of the glass HOLE in design coords (filled by window())
SHEEN = (255, 255, 255, 34)


def window(p, x0, y0, x1, y1, lights=1, key=None):
    """A framed stairwell window whose GLASS IS A HOLE (alpha 0): the city behind it is the game's (scripts/stair_window.gd —
    the same skyline as the apartments', by time of day, with its fires and night rain). `lights` panes side by side (mullions),
    a meeting rail across the middle, a lit sill, two faint diagonal sheen streaks on the glass."""
    rect(p, x0 - 1, y0 - 1, x1 + 1, y1 + 1, FRAME[0])
    rect(p, x0, y0, x1, y1, FRAME[1])
    gx0, gy0, gx1, gy1 = x0 + 2, y0 + 2, x1 - 2, y1 - 2
    my = (gy0 + gy1) // 2
    bars = [int(round(gx0 + (gx1 - gx0) * k / lights)) for k in range(1, lights)]
    for y in range(gy0, gy1 + 1):
        for x in range(gx0, gx1 + 1):
            if y == my or x in bars:
                p[x, y] = FRAME[1] + (255,)
            elif y == my + 1 or (x - 1) in bars:
                p[x, y] = FRAME[0] + (255,)                       # the bars' shadowed edge
            else:
                p[x, y] = (0, 0, 0, 0)                            # the hole
    for k in range(2):                                            # sheen: two short diagonal streaks per pane
        for i in range(0, 9):
            for bx0 in [gx0] + [bb + 1 for bb in bars]:
                xx, yy = bx0 + 3 + k * 4 + i, gy0 + 3 + i * 2
                if xx <= gx1 and yy <= gy1 and yy != my and xx not in bars:
                    p[xx, yy] = SHEEN
    for x in range(x0 - 1, x1 + 2):
        p[x, y1 + 1] = FRAME[2] + (255,)                          # the sill, catching light
        p[x, y1 + 2] = FRAME[0] + (255,)
    if key:
        GLASS_RECTS[key] = (gx0, gy0, gx1, gy1)


def dark_back(p, x0, x1, y0, y1, glow=None):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            v = 1.0 + (0.5 if y < -EXT + 6 else 0.0)
            if glow:
                gx, gy, gr = glow
                d = ((x - gx) ** 2 + ((y - gy) * 0.7) ** 2) ** 0.5
                v += max(0.0, 1.6 * (1 - d / gr))
            p[x, y] = dither(DARK, min(3.0, v), x, y, 0.2) + (255,)


def up_view():
    img = new_canvas()
    p = px(img)
    floor_strip(p, 0, W - 1)
    under_stairs_open(p, 0, 39, up_steps_top())
    # the shaft: dark back wall, the window high up, light spilling down toward the steps
    dark_back(p, SHAFT_X0, W - 1, -EXT, 108, glow=(59, 7, 36))
    window(p, 48, WINDOW_TOP, 69, WINDOW_BOT, key='up')
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


# ---------------------------------------------------------------- the stair hall behind the steps (owner rounds 31c / 31d)
# Through the doorway the hall shows two things besides the yellow flight: ABOVE THE LINE (the top of the yellow steps,
# `up_steps_top()`) the BACK of the flight the stair turns into — brown, its treads' backs as bands that shrink as it climbs away;
# BELOW THE LINE the space UNDER that flight, a cupboard / recess at landing level drawn in real one-point perspective (back wall,
# side walls, a ceiling, a floor, all receding to VP — the corridor camera's eye) with things in it that have tops and sides.
# Up-stair sprite: its left half is the open under-stair cupboard. Down-stair sprite: its shaft half is the recess where you step
# down (RECESS kinds, rotated by floor), its other half a closed under-stair cupboard door. Grey below, brown above, as the owner asked.
RECESS = 'cleaner'
RECESS_KINDS = ['cleaner', 'junk', 'table']   # rotated by floor (building_floors._apply_stair_visuals)
STEP_N, STEP_BOT = 12, 108
STEP_TOP = 40      # owner round 31f: the flight climbs HALFWAY up the opening (design 108 floor .. -29 top) — stair_pan.*_TURN_HEIGHT follow it
VP = (40.0, 82.0)                             # the vanishing point: the corridor camera's eye, centred on the sprite (the newel)
BROWN = [(44, 28, 16), (66, 43, 26), (90, 60, 36), (116, 80, 49), (142, 102, 64)]
GREY = [(26, 28, 30), (42, 45, 48), (60, 64, 66), (82, 86, 86), (108, 112, 110)]
RED = [(80, 14, 12), (140, 26, 20), (190, 44, 32), (226, 92, 70)]
CARD = [(92, 66, 36), (132, 98, 56), (168, 128, 76), (196, 160, 104)]
TIMBER = [(58, 38, 20), (92, 62, 32), (124, 86, 46), (150, 110, 64)]
BAG = [(10, 10, 12), (22, 22, 26), (38, 38, 44), (58, 58, 66)]
BUCKET = [(96, 84, 22), (140, 124, 34), (184, 164, 52), (218, 200, 92)]
TIN = [(52, 62, 84), (80, 94, 122), (112, 128, 156), (150, 164, 188)]
PAPER = [(118, 114, 100), (150, 146, 130), (184, 180, 164), (214, 210, 194)]
CLAY = [(84, 44, 30), (122, 68, 46), (156, 94, 64), (184, 122, 88)]


def _step_heights():
    """STEP_N risers from the floor (STEP_BOT) to STEP_TOP, each a touch shallower than the one below (the flight recedes)."""
    raw = [6.4 - 0.14 * i for i in range(STEP_N)]
    k = (STEP_BOT - STEP_TOP) / sum(raw)
    return [r * k for r in raw]


def up_steps_top() -> int:
    """Sprite-y of the top edge of the yellow up-stairs — THE line: the stair back sits above it, the cupboards below it."""
    return int(round(STEP_BOT - sum(_step_heights())))


def shade(c, k):
    return (max(0, min(255, int(c[0] * k))), max(0, min(255, int(c[1] * k))), max(0, min(255, int(c[2] * k))))


def fill_poly(p, pts, fn):
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).polygon([(float(a), float(b)) for a, b in pts], fill=255)
    mp = m.load()
    xs = [q[0] for q in pts]
    ys = [q[1] for q in pts]
    for y in range(max(0, int(min(ys)) - 1), min(H, int(max(ys)) + 2)):
        for x in range(max(0, int(min(xs)) - 1), min(W, int(max(xs)) + 2)):
            if mp[x, y]:
                c = fn(x, y) if callable(fn) else fn
                if c is not None:
                    p[x, y] = tuple(c[:3]) + (255,)


def line(p, a, b, col):
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).line([a, b], fill=255, width=1)
    mp = m.load()
    for y in range(H):
        for x in range(W):
            if mp[x, y]:
                p[x, y] = tuple(col[:3]) + (255,)


def back_of_flight(p, x0, x1, line_y):
    """The back of the flight above, seen from the landing: brown timber, a band per tread (the nearest, lowest, biggest), stringer
    boards at both sides, the lowest edge catching the light and a hard shadow under it — that edge ON the line."""
    hs = [max(1.8, 8.2 - 0.62 * i) for i in range(STEP_N + 12)]   # on up into the extension, the treads ever thinner
    y = float(line_y)
    bands = []
    for hgt in hs:
        if y - hgt < -EXT:
            break
        top = y - hgt
        bands.append((int(round(top)), int(round(y))))
        y = top
    for x in range(x0, x1 + 1):
        for yy in range(-EXT, line_y + 1):
            p[x, yy] = dither(BROWN, max(0.0, 0.9 + 1.4 * (yy / max(1, line_y))), x, yy, 0.06) + (255,)
    for (t, bt) in bands:
        for x in range(x0, x1 + 1):
            if -EXT <= t < H:
                p[x, t] = dither(BROWN, max(1.5, 3.0 + 0.8 * (bt / max(1, line_y))), x, t, 0.0) + (255,)
            if -EXT <= t + 1 < H:
                p[x, t + 1] = BROWN[0] + (255,)
    for yy in range(-EXT, line_y + 1):
        for x in (x0, x0 + 1):
            p[x, yy] = BROWN[0] + (255,)
        for x in (x1 - 1, x1):
            p[x, yy] = BROWN[1] + (255,)
    for x in range(x0, x1 + 1):
        p[x, line_y] = BROWN[4] + (255,)
        p[x, line_y + 1] = (16, 12, 8, 255)
        p[x, line_y + 2] = (24, 20, 16, 255)


class Space:
    """A box-shaped space behind an opening (x0..x1, y0..y1) in one-point perspective toward VP; k = how far the back face shrinks.
    m(u, v, t) maps u across (0 left .. 1 right), v up (0 floor .. 1 the opening's top), t into the depth (0 the opening .. 1 the back)."""
    def __init__(self, x0, y0, x1, y1, k=0.6):
        self.x0, self.y0, self.x1, self.y1, self.k = x0, y0, x1, y1, k

    def m(self, u, v, t):
        fx = self.x0 + u * (self.x1 - self.x0)
        fy = self.y1 - v * (self.y1 - self.y0)
        s = 1.0 - (1.0 - self.k) * t
        return (VP[0] + (fx - VP[0]) * s, VP[1] + (fy - VP[1]) * s)


def draw_space(p, sp, lit=1.0):
    """Back wall, ceiling (the stair's underside — darkest), side walls and floor, each shaded by depth: brighter toward the
    opening (the corridor's light comes in through it), darker toward the back."""
    m = sp.m
    fill_poly(p, [m(0, 1, 1), m(1, 1, 1), m(1, 0, 1), m(0, 0, 1)], lambda x, y: dither(GREY, 1.0 * lit, x, y, 0.2))
    fill_poly(p, [m(0, 1, 0), m(1, 1, 0), m(1, 1, 1), m(0, 1, 1)], lambda x, y: dither(GREY, 0.35 * lit, x, y, 0.2))
    for side in (0, 1):
        a, b = m(side, 0, 0), m(side, 0, 1)
        def wall_fn(x, y, a=a, b=b):
            t = (x - a[0]) / (b[0] - a[0]) if abs(b[0] - a[0]) > 0.01 else 0.5
            return dither(GREY, (2.1 - 1.2 * max(0.0, min(1.0, t))) * lit, x, y, 0.2)
        fill_poly(p, [m(side, 1, 0), m(side, 1, 1), m(side, 0, 1), m(side, 0, 0)], wall_fn)
    fy0, fy1 = m(0, 0, 0)[1], m(0, 0, 1)[1]
    def floor_fn(x, y):
        t = (fy0 - y) / max(0.01, fy0 - fy1)
        return dither(GREY, (2.9 - 1.6 * max(0.0, min(1.0, t))) * lit, x, y, 0.2)
    fill_poly(p, [m(0, 0, 0), m(1, 0, 0), m(1, 0, 1), m(0, 0, 1)], floor_fn)
    # skirting along the back
    line(p, m(0, 0.06, 1), m(1, 0.06, 1), GREY[0])


def cuboid(p, sp, u0, u1, v0, v1, t0, t1, ramp, outline=True):
    """A box standing in the space: its front face, its top (seen from above while below the eye) and the side facing the eye."""
    m = sp.m
    n = len(ramp) - 1
    side_u = u0 if (m(u0, v0, t0)[0] + m(u1, v0, t0)[0]) / 2 > VP[0] else u1
    fill_poly(p, [m(side_u, v0, t0), m(side_u, v1, t0), m(side_u, v1, t1), m(side_u, v0, t1)], ramp[max(0, n - 3)])
    if m(u0, v1, t0)[1] > VP[1]:
        fill_poly(p, [m(u0, v1, t0), m(u1, v1, t0), m(u1, v1, t1), m(u0, v1, t1)], ramp[n])
    fill_poly(p, [m(u0, v0, t0), m(u1, v0, t0), m(u1, v1, t0), m(u0, v1, t0)], lambda x, y: dither(ramp, n - 1.4, x, y, 0.06))
    if outline:
        for a, b in [((u0, v0), (u1, v0)), ((u0, v1), (u1, v1)), ((u0, v0), (u0, v1)), ((u1, v0), (u1, v1))]:
            line(p, m(a[0], a[1], t0), m(b[0], b[1], t0), shade(ramp[0], 0.7))


def cylinder(p, sp, u0, u1, v0, v1, t, ramp, rim=None):
    """A round thing standing in the space (bucket, tin, pot): a shaded body and an elliptical top seen from above."""
    m = sp.m
    a, b = m(u0, v0, t), m(u1, v1, t)
    xl, xr, yb, yt = a[0], b[0], a[1], b[1]
    depth = abs(m(u0, v1, t)[1] - m(u0, v1, t + 0.18)[1]) + 1.2
    n = len(ramp) - 1
    def body(x, y):
        k = (x - xl) / max(1.0, xr - xl)
        return dither(ramp, max(0.0, min(n, n - 0.6 - 2.2 * abs(k - 0.35))), x, y, 0.1)
    fill_poly(p, [(xl, yt), (xr, yt), (xr, yb), (xl, yb)], body)
    m2 = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m2).ellipse([xl, yb - depth / 2, xr, yb + depth / 2], fill=255)
    m3 = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m3).ellipse([xl, yt - depth / 2, xr, yt + depth / 2], fill=255)
    q2, q3 = m2.load(), m3.load()
    for y in range(H):
        for x in range(W):
            if q2[x, y] and y > yb:
                p[x, y] = body(x, y) + (255,)
            if q3[x, y]:
                p[x, y] = (rim or ramp[n]) + (255,)
    m4 = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m4).ellipse([xl + 1.2, yt - depth / 2 + 0.8, xr - 1.2, yt + depth / 2 - 0.4], fill=255)
    q4 = m4.load()
    for y in range(H):
        for x in range(W):
            if q4[x, y]:
                p[x, y] = ramp[max(0, n - 3)] + (255,)


def contact_shadow(p, sp, u0, u1, t):
    a, b = sp.m(u0, 0, t), sp.m(u1, 0, t)
    for x in range(int(a[0]) - 1, int(b[0]) + 2):
        y = int(round(a[1]))
        if 0 <= x < W and 0 <= y < H:
            c = p[x, y]
            p[x, y] = shade(c, 0.5) + (255,)


def props(p, sp, kind):
    m = sp.m
    if kind == 'cleaner':
        # a folded yellow wet-floor sign (an A-frame: its front panel and the edge of the back one), a mop bucket with its wringer,
        # the mop leaning back against the back wall
        t0, t1 = 0.25, 0.55
        fill_poly(p, [m(0.08, 0, t0), m(0.34, 0, t0), m(0.26, 0.52, t0 + 0.12), m(0.16, 0.52, t0 + 0.12)], lambda x, y: dither(BUCKET, 2.4, x, y, 0.2))
        fill_poly(p, [m(0.34, 0, t0), m(0.34, 0, t1), m(0.26, 0.52, t0 + 0.12)], BUCKET[0])
        line(p, m(0.12, 0.22, t0 + 0.05), m(0.3, 0.22, t0 + 0.05), (30, 26, 8))
        contact_shadow(p, sp, 0.08, 0.34, t0)
        cylinder(p, sp, 0.5, 0.82, 0, 0.3, 0.3, BUCKET)
        cuboid(p, sp, 0.55, 0.77, 0.3, 0.4, 0.3, 0.45, [(40, 44, 48), (70, 76, 82), (100, 108, 114), (140, 148, 154)])
        line(p, m(0.74, 0.35, 0.33), m(0.92, 0.95, 0.95), TIMBER[3])
        contact_shadow(p, sp, 0.5, 0.82, 0.3)
    elif kind == 'junk':
        cuboid(p, sp, 0.05, 0.47, 0, 0.42, 0.18, 0.62, CARD)
        cuboid(p, sp, 0.12, 0.40, 0.42, 0.7, 0.28, 0.55, CARD)
        line(p, m(0.26, 0.0, 0.18), m(0.26, 0.42, 0.18), (196, 176, 130))
        line(p, m(0.12, 0.56, 0.28), m(0.40, 0.56, 0.28), (196, 176, 130))
        contact_shadow(p, sp, 0.05, 0.47, 0.18)
        cuboid(p, sp, 0.55, 0.94, 0, 0.12, 0.08, 0.4, PAPER)
        line(p, m(0.74, 0.0, 0.08), m(0.74, 0.12, 0.08), (60, 56, 50))
        cylinder(p, sp, 0.62, 0.84, 0.12, 0.3, 0.2, TIN, rim=(170, 176, 186))
        contact_shadow(p, sp, 0.55, 0.94, 0.08)
    elif kind == 'table':
        # a small side table (a slab top with its front edge + four legs in perspective), a dead plant in a pot on it; a bin bag
        for (u, t) in [(0.12, 0.6), (0.54, 0.6), (0.12, 0.2), (0.54, 0.2)]:
            line(p, m(u, 0, t), m(u, 0.4, t), TIMBER[0] if t > 0.4 else TIMBER[1])
            line(p, m(u + 0.03, 0, t), m(u + 0.03, 0.4, t), TIMBER[0])
        cuboid(p, sp, 0.08, 0.6, 0.4, 0.46, 0.18, 0.62, TIMBER)
        cylinder(p, sp, 0.26, 0.42, 0.46, 0.62, 0.36, CLAY)
        for (du, dv) in [(-0.04, 0.2), (0.0, 0.3), (0.05, 0.24), (0.02, 0.36), (-0.02, 0.33)]:
            q = m(0.34 + du, 0.62 + dv, 0.38)
            if 0 <= int(q[0]) < W and 0 <= int(q[1]) < H:
                p[int(q[0]), int(q[1])] = (96, 84, 46, 255)
        a, b = m(0.64, 0, 0.22), m(0.94, 0.36, 0.22)
        fill_poly(p, [(a[0] + 1, a[1]), (b[0], a[1]), (b[0] + 1, (a[1] + b[1]) / 2), (b[0] - 3, b[1] + 1), (a[0] + 3, b[1] + 1), (a[0], (a[1] + b[1]) / 2)],
                  lambda x, y: dither(BAG, 2.6 - 2.0 * ((x - a[0]) / max(1.0, b[0] - a[0])), x, y, 0.3))
        q = m(0.79, 0.42, 0.24)
        fill_poly(p, [(q[0] - 1, q[1] + 2), (q[0] + 1, q[1] + 2), (q[0], q[1] - 1)], BAG[3])
        contact_shadow(p, sp, 0.64, 0.94, 0.22)
    elif kind == 'cupboard':
        # what's kept under the stairs: a stepladder folded against the side wall, a stack of boxes, a broom leaning on the back
        cuboid(p, sp, 0.42, 0.86, 0, 0.36, 0.3, 0.75, CARD)
        cuboid(p, sp, 0.48, 0.80, 0.36, 0.6, 0.38, 0.68, CARD)
        line(p, m(0.64, 0.0, 0.3), m(0.64, 0.36, 0.3), (196, 176, 130))
        contact_shadow(p, sp, 0.42, 0.86, 0.3)
        line(p, m(0.12, 0.0, 0.25), m(0.2, 0.92, 0.85), TIMBER[3])
        fill_poly(p, [m(0.06, 0.0, 0.22), m(0.2, 0.0, 0.22), m(0.18, 0.14, 0.26), m(0.09, 0.14, 0.26)], lambda x, y: dither(TIMBER, 1.6, x, y, 0.4))


def frame(p, sp, col_light, col_dark):
    """The opening's own edge: a thin casing so the cupboard reads as a hole in the wall with depth behind it."""
    x0, y0, x1, y1 = sp.x0, sp.y0, sp.x1, sp.y1
    for x in range(int(x0) - 1, int(x1) + 2):
        if 0 <= int(y0) - 1 < H and 0 <= x < W:
            p[x, int(y0) - 1] = col_light + (255,)
    for y in range(int(y0) - 1, int(y1) + 1):
        for x in (int(x0) - 1, int(x1) + 1):
            if 0 <= x < W and 0 <= y < H:
                p[x, y] = col_light + (255,)


def cupboard_door(p, x0, y0, x1, y1):
    """A closed cupboard door under the stairs, set back in its frame: the reveal (the frame's depth) on the side toward the eye
    and under the lintel, a two-panel painted door with a brass knob, a dark gap at the floor."""
    sp = Space(x0, y0, x1, y1, k=0.9)
    m = sp.m
    # reveals: the frame's inner faces (top: we're below the lintel; side: the one facing VP)
    fill_poly(p, [m(0, 1, 0), m(1, 1, 0), m(1, 1, 1), m(0, 1, 1)], GREY[0])
    side = 0 if (x0 + x1) / 2 > VP[0] else 1
    fill_poly(p, [m(side, 1, 0), m(side, 1, 1), m(side, 0, 1), m(side, 0, 0)], GREY[1])
    a, b = m(0, 1, 1), m(1, 0, 1)
    dx0, dy0, dx1, dy1 = a[0], a[1], b[0], b[1]
    fill_poly(p, [(dx0, dy0), (dx1, dy0), (dx1, dy1), (dx0, dy1)], lambda x, y: dither(GREY, 2.6 - 0.6 * (x - dx0) / max(1.0, dx1 - dx0), x, y, 0.2))
    for (py0, py1) in [(dy0 + 3, dy0 + (dy1 - dy0) * 0.45), (dy0 + (dy1 - dy0) * 0.52, dy1 - 4)]:
        fill_poly(p, [(dx0 + 3, py0), (dx1 - 3, py0), (dx1 - 3, py1), (dx0 + 3, py1)], lambda x, y: dither(GREY, 2.1, x, y, 0.2))
        line(p, (dx0 + 3, py0), (dx1 - 3, py0), GREY[1])
        line(p, (dx0 + 3, py0), (dx0 + 3, py1), GREY[1])
        line(p, (dx0 + 3, py1), (dx1 - 3, py1), GREY[4])
        line(p, (dx1 - 3, py0), (dx1 - 3, py1), GREY[4])
    knob = (int(dx1 - 4), int(dy0 + (dy1 - dy0) * 0.5))
    p[knob[0], knob[1]] = (214, 176, 90, 255)
    p[knob[0], knob[1] + 1] = (130, 100, 40, 255)
    line(p, (dx0, dy1), (dx1, dy1), (14, 14, 16))
    frame(p, sp, GREY[3], GREY[0])


def under_stairs_open(p, x0, x1, line_y, kind='cupboard'):
    """The up-stair's other half: the stair back above the line, an OPEN cupboard under it (its door swung out flat against the
    wall beside the opening, seen edge-on), with what's kept there."""
    back_of_flight(p, x0, x1, line_y)
    for y in range(line_y + 3, STEP_BOT):
        for x in range(x0, x1 + 1):
            p[x, y] = dither(GREY, 1.4, x, y, 0.2) + (255,)
    sp = Space(x0 + 6, line_y + 5, x1 - 3, STEP_BOT - 1, k=0.6)
    draw_space(p, sp)
    props(p, sp, kind)
    frame(p, sp, GREY[3], GREY[0])
    fill_poly(p, [(x0 + 1, line_y + 5), (x0 + 4, line_y + 6), (x0 + 4, STEP_BOT - 1), (x0 + 1, STEP_BOT)], lambda x, y: dither(GREY, 2.4 if x < x0 + 3 else 1.2, x, y, 0.2))


RAIL_Y = 66                         # DOWN: the half-wall's capping rail (sprite y of its top) — stair_pan.VAULT_RAIL_TOP = 291 + RAIL_Y
                                    # (owner round 31h: "a bit higher… strange for a bannister to be that low" — was 76)
FAR_EDGE = RAIL_Y - 10              # the far landing's edge across the well, seen over the wall


def well(p, x0, x1, y0, y1):
    """The open stairwell behind the banister: the same dark shaft wall as the UP stair's, lit round the window above, falling away
    to black below this floor's landing (the far side's floor line, FAR_EDGE) — the drop you'd jump."""
    dark_back(p, x0, x1, y0, y1, glow=(40, 8, 54))               # the wide window's light across the whole well
    for y in range(FAR_EDGE + 1, y1 + 1):
        for x in range(x0, x1 + 1):
            t = (y - FAR_EDGE - 1) / max(1.0, y1 - FAR_EDGE - 1)
            p[x, y] = dither(DARK, max(0.0, 1.1 - 1.3 * t), x, y, 0.3) + (255,)
    for x in range(x0, x1 + 1):                                    # the far side's landing edge, catching the window light
        p[x, FAR_EDGE] = dither(PLASTER, 1.2, x, FAR_EDGE, 0.2) + (255,)
        p[x, FAR_EDGE + 1] = PLASTER[0] + (255,)


def banister(p, x0, x1):
    """A solid half-wall across the open well (owner round 31g: the spindle banister "looks like a baby gate… try making it a wall"):
    a plastered knee wall the height of a banister, a timber capping rail along its top (its front face lit, a shadow line under the
    overhang — the eye is just below it), a sunk panel picked out by a moulding, a skirting board, and the landing slab's cut edge
    beneath. The cap's top is RAIL_Y — what the vault climbs onto (stair_pan.VAULT_RAIL_TOP)."""
    top = RAIL_Y + 4
    for y in range(top, 101):                                      # the wall face: lit from the window above-left
        for x in range(x0, x1 + 1):
            v = 2.3 - 0.9 * (x - x0) / max(1, x1 - x0) - 0.9 * (y - top) / 26.0
            p[x, y] = dither(PLASTER, max(0.3, min(3.0, v)), x, y, 0.15) + (255,)
    for x in range(x0, x1 + 1):                                    # the cap's shadow on the wall just under the overhang
        p[x, top] = dither(PLASTER, 0.2, x, top, 0.2) + (255,)
    # a sunk panel: shadowed top + left edges, lit bottom + right (light from the upper left)
    px0, py0, px1, py1 = x0 + 4, top + 4, x1 - 6, 96
    for x in range(px0, px1 + 1):
        p[x, py0] = PLASTER[0] + (255,)
        p[x, py1] = PLASTER[3] + (255,)
    for y in range(py0, py1 + 1):
        p[px0, y] = PLASTER[0] + (255,)
        p[px1, y] = PLASTER[3] + (255,)
    for x in range(px0 + 1, px1):                                  # the panel's field sits a shade back
        for y in range(py0 + 1, py1):
            c = p[x, y]
            p[x, y] = shade(c[:3], 0.9) + (255,)
    for (cx, cy) in ((px0 + 9, py0 + 6), (px0 + 10, py0 + 7), (px1 - 7, py1 - 3)):   # wear: scuffs + a hairline crack
        p[cx, cy] = PLASTER[0] + (255,)
    for x in range(x0, x1 + 1):
        p[x, RAIL_Y] = TIMBER[3] + (255,)                         # the capping rail: lit top edge, front face, underside
        p[x, RAIL_Y + 1] = TIMBER[2] + (255,)
        p[x, RAIL_Y + 2] = TIMBER[1] + (255,)
        p[x, RAIL_Y + 3] = TIMBER[0] + (255,)
        for y in range(101, 105):                                  # skirting
            p[x, y] = (TIMBER[1] if y == 101 else TIMBER[0]) + (255,)
        for y in range(105, 108):                                  # the landing slab's cut edge, facing us
            p[x, y] = dither(GREY, 2.6 - (y - 105) * 0.8, x, y, 0.2) + (255,)
    for y in range(RAIL_Y, 105):                                   # the wall's return against the hall's side wall
        p[x1, y] = PLASTER[0] + (255,)
        p[x1 - 1, y] = shade(p[x1 - 1, y][:3], 0.8) + (255,)


def way_down(p, x0, x1, y0, y1):
    """The DOWN shaft below the stair back: the dark where the flight drops away, a faint light coming up from the landing below
    (brightest just behind the lip). Only the first step (the lip) is drawn; the flight itself never is."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            t = (y - y0) / max(1.0, y1 - y0)
            v = 0.1 + 2.9 * t ** 3.0 + 0.5 * max(0.0, 1 - abs(x - (x0 + x1) / 2) / 20.0) * t ** 2
            p[x, y] = (dither(DARK, min(3.0, v), x, y, 0.35) if v < 2.8 else dither(FAR, min(1.6, v - 2.8), x, y, 0.35)) + (255,)
    for y in range(y0, y1 + 1):                                   # the shaft's side wall edge, catching the up-light
        p[x0, y] = dither(DARK, 1.0 + 1.8 * ((y - y0) / max(1.0, y1 - y0)), x0, y, 0.2) + (255,)


def down_view(kind=None):
    """One dark stair hall (owner round 31f: no stair back above the DOWN stair): the far wall under the window, the far landing's
    edge at FAR_EDGE, below it the drop — on the left the way down with only its first step drawn, on the right the banister across
    the open well."""
    img = new_canvas()
    p = px(img)
    floor_strip(p, 0, W - 1)
    well(p, 1, W - 1, -EXT, 104)
    way_down(p, 1, 38, FAR_EDGE + 2, 104)
    window(p, 5, WINDOW_TOP, 74, WINDOW_BOT, lights=3, key='down')     # owner round 31j: wide, more light down the well
    banister(p, 41, W - 1)
    # the lip: the first step down, in yellow
    rect(p, 0, 105, 40, 105, YEL[0])
    rect(p, 0, 106, 40, 107, YEL[2])
    rect(p, 0, 106, 40, 106, YEL[3])
    rect(p, 0, 108, 40, 108, YEL[0])
    newel_post(p, 40, RAIL_Y - 6)
    return img


def newel_post(p, x, top):
    """The DOWN stair's newel: a real post that stops a little above the half-wall's cap (its own cap block on top), so the
    wide window behind runs clear over it."""
    for y in range(top, 109):
        p[x, y] = WOOD[1] + (255,)
        p[x + 1, y] = WOOD[0] + (255,)
        p[x - 1, y] = WOOD[2] + (255,) if y % 9 else WOOD[1] + (255,)
    for xx in range(x - 2, x + 3):
        p[xx, top - 1] = WOOD[2] + (255,)
        p[xx, top - 2] = WOOD[2] + (255,)
        p[xx, top] = WOOD[0] + (255,)


def build():
    up, down = up_view(), down_view()
    outs = {'Lobby_Left.png': up, 'Hallway_Staircase_Left.png': down,
            'Lobby_Right.png': up.transpose(Image.FLIP_LEFT_RIGHT),
            'Hallway_Staircase_Right.png': down.transpose(Image.FLIP_LEFT_RIGHT)}
    for name, im in outs.items():
        im.save(os.path.join(ROOT, 'assets', name))
        print('wrote assets/' + name)
    # the glass holes, in TEXTURE pixels of the LEFT sprites (the Right ones are mirrored) — scripts/stair_window.gd reads this
    import json
    glass = {k: [v[0], v[1] + EXT, v[2], v[3] + EXT] for k, v in GLASS_RECTS.items()}
    with open(os.path.join(ROOT, 'assets', 'stair_window.json'), 'w') as fh:
        json.dump({'w': W, 'h': H + EXT, 'glass': glass}, fh, indent=1, sort_keys=True)
    print('wrote assets/stair_window.json', glass)
    if '--mock' in sys.argv:
        out = os.path.join(ROOT, 'docs', 'art_reference')
        os.makedirs(out, exist_ok=True)
        S = 5

        def with_city(im, key, run):
            # the game's look: the run's stairwell city behind the glass hole, centred on it (scripts/stair_window.gd)
            g = {k: [v[0], v[1] + EXT, v[2], v[3] + EXT] for k, v in GLASS_RECTS.items()}[key]
            city = Image.open(os.path.join(ROOT, 'assets', 'city', 'stair_view_%d_0.png' % run)).convert('RGBA')
            cx, cy = (g[0] + g[2] + 1) // 2, (g[1] + g[3] + 1) // 2
            base = Image.new('RGBA', im.size, (0, 0, 0, 255))
            base.paste(city, (cx - city.width // 2, cy - city.height // 2), city)
            base.alpha_composite(im)
            return base
        views = [with_city(up, 'up', 1), with_city(down, 'down', 1), with_city(down, 'down', 2), with_city(down, 'down', 3)]
        sheet = Image.new('RGBA', (W * S * len(views) + 10 * (len(views) + 1), (H + EXT) * S + 20), (30, 30, 34, 255))
        for i, im in enumerate(views):
            sheet.paste(im.resize((W * S, (H + EXT) * S), Image.NEAREST), (10 + i * (W * S + 10), 10))
        sheet.save(os.path.join(out, 'stairwell.png'))
        print('wrote docs/art_reference/stairwell.png')


if __name__ == '__main__':
    build()
