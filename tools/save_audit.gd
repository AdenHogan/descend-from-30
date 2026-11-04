extends Node

# SAVE AUDIT — loads a real save file into the real game code and prints what the building HELD against what the player MET, plus what the player's
# kit does against it. Read-only: it works on a copy inside the test sandbox (res://tools/ → WorldState.data_dir()), never the player's own files.
#   godot --headless res://tools/save_audit.tscn -- --save=/abs/path/slot_1_save.json
# (owner round 49k: "analyse the most recent save… it was too damn easy").

const MG := preload("res://scripts/module_geo.gd")

var _src := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save="):
			_src = a.substr(7)
	await get_tree().process_frame
	if _src == "" or not FileAccess.file_exists(_src):
		print("usage: --save=<abs path to slot_N_save.json>")
		get_tree().quit(1)
		return
	var dst: String = WorldState.data_dir() + "slot_1_save.json"
	DirAccess.copy_absolute(_src, ProjectSettings.globalize_path(dst))
	WorldState.active_slot = 1
	var scene: String = WorldState.load_game()
	print("loaded: scene=%s run=%d floor=%d seed=%d health_stage=%d character=%s" % [scene, WorldState.current_run, WorldState.current_floor, WorldState.master_seed, WorldState.player_health, WorldState.current_character()])
	_building()
	_flats()
	_kit()
	get_tree().quit(0)


func _building() -> void:
	print("\n== CORRIDORS (run %d): the dead the building placed, floor 29 -> 1" % WorldState.current_run)
	var total := 0
	var stairs := 0
	var rows := []
	var bosses := []
	var big_floors := 0
	for f in range(29, 0, -1):
		var n: int = WorldState.get_floor_zombie_count(f)
		var s: int = WorldState.stair_enemy_count(f)
		total += n
		stairs += s
		rows.append("%d:%d" % [f, n])
		if WorldState.floor_has_boss(f):
			bosses.append(f)
		if n >= 6:
			big_floors += 1
	print("  per floor (floor:count) ", " ".join(rows))
	print("  corridor dead total %d (mean %.2f a floor), stair enemies %d, floors with 6+ dead %d, boss floors %s" % [total, float(total) / 29.0, stairs, big_floors, str(bosses)])
	var killed := 0
	var killed_corridor := 0
	for key in WorldState.killed_zombies:
		var e: Dictionary = WorldState.killed_zombies[key]
		killed += 1
		if not str(e.get("scene", "")).contains("room"):
			killed_corridor += 1
	print("  killed on record: %d (corridor/other %d, flats %d); run_kills counter %d" % [killed, killed_corridor, killed - killed_corridor, WorldState.run_kills])
	print("  a standard's hit points by floor (the formula in enemy_zombie_standard._set_hp_from_floor: int(lerp(7,1,(f-1)/29)) +/- 1, clamped 1..8):")
	var hp := []
	for f in [29, 25, 20, 15, 10, 5, 1]:
		var base: float = lerpf(7.0, 1.0, float(f - 1) / 29.0)
		hp.append("f%d:%d..%d" % [f, clampi(int(base) - 1, 1, 8), clampi(int(base) + 1, 1, 8)])
	print("   ", " ".join(hp))


