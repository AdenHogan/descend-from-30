"""THE BATHROOM — toilets, basins, baths, a shower, a washing machine and the small things that live round them (owner round 47f: "expand to other module types too… a big pass").

A bathroom is a SHELL (the bare tiled room) plus PIECES laid by the planner, in five STYLES — tub (A: the classic suite, a roll-top bath out in the room, a pedestal basin, a corner shower), avocado
(B: the seventies suite, a panelled bath with a glass screen, a vanity unit), gilded (C: the gold roll-top, the gold throne, the gilt washstand), wetroom (D: the squalid one — a curtained bath, a
washing machine spewing clothes) and pink (E: the fifties suite, a tiled tub with its curtain drawn back, a linen cupboard).

The fixtures are NOT redrawn: they are the old bathroom's own solids (tools/art/bathroom.py + solid3d.py — true perspective, we look down into the basin and over the lip of the bath), lifted out of
the module into pieces. They draw at the bucket's x on the full module canvas, so each carries the perspective of where it stands; every one is registered with its feet on the row the old art drew
them on (front plane 114), so a piece placed at that row lands exactly where it was drawn. Their nodes are FRONT nodes (you stand at a toilet), as before.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bathroom as BR
import furn as F
import furnlib as FL
import propkit as K
import solid3d as S3
from furnlib import piece
from pixlib import hexc, shade, mix, rrect, setback, pbox, pp, flat_piece
from solid3d import P as _P3

Y_FRONT = 114                                                                                       # the feet row of a front-plane piece: the pieces draw on the old module's rows

# palettes lifted from bathroom.py's variants
PORC, PORC_LT, PORC_DK, PORC_OUT = BR.PORC, BR.PORC_LT, BR.PORC_DK, BR.PORC_OUT
AVO, AVO_LT, AVO_DK, AVO_OUT = BR.AVO, BR.AVO_LT, BR.AVO_DK, BR.AVO_OUT
GOLD, GOLD_LT, GOLD_DK, GOLD_OUT = BR.GOLD, BR.GOLD_LT, BR.GOLD_DK, BR.GOLD_OUT
PINK, PINK_LT, PINK_DK, PINK_OUT = BR.PINK, BR.PINK_LT, BR.PINK_DK, BR.PINK_OUT
CHROME, CHROME_DK, IRON, BLOOD, MIRROR, MIRROR_HI, GLASS = BR.CHROME, BR.CHROME_DK, BR.IRON, BR.BLOOD, BR.MIRROR, BR.MIRROR_HI, BR.GLASS
E_TILE = BR.E_TILE
TOWELS = BR.TOWELS


def _fixture(pid, w, h, **kw):
    """A fixture piece: front plane, drawn per bucket on the module canvas, feet on the old art's row."""
    kw.setdefault('feet', (Y_FRONT, Y_FRONT))
    return piece(pid, w, h, 'front', bucketed=True, lean=False, **kw)


# ================================================================================================================================ the toilet
_TOILETS = {
    'white': dict(kw={}, roll=hexc('ece6d6'), rolly=80, forr=['tub']),
    'avocado': dict(kw=dict(porc=AVO, out=AVO_OUT, lid_up=True, seat=hexc('d9cfa8')), roll=hexc('ece6d6'), rolly=78, forr=['avocado']),
    'gold': dict(kw=dict(porc=GOLD, out=GOLD_OUT, seat=hexc('7a1f2a'), lever=GOLD_LT, crest=hexc('7a1f2a')), roll=None, rolly=78, forr=['gilded']),
    'wet': dict(kw=dict(lid_up=True, seat=hexc('b9b4a4')), roll=None, rolly=78, forr=['wetroom']),
    'pink': dict(kw=dict(porc=PINK, out=PINK_OUT, seat=hexc('26262a')), roll=hexc('efe8d8'), rolly=78, forr=['pink']),
}


@_fixture('toilet', 46, 36, rooms={'bathroom': 10}, styles=None, tags=('toilet', 'wet'),
          variants={k: {'t': k, 'for': v['forr']} for k, v in _TOILETS.items()},
          anchors=({'name': 'toilet', 'dx': 12, 'dy': -22},),
          note='a close-coupled toilet standing out from the wall, drawn in perspective: the cistern and its lever, the oval seat from above — white, avocado with its lid up, a gold throne with a red velvet seat, a squalid grey one, a pink one with a black seat — a roll of paper on its holder beside it')
def toilet(c, ox, oy, p):
    spec = _TOILETS[p['t']]
    cx = ox + 14
    BR.toilet3d(c, cx, **spec['kw'])
    if spec['roll'] is not None:
        BR.toilet_roll(c, cx + 22, spec['rolly'], spec['roll'])
    if p['t'] == 'wet':                                                                              # black mould creeping up behind the pan, spare rolls by it
        BR.mould_bloom(c, cx - 14, 92, 12, 22, seed=14, up=True)
        BR.standing_rolls(c, cx + 27, 102)


