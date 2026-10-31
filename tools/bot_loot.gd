extends RefCounted

# THE LOOTER (owner round 44 — "this time I want the bots to scavenge too… a complete test to check for balance and errors/problems").
# Everything the descent bot (bot_run.gd) does NOT do on its own: walk the corridor's doors, open / force / unlock them, go into the
# apartments, search every scavenge node, take what is worth the slot, put the worst thing down when the bag is full, pick up what the
# dead drop, go through the maintenance room, and leave again — through the game's own doors, nodes, loot panel and pickups.
# docs/BOT_RUNS.md has the policy and the numbers.
#
# It owns NO input of its own: it asks the bot (`bot`) to walk, tap, switch stance and fight, so there is one set of keys held.

var ANCHOR_TIMEOUT := 40.0
const MELEE_RANK := {"bat": 100, "sword": 60, "knife": 40}

var bot                                   # the bot_run node (untyped: this file is preloaded by it)
var only_apts: Array = []                 # debugging: loot only these apartments (--apt=2903,2904)
var avoid_breach: bool = false            # --avoid-breach: never go into a breach room (a prudent player's rule)
var mode: String = "need"                 # need = loot while the kit is short · all = every door on the way

# --- per floor ---
var floor_n: int = -1
var done: Dictionary = {}                 # apartment id -> why it is finished
var cur_door = null
var door_t: float = 0.0
var door_stage: String = ""               # walk · force · key · wait
var _door_state_at_start: int = -1
var _force_wait: float = 0.0

# --- per apartment / maintenance room ---
var in_room: bool = false
var room_id: String = ""
var room_t: float = 0.0
var cur_anchor = null
var anchor_t: float = 0.0
var anchor_stage: String = ""             # walk · wait · reveal · decide
var done_anchors: Dictionary = {}         # anchor name -> outcome (this visit)
var panel_t: float = 0.0
var exiting: bool = false
var exit_t: float = 0.0
var _room_rec: Dictionary = {}
var _stepdown_t: float = 0.0
var _retarget_t: float = 0.0
var _dumped: bool = false
var _drop_t: float = 0.0
var _discards: Array = []                 # {id, x, floor, run}: what the bot put down, so it never picks its own rubbish back up
var _next_room_door: String = ""          # how the door stood when the bot went in (open / forced / breached …)
var bench_open: bool = false              # the workbench screen is up (it pauses the tree)
var _exit_hangs: int = 0
var _balcony_used: int = 0
var _retry_at: Dictionary = {}            # apartment id -> game time to look at its door again
var _skip_seen: Dictionary = {}
var _entering_apt: String = ""
var _entering_maint: bool = false
var _enter_wait: float = 0.0
var _enter_tries: int = 0
var _balcony_wanted: bool = false
var _balcony_t: float = 0.0
var _balcony_used_pending: bool = false
var _drop_skip: Dictionary = {}           # instance id -> true: a drop the bot gave up on
var _drop_gap: Dictionary = {}
var _drop_walk_t: Dictionary = {}
var _drop_tries: Dictionary = {}
var _instant: Dictionary = {}              # anchor name -> times its panel shut within 0.3 s (this visit)

# --- results (the report reads these) ---
var apartments: Array = []                # one record per apartment / maintenance visit
var finds: Array = []                     # every node searched: {run, floor, apt, anchor, item, amount, took, why}
var skips: Array = []                     # doors that were passed over: {run, floor, apt, why}
var cov: Dictionary = {}                  # coverage counters: what the bot actually exercised


func _init(b = null, m: String = "need") -> void:
	bot = b
	mode = m


func tlog(msg: String) -> void:
	if bot.trace:
		print("      [loot t=%.1f] %s" % [bot.t, msg])


func count(key: String, n: int = 1) -> void:
	cov[key] = int(cov.get(key, 0)) + n


# =============================================================== inventory knowledge

static func item(id: String) -> Dictionary:
	return ItemData.get_item(id)


func melee_slots() -> Array:
	var out: Array = []
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		var d: Dictionary = inst.get_data()
		if d.get("is_weapon", false) and not inst.is_depleted:
			var ty: String = bot._player().call("_get_weapon_type", d) if bot._player() != null else ""
			if ty != "gun" and ty != "":
				out.append(i)
	return out


func melee_score(inst) -> float:
	var ty: String = bot._weapon_type(inst)
	return float(MELEE_RANK.get(ty, 0)) + float(inst.current_durability)


func best_melee_slot() -> int:
	var best := -1
	var best_s := -1.0
	for i in melee_slots():
		var s := melee_score(WorldState.inventory[i])
		if s > best_s:
			best_s = s
			best = i
	return best


## Swings left in the bag: the durability of every working melee weapon (weapons are consumables — a hammer is ten swings).
func melee_budget(exclude_slot: int = -1) -> int:
	var n := 0
	for i in melee_slots():
		if i != exclude_slot:
			n += WorldState.inventory[i].current_durability
	return n


func has_gun() -> bool:
	for inst in WorldState.inventory:
		if inst.item_id == "004" and not inst.is_depleted:
			return true
	return false


func bullets_total() -> int:
	var n := 0
	for inst in WorldState.inventory:
		if inst.item_id == "016":
			n += inst.count
		elif inst.item_id == "004":
			n += inst.mag_count
	return n


func heal_points() -> int:
	var n := 0
	for inst in WorldState.inventory:
		var d: Dictionary = inst.get_data()
		if d.get("is_health_item", false):
			var per: int = inst.base_heals() + WorldState.get_heal_bonus()
			var uses: int = maxi(1, inst.current_durability) if inst.item_id == "010" else 1
			if inst.item_id == "010":
				uses += (inst.count - 1) * 2       # (a stack: the front bottle's doses, then two a bottle)
			else:
				uses = maxi(1, inst.count)
			n += per * uses
	return n


func free_slots() -> int:
	return maxi(0, WorldState.get_inventory_slots() - WorldState.inventory.size())


## What the kit is short of right now (the `need` policy loots while this is not empty).
func needs() -> Array:
	var out: Array = []
	if melee_budget() < 14:
		out.append("weapon")
	if heal_points() < 4:
		out.append("heal")
	if has_gun() and bullets_total() < 10:
		out.append("ammo")
	if WorldState.is_stair_blocked(WorldState.current_floor) and not WorldState.has_crowbar():
		out.append("crowbar")
	return out


## How much a thing is worth a slot (0 = leave it). `inst_id` may be a key target.
func worth(id: String, is_key: bool = false) -> float:
	var d: Dictionary = item(id)
	if d.is_empty():
		return 0.0
	if d.get("is_money", false) or d.get("is_scrap", false) or id == "031":
		return 10.0
	if is_key or d.get("is_key", false):
		return 8.0
	if d.get("is_weapon", false):
		var ty: String = bot._weapon_type_of_data(d)
		if ty == "gun":
			return 3.0 if has_gun() else 9.0
		if best_melee_slot() < 0:
			return 10.0
		# a weapon is worth the swings it adds, less the more the bag already holds
		var dur_new := float(_max_durability_of(id))
		var marginal: float = dur_new * clampf(1.0 - float(melee_budget()) / 40.0, 0.15, 1.0)
		var rank_bonus: float = 1.0 if ty == "bat" else 0.0
		return minf(9.0, 1.0 + 0.5 * marginal + rank_bonus)
	if d.get("is_ammo", false):
		return 8.0 if has_gun() and bullets_total() < 40 else 1.0
	if d.get("is_health_item", false):
		if id == "007":
			return 9.0
		if heal_points() < 8:
			return 6.0 if id in ["006", "010"] else 3.0
		return 1.5
	if d.get("is_crowbar", false):
		return 8.0 if not WorldState.has_crowbar() else 2.0
	if d.get("is_fuse", false):
		return 6.0 if WorldState.fuse_count() < 3 else 0.5
	if d.get("can_repair", false):
		return 4.0
	if d.get("is_extinguisher", false):
		return 4.0
	if d.get("is_throwable", false):
		return 5.0 if id == "039" else 3.0
	if d.get("is_speed_boost", false):
		return 3.0
	if d.get("can_force_lock", false):
		return 3.0
	if d.get("is_rope", false) or d.get("is_clothes", false):
		return 2.0
	if d.get("is_junk", false):
		return 0.4 if mode == "all" and free_slots() >= 3 else 0.0
	return 1.5


static func _max_durability_of(id: String) -> int:
	var inst := ItemInstance.new()
	inst.setup(id)
	return inst.get_max_durability()


## The slot holding the least valuable thing (to put down for something better). -1 = nothing worth losing.
func worst_slot(exclude_id: String = "") -> int:
	var worst := -1
	var worst_w := 1e9
	var bm := best_melee_slot()
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if inst.item_id == exclude_id:
			continue
		var w: float
		if i == bm:
			w = 50.0
		elif inst.item_id == "004":
			w = 40.0 if inst.mag_count > 0 or bullets_total() > 0 else 6.0
		elif inst.item_id == "035" or inst.get_data().get("is_key", false):
			w = 30.0
		else:
			w = _slot_worth(i)
		if w < worst_w:
			worst_w = w
			worst = i
	return worst if worst_w < 20.0 else -1


