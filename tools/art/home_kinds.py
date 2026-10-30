"""WHAT EVERY THING IS, AND WHERE A HOME COULD HAVE IT (owner round 48k: "this logic needs to be for everything… a piano could obviously be in a living room, a bedroom, a study, even a dining
room, but no one on earth has a piano in their kitchen or their bathroom… I don't want players to go into any apartment, see a piece of furniture or decoration and say 'erm, that shouldn't be there'").

Every piece in the furniture library is one KIND of thing, and every kind lists the ONLY rooms a home could plausibly keep it in — an UPPER BOUND, not a recipe (a piano is a thing a home
can have in four rooms; which of those the game actually deals it into is the piece's own `rooms` / `styles` weights, and that list must stay inside the bound). The planner deals only from the
bound (`FurniturePlanner.home_issue`), registration refuses a piece outside it, a piece with no kind cannot be registered at all, and `validate_state` re-checks every placement.

    to add a piece:  give it a kind in PIECE_KIND below (or a new kind in KINDS with the rooms a home could keep it in and one line saying why)
    to widen a kind: change its rooms here, nowhere else — then regenerate (docs/HOME_LOGIC.md lists every kind, every piece in it, and where the game actually uses it).

Rooms: B bedroom, T bathroom, K kitchen, S study, L living room, D dining room.
"""
ROOM_NAMES = {'B': 'bedroom', 'T': 'bathroom', 'K': 'kitchen', 'S': 'study', 'L': 'living_room', 'D': 'dining_room'}


def R(letters):
    return tuple(ROOM_NAMES[ch] for ch in letters)


ALL = 'BTKSLD'

