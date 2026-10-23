#!/usr/bin/env python3
"""THE GAME'S LOGO - "Descend From 30" (owner round 48: "make the logo for the game").

    python3 tools/art/logo.py            write assets/logo/* and docs/logo/logo_sheet.png
    python3 tools/art/logo.py --check    the committed files must be what this script draws, give or take rounding (the gate runs it)

THE LOGO IS THE BLOODIED HANDPRINT (owner, round 48c: "the logo is the bloodied handprint and if that doesn't work then the logo doesn't work").
A real print on a wall, behind the number: tools/art/logo_print.py draws how it TRANSFERRED - hard-pressed pads, the print breaking at the joints and
the creases of the palm, a wet uneven edge, thick blood dark and thin blood bright, a few drips and a little spatter.  A flat red silhouette read as a
cold-war poster, and a pixel-art / brick-tower version as "AI crap"; this is neither.

THE TYPE the owner likes ("clean and mature"): Barlow Condensed Bold capitals (SIL OFL, assets/fonts/logo/), vector, plain - no bevel, outline,
shadow or distress.  The hard-worn thing is the print; the lettering stays quiet so the print does the work.

LAYOUT (round 48c, after the owner's reference; round 48d "directly behind the number"): DESCEND over FROM on the left, the big 30 on the right, the print
DIRECTLY BEHIND the 30 - the hand's middle on the numerals' middle, its fingers rising over them, its wrist and drips hanging under them.  Landscape.

VARIANTS (transparent backgrounds): dark = warm-white letters for dark grounds; light = ink letters for light grounds, the 30 warm white with an ink
keyline so it reads over the blood AND over the paper.  The WORDMARK alone (no print, a pure vector: SVG + PNG) sets the 30 itself in blood.
THE ICON is the print on a dark rounded tile with the 30 over its palm.

The context rule (CLAUDE.md "Context") holds: nothing names or implies a cause, an authority or any preparation; the print is a REACTION,
the same bloody handprint the opening's cold open already shows.
"""
import io
import os
import struct
import sys

import numpy as np
import shapely
from fontTools.pens.basePen import decomposeQuadraticSegment
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw
from shapely import affinity
from shapely.geometry import Point, Polygon, box
from shapely.ops import unary_union

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import logo_hand
import logo_print

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FONT = os.path.join(ROOT, 'assets', 'fonts', 'logo', 'BarlowCondensed-Bold.ttf')

# ---------------------------------------------------------------------------------------------------------------- palette
WARM = (238, 230, 214)            # warm white, for letters on a dark ground
INK = (24, 16, 28)                # the near-black of the game's night, for letters on a light ground
_MID = 0.45 * logo_print.THIN + 0.55 * logo_print.THICK
BLOOD_D = tuple(int(round(v)) for v in _MID)                       # the flat blood of the wordmark's 30 = the print's own mid tone
BLOOD_L = tuple(int(round(v * 0.9)) for v in _MID)                  # a step darker on paper
TILE = (24, 16, 28)               # the icon's ground

# ---------------------------------------------------------------------------------------------------------------- layout (font units: 1000 / em)
NUM_H = 1400.0                    # the height of the 30
LINE_GAP = 0.12                   # between DESCEND and FROM, as a share of the 30's height (the two lines + the gap = the 30's height)
TRACK_TEXT = 14                   # open tracking of DESCEND / FROM
TRACK_NUM = 25                    # the 3 and the 0 sit close: one mark
WORD_GAP = 0.17                   # the plain wordmark: between the words and its 30, as a share of the 30's height
GAP_X = 0.10                      # between the words and the 30, as a share of the 30's height
HAND_WIDTH = 1.40                 # the print's box (thumb to little finger) is this wide, as a share of the 30's width: a hand a little wider than its number
HAND_DY = 0.00                    # the middle of the hand sits this far below the middle of the 30, as a share of the 30's height (0 = centred on it)
CLEAR = 0.12                      # clear space between the words and the thumb, as a share of the 30's height
MARGIN = 0.10 * NUM_H             # clear space round every logo
PRINT_PX = 2200                   # the print is drawn this tall, then scaled down for every output
SS = 3                            # vector raster supersample

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
    """-> the line's glyphs as one geometry (y DOWN, baseline at y = 0) and its ink extent (x0, x1)."""
    parts, x = [], 0.0
    ink0, ink1 = None, 0.0
    for ch in text:
        g, adv, (gx0, gx1) = glyph_geometry(ch)
        if not g.is_empty:
            parts.append(affinity.translate(affinity.scale(g, 1, -1, origin=(0, 0)), x, 0))
            if ink0 is None:
                ink0 = x + gx0
            ink1 = x + gx1
        x += adv + tracking
    return unary_union(parts), (ink0, ink1)


