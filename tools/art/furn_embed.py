"""Lay a PLANNED piece's own sprite onto a BAKED module (owner round 48j: "every item needs to have depth… we really need consistency on this across the board").

A story room (the tutorial's flats, a breach, a gun cabinet…) is still a baked module — drawn by tools/art/bedroom_variants.py & co. — while an ordinary flat is laid from the furniture library
(data/furniture.json). Two drawings of one toy drift apart: the baked child's room kept a flat teddy, a flat toy shelf and a plain wardrobe long after the library's were redrawn. `lay` closes that:
a baked room asks for the library's piece by name and gets the very sprite the planner would use (same render, same finishing pass, same lean bucket), composited where the baked art wants it.

    furn_embed.lay(c, 'toy_shelf', 'a', x, feet_y)       x = the piece's front-left column (the planner's reference point R), feet_y = its feet row
"""
import copy
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furnlib as FL
import pixlib


def _load_pieces():
    """Register the library's pieces (furn_build imports the same files; importing one twice under one name is harmless)."""
    for mod in ('furn_beds', 'furn_kids', 'furn_toys', 'furn_wardrobes', 'furn_props2', 'furn_floor'):
        __import__(mod)


def lay(c, pid, variant, x, feet_y, floor=True, override=None):
    """Composite the library piece `pid` (variant name) onto canvas `c` with its front-left reference point at (x, feet_y). A floor piece registers its feet for the pipeline's clip checks
    (`floor=False` for one that stands on a bed or a table). `override` = attributes of a COPY of the piece to change for this room (`w`, `draw`): the same drawing at the width a baked
    corner allows (the kid's wardrobe, 28 wide, where a window box leaves no more); it still renders and finishes as the library's piece. Returns (sprite, info, (left, top))."""
    _load_pieces()
    pc = FL.REGISTRY[pid]
    if override:
        pc = copy.copy(pc)
        for k, v in override.items():
            setattr(pc, k, v)
    params = dict(pc.variants[variant])
    bk = FL.bucket_of(x + pc.w / 2.0) if pc.bucketed else None
    xk = FL.LEAN_X[bk] if bk is not None else 160
    saved = (list(pixlib.LIGHTS), list(pixlib.ANIMS), list(pixlib.FLOOR_PIECES))      # render() clears the module-wide lists a baked room is still filling
    try:
        spr, info = FL.render(pc, params, xk)
    finally:
        pixlib.LIGHTS[:] = saved[0]
        pixlib.ANIMS[:] = saved[1]
        pixlib.FLOOR_PIECES[:] = saved[2]
    left, top = int(x) - info['rx'], int(feet_y) - info['ry']
    c.img.alpha_composite(spr, (max(0, left), max(0, top)), (max(0, -left), max(0, -top)))
    c.px = c.img.load()
    if floor and pc.plane in ('floor', 'front'):
        px = spr.load()
        pts = {(left + sx, top + sy) for sy in range(spr.height) for sx in range(spr.width)
               if px[sx, sy][3] >= 200 and sy >= info['ry'] + info.get('sb', 0) - 3}
        if pts:
            pixlib.register_floor_piece('%s at x%d' % (pid, x), 'feet', pts)
    return spr, info, (left, top)
