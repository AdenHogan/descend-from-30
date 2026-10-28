#!/usr/bin/env python3
"""THE GAME'S LOGO - "Descend From 30" (owner round 48: "make the logo for the game"; round 48m: the final look).

    python3 tools/art/logo.py            write assets/logo/* and docs/logo/logo_sheet.png
    python3 tools/art/logo.py --check    the committed files must be what this script draws, give or take rounding (the gate runs it)
    python3 tools/art/logo.py --press    write the big advertising renders to docs/press/ (6000 px wide, transparent + on the dark ground; not in the gate)

THE LOGO IS THE BLOODIED HANDPRINT (owner, round 48c: "the logo is the bloodied handprint and if that doesn't work then the logo doesn't work").  Since round 48m it is
the OWNER'S OWN HAND: they painted it in blood paint and photographed it, and tools/art/logo_photo.py cuts it out and draws it as a print - the real outline, the real
pressure and palm lines, no glare, no gloss, a pooled darker rim, and drips that each end differently.  (A procedural print and an AI edit of the photo were both
rejected: "AI crap", "a real jpeg under the text".)  It stands DIRECTLY BEHIND the 30.

THE TYPE (owner round 48m, after trying eight faces and condensing the wide ones to a common footprint): DESCEND FROM is ALDRICH (SIL OFL, by Matthew Desmond) - a
squared, slightly technical capital with a strong M - set compact (squeezed to 0.76 of its width with the vertical stems put back, slightly emboldened, tracked
close) - and the 30 is BARLOW CONDENSED BOLD (SIL OFL), whose round 0 cannot be mistaken for the O of FROM.  Barlow alone was "a bit like the Last of Us".  Both are
worn the same way, with the same grain, scratches and strikes of blood (tools/art/logo_text.py).

LAYOUT (round 48c, after the owner's reference; round 48d "directly behind the number"; round 48i "too spaced out"): DESCEND over FROM on the left (FROM flush with DESCEND's
right end, so both lines sit the same distance from the 30), the big 30 on the right, the print DIRECTLY BEHIND the 30 - the hand's middle on the numerals' middle, its fingers
rising over them, its heel and its drips hanging under them (three run down behind the M).  Landscape, 1.65 : 1.

VARIANTS (transparent backgrounds): dark = cream letters for dark grounds; light = ink words for light grounds, the 30 cream with an ink keyline so it reads over the blood AND over
the paper.  The WORDMARK alone (no print, a pure vector: SVG + PNG) sets the 30 itself in blood.  THE ICON is the print on a dark rounded tile with the 30 over its palm.

The context rule (CLAUDE.md "Context") holds: nothing names or implies a cause, an authority or any preparation; the print is a REACTION.
"""
import io
import os
import struct
import sys

import numpy as np
from fontTools.pens.basePen import BasePen
from fontTools.ttLib import TTFont
from PIL import Image, ImageChops, ImageDraw
from shapely import affinity
from shapely.geometry import Polygon, box
from shapely.ops import unary_union

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import logo_photo
import logo_print
import logo_text

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FONT_DIR = os.path.join(ROOT, 'assets', 'fonts', 'logo')
FACES = {'words': os.path.join(FONT_DIR, 'Aldrich-Regular.ttf'),                  # DESCEND / FROM
         'num': os.path.join(FONT_DIR, 'BarlowCondensed-Bold.ttf')}                # the 30
LICENCES = {'words': os.path.join(FONT_DIR, 'OFL-Aldrich.txt'), 'num': os.path.join(FONT_DIR, 'OFL.txt')}

# ---------------------------------------------------------------------------------------------------------------- palette
WARM = logo_text.WARM                # the cream of the letters on a dark ground
INK = logo_text.INK                  # the near-black of the game's night, for letters on a light ground
_MID = 0.45 * logo_print.THIN + 0.55 * logo_print.THICK
BLOOD_D = tuple(int(round(v)) for v in _MID)                       # the flat blood of the wordmark's 30 = the print's own mid tone
BLOOD_L = tuple(int(round(v * 0.9)) for v in _MID)                  # a step darker on paper
TILE = (24, 16, 28)               # the icon's ground

