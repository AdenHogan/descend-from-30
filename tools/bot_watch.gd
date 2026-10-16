extends RefCounted

# THE WATCHER (owner round 44 — "a complete test to check for balance and errors/problems"). While the bot plays it keeps two kinds of
# books:
#   (1) the ENGINE'S OWN ERROR LOG, captured as it happens with the context the bot knows (floor, scene, what it was doing) — a
#       `SCRIPT ERROR` that scrolls past in a log nobody reads becomes a line in the report. (OS.add_logger, Godot 4.5+.)
#   (2) INVARIANTS the game must always satisfy, checked twice a second of game time: nothing in the bag that cannot be, no negative
#       money, a floor scene that matches the floor counter, a player standing on the plane, no stuck pause / transition / loot panel,
#       and a PROGRESS watchdog that classifies "nothing happened for 30 s" (a softlock that is not a hang).
# Nothing here changes the game. Every finding goes through `bot._anomaly(kind, msg)`, de-duplicated by kind + text so a stuck state
# is reported once with a count, not once a frame.

const PLANE_Y_CORRIDOR := 386.0
const CHECK_EVERY := 0.5
const STUCK_AFTER := 30.0

## Collects every engine error / warning / script error on any thread; drained by the watcher on the main thread.
class ErrLog extends Logger:
	var mutex := Mutex.new()
	var items: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, backtraces: Array[ScriptBacktrace]) -> void:
		var bt := ""
		for b in backtraces:
			bt += b.format(0, 4) + " | "
		mutex.lock()
		if items.size() < 400:
			items.append({"fn": function, "file": file, "line": line, "code": code, "msg": rationale, "type": error_type, "trace": bt.left(700)})
		mutex.unlock()

	func drain() -> Array:
		mutex.lock()
		var out := items.duplicate()
		items.clear()
		mutex.unlock()
		return out


var bot
var errlog: ErrLog = null
var _clock: float = 0.0
var seen: Dictionary = {}                  # "kind|text" -> count (every repeat, reported or not)
var engine_errors: Array = []              # {sig, count, file, line, msg, first_t, floor, scene, kind} — one per distinct engine error
var _eng_index: Dictionary = {}
var checks_run: int = 0
var counters: Dictionary = {}              # what the watcher saw (coverage of the watcher itself)

# --- invariant state ---
var _floor_mismatch_t: float = 0.0
var _plane_t: float = 0.0
var _pause_t: float = 0.0
var _trans_t: float = 0.0
var _loot_ghost_t: float = 0.0
var _prog_sig: String = ""
var _prog_t: float = 0.0
var _prog_reported: bool = false
var stall_trace: int = 0                   # physics frames of per-frame detail still to print after a NO_PROGRESS (the bot prints them)
var _nan_reported: Dictionary = {}
var _cast0: Array = []


func _init(b = null) -> void:
	bot = b
	errlog = ErrLog.new()
	OS.add_logger(errlog)


func detach() -> void:
	if errlog != null:
		OS.remove_logger(errlog)
		errlog = null


func bump(key: String, n: int = 1) -> void:
	counters[key] = int(counters.get(key, 0)) + n


## Called every physics tick by the bot with the player (may be null) and the bot's current activity text.
func tick(p, dt: float, activity: String) -> void:
	_clock += dt
	_drain_engine_errors()
	if _clock < CHECK_EVERY:
		return
	var step := _clock
	_clock = 0.0
	checks_run += 1
	_check_state(step)
	if p != null:
		_check_player(p, step)
	_check_progress(p, step, activity)


# ----------------------------------------------------------------------------- engine log

