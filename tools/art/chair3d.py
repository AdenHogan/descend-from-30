"""Armchairs at ANY angle: a tiny 3D model rendered into pixel art.

Drawing a chair turned three-quarters by hand keeps coming out wrong (owner: "you can draw them
from the front and the side but not from an angle"), so the chair is BUILT — a seat base, a seat
cushion, two arms with rolled tops, a low (club) or tall back and four legs, as boxes and prisms in 3D —
turned by `yaw` and projected with the rooms' view (straight on, looking a little down: depth
recedes UP the screen). A z-buffer sorts it out; each face is lit by the rooms' flat top-left
light and snapped to a 5-tone ramp of the upholstery colour, then outlined: the silhouette in the
darkest tone, the creases between parts one step darker. The result is flat, readable pixel art
that looks turned because it IS turned.

Units: 1 unit = 1 px at the rooms' scale. The chair stands on z = 0 at its footprint centre.
    armchair(c, cx, base_y, yaw, pal, style='club'|'wing')
      cx, base_y  where the chair's footprint centre meets the floor on screen
      yaw         degrees; 0 = facing us, +35 = turned to face screen-LEFT (three-quarters),
                  -35 = to face screen-RIGHT, 90 = side-on facing left. (Round 12 fix: the sign
                  was backwards — every chair faced away from what it was grouped with.)
      plan        optional {run: 'ok' | 'blood' | 'tipped' | 'side'}: how this chair looks on
                  runs 2/3 — blood-stained, or knocked over flat on its back / onto its side (a
                  real 3D fall, so it lands right at any yaw) and bloodied; the stain is placed on
                  the upright chair's surfaces, so it follows the chair's angle. pixlib.
                  finish_module(per_run=...) rebuilds a module per run with RUN set.
"""
import math
import random

RUN = 1               # set by the module build for its run-2 / run-3 rebuilds

DEPTH_K = 0.22        # how far up the screen one unit of depth moves a point — matched to the rooms'
                      # hand-drawn furniture (a table shows a ~5px top); 0.42 read as seen from above
HEIGHT_K = 0.98       # vertical foreshortening from looking slightly down
LIGHT = (-0.45, -0.55, 0.70)   # from the upper left, a little in front


def _norm(v):
    l = math.sqrt(sum(a * a for a in v)) or 1.0
    return tuple(a / l for a in v)


LIGHT = _norm(LIGHT)


def ramp(col, n=5):
    """A 5-step shading ramp around an upholstery colour (dark .. light)."""
    out = []
    for k in range(n):
        f = 0.48 + 0.21 * k           # 0.48 .. 1.32
        if f <= 1.0:
            out.append(tuple(int(col[i] * f) for i in range(3)) + (255,))
        else:
            out.append(tuple(int(col[i] + (255 - col[i]) * (f - 1.0) * 0.55) for i in range(3)) + (255,))
    return out


class Model:
    def __init__(self):
        self.faces = []          # (points3d[list], part_id, material, source points)

    def add(self, pts, part, mat):
        self.faces.append((pts, part, mat, list(pts)))

    def box(self, x0, x1, y0, y1, z0, z1, part, mat, bevel=0.0):
        """An axis-aligned box (x right, y depth into the room, z up); `bevel` cuts its top edges."""
        b = bevel
        if b <= 0:
            P = lambda x, y, z: (x, y, z)
            c = [P(x0, y0, z0), P(x1, y0, z0), P(x1, y1, z0), P(x0, y1, z0),
                 P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)]
            quads = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7), (3, 2, 1, 0)]
            for q in quads:
                self.add([c[i] for i in q], part, mat)
            return
        # a bevelled top: the top face inset by b, slanted faces down to the sides
        zt = z1 - b
        self.box(x0, x1, y0, y1, z0, zt, part, mat)
        top = [(x0 + b, y0 + b, z1), (x1 - b, y0 + b, z1), (x1 - b, y1 - b, z1), (x0 + b, y1 - b, z1)]
        rim = [(x0, y0, zt), (x1, y0, zt), (x1, y1, zt), (x0, y1, zt)]
        self.add(top, part, mat)
        for i in range(4):
            j = (i + 1) % 4
            self.add([rim[i], rim[j], top[j], top[i]], part, mat)

    def roll(self, x0, x1, y0, y1, zc, r, part, mat, sides=7):
        """A rolled arm top: a half-cylinder along the depth axis, centred at x=(x0+x1)/2."""
        xc = (x0 + x1) / 2.0
        pts = []
        for k in range(sides + 1):
            a = math.pi * k / sides
            pts.append((xc + math.cos(a) * r, zc + math.sin(a) * r))
        for k in range(sides):
            (xa, za), (xb, zb) = pts[k], pts[k + 1]
            self.add([(xa, y0, za), (xb, y0, zb), (xb, y1, zb), (xa, y1, za)], part, mat)
        cap_f = [(x, y0, z) for (x, z) in pts]
        cap_b = [(x, y1, z) for (x, z) in reversed(pts)]
        self.add(cap_f, part, mat)
        self.add(cap_b, part, mat)


