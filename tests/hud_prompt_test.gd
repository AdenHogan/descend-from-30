extends Node

# The world-anchored loot prompt (HUD.show_world_prompt) is a SCREEN-space label
# that tracks an item's projected position but stays crisp and IN BOUNDS — the
# world-space label it replaced blew up huge/blurry and spilled past the walls.
# Headless can't see crispness, but it CAN prove the two things that matter:
#   (1) the projected label is clamped fully on-screen and above the HUD bar,
#   (2) one owner leaving range can't wipe another owner's prompt.
# Run:  godot --headless res://tests/hud_prompt_test.tscn

var fails := 0

func chk(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c:
		fails += 1


func _ready() -> void:
	print("=== HUD world prompt ===")
	var cam := Camera2D.new()
	cam.zoom = Vector2(3.3, 3.3)
	cam.position = Vector2(600, 300)
	add_child(cam)
	cam.make_current()
	var owner_a := Node.new()
	var owner_b := Node.new()
	add_child(owner_a)
	add_child(owner_b)
	await get_tree().process_frame

	# An item far off to the right must still land fully on-screen.
	HUD.show_world_prompt(owner_a, "First Aid Kit   [Click] Take", Vector2(5000, 300))
	HUD._update_world_prompt()
	var pa: Panel = HUD.world_prompt_panel(owner_a)
	chk(pa != null and pa.visible, "prompt is shown")
	var pos: Vector2 = pa.position
	var w: float = pa.size.x
	chk(pos.x >= 0.0 and pos.x + w <= HUD.SCREEN_W + 0.5, "clamped inside the right edge (x=%.0f w=%.0f)" % [pos.x, w])
	chk(pos.y >= 0.0 and pos.y + pa.size.y <= HUD.SCREEN_H + 0.5, "kept on screen (y=%.0f)" % pos.y)

	# An item far to the LEFT clamps to the left edge, never negative.
	HUD.show_world_prompt(owner_a, "Bandages   [Click] Take", Vector2(-5000, 300))
	HUD._update_world_prompt()
	chk(HUD.world_prompt_panel(owner_a).position.x >= 0.0, "clamped inside the left edge (x=%.0f)" % HUD.world_prompt_panel(owner_a).position.x)

	# Multiple owners show at once, each its own pill.
	HUD.show_world_prompt(owner_b, "2509 - [E] Enter", Vector2(600, 300))
	HUD._update_world_prompt()
	chk(HUD.world_prompt_panel(owner_a).visible and HUD.world_prompt_panel(owner_b).visible,
		"two owners show independent prompts at once")

	# Ownership: one node leaving range hides ONLY its own prompt.
	HUD.hide_world_prompt(owner_b)
	chk(HUD.world_prompt_panel(owner_a).visible, "one owner leaving does not hide another's prompt")
	chk(not HUD.world_prompt_panel(owner_b).visible, "the owner hides its own prompt")
	HUD.hide_world_prompt(owner_a)
	chk(not HUD.world_prompt_panel(owner_a).visible, "the other owner hides its own too")

	# Owner round 48i: "Overlap on items and text" - two pickups side by side (a Fire Extinguisher and Torn Clothes) drew their pills on top of each other, "Fir…" hidden
	# behind "Torn Clothes [Click] Take". Pills that would overlap stack instead, in a stable left-to-right order, all on screen; a lone pill stays where it was.
	var o3 := Node.new()
	var o4 := Node.new()
	add_child(o3)
	add_child(o4)
	HUD.show_world_prompt(owner_a, "Torn Clothes   [Click] Take", Vector2(600, 300))
	HUD._update_world_prompt()
	var lone: Vector2 = HUD.world_prompt_panel(owner_a).position
	HUD.show_world_prompt(owner_b, "Fire Extinguisher   [Click] Take", Vector2(590, 300))
	HUD.show_world_prompt(o3, "First Aid Kit   [Click] Take", Vector2(612, 301))
	HUD.show_world_prompt(o4, "2509 - [E] Enter", Vector2(600, 296))
	HUD._update_world_prompt()
	var pills: Array = [HUD.world_prompt_panel(owner_a), HUD.world_prompt_panel(owner_b), HUD.world_prompt_panel(o3), HUD.world_prompt_panel(o4)]
	var overlaps := 0
	var off_screen := 0
	for i in range(pills.size()):
		var ri := Rect2(pills[i].position, pills[i].size)
		if ri.position.x < 0.0 or ri.position.y < 0.0 or ri.end.x > HUD.SCREEN_W + 0.5 or ri.end.y > HUD.SCREEN_H + 0.5:
			off_screen += 1
		for j in range(i + 1, pills.size()):
			if ri.intersects(Rect2(pills[j].position, pills[j].size)):
				overlaps += 1
	chk(overlaps == 0, "four pickups / doors at nearly one spot: no two pills overlap (%d overlapping pairs)" % overlaps)
	chk(off_screen == 0, "...and every one stays on screen (%d off)" % off_screen)
	chk(HUD.world_prompt_panel(owner_b).position.x < HUD.world_prompt_panel(owner_a).position.x + 1.0 or HUD.world_prompt_panel(owner_b).position.y != HUD.world_prompt_panel(owner_a).position.y,
		"...and they are told apart (not stacked on the same rows)")
	HUD.hide_world_prompt(owner_b)
	HUD.hide_world_prompt(o3)
	HUD.hide_world_prompt(o4)
	HUD._update_world_prompt()
	chk(HUD.world_prompt_panel(owner_a).position.is_equal_approx(lone), "a pill on its own is where it always was (%s vs %s)" % [str(HUD.world_prompt_panel(owner_a).position), str(lone)])
	# near the top of the screen there is no room to stack upward: the stack goes below, still on screen
	HUD.show_world_prompt(owner_a, "Torn Clothes   [Click] Take", Vector2(600, 150))
	HUD.show_world_prompt(owner_b, "Fire Extinguisher   [Click] Take", Vector2(598, 150))
	HUD._update_world_prompt()
	var ta := Rect2(HUD.world_prompt_panel(owner_a).position, HUD.world_prompt_panel(owner_a).size)
	var tb := Rect2(HUD.world_prompt_panel(owner_b).position, HUD.world_prompt_panel(owner_b).size)
	chk(not ta.intersects(tb) and ta.position.y >= 0.0 and tb.position.y >= 0.0, "high on the screen: still separate and on screen (%s / %s)" % [str(ta), str(tb)])
	for o in [owner_a, owner_b, o3, o4]:
		HUD.hide_world_prompt(o)

	await _test_dialogue_bubble()
	await _test_prompt_ceiling()
	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)


