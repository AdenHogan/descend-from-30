"""THE BEDS — the sleeping pieces of every bedroom style, dressed with tools/art/bedding.py (owner round 47b: better blankets, no boxes under the beds).

Frames, mattresses and the room's perspective come from furn.persp_bed (also used by the baked rooms); what lies on the mattress — pillow, turned-down sheet, cover with a pattern drawn
in perspective, creases, drape, throw — is painted by `bedding.dress`, so the same bed can wear many covers. Nothing stands under a bed any more: the dark gap under the frame is the
thing you search.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import bedding as BD
from furnlib import piece
from pixlib import hexc, shade

BED_WOOD = hexc('4f3526')
BED_WOOD_LT = hexc('66462f')
WOOD_OUT = hexc('2b1c13')

# colourways: (cover, accent, pattern, sheet, pillow, throw)
WOOD_COVERS = {
    'sage': dict(col=hexc('6d7e6a'), accent=hexc('869a82'), pattern='plain', piping=hexc('d8d2bc'), pillow=hexc('e2dccb'), pillow_band=hexc('6d7e6a'), throw=(hexc('a8754a'), hexc('d8c8a0'))),
    'rust': dict(col=hexc('8a5040'), accent=hexc('a86a54'), pattern='stripe', pillow=hexc('d8cfbd'), pillow_band=hexc('8a5040'), throw=None),
    'plum': dict(col=hexc('6a4a6a'), accent=hexc('84628a'), pattern='quilt', pillow=hexc('d8d0c4'), pillow_band=hexc('6a4a6a'), throw=None),
    'slate': dict(col=hexc('52627a'), accent=hexc('6a7a94'), pattern='check', pillow=hexc('d4d8dc'), pillow_band=hexc('52627a'), throw=(hexc('b08a3a'), hexc('6a4a2a'))),
    'mustard': dict(col=hexc('a88a3a'), accent=hexc('c4a652'), pattern='wide', piping=hexc('6a4a2a'), pillow=hexc('e0d8c0'), pillow_band=hexc('a88a3a'), throw=None),
}


def _wood_beds():
    v = {}
    for h in ('left', 'right'):
        for d in WOOD_COVERS:
            v['%s_%s' % (h[0], d)] = {'head': h, 'duvet': d}
    return v


@piece('bed_wood', 137, 47, 'front', rooms={'bedroom': 8}, styles={'adult': 8, 'teen': 2, 'sick': 1}, tags=('sleeping',),
       variants=_wood_beds(), bucketed=True, anchors=({'name': 'bed_pillow', 'dx': 21, 'dy': -26, 'head_rel': True}, {'name': 'underbed', 'dx': 74, 'dy': -4}),
       feet=(114, 116), near=('bedside',), note='a single wooden bed lengthwise to the wall: head either end, one of five covers (plain with piping, striped, quilted, checked, banded), some with a knitted throw')
def bed_wood(c, ox, oy, p):
    spec = dict(WOOD_COVERS[p['duvet']], seed=len(p['duvet']) * 5 + (1 if p['head'] == 'left' else 2))
    F.persp_bed(c, ox, ox + 136, oy, head=p['head'], head_top=68, foot_top=80, board=(BED_WOOD, BED_WOOD_LT, WOOD_OUT), bedding=BD.dress(spec))


# ================================================================================================================================ TEEN: a pine bed
PINE = F.PINE
TEEN_COVERS = {
    'stars': dict(col=hexc('2f3a63'), accent=hexc('d9c24a'), pattern='stars', pillow=hexc('c9ced8'), pillow_band=hexc('2f3a63'), sheet=hexc('a8b0c4'), throw=None),
    'green': dict(col=hexc('3f6a52'), accent=hexc('2c4e3c'), pattern='stripe', pillow=hexc('d8d8cc'), pillow_band=hexc('3f6a52'), throw=None),
    'grey': dict(col=hexc('6a6f78'), accent=hexc('90959e'), pattern='plaid', pillow=hexc('d4d4d0'), pillow_band=hexc('6a6f78'), throw=(hexc('8a3a3a'), hexc('2a2a2e'))),
    'red': dict(col=hexc('8a3a3a'), accent=hexc('62262a'), pattern='check', pillow=hexc('d8d0c8'), pillow_band=hexc('8a3a3a'), throw=None),
}


def _teen_beds():
    v = {}
    for h in ('left', 'right'):
        for d in TEEN_COVERS:
            v['%s_%s' % (h[0], d)] = {'head': h, 'duvet': d}
    return v


@piece('bed_pine', 123, 47, 'front', rooms={'bedroom': 6}, styles={'teen': 8}, tags=('sleeping',), variants=_teen_beds(), bucketed=True,
       anchors=({'name': 'bed_pillow', 'dx': 21, 'dy': -26, 'head_rel': True}, {'name': 'underbed', 'dx': 62, 'dy': -4}),
       feet=(114, 116), near=('bedside',), note='a single pine bed under a teenager\'s cover: stars they stuck on themselves, stripes, a hoodie-grey plaid with a throw, a red check')
def bed_pine(c, ox, oy, p):
    spec = dict(TEEN_COVERS[p['duvet']], seed=len(p['duvet']) * 3 + (1 if p['head'] == 'left' else 2))
    F.persp_bed(c, ox, ox + 122, oy, head=p['head'], head_top=70, foot_top=84, board=(PINE[0], PINE[1], PINE[3]), bedding=BD.dress(spec))


# ================================================================================================================================ SICK: an iron bedstead under a patchwork
IRON_COVERS = {
    'patch': dict(col=hexc('8a6a5a'), accent=hexc('a0806e'), pattern='patch', patch=(hexc('a0505a'), hexc('5e6f58'), hexc('c9a06a'), hexc('5e6f78'), hexc('8a6a5a'), hexc('d0c4a8'))),
    'blue': dict(col=hexc('4a6a88'), accent=hexc('8aa4bc'), pattern='patch', patch=(hexc('3f6488'), hexc('7a9ab8'), hexc('b8c8d4'), hexc('2e4a66'), hexc('d0c8a8'), hexc('8a6a5a'))),
}


def _iron_beds():
    v = {}
    for h in ('left', 'right'):
        for q in IRON_COVERS:
            for s in ('clean', 'stained'):
                v['%s_%s_%s' % (h[0], q, s)] = {'head': h, 'quilt': q, 'stain': s == 'stained'}
    return v


@piece('bed_iron', 119, 47, 'front', rooms={'bedroom': 4}, styles={'sick': 8}, tags=('sleeping', 'medical'), variants=_iron_beds(), bucketed=True,
       anchors=({'name': 'bed_pillow', 'dx': 16, 'dy': -26, 'head_rel': True}, {'name': 'quilt', 'dx': 62, 'dy': -23}), feet=(114, 117), near=('bedside',),
       note='an iron bedstead under a patchwork quilt (one with a dried stain across the pillow end)')
def bed_iron(c, ox, oy, p):
    iron = hexc('2e2c2a')
    spec = dict(IRON_COVERS[p['quilt']], seed=7 + (1 if p['head'] == 'left' else 2), pillow=hexc('d4cdbc'), pillow_band=hexc('7a6a5a'), sheet=hexc('c8c0aa'), stain=p['stain'], creases=3, hem=7)
    F.persp_bed(c, ox, ox + 118, oy, head=p['head'], head_top=70, foot_top=80, board=(iron, shade(iron, 1.3), iron), iron=True, knob=F.BRASS, rail=True, bedding=BD.dress(spec))


# ================================================================================================================================ KID: a small bed with a teddy
KID_COVERS = {
    'pink': dict(col=hexc('d98aa0'), accent=hexc('f4d6e0'), pattern='dots', pillow=hexc('f2e8ec'), pillow_band=hexc('d98aa0'), sheet=hexc('f6eef0'), throw=None, piping=hexc('f6eef0')),
    'blue': dict(col=hexc('7aa0c8'), accent=hexc('d8e6f2'), pattern='stripe', pillow=hexc('eef2f6'), pillow_band=hexc('7aa0c8'), sheet=hexc('f0f2f4'), throw=None, piping=hexc('f0f2f4')),
    'yellow': dict(col=hexc('e6c24a'), accent=hexc('fff4c8'), pattern='stars', pillow=hexc('f6f0dc'), pillow_band=hexc('e6c24a'), sheet=hexc('fbf6e8'), throw=None, piping=hexc('fbf6e8')),
}
KID_BOARD = (hexc('e6e0cc'), hexc('f4f0e4'), hexc('8a8270'))


def _kid_beds():
    v = {}
    for h in ('left', 'right'):
        for d in KID_COVERS:
            v['%s_%s' % (h[0], d)] = {'head': h, 'duvet': d}
    return v


def _teddy(c, cx, base, col=hexc('a06c3c')):
    """A teddy bear sitting up: round body, head with muzzle, ears, arms and pads, a ribbon at the neck — each part a lit ball, then outlined."""
    import propkit as K
    L = K.Layer(c)
    lc = L.c
    K.sphere(lc, cx - 3.2, base - 13.2, 1.6, 1.6, col, n=4)                        # ears
    K.sphere(lc, cx + 3.2, base - 13.2, 1.6, 1.6, col, n=4)
    K.sphere(lc, cx, base - 5.2, 3.9, 4.6, col, n=4)                               # body
    K.sphere(lc, cx - 3.6, base - 5.0, 1.4, 2.5, col, n=4)                         # arms
    K.sphere(lc, cx + 3.6, base - 5.0, 1.4, 2.5, col, n=4)
    K.sphere(lc, cx - 2.2, base - 0.6, 1.6, 1.3, col, n=4)                         # feet
    K.sphere(lc, cx + 2.2, base - 0.6, 1.6, 1.3, col, n=4)
    K.sphere(lc, cx, base - 10.2, 3.4, 3.2, col, n=4)                              # head
    K.sphere(lc, cx, base - 8.9, 1.8, 1.2, shade(col, 1.35), n=3)                  # muzzle
    lc.put(int(cx) - 1, int(base - 9.5), hexc('1e1a16'))                           # eyes + nose
    lc.put(int(cx) + 1, int(base - 9.5), hexc('1e1a16'))
    lc.put(int(cx), int(base - 9), hexc('2a1c17'))
    lc.rect(int(cx) - 2, int(base - 7), int(cx) + 1, int(base - 6), hexc('c04a52'))   # a ribbon bow
    lc.put(int(cx) - 1, int(base - 6.5), hexc('e07a82'))
    L.flush()


@piece('bed_kid', 79, 40, 'front', rooms={'bedroom': 5}, styles={'kid': 8}, tags=('sleeping',), variants=_kid_beds(), bucketed=True,
       anchors=({'name': 'bed_pillow', 'dx': 16, 'dy': -26, 'head_rel': True}, {'name': 'underbed', 'dx': 40, 'dy': -4}), feet=(114, 116), near=('bedside',),
       note="a small cream bed with a spotted, striped or starry cover and a teddy bear sitting up against the pillow")
def bed_kid(c, ox, oy, p):
    spec = dict(KID_COVERS[p['duvet']], seed=2 + (1 if p['head'] == 'left' else 3), creases=3, hem=7)
    F.persp_bed(c, ox, ox + 78, oy, head=p['head'], head_top=76, foot_top=84, board=KID_BOARD, bedding=BD.dress(spec))
    hx = 17 if p['head'] == 'left' else 61                                                  # the teddy sits at the head end, leaning on the pillow
    _teddy(c, ox + hx, oy - 20, hexc('a06c3c'))


# ================================================================================================================================ REFUGE: a mattress on the floor
BAGS = {'blue': (hexc('3a5a7a'), hexc('c9803a')), 'green': (hexc('4a5a3a'), hexc('d8c890')), 'red': (hexc('7a3a3a'), hexc('d0b890'))}


def _mattresses():
    v = {}
    for h in ('left', 'right'):
        for b in BAGS:
            v['%s_%s' % (h[0], b)] = {'head': h, 'bag': b}
        v['%s_bare' % h[0]] = {'head': h, 'bag': 'none'}
    return v


@piece('mattress_floor', 105, 24, 'front', rooms={'bedroom': 4}, styles={'bedsit': 8}, tags=('sleeping',), variants=_mattresses(), bucketed=True,
       anchors=({'name': 'bed_pillow', 'dx': 12, 'dy': -12, 'head_rel': True}, {'name': 'sleeping_bag', 'dx': 60, 'dy': -8, 'head_rel': True}), feet=(115, 117), near=('storage',),
       note='a ticking mattress on the floor, stained and tufted, a sleeping bag half unzipped across it (or just the bare mattress)')
def mattress_floor(c, ox, oy, p):
    spec = dict(seed=3 + (1 if p['head'] == 'left' else 4), stains=((30, 5.0, 7.0, 3.0), (66, 8.5, 5.0, 2.2)), ticking=hexc('cfc7b2'), ticking2=hexc('98a4aa'),
                pillow=hexc('d4cdb8'), pillow_band=hexc('8a8060'))
    if p['bag'] != 'none':
        spec['bag'], spec['lining'] = BAGS[p['bag']]
    F.persp_bed(c, ox, ox + 104, oy, head=p['head'], low=True, sheet=(hexc('c9c0a8'), hexc('a89f88')), bedding=BD.mattress_bed(spec))