func _drain_engine_errors() -> void:
	if errlog == null:
		return
	for e in errlog.drain():
		var file: String = str(e["file"])
		var msg: String = str(e["msg"]) if str(e["msg"]) != "" else str(e["code"])
		var sig := "%s:%d|%s" % [file, int(e["line"]), msg.left(120)]
		var kind := "WARNING" if int(e["type"]) == 1 else ("SCRIPT_ERROR" if int(e["type"]) == 2 else "ENGINE_ERROR")
		var owner_of := "bot" if file.begins_with("res://tools/") else "game"
		if file.contains("rendering/dummy") or file.contains("/dummy/"):
			owner_of = "headless"                 # the renderer-less build has no textures to read back: not the game's fault
		if _eng_index.has(sig):
			var rec: Dictionary = _eng_index[sig]
			rec["count"] = int(rec["count"]) + 1
			continue
		var rec2 := {"sig": sig, "count": 1, "file": file, "line": int(e["line"]), "fn": str(e["fn"]), "msg": msg, "kind": kind, "owner": owner_of,
			"trace": str(e.get("trace", "")), "first_t": snappedf(bot.t, 0.1), "run": WorldState.current_run, "floor": WorldState.current_floor,
			"scene": str(bot.get_tree().current_scene.scene_file_path) if bot.get_tree().current_scene != null else "none"}
		_eng_index[sig] = rec2
		engine_errors.append(rec2)
		# warnings are kept in the report but are not anomalies; errors from the bot itself are marked so they are not blamed on the game
		if kind != "WARNING" and owner_of != "headless":
			bot._anomaly("%s_%s" % [kind, owner_of.to_upper()], "%s:%d in %s(): %s" % [file, int(e["line"]), str(e["fn"]), msg.left(200)])


# ----------------------------------------------------------------------------- invariants

func report(kind: String, msg: String, key: String = "") -> void:
	var sig := kind + "|" + (key if key != "" else msg.left(80))
	seen[sig] = int(seen.get(sig, 0)) + 1
	if int(seen[sig]) == 1:
		bot._anomaly(kind, msg)


