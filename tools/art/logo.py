#!/usr/bin/env python3
"""THE GAME'S LOGO - "Descend From 30" (owner round 48: "make the logo for the game").

    python3 tools/art/logo.py            write assets/logo/* and docs/logo/logo_sheet.png
    python3 tools/art/logo.py --check    the committed files must be exactly what this script draws (the gate runs it)

Round 48b - the owner's note on the first version (pixel art, dithered print, brick-tower 30): "I don't really like the font. Overall this
all feels a little too AI crap. It needs to be clear and clean."  So this version has almost nothing in it:

  * TWO flat colours and nothing else (warm white + dried blood on a dark ground; ink + blood on a light one);
  * ONE typeface, Barlow Condensed Bold (SIL OFL, assets/fonts/logo/) set in capitals with open tracking - the lettering of building
    signage and lift panels - on two lines of EXACTLY the same width: DESCEND / FROM 30, the 30 in blood;
  * ONE handprint (tools/art/logo_hand.py): a slim, flat shape, as tall as the two lines and aligned to their cap line and baseline.
No bevel, no outline, no shadow, no texture, no gradient, no windows.  Everything is a vector (shapely geometry -> SVG paths, and the same
geometry rasterised for the PNGs), so it scales to any size.

VARIANTS (transparent backgrounds): dark = for dark grounds, light = for light grounds, white / black = one ink.
THE ICON is the print on a dark rounded tile; every size of the .ico is drawn natively from the vector.

The context rule (CLAUDE.md "Context") holds: nothing names or implies a cause, an authority or any preparation; the print is a REACTION,
the same bloody handprint the opening's cold open already shows.
"""
import io
import os
import struct
import sys

import numpy as np
from fontTools.pens.basePen import decomposeQuadraticSegment
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw
from shapely import affinity
from shapely.geometry import Polygon, box
from shapely.ops import unary_union

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import logo_hand

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FONT = os.path.join(ROOT, 'assets', 'fonts', 'logo', 'BarlowCondensed-Bold.ttf')

# ---------------------------------------------------------------------------------------------------------------- palette
WARM = (238, 230, 214)            # warm white, for letters on a dark ground
INK = (24, 16, 28)                # the near-black of the game's night, for letters on a light ground
BLOOD_D = (160, 33, 35)           # dried blood on a dark ground
BLOOD_L = (136, 27, 30)           # the same, a step darker so it holds on a light ground
TILE = (24, 16, 28)               # the icon's ground
THEMES = {
    'dark': {'text': WARM, 'blood': BLOOD_D},
    'light': {'text': INK, 'blood': BLOOD_L},
    'white': {'text': (255, 255, 255), 'blood': (255, 255, 255)},
    'black': {'text': (0, 0, 0), 'blood': (0, 0, 0)},
}

# ---------------------------------------------------------------------------------------------------------------- layout (font units: 1000 / em)
TRACK1 = 80                       # open tracking of the first line; the second line is tracked to the SAME width
LINE_GAP = 200                    # air between the two lines (cap height is 700)
HAND_GAP = 330                    # air between the print and the lettering
SS = 4                            # raster supersample


# ---------------------------------------------------------------------------------------------------------------- type
_FONT = None


def _font():
    global _FONT
    if _FONT is None:
        _FONT = TTFont(FONT)
    return _FONT


def _flatten_quad(p0, c, p1, n=18):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1])
            for t in (i / n for i in range(1, n + 1))]


def _flatten_cubic(p0, c1, c2, p1, n=18):
    out = []
    for i in range(1, n + 1):
        t = i / n
        u = 1 - t
        out.append((u ** 3 * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t ** 3 * p1[0],
                    u ** 3 * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t ** 3 * p1[1]))
    return out


