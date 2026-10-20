"""BEDDING — pillows, duvets, throws, quilts, mattresses and sleeping bags for the furniture library's beds (owner round 47b: "some beds have poor looking blankets on them, especially the bottom two").

furn.persp_bed builds the frame, mattress and the room's perspective; this paints what lies ON the mattress. The covers are not drawn as flat polygons any more: every pixel of the
mattress top is mapped back to its place on the bed (x along it, d out from the wall — the inverse of pixlib.pp), so a stripe, a check, a quilt's diamond stitching, a patchwork square or
a scatter of stars is drawn IN PERSPECTIVE and stays regular on the bed whatever the lean. On top of that: a tucked / rolled edge, a turned-down sheet, creases and a lump where the
feet are, a front drape with soft folds, a hem and piping, a knitted throw with fringe across the foot, a plump pillow with a dent and a pillowcase border — and for the squat a ticking
mattress with tufts and a real sleeping bag (baffles, zip, hood).

    bedding.dress(spec)            -> a function (c, geo) for furn.persp_bed(..., bedding=fn)
    bedding.mattress_bed(spec)     -> the same for a mattress straight on the floor (low=True)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import pp, hexc, shade, mix
import propkit as K

VPX = 160.0
SEAM = 100.0


def tn7(col):
    """Seven tones of a colour, darkest first; index 3 is the colour itself."""
    return [shade(col, 0.58 + 0.84 * i / 6.0) for i in range(7)]


def _ix(tn, i):
    return tn[max(0, min(len(tn) - 1, int(i)))]


class Top:
    """A horizontal plane at wall-height `y` seen in the room's perspective: (x, d) on the bed <-> screen."""

    def __init__(self, y, d1):
        self.y, self.d1 = y, d1

    def pt(self, x, d):
        s = (SEAM + d) / SEAM
        return (VPX + (x - VPX) * s, self.y * s)

    def xd(self, px, py):
        s = py / self.y
        return (VPX + (px - VPX) / s, SEAM * (s - 1.0))

    def spt(self, x, d):
        a = self.pt(x, d)
        return (int(round(a[0])), int(round(a[1])))


def fill_top(c, T, xa, xb, d0, d1, fn, base=None):
    """Paint every pixel whose centre lies on the plane rectangle x in [xa, xb] x d in [d0, d1] with fn(x, d, px, py) (None = leave). `base` first lays the polygon in one colour so the
    ragged edge of the pixel test is covered."""
    pts = [T.spt(xa, d0), T.spt(xb, d0), T.spt(xb, d1), T.spt(xa, d1)]
    if base is not None:
        c.poly(pts, base)
    ys = [p[1] for p in pts]
    xs = [p[0] for p in pts]
    for py in range(min(ys) - 1, max(ys) + 2):
        for px in range(min(xs) - 1, max(xs) + 2):
            x, d = T.xd(px + 0.5, py + 0.5)
            if xa <= x <= xb and d0 <= d <= d1:
                col = fn(x, d, px, py)
                if col is not None:
                    c.put(px, py, col)


def _hash(a, b, seed=0):
    h = (a * 73856093) ^ (b * 19349663) ^ (seed * 83492791)
    return (h & 0xffff) / 65535.0


