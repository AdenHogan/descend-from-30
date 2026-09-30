"""Render chosen corridor props in situ (hotel corridor) at N x for review: python3 prop_review.py out.png 4 name [name...]"""
import base64, io, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import prop_lab
from PIL import Image, ImageDraw

def main(out, zoom, names):
    bd = [b for b in prop_lab.backdrops() if b['run'] == 1][0]
    bg0 = Image.open(io.BytesIO(base64.b64decode(bd['image'].split(',')[1]))).convert('RGBA')
    tiles = []
    for fn, name, seed, a, kw in prop_lab.recorded_calls():
        if name not in names:
            continue
        im, m = prop_lab.render(fn, name, seed, a, kw)
        bg = bg0.copy()
        cx = prop_lab.DOOR_SPOT_X if m['rule'] == 'door' else int(prop_lab.OPEN_SPOT_X - im.width / 2)
        bg.alpha_composite(im, (cx - prop_lab.CROP[0], prop_lab.FLOOR_Y + m['depth'] - m['contact'] - prop_lab.CROP[1]))
        x = cx - prop_lab.CROP[0]
        tiles.append((name, bg.crop((max(0, x - 6), 82, min(bg.width, x + im.width + 8), 150))))
    cw = max(t.width for _, t in tiles); ch = max(t.height for _, t in tiles)
    cols = min(3, len(tiles)); rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * cw, rows * (ch + 10)), (30, 30, 30, 255)); d = ImageDraw.Draw(sheet)
    for i, (n, t) in enumerate(tiles):
        x, y = (i % cols) * cw, (i // cols) * (ch + 10)
        sheet.paste(t, (x, y)); d.text((x + 2, y + ch), n, fill=(230, 230, 230, 255))
    sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.NEAREST).save(out)

if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]), set(sys.argv[3:]))
