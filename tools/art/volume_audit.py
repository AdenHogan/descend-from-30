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


def main(argv):
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