func _flats() -> void:
	print("\n== FLATS (floors 1-29, five a floor): what each door state held, and what was entered")
	var names := ["OPEN", "SHUT_FORCEABLE", "SHUT_LOCKED", "BARRICADED_FORCEABLE", "BARRICADED_LOCKED", "BREACHED"]
	# A forced / torn-down door is saved as OPEN, so the SAVED state cannot say what a flat WAS. Re-seed a copy of the door table from the master seed (the same roll the
	# game made when the floor was first seen) to read the ORIGINAL state of every flat the player knew about.
	var saved_states: Dictionary = WorldState.door_states.duplicate()
	var original := {}
	var saved_seeded: Dictionary = WorldState.floor_states_seeded.duplicate()
	WorldState.door_states = {}
	WorldState.floor_states_seeded = {}
	for f in range(29, 0, -1):
		WorldState.seed_floor_door_states(f)
	for apt in saved_states:
		if WorldState.door_states.has(apt):
			original[apt] = int(WorldState.door_states[apt])
	WorldState.door_states = saved_states
	WorldState.floor_states_seeded = saved_seeded
	var orig_total := {}
	var orig_entered := {}
	var orig_ended_open := {}
	for apt in original:
		if not str(apt).is_valid_int():
			continue
		var nm0: String = names[int(original[apt])]
		orig_total[nm0] = int(orig_total.get(nm0, 0)) + 1
		if bool(WorldState.map_entered.get(apt, false)):
			orig_entered[nm0] = int(orig_entered.get(nm0, 0)) + 1
		if int(saved_states.get(apt, -1)) == WorldState.DoorState.OPEN:
			orig_ended_open[nm0] = int(orig_ended_open.get(nm0, 0)) + 1
	print("  ORIGINAL door state (re-rolled from the seed) -> flats / entered / ended open now:")
	for nm in names:
		print("    %-22s flats %3d   entered %2d   open now %3d" % [nm, int(orig_total.get(nm, 0)), int(orig_entered.get(nm, 0)), int(orig_ended_open.get(nm, 0))])
	var by_state := {}
	var dead_by_state := {}
	var entered_by_state := {}
	for f in range(29, 0, -1):
		for c in range(1, 6):
			var apt := "%d%02d" % [f, c]
			if not WorldState.door_states.has(apt):
				continue
			var st: int = int(WorldState.door_states[apt])
			var nm: String = names[st]
			by_state[nm] = int(by_state.get(nm, 0)) + 1
			var n := 0
			if st == WorldState.DoorState.BREACHED:
				n = WorldState.get_breached_room_enemies(apt, 150.0, MG.right_x(WorldState.apartment_span(apt)) - 43.0, 321.0).size()
			elif WorldState.flat_lays_ordinary_dead(apt):
				n = WorldState.get_apartment_zombie_count(apt)
			dead_by_state[nm] = int(dead_by_state.get(nm, 0)) + n
			if bool(WorldState.map_entered.get(apt, false)):
				entered_by_state[nm] = int(entered_by_state.get(nm, 0)) + 1
	for nm in names:
		print("  %-22s flats %3d   dead inside %3d   entered %2d" % [nm, int(by_state.get(nm, 0)), int(dead_by_state.get(nm, 0)), int(entered_by_state.get(nm, 0))])
	var ent := 0
	for k in WorldState.map_entered:
		if bool(WorldState.map_entered[k]):
			ent += 1
	print("  flats entered in all: %d; searched nodes on record: %d" % [ent, WorldState.searched_anchors.size()])


func _kit() -> void:
	print("\n== THE KIT AT THE LOBBY")
	var mx: float = WorldState.get_max_stamina()
	print("  perks: %s" % str(WorldState.active_upgrades))
	print("  stamina: max %.0f, regen x%.2f (=%.1f a second after a %.1f s pause: a full bar in %.1f s), sprint drain x%.2f (=%.1f a second: a full bar lasts %.1f s)" % [mx, WorldState.get_stamina_regen_mult(), 10.0 * WorldState.get_stamina_regen_mult(), 0.8, mx / (10.0 * WorldState.get_stamina_regen_mult()), WorldState.get_sprint_drain_mult(), 14.4 * WorldState.get_sprint_drain_mult(), mx / (14.4 * WorldState.get_sprint_drain_mult())])
	var Player = load("res://scripts/player.gd")
	for it in WorldState.inventory:
		if it == null:
			continue
		var line := "  slot: %s (%s) x%d  Lv%d  dur %d" % [it.item_id, ItemData.get_item_name(it.item_id) if ItemData.has_method("get_item_name") else "?", it.count, it.level, it.current_durability]
		if it.item_id in ["002", "003", "012", "013", "014", "015", "016", "017", "018", "021", "025", "026", "027", "028", "029"]:
			var kind := "bat"
			var dmg: int = int(Player.WEAPON_DAMAGE.get(kind, 1)) + WorldState.get_melee_damage_bonus() + int(it.perk_add("damage"))
			line += "   [blunt: damage %d (3 base +%d perks), cooldown x%.2f -> %.2f s, reach +%.0f, perks %s]" % [dmg, int(it.perk_add("damage")), it.perk_mult("cooldown"), 0.8 * it.perk_mult("cooldown"), it.perk_add("reach"), str(it.perks)]
		elif it.item_id == "004":
			line += "   [gun: mag %d, head +%.2f body +%.2f from the gun's perks, run bonus head +%.2f body +%.2f, perks %s]" % [it.mag_count, it.perk_add("headshot"), it.perk_add("body"), WorldState.get_headshot_bonus(), WorldState.get_body_bonus(), str(it.perks)]
		print(line)
	print("  hits to kill with that bat's damage, by floor (worst-case HP of each floor): ")
	var bat = null
	for it in WorldState.inventory:
		if it != null and it.item_id == "017":
			bat = it
	if bat != null:
		var dmg2: int = 3 + WorldState.get_melee_damage_bonus() + int(bat.perk_add("damage"))
		var row := []
		for f in [29, 25, 20, 15, 10, 5, 1]:
			var base2: float = lerpf(7.0, 1.0, float(f - 1) / 29.0)
			var worst: int = clampi(int(base2) + 1, 1, 8)
			row.append("f%d:%d hit%s" % [f, int(ceil(float(worst) / float(dmg2))), "" if int(ceil(float(worst) / float(dmg2))) == 1 else "s"])
		print("   ", " ".join(row), "  (damage per swing %d)" % dmg2)
