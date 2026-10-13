class_name Quests
extends RefCounted

# THE QUEST FRAMEWORK (owner round 39: "let's start on quest mechanics"; docs/QUESTS.md). Quests are DATA
# (data/quests.json — states, lines, choices, effects, and what the place looks like in later runs); this file is
# the small engine that runs them. The words are placeholders the owner rewrites; the MECHANICS here are real:
#
#   • A quest has a giver standing somewhere sensible (a corridor post, or a flat you can walk into), seeded once
#     per playthrough (`site`) and stable across all three runs.
#   • Talking to the giver starts the quest (a banner, a journal entry) and offers CHOICES. A choice may need
#     bullets or an item and runs EFFECTS: take them, hand over a gun, grant an upgrade, end someone's misery, set
#     the outcome, complete the quest.
#   • What you did is REMEMBERED across the arc (WorldState.quests, saved): later runs find the place changed by
#     the outcome — a turned couple, a mourner, a body and a revolver (`world`).
#   • A giver can die (a zombie, a bad fight): the quest turns to its `on_giver_died` state and stays there.
#
#   • A choice can be a PAYMENT IN INSTALMENTS (`pay`, owner round 41 — "keep it at 10 and 20 but the bullets can carry over"):
#     whatever bullets the player hands over are added to a LEDGER that lives in the quest's state, so it survives the time skips
#     and all three characters; the choice's `do` runs the moment the goal is met, and until then the giver just says how many
#     are still owed. The bullets are always his once handed over — if the reward does not fit the pockets it WAITS for them.
#
# State lives in WorldState.quests[qid] = {started, stage, outcome, done, flags, ledger, site}; string keys only.

const FILE := "res://data/quests.json"
## Upgrades only quests grant. Same shape as WorldState.UPGRADE_POOL mods, folded by WorldState._stat_mods_sources.
const UPGRADES := {
	"Q_refund": {"name": "Waste Not", "desc": "A shot has a 20% chance not to use up a round.", "mods": {"gun_refund": {"add": 0.20}}},
	"Q_crit":   {"name": "Johnny's Eye", "desc": "+10% chance to land a headshot.", "mods": {"headshot_bonus": {"add": 0.10}}},
}
const GUN_PRESETS := {
	# "high-durability gun" (quest 010): a Durable Hand Cannon, full of rounds.
	"johnny":   {"item": "004", "perks": ["G_durable"], "level": 2, "rounds": 6},
	# Ethel's revolver (quest 001): five of six bullets, the same sort of tough gun.
	"revolver": {"item": "004", "perks": ["G_durable"], "level": 2, "rounds": 5},
}
const MERCHANT_FLOORS_CLEAR := true            # corridor quests keep off a merchant's floor
const FIRE_CLEARANCE := 3                      # a quest's floor keeps this far from any seeded fire origin …
const FIRE_CLEARANCE_STEPS := [3, 2, 1]        # … relaxing in these steps when that leaves no floor (never below 1: two floors clear)
const POSTS := {"left": 335.0, "right": 1005.0}
const TALK_HOLD := 14.0                        # how long a conversation bubble stays up

static var _defs: Dictionary = {}


# --- data ----------------------------------------------------------------------------------------

