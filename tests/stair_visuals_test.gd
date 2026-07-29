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
		# black box, and the player surfaced in front of it anyway. The shredder
		# hides the player. Do not add it back.
		chk(bf.get_node_or_null("StairFrontLeft") == null
			and bf.get_node_or_null("StairFrontRight") == null,
			"%s: no front-layer sprite (it rendered as a black box)" % tag)
		bf.free()
		await get_tree().process_frame

	# DOWN AND UP ARE MIRRORED IN DESIGN, SEPARATE IN CODE. Every value that
	# places something on screen exists twice — DOWN_* and UP_* — so tuning one
	# direction cannot move the other. Identical values mean "these happen to
	# match", never "these must match". This is not tidiness: a shared
	# SHRED_FOOT is what let an ascent tweak break a signed-off descent.
	var floor_line := 391.0
	var down_red := floor_line - StairPan.DOWN_STAIR_APPROACH
	var up_red := floor_line - StairPan.UP_STAIR_APPROACH
	var down_cut := down_red + StairPan.DOWN_SHRED_FOOT
	var up_cut := up_red + StairPan.UP_SHRED_FOOT
	chk(down_red < floor_line and up_red < floor_line,
		"both red lines sit ABOVE the standing line, on the stairs (%.0f / %.0f)"
			% [down_red, up_red])
	chk(down_cut > down_red and up_cut > up_red,
		"both cuts sit below their red line, on the steps (down %.0f, up %.0f)"
			% [down_cut, up_cut])

	# The descent is signed off. These are its numbers; if a future ascent tweak
	# ever moves one, it is a bug in the split, not a tuning choice.
	chk(StairPan.DOWN_STAIR_APPROACH == 10.0
		and StairPan.DOWN_TURN_HEIGHT == 72.0
		and StairPan.DOWN_SHRED_FOOT == 20.0
		and StairPan.DOWN_DEPTH_SCALE == 0.82,
		"the DESCENT still has its signed-off geometry (%.0f/%.0f/%.0f/%.2f)"
			% [StairPan.DOWN_STAIR_APPROACH, StairPan.DOWN_TURN_HEIGHT,
			   StairPan.DOWN_SHRED_FOOT, StairPan.DOWN_DEPTH_SCALE])

	# Arriving, the player climbs up through the cut; their scalp breaks it
	# SHRED_TOP below, and there must be real climbing left between that and the
	# red line or they surface all at once.
	var scalp_crosses := up_cut + StairPan.SHRED_TOP
	chk(scalp_crosses - up_red >= StairPan.STEP_HEIGHT * 2.0,
		"the climb into view is more than a single step (%.0fpx, step %.0f)"
			% [scalp_crosses - up_red, StairPan.STEP_HEIGHT])

	# THE SHAFT CROP. The player sprite is 48px at scale 3 — 144 wide — and the
	# stairwell is barely 60, so a body standing dead centre in it still spills
	# across the corridor wall. shaft_band takes its margin as an argument, so
	# neither direction can inherit the other's.
	var band := StairPan.shaft_band(148.0, 188.0, StairPan.UP_SHAFT_MARGIN)
	chk(band.x < 148.0 and band.y > 188.0,
		"the band contains both stair positions (%.0f..%.0f)" % [band.x, band.y])
	chk(band.y - band.x < 144.0,
		"...and is narrower than the sprite, or it crops nothing (%.0f wide)"
			% (band.y - band.x))
	var right := StairPan.shaft_band(1201.0, 1162.0, StairPan.UP_SHAFT_MARGIN)
	chk(right.x < 1162.0 and right.y > 1201.0,
		"the right stairwell bands the same way round (%.0f..%.0f)" % [right.x, right.y])

	# The bend and the step onto the red line are mirrored, but each direction
	# owns its own value.
	chk(StairPan.DOWN_TURN_HEIGHT > 0.0 and StairPan.UP_TURN_HEIGHT > 0.0,
		"each direction owns its bend height (down %.0f, up %.0f)"
			% [StairPan.DOWN_TURN_HEIGHT, StairPan.UP_TURN_HEIGHT])
	chk(StairPan.DOWN_STAIR_APPROACH > 0.0 and StairPan.UP_STAIR_APPROACH > 0.0,
		"...and its own step on/off the red line (down %.0f, up %.0f)"
			% [StairPan.DOWN_STAIR_APPROACH, StairPan.UP_STAIR_APPROACH])

	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