# ================================================================================================================================ the basin
_BASINS = {
    'pedestal': dict(forr=['tub'], kw=dict(rim=70), rim_x=-21, mug=None, tint=None),
    'pink': dict(forr=['pink'], kw=dict(rim=70, porc=PINK, out=PINK_OUT), rim_x=-21, mug=hexc('e0d9b8'), bottle=hexc('c07a3a')),
    'bracket': dict(forr=['wetroom'], kw=dict(rim=66, pedestal=False, inside=hexc('b9b09a'), drip=True), rim_x=None),
}


@_fixture('basin', 46, 40, rooms={'bathroom': 8}, styles={'tub': 8, 'pink': 8, 'wetroom': 8, 'avocado': 0.01, 'gilded': 0.01},
          tags=('basin', 'wet'), variants={k: {'t': k, 'for': v['forr']} for k, v in _BASINS.items()},
          anchors=({'name': 'basin', 'dx': 6, 'dy': -41, 'if': {'t': 'pedestal'}}, {'name': 'wall_sink', 'dx': 21, 'dy': -40, 'if': {'t': 'pedestal'}},
                   {'name': 'basin', 'dx': 7, 'dy': -41, 'if': {'t': 'pink'}}, {'name': 'wall_sink', 'dx': 24, 'dy': -38, 'if': {'t': 'pink'}},
                   {'name': 'wall_sink', 'dx': 23, 'dy': -44, 'if': {'t': 'bracket'}}),
          note='a basin standing out from the wall, drawn in perspective so we look down into the bowl: a white pedestal basin with a tumbler of toothbrushes and a pump bottle on the rim, a pink one, or a small basin on iron brackets with a waste pipe, a drip and grime')
def basin(c, ox, oy, p):
    spec = _BASINS[p['t']]
    cx = ox + 26
    if p['t'] == 'bracket':
        c.vline(cx, 80, 99, IRON)                                                                    # the waste pipe, down the wall
        c.rect(cx - 3, 92, cx + 3, 97, BR.RUST)
        BR.basin3d(c, cx, **spec['kw'])
        c.dither(cx - 19, 69, cx - 1, 72, hexc('8a7a5a', 120), 0.4, pattern='random')               # grime in the basin
        return
    BR.basin3d(c, cx, **spec['kw'])
    if p['t'] == 'pedestal':
        BR.rim_things(c, cx - 21, 75)
        c.ellipse(cx - 2, 76, 2, 1, BLOOD)
    else:
        BR.rim_things(c, cx - 21, 75, mug=spec['mug'], bottle=spec['bottle'])


# ================================================================================================================================ the vanity and the washstand
@_fixture('vanity', 62, 40, rooms={'bathroom': 7}, styles={'avocado': 9}, tags=('basin', 'wet', 'storage'),
          variants={'avocado': {'for': ['avocado']}},
          anchors=({'name': 'vanity', 'dx': 3, 'dy': -24}, {'name': 'worktop', 'dx': 52, 'dy': -38}),
          note='a vanity unit standing out from the wall: a tiled upstand, a worktop slab with an avocado basin set into it, two panelled doors over a recessed plinth — one open on bleach and sponges — and a tumbler on the slab')
def vanity(c, ox, oy, p):
    cx = ox + 25
    BR.vanity3d(c, cx - 22, cx + 22, 72)
    BR.rim_things(c, cx + 30, 76, mug=hexc('e8a0b0'))


@_fixture('washstand', 60, 42, rooms={'bathroom': 7}, styles={'gilded': 9}, tags=('basin', 'wet', 'storage'),
          variants={'gilt': {'for': ['gilded']}},
          anchors=({'name': 'washstand', 'dx': 5, 'dy': -34}, {'name': 'trinket_dish', 'dx': 48, 'dy': -39}),
          note='a gilt washstand: a marble slab on cabriole legs with a gold basin set into it, a drawer in the apron, a perfume bottle, and a gilt trinket dish with a string of pearls spilling over its lip')
def washstand(c, ox, oy, p):
    cx = ox + 24
    BR.washstand3d(c, cx - 19, cx + 19, 72)
    tq = _P3(S3.wall_x(cx + 19, 14), 72, 6)
    c.ellipse(tq[0], tq[1] - 1, 4, 1.5, GOLD_OUT)
    c.ellipse(tq[0], tq[1] - 1, 3, 1, GOLD)
    c.put(tq[0] - 1, tq[1] - 2, GOLD_LT)
    for (px_, py_) in ((-2, -2), (0, -2), (2, -1), (3, 0), (4, 1), (5, 2), (5, 3)):
        c.put(tq[0] + px_, tq[1] + py_, hexc('f4efe4'))


