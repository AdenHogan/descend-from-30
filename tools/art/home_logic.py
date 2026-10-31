"""HOME LOGIC — how a home keeps its things (owner round 48k: "do we have some sort of internal logic engine… a logic list of how homes operate… that plant on the floor, if it were my
home, it would logically go on a table… if it were a larger plant then sure it would be in a big pot on the floor and it would grow tall").

WHY THIS FILE EXISTS. The planner already knew WHICH ROOM a piece belongs in (`furnlib.TAG_ROOMS`: no bed in a kitchen) and where it may stand geometrically (wall line, window, lane,
stand zone, support). It knew nothing about HOW A HOME KEEPS A THING — a floor was just "a plane", so a 36 px desk plant could be dealt as floor clutter into a bathroom. This file is that
missing half, as DATA with checks that can fail:

  0. WHAT IT IS, AND WHERE A HOME COULD HAVE IT (`home_kinds.py`). Every piece is ONE kind of thing and every kind lists the only rooms a home could plausibly keep it in — a piano in a
     living room, bedroom, study or dining room and never a kitchen or a bathroom; a bed in a bedroom only. A piece with no kind cannot be registered; a piece whose rooms go outside its
     kind's rooms is refused; the planner will not deal it and `validate_state` re-checks every placement. This is the rule for EVERYTHING, procedurally generated or not.
  1. KEEPING (floor or surface).  A thing on the FLOOR must say why a home keeps it there — a `keep` kind from FLOOR_KEEPS (shoes by the bed, a bin, a chair, a bag, a toy, a mop bucket…)
     — and a kind may carry a MINIMUM HEIGHT (only a tall plant in a big pot stands on a floor) and the ROOMS it is kept in (a floor lamp is not a bathroom thing). A piece with no reason
     is refused at registration; the planner will not deal it (`FurniturePlanner.eligible`) and `validate_state` re-checks every plan. A thing on a SURFACE is small (SURFACE_MAX_H;
     a plant on a table is a desk plant, PLANT_TOP_MAX_H) — a big thing cannot be "on a table".
  2. SMALL THINGS NEVER STAND ON THE FLOOR.  SURFACE_TAGS (`small`) are never floor-kept whatever else they say.
  3. BELONGING.  A floor piece that declares `near` (shoes → the bed, a bin → the worktop) is only ever put BESIDE such a body (BELONG_GAP px): the planner no longer scatters it at
     random when the room has nothing for it to belong to, and `validate_state` re-checks it.

THE SINGLE SOURCE: this table. `furn_rooms.rules_export()` writes it to `data/furniture.json` "rules" → "home"; `furnlib.piece` refuses a piece that breaks it; the game's planner and
`tests/furniture_test.gd` read the same JSON; `docs/HOME_LOGIC.md` (the readable list — GENERATED, never hand-edited) comes from `python3 tools/art/home_logic.py --write` and the gate runs
`--check` (the doc is current, every floor piece states its reason, the rules can FAIL on a sample of bad pieces, the growth system's floor pots obey the same rule).
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
import home_kinds as HK

FLOOR_MIN_H = 44        # px — a thing this tall stands on a floor on size alone (a lamp, a stand, a rail, an easel). The player is ~56 px; 44 is a hip-high piece and up.
SURFACE_MAX_H = 40      # px — nothing taller than this "stands on a table" (a balloon bunch is the tallest thing a table carries)
PLANT_FLOOR_MIN_H = 48  # px — a plant on the floor is a big plant in a big pot, taller than a person's waist
PLANT_TOP_MAX_H = 26    # px — a plant on a surface is a desk plant: a pot you can lift
BELONG_GAP = 32         # px — a floor thing that belongs with something stands within this of it (the planner's own candidate gaps are 2..28)

# why a home keeps this on the floor; `min_h` = the smallest it may be drawn; `rooms` = the only rooms it is kept in (None = any room)
FLOOR_KEEPS = {
    'tall':     dict(why='anything as tall as a hip or more stands on the floor by itself: a rail, an easel, a drip stand, a guitar stand', min_h=FLOOR_MIN_H, rooms=None),
    'seat':     dict(why='a chair, stool, pouf or wheelchair stands where it is sat on', min_h=0, rooms=None),
    'table':    dict(why='a low table stands on the floor in front of the seating', min_h=0, rooms=None),
    'stand':    dict(why='a stand, stool or trolley exists to hold something off the floor', min_h=0, rooms=None),
    'storage':  dict(why='a chest, crate, box or basket is where things are kept, and stands on the floor', min_h=0, rooms=None),
    'bag':      dict(why='a bag is dropped by the bed, a chair or the door', min_h=0, rooms=None),
    'footwear': dict(why='shoes and slippers are kicked off by the bed or the door', min_h=0, rooms=('bedroom', 'living_room', 'bathroom', 'dining_room')),
    'clothes':  dict(why='laundry is in a basket or a pile by the bed, the wardrobe or the bath', min_h=0, rooms=('bedroom', 'bathroom')),
    'toy':      dict(why='children leave toys on the floor where they played', min_h=0, rooms=('bedroom', 'living_room')),
    'rubbish':  dict(why='a bin, a bag of rubbish or an empty box is put on the floor until it is taken out', min_h=0, rooms=None),
    'airer':    dict(why='washing is dried on an airer in the warm: the kitchen, a bedroom or the living room', min_h=0, rooms=('kitchen', 'bedroom', 'living_room')),
    'cleaning': dict(why='a mop and bucket stand where the mess is: the kitchen and the bathroom', min_h=0, rooms=('kitchen', 'bathroom')),
    'pet':      dict(why="a pet is fed on the floor, in a corner of the kitchen or the room it lives in", min_h=0, rooms=('kitchen', 'living_room', 'dining_room')),
    'party':    dict(why='presents are left on the floor beside the table', min_h=0, rooms=('dining_room', 'living_room')),
    'light':    dict(why='a standard lamp stands beside a seat; a bathroom or kitchen has none', min_h=FLOOR_MIN_H, rooms=('living_room', 'dining_room', 'study', 'bedroom')),
    'plant':    dict(why='only a TALL plant in a BIG pot stands on a floor — a small one sits on a table, a shelf or a sill', min_h=PLANT_FLOOR_MIN_H, rooms=('bedroom', 'living_room', 'dining_room', 'study')),
}

# tags that mean "small, kept in the hand / on a surface" — never floor-kept, whatever `keep` says
SURFACE_TAGS = ('small',)
# a tag may cap how big its thing is on a SURFACE as well
TOP_MAX_BY_TAG = {'plant': PLANT_TOP_MAX_H}


def rules():
    """The table as it is written into data/furniture.json "rules" → "home" (the game and its tests read exactly this)."""
    return {
        'floor_min_h': FLOOR_MIN_H,
        'surface_max_h': SURFACE_MAX_H,
        'belong_gap': BELONG_GAP,
        'surface_tags': list(SURFACE_TAGS),
        'top_max_by_tag': dict(TOP_MAX_BY_TAG),
        'keeps': {k: {'why': v['why'], 'min_h': int(v['min_h']), 'rooms': (list(v['rooms']) if v['rooms'] else None)} for k, v in FLOOR_KEEPS.items()},
        'kinds': HK.rooms_export(),
        'group_limits': HK.group_limits_export(),
    }


def issue(plane, h, tags, keep, rooms, kind=None):
    """Why a piece of this plane / height / tags may NOT be kept like this — '' when it may. THE rule (furnlib.piece calls it at registration; the planner's GDScript twin is
    `FurniturePlanner.home_issue`, reading the same table from the JSON)."""
    if not kind:
        return 'has no kind — say what it IS in tools/art/home_kinds.py (PIECE_KIND) so a home can say where it may be'
    if kind not in HK.KINDS:
        return 'kind "%s" is not in home_kinds.KINDS' % kind
    allowed = HK.kind_rooms(kind)
    for r in rooms:
        if r not in allowed:
            return 'is a "%s" and a home does not keep one in a %s (%s: %s)' % (kind, r, HK.KINDS[kind][1], ', '.join(allowed))
    if plane == 'floor':
        if not keep:
            return 'stands on a floor but gives no `keep` — say why a home keeps it there (one of %s)' % ', '.join(sorted(FLOOR_KEEPS))
        if keep not in FLOOR_KEEPS:
            return 'keep "%s" is not a known way of keeping a thing on a floor (%s)' % (keep, ', '.join(sorted(FLOOR_KEEPS)))
        for t in tags:
            if t in SURFACE_TAGS:
                return 'is tagged "%s": a small thing is kept on a surface, never on the floor' % t
        k = FLOOR_KEEPS[keep]
        if h < int(k['min_h']):
            return '"%s" things are only kept on a floor from %d px tall (this is %d): %s' % (keep, k['min_h'], h, k['why'])
        if k['rooms'] is not None:
            for r in rooms:
                if r not in k['rooms']:
                    return '"%s" things are not kept on the floor of a %s (kept in: %s)' % (keep, r, ', '.join(k['rooms']))
        if 'plant' in tags and keep != 'plant':
            return 'is a plant on the floor but is not kept as one (keep="plant": a tall plant in a big pot)'
        return ''
    if keep:
        return 'has a `keep` ("%s") but does not stand on the floor — `keep` is for floor pieces only' % keep
    if plane == 'top':
        if h > SURFACE_MAX_H:
            return 'stands on a surface but is %d px tall (the most a table carries is %d)' % (h, SURFACE_MAX_H)
        for t in tags:
            if t in TOP_MAX_BY_TAG and h > TOP_MAX_BY_TAG[t]:
                return 'a "%s" on a surface is a small one: at most %d px (this is %d)' % (t, TOP_MAX_BY_TAG[t], h)
    return ''


# --------------------------------------------------------------------------------------------------------------------------------------- the readable list
def _write_doc(items, tag_rooms):
    L = []
    A = L.append
    A('# HOME LOGIC — how a home keeps its things')
    A('')
    A('> GENERATED by `python3 tools/art/home_logic.py --write` from `tools/art/home_logic.py` + `tools/art/furnlib.py` — do not hand-edit (the gate fails when it is stale). To change a rule, change the')
    A('> table in `home_logic.py` and regenerate. Owner round 48k: "a logic list of how homes operate… internal intelligence on where things go".')
    A('')
    A('Every rule below is DATA with a check that can fail. **Registration** (`furnlib.piece`) refuses a piece that breaks one; the planner will not deal it (`FurniturePlanner.eligible`);')
    A('`FurniturePlanner.validate_state` re-checks every plan; `tests/furniture_test.gd` runs that over thousands of seeds and proves each rule fails on a plan that breaks it.')
    A('')
    A('## 1. What every thing IS, and the rooms a home could keep it in')
    A('')
    A('Every piece is ONE kind of thing (`tools/art/home_kinds.py`). A kind lists the ONLY rooms a home could plausibly keep it in — an upper bound, not a recipe. A piece is registered in some of')
    A('those rooms (its `rooms` weights); registration refuses a piece outside the bound, refuses a piece that has no kind, and the planner and `validate_state` re-check it at runtime.')
    A('')
    A('| kind | a home could keep it in | why | pieces (where the game uses each) |')
    A('|---|---|---|---|')
    by = {}
    for n in sorted(items):
        by.setdefault(items[n].get('kind') or '?', []).append(n)
    ab = {'bedroom': 'B', 'bathroom': 'T', 'kitchen': 'K', 'study': 'S', 'living_room': 'L', 'dining_room': 'D'}
    for k in sorted(HK.KINDS):
        mem = ', '.join('`%s` (%s)' % (n, ''.join(ab[r] for r in sorted(items[n]['rooms'], key=lambda r: 'BTKSLD'.index(ab[r])))) for n in by.get(k, []))
        A('| `%s` | %s | %s | %s |' % (k, ', '.join(HK.kind_rooms(k)) if len(HK.kind_rooms(k)) < 6 else 'any room', HK.KINDS[k][1], mem or '—'))
    A('')
    A('Room letters: B bedroom, T bathroom, K kitchen, S study, L living room, D dining room.')
    A('')
    A('Also (older, still enforced): a piece carrying one of these tags can only be registered in the rooms listed (`furnlib.TAG_ROOMS`).')
    A('')
    A('| tag | rooms |')
    A('|---|---|')
    for t in sorted(tag_rooms):
        A('| `%s` | %s |' % (t, ', '.join(tag_rooms[t])))
    A('')
    A('## 2. Keeping: the floor is for things a home keeps on a floor')
    A('')
    A('A piece on the FLOOR plane must carry a `keep` kind — the reason a home keeps it there. A kind may set a smallest height and the only rooms it is kept in.')
    A('A piece tagged `%s` is never kept on the floor. A thing on a SURFACE is at most **%d px** tall; a plant on a surface at most **%d px**.' % ('`, `'.join(SURFACE_TAGS), SURFACE_MAX_H, PLANT_TOP_MAX_H))
    A('')
    A('| keep | why a home keeps it on the floor | from (px) | rooms |')
    A('|---|---|---|---|')
    for k in sorted(FLOOR_KEEPS):
        v = FLOOR_KEEPS[k]
        A('| `%s` | %s | %s | %s |' % (k, v['why'], v['min_h'] or '—', ', '.join(v['rooms']) if v['rooms'] else 'any'))
    A('')
    A('### Every floor piece and its reason')
    A('')
    A('| piece | keep | height | belongs beside (`near`) | rooms |')
    A('|---|---|---|---|---|')
    for n in sorted(items):
        p = items[n]
        if p['plane'] == 'floor':
            A('| `%s` | %s | %d | %s | %s |' % (n, p.get('keep') or '—', p['h'], ', '.join(p['near']) or '—', ', '.join(sorted(p['rooms']))))
    A('')
    A('## 3a. One of a kind: a room is not doubled up')
    A('')
    A('A room never holds more than this many things of a group, and the same drawing is never hung twice on one wall (a picture\'s `limit` is 1). Found by looking at planned rooms the way a player does:')
    A('a formal dining room could hang a grandfather clock, a cuckoo clock and a wall clock; a houseshare two matching wall clocks side by side.')
    A('')
    A('| group | kinds | most in one room | why |')
    A('|---|---|---|---|')
    for (n, k, m, w) in HK.GROUP_LIMITS:
        A('| %s | %s | %d | %s |' % (n, ', '.join('`%s`' % x for x in k), m, w))
    A('')
    A('## 3. Belonging: a thing that goes with something is put beside it')
    A('')
    A('A floor piece that declares `near` (shoes → `sleeping`, a bin → `unit`) is only ever placed within **%d px** of a body carrying one of those tags. If the room has none, the piece is' % BELONG_GAP)
    A('not placed at all — it is never scattered at random. `validate_state` re-checks it.')
    A('')
    A('## 4. Where it may stand (the planner\'s structural rules, unchanged)')
    A('')
    A('The wall line is exclusive; nothing tall stands in front of the window; everything on the floor lies behind the walking lane (feet ≤ 122) and never in a step-up spot\'s stand zone; a thing')
    A('on top stands ON a surface that has a slot for it (`tools/art/support_audit.py`); hung things hang clear of every piece; a desk wants its chair; a piece\'s `limit`; at least `min_front`')
    A('nodes reachable from the walking lane. See the header of `scripts/furniture_planner.gd`.')
    A('')
    A('## 5. The same rule in the baked story rooms')
    A('')
    A('`scripts/room_growth.gd` places houseplants in the baked modules. A flat\'s floor takes only the TALL pots (`FLOOR_POTS` / `FLOOR_DEAD_POTS`, each at least %d px — the plant rule above); small pots stand on a' % PLANT_FLOOR_MIN_H)
    A('balcony, where pots really do stand on the floor. `tests/growth_test.gd` checks every floor pot against this table.')
    A('')
    return '\n'.join(L)


def _load_items():
    with open(os.path.join(ROOT, 'data', 'furniture.json')) as f:
        return json.load(f)


def _selftest():
    """The rules must be able to FAIL: every one of these is a piece that should be refused."""
    bad = [
        ('floor', 36, ('plant', 'clutter'), 'plant', ('bathroom',), 'plant_floor', 'a 36 px plant on the floor, in a bathroom (the owner\'s screenshot)'),
        ('floor', 36, ('plant',), 'plant', ('living_room',), 'plant_floor', 'a 36 px plant on a living-room floor'),
        ('floor', 60, ('plant',), 'plant', ('bathroom',), 'plant_floor', 'a big plant on a bathroom floor'),
        ('floor', 20, ('clutter',), None, ('bedroom',), 'boxes', 'a floor piece with no reason'),
        ('floor', 20, ('clutter',), 'nonsense', ('bedroom',), 'boxes', 'an unknown way of keeping'),
        ('floor', 30, ('small',), 'storage', ('bedroom',), 'boxes', 'a small thing on the floor'),
        ('floor', 30, ('plant',), 'storage', ('bedroom',), 'boxes', 'a plant dressed up as storage'),
        ('floor', 30, ('light',), 'light', ('living_room',), 'floor_lamp', 'a floor lamp that is too short'),
        ('floor', 56, ('light',), 'light', ('bathroom',), 'floor_lamp', 'a standard lamp in a bathroom'),
        ('floor', 40, ('wet',), 'cleaning', ('bedroom',), 'cleaning', 'a mop bucket in a bedroom'),
        ('top', 60, ('small',), None, ('bedroom',), 'reading', 'a 60 px thing on a table'),
        ('top', 36, ('small', 'plant'), None, ('bedroom',), 'plant_small', 'a 36 px plant on a table'),
        ('wall', 40, ('storage',), 'storage', ('bedroom',), 'bookcase', 'a keep on a wall piece'),
        ('wall', 60, ('music',), None, ('kitchen',), 'instrument', 'a piano in a kitchen'),
        ('wall', 60, ('music',), None, ('bathroom',), 'instrument', 'a piano in a bathroom'),
        ('wall', 60, ('music',), None, ('living_room', 'kitchen'), 'instrument', 'a piano allowed in the living room AND the kitchen'),
        ('front', 47, ('sleeping',), None, ('kitchen',), 'bed', 'a bed in a kitchen'),
        ('front', 36, ('toilet',), None, ('bedroom',), 'sanitaryware', 'a toilet in a bedroom'),
        ('wall', 40, ('storage',), None, ('bedroom',), None, 'a piece with no kind at all'),
        ('wall', 40, ('storage',), None, ('bedroom',), 'no_such_kind', 'a kind that does not exist'),
        ('top', 14, ('small', 'cooking'), None, ('bathroom',), 'kitchen_ware', 'a kettle in a bathroom'),
    ]
    good = [
        ('floor', 60, ('plant',), 'plant', ('living_room',), 'plant_floor', 'a tall plant in the living room'),
        ('floor', 7, ('footwear',), 'footwear', ('bedroom',), 'footwear', 'shoes by the bed'),
        ('top', 22, ('small', 'plant'), None, ('bedroom', 'bathroom'), 'plant_small', 'a desk plant on a table, even in a bathroom'),
        ('top', 36, ('party',), None, ('dining_room',), 'party', 'balloons on a table'),
        ('wall', 60, ('music',), None, ('living_room', 'bedroom', 'study', 'dining_room'), 'instrument', 'a piano in the living room, bedroom, study and dining room'),
        ('front', 47, ('sleeping',), None, ('bedroom',), 'bed', 'a bed in a bedroom'),
    ]
    fails = 0
    for plane, h, tags, keep, rooms, kind, label in bad:
        if issue(plane, h, tags, keep, rooms, kind) == '':
            print('  FAIL  the rule does not refuse: %s' % label)
            fails += 1
    for plane, h, tags, keep, rooms, kind, label in good:
        why = issue(plane, h, tags, keep, rooms, kind)
        if why:
            print('  FAIL  the rule refuses a good piece (%s): %s' % (label, why))
            fails += 1
    return fails


def _growth_pots():
    """(floor pot names, their heights) from the growth system, so the same rule can be applied to the baked rooms' houseplants."""
    src = open(os.path.join(ROOT, 'scripts', 'room_growth.gd')).read()
    names = []
    for const in ('FLOOR_POTS', 'FLOOR_DEAD_POTS'):
        m = re.search(r'const %s := \[([^\]]*)\]' % const, src)
        if not m:
            return None
        names += re.findall(r'"([^"]+)"', m.group(1))
    from PIL import Image
    out = []
    for n in names:
        p = os.path.join(ROOT, 'assets', 'growth', n + '.png')
        out.append((n, Image.open(p).size[1] if os.path.exists(p) else -1))
    return out


