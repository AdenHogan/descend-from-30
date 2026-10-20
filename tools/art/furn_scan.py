#!/usr/bin/env python3
"""SCAN the furniture library for pieces that look wrong (owner round 47: "go through the furniture and decorations to find clear issues").

Read-only: reads data/furniture.json + assets/furniture/*.png and prints a ranked report; `--sheets DIR` also writes review contact sheets (every piece, 3x, on the wall colour it is
usually seen against) so a human can look. Nothing here changes an asset.

Automatic findings (each has a severity, 3 = egregious):
  NODE    a scavenge node that does not sit on anything drawn (it would float in the air)                         3
  SLOT    a surface slot with nothing under it (a lamp would hover)                                               3
  LIGHT   a light fixture outside its own sprite                                                                  2
  CLIP    a sprite whose rendered position at its bucket would leave the module (cut off)                         3
  SPECK   stray 1-2 px specks away from the body (render noise)                                                   2
  TINY    illegible at game size (< 7 px on its long side) and not a deliberately small thing                     2
  FLAT    almost no shading (<= 4 solid colours) on something big — reads as a painted-on slab                    2
  NOEDGE  no dark outline — it will not separate from the wall                                                    1
  BUCKET  the same piece drawn at different buckets differs wildly in height (a lean glitch)                      2
  DUP     two variants that are pixel-identical (wasted)                                                          1
  FEET    the lowest solid row is not at the piece's feet row (it floats / sinks)                                 2
  LOWCON  very low contrast against the usual wall (it disappears)                                                1
"""
import json
import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SPR = os.path.join(ROOT, 'assets', 'furniture')
DATA = os.path.join(ROOT, 'data', 'furniture.json')

SMALL_OK = ('top', 'floor')            # these are small things on purpose
WALL_COLOURS = {'adult': (88, 106, 128), 'teen': (86, 140, 146), 'sick': (176, 164, 134), 'refuge': (164, 154, 136), 'kid': (176, 196, 212)}


def load(name):
    return Image.open(os.path.join(SPR, name + '.png')).convert('RGBA')


def solid_mask(img, thresh=200):
    a = img.getchannel('A')
    w, h = img.size
    px = a.load()
    return [[px[x, y] >= thresh for x in range(w)] for y in range(h)]


def components(mask):
    h, w = len(mask), len(mask[0])
    seen = [[False] * w for _ in range(h)]
    out = []
    for y in range(h):
        for x in range(w):
            if mask[y][x] and not seen[y][x]:
                q = deque([(x, y)])
                seen[y][x] = True
                cells = []
                while q:
                    cx, cy = q.popleft()
                    cells.append((cx, cy))
                    for dx in (-2, -1, 0, 1, 2):          # a 2 px reach joins a piece to its own detached highlight
                        for dy in (-2, -1, 0, 1, 2):
                            nx, ny = cx + dx, cy + dy
                            if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                                seen[ny][nx] = True
                                q.append((nx, ny))
                out.append(cells)
    return out


