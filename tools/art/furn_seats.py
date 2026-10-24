"""CHAIRS AND A ROCKING HORSE — built as little 3D models and turned into pixel art (tools/art/chair3d.py renders them with the rooms' own view and light), so a piece has real
volume from any angle instead of being a flat picture (owner round 47b: "the bean bag is hard to identify… replace it with a chair, children's chair or even a blood stained rocking horse
or something, again with better depth and detail not a flat 2D image").

  chair_wood      a plain wooden chair (ladder-back or spindle-back, rush / cloth seat), turned a few ways; one wears a cardigan thrown over its back
  chair_child     the same make at 0.7 scale in painted colours — a child's chair
  rocking_horse   curved rockers, splayed legs, a body, a neck with a real head, ears, a mane and tail, a saddle, handles; painted white / grey / brown — and a bloodied one
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chair3d as C3
import furnlib as FL
from furnlib import piece
from pixlib import hexc, shade


def scaled(m, k):
    out = C3.Model()
    for (pts, part, mat, src) in m.faces:
        out.faces.append(([(x * k, y * k, z * k) for (x, y, z) in pts], part, mat, [(x * k, y * k, z * k) for (x, y, z) in src]))
    return out


from toys3d import extrude_yz                                                                  # the side-view-outline-to-solid helper (furn_medical imports it from here)


# ================================================================================================================================ a wooden chair
WOODS = {'oak': hexc('9a7448'), 'dark': hexc('4e3626'), 'white': hexc('d8d2c0'), 'green': hexc('5a7a5e')}
SEATS = {'rush': hexc('c8a860'), 'cloth': hexc('a8584e'), 'blue': hexc('4a6a8a')}


def _chair_variants():
    v = {}
    for style in ('ladder', 'spindle'):
        for wk, sk in (('oak', 'rush'), ('dark', 'cloth'), ('white', 'blue'), ('green', 'rush')):
            for yn, yaw in (('f', 0), ('l', 35), ('r', -35)):
                v['%s_%s_%s' % (style, wk, yn)] = {'style': style, 'wood': wk, 'seat': sk, 'yaw': yaw, 'cardigan': False}
    v['ladder_oak_f_cardigan'] = {'style': 'ladder', 'wood': 'oak', 'seat': 'rush', 'yaw': 0, 'cardigan': True}
    v['ladder_dark_l_cardigan'] = {'style': 'ladder', 'wood': 'dark', 'seat': 'cloth', 'yaw': 35, 'cardigan': True}
    return v


def _cardigan(c, cx, base_y, cbuf, pbuf, yaw):
    """A cardigan thrown over the top of the chair back: shoulders humped over the rail, the body hanging down the front in a few folds, one sleeve trailing further down."""
    pts = [(x, y) for (x, y) in cbuf if pbuf[(x, y)].startswith(('rail', 'crest', 'post', 'panel'))]
    if not pts:
        return
    top = min(y for (_, y) in pts)
    xs = [x for (x, y) in pts if y <= top + 5]
    x0, x1 = min(xs), max(xs)
    col = hexc('9a4a56')
    tn = [shade(col, f) for f in (0.5, 0.72, 1.0, 1.25)]
    w = max(1, x1 - x0)
    side = 1 if yaw >= 0 else 0                                          # the sleeve trails down the side away from where the chair is turned
    for x in range(x0 - 1, x1 + 2):
        u = (x - x0) / float(w)
        shoulder = 2 if 0.15 < u < 0.85 else 0
        hang = 7 + int(round(1.6 * math.sin(u * 6.0)))
        if (u > 0.82 and side) or (u < 0.18 and not side):
            hang += 5                                                    # the sleeve
        for y in range(top - 1 - shoulder, top + hang):
            f = (y - top) / float(max(1, hang))
            i = 2 + (1 if u < 0.3 else 0) - (1 if f > 0.65 else 0) - (1 if int(u * 9) % 3 == 0 and f > 0.2 else 0)
            c.put(cx + x, base_y + y, tn[max(0, min(3, i))])
        c.put(cx + x, base_y + top + hang - 1, tn[0])
        c.put(cx + x, base_y + top - 2 - shoulder, tn[0])
    for k in range(3):                                                   # buttons down the front
        c.put(cx + x0 + w // 2, base_y + top + 2 + k * 2, hexc('e8dcc0'))
    c.vline(cx + x0 + w // 2 - 1, base_y + top + 1, base_y + top + 6, tn[0])


@piece('chair_wood', 28, 40, 'floor', rooms={'bedroom': 5}, styles={'adult': 3, 'teen': 2, 'sick': 3, 'bedsit': 2}, tags=('seat',), variants=_chair_variants(),
       anchors=(), near=('sleeping', 'wardrobe', 'storage'), feet=(116, 121), limit=1, note='a plain wooden chair — ladder or spindle back, rush or cloth seat; sometimes a cardigan thrown over the back')
def chair_wood(c, ox, oy, p):
    model = C3.dining_chair(p['style'])
    pal = {'wood': WOODS[p['wood']], 'seat': SEATS[p['seat']], 'fab': SEATS[p['seat']]}
    r = C3.draw_model(c, ox + 14, oy, model, p['yaw'], pal, srad=11)
    if r and p['cardigan']:
        _cardigan(c, ox + 14, oy, r[0], r[1], p['yaw'])


# ================================================================================================================================ a child's chair
KID_PAINTS = {'red': hexc('c0453a'), 'blue': hexc('4a7ab0'), 'yellow': hexc('e0b83a'), 'green': hexc('5a9a60'), 'pink': hexc('d98aa0')}


def _kid_chairs():
    v = {}
    for k in KID_PAINTS:
        for yn, yaw in (('f', 0), ('l', 38), ('r', -38)):
            v['%s_%s' % (k, yn)] = {'paint': k, 'yaw': yaw}
    return v


@piece('chair_child', 22, 28, 'floor', rooms={'bedroom': 4}, styles={'kid': 8}, tags=('seat', 'child'), variants=_kid_chairs(), anchors=(), near=('toy', 'sleeping'), feet=(116, 121),
       note="a child's chair in painted wood, turned a little toward the room")
def chair_child(c, ox, oy, p):
    model = scaled(C3.dining_chair('ladder'), 0.68)
    paint = KID_PAINTS[p['paint']]
    pal = {'wood': paint, 'seat': shade(paint, 1.25), 'fab': paint}
    C3.draw_model(c, ox + 11, oy, model, p['yaw'], pal, srad=8)


# ================================================================================================================================ a rocking horse
# the model + its paint live in tools/art/toys3d.py (one source: the baked child's room draws the same horse)
import toys3d as T3
HORSES = T3.HORSES
horse_model = T3.horse_model


def _horse_variants():
    v = {}
    for k in HORSES:
        for yn, yaw in (('l', 62), ('r', -62), ('fl', 28), ('fr', -28)):
            v['%s_%s' % (k, yn)] = {'horse': k, 'yaw': yaw}
    return v


@piece('rocking_horse', 36, 30, 'floor', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8}, tags=('toy',), variants=_horse_variants(), anchors=({'name': 'rocking_horse', 'dx': 18, 'dy': -17},),
       near=('sleeping',), feet=(116, 121), note='a rocking horse on its curved rockers: painted white, grey or brown — one in four is bloodied, as if a child had been taken off it in a hurry')
def rocking_horse(c, ox, oy, p):
    T3.horse(c, ox + 18, oy, p['horse'], p['yaw'])
