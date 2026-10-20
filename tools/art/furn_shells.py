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


SHELLS = {'a': shell_a, 'b': shell_b, 'c': shell_c, 'd': shell_d, 'e': shell_e}

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if a != '--check']
    CHECK = '--check' in sys.argv
    for k in (args or SHELLS):
        SHELLS[k]()
    if CHECK:
        if STALE:
            print('SHELLS: stale or missing:', STALE)
            sys.exit(1)
        print('SHELLS: %d bedroom shells current' % len(args or SHELLS))