# -------------------------------------------------------------------------------------------------------------------------------- patterns
def pattern_index(spec, x, d, xa):
    """-> (which tone list: 0 main / 1 accent, tone offset) for a point of the cover."""
    pat = spec.get('pattern', 'plain')
    if pat == 'stripe':
        return (1 if int(d / 4.4) % 2 else 0, 0)
    if pat == 'wide':
        return (1 if int((x - xa) / 9.0) % 2 else 0, 0)
    if pat == 'check':
        return (1 if (int(d / 4.4) + int((x - xa) / 5.2)) % 2 else 0, 0)
    if pat == 'plaid':
        a = int((x - xa) / 4.0) % 6 == 0
        b = int(d / 3.4) % 5 == 0
        return (1 if (a or b) else 0, -1 if (a and b) else 0)
    if pat == 'quilt':
        u, v = (x - xa), d * 1.05
        e1 = abs(((u + v) % 10.0) - 5.0)
        e2 = abs(((u - v) % 10.0) - 5.0)
        edge = min(e1, e2)
        if edge < 0.55:
            return (0, -2)
        if min(e1, e2) > 3.6:
            return (0, 1)                                          # the middle of each diamond is puffed up
        return (0, 0)
    if pat == 'patch':
        cx, cy = int((x - xa) / 6.6), int(d / 4.6)
        fx, fy = (x - xa) / 6.6 - cx, d / 4.6 - cy
        n = max(1, len(spec.get('patch', ())))
        k = 2 + int(_hash(cx, cy, spec.get('seed', 1)) * n) % n
        if fx < 0.08 or fy < 0.1:
            return (k, -2)                                          # the seam between two patches
        return (k, -1 if _hash(cx + 7, cy + 3, 5) < 0.3 else 0)
    if pat == 'stars':
        cx, cy = int((x - xa) / 7.0), int(d / 5.0)
        if _hash(cx, cy, spec.get('seed', 1)) < 0.42:
            fx, fy = ((x - xa) / 7.0 - cx), (d / 5.0 - cy)
            if abs(fx - 0.5) < 0.2 and abs(fy - 0.5) < 0.3:
                return (1, 1)
    if pat == 'dots':
        cx, cy = int((x - xa) / 6.0), int(d / 4.0)
        fx, fy = ((x - xa) / 6.0 - cx), (d / 4.0 - cy)
        if abs(fx - 0.5) < 0.2 and abs(fy - 0.5) < 0.3 and (cx + cy) % 2 == 0:
            return (1, 0)
    return (0, 0)


# -------------------------------------------------------------------------------------------------------------------------------- the covers
def _creases(c, T, xa, xb, d1, spec, rng):
    """A few soft wrinkles: a long curved dark line with a light ridge beside it, running across the bed and a little slanted — drawn between projected points so they converge like
    everything else."""
    n = spec.get('creases', 4)
    tn = spec['_tn']
    span = xb - xa - 22
    for k in range(n):
        x0 = xa + 8 + span * (k + rng.random() * 0.5) / max(1, n)
        ln = rng.uniform(14, 24)
        d0 = rng.uniform(1.5, d1 * 0.4)
        pts = []
        for j in range(4):
            t = j / 3.0
            pts.append(T.spt(x0 + ln * t, d0 + (d1 * 0.55) * t + 2.2 * math.sin(t * 3.1 + k)))
        for j in range(3):
            c.line(pts[j][0], pts[j][1], pts[j + 1][0], pts[j + 1][1], _ix(tn, 2))
            c.line(pts[j][0], pts[j][1] - 1, pts[j + 1][0], pts[j + 1][1] - 1, _ix(tn, 4))


def _lump(x, d, spec, xb, d1):
    """Raise the cover over the sleeper's feet: a soft lump near the far end (2 = its crest, 1 = its flank)."""
    cx = spec['_lump_x']
    dx = (x - cx) / 15.0
    dy = (d - d1 * 0.5) / (d1 * 0.55)
    r = dx * dx + dy * dy
    return 2 if r < 0.28 else (1 if r < 1.0 else 0)


def _cover(c, T, geo, spec, xa, xb, rng):
    d1 = geo['d1']
    main, acc = tn7(spec['col']), tn7(spec.get('accent', shade(spec['col'], 1.25)))
    tns = [main, acc] + [tn7(pc) for pc in spec.get('patch', ())]
    spec['_tn'] = main
    spec['_lump_x'] = xb - (xb - xa) * 0.38

    def fn(x, d, px, py):
        which, off = pattern_index(spec, x, d, xa)
        tn = tns[which]
        i = 3 + off
        if d < 1.6:
            i -= 2                                                    # tucked against the wall: in shade
        elif d < 3.2:
            i -= 1
        if d > d1 - 0.5:
            i += 2                                                    # the rolled front edge catches the light
        elif d > d1 - 1.7:
            i += 1
        if x > xb - 1.6:
            i -= 1
        lm = _lump(x, d, spec, xb, d1)
        if lm and i >= 3:
            i += 2 if lm == 2 else 1
        return _ix(tn, i)
    fill_top(c, T, xa, xb, 0.0, d1 + 0.6, fn, base=main[3])
    _creases(c, T, xa, xb, d1, spec, rng)
    return main, acc