def _scaled(geom, k):
    return affinity.scale(geom, k, k, origin=(0, 0))


_EDGE = None


def _left_edge():
    """The print's leftmost inked pixel on every 4th row, as (x, y) print pixels - the part that could meet the words."""
    global _EDGE
    if _EDGE is None:
        img, info = the_print()
        a = img[::4, :, 3] > 40
        rows = np.nonzero(a.any(axis=1))[0]
        _EDGE = (np.stack([a[rows].argmax(axis=1), rows * 4], axis=1).astype(float), info)
    return _EDGE


def _ink_gap(words, scale, origin):
    """Distance from the words to the nearest ink of the print placed at `origin` with `scale` (units per palm-width)."""
    px, info = _left_edge()
    u = scale / info['scale']
    pts = shapely.points(origin[0] + (px[:, 0] - info['ox']) * u, origin[1] + (px[:, 1] - info['oy']) * u)
    return float(shapely.distance(words, pts).min())


# ---------------------------------------------------------------------------------------------------------------- layout
def build_layout(with_print=True):
    """-> dict of shapely geometry in logo units (y DOWN, the top of the 30 at y = 0):
    desc, frm (the two lines), num (the 30) and the hand's placement (palm-width -> unit scale and origin).
    `with_print=False` is the plain wordmark: the 30 sits GAP_X from the words, with no room made for the print."""
    cap = cap_height()
    n_geom, (n0, n1) = set_line('30', TRACK_NUM)
    nb = n_geom.bounds
    kn = NUM_H / (nb[3] - nb[1])
    num = affinity.translate(_scaled(n_geom, kn), -nb[0] * kn, -nb[1] * kn)          # top-left of the ink at (0, 0)
    gap = LINE_GAP * NUM_H
    c = (NUM_H - gap) / 2.0                                                          # the cap height of the two lines
    kt = c / cap
    d_geom, (d0, d1) = set_line('DESCEND', TRACK_TEXT)
    f_geom, (f0, f1) = set_line('FROM', TRACK_TEXT)
    desc = affinity.translate(_scaled(d_geom, kt), -d0 * kt, c)                      # baseline at y = c, cap top at 0
    frm = affinity.translate(_scaled(f_geom, kt), -f0 * kt, NUM_H)                   # baseline at the 30's foot
    wd = (d1 - d0) * kt
    dx = wd + (GAP_X if with_print else WORD_GAP) * NUM_H
    num = affinity.translate(num, dx, 0)
    # the print: DIRECTLY behind the 30 (owner: "the handprint should be directly behind the number") - the hand's own middle (its centre of mass: the
    # palm) on the middle of the numerals, the fingers standing above them and the wrist and the drips hanging below
    g = logo_hand.hand_geometry()
    gx0, gy0, gx1, gy1 = g.bounds
    nw = num.bounds[2] - num.bounds[0]
    s = HAND_WIDTH * nw / (gx1 - gx0)                                                # units per palm-width
    ccx, ccy = g.centroid.x, g.centroid.y
    ncx, ncy = (num.bounds[0] + num.bounds[2]) / 2.0, (num.bounds[1] + num.bounds[3]) / 2.0
    hx = ncx - ccx * s
    hy = ncy + HAND_DY * NUM_H - ccy * s
    # the words must not touch the print: the nearest INK (its wobbly edge, not the clean outline) must stay CLEAR away, or the 30 and its print move right together
    words = unary_union([desc, frm])
    for _ in range(8 if with_print else 0):
        gap = _ink_gap(words, s, (hx, hy))
        if gap >= CLEAR * NUM_H - 1e-6:
            break
        step = CLEAR * NUM_H - gap
        num = affinity.translate(num, step, 0)
        hx += step
    return {'desc': desc, 'frm': frm, 'num': num, 'hand_scale': s, 'hand_origin': (hx, hy)}


