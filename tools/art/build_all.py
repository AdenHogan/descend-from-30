"""Rebuild EVERY room module variant (art + floor + strip + scene + previews) and the overview sheet
docs/art_reference/modules/all_variants.png (one row per room type, variants a-e across).

Run:  python3 tools/art/build_all.py
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SCRIPTS = ['balcony.py', 'bedroom.py', 'bedroom_variants.py', 'bathroom.py', 'kitchen.py', 'kitchen_variants.py',
           'living_room.py', 'living_room_variants.py', 'study.py', 'study_variants.py',
           'dining_room.py', 'dining_room_variants.py']
TYPES = ['living_room', 'bedroom', 'kitchen', 'bathroom', 'study', 'dining_room']


def main():
    for s in SCRIPTS:
        r = subprocess.run([sys.executable, os.path.join(HERE, s)], capture_output=True, text=True)
        print(r.stdout.strip())
        if r.returncode != 0:
            print(r.stderr.strip())
            sys.exit('%s failed' % s)
    from PIL import Image, ImageDraw
    sc, pad = 2, 6
    w, h = 320 * sc, 144 * sc
    sheet = Image.new('RGB', (5 * (w + pad) + pad, len(TYPES) * (h + pad + 12) + pad), (18, 18, 20))
    d = ImageDraw.Draw(sheet)
    prev = os.path.join(ROOT, 'docs', 'art_reference', 'modules')
    for r, t in enumerate(TYPES):
        for k, v in enumerate(['', '_b', '_c', '_d', '_e']):
            p = os.path.join(prev, t + v + '_x4.png')
            if not os.path.exists(p):
                continue
            im = Image.open(p).convert('RGB').resize((w, h), Image.NEAREST)
            x, y = pad + k * (w + pad), pad + r * (h + pad + 12)
            d.text((x, y), t + v, fill=(220, 210, 190))
            sheet.paste(im, (x, y + 12))
    out = os.path.join(prev, 'all_variants.png')
    sheet.save(out)
    print('wrote', out)


if __name__ == '__main__':
    main()
