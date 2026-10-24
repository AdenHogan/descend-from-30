"""A DOLLS' HOUSE WITH A SHAPE (owner round 48i: "the doll house is still a flat object on the back. It has no depth or shape to it").

The old ones were a rectangle with four coloured squares and a triangle. This one is a little building seen the way the room is drawn (a camera at the ceiling over the room's middle, so the
side of the house that faces the middle shows): a FRONT FACE open like a real dolls' house — two storeys of papered rooms with their floor slabs seen from a little above, a party wall, the
rooms' inner side walls, tiny furniture with a lit and a shaded side — a SIDE FACE receding toward the vanishing point with its own window, and a gabled ROOF of shingled planes: the front
slope, a hip end over the side, a ridge cap, eaves that overhang and throw a shadow, and a brick chimney. It stands on a plinth.

`draw(c, fx0, base_y, scheme, side)` -> (front x0, front x1, top y): paint on a pixlib Canvas `c`; `base_y` = the row the plinth stands on (the table top); `side` 'r' = the right face shows (a
house left of the room's middle), 'l' = the left face shows.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import hexc, shade, mix

W_FRONT = 30
STOREY = 11
SIDE_DX = 6                 # how far the side face recedes (px across)
SIDE_RISE = 3               # …and how much its far edges lift toward the horizon

SCHEMES = {
    'cream': dict(frame=hexc('e8dcc0'), trim=hexc('c9b890'), roof=hexc('a8423a'), brick=hexc('8a4a3a'),
                  r11=(hexc('9fd0bb'), hexc('d8efe4')), r12=(hexc('1a1826'), hexc('2c2a40')), r21=(hexc('e8c85a'), hexc('f2dc8a')), r22=(hexc('e8eef0'), hexc('9ac0d8'))),
    'blue': dict(frame=hexc('9ab4d0'), trim=hexc('e8e4d8'), roof=hexc('5a5e6a'), brick=hexc('7a5a4a'),
                 r11=(hexc('e8d49a'), hexc('f4e8bc')), r12=(hexc('181c26'), hexc('2a3042')), r21=(hexc('d8a0b0'), hexc('ecc4d0')), r22=(hexc('d8e8d8'), hexc('8ab8a0'))),
    'green': dict(frame=hexc('6a9a82'), trim=hexc('e8dcc0'), roof=hexc('6a4a36'), brick=hexc('9a5a44'),
                  r11=(hexc('e8e0c8'), hexc('b8c8a8')), r12=(hexc('181a20'), hexc('2c3038')), r21=(hexc('b8a0d0'), hexc('d4c4e4')), r22=(hexc('e4ecf0'), hexc('88a8c0'))),
    'red': dict(frame=hexc('c8a89a'), trim=hexc('f0e4d4'), roof=hexc('3a5a7a'), brick=hexc('a85a46'),
                r11=(hexc('f0d8a0'), hexc('f8ecc8')), r12=(hexc('1a1620'), hexc('302a3a')), r21=(hexc('a8c8d8'), hexc('d0e4ee')), r22=(hexc('e8e0d0'), hexc('c8a098'))),
}


def _paper(c, x0, y0, x1, y1, a, b, kind, lit_left=True):
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
            # the room is lit from the open front and the left: the back wall is brightest toward the left, the right dims a little
            f = 1.04 - 0.14 * (x - x0) / max(1.0, float(x1 - x0))
            c.put(x, y, shade(col, f))
    for x in range(x0, x1 + 1):
        c.put(x, y0, shade(a, 0.62))                                  # the shadow the ceiling throws
        c.put(x, y0 + 1, shade(a, 0.84))
        c.put(x, y1 - 1, shade(a, 0.78))                              # the skirting
        c.put(x, y1, hexc('8a6a44'))                                  # the boards


def _box(c, x0, y0, x1, y1, col):
    """A tiny block of furniture: lit face, shaded right edge, a lit top row."""
    c.rect(x0, y0, x1, y1, col)
    c.vline(x1, y0, y1, shade(col, 0.66))
    c.hline(x0, x1, y0, shade(col, 1.3))
    c.hline(x0, x1, y1, shade(col, 0.72))


def _furnish(c, x0, floor_y, kind):
    if kind == 'kitchen':
        _box(c, x0, floor_y - 5, x0 + 6, floor_y - 1, hexc('8a6a44'))                    # a counter
        c.hline(x0, x0 + 6, floor_y - 6, hexc('d8c8a0'))
        _box(c, x0 + 8, floor_y - 5, x0 + 11, floor_y - 1, hexc('9aa0a6'))              # a stove
        c.put(x0 + 9, floor_y - 4, hexc('2a2a2e'))
        _box(c, x0 + 9, floor_y - 8, x0 + 10, floor_y - 6, hexc('b0453a'))              # a pot on it
        c.hline(x0 + 8, x0 + 11, floor_y - 9, hexc('d8d0c0'))
    elif kind == 'bedroom':
        c.rect(x0, floor_y - 3, x0 + 9, floor_y - 1, hexc('7a5a3a'))                      # a bed: frame,
        c.rect(x0 + 1, floor_y - 5, x0 + 9, floor_y - 3, hexc('d98aa0'))                   # a quilt,
        c.hline(x0 + 1, x0 + 9, floor_y - 5, hexc('ecb0c0'))
        c.rect(x0 + 1, floor_y - 6, x0 + 3, floor_y - 5, hexc('f4f0e8'))                  # a pillow,
        c.vline(x0, floor_y - 7, floor_y - 1, hexc('5a3e24'))                              # and a headboard
        c.vline(x0 + 9, floor_y - 4, floor_y - 1, hexc('5a3e24'))
    elif kind == 'bath':
        _box(c, x0, floor_y - 4, x0 + 8, floor_y - 1, hexc('f4f4f0'))                    # a tub
        c.rect(x0 + 1, floor_y - 4, x0 + 7, floor_y - 3, hexc('7ab8e0'))
        c.put(x0 + 6, floor_y - 5, hexc('f0d440')); c.put(x0 + 7, floor_y - 5, hexc('f0d440'))   # the duck
        c.vline(x0 - 1, floor_y - 6, floor_y - 4, hexc('b8bcc0'))                          # a tap
    elif kind == 'dark':
        c.rect(x0 + 1, floor_y - 2, x0 + 5, floor_y - 1, hexc('0e0c14'))                  # its shadow on the floor
        c.rect(x0 + 2, floor_y - 5, x0 + 4, floor_y - 2, hexc('d8d0c0'))                  # the doll: a pale dress,
        c.put(x0 + 1, floor_y - 2, hexc('d8d0c0')); c.put(x0 + 5, floor_y - 2, hexc('d8d0c0'))
        c.rect(x0 + 2, floor_y - 7, x0 + 4, floor_y - 6, hexc('e8cdb0'))                  # a face turned to the room
        c.hline(x0 + 2, x0 + 4, floor_y - 8, hexc('120e0a'))
        c.put(x0 + 2, floor_y - 7, hexc('1a1010')); c.put(x0 + 4, floor_y - 7, hexc('1a1010'))


def _window(c, x, y, w, h, curtain=None):
    c.rect(x, y, x + w - 1, y + h - 1, hexc('8ab8e0'))
    c.hline(x, x + w - 1, y, hexc('d8ecf8'))
    c.vline(x + w // 2, y, y + h - 1, hexc('f4f0e4'))
    c.hline(x, x + w - 1, y + h // 2, hexc('f4f0e4'))
    if curtain is not None:
        c.vline(x - 1, y - 1, y + h, curtain)
        c.vline(x + w, y - 1, y + h, curtain)


def draw(c, fx0, base_y, scheme='cream', side='r', top_col=None):
    """`top_col` = the colour of the table top the house stands on: when given, the top SURFACE is drawn under the whole footprint (owner round 48i: "the backs of the houses float beyond
    the table" - the side face recedes and rises toward the vanishing point, and its base hung in the air above a table whose top showed only a sliver)."""
    S = SCHEMES[scheme]
    fr, tr = S['frame'], S['trim']
    sgn = 1 if side == 'r' else -1
    fx1 = fx0 + W_FRONT - 1
    ft = base_y - 3 - 2 * STOREY - 3                       # the front face's top edge (under the eaves)
    fb = base_y - 3                                         # its bottom (on the plinth)
    # --- the table top under the footprint: a lit surface running back from the front edge, as deep as the house's side face recedes (+ a row), so the house's back edge rests on wood
    ex = fx1 if side == 'r' else fx0                        # the front edge the side face hangs from
    if top_col is not None:
        x_lo = fx0 - 2 - (SIDE_DX if side == 'l' else 0)
        x_hi = fx1 + 2 + (SIDE_DX if side == 'r' else 0)
        for k in range(0, SIDE_RISE + 2):
            y = base_y - k
            inset = 1 if k >= SIDE_RISE else 0              # the far edge draws in a touch toward the vanishing point
            for x in range(x_lo + inset, x_hi - inset + 1):
                f = 1.0 + 0.05 * k - (0.06 if (x + k) % 5 == 0 else 0.0)        # a little grain, lighter toward the back
                c.put(x, y, shade(top_col, f))
        c.hline(x_lo + 1, x_hi - 1, base_y - SIDE_RISE - 1, shade(top_col, 1.28))      # the back edge catches the light
    # --- the plinth (front), with its shadow on the table top
    c.shadow((fx0 + fx1) / 2.0 + sgn * 2, base_y, W_FRONT // 2 + 5, 1.8, 90)
    c.rect(fx0 - 1, fb + 1, fx1 + 1, base_y, shade(fr, 0.6))
    c.hline(fx0 - 1, fx1 + 1, fb + 1, shade(fr, 0.95))
    # ... and under the SIDE face: the plinth runs back with it, rising as it recedes, so the house is one solid box standing on the table
    for k in range(1, SIDE_DX + 1):
        x = ex + sgn * k
        lift = int(round(SIDE_RISE * k / float(SIDE_DX)))
        c.vline(x, fb - lift + 1, base_y - lift, shade(fr, 0.5))
        c.put(x, fb - lift + 1, shade(fr, 0.8))
    # --- the SIDE FACE: a parallelogram receding and rising toward the vanishing point
    for k in range(1, SIDE_DX + 1):
        x = ex + sgn * k
        lift = int(round(SIDE_RISE * k / float(SIDE_DX)))
        col = shade(fr, 0.74 - 0.05 * k / SIDE_DX)
        c.vline(x, ft - lift, fb - lift, col)
        c.put(x, ft - lift, shade(tr, 0.8))
        c.put(x, fb - lift, shade(fr, 0.5))
    mid_lift = int(round(SIDE_RISE * 0.5))
    _window(c, ex + sgn * 2 if side == 'r' else ex - 4, ft + 5 - 1, 3, 4)                # a window in the side wall, foreshortened by the light
    _window(c, ex + sgn * 2 if side == 'r' else ex - 4, ft + 5 + STOREY - 1, 3, 4)
    # --- the front face: outer frame, then the open rooms
    c.rect(fx0, ft, fx1, fb, fr)
    c.vline(fx0, ft, fb, shade(fr, 1.15))
    c.vline(fx1, ft, fb, shade(fr, 0.72))
    rx0, rx1 = fx0 + 2, fx1 - 2                              # the rooms' span
    midx = (rx0 + rx1) // 2
    f1b = fb - 2                                             # the ground floor's floor row
    f1t = f1b - STOREY + 1
    f2b = f1t - 3
    f2t = f2b - STOREY + 1
    _paper(c, rx0, f1t, midx - 1, f1b, S['r11'][0], S['r11'][1], 'stripe')
    _paper(c, midx + 2, f1t, rx1, f1b, S['r12'][0], S['r12'][1], 'plain')
    _paper(c, rx0, f2t, midx - 1, f2b, S['r21'][0], S['r21'][1], 'dots')
    _paper(c, midx + 2, f2t, rx1, f2b, S['r22'][0], S['r22'][1], 'tile')
    for (ya, yb) in ((f1t, f1b), (f2t, f2b)):                # the inner side walls: the left one is lit, the right one in shade (the rooms have depth)
        for y in range(ya, yb + 1):
            c.put(rx0, y, shade(fr, 1.05)); c.put(rx0 + 1, y, shade(fr, 0.9)) if False else None
            c.put(rx1, y, shade(fr, 0.55))
    c.vline(midx, f2t, f1b, shade(fr, 0.95))                 # the party wall, a wall with a thickness
    c.vline(midx + 1, f2t, f1b, shade(fr, 0.62))
    for (sy, th) in ((f2t - 2, 2), (f2b + 1, 3), (f1b + 1, 2)):   # the floor slabs: a lit top edge, a shaded underside and the shadow they throw on the room beneath
        c.rect(fx0, sy, fx1, sy + th - 1, tr)
        c.hline(fx0, fx1, sy, shade(tr, 1.25))
        c.hline(fx0, fx1, sy + th - 1, shade(tr, 0.6))
    for x in range(rx0, rx1 + 1):
        c.put(x, f1t, shade(S['r11'][0], 0.5)) if x < midx else c.put(x, f1t, shade(S['r12'][0], 0.6))
    _furnish(c, rx0 + 2, f1b, 'kitchen')
    _window(c, rx0 + 8, f1t + 3, 3, 3)
    _furnish(c, midx + 3, f1b, 'dark')
    _furnish(c, rx0 + 2, f2b, 'bedroom')
    _window(c, rx0 + 11, f2t + 3, 3, 3, curtain=hexc('6a8ab8'))
    _furnish(c, midx + 3, f2b, 'bath')
    c.rect(midx + 9, f2t + 3, midx + 11, f2t + 6, hexc('b8c8d0'))                         # a mirror
    c.line(midx + 9, f2t + 6, midx + 11, f2t + 4, hexc('f0f8fc'))
    # a little front door in the plinth's line: the ground floor opens onto a step
    # --- the ROOF: a gable running left-right. The front slope faces us; the side face carries the gable end (a triangle in the side wall's own plane, so it recedes with it);
    # the ridge sits at mid-depth, so it is shifted along the side's direction; the eaves overhang and throw a shadow on the face below.
    ry1 = ft - 1                                             # the eave line over the front face
    rh = 11
    ry0 = ry1 - rh                                           # the ridge, at the front edge's depth
    ov = 2
    roof = S['roof']
    half = SIDE_DX // 2
    ridge_l = fx0 + sgn * half if side == 'r' else fx0 + sgn * half
    ridge_x0, ridge_x1 = fx0 + sgn * half, fx1 + sgn * half
    ridge_y = ry0 - (SIDE_RISE + 1) // 2
    # the gable end first (the front slope overlaps its near edge)
    ax, ay = ex, ry1 + 1
    bx, by_ = ex + sgn * SIDE_DX, ry1 + 1 - SIDE_RISE
    cx, cy = ex + sgn * half, ridge_y
    c.poly([(ax, ay), (bx, by_), (cx, cy)], shade(fr, 0.7))
    c.line(bx, by_, cx, cy, shade(roof, 0.5))                # the bargeboard along its far edge
    c.line(ax, ay, cx, cy, shade(roof, 0.8))
    # the front slope: eave line to ridge line, shingled in staggered rows
    xl_e, xr_e = fx0 - ov, fx1 + ov
    for y in range(ridge_y, ry1 + 1):
        f = (y - ridge_y) / float(max(1, ry1 - ridge_y))     # 0 at the ridge, 1 at the eave
        xl = int(round(ridge_x0 + (xl_e - ridge_x0) * f))
        xr = int(round(ridge_x1 + (xr_e - ridge_x1) * f))
        row = (y - ridge_y) // 2
        for x in range(xl, xr + 1):
            col = shade(roof, 1.14 if (y - ridge_y) % 2 == 0 else 0.88)
            if (x + (3 if row % 2 else 0)) % 6 == 0:
                col = shade(roof, 0.62)                      # the joints between shingles
            c.put(x, y, col)
    c.line(ridge_x0, ridge_y, ridge_x1, ridge_y, shade(roof, 1.45))      # the ridge cap
    c.line(ridge_x0, ridge_y + 1, ridge_x1, ridge_y + 1, shade(roof, 0.7))
    c.hline(xl_e, xr_e, ry1, shade(roof, 0.55))              # the eave's drip edge, and the shadow it throws on the face below
    c.hline(xl_e, xr_e, ry1 + 1, shade(roof, 0.38))
    for x in range(fx0, fx1 + 1):
        c.put(x, ry1 + 2, shade(fr, 0.5))
    ry0 = ridge_y
    # the chimney: a brick block on the back of the roof, a lit front and a shaded side
    chx = (fx0 + 6) if side == 'r' else (fx1 - 10)
    cy1 = ry0 + 6
    c.rect(chx, ry0 - 6, chx + 4, cy1, S['brick'])
    for yy in range(ry0 - 5, cy1, 2):
        c.hline(chx, chx + 4, yy, shade(S['brick'], 0.72))
        c.put(chx + 1 + (yy % 3), yy - 1, shade(S['brick'], 0.72))
    c.vline(chx, ry0 - 6, cy1, shade(S['brick'], 1.2))
    c.vline(chx + 4, ry0 - 6, cy1, shade(S['brick'], 0.62))
    c.rect(chx - 1, ry0 - 7, chx + 5, ry0 - 7, shade(S['brick'], 1.15))
    c.hline(chx - 1, chx + 5, ry0 - 6, shade(S['brick'], 0.5))
    return fx0, fx1, ry0 - 7