def _drape(c, T, xa, xb, d_edge, hem, spec, ph, kind='duvet'):
    """The part of the cover that hangs over the front of the bed: soft vertical folds in clear tone steps with a darker crease between, a rolled top edge, a gently wavy hem and (if the
    cover has piping) a pale line along it."""
    main, acc = tn7(spec['col']), tn7(spec.get('accent', shade(spec['col'], 1.25)))
    if kind == 'throw':
        main, acc = tn7(spec['throw'][0]), tn7(spec['throw'][1])
    tns = [main, acc] + [tn7(pc) for pc in spec.get('patch', ())]
    s1 = (SEAM + d_edge) / SEAM
    ya = int(round(T.pt(xa, d_edge)[1]))
    fa, fb = int(round(T.pt(xa, d_edge)[0])), int(round(T.pt(xb, d_edge)[0]))
    rng = random.Random(int(ph * 100) + fa)
    # fold boundaries: 3-6 px apart; each fold has its own tone step, the boundary column is a crease
    cuts, x = [], fa
    while x < fb:
        x += rng.randint(3, 6)
        cuts.append(x)
    steps = [0, 1, -1, 0, 1, 0, -1, 1]
    for x in range(fa, fb + 1):
        k = x - fa
        xw = VPX + (x - VPX) / s1
        which, off = pattern_index(spec if kind == 'duvet' else dict(spec, pattern='wide'), xw, 0.5, xa)
        tn = tns[which] if kind == 'duvet' else (acc if which else main)
        fi = sum(1 for cc in cuts if cc <= x)
        crease = x in cuts
        edge_in = min(x - fa, fb - x)
        wave = int(round(0.9 * math.sin(k * 0.17 + ph) + 0.5 * math.sin(k * 0.43 + ph * 2)))
        h = hem + wave - (1 if edge_in == 0 else 0)
        for y in range(ya + 1, ya + h + 1):
            f = (y - ya) / float(max(1, h))
            i = 3 + off + steps[fi % len(steps)] - (1 if f > 0.5 else 0) - (1 if f > 0.82 else 0) - (1 if crease else 0)
            if y == ya + 1:
                i += 2                                                # the roll where it goes over the edge
            elif y == ya + 2:
                i += 1
            c.put(x, y, _ix(tn, i))
            if y == ya + 1 and spec.get('piping') and kind == 'duvet':
                c.put(x, y, spec['piping'])                           # piping along the rolled edge
        c.put(x, ya + h, _ix(tn, 0))                                  # the hem, dark
        if kind == 'throw':
            c.put(x, ya + h + 1, _ix(acc, 3) if k % 2 == 0 else _ix(acc, 1))     # fringe
            if k % 3 == 0:
                c.put(x, ya + h + 2, _ix(acc, 2))
    return ya + hem


def _throw(c, T, geo, spec, xa, xb, rng):
    """A knitted throw folded across the foot of the bed: a band over the cover and down over the front, striped ends, a fringe."""
    d1 = geo['d1']
    t1, t2 = spec['throw']
    tw = 11.0
    tx0 = xb - (xb - xa) * 0.18 - tw
    T2 = Top(T.y - 0.7, d1)
    m, a = tn7(t1), tn7(t2)

    def fn(x, d, px, py):
        u = x - tx0
        stripe = u < 1.6 or u > tw - 1.6 or (4.6 < u < 5.9)
        tn = a if stripe else m
        i = 3 + (1 if (px + py) % 2 == 0 else 0) - (1 if d < 1.6 else 0) + (2 if d > d1 - 0.4 else 0)
        if u < 0.9:
            i += 1
        if u > tw - 0.9:
            i -= 1
        return _ix(tn, i)
    fill_top(c, T2, tx0, tx0 + tw, 0.9, d1 + 0.7, fn, base=m[3])
    sp = dict(spec)
    sp['pattern'] = 'wide'
    _drape(c, T2, tx0, tx0 + tw, d1 + 0.7, 8, sp, 1.3, kind='throw')