_PRINT = None


def the_print():
    """The textured print (RGBA uint8, drawn once per run) and its info."""
    global _PRINT
    if _PRINT is None:
        _PRINT = logo_print.print_image(PRINT_PX)
    return _PRINT


def print_rect(lay):
    """Where the print's image lies in logo units: (x0, y0, x1, y1) of its inked pixels, and of the whole image."""
    img, info = the_print()
    u = lay['hand_scale'] / info['scale']                                            # units per print pixel
    hx, hy = lay['hand_origin']
    ix0, iy0 = hx - info['ox'] * u, hy - info['oy'] * u
    ys, xs = np.nonzero(img[..., 3] > 6)
    return ((ix0 + xs.min() * u, iy0 + ys.min() * u, ix0 + (xs.max() + 1) * u, iy0 + (ys.max() + 1) * u),
            (ix0, iy0, ix0 + info['w'] * u, iy0 + info['h'] * u))


# ---------------------------------------------------------------------------------------------------------------- rendering
def _polys(geom):
    return [geom] if geom.geom_type == 'Polygon' else list(getattr(geom, 'geoms', []))


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


def _paint(im, geom, colour, k, ox, oy):
    W, H = im.size
    layer = Image.new('RGBA', (W, H), tuple(colour) + (0,))
    layer.putalpha(_mask(geom, W, H, k, ox, oy))
    return Image.alpha_composite(im, layer)


def _specks(num, n=9, seed=5):
    """A few droplets of blood that landed on the 30 (round, small, none near the edge)."""
    rng = np.random.RandomState(seed)
    x0, y0, x1, y1 = num.bounds
    inner = num.buffer(-0.02 * NUM_H)
    out = []
    while len(out) < n:
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        if inner.contains(Point(x, y)):
            r = float(np.exp(rng.normal(np.log(0.0085 * NUM_H), 0.5)))
            out.append(Point(x, y).buffer(min(r, 0.02 * NUM_H), 24))
    return unary_union(out)


def render(parts, bounds, width_px, theme, hand=None, specks=None):
    """-> RGBA PIL image `width_px` wide.  parts: {'desc','frm','num'} geometry; `hand`: the layout (to place the print) or None."""
    x0, y0, x1, y1 = bounds
    ox, oy = x0 - MARGIN, y0 - MARGIN
    w, h = (x1 - x0) + 2 * MARGIN, (y1 - y0) + 2 * MARGIN
    k = width_px / w
    W, H = int(width_px), int(round(h * k))
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    if hand is not None:
        img, info = the_print()
        u = hand['hand_scale'] / info['scale']
        hx, hy = hand['hand_origin']
        px, py = (hx - info['ox'] * u - ox) * k, (hy - info['oy'] * u - oy) * k
        pw, ph = int(round(info['w'] * u * k)), int(round(info['h'] * u * k))
        pr = Image.fromarray(img, 'RGBA').resize((pw, ph), Image.LANCZOS)
        im.alpha_composite(pr, (int(round(px)), int(round(py)))) if px >= 0 and py >= 0 else _paste_clipped(im, pr, int(round(px)), int(round(py)))
    lines = unary_union([parts['desc'], parts['frm']])
    if hand is not None:
        if theme == 'light':                                         # the 30: warm white inside an ink keyline, so it reads over blood and over paper
            key = parts['num'].buffer(0.016 * NUM_H, join_style=1).difference(parts['num'])
            im = _paint(im, key, INK, k, ox, oy)
            im = _paint(im, lines, INK, k, ox, oy)
            im = _paint(im, parts['num'], WARM, k, ox, oy)
        else:
            im = _paint(im, lines, WARM, k, ox, oy)
            im = _paint(im, parts['num'], WARM, k, ox, oy)
        if specks is not None:
            im = _paint(im, specks, tuple(int(v) for v in logo_print.THIN * 0.55 + logo_print.THICK * 0.45), k, ox, oy)
    else:
        text, blood = (WARM, BLOOD_D) if theme == 'dark' else (INK, BLOOD_L)
        im = _paint(im, lines, text, k, ox, oy)
        im = _paint(im, parts['num'], blood, k, ox, oy)
    return im