def build(style, cushion=True):
    m = Model()
    W, D = 28.0, 24.0
    hw, hd = W / 2, D / 2
    for (lx, ly) in ((-hw + 2, -hd + 2), (hw - 3, -hd + 2), (-hw + 2, hd - 3), (hw - 3, hd - 3)):
        m.box(lx, lx + 2.0, ly, ly + 2.0, 0, 4, 'leg', 'wood')
    m.box(-hw, hw, -hd, hd, 4, 12, 'base', 'fab', bevel=1.0)                      # the seat base
    if cushion:
        m.box(-hw + 5, hw - 5, -hd + 1, hd - 6, 12, 15, 'cushion', 'fab_lt', bevel=1.2)  # the cushion
    for side in (-1, 1):                                                          # the arms
        ax0, ax1 = (-hw, -hw + 5) if side < 0 else (hw - 5, hw)
        m.box(ax0, ax1, -hd, hd - 2, 12, 18, 'arm%d' % side, 'fab')
        m.roll(ax0 - 0.4, ax1 + 0.4, -hd - 0.6, hd - 2, 18, 2.8, 'arm%d' % side, 'fab')
    back_top = 36 if style == 'wing' else 30
    m.box(-hw, hw, hd - 6, hd, 12, back_top, 'back', 'fab', bevel=2.0)          # the back
    m.box(-hw + 5, hw - 5, hd - 9, hd - 6, 15, back_top - 4, 'backcush', 'fab_lt', bevel=1.2)
    return m


def _rot(p, yaw):
    a = math.radians(-yaw)          # +yaw turns the chair's front toward screen-LEFT
    x, y, z = p
    return (x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a), z)


def _proj(p):
    x, y, z = p
    return (x, -z * HEIGHT_K - y * DEPTH_K)


def _depth(p):
    x, y, z = p
    return y - z * 0.08          # further into the room = further away; a touch for height


def _normal(pts):
    a, b, c = pts[0], pts[1], pts[2]
    u = tuple(b[i] - a[i] for i in range(3))
    v = tuple(c[i] - a[i] for i in range(3))
    n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
    return _norm(n)


def render(model, yaw, pal, size=64):
    """-> dict pixel -> colour, plus bounds. pal: {'fab': col, 'fab_lt': col, 'wood': col}."""
    ramps = {k: ramp(v) for k, v in pal.items()}
    zbuf, cbuf, pbuf, sbuf = {}, {}, {}, {}
    view = _norm((0.0, 1.0, -0.4))  # the viewer looks INTO the room (+y) and a little down
    centre = {}                     # each part's centre, to point every face normal OUTWARD
    for (pts, part, mat, src) in model.faces:
        for p in pts:
            acc = centre.setdefault(part, [0.0, 0.0, 0.0, 0])
            for i in range(3):
                acc[i] += p[i]
            acc[3] += 1
    for part, acc in centre.items():
        centre[part] = _rot((acc[0] / acc[3], acc[1] / acc[3], acc[2] / acc[3]), yaw)
    for (pts, part, mat, src) in model.faces:
        rp = [_rot(p, yaw) for p in pts]
        n = _normal(rp)
        fc = tuple(sum(p[i] for p in rp) / len(rp) for i in range(3))
        pc = centre[part]
        if sum(n[i] * (fc[i] - pc[i]) for i in range(3)) < 0:
            n = (-n[0], -n[1], -n[2])
        if n[0] * view[0] + n[1] * view[1] + n[2] * view[2] >= 0:   # facing away from us
            continue
        lum = max(0.0, n[0] * LIGHT[0] + n[1] * LIGHT[1] + n[2] * LIGHT[2])
        # snap to the ramp with firm steps: tops light, faces toward the light mid, away dark
        tone = 4 if lum > 0.82 else 3 if lum > 0.58 else 2 if lum > 0.34 else 1
        if n[2] > 0.75:
            tone = max(tone, 3)
        if n[2] < -0.2:
            tone = 0
        col = ramps[mat][tone]
        sp = [_proj(p) for p in rp]
        dp = [_depth(p) for p in rp]
        for i in range(1, len(sp) - 1):                              # fan into triangles
            _tri(sp[0], sp[i], sp[i + 1], dp[0], dp[i], dp[i + 1], col, part, zbuf, cbuf, pbuf,
                 (src[0], src[i], src[i + 1]), sbuf)
    return cbuf, pbuf, zbuf, sbuf


