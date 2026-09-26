"""BREACH-ROOM NESTS — what happened here, told across the flat (owner round 21b: the first nest was
"a bit too much horror and gore… it needs to be logical and immersive… you went nuts with the red
blood paint without considering the storytelling that might have gone into what happened when that
breach occurred").

So a breached flat now reads as ONE event, left to right (or right to left) through its three rooms:
  ENTRY   (the room with the front door): they came through the door. The resident was caught by
          it — a bloody hand on the wall that slid down to the skirting, a pool on the floor at its
          foot, one arc of spatter above; what they dropped (their keys by the door, a shoe, a bag
          spilled out); splinters of the door blown in; bare, smudged footprints; and a drag trail
          starting from the pool, heading INTO the flat.
  THROUGH (the middle room): the trail crossing it, unbroken, along the walking line — where they
          clawed at the floor (a handprint with four nail streaks behind it), a hand that caught the
          doorframe on the way through, a few drops.
  LAIR    (the far room): where the trail ends — the dead pulled into a heap against the back wall,
          the floor under them stained black, bones and torn clothing kept close round it, a low smear
          on the wall where they were thrown down. Only here is the room dimmed.
No words in blood, nothing growing out of the ceiling, no gore scattered for its own sake.

For every room-module variant pixlib.finish_module calls write(), which renders
assets/rooms/<name>_nest_<role>.png for the six roles (entry/through/lair × l/r, where _l = the front
door is on the LEFT so the story runs left → right) and records where flies gather (over the pool, the
heap) in assets/rooms/nest_meta.json. room.gd picks the role from the flat's entrance side + the
module's slot. Every mark knows the module's own layout (bare wall / bare floor / furniture masks from
the art), so a trail passes BEHIND a table and a handprint never lands on a picture.
"""
import json
import math
import os
import random
import zlib

from PIL import Image

W, H, SEAM = 320, 144, 100
LANE_Y = 129                     # the walking line (world 353 − the module's top 224): the trail's line
ROLES = ('entry_l', 'through_l', 'lair_l', 'entry_r', 'through_r', 'lair_r')

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
WASH = {'entry': (14, 6, 5, 22), 'through': (14, 6, 5, 16), 'lair': (12, 5, 4, 58)}


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
    # rugs etc. registered by the art (pixlib.flat_piece): flat wherever they still show in the finished
    # art — a sofa drawn on the rug covers those pixels, so it stays upright
    for (x, y), col in (flat_pieces or {}).items():
        if y >= SEAM and fp[x, y] == col:
            flat[x][y] = True
    return bare, flat


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
    return x0 + (w if s > 0 else 0)


def _stain(L, rng, x0, x1, y, depth=3):
    # the floor under the dead, soaked black at the heart and dried brown at the rim
    for x in range(min(x0, x1), max(x0, x1) + 1):
        for j in range(depth + 1):
            if rng.random() < 0.9 - 0.18 * j:
                L.put(x, y + j, BLOOD_OLD if j else BLOOD_DK)


def _heap(L, rng, cx, y, s):
    # the dead pulled together where they fed: one laid out along the wall, the next dragged in and
    # dropped in front of it, head to feet
    _stain(L, rng, cx - 34, cx + 34, y, 3)
    _body(L, rng, cx - s * 24, y - 3, s)
    _body(L, rng, cx + s * 22, y + 4, -s)


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

