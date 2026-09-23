extends Node

# The WHOLE building as one continuous space: every floor, the hallway (30) and the lobby (0)
# included, is reached by the seamless stair PAN — no fade, no reload — and each floor is the
# same shape so they stack flush. Walks 30 → 0 → 30 through the REAL stairwell triggers and,
# at every floor, checks the things a player would see go wrong: a fade, a camera/zoom jump,
# the world drifting off origin, the player off the floor line, a second player, the old floor
# left behind, and memory (drops/corpses) missing on arrival.
# Run: godot --headless res://tests/transition_seam_test.tscn

var failures: int = 0
const BAND_TOP := 243.0
const BAND_BOTTOM := 435.0
const SCENES := ["res://scenes/hallway.tscn", "res://scenes/building_floors.tscn", "res://scenes/lobby.tscn"]


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== transition seam test ===")
	_test_every_floor_is_the_same_shape()
	_test_lobby_has_one_stairwell()
	await _test_full_descent_and_back()
	Engine.time_scale = 1.0
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_every_floor_is_the_same_shape() -> void:
	print("[every floor scene fills exactly the shared band — no filler, flush stacking]")
	var ref_x := Vector2.ZERO
	for path in SCENES:
		var s = load(path).instantiate()
		var tm: TileMapLayer = s.get_node("TileMapLayer")
		var cell := float(tm.tile_set.tile_size.y)
		var r := tm.get_used_rect()
		var top: float = tm.position.y + r.position.y * cell
		var bottom: float = top + r.size.y * cell
		check(is_equal_approx(top, BAND_TOP) and is_equal_approx(bottom, BAND_BOTTOM),
			"%s tiles span exactly %d..%d (got %d..%d)" % [path.get_file(), BAND_TOP, BAND_BOTTOM, top, bottom])
		var xs := Vector2(tm.position.x + r.position.x * 16.0, tm.position.x + r.end.x * 16.0)
		if ref_x == Vector2.ZERO:
			ref_x = xs
		check(xs == ref_x, "%s spans the same width as the others (%s)" % [path.get_file(), xs])
		# Every row is solid wall-to-wall: no gaps for the clear colour to show through, and
		# none of the old blue filler tile (world_tileset 3:15) anywhere.
		var holes := 0
		var filler := 0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if tm.get_cell_source_id(c) == -1:
					holes += 1
				elif tm.get_cell_source_id(c) == 1 and tm.get_cell_atlas_coords(c) == Vector2i(3, 15):
					filler += 1
		check(filler == 0, "%s has no blue filler tiles (%d)" % [path.get_file(), filler])
		if path.ends_with("lobby.tscn"):
			check(holes == 0, "lobby is solid wall to wall (%d holes)" % holes)
		check(s is Node2D, "%s root is a Node2D (a pan backdrop must carry an offset)" % path.get_file())
		s.free()
	check(StairPan.FLOOR_BAND_TOP == BAND_TOP and StairPan.FLOOR_BAND_TOP + StairPan.FLOOR_BAND_H == BAND_BOTTOM,
		"StairPan's band is the same band")


func _test_lobby_has_one_stairwell() -> void:
	print("[the lobby has ONE stairwell — under floor 1's down stair — and end walls]")
	var s = load("res://scenes/lobby.tscn").instantiate()
	var stairs := []
	for n in s.get_children():
		if n is Area2D and n.get_script() == load("res://scripts/stairwell.gd"):
			stairs.append(n)
	check(stairs.size() == 1, "exactly one stairwell (%d)" % stairs.size())
	if stairs.size() == 1:
		check(stairs[0].direction == "up" and stairs[0].stair_side == WorldState.stair_down_side(1),
			"it goes UP on the side floor 1's down stair comes down (%s)" % stairs[0].stair_side)
	check(s.get_node_or_null("LobbyLeft") == null, "no left staircase art")
	var walls := 0
	for c in s.get_node("StaticBody2D").get_children():
		if c.shape is WorldBoundaryShape2D and absf(c.shape.normal.x) > 0.9:
			walls += 1
	check(walls == 2, "two end walls, like every other floor (%d)" % walls)
	s.free()


func _stairwell(dir: String) -> Node:
	for n in get_tree().current_scene.get_children():
		if n is Area2D and n.get("direction") == dir and n.process_mode != Node.PROCESS_MODE_DISABLED \
				and n.has_method("_perform_transition"):
			return n
	return null


func _floor_scenes_in_tree() -> int:
	var c := 0
	for n in get_tree().root.get_children():
		if n.scene_file_path in SCENES:
			c += 1
	return c