# ================================================================================================================================ the bath
_BATHS = {'claw': ['tub'], 'gold': ['gilded'], 'panel': ['avocado'], 'curtain': ['wetroom'], 'tiled': ['pink']}


@_fixture('bath', 104, 48, rooms={'bathroom': 10}, styles=None, tags=('bath', 'wet'),
          variants={k: {'t': k, 'for': v} for k, v in _BATHS.items()},
          anchors=({'name': 'bath_left', 'dx': 34, 'dy': -26, 'if': {'t': 'claw'}}, {'name': 'bath_right', 'dx': 70, 'dy': -26, 'if': {'t': 'claw'}},
                   {'name': 'gold_tub', 'dx': 34, 'dy': -22, 'if': {'t': 'gold'}}, {'name': 'bubbles', 'dx': 68, 'dy': -26, 'if': {'t': 'gold'}},
                   {'name': 'bath_taps', 'dx': 28, 'dy': -38, 'if': {'t': 'panel'}}, {'name': 'bath_panel', 'dx': 78, 'dy': -8, 'if': {'t': 'panel'}},
                   {'name': 'behind_curtain', 'dx': 55, 'dy': -44, 'if': {'t': 'curtain'}}, {'name': 'curtain_corner', 'dx': 21, 'dy': -26, 'if': {'t': 'curtain'}},
                   {'name': 'pink_tub', 'dx': 50, 'dy': -22, 'if': {'t': 'tiled'}}, {'name': 'pink_taps', 'dx': 20, 'dy': -38, 'if': {'t': 'tiled'}}),
          note='the bath, drawn in perspective so we look over its lip into it: a roll-top on claw feet out in the room with a hand shower, a GOLD roll-top heaped with bubbles and a rubber duck, a panelled avocado bath with a glass screen and a kicked-in corner, a bath with its curtain drawn hanging INSIDE it, a tiled pink tub with its curtain pulled back')