# =============================================================== the corridor: doors

func on_floor_change(f: int) -> void:
	floor_n = f
	done.clear()
	_retry_at.clear()
	cur_door = null
	door_t = 0.0
	door_stage = ""
	in_room = false
	exiting = false


func _doors(scene: Node) -> Array:
	var out: Array = []
	for n in scene.get_children():
		if n is Area2D and n.get("apartment_id") != null and n.get("current_state") != null and n.has_method("_enter_apartment"):
			out.append(n)
	return out


func _state_name(s: int) -> String:
	return ["open", "shut (forceable)", "shut (locked)", "barricaded (forceable)", "barricaded (locked)", "breached"][clampi(s, 0, 5)]


## Can the bot get through this door with what it carries? -> "" (yes) or the reason it can't.
func door_blocker(d) -> String:
	if WorldState.player_health >= 4 and heal_points() == 0 and d.get("is_maintenance") != true:
		return "too hurt to go in, nothing to heal with"       # (a flat entered like that was left again at once)
	var st: int = int(d.current_state)
	var bm := best_melee_slot()
	var dura: int = WorldState.inventory[bm].current_durability if bm >= 0 else 0
	match st:
		WorldState.DoorState.OPEN:
			return ""
		WorldState.DoorState.BREACHED:
			if avoid_breach:
				return "breach room (avoided)"
			if mode != "all" and WorldState.player_health >= 3:
				return "breach room, hurt"
			if bm < 0:
				return "breach room, unarmed"
			return ""
		WorldState.DoorState.SHUT_FORCEABLE:
			if bm < 0 or dura < 3:
				return "needs a weapon with 3+ uses"
			return ""
		WorldState.DoorState.SHUT_LOCKED:
			if _key_slot_for(d.apartment_id) >= 0:
				return ""
			var fs := _force_lock_slot()
			if fs < 0:
				return "locked, no key, nothing to force it"
			return ""
		WorldState.DoorState.BARRICADED_FORCEABLE, WorldState.DoorState.BARRICADED_LOCKED:
			if mode != "all" and not ("crowbar" in needs()):
				return "barricaded"
			if bm < 0 or dura < 4:
				return "barricaded, weapon too worn"
			return ""
	return "unknown state"


func _key_slot_for(apt: String) -> int:
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if inst.get_data().get("is_key", false) and inst.target_apartment == apt:
			return i
	return -1


func _force_lock_slot() -> int:
	var best := -1
	var best_d := 0
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if inst.is_depleted:
			continue
		var d: Dictionary = inst.get_data()
		if d.get("can_force_lock", false) and inst.current_durability >= 3 and inst.current_durability > best_d:
			best = i
			best_d = inst.current_durability
	return best


## No door on this floor is left to try (so a crowbar that never turned up will not).
func floor_exhausted(p, scene: Node) -> bool:
	if mode == "none":
		return true
	if floor_n != WorldState.current_floor:
		on_floor_change(WorldState.current_floor)
	return cur_door == null and _next_door(p, scene) == null


func wants_floor() -> bool:
	if mode == "none":
		return false
	if WorldState.current_floor == 30 and WorldState.current_run == 1:
		return false             # the tutorial's flats are scripted (tests/tutorial_test.tscn owns them); the bot skips the tutorial
	if mode == "all":
		return true
	return not needs().is_empty()


## One tick of corridor looting. True = the bot's frame was used (it is walking to / working a door).
func corridor_tick(p, scene: Node) -> bool:
	if mode == "none" or p == null:
		return false
	if floor_n != WorldState.current_floor:
		on_floor_change(WorldState.current_floor)
	if not wants_floor():
		return false
	# the dead's drops lie in the corridor too
	if _pickup_drops(p, scene, 260.0):
		return true
	# a door in progress
	if cur_door != null and is_instance_valid(cur_door):
		return _work_door(p)
	cur_door = null
	var d = _next_door(p, scene)
	if d == null:
		return false
	cur_door = d
	door_t = 0.0
	door_stage = "walk"
	_door_state_at_start = int(d.current_state)
	tlog("door pick %s (%s) done=%s" % [str(d.apartment_id), _state_name(_door_state_at_start), str(done.keys())])
	return _work_door(p)


func _next_door(p, scene: Node):
	var best = null
	var best_dx := 1e9
	for d in _doors(scene):
		var apt := str(d.apartment_id)
		if done.has(apt) and _retry_at.has(apt) and bot.t >= float(_retry_at[apt]):
			done.erase(apt)                  # a door passed over for want of something may be possible now (a weapon, a key, a kit found)
			_retry_at.erase(apt)
		if done.has(apt):
			continue
		if d.get("is_maintenance") == true:
			if not maint_policy(d):
				done[apt] = "maintenance room: nothing to do there"
				continue
			var mdx := absf(d.global_position.x - p.global_position.x)
			if mdx < best_dx:
				best_dx = mdx
				best = d
			continue
		if not only_apts.is_empty() and not (apt in only_apts):
			done[apt] = "filtered (--apt)"
			continue
		var why := door_blocker(d)
		if why != "":
			done[apt] = why
			_retry_at[apt] = bot.t + 8.0
			var sk := "%d|%d|%s|%s" % [WorldState.current_run, WorldState.current_floor, apt, why]
			if not _skip_seen.has(sk):
				_skip_seen[sk] = true
				skips.append({"run": WorldState.current_run, "floor": WorldState.current_floor, "apt": apt, "why": why, "state": _state_name(int(d.current_state))})
			continue
		var dx := absf(d.global_position.x - p.global_position.x)
		if dx < best_dx:
			best_dx = dx
			best = d
	return best


func _work_door(p) -> bool:
	var d = cur_door
	var apt := str(d.apartment_id)
	door_t += bot.dt
	# A long walk to a door is the shape of a pin: from 15 s on, say what the player, the dead and the survivors are doing once a game-second
	# (silent before, so a run that never gets stuck prints nothing and takes exactly the path it always took).
	if door_t > 15.0 and int(door_t) != int(door_t - bot.dt):
		print("      [pin t=%.1f door_t=%d] apt %s stage %s :: %s" % [bot.t, int(door_t), apt, door_stage, diag(p)])
	if door_t > 75.0:
		done[apt] = "timed out at the door (%s)" % door_stage
		bot._anomaly("DOOR_TIMEOUT", "floor %d apt %s: gave up at the door, stage %s, state %s (door x=%d, near=%s) :: %s" % [WorldState.current_floor, apt, door_stage, _state_name(int(d.current_state)), int(d.global_position.x), str(d.player_nearby), diag(p)])
		cur_door = null
		bot.want_scav = false
		return false
	var st: int = int(d.current_state)
	if d.get("is_maintenance") == true:
		st = WorldState.DoorState.OPEN
	var near: bool = d.player_nearby
	if not near:
		bot.want_scav = false
		_walk_to(p, d.global_position.x)
		return true
	# in reach of the door
	bot._walk(0.0)
	p.call("_clear_move_target")
	match st:
		WorldState.DoorState.OPEN, WorldState.DoorState.BREACHED:
			# a weapon in hand and combat stance for a breach room; scavenge stance is fine for an ordinary flat
			bot.want_scav = false
			if not bot.stance_settled(false):
				return true
			# press [interact] and WAIT for the room: the press can be lost (a tap still held from the last action leaves no fresh
			# press edge; a latch left up by a loot panel), and a door marked "entered" on the press alone was never tried again
			if door_stage != "entering":
				door_stage = "entering"
				_enter_wait = 0.0
				_enter_tries = 0
				_next_room_door = _state_name(_door_state_at_start)
				_entering_apt = apt
				_entering_maint = d.get("is_maintenance") == true
			# a survivor holding this door (a defender posts ~50 px from it) takes the press as [Talk] while the player is nearer to THEM than to
			# the door (survivor.gd TALK_RANGE): stand on the door itself, as a player has to
			if _survivor_talk_near(p) and absf(p.global_position.x - d.global_position.x) > 3.0:
				bot._walk(signf(d.global_position.x - p.global_position.x))           # (not _walk_to: it stops 8 px short, and the survivor may stand nearer than that)
				_count_door("door_beside_survivor", apt)
				return true
			_enter_wait -= bot.dt
			if _enter_wait <= 0.0:
				if _enter_tries >= 6:
					done[apt] = "would not open"
					bot._anomaly("DOOR_WONT_OPEN", "floor %d apt %s: pressed [interact] six times at an open door and the room never loaded (%s)" % [WorldState.current_floor, apt, diag(p)])
					_entering_apt = ""
					cur_door = null
					return false
				_enter_tries += 1
				_enter_wait = 1.6
				WorldState.interaction_handled = false
				bot.tap("interact")
			return true
		WorldState.DoorState.SHUT_FORCEABLE, WorldState.DoorState.BARRICADED_FORCEABLE, WorldState.DoorState.BARRICADED_LOCKED, WorldState.DoorState.SHUT_LOCKED:
			bot.want_scav = true
			if not bot.stance_settled(true):
				return true
			return _force_or_unlock(p, d, st)
	return true


