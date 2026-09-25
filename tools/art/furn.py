"""Reusable furniture for the room-module variants (tools/art/*_variants.py).

Every piece takes a palette P = (base, light, dark, outline) so a variant restyles it, and draws
flat (no baked light — the engine lights it), with a soft contact shadow and its OWN outline so
overlapping pieces stay readable. Coordinates are module-local (320 x 144; wall/floor seam y 100,
walking line 129). Pieces against the back wall stand on y 99/100; pieces out in the room stand
on 108..122 (the nearer, the bigger y).
"""
from pixlib import hexc, shade, rrect

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
    from pixlib import Canvas
    lyr = Canvas(w=c.w, h=c.h, bg=(0, 0, 0, 0), seed=11)
    fn(lyr)
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