def _paste_clipped(dst, src, x, y):
    W, H = dst.size
    sx0, sy0 = max(0, -x), max(0, -y)
    sx1, sy1 = min(src.width, W - x), min(src.height, H - y)
    if sx1 > sx0 and sy1 > sy0:
        dst.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))


def _union_bounds(*bs):
    return (min(b[0] for b in bs), min(b[1] for b in bs), max(b[2] for b in bs), max(b[3] for b in bs))


def full_bounds(lay):
    ink, _whole = print_rect(lay)
    tb = unary_union([lay['desc'], lay['frm'], lay['num']]).bounds
    return _union_bounds(tb, ink)


def word_bounds(lay):
    return unary_union([lay['desc'], lay['frm'], lay['num']]).bounds


# ---------------------------------------------------------------------------------------------------------------- the pieces
def render_full(theme, width_px):
    lay = build_layout()
    return render(lay, full_bounds(lay), width_px, theme, hand=lay, specks=_specks(lay['num']))


def render_wordmark(theme, width_px):
    lay = build_layout(False)
    return render(lay, word_bounds(lay), width_px, theme)


def svg_wordmark(theme):
    """The wordmark is pure vector: SVG paths (the lines in one colour, the 30 in blood)."""
    lay = build_layout(False)
    x0, y0, x1, y1 = word_bounds(lay)
    ox, oy = x0 - MARGIN, y0 - MARGIN
    w, h = (x1 - x0) + 2 * MARGIN, (y1 - y0) + 2 * MARGIN
    text, blood = (WARM, BLOOD_D) if theme == 'dark' else (INK, BLOOD_L)

    def d_of(geom):
        geom = affinity.translate(geom, -ox, -oy).simplify(0.05)
        out = []
        for p in _polys(geom):
            for ring in [p.exterior] + list(p.interiors):
                pts = list(ring.coords)[:-1]
                out.append('M' + 'L'.join('%.1f %.1f' % (x, y) for x, y in pts) + 'Z')
        return ''.join(out)
    hexc = lambda c: '#%02x%02x%02x' % tuple(c)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
            '<path fill="%s" fill-rule="evenodd" d="%s"/>\n<path fill="%s" fill-rule="evenodd" d="%s"/>\n</svg>\n'
            % (round(w / 2), round(h / 2), round(w), round(h), hexc(text), d_of(unary_union([lay['desc'], lay['frm']])), hexc(blood), d_of(lay['num']))).encode()


def render_mark(width_px):
    """The print alone (drips and all), cropped to its ink, transparent."""
    img, _info = the_print()
    ys, xs = np.nonzero(img[..., 3] > 6)
    crop = Image.fromarray(img[ys.min():ys.max() + 1, xs.min():xs.max() + 1], 'RGBA')
    h = int(round(crop.height * width_px / crop.width))
    return crop.resize((width_px, h), Image.LANCZOS)


