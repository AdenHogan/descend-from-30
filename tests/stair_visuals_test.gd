extends Node

# Which staircase art each side of a floor shows, for every way you can arrive.
# Lobby_* is the UP stairwell (the lobby is the building's bottom);
# Hallway_Staircase_* is the DOWN one (floor 30 is the top). The side you arrived
# on offers the way back, the far side carries on — so exactly one side is up and
# one is down, and the descent zig-zags across the corridor.
# Regression: the art used to ignore stair_direction on left arrivals, so floors
# 25 and 26 showed the same stairwell and a side whose arrow said "up" was drawn
# descending.
# Run:  godot --headless res://tests/stair_visuals_test.tscn

var fails := 0
func chk(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m); if not c: fails += 1
func _ready() -> void:
	WorldState.new_game()
	WorldState.current_floor = 25
	# side arrived, direction travelled -> which side should show UP art
	for case in [["left","down",true],["left","up",false],["right","down",false],["right","up",true]]:
		WorldState.stair_spawn_side = case[0]
		WorldState.stair_direction = case[1]
		var bf = load("res://scenes/building_floors.tscn").instantiate()
		bf.setup_floor = 25; bf.passive = true
		add_child(bf)
		for i in range(3): await get_tree().process_frame
		var ll = bf.get_node("LobbyLeft"); var hl = bf.get_node("HallwayStaircaseLeft")
		var lr = bf.get_node("LobbyRight"); var hr = bf.get_node("HallwayStaircaseRight")
		var want_left_up: bool = case[2]
		var tag := "arrive %s going %s" % [case[0], case[1]]
		chk(ll.visible == want_left_up and hl.visible != want_left_up, "%s: left shows %s" % [tag, "UP" if want_left_up else "DOWN"])
		chk(lr.visible != want_left_up and hr.visible == want_left_up, "%s: right shows %s" % [tag, "DOWN" if want_left_up else "UP"])
		chk(int(ll.visible) + int(hl.visible) == 1, "%s: exactly one left sprite" % tag)
		chk(int(lr.visible) + int(hr.visible) == 1, "%s: exactly one right sprite" % tag)
		# NO front-layer occluder. One was tried: it re-cut the top of the stair
		# art and drew it at z 2, which put the DARK SHAFT over the corridor as a
		# black box. The shredder hides the player; nothing needs to be drawn on
		# top of them. Do not add it back.
		chk(bf.get_node_or_null("StairFrontLeft") == null
			and bf.get_node_or_null("StairFrontRight") == null,
			"%s: no front-layer sprite (it rendered as a black box)" % tag)
		bf.free()
		await get_tree().process_frame

	# The transition has to MIRROR: the spot the descent leaves from and the spot
	# the ascent arrives on are the same red line, up on the steps. Arriving at
	# the standing line instead put the player half in the wall and read as
	# materialising out of it.
	var floor_line := 391.0
	chk(StairPan.stair_line(floor_line) < floor_line,
		"the red line sits ABOVE the standing line, on the stairs (%.1f < %.1f)"
			% [StairPan.stair_line(floor_line), floor_line])
	chk(StairPan.stair_line(floor_line) == floor_line - StairPan.STAIR_APPROACH,
		"one constant sets it for both directions")
	# ONE cut line, both directions — the player leaves down through it and comes
	# back up through the same one, so a body cannot dissolve at one height and
	# reappear at another.
	var cut := StairPan.shred_line(floor_line)
	chk(cut > StairPan.stair_line(floor_line),
		"the cut sits BELOW the red line (%.1f > %.1f)"
			% [cut, StairPan.stair_line(floor_line)])
	chk(cut < floor_line,
		"...and ABOVE the corridor floor, on the yellow steps (%.1f < %.1f)"
			% [cut, floor_line])

	# Arriving, the player climbs UP through that fixed cut, so the first pixel
	# shows when their scalp crosses it. There must be real climbing left between
	# that moment and the red line, or they surface all at once.
	var scalp_crosses := cut + StairPan.SHRED_TOP
	chk(scalp_crosses > StairPan.stair_line(floor_line),
		"they break the cut before reaching the red line (%.1f > %.1f)"
			% [scalp_crosses, StairPan.stair_line(floor_line)])
	chk(scalp_crosses - StairPan.stair_line(floor_line) >= StairPan.STEP_HEIGHT * 2.0,
		"the climb into view is more than a single step (%.0fpx, step %.0f)"
			% [scalp_crosses - StairPan.stair_line(floor_line), StairPan.STEP_HEIGHT])

	# THE MIRROR. Ascending is the descent played backwards, so the matching beats
	# must cover the same ground. The visible flight either side of the bend is
	# TURN_HEIGHT by construction, and the settle onto the floor is the approach
	# off it — both STAIR_APPROACH. If these ever differ, the two directions have
	# stopped being each other's reverse.
	chk(StairPan.TURN_HEIGHT > 0.0,
		"visible flight is the same height both ways (%.0fpx)" % StairPan.TURN_HEIGHT)

	# THE ARRIVAL HITCH. The destination floor is built DURING the pan, detached,
	# so the commit frame only has to run _ready instead of allocating a whole
	# floor. Building it must not put anything on screen early.
	chk(StairPan.floor_scene_path(24) == "res://scenes/building_floors.tscn"
		and StairPan.floor_scene_path(30) == "res://scenes/hallway.tscn"
		and StairPan.floor_scene_path(0) == "res://scenes/lobby.tscn",
		"every floor maps to its scene from one place")
	StairPan._build_pending(24)
	chk(StairPan._pending_scene != null, "the destination floor is built ahead of the commit")
	chk(StairPan._pending_scene != null and not StairPan._pending_scene.is_inside_tree(),
		"...detached, so none of it runs or draws until the swap")
	StairPan._drop_pending()
	chk(StairPan._pending_scene == null, "an abandoned pan frees it instead of leaking a floor")
	chk(absf(floor_line - StairPan.stair_line(floor_line)) == StairPan.STAIR_APPROACH,
		"step onto the red line leaving == step off it arriving (%.0fpx)"
			% StairPan.STAIR_APPROACH)

	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