func _survivor_talk_near(p) -> bool:
	for n in bot.get_tree().get_nodes_in_group("survivor"):
		if is_instance_valid(n) and n.has_method("can_talk") and n.can_talk() and absf(n.global_position.x - p.global_position.x) <= 70.0:
			return true
	return false


func _force_or_unlock(p, d, st: int) -> bool:
	var apt := str(d.apartment_id)
	if d.is_forcing or d.is_removing_barricade:
		_force_wait += bot.dt
		if _force_wait > 25.0:
			_force_wait = 0.0
			bot._anomaly("FORCE_HUNG", "floor %d apt %s: forcing for 25 s and it has not finished" % [WorldState.current_floor, apt])
			done[apt] = "force hung"
			cur_door = null
		return true
	_force_wait = 0.0
	if int(d.current_state) != _door_state_at_start and (int(d.current_state) == WorldState.DoorState.OPEN):
		count("doors_forced_open")
		door_stage = "walk"
		return true
	if st == WorldState.DoorState.SHUT_LOCKED:
		var ks := _key_slot_for(apt)
		if ks >= 0:
			bot.tap("item_context")
			_count_door("keys_used", apt)
			done[apt] = "unlocked with the key"
			bot._event("DOOR", "floor %d apt %s: unlocked with its key" % [WorldState.current_floor, apt])
			return true
		var fs := _force_lock_slot()
		if fs < 0:
			done[apt] = "no way to force the lock"
			cur_door = null
			return false
		bot.select_slot(fs)
		bot.tap("item_context")
		_count_door("locks_forced", apt)
		return true
	# shut-forceable / barricaded: the best melee tool in hand, then X
	var bm := best_melee_slot()
	if bm < 0:
		done[apt] = "no weapon to force it"
		cur_door = null
		return false
	bot.select_slot(bm)
	bot.tap("item_context")
	if st == WorldState.DoorState.BARRICADED_FORCEABLE or st == WorldState.DoorState.BARRICADED_LOCKED:
		_count_door("barricades_torn", apt)
	else:
		_count_door("doors_forced", apt)
	return true


var _counted_doors: Dictionary = {}

func _count_door(key: String, apt: String) -> void:
	var k := "%s|%d|%d|%s" % [key, WorldState.current_run, WorldState.current_floor, apt]
	if not _counted_doors.has(k):
		_counted_doors[k] = true
		count(key)


func _walk_to(p, x: float) -> void:
	var dx: float = x - p.global_position.x
	if absf(dx) > 8.0:
		bot._walk(signf(dx))
		bot._sprint(absf(dx) > 220.0 and WorldState.stamina > WorldState.get_max_stamina() * 0.7)
	else:
		bot._walk(0.0)
		bot._sprint(false)


# =============================================================== the dead's drops

func _drops(scene: Node) -> Array:
	var out: Array = []
	for n in scene.get_children():
		if n is Area2D and n.get("item_id") != null and n.get("drop_key") != null and n.has_method("_try_pickup") and n.is_inside_tree():
			out.append(n)
	return out


func _pickup_drops(p, scene: Node, reach: float) -> bool:
	_drop_t -= bot.dt
	var best = null
	var best_dx := reach
	for n in _drops(scene):
		if str(n.item_id) == "036" and n.get("drop_key") == "":
			continue                     # the wall-mounted extinguisher is a fixture, not a drop
		if _drop_skip.has(n.get_instance_id()):
			continue
		var dx := absf(n.global_position.x - p.global_position.x)
		if dx < best_dx and _drop_wanted(n):
			best_dx = dx
			best = n
	if best == null:
		return false
	if bot.trace and fmod(bot.t, 4.0) < bot.dt * 1.5:
		tlog("drop %s at %d (player %d), nearby=%s" % [str(best.item_id), int(best.global_position.x), int(p.global_position.x), str(best.player_nearby)])
	if best.player_nearby:
		bot._walk(0.0)
		if _drop_t <= 0.0:
			_drop_t = 0.6
			# a full bag: put the worst thing down first (never the thing being picked up)
			var bid := str(best.item_id)
			if not _has_room_for(bid):
				var made: Array = _make_room_for(bid, worth(bid), p)
				if made.is_empty():
					_drop_skip[best.get_instance_id()] = true
					return false
				_drop_t = 0.8
				return true
			var before := _inv_signature()
			var tries: int = int(_drop_tries.get(best.get_instance_id(), 0)) + 1
			_drop_tries[best.get_instance_id()] = tries
			if tries > 3:
				_drop_skip[best.get_instance_id()] = true
				if free_slots() == 0 and not _no_slot(bid):
					# a bundle that does not wholly fit stays where it lies (robustness rule 5): by design, remembered, not a finding
					_refused[bid] = _bag_sig()
					count("drops_refused")
					return false
				bot._anomaly("DROP_NOT_TAKEN", "floor %d: pressed [interact] on a %s drop %d times and it stayed on the floor (bag %s, free slots %d)" % [WorldState.current_floor, bid, tries - 1, _inv_signature(), free_slots()])
				return false
			bot.tap("interact")
			count("drops_picked")
			bot.after(0.3, func(): _note_drop(before))
		return true
	# walking to it: if it never gets any nearer it is out of reach (a drop tossed through the end wall) — leave it
	var bid_n: int = best.get_instance_id()
	var gap := absf(best.global_position.x - p.global_position.x)
	if not _drop_gap.has(bid_n) or gap < float(_drop_gap[bid_n]) - 6.0:
		_drop_gap[bid_n] = gap
		_drop_walk_t[bid_n] = 0.0
	_drop_walk_t[bid_n] = float(_drop_walk_t.get(bid_n, 0.0)) + bot.dt
	if float(_drop_walk_t[bid_n]) > 8.0:
		_drop_skip[bid_n] = true
		count("drops_unreachable")
		bot._event("DROP", "floor %d: a %s drop at x=%d could not be reached (player x=%d)" % [WorldState.current_floor, str(best.item_id), int(best.global_position.x), int(p.global_position.x)])
		return false
	_walk_to(p, best.global_position.x)
	return true


## Put the slot's item down through the game's own discard (it lands on the floor beside the player) and remember it.
func _put_down(slot: int, p) -> void:
	var inst = WorldState.inventory[slot]
	_discards.append({"id": inst.item_id, "x": p.global_position.x, "floor": WorldState.current_floor, "run": WorldState.current_run})
	count("discards")
	HUD.discard_slot(slot)


func _was_put_down(n) -> bool:
	for d in _discards:
		if d["id"] == str(n.item_id) and int(d["floor"]) == WorldState.current_floor and int(d["run"]) == WorldState.current_run \
				and absf(float(d["x"]) - n.global_position.x) < 140.0:
			return true
	return false


func _drop_wanted(n) -> bool:
	if _was_put_down(n):
		return false
	if str(n.target_apartment) != "":
		return free_slots() > 0 or worst_slot() >= 0
	var id := str(n.item_id)
	var w := worth(id)
	if w <= 0.5:
		return false
	var d: Dictionary = item(id)
	if _has_room_for(id):
		return true
	var ws := worst_slot(id)
	return ws >= 0 and _slot_worth(ws) + 2.0 < w


func _note_drop(before: String) -> void:
	if before != _inv_signature():
		count("drops_taken")


var _refused: Dictionary = {}              # item id -> the bag (bag_sig) the game refused it into

func _bag_sig() -> String:
	var parts: Array = []
	for inst in WorldState.inventory:
		parts.append("%s:%d" % [inst.item_id, inst.count])
	return "|".join(parts)


func _inv_signature() -> String:
	var parts: Array = []
	for inst in WorldState.inventory:
		parts.append("%s:%d:%d" % [inst.item_id, inst.count, inst.current_durability])
	return "|".join(parts) + "|w%d|s%d|u%s" % [WorldState.wallet_balance, WorldState.scrap, str(WorldState.wallet_unlocked)]


# =============================================================== kit upkeep: reload, repair, throw

var _kit_gate: float = 0.0
var _mag_before: int = -1


