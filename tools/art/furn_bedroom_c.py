"""BEDROOM STYLE `sick` — the sick room (the old bedroom_c): an iron bedstead under a patchwork quilt, a drip stand still dripping, a wheelchair, a medicine trolley, a mirrored wardrobe, a cabinet
of pill bottles, a wedding photo and a cross-stitch sampler. Each piece its own asset; the planner decides what is in THIS flat's sick room and where."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furn as F
import furnlib as FL
import bedroom_variants as BV
from furnlib import piece
from pixlib import hexc, shade
from furn_bedroom import _legacy

@piece('photo_wedding', 29, 28, 'decor', rooms={'bedroom': 4, 'living_room': 4}, styles={'sick': 6, 'adult': 2}, tags=('picture',), wall_y=(24, 40), limit=1, note='a sepia wedding photograph')
def photo_wedding(c, ox, oy, p):
    F.photo(c, ox + 2, oy + 8, ox + 26, oy + 26, [(hexc('e0c8a8'), hexc('5a4028'), hexc('f4f0e4'), 12), (hexc('d8b89a'), hexc('2a2420'), hexc('2e2e33'), 13)],
            bg=hexc('c8b89a'), ground=hexc('a8987a'), frame=hexc('6b4a2c'))
    c.line(ox + 14, oy, ox, oy + 6, hexc('3b2718')); c.line(ox + 14, oy, ox + 28, oy + 6, hexc('3b2718'))


@piece('sampler_home', 22, 17, 'decor', rooms={'bedroom': 3, 'living_room': 3, 'kitchen': 3}, styles={'sick': 6, 'adult': 2}, tags=('picture',), wall_y=(24, 40), limit=1,
       note='a cross-stitch sampler that says HOME')
def sampler_home(c, ox, oy, p):
    c.box(ox, oy, ox + 20, oy + 14, hexc('6b4a2c'), hexc('3b2718'))
    c.rect(ox + 2, oy + 2, ox + 18, oy + 12, hexc('e6ddc4'))
    F.text3(c, ox + 2 + (17 - F.text3_width('HOME')) // 2, oy + 3, 'HOME', hexc('a0505a'))
    for (hx, hy) in ((8, 9), (10, 9), (7, 10), (11, 10), (8, 10), (9, 10), (10, 10), (9, 11)):
        c.put(ox + hx, oy + hy, hexc('b0453a'))
