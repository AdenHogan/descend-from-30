"""BEDROOM STYLE `sick` — the sick room (the old bedroom_c): an iron bedstead under a patchwork quilt, a drip stand still dripping, a wheelchair, a medicine trolley, a mirrored wardrobe, a cabinet
of pill bottles, a wedding photo and a cross-stitch sampler. Each piece its own asset; the planner decides what is in THIS flat's sick room and where."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import bedroom_variants as BV
from furnlib import piece
from pixlib import hexc, shade
from furn_bedroom import _legacy

BLOOD = hexc('4a1d1b', 150)
QUILTS = {'patch': ((hexc('a0505a'), hexc('5e6f58'), hexc('c9a06a'), hexc('5e6f78'), hexc('a0505a'), hexc('5e6f58'))),
          'blue': ((hexc('5e6f78'), hexc('8a9aa8'), hexc('5e6f78'), hexc('8a9aa8'), hexc('5e6f78'), hexc('8a9aa8')))}


def _iron_beds():
    v = {}
    for h in ('left', 'right'):
        for q in QUILTS:
            for s in ('clean', 'stained'):
                v['%s_%s_%s' % (h[0], q, s)] = {'head': h, 'quilt': q, 'stain': s == 'stained'}
    return v


@piece('bed_iron', 119, 47, 'front', rooms={'bedroom': 4}, styles={'sick': 8}, tags=('sleeping', 'medical'), variants=_iron_beds(), bucketed=True,
       anchors=({'name': 'bed_pillow', 'dx': 16, 'dy': -26, 'head_rel': True}, {'name': 'quilt', 'dx': 62, 'dy': -23}), feet=(114, 117), near=('bedside',),
       note='an iron bedstead under a patchwork quilt (one with a stain on the pillow end)')
def bed_iron(c, ox, oy, p):
    iron, knob = hexc('2e2c2a'), F.BRASS
    F.persp_bed(c, ox, ox + 118, oy, head=p['head'], head_top=70, foot_top=80, board=(iron, shade(iron, 1.3), iron), iron=True, knob=knob,
                duvet=(hexc('8a6a5a'), hexc('6e5446'), hexc('a0806e')), rail=True)
    cols = QUILTS[p['quilt']]
    for k, (qx, qy) in enumerate(((34, 90), (56, 93), (78, 90), (44, 95), (68, 96), (90, 94))):
        mx = qx if p['head'] == 'left' else 118 - qx - 7
        c.rect(ox + mx, oy - 116 + qy, ox + mx + 7, oy - 116 + qy + 2, cols[k])
    if p['stain']:
        bx = 12 if p['head'] == 'left' else 106
        c.ellipse(ox + bx, oy - 24, 3, 1, BLOOD)
        c.line(ox + bx - 2, oy - 20, ox + bx - 1, oy - 12, BLOOD)


@piece('drip_stand', 12, 82, 'floor', rooms={'bedroom': 4, 'bathroom': 3}, styles={'sick': 8, 'adult': 1}, tags=('medical',), variants={'a': {}},
       anims=({'kind': 'drop', 'dx': 3, 'dy': -67, 'fall': 3, 'color': 'e8f0f0'},), near=('sleeping',), feet=(114, 118), note='an IV drip stand, still dripping')
def drip_stand(c, ox, oy, p):
    BV.drip_stand(c, ox + 5, oy)


@piece('wheelchair', 33, 36, 'floor', rooms={'bedroom': 4, 'bathroom': 2, 'living_room': 1}, styles={'sick': 8, 'adult': 1}, tags=('medical',), variants={'a': {}},
       anchors=({'name': 'wheelchair', 'dx': 14, 'dy': -21},), near=('sleeping',), feet=(116, 120), note='a folding wheelchair, a blanket across the seat')
def wheelchair(c, ox, oy, p):
    BV.wheelchair(c, ox + 1, oy)


@piece('med_trolley', 32, 36, 'floor', rooms={'bedroom': 4, 'bathroom': 3}, styles={'sick': 8}, tags=('medical',), variants={'a': {}},
       anchors=({'name': 'med_trolley', 'dx': 9, 'dy': -30},), near=('sleeping',), feet=(116, 120), note='a medicine trolley: a basin, bottles, towels')
def med_trolley(c, ox, oy, p):
    BV.med_trolley(c, ox + 1, oy)


@piece('wardrobe_mirror', 39, 77, 'wall', rooms={'bedroom': 4}, styles={'sick': 8, 'adult': 2}, tags=('wardrobe', 'storage', 'mirror', 'tall'), depth=5, variants={'a': {}},
       anchors=({'name': 'wardrobe', 'dx': 7, 'dy': -39},), feet=(105, 108), note='a tall wardrobe with a mirrored door')
def wardrobe_mirror(c, ox, oy, p):
    _legacy(c, BV._c_wardrobe, ox - 8, oy - 99)


def _cabinet(c):
    BV._c_cabinet(c)


@piece('pill_cabinet', 27, 26, 'wall', rooms={'bedroom': 4, 'bathroom': 5}, styles={'sick': 8, 'adult': 1}, tags=('storage', 'medical'), depth=4, variants={'a': {}},
       slots=(), anchors=({'name': 'pill_cabinet', 'dx': 12, 'dy': -13},), feet=(105, 108), note='a cabinet crowded with pill bottles')
def pill_cabinet(c, ox, oy, p):
    _legacy(c, _cabinet, ox - 280, oy - 99)


@piece('photo_wedding', 29, 28, 'decor', rooms={'bedroom': 4, 'living_room': 4}, styles={'sick': 6, 'adult': 2}, tags=('picture',), wall_y=(24, 40), limit=1, note='a sepia wedding photograph')
def photo_wedding(c, ox, oy, p):
    F.photo(c, ox + 2, oy + 8, ox + 26, oy + 26, [(hexc('e0c8a8'), hexc('5a4028'), hexc('f4f0e4'), 12), (hexc('d8b89a'), hexc('2a2420'), hexc('2e2e33'), 13)],
            bg=hexc('c8b89a'), ground=hexc('a8987a'), frame=hexc('6b4a2c'))
    c.line(ox + 14, oy, ox, oy + 6, hexc('3b2718')); c.line(ox + 14, oy, ox + 28, oy + 6, hexc('3b2718'))


@piece('sampler_home', 22, 17, 'decor', rooms={'bedroom': 3, 'living_room': 3, 'kitchen': 3}, styles={'sick': 6, 'adult': 2}, tags=('picture',), wall_y=(24, 40), limit=1,
       note='a cross-stitch sampler that says HOME')
def sampler_home(c, ox, oy, p):
    c.box(ox, oy, ox + 20, oy + 14, hexc('6b4a2c'), hexc('3b2718'))
    c.rect(ox + 2, oy + 2, ox + 18, oy + 12, hexc('e6ddc4'))
    F.text3(c, ox + 2 + (17 - F.text3_width('HOME')) // 2, oy + 3, 'HOME', hexc('a0505a'))
    for (hx, hy) in ((8, 9), (10, 9), (7, 10), (11, 10), (8, 10), (9, 10), (10, 10), (9, 11)):
        c.put(ox + hx, oy + hy, hexc('b0453a'))
