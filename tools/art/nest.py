"""BREACH-ROOM NESTS (owner round 21 — "breach rooms should be looking real fucked up like a nest of
horror. Blood and stuff everywhere… the player needs to look at the art and think nope").

For every room-module variant, pixlib.finish_module calls write() and this renders
assets/rooms/<name>_nest.png: a transparent overlay that room.gd lays over that module ONLY in a
BREACHED apartment. It knows the module's own layout (masks from the art: bare wall, bare floor,
furniture), so the marks land where they belong:
  * on the walls + furniture — arterial spray fanned out from where something was opened, with runs
    dripping off it; hands dragged down the paper; handprints; claw gouges to the plaster; now and
    then words in blood;
  * on the bare floor only — pools (flattened, glossy), drag trails, chunks of gore, gnawed bones,
    torn rags; and in some rooms the NEST itself — a heap of the dead against the back wall.
The live details (flies over the gore, blood still dripping from the ceiling) are added at runtime by
room.gd (module_anim.gd).
"""
import math
import os
import random
import zlib

from PIL import Image

W, H, SEAM = 320, 144, 100

BLOOD = (122, 10, 12, 255)
BLOOD_DK = (74, 6, 6, 255)
BLOOD_DRY = (92, 26, 20, 255)
BLOOD_LT = (168, 32, 28, 255)
GORE = (150, 58, 64, 255)
GORE_DK = (96, 26, 32, 255)
BONE = (192, 180, 152, 255)
BONE_DK = (138, 124, 98, 255)
SKIN = (128, 132, 104, 255)
SKIN_DK = (88, 96, 72, 255)
RAGS = [(70, 78, 96, 255), (96, 84, 66, 255), (80, 64, 70, 255), (110, 106, 96, 255)]
GOUGE, GOUGE_LT = (34, 22, 18, 255), (150, 136, 112, 255)
WORDS = ['GET OUT', 'HELP', 'NO', 'IT HEARS', 'DONT']


class Layer:
    def __init__(self):
        self.img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        self.px = self.img.load()

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = c

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                if ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / max(ry, 0.5)) ** 2 <= 1.0:
                    self.put(x, y, c)


def _masks(full, bare_floor):
    fp, bp = full.load(), bare_floor.load()
    bare = [[fp[x, y] == bp[x, y] for y in range(H)] for x in range(W)]
    return bare


def _spray(L, rng, ox, oy):
    # arterial spray: droplets fanned along a direction, big near the source, tails pointing away,
    # runs dripping off the heavier ones
    ang = rng.uniform(-2.6, -0.5) if rng.random() < 0.7 else rng.uniform(-3.4, 0.2)
    reach = rng.uniform(28, 64)
    for k in range(rng.randint(55, 90)):
        t = rng.random() ** 0.75
        a = ang + rng.gauss(0, 0.28 * (1.1 - t))
        x, y = ox + math.cos(a) * reach * t, oy + math.sin(a) * reach * t * 0.8
        size = 3 if t < 0.15 else (2 if t < 0.45 else 1)
        col = BLOOD if rng.random() < 0.7 else BLOOD_DK
        for dx in range(size):
            for dy in range(size):
                L.put(x + dx, y + dy, col)
        if t > 0.3 and rng.random() < 0.5:                                  # its tail
            L.put(x - math.cos(a) * 2, y - math.sin(a) * 2, BLOOD_DK)
        if size >= 2 and rng.random() < 0.35:                               # a run down the wall
            for d in range(rng.randint(3, 13)):
                L.put(x + (1 if size > 2 else 0), y + size + d, BLOOD_DK if d > 2 else col)
    for k in range(rng.randint(3, 6)):                                      # the source: a heavy splat
        L.ellipse(ox + rng.randint(-3, 3), oy + rng.randint(-2, 2), rng.uniform(1.5, 3.5), rng.uniform(1.5, 3), BLOOD_DK)


