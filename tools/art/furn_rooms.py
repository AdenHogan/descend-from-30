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
        wall=dict(count=[1, 3], must=['wardrobe|dressing'], want=['dressing']),
        tops=0.9, decor=[3, 5], clutter=[2, 4], rug=0.6, ceiling=1.0, min_front=2,
        fallback=[dict(id='wardrobe_wood', variant='painted', x=53, y=106), dict(id='bed_wood', variant='r_slate', x=117, y=115), dict(id='ceiling_flush', variant='a', x=172, y=0)],
        fallback_left=[dict(id='nightstand_wood', variant='dark', x=46, y=105), dict(id='wardrobe_mirror', variant='clean', x=223, y=108), dict(id='bed_wood', variant='l_mustard', x=76, y=116), dict(id='ceiling_pendant', variant='cream', x=170, y=0)],
        fallback_right=[dict(id='dressing_table', variant='dark', x=55, y=106), dict(id='bed_wood', variant='l_sage', x=135, y=116), dict(id='stool_dressing', variant='black_rose', x=107, y=116), dict(id='ceiling_pendant', variant='mustard', x=240, y=0)]),
    'bedroom/teen': dict(
        legacy=1, weight=22, shell='bedroom_shell_b',
        centre=dict(tag='sleeping', x=[44, 100], mirror=True),
        flank=dict(tag='bedside', chance=0.85),
        wall=dict(count=[1, 3], must=['work']),
        tops=0.9, decor=[3, 5], clutter=[2, 4], rug=0.3, ceiling=1.0, min_front=2,
        fallback=[dict(id='desk_crt', variant='pine', x=198, y=107), dict(id='bed_pine', variant='l_red', x=57, y=116), dict(id='chair_office', variant='right', x=246, y=118), dict(id='ceiling_flush', variant='a', x=167, y=0)],
        fallback_left=[dict(id='desk_crt', variant='pine', x=201, y=107), dict(id='bed_pine', variant='l_green', x=69, y=114), dict(id='chair_wood', variant='spindle_dark_f', x=247, y=118), dict(id='ceiling_flush', variant='a', x=164, y=0)],
        fallback_right=[dict(id='desk_crt', variant='pine', x=47, y=108), dict(id='bed_pine', variant='r_grey', x=136, y=115), dict(id='chair_office', variant='front', x=99, y=116), dict(id='ceiling_flush', variant='a', x=199, y=0)]),
    'bedroom/sick': dict(
        legacy=2, weight=14, shell='bedroom_shell_c',
        centre=dict(tag='sleeping', x=[60, 150]),
        flank=dict(tag='bedside', chance=0.6),
        wall=dict(count=[1, 2], must=['wardrobe|medical']),
        tops=0.9, decor=[2, 4], clutter=[3, 5], rug=0.2, ceiling=1.0, min_front=2,
        fallback=[dict(id='nightstand_wood', variant='light', x=221, y=105), dict(id='pill_cabinet', variant='a', x=61, y=108), dict(id='bed_iron', variant='r_blue_clean', x=97, y=115), dict(id='ceiling_flush', variant='a', x=231, y=0)],
        fallback_left=[dict(id='nightstand_wood', variant='dark', x=209, y=105), dict(id='pill_cabinet', variant='b', x=237, y=108), dict(id='bed_iron', variant='r_blue_stained', x=85, y=117), dict(id='ceiling_pendant', variant='green', x=155, y=0)],
        fallback_right=[dict(id='wardrobe_mirror', variant='clean', x=52, y=106), dict(id='bed_iron', variant='r_patch_clean', x=134, y=117), dict(id='ceiling_flush', variant='a', x=234, y=0)]),
    'bedroom/bedsit': dict(
        legacy=3, weight=16, shell='bedroom_shell_d',
        centre=dict(tag='sleeping', x=[60, 150]),
        flank=dict(tag='bedside', chance=0.4),
        wall=dict(count=[2, 4], must=['storage']),
        tops=0.9, decor=[3, 5], clutter=[3, 5], rug=0.15, ceiling=0.0, min_front=2,
        fallback=[dict(id='boxes_stack', variant='open', x=239, y=107), dict(id='crate_bedside', variant='pine', x=209, y=107), dict(id='bookcase_low', variant='oak', x=63, y=108), dict(id='mattress_floor', variant='r_bare', x=97, y=115)],
        fallback_left=[dict(id='boxes_stack', variant='closed', x=209, y=105), dict(id='mattress_floor', variant='r_blue', x=85, y=116)],
        fallback_right=[dict(id='wardrobe_wood', variant='oak', x=48, y=105), dict(id='bookcase_low', variant='light', x=99, y=106), dict(id='crate_bedside', variant='grey', x=246, y=108), dict(id='mattress_floor', variant='r_green', x=134, y=116)]),
    'bedroom/kid': dict(
        legacy=4, weight=18, shell='bedroom_shell_e',
        centre=dict(tag='sleeping', x=[60, 160]),
        flank=dict(tag='bedside', chance=0.8),
        wall=dict(count=[1, 3], must=['toy|wardrobe']),
        tops=0.9, decor=[3, 5], clutter=[3, 5], rug=0.6, ceiling=1.0, min_front=2,
        fallback=[dict(id='wardrobe_small', variant='blue', x=53, y=105), dict(id='nightstand_wood', variant='light', x=100, y=105), dict(id='dollhouse_table', variant='blue', x=227, y=108), dict(id='bed_kid', variant='l_blue', x=130, y=114), dict(id='ceiling_paper', variant='white', x=209, y=0)],
        fallback_left=[dict(id='radiator', variant='iron', x=76, y=105), dict(id='wardrobe_small', variant='blue', x=234, y=107), dict(id='nightstand_wood', variant='light', x=118, y=107), dict(id='bed_kid', variant='l_blue', x=148, y=114), dict(id='ceiling_paper', variant='white', x=234, y=0)],
        fallback_right=[dict(id='wardrobe_small', variant='pink', x=54, y=105), dict(id='nightstand_wood', variant='light', x=184, y=105), dict(id='radiator', variant='iron', x=211, y=106), dict(id='bed_kid', variant='r_pink', x=100, y=114), dict(id='ceiling_pendant', variant='cream', x=187, y=0)]),
}