def _tri(a, b, c, da, db, dc, col, part, zbuf, cbuf, pbuf, src=None, sbuf=None):
    minx, maxx = int(math.floor(min(a[0], b[0], c[0]))), int(math.ceil(max(a[0], b[0], c[0])))
    miny, maxy = int(math.floor(min(a[1], b[1], c[1]))), int(math.ceil(max(a[1], b[1], c[1])))
    den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(den) < 1e-9:
        return
    for y in range(miny, maxy + 1):
        for x in range(minx, maxx + 1):
            px, py = x + 0.5, y + 0.5
            w1 = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / den
            w2 = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / den
            w3 = 1 - w1 - w2
            if w1 < -0.01 or w2 < -0.01 or w3 < -0.01:
                continue
            d = w1 * da + w2 * db + w3 * dc
            if d < zbuf.get((x, y), 1e9):
                zbuf[(x, y)] = d
                cbuf[(x, y)] = col
                pbuf[(x, y)] = part
                if sbuf is not None:           # where on the UPRIGHT chair this pixel is
                    sbuf[(x, y)] = tuple(w1 * src[0][i] + w2 * src[1][i] + w3 * src[2][i] for i in range(3))


def fall(model, how='back', lean=6.0):
    """Knock the chair OVER: 'back' = rotated 90 deg about its back-bottom edge so it lies on its
    back (underside and legs toward us, the back cushion facing the ceiling); 'side' = rolled 90 deg
    onto its right arm (lean > 0) or left arm (lean < 0). `lean` also tips it a few degrees askew.
    The footprint is re-centred on the chair's old spot and it's set down on the floor."""
    hd, hw = 12.0, 14.0
    sd = 1.0 if lean >= 0 else -1.0
    r = math.radians(abs(lean)) * sd
    out = Model()
    for (pts, part, mat, src) in model.faces:
        np_ = []
        for (x, y, z) in pts:
            if how == 'back':
                x, y, z = x, hd + z, hd - y                # about the edge y = hd, z = 0
                x, z = x * math.cos(r) - z * math.sin(r), x * math.sin(r) + z * math.cos(r)
            else:
                ex = hw * sd                               # about the bottom edge of that arm
                x, z = ex + z * sd, -(x - ex) * sd
                y, z = y * math.cos(r) - z * math.sin(r), y * math.sin(r) + z * math.cos(r)
            np_.append((x, y, z))
        out.faces.append((np_, part, mat, src))
    allp = [p for f in out.faces for p in f[0]]
    mx = (min(p[0] for p in allp) + max(p[0] for p in allp)) / 2
    my = (min(p[1] for p in allp) + max(p[1] for p in allp)) / 2
    mz = min(p[2] for p in allp)
    out.faces = [([(x - mx, y - my, z - mz) for (x, y, z) in pts], part, mat, src)
                 for (pts, part, mat, src) in out.faces]
    return out


