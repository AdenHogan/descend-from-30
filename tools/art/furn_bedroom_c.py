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