## Between fights: reload an empty gun from the bag, mend what is broken with a toolbox, light a crowd with a Molotov.
## Returns true when it used the frame (it never does for more than one press).
func maintain_kit(p, zs: Array) -> bool:
	if mode == "none" or p == null:
		return false
	_kit_gate -= bot.dt
	if _kit_gate > 0.0 or p.is_attacking or p.is_pushing or p.is_switching_mode or p.pack_phase != "" or WorldState.loot_open:
		return false
	var nearest := 1e9
	for z in zs:
		nearest = minf(nearest, bot._edge(p, z))
	# 1. the gun is empty and rounds are in the bag
	if nearest > 140.0:
		for i in WorldState.inventory.size():
			var inst = WorldState.inventory[i]
			if inst.item_id == "004" and not inst.is_depleted and inst.mag_count == 0 and _bag_rounds() > 0:
				_kit_gate = 1.2
				if HUD.selected_slot != i:
					bot.select_slot(i)           # the first use only EQUIPS a gun; the second reloads it
					_kit_gate = 0.5
					return true
				_mag_before = inst.mag_count
				p.use_item(i)
				count("reloads")
				bot.after(0.6, func(): _verify_reload(inst))
				return true
	# 2. a toolbox and something to mend
	if nearest > 220.0:
		var tb := _slot_with("019")
		if tb >= 0 and _needs_mending():
			_kit_gate = 2.0
			var sig := _inv_signature()
			p.use_item(tb)
			count("repairs")
			bot.after(0.6, func(): _verify_repair(sig))
			return true
	# 3. three or more of the dead coming, none on us yet: burn them
	var mol := _slot_with("039")
	if mol >= 0 and nearest > 110.0:
		var ahead := 0
		var facing_right: bool = not p.animated_sprite.flip_h
		for z in zs:
			var dx: float = z.global_position.x - p.global_position.x
			var e: float = bot._edge(p, z)
			if (dx > 0.0) == facing_right and e > 110.0 and e < 340.0:
				ahead += 1
		if ahead >= 3:
			_kit_gate = 2.5
			bot.select_slot(mol)
			p.use_item(mol)
			count("molotovs_thrown")
			bot._event("THROW", "floor %d: a Molotov at %d of the dead" % [WorldState.current_floor, ahead])
			return true
	return false


func _bag_rounds() -> int:
	var n := 0
	for inst in WorldState.inventory:
		if inst.item_id == "016":
			n += inst.count
	return n


func _slot_with(id: String) -> int:
	for i in WorldState.inventory.size():
		if WorldState.inventory[i].item_id == id:
			return i
	return -1


func _needs_mending() -> bool:
	for inst in WorldState.inventory:
		var d: Dictionary = inst.get_data()
		if (d.get("is_weapon", false) or d.get("is_tool", false)) and inst.is_depleted and d.get("can_repair", false) == false:
			return true
		if inst.item_id == "004" and inst.is_damaged:
			return true
	return false


func _verify_reload(inst) -> void:
	if inst == null or not is_instance_valid(inst):
		return
	if inst.mag_count <= _mag_before and _bag_rounds() > 0:
		bot._anomaly("RELOAD_NO_EFFECT", "floor %d: used the empty gun with rounds in the bag and the magazine stayed at %d" % [WorldState.current_floor, inst.mag_count])
		count("reload_failed")
	else:
		count("reloaded_rounds", inst.mag_count - _mag_before)


func _verify_repair(sig_before: String) -> void:
	if sig_before == _inv_signature():
		bot._anomaly("REPAIR_NO_EFFECT", "floor %d: used the toolbox on something broken and nothing changed" % WorldState.current_floor)
		count("repair_failed")


# =============================================================== the merchant: sell the surplus, buy what the kit is short of

func shop_trade(ui, f: int) -> void:
	if mode == "none":
		return
	count("shop_visits")
	var notes_in: int = WorldState.get_money_total()
	var stock_n: int = ui.stock.size()
	count("shop_stock_seen", stock_n)
	# sell what is not worth a slot (the shop pays for the surplus; 3 sales a visit)
	for slot in range(WorldState.inventory.size() - 1, -1, -1):
		if WorldState.get_sales_remaining(f) <= 0:
			break
		var inst = WorldState.inventory[slot]
		var id: String = inst.item_id
		if slot == best_melee_slot() or id == "004" or inst.get_data().get("is_key", false) or id == "035":
			continue
		if _slot_worth(slot) > 1.0 or WorldState.get_sell_price(id) <= 0:
			continue
		var before := _inv_signature()
		ui._on_sell_pressed(slot)
		ui._on_sell_pressed(slot)
		if before == _inv_signature():
			bot._anomaly("SELL_NO_EFFECT", "floor %d: pressed Sell twice on %s and nothing changed" % [f, id])
		else:
			count("shop_sold")
	# buy by worth, best first, while the notes last
	var wants: Array = []
	for i in stock_n:
		var e: Dictionary = ui.stock[i]
		if bool(e["sold"]):
			continue
		var w := worth(str(e["item_id"]))
		if w >= 3.0:
			wants.append({"i": i, "w": w, "price": int(e["price"]), "id": str(e["item_id"])})
	wants.sort_custom(func(a, b): return float(a["w"]) > float(b["w"]))
	for want in wants:
		var money: int = WorldState.get_money_total()
		if money < int(want["price"]):
			count("shop_too_dear")
			continue
		var id2: String = want["id"]
		if free_slots() == 0 and not _stacks_with(id2) and not _no_slot(id2):
			var ws := worst_slot(id2)
			if ws < 0 or _slot_worth(ws) + 2.0 >= float(want["w"]):
				count("shop_no_room")
				continue
			_put_down(ws, bot._player())
		var sig := _inv_signature()
		var room_before := free_slots() > 0 or _stacks_with(id2) or _no_slot(id2)
		ui._on_buy_pressed(int(want["i"]))
		ui._on_buy_pressed(int(want["i"]))
		if sig == _inv_signature() and not room_before:
			count("shop_no_room")                    # the bag was still full when the buy was pressed (a put-down lands a beat later): "Inventory full." by design
		elif sig == _inv_signature():
			bot._anomaly("BUY_NO_EFFECT", "floor %d: bought %s for %d with %d notes and nothing changed" % [f, id2, int(want["price"]), money])
		else:
			count("shop_bought")
			count("shop_notes_spent", money - WorldState.get_money_total())
			bot._event("SHOP", "floor %d: bought %s for %d" % [f, str(item(id2).get("name", id2)), int(want["price"])])
	count("shop_notes_in", notes_in)


# =============================================================== inside a flat / the maintenance room

func _begin_room(apt: String, kind: String) -> void:
	# the room is up: the door that led here is done with (counted now, not when the press was made)
	if _entering_apt != "":
		done[_entering_apt] = "entered"
		count("maintenance_entered" if _entering_maint else "doors_entered")
		if _next_room_door.begins_with("breached"):
			count("breach_entered")
		_entering_apt = ""
		cur_door = null
	if not _room_rec.is_empty():
		if _balcony_used_pending:
			_balcony_used += 1
			_balcony_used_pending = false
			count("balcony_descents")
		_finish_room("left by the balcony" if _next_room_door == "balcony" else "left")
	in_room = true
	_dumped = false
	room_id = apt
	room_t = 0.0
	cur_anchor = null
	anchor_stage = ""
	done_anchors.clear()
	_instant.clear()
	_exit_hangs = 0
	maint_stage = ""
	exiting = false
	exit_t = 0.0
	_room_rec = {"run": WorldState.current_run, "floor": WorldState.current_floor, "apt": apt, "kind": kind, "nodes": 0, "searched": 0,
		"took": {}, "left": {}, "t": 0.0, "hp_in": WorldState.player_health, "hp_out": WorldState.player_health, "zombies": 0, "ended": "", "anchors": 0,
		"hits": 0, "hp_last": WorldState.player_health, "door": _next_room_door, "kills_in": int(bot.run_rec.get("kills", 0)), "kills": 0}
	_next_room_door = ""



func dump_room(room: Node) -> void:
	var uis: Array = bot.get_tree().get_nodes_in_group("loot_ui")
	print("      [loot_ui nodes] %d -> %s" % [uis.size(), str(uis.map(func(u): return "%s(vis=%s, parent=%s)" % [u.get_instance_id(), str(u.visible), str(u.get_parent().name)]))])
	var inter = room.get("interactables")
	if inter == null:
		return
	for a in inter:
		if is_instance_valid(a):
			print("      [anchor] %s x=%d y=%d item='%s' searched=%s vis=%s proc=%s back=%s" % [a.name, int(a.global_position.x), int(a.global_position.y), WorldState.get_anchor_item(a.apartment_id, a.name), str(WorldState.is_anchor_searched(a.apartment_id, a.name)), str(a.visible), str(a.is_processing()), str(a.get("back_spot") != null)])


func room_started() -> bool:
	return not _room_rec.is_empty() and in_room


func _finish_room(why: String) -> void:
	if _room_rec.is_empty():
		return
	_room_rec["ended"] = why
	_room_rec["t"] = room_t
	_room_rec["hp_out"] = WorldState.player_health
	apartments.append(_room_rec)
	_room_rec = {}
	in_room = false
	cur_anchor = null


