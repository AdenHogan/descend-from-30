"""Compose a furniture PLAN onto a shell — the Python twin of scripts/room_furniture.gd, for previews, blueprints and review (owner round 47).

A plan is what scripts/furniture_planner.gd returns:  {"shell": "bedroom_shell_a", "items": [{"id","variant","x","y","bucket","z", ...}], "anchors": [{"name","x","y","bp"}], ...}
x, y = where the piece's reference point R goes in module pixels (front-left corner at the feet row for wall / front / floor / top pieces; top-left for decor; the centre top for a
ceiling light). The sprites are the ones assets/furniture/ holds; data/furniture.json says where R is inside each.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw

import furnlib as FL

_DATA = None
_CACHE = {}


def data():
    global _DATA
    if _DATA is None:
        _DATA = json.load(open(FL.DATA))
    return _DATA


def _sprite(name, open_state=0):
    key = (name, open_state)
    if key not in _CACHE:
        _CACHE[key] = Image.open(os.path.join(FL.SPRITES, name + '.png')).convert('RGBA')
    return _CACHE[key]


def sprite_info(item):
    rec = data()['items'][item['id']]
    sprites = rec['variants'][item['variant']]['sprites']
    k = item.get('bucket', 0) if len(sprites) > 1 else 0
    return rec, sprites[min(k, len(sprites) - 1)]


def compose(shell, items, anchors=(), run=1, show_nodes=False, opened=()):
    """`shell` an RGBA image 320x144; returns the composed image. Items sorted by (z, y)."""
    out = shell.convert('RGBA').copy()
    dim = {1: 1.0, 2: 0.95, 3: 0.88}.get(run, 1.0)
    for it in sorted(items, key=lambda i: (i.get('z', 0), i['y'])):
        rec, info = sprite_info(it)
        spr = _sprite(info['file'])
        if it.get('id') in opened and 'open_file' in info:
            strip = _sprite(info['open_file'])
            fw = strip.width // (strip.width // spr.width)
            spr = strip.crop((strip.width - spr.width, 0, strip.width, strip.height))
        if dim != 1.0:
            r, g, b, a = spr.split()
            spr = Image.merge('RGBA', (r.point(lambda v: int(v * dim)), g.point(lambda v: int(v * dim)), b.point(lambda v: int(v * dim)), a))
        out.alpha_composite(spr, (int(it['x'] - info['rx']), int(it['y'] - info['ry'])))
    if show_nodes:
        d = ImageDraw.Draw(out)
        for a in anchors:
            col = (80, 160, 255, 255) if a.get('bp') else (255, 200, 40, 255)
            d.ellipse((a['x'] - 2, a['y'] - 2, a['x'] + 2, a['y'] + 2), outline=col)
    return out


def preview(shell_png, plan, path, scale=4, run=1, show_nodes=True):
    shell = Image.open(shell_png)
    img = compose(shell, plan['items'], plan.get('anchors', ()), run=run, show_nodes=show_nodes)
    img.resize((img.width * scale, img.height * scale), Image.NEAREST).save(path)
    return img
