"""The opening's runners, drawn from a SKELETON: a person running in fear and a black cat, each in THREE size tiers (owner round 49c: "the
man on the ground who runs toward the building… gets weirdly smaller… strange body pixel proportions and look generally unrefined", then, on
the first hand-typed version of these, "both look mangled… we need to be accurate, and not make them look disabled and nightmarish").

Why a skeleton: typing a figure pixel by pixel put its limbs wherever the eye last left them (a stump of an arm, a leg that did not join the
hip). Here every pose is a set of JOINTS — head, shoulder, hip, elbows, hands, knees, feet; for the cat the spine, head, tail and four legs —
the limbs are two segments of one fixed length joined at a knee or an elbow, and the pose is drawn at four times the size and sampled down to
whole pixels (a cell takes the colour of the topmost part that covers most of it), so the same figure is the same figure at every tier and a
limb is always attached. The three tiers are the three sizes a figure is ever shown at (`TIERS`: chosen by the ground row it stands on —
never a drawing rescaled to a fractional size); the smallest, at the building's own plane, is still about a person's height against a 14 px
storey.

Sheet: assets/opening/figures.png + meta['figures'] = {name: {x, y, w, h}}. Names: person_<L|M|S>_<a|p1|b|p2> (a four-frame run, facing
right), person_S_pound_<a|b> (seen from behind, a fist up on the boards), cat_<L|M|S>_<a|b> (a gallop: stretched, then gathered). All
face right; the game mirrors them.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, 'assets', 'opening')

# ground rows (0 = the building's foot, 43 = the front edge): a figure standing on row >= the tier's `row` is drawn at that tier
TIERS = {'L': 28, 'M': 14, 'S': 0}
PERSON_H = {'L': 16, 'M': 13, 'S': 10}
CAT_H = {'L': 9, 'M': 8, 'S': 6}
RUN_FRAMES = ('a', 'p1', 'b', 'p2')
SS = 6                                                  # the drawing is made at this many times the size, then sampled down

PAL = {
    'hair': (40, 28, 24, 255),
    'skin': (214, 160, 126, 255),
    'skin_d': (170, 120, 92, 255),                      # the far arm
    'shirt': (204, 72, 62, 255),
    'shirt_d': (150, 50, 46, 255),                      # the far sleeve / the shaded back
    'pants': (50, 58, 92, 255),
    'pants_d': (32, 38, 64, 255),                       # the far leg
    'shoe': (24, 22, 28, 255),
    'cat': (14, 14, 18, 255),
    'cat_lit': (40, 40, 52, 255),                       # the far legs, a shade lighter than the body so they read as a second pair
    'eye': (206, 214, 84, 255),
}

# ---- the person -------------------------------------------------------------------------------------------------------------------
# Joints in a 9 x 13 box (the L tier; x right, y down, the feet at y 13). Facing right, leaning into the run. Near arm / leg = the ones
# toward the viewer. `a` = contact, the near leg reaching forward and the near arm swung back; `p1` = passing, the near leg tucked up
# under the hip; `b` = contact with the other leg forward; `p2` = passing the other way.
RUN = {
    'a': dict(head=(5.0, 2.2), neck=(4.5, 3.8), hip=(3.7, 7.5),
              n_elbow=(3.0, 6.0), n_hand=(1.9, 5.0), f_elbow=(6.1, 6.0), f_hand=(7.5, 4.9),
              n_knee=(5.4, 9.8), n_foot=(6.9, 12.7), f_knee=(2.8, 9.9), f_foot=(0.9, 11.6)),
    'p1': dict(head=(4.9, 2.3), neck=(4.4, 3.9), hip=(3.7, 7.6),
               n_elbow=(3.6, 6.5), n_hand=(5.1, 6.3), f_elbow=(3.3, 6.4), f_hand=(2.4, 7.6),
               n_knee=(5.0, 9.2), n_foot=(2.6, 10.3), f_knee=(3.9, 10.0), f_foot=(3.9, 12.7)),
    'b': dict(head=(5.0, 2.2), neck=(4.5, 3.8), hip=(3.7, 7.5),
              n_elbow=(6.1, 6.0), n_hand=(7.5, 4.9), f_elbow=(3.0, 6.0), f_hand=(1.9, 5.0),
              n_knee=(2.8, 9.9), n_foot=(0.9, 11.6), f_knee=(5.4, 9.8), f_foot=(6.9, 12.7)),
    'p2': dict(head=(4.9, 2.3), neck=(4.4, 3.9), hip=(3.7, 7.6),
               n_elbow=(3.3, 6.4), n_hand=(2.4, 7.6), f_elbow=(3.6, 6.5), f_hand=(5.1, 6.3),
               n_knee=(3.9, 10.0), n_foot=(3.9, 12.7), f_knee=(5.0, 9.2), f_foot=(2.6, 10.3)),
}


def _canvas(w, h):
    return Image.new('L', (w * SS, h * SS), 0)


def _line(d, pts, width):
    """A polyline of round-capped segments, `width` in output pixels."""
    pts = [(x * SS, y * SS) for (x, y) in pts]
    wpx = max(1, int(round(width * SS)))
    for a, b in zip(pts[:-1], pts[1:]):
        d.line([a, b], fill=255, width=wpx)
    r = wpx / 2.0
    for (x, y) in pts:
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)


def _ellipse(d, cx, cy, rx, ry):
    d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=255)


def _poly(d, pts):
    d.polygon([(x * SS, y * SS) for (x, y) in pts], fill=255)


def _sample(layers, w, h):
    """Layers = [(mask, colour)] bottom to top -> an RGBA image of whole pixels: a cell takes the topmost layer covering at least 45 % of it."""
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = img.load()
    for mask, col in layers:
        mp = mask.load()
        for y in range(h):
            for x in range(w):
                tot = 0
                for yy in range(SS):
                    for xx in range(SS):
                        tot += 1 if mp[x * SS + xx, y * SS + yy] else 0
                if tot >= 0.45 * SS * SS:
                    px[x, y] = col
    return img


def scaled(pose, k, ox=0.0):
    return {n: (p[0] * k + ox, p[1] * k) for n, p in pose.items()}


# ---- the person: HAND-PLACED pixels in the look the owner asked for (2026-11-11: "I want our people, NPCs, and player characters to be more like this" — a
# reference of chunky figures: a big mass of hair, a big soft coat, a pale face that is two dark eyes, thin legs, small dark shoes — and, of the
# old line-skeleton runner: "that pixel man… is really not what we want for this project"). Our own figure in that manner, not the reference's:
# dark hair to the shoulder, a teal coat, bare legs. Three sizes by the ground row, each placed by hand (never one drawing rescaled); the run is
# contact / passing / contact / passing; the figure at the door is seen from behind, a fist up on the boards, then the other.
P_TONES = {'H': (52, 36, 46, 255), 'h': (86, 62, 78, 255), 'F': (232, 216, 204, 255), 'E': (24, 18, 24, 255), 'C': (74, 128, 136, 255),
           'c': (56, 100, 110, 255), 'd': (40, 72, 82, 255), 'L': (190, 150, 140, 255), 'l': (150, 116, 112, 255), 'S': (20, 18, 24, 255),
           'A': (232, 216, 204, 255)}
_P_TOP = {
    'L': ['...HHHH....', '..HHHHHH...', '..HHhFFF...', '..HHFEFE...', '..HHFFFF...', '..HHhFF....', '.HHCCCCc...', '{a}CCCCCCCc{b}.', '.cCCCCCCc..',
          '..cCCCCcc..', '..dccccd...'],
    'M': ['...HHHH...', '..HHHHHH..', '..HHFEFE..', '..HHFFFF..', '..HHhFF...', '.HCCCCCc..', '{a}CCCCCCc{b}.', '.cCCCCCc..', '..dcccd...'],
    'S': ['..HHHH..', '..HFEFE.', '..HFFFF.', '..HCCCc.', '{a}CCCCCc{b}', '.cCCCCc.', '..dccd..'],
}
_P_LEGS = {
    'L': {'a': ['...Ll.L....', '..L...lL...', '.L......L..', 'SS......L..', '........SS.'],
          'p1': ['...LL......', '...Ll......', '...L.l.....', '...L.SS....', '...SS......'],
          'b': ['...lL.l....', '..l...Ll...', '.l......l..', 'SS......l..', '........SS.'],
          'p2': ['...lL......', '...lL......', '...l.L.....', '...l.SS....', '...SS......']},
    'M': {'a': ['...Ll.L...', '..L...lL..', '.L.....L..', 'SS.....SS.'], 'p1': ['...LL.....', '...Ll.....', '...L.l....', '...SSSS...'],
          'b': ['...lL.l...', '..l...Ll..', '.l.....l..', 'SS.....SS.'], 'p2': ['...lL.....', '...lL.....', '...l.L....', '...SSSS...']},
    'S': {'a': ['..L..L..', '.L....L.', 'SS....SS'], 'p1': ['...LL...', '...Ll...', '...SSS..'],
          'b': ['..l..l..', '.l....l.', 'SS....SS'], 'p2': ['...lL...', '...lL...', '...SSS..']},
}
_P_POUND = {
    'a': ['....A...', '....c...', '..HHHc..', '..HHHH..', '..HHHH..', '.cCHHCc.', '.cCCCCc.', '.cCCCCc.', '..dccd..', '..L..L..', '..L..L..', '..SS.SS.'],
    'b': ['...A....', '...c....', '..cHHH..', '..HHHH..', '..HHHH..', '.cCHHCc.', '.cCCCCc.', '.cCCCCc.', '..dccd..', '..L..L..', '..L..L..', '..SS.SS.'],
}


def _from_rows(rows, tones, what):
    w = len(rows[0])
    assert all(len(r) == w for r in rows), '%s: a ragged grid' % what
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != '.':
                px[x, y] = tones[ch]
    return im


def person(tier, frame):
    hands = ('A', 'A') if frame in ('a', 'b') else ('.', '.')                    # the arms swing out at each contact, tuck in as the legs pass
    top = [r.replace('{a}', hands[0]).replace('{b}', hands[1]) for r in _P_TOP[tier]]
    return _from_rows(top + _P_LEGS[tier][frame], P_TONES, 'person %s %s' % (tier, frame))


def pound(frame):
    return _from_rows(_P_POUND[frame], P_TONES, 'pound %s' % frame)


# ---- the cat ----------------------------------------------------------------------------------------------------------------
# Joints in a 15 x 8 box (the L tier), facing right. `a` = stretched (the fore legs reaching, the hind legs thrown back, the spine long and
# low); `b` = gathered (all four feet bunched under the body, the back arched).
# ---- the cat: HAND-PLACED pixels (owner 2026-11-11: "I hate how the cat looks and runs up towards the building and disappears"). The old cat
# was a line-skeleton galloping INTO the picture in three shrinking sizes and fading out at the door: a side-view drawing moving away from the
# viewer. Now it does what a cat does: it trots in across the front of the garden, side on (the way it is drawn), stops on the path and SITS,
# its tail flicking, and looks up when the crows go. It never leaves. One size (the front of the garden), every pixel placed by hand:
# K the coat, L the sheen along the back, D the far legs, E the eye.
CAT_TONES = {'K': PAL['cat'], 'L': (50, 50, 64, 255), 'D': (36, 36, 48, 255), 'E': PAL['eye']}
CAT_FRAMES = ('a', 'p1', 'b', 'p2', 'sit_a', 'sit_b', 'look')
_CAT_TOP = [
    '.K..........K.K.',
    'K...........KKK.',
    'K..........KKKEK',
    'K..LLLLLLLLKKKKK',
    '.KKKKKKKKKKKKKK.',
    '.KKKKKKKKKKKK...',
    '..KKKKKKKKKK....',
]
_CAT_TOP2 = ['K...........K.K.', 'K...........KKK.', '.K.........KKKEK', '.K.LLLLLLLLKKKKK'] + _CAT_TOP[4:]      # the tail's tip the other way
_CAT = {
    'a': _CAT_TOP + ['..K.D.....D.K...', '.K..D....D...K..', 'K....D...D....K.'],
    'p1': _CAT_TOP2 + ['...KD.....DK....', '...KD.....DK....', '...K.D....D.K...'],
    'b': _CAT_TOP + ['....DK...K.D....', '...D.K...K..D...', '..D...K.K....D..'],
    'p2': _CAT_TOP2 + ['...DK.....KD....', '...DK.....KD....', '...D.K....K.D...'],
    'sit_a': [
        '.....K.K..',
        '.....KKK..',
        '....KKKEK.',
        '....KKKKK.',
        '....LKKK..',
        '...LKKKK..',
        '..LKKKKK..',
        '.LKKKKDK..',
        '.KKKKKDK..',
        'KKKKKKDKKK',
    ],
    'sit_b': [
        '.....K.K..',
        '.....KKK..',
        '....KKKEK.',
        '....KKKKK.',
        '....LKKK..',
        '...LKKKK..',
        '..LKKKKK..',
        '.LKKKKDK..',
        '.KKKKKDK.K',
        'KKKKKKDKK.',
    ],
    'look': [
        '......K.KK',
        '.....KKKEK',
        '....KKKKK.',
        '....KKKK..',
        '....LKKK..',
        '...LKKKK..',
        '..LKKKKK..',
        '.LKKKKDK..',
        '.KKKKKDK..',
        'KKKKKKDKKK',
    ],
}


def cat(tier, frame):
    """The cat's drawing for `frame` (one size: `tier` is accepted for the callers that ask by ground row)."""
    rows = _CAT[frame]
    w = len(rows[0])
    assert all(len(r) == w for r in rows), 'cat %s: a ragged grid' % frame
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != '.':
                px[x, y] = CAT_TONES[ch]
    return im


