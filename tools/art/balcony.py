"""THE BALCONY (owner round 14 — "the balcony looks ugly as hell now… completely out of place, and not
in the correct place, or even the right size… move it higher, to the wall floor boundary line, as an
actual out door area"; "right now, it looks like the tardis").

A LOGGIA behind an opening in the back wall of a study / dining room: the doorway (a painted trim
frame, the French doors swung OUT flat against the loggia's side walls), a tiled floor that starts at
the room's wall/floor seam and recedes UP to the railing at the far edge, and the city beyond — sky,
towers, rooftops — in the run's light: MORNING, a sunset AFTERNOON (a smoke column over the city —
the outbreak), NIGHT (dark towers, lit windows, a fire burning out there). Later runs weather the
balcony itself (a dying plant, then knocked over; cracked tiles, a cracked door pane, grime).

Perspective = the room's: the horizon is the ceiling (local y 0) and a balcony's vanishing point is
its own centre, so the floor rows and the side walls converge like the rest of the flat.

Every number that the GAME uses lives in scripts/balcony_geo.gd (read below and checked) — the art is
drawn from them, so the player / enemies / descent line up with what's drawn.

Writes assets/rooms/balcony.png (+ _r2, _r3): a 320 x 144 layer, transparent except the doorway
(module x 8..92), drawn over the module art by room.gd on a balcony slot. Preview:
docs/art_reference/modules/balcony_runs.png.
Run:  python3 tools/art/balcony.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image  # noqa: E402
from pixlib import Canvas, hexc, mix, shade, W, H, DECAY  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))


def _geo():
    """scripts/balcony_geo.gd's constants (world y) → module-local numbers."""
    txt = open(os.path.join(ROOT, 'scripts', 'balcony_geo.gd')).read()
    vals = {}
    for m in re.finditer(r'const (\w+) := (-?[\d.]+)', txt):
        vals[m.group(1)] = float(m.group(2))
    return vals


G = _geo()
TOP = 224                                   # module top, world
CX = int(G['CENTER_DX'])                    # the balcony centre, module x
SILL = int(G['THRESHOLD_Y']) - TOP          # 100: the wall/floor seam — the doorway's sill
EDGE = int(G['EDGE_Y']) - TOP               # 86: the far edge of the balcony floor (rail base)
RAIL = int(G['RAIL_TOP_Y']) - TOP           # 64: the handrail
LINTEL = int(G['LINTEL_Y']) - TOP           # 20: the top of the opening
X0, X1 = CX - int(G['OPEN_HALF']), CX + int(G['OPEN_HALF'])   # the opening: 12..88
TRIM = 4                                    # the door frame's trim, outside the opening


def depth_x(x, y):
    """Where x (at the wall plane, y = SILL) sits on the floor line y further back — toward the
    vanishing point (CX, 0)."""
    return CX + (x - CX) * (y / float(SILL))


# per run: sky top / bottom, far towers, near roofs, lit-window colour + density
LOOK = {
    1: dict(sky=(hexc('8fbfe6'), hexc('d4e6f0')), far=hexc('9fb2c4'), near=hexc('6f8296'),
            roof=hexc('55626f'), lit=None, sun=hexc('fff4c8')),
    2: dict(sky=(hexc('d9826e'), hexc('f4c08e')), far=hexc('a0788a'), near=hexc('6e4e66'),
            roof=hexc('4a3446'), lit=(hexc('ffd98a'), 0.06), sun=hexc('ffe0a0')),
    3: dict(sky=(hexc('0e1226'), hexc('1c2440')), far=hexc('1e2338'), near=hexc('141828'),
            roof=hexc('0c0f1a'), lit=(hexc('e8c070'), 0.14), sun=None),
}


def _view(c, run, rng):
    """The city beyond the rail, clipped to the opening between the loggia's side walls — the SAME skyline the
    apartment windows look onto (tools/art/cityscape.py), so the building reads as one place. The fires, blasts
    and smoke are NOT painted here: the game plays them as small animations over the points this returns."""
    import cityscape
    import random as _r
    return cityscape.draw_city(c, (X0, LINTEL, X1, EDGE + 1), run, _r.Random(700 + run), layout_seed=4242, tall=1.55)


