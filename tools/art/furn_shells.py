"""The bedroom SHELLS (owner round 47): the five old bedroom rooms with their furniture taken out. Each keeps its wallpaper / plaster, damp, floor and character; the pieces come from
tools/art/furn_bedroom.py, laid by the game's planner. Run:  python3 tools/art/furn_shells.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bedroom as BR
from shells import finish_shell as _finish_shell


CHECK = False


def finish_shell(*a, **kw):
    r = _finish_shell(*a, check=CHECK, **kw)
    if CHECK:
        STALE.extend(r or [])
    return r


STALE = []


def shell_a():
    def wall(c):
        BR.wall(c)
        BR.decay(c)

    def build(c):
        wall(c)
        BR.floor(c)
    finish_shell('bedroom_shell_a', 'bedroom', 'bedroom/adult', 21, wall, BR.floor, build)


def _simple(name, plan, seed, wall_fn, floor_fn):
    def build(c):
        wall_fn(c)
        floor_fn(c)
    finish_shell(name, 'bedroom', plan, seed, wall_fn, floor_fn, build)


def shell_b():
    import bedroom_variants as BV
    _simple('bedroom_shell_b', 'bedroom/teen', 22, BV.b_wall, BV.b_floor)


def shell_c():
    import bedroom_variants as BV
    _simple('bedroom_shell_c', 'bedroom/sick', 23, BV.c_wall, BV.c_floor)


def shell_d():
    import bedroom_variants as BV
    _simple('bedroom_shell_d', 'bedroom/refuge', 24, BV.d_wall, BV.d_floor)


def shell_e():
    import bedroom_variants as BV
    _simple('bedroom_shell_e', 'bedroom/kid', 25, BV.e_wall, BV.e_floor)


# ---------------------------------------------------------------------------------------------------------------------------------- kitchens (round 47e)
# A kitchen's wall used to carry things that belong to ONE arrangement (a tile band only behind the counter, a brick recess for the range, a splashback x 100..230): a planned kitchen puts its
# units anywhere, so every band runs the full width and the recess is now a piece (range_recess).
def _kitchen(name, plan, seed, wall_fn, floor_fn):
    def build(c):
        wall_fn(c)
        floor_fn(c)
    finish_shell(name, 'kitchen', plan, seed, wall_fn, floor_fn, build)


def kshell_a():
    import kitchen as KI

    def wall(c):
        KI.wall(c)
        KI.decay(c)
    _kitchen('kitchen_shell_a', 'kitchen/classic', 33, wall, KI.floor)


def kshell_b():
    import kitchen_variants as KV
    import furn as F
    from pixlib import hexc

    def wall(c):
        F.wall_plain(c, KV.B_WALL, hexc('8a9a80'), hexc('3a3a36'))
        c.rect(0, 56, 319, 93, hexc('e6e2d4'))                                             # small square tiles all along the wall
        for y in range(56, 94, 6):
            c.hline(0, 319, y, hexc('c8c2b0'))
        for x in range(0, 320, 6):
            c.vline(x, 56, 93, hexc('c8c2b0'))
        for i in range(5):
            c.ellipse(180 + i * 6, 14 + (i % 2) * 3, 7, 5, hexc('8a9a70', 60))
    _kitchen('kitchen_shell_b', 'kitchen/retro', 34, wall, KV.b_floor)


def kshell_c():
    import kitchen_variants as KV
    import furn as F
    from pixlib import hexc

    def wall(c):
        F.wall_plain(c, KV.C_WALL, hexc('a89a78'), hexc('5e4a3a'), texture=hexc('c9bda0'))
    _kitchen('kitchen_shell_c', 'kitchen/country', 35, wall, KV.c_floor)


def kshell_d():
    import kitchen_variants as KV
    import furn as F
    from pixlib import hexc

    def wall(c):
        F.wall_plain(c, KV.D_WALL, hexc('9a927a'), hexc('4a4a48'), texture=hexc('b9b090'))
        c.rect(0, 58, 319, 93, hexc('d8d2c2'))                                              # a white splashback all along
        for y in range(58, 94, 7):
            c.hline(0, 319, y, hexc('b9b3a4'))
        for i in range(6):
            c.ellipse(26 + i * 7, 14 + (i % 2) * 4, 9, 5, hexc('6a6a4a', 60))
    _kitchen('kitchen_shell_d', 'kitchen/student', 36, wall, KV.d_floor)


def kshell_e():
    import kitchen_variants as KV
    _kitchen('kitchen_shell_e', 'kitchen/hoarder', 37, KV.e_wall, KV.e_floor)


# ---------------------------------------------------------------------------------------------------------------------------------- living rooms (round 47f)
# The five old living rooms with their furniture taken out. The wall pictures, the clocks, the starburst, the cameos and the antlers were part of the old art's `*_decor` and are
# now pieces; the walls keep their paper, panelling, damp and cracks.
def _living(name, plan, seed, wall_fn, floor_fn):
    def build(c):
        wall_fn(c)
        floor_fn(c)
    finish_shell(name, 'living_room', plan, seed, wall_fn, floor_fn, build)


def lshell_a():
    import living_room as LR

    def wall(c):
        LR.wall(c)
        LR.decay(c)
    _living('living_shell_a', 'living_room/cosy', 41, wall, LR.floor)


def lshell_b():
    import living_room_variants as LV
    _living('living_shell_b', 'living_room/mid', 42, LV.b_wall, LV.b_floor)


def lshell_c():
    import living_room_variants as LV
    _living('living_shell_c', 'living_room/squat', 43, LV.c_wall, LV.c_floor)


def lshell_d():
    import living_room_variants as LV
    _living('living_shell_d', 'living_room/parlour', 44, LV.d_wall, LV.d_floor)


def lshell_e():
    import living_room_variants as LV
    _living('living_shell_e', 'living_room/lodge', 45, LV.e_wall, LV.e_floor)


# ---------------------------------------------------------------------------------------------------------------------------------- dining rooms + studies (round 47f)
# Same rule: the old wall + floor, none of the furniture or the `*_decor` pictures (those are pieces now). Dining rooms and studies are the two room types that can sit on a BALCONY slot, so their
# shell scenes carry the Balcony node too (tools/art/shells.py) — room.gd reveals it on a balcony slot, and the planner keeps x 4..96 clear there.
def _room(name, room_type, plan, seed, wall_fn, floor_fn):
    def build(c):
        wall_fn(c)
        floor_fn(c)
    finish_shell(name, room_type, plan, seed, wall_fn, floor_fn, build)


def dshell_a():
    import dining_room as DR

    def wall(c):
        DR.wall(c)
        DR.decay(c)
    _room('dining_shell_a', 'dining_room', 'dining_room/family', 51, wall, DR.floor)


def dshell_b():
    import dining_room_variants as DV
    _room('dining_shell_b', 'dining_room', 'dining_room/diner', 52, DV.b_wall, DV.b_floor)


def dshell_c():
    import dining_room_variants as DV
    _room('dining_shell_c', 'dining_room', 'dining_room/formal', 53, DV.c_wall, DV.c_floor)


def dshell_d():
    import dining_room_variants as DV
    _room('dining_shell_d', 'dining_room', 'dining_room/barricade', 54, DV.d_wall, DV.d_floor)


def dshell_e():
    import dining_room_variants as DV
    _room('dining_shell_e', 'dining_room', 'dining_room/party', 55, DV.e_wall, DV.e_floor)


def sshell_a():
    import study as ST

    def wall(c):
        ST.wall(c)
        ST.decay(c)
    _room('study_shell_a', 'study', 'study/den', 61, wall, ST.floor)


def sshell_b():
    import study_variants as SV
    _room('study_shell_b', 'study', 'study/office', 62, SV.b_wall, SV.b_floor)


def sshell_c():
    import study_variants as SV
    _room('study_shell_c', 'study', 'study/library', 63, SV.c_wall, SV.c_floor)


def sshell_d():
    import study_variants as SV
    _room('study_shell_d', 'study', 'study/radio', 64, SV.d_wall, SV.d_floor)


def sshell_e():
    import study_variants as SV
    _room('study_shell_e', 'study', 'study/studio', 65, SV.e_wall, SV.e_floor)


# ---------------------------------------------------------------------------------------------------------------------------------- bathrooms (round 47f)
# The old tiled walls and floors with nothing in them: the fixtures, the mirrors, the mats, the cupboard and the chandelier are pieces now. (The `*_bare` functions of tools/art/bathroom.py already
# are the wall alone; the floors are the @persp ones.)
def bshell_a():
    import bathroom as BR
    _room('bath_shell_a', 'bathroom', 'bathroom/tub', 71, BR.a_wall, BR.a_floor)


def bshell_b():
    import bathroom as BR
    _room('bath_shell_b', 'bathroom', 'bathroom/avocado', 72, BR.b_wall, BR.b_floor)


def bshell_c():
    import bathroom as BR
    _room('bath_shell_c', 'bathroom', 'bathroom/gilded', 73, BR.c_wall, BR.c_floor)


def bshell_d():
    import bathroom as BR
    _room('bath_shell_d', 'bathroom', 'bathroom/wetroom', 74, BR.d_wall, BR.d_floor)


def bshell_e():
    import bathroom as BR
    _room('bath_shell_e', 'bathroom', 'bathroom/pink', 75, BR.e_wall, BR.e_floor)


SHELLS = {'a': shell_a, 'b': shell_b, 'c': shell_c, 'd': shell_d, 'e': shell_e,
          'ka': kshell_a, 'kb': kshell_b, 'kc': kshell_c, 'kd': kshell_d, 'ke': kshell_e,
          'la': lshell_a, 'lb': lshell_b, 'lc': lshell_c, 'ld': lshell_d, 'le': lshell_e,
          'da': dshell_a, 'db': dshell_b, 'dc': dshell_c, 'dd': dshell_d, 'de': dshell_e,
          'sa': sshell_a, 'sb': sshell_b, 'sc': sshell_c, 'sd': sshell_d, 'se': sshell_e,
          'ba': bshell_a, 'bb': bshell_b, 'bc': bshell_c, 'bd': bshell_d, 'be': bshell_e}

def room_of(key):
    """The room type a shell key belongs to (a one-letter key is a bedroom; two letters: k kitchen, l living, d dining, s study, b bathroom)."""
    if len(key) == 1:
        return 'bedroom'
    return {'k': 'kitchen', 'l': 'living_room', 'd': 'dining_room', 's': 'study', 'b': 'bathroom'}[key[0]]


if __name__ == '__main__':
    import furn_rooms
    args = [a for a in sys.argv[1:] if a != '--check']
    CHECK = '--check' in sys.argv
    if not args:
        args = [k for k in SHELLS if room_of(k) in furn_rooms.BUILT]             # only the room types built into the library (furn_rooms.BUILT)
    for k in args:
        SHELLS[k]()
    if CHECK:
        if STALE:
            print('SHELLS: stale or missing:', STALE)
            sys.exit(1)
        print('SHELLS: %d shells current' % len(args))