# ---------------------------------------------------------------------------------------------------------------- layout
NUM_H = 1400.0                    # the height of the 30
LINE_GAP = 0.12                   # between DESCEND and FROM, as a share of the 30's height (the two lines + the gap = the 30's height)
TRACK_NUM = 25                    # the 3 and the 0 sit close: one mark (Barlow font units)
WORDS_TRACK = 0.025               # open tracking of DESCEND / FROM, as a share of Aldrich's cap height
WORDS_TARGET = 5.5                # DESCEND's width / cap height once compacted (Aldrich natural 7.2; Barlow Condensed Bold sets 4.5): the footprint of the condensed face
WORDS_XMIN = 0.64                 # never squeeze a face further than this
WORDS_STEM = 0.9                  # how much of the stems the squeeze took is put back (a sideways dilation of the glyph, so the strokes stay strong)
WORDS_EMBOLDEN = 0.012            # Aldrich is light beside Barlow: a little weight, as a share of its cap height
WORD_GAP = 0.17                   # the plain wordmark: between the words and its 30, as a share of the 30's height
HAND_WIDTH = 1.552004                 # the print's box (thumb to little finger) is this wide, as a share of the 30's width: a hand a little wider than its number
HAND_DY = 0.00                    # the middle of the hand sits this far below the middle of the 30, as a share of the 30's height (0 = centred on it)
FROM_ALIGN = 'right'              # FROM sits under DESCEND flush 'left' or flush 'right' (owner round 48i: flush left left a hole a whole 30-height wide under the thumb)
TIP_REACH = 0.25                  # how far the thumb's ink reaches in under DESCEND (owner round 48h: "okay with some of the handprint being behind descend a little")
MARGIN = 0.10 * NUM_H             # clear space round every logo
SS = 3                            # vector raster supersample
SHEET_W = 1500                    # the contact sheet's logos are this wide

_FONTS = {}
_WP = None


def _font(face):
    if face not in _FONTS:
        _FONTS[face] = TTFont(FACES[face])
    return _FONTS[face]


# ---------------------------------------------------------------------------------------------------------------- glyphs
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


class _FlatPen(BasePen):
    """Flattens a TrueType / CFF outline (BasePen resolves the implied on-curve points, so a contour of off-curve points - Aldrich has them - is no problem)."""

    def __init__(self, gs):
        super().__init__(gs)
        self.contours = []
        self.cur = []

    def _moveTo(self, p):
        self.cur = [p]

    def _lineTo(self, p):
        self.cur.append(p)

    def _curveToOne(self, c1, c2, p):
        self.cur += _flatten_cubic(self.cur[-1], c1, c2, p)

    def _qCurveToOne(self, c, p):
        self.cur += _flatten_quad(self.cur[-1], c, p)

    def _closePath(self):
        if len(self.cur) >= 3:
            self.contours.append(self.cur)
        self.cur = []
    _endPath = _closePath


def _raw_glyph(ch, face):
    """-> (shapely geometry in font units, y UP, advance width) of a glyph exactly as the font draws it."""
    f = _font(face)
    name = f.getBestCmap()[ord(ch)]
    gs = f.getGlyphSet()
    adv = f['hmtx'][name][0]
    if ch == ' ':
        return Polygon(), adv
    pen = _FlatPen(gs)
    gs[name].draw(pen)
    geom = Polygon()
    for c in pen.contours:                               # even-odd: a counter is a contour inside a contour
        geom = geom.symmetric_difference(Polygon(c).buffer(0))
    return geom, adv


def cap_height(face='words'):
    return _font(face)['OS/2'].sCapHeight


