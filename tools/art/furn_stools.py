"""STOOLS — the seat that belongs to a thing you sit AT (owner round 48k: "any player should look at the room and think a human designed it").

`tools/art/room_eye.py` measured over 1200 planned rooms: a piano stood with nowhere to sit in 37 of them, a dressing table with no stool in 28 (14 % of the bedrooms). A piece that is used from
a seat now brings it, the way a desk brings its chair:

  stool_piano     a padded piano bench: a buttoned cushion (leather or tapestry) over a rail on four turned legs with a stretcher; stands in front of the keyboard
  stool_dressing  a round upholstered dressing-table stool: a piped drum cushion on four splayed turned legs; tucked in front of the dressing table

Each is a small 3D-shaded object (propkit: lit from the upper left, a selective outline, a contact shadow) — never a flat silhouette (Consistency rule 6).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import propkit as K
import corridor_props3d as P3
from furnlib import piece
from pixlib import hexc, shade

WOODS = {'walnut': hexc('5a3a26'), 'oak': hexc('9a7448'), 'black': hexc('2a2622'), 'maple': hexc('b8925a')}
LEATHER = {'maroon': hexc('7a2c2e'), 'green': hexc('3e5a46'), 'black': hexc('2c2a2c'), 'tan': hexc('9a6a3e')}
TAPESTRY = {'rose': hexc('a8627a'), 'blue': hexc('4a6a8a'), 'gold': hexc('b89a48')}


def _turned_leg(lc, x, y_top, y_bot, wood, r=1.5, back=False):
    """A turned leg: a slim shaft with a collar near the top and a bun foot."""
    col = shade(wood, 0.72) if back else wood
    K.cyl(lc, x, y_top, y_bot - 1, r - 0.3, col, ry=0.5, cap=False)
    K.cyl(lc, x, y_top + 1, y_top + 2, r + 0.4, col, ry=0.6, cap=False)                      # the collar
    K.cyl(lc, x, y_bot - 2, y_bot - 1, r + 0.3, col, ry=0.6, cap=False)                      # the bun foot
    lc.put(int(round(x)), y_bot, shade(col, 0.5))


def _button(c, x, y, col):
    c.put(x, y, shade(col, 0.55))
    c.put(x - 1, y - 1, shade(col, 1.3))


# ================================================================================================================================ the piano stool
def _piano_variants():
    v = {}
    for wk in ('walnut', 'black', 'oak'):
        for fk, fab in list(LEATHER.items()) + list(TAPESTRY.items()):
            v['%s_%s' % (wk, fk)] = {'wood': wk, 'fab': fk, 'tapestry': fk in TAPESTRY}
    return v


@piece('stool_piano', 28, 22, 'floor', keep='seat', rooms={'living_room': 6, 'study': 6, 'dining_room': 6, 'bedroom': 6}, tags=('seat', 'stool_piano'), variants=_piano_variants(),
       anchors=(), companion_only=True, limit=1, lap=22, feet=(116, 121), wall_y=None,
       note='a padded piano bench: a buttoned cushion (leather or tapestry) over a plain rail on four turned legs with a stretcher; stands in front of the keyboard')
def stool_piano(c, ox, oy, p):
    wood = WOODS[p['wood']]
    fab = (TAPESTRY if p['tapestry'] else LEATHER)[p['fab']]
    cx = ox + 14
    c.shadow(cx, oy + 1, 14, 2, 105)
    L = K.Layer(c)
    lc = L.c
    # the far legs first (drawn higher and darker: they stand further back), then the stretcher, then the near legs
    for lx in (ox + 6, ox + 22):
        _turned_leg(lc, lx, oy - 13, oy - 3, wood, back=True)
    P3.rod(lc, (ox + 4, oy - 5), (ox + 23, oy - 5), 0.9, 0.9, shade(wood, 0.8))                   # the stretcher between the near legs
    for lx in (ox + 3, ox + 24):
        _turned_leg(lc, lx, oy - 13, oy, wood)
    # the rail under the seat, with a lit top edge and a shaded bottom one
    lc.rect(ox + 2, oy - 15, ox + 25, oy - 13, shade(wood, 1.0))
    lc.hline(ox + 2, ox + 25, oy - 15, shade(wood, 1.3))
    lc.hline(ox + 2, ox + 25, oy - 13, shade(wood, 0.6))
    # the cushion: a slab with a lit top face, a bulging front, piping along the edge and two buttons
    K.slab(lc, ox + 1, oy - 20, ox + 26, oy - 16, fab, d=3, top=shade(fab, 1.28), n=5, lo=0.6, hi=1.3, inset=2)
    lc.hline(ox + 1, ox + 26, oy - 16, shade(fab, 0.62))
    for bx in (ox + 9, ox + 18):
        _button(lc, bx, oy - 22, fab)
    if p['tapestry']:                                                                              # a woven pattern: two rows of small diamonds across the front
        for k in range(ox + 4, ox + 25, 4):
            lc.put(k, oy - 18, shade(fab, 1.45))
            lc.put(k + 2, oy - 17, shade(fab, 0.7))
    L.flush()


# ================================================================================================================================ the dressing-table stool
def _dress_variants():
    v = {}
    for wk in ('walnut', 'oak', 'black'):
        for fk, fab in list(TAPESTRY.items()) + [('cream', hexc('d8cdb4')), ('maroon', hexc('7a2c2e'))]:
            v['%s_%s' % (wk, fk)] = {'wood': wk, 'fab': fk}
    return v


_DRESS_FABS = dict(TAPESTRY)
_DRESS_FABS['cream'] = hexc('d8cdb4')
_DRESS_FABS['maroon'] = hexc('7a2c2e')


@piece('stool_dressing', 20, 22, 'floor', keep='seat', rooms={'bedroom': 6}, styles={'adult': 6, 'kid': 6}, tags=('seat', 'stool_dressing'), variants=_dress_variants(),
       anchors=(), companion_only=True, limit=1, lap=18, feet=(116, 121),
       note='a round upholstered dressing-table stool: a piped drum cushion on four splayed turned legs; tucked in front of the dressing table')
def stool_dressing(c, ox, oy, p):
    wood = WOODS[p['wood']]
    fab = _DRESS_FABS[p['fab']]
    cx = ox + 10
    c.shadow(cx, oy + 1, 10, 2, 105)
    L = K.Layer(c)
    lc = L.c
    # four splayed legs: the far pair shorter and darker, the near pair splayed outward toward you; a ring stretcher between them
    for (x0, x1, y0, y1, back) in ((cx - 3, cx - 5, oy - 12, oy - 4, True), (cx + 3, cx + 5, oy - 12, oy - 4, True), (cx - 4, cx - 8, oy - 12, oy, False), (cx + 4, cx + 8, oy - 12, oy, False)):
        P3.rod(lc, (x0, y0), (x1, y1), 1.0, 0.9, shade(wood, 0.72) if back else wood)
    P3.rod(lc, (cx - 6, oy - 5), (cx + 6, oy - 5), 0.7, 0.7, shade(wood, 0.8))
    # the cushion: a flat drum seen a little from above, a lit cap, a darker piped rim, one button in the middle
    K.cyl(lc, cx, oy - 16, oy - 14, 9.0, fab, ry=3.0, cap=True, cap_col=shade(fab, 1.22), n=5, lo=0.58, hi=1.3)
    K.cyl(lc, cx, oy - 13, oy - 12, 8.0, shade(wood, 0.9), ry=2.6, cap=False)                      # the wooden seat rail under the cushion
    lc.put(cx, oy - 16, shade(fab, 0.55))
    lc.put(cx - 1, oy - 17, shade(fab, 1.4))
    L.flush()
