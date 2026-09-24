extends Node

# Apartment WALL WINDOWS: every non-balcony module gets one window at a seeded LEFT/RIGHT
# wall slot, sitting in the anchor-free top wall band (no overlap with scavenge nodes).
# Natural light by run; night adds the rain/lightning storm. Run:
#   godot --headless res://tests/apartment_window_test.tscn

var failures: int = 0
const APT := "1501"


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== apartment window test ===")
	_test_seeded_side()
	await _test_windows_day()
	await _test_windows_night()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_seeded_side() -> void:
	WorldState.new_game()
	# Deterministic + stable: same call, same answer; independent of run.
	var a := WorldState.apartment_window_side(APT, 0)
	WorldState.current_run = 3
	var b := WorldState.apartment_window_side(APT, 0)
	check(a == b, "window side is stable across runs (%s == %s)" % [a, b])
	check(a in ["left", "right"], "side is left or right (%s)" % a)
	# Both sides occur across the building (not all one side).
	var lefts := 0
	var rights := 0
	for f in range(1, 30):
		for col in range(1, 6):
			var apt := str(f) + "0" + str(col)
			for slot in range(3):
				if WorldState.apartment_window_side(apt, slot) == "left":
					lefts += 1
				else:
					rights += 1
	check(lefts > 0 and rights > 0, "both left and right windows occur (L %d / R %d)" % [lefts, rights])


func _expected_windows(apt: String) -> int:
	var n := 0
	for slot in range(3):
		if not WorldState.is_balcony_slot(apt, slot):
			n += 1
	return n


func _test_windows_day() -> void:
	WorldState.new_game()
	WorldState.is_first_run = false          # skip tutorial layouts
	WorldState.current_run = 1                # morning / day
	WorldState.current_apartment_id = APT
	WorldState.current_floor = 15
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(5):
		await get_tree().process_frame
	var windows := get_tree().get_nodes_in_group("apt_window_light")
	check(windows.size() == _expected_windows(APT),
		"one window per non-balcony module (%d, expected %d)" % [windows.size(), _expected_windows(APT)])
	# Every window sits on the wallpaper band (world 262 = module-local 38 — above the chair rail
	# at local 70, below the crown moulding), read from the room's own constant.
	var wy: float = room.MODULE_WINDOW_Y
	check(absf(wy - 262.0) < 0.5, "the window line is world 262 (module-local 38)")
	var win_y_ok := true
	for w in windows:
		if absf(w.global_position.y - wy) > 1.0:
			win_y_ok = false
	check(win_y_ok, "windows sit on the wallpaper band (y %.0f)" % wy)
	# The whole pane + frame stays on the wallpaper: above the chair rail (module-local 70), below
	# the crown moulding (local 5).
	var PW = load("res://scripts/apartment_window.gd")
	var top_local: float = wy - 224.0 - PW.PANE_HALF_H - 1.5
	var bot_local: float = wy - 224.0 + PW.PANE_HALF_H + 1.5
	check(top_local >= 6.0 and bot_local <= 69.0, "window spans local %.1f..%.1f, inside the wallpaper band 6..69" % [top_local, bot_local])
	# The window CENTRE sits ABOVE every scavenge node (window higher on the wall than the
	# furniture), so it never obscures a node's interaction point — a node may sit under it.
	var min_anchor_y := 100000.0
	for m in get_tree().get_nodes_in_group("room_module"):
		for c in m.get_children():
			if c is Marker2D:
				min_anchor_y = minf(min_anchor_y, m.global_position.y + c.position.y)
	check(min_anchor_y > wy, "every scavenge node sits below the window centre (lowest %.0f > %.0f)" % [min_anchor_y, wy])
	check(get_tree().get_nodes_in_group("apt_storm").is_empty(), "no storm on a day run")
	# MODULE WALLS (owner round 9): a perspective wall at every boundary, the face toward the camera.
	var mw = room.get_node_or_null("ModuleWalls")
	check(mw != null, "the room builds its module walls")
	if mw != null:
		var bs: Array = mw.boundaries
		check(bs.size() == 4, "4 walls: two ends + two partitions (%d)" % bs.size())
		var interior_doors := 0
		var outside := 0
		for b in bs:
			if b["left"] != null and b["right"] != null and b["door"]:
				interior_doors += 1
			if b["outside"]:
				outside += 1
		check(interior_doors == 2, "both partitions have a doorway (%d)" % interior_doors)
		check(outside == 1, "exactly one end is the entrance (doorway to the corridor) (%d)" % outside)
		var mid: Dictionary = bs[1]
		check(mw.facing_room(mid, float(mid["x"]) - 50.0) == mid["left"], "camera left of a partition sees the LEFT room's wall")
		check(mw.facing_room(mid, float(mid["x"]) + 50.0) == mid["right"], "…and from the right, the RIGHT room's wall (never inverted)")
	# Every window / balcony door casts a slanting light BEAM (window_beam.gd) that carries a
	# real PointLight2D — so the shaft actually lights the room, not just a painted overlay.
	var beams := get_tree().get_nodes_in_group("window_beam")
	check(beams.size() >= windows.size(),
		"each window casts a light beam (%d beams >= %d windows)" % [beams.size(), windows.size()])
	var beams_lit := beams.size() > 0
	for b in beams:
		var has_light := false
		for c in b.get_children():
			if c is PointLight2D:
				has_light = true
		beams_lit = beams_lit and has_light
	check(beams_lit, "every beam carries a real cast light")
	room.queue_free()
	await get_tree().process_frame


func _test_windows_night() -> void:
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.current_run = 3                # night
	WorldState.current_apartment_id = APT
	WorldState.current_floor = 15
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(5):
		await get_tree().process_frame
	check(get_tree().get_nodes_in_group("apt_window_light").size() == _expected_windows(APT),
		"windows still spawn at night")
	check(not get_tree().get_nodes_in_group("apt_storm").is_empty(), "a night run adds the storm driver")
	# Rain particles hang off the windows at night.
	var rain_found := false
	for w in get_tree().get_nodes_in_group("apt_window_light"):
		var parent = w.get_parent()
		for c in parent.get_children():
			if c is CPUParticles2D:
				rain_found = true
	check(rain_found, "night windows carry rain particles")
	room.queue_free()
	await get_tree().process_frame