# ------------------------------------------------------------------------------------------------------------------------------------ kitchens (round 47e)
# `run` = the fitted units along the back wall (tag `unit`, edge to edge on one feet row, every `must` tag at least once); `centre` = the table; the rest as for a bedroom.
RECIPES.update({
    'kitchen/classic': dict(
        legacy=0, weight=26, shell='kitchen_shell_a',
        centre=dict(tag='dining', x=[40, 210], anywhere=True),
        run=dict(count=[4, 6], must=['cold', 'cooking', 'wet'], x=[6, 36], sides=2),
        wall=dict(count=[0, 1], must=[]),
        tops=0.9, decor=[5, 7], clutter=[3, 5], rug=0.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='unit_sink', variant='sage', x=63, y=106), dict(id='fridge_tall', variant='white', x=101, y=106), dict(id='unit_cooker', variant='white_bare', x=134, y=106), dict(id='table_kitchen', variant='cloth', x=182, y=120), dict(id='light_tube', variant='a', x=178, y=0)],
        fallback_left=[dict(id='unit_sink', variant='sage', x=76, y=106), dict(id='washer_unit', variant='sage', x=114, y=106), dict(id='unit_cooker', variant='cream_pan', x=177, y=106), dict(id='fridge_tall', variant='cream', x=144, y=106), dict(id='table_kitchen', variant='cloth', x=211, y=120), dict(id='light_tube', variant='a', x=163, y=0)],
        fallback_right=[dict(id='unit_sink', variant='sage', x=208, y=106), dict(id='unit_base', variant='sage_two', x=178, y=106), dict(id='unit_cooker', variant='white_kettle', x=117, y=106), dict(id='fridge_tall', variant='cream', x=145, y=106), dict(id='table_kitchen', variant='cloth', x=54, y=117), dict(id='light_tube', variant='a', x=173, y=0)]),
    'kitchen/retro': dict(
        legacy=1, weight=22, shell='kitchen_shell_b',
        centre=dict(tag='dining', x=[40, 210], anywhere=True),
        run=dict(count=[3, 5], must=['cold', 'cooking', 'wet'], x=[6, 36], sides=2),
        wall=dict(count=[0, 1], must=[]),
        tops=0.9, decor=[5, 7], clutter=[2, 4], rug=0.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='unit_sink', variant='yellow', x=63, y=106), dict(id='fridge_tall', variant='mint', x=101, y=106), dict(id='unit_cooker', variant='white_kettle', x=134, y=106), dict(id='table_kitchen', variant='dinette', x=182, y=120), dict(id='light_dome_orange', variant='orange', x=183, y=0)],
        fallback_left=[dict(id='unit_sink', variant='yellow', x=76, y=106), dict(id='unit_base', variant='yellow_drawers', x=114, y=106), dict(id='unit_cooker', variant='white_bare', x=177, y=106), dict(id='fridge_tall', variant='mint', x=144, y=106), dict(id='table_kitchen', variant='dinette', x=209, y=118), dict(id='light_dome_orange', variant='orange', x=153, y=0)],
        fallback_right=[dict(id='unit_sink', variant='yellow', x=208, y=106), dict(id='washer_unit', variant='yellow', x=178, y=106), dict(id='unit_cooker', variant='white_kettle', x=117, y=106), dict(id='fridge_tall', variant='mint', x=145, y=106), dict(id='table_kitchen', variant='dinette', x=44, y=117), dict(id='light_dome_orange', variant='orange', x=205, y=0)]),
    'kitchen/country': dict(
        legacy=2, weight=18, shell='kitchen_shell_c',
        centre=dict(tag='dining', x=[120, 250], anywhere=True),
        run=dict(count=[2, 4], must=['cooking'], x=[60, 190]),
        wall=dict(count=[1, 2], must=['wet']),
        tops=0.9, decor=[4, 6], clutter=[3, 4], rug=0.0, ceiling=0.8, min_front=2,
        fallback=[dict(id='sink_butler', variant='white', x=47, y=106), dict(id='range_recess', variant='green', x=90, y=106), dict(id='unit_base', variant='pine_open', x=166, y=106), dict(id='table_kitchen', variant='pine', x=198, y=120), dict(id='light_bulb', variant='a', x=220, y=0)],
        fallback_left=[dict(id='sink_butler', variant='white', x=80, y=106), dict(id='range_recess', variant='cream', x=181, y=106), dict(id='table_kitchen', variant='pine', x=112, y=117)],
        fallback_right=[dict(id='sink_butler', variant='white', x=212, y=106), dict(id='range_recess', variant='black', x=122, y=106), dict(id='table_kitchen', variant='pine', x=52, y=118), dict(id='light_bulb', variant='a', x=216, y=0)]),
    'kitchen/student': dict(
        legacy=3, weight=18, shell='kitchen_shell_d',
        centre=dict(tag='dining', x=[40, 210], anywhere=True),
        run=dict(count=[3, 5], must=['cold', 'cooking', 'wet'], x=[6, 36], sides=2),
        wall=dict(count=[0, 1], must=[]),
        tops=0.9, decor=[4, 6], clutter=[4, 6], rug=0.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='unit_sink', variant='white', x=63, y=106), dict(id='fridge_tall', variant='white_open', x=101, y=106), dict(id='unit_cooker', variant='white_bare', x=134, y=106), dict(id='table_kitchen', variant='camping', x=182, y=120), dict(id='light_bulb', variant='a', x=178, y=0)],
        fallback_left=[dict(id='unit_sink', variant='white', x=76, y=106), dict(id='washer_unit', variant='white', x=114, y=106), dict(id='unit_cooker', variant='black_bare', x=177, y=106), dict(id='fridge_tall', variant='white_open', x=144, y=106), dict(id='table_kitchen', variant='camping', x=209, y=118), dict(id='light_bulb', variant='a', x=161, y=0)],
        fallback_right=[dict(id='unit_sink', variant='white', x=208, y=106), dict(id='unit_base', variant='white_dd', x=178, y=106), dict(id='unit_cooker', variant='white_bare', x=117, y=106), dict(id='fridge_tall', variant='white_open', x=145, y=106), dict(id='table_kitchen', variant='camping', x=46, y=117), dict(id='light_tube', variant='a', x=162, y=0)]),
    'kitchen/hoarder': dict(
        legacy=4, weight=16, shell='kitchen_shell_e',
        centre=dict(tag='dining', x=[120, 230], anywhere=True),
        run=dict(count=[3, 5], must=['cooking', 'wet'], x=[50, 110]),
        wall=dict(count=[0, 1], must=['clutter|storage']),
        tops=0.9, decor=[4, 6], clutter=[4, 6], rug=0.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='unit_cooker', variant='black_bare', x=102, y=106), dict(id='unit_sink', variant='cream', x=130, y=106), dict(id='table_kitchen', variant='trestle', x=189, y=120), dict(id='light_bulb', variant='a', x=159, y=0)],
        fallback_left=[dict(id='unit_sink', variant='cream', x=76, y=106), dict(id='unit_base', variant='cream_two', x=114, y=106), dict(id='unit_cooker', variant='cream_bare', x=144, y=106), dict(id='table_kitchen', variant='trestle', x=216, y=118), dict(id='light_bulb', variant='a', x=216, y=0)],
        fallback_right=[dict(id='unit_sink', variant='cream', x=208, y=106), dict(id='unit_base', variant='cream_drawers', x=178, y=106), dict(id='unit_cooker', variant='black_bare', x=150, y=106), dict(id='table_kitchen', variant='trestle', x=85, y=119), dict(id='light_bulb', variant='a', x=231, y=0)]),
})

