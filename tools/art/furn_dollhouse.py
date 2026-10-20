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

HOUSES = {
    'cream': dict(frame=hexc('e8dcc0'), trim=hexc('c9b890'), roof=hexc('a8423a'), chimney=hexc('8a4a3a'), kitchen=(hexc('9fd0bb'), hexc('d8efe4')), bedroom=(hexc('e8c85a'), hexc('f2dc8a')),
                 bath=(hexc('e8eef0'), hexc('9ac0d8')), dark=hexc('1a1826')),
    'blue': dict(frame=hexc('9ab4d0'), trim=hexc('e8e4d8'), roof=hexc('5a5e6a'), chimney=hexc('7a5a4a'), kitchen=(hexc('e8d49a'), hexc('f4e8bc')), bedroom=(hexc('d8a0b0'), hexc('ecc4d0')),
                 bath=(hexc('d8e8d8'), hexc('8ab8a0')), dark=hexc('181c26')),
    'green': dict(frame=hexc('5a8a72'), trim=hexc('e8dcc0'), roof=hexc('6a4a36'), chimney=hexc('9a5a44'), kitchen=(hexc('e8e0c8'), hexc('b8c8a8')), bedroom=(hexc('b8a0d0'), hexc('d4c4e4')),
                 bath=(hexc('e4ecf0'), hexc('88a8c0')), dark=hexc('181a20')),
}


def _room_bg(c, x0, y0, x1, y1, a, b, kind):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if kind == 'stripe':
                col = a if (x - x0) % 3 else b
            elif kind == 'dots':
                col = b if ((x - x0) % 4 == 1 and (y - y0) % 4 == 2) else a
            elif kind == 'tile':
                col = b if ((x - x0) % 3 == 0 or (y - y0) % 3 == 0) else a
            else:
                col = a
            c.put(x, y, col)
    c.hline(x0, x1, y0, shade(a, 0.7))                                  # the shadow under the ceiling
    c.hline(x0, x1, y0 + 1, shade(a, 0.86))
    c.hline(x0, x1, y1, hexc('7a5a3a'))                                  # the boards
    c.hline(x0, x1, y1 - 1, shade(a, 0.78))                              # the skirting


