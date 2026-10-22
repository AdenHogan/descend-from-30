#!/usr/bin/env python3
"""THE GAME'S LOGO - "Descend From 30" (owner round 48: "make the logo for the game").

    python3 tools/art/logo.py            write assets/logo/* and docs/logo/logo_sheet.png
    python3 tools/art/logo.py --check    the committed files must be exactly what this script draws (the gate runs it)

THE IDEA (owner): a BLOODIED HANDPRINT BEHIND THE NUMBER.  A big 30 in warm white stands over one slim handprint in dried blood - the hand's
fingers rise behind a small line of capitals, DESCEND FROM, that is tracked out to the exact width of the 30 - and the heel of the palm shows
just under it.  (Round 48's first try set the print BESIDE the words; that was wrong.  Its first look, pixel art with a dithered print and a
brick-tower 30, was "AI crap... it needs to be clear and clean", so everything here is flat and plain.)

  * TWO flat colours and nothing else (warm white + dried blood on a dark ground; ink + blood on a light one);
  * ONE typeface, Barlow Condensed Bold (SIL OFL, assets/fonts/logo/), capitals with open tracking - the lettering of building signage and lift panels;
  * ONE handprint (tools/art/logo_hand.py): slim and flat, its palm centred under the middle of the 30.
No bevel, no outline, no shadow, no texture, no gradient.  Everything is a vector (shapely geometry -> SVG paths, and the same geometry
rasterised for the PNGs), so it scales to any size.

VARIANTS (transparent backgrounds): dark = for dark grounds, light = for light grounds (ink letters over a paler print, so they never go dark-on-dark-red),
white / black = one ink (the print is cut back a hair round every letter).  The WORDMARK alone (no print) sets the
30 itself in blood.  THE ICON is the print on a dark rounded tile with the 30 over its palm; every size of the .ico is drawn natively from the vector.

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
BLOOD_PALE = (178, 84, 82)        # the print on a light ground, behind ink letters (ink on it reads 3.9:1, it on the paper 3.8:1)
TILE = (24, 16, 28)               # the icon's ground
THEMES = {
    'dark': {'text': WARM, 'hand': BLOOD_D, 'blood': BLOOD_D},
    'light': {'text': INK, 'hand': BLOOD_PALE, 'blood': BLOOD_L},     # ink letters on the paper, over a paler print; the 30 alone is dark blood
    'white': {'text': (255, 255, 255), 'hand': (255, 255, 255), 'blood': (255, 255, 255)},
    'black': {'text': (0, 0, 0), 'hand': (0, 0, 0), 'blood': (0, 0, 0)},
}
ONE_INK = ('white', 'black')
LAYER_ORDER = ('tile', 'hand', 'blood', 'text')
ONE_INK_GAP = 34.0                # one ink: the print is cut back this far round every letter, so the letters stay clean

# ---------------------------------------------------------------------------------------------------------------- layout (font units: 1000 / em)
NUM_CAP = 1400.0                  # cap height of the big 30
TRACK1 = 120                      # open tracking of DESCEND FROM (font units / 1000): its size follows from fitting the 30's width
STACK_GAP = 0.16                  # air between the two lines, as a share of the 30's cap height
HAND_ABOVE = 0.40                 # the fingertips rise this far over the top line (share of the 30's cap height)
HAND_BELOW = 0.24                 # the heel of the palm hangs this far under the 30's baseline
TRACK_NUM = 25                    # the 3 and the 0 sit close: one mark
MARGIN = 0.12 * NUM_CAP           # clear space round every logo
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


def _scaled(geom, k):
    return affinity.scale(geom, k, k, origin=(0, 0))


def build_stack():
    """DESCEND FROM over a big 30, both on the SAME width (the first line is tracked out to the 30's width).
    -> {'line1': geometry, 'num': geometry}, bounds (x0, y0, x1, y1) in font units, y DOWN, the top of line 1 at y = 0."""
    cap = cap_height()
    k2 = NUM_CAP / cap
    num_chars, (n0, n1) = set_line('30', TRACK_NUM)
    width = (n1 - n0) * k2
    _, (a0, b0) = set_line('DESCEND FROM', TRACK1)
    k1 = width / (b0 - a0)                                          # the line's size is whatever fits the 30's width at that tracking
    c1 = cap * k1
    l1, (a1, b1) = set_line('DESCEND FROM', TRACK1)
    base2 = c1 + NUM_CAP * STACK_GAP + NUM_CAP                      # the 30's baseline
    line1 = unary_union([affinity.translate(_scaled(g, k1), -a1 * k1, c1) for ch, g in l1])
    num = unary_union([affinity.translate(_scaled(g, k2), -n0 * k2, base2) for ch, g in num_chars])
    return {'line1': line1, 'num': num}, (0.0, 0.0, width, base2)


def hand_behind(stack_bounds):
    """The print scaled so its fingertips stand HAND_ABOVE over the top line and its heel hangs HAND_BELOW under the 30, the print's box centred on the 30."""
    x0, y0, x1, y1 = stack_bounds
    g = logo_hand.hand_geometry()
    gx0, gy0, gx1, gy1 = g.bounds
    target = (y1 - y0) + NUM_CAP * (HAND_ABOVE + HAND_BELOW)
    s = target / (gy1 - gy0)
    g = affinity.scale(g, s, s, origin=(0, 0))
    gx0, gy0, gx1, gy1 = g.bounds
    return affinity.translate(g, (x0 + x1) / 2.0 - (gx0 + gx1) / 2.0, y0 - NUM_CAP * HAND_ABOVE - gy0)      # the print's own box is centred on the 30


def _union_bounds(*bs):
    return (min(b[0] for b in bs), min(b[1] for b in bs), max(b[2] for b in bs), max(b[3] for b in bs))


def build_full():
    """-> parts {'hand', 'line1', 'num'}, bounds."""
    stack, sb = build_stack()
    hand = hand_behind(sb)
    parts = {'hand': hand, 'line1': stack['line1'], 'num': stack['num']}
    return parts, _union_bounds(sb, hand.bounds)


def layers_for(theme, parts):
    """The drawable layers of a logo in a theme.  A wordmark (no 'hand') sets the 30 itself in blood."""
    hand = parts.get('hand')
    text = unary_union([parts['line1'], parts['num']])
    if hand is None:
        if theme in ONE_INK:
            return {'text': text}
        return {'text': parts['line1'], 'blood': parts['num']}
    if theme in ONE_INK:                                             # one ink: the print is cut back a hair round the letters
        return {'text': unary_union([text, hand.difference(text.buffer(ONE_INK_GAP, join_style=1))])}
    return {'hand': hand, 'text': text}


def build_mark():
    g = logo_hand.hand_geometry()
    x0, y0, x1, y1 = g.bounds
    s = 1600.0 / (y1 - y0)
    g = affinity.translate(affinity.scale(g, s, s, origin=(0, 0)), -x0 * s, -y0 * s)
    return {'blood': g}, g.bounds


ICON_COLOURS = {'tile': TILE, 'hand': BLOOD_D, 'text': WARM}


def build_icon():
    """The print on a dark rounded tile with the 30 over its palm (the vector is in a 1000-unit square)."""
    tile = box(0, 0, 1000, 1000).buffer(-220, join_style=1).buffer(220, join_style=1)
    g = logo_hand.hand_geometry()
    x0, y0, x1, y1 = g.bounds
    s = 880.0 / (y1 - y0)
    g = affinity.scale(g, s, s, origin=(0, 0))
    gx0, gy0, gx1, gy1 = g.bounds
    ox, oy = 500 - (gx0 + gx1) / 2.0, 60 - gy0                        # the print's box centred on the tile
    g = affinity.translate(g, ox, oy)
    chars, (n0, n1) = set_line('30', TRACK_NUM)
    cap = 400.0
    k = cap / cap_height()
    num = unary_union([affinity.translate(_scaled(c, k), -(n0 + n1) / 2.0 * k + 500, oy + 0.78 * s + cap / 2.0) for ch, c in chars])
    return {'tile': tile, 'hand': g, 'text': num}, (0.0, 0.0, 1000.0, 1000.0)


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
    for role in LAYER_ORDER:
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
    for role in LAYER_ORDER:
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
    word, wb = build_stack()
    mark, mb = build_mark()
    margin = MARGIN
    for theme in THEMES:
        for name, parts, bounds, wpx in (('logo_full', full, fb, 2000), ('logo_wordmark', word, wb, 1400)):
            layers = layers_for(theme, parts)
            base = 'assets/logo/%s_%s' % (name, theme)
            files[base + '.svg'] = svg_of(layers, bounds, theme, margin).encode()
            files[base + '.png'] = _png(raster(layers, bounds, theme, margin, wpx))
            files[base + '_600.png'] = _png(raster(layers, bounds, theme, margin, 600))
    for theme in ('dark', 'light'):
        base = 'assets/logo/mark_handprint_%s' % theme
        files[base + '.svg'] = svg_of(mark, mb, theme, MARGIN * 0.5).encode()
        files[base + '.png'] = _png(raster(mark, mb, theme, MARGIN * 0.5, 800))
    ic, ib = build_icon()
    files['assets/logo/icon.svg'] = svg_of(ic, ib, 'dark', 0, ICON_COLOURS).encode()
    files['assets/logo/icon.png'] = _png(raster(ic, ib, 'dark', 0, 512, ICON_COLOURS))
    files['assets/logo/icon_1024.png'] = _png(raster(ic, ib, 'dark', 0, 1024, ICON_COLOURS))
    files['assets/logo/icon.ico'] = ico_bytes([(n, _png(raster(ic, ib, 'dark', 0, n, ICON_COLOURS))) for n in (16, 32, 48, 64, 128, 256)])
    files['docs/logo/logo_sheet.png'] = _png(contact_sheet(full, fb, word, wb, margin))
    return files


def _flat(im, bg):
    base = Image.new('RGBA', im.size, bg + (255,))
    return Image.alpha_composite(base, im).convert('RGB')


def contact_sheet(full, fb, word, wb, margin):
    """Every variant on the ground it is for, and the icon at 128 / 64 / 32 / 16 px."""
    dark, light = (18, 13, 22), (234, 228, 216)
    pad = 28

    def tile(parts, bounds, theme, w):
        return raster(layers_for(theme, parts), bounds, theme, margin, w)
    tiles = [(tile(full, fb, 'dark', 700), dark), (tile(full, fb, 'light', 700), light),
             (tile(word, wb, 'dark', 560), dark), (tile(word, wb, 'light', 560), light),
             (tile(full, fb, 'white', 700), (70, 70, 76)), (tile(full, fb, 'black', 700), (216, 216, 210))]
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
    ic, ib = build_icon()
    x = pad
    for n in (128, 64, 32, 16):
        strip.paste(_flat(raster(ic, ib, 'dark', 0, n, ICON_COLOURS), (30, 22, 36)), (x, pad + (128 - n)))
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
    # the brief: transparent backgrounds, a square icon, two lines of one width, the print behind the 30
    for rel in files:
        if rel.endswith('.png') and rel.startswith('assets/logo/') and 'icon' not in rel:
            p = os.path.join(ROOT, rel)
            if os.path.exists(p) and not (np.asarray(Image.open(p).convert('RGBA'))[..., 3] == 0).any():
                bad.append('%s is not on a transparent background' % rel)
    for n, rel in ((512, 'assets/logo/icon.png'), (1024, 'assets/logo/icon_1024.png')):
        p = os.path.join(ROOT, rel)
        if os.path.exists(p) and Image.open(p).size != (n, n):
            bad.append('%s is not %d x %d' % (rel, n, n))
    stack, (sx0, sy0, sx1, sy1) = build_stack()
    w1 = stack['line1'].bounds[2] - stack['line1'].bounds[0]
    w2 = stack['num'].bounds[2] - stack['num'].bounds[0]
    if abs(w1 - w2) > 0.5:
        bad.append('DESCEND FROM and the 30 are not the same width (%.1f vs %.1f)' % (w1, w2))
    full_parts, _ = build_full()
    hb, nb = full_parts['hand'].bounds, stack['num'].bounds
    if not (hb[0] < nb[0] + 0.5 * (nb[2] - nb[0]) < hb[2] and hb[1] < nb[1] and hb[3] > nb[3]):
        bad.append('the print is not behind the 30 (it must rise above it and hang below it)')
    behind = full_parts['hand'].intersection(full_parts['num']).area / full_parts['num'].area
    if behind < 0.25:
        bad.append('the print is barely behind the 30 (only %.0f %% of the numerals stand over it)' % (100 * behind))
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
    for c in (BLOOD_D, BLOOD_L, BLOOD_PALE):
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
