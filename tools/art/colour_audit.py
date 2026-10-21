#!/usr/bin/env python3
"""COLOUR AUDIT of the planned rooms (owner round 47h: "recheck colours to make sure furnishings and decorations aren't too garish against modules… the bathroom is a bit too pink with
the tiling and the bathtub… assess the colour wheel for pleasing colours across the board").

Composes every plan of one or more `tools/furniture_dump.tscn --out=` files onto its shell (the room exactly as the morning run draws it — the brightest, most saturated look) and
measures, per room:

  vivid      share of the room's pixels that are VIVID (saturation >= VIVID_S and value >= VIVID_V): the loud colours. A cosy-horror room is mostly muted — a little vivid is an accent,
             a lot is garish.
  hue share  the biggest share of the room's coloured pixels (saturation >= COLOUR_S) that falls in ONE 30-degree hue family: a room that is 50 % one hue (a pink bathroom: pink tiles, pink tub,
             pink basin, pink mat) is monochrome-loud, not harmonious. The 60-30-10 rule: a dominant hue ~60 %, a secondary ~30 %, an accent ~10 %.
  wall / floor   the median colour of the bare shell's wall band and floor band, so a piece can be judged against what it stands on.
  worst piece    the placed piece with the loudest saturated area (area x saturation), against the wall hue (a clash = both loud, hues 50-130 degrees apart).

    python3 tools/art/colour_audit.py plans1.json [plans2.json ...] [--sheet out.png] [--limit]

`--limit` exits 1 when a room breaks a limit (the gate does not run this; it is a tool for the art passes — `docs/FURNITURE.md` "Colour").
"""
import colorsys
import json
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw

import furn_compose as FC
import furn_preview as FP
import furnlib as FL

VIVID_S = 0.60
VIVID_V = 0.50
COLOUR_S = 0.22                  # below this a pixel is a neutral (grey, cream, plaster, wood-dark) and has no hue worth counting
LIMITS = {'vivid': 0.075, 'hue_share': 0.42}
SURFACE_LOUD = 0.36              # a shell's wall or floor: median saturation x value may not exceed this (before round 47h the avocado bathroom's lino was 0.49, the country kitchen's tile 0.39, the diner's parquet 0.40)


def hsv_image(img):
    a = np.asarray(img.convert('RGBA')).astype(np.float32) / 255.0
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    mx = a[..., :3].max(axis=-1)
    mn = a[..., :3].min(axis=-1)
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0.0)
    h = np.zeros_like(mx)
    m = d > 1e-6
    rr = (g - b) / np.maximum(d, 1e-6) % 6
    gg = (b - r) / np.maximum(d, 1e-6) + 2
    bb = (r - g) / np.maximum(d, 1e-6) + 4
    h = np.where(mx == r, rr, np.where(mx == g, gg, bb))
    h = np.where(m, h * 60.0, 0.0)
    return h, s, mx, al


def room_metrics(img):
    h, s, v, al = hsv_image(img)
    opaque = al > 0.5
    n = float(opaque.sum())
    vivid = ((s >= VIVID_S) & (v >= VIVID_V) & opaque).sum() / n
    coloured = (s >= COLOUR_S) & (v >= 0.15) & (v <= 0.97) & opaque
    nc = float(coloured.sum())
    fam = np.zeros(12)
    for k in range(12):
        lo, hi = k * 30.0, k * 30.0 + 30.0
        fam[k] = (coloured & (h >= lo) & (h < hi)).sum()
    top = int(fam.argmax())
    return {'vivid': float(vivid), 'hue_share': float(fam[top] / n), 'hue_of_coloured': float(fam[top] / max(nc, 1.0)),
            'top_hue': top * 30 + 15, 'coloured': nc / n, 'families': (fam / n).round(3).tolist()}


def median_colour(img, box):
    a = np.asarray(img.convert('RGB').crop(box)).reshape(-1, 3)
    return tuple(int(x) for x in np.median(a, axis=0))


def hue_of(rgb):
    h, s, v = colorsys.rgb_to_hsv(*[c / 255.0 for c in rgb])
    return h * 360.0, s, v


def hue_gap(a, b):
    d = abs(a - b) % 360.0
    return min(d, 360.0 - d)


