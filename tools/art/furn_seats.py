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


def extrude_yz(m, poly, x0, x1, part, mat):
    """A solid from a side-view outline: `poly` is [(y, z)…] (convex-ish), thickness from x0 to x1. Faces on both sides and round the edge."""
    n = len(poly)
    m.add([(x0, y, z) for (y, z) in poly], part, mat)
    m.add([(x1, y, z) for (y, z) in reversed(poly)], part, mat)
    for i in range(n):
        (ya, za), (yb, zb) = poly[i], poly[(i + 1) % n]
        m.add([(x0, ya, za), (x1, ya, za), (x1, yb, zb), (x0, yb, zb)], part, mat)


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
def horse_model():
    """A rocking horse, head toward -y (the chairs' front): side-view outlines extruded across its width. Units are px."""
    m = C3.Model()
    # two curved runners joined by a stretcher: each a strip of short segments along an arc, rising at both ends
    n = 9
    for sx in (-4.4, 4.4):
        for k in range(n):
            ya, yb = -15.0 + 30.0 * k / n, -15.0 + 30.0 * (k + 1) / n
            za = 4.2 * (abs(ya) / 15.0) ** 2
            zb = 4.2 * (abs(yb) / 15.0) ** 2
            extrude_yz(m, [(ya, za), (yb, zb), (yb, zb + 2.0), (ya, za + 2.0)], sx - 0.8, sx + 0.8, 'rocker%d' % (sx > 0), 'rocker')
    m.box(-4.4, 4.4, -0.5, 0.5, 1.2, 2.4, 'stretch', 'rocker')
    # four legs, splayed a little, from the runners up under the body
    for sx in (-3.4, 3.4):
        extrude_yz(m, [(-10.4, 3.4), (-8.9, 3.4), (-6.2, 9.0), (-8.0, 9.0)], sx - 0.8, sx + 0.8, 'legf%d' % (sx > 0), 'wood')
        extrude_yz(m, [(9.4, 3.4), (10.9, 3.4), (8.4, 9.0), (6.6, 9.0)], sx - 0.8, sx + 0.8, 'legb%d' % (sx > 0), 'wood')
    # the body, a bevelled barrel
    m.box(-4.2, 4.2, -9.0, 10.0, 8.5, 15.2, 'body', 'wood', bevel=1.5)
    # the neck, the head with its long face, the ears, the mane
    extrude_yz(m, [(-3.0, 14.2), (-7.4, 23.4), (-11.4, 22.8), (-9.4, 14.2)], -2.6, 2.6, 'neck', 'wood')
    extrude_yz(m, [(-9.6, 23.8), (-14.0, 23.8), (-19.2, 19.6), (-19.4, 16.4), (-16.6, 15.4), (-11.0, 19.4)], -2.3, 2.3, 'head', 'wood')
    for sx in (-1.6, 1.6):
        extrude_yz(m, [(-9.4, 23.6), (-8.6, 27.4), (-7.4, 23.4)], sx - 0.5, sx + 0.5, 'ear%d' % (sx > 0), 'wood')
    extrude_yz(m, [(-3.0, 14.6), (-7.6, 24.2), (-8.6, 23.6), (-4.6, 14.2)], -0.7, 0.7, 'mane', 'mane')
    extrude_yz(m, [(-9.8, 23.6), (-11.6, 24.2), (-12.2, 22.4), (-10.0, 22.2)], -0.7, 0.7, 'forelock', 'mane')
    extrude_yz(m, [(9.8, 14.4), (13.4, 13.0), (15.4, 6.0), (13.6, 5.6), (11.6, 10.4)], -1.0, 1.0, 'tail', 'mane')
    # the saddle, the handles across the neck, the eyes
    m.box(-4.7, 4.7, -2.0, 5.5, 14.8, 16.8, 'saddle', 'saddle', bevel=0.7)
    m.box(-5.8, 5.8, -10.0, -9.0, 19.4, 20.4, 'handle', 'rocker')
    for sx in (-5.8, 5.8):
        m.box(sx - 0.7, sx + 0.7, -10.2, -8.8, 19.2, 20.6, 'knob%d' % (sx > 0), 'rocker')
    for sx in (-2.55, 2.55):
        m.box(sx - 0.3, sx + 0.3, -14.6, -13.6, 20.6, 21.6, 'eye%d' % (sx > 0), 'eye')
    return m


HORSES = {'white': dict(wood=hexc('e2dccb'), mane=hexc('4a3a30'), saddle=hexc('b0453a'), rocker=hexc('a07848')),
          'grey': dict(wood=hexc('9ca0a8'), mane=hexc('34363c'), saddle=hexc('3a5a7a'), rocker=hexc('8a6844')),
          'brown': dict(wood=hexc('8a5a3a'), mane=hexc('2a1c14'), saddle=hexc('c4a040'), rocker=hexc('6a4a2c')),
          'white_blood': dict(wood=hexc('d8d0bc'), mane=hexc('4a3a30'), saddle=hexc('8a3a34'), rocker=hexc('8a6a44'), blood=True)}


def _horse_variants():
    v = {}
    for k in HORSES:
        for yn, yaw in (('l', 62), ('r', -62), ('fl', 28), ('fr', -28)):
            v['%s_%s' % (k, yn)] = {'horse': k, 'yaw': yaw}
    return v


@piece('rocking_horse', 36, 30, 'floor', rooms={'bedroom': 4, 'living_room': 3}, styles={'kid': 8}, tags=('toy',), variants=_horse_variants(), anchors=({'name': 'rocking_horse', 'dx': 18, 'dy': -17},),
       near=('sleeping',), feet=(116, 121), note='a rocking horse on its curved rockers: painted white, grey or brown — one in four is bloodied, as if a child had been taken off it in a hurry')
def rocking_horse(c, ox, oy, p):
    spec = HORSES[p['horse']]
    pal = {'wood': spec['wood'], 'mane': spec['mane'], 'saddle': spec['saddle'], 'rocker': spec['rocker'], 'eye': hexc('18120e')}
    r = C3.draw_model(c, ox + 18, oy, horse_model(), p['yaw'], pal, srad=15)
    if r and spec.get('blood'):
        cbuf, pbuf, sbuf = r
        rng = random.Random(41 + int(p['yaw']))
        C3._bloody(c, ox + 18, oy, cbuf, pbuf, sbuf, rng, heavy=False, fallen=False,
                   blobs=[((0.0, -6.0, 18.0), 3.2), ((0.0, 1.0, 15.2), 4.6)], skip=('rocker', 'stretch', 'eye'))