static func defs() -> Dictionary:
	if _defs.is_empty() and FileAccess.file_exists(FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if parsed is Dictionary:
			for k in parsed:
				if not str(k).begins_with("_"):
					_defs[k] = parsed[k]
	return _defs


static func ids() -> Array:
	return defs().keys()


static func def(qid: String) -> Dictionary:
	return defs().get(qid, {})


# --- state ---------------------------------------------------------------------------------------

## The quest's saved state (created on first ask).
static func state_of(qid: String) -> Dictionary:
	var all: Dictionary = WorldState.quests
	if not all.has(qid):
		all[qid] = {"started": false, "stage": str(def(qid).get("start", "offer")), "outcome": "", "done": false, "flags": {}, "ledger": {}, "site": {}}
	var st: Dictionary = all[qid]
	if not st.has("ledger"):
		st["ledger"] = {}                 # (a save from before the ledger)
	return st


## How much of an instalment goal the player has already handed over (bullets), across every run so far.
static func ledger_paid(qid: String, name: String) -> int:
	return int(state_of(qid)["ledger"].get(name, 0))


static func started(qid: String) -> bool:
	return bool(state_of(qid).get("started", false))


static func stage(qid: String) -> String:
	return str(state_of(qid).get("stage", ""))


static func outcome(qid: String) -> String:
	return str(state_of(qid).get("outcome", ""))


static func completed(qid: String) -> bool:
	return bool(state_of(qid).get("done", false))


static func flag(qid: String, name: String) -> bool:
	return bool(state_of(qid)["flags"].get(name, false))


static func set_flag(qid: String, name: String, v: bool = true) -> void:
	state_of(qid)["flags"][name] = v


static func state_def(qid: String, st: String) -> Dictionary:
	return def(qid).get("states", {}).get(st, {})


static func _run_key() -> String:
	return str(clampi(WorldState.current_run, 1, 3))


# --- where it happens ----------------------------------------------------------------------------

## The quest's place: {floor, apt} for a flat, {floor, post, post_kind} for a corridor. Chosen once per playthrough
## (seeded on the master seed), pinned in the quest's state. {} = nowhere suitable.
## It keeps well clear of the building's fires (FIRE_CLEARANCE floors from any outbreak origin) — but fire origins are
## common enough (~12% of floors) that two of them can rule out a whole 10-floor band, which silently dropped the quest
## from ~1 playthrough in 9 (tools/npc_balance_report.tscn `quests`). So the clearance relaxes in steps
## (FIRE_CLEARANCE_STEPS) rather than giving up; the last step still keeps two floors from an origin, where the worst a
## later run does is a LIGHT fire.
static func site(qid: String) -> Dictionary:
	var st := state_of(qid)
	if not st["site"].is_empty():
		return st["site"]
	var d := def(qid)
	var band: Array = d.get("floors", [10, 20])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "questsite" + qid)
	rng.randi()
	var cands: Array = []
	for f in range(int(band[0]), int(band[1]) + 1):
		cands.append(f)
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = cands[i]
		cands[i] = cands[j]
		cands[j] = t
	for clearance in FIRE_CLEARANCE_STEPS:
		for f in cands:
			if f in WorldState.MERCHANT_FLOORS or _fire_near(f, int(clearance)):
				continue
			if str(d.get("kind", "")) == "flat":
				WorldState.seed_floor_door_states(f)               # pins which flats are OPEN (they stay open all arc)
				for col in range(1, 6):
					var apt := "%d%02d" % [f, col]
					if WorldState.get_door_state(apt) == WorldState.DoorState.OPEN:
						st["site"] = {"floor": f, "apt": apt}
						return st["site"]
			else:
				var kind := "stairs" if rng.randf() < 0.5 else "door"
				var post: float
				if kind == "stairs":
					post = float(POSTS[WorldState.stair_down_side(f)])
				else:
					post = float(WorldState.APARTMENT_X[1 + rng.randi() % 5]) + (-1.0 if rng.randf() < 0.5 else 1.0) * SurvivorPlan.DOOR_POST_OFFSET
				st["site"] = {"floor": f, "post": post, "post_kind": kind}
				return st["site"]
	return {}


static func _fire_near(f: int, clearance: int = FIRE_CLEARANCE) -> bool:
	for k in range(-clearance, clearance + 1):
		if WorldState._fire_origin_seeded(f + k):
			return true
	return false


## Is this flat some quest's flat? (The hider roll and the ordinary zombie spawn keep out of it.)
static func is_quest_flat(apt: String) -> bool:
	if not WorldState.survivor_rule:
		return false                 # the quests' people live under the survivor rule (WorldState.survivor_rule)
	for qid in ids():
		if str(def(qid).get("kind", "")) == "flat" and str(site(qid).get("apt", "")) == apt:
			return true
	return false


static func quest_for_flat(apt: String) -> String:
	if not WorldState.survivor_rule:
		return ""
	for qid in ids():
		if str(def(qid).get("kind", "")) == "flat" and str(site(qid).get("apt", "")) == apt:
			return qid
	return ""


