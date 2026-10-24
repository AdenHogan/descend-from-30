#!/usr/bin/env python3
"""Floating-items audit (owner round 48i: "the pills are sort of suspended in the air over this dresser… We can't have floaty things. If it's an item it needs to physically
be on top of the furniture").

A 'top' piece (a lamp, a glass, a clock) stands ON a host piece's top slot. This tool takes every host variant x every top piece that may stand on it x the three places the
planner can put it along the slot (left end, middle, right end) and measures, from the rendered sprites, how many rows lie between the item's feet and the host's surface under
each of its feet columns. 0 = touching, -1 = sunk into the surface (fine), >= 1 = air.

    python3 tools/art/support_audit.py            report per host
    python3 tools/art/support_audit.py --check    exit 1 when a placement floats (median gap >= 2 rows, or a quarter of its feet over nothing)

It reads data/furniture.json + assets/furniture/*.png (so run furn_build.py first) and is in tools/run_all_tests.sh. The slot rows/columns it audits are the ones
furnlib._settle_slots measured, so a failure means the measurement, not the audit, is wrong for that host (a mirror standing behind the surface, a slot wider than the mantel...).
"""
import json
import os
import sys
from collections import Counter, defaultdict

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
D = json.load(open(os.path.join(ROOT, 'data', 'furniture.json')))['items']
_cache = {}


def img(name):
    if name not in _cache:
        im = Image.open(os.path.join(ROOT, 'assets', 'furniture', name + '.png')).convert('RGBA')
        _cache[name] = (im.load(), im.size)
    return _cache[name]


def solid(px, size, x, y, a=200):
    return 0 <= x < size[0] and 0 <= y < size[1] and px[x, y][3] >= a


def feet_cols(px, size):
    """The item's lowest solid row and the columns that touch it (or the row above)."""
    w, h = size
    low = max((y for y in range(h) for x in range(w) if px[x, y][3] >= 200), default=None)
    if low is None:
        return None, []
    return low, [x for x in range(w) if any(px[x, y][3] >= 200 for y in (low, low - 1))]


def tops_for(kinds):
    return [k for k, r in D.items() if r['plane'] == 'top' and set(r.get('on', [])) & set(kinds)]


def audit():
    rows = []
    for hk, hr in sorted(D.items()):
        for hv, hvar in hr['variants'].items():
            for sl in hvar.get('slots', []):
                if not sl.get('top'):
                    continue
                for hs in hvar['sprites']:
                    hpx, hsz = img(hs['file'])
                    for tk in tops_for(sl['kinds']):
                        tr = D[tk]
                        w = tr['w']
                        for tv, tvar in tr['variants'].items():
                            ts = tvar['sprites'][0]
                            tpx, tsz = img(ts['file'])
                            low, cols = feet_cols(tpx, tsz)
                            if low is None:
                                continue
                            for x in sorted({sl['dx0'], (sl['dx0'] + sl['dx1'] - w + 1) // 2, sl['dx1'] - w + 1}):
                                if x < sl['dx0'] or x + w - 1 > sl['dx1']:
                                    continue
                                ox_t, oy_t = x - ts['rx'], sl['dy'] - ts['ry']
                                gaps = []
                                for c in cols:
                                    hx, hy = ox_t + c + hs['rx'], oy_t + low + hs['ry']          # the feet pixel in the HOST sprite's own pixels
                                    g = 99
                                    if solid(hpx, hsz, hx, hy):
                                        g = -1
                                    else:
                                        for d in range(1, 16):
                                            if solid(hpx, hsz, hx, hy + d):
                                                g = d - 1
                                                break
                                    gaps.append(g)
                                gaps.sort()
                                rows.append((hk, hv, hs['file'], tk, tv, x, gaps[len(gaps) // 2], sum(1 for g in gaps if g == 99) / float(len(gaps))))
    return rows


def main():
    check = '--check' in sys.argv
    rows = audit()
    bad = [r for r in rows if r[6] >= 2 or r[7] >= 0.25]
    if not check:
        per = defaultdict(Counter)
        for r in rows:
            per[r[0]]['all'] += 1
            if r in bad:
                per[r[0]]['bad'] += 1
        for hk in sorted(per):
            print('  %-16s %5d placements, %4d floating' % (hk, per[hk]['all'], per[hk]['bad']))
    seen = Counter((r[0], r[1], r[3]) for r in bad)
    for (hk, hv, tk), n in sorted(seen.items())[:40]:
        print('FLOATS: %s/%s carrying %s (%d placements)' % (hk, hv, tk, n))
    print('%s support audit: %d placements, %d float' % ('FAIL' if (check and bad) else 'ok', len(rows), len(bad)))
    if check and bad:
        sys.exit(1)


if __name__ == '__main__':
    main()
