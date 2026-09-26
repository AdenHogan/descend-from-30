extends Node

# THE GUN CABINET (owner round 20 — "a quest without saying it"): living room E's locked cabinet
# holds a GUARANTEED Lv3 gun; its key or a crowbar opens it; the key is on a tough SPITTER (double
# HP, double spit damage) in a boss-less breach room on the same floor; in runs 2/3 someone may have
# broken in first. Run:
#   godot --headless res://tests/gun_cabinet_test.tscn

var failures: int = 0
var cab := ""          # a cabinet apartment on the found seed
var key_room := ""     # its key carrier's breach room


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== gun cabinet test ===")
	_find_seed()
	if cab == "":
		check(false, "found a seed with a gun cabinet and a key room")
	else:
		_test_where()
		_test_weapon()
		_test_open_with_key()
		_test_open_with_crowbar()
		_test_looted_by_others()
		_test_key_labels()
		await _test_live_rooms()
	WorldState.dev_seed = 0
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _fresh(seed_: int) -> void:
	WorldState.dev_seed = seed_
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.current_run = 1


func _find_seed() -> void:
	for s in range(1, 200):
		_fresh(7000 + s)
		for f in range(4, 27):
			for apt in WorldState.gun_cabinets_on_floor(f):
				var room := WorldState.cabinet_key_room(apt)
				if room != "":
					cab = apt
					key_room = room
					print("  seed %d: cabinet %s, key room %s" % [7000 + s, cab, key_room])
					return


func _test_where() -> void:
	var slot := WorldState.gun_cabinet_slot(cab)
	var layout: Array = WorldState.get_apartment_layout(cab)
	var RoomScript = load("res://scripts/room.gd")
	check(slot >= 0 and layout[slot] == "living_room", "the cabinet is in a living-room slot")
	check(RoomScript.module_scene_for(cab, slot, "living_room") == WorldState.GUN_CABINET_SCENE,
		"that slot shows living room E")
	var m = load(WorldState.GUN_CABINET_SCENE).instantiate()
	check(m.get_node_or_null(WorldState.GUN_CABINET_ANCHOR) != null, "living room E carries the cabinet node")
	m.free()
	check(WorldState.gun_cabinet_state(cab) == "locked", "a fresh cabinet is locked")
	check(WorldState.get_door_state(key_room) == WorldState.DoorState.BREACHED, "the key room is a breach room")
	check(key_room != cab and WorldState._apartment_floor(key_room) == WorldState._apartment_floor(cab),
		"on the same floor, not the cabinet's own flat")
	check(WorldState.cabinet_for_key_room(key_room) == cab, "the key room knows its cabinet")
	# every floor with a cabinet seeds at least one breach room outside the cabinet flats
	var ok := true
	for f in range(2, 29):
		var cabs: Array = WorldState.gun_cabinets_on_floor(f)
		if cabs.is_empty():
			continue
		var n := 0
		for i in range(1, 6):
			var apt := str(f) + "0" + str(i)
			if not (apt in cabs) and WorldState.get_door_state(apt) == WorldState.DoorState.BREACHED:
				n += 1
		if n == 0:
			ok = false
	check(ok, "every cabinet floor has a breach room for the key")
	WorldState.is_first_run = true
	var tut := true
	for apt in ["3002", "3003", "3004", "3005"]:
		if WorldState.gun_cabinet_slot(apt) >= 0:
			tut = false
	WorldState.is_first_run = false
	check(tut, "no cabinet in the tutorial's rooms (first run, floor 30)")


func _test_weapon() -> void:
	var a = WorldState.gun_cabinet_weapon(cab)
	var b = WorldState.gun_cabinet_weapon(cab)
	check(a.item_id == WorldState.CABINET_WEAPON and a.level == 3, "inside: the Gun at Lv3 (%s Lv%d)" % [a.item_id, a.level])
	check(a.perks.size() == 2 and a.perks[0] in WeaponUpgrades.TREES["004"][2] and a.perks[1] in WeaponUpgrades.TREES["004"][3],
		"one of each level's two perks (%s)" % str(a.perks))
	check(WeaponUpgrades.points_free(a) == 4, "its 4 tuning points left for the bench")
	check(a.mag_count == WorldState.CABINET_ROUNDS, "a few rounds in the magazine")
	check(a.perks == b.perks, "the same gun every time (seeded)")
	check(a.tier_label() == "Lv3", "reads as Lv3")


func _test_open_with_key() -> void:
	WorldState.inventory.clear()
	WorldState.gun_cabinets.erase(cab)
	check(WorldState.open_gun_cabinet(cab, "key") != "", "no key, no opening")
	check(WorldState.open_gun_cabinet(cab, "pry") != "", "no crowbar, no prying")
	check(WorldState.gun_cabinet_state(cab) == "locked", "still locked")
	WorldState.add_key_to_inventory(WorldState.CABINET_KEY_PREFIX + cab)
	check(WorldState.has_cabinet_key(cab), "its key is recognised")
	check(WorldState.open_gun_cabinet(cab, "key") == "", "its key opens it")
	check(WorldState.gun_cabinet_state(cab) == "open", "open, the gun inside")
	check(not WorldState.has_cabinet_key(cab), "the key stays in the lock")
	check(WorldState.cabinet_key_room(cab) == "", "an opened cabinet has no key carrier any more")
	WorldState.note_gun_cabinet_taken(cab)
	check(WorldState.gun_cabinet_state(cab) == "open_empty", "taken: open and empty")
	check(not WorldState.gun_cabinet_holds_weapon(cab), "nothing left inside")


