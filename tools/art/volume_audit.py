#!/usr/bin/env python3
"""VOLUME AUDIT — nothing in the game may be a flat drawing (owner round 48h: "We absolutely do not want any flat drawings anywhere. Even for wall art, there needs to be quality").

A flat drawing is a silhouette filled with one or two colours: a bin bag that is a black ellipse, a suitcase that is a two-colour slab, a picture that is a coloured rectangle. A solid
object is built from many tones — a lit face, a shaded face, its own shadow, the material's marks — so the cheapest honest test is how many distinct colours the sprite uses and how much
of it one colour covers. This tool measures that for every sprite it knows about and FAILS the gate when a sprite is flat and is not already on the owner-visible debt list
(data/art_flat_backlog.json). The list is a RATCHET: a new flat sprite fails, a fixed sprite still on the list fails (prune it), so the debt can only shrink.

Rules (opaque pixels only — alpha >= 200 — so a soft floor shadow never counts):
  corridor standing props (assets/corridor/decals/dressing.json)   >= 20 colours, one colour <= 36 % of the sprite, a tonal range (5th..95th percentile luminance) >= 0.25
  furniture pieces (data/furniture.json; the worst sprite of a piece)  >= 16 colours when the sprite has >= 600 opaque px, >= 12 when >= 200, >= 8 below that; one colour <= 50 %
Exempt, with the reason in EXEMPT: a MARK (a stain, a smear: flat by nature) and a clear-glass door (almost all transparent).

    python3 tools/art/volume_audit.py            # print the ranked report (flat sprites, then the backlog)
    python3 tools/art/volume_audit.py --check    # the gate: exit 1 on a new flat sprite or a stale backlog entry
    python3 tools/art/volume_audit.py --write    # rewrite the backlog from what is flat NOW (only when adding debt on purpose — say why in the commit)
    python3 tools/art/volume_audit.py --baked    # the BAKED room modules: every object in each picture below the library's bar, worst first (a report, not a gate — see below)

The baked modules are one picture each, so their objects are found by `tools/art/baked_objects.py` (what differs from the bare wall + floor, minus soft shadow, grouped by touching) while
`pixlib.finish_module` renders them, and recorded in assets/rooms/object_meta.json. `--baked` reads that, says when it is stale against the art, and ranks what is below the furniture bar.
It is NOT gated yet: a touching group (a sofa on its rug, a picture and its wall mark) counts as one object and floor marks / wall bands read as flat, so the list over-reports (round 48j:
~135 entries, a third of them false). Use it to find what to redraw next; the shared small things (lamps, plants, tins, bags, boxes, books) were redrawn at their source (tools/art/props3d.py).
"""
import json
import os
import sys
from collections import Counter

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
BACKLOG = os.path.join(ROOT, 'data', 'art_flat_backlog.json')
DECALS = os.path.join(ROOT, 'assets', 'corridor', 'decals')
FURN = os.path.join(ROOT, 'assets', 'furniture')

EXEMPT = {
    'floor_stain': 'a mark on the floor, flat by nature',
    'shower_walkin': 'a pane of clear glass: almost all of it is transparent',
}

PROP_COLOURS, PROP_DOM, PROP_RANGE = 20, 0.36, 0.25
MIN_PROPS, MIN_PIECES = 40, 150