## One tick inside an apartment (kind "flat") or the maintenance room (kind "maint").
func room_tick(p, room: Node, kind: String) -> void:
	if not in_room or _room_rec.is_empty() or room_id != str(room.get("apartment_id")):
		_begin_room(str(room.get("apartment_id")), kind)

	room_t += bot.dt
	_room_rec["t"] = room_t
	var hp_now: int = WorldState.player_health
	if hp_now > int(_room_rec.get("hp_last", hp_now)):
		_room_rec["hits"] = int(_room_rec.get("hits", 0)) + (hp_now - int(_room_rec["hp_last"]))
	_room_rec["hp_last"] = hp_now
	_room_rec["kills"] = int(bot.run_rec.get("kills", 0)) - int(_room_rec.get("kills_in", 0))
	if bot.trace and not _dumped:
		_dumped = true
		print("    [room] %s %s entered" % [kind, room_id])
		dump_room(room)
	# the dead in here come first
	var zs: Array = bot._zombies(p, 240.0)
	var threat = null
	for z in zs:
		# coming for us, or close; a body standing idle only counts when it is nearly on us (walking past wakes it; the game phases a
		# player through a body that blocks the lane)
		var idle: bool = str(z.get("state")) == "idle"
		# (a body busy with a survivor — a rescue in progress — stands across the lane between us and the node: it is a fight we are in)
		var busy_att: bool = str(z.get("state")) in ["attack", "chase"]
		if bot._on_me(p, z) or bot._edge(p, z) < (55.0 if idle else (220.0 if busy_att else 120.0)):
			threat = z
			break
	_room_rec["zombies"] = maxi(int(_room_rec["zombies"]), zs.size())
	if bot.god and not bot._armed() and bot._slot_of_gun() < 0:
		threat = null                    # god mode and nothing to fight with: ignore the dead
	if threat != null and not _loot_panel_open():
		bot.want_scav = false
		tlog("threat %s at %d" % [bot._type_of(threat), int(threat.global_position.x - p.global_position.x)])
		_leave_panel()
		if bot.try_heal_now(p, zs):
			return
		var exn = exit_node(room)
		bot.goal_override = exn.global_position.x if exn != null else -1.0       # "onward" in a room is the way out, not the corridor's stairs
		bot._fight(p, threat, zs)
		bot.goal_override = -1.0
		return
	if kind == "flat" and _resident_tick(p, room, zs):
		return
	if bot.try_heal_now(p, zs):
		return
	if maintain_kit(p, zs):
		return
	if room_t > (150.0 if kind == "flat" else 90.0) and not exiting:
		bot._anomaly("ROOM_LONG", "floor %d %s: still inside after %.0f s (stage %s, anchor %s)" % [WorldState.current_floor, room_id, room_t, anchor_stage, str(cur_anchor.name) if cur_anchor != null and is_instance_valid(cur_anchor) else "-"])
		exiting = true
	if exiting:
		_exit_room(p, room)
		return
	if _loot_panel_open() or anchor_stage in ["reveal", "decide"]:
		_panel_tick(p)
		return
	if anchor_stage == "took":
		_after_panel(p, "took")
	if _pickup_drops(p, room, 200.0):
		return
	# landed (or stepped) out on a balcony: back inside before anything else (S), unless the bot is on its way over the rail
	if p.on_balcony_plane and not (exiting and _balcony_wanted):
		_balcony_t -= bot.dt
		if _balcony_t <= 0.0 and not bot.is_player_busy(p):
			_balcony_t = 1.2
			bot.tap("move_down")
			count("balcony_step_ins")
		return
	if bot.balcony_first and not exiting and kind == "flat" and _has_balcony(room) and _balcony_used < 3:
		exiting = true                    # (debugging) go straight over the balcony
	if kind == "maint" and cur_anchor == null and anchor_stage == "" and _wanted_anchors(room).is_empty() and _maint_station(p, room):
		return
	if _hurt_enough_to_leave(p, kind):
		exiting = true
		_room_rec["ended"] = "left hurt"
		return
	_loot_next(p, room)


## The living in this flat (survivors behind locked doors, docs/RESIDENTS.md), by temper. A resident who has turned on us is fought
## with what we have (it is a melee / shot target like the dead); one that has only WARNED us is left alone — the bot stops searching and goes.
## Returns true when it owned the frame.
func _resident_tick(p, room: Node, zs: Array) -> bool:
	var res: Array = []
	for r in bot.get_tree().get_nodes_in_group("resident_npc"):
		if is_instance_valid(r) and room.is_ancestor_of(r) and r.get("is_dead") != true:
			res.append(r)
	if res.is_empty():
		return false
	var rr: Dictionary = _room_rec.get("residents", {})
	for r in res:
		var key := "%s%s" % [str(r.get("temper")), "+violent" if r.get("violent") == true else ""]
		if not rr.has(key):
			rr[key] = 0.0
			count("resident_" + key.replace("+", "_"))
		rr[key] = float(rr[key]) + bot.dt
	_room_rec["residents"] = rr
	var angry = null
	for r in res:
		if r.get("violent") == true and absf(r.global_position.x - p.global_position.x) < 260.0:
			if angry == null or absf(r.global_position.x - p.global_position.x) < absf(angry.global_position.x - p.global_position.x):
				angry = r
	if angry != null and not _loot_panel_open():
		# hurt and out of healing, or nothing to hit it with: get out rather than trade blows
		if (WorldState.player_health >= 4 and heal_points() == 0) or (not bot._armed() and bot._slot_of_gun() < 0):
			if not exiting:
				exiting = true
				_room_rec["ended"] = "left a violent resident"
			return false
		bot.want_scav = false
		_leave_panel()
		if bot.try_heal_now(p, zs):
			return true
		var exn = exit_node(room)
		bot.goal_override = exn.global_position.x if exn != null else -1.0
		bot._fight(p, angry, res)
		bot.goal_override = -1.0
		count("resident_fight_ticks")
		return true
	# warned but not yet swinging: do not give it a reason
	for r in res:
		if str(r.get("temper")) == "hostile" and int(r.rec.get("warned", 0)) >= 1 and not exiting:
			exiting = true
			_room_rec["ended"] = "warned off by a resident"
			count("resident_warned_off")
	return false


func _hurt_enough_to_leave(p, kind: String) -> bool:
	if kind == "maint":
		return false
	return WorldState.player_health >= 4 and heal_points() == 0


func _loot_panel_open() -> bool:
	return WorldState.loot_open


func _leave_panel() -> void:
	for ui in bot.get_tree().get_nodes_in_group("loot_ui"):
		if ui.has_method("leave"):
			ui.leave()
	anchor_stage = ""


func _loot_ui():
	for ui in bot.get_tree().get_nodes_in_group("loot_ui"):
		return ui
	return null


func _wanted_anchors(room: Node) -> Array:
	var out: Array = []
	var inter = room.get("interactables")
	if inter == null:
		return out
	for a in inter:
		if not is_instance_valid(a) or not a.visible or done_anchors.has(str(a.name)):
			continue
		if a.has_meta("ruin_scrap"):
			out.append(a)
			continue
		var searched := WorldState.is_anchor_searched(a.apartment_id, a.name)
		var has_item: bool = WorldState.get_anchor_item(a.apartment_id, a.name) != "" or WorldState.is_anchor_a_key(a.apartment_id, a.name)
		if searched and not has_item:
			continue
		out.append(a)
	return out


