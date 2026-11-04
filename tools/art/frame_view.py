"""View baked room modules against the 240 px module frame (docs/MODULE_WIDTH.md).

    FRAME_PREVIEW=/tmp/fp FRAME_REPORT=1 python3 tools/art/living_room.py        # renders the design canvas + nodes of a room without exporting anything
    python3 tools/art/frame_view.py /tmp/fp out.png living_room living_room_b      # the picture with the frame (red), the window boxes (yellow), the nodes (red = outside the frame)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw

import pixlib as PX


def view(folder, names, out, scale=3):
    ims = []
    for n in names:
        img = Image.open(os.path.join(folder, n + '.png')).convert('RGBA')
        meta = json.load(open(os.path.join(folder, n + '.json')))
        d = ImageDraw.Draw(img)
        for (x0, y0, x1, y1) in (PX.WIN_L, PX.WIN_R):
            d.rectangle((x0, y0, x1, y1), outline=(255, 255, 0, 255))
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        d = ImageDraw.Draw(img)
        for x in (PX.PAD, PX.PAD + PX.MW):
            d.line((x * scale, 0, x * scale, img.height), fill=(255, 0, 0, 255), width=2)
        for (a, x, y, fl) in meta['anchors']:
            bp = 'bp' in fl
            c = (80, 160, 255, 255) if bp else (255, 200, 40, 255)
            inside = PX.PAD + 6 <= x <= PX.PAD + PX.MW - 6
            d.ellipse((x * scale - 6, y * scale - 6, x * scale + 6, y * scale + 6), outline=c if inside else (255, 0, 0, 255), width=3)
            d.text((x * scale + 8, y * scale - 5), a.replace('anchor_', '')[:22], fill=c)
        for (x, y, k, f) in meta['lights']:
            d.rectangle((x * scale - 3, y * scale - 3, x * scale + 3, y * scale + 3), outline=(255, 80, 80, 255))
        d.text((4, 2), '%s  (%d problems)' % (n, len(meta['errors'])), fill=(255, 255, 255, 255))
        ims.append(img)
    W = max(i.width for i in ims)
    H = sum(i.height + 4 for i in ims)
    sh = Image.new('RGBA', (W, H), (20, 20, 24, 255))
    y = 0
    for i in ims:
        sh.paste(i, (0, y))
        y += i.height + 4
    sh.convert('RGB').save(out)


if __name__ == '__main__':
    view(sys.argv[1], sys.argv[3:], sys.argv[2])
