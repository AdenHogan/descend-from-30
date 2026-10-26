#!/usr/bin/env python3
"""ROOM EYE — a designer's-eye report over many planned rooms (owner round 48k: "any player should look at the room they are in and think a human designed it").

The planner's rules say what may NOT be (a bed in a kitchen). This asks the other question — does the room READ as chosen? — by measuring the things a person notices without being able to
say why: a piano with nowhere to sit, a dressing table with no stool, a TV nobody can watch, a radiator in the middle of a wall while the window stands bare, a floor lamp nowhere near a
seat, a sofa and an armchair in two loud colours that have nothing to do with each other, a stretch of bare wall a hand-span wide on one side and nothing on the other.

    godot --headless res://tools/furniture_dump.tscn -- --room=living_room --n=40 --out=/tmp/living_room.json     (once per room type)
    python3 tools/art/room_eye.py <dir with the six <room>.json files>

Prints, per room type, how many plans show each fault (a rate), with the first few seeds so a fault can be looked at. A REPORT, not a gate: the faults it finds are turned into DATA rules
(furniture_planner.gd + the piece records) and those rules are what tests/furniture_test.gd `_test_designers_eye` fails on. First run over 1200 plans (round 48k): radiators away from the window
84, a kitchen sink away from it 200 of 200, a piano with nowhere to sit 37, a dressing table with no stool 28, a floor lamp nowhere near a seat 37 — all 0 now. What is still reported is
`lopsided` (every big piece on one side) and `wide_bare_wall`, which are judgements, not rules; `loud_pieces_clash` was measured and judged on contact sheets (it reads as designed).
"""
import colorsys
import json
import os
import sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SPRITES = os.path.join(ROOT, 'assets', 'furniture')
MODULE_W = 320
WINDOW_INSET = 72
WINDOW_HALF_W = 22
BELONG_GAP = 32          # data/furniture.json rules.home.belong_gap
UNDER_WINDOW_SLACK = 10  # furniture_planner.gd UNDER_WINDOW_SLACK

SEATS = {'sofa', 'loveseat', 'armchair', 'pouf'}
SOFT = {'sofa', 'loveseat', 'armchair', 'pouf', 'rug_large', 'rug_oblong', 'bed_wood', 'bed_pine', 'bed_iron', 'bed_kid', 'mattress_floor', 'trunk'}
TVS = {'tv_wall', 'tv_crt'}


def load_sprite(name, _cache={}):
    if name in _cache:
        return _cache[name]
    from PIL import Image
    path = os.path.join(SPRITES, name + '.png')
    im = Image.open(path).convert('RGBA') if os.path.exists(path) else None
    _cache[name] = im
    return im


def colour_of(name, _cache={}):
    """(hue in degrees or None, share of the piece that is a loud colour, mean saturation of that colour). Wood browns and greys are NOT colours; a sofa in oxblood or a rug in teal is."""
    if name in _cache:
        return _cache[name]
    im = load_sprite(name)
    if im is None:
        _cache[name] = (None, 0.0, 0.0)
        return _cache[name]
    bins = [0.0] * 24
    n = 0
    loud = 0
    sat_sum = 0.0
    for (r, g, b, a) in (im.get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata()):
        if a < 200:
            continue
        n += 1
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        deg = h * 360.0
        wood = 8 <= deg <= 48 and s < 0.66
        if s < 0.34 or v < 0.30 or wood:
            continue
        loud += 1
        sat_sum += s
        bins[int(deg / 15.0) % 24] += s * v
    if n == 0 or loud == 0:
        _cache[name] = (None, 0.0, 0.0)
        return _cache[name]
    # the dominant hue: the heaviest of the bins summed with their neighbours
    best = max(range(24), key=lambda i: bins[i] + 0.5 * (bins[i - 1] + bins[(i + 1) % 24]))
    _cache[name] = (best * 15.0 + 7.5, loud / float(n), sat_sum / loud)
    return _cache[name]


def hue_gap(a, b):
    d = abs(a - b) % 360.0
    return min(d, 360.0 - d)


def span(it):
    return it['x'], it['x'] + it['w']


def centre(it):
    return it['x'] + it['w'] / 2.0


def window_x(side):
    if side == 'left':
        return WINDOW_INSET - WINDOW_HALF_W, WINDOW_INSET + WINDOW_HALF_W
    if side == 'right':
        return MODULE_W - WINDOW_INSET - WINDOW_HALF_W, MODULE_W - WINDOW_INSET + WINDOW_HALF_W
    return None


