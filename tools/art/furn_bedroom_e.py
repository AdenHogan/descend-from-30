"""BEDROOM STYLE `kid` — the child's room (the old bedroom_e): a small bed with a teddy, a dolls' house on a low table, a painted toy shelf, a toy chest with its lid up, a rocking horse, a block
tower, a ball, a rag doll, a small white wardrobe, a pencilled height chart, a crayon drawing, a rainbow. Each piece its own asset."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import bedroom_variants as BV
from furnlib import piece
from pixlib import hexc, shade, rrect, pp, pbox
from furn_bedroom import _legacy

TOY_R, TOY_Y, TOY_B, TOY_G = BV.TOY_R, BV.TOY_Y, BV.TOY_B, BV.TOY_G
@piece('toy_shelf', 28, 22, 'decor', rooms={'bedroom': 5, 'living_room': 2}, styles={'kid': 8}, tags=('toy', 'shelf'), wall_y=(36, 50), limit=1,
       note='a painted shelf on brackets: blocks, a bunny, a toy car')
def toy_shelf(c, ox, oy, p):
    def shelf(l):
        BV._e_toys_wall(l)
    # draws the whole old toy wall (shelf + tower + ball); keep only the shelf rows by drawing it on a clipped canvas
    from PIL import Image
    from pixlib import Canvas
    lyr = Canvas(w=c.w, h=c.h, bg=(0, 0, 0, 0), seed=11)
    BV._e_toys_wall(lyr)
    crop = lyr.img.crop((196, 44, 226, 66))
    c.img.alpha_composite(crop, (ox, oy))
    c.px = c.img.load()


@piece('block_tower', 16, 24, 'floor', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8}, tags=('toy',), near=('toy',), feet=(106, 112), variants={'a': {}},
       note='blocks stacked against the wall, a roof block on top')
def block_tower(c, ox, oy, p):
    for i, (dx, col) in enumerate(((0, TOY_B), (5, TOY_R), (2, TOY_Y), (1, TOY_G))):
        BV._block(c, ox + dx, oy - 4 - (0 if i < 2 else 5 * (i - 1)), col)
    c.poly([(ox + 2, oy - 14), (ox + 5, oy - 19), (ox + 8, oy - 14)], TOY_R)


@piece('ball', 10, 10, 'floor', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8, 'teen': 1}, tags=('toy',), near=('toy',), feet=(106, 119), variants={'red': {}},
       note='a red ball with a white band')
def ball(c, ox, oy, p):
    c.shadow(ox + 5, oy + 1, 5, 1, 80)
    c.ellipse(ox + 5, oy - 4, 4, 4, TOY_R)
    c.hline(ox + 1, ox + 9, oy - 4, hexc('f0ead8'))
    c.put(ox + 3, oy - 6, hexc('f0a8a0'))


def _toy_chest(c, cx):
    blue, blue_lt, blue_out = hexc('7aa0c8'), hexc('9ac0e0'), hexc('3a5a78')
    d0, d1 = 8, 16
    wx0 = 160 + (cx - 14 - 160) * 100.0 / (100 + d1)
    wx1 = 160 + (cx + 14 - 160) * 100.0 / (100 + d1)
    c.shadow(cx, 117, 16, 2, 110)
    lb, lr_ = pp(wx0 + 1, 90, d0), pp(wx1 - 1, 90, d0)
    lid = [(round(lb[0]), round(lb[1]) - 11), (round(lr_[0]), round(lr_[1]) - 11), (round(lr_[0]), round(lr_[1])), (round(lb[0]), round(lb[1]))]
    c.poly(lid, hexc('5a80a8'))
    c.line(lid[0][0], lid[0][1], lid[1][0], lid[1][1], blue_out)
    c.line(lid[0][0], lid[0][1], lid[3][0], lid[3][1], blue_out)
    c.line(lid[1][0], lid[1][1], lid[2][0], lid[2][1], blue_out)
    c.hline(lid[0][0] + 2, lid[1][0] - 2, lid[0][1] + 2, hexc('6f95bd'))
    f = pbox(c, wx0, 90, wx1, 100, d0, d1, blue, hexc('2a3a4e'), shade(blue, 0.72), blue_out)
    c.hline(f['fl'][0] + 1, f['fr'][0] - 1, f['fl'][1] + 1, blue_lt)
    c.hline(f['fl'][0] + 3, f['fr'][0] - 3, f['fbl'][1] - 3, shade(blue, 0.88))
    c.rect(f['bl'][0] + 4, f['bl'][1] - 4, f['bl'][0] + 10, f['fl'][1] - 1, hexc('d9c24a'))
    c.hline(f['bl'][0] + 4, f['bl'][0] + 10, f['bl'][1] - 4, shade(hexc('d9c24a'), 1.15))
    c.ellipse(f['br'][0] - 8, f['br'][1] - 1, 3, 3, hexc('a8322c'))
    c.put(f['br'][0] - 9, f['br'][1] - 3, hexc('d8645c'))
    c.line(f['bl'][0] + 14, f['bl'][1] - 6, f['bl'][0] + 17, f['fl'][1] - 1, hexc('8a6a3a'))


@piece('toy_chest', 36, 30, 'floor', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8, 'teen': 1}, tags=('toy', 'storage'), variants={'blue': {}}, bucketed=True,
       anchors=({'name': 'toy_chest', 'dx': 18, 'dy': -10},), near=('sleeping',), feet=(116, 119), note='a blue toy chest, lid up, toys piled inside')
def toy_chest(c, ox, oy, p):
    _legacy(c, lambda l: _toy_chest(l, ox + 18), 0, oy - 117)


@piece('rag_doll', 10, 16, 'floor', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8}, tags=('toy',), variants={'a': {}}, near=('sleeping',), feet=(112, 119),
       note='a rag doll sat against the foot of the bed')
def rag_doll(c, ox, oy, p):
    c.ellipse(ox + 5, oy - 12, 2, 2, hexc('f0d8c0'))
    c.rect(ox + 3, oy - 15, ox + 7, oy - 14, hexc('c87a3a'))
    c.put(ox + 4, oy - 12, hexc('1e1a16')); c.put(ox + 6, oy - 12, hexc('1e1a16'))
    c.poly([(ox + 2, oy - 9), (ox + 8, oy - 9), (ox + 10, oy - 3), (ox, oy - 3)], hexc('7a9ad0'))
    c.put(ox, oy - 3, hexc('f0d8c0')); c.put(ox + 10, oy - 3, hexc('f0d8c0'))


@piece('ceiling_paper', 15, 22, 'ceiling', rooms={'bedroom': 3, 'living_room': 2}, styles={'kid': 8}, tags=('light', 'ceiling'), variants={'white': {}},
       lights=({'dx': 7, 'dy': 20, 'kind': 'pendant'},), note='a paper-shade pendant')
def ceiling_paper(c, ox, oy, p):
    F.pendant(c, ox + 7, 20, 'white', dome=True)


@piece('height_chart', 18, 30, 'decor', rooms={'bedroom': 4, 'living_room': 2, 'kitchen': 2}, styles={'kid': 8}, tags=('mark',), wall_y=(54, 66), limit=1,
       note='height marks pencilled on the wall, each with the age beside it, and her name at the top')
def height_chart(c, ox, oy, p):
    for (y, age) in ((27, '3'), (21, '4'), (15, '5'), (9, '6')):
        c.hline(ox, ox + 5, oy + y, hexc('4a4a4a'))
        F.text3(c, ox + 7, oy + y - 2, age, hexc('5a5a5a'))
    F.text3(c, ox, oy, 'MIA', hexc('5a5a5a'))


@piece('picture_crayon', 34, 29, 'decor', rooms={'bedroom': 5, 'kitchen': 3, 'living_room': 3}, styles={'kid': 8}, tags=('picture',), wall_y=(18, 34), limit=1,
       note='a crayon drawing in a cheap white frame')
def picture_crayon(c, ox, oy, p):
    import wallart
    wallart.picture_crayon(c, ox, oy, ox + 30, oy + 24)


@piece('poster_rainbow', 21, 27, 'decor', rooms={'bedroom': 5}, styles={'kid': 8}, tags=('poster',), wall_y=(18, 34), limit=1, note='a rainbow poster taped up')
def poster_rainbow(c, ox, oy, p):
    import wallart
    wallart.poster_rainbow(c, ox, oy, ox + 18, oy + 24)
