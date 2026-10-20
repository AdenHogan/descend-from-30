"""BEDROOM STYLE `teen` — the teenager's room (the old bedroom_b): posters, a desk with an old computer and a chair, a single pine bed with a starry duvet, a beanbag, a crate for a bedside
table with a lava lamp, trainers and clothes on the floor. Each piece is its own asset (tools/art/furnlib.py); the planner mixes them differently for every flat."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
from furnlib import piece
from pixlib import hexc, shade
from furn_bedroom import _legacy, CLOTH

PINE = F.PINE
STAR = hexc('d9c24a')
# --- the desk ----------------------------------------------------------------------------------------------------------------------------------------
def _b_desk(c):
    x0, x1, cx = 9, 51, 30
    c.shadow(cx, 100, 22, 2, 100)
    c.rect(x0, 72, x1, 74, F.PINE[1])
    c.hline(x0, x1, 72, F.PINE[3])
    for (p0, p1) in ((x0 + 2, x0 + 12), (x1 - 12, x1 - 2)):
        c.box(p0, 75, p1, 99, F.PINE[0], F.PINE[3])
        for (d0, d1) in ((77, 84), (86, 93)):
            c.box(p0 + 2, d0, p1 - 2, d1, F.PINE[0], F.PINE[2])
            c.put((p0 + p1) // 2, (d0 + d1) // 2, F.BRASS)
    c.rect(x0 + 13, 75, x1 - 13, 77, F.PINE[2])


def _desk_post(c, ox, oy, p, shift):
    F.crt_on_top(c, shift, ox + 21, 72 + (oy - 99))


@piece('desk_crt', 43, 28, 'wall', rooms={'bedroom': 8, 'study': 4}, styles={'teen': 8, 'adult': 1, 'refuge': 0}, tags=('work', 'storage'), depth=8,
       variants={'pine': {}}, anchors=({'name': 'desk', 'dx': 22, 'dy': -21}, {'name': 'desk_drawer', 'dx': 8, 'dy': -11}), feet=(105, 108),
       needs={'tag': 'seat', 'dx': [38, 52], 'chance': 1.0}, post=_desk_post, note='a pine desk with a pedestal of drawers at each end and an old beige computer on it (it wants its chair)')
def desk_crt(c, ox, oy, p):
    _legacy(c, _b_desk, ox - 9, oy - 99)


@piece('chair_office', 28, 30, 'floor', rooms={'bedroom': 6, 'study': 8}, styles={'teen': 6, 'adult': 1}, tags=('seat',),
       variants={'left': {'yaw': -40}, 'right': {'yaw': 40}, 'front': {'yaw': 0}}, feet=(116, 121), companion_only=True, note='an office chair rolled back from the desk, swivelled toward the room')
def chair_office(c, ox, oy, p):
    import chair3d as C3
    C3.RUN = 1
    C3.office_chair_at(c, ox + 14, oy, p['yaw'], {'fab': hexc('2e2e34'), 'metal': hexc('3a3a3d')}, plan={}, key='bedroom_chair', outline=hexc('111114'))


def _crate(c):
    c.shadow(301, 100, 10, 2, 90)
    c.box(292, 82, 310, 99, hexc('9a7a4e'), hexc('5e4a2e'))
    for gy in (86, 91, 96):
        c.hline(293, 309, gy, hexc('7c6140'))


# --- floor -------------------------------------------------------------------------------------------------------------------------------------------
# --- posters (pictures, no title words — wallart.py) ------------------------------------------------------------------------------------------------------
@piece('poster_gig', 33, 33, 'decor', rooms={'bedroom': 6, 'living_room': 2, 'study': 2}, styles={'teen': 8}, tags=('poster',), wall_y=(16, 30), limit=1,
       note='a gig poster: a guitar on a sunburst')
def poster_gig(c, ox, oy, p):
    F.poster_gig(c, ox, oy, ox + 30, oy + 30)


@piece('poster_film', 29, 39, 'decor', rooms={'bedroom': 6, 'living_room': 2}, styles={'teen': 8}, tags=('poster',), wall_y=(14, 28), limit=1, variants={'torn': {}, 'whole': {'torn': False}},
       note='a horror film one-sheet, torn at the corner')
def poster_film(c, ox, oy, p):
    F.poster_film(c, ox, oy, ox + 26, oy + 36, torn=p.get('torn', True))


@piece('poster_map', 41, 33, 'decor', rooms={'bedroom': 5, 'study': 4, 'living_room': 2}, styles={'teen': 6, 'adult': 1, 'kid': 1}, tags=('poster',), wall_y=(20, 36), limit=1,
       note='a roller map of the world on its rods')
def poster_map(c, ox, oy, p):
    F.poster_map(c, ox, oy, ox + 36, oy + 24)


@piece('poster_game', 33, 27, 'decor', rooms={'bedroom': 5, 'living_room': 1}, styles={'teen': 8}, tags=('poster',), wall_y=(18, 34), limit=1, note='a video game poster')
def poster_game(c, ox, oy, p):
    F.poster_game(c, ox, oy, ox + 30, oy + 24)


@piece('timetable', 21, 17, 'decor', rooms={'bedroom': 4, 'study': 4}, styles={'teen': 6, 'kid': 1}, tags=('notice',), wall_y=(30, 48), limit=1, note='a pinned school timetable')
def timetable(c, ox, oy, p):
    import wallart
    wallart.draw_timetable(c, ox, oy)
