"""THE ROOM RECIPES — how the planner (scripts/furniture_planner.gd) fills each kind of room, as data (owner round 47).

A recipe is one STYLE of one room type. The five old bedroom modules (A-E) are its first five recipes: the SAME look-and-feel (a shell: the bare room), but the pieces in it are
chosen and placed from the seed, so two bedroom-As are never the same room. A recipe does not list pieces — the pieces list the rooms and styles they suit (furn_<room>.py), the
recipe says only the SHAPE of the room:

    weight    how often this style turns up in a flat (the old rooms were a flat 1-in-5)
    shell     assets/rooms/<shell>.png — the bare room (tools/art/furn_shells.py)
    legacy    the index of the OLD baked module of this look in room.MODULE_VARIANTS — a flat whose room must be baked (a breach / burnt / corpse story) shows the old module of the SAME style, so
              the wallpaper and floor never change between runs
    centre    the piece the room is built round (a tag: 'sleeping' = a bed) and the x range its front-left corner may start in
    flank     a piece placed flush against the centre's head end (a bedside table), with a chance
    wall      `count` more pieces on the wall line, and `must` tags at least one of which must be there ("a|b" = either)
    tops      the chance each free surface slot (the top of a dresser) takes something
    decor     how many pictures / posters hang;  clutter  how many things lie about on the floor;  rug  the chance of a rug;  ceiling  the chance of a ceiling light
    min_front scavenge nodes that must be reachable from the walking lane (the old per-module rule)
    fallback  a hand-set layout, used if no seeded layout can be made in MAX_TRIES attempts (it must be valid for either window side — the test checks)
"""

RECIPES = {
    'bedroom/adult': dict(
        legacy=0, weight=30, shell='bedroom_shell_a',
        centre=dict(tag='sleeping', x=[70, 170]),
        flank=dict(tag='bedside', chance=0.9),
        wall=dict(count=[1, 3], must=['wardrobe|dressing']),
        tops=0.8, decor=[2, 4], clutter=[1, 3], rug=0.6, ceiling=1.0, min_front=2,
        fallback=[dict(id='bed_wood', variant='l_sage', x=100, y=115), dict(id='nightstand_wood', variant='dark', x=62, y=106),
                  dict(id='clothes_pile', variant='blue_red', x=170, y=119), dict(id='ceiling_flush', variant='a', x=150, y=0)]),
    'bedroom/teen': dict(
        legacy=1, weight=22, shell='bedroom_shell_b',
        centre=dict(tag='sleeping', x=[70, 170]),
        flank=dict(tag='bedside', chance=0.85),
        wall=dict(count=[1, 3], must=['work']),
        tops=0.8, decor=[2, 4], clutter=[1, 3], rug=0.3, ceiling=1.0, min_front=2,
        fallback=[dict(id='bed_pine', variant='l_stars', x=100, y=115), dict(id='trainers', variant='white', x=60, y=119), dict(id='ceiling_flush', variant='a', x=150, y=0)]),
    'bedroom/sick': dict(
        legacy=2, weight=14, shell='bedroom_shell_c',
        centre=dict(tag='sleeping', x=[60, 150]),
        flank=dict(tag='bedside', chance=0.6),
        wall=dict(count=[1, 2], must=['wardrobe|medical']),
        tops=0.7, decor=[1, 3], clutter=[2, 4], rug=0.2, ceiling=1.0, min_front=2,
        fallback=[dict(id='bed_iron', variant='l_patch_clean', x=100, y=115), dict(id='med_trolley', variant='a', x=240, y=119), dict(id='ceiling_flush', variant='a', x=150, y=0)]),
    'bedroom/refuge': dict(
        legacy=3, weight=16, shell='bedroom_shell_d',
        centre=dict(tag='sleeping', x=[60, 150]),
        flank=dict(tag='bedside', chance=0.4),
        wall=dict(count=[1, 3], must=['storage']),
        tops=0.7, decor=[2, 4], clutter=[2, 4], rug=0.15, ceiling=0.0, min_front=2,
        fallback=[dict(id='mattress_floor', variant='l_blue', x=100, y=116), dict(id='backpack', variant='olive', x=210, y=119)]),
    'bedroom/kid': dict(
        legacy=4, weight=18, shell='bedroom_shell_e',
        centre=dict(tag='sleeping', x=[60, 160]),
        flank=dict(tag='bedside', chance=0.8),
        wall=dict(count=[1, 3], must=['toy|wardrobe']),
        tops=0.6, decor=[2, 4], clutter=[2, 4], rug=0.6, ceiling=1.0, min_front=2,
        fallback=[dict(id='bed_kid', variant='l_pink', x=110, y=115), dict(id='rocking_horse', variant='white_l', x=215, y=119), dict(id='ceiling_paper', variant='white', x=150, y=0)]),
}