func _test_full_descent_and_back() -> void:
	print("[30 → lobby → 30 through the real stairwells: every step a pan, nothing lost]")
	WorldState.new_game()
	# A building whose floor 29 mounts a wall extinguisher, so that check always runs.
	for sd in range(424242, 425242):
		WorldState.master_seed = sd
		if WorldState.floor_has_extinguisher(29) and not WorldState.is_floor_charred(29):
			break
	WorldState.is_first_run = false        # the first-run no-return rule is its own test
	WorldState.opener_seen = true
	WorldState.god_mode = true
	WorldState.current_floor = 30
	WorldState.spawn_source = "stair"
	WorldState.stair_spawn_side = "left"
	# Memory planted on the three kinds of floor, each filed under ITS scene. They must be on
	# the floor when you arrive by stairs — floor 29's used to vanish when reached from 30.
	WorldState.add_world_drop("004", Vector2(700, 396), 29, {"scene": "res://scenes/building_floors.tscn", "apartment_id": ""})
	WorldState.add_world_drop("004", Vector2(600, 396), 1, {"scene": "res://scenes/lobby.tscn", "apartment_id": ""})
	WorldState.add_world_drop("004", Vector2(500, 396), 30, {"scene": "res://scenes/hallway.tscn", "apartment_id": ""})
	# Survive the scene swaps: hand "current scene" to a stub the first change will free.
	var stub := Node.new()
	get_tree().root.add_child.call_deferred(stub)   # root is busy while _ready runs
	await get_tree().process_frame
	get_tree().current_scene = stub
	get_tree().change_scene_to_file("res://scenes/hallway.tscn")
	for i in 5:
		await get_tree().process_frame
	var zoom0: Vector2 = get_tree().get_first_node_in_group("player").get_node("Camera2D").zoom
	Engine.time_scale = 12.0
	var plan := []
	for f in range(30, 0, -1):
		plan.append([f, "down"])
	for f in range(0, 30):
		plan.append([f, "up"])
	var faded := 0
	var bad_steps := []
	for step in plan:
		var from: int = step[0]
		var dir: String = step[1]
		var to: int = from + (-1 if dir == "down" else 1)
		var trig := _stairwell(dir)
		if trig == null:
			bad_steps.append("%d %s: no stairwell" % [from, dir])
			continue
		var player = get_tree().get_first_node_in_group("player")
		player.global_position = Vector2(trig.global_position.x, 386.0)
		trig._perform_transition()
		if not StairPan.panning:
			faded += 1
		var guard := 0
		while (StairPan.panning or Transition.busy) and guard < 3000:
			await get_tree().process_frame
			guard += 1
		await get_tree().process_frame
		await get_tree().process_frame
		var scene = get_tree().current_scene
		var why := []
		if scene == null or scene.scene_file_path != StairPan.scene_for_floor(to):
			why.append("wrong scene %s" % (scene.scene_file_path if scene else "null"))
		if WorldState.current_floor != to:
			why.append("current_floor %d" % WorldState.current_floor)
		if scene is Node2D and scene.position != Vector2.ZERO:
			why.append("world drifted to %s" % scene.position)
		var players := get_tree().get_nodes_in_group("player")
		if players.size() != 1:
			why.append("%d players" % players.size())
		player = players[0] if players.size() > 0 else null
		if player == null or player.get_parent() != scene:
			why.append("player not in the floor")
		elif absf(player.global_position.y - 386.0) > 1.0:
			why.append("player off the floor line (y %.1f)" % player.global_position.y)
		elif player.is_cutscene:
			why.append("control not returned")
		else:
			var cam: Camera2D = player.get_node("Camera2D")
			if not cam.is_current() or cam.zoom != zoom0 or cam.limit_top != int(BAND_TOP):
				why.append("camera jump (zoom %s top %d)" % [cam.zoom, cam.limit_top])
		if _floor_scenes_in_tree() != 1:
			why.append("%d floor scenes alive" % _floor_scenes_in_tree())
		for z in get_tree().get_nodes_in_group("pan_scenery"):
			why.append("frozen scenery left behind")
			break
		if not why.is_empty():
			bad_steps.append("%d→%d: %s" % [from, to, ", ".join(why)])
		# Memory: the planted drop is on the floor when you walk in.
		var want_drop := {29: "29:700.0:396.0", 0: "1:600.0:396.0", 30: "30:500.0:396.0"}
		if want_drop.has(to):
			var found := false
			for n in scene.get_children():
				if n.get("drop_key") == want_drop[to]:
					found = true
			check(found, "%s by stairs: its remembered drop is there" % ("the lobby" if to == 0 else "floor %d" % to))
		# The wall extinguisher placed while the pan built floor 29 from the hallway must be
		# filed under floor 29's OWN scene, or it never shows (it used to take the hallway's).
		if to == 29 and dir == "down" and WorldState.floor_has_extinguisher(29) \
				and not WorldState.is_floor_charred(29) and not WorldState.is_maintenance_floor(29):
			var kit := false
			for n in scene.get_children():
				if n.get("drop_key") == "29:929.0:360.0":
					kit = true
			check(kit, "floor 29 by stairs from the hallway: its wall extinguisher is mounted")
		if to == 0:
			var outside := 0
			for z in get_tree().get_nodes_in_group("zombie"):
				if z.global_position.x < 128.0 or z.global_position.x > 1224.0:
					outside += 1
			check(outside == 0, "the lobby's dead are all inside its walls")
	check(faded == 0, "all %d stair trips panned — none faded to black (%d faded)" % [plan.size(), faded])
	check(bad_steps.is_empty(), "every arrival clean: right scene, on the line, camera steady, no drift, old floor gone%s"
		% ("" if bad_steps.is_empty() else " — " + "; ".join(bad_steps.slice(0, 6))))
	WorldState.god_mode = false