RECIPES.update({
    'living_room/cosy': dict(
        legacy=0, weight=26, shell='living_shell_a',
        centre=dict(tag='sofa', x=[40, 190]),
        flank=dict(tag='armchair', chance=0.8),
        wall=dict(count=[2, 3], must=['books|storage']),
        tops=0.9, decor=[3, 5], clutter=[2, 4], rug=0.7, ceiling=0.9, min_front=2,
        fallback=[dict(id='side_table', variant='drawer', x=213, y=105), dict(id='bookcase_low', variant='dark', x=47, y=107), dict(id='sofa', variant='gold', x=81, y=110), dict(id='coffee_table', variant='wood', x=97, y=116)],
        fallback_left=[dict(id='side_table', variant='round', x=64, y=105), dict(id='chest_drawers', variant='dark', x=226, y=106), dict(id='sofa', variant='gold', x=139, y=109), dict(id='armchair', variant='club_red_r35', x=105, y=114), dict(id='coffee_table', variant='wood', x=155, y=114), dict(id='ceiling_pendant', variant='cream', x=223, y=0)],
        fallback_right=[dict(id='trunk', variant='leather', x=212, y=105), dict(id='bookcase_low', variant='light', x=161, y=107), dict(id='sofa', variant='gold', x=62, y=111), dict(id='ceiling_flush', variant='a', x=194, y=0)]),
    'living_room/mid': dict(
        legacy=1, weight=22, shell='living_shell_b',
        centre=dict(tag='sofa', x=[40, 190]),
        flank=dict(tag='armchair', chance=0.7),
        wall=dict(count=[2, 3], must=['sideboard']),
        tops=0.9, decor=[3, 5], clutter=[2, 4], rug=0.6, ceiling=0.9, min_front=2,
        fallback=[dict(id='shelving_open', variant='oak', x=46, y=106), dict(id='sideboard', variant='teak', x=178, y=108), dict(id='sofa', variant='avocado', x=81, y=110), dict(id='coffee_table', variant='kidney', x=97, y=116), dict(id='ceiling_pendant', variant='rose', x=232, y=0)],
        fallback_left=[dict(id='sideboard', variant='teak', x=172, y=105), dict(id='side_table', variant='drawer', x=246, y=107), dict(id='loveseat', variant='mustard', x=99, y=112), dict(id='armchair', variant='club_mustard_r35', x=65, y=115), dict(id='coffee_table', variant='kidney', x=105, y=116), dict(id='ceiling_flush', variant='a', x=157, y=0)],
        fallback_right=[dict(id='side_table', variant='round', x=150, y=105), dict(id='sideboard', variant='teak', x=184, y=107), dict(id='sofa', variant='olive', x=62, y=111), dict(id='ceiling_flush', variant='a', x=203, y=0)]),
    'living_room/squat': dict(
        legacy=2, weight=20, shell='living_shell_c',
        centre=dict(tag='sofa', x=[40, 200]),
        wall=dict(count=[2, 3], must=['books|storage']),
        tops=0.9, decor=[4, 6], clutter=[4, 6], rug=0.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='shelving_open', variant='teak', x=112, y=105), dict(id='crate_cubes', variant='dairy', x=68, y=108), dict(id='sofa', variant='denim', x=156, y=110), dict(id='coffee_table', variant='pallet', x=172, y=114), dict(id='light_bulb', variant='a', x=195, y=0)],
        fallback_left=[dict(id='crate_cubes', variant='primary', x=209, y=105), dict(id='chest_drawers', variant='light', x=155, y=105), dict(id='sofa', variant='grey', x=61, y=109), dict(id='coffee_table', variant='pallet', x=77, y=114), dict(id='light_bulb', variant='a', x=240, y=0)],
        fallback_right=[dict(id='crate_cubes', variant='primary', x=48, y=107), dict(id='radiator', variant='iron', x=208, y=108), dict(id='sofa', variant='denim', x=114, y=111), dict(id='coffee_table', variant='pallet', x=130, y=118), dict(id='ceiling_flush', variant='a', x=179, y=0)]),
    'living_room/parlour': dict(
        legacy=3, weight=18, shell='living_shell_d',
        centre=dict(tag='sofa', x=[40, 190]),
        flank=dict(tag='armchair', chance=0.8),
        wall=dict(count=[2, 3], must=['music|display']),
        tops=0.9, decor=[3, 5], clutter=[1, 3], rug=0.8, ceiling=0.9, min_front=2,
        fallback=[dict(id='clock_grandfather', variant='oak', x=53, y=105), dict(id='piano_upright', variant='ebonised', x=201, y=105), dict(id='sofa', variant='burgundy', x=81, y=110), dict(id='stool_piano', variant='oak_green', x=243, y=116), dict(id='coffee_table', variant='tea', x=97, y=116), dict(id='ceiling_pendant', variant='rose', x=200, y=0)],
        fallback_left=[dict(id='china_cabinet', variant='oak', x=238, y=105), dict(id='sofa', variant='burgundy', x=139, y=109), dict(id='armchair', variant='club_green_r35', x=105, y=114), dict(id='coffee_table', variant='tea', x=155, y=114), dict(id='ceiling_flush', variant='a', x=211, y=0)],
        fallback_right=[dict(id='china_cabinet', variant='mahogany', x=148, y=106), dict(id='sideboard', variant='walnut', x=206, y=107), dict(id='sofa', variant='velvet', x=62, y=111)]),
    'living_room/lodge': dict(
        legacy=-1, weight=14, shell='living_shell_e',
        centre=dict(tag='sofa', x=[40, 200]),
        flank=dict(tag='armchair', chance=0.7),
        wall=dict(count=[1, 2], must=['hearth']),
        tops=0.9, decor=[3, 5], clutter=[2, 4], rug=0.7, ceiling=0.9, min_front=2,
        fallback=[dict(id='side_table', variant='drawer', x=218, y=107), dict(id='fireplace', variant='stone', x=67, y=107), dict(id='loveseat', variant='oxblood', x=145, y=112), dict(id='coffee_table', variant='trunk', x=151, y=117), dict(id='ceiling_pendant', variant='rose', x=153, y=0)],
        fallback_left=[dict(id='side_table', variant='drawer', x=156, y=105), dict(id='fireplace', variant='brick', x=183, y=108), dict(id='sofa', variant='tartan', x=61, y=109), dict(id='coffee_table', variant='trunk', x=77, y=114)],
        fallback_right=[dict(id='fireplace', variant='brick', x=58, y=108), dict(id='loveseat', variant='oxblood', x=171, y=109), dict(id='coffee_table', variant='trunk', x=177, y=115), dict(id='armchair', variant='wing_brown_r35', x=137, y=118), dict(id='ceiling_flush', variant='a', x=206, y=0)]),
})



