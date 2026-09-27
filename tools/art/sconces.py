"""Corridor WALL SCONCES — the light source of every corridor floor (owner round 24: "the lights are
random globs of light at the top that don't seem to have a light source… the wall lamps… we need
this to be the light source for the floors").

Run:  python3 tools/art/sconces.py
Out:  assets/corridor/sconces/sconce_<style>.png       the fixture, authored FLAT (lit by the engine like
                                               the wall it's on — a dead lamp is just this)
      assets/corridor/sconces/sconce_<style>_lit.png   ONLY what glows when it's on (the shade / glass /
                                               the bulb), drawn UNSHADED over the fixture with its
                                               alpha following the lamp (flicker, cut-outs)
      assets/corridor/sconces/sconce_<style>_broken.png a smashed one (deep / late floors) — never lights
      docs/art_reference/corridor/sconces.png  a contact sheet (off / on / broken, 4x)

Every image is 24x24 with the BULB at pixel (12, 12), so scripts/floor_lighting.gd centres the
sprite on the light's position. Styles follow the corridor sections (building_floors.
corridor_section): high = the faded hotel's brass arm + pleated fabric shade, mid = a residential
coach lantern, low = an institutional caged bulkhead; hallway (floor 30) and lobby use
the hotel / a polished brass-and-opal lobby fitting.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade, mix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'corridor', 'sconces')   # its own folder: corridor.py prunes assets/corridor/*.png
PREV = os.path.join(ROOT, 'docs', 'art_reference', 'corridor', 'sconces.png')
W = H = 24
BX, BY = 12, 12                                  # the bulb

GLOW = hexc('fff2c8')
GLOW_HOT = hexc('fffbe8')
GLOW_WARM = hexc('ffd98a')


def new():
    return Canvas(w=W, h=H, seed=1)


# --- HIGH: the hotel — a brass back-plate, a swan-neck arm, a pleated cream drum shade ----------
def high(lit=False, broken=False):
    c = new()
    brass, brass_dk, brass_lt = hexc('b58f4a'), hexc('6a4a22'), hexc('e0c07a')
    # the back-plate on the wall, under the shade
    c.ellipse(BX, BY + 7, 2, 3, brass_dk)
    c.ellipse(BX, BY + 7, 1, 2, brass)
    c.put(BX, BY + 6, brass_lt)
    c.vline(BX, BY + 3, BY + 5, brass)            # the neck up into the shade
    c.put(BX + 1, BY + 4, brass_dk)
    if broken:                                    # the shade gone, the bulb snapped off in its holder
        c.rect(BX - 1, BY + 1, BX + 1, BY + 2, brass_dk)
        c.put(BX - 1, BY, hexc('8a8a86')); c.put(BX + 1, BY - 1, hexc('b8c0c0'))
        return c
    # the drum shade, a little wider at the bottom: pleated fabric
    fab, fab_dk, fab_lt = hexc('d8c8a4'), hexc('a8946c'), hexc('ece0c4')
    for y in range(BY - 6, BY + 3):
        k = (y - (BY - 6)) / 8.0
        half = int(round(5 + 2 * k))
        for x in range(BX - half, BX + half + 1):
            col = fab
            if (x - BX) % 2 == 0:
                col = fab_dk if not lit else fab
            if x == BX - half or x == BX + half:
                col = fab_dk
            if lit:
                col = mix(GLOW, GLOW_WARM, 0.3 + 0.4 * abs(x - BX) / max(1, half))
                if (x - BX) % 2 == 0:
                    col = mix(col, GLOW_WARM, 0.35)
            c.put(x, y, col)
    c.hline(BX - 5, BX + 5, BY - 7, brass if not lit else GLOW_WARM)      # the top trim
    c.hline(BX - 7, BX + 7, BY + 3, brass if not lit else GLOW_HOT)       # the bottom trim
    if not lit:
        c.hline(BX - 4, BX + 4, BY - 6, fab_lt)
    else:
        c.hline(BX - 3, BX + 3, BY + 4, GLOW_HOT)                           # light spilling out below
        c.put(BX, BY + 5, GLOW)
    return c


# --- MID: residential — a black coach lantern on a curled bracket, frosted glass --------------------
def mid(lit=False, broken=False):
    c = new()
    iron, iron_lt = hexc('26262a'), hexc('5a5a60')
    c.rect(BX + 5, BY + 2, BX + 7, BY + 9, iron)                              # the back-plate (right)
    c.put(BX + 6, BY + 3, iron_lt)
    c.hline(BX + 2, BX + 5, BY + 5, iron)                                    # the bracket arm
    c.put(BX + 3, BY + 6, iron); c.put(BX + 4, BY + 7, iron)                  # its curl
    c.vline(BX, BY + 4, BY + 5, iron)
    c.hline(BX - 3, BX + 3, BY + 4, iron)                                    # the lantern's base
    c.poly([(BX - 4, BY - 5), (BX + 4, BY - 5), (BX + 2, BY - 8), (BX - 2, BY - 8)], iron)   # its cap
    c.rect(BX - 1, BY - 10, BX + 1, BY - 9, iron)                            # the finial
    c.vline(BX - 3, BY - 5, BY + 3, iron)                                    # the frame
    c.vline(BX + 3, BY - 5, BY + 3, iron)
    if broken:
        c.put(BX - 2, BY + 1, hexc('d8dcd8')); c.put(BX + 1, BY - 3, hexc('d8dcd8'))
        c.put(BX, BY - 1, hexc('6a6a66'))
        return c
    for y in range(BY - 4, BY + 4):                                           # the glass
        for x in range(BX - 2, BX + 3):
            if lit:
                col = mix(GLOW_HOT, GLOW_WARM, min(1.0, abs(x - BX) / 3.0 + abs(y - BY) / 8.0))
            else:
                col = hexc('d4d0c0') if x != BX - 2 else hexc('eeeae0')
            c.put(x, y, col)
    c.hline(BX - 2, BX + 2, BY - 1, iron if not lit else GLOW_WARM)          # a glazing bar
    return c


# --- LOW: institutional — a grey bulkhead, opal glass behind a cage -----------------------------
def low(lit=False, broken=False):
    c = new()
    frame, frame_dk, frame_lt = hexc('7a8480'), hexc('3a403e'), hexc('a4acaa')
    c.rect(BX - 8, BY - 5, BX + 8, BY + 5, frame_dk)
    c.rect(BX - 7, BY - 4, BX + 7, BY + 4, frame)
    c.hline(BX - 7, BX + 7, BY - 4, frame_lt)
    for (x, y) in ((BX - 7, BY - 4), (BX + 7, BY - 4), (BX - 7, BY + 4), (BX + 7, BY + 4)):
        c.put(x, y, frame_dk)                                               # rounded corners
    glass = hexc('d4d8cc') if not lit else GLOW
    if broken:
        c.rect(BX - 5, BY - 2, BX + 5, BY + 2, hexc('2a2a28'))
        c.put(BX - 3, BY - 1, hexc('c8ccc4')); c.put(BX + 2, BY + 1, hexc('c8ccc4'))
    else:
        c.rect(BX - 5, BY - 2, BX + 5, BY + 2, glass)
        if lit:
            c.rect(BX - 3, BY - 1, BX + 3, BY + 1, GLOW_HOT)
        else:
            c.hline(BX - 4, BX + 1, BY - 1, hexc('eef0e8'))
    for x in (BX - 2, BX + 2):                                              # the cage bars
        c.vline(x, BY - 3, BY + 3, frame_dk)
    c.hline(BX - 6, BX + 6, BY, frame_dk)
    c.put(BX - 6, BY - 3, frame_lt); c.put(BX + 6, BY + 3, frame_dk)       # screws
    return c


# --- LOBBY: polished brass arm and an opal glass globe ------------------------------------------
def lobby(lit=False, broken=False):
    c = new()
    brass, brass_dk, brass_lt = hexc('c8a050'), hexc('6a4a22'), hexc('f0d890')
    c.rect(BX - 1, BY + 5, BX + 1, BY + 9, brass)                            # the back-plate
    c.vline(BX - 1, BY + 5, BY + 9, brass_lt)
    c.vline(BX + 1, BY + 5, BY + 9, brass_dk)
    c.vline(BX, BY + 3, BY + 4, brass)
    c.hline(BX - 2, BX + 2, BY + 3, brass_dk)                                # the gallery
    if broken:
        c.put(BX - 2, BY + 2, hexc('e8e4d8')); c.put(BX + 2, BY + 1, hexc('e8e4d8'))
        return c
    for y in range(BY - 5, BY + 3):
        for x in range(BX - 5, BX + 6):
            d = ((x - BX) ** 2 + (y - (BY - 1)) ** 2) ** 0.5
            if d <= 4.6:
                if lit:
                    c.put(x, y, mix(GLOW_HOT, GLOW_WARM, min(1.0, d / 5.0)))
                else:
                    c.put(x, y, hexc('b8b4a8') if d > 3.8 else hexc('e8e4d8'))
    if not lit:
        c.put(BX - 2, BY - 3, hexc('fbf9f2'))
    return c


STYLES = {'high': high, 'mid': mid, 'low': low, 'lobby': lobby}


def main():
    from PIL import Image
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for name, fn in STYLES.items():
        off, on, broken = fn(False), fn(True), fn(False, broken=True)
        # the lit overlay keeps ONLY the pixels that change when it's on (what actually glows)
        glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        for y in range(H):
            for x in range(W):
                p = on.img.getpixel((x, y))
                if p[3] and p != off.img.getpixel((x, y)):
                    glow.putpixel((x, y), p)
        off.img.save(os.path.join(OUT, 'sconce_%s.png' % name))
        glow.save(os.path.join(OUT, 'sconce_%s_lit.png' % name))
        broken.img.save(os.path.join(OUT, 'sconce_%s_broken.png' % name))
        lit_full = off.img.copy()
        lit_full.alpha_composite(glow)
        tiles += [off.img, lit_full, broken.img]
    s = 4
    sheet = Image.new('RGBA', (len(tiles) * (W + 2) * s, H * s), (60, 64, 70, 255))
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t.resize((W * s, H * s), Image.NEAREST), (i * (W + 2) * s, 0))
    os.makedirs(os.path.dirname(PREV), exist_ok=True)
    sheet.save(PREV)
    print('wrote sconce_%s (+_lit, _broken)' % '/'.join(STYLES))


if __name__ == '__main__':
    main()
