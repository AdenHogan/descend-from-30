class_name SurvivorPlan
extends RefCounted

# WHO IS ALIVE OUT THERE, AND WHERE (docs/NPC_AI.md). The people the building still has, other than the ones
# holed up behind LOCKED doors (those are WorldState "RESIDENTS"). Placement follows CONTEXT — a survivor is
# always somewhere that makes sense for what they are:
#
#   DEFENDER  armed, in the corridor, holding a way down or standing guard at a door. The fighters.
#   WAITER    in the corridor by the lift, waiting for a car that is never coming (never on a merchant floor —
#             the merchant has the car). Bangs on the doors in threes, which the dead hear.
#   HIDER     inside an apartment you can walk into (its door open or only weakly locked), as far from the front
#             door as the flat allows, small and quiet, with a little something to give you if you save them.
#
# Everything is seeded per (place, run) like the rest of the world — `hash(master_seed + "survivor" + key)` — and
# SETTLED into `WorldState.survivors` (saved), so a record is stable across re-entry, a stair pan's backdrop and
# its live commit agree, and a dead one stays dead. A new run is a new key, so a new roll: they dwindle.

const CHANCE := {
	"defender": {1: 0.30, 2: 0.24, 3: 0.16},
	"waiter":   {1: 0.18, 2: 0.14, 3: 0.10},
	"hider":    {1: 0.12, 2: 0.09, 3: 0.06},     # of the apartments you can walk into
}
const HP := {"defender": 8, "waiter": 4, "hider": 3, "host": 4, "patient": 4}
const AMMO_MIN := 4
const AMMO_MAX := 7
const LOOKS := [1, 2, 3, 4, 5, 6]               # assets/homeless-character-pixel-art-pack/<n>
const STICK_LOOK := 2                           # look 2 carries a bat in its own art (WorldState.RESIDENT_STICK_LOOK)
# What a defender carries: item id -> weight, by run (the dead are armed better as the building empties).
const DEFENDER_WEAPONS := {
	1: {"001": 4, "002": 4, "012": 3, "014": 3, "013": 1, "003": 1, "004": 1},
	2: {"001": 3, "002": 3, "012": 2, "014": 3, "013": 2, "017": 1, "003": 2, "004": 2},
	3: {"002": 2, "014": 3, "013": 2, "017": 2, "003": 3, "004": 4},
}
# What a hider will give the person who saves them: item id -> [weight, amount (0 = one item)].
const GIFTS := {"006": [5, 0], "010": [4, 0], "005": [4, 0], "016": [3, 4], "007": [1, 0]}

# The corridor (building_floors.tscn): the lift, and where a defender holds.
const LIFT_X := 1029.5
const WAITER_X := 984.0                          # 45 px left of the lift doors
const STAIR_POST_X := {"left": 335.0, "right": 1005.0}    # ~150 px in from the stair trigger (188 / 1162)
const DOOR_POST_OFFSET := 56.0                   # beside an apartment door
const FIRST_FLOOR := 1
const LAST_FLOOR := 28                           # 29 keeps its scripted neighbour (character stories) and the run-opening grace


static func _run() -> int:
	return clampi(WorldState.current_run, 1, 3)


static func corridor_key(floor_num: int, role: String) -> String:
	return "f%d:%s:r%d" % [floor_num, role, WorldState.current_run]


static func hider_key(apartment_id: String) -> String:
	return "%s:hider:r%d" % [apartment_id, WorldState.current_run]


static func _rng(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "survivor" + key)
	rng.randi()        # near-identical keys seed near-identical first draws (see WorldState.apartment_riser): skip one
	return rng


static func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var r := rng.randi_range(1, maxi(total, 1))
	for k in weights:
		r -= int(weights[k])
		if r <= 0:
			return str(k)
	return str(weights.keys()[0])


## A corridor floor that can hold a survivor at all: a procedural floor, not on fire past a lick, and not the
## first run's tutorial floor.
static func floor_ok(floor_num: int) -> bool:
	if floor_num < FIRST_FLOOR or floor_num > LAST_FLOOR:
		return false
	return WorldState.fire_intensity(floor_num) < WorldState.FIRE_BLAZE


## Whether this role may stand on this floor (context).
static func role_fits(role: String, floor_num: int) -> bool:
	if not floor_ok(floor_num):
		return false
	if role == "waiter":
		return not (floor_num in WorldState.MERCHANT_FLOORS)        # the merchant has the car
	return true


## Is the building populated at all? (`WorldState.survivor_rule` — only the real New Game turns it on; every test starts
## without, so a floor holds only what the test put there.)
static func active() -> bool:
	return WorldState.survivor_rule