func _loot_next(p, room: Node) -> void:
	_room_rec["anchors"] = (room.get("interactables") as Array).size() if room.get("interactables") != null else 0
	if cur_anchor == null or not is_instance_valid(cur_anchor):
		cur_anchor = _pick_anchor(p, room)
		anchor_t = 0.0
		anchor_stage = "walk"
		tlog("pick %s" % (str(cur_anchor.name) if cur_anchor != null else "none"))
		if cur_anchor == null:
			exiting = true
			if _room_rec["ended"] == "":
				_room_rec["ended"] = "all searched"
			return
	var a = cur_anchor
	if not a.visible and anchor_stage != "reveal" and anchor_stage != "decide":
		# searched and found empty while we weren't looking (a threat cut the panel short): the node has gone dark by design
		done_anchors[str(a.name)] = "emptied"
		cur_anchor = null
		anchor_stage = ""
		return
	anchor_t += bot.dt
	if anchor_t > ANCHOR_TIMEOUT:
		done_anchors[str(a.name)] = "unreachable"
		bot._anomaly("ANCHOR_UNREACHABLE", "floor %d %s: could not search %s in %d s (stage %s, player x=%d y=%d, anchor x=%d y=%d, in_range=%s, scav=%s, switching=%s, attacking=%s, back_spot=%s, player_back=%s, plane_ok=%s, proc=%s, ref_ok=%s, same=%s) %s" % [WorldState.current_floor, room_id, a.name, int(ANCHOR_TIMEOUT), anchor_stage, int(p.global_position.x), int(p.global_position.y), int(a.global_position.x), int(a.global_position.y), str(a.is_in_range), str(WorldState.is_scavenge_mode), str(p.is_switching_mode), str(p.is_attacking), str(a.get("back_spot") != null), str(p.back_spot != null), str(a.call("_plane_ok")), str(a.is_processing()), str(is_instance_valid(a.player)), str(a.player == p), diag(p)])
		_leave_panel()
		cur_anchor = null
		return
	# a ruined flat's scrap needs no search
	if a.has_meta("ruin_scrap"):
		bot.want_scav = true
		if not bot.stance_settled(true):
			return
		if absf(a.global_position.x - p.global_position.x) > 24.0:
			_walk_to(p, a.global_position.x)
			return
		bot._walk(0.0)
		WorldState.interaction_handled = false
		a.try_interact()
		count("ruin_scrap_taken")
		done_anchors[str(a.name)] = "ruin scrap"
		cur_anchor = null
		return
	bot.want_scav = true
	var back = a.get("back_spot")
	if back != null:
		# set-back furniture: step up to it (the game's own click-to-search path does the step), then search
		bot._walk(0.0)               # (a key left held by an earlier step overrides the click-move for good: the player pressed on into a wall for 30 s)
		if p.back_spot != back:
			_retarget_t -= bot.dt
			if p.back_spot != null and not bot.is_player_busy(p) and _stepdown_t <= 0.0:
				_stepdown_t = 0.8
				p.call("exit_back_plane", false)           # stepped up at a DIFFERENT piece of furniture: down first
			elif not p.has_move_target and not bot.is_player_busy(p) and _retarget_t <= 0.0 and p.back_spot == null:
				_retarget_t = 4.0
				p.set_move_target(a.global_position.x, a)  # the game's own click-to-search: walks over, steps up, searches
				count("back_plane_steps")
			_stepdown_t -= bot.dt
			return
	else:
		if p.back_spot != null:
			if _stepdown_t <= 0.0 and not bot.is_player_busy(p):
				_stepdown_t = 0.8
				p.call("exit_back_plane", false)
			_stepdown_t -= bot.dt
			return
		var dx: float = a.global_position.x - p.global_position.x
		if absf(dx) > 20.0:
			_walk_to(p, a.global_position.x)
			return
		bot._walk(0.0)
	if not bot.stance_settled(true):
		return
	bot._walk(0.0)
	if not a.is_in_range:
		# close enough in x but the 2-D range test says no (a high node): nudge toward it
		if back == null:
			_walk_to(p, a.global_position.x)
		return
	# a swing's cooldown still running would shut the panel at once (the game's rule: a search is cancelled by an attack) — let it end
	if p.is_attacking or p.is_pushing:
		return
	# search it: the game's own path (auto stance for a low / high node, then the node's try_interact)
	WorldState.interaction_handled = false
	if p.has_method("auto_stance_for_anchor"):
		p.auto_stance_for_anchor(a.global_position.y)
	a.try_interact()
	anchor_stage = "reveal"
	panel_t = 0.0
	tlog("try_interact %s -> loot_open=%s" % [a.name, str(WorldState.loot_open)])
	count("nodes_opened")
	if WorldState.loot_open:
		_room_rec["nodes"] = int(_room_rec["nodes"]) + 1
	else:
		# the node refused (a locked cabinet, a hidden node): note it and move on
		done_anchors[str(a.name)] = "refused"
		count("nodes_refused")
		cur_anchor = null
		anchor_stage = ""


func _pick_anchor(p, room: Node):
	var best = null
	var best_dx := 1e9
	for a in _wanted_anchors(room):
		var dx := absf(a.global_position.x - p.global_position.x)
		# stay on the plane you are on if you can (stepping up and down costs time)
		if (a.get("back_spot") != null) != (p.back_spot != null):
			dx += 60.0
		if dx < best_dx:
			best_dx = dx
			best = a
	return best


func _panel_tick(p) -> void:
	panel_t += bot.dt
	var ui = _loot_ui()
	if ui == null or not ui.visible:
		# the panel closed on its own (nothing found / walked off)
		if anchor_stage in ["reveal", "decide"]:
			if panel_t < 0.3:
				# a search that shuts at once was cancelled by something (a swing, a push, a stance change): retry it a few times, then say so
				var nm := str(cur_anchor.name) if cur_anchor != null and is_instance_valid(cur_anchor) else "?"
				_instant[nm] = int(_instant.get(nm, 0)) + 1
				count("instant_closes")
				if bot.trace:
					tlog("panel closed after %.2f s: switching=%s pushing=%s attacking=%s scav=%s anim=%s" % [panel_t, str(p.is_switching_mode), str(p.is_pushing), str(p.is_attacking), str(WorldState.is_scavenge_mode), str(p.animated_sprite.animation)])
				if int(_instant[nm]) >= 5:
					done_anchors[nm] = "instant close"
					bot._anomaly("PANEL_INSTANT_CLOSE", "floor %d %s: the panel for %s shut within 0.3 s five times running (attacking=%s pushing=%s switching=%s)" % [WorldState.current_floor, room_id, nm, str(p.is_attacking), str(p.is_pushing), str(p.is_switching_mode)])
			_after_panel(p, "closed")
		return
	if panel_t > 20.0:
		bot._anomaly("PANEL_STUCK", "floor %d %s: the loot panel stayed open 20 s (revealing=%s, has_item=%s)" % [WorldState.current_floor, room_id, str(ui.is_revealing), str(ui.has_item)])
		ui.leave()
		_after_panel(p, "stuck")
		return
	if ui.is_revealing:
		anchor_stage = "reveal"
		return
	anchor_stage = "decide"
	if not ui.has_item:
		return                      # an empty search closes itself (a line, no panel)
	var id: String = str(ui.current_item_id)
	var is_key: bool = str(ui.current_key_target) != ""
	var w := worth(id, is_key)
	var key_tgt := str(ui.current_key_target)
	var rec := {"key_target": key_tgt, "run": WorldState.current_run, "floor": WorldState.current_floor, "apt": room_id, "anchor": str(cur_anchor.name) if cur_anchor != null and is_instance_valid(cur_anchor) else "?", "item": id, "worth": w}
	_room_rec["searched"] = int(_room_rec["searched"]) + 1
	var take := false
	var why := ""
	if w >= 1.0 and _has_room_for(id):
		take = true
	elif w >= 1.0:
		var put_down: Array = _make_room_for(id, w, p)
		if _has_room_for(id) and not put_down.is_empty():
			take = true
			why = "swapped for " + ", ".join(PackedStringArray(put_down))
		else:
			why = "bag full"
	else:
		why = "not worth a slot"
	rec["took"] = take
	rec["why"] = why
	if take:
		var before := _inv_signature() + "|h%d" % WorldState.player_health        # (health too: bandages taken and used within the check's 0.25 s leave the bag as it was)
		var pushed := InputEventAction.new()
		pushed.action = "interact"
		pushed.pressed = true
		bot.get_viewport().push_input(pushed)
		if cur_anchor != null and is_instance_valid(cur_anchor):
			done_anchors[str(cur_anchor.name)] = "taking"
		bot.after(0.25, func(): _verify_take(rec, before, id))
		_room_rec["took"][id] = int(_room_rec["took"].get(id, 0)) + 1
		count("items_taken")
		anchor_stage = "took"
		panel_t = 0.0
		return
	_room_rec["left"][id] = int(_room_rec["left"].get(id, 0)) + 1
	count("items_left")
	finds.append(rec)
	if cur_anchor != null and is_instance_valid(cur_anchor):
		done_anchors[str(cur_anchor.name)] = "left: " + why
	ui.leave()
	_after_panel(p, "left")


func _slot_worth(slot: int) -> float:
	var inst = WorldState.inventory[slot]
	if slot == best_melee_slot():
		return 50.0
	if slot in melee_slots():
		return minf(8.0, 1.0 + 0.5 * float(inst.current_durability))      # a spare weapon is as good as its swings
	var w := worth(inst.item_id)
	if inst.get_data().get("is_health_item", false):
		w += 2.0
	return w


## Is there somewhere to put this: a free slot, a stack with space left, or an item that takes no slot?
func _has_room_for(id: String) -> bool:
	if _no_slot(id) or free_slots() > 0:
		return true
	# the game refuses a bundle that does not WHOLLY fit (all-or-nothing for ammo): while the bag is just as it was when it refused, it will again
	if _refused.get(id, "") == _bag_sig():
		return false
	var d: Dictionary = item(id)
	var cap := 0
	if d.get("is_ammo", false):
		cap = WorldState.MAX_AMMO_PER_SLOT
	elif d.get("is_fuse", false):
		cap = WorldState.MAX_FUSE_PER_SLOT
	elif d.get("is_throwable", false):
		cap = WorldState.throwable_cap(id)
	elif d.get("is_medical", false):
		cap = WorldState.MAX_MEDICAL_PER_SLOT
	elif d.get("is_money", false):
		return _stacks_with(id)
	if cap > 0:
		for inst in WorldState.inventory:
			if inst.item_id == id and inst.count < cap:
				return true
	return false