RECIPES.update({
    # ---- dining rooms (round 47f): A family, B diner, C formal, D houseshare, E party. The table carries its chairs; balcony slots block x 4..96 (ctx.blocked).
    'dining_room/family': dict(
        legacy=0, weight=26, shell='dining_shell_a',
        centre=dict(tag='dining', x=[30, 210]),
        wall=dict(count=[1, 3], must=['storage|clock']),
        tops=0.9, decor=[3, 5], clutter=[2, 3], rug=0.5, ceiling=0.9, min_front=2,
        fallback=[dict(id='clock_grandfather', variant='mahogany', x=141, y=105), dict(id='table_dining', variant='family', x=182, y=118), dict(id='ceiling_pendant', variant='green', x=179, y=0)],
        fallback_left=[dict(id='piano_upright', variant='ebonised', x=222, y=105), dict(id='table_dining', variant='family', x=85, y=115), dict(id='stool_piano', variant='oak_tan', x=195, y=118), dict(id='ceiling_pendant', variant='mustard', x=220, y=0)],
        fallback_right=[dict(id='china_cabinet', variant='mahogany', x=77, y=107), dict(id='clock_grandfather', variant='oak', x=119, y=107), dict(id='table_dining', variant='family', x=149, y=117), dict(id='ceiling_pendant', variant='green', x=201, y=0)]),
    'dining_room/diner': dict(
        legacy=1, weight=20, shell='dining_shell_b',
        centre=dict(tag='dining', x=[30, 210]),
        wall=dict(count=[2, 3], want=['sideboard']),
        tops=0.9, decor=[3, 5], clutter=[1, 3], rug=0.0, ceiling=0.9, min_front=2,
        fallback=[dict(id='table_dining', variant='diner', x=140, y=115), dict(id='ceiling_pendant', variant='mustard', x=190, y=0)],
        fallback_left=[dict(id='sideboard', variant='teak', x=201, y=108), dict(id='table_dining', variant='diner', x=85, y=115), dict(id='ceiling_pendant', variant='mustard', x=163, y=0)],
        fallback_right=[dict(id='side_table', variant='round', x=249, y=105), dict(id='sideboard', variant='teak', x=57, y=105), dict(id='table_dining', variant='diner', x=149, y=117), dict(id='light_dome_orange', variant='orange', x=182, y=0)]),
    'dining_room/formal': dict(
        legacy=2, weight=18, shell='dining_shell_c',
        centre=dict(tag='dining', x=[30, 210]),
        wall=dict(count=[2, 3], must=['clock|display']),
        tops=0.9, decor=[3, 5], clutter=[1, 3], rug=0.6, ceiling=0.9, min_front=2,
        fallback=[dict(id='clock_grandfather', variant='oak', x=148, y=108), dict(id='table_dining', variant='formal', x=182, y=118)],
        fallback_left=[dict(id='clock_grandfather', variant='oak', x=251, y=105), dict(id='radiator', variant='cream', x=76, y=105), dict(id='table_dining', variant='formal', x=146, y=114), dict(id='ceiling_flush', variant='a', x=166, y=0)],
        fallback_right=[dict(id='china_cabinet', variant='mahogany', x=162, y=108), dict(id='radiator', variant='iron', x=208, y=109), dict(id='table_dining', variant='formal', x=62, y=115), dict(id='ceiling_pendant', variant='rose', x=211, y=0)]),
    'dining_room/houseshare': dict(
        legacy=3, weight=16, shell='dining_shell_d',
        centre=dict(tag='dining', x=[40, 200]),
        wall=dict(count=[2, 3], must=['storage']),
        tops=0.9, decor=[3, 5], clutter=[3, 5], rug=0.0, ceiling=0.8, min_front=2,
        fallback=[dict(id='boxes_stack', variant='closed', x=241, y=108), dict(id='table_dining', variant='shared', x=145, y=118), dict(id='ceiling_flush', variant='a', x=181, y=0)],
        fallback_left=[dict(id='boxes_stack', variant='closed', x=240, y=105), dict(id='radiator', variant='cream', x=76, y=105), dict(id='side_table', variant='drawer', x=47, y=106), dict(id='table_dining', variant='shared', x=147, y=114), dict(id='ceiling_flush', variant='a', x=151, y=0)],
        fallback_right=[dict(id='side_table', variant='round', x=248, y=105), dict(id='trunk', variant='leather', x=68, y=105), dict(id='radiator', variant='cream', x=208, y=109), dict(id='table_dining', variant='shared', x=114, y=117)]),
    'dining_room/party': dict(
        legacy=4, weight=14, shell='dining_shell_e',
        centre=dict(tag='dining', x=[30, 210]),
        wall=dict(count=[2, 3], want=['sideboard']),
        tops=0.9, decor=[4, 6], clutter=[2, 4], rug=0.0, ceiling=0.8, min_front=2,
        fallback=[dict(id='table_dining', variant='party', x=140, y=115)],
        fallback_left=[dict(id='sideboard', variant='oak', x=201, y=108), dict(id='table_dining', variant='party', x=85, y=115)],
        fallback_right=[dict(id='side_table', variant='round', x=249, y=105), dict(id='sideboard', variant='oak', x=57, y=105), dict(id='table_dining', variant='party', x=149, y=117), dict(id='ceiling_flush', variant='a', x=207, y=0)]),
})