def metrics(path):
    img = Image.open(path).convert('RGBA')
    px = img.load()
    w, h = img.size
    cols = Counter()
    lums = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 200:
                continue
            cols[(r, g, b)] += 1
            lums.append((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0)
    n = len(lums)
    if n < 20:
        return None
    lums.sort()
    return {'n': n, 'colours': len(cols), 'dom': cols.most_common(1)[0][1] / n, 'range': lums[int(n * 0.95)] - lums[int(n * 0.05)]}


def furniture_need(n):
    return 16 if n >= 600 else 12 if n >= 200 else 8


def corridor_props():
    """Every standing prop of the corridor's dressing (the ones with a floor depth), flat or not."""
    meta = json.load(open(os.path.join(DECALS, 'dressing.json')))['props']
    out = {}
    for name in sorted(meta):
        f = os.path.join(DECALS, name + '.png')
        m = metrics(f) if os.path.exists(f) else None
        if m is None:
            continue
        why = []
        if m['colours'] < PROP_COLOURS:
            why.append('%d colours (< %d)' % (m['colours'], PROP_COLOURS))
        if m['dom'] > PROP_DOM:
            why.append('one colour covers %d %%' % round(100 * m['dom']))
        if m['range'] < PROP_RANGE:
            why.append('tonal range %.2f (< %.2f)' % (m['range'], PROP_RANGE))
        out[name] = (why, m)
    if len(out) < MIN_PROPS:                                                    # a check that silently looks at nothing is not a check
        raise SystemExit('volume audit: only %d corridor props found (expected >= %d) — dressing.json moved?' % (len(out), MIN_PROPS))
    return out


def furniture_pieces():
    items = json.load(open(os.path.join(ROOT, 'data', 'furniture.json')))['items']
    out = {}
    for name, it in sorted(items.items()):
        if name in EXEMPT:
            continue
        worst = None
        for v in it['variants'].values():
            for sp in v['sprites']:
                f = os.path.join(FURN, sp['file'] + '.png')
                if not os.path.exists(f):
                    continue
                m = metrics(f)
                if m is None:
                    continue
                need = furniture_need(m['n'])
                why = []
                if m['colours'] < need:
                    why.append('%d colours (< %d)' % (m['colours'], need))
                if m['dom'] > 0.5:
                    why.append('one colour covers %d %%' % round(100 * m['dom']))
                if why and (worst is None or m['colours'] < worst[1]['colours']):
                    worst = (why, dict(m, file=sp['file']))
        if worst is not None:
            out[name] = worst
    if len(items) < MIN_PIECES:
        raise SystemExit('volume audit: only %d furniture pieces in data/furniture.json (expected >= %d)' % (len(items), MIN_PIECES))
    return out


def flat_now():
    props = {k: v for k, v in corridor_props().items() if v[0]}
    furn = furniture_pieces()
    return {'corridor_props': props, 'furniture': furn}


def load_backlog():
    if not os.path.exists(BACKLOG):
        return {'corridor_props': [], 'furniture': []}
    return json.load(open(BACKLOG))


def baked_report(sheet_dir=None):
    sys.path.insert(0, HERE)
    import math
    import baked_objects as B
    path = os.path.join(ROOT, B.META)
    if not os.path.exists(path):
        print('no %s — run tools/art/build_all.py' % B.META)
        return 1
    data = json.load(open(path))
    rows, stale = [], []
    for name in sorted(data):
        art = os.path.join(ROOT, 'assets', 'rooms', name + '.png')
        if not os.path.exists(art) or B.sha(Image.open(art).convert('RGBA')) != data[name]['sha']:
            stale.append(name)
        for o in data[name]['objects']:
            x0, y0, x1, y1 = o['bbox']
            if not B.is_flat(o) or y1 >= 119 or (y1 - y0) <= 5 or (y0 <= 6 and o['n'] < 200):      # floor mats, slivers, ceiling-edge fixtures
                continue
            deficit = max(B.need(o['n']) - o['colours'], 0) + (8 if o['dom'] > 0.5 else 0)
            rows.append((deficit * math.sqrt(o['n']), name, o))
    rows.sort(key=lambda r: -r[0])
    print('baked modules: %d, objects measured %d, below the furniture bar (floor marks and slivers left out): %d' % (len(data), sum(len(v['objects']) for v in data.values()), len(rows)))
    if stale:
        print('STALE (the art changed since object_meta.json was written — run tools/art/build_all.py): %s' % ', '.join(stale))
    for sc, name, o in rows[:60]:
        print('  %-14s %-22s n=%4d colours=%3d (need %2d) one colour %2d%%, range %.2f' % (name, o['bbox'], o['n'], o['colours'], B.need(o['n']), round(100 * o['dom']), o['range']))
    if sheet_dir:
        baked_sheets(rows, sheet_dir)
    return 0


def baked_sheets(rows, out_dir, scale=3, width=1500, per_sheet=24):
    """Contact sheets of the flagged objects, worst first: each crop is cut from the module's finished art at `scale`, labelled with its module, box and colour count — the list to work down."""
    from PIL import ImageDraw
    os.makedirs(out_dir, exist_ok=True)
    pad = 3
    cells = []
    for sc, name, o in rows:
        x0, y0, x1, y1 = o['bbox']
        art = Image.open(os.path.join(ROOT, 'assets', 'rooms', name + '.png')).convert('RGBA')
        box = (max(0, x0 - pad), max(0, y0 - pad), min(art.width, x1 + pad + 1), min(art.height, y1 + pad + 1))
        crop = art.crop(box).resize(((box[2] - box[0]) * scale, (box[3] - box[1]) * scale), Image.NEAREST)
        cells.append((crop, '%s %s n=%d c=%d' % (name, o['bbox'], o['n'], o['colours'])))
    n_sheet = 0
    for i in range(0, len(cells), per_sheet):
        chunk = cells[i:i + per_sheet]
        x = y = row_h = 0
        placed = []
        for crop, label in chunk:
            w, h = max(crop.width, 220), crop.height + 14
            if x + w > width:
                x, y, row_h = 0, y + row_h + 6, 0
            placed.append((x, y, crop, label))
            x += w + 6
            row_h = max(row_h, h)
        sheet = Image.new('RGBA', (width, y + row_h + 6), (34, 34, 38, 255))
        d = ImageDraw.Draw(sheet)
        for (px, py, crop, label) in placed:
            d.text((px, py), label, fill=(230, 230, 120, 255))
            sheet.alpha_composite(crop, (px, py + 12))
        sheet.convert('RGB').save(os.path.join(out_dir, 'baked_%02d.png' % n_sheet))
        n_sheet += 1
    print('wrote %d contact sheet(s) of %d objects to %s' % (n_sheet, len(cells), out_dir))


def main(argv):
    if '--baked' in argv:
        return baked_report(argv[argv.index('--sheets') + 1] if '--sheets' in argv else None)
    flat = flat_now()
    back = load_backlog()
    if '--write' in argv:
        data = {'_note': 'Sprites the volume audit (tools/art/volume_audit.py) finds flat that have not been redrawn yet. A RATCHET: the gate fails on a flat sprite that is not listed AND on a listed one that is no longer flat — fix a piece, then delete its line. Never add to it to make a check pass.'}
        for k in ('corridor_props', 'furniture'):
            data[k] = sorted(flat[k])
        with open(BACKLOG, 'w') as fh:
            json.dump(data, fh, indent=1)
            fh.write('\n')
        print('wrote %s: %d corridor props, %d furniture pieces' % (BACKLOG, len(data['corridor_props']), len(data['furniture'])))
        return 0
    bad = []
    for group in ('corridor_props', 'furniture'):
        now = flat[group]
        listed = set(back.get(group, []))
        for name in sorted(set(now) - listed):
            bad.append('NEW FLAT   %-10s %-22s %s' % (group, name, '; '.join(now[name][0])))
        for name in sorted(listed - set(now)):
            bad.append('FIXED      %-10s %-22s is no longer flat — delete it from data/art_flat_backlog.json' % (group, name))
    if '--check' in argv:
        if bad:
            print('VOLUME AUDIT: %d problem(s)' % len(bad))
            for b in bad:
                print('  ' + b)
            return 1
        left = sum(len(back.get(g, [])) for g in ('corridor_props', 'furniture'))
        print('volume audit: no new flat sprites (%d on the debt list: %d corridor props, %d furniture pieces)' % (left, len(back.get('corridor_props', [])), len(back.get('furniture', []))))
        return 0
    # the report
    for group in ('corridor_props', 'furniture'):
        now = flat[group]
        print('\n== %s — %d flat' % (group, len(now)))
        for name, (why, m) in sorted(now.items(), key=lambda kv: kv[1][1]['colours']):
            tag = '' if name in set(back.get(group, [])) else '  <-- NOT on the backlog'
            print('  %-24s %3d colours, %2d%% one colour, range %.2f  (%s)%s' % (name, m['colours'], round(100 * m['dom']), m['range'], '; '.join(why), tag))
    for b in bad:
        print(b)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
