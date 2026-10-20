"""WHICH ROOMS USE THE SHARED PIECES (owner round 47f). The first pieces were written for bedroom (and kitchen) styles; many of them belong just as well in a living room, a dining room, a study or a
bathroom (a bookcase, a chest of drawers, a clock, a plant, a mirror, a lamp). Rather than edit each one, these tables add styles (and rooms, and surface kinds) to a piece AFTER every piece is
registered. A piece that lists no styles at all is for every style already and needs no styles entry here. Import it after the piece modules and call `apply()`.

    STYLES[pid] = {style: weight}      added to the piece's style weights (ignored for a piece with no style list: it is for every style already)
    ROOMS[pid]  = {room: weight}       the room types the piece may now also stand in (the tag rules in furnlib.TAG_ROOMS are re-checked)
    ON[pid]     = (kind, …)            surface kinds it may now also stand on
"""
import furnlib as FL

STYLES = {
    # ---- living rooms (cosy mid squat parlour lodge)
    'backpack': {'squat': 4, 'barricade': 4, 'radio': 3},
    'bin_bags': {'squat': 6, 'barricade': 4, 'party': 1},
    'bookcase_low': {'cosy': 6, 'parlour': 4, 'lodge': 3, 'mid': 1, 'den': 4, 'library': 3, 'studio': 2},
    'calendar_wall': {'cosy': 2, 'squat': 1, 'office': 5, 'den': 2, 'radio': 2},
    'ceiling_pendant': {'cosy': 4, 'mid': 3, 'parlour': 3, 'lodge': 3, 'family': 4, 'formal': 4, 'diner': 2, 'den': 3, 'library': 3},
    'chest_drawers': {'cosy': 6, 'parlour': 2, 'lodge': 2},
    'clock_cuckoo': {'cosy': 2, 'lodge': 4, 'parlour': 2, 'family': 3},
    'clock_regulator': {'parlour': 5, 'cosy': 2, 'lodge': 3, 'formal': 5, 'family': 2, 'library': 4, 'den': 3},
    'clock_wall': {'cosy': 3, 'mid': 3, 'squat': 1, 'parlour': 1, 'diner': 3, 'family': 3, 'party': 2, 'formal': 1, 'office': 4, 'den': 2, 'library': 1},
    'floor_stain': {'squat': 5, 'cosy': 1, 'barricade': 6, 'wetroom': 5},
    'frame_family': {'cosy': 5, 'parlour': 3, 'mid': 2, 'family': 5, 'party': 2, 'den': 3},
    'frame_ghost': {'cosy': 2, 'parlour': 2, 'barricade': 2},
    'lamp_lava': {'squat': 4, 'mid': 3},
    'lantern_battery': {'squat': 2, 'barricade': 4, 'radio': 3},
    'mirror_wall': {'cosy': 3, 'mid': 3, 'parlour': 4, 'formal': 4, 'diner': 2},
    'missing_lucy': {'squat': 3, 'barricade': 4},
    'newspaper_evacuate': {'squat': 6, 'barricade': 6},
    'newspaper_stacks': {'squat': 3, 'barricade': 3, 'den': 2, 'radio': 3, 'library': 2},
    'photo_small': {'cosy': 4, 'parlour': 3, 'mid': 3, 'family': 3, 'formal': 2, 'den': 3, 'office': 2},
    'photo_wedding': {'cosy': 2, 'parlour': 4},
    'picture_landscape': {'cosy': 6, 'mid': 3, 'lodge': 2, 'family': 5, 'formal': 2, 'diner': 2, 'den': 3, 'library': 2, 'office': 1},
    'picture_portrait': {'parlour': 5, 'cosy': 3, 'formal': 3, 'family': 2, 'library': 5, 'den': 2},
    'pizza_boxes': {'squat': 8, 'party': 2},
    'plant_pot': {'cosy': 3, 'mid': 4, 'parlour': 2, 'lodge': 1, 'family': 3, 'diner': 4, 'formal': 2, 'office': 4, 'den': 2, 'library': 3, 'gilded': 5, 'tub': 2, 'pink': 2},
    'poster_film': {'squat': 4},
    'poster_game': {'squat': 4},
    'poster_gig': {'squat': 6, 'studio': 2},
    'poster_rainbow': {'diner': 4},
    'sampler_home': {'cosy': 3, 'parlour': 2},
    'trainers': {'squat': 4},
    'wall_shelf': {'cosy': 3, 'mid': 3, 'squat': 1, 'lodge': 2, 'family': 3, 'diner': 2, 'den': 3, 'radio': 2, 'studio': 2},
    'boxes_stack': {'barricade': 6, 'radio': 5, 'studio': 2},
    'timetable': {'office': 6},
    'lamp_floor': {'library': 6, 'den': 3, 'office': 1},
    'armchair': {'library': 6, 'den': 5, 'office': 3, 'studio': 2},
    # ---- bathrooms (tub avocado gilded wetroom pink)
    'pill_cabinet': {'tub': 3, 'avocado': 3, 'wetroom': 2, 'pink': 3},
    'clothes_pile': {'wetroom': 6, 'tub': 1},
    'slippers': {'pink': 3, 'tub': 3, 'avocado': 2},
    'bucket_mop': {'wetroom': 4, 'tub': 2},
    'waste_bin': {'tub': 3, 'avocado': 2, 'pink': 3, 'wetroom': 2},
    'light_tube': {'office': 6, 'wetroom': 3},
}
ROOMS = {
    'chest_drawers': {'living_room': 4},
    'lamp_lava': {'living_room': 3},
    'newspaper_stacks': {'living_room': 3, 'dining_room': 1},
    'pizza_boxes': {'living_room': 3, 'dining_room': 2},
    'poster_game': {'living_room': 3},
    'poster_rainbow': {'dining_room': 3},
    'bin_bags': {'dining_room': 2},
    'box_cardboard': {'dining_room': 2},
    'newspaper_evacuate': {'dining_room': 3, 'study': 2},
    'backpack': {'dining_room': 2, 'study': 2},
    'floor_stain': {'dining_room': 3, 'study': 2},
    'missing_lucy': {'dining_room': 2},
    'mugs': {'dining_room': 3},
    'frame_ghost': {'dining_room': 3, 'study': 1},
    'lantern_battery': {'dining_room': 2},
    'boxes_stack': {'dining_room': 3, 'study': 4},
    'photo_small': {'study': 3},
    'calendar_wall': {'dining_room': 2},
    'clock_cuckoo': {'dining_room': 3},
}
ON = {
    'fruit_bowl': ('table',),
    'teapot': ('table', 'low'),
    'mugs': ('table', 'low'),
    'glass_water': ('table', 'low', 'desk'),
    'photo_small': ('table', 'desk'),
    'book_pile': ('desk', 'table', 'low'),
    'lamp_table': ('desk',),
    'lantern_battery': ('desk',),
    'alarm_clock': (),
}


def apply():
    for pid, styles in STYLES.items():
        pc = FL.REGISTRY.get(pid)                                           # a piece of a room type that is not built yet is simply absent
        if pc is not None and pc.styles is not None:
            pc.styles.update(styles)
    for pid, rooms in ROOMS.items():
        if pid in FL.REGISTRY:
            FL.REGISTRY[pid].rooms.update(rooms)
    for pid, kinds in ON.items():
        pc = FL.REGISTRY.get(pid)
        if pc is not None:
            pc.on = tuple(dict.fromkeys(tuple(pc.on) + tuple(kinds)))
