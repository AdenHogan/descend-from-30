#!/usr/bin/env python3
"""Compose the planner's plans (tools/furniture_dump.tscn --out=plans.json) onto their shells -> a contact sheet.

    python3 tools/art/furn_preview.py plans.json out.png [--cols 3] [--scale 2] [--run 1] [--nodes] [--window]
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw

import furn_compose as FC
import furnlib as FL


def main():
    args = sys.argv[1:]
    plans = json.load(open(args[0]))
    out = args[1]
    cols = int(args[args.index('--cols') + 1]) if '--cols' in args else 3
    scale = int(args[args.index('--scale') + 1]) if '--scale' in args else 2
    run = int(args[args.index('--run') + 1]) if '--run' in args else 1
    show_nodes = '--nodes' in args
    show_window = '--window' in args
    cells = []
    for pl in plans:
        shell = os.path.join(FL.ROOT, 'assets', 'rooms', pl['shell'] + ('' if run == 1 else '_r%d' % run) + '.png')
        img = Image.open(shell).convert('RGBA')
        items = [dict(i, z={'rug': 0, 'decor': 1, 'ceiling': 5, 'top': 4}.get(i['plane'], 2) * 1000 + i['z']) for i in pl['items']]
        # the plan's own order is the draw order (z = index) — keep it
        items = sorted(pl['items'], key=lambda i: i['z'])
        for k, i in enumerate(items):
            i['bucket'] = 0
        comp = compose_plan(img, pl, run, show_nodes)
        if show_window and pl.get('window'):
            d = ImageDraw.Draw(comp)
            cx = 72 if pl['window'] == 'left' else 248
            d.rectangle((cx - 22, 10, cx + 22, 66), outline=(255, 255, 0, 255))
        d = ImageDraw.Draw(comp)
        cells.append(comp.resize((comp.width * scale, comp.height * scale), Image.NEAREST))
        label = '%s/%s seed %s%s att %s' % (pl['room'], pl['style'], pl['seed'], ' FB' if pl['fallback'] else '', pl['attempt'])
        ImageDraw.Draw(cells[-1]).text((4, 2), label, fill=(255, 255, 255, 255))
    w, h = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * (w + 6), rows * (h + 6)), (20, 20, 24, 255))
    for k, c in enumerate(cells):
        sheet.paste(c, ((k % cols) * (w + 6), (k // cols) * (h + 6)))
    sheet.save(out)
    print('wrote', out, len(cells), 'plans')


def compose_plan(shell, pl, run, show_nodes):
    out = shell.copy()
    dim = {1: 1.0, 2: 0.95, 3: 0.88}.get(run, 1.0)
    for it in sorted(pl['items'], key=lambda i: i['z']):
        spr = FC._sprite(it['file'])
        if dim != 1.0:
            r, g, b, a = spr.split()
            spr = Image.merge('RGBA', (r.point(lambda v: int(v * dim)), g.point(lambda v: int(v * dim)), b.point(lambda v: int(v * dim)), a))
        out.alpha_composite(spr, (int(it['x'] - it['rx']), int(it['y'] - it['ry'])))
    if show_nodes:
        d = ImageDraw.Draw(out)
        for a in pl['anchors']:
            col = (80, 160, 255, 255) if a['bp'] else (255, 200, 40, 255)
            d.ellipse((a['x'] - 2, a['y'] - 2, a['x'] + 2, a['y'] + 2), outline=col)
        for l in pl['lights']:
            d.rectangle((l['x'] - 1, l['y'] - 1, l['x'] + 1, l['y'] + 1), outline=(255, 80, 80, 255))
    return out


if __name__ == '__main__':
    main()