def faults(plan):
    """The list of fault names this plan shows."""
    out = []
    items = plan['items']
    ids = [it['id'] for it in items]
    by = defaultdict(list)
    for it in items:
        by[it['id']].append(it)
    room = plan['room']
    win = window_x(plan.get('window', ''))

    # --- companions: a thing that is used from a seat has one
    if 'piano_upright' in by and not any(i in by for i in ('piano_stool', 'stool_piano')):
        out.append('piano_no_stool')
    if 'dressing_table' in by and not any(i in by for i in ('stool_dressing', 'stool_low')):
        out.append('dressing_table_no_stool')
    if any(i in by for i in TVS) and not any(i in by for i in SEATS):
        out.append('tv_nobody_can_watch')
    if 'fireplace' in by and not any(i in by for i in SEATS) and room == 'living_room':
        out.append('hearth_no_seat')
    if 'lamp_floor' in by:
        seats = [it for i in SEATS for it in by.get(i, [])]
        for lamp in by['lamp_floor']:
            l0, l1 = span(lamp)
            near = any(max(0.0, max(span(s)[0] - l1, l0 - span(s)[1])) <= BELONG_GAP for s in seats)
            if not near:
                out.append('floor_lamp_far_from_a_seat')
    # --- the radiator is a window's partner: under it, or with no window to partner, anywhere
    if win is not None:
        for rad in by.get('radiator', []):
            c = centre(rad)
            if abs(c - (win[0] + win[1]) / 2.0) > UNDER_WINDOW_SLACK:
                out.append('radiator_not_under_window')
        sinks = by.get('unit_sink', []) + by.get('sink_butler', [])
        for s in sinks:
            if abs(centre(s) - (win[0] + win[1]) / 2.0) > 24:
                out.append('sink_not_under_window')
        if room == 'kitchen' and not sinks:
            out.append('kitchen_without_a_sink')
    # --- colour: the big soft furnishings of a room are one scheme
    colours = []
    for it in items:
        if it['id'] in SOFT:
            h, share, sat = colour_of(it['file'])
            if h is not None and share >= 0.30:
                colours.append((it['id'], h, share, sat))
    loud = [c for c in colours if c[3] >= 0.50 and c[2] >= 0.45]
    for i in range(len(loud)):
        for j in range(i + 1, len(loud)):
            if 45.0 <= hue_gap(loud[i][1], loud[j][1]) <= 150.0:
                out.append('loud_pieces_clash')
    hues = []
    for c in colours:
        if all(hue_gap(c[1], h) > 40.0 for h in hues):
            hues.append(c[1])
    if len(hues) >= 3:
        out.append('three_or_more_colours_in_big_pieces')
    # --- balance: not every large thing to one side, no bare hand-span of nothing between two tall things on the wall band
    big = [it for it in items if it['plane'] in ('wall', 'front') and it['w'] >= 24]
    if big:
        left = sum(it['w'] for it in big if centre(it) < MODULE_W / 2.0)
        right = sum(it['w'] for it in big if centre(it) >= MODULE_W / 2.0)
        if abs(left - right) > 0.72 * (left + right):
            out.append('lopsided')
    occ = [0] * MODULE_W
    for it in items:
        if it['plane'] in ('wall', 'front', 'decor') and it['w'] >= 14:
            for x in range(max(0, int(it['x'])), min(MODULE_W, int(it['x'] + it['w']))):
                occ[x] = 1
    if win is not None:
        for x in range(win[0], win[1] + 1):
            occ[x] = 1
    run = best_run = 0
    for x in range(8, MODULE_W - 8):
        run = run + 1 if not occ[x] else 0
        best_run = max(best_run, run)
    if best_run >= 78:
        out.append('wide_bare_wall')
    # --- duplicated things (a second laundry basket, two alarm clocks, two lava lamps)
    for pid in ('laundry_basket3d', 'laundry_basket', 'alarm_clock', 'lamp_lava'):
        if len(by.get(pid, [])) > 1:
            out.append('doubled_' + pid)
    return out


def main(argv):
    args = [a for a in argv if not a.startswith('--')]
    d = args[0] if args else '/tmp'
    total = Counter()
    n_plans = 0
    first = {}
    per_room = {}
    for room in ('bedroom', 'kitchen', 'living_room', 'dining_room', 'study', 'bathroom'):
        path = os.path.join(d, room + '.json')
        if not os.path.exists(path):
            continue
        plans = json.load(open(path))
        c = Counter()
        for pl in plans:
            fs = set(faults(pl))
            for f in fs:
                c[f] += 1
                first.setdefault((room, f), []).append((pl['style'], pl['seed']))
        per_room[room] = (len(plans), c)
        n_plans += len(plans)
        total.update(c)
    for room, (n, c) in per_room.items():
        print('%-12s %d plans' % (room, n))
        for f, k in c.most_common():
            seeds = ', '.join('%s/%d' % s for s in first[(room, f)][:3])
            print('   %-38s %4d  (%4.0f%%)   e.g. %s' % (f, k, 100.0 * k / n, seeds))
    print('\nALL ROOMS (%d plans)' % n_plans)
    for f, k in total.most_common():
        print('   %-38s %4d  (%4.0f%%)' % (f, k, 100.0 * k / n_plans))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
