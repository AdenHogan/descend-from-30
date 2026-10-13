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
#
# RESCUES (owner round 41) are the exception to "a new run, a new roll", and the only survivors who can die. Somewhere
# (a corridor post, a walk-in flat) a person is SHOUTING FOR HELP while three of the dead walk slowly at them. They fend
# them off for show; if the player lets it go on too long they are overrun, live. Whether the player stepped in is what
# settles their fate — never their own fighting, never how long the player took to get there in a run they weren't:
#   • one identity per PLACE (key without the run), rolled once, appearing in a seeded run (`appears`, 1-3);
#   • in that run the event is OPEN; saved by the player → "saved" for good (alive, grateful, in every later run);
#     overrun live → "lost"; an event whose run ended unanswered is lost too (`rescue_status`, worked out when asked — no
#     time-skip step to forget) — in a later run there is a body where they stood.

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
# What someone you SAVED from the dead gives (owner round 42: "an item as a thank you or scrap or money"): the hider's table plus
# scrap (a Scrap Bag, 037, goes straight to the counter) and money (Bank Notes, 033, straight to the wallet). Amounts are a good
# find, not a windfall: a natural bag is 6-14 scrap, the first workbench level is 50.
const RESCUE_GIFTS := {"006": [4, 0], "010": [3, 0], "005": [3, 0], "016": [3, 4], "007": [1, 0], "037": [4, 28], "033": [4, 40]}

# The corridor (building_floors.tscn): the lift, and where a defender holds.
const LIFT_X := 1029.5
const WAITER_X := 984.0                          # 45 px left of the lift doors
const STAIR_POST_X := {"left": 335.0, "right": 1005.0}    # ~150 px in from the stair trigger (188 / 1162)
const DOOR_POST_OFFSET := 56.0                   # beside an apartment door
const FIRST_FLOOR := 1
const LAST_FLOOR := 28                           # 29 keeps its scripted neighbour (character stories) and the run-opening grace
# --- rescues ---
const RESCUE_CHANCE := {"corridor": 0.12, "flat": 0.06}     # of the floors / of the walk-in flats, once per playthrough
const RESCUE_LAST_FLOOR := 26                    # none on the eased opening floors 29-27 (WorldState.OPENING_COUNT_CAP) — nor 28
const RESCUE_APPEARS := {1: 45, 2: 30, 3: 25}    # weight of the run the event happens in
const RESCUE_DEAD := 3                           # the dead walking at them
const RESCUE_STEPS := [250.0, 320.0, 390.0]      # how far from the survivor each starts
const RESCUE_HOLD := 26.0                        # seconds of being swarmed (a dead one on them) before they are overrun


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
	var rescue: Dictionary = {} if not quest_npcs.is_empty() else rescue_for_floor(floor_num)
	if not rescue.is_empty():
		out.append(rescue)
	var haven: Dictionary = {} if (not quest_npcs.is_empty() or not rescue.is_empty()) else haven_for_floor(floor_num)
	if not haven.is_empty():
		out.append(haven)
	for role in ["defender", "waiter"]:
		if not role_fits(role, floor_num):
			continue
		if role == "defender" and (not quest_npcs.is_empty() or not rescue.is_empty() or not haven.is_empty()):
			continue                                  # the floor's armed post is a quest giver's — the one who is shouting — or the one you stood by
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
	var rescue := rescue_for_flat(apartment_id)
	if not rescue.is_empty():
		return rescue                              # the flat's one survivor is the one shouting for help (or what became of them)
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


static func _roll(key: String, role: String, floor_num: int, apt: String, forced_run: int = 0) -> Dictionary:
	var rng := _rng(key)
	var run: int = forced_run if forced_run > 0 else _run()
	if forced_run == 0 and rng.randf() >= float(CHANCE[role][run]) and WorldState.dev_survivors == 0:
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


# =============================== HAVENS (the ones you stood by) =========================
#
# Owner round 42: "if you help them they should persist". A fighting survivor the player backs up (`Survivor._helped`) is
# recorded in `WorldState.havens` with a snapshot of who they are; from the next run on the SAME person holds the SAME post (their
# record lives under a run-less key, `f26:haven`) and the floor has no dead (WorldState.haven_floor). An unaided survivor is
# re-rolled per run as ever — the player's help is the only thing that makes anyone permanent. (A rescued survivor is already
# permanent — the rescue record below — and registers its haven when it is saved.)

static func haven_key(floor_num: int) -> String:
	return "f%d:haven" % floor_num


