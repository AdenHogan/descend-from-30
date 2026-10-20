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


SHELLS = {'a': shell_a, 'b': shell_b, 'c': shell_c, 'd': shell_d, 'e': shell_e,
          'ka': kshell_a, 'kb': kshell_b, 'kc': kshell_c, 'kd': kshell_d, 'ke': kshell_e}

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if a != '--check']
    CHECK = '--check' in sys.argv
    for k in (args or SHELLS):
        SHELLS[k]()
    if CHECK:
        if STALE:
            print('SHELLS: stale or missing:', STALE)
            sys.exit(1)
        print('SHELLS: %d shells current' % len(args or SHELLS))