def bath(c, ox, oy, p):
    k = p['t']
    cx = ox + 52
    if k == 'claw':
        d = cx - 150
        c.rect(186 + d, 50, 187 + d, 70, CHROME_DK)                                                  # the riser + hand shower, its hose hanging to the tap end
        c.rect(184 + d, 48, 189 + d, 50, CHROME)
        c.line(187 + d, 71, 182 + d, 80, CHROME_DK)
        wx0, wx1, _opening = BR.clawfoot3d(c, cx, 64, 80, PORC, PORC_LT, PORC_DK, PORC_OUT, IRON, hexc('4d5a52'), water=hexc('6a7b5e'))
        tp = _P3(wx1 - 3, 80, 13)                                                                    # standing taps at the right end
        c.rect(tp[0] - 1, tp[1] - 6, tp[0] + 1, tp[1] - 1, CHROME)
        c.line(tp[0], tp[1] - 6, tp[0] - 4, tp[1] - 3, CHROME)
        c.put(tp[0] - 4, tp[1] - 2, CHROME_DK)
        e0 = _P3(wx0 + 2, 80, 13)                                                                    # a towel slung over the left end; a streak of blood down the bath
        c.poly([(e0[0] - 2, e0[1] - 2), (e0[0] + 8, e0[1] - 3), (e0[0] + 9, e0[1] + 13), (e0[0] - 1, e0[1] + 15)], TOWELS[3])
        c.vline(e0[0] + 8, e0[1] - 2, e0[1] + 13, shade(TOWELS[3], 0.8))
        c.hline(e0[0] - 1, e0[0] + 8, e0[1] - 2, shade(TOWELS[3], 1.15))
        c.line(152 + d, 102, 154 + d, 112, BLOOD)
    elif k == 'gold':
        wx0, wx1, _o = BR.clawfoot3d(c, cx, 62, 82, GOLD, GOLD_LT, GOLD_DK, GOLD_OUT, GOLD_DK, hexc('6a5418'), water=hexc('d9e0c8'))
        for (bx, bd) in ((wx0 + 12, 8), (wx0 + 20, 12), (wx0 + 28, 7), (wx0 + 36, 13), (wx0 + 44, 9), (wx1 - 12, 11)):   # bubbles heaped up
            q = S3.P(bx, 81, bd)
            c.ellipse(q[0], q[1] - 1, 3, 2, hexc('f4f2ec'))
            c.put(q[0] - 1, q[1] - 2, hexc('ffffff'))
        dk_ = S3.P(wx1 - 10, 81, 15)
        c.rect(dk_[0], dk_[1] - 3, dk_[0] + 4, dk_[1], hexc('f0cf3a'))                               # a rubber duck
        c.put(dk_[0] + 5, dk_[1] - 2, hexc('e07a2a'))
    elif k == 'panel':
        x0, x1, rim = cx - 48, cx + 48, 78
        tx = int(round(S3.wall_x(x0, 20)))
        wx0, wx1, f = BR.bath3d(c, x0, x1, rim, body=AVO, lit=AVO_LT, dk=AVO_DK, out=AVO_OUT, inside=hexc('5f6a34'))
        c.rect(tx + 4, rim - 7, tx + 6, rim - 1, CHROME)                                             # taps on the wall at the left end
        c.rect(tx + 10, rim - 7, tx + 12, rim - 1, CHROME)
        c.hline(tx + 3, tx + 13, rim - 7, CHROME_DK)
        c.rect(tx + 2, 30, tx + 3, rim - 8, CHROME_DK)                                               # a shower riser
        c.rect(tx + 1, 30, tx + 7, 32, CHROME)
        fl, fr, fbr = f['fl'], f['fr'], f['fbr']
        c.box(fl[0] + 4, fl[1] + 4, fr[0] - 4, fbr[1] - 4, AVO, AVO_DK)                             # the moulded front panel
        c.dither(fl[0] + 5, fbr[1] - 8, fr[0] - 5, fbr[1] - 5, AVO_DK, 0.5)
        bx, by = fl[0], fbr[1]                                                                       # kicked in at one corner
        c.poly([(bx + 10, by - 1), (bx + 16, by - 12), (bx + 26, by - 10), (bx + 30, by - 1)], hexc('1e1a16'))
        c.line(bx + 16, by - 12, bx + 26, by - 10, AVO_LT)
        s0, s1 = _P3(wx0 + 2, 34, 19), _P3(wx0 + 26, rim, 19)                                        # the glass screen on the front edge
        for y in range(s0[1], s1[1]):
            for x in range(s0[0], s1[0] + 1):
                c.put(x, y, GLASS)
        c.vline(s1[0], s0[1], s1[1] - 1, CHROME_DK)
        c.hline(s0[0], s1[0], s0[1], CHROME_DK)
        c.vline(s0[0], s0[1], s1[1] - 1, CHROME_DK)
        c.line(s0[0] + 4, s1[1] - 8, s0[0] + 12, s0[1] + 8, hexc('dde6e6'))
    elif k == 'curtain':
        x0, x1, rim = cx - 45, cx + 45, 80
        wx0, wx1, f = BR.bath3d(c, x0, x1, rim, inside=hexc('8a8a70'))
        d_r, rail_y = 11, 13
        BR.shower_rail(_Stay(c), wx0, wx1, rail_y, d_r)
        xa, xb, top, hem = BR.curtain_in_tub(c, wx0, wx1, rim, d_r, rail_y, hexc('c9c48a'), wx0 + 13, wx1, wx0 + 13)
        for (fx, fy) in ((xa + 18, top + 12), (xa + 42, top + 8), (xa + 30, top + 26), (xa + 56, top + 30)):   # ducks printed on it
            c.rect(fx, fy, fx + 4, fy + 3, hexc('d9b43a'))
            c.put(fx + 5, fy + 1, hexc('c06a2a'))
        c.dither(xa, hem - 20, xb, hem - 8, hexc('7a7a4a', 90), 0.4, pattern='random')                # grime low down
        c.line(xa + 3, top + 40, xa + 9, top + 58, BLOOD)                                            # a smear down the plastic
        c.line(xa + 5, top + 40, xa + 10, top + 54, BLOOD)
        for (hx, hy) in ((xa + 1, top + 44), (xa + 1, top + 47), (xa + 1, top + 50)):                # fingers round its edge
            c.rect(hx - 2, hy, hx, hy + 1, hexc('8a6a5a'))
        fl, fbr = BR.bath_front(c, wx0, wx1, rim, d_r)
        c.box(fl[0] + 4, fl[1] + 5, fbr[0] - 4, fbr[1] - 4, PORC, PORC_DK)                          # the bath panel
        c.hline(fl[0] + 5, fbr[0] - 5, fl[1] + 6, PORC_LT)
        c.dither(fl[0] + 1, fbr[1] - 6, fbr[0] - 1, fbr[1] - 1, hexc('8a8a70', 120), 0.45, pattern='random')
        c.line(cx - 5, fl[1] + 8, cx - 3, fl[1] + 18, BLOOD)
    else:                                                                                            # tiled
        x0, x1, rim = cx - 44, cx + 44, 80
        wx0, wx1, f = BR.bath3d(c, x0, x1, rim, body=E_TILE, lit=PINK_LT, dk=shade(E_TILE, 0.72), out=PINK_OUT, inside=hexc('b07a86'))
        tx = int(round(wx0))
        c.rect(tx + 4, rim - 8, tx + 6, rim - 1, CHROME)                                             # taps on the wall
        c.rect(tx + 10, rim - 8, tx + 12, rim - 1, CHROME)
        c.hline(tx + 3, tx + 13, rim - 8, CHROME_DK)
        d_r, rail_y = 11, 14
        BR.shower_rail(_Stay(c), wx0, wx1, rail_y, d_r)
        xa, xb, top, hem = BR.curtain_in_tub(c, wx0, wx1, rim, d_r, rail_y, hexc('efe8d8'), wx1 - 16, wx1, wx1)
        for (x, y) in ((xb - 10, top + 12), (xb - 4, top + 28), (xb - 9, top + 44)):                 # little pink fish on it
            c.rect(x, y, x + 3, y + 1, PINK_DK)
            c.put(x + 4, y, PINK_DK)
            c.put(x + 4, y + 1, PINK_DK)
        fl, fbr = BR.bath_front(c, wx0, wx1, rim, d_r, body=E_TILE, lit=PINK_LT, dk=shade(E_TILE, 0.72), out=PINK_OUT)
        for y in range(fl[1] + 5, fbr[1], 6):                                                        # the tiled plinth
            c.hline(fl[0] + 1, fbr[0] - 1, y, hexc('b89aa0'))
        for x in range(fl[0] + 6, fbr[0], 8):
            c.vline(x, fl[1] + 2, fbr[1] - 1, hexc('b89aa0'))
        c.line(cx - 8, fl[1] + 8, cx - 6, fl[1] + 18, BLOOD)


