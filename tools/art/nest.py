"""BREACH-ROOM STORIES + THE DEAD IN ORDINARY FLATS (owner rounds 21b / 21c).

A breached flat reads as ONE event (21b: "logical and immersive… considering the storytelling"),
kept SHORT (21c: "we don't need a corpse to have dragged itself across all three modules"):
  DOOR     (the front door's room): the door came in (splinters), the resident ran — their keys dropped
           by the door, a shoe, a spilt bag — and the dead came in after them (bare bloody prints).
  KILL     (the next room, where they got to): a hand on the wall that slid to the skirting, a pool at
           its foot, one arc of spatter, a drag of a few steps, and the dead where it stopped — two
           laid against the back wall where there's room, else one on the floor; a bone or two, rags.
  DOORKILL (both in the door's own room): the flight by the door, caught further in.
The third room is left alone. No words in blood, nothing growing out of the ceiling, no scattered gore.
  CORPSE   (an ORDINARY flat, now and then — 21c "sporadically there should be bodies across the
           building"): one of the dead where they fell, a dried stain, flies. No story needed.
           Round 22 ("sometimes… our enemies dead nearby… that neighbour fought and killed one but died
           of their wounds"): about half the time one of THEM lies near — the standard zombie's own
           death pose, its head knocked off — and whatever the resident fought with lies by their hand.
  RISE     (round 22 — "watch some of them get up… like our neighbour in the tutorial"): the same
           story WITHOUT the body: a real zombie lies there instead (room.gd, the riser) and gets up
           as the player comes close. Its spot is recorded in the meta ("riser": [feet x, floor y, s]).

For every room-module variant pixlib.finish_module calls write(), which renders
assets/rooms/<name>_nest_<role>.png for the eight roles (door / kill / doorkill / corpse × l/r; _l =
the front door on the LEFT, so the story runs left → right — for a corpse it's just which way the head
lies) and records where flies gather (over the pool, the dead) in assets/rooms/nest_meta.json.
room.gd picks the roles (breach_nest_roles / WorldState.apartment_corpse_slot). Every mark knows the
module's own layout (bare wall / bare floor / furniture masks from the art), so a trail passes BEHIND
a table and a handprint never lands on a picture; the dead are the purchased homeless-character pack's
Death frame at the actors' 2x scale.
"""
import json
import math
import os
import random
import zlib

from PIL import Image

W, H, SEAM = 320, 144, 100
LANE_Y = 129                     # the walking line (world 353 − the module's top 224): the trail's line
ROLES = ('door_l', 'kill_l', 'doorkill_l', 'corpse_l', 'rise_l', 'door_r', 'kill_r', 'doorkill_r', 'corpse_r', 'rise_r')

BLOOD = (112, 12, 14, 255)
BLOOD_DK = (70, 8, 8, 255)
BLOOD_DRY = (100, 22, 18, 255)
BLOOD_OLD = (72, 20, 16, 255)
BONE = (186, 174, 148, 255)
BONE_DK = (134, 120, 96, 255)
SKIN = (124, 128, 102, 255)
SKIN_DK = (86, 92, 70, 255)
HAIR = (40, 30, 24, 255)
RAGS = [(70, 78, 96, 255), (96, 84, 66, 255), (80, 64, 70, 255), (110, 106, 96, 255), (58, 70, 60, 255)]
SPLINTER = [(112, 84, 56, 255), (86, 62, 40, 255), (150, 118, 80, 255)]
WASH = {'door': (14, 6, 5, 16), 'kill': (12, 5, 4, 40), 'doorkill': (12, 5, 4, 32), 'corpse': (0, 0, 0, 0), 'rise': (0, 0, 0, 0)}


class Layer:
    def __init__(self):
        self.img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        self.px = self.img.load()

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = c

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                if ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / max(ry, 0.5)) ** 2 <= 1.0:
                    self.put(x, y, c)


def _masks(full, bare_floor, flat_pieces=None):
    fp, bp = full.load(), bare_floor.load()
    bare = [[fp[x, y] == bp[x, y] for y in range(H)] for x in range(W)]
    # FLAT = bare floor, or art lying flat ON the floor (a rug): a run of non-bare pixels down a column
    # that starts well below the seam, stays short and doesn't join anything standing up — so a drag
    # trail crosses a rug but passes behind a sofa, a table leg or a bath
    flat = [col[:] for col in bare]
    clear = [col[:] for col in bare]
    for x in range(W):
        y = SEAM
        while y < H:
            if bare[x][y]:
                y += 1
                continue
            y0 = y
            while y < H and not bare[x][y]:
                y += 1
            if y0 >= SEAM + 6 and y - y0 <= 24 and bare[x][y0 - 1]:
                for yy in range(y0, y):
                    flat[x][yy] = True
                    if y - y0 <= 5:                 # a shadow / a rug's edge — not a thing lying there
                        clear[x][yy] = True
    # rugs etc. registered by the art (pixlib.flat_piece): flat wherever they still show in the finished
    # art — a sofa drawn on the rug covers those pixels, so it stays upright
    # CLEAR = bare floor, a registered rug, or a short run (a shadow) — where the dead and dropped things
    # may go (round 22: a guitar lying on the floor is a longer run too, and a body was laid over it)
    for (x, y), col in (flat_pieces or {}).items():
        if y >= SEAM and fp[x, y] == col:
            flat[x][y] = True
            clear[x][y] = True
    return bare, flat, clear


# ---------------------------------------------------------------------------------------- the marks

