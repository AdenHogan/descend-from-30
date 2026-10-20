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
       slots=({'id': 'top', 'dx0': 24, 'dx1': 38, 'dy': -33, 'top': True, 'kinds': ('small',)},),
       anchors=({'name': 'dressing_table', 'dx': 31, 'dy': -37, 'top': True, 'note': 'the jewellery box on the top'},),
       feet=(105, 108), note='a dressing table with a (cracked) mirror, two drawers')
def dressing_table(c, ox, oy, p):
    _legacy(c, lambda l: _dressing_table_legacy(l, p['pal']), ox - 6, oy - 99)


@piece('nightstand_wood', 23, 20, 'wall', rooms={'bedroom': 6}, styles={'adult': 6, 'teen': 1, 'kid': 2, 'sick': 1}, tags=('storage', 'bedside'), depth=4,
       variants={'dark': {'pal': (WOOD, WOOD_LT, WOOD_DK, WOOD_OUT), 'book': hexc('7a6a8a')},
                 'light': {'pal': (hexc('8a6a4a'), hexc('a2805a'), hexc('6c5038'), hexc('3a281a')), 'book': hexc('5a7a6a')}},
       slots=({'id': 'top', 'dx0': 4, 'dx1': 19, 'dy': -19, 'top': True, 'kinds': ('lamp', 'small')},),
       anchors=({'name': 'bedside', 'dx': 11, 'dy': -12},), opens={'kind': 'drawer', 'frames': 3, 'anchor': 'bedside'}, feet=(105, 108),
       note='a bedside table: one drawer, an open shelf with a book')
def nightstand_wood(c, ox, oy, p):
    W_, WL, WD, WO = p['pal']
    x0, x1, top, base = ox, ox + 22, oy - 19, oy + 1
    c.shadow(ox + 11, base, 12, 2, 90)
    c.rect(x0 - 1, top, x1 + 1, top + 1, WL)
    c.box(x0, top + 2, x1, base - 1, W_, WO)
    c.rect(x0 + 2, top + 13, x1 - 2, base - 2, WD)                       # the open shelf, dark
    c.rect(x0 + 4, top + 15, x0 + 9, base - 3, p['book'])                # a book lying in it
    t = p['open']
    dy = int(round(5 * t))
    if dy:
        c.rect(x0 + 2, top + 4, x1 - 2, top + 4 + dy, hexc('1c1410'))     # the dark gap the drawer came out of
    c.box(x0 + 2, top + 4 + dy, x1 - 2, top + 11 + dy, W_, WD)            # the drawer front
    c.hline(x0 + 3, x1 - 3, top + 5 + dy, WL)
    if dy:
        c.hline(x0 + 2, x1 - 2, top + 3 + dy, shade(WL, 1.1))             # its top edge catching the light
    c.rect(x0 + 9, top + 7 + dy, x0 + 13, top + 7 + dy, BRASS)