## Put the least valuable things down (the game's own discard) until `id` fits — only things worth clearly less than it, at most three.
## Returns the item ids put down (empty = it would not fit, nothing was put down).
func _make_room_for(id: String, w: float, p) -> Array:
	var out: Array = []
	for _i in range(3):
		if _has_room_for(id):
			break
		var ws := worst_slot(id)
		if ws < 0 or _slot_worth(ws) + 2.0 >= w:
			break
		var out_id: String = WorldState.inventory[ws].item_id
		bot._event("BAG", "floor %d: put down %s for %s" % [WorldState.current_floor, out_id, id])
		_put_down(ws, p)
		out.append(out_id)
	return out


## Things the game absorbs without a slot: the Empty Wallet (unlocks the wallet), scrap bags, and cash once the wallet is unlocked.
func _no_slot(id: String) -> bool:
	if id == "031":
		return true
	var d: Dictionary = item(id)
	return d.get("is_scrap", false) or (d.get("is_money", false) and WorldState.wallet_unlocked)


func _stacks_with(id: String) -> bool:
	var d: Dictionary = item(id)
	if d.get("is_ammo", false) or d.get("is_throwable", false) or d.get("is_fuse", false) or d.get("is_money", false):
		for inst in WorldState.inventory:
			if inst.item_id == id:
				return true
	return false


func _verify_take(rec: Dictionary, before: String, id: String) -> void:
	var ok := before != _inv_signature() + "|h%d" % WorldState.player_health
	rec["landed"] = ok
	finds.append(rec)
	var nm := str(rec.get("anchor", "?"))
	var held_key := false
	if str(rec.get("key_target", "")) != "":
		for inst in WorldState.inventory:
			if inst.target_apartment == str(rec["key_target"]):
				held_key = true
	if not ok and held_key:
		# a second key for a door the bag already holds the key to: the game takes it "silently" (WorldState.add_key_to_inventory) — by design
		rec["why"] = "already held"
		count("keys_already_held")
		done_anchors[nm] = "taken (already held)"
		_leave_panel()
		cur_anchor = null
		panel_t = 0.0
		return
	if not ok:
		if free_slots() == 0 and not _no_slot(id):
			# the bag was full for it (an ammo bundle must fit WHOLLY): the game leaves it on the node — by design, remembered, not a finding
			rec["why"] = "did not fit"
			rec["took"] = false
			_refused[id] = _bag_sig()
			count("takes_refused")
			count("items_taken", -1)                  # (counted as taken when the press was made)
			var tk: int = int(_room_rec.get("took", {}).get(id, 0)) - 1
			if tk > 0:
				_room_rec["took"][id] = tk
			else:
				_room_rec.get("took", {}).erase(id)
			_room_rec["left"][id] = int(_room_rec["left"].get(id, 0)) + 1
			done_anchors[nm] = "left: did not fit"
		else:
			# room, a press, and nothing changed: money to the wallet / scrap also change the signature, so this is real
			bot._anomaly("TAKE_NO_EFFECT", "floor %d %s: took %s from %s but nothing in the bag / wallet / scrap changed (free slots %d, bag %s)" % [WorldState.current_floor, room_id, id, nm, free_slots(), _bag_sig()])
			count("takes_lost")
			done_anchors[nm] = "take failed"
		# the panel is still open on the same item: shut it, or the next tick decides to take it again for ever
		_leave_panel()
		cur_anchor = null
		panel_t = 0.0
		return
	done_anchors[nm] = "taken"


func _after_panel(_p, _how: String) -> void:
	tlog("after_panel (%s) anchor=%s" % [_how, str(cur_anchor.name) if cur_anchor != null and is_instance_valid(cur_anchor) else "-"])
	anchor_stage = ""
	cur_anchor = null
	panel_t = 0.0


## Is the maintenance room on this floor worth a visit? (Always in `all` mode; otherwise when there is something to do there.)
func maint_policy(_d) -> bool:
	if mode == "none":
		return false
	if mode == "all":
		return true
	return WorldState.scrap >= 30 or WorldState.fuse_count() > 0 or "weapon" in needs()


var maint_stage: String = ""              # "" · fuse · bench · done
var _maint_t: float = 0.0
var _maint_tap: float = 0.0
var _fuses_before: int = 0


## The two stations (room.gd `_maintenance_process`): the fuse box at `_fuse_box_pos`, the workbench at `_workbench_pos`, each [E] when
## standing in front of it. Returns true while it is using the frame; false once both are done (the room then empties out).
func _maint_station(p, room: Node) -> bool:
	if maint_stage == "":
		maint_stage = "fuse"
		_maint_t = 0.0
		_maint_tap = 0.0
	if maint_stage == "done":
		return false
	_maint_t += bot.dt
	_maint_tap -= bot.dt
	if _maint_t > 50.0:
		bot._anomaly("MAINT_STUCK", "floor %d: 50 s at the %s station and it did not finish" % [WorldState.current_floor, maint_stage])
		maint_stage = "done"
		return false
	bot.want_scav = true
	match maint_stage:
		"fuse":
			if WorldState.fuse_count() <= 0 or WorldState.elevator_powered:
				count("fusebox_visits_empty" if WorldState.fuse_count() <= 0 else "fusebox_already_powered")
				maint_stage = "bench"
				_maint_t = 0.0
				return true
			var fx: float = room.get("_fuse_box_pos").x
			if absf(fx - p.global_position.x) > 28.0:
				_walk_to(p, fx)
				return true
			bot._walk(0.0)
			if _maint_tap <= 0.0:
				_maint_tap = 0.8
				_fuses_before = WorldState.elevator_fuses_loaded
				WorldState.interaction_handled = false
				bot.tap("interact")
				bot.after(0.4, func(): _verify_fuse())
				count("fuse_box_pressed")
			return true
		"bench":
			if not _bench_wanted():
				count("bench_skipped")
				maint_stage = "done"
				return false
			var bx: float = room.get("_workbench_pos").x
			if absf(bx - p.global_position.x) > 28.0:
				_walk_to(p, bx)
				return true
			bot._walk(0.0)
			var ui = room.get("_workbench_ui")
			if ui != null and is_instance_valid(ui) and ui.visible:
				bench_open = true
				_bench_session(ui)
				ui.close()
				bench_open = false
				maint_stage = "done"
				return false
			if _maint_tap <= 0.0:
				_maint_tap = 1.0
				WorldState.interaction_handled = false
				bot.tap("interact")
				count("bench_pressed")
			return true
	return false


func bench_ui_visible(room: Node) -> bool:
	var ui = room.get("_workbench_ui") if room != null else null
	return ui != null and is_instance_valid(ui) and ui.visible


func _verify_fuse() -> void:
	if WorldState.elevator_fuses_loaded <= _fuses_before and not WorldState.elevator_powered:
		bot._anomaly("FUSE_NO_EFFECT", "floor %d: pressed the fuse box with fuses in the bag and nothing was fitted (loaded %d, carrying %d)" % [WorldState.current_floor, WorldState.elevator_fuses_loaded, WorldState.fuse_count()])
	else:
		count("fuses_fitted", WorldState.elevator_fuses_loaded - _fuses_before)
		if WorldState.elevator_powered:
			count("elevator_powered")
			bot._event("ELEVATOR", "floor %d: the elevator is powered (run %d)" % [WorldState.current_floor, WorldState.current_run])


func _bench_wanted() -> bool:
	if WorldState.scrap >= 1:
		return true
	for inst in WorldState.inventory:
		if inst.is_depleted and Salvage.can_salvage(inst):
			return true
		if WeaponUpgrades.can_upgrade(inst.item_id) and WeaponUpgrades.points_free(inst) > 0:
			return true
	return false


## One sitting at the bench, driven through the screen's own methods: break down what is broken, raise the best weapons as far as the
## scrap goes, spend the tuning points, and note every refusal (the sweep reads them to see what stops a player).
func _bench_session(ui) -> void:
	count("bench_sessions")
	var scrap_in: int = WorldState.scrap
	# 1. what is broken is worth more as scrap (anything but junk asks twice)
	for slot in range(WorldState.inventory.size() - 1, -1, -1):
		var inst = WorldState.inventory[slot]
		if inst.is_depleted and Salvage.can_salvage(inst) and not inst.get_data().get("is_key", false):
			var got: int = ui.salvage(slot)
			if got == 0:
				got = ui.salvage(slot)
			if got > 0:
				count("bench_salvaged")
				count("bench_salvage_scrap", got)
			else:
				count("bench_salvage_refused")
	# 2. upgrade: the best melee weapon first, then the gun
	var order: Array = []
	var bm := best_melee_slot()
	if bm >= 0:
		order.append(WorldState.inventory[bm])
	for inst in WorldState.inventory:
		if inst.item_id == "004" and not inst.is_depleted:
			order.append(inst)
	for inst in order:
		for _i in range(8):
			var slot2: int = WorldState.inventory.find(inst)
			if slot2 < 0:
				break
			var chk: Dictionary = WeaponUpgrades.check(inst, WorldState.inventory, WorldState.scrap)
			if not bool(chk["ok"]):
				count("bench_blocked: " + str(chk["reason"]).left(24))
				break
			ui.select_weapon(slot2)
			var choices: Array = WeaponUpgrades.next_choices(inst)
			if not choices.is_empty():
				ui.choose_perk(str(choices[0]))
			var err: String = ui.confirm()
			if err != "":
				bot._anomaly("BENCH_REFUSED", "floor %d: the bench said ok (%s) but refused: %s" % [WorldState.current_floor, str(chk), err])
				break
			count("bench_upgrades")
			bot._event("BENCH", "floor %d: %s is now level %d" % [WorldState.current_floor, inst.get_display_name(), inst.level])
	# 3. spend the tuning points
	for inst in order:
		var slot3: int = WorldState.inventory.find(inst)
		if slot3 < 0 or WeaponUpgrades.points_free(inst) <= 0:
			continue
		ui.select_weapon(slot3)
		for stat_id in WeaponUpgrades.stats_for(inst.item_id):
			var guard := 0
			while WeaponUpgrades.points_free(inst) - _staged_points(ui) > 0 and guard < 6:
				guard += 1
				var before: int = _staged_points(ui)
				ui.stage_point(str(stat_id), 1)
				if _staged_points(ui) == before:
					break
		if _staged_points(ui) > 0:
			var terr: String = ui.set_tuning()
			if terr != "":
				bot._anomaly("TUNE_REFUSED", "floor %d: tuning refused: %s" % [WorldState.current_floor, terr])
			else:
				count("bench_tuned")
	count("bench_scrap_spent", maxi(0, scrap_in - WorldState.scrap))