# ================================================================================================================================ the shower
@_fixture('shower_walkin', 44, 56, rooms={'bathroom': 6}, styles={'tub': 9, 'wetroom': 2}, tags=('wet', 'shower'),
          variants={'glass': {'for': ['tub', 'wetroom']}}, anchors=({'name': 'wall_shower', 'dx': 24, 'dy': -18},),
          note='a walk-in shower standing out into the room: a tiled back wall with its head and riser, a tray coming out with its drain and two bottles, a glass side screen in perspective — soap on a ledge, black mould along the tray')
def shower_walkin(c, ox, oy, p):
    x0 = ox + 8
    def _inside(c_):
        BR.mould_bloom(c_, x0 + 17, 97, 16, 7, seed=13, up=True)
        c_.rect(x0 + 4, 56, x0 + 9, 62, hexc('d7c2a0'))
        c_.rect(x0 + 2, 62, x0 + 11, 63, CHROME_DK)
    BR.shower3d(c, x0, x0 + 28, 16, shade(BR.A_TILE, 0.95), BR.A_GROUT, behind_glass=_inside)


# ================================================================================================================================ the washing machine
@_fixture('washer', 60, 52, rooms={'bathroom': 7}, styles={'wetroom': 9, 'tub': 2, 'avocado': 2},
          tags=('wet', 'laundry'), variants={'open': {'door': True, 'for': ['wetroom']}, 'shut': {'door': False, 'for': ['tub', 'avocado', 'wetroom']}},
          anchors=({'name': 'washer', 'dx': 40, 'dy': -28},),
          note='a front-loader standing out from the wall: a control panel with a soap drawer, display and dial, a chrome-bezelled porthole over the steel drum, a kick plate — with the door swung wide and the wash dragged half out onto the floor, or shut')
def washer(c, ox, oy, p):
    mx = ox + 34
    cx_, cy_, fl, fr, fbr = BR.washing_machine3d(c, mx, top=68, door_open=p['door'])
    if p['door']:
        BR.machine_laundry3d(c, cx_, cy_, fbr[1], int(round((fr[0] - fl[0]) * 0.40)))


# ================================================================================================================================ baskets, buckets, stools
@piece('laundry_basket3d', 30, 20, 'floor', bucketed=True, lean=False, rooms={'bathroom': 7}, styles={'wetroom': 9, 'tub': 5, 'avocado': 4, 'pink': 4, 'gilded': 0.01}, tags=('clutter', 'clothes', 'laundry'),
       variants={'plastic': {'k': 'plastic', 'for': ['wetroom']}, 'wicker': {'k': 'wicker', 'for': ['tub', 'avocado']}, 'white': {'k': 'white', 'for': ['pink']}},
       anchors=({'name': 'laundry_basket', 'dx': 14, 'dy': -10},), feet=(118, 118), near=('wet',),
       note='a laundry basket by the wall: a blue plastic tub with slots, washing heaped in it; a round wicker hamper with a lid and a towel caught under it; or a white wicker one with a pink rim')
def laundry_basket3d(c, ox, oy, p):
    cx = ox + 15
    k = p['k']
    if k == 'plastic':
        BR.laundry_basket3d(c, cx, d_c=7)
    elif k == 'wicker':
        BR.wicker_hamper3d(c, cx)
    else:
        def _hamper(c_):
            c_.shadow(cx, 100, 12, 2, 100)
            c_.poly([(cx - 12, 81), (cx + 12, 81), (cx + 10, 100), (cx - 10, 100)], hexc('efe8d8'))
            for y in range(84, 100, 3):
                c_.hline(cx - 11, cx + 11, y, hexc('d0c8b4'))
            c_.rect(cx - 14, 78, cx + 14, 81, PINK_DK)
            c_.poly([(cx - 8, 78), (cx - 2, 72), (cx + 2, 78)], TOWELS[1])
        setback(c, _hamper, depth=3, top=78, x_range=(cx - 14, cx + 14))


