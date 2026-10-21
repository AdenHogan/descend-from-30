#!/usr/bin/env python3
"""Build the furniture library: sprites -> assets/furniture, records -> data/furniture.json, contact sheets -> docs/art_reference/furniture.

    python3 tools/art/furn_build.py            build everything (and delete files no piece makes any more)
    python3 tools/art/furn_build.py --check    the GATE: the committed sprites + data/furniture.json are exactly what the pieces draw now (stale = fails)
    python3 tools/art/furn_build.py --only id  build / preview just these pieces (no writes to data/, a sheet only)
"""
import hashlib
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw

import furnlib as FL
import furn_bedroom  # noqa: F401  (registers the bedroom pieces)
import furn_bedroom_b  # noqa: F401
import furn_bedroom_c  # noqa: F401
import furn_bedroom_d  # noqa: F401
import furn_bedroom_e  # noqa: F401
import furn_props  # noqa: F401
import furn_beds  # noqa: F401
import furn_seats  # noqa: F401
import furn_dollhouse  # noqa: F401
import furn_wardrobes  # noqa: F401
import furn_props2  # noqa: F401
import furn_medical  # noqa: F401
import furn_more  # noqa: F401
import furn_case  # noqa: F401
import furn_kids  # noqa: F401
import furn_toys  # noqa: F401
import furn_floor  # noqa: F401
import furn_walls  # noqa: F401
import furn_clocks  # noqa: F401
import furn_kitchen  # noqa: F401
import furn_kitchen_small  # noqa: F401
import furn_living  # noqa: F401
import furn_living2  # noqa: F401
import furn_living_small  # noqa: F401
import furn_dining  # noqa: F401
import furn_study  # noqa: F401
import furn_bathroom  # noqa: F401
import furn_desk  # noqa: F401
import furn_styles
import furn_rooms

for _m in [m for m in os.environ.get('FURN_EXTRA', '').split(',') if m]:                  # pieces written but not built into the library yet (dining / study / bathroom), for previews
    __import__(_m)
furn_styles.apply()

PIECE_MODULES = ('furn_bedroom',)


def build_all(only=None):
    data = {'version': 1, 'lean_x': list(FL.LEAN_X), 'lean_mode': FL.LEAN_MODE, 'rules': furn_rooms.rules(), 'recipes': furn_rooms.built_recipes(), 'items': {}}
    files = {}
    for pid, pc in FL.REGISTRY.items():
        if only and pid not in only:
            continue
        rec, f = FL.build_piece(pc)
        data['items'][pid] = rec
        files.update(f)
    return data, files


def _json(data):
    return json.dumps(data, indent=1, sort_keys=True) + '\n'


def _png_bytes(img):
    b = io.BytesIO()
    img.save(b, format='PNG')
    return b.getvalue()


MAX_SHEET_H = 30000


def sheet(files, path, data=None, per_piece_variants=2, buckets=(0, 3, 6), scale=3, bg=(95, 106, 120, 255), full=False):
    """A contact sheet: per piece the first and last variants (`per_piece_variants`), and for a leaning piece the far-left / centre / far-right buckets."""
    keep = []
    if data is None or full:
        keep = sorted(n for n in files if not n.startswith('open/'))
    else:
        for pid, rec in data['items'].items():
            vids = list(rec['variants'].keys())
            if len(vids) > per_piece_variants:
                step = max(1, (len(vids) - 1) // max(1, per_piece_variants - 1))
                vids = vids[::step][:per_piece_variants]
            for vid in vids:
                sp = rec['variants'][vid]['sprites']
                for k, info in enumerate(sp):
                    if len(sp) == 1 or k in buckets:
                        keep.append(info['file'] + '.png')
    cells = [(n, files[n]) for n in keep if n in files]
    cw = max(i.width for _, i in cells) * scale + 10
    ch = max(i.height for _, i in cells) * scale + 22
    cols = max(1, min(8, 2000 // cw))
    rows = (len(cells) + cols - 1) // cols
    page_rows = max(1, MAX_SHEET_H // ch)                                           # Godot imports docs/ too and downsizes a texture taller than 32768 px: long sheets are paged (pieces.png, pieces_2.png…)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    base, ext = os.path.splitext(path)
    pages = max(1, (rows + page_rows - 1) // page_rows)
    for pg in range(pages):
        first = pg * page_rows * cols
        chunk = cells[first:first + page_rows * cols]
        prow = (len(chunk) + cols - 1) // cols
        sh = Image.new('RGBA', (cols * cw, max(1, prow) * ch), bg)
        d = ImageDraw.Draw(sh)
        for k, (n, im) in enumerate(chunk):
            x, y = (k % cols) * cw + 5, (k // cols) * ch + 4
            d.text((x, y), n[:-4], fill=(235, 235, 220, 255))
            sh.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (x, y + 14))
        sh.save(path if pg == 0 else '%s_%d%s' % (base, pg + 1, ext))
    k = pages + 1                                                                   # a later run with fewer pages leaves no stale page behind
    while os.path.exists('%s_%d%s' % (base, k, ext)):
        os.remove('%s_%d%s' % (base, k, ext))
        if os.path.exists('%s_%d%s.import' % (base, k, ext)):
            os.remove('%s_%d%s.import' % (base, k, ext))
        k += 1


def main():
    args = sys.argv[1:]
    only = None
    if '--only' in args:
        only = set(args[args.index('--only') + 1:])
        data, files = build_all(only)
        allv = bool(os.environ.get('FURN_ALL'))                                     # FURN_ALL=1: every variant (centre bucket) instead of the first and last
        sheet(files, os.path.join(os.environ.get('FURN_PREVIEW', FL.PREVIEW), 'only.png'), data=data, scale=int(os.environ.get('FURN_SCALE', '3')),
              per_piece_variants=999 if allv else 2, buckets=(3,) if allv else (0, 3, 6))
        print('previewed', sorted(only))
        return
    data, files = build_all()
    if '--check' in args:
        bad = []
        if not os.path.exists(FL.DATA) or open(FL.DATA).read() != _json(data):
            bad.append('data/furniture.json is stale')
        for rel, img in files.items():
            p = os.path.join(FL.SPRITES, rel)
            if not os.path.exists(p):
                bad.append('missing ' + rel)
            elif open(p, 'rb').read() != _png_bytes(img):
                bad.append('stale ' + rel)
        for rel in FL.stale_files(files.keys()):
            bad.append('orphan ' + rel)
        if bad:
            print('FURNITURE:', len(bad), 'problems; first:', bad[:6])
            sys.exit(1)
        print('FURNITURE: %d pieces, %d sprites current' % (len(data['items']), len(files)))
        return
    FL.write_files(files)
    FL.remove_stale(files.keys())
    os.makedirs(os.path.dirname(FL.DATA), exist_ok=True)
    open(FL.DATA, 'w').write(_json(data))
    sheet(files, os.path.join(FL.PREVIEW, 'pieces.png'), data=data)
    print('wrote %d pieces, %d sprites' % (len(data['items']), len(files)))


if __name__ == '__main__':
    main()