# --- the people ----------------------------------------------------------------------------------

static func _npc_key(qid: String, npc: String) -> String:
	return "q:%s:%s:r%d" % [qid, npc, WorldState.current_run]


## A survivor record for one of a quest's people this run (settled in WorldState.survivors so its hp / death persist).
static func npc_record(qid: String, npc: String, x: float, post: float, extra: Dictionary = {}) -> Dictionary:
	var key := _npc_key(qid, npc)
	var all: Dictionary = WorldState.survivors
	if all.has(key) and not all[key].get("none", false):
		var r: Dictionary = all[key]
		if extra.has("mood"):
			r["mood"] = extra["mood"]
		return r
	var d := def(qid)
	var tpl: Dictionary = d.get("npc", {}) if d.has("npc") else d.get("npcs", {}).get(npc, {})
	var role: String = str(tpl.get("role", "defender"))
	var hp: int = int(tpl.get("hp", SurvivorPlan.HP.get(role, 4)))
	var rec := {
		"key": key, "role": role, "floor": int(site(qid).get("floor", 0)), "apt": str(site(qid).get("apt", "")),
		"look": int(tpl.get("look", 1)), "weapon": str(tpl.get("weapon", "")), "ammo": int(tpl.get("ammo", 0)),
		"gift": "", "gift_n": 0, "hp": hp, "max_hp": hp, "dead": false, "x": -1.0, "post": post, "post_kind": "quest",
		"spot": 0.5, "met": 0, "aided": false, "calm": false, "gave": false, "quest": qid, "npc": npc,
		"name": str(tpl.get("name", npc)), "mood": "",
	}
	for k in extra:
		rec[k] = extra[k]
	if x >= 0.0:
		rec["x"] = x
	all[key] = rec
	return rec


## A corridor quest's giver for this floor this run ([] = none). Dead stays dead for the run; a giver who died in an
## EARLIER run (the quest is `lost`) is simply gone.
static func corridor_records(floor_num: int) -> Array:
	var out: Array = []
	if not WorldState.survivor_rule:
		return out
	for qid in ids():
		var d := def(qid)
		if str(d.get("kind", "")) != "corridor":
			continue
		var s := site(qid)
		if s.is_empty() or int(s.get("floor", -1)) != floor_num:
			continue
		var key := _npc_key(qid, "giver")
		if stage(qid) == str(d.get("on_giver_died", "")) and not WorldState.survivors.has(key):
			continue
		out.append(npc_record(qid, "giver", -1.0, float(s["post"])))
	return out