@piece('stool_radio', 24, 38, 'floor', bucketed=True, lean=False, rooms={'bathroom': 5}, styles={'avocado': 9}, tags=('clutter', 'music'),
       variants={'teak': {'for': ['avocado']}}, anchors=({'name': 'radio_stool', 'dx': 12, 'dy': -17},), feet=(118, 118),
       note='a wooden stool against the wall with a transistor radio on it, its aerial up, a speaker grille and a tuning dial')
def stool_radio(c, ox, oy, p):
    BR.stool_radio3d(c, ox + 12)


@piece('mop_bucket3d', 28, 34, 'floor', bucketed=True, lean=False, rooms={'bathroom': 6}, styles={'avocado': 9, 'wetroom': 4, 'tub': 2}, tags=('clutter', 'wet', 'cleaning'),
       variants={'red': {'for': ['avocado', 'wetroom', 'tub']}}, anchors=({'name': 'mop_bucket', 'dx': 14, 'dy': -10},), feet=(118, 118),
       note='a round red mop bucket standing a little out from the wall: grey water inside, the mop head sunk in it and its handle leant back against the wall, a wire handle')
def mop_bucket3d(c, ox, oy, p):
    BR.mop_bucket(c, ox + 1, 100)


@piece('champagne_stand', 18, 38, 'floor', bucketed=True, lean=False, rooms={'bathroom': 5}, styles={'gilded': 9}, tags=('clutter', 'drink'),
       variants={'gold': {'for': ['gilded']}}, anchors=({'name': 'champagne', 'dx': 9, 'dy': -20},), feet=(118, 118),
       note='a gold ice-bucket on a stand beside the tub with a bottle of champagne in it')
def champagne_stand(c, ox, oy, p):
    BR.champagne(c, ox + 2, 118)


@piece('towel_rail', 36, 30, 'decor', rooms={'bathroom': 7}, styles={'tub': 9, 'gilded': 5, 'pink': 3, 'avocado': 2, 'wetroom': 1}, tags=('towels',), wall_y=(68, 70), limit=1,
       variants={'chrome': {'k': 'chrome', 'for': ['tub', 'pink', 'avocado', 'wetroom']}, 'gold': {'k': 'gold', 'for': ['gilded']}},
       note='a towel rail on the wall under the window line: a heated chrome ladder rail with two towels slung over it, or a gold stand with a plush red towel')
def towel_rail(c, ox, oy, p):
    if p['k'] == 'chrome':
        BR.towel_rail(_Off(c, ox - 232, oy - 70), 232, 262, 70)                                      # the old module's rows: the rail's top row (70) lands on the decor origin
    else:
        sub = _Off(c, ox - 232, oy - 67)
        sub.rect(238, 67, 239, 99, GOLD_DK)
        sub.hline(232, 245, 99, GOLD_DK)
        sub.hline(232, 245, 67, GOLD)
        BR.hung_towel(sub, 233, 245, 68, 88, hexc('7a1f2a'))


class _Stay:
    """A canvas proxy for the shower rail: the old module's ceiling stay runs up to row 0, but a planned piece may not reach above the crown moulding (the planner's TOP_MIN_Y 5), so the stay stops at row 6."""

    def __init__(self, c):
        self.c = c

    def vline(self, x, y0, y1, col):
        self.c.vline(x, max(y0, 6), y1, col)

    def __getattr__(self, name):
        return getattr(self.c, name)


class _Off:
    """A canvas proxy that draws a function written in the old module's absolute coordinates at an offset (dx, dy)."""

    def __init__(self, c, dx, dy):
        self.c, self.dx, self.dy = c, dx, dy

    def _pt(self, x, y):
        return x + self.dx, y + self.dy

    def put(self, x, y, col):
        self.c.put(x + self.dx, y + self.dy, col)

    def rect(self, x0, y0, x1, y1, col):
        self.c.rect(x0 + self.dx, y0 + self.dy, x1 + self.dx, y1 + self.dy, col)

    def hline(self, x0, x1, y, col):
        self.c.hline(x0 + self.dx, x1 + self.dx, y + self.dy, col)

    def vline(self, x, y0, y1, col):
        self.c.vline(x + self.dx, y0 + self.dy, y1 + self.dy, col)

    def line(self, x0, y0, x1, y1, col):
        self.c.line(x0 + self.dx, y0 + self.dy, x1 + self.dx, y1 + self.dy, col)

    def box(self, x0, y0, x1, y1, fill, line=None):
        if line is None:
            self.c.box(x0 + self.dx, y0 + self.dy, x1 + self.dx, y1 + self.dy, fill)
        else:
            self.c.box(x0 + self.dx, y0 + self.dy, x1 + self.dx, y1 + self.dy, fill, line)

    def poly(self, pts, col):
        self.c.poly([(x + self.dx, y + self.dy) for (x, y) in pts], col)

    def ellipse(self, cx, cy, rx, ry, col):
        self.c.ellipse(cx + self.dx, cy + self.dy, rx, ry, col)

    def shadow(self, cx, cy, rx, ry, a=100):
        self.c.shadow(cx + self.dx, cy + self.dy, rx, ry, a)

    def dither(self, x0, y0, x1, y1, col, d=0.5, **kw):
        self.c.dither(x0 + self.dx, y0 + self.dy, x1 + self.dx, y1 + self.dy, col, d, **kw)