## May the floor's armed post become a haven? Not a quest giver's floor, not one where a rescue is still to happen / happening
## (that person owns the post — and the three dead walking at them would sit badly in a "safe" floor).
static func can_haven_floor(floor_num: int) -> bool:
	if floor_num < FIRST_FLOOR or floor_num > LAST_FLOOR or not floor_ok(floor_num):
		return false
	if not Quests.corridor_records(floor_num).is_empty():
		return false
	var r = WorldState.survivors.get(rescue_key_corridor(floor_num), null)
	if r is Dictionary and not r.get("none", false) and rescue_status(r) != "saved":
		return false
	return true


## Remember that the player stood by / saved this survivor (called by `Survivor`). `kind` "post" = a fighting defender,
## "rescue" = someone saved from the dead. False = nothing was written (the last run: no later run to be quiet for; or no room for it).
static func register_haven(rec: Dictionary, kind: String) -> bool:
	if not active():
		return false
	var f := int(rec.get("floor", 0))
	var apt := str(rec.get("apt", ""))
	var place: String = apt if (apt != "" and str(rec.get("role", "")) == "hider") else "f%d" % f
	if kind == "post":
		if place != "f%d" % f or not can_haven_floor(f):
			return false
	var snap := {}
	for k in ["look", "weapon", "ammo", "post", "post_kind", "spot", "max_hp"]:
		snap[k] = rec.get(k)
	return WorldState.note_haven(place, {"kind": kind, "floor": f, "apt": apt if place == apt else "", "snap": snap})


## The floor's helped defender THIS run ({} = none): the same person as the run they were helped in, grateful, at the same post.
static func haven_for_floor(floor_num: int) -> Dictionary:
	if not active() or not floor_ok(floor_num) or not WorldState.haven_floor(floor_num):
		return {}
	var h: Dictionary = WorldState.haven_info("f%d" % floor_num)
	if str(h.get("kind", "")) != "post":
		return {}                                      # a rescued survivor is the floor's rescue record, not this
	var key := haven_key(floor_num)
	var all: Dictionary = WorldState.survivors
	if not all.has(key) or all[key].get("none", false):
		var snap: Dictionary = h.get("snap", {})
		var max_hp := int(snap.get("max_hp", HP["defender"]))
		all[key] = {
			"key": key, "role": "defender", "floor": floor_num, "apt": "", "look": int(snap.get("look", 1)),
			"weapon": str(snap.get("weapon", "")), "ammo": int(snap.get("ammo", 0)), "gift": "", "gift_n": 0,
			"hp": max_hp, "max_hp": max_hp, "dead": false,
			"x": -1.0, "post": float(snap.get("post", 600.0)), "post_kind": str(snap.get("post_kind", "")), "spot": float(snap.get("spot", 0.5)),
			"met": 0, "aided": true, "calm": false, "gave": false, "quest": "", "haven": true, "helped": true, "credited": true,
		}
	return all[key]


# =============================== RESCUES ===============================================

static func rescue_key_corridor(floor_num: int) -> String:
	return "f%d:rescue" % floor_num                 # (no run: one person, all three runs)


static func rescue_key_flat(apartment_id: String) -> String:
	return "%s:rescue" % apartment_id


## The shouting survivor of this corridor floor, or what became of them ({} = nobody, or not yet). Never on the opening floors.
static func rescue_for_floor(floor_num: int) -> Dictionary:
	if not active() or floor_num < FIRST_FLOOR or floor_num > RESCUE_LAST_FLOOR or not floor_ok(floor_num):
		return {}
	return _rescue_settled(rescue_key_corridor(floor_num), "corridor", floor_num, "")


## The same for a walk-in flat (call only for a flat `hider_flat_ok` allows).
static func rescue_for_flat(apartment_id: String) -> Dictionary:
	var f: int = WorldState._apartment_floor(apartment_id)
	if not active() or f < FIRST_FLOOR or f > RESCUE_LAST_FLOOR:
		return {}
	return _rescue_settled(rescue_key_flat(apartment_id), "flat", f, apartment_id)


static func _rescue_settled(key: String, kind: String, floor_num: int, apt: String) -> Dictionary:
	var all: Dictionary = WorldState.survivors
	var rec: Dictionary = {}
	if all.has(key):
		rec = all[key]
		if rec.get("none", false):
			if WorldState.dev_survivors < 2:
				return {}
			rec = {}
	if rec.is_empty():
		rec = _roll_rescue(key, kind, floor_num, apt)
		all[key] = rec if not rec.is_empty() else {"none": true}
		if rec.is_empty():
			return {}
	var status := rescue_status(rec)
	if status == "future":
		return {}
	if status == "lost" and not bool(rec.get("dead", false)):
		rec["dead"] = true                           # an event that came and went unanswered: a body where they stood
		rec["hp"] = 0
		rec["rescue"] = "lost"
	return rec