def words_params():
    """How the words are set compact (measured from the face itself, once): -> {'track', 'xs', 'hdil', 'embolden'} in Aldrich font units."""
    global _WP
    if _WP is None:
        cap = cap_height('words')
        track = WORDS_TRACK * cap
        parts, x = [], 0.0
        for ch in 'DESCEND':
            g, adv = _raw_glyph(ch, 'words')
            parts.append(affinity.translate(g, x, 0))
            x += adv + track
        b = unary_union(parts).bounds
        natural = (b[2] - b[0]) / (b[3] - b[1])                                    # DESCEND's width / cap height as the font draws it
        xs = min(1.0, max(WORDS_XMIN, WORDS_TARGET / natural))
        i_b = _raw_glyph('I', 'words')[0].bounds
        stem = i_b[2] - i_b[0]
        _WP = {'track': track, 'xs': xs, 'hdil': WORDS_STEM * (1 - xs) * stem / 2.0, 'embolden': WORDS_EMBOLDEN * cap, 'natural': natural}
    return _WP


def glyph_geometry(ch, face='num'):
    """-> (shapely geometry in font units, y UP, advance width, (xmin, xmax)).  The 30 is the face as drawn; the words are Aldrich set compact."""
    g, adv = _raw_glyph(ch, face)
    if face == 'words' and not g.is_empty:
        p = words_params()
        g = affinity.scale(g, p['xs'], 1.0, origin=(0, 0))
        adv = adv * p['xs']
        if p['hdil'] > 0:                                              # put the stems back: dilate sideways only
            g = unary_union([affinity.translate(g, p['hdil'] * k / 3.0, 0) for k in range(-3, 4)]).buffer(0)
        g = g.buffer(p['embolden'], join_style=2, mitre_limit=3.0)
    x0, _, x1, _ = g.bounds if not g.is_empty else (0, 0, 0, 0)
    return g, adv, (x0, x1)


def set_line(text, tracking, face='num'):
    """-> the line's glyphs as one geometry (y DOWN, baseline at y = 0) and its ink extent (x0, x1)."""
    parts, x = [], 0.0
    ink0, ink1 = None, 0.0
    for ch in text:
        g, adv, (gx0, gx1) = glyph_geometry(ch, face)
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


def the_print():
    """The print (RGBA uint8 array: the owner's hand and its drips) and its info - tools/art/logo_photo.py."""
    return logo_photo.print_image()


def _left_edge():
    """The print's leftmost inked pixel on every 4th row, as (x, y) print pixels - the part that could meet the words."""
    global _EDGE
    if _EDGE is None:
        img, info = the_print()
        a = img[::4, :, 3] > 40
        rows = np.nonzero(a.any(axis=1))[0]
        _EDGE = (np.stack([a[rows].argmax(axis=1), rows * 4], axis=1).astype(float), info)
    return _EDGE


def _ink_left(scale, origin):
    """The x of the print's leftmost inked pixel when placed at `origin` with `scale` (units per print unit)."""
    px, info = _left_edge()
    return origin[0] + (px[:, 0].min() - info['ox']) * scale / info['scale']


