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


# --- wall paper things -------------------------------------------------------------------------
def building_notices():
    """What a building puts up — then what it put up once things went wrong (owner round 38: "a sign saying
    bins out Monday… very plain and basic for an announcement from building management"). All drawn by
    tools/art/wallart.py (its CORRIDOR_PAPER table is the one list of them): memos on the management's
    letterhead, safety plates with pictograms, hazard signs, a neighbour's note, missing / lost flyers with
    tear-off tabs, a child's drawing."""
    import wallart as W
    for name, fn, seed in W.CORRIDOR_PAPER:
        save(name, fn(seed))


def dead(name, seed, how, fought=False):
    """One of the dead on the corridor floor (owner round 21c — "sporadically there should be bodies
    across the building"), drawn by the rooms' own code (tools/art/nest.py: the purchased homeless
    pack's Death frame at 2x, greyed, bitten at the neck) with the blood that says how: 'pool' —
    lying in it; 'crawl' — a trail behind, bloody hands clawing along it, where they gave out. Head
    to the right (flip for the left); the body's floor line is the sprite's bottom row - 3.
    fought (round 22 — "our enemies dead nearby… that neighbour fought and killed one but died of their
    wounds"): one of THEM lies past their head, its head knocked off, and the weapon by their hand."""
    import nest
    rng = random.Random(seed)
    flat = [[True] * nest.H for _ in range(nest.W)]
    body, floor = nest.Layer(), nest.Layer()
    fx, fy = (150 if how == 'crawl' else 40), 120
    nest._bleed(floor, floor, rng, flat, flat, fx, fy, 1, how)
    nest._stain(body, rng, fx + 10, fx + nest.BODY_W - 6, fy, 2)
    nest._body(body, rng, fx, fy, 1)
    if fought:
        nest._weapon(body, rng, fx + rng.randint(40, 52), fy + 5, rng.choice((1, -1)), rng.choice(nest.WEAPONS))
        nest._zombie_dead(floor, body, rng, fx + nest.BODY_W + rng.randint(8, 18), fy + rng.randint(-2, 2), 1)
    img = floor.img.copy()
    img.alpha_composite(body.img)
    c = canvas(1, 1, seed)
    c.img = img.crop((img.getbbox()[0], img.getbbox()[1], img.getbbox()[2], fy + 6))
    c.px = c.img.load()
    save(name, c)


SHEETS = os.path.join(ROOT, 'assets', 'decal_sheets')


def sheet_groups(names, standing):
    """Which sheet each decal goes on (assets/decal_sheets/<group>.png)."""
    g = {'standing_props': [], 'notices': [], 'wall_horror': [], 'door_marks': [], 'floor_marks': [],
         'the_dead': []}
    for n in names:
        if n in standing:
            g['standing_props'].append(n)
        elif n.startswith('door_'):
            g['door_marks'].append(n)
        elif n.startswith('dead_'):
            g['the_dead'].append(n)
        elif n.startswith(('pool', 'drag', 'prints', 'casings')):
            g['floor_marks'].append(n)
        elif n.startswith(('notice', 'poster', 'kid_drawing')):
            g['notices'].append(n)
        else:
            g['wall_horror'].append(n)
    return {k: v for k, v in g.items() if v}


def contact_sheet(names, labels=True, cols=6, cell=3 * 84):
    """Each decal at up to 3x in a `cell`-square slot, its name just under it."""
    from PIL import Image, ImageDraw, ImageFont
    lab = 16 if labels else 0
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * cell, rows * (cell + lab)), (150, 138, 110, 255))
    d = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 12) if labels else None
    for i, n in enumerate(names):
        im = MADE[n]
        s = min(3, (cell - 8) // max(im.size))
        big = im.resize((im.size[0] * s, im.size[1] * s), Image.NEAREST)
        x, y = (i % cols) * cell + 4, (i // cols) * (cell + lab) + 4
        sheet.alpha_composite(big, (x, y))
        if labels:
            d.text((x, y + big.size[1] + 3), n, fill=(40, 34, 26, 255), font=font)
    return sheet


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
    import json
    import corridor_props                                          # the standing dressing, with geometry
    meta = corridor_props.build(save)
    with open(os.path.join(OUT, 'dressing.json'), 'w') as fh:
        json.dump({'note': 'tools/art/corridor_props.py: per standing prop — rule (door/open), depth on the '
                           'floor, contact (sprite row of its front floor contact)', 'props': meta},
                  fh, indent=1, sort_keys=True)
    building_notices()
    dead('dead_1', 70, 'pool'); dead('dead_2', 71, 'crawl'); dead('dead_3', 72, 'pool'); dead('dead_4', 73, 'crawl')
    dead('dead_5', 74, 'pool', fought=True); dead('dead_6', 75, 'pool', fought=True)
    # the contact sheets, each decal at 3x on a mid-tone wall swatch: one of everything for the docs,
    # and grouped + labelled copies in assets/decal_sheets/ (owner: "save the decal sheets into their own
    # folder in the assets folder too")
    names = sorted(MADE)
    all_sheet = contact_sheet(names, labels=False)
    all_sheet.save(os.path.join(ROOT, 'docs', 'art_reference', 'corridor', 'corridor_decals.png'))
    os.makedirs(SHEETS, exist_ok=True)
    for f in os.listdir(SHEETS):
        if f.endswith('.png'):
            os.remove(os.path.join(SHEETS, f))
    contact_sheet(names).save(os.path.join(SHEETS, 'all_decals.png'))
    groups = sheet_groups(names, set(meta))
    for g, members in groups.items():
        contact_sheet(members).save(os.path.join(SHEETS, g + '.png'))
    print('wrote %d decals' % len(names))


if __name__ == '__main__':
    main()