# ---- the sheet ------------------------------------------------------------------------------------------------------------------
def all_sprites():
    out = {}
    for tier in PERSON_H:
        for f in RUN_FRAMES:
            out['person_%s_%s' % (tier, f)] = person(tier, f)
    for f in ('a', 'b'):
        out['person_S_pound_%s' % f] = pound(f)
    for f in CAT_FRAMES:
        out['cat_L_%s' % f] = cat('L', f)
    return out


def draw_sheet():
    spr = all_sprites()
    gap = 1
    names = sorted(spr)
    wid = sum(spr[n].width + gap for n in names)
    hei = max(spr[n].height for n in names)
    sheet = Image.new('RGBA', (wid, hei), (0, 0, 0, 0))
    meta = {}
    x = 0
    for n in names:
        im = spr[n]
        sheet.paste(im, (x, 0))
        meta[n] = {'x': x, 'y': 0, 'w': im.width, 'h': im.height}
        x += im.width + gap
    return sheet, meta


def tier_for(row):
    """Which of the three drawings a figure standing on ground row `row` uses."""
    for name in ('L', 'M'):
        if row >= TIERS[name]:
            return name
    return 'S'


def size_of(kind, row):
    """(w, h) of the figure on that row, as drawn: what the art tool's clearance check measures."""
    t = tier_for(row)
    im = cat(t, 'a') if kind == 'cat' else person(t, 'a')
    return im.width, im.height