def _side_walls(c, run):
    """The loggia's side walls, receding from the jambs to the far edge (render, lit by the sky)."""
    lit = [hexc('b8b0a2'), hexc('a89880'), hexc('3a3a48')][run - 1]
    dark = shade(lit, 0.72)
    for (xa, col) in ((X0, lit), (X1, dark)):
        xb = int(round(depth_x(xa, EDGE)))
        lo, hi = min(xa, xb), max(xa, xb)
        for x in range(lo, hi + 1):
            # the wall's floor line at this x (from SILL at the jamb to EDGE at the back)
            t = (x - xa) / float(xb - xa) if xb != xa else 0.0
            fy = int(round(SILL + (EDGE - SILL) * t))
            c.vline(x, LINTEL, fy, col)
        # a render joint halfway back
        mx = int(round(depth_x(xa, (SILL + EDGE) / 2.0)))
        c.vline(mx, LINTEL, int(round((SILL + EDGE) / 2.0)), shade(col, 0.88))


def _doors(c, run):
    """The French doors, swung out flat against the side walls: a white frame + a glass pane that
    catches the sky, seen almost edge-on."""
    frame = [hexc('ece6d8'), hexc('d8cfbd'), hexc('8a8478')][run - 1]
    glass = [hexc('b8d6ec'), hexc('e8b89a'), hexc('2c3654')][run - 1]
    DEPTH = SILL - (SILL - EDGE) * 0.62                  # the leaf reaches ~0.8 m out
    for xa in (X0, X1):
        xb = int(round(depth_x(xa, DEPTH)))
        lo, hi = min(xa, xb), max(xa, xb)
        for x in range(lo, hi + 1):
            t = (x - xa) / float(xb - xa) if xb != xa else 0.0
            fy = int(round(SILL + (DEPTH - SILL) * t))
            ty = LINTEL + 1
            c.vline(x, ty, fy - 1, frame)
            if x not in (lo, hi):
                c.vline(x, ty + 4, fy - 6, glass)
                c.put(x, int((ty + fy) / 2), frame)               # the glazing bar
        if run == 3 and xa == X1:                                 # a cracked pane
            c.line(lo + 1, LINTEL + 12, hi - 1, LINTEL + 22, hexc('dfe6f0', 200))


def _floor(c, run, rng):
    """Terracotta tiles in perspective, the far edge a concrete lip."""
    tile = [hexc('b0664a'), hexc('a05e46'), hexc('5a3a34')][run - 1]
    grout = shade(tile, 0.7)
    for y in range(EDGE, SILL + 1):
        xa, xb = int(round(depth_x(X0, y))), int(round(depth_x(X1, y)))
        c.hline(xa, xb, y, shade(tile, 0.92 + 0.08 * (y - EDGE) / float(SILL - EDGE)))
    for d in (0.25, 0.5, 0.76):                              # rows (perspective-spaced)
        y = int(round(SILL - (SILL - EDGE) * d))
        c.hline(int(round(depth_x(X0, y))), int(round(depth_x(X1, y))), y, grout)
    for k in range(1, 8):                                    # columns, converging on the centre
        xs = X0 + (X1 - X0) * k / 8.0
        for y in range(EDGE, SILL):
            c.put(int(round(depth_x(xs, y))), y, grout)
    c.hline(int(round(depth_x(X0, EDGE))), int(round(depth_x(X1, EDGE))), EDGE, hexc('9a948a') if run < 3 else hexc('3e3c40'))
    if run >= 2:                                             # cracked tiles, grime at the edges
        for (x0, y0) in ((X0 + 30, SILL - 4), (X0 + 52, EDGE + 5)):
            c.line(x0, y0, x0 + 5, y0 - 2, shade(tile, 0.5))
        for y in range(EDGE + 1, SILL):
            for x in (int(round(depth_x(X0, y))) + 1, int(round(depth_x(X1, y))) - 1):
                c.put(x, y, hexc('2a2018', 70 if run == 2 else 120))


