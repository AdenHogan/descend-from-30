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
    c.rect(cx - 1, sh - 3, cx + 1, sh, shade(skin, 0.92))
    c.put(cx + 1, sh - 2, shade(skin, 0.72)); c.put(cx + 1, sh - 1, shade(skin, 0.72))
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
    # --- head: lit on the left, a shaded cheek on the right
    ry = hr * (1.22 if not child else 1.12)
    c.ellipse(cx, hy, hr, ry, skin)
    for yy in range(int(hy - ry), int(hy + ry) + 1):
        for xx in range(int(cx + hr * 0.45), int(cx + hr) + 1):
            if ((xx - cx) / hr) ** 2 + ((yy - hy) / ry) ** 2 <= 1.0:
                c.put(xx, yy, shade(skin, 0.80))
    c.put(int(cx - hr * 0.55), hy + 1, shade(skin, 1.10)); c.put(int(cx - hr * 0.55), hy + 2, shade(skin, 1.06))   # the lit cheek
    ey = hy - 1
    eye = hexc('1e1814')
    c.put(cx - 2, ey, eye); c.put(cx + 2, ey, eye)
    c.put(cx - 2, ey - 1, shade(hair, 0.8)); c.put(cx - 3, ey - 1, shade(hair, 0.8)); c.put(cx + 2, ey - 1, shade(hair, 0.8)); c.put(cx + 3, ey - 1, shade(hair, 0.8))   # brows
    c.put(cx - 3 + 1, ey + 1, shade(skin, 0.9)); c.put(cx + 1 + 1, ey + 1, shade(skin, 0.9)) if old else None
    c.put(cx, hy + 1, shade(skin, 0.80))                                                                     # the nose, shaded on its lower side
    c.put(cx - 1, hy + 2, shade(skin, 0.88))
    lip = hexc('a85a50') if female else shade(skin, 0.62)
    c.hline(cx - 1, cx + 1, hy + 3, lip)
    if old:
        c.put(cx - 3, hy + 1, shade(skin, 0.78)); c.put(cx + 3, hy + 1, shade(skin, 0.7))                     # lines
    if female and not child and spec['jewel']:
        c.put(int(cx - hr) - 0, hy + 2, hexc('f0e0a0')); c.put(int(cx + hr), hy + 2, hexc('f0e0a0'))          # earrings
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
        c.ellipse(cx, top + 1, hr + 0.5, 2.4, hair)
        c.ellipse(cx, top - 2, 2.2, 2.0, hair)
        c.vline(int(cx - hr), top + 1, hy, hair); c.vline(int(cx + hr), top + 1, hy, shade(hair, 0.8))
        c.put(cx - 1, top - 3, hl)
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
        gl = hexc('7a7468')
        for gx in (cx - 2, cx + 2):
            c.put(gx - 1, ey, gl); c.put(gx + 1, ey, gl); c.put(gx, ey - 1, gl); c.put(gx, ey + 1, gl)
        c.put(cx, ey, gl)
        c.put(cx - 2, ey, eye); c.put(cx + 2, ey, eye)
    # --- a dark painter's edge on the right of an oil, a soft white border-less photo curl otherwise
    if spec['kind'] == 'oil':
        for yy in range(y0, y1 + 1):
            c.put(x0, yy, shade(c.px[x0, yy], 0.8)); c.put(x1, yy, shade(c.px[x1, yy], 0.7))


def frame_kind(spec):
    return spec['frame']


def mat_for(spec):
    return hexc('ece2c8') if spec['kind'] != 'school' else hexc('f4f0e6')