# Owner round 49q: "we really need to stop having text so high" - a world pill is for the person standing at the thing, so its anchor may stand no more than PROMPT_MAX_RISE
# above the top of their head, however high the thing's own label point is (a lift's 60 px up the wall, a curtain rail, a workbench's pegboard).
func _test_prompt_ceiling() -> void:
	print("[a world pill never floats far above the player's head]")
	var stand := Node2D.new()
	stand.add_to_group("player")
	stand.global_position = Vector2(600, 330)
	add_child(stand)
	var cam: Camera2D = get_viewport().get_camera_2d()
	var o := Node.new()
	add_child(o)
	var head_world: Vector2 = stand.global_position + Vector2(0, -26)
	var ceiling_world_y: float = head_world.y - HUD.PROMPT_MAX_RISE
	HUD.show_world_prompt(o, "Lift  [{interact}] Ride", Vector2(600, head_world.y - 300.0))
	HUD._update_world_prompt()
	var high: Rect2 = Rect2(HUD.world_prompt_panel(o).position, HUD.world_prompt_panel(o).size)
	var want_bottom: float = (Vector2(600, ceiling_world_y) - cam.get_screen_center_position()).y * cam.zoom.y + HUD.SCREEN_H / 2.0 - HUD.WORLD_PROMPT_GAP
	chk(absf(high.end.y - want_bottom) < 1.5, "an anchor 300 px over the head is pulled down to %.0f px over it: the pill's foot is at %.1f (wanted %.1f)" % [HUD.PROMPT_MAX_RISE, high.end.y, want_bottom])
	HUD.show_world_prompt(o, "Body   [{interact}] Search", Vector2(600, stand.global_position.y + 20.0))
	HUD._update_world_prompt()
	var low: Rect2 = Rect2(HUD.world_prompt_panel(o).position, HUD.world_prompt_panel(o).size)
	var want_low: float = (Vector2(600, stand.global_position.y + 20.0) - cam.get_screen_center_position()).y * cam.zoom.y + HUD.SCREEN_H / 2.0 - HUD.WORLD_PROMPT_GAP
	chk(absf(low.end.y - want_low) < 1.5 and low.end.y > high.end.y, "…and a prompt for something at the player's feet is left where it was (foot %.1f)" % low.end.y)
	HUD.hide_world_prompt(o)
	stand.remove_from_group("player")
	HUD.show_world_prompt(o, "Lift  [{interact}] Ride", Vector2(600, head_world.y - 300.0))
	HUD._update_world_prompt()
	var free_pill: Rect2 = Rect2(HUD.world_prompt_panel(o).position, HUD.world_prompt_panel(o).size)
	chk(free_pill.end.y < high.end.y - 100.0 or free_pill.position.y <= 6.5, "with no player (between scenes) nothing is clamped (foot %.1f)" % free_pill.end.y)
	HUD.hide_world_prompt(o)
	o.queue_free()
	stand.queue_free()