# ---------------------------------------------------------------------------------------------------------------- layout
def build_layout(with_print=True):
    """-> dict of shapely geometry in logo units (y DOWN, the top of the 30 at y = 0):
    desc, frm (the two lines), num (the 30) and the hand's placement (print-unit -> logo-unit scale and origin).
    `with_print=False` is the plain wordmark: the 30 sits WORD_GAP from the words, with no room made for the print."""
    cap = cap_height('words')
    n_geom, (n0, n1) = set_line('30', TRACK_NUM, 'num')
    nb = n_geom.bounds
    kn = NUM_H / (nb[3] - nb[1])
    num = affinity.translate(_scaled(n_geom, kn), -nb[0] * kn, -nb[1] * kn)          # top-left of the ink at (0, 0)
    gap = LINE_GAP * NUM_H
    c = (NUM_H - gap) / 2.0                                                          # the cap height of the two lines
    kt = c / cap
    d_geom, (d0, d1) = set_line('DESCEND', words_params()['track'], 'words')
    f_geom, (f0, f1) = set_line('FROM', words_params()['track'], 'words')
    desc = affinity.translate(_scaled(d_geom, kt), -d0 * kt, c)                      # baseline at y = c, cap top at 0
    frm = affinity.translate(_scaled(f_geom, kt), -f0 * kt, NUM_H)                   # baseline at the 30's foot
    wd = (d1 - d0) * kt
    if FROM_ALIGN == 'right':
        frm = affinity.translate(frm, wd - (f1 - f0) * kt, 0)                        # FROM's last letter ends where DESCEND's does
    num = affinity.translate(num, wd + WORD_GAP * NUM_H, 0)                          # the plain wordmark's place; the print's version is set by the thumb below
    # the print: DIRECTLY behind the 30 (owner: "the handprint should be directly behind the number") - the hand's own middle (its centre of mass: the
    # palm) on the middle of the numerals, the fingers standing above them and the heel and the drips hanging below
    g = logo_photo.hand_shape()
    gx0, gy0, gx1, gy1 = g.bounds
    nw = num.bounds[2] - num.bounds[0]
    s = HAND_WIDTH * nw / (gx1 - gx0)                                                # logo units per print unit
    ccx, ccy = g.centroid.x, g.centroid.y
    ncx, ncy = (num.bounds[0] + num.bounds[2]) / 2.0, (num.bounds[1] + num.bounds[3]) / 2.0
    hx = ncx - ccx * s
    hy = ncy + HAND_DY * NUM_H - ccy * s
    if with_print:
        # the 30 + its print slide left together until the thumb's real INK (its wobbly edge, not the clean outline) reaches TIP_REACH in under DESCEND
        shift = (desc.bounds[2] - TIP_REACH * NUM_H) - _ink_left(s, (hx, hy))
        num = affinity.translate(num, shift, 0)
        hx += shift
    return {'desc': desc, 'frm': frm, 'num': num, 'hand_scale': s, 'hand_origin': (hx, hy)}


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


def _frame(bounds, width_px):
    """-> (W, H, k, ox, oy): the canvas for `bounds` plus the clear space, `width_px` wide."""
    x0, y0, x1, y1 = bounds
    ox, oy = x0 - MARGIN, y0 - MARGIN
    w, h = (x1 - x0) + 2 * MARGIN, (y1 - y0) + 2 * MARGIN
    k = width_px / w
    return int(width_px), int(round(h * k)), k, ox, oy


def render(parts, bounds, width_px, theme):
    """The plain, flat lettering (the WORDMARK): -> RGBA PIL image `width_px` wide.  parts: {'desc','frm','num'} geometry."""
    W, H, k, ox, oy = _frame(bounds, width_px)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    lines = unary_union([parts['desc'], parts['frm']])
    text, blood = (WARM, BLOOD_D) if theme == 'dark' else (INK, BLOOD_L)
    im = _paint(im, lines, text, k, ox, oy)
    return _paint(im, parts['num'], blood, k, ox, oy)


def _place_print(im, lay, printimg, ox, oy, k):
    img, info = printimg
    u = lay['hand_scale'] / info['scale']
    hx, hy = lay['hand_origin']
    px, py = (hx - info['ox'] * u - ox) * k, (hy - info['oy'] * u - oy) * k
    pw, ph = int(round(info['w'] * u * k)), int(round(info['h'] * u * k))
    pr = Image.fromarray(img, 'RGBA').resize((pw, ph), Image.LANCZOS)
    if px >= 0 and py >= 0:
        im.alpha_composite(pr, (int(round(px)), int(round(py))))
    else:
        _paste_clipped(im, pr, int(round(px)), int(round(py)))