def _hand_smear(L, rng, x, y):
    # a bloody hand dragged down the paper: a palm-wide streak thinning into four finger lines
    length = rng.randint(22, 40)
    drift = rng.uniform(-0.25, 0.25)
    for d in range(length):
        cx = x + drift * d
        fade = d / length
        if fade < 0.45:
            for w in range(5):
                if rng.random() < 0.9 - fade:
                    L.put(cx + w, y + d, BLOOD_DRY if w in (0, 4) else BLOOD)
        else:
            for f in range(4):
                if rng.random() < 1.1 - fade:
                    L.put(cx + f * 1.4, y + d, BLOOD_DRY)


def _handprint(L, rng, x, y):
    col = BLOOD_LT if rng.random() < 0.5 else BLOOD
    for (dx, dy) in ((0, 3), (1, 3), (2, 3), (3, 3), (0, 4), (1, 4), (2, 4), (3, 4), (1, 5), (2, 5), (0, 2), (3, 2),
                     (0, 0), (0, 1), (1, -1), (1, 0), (2, -1), (2, 0), (3, 0), (3, 1), (4, 2), (5, 1)):
        if rng.random() < 0.85:
            L.put(x + dx, y + dy, col)


def _claws(L, rng, x, y):
    ang = rng.uniform(0.9, 1.4) * (1 if rng.random() < 0.5 else -1)
    ln = rng.randint(10, 18)
    for k in range(3):
        for t in range(ln):
            px, py = x + k * 3 + math.cos(ang) * t * 0.4, y + t
            L.put(px, py, GOUGE)
            if t % 3 == 0:
                L.put(px - 1, py, GOUGE_LT)


def _pool(L, rng, cx, cy):
    blobs = [(cx + rng.randint(-10, 10), cy + rng.randint(-2, 2), rng.uniform(5, 15)) for _ in range(rng.randint(2, 4))]
    for (bx, by, r) in blobs:
        L.ellipse(bx, by, r, r * 0.3, BLOOD_DK)
    for (bx, by, r) in blobs:
        L.ellipse(bx, by - 0.4, r * 0.75, r * 0.2, BLOOD)
    bx, by, r = blobs[0]
    for x in range(int(bx - r * 0.5), int(bx + r * 0.1)):                  # the glossy wet highlight
        L.put(x, by - 1, BLOOD_LT)


def _drag(L, rng, x0, y, x1):
    # a trail where something was dragged across the floor: streaky, broken, fading
    step = 1 if x1 > x0 else -1
    n = abs(x1 - x0)
    for i in range(n):
        x = x0 + i * step
        fade = i / max(1, n)
        yy = y + int(2 * math.sin(i * 0.07))
        for w in range(5):
            if rng.random() < (0.85 - fade * 0.6) * (0.6 if w in (0, 4) else 1.0):
                L.put(x, yy + w, BLOOD_DRY if rng.random() < 0.5 else BLOOD_DK)


def _gore(L, rng, x, y):
    # a chunk of something: lumps and torn strips, never a neat dot
    if rng.random() < 0.4:
        ln = rng.randint(3, 7)
        for i in range(ln):
            L.put(x + i, y + (i % 3 == 0), GORE if i % 2 else GORE_DK)
        L.put(x + ln, y, BLOOD_DK)
        return
    r = rng.uniform(1.4, 3.2)
    L.ellipse(x, y, r * rng.uniform(0.8, 1.5), r * 0.6, GORE_DK)
    L.ellipse(x - 0.4, y - 0.4, r * 0.7, r * 0.45, GORE)
    if rng.random() < 0.5:
        L.put(x - r * 0.4, y - r * 0.3, (196, 110, 110, 255))


