"""Build the ART LAB page — a review bench for the owner (owner round 25: "that prop lab page sounds great").

Every standing corridor prop is re-rendered by its REAL generator (tools/art/corridor_props.py) across
16 seeds — the seed the game uses now, plus 15 others — and shown standing on crops of the real corridor
art at its true floor depth; every inventory icon (tools/art/item_icons.py output) is shown at 1x/2x/4x.
The owner marks each one Keep / Rework, picks a seed, and leaves a note; the page stores those in its
artifact database, where Claude reads them back and copies the chosen seeds into build().

Run:  python3 tools/art/prop_lab.py <out.html>
Writes one self-contained page (images inlined), from tools/art/prop_lab_page.html.
"""
import base64
import inspect
import io
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import corridor_props  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SEEDS = 16
CROP = (170, 40, 400, 192)          # corridor-local box: door 201's right half, the gap, door 329
FLOOR_Y = 160                       # the skirting / floor line (corridor local)
DOOR_SPOT_X = 201 + 27 + 3          # a "door" prop's left edge, just outside door 201's frame
OPEN_SPOT_X = 265                   # an "open" prop's centre, between the doors
BACKDROPS = [('hotel', 'Hotel (floors 21-29)', 'corridor_high_w0a', 'oak'),
             ('residential', 'Residential (11-20)', 'corridor_mid_w2a', 'cream'),
             ('institutional', 'Institutional (1-10)', 'corridor_low_w4a', 'steel')]
DOORS_LOCAL = (201, 329)            # apartment doors in the crop (live nodes in the game, centred at y 119)
DOOR_CENTRE_Y = 119
LABELS = {
    'shoe_rack': 'Shoe rack', 'shoe_tray': 'Shoe tray', 'umbrella_stand': 'Umbrella stand',
    'hall_table': 'Hall table', 'parcels': 'Parcels', 'pram': 'Pram', 'bin_bags': 'Bin bags',
    'recycling_box': 'Recycling box', 'newspapers': 'Newspapers', 'suitcase': 'Suitcase',
    'shopping_bag': 'Shopping bag', 'bicycle': 'Bicycle', 'bicycle_wrecked': 'Wrecked bicycle',
    'kids_bike': "Kid's bike", 'scooter': 'Scooter', 'plant_tall': 'Floor planter', 'plant_dead': 'Dead planter',
    'plant_fallen': 'Knocked-over planter', 'plant_stand': 'Plant on a stand',
    'plant_stand_fallen': 'Knocked-over plant stand', 'chair': 'Hall chair', 'chair_down': 'Knocked-over chair',
}


def uri(img):
    buf = io.BytesIO()
    img.save(buf, 'PNG', optimize=True)
    return 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode()


def recorded_calls():
    """Replay build() with every generator wrapped, to learn each variant's generator, seed and options."""
    calls = []
    names = [n for n in dir(corridor_props) if not n.startswith('_')]
    orig = {}
    for n in names:
        f = getattr(corridor_props, n)
        if callable(f) and getattr(f, '__module__', '') == 'corridor_props' and n != 'build' \
                and list(inspect.signature(f).parameters)[:1] == ['save']:
            orig[n] = f

            def wrap(save, name, seed, *a, _n=n, **kw):
                calls.append((_n, name, seed, a, kw))
                return orig[_n](save, name, seed, *a, **kw)
            setattr(corridor_props, n, wrap)
    try:
        corridor_props.build(lambda name, c: None)
    finally:
        for n, f in orig.items():
            setattr(corridor_props, n, f)
    return calls


def render(fn_name, name, seed, a, kw):
    got = {}
    corridor_props.META.pop(name, None)
    getattr(corridor_props, fn_name)(lambda nm, c: got.__setitem__(nm, c.img.copy()), name, seed, *a, **kw)
    return got[name], dict(corridor_props.META[name])


def props():
    out = []
    for fn_name, name, seed, a, kw in recorded_calls():
        base = name.split('__')[0]
        variant = int(name.split('__')[1]) if '__' in name else 1
        tried = [seed] + [seed + 1009 * k for k in range(1, SEEDS)]
        imgs, seeds = [], []
        meta = None
        for s in tried:                                   # keep only DIFFERENT looks (many props barely vary)
            im, m = render(fn_name, name, s, a, kw)
            meta = meta or m
            u = uri(im)
            if u not in imgs:
                imgs.append(u)
                seeds.append(s)
        opts = ', '.join('%s=%r' % kv for kv in kw.items()) + (', '.join(repr(x) for x in a))
        out.append({'key': name, 'base': base, 'label': LABELS.get(base, base.replace('_', ' ').capitalize()),
                    'variant': variant, 'generator': fn_name, 'options': opts, 'seeds': seeds, 'gameSeed': seed,
                    'rule': meta['rule'], 'depth': meta['depth'], 'contact': meta['contact'], 'images': imgs})
    return out


def backdrops():
    out = []
    for key, label, fname, door in BACKDROPS:
        strip = Image.open(os.path.join(ROOT, 'assets', 'doors', 'door_%s.png' % door)).convert('RGBA')
        fw = strip.width // 7
        leaf = strip.crop((0, 0, fw, strip.height))                 # frame 0: closed
        for run, suffix in ((1, ''), (3, '_r3')):
            p = os.path.join(ROOT, 'assets', 'corridor', fname + suffix + '.png')
            if not os.path.exists(p):
                continue
            wall = Image.open(p).convert('RGBA')
            for dx in DOORS_LOCAL:                                    # the doors are live nodes in the game
                wall.alpha_composite(leaf, (dx - fw // 2, DOOR_CENTRE_Y - leaf.height // 2))
            out.append({'key': key, 'label': label, 'run': run, 'image': uri(wall.crop(CROP))})
    return out


def icons():
    items = json.load(open(os.path.join(ROOT, 'data', 'Items.json')))['ITEMS']
    files = {}
    for f in os.listdir(os.path.join(ROOT, 'assets', 'Items')):
        if f.endswith('.png'):
            iid = f[:3]
            if f == iid + '.png' or iid not in files:
                files[iid] = f
    out = []
    for iid in sorted(items):
        if iid not in files:
            continue
        im = Image.open(os.path.join(ROOT, 'assets', 'Items', files[iid])).convert('RGBA')
        out.append({'key': iid, 'label': items[iid]['ITEM_NAME'], 'desc': items[iid]['ITEM_DESCRIPTION'],
                    'kind': items[iid]['VALUE_PROPERTY'], 'file': files[iid], 'image': uri(im)})
    return out


def main(dest):
    data = {'crop': {'x': CROP[0], 'y': CROP[1], 'w': CROP[2] - CROP[0], 'h': CROP[3] - CROP[1]},
            'floorY': FLOOR_Y, 'doorX': DOOR_SPOT_X, 'openX': OPEN_SPOT_X,
            'props': props(), 'backdrops': backdrops(), 'icons': icons()}
    page = open(os.path.join(os.path.dirname(__file__), 'prop_lab_page.html')).read()
    page = page.replace('/*LAB_DATA*/null', json.dumps(data, separators=(',', ':')))
    with open(dest, 'w') as fh:
        fh.write(page)
    print('wrote %s (%d props, %d icons, %.1f MB)' % (dest, len(data['props']), len(data['icons']),
                                                    os.path.getsize(dest) / 1e6))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'prop_lab.html')