func _test_open_with_crowbar() -> void:
	WorldState.inventory.clear()
	WorldState.gun_cabinets.erase(cab)
	WorldState.add_to_inventory("035")
	check(WorldState.open_gun_cabinet(cab, "pry") == "", "a crowbar pries it")
	check(WorldState.gun_cabinet_state(cab) == "smashed", "smashed, the gun inside")
	check(not WorldState.has_crowbar(), "the crowbar is spent")
	WorldState.gun_cabinets.erase(cab)


func _test_looted_by_others() -> void:
	var saved_run: int = WorldState.current_run
	var any2 := false
	var any3 := false
	var monotonic := true
	var run1 := false
	for s in range(0, 60):
		var apt := str(5 + s % 20) + "0" + str(1 + s % 5)
		WorldState.current_run = 1
		run1 = run1 or WorldState.gun_cabinet_looted_by_others(apt) and not WorldState.is_apartment_charred(5 + s % 20, 1 + s % 5)
		WorldState.current_run = 2
		var l2 := WorldState.gun_cabinet_looted_by_others(apt)
		WorldState.current_run = 3
		var l3 := WorldState.gun_cabinet_looted_by_others(apt)
		any2 = any2 or l2
		any3 = any3 or l3
		if l2 and not l3:
			monotonic = false
	WorldState.current_run = saved_run
	check(not run1, "run 1: nobody has been at a cabinet yet")
	check(any2 and any3, "runs 2/3: some cabinets were broken into first")
	check(monotonic, "once broken into, it stays broken into")


func _test_key_labels() -> void:
	var t: String = WorldState.CABINET_KEY_PREFIX + cab
	check(WorldState.key_display(t) == "Gun cabinet key — Apt " + cab, "the key names the cabinet")
	check(WorldState.key_display(cab) == "Key — Apt " + cab, "a door key reads as before")
	check(WorldState.key_tag(t) == "C" + cab, "its slot tag")
	var inst := ItemInstance.new()
	inst.setup_key("022", t)
	check(inst.get_display_name() == "Gun cabinet key — Apt " + cab, "the item's name")
	check(inst.target_apartment != cab, "it never opens the flat's front door")


func _room(apt: String) -> Node:
	WorldState.current_apartment_id = apt
	WorldState.current_floor = WorldState._apartment_floor(apt)
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	return room


func _test_live_rooms() -> void:
	WorldState.inventory.clear()
	WorldState.gun_cabinets.erase(cab)
	# --- the cabinet's flat ---
	var room := _room(cab)
	for i in range(5):
		await get_tree().process_frame
	var anchor: Node = null
	for m in get_tree().get_nodes_in_group("room_module"):
		var a = m.get_node_or_null(WorldState.GUN_CABINET_ANCHOR)
		if a != null:
			anchor = a
	check(anchor != null and anchor.has_method("try_interact"), "the cabinet node is live")
	check(anchor != null and anchor.visible, "and shown")
	check(WorldState.get_anchor_item(cab, WorldState.GUN_CABINET_ANCHOR) == WorldState.CABINET_WEAPON, "it holds the gun")
	var art = get_tree().get_first_node_in_group("gun_cabinet_art")
	check(art != null and not art.visible, "locked = the module art itself (no overlay)")
	# no key, no crowbar: it stays shut
	check(anchor != null and not anchor._open_gun_cabinet(), "locked without its key or a crowbar")
	WorldState.add_key_to_inventory(WorldState.CABINET_KEY_PREFIX + cab)
	check(anchor != null and anchor._open_gun_cabinet(), "its key opens it")
	check(art != null and art.visible and art.texture != null, "the open look is laid over the art")
	room.queue_free()
	await get_tree().process_frame
	# every look has its overlay, every run
	var GA = load("res://scripts/gun_cabinet_art.gd")
	var all_ok := true
	for st in ["open", "smashed", "open_empty", "smashed_empty"]:
		for r in [1, 2, 3]:
			var p: String = GA.texture_for(st, r)
			if p == "" or (r > 1 and not p.ends_with("_r%d.png" % r)):
				all_ok = false
	check(all_ok, "an overlay for every look, every run")
	check(GA.texture_for("locked", 1) == "", "no overlay while locked")
	# --- the key room: a tough spitter, no big boss ---
	WorldState.gun_cabinets.erase(cab)
	WorldState.inventory.clear()
	var kroom := _room(key_room)
	for i in range(5):
		await get_tree().process_frame
	var carriers := get_tree().get_nodes_in_group("cabinet_key_carrier")
	check(carriers.size() == 1, "one key carrier in the breach room (%d)" % carriers.size())
	var bigs := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if z.get("drops_key") == true and z.get_script() == load("res://scripts/enemy_zombie_big.gd"):
			bigs += 1
	check(bigs == 0, "no big boss in the key room")
	if carriers.size() == 1:
		var sp = carriers[0]
		check(sp.is_in_group("spitter"), "it's a spitter")
		check(sp.key_target_apartment == WorldState.CABINET_KEY_PREFIX + cab, "carrying the cabinet's key")
		check(sp.spit_damage == 2, "its spit hits twice as hard")
		if sp.player != null:
			sp._spit_cd = 0.0
			sp._deliver_attack(0.0)
			var dmg := -1
			for n in sp.get_parent().get_children():
				if n.get_script() == load("res://scripts/spit_projectile.gd"):
					dmg = n.damage
			check(dmg == 2, "a spit it fires carries 2 damage (%d)" % dmg)
		else:
			check(false, "the room has a player for the spit check")
		check(sp.max_hp % 2 == 0 and sp.max_hp >= 2 and sp.current_hp == sp.max_hp, "double HP (%d)" % sp.max_hp)
		sp._drop_key()
		check(WorldState.has_cabinet_key(cab), "killing it gives the cabinet's key")
	kroom.queue_free()
	await get_tree().process_frame