## Lay a quest flat's people, dead and drops (room.gd, in place of the ordinary zombies). Returns the survivors spawned.
static func populate_flat(room: Node, apt: String, entrance_side: String) -> Array:
	var qid := quest_for_flat(apt)
	var spawned: Array = []
	if qid == "":
		return spawned
	var d := def(qid)
	var run := WorldState.current_run
	var far_mod := 2 if entrance_side == "left" else 0
	var base_x: float = float(room.LEFT_WALL_X) + far_mod * float(room.MODULE_WIDTH) + 120.0
	var specs: Array = []
	if run <= 1:
		for npc in d.get("npcs", {}):
			specs.append({"npc": npc})
	else:
		var table: Dictionary = d.get("world", {})
		var by_outcome: Dictionary = table.get(outcome(qid), table.get("", {}))
		specs = by_outcome.get(str(clampi(run, 1, 3)), [])
	var zi := 0
	for spec in specs:
		if spec.has("npc"):
			var npc: String = str(spec["npc"])
			var dx: float = float(d.get("npcs", {}).get(npc, {}).get("dx", 0.0))
			var extra := {}
			if spec.has("mood"):
				extra["mood"] = str(spec["mood"])
			var rec := npc_record(qid, npc, base_x + dx, base_x + dx, extra)
			if spec.has("mood"):
				rec["mood"] = str(spec["mood"])
			spawned.append(Survivor.spawn(room, rec, room.ROOM_FEET_Y, base_x + dx))
		elif spec.has("body"):
			var npc2: String = str(spec["body"])
			var dx2: float = float(d.get("npcs", {}).get(npc2, {}).get("dx", 0.0))
			var rec2 := npc_record(qid, npc2, base_x + dx2, base_x + dx2, {})
			rec2["dead"] = true
			rec2["hp"] = 0
			spawned.append(Survivor.spawn(room, rec2, room.ROOM_FEET_Y, base_x + dx2))
		elif spec.has("zombies"):
			var n: int = int(spec["zombies"])
			var zkey: String = str(spec.get("key", "z"))
			for i in n:
				var skey := "q:%s:%s:%d" % [qid, zkey, i]
				if flag(qid, "slain:" + skey) or WorldState.killed_zombies.has(skey):
					continue
				var z = preload("res://scenes/enemy_zombie_standard.tscn").instantiate()
				z.position = Vector2(base_x + 30.0 + 44.0 * i, room.ROOM_STD_ORIGIN_Y)
				z.spawn_key = skey
				room.add_child(z)
				WorldState.apply_saved_zombie(z)
		elif spec.has("drop") or spec.has("gun"):
			var dkey: String = "dropped:" + str(spec.get("key", "drop"))
			if flag(qid, dkey):
				continue
			set_flag(qid, dkey)
			var pos := Vector2(base_x + 18.0, room.ROOM_FEET_Y - 8.0)
			if spec.has("gun"):
				var gun := make_gun(str(spec["gun"]))
				WorldState.add_world_drop(gun.item_id, pos, WorldState.current_floor,
					{"instance": WorldState.instance_to_dict(gun), "scene": room._own_scene_path(), "apartment_id": apt})
			else:
				var item: String = str(spec["drop"])
				var inst := ItemInstance.new()
				inst.setup(item)
				if bool(spec.get("half", false)):
					inst.heal_scale = 0.5            # "half what it previously was" (quest 001): a health item heals half as much
				WorldState.add_world_drop(item, pos, WorldState.current_floor,
					{"instance": WorldState.instance_to_dict(inst), "scene": room._own_scene_path(), "apartment_id": apt})
	return spawned


## The quest's zombie that was killed this run is gone for good (the kill memory is wiped at the time skip).
static func settle_time_skip() -> void:
	for qid in ids():
		if str(def(qid).get("kind", "")) != "flat":
			continue
		for skey in WorldState.killed_zombies.keys():
			if str(skey).begins_with("q:%s:" % qid):
				set_flag(qid, "slain:" + str(skey))


# --- guns ----------------------------------------------------------------------------------------

static func make_gun(preset: String) -> ItemInstance:
	var p: Dictionary = GUN_PRESETS.get(preset, GUN_PRESETS["johnny"])
	var inst := ItemInstance.new()
	inst.setup(str(p["item"]))
	var base_max: int = inst.get_max_durability()
	inst.level = int(p["level"])
	inst.perks = p["perks"].duplicate()
	WorldState._apply_durability_headroom(inst, base_max)
	if inst.get_max_durability() > 0:
		inst.current_durability = inst.get_max_durability()
	inst.mag_count = mini(int(p["rounds"]), inst.get_mag_cap())
	return inst


# --- conversation --------------------------------------------------------------------------------

static func _lines_for(qid: String, st: String, who: Node) -> Array:
	var sd := state_def(qid, st)
	var lines = sd.get("lines", [])
	if lines is Dictionary:
		lines = lines.get(_run_key(), lines.get("1", []))
	# a mourner says her own line in the later run
	if str(who.get("rec").get("mood", "")) == "mourn":
		var m = def(qid).get("talk_mourn", {}).get(_run_key(), [])
		if m is Array and not m.is_empty():
			lines = m
	return lines if lines is Array else []