def piece_stats(pl, run=1, wall=None, floor=None):
    """Per placed piece: its area-weighted saturation and mean hue — the loudest ones — and whether it BLENDS into what it stands against (same hue family, saturation and lightness as the
    wall / floor colour behind it: a pink tub on pink tile) or CLASHES with it (both loud, hues 50-130 degrees apart)."""
    out = []
    for it in pl['items']:
        if it['plane'] in ('rug', 'ceiling'):
            continue
        spr = FC._sprite(it['file'])
        h, s, v, al = hsv_image(spr)
        m = (al > 0.5)
        if m.sum() < 30:
            continue
        col = (s >= COLOUR_S) & (v >= 0.15) & m
        if col.sum() < 20:
            continue
        # the circular mean hue of the coloured pixels
        rad = np.deg2rad(h[col])
        mh = (np.rad2deg(np.arctan2(np.sin(rad).mean(), np.cos(rad).mean())) + 360.0) % 360.0
        sat, val = float(s[col].mean()), float(v[col].mean())
        rec = {'id': it['id'], 'variant': it['variant'], 'area': int(m.sum()), 'sat': sat, 'hue': float(mh), 'loud': float(((s >= VIVID_S) & (v >= VIVID_V) & m).sum()), 'blends': False, 'clash': False}
        back = floor if it['plane'] in ('floor', 'rug') else wall
        if back is not None and rec['area'] >= 500:
            bh, bs, bv = hue_of(back)
            if bs >= 0.10 and sat >= 0.10 and hue_gap(mh, bh) < 25.0 and abs(sat - bs) < 0.15 and abs(val - bv) < 0.12:
                rec['blends'] = True
            if bs >= 0.30 and sat >= 0.55 and 50.0 <= hue_gap(mh, bh) <= 130.0:
                rec['clash'] = True
        out.append(rec)
    return sorted(out, key=lambda r: -r['loud'])


def analyse(files, run=1):
    rows = []
    for fn in files:
        for pl in json.load(open(fn)):
            shell = os.path.join(FL.ROOT, 'assets', 'rooms', pl['shell'] + ('' if run == 1 else '_r%d' % run) + '.png')
            base = Image.open(shell).convert('RGBA')
            comp = FP.compose_plan(base, pl, run, False)
            m = room_metrics(comp)
            wall = median_colour(base, (6, 24, 314, 80))
            floor = median_colour(base, (6, 112, 314, 142))
            m.update({'room': pl['room'], 'style': pl['style'], 'seed': pl['seed'], 'wall': wall, 'floor': floor, 'img': comp, 'pieces': piece_stats(pl, run, wall, floor)})
            rows.append(m)
    return rows


def files_given(args):
    return any(a.endswith('.json') for a in args)