# kind: (rooms a home could keep it in, why)
KINDS = {
    # ---- sleeping, clothes, personal
    'bed':              ('B',    'a bed is where somebody sleeps: a bedroom'),
    'wardrobe':         ('B',    'clothes are kept where they are put on'),
    'bedside':          ('B',    'a bedside table is beside a bed'),
    'dressing_table':   ('B',    'somebody dresses at it: a bedroom'),
    'chest_of_drawers': ('BLS',  'a chest of drawers keeps clothes and linen: a bedroom, or a living room / study that doubles as one'),
    'clothes_rail':     ('BL',   'a rail of clothes is a bedroom thing (a living room that is slept in, too)'),
    'laundry_basket':   ('BT',   'dirty washing collects in a bedroom or a bathroom'),
    'washing_machine':  ('KT',   'a washing machine stands where there is a water supply and drain: the kitchen or the bathroom'),
    'toiletries':       ('BT',   'a hairbrush or scent is on a dressing table or by a basin'),
    'jewellery':        ('B',    'a jewellery box lives on a dressing table'),
    'medicine':         ('BTK',  'pills are by the bed, in the bathroom cabinet or the kitchen'),
    'care_equipment':   ('BL',   'a drip stand or a medical trolley is where somebody is nursed: beside a bed, or a sickbed made up in the living room'),
    'mobility_aid':     (ALL,    'a wheelchair goes wherever its user does'),
    'footwear':         ('BLST', 'shoes are kicked off by the bed or the door; slippers wait by the bath'),
    'luggage':          ('BLS',  'a suitcase is kept in a bedroom or the living room (on a wardrobe, under the stairs)'),
    'bag':              ('BLDSK', 'a bag is dropped by the bed, a chair or the door'),
    'alarm_clock':      ('BSKL', 'an alarm clock is by a bed, or on a desk / kitchen shelf'),
    # ---- bathroom
    'sanitaryware':     ('T',    'a toilet, basin, bath or shower is in a bathroom, and nowhere else'),
    'bath_furnishing':  ('T',    'a towel rail, bath mat, bathroom mirror or linen press belongs to the bathroom'),
    'cleaning':         ('KT',   'a mop and bucket stand where the mess is: the kitchen and the bathroom'),
    'drinks_stand':     ('DLT',  'a champagne stand is for celebrating: a dining room, a living room, or a grand bathroom'),
    # ---- kitchen
    'kitchen_unit':     ('K',    'a fitted unit, cooker, fridge or larder is a kitchen thing'),
    'kitchen_ware':     ('K',    'a kettle, toaster, microwave, board, tin or jar of utensils is kept in the kitchen'),
    'tableware':        ('KDL',  'a teapot, bowl, place setting or cake is on the kitchen or dining table, or on a living-room one'),
    'drinkware':        (ALL,    'a glass or a mug is wherever somebody was drinking'),
    'drinks':           ('KDL',  'a row of bottles is in the kitchen, the dining room or the living room'),
    'food_store':       ('KDL',  'tins, crates and takeaway boxes are food: the kitchen, or left in the dining / living room'),
    'dining_table':     ('DK',   'you eat at it: the dining room or the kitchen'),
    'dresser':          ('KDL',  'a Welsh dresser holds plates: kitchen, dining room, or a living room'),
    'rubbish':          (ALL,    'every room has a bin or a bag of rubbish somewhere'),
    # ---- living, study, dining
    'sofa':             ('LSB',  'a sofa is in a living room (a study or a bedsit can hold one)'),
    'armchair':         ('LBSD', 'an armchair is anywhere somebody sits to read or talk, but not where they cook or wash'),
    'chair':            ('BSDLK', 'a chair is at a desk or a table'),
    'pouf':             ('LB',   'a pouf is a living-room / bedroom seat'),
    'piano_stool':      ('LBSD', 'a piano stool stands wherever the piano does'),
    'dressing_stool':   ('B',    'a dressing-table stool is in the bedroom that has the table'),
    'coffee_table':     ('L',    'a low table is in front of the sofa'),
    'side_table':       ('LBDS', 'a side table stands beside a seat or a bed'),
    'sideboard':        ('DLK',  'a sideboard holds linen and crockery: dining room, living room, kitchen'),
    'display_cabinet':  ('DL',   'a china cabinet is for showing off: dining room or living room'),
    'bookcase':         ('BLSD', 'books are kept where people read'),
    'shelving':         ('BLSDK', 'open shelving holds things in any room people live in except the bathroom'),
    'shelf':            (ALL,    'a wall shelf can be in any room'),
    'fireplace':        ('LDB',  'a hearth is in a living room, a dining room or a bedroom'),
    'instrument':       ('LBSD', 'a piano or a guitar is in a living room, a bedroom, a study or a dining room — and never where food is cooked or people wash'),
    'long_case_clock':  ('LDSB', 'a grandfather clock stands in a room people sit in'),
    'tv':               ('LB',   'a television is in the living room (or the bedroom)'),
    'audio':            (ALL,    'a radio or a record player goes anywhere'),
    'hobby_gear':       ('SBL',  'an amateur radio station is a study / hobby-room thing'),
    'work_gear':        ('SBL',  'a computer, typewriter, printer or globe is a study thing (a desk in a bedroom or living room)'),
    'desk':             ('SBL',  'a desk is a study (or a corner of a bedroom / living room)'),
    'filing_cabinet':   ('SB',   'papers are filed in a study'),
    'art_supplies':     ('SLB',  'an easel, canvases and paint are a studio thing'),
    'paperwork':        ('SBLDK', 'a pile of papers is where somebody was doing the bills'),
    'reading':          (ALL,    'a book, a magazine, a paper is left anywhere'),
    'smoking':          ('LDSB', 'an ashtray is in a room people sit in'),
    'coat_stand':       ('BLS', 'a coat stand is by a door: a living room, a study or a bedsit that doubles as the hall (never where people eat or wash)'),
    'trunk':            ('BLDS', 'a trunk holds blankets and keepsakes'),
    'boxes':            (ALL,    'boxes are stored anywhere'),
    'radiator':         (ALL,    'every room is heated'),
    'toys':             ('BL',   'children play in their bedroom and the living room'),
    'party':            ('DLBK', 'party things are in the room the party was in'),
    # ---- light
    'ceiling_light':    (ALL,    'every room has a ceiling light'),
    'chandelier':       ('DLBT', 'a chandelier hangs in a grand room — dining, living, bedroom, or a gilded bathroom'),
    'table_lamp':       ('BSLD', 'a lamp stands on a table or desk in a room people sit or sleep in'),
    'floor_lamp':       ('LDSB', 'a standard lamp stands beside a seat'),
    'candles':          ('DLB',  'candles are for the table or the bedside'),
    # ---- plants
    'plant_floor':      ('BLDS', 'a tall plant in a big pot stands in a living space — never a kitchen or a bathroom'),
    'plant_small':      (ALL,    'a small plant on a sill, a shelf or a counter is anywhere'),
    # ---- floor coverings
    'rug':              ('BLDS', 'a rug lies in a living space (a bathroom has a mat, a kitchen a lino floor)'),
    'bath_mat':         ('T',    'a bath mat is by the bath'),
    'mark':             (ALL,    'a stain can be on any floor'),
    # ---- wall: pictures and paper
    'art':              (ALL,    'a landscape or a sketch can hang in any room'),
    'portrait':         ('BLDSK', 'family photographs and portraits hang where the family lives — not the bathroom'),
    'poster':           ('BLSD', 'a poster is in somebody\'s room'),
    'hunting':          ('LDS',  'a stag head and a hunting print are a den / dining / living-room thing'),
    'notice':           ('KBSLD', 'a calendar, a note or a timetable is where it is read: not on a bathroom wall'),
    'mirror':           ('BTLD', 'a mirror hangs over a dressing table, a basin, or in a hall / living room'),
    'wall_clock':       ('BKLDS', 'a clock hangs where people check the time: not over the bath'),
    'banner':           ('DLB',  'a party banner hangs in the room of the party'),
}