func _check_state(step: float) -> void:
	# --- the bag ---
	var slots: int = WorldState.get_inventory_slots()
	var handed := 0                          # what the bot itself was given outside the slots (a crowbar at a barricade, a god-mode hammer)
	for gi in WorldState.inventory:
		if gi != null and gi.has_meta("bot_gift"):
			handed += 1
	if WorldState.inventory.size() > slots + handed and not WorldState.packless_rule:
		report("INV_OVERFULL", "floor %d: %d things in a %d-slot bag" % [WorldState.current_floor, WorldState.inventory.size(), slots])
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if inst == null:
			report("INV_NULL", "slot %d of the bag is null" % i, "null%d" % i)
			continue
		var id: String = str(inst.item_id)
		var d: Dictionary = ItemData.get_item(id)
		if d.is_empty():
			report("INV_UNKNOWN_ITEM", "slot %d holds an item id the catalogue does not know: '%s'" % [i, id], id)
			continue
		var mx: int = inst.get_max_durability()
		if mx > 0 and (inst.current_durability < 0 or inst.current_durability > mx + 2):
			report("INV_DURABILITY", "%s has durability %d (max %d)" % [d.get("name", id), inst.current_durability, mx], "dur" + id)
		if inst.count < 1:
			report("INV_COUNT", "%s has count %d" % [d.get("name", id), inst.count], "cnt" + id)
		if id == "004" and (inst.mag_count < 0 or inst.mag_count > 40):
			report("INV_MAG", "the gun's magazine reads %d" % inst.mag_count)
		if d.get("is_ammo", false) and inst.count > WorldState.MAX_AMMO_PER_SLOT:
			report("INV_AMMO_STACK", "ammo stack of %d (limit %d)" % [inst.count, WorldState.MAX_AMMO_PER_SLOT])
		if d.get("is_fuse", false) and inst.count > WorldState.MAX_FUSE_PER_SLOT:
			report("INV_FUSE_STACK", "fuse stack of %d (limit %d)" % [inst.count, WorldState.MAX_FUSE_PER_SLOT])
	# --- numbers ---
	if WorldState.wallet_balance < 0:
		report("NEG_WALLET", "wallet balance %d" % WorldState.wallet_balance)
	if WorldState.scrap < 0:
		report("NEG_SCRAP", "scrap %d" % WorldState.scrap)
	if WorldState.player_health < 0 or WorldState.player_health > 5:
		report("HEALTH_RANGE", "health stage %d" % WorldState.player_health)
	var mxs: float = WorldState.get_max_stamina()
	if is_nan(WorldState.stamina) or WorldState.stamina < -0.01 or WorldState.stamina > mxs + 0.5:
		report("STAMINA_RANGE", "stamina %.2f of %.2f" % [WorldState.stamina, mxs], "stamina")
	if WorldState.current_floor < 0 or WorldState.current_floor > 30:
		report("FLOOR_RANGE", "current_floor = %d" % WorldState.current_floor)
	if WorldState.current_run < 1 or WorldState.current_run > 3:
		report("RUN_RANGE", "current_run = %d" % WorldState.current_run)
	if WorldState.elevator_fuses_loaded < 0 or WorldState.elevator_fuses_loaded > WorldState.ELEVATOR_FUSES_NEEDED:
		report("FUSE_RANGE", "elevator_fuses_loaded = %d" % WorldState.elevator_fuses_loaded)
	# --- the characters of this playthrough never change (a rest / a pried barricade re-rolls the BUILDING, not the people) ---
	var cast_now: Array = WorldState.run_cast()
	if _cast0.is_empty():
		_cast0 = cast_now                     # (one bot process = one playthrough)
	elif cast_now != _cast0:
		report("CAST_CHANGED", "the run cast changed from %s to %s" % [str(_cast0), str(cast_now)])
	# --- the floor counter against the scene that is up ---
	var sc = bot.get_tree().current_scene
	if sc != null and str(sc.scene_file_path).ends_with("/building_floors.tscn") and not Transition.busy and not StairPan.panning:
		var built = sc.get("_built_floor")
		if built != null and int(built) >= 0 and int(built) != WorldState.current_floor:
			_floor_mismatch_t += step
			if _floor_mismatch_t > 1.5:
				report("FLOOR_MISMATCH", "WorldState.current_floor is %d but the corridor on screen was built for floor %d" % [WorldState.current_floor, int(built)])
		else:
			_floor_mismatch_t = 0.0
	else:
		_floor_mismatch_t = 0.0
	# --- pauses, fades and panels that should not outlast their cause ---
	if bot.get_tree().paused and not _legit_pause():
		_pause_t += step
		if _pause_t > 25.0:
			report("PAUSE_STUCK", "the tree has been paused 25 s with nothing open that explains it (scene %s)" % (str(sc.scene_file_path) if sc != null else "none"))
	else:
		_pause_t = 0.0
	if Transition.busy and bot.phase == "play":
		_trans_t += step
		if _trans_t > 45.0:
			report("TRANSITION_STUCK", "Transition.busy for 45 s")
	else:
		_trans_t = 0.0                     # (the end-of-run cards are long by design: the bot's phase is not "play" for those)
	if WorldState.loot_open:
		var visible_panel := false
		for ui in bot.get_tree().get_nodes_in_group("loot_ui"):
			if ui.visible:
				visible_panel = true
		if not visible_panel:
			_loot_ghost_t += step
			if _loot_ghost_t > 4.0:
				report("LOOT_OPEN_GHOST", "WorldState.loot_open is true with no loot panel showing for 4 s")
		else:
			_loot_ghost_t = 0.0
	else:
		_loot_ghost_t = 0.0
	# --- what the dead dropped: it must lie where a player can stand (the corridor's walkable span is x ~115..1235) ---
	if sc != null and bot._kind in ["corridor", "hallway", "lobby"] and bot.loot != null:
		for dn in bot.loot._drops(sc):
			var dxx: float = dn.global_position.x
			if (dxx < 112.0 or dxx > 1238.0) and str(dn.item_id) != "036":
				report("DROP_UNREACHABLE", "floor %d: a %s drop lies at x=%d, outside the walkable corridor (115..1235)" % [WorldState.current_floor, str(dn.item_id), int(dxx)], "drop%d_%s" % [WorldState.current_floor, str(dn.item_id)])
	# --- the dead ---
	var zs: Array = bot.get_tree().get_nodes_in_group("zombie")
	if zs.size() > 70:
		report("ENEMY_FLOOD", "%d bodies in the 'zombie' group" % zs.size())
	for z in zs:
		if is_instance_valid(z) and z is Node2D:
			var gp: Vector2 = z.global_position
			if is_nan(gp.x) or is_nan(gp.y) or absf(gp.x) > 20000.0 or absf(gp.y) > 20000.0:
				report("ENEMY_NAN", "an enemy is at %s" % str(gp), "enemynan")


