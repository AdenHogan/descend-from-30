"""THE BEDROOM PIECES — every piece of furniture and object a bedroom can hold, each its own asset (owner round 47; the system is tools/art/furnlib.py).

The five old bedroom variants (tools/art/bedroom.py + bedroom_variants.py) were five baked pictures. Their pieces live here now, separately, with the logic of where they belong:
styles `adult` (A: the faded blue-papered main bedroom), `teen` (B: posters, a desk with an old computer), `sick` (C: the sick room — an iron bedstead, a drip stand, a wheelchair),
`refuge` (D: the squat — a mattress on the floor, crates, a camping lantern, boxes), `kid` (E: the child's room — a dolls' house, a rocking horse, a toy chest). A piece lists the
styles it suits, so the planner never puts a drip stand in the child's room or a dolls' house in the squat; a piece lists the ROOMS it suits, so a bed can never turn up in a kitchen.

Each piece is `draw(c, ox, oy, p)`: its FRONT-LEFT corner at x = ox, the last row of its front face (its feet) at y = oy, `p` the variant's parameters (colourway…) plus p['open'] (0..1,
an opening piece drawn that far open). Set-back pieces ('wall' plane, depth > 0) are drawn FLAT and brought forward + leaned toward the module's middle by the kit (pixlib.setback).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
from furnlib import piece, box3, knob, foot_shadow
from pixlib import hexc, shade, mix

OUT = hexc('2a1c17')
BRASS = hexc('b09456')

# --- palettes shared by the adult room's pieces (from bedroom.py) --------------------------------------------------------------
WOOD = hexc('5d3f2c')
WOOD_DK = hexc('46301f')
WOOD_LT = hexc('71503a')
WOOD_OUT = hexc('2b1c13')


def _legacy(c, fn, dx, dy=0):
    """Run a legacy absolute-coordinate draw function shifted by (dx, dy) onto this canvas."""
    F.moved(c, fn, dx, dy)


# ================================================================================================================================ ADULT (A)
def _dressing_table_legacy(c, pal):
    """bedroom.py's dressing table (x 6..46, top 66, base 100): a mirror on it, two drawers, brass pulls. Palette-able."""
    WOOD_, WOOD_LT_, WOOD_DK_, WOOD_OUT_ = pal
    x0, x1, top, base = 6, 46, 66, 100
    c.shadow(26, base, 20, 2, 90)
    c.box(12, 30, 40, 63, WOOD_, WOOD_OUT_)
    MIRROR, MIRROR_DK, MIRROR_HI = hexc('8b9aa0'), hexc('6c7a80'), hexc('b8c3c4')
    c.rect(14, 32, 38, 61, MIRROR)
    c.dither(14, 50, 38, 61, MIRROR_DK, 0.5)
    c.line(16, 58, 24, 34, MIRROR_HI)
    c.line(18, 59, 26, 35, MIRROR_HI)
    c.line(27, 44, 36, 58, shade(MIRROR, 0.8))
    c.line(27, 44, 31, 40, shade(MIRROR, 0.8))
    c.rect(x0 - 1, top, x1 + 1, top + 2, WOOD_LT_)
    c.hline(x0 - 1, x1 + 1, top, shade(WOOD_LT_, 1.1))
    c.box(x0, top + 3, x1, base - 1, WOOD_, WOOD_OUT_)
    for (ry0, ry1) in ((top + 5, top + 13), (top + 15, top + 23)):
        c.box(x0 + 2, ry0, x1 - 2, ry1, WOOD_, WOOD_DK_)
        c.hline(x0 + 3, x1 - 3, ry0 + 1, WOOD_LT_)
        c.rect(24, (ry0 + ry1) // 2, 28, (ry0 + ry1) // 2, BRASS)
    c.rect(x0 + 2, base - 5, x0 + 4, base - 1, WOOD_DK_)
    c.rect(x1 - 4, base - 5, x1 - 2, base - 1, WOOD_DK_)


@piece('dressing_table', 41, 34, 'wall', rooms={'bedroom': 6}, styles={'adult': 6, 'kid': 1}, tags=('storage', 'mirror', 'dressing'), depth=5,
       variants={'dark': {'pal': (WOOD, WOOD_LT, WOOD_DK, WOOD_OUT)},
                 'light': {'pal': (hexc('8a6a4a'), hexc('a2805a'), hexc('6c5038'), hexc('3a281a'))}},
       slots=({'id': 'top', 'dx0': 24, 'dx1': 38, 'dy': -33, 'top': True, 'kinds': ('small', 'vanity')},),
       anchors=({'name': 'dressing_table', 'dx': 31, 'dy': -37, 'top': True, 'note': 'the jewellery box on the top'},),
       feet=(105, 108), note='a dressing table with a (cracked) mirror, two drawers')
def dressing_table(c, ox, oy, p):
    _legacy(c, lambda l: _dressing_table_legacy(l, p['pal']), ox - 6, oy - 99)


# --- things that stand ON a surface (slots) ------------------------------------------------------------------------------------------------------
# --- the floor -----------------------------------------------------------------------------------------------------------------------------------
CLOTH = [hexc('8a4a42'), hexc('4e5d70'), hexc('c1b69c'), hexc('5f6b4e'), hexc('7d6a8a'), hexc('2e2e33')]


# --- on the walls ---------------------------------------------------------------------------------------------------------------------------------
@piece('frame_family', 20, 24, 'decor', rooms={'bedroom': 5, 'living_room': 5, 'dining_room': 4, 'study': 3}, styles={'adult': 5, 'sick': 1, 'kid': 1}, tags=('picture',),
       variants={'seaside': {}}, wall_y=(24, 44), note='a framed family photo on a string')
def frame_family(c, ox, oy, p):
    FRAME = hexc('6b4a2c')
    FRAME_DK = hexc('3b2718')
    F.photo(c, ox, oy + 6, ox + 18, oy + 20, [(hexc('d8b89a'), hexc('4a3424'), hexc('5a7aa0'), 10), (hexc('e0c0a0'), hexc('a8783a'), hexc('b0453a'), 9),
                                              (hexc('e0c0a0'), hexc('6a4a2a'), hexc('d9c24a'), 5)], bg=hexc('b8d0dc'), ground=hexc('c9b48a'), frame=FRAME)
    c.line(ox + 9, oy, ox - 2, oy + 6, FRAME_DK)
    c.line(ox + 9, oy, ox + 20, oy + 6, FRAME_DK)


# --- the ceiling ----------------------------------------------------------------------------------------------------------------------------------
@piece('ceiling_flush', 17, 5, 'ceiling', rooms={'bedroom': 6, 'living_room': 4, 'study': 3, 'dining_room': 2, 'bathroom': 4, 'kitchen': 3}, styles=None, tags=('light', 'ceiling'),
       lights=({'dx': 0, 'dy': 4, 'kind': 'flush'},), note='a flush ceiling dome')
def ceiling_flush(c, ox, oy, p):
    F.flush_light(c, ox)


# --- the rug --------------------------------------------------------------------------------------------------------------------------------------
# ================================================================================================================================ ADULT, more pieces
WOOD_PALS = {'dark': (WOOD, WOOD_LT, WOOD_DK, WOOD_OUT), 'light': (hexc('8a6a4a'), hexc('a2805a'), hexc('6c5038'), hexc('3a281a')),
             'oak': (hexc('7a5a3a'), hexc('8e6a46'), hexc('5e4430'), hexc('2e2014'))}


@piece('chest_drawers', 44, 36, 'wall', rooms={'bedroom': 6}, styles={'adult': 5, 'teen': 3, 'sick': 2, 'kid': 2}, tags=('storage', 'drawers'), depth=5,
       variants={k: {'pal': v} for k, v in WOOD_PALS.items()},
       slots=({'id': 'top', 'dx0': 4, 'dx1': 40, 'dy': -34, 'top': True, 'kinds': ('small', 'lamp', 'vanity')},),
       anchors=({'name': 'chest_drawers', 'dx': 22, 'dy': -20},), opens={'kind': 'drawer', 'frames': 3, 'anchor': 'chest_drawers'}, feet=(105, 108),
       note='a chest of three drawers; the top one pulls out when it is searched')
def chest_drawers(c, ox, oy, p):
    F.chest(c, ox, ox + 43, oy - 35, oy + 1, p['pal'], drawers=3, open_row=0 if p['open'] > 0.3 else None)


@piece('bookcase_low', 30, 50, 'wall', rooms={'bedroom': 4, 'living_room': 5, 'study': 6}, styles={'adult': 3, 'teen': 3, 'kid': 1}, tags=('books', 'storage'), depth=5,
       variants={'dark': {'pal': WOOD_PALS['dark'], 'seed': 3}, 'light': {'pal': WOOD_PALS['light'], 'seed': 8}, 'oak': {'pal': WOOD_PALS['oak'], 'seed': 5}},
       slots=({'id': 'top', 'dx0': 3, 'dx1': 26, 'dy': -49, 'top': True, 'kinds': ('small',)},),
       anchors=({'name': 'bookcase', 'dx': 15, 'dy': -30},), feet=(105, 108), note='a low bookcase of paperbacks')
def bookcase_low(c, ox, oy, p):
    import random
    F.shelves(c, ox, ox + 29, oy - 49, oy + 1, p['pal'], (oy - 33, oy - 17, oy - 2), random.Random(p['seed']))


LAMP_PENDANTS = ('cream', 'rose', 'green', 'mustard')


@piece('ceiling_pendant', 15, 26, 'ceiling', rooms={'bedroom': 4, 'living_room': 4, 'dining_room': 5, 'study': 2, 'kitchen': 2}, styles={'adult': 4, 'kid': 3, 'sick': 1},
       variants={s: {'shade': s} for s in LAMP_PENDANTS}, tags=('light', 'ceiling'), lights=({'dx': 7, 'dy': 24, 'kind': 'pendant'},), note='a pendant on a flex')
def ceiling_pendant(c, ox, oy, p):
    F.pendant(c, ox + 7, 24, p['shade'])


# --- a chair to sit in ---------------------------------------------------------------------------------------------------------------------------------
FABRICS = {'mustard': (hexc('b08a3a'), hexc('8a6a28'), hexc('c9a24e')), 'green': (hexc('5a7a55'), hexc('42603f'), hexc('6f8f68')),
           'rose': (hexc('a85a62'), hexc('86444c'), hexc('bf7078')), 'grey': (hexc('7a7f88'), hexc('5e636c'), hexc('90959e'))}


# --- small things ---------------------------------------------------------------------------------------------------------------------------------
# --- on the floor ---------------------------------------------------------------------------------------------------------------------------------
@piece('laundry_basket', 20, 16, 'floor', rooms={'bedroom': 5, 'bathroom': 6}, styles={'adult': 3, 'teen': 3, 'kid': 2, 'sick': 1}, tags=('clutter', 'clothes'),
       variants={'blue': {'a': 1}, 'grey': {'a': 5}, 'cream': {'a': 2}}, anchors=({'name': 'laundry_basket', 'dx': 9, 'dy': -8},), near=('wardrobe', 'sleeping'), feet=(116, 121),
       note='a wicker laundry basket, clothes spilling over the rim')
def laundry_basket(c, ox, oy, p):
    cl = CLOTH[p['a']]
    c.shadow(ox + 9, oy + 1, 11, 2, 90)
    c.poly([(ox + 2, oy - 14), (ox + 6, oy - 17), (ox + 12, oy - 16), (ox + 16, oy - 13), (ox + 15, oy - 10)], cl)
    c.poly([(ox + 5, oy - 14), (ox + 10, oy - 18), (ox + 14, oy - 13)], shade(cl, 1.15))
    wick, wick_dk = hexc('a8845a'), hexc('6b4f30')
    c.poly([(ox, oy - 12), (ox + 18, oy - 12), (ox + 16, oy), (ox + 2, oy)], wick)
    c.hline(ox, ox + 18, oy - 12, shade(wick, 1.15))
    for yy in range(oy - 9, oy, 3):
        c.hline(ox + 1, ox + 17, yy, wick_dk)
    for xx in range(ox + 3, ox + 17, 4):
        c.vline(xx, oy - 11, oy - 1, shade(wick, 0.85))
    c.hline(ox + 2, ox + 16, oy + 1, hexc('2a1c17'))


# --- on the wall ----------------------------------------------------------------------------------------------------------------------------------
@piece('mirror_wall', 20, 28, 'decor', rooms={'bedroom': 5, 'bathroom': 8, 'living_room': 3, 'dining_room': 1}, styles={'adult': 4, 'sick': 1}, tags=('picture', 'mirror'),
       variants={'gilt': {'fr': hexc('b09456')}, 'dark': {'fr': hexc('4a3426')}}, wall_y=(22, 40), note='a mirror in a frame, the silvering going')
def mirror_wall(c, ox, oy, p):
    fr = p['fr']
    c.box(ox, oy + 2, ox + 17, oy + 27, fr, shade(fr, 0.4))
    c.rect(ox + 2, oy + 4, ox + 15, oy + 25, hexc('8b9aa0'))
    c.dither(ox + 2, oy + 16, ox + 15, oy + 25, hexc('6c7a80'), 0.5)
    c.line(ox + 4, oy + 22, ox + 9, oy + 6, hexc('b8c3c4'))
    c.line(ox + 6, oy + 23, ox + 11, oy + 7, hexc('b8c3c4'))
    c.line(ox + 9, oy + 2, ox + 9, oy, shade(fr, 0.5))


@piece('clock_wall', 14, 16, 'decor', rooms={'bedroom': 4, 'kitchen': 6, 'living_room': 4, 'dining_room': 3, 'study': 3}, styles={'adult': 3, 'kid': 2, 'sick': 3, 'teen': 1}, tags=('clock',),
       variants={'brass': {'rim': hexc('b09456')}, 'white': {'rim': hexc('d8d2c2')}}, wall_y=(22, 40), note='a round wall clock, stopped at the hour it all went wrong')
def clock_wall(c, ox, oy, p):
    c.ellipse(ox + 7, oy + 8, 7, 7, p['rim'])
    c.ellipse(ox + 7, oy + 8, 6, 6, hexc('e6e0cc'))
    for (dx, dy) in ((0, -5), (5, 0), (0, 5), (-5, 0)):
        c.put(ox + 7 + dx, oy + 8 + dy, hexc('3a3a3a'))
    c.line(ox + 7, oy + 8, ox + 7, oy + 4, hexc('2a2a2a'))
    c.line(ox + 7, oy + 8, ox + 10, oy + 9, hexc('2a2a2a'))
    c.put(ox + 7, oy + 8, hexc('a8322c'))


@piece('wall_shelf', 28, 18, 'decor', rooms={'bedroom': 4, 'living_room': 5, 'study': 4, 'kitchen': 3, 'dining_room': 2}, styles={'adult': 3, 'teen': 2, 'kid': 2}, tags=('shelf',),
       variants={'a': {'x': 0}, 'b': {'x': 1}}, wall_y=(30, 46), note='a bracketed shelf with a few books and an ornament')
def wall_shelf(c, ox, oy, p):
    y = oy + 14
    c.rect(ox, y, ox + 27, y + 1, hexc('8a6a4a'))
    c.hline(ox, ox + 27, y, hexc('a2805a'))
    c.hline(ox, ox + 27, y + 2, hexc('2a1c17'))
    for bx in (ox + 3, ox + 23):
        c.vline(bx, y + 3, y + 5, hexc('3a281a'))
    if p['x'] == 0:
        for i, (h, col) in enumerate(((10, F.BOOKS[1]), (12, F.BOOKS[0]), (9, F.BOOKS[2]), (11, F.BOOKS[3]))):
            c.rect(ox + 2 + i * 3, y - h, ox + 4 + i * 3, y - 1, col)
        c.poly([(ox + 18, y - 1), (ox + 20, y - 8), (ox + 23, y - 8), (ox + 25, y - 1)], hexc('7aa0a8'))
    else:
        c.ellipse(ox + 7, y - 4, 4, 4, hexc('b98c97'))
        c.rect(ox + 14, y - 9, ox + 16, y - 1, F.BOOKS[4]); c.rect(ox + 17, y - 7, ox + 19, y - 1, F.BOOKS[2]); c.rect(ox + 20, y - 8, ox + 22, y - 1, F.BOOKS[1])


# --- more pictures --------------------------------------------------------------------------------------------------------------------------------
@piece('picture_landscape', 24, 24, 'decor', rooms={'bedroom': 5, 'living_room': 6, 'dining_room': 5, 'study': 3, 'kitchen': 2}, styles={'adult': 5, 'sick': 2, 'kid': 1}, tags=('picture',),
       variants={'hills': {'water': None, 'boat': False, 'fr': hexc('6b4a2c')}, 'sea': {'water': hexc('5a7a9a'), 'boat': True, 'fr': hexc('b09456')}}, wall_y=(22, 38),
       note='a painted landscape in a frame: hills, or the sea with a sailing boat')
def picture_landscape(c, ox, oy, p):
    import wallart
    r = wallart.frame(c, ox, oy + 2, ox + 21, oy + 20, wallart.kind_for(p['fr']), mat=None, thick=1, hang='wire', lip=False)
    F.landscape(c, r[0], r[1], r[2], r[3], water=p['water'], boat=p['boat'])


@piece('picture_portrait', 22, 28, 'decor', rooms={'bedroom': 5, 'living_room': 6, 'dining_room': 5, 'study': 5}, styles={'adult': 4, 'sick': 3}, tags=('picture',),
       variants={'man': {'s': 'man'}, 'woman': {'s': 'woman'}, 'old': {'s': 'old'}, 'girl': {'s': 'girl'}}, wall_y=(20, 34), note='a portrait someone actually sat for')
def picture_portrait(c, ox, oy, p):
    F.portrait(c, ox + 3, oy + 4, ox + 16, oy + 22, sitter=p['s'], frame=hexc('6b4a2c'))


@piece('calendar_wall', 25, 36, 'decor', rooms={'bedroom': 3, 'kitchen': 7, 'study': 4, 'living_room': 2}, styles={'adult': 3, 'teen': 1, 'refuge': 2, 'sick': 1}, tags=('notice',), limit=1,
       wall_y=(28, 44), note='a wall calendar: the days crossed off in red up to the 12th — and then nothing')
def calendar_wall(c, ox, oy, p):
    F.calendar(c, ox, oy + 3, month='MAY', crossed=12, ringed=19)
