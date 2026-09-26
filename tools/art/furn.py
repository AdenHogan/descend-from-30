"""Reusable furniture for the room-module variants (tools/art/*_variants.py).

Every piece takes a palette P = (base, light, dark, outline) so a variant restyles it, and draws
flat (no baked light — the engine lights it), with a soft contact shadow and its OWN outline so
overlapping pieces stay readable. Coordinates are module-local (320 x 144; wall/floor seam y 100,
walking line 129). Pieces against the back wall stand on y 99/100; pieces out in the room stand
on 108..122 (the nearer, the bigger y).
"""
from pixlib import hexc, shade, mix, rrect, light

WOOD = (hexc('5e3d28'), hexc('76513a'), hexc('472d1d'), hexc('27180f'))
PINE = (hexc('b58a55'), hexc('c9a06a'), hexc('93703f'), hexc('4a3620'))
TEAK = (hexc('8a6443'), hexc('9e7550'), hexc('6b4a31'), hexc('3a2718'))
METAL = (hexc('6f7572'), hexc('878d89'), hexc('565b59'), hexc('2e3130'))
WHITE = (hexc('dcd8cc'), hexc('ecE8de'), hexc('bdb8aa'), hexc('5e5a50'))
BOOKS = [hexc('7a2e28'), hexc('2f4a63'), hexc('5d6b3a'), hexc('8a6a3a'), hexc('4b3a5c'),
         hexc('b8a782'), hexc('3b5550'), hexc('6b4a36'), hexc('9c4f33')]
BRASS = hexc('b09456')
PAPER = hexc('d8cfb4')
PAPER_DK = hexc('b7ad92')
BLOOD = hexc('4a1d1b', 150)
DARK = hexc('24180f')


def chest(c, x0, x1, top, base, P, drawers=3, open_row=None, knobs=BRASS, legs=True):
    """A chest of drawers / cabinet against the wall: a top lip, drawers, feet. `open_row` pulls
    that drawer out (its dark inside shows)."""
    b, lt, dk, out = P
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 2, 2, 100)
    c.rect(x0 - 1, top, x1 + 1, top + 1, lt)
    c.hline(x0 - 1, x1 + 1, top, out)
    foot = 3 if legs else 0
    c.box(x0, top + 2, x1, base - foot, b, out)
    h = (base - foot - top - 4) // drawers
    for i in range(drawers):
        y0 = top + 4 + i * h
        y1 = y0 + h - 2
        if i == open_row:
            c.rect(x0 + 2, y0, x1 - 2, y0 + 1, DARK)
            c.box(x0 + 1, y0 + 2, x1 - 1, y1 + 1, b, out)
            c.hline(x0 + 2, x1 - 2, y0 + 3, lt)
        else:
            c.box(x0 + 2, y0, x1 - 2, y1, b, dk)
            c.hline(x0 + 3, x1 - 3, y0 + 1, lt)
        my = (y0 + y1) // 2 + (1 if i == open_row else 0)
        if x1 - x0 > 24:
            c.rect(x0 + 6, my, x0 + 8, my, knobs)
            c.rect(x1 - 8, my, x1 - 6, my, knobs)
        else:
            c.rect((x0 + x1) // 2 - 1, my, (x0 + x1) // 2 + 1, my, knobs)
    if legs:
        for fx in (x0 + 1, x1 - 3):
            c.rect(fx, base - 2, fx + 2, base, out)


def shelves(c, x0, x1, top, base, P, rows, rng, fill=0.85, back=DARK):
    """An open shelving unit / bookcase: uprights, shelf boards at `rows` (y of each board), books
    standing on each board (some gaps, one leaning)."""
    b, lt, dk, out = P
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 2, 2, 100)
    c.box(x0, top, x1, base - 1, b, out)
    c.rect(x0 + 2, top + 2, x1 - 2, base - 3, back)
    prev = top + 2
    for ry in rows:
        x = x0 + 3
        while x < x1 - 3:
            bw = rng.choice((2, 2, 3, 3, 4))
            if x + bw > x1 - 3:
                break
            if rng.random() > fill:
                x += bw + 1
                continue
            bh = min(rng.randint(7, 11), ry - prev - 2)
            col = rng.choice(BOOKS)
            c.rect(x, ry - bh, x + bw - 1, ry - 1, col)
            c.hline(x, x + bw - 1, ry - bh + 1, shade(col, 1.2))
            x += bw
        c.rect(x0 + 2, ry, x1 - 2, ry + 1, lt)
        prev = ry + 2
    c.rect(x0 + 2, base - 3, x1 - 2, base - 2, dk)


def leaning_book(c, x_foot, shelf_y, h, w, col, lean=-1, slope=0.34):
    """A book leaning over against its neighbour (owner round 14: the old slanted ones "look like
    extended blurred shapes"): drawn as a crisp slanted block — every row exactly `w` px, stepping one
    pixel sideways every ~3 rows — with a dark spine edge on the side it leans toward, a pale page
    edge along the top, and its foot flat on the shelf at x_foot..x_foot+w-1. lean -1 leans left."""
    dk, lt = shade(col, 0.62), shade(col, 1.18)
    rows = int(h * 0.94)                                   # a tilted book stands a touch lower
    for r in range(rows):
        off = int(round(r * slope)) * lean
        y = shelf_y - 1 - r
        x0 = x_foot + off
        c.hline(x0, x0 + w - 1, y, col)
        c.put(x0 if lean < 0 else x0 + w - 1, y, dk)       # the edge it leans toward, in shadow
        if r == rows - 1:
            c.hline(x0, x0 + w - 1, y, hexc('e6ddc8'))     # the page edge
        elif r == rows - 3:
            c.hline(x0 + 1, x0 + w - 2, y, lt)             # a band on the spine


# --- POSTERS you can read (owner round 14: abstract colour-block posters "don't really make any sense")
FONT3 = {  # 3x5 capitals
    'A': ['010', '101', '111', '101', '101'], 'C': ['011', '100', '100', '100', '011'],
    'D': ['110', '101', '101', '101', '110'], 'E': ['111', '100', '110', '100', '111'],
    'G': ['011', '100', '101', '101', '011'], 'H': ['101', '101', '111', '101', '101'],
    'I': ['1', '1', '1', '1', '1'], 'K': ['101', '101', '110', '101', '101'],
    'L': ['100', '100', '100', '100', '111'], 'M': ['10001', '11011', '10101', '10001', '10001'],
    'N': ['1001', '1101', '1011', '1001', '1001'], 'O': ['010', '101', '101', '101', '010'],
    'P': ['110', '101', '110', '100', '100'], 'R': ['110', '101', '110', '101', '101'],
    'S': ['011', '100', '010', '001', '110'], 'T': ['111', '010', '010', '010', '010'],
    'U': ['101', '101', '101', '101', '111'], 'V': ['101', '101', '101', '101', '010'],
    'W': ['10001', '10001', '10101', '11011', '10001'], 'Y': ['101', '101', '010', '010', '010'],
    ' ': ['0', '0', '0', '0', '0'],
    'B': ['110', '101', '110', '101', '110'], 'F': ['111', '100', '110', '100', '100'],
    'J': ['001', '001', '001', '101', '010'], 'Q': ['010', '101', '101', '110', '011'],
    'X': ['101', '101', '010', '101', '101'], 'Z': ['111', '001', '010', '100', '111'],
    '0': ['111', '101', '101', '101', '111'], '1': ['01', '11', '01', '01', '01'],
    '2': ['110', '001', '010', '100', '111'], '3': ['110', '001', '010', '001', '110'],
    '4': ['101', '101', '111', '001', '001'], '5': ['111', '100', '110', '001', '110'],
    '6': ['011', '100', '110', '101', '010'], '7': ['111', '001', '010', '010', '010'],
    '8': ['010', '101', '010', '101', '010'], '9': ['010', '101', '011', '001', '110'],
    '!': ['1', '1', '1', '0', '1'], '?': ['110', '001', '010', '000', '010'],
    '-': ['00', '00', '11', '00', '00'], '.': ['0', '0', '0', '0', '1'],
    "'": ['1', '1', '0', '0', '0'], ':': ['0', '1', '0', '1', '0'], '/': ['001', '001', '010', '100', '100'],
}


def text3(c, x, y, word, col):
    """Draw `word` in the 3x5 pixel capitals; returns its width."""
    x0 = x
    for ch in word:
        g = FONT3.get(ch, FONT3[' '])
        for gy, row in enumerate(g):
            for gx, v in enumerate(row):
                if v == '1':
                    c.put(x + gx, y + gy, col)
        x += len(g[0]) + 1
    return x - x0 - 1


def text3_width(word):
    return sum(len(FONT3.get(ch, FONT3[' '])[0]) + 1 for ch in word) - 1


