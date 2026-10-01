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
	# The stairwell layout is now a PURE FUNCTION OF THE FLOOR (WorldState.stair_down_side),
	# NOT of how you arrived. So on a GIVEN floor the same side is always DOWN and the same
	# side always UP, no matter what stair_spawn_side / stair_direction say. We prove that by
	# building the SAME floor under all four arrival combinations and asserting an identical
	# layout every time — this is the "iron-clad, can't lose track of the stairs" guarantee.
	# Floor 25 is odd, so its DOWN stair is on the RIGHT (stair_down_side(25) == "right").
	WorldState.current_floor = 25
	for case in [["left","down"],["left","up"],["right","down"],["right","up"],["","" ]]:
		WorldState.stair_spawn_side = case[0]
		WorldState.stair_direction = case[1]
		var bf = load("res://scenes/building_floors.tscn").instantiate()
		bf.setup_floor = 25; bf.passive = true
		add_child(bf)
		for i in range(3): await get_tree().process_frame
		var ll = bf.get_node("LobbyLeft"); var hl = bf.get_node("HallwayStaircaseLeft")
		var lr = bf.get_node("LobbyRight"); var hr = bf.get_node("HallwayStaircaseRight")
		var tag := "arrival(%s,%s)" % [case[0] if case[0] != "" else "-", case[1] if case[1] != "" else "-"]
		# Floor 25: DOWN on the RIGHT (Hallway art), UP on the LEFT (Lobby art), ALWAYS.
		chk(hr.visible and lr.visible == false, "%s: floor 25 right shows DOWN (fixed)" % tag)
		chk(ll.visible and hl.visible == false, "%s: floor 25 left shows UP (fixed)" % tag)
		chk(int(ll.visible) + int(hl.visible) == 1, "%s: exactly one left sprite" % tag)
		chk(int(lr.visible) + int(hr.visible) == 1, "%s: exactly one right sprite" % tag)
		# The active triggers must match the art. (The passive backdrop makes triggers inert
		# via _make_inert; call the function directly to test its floor-derived output.)
		bf._enable_stair_triggers(25)
		chk(bf.get_node("stair_right_down_trigger").process_mode == Node.PROCESS_MODE_ALWAYS
			and bf.get_node("stair_left_up_trigger").process_mode == Node.PROCESS_MODE_ALWAYS,
			"%s: floor 25 right-DOWN + left-UP triggers live" % tag)
		chk(bf.get_node("stair_left_down_trigger").process_mode == Node.PROCESS_MODE_DISABLED
			and bf.get_node("stair_right_up_trigger").process_mode == Node.PROCESS_MODE_DISABLED,
			"%s: floor 25 the other two triggers disabled" % tag)
		# NO front-layer occluder. One was tried: it re-cut the top of the stair
		# art and drew it at z 2, which put the DARK SHAFT over the corridor as a
		# black box, and the player surfaced in front of it anyway. The shredder
		# hides the player. Do not add it back.
		chk(bf.get_node_or_null("StairFrontLeft") == null
			and bf.get_node_or_null("StairFrontRight") == null,
			"%s: no front-layer sprite (it rendered as a black box)" % tag)
		bf.free()
		await get_tree().process_frame
	# And an EVEN floor mirrors it: floor 24 DOWN on the LEFT.
	WorldState.current_floor = 24
	WorldState.stair_spawn_side = ""; WorldState.stair_direction = ""
	var bf24 = load("res://scenes/building_floors.tscn").instantiate()
	bf24.setup_floor = 24; bf24.passive = true
	add_child(bf24)
	for i in range(3): await get_tree().process_frame
	chk(bf24.get_node("HallwayStaircaseLeft").visible and bf24.get_node("LobbyRight").visible,
		"floor 24 (even): DOWN on the LEFT, UP on the RIGHT")
	bf24.free()
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
	# ever moves one, it is a bug in the split, not a tuning choice. (The bend height went 72 -> 88 on the owner's
	# word, round 31f, when the flight was raised to halfway up the opening — it follows the art, checked below.)
	chk(StairPan.DOWN_STAIR_APPROACH == 10.0
		and StairPan.DOWN_TURN_HEIGHT == 88.0
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
	chk(band.x <= 148.0 and band.y >= 188.0,
		"the band spans both stair positions (%.0f..%.0f)" % [band.x, band.y])
	chk(band.y - band.x < 144.0,
		"...and is narrower than the sprite, or it crops nothing (%.0f wide)"
			% (band.y - band.x))
	var right := StairPan.shaft_band(1201.0, 1162.0, StairPan.UP_SHAFT_MARGIN)
	chk(right.x <= 1162.0 and right.y >= 1201.0,
		"the right stairwell bands the same way round (%.0f..%.0f)" % [right.x, right.y])

	# THE WALL ABOVE THE OPENING. The bend is UP_TURN_HEIGHT above the floor,
	# which is past the top of the stairwell opening — so the player turns behind
	# solid wall and must not be drawn there. This is what makes them disappear
	# behind the bend; without it they climb up over the corridor wall in plain
	# sight, which no amount of x cropping fixes.
	chk(StairPan.UP_SHAFT_TOP < StairPan.UP_TURN_HEIGHT,
		"the bend sits ABOVE the opening, so the wall swallows them (%.0f < %.0f)"
			% [StairPan.UP_SHAFT_TOP, StairPan.UP_TURN_HEIGHT])
	chk(StairPan.UP_SHAFT_TOP > StairPan.UP_STAIR_APPROACH,
		"...but the red line is INSIDE the opening, so arrival is not clipped (%.0f > %.0f)"
			% [StairPan.UP_SHAFT_TOP, StairPan.UP_STAIR_APPROACH])

	# THE ARRIVAL MUST NOT BOUNCE. The ascent used to climb to the red line, drop
	# the shader there (snapping the cropped sprite back to its full 144px width,
	# in front of the scene) and then ease DOWN onto the floor. It now climbs
	# straight to the standing line, so there is no drop; and the crop is released
	# during the climb, while the player is still wholly below the cut and
	# therefore undrawn.
	# It climbs to the red line and then WALKS DOWN onto the floor, with the cut
	# falling away past their feet during that step. Sweeping the cut while they
	# stood still made them rematerialise on the spot.
	chk(StairPan.UP_ARRIVE_REVEAL > 0.0,
		"the cut falls away over a real interval, not instantly (%.2fs)"
			% StairPan.UP_ARRIVE_REVEAL)

	# The bend and the step onto the red line are mirrored, but each direction
	# owns its own value.
	chk(StairPan.DOWN_TURN_HEIGHT > 0.0 and StairPan.UP_TURN_HEIGHT > 0.0,
		"each direction owns its bend height (down %.0f, up %.0f)"
			% [StairPan.DOWN_TURN_HEIGHT, StairPan.UP_TURN_HEIGHT])
	chk(StairPan.DOWN_STAIR_APPROACH > 0.0 and StairPan.UP_STAIR_APPROACH > 0.0,
		"...and its own step on/off the red line (down %.0f, up %.0f)"
			% [StairPan.DOWN_STAIR_APPROACH, StairPan.UP_STAIR_APPROACH])

	# CANONICAL ARRIVAL SIDE (the dev-warp fix). The stairwell layout is arrival-driven,
	# so a warp must land on the SAME side a real stair descent to that floor would — else
	# even floors render mirrored (down-stair on the wrong side) until an apartment
	# round-trip re-derives it. The warp (dev_warp_prompt), balcony drop and elevator all
	# feed WorldState.canonical_stair_arrival_side into stair_spawn_side for exactly this.
	chk(WorldState.canonical_stair_arrival_side(25) == "left"
		and WorldState.canonical_stair_arrival_side(23) == "left",
		"odd floors arrive on the LEFT (25=%s, 23=%s)"
			% [WorldState.canonical_stair_arrival_side(25), WorldState.canonical_stair_arrival_side(23)])
	chk(WorldState.canonical_stair_arrival_side(24) == "right"
		and WorldState.canonical_stair_arrival_side(26) == "right",
		"even floors arrive on the RIGHT (24=%s, 26=%s)"
			% [WorldState.canonical_stair_arrival_side(24), WorldState.canonical_stair_arrival_side(26)])
	# A canonical arrival at floor N puts the DOWN stair (the way on, to N-1) on the side
	# OPPOSITE the arrival side — the zig-zag. Verify the built floor honours it for both
	# parities, which is what a warp now reproduces on every floor.
	for fnum in [24, 25]:
		WorldState.current_floor = fnum
		WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(fnum)
		WorldState.stair_direction = "down"
		var bf2 = load("res://scenes/building_floors.tscn").instantiate()
		bf2.setup_floor = fnum; bf2.passive = true
		add_child(bf2)
		for i in range(3): await get_tree().process_frame
		var down_on_left: bool = bf2.get_node("HallwayStaircaseLeft").visible
		var arrived_left: bool = WorldState.canonical_stair_arrival_side(fnum) == "left"
		chk(down_on_left != arrived_left,
			"floor %d: DOWN stair is opposite the canonical arrival side (down_left=%s, arrived_left=%s)"
				% [fnum, down_on_left, arrived_left])
		bf2.free()
		await get_tree().process_frame

	# The stair art (owner round 31e): one DOWN look (the way down + a banister over the open well — no recess rotation), and every
	# stair sprite fills the WHOLE opening, lintel (262) to floor (406), so no corridor filler band shows above it.
	for f2 in [7, 12, 25]:
		var bf2 = load("res://scenes/building_floors.tscn").instantiate()
		bf2.setup_floor = f2; bf2.passive = true
		add_child(bf2)
		for i in range(3): await get_tree().process_frame
		var down_on_left: bool = WorldState.stair_down_side(f2) == "left"
		var spr = bf2.get_node("HallwayStaircaseLeft" if down_on_left else "HallwayStaircaseRight")
		var want := "res://assets/Hallway_Staircase_%s.png" % ("Left" if down_on_left else "Right")
		chk(spr.texture != null and spr.texture.resource_path == want, "floor %d DOWN stair shows %s (%s)" % [f2, want.get_file(), spr.texture.resource_path if spr.texture else "none"])
		for n in ["HallwayStaircaseLeft", "HallwayStaircaseRight", "LobbyLeft", "LobbyRight"]:
			var s2: Sprite2D = bf2.get_node(n)
			var top: float = s2.position.y - s2.texture.get_height() * 0.5
			var bot: float = s2.position.y + s2.texture.get_height() * 0.5
			chk(s2.scale == Vector2.ONE and s2.texture.get_width() == 80 and is_equal_approx(top, 262.0) and is_equal_approx(bot, 406.0),
				"floor %d %s fills the opening 262..406 at scale 1 (%.1f..%.1f)" % [f2, n, top, bot])
		var signs = bf2.get_node_or_null("FloorSigns")
		var after := signs != null
		for n in ["HallwayStaircaseLeft", "HallwayStaircaseRight", "LobbyLeft", "LobbyRight"]:
			if signs != null and signs.get_index() < bf2.get_node(n).get_index():
				after = false
		chk(after, "floor %d: the signs draw over the stair art (the STAIRS sign hangs in front of it)" % f2)
		bf2.queue_free()
		await get_tree().process_frame
	# The bend sits ON the top of the yellow flight the art draws (both directions): measured from the texture — the topmost
	# yellow tread in the shaft column — not taken on trust.
	var img: Image = load("res://assets/Lobby_Left.png").get_image()
	var top_row := -1
	for yy in range(img.get_height()):
		var c: Color = img.get_pixel(44, yy)   # left of the window, inside the shaft
		if c.r > 0.6 and c.g > 0.42 and c.b < 0.35:
			top_row = yy
			break
	var step_top_world: float = 262.0 + float(top_row)
	chk(top_row >= 0 and absf((419.0 - step_top_world) - StairPan.UP_TURN_HEIGHT) <= 1.0
		and StairPan.DOWN_TURN_HEIGHT == StairPan.UP_TURN_HEIGHT,
		"the bend (%.0f) is the drawn top step (world %.0f -> %.0f above the feet line)" % [StairPan.UP_TURN_HEIGHT, step_top_world, 419.0 - step_top_world])
	var mid: float = (262.0 + 406.0) * 0.5
	chk(absf(step_top_world - mid) <= 8.0, "the flight climbs about halfway up the opening (top %.0f, middle %.0f)" % [step_top_world, mid])
	# The stair ENEMY on a DOWN shaft is cut on the top of the yellow first step (owner round 31i: it used to be 4px lower, so
	# its body drew over the step's face). Read the lip from the texture: the topmost yellow row in the shaft column.
	var dimg: Image = load("res://assets/Hallway_Staircase_Left.png").get_image()
	var lip_row := -1
	for yy in range(dimg.get_height() - 1, 0, -1):
		var c: Color = dimg.get_pixel(20, yy)
		var yellow: bool = c.r > 0.4 and c.g > 0.28 and c.r > c.b + 0.25   # tread, nosing highlight and shadow rows alike
		if yellow:
			lip_row = yy
		elif lip_row >= 0:
			break
	var lip_world: float = 262.0 + float(lip_row)
	var BFS = load("res://scripts/building_floors.gd")
	var enemy_cut: float = BFS.STAIR_STAND_Y + BFS.STAIR_DOWN_CUT_DROP
	var player_cut: float = 386.0 - StairPan.DOWN_STAIR_APPROACH + StairPan.DOWN_SHRED_FOOT
	chk(lip_row >= 0 and is_equal_approx(enemy_cut, lip_world),
		"the stair enemy's DOWN cut (%.0f) is the top of the yellow step (%.0f)" % [enemy_cut, lip_world])
	chk(is_equal_approx(enemy_cut, player_cut), "...the same line the player's descent is cut on (%.0f)" % player_cut)
	for path in ["res://scenes/hallway.tscn", "res://scenes/lobby.tscn"]:
		var sc = load(path).instantiate()
		for n in ["HallwayStaircaseLeft", "LobbyRight"]:
			var s3 = sc.get_node_or_null(n)
			if s3 != null:
				var top3: float = s3.position.y - s3.texture.get_height() * 0.5
				chk(is_equal_approx(top3, 262.0), "%s %s top at the lintel (%.1f)" % [path.get_file(), n, top3])
		sc.free()
	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