def render_icon(n):
    """The print on a dark rounded tile with the 30 over its palm, n px square."""
    S = float(n)
    tile = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    m = Image.new('L', (n * 4, n * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, n * 4 - 1, n * 4 - 1], radius=int(0.22 * n * 4), fill=255)
    layer = Image.new('RGBA', (n, n), TILE + (0,))
    layer.putalpha(m.resize((n, n), Image.BOX))
    tile = Image.alpha_composite(tile, layer)
    img, info = the_print()
    # fit the print's hand (not its drips) into the tile: the hand's own box, centred, 80 % of the tile tall
    g = logo_hand.hand_geometry()
    gx0, gy0, gx1, gy1 = g.bounds
    hand_h = (gy1 - gy0) * info['scale']                                              # the hand's height in print pixels
    f = 0.78 * S / hand_h
    pr = Image.fromarray(img, 'RGBA').resize((int(round(info['w'] * f)), int(round(info['h'] * f))), Image.LANCZOS)
    hx0 = (gx0 * info['scale'] + info['ox']) * f
    hy0 = (gy0 * info['scale'] + info['oy']) * f
    x = int(round(S / 2 - (gx1 - gx0) * info['scale'] * f / 2 - hx0))
    y = int(round(0.09 * S - hy0))
    _paste_clipped(tile, pr, x, y)
    # the tile is a rounded square: nothing of the print outside it
    clip = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    clip.putalpha(m.resize((n, n), Image.BOX))
    a = np.minimum(np.asarray(tile)[..., 3], np.asarray(clip)[..., 3])
    t = np.asarray(tile).copy()
    t[..., 3] = a
    tile = Image.fromarray(t, 'RGBA')
    # the 30, over the palm
    cap = 0.30 * S
    chars, (a0, a1) = set_line('30', TRACK_NUM)
    nb = chars.bounds
    kk = cap / (nb[3] - nb[1])
    num = affinity.translate(_scaled(chars, kk), S / 2 - (a0 + a1) / 2 * kk, 0.60 * S + cap / 2 - nb[3] * kk)
    return _paint(tile, num, WARM, 1.0, 0.0, 0.0)


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
    for theme in ('dark', 'light'):
        full = render_full(theme, 2400)
        files['assets/logo/logo_full_%s.png' % theme] = _png(full)
        files['assets/logo/logo_full_%s_600.png' % theme] = _png(full.resize((600, int(round(full.height * 600 / full.width))), Image.LANCZOS))
        word = render_wordmark(theme, 1600)
        files['assets/logo/logo_wordmark_%s.png' % theme] = _png(word)
        files['assets/logo/logo_wordmark_%s_600.png' % theme] = _png(render_wordmark(theme, 600))
        files['assets/logo/logo_wordmark_%s.svg' % theme] = svg_wordmark(theme)
    files['assets/logo/mark_handprint.png'] = _png(render_mark(1000))
    files['assets/logo/icon.png'] = _png(render_icon(512))
    files['assets/logo/icon_1024.png'] = _png(render_icon(1024))
    files['assets/logo/icon.ico'] = ico_bytes([(n, _png(render_icon(n))) for n in (16, 32, 48, 64, 128, 256)])
    files['docs/logo/logo_sheet.png'] = _png(contact_sheet())
    return files


def _flat(im, bg):
    base = Image.new('RGBA', im.size, bg + (255,))
    return Image.alpha_composite(base, im).convert('RGB')


