"""Placeholder ITEM ICON cards in the style of assets/Items/ (58x46, white, bold black words) — for
items added before their real icon art exists.

Run:  python3 tools/art/item_card.py            (writes every card below)
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
W, H = 58, 46

# file name -> (small top line, big bottom line)
CARDS = {
    '038 - Gun Cabinet Key.png': ('Cabinet', 'Key'),
}


def card(top, big):
    im = Image.new('RGBA', (W, H), (255, 255, 255, 255))
    d = ImageDraw.Draw(im)
    for text, size, y in ((top, 11, 4), (big, 17, 19)):
        f = ImageFont.truetype(FONT, size)
        while d.textlength(text, font=f) > W - 2 and size > 6:
            size -= 1
            f = ImageFont.truetype(FONT, size)
        x = (W - d.textlength(text, font=f)) / 2
        d.text((x, y), text, font=f, fill=(20, 20, 20, 255))
    return im


if __name__ == '__main__':
    for name, (top, big) in CARDS.items():
        p = os.path.join(ROOT, 'assets', 'Items', name)
        card(top, big).save(p)
        print('wrote', p)