def avoid_candidates():
    """STATIC check, no plans needed: for every piece variant that can stand in a style, does its colour BLEND into what it stands against (the style's wall colour for a wall / front / decor
    piece, its floor colour for a floor piece or rug)? Returns {piece: {variant: [styles]}} for the large pieces (>= 500 px) whose colour is a CHOICE (green, teal, rose, olive upholstery —
    not the browns of wood, which a room is allowed to be full of) and that have another variant to use instead. Paste the result into furn_palette.AVOID after reading it."""
    data = json.load(open(os.path.join(FL.ROOT, 'data', 'furniture.json')))
    shells = {}
    for key, rc in data['recipes'].items():
        room, style = key.split('/')
        base = Image.open(os.path.join(FL.ROOT, 'assets', 'rooms', rc['shell'] + '.png')).convert('RGBA')
        shells[(room, style)] = (median_colour(base, (6, 24, 314, 80)), median_colour(base, (6, 112, 314, 142)))
    out = {}
    for pid, rec in data['items'].items():
        vids = sorted(rec['variants'])
        for vid in vids:
            params = rec['variants'][vid].get('params', {})
            sprites = rec['variants'][vid]['sprites']
            sp = sprites[len(sprites) // 2]
            spr = FC._sprite(sp['file'])
            h, s_, v, al = hsv_image(spr)
            m = al > 0.5
            col = (s_ >= 0.10) & (v >= 0.15) & m
            if m.sum() < 500 or col.sum() < 200:
                continue
            rad = np.deg2rad(h[col])
            mh = (np.rad2deg(np.arctan2(np.sin(rad).mean(), np.cos(rad).mean())) + 360.0) % 360.0
            sat, val = float(s_[col].mean()), float(v[col].mean())
            if 5.0 <= mh <= 50.0 and val < 0.75:
                continue                                                                      # the browns of wood and leather
            for (room, style), (wall, floor) in shells.items():
                if rec['rooms'].get(room, 0) <= 0:
                    continue
                st = rec.get('styles')
                if st is not None and style not in st:
                    continue
                f = params.get('for')
                if f is not None and style not in f:
                    continue
                if style in params.get('not', []):
                    continue
                back = floor if rec['plane'] in ('floor', 'rug') else wall
                bh, bs, bv = hue_of(back)
                if bs >= 0.10 and sat >= 0.10 and hue_gap(mh, bh) < 25.0 and abs(sat - bs) < 0.15 and abs(val - bv) < 0.12:
                    others = [o for o in vids if o != vid and (rec['variants'][o].get('params', {}).get('for') is None or style in rec['variants'][o]['params']['for'])
                              and style not in rec['variants'][o].get('params', {}).get('not', [])]
                    if others:
                        out.setdefault(pid, {}).setdefault(vid, []).append(style)
    return out


def main():
    args = sys.argv[1:]
    if '--check' in args and not files_given(args):
        loud = []
        for fn in sorted(os.listdir(os.path.join(FL.ROOT, 'assets', 'rooms'))):
            if '_shell_' in fn and fn.endswith('.png') and not any(t in fn for t in ('_floor', '_r2', '_r3', '_burnt')):
                base = Image.open(os.path.join(FL.ROOT, 'assets', 'rooms', fn)).convert('RGBA')
                for nm, box in (('wall', (6, 24, 314, 80)), ('floor', (6, 112, 314, 142))):
                    _, sat, val = hue_of(median_colour(base, box))
                    if sat * val > SURFACE_LOUD:
                        loud.append('%s %s %.2f' % (fn, nm, sat * val))
        if loud:
            print('COLOUR: a shell wall / floor is too loud (saturation x value > %.2f): %s' % (SURFACE_LOUD, '; '.join(loud)))
            sys.exit(1)
        res = avoid_candidates()
        if res:
            print('COLOUR: %d piece(s) have a variant that blends into the wall / floor of a style it can stand in — run: python3 tools/art/colour_audit.py --avoid, read it, and add it to tools/art/furn_palette.py AVOID' % len(res))
            for pid in sorted(res):
                print('   ', pid, {v: sorted(set(st)) for v, st in res[pid].items()})
            sys.exit(1)
        print('COLOUR: no large piece blends into its room (furn_palette.AVOID applied)')
        return
    if '--avoid' in args:
        res = avoid_candidates()
        for pid in sorted(res):
            print('    %r: {%s},' % (pid, ', '.join('%r: %r' % (v, sorted(set(st))) for v, st in sorted(res[pid].items()))))
        return
    sheet = args[args.index('--sheet') + 1] if '--sheet' in args else ''
    files = [a for a in args if a.endswith('.json')]
    rows = analyse(files)
    by = defaultdict(list)
    for r in rows:
        by[(r['room'], r['style'])].append(r)
    print('%-22s %6s %6s %7s %-8s %-14s %-14s  loudest pieces' % ('room/style', 'vivid', 'hue%', 'top-hue', '', 'wall(h,s,v)', 'floor(h,s,v)'))
    bad = 0
    for (room, style), rs in sorted(by.items()):
        vv = float(np.mean([r['vivid'] for r in rs]))
        hs = float(np.mean([r['hue_share'] for r in rs]))
        th = rs[0]['top_hue']
        wh, ws, wv = hue_of(rs[0]['wall'])
        fh, fs, fv = hue_of(rs[0]['floor'])
        loud = defaultdict(float)
        for r in rs:
            for p in r['pieces'][:4]:
                loud['%s/%s' % (p['id'], p['variant'])] += p['loud']
        top = sorted(loud.items(), key=lambda kv: -kv[1])[:3]
        flag = ''
        blends = sorted({'%s/%s' % (p['id'], p['variant']) for r in rs for p in r['pieces'] if p['blends']})
        clashes = sorted({'%s/%s' % (p['id'], p['variant']) for r in rs for p in r['pieces'] if p['clash']})
        if blends:
            flag += ' BLENDS(%s)' % ','.join(blends[:3])
        if clashes:
            flag += ' CLASH(%s)' % ','.join(clashes[:3])
        if vv > LIMITS['vivid']:
            flag += ' VIVID'
        if hs > LIMITS['hue_share']:
            flag += ' ONE-HUE'
        if flag:
            bad += 1
        print('%-22s %5.1f%% %5.1f%% %6d° %-8s w(%3d,%.2f,%.2f) f(%3d,%.2f,%.2f)  %s%s' % (
            '%s/%s' % (room, style), vv * 100, hs * 100, th, flag.strip(), wh, ws, wv, fh, fs, fv, ', '.join(k for k, _ in top), ''))
    if sheet:
        cells = []
        for (room, style), rs in sorted(by.items()):
            im = rs[0]['img'].resize((rs[0]['img'].width * 2, rs[0]['img'].height * 2), Image.NEAREST)
            ImageDraw.Draw(im).text((4, 2), '%s/%s  vivid %.0f%% hue %.0f%%' % (room, style, rs[0]['vivid'] * 100, rs[0]['hue_share'] * 100), fill=(255, 255, 255, 255))
            cells.append(im)
        cols = 3
        w, h = cells[0].size
        rws = (len(cells) + cols - 1) // cols
        sh = Image.new('RGBA', (cols * (w + 4), rws * (h + 4)), (16, 16, 20, 255))
        for k, c in enumerate(cells):
            sh.paste(c, ((k % cols) * (w + 4), (k // cols) * (h + 4)))
        sh.save(sheet)
        print('wrote', sheet)
    if '--limit' in args and bad:
        sys.exit(1)


if __name__ == '__main__':
    main()
