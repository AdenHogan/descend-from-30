"""Per-floor decals for the corridors: lived-in DRESSING and HORROR marks.

Run:  python3 tools/art/corridor_decals.py
Out:  assets/corridor/decals/<name>.png (transparent), a contact sheet in
      docs/art_reference/corridor/corridor_decals.png.

The baked corridor art (tools/art/corridor.py) is one of a few dozen images, so on its own every
hotel floor looks like every other hotel floor. scripts/corridor_decals.gd scatters these small
sprites over it per floor, from the seed: residents' things against the walls (plants, shoes,
an umbrella, parcels, a chair, a scooter...) and — more the deeper you go and the later in the
day it gets — the horror: blood smeared along the walls, handprints, spatter, bullet holes,
claw gouges, blood scrawled messages, pools and drag trails on the floor, marks on the doors.

Every sprite is authored FLAT (lit by the engine like the wall under it), bottom-anchored where
it stands on the floor. Names are the catalogue keys in corridor_decals.gd — keep them in step.
"""
import math
import os
import random
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, mix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'corridor', 'decals')
MADE = {}

BLOOD = hexc('6a1812', 235)
BLOOD_DK = hexc('4a0e0c', 240)
BLOOD_LT = hexc('84241a', 215)
BLOOD_THIN = hexc('6a1812', 150)


def canvas(w, h, seed):
    return Canvas(w=w, h=h, seed=seed)


def save(name, c):
    bbox = c.img.getbbox()
    if bbox is None:
        sys.exit('%s: empty' % name)
    c.img.save(os.path.join(OUT, name + '.png'))
    MADE[name] = c.img


# --- blood ----------------------------------------------------------------------------------
def drips(c, rng, x, y, n_max, col=BLOOD):
    for k in range(rng.randrange(0, n_max + 1)):
        yy = y
        ln = rng.randrange(2, 12)
        for j in range(ln):
            c.put(x, yy + j, col if j < ln - 1 else BLOOD_DK)
        c.put(x, yy + ln, BLOOD_DK)