def _handprint(L, x, y, s, rng, col=BLOOD):
    # a palm with four fingers up and a thumb out to the side `s` points away from
    for (dx, dy) in ((0, 3), (1, 3), (2, 3), (3, 3), (0, 4), (1, 4), (2, 4), (3, 4), (1, 5), (2, 5),
                     (0, 0), (0, 1), (1, -1), (1, 0), (2, -1), (2, 0), (3, 0), (3, 1), (0, 2), (3, 2)):
        if rng.random() < 0.88:
            L.put(x + dx, y + dy, col)
    L.put(x + (4 if s > 0 else -1), y + 2, col)
    L.put(x + (5 if s > 0 else -2), y + 1, col)


def _slide_down(L, rng, x, y0, y1):
    # the hand that slid down the wall to the skirting: palm-wide at the top, breaking into finger
    # lines, thinning as the blood ran out
    n = max(1, y1 - y0)
    for d in range(n):
        f = d / n
        for w in range(5):
            if f < 0.5:
                ok = rng.random() < 0.92 - f * 0.6
                col = BLOOD_DRY if w in (0, 4) else BLOOD_DK
            else:
                ok = w != 2 and rng.random() < 1.05 - f
                col = BLOOD_DRY
            if ok:
                L.put(x + w + int(0.12 * d * math.sin(d * 0.2)), y0 + d, col)


def _spatter(L, rng, ox, oy, s):
    # ONE arc of it, low on the wall, thrown the way the struggle went — a few runs off the bigger drops
    ang0 = -math.pi / 2 - s * rng.uniform(0.3, 0.9)
    for k in range(rng.randint(16, 26)):
        t = rng.random() ** 0.8
        a = ang0 + rng.gauss(0, 0.35)
        r = 4 + 22 * t
        x, y = ox + math.cos(a) * r, oy + math.sin(a) * r * 0.7
        size = 2 if t < 0.25 else 1
        for dx in range(size):
            for dy in range(size):
                L.put(x + dx, y + dy, BLOOD_DK)
        if size == 2 and rng.random() < 0.4:
            for d in range(rng.randint(2, 7)):
                L.put(x, y + 2 + d, BLOOD_DRY)


def _pool(L, rng, cx, cy, big=1.0):
    # a pool that has dried at its rim — flattened by the floor's perspective, glossy only at the heart
    blobs = [(cx + rng.randint(-5, 5), cy + rng.randint(-1, 1), rng.uniform(4, 9) * big) for _ in range(rng.randint(2, 3))]
    for (bx, by, r) in blobs:
        L.ellipse(bx, by, r, r * 0.32, BLOOD_OLD)
    for (bx, by, r) in blobs:
        L.ellipse(bx, by, r * 0.72, r * 0.22, BLOOD_DK)
    bx, by, r = blobs[0]
    for x in range(int(bx - r * 0.35), int(bx + r * 0.05)):
        L.put(x, by - 1, BLOOD)


def _trail(L, rng, pts):
    # the drag: a smear one body wide, laid down in STREAKS along the way it went (each row stays on or
    # off for a stretch, so it reads as dragged, not dotted), heavier at the heart, thinning at the rims
    rows = list(range(-3, 4))
    on = {w: True for w in rows}
    for i, (x, y) in enumerate(pts):
        for w in rows:
            edge = abs(w) == 3
            p_off = 0.10 if edge else (0.04 if abs(w) == 2 else 0.015)
            p_on = 0.10 if edge else 0.30
            on[w] = (rng.random() > p_off) if on[w] else (rng.random() < p_on)
            if on[w] and not (edge and i % 3 == 0):
                col = BLOOD_OLD if abs(w) >= 2 else (BLOOD_DRY if w else BLOOD_DK)
                L.put(x, y + w, col)
        if i % 11 == 0 and rng.random() < 0.3:                          # a darker clot where it stalled
            L.put(x, y, BLOOD_DK); L.put(x, y - 1, BLOOD_DK)


def _path(rng, x0, y0, x1, y1):
    # a gently wandering line from (x0,y0) to (x1,y1), one point per column
    step = 1 if x1 >= x0 else -1
    n = abs(x1 - x0)
    ph, amp = rng.uniform(0, 6.3), rng.uniform(0.8, 2.2)
    out = []
    for i in range(n + 1):
        t = i / max(1, n)
        y = y0 + (y1 - y0) * (t * t * (3 - 2 * t)) + amp * math.sin(ph + i * 0.045) * math.sin(math.pi * t)
        out.append((x0 + i * step, int(round(y))))
    return out