def render(name, full, bare_floor, seed, role, flat_pieces=None):
    part, side = role.split('_')
    s = 1 if side == 'l' else -1                 # the way the story runs across the flat
    e = 0 if s > 0 else W - 1                     # the edge it comes in from (the front door, in ENTRY)
    far = W - 1 if s > 0 else 0
    rng = random.Random(zlib.crc32(('nest:%s:%s:%d' % (name, role, seed)).encode()))
    bare, flat = _masks(full, bare_floor, flat_pieces)
    wall, floor, obj = Layer(), Layer(), Layer()
    flies = []
    if part == 'entry':
        # where they caught the resident: by the door, on the wall
        wx = _pick_wall_x(bare, rng, *sorted((e + s * 14, e + s * 46)), 60, 98)
        if wx is None:
            wx = _pick_wall_x(bare, rng, *sorted((e + s * 10, e + s * 110)), 64, 96) or (e + s * 30)
        hy = rng.randint(58, 68)
        _handprint(wall, wx, hy, s, rng)
        _slide_down(wall, rng, wx, hy + 6, SEAM - 1)
        _spatter(wall, rng, wx + 2, rng.randint(74, 86), -s)
        px, py = wx + 2 + s * 4, SEAM + rng.randint(6, 9)
        _pool(floor, rng, px, py, 1.1)
        flies.append((px, py - 4))
        # what they dropped
        _x2(floor, lambda T, x_, y_, s_: _keys(T, x_, y_), e + s * rng.randint(8, 16), rng.randint(124, 136), s)
        spot = _pick_floor(flat, rng, range(e + s * 40, e + s * 90, s * 4) if s > 0 else range(e + s * 40, e + s * 90, s * 4),
                           range(116, 138, 3), 5)
        if spot:
            _shoe(obj, rng, spot[0], spot[1], -s)
        spot = _pick_floor(flat, rng, list(range(min(e + s * 16, e + s * 70), max(e + s * 16, e + s * 70), 4)),
                           range(132, 142, 2), 22)
        if spot:
            _bag(obj, rng, spot[0], spot[1], s)
        _splinters(floor, rng, e, s, flat)
        # the trail leaves the pool for the rest of the flat; bare feet walked in beside it
        pts = _path(rng, px + s * 6, py + 2, far, LANE_Y)
        _trail(floor, rng, pts)
        for k, i in enumerate(range(10, min(len(pts), 110), rng.randint(13, 17))):
            fx, fy = pts[i]
            _footprint(floor, rng, fx, fy + (6 if k % 2 else -6), s, k / 8)
    elif part == 'through':
        pts = _path(rng, e, LANE_Y, far, LANE_Y)
        _trail(floor, rng, pts)
        for k in range(rng.randint(1, 2)):                               # clawing at the floor
            i = rng.randint(60, len(pts) - 60)
            _claw_hand(floor, rng, pts[i][0], pts[i][1] + rng.choice((-3, 4)), s)
        gx = _pick_wall_x(bare, rng, *sorted((e + s * 2, e + s * 14)), 76, 92, 5)
        if gx is not None:                                               # a hand caught the doorframe
            gy = rng.randint(78, 88)
            _handprint(wall, gx, gy, s, rng, BLOOD_DK)
            for f in range(4):
                for d in range(rng.randint(4, 9)):
                    wall.put(gx + f + s * (d // 3), gy + 1 + d // 2 + f // 3, BLOOD_DRY)
        for k in range(rng.randint(3, 6)):
            x, y = rng.choice(pts)
            floor.put(x + rng.randint(-6, 6), y + rng.choice((-5, 5, 6)), BLOOD_DK)
    else:
        # the lair: at the far end, where they were taken — the dead together on the floor, as far
        # back as there's room (against the skirting where it's clear), and the trail runs into them
        spots = [(cx, y) for y in range(SEAM + 14, 126, 2) for cx in range(50, W - 50, 3)
                 if _bare_run(flat, cx - 46, cx + 46, (y - 13, y - 8, y - 3, y, y + 5))]
        spots.sort(key=lambda p: (p[1] // 6, -p[0] * s))                      # back first, then far
        if spots:
            hx, hy = spots[min(len(spots) - 1, rng.randint(0, 2))]
            _heap(obj, rng, hx, hy, s)
            end = (hx - s * 40, hy + 2)
        else:                                                                  # no room for two: one, laid out
            xs = [x for x in range(38, W - 38, 4)]
            spot = _pick_floor(flat, rng, xs, range(114, 140, 2), 34)
            if spot is None:
                spot = _pick_floor(flat, rng, xs, range(108, 142, 2), 30) or (W // 2, LANE_Y + 6)
            hx, hy = spot
            _stain(obj, rng, hx - 26, hx + 26, hy, 2)
            _body(obj, rng, hx - s * 31, hy, s)
            end = (hx - s * 32, hy + 1)
        flies.append((hx, hy - 9))
        sx = _pick_wall_x(bare, rng, hx - 30, hx + 26, 84, 98, 4)             # thrown down against the wall
        if sx is not None and hy < SEAM + 16:
            for d in range(rng.randint(8, 14)):
                for w in range(4):
                    if rng.random() < 0.75:
                        wall.put(sx + w, SEAM - 1 - d, BLOOD_OLD if d > 5 else BLOOD_DRY)
        pts = _path(rng, e, LANE_Y, end[0], end[1])
        _trail(floor, rng, pts)
        for k in range(rng.randint(3, 5)):                               # kept close to where they fed
            _bone(floor, rng, hx + rng.randint(-40, 36), hy + rng.randint(3, 10))
        for k in range(rng.randint(2, 3)):
            _rag(floor, rng, hx + rng.randint(-44, 40), hy + rng.randint(3, 12))
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
    return out, [[int(x), int(y)] for (x, y) in flies]


META = os.path.join('assets', 'rooms', 'nest_meta.json')


def write(name, full, bare_floor, seed, root, flat_pieces=None):
    d = os.path.join(root, 'assets', 'rooms')
    old = os.path.join(d, name + '_nest.png')                         # the round-21 single overlay
    for p in (old, old + '.import'):
        if os.path.exists(p):
            os.remove(p)
    if os.environ.get('NEST_DEBUG'):
        bare, flat = _masks(full, bare_floor, flat_pieces)
        m = Image.new('RGB', (W, H))
        for x in range(W):
            for y in range(H):
                m.putpixel((x, y), (0, 160, 0) if bare[x][y] else ((200, 200, 0) if flat[x][y] else (60, 0, 0)))
        m.resize((W * 3, H * 3)).save(os.environ['NEST_DEBUG'] + '/' + name + '_mask.png')
    meta_path = os.path.join(root, META)
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    imgs = {}
    for role in ROLES:
        img, flies = render(name, full, bare_floor, seed, role, flat_pieces)
        img.save(os.path.join(d, '%s_nest_%s.png' % (name, role)))
        meta['%s_nest_%s' % (name, role)] = {'flies': flies}
        imgs[role] = img
    with open(meta_path, 'w') as f:                                     # one line a texture, sorted
        f.write('{\n' + ',\n'.join(' %s: %s' % (json.dumps(k), json.dumps(meta[k], separators=(', ', ': ')))
                                     for k in sorted(meta)) + '\n}\n')
    return imgs


def preview(root):
    # docs/art_reference/modules/breach_nests.png: per room type, a breached flat read left to right —
    # variant a as the ENTRY (front door on the left), b the room it's dragged THROUGH, c the LAIR —
    # then the same three with the door on the right
    from PIL import ImageDraw
    types = ['living_room', 'bedroom', 'kitchen', 'bathroom', 'study', 'dining_room']
    rooms = os.path.join(root, 'assets', 'rooms')
    pad = 6
    sheet = Image.new('RGB', (2 * (3 * W + pad) + pad, len(types) * (H + 14) + pad), (18, 18, 20))
    d = ImageDraw.Draw(sheet)
    for r, t in enumerate(types):
        for k, side in enumerate(('l', 'r')):
            roles = ['entry', 'through', 'lair'] if side == 'l' else ['lair', 'through', 'entry']
            for i, (v, role) in enumerate(zip(['', '_b', '_c'] if side == 'l' else ['_c', '_b', ''], roles)):
                a = Image.open(os.path.join(rooms, t + v + '.png')).convert('RGBA')
                a.alpha_composite(Image.open(os.path.join(rooms, '%s%s_nest_%s_%s.png' % (t, v, role, side))))
                x, y = pad + k * (3 * W + pad) + i * W, pad + r * (H + 14)
                sheet.paste(a.convert('RGB'), (x, y + 12))
            d.text((pad + k * (3 * W + pad), pad + r * (H + 14)), '%s — front door %s' % (t, 'left' if side == 'l' else 'right'),
                   fill=(220, 210, 190))
    out = os.path.join(root, 'docs', 'art_reference', 'modules', 'breach_nests.png')
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
    print('wrote', out)


if __name__ == '__main__':
    preview(os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')))
