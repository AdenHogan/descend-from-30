"""A GALLERY OF PORTRAITS (owner round 48i: "make a general collection of portraits to procedurally throw into various apartments. We don't or shouldn't always have the same ones").

The old room had four faces. This paints PEOPLE: each portrait is a small spec - who (a man, a woman, a girl, a boy, an old man, an old woman), skin tone, hair style and colour, glasses, a beard
or moustache, a hat, a collar or a necklace, the clothes and the backdrop - and `paint()` draws the spec as lit head-and-shoulders with a shaded cheek, a light catch in the eyes and a painter's
vignette. `SPECS` is a fixed library built from a seeded draw (so every build is the same pictures); the furniture piece `picture_portrait` has one variant per spec and the planner deals them
out, so two flats rarely hang the same faces. Three KINDS share the painter: an oil portrait (dark backdrop, formal dress), a studio photograph (a pale mottled backdrop, a mat) and a school
photograph (blue-grey mottle, a jumper and tie).
"""
import random

from pixlib import hexc, shade, mix

SKIN = [hexc('f2d2b4'), hexc('e6bf9c'), hexc('d0a07a'), hexc('b07e58'), hexc('84583c'), hexc('5e3e2c')]
HAIR = [hexc('1c1612'), hexc('3a2616'), hexc('5c3a1e'), hexc('8a5a2a'), hexc('c4a050'), hexc('b4b0a8'), hexc('7a4a2a'), hexc('e0dcd0'), hexc('a43c22')]
COAT = [hexc('2a2a34'), hexc('3a3228'), hexc('4a2a34'), hexc('2a4a3a'), hexc('2a3a5a'), hexc('5a2a2a'), hexc('4a4a50'), hexc('6a5a3a'), hexc('a8a094'), hexc('7a3a52')]
BG_OIL = [hexc('4a4234'), hexc('2e3a3a'), hexc('3e3434'), hexc('3a3a44'), hexc('4a3a2c'), hexc('2c3a4a'), hexc('403a2a'), hexc('3a2e3e')]
BG_PHOTO = [hexc('c8c0b0'), hexc('b8b4a8'), hexc('d0c8b4'), hexc('a8b0b0'), hexc('c4b8a0')]
BG_SCHOOL = [hexc('6a8ab0'), hexc('7a90b8'), hexc('5a7aa0'), hexc('8aa0c0')]
FRAMES = ['walnut', 'gilt', 'oak', 'black', 'white', 'pine']

MALE_HAIR = ['short', 'side', 'curly', 'bald', 'crop', 'long']
FEMALE_HAIR = ['bun', 'bob', 'long', 'curly', 'pigtails', 'short', 'bangs']
WHO = ['man', 'woman', 'girl', 'boy', 'old_man', 'old_woman']


def make_specs(n=36, seed=48):
    rng = random.Random(seed)
    out = []
    for i in range(n):
        who = WHO[i % len(WHO)] if i < len(WHO) * 2 else rng.choice(WHO)
        kind = ('oil', 'photo', 'school')[rng.choice((0, 0, 1, 1, 2))] if who not in ('girl', 'boy') else rng.choice(('photo', 'school', 'school'))
        female = who in ('woman', 'girl', 'old_woman')
        old = who.startswith('old')
        spec = {
            'i': i, 'who': who, 'kind': kind, 'skin': rng.randrange(len(SKIN)),
            'hair': rng.choice((5, 7)) if old else rng.choice((0, 1, 2, 3, 4, 6, 8)),
            'style': rng.choice(FEMALE_HAIR if female else MALE_HAIR) if not old else rng.choice(('short', 'bun', 'bald', 'side')) if not female else rng.choice(('bun', 'short', 'curly')),
            'coat': rng.randrange(len(COAT)), 'glasses': rng.random() < (0.55 if old else 0.2), 'hat': (not female and kind == 'oil' and rng.random() < 0.2),
            'beard': ('full' if rng.random() < 0.28 else 'moustache' if rng.random() < 0.3 else 'none') if who in ('man', 'old_man') else 'none',
            'collar': rng.choice(('white', 'white', 'open', 'lace')) if kind == 'oil' else ('tie' if kind == 'school' else rng.choice(('open', 'white', 'scarf'))),
            'jewel': female and rng.random() < 0.5,
            'bg': rng.randrange(8), 'frame': rng.choice(FRAMES) if kind != 'school' else rng.choice(('black', 'white', 'oak')),
        }
        if who in ('girl', 'boy'):
            spec['style'] = rng.choice(('pigtails', 'bob', 'bangs', 'short')) if who == 'girl' else rng.choice(('short', 'side', 'crop'))
            spec['hair'] = rng.randrange(0, 5)
        out.append(spec)
    return out