def render_full(theme, width_px=2400):
    """The whole logo: the owner's print behind the 30, the worn lettering with its strikes of blood on it.  The look is computed once at logo_text.REF_W and carried to
    `width_px` (see logo_text), so any size is the same picture."""
    lay = build_layout()
    bounds = full_bounds(lay)
    W, H, k, ox, oy = _frame(bounds, width_px)
    Wr, Hr, kr, _x, _y = _frame(bounds, logo_text.REF_W)
    words, num = unary_union([lay['desc'], lay['frm']]), lay['num']
    mask = lambda g, w, h, kk: np.asarray(_mask(g, w, h, kk, ox, oy), np.float32) / 255.0
    ref = logo_text.reference(mask(words, Wr, Hr, kr), mask(num, Wr, Hr, kr))
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    f = (lay['hand_scale'] / logo_photo.UNIT) * k                          # output px per print px
    _place_print(im, lay, logo_photo.print_scaled(max(1.0, f)), ox, oy, k)
    if theme == 'light':
        # ink letters over dark blood would vanish where the thumb tucks under DESCEND: knock the print out round them
        halo = _mask(unary_union([lay['desc'], lay['frm']]).buffer(0.02 * NUM_H, join_style=1), W, H, k, ox, oy)
        im.putalpha(ImageChops.multiply(im.getchannel('A'), ImageChops.invert(halo)))
        key = lay['num'].buffer(0.016 * NUM_H, join_style=1).difference(lay['num'])        # the 30: cream inside an ink keyline, so it reads over blood and over paper
        im = _paint(im, key, INK, k, ox, oy)
    im.alpha_composite(logo_text.letters(ref, mask(words, W, H, k), mask(num, W, H, k), theme))
    return im


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
    g = logo_photo.hand_shape()
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
    chars, (a0, a1) = set_line('30', TRACK_NUM, 'num')
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


def _small(im, w):
    return im.resize((w, int(round(im.height * w / im.width))), Image.LANCZOS)


def all_outputs():
    """-> {relative path: bytes} of every generated file."""
    files = {}
    fulls = {}
    for theme in ('dark', 'light'):
        full = render_full(theme, 2400)
        fulls[theme] = full
        files['assets/logo/logo_full_%s.png' % theme] = _png(full)
        files['assets/logo/logo_full_%s_600.png' % theme] = _png(_small(full, 600))
        files['assets/logo/logo_wordmark_%s.png' % theme] = _png(render_wordmark(theme, 1600))
        files['assets/logo/logo_wordmark_%s_600.png' % theme] = _png(render_wordmark(theme, 600))
        files['assets/logo/logo_wordmark_%s.svg' % theme] = svg_wordmark(theme)
    files['assets/logo/mark_handprint.png'] = _png(render_mark(1000))
    files['assets/logo/icon.png'] = _png(render_icon(512))
    files['assets/logo/icon_1024.png'] = _png(render_icon(1024))
    files['assets/logo/icon.ico'] = ico_bytes([(n, _png(render_icon(n))) for n in (16, 32, 48, 64, 128, 256)])
    files['docs/logo/logo_sheet.png'] = _png(contact_sheet(fulls))
    return files


def _flat(im, bg):
    base = Image.new('RGBA', im.size, bg + (255,))
    return Image.alpha_composite(base, im).convert('RGB')


def contact_sheet(fulls=None):
    """Every variant on the ground it is for, the print alone, and the icon at 128 / 64 / 32 / 16 px."""
    fulls = fulls or {t: render_full(t, 2400) for t in ('dark', 'light')}
    dark, light = (18, 13, 22), (234, 228, 216)
    pad = 36
    a = _flat(_small(fulls['dark'], SHEET_W), dark)
    b = _flat(_small(fulls['light'], SHEET_W), light)
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