def self_check():
    errs = []
    spr = all_sprites()
    for n, im in spr.items():
        if im.getbbox() is None:
            errs.append('%s: empty' % n)
            continue
        px = im.load()
        # a figure stands on its bottom row: something must touch it
        if not any(px[x, im.height - 1][3] for x in range(im.width)):
            errs.append('%s: nothing on the feet row' % n)
        # one connected body (an arm or a leg that does not join is exactly the "mangled" look this module exists to prevent)
        seen = set()
        todo = [(x, y) for y in range(im.height) for x in range(im.width) if px[x, y][3]][:1]
        while todo:
            x, y = todo.pop()
            if (x, y) in seen or not (0 <= x < im.width and 0 <= y < im.height) or not px[x, y][3]:
                continue
            seen.add((x, y))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    todo.append((x + dx, y + dy))
        total = sum(1 for y in range(im.height) for x in range(im.width) if px[x, y][3])
        if len(seen) != total:
            errs.append('%s: %d of its %d pixels are not joined to the body' % (n, total - len(seen), total))
    for t in PERSON_H:
        for f in RUN_FRAMES:
            if spr['person_%s_%s' % (t, f)].height != PERSON_H[t]:
                errs.append('person %s %s is not %d tall (%d)' % (t, f, PERSON_H[t], spr['person_%s_%s' % (t, f)].height))
    if not (PERSON_H['L'] > PERSON_H['M'] > PERSON_H['S'] >= 10):
        errs.append('person tiers must shrink in steps and never below 10 px (a person at the building plane)')
    return errs


if __name__ == '__main__':
    errs = self_check()
    if '--preview' in sys.argv:
        spr = all_sprites()
        out = sys.argv[sys.argv.index('--preview') + 1]
        names = sorted(spr)
        wid = sum(spr[n].width + 2 for n in names)
        hei = max(spr[n].height for n in names)
        sheet = Image.new('RGBA', (wid, hei), (74, 130, 66, 255))
        x = 0
        for n in names:
            sheet.alpha_composite(spr[n], (x, 0))
            x += spr[n].width + 2
        sheet.resize((sheet.width * 12, sheet.height * 12), Image.NEAREST).save(out)
        print('wrote', out, [n for n in names])
    if errs:
        print('\n'.join(errs))
        sys.exit(1)