def _window(c, x, y, w, h, curtain=None):
    c.rect(x, y, x + w - 1, y + h - 1, hexc('8ab8e0'))
    c.hline(x, x + w - 1, y, hexc('d8ecf8'))
    c.vline(x + w // 2, y, y + h - 1, hexc('f4f0e4'))
    c.hline(x, x + w - 1, y + h // 2, hexc('f4f0e4'))
    if curtain is not None:
        c.vline(x - 1, y - 1, y + h, curtain)
        c.vline(x + w, y - 1, y + h, curtain)


@piece('dollhouse_table', 41, 58, 'wall', rooms={'bedroom': 4, 'living_room': 2}, styles={'kid': 8}, tags=('toy',), depth=4, surface_h=19,
       variants={k: {'house': k} for k in HOUSES}, anchors=({'name': 'dollhouse', 'dx': 20, 'dy': -29},), feet=(105, 108),
       note="a dolls' house on a low pine table: two storeys open at the front — kitchen, bedroom, bath, and one dark room with a small pale doll standing in it")
def dollhouse_table(c, ox, oy, p):
    H = HOUSES[p['house']]
    L = K.Layer(c)
    lc = L.c
    ty = oy - 19                                                        # the table top
    # --- the table: pine top with a lit edge, turned legs, a stretcher
    lc.shadow(ox + 20, oy + 1, 20, 2, 90)
    for lx in (ox + 3, ox + 36):
        for y in range(ty + 3, oy + 1):
            lc.put(lx, y, shade(PINE, 0.95))
            lc.put(lx + 1, y, shade(PINE, 0.68))
        lc.put(lx, ty + 8, shade(PINE, 1.2))
        lc.rect(lx - 1, oy - 1, lx + 2, oy, shade(PINE, 0.6))
    lc.hline(ox + 4, ox + 37, oy - 7, shade(PINE, 0.8))
    lc.hline(ox + 4, ox + 37, oy - 6, shade(PINE, 0.6))
    lc.rect(ox, ty, ox + 40, ty + 2, PINE)
    lc.hline(ox, ox + 40, ty, shade(PINE, 1.3))
    lc.hline(ox, ox + 40, ty + 2, shade(PINE, 0.62))
    lc.hline(ox + 1, ox + 39, ty + 3, shade(PINE, 0.5))
    # --- the house: a plinth, then two floors of two rooms
    hx0, hx1 = ox + 5, ox + 35
    by = ty - 1
    lc.rect(hx0 - 1, by - 1, hx1 + 1, by, shade(H['frame'], 0.7))                     # the base board
    f1y0, f1y1 = by - 11, by - 2                                                        # floor 1 interior rows
    f2y0, f2y1 = by - 23, by - 14
    mid = ox + 20
    # the rooms' papers
    _room_bg(lc, hx0 + 2, f1y0, mid - 1, f1y1, H['kitchen'][0], H['kitchen'][1], 'stripe')
    _room_bg(lc, mid + 2, f1y0, hx1 - 2, f1y1, H['dark'], shade(H['dark'], 1.5), 'plain')
    _room_bg(lc, hx0 + 2, f2y0, mid - 1, f2y1, H['bedroom'][0], H['bedroom'][1], 'dots')
    _room_bg(lc, mid + 2, f2y0, hx1 - 2, f2y1, H['bath'][0], H['bath'][1], 'tile')
    # the frame: side walls, party wall, floor slabs (a lit top, a shaded underside), the underside of the roof
    fr, tr = H['frame'], H['trim']
    for (xa, xb) in ((hx0, hx0 + 1), (hx1 - 1, hx1)):
        lc.rect(xa, f2y0 - 2, xb, by - 2, fr)
        lc.vline(xa, f2y0 - 2, by - 2, shade(fr, 1.15))
        lc.vline(xb, f2y0 - 2, by - 2, shade(fr, 0.72))
    lc.rect(mid, f2y0, mid + 1, by - 2, shade(fr, 0.92))
    lc.vline(mid, f2y0, by - 2, shade(fr, 1.1))
    for sy in (f1y0 - 2, f2y1 + 1, f2y0 - 2):
        lc.rect(hx0, sy, hx1, sy + 1, tr)
        lc.hline(hx0, hx1, sy, shade(tr, 1.2))
        lc.hline(hx0, hx1, sy + 1, shade(tr, 0.62))
    lc.hline(hx0 + 2, hx1 - 2, f2y1 + 2, shade(fr, 0.55))                                # the shadow under the upper floor
    # --- the furniture, tiny: kitchen (counter, stove, pot, window), the dark room (a moonlit window and a doll), bedroom (bed, window, curtains), bath (tub, mirror, duck)
    kx = hx0 + 2
    lc.rect(kx, f1y1 - 5, kx + 6, f1y1 - 1, hexc('8a6a44'))
    lc.hline(kx, kx + 6, f1y1 - 5, hexc('d8c8a0'))
    lc.vline(kx + 3, f1y1 - 4, f1y1 - 1, hexc('5a4630'))
    lc.rect(kx + 8, f1y1 - 5, kx + 11, f1y1 - 1, hexc('9aa0a6'))
    lc.hline(kx + 8, kx + 11, f1y1 - 5, hexc('dde2e6'))
    lc.put(kx + 9, f1y1 - 4, hexc('2a2a2e'))
    lc.rect(kx + 9, f1y1 - 7, kx + 10, f1y1 - 6, hexc('b0453a'))
    lc.put(kx + 8, f1y1 - 7, hexc('b0453a'))
    _window(lc, kx + 6, f1y0 + 2, 3, 3)
    lc.put(kx + 3, f1y0 + 2, hexc('e8c85a'))
    lc.vline(kx + 3, f1y0 + 1, f1y0 + 1, hexc('3a3a3a'))
    dx0 = mid + 2
    lc.rect(dx0 + 8, f1y0 + 2, dx0 + 10, f1y0 + 4, hexc('3a4a6a'))                       # a window the moon shows through, barely
    lc.hline(dx0 + 8, dx0 + 10, f1y0 + 2, hexc('6a7aa0'))
    lc.rect(dx0 + 3, f1y1 - 1, dx0 + 6, f1y1 - 1, hexc('0e0c14'))                        # its shadow on the floor
    lc.rect(dx0 + 4, f1y1 - 4, dx0 + 5, f1y1 - 2, hexc('d8d0c0'))                        # the doll: a pale dress,
    lc.put(dx0 + 3, f1y1 - 2, hexc('d8d0c0')); lc.put(dx0 + 6, f1y1 - 2, hexc('d8d0c0'))
    lc.rect(dx0 + 4, f1y1 - 6, dx0 + 5, f1y1 - 5, hexc('e8cdb0'))                         # a face turned to the room,
    lc.put(dx0 + 4, f1y1 - 7, hexc('120e0a')); lc.put(dx0 + 5, f1y1 - 7, hexc('120e0a'))     # dark hair,
    lc.put(dx0 + 3, f1y1 - 6, hexc('120e0a')); lc.put(dx0 + 6, f1y1 - 6, hexc('120e0a'))
    lc.put(dx0 + 4, f1y1 - 5, hexc('1a1010'))                                             # and two dark eyes
    bx = hx0 + 2
    lc.rect(bx, f2y1 - 3, bx + 8, f2y1 - 1, hexc('7a5a3a'))                               # the bed
    lc.rect(bx + 1, f2y1 - 4, bx + 8, f2y1 - 3, hexc('d98aa0'))
    lc.hline(bx + 1, bx + 8, f2y1 - 4, hexc('ecb0c0'))
    lc.rect(bx + 1, f2y1 - 5, bx + 3, f2y1 - 4, hexc('f4f0e8'))
    lc.vline(bx, f2y1 - 6, f2y1 - 1, hexc('5a3e24'))
    _window(lc, bx + 9, f2y0 + 2, 3, 3, curtain=hexc('6a8ab8'))
    lc.put(bx + 4, f2y0 + 2, hexc('c8a8d8'))
    tx = mid + 2
    lc.rect(tx + 1, f2y1 - 4, tx + 9, f2y1 - 1, hexc('f4f4f0'))                           # the bath
    lc.hline(tx + 1, tx + 9, f2y1 - 4, hexc('ffffff'))
    lc.rect(tx + 2, f2y1 - 4, tx + 8, f2y1 - 3, hexc('7ab8e0'))
    lc.put(tx + 7, f2y1 - 5, hexc('f0d440')); lc.put(tx + 8, f2y1 - 5, hexc('f0d440'))   # the duck
    lc.put(tx + 1, f2y1 - 6, hexc('b8bcc0')); lc.put(tx + 1, f2y1 - 5, hexc('b8bcc0'))
    lc.rect(tx + 10, f2y0 + 2, tx + 12, f2y0 + 5, hexc('b8c8d0'))                         # a mirror
    lc.line(tx + 10, f2y0 + 5, tx + 12, f2y0 + 3, hexc('f0f8fc'))
    # --- the roof: a shingled front slope with overhanging eaves, a ridge cap, a brick chimney, a round attic window under it
    ry1 = f2y0 - 3                                                                         # the eave
    ry0 = ry1 - 12                                                                          # the ridge
    roof = H['roof']
    k = 0
    for y in range(ry0, ry1 + 1):
        f = (y - ry0) / float(ry1 - ry0)
        xa = int(round(hx0 + 4 - 6 * f))
        xb = int(round(hx1 - 4 + 6 * f))
        row = (y - ry0) // 2
        for x in range(xa, xb + 1):
            off = (x + (3 if row % 2 else 0)) % 6
            col = shade(roof, 1.12 if (y - ry0) % 2 == 0 else 0.86)
            if off == 0:
                col = shade(roof, 0.62)                                                    # the joints between shingles
            c_ = col
            lc.put(x, y, c_)
    lc.hline(hx0 + 3, hx1 - 3, ry0, shade(roof, 1.4))                                      # the ridge cap
    lc.hline(hx0 + 3, hx1 - 3, ry0 + 1, shade(roof, 0.7))
    lc.hline(hx0 - 2, hx1 + 2, ry1, shade(roof, 0.55))                                     # the eave's drip edge
    lc.hline(hx0 - 2, hx1 + 2, ry1 + 1, shade(roof, 0.4))
    chx = hx1 - 9
    lc.rect(chx, ry0 - 6, chx + 4, ry0 + 5, H['chimney'])                                  # a brick chimney, mortar lines, a cap
    for yy in range(ry0 - 4, ry0 + 5, 2):
        lc.hline(chx, chx + 4, yy, shade(H['chimney'], 0.7))
    lc.vline(chx, ry0 - 6, ry0 + 5, shade(H['chimney'], 1.2))
    lc.vline(chx + 4, ry0 - 6, ry0 + 5, shade(H['chimney'], 0.7))
    lc.rect(chx - 1, ry0 - 7, chx + 5, ry0 - 6, shade(H['chimney'], 0.55))
    lc.hline(chx - 1, chx + 5, ry0 - 7, shade(H['chimney'], 1.1))
    L.flush()