def write_press(width_px=6000):
    """The advertising renders: the logo at `width_px` wide, transparent and on the dark ground, in docs/press/ (not in the gate - they are large)."""
    out = os.path.join(ROOT, 'docs', 'press')
    os.makedirs(out, exist_ok=True)
    im = render_full('dark', width_px)
    names = []
    for name, data in (('DescendFrom30_logo_%dpx_transparent.png' % width_px, im), ('DescendFrom30_logo_%dpx_on_dark.png' % width_px, _flat(im, TILE).convert('RGBA'))):
        p = os.path.join(out, name)
        data.save(p)
        names.append(p)
    return names


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
    for face in FACES:                                              # the two typefaces and their licences (SIL OFL: they may be bundled, with the licence)
        if not os.path.exists(FACES[face]):
            bad.append('the %s typeface %s is missing' % (face, os.path.relpath(FACES[face], ROOT)))
        if not os.path.exists(LICENCES[face]):
            bad.append("the typeface's licence (%s) is missing" % os.path.relpath(LICENCES[face], ROOT))
    if not os.path.exists(logo_photo.SRC):
        bad.append('the hand cut-out %s is missing' % os.path.relpath(logo_photo.SRC, ROOT))
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
    # its fingers rising above them, its heel hanging under them, most of the numerals standing over the hand, and the thumb clear of the words
    lay = build_layout()
    g = affinity.translate(_scaled(logo_photo.hand_shape(), lay['hand_scale']), *lay['hand_origin'])
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
    if nb[0] - words.bounds[2] < 0.12 * NUM_H:
        bad.append('DESCEND runs into the 30 (%.2f of its height apart, want >= 0.12)' % ((nb[0] - words.bounds[2]) / NUM_H))
    frm_gap = (nb[0] - lay['frm'].bounds[2]) / NUM_H                                             # the second line must not leave a hole between the words and the 30 (owner round 48i)
    if frm_gap > 0.30:
        bad.append('FROM is %.2f of the 30\'s height from the 30 (the lines read as a block with the number close beside it: want <= 0.30)' % frm_gap)
    reach = (words.bounds[2] - _ink_left(lay['hand_scale'], lay['hand_origin'])) / NUM_H           # the print may tuck in under DESCEND (owner round 48h) - a little
    if not (0.02 <= reach <= 0.30):
        bad.append('the thumb reaches %.2f of the 30 in under DESCEND (a little behind it is wanted: 0.02 .. 0.30)' % reach)
    # the words keep Barlow's footprint (owner round 48m: "the font spreads things out a bit too much... less spacious"): the whole logo is not wider than 1.75 x its height
    fb = full_bounds(lay)
    if (fb[2] - fb[0]) / (fb[3] - fb[1]) > 1.75:
        bad.append('the logo is too wide (%.2f : 1; the compact words keep it near 1.65)' % ((fb[2] - fb[0]) / (fb[3] - fb[1])))
    # the hand: in proportion (it is a hand, not a glove or a paw), and it does not widen toward its foot (no fat base: the AI attempts' fault)
    x0, y0, x1, y1 = hb
    if not (0.60 <= (x1 - x0) / (y1 - y0) <= 0.95):
        bad.append('the print is out of proportion (width / height %.2f)' % ((x1 - x0) / (y1 - y0)))

    def width_at(share):
        y = y0 + share * (y1 - y0)
        sl = g.intersection(box(-1e6, y - 0.004 * (y1 - y0), 1e6, y + 0.004 * (y1 - y0)))
        return sl.bounds[2] - sl.bounds[0] if not sl.is_empty else 0.0
    if width_at(0.95) > width_at(0.60):
        bad.append('the print has a fat base (%.0f wide at its foot vs %.0f at the palm)' % (width_at(0.95), width_at(0.60)))
    for name, c in (('THIN', logo_print.THIN), ('THICK', logo_print.THICK), ('flat blood', BLOOD_D), ('strike blood', logo_text.BLOOD_A), ('strike pool', logo_text.BLOOD_B)):
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
    if '--press' in sys.argv:
        for p in write_press():
            print('wrote', os.path.relpath(p, ROOT))
        sys.exit(0)
    fs = write_all()
    print('wrote %d files' % len(fs))
