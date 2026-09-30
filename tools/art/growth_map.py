"""The GROWTH MAP of a room module: where vegetation can grow WITHOUT covering the furniture.

Room art is one baked picture, so a live sprite laid over it would sit in front of the furniture it
should be behind. Instead of guessing, every module variant records — while it is rendered — three
skylines over its 320 columns, measured on the final art against the bare wall + floor (and against
the run-2 / run-3 furniture looks too, so a knocked-over chair is never grown through):

  up_floor[x]   how many clear rows there are ABOVE the floor line (BASE_FLOOR) at column x — how tall
                a plant may stand there
  up_wall[x]    the same, up from the skirting (BASE_WALL) — how tall ivy may climb
  down_ceil[x]  clear rows DOWN from just under the crown moulding (CEIL_Y) — how long a vine may hang

scripts/room_growth.gd fits sprites into these (a sprite only goes where its whole width is clear).
Written by pixlib.finish_module into assets/rooms/growth_meta.json (one entry per variant).
"""
import json
import os

W, H = 320, 144
BASE_FLOOR = 116
BASE_WALL = 97
CEIL_Y = 12
MAX_UP = 100
MAX_DOWN = 92
META = os.path.join('assets', 'rooms', 'growth_meta.json')


def _bare(imgs, bare_img):
    px = [im.load() for im in imgs]
    bp = bare_img.load()

    def bare(x, y):
        if not (0 <= x < W and 0 <= y < H):
            return False
        return all(p[x, y] == bp[x, y] for p in px)
    return bare


def skylines(imgs, bare_img):
    bare = _bare(imgs, bare_img)
    up_floor, up_wall, down_ceil = [], [], []
    for x in range(W):
        # standing on the floor: the patch it stands on must be clear, then count upward
        if not all(bare(x, y) for y in range(BASE_FLOOR - 2, BASE_FLOOR + 1)):
            up_floor.append(0)
        else:
            n = 0
            y = BASE_FLOOR - 3
            while n < MAX_UP and bare(x, y):
                n += 1
                y -= 1
            up_floor.append(n)
        n = 0
        y = BASE_WALL
        while n < MAX_UP and bare(x, y):
            n += 1
            y -= 1
        up_wall.append(n)
        n = 0
        y = CEIL_Y
        while n < MAX_DOWN and bare(x, y):
            n += 1
            y += 1
        down_ceil.append(n)
    return up_floor, up_wall, down_ceil


def write(name, imgs, bare_img, root):
    up_floor, up_wall, down_ceil = skylines(imgs, bare_img)
    path = os.path.join(root, META)
    data = {}
    if os.path.exists(path):
        try:
            data = json.load(open(path))
        except ValueError:
            data = {}
    entries = data.setdefault('modules', {})
    entries[name] = {'up_floor': up_floor, 'up_wall': up_wall, 'down_ceil': down_ceil}
    data['note'] = ('written by tools/art/growth_map.py via pixlib.finish_module — per module variant, three skylines '
                    '(clear rows above the floor line / up the wall / down from the ceiling) over its 320 columns')
    data['base'] = {'floor': BASE_FLOOR, 'wall': BASE_WALL, 'ceil': CEIL_Y}
    with open(path, 'w') as fh:
        json.dump(data, fh, separators=(',', ':'), sort_keys=True)