# piece id -> kind. A piece with no entry cannot be registered (furnlib.piece asserts it).
PIECE_KIND = {
    # ceiling
    'ceiling_flush': 'ceiling_light', 'ceiling_paper': 'ceiling_light', 'ceiling_pendant': 'ceiling_light', 'light_bulb': 'ceiling_light', 'light_tube': 'ceiling_light',
    'light_dome_orange': 'ceiling_light', 'chandelier': 'chandelier',
    # decor
    'banner_party': 'banner', 'calendar_wall': 'notice', 'clock_cuckoo': 'wall_clock', 'clock_regulator': 'wall_clock', 'clock_sunburst': 'wall_clock',
    'clock_wall': 'wall_clock', 'frame_family': 'portrait', 'height_chart': 'notice', 'map_street': 'notice', 'mirror_bath': 'bath_furnishing', 'mirror_wall': 'mirror',
    'note_bills': 'notice', 'note_cat_food': 'notice', 'note_milk_eggs': 'notice', 'note_rent': 'notice', 'noticeboard': 'notice', 
    'picture_crayon': 'portrait', 'picture_landscape': 'art', 'picture_portrait': 'portrait', 'portraits_row': 'portrait', 'poster_film': 'poster', 'poster_game': 'poster',
    'poster_gig': 'poster', 'poster_map': 'poster', 'poster_rainbow': 'poster', 'print_hunting': 'hunting', 'sampler_home': 'portrait', 'shelf_jars': 'kitchen_ware',
    'sketches_wall': 'art', 'stag_head': 'hunting', 'tea_towel': 'kitchen_ware', 'timetable': 'notice', 'towel_rail': 'bath_furnishing', 'toy_shelf': 'toys', 'tv_wall': 'tv',
    'wall_cupboards': 'kitchen_unit', 'wall_shelf': 'shelf',
    # floor
    'backpack': 'bag', 'ball': 'toys', 'bin_bags': 'rubbish', 'block_tower': 'toys', 'box_cardboard': 'boxes', 'bucket_mop': 'cleaning', 'cat_tins': 'food_store',
    'chair_child': 'chair', 'chair_office': 'chair', 'chair_wood': 'chair', 'champagne_stand': 'drinks_stand', 'clothes_pile': 'laundry_basket', 'clothes_rail': 'clothes_rail',
    'coffee_table': 'coffee_table', 'crate_veg': 'food_store', 'drip_stand': 'care_equipment', 'easel': 'art_supplies', 'gifts_pile': 'party', 'guitar_stand': 'instrument',
    'lamp_floor': 'floor_lamp', 'laundry_basket': 'laundry_basket', 'laundry_basket3d': 'laundry_basket', 'log_basket': 'fireplace', 'med_trolley': 'care_equipment',
    'mop_bucket3d': 'cleaning', 'pedal_bin': 'rubbish', 'pizza_boxes': 'food_store', 'plant_floor': 'plant_floor', 'pouf': 'pouf', 'printer_stand': 'work_gear',
    'rag_doll': 'toys', 'rocking_horse': 'toys', 'shoes_pair': 'footwear', 'slippers': 'footwear', 'stool_dressing': 'dressing_stool', 'stool_piano': 'piano_stool', 'stool_radio': 'audio', 'toy_chest': 'toys', 'trainers': 'footwear',
    'trolley_drinks': 'drinks', 'waste_bin': 'rubbish', 'wheelchair': 'mobility_aid',
    # front
    'armchair': 'armchair', 'basin': 'sanitaryware', 'bath': 'sanitaryware', 'bed_iron': 'bed', 'bed_kid': 'bed', 'bed_pine': 'bed', 'bed_wood': 'bed', 'desk_study': 'desk',
    'loveseat': 'sofa', 'mattress_floor': 'bed', 'shower_walkin': 'sanitaryware', 'sofa': 'sofa', 'table_dining': 'dining_table', 'table_kitchen': 'dining_table',
    'toilet': 'sanitaryware', 'toilet_roll_spare': 'bath_furnishing', 'trolley_kitchen': 'kitchen_unit', 'vanity': 'sanitaryware', 'washer': 'washing_machine', 'washstand': 'sanitaryware',
    # rug
    'bath_mat': 'bath_mat', 'floor_stain': 'mark', 'rug_large': 'rug', 'rug_oblong': 'rug',
    # top
    'alarm_clock': 'alarm_clock', 'ashtray_pack': 'smoking', 'balloons': 'party', 'book_pile': 'reading', 'boombox': 'audio', 'bottles_row': 'drinks', 'bread_bin': 'kitchen_ware',
    'cake_party': 'tableware', 'candelabra': 'candles', 'canisters': 'kitchen_ware', 'chopping_board': 'kitchen_ware', 'computer_crt': 'work_gear', 'fruit_bowl': 'tableware',
    'glass_water': 'drinkware', 'globe': 'work_gear', 'hairbrush': 'toiletries', 'jewel_box': 'jewellery', 'kettle': 'kitchen_ware', 'lamp_banker': 'table_lamp',
    'lamp_lava': 'table_lamp', 'lamp_table': 'table_lamp', 'magazines': 'reading', 'microwave': 'kitchen_ware', 'mugs': 'drinkware', 'papers_pile': 'paperwork',
    'party_hats': 'party', 'perfume_set': 'toiletries', 'photo_small': 'portrait', 'pill_bottles': 'medicine', 'place_settings': 'tableware', 'plant_desk': 'plant_small',
    'radio_gear': 'hobby_gear', 'record_player': 'audio', 'suitcase': 'luggage', 'teapot': 'tableware', 'tin_stack': 'kitchen_ware', 'toaster': 'kitchen_ware', 'tv_crt': 'tv',
    'typewriter': 'work_gear', 'utensil_jar': 'kitchen_ware', 'vase_flowers': 'plant_small',
    # wall
    'bookcase_low': 'bookcase', 'bookcase_tall': 'bookcase', 'boxes_stack': 'boxes', 'canvases_leaning': 'art_supplies', 'chest_drawers': 'chest_of_drawers',
    'china_cabinet': 'display_cabinet', 'clock_grandfather': 'long_case_clock', 'coat_stand': 'coat_stand', 'crate_bedside': 'bedside', 'crate_cubes': 'bookcase',
    'desk_crt': 'desk', 'dollhouse_table': 'toys', 'dresser_welsh': 'dresser', 'dressing_table': 'dressing_table', 'filing_cabinet': 'filing_cabinet', 'fireplace': 'fireplace',
    'fridge_tall': 'kitchen_unit', 'larder_tall': 'kitchen_unit', 'linen_cupboard': 'bath_furnishing', 'newspaper_stacks': 'reading', 'nightstand_wood': 'bedside',
    'paint_shelf': 'art_supplies', 'piano_upright': 'instrument', 'pill_cabinet': 'medicine', 'radiator': 'radiator', 'range_recess': 'kitchen_unit', 'shelving_open': 'shelving',
    'side_table': 'side_table', 'sideboard': 'sideboard', 'sink_butler': 'kitchen_unit', 'trunk': 'trunk', 'unit_base': 'kitchen_unit', 'unit_cooker': 'kitchen_unit',
    'unit_sink': 'kitchen_unit', 'wardrobe_mirror': 'wardrobe', 'wardrobe_small': 'wardrobe', 'wardrobe_wood': 'wardrobe',
}


