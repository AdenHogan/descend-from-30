"""THE SICK ROOM'S EQUIPMENT — an IV drip stand, a wheelchair and a medicine trolley, redrawn (owner round 47b: "everything very flat and very basic looking… more detail and love").

The drip stand is cut to scale (the old one was 87 px, taller than a wardrobe) and has a five-star base on castors, a chrome pole with a collar, two hooks, a bag with a fluid level and a label, a
drip chamber with a drop that still falls (a live `drop` detail), a looping line. The wheelchair is a little 3D model (wheels with spokes and hand rims, casters, frame tubes, sling seat and
back, armrests, footplates, a blanket across the knees) turned toward the room. The trolley is a two-tier steel cart with an enamel basin, a stack of towels, bottles and a first-aid box.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chair3d as C3
import furnlib as FL
import propkit as K
from furnlib import piece
from pixlib import hexc, shade, mix
from furn_seats import extrude_yz

STEEL = hexc('a4adb2')


# ================================================================================================================================ the drip stand
@piece('drip_stand', 16, 62, 'floor', keep='tall', rooms={'bedroom': 4}, styles={'sick': 8, 'adult': 1}, tags=('medical',), variants={'clear': {'liq': 'dcecee'}, 'amber': {'liq': 'e8d49a'}},
       anims=({'kind': 'drop', 'dx': 7, 'dy': -37, 'fall': 3, 'color': 'e8f0f0'},), near=('sleeping',), feet=(114, 118),
       note='an IV drip stand on a five-star castor base: chrome pole, a bag with a fluid level and a label, a drip chamber that still drips, a looped line')
def drip_stand(c, ox, oy, p):
    liq = hexc(p['liq'])
    cx = ox + 8
    K.contact_shadow(c, cx, oy + 0.5, 9, 1.4, 85)
    L = K.Layer(c)
    lc = L.c
    # the base: a hub and five legs, two of them toward us, castors at the ends
    for (dx, dy) in ((-7, 0), (7, 0), (-4, 1), (4, 1), (0, -1)):
        lc.line(cx, oy - 3, cx + dx, oy - 1 + dy, hexc('8a9298'))
        lc.put(cx + dx, oy + dy, hexc('26262a'))
    lc.rect(cx - 1, oy - 5, cx + 1, oy - 3, STEEL)
    # the pole: chrome, a lit left edge, a collar part-way up
    for y in range(oy - 60, oy - 5):
        lc.put(cx, y, hexc('d4dcdf'))
        lc.put(cx + 1, y, hexc('7a848a'))
    lc.rect(cx - 1, oy - 32, cx + 2, oy - 30, hexc('b8c0c4'))
    lc.hline(cx - 1, cx + 2, oy - 30, hexc('5a6468'))
    # the cross bar and its two hooks
    lc.hline(cx - 6, cx + 7, oy - 60, hexc('d4dcdf'))
    lc.hline(cx - 6, cx + 7, oy - 59, hexc('7a848a'))
    lc.put(cx - 6, oy - 58, hexc('c8d0d4')); lc.put(cx + 7, oy - 58, hexc('c8d0d4'))
    # the bag: clear plastic, the fluid level, graduations, a label, a sealed top with a hanging hole
    bx0, bx1 = cx - 9, cx - 4
    for y in range(oy - 58, oy - 44):
        w = 0 if y < oy - 46 else (1 if y == oy - 45 else 2)
        for x in range(bx0 + (1 if y >= oy - 46 and y > oy - 47 else 0), bx1 + 1 - (1 if y >= oy - 46 else 0)):
            level = y >= oy - 53
            lc.put(x, y, shade(liq, 0.96 if level else 1.12) if level else hexc('e8f0f2'))
    lc.vline(bx0, oy - 58, oy - 46, hexc('f6fafb'))
    lc.vline(bx1, oy - 58, oy - 46, hexc('9aa8ae'))
    lc.hline(bx0, bx1, oy - 58, hexc('9aa8ae'))
    lc.hline(bx0 + 1, bx1 - 1, oy - 53, hexc('f6fafb'))                                    # the fluid's surface
    lc.rect(bx0 + 1, oy - 51, bx0 + 3, oy - 47, hexc('f4f4ee'))                           # the label with a red cross
    lc.put(bx0 + 2, oy - 50, hexc('c0453a')); lc.put(bx0 + 2, oy - 49, hexc('c0453a')); lc.put(bx0 + 1, oy - 49, hexc('c0453a')); lc.put(bx0 + 3, oy - 49, hexc('c0453a'))
    for gy in (oy - 55, oy - 52, oy - 49):
        lc.put(bx1 - 1, gy, hexc('5a6468'))
    lc.put(bx0 + 2, oy - 57, hexc('4a5458'))                                                # the hanging hole
    lc.vline(bx0 + 2, oy - 59, oy - 58, hexc('8a9298'))
    # a second, small amber bag on the other hook
    lc.rect(cx + 5, oy - 57, cx + 7, oy - 52, hexc('c8903a'))
    lc.vline(cx + 5, oy - 57, oy - 52, hexc('e8b45a'))
    lc.hline(cx + 5, cx + 7, oy - 52, hexc('8a5a22'))
    # the line from the bag's port: a drip chamber, then a loop trailing down and out
    lc.vline(cx - 6, oy - 44, oy - 41, hexc('c8d4d8'))
    lc.rect(cx - 7, oy - 40, cx - 5, oy - 36, hexc('dce8ec'))
    lc.vline(cx - 7, oy - 40, oy - 36, hexc('f6fafb'))
    lc.vline(cx - 5, oy - 40, oy - 36, hexc('8a9aa0'))
    lc.put(cx - 6, oy - 38, hexc('b8d8e8'))                                                 # the drop that is about to fall
    pts = [(cx - 6, oy - 35), (cx - 5, oy - 31), (cx - 2, oy - 26), (cx + 3, oy - 22), (cx + 8, oy - 20), (cx + 11, oy - 16), (cx + 11, oy - 11)]
    for (a, b) in zip(pts, pts[1:]):
        lc.line(a[0], a[1], b[0], b[1], hexc('b8c8cc'))
    lc.put(cx + 11, oy - 10, hexc('8a9aa0'))
    L.flush()


# ================================================================================================================================ the wheelchair
def _wheel(m, xc, yc, zc, r, thick, part):
    """A wheel with its axis along x: a ring of short segments (the tyre), six spokes, a hub."""
    n = 16
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        r0, r1 = r - 1.6, r
        quad = [(yc + r0 * math.cos(a0), zc + r0 * math.sin(a0)), (yc + r1 * math.cos(a0), zc + r1 * math.sin(a0)),
                (yc + r1 * math.cos(a1), zc + r1 * math.sin(a1)), (yc + r0 * math.cos(a1), zc + r0 * math.sin(a1))]
        extrude_yz(m, quad, xc - thick, xc + thick, '%s_t%d' % (part, k), 'tyre')
    for k in range(6):
        a = math.pi * k / 3.0
        ca, sa = math.cos(a), math.sin(a)
        w = 0.45
        quad = [(yc - w * sa - (r - 1.6) * ca, zc + w * ca - (r - 1.6) * sa), (yc + w * sa - (r - 1.6) * ca, zc - w * ca - (r - 1.6) * sa),
                (yc + w * sa + (r - 1.6) * ca, zc - w * ca + (r - 1.6) * sa), (yc - w * sa + (r - 1.6) * ca, zc + w * ca + (r - 1.6) * sa)]
        extrude_yz(m, quad, xc - 0.25, xc + 0.25, '%s_s%d' % (part, k), 'metal')
    hub = [(yc + 1.4 * math.cos(2 * math.pi * k / 8), zc + 1.4 * math.sin(2 * math.pi * k / 8)) for k in range(8)]
    extrude_yz(m, hub, xc - 0.9, xc + 0.9, part + '_hub', 'metal')


def wheelchair_model():
    """A folding wheelchair, front toward -y (like the chairs). Units are px."""
    m = C3.Model()
    for sx in (-7.6, 7.6):
        _wheel(m, sx, 4.0, 10.0, 10.0, 0.7, 'wheel%d' % (sx > 0))                       # the big wheels
        _wheel(m, sx + (1.5 if sx > 0 else -1.5), 4.0, 10.0, 8.4, 0.25, 'rim%d' % (sx > 0))   # the hand rims, just outside
        extrude_yz(m, [(-10.4, 6.0), (-9.4, 6.0), (-8.0, 13.0), (-9.0, 13.0)], sx * 0.84 - 0.45, sx * 0.84 + 0.45, 'fork%d' % (sx > 0), 'metal')
        _wheel(m, sx * 0.84, -10.0, 2.6, 2.6, 0.5, 'caster%d' % (sx > 0))               # the front casters
        extrude_yz(m, [(-12.4, 7.0), (-11.0, 7.0), (-14.0, 12.5), (-15.4, 12.5)], sx * 0.7 - 0.45, sx * 0.7 + 0.45, 'foot%d' % (sx > 0), 'metal')   # the footrest hangers
        m.box(sx * 0.7 - 1.4, sx * 0.7 + 1.4, -17.4, -13.4, 5.6, 6.6, 'plate%d' % (sx > 0), 'metal')             # the footplates
        m.box(sx - 0.6, sx + 0.6, -9.0, 10.0, 16.4, 17.6, 'rail%d' % (sx > 0), 'metal')                            # the seat rails
        m.box(sx - 0.6, sx + 0.6, -7.0, -6.0, 17.4, 25.0, 'armpost%d' % (sx > 0), 'metal')                        # the armrest posts
        m.box(sx - 1.0, sx + 1.0, -8.0, 4.0, 25.0, 26.2, 'arm%d' % (sx > 0), 'arm')                               # the padded armrests
        m.box(sx - 0.6, sx + 0.6, 8.6, 9.6, 17.0, 33.0, 'back%d' % (sx > 0), 'metal')                              # the back posts
        m.box(sx - 0.6, sx + 0.6, 9.6, 14.0, 32.0, 33.0, 'push%d' % (sx > 0), 'arm')                               # the push handles
    m.box(-6.4, 6.4, -9.0, 9.0, 17.6, 18.6, 'seat', 'fab')                                  # the sling seat
    m.box(-6.4, 6.4, 8.8, 9.8, 19.0, 31.0, 'backrest', 'fab')                               # the sling back
    m.box(-7.4, 7.4, -3.0, -1.6, 14.0, 15.0, 'cross', 'metal')                              # the folding cross brace
    m.box(-6.8, 6.8, -9.0, 4.0, 18.6, 20.6, 'blanket', 'blanket', bevel=0.7)                # a blanket across the knees
    m.box(-6.8, 6.8, -10.4, -9.0, 14.4, 20.6, 'blanket_front', 'blanket')                    # …hanging over the front
    return m


@piece('wheelchair', 33, 36, 'floor', keep='seat', rooms={'bathroom': 2, 'bedroom': 4, 'living_room': 1}, styles={'sick': 8, 'adult': 1}, tags=('medical',),
       variants={'purple_l': {'yaw': 62, 'rug': '7a5a8a'}, 'purple_r': {'yaw': -62, 'rug': '7a5a8a'}, 'green_l': {'yaw': 40, 'rug': '4e6a5a'}, 'tartan_r': {'yaw': -40, 'rug': '8a4a3e'}},
       anchors=({'name': 'wheelchair', 'dx': 16, 'dy': -19},), near=('sleeping',), feet=(116, 120),
       note='a folding wheelchair, turned toward the room: spoked wheels with hand rims, casters, a sling seat and back, a blanket across the seat')
def wheelchair(c, ox, oy, p):
    pal = {'metal': hexc('b4bcc0'), 'tyre': hexc('34343a'), 'fab': hexc('4c4c56'), 'arm': hexc('3a3a40'), 'blanket': hexc(p['rug'])}
    C3.draw_model(c, ox + 16, oy - 2, wheelchair_model(), p['yaw'], pal, srad=15)


# ================================================================================================================================ the medicine trolley
@piece('med_trolley', 34, 38, 'floor', keep='stand', rooms={'bedroom': 4}, styles={'sick': 8}, tags=('medical',), variants={'a': {}, 'b': {'alt': True}},
       anchors=({'name': 'med_trolley', 'dx': 10, 'dy': -28},), near=('sleeping',), feet=(116, 120),
       note='a two-tier steel medicine trolley on castors: an enamel basin, a stack of towels, bottles on the top tray; a first-aid box and a folded blanket below')
def med_trolley(c, ox, oy, p):
    alt = p.get('alt', False)
    K.contact_shadow(c, ox + 17, oy + 0.5, 19, 1.8, 100)
    L = K.Layer(c)
    lc = L.c
    steel, steel_dk = hexc('c4ccd0'), hexc('6e787e')
    x0, x1 = ox + 2, ox + 31
    top_y, low_y = oy - 27, oy - 10
    for lx in (x0, x1 - 1):                                                                    # the legs, a lit left edge, castors
        for y in range(top_y, oy - 1):
            lc.put(lx, y, hexc('dce2e6'))
            lc.put(lx + 1, y, steel_dk)
        lc.rect(lx - 1, oy - 1, lx + 2, oy, hexc('26262a'))
        lc.put(lx, oy - 1, hexc('5a5a60'))
    for (ya, th) in ((low_y, 2), (top_y, 2)):                                                  # the two trays, each with a raised lip
        lc.rect(x0 - 1, ya, x1 + 2, ya + th - 1, steel)
        lc.hline(x0 - 1, x1 + 2, ya, hexc('f0f4f6'))
        lc.hline(x0 - 1, x1 + 2, ya + th, steel_dk)
        lc.put(x0 - 1, ya - 1, steel); lc.put(x1 + 2, ya - 1, steel)
    # on the top tray: an enamel basin, a stack of towels, bottles
    K.frustum(lc, ox + 10, top_y - 6, top_y - 1, 7.0, 5.4, hexc('e8e4d4'), ry_t=2.0, ry_b=1.4, inner=hexc('9fb0b4'), rim=hexc('3a6a9a'), gloss=True)
    lc.hline(ox + 4, ox + 16, top_y - 6, hexc('3a6a9a'))
    for k, (col, w) in enumerate(((hexc('f2efe4'), 9), (hexc('6e8fb0'), 8), (hexc('f2efe4'), 9))):    # folded towels
        y = top_y - 2 - k * 2
        lc.rect(ox + 18, y - 1, ox + 18 + w, y, col)
        lc.hline(ox + 18, ox + 18 + w, y - 1, shade(col, 1.25))
        lc.hline(ox + 18, ox + 18 + w, y, shade(col, 0.74))
    for (bx, h, glass, cap, lab) in ((ox + 28, 8, hexc('c2701e'), hexc('ece8dc'), hexc('ece6d6')), (ox + 24, 6, hexc('dcd8c0'), hexc('3a6a9a'), None)):
        for y in range(top_y - h, top_y):
            for x in range(bx, bx + 3):
                lc.put(x, y, shade(glass, 1.25 - 0.3 * (x - bx)))
        lc.rect(bx, top_y - h - 1, bx + 2, top_y - h, cap)
        if lab:
            lc.rect(bx, top_y - h + 3, bx + 2, top_y - h + 5, lab)
    # on the lower tray: a first-aid box with a white cross, a folded blanket
    lc.rect(ox + 5, low_y - 6, ox + 15, low_y - 1, hexc('e8e8e0'))
    lc.hline(ox + 5, ox + 15, low_y - 6, hexc('ffffff'))
    lc.hline(ox + 5, ox + 15, low_y - 1, hexc('a8a89c'))
    lc.rect(ox + 9, low_y - 5, ox + 11, low_y - 2, hexc('c0453a'))
    lc.rect(ox + 8, low_y - 4, ox + 12, low_y - 3, hexc('c0453a'))
    lc.rect(ox + 18, low_y - 4, ox + 28, low_y - 1, hexc('6e7f95') if not alt else hexc('8a6a5a'))
    lc.hline(ox + 18, ox + 28, low_y - 4, shade(hexc('6e7f95') if not alt else hexc('8a6a5a'), 1.3))
    lc.hline(ox + 18, ox + 28, low_y - 2, shade(hexc('6e7f95') if not alt else hexc('8a6a5a'), 0.7))
    L.flush()
