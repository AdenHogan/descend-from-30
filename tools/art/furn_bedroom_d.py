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

@piece('clothes_rail', 49, 52, 'floor', rooms={'bedroom': 4, 'living_room': 1}, styles={'refuge': 8, 'sick': 1, 'teen': 1}, tags=('storage', 'clothes'), variants={'a': {}},
       anchors=({'name': 'clothes_rail', 'dx': 16, 'dy': -22},), feet=(116, 119), near=('sleeping',), note='a freestanding clothes rail on castors, a few things hung from it')
def clothes_rail(c, ox, oy, p):
    rx0, rx1, rtop, rbase = ox, ox + 44, oy - 48, oy
    c.shadow((rx0 + rx1) // 2, rbase, 24, 2, 110)
    c.vline(rx0, rtop, rbase - 2, hexc('9aa3a8'))
    c.vline(rx1, rtop, rbase - 2, hexc('9aa3a8'))
    c.hline(rx0, rx1, rtop, hexc('9aa3a8'))
    c.hline(rx0 - 3, rx0 + 3, rbase - 1, hexc('9aa3a8')); c.hline(rx1 - 3, rx1 + 3, rbase - 1, hexc('9aa3a8'))
    for (hx, col, ln) in ((6, CLOTH[0], 26), (16, CLOTH[3], 34), (26, CLOTH[5], 22), (35, CLOTH[1], 30)):
        c.line(rx0 + hx, rtop + 1, rx0 + hx - 3, rtop + 4, hexc('6d6c64'))
        c.line(rx0 + hx, rtop + 1, rx0 + hx + 3, rtop + 4, hexc('6d6c64'))
        c.poly([(rx0 + hx - 4, rtop + 4), (rx0 + hx + 4, rtop + 4), (rx0 + hx + 5, rtop + 4 + ln), (rx0 + hx - 5, rtop + 4 + ln)], col)
        c.vline(rx0 + hx, rtop + 6, rtop + 3 + ln, shade(col, 0.8))


def _backpack(c):
    c.shadow(70, 121, 10, 2, 110)
    c.poly([(60, 121), (61, 106), (66, 100), (76, 100), (80, 106), (80, 121)], hexc('4a5a3a'))
    c.rect(62, 110, 78, 116, hexc('3a4a2e'))
    c.line(64, 102, 64, 108, hexc('2e3a24')); c.line(76, 102, 76, 108, hexc('2e3a24'))
    c.rect(68, 99, 72, 101, hexc('2e3a24'))


@piece('floor_stain', 28, 8, 'rug', rooms={'bedroom': 4, 'living_room': 3, 'kitchen': 3, 'bathroom': 3}, styles={'refuge': 6, 'sick': 3, 'teen': 1}, tags=('stain',), feet=(113, 119),
       variants={'a': {'seed': 34}, 'b': {'seed': 41}}, note='a dried stain on the boards')
def floor_stain(c, ox, oy, p):
    F.floor_stain(c, ox + 14, oy - 4, 12, 2.5, hexc('9a8a5a'), seed=p['seed'])


@piece('newspaper_evacuate', 37, 30, 'decor', rooms={'bedroom': 3, 'living_room': 3, 'kitchen': 2, 'study': 2}, styles={'refuge': 8, 'adult': 1}, tags=('notice',), wall_y=(22, 36), limit=1,
       note='a front page taped to the wall: EVACUATE')
def newspaper_evacuate(c, ox, oy, p):
    F.newspaper(c, ox, oy, 'EVACUATE', sub='GO NORTH', w=36)


@piece('missing_lucy', 20, 28, 'decor', rooms={'bedroom': 3, 'living_room': 3, 'kitchen': 2, 'study': 2}, styles={'refuge': 8, 'kid': 1}, tags=('notice',), wall_y=(22, 36), limit=1,
       note='a missing-person poster: LUCY')
def missing_lucy(c, ox, oy, p):
    F.missing_poster(c, ox, oy, name='LUCY')


@piece('spray_nofood', 35, 18, 'decor', rooms={'bedroom': 4, 'living_room': 3, 'kitchen': 3}, styles={'refuge': 8}, tags=('notice',), wall_y=(24, 38), limit=1,
       note='NO FOOD, sprayed on the plaster for whoever comes in after')
def spray_nofood(c, ox, oy, p):
    F.text_spray(c, ox, oy, 'NO FOOD', hexc('a8322c'))


@piece('tally_marks', 24, 12, 'decor', rooms={'bedroom': 4, 'living_room': 2, 'study': 2}, styles={'refuge': 8, 'sick': 1}, tags=('mark',), wall_y=(44, 60), limit=1,
       note='the days, scratched into the plaster')
def tally_marks(c, ox, oy, p):
    for i in range(7):
        c.vline(ox + i * 3, oy, oy + 8, hexc('5a5244'))
    c.line(ox - 2, oy + 6, ox + 20, oy + 2, hexc('5a5244'))