## [{label, enabled, hint}] for the current stage.
static func choices(qid: String) -> Array:
	var out: Array = []
	var sd := state_def(qid, stage(qid))
	for c in sd.get("choices", []):
		var ok := true
		var hint := ""
		var label := str(c.get("label", "…"))
		var need: Dictionary = c.get("need", {})
		if c.has("pay"):
			var pay: Dictionary = c["pay"]
			var goal := int(pay["ammo"])
			var paid := ledger_paid(qid, str(pay["ledger"]))
			var left := maxi(goal - paid, 0)
			if left <= 0 and str(pay.get("collect", "")) != "":
				label = str(pay["collect"])                       # paid in full: what is left is taking what is owed
			else:
				label = label.replace("{paid}", str(paid)).replace("{goal}", str(goal)).replace("{left}", str(left))
				if left > 0 and WorldState.get_ammo_total() < 1:
					ok = false
					hint = "no bullets"
		if need.has("ammo") and WorldState.get_ammo_total() < int(need["ammo"]):
			ok = false
			hint = "need %d bullets" % int(need["ammo"])
		if need.has("item") and not _has_item(str(need["item"])):
			ok = false
			hint = "need %s" % str(ItemData.get_item(str(need["item"])).get("name", "it"))
		out.append({"label": label, "enabled": ok, "hint": hint})
	return out


static func _has_item(id: String) -> bool:
	for it in WorldState.inventory:
		if it != null and it.item_id == id:
			return true
	return false


## The giver was talked to: start the quest if it hasn't been, say a line, offer the choices. Returns the line.
static func talk(who: Node) -> String:
	var qid: String = str(who.get("quest_id"))
	if qid == "" or def(qid).is_empty():
		return ""
	var st := state_of(qid)
	if not bool(st["started"]):
		st["started"] = true
		_banner("NEW QUEST", qid)
	var lines := _lines_for(qid, stage(qid), who)
	var line := ""
	if not lines.is_empty():
		line = str(lines[randi() % lines.size()])
	if line != "":
		who.say_text("quest", line, TALK_HOLD)
	who.show_choices(choices(qid))
	return line


## The player picked choice `idx`. Applies the effects; returns true if anything happened.
static func choose(who: Node, idx: int) -> bool:
	var qid: String = str(who.get("quest_id"))
	var sd := state_def(qid, stage(qid))
	var cs: Array = sd.get("choices", [])
	if idx < 0 or idx >= cs.size():
		return false
	var c: Dictionary = cs[idx]
	var shown := choices(qid)
	if idx >= shown.size() or not bool(shown[idx]["enabled"]):
		return false
	if c.has("pay"):
		return _pay(qid, c, who)
	var dos: Array = c.get("do", [])
	if dos.is_empty():
		who.hide_choices()                   # "Not now" / "Leave": nothing happens, the quest stays open
		return true
	# Everything the player has to hand over is checked BEFORE anything is taken (never half a trade): a gun or an
	# item they are to RECEIVE needs a slot — counting the slots the payment itself frees.
	var receives := 0
	for e in dos:
		if str(e).begins_with("give_gun:") or str(e).begins_with("give_item:"):
			receives += 1
	if receives > 0 and WorldState.inventory.size() - _slots_freed(dos) + receives > WorldState.get_inventory_slots():
		HUD.show_feedback("No room to carry it.")
		return false
	var before := stage(qid)
	for e in dos:
		_apply(qid, str(e), who)
	WorldState.sync_overload()
	HUD.refresh_inventory()
	who.hide_choices()
	if stage(qid) != before and not completed(qid):
		_banner("OBJECTIVE UPDATED", qid)
	# the new state speaks at once (and offers whatever it offers)
	var ls := _lines_for(qid, stage(qid), who)
	if not ls.is_empty():
		who.say_text("quest", str(ls[randi() % ls.size()]), TALK_HOLD)
	var more := choices(qid)
	if not more.is_empty():
		who.show_choices(more)
	return true