func _legit_pause() -> bool:
	# the pausing screens the bot itself opens or walks through, and the game's own freezes (a teaching beat, a hazard warning)
	if bot._shop_state == "open" or (bot.loot != null and bot.loot.bench_open):
		return true
	if TutorialManager.get("_awaiting") == true:
		return true
	for n in HUD.get_children():
		if n is CanvasItem and n.visible and n.get_script() != null:
			var sp: String = str(n.get_script().resource_path)
			if sp.ends_with("intro_overlay.gd") or sp.ends_with("character_panel.gd") or sp.ends_with("choice_panel.gd") or sp.ends_with("workbench_ui.gd"):
				return true
	var sc = bot.get_tree().current_scene
	return sc == null or Transition.busy or WorldState.loot_open


func _check_player(p, step: float) -> void:
	var gp: Vector2 = p.global_position
	if is_nan(gp.x) or is_nan(gp.y) or absf(gp.x) > 20000.0 or absf(gp.y) > 20000.0:
		report("PLAYER_NAN", "the player is at %s" % str(gp))
		return
	var kind: String = bot._kind
	var busy: bool = p.is_cutscene or p.escaping or StairPan.panning or Transition.busy or p.back_spot != null
	if kind in ["corridor", "hallway", "lobby"] and not busy and p.get("on_balcony_plane") != true:
		if absf(gp.y - PLANE_Y_CORRIDOR) > 8.0:
			_plane_t += step
			if _plane_t > 1.5:
				report("PLANE_DRIFT", "floor %d: the player stands at y=%d (the corridor plane is %d), x=%d" % [WorldState.current_floor, int(gp.y), int(PLANE_Y_CORRIDOR), int(gp.x)], "plane%d" % WorldState.current_floor)
		else:
			_plane_t = 0.0
	else:
		_plane_t = 0.0
	if kind in ["room", "maint"] and gp.y > 520.0:
		report("FELL_THROUGH_FLOOR", "inside %s the player is at y=%d" % [bot.loot.room_id if bot.loot != null else "?", int(gp.y)])


## The progress watchdog: if nothing observable changes for STUCK_AFTER seconds while the bot is meant to be playing, say what it was doing.
func _check_progress(p, step: float, activity: String) -> void:
	if p == null or bot.phase != "play" or bot.get_tree().paused:
		_prog_t = 0.0
		_prog_reported = false
		return
	var sig := "%s|%s|%d|%d|%s|%d|%d|%s" % [str(bot.get_tree().current_scene.scene_file_path) if bot.get_tree().current_scene != null else "-",
		str(WorldState.current_floor), int(p.global_position.x / 14.0), int(p.global_position.y / 14.0),
		(bot.loot._inv_signature() if bot.loot != null else ""), WorldState.player_health, int(bot.run_rec.get("kills", 0)), str(WorldState.loot_open)]
	if sig != _prog_sig:
		_prog_sig = sig
		_prog_t = 0.0
		_prog_reported = false
		return
	_prog_t += step
	if _prog_t > STUCK_AFTER and not _prog_reported:
		_prog_reported = true
		stall_trace = 240
		report("NO_PROGRESS", "floor %d: nothing changed for %d s — %s :: %s" % [WorldState.current_floor, int(_prog_t), activity, (bot.loot.diag(p) if bot.loot != null else "")], "noprog%d" % WorldState.current_floor)