RECIPES.update({
    # ---- studies (round 47f): A den, B office, C library, D radio room, E studio. The desk carries its chair; balcony slots block x 4..96 (ctx.blocked).
    'study/den': dict(
        legacy=0, weight=24, shell='study_shell_a',
        centre=dict(tag='desk', x=[40, 200]),
        wall=dict(count=[3, 4], must=['books|files']),
        tops=0.9, decor=[3, 5], clutter=[2, 3], rug=0.5, ceiling=0.9, min_front=2,
        fallback=[dict(id='filing_cabinet', variant='grey', x=245, y=106), dict(id='desk_study', variant='mahogany', x=156, y=112), dict(id='waste_bin', variant='steel', x=229, y=114), dict(id='ceiling_pendant', variant='rose', x=227, y=0)],
        fallback_left=[dict(id='filing_cabinet', variant='cream', x=248, y=106), dict(id='desk_study', variant='mahogany', x=147, y=110), dict(id='waste_bin', variant='steel', x=220, y=114), dict(id='ceiling_pendant', variant='cream', x=227, y=0)],
        fallback_right=[dict(id='radiator', variant='iron', x=208, y=105), dict(id='bookcase_tall', variant='ladder', x=50, y=108), dict(id='desk_study', variant='mahogany', x=114, y=113), dict(id='waste_bin', variant='wire', x=187, y=114), dict(id='ceiling_flush', variant='a', x=169, y=0)]),
    'study/office': dict(
        legacy=1, weight=22, shell='study_shell_b',
        centre=dict(tag='desk', x=[40, 200]),
        wall=dict(count=[3, 5], must=['files']),
        tops=0.9, decor=[3, 5], clutter=[3, 5], rug=0.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='filing_cabinet', variant='grey', x=245, y=106), dict(id='desk_study', variant='steel', x=156, y=112), dict(id='waste_bin', variant='steel', x=229, y=114), dict(id='light_tube', variant='a', x=228, y=0)],
        fallback_left=[dict(id='shelving_open', variant='teak', x=200, y=105), dict(id='filing_cabinet', variant='green', x=248, y=106), dict(id='bookcase_tall', variant='mahogany', x=161, y=108), dict(id='desk_study', variant='steel', x=61, y=111), dict(id='waste_bin', variant='steel', x=134, y=114), dict(id='ceiling_flush', variant='a', x=238, y=0)],
        fallback_right=[dict(id='radiator', variant='iron', x=208, y=105), dict(id='filing_cabinet', variant='cream', x=70, y=106), dict(id='desk_study', variant='steel', x=114, y=113), dict(id='waste_bin', variant='wire', x=187, y=114), dict(id='ceiling_flush', variant='a', x=172, y=0)]),
    'study/library': dict(
        legacy=2, weight=20, shell='study_shell_c',
        centre=dict(tag='desk', x=[40, 200]),
        flank=dict(tag='armchair', chance=0.6),
        wall=dict(count=[3, 4], must=['books']),
        tops=0.9, decor=[2, 4], clutter=[1, 3], rug=0.6, ceiling=0.9, min_front=2,
        fallback=[dict(id='bookcase_tall', variant='ladder', x=238, y=107), dict(id='desk_study', variant='writing', x=156, y=112), dict(id='ceiling_pendant', variant='mustard', x=151, y=0)],
        fallback_left=[dict(id='bookcase_tall', variant='mahogany', x=237, y=105), dict(id='radiator', variant='iron', x=70, y=109), dict(id='desk_study', variant='writing', x=147, y=110), dict(id='waste_bin', variant='steel', x=219, y=116), dict(id='armchair', variant='wing_green_l35', x=109, y=118), dict(id='ceiling_pendant', variant='cream', x=198, y=0)],
        fallback_right=[dict(id='bookcase_tall', variant='oak', x=62, y=108), dict(id='radiator', variant='iron', x=211, y=109), dict(id='waste_bin', variant='steel', x=212, y=113), dict(id='desk_study', variant='writing', x=140, y=113), dict(id='armchair', variant='wing_brown_l35', x=102, y=115), dict(id='ceiling_flush', variant='a', x=179, y=0)]),
    'study/radio': dict(
        legacy=3, weight=18, shell='study_shell_d',
        centre=dict(tag='desk', x=[40, 200]),
        wall=dict(count=[3, 5], must=['storage']),
        tops=0.9, decor=[3, 5], clutter=[3, 5], rug=0.0, ceiling=0.9, min_front=2,
        fallback=[dict(id='bookcase_low', variant='oak', x=243, y=107), dict(id='desk_study', variant='trestle', x=156, y=112), dict(id='waste_bin', variant='steel', x=229, y=114), dict(id='light_bulb', variant='a', x=227, y=0)],
        fallback_left=[dict(id='shelving_open', variant='oak', x=240, y=106), dict(id='bookcase_low', variant='oak', x=204, y=107), dict(id='bookcase_tall', variant='mahogany', x=161, y=108), dict(id='desk_study', variant='trestle', x=61, y=111), dict(id='waste_bin', variant='steel', x=134, y=114), dict(id='light_bulb', variant='a', x=204, y=0)],
        fallback_right=[dict(id='radiator', variant='iron', x=208, y=105), dict(id='bookcase_tall', variant='ladder', x=50, y=108), dict(id='desk_study', variant='trestle', x=114, y=113), dict(id='waste_bin', variant='wire', x=187, y=114), dict(id='light_bulb', variant='a', x=232, y=0)]),
    'study/studio': dict(
        legacy=4, weight=16, shell='study_shell_e',
        centre=dict(tag='desk', x=[40, 200]),
        wall=dict(count=[3, 5], must=['art']),
        tops=0.9, decor=[3, 5], clutter=[3, 5], rug=0.0, ceiling=0.9, min_front=2,
        fallback=[dict(id='paint_shelf', variant='pine', x=245, y=106), dict(id='desk_study', variant='bench', x=156, y=112), dict(id='waste_bin', variant='steel', x=229, y=114)],
        fallback_left=[dict(id='canvases_leaning', variant='few', x=172, y=105), dict(id='paint_shelf', variant='pine', x=234, y=106), dict(id='desk_study', variant='bench', x=61, y=111), dict(id='waste_bin', variant='steel', x=134, y=114), dict(id='ceiling_flush', variant='a', x=215, y=0)],
        fallback_right=[dict(id='radiator', variant='iron', x=208, y=105), dict(id='canvases_leaning', variant='stack', x=48, y=106), dict(id='desk_study', variant='bench', x=114, y=113), dict(id='waste_bin', variant='wire', x=187, y=114), dict(id='ceiling_flush', variant='a', x=206, y=0)]),
})