# ================================================================================================================================ mirrors
@piece('mirror_bath', 36, 36, 'decor', rooms={'bathroom': 9}, styles={'tub': 9, 'avocado': 9, 'gilded': 9, 'wetroom': 9, 'pink': 9}, tags=('picture', 'mirror'), above=('basin',), wall_y=(18, 32), limit=1,
       variants={'cabinet': {'k': 'cabinet', 'for': ['tub']}, 'round_crack': {'k': 'round', 'for': ['avocado']}, 'gilt': {'k': 'gilt', 'for': ['gilded']},
                 'tile': {'k': 'tile', 'for': ['wetroom']}, 'pink_round': {'k': 'pink', 'for': ['pink']}},
       note='the mirror over the basin: a mirrored medicine cabinet with its door swung open on bottles (classic), a cracked round one (avocado), a gilt-framed one with ornate corners (gilded), a cracked mirror tile (wetroom), a round one in a pink frame')
def mirror_bath(c, ox, oy, p):
    k = p['k']
    if k == 'cabinet':
        BR.mirror_cabinet(_Off(c, ox - 24 + 7, oy - 24), 24, 24, 48, 54, hexc('d6d2c4'), PORC_OUT, open_door='left')
    elif k == 'round':
        s = _Off(c, ox - 39 + 11, oy - 38 + 11)
        s.ellipse(39, 38, 9.5, 9.5, hexc('9a8660'))
        s.ellipse(39, 38, 7.5, 7.5, MIRROR)
        s.line(34, 43, 42, 32, MIRROR_HI)
        s.line(35, 33, 44, 42, shade(MIRROR, 0.8))
    elif k == 'gilt':
        s = _Off(c, ox - 24 + 4, oy - 20 + 5)
        BR.gilt_mirror(s, 24, 20, 48, 50)
    elif k == 'tile':
        s = _Off(c, ox - 25 + 5, oy - 30)
        s.box(25, 30, 49, 52, hexc('7a8480'), hexc('3a403e'))
        s.rect(27, 32, 47, 50, MIRROR)
        s.line(29, 48, 44, 34, MIRROR_HI)
        s.line(34, 34, 40, 48, shade(MIRROR, 0.75))
        s.line(40, 48, 45, 42, shade(MIRROR, 0.75))
    else:
        s = _Off(c, ox - 37 + 13, oy - 32 + 13)
        s.ellipse(37, 32, 11, 11, PINK_DK)
        s.ellipse(37, 32, 9, 9, MIRROR)
        s.line(32, 38, 41, 25, MIRROR_HI)


# ================================================================================================================================ the linen cupboard and the chandelier
@piece('linen_cupboard', 34, 54, 'wall', rooms={'bathroom': 6}, styles={'pink': 9, 'tub': 2, 'avocado': 2}, tags=('storage', 'linen'), depth=5,
       variants={'cream': {'for': ['pink', 'tub', 'avocado']}}, anchors=({'name': 'linen_cupboard', 'dx': 16, 'dy': -26},), opens={'kind': 'door_h', 'frames': 3, 'anchor': 'linen_cupboard'}, feet=(105, 108),
       note='a cream linen cupboard with a cornice: open shelves of folded towels and spare rolls over two panelled doors, bun feet; the right-hand door swings open when searched')