def contact_sheet():
    """Every variant on the ground it is for, the print alone, and the icon at 128 / 64 / 32 / 16 px."""
    dark, light = (18, 13, 22), (234, 228, 216)
    pad = 36
    a = _flat(render_full('dark', 1500), dark)
    b = _flat(render_full('light', 1500), light)
    c = _flat(render_wordmark('dark', 760), dark)
    d = _flat(render_wordmark('light', 760), light)
    width = a.width + 2 * pad

    def cell(im, bg, w, h):
        out = Image.new('RGB', (w, h), bg)
        out.paste(im, ((w - im.width) // 2, (h - im.height) // 2))
        return out
    ha, hb = a.height + 2 * pad, b.height + 2 * pad
    hc = max(c.height, d.height) + 2 * pad
    sheet = Image.new('RGB', (width * 2, ha + hc + 128 + 2 * pad), dark)
    sheet.paste(cell(a, dark, width, ha), (0, 0))
    sheet.paste(cell(b, light, width, hb), (width, 0))
    sheet.paste(cell(c, dark, width, hc), (0, ha))
    sheet.paste(cell(d, light, width, hc), (width, ha))
    strip = Image.new('RGB', (width * 2, 128 + 2 * pad), (30, 22, 36))
    x = pad
    for n in (128, 64, 32, 16):
        strip.paste(_flat(render_icon(n), (30, 22, 36)), (x, pad + (128 - n)))
        x += n + pad
    mk = _flat(render_mark(128 + 0), (30, 22, 36))
    strip.paste(mk, (width * 2 - mk.width - pad, pad))
    sheet.paste(strip, (0, ha + hc))
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
            a = np.asarray(Image.open(p).convert('RGBA')).astype(np.int16)
            b = np.asarray(Image.open(io.BytesIO(data)).convert('RGBA')).astype(np.int16)
            if a.shape != b.shape:
                bad.append('stale %s (size)' % rel)
            else:                                                   # the print is procedural: allow rounding, refuse a different picture
                diff = np.abs(a - b)
                if diff.mean() > 0.6 or (diff.max(axis=2) > 24).mean() > 0.002:
                    bad.append('stale %s (mean diff %.2f)' % (rel, diff.mean()))
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
    for rel in files:                                               # the brief: transparent backgrounds, a square icon
        if rel.endswith('.png') and rel.startswith('assets/logo/') and 'icon' not in rel:
            p = os.path.join(ROOT, rel)
            if os.path.exists(p) and not (np.asarray(Image.open(p).convert('RGBA'))[..., 3] == 0).any():
                bad.append('%s is not on a transparent background' % rel)
    for n, rel in ((512, 'assets/logo/icon.png'), (1024, 'assets/logo/icon_1024.png')):
        p = os.path.join(ROOT, rel)
        if os.path.exists(p) and Image.open(p).size != (n, n):
            bad.append('%s is not %d x %d' % (rel, n, n))
    # the composition: the print is DIRECTLY behind the 30 - the hand's middle on the middle of the numerals (within a tenth of the 30's size),
    # its fingers rising above them, its wrist hanging under them, most of the numerals standing over the hand, and the thumb clear of the words
    lay = build_layout()
    g = affinity.translate(_scaled(logo_hand.hand_geometry(), lay['hand_scale']), *lay['hand_origin'])
    nb, hb = lay['num'].bounds, g.bounds
    ncx, ncy = (nb[0] + nb[2]) / 2.0, (nb[1] + nb[3]) / 2.0
    if abs(g.centroid.x - ncx) > 0.10 * (nb[2] - nb[0]) or abs(g.centroid.y - ncy) > 0.10 * (nb[3] - nb[1]):
        bad.append('the print is not directly behind the 30 (the hand is %.0f / %.0f units off the middle of the numerals)' % (g.centroid.x - ncx, g.centroid.y - ncy))
    if not (hb[1] < nb[1] and hb[3] > nb[3]):
        bad.append('the print must rise above the 30 and hang below it')
    behind = g.intersection(lay['num']).area / lay['num'].area
    if behind < 0.55:
        bad.append('the print is barely behind the 30 (only %.0f %% of the numerals stand over it)' % (100 * behind))
    words = unary_union([lay['desc'], lay['frm']])
    if words.bounds[2] > nb[0] or _ink_gap(words, lay['hand_scale'], lay['hand_origin']) < 0.10 * NUM_H:
        bad.append('DESCEND / FROM run into the 30 or the print')
    # the print: no fat base (wrist narrower than the palm), in proportion (not a glove), and the blood is blood, not a cartoon red
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
    for name, c in (('THIN', logo_print.THIN), ('THICK', logo_print.THICK), ('flat blood', BLOOD_D)):
        loud, v = _loudness(tuple(float(x) for x in c))
        if loud > 0.60 or v > 0.74:
            bad.append('the blood tone %s %s is too loud (saturation x value %.2f, value %.2f; a comic red is ~0.78 / 0.86)' % (name, tuple(int(x) for x in c), loud, v))
    return bad


if __name__ == '__main__':
    if '--check' in sys.argv:
        problems = check()
        for b in problems:
            print('LOGO: ' + b)
        if problems:
            print('LOGO: %d problem(s) - run python3 tools/art/logo.py' % len(problems))
            sys.exit(1)
        print('LOGO: assets/logo + docs/logo are what tools/art/logo.py draws')
        sys.exit(0)
    fs = write_all()
    print('wrote %d files' % len(fs))