def _bone(L, rng, x, y):
    # a gnawed bone, dirty: an uneven shaft, one end knobbed, one snapped
    ln = rng.randint(4, 8)
    tilt = rng.choice((-1, 0, 0, 1))
    for i in range(ln):
        L.put(x + i, y + (tilt * i) // 5, BONE if i % 3 else BONE_DK)
    L.put(x - 1, y, BONE_DK); L.put(x - 1, y - 1, BONE)                        # the knuckle end
    L.put(x + ln, y + (tilt * ln) // 5 + 1, BLOOD_DK)                          # the snapped end, bloody


def _rag(L, rng, x, y):
    col = rng.choice(RAGS)
    w, h = rng.randint(5, 10), rng.randint(2, 4)
    for yy in range(h):
        for xx in range(w):
            if rng.random() < 0.85:
                L.put(x + xx + (yy % 2), y + yy, col if rng.random() < 0.8 else BLOOD_DK)


def _body(L, rng, x, y, flip):
    # one of the dead, lying on its side: clothed torso, head, an arm and legs; lit on top, soaked
    col = rng.choice(RAGS)
    lt, dk = tuple(min(255, int(v * 1.2)) for v in col[:3]) + (255,), tuple(int(v * 0.6) for v in col[:3]) + (255,)
    w = rng.randint(13, 18)
    s = -1 if flip else 1
    for i in range(w):                                                        # torso + legs
        xx = x + s * i
        L.put(xx, y - 2, lt if i < w - 5 else dk)
        for j in range(-1, 2):
            L.put(xx, y + j, col if i < w - 5 else dk)
        L.put(xx, y + 2, dk)
    hx = x - s * 3                                                            # the head
    L.ellipse(hx, y, 2.4, 2.2, SKIN)
    L.put(hx, y - 2, tuple(min(255, int(v * 1.15)) for v in SKIN[:3]) + (255,))
    L.put(hx - s, y + 1, SKIN_DK)
    L.put(hx + s, y - 3, (40, 30, 24, 255)); L.put(hx, y - 3, (40, 30, 24, 255))    # hair
    ax = x + s * rng.randint(3, 7)                                            # an arm flung out
    for t in range(rng.randint(5, 8)):
        L.put(ax + s * (t // 3), y + 2 + t, SKIN if t % 4 else SKIN_DK)
    for k in range(rng.randint(2, 4)):                                        # soaked through
        L.put(x + s * rng.randint(0, w), y + rng.randint(-1, 2), BLOOD_DK)


def _heap(L, rng, cx, base):
    # THE NEST: the dead dragged into a pile against the back wall — bodies stacked on each other,
    # an arm reaching out of it, the floor round it soaked black
    for x in range(-30, 31):
        for y in range(4):
            if rng.random() < 0.8 - y * 0.18:
                L.put(cx + x, base + 1 + y, BLOOD_DK)
    rows = [(base - 1, 3), (base - 6, 2), (base - 10, 1)]
    for (y, n) in rows:
        span = n * 16
        for k in range(n):
            x = cx - span // 2 + k * 16 + rng.randint(-2, 2)
            flip = rng.random() < 0.5
            _body(L, rng, x + (16 if flip else 0), y, flip)
    ax = cx + rng.randint(-6, 6)                                              # an arm reaching up out of it
    for t in range(9):
        L.put(ax + t // 4, base - 12 - t, SKIN)
        L.put(ax + 1 + t // 4, base - 12 - t, SKIN_DK)
    for (dx, dy) in ((1, -22), (3, -22), (2, -23), (4, -21), (0, -21)):
        L.put(ax + dx, base + dy, SKIN)
    for k in range(3):
        _bone(L, rng, cx + rng.randint(-26, 20), base + rng.randint(0, 3))


FLESH = (86, 22, 26, 255)
FLESH_DK = (44, 10, 12, 255)
FLESH_LT = (140, 52, 58, 255)
WASH = (18, 7, 6, 112)                    # the whole room goes dim and filthy


def _growth(L, rng, x0, y0, spread, down):
    # the NEST growing: a fleshy mass creeping from a corner / along the ceiling — lumpy, veined,
    # with strands hanging off it that end in a bulb
    pts = [(x0, y0)]
    for k in range(int(spread * 1.6)):
        px, py = rng.choice(pts)
        nx, ny = px + rng.randint(-3, 3), py + rng.randint(-1, 3 if down else 1)
        if 0 <= nx < W and 0 <= ny < H and abs(nx - x0) <= spread:
            pts.append((nx, ny))
            L.ellipse(nx, ny, rng.uniform(1.2, 3.2), rng.uniform(1.0, 2.6), FLESH if rng.random() < 0.7 else FLESH_DK)
    for (px, py) in rng.sample(pts, min(len(pts), 12)):
        L.put(px, py, FLESH_LT)                                               # veins / wet highlights
        L.put(px + 1, py, FLESH_LT)
    for k in range(rng.randint(2, 5)):                                        # strands hanging down
        px, py = rng.choice(pts)
        ln = rng.randint(5, 22)
        for d in range(ln):
            L.put(px + (d // 7) * rng.choice((0, 1)), py + d, FLESH_DK)
        L.ellipse(px, py + ln, 1.5, 1.8, FLESH)


def _splat(L, rng, x, y):
    # something thrown against the wall: a big irregular blotch with runs off its bottom
    for k in range(rng.randint(5, 9)):
        L.ellipse(x + rng.gauss(0, 4), y + rng.gauss(0, 3), rng.uniform(1.5, 4.5), rng.uniform(1.5, 4), BLOOD if k % 3 else BLOOD_DK)
    for k in range(rng.randint(4, 8)):
        dx = rng.randint(-7, 7)
        for d in range(rng.randint(4, 20)):
            L.put(x + dx, y + 3 + d, BLOOD_DK if d > 3 else BLOOD)
    for k in range(20):
        a, r = rng.uniform(0, 6.28), rng.uniform(6, 14)
        L.put(x + math.cos(a) * r, y + math.sin(a) * r * 0.8, BLOOD)


def _remains(L, rng, x, y):
    # a body on the floor, half eaten: legs, a torn torso with its ribs showing, blood round it
    for k in range(3):
        L.ellipse(x + rng.randint(-10, 10), y + 1, rng.uniform(8, 14), 2.5, BLOOD_DK)
    col = rng.choice(RAGS)
    for i in range(14):                                                       # legs in trousers
        L.put(x - 12 + i, y - 1, col); L.put(x - 12 + i, y, col)
    for i in range(10):                                                       # the torso, opened
        for j in range(4):
            L.put(x + 2 + i, y - 2 + j, SKIN if j in (0, 3) else GORE)
    for i in range(0, 10, 2):                                                 # ribs
        L.put(x + 3 + i, y - 1, BONE); L.put(x + 3 + i, y, BONE)
    L.ellipse(x + 15, y - 1, 2.5, 2, SKIN)                                    # the head, turned away
    L.put(x + 16, y - 2, SKIN_DK)


def render(name, full, bare_floor, seed):
    rng = random.Random(zlib.crc32(('nest:%s:%d' % (name, seed)).encode()))
    bare = _masks(full, bare_floor)
    wall_only, anywhere_up, floor_only, obj = Layer(), Layer(), Layer(), Layer()
    # --- the nest growing out of the ceiling line and the top corners ---
    # a sagging band of it along the ceiling line, thicker in places
    for x in range(W):
        sag = int(3 + 3 * math.sin(x * 0.05 + seed) + 2 * math.sin(x * 0.17))
        for y in range(max(0, sag)):
            anywhere_up.put(x, y, FLESH_DK if y < sag - 1 else FLESH)
    for k in range(rng.randint(4, 7)):
        _growth(anywhere_up, rng, rng.randint(0, W - 1), rng.randint(2, 8), rng.randint(10, 26), True)
    for cx in (rng.randint(0, 20), rng.randint(W - 21, W - 1)):
        if rng.random() < 0.7:
            _growth(anywhere_up, rng, cx, rng.randint(4, 30), rng.randint(8, 16), True)
    # --- walls + furniture ---
    for k in range(rng.randint(3, 6)):
        _spray(anywhere_up, rng, rng.randint(20, 300), rng.randint(28, 92))
    for k in range(rng.randint(2, 4)):
        _splat(anywhere_up, rng, rng.randint(16, 304), rng.randint(30, 86))
    for k in range(rng.randint(1, 3)):
        _hand_smear(wall_only, rng, rng.randint(12, 300), rng.randint(40, 62))
    for k in range(rng.randint(2, 5)):
        _handprint(wall_only, rng, rng.randint(10, 305), rng.randint(46, 92))
    for k in range(rng.randint(1, 3)):
        _claws(wall_only, rng, rng.randint(10, 300), rng.randint(30, 70))
    if rng.random() < 0.4:                                                    # words in blood, on bare wall
        word = rng.choice(WORDS)
        wlen = len(word) * 8
        for _ in range(40):
            x, y = rng.randint(8, W - wlen - 8), rng.randint(20, 60)
            if all(bare[xx][yy] for xx in range(x - 2, x + wlen + 2, 3) for yy in (y - 1, y + 5, y + 11)):
                import furn as F
                c = _CanvasShim(wall_only)
                F.text_spray(c, x, y, word, BLOOD, scale=2, drips=True, seed=seed)
                break
    # --- the floor ---
    floor_pts = [(x, y) for x in range(6, W - 6, 4) for y in range(104, 140, 3) if bare[x][y]]
    if floor_pts:
        for k in range(rng.randint(4, 7)):
            x, y = rng.choice(floor_pts)
            _pool(floor_only, rng, x, y)
        for k in range(rng.randint(2, 3)):
            x, y = rng.choice(floor_pts)
            _drag(floor_only, rng, x, y - 2, x + rng.choice((-1, 1)) * rng.randint(40, 130))
        for k in range(rng.randint(9, 15)):
            _gore(floor_only, rng, *rng.choice(floor_pts))
        for k in range(rng.randint(4, 8)):
            _bone(floor_only, rng, *rng.choice(floor_pts))
        for k in range(rng.randint(3, 6)):
            _rag(floor_only, rng, *rng.choice(floor_pts))
        if rng.random() < 0.8:
            wide = [(x, y) for (x, y) in floor_pts if 112 <= y <= 138 and all(bare[xx][y] for xx in range(max(0, x - 14), min(W, x + 18), 2))]
            if wide:
                _remains(obj, rng, *rng.choice(wide))
    # --- the nest: a heap of the dead against the back wall, where there's room ---
    if rng.random() < 0.75:
        spans = []
        for cx in range(34, W - 34, 4):
            if all(bare[x][y] for x in range(cx - 24, cx + 25, 3) for y in (SEAM + 2, SEAM + 7, SEAM - 3)):
                spans.append(cx)
        if spans:
            _heap(obj, rng, rng.choice(spans), SEAM + 6)
    # --- composite through the masks ---
    out = Image.new('RGBA', (W, H), WASH)
    op = out.load()
    for layer, ok in ((anywhere_up, lambda x, y: y < SEAM or not bare[x][y]),
                      (wall_only, lambda x, y: y < SEAM and bare[x][y]),
                      (floor_only, lambda x, y: y >= SEAM and bare[x][y]),
                      (obj, lambda x, y: True)):
        lp = layer.px
        for y in range(H):
            for x in range(W):
                if lp[x, y][3] and ok(x, y):
                    op[x, y] = lp[x, y]
    return out


class _CanvasShim:
    # just enough of pixlib.Canvas for furn.text_spray to draw into a Layer
    def __init__(self, layer):
        self.layer = layer

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.layer.put(x, y, c if len(c) == 4 and c[3] == 255 else c[:3] + (255,))

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)


def write(name, full, bare_floor, seed, root):
    img = render(name, full, bare_floor, seed)
    img.save(os.path.join(root, 'assets', 'rooms', name + '_nest.png'))
    return img
