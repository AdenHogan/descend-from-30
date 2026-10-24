"""THE DOLLS' HOUSE (kid style) — redrawn with depth and detail (owner round 47b: "the dolls house is too flat and simple").

A low pine toy table with a four-room house standing on it, its front open like a real one: two storeys with floor slabs and a party wall, each room papered and furnished with tiny pieces (a
stove, a bed, a bath…), a shingled front roof slope with eaves, a brick chimney and a round attic window. One room is dark and a small pale doll stands in it. The kit leans the whole thing toward
the room's middle (pixlib.setback), so the table top and the house's side show real depth.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furnlib as FL
from furnlib import piece
from pixlib import hexc, shade, mix
import propkit as K

PINE = hexc('b98a52')
TW = 47                                                                 # the table's width: the house (30) + its side face (6) + a margin of wood each side

import dollhouse3d as DH

HOUSES = {k: dict(house=k) for k in DH.SCHEMES}


def _house_post(c, ox, oy, p, shift):
    """The house stands ON the table, after the kit has leaned the table toward the room's middle (the house is drawn with its own side face, so it is NOT extruded as well)."""
    side = 'r' if ox + TW // 2 <= 160 else 'l'                      # the face toward the room's middle shows
    top_y = oy - 19 + (shift // 2 if shift > 1 else shift)
    # the house + its side face (6 px) sit centred on the top: 5-6 px of wood each side, never overhanging it
    DH.draw(c, ox + (5 if side == 'r' else 12), top_y, p['house'], side, top_col=PINE)


@piece('dollhouse_table', TW, 74, 'wall', rooms={'bedroom': 4, 'living_room': 2}, styles={'kid': 8}, tags=('toy',), depth=4, surface_h=19,
       variants={k: {'house': k} for k in HOUSES}, anchors=({'name': 'dollhouse', 'dx': TW // 2, 'dy': -29},), feet=(105, 108), post=_house_post,
       note="a dolls' house on a low pine table: a real little building - a gabled shingled roof with a brick chimney, a side wall with its own windows, two storeys open at the front (kitchen, bedroom, bath and one dark room with a small pale doll in it)")
def dollhouse_table(c, ox, oy, p):
    L = K.Layer(c)
    lc = L.c
    ty = oy - 19                                                        # the table top
    # --- the table: pine top with a lit edge, turned legs, a stretcher
    lc.shadow(ox + TW // 2, oy + 1, TW // 2, 2, 90)
    for lx in (ox + 3, ox + TW - 5):
        for y in range(ty + 3, oy + 1):
            lc.put(lx, y, shade(PINE, 0.95))
            lc.put(lx + 1, y, shade(PINE, 0.68))
        lc.put(lx, ty + 8, shade(PINE, 1.2))
        lc.rect(lx - 1, oy - 1, lx + 2, oy, shade(PINE, 0.6))
    lc.hline(ox + 4, ox + TW - 4, oy - 7, shade(PINE, 0.8))
    lc.hline(ox + 4, ox + TW - 4, oy - 6, shade(PINE, 0.6))
    lc.rect(ox, ty, ox + TW - 1, ty + 2, PINE)
    lc.hline(ox, ox + TW - 1, ty, shade(PINE, 1.3))
    lc.hline(ox, ox + TW - 1, ty + 2, shade(PINE, 0.62))
    lc.hline(ox + 1, ox + TW - 2, ty + 3, shade(PINE, 0.5))
    L.flush()
