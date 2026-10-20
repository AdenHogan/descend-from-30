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
KID_DUVETS = {'pink': (hexc('d98aa0'), hexc('b86a80'), hexc('e8a8b8')), 'blue': (hexc('7aa0c8'), hexc('5a80a8'), hexc('9ac0e0')), 'yellow': (hexc('e6c24a'), hexc('c4a032'), hexc('f0d472'))}
BOARD = (hexc('e6e0cc'), hexc('f4f0e4'), hexc('8a8270'))


def _kid_beds():
    v = {}
    for h in ('left', 'right'):
        for d in KID_DUVETS:
            v['%s_%s' % (h[0], d)] = {'head': h, 'duvet': d}
    return v


@piece('bed_kid', 79, 40, 'front', rooms={'bedroom': 5}, styles={'kid': 8}, tags=('sleeping',), variants=_kid_beds(), bucketed=True,
       anchors=({'name': 'bed_pillow', 'dx': 16, 'dy': -26, 'head_rel': True},), feet=(114, 116), near=('bedside',), note='a small bed with a teddy bear on the pillow')
def bed_kid(c, ox, oy, p):
    d = KID_DUVETS[p['duvet']]
    F.persp_bed(c, ox, ox + 78, oy, head=p['head'], head_top=76, foot_top=84, board=BOARD, duvet=d)
    hx = 16 if p['head'] == 'left' else 62                                                  # the teddy sits at the head end
    c.ellipse(ox + hx, oy - 28, 5, 5, hexc('9a6a3a')); c.ellipse(ox + hx - 4, oy - 33, 2, 2, hexc('9a6a3a'))
    c.ellipse(ox + hx + 4, oy - 33, 2, 2, hexc('9a6a3a')); c.put(ox + hx - 1, oy - 29, hexc('1e1a16')); c.put(ox + hx + 2, oy - 29, hexc('1e1a16'))
    c.ellipse(ox + hx, oy - 21, 4, 3, hexc('9a6a3a'))


def _dollhouse(c):
    BV._e_dollhouse(c)


@piece('dollhouse_table', 41, 56, 'wall', rooms={'bedroom': 4, 'living_room': 2}, styles={'kid': 8}, tags=('toy',), depth=4, surface_h=19, variants={'a': {}},
       anchors=({'name': 'dollhouse', 'dx': 20, 'dy': -25},), feet=(105, 108), note="a dolls' house on a low table: one room dark, a tiny figure in it")
def dollhouse_table(c, ox, oy, p):
    _legacy(c, _dollhouse, ox - 5, oy - 99)


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


def _horse(c):
    c.shadow(76, 121, 14, 2, 110)
    for x in range(60, 95):
        y = 121 - int(((x - 77) / 17.0) ** 2 * 6)
        c.put(x, y, F.WOOD[0]); c.put(x, y - 1, F.WOOD[1])
    c.line(68, 119, 72, 106, F.WOOD[0]); c.line(86, 119, 82, 106, F.WOOD[0])
    rrect(c, 66, 98, 88, 107, hexc('e6e0cc'), 3)
    c.poly([(84, 99), (92, 90), (96, 92), (90, 101)], hexc('e6e0cc'))
    c.put(93, 92, hexc('1e1a16'))
    c.poly([(86, 98), (90, 90), (88, 98)], hexc('8a4a2a'))
    c.rect(72, 97, 78, 99, hexc('a8322c'))


@piece('rocking_horse', 38, 20, 'floor', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8}, tags=('toy',), variants={'a': {}}, anchors=({'name': 'rocking_horse', 'dx': 17, 'dy': -19},),
       near=('sleeping',), feet=(116, 121), note='a rocking horse on its curved rockers')
def rocking_horse(c, ox, oy, p):
    _legacy(c, _horse, ox - 60, oy - 121)


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


@piece('wardrobe_small', 29, 68, 'wall', rooms={'bedroom': 4}, styles={'kid': 8}, tags=('wardrobe', 'storage'), depth=4, variants={'a': {}},
       anchors=({'name': 'small_wardrobe', 'dx': 14, 'dy': -29},), feet=(105, 108), note='a small white wardrobe with a pink pelmet')
def wardrobe_small(c, ox, oy, p):
    _legacy(c, BV._e_wardrobe, ox - 278, oy - 99)


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