def glyph_geometry(ch):
    """-> (shapely geometry in font units, y UP, advance width, (xmin, xmax))."""
    f = _font()
    name = f.getBestCmap()[ord(ch)]
    gs = f.getGlyphSet()
    adv = f['hmtx'][name][0]
    if ch == ' ':
        return Polygon(), adv, (0, 0)
    pen = DecomposingRecordingPen(gs)
    gs[name].draw(pen)
    contours, cur = [], []
    for op, args in pen.value:
        if op == 'moveTo':
            cur = [args[0]]
        elif op == 'lineTo':
            cur.append(args[0])
        elif op == 'qCurveTo':
            start = cur[-1]
            for (c, e) in decomposeQuadraticSegment(list(args)):
                cur += _flatten_quad(start, c, e)
                start = e
        elif op == 'curveTo':
            cur += _flatten_cubic(cur[-1], *args)
        elif op in ('closePath', 'endPath'):
            if len(cur) >= 3:
                contours.append(cur)
            cur = []
    geom = Polygon()
    for c in contours:                                   # even-odd: a counter is a contour inside a contour
        geom = geom.symmetric_difference(Polygon(c).buffer(0))
    x0, _, x1, _ = geom.bounds
    return geom, adv, (x0, x1)


def cap_height():
    return _font()['OS/2'].sCapHeight


def set_line(text, tracking):
    """-> list of (char, geometry y DOWN with the baseline at y = 0) and the line's ink extent (x0, x1)."""
    out, x = [], 0.0
    ink0, ink1 = None, 0.0
    for ch in text:
        g, adv, (gx0, gx1) = glyph_geometry(ch)
        if not g.is_empty:
            gd = affinity.scale(g, 1, -1, origin=(0, 0))
            out.append((ch, affinity.translate(gd, x, 0)))
            if ink0 is None:
                ink0 = x + gx0
            ink1 = x + gx1
        x += adv + tracking
    return out, (ink0, ink1)


def _justified_tracking(text, target_width):
    """The tracking that makes `text`'s ink exactly `target_width` wide."""
    _, (a, b) = set_line(text, 0)
    return (target_width - (b - a)) / (len(text) - 1)


def build_wordmark():
    """-> {'text': geometry, 'blood': geometry}, bounds (x0, y0, x1, y1) in font units, y DOWN, cap top of line 1 at y = 0."""
    cap = cap_height()
    l1, (a1, b1) = set_line('DESCEND', TRACK1)
    t2 = _justified_tracking('FROM 30', b1 - a1)
    l2, (a2, b2) = set_line('FROM 30', t2)
    text, blood = [], []
    for ch, g in l1:
        text.append(affinity.translate(g, -a1, cap))
    for ch, g in l2:
        (blood if ch in '30' else text).append(affinity.translate(g, -a2, cap + LINE_GAP + cap))
    return {'text': unary_union(text), 'blood': unary_union(blood)}, (0.0, 0.0, b1 - a1, 2 * cap + LINE_GAP)


def hand_for(height):
    """The print scaled to `height` units tall, its top-left at the origin."""
    g = logo_hand.hand_geometry()
    x0, y0, x1, y1 = g.bounds
    s = height / (y1 - y0)
    g = affinity.scale(g, s, s, origin=(0, 0))
    x0, y0, x1, y1 = g.bounds
    return affinity.translate(g, -x0, -y0)


def build_full():
    word, (wx0, wy0, wx1, wy1) = build_wordmark()
    hand = hand_for(wy1 - wy0)
    dx = hand.bounds[2] + HAND_GAP
    word = {k: affinity.translate(v, dx, 0) for k, v in word.items()}
    return {'text': word['text'], 'blood': unary_union([word['blood'], hand])}, (0.0, 0.0, wx1 + dx, wy1)


def build_mark():
    g = hand_for(1600)
    return {'blood': g}, g.bounds