def _wardrobe_body(c, x0, x1, top, base, pal, t):
    """The adult wardrobe (bedroom.py's): a cornice, two doors, a drawer; at t > 0 the RIGHT door swings out on its hinge to show a shelf, a hat box and clothes hanging."""
    import bedroom as BR
    WA, WA_DK, WA_LT = pal
    c.shadow((x0 + x1) // 2, base, 22, 2, 100)
    c.rect(x0 - 1, top, x1 + 1, top + 3, WA_DK)
    c.hline(x0 - 1, x1 + 1, top, WA_LT)
    c.box(x0, top + 4, x1, base - 1, WA, WOOD_OUT)
    mid = (x0 + x1) // 2
    c.box(x0 + 2, top + 6, mid - 1, base - 16, WA, WA_DK)
    c.box(x0 + 5, top + 10, mid - 4, base - 20, WA, WA_DK)
    c.rect(mid - 4, (top + base) // 2 - 4, mid - 3, (top + base) // 2 - 1, BRASS)
    dw = (x1 - 2) - mid                                                 # the right door's width when closed
    if t <= 0.0:
        c.box(mid, top + 6, x1 - 2, base - 16, WA, WA_DK)
        c.box(mid + 3, top + 10, x1 - 5, base - 20, WA, WA_DK)
        c.rect(mid + 3, (top + base) // 2 - 4, mid + 4, (top + base) // 2 - 1, BRASS)
    else:
        c.rect(mid, top + 6, x1 - 2, base - 16, hexc('2c211b'))        # the dark inside
        c.hline(mid, x1 - 2, top + 16, WA_LT)                          # the shelf
        c.box(mid + 3, top + 9, mid + 13, top + 15, hexc('8f7a6a'), hexc('5f4f43'))
        rail = top + 21
        c.hline(mid + 1, x1 - 3, rail, BRASS)
        BR.hanging_clothes(c, mid, rail)
        wd = max(1, int(round(dw * (1.0 - t) ** 0.8)))                  # the leaf seen foreshortened as it swings out
        out_w = int(round(5 * t))
        c.rect(x1 - 2 - wd + 1, top + 6, x1 - 2, base - 16, WA)
        c.vline(x1 - 2 - wd + 1, top + 6, base - 16, WA_DK)
        if out_w:
            c.poly([(x1 - 1, top + 6), (x1 - 1 + out_w, top + 8), (x1 - 1 + out_w, base - 17), (x1 - 1, base - 16)], WA_LT)
    c.box(x0 + 2, base - 14, x1 - 2, base - 3, WA, WA_DK)               # the bottom drawer
    c.hline(x0 + 3, x1 - 3, base - 13, WA_LT)
    c.rect(mid - 2, base - 9, mid + 2, base - 9, BRASS)


@piece('wardrobe_wood', 35, 73, 'wall', rooms={'bedroom': 6}, styles={'adult': 6, 'kid': 1, 'sick': 1, 'teen': 1}, tags=('storage', 'wardrobe', 'tall'), depth=4,
       variants={'walnut': {'pal': (hexc('6a4a33'), hexc('533826'), hexc('7e5a3f'))}, 'oak': {'pal': (hexc('7a5a3a'), hexc('5e4430'), hexc('8e6a46'))},
                 'dark': {'pal': (hexc('4e3626'), hexc('3a281c'), hexc('62463a'))}},
       slots=({'id': 'top', 'dx0': 3, 'dx1': 31, 'dy': -72, 'top': True, 'kinds': ('big',)},),
       anchors=({'name': 'wardrobe_upper', 'dx': 24, 'dy': -53}, {'name': 'wardrobe_lower', 'dx': 17, 'dy': -9}),
       opens={'kind': 'door_h', 'frames': 3, 'anchor': 'wardrobe_upper'}, feet=(105, 108), note='a tall wardrobe: two doors and a drawer; the right door opens on clothes')
def wardrobe_wood(c, ox, oy, p):
    _wardrobe_body(c, ox, ox + 34, oy - 71, oy + 1, p['pal'], p['open'])


# --- the bed -----------------------------------------------------------------------------------------------------------------------------------
BED_WOOD = hexc('4f3526')
BED_WOOD_LT = hexc('66462f')
DUVETS = {'sage': (hexc('6d7e6a'), hexc('586855'), hexc('7f8f7a')), 'rust': (hexc('8a5040'), hexc('6e3e32'), hexc('9d6250')),
          'plum': (hexc('6a4a6a'), hexc('543a54'), hexc('7e5c7e')), 'slate': (hexc('52627a'), hexc('414e62'), hexc('64768e')),
          'mustard': (hexc('a88a3a'), hexc('866c2a'), hexc('bd9f4e'))}


def _bed_variants(head_list=('left', 'right'), duvets=('sage', 'rust', 'plum', 'slate'), under=('box', 'none')):
    v = {}
    for h in head_list:
        for d in duvets:
            for u in under:
                v['%s_%s_%s' % (h[0], d, u)] = {'head': h, 'duvet': d, 'under': u}
    return v


@piece('bed_wood', 137, 47, 'front', rooms={'bedroom': 8}, styles={'adult': 8, 'teen': 2, 'sick': 1}, tags=('sleeping',),
       variants=_bed_variants(), bucketed=True, anchors=({'name': 'bed_pillow', 'dx': 21, 'dy': -26, 'head_rel': True},
                                         {'name': 'underbed', 'dx': 74, 'dy': -4, 'if': {'under': 'box'}}),
       feet=(114, 116), near=('bedside',), note='a single wooden bed lengthwise to the wall: head either end, a duvet colour, a box under it or not')
def bed_wood(c, ox, oy, p):
    F.persp_bed(c, ox, ox + 136, oy, head=p['head'], head_top=68, foot_top=80, board=(BED_WOOD, BED_WOOD_LT, WOOD_OUT), duvet=DUVETS[p['duvet']])
    if p['under'] == 'box':
        bx = ox + 62
        c.box(bx, oy - 6, bx + 24, oy - 1, hexc('9a7a4e'), hexc('7c6140'))
        c.hline(bx + 1, bx + 23, oy - 6, shade(hexc('9a7a4e'), 1.1))


# --- things that stand ON a surface (slots) ------------------------------------------------------------------------------------------------------
@piece('lamp_table', 11, 18, 'top', rooms={'bedroom': 6, 'living_room': 5, 'study': 3, 'dining_room': 2}, styles=None, tags=('light', 'lamp'), on=('lamp',),
       variants={'cream': {'shade': 'cream'}, 'rose': {'shade': 'rose'}, 'green': {'shade': 'green'}, 'mustard': {'shade': 'mustard'}},
       lights=({'dx': 5, 'dy': -12, 'kind': 'table', 'top': True},), note='a squat table lamp')
def lamp_table(c, ox, oy, p):
    F.table_lamp(c, ox + 5, oy, shade=p['shade'], base=hexc('7b8a86'))


@piece('glass_water', 4, 5, 'top', rooms={'bedroom': 4, 'bathroom': 2, 'kitchen': 3, 'study': 1, 'living_room': 2, 'dining_room': 2}, tags=('small',), on=('small',),
       note='a glass of water')
def glass_water(c, ox, oy, p):
    c.rect(ox, oy - 3, ox + 2, oy, hexc('a9b6b7'))
    c.put(ox, oy - 3, hexc('d8e2e3'))


@piece('jewel_box', 11, 7, 'top', rooms={'bedroom': 4}, styles={'adult': 4, 'kid': 1}, tags=('small', 'dressing'), on=('small',),
       anchors=({'name': 'jewel_box', 'dx': 5, 'dy': -4},), note='a jewellery box, lid up')
def jewel_box(c, ox, oy, p):
    c.rect(ox, oy - 2, ox + 10, oy, hexc('4a3040'))
    c.poly([(ox, oy - 3), (ox + 10, oy - 3), (ox + 9, oy - 8), (ox + 1, oy - 8)], hexc('5c3c50'))
    c.hline(ox + 2, ox + 8, oy - 2, BRASS)


@piece('perfume_set', 9, 8, 'top', rooms={'bedroom': 4, 'bathroom': 3}, styles={'adult': 3, 'kid': 1}, tags=('small', 'dressing'), on=('small',), note='perfume bottles')
def perfume_set(c, ox, oy, p):
    c.rect(ox + 1, oy - 6, ox + 3, oy - 1, hexc('b98c97'))
    c.put(ox - 1, oy - 7, hexc('d4c9a9'))
    c.rect(ox + 5, oy - 4, ox + 7, oy - 1, hexc('8fa3a8'))
    c.put(ox + 6, oy - 5, hexc('d4c9a9'))


@piece('hairbrush', 9, 2, 'top', rooms={'bedroom': 3, 'bathroom': 3}, tags=('small', 'dressing'), on=('small',), note='a hairbrush')
def hairbrush(c, ox, oy, p):
    c.rect(ox, oy - 1, ox + 8, oy, hexc('3d2a1c'))
    c.hline(ox + 1, ox + 7, oy - 1, hexc('6a4a30'))


@piece('suitcase', 23, 10, 'top', rooms={'bedroom': 5, 'living_room': 1}, styles={'adult': 4, 'teen': 1, 'refuge': 3}, tags=('storage',), on=('big',),
       variants={'tan': {'col': (hexc('6b5a45'), hexc('463a2c'))}, 'blue': {'col': (hexc('44566a'), hexc('2c3a4a'))}},
       note='a suitcase on top of a wardrobe (scenery: a node up there could not be reached from the plane)')
def suitcase(c, ox, oy, p):
    a, b = p['col']
    c.box(ox, oy - 7, ox + 22, oy, a, b)
    c.rect(ox + 9, oy - 9, ox + 13, oy - 8, b)


# --- the floor -----------------------------------------------------------------------------------------------------------------------------------
CLOTH = [hexc('8a4a42'), hexc('4e5d70'), hexc('c1b69c'), hexc('5f6b4e'), hexc('7d6a8a'), hexc('2e2e33')]


@piece('clothes_pile', 32, 12, 'floor', rooms={'bedroom': 7, 'bathroom': 2}, styles=None, tags=('clutter', 'clothes'),
       variants={'blue_red': {'a': 1, 'b': 0}, 'green_grey': {'a': 3, 'b': 5}, 'plum_tan': {'a': 4, 'b': 2}}, near=('sleeping', 'wardrobe'),
       anchors=({'name': 'clothes_pile', 'dx': 12, 'dy': -4},), feet=(116, 121), note='clothes dropped on the carpet')
def clothes_pile(c, ox, oy, p):
    a, b = CLOTH[p['a']], CLOTH[p['b']]
    c.poly([(ox, oy), (ox + 8, oy - 5), (ox + 20, oy - 7), (ox + 30, oy - 3), (ox + 32, oy)], a)
    c.poly([(ox + 6, oy), (ox + 14, oy - 6), (ox + 24, oy - 4), (ox + 26, oy + 1)], b)
    c.line(ox + 10, oy - 4, ox + 22, oy - 1, shade(a, 0.8))
    c.hline(ox + 2, ox + 30, oy + 1, hexc('1a120d'))


@piece('shoes_pair', 9, 5, 'floor', rooms={'bedroom': 6, 'living_room': 2}, tags=('clutter',), variants={'pale': {'col': hexc('c1b69c')}, 'dark': {'col': hexc('3a3036')}},
       near=('sleeping',), feet=(116, 121), note='a pair of shoes')
def shoes_pair(c, ox, oy, p):
    c.rect(ox, oy - 3, ox + 3, oy, p['col'])
    c.rect(ox + 5, oy - 3, ox + 8, oy, p['col'])
    c.hline(ox, ox + 8, oy, hexc('2a1c17'))


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


@piece('frame_ghost', 17, 21, 'decor', rooms={'bedroom': 3, 'living_room': 3, 'dining_room': 2}, styles={'adult': 3}, tags=('picture', 'story'), wall_y=(24, 44),
       note="where a picture used to hang — taken when they left: the unfaded paper, a nail, a snapped string")
def frame_ghost(c, ox, oy, p):
    base = hexc('5f6a78')
    c.rect(ox, oy + 6, ox + 16, oy + 20, shade(base, 1.1))
    for (a, b, cc, d) in ((ox, oy + 6, ox + 16, oy + 6), (ox, oy + 20, ox + 16, oy + 20), (ox, oy + 6, ox, oy + 20), (ox + 16, oy + 6, ox + 16, oy + 20)):
        c.line(a, b, cc, d, shade(base, 0.9))
    c.put(ox + 8, oy, hexc('3b2718'))
    c.put(ox + 8, oy + 1, shade(hexc('3b2718'), 1.4))
    c.line(ox + 8, oy + 1, ox + 5, oy + 5, hexc('3b2718'))


# --- the ceiling ----------------------------------------------------------------------------------------------------------------------------------
@piece('ceiling_flush', 17, 5, 'ceiling', rooms={'bedroom': 6, 'living_room': 4, 'study': 3, 'dining_room': 2, 'bathroom': 4, 'kitchen': 3}, styles=None, tags=('light', 'ceiling'),
       lights=({'dx': 0, 'dy': 4, 'kind': 'flush'},), note='a flush ceiling dome')
def ceiling_flush(c, ox, oy, p):
    F.flush_light(c, ox)


# --- the rug --------------------------------------------------------------------------------------------------------------------------------------
@piece('rug_oblong', 64, 14, 'rug', rooms={'bedroom': 5, 'living_room': 5, 'study': 3, 'dining_room': 2}, styles={'adult': 3, 'kid': 3, 'teen': 2},
       variants={'mauve': {'col': hexc('8a5a62'), 'border': hexc('5e3a42')}, 'green': {'col': hexc('5e7a5a'), 'border': hexc('3c5238')}, 'blue': {'col': hexc('4e6a8a'), 'border': hexc('34485e')}},
       tags=('rug',), feet=(118, 122), note='a rug on the floor — walked over, drawn under everything')
def rug_oblong(c, ox, oy, p):
    F.rug(c, ox, ox + 63, oy - 13, oy, p['col'], p['border'], pattern=hexc('c9b48a'), fringe=hexc('c9b48a'))


# ================================================================================================================================ ADULT, more pieces
WOOD_PALS = {'dark': (WOOD, WOOD_LT, WOOD_DK, WOOD_OUT), 'light': (hexc('8a6a4a'), hexc('a2805a'), hexc('6c5038'), hexc('3a281a')),
             'oak': (hexc('7a5a3a'), hexc('8e6a46'), hexc('5e4430'), hexc('2e2014'))}


@piece('chest_drawers', 44, 36, 'wall', rooms={'bedroom': 6}, styles={'adult': 5, 'teen': 3, 'sick': 2, 'kid': 2}, tags=('storage', 'drawers'), depth=5,
       variants={k: {'pal': v} for k, v in WOOD_PALS.items()},
       slots=({'id': 'top', 'dx0': 4, 'dx1': 40, 'dy': -34, 'top': True, 'kinds': ('small', 'lamp')},),
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


@piece('armchair', 34, 36, 'front', rooms={'bedroom': 4, 'living_room': 8, 'study': 5, 'dining_room': 1}, styles={'adult': 3, 'sick': 1, 'refuge': 1}, tags=('seating_lounge',),
       variants={k: {'fab': v} for k, v in FABRICS.items()}, anchors=({'name': 'armchair', 'dx': 17, 'dy': -12},), feet=(114, 119),
       note='an armchair set at an angle to the room: a high back, rolled arms, a loose cushion')
def armchair(c, ox, oy, p):
    f, fd, fl = p['fab']
    out = shade(fd, 0.45)
    x0, x1 = ox, ox + 33
    c.shadow((x0 + x1) // 2, oy + 1, 19, 2, 100)
    c.box(x0 + 4, oy - 35, x1 - 4, oy - 16, f, out)                                    # the back, with a lit top edge and a padded panel
    c.hline(x0 + 5, x1 - 5, oy - 34, fl)
    c.rect(x0 + 8, oy - 31, x1 - 8, oy - 20, fd)
    c.hline(x0 + 8, x1 - 8, oy - 31, shade(fd, 0.8))
    c.box(x0, oy - 22, x0 + 6, oy - 4, fd, out)                                        # the rolled arms, their tops lit
    c.box(x1 - 6, oy - 22, x1, oy - 4, fd, out)
    c.hline(x0 + 1, x0 + 5, oy - 21, fl); c.hline(x0 + 1, x0 + 5, oy - 20, shade(fl, 0.9))
    c.hline(x1 - 5, x1 - 1, oy - 21, fl); c.hline(x1 - 5, x1 - 1, oy - 20, shade(fl, 0.9))
    c.poly([(x0 + 7, oy - 15), (x1 - 7, oy - 15), (x1 - 8, oy - 18), (x0 + 8, oy - 18)], fl)   # the seat cushion: top face…
    c.hline(x0 + 8, x1 - 8, oy - 18, shade(fl, 1.1))
    c.box(x0 + 7, oy - 14, x1 - 7, oy - 6, f, out)                                     # …and front
    c.rect(x0 + 13, oy - 11, x0 + 19, oy - 10, fd)
    for lx in (x0 + 2, x1 - 3):
        c.rect(lx, oy - 3, lx + 1, oy, hexc('2a1c17'))


# --- small things ---------------------------------------------------------------------------------------------------------------------------------
@piece('alarm_clock', 8, 7, 'top', rooms={'bedroom': 6}, styles={'adult': 3, 'teen': 4, 'kid': 1, 'sick': 1}, tags=('small',), on=('small',), anims=(), note='a wind-up alarm clock')
def alarm_clock(c, ox, oy, p):
    c.ellipse(ox + 4, oy - 4, 4, 4, hexc('a8322c'))
    c.ellipse(ox + 4, oy - 4, 3, 3, hexc('e6e0cc'))
    c.put(ox + 4, oy - 5, hexc('2a2a2a')); c.put(ox + 5, oy - 4, hexc('2a2a2a'))
    c.put(ox + 1, oy - 8, hexc('b09456')); c.put(ox + 7, oy - 8, hexc('b09456'))
    c.hline(ox + 1, ox + 7, oy, hexc('2a1c17'))


@piece('book_pile', 14, 7, 'top', rooms={'bedroom': 5, 'study': 6, 'living_room': 4}, tags=('small', 'books'), on=('small',),
       variants={'a': {'cols': (0, 1, 3)}, 'b': {'cols': (2, 4)}, 'c': {'cols': (1, 3, 0)}}, note='a few paperbacks in a pile')
def book_pile(c, ox, oy, p):
    cols = [F.BOOKS[i] for i in p['cols']]
    F.book_stack(c, ox, oy + 2, [10, 12, 9][:len(cols)], cols)


@piece('photo_small', 9, 11, 'top', rooms={'bedroom': 4, 'living_room': 4, 'study': 2, 'dining_room': 1}, styles={'adult': 4, 'sick': 2, 'kid': 1}, tags=('small', 'picture'), on=('small',),
       variants={'a': {'bg': hexc('9ac0d8')}, 'b': {'bg': hexc('c9b48a')}}, note='a small framed photograph standing on a surface')
def photo_small(c, ox, oy, p):
    c.box(ox, oy - 10, ox + 8, oy, hexc('6b4a2c'), hexc('3b2718'))
    c.rect(ox + 1, oy - 9, ox + 7, oy - 2, p['bg'])
    c.rect(ox + 3, oy - 7, ox + 5, oy - 4, hexc('d8b89a'))
    c.hline(ox + 2, ox + 6, oy - 3, hexc('a8322c'))
    c.vline(ox + 4, oy - 1, oy, hexc('3b2718'))


@piece('pill_bottles', 10, 7, 'top', rooms={'bedroom': 4, 'bathroom': 6}, styles={'adult': 2, 'sick': 6}, tags=('small', 'medical'), on=('small',),
       note='a brown bottle of tablets and a spoon-sized blister pack')
def pill_bottles(c, ox, oy, p):
    c.rect(ox, oy - 6, ox + 3, oy, hexc('9a5a28'))
    c.rect(ox, oy - 8, ox + 3, oy - 7, hexc('e0d9b8'))
    c.rect(ox + 5, oy - 2, ox + 9, oy, hexc('c9d0d4'))
    c.hline(ox + 5, ox + 9, oy - 2, hexc('e8eef0'))


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


@piece('slippers', 12, 4, 'floor', rooms={'bedroom': 6, 'bathroom': 2}, styles={'adult': 4, 'sick': 2, 'kid': 1}, tags=('clutter',), variants={'blue': {'c': hexc('5a6a8a')}, 'tan': {'c': hexc('a8845a')}},
       near=('sleeping',), feet=(116, 121), note='a pair of slippers by the bed')
def slippers(c, ox, oy, p):
    for dx in (0, 7):
        c.rect(ox + dx, oy - 3, ox + dx + 4, oy - 1, p['c'])
        c.hline(ox + dx, ox + dx + 4, oy - 3, shade(p['c'], 1.3))
        c.hline(ox + dx - 1, ox + dx + 5, oy, hexc('2a1c17'))


@piece('plant_pot', 18, 32, 'floor', rooms={'bedroom': 3, 'living_room': 7, 'study': 3, 'dining_room': 2, 'kitchen': 2, 'bathroom': 2}, styles={'adult': 3, 'sick': 2, 'teen': 1},
       tags=('plant', 'clutter'), variants={'green': {'dead': False}, 'dead': {'dead': True}}, feet=(112, 119), note='a houseplant in a terracotta pot — dead where nobody watered it')
def plant_pot(c, ox, oy, p):
    F.potted_plant(c, ox + 9, oy, dead=p['dead'], big=False)


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