def lum(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def analyse():
    data = json.load(open(DATA))
    lean_x = data['lean_x']
    finds = []

    def add(sev, code, pid, vid, msg):
        finds.append((sev, code, pid, vid, msg))

    for pid, rec in sorted(data['items'].items()):
        plane = rec['plane']
        vids = sorted(rec['variants'])
        digests = {}
        heights = {}
        for vid in vids:
            v = rec['variants'][vid]
            sprites = v['sprites']
            for si, info in enumerate(sprites):
                img = load(info['file'])
                w, h = img.size
                mask = solid_mask(img)
                n_solid = sum(sum(1 for c in row if c) for row in mask)
                tag = vid if len(sprites) == 1 else '%s@b%d' % (vid, round(lean_x.index(info['bx']))) if 'bx' in info and info['bx'] in lean_x else vid
                # TINY
                if max(w, h) < 7 and plane not in ('top',) and not (plane == 'floor' and rec['w'] <= 12):
                    add(2, 'TINY', pid, tag, '%dx%d' % (w, h))
                elif plane == 'top' and max(w, h) < 5:
                    add(2, 'TINY', pid, tag, '%dx%d (a top item)' % (w, h))
                # SPECK: components of <= 2 px whose nearest big component is > 3 px away
                comps = components(mask)
                if len(comps) > 1:
                    comps.sort(key=len, reverse=True)
                    main = set(comps[0])
                    specks = [c for c in comps[1:] if len(c) <= 2]
                    if specks and n_solid > 40:
                        add(2, 'SPECK', pid, tag, '%d stray specks' % len(specks))
                # FLAT
                cols = set()
                for y in range(h):
                    for x in range(w):
                        if mask[y][x]:
                            cols.add(img.getpixel((x, y))[:3])
                if n_solid > 150 and len(cols) <= 4:
                    add(2, 'FLAT', pid, tag, '%d solid colours over %d px' % (len(cols), n_solid))
                # NOEDGE: boundary pixels darker than the body?
                if n_solid > 120:
                    body = [lum(img.getpixel((x, y))) for y in range(h) for x in range(w) if mask[y][x]]
                    mean = sum(body) / len(body)
                    edge = []
                    for y in range(h):
                        for x in range(w):
                            if mask[y][x]:
                                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                                    nx, ny = x + dx, y + dy
                                    if not (0 <= nx < w and 0 <= ny < h) or not mask[ny][nx]:
                                        edge.append(lum(img.getpixel((x, y))))
                                        break
                    if edge and sum(edge) / len(edge) > mean * 0.9:
                        add(1, 'NOEDGE', pid, tag, 'edge luminance %.0f vs body %.0f' % (sum(edge) / len(edge), mean))
                # FEET: lowest solid row vs the reference row
                if plane in ('wall', 'front', 'floor') and n_solid > 30:
                    low = max(y for y in range(h) if any(mask[y]))
                    feet_row = info['ry']
                    if abs(low - feet_row) > 5:
                        add(2, 'FEET', pid, tag, 'lowest solid row %d, feet row %d' % (low, feet_row))
                # CLIP: the sprite at its bucket position leaves the module
                if 'bx' in info:
                    ox = round(info['bx'] - rec['w'] / 2.0)
                    left, right = ox + info['l'], ox + info['r']
                    if left < 1 or right > 318:
                        add(3, 'CLIP', pid, tag, 'x %d..%d at bucket %d' % (left, right, info['bx']))
                heights.setdefault(vid, []).append(h)
                if si == min(3, len(sprites) - 1):
                    digests.setdefault(img.tobytes(), []).append(vid)
            # NODE / SLOT / LIGHT use the centre-most sprite
            mid = sprites[min(len(sprites) - 1, len(sprites) // 2)]
            img = load(mid['file'])
            w, h = img.size
            ap = img.getchannel('A').load()

            def solid_near(px, py, r=3, thr=128):
                for dy in range(-r, r + 1):
                    for dx in range(-r, r + 1):
                        x, y = px + dx, py + dy
                        if 0 <= x < w and 0 <= y < h and ap[x, y] >= thr:
                            return True
                return False
            for a in v.get('anchors', []):
                px, py = mid['rx'] + a['dx'], mid['ry'] + a['dy']
                if plane == 'top':
                    continue
                if not solid_near(px, py):
                    add(3, 'NODE', pid, vid, '"%s" at (%d,%d) is %s' % (a['name'], a['dx'], a['dy'], 'off the sprite' if not (0 <= px < w and 0 <= py < h) else 'in empty air'))
            for s in v.get('slots', []):
                x0, x1, y = mid['rx'] + s['dx0'], mid['rx'] + s['dx1'], mid['ry'] + s['dy']
                hits = sum(1 for x in range(x0, x1 + 1) if any(0 <= x < w and 0 <= yy < h and ap[x, yy] >= 128 for yy in range(y - 1, y + 5)))
                if hits < (x1 - x0 + 1) * 0.6:
                    add(3, 'SLOT', pid, vid, 'slot "%s" x %d..%d y %d: only %d of %d columns have a surface under them' % (s['id'], s['dx0'], s['dx1'], s['dy'], hits, x1 - x0 + 1))
            for l in v.get('lights', []):
                px, py = mid['rx'] + l['dx'], mid['ry'] + l['dy']
                if not (-2 <= px < w + 2 and -2 <= py < h + 2):
                    add(2, 'LIGHT', pid, vid, 'a %s light at (%d,%d) is outside the %dx%d sprite' % (l['kind'], l['dx'], l['dy'], w, h))
        # BUCKET: heights of one variant across its buckets
        for vid, hs in heights.items():
            if len(hs) > 2 and max(hs) - min(hs) > max(6, 0.25 * max(hs)):
                add(2, 'BUCKET', pid, vid, 'heights across buckets %s' % hs)
        for k, vs in digests.items():
            if len(vs) > 1:
                add(1, 'DUP', pid, ','.join(vs), 'pixel-identical variants')
        # LOWCON against the styles' walls
        styles = list((rec.get('styles') or {'adult': 1}).keys())
        mid_v = rec['variants'][vids[0]]['sprites']
        img = load(mid_v[len(mid_v) // 2]['file'])
        mask = solid_mask(img)
        body = [img.getpixel((x, y))[:3] for y in range(img.height) for x in range(img.width) if mask[y][x]]
        if len(body) > 60 and plane in ('wall', 'front', 'floor', 'decor'):
            mean = tuple(sum(c[i] for c in body) / len(body) for i in range(3))
            for st in styles:
                wc = WALL_COLOURS.get(st)
                if wc and abs(lum(mean) - lum(wc)) < 14 and sum(abs(mean[i] - wc[i]) for i in range(3)) < 45:
                    add(1, 'LOWCON', pid, st, 'mean body colour %s ~ the %s wall %s' % (tuple(int(m) for m in mean), st, wc))
    return data, finds


def sheets(data, out_dir, scale=3):
    os.makedirs(out_dir, exist_ok=True)
    ids = sorted(data['items'])
    groups = {}
    for pid in ids:
        groups.setdefault(data['items'][pid]['plane'], []).append(pid)
    for plane, pids in groups.items():
        cells = []
        for pid in pids:
            rec = data['items'][pid]
            for vid in sorted(rec['variants'])[:3]:
                sp = rec['variants'][vid]['sprites']
                info = sp[len(sp) // 2]
                cells.append(('%s/%s' % (pid, vid), load(info['file'])))
        wall = (88, 106, 128, 255)
        cw = max(i.width for _, i in cells) * scale + 8
        ch = max(i.height for _, i in cells) * scale + 22
        cols = max(1, min(8, 1900 // cw))
        rows = (len(cells) + cols - 1) // cols
        sh = Image.new('RGBA', (cols * cw, rows * ch), wall)
        d = ImageDraw.Draw(sh)
        for k, (name, im) in enumerate(cells):
            x, y = (k % cols) * cw + 4, (k // cols) * ch + 3
            d.text((x, y), name[:34], fill=(240, 240, 225, 255))
            sh.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (x, y + 14))
        sh.save(os.path.join(out_dir, 'scan_%s.png' % plane))
    return groups


def main():
    args = sys.argv[1:]
    data, finds = analyse()
    finds.sort(key=lambda f: (-f[0], f[1], f[2]))
    if '--sheets' in args:
        sheets(data, args[args.index('--sheets') + 1])
    by = {}
    for sev, code, pid, vid, msg in finds:
        by.setdefault(pid, []).append((sev, code, vid, msg))
    print('FURNITURE SCAN: %d pieces, %d findings (%d egregious)' % (len(data['items']), len(finds), sum(1 for f in finds if f[0] >= 3)))
    for pid in sorted(by, key=lambda p: (-max(f[0] for f in by[p]), -len(by[p]), p)):
        print('\n%s  [%s, rooms %s]' % (pid, data['items'][pid]['plane'], ','.join(data['items'][pid]['rooms'])))
        seen = set()
        for sev, code, vid, msg in sorted(by[pid], key=lambda f: (-f[0], f[1])):
            key = (code, msg)
            if key in seen:
                continue
            seen.add(key)
            print('   %s %-6s %-16s %s' % ('!!!' if sev >= 3 else ('!! ' if sev == 2 else '!  '), code, vid, msg))


if __name__ == '__main__':
    main()