# ------------------------------------------------------------------------------------------------------------------------------------ kitchens (round 47e)
# `run` = the fitted units along the back wall (tag `unit`, edge to edge on one feet row, every `must` tag at least once); `centre` = the table; the rest as for a bedroom.
RECIPES.update({
    'kitchen/classic': dict(
        legacy=0, weight=26, shell='kitchen_shell_a',
        centre=dict(tag='dining', x=[40, 210], anywhere=True),
        run=dict(count=[4, 6], must=['cold', 'cooking', 'wet'], x=[6, 36], sides=2),
        wall=dict(count=[0, 1], must=[]),
        tops=0.7, decor=[3, 5], clutter=[2, 4], rug=0.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='fridge_tall', variant='cream', x=8, y=106), dict(id='unit_base', variant='sage_two', x=36, y=106), dict(id='unit_base', variant='sage_drawers', x=66, y=106),
                  dict(id='unit_cooker', variant='white_pan', x=98, y=106), dict(id='unit_sink', variant='sage', x=128, y=106), dict(id='table_kitchen', variant='cloth', x=210, y=118),
                  dict(id='light_tube', variant='a', x=130, y=0)]),
    'kitchen/retro': dict(
        legacy=1, weight=22, shell='kitchen_shell_b',
        centre=dict(tag='dining', x=[40, 210], anywhere=True),
        run=dict(count=[4, 6], must=['cold', 'cooking', 'wet'], x=[6, 36], sides=2),
        wall=dict(count=[0, 1], must=[]),
        tops=0.7, decor=[3, 5], clutter=[1, 3], rug=0.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='fridge_tall', variant='mint', x=8, y=106), dict(id='unit_base', variant='yellow_two', x=36, y=106), dict(id='unit_base', variant='yellow_drawers', x=66, y=106),
                  dict(id='unit_cooker', variant='white_bare', x=98, y=106), dict(id='unit_sink', variant='yellow', x=128, y=106), dict(id='table_kitchen', variant='dinette', x=210, y=118),
                  dict(id='light_dome_orange', variant='orange', x=150, y=0)]),
    'kitchen/country': dict(
        legacy=2, weight=18, shell='kitchen_shell_c',
        centre=dict(tag='dining', x=[120, 250], anywhere=True),
        run=dict(count=[2, 4], must=['cooking'], x=[60, 130]),
        wall=dict(count=[1, 2], must=['wet']),
        tops=0.7, decor=[2, 4], clutter=[2, 3], rug=0.0, ceiling=0.8, min_front=2,
        fallback=[dict(id='sink_butler', variant='white', x=7, y=106), dict(id='range_recess', variant='green', x=100, y=106), dict(id='dresser_welsh', variant='pine', x=186, y=106),
                  dict(id='table_kitchen', variant='pine', x=240, y=118)]),
    'kitchen/student': dict(
        legacy=3, weight=18, shell='kitchen_shell_d',
        centre=dict(tag='dining', x=[40, 210], anywhere=True),
        run=dict(count=[3, 5], must=['cold', 'cooking', 'wet'], x=[6, 36], sides=2),
        wall=dict(count=[0, 1], must=[]),
        tops=0.7, decor=[2, 4], clutter=[3, 5], rug=0.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='fridge_tall', variant='white_open', x=6, y=106), dict(id='unit_base', variant='white_two', x=44, y=106), dict(id='unit_base', variant='white_drawers', x=74, y=106),
                  dict(id='unit_sink', variant='white', x=104, y=106), dict(id='unit_cooker', variant='black_bare', x=146, y=106), dict(id='table_kitchen', variant='camping', x=220, y=118),
                  dict(id='light_bulb', variant='a', x=150, y=0)]),
    'kitchen/hoarder': dict(
        legacy=4, weight=16, shell='kitchen_shell_e',
        centre=dict(tag='dining', x=[120, 230], anywhere=True),
        run=dict(count=[3, 5], must=['cooking', 'wet'], x=[50, 110]),
        wall=dict(count=[0, 1], must=['clutter|storage']),
        tops=0.8, decor=[3, 5], clutter=[3, 5], rug=0.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='newspaper_stacks', variant='a', x=6, y=106), dict(id='unit_base', variant='cream_two', x=52, y=106), dict(id='unit_base', variant='cream_drawers', x=82, y=106),
                  dict(id='unit_cooker', variant='cream_bare', x=112, y=106), dict(id='unit_sink', variant='cream', x=142, y=106), dict(id='table_kitchen', variant='trestle', x=200, y=118), dict(id='light_bulb', variant='a', x=150, y=0)]),
})



# THE LOGIC as data: piece tags -> the only room types they may be registered in (furnlib.TAG_ROOMS is the source; exported so the game and its tests read the same table).
def rules():
    import furnlib as FL
    return {'tag_rooms': {k: list(v) for k, v in FL.TAG_ROOMS.items()}}