## A payment in instalments: hand over what you have toward the goal (never more than is owed); the ledger remembers it
## for the rest of the playthrough. The moment the goal is met the choice's `do` runs. The payment that would COMPLETE the
## goal is refused whole while the reward will not fit the pockets (nothing taken — see below), so a reward is never left
## waiting for whoever talks to the giver next; the `collect` label only serves a ledger that was completed before that rule.
static func _pay(qid: String, c: Dictionary, who: Node) -> bool:
	var pay: Dictionary = c["pay"]
	var ledger_name := str(pay["ledger"])
	var goal := int(pay["ammo"])
	var paid := ledger_paid(qid, ledger_name)
	var left := maxi(goal - paid, 0)
	var give := mini(WorldState.get_ammo_total(), left)
	if left > 0 and give <= 0:
		HUD.show_feedback("You have no bullets to give.")
		return false
	var completes: bool = give >= left
	var dos: Array = c.get("do", [])
	var receives := 0
	for e in dos:
		if str(e).begins_with("give_gun:") or str(e).begins_with("give_item:"):
			receives += 1
	var fits := true
	if completes and receives > 0:
		var freed := _slots_freed(["take_ammo:%d" % give]) if give > 0 else 0
		fits = WorldState.inventory.size() - freed + receives <= WorldState.get_inventory_slots()
	if completes and not fits:
		# Never half a trade, and no reward left waiting on the counter (owner round 42: "rewarding someone's death with a free weapon
		# isn't what we do" — a gun paid for but not yet collected would go to the next character if this one died first). The final
		# instalment is refused WHOLE, bullets and all, until the reward fits.
		HUD.show_feedback("No room to carry it — make space and come back.")
		return false
	if give > 0:
		WorldState.consume_ammo(give)
		state_of(qid)["ledger"][ledger_name] = paid + give
		HUD.show_feedback("You hand over %d bullet%s." % [give, "" if give == 1 else "s"])
	var before := stage(qid)
	if completes:
		for e in dos:
			_apply(qid, str(e), who)
	WorldState.sync_overload()
	HUD.refresh_inventory()
	who.hide_choices()
	if stage(qid) != before and not completed(qid):
		_banner("OBJECTIVE UPDATED", qid)
	if stage(qid) != before:
		var ls := _lines_for(qid, stage(qid), who)       # the new state speaks at once
		if not ls.is_empty():
			who.say_text("quest", str(ls[randi() % ls.size()]), TALK_HOLD)
	elif not completes:
		var more := str(pay.get("more", ""))             # still short: how many are owed
		if more != "":
			who.say_text("quest", more.replace("{left}", str(left - give)).replace("{paid}", str(paid + give)).replace("{goal}", str(goal)), TALK_HOLD)
	var again := choices(qid)
	if not again.is_empty():
		who.show_choices(again)
	return true


## How many inventory slots the `take_*` effects among `dos` would empty (bullets stack; an emptied stack frees its slot).
static func _slots_freed(dos: Array) -> int:
	var freed := 0
	for e in dos:
		var parts := str(e).split(":", true, 2)
		if parts[0] == "take_item":
			freed += 1
		elif parts[0] == "take_ammo":
			var remaining := int(parts[1])
			for i in range(WorldState.inventory.size() - 1, -1, -1):
				if remaining <= 0:
					break
				var it = WorldState.inventory[i]
				if ItemData.get_item(it.item_id).get("is_ammo", false):
					if it.count <= remaining:
						freed += 1
					remaining -= mini(it.count, remaining)
	return freed


static func _apply(qid: String, effect: String, who: Node) -> void:
	var parts := effect.split(":", true, 2)
	var verb := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	var arg2 := parts[2] if parts.size() > 2 else ""
	match verb:
		"take_ammo":
			WorldState.consume_ammo(int(arg))
		"take_item":
			for i in WorldState.inventory.size():
				if WorldState.inventory[i] != null and WorldState.inventory[i].item_id == arg:
					WorldState.remove_from_inventory(i)
					if HUD.selected_slot == i:
						HUD.selected_slot = -1
					elif HUD.selected_slot > i:
						HUD.selected_slot -= 1
					break
		"give_item":
			WorldState.add_to_inventory(arg, int(arg2) if arg2 != "" else 0)
		"give_gun":
			var gun := make_gun(arg)
			if WorldState.add_instance_to_inventory(gun):
				HUD.show_feedback("%s hands you a gun." % str(who.get("rec").get("name", "They")))
		"upgrade":
			if arg in UPGRADES and not (arg in WorldState.quest_upgrades):
				WorldState.quest_upgrades.append(arg)
				HUD.show_feedback("%s — %s" % [UPGRADES[arg]["name"], UPGRADES[arg]["desc"]])
		"kill":
			_kill_npc(qid, arg, who)
		"outcome":
			state_of(qid)["outcome"] = arg
		"complete":
			if not completed(qid):
				state_of(qid)["done"] = true
				WorldState.note_quest_completed()
				_banner("QUEST COMPLETE", qid)
		"banner":
			HUD.show_feedback(arg)
		"flag":
			set_flag(qid, arg)
		"goto":
			state_of(qid)["stage"] = arg


