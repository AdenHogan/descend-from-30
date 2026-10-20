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
@piece('picture_crayon', 34, 29, 'decor', rooms={'bedroom': 5, 'kitchen': 3, 'living_room': 3}, styles={'kid': 8}, tags=('picture',), wall_y=(18, 34), limit=1,
       note='a crayon drawing in a cheap white frame')
def picture_crayon(c, ox, oy, p):
    import wallart
    wallart.picture_crayon(c, ox, oy, ox + 30, oy + 24)


@piece('poster_rainbow', 21, 27, 'decor', rooms={'bedroom': 5}, styles={'kid': 8}, tags=('poster',), wall_y=(18, 34), limit=1, note='a rainbow poster taped up')
def poster_rainbow(c, ox, oy, p):
    import wallart
    wallart.poster_rainbow(c, ox, oy, ox + 18, oy + 24)
