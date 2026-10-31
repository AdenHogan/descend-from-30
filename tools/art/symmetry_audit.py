#!/usr/bin/env python3
"""Symmetry audit for the basins (owner round 49f, twice: "they need to be structurally looking sound on both sides, no lopsidedness. Also that bar above is clipping, move it up a bit").

`bathroom.basin3d` is built about ONE column (`basin_axis`) from integer row profiles, so its silhouette is a mirror image by construction; this tool proves it stays so. It draws
the basin into a bare transparent canvas at every wall x the planner and the baked rooms use (the seven lean buckets' centres, the baked rooms' own 36 / 37), in all three kinds
(pedestal / pink / wall-hung on brackets), and checks, from the pixels:

  * the silhouette (alpha >= 200) from the rim's widest row down to the foot (the bowl's underside for a wall-hung basin) is symmetric about the returned axis, row for row;
  * the back deck lies wholly ABOVE the rim — no deck row at or below the rim's back row, and a one-row gap or touch only (nothing painted across the rim's top).

    python3 tools/art/symmetry_audit.py            report
    python3 tools/art/symmetry_audit.py --check    exit 1 on the first asymmetric or clipping basin

In tools/run_all_tests.sh. (It reads the generator, not the PNGs, so it needs no build step; the sprites are rendered from the same call.)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bathroom as BR
import furnlib as FL
from pixlib import Canvas, hexc

KINDS = {
    'pedestal': dict(rim=70),
    'pink': dict(rim=70, porc=BR.PINK, out=BR.PINK_OUT),
    'bracket': dict(rim=66, pedestal=False, inside=hexc('b9b09a'), drip=False),
}


def wall_xs():
    xs = {36, 37}
    for xk in FL.LEAN_X:
        xs.add(int(round(xk - 46 / 2.0)) + 26)             # the planned piece: ox + 26 at each bucket
    return sorted(xs)


def audit():
    bad = []
    n = 0
    for kind, kw in KINDS.items():
        for wcx in wall_xs():
            c = Canvas(bg=(0, 0, 0, 0))
            sx, _ = BR.basin3d(c, wcx, things=None, **kw)
            g = BR.basin_rows(wcx, kw.get('rim', 70))
            px = c.px
            w, h = c.img.size
            solid = lambda x, y: 0 <= x < w and 0 <= y < h and px[x, y][3] >= 200
            y_end = g['foot'] if kind != 'bracket' else g['r_bot']
            n += 1
            if sx != g['sx']:
                bad.append('%s @%d: the returned axis %d is not the audited one %d' % (kind, wcx, sx, g['sx']))
                continue
            for y in range(g['ry'], y_end + 1):
                run = [x for x in range(w) if solid(x, y)]
                if not run:
                    bad.append('%s @%d: row %d is empty' % (kind, wcx, y))
                    break
                lo, hi = min(run), max(run)
                if lo + hi != 2 * sx:
                    bad.append('%s @%d: row %d spans %d..%d, not symmetric about %d' % (kind, wcx, y, lo, hi, sx))
                    break
            # the deck: wholly above the rim. Its under-edge is one dark row and the silhouette outline one more, so from the rim's back row + 2 down the only solid pixels left of / right of
            # the sx are the ring's own (its half-width at that row, plus the 1-px outline) — a deck row painted across the rim's top would show as solid pixels further out
            for y in range(g['r_top'] + 2, g['r_top'] + 5):
                t = (y - g['ry']) / float(g['ery'])
                ring_hw = int(round(g['erx'] * (max(0.0, 1.0 - t * t)) ** 0.5))
                far = [x for x in range(w) if solid(x, y) and abs(x - sx) > ring_hw + 2]
                if far:
                    bad.append('%s @%d: row %d (rim back row %d) has solid pixels %d px from the axis, past the ring (%d) — the deck is clipping the rim' % (kind, wcx, y, g['r_top'], abs(far[0] - sx), ring_hw))
                    break
    return n, bad


if __name__ == '__main__':
    n, bad = audit()
    if bad:
        print('symmetry audit: %d basin(s) of %d are lopsided or clip' % (len(bad), n))
        for b in bad[:12]:
            print('  ' + b)
        sys.exit(1 if '--check' in sys.argv else 0)
    print('symmetry audit: %d basins (3 kinds x %d places) symmetric, deck clear of the rim' % (n, n // 3))