## The corridor survivors of this floor THIS run: [] or 1-2 records (live references into WorldState.survivors).
static func corridor_records(floor_num: int) -> Array:
	var out: Array = []
	if not active():
		return out
	var quest_npcs: Array = Quests.corridor_records(floor_num) if floor_ok(floor_num) else []
	out.append_array(quest_npcs)
	for role in ["defender", "waiter"]:
		if not role_fits(role, floor_num):
			continue
		if role == "defender" and not quest_npcs.is_empty():
			continue                                  # the floor's armed post is a quest giver's
		var rec := _settled(corridor_key(floor_num, role), role, floor_num, "")
		if not rec.is_empty():
			out.append(rec)
	return out


## The hider of this apartment this run ({} = nobody). Only a flat you can walk into: open or weakly locked.
static func hider_for(apartment_id: String) -> Dictionary:
	if not active():
		return {}
	var f: int = WorldState._apartment_floor(apartment_id)
	if not floor_ok(f) or not hider_flat_ok(apartment_id):
		return {}
	return _settled(hider_key(apartment_id), "hider", f, apartment_id)


static func hider_flat_ok(apartment_id: String) -> bool:
	var f: int = WorldState._apartment_floor(apartment_id)
	if f < FIRST_FLOOR or f > LAST_FLOOR:
		return false
	var ds: int = WorldState.get_door_state(apartment_id)
	if ds != WorldState.DoorState.OPEN and ds != WorldState.DoorState.SHUT_FORCEABLE:
		return false
	if not WorldState.resident_for(apartment_id).is_empty() or WorldState.revenants.has(apartment_id):
		return false
	if not WorldState.apartment_corpse(apartment_id).is_empty():
		return false                       # its own dead story
	if Quests.is_quest_flat(apartment_id):
		return false                       # a quest's flat has its own people
	var col := int(apartment_id.substr(apartment_id.length() - 2))
	return WorldState.apartment_fire_stage(f, col) < 0


static func _settled(key: String, role: String, floor_num: int, apt: String) -> Dictionary:
	var all: Dictionary = WorldState.survivors
	if all.has(key):
		var r: Dictionary = all[key]
		if not r.get("none", false):
			return r
		if WorldState.dev_survivors == 0:
			return {}
	var rec := _roll(key, role, floor_num, apt)
	all[key] = rec if not rec.is_empty() else {"none": true}
	return rec


static func _roll(key: String, role: String, floor_num: int, apt: String) -> Dictionary:
	var rng := _rng(key)
	var run := _run()
	if rng.randf() >= float(CHANCE[role][run]) and WorldState.dev_survivors == 0:
		return {}
	var weapon := ""
	var ammo := 0
	var gift := ""
	var gift_n := 0
	match role:
		"defender":
			weapon = _weighted(DEFENDER_WEAPONS[run], rng)
			if weapon == "004":
				ammo = rng.randi_range(AMMO_MIN, AMMO_MAX)
		"hider":
			if rng.randf() < 0.30:
				weapon = "001"                         # a kitchen knife — enough to fight when cornered, not to hunt
			var g := _weighted_gift(rng)
			gift = g
			gift_n = int(GIFTS[g][1])
	var look: int = LOOKS[rng.randi() % LOOKS.size()]
	if weapon in WorldState.RESIDENT_STICK_WEAPONS:
		look = STICK_LOOK
	elif look == STICK_LOOK:
		look = 1 + (look % LOOKS.size())               # only a bat-holder wears the stick look
	var post := 0.0
	var post_kind := ""
	match role:
		"defender":
			post_kind = "stairs" if rng.randf() < 0.55 else "door"
			if post_kind == "stairs":
				post = float(STAIR_POST_X[WorldState.stair_down_side(floor_num)])
			else:
				var door := 1 + rng.randi() % 5
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				post = float(WorldState.APARTMENT_X[door]) + side * DOOR_POST_OFFSET
		"waiter":
			post = WAITER_X
		"hider":
			post = -1.0                                # set when the room is built (it depends on which wall the front door is)
	return {
		"key": key, "role": role, "floor": floor_num, "apt": apt, "look": look,
		"weapon": weapon, "ammo": ammo, "gift": gift, "gift_n": gift_n,
		"hp": int(HP[role]), "max_hp": int(HP[role]), "dead": false,
		"x": -1.0, "post": post, "post_kind": post_kind, "spot": rng.randf(),
		"met": 0, "aided": false, "calm": false, "gave": false, "quest": "",
	}


static func _weighted_gift(rng: RandomNumberGenerator) -> String:
	var w := {}
	for id in GIFTS:
		w[id] = int(GIFTS[id][0])
	return _weighted(w, rng)


## The dead/alive census for tests and the journal: records for a floor this run that are alive.
static func living_on_floor(floor_num: int) -> Array:
	var out: Array = []
	for r in corridor_records(floor_num):
		if not bool(r.get("dead", false)):
			out.append(r)
	return out
