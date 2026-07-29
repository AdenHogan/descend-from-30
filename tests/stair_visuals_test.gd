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

	# ASCENDING IS THE DESCENT PLAYED BACKWARDS. The descent is signed off, so the
	# ascent must reuse its numbers rather than invent its own. Both directions
	# derive the red line and the cut from the same two constants applied to their
	# own floor's standing line, so the pair below is what keeps them in step.
	var floor_line := 391.0
	var red_line := floor_line - StairPan.STAIR_APPROACH
	var cut := red_line + StairPan.SHRED_FOOT
	chk(red_line < floor_line,
		"the red line sits ABOVE the standing line, on the stairs (%.1f < %.1f)"
			% [red_line, floor_line])
	chk(cut > red_line,
		"the cut sits below the red line, on the yellow steps (%.1f > %.1f)"
			% [cut, red_line])
	# Leaving, the player drops through that cut; arriving, they climb up through
	# it. Their scalp breaks it SHRED_TOP below the cut, and there must be real
	# climbing left between that and the red line or they surface all at once.
	var scalp_crosses := cut + StairPan.SHRED_TOP
	chk(scalp_crosses - red_line >= StairPan.STEP_HEIGHT * 2.0,
		"the climb into view is more than a single step (%.0fpx, step %.0f)"
			% [scalp_crosses - red_line, StairPan.STEP_HEIGHT])
	# THE SHAFT CROP. The player sprite is 48px at scale 3 — 144 wide — and the
	# stairwell is barely 60, so a body standing dead centre in it still spills
	# across the corridor wall. While the shredder runs, the sprite is cropped to
	# the shaft, so nothing of them is drawn outside the opening.
	var band := StairPan.shaft_band(148.0, 188.0)     # the left stairwell's two stair x's
	chk(band.x < 148.0 and band.y > 188.0,
		"the band contains both stair positions (%.0f..%.0f)" % [band.x, band.y])
	chk(band.y - band.x < 144.0,
		"...and is narrower than the sprite, or it crops nothing (%.0f wide)"
			% (band.y - band.x))
	var right := StairPan.shaft_band(1201.0, 1162.0)  # argument order must not matter
	chk(right.x < 1162.0 and right.y > 1201.0,
		"the right stairwell bands the same way round (%.0f..%.0f)" % [right.x, right.y])

	# The two beats either side of the bend cover the same ground both ways.
	chk(StairPan.TURN_HEIGHT > 0.0,
		"visible flight is the same height both ways (%.0fpx)" % StairPan.TURN_HEIGHT)
	chk(StairPan.STAIR_APPROACH > 0.0,
		"step onto the red line leaving == step off it arriving (%.0fpx)"
			% StairPan.STAIR_APPROACH)

	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