SPECS = make_specs()


def _backdrop(c, x0, y0, x1, y1, spec):
    pal = BG_OIL if spec['kind'] == 'oil' else BG_PHOTO if spec['kind'] == 'photo' else BG_SCHOOL
    bg = pal[spec['bg'] % len(pal)]
    rng = random.Random(spec['i'] * 7 + 1)
    h = max(1, y1 - y0)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            f = 1.10 - 0.30 * (y - y0) / float(h) - 0.12 * abs((x - (x0 + x1) / 2.0)) / max(1.0, (x1 - x0) / 2.0)   # light on the sitter, darker toward the corners
            if spec['kind'] != 'oil' and rng.random() < 0.18:
                f += rng.choice((-0.06, 0.05))                                                                        # the studio cloth's mottle
            c.put(x, y, shade(bg, max(0.4, f)))


def paint(c, x0, y0, x1, y1, spec):
    """Paint spec's sitter into the inner rect (x0, y0)-(x1, y1) of a frame."""
    _backdrop(c, x0, y0, x1, y1, spec)
    w, h = x1 - x0 + 1, y1 - y0 + 1
    cx = (x0 + x1) // 2
    skin = SKIN[spec['skin']]
    hair = HAIR[spec['hair']]
    coat = COAT[spec['coat']]
    who = spec['who']
    child = who in ('girl', 'boy')
    old = who.startswith('old')
    female = who in ('woman', 'girl', 'old_woman')
    scale = 0.86 if child else 1.0
    hr = max(2.5, w * 0.20 * scale)                         # head half-width
    hy = y0 + int(h * (0.46 if child else 0.40))            # head centre
    sh = y0 + int(h * (0.72 if child else 0.68))            # shoulder line
    # --- clothes
    sw = int(w * (0.36 if child else 0.42))
    c.poly([(cx - sw, y1), (cx - int(sw * 0.72), sh), (cx + int(sw * 0.72), sh), (cx + sw, y1)], coat)
    c.line(cx - int(sw * 0.72), sh, cx - sw, y1, shade(coat, 1.35))                            # the lit shoulder
    c.line(cx + int(sw * 0.72), sh, cx + sw, y1, shade(coat, 0.7))                             # the shaded one
    for yy in range(sh + 1, y1 + 1):
        c.put(cx + sw - (yy - sh) // 3 - 1, yy, shade(coat, 0.72))
    # --- neck
    c.rect(cx - 2, sh - 4, cx + 2, sh, shade(skin, 0.92))
    c.rect(cx + 1, sh - 4, cx + 2, sh, shade(skin, 0.72))
    col = spec['collar']
    if col == 'white':
        c.poly([(cx - 4, sh - 1), (cx, sh + 4), (cx + 4, sh - 1)], hexc('ece8dc'))
        c.line(cx - 4, sh - 1, cx, sh + 4, shade(hexc('ece8dc'), 0.8))
    elif col == 'lace':
        for k in range(-4, 5):
            c.put(cx + k, sh + (1 if k % 2 else 0), hexc('f0eadc'))
        c.hline(cx - 3, cx + 3, sh + 2, hexc('d8d2c0'))
    elif col == 'tie':
        c.poly([(cx - 3, sh - 1), (cx, sh + 2), (cx + 3, sh - 1)], hexc('f0eee8'))
        c.rect(cx, sh + 1, cx, y1, hexc('a8322a'))
        c.put(cx, sh + 1, shade(hexc('a8322a'), 1.3))
    elif col == 'scarf':
        c.rect(cx - 4, sh - 1, cx + 4, sh + 2, hexc('c8483a') if spec['coat'] % 2 else hexc('3a6a9a'))
        c.hline(cx - 4, cx + 4, sh - 1, hexc('e8e0d0'))
    else:
        c.poly([(cx - 3, sh - 1), (cx, sh + 3), (cx + 3, sh - 1)], shade(skin, 0.86))                  # an open neck
    if spec['jewel']:
        c.put(cx - 2, sh + 3, hexc('e8d8a0')); c.put(cx, sh + 4, hexc('e8d8a0')); c.put(cx + 2, sh + 3, hexc('e8d8a0'))
    # --- head (owner round 49f: "the details of the rectangular pictures look like Terrence and Phillip from South Park. We need better looking people in photos"): the old head was a flat
    # oval with two dots and a slit; this one is lit from the upper left per pixel (four tones, a narrower jaw), with ears, lidded eyes (a pale white and a dark iris, a catch of light), brows, a
    # nose with a lit tip and a shaded side, a lipped mouth that smiles a little, a shadow under the chin, and a few lines on the old.
    ry = hr * (1.30 if not child else 1.18)
    tones = (1.10, 1.0, 0.88, 0.76)
    for yy in range(int(hy - ry) - 1, int(hy + ry) + 2):
        v = (yy + 0.5 - hy) / ry
        if abs(v) > 1.0:
            continue
        half = hr * (1.0 - 0.22 * max(0.0, v) ** 2) * (0.92 + 0.08 * (1.0 - abs(v)))        # the jaw narrows toward the chin
        for xx in range(int(cx - half) - 1, int(cx + half) + 2):
            u = (xx + 0.5 - cx) / max(0.5, half)
            if abs(u) > 1.0:
                continue
            lit = 1.0 - 0.34 * u - 0.10 * v + (0.10 if (u < -0.2 and -0.3 < v < 0.45) else 0.0)     # light from the upper left, the cheek catching it
            k = 0 if lit > 1.22 else 1 if lit > 0.92 else 2 if lit > 0.62 else 3
            c.put(xx, yy, shade(skin, tones[k]))
    ey = hy - 1
    es = max(2, int(round(hr * 0.52)))                                                     # half the gap between the eyes
    lid = shade(skin, 0.66)
    white = shade(hexc('e6e2d8'), 0.9)
    iris = hexc('221a16') if spec['skin'] < 4 else hexc('120e0c')
    eye = iris
    for sgn in (-1, 1):
        ox0 = cx + sgn * es
        c.put(ox0 + sgn, ey, white)                                                          # the outer white
        c.put(ox0, ey, iris)                                                                 # the iris, looking out at you
        c.put(ox0, ey - 1, lid); c.put(ox0 + sgn, ey - 1, lid)                               # the lid
        c.put(ox0 + sgn, ey + 1, shade(skin, 0.86))                                          # the shadow under the eye
        c.hline(min(ox0, ox0 + sgn * 2), max(ox0, ox0 + sgn * 2), ey - 2, shade(hair, 0.78) if spec['style'] != 'bald' else shade(skin, 0.7))   # the brow (a bald head keeps a faint one)
    nose = shade(skin, 0.84)
    c.put(cx + 1, ey, nose); c.put(cx + 1, ey + 1, nose)                                    # the bridge, shaded on its far side
    c.put(cx, ey + 2, shade(skin, 1.14))                                                     # the lit tip
    c.put(cx - 1, ey + 3, shade(skin, 0.66)); c.put(cx + 1, ey + 3, shade(skin, 0.58))       # the nostrils
    my = hy + max(3, int(round(ry * 0.52)))                                                  # the mouth
    lip = hexc('b4605a') if female else shade(skin, 0.66)
    c.hline(cx - 1, cx + 1, my, shade(lip, 0.72))                                            # the line between the lips
    c.hline(cx - 1, cx + 0, my + 1, shade(lip, 1.15) if female else shade(skin, 0.86))       # the lower lip, lit
    c.put(cx - 2, my - (1 if spec['kind'] != 'oil' else 0), shade(skin, 0.7))                # the corners: a small smile in a photograph, level in an oil
    c.put(cx + 2, my - (1 if spec['kind'] != 'oil' else 0), shade(skin, 0.6))
    c.put(cx, my + 2, shade(skin, 0.80))                                                     # the shadow under the lip
    if female and not child:
        c.put(cx - es - 1, ey + 2, mix(skin, hexc('d88a80'), 0.35)); c.put(cx + es + 1, ey + 2, mix(skin, hexc('d88a80'), 0.30))      # a touch of colour on the cheeks
    if child:
        c.put(cx - es - 1, ey + 2, mix(skin, hexc('e09a90'), 0.4)); c.put(cx + es + 1, ey + 2, mix(skin, hexc('e09a90'), 0.35))
    ex0 = int(cx - hr) - 1                                                                   # the ears
    c.put(ex0, ey + 1, shade(skin, 0.92)); c.put(ex0, ey + 2, shade(skin, 0.82))
    c.put(int(cx + hr) + 1, ey + 1, shade(skin, 0.74)); c.put(int(cx + hr) + 1, ey + 2, shade(skin, 0.66))
    c.hline(cx - 2, cx + 2, int(hy + ry) + 1, shade(skin, 0.55))                             # the shadow the chin throws on the neck
    if old:
        c.put(cx - es - 2, ey, shade(skin, 0.74)); c.put(cx + es + 2, ey, shade(skin, 0.66))        # crow's feet
        c.put(cx - 2, my - 1, shade(skin, 0.74)); c.put(cx + 2, my - 1, shade(skin, 0.66))            # the lines from the nose to the mouth
        c.hline(cx - 2, cx + 2, ey - 4, shade(skin, 0.84))                                            # a line across the forehead
    if female and not child and spec['jewel']:
        c.put(ex0 - 0, ey + 3, hexc('f0e0a0')); c.put(int(cx + hr) + 1, ey + 3, hexc('f0e0a0'))     # earrings
    # --- beard / moustache
    if spec['beard'] == 'full':
        for yy in range(hy + 2, int(hy + ry) + 1):
            for xx in range(int(cx - hr * 0.75), int(cx + hr * 0.75) + 1):
                if ((xx - cx) / (hr * 0.9)) ** 2 + ((yy - (hy + 1)) / ry) ** 2 <= 1.05 and (yy > hy + 3 or abs(xx - cx) > 1):
                    c.put(xx, yy, shade(hair, 0.9 if xx <= cx else 0.7))
        c.hline(cx - 1, cx + 1, hy + 3, lip)
    elif spec['beard'] == 'moustache':
        c.hline(cx - 2, cx + 2, hy + 2, hair)
    # --- hair
    top = int(round(hy - ry))
    style = spec['style']
    hl = shade(hair, 1.30)
    if style == 'bald':
        c.put(int(cx - hr), hy - 2, hair); c.put(int(cx + hr), hy - 2, shade(hair, 0.8))
        c.put(cx - 1, top + 1, shade(skin, 1.15))
    elif style in ('short', 'crop'):
        c.ellipse(cx, top + 1, hr + 0.4, 2.2 if style == 'short' else 1.6, hair)
        c.put(int(cx - hr), top + 2, hair); c.put(int(cx + hr), top + 2, shade(hair, 0.8))
        c.put(cx - 2, top, hl)
    elif style == 'side':
        c.ellipse(cx, top + 1, hr + 0.6, 2.4, hair)
        c.hline(cx - 3, cx - 1, top + 2, hair); c.put(int(cx - hr), top + 3, hair)
        c.put(cx + 1, top, hl); c.put(cx, top, hl)
    elif style == 'curly':
        for k in range(-3, 4):
            c.ellipse(cx + k * 1.5, top + 1 - (k % 2), 1.6, 1.6, hair)
        c.put(int(cx - hr) - 1, top + 3, hair); c.put(int(cx + hr) + 1, top + 3, shade(hair, 0.8))
        c.put(cx - 2, top - 1, hl)
    elif style == 'long':
        c.ellipse(cx, top + 1, hr + 0.8, 2.6, hair)
        c.rect(int(cx - hr) - 1, top + 1, int(cx - hr), sh, hair); c.rect(int(cx + hr), top + 1, int(cx + hr) + 1, sh, shade(hair, 0.8))
        c.put(int(cx - hr), top + 2, hl)
    elif style == 'bun':
        c.ellipse(cx, top + 1, hr + 0.7, 2.2, hair)                                     # the hair swept back, a round knot on top (not a cone: a ball sitting on the crown)
        c.ellipse(cx, top - 1, 2.6, 2.2, shade(hair, 0.92))
        c.hline(cx - 1, cx + 0, top - 2, hl)
        c.vline(int(cx - hr), top + 1, hy, hair); c.vline(int(cx + hr), top + 1, hy, shade(hair, 0.8))
    elif style == 'bob':
        c.ellipse(cx, top + 1, hr + 0.8, 2.6, hair)
        c.rect(int(cx - hr) - 1, top + 1, int(cx - hr), hy + 3, hair); c.rect(int(cx + hr), top + 1, int(cx + hr) + 1, hy + 3, shade(hair, 0.8))
        c.hline(cx - 3, cx + 3, top + 2, hair)
    elif style == 'pigtails':
        c.ellipse(cx, top + 1, hr + 0.5, 2.4, hair)
        c.rect(int(cx - hr) - 2, top + 3, int(cx - hr) - 1, sh - 1, hair); c.rect(int(cx + hr) + 1, top + 3, int(cx + hr) + 2, sh - 1, shade(hair, 0.8))
        c.put(int(cx - hr) - 1, top + 2, hexc('c8483a')); c.put(int(cx + hr) + 1, top + 2, hexc('c8483a'))
    elif style == 'bangs':
        c.ellipse(cx, top + 1, hr + 0.6, 2.5, hair)
        c.hline(cx - 3, cx + 3, top + 3, hair); c.hline(cx - 2, cx + 2, top + 4, shade(hair, 0.9))
        c.rect(int(cx - hr) - 1, top + 1, int(cx - hr), sh, hair); c.rect(int(cx + hr), top + 1, int(cx + hr) + 1, sh, shade(hair, 0.8))
    if spec['hat']:
        hc = hexc('3a2a1a')
        c.rect(cx - 5, top - 1, cx + 5, top, hc)
        c.rect(cx - 3, top - 4, cx + 3, top - 2, hc)
        c.hline(cx - 3, cx + 3, top - 4, shade(hc, 1.4))
    # --- spectacles
    if spec['glasses']:
        gl = hexc('6a645a')
        for sgn in (-1, 1):                                                                  # a round rim round each eye, a bridge between
            ox0 = cx + sgn * es
            xs = sorted((ox0 - sgn * 1 if False else ox0, ox0 + sgn))
            for gx in range(xs[0] - 1, xs[1] + 2):
                c.put(gx, ey - 1, gl); c.put(gx, ey + 1, gl)
            c.put(xs[0] - 1, ey, gl); c.put(xs[1] + 1, ey, gl)
        c.hline(cx - es + 1, cx + es - 1, ey - 1 + 0, gl) if es > 2 else c.put(cx, ey - 1, gl)
        for sgn in (-1, 1):
            c.put(cx + sgn * es, ey, iris); c.put(cx + sgn * (es + 1), ey, white)
    # --- a dark painter's edge on the right of an oil, a soft white border-less photo curl otherwise
    if spec['kind'] == 'oil':
        for yy in range(y0, y1 + 1):
            c.put(x0, yy, shade(c.px[x0, yy], 0.8)); c.put(x1, yy, shade(c.px[x1, yy], 0.7))


def frame_kind(spec):
    return spec['frame']


def mat_for(spec):
    return hexc('ece2c8') if spec['kind'] != 'school' else hexc('f4f0e6')


def pick(who, kind, nth=0):
    """The index of the nth sitter of this kind in the gallery (the dining room's row of oils hangs particular people)."""
    n = 0
    for sp in SPECS:
        if sp['who'] == who and sp['kind'] == kind:
            if n == nth:
                return sp['i']
            n += 1
    for sp in SPECS:
        if sp['who'] == who:
            return sp['i']
    return 0
