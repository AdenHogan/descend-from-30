"""THE LIVING ROOM, part three: the lamp, the small things and the rugs (owner round 47f). See furn_living.py."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import propkit as K
import instruments as IN
from furnlib import piece
from pixlib import hexc, shade, mix

BRASS, BRASS_LT = hexc('b89a48'), hexc('e4cc78')


# ================================================================================================================================ the standard lamp
@piece('lamp_floor', 18, 56, 'floor', keep='light', rooms={'living_room': 6, 'study': 3, 'dining_room': 1}, styles={'cosy': 6, 'mid': 6, 'parlour': 5, 'lodge': 3, 'squat': 1}, tags=('light', 'lamp'), limit=1, near=('seating_lounge',),
       variants={'brass': {'col': 'b89a48', 'shade': 'e8d8a8', 'for': ['cosy', 'parlour', 'lodge']}, 'black': {'col': '2a2a2e', 'shade': 'd8d0b8', 'for': ['mid', 'squat']},
                 'teak': {'col': '7a4a2a', 'shade': 'c8a060', 'for': ['mid', 'cosy']}},
       lights=({'dx': 9, 'dy': -46, 'kind': 'table'},), feet=(108, 118),
       note='a standard lamp on a round foot: a slender stem with a brass collar and a pleated drum shade, its inside glowing')
def lamp_floor(c, ox, oy, p):
    col, shd = hexc(p['col']), hexc(p['shade'])
    cx = ox + 9.0
    K.contact_shadow(c, cx, oy + 0.5, 8, 1.6, 100)
    L = K.Layer(c)
    lc = L.c
    K.cyl(lc, cx, oy - 3, oy - 1, 5.0, col, ry=1.6, gloss=True)                                  # the foot
    K.cyl(lc, cx, oy - 39, oy - 3, 0.9, col, ry=0.4, gloss=True)                                 # the stem
    for yy in (oy - 20, oy - 21):
        lc.hline(int(cx - 1), int(cx + 1), yy, BRASS_LT)                                         # a collar
    inner = mix(shd, hexc('fff0b8'), 0.65)
    K.frustum(lc, cx, oy - 52, oy - 40, 6.2, 8.0, shd, ry_t=2.2, ry_b=2.4, inner=inner, rim=shade(shd, 0.9), band=(shade(shd, 0.74), 1), n=5, lo=0.62, hi=1.22)
    for k in range(4):                                                                           # pleats
        lc.vline(int(cx - 5 + k * 3), oy - 50, oy - 42, shade(shd, 0.84))
    lc.put(int(cx), oy - 56, BRASS)
    lc.put(int(cx), oy - 55, hexc('f8e8a8')); lc.put(int(cx + 1), oy - 55, hexc('f8e8a8'))
    L.flush()


# ================================================================================================================================ the side table
@piece('side_table', 24, 26, 'wall', rooms={'living_room': 6, 'study': 2, 'dining_room': 2}, styles={'cosy': 5, 'mid': 4, 'parlour': 6, 'lodge': 3}, tags=('storage',), depth=4,
       variants={'round': {'kind': 'round'}, 'drawer': {'kind': 'drawer'}},
       slots=({'id': 'top', 'dx0': 4, 'dx1': 20, 'dy': -24, 'top': True, 'kinds': ('lamp', 'small')},),
       anchors=({'name': 'side_table', 'dx': 12, 'dy': -13},), feet=(105, 108),
       note='a small side table to stand a lamp on: a round pedestal one, or a square one with a drawer and a shelf')
def side_table(c, ox, oy, p):
    wood, wl, wd = hexc('7a5238'), hexc('a2784a'), hexc('4a2e22')
    cx = ox + 12.0
    c.shadow(cx, oy + 1, 14, 2, 100)
    if p['kind'] == 'round':
        K.cyl(c, cx, oy - 18, oy - 3, 1.4, wd, ry=0.5)
        for k in range(-7, 8):                                                                   # a tripod foot
            c.put(int(cx + k), oy - 1 + (1 if abs(k) < 3 else 0), wd if abs(k) < 5 else shade(wd, 1.3))
        c.rect(int(cx - 3), oy - 4, int(cx + 2), oy - 2, wd)
        for dx in range(-10, 11):                                                                # the round top, an ellipse seen from a little above
            u = dx / 10.0
            hh = int(round(2.4 * math.sqrt(max(0.0, 1.0 - u * u))))
            for y in range(oy - 24 - hh, oy - 24 + hh + 1):
                c.put(int(cx) + dx, y, shade(wl, 1.12 - 0.12 * (y - (oy - 24 - hh)) / max(1.0, 2.0 * hh) - 0.06 * max(0.0, u)))
            for t in range(1, 3):
                c.put(int(cx) + dx, oy - 24 + hh + t, shade(wood, 0.95 - 0.2 * t))
            c.put(int(cx) + dx, oy - 24 - hh - 1, shade(wd, 0.7))
    else:
        x0, x1 = ox + 3, ox + 20
        for lx in (x0, x1 - 1):
            c.rect(lx, oy - 18, lx + 1, oy - 1, wd)
            c.vline(lx, oy - 18, oy - 1, wood)
        c.rect(x0 - 1, oy - 25, x1 + 1, oy - 22, wl)
        c.hline(x0 - 1, x1 + 1, oy - 25, shade(wl, 1.25))
        c.hline(x0 - 1, x1 + 1, oy - 22, wd)
        c.rect(x0 + 1, oy - 21, x1 - 1, oy - 16, wood)                                           # a drawer
        c.hline(x0 + 1, x1 - 1, oy - 21, wl)
        c.hline(x0 + 7, x0 + 10, oy - 19, BRASS)
        c.rect(x0 + 1, oy - 9, x1 - 1, oy - 8, wood)                                             # the shelf
        c.hline(x0 + 1, x1 - 1, oy - 9, wl)


# ================================================================================================================================ things on a low table
@piece('magazines', 16, 8, 'top', rooms={'living_room': 6, 'study': 2, 'dining_room': 1}, styles=None, tags=('small', 'paper'), on=('low',), limit=1,
       variants={'a': {'cols': ('a8584a', '4a6a8a', 'd8c070')}, 'b': {'cols': ('3a6a5a', 'c8704a', 'e8e4d4')}},
       note='a drift of glossy magazines, fanned, the top one with a face on the cover')
def magazines(c, ox, oy, p):
    K.contact_shadow(c, ox + 8, oy + 0.5, 9, 1.4, 90)
    cols = [hexc(k) for k in p['cols']]
    for k, col in enumerate(cols):
        x0 = ox + 1 + k * 2
        y = oy - 2 - k * 2
        c.rect(x0, y, x0 + 11, y + 1, shade(col, 0.55))
        c.rect(x0, y - 1, x0 + 11, y, col)
        c.hline(x0, x0 + 11, y - 1, shade(col, 1.25))
        c.rect(x0 + 1, y - 1, x0 + 4, y, hexc('f0e8d0'))
    c.put(ox + 8, oy - 7, hexc('e8c8a8')); c.put(ox + 9, oy - 7, hexc('e8c8a8'))               # a face on the cover


@piece('ashtray_pack', 11, 7, 'top', rooms={'living_room': 4}, styles={'mid': 5, 'squat': 4, 'cosy': 2}, tags=('small',), on=('low',), limit=1,
       variants={'glass': {'col': '5a8a9a'}, 'tin': {'col': '9aa0a2'}},
       note='an ashtray with a pack of cigarettes and a lighter beside it')
def ashtray_pack(c, ox, oy, p):
    col = hexc(p['col'])
    K.contact_shadow(c, ox + 5, oy + 0.5, 6, 1.2, 90)
    L = K.Layer(c)
    lc = L.c
    K.frustum(lc, ox + 3.5, oy - 3, oy - 1, 3.4, 3.0, col, ry_t=1.2, ry_b=0.9, inner=hexc('3a3430'), rim=shade(col, 1.3))
    lc.put(ox + 3, oy - 3, hexc('d8d0c0')); lc.put(ox + 4, oy - 3, hexc('d8d0c0'))
    lc.rect(ox + 7, oy - 3, ox + 9, oy - 1, hexc('c8483a'))
    lc.hline(ox + 7, ox + 9, oy - 3, hexc('f0e8d0'))
    L.flush()


# ================================================================================================================================ the guitar
@piece('guitar_stand', 28, 64, 'floor', keep='tall', rooms={'living_room': 4, 'bedroom': 1}, styles={'squat': 7, 'mid': 1, 'teen': 1}, tags=('music',), limit=1,
       variants={'acoustic': {'body': 'c88a3a'}, 'dark': {'body': '7a3a1c'}}, feet=(108, 118),
       note='an acoustic guitar upright on an A-frame floor stand against the wall: a wide bound body with a pinched waist, a ringed sound hole, a pickguard and bridge, a fretted neck and a tapered head with its tuning pegs')
def guitar_stand(c, ox, oy, p):
    """(owner round 48i: "the guitar looks like some bizarre flute thing") the drawing lives in instruments.py: a body 26 rows long and 19 wide at the lower bout, then the neck."""
    body = hexc(p['body'])
    cx = ox + 14
    by = oy - 12                                   # the belly rests in the stand's cradle
    K.contact_shadow(c, cx, oy + 0.5, 11, 1.5, 100)
    L = K.Layer(c)
    lc = L.c
    steel, steel_lt, pad = hexc('34343a'), hexc('5c5c66'), hexc('1c1c20')
    for sx in (-1, 1):                              # the A-frame: two legs meeting under the belly, a crossbar, padded cradle arms hugging the lower bout
        lc.line(cx + sx * 1, by + 2, cx + sx * 9, oy, steel)
        lc.line(cx + sx * 1 + 1, by + 2, cx + sx * 9 + 1, oy, steel if sx > 0 else steel_lt)
    lc.hline(cx - 5, cx + 5, oy - 4, steel)
    lc.line(cx, by + 2, cx, by, steel)
    for sx in (-1, 1):
        for k in range(5):
            lc.put(cx + sx * 9, by - 1 - k, pad)
        lc.put(cx + sx * 8, by - 5, pad)
        lc.hline(cx + sx * 6, cx + sx * 8, by + 1, steel)
    IN.acoustic_guitar(lc, cx, by, body)
    L.flush()


# ================================================================================================================================ rugs
def _large_rug(c, ox, oy, p, W):
    col, bor, pat = hexc(p['col']), hexc(p['border']), hexc(p['pat'])
    shag = p.get('shag', False)
    plaid = p.get('plaid', False)
    rng = random.Random(len(p['col']) * 31 + ord(p['col'][0]) + W)
    top, bot = oy - 13, oy - 1
    for y in range(top, bot + 1):
        f = (y - top) / float(bot - top)
        inset = int(round(3.5 * (1.0 - f)))
        xa, xb = ox + 3 + inset, ox + W - 4 - inset
        for x in range(xa, xb + 1):
            edge_x = min(x - xa, xb - x)
            edge_y = min(y - top, bot - y)
            e = min(edge_x, edge_y * 3)
            if plaid:                                                                           # a tartan: wide bands of the second colour crossing the field, thin gold lines, a woollen grain
                u, v = (x - ox) % 14, (y - top) % 6
                cc = col
                if u in (6, 7, 8) or v in (2, 3):
                    cc = mix(col, bor, 0.55)
                if u == 7 or v == 2:
                    cc = shade(cc, 0.8)
                if u == 2 or v == 5:
                    cc = pat
                cc = shade(cc, 0.94 + 0.12 * ((x * 5 + y * 3) % 3) / 2.0)
                if e <= 0:
                    cc = shade(bor, 0.55)
                elif e <= 1:
                    cc = bor
            elif shag:
                cc = shade(col, 0.86 + 0.28 * ((x * 7 + y * 13) % 5) / 4.0)
                if e <= 0:
                    cc = shade(col, 0.6)
            elif e <= 0:
                cc = shade(bor, 0.55)
            elif e <= 2:
                cc = bor
            elif e == 3:
                cc = pat
            elif e <= 4:
                cc = bor
            else:
                u, v = (x - ox) % 8, (y - top) % 4
                cc = col
                if abs(u - 4) + abs(v - 2) * 2.0 <= 2.6:
                    cc = shade(col, 1.22)
                if abs(u - 4) + abs(v - 2) * 2.0 <= 1.0:
                    cc = pat
            if f > 0.5 and rng.random() < 0.05 and e > 4:
                cc = shade(cc, 0.82)
            c.put(x, y, cc)
    if not shag and not plaid:
        mx, my = ox + W // 2, (top + bot) // 2
        for k, r in enumerate((10, 7, 4, 2)):                                                    # the medallion
            for dx in range(-r - 1, r + 2):
                for dy in range(-(r // 3) - 1, r // 3 + 2):
                    if abs(dx) / float(r + 0.5) + abs(dy) / (r / 3.0 + 0.5) <= 1.0:
                        c.put(mx + dx, my + dy, (bor, pat, bor, pat)[k])
        for y in range(top + 1, bot):                                                            # fringe at both ends
            if (y - top) % 2 == 0:
                for fx in range(2):
                    c.put(ox + 1 - fx + int(round(3.5 * (1.0 - (y - top) / float(bot - top)))), y, shade(pat, 0.9))
                    c.put(ox + W - 2 + fx - int(round(3.5 * (1.0 - (y - top) / float(bot - top)))), y, shade(pat, 0.9))


@piece('rug_large', 120, 14, 'rug', rooms={'living_room': 8, 'dining_room': 4, 'study': 2}, styles={'cosy': 8, 'mid': 6, 'parlour': 8, 'lodge': 7, 'family': 3, 'formal': 4, 'library': 3, 'office': 1}, tags=('rug',), feet=(129, 134), under=('sofa', 'seating_lounge', 'table'),
       variants={'maroon': {'col': '8a3a38', 'border': '5a2424', 'pat': 'd8b890', 'for': ['cosy', 'family', 'library']}, 'gold': {'col': 'b8902a', 'border': '8a6a1e', 'pat': 'e4cc78', 'shag': True, 'for': ['mid']},
                 'tartan': {'col': '2e5a3a', 'border': '7a2a2a', 'pat': 'e4cc78', 'plaid': True, 'for': ['lodge']},
                 'green': {'col': '4e6a4a', 'border': '34482e', 'pat': 'c8c498', 'for': ['parlour', 'formal']}, 'blue': {'col': '4e6a8a', 'border': '34485e', 'pat': 'd0c8a8', 'for': ['formal', 'library', 'office']}},
       note='a big woven rug under the sofa group: border bands, lozenges, a medallion, fringe; or a shaggy gold sixties one')
def rug_large(c, ox, oy, p):
    _large_rug(c, ox, oy, p, 120)


# ================================================================================================================================ the lodge's things
@piece('log_basket', 22, 20, 'floor', keep='storage', rooms={'living_room': 5}, styles={'lodge': 8, 'cosy': 1, 'parlour': 1}, tags=('storage', 'wood'), limit=1,
       variants={'wicker': {}}, anchors=({'name': 'log_basket', 'dx': 11, 'dy': -9},), near=('hearth',), feet=(110, 120),
       note='a wicker basket of split logs by the hearth: a woven rim, the cut ends of logs sticking out, a bundle of kindling')
def log_basket(c, ox, oy, p):
    cx = ox + 11
    K.contact_shadow(c, cx, oy + 0.5, 11, 1.8, 100)
    L = K.Layer(c)
    lc = L.c
    rng = random.Random(8)
    for (lx, ly, r) in ((-5, -15, 3.0), (0, -16, 3.2), (5, -15, 3.0), (-2, -19, 2.8), (3, -19, 2.6)):   # logs: their cut ends toward us
        K.ell(lc, cx + lx, oy + ly + 5, r, r * 0.9, hexc('9a7448'))
        K.ell(lc, cx + lx, oy + ly + 5, r - 1.2, (r - 1.2) * 0.9, hexc('c8a46a'))
        lc.put(int(cx + lx), oy + ly + 5, hexc('7a5a38'))
    K.frustum(lc, cx, oy - 13, oy - 1, 10.0, 8.0, hexc('b8904e'), ry_t=2.2, ry_b=1.6, n=5, lo=0.55, hi=1.25, band=(hexc('8a6a34'), 1))
    for k in range(5):
        yy = oy - 11 + k * 2
        lc.hline(int(cx - 9 + k % 2), int(cx + 8 - k % 2), yy, shade(hexc('b8904e'), 0.7))
    for k in range(9):
        lc.put(int(cx - 8 + k * 2), oy - 12 + (k % 2) * 2, shade(hexc('b8904e'), 1.3))
    L.flush()


@piece('stag_head', 44, 38, 'decor', rooms={'living_room': 4}, styles={'lodge': 9}, tags=('picture', 'trophy'), wall_y=(14, 26), limit=1, variants={'twelve': {}},
       note='a stag\'s head on a shield plaque: the brow, the glass eyes, a spread of antlers with tines')
def stag_head(c, ox, oy, p):
    L = K.Layer(c)
    lc = L.c
    cx = ox + 22
    bone, bd = hexc('d9cfb8'), hexc('a89c80')
    for d in (-1, 1):                                                                            # the antlers: a main beam and tines
        beam = [(cx + 3 * d, oy + 14), (cx + 8 * d, oy + 9), (cx + 13 * d, oy + 5), (cx + 17 * d, oy + 1), (cx + 20 * d, oy - 1)]
        for a, b in zip(beam, beam[1:]):
            lc.line(a[0], a[1], b[0], b[1], bone)
            lc.line(a[0], a[1] + 1, b[0], b[1] + 1, bd)
        for (tx, ty, ex, ey) in ((cx + 8 * d, oy + 9, cx + 7 * d, oy + 1), (cx + 13 * d, oy + 5, cx + 14 * d, oy - 2), (cx + 17 * d, oy + 1, cx + 22 * d, oy + 4), (cx + 6 * d, oy + 12, cx + 4 * d, oy + 7)):
            lc.line(tx, ty, ex, ey, bone)
    lc.poly([(cx - 8, oy + 13), (cx + 8, oy + 13), (cx + 7, oy + 28), (cx, oy + 34), (cx - 7, oy + 28)], hexc('6b4a31'))   # the shield plaque
    lc.poly([(cx - 6, oy + 14), (cx + 6, oy + 14), (cx + 5, oy + 27), (cx, oy + 32), (cx - 5, oy + 27)], hexc('8a6443'))
    K.sphere(lc, cx, oy + 21, 4.6, 6.2, hexc('7a5a3a'))                                          # the head
    for d in (-1, 1):
        lc.rect(cx + d * 4 - (1 if d < 0 else 0), oy + 15, cx + d * 4 + (0 if d < 0 else 1), oy + 17, hexc('5a3e28'))   # the ears
        lc.put(cx + d * 2, oy + 19, hexc('1a1410'))                                              # the glass eyes
        lc.put(cx + d * 2, oy + 18, hexc('f0d8a0'))
    lc.rect(cx - 1, oy + 25, cx + 1, oy + 27, hexc('2a1a14'))                                    # the nose
    L.flush()


@piece('cameos', 38, 22, 'decor', rooms={'living_room': 4, 'dining_room': 3}, styles={'parlour': 9, 'formal': 4}, tags=('picture',), wall_y=(24, 36), limit=1, variants={'pair': {}},
       note='a pair of silhouette cameos in oval gilt frames, the couple turned to face each other')
def cameos(c, ox, oy, p):
    import wall_art3d
    wall_art3d.cameos(c, ox, oy, p)


@piece('print_hunting', 26, 24, 'decor', rooms={'living_room': 4}, styles={'lodge': 8}, tags=('picture',), wall_y=(24, 40), limit=1, variants={'gilt': {}},
       note='a framed hunting print: a dark green glen, a stag on the ridge, hounds below')
def print_hunting(c, ox, oy, p):
    import wallart as W
    ix0, iy0, ix1, iy1 = W.frame(c, ox, oy, ox + 25, oy + 23, 'gilt', mat=hexc('d8cca8'), thick=2, hang='wire', matw=2)
    c.rect(ix0, iy0, ix1, iy1, hexc('6a7a5a'))
    c.rect(ix0, iy0, ix1, iy0 + 6, hexc('b8c0a0'))                                               # a pale sky
    c.poly([(ix0, iy0 + 9), (ix0 + 5, iy0 + 6), (ix0 + 10, iy0 + 8), (ix1, iy0 + 5), (ix1, iy1), (ix0, iy1)], hexc('3a4a30'))
    c.poly([(ix0 + 4, iy0 + 6), (ix0 + 8, iy0 + 5), (ix0 + 7, iy0 + 8)], hexc('1a1a14'))         # the stag on the ridge
    c.put(ix0 + 8, iy0 + 4, hexc('1a1a14')); c.put(ix0 + 7, iy0 + 3, hexc('1a1a14'))
    for hx in (ix0 + 8, ix0 + 12):                                                               # hounds
        c.rect(hx, iy1 - 4, hx + 2, iy1 - 3, hexc('d8d0c0'))
    W.glint(c, (ix0, iy0, ix1, iy1))