static func _kill_npc(qid: String, npc: String, who: Node) -> void:
	for s in who.get_tree().get_nodes_in_group("survivor"):
		if is_instance_valid(s) and str(s.get("rec").get("quest", "")) == qid and str(s.get("rec").get("npc", "")) == npc:
			s.mercy_kill()
			return


static func _banner(kicker: String, qid: String) -> void:
	var d := def(qid)
	var objective: String = str(state_def(qid, stage(qid)).get("journal", ""))
	if HUD != null and HUD.has_method("show_quest_banner"):
		HUD.show_quest_banner(kicker, str(d.get("title", qid)), objective)


# --- events --------------------------------------------------------------------------------------

## Is this record the one the player TALKS to (the quest's giver)? The other people of a quest are scenery to its talk.
static func is_giver(rec: Dictionary) -> bool:
	var qid: String = str(rec.get("quest", ""))
	if qid == "" or def(qid).is_empty():
		return false
	return str(rec.get("npc", "giver")) == str(def(qid).get("giver", "giver"))


## A quest's giver cannot be KILLED before the player has spoken to them: the dead can wound them (they fall back and
## tend it) but never finish them. Measured: with the player merely standing on his floor, Johnny was dead within 90 s on
## ~37% of real floors (tools/npc_balance_report.tscn `johnny`) — the quest lost before it was ever offered. Once the first
## conversation has happened (`started`) they are as mortal as anyone. `"protected_until_met": false` in the data opts out.
static func protects(rec: Dictionary) -> bool:
	if not is_giver(rec):
		return false
	var qid: String = str(rec.get("quest", ""))
	return bool(def(qid).get("protected_until_met", true)) and not started(qid)


## A survivor died (any cause). If it was a quest's giver, the quest turns to its `on_giver_died` state for good.
static func on_survivor_died(rec: Dictionary) -> void:
	var qid: String = str(rec.get("quest", ""))
	if qid == "" or def(qid).is_empty():
		return
	var d := def(qid)
	var npc: String = str(rec.get("npc", ""))
	var giver: String = str(d.get("giver", "giver"))
	if npc != giver:
		return
	var dead_stage: String = str(d.get("on_giver_died", "lost"))
	if completed(qid) or stage(qid) == dead_stage:
		return
	state_of(qid)["stage"] = dead_stage
	if started(qid):
		_banner("QUEST FAILED", qid)


# --- the journal ---------------------------------------------------------------------------------

## " (4 of 10 bullets given)" for a state that is waiting on a payment; "" otherwise.
static func progress_text(qid: String) -> String:
	for c in state_def(qid, stage(qid)).get("choices", []):
		if c.has("pay"):
			var goal := int(c["pay"]["ammo"])
			var paid := ledger_paid(qid, str(c["pay"]["ledger"]))
			if paid < goal:
				return "  (%d of %d bullets given)" % [paid, goal]
	return ""


## [{title, number, objective, done, failed}] for every quest the player has begun.
static func journal_entries() -> Array:
	var out: Array = []
	for qid in ids():
		if not started(qid):
			continue
		var d := def(qid)
		var st := stage(qid)
		out.append({
			"id": qid, "title": str(d.get("title", qid)), "number": str(d.get("number", "")),
			"objective": str(state_def(qid, st).get("journal", "")) + progress_text(qid),
			"done": completed(qid), "failed": st == str(d.get("on_giver_died", "")) and not completed(qid),
		})
	return out