def _claw_hand(L, rng, x, y, s):
    # a hand pressed flat to the floor while being dragged, its nails scoring streaks back the way
    # they'd come (s = the way the trail runs)
    _handprint(L, x, y - 2, -s, rng, BLOOD_DK)
    for f in range(4):
        for d in range(rng.randint(5, 10)):
            L.put(x + f - s * (2 + d), y - 2 + f // 2, BLOOD_DRY if d > 2 else BLOOD_DK)


def _footprint(L, rng, x, y, s, fade):
    # a bare, smudged foot — heel, sole, toes pointing the way it walked
    if rng.random() < fade * 0.5:
        return
    for (dx, dy) in ((0, 0), (1, 0), (2, 0), (3, 1), (4, 1), (5, 0)):
        if rng.random() < 0.85 - fade * 0.5:
            L.put(x + s * dx, y + dy, BLOOD_DRY)
    for t in range(3):
        L.put(x + s * (6 + t % 2), y - 1 + t, BLOOD_OLD)


def _shoe(L, rng, x, y, s):
    _x2(L, _shoe1, x, y, s, rng)


def _shoe1(L, x, y, s, rng):
    col = rng.choice([(40, 34, 30, 255), (98, 70, 48, 255), (150, 60, 58, 255), (180, 176, 168, 255)])
    for i in range(7):
        L.put(x + s * i, y, col)
        if 1 <= i <= 4:
            L.put(x + s * i, y - 1, col)
    L.put(x + s * 5, y - 1, tuple(int(v * 0.6) for v in col[:3]) + (255,))
    L.put(x, y - 2, col); L.put(x + s, y - 2, col)                          # the heel counter
    L.put(x + s * 6, y + 1, (30, 26, 24, 255))                             # its sole


def _x2(L, fn, x, y, s, *args):
    # draw a dropped thing at the actors' 2x pixel scale (like the dead), its bottom-left on (x, y)
    T = Layer()
    fn(T, 4 if s > 0 else 36, 24, s, *args)
    box = T.img.getbbox()
    if box is None:
        return
    im = T.img.crop(box)
    im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
    ox = x if s > 0 else x - im.width + 1
    ip = im.load()
    for yy in range(im.height):
        for xx in range(im.width):
            if ip[xx, yy][3]:
                L.put(ox + xx, y - im.height + 1 + yy, ip[xx, yy])


def _keys(L, x, y):
    for (dx, dy, c) in ((0, 0, (200, 170, 70, 255)), (1, 0, (160, 130, 50, 255)), (2, 1, (200, 170, 70, 255)),
                        (3, 1, (180, 180, 186, 255)), (4, 1, (140, 140, 150, 255)), (1, -1, (90, 90, 96, 255))):
        L.put(x + dx, y + dy, c)


def _bag(L, rng, x, y, s):
    _x2(L, _bag1, x, y, s, rng)


def _bag1(L, x, y, s, rng):
    # a handbag on its side, spilt: purse, a phone face down, a lipstick, receipts
    col = rng.choice([(92, 52, 40, 255), (40, 38, 44, 255), (120, 98, 70, 255)])
    for i in range(8):
        for j in range(4):
            L.put(x + s * i, y - j, col if j else tuple(int(v * 0.7) for v in col[:3]) + (255,))
    for t in range(5):                                                       # the strap
        L.put(x + s * (1 + t), y - 5 - (1 if 0 < t < 4 else 0), col)
    things = [((22, 22, 26, 255), 3, 2), ((150, 30, 50, 255), 2, 1), ((210, 204, 190, 255), 3, 2), ((110, 80, 50, 255), 3, 2)]
    for k, (c, w_, h_) in enumerate(things):
        tx, ty = x + s * (9 + k * 3 + rng.randint(0, 1)), y - (k % 2)
        for i in range(w_):
            for j in range(h_):
                L.put(tx + s * i, ty - j, c)


def _splinters(L, rng, e, s, bare):
    # the door came in: pieces of it and plaster dust fanned across the floor just inside
    for k in range(rng.randint(14, 22)):
        x = e + s * int(abs(rng.gauss(0, 14)) + 4)
        y = rng.randint(106, 140)
        if not (0 <= x < W) or not bare[x][y]:
            continue
        c = rng.choice(SPLINTER) if rng.random() < 0.7 else (200, 190, 170, 255)
        for i in range(rng.choice((1, 2, 2, 3, 4))):
            L.put(x + s * i, y - (i // 2 if rng.random() < 0.3 else 0), c)


def _rag(L, rng, x, y):
    col = rng.choice(RAGS)
    w, h = rng.randint(4, 8), rng.randint(2, 3)
    for yy in range(h):
        for xx in range(w):
            if rng.random() < 0.85:
                L.put(x + xx + (yy % 2), y + yy, col if rng.random() < 0.85 else BLOOD_OLD)


def _bone(L, rng, x, y):
    ln = rng.randint(4, 7)
    tilt = rng.choice((-1, 0, 0, 1))
    for i in range(ln):
        L.put(x + i, y + (tilt * i) // 5, BONE if i % 3 else BONE_DK)
    L.put(x - 1, y, BONE_DK); L.put(x - 1, y - 1, BONE)
    L.put(x + ln, y + (tilt * ln) // 5, BLOOD_OLD)


def _shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)


PEOPLE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets',
                      'homeless-character-pixel-art-pack')
_DEAD = {}


def _dead_sprite(k):
    # the last frame of person k's Death strip (the purchased homeless-character pack: 6 people, 48px
    # frames) — lying on their back, head to the right — cropped, drawn at 2x like the player
    if k not in _DEAD:
        im = Image.open(os.path.join(PEOPLE, str(k), 'Death.png')).convert('RGBA')
        f = im.crop((5 * 48, 0, 6 * 48, 48))
        f = f.crop(f.getbbox())
        _DEAD[k] = f.resize((f.width * 2, f.height * 2), Image.NEAREST)
    return _DEAD[k]


def _body(L, rng, x, y, s, bitten=True):
    # one of the dead, on their back at the player's scale (a real person sprite, not a smudge): feet at
    # x, head toward s, its underside on floor row y. Greyed a little (the colour's gone out of them) and
    # stained through at the neck and chest where they were bitten — dried dark, not painted red.
    spr = _dead_sprite(rng.randint(1, 6))
    if s < 0:
        spr = spr.transpose(Image.FLIP_LEFT_RIGHT)
    w, h = spr.size
    x0 = x if s > 0 else x - w + 1
    y0 = y - h + 1
    sp = spr.load()
    bite = rng.uniform(0.66, 0.76)                                             # the neck / shoulder
    for yy in range(h):
        for xx in range(w):
            c = sp[xx, yy]
            if c[3] < 128:
                continue
            g = (c[0] + c[1] + c[2]) // 3
            c = tuple(int((v * 0.7 + g * 0.3) * 0.82) for v in c[:3]) + (255,)
            t = ((xx // 2 * 2) / w) if s > 0 else (1 - (xx // 2 * 2) / w)       # 0 at the feet, 1 at the head
            if bitten and sum(c[:3]) > 90:                                     # soaked through (not the outline)
                d = ((t - bite) / 0.12) ** 2 + (((yy // 2 * 2) - h * 0.45) / (h * 0.9)) ** 2
                if d < 1.0:
                    c = BLOOD_DK if d < 0.35 else BLOOD_OLD
            L.put(x0 + xx, y0 + yy, c)
    for xx in range(w):                                                        # its shadow on the floor
        if sp[xx, h - 1][3] >= 128 and rng.random() < 0.9:
            L.put(x0 + xx, y + 1, (26, 18, 14, 255))
    return (x0 + w // 2, y - h // 2)                                         # its middle: the search spot


def _stain(L, rng, x0, x1, y, depth=3):
    # the floor under the dead, soaked black at the heart and dried brown at the rim
    for x in range(min(x0, x1), max(x0, x1) + 1):
        for j in range(depth + 1):
            if rng.random() < 0.9 - 0.18 * j:
                L.put(x, y + j, BLOOD_OLD if j else BLOOD_DK)


def _heap(L, rng, cx, y, s):
    # the dead pulled together where they fed: one laid out along the wall, the next dragged in and
    # dropped in front of it, head to feet
    _stain(L, rng, cx - 40, cx + 40, y, 3)
    return [_body(L, rng, cx - s * 52, y - 3, s), _body(L, rng, cx + s * 52, y + 4, -s)]


ZOMBIE_DEATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'Enemies',
                            'Zombie', 'Zombie', 'Zombie - Death.png')
_ZPARTS = []
ZB_W, ZB_H = 112, 16             # a dead zombie's footprint: its body, the gap, its head (world px)


def _zombie_parts():
    # the standard zombie's last Death frame (the in-game corpse, 3x like the enemies), split into its
    # body and its head — which the death pose knocks off (so it can lie a little nearer the stump)
    if not _ZPARTS:
        im = Image.open(ZOMBIE_DEATH).convert('RGBA')
        n = im.width // im.height
        f = im.crop(((n - 1) * im.height, 0, n * im.height, im.height))
        box = f.getbbox()
        f = f.crop(box)
        a = f.load()
        cols = [x for x in range(f.width) if any(a[x, y][3] > 100 for y in range(f.height))]
        gaps = [cols[i] for i in range(1, len(cols)) if cols[i] - cols[i - 1] > 3]
        cut = gaps[0] if gaps else f.width // 3
        head = f.crop((0, 0, cut, f.height))
        body = f.crop((cut, 0, f.width, f.height))
        head, body = head.crop(head.getbbox()), body.crop(body.getbbox())
        _ZPARTS.extend([body.resize((body.width * 3, body.height * 3), Image.NEAREST),
                        head.resize((head.width * 3, head.height * 3), Image.NEAREST)])
    return _ZPARTS


def _paste(L, spr, x0, y1, dim=1.0):
    # an RGBA sprite, its bottom-left on (x0, y1)
    sp = spr.load()
    for yy in range(spr.height):
        for xx in range(spr.width):
            c = sp[xx, yy]
            if c[3] >= 128:
                L.put(x0 + xx, y1 - spr.height + 1 + yy, _shade(c, dim))


def _zombie_dead(L, rng, x, y, s):
    # one of THEM, dead: its body with the neck toward s from x, the head knocked a step further on,
    # the stump bled out dark between them. (x, y) = its far end (feet) on the floor row y.
    body, head = _zombie_parts()
    if s < 0:
        body, head = body.transpose(Image.FLIP_LEFT_RIGHT), head.transpose(Image.FLIP_LEFT_RIGHT)
    bx0 = x if s > 0 else x - body.width + 1
    neck = bx0 + body.width - 1 if s > 0 else bx0
    gap = rng.randint(6, 12)
    hx0 = neck + s * gap if s > 0 else neck - gap - head.width + 1
    hy = y + rng.randint(-2, 2)
    L.ellipse(neck + s * (gap // 2), y - 1, gap * 0.7 + 3, 2.2, BLOOD_OLD)            # bled out at the stump
    L.ellipse(neck + s * (gap // 2), y - 1, gap * 0.45 + 1, 1.3, (38, 6, 6, 255))
    _paste(L, body, bx0, y, 0.92)
    _paste(L, head, hx0, hy, 0.92)
    for xx in range(body.width):                                                   # its shadow
        if rng.random() < 0.85:
            L.put(bx0 + xx, y + 1, (26, 18, 14, 255))
    return (bx0 + body.width // 2, y - 6)


WEAPONS = ('knife', 'hammer', 'pin', 'club', 'pan', 'leg')


def _weapon(L, rng, x, y, s, kind):
    # what the resident fought with, dropped by their hand: 2x, bloodied at the business end
    _x2(L, _weapon1, x, y, s, rng, kind)


def _weapon1(L, x, y, s, rng, kind):
    steel, dark, wood = (176, 180, 186, 255), (70, 70, 76, 255), (120, 82, 50, 255)
    def run(n, col, dy=0, x0=0):
        for i in range(n):
            L.put(x + s * (x0 + i), y + dy, col)
    if kind == 'knife':
        run(4, (40, 32, 28, 255)); run(7, steel, 0, 4); run(5, dark, 1, 4)
        L.put(x + s * 10, y, BLOOD); L.put(x + s * 9, y, BLOOD_DK); L.put(x + s * 8, y + 1, BLOOD_DK)
    elif kind == 'hammer':
        run(9, wood); run(9, (90, 60, 36, 255), 1)
        for j in range(-2, 3):
            L.put(x + s * 9, y + j, dark); L.put(x + s * 10, y + j, steel if j < 2 else dark)
        L.put(x + s * 10, y - 2, BLOOD); L.put(x + s * 9, y + 2, BLOOD_DK)
    elif kind == 'pin':
        run(2, (150, 110, 70, 255)); run(8, (196, 160, 110, 255), 0, 2); run(8, (160, 124, 80, 255), 1, 2)
        run(2, (150, 110, 70, 255), 0, 10)
        L.put(x + s * 7, y, BLOOD); L.put(x + s * 8, y + 1, BLOOD_DK)
    elif kind == 'club':
        run(3, (30, 30, 34, 255)); run(12, (200, 200, 206, 255), 0, 3)
        run(3, (200, 200, 206, 255), -1, 15); run(3, (120, 120, 128, 255), 0, 15)
        L.put(x + s * 16, y - 1, BLOOD); L.put(x + s * 17, y, BLOOD_DK)
    elif kind == 'pan':
        run(6, (40, 40, 44, 255))
        for j in range(-2, 3):
            w = 4 - abs(j)
            for i in range(-w, w + 1):
                L.put(x + s * (10 + i), y + j, (54, 54, 60, 255) if abs(j) < 2 else dark)
        L.put(x + s * 11, y - 1, BLOOD); L.put(x + s * 12, y, BLOOD_DK)
    else:                                                              # a chair leg, broken off
        run(11, wood); run(11, (86, 58, 34, 255), 1)
        L.put(x + s * 11, y - 1, (190, 150, 100, 255)); L.put(x + s * 12, y, (190, 150, 100, 255))
        L.put(x + s * 9, y, BLOOD); L.put(x + s * 10, y + 1, BLOOD_DK)


def _fought_back(floor, obj, rng, flat, fx, fy, s, taken):
    # the one they killed, lying near them (None if there's no room). taken = rects already used.
    cands = []
    for y in range(max(SEAM + 20, fy - 12), min(H - 3, fy + 12) + 1, 2):
        for zx in range(6, W - 6, 3):
            zs = rng.choice((1, -1))
            x0, x1 = (zx, zx + ZB_W) if zs > 0 else (zx - ZB_W, zx)
            if x0 < 2 or x1 > W - 3 or not _fits(flat, x0, x1, y - ZB_H, y + 3):
                continue
            if any(not (x1 < a0 - 4 or x0 > a1 + 4 or y - ZB_H > b1 or y + 3 < b0) for (a0, b0, a1, b1) in taken):
                continue
            d = abs((x0 + x1) / 2 - (fx + s * BODY_W / 2))
            if d < 170:
                cands.append((d, zx, y, zs))
    if not cands:
        return None
    cands.sort()
    _, zx, y, zs = rng.choice(cands[:max(1, len(cands) // 3)])      # near them, not always the nearest
    return _zombie_dead(obj, rng, zx, y, zs)


# ------------------------------------------------------------------------------------------ helpers

def _bare_run(bare, x0, x1, ys):
    return all(0 <= x < W and 0 <= y < H and bare[x][y] for x in range(min(x0, x1), max(x0, x1) + 1, 2) for y in ys)


def _pick_wall_x(bare, rng, lo, hi, y0, y1, width=6):
    # an x in [lo, hi] where a hand-width of wall is bare from y0 to y1
    cands = [x for x in range(max(1, lo), min(W - width - 1, hi) + 1)
             if all(bare[x + w][y] for w in range(0, width, 2) for y in range(y0, y1 + 1, 3))]
    return rng.choice(cands) if cands else None


def _pick_floor(bare, rng, xs, ys, half=8):
    cands = [(x, y) for x in xs for y in ys if _bare_run(bare, x - half, x + half, (y - 1, y, y + 1))]
    return rng.choice(cands) if cands else None


# ------------------------------------------------------------------------------------------- render

def _flight(wall, floor, obj, rng, bare, flat, e, s):
    # the front door's room: the door came in (splinters), the resident ran (keys dropped by the door,
    # a shoe, a spilt bag) and the dead came in after them — bare bloody prints heading into the flat
    _x2(floor, lambda T, x_, y_, s_: _keys(T, x_, y_), e + s * rng.randint(8, 16), rng.randint(124, 136), s)
    spot = _pick_floor(flat, rng, list(range(min(e + s * 40, e + s * 90), max(e + s * 40, e + s * 90), 4)),
                       range(116, 138, 3), 5)
    if spot:
        _shoe(obj, rng, spot[0], spot[1], -s)
    spot = _pick_floor(flat, rng, list(range(min(e + s * 16, e + s * 70), max(e + s * 16, e + s * 70), 4)),
                       range(132, 142, 2), 22)
    if spot:
        _bag(obj, rng, spot[0], spot[1], s)
    _splinters(floor, rng, e, s, flat)
    y0 = LANE_Y + rng.choice((-4, 3))
    for k in range(rng.randint(5, 7)):
        _footprint(floor, rng, e + s * (14 + k * 15), y0 + (4 if k % 2 else -4), s, k / 7)


BODY_W, BODY_H = 74, 21          # the widest dead sprite (72x20) + a pixel: its whole footprint must be clear
RISER_W, RISER_H = 88, 12        # a real zombie lying there (enemy_zombie_standard.gd riser): feet to head; its floor footprint
FOUGHT_BACK = 0.5                # how often the resident took one of them with them


def _fits(flat, x0, x1, y0, y1):
    # every pixel of the rect is floor (or a rug): nothing standing there for a body to clip into
    return all(0 <= x < W and 0 <= y < H and flat[x][y]
               for x in range(int(min(x0, x1)), int(max(x0, x1)) + 1, 2) for y in range(int(y0), int(y1) + 1, 2))


def _one_spot(flat, rng, lo, hi, s, ys=range(112, 135, 2), width=BODY_W, height=BODY_H):   # behind the lane (129) first
    # (feet x, floor y) for ONE body lying toward s, fully clear of furniture, or None
    cands = []
    for y in ys:
        for fx in range(max(4, lo), min(W - 4, hi) + 1, 3):
            hx = fx + s * width
            if 2 <= hx <= W - 3 and _fits(flat, fx, hx, y - height, y + 2):
                cands.append((fx, y))
    return rng.choice(cands) if cands else None


def _first(fn, masks):
    # the first spot found on CLEAR floor, else on FLAT (a rug nobody registered) — so the dead lie back
    # from the walking line as before, but on bare floor wherever there's room for them
    for m in masks:
        r = fn(m)
        if r is not None:
            return r
    return None


def _heap_spot(flat, rng, lo, hi):
    # the centre of TWO laid side by side (head to feet), as far back as there's room
    cands = [(cx, y) for y in range(SEAM + 20, 126, 2) for cx in range(max(56, lo), min(W - 56, hi) + 1, 3)
             if _fits(flat, cx - 54, cx + 54, y - BODY_H - 3, y + 7)]
    if not cands:
        return None
    back = min(y for (_, y) in cands)
    near = [c for c in cands if c[1] <= back + 6]
    return rng.choice(near)


def _bleed(wall, floor, rng, bare, flat, fx, fy, s, how):
    # what the blood says about how they died, ending at their feet (fx, fy) — returns fly spots.
    #   crawl    — bitten further back and crawled here: a pool where it happened, a trail on to
    #              where they gave out, bloody hands clawing along it
    #   pool     — they didn't get up: lying in it
    #   struggle — pinned at the wall: a hand slid down it, spatter, then a few steps before they fell
    flies = []
    if how == 'crawl':
        sx = max(8, min(W - 8, fx - s * rng.randint(60, 120)))
        sy = max(SEAM + 8, min(H - 5, fy + rng.randint(-8, 6)))
        _pool(floor, rng, sx, sy, 0.9)
        pts = _path(rng, sx + s * 4, sy + 1, fx, fy - 2)
        _trail(floor, rng, pts)
        for k in range(rng.randint(2, 3)):
            i = rng.randint(len(pts) // 5, max(len(pts) // 5 + 1, len(pts) - 8))
            _claw_hand(floor, rng, pts[i][0], pts[i][1] + rng.choice((-4, 4)), s)
        flies.append((sx, sy - 4))
    elif how == 'struggle':
        wx = _pick_wall_x(bare, rng, *sorted((fx - s * 70, fx - s * 10)), 60, 98)
        if wx is not None:
            hy_ = rng.randint(58, 68)
            _handprint(wall, wx, hy_, s, rng)
            _slide_down(wall, rng, wx, hy_ + 6, SEAM - 1)
            _spatter(wall, rng, wx + 2, rng.randint(72, 86), -s)
            px, py = wx + 2, SEAM + rng.randint(5, 8)
            _pool(floor, rng, px, py, 0.8)
            _trail(floor, rng, _path(rng, px, py + 2, fx, fy - 2))
        else:
            how = 'pool'
    if how == 'pool':
        _pool(floor, rng, fx + s * rng.randint(34, 52), fy + 1, 1.8)          # spread out from under them
    return flies


def _kill(wall, floor, obj, rng, bare, masks, s, lo, hi):
    # where they were caught: a hand on the wall that slid to the skirting, a pool at its foot, one
    # arc of spatter — then a SHORT drag (a few steps) to where they lie. Returns (flies, bodies).
    spot = _first(lambda m: _heap_spot(m, rng, lo, hi), masks)
    bodies = []
    if spot is not None:
        hx, hy = spot
        bodies = _heap(obj, rng, hx, hy, s)
        body_back = hx - s * 52
    else:
        spot = (_first(lambda m: _one_spot(m, rng, lo, hi, s), masks)
                or _first(lambda m: _one_spot(m, rng, 4, W - 4, s, range(104, 142, 2)), masks))
        if spot is None:
            return [], []
        fx, hy = spot
        hx = fx + s * BODY_W // 2
        _stain(obj, rng, hx - 26, hx + 26, hy, 2)
        bodies = [_body(obj, rng, fx, hy, s)]
        body_back = fx
    # the attack: a few steps back from the body, toward the way they came
    ax = int(body_back - s * rng.randint(30, 60))
    ax = max(12, min(W - 12, ax))
    wx = _pick_wall_x(bare, rng, ax - 14, ax + 10, 60, 98)
    if wx is not None:
        hy_ = rng.randint(58, 68)
        _handprint(wall, wx, hy_, s, rng)
        _slide_down(wall, rng, wx, hy_ + 6, SEAM - 1)
        _spatter(wall, rng, wx + 2, rng.randint(74, 86), -s)
        px, py = wx + 2, SEAM + rng.randint(6, 9)
    else:
        px, py = ax, LANE_Y - rng.randint(0, 6)
    _pool(floor, rng, px, py, 1.1)
    _trail(floor, rng, _path(rng, px + s * 5, py + 2, int(body_back), hy + 1))
    if rng.random() < 0.6:                                         # clawed at the floor as they went
        mx = (px + body_back) // 2
        _claw_hand(floor, rng, int(mx), (py + hy) // 2 + rng.choice((-4, 4)), s)
    for k in range(rng.randint(1, 3)):
        _bone(floor, rng, hx + rng.randint(-40, 36), hy + rng.randint(3, 10))
    for k in range(rng.randint(1, 2)):
        _rag(floor, rng, hx + rng.randint(-44, 40), hy + rng.randint(3, 12))
    return [(hx, hy - 9), (px, py - 4)], bodies


def render(name, full, bare_floor, seed, role, flat_pieces=None):
    part, side = role.split('_')
    s = 1 if side == 'l' else -1                 # the way the story runs across the flat
    e = 0 if s > 0 else W - 1                     # the edge it comes in from (the front door, in ENTRY)
    far = W - 1 if s > 0 else 0
    rng = random.Random(zlib.crc32(('nest:%s:%s:%d' % (name, role, seed)).encode()))
    bare, flat, clear = _masks(full, bare_floor, flat_pieces)
    masks = (clear, flat)
    wall, floor, obj = Layer(), Layer(), Layer()
    flies, bodies, riser, zombies = [], [], None, []
    if part in ('door', 'doorkill'):
        _flight(wall, floor, obj, rng, bare, clear, e, s)
    if part in ('kill', 'doorkill'):
        if part == 'kill':                                  # they got this far, fleeing from the door
            lo, hi = (70, W - 40) if s > 0 else (40, W - 70)
        else:                                               # caught further in, in the door's own room
            lo, hi = (170, W - 40) if s > 0 else (40, W - 170)
        f_, b_ = _kill(wall, floor, obj, rng, bare, masks, s, lo, hi)
        flies += f_
        bodies += b_
    if part in ('corpse', 'rise'):                          # one of the dead, and how they came to be there
        how = rng.choices(('crawl', 'pool', 'struggle'), (0.4, 0.35, 0.25))[0]
        lo, hi = ((70, W - 4) if s > 0 else (4, W - 70)) if how == 'crawl' else (4, W - 4)
        if part == 'rise':                                  # a real zombie lies here: on the walking line,
            lo, hi = max(lo, 26), min(hi, W - 26)           # clear of the walls at the module's ends
            spot = (_first(lambda m: _one_spot(m, rng, lo, hi, s, range(127, 132), RISER_W, RISER_H), masks)
                    or _first(lambda m: _one_spot(m, rng, 26, W - 26, s, range(125, 134), RISER_W, RISER_H), masks)
                    or _first(lambda m: _one_spot(m, rng, 26, W - 26, s, range(112, 140, 2), RISER_W, RISER_H), masks))
        else:
            spot = (_first(lambda m: _one_spot(m, rng, lo, hi, s), masks)
                    or _first(lambda m: _one_spot(m, rng, 4, W - 4, s), masks)
                    or _first(lambda m: _one_spot(m, rng, 4, W - 4, s, range(104, 142, 2)), masks))
        if spot is not None:
            fx, fy = spot
            ln = RISER_W if part == 'rise' else BODY_W
            flies += _bleed(wall, floor, rng, bare, clear, fx, fy, s, how)
            _stain(obj, rng, fx + s * 10, fx + s * (ln - 6), fy, 2)
            if part == 'rise':
                riser = [int(fx), int(fy), s]
            else:
                bodies.append(_body(obj, rng, fx, fy, s))
            if rng.random() < 0.4:
                _rag(floor, rng, fx + s * rng.randint(-30, 70), fy + rng.randint(2, 6))
            flies.append((fx + s * ln // 2, fy - 9))
            if rng.random() < FOUGHT_BACK:                  # they took one of them with them
                x0, x1 = sorted((fx, fx + s * ln))
                wx = fx + s * rng.randint(40, 56)                # their hand, about the chest: what they fought with
                _weapon(obj, rng, wx, fy + rng.randint(4, 6), s if rng.random() < 0.5 else -s, rng.choice(WEAPONS))
                z = _first(lambda m: _fought_back(floor, obj, rng, m, fx, fy, s, [(x0, fy - BODY_H, x1, fy + 3)]), masks)
                if z is not None:
                    flies.append(z)
                    zombies.append(z)
    # composite through the masks: wall marks on bare wall only, floor marks on bare floor only
    out = Image.new('RGBA', (W, H), WASH[part])
    op = out.load()
    for layer, ok in ((wall, lambda x, y: y < SEAM and bare[x][y]),
                      (floor, lambda x, y: y >= SEAM and flat[x][y]),
                      (obj, lambda x, y: bare[x][y] if y < SEAM else flat[x][y])):
        lp = layer.px
        for y in range(H):
            for x in range(W):
                if lp[x, y][3] and ok(x, y):
                    op[x, y] = lp[x, y]
    return (out, [[int(x), int(y)] for (x, y) in flies], [[int(x), int(y)] for (x, y) in bodies], riser,
            [[int(x), int(y)] for (x, y) in zombies])


META = os.path.join('assets', 'rooms', 'nest_meta.json')


def write(name, full, bare_floor, seed, root, flat_pieces=None):
    d = os.path.join(root, 'assets', 'rooms')
    old = os.path.join(d, name + '_nest.png')                         # the round-21 single overlay
    for p in (old, old + '.import'):
        if os.path.exists(p):
            os.remove(p)
    if os.environ.get('NEST_DEBUG'):
        bare, flat, _clear = _masks(full, bare_floor, flat_pieces)
        m = Image.new('RGB', (W, H))
        for x in range(W):
            for y in range(H):
                m.putpixel((x, y), (0, 160, 0) if bare[x][y] else ((200, 200, 0) if flat[x][y] else (60, 0, 0)))
        m.resize((W * 3, H * 3)).save(os.environ['NEST_DEBUG'] + '/' + name + '_mask.png')
    meta_path = os.path.join(root, META)
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    imgs = {}
    for role in ROLES:
        img, flies, bodies, riser, zombies = render(name, full, bare_floor, seed, role, flat_pieces)
        img.save(os.path.join(d, '%s_nest_%s.png' % (name, role)))
        meta['%s_nest_%s' % (name, role)] = {'flies': flies, 'bodies': bodies}
        if riser is not None:
            meta['%s_nest_%s' % (name, role)]['riser'] = riser
        if zombies:                                                     # the one they killed (round 22)
            meta['%s_nest_%s' % (name, role)]['zombies'] = zombies
        imgs[role] = img
    with open(meta_path, 'w') as f:                                     # one line a texture, sorted
        f.write('{\n' + ',\n'.join(' %s: %s' % (json.dumps(k), json.dumps(meta[k], separators=(', ', ': ')))
                                     for k in sorted(meta)) + '\n}\n')
    return imgs


def preview(root):
    # docs/art_reference/modules/breach_nests.png: per room type, two breached flats — the door on the
    # LEFT with the story over two rooms (a = DOOR, b = KILL, c untouched), then the door on the RIGHT
    # with it all in the door's own room (c = DOORKILL). docs/.../human_dead.png: every variant's CORPSE.
    from PIL import ImageDraw
    types = ['living_room', 'bedroom', 'kitchen', 'bathroom', 'study', 'dining_room']
    rooms = os.path.join(root, 'assets', 'rooms')
    pad = 6
    sheet = Image.new('RGB', (2 * (3 * W + pad) + pad, len(types) * (H + 14) + pad), (18, 18, 20))
    d = ImageDraw.Draw(sheet)
    for r, t in enumerate(types):
        for k, roles in enumerate((['door_l', 'kill_l', None], [None, None, 'doorkill_r'])):
            for i, (v, role) in enumerate(zip(['', '_b', '_c'], roles)):
                a = Image.open(os.path.join(rooms, t + v + '.png')).convert('RGBA')
                if role:
                    a.alpha_composite(Image.open(os.path.join(rooms, '%s%s_nest_%s.png' % (t, v, role))))
                x, y = pad + k * (3 * W + pad) + i * W, pad + r * (H + 14)
                sheet.paste(a.convert('RGB'), (x, y + 12))
            d.text((pad + k * (3 * W + pad), pad + r * (H + 14)),
                   '%s - %s' % (t, 'door left: fled a room, caught in the next' if k == 0 else 'door right: caught in the door room'),
                   fill=(220, 210, 190))
    prev = os.path.join(root, 'docs', 'art_reference', 'modules')
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(os.path.join(prev, 'breach_nests.png'))
    dead = Image.new('RGB', (5 * (W + pad) + pad, len(types) * (H + pad) + pad), (18, 18, 20))
    for r, t in enumerate(types):
        for i, v in enumerate(['', '_b', '_c', '_d', '_e']):
            a = Image.open(os.path.join(rooms, t + v + '.png')).convert('RGBA')
            a.alpha_composite(Image.open(os.path.join(rooms, '%s%s_nest_corpse_%s.png' % (t, v, 'l' if i % 2 else 'r'))))
            dead.paste(a.convert('RGB'), (pad + i * (W + pad), pad + r * (H + pad)))
    dead.save(os.path.join(prev, 'human_dead.png'))
    # risers.png (round 22): every variant's RISE story with the zombie lying where the game lays it
    # (the Idle frame on its back, squashed flat like enemy_zombie_standard._riser_pose)
    meta = json.load(open(os.path.join(root, META)))
    idle = Image.open(os.path.join(os.path.dirname(ZOMBIE_DEATH), 'Zombie - Idle.png')).convert('RGBA')
    idle = idle.crop((0, 0, idle.height, idle.height))
    idle = idle.crop(idle.getbbox())
    idle = idle.resize((idle.width * 3 // 2, idle.height * 3), Image.NEAREST)
    rise = Image.new('RGB', (5 * (W + pad) + pad, len(types) * (H + pad) + pad), (18, 18, 20))
    for r, t in enumerate(types):
        for i, v in enumerate(['', '_b', '_c', '_d', '_e']):
            role = 'rise_' + ('l' if i % 2 else 'r')
            a = Image.open(os.path.join(rooms, t + v + '.png')).convert('RGBA')
            a.alpha_composite(Image.open(os.path.join(rooms, '%s%s_nest_%s.png' % (t, v, role))))
            e = meta.get('%s%s_nest_%s' % (t, v, role), {}).get('riser')
            if e:
                fx, fy, s_ = e
                g = idle.transpose(Image.FLIP_LEFT_RIGHT) if s_ > 0 else idle
                g = g.rotate(-90 if s_ > 0 else 90, expand=True)
                x0 = fx if s_ > 0 else fx - g.width + 1
                a.alpha_composite(g, (max(0, min(W - g.width, x0)), fy - g.height + 1))
            rise.paste(a.convert('RGB'), (pad + i * (W + pad), pad + r * (H + pad)))
    rise.save(os.path.join(prev, 'risers.png'))
    print('wrote breach_nests.png + human_dead.png + risers.png')


if __name__ == '__main__':
    preview(os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')))