def _rail(c, run):
    """A painted steel railing along the far edge: posts at the ends, a handrail, balusters."""
    metal = [hexc('3c4046'), hexc('3a3a40'), hexc('1a1c22')][run - 1]
    hi = [hexc('8a929c'), hexc('b08a74'), hexc('4a5068')][run - 1]
    xa, xb = int(round(depth_x(X0, EDGE))), int(round(depth_x(X1, EDGE)))
    for x in range(xa + 3, xb - 2, 4):
        c.vline(x, RAIL + 2, EDGE - 1, metal)
    c.hline(xa, xb, EDGE - 2, metal)                          # bottom rail
    c.rect(xa, RAIL, xb, RAIL + 1, metal)                     # handrail
    c.hline(xa, xb, RAIL, hi)
    for x in (xa, xb):
        c.rect(x, RAIL, x + (1 if x == xa else 0) - (0 if x == xa else 1), EDGE, metal)
    if run == 3:                                              # rust streaks
        for x in range(xa + 5, xb, 13):
            c.vline(x, RAIL + 2, RAIL + 6, hexc('6a3a22', 160))


def _plant(c, run):
    """A potted plant in the far left corner, dying by the afternoon, knocked over at night."""
    px = int(round(depth_x(X0, EDGE + 3))) + 5
    base = EDGE + 3
    pot, pot_dk = hexc('9a5236'), hexc('6a3622')
    if run < 3:
        c.rect(px - 3, base - 5, px + 3, base, pot)
        c.hline(px - 3, px + 3, base - 5, shade(pot, 1.2))
        c.vline(px + 3, base - 4, base, pot_dk)
        leaves = [hexc('5a8a3a'), hexc('4a7030')] if run == 1 else [hexc('8a7a3a'), hexc('6a5a2a')]
        for i, (dx, dy) in enumerate(((-3, -8), (-1, -11), (1, -10), (3, -7), (0, -13), (-4, -6), (4, -9))):
            c.line(px, base - 5, px + dx, base - 5 + dy + 5, leaves[i % 2])
            c.put(px + dx, base + dy, leaves[(i + 1) % 2])
    else:
        c.rect(px - 1, base - 3, px + 6, base, pot)           # on its side
        c.vline(px + 6, base - 3, base, pot_dk)
        c.rect(px - 5, base - 1, px - 1, base, hexc('3a2a1e'))   # soil spilled
        c.line(px - 5, base - 2, px - 9, base - 4, hexc('4a3a22'))


def _frame(c, run):
    """The doorway's painted trim, the sill, the shadow the lintel throws."""
    f = DECAY[run]['wall'] if run > 1 else 1.0
    trim = shade(hexc('ddd6c6'), f)
    trim_dk = shade(hexc('b0a896'), f)
    trim_hi = shade(hexc('f2ede0'), f)
    c.rect(X0 - TRIM, LINTEL - TRIM, X1 + TRIM, LINTEL - 1, trim)     # head
    c.hline(X0 - TRIM, X1 + TRIM, LINTEL - TRIM, trim_hi)
    c.hline(X0 - TRIM + 1, X1 + TRIM - 1, LINTEL - 1, trim_dk)
    for (xa, xb) in ((X0 - TRIM, X0 - 1), (X1 + 1, X1 + TRIM)):         # jambs
        c.rect(xa, LINTEL - TRIM, xb, SILL, trim)
        c.vline(xa, LINTEL - TRIM, SILL, trim_hi)
        c.vline(xb, LINTEL, SILL, trim_dk)
    # the sill: a stone step across the opening, its lip on the room floor
    c.rect(X0 - TRIM, SILL - 1, X1 + TRIM, SILL + 1, shade(hexc('b8b2a6'), f))
    c.hline(X0 - TRIM, X1 + TRIM, SILL - 1, shade(hexc('d8d2c6'), f))
    c.hline(X0 - TRIM, X1 + TRIM, SILL + 2, hexc('000000', 80))
    # the lintel's shadow on the loggia (under the head, fading)
    for k in range(3):
        c.hline(X0, X1, LINTEL + k, hexc('000000', 60 - 18 * k))
    if run >= 2:                                              # grime in the frame's corners
        for (x, y) in ((X0 - 2, SILL - 3), (X1 + 2, SILL - 3), (X0 - 2, LINTEL - 2), (X1 + 2, LINTEL - 2)):
            c.put(x, y, hexc('3a3024', 90 if run == 2 else 150))
            c.put(x, y - 1, hexc('3a3024', 60 if run == 2 else 110))