def build_icon():
    """The print on a dark rounded tile (the vector is in a 1000-unit square)."""
    tile = box(0, 0, 1000, 1000).buffer(-220, join_style=1).buffer(220, join_style=1)
    g = logo_hand.hand_geometry()
    x0, y0, x1, y1 = g.bounds
    s = 740.0 / (y1 - y0)
    g = affinity.scale(g, s, s, origin=(0, 0))
    x0, y0, x1, y1 = g.bounds
    g = affinity.translate(g, 500 - (x0 + x1) / 2, 500 - (y0 + y1) / 2)
    return {'tile': tile, 'blood': g}, (0.0, 0.0, 1000.0, 1000.0)


# ---------------------------------------------------------------------------------------------------------------- export
def _ring_d(coords, k):
    pts = list(coords)[:-1]
    return 'M' + 'L'.join('%.1f %.1f' % (x * k, y * k) for x, y in pts) + 'Z'


def _polys(geom):
    return [geom] if geom.geom_type == 'Polygon' else list(getattr(geom, 'geoms', []))


def geom_path(geom, ox=0.0, oy=0.0):
    geom = affinity.translate(geom, -ox, -oy).simplify(0.05)
    d = []
    for p in _polys(geom):
        if p.is_empty:
            continue
        d.append(_ring_d(p.exterior.coords, 1.0))
        for r in p.interiors:
            d.append(_ring_d(r.coords, 1.0))
    return ''.join(d)


def _hex(c):
    return '#%02x%02x%02x' % c


def svg_of(layers, bounds, theme, margin, colours=None):
    """layers {role: geometry}; colours {role: rgb} (default: the theme's)."""
    x0, y0, x1, y1 = bounds
    ox, oy = x0 - margin, y0 - margin
    w, h = (x1 - x0) + 2 * margin, (y1 - y0) + 2 * margin
    cols = colours or THEMES[theme]
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (round(w / 2), round(h / 2), round(w), round(h))]
    for role in ('tile', 'text', 'blood'):
        if role in layers and not layers[role].is_empty:
            parts.append('<path fill="%s" fill-rule="evenodd" d="%s"/>' % (_hex(cols[role]), geom_path(layers[role], ox, oy)))
    parts.append('</svg>')
    return '\n'.join(parts) + '\n'


def _mask(geom, W, H, k, ox, oy):
    """Anti-aliased coverage of `geom` on a W x H canvas: drawn SS x larger, area-averaged down."""
    big = Image.new('L', (W * SS, H * SS), 0)
    d = ImageDraw.Draw(big)
    for p in _polys(geom):
        if p.is_empty:
            continue
        d.polygon([((x - ox) * k * SS, (y - oy) * k * SS) for x, y in p.exterior.coords], fill=255)
        for r in p.interiors:
            d.polygon([((x - ox) * k * SS, (y - oy) * k * SS) for x, y in r.coords], fill=0)
    return big.resize((W, H), Image.BOX)


def raster(layers, bounds, theme, margin, width_px, colours=None):
    """-> RGBA PIL image, `width_px` wide, transparent background."""
    x0, y0, x1, y1 = bounds
    ox, oy = x0 - margin, y0 - margin
    w, h = (x1 - x0) + 2 * margin, (y1 - y0) + 2 * margin
    k = width_px / w
    W, H = int(width_px), int(round(h * k))
    cols = colours or THEMES[theme]
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for role in ('tile', 'text', 'blood'):
        if role in layers and not layers[role].is_empty:
            layer = Image.new('RGBA', (W, H), cols[role] + (0,))
            layer.putalpha(_mask(layers[role], W, H, k, ox, oy))
            out = Image.alpha_composite(out, layer)
    return out


def _png(im):
    b = io.BytesIO()
    im.save(b, 'PNG', optimize=False, compress_level=9)
    return b.getvalue()


def ico_bytes(frames):
    """frames: [(n, png bytes)] -> a multi-size .ico of PNG frames."""
    out = struct.pack('<HHH', 0, 1, len(frames))
    off = 6 + 16 * len(frames)
    blobs = b''
    for n, data in frames:
        out += struct.pack('<BBBBHHII', 0 if n >= 256 else n, 0 if n >= 256 else n, 0, 0, 1, 32, len(data), off + len(blobs))
        blobs += data
    return out + blobs