static func _roll_rescue(key: String, kind: String, floor_num: int, apt: String) -> Dictionary:
	var rng := _rng(key + ":appears")
	var force: bool = WorldState.dev_survivors >= 2        # the dev switch (2): a rescue at every place that can hold one
	if not force and rng.randf() >= float(RESCUE_CHANCE[kind]):
		return {}
	var appears := int(_weighted(RESCUE_APPEARS, rng))
	if force:
		appears = _run()                              # …happening NOW, whatever run it is
	var rec := _roll(key, "defender" if kind == "corridor" else "hider", floor_num, apt, appears)
	if rec.is_empty():
		return {}
	if kind == "flat" and str(rec.get("weapon", "")) == "":
		var wr := _rng(key + ":arms")
		if wr.randf() < 0.30:
			rec["weapon"] = "001"                      # a kitchen knife, to shove the first one off with
	var g := _weighted_gift(_rng(key + ":gift"), RESCUE_GIFTS)       # a thank-you for whoever saves them (their own table: it can be scrap or money)
	rec["gift"] = g
	rec["gift_n"] = int(RESCUE_GIFTS[g][1])
	rec["rescue"] = "pending"
	rec["appears"] = appears
	rec["peril"] = RESCUE_HOLD
	return rec


## "" = not a rescue · "future" = their event is in a later run (nobody here yet) · "open" = the event is on NOW ·
## "saved" / "lost" = what the player made of it. An event whose run is over without an answer is "lost".
static func rescue_status(rec: Dictionary) -> String:
	var st := str(rec.get("rescue", ""))
	if st == "":
		return ""
	if st == "saved" or st == "lost":
		return st
	var appears := int(rec.get("appears", 1))
	if _run() < appears:
		return "future"
	return "open" if _run() == appears else "lost"


static func rescue_dead_key(rec: Dictionary, i: int) -> String:
	return "rescue:%s:%d" % [str(rec.get("key", "")), i]


## How many of the three are still to be killed (the kill memory holds the ones already put down this run).
static func rescue_remaining(rec: Dictionary) -> int:
	var n := 0
	for i in RESCUE_DEAD:
		var k := rescue_dead_key(rec, i)
		if not WorldState.killed_zombies.has(k) and not WorldState.followed_away.has(k):      # (one that followed the player away is no longer here)
			n += 1
	return n


## Lays the three dead walking at the survivor: `toward` is the way they come from (-1 left / +1 right), at the spread
## RESCUE_STEPS from `at_x`, clamped inside [lo, hi]. They are ordinary standard zombies (kills are remembered by their key,
## their health follows the floor) sent to the survivor's spot; as a pan backdrop's SCENERY they are frozen until it commits.
static func spawn_rescue_dead(parent: Node, rec: Dictionary, at_x: float, origin_y: float, lo: float, hi: float, toward: float, floor_num: int, as_scenery: bool) -> Array:
	var out: Array = []
	var scene: PackedScene = preload("res://scenes/enemy_zombie_standard.tscn")
	for i in RESCUE_DEAD:
		var skey := rescue_dead_key(rec, i)
		if WorldState.killed_zombies.has(skey) or WorldState.followed_away.has(skey):
			continue
		var x := clampf(at_x + toward * float(RESCUE_STEPS[i]), lo, hi)
		if absf(x - at_x) < 120.0:                     # no room on that side: they come from the other
			x = clampf(at_x - toward * float(RESCUE_STEPS[i]), lo, hi)
		var z = scene.instantiate()
		z.position = Vector2(x, origin_y)
		z.spawn_key = skey
		z.hp_floor = floor_num
		z.add_to_group("rescue_dead")
		if as_scenery:
			z.add_to_group("pan_scenery")
		parent.add_child(z)
		WorldState.apply_saved_zombie(z)
		if as_scenery:
			z.set_physics_process(false)
			EnemyMind._begin_investigate(z, at_x)      # (silently: nobody should hear a backdrop)
		else:
			EnemyMind.hear(z, at_x)
		out.append(z)
	return out


static func _weighted_gift(rng: RandomNumberGenerator, table: Dictionary = GIFTS) -> String:
	var w := {}
	for id in table:
		w[id] = int(table[id][0])
	return _weighted(w, rng)


## The dead/alive census for tests and the journal: records for a floor this run that are alive.
static func living_on_floor(floor_num: int) -> Array:
	var out: Array = []
	for r in corridor_records(floor_num):
		if not bool(r.get("dead", false)):
			out.append(r)
	return out
