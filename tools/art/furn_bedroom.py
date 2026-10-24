"""THE BEDROOM PIECES — every piece of furniture and object a bedroom can hold, each its own asset (owner round 47; the system is tools/art/furnlib.py).

The five old bedroom variants (tools/art/bedroom.py + bedroom_variants.py) were five baked pictures. Their pieces live here now, separately, with the logic of where they belong:
styles `adult` (A: the faded blue-papered main bedroom), `teen` (B: posters, a desk with an old computer), `sick` (C: the sick room — an iron bedstead, a drip stand, a wheelchair),
`bedsit` (D: a young renter's room — a mattress on the floor, crates for a bedside, a clothes rail, a rucksack, moving boxes), `kid` (E: the child's room — a dolls' house, a rocking horse, a toy chest). A piece lists the
styles it suits, so the planner never puts a drip stand in the child's room or a dolls' house in the bedsit; a piece lists the ROOMS it suits, so a bed can never turn up in a kitchen.

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
# --- things that stand ON a surface (slots) ------------------------------------------------------------------------------------------------------
# --- the floor -----------------------------------------------------------------------------------------------------------------------------------
CLOTH = [hexc('8a4a42'), hexc('4e5d70'), hexc('c1b69c'), hexc('5f6b4e'), hexc('7d6a8a'), hexc('2e2e33')]


# --- on the walls ---------------------------------------------------------------------------------------------------------------------------------
# --- the ceiling ----------------------------------------------------------------------------------------------------------------------------------
# --- the rug --------------------------------------------------------------------------------------------------------------------------------------
# ================================================================================================================================ ADULT, more pieces
WOOD_PALS = {'dark': (WOOD, WOOD_LT, WOOD_DK, WOOD_OUT), 'light': (hexc('8a6a4a'), hexc('a2805a'), hexc('6c5038'), hexc('3a281a')),
             'oak': (hexc('7a5a3a'), hexc('8e6a46'), hexc('5e4430'), hexc('2e2014'))}


LAMP_PENDANTS = ('cream', 'rose', 'green', 'mustard')


# --- a chair to sit in ---------------------------------------------------------------------------------------------------------------------------------
FABRICS = {'mustard': (hexc('b08a3a'), hexc('8a6a28'), hexc('c9a24e')), 'green': (hexc('5a7a55'), hexc('42603f'), hexc('6f8f68')),
           'rose': (hexc('a85a62'), hexc('86444c'), hexc('bf7078')), 'grey': (hexc('7a7f88'), hexc('5e636c'), hexc('90959e'))}


# --- small things ---------------------------------------------------------------------------------------------------------------------------------
# --- on the floor ---------------------------------------------------------------------------------------------------------------------------------
# --- on the wall ----------------------------------------------------------------------------------------------------------------------------------
# --- more pictures --------------------------------------------------------------------------------------------------------------------------------
@piece('picture_landscape', 24, 24, 'decor', rooms={'bedroom': 5, 'living_room': 6, 'dining_room': 5, 'study': 3, 'kitchen': 2}, styles={'adult': 5, 'sick': 2, 'kid': 1}, tags=('picture',),
       variants={'hills': {'water': None, 'boat': False, 'fr': hexc('6b4a2c')}, 'sea': {'water': hexc('5a7a9a'), 'boat': True, 'fr': hexc('b09456')}}, wall_y=(22, 38),
       note='a painted landscape in a frame: hills, or the sea with a sailing boat')
def picture_landscape(c, ox, oy, p):
    import wall_art3d
    wall_art3d.picture_landscape(c, ox, oy, p)


@piece('picture_portrait', 22, 28, 'decor', rooms={'bedroom': 5, 'living_room': 6, 'dining_room': 5, 'study': 5}, styles={'adult': 4, 'sick': 3}, tags=('picture',),
       variants={'man': {'s': 'man'}, 'woman': {'s': 'woman'}, 'old': {'s': 'old'}, 'girl': {'s': 'girl'}}, wall_y=(20, 34), note='a portrait someone actually sat for')
def picture_portrait(c, ox, oy, p):
    F.portrait(c, ox + 3, oy + 4, ox + 16, oy + 22, sitter=p['s'], frame=hexc('6b4a2c'))


@piece('calendar_wall', 25, 36, 'decor', rooms={'bedroom': 3, 'kitchen': 7, 'study': 4, 'living_room': 2}, styles={'adult': 3, 'teen': 1, 'bedsit': 2, 'sick': 1}, tags=('notice',), limit=1,
       wall_y=(28, 44), note='a wall calendar: the days crossed off in red up to the 12th — and then nothing')
def calendar_wall(c, ox, oy, p):
    F.calendar(c, ox, oy + 3, month='MAY', crossed=12, ringed=19)