# a room never has MORE than this many things of a group (owner round 48k, from reviewing planned rooms: a formal dining room could hang a grandfather clock, a cuckoo clock AND a wall clock;
# a houseshare two matching wall clocks side by side — nobody designs a room that way). (name, kinds in the group, most one room holds, why)
GROUP_LIMITS = (
    ('clock', ('wall_clock', 'long_case_clock'), 1, 'one clock a room: a home does not hang three'),
    ('television', ('tv',), 1, 'one television a room'),
    ('ceiling light', ('ceiling_light', 'chandelier'), 1, 'one light in the middle of the ceiling'),
    ('mirror', ('mirror',), 1, 'one mirror on the wall (a dressing table brings its own)'),
    ('trophy', ('hunting',), 1, 'one stag head or hunting print'),
    ('hearth', ('fireplace',), 1, 'one fireplace'),
    ('instrument', ('instrument',), 2, 'a piano and a guitar at most'),
    ('radiator', ('radiator',), 1, 'one radiator under the window wall'),
    ('banner', ('banner',), 1, 'one party banner'),
)


def group_limits_export():
    return [{'name': n, 'kinds': list(k), 'max': m, 'why': w} for (n, k, m, w) in GROUP_LIMITS]


def kind_rooms(kind):
    return R(KINDS[kind][0])


def rooms_export():
    return {k: {'rooms': list(R(v[0])), 'why': v[1]} for k, v in KINDS.items()}