def smear(name, seed, w, h):
    """A hand dragged along the wall: thick at the start, feathering out, runs off the bottom."""
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    y = h // 3
    thick = rng.randrange(4, 7)
    wave = rng.uniform(0.05, 0.12)
    for x in range(2, w - 2):
        t = x / float(w)
        cy = y + int(3 * math.sin(x * wave + seed)) + int(t * rng.choice((0, 0, 1)))
        th = max(1, int(thick * (1.0 - 0.75 * t)))
        for k in range(-th // 2, th - th // 2):
            if rng.random() < 1.0 - t * 0.55:                      # dragging out, streaky
                col = BLOOD_DK if k == -th // 2 else (BLOOD_LT if (x + k) % 5 == 0 else BLOOD)
                c.put(x, cy + k, col)
        if rng.random() < 0.08 * (1 - t):
            drips(c, rng, x, cy + th // 2, 1)
    for x in range(0, 6):                                          # the palm where it started
        for yy in range(y - 4, y + 5):
            if (x - 3) ** 2 / 9.0 + (yy - y) ** 2 / 20.0 <= 1.0:
                c.put(x + 1, yy, BLOOD)
    save(name, c)


def slide(name, seed):
    """Someone slid down the wall: a broad smear from shoulder height down to the skirting,
    solid in the middle, streaked (finger-drag lines) and ragged at the edges."""
    w, h = 22, 56
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    streaks = [rng.randrange(-4, 5) for _ in range(3)]
    for y in range(h):
        t = y / float(h)
        half = 4 + int(4 * t)
        cx = 11 + int(1.5 * math.sin(y * 0.15 + seed))
        lo, hi = cx - half - rng.choice((0, 0, 1)), cx + half + rng.choice((0, 0, 1))
        for x in range(lo, hi + 1):
            col = BLOOD
            if x in (lo, hi):
                col = BLOOD_DK
            elif any(x == cx + s_ for s_ in streaks):
                col = BLOOD_LT                                     # lighter drag lines
            if t < 0.15 and rng.random() < 0.4:
                continue                                           # it starts thin, patchy
            c.put(x, y, col)
    for k in range(4):                                             # fingers at the top
        x = 6 + k * 3
        for y in range(0, rng.randrange(4, 8)):
            c.put(x, y, BLOOD)
    save(name, c)


def handprint(name, seed, dragged=False, pair=False):
    w, h = (26 if pair else 14), (24 if dragged else 16)
    c = canvas(w, h, seed)
    rng = random.Random(seed)

    def hand(hx, hy, tilt):
        for y in range(hy, hy + 6):
            for x in range(hx - 3, hx + 4):
                if ((x - hx) / 3.3) ** 2 + ((y - hy - 3) / 3.1) ** 2 <= 1.0:
                    c.put(x, y, BLOOD if (x + y) % 6 else BLOOD_LT)
        for i, (fx, ln) in enumerate(((-3, 4), (-1, 5), (1, 5), (3, 4))):
            for k in range(ln):
                c.put(hx + fx + (k * tilt) // 4, hy - 1 - k, BLOOD)
            c.put(hx + fx + (ln * tilt) // 4, hy - 1 - ln, BLOOD_DK)
        c.put(hx + 5, hy + 2, BLOOD)                               # the thumb
        c.put(hx + 6, hy + 1, BLOOD)
        c.put(hx + 6, hy, BLOOD_DK)
        if dragged:                                                # pulled down the wall
            for x in range(hx - 3, hx + 4):
                for y in range(hy + 6, hy + 6 + rng.randrange(4, 12)):
                    if rng.random() < 0.7:
                        c.put(x, y, BLOOD_THIN if y > hy + 10 else BLOOD)
        else:
            drips(c, rng, hx + rng.randrange(-2, 3), hy + 6, 2)
    hand(6, 6, rng.choice((-1, 0, 1)))
    if pair:
        hand(19, 4 + rng.randrange(0, 3), rng.choice((-1, 0, 1)))
    save(name, c)


def spatter(name, seed):
    """An arc of droplets thrown across the wall."""
    w, h = 40, 30
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    ox, oy = rng.choice((2, w - 3)), rng.randrange(h // 2, h - 4)
    ang0 = -0.9 if ox < w // 2 else math.pi + 0.9
    for k in range(70):
        a = ang0 + rng.uniform(-0.8, 0.8) * (1 if ox < w // 2 else -1)
        r = rng.uniform(2, 36) ** 1.0
        x, y = int(ox + math.cos(a) * r), int(oy + math.sin(a) * r * 0.7)
        size = 2 if r < 12 and rng.random() < 0.5 else 1
        for dx in range(size):
            for dy in range(size):
                c.put(x + dx, y + dy, BLOOD if rng.random() < 0.8 else BLOOD_DK)
        if r < 20 and rng.random() < 0.15:
            drips(c, rng, x, y + size, 1)
    for x in range(ox - 2, ox + 3):                                # the heart of it
        for y in range(oy - 2, oy + 3):
            if (x - ox) ** 2 + (y - oy) ** 2 <= 5:
                c.put(x, y, BLOOD)
    save(name, c)


# --- damage ---------------------------------------------------------------------------------
def bullets(name, seed, n, w=34, h=26):
    """A burst of bullet holes: a dark hole, a chipped pale rim, hairline cracks."""
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    for k in range(n):
        x, y = rng.randrange(4, w - 4), rng.randrange(4, h - 4)
        for (dx, dy) in rng.sample([(-2, 0), (2, 0), (0, -2), (0, 2), (-2, -1), (2, 1), (-1, 2), (1, -2)], 5):
            c.put(x + dx, y + dy, hexc('d6ccb4', 220))              # chipped rim
        for (dx, dy) in ((-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)):
            c.put(x + dx, y + dy, hexc('bcb09a', 230))
        c.rect(x - 0, y - 0, x + 1, y + 1, hexc('141010'))
        c.put(x, y, hexc('060404'))
        for j in range(rng.randrange(1, 3)):                        # cracks
            a = rng.uniform(0, 6.28)
            for r in range(3, rng.randrange(5, 9)):
                c.put(int(x + math.cos(a) * r), int(y + math.sin(a) * r), hexc('2a2420', 150))
    save(name, c)


def claws(name, seed):
    """Four gouges raked down through the paper to the plaster."""
    w, h = 22, 30
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    slant = rng.choice((-0.25, 0.2, 0.3))
    for k in range(4):
        x0 = 3 + k * 4 + (1 if k == 3 else 0)
        y0 = rng.randrange(0, 4) + (2 if k in (0, 3) else 0)
        ln = rng.randrange(18, 26) - (4 if k in (0, 3) else 0)
        for j in range(ln):
            x = int(x0 + j * slant) + 3
            t = j / float(ln)
            c.put(x, y0 + j, hexc('d8cdb2'))                        # plaster in the gouge
            if t < 0.8:
                c.put(x + 1, y0 + j, hexc('b8ab92'))
            c.put(x - 1, y0 + j, hexc('201814', 200))               # torn edge shadow
            if 0.2 < t < 0.7 and rng.random() < 0.15:
                c.put(x + 2, y0 + j, BLOOD)
    save(name, c)


# --- writing --------------------------------------------------------------------------------
FONT = {  # 5x7, rows top to bottom
    'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
    'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
    'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
    'G': ['01111', '10000', '10000', '10011', '10001', '10001', '01111'],
    'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
    'I': ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
    'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
    'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
    'N': ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
    'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
    'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
    'Q': ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
    'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
    'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
    'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
    'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
    'W': ['10001', '10001', '10001', '10101', '10101', '11011', '10001'],
    'Y': ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
    ' ': ['00000'] * 7,
}


def scrawl(name, seed, text, col=None, dark=None, drip=True):
    """Finger-painted capitals: 2px strokes, letters jostling, runs dripping off them."""
    col = col or BLOOD
    dark = dark or BLOOD_DK
    rng = random.Random(seed)
    w = len(text) * 8 + 4
    h = 26
    c = canvas(w, h, seed)
    x = 2
    for ch in text:
        g = FONT[ch]
        oy = 3 + rng.choice((0, 0, 1, -1)) + 1
        sk = rng.choice((0, 0, 1))
        for r, row in enumerate(g):
            for k, bit in enumerate(row):
                if bit == '1':
                    px, py = x + k + (sk if r < 3 else 0), oy + r
                    c.put(px, py, col)
                    c.put(px + 1, py, col if rng.random() < 0.8 else dark)
                    if r == 6 and drip and rng.random() < 0.35:
                        for j in range(rng.randrange(2, 10)):
                            c.put(px, py + 1 + j, col if j < 6 else dark)
        x += 8
    save(name, c)


def search_x(name, seed):
    """The rescue teams' search mark sprayed on a door: an X, a date and a count."""
    w, h = 22, 22
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    paint = hexc('e0662a', 235)
    for k in range(18):
        for t in (0, 1):
            c.put(2 + k, 2 + k + t, paint)
            c.put(19 - k, 2 + k + t, paint)
    for (x, y) in ((9, 0), (10, 0), (11, 0), (9, 1)):             # a number up top
        c.put(x, y, paint)
    for y in range(8, 14):                                          # a tally left, a digit right
        c.put(3, y, paint)
        c.put(5, y, paint)
    for (x, y) in ((16, 9), (17, 9), (18, 9), (18, 10), (17, 11), (16, 12), (16, 13)):
        c.put(x, y, paint)
    for k in range(6):                                              # overspray
        c.put(rng.randrange(0, w), rng.randrange(0, h), hexc('e0662a', 110))
    save(name, c)


# --- the floor --------------------------------------------------------------------------------
def pool(name, seed, w, h):
    """A pool of blood on the floor, seen at the corridor's shallow angle."""
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    ph = [rng.uniform(0, 6.28) for _ in range(3)]
    cx, cy = w / 2.0, h / 2.0
    for y in range(h):
        for x in range(w):
            a = math.atan2((y - cy) / cy, (x - cx) / cx)
            k = 1.0 + 0.18 * math.sin(3 * a + ph[0]) + 0.1 * math.sin(5 * a + ph[1])
            d = (((x - cx) / cx) ** 2 + ((y - cy) / cy) ** 2) ** 0.5 / k
            if d < 0.78:
                c.put(x, y, BLOOD_DK if d < 0.5 else BLOOD)
            elif d < 0.95:
                c.put(x, y, BLOOD_LT if y < cy else BLOOD)
    c.put(int(cx) - 3, int(cy) - 1, hexc('b04438', 200))            # a wet glint
    c.put(int(cx) - 2, int(cy) - 1, hexc('b04438', 160))
    save(name, c)


def drag(name, seed, w):
    """Something heavy dragged along the floor: two smeared tracks, fading out."""
    h = 8
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    for x in range(w):
        t = x / float(w)
        for band in (1, 5):
            y = band + int(1.5 * math.sin(x * 0.05 + band))
            for k in range(2):
                if rng.random() < 0.95 - t * 0.8:
                    c.put(x, y + k, BLOOD if k else BLOOD_DK)
        if rng.random() < 0.3 * (1 - t):
            c.put(x, 3 + rng.randrange(0, 2), BLOOD_THIN)
    save(name, c)


def footprints(name, seed):
    w, h = 90, 8
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    x = 3
    k = 0
    while x < w - 6:
        y = 1 if k % 2 == 0 else 4
        fade = 1.0 - x / float(w)
        col = hexc('6a1812', int(60 + 170 * fade))
        c.rect(x, y, x + 3, y + 1, col)
        c.put(x + 4, y, col)
        c.put(x - 1, y + 1, col)
        x += rng.randrange(9, 13)
        k += 1
    save(name, c)


def casings(name, seed):
    w, h = 26, 6
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    for k in range(rng.randrange(4, 8)):
        x, y = rng.randrange(1, w - 3), rng.randrange(1, h - 2)
        c.put(x, y, hexc('c8a040'))
        c.put(x + 1, y, hexc('9a7424'))
        if rng.random() < 0.5:
            c.put(x + 1, y + 1, hexc('7a5a1a'))
    save(name, c)


# --- lived-in dressing (stands on the floor against the wall; bottom row = floor contact) ------
def shadow_row(c, x0, x1, y):
    for x in range(x0, x1 + 1):
        c.put(x, y, (20, 14, 12, 110))


def plant_tall(name, seed, dead=False, fallen=False):
    w, h = 22, 40
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    pot, pot_dk = hexc('a8573a'), hexc('7a3a26')
    if fallen:                                                      # knocked over, soil spilled
        c.poly([(3, h - 9), (13, h - 12), (15, h - 4), (5, h - 1)], pot)
        c.line(3, h - 9, 13, h - 12, shade(pot, 1.2))
        c.line(5, h - 1, 15, h - 4, pot_dk)
        for x in range(12, 22):
            for y in range(h - 5, h):
                if rng.random() < 0.6 - (x - 12) * 0.04:
                    c.put(x, y, hexc('3a2a1e'))
        leaf = hexc('4a6a34') if not dead else hexc('7a6a3a')
        for k in range(10):
            x, y = rng.randrange(0, 12), rng.randrange(h - 14, h - 9)
            c.rect(x, y, x + 2, y, leaf)
        save(name, c)
        return
    shadow_row(c, 2, 19, h - 1)
    c.poly([(5, h - 14), (17, h - 14), (15, h - 2), (7, h - 2)], pot)
    c.rect(4, h - 16, 18, h - 14, shade(pot, 1.12))
    c.hline(4, 18, h - 13, pot_dk)
    c.vline(15, h - 12, h - 3, pot_dk)
    c.hline(6, 16, h - 16, hexc('3a2a1e'))
    stem = hexc('5a4a2a')
    for (x1, y1) in ((11, 6), (8, 12), (14, 10), (6, 20), (16, 18)):
        c.line(11, h - 16, x1, y1, stem)
    lcol = [hexc('3e6a30'), hexc('4e7e3a'), hexc('2e5226')] if not dead else [hexc('7a6a3a'), hexc('8a7a44'), hexc('5a4a2a')]
    for k in range(34 if not dead else 12):
        x, y = rng.randrange(3, 19), rng.randrange(2, h - 18)
        if dead and y < 12:
            continue
        col = rng.choice(lcol)
        c.rect(x, y, x + 2, y + 1, col)
        c.put(x + 1, y - 1, shade(col, 1.15))
    if dead:
        for k in range(5):
            c.put(rng.randrange(3, 20), h - 2, hexc('7a6a3a'))      # dropped leaves
    save(name, c)


def plant_small(name, seed):
    w, h = 14, 18
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    shadow_row(c, 1, 12, h - 1)
    c.rect(3, h - 8, 10, h - 2, hexc('d8d0c0'))
    c.vline(10, h - 8, h - 2, hexc('a8a090'))
    c.hline(3, 10, h - 8, hexc('eee8dc'))
    for k in range(18):
        x, y = rng.randrange(1, 13), rng.randrange(1, h - 8)
        c.rect(x, y, x + 1, y, rng.choice([hexc('3e6a30'), hexc('5a8a40'), hexc('4e7e3a')]))
    save(name, c)


def umbrella(name, seed):
    w, h = 10, 34
    c = canvas(w, h, seed)
    col = hexc('2a3a5a')
    c.line(3, h - 1, 6, 2, hexc('2a2622'))                          # shaft
    c.poly([(4, 4), (8, 6), (6, h - 6), (3, h - 8)], col)             # furled canopy
    c.line(4, 4, 3, h - 8, shade(col, 1.3))
    c.line(8, 6, 6, h - 6, shade(col, 0.7))
    c.rect(5, 0, 7, 2, hexc('5a3a22'))                               # hooked handle
    c.put(8, 1, hexc('5a3a22'))
    c.put(8, 2, hexc('5a3a22'))
    shadow_row(c, 1, 6, h - 1)
    save(name, c)


def shoes(name, seed, boots=False):
    w, h = 20, 12 if boots else 7
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    col = rng.choice([hexc('3a2a22'), hexc('5a3a2a'), hexc('2a2a30'), hexc('7a2a2a')])
    shadow_row(c, 0, w - 1, h - 1)
    for ox in (1, 10):
        if boots:
            c.rect(ox + 1, 0, ox + 4, h - 3, col)
            c.rect(ox + 1, h - 5, ox + 8, h - 2, col)
            c.hline(ox + 1, ox + 4, 0, shade(col, 1.3))
        else:
            c.rect(ox, h - 5, ox + 7, h - 2, col)
            c.rect(ox, h - 5, ox + 3, h - 4, shade(col, 0.6))
        c.hline(ox, ox + 8, h - 2, hexc('1a1614'))
        c.put(ox + 6, h - 4, shade(col, 1.35))
    save(name, c)


def shoe_rack(name, seed):
    w, h = 30, 18
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    wood = hexc('8a6444')
    shadow_row(c, 0, w - 1, h - 1)
    for y in (h - 2, h - 9):
        c.hline(1, w - 2, y, wood)
        c.hline(1, w - 2, y + 1, shade(wood, 0.6))
    c.vline(1, 2, h - 1, shade(wood, 0.8))
    c.vline(w - 2, 2, h - 1, shade(wood, 0.8))
    for shelf in (h - 3, h - 10):
        x = 3
        while x < w - 8:
            col = rng.choice([hexc('3a2a22'), hexc('c8c0b0'), hexc('2a3a5a'), hexc('8a2a2a'), hexc('5a4a3a')])
            c.rect(x, shelf - 3, x + 5, shelf, col)
            c.put(x + 4, shelf - 3, shade(col, 1.3))
            x += 7
    save(name, c)


def parcels(name, seed):
    w, h = 24, 22
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    card = hexc('b08858')
    shadow_row(c, 0, w - 1, h - 1)
    boxes = [(1, h - 12, 20, h - 1), (4, h - 20, 16, h - 12)]
    if rng.random() < 0.5:
        boxes[1] = (8, h - 19, 22, h - 12)
    for (x0, y0, x1, y1) in boxes:
        c.rect(x0, y0, x1, y1, card)
        c.hline(x0, x1, y0, shade(card, 1.15))
        c.vline(x1, y0, y1, shade(card, 0.75))
        c.hline(x0, x1, y1, shade(card, 0.65))
        mid = (x0 + x1) // 2
        c.vline(mid, y0, y1, hexc('c8b890'))                       # tape
        c.rect(x0 + 2, y0 + 3, x0 + 6, y0 + 5, hexc('eeeae0'))     # a label
    save(name, c)


def chair(name, seed, broken=False):
    w, h = 16, 30
    c = canvas(w, h, seed)
    wood, dk = hexc('7a5236'), hexc('4e321e')
    if broken:                                                     # on its side
        c.rect(1, h - 5, 14, h - 3, wood)
        c.hline(1, 14, h - 5, shade(wood, 1.2))
        c.rect(1, h - 16, 3, h - 3, wood)
        c.line(14, h - 3, 15, h - 1, dk)
        c.line(6, h - 3, 8, h - 1, dk)
        shadow_row(c, 0, w - 1, h - 1)
        save(name, c)
        return
    shadow_row(c, 0, w - 1, h - 1)
    c.rect(3, 0, 4, h - 2, wood)                                   # the back post, floor to top
    c.hline(3, 4, 0, shade(wood, 1.3))
    for y in (4, 9):                                               # back slats, edge-on
        c.rect(2, y, 5, y + 1, dk)
    c.rect(3, h - 14, 14, h - 12, wood)                            # the seat
    c.hline(3, 14, h - 14, shade(wood, 1.25))
    c.rect(13, h - 12, 14, h - 2, dk)                              # front leg
    c.rect(4, h - 12, 5, h - 2, dk)                                # back leg
    c.hline(5, 12, h - 6, shade(dk, 0.9))                          # a stretcher
    save(name, c)


def scooter(name, seed):
    w, h = 22, 22
    c = canvas(w, h, seed)
    shadow_row(c, 0, w - 1, h - 1)
    deck = hexc('c83a4a')
    c.rect(3, h - 6, 18, h - 5, deck)
    c.line(17, h - 6, 15, 2, hexc('8a8a90'))                       # stem
    c.hline(12, 18, 2, hexc('2a2a2a'))                             # bar
    for x in (4, 17):
        c.ellipse(x, h - 3, 2, 2, hexc('2a2a2a'))
        c.put(x, h - 3, hexc('8a8a8a'))
    save(name, c)


def suitcase(name, seed):
    w, h = 18, 26
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    col = rng.choice([hexc('2a3a4a'), hexc('5a2a2a'), hexc('3a3a30')])
    shadow_row(c, 0, w - 1, h - 1)
    c.rect(2, 6, 15, h - 2, col)
    c.hline(2, 15, 6, shade(col, 1.3))
    c.vline(15, 6, h - 2, shade(col, 0.7))
    for x in (5, 9, 12):
        c.vline(x, 8, h - 4, shade(col, 0.82))
    c.rect(6, 1, 11, 2, hexc('2a2a2a'))                            # handle
    c.vline(6, 1, 6, hexc('2a2a2a'))
    c.vline(11, 1, 6, hexc('2a2a2a'))
    save(name, c)


def shopping_bag(name, seed):
    w, h = 14, 18
    c = canvas(w, h, seed)
    shadow_row(c, 0, w - 1, h - 1)
    col = hexc('e8e4dc')
    c.poly([(2, 5), (12, 5), (13, h - 2), (1, h - 2)], col)
    c.line(2, 5, 1, h - 2, shade(col, 0.8))
    c.line(12, 5, 13, h - 2, shade(col, 0.75))
    c.rect(4, 8, 9, 11, hexc('3a7a4a'))                            # a printed logo
    for (x, y) in ((4, 4), (4, 3), (5, 2), (6, 2), (7, 2), (8, 3), (8, 4)):
        c.put(x, y, hexc('a8a49c'))
    c.rect(3, 2, 6, 4, hexc('d8a040'))                            # bread poking out
    save(name, c)


# --- wall paper things -------------------------------------------------------------------------
def kid_drawing(name, seed):
    w, h = 14, 12
    c = canvas(w, h, seed)
    rng = random.Random(seed)
    c.rect(0, 1, 13, 11, hexc('f2eee4'))
    c.hline(0, 13, 11, hexc('c8c4ba'))
    c.rect(1, 0, 3, 1, hexc('d8d8a0', 200))                        # tape
    c.rect(10, 0, 12, 1, hexc('d8d8a0', 200))
    c.ellipse(4, 4, 2, 2, hexc('e8c040'))                          # a sun
    c.hline(1, 12, 9, hexc('4a9a4a'))                              # grass
    for (x, y) in ((8, 5), (8, 6), (8, 7), (7, 8), (9, 8), (7, 6), (9, 6)):
        c.put(x, y, hexc('2a4aa0'))                                # a figure
    c.put(8, 4, hexc('c83a3a'))
    save(name, c)


def poster_missing(name, seed):
    w, h = 16, 20
    c = canvas(w, h, seed)
    c.rect(0, 0, 15, 19, hexc('eeeae0'))
    c.hline(0, 15, 19, hexc('c8c4ba'))
    c.rect(2, 1, 13, 3, hexc('2a2a2a'))                            # MISSING
    c.rect(4, 5, 11, 11, hexc('8a8478'))                           # a photo
    c.ellipse(7, 8, 2, 2, hexc('c8a88a'))
    for y in (13, 15, 17):
        c.hline(2, 13, y, hexc('8a8a86'))
    c.put(7, 0, hexc('c83a2c'))
    save(name, c)


def notice_quarantine(name, seed):
    w, h = 18, 22
    c = canvas(w, h, seed)
    c.rect(0, 0, 17, 21, hexc('f0e6a8'))
    c.hline(0, 17, 21, hexc('c8be88'))
    c.rect(1, 1, 16, 5, hexc('c8322a'))                            # a red banner
    for x in range(3, 15, 2):
        c.put(x, 3, hexc('f0e6a8'))
    for y in range(8, 20, 2):
        c.hline(2, 15 - (y % 4), y, hexc('4a4a44'))
    c.rect(1, 0, 3, 0, hexc('d8d8a0', 200))
    c.rect(14, 0, 16, 0, hexc('d8d8a0', 200))
    save(name, c)


def main():
    from PIL import Image
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith('.png') or f.endswith('.png.import'):
            os.remove(os.path.join(OUT, f))
    smear('smear_1', 1, 62, 18); smear('smear_2', 2, 44, 16); smear('smear_3', 3, 80, 20)
    slide('slide_1', 4); slide('slide_2', 5)
    handprint('hand_1', 6); handprint('hand_2', 7, dragged=True); handprint('hand_3', 8, pair=True)
    spatter('spatter_1', 9); spatter('spatter_2', 10)
    bullets('bullets_1', 11, 4); bullets('bullets_2', 12, 7); bullets('bullets_3', 13, 10, 44, 30)
    bullets('door_bullets', 14, 5, 22, 30)
    claws('claws_1', 15); claws('claws_2', 16)
    for i, t in enumerate(('HELP', 'GET OUT', 'DONT GO DOWN', 'THEY HEAR YOU', 'NO WAY OUT', 'STAY QUIET')):
        scrawl('scrawl_%d' % (i + 1), 20 + i, t)
    search_x('door_x', 30)
    handprint('door_hand', 31, dragged=True)
    pool('pool_1', 40, 34, 7); pool('pool_2', 41, 50, 9); pool('pool_3', 42, 24, 6)
    drag('drag_1', 43, 140); drag('drag_2', 44, 90)
    footprints('prints_1', 45)
    casings('casings_1', 46)
    plant_tall('plant_tall', 50); plant_tall('plant_dead', 51, dead=True)
    plant_tall('plant_fallen', 52, fallen=True)
    plant_small('plant_small', 53)
    umbrella('umbrella', 54)
    shoes('shoes', 55); shoes('boots', 56, boots=True)
    shoe_rack('shoe_rack', 57)
    parcels('parcels', 58)
    chair('chair', 59); chair('chair_down', 60, broken=True)
    scooter('scooter', 61)
    suitcase('suitcase', 62)
    shopping_bag('shopping_bag', 63)
    kid_drawing('kid_drawing', 64)
    poster_missing('poster_missing', 65)
    notice_quarantine('notice_quarantine', 66)
    # the contact sheet, each decal at 3x on a mid-tone wall swatch
    names = sorted(MADE)
    cols, cell = 6, 3 * 84
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * cell, rows * cell), (150, 138, 110, 255))
    for i, n in enumerate(names):
        im = MADE[n]
        s = min(3, (cell - 8) // max(im.size))
        big = im.resize((im.size[0] * s, im.size[1] * s), Image.NEAREST)
        x, y = (i % cols) * cell + 4, (i // cols) * cell + 4
        sheet.alpha_composite(big, (x, y))
    sheet.save(os.path.join(ROOT, 'docs', 'art_reference', 'corridor', 'corridor_decals.png'))
    print('wrote %d decals' % len(names))


if __name__ == '__main__':
    main()