def _pillow(c, T, geo, spec, px0, px1):
    d1 = geo['d1']
    base = spec.get('pillow', hexc('dcd5c3'))
    band = spec.get('pillow_band', shade(spec['col'], 1.0))
    tn = [shade(base, 0.5 + 0.88 * i / 6.0) for i in range(7)]
    bn = tn7(band)
    Tp = Top(T.y - 1.5, d1)
    d0, dd1 = 1.6, d1 - 1.0
    cxp, cdp = (px0 + px1) / 2.0, (d0 + dd1) / 2.0
    hw, hd = (px1 - px0) / 2.0, (dd1 - d0) / 2.0
    out = shade(base, 0.38)

    def fn(x, d, px, py):
        u, v = (x - cxp) / hw, (d - cdp) / hd
        if abs(u) > 0.7 and abs(v) > 0.7 and (abs(u) - 0.7) + (abs(v) - 0.7) > 0.22:
            return None                                              # rounded corners
        e = max(abs(u), abs(v))
        i = 2 + (3 if e < 0.4 else (2 if e < 0.7 else (1 if e < 0.88 else 0)))
        if abs(v) < 0.14 and abs(u) < 0.78:
            i -= 2                                                   # the dent where a head has been
        elif abs(v) < 0.28 and abs(u) < 0.7 and v > 0:
            i += 1
        col = tn
        if 0.74 < abs(u) < 0.86:
            col = bn                                                 # the pillowcase border
            i = 3
        return _ix(col, i)
    ya = Tp.spt(px0, dd1)[1]
    xa_, xb_ = Tp.spt(px0, dd1)[0], Tp.spt(px1, dd1)[0]
    fill_top(c, Tp, px0, px1, d0, dd1, fn, base=tn[3])
    for x in range(xa_ + 1, xb_):                                    # the thickness: the pillow's front, shaded, bulging a little
        bulge = 1 if xa_ + 3 < x < xb_ - 3 else 0
        for y in range(ya + 1, ya + 3 + bulge):
            c.put(x, y, _ix(tn, 2 if y == ya + 1 else 1))
        c.put(x, ya + 3 + bulge, out)                                # its lower edge against the cover
    for y in range(ya - 1, ya + 3):
        c.put(xa_, y, out)
        c.put(xb_, y, out)
    a = Tp.spt(px0 + 1.5, d0 + 1.2)                                  # two little wrinkles at the corners
    c.line(a[0], a[1], a[0] + 1, a[1] + 1, _ix(tn, 1))
    b = Tp.spt(px1 - 1.5, d0 + 1.2)
    c.line(b[0], b[1], b[0] - 1, b[1] + 1, _ix(tn, 1))
    # the far edge against the headboard / mattress: a soft shadow line
    p0, p1 = Tp.spt(px0 + 1.5, d0 - 0.3), Tp.spt(px1 - 1.5, d0 - 0.3)
    c.line(p0[0], p0[1], p1[0], p1[1], out)


def _stain(c, T, cx, cd, rx, rd, col, strength=0.62):
    """A dried stain on the cover: an irregular ellipse on the bed plane, the cloth's own colour darkened toward `col`."""
    def fn(x, d, px, py):
        u, v = (x - cx) / rx, (d - cd) / rd
        r2 = u * u + v * v + 0.25 * math.sin(u * 5 + v * 3)
        if r2 > 1.0:
            return None
        e = c.px[px, py]
        if e[3] == 0:
            return None
        return mix(e, col, strength * (1.0 if r2 < 0.55 else 0.55))
    fill_top(c, T, cx - rx, cx + rx, cd - rd, cd + rd, fn)


def dress(spec):
    """The bedding of a (wooden / pine / kid's) bed: pillow, turned-down sheet, cover with a pattern, creases, drape, optional throw. spec keys: col, accent, pattern, sheet, pillow,
    pillow_band, piping, throw ((main, accent) or None), seed, hem, drape_pattern, creases."""
    def fn(c, geo):
        rng = random.Random(spec.get('seed', 1))
        head = geo['head']
        d1, ym = geo['d1'], geo['ym']
        xm0, xm1 = geo['xm0'], geo['xm1']
        T = Top(ym - 1.3, d1)
        pw = 14.0
        px0, px1 = (xm0 + 1, xm0 + 1 + pw) if head == 'left' else (xm1 - 1 - pw, xm1 - 1)
        da, db = (px1 + 1, xm1) if head == 'left' else (xm0, px0 - 1)
        main, acc = _cover(c, T, geo, spec, da, db, rng)
        # the turned-down sheet at the head of the cover
        fw = spec.get('fold_w', 5.0)
        fa, fb = (da, da + fw) if head == 'left' else (db - fw, db)
        sheet = tn7(spec.get('sheet', hexc('d6d0c0')))

        def sfn(x, d, px, py):
            u = (x - fa) / fw if head == 'left' else (fb - x) / fw
            i = 4 - (1 if d < 1.6 else 0) + (1 if d > d1 - 0.8 else 0)
            if u > 0.78:
                i -= 2                                                # the fold's edge turns over: in shade
            elif u > 0.55:
                i -= 1
            if u < 0.12:
                i += 1
            return _ix(sheet, i)
        fill_top(c, T, fa, fb, 0.0, d1 + 0.6, sfn, base=sheet[4])
        ex = fb if head == 'left' else fa
        e1, e2 = T.spt(ex, 0.4), T.spt(ex, d1 + 0.6)
        c.line(e1[0], e1[1], e2[0], e2[1], _ix(sheet, 1))
        sx = 1 if head == 'left' else -1
        c.line(e1[0] + sx, e1[1], e2[0] + sx, e2[1], _ix(main, 2))
        sheet_spec = dict(spec, col=spec.get('sheet', hexc('d6d0c0')), pattern='plain', piping=None)
        ca, cb = (fa + fw, db) if head == 'left' else (da, fa)
        _drape(c, T, ca, cb, d1 + 0.6, spec.get('hem', 8), spec, 0.4)                    # the cover's drape over the front edge…
        _drape(c, T, fa, fb, d1 + 0.6, spec.get('hem', 8) - 1, sheet_spec, 2.1)           # …and the turned-down sheet's
        if spec.get('throw') is not None:
            _throw(c, T, geo, spec, da + fw, db, rng)
        if spec.get('stain'):
            _stain(c, T, (fa + fw + 6) if head == 'left' else (fb - fw - 6), d1 * 0.45, 5.5, 3.2, hexc('4a1d1b'))
        _pillow(c, T, geo, spec, px0, px1)
        if spec.get('stain'):
            _stain(c, T, (px0 + px1) / 2.0, d1 * 0.5, 4.0, 2.6, hexc('4a1d1b'), strength=0.5)
        geo['duvet'] = (da, db)
    return fn