# Owner round 49f: the player's lines are a speech bubble over their head (like the residents'), not a banner at the top of the screen. Round 49q: the bubble sits RIGHT over the head with a tail
# (it was ~130 screen px above it: "far too high, I don't like how disconnected it is"), and it is the world pills that step round a bubble, never the bubble that climbs above a pill.
func _head_of(node: Node2D) -> Vector2:
	# the HUD's own fallback for a "player" with no head_top_position: 26 world px over the origin
	return get_viewport().get_canvas_transform() * (node.global_position + Vector2(0, -26))


func _test_dialogue_bubble() -> void:
	print("[the player's lines: a bubble over the head]")
	var stand := Node2D.new()
	stand.add_to_group("player")
	stand.global_position = Vector2(600, 330)
	add_child(stand)
	var cam: Camera2D = get_viewport().get_camera_2d()
	HUD.show_dialogue("Mrs Delacroix? Are you all right?", "", false, 4.0)
	await get_tree().process_frame
	var panel: PanelContainer = HUD.dialogue_panel
	var head: Vector2 = _head_of(stand)
	var r := Rect2(panel.position, panel.size)
	chk(panel.visible and r.position.x >= 0.0 and r.end.x <= HUD.SCREEN_W + 0.5 and r.position.y >= 0.0 and r.end.y <= HUD.SCREEN_H + 0.5, "the bubble is on screen (%s)" % str(r))
	chk(absf(r.get_center().x - head.x) < 2.0 and r.end.y <= head.y + 1.0, "…centred over the player's head (%s, head %s)" % [str(r), str(head)])
	var drop: float = head.y - r.end.y
	chk(drop <= HUD.BUBBLE_TAIL_H + HUD.BUBBLE_HEAD_GAP + 2.5, "…and right ON it: %.1f screen px between the bubble's foot and the head (a tail's worth, not a gap)" % drop)
	var tail: Control = HUD.dialogue_tail
	chk(tail != null and tail.visible, "the bubble has a tail")
	if tail != null:
		chk(absf((tail.position.x + tail.size.x * 0.5) - head.x) < 2.0 and absf((tail.position.y + tail.size.y) - (head.y - HUD.BUBBLE_HEAD_GAP)) < 2.5,
			"…whose tip touches the head (tip %s, head %s)" % [str(tail.position + tail.size), str(head)])
		chk(tail.position.y >= r.end.y - 3.0, "…hanging below the bubble's foot (tail %s, bubble foot %.0f)" % [str(tail.position), r.end.y])
	chk(r.size.x < 340.0, "…a bubble, not a banner across the screen (%.0f px wide)" % r.size.x)
	# it follows the player
	stand.global_position = Vector2(560, 330)
	HUD._position_dialogue()
	chk(panel.position.x < r.position.x - 4.0, "it follows the player when they walk (x %.0f -> %.0f)" % [r.position.x, panel.position.x])
	var held := Rect2(panel.position, panel.size)
	# an [E] Talk pill planted where the bubble hangs: the BUBBLE keeps its place, the PILL steps round it (owner round 49q)
	var talk := Node.new()
	add_child(talk)
	var on_bubble := held.get_center()
	var pill_world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * (on_bubble + Vector2(0, 14))
	HUD.show_world_prompt(talk, "[{interact}] Talk", pill_world)
	HUD._update_world_prompt()
	HUD._position_dialogue()
	var pill := Rect2(HUD.world_prompt_panel(talk).position, HUD.world_prompt_panel(talk).size)
	var rb := Rect2(panel.position, panel.size)
	chk(rb.position.is_equal_approx(held.position), "a world pill never moves the bubble off the head (bubble %s, was %s)" % [str(rb), str(held)])
	chk(not rb.intersects(pill), "…the pill steps clear of the bubble instead (bubble %s, pill %s)" % [str(rb), str(pill)])
	chk(pill.end.y <= rb.position.y + 1.0 or pill.position.y >= rb.end.y - 1.0, "…above or below it, never across it")
	HUD.hide_world_prompt(talk)
	# the game's passing words ("Equipped ...") stack ABOVE the player's own bubble, and then carry no tail (it would point at the bubble below)
	HUD.show_feedback("Equipped Baseball Bat.")
	await get_tree().process_frame
	var fb := Rect2(HUD.feedback_pill.position, HUD.feedback_pill.size)
	chk(not fb.intersects(Rect2(panel.position, panel.size)) and fb.end.y <= panel.position.y + 1.0, "passing words stack above a standing line (%s over %s)" % [str(fb), str(Rect2(panel.position, panel.size))])
	chk(HUD.feedback_tail != null and not HUD.feedback_tail.visible, "…and a stacked bubble has no tail (nothing for it to point at)")
	HUD.hide_dialogue()
	HUD._position_feedback()
	var fb2 := Rect2(HUD.feedback_pill.position, HUD.feedback_pill.size)
	chk(HUD.feedback_tail.visible and absf(fb2.get_center().x - _head_of(stand).x) < 2.0 and _head_of(stand).y - fb2.end.y <= HUD.BUBBLE_TAIL_H + HUD.BUBBLE_HEAD_GAP + 2.5,
		"alone, passing words sit right on the head with their tail (%s)" % str(fb2))
	HUD.feedback_timer = 0.01
	for _i in range(60):                      # headless frames can be a fraction of a millisecond: wait for the timer, not a fixed count
		if not HUD.feedback_pill.visible:
			break
		await get_tree().process_frame
	chk(not HUD.feedback_pill.visible and not HUD.feedback_tail.visible, "the tail goes with its bubble (pill %s, tail %s, timer %.3f)" % [str(HUD.feedback_pill.visible), str(HUD.feedback_tail.visible), HUD.feedback_timer])
	HUD.show_dialogue("Mrs Delacroix? Are you all right?", "", false, 4.0)
	await get_tree().process_frame
	# another speech bubble (a resident's) on the same spot: the player's keeps clear of it
	var other := PanelContainer.new()
	other.custom_minimum_size = Vector2(250, 40)
	other.add_to_group("speech_bubble")
	HUD.get_node("Control").add_child(other)
	other.position = panel.position
	other.size = Vector2(250, 40)
	HUD._position_dialogue()
	chk(not Rect2(panel.position, panel.size).intersects(other.get_global_rect()), "…nor another speech bubble")
	chk(not HUD.dialogue_tail.visible, "…and a bubble pushed up off the head has no tail")
	other.queue_free()
	# a line somebody ELSE says (the merchant behind the lift's doors) hangs over THEM, not over the player, and carries no "Merchant:" label
	var lift_at := Vector2(900.0, 363.0)
	stand.global_position = Vector2(600, 330)
	HUD.show_dialogue("Not a chance — I'm not opening these doors with the floor on fire.", "", false, 4.0, lift_at)
	await get_tree().process_frame
	var mouth: Vector2 = get_viewport().get_canvas_transform() * (lift_at + Vector2(0, HUD.SPEAKER_HEAD_DY))
	var rs := Rect2(panel.position, panel.size)
	chk(absf(rs.get_center().x - mouth.x) < 2.0 or rs.position.x <= 8.5 or rs.end.x >= HUD.SCREEN_W - 8.5, "the merchant's line hangs over the merchant, not the player (bubble centre %.0f, mouth %.0f)" % [rs.get_center().x, mouth.x])
	chk(absf(rs.get_center().x - _head_of(stand).x) > 20.0, "…and it is nowhere near the player's head")
	HUD.hide_dialogue()
	HUD.show_dialogue("The player speaks again.", "", false, 2.0)
	await get_tree().process_frame
	var back := Rect2(panel.position, panel.size)
	chk(absf(back.get_center().x - _head_of(stand).x) < 2.0, "the next ordinary line is the player's again (the speaker point does not stick)")
	for path in ["res://scripts/building_floors.gd"]:
		var src := FileAccess.get_file_as_string(path)
		chk(src.find("\"Merchant: ") < 0, "no merchant line still carries a \"Merchant:\" label")
	HUD.hide_dialogue()
	# a paused teaching beat keeps its hint inside the bubble
	HUD.show_dialogue("Find a weapon.", "[any key]", true)
	await get_tree().process_frame
	chk(HUD.dialogue_hint.visible and panel.get_global_rect().encloses(HUD.dialogue_hint.get_global_rect()), "a teaching beat's hint lives inside the bubble")
	HUD.hide_dialogue()
	# no player at all (between scenes): the old top-centre fallback, never off screen
	stand.remove_from_group("player")
	HUD.show_dialogue("A line with nobody to say it.", "", false, 2.0)
	await get_tree().process_frame
	var f := Rect2(panel.position, panel.size)
	chk(f.position.x >= 0.0 and f.end.x <= HUD.SCREEN_W + 0.5 and absf(f.get_center().x - HUD.SCREEN_W * 0.5) < 2.0, "with nobody to say it, the line falls back to the top-centre (%s)" % str(f))
	HUD.hide_dialogue()
	stand.queue_free()
	if cam != null:
		cam.zoom = Vector2(3.3, 3.3)