def all_outputs():
    """-> {relative path: bytes} of every generated file."""
    files = {}
    full, fb = build_full()
    word, wb = build_wordmark()
    mark, mb = build_mark()
    margin = cap_height() * 0.30                             # clear space round every logo = 30 % of the cap height
    for theme in THEMES:
        for name, layers, bounds, wpx in (('logo_full', full, fb, 2400), ('logo_wordmark', word, wb, 1600)):
            base = 'assets/logo/%s_%s' % (name, theme)
            files[base + '.svg'] = svg_of(layers, bounds, theme, margin).encode()
            files[base + '.png'] = _png(raster(layers, bounds, theme, margin, wpx))
            files[base + '_600.png'] = _png(raster(layers, bounds, theme, margin, 600))
    for theme in ('dark', 'light'):
        base = 'assets/logo/mark_handprint_%s' % theme
        files[base + '.svg'] = svg_of(mark, mb, theme, margin).encode()
        files[base + '.png'] = _png(raster(mark, mb, theme, margin, 800))
    cols = {'tile': TILE, 'blood': BLOOD_D}
    ic, ib = build_icon()
    files['assets/logo/icon.svg'] = svg_of(ic, ib, 'dark', 0, cols).encode()
    files['assets/logo/icon.png'] = _png(raster(ic, ib, 'dark', 0, 512, cols))
    files['assets/logo/icon_1024.png'] = _png(raster(ic, ib, 'dark', 0, 1024, cols))
    frames = []
    for n in (16, 32, 48, 64, 128, 256):
        g, b = build_icon()
        frames.append((n, _png(raster(g, b, 'dark', 0, n, cols))))
    files['assets/logo/icon.ico'] = ico_bytes(frames)
    files['docs/logo/logo_sheet.png'] = _png(contact_sheet(full, fb, word, wb, margin))
    return files


def _flat(im, bg):
    base = Image.new('RGBA', im.size, bg + (255,))
    return Image.alpha_composite(base, im).convert('RGB')