# ================================================================================================================================ a mattress on the floor + a sleeping bag
def _ticking_front(c, geo, T_top, spec, xm0, xm1, tick, tick2):
    ym, ymb, d1 = geo['ym'], geo['ymb'], geo['d1']
    Tb = Top(ymb, d1)
    x0, y0 = T_top.spt(xm0, d1)
    x1, _ = T_top.spt(xm1, d1)
    y1 = Tb.spt(xm0, d1)[1]
    for x in range(x0, x1 + 1):
        tn = tick2 if ((x - x0) // 3) % 2 else tick
        for y in range(y0 + 1, y1 + 1):
            f = (y - y0) / float(max(1, y1 - y0))
            c.put(x, y, _ix(tn, 2 - (1 if f > 0.7 else 0)))
    c.hline(x0, x1, y0 + 1, _ix(tick, 5))                       # the piped top edge
    c.hline(x0, x1, y1, _ix(tick, 0))                           # the bottom edge on the boards
    c.vline(x0, y0, y1, _ix(tick, 4))
    c.vline(x1, y0, y1, _ix(tick, 1))
    for (sx, sd, sw, sh_) in spec.get('front_stains', ()):
        for x in range(x0 + sx, x0 + sx + sw):
            for y in range(y0 + 2, y0 + 2 + sh_):
                e = c.px[x, y]
                c.put(x, y, mix(e, hexc('4a3a22'), 0.35))


def mattress_bed(spec):
    """A bare mattress on the floor (cream-and-grey ticking with piping, tufted buttons, stains), a grubby pillow, and — if the spec has a `bag` colour — a sleeping bag half unzipped across it."""
    def fn(c, geo):
        rng = random.Random(spec.get('seed', 3))
        d1, ym = geo['d1'], geo['ym']
        xm0, xm1 = geo['xm0'], geo['xm1']
        head = geo['head']
        T = Top(ym, d1)
        tick, tick2 = tn7(spec.get('ticking', hexc('cfc7b2'))), tn7(spec.get('ticking2', hexc('9aa4a8')))
        stains = spec.get('stains', ())

        def top_fn(x, d, px, py):
            tn = tick2 if int(d / 2.6) % 2 else tick
            i = 3
            if d < 1.0:
                i -= 1
            if d > d1 - 0.9:
                i += 2
            if x < xm0 + 0.9 or x > xm1 - 0.9:
                i += 1
            for (sx, sd, rx, rd) in stains:
                u, v = (x - xm0 - sx) / rx, (d - sd) / rd
                if u * u + v * v < 1.0:
                    return mix(_ix(tn, i), hexc('6a5a38'), 0.4 if u * u + v * v < 0.5 else 0.22)
            return _ix(tn, i)
        fill_top(c, T, xm0, xm1, 0.0, d1, top_fn, base=tick[3])
        # the buttons: tufts pulled into the ticking, each a dark dimple with a light fleck beside it
        k = 0
        for bx in range(int(xm0) + 9, int(xm1) - 4, 13):
            for dd in ((d1 * 0.33, d1 * 0.72) if k % 2 == 0 else (d1 * 0.5,)):
                p = T.spt(bx, dd)
                c.put(p[0], p[1], _ix(tick, 0))
                c.put(p[0] - 1, p[1] - 1, _ix(tick, 5))
            k += 1
        _ticking_front(c, geo, T, spec, xm0, xm1, tick, tick2)
        # the pillow, grubby and flat
        pw = 15.0
        px0, px1 = (xm0 + 2.0, xm0 + 2.0 + pw) if head == 'left' else (xm1 - 2.0 - pw, xm1 - 2.0)
        pspec = dict(spec, col=spec.get('pillow_band', hexc('9a8f78')), pillow=spec.get('pillow', hexc('d4cdb8')))
        bag = spec.get('bag')
        if bag is not None:
            xa, xb = (px1 + 2.0, xm1 - 1.0) if head == 'left' else (xm0 + 1.0, px0 - 2.0)
            _bag(c, T, geo, spec, xa, xb, head)
        _pillow(c, T, geo, pspec, px0, px1)
    return fn


def _bag(c, T, geo, spec, xa, xb, head):
    """A sleeping bag lying along the mattress: mummy-shaped (it narrows toward the feet and the foot end is round), quilted in puffy baffles, a zip down the middle half undone so the lining
    shows, the middle of it slumping over the front edge of the mattress."""
    d1 = geo['d1']
    Tb = Top(T.y - 1.0, d1)
    col, lining = spec['bag'], spec.get('lining', hexc('c9803a'))
    main, lin = tn7(col), tn7(lining)
    length = xb - xa
    dm = d1 * 0.5
    zip_c = hexc('9aa0a6')

    def u_of(x):
        return (x - xa) if head == 'left' else (xb - x)

    def half_w(x):
        u = u_of(x) / length
        w = (d1 * 0.5 - 0.6) * (1.0 - 0.34 * u)
        if u > 0.9:
            w *= math.sqrt(max(0.0, 1.0 - ((u - 0.9) / 0.1) ** 2))
        elif u < 0.04:
            w *= 0.8 + 5.0 * u
        return w

    sag0, sag1 = 0.28, 0.72

    def fn(x, d, px, py):
        u = u_of(x)
        uu = u / length
        hw = half_w(x)
        sag = sag0 < uu < sag1
        hw_f = hw + (d1 * 0.2 if sag else 0.0)                              # the slumped middle bulges out toward us
        if abs(d - dm) > hw_f and not (sag and d - dm > 0 and d < d1 + 0.4):
            return None
        if abs(d - dm) > hw_f and d - dm > hw_f:
            return None
        off = d - dm
        ph = (u % 6.4) / 6.4
        i = 3 + (1 if 0.25 < ph < 0.75 else 0) - (1 if (ph < 0.08 or ph > 0.94) else 0)
        edge = abs(off) / max(hw_f, 0.5)
        if edge > 0.86:
            i -= 1
        if off < -hw * 0.5:
            i += 1                                                            # the far flank catches the light
        # the unzipped half: the lining folded back over the front side, near the head end
        if off > 0.4 and uu < 0.5 and off < hw_f * (1.0 - uu * 1.3):
            return _ix(lin, 3 + (1 if (u % 6.4) / 6.4 > 0.3 else 0) - (1 if edge > 0.8 else 0))
        if abs(off) < 0.5 and uu < 0.5:
            return zip_c if int(u) % 2 == 0 else _ix(main, 1)                 # the zip's teeth
        return _ix(main, i)
    d_lo, d_hi = dm - (d1 * 0.5 - 0.6), d1 + 0.4
    fill_top(c, Tb, min(xa, xb), max(xa, xb), d_lo, d_hi, fn)
    # the pull tab + a stitched label
    zx = xa + 0.5 * length if head == 'left' else xb - 0.5 * length
    p = Tb.spt(zx, dm)
    c.put(p[0], p[1], hexc('d84a3a'))
    c.put(p[0] + (1 if head == 'left' else -1), p[1], hexc('a8322c'))
    # the slumped middle hangs a little over the front edge
    xs0, xs1 = (xa + sag0 * length, xa + sag1 * length) if head == 'left' else (xb - sag1 * length, xb - sag0 * length)
    sd = dict(col=col, pattern='plain')
    _drape(c, Tb, xs0 + 1.0, xs1 - 1.0, d1 + 0.4, 4, sd, 0.9)
