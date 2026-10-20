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

PILLOW = hexc('d8d1bf')
BAGS = {'blue': (hexc('3a5a7a'), hexc('2a4460')), 'green': (hexc('4a5a3a'), hexc('34422a')), 'red': (hexc('7a3a3a'), hexc('5a2a2a'))}


def _mattresses():
    v = {}
    for h in ('left', 'right'):
        for b in BAGS:
            v['%s_%s' % (h[0], b)] = {'head': h, 'bag': b}
    v['l_bare'] = {'head': 'left', 'bag': 'none'}
    v['r_bare'] = {'head': 'right', 'bag': 'none'}
    return v


@piece('mattress_floor', 105, 24, 'front', rooms={'bedroom': 4}, styles={'refuge': 8}, tags=('sleeping',), variants=_mattresses(), bucketed=True,
       anchors=({'name': 'bed_pillow', 'dx': 12, 'dy': -12, 'head_rel': True}, {'name': 'sleeping_bag', 'dx': 70, 'dy': -8, 'head_rel': True, 'if': {'bag': 'blue'}},
                {'name': 'sleeping_bag', 'dx': 70, 'dy': -8, 'head_rel': True, 'if': {'bag': 'green'}}, {'name': 'sleeping_bag', 'dx': 70, 'dy': -8, 'head_rel': True, 'if': {'bag': 'red'}}),
       feet=(115, 117), near=('storage',), note='a mattress on the floor with a sleeping bag half off it')
def mattress_floor(c, ox, oy, p):
    x0, x1 = ox, ox + 104
    F.persp_bed(c, x0, x1, oy, head=p['head'], low=True, sheet=(hexc('c9c0a8'), hexc('a89f88')))
    mir = (lambda x: x) if p['head'] == 'left' else (lambda x: x0 + x1 - x)
    for x in range(6, 104, 12):
        c.put(mir(x0 + x), oy - 2, hexc('8a8270'))                                                  # buttons
    hx = x0 + 3 if p['head'] == 'left' else x1 - 22
    rrect(c, hx, oy - 15, hx + 19, oy - 9, PILLOW, 2)
    if p['bag'] != 'none':
        a, b = BAGS[p['bag']]
        pts = [(x0 + 26, oy - 13), (x1 - 12, oy - 14), (x1 + 6, oy - 6), (x1 + 4, oy + 3), (x0 + 30, oy - 2)]
        pts = [(mir(x), y) for (x, y) in pts]
        c.poly(pts, a)
        c.line(mir(x0 + 30), oy - 8, mir(x1 - 4), oy - 8, b)
        c.line(mir(x0 + 30), oy - 5, mir(x1 + 2), oy - 3, b)
        c.rect(mir(x1 - 30), oy - 12, mir(x1 - 30) + 2, oy - 10, hexc('c0453a'))


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


@piece('backpack', 23, 22, 'floor', rooms={'bedroom': 5, 'living_room': 2, 'study': 2}, styles={'refuge': 8, 'teen': 2, 'adult': 1}, tags=('storage', 'bag'), variants={'olive': {}},
       anchors=({'name': 'backpack', 'dx': 10, 'dy': -14},), near=('sleeping',), feet=(116, 121), note='a backpack dumped on the floor, half emptied')
def backpack(c, ox, oy, p):
    _legacy(c, _backpack, ox - 60, oy - 121)


@piece('crates_stove', 40, 45, 'wall', rooms={'bedroom': 4, 'living_room': 1}, styles={'refuge': 8}, tags=('storage',), depth=4, surface_h=37, variants={'a': {}},
       slots=({'id': 'lamp', 'dx0': 33, 'dx1': 40, 'dy': -21, 'top': False, 'kinds': ('lamp',)},), anchors=({'name': 'crates', 'dx': 15, 'dy': -29},), feet=(105, 108),
       note='crates stacked against the wall with a camping stove on top, cans and candles')
def crates_stove(c, ox, oy, p):
    def body(l):
        BV._d_crates(l)
    _legacy(c, body, ox - 5, oy - 99)


@piece('boxes_stack', 33, 38, 'wall', rooms={'bedroom': 5, 'living_room': 3, 'study': 3, 'kitchen': 2, 'dining_room': 1}, styles={'refuge': 8}, tags=('storage',), depth=4,
       variants={'a': {}}, anchors=({'name': 'boxes', 'dx': 16, 'dy': -13},), feet=(105, 108), note='cardboard boxes stacked against the wall')
def boxes_stack(c, ox, oy, p):
    _legacy(c, BV._d_boxes, ox - 276, oy - 99)


@piece('lantern_battery', 8, 14, 'top', rooms={'bedroom': 3, 'living_room': 3, 'kitchen': 1, 'study': 2}, styles={'refuge': 8, 'sick': 1}, tags=('light', 'lamp'), on=('lamp',),
       lights=({'dx': 3, 'dy': -6, 'kind': 'lantern'},), note='a battery camping lantern — it works without the flat\'s power')
def lantern_battery(c, ox, oy, p):
    F.lantern(c, ox + 3, oy)


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