def build(run, view_only=False):
    import random
    rng = random.Random(7)                  # the SAME city every run — only its light changes
    c = Canvas(seed=7)
    meta = _view(c, run, rng)
    if view_only:
        return c, meta
    _floor(c, run, rng)
    _plant(c, run)
    _rail(c, run)
    _side_walls(c, run)
    _doors(c, run)
    _frame(c, run)
    return c, meta


RAIN_ORIGIN = (10, 16)                      # module-local top-left of assets/city/rain_balcony.png (80 x 78)


def _visible_view_mask(run):
    """Which pixels of the finished balcony art are still the bare city view (nothing — rail, doors, walls,
    frame, floor — drawn over them): the only places the night's rain, and the fires, may show."""
    full, _m = build(run)
    view, _m2 = build(run, view_only=True)
    w, h = full.img.size
    mask = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            v = view.px[x, y]
            if v[3] > 0 and full.px[x, y] == v:
                mask[y][x] = True
    return mask


def _export_fx(metas):
    """assets/city/balcony_rain.png (the night's rain, cut to the visible view) + balcony_meta.json (where the fires /
    blasts / smoke / aircraft lights may sit, and where rain splashes on the tiles)."""
    import json
    out = os.path.join(ROOT, 'assets', 'city')
    os.makedirs(out, exist_ok=True)
    mask = _visible_view_mask(3)
    strip = Image.open(os.path.join(out, 'rain_balcony.png')).convert('RGBA')
    fw, fh = 80, 78
    px = strip.load()
    for f in range(strip.width // fw):
        for y in range(fh):
            for x in range(fw):
                mx, my = RAIN_ORIGIN[0] + x, RAIN_ORIGIN[1] + y
                ok = 0 <= my < len(mask) and 0 <= mx < len(mask[0]) and mask[my][mx]
                if not ok:
                    px[f * fw + x, y] = (0, 0, 0, 0)
    strip.save(os.path.join(out, 'rain_balcony_masked.png'))
    back_l = int(round(depth_x(X0, EDGE))) + 4
    back_r = int(round(depth_x(X1, EDGE))) - 4
    meta = {'rain_origin': list(RAIN_ORIGIN), 'rain_size': [fw, fh],
            'splash': {'y0': EDGE + 2, 'y1': EDGE + 11, 'x0': back_l, 'x1': back_r}}
    for run in (1, 2, 3):
        m = metas[run]
        keep = lambda pts, ylo, yhi: [list(p) for p in pts if back_l <= p[0] <= back_r and ylo <= p[1] <= yhi]
        meta['run_%d' % run] = {'fire': keep(m['fire'], LINTEL + 4, RAIL - 4), 'blast': keep(m['blast'], LINTEL + 4, RAIL - 2),
                                'smoke': keep(m['smoke'], LINTEL + 4, RAIL - 2), 'beacon': keep(m['beacon'], LINTEL + 4, RAIL - 4)}
    with open(os.path.join(out, 'balcony_meta.json'), 'w') as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)


def main():
    out_dir = os.path.join(ROOT, 'assets', 'rooms')
    prev = []
    metas = {}
    for run in (1, 2, 3):
        c, metas[run] = build(run)
        name = 'balcony' + ('' if run == 1 else '_r%d' % run)
        c.img.save(os.path.join(out_dir, name + '.png'))
        prev.append(c.img)
    _export_fx(metas)
    # preview: each run over the study wall, with the player to scale on the plane and on the rail
    study = [Image.open(os.path.join(out_dir, n)).convert('RGBA')
             for n in ('study.png', 'study_r2.png', 'study_r3.png')]
    sheet = Image.new('RGBA', (3 * 130 * 4, 144 * 4), (0, 0, 0, 255))
    for i, (b, s) in enumerate(zip(prev, study)):
        im = s.copy()
        im.alpha_composite(b)
        crop = im.crop((0, 0, 130, 144)).resize((520, 576), Image.NEAREST)
        sheet.paste(crop, (i * 520, 0))
    os.makedirs(os.path.join(ROOT, 'docs', 'art_reference', 'modules'), exist_ok=True)
    sheet.save(os.path.join(ROOT, 'docs', 'art_reference', 'modules', 'balcony_runs.png'))
    print('balcony: wrote 3 looks (opening x %d..%d, sill %d, edge %d, rail %d, lintel %d)'
          % (X0, X1, SILL, EDGE, RAIL, LINTEL))


if __name__ == '__main__':
    main()