def _paper(c, x0, y0, x1, y1, bg):
    c.rect(x0, y0, x1, y1, bg)
    c.rect(x0 + 1, y1 + 1, x1 + 1, y1 + 1, hexc('000000', 60))          # a hair of shadow
    for tx in (x0, x1):
        c.rect(tx - 1, y0 - 1, tx + 1, y0, hexc('f0ead2', 190))          # tape / pins


def poster_gig(c, x0, y0, x1, y1, title='LIVE', paper=hexc('e4d8bc'), ink=hexc('b8332a'), spot=hexc('e0913a')):
    """A gig poster: the title, a guitarist silhouette in a spotlight, the small print."""
    _paper(c, x0, y0, x1, y1, paper)
    cx = (x0 + x1) // 2
    text3(c, cx - text3_width(title) // 2, y0 + 3, title, ink)
    cy = (y0 + y1) // 2 + 3
    r = max(4, min(x1 - x0, y1 - y0) // 4)
    c.ellipse(cx, cy, r + 1, r, spot)
    blk = hexc('1e1a1c')
    c.rect(cx - 1, cy - r + 1, cx + 1, cy - r + 3, blk)
    c.rect(cx - 2, cy - r + 4, cx + 2, cy + 1, blk)
    c.line(cx - 1, cy + 2, cx - 3, cy + r, blk); c.line(cx + 1, cy + 2, cx + 3, cy + r, blk)
    c.line(cx - 5, cy + 1, cx + 5, cy - 4, blk)
    c.rect(cx - 5, cy - 1, cx - 3, cy + 2, blk)
    c.hline(x0 + 3, x1 - 3, y1 - 4, hexc('7a6e5c'))
    c.hline(x0 + 5, x1 - 5, y1 - 2, hexc('7a6e5c'))


def poster_film(c, x0, y0, x1, y1, title='NIGHT', torn=False):
    """A horror-film poster: a night sky, a big pale moon, a black treeline and a reaching hand, the
    title in red on a black band at the foot."""
    _paper(c, x0, y0, x1, y1, hexc('1c2440'))
    for y in range(y0, y1 - 7):
        t = (y - y0) / float(max(1, y1 - 7 - y0))
        c.hline(x0, x1, y, mix(hexc('1c2440'), hexc('3a2a4a'), t))
    mx, my = (x0 + x1) // 2 + 3, y0 + 9
    c.ellipse(mx, my, 6, 6, hexc('e8e2c8'))
    c.put(mx - 2, my - 1, hexc('c8c2a8')); c.put(mx + 2, my + 2, hexc('c8c2a8'))
    for x in range(x0, x1 + 1):                                          # a treeline
        h = 3 + (x * 7) % 5
        c.vline(x, y1 - 8 - h, y1 - 8, hexc('0e0e14'))
    hx = (x0 + x1) // 2 - 3                                                # the hand, reaching up
    c.rect(hx, y1 - 14, hx + 3, y1 - 8, hexc('0e0e14'))
    for k in range(4):
        c.vline(hx + k, y1 - 18 + (k % 2), y1 - 14, hexc('0e0e14'))
    c.rect(x0, y1 - 7, x1, y1, hexc('0e0e14'))
    text3(c, (x0 + x1) // 2 - text3_width(title) // 2, y1 - 6, title, hexc('c8322a'))
    if torn:                                                               # the bottom corner torn off
        for j in range(6):
            for i in range(6 - j):
                c.put(x1 - i, y1 - j, hexc('ece6d4') if i else hexc('c8c0aa'))


def poster_map(c, x0, y0, x1, y1):
    """A world map: pale sea, green-khaki continents, a pin or two."""
    _paper(c, x0, y0, x1, y1, hexc('a8c4d0'))
    c.rect(x0, y0, x1, y0 + 1, hexc('e8e2d0')); c.rect(x0, y1 - 1, x1, y1, hexc('e8e2d0'))
    w, h = x1 - x0, y1 - y0
    land = hexc('a8b070')
    for (fx, fy, rx, ry) in ((0.22, 0.35, 0.12, 0.18), (0.30, 0.68, 0.06, 0.16), (0.52, 0.32, 0.08, 0.12),
                             (0.55, 0.62, 0.07, 0.16), (0.72, 0.36, 0.16, 0.16), (0.84, 0.72, 0.07, 0.07)):
        c.ellipse(x0 + int(fx * w), y0 + int(fy * h), max(1, int(rx * w)), max(1, int(ry * h)), land)
    c.put(x0 + int(0.24 * w), y0 + int(0.33 * h), hexc('c0302a'))
    c.put(x0 + int(0.74 * w), y0 + int(0.40 * h), hexc('c0302a'))


def poster_game(c, x0, y0, x1, y1, title='SPACE'):
    """A game poster: stars, a ringed planet, a little ship, the title."""
    _paper(c, x0, y0, x1, y1, hexc('14142a'))
    for k in range(18):
        c.put(x0 + 1 + (k * 13) % max(1, x1 - x0 - 1), y0 + 1 + (k * 7) % max(1, y1 - y0 - 8), hexc('d8d8f0'))
    px, py = x0 + (x1 - x0) // 3, y0 + (y1 - y0) // 2
    c.ellipse(px, py, 5, 5, hexc('d98a4a'))
    c.hline(px - 8, px + 8, py, hexc('e8c890')); c.hline(px - 7, px + 7, py + 1, hexc('b86a3a'))
    sx, sy = x1 - 8, y0 + 7
    c.poly([(sx, sy), (sx + 5, sy + 2), (sx, sy + 4)], hexc('c8d0e0'))
    c.put(sx - 1, sy + 2, hexc('e0702c')); c.put(sx - 2, sy + 2, hexc('e0a02c'))
    text3(c, (x0 + x1) // 2 - text3_width(title) // 2, y1 - 6, title, hexc('4ec8e0'))


def table_front(c, x0, x1, top, base, P, depth=5, cloth=None, cloth_dk=None, hem=None):
    """A table standing out in the room, seen from the front and a little above: the top surface
    (`depth` rows), an apron, four legs (the far pair set back + darker). Optional cloth."""
    b, lt, dk, out = P
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 3, 3, 110)
    c.rect(x0 + 6, top + depth + 3, x0 + 7, base - 3, shade(dk, 0.8))      # far legs
    c.rect(x1 - 7, top + depth + 3, x1 - 6, base - 3, shade(dk, 0.8))
    c.rect(x0 + 2, top + depth + 2, x0 + 4, base, dk)                         # near legs
    c.rect(x1 - 4, top + depth + 2, x1 - 2, base, dk)
    if cloth is None:
        c.rect(x0, top, x1, top + depth, lt)
        c.hline(x0, x1, top, out)
        c.rect(x0, top + depth + 1, x1, top + depth + 3, b)
        c.hline(x0, x1, top + depth + 3, out)
    else:
        c.rect(x0 - 1, top, x1 + 1, top + depth, cloth)
        c.hline(x0 - 1, x1 + 1, top, cloth_dk)
        hem = hem or (top + depth + 7)
        for x in range(x0 - 1, x1 + 2):
            h = hem + (1 if (x // 6) % 3 == 0 else 0)
            c.vline(x, top + depth + 1, h, cloth_dk if (x - x0) % 11 in (0, 1) else cloth)
        c.hline(x0 - 1, x1 + 1, top + depth + 1, shade(cloth, 1.06))


def chair_back(c, x0, top, bottom, P, width=18, slats=2):
    """A chair tucked in behind a table: only its back shows above the table top."""
    b, lt, dk, out = P
    c.rect(x0, top, x0 + 2, bottom, b)
    c.rect(x0 + width - 2, top, x0 + width, bottom, b)
    c.rect(x0, top, x0 + width, top + 2, lt)
    c.hline(x0, x0 + width, top, out)
    for i in range(slats):
        y = top + 6 + i * 6
        if y < bottom - 1:
            c.rect(x0 + 3, y, x0 + width - 3, y + 1, dk)


def side_chair(c, x0, base, P, facing_right=True):
    """A chair seen exactly side-on (14px deep): back post up to the top rail, seat plank, front
    leg, a stretcher."""
    b, lt, dk, out = P
    d = 1 if facing_right else -1
    back = x0 if facing_right else x0 + 13
    front = x0 + 12 if facing_right else x0 + 1
    seat_y = base - 17
    c.shadow(x0 + 7, base, 9, 2, 110)
    c.rect(min(back, back + d), base - 40, max(back, back + d), base, b)
    c.vline(back + d, base - 40, base, dk)
    for ry in (base - 36, base - 30, base - 24):
        c.rect(back + d, ry, back + 2 * d, ry + 1, dk)
    c.rect(min(back, front), seat_y, max(back, front) + 1, seat_y + 2, b)
    c.hline(min(back, front), max(back, front) + 1, seat_y, lt)
    c.rect(min(front, front + d), seat_y + 3, max(front, front + d), base, b)
    c.vline(front + d, seat_y + 3, base, dk)
    c.hline(min(back, front) + 1, max(back, front), base - 6, dk)


def cardboard_box(c, x0, x1, top, base, open_flaps=True, label=True, col=hexc('a88a5c')):
    dk = shade(col, 0.75)
    c.shadow((x0 + x1) // 2, base, (x1 - x0) // 2 + 2, 2, 110)
    c.box(x0, top, x1, base, col, dk)
    c.hline(x0 + 1, x1 - 1, top + 1, shade(col, 1.1))
    if open_flaps:
        c.poly([(x0, top), (x0 - 4, top - 4), (x0 - 3, top - 5), (x0 + 1, top - 1)], dk)
        c.poly([(x1, top), (x1 + 4, top - 5), (x1 + 5, top - 4), (x1 + 1, top + 1)], col)
    else:
        c.hline(x0, x1, top + (base - top) // 3, shade(col, 0.9))
    if label:
        c.rect(x0 + 4, top + (base - top) // 2 - 1, x1 - 4, top + (base - top) // 2 + 1, PAPER)


def poster(c, x0, y0, x1, y1, bg, fg, accent=None, torn=False):
    c.rect(x0, y0, x1, y1, bg)
    c.rect(x0 + 2, y0 + 2, x1 - 2, y0 + (y1 - y0) * 3 // 5, fg)
    if accent is not None:
        c.rect(x0 + 2, y1 - 5, x1 - 2, y1 - 4, accent)
        c.rect(x0 + 2, y1 - 3, (x0 + x1) // 2, y1 - 2, accent)
    for (tx, ty) in ((x0, y0), (x1, y0)):
        c.put(tx, ty, PAPER)
    if torn:
        c.poly([(x1 - 6, y1), (x1, y1 - 7), (x1, y1)], shade(bg, 0.6))
    else:
        c.put(x0, y1, PAPER)
        c.put(x1, y1, PAPER)


def frame_pic(c, x0, y0, x1, y1, fr, fill, wire=True):
    c.box(x0, y0, x1, y1, fr, shade(fr, 0.55))
    c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, fill)
    if wire:
        mx = (x0 + x1) // 2
        c.line(x0 + 3, y0, mx, y0 - 6, shade(fr, 0.55))
        c.line(x1 - 3, y0, mx, y0 - 6, shade(fr, 0.55))


def rug(c, x0, x1, y0, y1, col, border, pattern=None, fringe=None):
    inset = 6
    c.poly([(x0 + inset, y0), (x1 - inset, y0), (x1, y1), (x0, y1)], border)
    c.poly([(x0 + inset + 2, y0 + 2), (x1 - inset - 2, y0 + 2), (x1 - 3, y1 - 2), (x0 + 3, y1 - 2)], col)
    if pattern is not None:
        for x in range(x0 + 12, x1 - 10, 10):
            c.put(x, (y0 + y1) // 2, pattern)
            c.put(x + 1, (y0 + y1) // 2 + 1, pattern)
    if fringe is not None:
        for x in range(x0, x1 + 1, 2):
            c.put(x, y1 + 1, fringe)


def floor_lamp(c, x, top, base, shade_col, pole):
    c.shadow(x, base + 1, 6, 2, 90)
    c.poly([(x - 4, top), (x + 4, top), (x + 8, top + 11), (x - 8, top + 11)], shade_col)
    c.hline(x - 8, x + 8, top + 11, shade(shade_col, 0.8))
    c.vline(x, top + 12, base - 1, pole)
    c.ellipse(x, base, 4, 1, pole)
    light(x, top + 8, 'floor')


def candle(c, x, base, h=5):
    c.rect(x - 1, base - h, x + 1, base, hexc('e3dcc6'))
    c.put(x, base - h - 1, hexc('3a2a1a'))
    c.put(x + 1, base, hexc('d8cfb4'))


def potted_plant(c, cx, base, dead=False, big=False):
    pot = hexc('9a5a3a')
    leaf = [hexc('7a6a3e'), hexc('5f5231')] if dead else [hexc('4d6a3c'), hexc('5e8240')]
    h = 30 if big else 18
    c.shadow(cx, base, 8, 2, 90)
    c.poly([(cx - 6, base - 12), (cx + 6, base - 12), (cx + 5, base), (cx - 5, base)], pot)
    c.hline(cx - 7, cx + 7, base - 13, shade(pot, 1.1))
    for i, (dx, dy) in enumerate(((-9, -h), (-4, -h - 6), (3, -h - 4), (9, -h + 2), (-11, -h + 8), (11, -h + 10))):
        col = leaf[i % 2]
        c.line(cx, base - 13, cx + dx, base + dy, col)
        c.ellipse(cx + dx, base + dy, 2, 3, col)


# --- walls + floors --------------------------------------------------------------------------
W_ = 320


def wall_plain(c, base, crown_col, skirt, rail=None, rail_y=18, texture=None, dado=None, dado_y=60):
    """A painted wall: crown moulding (hidden under the ceiling slab, rows 0..9), an optional
    picture rail, an optional dado (lower wall colour below a rail at dado_y), the skirting."""
    c.rect(0, 0, W_ - 1, 93, base)
    if texture is not None:
        for y in range(6, 93):
            for x in range(W_):
                if (x * 7 + y * 11 + (x * y) % 7) % 29 == 0:
                    c.put(x, y, texture)
    c.rect(0, 0, W_ - 1, 4, crown_col)
    c.hline(0, W_ - 1, 4, shade(crown_col, 1.2))
    c.hline(0, W_ - 1, 5, shade(crown_col, 0.8))
    c.dither(0, 6, W_ - 1, 10, shade(base, 0.9), 0.5)
    if rail is not None:
        c.rect(0, rail_y, W_ - 1, rail_y + 1, rail)
        c.hline(0, W_ - 1, rail_y, shade(rail, 1.15))
    if dado is not None:
        c.rect(0, dado_y, W_ - 1, 93, dado)
        c.rect(0, dado_y, W_ - 1, dado_y + 2, shade(dado, 0.75))
        c.hline(0, W_ - 1, dado_y, shade(dado, 1.1))
    c.rect(0, 94, W_ - 1, 99, skirt)
    c.hline(0, W_ - 1, 94, shade(skirt, 1.2))
    c.hline(0, W_ - 1, 99, shade(skirt, 0.5))


def wall_motif(c, motif, motif2, y0=14, y1=90, step_x=16, step_y=12):
    """A small repeating wallpaper motif (a sprig/flower) on a staggered grid."""
    for y in range(y0, y1, step_y):
        off = 0 if ((y - y0) // step_y) % 2 == 0 else step_x // 2
        for x in range(off + 4, W_, step_x):
            c.put(x, y, motif)
            c.put(x - 1, y + 1, motif)
            c.put(x + 1, y + 1, motif)
            c.put(x, y + 2, motif2)


def floor_planks(c, cols, seam, hi=None):
    """Boards along the room, rows taller toward the viewer, one plank end per row every 32px."""
    rows = [101, 104, 108, 113, 119, 126, 134, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        col = cols[r % len(cols)]
        c.rect(0, y0, W_ - 1, y1, col)
        c.hline(0, W_ - 1, y0, hi or shade(col, 1.08))
        c.hline(0, W_ - 1, y1, seam)
        for x in range((r * 13) % 32, W_, 32):
            c.vline(x, y0 + 1, y1, seam)
        for k in range(3):
            gx0 = (r * 7 + k * 11) % 32
            gy = y0 + 1 + (r + k) % max(1, y1 - y0 - 1)
            for gx in range(gx0 - 32, W_, 32):
                c.hline(max(gx, 0), min(gx + 4, W_ - 1), gy, shade(col, 0.9))
    c.hline(0, W_ - 1, 100, shade(cols[0], 0.5))
    c.dither(0, 101, W_ - 1, 102, hexc('1f1812', 90), 0.5)


def floor_carpet(c, base, lt, dk, worn=None):
    c.rect(0, 100, W_ - 1, 143, base)
    for y in range(102, 144):
        for x in range(W_):
            k = (x * 7 + y * 13) % 32
            if k in (3, 19):
                c.put(x, y, dk)
            elif k == 11:
                c.put(x, y, lt)
    if worn is not None:
        for y in range(124, 136):
            for x in range(W_):
                if (x + 2 * y) % 4 == 0:
                    c.put(x, y, worn)
    c.hline(0, W_ - 1, 100, shade(base, 0.6))
    c.hline(0, W_ - 1, 101, shade(base, 0.8))


def floor_lino(c, a, b, size=16, line=None):
    rows = [100, 105, 111, 118, 126, 135, 144]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1] - 1
        for x in range(0, W_, size):
            c.rect(x, y0, x + size - 1, y1, a if ((x // size) + r) % 2 else b)
        if line is not None:
            c.hline(0, W_ - 1, y0, line)
    c.hline(0, W_ - 1, 100, shade(a, 0.5))
    c.hline(0, W_ - 1, 101, shade(a, 0.72))


def moved(c, fn, dx, dy):
    """Draw `fn` on its own transparent layer and composite it shifted by (dx, dy) — to put a piece
    (with its shadow) somewhere else without rewriting every coordinate in it."""
    from PIL import Image
    from pixlib import Canvas, push_light_offset, pop_light_offset
    lyr = Canvas(w=c.w, h=c.h, bg=(0, 0, 0, 0), seed=11)
    push_light_offset(dx, dy)
    try:
        fn(lyr)
    finally:
        pop_light_offset()
    out = Image.new('RGBA', (c.w, c.h), (0, 0, 0, 0))
    out.paste(lyr.img, (dx, dy), lyr.img)
    c.img.alpha_composite(out)
    c.px = c.img.load()


def file_shelf(c, x0, x1, top, base, P, rng):
    """A small two-tier shelf for box files: files standing upright on the top tier (spine
    labels, finger holes), a few lying flat on the bottom tier. Stands on the floor at the wall."""
    b, lt, dk, out = P
    mid = (top + base) // 2
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 2, 2, 100)
    c.box(x0, top, x1, base - 1, b, out)
    c.rect(x0 + 2, top + 2, x1 - 2, base - 3, DARK)
    cols = [hexc('2f4a63'), hexc('7a2e28'), hexc('5d6b3a'), hexc('2f4a63'), hexc('8a6a3a'), hexc('4b3a5c')]
    x = x0 + 3
    i = 0
    while x + 4 < x1 - 2:                                    # upright files on the top tier
        col = cols[(i + rng.randrange(0, 2)) % len(cols)]
        h = min(mid - top - 4, rng.choice((11, 12, 12)))
        c.rect(x, mid - h, x + 4, mid - 1, col)
        c.vline(x, mid - h, mid - 1, shade(col, 1.2))
        c.rect(x + 1, mid - h + 2, x + 3, mid - h + 4, hexc('e6e0cc'))     # the spine label
        c.put(x + 2, mid - 4, hexc('141010'))                              # finger hole
        x += 5
        i += 1
    c.rect(x0 + 2, mid, x1 - 2, mid + 1, lt)                   # the middle shelf
    for k in range(3):                                         # files lying flat below
        col = cols[(k * 2 + 1) % len(cols)]
        y = base - 6 - k * 4
        xs = x0 + 3 + (k % 2)
        c.rect(xs, y, x1 - 4 - (k % 2) * 2, y + 3, col)
        c.hline(xs, x1 - 4 - (k % 2) * 2, y, shade(col, 1.2))
        c.rect(xs + 2, y + 1, xs + 6, y + 2, hexc('e6e0cc'))
    c.rect(x0 + 2, base - 3, x1 - 2, base - 2, dk)


def side_cabinet(c, x0, x1, top, base, P):
    """A low closed cabinet (two doors, knobs) — something to put things ON instead of the floor."""
    b, lt, dk, out = P
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 2, 2, 100)
    c.box(x0, top, x1, base - 1, b, out)
    c.hline(x0 + 1, x1 - 1, top + 1, lt)
    mid = (x0 + x1) // 2
    c.vline(mid, top + 3, base - 4, dk)
    for (a, e) in ((x0 + 2, mid - 1), (mid + 1, x1 - 2)):
        c.box(a, top + 3, e, base - 4, b, dk)
    c.put(mid - 2, (top + base) // 2, lt)
    c.put(mid + 2, (top + base) // 2, lt)
    c.rect(x0 + 1, base - 3, x1 - 1, base - 2, dk)


def book_stack(c, x0, top_y, widths, cols, fallen=None):
    """Books lying flat in a stack whose TOP surface rests at top_y (sitting on furniture)."""
    for i, (w_, col) in enumerate(zip(widths, cols)):
        y = top_y - 3 - i * 3
        x = x0 + (i % 2) * 2
        c.rect(x, y, x + w_, y + 2, col)
        c.hline(x, x + w_, y, shade(col, 1.18))
        c.vline(x + w_, y, y + 2, shade(col, 0.75))


def magazine_rack(c, x0, x1, top, base, metal=None, papers=None):
    """A wire magazine rack on the floor, newspapers folded into it, sticking up over its rim."""
    metal = metal or hexc('3a3a40')
    papers = papers or [hexc('e6e0cc'), hexc('cfc5a6'), hexc('d9d2bc'), hexc('b8ae94')]
    c.shadow((x0 + x1) // 2, base + 1, (x1 - x0) // 2 + 2, 2, 100)
    for i, col in enumerate(papers):                             # the papers, standing folded
        px0 = x0 + 2 + i * ((x1 - x0 - 4) // len(papers))
        c.rect(px0, top - 7 + (i % 2) * 2, px0 + (x1 - x0 - 4) // len(papers), base - 3, col)
        c.hline(px0, px0 + (x1 - x0 - 4) // len(papers), top - 7 + (i % 2) * 2, shade(col, 1.08))
        c.vline(px0, top - 7 + (i % 2) * 2, base - 3, shade(col, 0.8))
    c.hline(x0, x1, top, metal)                                  # the wire basket over them
    c.hline(x0, x1, base - 3, metal)
    for x in range(x0, x1 + 1, 3):
        c.vline(x, top, base - 3, metal)
    c.line(x0, base - 3, x0 - 1, base, metal)                    # feet
    c.line(x1, base - 3, x1 + 1, base, metal)


# --- LIGHT FIXTURES (owner round 14) ---------------------------------------------------------------
# Each draws the fixture UNLIT (the engine lights it) and registers its bulb (pixlib.light) — the
# runtime (scripts/apartment_lights.gd) decides per apartment + run whether it's on, steady,
# flickering or cutting out. Ceiling fixtures hang from y 0 (the ceiling line); keep them out of the
# window boxes' columns (x 50-94, 226-270) when they hang lower than y 10.
LAMP_SHADES = {'cream': (hexc('d9c9a0'), hexc('b7a67c')), 'rose': (hexc('c98f8a'), hexc('a06a66')),
               'green': (hexc('4e7a5a'), hexc('365a40')), 'mustard': (hexc('c9a03a'), hexc('9c7a28')),
               'white': (hexc('e6e0d0'), hexc('bdb6a4')), 'orange': (hexc('d0763a'), hexc('a65a28')),
               'teal': (hexc('4f8a86'), hexc('356662'))}


def table_lamp(c, x, surface, shade='cream', base=None, tall=False):
    """A table lamp standing on a surface (a desk, the top of a chest, a coffee / side table):
    a small foot, a stem, a tapered fabric shade. `surface` = the y the foot stands on."""
    sc, sd = LAMP_SHADES[shade]
    bc = base or hexc('8a6a44')
    h = 8 if tall else 5
    c.rect(x - 2, surface - 1, x + 2, surface, bc)                       # the foot
    c.hline(x - 2, x + 2, surface, shade_col(bc, 0.7))
    c.vline(x, surface - 1 - h, surface - 2, bc)                          # the stem
    top = surface - 2 - h - 7
    c.poly([(x - 3, top), (x + 3, top), (x + 5, top + 7), (x - 5, top + 7)], sc)
    c.hline(x - 5, x + 5, top + 7, sd)
    c.hline(x - 3, x + 3, top, shade_col(sc, 1.08))
    light(x, top + 5, 'table')


def desk_lamp(c, x, surface, col=None, facing=1):
    """An angled desk lamp (anglepoise): a heavy foot, two arms, a cone head tipped at the desk."""
    k = col or hexc('3a3a40')
    c.rect(x - 3, surface - 1, x + 3, surface, k)
    c.line(x, surface - 2, x - 2 * facing, surface - 9, k)
    c.line(x - 2 * facing, surface - 9, x + 4 * facing, surface - 14, k)
    hx = x + 6 * facing
    c.poly([(hx - 3, surface - 16), (hx + 3, surface - 16), (hx + 4, surface - 11), (hx - 4, surface - 11)], k)
    c.hline(hx - 4, hx + 4, surface - 11, shade_col(k, 1.4))
    light(hx, surface - 11, 'desk')


def pendant(c, x, drop=24, shade='cream', dome=False):
    """A pendant hanging from the ceiling: a cord and a shade (a cone, or a dome)."""
    sc, sd = LAMP_SHADES[shade]
    c.vline(x, 0, drop - 6, hexc('2a2622'))
    if dome:
        c.ellipse(x, drop - 2, 7, 4, sc)
        c.rect(x - 7, drop - 2, x + 7, drop, sc)
        c.hline(x - 7, x + 7, drop, sd)
    else:
        c.poly([(x - 2, drop - 6), (x + 2, drop - 6), (x + 7, drop), (x - 7, drop)], sc)
        c.hline(x - 7, x + 7, drop, sd)
    c.put(x, drop + 1, hexc('f0e6c8'))                                      # the bulb peeking out
    light(x, drop + 1, 'pendant')


def bare_bulb(c, x, drop=26):
    """A bare bulb on a flex — the cheap / stripped-out flat."""
    c.vline(x, 0, drop - 3, hexc('2a2622'))
    c.rect(x - 1, drop - 3, x + 1, drop - 2, hexc('6a6a66'))
    c.ellipse(x, drop, 2, 2, hexc('e6e0cc'))
    light(x, drop, 'bulb')


def flush_light(c, x):
    """A flush ceiling dome."""
    c.ellipse(x, 1, 8, 3, hexc('e6e0d0'))
    c.hline(x - 8, x + 8, 0, hexc('bdb6a4'))
    c.hline(x - 6, x + 6, 3, hexc('c9c2b0'))
    light(x, 4, 'flush')


def tube_light(c, x, w=34):
    """A fluorescent batten on the ceiling (kitchens, home offices)."""
    c.rect(x - w // 2, 0, x + w // 2, 2, hexc('c9c6bc'))
    c.hline(x - w // 2 + 1, x + w // 2 - 1, 3, hexc('eef0ec'))
    c.put(x - w // 2, 3, hexc('8a8880')); c.put(x + w // 2, 3, hexc('8a8880'))
    light(x, 3, 'tube')


def lantern(c, x, surface):
    """A battery camping lantern (it works without the flat's power)."""
    c.rect(x - 3, surface - 2, x + 3, surface, hexc('3a4a3a'))
    c.rect(x - 2, surface - 9, x + 2, surface - 3, hexc('d8d8c8'))
    c.vline(x - 3, surface - 9, surface - 3, hexc('3a4a3a')); c.vline(x + 3, surface - 9, surface - 3, hexc('3a4a3a'))
    c.rect(x - 3, surface - 11, x + 3, surface - 10, hexc('3a4a3a'))
    c.line(x - 2, surface - 12, x, surface - 14, hexc('2a2a2a')); c.line(x, surface - 14, x + 2, surface - 12, hexc('2a2a2a'))
    light(x, surface - 6, 'lantern')


def shade_col(col, f):
    return shade(col, f)


# --- A BED IN PERSPECTIVE (owner round 16: "do the beds") ------------------------------------------
# Lengthwise along the back wall, its front legs on the floor at `base`. Built in wall coordinates
# (pixlib.pp): the headboard and footboard are real boards running back to the wall (we see the face
# turned to the room's middle), the mattress top narrows toward the wall, the pillow lies ON it and the
# duvet covers the rest and drapes over the front edge. x0 / x1 are where the bed's FRONT shows on
# screen (the old flat coordinates). Returns the geometry so a room can add its own things on top.
BED_SHEET, BED_SHEET_DK = hexc('c9c2b1'), hexc('aaa293')
BED_PILLOW, BED_PILLOW_DK = hexc('d8d1bf'), hexc('b7af9c')


def _q(p_):
    return (int(round(p_[0])), int(round(p_[1])))


def persp_bed(c, x0, x1, base, head='left', head_top=70, foot_top=80, board=None, duvet=None,
              iron=False, knob=None, sheet=(BED_SHEET, BED_SHEET_DK), pillow=(BED_PILLOW, BED_PILLOW_DK),
              legs=True, rail=True, fold=True, rumples=True, hem_drop=8, low=False):
    from pixlib import pp, pbox
    d1 = base - 100
    s1 = (100.0 + d1) / 100.0
    wx0 = 160 + (x0 - 160) / s1
    wx1 = 160 + (x1 - 160) / s1
    T = 2 if iron else 3
    # heights (wall coords, 100 = the floor): legs 96-100, rail 91-96, mattress 85-91, duvet 84.5
    ym, ymb, yr0, yr1 = 85.0, 91.0, 91.0, 96.0
    if low:                                     # a mattress straight on the floor
        ym, ymb = 93.0, 100.0
    col, lt, out = board if board is not None else (hexc('6e4a2e'), hexc('8a5e3a'), hexc('2e1c10'))
    left_top, right_top = (head_top, foot_top) if head == 'left' else (foot_top, head_top)
    ends = []
    if not low:
        ends = [('l', wx0, wx0 + T, left_top), ('r', wx1 - T, wx1, right_top)]
    foot = pp((wx0 + wx1) / 2, 100, d1)
    c.shadow(foot[0], foot[1] + 1, (x1 - x0) / 2 + 3, 3, 110)

    def draw_board(side, bx0, bx1, top, part='back'):
        if iron:
            k_ = knob or hexc('c9a24a')
            for dd in ((0.5,) if part == 'back' else (d1,)):          # the post(s)
                a_, b_ = _q(pp(bx0 + 1, top, dd)), _q(pp(bx0 + 1, 100 if dd == d1 else ymb, dd))
                c.rect(a_[0] - 1, a_[1], a_[0], b_[1], col if dd == d1 else shade(col, 0.8))
                c.ellipse(a_[0], a_[1] - 1, 1.5, 1.5, k_)
            if part != 'back':
                return
            hi = shade(col, 1.9)                                        # iron catches the light
            y_lo = ym - 1
            for yy in (top + 3, y_lo):                                  # the rails, back to front
                a_, b_ = _q(pp(bx0 + 1, yy, 0.5)), _q(pp(bx0 + 1, yy, d1))
                c.line(a_[0], a_[1], b_[0], b_[1], col)
                c.line(a_[0], a_[1] - 1, b_[0], b_[1] - 1, hi)
            for k in range(1, 7):                                       # spindles
                dd = 0.5 + (d1 - 0.5) * k / 7.0
                a_, b_ = _q(pp(bx0 + 1, top + 3, dd)), _q(pp(bx0 + 1, y_lo, dd))
                c.line(a_[0], a_[1], b_[0], b_[1], col)
                if k % 2:
                    c.put(a_[0], (a_[1] + b_[1]) // 2, hi)
            return
        f = pbox(c, bx0, top, bx1, 100, 0, d1 + 0.5, col, lt, shade(col, 0.82), out)
        # a panel moulding on the face we see
        xs = bx1 if side == 'l' else bx0
        if (side == 'l' and bx1 < 160) or (side == 'r' and bx0 > 160):
            a_, b_ = _q(pp(xs, top + 4, 3)), _q(pp(xs, top + 4, d1 - 2))
            c2, d2 = _q(pp(xs, ym - 2, 3)), _q(pp(xs, ym - 2, d1 - 2))
            c.line(a_[0], a_[1], b_[0], b_[1], lt)
            c.line(c2[0], c2[1], d2[0], d2[1], shade(col, 0.7))
            c.line(a_[0], a_[1], c2[0], c2[1], shade(col, 0.7))
            c.line(b_[0], b_[1], d2[0], d2[1], lt)

    def faces_in(side, bx0, bx1):
        return (side == 'l' and bx1 < 160) or (side == 'r' and bx0 > 160)
    for (side, bx0, bx1, top) in ends:
        if faces_in(side, bx0, bx1) or iron:
            draw_board(side, bx0, bx1, top)
    xm0, xm1 = (wx0 + T, wx1 - T) if not low else (wx0, wx1)
    if rail and not low:
        a_, b_ = _q(pp(xm0, yr0, d1)), _q(pp(xm1, yr1, d1))
        c.rect(a_[0], a_[1], b_[0], b_[1], col)
        c.hline(a_[0], b_[0], a_[1], lt)
        c.hline(a_[0], b_[0], b_[1], out)
    if legs and not low:
        for lx in (xm0 + 1, xm1 - 3):
            a_, b_ = _q(pp(lx, yr1, d1)), _q(pp(lx + 2, 100, d1))
            c.rect(a_[0], a_[1] + 1, b_[0], b_[1], out)
    sh, sh_dk = sheet
    pbox(c, xm0, ym, xm1, ymb, 0, d1, sh_dk, sh, shade(sh_dk, 0.85))
    # the pillow at the head end, lying on the mattress
    pw = 14
    px0, px1 = (xm0 + 1, xm0 + 1 + pw) if head == 'left' else (xm1 - 1 - pw, xm1 - 1)
    pc, pdk = pillow
    q = [_q(pp(px0, ym - 2, 2)), _q(pp(px1, ym - 2, 2)), _q(pp(px1, ym - 2, d1 - 2)), _q(pp(px0, ym - 2, d1 - 2))]
    c.poly(q, pc)
    c.line(q[3][0] + 1, q[3][1] + 1, q[2][0] - 1, q[2][1] + 1, pdk)          # its front, in shade
    c.line(q[0][0] + 1, q[0][1], q[1][0] - 1, q[1][1], shade(pc, 1.06))
    mid_a, mid_b = _q(pp((px0 + px1) / 2 - 3, ym - 2, d1 / 2)), _q(pp((px0 + px1) / 2 + 3, ym - 2, d1 / 2))
    c.hline(mid_a[0], mid_b[0], mid_a[1], pdk)                                # the dent
    geo = {'wx0': wx0, 'wx1': wx1, 'xm0': xm0, 'xm1': xm1, 'd1': d1, 'ym': ym, 'pillow': (px0, px1)}
    if duvet is not None:
        dc, ddk, dlt = duvet
        da, db = (px1 + 1, xm1) if head == 'left' else (xm0, px0 - 1)
        yd = ym - 0.5
        top = [_q(pp(da, yd, 0)), _q(pp(db, yd, 0)), _q(pp(db, yd, d1 + 0.6)), _q(pp(da, yd, d1 + 0.6))]
        c.poly(top, dc)
        c.line(top[0][0], top[0][1], top[1][0], top[1][1], ddk)                # tucked against the wall
        if fold:                                                               # turned down at the pillow
            fa, fb = (da, da + 5) if head == 'left' else (db - 5, db)
            fq = [_q(pp(fa, yd, 0)), _q(pp(fb, yd, 0)), _q(pp(fb, yd, d1 + 0.6)), _q(pp(fa, yd, d1 + 0.6))]
            c.poly(fq, shade(dlt, 1.06))
            e_ = fq[1] if head == 'left' else fq[0]
            e2 = fq[2] if head == 'left' else fq[3]
            c.line(e_[0], e_[1], e2[0], e2[1], ddk)
        if rumples:
            n = max(2, int((db - da) / 26))
            for k in range(n):
                rx = da + 8 + k * (db - da - 16) / max(1, n - 1) if n > 1 else da + 8
                dd = [4.0, 9.0, 6.0, 11.0, 5.0][k % 5]
                a_, b_ = _q(pp(rx, yd, dd)), _q(pp(rx + 10, yd, dd))
                c.hline(a_[0], min(b_[0], top[1][0] - 2), a_[1], dlt)
                c.hline(a_[0] + 2, min(b_[0] + 1, top[1][0] - 1), a_[1] + 1, shade(dc, 0.88))
        # the drape over the front edge, an uneven hem, darker as it turns away
        fa_, fb_ = top[3], top[2]
        hem = [0, 1, 1, 2, 1, 0, 0, 1, 2, 2, 1, 0]
        span = fb_[0] - fa_[0] + 1
        for x in range(fa_[0], fb_[0] + 1):
            k = int((x - fa_[0]) * len(hem) / max(1, span))
            hy = fa_[1] + hem_drop + hem[min(k, len(hem) - 1)]
            c.vline(x, fa_[1] + 1, hy, ddk)
            c.put(x, hy, shade(ddk, 0.8))
        c.hline(fa_[0], fb_[0], fa_[1], dc)
        c.hline(fa_[0], fb_[0], fa_[1] + 1, shade(dc, 0.92))
        for k in range(1, 5):
            fx = fa_[0] + span * k // 5
            c.vline(fx, fa_[1] + 3, fa_[1] + hem_drop - 2, shade(ddk, 0.82))
            c.vline(fx + 1, fa_[1] + 2, fa_[1] + hem_drop - 3, shade(ddk, 1.1))
        geo['duvet'] = (da, db)
    for (side, bx0, bx1, top) in ends:
        if iron:
            draw_board(side, bx0, bx1, top, 'front')
        elif not faces_in(side, bx0, bx1):
            draw_board(side, bx0, bx1, top)
    return geo


# --- SMALL THINGS WITH VOLUME (owner round 16: "the small items… little things that just look off") --
def tin(c, cx, base, r, h, body, label=None, lid=hexc('b8bcbc'), open_col=None, handle=True):
    """A tin / paint can standing on the floor: a cylinder — the lit left edge, the shadowed right,
    a label band, and its TOP seen from above (a lid with a rim, or open with the paint inside)."""
    ry = max(1.0, r * 0.4)
    top = base - h
    c.shadow(cx + 1, base + 1, r + 2, 1.5, 100)
    c.rect(cx - r, top, cx + r, base, body)
    c.vline(cx - r, top, base, shade(body, 1.18))
    c.vline(cx + r, top, base, shade(body, 0.62))
    c.vline(cx + r - 1, top, base, shade(body, 0.8))
    c.ellipse(cx, base, r, ry, shade(body, 0.72))                     # the rounded bottom edge
    c.hline(cx - r + 1, cx + r - 1, base - 1, shade(body, 0.85))
    if label is not None:
        lt_ = top + max(2, h // 3)
        c.rect(cx - r, lt_, cx + r, lt_ + max(2, h // 3), label)
        c.vline(cx + r, lt_, lt_ + max(2, h // 3), shade(label, 0.65))
        c.vline(cx - r, lt_, lt_ + max(2, h // 3), shade(label, 1.15))
    c.ellipse(cx, top, r, ry, shade(lid, 0.7))
    if open_col is not None:
        c.ellipse(cx, top, r - 1, max(0.6, ry - 0.6), open_col)
        c.put(cx - 1, int(top), shade(open_col, 1.25))
    else:
        c.ellipse(cx, top, r - 1, max(0.6, ry - 0.6), lid)
        c.hline(cx - r + 2, cx, int(round(top - ry + 1)), shade(lid, 1.2))
    if handle:
        c.line(cx - r, int(top), cx - r + 2, int(top - ry - 3), hexc('6a6e70'))
        c.line(cx - r + 2, int(top - ry - 3), cx + r - 2, int(top - ry - 3), hexc('6a6e70'))
        c.line(cx + r - 2, int(top - ry - 3), cx + r, int(top), hexc('6a6e70'))


def bin_bag(c, cx, base, w, h, knot=True, split=False, seed=1):
    """A tied black bin bag slumped on the floor: a lumpy sack, widest low down, narrowing to a
    knotted neck; shiny plastic — streaks of light on the left lobes, deep shade on the right."""
    import math as _m
    import random as _r
    rng = _r.Random(seed)
    bag, dk, lt, hi = hexc('2f2e2c'), hexc('1c1b1a'), hexc('4e4d4a'), hexc('6e6d68')
    c.shadow(cx, base + 1, w / 2 + 3, 2, 110)
    ph = [rng.random() * 6.28 for _ in range(3)]
    rows = {}
    for y in range(base - h, base + 1):
        t = (base - y) / float(h)                       # 0 at the floor, 1 at the neck
        hw = w / 2.0 * (0.9 + 0.1 * t / 0.3 if t < 0.3 else max(0.0, 1 - ((t - 0.3) / 0.72) ** 2) ** 0.5)
        if t < 0.06:
            hw *= 0.82 + 3.0 * t                          # the slumped, rounded bottom on the floor
        hw *= 1 + 0.07 * _m.sin(t * 9 + ph[0]) + 0.05 * _m.sin(t * 17 + ph[1])
        if t > 0.8:
            hw = max(1.5, hw * 0.55)
        rows[y] = (int(round(cx - hw + 0.8 * _m.sin(t * 5 + ph[2]))), int(round(cx + hw)))
    for y, (a, b) in rows.items():
        for x in range(a, b + 1):
            u = (x - a) / max(1.0, float(b - a))
            col = lt if u < 0.22 else (bag if u < 0.72 else dk)
            c.put(x, y, col)
        c.put(a, y, dk); c.put(b, y, hexc('121110'))
    for k in range(3):                                    # the plastic's shine: short curved streaks
        yy = base - int(h * (0.25 + 0.2 * k))
        if yy in rows:
            a, b = rows[yy]
            c.line(a + 2, yy, a + 3 + k, yy - 3, hi)
    c.hline(rows[base][0] + 1, rows[base][1] - 1, base, dk)
    if knot:
        ky = base - h
        c.poly([(cx - 2, ky), (cx - 4, ky - 4), (cx - 1, ky - 2), (cx + 1, ky - 5), (cx + 2, ky)], dk)
        c.put(cx - 3, ky - 3, lt)
    if split:
        sy = base - h // 3
        c.poly([(cx + 1, sy - 3), (cx + w // 3, sy - 1), (cx + w // 4, sy + 3)], hexc('141312'))
        c.rect(cx + 3, sy + 1, cx + 6, sy + 3, hexc('b0453a'))            # a can
        c.rect(cx - 1, base, cx + 3, base + 1, hexc('d8d2c2'))            # paper



# --- WALL PIECES WITH A STORY (owner round 17: "the wall decorations and photos… look meaningless and
# lacking context… the papers with red lines… look weird like conspiracy boards"). Every paper on a wall
# now SAYS something you can read at the room's scale (the 3x5 capitals), and every photo has people in
# it. Keep the words short and plain: a month, a crossed-off day, "MILK", "MISSING", "STAY INDOORS".
PAPER, PAPER_DK, INK, RED_INK = hexc('ece4cc'), hexc('b9b09a'), hexc('2a2622'), hexc('b0332a')


def pin(c, x, y, col=hexc('c0453a')):
    c.put(x, y, col)
    c.put(x + 1, y + 1, shade(col, 0.6))


def tape(c, x, y):
    c.rect(x - 2, y - 1, x + 2, y, hexc('e8e0c0', 200))


def note(c, x0, y0, lines, w=None, paper=PAPER, ink=INK, fix='pin', tilt=0):
    """A paper with words: each line in the 3x5 capitals, centred; `fix` = 'pin' / 'tape' / None."""
    w = w or max(text3_width(t) for t in lines) + 5
    h = 6 * len(lines) + 4
    x1, y1 = x0 + w, y0 + h
    _paper(c, x0, y0, x1, y1, paper)
    c.hline(x0, x1, y1, shade(paper, 0.85))
    for i, t in enumerate(lines):
        col = RED_INK if t.endswith('!') else ink
        text3(c, x0 + (w - text3_width(t)) // 2 + 1, y0 + 3 + 6 * i, t, col)
    if fix == 'pin':
        pin(c, (x0 + x1) // 2, y0 + 1)
    elif fix == 'tape':
        tape(c, x0 + 2, y0); tape(c, x1 - 2, y0)
    return (x0, y0, x1, y1)


def sticky(c, x0, y0, word, col=hexc('e8d45a')):
    """A square sticky note with one word on it, its bottom edge curling."""
    w = max(9, text3_width(word) + 4)
    c.rect(x0, y0, x0 + w, y0 + 9, col)
    c.hline(x0 + 1, x0 + w, y0 + 9, shade(col, 0.78))
    c.put(x0 + w, y0 + 8, shade(col, 0.7))
    text3(c, x0 + 2, y0 + 2, word, INK)
    return x0 + w


def calendar(c, x0, y0, month='MAY', crossed=12, ringed=19, header=hexc('4a6e8a'), picture=None):
    """A wall calendar hung on a nail: a picture on the top page, the month in the band under it, a
    7-day grid with the days CROSSED OFF in red up to `crossed` — then nothing: the day it stopped —
    and one day ringed (something that never happened)."""
    w, top_h = 23, 10
    grid_y = y0 + top_h + 7
    x1, y1 = x0 + w, grid_y + 5 * 3 + 1
    c.line(x0 + w // 2, y0 - 3, x0 + 2, y0, hexc('6a6258')); c.line(x0 + w // 2, y0 - 3, x1 - 2, y0, hexc('6a6258'))
    _paper(c, x0, y0, x1, y1, PAPER)
    if picture is None:                                  # a landscape on the top page
        c.rect(x0 + 1, y0 + 1, x1 - 1, y0 + top_h, hexc('9ac0d8'))
        c.poly([(x0 + 1, y0 + top_h), (x0 + 8, y0 + 4), (x0 + 13, y0 + 8), (x0 + 17, y0 + 5), (x1 - 1, y0 + top_h)], hexc('6a8a5a'))
        c.ellipse(x1 - 5, y0 + 3, 1.5, 1.5, hexc('f0d27a'))
    else:
        picture(c, x0 + 1, y0 + 1, x1 - 1, y0 + top_h)
    c.rect(x0 + 1, y0 + top_h + 1, x1 - 1, y0 + top_h + 6, header)
    text3(c, x0 + (w - text3_width(month)) // 2 + 1, y0 + top_h + 1, month, hexc('f4efe0'))
    day = 1
    for r in range(5):
        for k in range(7):
            if day > 31:
                break
            cx, cy = x0 + 2 + k * 3, grid_y + r * 3
            if day <= crossed:
                c.put(cx, cy, RED_INK); c.put(cx + 1, cy + 1, RED_INK)
                c.put(cx + 1, cy, shade(RED_INK, 1.2)); c.put(cx, cy + 1, shade(RED_INK, 1.2))
            else:
                c.put(cx, cy, PAPER_DK)
            if day == ringed:
                for (dx, dy) in ((-1, 0), (2, 0), (0, -1), (1, -1), (0, 2), (1, 2)):
                    c.put(cx + dx, cy + dy, hexc('2a58a0'))
            day += 1
    return (x0, y0, x1, y1)


def photo(c, x0, y0, x1, y1, people, bg=hexc('9ac0d8'), ground=hexc('7a9a5a'), border=hexc('f4f0e4'), frame=None):
    """A photograph of PEOPLE (owner round 17 — pictures of nothing read as meaningless): a white
    border (or a frame), sky + ground, and a row of little figures — each (skin, hair, clothes, height)."""
    if frame is not None:
        c.box(x0 - 2, y0 - 2, x1 + 2, y1 + 2, frame, shade(frame, 0.55))
    c.rect(x0, y0, x1, y1, border)
    ix0, iy0, ix1, iy1 = x0 + 1, y0 + 1, x1 - 1, y1 - (3 if frame is None else 1)
    c.rect(ix0, iy0, ix1, iy1, bg)
    c.rect(ix0, iy1 - (iy1 - iy0) // 3, ix1, iy1, ground)
    n = len(people)
    span = ix1 - ix0
    for i, (skin, hair, cloth, hgt) in enumerate(people):
        px = ix0 + int(span * (i + 1) / (n + 1))
        base = iy1 - 1
        top = base - hgt
        c.rect(px - 1, top + 3, px + 1, base, cloth)                        # body
        c.rect(px - 1, top, px + 1, top + 2, skin)                          # head
        c.hline(px - 1, px + 1, top, hair)
        c.put(px - 1, top + 1, hair)
    return (x0, y0, x1, y1)


def newspaper(c, x0, y0, headline, sub=None, w=None):
    """A front page taped to the wall: the masthead rule, a big headline you can read, a photo block
    and the columns."""
    w = w or max(22, text3_width(headline) + 5)
    x1, y1 = x0 + w, y0 + 26
    _paper(c, x0, y0, x1, y1, hexc('ddd6c2'))
    c.hline(x0 + 2, x1 - 2, y0 + 2, INK)
    c.hline(x0 + 2, x1 - 2, y0 + 3, hexc('8a8270'))
    text3(c, x0 + (w - text3_width(headline)) // 2 + 1, y0 + 5, headline, INK)
    yy = y0 + 11
    if sub:
        text3(c, x0 + (w - text3_width(sub)) // 2 + 1, yy, sub, hexc('5a544a'))
        yy += 6
    c.rect(x0 + 2, yy, x0 + w // 2 - 1, y1 - 2, hexc('8a8478'))            # the photo
    c.rect(x0 + 3, yy + 1, x0 + w // 2 - 2, y1 - 3, hexc('6a665c'))
    for ly in range(yy, y1 - 1, 2):
        c.hline(x0 + w // 2 + 1, x1 - 2, ly, hexc('9a9282'))
    tape(c, x0 + 3, y0); tape(c, x1 - 3, y0)
    return (x0, y0, x1, y1)


def missing_poster(c, x0, y0, name='ANNA', col=hexc('f0ece0')):
    """MISSING — a photo of the face, the name, a phone number tab row torn off at the bottom."""
    w, h = 29, 30
    x1, y1 = x0 + w, y0 + h
    _paper(c, x0, y0, x1, y1, col)
    text3(c, x0 + (w - text3_width('MISSING')) // 2 + 1, y0 + 2, 'MISSING', RED_INK)
    c.rect(x0 + 5, y0 + 9, x1 - 5, y0 + 19, hexc('8a847a'))                 # the photo
    c.ellipse((x0 + x1) // 2, y0 + 13, 2.5, 3, hexc('d8b89a'))
    c.hline((x0 + x1) // 2 - 3, (x0 + x1) // 2 + 3, y0 + 10, hexc('4a3424'))
    c.rect((x0 + x1) // 2 - 3, y0 + 17, (x0 + x1) // 2 + 3, y0 + 19, hexc('5a7aa0'))
    text3(c, x0 + (w - text3_width(name)) // 2 + 1, y0 + 21, name, INK)
    for k in range(7):                                                    # the tear-off tabs
        tx = x0 + 1 + k * 4
        if k in (1, 4):
            continue                                                      # two already taken
        c.rect(tx, y1 - 3, tx + 2, y1, col)
        c.vline(tx + 3, y1 - 3, y1, shade(col, 0.8))
    tape(c, x0 + 3, y0)
    return (x0, y0, x1, y1)


def text_spray(c, x, y, word, col, scale=2, drips=True, seed=3):
    """Big spray-painted capitals (the 3x5 font at 2x), soft-edged, with a few runs dripping down."""
    import random as _r
    rng = _r.Random(seed)
    x0 = x
    for ch in word:
        g = FONT3.get(ch, FONT3[' '])
        for gy, row in enumerate(g):
            for gx, v in enumerate(row):
                if v == '1':
                    c.rect(x + gx * scale, y + gy * scale, x + gx * scale + scale - 1, y + gy * scale + scale - 1, col)
                    if drips and gy == 4 and rng.random() < 0.35:
                        ln = rng.randrange(2, 7)
                        c.vline(x + gx * scale, y + 5 * scale, y + 5 * scale + ln, col[:3] + (180,))
        x += (len(g[0]) + 1) * scale
    return x - x0


def portrait(c, x0, y0, x1, y1, sitter='man', bg=hexc('4a4234'), coat=hexc('2a2a30'), skin=hexc('d8b89a'),
             hair=hexc('4a3424'), frame=None):
    """A head-and-shoulders portrait someone actually sat for (owner round 17: blank ovals read as
    nothing): shoulders in a dark coat with a white collar, a face with eyes and a mouth, and the
    sitter's hair — 'man' (short, a moustache), 'woman' (hair up in a bun), 'girl' (long, a bow),
    'old' (grey, balding, spectacles)."""
    if frame is not None:
        c.box(x0 - 2, y0 - 2, x1 + 2, y1 + 2, frame, shade(frame, 0.55))
        c.hline(x0 - 1, x1 + 1, y0 - 1, shade(frame, 1.25))
    c.rect(x0, y0, x1, y1, bg)
    for yy in range(y0, y1 + 1):                                        # a painter's dark vignette
        c.put(x0, yy, shade(bg, 0.8)); c.put(x1, yy, shade(bg, 0.8))
    w, h = x1 - x0, y1 - y0
    cx = (x0 + x1) // 2
    hr = max(2.5, w * 0.19)                                             # head half-width
    hy = y0 + int(h * 0.40)                                             # head centre
    sh = y0 + int(h * 0.68)                                             # shoulder line
    c.poly([(cx - int(w * 0.40), y1), (cx - int(w * 0.30), sh), (cx + int(w * 0.30), sh), (cx + int(w * 0.40), y1)], coat)
    c.line(cx - int(w * 0.30), sh, cx - int(w * 0.40), y1, shade(coat, 1.3))
    c.rect(cx - 1, sh - 2, cx + 1, sh, skin)                            # neck
    c.poly([(cx - 3, sh), (cx, sh + 4), (cx + 3, sh)], hexc('ece8dc'))  # collar
    c.ellipse(cx, hy, hr, hr * 1.25, skin)
    c.vline(int(cx + hr), hy - 1, hy + 2, shade(skin, 0.8))             # the shadowed cheek
    ey = hy - 1
    c.put(cx - 2, ey, hexc('2a2220')); c.put(cx + 2, ey, hexc('2a2220'))
    c.put(cx, hy + 1, shade(skin, 0.82))                                # nose
    c.hline(cx - 1, cx + 1, hy + 3, shade(skin, 0.6))                   # mouth
    top = int(round(hy - hr * 1.25))
    if sitter == 'man':
        c.ellipse(cx, top + 1, hr, 2, hair)
        c.put(int(cx - hr), top + 2, hair); c.put(int(cx - hr), top + 3, hair)
        c.hline(cx - 2, cx + 2, hy + 2, hair)                           # moustache
    elif sitter == 'woman':
        c.ellipse(cx, top + 1, hr + 0.5, 2.5, hair)
        c.ellipse(cx, top - 2, 2, 2, hair)                              # the bun
        c.vline(int(cx - hr), top + 1, hy, hair); c.vline(int(cx + hr), top + 1, hy, hair)
        c.put(cx - 1, sh + 2, hexc('d9c9a0')); c.put(cx + 1, sh + 2, hexc('d9c9a0'))   # a brooch
    elif sitter == 'girl':
        c.ellipse(cx, top + 1, hr + 0.5, 2.5, hair)
        c.rect(int(cx - hr - 1), top + 1, int(cx - hr), sh, hair)
        c.rect(int(cx + hr), top + 1, int(cx + hr + 1), sh, hair)
        c.rect(int(cx + hr - 1), top - 1, int(cx + hr + 1), top, hexc('c0453a'))   # a bow
    elif sitter == 'old':
        c.put(int(cx - hr), hy - 2, hexc('c9c4bc')); c.put(int(cx + hr), hy - 2, hexc('c9c4bc'))
        c.put(int(cx - hr), hy - 1, hexc('c9c4bc')); c.put(int(cx + hr), hy - 1, hexc('c9c4bc'))
        c.hline(cx - 3, cx - 1, ey, hexc('8a8478')); c.hline(cx + 1, cx + 3, ey, hexc('8a8478'))   # spectacles
        c.put(cx - 2, ey, hexc('2a2220')); c.put(cx + 2, ey, hexc('2a2220'))
    return (x0, y0, x1, y1)


def landscape(c, x0, y0, x1, y1, sky=hexc('9ab8c8'), hills=hexc('5a7a4a'), water=None, boat=False):
    """A painted view: sky, a far hill line, and a near field — or the sea, with a sailing boat."""
    import math as _m
    c.rect(x0, y0, x1, y1, sky)
    hz = y0 + (y1 - y0) * 3 // 5
    if water is not None:
        c.rect(x0, hz, x1, y1, water)
        for yy in range(hz + 2, y1, 3):
            c.hline(x0 + 1 + (yy % 4), x1 - 2, yy, shade(water, 1.15))
        if boat:
            bx = x0 + (x1 - x0) * 2 // 5
            c.poly([(bx, hz - 1), (bx, hz - 9), (bx + 5, hz - 1)], hexc('f0ece0'))       # the sail
            c.vline(bx, hz - 10, hz, hexc('3a3028'))
            c.poly([(bx - 4, hz), (bx + 7, hz), (bx + 5, hz + 2), (bx - 2, hz + 2)], hexc('6a3a2a'))
    else:
        for x in range(x0, x1 + 1):
            yy = hz - 3 + int(2.5 * _m.sin((x - x0) / 4.0)) + int(1.5 * _m.sin((x - x0) / 1.7))
            c.vline(x, yy, y1, shade(hills, 0.8))
        c.rect(x0, hz + 2, x1, y1, hills)
        c.ellipse(x1 - 4, y0 + 3, 1.5, 1.5, hexc('f4e6b0'))
    return (x0, y0, x1, y1)


def waste_basket(c, cx, base, r, h, body=hexc('3a3a44'), paper=True):
    """A round wastepaper basket on the floor, seen from a little above: a mesh cylinder (lit left,
    dark right), its OPEN rim an ellipse with the dark inside and crumpled paper heaped in it."""
    ry = max(1.5, r * 0.38)
    top = base - h
    c.shadow(cx + 1, base + 1, r + 2, 1.5, 110)
    for yy in range(top, base + 1):                                     # it narrows toward the foot
        t = (yy - top) / float(max(1, h))
        rr = int(round(r - t * 1.5))
        c.hline(cx - rr, cx + rr, yy, body)
        c.put(cx - rr, yy, shade(body, 1.3)); c.put(cx + rr, yy, shade(body, 0.6))
        if (yy - top) % 3 == 1:
            c.hline(cx - rr + 1, cx + rr - 1, yy, shade(body, 1.12))    # the mesh bands
    c.ellipse(cx, base, r - 1.5, ry * 0.8, shade(body, 0.7))
    c.ellipse(cx, top, r, ry, shade(body, 1.35))                        # the rim
    c.ellipse(cx, top, r - 1, ry - 0.6, hexc('141418'))                 # inside
    if paper:
        for (dx, dy, rr_) in ((-2, -1, 2), (1, -2, 2.5), (3, 0, 1.5)):
            c.ellipse(cx + dx, top + dy, rr_, rr_ * 0.8, hexc('e6e0cc'))
            c.put(cx + dx, top + dy, hexc('b9b09a'))