RECIPES.update({
    # ---- bathrooms (round 47f): A tub (classic), B avocado, C gilded, D wetroom, E pink. The fixtures are FRONT pieces (`planes`), lifted from the old module's own 3D drawings.
    'bathroom/tub': dict(
        legacy=0, weight=26, shell='bath_shell_a',
        centre=dict(tag='bath|shower', x=[44, 84], mirror=True),
        wall=dict(count=[2, 3], must=['toilet', 'basin'], want=['linen'], planes=['wall', 'front']),
        tops=0.9, decor_must=['mirror_bath'], decor=[3, 4], clutter=[2, 4], rug=1.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='linen_cupboard', variant='cream', x=129, y=105), dict(id='basin', variant='pedestal', x=218, y=114), dict(id='shower_walkin', variant='glass', x=77, y=114), dict(id='toilet', variant='white', x=167, y=114), dict(id='ceiling_flush', variant='a', x=152, y=0)],
        fallback_left=[dict(id='linen_cupboard', variant='cream', x=179, y=105), dict(id='shower_walkin', variant='glass', x=216, y=114), dict(id='basin', variant='pedestal', x=72, y=114), dict(id='toilet', variant='white', x=125, y=114), dict(id='ceiling_flush', variant='a', x=201, y=0)],
        fallback_right=[dict(id='radiator', variant='cream', x=208, y=106), dict(id='shower_walkin', variant='glass', x=54, y=114), dict(id='basin', variant='pedestal', x=99, y=114), dict(id='toilet', variant='white', x=149, y=114), dict(id='ceiling_flush', variant='a', x=227, y=0)]),
    'bathroom/avocado': dict(
        legacy=1, weight=20, shell='bath_shell_b',
        centre=dict(tag='bath|shower', x=[44, 84], mirror=True),
        wall=dict(count=[2, 3], must=['toilet', 'basin'], want=['linen'], planes=['wall', 'front']),
        tops=0.9, decor_must=['mirror_bath'], decor=[3, 4], clutter=[2, 4], rug=1.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='toilet', variant='avocado', x=47, y=114), dict(id='bath', variant='panel', x=168, y=114), dict(id='vanity', variant='avocado', x=103, y=114), dict(id='ceiling_flush', variant='a', x=197, y=0)],
        fallback_left=[dict(id='vanity', variant='avocado', x=46, y=114), dict(id='bath', variant='panel', x=168, y=114), dict(id='toilet', variant='avocado', x=120, y=114), dict(id='ceiling_flush', variant='a', x=212, y=0)],
        fallback_right=[dict(id='toilet', variant='avocado', x=226, y=114), dict(id='bath', variant='panel', x=53, y=114), dict(id='vanity', variant='avocado', x=162, y=114), dict(id='ceiling_flush', variant='a', x=181, y=0)]),
    'bathroom/gilded': dict(
        legacy=2, weight=14, shell='bath_shell_c',
        centre=dict(tag='bath', x=[60, 190]),
        wall=dict(count=[2, 3], must=['toilet', 'basin'], planes=['wall', 'front']),
        tops=0.9, decor_must=['mirror_bath'], decor=[3, 4], clutter=[2, 3], rug=1.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='washstand', variant='gilt', x=46, y=114), dict(id='bath', variant='gold', x=170, y=114), dict(id='toilet', variant='gold', x=108, y=114), dict(id='chandelier', variant='gold', x=186, y=0)],
        fallback_left=[dict(id='washstand', variant='gilt', x=44, y=114), dict(id='toilet', variant='gold', x=222, y=114), dict(id='bath', variant='gold', x=113, y=114), dict(id='chandelier', variant='gold', x=201, y=0)],
        fallback_right=[dict(id='toilet', variant='gold', x=49, y=114), dict(id='bath', variant='gold', x=176, y=114), dict(id='washstand', variant='gilt', x=104, y=114), dict(id='chandelier', variant='gold', x=163, y=0)]),
    'bathroom/wetroom': dict(
        legacy=3, weight=20, shell='bath_shell_d',
        centre=dict(tag='bath|shower', x=[44, 84], mirror=True),
        wall=dict(count=[3, 4], must=['toilet', 'laundry'], want=['basin'], planes=['wall', 'front']),
        tops=0.9, decor_must=['mirror_bath'], decor=[2, 4], clutter=[3, 5], rug=0.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='shower_walkin', variant='glass', x=58, y=114), dict(id='toilet', variant='wet', x=105, y=114), dict(id='washer', variant='shut', x=158, y=114), dict(id='ceiling_flush', variant='a', x=219, y=0)],
        fallback_left=[dict(id='shower_walkin', variant='glass', x=209, y=114), dict(id='toilet', variant='wet', x=82, y=114), dict(id='washer', variant='open', x=139, y=114), dict(id='ceiling_flush', variant='a', x=162, y=0)],
        fallback_right=[dict(id='shower_walkin', variant='glass', x=66, y=114), dict(id='toilet', variant='wet', x=194, y=114), dict(id='washer', variant='open', x=128, y=114), dict(id='ceiling_flush', variant='a', x=212, y=0)]),
    'bathroom/pink': dict(
        legacy=4, weight=20, shell='bath_shell_e',
        centre=dict(tag='bath|shower', x=[44, 84], mirror=True),
        wall=dict(count=[2, 3], must=['toilet', 'basin'], want=['linen'], planes=['wall', 'front']),
        tops=0.9, decor_must=['mirror_bath'], decor=[3, 4], clutter=[2, 4], rug=1.0, ceiling=1.0, min_front=2,
        fallback=[dict(id='toilet', variant='pink', x=217, y=114), dict(id='bath', variant='tiled', x=56, y=114), dict(id='basin', variant='pink', x=164, y=114), dict(id='ceiling_flush', variant='a', x=160, y=0)],
        fallback_left=[dict(id='toilet', variant='pink', x=47, y=114), dict(id='basin', variant='pink', x=94, y=114), dict(id='bath', variant='tiled', x=141, y=114), dict(id='ceiling_flush', variant='a', x=211, y=0)],
        fallback_right=[dict(id='toilet', variant='pink', x=201, y=114), dict(id='bath', variant='tiled', x=46, y=114), dict(id='basin', variant='pink', x=152, y=114), dict(id='ceiling_flush', variant='a', x=230, y=0)]),
})