def linen_cupboard(c, ox, oy, p):
    s = _Off(c, ox - 278 + 2, oy - 99)
    x0, x1, top = 278, 308, 46
    body, body_dk, trim = hexc('efe8d8'), hexc('c9c0ae'), PINK_DK
    s.shadow(293, 100, 17, 2, 100)
    s.rect(x0 - 1, top - 2, x1 + 1, top, trim)
    s.hline(x0 - 1, x1 + 1, top - 2, shade(trim, 1.2))
    s.box(x0, top + 1, x1, 95, body, PINK_OUT)
    s.rect(x0 + 2, top + 3, x1 - 2, 70, hexc('b8aaa8'))
    s.rect(x0 + 2, 58, x1 - 2, 59, body)
    s.hline(x0 + 2, x1 - 2, 58, shade(body, 1.05))
    for (tx, ty, col) in ((x0 + 4, 53, TOWELS[1]), (x0 + 4, 50, hexc('f4f0e6')), (x0 + 4, 47, TOWELS[1]), (x0 + 16, 54, hexc('f4f0e6')), (x0 + 16, 51, PINK)):
        s.rect(tx, ty, tx + 10, ty + 3, col)
        s.hline(tx, tx + 10, ty + 3, shade(col, 0.8))
        s.vline(tx + 10, ty, ty + 3, shade(col, 0.85))
    for k in range(4):
        rx = x0 + 4 + k * 6
        s.rect(rx, 64, rx + 4, 69, hexc('f4f0e6'))
        s.put(rx + 2, 66, hexc('b8b0a0'))
    s.rect(x0 + 2, 70, x1 - 2, 71, body)
    t = p['open']
    mid = (x0 + x1) // 2
    for k, (d0, d1) in enumerate(((x0 + 2, mid - 1), (mid + 1, x1 - 2))):
        if k == 1 and t > 0:                                                              # the right-hand door swings out on its hinge (the right edge): the leaf narrows as it turns, the dark inside shows
            s.rect(d0, 73, d1, 93, hexc('3a342e'))
            s.hline(d0, d1, 82, shade(hexc('3a342e'), 1.9))                                     # a shelf
            for (tx, ty, col) in ((d0 + 1, 77, TOWELS[1]), (d0 + 1, 86, hexc('f4f0e6'))):
                s.rect(tx, ty, tx + 6, ty + 3, col)
                s.hline(tx, tx + 6, ty + 3, shade(col, 0.8))
            ww = max(3, int(round((d1 - d0) * (1.0 - 0.7 * t))))
            lip = 1 if t >= 0.75 else 0                                                         # its free edge is nearer: a pixel taller
            s.box(d1 - ww, 73 - lip, d1, 93 + lip, body, body_dk)
            s.box(d1 - ww + 2 if ww > 5 else d1 - ww, 75, d1 - 2 if ww > 5 else d1, 91, body, body_dk)
            s.put(d1 - ww + 1, 83, CHROME)
            continue
        s.box(d0, 73, d1, 93, body, body_dk)
        s.box(d0 + 2, 75, d1 - 2, 91, body, body_dk)
    s.put(mid - 3, 83, CHROME)
    if t <= 0:
        s.put(mid + 3, 83, CHROME)
    for fx in (x0 + 1, x1 - 3):
        s.rect(fx, 96, fx + 2, 99, PINK_OUT)


@piece('chandelier', 28, 28, 'ceiling', rooms={'bathroom': 4, 'dining_room': 3}, styles={'gilded': 9, 'formal': 3}, tags=('light', 'ceiling'), lights=({'dx': 14, 'dy': 20, 'kind': 'chandelier'},),
       variants={'gold': {'for': ['gilded', 'formal']}}, note='a gold chandelier on a chain: two tiers of arms with candles, crystals hanging below')
def chandelier(c, ox, oy, p):
    BR.chandelier(_Off(c, ox - 12 + 14, oy - 5), 12)


# ================================================================================================================================ mats
@piece('bath_mat', 94, 14, 'rug', rooms={'bathroom': 8}, styles={'avocado': 8, 'pink': 8, 'gilded': 8, 'tub': 4}, tags=('rug',), feet=(120, 124),
       variants={'shag_gold': {'col': 'd9a24a', 'dk': 'b8863a', 'for': ['avocado', 'tub']}, 'fluffy_pink': {'col': 'efc4cc', 'dk': 'e0a8b4', 'for': ['pink']},
                 'leopard': {'col': 'c89a4a', 'dk': '4a3220', 'leopard': True, 'for': ['gilded']}},
       note='a bath mat flat on the floor: a shaggy gold one, a fluffy pink one, or a leopard-skin rug under the gold tub')
def bath_mat(c, ox, oy, p):
    col = hexc(p['col'])
    top, bot = oy - 11, oy - 1
    for y in range(top, bot + 1):
        f = (y - top) / float(bot - top)
        inset = int(round(3.5 * (1.0 - f)))
        for x in range(ox + 3 + inset, ox + 90 - inset):
            c.put(x, y, shade(col, 0.9 + 0.2 * ((x * 7 + y * 13) % 5) / 4.0))
    if p.get('leopard'):
        rng = random.Random(7)
        for _ in range(24):
            x, y = rng.randint(ox + 8, ox + 84), rng.randint(top + 2, bot - 1)
            c.rect(x, y, x + 2, y + 1, hexc(p['dk']))
    else:
        c.hline(ox + 4, ox + 88, top, shade(col, 1.15))
        c.hline(ox + 3, ox + 90, bot, shade(col, 0.72))