# ----------------------------------------------------------------------------- save / load fidelity

const FINGERPRINT_FIELDS := ["master_seed", "cast_seed", "current_floor", "current_run", "player_health", "is_dying", "rest_available", "rest_count",
	"anchor_items", "searched_anchors", "door_states", "door_keys_consumed", "killed_zombies", "world_drops", "player_corpses", "wallet_balance", "wallet_unlocked", "scrap",
	"active_upgrades", "visited_floors", "run_chronicle", "elevator_powered", "elevator_fuses_loaded", "stair_blocks_cleared", "havens", "survivors", "quests",
	"run_kills", "run_scavenged", "run_boons", "followed_away", "gun_cabinets", "residents", "revenants"]


## JSON turns every number into a float on the way back in, so 3 and 3.0 are the same value: compare values, not spellings
## (floats that are whole become ints; dictionaries are written with sorted keys; Vector2 and friends become their text).
func _norm(v):
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if is_equal_approx(v, roundf(v)) and absf(v) < 1.0e15 else snappedf(v, 0.0001)
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _norm(v[k])
			return d
		TYPE_ARRAY:
			var a: Array = []
			for e in v:
				a.append(_norm(e))
			return a
		TYPE_STRING, TYPE_INT, TYPE_BOOL, TYPE_NIL, TYPE_STRING_NAME:
			return v
		_:
			return str(v)


func _fingerprint() -> Dictionary:
	var out := {}
	for k in FINGERPRINT_FIELDS:
		out[k] = JSON.stringify(_norm(WorldState.get(k)), "", true)
	out["inventory"] = JSON.stringify(_norm(WorldState._serialize_inventory()), "", true)
	out["stamina"] = "%.1f" % WorldState.stamina
	return out


## Save the game as it stands, load it straight back, and say what changed. A faithful save changes nothing; anything that
## differs is state a player would lose or corrupt by quitting and continuing (the string-keys rule, a field missing from the file …).
func check_save_load(where: String) -> void:
	var sc = bot.get_tree().current_scene
	if sc == null:
		return
	bump("save_load_checks")
	var before := _fingerprint()
	var gifts: Array = []                     # the bot's own gifts are tags on the instances, which a load rebuilds: re-tag the same slots
	for gi in WorldState.inventory.size():
		if WorldState.inventory[gi] != null and WorldState.inventory[gi].has_meta("bot_gift"):
			gifts.append(gi)
	WorldState.save_game(str(sc.scene_file_path), false)
	var path: String = WorldState.slot_save_path()
	if not FileAccess.file_exists(path):
		report("SAVE_MISSING", "%s: save_game wrote no file at %s" % [where, path])
		return
	if JSON.parse_string(FileAccess.get_file_as_string(path)) == null:
		report("SAVE_INVALID_JSON", "%s: the save file does not parse" % where)
		return
	if WorldState.load_game() == "":
		report("LOAD_FAILED", "%s: load_game returned nothing for the file it had just written" % where)
		return
	for gi in gifts:
		if gi < WorldState.inventory.size():
			WorldState.inventory[gi].set_meta("bot_gift", true)
	var after := _fingerprint()
	var diffs: Array = []
	for k in before:
		if before[k] != after.get(k, ""):
			diffs.append(k)
	if not diffs.is_empty():
		report("SAVE_LOAD_DRIFT", "%s: after save + load these fields differ: %s (first: %s -> %s)" % [where, ", ".join(PackedStringArray(diffs)), str(before[diffs[0]]).left(120), str(after.get(diffs[0], "")).left(120)], "drift:" + ",".join(PackedStringArray(diffs)))


# ----------------------------------------------------------------------------- summary

func summary() -> Dictionary:
	return {"checks": checks_run, "counters": counters, "seen": seen, "engine_errors": engine_errors}