# The room types whose pieces + shells are BUILT into the library (furn_build.py / furn_shells.py export and check only these). A room type's recipes may be written before its pieces exist; they
# do not reach data/furniture.json - so the game never plans a room it has no pieces or shell for - until the type is added here.
BUILT = ('bedroom', 'kitchen', 'living_room', 'dining_room', 'study', 'bathroom')


def _module_space(rcp):
    """A recipe is AUTHORED in the art's design coordinates (the 320 px canvas); the game plans in MODULE coordinates (pixlib.PAD columns narrower on each side): a centre piece's x range, a run
    that starts away from the walls (x range above the 40 px edge offsets) and every fallback layout move in by PAD. (A run's small x is an offset from the wall it starts at: unchanged.)"""
    import copy
    import pixlib as PX
    if PX.PAD == 0:
        return rcp
    r = copy.deepcopy(rcp)
    lo_edge = 4
    c = r.get('centre')
    if c and 'x' in c:
        c['x'] = [max(lo_edge, c['x'][0] - PX.PAD), max(lo_edge, c['x'][1] - PX.PAD)]
    run = r.get('run')
    if run and 'x' in run and run['x'][1] > 40:
        run['x'] = [max(lo_edge, run['x'][0] - PX.PAD), max(lo_edge, run['x'][1] - PX.PAD)]
    for key in ('fallback', 'fallback_left', 'fallback_right'):
        for f in r.get(key, []):
            f['x'] = f['x'] - PX.PAD
    return r


def built_recipes():
    return {k: _module_space(v) for k, v in RECIPES.items() if k.split('/')[0] in BUILT}


# THE LOGIC as data: piece tags -> the only room types they may be registered in (furnlib.TAG_ROOMS is the source; exported so the game and its tests read the same table).
def rules():
    import furnlib as FL
    import home_logic as HL
    return {'tag_rooms': {k: list(v) for k, v in FL.TAG_ROOMS.items()}, 'home': HL.rules()}