def _footprint_shadow(c, cx, base_y, model, yaw):
    """The chair's own footprint darkened on the floor (every point dropped to z = 0) — a fallen
    chair's shape, not the round contact shadow of one standing."""
    pts = sorted({(cx + x, base_y - y * DEPTH_K + 1)
                  for (ps, part, mat, src) in model.faces for (x, y, z) in (_rot(p, yaw) for p in ps)})
    cr = lambda o, a, b: (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cr(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    hull = lo[:-1] + up[:-1]
    for y in range(int(min(p[1] for p in hull)), int(max(p[1] for p in hull)) + 2):
        for x in range(int(min(p[0] for p in hull)) - 1, int(max(p[0] for p in hull)) + 2):
            if all((b[0] - a[0]) * (y + 0.5 - a[1]) - (b[1] - a[1]) * (x + 0.5 - a[0]) >= 0
                   for a, b in zip(hull, hull[1:] + hull[:1])):
                c.put(x, y, (20, 14, 12, 95))


BLOOD = ((58, 14, 12, 255), (92, 24, 20, 235), (92, 24, 20, 170))


def _bloody(c, cx, base_y, cbuf, pbuf, sbuf, rng, heavy, fallen, underside=False):
    """Blood soaked into the seat and up the back cushion, over the seat's front edge — placed on
    the UPRIGHT chair's own surfaces (`sbuf`: where each pixel is on the chair), so a knocked-over
    chair carries its stain at the chair's angle, not the screen's. Then blood on the floor: drips
    under a standing chair, a pool spread out beside a fallen one."""
    ox = rng.uniform(-4, 4)
    blobs = [((ox, rng.uniform(-6, 0), 13.5), rng.uniform(5.5, 7.5) * (1.25 if heavy else 1.0)),
             ((ox + rng.uniform(-3, 3), 3.0, 21.0), rng.uniform(4.5, 6.5) * (1.2 if heavy else 1.0))]
    if underside:        # on its back the seat faces away: blood splashed over the bare underside
        blobs.append(((ox, rng.uniform(-3, 3), 4.0), rng.uniform(6.5, 8.5)))
    ph = [rng.uniform(0, 6.28) for _ in range(3)]
    stain = {}
    for (x, y), q in sbuf.items():
        if pbuf[(x, y)] == 'leg':
            continue
        d = 9.0
        for (cpos, rad) in blobs:
            dx, dy, dz = q[0] - cpos[0], q[1] - cpos[1], q[2] - cpos[2]
            a = math.atan2(dy + dz, dx)
            k = 1.0 + 0.3 * math.sin(3 * a + ph[0]) + 0.15 * math.sin(5 * a + ph[1]) + 0.1 * math.sin(9 * a + ph[2])
            d = min(d, math.sqrt(dx * dx + dy * dy + dz * dz) / (rad * k))
        if d < 0.7:
            stain[(x, y)] = BLOOD[0]
        elif d < 1.0:
            stain[(x, y)] = BLOOD[1]
        elif d < 1.2 and rng.random() < 0.5:
            stain[(x, y)] = BLOOD[2]
    for (x, y), col in stain.items():
        c.put(cx + x, base_y + y, col)
    floor_y = max(y for x, y in cbuf)
    if not fallen or underside:
        bottom = {}
        for (x, y) in stain:                                 # drips run down the chair's front
            if y > bottom.get(x, -99):
                bottom[x] = y
        for x in rng.sample(sorted(bottom), min(len(bottom), 3 if heavy else 2)):
            y = bottom[x]
            for k in range(1, rng.randrange(3, 9)):
                if (x, y + k) in cbuf:
                    c.put(cx + x, base_y + y + k, (82, 20, 17, 230))
    if not fallen:
        mx = int(sum(x for x, y in stain) / len(stain)) if stain else 0
        for k in range(rng.randrange(3, 7) + (4 if heavy else 0)):   # and on the floor under it
            x = mx + rng.randrange(-10, 11)
            y = floor_y + rng.randrange(1, 4)
            if (x, y) not in cbuf:
                c.put(cx + x, base_y + y, (74, 18, 15, 220))
                if heavy and rng.random() < 0.5:
                    c.put(cx + x + 1, base_y + y, (74, 18, 15, 200))
        return
    # fallen: it ran out of the seat and pooled on the floor along the chair's front
    xs = [x for (x, y) in cbuf if y >= floor_y - 2]
    px = rng.uniform(min(xs), max(xs)) if xs else 0
    prx, pry = rng.uniform(7, 10) * (1.2 if heavy else 1.0), rng.uniform(1.8, 2.6)
    py = floor_y + 1
    for y in range(int(py - pry) - 1, int(py + pry) + 2):
        for x in range(int(px - prx) - 1, int(px + prx) + 2):
            a = math.atan2((y - py) / pry, (x - px) / prx)
            k = 1.0 + 0.25 * math.sin(3 * a + ph[1]) + 0.12 * math.sin(7 * a + ph[2])
            d = math.hypot((x - px) / prx, (y - py) / pry) / k
            if (x, y) in cbuf or d > 1.0:
                continue
            c.put(cx + x, base_y + y, BLOOD[0] if d < 0.65 else (74, 18, 15, 215))
    for k in range(rng.randrange(4, 8)):                     # and spatter around it
        x = int(px) + rng.randrange(-16, 17)
        y = floor_y + rng.randrange(-1, 5)
        if (x, y) not in cbuf:
            c.put(cx + x, base_y + y, (74, 18, 15, 210))


def armchair(c, cx, base_y, yaw, pal, style='wing', outline=None, shadow=True, plan=None, key='chair'):
    """Draw a turned armchair onto a pixlib Canvas: footprint centre at (cx, base_y) on screen."""
    state = (plan or {}).get(RUN, 'ok')
    fallen = state in ('tipped', 'side')
    model = build(style, cushion=not fallen)
    if fallen:
        # KNOCKED OVER (owner round 13 — "on its back, knocked over, rather than precariously
        # balancing"): flat on its back, underside and legs toward us — or rolled onto an arm — a
        # little askew, the seat cushion thrown out onto the floor beside it.
        side = 1 if yaw >= 0 else -1
        model = fall(model, 'back' if state == 'tipped' else 'side', 6.0 * side)
        allp = [p for f in model.faces for p in f[0]]
        y0 = min(p[1] for p in allp)
        x1 = max(p[0] for p in allp) if side < 0 else min(p[0] for p in allp)
        cx0 = x1 + 4 * side if side < 0 else x1 - 20
        model.box(cx0, cx0 + 16, y0 - 16, y0 - 1, 0, 3, 'cushion', 'fab_lt', bevel=1.0)
    cbuf, pbuf, zbuf, sbuf = render(model, yaw, pal)
    if not cbuf:
        return
    out = outline or tuple(int(v * 0.3) for v in pal['fab'][:3]) + (255,)
    crease = {}
    for (x, y), col in cbuf.items():                         # creases: a step darker where parts meet
        part = pbuf[(x, y)]
        for (dx, dy) in ((1, 0), (0, 1)):
            q = (x + dx, y + dy)
            if q in pbuf and pbuf[q] != part and abs(zbuf[q] - zbuf[(x, y)]) > 1.5:
                far = q if zbuf[q] > zbuf[(x, y)] else (x, y)
                crease[far] = True
    if shadow and fallen:
        _footprint_shadow(c, cx, base_y, model, yaw)
    elif shadow:
        c.shadow(cx, base_y, 19, 3, 110)
    for (x, y), col in cbuf.items():
        if crease.get((x, y)):
            col = tuple(int(v * 0.72) for v in col[:3]) + (255,)
        c.put(cx + x, base_y + y, col)
    for (x, y) in cbuf:                                       # the silhouette
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in cbuf:
                c.put(cx + x + dx, base_y + y + dy, out)
    if state != 'ok':
        import zlib
        seat = {p: q for p, q in sbuf.items() if pbuf[p] != 'cushion' or not fallen}
        _bloody(c, cx, base_y, cbuf, pbuf, seat, random.Random(zlib.crc32(('%s:%d' % (key, RUN)).encode())),
                heavy=(fallen or RUN >= 3), fallen=fallen, underside=(state == 'tipped'))
    return {'bbox': (cx + min(x for x, y in cbuf) - 1, base_y + min(y for x, y in cbuf) - 1,
                     cx + max(x for x, y in cbuf) + 1, base_y + max(y for x, y in cbuf) + 1)}


if __name__ == '__main__':
    import os, sys
    sys.path.insert(0, os.path.dirname(__file__))
    from pixlib import Canvas, hexc
    from PIL import Image
    c = Canvas(w=420, h=150, seed=1)
    c.rect(0, 0, 419, 149, hexc('8a7a64'))
    c.rect(0, 50, 419, 80, hexc('6b4a31'))
    c.rect(0, 100, 419, 149, hexc('6b4a31'))
    pal = {'fab': hexc('7a302b'), 'fab_lt': hexc('8e3a33'), 'wood': hexc('4a2e1e')}
    pal2 = {'fab': hexc('3e5a4a'), 'fab_lt': hexc('4a6a58'), 'wood': hexc('3a2618')}
    for i, yaw in enumerate((0, 25, 40, 60, 90, -40, -25)):
        armchair(c, 30 + i * 58, 70, yaw, pal if i % 2 == 0 else pal2, style='wing' if i < 5 else 'club')
    RUN = 3
    for i, yaw in enumerate((35, -35, 40, -40)):
        armchair(c, 40 + i * 100, 140, yaw, pal if i % 2 == 0 else pal2, style='wing' if i < 2 else 'club',
                 plan={3: ('tipped', 'side', 'blood', 'tipped')[i]}, key='prev%d' % i)
    RUN = 1
    out = os.path.join(os.path.dirname(__file__), '..', '..', 'docs', 'art_reference', 'modules', 'armchair_angles.png')
    c.img.resize((420 * 3, 150 * 3), Image.NEAREST).save(out)
    print('wrote', out)
