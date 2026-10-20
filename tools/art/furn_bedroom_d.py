"""BEDROOM STYLE `refuge` — the squat (the old bedroom_d): a mattress on the floor with a sleeping bag, a freestanding clothes rail, a backpack, crates with a camping stove, boxes, a
battery lantern, a front page taped to the wall, a missing poster, a warning sprayed on the plaster, tally marks. Each piece its own asset."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import bedroom_variants as BV
from furnlib import piece
from pixlib import hexc, shade, rrect
from furn_bedroom import _legacy, CLOTH

def _backpack(c):
    c.shadow(70, 121, 10, 2, 110)
    c.poly([(60, 121), (61, 106), (66, 100), (76, 100), (80, 106), (80, 121)], hexc('4a5a3a'))
    c.rect(62, 110, 78, 116, hexc('3a4a2e'))
    c.line(64, 102, 64, 108, hexc('2e3a24')); c.line(76, 102, 76, 108, hexc('2e3a24'))
    c.rect(68, 99, 72, 101, hexc('2e3a24'))


@piece('newspaper_evacuate', 37, 30, 'decor', rooms={'bedroom': 3, 'living_room': 3, 'kitchen': 2, 'study': 2}, styles={'refuge': 8, 'adult': 1}, tags=('notice',), wall_y=(22, 36), limit=1,
       note='a front page taped to the wall: EVACUATE')
def newspaper_evacuate(c, ox, oy, p):
    F.newspaper(c, ox, oy, 'EVACUATE', sub='GO NORTH', w=36)


@piece('missing_lucy', 20, 28, 'decor', rooms={'bedroom': 3, 'living_room': 3, 'kitchen': 2, 'study': 2}, styles={'refuge': 8, 'kid': 1}, tags=('notice',), wall_y=(22, 36), limit=1,
       note='a missing-person poster: LUCY')
def missing_lucy(c, ox, oy, p):
    F.missing_poster(c, ox, oy, name='LUCY')