func _staged_points(ui) -> int:
	var n := 0
	for k in ui.staged:
		n += int(ui.staged[k])
	return n


## The looter's state in one line (the bot's --trace prints it with every status line).
func state_line() -> String:
	var bits: Array = ["mode=" + mode, "floor_n=%d" % floor_n, "in_room=%s" % str(in_room)]
	if cur_door != null and is_instance_valid(cur_door):
		bits.append("door=%s stage=%s state=%s near=%s t=%.0f" % [str(cur_door.apartment_id), door_stage, _state_name(int(cur_door.current_state)), str(cur_door.player_nearby), door_t])
	bits.append("done=%s" % str(done.keys()))
	return " ".join(bits)


## What the player and the dead around it are doing, in one line (quoted by the hang anomalies so a stuck case explains itself).
func diag(p) -> String:
	var zs: Array = []
	for z in bot._zombies(p, 200.0):
		zs.append("%s@%d:%s%s" % [bot._type_of(z), int(z.global_position.x), str(z.get("state")), "(solid)" if z.collision_layer & 1 != 0 else ""])
	var sv: Array = []
	for n in bot.get_tree().get_nodes_in_group("survivor"):
		if is_instance_valid(n) and absf(n.global_position.x - p.global_position.x) < 160.0:
			sv.append("%s@%d:%s" % [str(n.get("kind")), int(n.global_position.x), str(n.get("behaviour"))])
	var rs: Array = []
	for n in bot.get_tree().get_nodes_in_group("resident_npc"):
		if is_instance_valid(n) and absf(n.global_position.x - p.global_position.x) < 300.0:
			rs.append("%s@%d:%s%s%s" % [str(n.get("temper")), int(n.global_position.x), str(n.get("state")), "(violent)" if n.get("violent") == true else "", "(dead)" if n.get("is_dead") == true else ""])
	var hits: Array = []
	for i in p.get_slide_collision_count():
		var c = p.get_slide_collision(i)
		var o = c.get_collider()
		hits.append("%s@%d[%s,layer%d]" % [str(o.name) if o != null else "?", int(o.global_position.x) if o is Node2D else -1, str(o.get_script().resource_path.get_file()) if o != null and o.get_script() != null else "-", int(o.collision_layer) if o is CollisionObject2D else -1])
	return "atk=%s(cd=%.2f) dying=%s escaping=%s pack=%s lash=%s slide=%s unjam=%.2f phased=%d x=%d y=%d vel=(%d,%d) target=%s(%d) back=%s switching=%s attacking=%s pushing=%s cutscene=%s listening=%s crouch=%s keys=%s zombies=%s survivors=%s residents=%s talk_claim=%s guard=%s" % [
		str(p.is_attacking), float(p.attack_cooldown_timer), str(p.is_dying), str(p.escaping), str(p.pack_phase), str(p.is_lashing), str(hits), float(p._stuck_time), p._phased_bodies.size(), int(p.global_position.x), int(p.global_position.y), int(p.velocity.x), int(p.velocity.y), str(p.has_move_target), int(p.move_target_x),
		str(p.back_spot != null), str(p.is_switching_mode), str(p.is_attacking), str(p.is_pushing), str(p.is_cutscene), str(p.is_listening), str(p.is_crouching),
		str(bot._kb), str(zs), str(sv), str(rs), str(WorldState.interact_claimed_by_talk()), str(TutorialManager.interact_guarded())]


## The room's way out (the Area2D with door_open.gd), or null.
func exit_node(room: Node):
	var ex = null
	for n in room.get_children():
		if n is Area2D and n.get_script() != null and str(n.get_script().resource_path).ends_with("door_open.gd"):
			ex = n
	return ex


## COVERAGE: leave a flat by its balcony (W steps out, W again goes over the rail — a rope, 3 clothes, or a second press to jump).
## Used by the `god` configuration a few times a character; the apartment it lands in is looted like any other.
func _balcony_exit(p, room: Node) -> bool:
	if not bot.balcony_mode or room_kind_is_maint(room) or _balcony_used >= 3 or exit_t > 45.0:
		return false
	var best = null
	var best_dx := 1e9
	for z in room.find_children("*", "Area2D", true, false):
		if z.get_script() != null and str(z.get_script().resource_path).ends_with("balcony_zone.gd") and WorldState.is_balcony_descendable(str(z.apartment_id), int(z.slot)):
			var dxz := absf(z.global_position.x - p.global_position.x)
			if dxz < best_dx:
				best_dx = dxz
				best = z
	if best == null:
		_balcony_wanted = false
		return false
	_balcony_wanted = true
	_balcony_t -= bot.dt
	if not p.on_balcony_plane:
		if best_dx > 12.0:
			_walk_to(p, best.global_position.x)
			return true
		bot._walk(0.0)
		if _balcony_t <= 0.0 and not bot.is_player_busy(p):
			_balcony_t = 1.2
			WorldState.interaction_handled = false
			bot.tap("move_up")
			count("balcony_steps_out")
			tlog("balcony: W (step out) at x=%d zone x=%d" % [int(p.global_position.x), int(best.global_position.x)])
		return true
	bot._walk(0.0)
	if _balcony_t <= 0.0 and not bot.is_player_busy(p) and not p.is_lashing:
		_balcony_t = 1.0
		_next_room_door = "balcony"
		_balcony_used_pending = true
		bot.tap("move_up")
		count("balcony_descent_presses")
		tlog("balcony: W (over the rail) lashing=%s cutscene=%s rope=%s" % [str(p.is_lashing), str(p.is_cutscene), str(WorldState.has_descent_rope())])
	return true


func _has_balcony(room: Node) -> bool:
	for z in room.find_children("*", "Area2D", true, false):
		if z.get_script() != null and str(z.get_script().resource_path).ends_with("balcony_zone.gd") and WorldState.is_balcony_descendable(str(z.apartment_id), int(z.slot)):
			return true
	return false


func room_kind_is_maint(room: Node) -> bool:
	return str(room.scene_file_path).ends_with("/maintenance.tscn")


func _exit_room(p, room: Node) -> void:
	exit_t += bot.dt
	_leave_panel()
	bot.want_scav = false
	if p.back_spot != null and not bot.is_player_busy(p) and not p.on_balcony_plane:
		p.call("exit_back_plane", false)
		return
	if _balcony_exit(p, room):
		return
	var ex = exit_node(room)
	if ex == null:
		if exit_t > 20.0:
			bot._anomaly("NO_EXIT", "floor %d %s: no exit trigger found in the room" % [WorldState.current_floor, room_id])
		return
	if exit_t > 60.0:
		bot._anomaly("EXIT_HUNG", "floor %d %s: could not leave in 60 s (exit x=%d) %s" % [WorldState.current_floor, room_id, int(ex.global_position.x), diag(p)])
		exit_t = 0.0
		_exit_hangs += 1
		if _exit_hangs >= 3:
			# three minutes of trying: this is a real softlock — end the character here, with the picture of it
			var why := "could not leave %s in %d s: %s" % [room_id, 180, diag(p)]
			bot.run_rec["stuck"] = {"floor": WorldState.current_floor, "why": why}
			bot.floor_rec["stuck"] = true
			bot._event("STUCK", "floor %d: %s" % [WorldState.current_floor, why])
			bot._finish_run("stuck", why)
			return
	_walk_to(p, ex.global_position.x)
	if _room_rec.get("ended", "") == "":
		_room_rec["ended"] = "left"


## The scene changed back to the corridor: close the visit.
func left_room() -> void:
	if in_room:
		_finish_room(_room_rec.get("ended", "left") if not _room_rec.is_empty() else "left")