def check():
    sys.path.insert(0, HERE)
    import furnlib as FL
    data = _load_items()
    items = data['items']
    fails = _selftest()
    for (gn, gk, gm, gw) in HK.GROUP_LIMITS:
        for kk in gk:
            if kk not in HK.KINDS:
                print('  FAIL  group limit "%s" names the unknown kind %s' % (gn, kk))
                fails += 1
    home = data.get('rules', {}).get('home')
    if home != rules():
        print('  FAIL  data/furniture.json "rules.home" is stale — run python3 tools/art/furn_build.py')
        fails += 1
    for n, p in sorted(items.items()):
        why = issue(p['plane'], p['h'], p['tags'], p.get('keep'), list(p['rooms']), p.get('kind'))
        if why:
            print('  FAIL  %s %s' % (n, why))
            fails += 1
    doc = _write_doc(items, {k: list(v) for k, v in FL.TAG_ROOMS.items()})
    path = os.path.join(ROOT, 'docs', 'HOME_LOGIC.md')
    cur = open(path).read() if os.path.exists(path) else ''
    if cur != doc:
        print('  FAIL  docs/HOME_LOGIC.md is stale — run python3 tools/art/home_logic.py --write')
        fails += 1
    pots = _growth_pots()
    if pots is None:
        print('  FAIL  scripts/room_growth.gd has no FLOOR_POTS list (a flat\'s floor takes only the tall pots)')
        fails += 1
    else:
        for n, h in pots:
            if h < PLANT_FLOOR_MIN_H:
                print('  FAIL  floor pot %s is %d px tall: a plant on a flat\'s floor is at least %d px' % (n, h, PLANT_FLOOR_MIN_H))
                fails += 1
    print('home logic: %d floor pieces checked, %d failures' % (sum(1 for p in items.values() if p['plane'] == 'floor'), fails))
    return fails


def main():
    if '--write' in sys.argv:
        sys.path.insert(0, HERE)
        import furnlib as FL
        data = _load_items()
        doc = _write_doc(data['items'], {k: list(v) for k, v in FL.TAG_ROOMS.items()})
        with open(os.path.join(ROOT, 'docs', 'HOME_LOGIC.md'), 'w') as f:
            f.write(doc)
        print('wrote docs/HOME_LOGIC.md')
        return 0
    if '--selftest' in sys.argv:
        return 1 if _selftest() else 0
    return 1 if check() else 0


if __name__ == '__main__':
    sys.exit(main())