def contact_sheet(full, fb, word, wb, margin):
    """Every variant on the ground it is for, and the icon at 128 / 64 / 32 / 16 px."""
    dark, light = (18, 13, 22), (234, 228, 216)
    pad = 28
    tiles = [(raster(full, fb, 'dark', margin, 1100), dark), (raster(full, fb, 'light', margin, 1100), light),
             (raster(word, wb, 'dark', margin, 700), dark), (raster(word, wb, 'light', margin, 700), light),
             (raster(full, fb, 'white', margin, 1100), (70, 70, 76)), (raster(full, fb, 'black', margin, 1100), (216, 216, 210))]
    cw = max(t.width for t, _ in tiles) + 2 * pad
    rows = []
    for i in range(0, 6, 2):
        h = max(tiles[i][0].height, tiles[i + 1][0].height) + 2 * pad
        row = Image.new('RGB', (cw * 2, h))
        for j in (0, 1):
            im, bg = tiles[i + j]
            cell = Image.new('RGB', (cw, h), bg)
            cell.paste(_flat(im, bg), ((cw - im.width) // 2, (h - im.height) // 2))
            row.paste(cell, (j * cw, 0))
        rows.append(row)
    strip = Image.new('RGB', (cw * 2, 128 + 2 * pad), (30, 22, 36))
    cols = {'tile': TILE, 'blood': BLOOD_D}
    x = pad
    for n in (128, 64, 32, 16):
        g, b = build_icon()
        strip.paste(_flat(raster(g, b, 'dark', 0, n, cols), (30, 22, 36)), (x, pad + (128 - n)))
        x += n + pad
    sheet = Image.new('RGB', (cw * 2, sum(r.height for r in rows) + strip.height))
    y = 0
    for r in rows + [strip]:
        sheet.paste(r, (0, y))
        y += r.height
    return sheet


def write_all():
    files = all_outputs()
    for rel, data in files.items():
        p = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'wb') as f:
            f.write(data)
    return files


def _loudness(c):
    import colorsys
    h, s, v = colorsys.rgb_to_hsv(*(x / 255.0 for x in c))
    return s * v, v


def check():
    bad = []
    files = all_outputs()
    for rel, data in files.items():
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            bad.append('missing %s' % rel)
        elif rel.endswith('.png'):
            a = np.asarray(Image.open(p).convert('RGBA'))
            b = np.asarray(Image.open(io.BytesIO(data)).convert('RGBA'))
            if a.shape != b.shape or not (a == b).all():
                bad.append('stale %s' % rel)
        elif open(p, 'rb').read() != data:
            bad.append('stale %s' % rel)
    have = set()
    for sub in ('assets/logo', 'docs/logo'):
        d = os.path.join(ROOT, sub)
        if os.path.isdir(d):
            for fn in os.listdir(d):
                if not fn.endswith('.import') and fn != 'README.md':               # README.md is hand-written
                    have.add('%s/%s' % (sub, fn))
    for extra in sorted(have - set(files)):
        bad.append('extra %s' % extra)
    if not os.path.exists(os.path.join(ROOT, 'assets', 'fonts', 'logo', 'OFL.txt')):
        bad.append("the typeface's licence (assets/fonts/logo/OFL.txt) is missing")
    # the brief: transparent backgrounds, a square icon, two lines of one width
    for rel in files:
        if rel.endswith('.png') and rel.startswith('assets/logo/') and 'icon' not in rel:
            p = os.path.join(ROOT, rel)
            if os.path.exists(p) and not (np.asarray(Image.open(p).convert('RGBA'))[..., 3] == 0).any():
                bad.append('%s is not on a transparent background' % rel)
    for n, rel in ((512, 'assets/logo/icon.png'), (1024, 'assets/logo/icon_1024.png')):
        p = os.path.join(ROOT, rel)
        if os.path.exists(p) and Image.open(p).size != (n, n):
            bad.append('%s is not %d x %d' % (rel, n, n))
    l1, (a1, b1) = set_line('DESCEND', TRACK1)
    l2, (a2, b2) = set_line('FROM 30', _justified_tracking('FROM 30', b1 - a1))
    if abs((b1 - a1) - (b2 - a2)) > 0.5:
        bad.append('the two lines are not the same width (%.1f vs %.1f)' % (b1 - a1, b2 - a2))
    # the print: no fat base (wrist narrower than the palm), in proportion (not a glove), blood and not a cartoon red
    g0 = logo_hand.hand_geometry(rot=0.0)

    def width_at(y):
        sl = g0.intersection(box(-5, y - 0.005, 5, y + 0.005))
        return sl.bounds[2] - sl.bounds[0] if not sl.is_empty else 0.0
    palm, wrist = width_at(0.55), width_at(1.10)
    if wrist > 0.70 * palm:
        bad.append('the print has a fat base: wrist %.2f vs palm %.2f' % (wrist, palm))
    x0, y0, x1, y1 = g0.bounds
    if not (0.55 <= (x1 - x0) / (y1 - y0) <= 0.78):
        bad.append('the print is out of proportion (width / height %.2f)' % ((x1 - x0) / (y1 - y0)))
    for c in (BLOOD_D, BLOOD_L):
        loud, v = _loudness(c)
        if loud > 0.56 or v > 0.70:
            bad.append('the blood colour %s is too loud (saturation x value %.2f, value %.2f; a comic red is ~0.78 / 0.86)' % (c, loud, v))
    return bad


if __name__ == '__main__':
    if '--check' in sys.argv:
        problems = check()
        for b in problems:
            print('LOGO: ' + b)
        if problems:
            print('LOGO: %d problem(s) - run python3 tools/art/logo.py' % len(problems))
            sys.exit(1)
        print('LOGO: assets/logo + docs/logo are exactly what tools/art/logo.py draws')
        sys.exit(0)
    fs = write_all()
    print('wrote %d files' % len(fs))
